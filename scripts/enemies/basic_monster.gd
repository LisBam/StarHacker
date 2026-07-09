extends CharacterBody2D
class_name BasicMonster

## 基础怪物维护生命、攻击、移动、视野索敌和近距离攻击。
## GameWorld 负责生成怪物并设置玩家目标，怪物自身不依赖具体关卡结构。

signal health_changed(current_health: float, max_health: float)
signal died

## 最大血量；取值应大于 0，默认 60 用于训练场怪物强度，运行时修改会影响怪物承伤能力。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_health: float = 60.0
## 当前血量；取值会被限制在 0 到 max_health，默认 60 表示满血生成，运行时修改会影响怪物当前生存状态。
@export_range(0.0, 9999.0, 1.0, "or_greater") var current_health: float = 60.0
## 攻击力；取值建议大于等于 0，默认 12 表示每次近身攻击造成的伤害，运行时修改会影响玩家受击压力。
@export_range(0.0, 9999.0, 1.0, "or_greater") var attack_damage: float = 12.0
## 韧性；取值为百分比，默认 0 表示不减免控制，1 表示减少 1% 击退效果，100 表示完全免疫击退。
@export_range(0.0, 100.0, 1.0) var toughness: float = 0.0
## 攻击冲击力；取值建议大于等于 0，默认 180 会在命中玩家时造成短距离击退。
@export_range(0.0, 5000.0, 1.0, "or_greater") var attack_impact_force: float = 180.0
## 移动速度；取值建议大于 0，默认 150 像素每秒，运行时修改会影响怪物追击速度。
@export_range(1.0, 2000.0, 1.0, "or_greater") var move_speed: float = 150.0
## 视野范围；取值建议大于 0，默认 360 像素，玩家进入该范围后怪物开始索敌追击。
@export_range(1.0, 4000.0, 1.0, "or_greater") var vision_range: float = 360.0
## 攻击距离；取值建议大于 0，默认 42 像素，玩家进入该距离后怪物停止移动并尝试攻击。
@export_range(1.0, 400.0, 1.0, "or_greater") var attack_range: float = 42.0
## 攻击冷却；取值应大于 0，默认 0.9 秒，运行时修改会影响怪物连续攻击频率。
@export_range(0.05, 10.0, 0.05) var attack_cooldown: float = 0.9
## 脱战视野倍率；取值建议大于等于 1，默认 1.25 让怪物不会在视野边缘频繁切换索敌状态。
@export_range(1.0, 4.0, 0.05, "or_greater") var lose_target_range_multiplier: float = 1.25
## 游荡半径；取值建议大于等于 0，默认 180 表示怪物无目标时围绕出生点小范围移动，修改会影响巡游范围。
@export_range(0.0, 2000.0, 1.0) var wander_radius: float = 180.0
## 游荡速度倍率；取值建议 0 到 1，默认 0.35 表示无目标时慢速移动，修改会影响游荡节奏。
@export_range(0.0, 2.0, 0.05) var wander_speed_multiplier: float = 0.35
## 游荡到点距离；取值建议大于 0，默认 12 像素，怪物距离目标点小于该值时会进入等待并重新选点。
@export_range(1.0, 120.0, 1.0) var wander_arrive_distance: float = 12.0
## 游荡最短等待时间；取值建议大于等于 0，默认 0.6 秒，修改会影响怪物到点后的停顿下限。
@export_range(0.0, 10.0, 0.05) var wander_wait_min: float = 0.6
## 游荡最长等待时间；取值应大于等于最短等待时间，默认 1.8 秒，修改会影响怪物到点后的停顿上限。
@export_range(0.0, 10.0, 0.05) var wander_wait_max: float = 1.8
## 绕障检测距离；取值建议大于怪物半径，默认 56 像素，修改会影响怪物提前绕开墙体的距离。
@export_range(1.0, 400.0, 1.0, "or_greater") var avoidance_probe_distance: float = 56.0
## 绕障候选角度步长；取值建议 5 到 45 度，默认 22.5 度，修改会影响怪物寻找绕行方向的细腻程度。
@export_range(1.0, 90.0, 0.5) var avoidance_angle_step_degrees: float = 22.5
## 单侧绕障候选数量；取值建议 1 到 8，默认 4，修改会影响怪物绕障能力和每帧检测开销。
@export_range(1, 12, 1) var avoidance_candidate_count: int = 4
## 是否启用网格寻路；默认 true，直线被障碍阻挡时会向 GameWorld 请求 A* 路径。
@export var pathfinding_enabled: bool = true
## 寻路格子尺寸；取值建议 64 到 160，默认 96，越小路径越细但计算开销越高。
@export_range(16.0, 512.0, 1.0, "or_greater") var pathfinding_cell_size: float = 96.0
## 寻路代理半径；取值建议接近怪物碰撞半径，默认 24，让路径与墙体保持安全距离。
@export_range(0.0, 256.0, 1.0) var pathfinding_agent_radius: float = 24.0
## 路径重算最短间隔；取值建议大于 0，默认 0.45 秒，修改会影响怪物对移动目标的响应频率。
@export_range(0.05, 5.0, 0.05) var path_recalculation_min_interval: float = 0.45
## 路径重算最长间隔；取值应大于等于最短间隔，默认 0.9 秒，怪物会在区间内随机取值以错开路径更新。
@export_range(0.05, 5.0, 0.05) var path_recalculation_max_interval: float = 0.9
## 路径目标刷新距离；取值建议大于 0，默认 96，目标移动超过该距离会触发重新寻路。
@export_range(1.0, 1024.0, 1.0, "or_greater") var path_destination_refresh_distance: float = 96.0
## 路点到达距离；取值建议略大于怪物半径，默认 28，修改会影响怪物切换到下一个路点的时机。
@export_range(1.0, 256.0, 1.0) var path_waypoint_arrive_distance: float = 28.0
## 路径目标随机半径；取值建议 0 到 128，默认 48，让不同怪物绕同一障碍时不完全重合。
@export_range(0.0, 512.0, 1.0) var path_random_goal_radius: float = 48.0
## 单次路径最大路点数；取值建议 8 到 128，默认 64，修改会影响远距离寻路缓存长度。
@export_range(1, 256, 1) var path_max_point_count: int = 64
## 击退速度衰减；取值建议大于 0，默认 1600 像素每秒平方，修改会影响怪物受击后滑退持续时间。
@export_range(1.0, 12000.0, 1.0, "or_greater") var knockback_decay: float = 1600.0

