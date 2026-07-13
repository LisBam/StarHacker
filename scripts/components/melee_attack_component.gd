extends Area2D
class_name MeleeAttackComponent

## 近战攻击组件在短时间内开启一个朝向鼠标方向的 Area2D 命中框。
## 它只负责命中窗口、冷却、命中去重和可选伤害回调，不绑定任何具体敌人实现。
## 被命中的对象如果实现 apply_damage(damage: float, source: Node)，组件会自动调用。

signal attack_started(direction: Vector2)
signal attack_finished
signal body_hit(body: Node, damage: float)
signal area_hit(area: Area2D, damage: float)

## 近战伤害值；取值建议大于等于 0，默认 35 表示高于单发弹体伤害，运行时修改会影响后续命中伤害。
@export_range(0.0, 9999.0, 1.0, "or_greater") var damage: float = 35.0
## 近战冷却时长；取值应大于 0，默认 0.45 秒避免右键过密触发，运行时修改会影响攻击节奏。
@export_range(0.01, 5.0, 0.01) var cooldown_duration: float = 0.45
## 近战命中框持续时长；取值应大于 0，默认 0.12 秒形成短促挥击窗口，运行时修改会影响命中判定宽容度。
@export_range(0.01, 2.0, 0.01) var active_duration: float = 0.12
## 默认攻击距离；默认 91 像素，对应原命中框最远端与玩家本体的距离，仅在未传入武器资源时使用。
@export_range(1.0, 12000.0, 1.0, "or_greater") var attack_distance: float = 91.0
## 命中框碰撞形状路径；默认指向 HitboxShape，必须解析到 CollisionShape2D，修改会影响近战开启和关闭的碰撞区域。
@export var collision_shape_path: NodePath = ^"HitboxShape"
## 命中框调试视觉路径；默认指向 HitboxVisual，可为空，修改会影响近战攻击时的可视提示。
@export var visual_path: NodePath = ^"HitboxVisual"
## 近战朝向旋转偏移；取值为弧度，默认 0 表示命中框正向对准鼠标，修改会影响挥击方向校准。
@export var rotation_offset: float = 0.0

## 剩余冷却时间；取值大于等于 0，默认 0 表示可立即攻击，修改会影响是否允许下一次近战。
var _cooldown_remaining: float = 0.0
## 当前命中框剩余激活时间；取值大于等于 0，默认 0 表示未激活，修改会影响命中框关闭时机。
var _active_remaining: float = 0.0
## 当前挥击已命中对象表；键为 Node、值为 true，默认空字典用于单次攻击去重，修改会影响重复命中判定。
var _hit_instances: Dictionary = {}
## 当前挥击实际伤害；取值建议大于等于 0，默认跟随 damage，修改会影响本次挥击命中和信号伤害。
var _current_damage: float = 35.0
## 当前挥击冲击力；单位为目标单次无碰撞理论位移像素，默认 0 表示不击退，修改会影响本次挥击命中后的控制效果。
var _current_impact_force: float = 0.0
## 当前挥击方向；取值为单位向量，默认向右，修改会影响被击中目标的击退方向。
var _current_attack_direction: Vector2 = Vector2.RIGHT
## 当前近战冷却总时长；取值大于等于 0，默认 0 表示无冷却基准，修改会影响 HUD 冷却覆盖比例。
var _cooldown_duration: float = 0.0
## 当前挥击攻击力；默认 100，命中时参与统一攻防公式。
var _current_attack_power: float = 100.0
## 当前挥击暴击率；默认 0，每个命中目标独立判定。
var _current_critical_chance: float = 0.0
## 当前挥击暴击伤害倍率；默认 1.5 表示 150%。
var _current_critical_damage: float = 1.5
## 命中框沿攻击方向的固定近端距离；默认 0，ready 时由场景碰撞框位置和宽度自动计算，强化不会改变近端。
var _hitbox_near_distance: float = 0.0
## 命中框垂直高度；默认 1，ready 时从矩形碰撞形状读取，攻击距离变化时保持不变。
var _hitbox_height: float = 1.0

## 命中框碰撞形状缓存；默认按 collision_shape_path 获取，允许为空但无法碰撞，修改会影响近战判定开关。
@onready var _collision_shape: CollisionShape2D = get_node_or_null(collision_shape_path) as CollisionShape2D
## 命中框视觉节点缓存；默认按 visual_path 获取，允许为空，修改会影响攻击时是否显示调试视觉。
@onready var _visual: CanvasItem = get_node_or_null(visual_path) as CanvasItem


