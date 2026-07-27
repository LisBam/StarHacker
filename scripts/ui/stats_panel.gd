extends PanelContainer
class_name StatsPanel

## 统计面板：展示累计获得星穹、生涯对局统计（击杀数、撤离率）、单局之最与财富曲线。
## 面板只读取 StatsService 快照并响应其信号；不修改任何统计数据，也不保存副本。

## 面板关闭信号；宿主收到后隐藏遮罩并恢复焦点。
signal closed

## 全局窗口样式指南；面板窗口、分区卡与按钮统一从这里取色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 财富曲线折线颜色；使用与结算成功一致的绿色语义色，不参与主题换肤。
const WEALTH_LINE_COLOR: Color = Color(0.35, 1.0, 0.72, 1.0)
## 财富曲线网格颜色；半透明中性灰，仅作背景参照不携带业务语义。
const WEALTH_GRID_COLOR: Color = Color(0.5, 0.6, 0.7, 0.18)
## 财富曲线区域最小高度；默认 150 像素，保证折线有可读的纵向空间。
const WEALTH_CHART_MINIMUM_HEIGHT: float = 150.0
## 生涯窗口内容横向页边距；默认 18 像素，避免统计分区卡的边框贴住或遮盖最外层窗口描边。
const CONTENT_HORIZONTAL_MARGIN: int = 18
## 生涯窗口内容纵向页边距；默认 16 像素，保证标题、统计卡、财富曲线和返回按钮与窗口边框保持稳定留白。
const CONTENT_VERTICAL_MARGIN: int = 16

## 生涯统计服务缓存；ready 时解析，缺失时面板显示服务不可用提示。
var _stats_service: Node = null
## 对局统计数值标签表；键为快照字段名，值为对应 Label，刷新时按快照批量写入。
var _summary_value_labels: Dictionary = {}
## 单局之最数值标签表；键为快照字段名，值为对应 Label。
var _best_value_labels: Dictionary = {}
## 当前总资产标签；显示与银行授信一致口径的总资产估值。
var _total_assets_label: Label = null
## 财富曲线绘图控件；持有采样副本并在 _draw 中绘制折线。
var _wealth_chart: WealthCurveChart = null


## 财富曲线绘图内部类；只负责按采样数组绘制折线与网格，不读取任何服务。
class WealthCurveChart:
	extends Control

	## 折线颜色；由宿主面板常量注入，保持业务语义色统一。
	var line_color: Color = Color(0.35, 1.0, 0.72, 1.0)
	## 网格颜色；由宿主面板常量注入。
	var grid_color: Color = Color(0.5, 0.6, 0.7, 0.18)
	## 财富采样数组；元素为包含 unix_time 与 total_assets 的字典，由宿主刷新时写入。
	var samples: Array[Dictionary] = []

	func set_samples(next_samples: Array[Dictionary]) -> void:
		## 更新采样数据并请求重绘；采样为宿主提供的只读副本。
		samples = next_samples
		queue_redraw()

	func _draw() -> void:
		## 绘制横向网格与财富折线；样本不足两个时只显示网格作为空态。
		# 绘图区域尺寸；随面板布局变化，绘制坐标全部按当前尺寸换算。
		var chart_size: Vector2 = size
		# 横向网格线；四等分绘图高度，提供数值高低的视觉参照。
		for grid_index in range(5):
			# 当前网格线纵坐标；从顶部到底部等距排布。
			var grid_y: float = chart_size.y * float(grid_index) / 4.0
			draw_line(Vector2(0.0, grid_y), Vector2(chart_size.x, grid_y), grid_color, 1.0)
		if samples.size() < 2:
			return
		# 采样资产最大值；至少为 1 避免除零，纵轴按 0 到最大值线性映射。
		var maximum_assets: float = 1.0
		for sample in samples:
			maximum_assets = maxf(maximum_assets, float(sample.get("total_assets", 0)))
		# 折线顶点数组；横轴按采样序号等距排布，纵轴按资产占最大值比例映射（顶部留 6% 空隙）。
		var points: PackedVector2Array = PackedVector2Array()
		for sample_index in range(samples.size()):
			# 当前采样横坐标；首尾贴齐绘图区左右边缘。
			var point_x: float = chart_size.x * float(sample_index) / float(samples.size() - 1)
			# 当前采样纵坐标；资产越高越靠近顶部。
			var point_y: float = chart_size.y * (1.0 - 0.94 * float(samples[sample_index].get("total_assets", 0)) / maximum_assets)
			points.append(Vector2(point_x, point_y))
		draw_polyline(points, line_color, 2.0, true)


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_stats_service = get_tree().root.get_node_or_null("StatsService")
	_build_content()
	if _stats_service != null and _stats_service.has_signal("stats_changed"):
		_stats_service.connect("stats_changed", Callable(self, "_on_stats_changed"))
	refresh()


