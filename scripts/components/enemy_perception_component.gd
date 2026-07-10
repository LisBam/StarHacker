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
## AI 二级全域封锁状态；默认表示玩家已多次利用墙体脱离视野，小队扩大外围岔路和墙体近点封锁范围。
const TARGET_AI_STATE_BLOCKADE: int = 3

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
## 战术记忆补充：项目当前默认采用 30 秒短期记忆，原 8 秒说明保留用于追溯旧场景基线。
var target_memory_duration: float = 30.0
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
## 中期战术记忆时间；取值建议大于短期记忆，默认 60 秒，记录高频墙角与逃生通道并支持巡逻途经时复查。
var medium_memory_duration: float = 60.0
## 中期热点合并距离；默认 96 像素，相邻墙角记录会合并并累计频次，修改会影响高频藏点统计粒度。
var medium_hotspot_merge_distance: float = 96.0
## 中期热点最大数量；默认 12，限制单次交战片区的墙角与逃生通道记录规模。
var medium_hotspot_max_count: int = 12
## 巡逻复查触发半径；默认 120 像素，三级常规警戒途经中期热点时会驻足额外搜查。
var medium_recheck_trigger_radius: float = 120.0
## 巡逻复查持续时间；默认 3.5 秒，只执行短时区域复查，结束后继续预设巡逻或原地待机。
var medium_recheck_duration: float = 3.5
## 巡逻复查冷却；默认 8 秒，避免 AI 在同一热点反复进入短时搜查并原地转圈。
var medium_recheck_cooldown: float = 8.0
## 长期交战片区半径；默认 520 像素，仅记录当前交战区域，短中期记忆消退后仍维持路过时的高警戒。
var long_term_region_radius: float = 520.0
## 二级封锁提前量；默认 1，卡墙次数距离脱战阈值剩余一次时进入全域封锁而不是继续普通搜查。
var blockade_loss_margin: int = 1
## 实心墙体分组；默认 environment_obstacles，只有该组碰撞体可以完全阻断敌人视线。
var solid_wall_group: StringName = &"environment_obstacles"
## 视线透明碰撞跳过上限；默认 12，射线遇到非墙体地图元素时会排除后继续检测后方实心墙。
var line_of_sight_skip_limit: int = 12
## 可见线索刷新间隔；默认 0.45 秒，持续看见玩家时定期刷新本怪物内部最后可见坐标。
var visible_intelligence_broadcast_interval: float = 0.45

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
## 中期记忆剩余时间；取值大于等于 0，默认 0，确认墙体遮挡后刷新为 medium_memory_duration。
var _medium_memory_remaining: float = 0.0
## 中期高频热点；每项包含 position 与 count，默认空数组，记录玩家反复使用的墙角和逃生方向点。
var _medium_hotspots: Array[Dictionary] = []
## 长期交战片区中心；取值为世界坐标，仅在 _has_long_term_region 为 true 时有效。
var _long_term_region_center: Vector2 = Vector2.ZERO
## 是否存在长期交战片区；默认 false，首次看见玩家后创建且后续只记录当前片区。
var _has_long_term_region: bool = false
## 最后逃跑方向；取值为最后可见速度的单位向量，默认零向量，用于共享路线预判。
var _last_escape_direction: Vector2 = Vector2.ZERO
## 本地战术线索版本；取值单调递增，默认 0，每次确认消失线索时通知本怪物战术组件刷新。
var _intelligence_revision: int = 0
## 最近一次本地线索时间戳；取值为 Time.get_ticks_msec()，默认 0 表示尚未形成可用消失线索。
var _last_intelligence_timestamp_msec: int = 0
## 当前是否正在执行中期热点复查；默认 false，用于区分主动丢失搜查和巡逻途经后的短时驻足。
var _is_medium_memory_recheck: bool = false
## 中期热点复查冷却剩余时间；取值大于等于 0，默认 0，避免离开复查后立刻重复触发。
var _medium_recheck_cooldown_remaining: float = 0.0
## 可见线索刷新剩余时间；取值大于等于 0，默认 0，进入可见状态后立即记录并按间隔刷新。
var _visible_intelligence_broadcast_remaining: float = 0.0
## 最近情报类型；取值为 visible_contact、occlusion_loss 或 target_lost，默认空字符串表示尚未形成共享报告。
var _last_intelligence_type: String = ""


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
	medium_memory_duration = maxf(float(settings.get("medium_memory_duration", medium_memory_duration)), 0.0)
	medium_hotspot_merge_distance = maxf(float(settings.get("medium_hotspot_merge_distance", medium_hotspot_merge_distance)), 1.0)
	medium_hotspot_max_count = maxi(int(settings.get("medium_hotspot_max_count", medium_hotspot_max_count)), 1)
	medium_recheck_trigger_radius = maxf(float(settings.get("medium_recheck_trigger_radius", medium_recheck_trigger_radius)), 1.0)
	medium_recheck_duration = maxf(float(settings.get("medium_recheck_duration", medium_recheck_duration)), 0.0)
	medium_recheck_cooldown = maxf(float(settings.get("medium_recheck_cooldown", medium_recheck_cooldown)), 0.0)
	long_term_region_radius = maxf(float(settings.get("long_term_region_radius", long_term_region_radius)), 1.0)
	blockade_loss_margin = maxi(int(settings.get("blockade_loss_margin", blockade_loss_margin)), 0)
	solid_wall_group = StringName(str(settings.get("solid_wall_group", solid_wall_group)))
	line_of_sight_skip_limit = maxi(int(settings.get("line_of_sight_skip_limit", line_of_sight_skip_limit)), 1)
	visible_intelligence_broadcast_interval = maxf(float(settings.get("visible_intelligence_broadcast_interval", visible_intelligence_broadcast_interval)), 0.05)


