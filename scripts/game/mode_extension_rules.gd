extends RefCounted
class_name ModeExtensionRules

## 模式扩展规则表集中声明可选扩展、风险合约负面词条、局内效果倍率与掉落奖励。
## 模式扩展选择界面、联机会话、SessionState 与 GameWorld 只通过本表交换稳定 ID，
## 不在各自脚本中复制词条名称、数值或兼容条件，便于后续增加新的模式扩展。
## 风险合约的四个候选按效果类别无放回抽取，同一批不会同时出现同类词条的多个强度档位。

## 风险合约扩展标识；启用后必须从当前四个随机负面词条中至少选择一项。
const EXTENSION_RISK_CONTRACT: String = "risk_contract"
## 骇入协议扩展标识；启用后每名玩家在本局独立积攒碎片并获得可叠加协议。
const EXTENSION_HACK_PROTOCOL: String = "hack_protocol"

## 怪物数量词条类别；同一批候选最多出现一个数量强度档位。
const FAMILY_MONSTER_COUNT: String = "monster_count"
## 怪物移动速度词条类别；同一批候选最多出现一个移速强度档位。
const FAMILY_MONSTER_MOVE_SPEED: String = "monster_move_speed"
## 地图功能词条类别；当前只包含禁用右上角小地图。
const FAMILY_MAP: String = "map"
## 耐久消耗词条类别；当前只包含武器与防具耐久消耗翻倍。
const FAMILY_DURABILITY: String = "durability"
## 怪物生命词条类别；同一批候选最多出现一个生命强度档位。
const FAMILY_MONSTER_HEALTH: String = "monster_health"
## 怪物攻击力词条类别；同一批候选最多出现一个攻击力强度档位。
const FAMILY_MONSTER_ATTACK_POWER: String = "monster_attack_power"
## 玩家视野词条类别；同一批候选最多出现一个视野降低强度档位。
const FAMILY_PLAYER_VISION: String = "player_vision"
## 背包容量词条类别；同一批候选最多出现一个容量降低强度档位。
const FAMILY_BACKPACK_CAPACITY: String = "backpack_capacity"

## 默认风险候选数量；固定为四项，与风险合约界面和玩法规则一致。
const RISK_OFFER_COUNT: int = 4

## 模式扩展定义表；数组顺序即选择界面的展示顺序，每项保存稳定 ID、名称、说明与兼容条件。
const EXTENSION_DEFINITIONS: Array[Dictionary] = [
	{
		"id": EXTENSION_RISK_CONTRACT,
		"display_name": "风险合约",
		"description": "随机获得四个负面词条，至少选择一项后开局；每项词条都会提高本局怪物掉落概率。",
		"requires_settlement": true,
	},
	{
		"id": EXTENSION_HACK_PROTOCOL,
		"display_name": "骇入协议",
		"description": "局内积攒数据碎片并从三个随机协议中选择强化；协议越多，怪物数量越高且物品掉落率越低。",
		"requires_settlement": false,
	},
]

