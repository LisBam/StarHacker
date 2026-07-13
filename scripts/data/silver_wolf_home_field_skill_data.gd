extends "res://scripts/data/passive_skill_data.gd"
class_name SilverWolfHomeFieldSkillData

## 我的主场！数据定义五维基础属性分配的共同基准、单项浮动范围与输入精度。

## 五维基础属性共同基准；默认 99 点，总点数固定为该值的五倍。
@export_range(1.0, 9999.0, 0.1, "or_greater") var base_attribute_value: float = 99.0
## 每项属性相对基准允许浮动的最大比例；默认 0.20 表示每项可在 79.2 至 118.8 之间分配。
@export_range(0.0, 1.0, 0.01) var maximum_adjustment_ratio: float = 0.20
## 属性分配输入步长；默认 0.1 点，五项总和必须保持 495 点才能确认。
@export_range(0.1, 100.0, 0.1, "or_greater") var allocation_step: float = 0.1
