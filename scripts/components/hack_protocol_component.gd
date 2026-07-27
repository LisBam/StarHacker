extends Node
class_name HackProtocolComponent

## 骇入协议组件只管理一名本地玩家的碎片、候选、已获得协议和协议效果。
## 组件不保存到永久存档，也不直接创建 UI；战斗 HUD 通过信号和公开快照展示进度，
## GameWorld 与 NetworkCombatSync 只负责把本机确认的击杀、宝箱和团队协议摘要转交给它。

signal fragments_changed(current_fragments: float, required_fragments: float)
signal offer_ready
signal protocols_changed(protocol_ids: Array[String])
signal protocol_acquired(protocol_id: String, acquired_protocol_count: int)

## 玩家战斗属性组件路径；默认指向同级 StatsComponent，运行时通常不修改。
@export var stats_component_path: NodePath = ^"../StatsComponent"
## 玩家护盾组件路径；默认指向同级 ShieldComponent，运行时通常不修改。
@export var shield_component_path: NodePath = ^"../ShieldComponent"
## 玩家主动技能组件路径；默认指向同级 ActiveSkillComponent，击杀缩减冷却协议通过其公开接口结算。
@export var active_skill_component_path: NodePath = ^"../ActiveSkillComponent"
## 参与破盾震荡的敌人节点组；默认 training_monsters，单机真实敌人与联机傀儡使用同一分组。
@export var enemy_group: StringName = &"training_monsters"
## 协议减伤叠加上限；默认 40%，避免重复获得常驻减伤后完全免疫伤害，运行时通常不修改。
@export_range(0.0, 1.0, 0.01) var maximum_static_damage_reduction_ratio: float = 0.40
## 冲刺后临时减伤的协议内叠加上限；默认 40%，两层达到上限，仍允许与其他系统按玩家统一免伤乘区结算。
@export_range(0.0, 1.0, 0.01) var maximum_dodge_damage_reduction_ratio: float = 0.40
## 冲刺和疾跑最低剩余能耗倍率；默认 20%，重复节流协议不会把操作成本降为零。
@export_range(0.0, 1.0, 0.01) var minimum_movement_energy_cost_multiplier: float = 0.20

## 当前持有的数据碎片；允许超过本次需求，选择后只扣除旧需求并把溢出保留到下一阶段。
var _current_fragments: float = 0.0
## 本局按获得顺序保存的协议 ID；允许重复项，每个重复项代表额外一层相同效果。
var _acquired_protocol_ids: Array[String] = []
## 当前待选的三个协议 ID；只有碎片达到需求后生成，关闭窗口不会刷新或丢失候选。
var _offer_ids: Array[String] = []
## 按协议 kind 汇总的叠加值；每次获得协议后重建，战斗高频查询不重复遍历定义表。
var _effect_totals: Dictionary = {}
## 存活碎片的未结算时间；每达到 5 秒结算 1 点，死亡期间不会增加。
var _survival_fragment_elapsed: float = 0.0
## 冲刺后临时减伤剩余时间；归零时移除玩家控制器上的独立减伤来源。
var _dodge_damage_reduction_remaining: float = 0.0
## 濒危护盾是否可以触发；生命恢复到阈值以上后重新武装，防止低血量持续刷新护盾。
var _low_health_shield_armed: bool = true
## 定时护盾记录；每项保存剩余值 amount、初始上限 maximum_amount 与 remaining，溢出治疗产生的多次护盾分别到期。
var _timed_shield_grants: Array[Dictionary] = []
## 是否正在主动移除到期护盾；用于阻止护盾自然到期被误判为受击破盾并触发震荡。
var _suppress_shield_break_effect: bool = false
## 最近一次观察到的护盾值；护盾受伤减少时用于先扣减限时来源剩余值，避免到期重复移除其他护盾。
var _last_observed_shield: float = 0.0
## 候选随机源；正常流程随机化，自动验证可通过 set_random_seed 固定结果。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 玩家根节点缓存；组件只依赖公开方法与信号，不要求具体脚本类型。
var _player: Node = null
## 战斗属性组件缓存；用于生命、能量、治疗与攻防暴击协议。
var _stats_component: Node = null
## 护盾组件缓存；用于濒危护盾、溢出治疗护盾和持盾增伤状态。
var _shield_component: Node = null
## 主动技能组件缓存；用于击杀时按比例缩短全部槽位当前剩余冷却。
var _active_skill_component: Node = null