## 风险词条定义表；掉落加成为加算比例，局内最终怪物掉落倍率为 1 + 全部已选词条加成之和。
## 数量类词条本身已增加击杀与掉落机会，因此奖励低于同档生命、移速和攻击压力词条。
const RISK_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "monster_count_25",
		"display_name": "怪物数量+25%",
		"family": FAMILY_MONSTER_COUNT,
		"drop_bonus_ratio": 0.05,
		"population_multiplier": 1.25,
	},
	{
		"id": "monster_count_50",
		"display_name": "怪物数量+50%",
		"family": FAMILY_MONSTER_COUNT,
		"drop_bonus_ratio": 0.10,
		"population_multiplier": 1.50,
	},
	{
		"id": "monster_count_100",
		"display_name": "怪物数量+100%",
		"family": FAMILY_MONSTER_COUNT,
		"drop_bonus_ratio": 0.20,
		"population_multiplier": 2.00,
	},
	{
		"id": "monster_move_speed_25",
		"display_name": "怪物移速+25%",
		"family": FAMILY_MONSTER_MOVE_SPEED,
		"drop_bonus_ratio": 0.08,
		"monster_move_speed_multiplier": 1.25,
	},
	{
		"id": "monster_move_speed_50",
		"display_name": "怪物移速+50%",
		"family": FAMILY_MONSTER_MOVE_SPEED,
		"drop_bonus_ratio": 0.18,
		"monster_move_speed_multiplier": 1.50,
	},
	{
		"id": "monster_move_speed_100",
		"display_name": "怪物移速+100%",
		"family": FAMILY_MONSTER_MOVE_SPEED,
		"drop_bonus_ratio": 0.42,
		"monster_move_speed_multiplier": 2.00,
	},
	{
		"id": "disable_minimap",
		"display_name": "禁用小地图",
		"family": FAMILY_MAP,
		"drop_bonus_ratio": 0.10,
		"disable_minimap": true,
	},
	{
		"id": "durability_consumption_double",
		"display_name": "耐久消耗翻倍",
		"family": FAMILY_DURABILITY,
		"drop_bonus_ratio": 0.18,
		"durability_consumption_multiplier": 2.00,
	},
	{
		"id": "monster_health_25",
		"display_name": "怪物生命值+25%",
		"family": FAMILY_MONSTER_HEALTH,
		"drop_bonus_ratio": 0.10,
		"monster_health_multiplier": 1.25,
	},
	{
		"id": "monster_health_50",
		"display_name": "怪物生命值+50%",
		"family": FAMILY_MONSTER_HEALTH,
		"drop_bonus_ratio": 0.22,
		"monster_health_multiplier": 1.50,
	},
	{
		"id": "monster_health_100",
		"display_name": "怪物生命值+100%",
		"family": FAMILY_MONSTER_HEALTH,
		"drop_bonus_ratio": 0.50,
		"monster_health_multiplier": 2.00,
	},
	{
		"id": "monster_attack_power_50",
		"display_name": "怪物攻击力+50%",
		"family": FAMILY_MONSTER_ATTACK_POWER,
		"drop_bonus_ratio": 0.25,
		"monster_attack_power_multiplier": 1.50,
	},
	{
		"id": "monster_attack_power_100",
		"display_name": "怪物攻击力+100%",
		"family": FAMILY_MONSTER_ATTACK_POWER,
		"drop_bonus_ratio": 0.55,
		"monster_attack_power_multiplier": 2.00,
	},
	{
		"id": "player_vision_reduction_25",
		"display_name": "玩家视野降低25%",
		"family": FAMILY_PLAYER_VISION,
		"drop_bonus_ratio": 0.12,
		"player_vision_multiplier": 0.75,
	},
	{
		"id": "player_vision_reduction_50",
		"display_name": "玩家视野降低50%",
		"family": FAMILY_PLAYER_VISION,
		"drop_bonus_ratio": 0.32,
		"player_vision_multiplier": 0.50,
	},
	{
		"id": "backpack_capacity_reduction_25",
		"display_name": "背包空间上限-25%",
		"family": FAMILY_BACKPACK_CAPACITY,
		"drop_bonus_ratio": 0.10,
		"backpack_capacity_multiplier": 0.75,
	},
	{
		"id": "backpack_capacity_reduction_50",
		"display_name": "背包空间上限-50%",
		"family": FAMILY_BACKPACK_CAPACITY,
		"drop_bonus_ratio": 0.28,
		"backpack_capacity_multiplier": 0.50,
	},
	{
		"id": "backpack_capacity_reduction_75",
		"display_name": "背包空间上限-75%",
		"family": FAMILY_BACKPACK_CAPACITY,
		"drop_bonus_ratio": 0.60,
		"backpack_capacity_multiplier": 0.25,
	},
]


static func get_extension_definitions() -> Array[Dictionary]:
	## 返回模式扩展定义表深拷贝；UI 只读展示，不得修改共享常量字典。
	# 扩展定义结果；逐项深拷贝确保调用方无法回写规则表。
	var definitions: Array[Dictionary] = []
	for extension_definition in EXTENSION_DEFINITIONS:
		definitions.append(extension_definition.duplicate(true))
	return definitions


