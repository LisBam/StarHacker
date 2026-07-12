extends Resource
class_name EnhancementStoneData

## 强化石数据资源描述可堆叠的武器强化材料及其属性方向词条。
## 同一属性集合与增减方向完全一致的强化石拥有相同堆叠签名，仓库和背包最多将其合并为 99 个一组。
## 品质化强化石使用“品质 + 属性 + 实际百分比”作为堆叠条件，增强词条始终排在削弱词条之前。
## 方向化重构后堆叠条件改为“品质 + 属性 + 方向”，同组每颗强化石使用时都会重新随机具体幅度。

## 单词条标准价值；固定 30 金币，生成和升阶都按最终词条数量重新计算总价值。
const VALUE_PER_MODIFIER: int = 30

## 物品类型；固定为 enhancement_stone，供库存、分类和 UI 与武器资源解耦识别。
@export var item_kind: String = "enhancement_stone"
## 强化石品质标识；取值为 low、medium、high 或 supreme，默认 low 用于旧存档迁移。
@export_enum("low", "medium", "high", "supreme") var quality_id: String = EnhancementRules.QUALITY_LOW
## 强化石适用类型；weapon 只能强化武器，equipment 只能强化装备。
@export_enum("weapon", "equipment") var target_kind: String = "weapon"
## 强化石显示名称；默认“强化石”，随机生成时会按词条数量补充品质描述。
@export var display_name: String = "强化石"
## 强化石说明；默认说明属性方向词条用途，运行时通常不动态修改。
@export_multiline var description: String = "用于强化武器，属性增减方向会永久累计到所选武器。"
## 强化石图标文本；默认菱形符号，地面掉落和资源方格共用该简写。
@export var icon_text: String = "◆"
## 单颗基础价值；取值大于等于 0，实际出售整组时会乘以堆叠数量。
@export_range(0, 999999, 1) var value: int = VALUE_PER_MODIFIER
## 强化方向词典；键为统一属性名，值只使用 +1 或 -1，旧存档百分比会按正负号自动归一化。
@export var modifiers: Dictionary = {}


func get_stack_signature() -> String:
	# 归一化词典；签名只关心属性和方向，因此旧百分比强化石可以与新版同方向强化石堆叠。
	var normalized_modifiers: Dictionary = get_normalized_modifiers()
	# 排序后的属性键；稳定排序保证相同词条不会因 Dictionary 遍历顺序不同而拆成两组。
	var sorted_keys: Array[String] = []
	# 原始属性键；只接收非空字符串，异常字段不会污染堆叠签名。
	for raw_key in normalized_modifiers.keys():
		var modifier_key: String = str(raw_key)
		if not modifier_key.is_empty():
			sorted_keys.append(modifier_key)
	sorted_keys.sort()

	# 签名片段；只写入 +1 或 -1，避免随机百分比导致大量无法合并的小堆叠。
	var signature_parts: PackedStringArray = PackedStringArray()
	# 品质签名片段；同词条但不同品质不会合并，避免显示名称和价值丢失。
	signature_parts.append("quality=%s" % get_resolved_quality_id())
	signature_parts.append("target=%s" % get_resolved_target_kind())
	for modifier_key in sorted_keys:
		# 词条百分比；按 0.01 精度序列化，只有品质、属性和数值都一致时才能堆叠。
		var modifier_ratio: float = float(normalized_modifiers.get(modifier_key, 0.0))
		# 方向化堆叠签名；同品质、同属性、同方向的强化石合并，使用时再各自随机实际幅度。
		signature_parts.append("%s=%d" % [modifier_key, EnhancementRules.normalize_direction(modifier_ratio)])
	return "|".join(signature_parts)


func get_effective_value() -> int:
	return maxi(value, 0)


func can_apply_to_weapon(weapon_data: Resource) -> bool:
	# 可应用词条；只要强化石与目标存在至少一个共有属性，该目标就属于合法锻造目标。
	var applicable_modifiers: Dictionary = get_applicable_modifiers_for_target(weapon_data)
	return not applicable_modifiers.is_empty()


