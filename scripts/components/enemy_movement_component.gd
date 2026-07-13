extends Node

## 敌人移动组件独立维护巡逻、A* 路径缓存、局部绕障、卡住恢复和外部击退。
## 组件不读取玩家目标或索敌状态，宿主只需传入目的地、速度以及是否允许随机化可见追击终点。

## 游荡半径；取值建议大于等于 0，默认 180 表示怪物无目标时围绕出生点小范围移动，修改会影响巡游范围。
var wander_radius: float = 180.0
## 游荡速度倍率；取值建议 0 到 1，默认 0.35 表示无目标时慢速移动，修改会影响游荡节奏。
var wander_speed_multiplier: float = 0.35
## 游荡到点距离；取值建议大于 0，默认 12 像素，怪物距离目标点小于该值时会进入等待并重新选点。
var wander_arrive_distance: float = 12.0
## 游荡最短等待时间；取值建议大于等于 0，默认 0.6 秒，修改会影响怪物到点后的停顿下限。
var wander_wait_min: float = 0.6
## 游荡最长等待时间；取值应大于等于最短等待时间，默认 1.8 秒，修改会影响怪物到点后的停顿上限。
var wander_wait_max: float = 1.8
## 预设巡逻路线节点路径；默认留空使用出生点随机游荡，指定后读取该节点下的 Node2D 子节点作为顺序巡逻点。
var patrol_route_path: NodePath
## 预设巡逻路线是否循环；默认 true，到达最后一个巡逻点后返回第一个点，关闭后会在终点待机警戒。
var patrol_route_loop: bool = true
## 绕障检测距离；取值建议大于怪物半径，默认 56 像素，修改会影响怪物提前绕开墙体的距离。
var avoidance_probe_distance: float = 56.0
## 绕障候选角度步长；取值建议 5 到 45 度，默认 22.5 度，修改会影响怪物寻找绕行方向的细腻程度。
var avoidance_angle_step_degrees: float = 22.5
## 单侧绕障候选数量；取值建议 1 到 8，默认 4，修改会影响怪物绕障能力和每帧检测开销。
var avoidance_candidate_count: int = 4
## 是否启用网格寻路；默认 true，直线被障碍阻挡时会向 GameWorld 请求 A* 路径。
var pathfinding_enabled: bool = true
## 寻路格子尺寸；取值建议 24 到 96，默认 32 可识别建筑入口，越小路径越细但计算开销越高。
var pathfinding_cell_size: float = 32.0
## 寻路代理半径；取值建议接近怪物碰撞半径，默认 18 匹配当前怪物圆形碰撞体并保留入口通行能力。
var pathfinding_agent_radius: float = 18.0
## 路径重算最短间隔；取值建议大于 0，默认 0.55 秒，修改会影响怪物对移动目标的响应频率。
var path_recalculation_min_interval: float = 0.55
## 路径重算最长间隔；取值应大于等于最短间隔，默认 1.1 秒，怪物会在区间内随机取值以错开路径更新。
var path_recalculation_max_interval: float = 1.1
## 路径目标刷新距离；取值建议大于 0，默认 64，目标移动超过该距离会触发重新寻路。
var path_destination_refresh_distance: float = 64.0
## 路点到达距离；取值建议略大于怪物半径，默认 28，修改会影响怪物切换到下一个路点的时机。
var path_waypoint_arrive_distance: float = 28.0
## 路径目标随机半径；取值建议 0 到 64，默认 18，只在目标可见时轻微分散怪物终点。
var path_random_goal_radius: float = 18.0
## 分散目标节点组；默认 skill_targets，只有宿主自身也属于该组时才计算同阵营站位分离。
var separation_group: StringName = &"skill_targets"
## 分散检测半径；默认 64 像素，范围内同组单位会按距离产生远离方向，0 表示关闭。
var separation_radius: float = 64.0
## 分散移动速度；默认 90 像素/秒，作为基础移动之外的站位修正并受最终速度限制。
var separation_speed: float = 90.0
## 单次分散最大邻居数；默认 8，用于限制高密度敌群的节点遍历成本。
var separation_max_neighbors: int = 8
## 单次路径最大路点数；取值建议 8 到 160，默认 96，修改会影响远距离寻路缓存长度。
var path_max_point_count: int = 96
## 卡住判定时间；取值建议 0.3 到 1.2 秒，默认 0.75，避免正常转角减速被误判为卡住。
var stuck_detection_time: float = 0.75
## 卡住判定最小位移；取值建议 0 到 4 像素，默认 0.35，低于该帧位移会累计卡住时间。
var stuck_minimum_movement: float = 0.35
## 击退速度衰减；取值建议大于 0，默认 1600 像素每秒平方，修改会影响怪物受击后滑退持续时间。
var knockback_decay: float = 1600.0
## 移动碰撞与中心线检测掩码；默认检测第 5 层环境，修改会影响 A* 启用条件和局部绕障判断。
var obstacle_collision_mask: int = 16