func _ready() -> void:
	_current_damage = damage
	_cache_hitbox_geometry()
	monitoring = false
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_set_hitbox_enabled(false)


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)

	if _active_remaining > 0.0:
		_active_remaining = maxf(_active_remaining - delta, 0.0)
		if _active_remaining <= 0.0:
			_finish_attack()


func try_attack(direction: Vector2, weapon_data: Resource = null, attack_modifiers: Dictionary = {}) -> bool:
	# 本次近战伤害；取值来自武器数据或组件默认值，默认 damage，修改会影响当前挥击命中伤害。
	var selected_damage: float = _get_weapon_attack_float(weapon_data, "damage", "melee", damage) * maxf(float(attack_modifiers.get("damage_multiplier", 1.0)), 0.0)
	# 本次近战冷却；取值来自武器数据或组件默认值，默认 cooldown_duration，修改会影响下一次可近战时间。
	var selected_cooldown: float = _get_weapon_float(weapon_data, "cooldown", cooldown_duration) * maxf(float(attack_modifiers.get("cooldown_multiplier", 1.0)), 0.0)
	# 本次近战激活时长；取值来自武器数据或组件默认值，默认 active_duration，修改会影响命中框持续时间。
	var selected_active_duration: float = _get_weapon_float(weapon_data, "melee_active_duration", active_duration)
	# 本次近战攻击距离；表示判定区域沿攻击方向的最远端与玩家本体的距离，强化后会动态改变碰撞范围。
	var selected_attack_distance: float = _get_weapon_attack_float(weapon_data, "attack_distance", "melee", attack_distance)
	# 本次近战冲击力；取值来自武器数据，单位为目标单次无碰撞理论位移像素，默认 0 表示只造成伤害不击退。
	var selected_impact_force: float = _get_weapon_attack_float(weapon_data, "impact_force", "melee", 0.0) * maxf(float(attack_modifiers.get("impact_multiplier", 1.0)), 0.0)
	# 本次武器暴击率；默认 0，不同近战武器可配置不同初始值。
	var selected_critical_chance: float = clampf(_get_weapon_float(weapon_data, "critical_chance", 0.0) + _get_stats_float("get_equipment_critical_chance", 0.0), 0.0, EnhancementRules.CRITICAL_CHANCE_MAXIMUM)
	# 本次武器暴击伤害；默认 1.5 表示 150%。
	var selected_critical_damage: float = _get_weapon_float(weapon_data, "critical_damage", 1.5) + _get_stats_float("get_equipment_critical_damage", 0.0)

	if _cooldown_remaining > 0.0 or _active_remaining > 0.0 or direction.is_zero_approx():
		return false

	rotation = direction.angle() + rotation_offset
	_current_damage = selected_damage
	_current_impact_force = selected_impact_force
	_current_attack_direction = direction.normalized()
	_current_attack_power = _get_owner_attack_power()
	_current_critical_chance = selected_critical_chance
	_current_critical_damage = selected_critical_damage
	_apply_attack_distance(selected_attack_distance)
	_hit_instances.clear()
	_cooldown_remaining = selected_cooldown
	_cooldown_duration = selected_cooldown
	_active_remaining = selected_active_duration
	_set_hitbox_enabled(true)
	attack_started.emit(direction)
	return true


func _finish_attack() -> void:
	_set_hitbox_enabled(false)
	attack_finished.emit()


func _set_hitbox_enabled(enabled: bool) -> void:
	monitoring = enabled
	if _collision_shape != null:
		_collision_shape.disabled = not enabled
	if _visual != null:
		_visual.visible = enabled


func _cache_hitbox_geometry() -> void:
	## 从场景中的矩形碰撞框读取固定近端和高度，并复制形状以避免运行时尺寸修改污染共享资源。
	if _collision_shape == null or not (_collision_shape.shape is RectangleShape2D):
		return
	# 原始矩形形状；提供场景配置的宽度与高度，读取后复制为当前组件独占资源。
	var original_shape: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	# 原始命中框宽度；最低为 1，避免异常场景资源产生零宽判定区域。
	var original_width: float = maxf(original_shape.size.x, 1.0)
	_hitbox_near_distance = _collision_shape.position.x - original_width * 0.5
	_hitbox_height = maxf(original_shape.size.y, 1.0)
	# 独占矩形形状；运行时只修改当前玩家实例，不改变场景子资源或其他实例。
	var runtime_shape: RectangleShape2D = original_shape.duplicate() as RectangleShape2D
	_collision_shape.shape = runtime_shape


