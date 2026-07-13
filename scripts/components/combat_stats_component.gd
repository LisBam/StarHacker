extends Node
class_name CombatStatsComponent

## 战斗属性组件管理玩家生命值、能量值和能量恢复。
## 其他系统只通过 can_spend_energy、spend_energy、heal、take_damage 访问属性，避免直接改内部变量。
## UI 通过信号同步显示，不需要轮询玩家节点。

signal health_changed(current_health: float, max_health: float)
## 生命实际恢复信号；只在正数治疗确实提高当前生命时派发实际恢复量，玩家视觉反馈不会显示溢出治疗。
signal healed(amount: float)
signal energy_changed(current_energy: float, max_energy: float)
signal stats_changed
## 能量实际消费信号；每次成功扣除正数能量时派发，限时技能可精确统计期间总消耗而不受自然恢复影响。
signal energy_spent(amount: float)
## 死亡信号；生命首次降到 0 时派发一次，HUD 用它进入死亡暂停界面。
signal died

## 能量数值量化精度；固定为 0.1 点，所有运行时能量写入均按此精度对齐，避免逐帧恢复累积浮点残差。
const ENERGY_VALUE_PRECISION: float = 0.1

## 最大生命值；取值应大于 0，默认 100 作为基础玩家血量，运行时修改会影响生命条上限。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_health: float = 100.0
## 当前生命值；取值会被限制在 0 到 max_health，默认 100 表示满血开局，运行时修改会影响玩家当前生存状态。
@export_range(0.0, 9999.0, 1.0, "or_greater") var current_health: float = 100.0
## 最大能量值；取值应大于 0，默认 100，支持 0.1 精度以配合精细资源配置，运行时修改会影响能量条上限。
@export_range(0.1, 9999.0, 0.1, "or_greater") var max_energy: float = 100.0
## 当前能量值；取值会被限制并量化到 0 至 max_energy 的 0.1 精度，默认 100 表示满能量开局，运行时修改会影响武器可用性。
@export_range(0.0, 9999.0, 0.1, "or_greater") var current_energy: float = 100.0
## 每秒能量恢复量；取值建议大于等于 0，默认 15，支持 0.1 精度并与装备、消耗品恢复直接相加。
@export_range(0.0, 9999.0, 0.1, "or_greater") var energy_regeneration_per_second: float = 15.0
## 玩家攻击力；默认 100，与 C=100、目标防御 0 组合时保持武器原始伤害不变，装备可在运行时叠加。
@export_range(0.0, 99999.0, 1.0, "or_greater") var attack_power: float = 100.0
## 玩家防御力；默认 0，不改变当前敌人伤害，装备可在运行时叠加并降低受到的最终伤害。
@export_range(0.0, 99999.0, 1.0, "or_greater") var defense_power: float = 0.0
## 玩家暴击率；默认 0，实际攻击优先使用当前武器暴击率。
@export_range(0.0, 1.0, 0.01) var critical_chance: float = 0.0
## 玩家暴击伤害倍率；默认 1.5 表示暴击造成 150% 伤害。
@export_range(1.0, 10.0, 0.05, "or_greater") var critical_damage: float = 1.5
## 是否启用无限血量；取值为 true/false，默认 false，训练场设置会运行时修改，启用后受伤不会降低生命。
@export var infinite_health: bool = false
## 是否启用无限能量；取值为 true/false，默认 false，训练场设置会运行时修改，启用后消耗能量不会降低能量。
@export var infinite_energy: bool = false

