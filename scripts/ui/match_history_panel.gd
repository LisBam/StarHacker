extends PanelContainer
class_name MatchHistoryPanel

## 战绩面板：只读展示 StatsService 持久化的最近 20 局正式结算记录。
## 记录按最新在前排列，训练场、首次教学与不产出正式结算的娱乐模式不会出现在列表中。
## 历史列表每局只显示结果与完成时间；选择摘要后在同一窗口查看完整统计和结算时的具体获得、丢失物品。

## 面板关闭信号；主菜单宿主收到后隐藏遮罩并把焦点交还“统计”分类按钮。
signal closed

## 全局窗口样式指南；窗口、战绩卡片、标题和按钮统一使用项目当前 UI 风格。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 标准物品卡片控件；战绩详情只读复用仓库摘要与完整悬停信息，不开放点击、拖拽或库存操作。
const STORAGE_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/storage_item_control.gd")
## 通用物品卡片视图；详情中的结算物品沿用项目统一固定尺寸，不单独维护战绩专用规格。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 通用物品详情格式器；详情分区总价值与卡片悬停使用同一有效价值口径。
const ITEM_DETAIL_FORMATTER_SCRIPT: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 通用控件交互反馈组件；战绩行与返回按钮复用同一套悬停、按压、释放和焦点动画。
const CONTROL_INTERACTION_FEEDBACK_SCRIPT: Script = preload("res://scripts/ui/control_interaction_feedback.gd")
## 战绩窗口内容横向页边距；默认 18 像素，与生涯面板和其他局外窗口保持一致。
const CONTENT_HORIZONTAL_MARGIN: int = 18
## 战绩窗口内容纵向页边距；默认 16 像素，避免标题、列表与返回按钮贴住窗口描边。
const CONTENT_VERTICAL_MARGIN: int = 16
## 战绩行动态缩放的横向安全边距；默认左右各 6 像素，避免悬停放大后的描边被滚动区域裁切。
const HISTORY_INTERACTION_HORIZONTAL_MARGIN: int = 6
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
## 全局库存服务缓存；只用于把持久化物品快照恢复为只读资源，不改变玩家当前库存或图鉴进度。
var _global_inventory: Node = null
## 历史列表根布局；默认显示，进入某局详情时隐藏以保证列表每条只保留一行摘要。
var _history_root_layout: VBoxContainer = null
## 单局详情根布局；默认隐藏，点击历史行后显示完整统计与结算物品。
var _detail_root_layout: VBoxContainer = null
## 单局详情滚动内容；每次选择历史记录时清空并按该记录快照重新构建。
var _detail_content: VBoxContainer = null
## 单局详情返回按钮；进入详情后接收键盘焦点，点击或按确认键返回历史列表。
var _detail_back_button: Button = null


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_stats_service = get_tree().root.get_node_or_null("StatsService")
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_content()
	if _stats_service != null and _stats_service.has_signal("stats_changed"):
		_stats_service.connect("stats_changed", Callable(self, "_on_stats_changed"))
	refresh()


func refresh() -> void:
	## 从统计服务重新读取近期战绩；界面只消费深复制快照，不持有或修改服务内部数组。
	_show_history_list()
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
	_history_root_layout = root_layout
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
	# 动效安全边距；只缩小列表的可用宽度，不改变每条历史记录的直接父级和刷新协议。
	var history_interaction_margin: MarginContainer = MarginContainer.new()
	history_interaction_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_interaction_margin.add_theme_constant_override("margin_left", HISTORY_INTERACTION_HORIZONTAL_MARGIN)
	history_interaction_margin.add_theme_constant_override("margin_right", HISTORY_INTERACTION_HORIZONTAL_MARGIN)
	history_scroll.add_child(history_interaction_margin)
	# 战绩卡片容器；每条记录独占一张分区卡，按最新到最旧纵向排列。
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 8)
	history_interaction_margin.add_child(_history_list)
	# 返回按钮；关闭面板但不改变战绩数据或统计分类状态。
	var close_button: Button = Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.pressed.connect(_on_close_button_pressed)
	root_layout.add_child(close_button)
	_attach_interaction_feedback(close_button)
	_build_detail_view(content_margin)


