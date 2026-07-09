extends Node

## 敌人感知组件独立维护视野检测、玩家记忆、遮挡搜查和反复卡视野脱战状态。
## 组件只读取宿主与目标的世界坐标，不负责移动或攻击；移动目标通过只读查询接口交给宿主执行。

signal state_changed(previous_state: int, current_state: int)

## AI 空闲状态；默认表示怪物没有玩家记忆，会回到出生点附近巡逻或待机警戒。
const TARGET_AI_STATE_IDLE: int = 0
## AI 可见追击状态；默认表示怪物拥有无遮挡视线，会直接锁定玩家并寻路追击。
const TARGET_AI_STATE_VISIBLE: int = 1
## AI 丢失搜查状态；默认表示玩家被障碍遮挡，怪物只根据最后线索前往遮挡物背后和附近区域搜索。
const TARGET_AI_STATE_SEARCHING: int = 2

## 视野范围；取值建议大于 0，默认 360 像素，玩家进入该范围后怪物开始索敌追击。
var vision_range: float = 360.0
## 脱战视野倍率；取值建议大于等于 1，默认 1.25 让怪物不会在视野边缘频繁切换索敌状态。
var lose_target_range_multiplier: float = 1.25
## 索敌是否需要直线视野；默认 true，墙体会阻挡怪物首次发现玩家。
var vision_requires_line_of_sight: bool = true
## 索敌视线遮挡检测掩码；默认检测第 5 层环境墙体，修改会影响哪些障碍能阻挡怪物发现玩家。
var vision_line_of_sight_collision_mask: int = 16
## 视野丢失确认时间；取值建议 0.1 到 0.4 秒，默认 0.2 秒用于过滤墙角和物理射线单帧抖动。
var vision_loss_grace_duration: float = 0.2
## 失去视野后的记忆时间；取值建议大于 0，默认 8 秒，怪物会在这段时间内前往最后看见或推断的玩家位置搜索。
var target_memory_duration: float = 8.0
## 搜索到达距离；取值建议大于怪物半径，默认 54 像素，怪物靠近推断位置或当前搜索点后会进入扫荡或切换下一个搜索点。
var search_arrive_distance: float = 54.0
## 目标预测时间；取值建议 0 到 2 秒，默认 0.55 会按最近移动趋势把搜索点向玩家移动方向前推。
var target_prediction_time: float = 0.55
## 目标预测最大距离；取值建议大于等于 0，默认 220 像素，防止高速移动或瞬移导致搜索点偏离过远。
var target_prediction_max_distance: float = 220.0
## 到达推断位置后的搜索时间；取值建议大于等于 0，默认 4 秒，怪物会围绕推断位置继续扫荡而不是立刻丢失目标。
var target_search_duration_after_arrival: float = 4.0
## 到达推断位置后的搜索半径；取值建议大于怪物半径，默认 180 像素，修改会影响怪物在墙后区域的扫荡范围。
var target_search_radius: float = 180.0
## 搜查点最短观察时间；取值建议 0 到 1 秒，默认 0.2 秒，让怪物到点后短暂停顿观察而不是连续折返。
var target_search_point_wait_min: float = 0.2
## 搜查点最长观察时间；取值应大于等于最短时间，默认 0.55 秒，修改会影响区域搜查节奏。
var target_search_point_wait_max: float = 0.55
## 卡视野脱战次数阈值；取值建议 2 到 5，默认 3，玩家多次依靠障碍遮挡脱离视线后怪物会彻底丢失目标。
var occlusion_break_forget_count: int = 3
## 卡视野计数恢复时间；取值建议 3 到 15 秒，默认 8 秒，目标持续可见达到该时间后清除旧的规避记录。
var occlusion_count_reset_duration: float = 8.0
## 遮挡物背后搜查偏移；取值建议接近建筑墙厚或入口宽度，默认 96 像素，用于从视线命中点向玩家消失方向推导搜查锚点。
var lost_search_occlusion_offset: float = 96.0
## 搜查点选择尝试次数；取值建议 1 到 12，默认 6，用于在搜查锚点周边优先挑选不会直接撞墙的巡逻点。
var lost_search_destination_attempts: int = 6