func _ready() -> void:
	_random.randomize()
	_player = get_parent()
	_stats_component = get_node_or_null(stats_component_path)
	_shield_component = get_node_or_null(shield_component_path)
	_active_skill_component = get_node_or_null(active_skill_component_path)
	_last_observed_shield = maxf(float(_shield_component.get("current_shield")), 0.0) if _shield_component != null else 0.0
	_connect_runtime_signals()
	_rebuild_effect_totals()
	_apply_aggregate_effects()
	fragments_changed.emit(_current_fragments, get_required_fragments())


func _process(delta: float) -> void:
	_update_survival_fragments(delta)
	_update_temporary_effects(delta)


func set_random_seed(seed_value: int) -> void:
	## 固定候选随机种子；只影响后续新生成的三选一候选，不刷新已经存在的候选。
	_random.seed = seed_value


func add_fragments(amount: float) -> void:
	## 增加数据碎片并保留全部溢出；非正数请求不会改变进度或候选。
	if amount <= 0.0:
		return
	_current_fragments += amount
	_ensure_offer_ready()
	fragments_changed.emit(_current_fragments, get_required_fragments())


func notify_enemy_killed() -> void:
	## 结算一次本机确认击杀；碎片、回复与主动技能冷却协议共享同一个事实入口。
	add_fragments(HackProtocolRules.KILL_FRAGMENT_AMOUNT)
	# 本次击杀回复的能量值由已持有协议累计决定，零值表示没有对应收益。
	var energy_restore: float = _get_effect_total("kill_energy_restore")
	if energy_restore > 0.0:
		_restore_energy(energy_restore)
	# 本次击杀回复的生命值由协议累计决定，治疗上限和溢出量仍由属性组件统一结算。
	var health_restore: float = _get_effect_total("kill_health_restore")
	if health_restore > 0.0 and _stats_component != null and _stats_component.has_method("heal"):
		_stats_component.call("heal", health_restore)
	# 单层击杀冷却缩减比例取自统一平衡表，用于计算重复协议的乘算结果。
	var cooldown_reduction_per_stack: float = _get_definition_value("kill_skill_cooldown_reduction", "value")
	# 击杀冷却缩减协议层数决定本次结算次数，零层时不会访问主动技能组件。
	var cooldown_stack_count: int = _get_effect_stack_count("kill_skill_cooldown_reduction")
	if cooldown_stack_count > 0 and cooldown_reduction_per_stack > 0.0:
		_shorten_active_skill_cooldowns(pow(1.0 - clampf(cooldown_reduction_per_stack, 0.0, 1.0), cooldown_stack_count))


func notify_chest_opened() -> void:
	## 结算一次本机成功认领的宝箱；联机只有取得开启权的一端调用，因此每名玩家碎片保持独立。
	add_fragments(HackProtocolRules.CHEST_FRAGMENT_AMOUNT)


func is_offer_ready() -> bool:
	## 返回当前是否已经积满碎片并拥有可展示候选；溢出到下一阶段仍需先完成当前选择。
	return _current_fragments >= get_required_fragments() and not _offer_ids.is_empty()


func get_current_fragments() -> float:
	## 返回当前实际碎片，可能高于需求；HUD 应显示溢出数值但把进度条比例限制到 100%。
	return _current_fragments


func get_required_fragments() -> float:
	## 返回当前选择阶段需求；只按已经获得的协议总层数增长。
	return HackProtocolRules.get_fragment_requirement(_acquired_protocol_ids.size())


func get_offer_ids() -> Array[String]:
	## 返回当前候选副本；调用方不得直接修改组件内部选择状态。
	return _offer_ids.duplicate()


func get_acquired_protocol_ids() -> Array[String]:
	## 返回本局已获得协议副本；重复 ID 保留，用于同步层数与只读查看。
	return _acquired_protocol_ids.duplicate()


func get_acquired_protocol_count() -> int:
	## 返回本局协议总层数；多人模式用每名成员的该值计算团队平均数，不直接求和作为惩罚层级。
	return _acquired_protocol_ids.size()


