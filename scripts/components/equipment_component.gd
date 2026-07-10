extends Node
class_name EquipmentComponent

## 装备组件维护远程武器槽、当前远程武器索引和近战武器槽。
## 默认支持两把远程武器和一把近战武器，通过 ranged_slot_count 可以扩展远程槽数量。
## 它只记录装备状态，不执行攻击、不消耗能量，具体战斗行为由玩家控制器和攻击组件协作完成。

signal equipment_changed
signal ranged_weapon_changed(slot_index: int, weapon_data: Resource)
signal melee_weapon_changed(weapon_data: Resource)

## 背包组件路径；默认指向同级 InventoryComponent，可为空，修改会影响装备物品是否自动登记到背包。
@export var inventory_component_path: NodePath = ^"../InventoryComponent"
## 远程武器槽数量；取值建议 1 到 8，默认 2 满足双远程武器需求，运行时修改后需要重新初始化槽位。
@export_range(1, 8, 1) var ranged_slot_count: int = 2
## 开局远程武器列表；默认空数组，最多按 ranged_slot_count 装入，修改会影响玩家初始远程装备。
@export var starting_ranged_weapons: Array[Resource] = []
## 开局近战武器；默认空表示未装备，修改会影响玩家初始右键近战武器。
@export var starting_melee_weapon: Resource

## 远程武器槽运行时数组；元素为 Resource 或 null，默认按 ranged_slot_count 创建，使用普通 Array 以稳定支持空槽，修改会影响可切换远程武器。
var _ranged_weapons: Array = []
## 当前远程武器槽索引；取值为 0 到槽数量减 1，默认 0，修改会影响左键射击使用的远程武器。
var _current_ranged_slot: int = 0
## 当前近战武器资源；取值为 Resource 或 null，默认来自 starting_melee_weapon，修改会影响右键近战参数。
var _melee_weapon: Resource

## 背包组件缓存；默认按 inventory_component_path 获取，允许为空，修改会影响装备初始化时的背包登记。
@onready var _inventory_component = get_node_or_null(inventory_component_path)
## 全局背包服务；默认从自动加载 GlobalInventory 获取，存在时装备槽与主菜单仓库共享同一份数据。
var _global_inventory: Node


func _ready() -> void:
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if _global_inventory != null and _global_inventory.has_method("get_ranged_equipment_resources"):
		if _global_inventory.has_signal("equipment_changed"):
			_global_inventory.connect("equipment_changed", Callable(self, "_on_global_equipment_changed"))
		_sync_from_global_inventory()
		call_deferred("_emit_full_equipment_changed")
		return

	_initialize_equipment_slots()
	_remove_equipped_items_from_inventory()
	call_deferred("_emit_full_equipment_changed")


func equip_ranged_weapon(slot_index: int, weapon_data: Resource) -> bool:
	if _global_inventory != null and _global_inventory.has_method("equip_resource_to_ranged"):
		return bool(_global_inventory.call("equip_resource_to_ranged", slot_index, weapon_data))
	if not _is_valid_ranged_slot(slot_index) or not _is_ranged_weapon(weapon_data):
		return false

	_ranged_weapons[slot_index] = weapon_data
	if get_current_ranged_weapon() == null:
		_current_ranged_slot = slot_index

	ranged_weapon_changed.emit(_current_ranged_slot, get_current_ranged_weapon())
	equipment_changed.emit()
	return true


func equip_melee_weapon(weapon_data: Resource) -> bool:
	if _global_inventory != null and _global_inventory.has_method("equip_resource_to_melee"):
		return bool(_global_inventory.call("equip_resource_to_melee", weapon_data))
	if not _is_melee_weapon(weapon_data):
		return false

	_melee_weapon = weapon_data
	melee_weapon_changed.emit(_melee_weapon)
	equipment_changed.emit()
	return true


func unequip_ranged_weapon(slot_index: int) -> bool:
	if _global_inventory != null and _global_inventory.has_method("detach_ranged_equipment"):
		return bool(_global_inventory.call("detach_ranged_equipment", slot_index))
	if not _is_valid_ranged_slot(slot_index) or _ranged_weapons[slot_index] == null:
		return false

	_ranged_weapons[slot_index] = null
	if _current_ranged_slot == slot_index:
		_current_ranged_slot = _find_first_available_ranged_slot()

	ranged_weapon_changed.emit(_current_ranged_slot, get_current_ranged_weapon())
	equipment_changed.emit()
	return true


func unequip_melee_weapon() -> bool:
	if _global_inventory != null and _global_inventory.has_method("detach_melee_equipment"):
		return bool(_global_inventory.call("detach_melee_equipment"))
	if _melee_weapon == null:
		return false

	_melee_weapon = null
	melee_weapon_changed.emit(_melee_weapon)
	equipment_changed.emit()
	return true


func equip_ranged_slot(slot_index: int) -> bool:
	if _global_inventory != null and _global_inventory.has_method("set_current_ranged_slot"):
		return bool(_global_inventory.call("set_current_ranged_slot", slot_index))
	if not _is_valid_ranged_slot(slot_index) or _ranged_weapons[slot_index] == null:
		return false

	if _current_ranged_slot == slot_index:
		return true

	_current_ranged_slot = slot_index
	ranged_weapon_changed.emit(_current_ranged_slot, get_current_ranged_weapon())
	equipment_changed.emit()
	return true


