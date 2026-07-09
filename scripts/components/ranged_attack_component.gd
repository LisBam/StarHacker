extends Node2D
class_name RangedAttackComponent

## 远程攻击组件负责把“攻击请求”转换成独立弹体。
## 弹体场景、冷却时间、速度和枪口节点都暴露在检查器中，方便不同武器复用同一组件。

signal fired(projectile: Node2D)

## 弹体场景资源；默认由角色预制体指定，必须实例化为 Node2D，运行时修改会影响后续射击生成的弹体类型。
@export var projectile_scene: PackedScene
## 枪口节点路径；默认指向玩家 AimPivot/Muzzle，必须解析到 Node2D，修改会影响弹体出生位置。
@export var muzzle_path: NodePath = ^"../AimPivot/Muzzle"
## 弹体发射速度；取值建议大于 0，默认 900 适合快速射击原型，运行时修改会影响新弹体飞行速度。
@export_range(1.0, 2400.0, 1.0, "or_greater") var projectile_speed: float = 900.0
## 默认弹体伤害；取值建议大于等于 0，默认 12 用于未传入武器数据时的兜底伤害，运行时修改会影响无装备模式下的射击伤害。
@export_range(0.0, 9999.0, 1.0, "or_greater") var projectile_damage: float = 12.0
## 射击冷却时间；取值应大于 0，默认 0.16 秒形成连续点射手感，运行时修改会影响射击频率。
@export_range(0.01, 5.0, 0.01) var fire_cooldown: float = 0.16
## 枪口缺失时的备用出生距离；取值应大于等于 0，默认 34 让弹体从角色前方出现，修改会影响兜底发射位置。
@export_range(0.0, 160.0, 1.0) var fallback_muzzle_distance: float = 34.0
## 弹体父节点路径；默认留空表示挂到当前场景，运行时通常不修改，指定后会影响弹体所在层级和坐标继承。
@export var projectile_parent_path: NodePath

## 剩余射击冷却；取值大于等于 0，默认 0 表示可立即射击，修改会影响组件是否接受下一次射击请求。
var _cooldown_remaining: float = 0.0
## 当前射击冷却总时长；取值大于等于 0，默认 0 表示无冷却基准，修改会影响 HUD 冷却覆盖比例。
var _cooldown_duration: float = 0.0

## 枪口节点缓存；默认按 muzzle_path 解析，允许为空并走备用距离，修改会影响弹体出生位置来源。
@onready var _muzzle: Node2D = get_node_or_null(muzzle_path) as Node2D


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


func try_attack(direction: Vector2, weapon_data: Resource = null) -> bool:
	# 本次使用的弹体场景；取值来自武器数据或组件默认值，默认 projectile_scene，修改会影响实际生成的弹体类型。
	var selected_projectile_scene: PackedScene = _get_weapon_packed_scene(weapon_data, "projectile_scene", projectile_scene)
	# 本次使用的弹体速度；取值来自武器数据或组件默认值，默认 projectile_speed，修改会影响本次弹体飞行速度。
	var selected_projectile_speed: float = _get_weapon_float(weapon_data, "projectile_speed", projectile_speed)
	# 本次使用的弹体射程；取值来自武器数据或弹体默认值，默认 960，修改会影响本次弹体飞行距离。
	var selected_bullet_range: float = _get_weapon_float(weapon_data, "bullet_range", 960.0)
	# 本次使用的弹体伤害；取值来自武器数据或组件默认值，默认 projectile_damage，修改会影响本次弹体命中伤害。
	var selected_projectile_damage: float = _get_weapon_float(weapon_data, "ranged_damage", projectile_damage)
	# 本次使用的射击冷却；取值来自武器数据或组件默认值，默认 fire_cooldown，修改会影响下一次可射击时间。
	var selected_fire_cooldown: float = _get_weapon_float(weapon_data, "ranged_cooldown", fire_cooldown)
	# 本次使用的弹体冲击力；取值来自武器数据，默认 0 表示只造成伤害不击退。
	var selected_impact_force: float = _get_weapon_float(weapon_data, "impact_force", 0.0)

	if selected_projectile_scene == null or _cooldown_remaining > 0.0 or direction.is_zero_approx():
		return false

	# 本次射击生成的弹体实例；取值应为 Node2D 或 null，默认由 projectile_scene 实例化，修改会影响发射对象。
	var projectile: Node2D = selected_projectile_scene.instantiate() as Node2D
	if projectile == null:
		return false

	if projectile.has_method("set_damage"):
		projectile.call("set_damage", selected_projectile_damage)
	if projectile.has_method("set_max_distance"):
		projectile.call("set_max_distance", selected_bullet_range)
	if projectile.has_method("set_impact_force"):
		projectile.call("set_impact_force", selected_impact_force)

	# 本次弹体出生位置；取值为全局坐标 Vector2，默认由枪口或备用距离计算，修改会影响弹体出现地点。
	var spawn_position: Vector2 = _get_spawn_position(direction)
	projectile.global_position = spawn_position
	projectile.global_rotation = direction.angle()

	# 本次弹体挂载父节点；取值为有效 Node，默认当前场景或根节点，修改会影响弹体坐标系和生命周期组织。
	var projectile_parent: Node = _resolve_projectile_parent()
	projectile_parent.add_child(projectile)

	# 加入场景树后再次写入全局坐标，确保父节点带变换时弹体仍从枪口出现。
	projectile.global_position = spawn_position
	projectile.global_rotation = direction.angle()

	if projectile.has_method("launch"):
		projectile.call("launch", direction, selected_projectile_speed)

	_cooldown_remaining = selected_fire_cooldown
	_cooldown_duration = selected_fire_cooldown
	fired.emit(projectile)
	return true


func _get_spawn_position(direction: Vector2) -> Vector2:
	if is_instance_valid(_muzzle):
		return _muzzle.global_position

	return global_position + direction.normalized() * fallback_muzzle_distance


func _resolve_projectile_parent() -> Node:
	if not projectile_parent_path.is_empty():
		# 检查器配置的弹体父节点；取值为 Node 或 null，默认由 projectile_parent_path 查找，修改会影响父节点解析结果。
		var configured_parent: Node = get_node_or_null(projectile_parent_path)
		if configured_parent != null:
			return configured_parent

	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func get_cooldown_duration() -> float:
	return _cooldown_duration


func get_cooldown_ratio() -> float:
	if _cooldown_duration <= 0.0:
		return 0.0

	return clampf(_cooldown_remaining / _cooldown_duration, 0.0, 1.0)


func _get_weapon_float(weapon_data: Resource, property_name: StringName, fallback_value: float) -> float:
	if weapon_data == null:
		return fallback_value

	# 武器资源字段值；取值可能为数字或 null，默认通过 Resource.get 读取，修改会影响参数覆盖结果。
	var property_value: Variant = weapon_data.get(property_name)
	if property_value == null:
		return fallback_value

	return float(property_value)


func _get_weapon_packed_scene(weapon_data: Resource, property_name: StringName, fallback_scene: PackedScene) -> PackedScene:
	if weapon_data == null:
		return fallback_scene

	# 武器资源场景字段值；取值可能为 PackedScene 或 null，默认通过 Resource.get 读取，修改会影响弹体场景覆盖结果。
	var property_value: Variant = weapon_data.get(property_name)
	if property_value is PackedScene:
		return property_value as PackedScene

	return fallback_scene