## 当前是否已经进入死亡状态；默认 false，生命归零后置为 true，避免死亡信号在连续伤害中重复派发。
var _is_dead: bool = false
## 装备攻击力加成；默认 0，由装备组件在装备变化时整体覆盖。
var _equipment_attack_power: float = 0.0
## 装备防御力加成；默认 0，由装备组件整体覆盖。
var _equipment_defense_power: float = 0.0
## 装备最大生命加成；默认 0，变化时保持当前生命比例。
var _equipment_max_health: float = 0.0
## 装备每 5 秒回血值；默认 0，每个完整周期结算一次。
var _equipment_health_regeneration_per_five_seconds: float = 0.0
## 装备每秒能量恢复加成；默认 0，由有效躯干装备整体覆盖并叠加到基础恢复速度。
var _equipment_energy_regeneration: float = 0.0
## 能量自然恢复阻止来源表；键为稳定来源 ID、值为 true，任一来源存在时暂停自然回能但不影响主动耗能与无限能量。
var _energy_regeneration_blocked_sources: Dictionary = {}
## 能量自然恢复未结算余数；默认 0，累计不足 0.1 点的逐帧恢复，保证状态量化后长期恢复速率仍精确等于配置值。
var _energy_regeneration_remainder: float = 0.0
## 装备闪避率；默认 0，受到攻击时由玩家控制器独立判定。
var _equipment_dodge_chance: float = 0.0
## 装备暴击率加成；默认 0，与当前武器暴击率相加。
var _equipment_critical_chance: float = 0.0
## 装备暴击伤害倍率增量；默认 0，叠加到武器基础暴击伤害。
var _equipment_critical_damage: float = 0.0
## 生命恢复累计时间；默认 0，达到 5 秒后结算装备回血。
var _health_regeneration_elapsed: float = 0.0
## 技能攻防倍率来源；键为技能稳定 ID，值为包含 attack 与 defense 比例的字典，多个被动来源分别连乘生效。
var _skill_stat_multipliers: Dictionary = {}
## 技能固定攻防加成来源；键为稳定来源 ID，值保存 attack 与 defense 点数，多个来源直接相加。
var _skill_flat_stat_bonuses: Dictionary = {}
## 消耗品临时闪避率；默认 0，使用 0 至 1 小数表示百分点，由 TemporaryBuffComponent 整体覆盖且不写入装备属性。
var _temporary_dodge_chance: float = 0.0
## 消耗品临时每秒能量恢复；默认 0，由 TemporaryBuffComponent 整体覆盖并与角色基础、装备恢复直接相加。
var _temporary_energy_regeneration: float = 0.0
## 装备套装最终属性倍率；键为角色属性名、值为额外比例，默认空字典，由装备组件整体覆盖且不写入基础或装备点数。
var _equipment_set_stat_multipliers: Dictionary = {}


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	current_energy = snappedf(clampf(current_energy, 0.0, max_energy), ENERGY_VALUE_PRECISION)
	if infinite_health:
		current_health = max_health
	if infinite_energy:
		current_energy = max_energy
	_is_dead = current_health <= 0.0
	_emit_all_stats_changed()


func _process(delta: float) -> void:
	_health_regeneration_elapsed += maxf(delta, 0.0)
	while _health_regeneration_elapsed >= 5.0:
		_health_regeneration_elapsed -= 5.0
		if _equipment_health_regeneration_per_five_seconds > 0.0 and current_health > 0.0:
			heal(_equipment_health_regeneration_per_five_seconds)
	if infinite_energy:
		_energy_regeneration_remainder = 0.0
		set_energy(max_energy)
		return
	if not _energy_regeneration_blocked_sources.is_empty():
		# 自然回能阻止；疾跑等持续主动耗能期间不与回能相抵，解除全部来源后下一帧恢复原有结算。
		_energy_regeneration_remainder = 0.0
		return

	# 当前每秒能量恢复；基础值与装备加成直接相加，每 1 点装备属性对应每秒额外恢复 1 点能量。
	var effective_energy_regeneration: float = maxf(energy_regeneration_per_second + _equipment_energy_regeneration + _temporary_energy_regeneration, 0.0)
	if effective_energy_regeneration <= 0.0 or current_energy >= max_energy:
		return

	# 本帧累计恢复量；先累积不可见余数，再只结算完整 0.1 点，避免逐帧量化改变长期每秒恢复速度。
	var accumulated_regeneration: float = _energy_regeneration_remainder + effective_energy_regeneration * maxf(delta, 0.0)
	# 本帧可结算恢复量；向下对齐到 0.1 点，确保写入状态始终符合能量精度协议。
	var settled_regeneration: float = floorf(accumulated_regeneration / ENERGY_VALUE_PRECISION) * ENERGY_VALUE_PRECISION
	_energy_regeneration_remainder = accumulated_regeneration - settled_regeneration
	if settled_regeneration <= 0.0:
		return
	# 本帧恢复后的能量值；接近上限时 set_energy 会夹取，剩余未结算量不跨满能状态保留。
	set_energy(current_energy + settled_regeneration)
	if current_energy >= max_energy:
		_energy_regeneration_remainder = 0.0