func cycle_ranged_weapon(step: int) -> bool:
	if step == 0 or _ranged_weapons.is_empty():
		return false

	# 循环方向；取值为 -1 或 1，默认由滚轮方向归一化，修改会影响切换顺序。
	var direction: int = 1 if step > 0 else -1
	# 初始槽索引；取值为当前槽位，默认用于检测是否已绕回起点，修改会影响循环终止判断。
	var start_slot: int = _current_ranged_slot
	# 候选槽索引；取值为循环过程中的有效槽位，默认从当前槽位开始，修改会影响最终切换目标。
	var candidate_slot: int = _current_ranged_slot

	# 远程槽扫描次数；取值为 0 到槽数量减 1，默认最多扫描一整圈，修改循环范围会影响空槽跳过逻辑。
	for scan_index in range(_ranged_weapons.size()):
		candidate_slot = wrapi(candidate_slot + direction, 0, _ranged_weapons.size())
		if _ranged_weapons[candidate_slot] != null:
			return equip_ranged_slot(candidate_slot)

	return equip_ranged_slot(start_slot)


func get_current_ranged_weapon() -> Resource:
	if _global_inventory != null:
		_sync_from_global_inventory()
	if not _is_valid_ranged_slot(_current_ranged_slot):
		return null

	return _ranged_weapons[_current_ranged_slot]


func get_current_ranged_slot() -> int:
	if _global_inventory != null and _global_inventory.has_method("get_current_ranged_slot"):
		_current_ranged_slot = int(_global_inventory.call("get_current_ranged_slot"))
	return _current_ranged_slot


func get_ranged_slot_count() -> int:
	if _global_inventory != null and _global_inventory.has_method("get_ranged_slot_count"):
		return int(_global_inventory.call("get_ranged_slot_count"))
	return _ranged_weapons.size()


func get_ranged_weapon(slot_index: int) -> Resource:
	if _global_inventory != null and _global_inventory.has_method("get_ranged_equipment_resource"):
		return _global_inventory.call("get_ranged_equipment_resource", slot_index) as Resource
	if not _is_valid_ranged_slot(slot_index):
		return null

	return _ranged_weapons[slot_index]


func get_ranged_weapons() -> Array:
	if _global_inventory != null and _global_inventory.has_method("get_ranged_equipment_resources"):
		return _global_inventory.call("get_ranged_equipment_resources") as Array
	return _ranged_weapons.duplicate()


func get_melee_weapon() -> Resource:
	if _global_inventory != null and _global_inventory.has_method("get_melee_equipment_resource"):
		return _global_inventory.call("get_melee_equipment_resource") as Resource
	return _melee_weapon


func notify_weapon_runtime_state_changed(weapon_data: Resource) -> void:
	if weapon_data == null or _global_inventory == null or not _global_inventory.has_method("notify_weapon_runtime_state_changed"):
		return
	_global_inventory.call("notify_weapon_runtime_state_changed", weapon_data)


func _initialize_equipment_slots() -> void:
	_ranged_weapons.clear()

	# 远程槽初始化索引；取值为 0 到 ranged_slot_count - 1，默认逐槽填充空值，修改循环范围会影响槽数量。
	for slot_index in range(ranged_slot_count):
		_ranged_weapons.append(null)

	# 初始远程武器索引；取值来自 starting_ranged_weapons 下标，默认按顺序装入，修改循环来源会影响开局装备。
	for weapon_index in range(starting_ranged_weapons.size()):
		if weapon_index >= _ranged_weapons.size():
			break

		# 初始远程武器资源；取值为 Resource 或 null，默认来自检查器数组，修改会影响对应槽位配置。
		var ranged_weapon: Resource = starting_ranged_weapons[weapon_index]
		if _is_ranged_weapon(ranged_weapon):
			_ranged_weapons[weapon_index] = ranged_weapon

	if _is_melee_weapon(starting_melee_weapon):
		_melee_weapon = starting_melee_weapon
	else:
		_melee_weapon = null

	_current_ranged_slot = _find_first_available_ranged_slot()


func _remove_equipped_items_from_inventory() -> void:
	# 已装备远程武器清理遍历项；取值为 Resource 或 null，默认来自远程槽数组，修改循环来源会影响背包装备同步。
	for weapon_data in _ranged_weapons:
		_remove_item_from_inventory(weapon_data)

	_remove_item_from_inventory(_melee_weapon)


func _remove_item_from_inventory(item_data: Resource) -> void:
	if item_data == null or _inventory_component == null:
		return

	if _inventory_component.has_method("remove_item"):
		_inventory_component.call("remove_item", item_data)


func _find_first_available_ranged_slot() -> int:
	# 可用远程槽搜索索引；取值为远程槽下标，默认从 0 开始，修改循环范围会影响默认选中武器。
	for slot_index in range(_ranged_weapons.size()):
		if _ranged_weapons[slot_index] != null:
			return slot_index

	return 0


func _is_valid_ranged_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _ranged_weapons.size()


func _is_ranged_weapon(weapon_data: Resource) -> bool:
	return weapon_data != null and str(weapon_data.get("weapon_type")) == "ranged"


func _is_melee_weapon(weapon_data: Resource) -> bool:
	return weapon_data != null and str(weapon_data.get("weapon_type")) == "melee"


func _emit_full_equipment_changed() -> void:
	ranged_weapon_changed.emit(_current_ranged_slot, get_current_ranged_weapon())
	melee_weapon_changed.emit(_melee_weapon)
	equipment_changed.emit()


func _sync_from_global_inventory() -> void:
	if _global_inventory == null:
		return

	# 全局远程装备原始数组；元素为 Resource 或 null，默认保持槽位下标同步到组件缓存。
	var raw_ranged_weapons: Array = _global_inventory.call("get_ranged_equipment_resources")
	_ranged_weapons = raw_ranged_weapons.duplicate()
	_current_ranged_slot = int(_global_inventory.call("get_current_ranged_slot"))
	_melee_weapon = _global_inventory.call("get_melee_equipment_resource") as Resource


func _on_global_equipment_changed() -> void:
	_sync_from_global_inventory()
	_emit_full_equipment_changed()
