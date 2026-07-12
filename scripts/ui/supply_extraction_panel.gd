extends PanelContainer
class_name SupplyExtractionPanel

## 物资撤离面板在暂停状态下展示玩家背包、装备栏、金币与单局剩余送回价值。
## 面板只通过 GlobalInventory 的报价和原子送回接口修改所有权，数量选择复用仓库已有 UI。

signal closed

## 仓库物品卡片脚本；背包和装备栏统一复用完整详情、灰色滤镜与点击协议。
const STORAGE_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/storage_item_control.gd")
## 标准物品操作弹窗脚本；送回操作与背包丢弃、仓库出售复用同一功能按钮视觉资源。
const ITEM_ACTION_POPUP_SCRIPT: Script = preload("res://scripts/ui/item_action_popup.gd")
## 数量选择弹窗脚本；堆叠物品部分送回仓库时复用出售数量 UI。
const SELL_QUANTITY_DIALOG_SCRIPT: Script = preload("res://scripts/ui/sell_quantity_dialog.gd")
## 全局窗口样式指南；统一物资撤离窗口、规则说明、分区和操作控件视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 全部送回操作编号；单件物品和整组堆叠共同使用。
const ACTION_SEND_ALL: int = 1
## 部分送回操作编号；只在堆叠数量大于 1 时显示。
const ACTION_SEND_PARTIAL: int = 2
## 背包来源标识；与 GlobalInventory 公开接口保持一致。
const SOURCE_BACKPACK: String = "backpack"
## 近战装备来源标识；与 GlobalInventory 唯一近战槽位置保持一致。
const SOURCE_MELEE: String = "melee"
## 远程装备来源前缀；与 GlobalInventory 的 ranged_0、ranged_1 位置保持一致。
const SOURCE_RANGED_PREFIX: String = "ranged_"

## 面板最小尺寸；默认 920×620，暂停时居中显示并保留屏幕边缘空间。
@export var panel_minimum_size: Vector2 = Vector2(920.0, 620.0)

## 全局库存服务；负责报价、金币、额度、背包、装备和仓库所有权转移。
var _global_inventory: Node
## 金币文本；每次送回后即时刷新当前余额。
var _coins_label: Label
## 剩余送回价值文本；默认显示 1000，所有物资撤离点共用同一单局额度。
var _remaining_value_label: Label
## 装备栏网格；默认三列，展示两个远程槽和一个近战槽中的非空武器。
var _equipment_grid: GridContainer
## 背包物品网格；默认两列，展示全部武器与可堆叠资源。
var _backpack_grid: GridContainer
## 标准物品操作弹窗；根据堆叠数量显示“送回仓库”或“全部/部分送回仓库”。
var _action_menu: ItemActionPopup
## 数量选择弹窗；部分送回仓库时显示价值、运费和送回后剩余额度。
var _quantity_dialog: ConfirmationDialog
## 当前操作物品；默认 null，菜单关闭不会改变所有权。
var _action_resource: Resource
## 当前操作来源；取值为 backpack、ranged_N 或 melee，默认空字符串。
var _action_source_location: String = ""
## 当前操作物品数量；默认 1，背包堆叠资源读取真实数量。
var _action_quantity: int = 1
## 当前等待部分送回确认的物品；默认 null，数量确认后再次向全局服务报价。
var _pending_partial_resource: Resource
## 当前等待部分送回确认的来源；默认空字符串，与待确认资源共同定位所有权。
var _pending_partial_source_location: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = panel_minimum_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_build_interface()
	visible = false


func configure(global_inventory: Node) -> void:
	_global_inventory = global_inventory
	_connect_inventory_signals()
	_refresh_all()


func present() -> void:
	_refresh_all()
	visible = true


