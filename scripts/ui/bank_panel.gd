extends PanelContainer

## 银行面板只负责展示活期账户、定期存单、贷款状态并收集整数金额输入，不拥有任何货币数据。
## 利率、授信与扣款规则全部来自 BankService 公开接口，确认后由服务原子校验并执行。

signal closed

## 股市与矿场共用的滑条数量弹窗；银行金额选择复用其通用整数模式，不维护独立数量控件。
const SELL_QUANTITY_DIALOG_SCRIPT: Script = preload("res://scripts/ui/sell_quantity_dialog.gd")
## 股市同款二次确认弹窗；银行操作在金额选择后统一展示最终结果并等待再次确认。
const COMMON_CONFIRMATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/common_confirmation_dialog.gd")
## 全局窗口样式指南；为银行界面补充统一窗口、按钮与文字主题。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 活期页标识；展示活期余额、利息进度与存取入口。
const TAB_DEMAND: String = "demand"
## 定期页标识；展示进行中存单与三档可签订存单。
const TAB_FIXED: String = "fixed"
## 贷款页标识；展示进行中贷款、授信上限与申请入口。
const TAB_LOAN: String = "loan"
## 存入操作标识；数量弹窗输入整数星穹并存入活期账户。
const ACTION_DEPOSIT: String = "deposit"
## 取出操作标识；数量弹窗输入整数星穹并从活期账户取回。
const ACTION_WITHDRAW: String = "withdraw"
## 定期签订操作标识；数量弹窗输入本金并按锁定利率签订存单。
const ACTION_FIXED: String = "fixed"
## 贷款申请操作标识；数量弹窗输入本金并按授信上限放款。
const ACTION_LOAN: String = "loan"
## 贷款还款操作标识；跳过数量弹窗直接进入二次确认并全额还清。
const ACTION_REPAY: String = "repay"
## 倒计时轮询间隔；默认 0.25 秒，配合文本变化守卫刷新利息进度与各类倒计时。
const STATUS_POLL_INTERVAL_SECONDS: float = 0.25

## 面板固定尺寸；默认 1080×640，与矿场面板一致，适配 1280×720 主菜单并保留四周遮罩空间。
@export var panel_size: Vector2 = Vector2(1080.0, 640.0)

## 银行服务缓存；默认读取 Autoload，所有账户操作与快照都经由该服务完成。
var _service: Node
## 全局库存服务缓存；只读永久星穹余额，用于状态栏提示与金额上限。
var _global_inventory: Node
## 当前标签页；默认活期页，切换后只重建中部卡片区。
var _active_tab: String = TAB_DEMAND
## 当前数量弹窗操作类型；确认时路由到对应服务接口。
var _dialog_action: String = ""
## 当前数量弹窗附加参数；定期签订时保存存单类型标识，其他操作保持空字符串。
var _dialog_argument: String = ""
## 等待二次确认的金额；默认 0，数量弹窗确认后保存到最终交易完成或取消。
var _pending_amount: int = 0
## 倒计时轮询累计秒数；默认 0，达到轮询间隔后刷新状态文字。
var _status_poll_accumulator: float = 0.0
## 上次状态栏文本；默认空字符串，轮询刷新时文本未变化则跳过标签重写。
var _last_status_text: String = ""
## 上次卡片区倒计时文本；默认空字符串，轮询刷新时文本未变化则跳过标签重写。
var _last_countdown_text: String = ""
## 卡片重建是否已排队；默认 false，同帧多个服务信号合并为一次延迟重建。
var _cards_rebuild_queued: bool = false

## 星穹余额文本；显示当前局外星穹与活期余额，账户变化后由服务信号即时刷新。
var _coins_label: Label
## 状态栏文本；显示计息进度与下次利息预览，由轮询按固定间隔刷新。
var _status_label: Label
## 活期页按钮；切换模式并同步按下状态。
var _demand_tab_button: Button
## 定期页按钮；切换模式并同步按下状态。
var _fixed_tab_button: Button
## 贷款页按钮；切换模式并同步按下状态。
var _loan_tab_button: Button
## 卡片流式容器；三个标签页共用同一容器并整体重建。
var _card_container: HFlowContainer
## 卡片区倒计时标签；进行中存单或贷款卡片内的剩余时间文本，页面重建时重新捕获引用。
var _countdown_label: Label
## 数量操作弹窗；存入、取出、定期与贷款共用同一紧凑组件。
var _quantity_dialog: SellQuantityDialog
## 二次确认弹窗；完整展示操作、金额与利率后才执行真实交易。
var _confirmation_dialog: CommonConfirmationDialog
## 信息提示弹窗；交易失败时展示服务返回原因，不修改任何数据。
var _message_dialog: CommonConfirmationDialog


