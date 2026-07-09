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


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	_spawn_position = global_position
	_random.randomize()
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	if not is_instance_valid(_target):
		_has_target = false
		_update_wander(delta)
		move_and_slide()
		return

	# 目标距离；取值为当前怪物到玩家的距离，默认每帧计算，修改会影响索敌、追击和攻击判定。
	var target_distance: float = global_position.distance_to(_target.global_position)
	_update_target_state(target_distance)
	if not _has_target:
		_update_wander(delta)
		move_and_slide()
		return

	if target_distance <= attack_range:
		velocity = Vector2.ZERO
		_try_attack_target()
	else:
		# 追击方向；取值为怪物指向目标的单位向量，默认用于设置本帧速度，修改会影响怪物移动方向。
		var chase_direction: Vector2 = (_target.global_position - global_position).normalized()
		velocity = chase_direction * move_speed

	move_and_slide()


func set_target(target_node: Node) -> void:
	_target = target_node as Node2D
	_has_target = false


func apply_damage(damage: float, _source: Node) -> void:
	if damage <= 0.0 or current_health <= 0.0:
		return

	current_health = clampf(current_health - damage, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()
		queue_free()


func _update_target_state(target_distance: float) -> void:
	if target_distance <= vision_range:
		_has_target = true
	elif _has_target and target_distance > vision_range * lose_target_range_multiplier:
		_has_target = false


func _try_attack_target() -> void:
	if _attack_cooldown_remaining > 0.0 or not is_instance_valid(_target):
		return

	if _target.has_method("apply_damage"):
		_target.call("apply_damage", attack_damage, self)

	_attack_cooldown_remaining = attack_cooldown


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

	# 游荡方向；取值为怪物指向随机游荡点的单位向量，默认用于无目标慢速移动。
	var wander_direction: Vector2 = (_wander_target_position - global_position).normalized()
	velocity = wander_direction * move_speed * wander_speed_multiplier


func _pick_wander_target() -> void:
	# 游荡角度；取值为 0 到 TAU 的随机弧度，默认用于围绕出生点生成目标。
	var wander_angle: float = _random.randf_range(0.0, TAU)
	# 游荡距离；取值为 0 到 wander_radius，默认用于让怪物在出生点附近随机巡游。
	var wander_distance: float = _random.randf_range(0.0, wander_radius)
	_wander_target_position = _spawn_position + Vector2.RIGHT.rotated(wander_angle) * wander_distance
	_has_wander_target = true


func _get_next_wander_wait() -> float:
	# 标准化最长等待时间；取值至少为最短等待时间，默认防止配置反转导致随机范围错误。
	var resolved_wait_max: float = maxf(wander_wait_max, wander_wait_min)
	return _random.randf_range(wander_wait_min, resolved_wait_max)
