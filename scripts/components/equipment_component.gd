extends Node
class_name EquipmentComponent

## 装备组件维护远程武器槽、当前远程武器索引和近战武器槽。
## 默认支持两把远程武器和一把近战武器，通过 ranged_slot_count 可以扩展远程槽数量。
## 它只记录装备状态，不执行攻击、不消耗能量，具体战斗行为由玩家控制器和攻击组件协作完成。

signal equipment_changed
signal ranged_weapon_changed(slot_index: int, weapon_data: Resource)
signal melee_weapon_changed(weapon_data: Resource)
signal armor_equipment_changed(armor_slot: String, equipment_data: Resource)

## 背包组件路径；默认指向同级 InventoryComponent，可为空，修改会影响装备物品是否自动登记到背包。
@export var inventory_component_path: NodePath = ^"../InventoryComponent"
## 套装组件路径；默认指向同级 EquipmentSetComponent，修改会影响套装属性是否进入玩家最终属性聚合。
@export var equipment_set_component_path: NodePath = ^"../EquipmentSetComponent"
## 主动技能组件路径；默认指向同级 ActiveSkillComponent，腿部冷却缩减会通过其公开接口影响技能 CD，运行时通常不动态修改。
@export var active_skill_component_path: NodePath = ^"../ActiveSkillComponent"
## 远程武器槽数量；取值建议 1 到 8，默认 2 满足双远程武器需求，运行时修改后需要重新初始化槽位。
@export_range(1, 8, 1) var ranged_slot_count: int = 2
## 开局远程武器列表；默认空数组，最多按 ranged_slot_count 装入，修改会影响玩家初始远程装备。
@export var starting_ranged_weapons: Array[Resource] = []
## 开局近战武器；默认空表示未装备，修改会影响玩家初始右键近战武器。
@export var starting_melee_weapon: Resource
## 每次玩家实际受到伤害时所有已装备防具消耗的耐久；默认 1，运行时通常不动态修改。
@export_range(0.0, 9999.0, 0.1, "or_greater") var armor_durability_cost_per_hit: float = 1.0

## 远程武器槽运行时数组；元素为 Resource 或 null，默认按 ranged_slot_count 创建，使用普通 Array 以稳定支持空槽，修改会影响可切换远程武器。
var _ranged_weapons: Array = []
## 当前远程武器槽索引；取值为 0 到槽数量减 1，默认 0，修改会影响左键射击使用的远程武器。
var _current_ranged_slot: int = 0
## 当前近战武器资源；取值为 Resource 或 null，默认来自 starting_melee_weapon，修改会影响右键近战参数。
var _melee_weapon: Resource
## 四部位防具缓存；键为 head、body、legs、feet，值为 Resource 或 null。
var _armor_equipment: Dictionary = {}
## 玩家属性组件缓存；装备变化时写入聚合后的战斗属性。
var _stats_component: Node
## 玩家移动组件缓存；脚部装备变化时更新最大移速。
var _movement_component: Node
## 玩家战斗相机缓存；头部视野属性变化时调整相机缩放。
var _combat_camera: Camera2D
## 装备套装组件缓存；只读取当前套装属性结果，不持有套装件数或物品所有权。
var _equipment_set_component: Node
## 主动技能组件缓存；只接收装备聚合后的冷却缩减，不读取或修改具体技能资源。
var _active_skill_component: Node
## 不含装备的基础相机缩放；默认进入场景时读取当前 Camera2D.zoom。
var _base_camera_zoom: Vector2 = Vector2.ONE
## 不含装备的基础移速；默认 320，首次同步时从移动组件读取。
var _base_move_speed: float = 106.6667
## 当前装备移速比例；默认 0，由有效脚部装备聚合，角色面板用它换算实际速度加成。
var _equipment_move_speed_ratio: float = 0.0
## 当前装备视野比例；默认 0，由有效头部装备聚合，角色面板按百分比显示。
var _equipment_vision_range_ratio: float = 0.0

## 背包组件缓存；默认按 inventory_component_path 获取，允许为空，修改会影响装备初始化时的背包登记。
@onready var _inventory_component = get_node_or_null(inventory_component_path)
## 全局背包服务；默认从自动加载 GlobalInventory 获取，存在时装备槽与主菜单仓库共享同一份数据。
var _global_inventory: Node


func _ready() -> void:
	_stats_component = owner.get_node_or_null("StatsComponent") if owner != null else get_node_or_null("../StatsComponent")
	_movement_component = owner.get_node_or_null("MovementComponent") if owner != null else get_node_or_null("../MovementComponent")
	_combat_camera = owner.get_node_or_null("Camera2D") as Camera2D if owner != null else get_node_or_null("../Camera2D") as Camera2D
	_equipment_set_component = get_node_or_null(equipment_set_component_path)
	_active_skill_component = get_node_or_null(active_skill_component_path)
	if _movement_component != null and _movement_component.has_method("get_max_speed"):
		_base_move_speed = float(_movement_component.call("get_max_speed"))
	if _combat_camera != null:
		_base_camera_zoom = _combat_camera.zoom
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if _global_inventory != null and _global_inventory.has_method("get_ranged_equipment_resources"):
		if _global_inventory.has_signal("equipment_changed"):
			_global_inventory.connect("equipment_changed", Callable(self, "_on_global_equipment_changed"))
		_sync_from_global_inventory()
		_apply_armor_attributes()
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