func dismiss() -> void:
	# 关闭面板自身可见状态，避免父遮罩隐藏后该控件继续在后台接收并吞掉后续 ESC 输入。
	visible = false
	if _action_menu != null:
		_action_menu.hide()
	if _quantity_dialog != null:
		_quantity_dialog.hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	# 外层边距；保证标题、状态、装备与背包列表不会贴近面板边缘。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	# 主内容；状态栏、装备栏和背包列表纵向排列。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	# 标题栏；横向展示标题、金币、剩余额度与关闭按钮。
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	# 面板标题；占据剩余水平空间，防止状态文本挤压。
	var title_label: Label = Label.new()
	title_label.text = "物资撤离点"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 25)
	UI_STYLE_GUIDE.apply_title_label(title_label)
	header.add_child(title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 17)
	header.add_child(_coins_label)
	_remaining_value_label = Label.new()
	_remaining_value_label.add_theme_font_size_override("font_size", 17)
	header.add_child(_remaining_value_label)
	# 关闭按钮；退出面板后由 CombatHud 解除暂停并恢复战斗输入。
	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(90.0, 36.0)
	close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_button)
	# 规则说明；长期展示运费比例和单局价值上限，避免玩家误解灰色滤镜原因。
	var rule_label: Label = Label.new()
	rule_label.text = "点击物品送回局外仓库 · 运费为物品价值的20% · 单局最多送回1000价值"
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(rule_label)
	# 装备栏标题；与背包区域使用分隔线区分所有权来源。
	var equipment_title: Label = Label.new()
	equipment_title.text = "武器栏"
	equipment_title.add_theme_font_size_override("font_size", 18)
	content.add_child(equipment_title)
	_equipment_grid = GridContainer.new()
	_equipment_grid.columns = 3
	_equipment_grid.add_theme_constant_override("h_separation", 8)
	_equipment_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(_equipment_grid)
	# 装备与背包分隔线；明确两类来源都可直接送回仓库。
	var separator: HSeparator = HSeparator.new()
	content.add_child(separator)
	# 背包标题；下方滚动区展示全部随身物品。
	var backpack_title: Label = Label.new()
	backpack_title.text = "随身背包"
	backpack_title.add_theme_font_size_override("font_size", 18)
	content.add_child(backpack_title)
	# 背包滚动容器；物品较多时继续访问全部条目而不扩大面板。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_backpack_grid = GridContainer.new()
	_backpack_grid.columns = 2
	_backpack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_grid.add_theme_constant_override("h_separation", 8)
	_backpack_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_backpack_grid)
	_action_menu = ITEM_ACTION_POPUP_SCRIPT.new() as ItemActionPopup
	_action_menu.action_pressed.connect(_on_action_menu_id_pressed)
	add_child(_action_menu)
	_quantity_dialog = SELL_QUANTITY_DIALOG_SCRIPT.new() as ConfirmationDialog
	_quantity_dialog.connect("quantity_confirmed", Callable(self, "_on_quantity_confirmed"))
	add_child(_quantity_dialog)


func _connect_inventory_signals() -> void:
	if _global_inventory == null:
		return
	for signal_name in ["inventory_changed", "equipment_changed", "coins_changed"]:
		if _global_inventory.has_signal(signal_name) and not _global_inventory.is_connected(signal_name, Callable(self, "_on_inventory_state_changed")):
			_global_inventory.connect(signal_name, Callable(self, "_on_inventory_state_changed"))


func _refresh_all() -> void:
	if _coins_label == null or _remaining_value_label == null:
		return
	_coins_label.text = "金币：%d" % int(_global_inventory.call("get_coins")) if _global_inventory != null else "金币：--"
	_remaining_value_label.text = "剩余送回价值：%d" % int(_global_inventory.call("get_combat_shipping_remaining_value")) if _global_inventory != null else "剩余送回价值：--"
	_rebuild_equipment_items()
	_rebuild_backpack_items()


func _rebuild_equipment_items() -> void:
	_clear_container(_equipment_grid)
	if _global_inventory == null:
		return
	# 远程装备槽；空槽显示占位文本，非空武器按其稳定装备位置建立可送回卡片。
	var ranged_slot_count: int = int(_global_inventory.call("get_ranged_slot_count"))
	for slot_index in range(ranged_slot_count):
		# 当前远程装备；空资源会生成不可操作占位卡。
		var ranged_resource: Resource = _global_inventory.call("get_ranged_equipment_resource", slot_index) as Resource
		_add_item_card(_equipment_grid, ranged_resource, "%s%d" % [SOURCE_RANGED_PREFIX, slot_index], 1, "远程%d空" % (slot_index + 1))
	# 当前近战装备；唯一近战槽使用 melee 稳定来源标识。
	var melee_resource: Resource = _global_inventory.call("get_melee_equipment_resource") as Resource
	_add_item_card(_equipment_grid, melee_resource, SOURCE_MELEE, 1, "近战空")


func _rebuild_backpack_items() -> void:
	_clear_container(_backpack_grid)
	if _global_inventory == null:
		return
	# 背包条目；每项包含资源和真实堆叠数量，界面不直接修改字典。
	var backpack_entries: Array = _global_inventory.call("get_backpack_entries")
	if backpack_entries.is_empty():
		# 空背包提示；占据一行并保持居中，避免网格完全无内容。
		var empty_label: Label = Label.new()
		empty_label.text = "背包为空"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0.0, 54.0)
		_backpack_grid.add_child(empty_label)
		return
	for raw_entry in backpack_entries:
		if not (raw_entry is Dictionary):
			continue
		# 当前背包条目；用于提取资源和堆叠数量。
		var entry: Dictionary = raw_entry as Dictionary
		_add_item_card(_backpack_grid, entry.get("resource") as Resource, SOURCE_BACKPACK, maxi(int(entry.get("quantity", 1)), 1), "")


