extends RefCounted
class_name EnhancementRules

## 强化规则目录集中维护强化石属性名称、方向、实际步长和利弊判断。
## 强化石资源只保存 +1 或 -1 方向，所有数值换算和 UI 颜色都通过本目录完成，避免各模块产生不同解释。
## 品质化强化石会直接保存实际百分比；旧版 +1/-1 方向数据仍会通过固定 10% 步长自动迁移。
## 方向化重构后强化石资源统一只保存 +1/-1；品质百分比区间仅在消耗强化石时用于生成本次实际幅度。

## 单次强化固定比例；默认 0.10 表示每颗强化石的每条有效词条改变对应武器基础属性 10%。
const ENHANCEMENT_STEP_RATIO: float = 0.10
## 低级强化石稳定标识；用于随机权重、存档和堆叠签名，不应在运行时修改。
const QUALITY_LOW: String = "low"
## 中级强化石稳定标识；用于随机权重、存档和堆叠签名，不应在运行时修改。
const QUALITY_MEDIUM: String = "medium"
## 高级强化石稳定标识；用于随机权重、存档和堆叠签名，不应在运行时修改。
const QUALITY_HIGH: String = "high"
## 极品强化石稳定标识；用于随机权重、存档和堆叠签名，不应在运行时修改。
const QUALITY_SUPREME: String = "supreme"
## 品质抽取顺序；与权重表共同构成 40%/30%/20%/10% 的完整分布。
const QUALITY_ORDER: Array[String] = [QUALITY_LOW, QUALITY_MEDIUM, QUALITY_HIGH, QUALITY_SUPREME]
## 品质随机权重；总和为 1.0，调整任意值会直接改变怪物掉落品质分布。
const QUALITY_WEIGHTS: Dictionary = {
	QUALITY_LOW: 0.40,
	QUALITY_MEDIUM: 0.30,
	QUALITY_HIGH: 0.20,
	QUALITY_SUPREME: 0.10,
}
## 品质中文名称；用于掉落物、背包、仓库和结算界面的统一显示。
const QUALITY_DISPLAY_NAMES: Dictionary = {
	QUALITY_LOW: "低级强化石",
	QUALITY_MEDIUM: "中级强化石",
	QUALITY_HIGH: "高级强化石",
	QUALITY_SUPREME: "极品强化石",
}
## 品质数值配置；百分比使用 0 到 1 小数，额外增强和削弱均最多追加一条不重复属性。
const QUALITY_CONFIGS: Dictionary = {
	QUALITY_LOW: {"extra_beneficial_chance": 0.0, "detrimental_chance": 0.80, "beneficial_min": 0.10, "beneficial_max": 0.20, "detrimental_min": 0.10, "detrimental_max": 0.20},
	QUALITY_MEDIUM: {"extra_beneficial_chance": 0.10, "detrimental_chance": 0.40, "beneficial_min": 0.20, "beneficial_max": 0.40, "detrimental_min": 0.05, "detrimental_max": 0.20},
	QUALITY_HIGH: {"extra_beneficial_chance": 0.20, "detrimental_chance": 0.10, "beneficial_min": 0.30, "beneficial_max": 0.50, "detrimental_min": 0.05, "detrimental_max": 0.10},
	QUALITY_SUPREME: {"extra_beneficial_chance": 0.30, "detrimental_chance": 0.0, "beneficial_min": 0.40, "beneficial_max": 0.60, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 全部可随机生成的强化属性；顺序同时用于属性筛选下拉框和随机词条池。
const STAT_KEYS: Array[String] = [
	"damage",
	"cooldown",
	"energy_cost",
	"projectile_speed",
	"bullet_range",
	"spread_degrees",
	"recoil_force",
	"front_recoil_force",
	"impact_force",
	"melee_active_duration",
]
## 属性中文名称；键为统一属性名，值用于强化石、搜索、筛选和武器详情。
const STAT_LABELS: Dictionary = {
	"damage": "伤害",
	"cooldown": "冷却",
	"energy_cost": "能量消耗",
	"projectile_speed": "弹体速度",
	"bullet_range": "射程",
	"spread_degrees": "扩散",
	"recoil_force": "后坐力",
	"front_recoil_force": "前坐力",
	"impact_force": "冲击力",
	"melee_active_duration": "判定时长",
}
## 每项属性的有利数值方向；1 表示数值增加是强化，-1 表示数值减少是强化。
const BENEFICIAL_DIRECTIONS: Dictionary = {
	"damage": 1,
	"cooldown": -1,
	"energy_cost": -1,
	"projectile_speed": 1,
	"bullet_range": 1,
	"spread_degrees": -1,
	"recoil_force": -1,
	"front_recoil_force": 1,
	"impact_force": 1,
	"melee_active_duration": 1,
}


static func normalize_direction(raw_value: Variant) -> int:
	# 原始方向数值；兼容旧存档百分比，小于 0 归一化为 -1，大于等于 0 归一化为 +1。
	var numeric_value: float = float(raw_value)
	return -1 if numeric_value < 0.0 else 1


static func normalize_modifier_ratio(raw_value: Variant) -> float:
	# 原始词条比例；新版使用 -0.60 到 0.60 左右的实际比例，旧版使用精确 +1/-1 方向值。
	var numeric_value: float = float(raw_value)
	if is_zero_approx(numeric_value):
		return 0.0
	# 迁移后比例；绝对值接近 1 的旧方向存档按 10% 恢复，其他数值保留到整数百分点精度。
	var migrated_ratio: float = float(normalize_direction(numeric_value)) * ENHANCEMENT_STEP_RATIO if absf(numeric_value) >= 0.999 else numeric_value
	return snappedf(migrated_ratio, 0.01)


static func get_stat_label(stat_name: String) -> String:
	return str(STAT_LABELS.get(stat_name, stat_name))


static func get_direction_symbol(direction: int) -> String:
	return "+" if direction >= 0 else "-"


static func get_beneficial_direction(stat_name: String) -> int:
	return int(BENEFICIAL_DIRECTIONS.get(stat_name, 1))


static func is_direction_beneficial(stat_name: String, direction: Variant) -> bool:
	return normalize_direction(direction) == get_beneficial_direction(stat_name)


static func get_effect_ratio(direction: Variant) -> float:
	return normalize_modifier_ratio(direction)


static func normalize_modifiers(modifiers: Dictionary) -> Dictionary:
	# 归一化词典；只保留规则目录已登记属性，并将旧百分比值转换为 +1 或 -1。
	var normalized_modifiers: Dictionary = {}
	for stat_name in STAT_KEYS:
		if modifiers.has(stat_name):
			# 实际词条比例；保留品质随机的幅度，同时忽略无效的 0% 词条。
			var modifier_ratio: float = normalize_modifier_ratio(modifiers.get(stat_name, 0.0))
			if not is_zero_approx(modifier_ratio):
				# 方向化强化石只持久化 +1 或 -1；旧存档中的具体百分比读取后仅保留方向，实际幅度延迟到使用瞬间生成。
				normalized_modifiers[stat_name] = normalize_direction(modifier_ratio)
	return normalized_modifiers


static func build_modifier_token(stat_name: String, direction: Variant, include_percentage: bool = false) -> String:
	# 标准化比例；旧强化石会在此自动转换为 10%，新强化石保留实际整数百分点。
	var modifier_ratio: float = normalize_modifier_ratio(direction)
	# 方向文本；搜索可使用不带百分比版本，物品详情默认展示完整数值。
	var direction_text: String = "%s%s" % [get_stat_label(stat_name), get_direction_symbol(normalize_direction(modifier_ratio))]
	return "%s%d%%" % [direction_text, roundi(absf(modifier_ratio) * 100.0)] if include_percentage else direction_text


static func roll_quality_modifier_ratio(random_source: RandomNumberGenerator, quality_id: String, stat_name: String, direction: Variant) -> float:
	if random_source == null or stat_name not in STAT_KEYS:
		return 0.0
	# 方向化词条；资源只保存正负方向，实际强化幅度在每次使用时根据品质重新抽取。
	var modifier_direction: int = normalize_direction(direction)
	# 品质配置；增强和削弱分别使用各品质独立区间，保证低级、中级、高级和极品的幅度差异集中维护。
	var quality_config: Dictionary = get_quality_config(quality_id)
	# 是否为玩法增强；冷却、扩散和后坐力的负方向仍属于增强，不按数值正负误判收益。
	var beneficial: bool = is_direction_beneficial(stat_name, modifier_direction)
	# 最小随机比例；削弱区间缺失时回退增强区间，兼容旧存档中理论上不会生成的异常品质方向组合。
	var minimum_ratio: float = float(quality_config.get("beneficial_min" if beneficial else "detrimental_min", 0.0))
	# 最大随机比例；与最小值共同形成闭区间整数百分点抽取范围。
	var maximum_ratio: float = float(quality_config.get("beneficial_max" if beneficial else "detrimental_max", 0.0))
	if maximum_ratio <= 0.0:
		minimum_ratio = float(quality_config.get("beneficial_min", ENHANCEMENT_STEP_RATIO))
		maximum_ratio = float(quality_config.get("beneficial_max", ENHANCEMENT_STEP_RATIO))
	# 最小整数百分点；例如 0.10 转换为 10，避免浮点随机造成不可追踪的小数精度。
	var minimum_percent: int = roundi(minf(minimum_ratio, maximum_ratio) * 100.0)
	# 最大整数百分点；例如 0.60 转换为 60，与最小值组成闭区间。
	var maximum_percent: int = roundi(maxf(minimum_ratio, maximum_ratio) * 100.0)
	return float(random_source.randi_range(minimum_percent, maximum_percent)) / 100.0 * float(modifier_direction)


static func get_quality_display_name(quality_id: String) -> String:
	return str(QUALITY_DISPLAY_NAMES.get(quality_id, QUALITY_DISPLAY_NAMES[QUALITY_LOW]))


static func get_quality_config(quality_id: String) -> Dictionary:
	# 品质配置副本；调用方可以读取但不会意外修改全局常量。
	var quality_config: Dictionary = QUALITY_CONFIGS.get(quality_id, QUALITY_CONFIGS[QUALITY_LOW]) as Dictionary
	return quality_config.duplicate(true)


static func roll_quality(random_source: RandomNumberGenerator) -> String:
	if random_source == null:
		return QUALITY_LOW
	# 品质随机值；取值 [0, 1)，依次落入 40%/30%/20%/10% 累计区间。
	var quality_roll: float = random_source.randf()
	# 累计权重；从 0 递增到 1，用于将随机值映射到稳定品质。
	var cumulative_weight: float = 0.0
	for quality_id in QUALITY_ORDER:
		cumulative_weight += float(QUALITY_WEIGHTS.get(quality_id, 0.0))
		if quality_roll < cumulative_weight:
			return quality_id
	return QUALITY_SUPREME
