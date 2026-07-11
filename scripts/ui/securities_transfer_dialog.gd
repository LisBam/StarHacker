extends ConfirmationDialog
class_name SecuritiesTransferDialog

## 证券币转账弹窗只负责整数充值或提现金额输入，不直接读取金币、证券币或存档服务。
## 宿主负责提供当前最大额度并在确认后调用股市服务执行最终原子校验。

signal transfer_confirmed(amount: int, is_deposit: bool)

## 弹窗默认宽度；默认 400 像素，与股票买卖数量窗口保持一致，运行时无需动态修改。
@export_range(320, 640, 1) var dialog_width: int = 400
## 弹窗默认高度；默认 170 像素，与股票买卖数量窗口保持一致并完整容纳滑条、数字输入和结果摘要，运行时无需动态修改。
@export_range(140, 260, 1) var dialog_height: int = 170
## 弹窗背景透明度；默认 0.82，与股票数量选择弹窗保持一致，运行时无需动态修改。
@export_range(0.40, 1.0, 0.01) var dialog_background_alpha: float = 0.82

## 当前是否为充值模式；默认 true，false 表示把整数证券币提现为永久金币。
var _is_deposit: bool = true
## 当前最大可转账整数数量；默认 1，由宿主按金币或证券币余额提供。
var _maximum_amount: int = 1
## 当前最小可转账整数数量；默认 1，提现模式由服务提供至少到账 1 金币所需门槛。
var _minimum_amount: int = 1
## 当前提现手续费比例；默认 0.005 即 0.5%，充值模式不使用该值扣费。
var _withdrawal_fee_ratio: float = 0.005
## 金额滑条；默认运行时创建，使用整数步长并与数字输入框保持双向同步。
var _amount_slider: HSlider
## 金额输入框；默认运行时创建，只允许输入最小到最大额度之间的整数，并与滑条保持双向同步。
var _amount_spin_box: SpinBox
## 兑换说明标签；默认运行时创建，显示方向、最大额度和 1:1 基础兑换规则。
var _description_label: Label
## 兑换结果标签；默认运行时创建，充值显示到账证券币，提现显示手续费和整数金币到账额。
var _result_label: Label
## 界面是否已经初始化；默认 false，公开展示接口会通过幂等初始化保证控件可用。
var _interface_initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_interface_initialized()


func present_deposit(maximum_amount: int) -> void:
	## 展示金币充值界面；输入单位为整数金币，证券币按 1:1 增加相同数值。
	_ensure_interface_initialized()
	_is_deposit = true
	_maximum_amount = maxi(maximum_amount, 1)
	_minimum_amount = 1
	_withdrawal_fee_ratio = 0.0
	title = "充值证券币"
	get_ok_button().text = "确认充值"
	_description_label.text = "金币 1:1 转入证券币 · 最多可充值 %d" % maximum_amount
	_present_current_configuration()


func present_withdrawal(maximum_amount: int, withdrawal_fee_ratio: float, minimum_amount: int = 1) -> void:
	## 展示证券币提现界面；只允许整数证券币，到账金币为扣除手续费后的向下取整结果。
	_ensure_interface_initialized()
	_is_deposit = false
	_maximum_amount = maxi(maximum_amount, 1)
	_minimum_amount = clampi(minimum_amount, 1, _maximum_amount)
	_withdrawal_fee_ratio = clampf(withdrawal_fee_ratio, 0.0, 1.0)
	title = "提现证券币"
	get_ok_button().text = "确认提现"
	_description_label.text = "整数证券币提现为金币 · 最多可提现 %d" % maximum_amount
	_present_current_configuration()


func _ensure_interface_initialized() -> void:
	## 初始化转账输入控件与统一视觉；允许弹窗创建后同一帧直接调用展示接口。
	if _interface_initialized:
		return
	_interface_initialized = true
	transparent = true
	unresizable = true
	get_cancel_button().text = "取消"
	_apply_dialog_visual_style()
	_build_interface()
	confirmed.connect(_on_confirmed)


func _present_current_configuration() -> void:
	## 重置输入范围和默认金额；每次打开均从 1 开始，避免沿用上次大额输入造成误操作。
	_amount_slider.min_value = float(_minimum_amount)
	_amount_slider.max_value = float(_maximum_amount)
	_amount_spin_box.min_value = float(_minimum_amount)
	_amount_spin_box.max_value = float(_maximum_amount)
	_amount_slider.set_value_no_signal(float(_minimum_amount))
	_amount_spin_box.set_value_no_signal(float(_minimum_amount))
	_refresh_result(_minimum_amount)
	popup_centered(Vector2i(dialog_width, dialog_height))


