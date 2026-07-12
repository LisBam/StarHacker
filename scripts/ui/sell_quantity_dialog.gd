extends ConfirmationDialog
class_name SellQuantityDialog

## 堆叠物品出售数量弹窗统一提供滑条和数字输入两种选择方式。
## 弹窗只负责数量展示与确认，不直接访问仓库、金币或存档服务。
## 跨容器移动补充；同一弹窗可切换移动模式，并继续保持不直接访问库存服务的职责边界。

signal quantity_confirmed(quantity: int)

## 全局窗口样式指南；统一数量弹窗的按钮、输入、滑条和窗口描边视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 可视进度拖动条组件；统一绘制购买、出售、移动、丢弃、送回和矿场数量选择进度。
const PROGRESS_SLIDER_VISUAL_SCRIPT: Script = preload("res://scripts/ui/progress_slider_visual.gd")
## 弹窗最外层框架组件；直接绘制不透明标题栏、外框、标题文字和关闭按钮。
const DIALOG_OUTER_FRAME_SCRIPT: Script = preload("res://scripts/ui/dialog_outer_frame.gd")

## 出售数量模式标识；默认显示金币收益并使用“出售”确认按钮。
const DISPLAY_MODE_SALE: String = "sale"
## 移动数量模式标识；跨仓库和背包拖拽堆叠时显示移动方向与实际数量。
const DISPLAY_MODE_TRANSFER: String = "transfer"
## 丢弃数量模式标识；战斗背包部分丢弃时显示本次丢弃数量，不计算金币。
const DISPLAY_MODE_DISCARD: String = "discard"
## 物资送回数量模式标识；显示本次价值、20% 运费和送回后的剩余额度。
const DISPLAY_MODE_SHIPPING: String = "shipping"
## 股票交易数量模式标识；显示当前数量和每股价格，最终手续费由后续通用确认弹窗精确展示。
const DISPLAY_MODE_STOCK_TRADE: String = "stock_trade"
## 矿场交易数量模式标识；复用同款滑条与数字输入，覆盖资产购买、出售、充值和提现。
const DISPLAY_MODE_MINING_TRANSACTION: String = "mining_transaction"
## 开发者数值模式标识；复用滑条与数字输入直接选择强化石数量或目标金币余额。
const DISPLAY_MODE_DEVELOPER_VALUE: String = "developer_value"
## 矿场资产购买操作；数量表示购买台数，摘要显示总算力币成本。
const MINING_ACTION_BUY: String = "buy"
## 矿场资产出售操作；数量表示出售台数，摘要显示按 60% 向上取整的返还。
const MINING_ACTION_SELL: String = "sell"
## 矿场充值操作；数量表示消耗的整数永久金币，摘要显示 1:10000 到账。
const MINING_ACTION_RECHARGE: String = "recharge"
## 矿场提现操作；数量表示到账的整数永久金币，摘要显示反推后的算力币成本与手续费。
const MINING_ACTION_WITHDRAW: String = "withdraw"

## 弹窗默认宽度；默认 520 像素可容纳物品名称、数量滑条和数字输入框。
## 当前尺寸补充；默认值已调整为 400 像素以保持紧凑，仍可在检查器中按界面语言长度调整，运行时无需动态修改。
@export_range(320, 640, 1) var dialog_width: int = 400
## 弹窗默认高度；默认 170 像素，完整容纳说明、数量选择和结果摘要且避免遮挡仓库，运行时无需动态修改。
@export_range(140, 260, 1) var dialog_height: int = 170
## 弹窗背景透明度；默认 0.82，数值越低越透明，修改后会同时影响出售和移动数量界面，运行时无需动态修改。
@export_range(0.40, 1.0, 0.01) var dialog_background_alpha: float = 0.82

