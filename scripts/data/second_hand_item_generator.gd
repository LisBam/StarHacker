extends RefCounted
class_name SecondHandItemGenerator

## 二手物品生成器集中处理武器与装备的二手判定、历史强化和耐久消耗。
## 怪物掉落、宝箱和商店共同调用本模块，确保三类来源使用完全一致的概率与数值规则。

## 二手武器装备出现概率；固定为 30%，每件新生成的武器或装备独立判定一次。
const SECOND_HAND_CHANCE: float = 0.30
## 二手物品最少耐久消耗百分比；固定为 1%，按整数百分点抽取并在全部历史强化完成后结算。
const DURABILITY_CONSUMPTION_PERCENT_MINIMUM: int = 1
## 二手物品最多耐久消耗百分比；固定为 99%，因此最差结果仍保留最大耐久的 1%。
const DURABILITY_CONSUMPTION_PERCENT_MAXIMUM: int = 99
## 二手物品最少历史强化石数量；固定为 1 颗，命中二手状态后必定拥有至少一次强化。
const ENHANCEMENT_STONE_COUNT_MINIMUM: int = 1
## 二手物品最多历史强化石数量；固定为 20 颗，与单把武器强化次数上限保持一致。
const ENHANCEMENT_STONE_COUNT_MAXIMUM: int = 20
## 单颗历史强化石寻找兼容词条的最大尝试次数；默认 128 次，保证标准武器装备稳定获得目标数量并为异常扩展资源保留退出边界。
const COMPATIBILITY_ATTEMPT_LIMIT_PER_STONE: int = 128
## 强化石兼容最少词条数量；正式词条数量由品质规则决定，该值只保持统一生成接口完整。
const STONE_MINIMUM_MODIFIER_COUNT: int = 1
## 强化石兼容最多词条数量；正式词条数量由品质规则决定，该值只保持统一生成接口完整。
const STONE_MAXIMUM_MODIFIER_COUNT: int = 3
## 强化石兼容削弱概率；正式削弱概率由品质规则决定，该值只保持统一生成接口完整。
const STONE_DETRIMENTAL_CHANCE: float = 0.28
## 强化石兼容基础价值；强化石最终价格由品质和正负词条数量计算，该值只保持统一生成接口完整。
const STONE_BASE_VALUE: int = 30


static func roll_and_apply(item_resource: Resource, random_source: RandomNumberGenerator, second_hand_chance: float = SECOND_HAND_CHANCE) -> Dictionary:
	## 对一件新生成的武器或装备执行二手概率判定；未命中时不修改资源并返回结构化结果。
	# 失败结果；调用方可直接读取统一字段，不需要分别判断空资源或随机失败。
	var unchanged_result: Dictionary = {"second_hand": false, "used_stone_count": 0, "durability_consumption_percent": 0}
	if item_resource == null or random_source == null or not _is_supported_item(item_resource):
		return unchanged_result
	# 实际二手概率；限制在 0 至 1，异常外部配置不会导致非法概率。
	var resolved_chance: float = clampf(second_hand_chance, 0.0, 1.0)
	if random_source.randf() >= resolved_chance:
		return unchanged_result
	return apply_second_hand_state(item_resource, random_source)


