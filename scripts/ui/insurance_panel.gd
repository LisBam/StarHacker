extends PanelContainer

## 保险面板只负责展示保单状态、投保报价、账户统计与结算记录，不拥有任何保单或货币数据。
## 保费与赔付规则全部来自 InsuranceService 公开接口，确认后由服务原子校验并扣款。

signal closed

## 股市同款二次确认弹窗；投保在展示价值、费率与条款后统一等待再次确认。
const COMMON_CONFIRMATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/common_confirmation_dialog.gd")
## 全局窗口样式指南；为保险界面补充统一窗口、按钮与文字主题。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 面板固定尺寸；默认 880×600，保单卡、统计与记录列表在该尺寸下保留完整可读空间。
@export var panel_size: Vector2 = Vector2(880.0, 600.0)

## 保险服务缓存；默认读取 Autoload，所有报价、投保与记录快照都经由该服务完成。
var _service: Node
## 全局库存服务缓存；只读永久星穹余额，用于状态栏提示。
var _global_inventory: Node
## 记录列表重建是否已排队；默认 false，同帧多个服务信号合并为一次延迟重建。
var _records_rebuild_queued: bool = false

## 星穹余额文本；显示当前局外星穹，保费扣款与赔付到账后由库存信号即时刷新。
var _coins_label: Label
## 保单区容器；按当前保单状态在生效卡与投保卡之间切换重建。
var _policy_container: VBoxContainer
## 统计文本；显示累计保费、累计赔付、投保次数与安全撤离次数。
var _statistics_label: Label
## 记录列表容器；按时间倒序展示投保、理赔与结算记录。
var _records_container: VBoxContainer
## 二次确认弹窗；完整展示投保价值、保费与条款后才执行真实投保。
var _confirmation_dialog: CommonConfirmationDialog
## 信息提示弹窗；投保失败时展示服务返回原因，不修改任何数据。
var _message_dialog: CommonConfirmationDialog


func _ready() -> void:
	custom_minimum_size = panel_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	_service = get_tree().root.get_node_or_null("InsuranceService")
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	_connect_services()
	# UI 风格服务；保单卡片使用手动取色，监听切换信号后立即重建而不等待下次打开。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))
	_refresh_all()


func refresh() -> void:
	## 主菜单打开面板时调用；重新读取随身价值、保单与记录快照。
	visible = true
	_refresh_all()


func _connect_services() -> void:
	if _service != null:
		if _service.has_signal("policy_changed"):
			_service.connect("policy_changed", Callable(self, "_on_policy_changed"))
		if _service.has_signal("insurance_settled"):
			_service.connect("insurance_settled", Callable(self, "_on_insurance_settled"))
	if _global_inventory != null and _global_inventory.has_signal("coins_changed"):
		_global_inventory.connect("coins_changed", Callable(self, "_refresh_coins"))


func _build_interface() -> void:
	# 面板样式；统一取样式指南主窗口样式并自动登记，UI 风格切换时立即刷新背景与描边。
	UI_STYLE_GUIDE.apply_window_panel(self)
	# 外边距；为标题、保单卡与记录列表提供统一留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	# 主纵向布局；依次承载状态栏、保单区、统计行与记录列表。
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	# 顶部状态栏；左侧标题与余额，右侧关闭按钮。
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)
	# 标题与余额区；标题下方显示当前局外星穹。
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	# 面板标题；骇入保险是死亡损失对冲的唯一入口。
	var title_label: Label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	UI_STYLE_GUIDE.apply_title_label(title_label)
	title_label.text = "骇入保险"
	title_box.add_child(title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 14)
	UI_STYLE_GUIDE.apply_secondary_label(_coins_label)
	title_box.add_child(_coins_label)
	# 关闭按钮；保单结算完全由服务在战斗结束时自动执行，面板关闭不影响任何保障。
	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(90.0, 36.0)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.text = "关闭"
	close_button.pressed.connect(_close_panel)
	header.add_child(close_button)
	# 保单区容器；按保单状态动态重建生效卡或投保卡。
	_policy_container = VBoxContainer.new()
	_policy_container.add_theme_constant_override("separation", 8)
	root.add_child(_policy_container)
	# 统计行；四项账户统计使用单行次要文字展示。
	_statistics_label = Label.new()
	_statistics_label.add_theme_font_size_override("font_size", 13)
	UI_STYLE_GUIDE.apply_secondary_label(_statistics_label)
	root.add_child(_statistics_label)
	# 记录标题；与统计行区分开的记录列表小节。
	var records_title_label: Label = Label.new()
	records_title_label.add_theme_font_size_override("font_size", 15)
	UI_STYLE_GUIDE.apply_muted_accent_label(records_title_label)
	records_title_label.text = "投保与理赔记录"
	root.add_child(records_title_label)
	# 记录滚动区；按时间倒序展示最近 30 条投保、理赔与结算记录。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_records_container = VBoxContainer.new()
	_records_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_records_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_records_container)
	# 底部条款说明；固定展示保险的核心规则，帮助玩家理解赔付边界。
	var rule_label: Label = Label.new()
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_label.add_theme_font_size_override("font_size", 12)
	UI_STYLE_GUIDE.apply_secondary_label(rule_label)
	rule_label.text = "仅“角色死亡”按丢失价值 80% 赔付（不超过投保价值）  |  主动逃跑与退出不赔付  |  成功撤离计入安全记录"
	root.add_child(rule_label)
	# 二次确认弹窗；确认与取消分别路由到投保执行与直接关闭。
	_confirmation_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_confirmation_dialog.confirmed.connect(_confirm_purchase)
	add_child(_confirmation_dialog)
	# 信息提示弹窗；独立实例避免确认回调与提示确认互相覆盖。
	_message_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	add_child(_message_dialog)