func refresh() -> void:
	## 面板打开时的统一刷新入口；按服务快照写入全部统计标签并更新财富曲线。
	if _stats_service == null or not _stats_service.has_method("get_statistics_snapshot"):
		if _total_assets_label != null:
			_total_assets_label.text = "统计服务不可用"
		return
	# 统计快照；全部字段为值拷贝。
	var snapshot: Dictionary = _stats_service.call("get_statistics_snapshot") as Dictionary
	# 对局统计标签写入；每个字段按各自格式化规则展示。
	_set_summary_text("total_runs_started", "%d 局" % int(snapshot.get("total_runs_started", 0)))
	_set_summary_text("total_success_extractions", "%d 次" % int(snapshot.get("total_success_extractions", 0)))
	_set_summary_text("total_deaths", "%d 次" % int(snapshot.get("total_deaths", 0)))
	_set_summary_text("total_escapes", "%d 次" % int(snapshot.get("total_escapes", 0)))
	_set_summary_text("extraction_rate", "%.1f%%" % (float(snapshot.get("extraction_rate", 0.0)) * 100.0))
	_set_summary_text("total_monster_kills", "%d 只" % int(snapshot.get("total_monster_kills", 0)))
	_set_summary_text("total_chests_opened", "%d 个" % int(snapshot.get("total_chests_opened", 0)))
	_set_summary_text("total_shipped_value", "%d 星穹" % int(snapshot.get("total_shipped_value", 0)))
	_set_summary_text("total_coins_earned", "%d 星穹" % int(snapshot.get("total_coins_earned", 0)))
	# 单局之最标签写入；存活时长转为分秒格式。
	_set_best_text("best_run_kills", "%d 只" % int(snapshot.get("best_run_kills", 0)))
	_set_best_text("best_run_survival_seconds", _format_duration(float(snapshot.get("best_run_survival_seconds", 0.0))))
	_set_best_text("best_run_extracted_value", "%d 星穹" % int(snapshot.get("best_run_extracted_value", 0)))
	_set_best_text("best_run_shipped_value", "%d 星穹" % int(snapshot.get("best_run_shipped_value", 0)))
	if _total_assets_label != null:
		_total_assets_label.text = "当前总资产：%d 星穹（口径与银行授信一致）" % int(snapshot.get("current_total_assets", 0))
	if _wealth_chart != null and _stats_service.has_method("get_wealth_samples"):
		_wealth_chart.set_samples(_stats_service.call("get_wealth_samples"))


func _build_content() -> void:
	## 构建面板完整内容；标题、两列统计分区、财富曲线分区与返回按钮。
	# 内容页边距容器；为全部内部统计分区预留窗口安全距离，避免嵌套卡片与最外层窗口描边发生视觉重叠。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_top", CONTENT_VERTICAL_MARGIN)
	content_margin.add_theme_constant_override("margin_right", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", CONTENT_VERTICAL_MARGIN)
	add_child(content_margin)
	# 根布局容器；纵向排列全部分区。
	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 10)
	content_margin.add_child(root_layout)
	# 面板标题；与其他局外面板一致使用 24 号标题。
	var title_label: Label = Label.new()
	title_label.text = "统计"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_title_label(title_label, 24)
	root_layout.add_child(title_label)
	# 统计主体分栏；左侧对局与战斗统计、右侧单局之最。
	var summary_split: HBoxContainer = HBoxContainer.new()
	summary_split.add_theme_constant_override("separation", 10)
	root_layout.add_child(summary_split)
	# 左侧对局统计分区；固定字段顺序展示生涯口径。
	summary_split.add_child(_build_stat_section("对局与战斗", [
		["total_runs_started", "正式对局"],
		["total_success_extractions", "成功撤离"],
		["total_deaths", "死亡"],
		["total_escapes", "主动逃跑"],
		["extraction_rate", "撤离率"],
		["total_monster_kills", "累计击杀"],
		["total_chests_opened", "累计开箱"],
		["total_shipped_value", "累计送回价值"],
		["total_coins_earned", "累计获得星穹"],
	], _summary_value_labels))
	# 右侧单局之最分区；只在对局结束时刷新纪录。
	summary_split.add_child(_build_stat_section("单局之最", [
		["best_run_kills", "单局最多击杀"],
		["best_run_survival_seconds", "单局最长存活"],
		["best_run_extracted_value", "单局最高带出价值"],
		["best_run_shipped_value", "单局最高送回价值"],
	], _best_value_labels))
	# 财富曲线分区；折线展示总资产随时间的变化。
	var wealth_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(wealth_panel)
	wealth_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_child(wealth_panel)
	# 财富分区内边距容器；四边留出可读空隙。
	var wealth_margin: MarginContainer = MarginContainer.new()
	wealth_margin.add_theme_constant_override("margin_left", 12)
	wealth_margin.add_theme_constant_override("margin_right", 12)
	wealth_margin.add_theme_constant_override("margin_top", 10)
	wealth_margin.add_theme_constant_override("margin_bottom", 12)
	wealth_panel.add_child(wealth_margin)
	# 财富分区纵向布局；标题、当前总资产与折线图。
	var wealth_layout: VBoxContainer = VBoxContainer.new()
	wealth_layout.add_theme_constant_override("separation", 8)
	wealth_margin.add_child(wealth_layout)
	# 财富分区标题；说明采样时机帮助玩家理解曲线形状。
	var wealth_title: Label = Label.new()
	wealth_title.text = "财富曲线（启动与每局结算时采样）"
	UI_STYLE_GUIDE.apply_muted_accent_label(wealth_title)
	wealth_layout.add_child(wealth_title)
	_total_assets_label = Label.new()
	UI_STYLE_GUIDE.apply_secondary_label(_total_assets_label)
	wealth_layout.add_child(_total_assets_label)
	_wealth_chart = WealthCurveChart.new()
	_wealth_chart.line_color = WEALTH_LINE_COLOR
	_wealth_chart.grid_color = WEALTH_GRID_COLOR
	_wealth_chart.custom_minimum_size = Vector2(0.0, WEALTH_CHART_MINIMUM_HEIGHT)
	_wealth_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wealth_layout.add_child(_wealth_chart)
	# 返回按钮；与其他局外面板同规格。
	var close_button: Button = Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.pressed.connect(_on_close_button_pressed)
	root_layout.add_child(close_button)