func _ready() -> void:
	custom_minimum_size = panel_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	_service = get_tree().root.get_node_or_null("BankService")
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	_connect_services()
	# UI 风格服务；银行卡片使用手动取色，监听切换信号后立即重建而不等待下次打开。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))
	set_process(false)
	_refresh_all()


func _process(delta: float) -> void:
	# 倒计时轮询；状态栏与卡片倒计时按固定间隔拉取服务快照，文本未变化时不产生任何控件写入。
	_status_poll_accumulator += maxf(delta, 0.0)
	if _status_poll_accumulator >= STATUS_POLL_INTERVAL_SECONDS:
		_status_poll_accumulator = 0.0
		_refresh_status_bar()
		_refresh_card_countdown()


func refresh() -> void:
	## 主菜单打开面板时调用；重新读取服务快照并恢复倒计时轮询。
	visible = true
	set_process(true)
	_refresh_all()


func _connect_services() -> void:
	if _service != null:
		if _service.has_signal("account_changed"):
			_service.connect("account_changed", Callable(self, "_on_account_changed"))
		if _service.has_signal("fixed_deposit_changed"):
			_service.connect("fixed_deposit_changed", Callable(self, "_queue_cards_rebuild"))
		if _service.has_signal("loan_changed"):
			_service.connect("loan_changed", Callable(self, "_queue_cards_rebuild"))
	if _global_inventory != null and _global_inventory.has_signal("coins_changed"):
		_global_inventory.connect("coins_changed", Callable(self, "_refresh_coins"))


func _build_interface() -> void:
	# 面板样式；统一取样式指南主窗口样式并自动登记，UI 风格切换时立即刷新背景与描边。
	UI_STYLE_GUIDE.apply_window_panel(self)
	# 外边距；为标题、标签页与卡片区提供统一留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	# 主纵向布局；依次承载状态栏、标签页、卡片区与底部规则说明。
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	# 顶部状态栏；左侧标题与余额，右侧计息状态与关闭按钮。
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)
	# 标题与余额区；标题下方显示局外星穹与活期余额。
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	# 面板标题；星海银行是保本理财与信用贷款的唯一入口。
	var title_label: Label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	UI_STYLE_GUIDE.apply_title_label(title_label)
	title_label.text = "星海银行"
	title_box.add_child(title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 14)
	UI_STYLE_GUIDE.apply_secondary_label(_coins_label)
	title_box.add_child(_coins_label)
	# 计息状态区；右对齐显示计息进度与下次利息预览。
	var status_box: VBoxContainer = VBoxContainer.new()
	status_box.custom_minimum_size = Vector2(360.0, 0.0)
	header.add_child(status_box)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.46, 0.92, 0.72, 1.0))
	status_box.add_child(_status_label)
	# 大盘利率提示；定期利率随牛熊市变化，帮助玩家择时签订。
	var market_label: Label = Label.new()
	market_label.name = "MarketRateLabel"
	market_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	market_label.add_theme_font_size_override("font_size", 11)
	UI_STYLE_GUIDE.apply_secondary_label(market_label)
	status_box.add_child(market_label)
	# 关闭按钮；关闭后 UI 停止轮询，计息与倒计时继续由服务后台推进。
	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(90.0, 36.0)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.text = "关闭"
	close_button.pressed.connect(_close_panel)
	header.add_child(close_button)
	# 标签栏；按钮使用切换模式，任何时刻只保持当前页面按下。
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	_demand_tab_button = Button.new()
	_demand_tab_button.text = "活期账户"
	_demand_tab_button.toggle_mode = true
	_demand_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demand_tab_button.pressed.connect(Callable(self, "_switch_tab").bind(TAB_DEMAND))
	tabs.add_child(_demand_tab_button)
	_fixed_tab_button = Button.new()
	_fixed_tab_button.text = "定期存单"
	_fixed_tab_button.toggle_mode = true
	_fixed_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fixed_tab_button.pressed.connect(Callable(self, "_switch_tab").bind(TAB_FIXED))
	tabs.add_child(_fixed_tab_button)
	_loan_tab_button = Button.new()
	_loan_tab_button.text = "信用贷款"
	_loan_tab_button.toggle_mode = true
	_loan_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loan_tab_button.pressed.connect(Callable(self, "_switch_tab").bind(TAB_LOAN))
	tabs.add_child(_loan_tab_button)
	# 卡片滚动区；三个标签页共用流式容器并整体重建。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_card_container = HFlowContainer.new()
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_container.add_theme_constant_override("h_separation", 12)
	_card_container.add_theme_constant_override("v_separation", 12)
	_card_container.alignment = FlowContainer.ALIGNMENT_CENTER
	scroll.add_child(_card_container)
	# 底部规则说明；固定展示银行的核心规则摘要。
	var rule_label: Label = Label.new()
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_label.add_theme_font_size_override("font_size", 12)
	UI_STYLE_GUIDE.apply_secondary_label(rule_label)
	rule_label.text = "活期每在线小时 0.2% 利息  |  定期利率随大盘与金库浮动、签订时锁定  |  贷款利率 15%、2 小时后自动从星穹→活期→算力币→证券币级联扣款"
	root.add_child(rule_label)
	# 数量弹窗；银行四类金额输入共用同一通用整数模式。
	_quantity_dialog = SELL_QUANTITY_DIALOG_SCRIPT.new() as SellQuantityDialog
	_quantity_dialog.connect("quantity_confirmed", Callable(self, "_on_quantity_confirmed"))
	add_child(_quantity_dialog)
	# 二次确认弹窗；确认与取消分别路由到交易执行与挂起清理。
	_confirmation_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_confirmation_dialog.confirmed.connect(_confirm_pending_action)
	_confirmation_dialog.canceled.connect(_clear_pending_action)
	add_child(_confirmation_dialog)
	# 信息提示弹窗；独立实例避免确认回调与提示确认互相覆盖。
	_message_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	add_child(_message_dialog)


