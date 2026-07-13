extends Node

## 幻影现实一段行为记录施法位置与生命，寻找鼠标目标附近最近空地，完成传送并结算落地范围伤害。

## 基础暴击伤害倍率；固定 1.5，与其他无武器主动技能的统一暴击协议一致。
const BASE_CRITICAL_DAMAGE_MULTIPLIER: float = 1.5

## 当前施法者；默认 null，由主动技能组件注入并提供安全落点与清理外部移动接口。
var _caster: Node2D
## 当前属性组件；默认 null，用于记录生命并读取释放瞬间最终攻击与装备暴击属性。
var _stats_component: Node
## 当前技能数据；默认 null，保存伤害、范围、冲击与安全搜索参数。
var _skill_data: Resource
## 当前落地伤害；默认 0，每次释放按基础 9 加 9% 最终攻击力并乘玩家套装增伤后固定。
var _current_damage: float = 0.0
## 当前伤害公式攻击力；默认 100，避免技能威力再次乘玩家攻击力。
var _current_attack_power: float = 100.0
## 当前暴击率；默认 0，释放瞬间从装备属性读取。
var _current_critical_chance: float = 0.0
## 当前暴击伤害倍率；默认 1.5，释放瞬间叠加装备暴击伤害。
var _current_critical_damage_multiplier: float = BASE_CRITICAL_DAMAGE_MULTIPLIER
## 当前目标击退方向；默认向右，每次范围命中前从落点指向目标更新。
var _current_knockback_direction: Vector2 = Vector2.RIGHT


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, _active_skill_component: Node) -> void:
	## 注入一段行为依赖；本节点没有跨阶段私有状态，记录值写入组件提供的 chain_state。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data


func execute(context: Dictionary) -> bool:
	## 执行一段传送；无法找到安全落点时返回 false，不记录阶段状态也不进入后续段。
	if not is_instance_valid(_caster) or _skill_data == null or not context.get("chain_state") is Dictionary:
		return false
	# 目标位置；位置指向模式已经把鼠标夹取到 250 像素范围内，异常类型回退施法者当前位置。
	var raw_target_position: Variant = context.get("target_position", _caster.global_position)
	# 标准化目标位置；只接受 Vector2，其他类型不会改变角色当前位置。
	var target_position: Vector2 = raw_target_position as Vector2 if raw_target_position is Vector2 else _caster.global_position
	# 安全落点；玩家接口用自身碰撞层排除施法者并按同心圆寻找最近环境空地。
	var safe_position: Vector2 = _caster.call("find_nearest_clear_position", target_position, float(_skill_data.get("teleport_clearance_radius")), float(_skill_data.get("teleport_search_step")), float(_skill_data.get("teleport_max_search_radius"))) as Vector2 if _caster.has_method("find_nearest_clear_position") else target_position
	if safe_position == Vector2.INF:
		return false
	# 阶段共享状态；记录传送前位置与生命，二段行为和致命伤害拦截从同一字典读取。
	var chain_state: Dictionary = context.get("chain_state") as Dictionary
	chain_state["recorded_position"] = _caster.global_position
	chain_state["recorded_health"] = float(_stats_component.get("current_health")) if _stats_component != null else 0.0
	_caster.global_position = safe_position
	if _caster.has_method("clear_external_motion"):
		_caster.call("clear_external_motion")
	_resolve_landing_damage(safe_position)
	return true


func _resolve_landing_damage(landing_position: Vector2) -> void:
	## 对落点半径内全部合法技能目标结算一次伤害；每个目标只在本次枚举中出现一次。
	# 释放瞬间最终攻击力；包含角色、装备、套装与技能倍率，用于 9% 威力转化。
	var attack_power: float = float(_stats_component.call("get_attack_power")) if _stats_component != null and _stats_component.has_method("get_attack_power") else 0.0
	# 玩家综合增伤倍率；由套装等来源统一聚合，行为不识别具体装备 ID。
	var outgoing_multiplier: float = float(_caster.call("get_outgoing_damage_multiplier")) if is_instance_valid(_caster) and _caster.has_method("get_outgoing_damage_multiplier") else 1.0
	_current_damage = (maxf(float(_skill_data.get("landing_base_damage")), 0.0) + attack_power * maxf(float(_skill_data.get("attack_power_ratio")), 0.0)) * maxf(outgoing_multiplier, 0.0)
	_current_attack_power = maxf(float(_skill_data.get("damage_formula_attack_power")), 0.0)
	_current_critical_chance = float(_stats_component.call("get_equipment_critical_chance")) if _stats_component != null and _stats_component.has_method("get_equipment_critical_chance") else 0.0
	_current_critical_damage_multiplier = maxf(BASE_CRITICAL_DAMAGE_MULTIPLIER + (float(_stats_component.call("get_equipment_critical_damage")) if _stats_component != null and _stats_component.has_method("get_equipment_critical_damage") else 0.0), 1.0)
	# 伤害半径平方；使用平方距离过滤，避免每个目标重复开方。
	var effect_radius_squared: float = pow(maxf(float(_skill_data.get("landing_effect_radius")), 1.0), 2.0)
	# 合法目标组；默认 skill_targets，空组不会枚举任何目标。
	var target_group: StringName = StringName(str(_skill_data.get("target_group")))
	for raw_target in get_tree().get_nodes_in_group(target_group):
		# 当前候选目标；必须有效、未排队释放且提供统一伤害接口。
		var target: Node2D = raw_target as Node2D
		if target == null or target == _caster or not is_instance_valid(target) or target.is_queued_for_deletion() or not target.has_method("apply_damage"):
			continue
		# 目标相对落点偏移；用于圆形距离过滤与径向击退方向。
		var target_offset: Vector2 = target.global_position - landing_position
		if target_offset.length_squared() > effect_radius_squared:
			continue
		_current_knockback_direction = target_offset.normalized() if not target_offset.is_zero_approx() else Vector2.RIGHT
		target.call("apply_damage", _current_damage, self)


func get_attack_power() -> float:
	## 返回本次落地伤害使用的固定公式攻击力。
	return _current_attack_power


func get_critical_chance() -> float:
	## 返回释放瞬间固定的装备暴击率。
	return clampf(_current_critical_chance, 0.0, 1.0)


func get_critical_damage_multiplier() -> float:
	## 返回释放瞬间固定的暴击伤害倍率。
	return maxf(_current_critical_damage_multiplier, 1.0)


func get_impact_force() -> float:
	## 返回资源配置的 75 点落地冲击力。
	return maxf(float(_skill_data.get("landing_impact_force")), 0.0) if _skill_data != null else 0.0


func get_knockback_direction() -> Vector2:
	## 返回当前同步命中目标对应的径向击退方向。
	return _current_knockback_direction
