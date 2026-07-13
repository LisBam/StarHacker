extends Node

## 不灭的琥珀立即为穹和周围友方添加 10 秒护盾；行为独立计时并在到期时移除本次尚存部分。

## 当前施法者；默认 null，作为自身目标与范围中心。
var _caster: Node2D
## 当前战斗属性组件；默认 null，用于读取最终防御力。
var _stats_component: Node
## 当前技能资源；默认 null，保存两套护盾公式、持续时间与范围。
var _skill_data: Resource
## 当前仍在计时的护盾记录；每项保存组件、授予量和剩余时间。
var _timed_shields: Array[Dictionary] = []


func _ready() -> void:
	set_process(true)


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, _active_skill_component: Node) -> void:
	## 注入技能依赖；本技能允许在冲锋期间正常执行，不主动取消强制移动。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data


func execute(_context: Dictionary) -> bool:
	## 为自身和范围内全部其他友方添加独立限时护盾记录。
	if not is_instance_valid(_caster) or _skill_data == null:
		return false
	var defense_power: float = float(_stats_component.call("get_defense_power")) if _stats_component != null and _stats_component.has_method("get_defense_power") else 0.0
	_grant_timed_shield(_caster, maxf(float(_skill_data.get("self_base_shield")), 0.0) + defense_power * maxf(float(_skill_data.get("self_defense_ratio")), 0.0))
	for raw_unit in get_tree().get_nodes_in_group(&"friendly_units"):
		var unit: Node2D = raw_unit as Node2D
		if unit != null and unit != _caster and unit.global_position.distance_to(_caster.global_position) <= maxf(float(_skill_data.get("ally_radius")), 1.0):
			_grant_timed_shield(unit, maxf(float(_skill_data.get("ally_base_shield")), 0.0) + defense_power * maxf(float(_skill_data.get("ally_defense_ratio")), 0.0))
	return true


func _process(delta: float) -> void:
	for index in range(_timed_shields.size() - 1, -1, -1):
		var record: Dictionary = _timed_shields[index]
		record["remaining"] = maxf(float(record.get("remaining", 0.0)) - maxf(delta, 0.0), 0.0)
		if float(record["remaining"]) > 0.0:
			_timed_shields[index] = record
			continue
		var component: Node = record.get("component") as Node
		if is_instance_valid(component) and component.has_method("remove_shield"):
			component.call("remove_shield", float(record.get("amount", 0.0)), true)
		_timed_shields.remove_at(index)


func _grant_timed_shield(unit: Node2D, amount: float) -> void:
	## 为一个单位添加护盾并记录实际增加量；无护盾接口或零增量不会创建空计时器。
	var component: Node = unit.call("get_shield_component") if unit.has_method("get_shield_component") else null
	if component == null or not component.has_method("add_shield") or amount <= 0.0:
		return
	var actual_amount: float = float(component.call("add_shield", amount, true))
	if actual_amount > 0.0:
		_timed_shields.append({"component": component, "amount": actual_amount, "remaining": maxf(float(_skill_data.get("shield_duration")), 0.01)})


func shutdown() -> void:
	## 角色切换时立即移除所有仍存的本技能护盾，不影响其他来源。
	for record in _timed_shields:
		var component: Node = (record as Dictionary).get("component") as Node
		if is_instance_valid(component) and component.has_method("remove_shield"):
			component.call("remove_shield", float((record as Dictionary).get("amount", 0.0)), true)
	_timed_shields.clear()
