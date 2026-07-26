extends PanelContainer
class_name StockMarketPanel

## 股市面板负责行情展示、数量选择、交易确认和持仓摘要。
## 行情公式、随机事件、星穹与持仓持久化分别由 StockMarketService 和 GlobalInventory 处理。

signal closed

## 通用物品卡片脚本；股票和持仓通过空资源展示模式复用标准 160×72 卡片视觉与交互动效。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 行情图脚本；只接收价格历史并绘制折线，不持有服务引用。
const STOCK_CHART_CONTROL_SCRIPT: Script = preload("res://scripts/ui/stock_chart_control.gd")
## 数量选择弹窗脚本；复用出售数量滑条和数字输入交互。
const SELL_QUANTITY_DIALOG_SCRIPT: Script = preload("res://scripts/ui/sell_quantity_dialog.gd")
## 通用确认弹窗脚本；买入和卖出最终确认统一显示数量、单价、手续费和结算金额。
const COMMON_CONFIRMATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/common_confirmation_dialog.gd")
## 证券币转账弹窗脚本；负责整数星穹充值和整数证券币提现的金额输入与结果预览。
const SECURITIES_TRANSFER_DIALOG_SCRIPT: Script = preload("res://scripts/ui/securities_transfer_dialog.gd")
## 杠杆开仓弹窗脚本；负责方向、倍数与整数保证金输入和费用预览，最终成交由股市服务原子校验。
const LEVERAGE_POSITION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/leverage_position_dialog.gd")
## 记录列表弹窗脚本；交易历史记录与通知中心共用同一滚动文本列表窗口。
const STOCK_RECORD_LIST_DIALOG_SCRIPT: Script = preload("res://scripts/ui/stock_record_list_dialog.gd")
## 全局窗口样式指南；为股市基准界面补充统一按钮、输入、滚动和内部面板主题。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 标准股票卡片尺寸；固定 160×72，与项目物品卡片规范一致。
const CARD_SIZE: Vector2 = Vector2(160.0, 72.0)
## 面板微行情刷新来源标识；与 StockMarketService.REFRESH_DISPLAY 保持一致，用于跳过每秒的大盘缓存更新。
const REFRESH_SOURCE_DISPLAY: String = "display"
## 面板目标尺寸；默认 1040×620，宿主应按该尺寸居中放置。
## 实际高度补充；交易区纵向内容可能把最小高度撑到超过该值，宿主须把面板生长方向设为双向以保持屏幕居中。
@export var panel_minimum_size: Vector2 = Vector2(1040.0, 620.0)
## 事件提示显示时长；默认 3 秒，结束后线性淡出。
@export_range(0.5, 10.0, 0.1) var event_message_duration_seconds: float = 3.0
## 股票二次确认窗口高度；默认 270 像素，稳定容纳七行实时成交信息并避免首次自动布局异常，运行时无需动态修改。
@export_range(220, 420, 1) var trade_confirmation_dialog_height: int = 270

## 股市服务；提供行情快照、报价和交易请求，缺失时面板保留关闭能力并禁用交易。
var _stock_market_service: Node
## 全局库存服务；提供星穹余额和持仓快照，缺失时持仓区显示为空。
var _global_inventory: Node
## 当前选中股票标识；默认选择目录中的第一只股票。
var _selected_stock_id: String = "quantum_arms"
## 股票列表控件；键为股票标识，值为承载标准 ItemCardView 的可点击按钮。
var _stock_buttons: Dictionary = {}
## 持仓卡片容器；行情或交易变化时清空并按五只股票稳定顺序重建。
## 原位刷新补充：当前容器中的卡片按股票标识长期复用，行情变化只更新文本和视觉状态，不再清空重建。
var _holdings_container: HBoxContainer
## 持仓卡片按钮表；键为稳定股票标识，值为长期复用的透明按钮宿主，数量归零时只隐藏不释放。
var _holding_buttons: Dictionary = {}
## 空持仓提示标签；默认创建后按可见持仓数量切换，不与持仓卡片反复销毁重建。
var _empty_holdings_label: Label
## 当前股票标题；显示名称和对应玩法模块。
var _selected_title_label: Label
## 当前行情摘要；显示单价、最近涨跌幅和当前大盘状态。
var _selected_summary_label: RichTextLabel
## 行情折线图；显示最近 30 次刷新价格。
var _chart: Control
## 星穹余额标签；监听 GlobalInventory.coins_changed 后即时刷新。
var _coins_label: Label
## 证券币充值按钮；永久星穹不足时禁用，点击后打开整数充值输入窗口。
var _deposit_button: Button
## 证券币提现按钮；余额不足以产生至少 1 星穹到账时禁用，点击后打开整数提现输入窗口。
var _withdraw_button: Button
## 当前持仓摘要；显示股数、成本价和浮动盈亏。
var _position_label: RichTextLabel
## 买入按钮；无可买数量时禁用，点击后先打开数量选择弹窗。
var _buy_button: Button
## 卖出按钮；无当前持仓时禁用，点击后先打开数量选择弹窗。
var _sell_button: Button
## 杠杆开仓按钮；选中股票已有杠杆仓位或余额不足最低保证金时禁用，点击后打开杠杆开仓弹窗。
var _leverage_open_button: Button
## 杠杆平仓按钮；选中股票没有杠杆仓位时禁用，点击后打开实时刷新的平仓二次确认。
var _leverage_close_button: Button
## 杠杆持仓卡片按钮表；键为稳定股票标识，值为长期复用的透明按钮宿主，无仓位时只隐藏不释放。
var _leverage_buttons: Dictionary = {}
## 杠杆开仓弹窗；同一实例复用全部股票的开仓输入，实际建仓由股市服务执行。
## 加仓复用补充；选中股票已有杠杆仓位时同一弹窗实例切换为加仓模式，追加保证金由股市服务合并。
var _leverage_dialog: LeveragePositionDialog
## 通知按钮；位于标题栏关闭按钮左侧，点击后打开强平等重要通知的通知中心窗口。
var _notification_button: Button
## 历史记录按钮；位于底部“全部持仓”标题上方，点击后打开交易历史记录窗口。
var _trade_history_button: Button
## 记录列表弹窗；交易历史与通知中心复用同一实例，按打开入口填充不同标题与内容。
var _record_list_dialog: StockRecordListDialog
## 记录弹窗当前展示模式；取值 trade、notification 或空字符串，用于新记录到达时只刷新对应视图。
var _record_dialog_mode: String = ""
## 顶部事件滚动提示；收到事件信号后显示并在 3 秒内线性淡出。
var _event_banner: Label
## 数量选择弹窗；同一实例在买入和卖出模式间复用。
var _quantity_dialog: SellQuantityDialog
## 最终交易确认弹窗；确认后调用服务执行原子交易。
var _confirmation_dialog: CommonConfirmationDialog
## 证券币转账弹窗；同一实例复用充值和提现模式，实际资产变更由股市服务执行。
var _securities_transfer_dialog: SecuritiesTransferDialog
## 当前待确认交易类型；取值 buy、sell 或空字符串。
var _pending_trade_type: String = ""
## 当前待确认股票标识；数量选择时缓存，避免玩家切换卡片后交易目标变化。
var _pending_stock_id: String = ""
## 当前待确认交易数量；取值至少为 1，确认弹窗显示与执行共同使用。
var _pending_quantity: int = 0
## 当前待确认整数成交价；打开数量弹窗时锁定，避免每秒微行情导致确认金额与最终结算不一致。
## 实时交易规则；旧锁价说明仅保留历史注释兼容，当前值会随行情刷新，仅代表弹窗最近一次展示价而不锁定成交价。
## 证券币成交精度补充；该变量当前保存两位小数证券币实时价，旧整数类型说明仅为历史兼容保留。
var _pending_unit_price: float = 0.0
## 事件提示补间；新事件到来时停止旧补间并从完全可见重新开始。
var _event_tween: Tween
## 全量刷新是否已排队；默认 false，参照仓库面板模式把同帧多路信号合并为一次统一刷新。
var _refresh_queued: bool = false
## 调试设置服务缓存；启动时查找一次，避免每秒行情刷新反复 get_node_or_null 查询。
var _debug_settings: Node
## 股票静态目录缓存；启动时从服务深复制一份名称与模块信息，每秒刷新不再重复请求静态副本。
var _stock_definitions_cache: Dictionary = {}
## 大盘显示名称缓存；默认震荡市，只在首次打开、切换选中股票、非微行情刷新与事件触发时读取完整市场快照更新。
var _cached_market_state_name: String = "震荡市"


func _ready() -> void:
	custom_minimum_size = panel_minimum_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	_stock_market_service = get_tree().root.get_node_or_null("StockMarketService")
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	_connect_services()
	_refresh_market_snapshot_cache()
	_refresh_all()
	_show_active_event_if_available()


func _exit_tree() -> void:
	set_market_display_active(false)


func set_market_display_active(active: bool) -> void:
	if _stock_market_service != null and _stock_market_service.has_method("set_market_panel_open"):
		_stock_market_service.call("set_market_panel_open", active)


