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
## 弹体最大飞行距离；取值应大于 0，默认 340 像素，运行时由武器攻击距离覆盖并影响自动销毁位置。
@export_range(1.0, 4000.0, 1.0, "or_greater") var max_distance: float = 340.0
## 弹体命中伤害；取值建议大于等于 0，默认 12 作为基础远程伤害，运行时修改会影响命中回调伤害值。
@export_range(0.0, 9999.0, 1.0, "or_greater") var damage: float = 12.0
## 命中后是否销毁；取值为 true/false，默认 true 避免穿透，运行时修改会影响弹体能否连续命中。
@export var destroy_on_hit: bool = true
## 可额外穿过的目标数量；默认 0 表示首个目标后销毁，正数仅对可受伤目标生效，墙体始终阻挡弹体。
@export_range(0, 100, 1, "or_greater") var piercing_count: int = 0
## 可剩余弹射次数；默认 0 表示不弹射，正数时墙体命中或穿透目标命中后会消耗一次并改变弹道。
@export_range(0, 100, 1, "or_greater") var bounce_count: int = 0
## 弹射相对反射方向的最大随机偏转角；默认 55 度，实际值会限制在 89 度内以保证墙体反射后仍朝离墙方向飞行。
@export_range(0.0, 89.0, 1.0) var bounce_random_angle_degrees: float = 55.0
## 弹射后沿碰撞法线推出的距离；默认 1 像素，避免弹体停在墙体接触面上而下一物理帧立即再次碰墙。
@export_range(0.01, 16.0, 0.01) var bounce_surface_separation: float = 1.0
## 弹体冲击力；单位为目标单次无碰撞理论位移像素，1 点对应 1 像素，默认 0 表示只造成伤害不击退，武器会在发射时覆盖该值。
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
## 已命中目标实例编号集合；默认空，防止穿透弹体在重叠碰撞帧中重复伤害同一目标。
var _hit_target_ids: Dictionary = {}
## 已命中碰撞体 RID；默认只在发生穿透后追加，扫掠射线会排除它们以继续检测后方目标。
## 当前实现把弹体自身 RID 固定放在首项，后续仍只追加实际穿透目标；同一数组可直接供每帧扫掠射线复用。
var _excluded_collision_rids: Array[RID] = []
## 最大飞行距离平方；默认由 max_distance 在 ready 与设置入口同步，用于高频回收判断避免逐帧开方。
var _max_distance_squared: float = 0.0
## 弹体伤害的实际发起单位；默认 null，由远程攻击组件在生成时注入玩家，供敌人受伤改索敌使用。
var _damage_instigator: Node
## 弹射随机源；每颗弹体独立随机化，用于在合法反射半平面内生成不同弹道。
var _bounce_random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_start_position = global_position
	_max_distance_squared = maxf(max_distance, 1.0) * maxf(max_distance, 1.0)
	_excluded_collision_rids = [get_rid()]
	_bounce_random.randomize()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	# 本帧目标位置；取值为当前位置加速度位移，默认用于射线检测和最终位移。
	var target_position: Vector2 = global_position + _velocity * delta
	if _handle_swept_collision(target_position):
		return

	global_position = target_position
	_age += delta

	if _age >= lifetime or global_position.distance_squared_to(_start_position) >= _max_distance_squared:
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
	_max_distance_squared = max_distance * max_distance


func set_impact_force(value: float) -> void:
	impact_force = maxf(value, 0.0)


func set_piercing_count(value: int) -> void:
	piercing_count = maxi(value, 0)
	destroy_on_hit = piercing_count <= 0


func set_bounce_count(value: int) -> void:
	## 设置当前弹体剩余弹射次数；由远程攻击组件在发射时传入有效武器属性，负值安全归零。
	bounce_count = maxi(value, 0)


func configure_combat_attributes(new_attack_power: float, new_critical_chance: float, new_critical_damage: float) -> void:
	_attack_power = maxf(new_attack_power, 0.0)
	_critical_chance = clampf(new_critical_chance, 0.0, 1.0)
	_critical_damage = maxf(new_critical_damage, 1.0)


func set_damage_instigator(instigator: Node) -> void:
	## 注入弹体所属战斗单位；引用只在弹体生命周期内使用，不改变碰撞层或伤害数值。
	_damage_instigator = instigator


func get_damage_instigator() -> Node:
	## 返回实际发射者；敌人不会把独立弹体节点误当作长期追击目标。
	return _damage_instigator


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
	if _apply_hit(body, _get_fallback_collision_normal(body)):
		hit_body.emit(body, damage)


