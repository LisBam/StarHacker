extends Node

## 炎墙，冲锋！行为负责释放后的强制移动生命周期、撞击去重、伤害和垂直击退方向。
## 输入、蓄力时间、能量和冷却继续由 ActiveSkillComponent 统一管理。

## 基础暴击伤害倍率；固定 1.5，与武器和其他主动技能的无武器暴击协议一致。
const BASE_CRITICAL_DAMAGE_MULTIPLIER: float = 1.5
## 冲锋减伤来源 ID；固定字符串确保重复释放覆盖自身且结束时不移除其他效果。
const DAMAGE_REDUCTION_SOURCE_ID: String = "caelus_firewall_charge"

## 当前施法者；默认 null，由主动技能组件创建行为后注入，必须提供强制移动和减伤公开接口。
var _caster: Node2D
## 当前战斗属性组件；默认 null，用于读取释放瞬间防御力、暴击率和暴击伤害。
var _stats_component: Node
## 当前技能资源；默认 null，提供冲锋时长、速度、伤害、冲击和检测范围。
var _skill_data: Resource
## 当前冲锋剩余时间；取值大于等于 0，默认 0，释放成功后按基础 1 秒加实际蓄力秒数写入。
var _charge_remaining: float = 0.0
## 当前冲锋方向；默认向右，释放时固定，持续期间不响应鼠标或移动输入变化。
var _charge_direction: Vector2 = Vector2.RIGHT
## 当前冲锋已命中目标表；键为目标实例、值为 true，默认空字典，每次释放清空以保证每个敌人只受击一次。
var _hit_targets: Dictionary = {}
## 当前撞击伤害；默认 0，释放瞬间按 10+20%最终防御力固定，本次冲锋全部目标共享。
var _current_damage: float = 0.0
## 当前撞击来源攻击力；默认 100，使技能威力不会再次乘算玩家攻击力。
var _current_attack_power: float = 100.0
## 当前撞击暴击率；默认 0，释放瞬间读取装备加成，每个目标仍由统一伤害计算器独立判定。
var _current_critical_chance: float = 0.0
## 当前撞击暴击伤害倍率；默认 1.5，释放瞬间叠加装备暴击伤害。
var _current_critical_damage_multiplier: float = BASE_CRITICAL_DAMAGE_MULTIPLIER
## 当前目标击退方向；默认向上，每次命中前按目标相对冲锋轴线位置更新为两侧垂直方向之一。
var _current_knockback_direction: Vector2 = Vector2.UP


func _ready() -> void:
	set_physics_process(false)


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, _active_skill_component: Node) -> void:
	## 注入行为依赖；角色切换会销毁本节点，退出树时会清理仍活动的减伤来源。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data


func execute(context: Dictionary) -> bool:
	## 启动一次冲锋；没有命中目标也视为成功，只要施法者能够进入强制移动状态。
	if not is_instance_valid(_caster) or _skill_data == null or not _caster.has_method("start_forced_movement"):
		return false
	# 原始方向；只接收 Vector2，零向量回退向右，保证冲锋始终拥有确定方向。
	var raw_direction: Variant = context.get("aim_direction", Vector2.RIGHT)
	# 提供方向；经过类型检查后再赋值到强类型变量，零向量继续使用默认向右。
	var provided_direction: Vector2 = raw_direction as Vector2 if raw_direction is Vector2 else Vector2.ZERO
	_charge_direction = provided_direction.normalized() if not provided_direction.is_zero_approx() else Vector2.RIGHT
	# 实际蓄力秒数；由主动技能组件限制到最多 2 秒，直接等量延长基础冲锋时长。
	var charge_seconds: float = clampf(float(context.get("charge_seconds", 0.0)), 0.0, maxf(float(_skill_data.get("maximum_charge_duration")), 0.01))
	_charge_remaining = maxf(float(_skill_data.get("base_charge_duration")), 0.01) + charge_seconds
	if not bool(_caster.call("start_forced_movement", _charge_direction, _charge_remaining, maxf(float(_skill_data.get("bonus_move_speed_attribute")), 0.0))):
		_charge_remaining = 0.0
		return false
	# 释放瞬间最终防御力；包含角色、装备、套装和被动倍率，本次冲锋期间固定不再变化。
	var defense_power: float = float(_stats_component.call("get_defense_power")) if _stats_component != null and _stats_component.has_method("get_defense_power") else 0.0
	_current_damage = maxf(float(_skill_data.get("base_damage")), 0.0) + defense_power * maxf(float(_skill_data.get("defense_power_ratio")), 0.0)
	_current_attack_power = maxf(float(_skill_data.get("damage_formula_attack_power")), 0.0)
	_current_critical_chance = float(_stats_component.call("get_equipment_critical_chance")) if _stats_component != null and _stats_component.has_method("get_equipment_critical_chance") else 0.0
	_current_critical_damage_multiplier = maxf(BASE_CRITICAL_DAMAGE_MULTIPLIER + (float(_stats_component.call("get_equipment_critical_damage")) if _stats_component != null and _stats_component.has_method("get_equipment_critical_damage") else 0.0), 1.0)
	_hit_targets.clear()
	if _caster.has_method("set_damage_reduction_source"):
		_caster.call("set_damage_reduction_source", DAMAGE_REDUCTION_SOURCE_ID, clampf(float(_skill_data.get("charge_damage_reduction_ratio")), 0.0, 1.0))
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	if _charge_remaining <= 0.0 or not is_instance_valid(_caster):
		_finish_charge()
		return
	_resolve_collisions()
	_charge_remaining = maxf(_charge_remaining - maxf(delta, 0.0), 0.0)
	if _charge_remaining <= 0.0:
		_finish_charge()


