extends "res://scripts/data/active_skill_data.gd"
class_name SilverWolfDoubleSpeedSkillData

## 二倍速技能数据集中保存攻速、固定移速、受击衰减、无伤奖励与头顶反馈参数。

## 效果基础持续时间；默认 9 秒，受击会从当前剩余时间扣除配置秒数。
@export_range(0.01, 120.0, 0.01, "or_greater") var effect_duration: float = 9.0
## 手持武器攻速提升比例；默认 0.99 表示提高 99%，通过玩家攻速接口在武器有效冷却之后结算。
@export_range(0.0, 10.0, 0.01, "or_greater") var attack_speed_bonus_ratio: float = 0.99
## 固定移速属性提升；默认增加 99 点，不转换为角色基础值且效果结束后精确移除。
@export_range(0.0, 3000.0, 1.0, "or_greater") var move_speed_attribute_bonus: float = 99.0
## 每次实际受击扣除的剩余持续时间；默认 2 秒，闪避成功不视为实际受击。
@export_range(0.0, 120.0, 0.01, "or_greater") var duration_loss_per_hit: float = 2.0
## 每次实际受击降低的技能效果比例；默认 0.20 表示从初始强度扣除 20%，五次受击后效果降为零。
@export_range(0.0, 1.0, 0.01) var effect_loss_ratio_per_hit: float = 0.20
## 全程无伤时剩余技能冷却缩减比例；默认 0.20 表示效果结束时把当前剩余冷却乘以 0.80。
@export_range(0.0, 1.0, 0.01) var no_hit_cooldown_reduction_ratio: float = 0.20
## 全程无伤完成时显示的头顶文本；默认 COMBO!，只作为即时反馈且不进入角色属性面板。
@export var no_hit_feedback_text: String = "COMBO!"
## 全程无伤完成时文本颜色；默认亮绿色，修改只影响头顶反馈视觉。
@export var no_hit_feedback_color: Color = Color(0.24, 1.0, 0.42, 1.0)