func can_spend_energy(amount: float) -> bool:
	if infinite_energy:
		return true

	return amount <= 0.0 or current_energy + ENERGY_VALUE_PRECISION * 0.001 >= amount


func spend_energy(amount: float) -> bool:
	if infinite_energy:
		set_energy(max_energy)
		return true

	if amount <= 0.0:
		return true

	if not can_spend_energy(amount):
		return false

	set_energy(current_energy - amount)
	energy_spent.emit(amount)
	return true


func set_energy(value: float) -> void:
	# 标准化后的能量值；取值限制在 0 到 max_energy，默认由传入值夹取，修改会影响信号派发前的最终能量。
	var clamped_energy: float = snappedf(clampf(value, 0.0, max_energy), ENERGY_VALUE_PRECISION)
	if is_equal_approx(clamped_energy, current_energy):
		return

	current_energy = clamped_energy
	energy_changed.emit(current_energy, max_energy)
	stats_changed.emit()


func configure_max_stats(new_max_health: float, new_max_energy: float) -> void:
	# 标准化后的最大生命；取值至少为 1，默认由角色配置随机得出，修改会影响生命上限和满血值。
	var resolved_max_health: float = maxf(new_max_health, 1.0)
	# 标准化后的最大能量；取值至少为 1，默认由角色配置随机得出，修改会影响能量上限和满能量值。
	var resolved_max_energy: float = maxf(new_max_energy, 1.0)
	max_health = resolved_max_health + _equipment_max_health
	max_energy = resolved_max_energy
	current_health = max_health
	current_energy = max_energy
	_is_dead = false
	_emit_all_stats_changed()


func configure_character_base_stats(new_max_health: float, new_max_energy: float, new_attack_power: float, new_defense_power: float) -> void:
	## 配置角色基础战斗属性并保留当前装备加成；进入场景和训练场切换角色时使用该入口。
	attack_power = maxf(new_attack_power, 0.0)
	defense_power = maxf(new_defense_power, 0.0)
	configure_max_stats(new_max_health, new_max_energy)


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	if infinite_health:
		set_health(max_health)
		return

	set_health(current_health - amount)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	# 治疗前生命值；用于扣除上限溢出并只反馈本次真实增加量。
	var previous_health: float = current_health
	set_health(current_health + amount)
	# 实际恢复量；满血治疗固定为 0，不生成误导性的绿色飘字。
	var restored_health: float = maxf(current_health - previous_health, 0.0)
	if restored_health > 0.0:
		healed.emit(restored_health)


func set_health(value: float) -> void:
	# 标准化后的生命值；取值限制在 0 到 max_health，默认由传入值夹取，修改会影响信号派发前的最终生命。
	var clamped_health: float = clampf(value, 0.0, max_health)
	if is_equal_approx(clamped_health, current_health):
		_update_death_state()
		return

	current_health = clamped_health
	health_changed.emit(current_health, max_health)
	stats_changed.emit()
	_update_death_state()


func get_health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


func get_energy_ratio() -> float:
	return current_energy / max_energy if max_energy > 0.0 else 0.0


