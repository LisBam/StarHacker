extends PanelContainer
class_name MainMenuBackpackPanel

## 主菜单背包面板复用战斗背包的“左侧装备栏 + 右侧随身物品”结构和标准物品卡片。
## 局外没有地面掉落容器，因此丢弃操作直接永久移除对应背包记录，不生成可重新拾取的物品。

signal closed

## 仓库物品卡片脚本；随身物品复用完整详情、耐久条、点击和悬停交互。
const STORAGE_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/storage_item_control.gd")
## 装备槽控件脚本；远程、近战和四部位装备复用游戏内背包左侧卡片布局。
const EQUIPMENT_STORAGE_SLOT_SCRIPT: Script = preload("res://scripts/ui/equipment_storage_slot_control.gd")
## 标准物品操作弹窗脚本；装备和丢弃操作复用全项目功能按钮资源。
const ITEM_ACTION_POPUP_SCRIPT: Script = preload("res://scripts/ui/item_action_popup.gd")
## 数量选择弹窗脚本；堆叠物品部分丢弃时复用战斗背包相同数量输入界面。
const SELL_QUANTITY_DIALOG_SCRIPT: Script = preload("res://scripts/ui/sell_quantity_dialog.gd")
## 装备操作编号；背包武器或装备点击后按类型进入对应装备槽。
const ACTION_EQUIP: int = 1
## 远程装备槽一操作编号；远程武器可明确选择第一个远程槽。
const ACTION_EQUIP_RANGED_ONE: int = 2
## 远程装备槽二操作编号；远程武器可明确选择第二个远程槽。
const ACTION_EQUIP_RANGED_TWO: int = 3
## 全部丢弃操作编号；单件物品和整组堆叠共同使用。
const ACTION_DISCARD_ALL: int = 4
## 部分丢弃操作编号；只在堆叠数量大于一时显示。
const ACTION_DISCARD_PARTIAL: int = 5

## 面板最小尺寸；与战斗背包接近，确保左侧七个装备槽和右侧物品网格可读。
@export var panel_minimum_size: Vector2 = Vector2(960.0, 620.0)

## 全局库存服务；负责背包、装备栏、直接丢弃和持久化。
var _global_inventory: Node
## 左侧装备栏列表；每次装备变化后完整重建，保持槽位顺序稳定。
var _equipment_list: VBoxContainer
## 右侧背包物品网格；按真实背包顺序显示全部物品。
var _item_grid: HFlowContainer
## 标准物品操作弹窗；根据当前物品类型生成装备和丢弃功能按钮。
var _action_popup: ItemActionPopup
## 部分丢弃数量弹窗；确认后从背包直接消费选择数量。
var _quantity_dialog: ConfirmationDialog
## 当前操作物品；弹窗关闭前保持精确资源实例引用。
var _action_resource: Resource
## 当前操作物品真实数量；用于决定全部或部分丢弃入口。
var _action_quantity: int = 1
## 等待部分丢弃的资源；数量确认后读取并立即清空，防止重复确认。
var _pending_partial_resource: Resource


func _ready() -> void:
	custom_minimum_size = panel_minimum_size
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	_connect_inventory_signals()
	_refresh_all()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	# 外层边距；与战斗背包保持足够留白，避免卡片贴边。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	# 主内容；标题栏位于顶部，装备与背包使用左右分栏填充剩余区域。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var header: HBoxContainer = HBoxContainer.new()
	content.add_child(header)
	var title_label: Label = Label.new()
	title_label.text = "背包"
	title_label.add_theme_font_size_override("font_size", 25)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var warning_label: Label = Label.new()
	warning_label.text = "局外丢弃会直接永久失去物品"
	warning_label.modulate = Color(1.0, 0.55, 0.55, 1.0)
	header.add_child(warning_label)
	var close_button: Button = Button.new()
	close_button.text = "关闭背包"
	close_button.custom_minimum_size = Vector2(116.0, 36.0)
	close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_button)
	# 左右分栏；左侧固定装备栏，右侧背包物品独立滚动。
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 205
	content.add_child(split)
	var equipment_panel: PanelContainer = PanelContainer.new()
	equipment_panel.custom_minimum_size = Vector2(196.0, 0.0)
	split.add_child(equipment_panel)
	var equipment_scroll: ScrollContainer = ScrollContainer.new()
	equipment_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equipment_panel.add_child(equipment_scroll)
	_equipment_list = VBoxContainer.new()
	_equipment_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_equipment_list.add_theme_constant_override("separation", 6)
	equipment_scroll.add_child(_equipment_list)
	var backpack_panel: PanelContainer = PanelContainer.new()
	backpack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(backpack_panel)
	var backpack_scroll: ScrollContainer = ScrollContainer.new()
	backpack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	backpack_panel.add_child(backpack_scroll)
	_item_grid = HFlowContainer.new()
	_item_grid.alignment = FlowContainer.ALIGNMENT_CENTER
	_item_grid.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.add_theme_constant_override("h_separation", 10)
	_item_grid.add_theme_constant_override("v_separation", 8)
	backpack_scroll.add_child(_item_grid)
	_action_popup = ITEM_ACTION_POPUP_SCRIPT.new() as ItemActionPopup
	_action_popup.action_pressed.connect(_on_action_pressed)
	add_child(_action_popup)
	_quantity_dialog = SELL_QUANTITY_DIALOG_SCRIPT.new() as ConfirmationDialog
	_quantity_dialog.connect("quantity_confirmed", Callable(self, "_on_quantity_confirmed"))
	add_child(_quantity_dialog)


