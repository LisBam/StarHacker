extends "res://scripts/data/passive_skill_data.gd"
class_name CaelusScavengingSkillData

## 拾荒被动数据保存成功撤离时按地图剩余掉落物价值换算星穹的比例。

## 地图掉落物总价值转化比例；默认 0.20 表示成功撤离获得总价值 20% 的星穹，小数结果向下取整。
@export_range(0.0, 10.0, 0.01, "or_greater") var world_drop_value_gold_ratio: float = 0.20
