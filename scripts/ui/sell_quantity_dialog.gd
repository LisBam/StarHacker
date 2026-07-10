extends ConfirmationDialog
class_name SellQuantityDialog

## 堆叠物品出售数量弹窗统一提供滑条和数字输入两种选择方式。
## 弹窗只负责数量展示与确认，不直接访问仓库、金币或存档服务。

signal quantity_confirmed(quantity: int)

## 弹窗默认宽度；默认 520 像素可容纳物品名称、数量滑条和数字输入框。
@export_range(360, 900, 1) var dialog_width: int = 520

## 当前最大可出售数量；取值至少为 1，默认 1 用于弹窗尚未配置时的安全范围。
var _maximum_quantity: int = 1
## 当前单件售价；取值大于等于 0，默认 0 用于即时计算出售总价。
var _unit_sell_price: int = 0
## 当前物品显示名称；默认“物品”，配置后用于标题说明本次出售目标。
var _item_display_name: String = "物品"
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
	title = "选择出售数量"
	get_ok_button().text = "出售"
	get_cancel_button().text = "取消"
	_build_interface()
	confirmed.connect(_on_confirmed)


func present(item_display_name: String, maximum_quantity: int, unit_sell_price: int) -> void:
	_item_display_name = item_display_name if not item_display_name.is_empty() else "物品"
	_maximum_quantity = maxi(maximum_quantity, 1)
	_unit_sell_price = maxi(unit_sell_price, 0)
	_description_label.text = "%s · 最多可出售 %d 个" % [_item_display_name, _maximum_quantity]
	_quantity_slider.max_value = _maximum_quantity
	_quantity_spin_box.max_value = _maximum_quantity
	_quantity_slider.set_value_no_signal(1.0)
	_quantity_spin_box.set_value_no_signal(1.0)
	_refresh_total_price(1)
	popup_centered(Vector2i(dialog_width, 0))


func _build_interface() -> void:
	# 内容容器；纵向排列说明、滑条、数字输入和总价信息。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_description_label)
	# 数量选择行；滑条占据主要宽度，数字输入框用于精确键盘输入。
	var quantity_row: HBoxContainer = HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation", 12)
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
	_quantity_spin_box.custom_minimum_size = Vector2(112.0, 38.0)
	_quantity_spin_box.value_changed.connect(_on_spin_box_value_changed)
	quantity_row.add_child(_quantity_spin_box)
	_total_price_label = Label.new()
	_total_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_price_label.add_theme_font_size_override("font_size", 18)
	content.add_child(_total_price_label)


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
	# 出售总价；单价乘当前数量，用于确认前即时预览金币收益。
	var total_sell_price: int = _unit_sell_price * clampi(quantity, 1, _maximum_quantity)
	_total_price_label.text = "可获得 %d 金币" % total_sell_price


func _on_confirmed() -> void:
	# 确认数量；从可直接输入的数字框读取，确保键盘最后一次修改被采用。
	var confirmed_quantity: int = clampi(roundi(_quantity_spin_box.value), 1, _maximum_quantity)
	quantity_confirmed.emit(confirmed_quantity)