func get_applicable_modifiers_for_target(target_resource: Resource) -> Dictionary:
	# 可应用词条；返回强化石词条与目标实际拥有属性的交集，锻造合法性和最终结算必须共用该结果。
	var applicable_modifiers: Dictionary = {}
	if target_resource == null:
		return applicable_modifiers
	# 目标是否为装备；武器强化石与装备强化石继续保持类型隔离，不能跨类型形成共有属性。
	var target_is_equipment: bool = str(target_resource.get("item_kind")) == "equipment"
	if (get_resolved_target_kind() == "equipment") != target_is_equipment:
		return applicable_modifiers
	# 归一化词条；旧属性别名和旧百分比方向在求交集前转换，避免同一属性出现两种兼容结果。
	var normalized_modifiers: Dictionary = get_normalized_modifiers()
	if normalized_modifiers.is_empty():
		return applicable_modifiers
	if target_resource.has_method("can_apply_enhancement"):
		for raw_stat_name in normalized_modifiers.keys():
			# 单属性候选；逐条查询目标能力，保证部分兼容强化石不会因其他无关词条被整体拒绝。
			var stat_name: String = str(raw_stat_name)
			# 单属性词典；复用目标现有兼容接口，不让强化石数据层依赖武器或装备的具体字段集合。
			var single_modifier: Dictionary = {stat_name: normalized_modifiers.get(raw_stat_name, 0.0)}
			if bool(target_resource.call("can_apply_enhancement", single_modifier)):
				applicable_modifiers[stat_name] = normalized_modifiers.get(raw_stat_name, 0.0)
		return applicable_modifiers
	# 旧扩展资源兼容；未实现逐词条能力接口的武器沿用完整词条，实际应用仍由资源自身接口决定。
	if not target_is_equipment and not str(target_resource.get("weapon_type")).is_empty():
		return normalized_modifiers
	return applicable_modifiers


func get_normalized_modifiers() -> Dictionary:
	return EnhancementRules.normalize_modifiers(modifiers)


func get_resolved_quality_id() -> String:
	return quality_id if quality_id in EnhancementRules.QUALITY_ORDER else EnhancementRules.QUALITY_LOW


func get_resolved_target_kind() -> String:
	return target_kind if target_kind in ["weapon", "equipment"] else "weapon"


func create_upgraded_copy() -> EnhancementStoneData:
	# 下一品质；空字符串表示当前已经是极品强化石，不能再生成更高阶资源。
	var next_quality_id: String = EnhancementRules.get_next_quality_id(get_resolved_quality_id())
	if next_quality_id.is_empty():
		return null
	# 升阶资源；完整复制词条方向、说明、图标和价值，仅替换品质与统一显示名称，保证主石特征不会被重新随机。
	var upgraded_stone: EnhancementStoneData = duplicate(true) as EnhancementStoneData
	if upgraded_stone == null:
		return null
	upgraded_stone.quality_id = next_quality_id
	if next_quality_id == EnhancementRules.QUALITY_SUPREME:
		# 极品词条；移除主石原有削弱方向，确保升阶生成的极品强化石同样遵守“无削弱”规则。
		var supreme_modifiers: Dictionary = upgraded_stone.get_normalized_modifiers()
		for raw_stat_name in supreme_modifiers.keys():
			# 属性名；来自规则目录，用于按玩法利弊识别并移除削弱词条。
			var stat_name: String = str(raw_stat_name)
			if not EnhancementRules.is_direction_beneficial(stat_name, supreme_modifiers.get(stat_name, 1)):
				supreme_modifiers.erase(stat_name)
		upgraded_stone.modifiers = supreme_modifiers
	# 升阶价值；严格保持“30 × 最终词条数量”，移除极品削弱词条后不会保留旧的高价值。
	upgraded_stone.value = VALUE_PER_MODIFIER * upgraded_stone.get_normalized_modifiers().size()
	upgraded_stone.display_name = _build_display_name(next_quality_id, upgraded_stone.get_resolved_target_kind())
	return upgraded_stone


func get_modifier_tokens(beneficial_only: bool = false) -> PackedStringArray:
	# 可见词条；按规则目录稳定顺序生成“伤害+”“冷却+”等不含具体数值的短文本。
	var modifier_tokens: PackedStringArray = PackedStringArray()
	# 归一化词典；兼容旧存档并用于利弊判断。
	var normalized_modifiers: Dictionary = get_normalized_modifiers()
	_append_modifier_tokens(modifier_tokens, normalized_modifiers, true)
	if not beneficial_only:
		_append_modifier_tokens(modifier_tokens, normalized_modifiers, false)
	return modifier_tokens