## 感知宿主；取值为 CharacterBody2D 或 null，默认由敌人聚合脚本注入，用于射线起点和当前位置查询。
var _actor: CharacterBody2D
## 当前追击目标；取值为 Node2D 或 null，默认由 GameWorld 通过敌人聚合脚本设置。
var _target: Node2D
## 组件使用的独立随机源；默认由宿主共享，确保同一敌人的搜索行为保持一致的随机序列。
var _random: RandomNumberGenerator
## 搜查点即时可行性检查；默认由移动组件提供，只负责过滤起步就会撞墙的候选点。
var _destination_validator: Callable
## 当前是否已锁定目标；取值为 true/false，默认 false，修改会影响怪物是否追击视野内玩家。
var _has_target: bool = false
## 当前目标是否处于可见状态；取值为 true/false，默认 false，墙体遮挡时会变为 false。
var _target_is_visible: bool = false
## 当前 AI 索敌状态；取值为 TARGET_AI_STATE_* 常量，默认空闲状态用于区分可见追击和丢失搜查。
var _target_ai_state: int = TARGET_AI_STATE_IDLE
## 最后一次看见或推断目标的位置；取值为世界坐标，默认零向量，仅在 _has_last_known_target_position 为 true 时有效。
var _last_known_target_position: Vector2 = Vector2.ZERO
## 是否存在最后目标位置；取值为 true/false，默认 false，失去视野后用于决定是否继续搜索。
var _has_last_known_target_position: bool = false
## 目标记忆剩余时间；取值大于等于 0，默认 0，失去视野后递减直到放弃搜索。
var _target_memory_remaining: float = 0.0
## 目标最近估算速度；取值为世界坐标速度向量，默认零向量，用于失去视野后预测玩家可能移动方向。
var _estimated_target_velocity: Vector2 = Vector2.ZERO
## 视线最后一次被遮挡的位置；取值为世界坐标，默认零向量，仅在 _has_last_occlusion_position 为 true 时用于推导遮挡物背后搜查点。
var _last_occlusion_position: Vector2 = Vector2.ZERO
## 是否存在视线遮挡位置；取值为 true/false，默认 false，只有射线命中环境遮挡物后才会变为 true。
var _has_last_occlusion_position: bool = false
## 当前交战中被障碍遮挡脱离视线的次数；取值从 0 递增，达到 occlusion_break_forget_count 后清空目标记忆。
var _line_of_sight_loss_count: int = 0
## 连续清晰看见目标的累计时间；取值大于等于 0，默认 0，达到恢复时间后重置旧的卡视野计数。
var _continuous_visible_duration: float = 0.0
## 当前连续失去视野的累计时间；取值大于等于 0，默认 0，达到确认时间后才正式进入搜查。
var _vision_loss_elapsed: float = 0.0
## 搜索锚点位置；取值为世界坐标，默认零向量，到达推断点后怪物会围绕该点继续搜索。
var _target_search_anchor_position: Vector2 = Vector2.ZERO
## 当前搜索点位置；取值为世界坐标，默认零向量，仅在 _has_target_search_destination 为 true 时有效。
var _target_search_destination: Vector2 = Vector2.ZERO
## 当前是否存在搜索点；取值为 true/false，默认 false，修改会影响失去视野后的扫荡移动。
var _has_target_search_destination: bool = false
## 到达推断位置后的搜索剩余时间；取值大于等于 0，默认 0，递减到 0 后怪物才真正放弃目标。
var _target_search_remaining: float = 0.0
## 是否已经到达丢失视野后的初始搜查锚点；取值为 true/false，默认 false，到达后才切换为周边巡逻搜查。
var _has_reached_lost_search_anchor: bool = false
## 当前搜查点观察剩余时间；取值大于等于 0，默认 0，到点后短暂停顿再选择下一处区域。
var _target_search_wait_remaining: float = 0.0


func initialize(actor: CharacterBody2D, random_source: RandomNumberGenerator, destination_validator: Callable = Callable()) -> void:
	_actor = actor
	_random = random_source
	_destination_validator = destination_validator