func _build_interface() -> void:
	# 面板主体样式；统一取样式指南主窗口样式并自动登记，UI 风格切换时立即刷新背景与描边。
	UI_STYLE_GUIDE.apply_window_panel(self)
	# 外层边距；为标题、三栏主体和持仓区提供统一安全留白。
	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_top", 12)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_bottom", 14)
	add_child(outer_margin)
	# 根内容容器；从上到下排列标题、行情主体、持仓标题和持仓列表。
	var root_content: VBoxContainer = VBoxContainer.new()
	root_content.add_theme_constant_override("separation", 9)
	outer_margin.add_child(root_content)
	# 标题行；横向承载面板标题、事件提示和关闭按钮。
	var title_row: HBoxContainer = HBoxContainer.new()
	root_content.add_child(title_row)
	# 面板标题；固定显示股市世界观名称并占据剩余横向空间。
	var title_label: Label = Label.new()
	title_label.text = "量子证券交易中心"
	UI_STYLE_GUIDE.apply_title_label(title_label, 25)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	_event_banner = Label.new()
	_event_banner.custom_minimum_size = Vector2(420.0, 0.0)
	_event_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_banner.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30, 1.0))
	_event_banner.visible = false
	title_row.add_child(_event_banner)
	# 标题栏通知按钮；位于关闭按钮左侧，打开通知中心查看强平等重要通知记录。
	_notification_button = Button.new()
	_notification_button.text = "通知"
	_notification_button.custom_minimum_size = Vector2(90.0, 36.0)
	_notification_button.pressed.connect(_on_notification_button_pressed)
	title_row.add_child(_notification_button)
	# 标题栏关闭按钮；关闭面板但不停止后台行情刷新。
	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(90.0, 36.0)
	close_button.pressed.connect(_on_close_pressed)
	title_row.add_child(close_button)
	# 主体三栏；左侧股票列表、中部行情图、右侧交易区固定在同一行。
	var main_row: HBoxContainer = HBoxContainer.new()
	main_row.custom_minimum_size = Vector2(0.0, 365.0)
	main_row.add_theme_constant_override("separation", 12)
	root_content.add_child(main_row)
	# 股票列表容器；固定 170 像素宽，纵向容纳五张 160×72 卡片。
	var stock_list: VBoxContainer = VBoxContainer.new()
	stock_list.custom_minimum_size = Vector2(170.0, 0.0)
	stock_list.add_theme_constant_override("separation", 2)
	main_row.add_child(stock_list)
	if _stock_market_service != null and _stock_market_service.has_method("get_stock_definitions"):
		# 股票目录；由服务返回静态副本，UI 只据此建立稳定标识按钮。
		var definitions: Dictionary = _stock_market_service.call("get_stock_definitions") as Dictionary
		_stock_definitions_cache = definitions
		for stock_id in definitions.keys():
			# 单只股票按钮；内部承载标准卡片并绑定当前稳定股票标识。
			var stock_button: Button = _create_stock_card_button(str(stock_id))
			stock_list.add_child(stock_button)
	# 中部行情列；扩展填满左侧列表和右侧交易区之间的剩余空间。
	var center_column: VBoxContainer = VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 6)
	main_row.add_child(center_column)
	_selected_title_label = Label.new()
	_selected_title_label.add_theme_font_size_override("font_size", 18)
	center_column.add_child(_selected_title_label)
	_selected_summary_label = RichTextLabel.new()
	_selected_summary_label.bbcode_enabled = true
	_selected_summary_label.fit_content = true
	_selected_summary_label.custom_minimum_size = Vector2(0.0, 30.0)
	_selected_summary_label.scroll_active = false
	center_column.add_child(_selected_summary_label)
	_chart = STOCK_CHART_CONTROL_SCRIPT.new() as Control
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_child(_chart)
	# 交易区面板；固定 220 像素宽，隔离余额、持仓摘要和买卖按钮。
	var trade_panel: PanelContainer = PanelContainer.new()
	trade_panel.custom_minimum_size = Vector2(220.0, 0.0)
	main_row.add_child(trade_panel)
	# 交易区边距；避免文字和按钮贴住面板边缘。
	var trade_margin: MarginContainer = MarginContainer.new()
	trade_margin.add_theme_constant_override("margin_left", 12)
	trade_margin.add_theme_constant_override("margin_top", 12)
	trade_margin.add_theme_constant_override("margin_right", 12)
	trade_margin.add_theme_constant_override("margin_bottom", 12)
	trade_panel.add_child(trade_margin)
	# 交易区内容；纵向排列标题、余额、持仓摘要、留白和买卖按钮。
	var trade_content: VBoxContainer = VBoxContainer.new()
	trade_content.add_theme_constant_override("separation", 12)
	trade_margin.add_child(trade_content)
	# 交易区标题；明确右栏职责并保持居中。
	var trade_title: Label = Label.new()
	trade_title.text = "交易区"
	trade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trade_title.add_theme_font_size_override("font_size", 18)
	trade_content.add_child(trade_title)
	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trade_content.add_child(_coins_label)
	# 证券币兑换按钮行；充值把整数星穹 1:1 转入，提现把整数证券币扣费后兑换为整数星穹。
	var securities_transfer_row: HBoxContainer = HBoxContainer.new()
	securities_transfer_row.add_theme_constant_override("separation", 6)
	trade_content.add_child(securities_transfer_row)
	# 充值按钮；没有永久星穹时禁用，防止打开无有效金额的输入窗口。
	_deposit_button = Button.new()
	_deposit_button.name = "DepositButton"
	_deposit_button.text = "充值"
	_deposit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deposit_button.pressed.connect(_on_securities_deposit_pressed)
	securities_transfer_row.add_child(_deposit_button)
	# 提现按钮；证券币整数部分不足 1 时禁用，小数余额继续保留在证券账户。
	_withdraw_button = Button.new()
	_withdraw_button.name = "WithdrawButton"
	_withdraw_button.text = "提现"
	_withdraw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_withdraw_button.pressed.connect(_on_securities_withdrawal_pressed)
	securities_transfer_row.add_child(_withdraw_button)
	_position_label = RichTextLabel.new()
	_position_label.bbcode_enabled = true
	_position_label.fit_content = true
	_position_label.scroll_active = false
	_position_label.custom_minimum_size = Vector2(0.0, 100.0)
	trade_content.add_child(_position_label)
	# 交易区弹性留白；把买入和卖出按钮稳定推到右栏底部。
	var trade_spacer: Control = Control.new()
	trade_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trade_content.add_child(trade_spacer)
	_buy_button = Button.new()
	_buy_button.text = "买入"
	_buy_button.custom_minimum_size = Vector2(0.0, 42.0)
	UI_STYLE_GUIDE.apply_primary_button(_buy_button)
	_buy_button.pressed.connect(_on_buy_pressed)
	trade_content.add_child(_buy_button)
	_sell_button = Button.new()
	_sell_button.text = "卖出"
	_sell_button.custom_minimum_size = Vector2(0.0, 42.0)
	UI_STYLE_GUIDE.apply_danger_button(_sell_button)
	_sell_button.pressed.connect(_on_sell_pressed)
	trade_content.add_child(_sell_button)
	# 杠杆按钮行；开仓与平仓并排放在现货买卖下方，共用交易区底部布局。
	var leverage_row: HBoxContainer = HBoxContainer.new()
	leverage_row.add_theme_constant_override("separation", 6)
	trade_content.add_child(leverage_row)
	# 杠杆开仓按钮；使用普通主题样式与主操作按钮区分，避免玩家误认为常规交易。
	_leverage_open_button = Button.new()
	_leverage_open_button.text = "杠杆开仓"
	_leverage_open_button.custom_minimum_size = Vector2(0.0, 42.0)
	_leverage_open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leverage_open_button.pressed.connect(_on_leverage_open_pressed)
	leverage_row.add_child(_leverage_open_button)
	# 杠杆平仓按钮；有仓位时才可用，点击后打开实时刷新的平仓确认窗口。
	_leverage_close_button = Button.new()
	_leverage_close_button.text = "杠杆平仓"
	_leverage_close_button.custom_minimum_size = Vector2(0.0, 42.0)
	_leverage_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leverage_close_button.pressed.connect(_on_leverage_close_pressed)
	leverage_row.add_child(_leverage_close_button)
	# 持仓区标题；位于主体与横向持仓列表之间。
	var holdings_title: Label = Label.new()
	holdings_title.text = "全部持仓"
	holdings_title.add_theme_font_size_override("font_size", 18)
	root_content.add_child(holdings_title)
	# 历史记录按钮；悬浮显示在“全部持仓”标题上方的既有空白区，打开交易历史窗口查看买卖、杠杆与资金转账记录。
	# 布局无侵入补充；按钮挂载在标题标签下作为手动定位子控件，不占用竖向布局行，面板整体尺寸与原有布局保持不变。
	_trade_history_button = Button.new()
	_trade_history_button.text = "历史记录"
	_trade_history_button.size = Vector2(110.0, 30.0)
	# 悬浮位置；相对标题左上角向上偏移 36 像素，与标题保持 6 像素间距并落在左列股票卡下方的空白区域。
	_trade_history_button.position = Vector2(0.0, -36.0)
	_trade_history_button.pressed.connect(_on_trade_history_button_pressed)
	holdings_title.add_child(_trade_history_button)
	# 持仓横向滚动容器；五只股票同时持仓时仍可访问全部标准卡片。
	var holdings_scroll: ScrollContainer = ScrollContainer.new()
	holdings_scroll.custom_minimum_size = Vector2(0.0, 92.0)
	holdings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	holdings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_content.add_child(holdings_scroll)
	# 持仓悬浮安全边距；四周预留标准 4 像素空间，避免滚动容器裁剪 1.03 倍放大后的卡牌边缘。
	var holdings_margin: MarginContainer = MarginContainer.new()
	holdings_margin.add_theme_constant_override("margin_left", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	holdings_margin.add_theme_constant_override("margin_top", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	holdings_margin.add_theme_constant_override("margin_right", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	holdings_margin.add_theme_constant_override("margin_bottom", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	holdings_scroll.add_child(holdings_margin)
	_holdings_container = HBoxContainer.new()
	_holdings_container.add_theme_constant_override("separation", 8)
	holdings_margin.add_child(_holdings_container)
	_empty_holdings_label = Label.new()
	_empty_holdings_label.text = "当前没有股票持仓"
	_empty_holdings_label.custom_minimum_size = Vector2(260.0, 72.0)
	_empty_holdings_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_holdings_container.add_child(_empty_holdings_label)
	# 持仓卡片预创建；按股票目录稳定顺序先建现货卡片再建杠杆卡片，保证两类卡片顺序不受持有先后影响。
	for holding_stock_id in _stock_definitions_cache.keys():
		# 预创建的现货持仓按钮；默认隐藏，首次刷新按实际持仓切换可见性。
		var prepared_holding_button: Button = _create_holding_card_button(str(holding_stock_id))
		prepared_holding_button.visible = false
	for leverage_stock_id in _stock_definitions_cache.keys():
		# 预创建的杠杆仓位按钮；默认隐藏，首次刷新按实际仓位切换可见性。
		var prepared_leverage_button: Button = _create_leverage_card_button(str(leverage_stock_id))
		prepared_leverage_button.visible = false
	_quantity_dialog = SELL_QUANTITY_DIALOG_SCRIPT.new() as SellQuantityDialog
	_quantity_dialog.connect("quantity_confirmed", Callable(self, "_on_trade_quantity_confirmed"))
	_quantity_dialog.canceled.connect(_on_trade_canceled)
	add_child(_quantity_dialog)
	_confirmation_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_confirmation_dialog.confirmed.connect(_on_trade_confirmed)
	_confirmation_dialog.canceled.connect(_on_trade_canceled)
	add_child(_confirmation_dialog)
	_securities_transfer_dialog = SECURITIES_TRANSFER_DIALOG_SCRIPT.new() as SecuritiesTransferDialog
	_securities_transfer_dialog.connect("transfer_confirmed", Callable(self, "_on_securities_transfer_confirmed"))
	add_child(_securities_transfer_dialog)
	_leverage_dialog = LEVERAGE_POSITION_DIALOG_SCRIPT.new() as LeveragePositionDialog
	_leverage_dialog.connect("leverage_confirmed", Callable(self, "_on_leverage_position_confirmed"))
	_leverage_dialog.canceled.connect(_on_trade_canceled)
	add_child(_leverage_dialog)
	_record_list_dialog = STOCK_RECORD_LIST_DIALOG_SCRIPT.new() as StockRecordListDialog
	# 记录弹窗关闭回调；确认与取消都只清空展示模式，不影响任何交易挂起状态。
	_record_list_dialog.confirmed.connect(_on_record_dialog_closed)
	_record_list_dialog.canceled.connect(_on_record_dialog_closed)
	add_child(_record_list_dialog)


func _connect_services() -> void:
	if _stock_market_service != null:
		if _stock_market_service.has_signal("market_changed"):
			# 行情变化信号；改为置位合并标志后延迟统一刷新，一次交易触发的多路信号只做一次全量刷新。
			_stock_market_service.connect("market_changed", Callable(self, "_queue_refresh_all"))
		if _stock_market_service.has_signal("market_refreshed"):
			# 行情刷新来源信号；非微行情刷新可能切换大盘或消耗事件，届时更新一次大盘名称缓存。
			_stock_market_service.connect("market_refreshed", Callable(self, "_on_market_refreshed"))
		if _stock_market_service.has_signal("event_announced"):
			_stock_market_service.connect("event_announced", Callable(self, "_on_event_announced"))
		if _stock_market_service.has_signal("securities_balance_changed"):
			_stock_market_service.connect("securities_balance_changed", Callable(self, "_on_securities_balance_changed"))
		if _stock_market_service.has_signal("leverage_positions_changed"):
			# 杠杆仓位变化信号；开仓、平仓与强制平仓后与其他资产信号共享同帧一次统一刷新。
			_stock_market_service.connect("leverage_positions_changed", Callable(self, "_queue_refresh_all"))
		if _stock_market_service.has_signal("leverage_position_closed"):
			# 杠杆仓位关闭信号；主动与强制平仓统一在顶部横幅展示结算说明。
			_stock_market_service.connect("leverage_position_closed", Callable(self, "_on_leverage_position_closed"))
		if _stock_market_service.has_signal("trade_records_changed"):
			# 交易记录变化信号；交易历史窗口打开期间实时追加最新记录。
			_stock_market_service.connect("trade_records_changed", Callable(self, "_on_trade_records_changed"))
		if _stock_market_service.has_signal("notification_records_changed"):
			# 通知记录变化信号；通知中心窗口打开期间实时追加最新通知。
			_stock_market_service.connect("notification_records_changed", Callable(self, "_on_notification_records_changed"))
	if _global_inventory != null:
		if _global_inventory.has_signal("coins_changed"):
			_global_inventory.connect("coins_changed", Callable(self, "_queue_refresh_all"))
		if _global_inventory.has_signal("stock_holdings_changed"):
			_global_inventory.connect("stock_holdings_changed", Callable(self, "_queue_refresh_all"))
	# 调试信息服务；开关变化后立即切换股票卡片和行情摘要中的开发计算字段。
	var debug_settings: Node = get_tree().root.get_node_or_null("DebugSettings")
	_debug_settings = debug_settings
	if debug_settings != null and debug_settings.has_signal("debug_information_visibility_changed"):
		debug_settings.connect("debug_information_visibility_changed", Callable(self, "_on_debug_information_visibility_changed"))


func _on_debug_information_visibility_changed(_visible: bool) -> void:
	_refresh_all()


func _on_securities_balance_changed(_balance: float) -> void:
	## 证券币账户变化后刷新余额、买入上限与已打开交易弹窗，不直接读取信号参数作为唯一状态源。
	## 合并刷新补充：改为置位合并标志，与同帧其他行情或资产信号共享一次统一全量刷新。
	_queue_refresh_all()


func _queue_refresh_all() -> void:
	## 合并全量刷新入口；参照仓库面板模式，同帧内 market_changed、coins_changed、stock_holdings_changed 与 securities_balance_changed 只触发一次刷新。
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_queued_refresh")


func _flush_queued_refresh() -> void:
	## 执行单次合并全量刷新；期间若已发生交易或选中切换触发的直接刷新，标志会被消化并跳过重复工作。
	if not _refresh_queued:
		return
	_refresh_all()


func _on_market_refreshed(refresh_source: String) -> void:
	## 行情刷新来源回调；每秒微行情不更新大盘缓存，正式结算与局外刷新才重新读取完整市场快照。
	if refresh_source == REFRESH_SOURCE_DISPLAY:
		return
	_refresh_market_snapshot_cache()


func _on_event_announced(message: String) -> void:
	## 随机事件回调；事件可能附带临时大盘状态，先更新大盘名称缓存，再展示既有顶部滚动提示。
	_refresh_market_snapshot_cache()
	_show_event_banner(message)


func _refresh_market_snapshot_cache() -> void:
	## 低频更新大盘显示名称缓存；深复制全市场快照的成本只在首次打开、切换选中股票、非微行情刷新与事件触发时产生。
	if _stock_market_service == null or not _stock_market_service.has_method("get_market_snapshot"):
		return
	# 全市场快照；仅在低频路径读取，每秒微行情刷新只消费缓存名称。
	var market_snapshot: Dictionary = _stock_market_service.call("get_market_snapshot") as Dictionary
	_cached_market_state_name = str(market_snapshot.get("market_state_name", "震荡市"))


func _create_stock_card_button(stock_id: String) -> Button:
	# 股票按钮宿主；自身透明，只负责鼠标、选择和标准卡片动画协议。
	var button: Button = Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_entered.connect(_on_stock_card_hovered.bind(stock_id, true))
	button.mouse_exited.connect(_on_stock_card_hovered.bind(stock_id, false))
	button.pressed.connect(_on_stock_selected.bind(stock_id))
	# 标准卡片视图；使用空资源展示模式，让顶部、价格和涨跌幅保持三行结构。
	var card: Control = ITEM_CARD_VIEW_SCRIPT.new() as Control
	card.name = "Card"
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(card)
	_stock_buttons[stock_id] = button
	return button


func _create_holding_card_button(stock_id: String) -> Button:
	## 创建一次可长期复用的持仓按钮；实时行情只更新其内部卡牌内容，避免鼠标悬浮状态随节点重建丢失。
	# 持仓按钮宿主；自身透明，只负责选择股票、鼠标悬浮和标准卡牌交互动画。
	var host: Button = Button.new()
	host.name = "Holding_%s" % stock_id
	host.custom_minimum_size = CARD_SIZE
	host.flat = true
	host.focus_mode = Control.FOCUS_NONE
	host.pressed.connect(_on_stock_selected.bind(stock_id))
	host.mouse_entered.connect(_on_holding_card_hovered.bind(host, true))
	host.mouse_exited.connect(_on_holding_card_hovered.bind(host, false))
	# 持仓标准卡牌；空资源展示模式允许股数、成本、现价和浮动盈亏按实时行情原位刷新。
	var card: Control = ITEM_CARD_VIEW_SCRIPT.new() as Control
	card.name = "Card"
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(card)
	_holding_buttons[stock_id] = host
	_holdings_container.add_child(host)
	return host


func _create_leverage_card_button(stock_id: String) -> Button:
	## 创建一次可长期复用的杠杆仓位按钮；实时行情只更新其内部卡牌内容，与现货持仓卡片共用交互协议。
	# 杠杆按钮宿主；自身透明，只负责选择股票、鼠标悬浮和标准卡牌交互动画。
	var host: Button = Button.new()
	host.name = "Leverage_%s" % stock_id
	host.custom_minimum_size = CARD_SIZE
	host.flat = true
	host.focus_mode = Control.FOCUS_NONE
	host.pressed.connect(_on_stock_selected.bind(stock_id))
	host.mouse_entered.connect(_on_holding_card_hovered.bind(host, true))
	host.mouse_exited.connect(_on_holding_card_hovered.bind(host, false))
	# 杠杆标准卡牌；空资源展示模式按实时行情原位刷新方向、倍数、盈亏和净值。
	var card: Control = ITEM_CARD_VIEW_SCRIPT.new() as Control
	card.name = "Card"
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(card)
	_leverage_buttons[stock_id] = host
	_holdings_container.add_child(host)
	return host


func _refresh_all() -> void:
	# 任何直接全量刷新都消化当前挂起的合并刷新；同帧稍后的延迟回调据此跳过重复刷新。
	_refresh_queued = false
	if _stock_market_service == null:
		_buy_button.disabled = true
		_sell_button.disabled = true
		return
	for stock_id in _stock_buttons.keys():
		_refresh_stock_card(str(stock_id))
	_refresh_selected_stock()
	_refresh_holdings()
	_refresh_pending_trade_dialog()


func _refresh_stock_card(stock_id: String) -> void:
	# 股票快照；包含静态名称、当前价格、最近涨跌和调试字段。
	# 轻量刷新补充：正式路径改用服务轻量只读接口与静态目录缓存，仅调试模式才读取深复制完整快照。
	# 股票按钮；通过稳定标识找到创建时缓存的宿主。
	var button: Button = _stock_buttons.get(stock_id) as Button
	if button == null:
		return
	# 标准卡片；负责统一三行排版、选中边框和交互动效。
	var card: Control = button.get_node_or_null("Card") as Control
	# 最近涨跌比例；正值上涨、负值下跌、零值持平。
	var change_ratio: float = float(_stock_market_service.call("get_stock_change_ratio", stock_id))
	# 当前两位小数价格；来自轻量只读接口，不复制任何行情字典。
	var current_price: float = float(_stock_market_service.call("get_stock_price", stock_id))
	# 股票静态定义缓存；提供稳定显示名称，不随每秒行情变化。
	var definition: Dictionary = _stock_definitions_cache.get(stock_id, {}) as Dictionary
	# 涨跌富文本颜色名；与强化收益着色规则一致。
	var color_name: String = "green" if change_ratio > 0.0 else ("red" if change_ratio < 0.0 else "white")
	# 卡片底部摘要；正式模式只显示涨跌幅，调试模式追加中枢和偏离。
	var detail: String = "[color=%s]%+.2f%%[/color]" % [color_name, change_ratio * 100.0]
	if _is_debug_information_visible():
		# 调试完整快照；仅调试模式读取单股深复制行情，正式玩家的每秒刷新不再复制字典。
		var snapshot: Dictionary = _stock_market_service.call("get_stock_snapshot", stock_id) as Dictionary
		# 调试卡片摘要；在标准卡片有限宽度内展示中枢与偏离率，完整字段保留在中部摘要。
		var center: float = float(snapshot.get("center", 0.0))
		# 中枢偏离率；当前价相对动态价值中枢的百分比，仅调试模式可见。
		var deviation_ratio: float = (float(snapshot.get("price", 0.0)) / center - 1.0) if center > 0.0 else 0.0
		detail += "  中枢%.1f 偏离%+.1f%%" % [center, deviation_ratio * 100.0]
	card.call("configure", null, 1, str(definition.get("name", "股票")), detail, "%.2f 证券币" % current_price)
	card.call("set_visual_state", stock_id == _selected_stock_id, false)


func _refresh_selected_stock() -> void:
	# 当前股票快照；驱动中部标题、折线、交易区和按钮可用性。
	var snapshot: Dictionary = _stock_market_service.call("get_stock_snapshot", _selected_stock_id) as Dictionary
	if snapshot.is_empty():
		return
	# 最近涨跌比例；用于中部摘要和折线颜色。
	var change_ratio: float = float(snapshot.get("last_change_ratio", 0.0))
	# 中部涨跌颜色；上涨绿色、下跌红色、持平白色。
	var color_name: String = "green" if change_ratio > 0.0 else ("red" if change_ratio < 0.0 else "white")
	_selected_title_label.text = "%s · %s" % [str(snapshot.get("name", "股票")), str(snapshot.get("module", ""))]
	# 全市场快照；提供有效大盘名称和调试运行累计进度。
	# 大盘缓存补充：每秒微行情不再深复制全市场快照，大盘名称改读低频更新的缓存，调试分支才读取完整快照。
	_selected_summary_label.text = "当前价 %.2f 证券币    [color=%s]%+.2f%%[/color]    大盘：%s" % [float(snapshot.get("price", 0.0)), color_name, change_ratio * 100.0, _cached_market_state_name]
	if _is_debug_information_visible():
		# 调试全市场快照；仅调试模式读取完整深复制，用于展示运行累计进度等开发字段。
		var market_snapshot: Dictionary = _stock_market_service.call("get_market_snapshot") as Dictionary
		# 调试中枢；取值为当前长期合理价格线，仅用于开发者验证均值回归。
		var debug_center: float = float(snapshot.get("center", 0.0))
		# 调试偏离率；当前价格相对中枢的比例，用于验证分段回归力度。
		var debug_deviation: float = (float(snapshot.get("price", 0.0)) / debug_center - 1.0) if debug_center > 0.0 else 0.0
		_selected_summary_label.text += "\n调试：中枢 %.2f · 偏离 %+.2f%% · 行为贡献 %.1f%% · 漂移 %.0f%% · 运行累计 %.0f%%" % [debug_center, debug_deviation * 100.0, float(snapshot.get("last_player_contribution_ratio", 0.0)) * 100.0, float(snapshot.get("next_drift_probability", 0.25)) * 100.0, float(market_snapshot.get("runtime_progress", 0.0)) * 100.0]
	_chart.call("configure_history", snapshot.get("history", []) as Array, int(signf(change_ratio)))
	# 当前股票持仓；缺失时按零持仓显示并禁用卖出。
	var holding: Dictionary = _get_holding(_selected_stock_id)
	# 当前持股数量；非负整数，决定卖出数量上限。
	var quantity: int = int(holding.get("quantity", 0))
	# 加权平均成本；包含历史买入手续费，用于计算真实浮动盈亏。
	var average_cost: float = float(holding.get("average_cost", 0.0))
	# 当前显示价格；保留两位小数用于每秒行情，实际成交仍由服务四舍五入为整数星穹。
	# 证券币成交规则；旧整数说明仅保留历史注释兼容，当前价和成交均直接使用两位小数证券币。
	var current_price: float = float(snapshot.get("price", 0.0))
	# 浮动盈亏金额；当前市值减持仓总成本，未持仓时为 0。
	var profit: float = (current_price - average_cost) * quantity
	# 浮动盈亏比例；以加权平均成本为分母，零成本时保持 0。
	var profit_ratio: float = (current_price / average_cost - 1.0) if average_cost > 0.0 else 0.0
	# 盈亏颜色；盈利绿色、亏损红色、持平白色。
	var profit_color: String = "green" if profit > 0.0 else ("red" if profit < 0.0 else "white")
	_position_label.text = "持仓 %d 股\n成本 %.2f\n[color=%s]浮盈亏 %+.0f (%+.2f%%)[/color]" % [quantity, average_cost, profit_color, profit, profit_ratio * 100.0]
	# 选中股票杠杆仓位快照；空字典表示当前没有杠杆仓位。
	var leverage_position: Dictionary = _stock_market_service.call("get_leverage_position", _selected_stock_id) as Dictionary if _stock_market_service.has_method("get_leverage_position") else {}
	if leverage_position.is_empty():
		_position_label.text += "\n杠杆：无仓位"
	else:
		# 杠杆浮动盈亏；正值盈利、负值亏损，展示颜色与现货盈亏语义一致。
		var leverage_profit: float = float(leverage_position.get("profit", 0.0))
		# 杠杆盈亏颜色；盈利绿色、亏损红色、持平白色。
		var leverage_profit_color: String = "green" if leverage_profit > 0.0 else ("red" if leverage_profit < 0.0 else "white")
		_position_label.text += "\n杠杆 %d×%s 保证金 %.0f\n[color=%s]杠杆盈亏 %+.2f[/color]  强平 %.2f" % [int(leverage_position.get("leverage", 1)), str(leverage_position.get("direction_name", "做多")), float(leverage_position.get("margin", 0.0)), leverage_profit_color, leverage_profit, float(leverage_position.get("liquidation_price", 0.0))]
	# 当前永久星穹；仅用于证券币充值，不再直接参与股票买入结算。
	var permanent_coins: int = int(_global_inventory.call("get_coins")) if _global_inventory != null else 0
	# 当前证券币余额；支持两位小数，是股票买卖的唯一结算货币。
	var securities_balance: float = float(_stock_market_service.call("get_securities_balance")) if _stock_market_service.has_method("get_securities_balance") else 0.0
	# 证券账户总资产；余额、现货实时市值与杠杆实时净值之和，由服务统一计算保证口径一致。
	var total_assets: float = float(_stock_market_service.call("get_total_securities_assets")) if _stock_market_service.has_method("get_total_securities_assets") else securities_balance
	_coins_label.text = "星穹：%d\n证券币：%.2f\n总资产：%.2f" % [permanent_coins, securities_balance, total_assets]
	# 充值按钮；按名称读取交易区动态控件，缺失时不影响核心行情显示。
	if _deposit_button != null:
		_deposit_button.disabled = permanent_coins <= 0
	# 提现按钮；只允许提现证券币整数部分，余额不足 1 时禁用。
	# 最小有效提现额；扣除手续费后必须至少产生 1 个整数星穹到账。
	var minimum_withdrawal_amount: int = int(_stock_market_service.call("get_minimum_withdrawal_amount"))
	if _withdraw_button != null:
		_withdraw_button.disabled = minimum_withdrawal_amount <= 0 or floori(securities_balance) < minimum_withdrawal_amount
	_buy_button.disabled = int(_stock_market_service.call("get_maximum_buy_quantity", _selected_stock_id)) <= 0
	_sell_button.disabled = quantity <= 0
	# 可选杠杆倍数目录；由服务提供，取最低倍数评估开仓入口可用性，避免面板硬编码倍率。
	var leverage_multipliers: Array = _stock_market_service.call("get_leverage_multipliers") as Array if _stock_market_service.has_method("get_leverage_multipliers") else []
	# 杠杆最低倍数下的最大保证金；连最低倍数都开不起时禁用开仓入口。
	var leverage_maximum_margin: int = int(_stock_market_service.call("get_maximum_leverage_margin", int(leverage_multipliers[0]))) if not leverage_multipliers.is_empty() else 0
	# 杠杆最低保证金门槛；服务统一配置，开仓按钮与弹窗滑条共用同一下限。
	var leverage_minimum_margin: int = int(_stock_market_service.call("get_leverage_minimum_margin")) if _stock_market_service.has_method("get_leverage_minimum_margin") else 0
	if _leverage_open_button != null:
		# 加仓复用补充；无仓位时保持开仓入口，已有仓位时同一按钮切换为加仓入口并按现有倍数评估追加保证金可支付性。
		if leverage_position.is_empty():
			_leverage_open_button.text = "杠杆开仓"
			_leverage_open_button.disabled = leverage_maximum_margin < leverage_minimum_margin or leverage_minimum_margin <= 0
		else:
			_leverage_open_button.text = "杠杆加仓"
			# 现有倍数下可支付的最大追加保证金；余额连最低追加额都不够时禁用加仓入口。
			var leverage_add_maximum_margin: int = int(_stock_market_service.call("get_maximum_leverage_margin", int(leverage_position.get("leverage", 1))))
			_leverage_open_button.disabled = leverage_add_maximum_margin < leverage_minimum_margin or leverage_minimum_margin <= 0
	if _leverage_close_button != null:
		_leverage_close_button.disabled = leverage_position.is_empty()


func _refresh_holdings() -> void:
	# 已创建持仓按钮；刷新开始时统一隐藏，随后只重新显示当前数量大于 0 的股票。
	# 可见性稳定补充：当前不再执行统一隐藏，已有正持仓卡牌在每秒刷新前后始终保持 visible=true，避免触发鼠标离开。
	# 可见持仓数量；用于控制空状态提示，不依赖容器子节点总数。
	var visible_holding_count: int = 0
	# 股票静态目录；按服务稳定顺序筛选非空持仓并建立底部卡片。
	# 目录缓存补充：改读启动时缓存的静态副本，每秒刷新不再向服务重复请求深复制目录。
	var definitions: Dictionary = _stock_definitions_cache
	for stock_id in definitions.keys():
		# 当前遍历股票持仓；数量为 0 时不创建空卡片。
		var holding: Dictionary = _get_holding(str(stock_id))
		# 当前股票持仓按钮；首次刷新即按股票目录顺序创建，未持有时保持隐藏以稳定后续显示顺序。
		var host: Button = _holding_buttons.get(str(stock_id)) as Button
		if host == null:
			host = _create_holding_card_button(str(stock_id))
		# 当前遍历持股数量；只展示正整数持仓。
		var quantity: int = int(holding.get("quantity", 0))
		# 当前卡牌目标可见性；只在持仓跨越 0 边界时修改，实时价格与盈亏刷新期间不会反复隐藏和显示。
		var should_show_holding: bool = quantity > 0
		if host.visible != should_show_holding:
			host.visible = should_show_holding
		if not should_show_holding:
			continue
		visible_holding_count += 1
		# 当前遍历股票快照；提供名称和最新价格。
		# 轻量刷新补充：名称改读静态目录缓存，价格改用轻量只读接口，不再每秒复制持仓股票的完整行情。
		var holding_definition: Dictionary = definitions.get(stock_id, {}) as Dictionary
		# 当前遍历加权成本；包含买入手续费。
		var average_cost: float = float(holding.get("average_cost", 0.0))
		# 当前遍历最新价格；用于计算持仓市值。
		var current_price: float = float(_stock_market_service.call("get_stock_price", str(stock_id)))
		# 当前遍历浮动盈亏金额；展示为取整星穹。
		var profit: float = (current_price - average_cost) * quantity
		# 当前遍历浮动盈亏比例；零成本时保持 0。
		var profit_ratio: float = current_price / average_cost - 1.0 if average_cost > 0.0 else 0.0
		# 当前遍历盈亏颜色；与右侧持仓摘要保持一致。
		var profit_color: String = "green" if profit > 0.0 else ("red" if profit < 0.0 else "white")
		# 持仓卡片按钮；透明宿主只负责点击切换、悬浮动画和键盘焦点隔离，不直接执行买卖。
		# 原位复用补充：首次持有时创建按钮，后续每秒行情刷新继续使用同一节点和当前缩放状态。
		# 持仓标准卡片；通过空资源模式展示价格、数量、成本和盈亏。
		var card: Control = host.get_node_or_null("Card") as Control
		card.call("configure", null, 1, "%s · %d股" % [str(holding_definition.get("name", "股票")), quantity], "成本 %.2f  [color=%s]%+.2f / %+.2f%%[/color]" % [average_cost, profit_color, profit, profit_ratio * 100.0], "%.2f 证券币" % current_price)
		card.call("set_visual_state", str(stock_id) == _selected_stock_id, false)
	visible_holding_count += _refresh_leverage_cards()
	if visible_holding_count == 0:
		# 空持仓提示；在没有任何股票时替代卡片列表。
		# 杠杆持仓补充：现货与杠杆仓位都为空时才显示空状态提示。
		_empty_holdings_label.visible = true
	else:
		_empty_holdings_label.visible = false


func _refresh_leverage_cards() -> int:
	## 按稳定股票顺序刷新底部杠杆仓位卡片；返回当前可见杠杆卡片数量，供空状态提示统一判断。
	# 可见杠杆卡片数量；无仓位股票的卡片保持隐藏。
	var visible_leverage_count: int = 0
	if _stock_market_service == null or not _stock_market_service.has_method("get_leverage_position"):
		return 0
	for stock_id in _stock_definitions_cache.keys():
		# 当前遍历杠杆仓位快照；空字典表示该股票没有杠杆仓位。
		var position: Dictionary = _stock_market_service.call("get_leverage_position", str(stock_id)) as Dictionary
		# 当前杠杆卡片按钮；构建阶段已按目录顺序预创建，理论上不会缺失。
		var host: Button = _leverage_buttons.get(str(stock_id)) as Button
		if host == null:
			host = _create_leverage_card_button(str(stock_id))
		# 当前卡牌目标可见性；只在仓位建立或关闭的边界修改，实时盈亏刷新期间不会反复隐藏和显示。
		var should_show_position: bool = not position.is_empty()
		if host.visible != should_show_position:
			host.visible = should_show_position
		if not should_show_position:
			continue
		visible_leverage_count += 1
		# 当前杠杆浮动盈亏；正值盈利、负值亏损。
		var profit: float = float(position.get("profit", 0.0))
		# 当前盈亏相对保证金比例；杠杆玩法以保证金回报率为主要观察指标。
		var margin: float = maxf(float(position.get("margin", 0.0)), 0.01)
		# 当前杠杆盈亏颜色；与现货持仓卡片的语义色一致。
		var profit_color: String = "green" if profit > 0.0 else ("red" if profit < 0.0 else "white")
		# 当前杠杆股票静态定义；卡片标题使用稳定显示名称，不随每秒行情变化。
		var leverage_definition: Dictionary = _stock_definitions_cache.get(stock_id, {}) as Dictionary
		# 杠杆标准卡片；标题标注杠杆属性，中部展示倍数方向与盈亏，底部展示实时净值。
		var card: Control = host.get_node_or_null("Card") as Control
		card.call("configure", null, 1, "%s · 杠杆" % str(leverage_definition.get("name", "股票")), "%d×%s  [color=%s]%+.2f / %+.1f%%[/color]" % [int(position.get("leverage", 1)), str(position.get("direction_name", "做多")), profit_color, profit, profit / margin * 100.0], "净值 %.2f 证券币" % float(position.get("equity", 0.0)))
		card.call("set_visual_state", str(stock_id) == _selected_stock_id, false)
	return visible_leverage_count


func _get_holding(stock_id: String) -> Dictionary:
	if _global_inventory == null or not _global_inventory.has_method("get_stock_holding"):
		return {}
	return _global_inventory.call("get_stock_holding", stock_id) as Dictionary


func _is_debug_information_visible() -> bool:
	# 调试设置服务；缺失时保持正式玩家视图，避免泄露价值中枢和概率参数。
	# 节点缓存补充：改用启动时缓存的服务引用，每秒行情刷新不再重复执行节点树查询。
	return _debug_settings != null and _debug_settings.has_method("is_debug_information_visible") and bool(_debug_settings.call("is_debug_information_visible"))


func _on_stock_selected(stock_id: String) -> void:
	_selected_stock_id = stock_id
	# 选中股票变化属于低频路径；此时同步更新一次大盘名称缓存，再执行完整刷新。
	_refresh_market_snapshot_cache()
	_refresh_all()


func _on_stock_card_hovered(stock_id: String, hovered: bool) -> void:
	# 股票按钮宿主；用于把鼠标悬浮状态转交标准卡片动画。
	var button: Button = _stock_buttons.get(stock_id) as Button
	# 标准卡片视图；按钮缺失时保持空引用，避免动态重建期间触发悬浮回调报错。
	var card: Control = null
	if button != null:
		card = button.get_node_or_null("Card") as Control
	if card != null:
		card.call("play_hover", button, hovered)


func _on_holding_card_hovered(button: Button, hovered: bool) -> void:
	## 把全部持仓卡片的鼠标状态转交标准卡片动画；按钮本身保持透明且不显示默认高亮。
	if button == null:
		return
	# 持仓标准卡片；固定为按钮的 Card 子节点，重建列表期间缺失时安全跳过。
	var card: Control = button.get_node_or_null("Card") as Control
	if card != null:
		card.call("play_hover", button, hovered)


func _on_buy_pressed() -> void:
	# 最大可买数量；服务已按当前星穹、价格和最低手续费精确校验。
	var maximum_quantity: int = int(_stock_market_service.call("get_maximum_buy_quantity", _selected_stock_id))
	if maximum_quantity <= 0:
		return
	_begin_quantity_selection("buy", maximum_quantity)


func _on_sell_pressed() -> void:
	# 最大可卖数量；等于当前选中股票的完整持股数量。
	var maximum_quantity: int = int(_get_holding(_selected_stock_id).get("quantity", 0))
	if maximum_quantity <= 0:
		return
	_begin_quantity_selection("sell", maximum_quantity)


func _on_leverage_open_pressed() -> void:
	## 打开杠杆开仓弹窗；缓存当前选中股票为交易目标，弹窗内的价格与余额随每秒行情持续刷新。
	## 加仓复用补充；选中股票已有杠杆仓位时同一入口改为打开加仓弹窗，方向与倍数锁定为现有仓位配置。
	if _stock_market_service == null or not _stock_market_service.has_method("get_leverage_open_quote"):
		return
	# 待交易股票静态定义；弹窗只使用稳定显示名称，成交价以确认瞬间实时行情为准。
	var definition: Dictionary = _stock_definitions_cache.get(_selected_stock_id, {}) as Dictionary
	if bool(_stock_market_service.call("has_leverage_position", _selected_stock_id)):
		# 现有仓位快照；加仓弹窗需要方向、倍数、保证金与开仓均价做本地合并预览。
		var position: Dictionary = _stock_market_service.call("get_leverage_position", _selected_stock_id) as Dictionary
		_pending_trade_type = "leverage_add"
		_pending_stock_id = _selected_stock_id
		_pending_unit_price = float(_stock_market_service.call("get_current_price", _pending_stock_id))
		_leverage_dialog.present_add(str(definition.get("name", "股票")), position, _pending_unit_price, float(_stock_market_service.call("get_securities_balance")), float(_stock_market_service.call("get_leverage_fee_ratio")), int(_stock_market_service.call("get_leverage_minimum_margin")), float(_stock_market_service.call("get_leverage_liquidation_loss_ratio")))
		return
	_pending_trade_type = "leverage_open"
	_pending_stock_id = _selected_stock_id
	_pending_unit_price = float(_stock_market_service.call("get_current_price", _pending_stock_id))
	_leverage_dialog.present_open(str(definition.get("name", "股票")), _pending_unit_price, float(_stock_market_service.call("get_securities_balance")), float(_stock_market_service.call("get_leverage_fee_ratio")), int(_stock_market_service.call("get_leverage_minimum_margin")), float(_stock_market_service.call("get_leverage_liquidation_loss_ratio")), _stock_market_service.call("get_leverage_multipliers") as Array)


func _on_leverage_close_pressed() -> void:
	## 打开杠杆平仓二次确认；正文展示实时盈亏、手续费与返还金额，并随每秒行情持续刷新。
	if _stock_market_service == null or not _stock_market_service.has_method("get_leverage_close_quote"):
		return
	# 平仓实时报价；没有仓位时直接提示并不打开确认窗口。
	var quote: Dictionary = _stock_market_service.call("get_leverage_close_quote", _selected_stock_id) as Dictionary
	if not bool(quote.get("valid", false)):
		_show_event_banner(str(quote.get("message", "当前没有杠杆仓位")))
		return
	_pending_trade_type = "leverage_close"
	_pending_stock_id = _selected_stock_id
	_confirmation_dialog.present("确认杠杆平仓", _build_leverage_close_message(quote), "确认平仓", "取消", 480, trade_confirmation_dialog_height, bool(quote.get("executable", false)))


func _on_leverage_position_confirmed(direction: int, leverage: int, margin: int) -> void:
	## 执行杠杆开仓；服务按确认瞬间的实时价格与余额原子校验，失败时证券币保持不变。
	## 加仓复用补充；挂起类型为加仓时改走加仓接口，服务沿用现有方向与倍数，仅合并追加保证金。
	if _stock_market_service == null or _pending_stock_id.is_empty():
		return
	if _pending_trade_type == "leverage_add":
		# 加仓结果；统一读取服务返回消息，在顶部短暂提示成功或失败原因。
		var add_result: Dictionary = _stock_market_service.call("request_leverage_add", _pending_stock_id, margin) as Dictionary
		_show_event_banner(str(add_result.get("message", "杠杆加仓已处理")))
	else:
		# 开仓结果；统一读取服务返回消息，在顶部短暂提示成功或失败原因。
		var open_result: Dictionary = _stock_market_service.call("request_leverage_open", _pending_stock_id, direction, leverage, margin) as Dictionary
		_show_event_banner(str(open_result.get("message", "杠杆开仓已处理")))
	_pending_trade_type = ""
	_pending_stock_id = ""
	_pending_quantity = 0
	_pending_unit_price = 0.0
	_refresh_all()


func _on_leverage_position_closed(_stock_id: String, message: String) -> void:
	## 杠杆仓位关闭回调；主动平仓与强制平仓统一在顶部横幅展示结算说明，行情信号会负责刷新界面。
	_show_event_banner(message)


func _build_leverage_close_message(quote: Dictionary) -> String:
	## 构建杠杆平仓实时摘要；返回值可在每秒行情刷新时直接替换确认窗口正文。
	# 平仓股票静态定义；正文使用稳定显示名称。
	var definition: Dictionary = _stock_definitions_cache.get(_pending_stock_id, {}) as Dictionary
	return "%s 杠杆仓位\n实时价格：%.2f 证券币\n浮动盈亏：%+.2f 证券币\n实时净值：%.2f 证券币\n平仓手续费：%.2f 证券币\n最终返还：%.2f 证券币\n净值持续波动，以点击确认瞬间的实时价格为准" % [str(definition.get("name", "股票")), float(quote.get("price", 0.0)), float(quote.get("profit", 0.0)), float(quote.get("equity", 0.0)), float(quote.get("fee", 0.0)), float(quote.get("total", 0.0))]


func _on_securities_deposit_pressed() -> void:
	## 打开证券币充值输入；最大金额取当前实时永久星穹，最终扣款仍由服务再次复核。
	if _global_inventory == null or not _global_inventory.has_method("get_coins"):
		return
	# 当前可充值星穹；永久星穹只支持整数，因此输入金额天然满足 1:1 整数兑换要求。
	var maximum_amount: int = int(_global_inventory.call("get_coins"))
	if maximum_amount <= 0:
		_show_event_banner("当前没有可充值的星穹")
		return
	_securities_transfer_dialog.present_deposit(maximum_amount)


func _on_securities_withdrawal_pressed() -> void:
	## 打开证券币提现输入；只开放当前余额整数部分，小数余额继续保留在证券账户中。
	if _stock_market_service == null or not _stock_market_service.has_method("get_securities_balance"):
		return
	# 当前最大提现整数额；向下取整确保任何证券币小数部分都不会被隐式兑换或丢失。
	var maximum_amount: int = floori(float(_stock_market_service.call("get_securities_balance")))
	# 最小有效提现额；默认 0.5% 手续费时为 2 证券币，可确保向下取整后至少到账 1 星穹。
	var minimum_amount: int = int(_stock_market_service.call("get_minimum_withdrawal_amount"))
	if minimum_amount <= 0 or maximum_amount < minimum_amount:
		_show_event_banner("证券币整数余额不足，无法提现")
		return
	# 当前提现手续费比例；由服务统一配置，输入弹窗只用于预览到账星穹。
	var withdrawal_fee_ratio: float = float(_stock_market_service.call("get_withdrawal_fee_ratio"))
	_securities_transfer_dialog.present_withdrawal(maximum_amount, withdrawal_fee_ratio, minimum_amount)


func _on_securities_transfer_confirmed(amount: int, is_deposit: bool) -> void:
	## 执行充值或提现；服务会按确认瞬间的真实余额复核，失败时两种资产都保持安全状态。
	if _stock_market_service == null or amount <= 0:
		return
	# 转账结果；充值和提现共用顶部提示，成功后余额信号会自动刷新所有交易控件。
	var transfer_result: Dictionary = _stock_market_service.call("request_securities_deposit", amount) as Dictionary if is_deposit else _stock_market_service.call("request_securities_withdrawal", amount) as Dictionary
	_show_event_banner(str(transfer_result.get("message", "转账已处理")))
	_refresh_all()


func _begin_quantity_selection(trade_type: String, maximum_quantity: int) -> void:
	_pending_trade_type = trade_type
	_pending_stock_id = _selected_stock_id
	# 待交易股票快照；缓存弹窗展示名称和当前单价，最终确认时会再次读取实时报价。
	# 报价锁定补充；快照只读取名称，整数成交价由服务单独读取并冻结到本次确认流程结束。
	# 实时交易规则；旧冻结说明仅保留历史注释兼容，当前流程会持续刷新整数展示价并在点击确认时重新取价。
	var snapshot: Dictionary = _stock_market_service.call("get_stock_snapshot", _pending_stock_id) as Dictionary
	_pending_unit_price = float(_stock_market_service.call("get_current_price", _pending_stock_id))
	# 当前永久星穹；数量弹窗会在买入模式按实时报价复核所选数量是否仍可支付。
	# 证券币余额规则；旧永久星穹说明仅保留历史注释兼容，股票弹窗只校验独立证券币余额。
	var available_coins: float = float(_stock_market_service.call("get_securities_balance"))
	# 股票手续费比例；由服务配置提供，确保数量弹窗预览与最终结算使用同一数值来源。
	var fee_ratio: float = float(_stock_market_service.call("get_stock_trade_fee_ratio"))
	_quantity_dialog.present_stock_trade(str(snapshot.get("name", "股票")), maximum_quantity, _pending_unit_price, trade_type == "buy", available_coins, fee_ratio)


func _on_trade_quantity_confirmed(quantity: int) -> void:
	_pending_quantity = maxi(quantity, 1)
	# 最终确认前股票快照；数量弹窗关闭后重新读取当前价，避免使用过期报价。
	# 报价锁定补充；此处重新读取快照只用于股票名称，金额继续使用已锁定的 _pending_unit_price。
	# 实时交易规则；旧锁价说明仅保留历史注释兼容，金额由下方服务报价持续更新，缓存价不参与成交。
	var snapshot: Dictionary = _stock_market_service.call("get_stock_snapshot", _pending_stock_id) as Dictionary
	# 实时交易报价；统一由服务计算单价、手续费、金额和可执行状态，避免 UI 复制公式后产生差异。
	var quote: Dictionary = _stock_market_service.call("get_trade_quote", _pending_stock_id, _pending_quantity, _pending_trade_type) as Dictionary
	_pending_unit_price = float(quote.get("price", 0.0))
	# 操作名称；用于确认弹窗标题和按钮文本。
	var action_name: String = "买入" if _pending_trade_type == "buy" else "卖出"
	# 确认正文；完整列出股票、数量、实时单价、手续费、金额和支付状态。
	var message: String = _build_trade_confirmation_message(snapshot, quote)
	_confirmation_dialog.present("确认%s" % action_name, message, "确认%s" % action_name, "取消", 480, trade_confirmation_dialog_height, bool(quote.get("executable", false)))


func _on_trade_confirmed() -> void:
	# 杠杆平仓确认分支；平仓没有数量概念，先于现货数量校验单独处理并共用统一的挂起状态清理。
	if _pending_trade_type == "leverage_close" and not _pending_stock_id.is_empty():
		# 平仓结果；服务按确认瞬间的实时价格结算净值并返还证券币。
		var close_result: Dictionary = _stock_market_service.call("request_leverage_close", _pending_stock_id) as Dictionary
		_show_event_banner(str(close_result.get("message", "杠杆平仓已处理")))
		_pending_trade_type = ""
		_pending_stock_id = ""
		_pending_quantity = 0
		_pending_unit_price = 0.0
		_refresh_all()
		return
	if _pending_quantity <= 0 or _pending_stock_id.is_empty():
		return
	# 交易结果；统一读取服务返回消息，在顶部短暂提示成功或失败原因。
	var trade_result: Dictionary = {}
	if _pending_trade_type == "buy":
		trade_result = _stock_market_service.call("request_buy", _pending_stock_id, _pending_quantity) as Dictionary
	elif _pending_trade_type == "sell":
		trade_result = _stock_market_service.call("request_sell", _pending_stock_id, _pending_quantity) as Dictionary
	if not trade_result.is_empty():
		_show_event_banner(str(trade_result.get("message", "交易已处理")))
	_pending_trade_type = ""
	_pending_stock_id = ""
	_pending_quantity = 0
	_pending_unit_price = 0.0
	_refresh_all()


func _on_trade_canceled() -> void:
	_pending_trade_type = ""
	_pending_stock_id = ""
	_pending_quantity = 0
	_pending_unit_price = 0.0


func _refresh_pending_trade_dialog() -> void:
	## 同步交易弹窗中的实时行情；数量选择和二次确认期间都不会暂停面板微行情。
	if _pending_trade_type.is_empty() or _pending_stock_id.is_empty() or _stock_market_service == null:
		return
	# 当前整数单价；每次市场刷新都覆盖最近展示值，不作为最终成交锁价。
	_pending_unit_price = float(_stock_market_service.call("get_current_price", _pending_stock_id))
	# 当前永久星穹；买入数量上限和二次确认支付状态都按该余额实时复核。
	# 证券币余额规则；旧永久星穹说明仅保留历史注释兼容，交易弹窗只使用证券币余额。
	var available_coins: float = float(_stock_market_service.call("get_securities_balance"))
	if _pending_trade_type == "leverage_open" or _pending_trade_type == "leverage_add":
		# 加仓强平保护；加仓弹窗打开期间仓位被强制平仓时立即关闭弹窗并清理挂起状态，防止对已消失仓位执行加仓。
		if _pending_trade_type == "leverage_add" and not bool(_stock_market_service.call("has_leverage_position", _pending_stock_id)):
			if _leverage_dialog != null and _leverage_dialog.visible:
				_leverage_dialog.hide()
			_on_trade_canceled()
			return
		# 杠杆开仓弹窗实时刷新；同步实时价格与可用余额，保证金上限与强平价预览随之更新，加仓模式共用同一刷新入口。
		if _leverage_dialog != null and _leverage_dialog.visible:
			_leverage_dialog.update_market(_pending_unit_price, available_coins)
		return
	if _pending_trade_type == "leverage_close":
		# 杠杆平仓确认实时刷新；净值、手续费与返还金额按实时行情覆盖正文。
		if _confirmation_dialog != null and _confirmation_dialog.visible:
			# 平仓实时报价；仓位可能已被强制平仓，此时禁用确认并提示原因。
			var close_quote: Dictionary = _stock_market_service.call("get_leverage_close_quote", _pending_stock_id) as Dictionary
			if bool(close_quote.get("valid", false)):
				_confirmation_dialog.update_confirmation_message(_build_leverage_close_message(close_quote), bool(close_quote.get("executable", false)))
			else:
				_confirmation_dialog.update_confirmation_message(str(close_quote.get("message", "当前没有杠杆仓位")), false)
		return
	if _quantity_dialog != null and _quantity_dialog.visible:
		# 数量弹窗实时上限；买入按当前价和余额计算，卖出按当前持仓计算。
		var maximum_quantity: int = int(_stock_market_service.call("get_maximum_buy_quantity", _pending_stock_id)) if _pending_trade_type == "buy" else int(_get_holding(_pending_stock_id).get("quantity", 0))
		_quantity_dialog.update_stock_trade(_pending_unit_price, maximum_quantity, available_coins)
		return
	if _confirmation_dialog == null or not _confirmation_dialog.visible or _pending_quantity <= 0:
		return
	# 二次确认实时报价；价格上涨导致余额不足时禁用确认，价格回落后会自动恢复。
	var quote: Dictionary = _stock_market_service.call("get_trade_quote", _pending_stock_id, _pending_quantity, _pending_trade_type) as Dictionary
	# 待交易股票快照；提供稳定显示名称，交易目标始终使用缓存股票标识。
	var snapshot: Dictionary = _stock_market_service.call("get_stock_snapshot", _pending_stock_id) as Dictionary
	_confirmation_dialog.update_confirmation_message(_build_trade_confirmation_message(snapshot, quote), bool(quote.get("executable", false)))


func _build_trade_confirmation_message(snapshot: Dictionary, quote: Dictionary) -> String:
	## 构建二次确认实时摘要；返回值可在每秒行情刷新时直接替换现有正文。
	# 最终金额标签；买入显示花费，卖出显示所得。
	var amount_name: String = "最终花费" if _pending_trade_type == "buy" else "最终所得"
	# 当前支付状态；不可执行时展示具体原因，价格恢复到可支付范围后改回成交提示。
	var status_text: String = "当前可成交" if bool(quote.get("executable", false)) else str(quote.get("message", "当前无法成交"))
	return "%s %d 股\n实时单价：%.2f 证券币\n手续费：%.2f 证券币\n%s：%.2f 证券币\n%s\n成交价持续波动，以点击确认瞬间的实时价格为准" % [str(snapshot.get("name", "股票")), _pending_quantity, float(quote.get("price", 0.0)), float(quote.get("fee", 0.0)), amount_name, float(quote.get("total", 0.0)), status_text]


func _show_event_banner(message: String) -> void:
	if _event_tween != null and _event_tween.is_valid():
		_event_tween.kill()
	_event_banner.text = message
	_event_banner.modulate = Color.WHITE
	_event_banner.visible = true
	_event_tween = create_tween()
	_event_tween.tween_interval(maxf(event_message_duration_seconds - 0.6, 0.0))
	_event_tween.tween_property(_event_banner, "modulate:a", 0.0, minf(event_message_duration_seconds, 0.6)).set_trans(Tween.TRANS_LINEAR)
	_event_tween.tween_callback(func() -> void: _event_banner.visible = false)


func _show_active_event_if_available() -> void:
	if _stock_market_service == null or not _stock_market_service.has_method("get_market_snapshot"):
		return
	# 当前市场快照；主菜单在战斗结算后重新创建时可恢复刚触发但尚在持续的事件消息。
	var market_snapshot: Dictionary = _stock_market_service.call("get_market_snapshot") as Dictionary
	# 当前事件；空字典表示没有持续事件，不显示顶部提示。
	var active_event: Dictionary = market_snapshot.get("active_event", {}) as Dictionary
	if not active_event.is_empty():
		_show_event_banner(str(active_event.get("message", "市场出现新变化")))


func _on_trade_history_button_pressed() -> void:
	## 打开交易历史窗口；展示买卖、杠杆、强平与资金转账记录，索引 0 为最新记录。
	if _record_list_dialog == null:
		return
	_record_dialog_mode = "trade"
	_record_list_dialog.present_records("交易历史记录", _format_trade_record_lines(), "暂时没有交易记录")


func _on_notification_button_pressed() -> void:
	## 打开通知中心窗口；展示强平等重要通知记录，索引 0 为最新记录。
	if _record_list_dialog == null:
		return
	_record_dialog_mode = "notification"
	_record_list_dialog.present_records("通知中心", _format_notification_record_lines(), "暂时没有通知")


func _on_record_dialog_closed() -> void:
	## 记录窗口关闭回调；清空展示模式，后续新记录不再触发无效的原位刷新。
	_record_dialog_mode = ""


func _on_trade_records_changed() -> void:
	## 交易记录变化回调；交易历史窗口打开时原位刷新，未打开时不做任何工作。
	if _record_dialog_mode != "trade" or _record_list_dialog == null or not _record_list_dialog.visible:
		return
	_record_list_dialog.update_records(_format_trade_record_lines(), "暂时没有交易记录")


func _on_notification_records_changed() -> void:
	## 通知记录变化回调；通知中心窗口打开时原位刷新，未打开时不做任何工作。
	if _record_dialog_mode != "notification" or _record_list_dialog == null or not _record_list_dialog.visible:
		return
	_record_list_dialog.update_records(_format_notification_record_lines(), "暂时没有通知")


func _format_trade_record_lines() -> Array[String]:
	## 把服务交易记录转换为带时间前缀与语义色的富文本行；强平记录红色警示，其余记录白色正文。
	# 富文本行列表；顺序与服务记录一致，索引 0 为最新记录。
	var lines: Array[String] = []
	if _stock_market_service == null or not _stock_market_service.has_method("get_trade_records"):
		return lines
	# 服务交易记录副本；每项包含时间文本、类型标识与说明文本。
	var records: Array = _stock_market_service.call("get_trade_records") as Array
	for record_value in records:
		if not (record_value is Dictionary):
			continue
		# 单条交易记录；缺失字段按空文本安全降级。
		var record: Dictionary = record_value as Dictionary
		# 记录正文颜色；强平记录使用红色提醒风险，其余记录保持白色。
		var record_color: String = "red" if str(record.get("type", "")) == "leverage_liquidation" else "white"
		lines.append("[color=gray]%s[/color]  [color=%s]%s[/color]" % [str(record.get("time_text", "")), record_color, str(record.get("message", ""))])
	return lines


func _format_notification_record_lines() -> Array[String]:
	## 把服务通知记录转换为带时间前缀的富文本行；通知统一使用琥珀色正文突出重要性。
	# 富文本行列表；顺序与服务记录一致，索引 0 为最新通知。
	var lines: Array[String] = []
	if _stock_market_service == null or not _stock_market_service.has_method("get_notification_records"):
		return lines
	# 服务通知记录副本；每项包含时间文本与说明文本。
	var records: Array = _stock_market_service.call("get_notification_records") as Array
	for record_value in records:
		if not (record_value is Dictionary):
			continue
		# 单条通知记录；缺失字段按空文本安全降级。
		var record: Dictionary = record_value as Dictionary
		lines.append("[color=gray]%s[/color]  [color=#ffcc4d]%s[/color]" % [str(record.get("time_text", "")), str(record.get("message", ""))])
	return lines


func _on_close_pressed() -> void:
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey):
		return
	if (_quantity_dialog != null and _quantity_dialog.visible) or (_confirmation_dialog != null and _confirmation_dialog.visible) or (_securities_transfer_dialog != null and _securities_transfer_dialog.visible) or (_leverage_dialog != null and _leverage_dialog.visible) or (_record_list_dialog != null and _record_list_dialog.visible):
		return
	# 键盘事件；只处理首次按下的 ESC，长按重复不会连续发送关闭信号。
	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE):
		closed.emit()
		get_viewport().set_input_as_handled()