func select_protocol(protocol_id: String) -> bool:
	## 从当前三个候选中获得一项协议；成功后扣除旧需求、保留溢出并按新需求准备下一批候选。
	if not is_offer_ready() or not _offer_ids.has(protocol_id):
		return false
	# 已支付需求在选择前读取，确保只扣除当前阶段门槛并完整保留超出的碎片。
	var paid_requirement: float = get_required_fragments()
	_current_fragments = maxf(_current_fragments - paid_requirement, 0.0)
	_acquired_protocol_ids.append(protocol_id)
	_offer_ids.clear()
	_rebuild_effect_totals()
	_apply_aggregate_effects()
	_ensure_offer_ready()
	fragments_changed.emit(_current_fragments, get_required_fragments())
	# 协议快照是独立副本，信号接收方无法通过修改数组污染组件内部权威状态。
	var protocol_snapshot: Array[String] = get_acquired_protocol_ids()
	protocols_changed.emit(protocol_snapshot)
	protocol_acquired.emit(protocol_id, _acquired_protocol_ids.size())
	return true


func get_weapon_modifier_snapshot() -> Dictionary:
	## 返回所有远程武器需要的离散协议增量；攻击组件在武器自身有效值之后加算。
	return {
		"bounce_bonus": roundi(_get_effect_total("weapon_bounce_bonus")),
		"piercing_bonus": roundi(_get_effect_total("weapon_piercing_bonus")),
		"combo_bonus": roundi(_get_effect_total("weapon_combo_bonus")),
		"scatter_bonus": roundi(_get_effect_total("weapon_scatter_bonus")),
	}


func get_dodge_energy_cost_multiplier() -> float:
	## 返回冲刺最终能耗倍率；每层降低 20%，但不会低于检查器配置的 20% 下限。
	return maxf(1.0 - _get_effect_total("dodge_energy_reduction"), minimum_movement_energy_cost_multiplier)


func get_sprint_energy_cost_multiplier() -> float:
	## 返回疾跑最终能耗倍率；每层降低 20%，但不会低于检查器配置的 20% 下限。
	return maxf(1.0 - _get_effect_total("sprint_energy_reduction"), minimum_movement_energy_cost_multiplier)


func get_miss_energy_refund_ratio() -> float:
	## 返回空弹能耗返还比例；重复协议加算但最高返还 100%，不会凭空产生额外能量。
	return clampf(_get_effect_total("miss_energy_refund"), 0.0, 1.0)


func refund_missed_projectile_energy(amount: float) -> void:
	## 接收单颗未命中敌人的分摊返还；弹体负责确保每颗只结算一次。
	_restore_energy(maxf(amount, 0.0))


func get_kill_drop_chance_multiplier() -> float:
	## 返回由本玩家击杀时的个人掉落倍率；只在主机权威怪物掉落链路按击杀归属应用。
	return 1.0 + maxf(_get_effect_total("kill_drop_chance_bonus"), 0.0)


func get_damage_multiplier_against(target: Node) -> float:
	## 返回目标相关伤害倍率；当前只处理低生命终结协议，其他造成伤害增益已写入玩家统一增伤来源。
	if target == null:
		return 1.0
	# 斩杀增伤协议层数决定是否读取目标生命状态，零层时直接返回中性倍率。
	var execute_stack_count: int = _get_effect_stack_count("execute_damage_bonus")
	if execute_stack_count <= 0:
		return 1.0
	# 目标最大生命值用于换算当前比例，异常或零上限值会安全回退为一。
	var maximum_health: float = maxf(float(target.get("max_health")), 1.0) if target.get("max_health") != null else 1.0
	# 目标当前生命值用于斩杀阈值判断，缺失属性时按满血处理以避免错误增伤。
	var current_health: float = maxf(float(target.get("current_health")), 0.0) if target.get("current_health") != null else maximum_health
	# 斩杀阈值来自协议平衡定义，数值表示目标最大生命值比例。
	var threshold: float = _get_definition_value("execute_damage_bonus", "threshold")
	if current_health / maximum_health >= threshold:
		return 1.0
	return 1.0 + _get_effect_total("execute_damage_bonus")