func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return

	if _apply_hit(area, _get_fallback_collision_normal(area)):
		hit_area.emit(area, damage)


func _handle_swept_collision(target_position: Vector2) -> bool:
	# 射线查询参数；取值为当前位置到目标位置，默认使用弹体碰撞掩码检测怪物和环境。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target_position, collision_mask, _excluded_collision_rids)
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
	# 命中法线；射线查询直接提供墙体或碰撞体朝向，弹射时必须使用它确保新方向不再指向墙内。
	var collision_normal: Vector2 = hit_result.get("normal", Vector2.ZERO) as Vector2
	# 命中对象；取值为 Node 或 null，默认用于沿用普通 body/area 命中流程。
	var collider: Node = hit_result.get("collider", null) as Node
	if collider == null:
		queue_free()
		return true

	if collider is Area2D:
		if _apply_hit(collider, collision_normal):
			hit_area.emit(collider as Area2D, damage)
	else:
		if _apply_hit(collider, collision_normal):
			hit_body.emit(collider, damage)
	# 扫掠命中后本帧已在接触点完成结算；即使弹射成功也必须停止本帧位移，避免跨过墙体或目标。
	return true


func _apply_hit(target: Node, collision_normal: Vector2 = Vector2.ZERO) -> bool:
	if target == null or _hit_target_ids.has(target.get_instance_id()):
		return false
	# 不可受伤碰撞体视为墙体或环境障碍；穿透只作用于目标，环境始终立即销毁弹体。
	if not target.has_method("apply_damage"):
		_try_bounce(collision_normal)
		return false
	_hit_target_ids[target.get_instance_id()] = true
	target.call("apply_damage", damage, self)
	if piercing_count <= 0 or destroy_on_hit:
		queue_free()
		return true
	piercing_count -= 1
	if target is CollisionObject2D:
		# 已穿透目标 RID；写入实例内高频查询缓存，后续扫线不会再次命中同一碰撞体。
		var target_rid: RID = (target as CollisionObject2D).get_rid()
		_excluded_collision_rids.append(target_rid)
	# 弹射是独立于穿透的可选能力；没有剩余弹射次数时必须保持原方向继续飞行，不能因为尝试弹射而销毁穿透弹体。
	if bounce_count > 0:
		_try_bounce(collision_normal if not collision_normal.is_zero_approx() else _get_fallback_collision_normal(target))
	return true


func _try_bounce(collision_normal: Vector2) -> bool:
	## 尝试消耗一次弹射并重定向弹体；法线为空时无法证明新弹道远离墙面，因此直接销毁避免卡在障碍内。
	if bounce_count <= 0:
		queue_free()
		return false
	# 规范碰撞法线；墙体射线法线或目标中心到弹体的方向都可作为安全外侧半平面。
	var resolved_normal: Vector2 = collision_normal.normalized()
	if resolved_normal.is_zero_approx():
		queue_free()
		return false
	# 理想反射方向；速度异常时使用法线作为直接离开墙体的安全方向。
	var reflected_direction: Vector2 = _velocity.bounce(resolved_normal).normalized() if not _velocity.is_zero_approx() else resolved_normal
	if reflected_direction.is_zero_approx() or reflected_direction.dot(resolved_normal) <= 0.0:
		reflected_direction = resolved_normal
	# 随机角度；先围绕理想反射方向偏转，再检查是否仍朝外，必要时退回法线保证不会再次冲进墙体。
	var random_angle: float = deg_to_rad(_bounce_random.randf_range(-bounce_random_angle_degrees, bounce_random_angle_degrees))
	var bounced_direction: Vector2 = reflected_direction.rotated(random_angle).normalized()
	if bounced_direction.is_zero_approx() or bounced_direction.dot(resolved_normal) <= 0.001:
		bounced_direction = resolved_normal
	bounce_count -= 1
	_velocity = bounced_direction * maxf(_velocity.length(), speed)
	rotation = bounced_direction.angle()
	global_position += resolved_normal * maxf(bounce_surface_separation, 0.01)
	return true


func _get_fallback_collision_normal(target: Node) -> Vector2:
	## 为普通碰撞信号补足法线；优先使用碰撞对象中心到弹体的外向方向，无法取得位置时使用当前反向速度。
	if target is Node2D:
		var target_position: Vector2 = (target as Node2D).global_position
		var outward_direction: Vector2 = global_position - target_position
		if not outward_direction.is_zero_approx():
			return outward_direction.normalized()
	return -_velocity.normalized() if not _velocity.is_zero_approx() else Vector2.ZERO
