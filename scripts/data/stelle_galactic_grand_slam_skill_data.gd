extends "res://scripts/data/active_skill_data.gd"
class_name StelleGalacticGrandSlamSkillData

## 银河全垒打技能数据集中保存星的方向挥击伤害、蓄力、击退和视觉参数。
## 数值资源可以独立复制调试，行为脚本不保存共享运行时状态。

## 固定基础威力；默认 10 点，与攻击力加成共同组成进入统一攻防公式前的技能威力。
@export_range(0.0, 99999.0, 0.1, "or_greater") var base_damage: float = 10.0
## 当前攻击力转化比例；默认 0.20 表示额外加入当前最终攻击力的 20%，运行时会读取技能释放瞬间的属性。
@export_range(0.0, 10.0, 0.01, "or_greater") var attack_power_ratio: float = 0.20
## 基础击退距离；默认 100 像素，目标会通过自身击退衰减换算初速度，墙体仍可阻挡实际位移。
@export_range(0.0, 3000.0, 1.0, "or_greater") var knockback_distance: float = 100.0
## 满蓄力伤害增幅；默认 0.80 表示蓄力 3 秒时基础威力与攻击力加成的总和提高 80%。
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_charge_damage_bonus_ratio: float = 0.80
## 满蓄力击退增幅；默认 0.80 表示蓄力 3 秒时目标击退距离从 100 提高到 180 像素。
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_charge_knockback_bonus_ratio: float = 0.80
## 统一伤害公式使用的来源攻击力；默认 100，使“10（+20%当前攻击力）”先组成技能威力，再只按目标防御结算而不重复乘算当前攻击力。
@export_range(0.0, 99999.0, 1.0, "or_greater") var damage_formula_attack_power: float = 100.0
## 挥击是否受环境遮挡；默认 true，墙体或建筑位于角色和目标之间时不会隔墙命中。
@export var blocked_by_environment: bool = true
## 挥击环境碰撞掩码；默认第 5 层环境，只有 blocked_by_environment 开启时用于射线检测。
@export_flags_2d_physics var environment_collision_mask: int = 16
## 释放特效颜色；默认金白色，用于扇形挥击填充与边缘线，修改不会影响命中判定。
@export var cast_effect_color: Color = Color(1.0, 0.82, 0.34, 0.92)
## 释放特效持续时间；默认 0.24 秒，取值大于 0，只影响挥击视觉淡出速度。
@export_range(0.01, 3.0, 0.01, "or_greater") var cast_effect_duration: float = 0.24
## 释放特效扇形采样段数；默认 32 段，在短时挥击轮廓平滑度和绘制开销之间取得平衡。
@export_range(4, 128, 1) var cast_effect_segment_count: int = 32
## 释放特效填充透明度倍率；默认 0.28，在基础颜色透明度上继续缩放，避免遮挡目标。
@export_range(0.0, 1.0, 0.01) var cast_effect_fill_opacity_ratio: float = 0.28
## 释放特效轮廓线宽；默认 3 像素，只影响方向反馈清晰度，不改变实际命中范围。
@export_range(0.5, 12.0, 0.5) var cast_effect_outline_width: float = 3.0
