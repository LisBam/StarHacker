extends "res://scripts/data/active_skill_data.gd"
class_name CaelusFirewallChargeSkillData

## 炎墙，冲锋！数据集中保存冲锋时长、速度、防御力伤害转化、减伤、碰撞半径与冲击力。

## 冲锋基础持续时间；默认 1 秒，释放时再加本次实际蓄力秒数。
@export_range(0.01, 30.0, 0.01, "or_greater") var base_charge_duration: float = 1.0
## 冲锋额外移速属性；默认 150 点，与角色当前移速属性相加后按 1 点等于 3 像素/秒换算。
@export_range(0.0, 3000.0, 1.0, "or_greater") var bonus_move_speed_attribute: float = 150.0
## 冲锋期间减伤比例；默认 0.80 表示最终受到伤害降低 80%，与其他来源按剩余伤害连乘。
@export_range(0.0, 1.0, 0.01) var charge_damage_reduction_ratio: float = 0.80
## 撞击基础威力；默认 10 点，与当前最终防御力比例共同组成统一伤害公式前的技能威力。
@export_range(0.0, 99999.0, 0.1, "or_greater") var base_damage: float = 10.0
## 当前防御力转化比例；默认 0.20 表示撞击额外加入释放瞬间最终防御力的 20%。
@export_range(0.0, 10.0, 0.01, "or_greater") var defense_power_ratio: float = 0.20
## 撞击冲击力；单位为目标理论位移像素，默认 50，方向根据目标位于冲锋轴线哪一侧选择对应垂直方向。
@export_range(0.0, 5000.0, 1.0, "or_greater") var impact_force: float = 50.0
## 撞击检测半径；默认 42 像素，覆盖玩家与当前基础怪物碰撞半径之和并留出 7 像素物理帧容差。
@export_range(1.0, 500.0, 1.0, "or_greater") var collision_radius: float = 42.0
## 统一伤害公式使用的来源攻击力；默认 100，使防御力比例先组成技能威力，再只按目标防御结算。
@export_range(0.0, 99999.0, 1.0, "or_greater") var damage_formula_attack_power: float = 100.0