func _build_detail_view(content_margin: MarginContainer) -> void:
	## 构建与历史列表共用窗口区域的单局详情页；默认隐藏，选择记录后替换列表显示。
	# 详情根布局；与列表根布局占用同一页边距区域，通过 visible 互斥避免创建第二层窗口。
	var detail_root: VBoxContainer = VBoxContainer.new()
	detail_root.add_theme_constant_override("separation", 10)
	detail_root.visible = false
	content_margin.add_child(detail_root)
	_detail_root_layout = detail_root
	# 详情标题；固定说明当前页面展示单局完整内容，具体结果和时间在滚动区首卡显示。
	var detail_title: Label = Label.new()
	detail_title.text = "战绩详情"
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_title_label(detail_title, 24)
	detail_root.add_child(detail_title)
	# 详情滚动区域；统计字段与物品卡片超出窗口高度时独立滚动，不移动底部返回按钮。
	var detail_scroll: ScrollContainer = ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_root.add_child(detail_scroll)
	# 详情内容容器；每次点击历史行后根据深复制快照完整重建。
	var detail_content: VBoxContainer = VBoxContainer.new()
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(detail_content)
	_detail_content = detail_content
	# 详情返回按钮；只返回历史列表，不关闭整个战绩窗口。
	var detail_back_button: Button = Button.new()
	detail_back_button.text = "返回历史战绩"
	detail_back_button.custom_minimum_size = Vector2(0.0, 42.0)
	detail_back_button.pressed.connect(_show_history_list)
	detail_root.add_child(detail_back_button)
	_attach_interaction_feedback(detail_back_button)
	_detail_back_button = detail_back_button


func _on_history_row_gui_input(event: InputEvent, history_row: Control, display_index: int, run_record: Dictionary) -> void:
	## 处理历史摘要行的鼠标、键盘与手柄确认；按下阶段保留动态反馈，释放后才打开对应深复制记录的详情。
	if event is InputEventMouseButton:
		# 鼠标按键事件；左键按下只消费输入并播放反馈，仍在行内释放时才执行详情切换。
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if not mouse_event.pressed and history_row != null and Rect2(Vector2.ZERO, history_row.size).has_point(mouse_event.position):
				_show_history_detail(display_index, run_record)
		return
	if event.is_action_pressed("ui_accept") or event.is_action_released("ui_accept"):
		accept_event()
		if event.is_action_released("ui_accept"):
			_show_history_detail(display_index, run_record)


func _show_history_detail(display_index: int, run_record: Dictionary) -> void:
	## 打开指定历史记录详情；展示完整统计数值，并按库存快照恢复具体获得与丢失物品。
	if _history_root_layout == null or _detail_root_layout == null or _detail_content == null:
		return
	_clear_detail_content()
	_build_run_detail_summary(display_index, run_record)
	# 结算物品分区标题；具体物品与统计信息分层，便于快速定位本局资产结果。
	var settlement_title: Label = Label.new()
	settlement_title.text = "具体结算物品"
	UI_STYLE_GUIDE.apply_muted_accent_label(settlement_title)
	_detail_content.add_child(settlement_title)
	if not bool(run_record.get("settlement_items_recorded", false)):
		# 旧战绩兼容提示；版本 2 及更旧记录没有物品快照，只能继续展示原有数值详情。
		var legacy_notice: Label = Label.new()
		legacy_notice.text = "该战绩生成时尚未记录具体结算物品"
		legacy_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legacy_notice.custom_minimum_size = Vector2(0.0, 72.0)
		UI_STYLE_GUIDE.apply_secondary_label(legacy_notice)
		_detail_content.add_child(legacy_notice)
	else:
		_build_settlement_item_section(
			"本局获得",
			run_record.get("gained_item_snapshots", []),
			"本局没有获得可结算物品",
			RESULT_SUCCESS_COLOR
		)
		if str(run_record.get("result_id", "")) != "success":
			_build_settlement_item_section(
				"丢失物品",
				run_record.get("lost_item_snapshots", []),
				"本局没有丢失物品",
				RESULT_FAILURE_COLOR
			)
	_history_root_layout.visible = false
	_detail_root_layout.visible = true
	if _detail_back_button != null:
		_detail_back_button.grab_focus()


