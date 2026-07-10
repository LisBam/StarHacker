extends Resource
class_name WeaponData

## 武器数据资源集中描述一把武器的装备类型、消耗、伤害和攻击节奏。
## 背包、装备、攻击和 HUD 都只读取这个资源，不直接互相写死参数。
## 同一套字段同时覆盖远程和近战武器，未使用字段保持默认值即可。

## 武器物品类型；固定为 weapon，供库存和 UI 与可堆叠资源解耦识别。
@export var item_kind: String = "weapon"

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
## 局外出售价格；取值大于等于 0，默认 0 表示不可出售，只在永久仓库出售时兑换为局外金币且运行时通常不修改。
@export_range(0, 999999, 1) var sell_price: int = 0
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
## 武器扩散角度；取值大于等于 0，默认 0 度表示完全精准，数值越高每次弹体相对瞄准方向的随机偏移越明显。
@export_range(0.0, 45.0, 0.1, "or_greater") var spread_degrees: float = 0.0
## 武器后坐力；取值建议大于等于 0，默认 0 表示不推动使用者，远程开火时会把玩家向反方向推开。
@export_range(0.0, 3000.0, 1.0, "or_greater") var recoil_force: float = 0.0
## 武器前坐力；取值建议大于等于 0，默认 0 表示不向攻击方向推动使用者，适合近战突进或特殊枪械反馈，屏幕震动按后坐力的一半换算。
@export_range(0.0, 3000.0, 1.0, "or_greater") var front_recoil_force: float = 0.0
## 武器冲击力；取值建议大于等于 0，默认 0 表示不造成击退，命中目标时会按目标韧性折算控制效果。
@export_range(0.0, 5000.0, 1.0, "or_greater") var impact_force: float = 0.0
## 近战伤害；取值建议大于等于 0，默认 35，修改会影响近战命中后的伤害值。
@export_range(0.0, 9999.0, 1.0, "or_greater") var melee_damage: float = 35.0
## 近战冷却；取值应大于 0，默认 0.45 秒，修改会影响近战攻击节奏。
@export_range(0.01, 5.0, 0.01) var melee_cooldown: float = 0.45
## 近战命中框激活时长；取值应大于 0，默认 0.12 秒，修改会影响近战判定窗口。
@export_range(0.01, 2.0, 0.01) var melee_active_duration: float = 0.12
## 累计强化百分比词典；键使用 damage、cooldown 等统一属性名，值为相对基础值的小数比例，运行时由强化石永久累加。
@export var enhancement_modifiers: Dictionary = {}

## 强化后售价最低倍率；默认 0.1，防止大量负词条把售价降为负数，运行时通常不修改。
const MINIMUM_SELL_PRICE_MULTIPLIER: float = 0.1
## 冷却和判定时长最小有效值；默认 0.01 秒，防止负强化导致除零或无限攻击。
const MINIMUM_DURATION_VALUE: float = 0.01
## 可应用于所有武器的统一强化属性；新增通用战斗字段时应同步详情格式化器。
const COMMON_ENHANCEMENT_STATS: Array[String] = ["damage", "cooldown", "energy_cost", "recoil_force", "front_recoil_force", "impact_force"]
## 远程武器专属强化属性；只允许远程武器消费包含这些字段的强化石效果。
const RANGED_ENHANCEMENT_STATS: Array[String] = ["projectile_speed", "bullet_range", "spread_degrees"]
## 近战武器专属强化属性；只允许近战武器消费包含这些字段的强化石效果。
const MELEE_ENHANCEMENT_STATS: Array[String] = ["melee_active_duration"]


func is_ranged() -> bool:
	return weapon_type == "ranged"


func is_melee() -> bool:
	return weapon_type == "melee"


func get_base_stat(stat_name: String) -> float:
	# 基础字段名；damage 与 cooldown 会根据武器类型映射到旧资源字段，保持所有既有 tres 兼容。
	var property_name: String = _resolve_base_property_name(stat_name)
	if property_name.is_empty():
		return 0.0
	# 基础字段值；取值来自资源原始导出属性，强化过程不会写回这些字段。
	var property_value: Variant = get(property_name)
	return float(property_value) if property_value != null else 0.0


