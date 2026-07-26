extends Node

## 同协舞灯在 10 秒状态内监听玩家与附近友方的伤害事件，并按每单位独立 0.5 秒间隔治疗伤害发起者自身。

## 友方连接刷新间隔；固定 0.3 秒，状态期间新召唤的友方最迟延迟该时长接入监听，避免每帧全量扫描友方组。
const FRIENDLY_REFRESH_INTERVAL: float = 0.3

## 当前施法者；默认 null，始终属于有效友方并作为范围中心。
var _caster: Node2D
## 玩家战斗属性组件；默认 null，用于读取玩家生命上限和执行治疗。
var _stats_component: Node
## 当前技能资源；默认 null，保存持续时间、间隔、治疗公式和范围。
var _skill_data: Resource
## 当前主动技能组件；本技能不直接修改槽状态，保留统一配置协议。
var _active_skill_component: Node
## 状态剩余时间；默认 0 表示未激活。
var _remaining_duration: float = 0.0
## 每个单位下次允许治疗的时间；键为实例 ID、值为秒数，分别递减避免多个单位共享节流。
var _unit_trigger_cooldowns: Dictionary = {}
## 已连接的友方单位表；键为实例 ID、值为节点引用，动态召唤的友方会在状态期间补充连接。
var _connected_friendlies: Dictionary = {}
## 友方连接刷新计时；累计状态期间经过的秒数，达到刷新间隔后归零并触发一次友方组扫描，避免逐帧组数组分配。
var _friendly_refresh_accumulated: float = 0.0


func _ready() -> void:
	set_process(false)


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, active_skill_component: Node) -> void:
	## 注入依赖并连接玩家现有伤害命中信号；未激活时回调直接忽略。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_active_skill_component = active_skill_component
	if is_instance_valid(_caster) and _caster.has_signal("skill_target_hit"):
		_caster.connect("skill_target_hit", Callable(self, "_on_player_skill_hit"))
	for component_name in ["MeleeAttackComponent", "HybridMeleeAttackComponent"]:
		var component: Node = _caster.get_node_or_null(component_name) if is_instance_valid(_caster) else null
		if component != null and component.has_signal("body_hit"):
			component.connect("body_hit", Callable(self, "_on_player_weapon_hit"))
			component.connect("area_hit", Callable(self, "_on_player_weapon_hit"))
	for component_name in ["RangedAttackComponent", "HybridRangedAttackComponent"]:
		var component: Node = _caster.get_node_or_null(component_name) if is_instance_valid(_caster) else null
		if component != null and component.has_signal("fired"):
			component.connect("fired", Callable(self, "_on_projectile_fired"))


func execute(_context: Dictionary) -> bool:
	## 开启完整持续时间并立即扫描当前友方；重复配置由主动技能冷却阻止。
	if not is_instance_valid(_caster) or _skill_data == null:
		return false
	_remaining_duration = maxf(float(_skill_data.get("effect_duration")), 0.01)
	_unit_trigger_cooldowns.clear()
	_friendly_refresh_accumulated = 0.0
	_refresh_friendly_connections()
	set_process(true)
	return true


func _process(delta: float) -> void:
	_remaining_duration = maxf(_remaining_duration - maxf(delta, 0.0), 0.0)
	for raw_id in _unit_trigger_cooldowns:
		_unit_trigger_cooldowns[raw_id] = maxf(float(_unit_trigger_cooldowns[raw_id]) - maxf(delta, 0.0), 0.0)
	_friendly_refresh_accumulated += maxf(delta, 0.0)
	if _friendly_refresh_accumulated >= FRIENDLY_REFRESH_INTERVAL:
		_friendly_refresh_accumulated = 0.0
		_refresh_friendly_connections()
	if _remaining_duration <= 0.0:
		set_process(false)