func _apply_attack_distance(resolved_attack_distance: float) -> void:
	## 按“最远端到玩家本体的距离”重算近战判定框，保持场景定义的近端和高度不变。
	if _collision_shape == null or not (_collision_shape.shape is RectangleShape2D):
		return
	# 安全攻击距离；最低为 1 像素，保证极端削弱后仍存在有效判定区域。
	var safe_attack_distance: float = maxf(resolved_attack_distance, 1.0)
	# 本次近端距离；优先保持场景原近端，攻击距离短于原近端时自动向玩家收缩以维持正宽度。
	var resolved_near_distance: float = minf(_hitbox_near_distance, maxf(safe_attack_distance - 1.0, 0.0))
	# 动态碰撞宽度；等于最远端减近端，使矩形右侧最远端精确落在攻击距离处。
	var hitbox_width: float = safe_attack_distance - resolved_near_distance
	# 动态碰撞形状；高度保持场景原值，只沿攻击方向伸缩。
	var rectangle_shape: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	rectangle_shape.size = Vector2(hitbox_width, _hitbox_height)
	_collision_shape.position.x = resolved_near_distance + hitbox_width * 0.5
	if _visual is Polygon2D:
		# 动态视觉区域；与碰撞框共享近端、最远端和高度，确保调试显示与真实判定完全一致。
		var half_height: float = _hitbox_height * 0.5
		(_visual as Polygon2D).polygon = PackedVector2Array([
			Vector2(resolved_near_distance, -half_height),
			Vector2(safe_attack_distance, -half_height),
			Vector2(safe_attack_distance, half_height),
			Vector2(resolved_near_distance, half_height),
		])


func _on_body_entered(body: Node) -> void:
	if _register_hit(body):
		body_hit.emit(body, _current_damage)


func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return

	if _register_hit(area):
		area_hit.emit(area, _current_damage)


func _register_hit(target: Node) -> bool:
	if target == owner or target in _hit_instances:
		return false

	_hit_instances[target] = true
	if target.has_method("destroy_by_melee"):
		target.call("destroy_by_melee", owner)
		return true

	if target.has_method("apply_damage"):
		target.call("apply_damage", _current_damage, self)

	return true


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func get_cooldown_duration() -> float:
	return _cooldown_duration


func get_cooldown_ratio() -> float:
	if _cooldown_duration <= 0.0:
		return 0.0

	return clampf(_cooldown_remaining / _cooldown_duration, 0.0, 1.0)


func get_impact_force() -> float:
	return _current_impact_force


func get_knockback_direction() -> Vector2:
	return _current_attack_direction


func get_attack_power() -> float:
	return _current_attack_power


func get_critical_chance() -> float:
	return _current_critical_chance


func get_critical_damage_multiplier() -> float:
	return _current_critical_damage


func _get_weapon_float(weapon_data: Resource, property_name: StringName, fallback_value: float) -> float:
	if weapon_data == null:
		return fallback_value
	if weapon_data.has_method("get_effective_stat"):
		return float(weapon_data.call("get_effective_stat", str(property_name)))

	# 武器资源字段值；取值可能为数字或 null，默认通过 Resource.get 读取，修改会影响近战参数覆盖结果。
	var property_value: Variant = weapon_data.get(property_name)
	if property_value == null:
		return fallback_value

	return float(property_value)


func _get_weapon_attack_float(weapon_data: Resource, stat_name: String, attack_mode: String, fallback_value: float) -> float:
	## 读取指定远近战通道的有效属性；混合武器由资源返回独立基础值与共享强化结果，旧资源继续使用普通有效属性接口。
	if weapon_data == null:
		return fallback_value
	if weapon_data.has_method("get_effective_attack_stat"):
		return float(weapon_data.call("get_effective_attack_stat", stat_name, attack_mode))
	# 旧属性名；伤害在资源中以 melee_damage 保存，其余字段保持通用名称。
	var legacy_property_name: String = "melee_damage" if stat_name == "damage" else stat_name
	return _get_weapon_float(weapon_data, legacy_property_name, fallback_value)


func _get_owner_attack_power() -> float:
	# 玩家属性组件；缺失时使用 100 保持既有伤害。
	var stats_component: Node = owner.get_node_or_null("StatsComponent") if owner != null else null
	return float(stats_component.call("get_attack_power")) if stats_component != null and stats_component.has_method("get_attack_power") else 100.0


func _get_stats_float(method_name: String, fallback_value: float) -> float:
	# 玩家属性组件；用于读取装备提供的暴击附加值。
	var stats_component: Node = owner.get_node_or_null("StatsComponent") if owner != null else null
	return float(stats_component.call(method_name)) if stats_component != null and stats_component.has_method(method_name) else fallback_value
