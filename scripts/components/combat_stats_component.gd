extends Node
class_name CombatStatsComponent

## 战斗属性组件管理玩家生命值、能量值和能量恢复。
## 其他系统只通过 can_spend_energy、spend_energy、heal、take_damage 访问属性，避免直接改内部变量。
## UI 通过信号同步显示，不需要轮询玩家节点。

signal health_changed(current_health: float, max_health: float)
signal energy_changed(current_energy: float, max_energy: float)
signal stats_changed
## 死亡信号；生命首次降到 0 时派发一次，HUD 用它进入死亡暂停界面。
signal died

## 最大生命值；取值应大于 0，默认 100 作为基础玩家血量，运行时修改会影响生命条上限。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_health: float = 100.0
## 当前生命值；取值会被限制在 0 到 max_health，默认 100 表示满血开局，运行时修改会影响玩家当前生存状态。
@export_range(0.0, 9999.0, 1.0, "or_greater") var current_health: float = 100.0
## 最大能量值；取值应大于 0，默认 100 作为基础技能资源上限，运行时修改会影响能量条上限。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_energy: float = 100.0
## 当前能量值；取值会被限制在 0 到 max_energy，默认 100 表示满能量开局，运行时修改会影响武器可用性。
@export_range(0.0, 9999.0, 1.0, "or_greater") var current_energy: float = 100.0
## 每秒能量恢复量；取值建议大于等于 0，默认 18 让原型战斗保持节奏，运行时修改会影响持续作战能力。
@export_range(0.0, 9999.0, 0.1, "or_greater") var energy_regeneration_per_second: float = 18.0
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
## 装备闪避率；默认 0，受到攻击时由玩家控制器独立判定。
var _equipment_dodge_chance: float = 0.0
## 装备暴击率加成；默认 0，与当前武器暴击率相加。
var _equipment_critical_chance: float = 0.0
## 装备暴击伤害倍率增量；默认 0，叠加到武器基础暴击伤害。
var _equipment_critical_damage: float = 0.0
## 生命恢复累计时间；默认 0，达到 5 秒后结算装备回血。
var _health_regeneration_elapsed: float = 0.0


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	current_energy = clampf(current_energy, 0.0, max_energy)
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
		set_energy(max_energy)
		return

	if energy_regeneration_per_second <= 0.0 or current_energy >= max_energy:
		return

	# 本帧恢复后的能量值；取值限制在 0 到 max_energy，默认由恢复速度和 delta 计算，修改会影响能量自然回复结果。
	var regenerated_energy: float = minf(current_energy + energy_regeneration_per_second * delta, max_energy)
	set_energy(regenerated_energy)


func can_spend_energy(amount: float) -> bool:
	if infinite_energy:
		return true

	return amount <= 0.0 or current_energy >= amount


func spend_energy(amount: float) -> bool:
	if infinite_energy:
		set_energy(max_energy)
		return true

	if amount <= 0.0:
		return true

	if not can_spend_energy(amount):
		return false

	set_energy(current_energy - amount)
	return true


func set_energy(value: float) -> void:
	# 标准化后的能量值；取值限制在 0 到 max_energy，默认由传入值夹取，修改会影响信号派发前的最终能量。
	var clamped_energy: float = clampf(value, 0.0, max_energy)
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
	max_health = resolved_max_health
	max_energy = resolved_max_energy
	current_health = max_health
	current_energy = max_energy
	_is_dead = false
	_emit_all_stats_changed()


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

	set_health(current_health + amount)


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


func is_infinite_health_enabled() -> bool:
	return infinite_health


func is_infinite_energy_enabled() -> bool:
	return infinite_energy


func is_dead() -> bool:
	return _is_dead


func get_attack_power() -> float:
	return maxf(attack_power + _equipment_attack_power, 0.0)


func get_defense_power() -> float:
	return maxf(defense_power + _equipment_defense_power, 0.0)


func get_dodge_chance() -> float:
	return clampf(_equipment_dodge_chance, 0.0, 1.0)


func get_equipment_critical_chance() -> float:
	return maxf(_equipment_critical_chance, 0.0)


func get_equipment_critical_damage() -> float:
	return maxf(_equipment_critical_damage, 0.0)


func apply_equipment_attributes(attributes: Dictionary) -> void:
	# 旧生命上限；用于在装备变化时保持当前生命比例而不是直接补满。
	var old_max_health: float = maxf(max_health, 1.0)
	# 基础生命上限；从当前总值扣除旧装备加成，防止重复刷新时不断叠加。
	var base_max_health: float = maxf(max_health - _equipment_max_health, 1.0)
	_equipment_attack_power = maxf(float(attributes.get("attack_power", 0.0)), 0.0)
	_equipment_defense_power = maxf(float(attributes.get("defense_power", 0.0)), 0.0)
	_equipment_max_health = maxf(float(attributes.get("max_health", 0.0)), 0.0)
	_equipment_health_regeneration_per_five_seconds = maxf(float(attributes.get("health_regeneration_per_five_seconds", 0.0)), 0.0)
	_equipment_dodge_chance = clampf(float(attributes.get("dodge_chance", 0.0)), 0.0, 1.0)
	_equipment_critical_chance = maxf(float(attributes.get("critical_chance", 0.0)), 0.0)
	_equipment_critical_damage = maxf(float(attributes.get("critical_damage", 0.0)), 0.0)
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
