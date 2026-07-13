extends Node

## “星尘王牌”行为监听玩家现有攻击组件的命中信号，在状态期间追加一次独立伤害。
## 远程弹体只对其第一个命中目标追加，近战与银河全垒打对所有命中目标追加；状态结束后技能冷却才开始递减。

## 冷却暂停来源 ID；状态激活期间保持本槽完整冷却不递减。
const COOLDOWN_PAUSE_SOURCE_ID: String = "stelle_stardust_ace_state"
## 银河全垒打技能 ID；固定与资源 skill_id 一致，用于过滤玩家技能命中事件。
const GRAND_SLAM_SKILL_ID: String = "stelle_galactic_grand_slam"

## 当前施法者；默认 null，用于读取攻击力、监听武器使用与查找攻击组件。
var _caster: Node2D
## 当前战斗属性组件；默认 null，用于读取状态命中瞬间的最终攻击力。
var _stats_component: Node
## 当前技能资源；默认 null，保存状态与附加伤害数值。
var _skill_data: Resource
## 主动技能组件；默认 null，用于暂停和恢复所属槽冷却。
var _active_skill_component: Node
## 所属技能槽；默认 -1，释放时由上下文记录。
var _slot_index: int = -1
## 状态剩余时间；默认 0 表示未激活，正值时命中监听才追加伤害。
var _remaining_duration: float = 0.0
## 状态内已成功使用武器次数；默认 0，达到资源上限后立即结束状态。
var _weapon_attack_count: int = 0
## 当前正在结算的附加威力；默认 0，目标同步 apply_damage 时通过本行为的战斗接口读取其他属性。
var _current_bonus_damage: float = 0.0
## 已连接的远程攻击组件；用于 shutdown 时精确断开 fired 信号。
var _ranged_components: Array[Node] = []
## 已连接的近战攻击组件；用于 shutdown 时精确断开 body_hit 与 area_hit 信号。
var _melee_components: Array[Node] = []


func _ready() -> void:
	set_process(false)


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, active_skill_component: Node) -> void:
	## 注入依赖并连接稳定攻击信号；状态未激活时回调只做快速返回。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_active_skill_component = active_skill_component
	if not is_instance_valid(_caster):
		return
	if _caster.has_signal("weapon_attack_succeeded"):
		_caster.connect("weapon_attack_succeeded", Callable(self, "_on_weapon_attack_succeeded"))
	if _caster.has_signal("skill_target_hit"):
		_caster.connect("skill_target_hit", Callable(self, "_on_skill_target_hit"))
	_connect_attack_components()


func execute(context: Dictionary) -> bool:
	## 开始完整 10 秒状态；重复执行会重置次数与时间，但正常冷却规则会阻止状态期间再次释放。
	if not is_instance_valid(_caster) or _skill_data == null:
		return false
	_slot_index = int(context.get("slot_index", -1))
	_remaining_duration = maxf(float(_skill_data.get("effect_duration")), 0.01)
	_weapon_attack_count = 0
	if _active_skill_component != null and _active_skill_component.has_method("set_cooldown_paused_source") and _slot_index >= 0:
		_active_skill_component.call("set_cooldown_paused_source", _slot_index, COOLDOWN_PAUSE_SOURCE_ID, true)
	set_process(true)
	return true


func _process(delta: float) -> void:
	_remaining_duration = maxf(_remaining_duration - maxf(delta, 0.0), 0.0)
	if _remaining_duration <= 0.0:
		_finish_effect()


func _connect_attack_components() -> void:
	## 连接玩家四个攻击通道；主副通道共享回调，目标去重仍由原攻击组件和弹体负责。
	for component_name in ["RangedAttackComponent", "HybridRangedAttackComponent"]:
		var ranged_component: Node = _caster.get_node_or_null(component_name)
		if ranged_component != null and ranged_component.has_signal("fired"):
			ranged_component.connect("fired", Callable(self, "_on_projectile_fired"))
			_ranged_components.append(ranged_component)
	for component_name in ["MeleeAttackComponent", "HybridMeleeAttackComponent"]:
		var melee_component: Node = _caster.get_node_or_null(component_name)
		if melee_component == null:
			continue
		if melee_component.has_signal("body_hit"):
			melee_component.connect("body_hit", Callable(self, "_on_melee_target_hit"))
		if melee_component.has_signal("area_hit"):
			melee_component.connect("area_hit", Callable(self, "_on_melee_target_hit"))
		_melee_components.append(melee_component)


func _on_projectile_fired(projectile: Node2D) -> void:
	## 为状态期间新生成的玩家弹体绑定一次性首目标附加伤害；状态结束后命中会被回调内状态检查忽略。
	if _remaining_duration <= 0.0 or not is_instance_valid(projectile):
		return
	if projectile.has_signal("hit_body"):
		projectile.connect("hit_body", Callable(self, "_on_ranged_target_hit").bind(projectile), CONNECT_ONE_SHOT)
	if projectile.has_signal("hit_area"):
		projectile.connect("hit_area", Callable(self, "_on_ranged_target_hit").bind(projectile), CONNECT_ONE_SHOT)