func set_target(target_node: Node) -> void:
	_target = target_node as Node2D
	_forget_target()


func update(delta: float) -> void:
	_update_memory_timers(delta)
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
		_try_begin_medium_memory_recheck()
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
	_vision_loss_elapsed = 0.0
	_is_medium_memory_recheck = false
	_continuous_visible_duration += delta
	if occlusion_count_reset_duration <= 0.0 or _continuous_visible_duration >= occlusion_count_reset_duration:
		_line_of_sight_loss_count = 0

	_remember_target_position(_target.global_position, delta)
	_update_long_term_region(_target.global_position)
	if previous_ai_state != TARGET_AI_STATE_VISIBLE or _visible_intelligence_broadcast_remaining <= 0.0:
		_mark_intelligence_changed("visible_contact")
		_visible_intelligence_broadcast_remaining = visible_intelligence_broadcast_interval
	_reset_target_search()
	_emit_state_change(previous_ai_state)


func _begin_lost_target_search(occlusion_blocked_view: bool, line_of_sight_hit: Dictionary) -> void:
	if not _has_last_known_target_position:
		_enter_regular_alert_state()
		return

	# 进入搜查状态前的 AI 状态；取值用于向宿主通知导航目标已经改变。
	var previous_ai_state: int = _target_ai_state
	_target_is_visible = false
	_target_ai_state = TARGET_AI_STATE_SEARCHING
	_vision_loss_elapsed = 0.0
	# 本次丢失情报类型；墙体遮挡同步墙角信息，超出视野距离等情况只同步最后线索并继续追踪。
	var lost_intelligence_type: String = "occlusion_loss" if occlusion_blocked_view else "target_lost"
	_target_memory_remaining = maxf(_target_memory_remaining, target_memory_duration)
	_update_long_term_region(_last_known_target_position)
	if occlusion_blocked_view:
		_line_of_sight_loss_count += 1
		_remember_occlusion_position(line_of_sight_hit)
		_record_tactical_memory()

	# 二级封锁进入计数；取值为脱战阈值减提前量，最小为 1，用于在临界前扩大封锁范围。
	var blockade_start_count: int = maxi(occlusion_break_forget_count - blockade_loss_margin, 1)
	if occlusion_blocked_view and _line_of_sight_loss_count >= blockade_start_count and _line_of_sight_loss_count < occlusion_break_forget_count:
		_target_ai_state = TARGET_AI_STATE_BLOCKADE

	if occlusion_blocked_view and _line_of_sight_loss_count >= occlusion_break_forget_count:
		_mark_intelligence_changed(lost_intelligence_type)
		_enter_regular_alert_state()
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
	_is_medium_memory_recheck = false
	_mark_intelligence_changed(lost_intelligence_type)
	_emit_state_change(previous_ai_state)


