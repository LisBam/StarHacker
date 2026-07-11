extends Control
class_name ItemCardView

## 通用物品卡片视图统一承担物品名称、类型、摘要与耐久状态的视觉展示。
## 背包、仓库、锻造、商店及装备槽只保留各自交互协议，所有物品视觉必须复用本控件，禁止另建差异化卡片排版。

## 标准卡片固定尺寸；所有物品无论类型与所在系统都使用 160×72 像素，运行时不得按内容动态改变。
const STANDARD_CARD_SIZE: Vector2 = Vector2(160.0, 72.0)
## 卡片普通背景颜色；默认使用高透明度深蓝黑，保证不同系统中的物品拥有一致底色。
const NORMAL_BACKGROUND_COLOR: Color = Color(0.06, 0.075, 0.09, 0.96)
## 卡片普通边框颜色；默认使用低饱和蓝灰色，统一所有物品的视觉边界。
const NORMAL_BORDER_COLOR: Color = Color(0.22, 0.30, 0.36, 1.0)
## 卡片选中边框颜色；用于当前装备或主锻造物等明确选中状态。
const SELECTED_BORDER_COLOR: Color = Color(0.55, 0.92, 1.0, 1.0)
## 卡片目标高亮背景颜色；用于修复、强化等合法选择目标，不改变卡片排版。
const HIGHLIGHT_BACKGROUND_COLOR: Color = Color(0.16, 0.52, 0.24, 0.34)
## 卡片边框宽度；默认 2 像素，所有系统保持一致且运行时无需动态修改。
const BORDER_WIDTH: float = 2.0
## 卡片圆角半径；默认 4 像素，用于统一物品卡片轮廓。
const CORNER_RADIUS: float = 4.0
## 标准悬浮缩放；默认 1.03，所有物品卡片鼠标经过时使用相同放大幅度。
const HOVER_SCALE: float = 1.03
## 标准悬浮动画时长；默认 0.12 秒，进入与离开使用相同缓动时间。
const HOVER_DURATION: float = 0.12
## 标准拖拽来源缩放；默认 0.96，所有可拖拽物品被拿起时使用相同收缩幅度。
const DRAG_SOURCE_SCALE: float = 0.96
## 标准拖拽来源透明度；默认 0.58，拖拽期间统一降低原卡片存在感。
const DRAG_SOURCE_OPACITY: float = 0.58
## 标准拖拽预览初始缩放；默认 0.92，预览出现时统一从较小尺寸开始。
const DRAG_PREVIEW_START_SCALE: float = 0.92
## 标准拖拽预览脉冲缩放；默认 1.04，拖动期间统一循环呼吸。
const DRAG_PREVIEW_PULSE_SCALE: float = 1.04
## 标准拖拽预览单段时长；默认 0.32 秒，控制呼吸与摆动速度。
const DRAG_PREVIEW_PULSE_DURATION: float = 0.32
## 标准拖拽预览摆动弧度；默认 0.035 弧度，所有系统使用相同轻微左右摆动。
const DRAG_PREVIEW_TILT_RADIANS: float = 0.035
## 标准禁用遮罩颜色；默认半透明灰黑，完整覆盖内容但保留名称与耐久状态可辨认。
const DISABLED_OVERLAY_COLOR: Color = Color(0.16, 0.16, 0.16, 0.72)
## 通用物品详情格式化器；用于读取统一物品名称与中文类型标签。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 通用耐久条组件；只有同时带有当前耐久和最大耐久属性的物品才会显示。
const DURABILITY_BAR_SCRIPT: Script = preload("res://scripts/ui/weapon_durability_bar.gd")

## 当前展示的物品资源；默认 null 表示空槽，修改后会同步名称、类型和耐久显示。
var _item_resource: Resource
## 当前展示数量；默认 1，堆叠资源使用 1 至 99，修改会影响名称后的数量标记。
var _quantity: int = 1
## 当前上下文标签；默认空字符串时自动显示物品类型，可由装备槽或锻造槽传入职责名称。
var _context_text: String = ""
## 当前名称覆盖文本；默认空字符串时读取资源标准显示名，商店二手前缀等只通过本字段扩展。
var _display_name_override: String = ""
## 当前空槽文本；默认“空”，资源为空时作为卡片主名称显示。
var _empty_text: String = "空"
## 当前底部摘要富文本；默认空字符串时仅保留类型与名称，价格、词条或能量等由调用方传入。
var _detail_bbcode: String = ""
## 当前卡片是否处于选中状态；默认 false，启用时使用统一青色边框。
var _selected: bool = false
## 当前卡片是否处于合法目标高亮状态；默认 false，启用时叠加统一绿色背景。
var _highlighted: bool = false
## 当前冷却覆盖比例；取值 0 到 1，默认 0，仅战斗武器槽使用且不会改变其他物品卡片结构。
var _cooldown_ratio: float = 0.0
## 当前卡片是否处于禁用状态；默认 false，启用后显示统一灰色遮罩并停止全部悬浮反馈。
var _disabled: bool = false
## 当前宿主是否处于拖拽来源状态；默认 false，启用时暂停悬浮动画以保持来源缩放与透明度稳定。
var _drag_source_active: bool = false
## 顶部上下文标签缓存；默认在首次进入场景树时创建，显示物品类型或槽位职责。
var _context_label: Label
## 中部物品名称标签缓存；默认在首次进入场景树时创建，显示名称与堆叠数量。
var _name_label: Label
## 底部摘要标签缓存；默认在首次进入场景树时创建，支持价格与强化方向颜色。
var _detail_label: RichTextLabel
## 耐久条缓存；默认在首次进入场景树时创建，无耐久属性物品会自动隐藏。
var _durability_bar: Control
## 统一禁用遮罩缓存；默认在构建内容时创建并置于全部文字和耐久组件上方。
var _disabled_overlay: ColorRect
## 当前宿主交互动效补间；默认 null，悬浮和拖拽来源反馈共用以避免动画叠加。
var _interaction_tween: Tween


