extends PanelContainer

## 矿场面板只负责展示服务快照、收集整数输入和播放数值反馈，不拥有任何货币或资产数据。
## 面板关闭后整体停止处理，后台收益继续由 MiningFarmService 的低频结算独立运行。

signal closed

## 股市与全局物品共用的滑条数量弹窗；矿场扩展其整数交易模式，不再维护独立数量控件。
const SELL_QUANTITY_DIALOG_SCRIPT: Script = preload("res://scripts/ui/sell_quantity_dialog.gd")
## 股市同款二次确认弹窗；矿场交易在数量选择后统一展示最终金额并等待再次确认。
const COMMON_CONFIRMATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/common_confirmation_dialog.gd")
## 资产单台收益飘字组件；每台资产每秒生成一次独立上升淡出文字。
const MINING_INCOME_FLOAT_EMITTER_SCRIPT: Script = preload("res://scripts/components/mining_income_float_emitter.gd")
## 全局窗口样式指南；为矿场基准界面补充统一按钮、滚动、进度和弹窗控件主题。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 可购买资产页标识；用于标签按钮与列表重建，不写入存档。
const TAB_AVAILABLE: String = "available"
## 已持有资产页标识；资产按单台产出从高到低展示并提供出售入口。
const TAB_OWNED: String = "owned"
## 算力合同页标识；展示进行中合同状态与全部可签订合同类型。
const TAB_CONTRACTS: String = "contracts"
## 充值操作标识；数量弹窗输入整数永久星穹并按 1:10000 即时兑换。
const ACTION_RECHARGE: String = "recharge"
## 提现操作标识；数量弹窗输入整数到账星穹并实时显示算力币成本和手续费。
const ACTION_WITHDRAW: String = "withdraw"
## 出售操作标识；数量弹窗输入资产台数并实时显示 60% 折价返还。
const ACTION_SELL: String = "sell"
## 购买操作标识；数量弹窗输入资产台数并在二次确认后按官方单价批量购买。
const ACTION_BUY: String = "buy"
## 合同签订操作标识；数量弹窗输入到期到账星穹并实时显示需锁定的算力币。
const ACTION_CONTRACT: String = "contract"
## 固件升级操作标识；单次固定提升 1 级，跳过数量弹窗直接进入二次确认。
const ACTION_UPGRADE: String = "upgrade"
## 超频操作标识；免费启动但会进入长散热冷却，跳过数量弹窗直接进入二次确认。
const ACTION_OVERCLOCK: String = "overclock"
## 超频与合同倒计时轮询间隔；默认 0.25 秒，配合文本变化守卫以低成本刷新按钮与状态文字。
const STATUS_POLL_INTERVAL_SECONDS: float = 0.25

## 面板固定尺寸；默认 1080×640，适配 1280×720 主菜单并保留四周遮罩空间。
@export var panel_size: Vector2 = Vector2(1080.0, 640.0)
## 余额滚动时长；默认 0.55 秒，用于后台补齐、充值、提现和出售的平滑数字过渡。
@export_range(0.05, 2.0, 0.05) var balance_tween_duration_seconds: float = 0.55
## 资产启动动画时长；默认 0.4 秒，购买后卡片由暗到亮并轻微放大回落。
@export_range(0.05, 2.0, 0.05) var asset_startup_tween_duration_seconds: float = 0.40
## 资产页切换过渡时长；默认 0.3 秒，重新进入矿场时避免卡片突兀出现。
@export_range(0.05, 1.0, 0.05) var card_transition_duration_seconds: float = 0.30

## 矿场服务缓存；默认读取 Autoload，所有交易和收益快照都经由该服务完成。
var _service: Node
## 全局库存服务缓存；只读永久星穹余额，用于充值上限和状态栏提示。
var _global_inventory: Node
## 当前标签页；默认可购买资产页，切换后只重建中部卡片区。
var _active_tab: String = TAB_AVAILABLE
## 上次面板关闭时的真实余额；重新打开时作为后台收益补齐动画的起点。
var _last_visible_balance: int = 0
## 当前动画显示余额；可能暂时落后于服务真实余额，只用于数字滚动表现。
var _displayed_balance: float = 0.0
## 余额滚动 Tween；新交易发生时会终止旧动画并从当前显示值继续过渡。
var _balance_tween: Tween
## 每秒进度累计；取值 0 到 1，满 1 后重置形成持续产出节律。
var _progress_elapsed_seconds: float = 0.0
## 当前数量弹窗操作类型；取值为充值、提现或出售，确认时路由到对应服务接口。
var _dialog_action: String = ""
## 当前数量弹窗资产标识；仅出售模式有效，其他操作保持空字符串。
var _dialog_asset_id: String = ""
## 最近一次购买的资产标识；列表重建后用于定位并播放启动上线动画。
var _pending_startup_asset_id: String = ""
## 是否显示全部具体整数；默认 false 使用 K/M/B 缩写，开启后整个矿场界面禁用数字缩写。
var _show_exact_values: bool = false
## 等待二次确认的数量；默认 0，数量弹窗确认后保存到最终交易完成或取消。
var _pending_quantity: int = 0
## 产出呼吸 Tween；成员持有引用避免每次刷新都累积一个无引用的永久循环 Tween，重建前必须先终止旧动画。
var _production_tween: Tween
## 上次产出显示文本；默认空字符串，产出文本未变化时跳过标签重写与呼吸 Tween 重建。
var _last_production_text: String = ""
## 上次已渲染的整数显示余额；默认 -1 表示尚未渲染，余额滚动回调显示值未变化时跳过文本重建。
var _last_rendered_balance: int = -1
## 资产卡片重建是否已排队；默认 false，同帧多个服务信号合并为一次延迟重建。
var _assets_rebuild_queued: bool = false
## 倒计时轮询累计秒数；默认 0，达到轮询间隔后刷新超频按钮与合同倒计时文字。
var _status_poll_accumulator: float = 0.0
## 上次超频按钮文本；默认空字符串，轮询刷新时文本未变化则跳过按钮重写。
var _last_overclock_button_text: String = ""
## 上次合同倒计时文本；默认空字符串，轮询刷新时文本未变化则跳过标签重写。
var _last_contract_countdown_text: String = ""

## 余额文本；显示整数或 K/M/B 两位小数缩写，实际余额始终保持整数。
var _balance_label: Label
## 具体数值显示开关；位于余额右侧，切换后立即重建全部数值文本和资产卡片。
var _exact_value_check_box: CheckBox
## 星穹折合文本；固定保留四位小数，帮助玩家判断当前可提现进度。
var _gold_equivalent_label: Label
## 每秒产出文本；绿色高亮并持续播放轻微呼吸效果。
var _production_label: Label
## 增益状态容器；按增益名称、百分比和剩余在线时间纵向显示。
var _buff_container: VBoxContainer
## 可购买页按钮；切换模式并同步按下状态。
var _available_tab_button: Button
## 已持有页按钮；切换模式并同步按下状态。
var _owned_tab_button: Button
## 算力合同页按钮；切换模式并同步按下状态。
var _contracts_tab_button: Button
## 超频按钮；位于产出状态区下方，按当前超频快照显示可用、进行中或散热倒计时。
var _overclock_button: Button
## 进行中合同倒计时标签；仅合同页存在进行中合同时有效，页面重建时重新捕获引用。
var _contract_countdown_label: Label
## 资产卡片流式容器；根据面板宽度自动换行并保持居中。
var _asset_container: HFlowContainer
## 收益进度条；底部按秒从 0 填充到 1 后循环重置。
var _production_progress: ProgressBar
## 浮动收益提示层；余额正向变化或后台补齐时在状态栏下方上浮淡出。
var _floating_feedback_layer: Control
## 数量操作弹窗；充值、提现和出售共用同一紧凑组件。
var _quantity_dialog: SellQuantityDialog
## 股市同款二次确认弹窗；完整展示操作、数量、金额和余额状态后才执行真实交易。
var _confirmation_dialog: CommonConfirmationDialog
## 信息提示弹窗；交易失败时展示服务返回原因，不修改任何数据。
var _message_dialog: CommonConfirmationDialog


