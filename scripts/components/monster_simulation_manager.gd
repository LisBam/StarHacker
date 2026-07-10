extends Node
class_name MonsterSimulationManager

## 怪物人口加载管理器把整张地图的敌人保存为轻量虚拟记录，仅在玩家附近实例化真实节点。
## 远处敌人不会进入场景树，也不会执行 AI、物理、碰撞或绘制；返回加载范围时会按原位置与剩余生命重新创建。

signal virtual_monster_died(monster: Node2D)

## 怪物加载半径；默认 2400 像素，虚拟记录进入该范围后才允许实例化为真实敌人。
@export_range(256.0, 12000.0, 1.0) var active_radius: float = 2400.0
## 卸载迟滞距离；默认 400 像素，已实例化敌人离开更远边界后才还原为虚拟记录，避免边缘频繁重建。
@export_range(0.0, 4000.0, 1.0) var sleep_hysteresis: float = 400.0
## 虚拟人口检查间隔；默认 0.05 秒，分批扫描记录以避免同一帧遍历一万名敌人。
@export_range(0.02, 2.0, 0.01) var update_interval: float = 0.05
## 每批检查虚拟记录数量；默认 256，一万条记录约两秒完成一轮加载范围检查。
@export_range(1, 2048, 1) var monsters_per_update: int = 256
## 单批最大实例化数量；默认 12，玩家快速移动时分帧加载附近敌人，避免节点创建产生明显卡顿峰值。
@export_range(1, 128, 1) var materializations_per_update: int = 12
## 同时存在的真实敌人上限；默认 220，人口继续增长时提高地图密度但不会无限增加正在运行的 AI 数量。
@export_range(1, 1000, 1) var max_materialized_monsters: int = 220

## 玩家节点缓存；默认由 GameWorld 初始化，用于计算虚拟记录是否进入加载范围。
var _player: Node2D
## 真实敌人挂载父节点；默认由 GameWorld 注入 Enemies 容器，缺失时回退当前场景根节点。
var _monster_parent: Node
## 敌人索敌目标缓存；默认与玩家相同，真实节点创建后通过 set_target 注入。
var _target: Node
## 真实敌人使用的场景组；默认由 GameWorld 注入，用于训练场清怪和兼容调试查询。
var _monster_group: StringName = &""
## 全地图虚拟敌人记录；每项保存编号、场景、位置、出生倍率、生命比例和可选真实节点。
var _virtual_records: Array[Dictionary] = []
## 虚拟记录编号查询表；键为单调递增编号，值为对应记录，用于节点死亡和卸载时快速定位。
var _records_by_id: Dictionary = {}
## 真实节点到虚拟记录编号的查询表；键为节点实例编号，值为虚拟记录编号。
var _node_record_ids: Dictionary = {}
## 下一条虚拟记录编号；默认 1，每新增一名地图人口后递增，确保记录身份在本局内稳定。
var _next_record_id: int = 1
## 下一批扫描起始下标；默认 0，按环形方式把一万条记录分散到多个更新批次。
var _scan_cursor: int = 0
## 下次扫描剩余时间；默认 0 表示初始化后立即检查玩家附近的虚拟人口。
var _update_remaining: float = 0.0
## 当前已实例化敌人数；默认 0，用于限制同时执行 AI 的真实节点总量。
var _materialized_count: int = 0


func initialize(player: Node2D, monster_parent: Node = null, target: Node = null, monster_group: StringName = &"") -> void:
	_player = player
	_monster_parent = monster_parent
	_target = target if target != null else player
	_monster_group = monster_group
	_update_remaining = 0.0


func add_virtual_monster(monster_scene: PackedScene, spawn_position: Vector2, size_multiplier: float, attribute_multiplier: float) -> bool:
	if monster_scene == null:
		return false

	# 新虚拟记录；只保存生成真实敌人所需的轻量数据，远距离人口不会创建任何节点。
	var record: Dictionary = {
		"id": _next_record_id,
		"scene": monster_scene,
		"position": spawn_position,
		"size_multiplier": maxf(size_multiplier, 0.1),
		"attribute_multiplier": maxf(attribute_multiplier, 0.1),
		"health_ratio": 1.0,
		"node": null,
	}
	_next_record_id += 1
	_virtual_records.append(record)
	_records_by_id[int(record["id"])] = record
	return true


func unregister_monster(monster: Node) -> void:
	if monster == null:
		return

	# 真实节点实例编号；用于查找节点当前对应的虚拟记录，未注册节点不会改变人口数据。
	var node_instance_id: int = monster.get_instance_id()
	if not _node_record_ids.has(node_instance_id):
		return

	# 虚拟记录编号；由真实节点查询表提供，用于同步删除全地图人口记录。
	var record_id: int = int(_node_record_ids.get(node_instance_id, 0))
	_node_record_ids.erase(node_instance_id)
	_remove_record(record_id)


func clear_registered_monsters() -> void:
	clear_population()


