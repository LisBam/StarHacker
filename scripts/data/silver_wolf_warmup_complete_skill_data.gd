extends "res://scripts/data/active_skill_data.gd"
class_name SilverWolfWarmupCompleteSkillData

## 热身结束数据保存解锁所需累计伤害、第二次五维调整范围与额外可分配属性点数。

## 造成与受到伤害合计解锁阈值；默认 999 点。
@export_range(1.0, 999999.0, 1.0, "or_greater") var unlock_damage_total: float = 999.0
## 二次五维分配额外点数；默认 99 点。
@export_range(1, 9999, 1, "or_greater") var additional_attribute_points: int = 99
## 二次五维分配共同基准；默认 99 点，单项上下限继续相对角色原始五维基准计算。
@export_range(1.0, 9999.0, 1.0, "or_greater") var base_attribute_value: float = 99.0
## 二次五维单项最大浮动比例；默认 0.40，允许每项相对 99 点基准增减最多 40%。
@export_range(0.0, 1.0, 0.01) var maximum_adjustment_ratio: float = 0.40
## 二次五维输入步长；默认 1 点，保持基础面板属性为整数并与首次分配一致。
@export_range(1.0, 100.0, 1.0, "or_greater") var allocation_step: float = 1.0