func apply_configuration(settings: Dictionary) -> void:
	vision_range = maxf(float(settings.get("vision_range", vision_range)), 0.0)
	lose_target_range_multiplier = maxf(float(settings.get("lose_target_range_multiplier", lose_target_range_multiplier)), 1.0)
	vision_requires_line_of_sight = bool(settings.get("vision_requires_line_of_sight", vision_requires_line_of_sight))
	vision_line_of_sight_collision_mask = int(settings.get("vision_line_of_sight_collision_mask", vision_line_of_sight_collision_mask))
	vision_loss_grace_duration = maxf(float(settings.get("vision_loss_grace_duration", vision_loss_grace_duration)), 0.0)
	target_memory_duration = maxf(float(settings.get("target_memory_duration", target_memory_duration)), 0.0)
	search_arrive_distance = maxf(float(settings.get("search_arrive_distance", search_arrive_distance)), 1.0)
	target_prediction_time = maxf(float(settings.get("target_prediction_time", target_prediction_time)), 0.0)
	target_prediction_max_distance = maxf(float(settings.get("target_prediction_max_distance", target_prediction_max_distance)), 0.0)
	target_search_duration_after_arrival = maxf(float(settings.get("target_search_duration_after_arrival", target_search_duration_after_arrival)), 0.0)
	target_search_radius = maxf(float(settings.get("target_search_radius", target_search_radius)), 0.0)
	target_search_point_wait_min = maxf(float(settings.get("target_search_point_wait_min", target_search_point_wait_min)), 0.0)
	target_search_point_wait_max = maxf(float(settings.get("target_search_point_wait_max", target_search_point_wait_max)), target_search_point_wait_min)
	occlusion_break_forget_count = maxi(int(settings.get("occlusion_break_forget_count", occlusion_break_forget_count)), 1)
	occlusion_count_reset_duration = maxf(float(settings.get("occlusion_count_reset_duration", occlusion_count_reset_duration)), 0.0)
	lost_search_occlusion_offset = maxf(float(settings.get("lost_search_occlusion_offset", lost_search_occlusion_offset)), 0.0)
	lost_search_destination_attempts = maxi(int(settings.get("lost_search_destination_attempts", lost_search_destination_attempts)), 1)


func set_target(target_node: Node) -> void:
	_target = target_node as Node2D
	_forget_target()


func update(delta: float) -> void:
	if not is_instance_valid(_actor) or not is_instance_valid(_target):
		_forget_target()
		return

	# 目标距离；取值为当前怪物到玩家的距离，默认每帧计算，修改会影响索敌、追击和攻击判定。
	var target_distance: float = _actor.global_position.distance_to(_target.global_position)
	# 本帧有效视野范围；取值为基础视野或脱战扩展视野，默认让已锁定目标在视野边缘更稳定。
	var active_vision_range: float = vision_range * lose_target_range_multiplier if _has_target else vision_range
	# 目标是否位于有效视野距离内；取值为 true/false，默认距离过远时不会尝试射线索敌。
	var target_within_vision_range: bool = target_distance <= active_vision_range
	# 视线遮挡命中结果；取值为空字典表示无遮挡，默认只在目标进入视野距离后执行射线检测。
	var line_of_sight_hit: Dictionary = {}
	if target_within_vision_range and vision_requires_line_of_sight:
		line_of_sight_hit = get_vision_line_of_sight_hit()

	# 本帧是否能看见目标；取值由距离和视线共同决定，默认墙体会阻挡首次索敌。
	var can_see_target: bool = target_within_vision_range and (not vision_requires_line_of_sight or line_of_sight_hit.is_empty())
	if can_see_target:
		_enter_visible_target_state(delta)
		return

	_continuous_visible_duration = 0.0
	_target_is_visible = false
	if not _has_target:
		return

	_vision_loss_elapsed += delta
	if _target_ai_state == TARGET_AI_STATE_VISIBLE and _vision_loss_elapsed < vision_loss_grace_duration:
		return

	# 本帧是否因环境遮挡丢失视野；取值为 true/false，默认只统计玩家利用墙体、箱体或建筑卡视野的脱离。
	var occlusion_blocked_view: bool = target_within_vision_range and vision_requires_line_of_sight and not line_of_sight_hit.is_empty()
	if _target_ai_state == TARGET_AI_STATE_VISIBLE:
		_begin_lost_target_search(occlusion_blocked_view, line_of_sight_hit)
		return

	_update_lost_target_search(delta)


