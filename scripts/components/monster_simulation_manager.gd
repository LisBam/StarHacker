extends Node
class_name MonsterSimulationManager

## 怪物加载管理器集中维护玩家附近的模拟范围，远距离怪物仍保留在地图和存活统计中，但停止 AI、物理与渲染。
## 管理器按固定批次轮询怪物，避免高密度地图在同一帧完成全部距离检查或唤醒操作。

## 怪物激活半径；默认 2400 像素，玩家周围大范围内的怪物会执行 AI、碰撞和绘制。
@export_range(256.0, 12000.0, 1.0) var active_radius: float = 2400.0
## 休眠迟滞距离；默认 400 像素，已激活怪物离开更远边界后才休眠，防止边缘反复开关。
@export_range(0.0, 4000.0, 1.0) var sleep_hysteresis: float = 400.0
## 加载状态检查间隔；默认 0.1 秒，每次只检查一批怪物以平滑 CPU 峰值。
@export_range(0.02, 2.0, 0.01) var update_interval: float = 0.1
## 每批检查怪物数量；默认 40，160 名怪物约 0.4 秒完成一次全量加载状态刷新。
@export_range(1, 512, 1) var monsters_per_update: int = 40

## 玩家节点缓存；默认由 GameWorld 初始化，必须是有效 Node2D 才能计算加载距离。
var _player: Node2D
## 已注册怪物数组；元素为远近程怪物 Node2D，包含激活和休眠个体但会自动清理失效引用。
var _monsters: Array[Node2D] = []
## 下一批检查起始下标；默认 0，按环形方式分散每次距离检查对象。
var _update_cursor: int = 0
## 下次检查剩余时间；默认 0 表示初始化后立即执行一批加载状态刷新。
var _update_remaining: float = 0.0


func initialize(player: Node2D) -> void:
	_player = player
	_update_remaining = 0.0


func register_monster(monster: Node2D) -> void:
	if monster == null or _monsters.has(monster):
		return
	_monsters.append(monster)
	# 初次加载半径；新刷新怪物不使用休眠迟滞，确保远处刷新后立即进入低开销休眠状态。
	var initial_radius: float = maxf(active_radius, 1.0)
	# 初始激活状态；只按玩家到基础加载半径判断，仍允许刷新在地图远处但不执行 AI。
	var initially_active: bool = is_instance_valid(_player) and monster.global_position.distance_squared_to(_player.global_position) <= initial_radius * initial_radius
	_apply_monster_state(monster, initially_active)


func unregister_monster(monster: Node) -> void:
	if monster is Node2D:
		_monsters.erase(monster as Node2D)
	_update_cursor = clampi(_update_cursor, 0, maxi(_monsters.size() - 1, 0))


func clear_registered_monsters() -> void:
	_monsters.clear()
	_update_cursor = 0
	_update_remaining = 0.0


func update(delta: float) -> void:
	if not is_instance_valid(_player) or _monsters.is_empty():
		return
	_update_remaining = maxf(_update_remaining - delta, 0.0)
	if _update_remaining > 0.0:
		return
	_update_remaining = maxf(update_interval, 0.02)
	# 本批检查数量；取值不超过当前注册数量，避免小规模场景重复检查同一怪物。
	var check_count: int = mini(maxi(monsters_per_update, 1), _monsters.size())
	# 本批循环索引；取值为 0 到 check_count-1，每次推进环形游标并处理一个有效怪物。
	for _check_index in range(check_count):
		if _monsters.is_empty():
			return
		_update_cursor = wrapi(_update_cursor, 0, _monsters.size())
		# 当前怪物；取值为环形游标对应节点，失效或待释放节点会从注册表移除。
		var monster: Node2D = _monsters[_update_cursor]
		if not is_instance_valid(monster) or monster.is_queued_for_deletion():
			_monsters.remove_at(_update_cursor)
			continue
		_apply_monster_state(monster, _should_monster_be_active(monster))
		_update_cursor += 1


func refresh_all() -> void:
	# 注册怪物副本；遍历副本可以在清理失效引用时安全修改原数组。
	var registered_copy: Array[Node2D] = _monsters.duplicate()
	# 注册怪物遍历项；取值为当前全部怪物，立即按玩家距离刷新加载状态。
	for monster in registered_copy:
		if not is_instance_valid(monster) or monster.is_queued_for_deletion():
			_monsters.erase(monster)
			continue
		_apply_monster_state(monster, _should_monster_be_active(monster))
	_update_cursor = 0


func get_registered_count() -> int:
	return _monsters.size()


func get_active_count() -> int:
	# 激活怪物数量；默认从 0 累加，只统计有效且显式报告模拟激活的节点。
	var active_count: int = 0
	# 注册怪物遍历项；取值为全部有效引用，用于调试性能和专项测试。
	for monster in _monsters:
		if is_instance_valid(monster) and monster.has_method("is_simulation_active") and bool(monster.call("is_simulation_active")):
			active_count += 1
	return active_count


func _should_monster_be_active(monster: Node2D) -> bool:
	if not is_instance_valid(monster) or not is_instance_valid(_player):
		return false
	# 当前激活状态；默认用于选择进入半径或带迟滞的离开半径，避免边界抖动。
	var currently_active: bool = bool(monster.call("is_simulation_active")) if monster.has_method("is_simulation_active") else true
	# 有效加载半径；休眠怪物使用基础半径，激活怪物额外增加迟滞距离。
	var resolved_radius: float = maxf(active_radius, 1.0) + (maxf(sleep_hysteresis, 0.0) if currently_active else 0.0)
	return monster.global_position.distance_squared_to(_player.global_position) <= resolved_radius * resolved_radius


func _apply_monster_state(monster: Node2D, active: bool) -> void:
	if monster.has_method("set_simulation_active"):
		monster.call("set_simulation_active", active)
		return
	monster.set_physics_process(active)
	monster.visible = active
