extends Control
class_name StockChartControl

## 股票折线图只负责把价格历史绘制为透明深色行情区域，不读取服务或处理交易。
## 价格标记扩展；控件也会绘制宿主整理后的通用价格线，但仍不读取任何业务服务或处理交易。
## 宿主通过 configure_history() 传入价格历史，通过 configure_price_levels() 传入止盈止损等只读价格线。
## 玩家在绘图区按住鼠标左键达到配置时长后，可沿纵轴查看鼠标所在行对应的价格。
## 宿主通过 configure_history() 传入最多 30 个价格，控件会自动归一化并保留上下边距。
## 历史扩容补充；服务侧历史上限已统一为 90 个采样，本控件按传入数组长度自适应绘制，不限制具体数量。

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
## 止盈线颜色；默认绿色表达盈利目标，运行时无需动态修改。
@export var take_profit_line_color: Color = Color(0.34, 1.0, 0.62, 0.96)
## 止损线颜色；默认红色表达风险目标，运行时无需动态修改。
@export var stop_loss_line_color: Color = Color(1.0, 0.42, 0.48, 0.96)
## 止盈止损线宽度；默认 1.5 像素，既清晰可见又不会盖住行情折线，运行时无需动态修改。
@export_range(1.0, 5.0, 0.5) var price_level_line_width: float = 1.5
## 止盈止损虚线单段长度；默认 7 像素，用于和实线行情折线区分，运行时无需动态修改。
@export_range(2.0, 20.0, 1.0) var price_level_dash_length: float = 7.0
## 存在止盈止损线时的纵轴额外边距比例；默认上下各 6%，确保极值目标线不会贴住绘图区边缘，运行时无需动态修改。
@export_range(0.0, 0.25, 0.01) var price_level_range_margin_ratio: float = 0.06
## 价格标记文字字号；默认 13 像素，在不遮挡走势的前提下保持可读，运行时无需动态修改。
@export_range(10, 24, 1) var price_label_font_size: int = 13
## 价格标记文字框内边距；默认横向 5、纵向 2 像素，运行时无需动态修改。
@export var price_label_padding: Vector2 = Vector2(5.0, 2.0)
## 价格标记文字框与绘图区边缘的距离；默认 4 像素，运行时无需动态修改。
@export_range(0.0, 16.0, 1.0) var price_label_edge_offset: float = 4.0
## 价格标记文字框背景色；默认使用高不透明深色保证文字在折线上方仍可辨认，运行时无需动态修改。
@export var price_label_background_color: Color = Color(0.01, 0.02, 0.03, 0.90)
## 鼠标长按生效时长；默认 0.35 秒，短点击不会误触读价，运行时无需动态修改。
@export_range(0.1, 1.5, 0.05) var inspection_hold_duration_seconds: float = 0.35
## 鼠标读价指示线颜色；默认青蓝色，与行情红绿语义保持区分，运行时无需动态修改。
@export var inspection_line_color: Color = Color(0.55, 0.92, 1.0, 0.96)
## 鼠标读价指示线宽度；默认 1.5 像素，运行时无需动态修改。
@export_range(1.0, 5.0, 0.5) var inspection_line_width: float = 1.5

## 当前价格历史；元素为正数价格，默认空数组时只绘制背景和“暂无行情”提示。
var _history: PackedFloat32Array = PackedFloat32Array()
## 当前涨跌方向；取值 -1、0、1，决定折线使用红色、白色或绿色。
var _trend_direction: int = 0
## 当前只读价格标记；每项包含正数 price、显示 label 与 take_profit/stop_loss 类型，不持有业务档案引用。
var _price_levels: Array[Dictionary] = []
## 鼠标左键是否从有效绘图区开始保持按下；用于累计长按时间并在松开时结束读价。
var _inspection_press_active: bool = false
## 鼠标读价是否已经跨过长按阈值；为 true 时绘制横向指示线和价格标签。
var _inspection_active: bool = false
## 当前按住鼠标的累计秒数；默认 0，达到 inspection_hold_duration_seconds 后激活读价。
var _inspection_elapsed_seconds: float = 0.0
## 当前读价鼠标局部坐标；始终限制在内部绘图区，用于换算纵轴价格和定位标签。
var _inspection_position: Vector2 = Vector2.ZERO
## 行情图面板样式缓存；默认空引用，首次绘制时创建并跨帧复用，主题切换通知会置空以按新风格重建。
var _panel_style_cache: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(430.0, 250.0)
	# 行情图需要独占自身区域的左键长按与移动事件；该区域下方没有其他可点击控件。
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	# 闲置时关闭逐帧处理；只有有效鼠标按住期间才累计长按时间。
	set_process(false)
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