## 当前追击目标；取值为 Node2D 或 null，默认由 GameWorld 设置，修改会影响怪物追击和攻击对象。
var _target: Node2D
## 当前是否已锁定目标；取值为 true/false，默认 false，修改会影响怪物是否追击视野内玩家。
var _has_target: bool = false
## 当前攻击冷却剩余时间；取值大于等于 0，默认 0 表示可立即攻击，修改会影响下次攻击时机。
var _attack_cooldown_remaining: float = 0.0
## 出生位置；取值为全局坐标，默认 ready 时记录，用于限制无目标游荡中心。
var _spawn_position: Vector2 = Vector2.ZERO
## 当前游荡目标位置；取值为全局坐标，默认由随机选点生成，修改会影响无目标移动方向。
var _wander_target_position: Vector2 = Vector2.ZERO
## 当前是否已有游荡目标；取值为 true/false，默认 false 表示需要重新随机选点。
var _has_wander_target: bool = false
## 当前游荡等待剩余时间；取值大于等于 0，默认 0 表示可立即移动，修改会影响无目标停顿时长。
var _wander_wait_remaining: float = 0.0
## 怪物局部随机数生成器；默认每只怪物独立随机化，修改会影响游荡点和等待时间。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 当前外部击退速度；取值为 Vector2，默认零向量，修改会影响怪物受击控制效果。
var _knockback_velocity: Vector2 = Vector2.ZERO
## 当前缓存路径点；元素为世界坐标 Vector2，默认空数组表示正在直线移动或尚未寻路。
var _path_points: Array[Vector2] = []
## 当前路径对应的目标位置；取值为世界坐标，默认零向量，修改会影响是否需要重算路径。
var _path_goal_position: Vector2 = Vector2.ZERO
## 路径重算剩余时间；取值大于等于 0，默认 0 表示允许立即重算路径。
var _path_recalculate_remaining: float = 0.0
## 绕障侧向偏好；取值为 -1 或 1，默认每只怪物随机，修改会影响左右绕行优先级。
var _avoidance_side_bias: int = 1


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	_spawn_position = global_position
	_random.randomize()
	_avoidance_side_bias = -1 if _random.randi_range(0, 1) == 0 else 1
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	_path_recalculate_remaining = maxf(_path_recalculate_remaining - delta, 0.0)
	if not is_instance_valid(_target):
		_has_target = false
		_update_wander(delta)
		_move_with_external_velocity(delta)
		return

	# 目标距离；取值为当前怪物到玩家的距离，默认每帧计算，修改会影响索敌、追击和攻击判定。
	var target_distance: float = global_position.distance_to(_target.global_position)
	_update_target_state(target_distance)
	if not _has_target:
		_update_wander(delta)
		_move_with_external_velocity(delta)
		return

	_update_target_behavior(delta, target_distance)
	_move_with_external_velocity(delta)