func _ready() -> void:
	custom_minimum_size = panel_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	_service = get_tree().root.get_node_or_null("MiningFarmService")
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	_connect_services()
	# UI 风格服务；资产卡片和空增益提示使用手动取色，监听切换信号后立即重刷而不等待下次重建。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))
	set_process(false)
	_refresh_all(false)


func _process(delta: float) -> void:
	_progress_elapsed_seconds = fmod(_progress_elapsed_seconds + maxf(delta, 0.0), 1.0)
	if _production_progress != null and not is_equal_approx(float(_production_progress.value), _progress_elapsed_seconds):
		# 进度条写入守卫；值未变化时跳过属性赋值，避免暂停或极端帧率下的重复重绘请求。
		_production_progress.value = _progress_elapsed_seconds
	# 倒计时轮询；超频按钮与合同倒计时按固定间隔拉取服务快照，文本未变化时不产生任何控件写入。
	_status_poll_accumulator += maxf(delta, 0.0)
	if _status_poll_accumulator >= STATUS_POLL_INTERVAL_SECONDS:
		_status_poll_accumulator = 0.0
		_refresh_overclock_button()
		_refresh_contract_countdown()


func present() -> void:
	visible = true
	set_process(true)
	# 打开前余额；用于识别服务补齐后台完整秒收益后实际增加的数量。
	var balance_before_open: int = _last_visible_balance
	if _service != null and _service.has_method("set_panel_open"):
		_service.call("set_panel_open", true)
	# 当前真实余额；服务可能在 set_panel_open 中先完成后台补齐。
	var current_balance: int = _get_real_balance()
	_displayed_balance = float(balance_before_open)
	_refresh_all(false)
	_animate_balance_to(current_balance)
	_animate_cards_in()
	_present_offline_income_report()


func _present_offline_income_report() -> void:
	## 展示启动时补发的离线收益报告；服务侧一次离线只产生一份报告，取走后不会重复弹出。
	if _service == null or not _service.has_method("take_offline_income_report"):
		return
	# 待展示报告；为空表示本次启动没有离线补发或已经展示过。
	var report: Dictionary = _service.call("take_offline_income_report") as Dictionary
	if report.is_empty():
		return
	# 原始离线秒数；超出上限时在报告中说明封顶规则，帮助玩家理解补发金额。
	var raw_seconds: int = int(report.get("raw_offline_seconds", 0))
	# 参与补发的有效离线秒数；已按 8 小时上限截断。
	var counted_seconds: int = int(report.get("offline_seconds", 0))
	# 报告正文；离线时长、折算比例与到账金额逐行展示。
	var message: String = "离线时长：%s" % _format_hour_minute_duration(raw_seconds)
	if raw_seconds > counted_seconds:
		message += "（超出 8 小时上限的部分不计）"
	message += "\n离线期间按在线基础产出的 25%% 折算\n本次到账：+%s 算力币" % _format_integer_value(int(report.get("earned", 0)))
	_message_dialog.present_information("离线收益报告", message)


func _connect_services() -> void:
	if _service == null:
		return
	if _service.has_signal("balance_changed"):
		_service.connect("balance_changed", Callable(self, "_on_balance_changed"))
	if _service.has_signal("production_changed"):
		_service.connect("production_changed", Callable(self, "_on_production_changed"))
	if _service.has_signal("production_settled"):
		_service.connect("production_settled", Callable(self, "_on_production_settled"))
	if _service.has_signal("assets_changed"):
		_service.connect("assets_changed", Callable(self, "_on_assets_changed"))
	if _service.has_signal("buffs_changed"):
		_service.connect("buffs_changed", Callable(self, "_refresh_buffs"))
	if _service.has_signal("overclock_changed"):
		_service.connect("overclock_changed", Callable(self, "_refresh_overclock_button"))
	if _service.has_signal("contract_changed"):
		_service.connect("contract_changed", Callable(self, "_on_contract_changed"))
	if _service.has_signal("contract_completed"):
		_service.connect("contract_completed", Callable(self, "_on_contract_completed"))


func _build_interface() -> void:
	# 面板样式；统一取样式指南主窗口样式并自动登记，UI 风格切换时立即刷新背景与描边。
	UI_STYLE_GUIDE.apply_window_panel(self)
	# 外边距；为标题、卡片和底部按钮提供统一留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	# 主纵向布局；依次承载状态栏、标签页、资产区、进度条和操作栏。
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	_build_header(root)
	_build_tabs(root)
	_build_asset_area(root)
	_build_footer(root)
	_build_quantity_dialog()
	_build_message_dialog()


func _build_header(root: VBoxContainer) -> void:
	# 顶部状态栏；左右分别显示余额和产出/增益，中间自动扩展。
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 100.0)
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)
	# 余额区；大字号余额下方显示四位小数星穹折合值。
	var balance_box: VBoxContainer = VBoxContainer.new()
	balance_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(balance_box)
	_balance_label = Label.new()
	_balance_label.add_theme_font_size_override("font_size", 31)
	UI_STYLE_GUIDE.apply_title_label(_balance_label)
	# 余额标题行；余额左侧保持主视觉，右侧放置具体数值开关且不挤压产出状态栏。
	var balance_title_row: HBoxContainer = HBoxContainer.new()
	balance_title_row.add_theme_constant_override("separation", 12)
	balance_box.add_child(balance_title_row)
	balance_title_row.add_child(_balance_label)
	_exact_value_check_box = CheckBox.new()
	_exact_value_check_box.text = "显示具体数值"
	_exact_value_check_box.button_pressed = _show_exact_values
	_exact_value_check_box.toggled.connect(_on_exact_value_toggled)
	balance_title_row.add_child(_exact_value_check_box)
	_gold_equivalent_label = Label.new()
	_gold_equivalent_label.add_theme_font_size_override("font_size", 13)
	UI_STYLE_GUIDE.apply_secondary_label(_gold_equivalent_label)
	balance_box.add_child(_gold_equivalent_label)
	_floating_feedback_layer = Control.new()
	_floating_feedback_layer.custom_minimum_size = Vector2(0.0, 34.0)
	_floating_feedback_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance_box.add_child(_floating_feedback_layer)
	# 产出区；右对齐显示当前整数产出和所有生效增益。
	var production_box: VBoxContainer = VBoxContainer.new()
	production_box.custom_minimum_size = Vector2(360.0, 0.0)
	header.add_child(production_box)
	_production_label = Label.new()
	_production_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_production_label.add_theme_font_size_override("font_size", 20)
	_production_label.add_theme_color_override("font_color", Color(0.34, 1.0, 0.62, 1.0))
	production_box.add_child(_production_label)
	_buff_container = VBoxContainer.new()
	production_box.add_child(_buff_container)
	# 超频按钮；位于产出与增益下方右对齐，点击后经二次确认启动 300 秒 1.5 倍产出并进入 1800 秒散热。
	_overclock_button = Button.new()
	_overclock_button.custom_minimum_size = Vector2(186.0, 32.0)
	_overclock_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	UI_STYLE_GUIDE.apply_primary_button(_overclock_button)
	_overclock_button.pressed.connect(Callable(self, "_open_direct_confirmation").bind(ACTION_OVERCLOCK, ""))
	production_box.add_child(_overclock_button)
	_refresh_overclock_button()
	# 关闭按钮；关闭后 UI 和动画停止，服务转入后台低频结算。
	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(90.0, 36.0)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.text = "关闭"
	close_button.pressed.connect(_close_panel)
	header.add_child(close_button)


