extends Control
class_name StockChartControl

## 股票折线图只负责把价格历史绘制为透明深色行情区域，不读取服务或处理交易。
## 宿主通过 configure_history() 传入最多 30 个价格，控件会自动归一化并保留上下边距。

## 全局窗口样式指南；行情图底板随当前 UI 风格取色，红绿白折线保持涨跌语义不受影响。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 行情图背景透明度；默认 0.68，与通用悬浮信息框保持一致。
@export_range(0.0, 1.0, 0.01) var background_alpha: float = 0.68
## 行情图白色边框宽度；默认 2 像素，与设计规范一致。
@export_range(1.0, 6.0, 1.0) var border_width: float = 2.0
## 行情图圆角半径；默认 6 像素，与通用信息框保持一致。
@export_range(0.0, 24.0, 1.0) var corner_radius: float = 6.0
## 折线宽度；默认 2 像素，在 30 个采样点下保持清晰且不过度遮挡网格。
@export_range(1.0, 6.0, 0.5) var line_width: float = 2.0
## 绘图内部留白；默认 18 像素，避免极值折线贴住白色边框。
@export_range(4.0, 48.0, 1.0) var chart_padding: float = 18.0

## 当前价格历史；元素为正数价格，默认空数组时只绘制背景和“暂无行情”提示。
var _history: PackedFloat32Array = PackedFloat32Array()
## 当前涨跌方向；取值 -1、0、1，决定折线使用红色、白色或绿色。
var _trend_direction: int = 0
## 行情图面板样式缓存；默认空引用，首次绘制时创建并跨帧复用，主题切换通知会置空以按新风格重建。
var _panel_style_cache: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(430.0, 250.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	# 主题变化通知；UI 风格切换会刷新宿主主题，此时重绘使行情图底板立即使用新风格取色。
	if what == NOTIFICATION_THEME_CHANGED:
		_panel_style_cache = null
		queue_redraw()


func configure_history(history: Array, trend_direction: int) -> void:
	_history = PackedFloat32Array()
	# 预分配历史容量；resize 后按索引赋值，避免每秒刷新逐项 append 反复扩容。
	_history.resize(history.size())
	for history_index in range(history.size()):
		_history[history_index] = maxf(float(history[history_index]), 0.0)
	_trend_direction = clampi(trend_direction, -1, 1)
	queue_redraw()


func _draw() -> void:
	# 行情图面板样式；集中配置透明背景、白边和圆角，修改只影响折线图承载区域。
	# 样式缓存补充：样式盒改为成员缓存并跨帧复用，主题切换会置空缓存并在下一次绘制按新风格重建。
	if _panel_style_cache == null:
		_panel_style_cache = StyleBoxFlat.new()
		_panel_style_cache.bg_color = Color(UI_STYLE_GUIDE.get_input_background_color(), background_alpha)
		_panel_style_cache.border_color = Color(1.0, 1.0, 1.0, 0.92)
		_panel_style_cache.set_border_width_all(int(border_width))
		_panel_style_cache.set_corner_radius_all(int(corner_radius))
	draw_style_box(_panel_style_cache, Rect2(Vector2.ZERO, size))
	# 内部绘图矩形；扣除统一留白后作为网格和折线的归一化坐标区域。
	var inner_rect: Rect2 = Rect2(Vector2(chart_padding, chart_padding), size - Vector2.ONE * chart_padding * 2.0)
	if inner_rect.size.x <= 0.0 or inner_rect.size.y <= 0.0:
		return
	for grid_index in range(1, 4):
		# 当前横向网格线纵坐标；四等分背景以辅助观察相对波动，不显示具体价格刻度。
		var grid_y: float = inner_rect.position.y + inner_rect.size.y * float(grid_index) / 4.0
		draw_line(Vector2(inner_rect.position.x, grid_y), Vector2(inner_rect.end.x, grid_y), Color(1.0, 1.0, 1.0, 0.10), 1.0)
	if _history.size() < 2:
		return
	# 历史最低价；默认取首个采样点，遍历后用于纵向归一化。
	var minimum_price: float = _history[0]
	# 历史最高价；默认取首个采样点，遍历后用于纵向归一化。
	var maximum_price: float = _history[0]
	for price in _history:
		minimum_price = minf(minimum_price, price)
		maximum_price = maxf(maximum_price, price)
	# 可视价格跨度；至少保留最高价 4% 或 1 星穹，避免横盘时折线贴满整个高度。
	var price_span: float = maxf(maximum_price - minimum_price, maxf(maximum_price * 0.04, 1.0))
	# 价格区间中点；扩展极小跨度时以真实高低价中心保持图形居中。
	var middle_price: float = (maximum_price + minimum_price) * 0.5
	minimum_price = middle_price - price_span * 0.5
	maximum_price = middle_price + price_span * 0.5
	# 折线点数组；按时间从左到右保存已归一化的局部坐标。
	var points: PackedVector2Array = PackedVector2Array()
	for history_index in range(_history.size()):
		# 横向时间比例；首个采样为 0，最后一个采样为 1。
		var x_ratio: float = float(history_index) / float(_history.size() - 1)
		# 纵向价格比例；最低价为 0，最高价为 1，绘制时反转 Y 轴。
		var y_ratio: float = (_history[history_index] - minimum_price) / maxf(maximum_price - minimum_price, 0.001)
		points.append(Vector2(inner_rect.position.x + inner_rect.size.x * x_ratio, inner_rect.end.y - inner_rect.size.y * y_ratio))
	# 折线颜色；最近上涨为绿色、下跌为红色、持平为白色，与收益着色规则一致。
	var line_color: Color = Color(0.32, 0.92, 0.48, 1.0) if _trend_direction > 0 else (Color(0.96, 0.28, 0.32, 1.0) if _trend_direction < 0 else Color(0.88, 0.92, 0.96, 1.0))
	draw_polyline(points, line_color, line_width, true)
	for point in points:
		draw_circle(point, 2.4, line_color)
