extends Control
class_name ProgressSliderVisual

## 可视进度拖动条组件覆盖在原生 HSlider 上方，负责绘制未完成轨道、已完成进度与滑块。
## 原生 HSlider 继续独立处理鼠标、键盘、步长、最小值和最大值，本组件不修改任何业务数值。

## 全局 UI 样式指南；自绘层从这里读取当前滑条色板，避免绕过主题而固定使用青蓝色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 子节点固定名称；安装接口通过该名称避免同一个 HSlider 重复挂载多个视觉层。
const VISUAL_NODE_NAME: StringName = &"ProgressSliderVisual"

## 拖动条最小高度；默认 32 像素，为 8 像素轨道、16 像素滑块和上下留白提供稳定空间。
@export_range(24.0, 64.0, 1.0) var minimum_slider_height: float = 32.0
## 轨道线宽；默认 8 像素，确保数量与音量变化在普通分辨率下清晰可见。
@export_range(3.0, 18.0, 1.0) var track_width: float = 8.0
## 滑块半径；默认 8 像素，鼠标悬停或拖动时额外增加 1 像素。
@export_range(4.0, 16.0, 1.0) var handle_radius: float = 8.0
## 未完成轨道颜色；默认深蓝灰，用于表示当前值之后仍可选择的范围。
@export var track_background_color: Color = Color(0.025, 0.055, 0.072, 1.0)
## 未完成轨道边缘颜色；默认低饱和青灰，提供完整范围边界。
@export var track_border_color: Color = Color(0.20, 0.38, 0.47, 0.95)
## 已完成进度颜色；默认明亮青蓝，长度随 HSlider 当前值实时变化。
@export var progress_color: Color = Color(0.10, 0.58, 0.72, 1.0)
## 已完成进度高亮颜色；默认用于鼠标悬停与拖动状态，提高当前进度辨识度。
@export var progress_highlight_color: Color = Color(0.16, 0.76, 0.90, 1.0)
## 滑块外圈颜色；默认亮青色，用于区分当前值位置与轨道填充终点。
@export var handle_border_color: Color = Color(0.55, 0.92, 1.0, 1.0)
## 滑块内部颜色；默认浅蓝白色，保证深色窗口和亮色进度上都清晰可见。
@export var handle_fill_color: Color = Color(0.88, 0.98, 1.0, 1.0)
## 禁用进度颜色；默认低饱和灰蓝，保留当前进度位置但明确不可交互。
@export var disabled_progress_color: Color = Color(0.28, 0.36, 0.40, 0.88)
## 是否跟随全局 UI 色板；默认 true，设置为 false 时才使用本组件的导出颜色作为局部特例。
@export var use_ui_style_palette: bool = true

## 关联的原生拖动条；默认 null，由 install() 在挂载时配置，只读取其范围、当前值和交互状态。
var _slider: HSlider
## 上一帧最小值；默认负无穷，用于识别 set_value_no_signal 等不发信号的范围变化。
var _last_minimum_value: float = -INF
## 上一帧最大值；默认负无穷，用于识别数量上限动态调整。
var _last_maximum_value: float = -INF
## 上一帧当前值；默认负无穷，变化后请求重新绘制进度长度。
var _last_value: float = -INF
## 上一帧鼠标悬停状态；默认 false，进入或离开时刷新高亮颜色和滑块尺寸。
var _last_hovered: bool = false
## 当前是否正在拖动滑块；默认 false，拖动期间保持高亮视觉直到原生 HSlider 发出结束信号。
var _dragging: bool = false


static func install(slider: HSlider) -> void:
	## 为指定 HSlider 安装唯一可视进度层；空引用或已经安装时直接返回。
	if slider == null or slider.get_node_or_null(NodePath(String(VISUAL_NODE_NAME))) != null:
		return
	# 新视觉层；生命周期跟随拖动条，不持有业务面板引用。
	var visual: ProgressSliderVisual = ProgressSliderVisual.new()
	visual.name = VISUAL_NODE_NAME
	slider.add_child(visual)
	visual._configure(slider)


func _configure(slider: HSlider) -> void:
	## 配置原生拖动条引用与覆盖布局；只允许 install() 在创建后调用一次。
	_slider = slider
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slider.custom_minimum_size.y = maxf(_slider.custom_minimum_size.y, minimum_slider_height)
	_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _slider.has_signal("drag_started") and not _slider.is_connected("drag_started", Callable(self, "_on_drag_started")):
		_slider.connect("drag_started", Callable(self, "_on_drag_started"))
	if _slider.has_signal("drag_ended") and not _slider.is_connected("drag_ended", Callable(self, "_on_drag_ended")):
		_slider.connect("drag_ended", Callable(self, "_on_drag_ended"))
	if not _slider.mouse_entered.is_connected(_on_mouse_entered):
		_slider.mouse_entered.connect(_on_mouse_entered)
	if not _slider.mouse_exited.is_connected(_on_mouse_exited):
		_slider.mouse_exited.connect(_on_mouse_exited)
	set_process(true)
	queue_redraw()