## 当前最大可出售数量；取值至少为 1，默认 1 用于弹窗尚未配置时的安全范围。
var _maximum_quantity: int = 1
## 当前最小可选数值；默认 1 保持出售、移动等既有模式不变，开发者金币模式允许为 0。
var _minimum_quantity: int = 1
## 当前单件售价；取值大于等于 0，默认 0 用于即时计算出售总价。
## 股票交易价格精度补充；股票模式下该变量使用两位小数证券币，其他物品模式仍传入整数金币。
var _unit_sell_price: float = 0.0
## 当前单件物品价值；默认 0，仅物资送回模式用于计算价值、运费和额度。
var _unit_item_value: int = 0
## 当前可用送回价值；默认 0，仅物资送回模式用于提示选择数量是否会超过单局上限。
var _shipping_remaining_value: int = 0
## 当前送回运费比例；默认 0.20，与全局库存服务的正式结算规则保持一致。
var _shipping_fee_ratio: float = 0.20
## 当前物品显示名称；默认“物品”，配置后用于标题说明本次出售目标。
var _item_display_name: String = "物品"
## 当前展示模式；默认出售模式，移动模式下不计算金币并改为显示本次将移动的数量。
var _display_mode: String = DISPLAY_MODE_SALE
## 股票交易方向；默认 false 表示卖出，仅股票交易模式用于决定余额校验和摘要文案。
var _stock_trade_is_buying: bool = false
## 股票交易当前可执行数量上限；默认 0，买入时随实时价格和金币变化，卖出时随持仓变化。
var _stock_trade_executable_maximum: int = 0
## 股票交易当前可用金币；默认 0，仅买入模式用于提示实时总花费是否超出余额。
## 证券币余额补充；股票模式下该变量表示可带小数的证券币余额，旧名称仅为兼容既有结构保留。
var _stock_trade_available_coins: float = 0.0
## 股票买卖手续费比例；默认 0.005 即 0.5%，仅股票模式用于实时计算两位小数证券币手续费。
var _stock_trade_fee_ratio: float = 0.005
## 当前矿场操作类型；默认购买，仅矿场交易模式用于选择对应整数预览公式。
var _mining_action: String = MINING_ACTION_BUY
## 矿场交易单价或兑换倍率；默认 0，购买出售时为官方资产价，充值提现时为 10000。
var _mining_unit_value: int = 0
## 矿场出售返还比例；默认 60%，只在资产出售数量预览中使用。
var _mining_sell_return_ratio: float = 0.60
## 矿场提现手续费率；默认 10%，只在提现成本反推预览中使用。
var _mining_withdrawal_fee_ratio: float = 0.10
## 矿场是否显示真实整数；默认 false 使用 K/M/B 缩写，由矿场面板的显示开关传入。
var _mining_show_exact_values: bool = false
## 数量滑条；默认运行时创建，取值范围与数字输入框保持双向同步。
var _quantity_slider: HSlider
## 数量数字输入框；默认运行时创建，玩家可键盘直接输入精确数量。
var _quantity_spin_box: SpinBox
## 总价标签；默认运行时创建，数量变化时即时显示将获得的金币。
var _total_price_label: Label
## 数量说明标签；默认运行时创建，显示当前物品名称和最大可出售数量。
var _description_label: Label
## 界面是否已经完成初始化；默认 false，公开展示接口可能早于 `_ready()` 调用，因此通过幂等初始化避免访问空控件。
var _interface_initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_interface_initialized()


func present(item_display_name: String, maximum_quantity: int, unit_sell_price: int) -> void:
	_ensure_interface_initialized()
	_display_mode = DISPLAY_MODE_SALE
	_minimum_quantity = 1
	_item_display_name = item_display_name if not item_display_name.is_empty() else "物品"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = float(maxi(unit_sell_price, 0))
	title = "选择出售数量"
	get_ok_button().text = "出售"
	_description_label.text = "%s · 最多可出售 %d 个" % [_item_display_name, _maximum_quantity]
	_present_current_configuration()


func present_transfer(item_display_name: String, maximum_quantity: int, source_display_name: String, target_display_name: String) -> void:
	_ensure_interface_initialized()
	_display_mode = DISPLAY_MODE_TRANSFER
	_minimum_quantity = 1
	_item_display_name = item_display_name if not item_display_name.is_empty() else "物品"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = 0.0
	title = "选择移动数量"
	get_ok_button().text = "移动"
	_description_label.text = "%s · %s → %s · 最多 %d 个" % [_item_display_name, source_display_name, target_display_name, _maximum_quantity]
	_present_current_configuration()


func present_discard(item_display_name: String, maximum_quantity: int) -> void:
	_ensure_interface_initialized()
	_display_mode = DISPLAY_MODE_DISCARD
	_minimum_quantity = 1
	_item_display_name = item_display_name if not item_display_name.is_empty() else "物品"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = 0.0
	title = "选择丢弃数量"
	get_ok_button().text = "丢弃"
	_description_label.text = "%s · 最多可丢弃 %d 个" % [_item_display_name, _maximum_quantity]
	_present_current_configuration()