func _on_ranged_target_hit(target: Node, _damage: float, _projectile: Node) -> void:
	## 远程弹体只对首个合法目标追加远程公式伤害。
	# 弹体在状态有效时已经取得本次附加伤害资格；即使飞行途中状态结束，首个命中仍应完成该次攻击效果。
	_apply_bonus_damage(target, true, true)


func _on_melee_target_hit(target: Node, _damage: float) -> void:
	## 近战命中框对本次挥击的每个合法目标追加近战公式伤害。
	_apply_bonus_damage(target, false)


func _on_skill_target_hit(skill_id: String, target: Node) -> void:
	## 银河全垒打状态内每个命中目标追加近战公式伤害，其他主动技能不触发。
	if skill_id == GRAND_SLAM_SKILL_ID:
		_apply_bonus_damage(target, false)


func _on_weapon_attack_succeeded(source_kind: String, _source_index: int, _weapon_data: Resource) -> void:
	## 每次成功使用武器计数一次；混合武器的副通道不会重复派发该玩家信号。
	if _remaining_duration <= 0.0:
		return
	_weapon_attack_count += 1
	if _weapon_attack_count >= maxi(int(_skill_data.get("maximum_weapon_attack_count")), 1):
		if source_kind == "melee":
			# 第三次近战攻击的命中框会在成功信号后继续存在，按资源宽限等待本次全部目标完成结算。
			_remaining_duration = minf(_remaining_duration, maxf(float(_skill_data.get("melee_resolution_grace_duration")), 0.0))
		else:
			_finish_effect()


func _apply_bonus_damage(target: Node, ranged_formula: bool, allow_after_state_end: bool = false) -> void:
	## 按远程或近战公式组成附加威力，并通过目标原有 apply_damage 接口进入统一防御结算。
	if (_remaining_duration <= 0.0 and not allow_after_state_end) or not is_instance_valid(target) or not target.has_method("apply_damage"):
		return
	# 当前最终攻击力；包含装备和被动技能倍率，按每次命中瞬间读取。
	var attack_power: float = float(_stats_component.call("get_attack_power")) if _stats_component != null and _stats_component.has_method("get_attack_power") else 100.0
	# 固定伤害；远程默认 8，近战与银河全垒打默认 5。
	var base_damage: float = float(_skill_data.get("ranged_bonus_base_damage")) if ranged_formula else float(_skill_data.get("melee_bonus_base_damage"))
	# 攻击力比例；远程默认 5%，近战默认 2.5%。
	var attack_power_ratio: float = float(_skill_data.get("ranged_bonus_attack_power_ratio")) if ranged_formula else float(_skill_data.get("melee_bonus_attack_power_ratio"))
	_current_bonus_damage = maxf(base_damage, 0.0) + attack_power * maxf(attack_power_ratio, 0.0)
	target.call("apply_damage", _current_bonus_damage, self)


func get_attack_power() -> float:
	## 返回固定公式攻击力；附加威力已包含角色攻击力比例，避免统一公式重复乘算。
	return maxf(float(_skill_data.get("damage_formula_attack_power")), 0.0) if _skill_data != null else 100.0


func get_critical_chance() -> float:
	## 星尘王牌附加伤害不独立暴击，固定返回 0。
	return 0.0


func get_critical_damage_multiplier() -> float:
	## 无暴击时倍率不参与结果，仍返回项目统一 1.5 作为接口完整值。
	return 1.5


func get_impact_force() -> float:
	## 附加伤害不产生额外击退，固定返回 0。
	return 0.0


func _finish_effect() -> void:
	## 结束状态并解除冷却暂停；调用幂等，状态结束后的命中回调不会再追加伤害。
	_remaining_duration = 0.0
	set_process(false)
	if _active_skill_component != null and _active_skill_component.has_method("set_cooldown_paused_source") and _slot_index >= 0:
		_active_skill_component.call("set_cooldown_paused_source", _slot_index, COOLDOWN_PAUSE_SOURCE_ID, false)


func shutdown() -> void:
	## 角色切换时停止状态并断开全部外部信号，避免旧行为继续响应新角色攻击。
	_finish_effect()
	if is_instance_valid(_caster):
		if _caster.has_signal("weapon_attack_succeeded") and _caster.is_connected("weapon_attack_succeeded", Callable(self, "_on_weapon_attack_succeeded")):
			_caster.disconnect("weapon_attack_succeeded", Callable(self, "_on_weapon_attack_succeeded"))
		if _caster.has_signal("skill_target_hit") and _caster.is_connected("skill_target_hit", Callable(self, "_on_skill_target_hit")):
			_caster.disconnect("skill_target_hit", Callable(self, "_on_skill_target_hit"))
	for ranged_component in _ranged_components:
		if is_instance_valid(ranged_component) and ranged_component.is_connected("fired", Callable(self, "_on_projectile_fired")):
			ranged_component.disconnect("fired", Callable(self, "_on_projectile_fired"))
	for melee_component in _melee_components:
		if not is_instance_valid(melee_component):
			continue
		if melee_component.is_connected("body_hit", Callable(self, "_on_melee_target_hit")):
			melee_component.disconnect("body_hit", Callable(self, "_on_melee_target_hit"))
		if melee_component.is_connected("area_hit", Callable(self, "_on_melee_target_hit")):
			melee_component.disconnect("area_hit", Callable(self, "_on_melee_target_hit"))
	_ranged_components.clear()
	_melee_components.clear()
