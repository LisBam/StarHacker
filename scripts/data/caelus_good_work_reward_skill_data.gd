extends "res://scripts/data/passive_skill_data.gd"
class_name CaelusGoodWorkRewardSkillData

## 好活当赏数据保存统计窗口、受伤次数、触发冷却和护盾防御力公式。

## 受伤统计窗口；默认 6 秒，首次受伤后开始计时。
@export_range(0.01, 120.0, 0.01, "or_greater") var tracking_window: float = 6.0
## 窗口内所需受伤次数；默认 6 次，闪避成功不会派发实际受伤信号。
@export_range(1, 100, 1, "or_greater") var required_hit_count: int = 6
## 成功触发后的被动冷却；默认 6 秒，冷却期间不累计新窗口。
@export_range(0.0, 120.0, 0.01, "or_greater") var trigger_cooldown: float = 6.0
## 护盾固定值；默认 66 点。
@export_range(0.0, 99999.0, 0.1, "or_greater") var base_shield_amount: float = 66.0
## 防御力护盾转化比例；默认 0.06 表示加入当前最终防御力的 6%。
@export_range(0.0, 10.0, 0.001, "or_greater") var defense_power_ratio: float = 0.06