## 移动宿主；取值为 CharacterBody2D 或 null，默认由敌人聚合脚本注入，组件通过它执行 test_move 和 move_and_slide。
var _actor: CharacterBody2D
## 怪物局部随机数生成器；默认每只怪物独立随机化，修改会影响游荡点和等待时间。
var _random: RandomNumberGenerator
## 出生位置；取值为全局坐标，默认 ready 时记录，用于限制无目标游荡中心。
var _spawn_position: Vector2 = Vector2.ZERO
## 当前游荡目标位置；取值为全局坐标，默认由随机选点生成，修改会影响无目标移动方向。
var _wander_target_position: Vector2 = Vector2.ZERO
## 当前是否已有游荡目标；取值为 true/false，默认 false 表示需要重新随机选点。
var _has_wander_target: bool = false
## 当前游荡等待剩余时间；取值大于等于 0，默认 0 表示可立即移动，修改会影响无目标停顿时长。
var _wander_wait_remaining: float = 0.0
## 预设巡逻点世界坐标；元素来自路线节点下的 Node2D 子节点，默认空数组表示使用随机游荡。
var _patrol_points: Array[Vector2] = []
## 当前预设巡逻点索引；取值为有效数组下标，默认 0，从离怪物最近的路线点恢复巡逻。
var _patrol_point_index: int = 0
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
## 当前卡住累计时间；取值大于等于 0，默认 0，持续移动失败时累加并触发重算路径。
var _stuck_time: float = 0.0
## 最近一次 AI 更新计算出的分散速度；默认零向量，在两次低频决策之间复用以保持逐帧移动平滑。
var _separation_velocity: Vector2 = Vector2.ZERO


func initialize(actor: CharacterBody2D, random_source: RandomNumberGenerator) -> void:
	_actor = actor
	_random = random_source
	_spawn_position = actor.global_position if is_instance_valid(actor) else Vector2.ZERO
	_avoidance_side_bias = -1 if _get_random_integer(0, 1) == 0 else 1


