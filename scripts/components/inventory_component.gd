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
## 全局背包服务；默认从自动加载 GlobalInventory 获取，缺失时回退原有场景内本地数组行为。
var _global_inventory: Node


func _ready() -> void:
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if _global_inventory != null and _global_inventory.has_method("get_backpack_resources"):
		if _global_inventory.has_signal("inventory_changed"):
			_global_inventory.connect("inventory_changed", Callable(self, "_on_global_inventory_changed"))
		_sync_from_global_inventory()
		inventory_changed.emit()
		return

	_items = initial_items.duplicate()
	inventory_changed.emit()


func add_item(item_data: Resource) -> bool:
	if _global_inventory != null and _global_inventory.has_method("add_backpack_resource"):
		return bool(_global_inventory.call("add_backpack_resource", item_data))
	if item_data == null or has_item(item_data):
		return false

	_items.append(item_data)
	inventory_changed.emit()
	return true


func add_item_at(item_data: Resource, target_index: int) -> bool:
	if _global_inventory != null and _global_inventory.has_method("add_backpack_resource"):
		return bool(_global_inventory.call("add_backpack_resource", item_data, target_index))
	if item_data == null or has_item(item_data):
		return false

	# 标准化后的插入索引；取值限制在 0 到当前物品数量，默认由投放槽位计算，修改会影响物品插入位置。
	var clamped_index: int = clampi(target_index, 0, _items.size())
	_items.insert(clamped_index, item_data)
	inventory_changed.emit()
	return true


func remove_item(item_data: Resource) -> bool:
	if _global_inventory != null and _global_inventory.has_method("remove_backpack_resource"):
		return bool(_global_inventory.call("remove_backpack_resource", item_data))
	# 待移除物品索引；取值为 -1 或有效数组下标，默认由背包查找得到，修改会影响移除目标。
	var item_index: int = _items.find(item_data)
	if item_index < 0:
		return false

	_items.remove_at(item_index)
	inventory_changed.emit()
	return true


func move_item(source_index: int, target_index: int) -> bool:
	if _global_inventory != null and _global_inventory.has_method("move_backpack_item"):
		return bool(_global_inventory.call("move_backpack_item", source_index, target_index))
	if source_index < 0 or source_index >= _items.size() or target_index < 0 or target_index > _items.size():
		return false

	if source_index == target_index or target_index == source_index + 1:
		return true

	# 被移动的物品资源；取值为背包内有效 Resource，默认由 source_index 读取，修改会影响移动结果。
	var moved_item: Resource = _items[source_index]
	_items.remove_at(source_index)

	# 移除源项后的插入索引；取值限制在当前数组范围，默认用于把拖拽物品放到目标物品前，修改会影响排序行为。
	var insert_index: int = target_index
	if target_index > source_index:
		insert_index -= 1
	insert_index = clampi(insert_index, 0, _items.size())

	_items.insert(insert_index, moved_item)
	inventory_changed.emit()
	return true


func has_item(item_data: Resource) -> bool:
	if _global_inventory != null and _global_inventory.has_method("has_backpack_resource"):
		return bool(_global_inventory.call("has_backpack_resource", item_data))
	return item_data != null and _items.has(item_data)


func get_items() -> Array[Resource]:
	if _global_inventory != null:
		_sync_from_global_inventory()
	return _items.duplicate()


func get_item_entries() -> Array[Dictionary]:
	if _global_inventory != null and _global_inventory.has_method("get_backpack_entries"):
		# 全局背包条目；包含资源、堆叠数量和记录元数据，UI 只读取副本不直接修改所有权。
		var global_entries: Array = _global_inventory.call("get_backpack_entries")
		# 合法条目结果；过滤异常值后返回字典副本，避免调用方写入全局记录。
		var resolved_entries: Array[Dictionary] = []
		for raw_entry in global_entries:
			if raw_entry is Dictionary:
				resolved_entries.append((raw_entry as Dictionary).duplicate())
		return resolved_entries

	# 本地回退条目；自动加载缺失时每个资源按数量 1 暴露给背包 UI。
	var fallback_entries: Array[Dictionary] = []
	for item_data in _items:
		fallback_entries.append({"resource": item_data, "quantity": 1})
	return fallback_entries


func use_enhancement_stone(stone_resource: Resource, weapon_resource: Resource) -> bool:
	if _global_inventory == null or not _global_inventory.has_method("use_enhancement_stone"):
		return false
	return bool(_global_inventory.call("use_enhancement_stone", stone_resource, "backpack", weapon_resource))


func get_item_count() -> int:
	if _global_inventory != null and _global_inventory.has_method("get_backpack_count"):
		return int(_global_inventory.call("get_backpack_count"))
	return _items.size()


func get_items_by_weapon_type(weapon_type: String) -> Array[Resource]:
	if _global_inventory != null:
		_sync_from_global_inventory()
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


func discard_detached_item(item_data: Resource) -> bool:
	if _global_inventory == null or not _global_inventory.has_method("discard_detached_resource"):
		return true
	return bool(_global_inventory.call("discard_detached_resource", item_data))


func _sync_from_global_inventory() -> void:
	if _global_inventory == null or not _global_inventory.has_method("get_backpack_resources"):
		return

	# 全局背包原始数组；取值为 Resource 或其他 Variant，默认只同步合法资源实例。
	var raw_items: Array = _global_inventory.call("get_backpack_resources")
	_items.clear()
	# 全局物品遍历项；取值可能为任意 Variant，默认只接收 Resource。
	for raw_item in raw_items:
		if raw_item is Resource:
			_items.append(raw_item)


func _on_global_inventory_changed() -> void:
	_sync_from_global_inventory()
	inventory_changed.emit()