func is_critical_guaranteed_against(target: Node) -> bool:
	## 判断目标是否满足满血必暴条件；护盾不改变满血判断，生命值必须仍等于最大生命。
	if _get_effect_stack_count("full_health_guaranteed_critical") <= 0 or target == null:
		return false
	if target.get("current_health") == null or target.get("max_health") == null:
		return false
	return is_equal_approx(float(target.get("current_health")), float(target.get("max_health")))


func _connect_runtime_signals() -> void:
	## 连接玩家本地事实信号；组件销毁时 Godot 会自动断开，不跨局残留。
	if _player != null:
		if _player.has_signal("damage_received"):
			_player.connect("damage_received", Callable(self, "_on_player_damage_received"))
		if _player.has_signal("dodge_succeeded"):
			_player.connect("dodge_succeeded", Callable(self, "_on_player_dodge_succeeded"))
	if _stats_component != null:
		if _stats_component.has_signal("health_changed"):
			_stats_component.connect("health_changed", Callable(self, "_on_health_changed"))
		if _stats_component.has_signal("energy_changed"):
			_stats_component.connect("energy_changed", Callable(self, "_on_energy_changed"))
		if _stats_component.has_signal("healing_received"):
			_stats_component.connect("healing_received", Callable(self, "_on_healing_received"))
	if _shield_component != null:
		if _shield_component.has_signal("shield_changed"):
			_shield_component.connect("shield_changed", Callable(self, "_on_shield_changed"))
		if _shield_component.has_signal("shield_broken"):
			_shield_component.connect("shield_broken", Callable(self, "_on_shield_broken"))


func _update_survival_fragments(delta: float) -> void:
	## 只在玩家存活时累计保底碎片；暂停时组件随场景树停止，联机无暂停时仍按真实战斗时间推进。
	if _stats_component == null:
		return
	if _stats_component.has_method("is_dead") and bool(_stats_component.call("is_dead")):
		return
	_survival_fragment_elapsed += maxf(delta, 0.0)
	# 生存结算间隔来自统一规则，最低保护值防止错误配置造成无限循环。
	var interval: float = maxf(HackProtocolRules.SURVIVAL_FRAGMENT_INTERVAL_SECONDS, 0.01)
	while _survival_fragment_elapsed >= interval:
		_survival_fragment_elapsed -= interval
		add_fragments(HackProtocolRules.SURVIVAL_FRAGMENT_AMOUNT)


func _update_temporary_effects(delta: float) -> void:
	## 推进冲刺减伤和溢出治疗护盾的独立持续时间，不修改其他技能创建的同类来源。
	if _dodge_damage_reduction_remaining > 0.0:
		_dodge_damage_reduction_remaining = maxf(_dodge_damage_reduction_remaining - maxf(delta, 0.0), 0.0)
		if _dodge_damage_reduction_remaining <= 0.0 and _player != null and _player.has_method("remove_damage_reduction_source"):
			_player.call("remove_damage_reduction_source", "hack_protocol:dodge_reduction")
	for grant_index in range(_timed_shield_grants.size() - 1, -1, -1):
		# 当前限时护盾记录保存剩余护盾、初始容量和倒计时，修改后会回写原数组。
		var shield_grant: Dictionary = _timed_shield_grants[grant_index]
		shield_grant["remaining"] = maxf(float(shield_grant.get("remaining", 0.0)) - maxf(delta, 0.0), 0.0)
		if float(shield_grant.get("remaining", 0.0)) > 0.0:
			_timed_shield_grants[grant_index] = shield_grant
			continue
		_suppress_shield_break_effect = true
		if _shield_component != null and _shield_component.has_method("remove_temporary_shield"):
			_shield_component.call("remove_temporary_shield", maxf(float(shield_grant.get("amount", 0.0)), 0.0), maxf(float(shield_grant.get("maximum_amount", 0.0)), 0.0))
		elif _shield_component != null and _shield_component.has_method("remove_shield"):
			_shield_component.call("remove_shield", maxf(float(shield_grant.get("amount", 0.0)), 0.0), true)
		_suppress_shield_break_effect = false
		_timed_shield_grants.remove_at(grant_index)