func _update_lost_target_search(delta: float) -> void:
	if _has_reached_lost_search_anchor:
		_target_search_remaining = maxf(_target_search_remaining - delta, 0.0)

	if _target_search_wait_remaining > 0.0:
		_target_search_wait_remaining = maxf(_target_search_wait_remaining - delta, 0.0)
		if _target_search_wait_remaining <= 0.0 and _target_search_remaining > 0.0:
			_pick_next_target_search_destination()

	if _should_continue_lost_target_search():
		return

	_enter_regular_alert_state()


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

	return _get_solid_wall_hit(_target.global_position)


func _get_solid_wall_hit(target_position: Vector2) -> Dictionary:
	# 射线排除 RID；初始只排除宿主，遇到非墙体元素后继续追加，使其不会错误触发视野丢失。
	var excluded_rids: Array[RID] = [_actor.get_rid()]
	# 射线跳过索引；取值为 0 到 line_of_sight_skip_limit 减一，限制透明元素过多时的重复物理查询开销。
	for _skip_index in range(line_of_sight_skip_limit):
		# 视线检测参数；取值为怪物到玩家之间的线段，默认使用配置掩码后再按实心墙体分组过滤。
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(_actor.global_position, target_position, vision_line_of_sight_collision_mask, excluded_rids)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		# 视线命中结果；取值为空表示无遮挡，非空时先确认碰撞体是否属于实心墙体组。
		var hit_result: Dictionary = _actor.get_world_2d().direct_space_state.intersect_ray(query)
		if hit_result.is_empty():
			return hit_result

		# 命中碰撞体；取值可能为 CollisionObject2D、其他 Object 或 null，默认只让实心墙体组阻断视线。
		var raw_collider: Variant = hit_result.get("collider")
		if raw_collider is Node and (raw_collider as Node).is_in_group(solid_wall_group):
			return hit_result

		if raw_collider is CollisionObject2D:
			excluded_rids.append((raw_collider as CollisionObject2D).get_rid())
			continue

		# 空命中结果；无法排除的非墙体对象按透明处理，避免把装饰或其他地图元素视为完整遮挡。
		var transparent_result: Dictionary = {}
		return transparent_result

	# 空命中结果；达到跳过上限后按视线未被实心墙阻挡处理，避免非墙体元素导致永久丢失目标。
	var fallback_empty_result: Dictionary = {}
	return fallback_empty_result


func _remember_target_position(target_position: Vector2, delta: float = 0.0) -> void:
	if _has_last_known_target_position and delta > 0.001:
		# 目标瞬时速度；取值由本帧目标位置变化估算，用于失去视野后的短距离预测。
		var measured_velocity: Vector2 = (target_position - _last_known_target_position) / delta
		_estimated_target_velocity = measured_velocity
		if not measured_velocity.is_zero_approx():
			_last_escape_direction = measured_velocity.normalized()

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
	_medium_memory_remaining = 0.0
	_medium_hotspots.clear()
	_has_long_term_region = false
	_long_term_region_center = Vector2.ZERO
	_last_escape_direction = Vector2.ZERO
	_intelligence_revision = 0
	_last_intelligence_timestamp_msec = 0
	_last_intelligence_type = ""
	_is_medium_memory_recheck = false
	_medium_recheck_cooldown_remaining = 0.0
	_reset_target_search()
	_emit_state_change(previous_ai_state)


