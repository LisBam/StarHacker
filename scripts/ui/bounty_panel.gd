extends PanelContainer
class_name BountyPanel

## 悬赏面板：展示当天全部随机悬赏的标题、说明、进度与奖励状态。
## 面板只读取 BountyService 快照并响应其信号，不推进进度、不发放奖励，也不保存任何悬赏数据副本。

## 面板关闭信号；宿主收到后隐藏遮罩并恢复焦点。
signal closed

## 全局窗口样式指南；面板窗口、悬赏卡与按钮统一从这里取色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 已完成状态文本颜色；使用与结算成功一致的绿色语义色，不参与主题换肤。
const COMPLETED_TEXT_COLOR: Color = Color(0.35, 1.0, 0.72, 1.0)
## 进度条最小尺寸；宽度自适应卡片，固定 14 像素高度保证纤细但可读。
const PROGRESS_BAR_MINIMUM_HEIGHT: float = 14.0
## 悬赏窗口内容横向页边距；默认 18 像素，避免滚动列表和悬赏卡边框贴住或遮盖最外层窗口描边。
const CONTENT_HORIZONTAL_MARGIN: int = 18
## 悬赏窗口内容纵向页边距；默认 16 像素，保证标题、列表和返回按钮与最外层窗口边框保持稳定留白。
const CONTENT_VERTICAL_MARGIN: int = 16

## 悬赏服务缓存；ready 时解析，缺失时面板显示服务不可用提示。
var _bounty_service: Node = null
## 日期提示标签；显示当前悬赏所属日期与刷新规则。
var _date_label: Label = null
## 悬赏卡列表容器；每次刷新按快照重建全部悬赏卡。
var _bounty_list: VBoxContainer = null


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_bounty_service = get_tree().root.get_node_or_null("BountyService")
	_build_content()
	if _bounty_service != null and _bounty_service.has_signal("bounties_changed"):
		_bounty_service.connect("bounties_changed", Callable(self, "_on_bounties_changed"))
	refresh()


func refresh() -> void:
	## 面板打开时的统一刷新入口；按服务快照重建全部悬赏卡。
	if _bounty_list == null:
		return
	for bounty_card in _bounty_list.get_children():
		bounty_card.queue_free()
	if _bounty_service == null or not _bounty_service.has_method("get_bounty_snapshot"):
		_date_label.text = "悬赏服务不可用"
		return
	# 悬赏快照；包含日期键与全部悬赏的只读副本。
	var snapshot: Dictionary = _bounty_service.call("get_bounty_snapshot") as Dictionary
	_date_label.text = "%s 的悬赏 · 每天刷新一批随机悬赏，完成后奖励自动发放" % str(snapshot.get("date_key", ""))
	# 快照悬赏数组；为空时显示占位提示。
	var bounties: Array = snapshot.get("bounties", []) as Array
	if bounties.is_empty():
		# 空悬赏占位提示；正常情况下每日刷新至少生成一条。
		var empty_label: Label = Label.new()
		empty_label.text = "今日暂无悬赏"
		UI_STYLE_GUIDE.apply_secondary_label(empty_label)
		_bounty_list.add_child(empty_label)
		return
	for raw_bounty in bounties:
		if raw_bounty is Dictionary:
			_bounty_list.add_child(_build_bounty_card(raw_bounty as Dictionary))


func _build_content() -> void:
	## 构建面板完整内容；标题、日期提示、悬赏滚动列表与返回按钮。
	# 内容页边距容器；将全部内部控件与最外层窗口描边隔开，滚动列表与卡片扩展时也不会覆盖边框。
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
	title_label.text = "悬赏"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_title_label(title_label, 24)
	root_layout.add_child(title_label)
	_date_label = Label.new()
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_secondary_label(_date_label)
	root_layout.add_child(_date_label)
	# 悬赏滚动区域；悬赏数量增加时保持面板高度稳定。
	var bounty_scroll: ScrollContainer = ScrollContainer.new()
	bounty_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bounty_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_layout.add_child(bounty_scroll)
	_bounty_list = VBoxContainer.new()
	_bounty_list.add_theme_constant_override("separation", 10)
	_bounty_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bounty_scroll.add_child(_bounty_list)
	# 返回按钮；与其他局外面板同规格。
	var close_button: Button = Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.pressed.connect(_on_close_button_pressed)
	root_layout.add_child(close_button)


func _build_bounty_card(bounty: Dictionary) -> Control:
	## 构建单条悬赏卡；标题与奖励在首行，说明在次行，进度条与状态在底行。
	# 悬赏卡外框；使用统一浅色分区面板样式。
	var card_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(card_panel)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 悬赏卡内边距容器；四边留出可读空隙。
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 12)
	card_margin.add_theme_constant_override("margin_right", 12)
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	card_panel.add_child(card_margin)
	# 悬赏卡纵向布局；标题行、说明行与进度行。
	var card_layout: VBoxContainer = VBoxContainer.new()
	card_layout.add_theme_constant_override("separation", 6)
	card_margin.add_child(card_layout)
	# 标题行；左侧悬赏标题、右侧奖励文本。
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	card_layout.add_child(header_row)
	# 悬赏标题标签；使用 16 号标题字号。
	var title_label: Label = Label.new()
	title_label.text = str(bounty.get("title", "悬赏"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_title_label(title_label, 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_row.add_child(title_label)
	# 奖励文本标签；星穹显示金额，强化石显示类别说明。
	var reward_label: Label = Label.new()
	reward_label.text = "奖励：稀有强化石" if str(bounty.get("reward_kind", "gold")) == "stone" else "奖励：%d 星穹" % int(bounty.get("reward_gold", 0))
	UI_STYLE_GUIDE.apply_muted_accent_label(reward_label)
	header_row.add_child(reward_label)
	# 悬赏说明标签；自动换行展示完整要求。
	var description_label: Label = Label.new()
	description_label.text = str(bounty.get("description", ""))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(description_label)
	card_layout.add_child(description_label)
	# 进度行；进度条与状态文本并排。
	var progress_row: HBoxContainer = HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 10)
	card_layout.add_child(progress_row)
	# 悬赏是否已完成；决定进度条数值与状态文本颜色。
	var is_completed: bool = bool(bounty.get("completed", false))
	# 悬赏目标值；至少为 1 避免进度条除零。
	var required_value: int = maxi(int(bounty.get("required", 1)), 1)
	# 悬赏当前进度；展示时不超过目标值。
	var progress_value: int = mini(int(bounty.get("progress", 0)), required_value)
	# 进度条控件；只读展示完成比例，不接收拖动输入。
	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = float(required_value)
	progress_bar.value = float(required_value if is_completed else progress_value)
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0.0, PROGRESS_BAR_MINIMUM_HEIGHT)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_row.add_child(progress_bar)
	# 状态文本标签；完成后显示绿色“已完成”，未完成显示当前进度比。
	var status_label: Label = Label.new()
	if is_completed:
		status_label.text = "已完成 · 奖励已发放"
		status_label.add_theme_color_override("font_color", COMPLETED_TEXT_COLOR)
	else:
		status_label.text = "%d / %d" % [progress_value, required_value]
		UI_STYLE_GUIDE.apply_secondary_label(status_label)
	progress_row.add_child(status_label)
	return card_panel


func _on_bounties_changed() -> void:
	## 悬赏服务变化回调；面板可见时才重建列表，隐藏期间等待宿主重新打开时刷新。
	if is_visible_in_tree():
		refresh()


func _on_close_button_pressed() -> void:
	closed.emit()