func apply_configuration(settings: Dictionary) -> void:
	wander_radius = maxf(float(settings.get("wander_radius", wander_radius)), 0.0)
	wander_speed_multiplier = maxf(float(settings.get("wander_speed_multiplier", wander_speed_multiplier)), 0.0)
	wander_arrive_distance = maxf(float(settings.get("wander_arrive_distance", wander_arrive_distance)), 1.0)
	wander_wait_min = maxf(float(settings.get("wander_wait_min", wander_wait_min)), 0.0)
	wander_wait_max = maxf(float(settings.get("wander_wait_max", wander_wait_max)), wander_wait_min)
	# 原始巡逻路线配置；取值应为 NodePath，默认类型异常时继续使用空路径随机游荡。
	var raw_patrol_route_path: Variant = settings.get("patrol_route_path", patrol_route_path)
	if raw_patrol_route_path is NodePath:
		patrol_route_path = raw_patrol_route_path
	patrol_route_loop = bool(settings.get("patrol_route_loop", patrol_route_loop))
	avoidance_probe_distance = maxf(float(settings.get("avoidance_probe_distance", avoidance_probe_distance)), 1.0)
	avoidance_angle_step_degrees = maxf(float(settings.get("avoidance_angle_step_degrees", avoidance_angle_step_degrees)), 1.0)
	avoidance_candidate_count = maxi(int(settings.get("avoidance_candidate_count", avoidance_candidate_count)), 1)
	pathfinding_enabled = bool(settings.get("pathfinding_enabled", pathfinding_enabled))
	pathfinding_cell_size = maxf(float(settings.get("pathfinding_cell_size", pathfinding_cell_size)), 16.0)
	pathfinding_agent_radius = maxf(float(settings.get("pathfinding_agent_radius", pathfinding_agent_radius)), 0.0)
	path_recalculation_min_interval = maxf(float(settings.get("path_recalculation_min_interval", path_recalculation_min_interval)), 0.05)
	path_recalculation_max_interval = maxf(float(settings.get("path_recalculation_max_interval", path_recalculation_max_interval)), path_recalculation_min_interval)
	path_destination_refresh_distance = maxf(float(settings.get("path_destination_refresh_distance", path_destination_refresh_distance)), 1.0)
	path_waypoint_arrive_distance = maxf(float(settings.get("path_waypoint_arrive_distance", path_waypoint_arrive_distance)), 1.0)
	path_random_goal_radius = maxf(float(settings.get("path_random_goal_radius", path_random_goal_radius)), 0.0)
	# 原始分散组；只接受 StringName 或 String，异常类型沿用现有配置。
	var raw_separation_group: Variant = settings.get("separation_group", separation_group)
	if raw_separation_group is StringName or raw_separation_group is String:
		separation_group = StringName(str(raw_separation_group))
	separation_radius = maxf(float(settings.get("separation_radius", separation_radius)), 0.0)
	separation_speed = maxf(float(settings.get("separation_speed", separation_speed)), 0.0)
	separation_max_neighbors = maxi(int(settings.get("separation_max_neighbors", separation_max_neighbors)), 1)
	path_max_point_count = maxi(int(settings.get("path_max_point_count", path_max_point_count)), 1)
	stuck_detection_time = maxf(float(settings.get("stuck_detection_time", stuck_detection_time)), 0.05)
	stuck_minimum_movement = maxf(float(settings.get("stuck_minimum_movement", stuck_minimum_movement)), 0.0)
	knockback_decay = maxf(float(settings.get("knockback_decay", knockback_decay)), 1.0)
	obstacle_collision_mask = int(settings.get("obstacle_collision_mask", obstacle_collision_mask))
	_refresh_patrol_points()


func update(delta: float) -> void:
	_path_recalculate_remaining = maxf(_path_recalculate_remaining - delta, 0.0)
	_refresh_separation_velocity()


func set_spawn_position(spawn_position: Vector2) -> void:
	_spawn_position = spawn_position
	_has_wander_target = false
	_refresh_patrol_points()


func get_idle_velocity(delta: float, resolved_move_speed: float) -> Vector2:
	if not _patrol_points.is_empty():
		return _get_patrol_velocity(delta, resolved_move_speed)

	return _get_wander_velocity(delta, resolved_move_speed)


func _get_patrol_velocity(delta: float, resolved_move_speed: float) -> Vector2:
	if _wander_wait_remaining > 0.0:
		_wander_wait_remaining = maxf(_wander_wait_remaining - delta, 0.0)
		return Vector2.ZERO

	if _patrol_point_index < 0 or _patrol_point_index >= _patrol_points.size():
		_pick_nearest_patrol_point()

	# 当前巡逻目标；取值为路线数组中的世界坐标，默认用于按顺序返回预设巡逻路线。
	var patrol_destination: Vector2 = _patrol_points[_patrol_point_index]
	# 巡逻点距离；取值为怪物到当前预设点的距离，默认用于判断到点等待和切换下一点。
	var patrol_distance: float = _actor.global_position.distance_to(patrol_destination)
	if patrol_distance <= wander_arrive_distance:
		if not _advance_patrol_point():
			return Vector2.ZERO

		_wander_wait_remaining = _get_next_wander_wait()
		return Vector2.ZERO

	# 巡逻方向；取值为寻路与局部绕障后的单位向量，默认让预设路线同样支持建筑入口绕行。
	var patrol_direction: Vector2 = get_steered_direction_to(patrol_destination, false)
	return patrol_direction * resolved_move_speed * wander_speed_multiplier