func configure_price_levels(price_levels: Array) -> void:
	## 配置需要叠加在行情图上的只读价格线；无效项会被忽略，调用方后续修改原数组不会影响控件。
	_price_levels.clear()
	for price_level_value in price_levels:
		if not (price_level_value is Dictionary):
			continue
		# 当前价格线配置；只读取绘图所需字段，避免图表依赖止盈止损档案结构。
		var price_level: Dictionary = price_level_value as Dictionary
		# 当前价格线价格；非正数不属于有效证券价格，因此不进入绘图范围。
		var price: float = float(price_level.get("price", 0.0))
		if price <= 0.0:
			continue
		# 当前价格线类型；只接受止盈和止损，未知类型不会获得错误的业务语义颜色。
		var level_type: String = str(price_level.get("type", ""))
		if level_type != "take_profit" and level_type != "stop_loss":
			continue
		_price_levels.append({
			"price": price,
			"label": str(price_level.get("label", "")),
			"type": level_type,
		})
	queue_redraw()


func is_price_inspection_active() -> bool:
	## 返回长按读价是否已经生效；主要供自动验证和未来无障碍提示查询，不允许外部修改交互状态。
	return _inspection_active


func get_inspected_price() -> float:
	## 返回当前鼠标行对应的价格；没有有效价格范围时返回 0，结果不改变行情或挂单数据。
	if not _inspection_active:
		return 0.0
	return get_price_at_local_y(_inspection_position.y)


func get_price_at_local_y(local_y: float) -> float:
	## 把控件局部纵坐标换算为当前可视价格；绘图区上边缘对应最高价，下边缘对应最低价。
	# 内部绘图矩形；与实际绘制共用同一留白，保证读价和可见折线严格对齐。
	var inner_rect: Rect2 = _get_inner_rect()
	if inner_rect.size.y <= 0.0:
		return 0.0
	# 当前可视价格范围；x 为最低价，y 为最高价。
	var price_range: Vector2 = _calculate_visible_price_range()
	if price_range.y <= price_range.x:
		return 0.0
	# 局部纵向比例；超出绘图区的输入会限制到上下边缘，避免返回范围外价格。
	var y_ratio: float = clampf((local_y - inner_rect.position.y) / inner_rect.size.y, 0.0, 1.0)
	return lerpf(price_range.y, price_range.x, y_ratio)


func _process(delta: float) -> void:
	## 仅在鼠标按住期间累计长按时长；达到阈值后保持读价，直到左键松开。
	if not _inspection_press_active:
		set_process(false)
		return
	_inspection_elapsed_seconds += maxf(delta, 0.0)
	if _inspection_active or _inspection_elapsed_seconds < inspection_hold_duration_seconds:
		return
	_inspection_active = true
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	## 处理行情图左键长按和按住移动；短点击、右键及绘图区外按下都不会显示价格。
	if event is InputEventMouseButton:
		# 鼠标按键事件；只接收左键，其他按键继续交给常规界面输入。
		var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button_event.pressed:
			_begin_price_inspection(mouse_button_event.position)
		else:
			_end_price_inspection()
		accept_event()
		return
	if event is InputEventMouseMotion and _inspection_press_active:
		# 鼠标移动事件；按住期间持续更新局部位置，激活读价后立即重绘当前行价格。
		var mouse_motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		_inspection_position = _clamp_to_inner_rect(mouse_motion_event.position)
		if _inspection_active:
			queue_redraw()
		accept_event()


