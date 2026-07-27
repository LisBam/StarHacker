extends PanelContainer
class_name ModeExtensionSelectPanel

## 模式扩展选择面板在骇入模式确定后、正式进入战斗前配置本局附加规则。
## 面板从 ModeExtensionRules 动态读取扩展与风险词条，不保存跨场景状态；
## 单人宿主把确认结果写入 SessionState，联机宿主则交给 NetworkSession 由房主同步。
## 风险合约启用时立即生成四个不同效果类别的候选，至少选择一项后才允许确认。

## 配置确认信号；参数分别为已启用模式扩展 ID 与风险合约词条 ID，宿主负责保存或同步。
signal configuration_confirmed(extension_ids: Array[String], risk_modifier_ids: Array[String])
## 面板关闭信号；宿主收到后返回上一级界面，不提交当前尚未确认的编辑结果。
signal closed

## 全局窗口样式指南；窗口、分区、按钮与文字统一从这里取色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 风险合约成功语义色；用于显示总掉落加成，保持与其他收益文案一致。
const RISK_REWARD_COLOR: Color = Color(0.34, 1.0, 0.62, 1.0)
## 风险合约警告语义色；用于尚未选择必需词条时提示玩家。
const RISK_WARNING_COLOR: Color = Color(1.0, 0.80, 0.30, 1.0)
## 面板内容横向页边距；默认 18 像素，防止分区边框贴住最外层窗口描边。
const CONTENT_HORIZONTAL_MARGIN: int = 18
## 面板内容纵向页边距；默认 16 像素，保证标题和底部按钮拥有稳定留白。
const CONTENT_VERTICAL_MARGIN: int = 16

## 当前骇入模式；用于判断风险合约是否兼容，默认标准骇入允许正常配置。
var _hack_variant: String = HackModeRules.VARIANT_STANDARD
## 已启用扩展 ID；编辑期间随复选框变化，确认时再统一规范化并派发给宿主。
var _selected_extension_ids: Array[String] = []
## 已选风险词条 ID；只允许来自当前四个候选，并由规则表限制每类最多一档。
var _selected_risk_modifier_ids: Array[String] = []
## 当前四个风险候选 ID；启用风险合约或点击刷新时重新生成。
var _risk_offer_ids: Array[String] = []
## 确认按钮文案；单人默认为“进入游戏”，联机宿主可改为“应用设置”。
var _confirm_button_text: String = "进入游戏"
## 模式扩展复选框表；键为扩展 ID，值为对应 CheckButton，刷新状态时无需重建整个列表。
var _extension_check_buttons: Dictionary = {}
## 风险候选复选框表；键为词条 ID，值为对应 CheckButton，每次刷新候选时重建。
var _risk_modifier_check_buttons: Dictionary = {}
## 风险候选随机源；ready 时随机化，自动测试可通过 set_risk_random_seed 固定结果。
var _risk_random: RandomNumberGenerator = RandomNumberGenerator.new()
## 风险合约详情分区；只有风险合约已启用时显示，关闭扩展后保留候选供本次返回勾选。
var _risk_section: PanelContainer = null
## 风险候选列表容器；每次刷新先清空，再按四个候选 ID 创建复选框。
var _risk_offer_container: VBoxContainer = null
## 风险状态标签；显示至少选择一项的校验提示或当前总掉落加成。
var _risk_status_label: Label = null
## 确认按钮；风险合约未选择词条或当前配置不兼容时禁用。
var _confirm_button: Button = null


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_risk_random.randomize()
	_build_content()
	_refresh_from_configuration()


func configure(hack_variant: String, extension_ids: Array = [], risk_modifier_ids: Array = [], confirm_button_text: String = "进入游戏") -> void:
	## 设置本次编辑上下文；可在节点进入场景树前调用，ready 后会按缓存配置构建界面。
	_hack_variant = HackModeRules.normalize_variant(hack_variant)
	_confirm_button_text = confirm_button_text
	# 标准配置；已有联机配置会按当前模式重新校验，超频模式自动移除需要结算的风险合约。
	var sanitized_configuration: Dictionary = ModeExtensionRules.sanitize_configuration(extension_ids, risk_modifier_ids, _hack_variant)
	_selected_extension_ids = _to_string_array(sanitized_configuration.get("extension_ids", []))
	_selected_risk_modifier_ids = _to_string_array(sanitized_configuration.get("risk_modifier_ids", []))
	_risk_offer_ids = _selected_risk_modifier_ids.duplicate()
	if is_node_ready():
		_refresh_from_configuration()