func _enter_visible_target_state(delta: float) -> void:
	if not is_instance_valid(_target):
		return

	# 进入可见状态前的 AI 状态；取值用于判断是否刚从搜查或空闲切回追击。
	var previous_ai_state: int = _target_ai_state
	_has_target = true
	_target_is_visible = true
	_target_ai_state = TARGET_AI_STATE_VISIBLE
	_has_last_occlusion_position = false
	_vision_loss_elapsed = 0.0
	_continuous_visible_duration += delta
	if occlusion_count_reset_duration <= 0.0 or _continuous_visible_duration >= occlusion_count_reset_duration:
		_line_of_sight_loss_count = 0

	_remember_target_position(_target.global_position, delta)
	_reset_target_search()
	_emit_state_change(previous_ai_state)


func _begin_lost_target_search(occlusion_blocked_view: bool, line_of_sight_hit: Dictionary) -> void:
	if not _has_last_known_target_position:
		_forget_target()
		return

	# 进入搜查状态前的 AI 状态；取值用于向宿主通知导航目标已经改变。
	var previous_ai_state: int = _target_ai_state
	_target_is_visible = false
	_target_ai_state = TARGET_AI_STATE_SEARCHING
	_vision_loss_elapsed = 0.0
	if occlusion_blocked_view:
		_line_of_sight_loss_count += 1
		_remember_occlusion_position(line_of_sight_hit)

	if _line_of_sight_loss_count >= occlusion_break_forget_count:
		_forget_target()
		return

	# 初始搜查锚点；取值来自遮挡物背后或最后可见位置预测，默认模拟敌人前往最后线索处排查。
	var initial_search_anchor: Vector2 = _get_lost_target_search_anchor()
	_target_search_anchor_position = initial_search_anchor
	_target_search_destination = initial_search_anchor
	_has_target_search_destination = true
	_has_reached_lost_search_anchor = false
	_target_memory_remaining = maxf(_target_memory_remaining, target_memory_duration)
	_target_search_remaining = 0.0
	_target_search_wait_remaining = 0.0
	_emit_state_change(previous_ai_state)


func _update_lost_target_search(delta: float) -> void:
	_target_memory_remaining = maxf(_target_memory_remaining - delta, 0.0)
	if _has_reached_lost_search_anchor:
		_target_search_remaining = maxf(_target_search_remaining - delta, 0.0)

	if _target_search_wait_remaining > 0.0:
		_target_search_wait_remaining = maxf(_target_search_wait_remaining - delta, 0.0)
		if _target_search_wait_remaining <= 0.0 and _target_search_remaining > 0.0:
			_pick_next_target_search_destination()

	if _should_continue_lost_target_search():
		return

	_forget_target()


func _remember_occlusion_position(line_of_sight_hit: Dictionary) -> void:
	if not line_of_sight_hit.has("position"):
		return

	# 遮挡命中位置；取值为 PhysicsRayQueryParameters2D 的 position 字段，默认用于推导遮挡物背后的搜查锚点。
	var raw_position: Variant = line_of_sight_hit["position"]
	if raw_position is Vector2:
		_last_occlusion_position = raw_position
		_has_last_occlusion_position = true


func has_vision_line_of_sight_to_target() -> bool:
	if not vision_requires_line_of_sight:
		return is_instance_valid(_target)

	if not is_instance_valid(_target):
		return false

	return get_vision_line_of_sight_hit().is_empty()


func get_vision_line_of_sight_hit() -> Dictionary:
	if not vision_requires_line_of_sight or not is_instance_valid(_actor) or not is_instance_valid(_target):
		# 空命中结果；取值为空字典，默认表示没有可记录的环境遮挡点。
		var empty_hit_result: Dictionary = {}
		return empty_hit_result

	# 视线检测参数；取值为怪物到玩家之间的线段，默认只检测环境墙体和建筑。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(_actor.global_position, _target.global_position, vision_line_of_sight_collision_mask, [_actor.get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 视线命中结果；取值为空表示无遮挡，非空时包含遮挡物和命中位置，默认用于决定发现或启动搜查。
	return _actor.get_world_2d().direct_space_state.intersect_ray(query)


