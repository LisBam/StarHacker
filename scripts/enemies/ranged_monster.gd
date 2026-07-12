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
## 敌方弹体偏移角度；取值大于等于 0，默认 4 度，每次射击会在瞄准方向两侧随机变化。
@export_range(0.0, 45.0, 0.1, "or_greater") var ranged_projectile_deviation_degrees: float = 4.0
## 冷却；取值应大于 0，默认 1.25 秒，修改会影响远程怪物连续开火频率。
@export_range(0.05, 10.0, 0.05) var cooldown: float = 1.25
## 个体冷却最小倍率；取值建议 0.8 到 1，默认 0.85，让远程怪物攻击间隔存在下限差异。
@export_range(0.1, 3.0, 0.01) var cooldown_random_multiplier_min: float = 0.85
## 个体冷却最大倍率；取值建议大于等于最小倍率，默认 1.35，让远程怪物攻击间隔存在上限差异。
@export_range(0.1, 3.0, 0.01) var cooldown_random_multiplier_max: float = 1.35
## 枪口偏移；取值为相对怪物中心的局部坐标，默认向前 24 像素，修改会影响子弹出生点。
@export var muzzle_offset: Vector2 = Vector2(24.0, 0.0)
## 视线遮挡检测掩码；默认检测第 5 层环境，修改会影响怪物判断能否直接射击玩家。
@export_flags_2d_physics var line_of_sight_collision_mask: int = 16
## 弹体父节点路径；默认留空表示挂到当前场景，指定后会影响敌方子弹所在层级。
@export var projectile_parent_path: NodePath

## 远程攻击冷却剩余时间；取值大于等于 0，默认 0 表示生成后可立即开火。
var _cooldown_remaining: float = 0.0
## 个体冷却倍率；取值由出生时随机生成，默认 1 表示不改变检查器中的基础冷却。
var _cooldown_multiplier: float = 1.0


func apply_spawn_variation(size_multiplier: float, attribute_multiplier: float) -> void:
	super.apply_spawn_variation(size_multiplier, attribute_multiplier)
	# 标准化属性倍率；取值至少 0.1，用于远程专属伤害、射程和冷却波动。
	var resolved_attribute_multiplier: float = maxf(attribute_multiplier, 0.1)
	# 标准化尺寸倍率；取值至少 0.1，用于保持距离随体型变化。
	var resolved_size_multiplier: float = maxf(size_multiplier, 0.1)
	shoot_range *= resolved_attribute_multiplier
	keep_distance *= resolved_size_multiplier
	ranged_projectile_damage *= resolved_attribute_multiplier
	ranged_projectile_impact_force *= resolved_attribute_multiplier
	cooldown /= resolved_attribute_multiplier


func _ready() -> void:
	super._ready()
	_randomize_individual_shooting()


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


func _randomize_individual_shooting() -> void:
	_cooldown_multiplier = _get_randomized_multiplier(cooldown_random_multiplier_min, cooldown_random_multiplier_max)
	_cooldown_remaining = _random.randf_range(0.0, _get_resolved_cooldown())


func _get_resolved_cooldown() -> float:
	return maxf(cooldown, 0.05) * maxf(_cooldown_multiplier, 0.1)