func set_risk_random_seed(seed_value: int) -> void:
	## 固定风险候选随机种子；主要供无头验证使用，正常玩家流程无需调用。
	_risk_random.seed = seed_value


func _build_content() -> void:
	## 构建标题、扩展列表、风险合约详情与底部操作区；扩展和词条内容均从规则表读取。
	# 内容页边距容器；统一隔离窗口最外层描边与内部业务分区。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_top", CONTENT_VERTICAL_MARGIN)
	content_margin.add_theme_constant_override("margin_right", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", CONTENT_VERTICAL_MARGIN)
	add_child(content_margin)
	# 根布局容器；纵向排列标题、说明、滚动内容、状态与底部按钮。
	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 10)
	content_margin.add_child(root_layout)
	# 面板标题；明确这是骇入模式之外的第三个规则维度。
	var title_label: Label = Label.new()
	title_label.text = "模式扩展"
	UI_STYLE_GUIDE.apply_title_label(title_label, 24)
	root_layout.add_child(title_label)
	# 面板副标题；说明模式扩展可多选或完全不选。
	var subtitle_label: Label = Label.new()
	subtitle_label.text = "可同时勾选多个模式扩展，也可以不启用任何扩展直接开始。"
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(subtitle_label)
	root_layout.add_child(subtitle_label)
	# 主滚动区；未来扩展数量增加或窗口高度较小时仍能访问全部配置。
	var content_scroll: ScrollContainer = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_layout.add_child(content_scroll)
	# 滚动内容布局；模式扩展卡和风险合约详情按顺序纵向排列。
	var extension_layout: VBoxContainer = VBoxContainer.new()
	extension_layout.add_theme_constant_override("separation", 10)
	extension_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(extension_layout)
	_extension_check_buttons.clear()
	for extension_definition in ModeExtensionRules.get_extension_definitions():
		extension_layout.add_child(_build_extension_card(extension_definition))
	_risk_section = _build_risk_section()
	extension_layout.add_child(_risk_section)
	# 底部操作行；返回不提交，确认只在当前配置满足规则时可用。
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	root_layout.add_child(action_row)
	# 返回按钮；回到上一级模式或联机面板。
	var close_button: Button = Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(_on_close_button_pressed)
	action_row.add_child(close_button)
	_confirm_button = Button.new()
	_confirm_button.text = _confirm_button_text
	_confirm_button.custom_minimum_size = Vector2(0.0, 42.0)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_primary_button(_confirm_button)
	_confirm_button.pressed.connect(_on_confirm_button_pressed)
	action_row.add_child(_confirm_button)


func _build_extension_card(extension_definition: Dictionary) -> Control:
	## 构建一个模式扩展卡；复选框控制启用状态，下方说明长期展示用途与兼容条件。
	# 扩展卡外框；与项目其他功能卡统一使用弱化分区样式。
	var card_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(card_panel)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 扩展卡内边距；四边留出可读空隙。
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 12)
	card_margin.add_theme_constant_override("margin_right", 12)
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	card_panel.add_child(card_margin)
	# 扩展卡纵向布局；复选框在上、完整说明在下。
	var card_layout: VBoxContainer = VBoxContainer.new()
	card_layout.add_theme_constant_override("separation", 4)
	card_margin.add_child(card_layout)
	# 扩展稳定 ID；用于连接勾选回调和保存复选框引用。
	var extension_id: String = str(extension_definition.get("id", ""))
	# 扩展复选框；支持多个扩展同时勾选，不使用互斥按钮组。
	var extension_check_button: CheckButton = CheckButton.new()
	extension_check_button.text = str(extension_definition.get("display_name", "模式扩展"))
	extension_check_button.toggled.connect(_on_extension_toggled.bind(extension_id))
	card_layout.add_child(extension_check_button)
	_extension_check_buttons[extension_id] = extension_check_button
	# 扩展说明；风险合约等复杂扩展的具体候选在独立详情分区继续配置。
	var description_label: Label = Label.new()
	description_label.text = str(extension_definition.get("description", ""))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(description_label)
	card_layout.add_child(description_label)
	return card_panel