func _ensure_offer_ready() -> void:
	## 碎片达到当前需求时生成一次候选；已有候选保持不变，避免关闭窗口或继续溢出导致刷词条。
	if _current_fragments < get_required_fragments() or not _offer_ids.is_empty():
		return
	_offer_ids = HackProtocolRules.roll_offer_ids(_random, HackProtocolRules.OFFER_COUNT)
	offer_ready.emit()


func _rebuild_effect_totals() -> void:
	## 按 kind 汇总全部已获得协议；定义中没有 value 的布尔或复杂效果按每层 1 计数。
	_effect_totals.clear()
	for protocol_id in _acquired_protocol_ids:
		# 当前协议定义提供稳定效果分类与单层数值，未知 ID 会被安全忽略。
		var protocol_definition: Dictionary = HackProtocolRules.get_protocol_definition(protocol_id)
		if protocol_definition.is_empty():
			continue
		# 效果类型是运行时聚合键，相同类型的重复协议会合并为一个缓存值。
		var effect_kind: String = str(protocol_definition.get("kind", ""))
		if effect_kind.is_empty():
			continue
		# 单层贡献默认按一计算，使没有 value 字段的布尔或复杂效果仍能统计层数。
		var contribution: float = float(protocol_definition.get("value", 1.0))
		_effect_totals[effect_kind] = float(_effect_totals.get(effect_kind, 0.0)) + contribution


func _apply_aggregate_effects() -> void:
	## 把可由现有组件公开来源承载的静态与条件效果整体覆盖，重复获得时不会对旧值重复乘算。
	if _stats_component != null and _stats_component.has_method("set_hack_protocol_bonuses"):
		_stats_component.call(
			"set_hack_protocol_bonuses",
			_get_effect_total("attack_power_bonus"),
			_get_effect_total("defense_power_bonus"),
			_get_effect_total("max_health_bonus"),
			_get_effect_total("max_energy_bonus"),
			_get_effect_total("critical_chance_bonus"),
			_get_effect_total("critical_damage_bonus")
		)
	if _player != null:
		if _player.has_method("set_movement_speed_multiplier_source"):
			_player.call("set_movement_speed_multiplier_source", "hack_protocol:move_speed", 1.0 + _get_effect_total("move_speed_bonus"))
		if _player.has_method("set_attack_speed_bonus_source"):
			_player.call("set_attack_speed_bonus_source", "hack_protocol:attack_speed", _get_effect_total("attack_speed_bonus"))
		if _player.has_method("set_outgoing_damage_bonus_source"):
			_player.call("set_outgoing_damage_bonus_source", "hack_protocol:outgoing_damage", _get_effect_total("outgoing_damage_bonus"))
		if _player.has_method("set_damage_reduction_source"):
			_player.call("set_damage_reduction_source", "hack_protocol:static_reduction", minf(_get_effect_total("damage_reduction"), maximum_static_damage_reduction_ratio))
	_refresh_health_condition_effects()
	_refresh_energy_condition_effects()
	_refresh_shield_condition_effects()


