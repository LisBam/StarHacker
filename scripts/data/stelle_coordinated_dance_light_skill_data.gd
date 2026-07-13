extends "res://scripts/data/active_skill_data.gd"
class_name StelleCoordinatedDanceLightSkillData

## 同协舞灯数据保存状态持续时间、每单位触发间隔、治疗固定值、生命比例和友方作用半径。

## 状态持续时间；默认 10 秒，期间玩家与范围内友方造成伤害时可治疗各自自身。
@export_range(0.01, 120.0, 0.01, "or_greater") var effect_duration: float = 10.0
## 单个单位治疗触发间隔；默认 0.5 秒，每名单位分别维护自己的计时。
@export_range(0.01, 10.0, 0.01, "or_greater") var trigger_interval: float = 0.5
## 单次治疗固定值；默认 2 点。
@export_range(0.0, 99999.0, 0.1, "or_greater") var base_heal_amount: float = 2.0
## 单次治疗的自身最大生命比例；默认 0.01 表示各单位按自身生命上限回复 1%。
@export_range(0.0, 10.0, 0.001, "or_greater") var max_health_heal_ratio: float = 0.01
## 友方作用半径；默认 500 像素，玩家自身始终视为合法单位，其他友方必须位于该范围内。
@export_range(1.0, 4000.0, 1.0, "or_greater") var friendly_effect_radius: float = 500.0