func present_shipping(item_display_name: String, maximum_quantity: int, unit_item_value: int, shipping_remaining_value: int, shipping_fee_ratio: float = 0.20) -> void:
	_ensure_interface_initialized()
	_display_mode = DISPLAY_MODE_SHIPPING
	_minimum_quantity = 1
	_item_display_name = item_display_name if not item_display_name.is_empty() else "物品"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = 0.0
	_unit_item_value = maxi(unit_item_value, 0)
	_shipping_remaining_value = maxi(shipping_remaining_value, 0)
	_shipping_fee_ratio = clampf(shipping_fee_ratio, 0.0, 1.0)
	title = "选择送回数量"
	get_ok_button().text = "送回仓库"
	_description_label.text = "%s · 最多可选择 %d 个" % [_item_display_name, _maximum_quantity]
	_present_current_configuration()


func present_stock_trade(stock_display_name: String, maximum_quantity: int, unit_price: float, is_buying: bool, available_coins: float = 0.0, fee_ratio: float = 0.005) -> void:
	_ensure_interface_initialized()
	_display_mode = DISPLAY_MODE_STOCK_TRADE
	_minimum_quantity = 1
	_item_display_name = stock_display_name if not stock_display_name.is_empty() else "股票"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = maxf(snappedf(unit_price, 0.01), 0.01)
	_stock_trade_is_buying = is_buying
	_stock_trade_executable_maximum = maxi(maximum_quantity, 0)
	_stock_trade_available_coins = maxf(snappedf(available_coins, 0.01), 0.0)
	_stock_trade_fee_ratio = clampf(fee_ratio, 0.0, 1.0)
	title = "选择买入数量" if is_buying else "选择卖出数量"
	get_ok_button().text = "下一步"
	_update_stock_trade_description()
	_present_current_configuration()


func present_mining_transaction(action: String, display_name: String, maximum_quantity: int, unit_value: int, sell_return_ratio: float = 0.60, withdrawal_fee_ratio: float = 0.10, show_exact_values: bool = false) -> void:
	## 使用股市同款滑条与数字输入展示矿场整数交易数量；最终结算仍由矿场服务重新校验。
	_ensure_interface_initialized()
	_display_mode = DISPLAY_MODE_MINING_TRANSACTION
	_minimum_quantity = 1
	_mining_action = action
	_item_display_name = display_name if not display_name.is_empty() else "矿场交易"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_mining_unit_value = maxi(unit_value, 0)
	_mining_sell_return_ratio = clampf(sell_return_ratio, 0.0, 1.0)
	_mining_withdrawal_fee_ratio = clampf(withdrawal_fee_ratio, 0.0, 0.99)
	_mining_show_exact_values = show_exact_values
	# 操作文案；数量窗口统一使用“下一步”，确认后进入股市同款二次确认窗口。
	var action_name: String = _get_mining_action_name()
	title = "选择%s数量" % action_name
	get_ok_button().text = "下一步"
	_description_label.text = "%s · 当前最多可%s %d" % [_item_display_name, action_name, _maximum_quantity]
	_present_current_configuration()


func present_developer_value(dialog_title: String, description: String, minimum_value: int, maximum_value: int, initial_value: int, confirm_text: String) -> void:
	## 展示开发者整数选择弹窗；只返回选定数值，实际资源或金币修改仍由 DeveloperMenu 调用服务完成。
	_ensure_interface_initialized()
	_display_mode = DISPLAY_MODE_DEVELOPER_VALUE
	_minimum_quantity = mini(minimum_value, maximum_value)
	_maximum_quantity = maxi(minimum_value, maximum_value)
	_item_display_name = description if not description.is_empty() else "开发者数值"
	title = dialog_title if not dialog_title.is_empty() else "修改开发者数值"
	get_ok_button().text = confirm_text if not confirm_text.is_empty() else "确认"
	_description_label.text = "%s · 范围 %d–%d" % [_item_display_name, _minimum_quantity, _maximum_quantity]
	_present_current_configuration(clampi(initial_value, _minimum_quantity, _maximum_quantity))