func _remember_target_position(target_position: Vector2, delta: float = 0.0) -> void:
	if _has_last_known_target_position and delta > 0.001:
		# 目标瞬时速度；取值由本帧目标位置变化估算，用于失去视野后的短距离预测。
		var measured_velocity: Vector2 = (target_position - _last_known_target_position) / delta
		_estimated_target_velocity = measured_velocity

	_last_known_target_position = target_position
	_has_last_known_target_position = true
	_target_memory_remaining = target_memory_duration


func _forget_target() -> void:
	# 清除记忆前的 AI 状态；取值用于通知宿主停止搜寻并恢复巡逻。
	var previous_ai_state: int = _target_ai_state
	_has_target = false
	_target_is_visible = false
	_target_ai_state = TARGET_AI_STATE_IDLE
	_has_last_known_target_position = false
	_target_memory_remaining = 0.0
	_estimated_target_velocity = Vector2.ZERO
	_has_last_occlusion_position = false
	_line_of_sight_loss_count = 0
	_continuous_visible_duration = 0.0
	_vision_loss_elapsed = 0.0
	_reset_target_search()
	_emit_state_change(previous_ai_state)


func get_current_chase_destination() -> Vector2:
	if _target_is_visible and is_instance_valid(_target):
		return _target.global_position

	if _has_target_search_destination:
		return _target_search_destination

	if _has_last_known_target_position:
		return _get_predicted_target_position()

	return _actor.global_position if is_instance_valid(_actor) else Vector2.ZERO


func _should_continue_lost_target_search() -> bool:
	if not is_instance_valid(_actor):
		return false

	if _has_target_search_destination:
		# 当前搜索点距离；取值为怪物到搜索点的距离，默认用于判断是否需要切换下一个搜索点。
		var search_point_distance: float = _actor.global_position.distance_to(_target_search_destination)
		if not _has_reached_lost_search_anchor:
			if search_point_distance > search_arrive_distance:
				return _target_memory_remaining > 0.0

			_has_reached_lost_search_anchor = true
			_target_search_anchor_position = _target_search_destination
			_target_search_remaining = target_search_duration_after_arrival
			if _target_search_remaining <= 0.0:
				return false

			_pick_next_target_search_destination()
			return true

		if _target_search_remaining <= 0.0:
			return false

		if _target_search_wait_remaining > 0.0:
			return true

		if search_point_distance <= search_arrive_distance:
			_target_search_wait_remaining = _get_next_search_wait()
			if _target_search_wait_remaining <= 0.0:
				_pick_next_target_search_destination()

		return true

	if not _has_last_known_target_position or _target_memory_remaining <= 0.0:
		return false

	# 兜底搜查锚点；取值来自最后线索，默认用于异常情况下恢复丢失搜查移动。
	var fallback_search_anchor: Vector2 = _get_lost_target_search_anchor()
	_target_search_anchor_position = fallback_search_anchor
	_target_search_destination = fallback_search_anchor
	_has_target_search_destination = true
	_has_reached_lost_search_anchor = false
	return true


func _get_lost_target_search_anchor() -> Vector2:
	# 预测兜底点；取值来自最后可见坐标和最后可见阶段估算速度，默认用于没有遮挡命中点时继续搜查。
	var fallback_anchor: Vector2 = _get_predicted_target_position()
	if not _has_last_occlusion_position or not is_instance_valid(_actor):
		return fallback_anchor

	# 遮挡物背后方向；取值为怪物指向遮挡命中点的方向，默认模拟敌人从自己视角绕到遮挡物背面。
	var occlusion_direction: Vector2 = _last_occlusion_position - _actor.global_position
	if occlusion_direction.is_zero_approx() and _has_last_known_target_position:
		occlusion_direction = _last_known_target_position - _actor.global_position
	if occlusion_direction.is_zero_approx():
		return fallback_anchor

	# 遮挡物背后锚点；取值为命中点沿遮挡方向推进，默认交给 A* 自动寻找入口或可走近邻格。
	var occlusion_anchor: Vector2 = _last_occlusion_position + occlusion_direction.normalized() * lost_search_occlusion_offset
	return occlusion_anchor


