extends PanelContainer
class_name RiskContractViewPanel

## 风险合约查看面板只读展示本局已经确认的负面词条与怪物掉落奖励。
## 面板不持有会话状态，也不允许修改或刷新词条；宿主每次打开时传入当前稳定 ID，
## 显示名称、奖励数值与合法性统一从 ModeExtensionRules 读取，避免 HUD 复制玩法规则。

## 玩家点击关闭按钮时派发；宿主负责恢复左侧“查看风险合约”入口。
signal closed

## 全局窗口样式指南；查看面板、词条卡片和文字随当前 UI 风格即时刷新。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 总奖励语义色；沿用风险合约选择界面的收益绿色，突出本局怪物掉落加成。
const TOTAL_REWARD_COLOR: Color = Color(0.34, 1.0, 0.62, 1.0)
## 面板水平内边距；默认 16 像素，在 420 像素左栏内为词条名称保留足够宽度。
const CONTENT_HORIZONTAL_MARGIN: int = 16
## 面板垂直内边距；默认 14 像素，使标题、列表与关闭按钮保持紧凑间距。
const CONTENT_VERTICAL_MARGIN: int = 14

## 当前规范化风险词条 ID；最多四项，顺序由 ModeExtensionRules 的定义表稳定决定。
var _modifier_ids: Array[String] = []
## 风险词条列表容器；每次打开时清空并按当前本局配置重新构建。
var _modifier_list: VBoxContainer = null
## 空合约说明标签；未启用风险合约时显示，存在合法词条时隐藏。
var _empty_state_label: Label = null
## 总奖励标签；显示已选项数和加算后的怪物掉落加成，空合约时显示未开启摘要。
var _total_reward_label: Label = null


func _ready() -> void:
	## 构建一次固定查看结构；每次 present() 只替换列表内容，不重复创建外层控件。
	UI_STYLE_GUIDE.apply_window_panel(self)
	_build_content()
	_refresh_content()


func present(modifier_ids: Array) -> void:
	## 展示本局风险合约；外部数组会先过滤未知、重复、同类多档与超过四项的数据。
	_modifier_ids = ModeExtensionRules.normalize_risk_modifier_ids(modifier_ids)
	if is_node_ready():
		_refresh_content()
	visible = true


func dismiss() -> void:
	## 关闭只读面板；不会改变 SessionState、掉落倍率或任何已选风险词条。
	visible = false


func get_displayed_modifier_ids() -> Array[String]:
	## 返回当前面板展示的词条 ID 副本；用于自动验证且不允许调用方改写内部列表。
	return _modifier_ids.duplicate()


func _build_content() -> void:
	## 构建标题、说明、可伸展词条列表、总奖励和关闭按钮。
	# 内容页边距；把所有文字和按钮与窗口边框隔开。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_top", CONTENT_VERTICAL_MARGIN)
	content_margin.add_theme_constant_override("margin_right", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", CONTENT_VERTICAL_MARGIN)
	add_child(content_margin)
	# 根纵向布局；在固定 420 像素高度内让词条列表优先占用剩余空间。
	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 9)
	content_margin.add_child(root_layout)
	# 面板标题；明确内容是已经锁定的本局配置，而不是可编辑的模式扩展入口。
	var title_label: Label = Label.new()
	title_label.name = "RiskContractTitle"
	title_label.text = "本局风险合约"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_title_label(title_label, 22)
	root_layout.add_child(title_label)
	# 面板说明；提示玩家这里仅用于查看负面效果和对应奖励。
	var description_label: Label = Label.new()
	description_label.name = "RiskContractDescription"
	description_label.text = "查看本局已选择的负面词条与怪物掉落加成。"
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_secondary_label(description_label)
	root_layout.add_child(description_label)
	# 词条滚动区；当前最多四项，保留滚动能力以兼容未来扩展更多合约项。
	var modifier_scroll: ScrollContainer = ScrollContainer.new()
	modifier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modifier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_layout.add_child(modifier_scroll)
	_modifier_list = VBoxContainer.new()
	_modifier_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modifier_list.add_theme_constant_override("separation", 7)
	modifier_scroll.add_child(_modifier_list)
	_empty_state_label = Label.new()
	_empty_state_label.name = "RiskContractEmptyState"
	_empty_state_label.text = "本局未启用风险合约。"
	_empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_state_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_secondary_label(_empty_state_label)
	_modifier_list.add_child(_empty_state_label)
	_total_reward_label = Label.new()
	_total_reward_label.name = "RiskContractTotalReward"
	_total_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_reward_label.add_theme_color_override("font_color", TOTAL_REWARD_COLOR)
	root_layout.add_child(_total_reward_label)
	# 关闭按钮；只关闭查看面板，不退出暂停菜单或恢复战斗。
	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.pressed.connect(_on_close_button_pressed)
	root_layout.add_child(close_button)