func _refresh_all() -> void:
	_refresh_coins()
	_refresh_status_bar()
	_refresh_tabs()
	_rebuild_cards()


func _refresh_coins(_amount: int = 0) -> void:
	if _coins_label == null:
		return
	# 当前局外星穹；库存服务缺失时显示 0，避免面板因单例缺失报错。
	var coins: int = int(_global_inventory.call("get_coins")) if _global_inventory != null and _global_inventory.has_method("get_coins") else 0
	# 当前活期余额；银行服务缺失时显示 0。
	var account_balance: int = int(_service.call("get_account_balance")) if _service != null and _service.has_method("get_account_balance") else 0
	_coins_label.text = "当前星穹：%d  |  活期余额：%d" % [coins, account_balance]


func _refresh_status_bar() -> void:
	if _status_label == null or _service == null:
		return
	# 计息进度；按当前周期百分比与下次利息预览生成状态文本。
	var progress_ratio: float = float(_service.call("get_interest_progress_ratio")) if _service.has_method("get_interest_progress_ratio") else 0.0
	var interest_preview: int = int(_service.call("get_demand_interest_preview")) if _service.has_method("get_demand_interest_preview") else 0
	# 目标状态文本；未变化时跳过标签重写。
	var status_text: String = "本小时计息进度 %d%%  下次利息 +%d" % [int(round(progress_ratio * 100.0)), interest_preview]
	if status_text != _last_status_text:
		_last_status_text = status_text
		_status_label.text = status_text
	# 大盘利率提示标签；由状态区固定节点名读取。
	var market_label: Label = _status_label.get_parent().get_node_or_null("MarketRateLabel") as Label
	if market_label != null and _service.has_method("get_market_state_description"):
		market_label.text = str(_service.call("get_market_state_description"))


func _refresh_tabs() -> void:
	_demand_tab_button.set_pressed_no_signal(_active_tab == TAB_DEMAND)
	_fixed_tab_button.set_pressed_no_signal(_active_tab == TAB_FIXED)
	_loan_tab_button.set_pressed_no_signal(_active_tab == TAB_LOAN)


func _switch_tab(tab_id: String) -> void:
	if _active_tab == tab_id:
		_refresh_tabs()
		return
	_active_tab = tab_id
	_refresh_tabs()
	_rebuild_cards()