func _get_wander_velocity(delta: float, resolved_move_speed: float) -> Vector2:
	if wander_radius <= 0.0 or wander_speed_multiplier <= 0.0:
		return Vector2.ZERO

	if _wander_wait_remaining > 0.0:
		_wander_wait_remaining = maxf(_wander_wait_remaining - delta, 0.0)
		return Vector2.ZERO

	if not _has_wander_target:
		_pick_wander_target()

	# 游荡目标距离；取值为怪物到当前游荡点的距离，默认用于判断到点和移动方向。
	var target_distance: float = _actor.global_position.distance_to(_wander_target_position)
	if target_distance <= wander_arrive_distance:
		_has_wander_target = false
		_wander_wait_remaining = _get_next_wander_wait()
		return Vector2.ZERO

	# 游荡方向；取值为绕障后的单位向量，默认用于无目标慢速移动。
	var wander_direction: Vector2 = get_steered_direction_to(_wander_target_position, false)
	return wander_direction * resolved_move_speed * wander_speed_multiplier


func _pick_wander_target() -> void:
	# 游荡角度；取值为 0 到 TAU 的随机弧度，默认用于围绕出生点生成目标。
	var wander_angle: float = _get_random_float(0.0, TAU)
	# 游荡距离；取值为 0 到 wander_radius，默认用于让怪物在出生点附近随机巡游。
	var wander_distance: float = _get_random_float(0.0, wander_radius)
	_wander_target_position = _spawn_position + Vector2.RIGHT.rotated(wander_angle) * wander_distance
	_has_wander_target = true
	clear_navigation_path()


func _get_next_wander_wait() -> float:
	# 标准化最长等待时间；取值至少为最短等待时间，默认防止配置反转导致随机范围错误。
	var resolved_wait_max: float = maxf(wander_wait_max, wander_wait_min)
	return _get_random_float(wander_wait_min, resolved_wait_max)


func _refresh_patrol_points() -> void:
	_patrol_points.clear()
	if not is_instance_valid(_actor) or patrol_route_path.is_empty():
		return

	# 巡逻路线根节点；取值由 patrol_route_path 指向，默认读取其直接 Node2D 子节点作为路线点。
	var route_root: Node = _actor.get_node_or_null(patrol_route_path)
	if route_root == null:
		return

	# 巡逻路线子节点；取值为路线根节点的直接子节点，默认按场景树顺序形成巡逻顺序。
	for route_child in route_root.get_children():
		if route_child is Node2D:
			_patrol_points.append((route_child as Node2D).global_position)

	_pick_nearest_patrol_point()


func _pick_nearest_patrol_point() -> void:
	if _patrol_points.is_empty() or not is_instance_valid(_actor):
		_patrol_point_index = 0
		return

	# 最近巡逻点距离；取值从第一个点初始化，默认用于选择脱战后最自然的返程入口。
	var nearest_distance: float = _actor.global_position.distance_to(_patrol_points[0])
	_patrol_point_index = 0
	# 巡逻点索引；取值为 1 到数组末尾，默认逐项查找离当前怪物最近的路线点。
	for point_index in range(1, _patrol_points.size()):
		# 候选巡逻点距离；取值为怪物到该路线点的距离，小于当前记录时替换最近点。
		var point_distance: float = _actor.global_position.distance_to(_patrol_points[point_index])
		if point_distance < nearest_distance:
			nearest_distance = point_distance
			_patrol_point_index = point_index


func _advance_patrol_point() -> bool:
	if _patrol_points.is_empty():
		return false

	if _patrol_point_index + 1 < _patrol_points.size():
		_patrol_point_index += 1
		clear_navigation_path()
		return true

	if patrol_route_loop:
		_patrol_point_index = 0
		clear_navigation_path()
		return true

	return false


func reset_idle_movement() -> void:
	_has_wander_target = false
	_wander_wait_remaining = 0.0
	_pick_nearest_patrol_point()
	clear_navigation_path()


func apply_knockback(direction: Vector2, force: float) -> void:
	if direction.is_zero_approx() or force <= 0.0:
		return

	_knockback_velocity += direction.normalized() * force