func _refresh_all() -> void:
	_refresh_coins()
	_rebuild_policy_section()
	_refresh_statistics()
	_rebuild_records()


func _refresh_coins(_amount: int = 0) -> void:
	if _coins_label == null:
		return
	# 当前局外星穹；库存服务缺失时显示 0，避免面板因单例缺失报错。
	var coins: int = int(_global_inventory.call("get_coins")) if _global_inventory != null and _global_inventory.has_method("get_coins") else 0
	_coins_label.text = "当前星穹：%d" % coins


func _rebuild_policy_section() -> void:
	if _policy_container == null or _service == null:
		return
	for child in _policy_container.get_children():
		child.queue_free()
	# 当前保单快照；非空表示已有生效保单，展示保障内容并隐藏投保入口。
	var policy: Dictionary = _service.call("get_policy_snapshot") as Dictionary if _service.has_method("get_policy_snapshot") else {}
	if not policy.is_empty():
		_policy_container.add_child(_create_active_policy_card(policy))
		return
	_policy_container.add_child(_create_quote_card())


func _create_active_policy_card(policy: Dictionary) -> Control:
	# 生效保单卡片；使用亮色语义突出保障进行中。
	var card: PanelContainer = _create_card_base(true)
	var content: VBoxContainer = _get_card_content(card)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color())
	name_label.text = "保单生效中：覆盖下一局正式骇入"
	content.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	detail_label.text = "投保价值：%d 星穹  |  已付保费：%d 星穹  |  赔付比例：%d%%" % [int(policy.get("insured_value", 0)), int(policy.get("premium_paid", 0)), int(round(float(policy.get("claim_ratio", 0.8)) * 100.0))]
	content.add_child(detail_label)
	var note_label: Label = Label.new()
	note_label.add_theme_font_size_override("font_size", 11)
	note_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	note_label.text = "保单在下一局正式骇入结算时自动消耗，期间不可退保"
	content.add_child(note_label)
	return card


func _create_quote_card() -> Control:
	# 投保报价卡片；实时展示随身价值、费率与保费，投保按钮进入二次确认。
	var card: PanelContainer = _create_card_base(false)
	var content: VBoxContainer = _get_card_content(card)
	# 当前投保报价；打开与重建时读取，确认瞬间服务会重新计算。
	var quote: Dictionary = _service.call("get_premium_quote") as Dictionary if _service != null and _service.has_method("get_premium_quote") else {}
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color())
	name_label.text = "为下一局骇入投保"
	content.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	detail_label.text = "当前随身价值：%d 星穹  |  费率：%.1f%%  |  保费：%d 星穹" % [int(quote.get("carried_value", 0)), float(quote.get("premium_rate", 0.12)) * 100.0, int(quote.get("premium", 0))]
	content.add_child(detail_label)
	var note_label: Label = Label.new()
	note_label.add_theme_font_size_override("font_size", 11)
	note_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	note_label.text = "投保基准为背包与装备的当前总价值；据点精算办公室可降低费率"
	content.add_child(note_label)
	# 投保按钮；没有随身物品时禁用并提示原因。
	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(0.0, 34.0)
	if int(quote.get("carried_value", 0)) <= 0:
		action_button.text = "当前没有可投保的随身物品"
		action_button.disabled = true
	else:
		action_button.text = "投保（保费 %d 星穹）" % int(quote.get("premium", 0))
		UI_STYLE_GUIDE.apply_primary_button(action_button)
		action_button.pressed.connect(_open_purchase_confirmation)
	content.add_child(action_button)
	return card