func get_pickup_preview_name() -> String:
	# 正向属性预览；地面掉落不显示削弱词条，避免玩家需要在拾取列表阅读负面信息。
	# 预览属性名称；按用户阅读需求省略方向符号，只显示“强化石（伤害 攻击距离）”。
	var preview_labels: PackedStringArray = PackedStringArray()
	# 归一化词典；预览只根据有利方向筛选属性，不显示百分比和任何削弱词条。
	var normalized_modifiers: Dictionary = get_normalized_modifiers()
	for stat_name in EnhancementRules.STAT_KEYS:
		if normalized_modifiers.has(stat_name) and EnhancementRules.is_direction_beneficial(stat_name, normalized_modifiers.get(stat_name, 0.0)):
			preview_labels.append(EnhancementRules.get_stat_label(stat_name))
	if preview_labels.is_empty():
		return display_name
	return "%s（%s）" % [display_name, " ".join(preview_labels)]


static func create_random(random_source: RandomNumberGenerator, minimum_modifier_count: int = 1, maximum_modifier_count: int = 3, detrimental_modifier_chance: float = 0.28, base_value: int = VALUE_PER_MODIFIER, requested_target_kind: String = "") -> EnhancementStoneData:
	if random_source == null:
		return null
	# 兼容参数快照；保留旧调用签名以避免扩展脚本失效，当前词条数和削弱概率完全由品质规则决定。
	var _legacy_generation_parameters: Array = [minimum_modifier_count, maximum_modifier_count, detrimental_modifier_chance]
	# 最小词条数；限制在规则目录属性数量内。
	var resolved_minimum_count: int = 1
	# 最大词条数；至少等于最小词条数并限制在规则目录属性数量内。
	var resolved_maximum_count: int = 3
	# 实际词条数；在配置范围内等概率随机。
	var modifier_count: int = resolved_minimum_count
	# 随机品质；按 40% 低级、30% 中级、20% 高级、10% 极品的权重抽取。
	var generated_quality_id: String = EnhancementRules.roll_quality(random_source)
	# 品质配置；包含额外增强概率、削弱概率和两类词条幅度区间。
	var quality_config: Dictionary = EnhancementRules.get_quality_config(generated_quality_id)
	# 额外增强抽取结果；每颗石头只抽取一次，中级、高级和极品分别使用 10%、20%、30% 概率。
	var rolled_extra_beneficial: bool = random_source.randf() < float(quality_config.get("extra_beneficial_chance", 0.0))
	# 削弱抽取结果；每颗石头只抽取一次，概率由品质规则决定。
	var rolled_detrimental: bool = random_source.randf() < float(quality_config.get("detrimental_chance", 0.0))
	modifier_count = clampi(1 + (1 if rolled_extra_beneficial else 0) + (1 if rolled_detrimental else 0), resolved_minimum_count, resolved_maximum_count)
	# 随机属性候选池；抽中后立即移除，保证同一颗强化石不会出现重复属性。
	# 适用类型；未指定时武器石与装备石等概率生成。
	var generated_target_kind: String = requested_target_kind if requested_target_kind in ["weapon", "equipment"] else ("weapon" if random_source.randf() < 0.5 else "equipment")
	# 对应属性池；不会生成另一类型的无效属性。
	var available_stats: Array[String] = (EnhancementRules.WEAPON_STAT_KEYS if generated_target_kind == "weapon" else EnhancementRules.EQUIPMENT_STAT_KEYS).duplicate()
	# 随机属性顺序；逐项执行不放回加权抽取，稀有属性单项权重固定为常规属性的五分之一。
	var shuffled_stats: Array[String] = []
	while not available_stats.is_empty():
		shuffled_stats.append(_take_weighted_stat(random_source, available_stats))

	# 随机方向词典；每项只保存 +1 或 -1，不再生成具体百分比。
	# 品质化数值补充；当前字典实际保存带方向的 0.05 至 0.60 比例，上述方向说明仅用于旧存档语义。
	# 方向化生成补充；当前字典只写入 +1 或 -1，品质范围由使用流程延迟抽取。
	var generated_modifiers: Dictionary = {}
	# 增强词条数；必定至少一条，中级、高级和极品可按各自概率增加第二条。
	var beneficial_modifier_count: int = 1 + (1 if rolled_extra_beneficial else 0)
	# 是否生成削弱词条；由最终词条数和额外增强结果共同推导。
	var has_detrimental_modifier: bool = rolled_detrimental
	for stat_index in range(beneficial_modifier_count):
		# 属性名称；来自已洗牌属性池前 modifier_count 项。
		var stat_name: String = shuffled_stats[stat_index]
		# 有利方向；不同属性的增强方向不同，例如伤害增加、冷却减少。
		var beneficial_direction: int = EnhancementRules.get_beneficial_direction(stat_name)
		generated_modifiers[stat_name] = beneficial_direction
	if has_detrimental_modifier and beneficial_modifier_count < shuffled_stats.size():
		# 削弱属性；使用尚未被增强词条占用的下一个属性，避免同属性在一颗石头上自我抵消。
		var detrimental_stat_name: String = shuffled_stats[beneficial_modifier_count]
		# 削弱数值方向；始终与该属性的有利方向相反。
		var detrimental_direction: int = -EnhancementRules.get_beneficial_direction(detrimental_stat_name)
		generated_modifiers[detrimental_stat_name] = detrimental_direction

	# 强化石资源；名称保持统一以提升同类识别，价值按词条数量线性增长。
	var enhancement_stone: EnhancementStoneData = EnhancementStoneData.new()
	enhancement_stone.quality_id = generated_quality_id
	enhancement_stone.target_kind = generated_target_kind
	enhancement_stone.display_name = _build_display_name(generated_quality_id, generated_target_kind)
	enhancement_stone.description = "用于强化%s，属性方向会永久累计到对应目标。" % ("装备" if generated_target_kind == "equipment" else "武器")
	enhancement_stone.value = maxi(base_value * modifier_count, 0)
	enhancement_stone.modifiers = generated_modifiers
	return enhancement_stone