func set_infinite_health(enabled: bool) -> void:
	infinite_health = enabled
	if infinite_health:
		set_health(max_health)


func set_infinite_energy(enabled: bool) -> void:
	infinite_energy = enabled
	if infinite_energy:
		set_energy(max_energy)


func set_energy_regeneration_blocked_source(source_id: String, blocked: bool) -> void:
	## 设置一个独立的自然能量恢复阻止来源；相同来源重复写入保持幂等，所有来源清除后才恢复每秒能量结算。
	# 标准化来源 ID；空字符串不具备稳定所有权，直接忽略以避免无法清理的阻止状态。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	if blocked:
		_energy_regeneration_blocked_sources[normalized_source_id] = true
	else:
		_energy_regeneration_blocked_sources.erase(normalized_source_id)


func is_infinite_health_enabled() -> bool:
	return infinite_health


func is_infinite_energy_enabled() -> bool:
	return infinite_energy


func is_dead() -> bool:
	return _is_dead


func get_attack_power() -> float:
	return maxf((attack_power + _equipment_attack_power) * _get_equipment_set_stat_multiplier("attack_power") * _get_combined_skill_multiplier("attack") + _get_combined_skill_flat_bonus("attack"), 0.0)


func get_defense_power() -> float:
	return maxf((defense_power + _equipment_defense_power) * _get_equipment_set_stat_multiplier("defense_power") * _get_combined_skill_multiplier("defense") + _get_combined_skill_flat_bonus("defense"), 0.0)


func set_skill_flat_stat_bonus(source_id: String, attack_bonus: float, defense_bonus: float) -> void:
	## 设置单个技能来源的固定攻防点数；相同来源覆盖旧值，负值按 0 处理。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	_skill_flat_stat_bonuses[normalized_source_id] = {"attack": maxf(attack_bonus, 0.0), "defense": maxf(defense_bonus, 0.0)}
	stats_changed.emit()


func remove_skill_flat_stat_bonus(source_id: String) -> void:
	## 移除指定固定攻防来源；不存在时保持幂等。
	if _skill_flat_stat_bonuses.erase(source_id.strip_edges()):
		stats_changed.emit()


func _get_combined_skill_flat_bonus(stat_name: String) -> float:
	## 累加全部技能固定点数；未知属性名没有贡献。
	var combined_bonus: float = 0.0
	for raw_bonus in _skill_flat_stat_bonuses.values():
		if raw_bonus is Dictionary:
			combined_bonus += maxf(float((raw_bonus as Dictionary).get(stat_name, 0.0)), 0.0)
	return combined_bonus


func set_equipment_set_stat_multipliers(multipliers: Dictionary) -> void:
	## 整体覆盖当前有效套装最终属性比例；装备变化时重新计算，损坏部件会立即使对应门槛失效。
	_equipment_set_stat_multipliers = multipliers.duplicate(true)
	stats_changed.emit()


func _get_equipment_set_stat_multiplier(stat_name: String) -> float:
	## 返回指定属性的最终套装倍率；字典值 0.2 转换为 1.2，异常低于-100%的配置限制到0倍。
	return maxf(1.0 + float(_equipment_set_stat_multipliers.get(stat_name, 0.0)), 0.0)


func set_skill_stat_multiplier(source_id: String, attack_bonus_ratio: float, defense_bonus_ratio: float) -> void:
	## 设置单个技能来源的攻防比例；相同来源覆盖旧值，不会与自身重复叠加，负值按 0 处理。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	# 新倍率来源；比例以 0.20 表示提高 20%，最终总倍率由所有来源的 1+比例连乘。
	var new_multiplier: Dictionary = {
		"attack": maxf(attack_bonus_ratio, 0.0),
		"defense": maxf(defense_bonus_ratio, 0.0),
	}
	# 旧倍率来源；值完全相同时不派发刷新，避免高频视野计数持续重建角色面板。
	var previous_multiplier: Dictionary = _skill_stat_multipliers.get(normalized_source_id, {}) as Dictionary
	if previous_multiplier == new_multiplier:
		return
	_skill_stat_multipliers[normalized_source_id] = new_multiplier
	stats_changed.emit()


