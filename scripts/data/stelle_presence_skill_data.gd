extends "res://scripts/data/passive_skill_data.gd"
class_name StellePresenceSkillData

## 开拓！！技能数据保存视野计数目标、刷新节奏和攻防倍率上限。
## 行为节点按当前相机实际世界视野统计，资源只提供长期可调的规则参数。

## 每个合法目标提供的攻防比例；默认 0.02 表示每个其他单位或宝箱提高 2%。
@export_range(0.0, 10.0, 0.001, "or_greater") var bonus_ratio_per_target: float = 0.02
## 通过本技能获得的攻防比例上限；默认 0.20 表示最多提高 20%。
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_bonus_ratio: float = 0.20
## 视野统计刷新间隔；默认 0.15 秒，降低大量单位下的遍历频率且保持属性变化反馈及时。
@export_range(0.02, 2.0, 0.01) var refresh_interval: float = 0.15
## 可计数其他单位节点组；默认 skill_presence_units，未来友方或中立单位需显式加入该组才会被统计。
@export var unit_group: StringName = &"skill_presence_units"
## 可计数宝箱节点组；默认 loot_chests，与世界宝箱注册组保持一致。
@export var chest_group: StringName = &"loot_chests"
## 缺少玩家相机时的隔离场景视野尺寸；默认 1280×720 世界像素，只用于测试或兼容场景，不影响正常战斗相机。
@export var fallback_view_size: Vector2 = Vector2(1280.0, 720.0)