func update_stock_trade(unit_price: float, maximum_quantity: int, available_coins: float = 0.0) -> void:
	## 刷新已打开股票数量弹窗的实时报价；保留玩家当前选择，并在可买上限下降时安全收紧数量。
	if _display_mode != DISPLAY_MODE_STOCK_TRADE:
		return
	_unit_sell_price = maxf(snappedf(unit_price, 0.01), 0.01)
	_stock_trade_executable_maximum = maxi(maximum_quantity, 0)
	_stock_trade_available_coins = maxf(snappedf(available_coins, 0.01), 0.0)
	# 控件数量上限；零股可交易时仍保留数值控件的最小合法范围 1，并通过禁用按钮阻止进入下一步。
	var control_maximum: int = maxi(_stock_trade_executable_maximum, 1)
	_maximum_quantity = control_maximum
	_quantity_slider.max_value = float(control_maximum)
	_quantity_spin_box.max_value = float(control_maximum)
	# 当前选择数量；价格上涨使上限降低时自动下调，避免玩家带着已失效数量进入二次确认。
	var resolved_quantity: int = clampi(roundi(_quantity_spin_box.value), 1, control_maximum)
	_quantity_slider.set_value_no_signal(float(resolved_quantity))
	_quantity_spin_box.set_value_no_signal(float(resolved_quantity))
	_update_stock_trade_description()
	_refresh_total_price(resolved_quantity)


func _update_stock_trade_description() -> void:
	## 更新股票交易说明；明确单价和上限均为持续波动中的实时数据，不暗示锁价。
	var maximum_text: String = "%d 股" % _stock_trade_executable_maximum if _stock_trade_executable_maximum > 0 else "0 股"
	_description_label.text = "%s · 实时单价 %.2f 证券币 · 当前最多 %s" % [_item_display_name, _unit_sell_price, maximum_text]


func _ensure_interface_initialized() -> void:
	## 初始化数量弹窗的固定控件和信号；允许宿主在弹窗加入场景树的同一帧立即调用展示接口。
	if _interface_initialized:
		return
	_interface_initialized = true
	# 窗口透明模式；关闭原生透明合成，保证包围标题栏与内容区域的最外层背景和青蓝描边保持完全可见。
	transparent = false
	unresizable = true
	title = "选择出售数量"
	get_ok_button().text = "出售"
	get_cancel_button().text = "取消"
	_apply_dialog_visual_style()
	_build_interface()
	DIALOG_OUTER_FRAME_SCRIPT.install(self)
	confirmed.connect(_on_confirmed)


func _present_current_configuration(initial_value: int = 1) -> void:
	_quantity_slider.min_value = _minimum_quantity
	_quantity_slider.max_value = _maximum_quantity
	_quantity_spin_box.min_value = _minimum_quantity
	_quantity_spin_box.max_value = _maximum_quantity
	# 初始数值；普通数量模式保持 1，开发者模式可传入当前金币或默认强化石数量。
	var resolved_initial_value: int = clampi(initial_value, _minimum_quantity, _maximum_quantity)
	_quantity_slider.set_value_no_signal(float(resolved_initial_value))
	_quantity_spin_box.set_value_no_signal(float(resolved_initial_value))
	_refresh_total_price(resolved_initial_value)
	popup_centered(Vector2i(dialog_width, dialog_height))


func _build_interface() -> void:
	# 内容边距；紧凑留白避免控件贴近透明窗口边缘，同时减少弹窗整体占屏面积。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_bottom", 1)
	add_child(content_margin)
	# 内容容器；纵向排列说明、滑条、数字输入和总价信息。
	# 移动模式补充；最后一行在移动模式下改为显示实际移动数量。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content_margin.add_child(content)
	_description_label = Label.new()
	# 自动换行基准宽度；动态 Window 首次布局前没有可用父级宽度，显式提供宽度可避免文字按 1 像素宽逐字换行并撑高窗口。
	_description_label.custom_minimum_size = Vector2(float(dialog_width - 48), 0.0)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_description_label)
	# 数量选择行；滑条占据主要宽度，数字输入框用于精确键盘输入。
	var quantity_row: HBoxContainer = HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation", 8)
	content.add_child(quantity_row)
	_quantity_slider = HSlider.new()
	_quantity_slider.min_value = 1.0
	_quantity_slider.max_value = 1.0
	_quantity_slider.step = 1.0
	_quantity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quantity_slider.value_changed.connect(_on_slider_value_changed)
	quantity_row.add_child(_quantity_slider)
	PROGRESS_SLIDER_VISUAL_SCRIPT.install(_quantity_slider)
	_quantity_spin_box = SpinBox.new()
	_quantity_spin_box.min_value = 1.0
	_quantity_spin_box.max_value = 1.0
	_quantity_spin_box.step = 1.0
	_quantity_spin_box.allow_greater = false
	_quantity_spin_box.allow_lesser = false
	_quantity_spin_box.custom_minimum_size = Vector2(82.0, 32.0)
	_quantity_spin_box.value_changed.connect(_on_spin_box_value_changed)
	quantity_row.add_child(_quantity_spin_box)
	_total_price_label = Label.new()
	_total_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_price_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_total_price_label)


