extends Area2D
class_name PlayerProjectile

## 玩家弹体是一个独立 Area2D，生成后按 launch 传入的方向飞行。
## 它通过最大寿命和最大距离自动回收，避免长时间射击后场景中残留大量不可见节点。
## 被命中的对象如果实现 apply_damage(damage: float, source: Node)，弹体会自动调用该接口。

signal hit_body(body: Node, damage: float)
signal hit_area(area: Area2D, damage: float)

## 弹体默认速度；取值建议大于 0，默认 900 与远程攻击组件一致，运行时修改会影响未覆盖速度的弹体飞行。
@export_range(1.0, 2400.0, 1.0, "or_greater") var speed: float = 900.0
## 弹体最大存活时间；取值应大于 0，默认 1.2 秒避免远距离残留，运行时修改会影响自动销毁时间。
@export_range(0.01, 20.0, 0.01) var lifetime: float = 1.2
## 弹体最大飞行距离；取值应大于 0，默认 340 像素限制射程，运行时修改会影响自动销毁距离。
@export_range(1.0, 4000.0, 1.0, "or_greater") var max_distance: float = 340.0
## 弹体命中伤害；取值建议大于等于 0，默认 12 作为基础远程伤害，运行时修改会影响命中回调伤害值。
@export_range(0.0, 9999.0, 1.0, "or_greater") var damage: float = 12.0
## 命中后是否销毁；取值为 true/false，默认 true 避免穿透，运行时修改会影响弹体能否连续命中。
@export var destroy_on_hit: bool = true
## 弹体冲击力；取值建议大于等于 0，默认 0 表示只造成伤害不击退，武器会在发射时覆盖该值。
@export_range(0.0, 5000.0, 1.0, "or_greater") var impact_force: float = 0.0

## 当前弹体速度向量；取值为方向乘速度，默认向右用于未 launch 时的兜底移动，修改会影响后续飞行方向和速度。
var _velocity: Vector2 = Vector2.RIGHT
## 当前弹体存活时间；取值大于等于 0，默认 0 表示刚生成，修改会影响 lifetime 自动销毁判定。
var _age: float = 0.0
## 弹体出生位置；取值为全局坐标 Vector2，默认在 ready 时记录当前位置，修改会影响 max_distance 销毁判定。
var _start_position: Vector2
## 弹体携带的攻击力；默认 100，命中时参与统一攻防公式。
var _attack_power: float = 100.0
## 弹体携带的暴击率；默认 0，每颗弹体命中时独立判定。
var _critical_chance: float = 0.0
## 弹体携带的暴击伤害倍率；默认 1.5 表示 150%。
var _critical_damage: float = 1.5


func _ready() -> void:
	_start_position = global_position
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
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

	# 本次发射速度；取值优先使用正数覆盖值，否则使用 speed，默认由组件传入，修改会影响当前弹体飞行速度。
	var resolved_speed: float = speed_override if speed_override > 0.0 else speed
	_velocity = direction.normalized() * resolved_speed
	rotation = direction.angle()


func set_damage(value: float) -> void:
	damage = maxf(value, 0.0)


func set_max_distance(value: float) -> void:
	max_distance = maxf(value, 1.0)


func set_impact_force(value: float) -> void:
	impact_force = maxf(value, 0.0)


func configure_combat_attributes(new_attack_power: float, new_critical_chance: float, new_critical_damage: float) -> void:
	_attack_power = maxf(new_attack_power, 0.0)
	_critical_chance = clampf(new_critical_chance, 0.0, 1.0)
	_critical_damage = maxf(new_critical_damage, 1.0)


func get_attack_power() -> float:
	return _attack_power


func get_critical_chance() -> float:
	return _critical_chance


func get_critical_damage_multiplier() -> float:
	return _critical_damage


func get_impact_force() -> float:
	return impact_force


func get_knockback_direction() -> Vector2:
	if _velocity.is_zero_approx():
		return Vector2.RIGHT.rotated(rotation)

	return _velocity.normalized()


func _on_body_entered(body: Node) -> void:
	if _apply_hit(body):
		hit_body.emit(body, damage)


func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return

	if _apply_hit(area):
		hit_area.emit(area, damage)


func _handle_swept_collision(target_position: Vector2) -> bool:
	# 射线查询参数；取值为当前位置到目标位置，默认使用弹体碰撞掩码检测怪物和环境。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target_position, collision_mask, [get_rid()])
	query.collide_with_areas = true
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
	# 命中对象；取值为 Node 或 null，默认用于沿用普通 body/area 命中流程。
	var collider: Node = hit_result.get("collider", null) as Node
	if collider == null:
		queue_free()
		return true

	if collider is Area2D:
		if _apply_hit(collider):
			hit_area.emit(collider as Area2D, damage)
	else:
		if _apply_hit(collider):
			hit_body.emit(collider, damage)

	return true


func _apply_hit(target: Node) -> bool:
	if target.has_method("apply_damage"):
		target.call("apply_damage", damage, self)

	if destroy_on_hit:
		queue_free()

	return true