func _build_run_detail_summary(display_index: int, run_record: Dictionary) -> void:
	## 构建单局结果、完成时间和全部数值字段；读取协议与旧版展开卡片保持一致。
	# 单局摘要外框；使用统一分区样式承载结果头部与详细字段网格。
	var summary_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(summary_panel)
	_detail_content.add_child(summary_panel)
	# 单局摘要内边距；为语义色结果、时间和统计字段保留稳定留白。
	var summary_margin: MarginContainer = MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 12)
	summary_margin.add_theme_constant_override("margin_top", 10)
	summary_margin.add_theme_constant_override("margin_right", 12)
	summary_margin.add_theme_constant_override("margin_bottom", 12)
	summary_panel.add_child(summary_margin)
	# 单局摘要布局；结果头部与四列详细网格上下排列。
	var summary_layout: VBoxContainer = VBoxContainer.new()
	summary_layout.add_theme_constant_override("separation", 10)
	summary_margin.add_child(summary_layout)
	# 单局结果头部；左侧显示历史序号和结果，右侧显示保存的本地结算时间。
	var summary_header: HBoxContainer = HBoxContainer.new()
	summary_header.add_theme_constant_override("separation", 10)
	summary_layout.add_child(summary_header)
	# 单局结果标签；详情页保留序号帮助玩家确认从列表选择的是哪一局。
	var result_label: Label = Label.new()
	result_label.text = "#%02d  %s" % [display_index, _get_result_text(str(run_record.get("result_id", "")))]
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.add_theme_color_override("font_color", _get_result_color(str(run_record.get("result_id", ""))))
	summary_header.add_child(result_label)
	# 单局完成时间标签；旧战绩缺失时显示明确兼容文本，不使用当前时间伪造。
	var completed_at_label: Label = Label.new()
	# 已保存完成时间；去除首尾空白后决定正式文本或兼容提示。
	var completed_at: String = str(run_record.get("completed_at", "")).strip_edges()
	completed_at_label.text = completed_at if not completed_at.is_empty() else "时间未知"
	completed_at_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI_STYLE_GUIDE.apply_secondary_label(completed_at_label)
	summary_header.add_child(completed_at_label)
	# 完整数值网格；四列展示旧版战绩卡片的全部七项信息，列表摘要不再重复这些内容。
	var detail_grid: GridContainer = GridContainer.new()
	detail_grid.columns = 4
	detail_grid.add_theme_constant_override("h_separation", 12)
	detail_grid.add_theme_constant_override("v_separation", 8)
	summary_layout.add_child(detail_grid)
	# 完整数值定义；名称与格式沿用原战绩协议，确保重构只改变信息层级而不改变统计口径。
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
		# 单项详情定义；固定包含玩家可见字段名与已经格式化的数值。
		var detail_definition: Array = raw_detail_definition as Array
		detail_grid.add_child(_build_detail_cell(str(detail_definition[0]), str(detail_definition[1])))


