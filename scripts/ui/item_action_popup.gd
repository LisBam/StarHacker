extends PopupPanel
class_name ItemActionPopup

## 标准物品操作弹窗统一承载点击物品后出现的出售、丢弃、装备、使用和送回等功能按钮。
## 非物品界面按钮不得复用本组件，避免主菜单、设置和普通面板操作被物品交互样式意外覆盖。

signal action_pressed(action_id: int)

## 全局窗口样式指南；弹窗背景、按钮状态与危险变体统一读取当前 UI 风格，保证黑蓝与黑白双风格即时切换。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 弹窗固定宽度；默认 104 像素，比上一版进一步缩短横向长度，减少对相邻物品卡片的遮挡。
@export_range(92.0, 480.0, 1.0) var popup_width: float = 104.0
## 单个功能按钮最小高度；默认 27 像素，比上一版提高 50%，增强文字可读性和点击稳定性。
@export_range(20.0, 72.0, 1.0) var action_button_height: float = 27.0
## 按钮悬停缩放；默认 1.025，仅提供轻量视觉反馈，不改变弹窗整体布局。
@export_range(1.0, 1.12, 0.005) var hover_scale: float = 1.025
## 按钮按压缩放；默认 0.97，用于确认点击已经被接收。
@export_range(0.85, 1.0, 0.005) var pressed_scale: float = 0.97
## 悬停与恢复动画时长；默认 0.10 秒，兼顾响应速度与视觉平滑度。
@export_range(0.02, 0.30, 0.01) var hover_duration: float = 0.10
## 按压动画时长；默认 0.06 秒，使功能操作保持干脆反馈。
@export_range(0.02, 0.20, 0.01) var pressed_duration: float = 0.06

## 操作按钮纵向容器；每次清空菜单时只移除其子按钮，不重建弹窗外壳。
var _action_list: VBoxContainer
## 当前操作按钮数量；用于根据内容计算弹窗高度，默认 0 表示没有可显示操作。
var _action_count: int = 0
## 每个按钮的活动补间；键为按钮实例编号，值为当前缩放 Tween，替换动画前必须终止旧补间。
var _button_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	# UI 风格服务；弹窗实例被宿主长期持有复用，监听切换信号后立即重建背景，隐藏期间同样生效。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))


func clear_actions() -> void:
	# 操作数量；清空后用于阻止没有功能按钮的空弹窗显示。
	_action_count = 0
	# 补间缓存；子按钮即将释放，旧 Tween 不再参与后续交互。
	_button_tweens.clear()
	if _action_list == null:
		return
	for child in _action_list.get_children():
		# 立即移出布局；同一帧重建菜单时旧按钮不会继续占据容器尺寸或短暂重复显示。
		_action_list.remove_child(child)
		child.queue_free()


func add_action(action_text: String, action_id: int, disabled: bool = false, destructive: bool = false) -> Button:
	# 功能按钮；每个物品操作都使用同一尺寸、字体、主题样式与动效连接。
	var action_button: Button = Button.new()
	action_button.text = action_text
	action_button.disabled = disabled
	action_button.custom_minimum_size = Vector2(popup_width - 12.0, action_button_height)
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.add_theme_font_size_override("font_size", 12)
	_apply_button_styles(action_button, destructive)
	action_button.mouse_entered.connect(_on_button_mouse_entered.bind(action_button))
	action_button.mouse_exited.connect(_on_button_mouse_exited.bind(action_button))
	action_button.button_down.connect(_on_button_down.bind(action_button))
	action_button.button_up.connect(_on_button_up.bind(action_button))
	action_button.pressed.connect(_on_action_button_pressed.bind(action_id))
	_action_list.add_child(action_button)
	_action_count += 1
	return action_button


func popup_at(screen_position: Vector2) -> void:
	if _action_count <= 0:
		return
	# 弹窗高度；上下边距合计 11 像素，按钮间距每项 3 像素，与按钮尺寸同步提高约 50%。
	var popup_height: float = 11.0 + float(_action_count) * action_button_height + float(maxi(_action_count - 1, 0)) * 3.0
	size = Vector2i(roundi(popup_width), roundi(popup_height))
	position = Vector2i(screen_position)
	popup()