func _notification(what: int) -> void:
	## 主题根切换时请求重绘；自绘滑条不自动读取 Theme 资源，必须显式刷新当前色板。
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _process(_delta: float) -> void:
	if _slider == null or not is_instance_valid(_slider):
		set_process(false)
		return
	if is_equal_approx(_last_minimum_value, _slider.min_value) and is_equal_approx(_last_maximum_value, _slider.max_value) and is_equal_approx(_last_value, _slider.value):
		return
	_last_minimum_value = _slider.min_value
	_last_maximum_value = _slider.max_value
	_last_value = _slider.value
	queue_redraw()


func _draw() -> void:
	if _slider == null or not is_instance_valid(_slider) or size.x <= 0.0 or size.y <= 0.0:
		return
	# 轨道中心纵坐标；始终位于控件垂直中心，不受父布局高度变化影响。
	var center_y: float = size.y * 0.5
	# 轨道水平内缩；为滑块半径和外圈保留空间，最小值与最大值滑块不会被控件边缘裁剪。
	var horizontal_inset: float = handle_radius + 2.0
	# 轨道起点；表示最小值位置。
	var track_start_x: float = horizontal_inset
	# 轨道终点；表示最大值位置，并保证异常窄控件仍有非负长度。
	var track_end_x: float = maxf(size.x - horizontal_inset, track_start_x)
	# 当前标准化比例；取值 0 到 1，最小值等于最大值时安全回退为 0。
	var value_ratio: float = _get_value_ratio()
	# 当前滑块横坐标；同时作为已完成进度终点。
	var handle_x: float = lerpf(track_start_x, track_end_x, value_ratio)
	# 当前风格色板；默认实时读取全局主题，局部特例可通过检查器关闭色板跟随。
	var resolved_track_background_color: Color = UI_STYLE_GUIDE.get_slider_track_background_color() if use_ui_style_palette else track_background_color
	var resolved_track_border_color: Color = UI_STYLE_GUIDE.get_slider_track_border_color() if use_ui_style_palette else track_border_color
	var resolved_progress_color: Color = UI_STYLE_GUIDE.get_slider_progress_color() if use_ui_style_palette else progress_color
	var resolved_progress_highlight_color: Color = UI_STYLE_GUIDE.get_slider_progress_highlight_color() if use_ui_style_palette else progress_highlight_color
	var resolved_handle_border_color: Color = UI_STYLE_GUIDE.get_slider_handle_border_color() if use_ui_style_palette else handle_border_color
	var resolved_handle_fill_color: Color = UI_STYLE_GUIDE.get_slider_handle_fill_color() if use_ui_style_palette else handle_fill_color
	var resolved_disabled_progress_color: Color = UI_STYLE_GUIDE.get_slider_disabled_progress_color() if use_ui_style_palette else disabled_progress_color
	_draw_rounded_segment(track_start_x, track_end_x, center_y, resolved_track_border_color, track_width + 2.0)
	_draw_rounded_segment(track_start_x, track_end_x, center_y, resolved_track_background_color, track_width)
	# 当前进度颜色；禁用时灰显，悬停或拖动时使用当前风格的高亮色。
	var active_progress_color: Color = resolved_disabled_progress_color if _slider.editable == false else (resolved_progress_highlight_color if _last_hovered or _dragging else resolved_progress_color)
	if value_ratio > 0.0:
		_draw_rounded_segment(track_start_x, handle_x, center_y, active_progress_color, track_width)
	# 当前滑块半径；悬停和拖动时略微放大，清楚标记可拖动位置。
	var active_handle_radius: float = handle_radius + 1.0 if _last_hovered or _dragging else handle_radius
	# 滑块阴影；扩大 2 像素并保持低透明度，增强与轨道重叠处的层次。
	draw_circle(Vector2(handle_x, center_y), active_handle_radius + 2.0, Color(0.0, 0.0, 0.0, 0.42))
	draw_circle(Vector2(handle_x, center_y), active_handle_radius, resolved_handle_border_color if _slider.editable else resolved_disabled_progress_color)
	draw_circle(Vector2(handle_x, center_y), maxf(active_handle_radius - 3.0, 1.0), resolved_handle_fill_color if _slider.editable else resolved_disabled_progress_color)


func _get_value_ratio() -> float:
	# 有效范围；用于避免最小值与最大值相同时发生除零。
	var value_range: float = _slider.max_value - _slider.min_value
	if value_range <= 0.0:
		return 0.0
	return clampf((_slider.value - _slider.min_value) / value_range, 0.0, 1.0)


func _draw_rounded_segment(start_x: float, end_x: float, center_y: float, color: Color, width: float) -> void:
	# 安全线宽；最低 1 像素，避免检查器异常配置导致不可见。
	var resolved_width: float = maxf(width, 1.0)
	# 线段半径；两端圆形与主体线宽一致，形成连续圆角轨道。
	var radius: float = resolved_width * 0.5
	draw_line(Vector2(start_x, center_y), Vector2(end_x, center_y), color, resolved_width, true)
	draw_circle(Vector2(start_x, center_y), radius, color)
	draw_circle(Vector2(end_x, center_y), radius, color)


func _on_drag_started() -> void:
	_dragging = true
	queue_redraw()


func _on_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	queue_redraw()


func _on_mouse_entered() -> void:
	## 记录原生滑条悬停状态；视觉层忽略鼠标，因此命中判定始终由 HSlider 提供。
	_last_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	## 清除原生滑条悬停状态；拖动状态独立保留，移出控件后仍能维持拖动高亮。
	_last_hovered = false
	queue_redraw()
