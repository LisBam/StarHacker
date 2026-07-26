extends ConfirmationDialog
class_name SaveDeletionConfirmationDialog

## 存档删除确认弹窗只负责展示永久删除警告，并校验玩家输入的固定确认短语。
## 弹窗不访问存档文件或业务服务；宿主收到 delete_confirmed 信号后负责提交最终删除命令。

signal delete_confirmed

## 全局窗口样式指南；统一输入框、危险按钮与弹窗背景视觉，不读取任何业务状态。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 弹窗最外层框架组件；直接绘制不透明标题栏、青蓝外框、标题文字和关闭按钮。
const DIALOG_OUTER_FRAME_SCRIPT: Script = preload("res://scripts/ui/dialog_outer_frame.gd")
## 删除确认短语；玩家必须逐字输入“确认删除”，不忽略空格或其他附加字符。
const CONFIRMATION_PHRASE: String = "确认删除"

## 弹窗默认宽度；默认 480 像素，可完整显示永久删除范围与固定确认短语，运行时无需动态修改。
@export_range(360, 680, 1) var dialog_width: int = 480
## 弹窗默认高度；默认 240 像素，可容纳警告、输入框、校验提示和操作按钮，运行时无需动态修改。
@export_range(210, 360, 1) var dialog_height: int = 240
## 弹窗背景透明度；默认 0.82，与项目专用输入弹窗保持一致，运行时无需动态修改。
@export_range(0.40, 1.0, 0.01) var dialog_background_alpha: float = 0.82

## 固定确认短语输入框；默认运行时创建，每次打开弹窗都会清空，内容完全匹配时才允许删除。
var _confirmation_input: LineEdit
## 输入校验提示；默认显示等待输入，错误内容使用危险色，正确内容使用成功色。
var _validation_label: Label
## 界面是否已经完成初始化；默认 false，公开展示接口会幂等创建全部控件与信号连接。
var _interface_initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_interface_initialized()


func present() -> void:
	## 展示全新确认流程；每次打开都清空历史输入，防止上一次正确短语被意外复用。
	_ensure_interface_initialized()
	_confirmation_input.clear()
	_refresh_confirmation_state("")
	popup_centered(Vector2i(dialog_width, dialog_height))
	_confirmation_input.call_deferred("grab_focus")


func is_confirmation_phrase_valid(input_text: String) -> bool:
	## 返回输入是否与固定短语完全一致；该纯校验接口便于宿主或自动验证复核危险操作门槛。
	return input_text == CONFIRMATION_PHRASE


func _ensure_interface_initialized() -> void:
	## 初始化专用输入控件与统一视觉；允许弹窗加入场景树后同一帧直接调用 present()。
	if _interface_initialized:
		return
	_interface_initialized = true
	transparent = false
	unresizable = true
	title = "删除存档"
	get_ok_button().text = "永久删除"
	get_cancel_button().text = "取消"
	_apply_dialog_visual_style()
	_build_interface()
	# 弹窗内部根面板；登记后黑白风格覆盖警告、输入框、校验文本和操作按钮。
	var dialog_content_root: Control = get_child(0, true) as Control
	if dialog_content_root != null:
		UI_STYLE_GUIDE.apply_screen_theme(dialog_content_root)
	DIALOG_OUTER_FRAME_SCRIPT.install(self)
	confirmed.connect(_on_confirmed)
	# UI 风格服务；弹窗可能在切换前已经初始化，监听后重建 Window 自身样式。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))


