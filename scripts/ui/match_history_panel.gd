extends PanelContainer
class_name MatchHistoryPanel

## 战绩面板：只读展示 StatsService 持久化的最近 20 局正式结算记录。
## 记录按最新在前排列，训练场、首次教学与不产出正式结算的娱乐模式不会出现在列表中。

## 面板关闭信号；主菜单宿主收到后隐藏遮罩并把焦点交还“统计”分类按钮。
signal closed

## 全局窗口样式指南；窗口、战绩卡片、标题和按钮统一使用项目当前 UI 风格。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 战绩窗口内容横向页边距；默认 18 像素，与生涯面板和其他局外窗口保持一致。
const CONTENT_HORIZONTAL_MARGIN: int = 18
## 战绩窗口内容纵向页边距；默认 16 像素，避免标题、列表与返回按钮贴住窗口描边。
const CONTENT_VERTICAL_MARGIN: int = 16
## 成功撤离语义色；使用结算成功的绿色，业务结果颜色不随黑蓝或黑白主题改变。
const RESULT_SUCCESS_COLOR: Color = Color(0.35, 1.0, 0.72, 1.0)
## 撤离失败语义色；使用结算失败的浅红色，帮助玩家快速扫描近期结果。
const RESULT_FAILURE_COLOR: Color = Color(1.0, 0.46, 0.52, 1.0)
## 主动逃跑语义色；使用暖黄色与成功、死亡区分，不表示按钮警告状态。
const RESULT_ESCAPE_COLOR: Color = Color(1.0, 0.78, 0.32, 1.0)

## 生涯统计服务缓存；ready 时从场景树解析，缺失时显示战绩服务不可用空态。
var _stats_service: Node = null
## 战绩数量说明标签；刷新时显示当前保存数量与 20 局上限。
var _history_summary_label: Label = null
## 战绩卡片纵向容器；刷新时清空并按最新在前重建全部只读卡片。
var _history_list: VBoxContainer = null


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_stats_service = get_tree().root.get_node_or_null("StatsService")
	_build_content()
	if _stats_service != null and _stats_service.has_signal("stats_changed"):
		_stats_service.connect("stats_changed", Callable(self, "_on_stats_changed"))
	refresh()


func refresh() -> void:
	## 从统计服务重新读取近期战绩；界面只消费深复制快照，不持有或修改服务内部数组。
	_clear_history_list()
	if _stats_service == null or not _stats_service.has_method("get_recent_run_history"):
		_history_summary_label.text = "战绩服务不可用"
		_add_empty_state("无法读取近期战绩")
		return
	# 近期战绩快照；索引 0 为最近一次正式结算，最多包含 20 条。
	var recent_history: Array = _stats_service.call("get_recent_run_history") as Array
	_history_summary_label.text = "最近 %d / 20 局正式战绩（不含训练场与无结算模式）" % recent_history.size()
	if recent_history.is_empty():
		_add_empty_state("暂无正式战绩")
		return
	for history_index in range(recent_history.size()):
		# 原始战绩条目；服务协议保证为字典，界面仍做类型防御以兼容损坏或扩展存档。
		var raw_record: Variant = recent_history[history_index]
		if raw_record is Dictionary:
			_history_list.add_child(_build_history_card(history_index + 1, raw_record as Dictionary))


func _build_content() -> void:
	## 构建标题、数量说明、滚动战绩列表与返回按钮，所有数据卡片由 refresh 动态生成。
	# 内容页边距容器；保护内部滚动区和最外层窗口描边之间的安全距离。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_top", CONTENT_VERTICAL_MARGIN)
	content_margin.add_theme_constant_override("margin_right", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", CONTENT_VERTICAL_MARGIN)
	add_child(content_margin)
	# 根布局容器；纵向排列固定标题、滚动内容与底部返回按钮。
	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 10)
	content_margin.add_child(root_layout)
	# 面板标题；使用与生涯、悬赏等局外窗口一致的 24 号居中标题。
	var title_label: Label = Label.new()
	title_label.text = "战绩"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_title_label(title_label, 24)
	root_layout.add_child(title_label)
	# 战绩数量说明；帮助玩家理解列表上限以及被排除的模式口径。
	_history_summary_label = Label.new()
	_history_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_secondary_label(_history_summary_label)
	root_layout.add_child(_history_summary_label)
	# 战绩滚动区域；记录超过窗口高度时只滚动卡片，不移动标题与返回按钮。
	var history_scroll: ScrollContainer = ScrollContainer.new()
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_child(history_scroll)
	# 战绩卡片容器；每条记录独占一张分区卡，按最新到最旧纵向排列。
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 8)
	history_scroll.add_child(_history_list)
	# 返回按钮；关闭面板但不改变战绩数据或统计分类状态。
	var close_button: Button = Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.pressed.connect(_on_close_button_pressed)
	root_layout.add_child(close_button)