func set_target(target_node: Node) -> void:
	_target = target_node as Node2D
	_has_target = false
	_clear_navigation_path()


func apply_damage(damage: float, source: Node) -> void:
	if damage <= 0.0 or current_health <= 0.0:
		return

	current_health = clampf(current_health - damage, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	_apply_knockback_from_source(source)
	if current_health <= 0.0:
		died.emit()
		queue_free()


func _update_target_state(target_distance: float) -> void:
	if target_distance <= vision_range:
		_has_target = true
	elif _has_target and target_distance > vision_range * lose_target_range_multiplier:
		_has_target = false
		_clear_navigation_path()


func _try_attack_target() -> void:
	if _attack_cooldown_remaining > 0.0 or not is_instance_valid(_target):
		return

	if _target.has_method("apply_damage"):
		_target.call("apply_damage", attack_damage, self)

	_attack_cooldown_remaining = attack_cooldown


func _update_target_behavior(_delta: float, target_distance: float) -> void:
	if target_distance <= attack_range:
		velocity = Vector2.ZERO
		_try_attack_target()
		return

	# 追击方向；取值为绕障后的单位向量，默认用于设置本帧速度。
	var chase_direction: Vector2 = _get_steered_direction_to(_target.global_position)
	velocity = chase_direction * move_speed


func _update_wander(delta: float) -> void:
	if wander_radius <= 0.0 or wander_speed_multiplier <= 0.0:
		velocity = Vector2.ZERO
		return

	if _wander_wait_remaining > 0.0:
		_wander_wait_remaining = maxf(_wander_wait_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		return

	if not _has_wander_target:
		_pick_wander_target()

	# 游荡目标距离；取值为怪物到当前游荡点的距离，默认用于判断到点和移动方向。
	var target_distance: float = global_position.distance_to(_wander_target_position)
	if target_distance <= wander_arrive_distance:
		_has_wander_target = false
		_wander_wait_remaining = _get_next_wander_wait()
		velocity = Vector2.ZERO
		return

	# 游荡方向；取值为绕障后的单位向量，默认用于无目标慢速移动。
	var wander_direction: Vector2 = _get_steered_direction_to(_wander_target_position)
	velocity = wander_direction * move_speed * wander_speed_multiplier


func _pick_wander_target() -> void:
	# 游荡角度；取值为 0 到 TAU 的随机弧度，默认用于围绕出生点生成目标。
	var wander_angle: float = _random.randf_range(0.0, TAU)
	# 游荡距离；取值为 0 到 wander_radius，默认用于让怪物在出生点附近随机巡游。
	var wander_distance: float = _random.randf_range(0.0, wander_radius)
	_wander_target_position = _spawn_position + Vector2.RIGHT.rotated(wander_angle) * wander_distance
	_has_wander_target = true
	_clear_navigation_path()


func _get_next_wander_wait() -> float:
	# 标准化最长等待时间；取值至少为最短等待时间，默认防止配置反转导致随机范围错误。
	var resolved_wait_max: float = maxf(wander_wait_max, wander_wait_min)
	return _random.randf_range(wander_wait_min, resolved_wait_max)


func apply_knockback(direction: Vector2, force: float) -> void:
	if direction.is_zero_approx() or force <= 0.0:
		return

	# 韧性减免比例；取值为 0 到 1，默认由 toughness 百分比换算。
	var toughness_reduction: float = clampf(toughness, 0.0, 100.0) * 0.01
	# 实际击退力度；取值为原始力度按韧性减免后的结果，默认用于写入外部速度。
	var resolved_force: float = maxf(force * (1.0 - toughness_reduction), 0.0)
	if resolved_force <= 0.0:
		return

	_knockback_velocity += direction.normalized() * resolved_force


func get_impact_force() -> float:
	return maxf(attack_impact_force, 0.0)


func get_knockback_direction() -> Vector2:
	if is_instance_valid(_target):
		# 指向目标方向；取值为怪物到当前目标的单位向量，默认用于近战命中玩家后的击退方向。
		var target_direction: Vector2 = _target.global_position - global_position
		if not target_direction.is_zero_approx():
			return target_direction.normalized()

	if not velocity.is_zero_approx():
		return velocity.normalized()

	return Vector2.RIGHT


func _apply_knockback_from_source(source: Node) -> void:
	if source == null:
		return

	# 来源冲击力；取值来自 source.get_impact_force()，默认 0 表示不击退怪物。
	var impact_force: float = _get_source_impact_force(source)
	if impact_force <= 0.0:
		return

	# 来源击退方向；取值优先来自 source.get_knockback_direction()，默认由来源位置指向怪物。
	var knockback_direction: Vector2 = _get_source_knockback_direction(source)
	apply_knockback(knockback_direction, impact_force)


func _get_source_impact_force(source: Node) -> float:
	if source.has_method("get_impact_force"):
		return maxf(float(source.call("get_impact_force")), 0.0)

	return 0.0


func _get_source_knockback_direction(source: Node) -> Vector2:
	if source.has_method("get_knockback_direction"):
		# 来源提供的原始方向；取值可能为任意 Variant，默认只接收 Vector2。
		var raw_direction: Variant = source.call("get_knockback_direction")
		if raw_direction is Vector2:
			# 来源提供的击退方向；取值可能为零向量，默认返回前会做兜底判断。
			var provided_direction: Vector2 = raw_direction
			if not provided_direction.is_zero_approx():
				return provided_direction.normalized()

	if source is Node2D:
		# 来源节点位置；取值为 Node2D 全局坐标，默认用于从来源指向怪物的击退方向。
		var source_position: Vector2 = (source as Node2D).global_position
		# 位置推导方向；取值为来源到怪物的单位向量，默认用于无方向来源的击退。
		var inferred_direction: Vector2 = global_position - source_position
		if not inferred_direction.is_zero_approx():
			return inferred_direction.normalized()

	return Vector2.RIGHT


func _get_steered_direction_to(destination: Vector2) -> Vector2:
	# 直接目标偏移；取值为目标点减当前点，默认用于计算期望移动方向。
	var direct_offset: Vector2 = destination - global_position
	if direct_offset.is_zero_approx():
		_clear_navigation_path()
		return Vector2.ZERO

	# 直接移动方向；取值为当前点指向目标点的单位向量，默认优先尝试直线移动。
	var direct_direction: Vector2 = direct_offset.normalized()
	if not _is_direction_blocked(direct_direction):
		_clear_navigation_path()
		return direct_direction

	if pathfinding_enabled:
		return _get_pathfinding_direction_to(destination)

	return _get_local_steered_direction_to(destination)


func _get_pathfinding_direction_to(destination: Vector2) -> Vector2:
	if _should_rebuild_navigation_path(destination):
		_rebuild_navigation_path(destination)

	_trim_reached_path_points()
	if _path_points.is_empty():
		return _get_local_steered_direction_to(destination)

	# 当前路径路点；取值为缓存路径第一个元素，默认作为本帧移动目标。
	var waypoint: Vector2 = _path_points[0]
	return _get_local_steered_direction_to(waypoint)


func _should_rebuild_navigation_path(destination: Vector2) -> bool:
	if _path_points.is_empty():
		return true

	if _path_recalculate_remaining <= 0.0:
		return true

	return _path_goal_position.distance_to(destination) >= maxf(path_destination_refresh_distance, 1.0)


func _rebuild_navigation_path(destination: Vector2) -> void:
	_path_points.clear()
	_path_goal_position = destination
	_path_recalculate_remaining = _get_next_path_recalculation_interval()

	# 寻路服务节点；取值为提供 find_navigation_path 的 GameWorld，默认缺失时回退局部绕障。
	var navigation_provider: Node = _resolve_navigation_provider()
	if navigation_provider == null or not navigation_provider.has_method("find_navigation_path"):
		return

	# 随机化目标位置；取值为目标附近的小偏移点，默认让多只怪物路径不完全重合。
	var randomized_destination: Vector2 = _get_randomized_path_destination(destination)
	# 原始路径点；取值来自 GameWorld，默认可能为空数组表示无法寻路。
	var raw_path_points: Array = navigation_provider.call(
		"find_navigation_path",
		global_position,
		randomized_destination,
		pathfinding_agent_radius,
		pathfinding_cell_size,
		path_max_point_count
	)
	# 原始路径点遍历项；取值可能为 Vector2，默认只接收合法世界坐标。
	for raw_path_point in raw_path_points:
		if raw_path_point is Vector2:
			_path_points.append(raw_path_point)


func _trim_reached_path_points() -> void:
	# 路点到达阈值；取值至少为 1，默认用于弹出已经接近的路径点。
	var arrive_distance: float = maxf(path_waypoint_arrive_distance, 1.0)
	while not _path_points.is_empty() and global_position.distance_to(_path_points[0]) <= arrive_distance:
		_path_points.remove_at(0)


func _get_next_path_recalculation_interval() -> float:
	# 标准化最短重算间隔；取值至少 0.05，默认防止每帧大量寻路。
	var resolved_min_interval: float = maxf(path_recalculation_min_interval, 0.05)
	# 标准化最长重算间隔；取值至少为最短间隔，默认防止配置反转。
	var resolved_max_interval: float = maxf(path_recalculation_max_interval, resolved_min_interval)
	return _random.randf_range(resolved_min_interval, resolved_max_interval)


func _get_randomized_path_destination(destination: Vector2) -> Vector2:
	# 随机半径；取值至少为 0，默认用于控制路径终点抖动范围。
	var random_radius: float = maxf(path_random_goal_radius, 0.0)
	if random_radius <= 0.0:
		return destination

	# 随机角度；取值为 0 到 TAU，默认用于生成终点偏移方向。
	var random_angle: float = _random.randf_range(0.0, TAU)
	# 随机距离；取值为 0 到 random_radius，默认用于生成终点偏移长度。
	var random_distance: float = _random.randf_range(0.0, random_radius)
	return destination + Vector2.RIGHT.rotated(random_angle) * random_distance


func _resolve_navigation_provider() -> Node:
	# 当前场景节点；取值通常为 GameWorld，默认优先作为寻路服务提供者。
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("find_navigation_path"):
		return current_scene

	# 父级扫描节点；取值从怪物父节点开始向上查找，默认用于兼容怪物挂载层级变化。
	var parent_node: Node = get_parent()
	while parent_node != null:
		if parent_node.has_method("find_navigation_path"):
			return parent_node

		parent_node = parent_node.get_parent()

	return null


func _clear_navigation_path() -> void:
	_path_points.clear()
	_path_recalculate_remaining = 0.0


func _get_local_steered_direction_to(destination: Vector2) -> Vector2:
	# 直接目标偏移；取值为目标点减当前点，默认用于计算期望移动方向。
	var direct_offset: Vector2 = destination - global_position
	if direct_offset.is_zero_approx():
		return Vector2.ZERO

	# 直接移动方向；取值为当前点指向目标点的单位向量，默认优先尝试直线移动。
	var direct_direction: Vector2 = direct_offset.normalized()
	if not _is_direction_blocked(direct_direction):
		return direct_direction

	# 候选角度步长；取值为弧度，默认由检查器角度配置转换。
	var angle_step: float = deg_to_rad(maxf(avoidance_angle_step_degrees, 1.0))
	# 候选阶梯索引；取值为 1 到 avoidance_candidate_count，默认逐步扩大绕障角度。
	for candidate_index in range(1, avoidance_candidate_count + 1):
		# 候选侧向索引；取值为 0 或 1，默认先尝试每只怪物自己的随机偏好侧。
		for side_index in range(2):
			# 候选方向符号；取值为 -1 或 1，默认用于左右两侧尝试绕行。
			var side: int = _avoidance_side_bias if side_index == 0 else -_avoidance_side_bias
			# 候选方向；取值为直接方向旋转后的单位向量，默认用于避开前方障碍。
			var candidate_direction: Vector2 = direct_direction.rotated(angle_step * float(candidate_index * side)).normalized()
			if not _is_direction_blocked(candidate_direction):
				return candidate_direction

	return direct_direction


func _is_direction_blocked(direction: Vector2) -> bool:
	if direction.is_zero_approx():
		return true

	# 检测位移；取值为候选方向乘检测距离，默认用于预测下一小段移动是否撞墙。
	var test_motion: Vector2 = direction.normalized() * maxf(avoidance_probe_distance, 1.0)
	return test_move(global_transform, test_motion)


func _move_with_external_velocity(delta: float) -> void:
	# 本帧基础速度；取值来自追击或游荡逻辑，默认在叠加击退前缓存。
	var desired_velocity: Vector2 = velocity
	velocity = desired_velocity + _knockback_velocity
	move_and_slide()
	velocity = desired_velocity
	_decay_knockback(delta)


func _decay_knockback(delta: float) -> void:
	if _knockback_velocity.is_zero_approx():
		return

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, maxf(knockback_decay, 1.0) * delta)