func _rebuild_cards() -> void:
	# 任何直接重建都消化当前挂起的合并刷新；同帧稍后的延迟回调据此跳过重复重建。
	_cards_rebuild_queued = false
	if _card_container == null or _service == null:
		return
	# 倒计时引用清理；旧标签随子节点释放，避免轮询刷新访问已销毁控件。
	_countdown_label = null
	_last_countdown_text = ""
	for child in _card_container.get_children():
		child.queue_free()
	if _active_tab == TAB_DEMAND:
		_card_container.add_child(_create_demand_card())
	elif _active_tab == TAB_FIXED:
		_rebuild_fixed_cards()
	else:
		_rebuild_loan_cards()


func _create_demand_card() -> Control:
	# 活期账户卡片；展示余额、利率说明与存取入口。
	var card: PanelContainer = _create_card_base(true, Vector2(420.0, 190.0))
	var content: VBoxContainer = _get_card_content(card)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color())
	name_label.text = "活期账户"
	content.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	detail_label.text = "余额：%d 星穹\n每满 1 在线小时按当时余额结算 0.2%% 利息（向下取整）" % int(_service.call("get_account_balance"))
	content.add_child(detail_label)
	var note_label: Label = Label.new()
	note_label.add_theme_font_size_override("font_size", 11)
	note_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	note_label.text = "存取均无手续费；活期余额同时计入贷款授信与违约抵扣顺序"
	content.add_child(note_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	# 存取按钮行；存入与取出并排等宽。
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	content.add_child(action_row)
	var deposit_button: Button = Button.new()
	deposit_button.custom_minimum_size = Vector2(0.0, 32.0)
	deposit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deposit_button.text = "存入"
	UI_STYLE_GUIDE.apply_primary_button(deposit_button)
	deposit_button.pressed.connect(Callable(self, "_open_amount_dialog").bind(ACTION_DEPOSIT, ""))
	action_row.add_child(deposit_button)
	var withdraw_button: Button = Button.new()
	withdraw_button.custom_minimum_size = Vector2(0.0, 32.0)
	withdraw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	withdraw_button.text = "取出"
	withdraw_button.pressed.connect(Callable(self, "_open_amount_dialog").bind(ACTION_WITHDRAW, ""))
	action_row.add_child(withdraw_button)
	return card


func _rebuild_fixed_cards() -> void:
	## 重建定期存单页；进行中存单卡片置于首位，随后按定义顺序展示三档存单。
	# 进行中存单快照；为空表示当前没有存单，可签订卡片据此决定按钮可用状态。
	var active_snapshot: Dictionary = _service.call("get_active_fixed_deposit_snapshot") as Dictionary if _service.has_method("get_active_fixed_deposit_snapshot") else {}
	if not active_snapshot.is_empty():
		_card_container.add_child(_create_active_fixed_card(active_snapshot))
	# 冻结状态；违约冻结期间同样禁用签订入口。
	var frozen: bool = _service.has_method("is_default_frozen") and bool(_service.call("is_default_frozen"))
	# 存单定义副本；卡片只读取快照，签订时服务仍会再次校验余额与占用。
	var definitions: Array = _service.call("get_fixed_deposit_definitions") as Array if _service.has_method("get_fixed_deposit_definitions") else []
	for raw_definition in definitions:
		# 单档存单定义；包含稳定标识、名称、在线时长、基础利率与说明。
		var definition: Dictionary = raw_definition as Dictionary
		_card_container.add_child(_create_fixed_definition_card(definition, not active_snapshot.is_empty() or frozen))


func _create_active_fixed_card(snapshot: Dictionary) -> Control:
	# 进行中存单卡片；使用亮色语义突出兑付倒计时。
	var card: PanelContainer = _create_card_base(true, Vector2(318.0, 158.0))
	var content: VBoxContainer = _get_card_content(card)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color())
	name_label.text = "进行中：%s" % str(snapshot.get("name", "定期存单"))
	content.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	detail_label.text = "本金 %d  |  锁定利率 %.2f%%\n到期本息 %d 星穹" % [int(snapshot.get("principal", 0)), float(snapshot.get("locked_rate", 0.0)) * 100.0, int(snapshot.get("payout", 0))]
	content.add_child(detail_label)
	# 倒计时标签；文本由轮询按剩余整数秒刷新，绿色与收益语义保持一致。
	_countdown_label = Label.new()
	_countdown_label.add_theme_font_size_override("font_size", 14)
	_countdown_label.add_theme_color_override("font_color", Color(0.46, 0.92, 0.72, 1.0))
	content.add_child(_countdown_label)
	_refresh_card_countdown()
	var note_label: Label = Label.new()
	note_label.add_theme_font_size_override("font_size", 11)
	note_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	note_label.text = "存单仅消耗在线时间，中途不可支取"
	content.add_child(note_label)
	return card