func _build_tabs(root: VBoxContainer) -> void:
	# 标签栏；按钮使用切换模式，任何时刻只保持当前页面按下。
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	_available_tab_button = Button.new()
	_available_tab_button.text = "可购买资产"
	_available_tab_button.toggle_mode = true
	_available_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_available_tab_button.pressed.connect(Callable(self, "_switch_tab").bind(TAB_AVAILABLE))
	tabs.add_child(_available_tab_button)
	_owned_tab_button = Button.new()
	_owned_tab_button.text = "已持有资产"
	_owned_tab_button.toggle_mode = true
	_owned_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_owned_tab_button.pressed.connect(Callable(self, "_switch_tab").bind(TAB_OWNED))
	tabs.add_child(_owned_tab_button)
	_contracts_tab_button = Button.new()
	_contracts_tab_button.text = "算力合同"
	_contracts_tab_button.toggle_mode = true
	_contracts_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contracts_tab_button.pressed.connect(Callable(self, "_switch_tab").bind(TAB_CONTRACTS))
	tabs.add_child(_contracts_tab_button)


func _build_asset_area(root: VBoxContainer) -> void:
	# 资产滚动区；卡片固定宽度并通过流式容器自动换行，避免不同分辨率出现大块空白。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_asset_container = HFlowContainer.new()
	_asset_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_asset_container.add_theme_constant_override("h_separation", 12)
	_asset_container.add_theme_constant_override("v_separation", 12)
	_asset_container.alignment = FlowContainer.ALIGNMENT_CENTER
	scroll.add_child(_asset_container)


func _build_footer(root: VBoxContainer) -> void:
	_production_progress = ProgressBar.new()
	_production_progress.custom_minimum_size = Vector2(0.0, 5.0)
	_production_progress.min_value = 0.0
	_production_progress.max_value = 1.0
	_production_progress.show_percentage = false
	root.add_child(_production_progress)
	# 操作栏；充值和提现分列两侧，中间长期显示固定兑换规则。
	var operations: HBoxContainer = HBoxContainer.new()
	operations.add_theme_constant_override("separation", 14)
	root.add_child(operations)
	var recharge_button: Button = Button.new()
	recharge_button.custom_minimum_size = Vector2(180.0, 42.0)
	recharge_button.text = "充值"
	UI_STYLE_GUIDE.apply_primary_button(recharge_button)
	recharge_button.pressed.connect(Callable(self, "_open_quantity_dialog").bind(ACTION_RECHARGE, ""))
	operations.add_child(recharge_button)
	var rule_label: Label = Label.new()
	rule_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rule_label.add_theme_font_size_override("font_size", 13)
	UI_STYLE_GUIDE.apply_secondary_label(rule_label)
	rule_label.text = "1星穹 = 10000算力币  |  提现手续费10%  |  算力合同费率2%-8%"
	operations.add_child(rule_label)
	var withdraw_button: Button = Button.new()
	withdraw_button.custom_minimum_size = Vector2(180.0, 42.0)
	withdraw_button.text = "提现"
	withdraw_button.pressed.connect(Callable(self, "_open_quantity_dialog").bind(ACTION_WITHDRAW, ""))
	operations.add_child(withdraw_button)


func _build_quantity_dialog() -> void:
	_quantity_dialog = SELL_QUANTITY_DIALOG_SCRIPT.new() as SellQuantityDialog
	_quantity_dialog.connect("quantity_confirmed", Callable(self, "_on_quantity_confirmed"))
	add_child(_quantity_dialog)
	_confirmation_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_confirmation_dialog.confirmed.connect(_confirm_quantity_action)
	_confirmation_dialog.canceled.connect(_clear_pending_transaction)
	add_child(_confirmation_dialog)


func _build_message_dialog() -> void:
	_message_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	add_child(_message_dialog)


func _refresh_all(sync_balance: bool = true) -> void:
	if sync_balance:
		_displayed_balance = float(_get_real_balance())
	_refresh_balance_text()
	_refresh_production()
	_refresh_buffs()
	_refresh_tabs()
	_rebuild_assets()


func _refresh_balance_text() -> void:
	if _balance_label == null:
		return
	# 显示整数余额；动画中先把浮点显示值四舍五入为整数，再进行单位缩写。
	var display_balance: int = maxi(int(round(_displayed_balance)), 0)
	if display_balance == _last_rendered_balance:
		# 显示值守卫；余额滚动动画每帧回调，整数显示值未变化时跳过余额与折合星穹文本重建。
		return
	_last_rendered_balance = display_balance
	_balance_label.text = "%s 算力币" % _format_integer_value(display_balance)
	_gold_equivalent_label.text = "折合星穹：%.4f" % (float(display_balance) / 10000.0)


func _refresh_production(_unused_value: int = 0) -> void:
	# 当前整数产出；服务不可用时显示 0，避免面板因单例缺失报错。
	var production: int = int(_service.call("get_production_per_second")) if _service != null and _service.has_method("get_production_per_second") else 0
	# 本次产出显示文本；与上次相同且循环动画仍有效时直接返回，不重建标签与 Tween。
	var production_text: String = "每秒产出 +%s" % _format_integer_value(production)
	if production_text == _last_production_text and _production_tween != null and _production_tween.is_valid():
		return
	_last_production_text = production_text
	_production_label.text = production_text
	if _production_tween != null and _production_tween.is_valid():
		# 旧呼吸 Tween；重建前必须终止，否则每次刷新都会累积一个永久循环 Tween 造成泄漏。
		_production_tween.kill()
	# 呼吸动画；只作用于产出标签透明度，不改变布局或可点击区域。
	_production_tween = create_tween().set_loops()
	_production_tween.tween_property(_production_label, "modulate:a", 0.66, 0.65)
	_production_tween.tween_property(_production_label, "modulate:a", 1.0, 0.65)