func remove_skill_stat_multiplier(source_id: String) -> void:
	## 移除指定技能来源；不存在时保持幂等，角色切换只清理对应被动而不影响其他技能。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty() or not _skill_stat_multipliers.has(normalized_source_id):
		return
	_skill_stat_multipliers.erase(normalized_source_id)
	stats_changed.emit()


func clear_skill_stat_multipliers() -> void:
	## 清空全部技能倍率；角色完整重配时使用，装备属性与角色基础值不会被修改。
	if _skill_stat_multipliers.is_empty():
		return
	_skill_stat_multipliers.clear()
	stats_changed.emit()


func get_skill_stat_bonus_ratio(stat_name: String) -> float:
	## 返回所有技能倍率相对 1 的综合增幅；例如单一 20% 来源返回 0.20，供角色属性面板归入技能值展示。
	return maxf(_get_combined_skill_multiplier(stat_name) - 1.0, 0.0)


func _get_combined_skill_multiplier(stat_name: String) -> float:
	## 连乘全部技能来源；未知属性名没有来源值并保持 1 倍。
	var combined_multiplier: float = 1.0
	for raw_multiplier in _skill_stat_multipliers.values():
		if raw_multiplier is Dictionary:
			combined_multiplier *= 1.0 + maxf(float((raw_multiplier as Dictionary).get(stat_name, 0.0)), 0.0)
	return maxf(combined_multiplier, 0.0)


func get_character_attribute_snapshot() -> Dictionary:
	## 返回角色面板所需的基础值、有效装备值与总值，UI 无需访问组件私有字段或复制战斗计算公式。
	# 基础生命上限；从当前总生命上限扣除装备加成，最低保持 1。
	var base_max_health: float = maxf(max_health - _equipment_max_health, 1.0)
	return {
		"current_health": current_health,
		"max_health": _build_attribute_snapshot(base_max_health, _equipment_max_health),
		"max_energy": _build_attribute_snapshot(max_energy, 0.0),
		"attack_power": _build_skill_attribute_snapshot(attack_power, _equipment_attack_power, "attack"),
		"defense_power": _build_skill_attribute_snapshot(defense_power, _equipment_defense_power, "defense"),
		"health_regeneration_per_five_seconds": _build_attribute_snapshot(0.0, _equipment_health_regeneration_per_five_seconds),
		"dodge_chance": _build_attribute_snapshot(0.0, _equipment_dodge_chance, _temporary_dodge_chance),
		"energy_regeneration": _build_attribute_snapshot(energy_regeneration_per_second, _equipment_energy_regeneration, _temporary_energy_regeneration)
	}


func _build_attribute_snapshot(base_value: float, equipment_value: float, temporary_value: float = 0.0) -> Dictionary:
	## 构建统一属性结构；临时值单独保留，角色面板可准确标注消耗品贡献而不误归入装备。
	return {
		"base": base_value,
		"equipment": equipment_value,
		"temporary": temporary_value,
		"total": maxf(base_value + equipment_value + temporary_value, 0.0)
	}