func move_with_external_velocity(desired_velocity: Vector2, delta: float) -> void:
	if not is_instance_valid(_actor):
		return

	# 移动前位置；取值为当前全局坐标，默认用于移动后判断怪物是否卡住。
	var previous_position: Vector2 = _actor.global_position
	# 分散后的基础速度；有主动移动时不超过原移动速度与分散速度较大值，静止攻击时仍允许小幅拉开站位。
	var separated_velocity: Vector2 = desired_velocity + _separation_velocity
	# 分散后速度上限；追击时保持原移动速度上限，原地站位调整时最多使用分散速度。
	var maximum_separated_speed: float = maxf(desired_velocity.length(), separation_speed)
	if separated_velocity.length() > maximum_separated_speed and maximum_separated_speed > 0.0:
		separated_velocity = separated_velocity.normalized() * maximum_separated_speed
	_actor.velocity = separated_velocity + _knockback_velocity
	_actor.move_and_slide()
	# 本帧实际位移；取值为 move_and_slide 后的位置差，默认用于卡墙检测。
	var moved_distance: float = _actor.global_position.distance_to(previous_position)
	_actor.velocity = separated_velocity
	_update_stuck_state(separated_velocity, moved_distance, delta)
	_decay_knockback(delta)


func _refresh_separation_velocity() -> void:
	## 计算同组近邻产生的距离加权分离速度；不读取索敌目标，因此追击、攻击站位和巡逻都可复用。
	_separation_velocity = Vector2.ZERO
	if not is_instance_valid(_actor) or separation_group.is_empty() or not _actor.is_in_group(separation_group) or separation_radius <= 0.0 or separation_speed <= 0.0:
		return
	# 分离方向累计；距离越近权重越高，重合时使用实例 ID 生成稳定方向避免零向量无法分开。
	var separation_direction: Vector2 = Vector2.ZERO
	# 已处理近邻数；达到配置上限后停止遍历，避免敌群规模线性放大单只怪物开销。
	var neighbor_count: int = 0
	for raw_neighbor in _actor.get_tree().get_nodes_in_group(separation_group):
		# 当前近邻候选；只接受有效 Node2D，后续继续排除自身、离树和死亡单位。
		var neighbor: Node2D = raw_neighbor as Node2D
		if neighbor == null or neighbor == _actor or not is_instance_valid(neighbor) or not neighbor.is_inside_tree():
			continue
		if neighbor.has_method("is_dead") and bool(neighbor.call("is_dead")):
			continue
		# 近邻偏移；从邻居指向宿主，长度用于半径过滤和距离权重。
		var neighbor_offset: Vector2 = _actor.global_position - neighbor.global_position
		# 近邻距离；取值 0 至分散半径，超出半径的单位不贡献分散方向。
		var neighbor_distance: float = neighbor_offset.length()
		if neighbor_distance > separation_radius:
			continue
		if neighbor_distance <= 0.001:
			# 重合分离角度；由两个实例 ID 稳定生成，避免完全重合时方向每次随机跳变。
			var stable_angle: float = fmod(float(_actor.get_instance_id() ^ neighbor.get_instance_id()), 360.0)
			neighbor_offset = Vector2.RIGHT.rotated(deg_to_rad(stable_angle))
			neighbor_distance = 0.0
		# 距离权重；重合为 1，接近半径边缘平滑降到 0。
		var distance_weight: float = 1.0 - clampf(neighbor_distance / separation_radius, 0.0, 1.0)
		separation_direction += neighbor_offset.normalized() * distance_weight
		neighbor_count += 1
		if neighbor_count >= separation_max_neighbors:
			break
	if not separation_direction.is_zero_approx():
		_separation_velocity = separation_direction.limit_length(1.0) * separation_speed


func get_steered_direction_to(destination: Vector2, randomize_path_goal: bool) -> Vector2:
	if not is_instance_valid(_actor):
		return Vector2.ZERO

	# 直接目标偏移；取值为目标点减当前点，默认用于计算期望移动方向。
	var direct_offset: Vector2 = destination - _actor.global_position
	if direct_offset.is_zero_approx():
		clear_navigation_path()
		return Vector2.ZERO

	# 直接移动方向；取值为当前点指向目标点的单位向量，默认优先尝试直线移动。
	var direct_direction: Vector2 = direct_offset.normalized()
	# 通往目标的中心线是否被环境阻断；取值为 true/false，默认用于提前决定是否需要全局寻路。
	var destination_path_blocked: bool = _is_path_to_destination_blocked(destination)
	if pathfinding_enabled and (destination_path_blocked or not _path_points.is_empty()):
		if not destination_path_blocked and not _is_direction_blocked(direct_direction):
			clear_navigation_path()
			return direct_direction

		return _get_pathfinding_direction_to(destination, randomize_path_goal)

	if not _is_direction_blocked(direct_direction):
		clear_navigation_path()
		return direct_direction

	return _get_local_steered_direction_to(destination)