func _enter_regular_alert_state() -> void:
	# 进入常规警戒前的 AI 状态；取值用于通知宿主停止主动搜寻并恢复巡逻或待机。
	var previous_ai_state: int = _target_ai_state
	_has_target = false
	_target_is_visible = false
	_target_ai_state = TARGET_AI_STATE_IDLE
	_continuous_visible_duration = 0.0
	_vision_loss_elapsed = 0.0
	_is_medium_memory_recheck = false
	_medium_recheck_cooldown_remaining = medium_recheck_cooldown
	_reset_target_search()
	_emit_state_change(previous_ai_state)


func _update_memory_timers(delta: float) -> void:
	_medium_recheck_cooldown_remaining = maxf(_medium_recheck_cooldown_remaining - delta, 0.0)
	_visible_intelligence_broadcast_remaining = maxf(_visible_intelligence_broadcast_remaining - delta, 0.0)
	if _target_ai_state != TARGET_AI_STATE_VISIBLE:
		_target_memory_remaining = maxf(_target_memory_remaining - delta, 0.0)
	_medium_memory_remaining = maxf(_medium_memory_remaining - delta, 0.0)
	if _medium_memory_remaining <= 0.0:
		_medium_hotspots.clear()

	if _target_memory_remaining <= 0.0 and not _target_is_visible and not _has_target:
		_has_last_known_target_position = false
		_has_last_occlusion_position = false
		_estimated_target_velocity = Vector2.ZERO
		_last_escape_direction = Vector2.ZERO


func _record_tactical_memory() -> void:
	if not _has_last_known_target_position:
		return

	_target_memory_remaining = target_memory_duration
	_medium_memory_remaining = medium_memory_duration
	_update_long_term_region(_last_known_target_position)
	_record_medium_hotspot(_last_occlusion_position if _has_last_occlusion_position else _last_known_target_position)
	if not _last_escape_direction.is_zero_approx():
		# 预测逃生热点；取值为最后可见位置沿逃跑方向前推，默认代表玩家常用岔路或房间出口方向。
		var escape_hotspot: Vector2 = _last_known_target_position + _last_escape_direction * minf(target_prediction_max_distance, lost_search_occlusion_offset * 2.0)
		_record_medium_hotspot(escape_hotspot)


func _record_medium_hotspot(hotspot_position: Vector2) -> void:
	# 热点数组索引；取值为 0 到现有热点数量减一，用于合并同一墙角附近的重复脱战记录。
	for hotspot_index in range(_medium_hotspots.size()):
		# 热点记录；包含 position 与 count，默认从数组复制后修改并写回。
		var hotspot: Dictionary = _medium_hotspots[hotspot_index]
		# 热点原始位置；取值异常时回退当前记录点，避免共享字典类型错误。
		var raw_hotspot_position: Variant = hotspot.get("position", hotspot_position)
		if not (raw_hotspot_position is Vector2):
			continue
		# 已有热点位置；取值为世界坐标，用于判断是否属于同一墙角或逃生通道。
		var existing_position: Vector2 = raw_hotspot_position
		if existing_position.distance_to(hotspot_position) > medium_hotspot_merge_distance:
			continue

		# 新热点频次；取值至少 1，重复利用同一区域时累加并提高后续复查优先级。
		var updated_count: int = int(hotspot.get("count", 1)) + 1
		hotspot["position"] = existing_position.lerp(hotspot_position, 1.0 / float(updated_count))
		hotspot["count"] = updated_count
		_medium_hotspots[hotspot_index] = hotspot
		return

	_medium_hotspots.append({"position": hotspot_position, "count": 1})
	if _medium_hotspots.size() <= medium_hotspot_max_count:
		return

	# 最低频热点索引；默认 0，超过容量时移除频次最低且维护价值最小的记录。
	var least_used_index: int = 0
	# 最低热点频次；默认取第一项，后续遇到更小频次时更新索引。
	var least_used_count: int = int(_medium_hotspots[0].get("count", 1))
	# 热点裁剪索引；取值从 1 到数组末尾，默认查找最低频项。
	for trim_index in range(1, _medium_hotspots.size()):
		# 候选热点频次；取值至少按字典默认 1，用于与当前最低值比较。
		var candidate_count: int = int(_medium_hotspots[trim_index].get("count", 1))
		if candidate_count < least_used_count:
			least_used_count = candidate_count
			least_used_index = trim_index
	_medium_hotspots.remove_at(least_used_index)