func present_at(screen_position: Vector2) -> void:
	## 通过项目统一的 present 前缀展示物品操作弹窗；坐标使用视口屏幕坐标，旧 popup_at() 接口继续保留兼容既有扩展。
	popup_at(screen_position)


func _build_interface() -> void:
	# 弹窗背景；深蓝灰底、亮边框和圆角用于与物品卡片保持同一视觉语言。
	# 风格化补充：底色与描边现读取当前 UI 风格窗口色板，构建集中在 _apply_popup_panel_style() 以支持切换后重建。
	_apply_popup_panel_style()
	# 外层边距；防止功能按钮紧贴弹窗边框，并为缩放动效保留少量空间。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	# 统一主题继承；弹窗根控件安装完整控件主题并自动登记，风格切换时全部功能按钮即时刷新。
	UI_STYLE_GUIDE.apply_screen_theme(margin)
	# 操作列表；功能按钮仅纵向排列，避免不同界面自行决定尺寸或间距。
	_action_list = VBoxContainer.new()
	_action_list.add_theme_constant_override("separation", 3)
	margin.add_child(_action_list)


func _apply_popup_panel_style() -> void:
	## 按当前 UI 风格重建弹窗背景；宿主长期持有的复用实例在风格切换后再次调用即可恢复一致外观。
	# 弹窗背景样式；底色与描边读取当前风格窗口色板，透明度保留原弹窗轻浮层意图，圆角与阴影维持原布局。
	var popup_style: StyleBoxFlat = StyleBoxFlat.new()
	popup_style.bg_color = Color(UI_STYLE_GUIDE.get_window_background_color(), 0.98)
	popup_style.border_color = Color(UI_STYLE_GUIDE.get_window_border_color(), 0.95)
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(6)
	popup_style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	popup_style.shadow_size = 5
	add_theme_stylebox_override("panel", popup_style)


func _on_ui_style_changed(_style_id: String) -> void:
	## 响应全局 UI 风格切换；弹窗无论当前可见与否都立即重建背景，下次显示即为新风格。
	_apply_popup_panel_style()


func _apply_button_styles(action_button: Button, destructive: bool) -> void:
	## 按钮不再自建 StyleBox 状态机；normal、hover、pressed、disabled 与 focus 全部继承统一主题并随风格切换自动刷新。
	# 破坏性操作；丢弃、销毁类按钮启用统一暗红危险变体，该语义色在黑白风格下保持不变。
	if destructive:
		UI_STYLE_GUIDE.apply_danger_button(action_button)


func _on_button_mouse_entered(action_button: Button) -> void:
	if action_button.disabled:
		return
	_animate_button_scale(action_button, hover_scale, hover_duration)


func _on_button_mouse_exited(action_button: Button) -> void:
	_animate_button_scale(action_button, 1.0, hover_duration)


func _on_button_down(action_button: Button) -> void:
	if action_button.disabled:
		return
	_animate_button_scale(action_button, pressed_scale, pressed_duration)


func _on_button_up(action_button: Button) -> void:
	if action_button.disabled:
		return
	_animate_button_scale(action_button, hover_scale if action_button.is_hovered() else 1.0, hover_duration)


func _animate_button_scale(action_button: Button, target_scale: float, duration: float) -> void:
	# 按钮实例编号；作为补间缓存键，避免快速移入移出产生多条同时写入 scale 的动画。
	var button_id: int = action_button.get_instance_id()
	# 旧补间；仍有效时立即终止，再从当前缩放平滑过渡到新目标。
	var existing_tween: Tween = _button_tweens.get(button_id) as Tween
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()
	action_button.pivot_offset = action_button.size * 0.5
	var scale_tween: Tween = action_button.create_tween()
	scale_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	scale_tween.tween_property(action_button, "scale", Vector2.ONE * target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_button_tweens[button_id] = scale_tween


func _on_action_button_pressed(action_id: int) -> void:
	hide()
	action_pressed.emit(action_id)