func _build_risk_section() -> PanelContainer:
	## 构建风险合约详情分区；包含规则提示、四个候选、刷新按钮与总掉落加成。
	# 风险分区外框；独立于扩展卡，启用后显示详细配置。
	var section_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(section_panel)
	section_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 风险分区内边距；为候选复选框和底部按钮提供统一留白。
	var section_margin: MarginContainer = MarginContainer.new()
	section_margin.add_theme_constant_override("margin_left", 12)
	section_margin.add_theme_constant_override("margin_right", 12)
	section_margin.add_theme_constant_override("margin_top", 10)
	section_margin.add_theme_constant_override("margin_bottom", 10)
	section_panel.add_child(section_margin)
	# 风险分区根布局；标题、说明、候选、刷新行依次排列。
	var section_layout: VBoxContainer = VBoxContainer.new()
	section_layout.add_theme_constant_override("separation", 7)
	section_margin.add_child(section_layout)
	# 风险分区标题；提示候选是本次合约的随机结果。
	var section_title: Label = Label.new()
	section_title.text = "本次风险词条"
	UI_STYLE_GUIDE.apply_muted_accent_label(section_title)
	section_layout.add_child(section_title)
	# 风险规则说明；明确候选可多选但至少选一项，同类档位不会同时出现。
	var rule_label: Label = Label.new()
	rule_label.text = "从四个随机负面词条中至少选择一项，可多选；刷新会替换全部候选并清空当前选择。"
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(rule_label)
	section_layout.add_child(rule_label)
	_risk_offer_container = VBoxContainer.new()
	_risk_offer_container.add_theme_constant_override("separation", 4)
	section_layout.add_child(_risk_offer_container)
	# 风险底部行；左侧展示总奖励，右侧提供免费刷新候选入口。
	var risk_footer: HBoxContainer = HBoxContainer.new()
	risk_footer.add_theme_constant_override("separation", 10)
	section_layout.add_child(risk_footer)
	_risk_status_label = Label.new()
	_risk_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_risk_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	risk_footer.add_child(_risk_status_label)
	# 刷新按钮；当前没有刷新成本与次数限制，每次生成新的四类候选。
	var refresh_button: Button = Button.new()
	refresh_button.text = "刷新词条"
	refresh_button.custom_minimum_size = Vector2(112.0, 36.0)
	refresh_button.pressed.connect(_on_refresh_risk_offer_pressed)
	risk_footer.add_child(refresh_button)
	return section_panel


func _refresh_from_configuration() -> void:
	## 把缓存配置写入控件；调用前可来自单人默认值、联机同步值或上一次已确认配置。
	for extension_definition in ModeExtensionRules.get_extension_definitions():
		# 当前扩展 ID；用于查找复选框与兼容状态。
		var extension_id: String = str(extension_definition.get("id", ""))
		# 扩展复选框；缺失时只跳过该项，不阻断其他扩展刷新。
		var extension_check_button: CheckButton = _extension_check_buttons.get(extension_id) as CheckButton
		if extension_check_button == null:
			continue
		# 当前模式兼容性；超频等无结算模式禁用风险合约并在工具提示中说明原因。
		var compatible: bool = ModeExtensionRules.is_extension_compatible(extension_id, _hack_variant)
		extension_check_button.disabled = not compatible
		extension_check_button.set_pressed_no_signal(compatible and _selected_extension_ids.has(extension_id))
		extension_check_button.tooltip_text = "" if compatible else "当前骇入模式不产出物品结算，无法启用此扩展。"
	if _selected_extension_ids.has(ModeExtensionRules.EXTENSION_RISK_CONTRACT):
		_fill_risk_offer_around_selected()
	_rebuild_risk_offer()
	_refresh_validation_state()
	if _confirm_button != null:
		_confirm_button.text = _confirm_button_text