func _update_long_term_region(sample_position: Vector2) -> void:
	if not _has_long_term_region or _long_term_region_center.distance_to(sample_position) > long_term_region_radius * 1.8:
		_long_term_region_center = sample_position
		_has_long_term_region = true
		return

	_long_term_region_center = _long_term_region_center.lerp(sample_position, 0.12)


func _try_begin_medium_memory_recheck() -> void:
	if _medium_memory_remaining <= 0.0 or _medium_hotspots.is_empty() or _medium_recheck_cooldown_remaining > 0.0:
		return

	# 优先复查热点；取值由频次高且距离当前巡逻位置近的记录选出，空字典表示没有合法点。
	var priority_hotspot: Dictionary = _get_priority_medium_hotspot()
	if priority_hotspot.is_empty():
		return

	# 复查点原始值；取值应为 Vector2，类型异常时不改变常规巡逻状态。
	var raw_recheck_position: Variant = priority_hotspot.get("position")
	if not (raw_recheck_position is Vector2):
		return

	# 中期复查位置；取值为历史高频墙角或逃生通道点，只有巡逻途经附近才触发。
	var recheck_position: Vector2 = raw_recheck_position
	if _actor.global_position.distance_to(recheck_position) > medium_recheck_trigger_radius:
		return

	# 复查前状态；默认三级常规警戒，用于向宿主通知短时搜查开始。
	var previous_ai_state: int = _target_ai_state
	_has_target = true
	_target_is_visible = false
	_target_ai_state = TARGET_AI_STATE_SEARCHING
	_target_search_anchor_position = recheck_position
	_target_search_destination = recheck_position
	_has_target_search_destination = true
	_has_reached_lost_search_anchor = false
	_target_memory_remaining = medium_recheck_duration
	_target_search_remaining = medium_recheck_duration
	_target_search_wait_remaining = 0.0
	_is_medium_memory_recheck = true
	_emit_state_change(previous_ai_state)


func _get_priority_medium_hotspot() -> Dictionary:
	# 最佳热点；默认空字典，按频次权重减去距离代价选择巡逻复查目标。
	var best_hotspot: Dictionary = {}
	# 最佳热点评分；默认负无穷，评分越高表示使用频次高且离当前巡逻位置更近。
	var best_score: float = -INF
	# 中期热点记录；取值为包含位置与频次的字典，默认逐项做类型校验。
	for hotspot in _medium_hotspots:
		# 热点位置原始值；取值应为 Vector2，异常项直接忽略。
		var raw_position: Variant = hotspot.get("position")
		if not (raw_position is Vector2):
			continue
		# 热点位置；取值为世界坐标，用于计算当前巡逻距离。
		var hotspot_position: Vector2 = raw_position
		# 热点评分；频次每次增加 240 分，距离每像素扣 1 分，使高频远点与低频近点保持可调平衡。
		var hotspot_score: float = float(hotspot.get("count", 1)) * 240.0 - _actor.global_position.distance_to(hotspot_position)
		if hotspot_score > best_score:
			best_score = hotspot_score
			best_hotspot = hotspot
	return best_hotspot