func _begin_price_inspection(local_position: Vector2) -> void:
	## 从绘图区内开始累计读价长按；边框和外部留白不参与价格换算。
	# 内部绘图矩形；用于拒绝在图表留白和边框上开始的无效长按。
	var inner_rect: Rect2 = _get_inner_rect()
	if not inner_rect.has_point(local_position):
		return
	_inspection_press_active = true
	_inspection_active = false
	_inspection_elapsed_seconds = 0.0
	_inspection_position = _clamp_to_inner_rect(local_position)
	set_process(true)


func _end_price_inspection() -> void:
	## 结束当前长按并隐藏价格指示；不会清除行情或止盈止损价格线。
	_inspection_press_active = false
	_inspection_active = false
	_inspection_elapsed_seconds = 0.0
	set_process(false)
	queue_redraw()


func _get_inner_rect() -> Rect2:
	## 返回折线、价格线与鼠标读价共同使用的内部绘图区。
	return Rect2(Vector2(chart_padding, chart_padding), size - Vector2.ONE * chart_padding * 2.0)


func _clamp_to_inner_rect(local_position: Vector2) -> Vector2:
	## 把鼠标局部坐标限制到内部绘图区；按住拖出边缘时继续显示最近的边界价格。
	# 内部绘图矩形；无有效尺寸时退回零坐标，避免构造反向限制区间。
	var inner_rect: Rect2 = _get_inner_rect()
	if inner_rect.size.x <= 0.0 or inner_rect.size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		clampf(local_position.x, inner_rect.position.x, inner_rect.end.x),
		clampf(local_position.y, inner_rect.position.y, inner_rect.end.y)
	)


func _calculate_visible_price_range() -> Vector2:
	## 计算行情历史与全部有效价格线共享的纵轴范围；返回值 x 为最低价、y 为最高价。
	# 是否已经取得至少一个有效价格；用于安全初始化最低价和最高价。
	var has_price: bool = false
	# 历史最低价；默认取首个采样点，遍历后用于纵向归一化。
	# 价格线扩展补充；当前实现从首个有效历史价或标记价初始化，兼容历史为空但存在目标线的场景。
	# 当前最低价；首次遇到有效历史或价格线时赋值。
	var minimum_price: float = 0.0
	# 历史最高价；默认取首个采样点，遍历后用于纵向归一化。
	# 价格线扩展补充；当前实现会继续纳入全部有效标记价，确保止盈止损线位于可视范围内。
	# 当前最高价；首次遇到有效历史或价格线时赋值。
	var maximum_price: float = 0.0
	for history_price in _history:
		if history_price <= 0.0:
			continue
		if not has_price:
			minimum_price = history_price
			maximum_price = history_price
			has_price = true
		else:
			minimum_price = minf(minimum_price, history_price)
			maximum_price = maxf(maximum_price, history_price)
	for price_level in _price_levels:
		# 当前标记价格；配置入口已过滤非正数，此处仍以默认值防御不完整字典。
		var level_price: float = float(price_level.get("price", 0.0))
		if level_price <= 0.0:
			continue
		if not has_price:
			minimum_price = level_price
			maximum_price = level_price
			has_price = true
		else:
			minimum_price = minf(minimum_price, level_price)
			maximum_price = maxf(maximum_price, level_price)
	if not has_price:
		return Vector2.ZERO
	# 可视价格跨度；至少保留最高价 4% 或 1 星穹，避免横盘时折线贴满整个高度。
	var price_span: float = maxf(maximum_price - minimum_price, maxf(maximum_price * 0.04, 1.0))
	if not _price_levels.is_empty():
		# 价格线边距后的跨度；只在存在标记时扩展，使目标线不贴边且不改变无挂单时的既有折线比例。
		price_span *= 1.0 + price_level_range_margin_ratio * 2.0
	# 价格区间中点；扩展极小跨度时以真实高低价中心保持图形居中。
	var middle_price: float = (maximum_price + minimum_price) * 0.5
	return Vector2(middle_price - price_span * 0.5, middle_price + price_span * 0.5)


