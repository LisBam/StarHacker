extends CharacterBody2D
class_name BasicMonster

## 基础怪物维护生命、攻击、移动、视野索敌和近距离攻击。
## GameWorld 负责生成怪物并设置玩家目标，怪物自身不依赖具体关卡结构。

signal health_changed(current_health: float, max_health: float)
signal died

## 战斗爆发特效脚本；默认通过路径预加载，避免怪物脚本依赖 Godot 全局类名缓存解析顺序。
const COMBAT_BURST_EFFECT_SCRIPT: Script = preload("res://scripts/effects/combat_burst_effect.gd")
## AI 空闲状态；默认表示怪物没有玩家记忆，会回到出生点附近巡逻或待机警戒。
const TARGET_AI_STATE_IDLE: int = 0
## AI 可见追击状态；默认表示怪物拥有无遮挡视线，会直接锁定玩家并寻路追击。
const TARGET_AI_STATE_VISIBLE: int = 1
## AI 丢失搜查状态；默认表示玩家被障碍遮挡，怪物只根据最后线索前往遮挡物背后和附近区域搜索。
const TARGET_AI_STATE_SEARCHING: int = 2

## 最大血量；取值应大于 0，默认 60 用于训练场怪物强度，运行时修改会影响怪物承伤能力。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_health: float = 60.0
## 当前血量；取值会被限制在 0 到 max_health，默认 60 表示满血生成，运行时修改会影响怪物当前生存状态。
@export_range(0.0, 9999.0, 1.0, "or_greater") var current_health: float = 60.0
## 武器掉落概率；取值为 0 到 1，默认 0.03 表示 3% 概率掉落随机武器，运行时修改会影响该怪物死亡奖励。
@export_range(0.0, 1.0, 0.001) var weapon_drop_chance: float = 0.03
## 攻击力；取值建议大于等于 0，默认 12 表示每次近身攻击造成的伤害，运行时修改会影响玩家受击压力。
@export_range(0.0, 9999.0, 1.0, "or_greater") var attack_damage: float = 12.0
## 韧性；取值为百分比，默认 0 表示不减免控制，1 表示减少 1% 击退效果，100 表示完全免疫击退。
@export_range(0.0, 100.0, 1.0) var toughness: float = 0.0
## 攻击冲击力；取值建议大于等于 0，默认 180 会在命中玩家时造成短距离击退。
@export_range(0.0, 5000.0, 1.0, "or_greater") var attack_impact_force: float = 180.0
## 移动速度；取值建议大于 0，默认 150 像素每秒，运行时修改会影响怪物追击速度。
@export_range(1.0, 2000.0, 1.0, "or_greater") var move_speed: float = 150.0
## 个体移动速度最小倍率；取值建议 0.5 到 1，默认 0.88，让同类怪物移动速度存在下限差异。
@export_range(0.1, 2.0, 0.01) var move_speed_random_multiplier_min: float = 0.88
## 个体移动速度最大倍率；取值建议大于等于最小倍率，默认 1.16，让同类怪物移动速度存在上限差异。
@export_range(0.1, 2.0, 0.01) var move_speed_random_multiplier_max: float = 1.16
## 视野范围；取值建议大于 0，默认 360 像素，玩家进入该范围后怪物开始索敌追击。
@export_range(1.0, 4000.0, 1.0, "or_greater") var vision_range: float = 360.0
## 攻击距离；取值建议大于 0，默认 42 像素，玩家进入该距离后怪物停止移动并尝试攻击。
@export_range(1.0, 400.0, 1.0, "or_greater") var attack_range: float = 42.0
## 攻击冷却；取值应大于 0，默认 0.9 秒，运行时修改会影响怪物连续攻击频率。
@export_range(0.05, 10.0, 0.05) var attack_cooldown: float = 0.9
## 个体攻击冷却最小倍率；取值建议 0.75 到 1，默认 0.9，让近战怪物攻击节奏存在下限差异。
@export_range(0.1, 3.0, 0.01) var attack_cooldown_random_multiplier_min: float = 0.9
## 个体攻击冷却最大倍率；取值建议大于等于最小倍率，默认 1.3，让近战怪物攻击节奏存在上限差异。
@export_range(0.1, 3.0, 0.01) var attack_cooldown_random_multiplier_max: float = 1.3
## 脱战视野倍率；取值建议大于等于 1，默认 1.25 让怪物不会在视野边缘频繁切换索敌状态。
@export_range(1.0, 4.0, 0.05, "or_greater") var lose_target_range_multiplier: float = 1.25
## 索敌是否需要直线视野；默认 true，墙体会阻挡怪物首次发现玩家。
@export var vision_requires_line_of_sight: bool = true
## 索敌视线遮挡检测掩码；默认检测第 5 层环境墙体，修改会影响哪些障碍能阻挡怪物发现玩家。
@export_flags_2d_physics var vision_line_of_sight_collision_mask: int = 16
## 失去视野后的记忆时间；取值建议大于 0，默认 8 秒，怪物会在这段时间内前往最后看见或推断的玩家位置搜索。
@export_range(0.0, 30.0, 0.1) var target_memory_duration: float = 8.0
## 搜索到达距离；取值建议大于怪物半径，默认 54 像素，怪物靠近推断位置或当前搜索点后会进入扫荡或切换下一个搜索点。
@export_range(1.0, 512.0, 1.0) var search_arrive_distance: float = 54.0
## 旧隔墙警觉追踪范围倍率；取值建议大于 1，默认 1.85，当前三阶段索敌不会读取墙后玩家实时位置。
## 该值保留为旧场景配置兼容，后续如需警戒范围衰减可复用。
@export_range(1.0, 6.0, 0.05, "or_greater") var hidden_target_tracking_range_multiplier: float = 1.85
## 目标预测时间；取值建议 0 到 2 秒，默认 0.55 会按最近移动趋势把搜索点向玩家移动方向前推。
@export_range(0.0, 5.0, 0.05) var target_prediction_time: float = 0.55
## 目标预测最大距离；取值建议大于等于 0，默认 220 像素，防止高速移动或瞬移导致搜索点偏离过远。
@export_range(0.0, 2000.0, 1.0) var target_prediction_max_distance: float = 220.0
## 到达推断位置后的搜索时间；取值建议大于等于 0，默认 4 秒，怪物会围绕推断位置继续扫荡而不是立刻丢失目标。
@export_range(0.0, 30.0, 0.1) var target_search_duration_after_arrival: float = 4.0
## 到达推断位置后的搜索半径；取值建议大于怪物半径，默认 180 像素，修改会影响怪物在墙后区域的扫荡范围。
@export_range(0.0, 2000.0, 1.0) var target_search_radius: float = 180.0
## 卡视野脱战次数阈值；取值建议 2 到 5，默认 3，玩家多次依靠障碍遮挡脱离视线后怪物会彻底丢失目标。
@export_range(1, 12, 1) var occlusion_break_forget_count: int = 3
## 遮挡物背后搜查偏移；取值建议接近建筑墙厚或入口宽度，默认 96 像素，用于从视线命中点向玩家消失方向推导搜查锚点。
@export_range(0.0, 600.0, 1.0) var lost_search_occlusion_offset: float = 96.0
## 搜查点选择尝试次数；取值建议 1 到 12，默认 6，用于在搜查锚点周边优先挑选不会直接撞墙的巡逻点。
@export_range(1, 24, 1) var lost_search_destination_attempts: int = 6
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
## 寻路格子尺寸；取值建议 24 到 96，默认 32 可识别建筑入口，越小路径越细但计算开销越高。
@export_range(16.0, 512.0, 1.0, "or_greater") var pathfinding_cell_size: float = 32.0
## 寻路代理半径；取值建议接近怪物碰撞半径，默认 18 匹配当前怪物圆形碰撞体并保留入口通行能力。
@export_range(0.0, 256.0, 1.0) var pathfinding_agent_radius: float = 18.0
## 路径重算最短间隔；取值建议大于 0，默认 0.55 秒，修改会影响怪物对移动目标的响应频率。
@export_range(0.05, 5.0, 0.05) var path_recalculation_min_interval: float = 0.55
## 路径重算最长间隔；取值应大于等于最短间隔，默认 1.1 秒，怪物会在区间内随机取值以错开路径更新。
@export_range(0.05, 5.0, 0.05) var path_recalculation_max_interval: float = 1.1
## 路径目标刷新距离；取值建议大于 0，默认 64，目标移动超过该距离会触发重新寻路。
@export_range(1.0, 1024.0, 1.0, "or_greater") var path_destination_refresh_distance: float = 64.0
## 路点到达距离；取值建议略大于怪物半径，默认 28，修改会影响怪物切换到下一个路点的时机。
@export_range(1.0, 256.0, 1.0) var path_waypoint_arrive_distance: float = 28.0
## 路径目标随机半径；取值建议 0 到 64，默认 18，只在目标可见时轻微分散怪物终点。
@export_range(0.0, 512.0, 1.0) var path_random_goal_radius: float = 18.0
## 单次路径最大路点数；取值建议 8 到 160，默认 96，修改会影响远距离寻路缓存长度。
@export_range(1, 256, 1) var path_max_point_count: int = 96
## 卡住判定时间；取值建议 0.3 到 1.2 秒，默认 0.75，避免正常转角减速被误判为卡住。
@export_range(0.05, 5.0, 0.05) var stuck_detection_time: float = 0.75
## 卡住判定最小位移；取值建议 0 到 4 像素，默认 0.35，低于该帧位移会累计卡住时间。
@export_range(0.0, 16.0, 0.05) var stuck_minimum_movement: float = 0.35
## 击退速度衰减；取值建议大于 0，默认 1600 像素每秒平方，修改会影响怪物受击后滑退持续时间。
@export_range(1.0, 12000.0, 1.0, "or_greater") var knockback_decay: float = 1600.0
## 怪物受击特效颜色；默认橙红色，修改会影响怪物被命中时的爆发反馈。
@export var hit_effect_color: Color = Color(1.0, 0.45, 0.28, 0.95)
## 怪物死亡特效颜色；默认亮橙色，修改会影响怪物死亡时的爆发反馈。
@export var death_effect_color: Color = Color(1.0, 0.82, 0.34, 1.0)