func _get_pathfinding_direction_to(destination: Vector2, randomize_path_goal: bool) -> Vector2:
	if _should_rebuild_navigation_path(destination):
		_rebuild_navigation_path(destination, randomize_path_goal)

	_trim_reached_path_points()
	if _path_points.is_empty():
		return _get_local_steered_direction_to(destination)

	# 当前路径路点；取值为缓存路径第一个元素，默认作为本帧移动目标。
	var waypoint: Vector2 = _path_points[0]
	return _get_local_steered_direction_to(waypoint)


func _should_rebuild_navigation_path(destination: Vector2) -> bool:
	if _path_points.is_empty():
		return _path_recalculate_remaining <= 0.0

	if _path_goal_position.distance_to(destination) >= path_destination_refresh_distance:
		return true

	return _path_recalculate_remaining <= 0.0 and _is_path_to_destination_blocked(destination)


func _rebuild_navigation_path(destination: Vector2, randomize_path_goal: bool) -> void:
	_path_points.clear()
	_path_goal_position = destination
	_path_recalculate_remaining = _get_next_path_recalculation_interval()

	# 寻路服务节点；取值为提供 find_navigation_path 的 GameWorld，默认缺失时回退局部绕障。
	var navigation_provider: Node = _resolve_navigation_provider()
	if navigation_provider == null or not navigation_provider.has_method("find_navigation_path"):
		return

	# 随机化目标位置；取值为目标附近的小偏移点，默认让多只怪物路径不完全重合。
	var randomized_destination: Vector2 = _get_randomized_path_destination(destination, randomize_path_goal)
	# 原始路径点；取值来自 GameWorld，默认可能为空数组表示无法寻路。
	var raw_path_points: Array = navigation_provider.call(
		"find_navigation_path",
		_actor.global_position,
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
	var arrive_distance: float = path_waypoint_arrive_distance
	while not _path_points.is_empty() and _actor.global_position.distance_to(_path_points[0]) <= arrive_distance:
		_path_points.remove_at(0)


func _get_next_path_recalculation_interval() -> float:
	# 标准化最短重算间隔；取值至少 0.05，默认防止每帧大量寻路。
	var resolved_min_interval: float = path_recalculation_min_interval
	# 标准化最长重算间隔；取值至少为最短间隔，默认防止配置反转。
	var resolved_max_interval: float = maxf(path_recalculation_max_interval, resolved_min_interval)
	return _get_random_float(resolved_min_interval, resolved_max_interval)


func _get_randomized_path_destination(destination: Vector2, randomize_path_goal: bool) -> Vector2:
	if not randomize_path_goal or path_random_goal_radius <= 0.0:
		return destination

	# 随机半径；取值至少为 0，默认用于控制路径终点抖动范围。
	var random_radius: float = path_random_goal_radius
	# 随机角度；取值为 0 到 TAU，默认用于生成终点偏移方向。
	var random_angle: float = _get_random_float(0.0, TAU)
	# 随机距离；取值为 0 到 random_radius，默认用于生成终点偏移长度。
	var random_distance: float = _get_random_float(0.0, random_radius)
	return destination + Vector2.RIGHT.rotated(random_angle) * random_distance


func _resolve_navigation_provider() -> Node:
	# 当前场景节点；取值通常为 GameWorld，默认优先作为寻路服务提供者。
	var current_scene: Node = _actor.get_tree().current_scene
	if current_scene != null and current_scene.has_method("find_navigation_path"):
		return current_scene

	# 父级扫描节点；取值从怪物父节点开始向上查找，默认用于兼容怪物挂载层级变化。
	var parent_node: Node = _actor.get_parent()
	while parent_node != null:
		if parent_node.has_method("find_navigation_path"):
			return parent_node

		parent_node = parent_node.get_parent()

	return null


func clear_navigation_path() -> void:
	_path_points.clear()
	_path_recalculate_remaining = 0.0


func _get_local_steered_direction_to(destination: Vector2) -> Vector2:
	# 直接目标偏移；取值为目标点减当前点，默认用于计算期望移动方向。
	var direct_offset: Vector2 = destination - _actor.global_position
	if direct_offset.is_zero_approx():
		return Vector2.ZERO

	# 直接移动方向；取值为当前点指向目标点的单位向量，默认优先尝试直线移动。
	var direct_direction: Vector2 = direct_offset.normalized()
	if not _is_direction_blocked(direct_direction):
		return direct_direction

	# 候选角度步长；取值为弧度，默认由检查器角度配置转换。
	var angle_step: float = deg_to_rad(avoidance_angle_step_degrees)
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

	return Vector2.ZERO


func is_destination_immediately_reachable(destination: Vector2) -> bool:
	if not is_instance_valid(_actor):
		return false

	# 候选目标方向；取值为宿主指向候选点的向量，默认只过滤起步就会碰撞的搜索点。
	var candidate_direction: Vector2 = destination - _actor.global_position
	return candidate_direction.is_zero_approx() or not _is_direction_blocked(candidate_direction.normalized())


func is_destination_navigable(destination: Vector2) -> bool:
	if not is_instance_valid(_actor):
		return false

	if not _is_path_to_destination_blocked(destination):
		return true
	if not pathfinding_enabled:
		return false

	# 寻路服务节点；取值为提供共享 A* 的 GameWorld，缺失时无法确认远端战术点可达性。
	var navigation_provider: Node = _resolve_navigation_provider()
	if navigation_provider == null or not navigation_provider.has_method("find_navigation_path"):
		return false

	# 战术验证路径；元素为世界坐标路点，非空表示候选墙角、岔路或出口可通过共享导航网格到达。
	var raw_path_points: Array = navigation_provider.call(
		"find_navigation_path",
		_actor.global_position,
		destination,
		pathfinding_agent_radius,
		pathfinding_cell_size,
		path_max_point_count
	)
	return not raw_path_points.is_empty()


func _is_direction_blocked(direction: Vector2) -> bool:
	if direction.is_zero_approx() or not is_instance_valid(_actor):
		return true

	# 检测位移；取值为候选方向乘检测距离，默认用于预测下一小段移动是否撞墙。
	var test_motion: Vector2 = direction.normalized() * avoidance_probe_distance
	return _actor.test_move(_actor.global_transform, test_motion)


func _is_path_to_destination_blocked(destination: Vector2) -> bool:
	# 目标偏移；取值为目标点减当前位置，默认用于跳过极短距离的全局寻路判断。
	var destination_offset: Vector2 = destination - _actor.global_position
	if destination_offset.length() <= avoidance_probe_distance:
		return _is_direction_blocked(destination_offset.normalized())

	# 走廊中心线查询；取值为怪物中心到目标点的射线，默认只检测环境层墙体和建筑。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(_actor.global_position, destination, obstacle_collision_mask, [_actor.get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 中心线命中结果；取值为空表示可直走到目标附近，非空表示应该提前启用 A* 绕行。
	var hit_result: Dictionary = _actor.get_world_2d().direct_space_state.intersect_ray(query)
	return not hit_result.is_empty()


func _update_stuck_state(desired_velocity: Vector2, moved_distance: float, delta: float) -> void:
	if desired_velocity.length() <= 1.0 or not _knockback_velocity.is_zero_approx():
		_stuck_time = 0.0
		return

	if moved_distance > stuck_minimum_movement:
		_stuck_time = 0.0
		return

	_stuck_time += delta
	if _stuck_time < stuck_detection_time:
		return

	_resolve_stuck_path()


func _resolve_stuck_path() -> void:
	_stuck_time = 0.0
	_avoidance_side_bias *= -1
	clear_navigation_path()


func _decay_knockback(delta: float) -> void:
	if _knockback_velocity.is_zero_approx():
		return

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)


func _get_random_float(minimum_value: float, maximum_value: float) -> float:
	return _random.randf_range(minimum_value, maximum_value) if _random != null else randf_range(minimum_value, maximum_value)


func _get_random_integer(minimum_value: int, maximum_value: int) -> int:
	return _random.randi_range(minimum_value, maximum_value) if _random != null else randi_range(minimum_value, maximum_value)
