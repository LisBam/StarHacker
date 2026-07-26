extends Control
class_name VerticalSplitHandle

## 垂直区域分隔拖条只负责把鼠标纵向拖动转换为 0 到 1 的布局占比。
## 具体上下区域由宿主面板决定，组件不依赖仓库、背包或任何库存服务。

signal split_ratio_changed(ratio: float)

## 全局窗口样式指南；自绘拖条从这里读取当前分栏色板与强调色，避免黑白简约风下残留固定蓝色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 最小占比；默认 0.20，防止上方区域被压缩到无法操作。
## 可调范围补充：当前最小值放宽为 0.10，便于玩家按实际需要缩小仓库区域。
@export_range(0.05, 0.90, 0.01) var minimum_ratio: float = 0.10
## 最大占比；默认 0.75，保证下方区域始终保留足够操作空间。
## 可调范围补充：当前最大值放宽为 0.90，下方区域由外层滚动容器保证内容仍可访问。
@export_range(0.10, 0.95, 0.01) var maximum_ratio: float = 0.90
## 拖条背景颜色；默认半透明深色，用于和上下内容区分。
@export var background_color: Color = Color(0.08, 0.11, 0.14, 0.96)
## 拖条中心线颜色；默认浅青色，提示该区域可以拖动。
@export var line_color: Color = Color(0.42, 0.78, 0.90, 0.92)
## 是否跟随全局 UI 色板；默认 true，设置为 false 时才使用本组件的导出颜色作为局部特例。
@export var use_ui_style_palette: bool = true

## 当前上方区域占比；默认 0.38，由宿主配置并在拖动期间持续更新。
var _current_ratio: float = 0.38
## 是否正在拖动；默认 false，仅鼠标左键按下拖条后进入拖动状态。
var _dragging: bool = false
## 是否处于鼠标悬停；默认 false，悬停或拖动时中心线切换为强调色并加粗，提示当前可以拖动。
var _hovered: bool = false
## 拖动起始鼠标纵坐标；默认 0，开始拖动时记录全局坐标。
var _drag_start_y: float = 0.0
## 拖动起始占比；默认 0.38，用于把本次鼠标位移叠加到稳定基准。
var _drag_start_ratio: float = 0.38
## 本次拖动使用的稳定高度；默认 1，按下拖条时缓存父容器高度，布局变化期间不重新计算以避免抽搐。
var _drag_available_height: float = 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 12.0)
	mouse_default_cursor_shape = Control.CURSOR_VSIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process_input(false)
	queue_redraw()


func configure(initial_ratio: float) -> void:
	_current_ratio = clampf(initial_ratio, minimum_ratio, maximum_ratio)
	_drag_start_ratio = _current_ratio


func _notification(what: int) -> void:
	## 主题根切换时请求重绘；自绘拖条不自动读取 Theme 资源，必须显式刷新当前色板。
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	# 当前拖条背景色；默认实时读取全局风格色板，局部特例可通过检查器关闭色板跟随。
	var resolved_background_color: Color = UI_STYLE_GUIDE.get_split_handle_background_color() if use_ui_style_palette else background_color
	# 当前中心线颜色；悬停或拖动时改用通用强调色，普通状态按色板开关选择全局或局部颜色。
	var resolved_line_color: Color = UI_STYLE_GUIDE.get_accent_color() if _hovered or _dragging else (UI_STYLE_GUIDE.get_split_handle_line_color() if use_ui_style_palette else line_color)
	# 当前中心线宽度；悬停或拖动时从 2 像素加粗到 3 像素，明确拖条处于可交互反馈状态。
	var resolved_line_width: float = 3.0 if _hovered or _dragging else 2.0
	# 完整背景矩形；覆盖拖条全部尺寸以扩大可点击区域。
	var background_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(background_rect, resolved_background_color, true)
	# 中心线纵坐标；默认位于拖条高度中央。
	var center_y: float = size.y * 0.5
	draw_line(Vector2(12.0, center_y), Vector2(maxf(size.x - 12.0, 12.0), center_y), resolved_line_color, resolved_line_width)


func _on_mouse_entered() -> void:
	## 记录悬停状态；进入拖条后中心线切换强调色并加粗，提示当前区域可以拖动。
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	## 清除悬停状态；拖动中移出拖条仍由拖动状态维持高亮，结束拖动后恢复普通视觉。
	_hovered = false
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	# 鼠标按钮事件；只响应左键按下，释放由全局输入继续接收，避免拖条移动后失去鼠标事件。
	var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button_event.button_index != MOUSE_BUTTON_LEFT or not mouse_button_event.pressed:
		return
	_dragging = true
	_drag_start_y = mouse_button_event.global_position.y
	_drag_start_ratio = _current_ratio
	_drag_available_height = maxf((get_parent() as Control).size.y - size.y if get_parent() is Control else 1.0, 1.0)
	set_process_input(true)
	queue_redraw()
	accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton:
		# 全局释放事件；无论鼠标是否仍位于移动后的拖条上，都能稳定结束拖动状态。
		var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT and not mouse_button_event.pressed:
			_dragging = false
			set_process_input(false)
			queue_redraw()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseMotion):
		return
	# 鼠标移动事件；使用按下时缓存的全局起点和稳定高度换算比例，不受布局实时重排影响。
	var mouse_motion_event: InputEventMouseMotion = event as InputEventMouseMotion
	# 新占比；鼠标向下拖动时扩大上方区域，向上拖动时扩大下方区域。
	var resolved_ratio: float = clampf(_drag_start_ratio + (mouse_motion_event.global_position.y - _drag_start_y) / _drag_available_height, minimum_ratio, maximum_ratio)
	if is_equal_approx(resolved_ratio, _current_ratio):
		return
	_current_ratio = resolved_ratio
	split_ratio_changed.emit(_current_ratio)
	get_viewport().set_input_as_handled()