func _mark_intelligence_changed(intelligence_type: String = "occlusion_loss") -> void:
	_intelligence_revision += 1
	_last_intelligence_timestamp_msec = Time.get_ticks_msec()
	_last_intelligence_type = intelligence_type


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
			_target_search_remaining = medium_recheck_duration if _is_medium_memory_recheck else target_search_duration_after_arrival
			if _target_search_remaining <= 0.0:
				return false

			_pick_next_target_search_destination()
			return true

		if _target_search_remaining <= 0.0:
			if _is_medium_memory_recheck or _target_memory_remaining <= 0.0:
				return false

			_target_search_remaining = minf(target_search_duration_after_arrival, _target_memory_remaining)
			_pick_next_target_search_destination()
			return _target_search_remaining > 0.0

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


func receive_shared_intelligence(report: Dictionary) -> void:
	# 怪物情报共享已删除；兼容入口不再接收任何外部怪物报告。
	return

	if report.is_empty() or not is_instance_valid(_actor):
		return

	# 共享目标编号；取值为发送者锁定目标实例编号，默认只接收与本组件当前目标一致的战术情报。
	var shared_target_id: int = int(report.get("target_instance_id", 0))
	if is_instance_valid(_target) and shared_target_id != 0 and shared_target_id != _target.get_instance_id():
		return

	# 共享情报类型；visible_contact 表示队友当前发现玩家，occlusion_loss 表示玩家刚进入实心墙体后方，target_lost 表示玩家快速离开有效视野但仍需前往最后线索追踪。
	var shared_intelligence_type: String = str(report.get("intelligence_type", "occlusion_loss"))

	# 共享消失位置原始值；取值应为 Vector2，缺失或异常时不改变本地记忆。
	var raw_disappearance_position: Variant = report.get("disappearance_position")
	if raw_disappearance_position is Vector2:
		_last_known_target_position = raw_disappearance_position
		_has_last_known_target_position = true

	# 共享遮挡位置原始值；取值应为 Vector2，记录队友射线命中的实心墙体坐标。
	var raw_occlusion_position: Variant = report.get("occlusion_position")
	if shared_intelligence_type == "occlusion_loss" and raw_occlusion_position is Vector2:
		_last_occlusion_position = raw_occlusion_position
		_has_last_occlusion_position = true

	# 共享估算速度原始值；取值应为 Vector2，只来自玩家最后可见阶段而非墙后实时位置。
	var raw_estimated_velocity: Variant = report.get("estimated_velocity")
	if raw_estimated_velocity is Vector2:
		_estimated_target_velocity = raw_estimated_velocity

	# 共享逃跑方向原始值；取值应为 Vector2，用于全队一致预判岔路和房间出口。
	var raw_escape_direction: Variant = report.get("escape_direction")
	if raw_escape_direction is Vector2:
		_last_escape_direction = raw_escape_direction

	if shared_intelligence_type == "occlusion_loss":
		_line_of_sight_loss_count = maxi(_line_of_sight_loss_count, int(report.get("loss_count", 0)))
	_target_memory_remaining = maxf(_target_memory_remaining, target_memory_duration)
	if shared_intelligence_type == "occlusion_loss":
		_medium_memory_remaining = maxf(_medium_memory_remaining, medium_memory_duration)
	if _has_last_known_target_position:
		_update_long_term_region(_last_known_target_position)
		if shared_intelligence_type == "occlusion_loss":
			_record_medium_hotspot(_last_occlusion_position if _has_last_occlusion_position else _last_known_target_position)

	# 共享中期热点数组；取值为发送者已记录的墙角与逃生通道，默认只合并合法 Vector2 位置。
	var raw_shared_hotspots: Variant = report.get("medium_hotspots", [])
	if shared_intelligence_type == "occlusion_loss" and raw_shared_hotspots is Array:
		# 共享热点遍历项；取值可能为 Dictionary 或其他 Variant，默认逐项校验。
		for raw_shared_hotspot in raw_shared_hotspots:
			if not (raw_shared_hotspot is Dictionary):
				continue
			# 共享热点字典；包含 position 与 count，默认先读取位置再按频次有限次合并。
			var shared_hotspot: Dictionary = raw_shared_hotspot
			# 共享热点位置原始值；取值应为 Vector2，异常项忽略。
			var raw_shared_position: Variant = shared_hotspot.get("position")
			if raw_shared_position is Vector2:
				_record_medium_hotspot(raw_shared_position)

	if _target_is_visible:
		return

	if shared_intelligence_type == "occlusion_loss" and _line_of_sight_loss_count >= occlusion_break_forget_count:
		_enter_regular_alert_state()
		return

	# 接收情报前的 AI 状态；取值用于通知宿主清理旧导航路径并切换分区任务。
	var previous_ai_state: int = _target_ai_state
	# 二级封锁进入计数；取值为脱战阈值减提前量，最小为 1。
	var blockade_start_count: int = maxi(occlusion_break_forget_count - blockade_loss_margin, 1)
	_has_target = true
	_target_is_visible = false
	_target_ai_state = TARGET_AI_STATE_BLOCKADE if shared_intelligence_type == "occlusion_loss" and _line_of_sight_loss_count >= blockade_start_count else TARGET_AI_STATE_SEARCHING
	# 共享搜查锚点原始值；取值应为 Vector2，缺失时按本地最后线索重新计算。
	var raw_search_anchor: Variant = report.get("search_anchor")
	_target_search_anchor_position = raw_search_anchor if raw_search_anchor is Vector2 else _get_lost_target_search_anchor()
	_target_search_destination = _target_search_anchor_position
	_has_target_search_destination = true
	_has_reached_lost_search_anchor = false
	_target_search_remaining = 0.0
	_target_search_wait_remaining = 0.0
	_is_medium_memory_recheck = false
	_emit_state_change(previous_ai_state)