func _apply_dialog_visual_style() -> void:
	# 弹窗主题；半透明深色背景、细边框和圆角同时应用于出售与移动模式。
	var dialog_theme: Theme = UI_STYLE_GUIDE.create_theme()
	# 弹窗面板样式；透明度由检查器参数统一控制，便于后续按整体 UI 风格调整。
	var dialog_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	dialog_panel_style.bg_color = Color(0.035, 0.045, 0.055, dialog_background_alpha)
	dialog_panel_style.border_color = Color(0.30, 0.50, 0.60, minf(dialog_background_alpha + 0.10, 1.0))
	dialog_panel_style.set_border_width_all(1)
	dialog_panel_style.set_corner_radius_all(8)
	dialog_panel_style.content_margin_top = UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT
	dialog_panel_style.content_margin_bottom = UI_STYLE_GUIDE.DIALOG_ACTION_BOTTOM_CLEARANCE
	dialog_theme.set_stylebox("panel", "Window", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "AcceptDialog", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "ConfirmationDialog", dialog_panel_style)
	theme = dialog_theme


func _on_slider_value_changed(value: float) -> void:
	# 标准化数量；滑条只使用整数步长，仍显式取整以避免浮点回调误差。
	var resolved_quantity: int = clampi(roundi(value), _minimum_quantity, _maximum_quantity)
	_quantity_spin_box.set_value_no_signal(float(resolved_quantity))
	_refresh_total_price(resolved_quantity)


func _on_spin_box_value_changed(value: float) -> void:
	# 标准化数量；直接输入会被限制在 1 到当前堆叠数量内。
	var resolved_quantity: int = clampi(roundi(value), _minimum_quantity, _maximum_quantity)
	_quantity_slider.set_value_no_signal(float(resolved_quantity))
	_refresh_total_price(resolved_quantity)


