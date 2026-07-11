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
	# 综合系数；增伤和减伤分别连乘。
	var comprehensive_coefficient: float = critical_modifier * _multiply_coefficients(increased_damage_multipliers) * _multiply_coefficients(reduced_damage_multipliers)
	# 最终伤害；正伤害至少结算 1 点。
	var final_damage: int = roundi(base_damage * comprehensive_coefficient)
	if raw_damage > 0.0:
		final_damage = maxi(final_damage, 1)
	return {"damage": final_damage, "is_critical": is_critical, "base_damage": base_damage, "comprehensive_coefficient": comprehensive_coefficient}


static func _multiply_coefficients(coefficients: Array) -> float:
	# 累计乘积；负系数按 0 处理，防止异常配置把伤害变成治疗。
	var product: float = 1.0
	for raw_coefficient in coefficients:
		product *= maxf(float(raw_coefficient), 0.0)
	return product