static func get_extension_definition(extension_id: String) -> Dictionary:
	## 按稳定 ID 返回模式扩展定义；未知 ID 返回空字典。
	for extension_definition in EXTENSION_DEFINITIONS:
		if str(extension_definition.get("id", "")) == extension_id:
			return extension_definition.duplicate(true)
	return {}


static func get_risk_definitions() -> Array[Dictionary]:
	## 返回全部风险词条定义深拷贝；顺序只用于文档和测试，不代表随机权重顺序。
	# 风险定义结果；逐项深拷贝防止 UI 勾选状态污染规则常量。
	var definitions: Array[Dictionary] = []
	for risk_definition in RISK_DEFINITIONS:
		definitions.append(risk_definition.duplicate(true))
	return definitions


static func get_risk_definition(modifier_id: String) -> Dictionary:
	## 按稳定 ID 返回风险词条定义；未知 ID 返回空字典，网络与会话规范化会直接丢弃该项。
	for risk_definition in RISK_DEFINITIONS:
		if str(risk_definition.get("id", "")) == modifier_id:
			return risk_definition.duplicate(true)
	return {}


static func normalize_extension_ids(raw_extension_ids: Array) -> Array[String]:
	## 规范化模式扩展 ID；只保留规则表中存在的唯一项，并恢复定义表的稳定展示顺序。
	# 请求集合；键为合法扩展 ID，值固定 true，用于去重且不信任外部数组顺序。
	var requested_ids: Dictionary = {}
	for raw_extension_id in raw_extension_ids:
		# 请求扩展 ID；去除首尾空白后只有规则表存在的项才加入集合。
		var extension_id: String = str(raw_extension_id).strip_edges()
		if not get_extension_definition(extension_id).is_empty():
			requested_ids[extension_id] = true
	# 标准扩展列表；按定义表顺序输出，保证单机、联机和 UI 摘要一致。
	var normalized_ids: Array[String] = []
	for extension_definition in EXTENSION_DEFINITIONS:
		# 定义扩展 ID；集合命中时只追加一次。
		var extension_id: String = str(extension_definition.get("id", ""))
		if requested_ids.has(extension_id):
			normalized_ids.append(extension_id)
	return normalized_ids


static func normalize_risk_modifier_ids(raw_modifier_ids: Array) -> Array[String]:
	## 规范化风险词条 ID；只保留合法项，并按定义顺序限制每类最多一档、整局最多四项。
	# 请求集合；外部数组中的重复项只保留一次。
	var requested_ids: Dictionary = {}
	for raw_modifier_id in raw_modifier_ids:
		# 请求词条 ID；未知值不会进入标准列表。
		var modifier_id: String = str(raw_modifier_id).strip_edges()
		if not get_risk_definition(modifier_id).is_empty():
			requested_ids[modifier_id] = true
	# 已使用类别集合；防止异常网络数据叠加同一类别多个强度档位。
	var used_families: Dictionary = {}
	# 标准词条列表；按规则表顺序输出，确保各端汇总顺序稳定。
	var normalized_ids: Array[String] = []
	for risk_definition in RISK_DEFINITIONS:
		# 当前词条 ID；请求未包含时跳过。
		var modifier_id: String = str(risk_definition.get("id", ""))
		if not requested_ids.has(modifier_id):
			continue
		# 当前效果类别；已使用时拒绝后续同类档位，避免数量、生命等倍率叠加失控。
		var family_id: String = str(risk_definition.get("family", ""))
		if used_families.has(family_id):
			continue
		used_families[family_id] = true
		normalized_ids.append(modifier_id)
		if normalized_ids.size() >= RISK_OFFER_COUNT:
			break
	return normalized_ids