func _build_settlement_item_section(section_name: String, raw_snapshots: Variant, empty_text: String, accent_color: Color) -> void:
	## 构建一类具体结算物品；使用库存兼容加载器恢复历史状态，并用标准卡片提供完整悬停详情。
	# 已恢复结算条目；每项包含独立 Resource 与数量，不进入玩家真实背包、装备栏或仓库。
	var restored_entries: Array[Dictionary] = _restore_settlement_item_snapshots(raw_snapshots)
	# 分区总价值；按历史快照恢复后的有效单价乘实际数量计算，与卡片悬停信息保持一致。
	var total_value: int = _calculate_restored_entries_total_value(restored_entries)
	# 物品分区标题；显示快照组数与总价值，语义色区分获得和丢失。
	var section_title: Label = Label.new()
	section_title.text = "%s（%d） 总价值：%d" % [section_name, restored_entries.size(), total_value]
	section_title.add_theme_font_size_override("font_size", 18)
	section_title.add_theme_color_override("font_color", accent_color)
	_detail_content.add_child(section_title)
	if restored_entries.is_empty():
		# 空物品提示；明确本局没有对应物品，不让空白区域被误认为加载失败。
		var empty_label: Label = Label.new()
		empty_label.text = empty_text
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0.0, 48.0)
		UI_STYLE_GUIDE.apply_secondary_label(empty_label)
		_detail_content.add_child(empty_label)
		return
	# 居中容器；标准物品卡按内容宽度收缩并整体居中，行尾不生成空白占位。
	var grid_center: CenterContainer = CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_content.add_child(grid_center)
	# 物品卡片网格；每行固定四张，与正式战斗结算窗口保持一致。
	var item_grid: GridContainer = GridContainer.new()
	item_grid.columns = 4
	item_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 6)
	grid_center.add_child(item_grid)
	for restored_entry in restored_entries:
		# 历史物品资源；由库存快照恢复为独立实例，仅供卡片摘要与悬停详情读取。
		var item_resource: Resource = restored_entry.get("resource") as Resource
		if item_resource == null:
			continue
		# 历史物品数量；堆叠资源按快照数量展示，武器与装备固定为 1。
		var quantity: int = maxi(int(restored_entry.get("quantity", 1)), 1)
		# 只读物品卡片；空位置和下标禁用快捷操作与拖拽，仅保留完整详情 tooltip。
		var item_control: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
		item_control.custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
		item_control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		item_control.call("configure", item_resource, "", -1, false, "", quantity)
		item_grid.add_child(item_control)


func _restore_settlement_item_snapshots(raw_snapshots: Variant) -> Array[Dictionary]:
	## 把持久化物品字典恢复为只读结算条目；库存服务缺失或单项损坏时跳过该项，不影响其他详情。
	# 恢复结果数组；顺序与正式结算窗口保存顺序一致。
	var restored_entries: Array[Dictionary] = []
	if not (raw_snapshots is Array):
		return restored_entries
	if _global_inventory == null:
		_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if _global_inventory == null or not _global_inventory.has_method("deserialize_item_snapshot"):
		return restored_entries
	for raw_snapshot in raw_snapshots as Array:
		if not (raw_snapshot is Dictionary):
			continue
		# 已恢复物品条目；库存加载器负责模板查找、强化、耐久、品质和数量兼容。
		var restored_entry: Dictionary = _global_inventory.call("deserialize_item_snapshot", raw_snapshot as Dictionary) as Dictionary
		if not restored_entry.is_empty() and restored_entry.get("resource") is Resource:
			restored_entries.append(restored_entry)
	return restored_entries


func _calculate_restored_entries_total_value(restored_entries: Array[Dictionary]) -> int:
	## 计算历史结算物品总价值；资源状态来自完成时快照，不读取玩家当前库存中的同名物品。
	# 历史结算总价值；默认 0，逐项累加非负有效价值与数量乘积。
	var total_value: int = 0
	for restored_entry in restored_entries:
		# 历史物品资源；异常空资源不参与价值计算。
		var item_resource: Resource = restored_entry.get("resource") as Resource
		if item_resource == null:
			continue
		# 历史物品数量；与卡片数量角标使用同一非负口径。
		var quantity: int = maxi(int(restored_entry.get("quantity", 1)), 1)
		total_value += maxi(int(ITEM_DETAIL_FORMATTER_SCRIPT.call("get_item_value", item_resource)), 0) * quantity
	return maxi(total_value, 0)


func _show_history_list() -> void:
	## 返回历史摘要列表；列表仍保留最新在前顺序，每条只显示一行结果与完成时间。
	if _history_root_layout != null:
		_history_root_layout.visible = true
	if _detail_root_layout != null:
		_detail_root_layout.visible = false
	_clear_detail_content()