static func apply_second_hand_state(item_resource: Resource, random_source: RandomNumberGenerator) -> Dictionary:
	## 为已确定的二手武器装备生成 1 至 20 次历史强化，并随机消耗 1% 至 99% 的最终最大耐久。
	# 失败结果；资源缺失或不支持耐久接口时保持原状态。
	var failed_result: Dictionary = {"second_hand": false, "used_stone_count": 0, "durability_consumption_percent": 0}
	if item_resource == null or random_source == null or not _is_supported_item(item_resource) or not item_resource.has_method("set_current_durability"):
		return failed_result
	# 计划使用强化石数量；在 1 至 20 闭区间内等概率抽取，每颗继续使用正式品质分布与词条规则。
	var requested_stone_count: int = random_source.randi_range(ENHANCEMENT_STONE_COUNT_MINIMUM, ENHANCEMENT_STONE_COUNT_MAXIMUM)
	# 实际成功强化数量；标准武器装备应等于计划数量，异常扩展资源无法匹配任何词条时可能提前结束。
	var applied_stone_count: int = 0
	for _stone_index in range(requested_stone_count):
		if not _apply_random_compatible_enhancement(item_resource, random_source):
			break
		applied_stone_count += 1
	# 耐久消耗整数百分比；闭区间均匀抽取，1 表示消耗 1%，99 表示只剩 1%。
	var durability_consumption_percent: int = random_source.randi_range(DURABILITY_CONSUMPTION_PERCENT_MINIMUM, DURABILITY_CONSUMPTION_PERCENT_MAXIMUM)
	# 最大耐久；历史强化可能改变耐久上限，因此必须在全部强化完成后读取最终值。
	var maximum_durability: float = float(item_resource.call("get_maximum_durability")) if item_resource.has_method("get_maximum_durability") else maxf(float(item_resource.get("max_durability")), 1.0)
	# 剩余耐久比例；使用整数百分比换算并限制到 1% 至 99%，避免二手物品生成即损坏或保持满耐久。
	var remaining_durability_ratio: float = 1.0 - float(durability_consumption_percent) / 100.0
	item_resource.call("set_current_durability", maximum_durability * remaining_durability_ratio)
	item_resource.set("is_second_hand", true)
	return {"second_hand": true, "used_stone_count": applied_stone_count, "durability_consumption_percent": durability_consumption_percent}


static func _apply_random_compatible_enhancement(item_resource: Resource, random_source: RandomNumberGenerator) -> bool:
	## 生成并应用一颗与目标兼容的正式强化石；品质、词条数量、正负方向和幅度均复用玩家获取与锻造规则。
	# 强化石目标类型；装备固定使用装备石，所有武器类型固定使用武器石。
	var target_kind: String = "equipment" if str(item_resource.get("item_kind")) == "equipment" else "weapon"
	for _attempt_index in range(COMPATIBILITY_ATTEMPT_LIMIT_PER_STONE):
		# 历史强化石；不会进入玩家库存，但生成概率与怪物、宝箱和商店中的正常强化石完全一致。
		var enhancement_stone: EnhancementStoneData = EnhancementStoneData.create_random(random_source, STONE_MINIMUM_MODIFIER_COUNT, STONE_MAXIMUM_MODIFIER_COUNT, STONE_DETRIMENTAL_CHANCE, STONE_BASE_VALUE, target_kind)
		if enhancement_stone == null or not enhancement_stone.can_apply_to_weapon(item_resource):
			continue
		# 可应用词条；只保留目标真实拥有的共有属性，部位或攻击类型不兼容词条不会计入本次历史强化。
		var applicable_modifiers: Dictionary = enhancement_stone.get_applicable_modifiers_for_target(item_resource)
		# 实际强化幅度；每条词条按强化石品质和方向在正式闭区间内独立抽取。
		var rolled_modifiers: Dictionary = {}
		for stat_name in EnhancementRules.STAT_KEYS:
			if applicable_modifiers.has(stat_name):
				rolled_modifiers[stat_name] = EnhancementRules.roll_quality_modifier_ratio(random_source, enhancement_stone.get_resolved_quality_id(), stat_name, applicable_modifiers.get(stat_name, 1))
		if rolled_modifiers.is_empty():
			continue
		if item_resource.has_method("apply_enhancement_with_result"):
			# 强化结果；数据资源会在成功时同步累计强化次数，失败时不会占用次数。
			var enhancement_result: Dictionary = item_resource.call("apply_enhancement_with_result", rolled_modifiers) as Dictionary
			if bool(enhancement_result.get("success", false)):
				return true
		elif item_resource.has_method("apply_enhancement") and bool(item_resource.call("apply_enhancement", rolled_modifiers)):
			return true
	return false


static func _is_supported_item(item_resource: Resource) -> bool:
	## 判断资源是否为可生成二手状态的武器或四部位装备；其他道具与强化石不会进入该流程。
	if item_resource == null:
		return false
	# 物品类型；武器使用稳定 weapon 类型，装备使用稳定 equipment 类型。
	var item_kind: String = str(item_resource.get("item_kind"))
	return item_kind == "equipment" or (item_kind == "weapon" and str(item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"])