static func sanitize_configuration(raw_extension_ids: Array, raw_modifier_ids: Array, hack_variant: String) -> Dictionary:
	## 规范化一整套模式扩展配置；不兼容扩展和没有选中词条的风险合约会被安全移除。
	# 标准扩展列表；先过滤未知 ID，再按骇入模式兼容性移除无效项。
	var extension_ids: Array[String] = normalize_extension_ids(raw_extension_ids)
	# 兼容扩展列表；只包含当前骇入模式能够实际产出效果的扩展。
	var compatible_extension_ids: Array[String] = []
	for extension_id in extension_ids:
		if is_extension_compatible(extension_id, hack_variant):
			compatible_extension_ids.append(extension_id)
	# 标准风险词条列表；风险合约未启用时必须清空，避免陈旧词条在下一局静默生效。
	var modifier_ids: Array[String] = normalize_risk_modifier_ids(raw_modifier_ids)
	if not compatible_extension_ids.has(EXTENSION_RISK_CONTRACT) or modifier_ids.is_empty():
		compatible_extension_ids.erase(EXTENSION_RISK_CONTRACT)
		modifier_ids.clear()
	return {
		"extension_ids": compatible_extension_ids,
		"risk_modifier_ids": modifier_ids,
	}


static func is_extension_compatible(extension_id: String, hack_variant: String) -> bool:
	## 判断扩展是否兼容当前骇入模式；需要结算的扩展在超频等娱乐模式中不可启用。
	# 扩展定义；未知 ID 直接不兼容，避免 UI 或网络生成未声明配置。
	var extension_definition: Dictionary = get_extension_definition(extension_id)
	if extension_definition.is_empty():
		return false
	if bool(extension_definition.get("requires_settlement", false)):
		return HackModeRules.is_settlement_enabled(hack_variant)
	return true


static func roll_risk_modifier_ids(random_source: RandomNumberGenerator, count: int = RISK_OFFER_COUNT, excluded_families: Array[String] = []) -> Array[String]:
	## 按效果类别无放回抽取风险词条；先均匀抽类别，再在该类别的强度档位中均匀抽一项。
	## random_source 为空时创建独立随机源；count 超过可用类别数时自动限制，不会返回同类多个档位。
	# 实际随机源；调用方传入固定种子可进行可重复测试，UI 默认传入已随机化实例。
	var resolved_random: RandomNumberGenerator = random_source
	if resolved_random == null:
		resolved_random = RandomNumberGenerator.new()
		resolved_random.randomize()
	# 排除类别集合；已选词条或当前候选中的类别不会再次进入抽取池。
	var excluded_family_lookup: Dictionary = {}
	for excluded_family in excluded_families:
		excluded_family_lookup[excluded_family] = true
	# 类别候选表；键为类别 ID，值为该类别下全部词条定义。
	var definitions_by_family: Dictionary = {}
	for risk_definition in RISK_DEFINITIONS:
		# 当前类别 ID；空类别或已排除类别不进入候选。
		var family_id: String = str(risk_definition.get("family", ""))
		if family_id.is_empty() or excluded_family_lookup.has(family_id):
			continue
		if not definitions_by_family.has(family_id):
			definitions_by_family[family_id] = []
		(definitions_by_family[family_id] as Array).append(risk_definition)
	# 可用类别数组；每轮随机移除一个类别，实现无放回抽取。
	var available_families: Array = definitions_by_family.keys()
	# 抽取结果；数量最多为请求值与可用类别数的较小值。
	var rolled_ids: Array[String] = []
	for _roll_index in range(mini(maxi(count, 0), available_families.size())):
		# 类别下标；从尚未使用的类别中均匀抽取。
		var family_index: int = resolved_random.randi_range(0, available_families.size() - 1)
		# 抽中类别；读取后立即从可用数组移除，保证同类最多一项。
		var family_id: String = str(available_families.pop_at(family_index))
		# 类别词条池；每个强度档位等概率出现。
		var family_definitions: Array = definitions_by_family.get(family_id, [])
		if family_definitions.is_empty():
			continue
		# 类别内词条；随机选择一档并写入稳定 ID。
		var risk_definition: Dictionary = family_definitions[resolved_random.randi_range(0, family_definitions.size() - 1)] as Dictionary
		rolled_ids.append(str(risk_definition.get("id", "")))
	return rolled_ids