func _build_interface() -> void:
	## 创建固定内容结构；纵向排列规则说明、整数输入和到账摘要。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(content_margin)
	# 内容容器；统一使用 8 像素间距保持紧凑且可读。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content_margin.add_child(content)
	_description_label = Label.new()
	# 自动换行基准宽度；动态 Window 首次布局前没有可用父级宽度，显式提供宽度可避免文字按 1 像素宽逐字换行并撑高窗口。
	_description_label.custom_minimum_size = Vector2(float(dialog_width - 48), 0.0)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_description_label)
	# 金额输入行；滑条负责快速选择，数字输入框负责键盘精确输入，与股票买卖数量窗口保持一致。
	var amount_row: HBoxContainer = HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 8)
	content.add_child(amount_row)
	_amount_slider = HSlider.new()
	_amount_slider.min_value = 1.0
	_amount_slider.max_value = 1.0
	_amount_slider.step = 1.0
	_amount_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amount_slider.value_changed.connect(_on_amount_slider_changed)
	amount_row.add_child(_amount_slider)
	_amount_spin_box = SpinBox.new()
	_amount_spin_box.min_value = 1.0
	_amount_spin_box.max_value = 1.0
	_amount_spin_box.step = 1.0
	_amount_spin_box.allow_greater = false
	_amount_spin_box.allow_lesser = false
	_amount_spin_box.custom_minimum_size = Vector2(82.0, 32.0)
	_amount_spin_box.value_changed.connect(_on_amount_spin_box_changed)
	amount_row.add_child(_amount_spin_box)
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_result_label)


func _apply_dialog_visual_style() -> void:
	## 应用半透明深色窗口样式；规格与股票数量弹窗一致，保持转账入口视觉统一。
	var dialog_theme: Theme = Theme.new()
	# 窗口面板样式；透明度由检查器参数统一控制。
	var dialog_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	dialog_panel_style.bg_color = Color(0.035, 0.045, 0.055, dialog_background_alpha)
	dialog_panel_style.border_color = Color(0.30, 0.50, 0.60, minf(dialog_background_alpha + 0.10, 1.0))
	dialog_panel_style.set_border_width_all(1)
	dialog_panel_style.set_corner_radius_all(8)
	dialog_theme.set_stylebox("panel", "Window", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "AcceptDialog", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "ConfirmationDialog", dialog_panel_style)
	theme = dialog_theme


func _on_amount_slider_changed(value: float) -> void:
	## 同步滑条选择到数字框；显式取整保证转账金额始终为整数。
	var resolved_amount: int = clampi(roundi(value), _minimum_amount, _maximum_amount)
	_amount_spin_box.set_value_no_signal(float(resolved_amount))
	_refresh_result(resolved_amount)


func _on_amount_spin_box_changed(value: float) -> void:
	## 同步数字输入到滑条；直接键盘输入同样限制在当前合法额度内。
	var resolved_amount: int = clampi(roundi(value), _minimum_amount, _maximum_amount)
	_amount_slider.set_value_no_signal(float(resolved_amount))
	_refresh_result(resolved_amount)


func _refresh_result(amount: int) -> void:
	## 刷新转账结果摘要；提现手续费和到账额仅作预览，最终结果由股市服务重新计算。
	var resolved_amount: int = clampi(amount, _minimum_amount, _maximum_amount)
	if _is_deposit:
		_result_label.text = "消耗 %d 金币 · 到账 %.2f 证券币" % [resolved_amount, float(resolved_amount)]
		get_ok_button().disabled = false
		return
	# 提现手续费；证券币支持两位小数，因此预览保留两位，不向整数取整。
	# 手续费进位规则；乘 100 后向上取整，与股市服务的最终提现费用保持完全一致。
	var withdrawal_fee: float = maxf(float(ceili(maxf(float(resolved_amount) * _withdrawal_fee_ratio * 100.0 - 0.000001, 0.0))) / 100.0, 0.01)
	# 实际到账金币；外部金币只支持整数，扣费后的小数部分留在本次手续费中并向下取整到账。
	var received_coins: int = floori(float(resolved_amount) - withdrawal_fee)
	_result_label.text = "手续费 %.2f 证券币 · 到账 %d 金币" % [withdrawal_fee, received_coins]
	get_ok_button().disabled = received_coins <= 0


func _on_confirmed() -> void:
	## 发出最终整数金额和兑换方向；宿主必须重新校验余额，避免弹窗期间其他操作改变资产。
	var confirmed_amount: int = clampi(roundi(_amount_spin_box.value), _minimum_amount, _maximum_amount)
	transfer_confirmed.emit(confirmed_amount, _is_deposit)