func _refresh_friendly_connections() -> void:
	## 连接状态期间新召唤的友方；离树引用从缓存移除，不影响其他单位。
	for raw_unit in get_tree().get_nodes_in_group(&"friendly_units"):
		var unit: Node2D = raw_unit as Node2D
		if unit == null or _connected_friendlies.has(unit.get_instance_id()) or not unit.has_signal("damage_dealt"):
			continue
		unit.connect("damage_dealt", Callable(self, "_on_friendly_damage_dealt").bind(unit))
		_connected_friendlies[unit.get_instance_id()] = unit
	# 失效连接收集容器；默认 null 表示没有需要清理的离树友方，仅在确实需要移除时才创建数组，避免每次刷新固定分配。
	var invalid_unit_ids: Variant = null
	for raw_id in _connected_friendlies:
		if not is_instance_valid(_connected_friendlies[raw_id]):
			if invalid_unit_ids == null:
				invalid_unit_ids = []
			invalid_unit_ids.append(raw_id)
	if invalid_unit_ids == null:
		return
	# 失效连接遍历项；迭代结束后统一移除，避免在字典迭代过程中直接 erase。
	for invalid_unit_id in invalid_unit_ids:
		_connected_friendlies.erase(invalid_unit_id)


func _on_projectile_fired(projectile: Node2D) -> void:
	## 状态期间生成的弹体在首次合法命中时触发玩家自身治疗。
	if _remaining_duration <= 0.0 or not is_instance_valid(projectile):
		return
	if projectile.has_signal("hit_body"):
		projectile.connect("hit_body", Callable(self, "_on_player_weapon_hit"), CONNECT_ONE_SHOT)
	if projectile.has_signal("hit_area"):
		projectile.connect("hit_area", Callable(self, "_on_player_weapon_hit"), CONNECT_ONE_SHOT)


func _on_player_weapon_hit(_target: Node, _damage: float) -> void:
	## 玩家武器造成伤害时尝试治疗玩家自身。
	_try_heal_unit(_caster)


func _on_player_skill_hit(_skill_id: String, _target: Node) -> void:
	## 玩家主动技能造成伤害时尝试治疗玩家自身。
	_try_heal_unit(_caster)


func _on_friendly_damage_dealt(_target: Node, _damage: float, unit: Node2D) -> void:
	## 其他友方只有仍位于玩家作用半径内时治疗其自身。
	if not is_instance_valid(unit) or not is_instance_valid(_caster) or unit.global_position.distance_to(_caster.global_position) > maxf(float(_skill_data.get("friendly_effect_radius")), 1.0):
		return
	_try_heal_unit(unit)


func _try_heal_unit(unit: Node2D) -> void:
	## 按单位独立间隔执行 `2 + 1%自身最大生命` 治疗，并限制到生命上限。
	if _remaining_duration <= 0.0 or not is_instance_valid(unit):
		return
	var unit_id: int = unit.get_instance_id()
	if float(_unit_trigger_cooldowns.get(unit_id, 0.0)) > 0.0:
		return
	var max_health: float = 0.0
	if unit == _caster and _stats_component != null:
		max_health = float(_stats_component.get("max_health"))
	elif unit.is_in_group(&"friendly_units"):
		max_health = float(unit.get("max_health"))
	var heal_amount: float = maxf(float(_skill_data.get("base_heal_amount")), 0.0) + maxf(max_health, 0.0) * maxf(float(_skill_data.get("max_health_heal_ratio")), 0.0)
	if unit == _caster and _stats_component != null and _stats_component.has_method("heal"):
		_stats_component.call("heal", heal_amount)
	elif unit.has_method("heal"):
		unit.call("heal", heal_amount)
	_unit_trigger_cooldowns[unit_id] = maxf(float(_skill_data.get("trigger_interval")), 0.01)


func shutdown() -> void:
	## 角色切换时结束状态；外部节点释放后连接会由 Godot 自动失效。
	_remaining_duration = 0.0
	set_process(false)
	_connected_friendlies.clear()
	_unit_trigger_cooldowns.clear()