func _get_predicted_target_position() -> Vector2:
	if not _has_last_known_target_position:
		return _actor.global_position if is_instance_valid(_actor) else Vector2.ZERO

	# 预测偏移；取值为估算速度乘预测时间，默认让怪物追向玩家移动趋势的前方。
	var prediction_offset: Vector2 = _estimated_target_velocity * target_prediction_time
	# 最大预测距离；取值至少为 0，默认限制推断点偏离最后目标位置的最大距离。
	var max_prediction_distance: float = target_prediction_max_distance
	if max_prediction_distance > 0.0 and prediction_offset.length() > max_prediction_distance:
		prediction_offset = prediction_offset.normalized() * max_prediction_distance

	return _last_known_target_position + prediction_offset


func _pick_next_target_search_destination() -> void:
	if _target_search_remaining <= 0.0:
		_has_target_search_destination = false
		return

	# 搜索半径；取值至少为 0，默认用于在推断点周围随机选择扫荡位置。
	var resolved_search_radius: float = target_search_radius
	if resolved_search_radius <= 0.0:
		_target_search_destination = _target_search_anchor_position
		_has_target_search_destination = true
		return

	# 兜底搜索点；取值为锚点，默认在多次随机点都不适合时至少保持在最后线索附近。
	var fallback_destination: Vector2 = _target_search_anchor_position
	# 搜索点尝试次数；取值至少为 1，默认优先挑选不会让怪物刚起步就贴墙的方向。
	var attempt_count: int = lost_search_destination_attempts
	# 搜索点尝试索引；取值为 0 到尝试次数减一，默认逐个验证候选点。
	for attempt_index in range(attempt_count):
		# 搜索角度；取值为 0 到 TAU 的随机弧度，默认让怪物在目标消失点附近不固定走同一方向。
		var search_angle: float = _random.randf_range(0.0, TAU) if _random != null else randf_range(0.0, TAU)
		# 搜索距离；取值为搜索半径的 35% 到 100%，默认避免所有搜索点都挤在锚点中心。
		var search_distance: float = _random.randf_range(resolved_search_radius * 0.35, resolved_search_radius) if _random != null else randf_range(resolved_search_radius * 0.35, resolved_search_radius)
		# 候选搜索点；取值为锚点周边坐标，默认用于搜查遮挡物后方、入口和室内周边。
		var candidate_destination: Vector2 = _target_search_anchor_position + Vector2.RIGHT.rotated(search_angle) * search_distance
		if attempt_index == 0:
			fallback_destination = candidate_destination

		# 候选起步方向；取值为怪物到候选点的方向，默认用于过滤明显会立即撞墙的巡逻点。
		var candidate_direction: Vector2 = candidate_destination - _actor.global_position if is_instance_valid(_actor) else Vector2.ZERO
		if candidate_direction.is_zero_approx() or _is_search_destination_valid(candidate_destination):
			_target_search_destination = candidate_destination
			_has_target_search_destination = true
			return

	_target_search_destination = fallback_destination
	_has_target_search_destination = true


func _is_search_destination_valid(candidate_destination: Vector2) -> bool:
	if not _destination_validator.is_valid():
		return true

	return bool(_destination_validator.call(candidate_destination))


func _get_next_search_wait() -> float:
	if target_search_point_wait_max <= 0.0:
		return 0.0

	return _random.randf_range(target_search_point_wait_min, target_search_point_wait_max) if _random != null else randf_range(target_search_point_wait_min, target_search_point_wait_max)


func _reset_target_search() -> void:
	_has_target_search_destination = false
	_target_search_remaining = 0.0
	_has_reached_lost_search_anchor = false
	_target_search_wait_remaining = 0.0


func _emit_state_change(previous_ai_state: int) -> void:
	if previous_ai_state != _target_ai_state:
		state_changed.emit(previous_ai_state, _target_ai_state)


func has_target() -> bool:
	return _has_target


func is_target_visible() -> bool:
	return _target_is_visible


func get_ai_state() -> int:
	return _target_ai_state


func is_movement_paused() -> bool:
	return _target_ai_state == TARGET_AI_STATE_SEARCHING and _target_search_wait_remaining > 0.0


func get_line_of_sight_loss_count() -> int:
	return _line_of_sight_loss_count


func get_search_destination() -> Vector2:
	return _target_search_destination
