extends Resource
class_name ActiveSkillData

## 主动技能数据资源描述一个可装备到技能槽的输入方式、索敌规则、蓄力规则、冷却和行为脚本。
## ActiveSkillComponent 只负责通用释放状态机，具体效果由 behavior_script 创建的独立节点执行。

## 指向技能类型；按下后显示方向或位置范围，松开时把瞄准方向与目标位置交给行为节点。
const TARGETING_DIRECTIONAL: int = 0
## 锁定目标技能类型；按下后在索敌范围内选择距离鼠标最近的合法目标，松开时对该目标释放。
const TARGETING_TARGET_LOCK: int = 1
## 无索敌技能类型；按下后可进行蓄力，松开时不要求方向或目标即可释放。
const TARGETING_NO_TARGET: int = 2
## 方向输入模式；指向技能使用鼠标相对角色的单位方向，适合挥击、射线和冲刺。
const DIRECTIONAL_INPUT_DIRECTION: int = 0
## 位置输入模式；指向技能使用限制在释放距离内的鼠标世界坐标，适合地面范围效果。
const DIRECTIONAL_INPUT_POSITION: int = 1

## 技能稳定标识；必须在同一角色的主动技能数组中唯一，默认空字符串表示配置无效，发布后修改会影响冷却与行为状态映射。
@export var skill_id: String = ""
## 技能显示名称；默认“未命名主动技能”，用于角色详情、战斗技能栏和提示信息，运行时不应动态修改模板。
@export var display_name: String = "未命名主动技能"
## 技能完整说明；默认空字符串，应记录长期有效的释放方式和效果，角色详情与技能栏提示会直接显示。
@export_multiline var description: String = ""
## 技能行为脚本；必须能够创建 Node，并实现 execute(context) 返回是否成功释放，运行时不应替换已创建实例的脚本。
@export var behavior_script: Script
## 索敌类型；0 为指向、1 为锁定目标、2 为无索敌，默认 2 使未配置技能不会意外查找目标。
@export_enum("指向", "锁定目标", "无索敌") var targeting_mode: int = TARGETING_NO_TARGET
## 指向输入模式；0 使用方向、1 使用目标位置，默认 0，只有 targeting_mode 为指向时生效。
@export_enum("方向", "位置") var directional_input_mode: int = DIRECTIONAL_INPUT_DIRECTION
## 基础冷却时间；取值大于等于 0 秒，默认 0 表示可以连续释放，运行时由组件按成功释放次数独立计时。
@export_range(0.0, 3600.0, 0.05, "or_greater") var cooldown_duration: float = 0.0
## 单次能量消耗；取值大于等于 0，默认 0 表示无需能量，成功释放后才由属性组件扣除。
@export_range(0.0, 9999.0, 0.1, "or_greater") var energy_cost: float = 0.0
## 释放或索敌最大距离；取值大于 0 像素，默认 240，用于范围显示、鼠标位置夹取与目标合法性过滤。
@export_range(1.0, 6000.0, 1.0, "or_greater") var cast_range: float = 240.0
## 指向技能扇形半角；取值 0 至 180 度，默认 45 度，用于方向范围预览，具体行为可复用该角度进行命中过滤。
@export_range(0.0, 180.0, 0.5) var directional_half_angle_degrees: float = 45.0
## 合法目标节点组；默认 skill_targets，锁定目标和需要目标列表的行为只处理主动加入该组的节点。
@export var target_group: StringName = &"skill_targets"
## 合法目标是否必须提供 apply_damage；默认 true，避免锁定装饰节点，治疗或交互技能可关闭后由行为脚本自行复核接口。
@export var target_requires_damage_method: bool = true
## 锁定目标是否要求角色到目标之间无遮挡；默认 false 允许技能自行决定遮挡规则，开启后使用环境碰撞掩码复核。
@export var target_requires_line_of_sight: bool = false
## 锁定目标视线检测碰撞掩码；默认第 5 层环境，只有 target_requires_line_of_sight 开启时生效。
@export_flags_2d_physics var line_of_sight_collision_mask: int = 16
## 是否允许蓄力；默认 false，开启后从按下开始累计时间并在角色头顶显示蓄力条。
@export var can_charge: bool = false
## 最大蓄力时间；取值大于 0 秒，默认 1 秒，达到上限后蓄力比例保持 100% 直到松开。
@export_range(0.01, 30.0, 0.01, "or_greater") var maximum_charge_duration: float = 1.0
## 蓄力期间移动速度倍率；取值 0 至 1，默认 1 表示不减速，只有 can_charge 开启且技能保持按住时由玩家控制器应用。
@export_range(0.0, 1.0, 0.01) var charge_movement_speed_multiplier: float = 1.0
## 瞄准目标标记半径；取值大于 0 像素，默认 18，用于位置指向与锁定目标的世界预览圆环。
@export_range(1.0, 256.0, 1.0, "or_greater") var target_marker_radius: float = 18.0


func is_valid_configuration() -> bool:
	## 只有稳定 ID 和可实例化行为脚本都存在时才允许进入技能槽，避免空配置占用输入并产生无效果冷却。
	return not skill_id.strip_edges().is_empty() and behavior_script != null
