extends "res://scripts/data/active_skill_data.gd"
class_name SilverWolfWarmupCompleteSkillData

## 热身结束数据保存解锁所需累计伤害与额外可分配属性点数。

## 造成与受到伤害合计解锁阈值；默认 999 点。
@export_range(1.0, 999999.0, 1.0, "or_greater") var unlock_damage_total: float = 999.0
## 二次五维分配额外点数；默认 99 点。
@export_range(1, 9999, 1, "or_greater") var additional_attribute_points: int = 99