func _refresh_buffs() -> void:
	if _buff_container == null:
		return
	# 当前增益列表；空列表显示稳定占位文本，避免状态栏高度跳动。
	var buffs: Array = _service.call("get_active_buffs") as Array if _service != null and _service.has_method("get_active_buffs") else []
	# 本次需要的标签数量；空增益仍占用一行占位文本，复用已有节点避免每秒倒计时销毁重建。
	var required_label_count: int = maxi(buffs.size(), 1)
	while _buff_container.get_child_count() > required_label_count:
		# 多余标签；仅在增益数量减少时释放节点，常规倒计时刷新只更新文本。
		var extra_label: Node = _buff_container.get_child(_buff_container.get_child_count() - 1)
		_buff_container.remove_child(extra_label)
		extra_label.queue_free()
	while _buff_container.get_child_count() < required_label_count:
		# 新增标签；仅在增益数量增加时创建节点，右对齐样式与原实现保持一致。
		var created_label: Label = Label.new()
		created_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_buff_container.add_child(created_label)
	if buffs.is_empty():
		# 占位标签；复用首个子节点显示无增益状态，禁用文字色随当前 UI 风格取值。
		var empty_label: Label = _buff_container.get_child(0) as Label
		empty_label.text = "当前无临时增益"
		empty_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_disabled_text_color())
		return
	for buff_index in range(buffs.size()):
		# 单个增益快照；包含名称、比例和剩余在线时间，负时间表示随外部事件结束。
		var buff: Dictionary = buffs[buff_index] as Dictionary
		# 复用增益标签；按下标取已有子节点，仅更新颜色与文本，不重建控件。
		var buff_label: Label = _buff_container.get_child(buff_index) as Label
		buff_label.add_theme_color_override("font_color", Color(0.46, 0.92, 0.72, 1.0))
		# 剩余时间文本；股市联动使用“至下次全量刷新”，骇入增益使用分秒倒计时。
		var remaining: float = float(buff.get("remaining_seconds", -1.0))
		var time_text: String = "至下次股市全量刷新" if remaining < 0.0 else _format_duration(remaining)
		buff_label.text = "%s +%.2f%%  %s" % [str(buff.get("name", "增益")), float(buff.get("ratio", 0.0)) * 100.0, time_text]


func _refresh_tabs() -> void:
	_available_tab_button.set_pressed_no_signal(_active_tab == TAB_AVAILABLE)
	_owned_tab_button.set_pressed_no_signal(_active_tab == TAB_OWNED)
	_contracts_tab_button.set_pressed_no_signal(_active_tab == TAB_CONTRACTS)


func _switch_tab(tab_id: String) -> void:
	if _active_tab == tab_id:
		_refresh_tabs()
		return
	_active_tab = tab_id
	_refresh_tabs()
	_rebuild_assets()
	_animate_cards_in()


func _rebuild_assets() -> void:
	# 任何直接重建都消化当前挂起的合并刷新；同帧稍后的延迟回调据此跳过重复重建。
	_assets_rebuild_queued = false
	if _asset_container == null:
		return
	# 合同倒计时引用清理；旧标签随子节点释放，避免轮询刷新访问已销毁控件。
	_contract_countdown_label = null
	_last_contract_countdown_text = ""
	for child in _asset_container.get_children():
		child.queue_free()
	if _active_tab == TAB_CONTRACTS:
		_rebuild_contracts()
		return
	# 资产定义副本；两个标签页都保持官方成长阶梯顺序，便于玩家在购买与持有页面建立稳定位置记忆。
	var definitions: Array = _service.call("get_asset_definitions") as Array if _service != null and _service.has_method("get_asset_definitions") else []
	for raw_definition in definitions:
		# 资产定义；每张卡片只读取当前快照，点击时服务仍会再次校验真实状态。
		var definition: Dictionary = raw_definition as Dictionary
		var asset_id: String = str(definition.get("id", ""))
		var quantity: int = int(_service.call("get_asset_quantity", asset_id)) if _service != null else 0
		_asset_container.add_child(_create_asset_card(definition, quantity))
	if _asset_container.get_child_count() == 0:
		var empty_label: Label = Label.new()
		empty_label.custom_minimum_size = Vector2(900.0, 90.0)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.text = "尚未持有算力资产" if _active_tab == TAB_OWNED else "暂无可展示资产"
		_asset_container.add_child(empty_label)


func _rebuild_contracts() -> void:
	## 重建算力合同页；进行中合同卡片置于首位，随后按定义顺序展示全部可签订合同类型。
	# 进行中合同快照；为空表示当前没有合同，可签订卡片据此决定按钮可用状态。
	var active_snapshot: Dictionary = _service.call("get_active_contract_snapshot") as Dictionary if _service != null and _service.has_method("get_active_contract_snapshot") else {}
	if not active_snapshot.is_empty():
		_asset_container.add_child(_create_active_contract_card(active_snapshot))
	# 合同定义副本；卡片只读取快照，签订时服务仍会再次校验余额与合同占用。
	var definitions: Array = _service.call("get_contract_definitions") as Array if _service != null and _service.has_method("get_contract_definitions") else []
	for raw_definition in definitions:
		# 单个合同定义；包含稳定标识、名称、在线时长、兑付比例和说明。
		var definition: Dictionary = raw_definition as Dictionary
		_asset_container.add_child(_create_contract_card(definition, not active_snapshot.is_empty()))


func _create_active_contract_card(snapshot: Dictionary) -> Control:
	# 进行中合同卡片；使用激活样式突出显示，倒计时标签由固定间隔轮询刷新。
	var card: PanelContainer = PanelContainer.new()
	card.name = "ActiveContractCard"
	card.custom_minimum_size = Vector2(318.0, 146.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	# 卡片背景与边框；进行中合同使用与运行资产一致的亮色语义。
	style.bg_color = UI_STYLE_GUIDE.get_section_background_color()
	style.border_color = UI_STYLE_GUIDE.get_accent_muted_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color())
	name_label.text = "进行中：%s" % str(snapshot.get("name", "算力合同"))
	content.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	detail_label.text = "锁定 %s 算力币  |  到期到账 %s 星穹" % [_format_integer_value(int(snapshot.get("locked_compute", 0))), _format_integer_value(int(snapshot.get("gold_amount", 0)))]
	content.add_child(detail_label)
	# 倒计时标签；文本由轮询按剩余整数秒刷新，绿色与产出收益语义保持一致。
	_contract_countdown_label = Label.new()
	_contract_countdown_label.add_theme_font_size_override("font_size", 14)
	_contract_countdown_label.add_theme_color_override("font_color", Color(0.46, 0.92, 0.72, 1.0))
	content.add_child(_contract_countdown_label)
	_refresh_contract_countdown()
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var note_label: Label = Label.new()
	note_label.add_theme_font_size_override("font_size", 11)
	note_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	note_label.text = "合同仅消耗在线时间，中途不可撤销"
	content.add_child(note_label)
	return card