func _price_to_local_y(price: float, price_range: Vector2, inner_rect: Rect2) -> float:
	## 把价格换算为内部绘图区纵坐标；超出范围时限制到可视边缘。
	# 纵向价格比例；最低价为 0，最高价为 1，绘制时反转 Y 轴。
	# 价格在当前纵轴内的比例；最低价为 0、最高价为 1，绘制坐标需要反转 Y 轴。
	var y_ratio: float = (price - price_range.x) / maxf(price_range.y - price_range.x, 0.001)
	return inner_rect.end.y - inner_rect.size.y * clampf(y_ratio, 0.0, 1.0)


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
	var inner_rect: Rect2 = _get_inner_rect()
	if inner_rect.size.x <= 0.0 or inner_rect.size.y <= 0.0:
		return
	for grid_index in range(1, 4):
		# 当前横向网格线纵坐标；四等分背景以辅助观察相对波动，不显示具体价格刻度。
		var grid_y: float = inner_rect.position.y + inner_rect.size.y * float(grid_index) / 4.0
		draw_line(Vector2(inner_rect.position.x, grid_y), Vector2(inner_rect.end.x, grid_y), Color(1.0, 1.0, 1.0, 0.10), 1.0)
	# 当前可视价格范围；同时覆盖行情历史和止盈止损标记，保证全部目标线都能显示。
	var price_range: Vector2 = _calculate_visible_price_range()
	if price_range.y <= price_range.x:
		return
	_draw_price_levels(inner_rect, price_range)
	if _history.size() >= 2:
		# 折线点数组；按时间从左到右保存已归一化的局部坐标。
		var points: PackedVector2Array = PackedVector2Array()
		for history_index in range(_history.size()):
			# 横向时间比例；首个采样为 0，最后一个采样为 1。
			var x_ratio: float = float(history_index) / float(_history.size() - 1)
			# 当前历史价格纵坐标；与价格线和长按读价共用同一价格范围。
			var point_y: float = _price_to_local_y(_history[history_index], price_range, inner_rect)
			points.append(Vector2(inner_rect.position.x + inner_rect.size.x * x_ratio, point_y))
		# 折线颜色；最近上涨为绿色、下跌为红色、持平为白色，与收益着色规则一致。
		var line_color: Color = Color(0.32, 0.92, 0.48, 1.0) if _trend_direction > 0 else (Color(0.96, 0.28, 0.32, 1.0) if _trend_direction < 0 else Color(0.88, 0.92, 0.96, 1.0))
		draw_polyline(points, line_color, line_width, true)
		for point in points:
			draw_circle(point, 2.4, line_color)
	if _inspection_active:
		_draw_price_inspection(inner_rect)