func get_tactical_intelligence() -> Dictionary:
	if _last_intelligence_timestamp_msec <= 0 or not _has_last_known_target_position:
		return {}

	return {
		"revision": _intelligence_revision,
		"intelligence_type": _last_intelligence_type,
		"timestamp_msec": _last_intelligence_timestamp_msec,
		"source_instance_id": _actor.get_instance_id() if is_instance_valid(_actor) else 0,
		"target_instance_id": _target.get_instance_id() if is_instance_valid(_target) else 0,
		"disappearance_position": _last_known_target_position,
		"occlusion_position": _last_occlusion_position if _has_last_occlusion_position else _last_known_target_position,
		"search_anchor": _get_predicted_target_position() if _last_intelligence_type == "visible_contact" else _get_lost_target_search_anchor(),
		"estimated_velocity": _estimated_target_velocity,
		"escape_direction": _last_escape_direction,
		"loss_count": _line_of_sight_loss_count,
		"alert_state": _target_ai_state,
		"medium_hotspots": _medium_hotspots.duplicate(true),
		"long_term_region_center": _long_term_region_center,
		"long_term_region_radius": long_term_region_radius
	}


func is_in_long_term_alert_region() -> bool:
	return _has_long_term_region and is_instance_valid(_actor) and _actor.global_position.distance_to(_long_term_region_center) <= long_term_region_radius


func get_medium_memory_remaining() -> float:
	return _medium_memory_remaining


func is_medium_memory_recheck() -> bool:
	return _is_medium_memory_recheck


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
	return (_target_ai_state == TARGET_AI_STATE_SEARCHING or _target_ai_state == TARGET_AI_STATE_BLOCKADE) and _target_search_wait_remaining > 0.0


func get_line_of_sight_loss_count() -> int:
	return _line_of_sight_loss_count


func get_search_destination() -> Vector2:
	return _target_search_destination