func _create_contract_card(definition: Dictionary, contract_occupied: bool) -> Control:
	# 可签订合同卡片；结构与资产卡片一致，按钮在已有进行中合同时统一禁用。
	var card: PanelContainer = PanelContainer.new()
	card.name = str(definition.get("id", "ContractCard"))
	card.custom_minimum_size = Vector2(318.0, 146.0)
	# 卡片可用状态；仅受合同占用影响，余额不足在点击时由弹窗流程提示。
	var card_active: bool = not contract_occupied
	var style: StyleBoxFlat = StyleBoxFlat.new()
	# 卡片背景与边框；被占用时复用锁定资产的暗色停机语义。
	style.bg_color = UI_STYLE_GUIDE.get_section_background_color() if card_active else Color(UI_STYLE_GUIDE.get_item_card_background_color(), 0.62)
	style.border_color = UI_STYLE_GUIDE.get_accent_muted_color() if card_active else Color(UI_STYLE_GUIDE.get_section_border_color(), 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color() if card_active else UI_STYLE_GUIDE.get_disabled_text_color())
	name_label.text = str(definition.get("name", "算力合同"))
	content.add_child(name_label)
	# 卡片说明文字色；与资产卡片一致，占用状态降低透明度弱化不可操作内容。
	var card_detail_color: Color = UI_STYLE_GUIDE.get_secondary_text_color() if card_active else Color(UI_STYLE_GUIDE.get_secondary_text_color(), 0.72)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", card_detail_color)
	# 合同费率百分比；由兑付比例换算，向下保留整数位便于与提现 10% 直接对比。
	var fee_percent: int = int(round((1.0 - float(definition.get("payout_ratio", 0.0))) * 100.0))
	detail_label.text = "在线 %s  |  费率 %d%%" % [_format_hour_minute_duration(int(definition.get("duration_seconds", 0))), fee_percent]
	content.add_child(detail_label)
	var description_label: Label = Label.new()
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", card_detail_color)
	description_label.text = str(definition.get("description", ""))
	content.add_child(description_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(0.0, 32.0)
	if contract_occupied:
		action_button.text = "已有进行中合同"
		action_button.disabled = true
	else:
		action_button.text = "签订合同"
		UI_STYLE_GUIDE.apply_primary_button(action_button)
		action_button.pressed.connect(Callable(self, "_open_quantity_dialog").bind(ACTION_CONTRACT, str(definition.get("id", ""))))
	content.add_child(action_button)
	return card


func _create_asset_card(definition: Dictionary, quantity: int) -> Control:
	# 资产卡片；固定 318×146 并以独立 PanelContainer 承载，不复用物品卡片以避免混淆物品所有权协议。
	var card: PanelContainer = PanelContainer.new()
	card.name = str(definition.get("id", "AssetCard"))
	card.custom_minimum_size = Vector2(318.0, 146.0)
	# 解锁状态；永久解锁由服务持有，锁定卡片仍展示门槛以形成明确成长目标。
	var asset_id: String = str(definition.get("id", ""))
	var unlocked: bool = bool(_service.call("is_asset_unlocked", asset_id)) if _service != null else false
	# 卡片激活状态；可购买页按永久解锁判断，已持有页只有数量大于 0 时显示运行中的亮色样式。
	var card_active: bool = unlocked if _active_tab == TAB_AVAILABLE else quantity > 0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	# 卡片背景与边框；激活时取当前风格子分区色与弱强调描边，锁定时改用物品卡片底色并降低透明度表达停机状态。
	style.bg_color = UI_STYLE_GUIDE.get_section_background_color() if card_active else Color(UI_STYLE_GUIDE.get_item_card_background_color(), 0.62)
	style.border_color = UI_STYLE_GUIDE.get_accent_muted_color() if card_active else Color(UI_STYLE_GUIDE.get_section_border_color(), 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	# 名称与收益行；名称右侧挂载单台收益飘字发射区域，不显示固定汇总文字。
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	content.add_child(name_row)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color() if card_active else UI_STYLE_GUIDE.get_disabled_text_color())
	name_label.text = str(definition.get("name", "未知资产"))
	name_row.add_child(name_label)
	# 飘字承载区；固定宽度避免高频收益文字推动名称行布局。
	var income_float_area: Control = Control.new()
	income_float_area.custom_minimum_size = Vector2(104.0, 24.0)
	income_float_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(income_float_area)
	# 单台收益发射器；实际持有量为 0 时保持静默，持有 N 台时每秒逻辑发射 N 次。
	# 固件升级补充；飘字显示固件加成后向下取整的单台收益，仅影响视觉数值，真实结算仍按类别整体取整。
	var effective_unit_production: int = int(_service.call("get_asset_effective_unit_production", asset_id)) if _service != null and _service.has_method("get_asset_effective_unit_production") else int(definition.get("production", 0))
	var income_emitter: Control = MINING_INCOME_FLOAT_EMITTER_SCRIPT.new() as Control
	income_emitter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	income_emitter.call("configure", quantity, effective_unit_production, _show_exact_values)
	income_float_area.add_child(income_emitter)
	# 卡片说明文字色；取当前风格次要文字色，锁定卡片降低透明度以弱化未运行内容。
	var card_detail_color: Color = UI_STYLE_GUIDE.get_secondary_text_color() if card_active else Color(UI_STYLE_GUIDE.get_secondary_text_color(), 0.72)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", card_detail_color)
	if _active_tab == TAB_AVAILABLE:
		detail_label.text = "单价 %s  |  单台 +%s/秒" % [_format_integer_value(int(definition.get("price", 0))), _format_integer_value(int(definition.get("production", 0)))]
	else:
		# 本类实际总产出；由服务按“单台基础×数量×固件倍率”整体向下取整，与真实结算完全一致。
		var type_production: int = int(_service.call("get_asset_type_production", asset_id)) if _service != null and _service.has_method("get_asset_type_production") else quantity * int(definition.get("production", 0))
		# 当前固件等级；已持有页始终展示，帮助玩家对比不同资产线的升级进度。
		var owned_upgrade_level: int = int(_service.call("get_asset_upgrade_level", asset_id)) if _service != null and _service.has_method("get_asset_upgrade_level") else 0
		detail_label.text = "持有 %s 台  |  Lv.%d  |  本类 +%s/秒" % [_format_integer_value(quantity), owned_upgrade_level, _format_integer_value(type_production)]
	content.add_child(detail_label)
	var description_label: Label = Label.new()
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", card_detail_color)
	description_label.text = str(definition.get("description", ""))
	content.add_child(description_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(0.0, 32.0)
	if _active_tab == TAB_AVAILABLE:
		action_button.text = "购买" if unlocked else "总产出达到 %s/秒后解锁" % _format_integer_value(int(definition.get("unlock_rate", 0)))
		action_button.disabled = not unlocked
		UI_STYLE_GUIDE.apply_primary_button(action_button)
		action_button.pressed.connect(Callable(self, "_open_quantity_dialog").bind(ACTION_BUY, asset_id))
		content.add_child(action_button)
	else:
		if quantity > 0:
			# 操作按钮行；固件升级与出售并排等宽，升级达到最大等级后左侧按钮禁用。
			var action_row: HBoxContainer = HBoxContainer.new()
			action_row.add_theme_constant_override("separation", 8)
			content.add_child(action_row)
			# 下一级升级费用；0 表示已达最大等级，此时不再提供升级入口。
			var upgrade_cost: int = int(_service.call("get_asset_upgrade_cost", asset_id)) if _service != null and _service.has_method("get_asset_upgrade_cost") else 0
			# 当前固件等级；用于升级按钮的等级跨度文案。
			var upgrade_level: int = int(_service.call("get_asset_upgrade_level", asset_id)) if _service != null and _service.has_method("get_asset_upgrade_level") else 0
			# 固件升级按钮；单次固定提升 1 级，点击后跳过数量弹窗直接进入二次确认。
			var upgrade_button: Button = Button.new()
			upgrade_button.custom_minimum_size = Vector2(0.0, 32.0)
			upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if upgrade_cost > 0:
				upgrade_button.text = "固件 Lv.%d→%d" % [upgrade_level, upgrade_level + 1]
				UI_STYLE_GUIDE.apply_primary_button(upgrade_button)
				upgrade_button.pressed.connect(Callable(self, "_open_direct_confirmation").bind(ACTION_UPGRADE, asset_id))
			else:
				upgrade_button.text = "固件已满级"
				upgrade_button.disabled = true
			action_row.add_child(upgrade_button)
			action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_button.text = "出售"
			UI_STYLE_GUIDE.apply_danger_button(action_button)
			action_button.pressed.connect(Callable(self, "_open_quantity_dialog").bind(ACTION_SELL, asset_id))
			action_row.add_child(action_button)
		else:
			# 未持有提示；已持有页只表达资产所有权状态，具体解锁门槛统一留在可购买资产页展示。
			action_button.text = "未购买"
			action_button.disabled = true
			content.add_child(action_button)
	if asset_id == _pending_startup_asset_id:
		_pending_startup_asset_id = ""
		_play_startup_animation(card)
	return card


func _open_quantity_dialog(action: String, asset_id: String) -> void:
	_dialog_action = action
	_dialog_asset_id = asset_id
	_pending_quantity = 0
	if action == ACTION_RECHARGE:
		# 最大充值星穹；至少允许输入 1，最终仍由服务校验真实余额。
		var coins: int = int(_global_inventory.call("get_coins")) if _global_inventory != null and _global_inventory.has_method("get_coins") else 0
		if coins <= 0:
			_show_message("星穹不足，无法充值")
			_clear_pending_transaction()
			return
		_quantity_dialog.present_mining_transaction(ACTION_RECHARGE, "算力币充值", coins, 10000, 0.60, 0.10, _show_exact_values)
	elif action == ACTION_WITHDRAW:
		# 最大可提现星穹；使用服务精确公式，避免按单星穹成本近似造成大额提现上限偏差。
		var maximum_gold: int = int(_service.call("get_maximum_withdrawable_gold")) if _service != null and _service.has_method("get_maximum_withdrawable_gold") else 0
		if maximum_gold <= 0:
			_show_message("算力币余额不足，最低提现 1 星穹")
			_clear_pending_transaction()
			return
		_quantity_dialog.present_mining_transaction(ACTION_WITHDRAW, "星穹提现", maximum_gold, 10000, 0.60, 0.10, _show_exact_values)
	elif action == ACTION_CONTRACT:
		# 合同占用校验；服务同一时间只允许一份进行中合同，占用时直接提示而不打开数量弹窗。
		if _service != null and _service.has_method("has_active_contract") and bool(_service.call("has_active_contract")):
			_show_message("已有进行中合同，需等待当前合同交付")
			_clear_pending_transaction()
			return
		# 当前合同定义；用于读取名称与兑付比例，签订时服务仍按当前定义重新计算。
		var contract_definition: Dictionary = _get_contract_definition(asset_id)
		# 最大可签订星穹；使用服务精确公式，避免按单星穹成本近似造成大额签订上限偏差。
		var maximum_contract_gold: int = int(_service.call("get_maximum_contract_gold", asset_id)) if _service != null and _service.has_method("get_maximum_contract_gold") else 0
		if contract_definition.is_empty() or maximum_contract_gold <= 0:
			_show_message("算力币余额不足，最低签订 1 星穹")
			_clear_pending_transaction()
			return
		# 合同费率损耗；换算为提现同款“1 - 费率”形式传入数量弹窗，复用整体反推预览公式。
		var contract_fee_ratio: float = 1.0 - clampf(float(contract_definition.get("payout_ratio", 0.0)), 0.01, 1.0)
		_quantity_dialog.present_mining_transaction(ACTION_CONTRACT, str(contract_definition.get("name", "算力合同")), maximum_contract_gold, 10000, 0.60, contract_fee_ratio, _show_exact_values)
	else:
		# 当前资产定义；数量窗口读取官方单价，确认时服务仍按当前定义重新计算。
		var definition: Dictionary = _get_asset_definition(asset_id)
		var unit_price: int = int(definition.get("price", 0))
		var display_name: String = str(definition.get("name", "算力资产"))
		if action == ACTION_SELL:
			var owned_quantity: int = int(_service.call("get_asset_quantity", asset_id))
			_quantity_dialog.present_mining_transaction(ACTION_SELL, display_name, owned_quantity, unit_price, 0.60, 0.10, _show_exact_values)
		else:
			var maximum_buy: int = int(_service.call("get_maximum_buy_quantity", asset_id)) if _service.has_method("get_maximum_buy_quantity") else 0
			if maximum_buy <= 0:
				_show_message("算力币余额不足，无法购买该资产")
				_clear_pending_transaction()
				return
			_quantity_dialog.present_mining_transaction(ACTION_BUY, display_name, maximum_buy, unit_price, 0.60, 0.10, _show_exact_values)


func _on_quantity_confirmed(quantity: int) -> void:
	_pending_quantity = maxi(quantity, 1)
	# 二次确认内容；完整列出实际数量和服务公式计算的最终整数金额。
	var message: String = _build_transaction_confirmation_message()
	var action_name: String = _get_action_display_name()
	_confirmation_dialog.present_adaptive("确认%s" % action_name, message, "确认%s" % action_name, "取消", true)


func _open_direct_confirmation(action: String, asset_id: String) -> void:
	## 打开无数量选择的二次确认；固件升级与超频单次只有一种结果，跳过滑条数量弹窗。
	_dialog_action = action
	_dialog_asset_id = asset_id
	# 固定数量；直接确认操作不涉及数量选择，保持确认回调的统一数量约定。
	_pending_quantity = 1
	# 确认正文；与数量弹窗流程共用同一构建入口，展示费用与生效说明。
	var message: String = _build_transaction_confirmation_message()
	var action_name: String = _get_action_display_name()
	_confirmation_dialog.present_adaptive("确认%s" % action_name, message, "确认%s" % action_name, "取消", true)


func _confirm_quantity_action() -> void:
	if _service == null:
		return
	# 确认数量；来自股市同款滑条窗口，并在服务端再次复核余额或持有量。
	var quantity: int = maxi(_pending_quantity, 1)
	var result: Dictionary = {}
	if _dialog_action == ACTION_RECHARGE:
		result = _service.call("recharge", quantity) as Dictionary
	elif _dialog_action == ACTION_WITHDRAW:
		result = _service.call("withdraw", quantity) as Dictionary
	elif _dialog_action == ACTION_BUY:
		result = _service.call("buy_asset", _dialog_asset_id, quantity) as Dictionary
	elif _dialog_action == ACTION_SELL:
		result = _service.call("sell_asset", _dialog_asset_id, quantity) as Dictionary
	elif _dialog_action == ACTION_CONTRACT:
		result = _service.call("start_contract", _dialog_asset_id, quantity) as Dictionary
	elif _dialog_action == ACTION_UPGRADE:
		result = _service.call("upgrade_asset", _dialog_asset_id) as Dictionary
	elif _dialog_action == ACTION_OVERCLOCK:
		result = _service.call("activate_overclock") as Dictionary
	if not bool(result.get("success", false)):
		_show_message(str(result.get("message", "操作失败")))
		_clear_pending_transaction()
		return
	if _dialog_action == ACTION_SELL:
		_show_floating_feedback("资产变现 +%s 算力币" % _format_integer_value(int(result.get("returned", 0))))
	elif _dialog_action == ACTION_RECHARGE:
		_show_floating_feedback("充值到账 +%s 算力币" % _format_integer_value(int(result.get("compute_coins", 0))))
	elif _dialog_action == ACTION_CONTRACT:
		_show_floating_feedback("合同签订 锁定 -%s 算力币" % _format_integer_value(int(result.get("locked", 0))))
	elif _dialog_action == ACTION_UPGRADE:
		_show_floating_feedback("固件升级 -%s 算力币" % _format_integer_value(int(result.get("cost", 0))))
	elif _dialog_action == ACTION_OVERCLOCK:
		_show_floating_feedback("超频启动 产出 ×1.5")
	else:
		if _dialog_action == ACTION_BUY:
			_pending_startup_asset_id = _dialog_asset_id
			_show_floating_feedback("资产上线 -%s 算力币" % _format_integer_value(int(result.get("cost", 0))))
		else:
			_show_floating_feedback("提现到账 +%d 星穹" % int(result.get("gold", 0)))
	_clear_pending_transaction()
	_rebuild_assets()


func _on_balance_changed(balance: int, _delta: int) -> void:
	if not visible:
		return
	_animate_balance_to(balance)


func _on_production_settled(earned: int, _settled_seconds: int) -> void:
	## 每次真实产出结算都在左上余额区生成一次上升淡出收益文字，交易到账不会误触发。
	if not visible or earned <= 0:
		return
	_show_floating_feedback("+%s" % _format_integer_value(earned))


func _on_production_changed(_production: int) -> void:
	_refresh_production()
	_refresh_buffs()
	_queue_assets_rebuild()


func _on_assets_changed() -> void:
	_queue_assets_rebuild()


func _queue_assets_rebuild() -> void:
	## 合并资产卡片重建；参照仓库面板模式，同帧内 assets_changed 与 production_changed 多次触发只执行一次重建。
	if _assets_rebuild_queued:
		return
	_assets_rebuild_queued = true
	call_deferred("_flush_queued_assets_rebuild")


func _flush_queued_assets_rebuild() -> void:
	## 执行单次资产卡片重建；期间若已发生交易触发的直接重建，标志会被消化并跳过重复工作。
	if not _assets_rebuild_queued:
		return
	_rebuild_assets()


func _on_ui_style_changed(_style_id: String) -> void:
	## UI 风格切换后立即重建增益列表和资产卡片，刷新其中手动取色的背景、边框与文字。
	_refresh_buffs()
	_rebuild_assets()


func _animate_balance_to(target_balance: int) -> void:
	if _balance_tween != null and _balance_tween.is_valid():
		_balance_tween.kill()
	_balance_tween = create_tween()
	_balance_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_balance_tween.tween_method(_set_displayed_balance, _displayed_balance, float(target_balance), balance_tween_duration_seconds)


func _set_displayed_balance(value: float) -> void:
	_displayed_balance = value
	_refresh_balance_text()


func _show_floating_feedback(message: String) -> void:
	if _floating_feedback_layer == null or message.is_empty():
		return
	# 浮动提示；从状态栏底部向上移动并淡出，结束后自动释放。
	var label: Label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.32, 1.0, 0.58, 1.0))
	label.position = Vector2(0.0, 16.0)
	_floating_feedback_layer.add_child(label)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", -8.0, 0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(label.queue_free)


