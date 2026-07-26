extends AcceptDialog
class_name StockRecordListDialog

## 记录列表弹窗负责展示交易历史记录与通知中心等只读文本列表，不访问股市服务或存档。
## 宿主传入标题与已格式化的富文本行；弹窗只做滚动展示，打开期间可原位更新内容而不重建窗口。

## 全局窗口样式指南；统一记录窗口的按钮、滚动条与面板主题。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 弹窗最外层框架组件；直接绘制不透明标题栏、外框、标题文字和关闭按钮。
const DIALOG_OUTER_FRAME_SCRIPT: Script = preload("res://scripts/ui/dialog_outer_frame.gd")

## 弹窗默认宽度；默认 560 像素，可完整显示时间前缀与单行交易说明，运行时无需动态修改。
@export_range(420, 900, 1) var dialog_width: int = 560
## 弹窗默认高度；默认 420 像素，约可同屏展示 12 条记录，其余通过滚动查看，运行时无需动态修改。
@export_range(240, 620, 1) var dialog_height: int = 420
## 弹窗背景透明度；默认 0.82，与股市其他弹窗保持一致，运行时无需动态修改。
@export_range(0.40, 1.0, 0.01) var dialog_background_alpha: float = 0.82
## 记录行间距；默认 6 像素，保证时间前缀与多行换行说明仍可逐条区分，运行时无需动态修改。
@export_range(0, 16, 1) var record_line_separation: int = 6

## 记录滚动容器；默认运行时创建，记录超出可视高度时提供纵向滚动。
var _record_scroll: ScrollContainer
## 记录富文本控件；默认运行时创建，按行展示宿主传入的 bbcode 记录文本。
var _record_label: RichTextLabel
## 界面是否已经初始化；默认 false，公开展示接口通过幂等初始化保证控件可用。
var _interface_initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_interface_initialized()


func present_records(dialog_title: String, record_lines: Array[String], empty_hint: String) -> void:
	## 展示记录窗口；记录按传入顺序纵向排列，宿主保证索引 0 为最新记录。
	_ensure_interface_initialized()
	title = dialog_title
	update_records(record_lines, empty_hint)
	if _record_scroll != null:
		# 打开时回到顶部；最新记录始终第一屏可见。
		_record_scroll.scroll_vertical = 0
	popup_centered(Vector2i(dialog_width, dialog_height))


func update_records(record_lines: Array[String], empty_hint: String) -> void:
	## 原位更新记录内容；窗口打开期间新增记录时不重建窗口，也不重置玩家当前滚动位置。
	if _record_label == null:
		return
	if record_lines.is_empty():
		_record_label.text = "[color=gray]%s[/color]" % empty_hint
		return
	_record_label.text = "\n".join(record_lines)


func _ensure_interface_initialized() -> void:
	## 初始化记录列表控件与统一视觉；允许弹窗创建后同一帧直接调用展示接口。
	if _interface_initialized:
		return
	_interface_initialized = true
	# 窗口透明模式；关闭原生透明合成，保证最外层背景和描边完全可见。
	transparent = false
	unresizable = true
	get_ok_button().text = "关闭"
	_apply_dialog_visual_style()
	_build_interface()
	# 弹窗内部根面板；登记后 UI 风格切换会同步刷新滚动区与按钮主题。
	var dialog_content_root: Control = get_child(0, true) as Control
	if dialog_content_root != null:
		UI_STYLE_GUIDE.apply_screen_theme(dialog_content_root)
	DIALOG_OUTER_FRAME_SCRIPT.install(self)
	# UI 风格服务；弹窗可能在设置切换前已经初始化，监听后重建 Window 自身样式。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))


func _build_interface() -> void:
	## 创建固定内容结构；外层留白内嵌纵向滚动容器与自动换行的富文本记录列表。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_bottom", 1)
	add_child(content_margin)
	_record_scroll = ScrollContainer.new()
	_record_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_record_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# 滚动区最小尺寸；按窗口尺寸扣除标题栏、按钮区和左右留白，保证首次打开即为稳定布局。
	_record_scroll.custom_minimum_size = Vector2(float(dialog_width - 48), float(dialog_height - 132))
	content_margin.add_child(_record_scroll)
	_record_label = RichTextLabel.new()
	_record_label.bbcode_enabled = true
	_record_label.fit_content = true
	_record_label.scroll_active = false
	_record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_record_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_record_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_record_label.add_theme_constant_override("line_separation", record_line_separation)
	_record_label.add_theme_font_size_override("normal_font_size", 14)
	_record_scroll.add_child(_record_label)


func _apply_dialog_visual_style() -> void:
	## 应用半透明深色窗口样式；规格与股市其他弹窗一致，保持整套股市界面视觉统一。
	var dialog_theme: Theme = UI_STYLE_GUIDE.create_theme()
	# 窗口面板样式；透明度由检查器参数统一控制。
	var dialog_panel_style: StyleBoxFlat = UI_STYLE_GUIDE.create_dialog_panel_style(dialog_background_alpha)
	# 面板左右留白；内容已有专用 MarginContainer，回退为跟随边框的自动留白以保持布局稳定。
	dialog_panel_style.content_margin_left = -1.0
	dialog_panel_style.content_margin_right = -1.0
	dialog_panel_style.content_margin_top = UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT
	dialog_panel_style.content_margin_bottom = UI_STYLE_GUIDE.DIALOG_ACTION_BOTTOM_CLEARANCE
	dialog_theme.set_stylebox("panel", "Window", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "AcceptDialog", dialog_panel_style)
	theme = dialog_theme


func _on_ui_style_changed(_style_id: String) -> void:
	## 风格切换后重建记录弹窗背景、边框和基础控件主题，当前展示内容保持不变。
	_apply_dialog_visual_style()
	DIALOG_OUTER_FRAME_SCRIPT.install(self)
