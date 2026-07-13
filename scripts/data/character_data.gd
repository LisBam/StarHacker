extends Resource
class_name CharacterData

## 角色数据资源保存可选择角色的稳定标识、展示信息和基础战斗属性。
## 将该资源保存到 data/characters 后，内容目录会自动发现并提供给角色选择、训练场和战斗属性系统。

## 角色稳定标识；必须填写唯一英文 ID，修改会影响会话中的当前角色选择。
@export var character_id: String = ""
## 角色显示名称；默认“未命名角色”，用于角色列表、详情面板和战斗 HUD。
@export var display_name: String = "未命名角色"
## 角色定位；默认“未配置定位”，用于角色选择详情说明该角色的玩法方向。
@export var role: String = "未配置定位"
## 角色说明；默认空字符串，用于长期记录角色玩法特征和适用场景。
@export_multiline var description: String = ""
## 是否开局默认解锁；默认 false 使后续新增角色保持锁定，设为 true 的角色会在首次启动和旧存档中自动补入解锁列表。
@export var unlocked_by_default: bool = false
## 基础生命上限；默认 100，进入战斗或切换角色时应用，运行时不应动态修改模板。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_health: float = 100.0
## 基础能量上限；默认 100，进入战斗或切换角色时应用，运行时不应动态修改模板。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_energy: float = 100.0
## 基础移动速度属性；默认 106.6667，按 1 点等于 3 像素/秒换算，装备移速比例会在该值上继续结算。
## 当前移动速度属性换算按 1 点等于 2 像素/秒执行；默认值仅作为未填写角色资源的隔离场景回退。
@export_range(1.0, 2000.0, 0.0001, "or_greater") var move_speed: float = 106.6667
## 基础攻击力；默认 10，装备攻击加成会在该值上继续结算，运行时不应动态修改模板。
@export_range(0.0, 99999.0, 1.0, "or_greater") var attack_power: float = 10.0
## 基础防御力；默认 5，装备防御加成会在该值上继续结算，运行时不应动态修改模板。
@export_range(0.0, 99999.0, 1.0, "or_greater") var defense_power: float = 5.0
## 基础每 5 秒生命恢复；默认 0，供角色属性面板和未来战斗恢复组件读取。
@export_range(0.0, 99999.0, 0.1, "or_greater") var health_regeneration_per_five_seconds: float = 0.0
## 基础视野倍率；默认 1.0 表示 100% 视野，装备视野加成会在其上继续结算。
@export_range(0.01, 10.0, 0.01, "or_greater") var vision_range: float = 1.0
## 基础闪避率；默认 0，使用 0 到 1 小数表示 0% 到 100%。
@export_range(0.0, 1.0, 0.01) var dodge_chance: float = 0.0
## 基础每秒能量恢复；默认 18，装备能量恢复会在该值上继续结算。
@export_range(0.0, 99999.0, 0.1, "or_greater") var energy_regeneration: float = 18.0
## 被动技能说明；默认待配置，当前用于角色选择详情占位，未来可扩展为技能资源引用。
## 兼容说明：该文本保留给旧角色和隔离场景，实际多被动行为优先读取 passive_skills 资源数组。
@export var passive: String = "被动技能：待配置"
## 主动技能说明；默认待配置，当前用于角色选择详情占位，未来可扩展为技能资源引用。
## 兼容说明：该文本保留给旧角色和隔离场景，实际三个主动技能槽优先读取 active_skills 资源数组。
@export var active: String = "主动技能：待配置"
## 被动技能资源数组；默认空表示没有运行时被动，每项应为 PassiveSkillData 兼容资源，角色进入战斗后会同时创建全部有效行为。
@export var passive_skills: Array[Resource] = []
## 主动技能资源数组；默认空表示三个技能槽都为空，最多按数组顺序把前三项配置到技能一、二、三。
@export var active_skills: Array[Resource] = []


func to_profile() -> Dictionary:
	return {
		"id": character_id,
		"display_name": display_name,
		"role": role,
		"description": description,
		"unlocked_by_default": unlocked_by_default,
		"max_health": max_health,
		"max_energy": max_energy,
		"move_speed": move_speed,
		"attack_power": attack_power,
		"defense_power": defense_power,
		"health_regeneration_per_five_seconds": health_regeneration_per_five_seconds,
		"vision_range": vision_range,
		"dodge_chance": dodge_chance,
		"energy_regeneration": energy_regeneration,
		"passive": passive,
		"active": active,
		"passive_skills": passive_skills.duplicate(),
		"active_skills": active_skills.duplicate(),
	}