func _refresh_health_condition_effects() -> void:
	## 按当前生命比例刷新濒危攻速，并在首次跌破阈值时发放濒危护盾。
	if _stats_component == null:
		return
	# 玩家最大生命值用于稳定计算低生命比例，最低一避免除零。
	var maximum_health: float = maxf(float(_stats_component.get("max_health")), 1.0)
	# 玩家当前生命值被限制在合法区间，异常外部数值不会误触发条件效果。
	var current_health: float = clampf(float(_stats_component.get("current_health")), 0.0, maximum_health)
	# 当前低生命比例驱动攻速与护盾条件，生命变化时会即时重新计算。
	var low_health_ratio: float = current_health / maximum_health
	# 低生命攻速阈值来自对应协议定义，表示最大生命值比例。
	var low_attack_threshold: float = _get_definition_value("low_health_attack_speed", "threshold")
	# 低生命攻速加成只在阈值以下注入，恢复后立即归零且不改写基础属性。
	var low_attack_bonus: float = _get_effect_total("low_health_attack_speed") if low_health_ratio < low_attack_threshold else 0.0
	if _player != null and _player.has_method("set_attack_speed_bonus_source"):
		_player.call("set_attack_speed_bonus_source", "hack_protocol:low_health_attack_speed", low_attack_bonus)
	# 低生命护盾协议层数决定固定值和最大生命比例收益的线性叠加规模。
	var shield_stack_count: int = _get_effect_stack_count("low_health_shield")
	# 低生命护盾阈值来自统一平衡定义，恢复到该比例以上会重新武装触发器。
	var shield_threshold: float = _get_definition_value("low_health_shield", "threshold")
	if low_health_ratio >= shield_threshold:
		_low_health_shield_armed = true
	elif shield_stack_count > 0 and _low_health_shield_armed:
		_low_health_shield_armed = false
		# 护盾协议定义同时包含固定护盾值和最大生命比例，用于组合单层收益。
		var shield_definition: Dictionary = _get_definition_by_kind("low_health_shield")
		# 最终护盾量按协议层数线性叠加，重复获得时收益保持透明可预测。
		var shield_amount: float = (maxf(float(shield_definition.get("flat_value", 0.0)), 0.0) + maximum_health * maxf(float(shield_definition.get("max_health_ratio", 0.0)), 0.0)) * float(shield_stack_count)
		if shield_amount > 0.0 and _shield_component != null and _shield_component.has_method("add_shield"):
			_shield_component.call("add_shield", shield_amount, true)


func _refresh_energy_condition_effects() -> void:
	## 按当前能量比例刷新高能增伤；每次能量变化即时生效，不轮询武器状态。
	if _stats_component == null or _player == null or not _player.has_method("set_outgoing_damage_bonus_source"):
		return
	# 玩家最大能量用于计算当前资源比例，最低保护值避免异常配置除零。
	var maximum_energy: float = maxf(float(_stats_component.get("max_energy")), 0.1)
	# 当前能量比例被限制到零至一，实时资源变化会立即刷新增伤状态。
	var energy_ratio: float = clampf(float(_stats_component.get("current_energy")) / maximum_energy, 0.0, 1.0)
	# 高能量阈值来自协议定义，表示必须严格超过的最大能量比例。
	var threshold: float = _get_definition_value("high_energy_damage_bonus", "threshold")
	# 条件增伤比例仅在超过阈值时返回，未满足条件时保持零且不影响其他来源。
	var bonus_ratio: float = _get_effect_total("high_energy_damage_bonus") if energy_ratio > threshold else 0.0
	_player.call("set_outgoing_damage_bonus_source", "hack_protocol:high_energy_damage", bonus_ratio)


func _refresh_shield_condition_effects() -> void:
	## 按当前护盾是否大于 0 刷新持盾增伤；护盾来源不限于骇入协议。
	if _player == null or not _player.has_method("set_outgoing_damage_bonus_source"):
		return
	# 当前持盾状态通过护盾组件公开接口读取，组件缺失时安全视为无护盾。
	var has_shield: bool = _shield_component != null and _shield_component.has_method("has_shield") and bool(_shield_component.call("has_shield"))
	# 持盾增伤仅在有护盾时注入，护盾耗尽后立即移除该独立伤害来源。
	var bonus_ratio: float = _get_effect_total("shield_damage_bonus") if has_shield else 0.0
	_player.call("set_outgoing_damage_bonus_source", "hack_protocol:shield_damage", bonus_ratio)


func _on_health_changed(_current_health: float, _maximum_health: float) -> void:
	## 生命变化回调；只刷新依赖生命阈值的协议，不重复应用静态属性。
	_refresh_health_condition_effects()


func _on_energy_changed(_current_energy: float, _maximum_energy: float) -> void:
	## 能量变化回调；即时更新高能增伤门槛。
	_refresh_energy_condition_effects()


