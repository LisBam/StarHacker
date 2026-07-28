extends RefCounted
class_name HackModeRules

## 骇入模式规则表：集中声明标准骇入、零装骇入、超频骇入三种模式的稳定标识、展示文案、
## 分组（战斗模式 / 娱乐模式）、结算资格与全部数值倍率。
## 模式选择界面、联机面板、GameWorld 与玩家组件只读取本表，不各自复制模式数值；
## 未来新增骇入模式时只需扩展本文件的定义表，并在对应挂点消费新增字段。
## 使用方式：全部接口均为静态函数，直接以 HackModeRules.xxx() 调用，不需要实例化。

## 标准骇入模式标识；当前默认规则，携带背包装备入场并正常结算，修改会影响全部模式判定与联机同步。
const VARIANT_STANDARD: String = "standard"
## 零装骇入模式标识；空背包空装备入场、局内自给自足的战斗模式，修改会影响零装规则挂点判定。
const VARIANT_BARE: String = "bare"
## 超频骇入模式标识；不产出结算的娱乐模式，修改会影响超频规则挂点判定。
const VARIANT_OVERCLOCK: String = "overclock"

## 战斗模式分组标识；该分组下的模式正常产出物品得失结算，修改会影响模式选择界面分组归属。
const CATEGORY_BATTLE: String = "battle"
## 娱乐模式分组标识；该分组下的模式与训练场一致不产出结算，修改会影响模式选择界面分组归属。
const CATEGORY_CASUAL: String = "casual"

## 零装模式怪物人口倍率；默认 0.6 表示开局布怪、人口曲线与同时活跃上限整体降到六成，平衡零装前期无装备的压力。
const BARE_POPULATION_MULTIPLIER: float = 0.6
## 零装模式武器装备二手概率；默认 0.65 覆盖正式战斗的 0.30 基础值，让零装局内自给的装备更常带随机强化与耐久损耗。
const BARE_SECOND_HAND_CHANCE: float = 0.65
## 超频模式怪物人口倍率；默认 2.0 表示开局布怪、人口曲线与同时活跃上限整体翻倍，制造高密度清怪爽局。
const OVERCLOCK_POPULATION_MULTIPLIER: float = 2.0
## 超频模式主动技能冷却倍率；默认 0.2 表示技能进入冷却时按两成时长写入，训练场无冷却开关优先级更高。
const OVERCLOCK_SKILL_COOLDOWN_SCALE: float = 0.2

## 模式定义表；数组顺序即模式选择界面与联机下拉框的展示顺序，每项包含稳定标识、展示名、分组与玩家可见说明。
const MODE_DEFINITIONS: Array[Dictionary] = [
	{
		"variant": VARIANT_STANDARD,
		"display_name": "标准骇入",
		"category": CATEGORY_BATTLE,
		"description": "携带当前背包与装备入场，掉落、撤离与死亡结算全部使用标准规则。",
	},
	{
		"variant": VARIANT_BARE,
		"display_name": "零装骇入",
		"category": CATEGORY_BATTLE,
		"description": "不携带任何资源入场，局内自给自足；怪物数量降低到 60%，掉落武器装备的二手概率提高到 65%，本局所得结算后全部存入仓库。",
	},
	{
		"variant": VARIANT_OVERCLOCK,
		"display_name": "超频骇入",
		"category": CATEGORY_CASUAL,
		"description": "技能冷却 ×0.2、无限能量（始终保持满值）、武器装备耐久不消耗、怪物密度翻倍；与训练场一致不产出物品结算。",
	},
]


static func normalize_variant(variant: String) -> String:
	## 规范化骇入模式标识；未知取值一律回退标准骇入，保证旧入口与异常网络数据不会进入未定义模式。
	if variant == VARIANT_BARE or variant == VARIANT_OVERCLOCK:
		return variant
	return VARIANT_STANDARD