## 当前追击目标；取值为 Node2D 或 null，默认由 GameWorld 设置，修改会影响怪物追击和攻击对象。
var _target: Node2D
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
## 当前攻击冷却剩余时间；取值大于等于 0，默认 0 表示可立即攻击，修改会影响下次攻击时机。
var _attack_cooldown_remaining: float = 0.0
## 个体移动速度倍率；取值由出生时随机生成，默认 1 表示不改变检查器中的基础速度。
var _move_speed_multiplier: float = 1.0
## 个体攻击冷却倍率；取值由出生时随机生成，默认 1 表示不改变检查器中的基础冷却。
var _attack_cooldown_multiplier: float = 1.0
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
## 当前卡住累计时间；取值大于等于 0，默认 0，持续移动失败时累加并触发重算路径。
var _stuck_time: float = 0.0


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	_spawn_position = global_position
	_random.randomize()
	_randomize_individual_behavior()
	_avoidance_side_bias = -1 if _random.randi_range(0, 1) == 0 else 1
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	_path_recalculate_remaining = maxf(_path_recalculate_remaining - delta, 0.0)
	if not is_instance_valid(_target):
		_forget_target()
		_update_wander(delta)
		_move_with_external_velocity(delta)
		return

	# 目标距离；取值为当前怪物到玩家的距离，默认每帧计算，修改会影响索敌、追击和攻击判定。
	var target_distance: float = global_position.distance_to(_target.global_position)
	_update_target_state(target_distance, delta)
	if not _has_target:
		_update_wander(delta)
		_move_with_external_velocity(delta)
		return

	_update_target_behavior(delta, target_distance)
	_move_with_external_velocity(delta)