func _on_shield_changed(current_shield: float, _maximum_shield: float) -> void:
	## 护盾变化回调；即时更新持盾增伤，并把受伤消耗优先记到最早到期的限时护盾来源。
	if current_shield < _last_observed_shield and not _suppress_shield_break_effect:
		# 本次护盾减少量；按最早创建顺序扣除限时记录，剩余部分视为其他永久护盾承伤。
		var unassigned_consumption: float = _last_observed_shield - current_shield
		for grant_index in range(_timed_shield_grants.size()):
			if unassigned_consumption <= 0.0:
				break
			# 当前限时护盾记录；字典回写后到期只移除尚未被伤害消费的部分。
			var shield_grant: Dictionary = _timed_shield_grants[grant_index]
			# 当前来源剩余护盾；最低为 0。
			var grant_amount: float = maxf(float(shield_grant.get("amount", 0.0)), 0.0)
			# 分配给该来源的承伤；不会超过其剩余值。
			var consumed_from_grant: float = minf(grant_amount, unassigned_consumption)
			shield_grant["amount"] = grant_amount - consumed_from_grant
			_timed_shield_grants[grant_index] = shield_grant
			unassigned_consumption -= consumed_from_grant
	_last_observed_shield = maxf(current_shield, 0.0)
	_refresh_shield_condition_effects()


func _on_player_damage_received(final_damage: float, _source: Node) -> void:
	## 玩家未闪避并完成一次受伤结算后回复能量；护盾吸收仍属于实际受到攻击。
	if final_damage <= 0.0:
		return
	# 本次受伤回复能量值由协议层数累计，最终能量上限仍由属性组件处理。
	var energy_restore: float = _get_effect_total("damage_energy_restore")
	if energy_restore > 0.0:
		_restore_energy(energy_restore)


func _on_player_dodge_succeeded() -> void:
	## 成功冲刺后刷新临时减伤持续时间；重复触发只延长到完整时长，不叠加独立来源。
	# 冲刺减伤协议层数决定本次临时减伤规模，零层时不会写入玩家减伤来源。
	var stack_count: int = _get_effect_stack_count("dodge_damage_reduction")
	if stack_count <= 0 or _player == null or not _player.has_method("set_damage_reduction_source"):
		return
	# 冲刺减伤协议定义提供单层比例与持续时间，两项数值始终配套读取。
	var protocol_definition: Dictionary = _get_definition_by_kind("dodge_damage_reduction")
	# 临时减伤总比例按层数线性叠加，并受独立上限约束以避免协议内完全免伤。
	var reduction_ratio: float = clampf(float(protocol_definition.get("value", 0.0)) * float(stack_count), 0.0, maximum_dodge_damage_reduction_ratio)
	_dodge_damage_reduction_remaining = maxf(float(protocol_definition.get("duration", 0.0)), 0.0)
	_player.call("set_damage_reduction_source", "hack_protocol:dodge_reduction", reduction_ratio)


func _on_healing_received(_requested_amount: float, _restored_amount: float, overheal_amount: float) -> void:
	## 把本次实际溢出治疗的一部分转为定时护盾；没有溢出或未持有协议时不创建记录。
	if overheal_amount <= 0.0 or _shield_component == null or not _shield_component.has_method("add_shield"):
		return
	# 溢出治疗转盾协议层数决定转化比例，零层时不会生成护盾或计时记录。
	var stack_count: int = _get_effect_stack_count("overheal_to_shield")
	if stack_count <= 0:
		return
	# 转盾协议定义提供单层转化比例与护盾持续时间，所有层数共享相同持续时间。
	var protocol_definition: Dictionary = _get_definition_by_kind("overheal_to_shield")
	# 总转化比例按层数线性叠加并封顶为百分之百，避免护盾超过实际溢出治疗量。
	var conversion_ratio: float = clampf(float(protocol_definition.get("value", 0.0)) * float(stack_count), 0.0, 1.0)
	# 计划护盾值由本次实际溢出治疗乘转化比例得到，非正数不会建立来源记录。
	var shield_amount: float = overheal_amount * conversion_ratio
	if shield_amount <= 0.0:
		return
	# 实际新增护盾值由护盾组件返回，计时器只追踪真正加入的部分。
	var added_amount: float = float(_shield_component.call("add_shield", shield_amount, true))
	if added_amount > 0.0:
		_timed_shield_grants.append({"amount": added_amount, "maximum_amount": added_amount, "remaining": maxf(float(protocol_definition.get("duration", 0.0)), 0.0)})