func get_enhancement_ratio(stat_name: String) -> float:
	# 统一属性名；允许战斗组件传入 ranged_damage 等旧字段名并映射到 damage 强化词条。
	var canonical_stat_name: String = _resolve_canonical_stat_name(stat_name)
	return float(enhancement_modifiers.get(canonical_stat_name, 0.0))


func get_enhancement_value(stat_name: String) -> float:
	return get_base_stat(stat_name) * get_enhancement_ratio(stat_name)


func get_effective_stat(stat_name: String) -> float:
	# 有效属性值；基础值乘以累计百分比，所有攻击与玩家反馈组件应通过该接口读取。
	var effective_value: float = get_base_stat(stat_name) * (1.0 + get_enhancement_ratio(stat_name))
	# 统一属性名；持续时间保持正数，其余不能为负，避免异常强化破坏战斗组件。
	var canonical_stat_name: String = _resolve_canonical_stat_name(stat_name)
	if canonical_stat_name in ["cooldown", "melee_active_duration"]:
		return maxf(effective_value, MINIMUM_DURATION_VALUE)
	return maxf(effective_value, 0.0)


func can_apply_enhancement(modifiers: Dictionary) -> bool:
	for raw_stat_name in modifiers.keys():
		if _is_stat_supported(str(raw_stat_name)):
			return true
	return false


func apply_enhancement(modifiers: Dictionary) -> bool:
	# 是否实际应用词条；只有与当前武器兼容的字段会写入，避免远程专属属性污染近战武器。
	var applied_any_modifier: bool = false
	for raw_stat_name in modifiers.keys():
		# 统一属性名；空值或当前武器不支持的字段直接跳过。
		var stat_name: String = _resolve_canonical_stat_name(str(raw_stat_name))
		if not _is_stat_supported(stat_name):
			continue
		# 新累计比例；强化允许正负相抵，不限制次数，基础属性始终保持不变。
		var accumulated_ratio: float = float(enhancement_modifiers.get(stat_name, 0.0)) + float(modifiers.get(raw_stat_name, 0.0))
		enhancement_modifiers[stat_name] = accumulated_ratio
		applied_any_modifier = true
	return applied_any_modifier


func get_effective_sell_price() -> int:
	# 售价调整比例；按所有当前武器可用词条的累计百分比相加，正强化升值、负强化贬值。
	var sell_price_ratio: float = 0.0
	for raw_stat_name in enhancement_modifiers.keys():
		if _is_stat_supported(str(raw_stat_name)):
			sell_price_ratio += float(enhancement_modifiers.get(raw_stat_name, 0.0))
	return maxi(roundi(float(sell_price) * maxf(1.0 + sell_price_ratio, MINIMUM_SELL_PRICE_MULTIPLIER)), 0)


func _resolve_base_property_name(stat_name: String) -> String:
	# 统一属性名；兼容战斗组件仍传入旧的远近战字段名。
	var canonical_stat_name: String = _resolve_canonical_stat_name(stat_name)
	if canonical_stat_name == "damage":
		return "ranged_damage" if is_ranged() else "melee_damage"
	if canonical_stat_name == "cooldown":
		return "ranged_cooldown" if is_ranged() else "melee_cooldown"
	return canonical_stat_name if canonical_stat_name in COMMON_ENHANCEMENT_STATS + RANGED_ENHANCEMENT_STATS + MELEE_ENHANCEMENT_STATS else ""


func _resolve_canonical_stat_name(stat_name: String) -> String:
	if stat_name in ["ranged_damage", "melee_damage"]:
		return "damage"
	if stat_name in ["ranged_cooldown", "melee_cooldown"]:
		return "cooldown"
	return stat_name


func _is_stat_supported(stat_name: String) -> bool:
	# 统一属性名；通用词条对所有武器有效，专属词条按 weapon_type 校验。
	var canonical_stat_name: String = _resolve_canonical_stat_name(stat_name)
	if canonical_stat_name in COMMON_ENHANCEMENT_STATS:
		return true
	if is_ranged():
		return canonical_stat_name in RANGED_ENHANCEMENT_STATS
	return canonical_stat_name in MELEE_ENHANCEMENT_STATS