func _animate_cards_in() -> void:
	if _asset_container == null:
		return
	for child in _asset_container.get_children():
		if not (child is Control):
			continue
		# 卡片控件；从轻微缩小和半透明状态恢复到正常显示。
		var card: Control = child as Control
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.97, 0.97)
		card.modulate.a = 0.35
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", Vector2.ONE, card_transition_duration_seconds)
		tween.tween_property(card, "modulate:a", 1.0, card_transition_duration_seconds)


func _play_startup_animation(card: Control) -> void:
	card.pivot_offset = card.size * 0.5
	card.modulate = Color(0.45, 0.48, 0.52, 0.45)
	card.scale = Vector2(0.94, 0.94)
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate", Color.WHITE, asset_startup_tween_duration_seconds)
	tween.tween_property(card, "scale", Vector2.ONE, asset_startup_tween_duration_seconds)


func _show_message(message: String) -> void:
	_message_dialog.present_information("矿场提示", message)


func _close_panel() -> void:
	_last_visible_balance = _get_real_balance()
	visible = false
	set_process(false)
	_dialog_action = ""
	_dialog_asset_id = ""
	_pending_quantity = 0
	if _service != null and _service.has_method("set_panel_open"):
		_service.call("set_panel_open", false)
	closed.emit()


func _get_real_balance() -> int:
	return int(_service.call("get_balance")) if _service != null and _service.has_method("get_balance") else 0


