extends "res://scripts/data/active_skill_data.gd"
class_name StelleStardustAceSkillData

## “星尘王牌”技能数据保存状态时长、武器次数上限以及远程与近战两套附加伤害公式。

## 状态最长持续时间；默认 10 秒，达到武器攻击次数上限时可提前结束。
@export_range(0.01, 120.0, 0.01, "or_greater") var effect_duration: float = 10.0
## 状态内允许的武器攻击次数；默认 3 次，成功使用武器后计数，技能释放不计入。
@export_range(1, 100, 1, "or_greater") var maximum_weapon_attack_count: int = 3
## 远程武器槽命中首个目标的固定附加伤害；默认 8 点。
@export_range(0.0, 99999.0, 0.1, "or_greater") var ranged_bonus_base_damage: float = 8.0
## 远程武器槽附加伤害的攻击力比例；默认 0.05 表示加入当前最终攻击力的 5%。
@export_range(0.0, 10.0, 0.001, "or_greater") var ranged_bonus_attack_power_ratio: float = 0.05
## 近战武器槽和银河全垒打对每个命中目标的固定附加伤害；默认 5 点。
@export_range(0.0, 99999.0, 0.1, "or_greater") var melee_bonus_base_damage: float = 5.0
## 近战与银河全垒打附加伤害的攻击力比例；默认 0.025 表示加入当前最终攻击力的 2.5%。
@export_range(0.0, 10.0, 0.001, "or_greater") var melee_bonus_attack_power_ratio: float = 0.025
## 统一伤害公式使用的来源攻击力；默认 100，附加威力已包含角色攻击力比例，不再重复乘算。
@export_range(0.0, 99999.0, 1.0, "or_greater") var damage_formula_attack_power: float = 100.0
## 第三次近战攻击的命中结算宽限；默认 0.13 秒，略大于当前最长 0.12 秒近战判定窗口，保证本次攻击全部命中后再结束状态。
@export_range(0.0, 2.0, 0.01, "or_greater") var melee_resolution_grace_duration: float = 0.13