func _refresh_total_price(quantity: int) -> void:
	# 有效数量；滑条和数字框始终限制在当前堆叠范围，摘要只读取该标准化结果。
	var resolved_quantity: int = clampi(quantity, _minimum_quantity, _maximum_quantity)
	get_ok_button().disabled = false
	if _display_mode == DISPLAY_MODE_TRANSFER:
		_total_price_label.text = "将移动 %d 个" % resolved_quantity
		return
	if _display_mode == DISPLAY_MODE_DISCARD:
		_total_price_label.text = "将丢弃 %d 个" % resolved_quantity
		return
	if _display_mode == DISPLAY_MODE_SHIPPING:
		# 送回摘要；运费按总价值比例向上取整，剩余额度允许显示负数以明确当前数量不可执行。
		var shipping_value: int = _unit_item_value * resolved_quantity
		# 当前数量运费；总价值乘配置比例后向上取整，与全局库存最终扣费一致。
		var shipping_fee: int = ceili(float(shipping_value) * _shipping_fee_ratio) if shipping_value > 0 else 0
		# 送回后的剩余额度；小于 0 时确认按钮禁用并通过负数明确超额规模。
		var remaining_after_shipping: int = _shipping_remaining_value - shipping_value
		_total_price_label.text = "价值 %d · 运费 %d · 送回后剩余 %d" % [shipping_value, shipping_fee, remaining_after_shipping]
		get_ok_button().disabled = shipping_value > _shipping_remaining_value
		return
	if _display_mode == DISPLAY_MODE_STOCK_TRADE:
		# 股票成交额；按当前实时整数单价计算，行情刷新时会由宿主再次调用本函数更新。
		# 证券币成交规则；旧整数说明仅保留历史注释兼容，成交额保留两位小数证券币。
		var stock_gross: float = snappedf(_unit_sell_price * resolved_quantity, 0.01)
		# 股票手续费；成交额的 0.5% 向上取整且最低 1 金币，与股市服务最终成交公式一致。
		# 证券币手续费规则；旧整数说明仅保留历史注释兼容，手续费向上保留到 0.01 且最低 0.01 证券币。
		var stock_fee: float = maxf(float(ceili(maxf(stock_gross * _stock_trade_fee_ratio * 100.0 - 0.000001, 0.0))) / 100.0, 0.01)
		# 股票最终金额；买入为成交额加手续费，卖出为扣费后向下取整且最低 1 金币。
		# 证券币最终金额；旧整数说明仅保留历史注释兼容，买入加费、卖出扣费并统一保留两位小数。
		var stock_total: float = snappedf(stock_gross + stock_fee, 0.01) if _stock_trade_is_buying else maxf(snappedf(stock_gross - stock_fee, 0.01), 0.01)
		# 股票当前数量是否可执行；买入同时检查实时可买上限和金币，卖出只检查持仓上限。
		var stock_trade_executable: bool = _stock_trade_executable_maximum >= resolved_quantity and (not _stock_trade_is_buying or _stock_trade_available_coins + 0.0001 >= stock_total)
		_total_price_label.text = "%d 股 · 手续费 %.2f · %s %.2f 证券币" % [resolved_quantity, stock_fee, "需支付" if _stock_trade_is_buying else "可获得", stock_total]
		if _stock_trade_is_buying and not stock_trade_executable:
			_total_price_label.text += " · 当前证券币不足"
		elif not _stock_trade_is_buying and not stock_trade_executable:
			_total_price_label.text += " · 当前持仓不足"
		get_ok_button().disabled = not stock_trade_executable
		return
	if _display_mode == DISPLAY_MODE_MINING_TRANSACTION:
		if _mining_action == MINING_ACTION_RECHARGE:
			_total_price_label.text = "消耗 %d 金币 · 到账 %s 算力币" % [resolved_quantity, _format_mining_value(resolved_quantity * _mining_unit_value)]
		elif _mining_action == MINING_ACTION_WITHDRAW:
			# 提现总成本；按到账金币整体反推并向上取整，与矿场服务正式公式一致。
			var withdrawal_cost: int = ceili(float(resolved_quantity * _mining_unit_value) / (1.0 - _mining_withdrawal_fee_ratio))
			_total_price_label.text = "到账 %d 金币 · 需要 %s 算力币 · 手续费 %s" % [resolved_quantity, _format_mining_value(withdrawal_cost), _format_mining_value(withdrawal_cost - resolved_quantity * _mining_unit_value)]
		elif _mining_action == MINING_ACTION_SELL:
			# 出售返还；总官方价乘 60% 后整体向上取整，与矿场服务结算顺序一致。
			var sell_return: int = ceili(float(resolved_quantity * _mining_unit_value) * _mining_sell_return_ratio)
			_total_price_label.text = "出售 %d 台 · 返还 %s 算力币" % [resolved_quantity, _format_mining_value(sell_return)]
		else:
			_total_price_label.text = "购买 %d 台 · 需要 %s 算力币" % [resolved_quantity, _format_mining_value(resolved_quantity * _mining_unit_value)]
		return
	if _display_mode == DISPLAY_MODE_DEVELOPER_VALUE:
		_total_price_label.text = "当前选择：%d" % resolved_quantity
		return
	get_ok_button().disabled = false
	# 出售总价；单价乘当前数量，用于确认前即时预览金币收益。
	var total_sell_price: int = int(_unit_sell_price) * resolved_quantity
	_total_price_label.text = "可获得 %d 金币" % total_sell_price


func _on_confirmed() -> void:
	# 确认数量；从可直接输入的数字框读取，确保键盘最后一次修改被采用。
	var confirmed_quantity: int = clampi(roundi(_quantity_spin_box.value), _minimum_quantity, _maximum_quantity)
	quantity_confirmed.emit(confirmed_quantity)


func _get_mining_action_name() -> String:
	## 返回矿场操作的中文动词，用于数量弹窗标题和最大数量说明。
	if _mining_action == MINING_ACTION_SELL:
		return "出售"
	if _mining_action == MINING_ACTION_RECHARGE:
		return "充值"
	if _mining_action == MINING_ACTION_WITHDRAW:
		return "提现"
	return "购买"


func _format_mining_value(value: int) -> String:
	## 根据矿场具体数值开关格式化交易金额；仅改变文本，不改变数量或最终整数结算。
	if _mining_show_exact_values:
		return str(value)
	# 绝对值；决定当前应使用 K、M 或 B 单位。
	var absolute_value: int = absi(value)
	if absolute_value >= 1000000000:
		return "%.2fB" % (float(value) / 1000000000.0)
	if absolute_value >= 1000000:
		return "%.2fM" % (float(value) / 1000000.0)
	if absolute_value >= 10000:
		return "%.2fK" % (float(value) / 1000.0)
	return str(value)
