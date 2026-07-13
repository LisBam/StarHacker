extends "res://scripts/data/passive_skill_data.gd"
class_name SilverWolfHomeFieldSkillData

## 我的主场！数据定义五维基础属性分配的共同基准、单项浮动范围与输入精度。

## 五维基础属性共同基准；默认 99 点，总点数固定为该整数值的五倍。
@export_range(1.0, 9999.0, 1.0, "or_greater") var base_attribute_value: float = 99.0
## 每项属性相对基准允许浮动的最大比例；默认 0.20，整数边界向内取整后可在 80 至 118 之间分配。
@export_range(0.0, 1.0, 0.01) var maximum_adjustment_ratio: float = 0.20
## 属性分配输入步长；默认 1 点，滑条与手动输入只允许整数，数字框箭头由界面固定每次调整 10 点。
@export_range(1.0, 100.0, 1.0, "or_greater") var allocation_step: float = 1.0
