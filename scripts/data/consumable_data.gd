extends Resource
class_name ConsumableData

## 消耗品数据资源描述一次使用后施加到当前角色的限时属性效果。
## 库存只负责堆叠与消费，TemporaryBuffComponent 根据 effect_stat 和 effect_amount 解释战斗效果。

## 物品类型；固定为 consumable，供库存、筛选、存档和战斗使用菜单识别。
@export var item_kind: String = "consumable"
## 道具稳定标识；必须填写唯一英文 ID，修改会影响堆叠签名、内容包归属和存档恢复。
@export var item_id: String = ""
## 道具显示名称；默认“未命名消耗品”，用于物品卡片、掉落物和使用反馈。
@export var display_name: String = "未命名消耗品"
## 道具说明；默认空字符串，应保持与扩展包权威描述一致，运行时通常不动态修改。
@export_multiline var description: String = ""
## 道具图标文本；默认加号，建议保持 1 至 2 个字符，修改只影响紧凑物品卡片显示。
@export var icon_text: String = "+"
## 单个道具价值；取值大于等于 0，默认 0 表示不可出售，堆叠总价按数量相乘。
@export_range(0, 999999, 1) var value: int = 0
## 临时效果属性；move_speed_ratio 为移速比例、dodge_chance 为闪避率百分点、energy_regeneration 为每秒能量恢复点数。
@export_enum("move_speed_ratio", "dodge_chance", "energy_regeneration") var effect_stat: String = "move_speed_ratio"
## 临时效果数值；默认 0，比例字段使用 0.1 表示 10%，点数字段直接使用每秒增加量。
@export_range(0.0, 9999.0, 0.01, "or_greater") var effect_amount: float = 0.0
## 临时效果持续时间；单位为秒，默认 60 秒，同一 item_id 再次使用会刷新持续时间而不重复叠加数值。
@export_range(0.01, 86400.0, 0.01, "or_greater") var duration_seconds: float = 60.0


func get_stack_signature() -> String:
	## 返回稳定堆叠签名；同一 item_id 的道具共享数量，不把运行时剩余持续时间写入物品资源。
	return "consumable:%s" % item_id


func get_effect_description() -> String:
	## 返回用于详情面板的标准效果摘要；描述字段仍保留扩展包原文，本方法只展示结构化数值。
	if effect_stat == "move_speed_ratio":
		return "移速+%.0f%%，持续%.0f秒" % [effect_amount * 100.0, duration_seconds]
	if effect_stat == "dodge_chance":
		return "闪避率+%.0f%%，持续%.0f秒" % [effect_amount * 100.0, duration_seconds]
	return "每秒能量恢复+%.1f，持续%.0f秒" % [effect_amount, duration_seconds]
