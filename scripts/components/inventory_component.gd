extends Node
class_name InventoryComponent

## 背包组件维护玩家拥有的物品资源列表。
## 当前框架先以武器资源为主要物品，后续可以继续放入消耗品、材料或任务道具资源。
## 装备组件只从背包读取和登记物品，不直接负责背包存储。

signal inventory_changed

## 初始物品列表；默认空数组，建议在角色预制体中配置，运行时通常不直接改此字段，改动会影响开局背包内容。
@export var initial_items: Array[Resource] = []

## 运行时物品列表；默认由 initial_items 复制得到，数组元素为 Resource，修改会影响背包查询和装备可用物品。
var _items: Array[Resource] = []


func _ready() -> void:
	_items = initial_items.duplicate()
	inventory_changed.emit()


func add_item(item_data: Resource) -> bool:
	if item_data == null:
		return false

	_items.append(item_data)
	inventory_changed.emit()
	return true


func remove_item(item_data: Resource) -> bool:
	# 待移除物品索引；取值为 -1 或有效数组下标，默认由背包查找得到，修改会影响移除目标。
	var item_index: int = _items.find(item_data)
	if item_index < 0:
		return false

	_items.remove_at(item_index)
	inventory_changed.emit()
	return true


func has_item(item_data: Resource) -> bool:
	return item_data != null and _items.has(item_data)


func get_items() -> Array[Resource]:
	return _items.duplicate()


func get_item_count() -> int:
	return _items.size()


func get_items_by_weapon_type(weapon_type: String) -> Array[Resource]:
	# 指定类型的物品结果；默认空数组，元素为符合 weapon_type 的 Resource，修改会影响背包筛选返回值。
	var matched_items: Array[Resource] = []

	# 背包遍历物品；取值来自 _items，默认逐个检查，修改循环来源会影响筛选范围。
	for item_data in _items:
		if item_data == null:
			continue

		# 当前物品类型；取值来自资源 weapon_type 字段，默认空字符串表示非武器或未配置，修改会影响类型匹配。
		var current_weapon_type: String = str(item_data.get("weapon_type"))
		if current_weapon_type == weapon_type:
			matched_items.append(item_data)

	return matched_items
