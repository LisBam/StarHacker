extends "res://scripts/data/passive_skill_data.gd"
class_name StelleFarthestChestSkillData

## 开拓！技能数据保存地图标记的稳定键和类型。
## 行为节点只在地图宝箱生成完成后选择一次最远目标，目标移除或角色切换时会清理标记。

## 地图标记稳定标识；默认 stelle_farthest_chest，同一世界内相同标识只保留一个位置。
@export var map_marker_id: String = "stelle_farthest_chest"
## 地图标记类型；默认 chest，地图控件据此使用宝箱专属形状，未来可扩展其他技能标记视觉。
@export var map_marker_kind: String = "chest"
## 可标记宝箱节点组；默认 loot_chests，与世界宝箱注册协议一致，运行时通常不动态修改。
@export var chest_group: StringName = &"loot_chests"
