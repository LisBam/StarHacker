extends "res://scripts/data/active_skill_data.gd"
class_name CaelusImmortalAmberSkillData

## 不灭的琥珀数据保存自身与其他友方护盾公式、持续时间和友方作用半径。

## 自身护盾固定值；默认 10 点。
@export_range(0.0, 99999.0, 0.1, "or_greater") var self_base_shield: float = 10.0
## 自身护盾防御力比例；默认 0.05 表示加入最终防御力的 5%。
@export_range(0.0, 10.0, 0.001, "or_greater") var self_defense_ratio: float = 0.05
## 其他友方护盾固定值；默认 5 点。
@export_range(0.0, 99999.0, 0.1, "or_greater") var ally_base_shield: float = 5.0
## 其他友方护盾防御力比例；默认 0.025 表示加入穹最终防御力的 2.5%。
@export_range(0.0, 10.0, 0.001, "or_greater") var ally_defense_ratio: float = 0.025
## 护盾持续时间；默认 10 秒，到期只移除尚未被伤害消耗的本次护盾。
@export_range(0.01, 120.0, 0.01, "or_greater") var shield_duration: float = 10.0
## 其他友方作用半径；默认 300 像素，范围内所有其他友方分别获得护盾。
@export_range(1.0, 4000.0, 1.0, "or_greater") var ally_radius: float = 300.0