func _create_fixed_definition_card(definition: Dictionary, entry_disabled: bool) -> Control:
	# 可签订存单卡片；展示时长、基础利率与当前报价利率。
	var card: PanelContainer = _create_card_base(not entry_disabled, Vector2(318.0, 158.0))
	var content: VBoxContainer = _get_card_content(card)
	var deposit_id: String = str(definition.get("id", ""))
	# 卡片文字色；占用或冻结时降低语义亮度。
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color() if not entry_disabled else UI_STYLE_GUIDE.get_disabled_text_color())
	name_label.text = str(definition.get("name", "定期存单"))
	content.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	# 当前报价利率；含大盘与金库倍率，签订瞬间重新读取并锁定。
	detail_label.text = "在线 %s  |  基础 %.1f%%\n当前报价利率 %.2f%%" % [_format_hour_minute_duration(int(definition.get("duration_seconds", 0))), float(definition.get("base_rate", 0.0)) * 100.0, float(_service.call("get_quoted_fixed_rate", deposit_id)) * 100.0]
	content.add_child(detail_label)
	var description_label: Label = Label.new()
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	description_label.text = str(definition.get("description", ""))
	content.add_child(description_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(0.0, 32.0)
	if entry_disabled:
		action_button.text = "已有进行中存单或信用冻结"
		action_button.disabled = true
	else:
		action_button.text = "签订存单"
		UI_STYLE_GUIDE.apply_primary_button(action_button)
		action_button.pressed.connect(Callable(self, "_open_amount_dialog").bind(ACTION_FIXED, deposit_id))
	content.add_child(action_button)
	return card


func _rebuild_loan_cards() -> void:
	## 重建贷款页；进行中贷款展示还款入口，无贷款时展示授信与申请卡片。
	# 进行中贷款快照；为空表示当前没有贷款。
	var loan_snapshot: Dictionary = _service.call("get_loan_snapshot") as Dictionary if _service.has_method("get_loan_snapshot") else {}
	if not loan_snapshot.is_empty():
		_card_container.add_child(_create_active_loan_card(loan_snapshot))
		return
	_card_container.add_child(_create_loan_application_card())


func _create_active_loan_card(snapshot: Dictionary) -> Control:
	# 进行中贷款卡片；使用危险语义强调应还金额与自动扣款风险。
	var card: PanelContainer = _create_card_base(true, Vector2(420.0, 190.0))
	var content: VBoxContainer = _get_card_content(card)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.50, 1.0))
	name_label.text = "进行中贷款"
	content.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	detail_label.text = "本金 %d 星穹  |  应还 %d 星穹" % [int(snapshot.get("principal", 0)), int(snapshot.get("repay_amount", 0))]
	content.add_child(detail_label)
	# 倒计时标签；文本由轮询按剩余整数秒刷新。
	_countdown_label = Label.new()
	_countdown_label.add_theme_font_size_override("font_size", 14)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.40, 1.0))
	content.add_child(_countdown_label)
	_refresh_card_countdown()
	var note_label: Label = Label.new()
	note_label.add_theme_font_size_override("font_size", 11)
	note_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	note_label.text = "到期自动按 星穹→活期→算力币→证券币 顺序扣款；仍不足将信用违约并冻结银行信贷 6 小时"
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	# 还款按钮；从局外星穹一次性全额还清。
	var repay_button: Button = Button.new()
	repay_button.custom_minimum_size = Vector2(0.0, 32.0)
	repay_button.text = "立即还清（%d 星穹）" % int(snapshot.get("repay_amount", 0))
	UI_STYLE_GUIDE.apply_primary_button(repay_button)
	repay_button.pressed.connect(_open_repay_confirmation)
	content.add_child(repay_button)
	return card