func _add_item_card(parent_grid: GridContainer, item_resource: Resource, source_location: String, quantity: int, empty_text: String) -> void:
	if item_resource == null:
		# 空装备槽卡片；只显示来源占位且不可点击。
		var empty_button: Button = Button.new()
		empty_button.text = empty_text
		empty_button.disabled = true
		empty_button.custom_minimum_size = Vector2(0.0, 54.0)
		empty_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent_grid.add_child(empty_button)
		return
	# 最少一件报价；卡片只有在至少能送回一个单位时可点击，整组超额仍可通过部分送回继续操作。
	var minimum_quote: Dictionary = _global_inventory.call("get_combat_shipping_quote", item_resource, source_location, 1) as Dictionary
	# 当前展示数量报价；卡片显示整件或整组物品实际需要支付的撤离收费，悬停详情仍展示出售价格。
	var display_quote: Dictionary = _global_inventory.call("get_combat_shipping_quote", item_resource, source_location, quantity) as Dictionary
	# 当前撤离收费；取值为物品当前有效价值的 20% 向上取整。
	var extraction_fee: int = maxi(int(display_quote.get("fee", 0)), 0)
	# 物品卡片；复用仓库详情和灰色滤镜，但关闭拖拽以限定为送回操作。
	var item_control: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
	item_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_control.call("configure", item_resource, source_location, 0, false, "", quantity, "撤离收费", extraction_fee)
	item_control.call("set_drag_enabled", false)
	item_control.call("set_item_selection_state", true, bool(minimum_quote.get("selectable", false)), false)
	item_control.connect("item_action_requested", Callable(self, "_on_item_action_requested").bind(source_location, quantity))
	parent_grid.add_child(item_control)


func _on_item_action_requested(item_resource: Resource, source_location: String, quantity: int) -> void:
	_action_resource = item_resource
	_action_source_location = source_location
	_action_quantity = maxi(quantity, 1)
	_action_menu.clear_actions()
	if _action_quantity > 1:
		# 整组报价；超出金币或剩余额度时仅禁用全部送回，仍保留部分送回入口。
		var full_quote: Dictionary = _global_inventory.call("get_combat_shipping_quote", item_resource, source_location, _action_quantity) as Dictionary
		_action_menu.add_action("全部送回仓库", ACTION_SEND_ALL, not bool(full_quote.get("selectable", false)))
		_action_menu.add_action("部分送回仓库", ACTION_SEND_PARTIAL)
	else:
		_action_menu.add_action("送回仓库", ACTION_SEND_ALL)
	_action_menu.popup_at(get_viewport().get_mouse_position())


func _on_action_menu_id_pressed(action_id: int) -> void:
	if _action_resource == null or _global_inventory == null:
		return
	if action_id == ACTION_SEND_ALL:
		_send_resource_to_warehouse(_action_resource, _action_source_location, _action_quantity)
	elif action_id == ACTION_SEND_PARTIAL:
		# 最大可送回数量；同时受真实堆叠、金币和剩余价值额度限制。
		var maximum_quantity: int = _get_maximum_shippable_quantity(_action_resource, _action_source_location, _action_quantity)
		if maximum_quantity <= 0:
			return
		_pending_partial_resource = _action_resource
		_pending_partial_source_location = _action_source_location
		# 单件物品价值；武器使用强化和耐久后的有效售价，资源使用固定售价。
		var unit_value: int = int(_action_resource.call("get_effective_sell_price")) if _action_resource.has_method("get_effective_sell_price") else maxi(int(_action_resource.get("sell_price")), 0)
		_quantity_dialog.call("present_shipping", str(_action_resource.get("display_name")), maximum_quantity, unit_value, int(_global_inventory.call("get_combat_shipping_remaining_value")), 0.20)


func _get_maximum_shippable_quantity(item_resource: Resource, source_location: String, stored_quantity: int) -> int:
	# 最大可送回数量；逐个报价同时考虑 1000 价值额度和向上取整后的 20% 运费，堆叠上限仅 99，遍历成本稳定。
	var maximum_quantity: int = 0
	for quantity in range(1, maxi(stored_quantity, 1) + 1):
		# 当前数量报价；首次不可选后更大数量也不会恢复，因此可提前结束遍历。
		var quote: Dictionary = _global_inventory.call("get_combat_shipping_quote", item_resource, source_location, quantity) as Dictionary
		if not bool(quote.get("selectable", false)):
			break
		maximum_quantity = quantity
	return maximum_quantity


func _on_quantity_confirmed(quantity: int) -> void:
	if _pending_partial_resource == null:
		return
	# 已确认物品；读取后立即清空等待状态，防止弹窗重复信号二次执行。
	var item_resource: Resource = _pending_partial_resource
	# 已确认来源；与资源实例共同定位背包堆叠。
	var source_location: String = _pending_partial_source_location
	_pending_partial_resource = null
	_pending_partial_source_location = ""
	_send_resource_to_warehouse(item_resource, source_location, quantity)


func _send_resource_to_warehouse(item_resource: Resource, source_location: String, quantity: int) -> void:
	# 原子送回结果；服务会再次复核金币、额度、数量和来源所有权。
	var result: Dictionary = _global_inventory.call("ship_combat_resource_to_warehouse", item_resource, source_location, quantity) as Dictionary
	if bool(result.get("success", false)):
		_action_resource = null
		_action_source_location = ""
		_action_quantity = 1
	_refresh_all()


func _on_inventory_state_changed() -> void:
	if visible:
		_refresh_all()


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