func _format_integer_value(value: int) -> String:
	if _show_exact_values:
		return str(value)
	# 绝对值；决定 K、M、B 单位，负号在格式化结果中由原值自然保留。
	var absolute_value: int = absi(value)
	if absolute_value >= 1000000000:
		return "%.2fB" % (float(value) / 1000000000.0)
	if absolute_value >= 1000000:
		return "%.2fM" % (float(value) / 1000000.0)
	if absolute_value >= 10000:
		return "%.2fK" % (float(value) / 1000.0)
	return str(value)


func _on_exact_value_toggled(enabled: bool) -> void:
	_show_exact_values = enabled
	# 显示格式切换会改变同一整数余额的缩写文本；重置渲染缓存确保守卫不拦截本次重建。
	_last_rendered_balance = -1
	_refresh_balance_text()
	_refresh_production()
	_rebuild_assets()


func _get_asset_definition(asset_id: String) -> Dictionary:
	## 从服务公开定义中查找指定资产；返回副本，UI 不修改静态配置。
	var definitions: Array = _service.call("get_asset_definitions") as Array if _service != null and _service.has_method("get_asset_definitions") else []
	for raw_definition in definitions:
		var definition: Dictionary = raw_definition as Dictionary
		if str(definition.get("id", "")) == asset_id:
			return definition
	return {}


func _get_contract_definition(contract_id: String) -> Dictionary:
	## 从服务公开定义中查找指定合同类型；返回副本，UI 不修改静态配置。
	var definitions: Array = _service.call("get_contract_definitions") as Array if _service != null and _service.has_method("get_contract_definitions") else []
	for raw_definition in definitions:
		var definition: Dictionary = raw_definition as Dictionary
		if str(definition.get("id", "")) == contract_id:
			return definition
	return {}


func _refresh_overclock_button() -> void:
	## 按超频快照刷新按钮文案与可用状态；文本和状态都未变化时不写入控件属性。
	if _overclock_button == null or _service == null or not _service.has_method("get_overclock_snapshot"):
		return
	# 超频状态快照；包含生效、散热剩余时间与可用标志。
	var snapshot: Dictionary = _service.call("get_overclock_snapshot") as Dictionary
	# 目标按钮文案；三种状态分别为可用、超频进行中和散热冷却中。
	var button_text: String = "超频 ×1.5（300秒）"
	# 目标禁用状态；超频进行中与散热期间都不可再次点击。
	var button_disabled: bool = false
	if bool(snapshot.get("active", false)):
		button_text = "超频中 %s" % _format_duration(float(snapshot.get("remaining_seconds", 0.0)))
		button_disabled = true
	elif float(snapshot.get("cooldown_remaining_seconds", 0.0)) > 0.0:
		button_text = "散热中 %s" % _format_duration(float(snapshot.get("cooldown_remaining_seconds", 0.0)))
		button_disabled = true
	if button_text == _last_overclock_button_text and _overclock_button.disabled == button_disabled:
		return
	_last_overclock_button_text = button_text
	_overclock_button.text = button_text
	_overclock_button.disabled = button_disabled


