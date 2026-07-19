extends Control
class_name CombatHudSlotView

## 局内 HUD 槽位视图统一技能槽与武器槽的紧凑外观、文字排版、状态遮罩和耐久显示。
## 组件不读取输入、技能组件或装备服务；宿主只通过公开接口传入按键、名称、辅助文本、资源和状态。

## 通用耐久条脚本；武器槽传入具有耐久属性的资源时显示，技能槽传入 null 时自动隐藏。
const DURABILITY_BAR_SCRIPT: Script = preload("res://scripts/ui/weapon_durability_bar.gd")
## 全局 UI 样式指南；紧凑技能与武器卡片从这里读取背景、边框与普通文字主题。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 普通背景颜色；默认沿用原技能槽深蓝黑色，使左右两侧槽位以技能 UI 为视觉基准。
const NORMAL_BACKGROUND_COLOR: Color = Color(0.025, 0.045, 0.075, 0.92)
## 普通边框颜色；默认使用技能槽青蓝描边，左右常驻 HUD 保持统一。
const NORMAL_BORDER_COLOR: Color = Color(0.26, 0.72, 0.92, 0.86)
## 选中边框颜色；默认亮青色，用于当前远程武器或其他明确选中状态。
const SELECTED_BORDER_COLOR: Color = Color(0.55, 0.92, 1.0, 1.0)
## 目标高亮颜色；默认绿色半透明，用于修复与强化的合法武器目标。
const HIGHLIGHT_BACKGROUND_COLOR: Color = Color(0.16, 0.52, 0.24, 0.34)
## 禁用遮罩颜色；默认灰黑半透明，保留名称、能耗和耐久可辨认。
const DISABLED_OVERLAY_COLOR: Color = Color(0.16, 0.16, 0.16, 0.72)
## 武器冷却进度颜色；默认白色半透明，从槽位底部按剩余比例覆盖。
const PROGRESS_OVERLAY_COLOR: Color = Color(1.0, 1.0, 1.0, 0.42)
## 点击与悬浮动画时长；默认 0.12 秒，与项目标准物品卡片保持一致。
const INTERACTION_DURATION: float = 0.12

## 当前显示尺寸；默认 106×50 像素匹配左侧技能槽，武器宿主会传入 112×54。
var _display_size: Vector2 = Vector2(106.0, 50.0)
## 当前显示资源；默认 null，只有武器等耐久资源会交给耐久条读取。
var _display_resource: Resource
## 当前是否选中；默认 false，影响边框亮度但不改变业务状态。
var _selected: bool = false
## 当前是否高亮；默认 false，合法目标状态会叠加绿色背景。
var _highlighted: bool = false
## 当前是否禁用；默认 false，启用时覆盖灰色滤镜并停止悬浮放大。
var _disabled: bool = false
## 当前底部进度遮罩比例；范围 0 至 1，默认 0，武器冷却使用该值。
var _progress_ratio: float = 0.0
## 当前空槽透明度；默认 1，技能空槽会传入 0.42 弱化文字。
var _content_opacity: float = 1.0
## 顶部按键标签；默认居中显示，武器槽传入空字符串时自动隐藏。
var _key_label: Label
## 中部名称标签；显示技能名、武器名或空槽文本。
var _name_label: Label
## 底部辅助信息标签；显示技能能耗、武器能耗或其他短状态。
var _detail_label: Label
## 整槽状态遮罩；技能冷却和后续段窗口使用，显示居中剩余时间。
var _state_overlay: ColorRect
## 整槽状态文字；默认空字符串，遮罩显示时居中展示秒数。
var _state_label: Label
## 禁用遮罩；目标不可选时覆盖全部槽位内容。
var _disabled_overlay: ColorRect
## 耐久条；传入具有 current_durability 与 max_durability 的资源时显示。
var _durability_bar: Control
## 当前交互动效补间；默认 null，新状态开始前停止旧补间避免缩放叠加。
var _interaction_tween: Tween
## 槽位背景样式实例；每个视图独占一份并在选中状态变化时更新边框，避免冷却重绘时重复创建 StyleBoxFlat。
var _slot_style: StyleBoxFlat = StyleBoxFlat.new()


func _ready() -> void:
	custom_minimum_size = _display_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_slot_style()
	_build_content()
	_refresh_content_visuals()
	queue_redraw()


func _notification(what: int) -> void:
	## 主题切换后仅请求重绘；绘制阶段实时读取色板，避免保存旧风格的背景和边框颜色。
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func configure_hud_content(display_size: Vector2, key_text: String, display_name: String, detail_text: String, display_resource: Resource = null, content_opacity: float = 1.0) -> void:
	## 配置共享局内槽位内容；按键为空时名称区域自动占据更自然的垂直位置。
	_display_size = Vector2(maxf(display_size.x, 48.0), maxf(display_size.y, 36.0))
	_display_resource = display_resource
	_content_opacity = clampf(content_opacity, 0.0, 1.0)
	custom_minimum_size = _display_size
	if _key_label != null:
		_key_label.text = key_text
		_key_label.visible = not key_text.is_empty()
	if _name_label != null:
		_name_label.text = display_name
	if _detail_label != null:
		_detail_label.text = detail_text
	if _durability_bar != null:
		_durability_bar.call("configure", _display_resource)
	_refresh_content_visuals()