static func get_risk_family(modifier_id: String) -> String:
	## 返回词条效果类别；未知词条返回空字符串，供候选填充与网络校验安全跳过。
	return str(get_risk_definition(modifier_id).get("family", ""))


static func get_total_drop_bonus_ratio(modifier_ids: Array) -> float:
	## 汇总已选风险词条的怪物掉落加成；所有合法项加算，同类重复项会先被规范化为一档。
	# 掉落加成总比例；0.25 表示怪物四类基础掉落概率统一提高 25%。
	var total_bonus_ratio: float = 0.0
	for modifier_id in normalize_risk_modifier_ids(modifier_ids):
		total_bonus_ratio += maxf(float(get_risk_definition(modifier_id).get("drop_bonus_ratio", 0.0)), 0.0)
	return total_bonus_ratio


static func get_effect_multipliers(modifier_ids: Array) -> Dictionary:
	## 汇总风险合约全部局内效果；各效果类别最多一档，缺失字段保持 1.0 或 false 的中性值。
	# 汇总结果；GameWorld、玩家组件和库存服务只读取这些稳定键，不解析具体词条 ID。
	var multipliers: Dictionary = {
		"population_multiplier": 1.0,
		"monster_move_speed_multiplier": 1.0,
		"monster_health_multiplier": 1.0,
		"monster_attack_power_multiplier": 1.0,
		"durability_consumption_multiplier": 1.0,
		"player_vision_multiplier": 1.0,
		"backpack_capacity_multiplier": 1.0,
		"drop_chance_multiplier": 1.0 + get_total_drop_bonus_ratio(modifier_ids),
		"disable_minimap": false,
	}
	for modifier_id in normalize_risk_modifier_ids(modifier_ids):
		# 当前词条定义；规范化后必定存在，仍保留空值安全回退。
		var risk_definition: Dictionary = get_risk_definition(modifier_id)
		for multiplier_key in [
			"population_multiplier",
			"monster_move_speed_multiplier",
			"monster_health_multiplier",
			"monster_attack_power_multiplier",
			"durability_consumption_multiplier",
			"player_vision_multiplier",
			"backpack_capacity_multiplier",
		]:
			if risk_definition.has(multiplier_key):
				multipliers[multiplier_key] = float(risk_definition.get(multiplier_key, 1.0))
		if bool(risk_definition.get("disable_minimap", false)):
			multipliers["disable_minimap"] = true
	return multipliers


static func get_configuration_summary(extension_ids: Array, modifier_ids: Array) -> String:
	## 返回玩家可见的模式扩展摘要；联机房间与选择面板共用，未启用时固定显示“未开启”。
	# 标准扩展列表；摘要不接受无词条风险合约等无效配置。
	var sanitized_configuration: Dictionary = sanitize_configuration(extension_ids, modifier_ids, HackModeRules.VARIANT_STANDARD)
	# 有效扩展 ID；摘要只展示当前已实现且合法的扩展。
	var normalized_extension_ids: Array = sanitized_configuration.get("extension_ids", [])
	if normalized_extension_ids.is_empty():
		return "未开启"
	# 摘要分段；每个模式扩展生成一个可独立阅读的片段。
	var summary_parts: Array[String] = []
	if normalized_extension_ids.has(EXTENSION_RISK_CONTRACT):
		# 总掉落加成百分比；四舍五入显示整数，与定义表当前整数百分点保持一致。
		var drop_bonus_percent: int = roundi(get_total_drop_bonus_ratio(sanitized_configuration.get("risk_modifier_ids", [])) * 100.0)
		# 风险词条数量；便于联机成员快速确认房主启用了多少项负面效果。
		var modifier_count: int = (sanitized_configuration.get("risk_modifier_ids", []) as Array).size()
		summary_parts.append("风险合约（%d项，掉落+%d%%）" % [modifier_count, drop_bonus_percent])
	if normalized_extension_ids.has(EXTENSION_HACK_PROTOCOL):
		summary_parts.append("骇入协议")
	return "、".join(summary_parts) if not summary_parts.is_empty() else "未开启"