static func get_mode_definitions() -> Array[Dictionary]:
	## 返回模式定义表副本；元素顺序即 UI 展示顺序，调用方只读展示不得回写常量表。
	# 定义表结果；逐项复制避免调用方意外修改共享常量字典。
	var definitions: Array[Dictionary] = []
	for mode_definition in MODE_DEFINITIONS:
		definitions.append(mode_definition.duplicate(true))
	return definitions


static func get_display_name(variant: String) -> String:
	## 返回骇入模式展示名；主菜单选择界面、联机面板与结算文案共用同一文案来源。
	for mode_definition in MODE_DEFINITIONS:
		if str(mode_definition.get("variant", "")) == normalize_variant(variant):
			return str(mode_definition.get("display_name", "标准骇入"))
	return "标准骇入"


static func get_description(variant: String) -> String:
	## 返回骇入模式玩家可见说明；供模式选择界面与联机面板提示复用。
	for mode_definition in MODE_DEFINITIONS:
		if str(mode_definition.get("variant", "")) == normalize_variant(variant):
			return str(mode_definition.get("description", ""))
	return ""


static func get_category(variant: String) -> String:
	## 返回骇入模式所属分组；battle 表示战斗模式（有结算），casual 表示娱乐模式（无结算）。
	for mode_definition in MODE_DEFINITIONS:
		if str(mode_definition.get("variant", "")) == normalize_variant(variant):
			return str(mode_definition.get("category", CATEGORY_BATTLE))
	return CATEGORY_BATTLE


static func requires_first_successful_extraction(variant: String) -> bool:
	## 返回模式是否必须先完成首次正式成功撤离；当前仅娱乐模式使用该永久成长门槛，战斗模式可直接选择。
	return get_category(variant) == CATEGORY_CASUAL


static func get_category_display_name(category: String) -> String:
	## 返回分组展示名；模式选择界面用它绘制“战斗模式 / 娱乐模式”分组标题。
	return "娱乐模式" if category == CATEGORY_CASUAL else "战斗模式"


static func is_settlement_enabled(variant: String) -> bool:
	## 返回该模式是否产出物品得失结算；娱乐模式与训练场一致不结算，战斗模式正常结算。
	return get_category(variant) != CATEGORY_CASUAL


static func is_bare_loadout(variant: String) -> bool:
	## 返回该模式是否以空背包空装备入场；目前只有零装骇入启用。
	return normalize_variant(variant) == VARIANT_BARE


static func get_population_multiplier(variant: String) -> float:
	## 返回该模式的怪物人口倍率；作用于开局布怪、人口曲线目标与同时活跃真实敌人上限，与联机成员倍率相乘。
	# 规范化模式标识；未知模式按标准骇入返回 1.0。
	var resolved_variant: String = normalize_variant(variant)
	if resolved_variant == VARIANT_BARE:
		return BARE_POPULATION_MULTIPLIER
	if resolved_variant == VARIANT_OVERCLOCK:
		return OVERCLOCK_POPULATION_MULTIPLIER
	return 1.0


static func get_second_hand_chance_override(variant: String) -> float:
	## 返回该模式对局内掉落二手概率的覆盖值；负值表示不覆盖，继续使用 GameWorld 检查器配置的基础概率。
	if normalize_variant(variant) == VARIANT_BARE:
		return BARE_SECOND_HAND_CHANCE
	return -1.0


static func get_skill_cooldown_scale(variant: String) -> float:
	## 返回该模式的主动技能冷却倍率；1.0 表示不修改，超频模式返回 0.2。
	if normalize_variant(variant) == VARIANT_OVERCLOCK:
		return OVERCLOCK_SKILL_COOLDOWN_SCALE
	return 1.0


static func is_energy_consumption_disabled(variant: String) -> bool:
	## 返回该模式是否完全不消耗能量；超频模式通过战斗属性组件的无限能量开关实现。
	return normalize_variant(variant) == VARIANT_OVERCLOCK


static func is_durability_consumption_disabled(variant: String) -> bool:
	## 返回该模式是否完全不消耗武器与防具耐久；超频模式在玩家控制器与装备组件各自的模式开关上生效。
	return normalize_variant(variant) == VARIANT_OVERCLOCK