func _fill_risk_offer_around_selected() -> void:
	## 保留已有已选词条并补足到四个候选；联机房主重新打开设置时不会丢失已确认选择。
	_risk_offer_ids = ModeExtensionRules.normalize_risk_modifier_ids(_risk_offer_ids)
	# 已使用类别；防止补充候选与保留词条属于同一效果类别。
	var used_families: Array[String] = []
	for modifier_id in _risk_offer_ids:
		# 已选词条类别；合法词条必定非空，仍过滤空值避免异常数据污染排除表。
		var family_id: String = ModeExtensionRules.get_risk_family(modifier_id)
		if not family_id.is_empty():
			used_families.append(family_id)
	# 缺少候选数量；已有四项时为零，不再消耗随机源。
	var missing_count: int = maxi(ModeExtensionRules.RISK_OFFER_COUNT - _risk_offer_ids.size(), 0)
	_risk_offer_ids.append_array(ModeExtensionRules.roll_risk_modifier_ids(_risk_random, missing_count, used_families))


func _generate_new_risk_offer() -> void:
	## 生成全新的四个风险候选并清空选择；启用扩展和点击刷新共用该入口。
	_selected_risk_modifier_ids.clear()
	_risk_offer_ids = ModeExtensionRules.roll_risk_modifier_ids(_risk_random, ModeExtensionRules.RISK_OFFER_COUNT)
	_rebuild_risk_offer()
	_refresh_validation_state()


func _rebuild_risk_offer() -> void:
	## 重建四个风险候选复选框；每项同时展示负面效果和该项独立掉落奖励。
	if _risk_section == null or _risk_offer_container == null:
		return
	_risk_section.visible = _selected_extension_ids.has(ModeExtensionRules.EXTENSION_RISK_CONTRACT)
	for offer_child in _risk_offer_container.get_children():
		offer_child.queue_free()
	_risk_modifier_check_buttons.clear()
	if not _risk_section.visible:
		return
	if _risk_offer_ids.is_empty():
		_generate_new_risk_offer()
		return
	for modifier_id in _risk_offer_ids:
		# 风险词条定义；候选已规范化，空定义只作为异常保护跳过。
		var risk_definition: Dictionary = ModeExtensionRules.get_risk_definition(modifier_id)
		if risk_definition.is_empty():
			continue
		# 词条独立掉落奖励百分比；四舍五入显示为规则表中的整数百分点。
		var drop_bonus_percent: int = roundi(float(risk_definition.get("drop_bonus_ratio", 0.0)) * 100.0)
		# 风险词条复选框；多个候选之间不互斥，玩家可以选择一到四项。
		var modifier_check_button: CheckButton = CheckButton.new()
		modifier_check_button.text = "%s    怪物掉落+%d%%" % [str(risk_definition.get("display_name", modifier_id)), drop_bonus_percent]
		modifier_check_button.set_pressed_no_signal(_selected_risk_modifier_ids.has(modifier_id))
		modifier_check_button.toggled.connect(_on_risk_modifier_toggled.bind(modifier_id))
		_risk_offer_container.add_child(modifier_check_button)
		_risk_modifier_check_buttons[modifier_id] = modifier_check_button