func _refresh_content() -> void:
	## 按当前规范化词条重建卡片，并更新空状态与总掉落奖励。
	if _modifier_list == null or _empty_state_label == null or _total_reward_label == null:
		return
	for list_child in _modifier_list.get_children():
		if list_child != _empty_state_label:
			_modifier_list.remove_child(list_child)
			list_child.queue_free()
	_empty_state_label.visible = _modifier_ids.is_empty()
	for modifier_id in _modifier_ids:
		# 当前词条定义；规范化后的 ID 必定存在，空值保护可避免规则表热更新时界面报错。
		var modifier_definition: Dictionary = ModeExtensionRules.get_risk_definition(modifier_id)
		if modifier_definition.is_empty():
			continue
		_modifier_list.add_child(_build_modifier_card(modifier_definition))
	# 总掉落加成百分比；所有已选词条继续采用规则表的加算口径。
	var total_drop_bonus_percent: int = roundi(ModeExtensionRules.get_total_drop_bonus_ratio(_modifier_ids) * 100.0)
	if _modifier_ids.is_empty():
		_total_reward_label.text = "风险合约未开启 · 怪物掉落加成 +0%"
	else:
		_total_reward_label.text = "共 %d 项 · 怪物掉落总加成 +%d%%" % [_modifier_ids.size(), total_drop_bonus_percent]


func _build_modifier_card(modifier_definition: Dictionary) -> PanelContainer:
	## 构建单条只读风险卡；左侧显示负面效果，右侧显示该项独立怪物掉落奖励。
	# 词条卡外框；使用通用分区样式，与选择阶段的风险词条视觉保持一致。
	var card_panel: PanelContainer = PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_section_panel(card_panel)
	# 词条卡内边距；为左右两列文字提供稳定留白。
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 10)
	card_margin.add_theme_constant_override("margin_top", 8)
	card_margin.add_theme_constant_override("margin_right", 10)
	card_margin.add_theme_constant_override("margin_bottom", 8)
	card_panel.add_child(card_margin)
	# 词条横向布局；名称优先伸展，奖励保持右对齐。
	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	card_margin.add_child(card_row)
	# 负面词条名称；直接使用规则表显示文本，包含具体强度数值。
	var modifier_name_label: Label = Label.new()
	modifier_name_label.text = str(modifier_definition.get("display_name", "未知风险词条"))
	modifier_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_row.add_child(modifier_name_label)
	# 该词条掉落奖励百分比；规则表以比例存储，这里四舍五入为玩家可读整数。
	var drop_bonus_percent: int = roundi(float(modifier_definition.get("drop_bonus_ratio", 0.0)) * 100.0)
	# 该词条奖励标签；固定右对齐且使用收益语义色。
	var reward_label: Label = Label.new()
	reward_label.text = "掉落 +%d%%" % drop_bonus_percent
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward_label.add_theme_color_override("font_color", TOTAL_REWARD_COLOR)
	card_row.add_child(reward_label)
	return card_panel


func _on_close_button_pressed() -> void:
	## 关闭当前查看面板并通知战斗 HUD 恢复左栏入口按钮。
	dismiss()
	closed.emit()
