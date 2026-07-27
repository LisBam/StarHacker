extends Node

## 穹的星尘王牌在状态内把当前护盾点数等量加入防御；武器提交时消耗全部护盾并为该次攻击准备附加伤害。

## 固定防御加成来源 ID；状态期间每帧覆盖为当前护盾值，结束时精确移除。
const DEFENSE_BONUS_SOURCE_ID: String = "caelus_stardust_ace_shield_defense"
## 冷却暂停来源 ID；5 秒状态结束后才开始 40 秒完整冷却。
const COOLDOWN_PAUSE_SOURCE_ID: String = "caelus_stardust_ace_state"

## 当前施法者；默认 null，用于监听武器提交并访问攻击组件与护盾。
var _caster: Node2D
## 当前战斗属性组件；默认 null，用于写入当前护盾对应的固定防御点数。
var _stats_component: Node
## 当前技能资源；默认 null，保存持续时间和两种附加伤害比例。
var _skill_data: Resource
## 主动技能组件；默认 null，用于暂停与恢复所属槽冷却。
var _active_skill_component: Node
## 所属技能槽；默认 -1，释放时由上下文记录。
var _slot_index: int = -1
## 状态剩余时间；默认 0 表示未激活。
var _remaining_duration: float = 0.0
## 当前近战攻击可用于全部目标的附加伤害；攻击结束后清零。
var _pending_melee_damage: float = 0.0
## 当前即将生成远程弹体的首目标附加伤害；弹体生成后立即清零。
var _pending_ranged_damage: float = 0.0
## 当前同步伤害值；目标 apply_damage 时通过本行为战斗接口读取。
var _current_damage: float = 0.0


func _ready() -> void:
	set_process(false)


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, active_skill_component: Node) -> void:
	## 注入依赖并连接武器提交、弹体生成和近战命中信号。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_active_skill_component = active_skill_component
	if not is_instance_valid(_caster):
		return
	_caster.connect("weapon_attack_committing", Callable(self, "_on_weapon_attack_committing"))
	for component_name in ["RangedAttackComponent", "HybridRangedAttackComponent"]:
		var component: Node = _caster.get_node_or_null(component_name)
		if component != null:
			component.connect("fired", Callable(self, "_on_projectile_fired"))
	for component_name in ["MeleeAttackComponent", "HybridMeleeAttackComponent"]:
		var component: Node = _caster.get_node_or_null(component_name)
		if component != null:
			component.connect("body_hit", Callable(self, "_on_melee_hit"))
			component.connect("area_hit", Callable(self, "_on_melee_hit"))
			component.connect("attack_finished", Callable(self, "_on_melee_attack_finished"))


func execute(context: Dictionary) -> bool:
	## 开启 5 秒状态并暂停本槽冷却；当前护盾从下一处理帧开始实时转化为防御力。
	if not is_instance_valid(_caster) or _skill_data == null:
		return false
	_slot_index = int(context.get("slot_index", -1))
	_remaining_duration = maxf(float(_skill_data.get("effect_duration")), 0.01)
	_active_skill_component.call("set_cooldown_paused_source", _slot_index, COOLDOWN_PAUSE_SOURCE_ID, true)
	_update_shield_defense_bonus()
	set_process(true)
	return true


func _process(delta: float) -> void:
	_remaining_duration = maxf(_remaining_duration - maxf(delta, 0.0), 0.0)
	_update_shield_defense_bonus()
	if _remaining_duration <= 0.0:
		_finish_effect()


func _update_shield_defense_bonus() -> void:
	## 每点当前护盾提供 1 点固定防御力；护盾被消耗或受伤降低后立即同步。
	if _stats_component == null or not _stats_component.has_method("set_skill_flat_stat_bonus"):
		return
	var shield_amount: float = float(_caster.call("get_current_shield")) if is_instance_valid(_caster) and _caster.has_method("get_current_shield") else 0.0
	_stats_component.call("set_skill_flat_stat_bonus", DEFENSE_BONUS_SOURCE_ID, 0.0, shield_amount)