func _update_target_behavior(_delta: float, target_distance: float) -> void:
	if not is_instance_valid(_target):
		velocity = Vector2.ZERO
		return
	if _should_pause_target_movement():
		velocity = Vector2.ZERO
		return

	# 是否拥有直线射击视线；取值为 true/false，默认只被环境墙体阻挡。
	var has_line_of_sight: bool = _has_line_of_sight_to_target()
	if not _target_is_visible or target_distance > shoot_range or not has_line_of_sight:
		# 当前追击目标点；取值为玩家可见位置或最后线索搜查点，默认用于失去视野后的搜索移动。
		var chase_destination: Vector2 = _get_current_chase_destination()
		# 追击方向；取值为绕障后的单位向量，默认用于接近射击范围或寻找视线。
		var chase_direction: Vector2 = _get_steered_direction_to(chase_destination)
		# 当前状态速度倍率；取值为 1 或搜查倍率，默认让远程怪物同样以谨慎速度排查最后线索。
		## 战术补充：远程怪物所有主动追击和搜查统一使用固定个体移速，安全感通过站位距离与静止卡点实现。
		var state_speed_multiplier: float = 1.0
		velocity = chase_direction * _get_resolved_move_speed() * state_speed_multiplier
		return

	# 目标方向；取值为怪物指向玩家的单位向量，默认用于发射和后退判断。
	var target_direction: Vector2 = (_target.global_position - global_position).normalized()
	if target_distance < keep_distance:
		# 后撤目标点；取值为远离玩家的临时点，默认让远程怪物保持安全距离。
		var retreat_destination: Vector2 = global_position - target_direction * keep_distance
		# 后撤方向；取值为绕障后的单位向量，默认用于避免后退卡墙。
		var retreat_direction: Vector2 = _get_steered_direction_to(retreat_destination)
		velocity = retreat_direction * _get_resolved_move_speed()
	else:
		velocity = Vector2.ZERO

	_try_fire_projectile(target_direction)


func _try_fire_projectile(direction: Vector2) -> void:
	if projectile_scene == null or _cooldown_remaining > 0.0 or direction.is_zero_approx():
		return
	if not is_instance_valid(_target) or not _target_is_visible:
		return
	# 发射瞬间目标距离；再次读取实时位置，防止低频 AI 决策后玩家已经离开 shoot_range 仍然放空枪。
	var current_target_distance: float = global_position.distance_to(_target.global_position)
	if current_target_distance > maxf(shoot_range, 0.0):
		return
	if not _has_line_of_sight_to_target():
		return
	# 实际发射方向；使用敌人独立随机源在配置偏移角度内变化，避免所有远程敌人保持绝对精准。
	var resolved_direction: Vector2 = direction.normalized().rotated(deg_to_rad(_random.randf_range(-maxf(ranged_projectile_deviation_degrees, 0.0), maxf(ranged_projectile_deviation_degrees, 0.0))))

	# 敌方弹体实例；取值为 Node2D 或 null，默认由 projectile_scene 实例化。
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	# 子弹出生位置；取值为怪物前方偏移后的全局坐标，默认避免从怪物中心发射。
	var spawn_position: Vector2 = global_position + muzzle_offset.rotated(resolved_direction.angle())
	projectile.global_position = spawn_position
	projectile.global_rotation = resolved_direction.angle()

	# 弹体父节点；取值为配置节点或当前场景，默认用于组织远程怪物弹体。
	var projectile_parent: Node = _resolve_projectile_parent()
	projectile_parent.add_child(projectile)
	projectile.global_position = spawn_position
	projectile.global_rotation = resolved_direction.angle()

	if projectile.has_method("configure_projectile"):
		projectile.call("configure_projectile", ranged_projectile_damage, ranged_projectile_impact_force, ranged_projectile_range)
	if projectile.has_method("set_attack_power"):
		projectile.call("set_attack_power", attack_power)
	if projectile.has_method("launch"):
		projectile.call("launch", resolved_direction, ranged_projectile_speed)

	_cooldown_remaining = _get_resolved_cooldown()


func _has_line_of_sight_to_target() -> bool:
	if not is_instance_valid(_target):
		return false

	return _has_vision_line_of_sight_to_target()


func is_ranged_tactical_unit() -> bool:
	return true


func get_tactical_attack_range() -> float:
	return maxf(shoot_range, 0.0)


func get_tactical_preferred_distance() -> float:
	return maxf(keep_distance, 1.0)


func _resolve_projectile_parent() -> Node:
	if not projectile_parent_path.is_empty():
		# 检查器配置的弹体父节点；取值为 Node 或 null，默认由 projectile_parent_path 查找。
		var configured_parent: Node = get_node_or_null(projectile_parent_path)
		if configured_parent != null:
			return configured_parent

	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root