func _draw_price_levels(inner_rect: Rect2, price_range: Vector2) -> void:
	## 绘制止盈止损等宿主价格标记；相邻条目交替靠左右放置标签，降低同价标记完全重叠的概率。
	# 标签字体；跟随当前主题，UI 风格切换后无需单独重建资源。
	var label_font: Font = get_theme_default_font()
	for price_level_index in range(_price_levels.size()):
		# 当前价格线配置；包含经过校验的价格、标签和业务语义类型。
		var price_level: Dictionary = _price_levels[price_level_index]
		# 当前价格线价格；决定纵坐标和两位小数显示文本。
		var price: float = float(price_level.get("price", 0.0))
		# 当前价格线颜色；止盈为绿色，止损为红色。
		var level_color: Color = take_profit_line_color if str(price_level.get("type", "")) == "take_profit" else stop_loss_line_color
		# 当前价格线纵坐标；价格范围已包含全部标记，因此正常情况下不会落到绘图区外。
		var line_y: float = _price_to_local_y(price, price_range, inner_rect)
		draw_dashed_line(Vector2(inner_rect.position.x, line_y), Vector2(inner_rect.end.x, line_y), level_color, price_level_line_width, price_level_dash_length, true, true)
		# 当前标签正文；同时展示目标类型和精确价格，避免只凭颜色辨认。
		var label_text: String = "%s %.2f" % [str(price_level.get("label", "目标价")), price]
		# 当前标签文字尺寸；用于构造不遮住文字的深色底框。
		var text_size: Vector2 = label_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, price_label_font_size)
		# 当前标签框尺寸；由文字尺寸加双侧内边距得到。
		var label_size: Vector2 = text_size + price_label_padding * 2.0
		# 当前标签横坐标；偶数项靠右、奇数项靠左，使相同价格的现货与杠杆标签仍可分别看见。
		var label_x: float = inner_rect.end.x - price_label_edge_offset - label_size.x if price_level_index % 2 == 0 else inner_rect.position.x + price_label_edge_offset
		# 当前标签纵坐标；以价格线为中心，并限制在绘图区内部。
		var label_y: float = clampf(line_y - label_size.y * 0.5, inner_rect.position.y, inner_rect.end.y - label_size.y)
		# 当前标签背景矩形；先绘制深色底再绘制语义色文字。
		var label_rect: Rect2 = Rect2(Vector2(label_x, label_y), label_size)
		draw_rect(label_rect, price_label_background_color, true)
		# 当前文字基线；使用字体上升高度确保文字垂直落在标签框内。
		var text_baseline: Vector2 = label_rect.position + Vector2(price_label_padding.x, price_label_padding.y + label_font.get_ascent(price_label_font_size))
		draw_string(label_font, text_baseline, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, price_label_font_size, level_color)


func _draw_price_inspection(inner_rect: Rect2) -> void:
	## 绘制长按读价横线与浮动价格标签；标签优先位于鼠标右上方，空间不足时自动翻转。
	# 当前读价位置；再次限制范围以兼容控件尺寸在按住期间发生变化。
	var inspection_position: Vector2 = _clamp_to_inner_rect(_inspection_position)
	draw_line(Vector2(inner_rect.position.x, inspection_position.y), Vector2(inner_rect.end.x, inspection_position.y), inspection_line_color, inspection_line_width, true)
	draw_circle(inspection_position, inspection_line_width + 2.0, inspection_line_color)
	# 当前行价格；由同一纵轴范围反向换算，显示两位小数证券币。
	var inspected_price: float = get_price_at_local_y(inspection_position.y)
	# 当前读价标签正文；明确单位避免与走势图采样序号混淆。
	var label_text: String = "价格 %.2f" % inspected_price
	# 标签字体；跟随当前主题，保证不同 UI 风格下字号和字形一致。
	var label_font: Font = get_theme_default_font()
	# 标签文字尺寸；用于计算跟随鼠标的深色底框。
	var text_size: Vector2 = label_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, price_label_font_size)
	# 标签框尺寸；由文字尺寸加双侧内边距得到。
	var label_size: Vector2 = text_size + price_label_padding * 2.0
	# 标签候选横坐标；默认放在鼠标右侧，越过右边界时翻转到左侧。
	var label_x: float = inspection_position.x + price_label_edge_offset
	if label_x + label_size.x > inner_rect.end.x:
		label_x = inspection_position.x - price_label_edge_offset - label_size.x
	# 标签候选纵坐标；默认放在价格线上方，越过上边界时翻转到下方。
	var label_y: float = inspection_position.y - price_label_edge_offset - label_size.y
	if label_y < inner_rect.position.y:
		label_y = inspection_position.y + price_label_edge_offset
	# 标签背景矩形；最终限制在内部绘图区，避免文字被图表边框裁切。
	var label_rect: Rect2 = Rect2(
		Vector2(
			clampf(label_x, inner_rect.position.x, inner_rect.end.x - label_size.x),
			clampf(label_y, inner_rect.position.y, inner_rect.end.y - label_size.y)
		),
		label_size
	)
	draw_rect(label_rect, price_label_background_color, true)
	# 当前文字基线；使用字体上升高度把文字稳定放入标签框。
	var text_baseline: Vector2 = label_rect.position + Vector2(price_label_padding.x, price_label_padding.y + label_font.get_ascent(price_label_font_size))
	draw_string(label_font, text_baseline, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, price_label_font_size, inspection_line_color)
