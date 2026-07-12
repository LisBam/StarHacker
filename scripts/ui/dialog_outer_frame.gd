extends Control
class_name DialogOuterFrame

## 弹窗最外层框架组件负责绘制不透明标题栏、青蓝外框、标题文字和关闭按钮。
## 组件只依赖 Window 标准接口，不读取任何业务服务，可复用于确认、数量、转账和结果弹窗。

## 全局窗口样式指南；集中提供外框颜色、尺寸、圆角、标题高度和按钮样式。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 组件稳定节点名称；用于重复安装时查找既有实例，避免同一弹窗叠加多层外框。
const COMPONENT_NODE_NAME: StringName = &"DialogOuterFrame"

## 所属弹窗；默认 null，安装时绑定，标题同步和关闭操作均通过标准 Window 接口完成。
var _dialog: Window
## 自定义标题文本；默认运行时创建，始终与 Window.title 保持一致。
var _title_label: Label
## 自定义关闭按钮；默认运行时创建，替代无系统边框模式下被隐藏的原生标题栏关闭入口。
var _close_button: Button


static func install(dialog: Window) -> DialogOuterFrame:
	## 为弹窗安装唯一外框组件并返回实例；重复调用不会创建额外节点。
	if dialog == null:
		return null
	# 既有组件；弹窗重复应用主题时继续复用原节点并刷新标题。
	var existing_frame: DialogOuterFrame = dialog.find_child(str(COMPONENT_NODE_NAME), true, false) as DialogOuterFrame
	if existing_frame != null:
		existing_frame._refresh_title()
		existing_frame.queue_redraw()
		return existing_frame
	# 原生全尺寸面板；AcceptDialog 会重排直属自定义子节点，挂载到内部 Panel 才能稳定覆盖完整窗口。
	var frame_parent: Control = dialog.get_child(0, true) as Control
	if frame_parent == null:
		return null
	# 新外框组件；作为全尺寸面板子节点安装，不参与正文和按钮的自动布局计算。
	var frame: DialogOuterFrame = DialogOuterFrame.new()
	frame.name = COMPONENT_NODE_NAME
	frame._dialog = dialog
	dialog.borderless = true
	dialog.transparent = false
	frame_parent.add_child(frame)
	return frame


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_build_interface()
	if _dialog != null and not _dialog.title_changed.is_connected(_refresh_title):
		_dialog.title_changed.connect(_refresh_title)
	_refresh_title()
	queue_redraw()


func _draw() -> void:
	# 标题栏矩形；完全不透明的深蓝背景保证标题区域不会透出场景颜色。
	var title_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(size.x, UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT))
	draw_rect(title_rect, UI_STYLE_GUIDE.DIALOG_TITLE_BACKGROUND_COLOR, true)
	# 标题分隔线起点；位于标题栏底部并避开外框左右描边。
	var separator_start: Vector2 = Vector2(float(UI_STYLE_GUIDE.DIALOG_OUTER_BORDER_WIDTH), UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT)
	# 标题分隔线终点；与起点共同形成横跨窗口内部的连续青蓝细线。
	var separator_end: Vector2 = Vector2(size.x - float(UI_STYLE_GUIDE.DIALOG_OUTER_BORDER_WIDTH), UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT)
	draw_line(separator_start, separator_end, UI_STYLE_GUIDE.WINDOW_BORDER_COLOR, 1.0)
	# 最外层边框；仅绘制轮廓不覆盖内部控件，始终位于弹窗内容和按钮上方。
	var outer_style: StyleBoxFlat = UI_STYLE_GUIDE.create_dialog_outer_frame_style()
	draw_style_box(outer_style, Rect2(Vector2.ZERO, size))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _build_interface() -> void:
	## 创建标题文字和关闭入口；两者只占用标题栏，不接管弹窗正文或确认按钮布局。
	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.ACCENT_COLOR)
	_title_label.add_theme_font_size_override("font_size", UI_STYLE_GUIDE.DIALOG_TITLE_FONT_SIZE)
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_left = UI_STYLE_GUIDE.DIALOG_TITLE_SIDE_PADDING
	_title_label.offset_top = 0.0
	_title_label.offset_right = -UI_STYLE_GUIDE.DIALOG_TITLE_SIDE_PADDING
	_title_label.offset_bottom = UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT
	add_child(_title_label)
	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.flat = true
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_close_button.offset_left = -UI_STYLE_GUIDE.DIALOG_CLOSE_BUTTON_SIZE - float(UI_STYLE_GUIDE.DIALOG_OUTER_BORDER_WIDTH)
	_close_button.offset_top = float(UI_STYLE_GUIDE.DIALOG_OUTER_BORDER_WIDTH)
	_close_button.offset_right = -float(UI_STYLE_GUIDE.DIALOG_OUTER_BORDER_WIDTH)
	_close_button.offset_bottom = UI_STYLE_GUIDE.DIALOG_CLOSE_BUTTON_SIZE + float(UI_STYLE_GUIDE.DIALOG_OUTER_BORDER_WIDTH)
	_close_button.pressed.connect(_on_close_button_pressed)
	add_child(_close_button)


func _refresh_title() -> void:
	## 同步 Window 标题到自定义标题栏；业务弹窗继续只维护原有 title 属性。
	if _title_label == null or _dialog == null:
		return
	_title_label.text = _dialog.title


func _on_close_button_pressed() -> void:
	## 关闭弹窗并发出取消信号；行为与确认弹窗原生标题栏关闭按钮保持一致。
	if _dialog == null:
		return
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).canceled.emit()
	_dialog.hide()
