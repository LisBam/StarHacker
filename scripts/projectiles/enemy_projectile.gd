extends Area2D
class_name EnemyProjectile

## 敌方弹体由远程怪物生成，负责按方向飞行、命中玩家、撞墙销毁和被玩家近战消除。
## 弹体通过 apply_damage(damage, source) 与玩家交互，source 为弹体自身，便于玩家读取冲击力和击退方向。

signal hit_body(body: Node, damage: float)

## 弹体速度；取值建议大于 0，默认 620 像素每秒，运行时修改会影响远程怪物弹道速度。
@export_range(1.0, 3000.0, 1.0, "or_greater") var speed: float = 620.0
## 弹体最大存活时间；取值应大于 0，默认 3 秒，运行时修改会影响敌方子弹最远飞行时间。
@export_range(0.01, 20.0, 0.01) var lifetime: float = 3.0
## 弹体最大飞行距离；取值应大于 0，默认 520 像素，运行时修改会影响远程怪物弹体回收位置。
@export_range(1.0, 12000.0, 1.0, "or_greater") var max_distance: float = 520.0
## 弹体伤害；取值建议大于等于 0，默认 10，运行时修改会影响命中玩家后的生命损失。
@export_range(0.0, 9999.0, 1.0, "or_greater") var damage: float = 10.0
## 弹体冲击力；单位为玩家单次无碰撞理论位移像素，1 点对应 1 像素，默认 90 表示命中玩家时产生 90 像素理论位移。
@export_range(0.0, 5000.0, 1.0, "or_greater") var impact_force: float = 90.0

## 当前弹体速度向量；取值为方向乘速度，默认向右用于未 launch 时的兜底移动。
var _velocity: Vector2 = Vector2.RIGHT
## 当前存活时间；取值大于等于 0，默认 0 表示刚生成。
var _age: float = 0.0
## 弹体出生位置；取值为全局坐标，默认 ready 时记录，用于最大距离销毁。
var _start_position: Vector2
## 是否已经完成命中或销毁流程；默认 false，命中后置为 true，避免扫线检测和 body_entered 在同一帧重复结算伤害与击退。
var _has_hit: bool = false
## 弹体携带的敌方攻击力；默认 100，命中玩家时参与统一攻防公式。
var _attack_power: float = 100.0


func _ready() -> void:
	_start_position = global_position
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	# 本帧目标位置；取值为当前位置加速度位移，默认用于射线检测和最终位移。
	var target_position: Vector2 = global_position + _velocity * delta
	if _handle_swept_collision(target_position):
		return

	global_position = target_position
	_age += delta

	if _age >= lifetime or global_position.distance_to(_start_position) >= max_distance:
		queue_free()


func launch(direction: Vector2, speed_override: float = -1.0) -> void:
	if direction.is_zero_approx():
		return

	# 本次发射速度；取值优先使用正数覆盖值，否则使用 speed，默认由远程怪物传入。
	var resolved_speed: float = speed_override if speed_override > 0.0 else speed
	_velocity = direction.normalized() * resolved_speed
	rotation = direction.angle()


func configure_projectile(new_damage: float, new_impact_force: float, new_max_distance: float) -> void:
	damage = maxf(new_damage, 0.0)
	impact_force = maxf(new_impact_force, 0.0)
	max_distance = maxf(new_max_distance, 1.0)


func set_attack_power(value: float) -> void:
	_attack_power = maxf(value, 0.0)


func get_attack_power() -> float:
	return _attack_power


func get_critical_chance() -> float:
	return 0.0


func get_critical_damage_multiplier() -> float:
	return 1.5


func destroy_by_melee(_source: Node) -> void:
	if _has_hit:
		return

	_has_hit = true
	queue_free()


func get_impact_force() -> float:
	return impact_force


func get_knockback_direction() -> Vector2:
	if _velocity.is_zero_approx():
		return Vector2.RIGHT.rotated(rotation)

	return _velocity.normalized()


func _on_body_entered(body: Node) -> void:
	if _has_hit:
		return

	if _apply_hit(body):
		hit_body.emit(body, damage)


func _handle_swept_collision(target_position: Vector2) -> bool:
	if _has_hit:
		return true

	# 射线查询参数；取值为当前位置到目标位置，默认使用弹体碰撞掩码检测玩家和环境。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target_position, collision_mask, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 射线命中结果；取值为空字典或包含 collider/position，默认用于提前处理高速碰撞。
	var hit_result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit_result.is_empty():
		return false

	# 命中位置；取值为射线碰撞点，默认让弹体销毁前停在碰撞处。
	var hit_position: Vector2 = target_position
	if hit_result.get("position") is Vector2:
		hit_position = hit_result.get("position")
	global_position = hit_position
	# 命中对象；取值为 Node 或 null，默认用于沿用普通 body 命中流程。
	var collider: Node = hit_result.get("collider", null) as Node
	if collider == null:
		_has_hit = true
		queue_free()
		return true

	if _apply_hit(collider):
		hit_body.emit(collider, damage)

	return true


func _apply_hit(target: Node) -> bool:
	if _has_hit:
		return false

	_has_hit = true
	if target.has_method("apply_damage"):
		target.call("apply_damage", damage, self)

	queue_free()
	return true