func set_target(target_node: Node) -> void:
	_target = target_node as Node2D
	_has_target = false
	_target_is_visible = false
	_target_ai_state = TARGET_AI_STATE_IDLE
	_has_last_known_target_position = false
	_target_memory_remaining = 0.0
	_estimated_target_velocity = Vector2.ZERO
	_has_last_occlusion_position = false
	_line_of_sight_loss_count = 0
	_reset_target_search()
	_clear_navigation_path()


func _randomize_individual_behavior() -> void:
	_move_speed_multiplier = _get_randomized_multiplier(move_speed_random_multiplier_min, move_speed_random_multiplier_max)
	_attack_cooldown_multiplier = _get_randomized_multiplier(attack_cooldown_random_multiplier_min, attack_cooldown_random_multiplier_max)
	_attack_cooldown_remaining = _random.randf_range(0.0, _get_resolved_attack_cooldown())


func _get_randomized_multiplier(minimum_multiplier: float, maximum_multiplier: float) -> float:
	# 标准化最小倍率；取值至少为 0.1，默认防止速度或冷却被随机到 0。
	var resolved_minimum: float = maxf(minf(minimum_multiplier, maximum_multiplier), 0.1)
	# 标准化最大倍率；取值至少为最小倍率，默认防止检查器中上下限反填导致随机范围错误。
	var resolved_maximum: float = maxf(maxf(minimum_multiplier, maximum_multiplier), resolved_minimum)
	return _random.randf_range(resolved_minimum, resolved_maximum)


