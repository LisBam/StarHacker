extends BasicMonster
class_name RangedMonster

## 远程测试怪物复用基础怪物的生命、韧性、绕障和游荡逻辑。
## 发现玩家后会保持距离并发射敌方子弹；如果被墙体挡住视线，会先绕障接近。

## 敌方弹体场景；默认由远程怪物场景指定，必须实例化为 Node2D，修改会影响怪物发射对象。
@export var projectile_scene: PackedScene
## 射击距离；取值建议大于保持距离且不超过弹体射程，默认 500 像素，玩家进入该范围且无遮挡时怪物会开火。
@export_range(1.0, 4000.0, 1.0, "or_greater") var shoot_range: float = 500.0
## 保持距离；取值建议大于攻击距离，默认 260 像素，玩家过近时怪物会后退。
@export_range(1.0, 2000.0, 1.0, "or_greater") var keep_distance: float = 260.0
## 敌方弹体速度；取值建议大于 0，默认 620 像素每秒，修改会影响弹道速度。
@export_range(1.0, 3000.0, 1.0, "or_greater") var ranged_projectile_speed: float = 620.0
## 敌方弹体伤害；取值建议大于等于 0，默认 10，修改会影响玩家被命中后的生命损失。
@export_range(0.0, 9999.0, 1.0, "or_greater") var ranged_projectile_damage: float = 10.0
## 敌方弹体射程；取值建议大于 0，默认 520 像素，修改会影响弹体自动销毁距离。
@export_range(1.0, 12000.0, 1.0, "or_greater") var ranged_projectile_range: float = 520.0
## 敌方弹体冲击力；取值建议大于等于 0，默认 90，命中玩家时会造成短距离击退。
@export_range(0.0, 5000.0, 1.0, "or_greater") var ranged_projectile_impact_force: float = 90.0
## 射击冷却；取值应大于 0，默认 1.25 秒，修改会影响远程怪物连续开火频率。
@export_range(0.05, 10.0, 0.05) var shoot_cooldown: float = 1.25
## 枪口偏移；取值为相对怪物中心的局部坐标，默认向前 24 像素，修改会影响子弹出生点。
@export var muzzle_offset: Vector2 = Vector2(24.0, 0.0)
## 视线遮挡检测掩码；默认检测第 5 层环境，修改会影响怪物判断能否直接射击玩家。
@export_flags_2d_physics var line_of_sight_collision_mask: int = 16
## 弹体父节点路径；默认留空表示挂到当前场景，指定后会影响敌方子弹所在层级。
@export var projectile_parent_path: NodePath

## 远程射击冷却剩余时间；取值大于等于 0，默认 0 表示生成后可立即开火。
var _shoot_cooldown_remaining: float = 0.0


func _process(delta: float) -> void:
	_shoot_cooldown_remaining = maxf(_shoot_cooldown_remaining - delta, 0.0)


func _update_target_behavior(_delta: float, target_distance: float) -> void:
	if not is_instance_valid(_target):
		velocity = Vector2.ZERO
		return

	# 是否拥有直线射击视线；取值为 true/false，默认只被环境墙体阻挡。
	var has_line_of_sight: bool = _has_line_of_sight_to_target()
	if target_distance > shoot_range or not has_line_of_sight:
		# 当前追击目标点；取值为玩家当前位置或最后可见位置，默认用于失去视野后的搜索移动。
		var chase_destination: Vector2 = _get_current_chase_destination()
		# 追击方向；取值为绕障后的单位向量，默认用于接近射击范围或寻找视线。
		var chase_direction: Vector2 = _get_steered_direction_to(chase_destination)
		velocity = chase_direction * move_speed
		return

	# 目标方向；取值为怪物指向玩家的单位向量，默认用于发射和后退判断。
	var target_direction: Vector2 = (_target.global_position - global_position).normalized()
	if target_distance < keep_distance:
		# 后撤目标点；取值为远离玩家的临时点，默认让远程怪物保持安全距离。
		var retreat_destination: Vector2 = global_position - target_direction * keep_distance
		# 后撤方向；取值为绕障后的单位向量，默认用于避免后退卡墙。
		var retreat_direction: Vector2 = _get_steered_direction_to(retreat_destination)
		velocity = retreat_direction * move_speed
	else:
		velocity = Vector2.ZERO

	_try_fire_projectile(target_direction)


func _try_fire_projectile(direction: Vector2) -> void:
	if projectile_scene == null or _shoot_cooldown_remaining > 0.0 or direction.is_zero_approx():
		return

	# 敌方弹体实例；取值为 Node2D 或 null，默认由 projectile_scene 实例化。
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	# 子弹出生位置；取值为怪物前方偏移后的全局坐标，默认避免从怪物中心发射。
	var spawn_position: Vector2 = global_position + muzzle_offset.rotated(direction.angle())
	projectile.global_position = spawn_position
	projectile.global_rotation = direction.angle()

	# 弹体父节点；取值为配置节点或当前场景，默认用于组织远程怪物弹体。
	var projectile_parent: Node = _resolve_projectile_parent()
	projectile_parent.add_child(projectile)
	projectile.global_position = spawn_position
	projectile.global_rotation = direction.angle()

	if projectile.has_method("configure_projectile"):
		projectile.call("configure_projectile", ranged_projectile_damage, ranged_projectile_impact_force, ranged_projectile_range)
	if projectile.has_method("launch"):
		projectile.call("launch", direction, ranged_projectile_speed)

	_shoot_cooldown_remaining = shoot_cooldown


func _has_line_of_sight_to_target() -> bool:
	if not is_instance_valid(_target):
		return false

	# 射线查询参数；取值为怪物到玩家之间的线段，默认只检测环境墙体和建筑。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, _target.global_position, line_of_sight_collision_mask, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 射线命中结果；取值为空表示无遮挡，默认用于判断是否可以直接射击。
	var hit_result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return hit_result.is_empty()


func _resolve_projectile_parent() -> Node:
	if not projectile_parent_path.is_empty():
		# 检查器配置的弹体父节点；取值为 Node 或 null，默认由 projectile_parent_path 查找。
		var configured_parent: Node = get_node_or_null(projectile_parent_path)
		if configured_parent != null:
			return configured_parent

	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root
