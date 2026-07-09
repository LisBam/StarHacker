extends Resource
class_name WeaponData

## 武器数据资源集中描述一把武器的装备类型、消耗、伤害和攻击节奏。
## 背包、装备、攻击和 HUD 都只读取这个资源，不直接互相写死参数。
## 同一套字段同时覆盖远程和近战武器，未使用字段保持默认值即可。

## 武器唯一标识；默认空字符串表示未配置，建议使用稳定英文 ID，修改会影响存档和调试定位。
@export var weapon_id: String = ""
## 武器显示名称；默认“未命名武器”用于兜底显示，运行时通常不修改，改名会影响 HUD 和背包文本。
@export var display_name: String = "未命名武器"
## 武器类型；取值为 ranged 或 melee，默认 ranged，修改会影响装备槽校验和攻击组件读取字段。
@export_enum("ranged", "melee") var weapon_type: String = "ranged"
## 武器说明文本；默认空字符串，主要用于背包详情和调试展示，运行时通常不动态修改。
@export_multiline var description: String = ""
## HUD 图标文本；默认问号用于未配置图标时兜底，建议保持 1 到 2 个字符，修改会影响装备栏显示。
@export var icon_text: String = "?"
## 每次成功使用武器消耗的能量；取值建议大于等于 0，默认 0 表示免费攻击，修改会影响玩家能量消耗节奏。
@export_range(0.0, 9999.0, 0.1, "or_greater") var energy_cost: float = 0.0
## 远程武器使用的弹体场景；默认空表示不能发射，必须实例化为 Node2D，修改会影响远程攻击生成对象。
@export var projectile_scene: PackedScene
## 远程弹体速度；取值建议大于 0，默认 900，修改会影响远程弹道速度。
@export_range(1.0, 3000.0, 1.0, "or_greater") var projectile_speed: float = 900.0
## 远程弹体射程；取值建议大于 0，默认 340 像素，远程武器专用，修改会影响弹体自动销毁距离。
@export_range(1.0, 12000.0, 1.0, "or_greater") var bullet_range: float = 340.0
## 远程弹体伤害；取值建议大于等于 0，默认 12，修改会影响弹体命中后的伤害值。
@export_range(0.0, 9999.0, 1.0, "or_greater") var ranged_damage: float = 12.0
## 远程射击冷却；取值应大于 0，默认 0.16 秒，修改会影响连续射击频率。
@export_range(0.01, 5.0, 0.01) var ranged_cooldown: float = 0.16
## 武器后坐力；取值建议大于等于 0，默认 0 表示不推动使用者，远程开火时会把玩家向反方向推开。
@export_range(0.0, 3000.0, 1.0, "or_greater") var recoil_force: float = 0.0
## 武器冲击力；取值建议大于等于 0，默认 0 表示不造成击退，命中目标时会按目标韧性折算控制效果。
@export_range(0.0, 5000.0, 1.0, "or_greater") var impact_force: float = 0.0
## 近战伤害；取值建议大于等于 0，默认 35，修改会影响近战命中后的伤害值。
@export_range(0.0, 9999.0, 1.0, "or_greater") var melee_damage: float = 35.0
## 近战冷却；取值应大于 0，默认 0.45 秒，修改会影响近战攻击节奏。
@export_range(0.01, 5.0, 0.01) var melee_cooldown: float = 0.45
## 近战命中框激活时长；取值应大于 0，默认 0.12 秒，修改会影响近战判定窗口。
@export_range(0.01, 2.0, 0.01) var melee_active_duration: float = 0.12


func is_ranged() -> bool:
	return weapon_type == "ranged"


func is_melee() -> bool:
	return weapon_type == "melee"
