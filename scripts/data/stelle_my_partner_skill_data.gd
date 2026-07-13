extends "res://scripts/data/active_skill_data.gd"
class_name StelleMyPartnerSkillData

## “我的伙伴”技能数据保存迷迷资源、重复释放治疗、限时攻速和标记联动冷却数值。

## 召唤的衍生单位资源；必须提供 unit_scene，默认空资源会使技能释放失败且不消耗能量。
@export var derived_unit: Resource
## 首次召唤相对玩家的偏移；默认 (52, 0)，避免生成时与玩家碰撞体重叠。
@export var summon_offset: Vector2 = Vector2(52.0, 0.0)
## 迷迷已在场时回复的生命值；默认 100 点，不会超过单位最大生命。
@export_range(0.0, 99999.0, 1.0, "or_greater") var existing_unit_heal_amount: float = 100.0
## 迷迷已在场时获得的攻速提升；默认 1.0 表示提高 100%，实际攻击冷却减半。
@export_range(0.0, 10.0, 0.01, "or_greater") var existing_unit_attack_speed_bonus_ratio: float = 1.0
## 重复释放攻速提升持续时间；默认 3 秒，重复释放会刷新同一来源计时。
@export_range(0.01, 120.0, 0.01, "or_greater") var existing_unit_attack_speed_duration: float = 3.0
## 迷迷命中银河全垒打标记目标时减少的本技能冷却；默认每次 1 秒，最低减到 0。
@export_range(0.0, 120.0, 0.01, "or_greater") var marked_target_cooldown_reduction: float = 1.0
