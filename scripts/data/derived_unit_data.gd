extends Resource
class_name DerivedUnitData

## 衍生单位数据资源只保存角色展示、召唤技能和内容文档共同需要的基础资料。
## 运行时单位场景负责 AI 与战斗状态，角色 UI 通过 get_detail_text 读取稳定的只读快照。

## 单位稳定标识；必须为唯一英文 ID，默认空字符串，修改会影响技能查找与后续存档引用。
@export var unit_id: String = ""
## 单位显示名称；默认“未命名单位”，用于角色展示分类与调试界面。
@export var display_name: String = "未命名单位"
## 单位阵营类型；默认“友方单位”，用于展开卡片第一行的类型徽章。
@export var unit_type: String = "友方单位"
## 单位攻击类型；默认“近战”，用于详情说明其基础作战方式。
@export var attack_type: String = "近战"
## 单位场景；默认空，召唤技能必须配置可实例化的 Node2D 场景，角色展示不实例化该资源。
@export var unit_scene: PackedScene
## 是否可移动；默认 true，false 表示部署后保持原地并只攻击范围内目标。
@export var movable: bool = true
## 最大生命值；默认 100，修改会影响召唤单位承伤与角色详情数值。
@export_range(1.0, 99999.0, 1.0, "or_greater") var max_health: float = 100.0
## 攻击力；默认 100，参与统一攻防伤害公式，修改会影响单位最终输出。
@export_range(0.0, 99999.0, 1.0, "or_greater") var attack_power: float = 100.0
## 防御力；默认 100，参与统一承伤公式，修改会影响单位最终承伤。
@export_range(0.0, 99999.0, 1.0, "or_greater") var defense_power: float = 100.0
## 移动速度；默认 100 像素/秒，不可移动单位仍保留该数值作为模板信息但运行时不会使用。
@export_range(0.0, 2000.0, 1.0, "or_greater") var move_speed: float = 100.0
## 韧性；默认 0%，取值 0 至 100，修改会影响受到冲击后的实际击退距离。
@export_range(0.0, 100.0, 1.0) var toughness: float = 0.0
## 视野范围；默认 500 像素，修改会影响单位发现敌人的最大距离。
@export_range(1.0, 4000.0, 1.0, "or_greater") var vision_range: float = 500.0
## 单次基础伤害；默认 10，先与攻击力、目标防御进入统一伤害公式。
@export_range(0.0, 99999.0, 1.0, "or_greater") var damage: float = 10.0
## 攻击距离；默认 60 像素，近战单位到达该距离后停止追击并尝试攻击。
@export_range(1.0, 4000.0, 1.0, "or_greater") var attack_range: float = 60.0
## 攻击冷却；默认 1 秒，攻速提升会基于该值缩短实际间隔。
@export_range(0.01, 60.0, 0.01, "or_greater") var attack_cooldown: float = 1.0
## 前坐力；默认 0 点理论位移，攻击后沿攻击方向推动自身。
@export_range(0.0, 5000.0, 1.0, "or_greater") var front_recoil_force: float = 0.0
## 冲击力；默认 0 点理论位移，命中目标后按目标韧性折算击退。
@export_range(0.0, 5000.0, 1.0, "or_greater") var impact_force: float = 0.0


func get_detail_text() -> String:
	## 返回角色展示使用的完整单位详情；每项数值单独成行，便于长期维护和快速核对资源配置。
	return "攻击类型：%s\n可移动：%s\n最大生命值：%d\n攻击力：%d\n防御力：%d\n移速：%d\n韧性：%d%%\n视野：%d\n伤害：%d\n攻击距离：%d\n攻击冷却：%ss\n前坐力：%d\n冲击力：%d" % [attack_type, "是" if movable else "否", roundi(max_health), roundi(attack_power), roundi(defense_power), roundi(move_speed), roundi(toughness), roundi(vision_range), roundi(damage), roundi(attack_range), _format_seconds(attack_cooldown), roundi(front_recoil_force), roundi(impact_force)]


func _format_seconds(seconds: float) -> String:
	## 格式化秒数；整数不显示小数，非整数保留一位以匹配技能和武器详情格式。
	return str(roundi(seconds)) if is_equal_approx(seconds, roundf(seconds)) else "%.1f" % seconds
