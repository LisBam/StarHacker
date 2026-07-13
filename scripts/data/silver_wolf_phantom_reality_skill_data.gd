extends "res://scripts/data/active_skill_data.gd"
class_name SilverWolfPhantomRealitySkillData

## 幻影现实数据集中保存落地伤害、范围、击退、传送安全搜索和致命回溯冷却参数。

## 传送落地基础威力；默认 9 点，与释放瞬间最终攻击力比例共同组成原始伤害。
@export_range(0.0, 99999.0, 0.1, "or_greater") var landing_base_damage: float = 9.0
## 传送落地攻击力转化比例；默认 0.09 表示额外加入当前最终攻击力的 9%。
@export_range(0.0, 10.0, 0.01, "or_greater") var attack_power_ratio: float = 0.09
## 传送落地伤害半径；默认 90 像素，以最终安全落点为圆心枚举技能目标组。
@export_range(1.0, 1000.0, 1.0, "or_greater") var landing_effect_radius: float = 90.0
## 传送落地冲击力；单位为目标理论位移像素，默认 75，方向从落点圆心指向目标。
@export_range(0.0, 5000.0, 1.0, "or_greater") var landing_impact_force: float = 75.0
## 统一伤害公式使用的来源攻击力；默认 100，使技能威力只按目标防御继续结算而不重复乘玩家攻击力。
@export_range(0.0, 99999.0, 1.0, "or_greater") var damage_formula_attack_power: float = 100.0
## 安全落点检测半径；默认 18 像素，与玩家本体圆形碰撞半径一致。
@export_range(1.0, 128.0, 1.0, "or_greater") var teleport_clearance_radius: float = 18.0
## 墙内目标向外搜索步长；默认 18 像素，越小越接近真实最近空地但物理查询次数越高。
@export_range(1.0, 128.0, 1.0, "or_greater") var teleport_search_step: float = 18.0
## 墙内目标最近空地最大搜索半径；默认 600 像素，找不到时本段技能释放失败且不消费资源。
@export_range(1.0, 3000.0, 1.0, "or_greater") var teleport_max_search_radius: float = 600.0
## 致命伤害自动回溯后的本次冷却额外比例；默认 0.99，使 9 秒根冷却按 1.99 倍结算为 17.91 秒。
@export_range(0.0, 10.0, 0.01, "or_greater") var lethal_cooldown_extension_ratio: float = 0.99