func _build_skill_attribute_snapshot(base_value: float, equipment_value: float, stat_name: String) -> Dictionary:
	## 构建含套装与技能倍率的属性结构；两类乘算贡献独立保存，面板不会误标为装备点数。
	# 套装属性名；技能内部使用 attack/defense，套装倍率字典使用完整角色属性名。
	var equipment_set_stat_name: String = "attack_power" if stat_name == "attack" else "defense_power"
	# 基础与装备合计；套装最终倍率在其上乘算，直接装备点数保持可追溯。
	var base_and_equipment_value: float = maxf(base_value + equipment_value, 0.0)
	# 套装额外值；由倍率后的结果减原合计得到，拾荒者两件套防御在此单独显示。
	var equipment_set_bonus_value: float = base_and_equipment_value * (_get_equipment_set_stat_multiplier(equipment_set_stat_name) - 1.0)
	# 技能倍率前数值；已经包含套装最终倍率，随后由全部被动技能比例连乘。
	var pre_skill_value: float = base_and_equipment_value + equipment_set_bonus_value
	# 技能额外值；用最终值减倍率前数值得出，面板兼容原“基础+额外”结构。
	var skill_bonus_value: float = pre_skill_value * get_skill_stat_bonus_ratio(stat_name)
	return {
		"base": base_value,
		"equipment": equipment_value,
		"set": equipment_set_bonus_value,
		"skill": skill_bonus_value,
		"total": pre_skill_value + skill_bonus_value,
	}


func get_dodge_chance() -> float:
	return clampf(_equipment_dodge_chance + _temporary_dodge_chance, 0.0, EnhancementRules.DODGE_CHANCE_MAXIMUM)


func set_temporary_buff_attributes(dodge_chance_bonus: float, energy_regeneration_bonus: float) -> void:
	## 整体覆盖消耗品提供的临时属性；持续时间由独立组件维护，归零时传入 0 即可恢复基础与装备结果。
	_temporary_dodge_chance = clampf(dodge_chance_bonus, 0.0, EnhancementRules.DODGE_CHANCE_MAXIMUM)
	_temporary_energy_regeneration = maxf(energy_regeneration_bonus, 0.0)
	stats_changed.emit()


func get_equipment_critical_chance() -> float:
	return clampf(_equipment_critical_chance, 0.0, EnhancementRules.CRITICAL_CHANCE_MAXIMUM)


func get_equipment_critical_damage() -> float:
	# 暴击伤害增量允许为负且不设置上限，使装备削弱词条能正确降低武器暴击倍率。
	return _equipment_critical_damage


func apply_equipment_attributes(attributes: Dictionary) -> void:
	# 旧生命上限；用于在装备变化时保持当前生命比例而不是直接补满。
	var old_max_health: float = maxf(max_health, 1.0)
	# 基础生命上限；从当前总值扣除旧装备加成，防止重复刷新时不断叠加。
	var base_max_health: float = maxf(max_health - _equipment_max_health, 1.0)
	_equipment_attack_power = maxf(float(attributes.get("attack_power", 0.0)), 0.0)
	_equipment_defense_power = maxf(float(attributes.get("defense_power", 0.0)), 0.0)
	_equipment_max_health = maxf(float(attributes.get("max_health", 0.0)), 0.0)
	_equipment_health_regeneration_per_five_seconds = maxf(float(attributes.get("health_regeneration_per_five_seconds", 0.0)), 0.0)
	_equipment_energy_regeneration = maxf(float(attributes.get("energy_regeneration", 0.0)), 0.0)
	_equipment_dodge_chance = clampf(float(attributes.get("dodge_chance", 0.0)), 0.0, EnhancementRules.DODGE_CHANCE_MAXIMUM)
	_equipment_critical_chance = clampf(float(attributes.get("critical_chance", 0.0)), 0.0, EnhancementRules.CRITICAL_CHANCE_MAXIMUM)
	# 装备暴击伤害增量；保留负值且不设置上限，最终与武器暴击伤害直接相加。
	_equipment_critical_damage = float(attributes.get("critical_damage", 0.0))
	max_health = base_max_health + _equipment_max_health
	current_health = clampf(current_health * max_health / old_max_health, 0.0, max_health)
	_emit_all_stats_changed()


func _emit_all_stats_changed() -> void:
	health_changed.emit(current_health, max_health)
	energy_changed.emit(current_energy, max_energy)
	stats_changed.emit()


func _update_death_state() -> void:
	if infinite_health:
		_is_dead = false
		return

	if current_health > 0.0:
		_is_dead = false
		return

	if _is_dead:
		return

	_is_dead = true
	died.emit()