func _build_interface() -> void:
	## 创建固定内容结构；纵向排列永久删除说明、输入框与即时校验结果。
	# 内容边距；保留标题栏与操作区净空，避免文字或输入框贴近最外层描边。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 14)
	content_margin.add_theme_constant_override("margin_top", 10)
	content_margin.add_theme_constant_override("margin_right", 14)
	content_margin.add_theme_constant_override("margin_bottom", 2)
	add_child(content_margin)
	# 内容容器；使用稳定间距保证警告、输入与反馈在窄窗口中仍清晰分组。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content_margin.add_child(content)
	# 删除范围说明；明确所有永久进度和自定义设置都会清空，避免玩家误认为只删除战斗进度。
	var warning_label: Label = Label.new()
	warning_label.custom_minimum_size = Vector2(float(dialog_width - 56), 0.0)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.text = "此操作会永久删除角色、物品、货币、商店、股市、矿场、按键、UI 风格与调试设置。\n请输入“%s”后才能继续。" % CONFIRMATION_PHRASE
	warning_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.DANGER_COLOR)
	content.add_child(warning_label)
	# 确认短语输入框；不使用占位内容代替真实输入，玩家必须主动键入完整四字短语。
	var confirmation_input: LineEdit = LineEdit.new()
	confirmation_input.name = "ConfirmationInput"
	confirmation_input.custom_minimum_size = Vector2(0.0, 38.0)
	confirmation_input.placeholder_text = CONFIRMATION_PHRASE
	confirmation_input.clear_button_enabled = true
	confirmation_input.text_changed.connect(_on_confirmation_text_changed)
	content.add_child(confirmation_input)
	_confirmation_input = confirmation_input
	# 校验提示；即时说明当前输入能否执行删除，不把按钮禁用作为唯一反馈。
	var validation_label: Label = Label.new()
	validation_label.name = "ValidationLabel"
	validation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	validation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(validation_label)
	_validation_label = validation_label


func _apply_dialog_visual_style() -> void:
	## 应用深色窗口、统一输入主题和危险确认按钮，保持设置页与其他专用弹窗一致。
	# 弹窗主题；复用全局控件状态并覆盖窗口面板透明度、描边、圆角和内容安全区域。
	var dialog_theme: Theme = UI_STYLE_GUIDE.create_theme()
	# 弹窗面板样式；标题栏净空由全局常量维护，底部净空保证操作按钮不贴住外框。
	# 统一样式补充；边框与圆角改由样式指南 create_dialog_panel_style() 统一生成 2 像素边框与 8 像素圆角，透明度沿用本弹窗 0.82 导出参数。
	var dialog_panel_style: StyleBoxFlat = UI_STYLE_GUIDE.create_dialog_panel_style(dialog_background_alpha)
	# 面板左右留白；统一函数默认 14 像素，本弹窗内容已有专用 MarginContainer，回退为跟随边框的自动留白以保持原布局。
	dialog_panel_style.content_margin_left = -1.0
	dialog_panel_style.content_margin_right = -1.0
	dialog_panel_style.content_margin_top = UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT
	dialog_panel_style.content_margin_bottom = UI_STYLE_GUIDE.DIALOG_ACTION_BOTTOM_CLEARANCE
	dialog_theme.set_stylebox("panel", "Window", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "AcceptDialog", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "ConfirmationDialog", dialog_panel_style)
	theme = dialog_theme
	UI_STYLE_GUIDE.apply_danger_button(get_ok_button())
	get_ok_button().custom_minimum_size = Vector2(112.0, 36.0)
	get_cancel_button().custom_minimum_size = Vector2(96.0, 36.0)


func _on_ui_style_changed(_style_id: String) -> void:
	## 风格切换后重建删除弹窗背景、边框和按钮主题，输入内容与校验状态保持不变。
	_apply_dialog_visual_style()
	DIALOG_OUTER_FRAME_SCRIPT.install(self)


func _on_confirmation_text_changed(input_text: String) -> void:
	## 根据当前输入即时刷新危险操作门槛；任何多字、少字或附加空格都会保持禁用。
	_refresh_confirmation_state(input_text)


func _refresh_confirmation_state(input_text: String) -> void:
	## 同步确认按钮与反馈文本，保证可见状态和最终校验使用同一条精确匹配规则。
	# 当前输入是否合法；仅完全等于固定四字短语时为 true。
	var is_valid: bool = is_confirmation_phrase_valid(input_text)
	get_ok_button().disabled = not is_valid
	if is_valid:
		_validation_label.text = "确认短语正确，可以永久删除存档。"
		_validation_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.SUCCESS_COLOR)
		return
	_validation_label.text = "请输入完整的“%s”。" % CONFIRMATION_PHRASE
	_validation_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.DANGER_COLOR if not input_text.is_empty() else UI_STYLE_GUIDE.SECONDARY_TEXT_COLOR)


func _on_confirmed() -> void:
	## 在原生确认信号触发后再次校验输入，防止脚本或焦点事件绕过按钮禁用状态。
	if _confirmation_input == null or not is_confirmation_phrase_valid(_confirmation_input.text):
		return
	delete_confirmed.emit()