func _refresh_validation_state() -> void:
	## 刷新风险提示与确认资格；未启用任何扩展时允许直接开始，风险合约启用时至少选择一项。
	# 风险合约是否启用；只有启用时词条必选规则参与确认资格。
	var risk_contract_enabled: bool = _selected_extension_ids.has(ModeExtensionRules.EXTENSION_RISK_CONTRACT)
	# 是否已选择风险词条；关闭风险合约时视为满足配置要求。
	var has_required_risk: bool = not risk_contract_enabled or not _selected_risk_modifier_ids.is_empty()
	if _confirm_button != null:
		_confirm_button.disabled = not has_required_risk
	if _risk_status_label == null:
		return
	if not has_required_risk:
		_risk_status_label.text = "请至少选择一项风险词条后再确认。"
		_risk_status_label.add_theme_color_override("font_color", RISK_WARNING_COLOR)
		return
	# 总掉落加成百分比；所有选中词条加算，最终统一乘到怪物四类掉落概率。
	var total_drop_bonus_percent: int = roundi(ModeExtensionRules.get_total_drop_bonus_ratio(_selected_risk_modifier_ids) * 100.0)
	_risk_status_label.text = "当前共选择 %d 项，怪物掉落总加成 +%d%%" % [_selected_risk_modifier_ids.size(), total_drop_bonus_percent]
	_risk_status_label.add_theme_color_override("font_color", RISK_REWARD_COLOR)


func _on_extension_toggled(button_pressed: bool, extension_id: String) -> void:
	## 更新模式扩展勾选状态；风险合约首次启用时立即刷新四个随机候选。
	if button_pressed:
		if not _selected_extension_ids.has(extension_id):
			_selected_extension_ids.append(extension_id)
		if extension_id == ModeExtensionRules.EXTENSION_RISK_CONTRACT:
			_generate_new_risk_offer()
			return
	else:
		_selected_extension_ids.erase(extension_id)
		if extension_id == ModeExtensionRules.EXTENSION_RISK_CONTRACT:
			_selected_risk_modifier_ids.clear()
	_rebuild_risk_offer()
	_refresh_validation_state()


func _on_risk_modifier_toggled(button_pressed: bool, modifier_id: String) -> void:
	## 更新单个风险词条选择；只接受当前四个候选，避免隐藏或陈旧控件写入配置。
	if not _risk_offer_ids.has(modifier_id):
		return
	if button_pressed:
		if not _selected_risk_modifier_ids.has(modifier_id):
			_selected_risk_modifier_ids.append(modifier_id)
	else:
		_selected_risk_modifier_ids.erase(modifier_id)
	_selected_risk_modifier_ids = ModeExtensionRules.normalize_risk_modifier_ids(_selected_risk_modifier_ids)
	_refresh_validation_state()


func _on_refresh_risk_offer_pressed() -> void:
	## 免费刷新全部风险候选；当前选中词条同时清空，玩家需要重新选择至少一项。
	_generate_new_risk_offer()


func _on_confirm_button_pressed() -> void:
	## 提交合法配置；未启用风险合约时允许两个数组都为空，启用时必须包含至少一项合法词条。
	# 标准配置；再次通过规则表校验，防止控件状态与模式兼容性在异步联机刷新中产生偏差。
	var sanitized_configuration: Dictionary = ModeExtensionRules.sanitize_configuration(_selected_extension_ids, _selected_risk_modifier_ids, _hack_variant)
	# 有效扩展列表；只有风险合约开启但词条为空时结果会被移除，此时拒绝提交并恢复校验提示。
	var extension_ids: Array[String] = _to_string_array(sanitized_configuration.get("extension_ids", []))
	# 有效风险词条列表；顺序由规则表统一规范化，网络各端得到一致汇总结果。
	var modifier_ids: Array[String] = _to_string_array(sanitized_configuration.get("risk_modifier_ids", []))
	if _selected_extension_ids.has(ModeExtensionRules.EXTENSION_RISK_CONTRACT) and not extension_ids.has(ModeExtensionRules.EXTENSION_RISK_CONTRACT):
		_refresh_validation_state()
		return
	configuration_confirmed.emit(extension_ids, modifier_ids)


func _on_close_button_pressed() -> void:
	closed.emit()


func _to_string_array(raw_values: Variant) -> Array[String]:
	## 把外部 Variant 数组安全转换为强类型字符串数组；非数组输入返回空列表。
	# 字符串结果；保持原顺序，具体合法性由规则表入口负责。
	var string_values: Array[String] = []
	if not (raw_values is Array):
		return string_values
	for raw_value in raw_values:
		string_values.append(str(raw_value))
	return string_values