func _create_card_base(active: bool) -> PanelContainer:
	## 创建保单区通用卡片外框；亮暗语义与矿场、据点卡片保持一致。
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	# 卡片背景与边框；生效保单使用亮色语义，投保报价使用普通分区语义。
	style.bg_color = UI_STYLE_GUIDE.get_section_background_color()
	style.border_color = UI_STYLE_GUIDE.get_accent_muted_color() if active else Color(UI_STYLE_GUIDE.get_section_border_color(), 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "CardContent"
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	return card


func _get_card_content(card: PanelContainer) -> VBoxContainer:
	## 读取通用卡片外框的内容容器；与 _create_card_base 配套使用。
	return card.get_node("CardMargin/CardContent") as VBoxContainer


func _refresh_statistics() -> void:
	if _statistics_label == null or _service == null or not _service.has_method("get_account_statistics"):
		return
	# 账户统计快照；四项累计值均为只增整数。
	var statistics: Dictionary = _service.call("get_account_statistics") as Dictionary
	_statistics_label.text = "累计保费：%d 星穹  |  累计赔付：%d 星穹  |  投保次数：%d  |  投保安全撤离：%d 次" % [int(statistics.get("total_premium", 0)), int(statistics.get("total_claims", 0)), int(statistics.get("total_policies", 0)), int(statistics.get("total_safe_extractions", 0))]


func _rebuild_records() -> void:
	# 任何直接重建都消化当前挂起的合并刷新；同帧稍后的延迟回调据此跳过重复重建。
	_records_rebuild_queued = false
	if _records_container == null or _service == null or not _service.has_method("get_claim_records"):
		return
	for child in _records_container.get_children():
		child.queue_free()
	# 记录副本；索引 0 为最新记录，按服务顺序从上到下展示。
	var records: Array = _service.call("get_claim_records") as Array
	if records.is_empty():
		# 空记录占位；使用禁用文字色保持列表高度稳定。
		var empty_label: Label = Label.new()
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_disabled_text_color())
		empty_label.text = "暂无投保与理赔记录"
		_records_container.add_child(empty_label)
		return
	for raw_record in records:
		if not (raw_record is Dictionary):
			continue
		# 单条记录字典；包含时间文本与说明文本。
		var record: Dictionary = raw_record as Dictionary
		var record_label: Label = Label.new()
		record_label.add_theme_font_size_override("font_size", 12)
		record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		record_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
		record_label.text = "[%s] %s" % [str(record.get("time_text", "--")), str(record.get("message", ""))]
		_records_container.add_child(record_label)


func _open_purchase_confirmation() -> void:
	if _service == null or not _service.has_method("get_premium_quote"):
		return
	# 投保实时报价；确认正文展示价值、费率、保费与条款摘要。
	var quote: Dictionary = _service.call("get_premium_quote") as Dictionary
	var message: String = "投保价值：%d 星穹\n费率：%.1f%%  保费：%d 星穹\n死亡时按丢失价值 %d%% 赔付（不超过投保价值）\n主动逃跑与退出不赔付，保单一局后消耗" % [int(quote.get("carried_value", 0)), float(quote.get("premium_rate", 0.12)) * 100.0, int(quote.get("premium", 0)), int(round(float(quote.get("claim_ratio", 0.8)) * 100.0))]
	_confirmation_dialog.present_adaptive("确认投保", message, "确认投保", "取消", true)


func _confirm_purchase() -> void:
	if _service == null or not _service.has_method("purchase_policy"):
		return
	# 投保执行结果；服务在确认瞬间重新计算随身价值并复核星穹余额。
	var result: Dictionary = _service.call("purchase_policy") as Dictionary
	if not bool(result.get("success", false)):
		_message_dialog.present_information("保险提示", str(result.get("message", "投保失败")))
	_refresh_all()


func _on_policy_changed() -> void:
	_rebuild_policy_section()
	_refresh_statistics()
	_queue_records_rebuild()


func _on_insurance_settled(_result_type: String, _message: String) -> void:
	_queue_records_rebuild()
	_refresh_statistics()


func _queue_records_rebuild() -> void:
	## 合并记录列表重建；同帧内保单与结算信号多次触发只执行一次重建。
	if _records_rebuild_queued:
		return
	_records_rebuild_queued = true
	call_deferred("_flush_queued_records_rebuild")


func _flush_queued_records_rebuild() -> void:
	## 执行单次记录列表重建；期间若已发生直接重建，标志会被消化并跳过重复工作。
	if not _records_rebuild_queued:
		return
	_rebuild_records()


func _on_ui_style_changed(_style_id: String) -> void:
	## UI 风格切换后立即重建保单卡与记录列表，刷新其中手动取色的背景、边框与文字。
	_rebuild_policy_section()
	_rebuild_records()


func _close_panel() -> void:
	visible = false
	closed.emit()