func _refresh_contract_countdown() -> void:
	## 按进行中合同快照刷新倒计时标签；标签只在合同页存在进行中合同时有效。
	if _contract_countdown_label == null or not is_instance_valid(_contract_countdown_label):
		return
	if _service == null or not _service.has_method("get_active_contract_snapshot"):
		return
	# 进行中合同快照；为空表示合同刚完成，页面重建由合同状态信号负责。
	var snapshot: Dictionary = _service.call("get_active_contract_snapshot") as Dictionary
	if snapshot.is_empty():
		return
	# 目标倒计时文本；按剩余整数秒生成，未变化时跳过标签重写。
	var countdown_text: String = "剩余在线 %s" % _format_duration(float(snapshot.get("remaining_seconds", 0.0)))
	if countdown_text == _last_contract_countdown_text:
		return
	_last_contract_countdown_text = countdown_text
	_contract_countdown_label.text = countdown_text


func _on_contract_changed() -> void:
	## 合同签订、完成或异常回退后重建当前页面；非合同页重建同样安全，只刷新资产卡片。
	_queue_assets_rebuild()


func _on_contract_completed(gold_amount: int) -> void:
	## 合同到期交付回调；面板可见时播放到账反馈，实际星穹已由服务直接发放。
	if not visible:
		return
	_show_floating_feedback("合同交付 +%d 星穹" % gold_amount)


func _format_hour_minute_duration(total_seconds: int) -> String:
	## 把秒数格式化为“X小时X分”样式的中文时长；用于合同时长与离线报告，不用于逐秒倒计时。
	if total_seconds < 60:
		return "%d秒" % maxi(total_seconds, 0)
	# 完整小时数；离线报告最长展示到数十小时，不换算为天。
	var hours: int = total_seconds / 3600
	# 剩余分钟数；不足 1 分钟的秒数直接舍去，保持报告文本简洁。
	var minutes: int = (total_seconds % 3600) / 60
	if hours <= 0:
		return "%d分钟" % minutes
	if minutes <= 0:
		return "%d小时" % hours
	return "%d小时%d分" % [hours, minutes]


func _build_transaction_confirmation_message() -> String:
	## 构建股市同款二次确认正文；金额使用矿场服务公开公式，确认后服务仍会最终复核。
	var quantity: int = maxi(_pending_quantity, 1)
	if _dialog_action == ACTION_RECHARGE:
		return "充值 %d 星穹\n到账：%s 算力币\n当前星穹：%d\n确认后立即同步写入两份存档" % [quantity, _format_integer_value(quantity * 10000), int(_global_inventory.call("get_coins"))]
	if _dialog_action == ACTION_WITHDRAW:
		var cost: int = int(_service.call("get_withdrawal_cost", quantity))
		return "提现到账：%d 星穹\n需要：%s 算力币\n手续费：%s 算力币\n当前余额：%s 算力币" % [quantity, _format_integer_value(cost), _format_integer_value(cost - quantity * 10000), _format_integer_value(_get_real_balance())]
	if _dialog_action == ACTION_CONTRACT:
		# 合同定义与锁定成本；均按服务当前公式计算，签订时服务仍会最终复核余额与占用。
		var contract_definition: Dictionary = _get_contract_definition(_dialog_asset_id)
		var locked_cost: int = int(_service.call("get_contract_cost", _dialog_asset_id, quantity)) if _service.has_method("get_contract_cost") else 0
		return "%s\n到期到账：%d 星穹\n立即锁定：%s 算力币\n在线 %s 后自动交付，中途不可撤销" % [str(contract_definition.get("name", "算力合同")), quantity, _format_integer_value(locked_cost), _format_hour_minute_duration(int(contract_definition.get("duration_seconds", 0)))]
	if _dialog_action == ACTION_OVERCLOCK:
		return "超频后 300 秒内全部产出 ×1.5\n结束后进入 1800 秒散热冷却\n超频免费且仅消耗在线时间"
	if _dialog_action == ACTION_UPGRADE:
		# 固件升级预览；展示等级跨度、费用与升级后的本类产出，费用按官方价乘当前等级倍率。
		var upgrade_definition: Dictionary = _get_asset_definition(_dialog_asset_id)
		var upgrade_level: int = int(_service.call("get_asset_upgrade_level", _dialog_asset_id)) if _service.has_method("get_asset_upgrade_level") else 0
		var upgrade_cost: int = int(_service.call("get_asset_upgrade_cost", _dialog_asset_id)) if _service.has_method("get_asset_upgrade_cost") else 0
		return "%s 固件 Lv.%d→%d\n需要：%s 算力币\n本类产出加成：+10%%（升级后共 +%d%%）\n固件永久生效，出售资产不回退等级" % [str(upgrade_definition.get("name", "算力资产")), upgrade_level, upgrade_level + 1, _format_integer_value(upgrade_cost), (upgrade_level + 1) * 10]
	var definition: Dictionary = _get_asset_definition(_dialog_asset_id)
	var asset_name: String = str(definition.get("name", "算力资产"))
	if _dialog_action == ACTION_SELL:
		var returned: int = int(_service.call("get_asset_sell_return", _dialog_asset_id, quantity))
		return "%s %d 台\n返还：%s 算力币\n出售后持有：%d 台\n总产出将立即降低" % [asset_name, quantity, _format_integer_value(returned), int(_service.call("get_asset_quantity", _dialog_asset_id)) - quantity]
	var total_cost: int = int(definition.get("price", 0)) * quantity
	return "%s %d 台\n需要：%s 算力币\n购买后持有：%d 台\n下一结算周期开始产出" % [asset_name, quantity, _format_integer_value(total_cost), int(_service.call("get_asset_quantity", _dialog_asset_id)) + quantity]


func _get_action_display_name() -> String:
	## 返回当前矿场交易中文名称，统一用于确认窗口标题和按钮。
	if _dialog_action == ACTION_RECHARGE:
		return "充值"
	if _dialog_action == ACTION_WITHDRAW:
		return "提现"
	if _dialog_action == ACTION_SELL:
		return "出售"
	if _dialog_action == ACTION_CONTRACT:
		return "签订"
	if _dialog_action == ACTION_UPGRADE:
		return "升级"
	if _dialog_action == ACTION_OVERCLOCK:
		return "超频"
	return "购买"


func _clear_pending_transaction() -> void:
	_pending_quantity = 0
	_dialog_action = ""
	_dialog_asset_id = ""


func _format_duration(seconds: float) -> String:
	# 完整剩余秒数；向上取整避免 0.1 秒时提前显示 00:00。
	var total_seconds: int = maxi(int(ceil(seconds)), 0)
	# 分钟部分；骇入增益可超过 60 分钟，因此不对分钟取模。
	var minutes: int = total_seconds / 60
	# 秒部分；固定显示两位，形成稳定倒计时宽度。
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]