func clear_population() -> void:
	# 已实例化节点列表；复制键数组后可在释放节点时安全清空原查询表。
	var materialized_node_ids: Array = _node_record_ids.keys()
	# 节点实例编号遍历项；用于查找并立即释放所有已加载敌人。
	for raw_node_id in materialized_node_ids:
		# 节点实例编号；字典键按整数保存，转换后用于 instance_from_id 查询。
		var node_id: int = int(raw_node_id)
		# 已实例化敌人对象；有效 Node 会从父节点移除并立即释放，避免训练场清怪后残留一帧逻辑。
		var monster_object: Object = instance_from_id(node_id)
		if monster_object is Node:
			var monster_node: Node = monster_object as Node
			if monster_node.get_parent() != null:
				monster_node.get_parent().remove_child(monster_node)
			monster_node.free()

	_virtual_records.clear()
	_records_by_id.clear()
	_node_record_ids.clear()
	_materialized_count = 0
	_scan_cursor = 0
	_update_remaining = 0.0


func update(delta: float) -> void:
	if not is_instance_valid(_player) or _virtual_records.is_empty():
		return

	_update_remaining = maxf(_update_remaining - delta, 0.0)
	if _update_remaining > 0.0:
		return
	_update_remaining = maxf(update_interval, 0.02)
	_unload_distant_materialized_monsters()
	_scan_virtual_population()


func refresh_all() -> void:
	if not is_instance_valid(_player):
		return
	_unload_distant_materialized_monsters()
	# 立即刷新仍遵守单批实例化上限，避免调试调用在一帧内创建大量真实节点。
	_scan_virtual_population()


func get_registered_count() -> int:
	return _virtual_records.size()


func get_population_count() -> int:
	return _virtual_records.size()


func get_active_count() -> int:
	return _materialized_count


func _scan_virtual_population() -> void:
	if _virtual_records.is_empty() or _materialized_count >= maxi(max_materialized_monsters, 1):
		return

	# 本批检查数量；不会超过当前人口总数，避免小规模人口在单批中重复扫描。
	var check_count: int = mini(maxi(monsters_per_update, 1), _virtual_records.size())
	# 本批已创建节点数量；达到 materializations_per_update 后仍推进游标，但不继续制造节点峰值。
	var materialized_this_update: int = 0
	# 有效加载半径平方；距离比较使用平方值以减少高频开方运算。
	var active_radius_squared: float = maxf(active_radius, 1.0) * maxf(active_radius, 1.0)
	# 批次循环索引；仅用于执行固定次数的环形扫描。
	for _check_index in range(check_count):
		if _virtual_records.is_empty():
			return
		_scan_cursor = wrapi(_scan_cursor, 0, _virtual_records.size())
		# 当前虚拟记录；字典为引用语义，实例化后可直接写回节点与运行状态。
		var record: Dictionary = _virtual_records[_scan_cursor]
		_scan_cursor += 1
		if is_instance_valid(record.get("node") as Node):
			continue
		if materialized_this_update >= maxi(materializations_per_update, 1):
			continue
		if _materialized_count >= maxi(max_materialized_monsters, 1):
			return
		# 记录世界位置；用于判断远处虚拟人口是否进入玩家加载范围。
		var record_position: Vector2 = record.get("position", Vector2.ZERO)
		if record_position.distance_squared_to(_player.global_position) > active_radius_squared:
			continue
		if _materialize_record(record):
			materialized_this_update += 1


func _unload_distant_materialized_monsters() -> void:
	# 有效卸载半径；基础加载半径外增加迟滞距离，防止玩家在边界附近反复触发节点创建与释放。
	var unload_radius: float = maxf(active_radius, 1.0) + maxf(sleep_hysteresis, 0.0)
	# 有效卸载半径平方；距离比较使用平方值降低批量检查成本。
	var unload_radius_squared: float = unload_radius * unload_radius
	# 已实例化节点编号副本；遍历副本允许卸载过程中修改节点查询表。
	var materialized_node_ids: Array = _node_record_ids.keys()
	# 节点实例编号遍历项；用于逐个检查真实敌人是否离开卸载范围。
	for raw_node_id in materialized_node_ids:
		# 节点实例编号；转换为整数后同时查询实例对象和对应虚拟记录。
		var node_id: int = int(raw_node_id)
		# 记录编号；缺失时为 0，异常映射会直接清理而不影响其他人口。
		var record_id: int = int(_node_record_ids.get(node_id, 0))
		# 记录原始值；应为 Dictionary，异常时只移除失效节点映射。
		var raw_record: Variant = _records_by_id.get(record_id)
		# 真实敌人对象；节点已由外部释放时会恢复记录的未加载状态。
		var monster_object: Object = instance_from_id(node_id)
		if not (raw_record is Dictionary):
			_node_record_ids.erase(node_id)
			continue
		# 当前虚拟记录；保存真实敌人的位置与生命后可安全释放节点。
		var record: Dictionary = raw_record
		if not (monster_object is Node2D):
			record["node"] = null
			_node_record_ids.erase(node_id)
			_materialized_count = maxi(_materialized_count - 1, 0)
			continue
		# 当前真实敌人；仅在离开卸载半径后还原为虚拟记录。
		var monster: Node2D = monster_object as Node2D
		if monster.global_position.distance_squared_to(_player.global_position) <= unload_radius_squared:
			continue
		_unmaterialize_record(record, monster)


