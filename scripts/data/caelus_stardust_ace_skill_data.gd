extends "res://scripts/data/active_skill_data.gd"
class_name CaelusStardustAceSkillData

## 穹的星尘王牌数据保存状态持续时间、两种武器槽护盾伤害比例和公式攻击力。

## 状态持续时间；默认 5 秒，技能释放后开始计时，结束后才进入冷却。
@export_range(0.01, 120.0, 0.01, "or_greater") var effect_duration: float = 5.0
## 近战武器消耗护盾的伤害比例；默认 0.5，对本次全部近战命中目标生效。
@export_range(0.0, 10.0, 0.01, "or_greater") var melee_shield_damage_ratio: float = 0.5
## 远程武器消耗护盾的伤害比例；默认 1.0，只对本次弹体首个命中目标生效。
@export_range(0.0, 10.0, 0.01, "or_greater") var ranged_shield_damage_ratio: float = 1.0
## 统一伤害公式使用的来源攻击力；默认 100，使护盾值只按目标防御结算一次。
@export_range(0.0, 99999.0, 1.0, "or_greater") var damage_formula_attack_power: float = 100.0