func _create_loan_application_card() -> Control:
	# 贷款申请卡片；展示授信上限、利率与期限，冻结期间禁用并显示倒计时。
	var frozen: bool = _service.has_method("is_default_frozen") and bool(_service.call("is_default_frozen"))
	var card: PanelContainer = _create_card_base(not frozen, Vector2(420.0, 190.0))
	var content: VBoxContainer = _get_card_content(card)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color() if not frozen else UI_STYLE_GUIDE.get_disabled_text_color())
	name_label.text = "申请信用贷款"
	content.add_child(name_label)
	# 当前授信上限；按总资产估值的 50% 实时计算。
	var maximum_amount: int = int(_service.call("get_maximum_loan_amount")) if _service.has_method("get_maximum_loan_amount") else 0
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	detail_label.text = "总资产估值：%d 星穹\n授信上限：%d 星穹（总资产 50%%）  |  利率 15%%  |  期限 2 在线小时" % [int(_service.call("get_total_asset_estimate")) if _service.has_method("get_total_asset_estimate") else 0, maximum_amount]
	content.add_child(detail_label)
	# 冻结倒计时标签；冻结期间由轮询刷新剩余时间。
	if frozen:
		_countdown_label = Label.new()
		_countdown_label.add_theme_font_size_override("font_size", 14)
		_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.50, 1.0))
		content.add_child(_countdown_label)
		_refresh_card_countdown()
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(0.0, 32.0)
	if frozen:
		action_button.text = "信用违约冻结中"
		action_button.disabled = true
	elif maximum_amount <= 0:
		action_button.text = "当前没有可用授信额度"
		action_button.disabled = true
	else:
		action_button.text = "申请贷款"
		UI_STYLE_GUIDE.apply_primary_button(action_button)
		action_button.pressed.connect(Callable(self, "_open_amount_dialog").bind(ACTION_LOAN, ""))
	content.add_child(action_button)
	return card


