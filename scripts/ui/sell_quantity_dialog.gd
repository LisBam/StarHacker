extends ConfirmationDialog
class_name SellQuantityDialog

## 堆叠物品出售数量弹窗统一提供滑条和数字输入两种选择方式。
## 弹窗只负责数量展示与确认，不直接访问仓库、金币或存档服务。
## 跨容器移动补充；同一弹窗可切换移动模式，并继续保持不直接访问库存服务的职责边界。

signal quantity_confirmed(quantity: int)

## 出售数量模式标识；默认显示金币收益并使用“出售”确认按钮。
const DISPLAY_MODE_SALE: String = "sale"
## 移动数量模式标识；跨仓库和背包拖拽堆叠时显示移动方向与实际数量。
const DISPLAY_MODE_TRANSFER: String = "transfer"
## 丢弃数量模式标识；战斗背包部分丢弃时显示本次丢弃数量，不计算金币。
const DISPLAY_MODE_DISCARD: String = "discard"
## 物资送回数量模式标识；显示本次价值、20% 运费和送回后的剩余额度。
const DISPLAY_MODE_SHIPPING: String = "shipping"

## 弹窗默认宽度；默认 520 像素可容纳物品名称、数量滑条和数字输入框。
## 当前尺寸补充；默认值已调整为 400 像素以保持紧凑，仍可在检查器中按界面语言长度调整，运行时无需动态修改。
@export_range(320, 640, 1) var dialog_width: int = 400
## 弹窗默认高度；默认 170 像素，完整容纳说明、数量选择和结果摘要且避免遮挡仓库，运行时无需动态修改。
@export_range(140, 260, 1) var dialog_height: int = 170
## 弹窗背景透明度；默认 0.82，数值越低越透明，修改后会同时影响出售和移动数量界面，运行时无需动态修改。
@export_range(0.40, 1.0, 0.01) var dialog_background_alpha: float = 0.82

## 当前最大可出售数量；取值至少为 1，默认 1 用于弹窗尚未配置时的安全范围。
var _maximum_quantity: int = 1
## 当前单件售价；取值大于等于 0，默认 0 用于即时计算出售总价。
var _unit_sell_price: int = 0
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
## 数量滑条；默认运行时创建，取值范围与数字输入框保持双向同步。
var _quantity_slider: HSlider
## 数量数字输入框；默认运行时创建，玩家可键盘直接输入精确数量。
var _quantity_spin_box: SpinBox
## 总价标签；默认运行时创建，数量变化时即时显示将获得的金币。
var _total_price_label: Label
## 数量说明标签；默认运行时创建，显示当前物品名称和最大可出售数量。
var _description_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	transparent = true
	unresizable = true
	title = "选择出售数量"
	get_ok_button().text = "出售"
	get_cancel_button().text = "取消"
	_apply_dialog_visual_style()
	_build_interface()
	confirmed.connect(_on_confirmed)


func present(item_display_name: String, maximum_quantity: int, unit_sell_price: int) -> void:
	_display_mode = DISPLAY_MODE_SALE
	_item_display_name = item_display_name if not item_display_name.is_empty() else "物品"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = maxi(unit_sell_price, 0)
	title = "选择出售数量"
	get_ok_button().text = "出售"
	_description_label.text = "%s · 最多可出售 %d 个" % [_item_display_name, _maximum_quantity]
	_present_current_configuration()


func present_transfer(item_display_name: String, maximum_quantity: int, source_display_name: String, target_display_name: String) -> void:
	_display_mode = DISPLAY_MODE_TRANSFER
	_item_display_name = item_display_name if not item_display_name.is_empty() else "物品"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = 0
	title = "选择移动数量"
	get_ok_button().text = "移动"
	_description_label.text = "%s · %s → %s · 最多 %d 个" % [_item_display_name, source_display_name, target_display_name, _maximum_quantity]
	_present_current_configuration()