func _connect_inventory_signals() -> void:
	if _global_inventory == null:
		return
	for signal_name in ["inventory_changed", "equipment_changed"]:
		if _global_inventory.has_signal(signal_name):
			_global_inventory.connect(signal_name, Callable(self, "_refresh_all"))


func _refresh_all() -> void:
	_rebuild_equipment()
	_rebuild_items()


func _rebuild_equipment() -> void:
	_clear_container(_equipment_list)
	if _global_inventory == null:
		return
	for slot_index in range(int(_global_inventory.call("get_ranged_slot_count"))):
		_add_equipment_slot("远程 %d" % (slot_index + 1), "ranged_%d" % slot_index, "ranged")
	_add_equipment_slot("近战", "melee", "melee")
	for armor_slot in ["head", "body", "legs", "feet"]:
		_add_equipment_slot({"head": "头部", "body": "躯干", "legs": "腿部", "feet": "脚部"}[armor_slot], "armor_" + armor_slot, armor_slot)


func _add_equipment_slot(slot_label: String, location: String, accepted_type: String) -> void:
	# 装备资源；空槽同样显示，确保主菜单背包与游戏内背包槽位结构一致。
	var item_resource: Resource = _global_inventory.call("get_equipment_location_resource", location) as Resource
	var slot_control: Button = EQUIPMENT_STORAGE_SLOT_SCRIPT.new() as Button
	slot_control.call("configure", slot_label, location, accepted_type, item_resource)
	_equipment_list.add_child(slot_control)


func _rebuild_items() -> void:
	_clear_container(_item_grid)
	if _global_inventory == null:
		return
	var entries: Array = _global_inventory.call("get_backpack_entries")
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index] as Dictionary
		var item_resource: Resource = entry.get("resource") as Resource
		if item_resource == null:
			continue
		var item_control: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
		item_control.call("configure", item_resource, "backpack", entry_index, false, "", int(entry.get("quantity", 1)))
		item_control.call("set_weapon_slot_visual_style", true)
		item_control.connect("item_action_requested", Callable(self, "_on_item_pressed"))
		_item_grid.add_child(item_control)
	if entries.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "背包为空"
		_item_grid.add_child(empty_label)


func _on_item_pressed(item_resource: Resource) -> void:
	_action_resource = item_resource
	_action_quantity = int(_global_inventory.call("get_storage_resource_quantity", item_resource, "backpack")) if _global_inventory != null else 1
	_action_popup.clear_actions()
	if str(item_resource.get("item_kind")) == "equipment" or str(item_resource.get("weapon_type")) == "melee":
		_action_popup.add_action("装备", ACTION_EQUIP)
	elif str(item_resource.get("weapon_type")) == "ranged":
		_action_popup.add_action("装备1", ACTION_EQUIP_RANGED_ONE)
		_action_popup.add_action("装备2", ACTION_EQUIP_RANGED_TWO)
	if _action_quantity > 1:
		_action_popup.add_action("全部丢弃", ACTION_DISCARD_ALL, false, true)
		_action_popup.add_action("部分丢弃", ACTION_DISCARD_PARTIAL, false, true)
	else:
		_action_popup.add_action("丢弃", ACTION_DISCARD_ALL, false, true)
	_action_popup.popup_at(get_viewport().get_mouse_position())


func _on_action_pressed(action_id: int) -> void:
	if _global_inventory == null or _action_resource == null:
		return
	if action_id in [ACTION_EQUIP, ACTION_EQUIP_RANGED_ONE, ACTION_EQUIP_RANGED_TWO]:
		var target_location: String = ""
		if str(_action_resource.get("item_kind")) == "equipment":
			target_location = "armor_" + str(_action_resource.get("equipment_slot"))
		elif str(_action_resource.get("weapon_type")) == "melee":
			target_location = "melee"
		else:
			target_location = "ranged_0" if action_id == ACTION_EQUIP_RANGED_ONE else "ranged_1"
		_global_inventory.call("transfer_storage_to_equipment", _action_resource, "backpack", target_location)
	elif action_id == ACTION_DISCARD_ALL:
		_global_inventory.call("consume_storage_resource_quantity", _action_resource, "backpack", maxi(_action_quantity, 1))
	elif action_id == ACTION_DISCARD_PARTIAL:
		_pending_partial_resource = _action_resource
		_quantity_dialog.call("present_discard", str(_action_resource.get("display_name")), maxi(_action_quantity, 1))


func _on_quantity_confirmed(quantity: int) -> void:
	if _pending_partial_resource == null or _global_inventory == null:
		return
	var item_resource: Resource = _pending_partial_resource
	_pending_partial_resource = null
	_global_inventory.call("consume_storage_resource_quantity", item_resource, "backpack", quantity)


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