func _create_card_base(active: bool, minimum_size: Vector2) -> PanelContainer:
	## 创建银行通用卡片外框；亮暗语义与矿场、据点卡片保持一致。
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = minimum_size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	# 卡片背景与边框；激活时取当前风格子分区色与弱强调描边，禁用时降低透明度。
	style.bg_color = UI_STYLE_GUIDE.get_section_background_color() if active else Color(UI_STYLE_GUIDE.get_item_card_background_color(), 0.62)
	style.border_color = UI_STYLE_GUIDE.get_accent_muted_color() if active else Color(UI_STYLE_GUIDE.get_section_border_color(), 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "CardContent"
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	return card


func _get_card_content(card: PanelContainer) -> VBoxContainer:
	## 读取通用卡片外框的内容容器；与 _create_card_base 配套使用。
	return card.get_node("CardMargin/CardContent") as VBoxContainer


func _refresh_card_countdown() -> void:
	## 按当前页面刷新卡片内倒计时标签；标签只在存单、贷款或冻结卡片中存在。
	if _countdown_label == null or not is_instance_valid(_countdown_label) or _service == null:
		return
	# 目标倒计时文本；按当前页面读取对应快照生成，未变化时跳过标签重写。
	var countdown_text: String = ""
	if _active_tab == TAB_FIXED:
		# 存单快照；页面重建保证标签只在存单存在时被捕获。
		var deposit_snapshot: Dictionary = _service.call("get_active_fixed_deposit_snapshot") as Dictionary
		if not deposit_snapshot.is_empty():
			countdown_text = "剩余在线 %s" % _format_duration(float(deposit_snapshot.get("remaining_seconds", 0.0)))
	elif _active_tab == TAB_LOAN:
		# 贷款快照；无贷款时读取冻结剩余时间。
		var loan_snapshot: Dictionary = _service.call("get_loan_snapshot") as Dictionary
		if not loan_snapshot.is_empty():
			countdown_text = "距自动扣款 %s" % _format_duration(float(loan_snapshot.get("remaining_seconds", 0.0)))
		elif _service.has_method("get_default_freeze_remaining_seconds"):
			countdown_text = "冻结剩余 %s" % _format_duration(float(_service.call("get_default_freeze_remaining_seconds")))
	if countdown_text.is_empty() or countdown_text == _last_countdown_text:
		return
	_last_countdown_text = countdown_text
	_countdown_label.text = countdown_text


func _open_amount_dialog(action: String, argument: String) -> void:
	_dialog_action = action
	_dialog_argument = argument
	_pending_amount = 0
	# 当前局外星穹；存入、定期与贷款金额上限的共同输入。
	var coins: int = int(_global_inventory.call("get_coins")) if _global_inventory != null and _global_inventory.has_method("get_coins") else 0
	if action == ACTION_DEPOSIT:
		if coins <= 0:
			_show_message("星穹不足，无法存入")
			_clear_pending_action()
			return
		_quantity_dialog.present_developer_value("存入活期", "选择存入活期账户的星穹数量", 1, coins, mini(coins, 100), "下一步")
	elif action == ACTION_WITHDRAW:
		# 当前活期余额；取出上限为全部余额。
		var account_balance: int = int(_service.call("get_account_balance"))
		if account_balance <= 0:
			_show_message("活期余额为 0，没有可取出的星穹")
			_clear_pending_action()
			return
		_quantity_dialog.present_developer_value("取出活期", "选择取回局外余额的星穹数量", 1, account_balance, account_balance, "下一步")
	elif action == ACTION_FIXED:
		if _service.has_method("has_active_fixed_deposit") and bool(_service.call("has_active_fixed_deposit")):
			_show_message("已有进行中的定期存单")
			_clear_pending_action()
			return
		if coins <= 0:
			_show_message("星穹不足，无法签订存单")
			_clear_pending_action()
			return
		# 存单定义；标题展示存单名称，利率在二次确认时按锁定值展示。
		var definition: Dictionary = _get_fixed_deposit_definition(argument)
		_quantity_dialog.present_developer_value(str(definition.get("name", "定期存单")), "选择锁定的本金星穹数量", 1, coins, mini(coins, 100), "下一步")
	elif action == ACTION_LOAN:
		# 当前授信上限；服务在放款时会再次复核。
		var maximum_amount: int = int(_service.call("get_maximum_loan_amount"))
		if maximum_amount <= 0:
			_show_message("当前没有可用授信额度")
			_clear_pending_action()
			return
		_quantity_dialog.present_developer_value("申请贷款", "选择贷款本金（应还为本金 ×1.15 向上取整）", 1, maximum_amount, maximum_amount, "下一步")


func _on_quantity_confirmed(quantity: int) -> void:
	_pending_amount = maxi(quantity, 1)
	# 二次确认内容；完整列出金额与服务公式计算的最终结果。
	var message: String = _build_confirmation_message()
	var action_name: String = _get_action_display_name()
	_confirmation_dialog.present_adaptive("确认%s" % action_name, message, "确认%s" % action_name, "取消", true)


func _open_repay_confirmation() -> void:
	_dialog_action = ACTION_REPAY
	_dialog_argument = ""
	_pending_amount = 1
	# 贷款快照；确认正文展示应还金额与当前星穹。
	var snapshot: Dictionary = _service.call("get_loan_snapshot") as Dictionary
	var coins: int = int(_global_inventory.call("get_coins")) if _global_inventory != null and _global_inventory.has_method("get_coins") else 0
	_confirmation_dialog.present_adaptive("确认还款", "一次性还清贷款\n应还：%d 星穹\n当前星穹：%d" % [int(snapshot.get("repay_amount", 0)), coins], "确认还款", "取消", true)


func _build_confirmation_message() -> String:
	## 构建二次确认正文；金额使用银行服务公开公式，确认后服务仍会最终复核。
	var amount: int = maxi(_pending_amount, 1)
	if _dialog_action == ACTION_DEPOSIT:
		return "存入活期：%d 星穹\n存入后活期余额：%d 星穹\n每满 1 在线小时按余额结算 0.2%% 利息" % [amount, int(_service.call("get_account_balance")) + amount]
	if _dialog_action == ACTION_WITHDRAW:
		return "取出活期：%d 星穹\n取出后活期余额：%d 星穹\n取出无手续费" % [amount, int(_service.call("get_account_balance")) - amount]
	if _dialog_action == ACTION_FIXED:
		# 存单定义与锁定利率；签订时服务按同一公式重新计算。
		var definition: Dictionary = _get_fixed_deposit_definition(_dialog_argument)
		var quoted_rate: float = float(_service.call("get_quoted_fixed_rate", _dialog_argument))
		return "%s\n本金：%d 星穹  锁定利率：%.2f%%\n到期本息：%d 星穹\n在线 %s 后自动兑付，中途不可支取" % [str(definition.get("name", "定期存单")), amount, quoted_rate * 100.0, amount + int(floor(float(amount) * quoted_rate)), _format_hour_minute_duration(int(definition.get("duration_seconds", 0)))]
	if _dialog_action == ACTION_LOAN:
		return "贷款本金：%d 星穹（立即到账）\n应还：%d 星穹\n期限：2 在线小时，到期自动级联扣款\n扣款不足将信用违约并冻结银行信贷 6 小时" % [amount, ceili(float(amount) * 1.15)]
	return "确认执行当前操作"


func _get_action_display_name() -> String:
	## 返回当前银行操作中文名称，统一用于确认窗口标题和按钮。
	if _dialog_action == ACTION_DEPOSIT:
		return "存入"
	if _dialog_action == ACTION_WITHDRAW:
		return "取出"
	if _dialog_action == ACTION_FIXED:
		return "签订"
	if _dialog_action == ACTION_REPAY:
		return "还款"
	return "贷款"


func _confirm_pending_action() -> void:
	if _service == null:
		return
	# 确认金额；服务端在执行瞬间再次复核余额、占用与授信。
	var amount: int = maxi(_pending_amount, 1)
	var result: Dictionary = {}
	if _dialog_action == ACTION_DEPOSIT:
		result = _service.call("deposit", amount) as Dictionary
	elif _dialog_action == ACTION_WITHDRAW:
		result = _service.call("withdraw", amount) as Dictionary
	elif _dialog_action == ACTION_FIXED:
		result = _service.call("start_fixed_deposit", _dialog_argument, amount) as Dictionary
	elif _dialog_action == ACTION_LOAN:
		result = _service.call("start_loan", amount) as Dictionary
	elif _dialog_action == ACTION_REPAY:
		result = _service.call("repay_loan") as Dictionary
	if not bool(result.get("success", false)):
		_show_message(str(result.get("message", "操作失败")))
	_clear_pending_action()
	_refresh_coins()
	_rebuild_cards()


func _clear_pending_action() -> void:
	_pending_amount = 0
	_dialog_action = ""
	_dialog_argument = ""


func _on_account_changed(_balance: int) -> void:
	_refresh_coins()
	if _active_tab == TAB_DEMAND:
		_queue_cards_rebuild()


func _queue_cards_rebuild() -> void:
	## 合并卡片重建；同帧内账户、存单与贷款信号多次触发只执行一次重建。
	if _cards_rebuild_queued:
		return
	_cards_rebuild_queued = true
	call_deferred("_flush_queued_cards_rebuild")


func _flush_queued_cards_rebuild() -> void:
	## 执行单次卡片重建；期间若已发生直接重建，标志会被消化并跳过重复工作。
	if not _cards_rebuild_queued:
		return
	_rebuild_cards()


func _on_ui_style_changed(_style_id: String) -> void:
	## UI 风格切换后立即重建当前页卡片，刷新其中手动取色的背景、边框与文字。
	_rebuild_cards()


func _show_message(message: String) -> void:
	_message_dialog.present_information("银行提示", message)


func _close_panel() -> void:
	visible = false
	set_process(false)
	_clear_pending_action()
	closed.emit()


func _get_fixed_deposit_definition(deposit_id: String) -> Dictionary:
	## 从服务公开定义中查找指定存单类型；返回副本，UI 不修改静态配置。
	var definitions: Array = _service.call("get_fixed_deposit_definitions") as Array if _service != null and _service.has_method("get_fixed_deposit_definitions") else []
	for raw_definition in definitions:
		var definition: Dictionary = raw_definition as Dictionary
		if str(definition.get("id", "")) == deposit_id:
			return definition
	return {}


func _format_duration(seconds: float) -> String:
	# 完整剩余秒数；向上取整避免 0.1 秒时提前显示 00:00。
	var total_seconds: int = maxi(int(ceil(seconds)), 0)
	# 分钟部分；贷款与冻结可超过 60 分钟，因此不对分钟取模。
	var minutes: int = total_seconds / 60
	# 秒部分；固定显示两位，形成稳定倒计时宽度。
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]


func _format_hour_minute_duration(total_seconds: int) -> String:
	## 把秒数格式化为“X小时X分”样式的中文时长；用于存单时长展示，不用于逐秒倒计时。
	if total_seconds < 60:
		return "%d秒" % maxi(total_seconds, 0)
	# 完整小时数；存单时长最长 6 小时，不换算为天。
	var hours: int = total_seconds / 3600
	# 剩余分钟数；不足 1 分钟的秒数直接舍去，保持文本简洁。
	var minutes: int = (total_seconds % 3600) / 60
	if hours <= 0:
		return "%d分钟" % minutes
	if minutes <= 0:
		return "%d小时" % hours
	return "%d小时%d分" % [hours, minutes]