func _on_shield_broken() -> void:
	## 受击破盾时向周围敌人施加径向击退；主动到期移除护盾不会触发该效果。
	if _suppress_shield_break_effect:
		return
	# 护盾击破协议层数决定理论击退距离，零层时不会扫描场景中的敌人。
	var stack_count: int = _get_effect_stack_count("shield_break_knockback")
	if stack_count <= 0 or _player == null or not (_player is Node2D):
		return
	# 护盾击破协议定义提供作用半径与单层击退距离，集中维护全部平衡参数。
	var protocol_definition: Dictionary = _get_definition_by_kind("shield_break_knockback")
	# 击退扫描半径决定受影响敌人范围，单位为 Godot 世界坐标像素。
	var radius: float = maxf(float(protocol_definition.get("radius", 0.0)), 0.0)
	# 理论击退距离按层数线性叠加，随后按敌人衰减参数反推初速度。
	var theoretical_distance: float = maxf(float(protocol_definition.get("force", 0.0)), 0.0) * float(stack_count)
	# 玩家世界坐标作为径向击退中心，使命中敌人统一向外移动。
	var player_position: Vector2 = (_player as Node2D).global_position
	for raw_enemy in get_tree().get_nodes_in_group(enemy_group):
		# 当前敌人节点必须是有效空间节点且位于半径内，其他节点会被安全忽略。
		var enemy: Node2D = raw_enemy as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.global_position.distance_to(player_position) > radius:
			continue
		# 径向方向从玩家指向敌人，重合位置或无击退接口的目标不会参与结算。
		var knockback_direction: Vector2 = (enemy.global_position - player_position).normalized()
		if knockback_direction.is_zero_approx() or not enemy.has_method("apply_knockback"):
			continue
		# 怪物击退衰减优先读取公开接口，缺失时使用与基础怪物一致的安全默认值。
		var knockback_decay: float = float(enemy.call("get_knockback_decay")) if enemy.has_method("get_knockback_decay") else 1800.0
		# 初始速度依据线性衰减位移公式反推，使不同怪物获得相近的设计击退距离。
		var initial_speed: float = sqrt(2.0 * maxf(knockback_decay, 1.0) * theoretical_distance)
		enemy.call("apply_knockback", knockback_direction, initial_speed)


func _shorten_active_skill_cooldowns(remaining_multiplier: float) -> void:
	## 按同一剩余倍率缩短全部主动技能槽；0.9 表示当前剩余冷却保留 90%。
	if _active_skill_component == null or not _active_skill_component.has_method("get_slot_count") or not _active_skill_component.has_method("scale_cooldown_remaining"):
		return
	for slot_index in range(int(_active_skill_component.call("get_slot_count"))):
		_active_skill_component.call("scale_cooldown_remaining", slot_index, maxf(remaining_multiplier, 0.0))


func _restore_energy(amount: float) -> void:
	## 通过属性组件统一入口恢复能量；能量上限、0.1 精度与无限能量规则仍由属性组件负责。
	if amount <= 0.0 or _stats_component == null or not _stats_component.has_method("set_energy"):
		return
	_stats_component.call("set_energy", float(_stats_component.get("current_energy")) + amount)


func _get_effect_total(effect_kind: String) -> float:
	## 返回指定 kind 的缓存叠加值；未知类型保持 0。
	return maxf(float(_effect_totals.get(effect_kind, 0.0)), 0.0)


func _get_effect_stack_count(effect_kind: String) -> int:
	## 返回指定 kind 的协议层数；复杂效果不能用 value 汇总值代替层数。
	# 目标效果层数从零开始逐项计数，重复协议各贡献一层。
	var stack_count: int = 0
	for protocol_id in _acquired_protocol_ids:
		if str(HackProtocolRules.get_protocol_definition(protocol_id).get("kind", "")) == effect_kind:
			stack_count += 1
	return stack_count


func _get_definition_by_kind(effect_kind: String) -> Dictionary:
	## 返回指定 kind 的首个规则定义；当前每个 kind 唯一，未知类型返回空字典。
	for protocol_definition in HackProtocolRules.get_protocol_definitions():
		if str(protocol_definition.get("kind", "")) == effect_kind:
			return protocol_definition
	return {}


func _get_definition_value(effect_kind: String, field_name: String) -> float:
	## 返回复杂协议定义中的单个浮点字段；缺失字段安全回退 0。
	return float(_get_definition_by_kind(effect_kind).get(field_name, 0.0))