func _build_stat_section(section_title: String, stat_rows: Array, target_label_table: Dictionary) -> Control:
	## 构建一个统计分区；每行左侧为字段名、右侧为数值标签，数值标签写入目标缓存表供刷新使用。
	# 分区外框；使用统一浅色分区面板样式。
	var section_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(section_panel)
	section_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 分区内边距容器；四边留出可读空隙。
	var section_margin: MarginContainer = MarginContainer.new()
	section_margin.add_theme_constant_override("margin_left", 12)
	section_margin.add_theme_constant_override("margin_right", 12)
	section_margin.add_theme_constant_override("margin_top", 10)
	section_margin.add_theme_constant_override("margin_bottom", 12)
	section_panel.add_child(section_margin)
	# 分区纵向布局；标题在上、统计行依次排列。
	var section_layout: VBoxContainer = VBoxContainer.new()
	section_layout.add_theme_constant_override("separation", 6)
	section_margin.add_child(section_layout)
	# 分区标题；使用强调文字色。
	var section_title_label: Label = Label.new()
	section_title_label.text = section_title
	UI_STYLE_GUIDE.apply_muted_accent_label(section_title_label)
	section_layout.add_child(section_title_label)
	for stat_row in stat_rows:
		# 单行统计定义；下标 0 为快照字段名、下标 1 为玩家可见名称。
		var row_definition: Array = stat_row as Array
		# 统计行容器；左名称右数值。
		var stat_row_box: HBoxContainer = HBoxContainer.new()
		stat_row_box.add_theme_constant_override("separation", 8)
		section_layout.add_child(stat_row_box)
		# 字段名称标签；伸展占满左侧空间。
		var name_label: Label = Label.new()
		name_label.text = str(row_definition[1])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI_STYLE_GUIDE.apply_secondary_label(name_label)
		stat_row_box.add_child(name_label)
		# 字段数值标签；右对齐并写入缓存表，刷新时按字段名回填。
		var value_label: Label = Label.new()
		value_label.text = "—"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_row_box.add_child(value_label)
		target_label_table[str(row_definition[0])] = value_label
	return section_panel


func _set_summary_text(field_name: String, text_value: String) -> void:
	## 写入对局统计标签；字段缺失时安全跳过，保持面板对快照结构变化的容错。
	# 目标标签；由构建阶段写入缓存表。
	var value_label: Label = _summary_value_labels.get(field_name) as Label
	if value_label != null:
		value_label.text = text_value


func _set_best_text(field_name: String, text_value: String) -> void:
	## 写入单局之最标签；字段缺失时安全跳过。
	# 目标标签；由构建阶段写入缓存表。
	var value_label: Label = _best_value_labels.get(field_name) as Label
	if value_label != null:
		value_label.text = text_value


func _format_duration(total_seconds: float) -> String:
	## 把秒数格式化为“分:秒”展示；与战斗 HUD 生存时间的可读格式保持一致。
	# 非负总秒数；负值按 0 处理。
	var resolved_seconds: int = maxi(roundi(total_seconds), 0)
	return "%d 分 %02d 秒" % [resolved_seconds / 60, resolved_seconds % 60]


func _on_stats_changed() -> void:
	## 统计服务变化回调；面板可见时才刷新，隐藏期间等待宿主重新打开时刷新。
	if is_visible_in_tree():
		refresh()


func _on_close_button_pressed() -> void:
	closed.emit()