func _build_history_card(display_index: int, run_record: Dictionary) -> Control:
	## 构建一条近期战绩卡片；头部显示序号、结算结果与时间，下方展示完整单局统计和结算价值。
	# 战绩卡片外框；统一使用窗口内部的浅层分区样式。
	var history_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(history_panel)
	history_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 卡片内边距；保证结果标题与数值网格不贴住分区描边。
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 12)
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_right", 12)
	card_margin.add_theme_constant_override("margin_bottom", 12)
	history_panel.add_child(card_margin)
	# 卡片纵向布局；头部与详细字段网格分行排列。
	var card_layout: VBoxContainer = VBoxContainer.new()
	card_layout.add_theme_constant_override("separation", 8)
	card_margin.add_child(card_layout)
	# 卡片头部；左侧显示列表序号和结果，右侧显示本地结算时间。
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	card_layout.add_child(header_row)
	# 结果标识；由稳定 result_id 映射为玩家可见中文并应用对应语义色。
	var result_label: Label = Label.new()
	result_label.text = "#%02d  %s" % [display_index, _get_result_text(str(run_record.get("result_id", "")))]
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.add_theme_color_override("font_color", _get_result_color(str(run_record.get("result_id", ""))))
	header_row.add_child(result_label)
	# 结算时间标签；服务保存本地时间字符串，旧记录缺失时明确显示未知而不伪造时间。
	var completed_at_label: Label = Label.new()
	# 已保存的本地时间；空字符串使用兼容提示。
	var completed_at: String = str(run_record.get("completed_at", "")).strip_edges()
	completed_at_label.text = completed_at if not completed_at.is_empty() else "时间未知"
	completed_at_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI_STYLE_GUIDE.apply_secondary_label(completed_at_label)
	header_row.add_child(completed_at_label)
	# 详细字段网格；四列布局在 900 像素窗口内同时兼顾字段密度与可读性。
	var detail_grid: GridContainer = GridContainer.new()
	detail_grid.columns = 4
	detail_grid.add_theme_constant_override("h_separation", 12)
	detail_grid.add_theme_constant_override("v_separation", 6)
	card_layout.add_child(detail_grid)
	# 详细字段定义；每项依次包含名称和已经格式化的玩家可见数值。
	var detail_definitions: Array = [
		["存活时间", _format_duration(float(run_record.get("survival_seconds", 0.0)))],
		["造成伤害", "%d" % maxi(int(run_record.get("damage_dealt", 0)), 0)],
		["受到伤害", "%d" % maxi(int(run_record.get("damage_received", 0)), 0)],
		["击杀数", "%d 只" % maxi(int(run_record.get("monster_kills", 0)), 0)],
		["开启宝箱", "%d 个" % maxi(int(run_record.get("chests_opened", 0)), 0)],
		["带出价值", "%d 星穹" % maxi(int(run_record.get("extracted_value", 0)), 0)],
		["送回价值", "%d 星穹" % maxi(int(run_record.get("shipped_value", 0)), 0)],
	]
	for raw_detail_definition in detail_definitions:
		# 单项详细字段定义；下标 0 为名称，下标 1 为格式化值。
		var detail_definition: Array = raw_detail_definition as Array
		detail_grid.add_child(_build_detail_cell(str(detail_definition[0]), str(detail_definition[1])))
	return history_panel


func _build_detail_cell(detail_name: String, detail_value: String) -> Control:
	## 构建一个战绩详细字段单元；名称使用次要色，数值单独一行便于横向比较。
	# 详细字段容器；四列网格中横向伸展以保持各列等宽。
	var detail_cell: VBoxContainer = VBoxContainer.new()
	detail_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_cell.add_theme_constant_override("separation", 2)
	# 字段名称标签；居中显示并弱化颜色。
	var name_label: Label = Label.new()
	name_label.text = detail_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_secondary_label(name_label)
	detail_cell.add_child(name_label)
	# 字段数值标签；居中显示实际本局数据。
	var value_label: Label = Label.new()
	value_label.text = detail_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_cell.add_child(value_label)
	return detail_cell


func _get_result_text(result_id: String) -> String:
	## 把稳定结算结果标识转换为中文；未知值按逃跑兼容，与 StatsService 的结果回退规则一致。
	if result_id == "success":
		return "撤离成功"
	if result_id == "death":
		return "撤离失败"
	return "逃跑"


func _get_result_color(result_id: String) -> Color:
	## 返回结算结果语义色；成功为绿、死亡为红、逃跑及未知值为暖黄。
	if result_id == "success":
		return RESULT_SUCCESS_COLOR
	if result_id == "death":
		return RESULT_FAILURE_COLOR
	return RESULT_ESCAPE_COLOR


func _format_duration(total_seconds: float) -> String:
	## 把非负秒数格式化为“分:秒”；与生涯面板和战斗 HUD 的存活时间口径一致。
	# 四舍五入后的总秒数；异常负值回退为 0。
	var resolved_seconds: int = maxi(roundi(total_seconds), 0)
	return "%d 分 %02d 秒" % [resolved_seconds / 60, resolved_seconds % 60]


func _clear_history_list() -> void:
	## 立即把旧卡片移出容器并排队释放；同一帧刷新时不会让旧卡片继续参与布局计算。
	if _history_list == null:
		return
	for child in _history_list.get_children():
		_history_list.remove_child(child)
		child.queue_free()


func _add_empty_state(message: String) -> void:
	## 在列表中添加居中空态；用于无战绩和服务不可用两种不含糊的状态。
	# 空态标签；使用最小高度保证空列表不会压缩成不可见的一行。
	var empty_label: Label = Label.new()
	empty_label.text = message
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.custom_minimum_size = Vector2(0.0, 220.0)
	UI_STYLE_GUIDE.apply_secondary_label(empty_label)
	_history_list.add_child(empty_label)


func _on_stats_changed() -> void:
	## 统计服务变化回调；面板可见时重新读取，隐藏期间由宿主下次打开时主动刷新。
	if is_visible_in_tree():
		refresh()


func _on_close_button_pressed() -> void:
	closed.emit()