func _ready() -> void:
	custom_minimum_size = STANDARD_CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_content()
	_refresh_content()
	queue_redraw()


func configure(item_resource: Resource, quantity: int = 1, context_text: String = "", detail_bbcode: String = "", empty_text: String = "空", display_name_override: String = "") -> void:
	# 配置入口；所有系统只提供数据与上下文文本，不得自行创建差异化名称、摘要或耐久节点。
	_item_resource = item_resource
	_quantity = clampi(quantity, 1, 99)
	_context_text = context_text
	_detail_bbcode = detail_bbcode
	_empty_text = empty_text if not empty_text.is_empty() else "空"
	_display_name_override = display_name_override
	custom_minimum_size = STANDARD_CARD_SIZE
	if is_node_ready():
		_refresh_content()


func set_visual_state(selected: bool, highlighted: bool) -> void:
	# 统一状态入口；只改变通用背景和边框，不改变任何系统的交互规则或物品数据。
	_selected = selected
	_highlighted = highlighted
	queue_redraw()


func set_cooldown_ratio(cooldown_ratio: float) -> void:
	# 冷却覆盖入口；统一卡片内部从底部向上绘制白色遮罩，非战斗系统保持默认零值。
	_cooldown_ratio = clampf(cooldown_ratio, 0.0, 1.0)
	queue_redraw()


func set_disabled_state(disabled: bool) -> void:
	# 禁用状态入口；所有系统统一调用本方法，不得自行使用不同颜色的 modulate 或额外遮罩。
	_disabled = disabled
	if _disabled_overlay != null:
		_disabled_overlay.visible = _disabled
	if _disabled:
		_stop_interaction_tween()