func configure_base_move_speed(new_base_move_speed: float) -> void:
	## 更新不含装备的角色基础移速并立即重新应用装备比例；切换角色时使用，避免覆盖脚部加成。
	_base_move_speed = maxf(new_base_move_speed, 1.0)
	_apply_movement_and_vision_attributes()


func get_character_attribute_snapshot() -> Dictionary:
	## 返回角色面板所需的移速与视野三值结构，保持展示结果和装备实际应用公式一致。
	# 装备实际移速；比例属性换算为速度点数，确保面板不直接显示内部小数比例。
	var equipment_move_speed: float = _base_move_speed * _equipment_move_speed_ratio
	return {
		"move_speed": {
			"base": _base_move_speed,
			"equipment": equipment_move_speed,
			"total": _base_move_speed + equipment_move_speed
		},
		"vision_range": {
			"base": 1.0,
			"equipment": _equipment_vision_range_ratio,
			"total": 1.0 + _equipment_vision_range_ratio
		}
	}


func get_armor_equipment(armor_slot: String) -> Resource:
	if _global_inventory != null and _global_inventory.has_method("get_armor_equipment_resource"):
		return _global_inventory.call("get_armor_equipment_resource", armor_slot) as Resource
	return _armor_equipment.get(armor_slot) as Resource


func get_armor_equipment_resources() -> Dictionary:
	if _global_inventory != null and _global_inventory.has_method("get_armor_equipment_resources"):
		return _global_inventory.call("get_armor_equipment_resources") as Dictionary
	return _armor_equipment.duplicate()


func notify_weapon_runtime_state_changed(weapon_data: Resource) -> void:
	if weapon_data == null or _global_inventory == null or not _global_inventory.has_method("notify_weapon_runtime_state_changed"):
		return
	_global_inventory.call("notify_weapon_runtime_state_changed", weapon_data)


func consume_armor_durability_on_hit() -> void:
	# 是否有耐久变化；只在实际变化后刷新属性和排队存档。
	var changed: bool = false
	# 本次防具耐久总消耗；四部位实际变化量相加后交给股市行为统计。
	var total_consumed_durability: float = 0.0
	# 本次新损坏防具数量；只统计从正耐久降到零的部位，避免后续受击重复计数。
	var newly_broken_count: int = 0
	for armor_slot in ["head", "body", "legs", "feet"]:
		var equipment_data: Resource = get_armor_equipment(armor_slot)
		if equipment_data == null or armor_durability_cost_per_hit <= 0.0:
			continue
		var durability_before: float = maxf(float(equipment_data.get("current_durability")), 0.0)
		equipment_data.call("set_current_durability", durability_before - armor_durability_cost_per_hit)
		# 扣除后耐久；用于统计真实消耗并识别首次归零。
		var durability_after: float = maxf(float(equipment_data.get("current_durability")), 0.0)
		total_consumed_durability += maxf(durability_before - durability_after, 0.0)
		if durability_before > 0.0 and durability_after <= 0.0:
			newly_broken_count += 1
		changed = changed or not is_equal_approx(durability_before, float(equipment_data.get("current_durability")))
		if _global_inventory != null and _global_inventory.has_method("notify_weapon_runtime_state_changed"):
			_global_inventory.call("notify_weapon_runtime_state_changed", equipment_data)
	if changed:
		# 股市统计服务；只发送数值事件，不让装备组件依赖具体股票目录或定价公式。
		var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
		if stock_market_service != null and stock_market_service.has_method("record_run_metric"):
			stock_market_service.call("record_run_metric", "armor_durability", total_consumed_durability)
			if newly_broken_count > 0:
				stock_market_service.call("record_run_metric", "broken_armor", newly_broken_count)
		_apply_armor_attributes()
		equipment_changed.emit()


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
	return weapon_data != null and str(weapon_data.get("weapon_type")) in ["ranged", "hybrid"]


func _is_melee_weapon(weapon_data: Resource) -> bool:
	return weapon_data != null and str(weapon_data.get("weapon_type")) in ["melee", "hybrid"]


func _emit_full_equipment_changed() -> void:
	ranged_weapon_changed.emit(_current_ranged_slot, get_current_ranged_weapon())
	melee_weapon_changed.emit(_melee_weapon)
	for armor_slot in ["head", "body", "legs", "feet"]:
		armor_equipment_changed.emit(armor_slot, get_armor_equipment(armor_slot))
	_apply_armor_attributes()
	equipment_changed.emit()