static func _take_weighted_stat(random_source: RandomNumberGenerator, available_stats: Array[String]) -> String:
	# 总权重；常规属性贡献 1，稀有属性贡献 0.2，修改规则目录会自动影响所有强化石来源。
	var total_weight: float = 0.0
	for stat_name in available_stats:
		total_weight += EnhancementRules.get_generation_weight(stat_name)
	# 权重落点；范围为 0 到总权重，逐项扣减后确定本次抽中的唯一属性。
	var weight_roll: float = random_source.randf() * total_weight
	for stat_index in range(available_stats.size()):
		# 候选属性；按规则目录权重参与抽取，抽中后从原数组移除。
		var stat_name: String = available_stats[stat_index]
		weight_roll -= EnhancementRules.get_generation_weight(stat_name)
		if weight_roll <= 0.0:
			available_stats.remove_at(stat_index)
			return stat_name
	# 浮点边界兜底属性；取最后一项并移除，确保候选池始终缩小。
	var fallback_stat: String = available_stats.pop_back()
	return fallback_stat


static func _build_display_name(quality: String, stone_target_kind: String) -> String:
	return "%s%s强化石" % [EnhancementRules.get_quality_display_name(quality).trim_suffix("强化石"), "装备" if stone_target_kind == "equipment" else "武器"]


func _append_modifier_tokens(target_tokens: PackedStringArray, normalized_modifiers: Dictionary, beneficial: bool) -> void:
	# 属性遍历顺序；固定使用规则目录顺序，同类强化石的显示和搜索文本保持稳定。
	for stat_name in EnhancementRules.STAT_KEYS:
		if not normalized_modifiers.has(stat_name):
			continue
		# 词条实际比例；正负号与属性有利方向共同决定它属于增强还是削弱。
		var modifier_ratio: float = float(normalized_modifiers.get(stat_name, 0.0))
		if EnhancementRules.is_direction_beneficial(stat_name, modifier_ratio) != beneficial:
			continue
		target_tokens.append(EnhancementRules.build_modifier_token(stat_name, modifier_ratio, false))


static func _roll_ratio(random_source: RandomNumberGenerator, minimum_ratio: float, maximum_ratio: float) -> float:
	# 最小整数百分点；例如 0.10 转换为 10，用于生成可精确序列化的数值。
	var minimum_percent: int = roundi(minf(minimum_ratio, maximum_ratio) * 100.0)
	# 最大整数百分点；例如 0.60 转换为 60，与最小值闭区间随机。
	var maximum_percent: int = roundi(maxf(minimum_ratio, maximum_ratio) * 100.0)
	return float(random_source.randi_range(minimum_percent, maximum_percent)) / 100.0