func play_hover(host_control: Control, hovered: bool) -> void:
	# 统一悬浮反馈；禁用卡片始终恢复原比例，合法卡片使用固定 1.03 倍缩放。
	if host_control == null:
		return
	if _drag_source_active:
		return
	_stop_interaction_tween()
	host_control.pivot_offset = host_control.size * 0.5
	var target_scale: Vector2 = Vector2.ONE * HOVER_SCALE if hovered and not _disabled else Vector2.ONE
	_interaction_tween = host_control.create_tween()
	_interaction_tween.tween_property(host_control, "scale", target_scale, HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func create_drag_preview() -> Control:
	# 标准拖拽预览宿主；使用完整通用卡片而非纯文本，保证跨系统拖拽外观完全一致。
	var preview_host: Control = Control.new()
	preview_host.custom_minimum_size = STANDARD_CARD_SIZE
	preview_host.size = STANDARD_CARD_SIZE
	preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 标准预览卡片；复制当前物品、数量与三行摘要，不携带禁用遮罩和交互信号。
	var preview_card: Control = ItemCardView.new()
	preview_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_host.add_child(preview_card)
	preview_card.call("configure", _item_resource, _quantity, _context_text, _detail_bbcode, _empty_text, _display_name_override)
	preview_card.call("set_visual_state", _selected, _highlighted)
	return preview_host


func play_drag_source(host_control: Control, active: bool) -> void:
	# 统一拖拽来源反馈；开始时缩小并降低透明度，结束后恢复标准外观。
	if host_control == null:
		return
	_drag_source_active = active
	_stop_interaction_tween()
	host_control.pivot_offset = host_control.size * 0.5
	var target_scale: Vector2 = Vector2.ONE * DRAG_SOURCE_SCALE if active else Vector2.ONE
	var target_modulate: Color = Color(1.0, 1.0, 1.0, DRAG_SOURCE_OPACITY) if active else Color.WHITE
	_interaction_tween = host_control.create_tween()
	_interaction_tween.tween_property(host_control, "scale", target_scale, HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_interaction_tween.parallel().tween_property(host_control, "modulate", target_modulate, HOVER_DURATION)


func play_drag_preview(preview_control: Control) -> void:
	# 统一拖拽预览动效；所有系统使用相同呼吸幅度、周期与摆动角度。
	if preview_control == null:
		return
	preview_control.scale = Vector2.ONE * DRAG_PREVIEW_START_SCALE
	preview_control.pivot_offset = STANDARD_CARD_SIZE * 0.5
	var preview_tween: Tween = preview_control.create_tween().set_loops()
	preview_tween.tween_property(preview_control, "scale", Vector2.ONE * DRAG_PREVIEW_PULSE_SCALE, DRAG_PREVIEW_PULSE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	preview_tween.parallel().tween_property(preview_control, "rotation", DRAG_PREVIEW_TILT_RADIANS, DRAG_PREVIEW_PULSE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	preview_tween.tween_property(preview_control, "scale", Vector2.ONE, DRAG_PREVIEW_PULSE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	preview_tween.parallel().tween_property(preview_control, "rotation", -DRAG_PREVIEW_TILT_RADIANS, DRAG_PREVIEW_PULSE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func refresh_durability() -> void:
	# 耐久刷新只更新通用耐久组件，避免高频耐久变化重建完整卡片。
	if _durability_bar != null:
		_durability_bar.call("refresh")


static func get_standard_size() -> Vector2:
	# 标准尺寸查询；各系统布局应读取此值，避免再次硬编码不同卡片尺寸。
	return STANDARD_CARD_SIZE


func _draw() -> void:
	# 卡片背景；所有物品共享同一底色，合法目标只叠加统一绿色提示。
	var card_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(card_rect, NORMAL_BACKGROUND_COLOR, true)
	if _highlighted:
		draw_rect(card_rect, HIGHLIGHT_BACKGROUND_COLOR, true)
	if _cooldown_ratio > 0.0:
		# 冷却矩形；高度按卡片固定高度与剩余比例计算，文字仍绘制在遮罩上方以保持可读。
		var cooldown_height: float = size.y * _cooldown_ratio
		var cooldown_rect: Rect2 = Rect2(Vector2(0.0, size.y - cooldown_height), Vector2(size.x, cooldown_height))
		draw_rect(cooldown_rect, Color(1.0, 1.0, 1.0, 0.42), true)
	# 卡片边框；选中物品使用统一青色，其余物品使用统一蓝灰色。
	var border_color: Color = SELECTED_BORDER_COLOR if _selected else NORMAL_BORDER_COLOR
	draw_style_box(_create_border_style(border_color), card_rect)


func _build_content() -> void:
	if _context_label != null:
		return
	# 内容边距；顶部、左右与耐久条之间保持固定留白，确保所有物品排版完全一致。
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)
	# 三行信息容器；固定按上下文、名称、摘要排列，新增物品不得改变该结构。
	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 0)
	margin.add_child(content)
	_context_label = Label.new()
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_context_label.add_theme_font_size_override("font_size", 10)
	content.add_child(_context_label)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 13)
	content.add_child(_name_label)
	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = true
	_detail_label.scroll_active = false
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_label.custom_minimum_size = Vector2(0.0, 18.0)
	_detail_label.add_theme_font_size_override("normal_font_size", 10)
	content.add_child(_detail_label)
	_durability_bar = DURABILITY_BAR_SCRIPT.new() as Control
	add_child(_durability_bar)
	_disabled_overlay = ColorRect.new()
	_disabled_overlay.color = DISABLED_OVERLAY_COLOR
	_disabled_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disabled_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_disabled_overlay.visible = _disabled
	add_child(_disabled_overlay)


func _refresh_content() -> void:
	if _context_label == null or _name_label == null or _detail_label == null:
		return
	# 类型或职责文本；调用方未指定上下文时自动使用统一格式化器的物品类型。
	_context_label.text = _context_text if not _context_text.is_empty() else (_get_item_type_label() if _item_resource != null else "空槽")
	# 主名称文本；堆叠数量统一追加在名称末尾，所有系统使用相同格式。
	var display_name: String = _display_name_override if not _display_name_override.is_empty() else (_get_item_display_name() if _item_resource != null else _empty_text)
	_name_label.text = "%s  x%d" % [display_name, _quantity] if _item_resource != null and _quantity > 1 else display_name
	# 底部摘要；富文本由调用方提供，但字体、对齐和可用区域始终由通用卡片控制。
	_detail_label.text = "[center]%s[/center]" % _detail_bbcode if not _detail_bbcode.is_empty() else ""
	_durability_bar.call("configure", _item_resource)
	queue_redraw()


func _get_item_display_name() -> String:
	return str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", _item_resource))


func _get_item_type_label() -> String:
	return str(ITEM_DETAIL_FORMATTER.call("get_item_type_label", _item_resource))


func _create_border_style(border_color: Color) -> StyleBoxFlat:
	# 边框样式；透明内部只绘制统一圆角边界，背景由本控件先行绘制。
	var border_style: StyleBoxFlat = StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_color = border_color
	border_style.set_border_width_all(int(BORDER_WIDTH))
	border_style.set_corner_radius_all(int(CORNER_RADIUS))
	return border_style


func _stop_interaction_tween() -> void:
	# 补间清理；快速悬浮、拖拽或禁用切换时终止旧动画，避免比例和透明度累计。
	if _interaction_tween != null and _interaction_tween.is_valid():
		_interaction_tween.kill()
	_interaction_tween = null