func _sync_from_global_inventory() -> void:
	if _global_inventory == null:
		return

	# 全局远程装备原始数组；元素为 Resource 或 null，默认保持槽位下标同步到组件缓存。
	var raw_ranged_weapons: Array = _global_inventory.call("get_ranged_equipment_resources")
	_ranged_weapons = raw_ranged_weapons.duplicate()
	_current_ranged_slot = int(_global_inventory.call("get_current_ranged_slot"))
	_melee_weapon = _global_inventory.call("get_melee_equipment_resource") as Resource
	_armor_equipment = _global_inventory.call("get_armor_equipment_resources") as Dictionary if _global_inventory.has_method("get_armor_equipment_resources") else {}


func _apply_armor_attributes() -> void:
	# 聚合属性；损坏装备不提供任何加成，避免零耐久仍持续生效。
	var attributes: Dictionary = {"attack_power": 0.0, "defense_power": 0.0, "max_health": 0.0, "health_regeneration_per_five_seconds": 0.0, "energy_regeneration": 0.0, "dodge_chance": 0.0, "cooldown_reduction": 0.0, "move_speed": 0.0, "vision_range": 0.0, "critical_chance": 0.0, "critical_damage": 0.0}
	# 四部位装备；同一快照同时用于普通属性与套装统计，避免一次刷新读取到不同装备状态。
	var armor_equipment: Dictionary = get_armor_equipment_resources()
	for armor_slot in ["head", "body", "legs", "feet"]:
		# 当前部位装备；空槽与损坏装备不参与任何普通属性聚合。
		var equipment_data: Resource = armor_equipment.get(armor_slot) as Resource
		if equipment_data == null or (equipment_data.has_method("is_broken") and bool(equipment_data.call("is_broken"))):
			continue
		for stat_name in attributes.keys():
			var stat_value: float = float(equipment_data.call("get_effective_stat", stat_name)) if equipment_data.has_method("get_effective_stat") else float(equipment_data.get(stat_name))
			attributes[stat_name] = float(attributes[stat_name]) + stat_value
	if _equipment_set_component != null and _equipment_set_component.has_method("get_active_attribute_bonuses"):
		# 套装属性加成；数据资源返回直接有效值，只有装备组件已支持的属性键才会写入角色聚合。
		var set_attribute_bonuses: Dictionary = _equipment_set_component.call("get_active_attribute_bonuses", armor_equipment) as Dictionary
		for raw_stat_name in set_attribute_bonuses.keys():
			# 套装属性名；未知键安全跳过，使特殊效果不会误写入战斗属性组件。
			var stat_name: String = str(raw_stat_name)
			if attributes.has(stat_name):
				attributes[stat_name] = float(attributes.get(stat_name, 0.0)) + float(set_attribute_bonuses.get(raw_stat_name, 0.0))
	if _stats_component != null and _stats_component.has_method("apply_equipment_attributes"):
		_stats_component.call("apply_equipment_attributes", attributes)
	if _stats_component != null and _stats_component.has_method("set_equipment_set_stat_multipliers"):
		# 套装最终属性倍率；与直接点数分开结算，使“提高20%防御力”作用于角色基础与全部装备防御合计值。
		var set_attribute_multipliers: Dictionary = _equipment_set_component.call("get_active_attribute_multipliers", armor_equipment) as Dictionary if _equipment_set_component != null and _equipment_set_component.has_method("get_active_attribute_multipliers") else {}
		_stats_component.call("set_equipment_set_stat_multipliers", set_attribute_multipliers)
	if _active_skill_component != null and _active_skill_component.has_method("set_equipment_cooldown_reduction"):
		# 实际技能冷却缩减；取有效腿部属性总和并限制为 0 至 100%，损坏或卸下腿部装备会在同一刷新中恢复默认 0。
		var cooldown_reduction: float = clampf(float(attributes.get("cooldown_reduction", 0.0)), 0.0, 1.0)
		_active_skill_component.call("set_equipment_cooldown_reduction", cooldown_reduction)
	_equipment_move_speed_ratio = maxf(float(attributes.get("move_speed", 0.0)), 0.0)
	_equipment_vision_range_ratio = maxf(float(attributes.get("vision_range", 0.0)), 0.0)
	_apply_movement_and_vision_attributes()


func _apply_movement_and_vision_attributes() -> void:
	## 把已缓存的角色基础值与装备比例写入运行时组件；角色切换和装备变化共用同一计算路径。
	if _movement_component != null and _movement_component.has_method("configure_max_speed"):
		_movement_component.call("configure_max_speed", _base_move_speed * (1.0 + _equipment_move_speed_ratio))
	if _combat_camera != null:
		# 相机缩放越小视野越广；按 1 + 视野百分比反比缩放，8% 视野对应缩放除以 1.08。
		var vision_multiplier: float = 1.0 + _equipment_vision_range_ratio
		_combat_camera.zoom = _base_camera_zoom / vision_multiplier


func _on_global_equipment_changed() -> void:
	_sync_from_global_inventory()
	_emit_full_equipment_changed()