func configure(item_resource: Resource, _quantity: int = 1, context_text: String = "", detail_bbcode: String = "", empty_text: String = "空", display_name_override: String = "", _secondary_detail_bbcode: String = "") -> void:
	## 兼容 WeaponSlotControl 的通用卡片配置签名；局内武器槽把 context_text 作为可选按键区文本。
	# 武器显示名称；优先使用宿主传入的损坏状态名称，资源为空时使用空槽文本。
	var resolved_name: String = display_name_override if not display_name_override.is_empty() else empty_text
	configure_hud_content(_display_size, context_text, resolved_name, detail_bbcode, item_resource, 1.0)


func configure_compact_layout(display_size: Vector2, show_context_label: bool) -> void:
	## 兼容紧凑武器槽接口；隐藏上下文时按键区域保持为空，名称与能耗继续居中排列。
	_display_size = Vector2(maxf(display_size.x, 48.0), maxf(display_size.y, 36.0))
	custom_minimum_size = _display_size
	if _key_label != null and not show_context_label:
		_key_label.visible = false


func set_visual_state(selected: bool, highlighted: bool) -> void:
	## 更新选中与合法目标视觉；只重绘背景和边框。
	if _selected == selected and _highlighted == highlighted:
		return
	_selected = selected
	_highlighted = highlighted
	_refresh_slot_style()
	queue_redraw()


func set_cooldown_ratio(cooldown_ratio: float) -> void:
	## 设置武器冷却进度遮罩；技能整槽秒数遮罩由 set_state_overlay() 独立控制。
	# 标准冷却比例；限制在 0 至 1，相同值不重复请求 CanvasItem 重绘。
	var resolved_ratio: float = clampf(cooldown_ratio, 0.0, 1.0)
	if is_equal_approx(_progress_ratio, resolved_ratio):
		return
	_progress_ratio = resolved_ratio
	queue_redraw()


func set_state_overlay(visible: bool, overlay_color: Color, overlay_text: String) -> void:
	## 设置技能冷却或后续段状态遮罩；文字始终居中，不参与实际计时。
	if _state_overlay == null or _state_label == null:
		return
	if _state_overlay.visible != visible:
		_state_overlay.visible = visible
	if _state_overlay.color != overlay_color:
		_state_overlay.color = overlay_color
	if _state_label.text != overlay_text:
		_state_label.text = overlay_text


func set_disabled_state(disabled: bool) -> void:
	## 设置不可选覆盖状态；禁用时立即恢复原始缩放。
	if _disabled == disabled:
		return
	_disabled = disabled
	if _disabled_overlay != null:
		_disabled_overlay.visible = _disabled
	if _disabled:
		scale = Vector2.ONE


func refresh_durability() -> void:
	## 刷新当前资源耐久条，不重建文字或其他槽位节点。
	if _durability_bar != null:
		_durability_bar.call("refresh")


func play_hover(host_control: Control, hovered: bool) -> void:
	## 播放共享悬浮缩放；技能槽不接收鼠标，因此只由可交互武器宿主调用。
	if host_control == null or _disabled:
		return
	_play_host_scale(host_control, Vector2.ONE * (1.03 if hovered else 1.0))


func play_click(host_control: Control, pressed: bool) -> void:
	## 播放共享点击缩放；按下缩至 0.96，释放恢复正常比例。
	if host_control == null or _disabled:
		return
	_play_host_scale(host_control, Vector2.ONE * (0.96 if pressed else 1.0))


func play_drag_source(host_control: Control, active: bool) -> void:
	## 播放共享拖拽来源反馈；激活时缩小并降低透明度，结束后恢复。
	if host_control == null:
		return
	_play_host_scale(host_control, Vector2.ONE * (0.96 if active else 1.0))
	host_control.modulate = Color(1.0, 1.0, 1.0, 0.58) if active else Color.WHITE


func create_drag_preview() -> Control:
	## 创建与当前局内槽位同外观的拖拽预览；只复制显示内容和视觉状态。
	# 预览宿主；固定使用当前紧凑尺寸并忽略鼠标。
	var preview_host: Control = Control.new()
	preview_host.custom_minimum_size = _display_size
	preview_host.size = _display_size
	preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 预览视图；复用相同组件与当前文字，不携带禁用状态。
	var preview_view: CombatHudSlotView = CombatHudSlotView.new()
	preview_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_host.add_child(preview_view)
	preview_view.configure_hud_content(_display_size, _key_label.text if _key_label != null and _key_label.visible else "", _name_label.text if _name_label != null else "", _detail_label.text if _detail_label != null else "", _display_resource, _content_opacity)
	preview_view.set_visual_state(_selected, _highlighted)
	return preview_host


