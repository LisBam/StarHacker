extends RefCounted
class_name EnhancementRules

## 强化规则目录集中维护强化石属性名称、方向、实际步长和利弊判断。
## 强化石资源只保存 +1 或 -1 方向，所有数值换算和 UI 颜色都通过本目录完成，避免各模块产生不同解释。
## 品质化强化石会直接保存实际百分比；旧版 +1/-1 方向数据仍会通过固定 10% 步长自动迁移。
## 方向化重构后强化石资源统一只保存 +1/-1；品质百分比区间仅在消耗强化石时用于生成本次实际幅度。

## 单次强化固定比例；默认 0.10 表示每颗强化石的每条有效词条改变对应武器基础属性 10%。
## 旧调用兼容补充：该步长只用于把历史 +1/-1 直接调用迁移为 10%，现行强化石实际幅度全部由属性独立区间抽取。
const ENHANCEMENT_STEP_RATIO: float = 0.10
## 乘算百分比公式标识；对应“基础值 × (1 + 累计比例)”，用于普通数值属性的统一结算。
const CALCULATION_MULTIPLICATIVE_RATIO: String = "multiplicative_ratio"
## 加算百分点公式标识；对应“基础值 + 累计百分点”，用于暴击率、暴击伤害与闪避率。
const CALCULATION_ADDITIVE_POINTS: String = "additive_points"
## 加算数值公式标识；对应“基础值 + 累计数值”，用于能量恢复和武器离散计数属性。
const CALCULATION_ADDITIVE_VALUE: String = "additive_value"
## 一级乘算属性组标识；用于伤害、攻击力、防御力、最大生命值、视野和冷却的独立幅度配置。
const MAGNITUDE_GROUP_PRIMARY: String = "primary"
## 二级乘算属性组标识；用于移速、能耗、偏移、坐力、冲击力和回血的独立幅度配置。
const MAGNITUDE_GROUP_SECONDARY: String = "secondary"
## 三级乘算属性组标识；用于弹体速度、攻击距离、判定时长和耐久值的独立幅度配置。
## 属性名称补充：max_durability 的现行玩家可见名称统一为“耐久”，含义是改变武器或装备耐久上限。
const MAGNITUDE_GROUP_TERTIARY: String = "tertiary"
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
	QUALITY_LOW: "初级强化石",
	QUALITY_MEDIUM: "中级强化石",
	QUALITY_HIGH: "高级强化石",
	QUALITY_SUPREME: "极品强化石",
}
## 强化石升阶映射；初级依次升为中级、高级和极品，极品没有下一品质并禁止继续升阶。
const QUALITY_UPGRADE_PATH: Dictionary = {
	QUALITY_LOW: QUALITY_MEDIUM,
	QUALITY_MEDIUM: QUALITY_HIGH,
	QUALITY_HIGH: QUALITY_SUPREME,
}
## 品质数值配置；百分比使用 0 到 1 小数，额外增强和削弱均最多追加一条不重复属性。
## 幅度配置补充：本表中的历史 min/max 键仅保留扩展兼容，现行随机幅度读取 MULTIPLICATIVE_MAGNITUDE_RANGES 或 ADDITIVE_POINT_MAGNITUDE_RANGES。
const QUALITY_CONFIGS: Dictionary = {
	QUALITY_LOW: {"extra_beneficial_chance": 0.0, "detrimental_chance": 0.80, "beneficial_min": 0.10, "beneficial_max": 0.20, "detrimental_min": 0.10, "detrimental_max": 0.20},
	QUALITY_MEDIUM: {"extra_beneficial_chance": 0.10, "detrimental_chance": 0.40, "beneficial_min": 0.20, "beneficial_max": 0.40, "detrimental_min": 0.05, "detrimental_max": 0.20},
	QUALITY_HIGH: {"extra_beneficial_chance": 0.20, "detrimental_chance": 0.10, "beneficial_min": 0.30, "beneficial_max": 0.50, "detrimental_min": 0.05, "detrimental_max": 0.10},
	QUALITY_SUPREME: {"extra_beneficial_chance": 0.30, "detrimental_chance": 0.0, "beneficial_min": 0.40, "beneficial_max": 0.60, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 乘算属性的幅度组归属；新增乘算属性时必须在此登记，避免回退到错误的共享品质区间。
const MULTIPLICATIVE_STAT_GROUPS: Dictionary = {
	"damage": MAGNITUDE_GROUP_PRIMARY,
	"attack_power": MAGNITUDE_GROUP_PRIMARY,
	"max_health": MAGNITUDE_GROUP_PRIMARY,
	"vision_range": MAGNITUDE_GROUP_PRIMARY,
	"cooldown": MAGNITUDE_GROUP_PRIMARY,
	"defense_power": MAGNITUDE_GROUP_PRIMARY,
	"energy_consumption": MAGNITUDE_GROUP_SECONDARY,
	"deviation_degrees": MAGNITUDE_GROUP_SECONDARY,
	"recoil_force": MAGNITUDE_GROUP_SECONDARY,
	"front_recoil_force": MAGNITUDE_GROUP_SECONDARY,
	"impact_force": MAGNITUDE_GROUP_SECONDARY,
	"health_regeneration_per_five_seconds": MAGNITUDE_GROUP_SECONDARY,
	"move_speed": MAGNITUDE_GROUP_SECONDARY,
	"projectile_speed": MAGNITUDE_GROUP_TERTIARY,
	"attack_distance": MAGNITUDE_GROUP_TERTIARY,
	"melee_active_duration": MAGNITUDE_GROUP_TERTIARY,
	"max_durability": MAGNITUDE_GROUP_TERTIARY,
}
## 加算百分点属性目录；字典值固定为公式标识，供数据资源、结果 UI 和存档迁移共用同一分类。
const ADDITIVE_POINT_STATS: Dictionary = {
	"critical_chance": CALCULATION_ADDITIVE_POINTS,
	"critical_damage": CALCULATION_ADDITIVE_POINTS,
	"dodge_chance": CALCULATION_ADDITIVE_POINTS,
	"cooldown_reduction": CALCULATION_ADDITIVE_POINTS,
}
## 加算数值属性目录；这些属性直接累加实际点数，不按基础值百分比换算。
const ADDITIVE_VALUE_STATS: Dictionary = {
	"scatter_count": CALCULATION_ADDITIVE_VALUE,
	"piercing_count": CALCULATION_ADDITIVE_VALUE,
	"bounce_count": CALCULATION_ADDITIVE_VALUE,
	"combo_count": CALCULATION_ADDITIVE_VALUE,
	"energy_regeneration": CALCULATION_ADDITIVE_VALUE,
}
## 稀有属性相对常规属性的刷新权重；0.2 表示单项权重为常规属性的五分之一。
const RARE_STAT_RELATIVE_WEIGHT: float = 0.20
## 稀有属性目录；强化石、商店历史强化和其他复用随机生成器的系统统一读取该集合。
## 武器离散机制不再进入强化石池，因此当前只有移速、视野和能量恢复使用五分之一生成权重。
const RARE_STAT_KEYS: Array[String] = ["move_speed", "vision_range", "energy_regeneration"]
## 加算数值属性独立幅度；能量恢复严格使用品质区间，武器离散计数每次固定改变 1。
## 离散计数配置仅保留旧武器累计强化与历史直接调用兼容；正式强化石属性池不会再生成这些词条。
const ADDITIVE_VALUE_MAGNITUDE_RANGES: Dictionary = {
	"scatter_count": {
		QUALITY_LOW: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_MEDIUM: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_HIGH: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_SUPREME: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
	"piercing_count": {
		QUALITY_LOW: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_MEDIUM: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_HIGH: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_SUPREME: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
	"bounce_count": {
		QUALITY_LOW: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_MEDIUM: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_HIGH: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_SUPREME: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
	"combo_count": {
		QUALITY_LOW: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_MEDIUM: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_HIGH: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 1.0, "detrimental_max": 1.0},
		QUALITY_SUPREME: {"beneficial_min": 1.0, "beneficial_max": 1.0, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
	"energy_regeneration": {
		QUALITY_LOW: {"beneficial_min": 0.4, "beneficial_max": 1.0, "detrimental_min": 0.4, "detrimental_max": 0.9},
		QUALITY_MEDIUM: {"beneficial_min": 0.8, "beneficial_max": 1.7, "detrimental_min": 0.2, "detrimental_max": 0.8},
		QUALITY_HIGH: {"beneficial_min": 1.5, "beneficial_max": 2.5, "detrimental_min": 0.2, "detrimental_max": 0.6},
		QUALITY_SUPREME: {"beneficial_min": 2.1, "beneficial_max": 3.4, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
}
## 乘算属性分组幅度；所有数值使用小数比例，增强与削弱按品质分别维护闭区间。
const MULTIPLICATIVE_MAGNITUDE_RANGES: Dictionary = {
	MAGNITUDE_GROUP_PRIMARY: {
		QUALITY_LOW: {"beneficial_min": 0.005, "beneficial_max": 0.012, "detrimental_min": 0.005, "detrimental_max": 0.012},
		QUALITY_MEDIUM: {"beneficial_min": 0.010, "beneficial_max": 0.020, "detrimental_min": 0.003, "detrimental_max": 0.010},
		QUALITY_HIGH: {"beneficial_min": 0.018, "beneficial_max": 0.030, "detrimental_min": 0.003, "detrimental_max": 0.008},
		QUALITY_SUPREME: {"beneficial_min": 0.025, "beneficial_max": 0.040, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
	MAGNITUDE_GROUP_SECONDARY: {
		QUALITY_LOW: {"beneficial_min": 0.024, "beneficial_max": 0.054, "detrimental_min": 0.024, "detrimental_max": 0.054},
		QUALITY_MEDIUM: {"beneficial_min": 0.045, "beneficial_max": 0.090, "detrimental_min": 0.015, "detrimental_max": 0.045},
		QUALITY_HIGH: {"beneficial_min": 0.075, "beneficial_max": 0.120, "detrimental_min": 0.015, "detrimental_max": 0.030},
		QUALITY_SUPREME: {"beneficial_min": 0.105, "beneficial_max": 0.150, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
	MAGNITUDE_GROUP_TERTIARY: {
		QUALITY_LOW: {"beneficial_min": 0.050, "beneficial_max": 0.110, "detrimental_min": 0.050, "detrimental_max": 0.110},
		QUALITY_MEDIUM: {"beneficial_min": 0.100, "beneficial_max": 0.175, "detrimental_min": 0.040, "detrimental_max": 0.090},
		QUALITY_HIGH: {"beneficial_min": 0.150, "beneficial_max": 0.225, "detrimental_min": 0.040, "detrimental_max": 0.060},
		QUALITY_SUPREME: {"beneficial_min": 0.200, "beneficial_max": 0.275, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
}
## 伤害等价幅度；作为逐属性平衡基准，保持现行四品质的核心输出收益与削弱风险。
const BALANCED_DAMAGE_MAGNITUDE_RANGES: Dictionary = {
	QUALITY_LOW: {"beneficial_min": 0.005, "beneficial_max": 0.012, "detrimental_min": 0.005, "detrimental_max": 0.012},
	QUALITY_MEDIUM: {"beneficial_min": 0.010, "beneficial_max": 0.020, "detrimental_min": 0.003, "detrimental_max": 0.010},
	QUALITY_HIGH: {"beneficial_min": 0.018, "beneficial_max": 0.030, "detrimental_min": 0.003, "detrimental_max": 0.008},
	QUALITY_SUPREME: {"beneficial_min": 0.025, "beneficial_max": 0.040, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 冷却等价幅度；按攻击频率与冷却时长的倒数关系换算，并对齐现有 0.1% 随机精度。
const BALANCED_COOLDOWN_MAGNITUDE_RANGES: Dictionary = {
	QUALITY_LOW: {"beneficial_min": 0.005, "beneficial_max": 0.012, "detrimental_min": 0.005, "detrimental_max": 0.012},
	QUALITY_MEDIUM: {"beneficial_min": 0.010, "beneficial_max": 0.020, "detrimental_min": 0.003, "detrimental_max": 0.010},
	QUALITY_HIGH: {"beneficial_min": 0.018, "beneficial_max": 0.029, "detrimental_min": 0.003, "detrimental_max": 0.008},
	QUALITY_SUPREME: {"beneficial_min": 0.024, "beneficial_max": 0.039, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 能耗等价幅度；按四分之一战斗时间受能量约束的标准场景换算持续输出收益。
const BALANCED_ENERGY_CONSUMPTION_MAGNITUDE_RANGES: Dictionary = {
	QUALITY_LOW: {"beneficial_min": 0.020, "beneficial_max": 0.047, "detrimental_min": 0.020, "detrimental_max": 0.050},
	QUALITY_MEDIUM: {"beneficial_min": 0.039, "beneficial_max": 0.076, "detrimental_min": 0.012, "detrimental_max": 0.041},
	QUALITY_HIGH: {"beneficial_min": 0.069, "beneficial_max": 0.112, "detrimental_min": 0.012, "detrimental_max": 0.033},
	QUALITY_SUPREME: {"beneficial_min": 0.094, "beneficial_max": 0.145, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 操控等价幅度；用于偏移、坐力、冲击力和移速等对命中、安全或位移产生间接收益的属性。
const BALANCED_CONTROL_MAGNITUDE_RANGES: Dictionary = {
	QUALITY_LOW: {"beneficial_min": 0.020, "beneficial_max": 0.048, "detrimental_min": 0.020, "detrimental_max": 0.048},
	QUALITY_MEDIUM: {"beneficial_min": 0.040, "beneficial_max": 0.080, "detrimental_min": 0.012, "detrimental_max": 0.040},
	QUALITY_HIGH: {"beneficial_min": 0.072, "beneficial_max": 0.120, "detrimental_min": 0.012, "detrimental_max": 0.032},
	QUALITY_SUPREME: {"beneficial_min": 0.100, "beneficial_max": 0.160, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 触达等价幅度；用于弹体速度、攻击距离、判定时长、耐久和最大生命等被整体数值稀释的属性。
const BALANCED_REACH_MAGNITUDE_RANGES: Dictionary = {
	QUALITY_LOW: {"beneficial_min": 0.040, "beneficial_max": 0.096, "detrimental_min": 0.040, "detrimental_max": 0.096},
	QUALITY_MEDIUM: {"beneficial_min": 0.080, "beneficial_max": 0.160, "detrimental_min": 0.024, "detrimental_max": 0.080},
	QUALITY_HIGH: {"beneficial_min": 0.144, "beneficial_max": 0.240, "detrimental_min": 0.024, "detrimental_max": 0.064},
	QUALITY_SUPREME: {"beneficial_min": 0.200, "beneficial_max": 0.320, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 恢复与视野等价幅度；用于周期治疗和视野这两类持续但不直接转化为单次伤害的属性。
const BALANCED_SUSTAIN_MAGNITUDE_RANGES: Dictionary = {
	QUALITY_LOW: {"beneficial_min": 0.030, "beneficial_max": 0.072, "detrimental_min": 0.030, "detrimental_max": 0.072},
	QUALITY_MEDIUM: {"beneficial_min": 0.060, "beneficial_max": 0.120, "detrimental_min": 0.018, "detrimental_max": 0.060},
	QUALITY_HIGH: {"beneficial_min": 0.108, "beneficial_max": 0.180, "detrimental_min": 0.018, "detrimental_max": 0.048},
	QUALITY_SUPREME: {"beneficial_min": 0.150, "beneficial_max": 0.240, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 装备攻击力等价幅度；按角色总攻击力与单件装备基础攻击力的平均稀释比例换算。
const BALANCED_ATTACK_POWER_MAGNITUDE_RANGES: Dictionary = {
	QUALITY_LOW: {"beneficial_min": 0.070, "beneficial_max": 0.168, "detrimental_min": 0.070, "detrimental_max": 0.168},
	QUALITY_MEDIUM: {"beneficial_min": 0.140, "beneficial_max": 0.280, "detrimental_min": 0.042, "detrimental_max": 0.140},
	QUALITY_HIGH: {"beneficial_min": 0.252, "beneficial_max": 0.420, "detrimental_min": 0.042, "detrimental_max": 0.112},
	QUALITY_SUPREME: {"beneficial_min": 0.350, "beneficial_max": 0.560, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 装备防御力等价幅度；按防御平滑常数 100 与现有单件装备基础防御力的平均稀释比例换算。
const BALANCED_DEFENSE_POWER_MAGNITUDE_RANGES: Dictionary = {
	QUALITY_LOW: {"beneficial_min": 0.060, "beneficial_max": 0.144, "detrimental_min": 0.060, "detrimental_max": 0.144},
	QUALITY_MEDIUM: {"beneficial_min": 0.120, "beneficial_max": 0.240, "detrimental_min": 0.036, "detrimental_max": 0.120},
	QUALITY_HIGH: {"beneficial_min": 0.216, "beneficial_max": 0.360, "detrimental_min": 0.036, "detrimental_max": 0.096},
	QUALITY_SUPREME: {"beneficial_min": 0.300, "beneficial_max": 0.480, "detrimental_min": 0.0, "detrimental_max": 0.0},
}
## 逐属性乘算幅度目录；正式属性优先读取本表，旧分组仅作为扩展内容未登记时的兼容回退。
const MULTIPLICATIVE_STAT_MAGNITUDE_RANGES: Dictionary = {
	"damage": BALANCED_DAMAGE_MAGNITUDE_RANGES,
	"cooldown": BALANCED_COOLDOWN_MAGNITUDE_RANGES,
	"energy_consumption": BALANCED_ENERGY_CONSUMPTION_MAGNITUDE_RANGES,
	"projectile_speed": BALANCED_REACH_MAGNITUDE_RANGES,
	"attack_distance": BALANCED_REACH_MAGNITUDE_RANGES,
	"deviation_degrees": BALANCED_CONTROL_MAGNITUDE_RANGES,
	"recoil_force": BALANCED_CONTROL_MAGNITUDE_RANGES,
	"front_recoil_force": BALANCED_CONTROL_MAGNITUDE_RANGES,
	"impact_force": BALANCED_CONTROL_MAGNITUDE_RANGES,
	"melee_active_duration": BALANCED_REACH_MAGNITUDE_RANGES,
	"max_durability": BALANCED_REACH_MAGNITUDE_RANGES,
	"attack_power": BALANCED_ATTACK_POWER_MAGNITUDE_RANGES,
	"defense_power": BALANCED_DEFENSE_POWER_MAGNITUDE_RANGES,
	"max_health": BALANCED_REACH_MAGNITUDE_RANGES,
	"health_regeneration_per_five_seconds": BALANCED_SUSTAIN_MAGNITUDE_RANGES,
	"move_speed": BALANCED_CONTROL_MAGNITUDE_RANGES,
	"vision_range": BALANCED_SUSTAIN_MAGNITUDE_RANGES,
}
## 加算属性独立幅度；数值仍以 0 到 1 小数保存，0.005 表示直接增加 0.5 个百分点。
const ADDITIVE_POINT_MAGNITUDE_RANGES: Dictionary = {
	"critical_chance": {
		QUALITY_LOW: {"beneficial_min": 0.011, "beneficial_max": 0.026, "detrimental_min": 0.011, "detrimental_max": 0.026},
		QUALITY_MEDIUM: {"beneficial_min": 0.022, "beneficial_max": 0.044, "detrimental_min": 0.007, "detrimental_max": 0.022},
		QUALITY_HIGH: {"beneficial_min": 0.040, "beneficial_max": 0.066, "detrimental_min": 0.007, "detrimental_max": 0.018},
		QUALITY_SUPREME: {"beneficial_min": 0.055, "beneficial_max": 0.088, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
	"critical_damage": {
		QUALITY_LOW: {"beneficial_min": 0.009, "beneficial_max": 0.021, "detrimental_min": 0.009, "detrimental_max": 0.021},
		QUALITY_MEDIUM: {"beneficial_min": 0.018, "beneficial_max": 0.035, "detrimental_min": 0.005, "detrimental_max": 0.018},
		QUALITY_HIGH: {"beneficial_min": 0.032, "beneficial_max": 0.053, "detrimental_min": 0.005, "detrimental_max": 0.014},
		QUALITY_SUPREME: {"beneficial_min": 0.044, "beneficial_max": 0.070, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
	"dodge_chance": {
		QUALITY_LOW: {"beneficial_min": 0.005, "beneficial_max": 0.011, "detrimental_min": 0.005, "detrimental_max": 0.011},
		QUALITY_MEDIUM: {"beneficial_min": 0.009, "beneficial_max": 0.018, "detrimental_min": 0.003, "detrimental_max": 0.009},
		QUALITY_HIGH: {"beneficial_min": 0.016, "beneficial_max": 0.026, "detrimental_min": 0.003, "detrimental_max": 0.007},
		QUALITY_SUPREME: {"beneficial_min": 0.022, "beneficial_max": 0.035, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
	"cooldown_reduction": {
		QUALITY_LOW: {"beneficial_min": 0.005, "beneficial_max": 0.012, "detrimental_min": 0.005, "detrimental_max": 0.012},
		QUALITY_MEDIUM: {"beneficial_min": 0.010, "beneficial_max": 0.020, "detrimental_min": 0.003, "detrimental_max": 0.010},
		QUALITY_HIGH: {"beneficial_min": 0.018, "beneficial_max": 0.029, "detrimental_min": 0.003, "detrimental_max": 0.008},
		QUALITY_SUPREME: {"beneficial_min": 0.024, "beneficial_max": 0.039, "detrimental_min": 0.0, "detrimental_max": 0.0},
	},
}
## 强化数值保存精度；0.001 对应 0.1 个百分点，可完整保存闪避率等小数区间。
const MODIFIER_VALUE_PRECISION: float = 0.001
## 乘算幅度随机步长；0.001 对应 0.1%，保证缩放后的一级、二级和三级区间端点均可准确抽取。
const MULTIPLICATIVE_ROLL_STEP: float = 0.001
## 加算幅度随机步长；0.001 对应 0.1 个百分点，覆盖 0.3%、0.5% 等区间端点。
const ADDITIVE_POINT_ROLL_STEP: float = 0.001
## 能量恢复强化随机步长；固定为 0.1 点，离散武器计数属性仍沿用整数步长。
const ENERGY_REGENERATION_ROLL_STEP: float = 0.1
## 暴击率最终上限；1.0 表示 100%，武器与装备的有效属性统一应用该限制。
const CRITICAL_CHANCE_MAXIMUM: float = 1.0
## 闪避率最终上限；0.60 表示 60%，单件装备和装备聚合结果均不得超过该值。
const DODGE_CHANCE_MAXIMUM: float = 0.60
## 冷却和判定时长最终下限；0.01 秒可防止零时长导致无限触发或除零。
const MINIMUM_DURATION_VALUE: float = 0.01
## 全部可随机生成的强化属性；顺序同时用于属性筛选下拉框和随机词条池。
const STAT_KEYS: Array[String] = [
	"damage",
	"cooldown",
	"energy_consumption",
	"projectile_speed",
	"attack_distance",
	"deviation_degrees",
	"recoil_force",
	"front_recoil_force",
	"impact_force",
	"melee_active_duration",
	"critical_chance",
	"critical_damage",
	"max_durability",
	"attack_power",
	"defense_power",
	"max_health",
	"health_regeneration_per_five_seconds",
	"dodge_chance",
	"cooldown_reduction",
	"move_speed",
	"vision_range",
	"energy_regeneration",
]
## 武器强化石属性池；只包含武器能够应用的属性。
## 散射、穿透、弹射和连击保留为武器基础机制，但不再作为强化石词条生成或出现在开发者自定义列表。
const WEAPON_STAT_KEYS: Array[String] = ["damage", "cooldown", "energy_consumption", "attack_distance", "projectile_speed", "deviation_degrees", "recoil_force", "front_recoil_force", "impact_force", "melee_active_duration", "critical_chance", "critical_damage", "max_durability"]
## 装备强化石属性池；冷却缩减仅腿部、移速仅脚部、视野仅头部、能量恢复仅躯干可应用。
const EQUIPMENT_STAT_KEYS: Array[String] = ["max_durability", "attack_power", "defense_power", "max_health", "health_regeneration_per_five_seconds", "dodge_chance", "cooldown_reduction", "move_speed", "vision_range", "energy_regeneration"]
## 属性中文名称；键为统一属性名，值用于强化石、搜索、筛选和武器详情。
const STAT_LABELS: Dictionary = {
	"damage": "伤害",
	"cooldown": "冷却",
	"energy_consumption": "能耗",
	"projectile_speed": "弹体速度",
	"attack_distance": "攻击距离",
	"deviation_degrees": "偏移",
	"recoil_force": "后坐力",
	"front_recoil_force": "前坐力",
	"impact_force": "冲击力",
	"melee_active_duration": "判定时长",
	"critical_chance": "暴击率",
	"critical_damage": "暴击伤害",
	"max_durability": "耐久",
	"attack_power": "攻击力",
	"defense_power": "防御力",
	"max_health": "最大生命值",
	"health_regeneration_per_five_seconds": "每5秒回血值",
	"dodge_chance": "闪避率",
	"cooldown_reduction": "冷却缩减",
	"move_speed": "移速",
	"vision_range": "视野",
	"scatter_count": "散射",
	"piercing_count": "穿透",
	"bounce_count": "弹射",
	"combo_count": "连击",
	"energy_regeneration": "能量恢复",
}
## 每项属性的有利数值方向；1 表示数值增加是强化，-1 表示数值减少是强化。
const BENEFICIAL_DIRECTIONS: Dictionary = {
	"damage": 1,
	"cooldown": -1,
	"energy_consumption": -1,
	"projectile_speed": 1,
	"attack_distance": 1,
	"deviation_degrees": -1,
	"recoil_force": -1,
	"front_recoil_force": 1,
	"impact_force": 1,
	"melee_active_duration": 1,
	"critical_chance": 1,
	"critical_damage": 1,
	"max_durability": 1,
	"attack_power": 1,
	"defense_power": 1,
	"max_health": 1,
	"health_regeneration_per_five_seconds": 1,
	"dodge_chance": 1,
	"cooldown_reduction": 1,
	"move_speed": 1,
	"vision_range": 1,
	"scatter_count": 1,
	"piercing_count": 1,
	"bounce_count": 1,
	"combo_count": 1,
	"energy_regeneration": 1,
}


static func normalize_direction(raw_value: Variant) -> int:
	# 原始方向数值；兼容旧存档百分比，小于 0 归一化为 -1，大于等于 0 归一化为 +1。
	var numeric_value: float = float(raw_value)
	return -1 if numeric_value < 0.0 else 1


static func canonicalize_stat_name(stat_name: String) -> String:
	## 把历史属性名迁移为现行统一名称；旧字符串只作为存档兼容入口，不进入新随机池或玩家界面。
	if stat_name == "spread_degrees":
		return "deviation_degrees"
	if stat_name == "energy_cost":
		return "energy_consumption"
	if stat_name == "bullet_range":
		return "attack_distance"
	return stat_name


static func migrate_stat_aliases(modifiers: Dictionary) -> Dictionary:
	## 迁移任意属性词典的历史键并保留原始数值；适用于累计强化与强化石方向两种数据结构。
	# 迁移结果；相同新旧键同时存在时直接累加，避免历史强化幅度被覆盖或丢失。
	var migrated_modifiers: Dictionary = {}
	for raw_stat_name in modifiers.keys():
		# 现行属性名；旧 spread_degrees 统一映射为 deviation_degrees，其他键保持原样。
		var stat_name: String = canonicalize_stat_name(str(raw_stat_name))
		migrated_modifiers[stat_name] = float(migrated_modifiers.get(stat_name, 0.0)) + float(modifiers.get(raw_stat_name, 0.0))
	return migrated_modifiers


static func normalize_modifier_ratio(raw_value: Variant) -> float:
	# 原始词条比例；新版使用 -0.60 到 0.60 左右的实际比例，旧版使用精确 +1/-1 方向值。
	var numeric_value: float = float(raw_value)
	if is_zero_approx(numeric_value):
		return 0.0
	# 迁移后比例；绝对值接近 1 的旧方向存档按 10% 恢复，其他数值保留到整数百分点精度。
	var migrated_ratio: float = float(normalize_direction(numeric_value)) * ENHANCEMENT_STEP_RATIO if absf(numeric_value) >= 0.999 else numeric_value
	# 精度补充；加算词条需要保留 0.1 个百分点，因此统一保存到 0.001。
	return snappedf(migrated_ratio, MODIFIER_VALUE_PRECISION)


static func get_stat_label(stat_name: String) -> String:
	stat_name = canonicalize_stat_name(stat_name)
	return str(STAT_LABELS.get(stat_name, stat_name))


static func get_direction_symbol(direction: int) -> String:
	return "+" if direction >= 0 else "-"


static func get_beneficial_direction(stat_name: String) -> int:
	stat_name = canonicalize_stat_name(stat_name)
	return int(BENEFICIAL_DIRECTIONS.get(stat_name, 1))


static func is_direction_beneficial(stat_name: String, direction: Variant) -> bool:
	return normalize_direction(direction) == get_beneficial_direction(stat_name)


static func get_effect_ratio(direction: Variant) -> float:
	return normalize_modifier_ratio(direction)


static func get_calculation_mode(stat_name: String) -> String:
	stat_name = canonicalize_stat_name(stat_name)
	if ADDITIVE_POINT_STATS.has(stat_name):
		return CALCULATION_ADDITIVE_POINTS
	if ADDITIVE_VALUE_STATS.has(stat_name):
		return CALCULATION_ADDITIVE_VALUE
	return CALCULATION_MULTIPLICATIVE_RATIO


static func is_additive_point_stat(stat_name: String) -> bool:
	return get_calculation_mode(stat_name) == CALCULATION_ADDITIVE_POINTS


static func is_additive_value_stat(stat_name: String) -> bool:
	return get_calculation_mode(stat_name) == CALCULATION_ADDITIVE_VALUE


static func calculate_effective_stat(base_value: float, stat_name: String, accumulated_modifier: float) -> float:
	stat_name = canonicalize_stat_name(stat_name)
	# 原始最终值；乘算属性把累计值视为基础值比例，加算属性把累计值视为直接百分点偏移。
	var calculated_value: float = base_value + accumulated_modifier if is_additive_point_stat(stat_name) or is_additive_value_stat(stat_name) else base_value * (1.0 + accumulated_modifier)
	if stat_name == "critical_chance":
		return clampf(calculated_value, 0.0, CRITICAL_CHANCE_MAXIMUM)
	if stat_name == "dodge_chance":
		return clampf(calculated_value, 0.0, DODGE_CHANCE_MAXIMUM)
	if stat_name == "critical_damage":
		return calculated_value
	if stat_name in ["cooldown", "melee_active_duration"]:
		return maxf(calculated_value, MINIMUM_DURATION_VALUE)
	if stat_name == "energy_consumption":
		return maxf(roundf(calculated_value), 0.0)
	if stat_name in ["scatter_count", "bounce_count", "combo_count"]:
		return maxf(roundf(calculated_value), 1.0)
	if stat_name == "piercing_count":
		return maxf(roundf(calculated_value), 0.0)
	return maxf(calculated_value, 0.0)


static func get_effect_value(stat_name: String, raw_value: Variant) -> float:
	stat_name = canonicalize_stat_name(stat_name)
	# 加算数值词条由随机器直接生成实际点数；其他词条继续兼容旧版方向值到比例的迁移规则。
	return float(raw_value) if is_additive_value_stat(stat_name) else get_effect_ratio(raw_value)


static func get_generation_weight(stat_name: String) -> float:
	stat_name = canonicalize_stat_name(stat_name)
	# 稀有词条使用常规词条五分之一权重；非法属性返回 0，防止进入随机池。
	if stat_name not in STAT_KEYS:
		return 0.0
	return RARE_STAT_RELATIVE_WEIGHT if stat_name in RARE_STAT_KEYS else 1.0


static func convert_legacy_enhancement_modifiers(modifiers: Dictionary, base_values: Dictionary) -> Dictionary:
	# 迁移结果；旧版加算属性曾保存“相对基础值比例”，现转换为等效直接百分点，保持旧物品最终数值不突变。
	var converted_modifiers: Dictionary = migrate_stat_aliases(modifiers)
	for stat_name in ADDITIVE_POINT_STATS.keys():
		if not converted_modifiers.has(stat_name):
			continue
		# 旧累计比例；直接读取存档数值，不能经过方向归一化，否则 ±100% 会被误判成旧强化石方向。
		var legacy_ratio: float = float(converted_modifiers.get(stat_name, 0.0))
		# 旧基础值；武器与装备由各自资源接口提供，缺失时按 0 处理以保持旧版无基础值属性仍无效果。
		var base_value: float = float(base_values.get(stat_name, 0.0))
		converted_modifiers[stat_name] = snappedf(base_value * legacy_ratio, MODIFIER_VALUE_PRECISION)
	return converted_modifiers


static func normalize_modifiers(modifiers: Dictionary) -> Dictionary:
	# 归一化词典；只保留规则目录已登记属性，并将旧百分比值转换为 +1 或 -1。
	var normalized_modifiers: Dictionary = {}
	# 已迁移词典；旧偏移属性键先转换为现行键，保证历史强化石不会丢失词条。
	var migrated_modifiers: Dictionary = migrate_stat_aliases(modifiers)
	for stat_name in STAT_KEYS:
		if migrated_modifiers.has(stat_name):
			# 实际词条比例；保留品质随机的幅度，同时忽略无效的 0% 词条。
			var modifier_ratio: float = normalize_modifier_ratio(migrated_modifiers.get(stat_name, 0.0))
			if not is_zero_approx(modifier_ratio):
				# 方向化强化石只持久化 +1 或 -1；旧存档中的具体百分比读取后仅保留方向，实际幅度延迟到使用瞬间生成。
				normalized_modifiers[stat_name] = normalize_direction(modifier_ratio)
	return normalized_modifiers


static func build_modifier_token(stat_name: String, direction: Variant, include_percentage: bool = false) -> String:
	stat_name = canonicalize_stat_name(stat_name)
	# 标准化比例；旧强化石会在此自动转换为 10%，新强化石保留实际整数百分点。
	var modifier_ratio: float = normalize_modifier_ratio(direction)
	# 方向文本；搜索可使用不带百分比版本，物品详情默认展示完整数值。
	var direction_text: String = "%s%s" % [get_stat_label(stat_name), get_direction_symbol(normalize_direction(modifier_ratio))]
	if not include_percentage:
		return direction_text
	# 可见幅度；加算属性与乘算属性都保留 0.1 精度，避免一级属性的小数百分比被显示为 0%。
	if is_additive_value_stat(stat_name):
		var additive_value_format: String = "%.1f" if stat_name == "energy_regeneration" else "%d"
		return "%s%s" % [direction_text, additive_value_format % (absf(float(direction)) if stat_name == "energy_regeneration" else roundi(absf(float(direction))))]
	return "%s%.1f 个百分点" % [direction_text, absf(modifier_ratio) * 100.0] if is_additive_point_stat(stat_name) else "%s%.1f%%" % [direction_text, absf(modifier_ratio) * 100.0]


static func roll_quality_modifier_ratio(random_source: RandomNumberGenerator, quality_id: String, stat_name: String, direction: Variant) -> float:
	stat_name = canonicalize_stat_name(stat_name)
	if random_source == null or stat_name not in STAT_KEYS:
		return 0.0
	# 方向化词条；资源只保存正负方向，实际强化幅度在每次使用时根据品质重新抽取。
	var modifier_direction: int = normalize_direction(direction)
	# 品质配置；增强和削弱分别使用各品质独立区间，保证低级、中级、高级和极品的幅度差异集中维护。
	var quality_config: Dictionary = get_stat_magnitude_config(stat_name, quality_id)
	# 是否为玩法增强；冷却、偏移和后坐力的负方向仍属于增强，不按数值正负误判收益。
	var beneficial: bool = is_direction_beneficial(stat_name, modifier_direction)
	# 最小随机比例；由属性公式与幅度组共同决定，不再读取所有属性共用的品质区间。
	var minimum_ratio: float = float(quality_config.get("beneficial_min" if beneficial else "detrimental_min", 0.0))
	# 最大随机比例；与最小值共同形成闭区间抽取范围。
	var maximum_ratio: float = float(quality_config.get("beneficial_max" if beneficial else "detrimental_max", 0.0))
	if maximum_ratio <= 0.0:
		return 0.0
	# 随机步长；能量恢复使用 0.1 点，其他离散加算属性保持整数，比例与百分点沿用各自的 0.1% 精度。
	var roll_step: float = ENERGY_REGENERATION_ROLL_STEP if stat_name == "energy_regeneration" else (1.0 if is_additive_value_stat(stat_name) else (ADDITIVE_POINT_ROLL_STEP if is_additive_point_stat(stat_name) else MULTIPLICATIVE_ROLL_STEP))
	# 最小随机单位；将浮点区间换算为整数单位，避免 randf 产生不可追踪精度。
	var minimum_step: int = roundi(minf(minimum_ratio, maximum_ratio) / roll_step)
	# 最大随机单位；与最小单位组成包含端点的闭区间。
	var maximum_step: int = roundi(maxf(minimum_ratio, maximum_ratio) / roll_step)
	return snappedf(float(random_source.randi_range(minimum_step, maximum_step)) * roll_step * float(modifier_direction), MODIFIER_VALUE_PRECISION)


static func get_stat_magnitude_config(stat_name: String, quality_id: String) -> Dictionary:
	stat_name = canonicalize_stat_name(stat_name)
	# 属性级配置；加算属性直接读取自身区间，保证暴击率、暴击伤害和闪避率互不共用幅度。
	var stat_configs: Dictionary = ADDITIVE_POINT_MAGNITUDE_RANGES.get(stat_name, {}) as Dictionary if is_additive_point_stat(stat_name) else (ADDITIVE_VALUE_MAGNITUDE_RANGES.get(stat_name, {}) as Dictionary if is_additive_value_stat(stat_name) else {})
	if stat_configs.is_empty():
		# 逐属性乘算配置；正式属性在此读取战斗收益平衡后的独立区间，不再受共享属性组限制。
		stat_configs = MULTIPLICATIVE_STAT_MAGNITUDE_RANGES.get(stat_name, {}) as Dictionary
	if stat_configs.is_empty():
		# 乘算属性组；未登记属性返回空配置，使错误数据在使用时安全跳过而不是套用其他属性区间。
		var magnitude_group: String = str(MULTIPLICATIVE_STAT_GROUPS.get(stat_name, ""))
		stat_configs = MULTIPLICATIVE_MAGNITUDE_RANGES.get(magnitude_group, {}) as Dictionary
	# 品质级配置；非法品质回退初级仅用于合法属性的旧存档兼容。
	var quality_config: Dictionary = stat_configs.get(quality_id, stat_configs.get(QUALITY_LOW, {})) as Dictionary
	return quality_config.duplicate(true)


static func get_quality_display_name(quality_id: String) -> String:
	return str(QUALITY_DISPLAY_NAMES.get(quality_id, QUALITY_DISPLAY_NAMES[QUALITY_LOW]))


static func get_next_quality_id(quality_id: String) -> String:
	# 下一品质标识；空字符串明确表示当前品质已经到达上限，调用方不得继续执行升阶。
	return str(QUALITY_UPGRADE_PATH.get(quality_id, ""))


static func can_upgrade_quality(quality_id: String) -> bool:
	# 可升阶判断只读取稳定映射，避免各锻造界面自行维护不同的品质上限规则。
	return not get_next_quality_id(quality_id).is_empty()


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