func _get_resolved_move_speed() -> float:
	return maxf(move_speed, 0.0) * maxf(_move_speed_multiplier, 0.1)


func _get_resolved_attack_cooldown() -> float:
	return maxf(attack_cooldown, 0.05) * maxf(_attack_cooldown_multiplier, 0.1)


func apply_damage(damage: float, source: Node) -> void:
	if damage <= 0.0 or current_health <= 0.0:
		return

	current_health = clampf(current_health - damage, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	_apply_knockback_from_source(source)
	if current_health <= 0.0:
		_spawn_death_effect()
		died.emit()
		queue_free()
	else:
		_spawn_hit_effect()


func _update_target_state(target_distance: float, delta: float) -> void:
	# 本帧有效视野范围；取值为基础视野或脱战扩展视野，默认让已锁定目标在视野边缘更稳定。
	var active_vision_range: float = vision_range * lose_target_range_multiplier if _has_target else vision_range
	# 目标是否位于有效视野距离内；取值为 true/false，默认距离过远时不会尝试射线索敌。
	var target_within_vision_range: bool = target_distance <= active_vision_range
	# 视线遮挡命中结果；取值为空字典表示无遮挡，默认只在目标进入视野距离后执行射线检测。
	var line_of_sight_hit: Dictionary = {}
	if target_within_vision_range and vision_requires_line_of_sight and is_instance_valid(_target):
		line_of_sight_hit = _get_vision_line_of_sight_hit()

	# 本帧是否能看见目标；取值由距离和视线共同决定，默认墙体会阻挡首次索敌。
	var can_see_target: bool = target_within_vision_range and (not vision_requires_line_of_sight or line_of_sight_hit.is_empty())
	if can_see_target:
		_enter_visible_target_state(delta)
		return

	if not _has_target:
		return

	# 本帧是否因环境遮挡丢失视野；取值为 true/false，默认只统计玩家利用墙体、箱体或建筑卡视野的脱离。
	var occlusion_blocked_view: bool = target_within_vision_range and vision_requires_line_of_sight and not line_of_sight_hit.is_empty()
	if _target_ai_state == TARGET_AI_STATE_VISIBLE or _target_is_visible:
		_begin_lost_target_search(occlusion_blocked_view, line_of_sight_hit)
		return

	_target_is_visible = false
	_target_memory_remaining = maxf(_target_memory_remaining - delta, 0.0)
	if _has_reached_lost_search_anchor:
		_target_search_remaining = maxf(_target_search_remaining - delta, 0.0)

	if _should_continue_lost_target_search():
		return

	_forget_target()


func _enter_visible_target_state(delta: float) -> void:
	if not is_instance_valid(_target):
		return

	# 进入可见状态前的 AI 状态；取值用于判断是否刚从搜查或空闲切回追击。
	var previous_ai_state: int = _target_ai_state
	if not _has_target:
		_has_target = true

	_target_is_visible = true
	_target_ai_state = TARGET_AI_STATE_VISIBLE
	_has_last_occlusion_position = false
	_remember_target_position(_target.global_position, delta)
	_reset_target_search()
	if previous_ai_state != TARGET_AI_STATE_VISIBLE:
		_clear_navigation_path()


func _begin_lost_target_search(occlusion_blocked_view: bool, line_of_sight_hit: Dictionary) -> void:
	if not _has_last_known_target_position:
		_forget_target()
		return

	_target_is_visible = false
	_target_ai_state = TARGET_AI_STATE_SEARCHING
	if occlusion_blocked_view:
		_line_of_sight_loss_count += 1
		_remember_occlusion_position(line_of_sight_hit)

	if _line_of_sight_loss_count >= maxi(occlusion_break_forget_count, 1):
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
	_clear_navigation_path()


func _remember_occlusion_position(line_of_sight_hit: Dictionary) -> void:
	if not line_of_sight_hit.has("position"):
		return

	# 遮挡命中位置；取值为 PhysicsRayQueryParameters2D 的 position 字段，默认用于推导遮挡物背后的搜查锚点。
	var raw_position: Variant = line_of_sight_hit["position"]
	if raw_position is Vector2:
		_last_occlusion_position = raw_position
		_has_last_occlusion_position = true


func _try_attack_target() -> void:
	if _attack_cooldown_remaining > 0.0 or not is_instance_valid(_target):
		return

	if _target.has_method("apply_damage"):
		_target.call("apply_damage", attack_damage, self)

	_attack_cooldown_remaining = _get_resolved_attack_cooldown()


func _has_vision_line_of_sight_to_target() -> bool:
	if not vision_requires_line_of_sight:
		return is_instance_valid(_target)

	if not is_instance_valid(_target):
		return false

	return _get_vision_line_of_sight_hit().is_empty()


func _get_vision_line_of_sight_hit() -> Dictionary:
	if not vision_requires_line_of_sight or not is_instance_valid(_target):
		# 空命中结果；取值为空字典，默认表示没有可记录的环境遮挡点。
		var empty_hit_result: Dictionary = {}
		return empty_hit_result

	# 视线检测参数；取值为怪物到玩家之间的线段，默认只检测环境墙体和建筑。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, _target.global_position, vision_line_of_sight_collision_mask, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 视线命中结果；取值为空表示无遮挡，非空时包含遮挡物和命中位置，默认用于决定发现或启动搜查。
	return get_world_2d().direct_space_state.intersect_ray(query)


func _can_track_hidden_target(_target_distance: float) -> bool:
	# 当前三阶段索敌不允许隔墙读取玩家实时位置；该兼容函数固定返回 false，避免旧调用恢复无脑追踪。
	return false


func _track_hidden_target_position(_delta: float) -> void:
	# 当前三阶段索敌不再写入墙后玩家实时坐标；失去视野后必须通过 _begin_lost_target_search 进入搜查。
	return


func _remember_target_position(target_position: Vector2, delta: float = 0.0) -> void:
	if _has_last_known_target_position and delta > 0.001:
		# 目标瞬时速度；取值由本帧目标位置变化估算，用于失去视野后的短距离预测。
		var measured_velocity: Vector2 = (target_position - _last_known_target_position) / delta
		_estimated_target_velocity = measured_velocity

	_last_known_target_position = target_position
	_has_last_known_target_position = true
	_target_memory_remaining = maxf(target_memory_duration, 0.0)


func _forget_target() -> void:
	_has_target = false
	_target_is_visible = false
	_target_ai_state = TARGET_AI_STATE_IDLE
	_has_last_known_target_position = false
	_target_memory_remaining = 0.0
	_estimated_target_velocity = Vector2.ZERO
	_has_last_occlusion_position = false
	_line_of_sight_loss_count = 0
	_reset_target_search()
	_clear_navigation_path()


func _get_current_chase_destination() -> Vector2:
	if _target_is_visible and is_instance_valid(_target):
		return _target.global_position

	if _has_target_search_destination:
		return _target_search_destination

	if _has_last_known_target_position:
		return _get_predicted_target_position()

	return global_position


func _should_continue_lost_target_search() -> bool:
	if _has_target_search_destination:
		# 当前搜索点距离；取值为怪物到搜索点的距离，默认用于判断是否需要切换下一个搜索点。
		var search_point_distance: float = global_position.distance_to(_target_search_destination)
		if not _has_reached_lost_search_anchor:
			if search_point_distance > search_arrive_distance:
				return _target_memory_remaining > 0.0

			_has_reached_lost_search_anchor = true
			_target_search_anchor_position = _target_search_destination
			_target_search_remaining = maxf(target_search_duration_after_arrival, 0.0)
			if _target_search_remaining <= 0.0:
				return false

			_pick_next_target_search_destination()
			return true

		if search_point_distance <= search_arrive_distance:
			_pick_next_target_search_destination()

		return _target_search_remaining > 0.0

	if not _has_last_known_target_position:
		return false

	if _target_memory_remaining <= 0.0:
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
	if not _has_last_occlusion_position:
		return fallback_anchor

	# 遮挡物背后方向；取值为怪物指向遮挡命中点的方向，默认模拟敌人从自己视角绕到遮挡物背面。
	var occlusion_direction: Vector2 = _last_occlusion_position - global_position
	if occlusion_direction.is_zero_approx() and _has_last_known_target_position:
		occlusion_direction = _last_known_target_position - global_position
	if occlusion_direction.is_zero_approx():
		return fallback_anchor

	# 遮挡物背后锚点；取值为命中点沿遮挡方向推进，默认交给 A* 自动寻找入口或可走近邻格。
	var occlusion_anchor: Vector2 = _last_occlusion_position + occlusion_direction.normalized() * maxf(lost_search_occlusion_offset, 0.0)
	return occlusion_anchor


func _get_predicted_target_position() -> Vector2:
	if not _has_last_known_target_position:
		return global_position

	# 预测偏移；取值为估算速度乘预测时间，默认让怪物追向玩家移动趋势的前方。
	var prediction_offset: Vector2 = _estimated_target_velocity * maxf(target_prediction_time, 0.0)
	# 最大预测距离；取值至少为 0，默认限制推断点偏离最后目标位置的最大距离。
	var max_prediction_distance: float = maxf(target_prediction_max_distance, 0.0)
	if max_prediction_distance > 0.0 and prediction_offset.length() > max_prediction_distance:
		prediction_offset = prediction_offset.normalized() * max_prediction_distance

	return _last_known_target_position + prediction_offset


func _start_target_search(anchor_position: Vector2) -> void:
	_target_search_anchor_position = anchor_position
	_target_search_remaining = maxf(target_search_duration_after_arrival, 0.0)
	_has_reached_lost_search_anchor = true
	_pick_next_target_search_destination()


func _pick_next_target_search_destination() -> void:
	if _target_search_remaining <= 0.0:
		_has_target_search_destination = false
		return

	# 搜索半径；取值至少为 0，默认用于在推断点周围随机选择扫荡位置。
	var resolved_search_radius: float = maxf(target_search_radius, 0.0)
	if resolved_search_radius <= 0.0:
		_target_search_destination = _target_search_anchor_position
		_has_target_search_destination = true
		return

	# 兜底搜索点；取值为锚点，默认在多次随机点都不适合时至少保持在最后线索附近。
	var fallback_destination: Vector2 = _target_search_anchor_position
	# 搜索点尝试次数；取值至少为 1，默认优先挑选不会让怪物刚起步就贴墙的方向。
	var attempt_count: int = maxi(lost_search_destination_attempts, 1)
	for attempt_index in range(attempt_count):
		# 搜索角度；取值为 0 到 TAU 的随机弧度，默认让怪物在目标消失点附近不固定走同一方向。
		var search_angle: float = _random.randf_range(0.0, TAU)
		# 搜索距离；取值为搜索半径的 35% 到 100%，默认避免所有搜索点都挤在锚点中心。
		var search_distance: float = _random.randf_range(resolved_search_radius * 0.35, resolved_search_radius)
		# 候选搜索点；取值为锚点周边坐标，默认用于搜查遮挡物后方、入口和室内周边。
		var candidate_destination: Vector2 = _target_search_anchor_position + Vector2.RIGHT.rotated(search_angle) * search_distance
		if attempt_index == 0:
			fallback_destination = candidate_destination

		# 候选起步方向；取值为怪物到候选点的方向，默认用于过滤明显会立即撞墙的巡逻点。
		var candidate_direction: Vector2 = candidate_destination - global_position
		if candidate_direction.is_zero_approx() or not _is_direction_blocked(candidate_direction.normalized()):
			_target_search_destination = candidate_destination
			_has_target_search_destination = true
			return

	_target_search_destination = fallback_destination
	_has_target_search_destination = true


func _reset_target_search() -> void:
	_has_target_search_destination = false
	_target_search_remaining = 0.0
	_has_reached_lost_search_anchor = false


func _update_target_behavior(_delta: float, target_distance: float) -> void:
	if _target_is_visible and target_distance <= attack_range:
		velocity = Vector2.ZERO
		_try_attack_target()
		return

	# 当前追击目标点；取值为可见玩家位置或最后可见位置，默认用于失去视野后的搜索移动。
	var chase_destination: Vector2 = _get_current_chase_destination()
	# 追击方向；取值为绕障后的单位向量，默认用于设置本帧速度。
	var chase_direction: Vector2 = _get_steered_direction_to(chase_destination)
	velocity = chase_direction * _get_resolved_move_speed()


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
	velocity = wander_direction * _get_resolved_move_speed() * wander_speed_multiplier


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
	# 通往目标的中心线是否被环境阻断；取值为 true/false，默认用于提前决定是否需要全局寻路。
	var destination_path_blocked: bool = _is_path_to_destination_blocked(destination)
	if pathfinding_enabled and (destination_path_blocked or not _path_points.is_empty()):
		if not destination_path_blocked and not _is_direction_blocked(direct_direction):
			_clear_navigation_path()
			return direct_direction

		return _get_pathfinding_direction_to(destination)

	if not _is_direction_blocked(direct_direction):
		_clear_navigation_path()
		return direct_direction

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

	if _path_goal_position.distance_to(destination) >= maxf(path_destination_refresh_distance, 1.0):
		return true

	return _path_recalculate_remaining <= 0.0 and _is_path_to_destination_blocked(destination)


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
	if not _target_is_visible:
		return destination

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

	return Vector2.ZERO


func _is_direction_blocked(direction: Vector2) -> bool:
	if direction.is_zero_approx():
		return true

	# 检测位移；取值为候选方向乘检测距离，默认用于预测下一小段移动是否撞墙。
	var test_motion: Vector2 = direction.normalized() * maxf(avoidance_probe_distance, 1.0)
	return test_move(global_transform, test_motion)


func _is_path_to_destination_blocked(destination: Vector2) -> bool:
	# 目标偏移；取值为目标点减当前位置，默认用于跳过极短距离的全局寻路判断。
	var destination_offset: Vector2 = destination - global_position
	if destination_offset.length() <= maxf(avoidance_probe_distance, 1.0):
		return _is_direction_blocked(destination_offset.normalized())

	# 走廊中心线查询；取值为怪物中心到目标点的射线，默认只检测环境层墙体和建筑。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, destination, vision_line_of_sight_collision_mask, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 中心线命中结果；取值为空表示可直走到目标附近，非空表示应该提前启用 A* 绕行。
	var hit_result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit_result.is_empty()


func _move_with_external_velocity(delta: float) -> void:
	# 本帧基础速度；取值来自追击或游荡逻辑，默认在叠加击退前缓存。
	var desired_velocity: Vector2 = velocity
	# 移动前位置；取值为当前全局坐标，默认用于移动后判断怪物是否卡住。
	var previous_position: Vector2 = global_position
	velocity = desired_velocity + _knockback_velocity
	move_and_slide()
	# 本帧实际位移；取值为 move_and_slide 后的位置差，默认用于卡墙检测。
	var moved_distance: float = global_position.distance_to(previous_position)
	velocity = desired_velocity
	_update_stuck_state(desired_velocity, moved_distance, delta)
	_decay_knockback(delta)


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
	_clear_navigation_path()


func _decay_knockback(delta: float) -> void:
	if _knockback_velocity.is_zero_approx():
		return

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, maxf(knockback_decay, 1.0) * delta)


func _spawn_hit_effect() -> void:
	_spawn_combat_burst(_resolve_effect_parent(), global_position, hit_effect_color, 26.0, 0.16, 6)


func _spawn_death_effect() -> void:
	_spawn_combat_burst(_resolve_effect_parent(), global_position, death_effect_color, 54.0, 0.34, 16)


func _spawn_combat_burst(parent_node: Node, burst_position: Vector2, burst_color: Color, burst_radius: float, burst_duration: float, burst_particle_count: int) -> void:
	if parent_node == null:
		return

	# 特效实例；取值为预加载脚本创建的 Node2D，默认挂到当前场景独立播放。
	var effect: Node2D = COMBAT_BURST_EFFECT_SCRIPT.new() as Node2D
	if effect == null:
		return

	effect.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_node.add_child(effect)
	effect.global_position = burst_position
	if effect.has_method("configure"):
		effect.call("configure", burst_color, burst_radius, burst_duration, burst_particle_count)


func _resolve_effect_parent() -> Node:
	# 当前场景节点；取值通常为 GameWorld，默认让特效脱离怪物节点生命周期独立播放。
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		return current_scene

	return get_tree().root