func _resolve_collisions() -> void:
	## 枚举技能目标组并按圆形半径判定撞击；每个目标在同一次冲锋中最多结算一次。
	# 目标组；默认 skill_targets，与通用主动技能合法目标协议一致，空组不命中任何节点。
	var target_group: StringName = StringName(str(_skill_data.get("target_group")))
	# 检测半径平方；最低半径 1 像素，平方比较避免逐目标开方。
	var collision_radius_squared: float = pow(maxf(float(_skill_data.get("collision_radius")), 1.0), 2.0)
	for raw_target in get_tree().get_nodes_in_group(target_group):
		# 候选目标；必须有效、未命中过、提供伤害接口且位于碰撞半径内。
		var target: Node2D = raw_target as Node2D
		if target == null or target == _caster or target in _hit_targets or not is_instance_valid(target) or target.is_queued_for_deletion() or not target.has_method("apply_damage"):
			continue
		if _caster.global_position.distance_squared_to(target.global_position) > collision_radius_squared:
			continue
		_hit_targets[target] = true
		# 垂直基准方向；顺时针旋转 90 度得到冲锋右侧方向，目标位于另一侧时反向。
		var perpendicular_direction: Vector2 = Vector2(-_charge_direction.y, _charge_direction.x)
		# 目标侧向投影；零投影目标固定推向右侧，保证轴线上目标也有明确击退方向。
		var side_projection: float = (target.global_position - _caster.global_position).dot(perpendicular_direction)
		_current_knockback_direction = perpendicular_direction if side_projection >= 0.0 else -perpendicular_direction
		target.call("apply_damage", _current_damage, self)


func _finish_charge() -> void:
	## 结束冲锋行为并移除独立减伤来源；玩家强制移动使用相同时长，会在自身物理帧同步归零。
	_charge_remaining = 0.0
	set_physics_process(false)
	if is_instance_valid(_caster) and _caster.has_method("remove_damage_reduction_source"):
		_caster.call("remove_damage_reduction_source", DAMAGE_REDUCTION_SOURCE_ID)


func _exit_tree() -> void:
	_finish_charge()
	if is_instance_valid(_caster) and _caster.has_method("cancel_forced_movement"):
		_caster.call("cancel_forced_movement")


func get_attack_power() -> float:
	## 返回本次冲锋固定公式攻击力，供目标统一攻防公式同步读取。
	return _current_attack_power


func get_critical_chance() -> float:
	## 返回本次冲锋固定暴击率，限制到 0 至 100%。
	return clampf(_current_critical_chance, 0.0, 1.0)


func get_critical_damage_multiplier() -> float:
	## 返回本次冲锋固定暴击伤害倍率，最低为 1 倍。
	return maxf(_current_critical_damage_multiplier, 1.0)


func get_impact_force() -> float:
	## 返回资源配置的 50 点理论位移冲击力，目标会继续按韧性与自身衰减换算。
	return maxf(float(_skill_data.get("impact_force")), 0.0) if _skill_data != null else 0.0


func get_knockback_direction() -> Vector2:
	## 返回当前命中目标对应的冲锋垂直方向；目标在同步 apply_damage 回调中读取。
	return _current_knockback_direction