func present_discard(item_display_name: String, maximum_quantity: int) -> void:
	_display_mode = DISPLAY_MODE_DISCARD
	_item_display_name = item_display_name if not item_display_name.is_empty() else "物品"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = 0
	title = "选择丢弃数量"
	get_ok_button().text = "丢弃"
	_description_label.text = "%s · 最多可丢弃 %d 个" % [_item_display_name, _maximum_quantity]
	_present_current_configuration()


func present_shipping(item_display_name: String, maximum_quantity: int, unit_item_value: int, shipping_remaining_value: int, shipping_fee_ratio: float = 0.20) -> void:
	_display_mode = DISPLAY_MODE_SHIPPING
	_item_display_name = item_display_name if not item_display_name.is_empty() else "物品"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = 0
	_unit_item_value = maxi(unit_item_value, 0)
	_shipping_remaining_value = maxi(shipping_remaining_value, 0)
	_shipping_fee_ratio = clampf(shipping_fee_ratio, 0.0, 1.0)
	title = "选择送回数量"
	get_ok_button().text = "送回仓库"
	_description_label.text = "%s · 最多可选择 %d 个" % [_item_display_name, _maximum_quantity]
	_present_current_configuration()


func _present_current_configuration() -> void:
	_quantity_slider.max_value = _maximum_quantity
	_quantity_spin_box.max_value = _maximum_quantity
	_quantity_slider.set_value_no_signal(1.0)
	_quantity_spin_box.set_value_no_signal(1.0)
	_refresh_total_price(1)
	popup_centered(Vector2i(dialog_width, dialog_height))


func _build_interface() -> void:
	# 内容边距；紧凑留白避免控件贴近透明窗口边缘，同时减少弹窗整体占屏面积。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(content_margin)
	# 内容容器；纵向排列说明、滑条、数字输入和总价信息。
	# 移动模式补充；最后一行在移动模式下改为显示实际移动数量。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content_margin.add_child(content)
	_description_label = Label.new()
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
	var dialog_theme: Theme = Theme.new()
	# 弹窗面板样式；透明度由检查器参数统一控制，便于后续按整体 UI 风格调整。
	var dialog_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	dialog_panel_style.bg_color = Color(0.035, 0.045, 0.055, dialog_background_alpha)
	dialog_panel_style.border_color = Color(0.30, 0.50, 0.60, minf(dialog_background_alpha + 0.10, 1.0))
	dialog_panel_style.set_border_width_all(1)
	dialog_panel_style.set_corner_radius_all(8)
	dialog_theme.set_stylebox("panel", "Window", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "AcceptDialog", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "ConfirmationDialog", dialog_panel_style)
	theme = dialog_theme


func _on_slider_value_changed(value: float) -> void:
	# 标准化数量；滑条只使用整数步长，仍显式取整以避免浮点回调误差。
	var resolved_quantity: int = clampi(roundi(value), 1, _maximum_quantity)
	_quantity_spin_box.set_value_no_signal(float(resolved_quantity))
	_refresh_total_price(resolved_quantity)


func _on_spin_box_value_changed(value: float) -> void:
	# 标准化数量；直接输入会被限制在 1 到当前堆叠数量内。
	var resolved_quantity: int = clampi(roundi(value), 1, _maximum_quantity)
	_quantity_slider.set_value_no_signal(float(resolved_quantity))
	_refresh_total_price(resolved_quantity)


func _refresh_total_price(quantity: int) -> void:
	# 有效数量；滑条和数字框始终限制在当前堆叠范围，摘要只读取该标准化结果。
	var resolved_quantity: int = clampi(quantity, 1, _maximum_quantity)
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
	get_ok_button().disabled = false
	# 出售总价；单价乘当前数量，用于确认前即时预览金币收益。
	var total_sell_price: int = _unit_sell_price * resolved_quantity
	_total_price_label.text = "可获得 %d 金币" % total_sell_price


func _on_confirmed() -> void:
	# 确认数量；从可直接输入的数字框读取，确保键盘最后一次修改被采用。
	var confirmed_quantity: int = clampi(roundi(_quantity_spin_box.value), 1, _maximum_quantity)
	quantity_confirmed.emit(confirmed_quantity)