func _on_weapon_attack_committing(source_kind: String, _source_index: int, _weapon: Resource) -> void:
	## 状态内武器正式提交时消耗全部护盾，并按来源槽记录本次附加伤害。
	if _remaining_duration <= 0.0 or not is_instance_valid(_caster):
		return
	var shield_component: Node = _caster.call("get_shield_component") if _caster.has_method("get_shield_component") else null
	var consumed_shield: float = float(shield_component.get("current_shield")) if shield_component != null else 0.0
	if consumed_shield <= 0.0:
		return
	shield_component.call("remove_shield", consumed_shield, true)
	if source_kind == "ranged":
		_pending_ranged_damage = consumed_shield * maxf(float(_skill_data.get("ranged_shield_damage_ratio")), 0.0)
	else:
		_pending_melee_damage = consumed_shield * maxf(float(_skill_data.get("melee_shield_damage_ratio")), 0.0)


func _on_projectile_fired(projectile: Node2D) -> void:
	## 把武器提交时保存的远程附加伤害绑定到本次弹体首个目标。
	if _pending_ranged_damage <= 0.0 or not is_instance_valid(projectile):
		return
	var bound_damage: float = _pending_ranged_damage
	_pending_ranged_damage = 0.0
	projectile.connect("hit_body", Callable(self, "_on_ranged_hit").bind(bound_damage), CONNECT_ONE_SHOT)
	projectile.connect("hit_area", Callable(self, "_on_ranged_hit").bind(bound_damage), CONNECT_ONE_SHOT)


func _on_ranged_hit(target: Node, _damage: float, bound_damage: float) -> void:
	## 对远程首个命中目标结算等同于全部消耗护盾值的附加伤害。
	_apply_shield_damage(target, bound_damage)


func _on_melee_hit(target: Node, _damage: float) -> void:
	## 对本次近战攻击的全部命中目标结算 50%消耗护盾值的附加伤害。
	_apply_shield_damage(target, _pending_melee_damage)


func _on_melee_attack_finished() -> void:
	## 近战命中窗口关闭后清除本次护盾伤害，避免污染下一次攻击。
	_pending_melee_damage = 0.0


func _apply_shield_damage(target: Node, damage: float) -> void:
	## 通过统一伤害接口结算护盾附加伤害；不暴击且不产生额外冲击。
	if damage <= 0.0 or not is_instance_valid(target) or not target.has_method("apply_damage"):
		return
	# 玩家综合增伤倍率；骇入协议“造成的伤害提高”和持盾、高能条件增伤与其他来源统一聚合。
	var outgoing_damage_multiplier: float = float(_caster.call("get_outgoing_damage_multiplier")) if is_instance_valid(_caster) and _caster.has_method("get_outgoing_damage_multiplier") else 1.0
	_current_damage = damage * maxf(outgoing_damage_multiplier, 0.0)
	target.call("apply_damage", _current_damage, self)


func get_attack_power() -> float:
	## 返回固定 100 公式攻击力，护盾值不会再次被玩家攻击力放大。
	return maxf(float(_skill_data.get("damage_formula_attack_power")), 0.0) if _skill_data != null else 100.0


func get_damage_instigator() -> Node:
	## 返回技能的实际施放者；目标据此查询玩家独立的骇入协议条件增伤与必定暴击规则。
	return _caster


func get_critical_chance() -> float:
	return 0.0


func get_critical_damage_multiplier() -> float:
	return 1.5


func get_impact_force() -> float:
	return 0.0


func _finish_effect() -> void:
	## 移除护盾防御转化并解除冷却暂停；已发射弹体仍保留其绑定的本次伤害。
	_remaining_duration = 0.0
	set_process(false)
	if _stats_component != null and _stats_component.has_method("remove_skill_flat_stat_bonus"):
		_stats_component.call("remove_skill_flat_stat_bonus", DEFENSE_BONUS_SOURCE_ID)
	if _active_skill_component != null and _slot_index >= 0:
		_active_skill_component.call("set_cooldown_paused_source", _slot_index, COOLDOWN_PAUSE_SOURCE_ID, false)


func shutdown() -> void:
	## 角色切换时结束状态并清空尚未命中的近战附加伤害。
	_finish_effect()
	_pending_melee_damage = 0.0
	_pending_ranged_damage = 0.0
