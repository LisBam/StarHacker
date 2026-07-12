extends Node
class_name EquipmentSetComponent

## 装备套装组件只负责统计当前有效防具的套装件数，并把数据资源中的档位效果转换为属性或世界行为结果。
## 装备槽所有权仍属于 GlobalInventory，普通装备属性仍由 EquipmentComponent 聚合，本组件不移动物品也不保存重复状态。

## 固定防具部位顺序；与 GlobalInventory 和 EquipmentComponent 保持一致，套装只统计头部、躯干、腿部与脚部。
const ARMOR_SLOT_IDS: Array[String] = ["head", "body", "legs", "feet"]

## 装备组件路径；默认指向同级 EquipmentComponent，运行时通常不修改，替换玩家组件结构时可在检查器中调整。
@export var equipment_component_path: NodePath = ^"../EquipmentComponent"

## 装备组件缓存；用于世界特殊效果结算时读取当前四部位资源，不持有或复制装备所有权。
var _equipment_component: Node


func _ready() -> void:
	_equipment_component = get_node_or_null(equipment_component_path)


static func collect_active_set_states(armor_equipment: Dictionary) -> Dictionary:
	## 统计已穿戴且未损坏的套装部件；结果键为 set_id，值包含套装资源与有效件数。
	# 套装状态表；不同资源实例只要 set_id 相同就合并，适配库存深拷贝后的装备。
	var set_states: Dictionary = {}
	for armor_slot in ARMOR_SLOT_IDS:
		# 当前部位装备；空槽或损坏装备不提供普通属性，也不计入套装触发件数。
		var equipment_data: Resource = armor_equipment.get(armor_slot) as Resource
		if equipment_data == null or (equipment_data.has_method("is_broken") and bool(equipment_data.call("is_broken"))):
			continue
		if not _resource_has_property(equipment_data, "equipment_set"):
			continue
		# 套装数据资源；没有 equipment_set 字段或未配置引用的基础装备保持独立，不进入套装表。
		var equipment_set: Resource = equipment_data.get("equipment_set") as Resource
		if equipment_set == null:
			continue
		# 套装稳定标识；空 ID 配置无效，避免所有未命名套装意外合并。
		var set_id: String = str(equipment_set.get("set_id")).strip_edges()
		if set_id.is_empty():
			continue
		# 当前套装状态；首次出现时保存权威套装资源，后续同 ID 装备只增加有效件数。
		var set_state: Dictionary = set_states.get(set_id, {"set_data": equipment_set, "piece_count": 0}) as Dictionary
		set_state["piece_count"] = int(set_state.get("piece_count", 0)) + 1
		set_states[set_id] = set_state
	return set_states


static func get_active_piece_count_for_set(armor_equipment: Dictionary, set_id: String) -> int:
	## 返回指定套装当前有效穿戴件数；未知或空套装 ID 返回 0。
	# 套装状态；复用统一统计确保 UI 激活颜色与实际战斗效果完全一致。
	var set_state: Dictionary = collect_active_set_states(armor_equipment).get(set_id, {}) as Dictionary
	return maxi(int(set_state.get("piece_count", 0)), 0)


static func calculate_active_attribute_bonuses(armor_equipment: Dictionary) -> Dictionary:
	## 汇总全部已触发套装的属性效果；多个不同套装提供同一属性时直接累计。
	# 全部套装属性；只返回数据资源实际声明的键，普通装备聚合器负责校验支持范围。
	var accumulated_bonuses: Dictionary = {}
	# 套装状态遍历项；每项已经排除空槽与损坏装备。
	for raw_set_state in collect_active_set_states(armor_equipment).values():
		# 当前套装状态；包含权威资源和有效件数，异常类型安全跳过。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 套装数据；必须实现统一属性查询接口，避免组件理解每个套装的具体数值字段。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set == null or not equipment_set.has_method("get_attribute_bonuses"):
			continue
		# 当前套装属性；达到的低档位与高档位已经由数据资源内部累计。
		var set_bonuses: Dictionary = equipment_set.call("get_attribute_bonuses", int(set_state.get("piece_count", 0))) as Dictionary
		for raw_stat_name in set_bonuses.keys():
			# 属性稳定名称；与 EquipmentData 有效属性键一致，供装备组件直接合并。
			var stat_name: String = str(raw_stat_name)
			# 属性加成；允许多个套装同属性叠加，正负数都保持数据资源原意。
			var bonus_value: float = float(set_bonuses.get(raw_stat_name, 0.0))
			accumulated_bonuses[stat_name] = float(accumulated_bonuses.get(stat_name, 0.0)) + bonus_value
	return accumulated_bonuses


func get_active_attribute_bonuses(armor_equipment: Dictionary) -> Dictionary:
	## 为玩家装备组件提供实例接口；内部复用纯静态计算，便于局外 UI 与无头测试使用相同规则。
	return calculate_active_attribute_bonuses(armor_equipment)


func roll_manual_chest_extra_drop_count(random_source: RandomNumberGenerator) -> int:
	## 为一次主动长按宝箱结算全部已触发套装特殊效果；不同套装的额外数量允许累计。
	# 当前防具；统一从装备组件或全局库存读取，保证世界行为与角色属性使用同一装备快照。
	var armor_equipment: Dictionary = _get_armor_equipment_resources()
	# 额外掉落总数；初始为 0，未达到任何特殊效果门槛时保持不变。
	var extra_drop_count: int = 0
	# 套装状态遍历项；每个已触发四件档位的套装独立执行自身概率判定。
	for raw_set_state in collect_active_set_states(armor_equipment).values():
		# 当前套装状态；包含套装资源与有效件数。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 套装数据；没有宝箱结算接口的兼容资源不会影响其他套装。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set == null or not equipment_set.has_method("roll_manual_chest_extra_drop_count"):
			continue
		extra_drop_count += maxi(int(equipment_set.call("roll_manual_chest_extra_drop_count", int(set_state.get("piece_count", 0)), random_source)), 0)
	return extra_drop_count


func _get_armor_equipment_resources() -> Dictionary:
	## 读取当前四部位装备；优先使用注入组件，隔离测试缺少玩家组件时回退全局库存服务。
	if _equipment_component == null:
		_equipment_component = get_node_or_null(equipment_component_path)
	if _equipment_component != null and _equipment_component.has_method("get_armor_equipment_resources"):
		return _equipment_component.call("get_armor_equipment_resources") as Dictionary
	# 全局库存服务；只读取公开装备快照，不访问内部记录结构。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory != null and global_inventory.has_method("get_armor_equipment_resources"):
		return global_inventory.call("get_armor_equipment_resources") as Dictionary
	return {}


static func _resource_has_property(content_resource: Resource, property_name: String) -> bool:
	## 判断兼容装备资源是否公开指定字段；旧自定义资源缺少套装字段时保持独立装备，不产生无效 get 错误。
	if content_resource == null:
		return false
	# 属性描述遍历项；脚本导出字段与内置属性都通过统一属性列表检查。
	for property_info in content_resource.get_property_list():
		if str((property_info as Dictionary).get("name", "")) == property_name:
			return true
	return false