func play_drag_preview(preview_control: Control) -> void:
	## 播放简洁拖拽预览呼吸动画；与共享槽位外观绑定但不改变业务拖拽数据。
	if preview_control == null:
		return
	preview_control.scale = Vector2.ONE * 0.94
	preview_control.pivot_offset = _display_size * 0.5
	# 预览补间；循环在 0.94 至 1.03 倍之间呼吸，拖拽结束后随预览节点自动释放。
	var preview_tween: Tween = preview_control.create_tween().set_loops()
	preview_tween.tween_property(preview_control, "scale", Vector2.ONE * 1.03, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	preview_tween.tween_property(preview_control, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_content() -> void:
	## 创建居中按键、名称、辅助信息、状态遮罩和耐久条；所有局内槽位共享同一节点结构。
	if _key_label != null:
		return
	# 内容边距；紧凑槽位使用较小留白，并为底部耐久条预留空间。
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	# 垂直内容容器；三个文本全部水平居中，按键不再靠左显示。
	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	margin.add_child(content)
	_key_label = Label.new()
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.add_theme_font_size_override("font_size", 10)
	UI_STYLE_GUIDE.apply_title_label(_key_label)
	content.add_child(_key_label)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 12)
	content.add_child(_name_label)
	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail_label.add_theme_font_size_override("font_size", 9)
	content.add_child(_detail_label)
	_state_overlay = ColorRect.new()
	_state_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_state_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_overlay.visible = false
	add_child(_state_overlay)
	_state_label = Label.new()
	_state_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override("font_size", 18)
	_state_overlay.add_child(_state_label)
	_durability_bar = DURABILITY_BAR_SCRIPT.new() as Control
	_durability_bar.call("set_layout_insets", 2.0, 2.0)
	add_child(_durability_bar)
	_disabled_overlay = ColorRect.new()
	_disabled_overlay.color = DISABLED_OVERLAY_COLOR
	_disabled_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_disabled_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disabled_overlay.visible = false
	add_child(_disabled_overlay)


func _refresh_content_visuals() -> void:
	## 同步文字透明度、耐久资源与禁用遮罩；节点未就绪时安全返回。
	if _key_label != null:
		_key_label.modulate = Color(1.0, 1.0, 1.0, _content_opacity)
	if _name_label != null:
		_name_label.modulate = Color(1.0, 1.0, 1.0, _content_opacity)
	if _detail_label != null:
		_detail_label.modulate = Color(1.0, 1.0, 1.0, _content_opacity)
	if _durability_bar != null:
		_durability_bar.call("configure", _display_resource)
	if _disabled_overlay != null:
		_disabled_overlay.visible = _disabled


func _draw() -> void:
	# 槽位矩形；技能与武器共享相同背景、边框、圆角与高亮规则。
	var slot_rect: Rect2 = Rect2(Vector2.ZERO, size)
	# 槽位样式；每次绘制按当前选中状态选择边框颜色，不保存跨实例共享可变资源。
	# 当前样式由本实例独占并在状态变化时提前更新，绘制阶段只复用结果。
	_slot_style.bg_color = UI_STYLE_GUIDE.get_compact_card_background_color()
	_slot_style.border_color = UI_STYLE_GUIDE.get_accent_color() if _selected else UI_STYLE_GUIDE.get_compact_card_border_color()
	var slot_style: StyleBoxFlat = _slot_style
	draw_style_box(slot_style, slot_rect)
	if _highlighted:
		draw_rect(slot_rect, HIGHLIGHT_BACKGROUND_COLOR, true)
	if _progress_ratio > 0.0:
		# 进度遮罩矩形；从底部向上覆盖剩余比例，与原武器冷却语义一致。
		var progress_height: float = size.y * _progress_ratio
		draw_rect(Rect2(Vector2(0.0, size.y - progress_height), Vector2(size.x, progress_height)), PROGRESS_OVERLAY_COLOR, true)


func _refresh_slot_style() -> void:
	## 刷新当前实例的背景与边框样式；只在初始化或选中状态变化时调用，冷却动画重绘直接复用结果。
	_slot_style.bg_color = UI_STYLE_GUIDE.get_compact_card_background_color()
	_slot_style.border_color = UI_STYLE_GUIDE.get_accent_color() if _selected else UI_STYLE_GUIDE.get_compact_card_border_color()
	_slot_style.set_border_width_all(2)
	_slot_style.set_corner_radius_all(6)


func _play_host_scale(host_control: Control, target_scale: Vector2) -> void:
	## 播放宿主缩放补间；连续交互会终止旧补间并从当前比例平滑过渡。
	if _interaction_tween != null and _interaction_tween.is_valid():
		_interaction_tween.kill()
	host_control.pivot_offset = host_control.size * 0.5
	_interaction_tween = host_control.create_tween()
	_interaction_tween.tween_property(host_control, "scale", target_scale, INTERACTION_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
