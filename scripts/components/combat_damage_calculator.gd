extends RefCounted
class_name CombatDamageCalculator

## 战斗伤害计算器集中执行攻防、暴击和最终取整规则。

## 攻防公式平滑常数；固定为 100。
const DEFENSE_SMOOTHING_CONSTANT: float = 100.0


static func calculate_damage(raw_damage: float, attack_power: float, defense_power: float, critical_chance: float, critical_damage_multiplier: float, increased_damage_multipliers: Array = [], reduced_damage_multipliers: Array = [], random_value: float = -1.0) -> Dictionary:
	# 随机判定值；外部未传入时每次伤害独立随机。
	var resolved_random_value: float = randf() if random_value < 0.0 else clampf(random_value, 0.0, 1.0)
	# 是否暴击；暴击率使用 0 到 1 小数。
	var is_critical: bool = resolved_random_value < clampf(critical_chance, 0.0, 1.0)
	# 基础伤害；采用“伤害 × (攻击 + C) / (防御 + C)”。
	var base_damage: float = maxf(raw_damage, 0.0) * (maxf(attack_power, 0.0) + DEFENSE_SMOOTHING_CONSTANT) / (maxf(defense_power, 0.0) + DEFENSE_SMOOTHING_CONSTANT)
	# 暴击修正；未暴击为 1，暴击倍率默认参考为 1.5。
	var critical_modifier: float = maxf(critical_damage_multiplier, 1.0) if is_critical else 1.0
	# 综合系数；增伤区与免伤区之间相乘，各数组内部表示同一属性乘区并按相对 1 的比例加算。
	var comprehensive_coefficient: float = critical_modifier * _combine_increased_damage_zone(increased_damage_multipliers) * _combine_reduced_damage_zone(reduced_damage_multipliers)
	# 最终伤害；正伤害至少结算 1 点。
	var final_damage: int = roundi(base_damage * comprehensive_coefficient)
	if raw_damage > 0.0:
		final_damage = maxi(final_damage, 1)
	return {"damage": final_damage, "is_critical": is_critical, "base_damage": base_damage, "comprehensive_coefficient": comprehensive_coefficient}


static func _combine_increased_damage_zone(coefficients: Array) -> float:
	## 把多个增伤倍率转换为相对 1 的比例后加算；两个 1.10 倍来源返回 1.20，而不是 1.21。
	# 综合增伤比例；小于 1 的异常输入不在增伤区产生反向减伤。
	var combined_bonus_ratio: float = 0.0
	for raw_coefficient in coefficients:
		combined_bonus_ratio += maxf(float(raw_coefficient) - 1.0, 0.0)
	return 1.0 + combined_bonus_ratio


static func _combine_reduced_damage_zone(coefficients: Array) -> float:
	## 把多个剩余伤害倍率转换为免伤比例后加算；两个 0.90 倍来源返回 0.80，而不是 0.81。
	# 综合免伤比例；每项倍率限制到 0 至 1，最终合计限制到 100% 防止产生负伤害。
	var combined_reduction_ratio: float = 0.0
	for raw_coefficient in coefficients:
		combined_reduction_ratio += 1.0 - clampf(float(raw_coefficient), 0.0, 1.0)
	return 1.0 - clampf(combined_reduction_ratio, 0.0, 1.0)