func _clear_detail_content() -> void:
	## 清空当前单局详情节点；返回列表或切换记录时释放恢复的只读物品资源与卡片。
	if _detail_content == null:
		return
	for child in _detail_content.get_children():
		_detail_content.remove_child(child)
		child.queue_free()


func _build_history_card(display_index: int, run_record: Dictionary) -> Control:
	## 构建一条近期战绩卡片；头部显示序号、结算结果与时间，下方展示完整单局统计和结算价值。
	## 列表收敛补充：详细字段网格保留为详情构建协议参考但不在历史行显示，点击整行后进入独立详情视图。
	# 战绩卡片外框；统一使用窗口内部的浅层分区样式。
	var history_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(history_panel)
	history_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_panel.focus_mode = Control.FOCUS_ALL
	history_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	history_panel.tooltip_text = "点击查看本局详细信息与结算物品"
	# 卡片内边距；保证结果标题与数值网格不贴住分区描边。
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_margin.add_theme_constant_override("margin_left", 12)
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_right", 12)
	card_margin.add_theme_constant_override("margin_bottom", 12)
	history_panel.add_child(card_margin)
	# 卡片纵向布局；头部与详细字段网格分行排列。
	var card_layout: VBoxContainer = VBoxContainer.new()
	card_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_layout.add_theme_constant_override("separation", 8)
	card_margin.add_child(card_layout)
	# 卡片头部；左侧显示列表序号和结果，右侧显示本地结算时间。
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 10)
	card_layout.add_child(header_row)
	# 结果标识；由稳定 result_id 映射为玩家可见中文并应用对应语义色。
	var result_label: Label = Label.new()
	result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_label.text = _get_result_text(str(run_record.get("result_id", "")))
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.add_theme_color_override("font_color", _get_result_color(str(run_record.get("result_id", ""))))
	header_row.add_child(result_label)
	# 结算时间标签；服务保存本地时间字符串，旧记录缺失时明确显示未知而不伪造时间。
	var completed_at_label: Label = Label.new()
	completed_at_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 已保存的本地时间；空字符串使用兼容提示。
	var completed_at: String = str(run_record.get("completed_at", "")).strip_edges()
	completed_at_label.text = completed_at if not completed_at.is_empty() else "时间未知"
	completed_at_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI_STYLE_GUIDE.apply_secondary_label(completed_at_label)
	header_row.add_child(completed_at_label)
	# 详细字段网格；四列布局在 900 像素窗口内同时兼顾字段密度与可读性。
	var detail_grid: GridContainer = GridContainer.new()
	detail_grid.name = "CollapsedDetailGrid"
	detail_grid.columns = 4
	detail_grid.add_theme_constant_override("h_separation", 12)
	detail_grid.add_theme_constant_override("v_separation", 6)
	detail_grid.visible = false
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
	history_panel.gui_input.connect(Callable(self, "_on_history_row_gui_input").bind(history_panel, display_index, run_record.duplicate(true)))
	_attach_interaction_feedback(history_panel)
	return history_panel


func _attach_interaction_feedback(target_control: Control) -> void:
	## 为可操作控件挂载独立动效组件；业务控件只负责点击结果，所有视觉状态统一由组件维护。
	if target_control == null:
		return
	# 控件交互反馈实例；使用组件默认参数，设计人员仍可在场景化复用时通过检查器调整全部动效数值。
	var interaction_feedback: Node = CONTROL_INTERACTION_FEEDBACK_SCRIPT.new() as Node
	interaction_feedback.name = "InteractionFeedback"
	target_control.add_child(interaction_feedback)


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


func _unhandled_key_input(event: InputEvent) -> void:
	## 战绩窗口处理返回输入；详情页优先返回历史列表，列表页再次返回才关闭整个窗口。
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _detail_root_layout != null and _detail_root_layout.visible:
		_show_history_list()
	else:
		_on_close_button_pressed()


func _on_stats_changed() -> void:
	## 统计服务变化回调；面板可见时重新读取，隐藏期间由宿主下次打开时主动刷新。
	if is_visible_in_tree():
		refresh()


func _on_close_button_pressed() -> void:
	closed.emit()