func _materialize_record(record: Dictionary) -> bool:
	# 敌人场景；虚拟记录必须持有有效 PackedScene 才能恢复真实节点。
	var monster_scene: PackedScene = record.get("scene") as PackedScene
	if monster_scene == null:
		return false

	# 新真实敌人；只在玩家加载范围内实例化，异常场景不会占用真实敌人名额。
	var monster: Node2D = monster_scene.instantiate() as Node2D
	if monster == null:
		return false

	# 出生尺寸倍率；沿用虚拟记录首次生成的随机结果，反复加载不会改变敌人体型。
	var size_multiplier: float = maxf(float(record.get("size_multiplier", 1.0)), 0.1)
	# 出生属性倍率；沿用虚拟记录首次生成的随机结果，反复加载不会刷新敌人强度。
	var attribute_multiplier: float = maxf(float(record.get("attribute_multiplier", 1.0)), 0.1)
	if monster.has_method("apply_spawn_variation"):
		monster.call("apply_spawn_variation", size_multiplier, attribute_multiplier)
	else:
		monster.scale *= Vector2(size_multiplier, size_multiplier)
	if not _monster_group.is_empty():
		monster.add_to_group(_monster_group)

	# 实际挂载父节点；优先使用 GameWorld 注入的 Enemies，缺失时回退当前场景或管理器父节点。
	var spawn_parent: Node = _monster_parent
	if spawn_parent == null:
		spawn_parent = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if spawn_parent == null:
		monster.free()
		return false
	spawn_parent.add_child(monster)
	monster.global_position = record.get("position", Vector2.ZERO)
	if monster.has_method("set_target"):
		monster.call("set_target", _target)
	if monster.has_signal("died"):
		monster.connect("died", Callable(self, "_on_materialized_monster_died").bind(monster), CONNECT_ONE_SHOT)

	# 记录生命比例；卸载前受伤的敌人重新加载后恢复相同剩余生命，而不是重新变为满血。
	var health_ratio: float = clampf(float(record.get("health_ratio", 1.0)), 0.0, 1.0)
	if "max_health" in monster and "current_health" in monster:
		monster.set("current_health", float(monster.get("max_health")) * health_ratio)
	record["node"] = monster
	_node_record_ids[monster.get_instance_id()] = int(record.get("id", 0))
	_materialized_count += 1
	return true


func _unmaterialize_record(record: Dictionary, monster: Node2D) -> void:
	record["position"] = monster.global_position
	if "max_health" in monster and "current_health" in monster:
		# 当前最大生命；至少为 1，避免异常敌人属性导致生命比例除零。
		var maximum_health: float = maxf(float(monster.get("max_health")), 1.0)
		record["health_ratio"] = clampf(float(monster.get("current_health")) / maximum_health, 0.0, 1.0)
	record["node"] = null
	_node_record_ids.erase(monster.get_instance_id())
	_materialized_count = maxi(_materialized_count - 1, 0)
	if monster.get_parent() != null:
		monster.get_parent().remove_child(monster)
	monster.free()


func _on_materialized_monster_died(monster: Node2D) -> void:
	if monster == null:
		return
	# 死亡节点实例编号；用于先从虚拟人口中永久删除对应记录，防止远处再次生成同一敌人。
	var node_instance_id: int = monster.get_instance_id()
	# 死亡记录编号；缺失映射时仍向 GameWorld 发送死亡事件以保留掉落逻辑。
	var record_id: int = int(_node_record_ids.get(node_instance_id, 0))
	_node_record_ids.erase(node_instance_id)
	if record_id > 0:
		_remove_record(record_id)
	virtual_monster_died.emit(monster)


func _remove_record(record_id: int) -> void:
	# 记录原始值；应为 Dictionary，缺失时表示人口已经由其他路径删除。
	var raw_record: Variant = _records_by_id.get(record_id)
	if not (raw_record is Dictionary):
		return
	# 待删除虚拟记录；从数组与编号表同步移除，人口统计会立即减少。
	var record: Dictionary = raw_record
	# 记录真实节点；有效时说明本次删除会释放一个真实敌人名额。
	var monster: Node2D = record.get("node") as Node2D
	if is_instance_valid(monster):
		_node_record_ids.erase(monster.get_instance_id())
		_materialized_count = maxi(_materialized_count - 1, 0)
	_virtual_records.erase(record)
	_records_by_id.erase(record_id)
	_scan_cursor = clampi(_scan_cursor, 0, maxi(_virtual_records.size() - 1, 0))
