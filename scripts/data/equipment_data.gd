extends Resource
class_name EquipmentData

## 装备数据资源描述头部、躯干、腿部和脚部装备的耐久与战斗属性。
## 所有数值通过统一有效属性接口读取，强化只累计百分比而不修改基础字段。
## 公式分类补充：暴击率、暴击伤害和闪避率累计直接百分点，其余属性累计乘算比例，基础字段仍保持不变。
## 装备强化范围补充：暴击率与暴击伤害不再接受装备强化词条，仅保留旧资源基础字段读取兼容；闪避率继续使用加算百分点。

## 物品类型；固定为 equipment，供库存、装备槽和存档识别。
@export var item_kind: String = "equipment"
## 装备唯一标识；必须使用稳定英文 ID，修改会影响存档恢复。
@export var equipment_id: String = ""
## 装备显示名称；默认“未命名装备”，用于背包、仓库和装备槽。
@export var display_name: String = "未命名装备"
## 装备部位；取值为 head、body、legs 或 feet，决定可投放槽位。
@export_enum("head", "body", "legs", "feet") var equipment_slot: String = "head"
## 装备说明；默认空字符串，用于详情面板说明设计用途。
@export_multiline var description: String = ""
## 所属套装数据；默认空表示独立装备，配置后会按稳定套装 ID 参与已穿戴且未损坏部件的档位统计。
@export var equipment_set: Resource
## 装备图标文本；默认护盾符号，用于紧凑物品卡片。
@export var icon_text: String = "◇"
## 装备价值；默认 0，强化和耐久会共同影响玩家出售时的实际价值。
@export_range(0, 999999, 1) var value: int = 0
## 最大耐久值；默认 500.0，归零后装备属性失效但物品不会消失，已存档装备按原耐久比例迁移。
@export_range(1.0, 999999.0, 0.1, "or_greater") var max_durability: float = 500.0
## 当前耐久值；默认 500.0 表示新装备以满耐久创建，受到玩家伤害时由装备组件统一动态消耗。
@export_range(0.0, 999999.0, 0.1) var current_durability: float = 500.0
## 是否为二手装备；默认 false 表示全新物品，怪物、宝箱或商店命中二手规则后设为 true，影响名称前缀并随物品存档永久保留。
@export var is_second_hand: bool = false
## 已使用强化石次数；默认 0，玩家锻造和二手历史强化成功后各增加 1，用于保存物品完整强化历史且当前不限制装备继续强化。
@export_range(0, 999999, 1) var enhancement_count: int = 0
## 攻击力加成；默认 0，装备有效时加到玩家基础攻击力。
@export_range(0.0, 99999.0, 1.0, "or_greater") var attack_power: float = 0.0
## 防御力加成；默认 0，装备有效时加到玩家基础防御力。
@export_range(0.0, 99999.0, 1.0, "or_greater") var defense_power: float = 0.0
## 最大生命值加成；默认 0，装备变化时同步更新玩家生命上限。
@export_range(0.0, 99999.0, 1.0, "or_greater") var max_health: float = 0.0
## 每 5 秒回血值；默认 0，装备有效时由属性组件每 5 秒结算一次。
@export_range(0.0, 99999.0, 0.1, "or_greater") var health_regeneration_per_five_seconds: float = 0.0
## 闪避率；使用 0 到 1 小数，默认 0，受到攻击时独立判定。
## 当前配置上限补充：检查器最多允许 0.80，装备、套装与临时效果汇总后仍由战斗属性组件执行同一最终上限。
@export_range(0.0, 0.8, 0.01) var dodge_chance: float = 0.0
## 技能冷却缩减；使用 0 到 1 小数，默认 0 表示不缩短主动技能冷却，0.05 表示主动技能基础冷却时间减少 5%，仅腿部装备支持且可被强化石在运行时动态改变。
## 当前配置上限补充：检查器最多允许 0.40，强化累计和运行时聚合结果超过该值的部分不会继续缩短主动技能冷却。
@export_range(0.0, 0.4, 0.001) var cooldown_reduction: float = 0.0
## 移速加成比例；使用 0 到 1 小数，默认 0，仅脚部装备支持，0.06 表示提高 6%。
@export_range(0.0, 10.0, 0.01, "or_greater") var move_speed: float = 0.0
## 视野加成比例；使用 0 到 1 小数，默认 0，仅头部装备支持，数值越高相机视野越广。
@export_range(0.0, 10.0, 0.01, "or_greater") var vision_range: float = 0.0
## 每秒能量恢复加成；默认 0，仅躯干装备支持，支持 0.1 精度并直接加算到玩家每秒能量恢复。
@export_range(0.0, 99999.0, 0.1, "or_greater") var energy_regeneration: float = 0.0
## 暴击率加成；使用 0 到 1 小数，默认 0，装备有效时与武器暴击率相加。
@export_range(0.0, 1.0, 0.01) var critical_chance: float = 0.0
## 暴击伤害倍率增量；默认 0，0.1 表示在基础 150% 上增加 10 个百分点。
@export_range(0.0, 9.0, 0.01, "or_greater") var critical_damage: float = 0.0
## 累计强化百分比；键为统一属性名，值为相对基础值的小数比例。
## 加算属性补充：暴击率、暴击伤害、闪避率和冷却缩减的值表示直接百分点偏移，例如 0.015 表示 1.5 个百分点。
@export var enhancement_modifiers: Dictionary = {}

## 装备通用强化属性；所有部位均可应用。
const COMMON_ENHANCEMENT_STATS: Array[String] = ["max_durability", "attack_power", "defense_power", "max_health", "health_regeneration_per_five_seconds", "dodge_chance"]
## 脚部专属强化属性；其他部位不会消费该词条。
const FEET_ENHANCEMENT_STATS: Array[String] = ["move_speed"]
## 腿部专属强化属性；冷却缩减可从 0 基础值开始按加算百分点叠加，其他部位不会消费该词条。
const LEGS_ENHANCEMENT_STATS: Array[String] = ["cooldown_reduction"]
## 头部专属强化属性；其他部位不会消费视野词条。
const HEAD_ENHANCEMENT_STATS: Array[String] = ["vision_range"]
## 躯干专属强化属性；其他部位不会消费能量恢复词条。
const BODY_ENHANCEMENT_STATS: Array[String] = ["energy_regeneration"]
## 仅基础装备可提供的属性；暴击率与暴击伤害可以保留资源基础配置，但装备强化石不会生成或应用对应词条。
const BASE_ONLY_STATS: Array[String] = ["critical_chance", "critical_damage"]
## 允许从零基础强化的属性；这些能力由部位资格定义而不是模板初始值决定，默认 0 仍能消费对应强化石。
const ZERO_BASE_ENHANCEMENT_STATS: Array[String] = ["cooldown_reduction"]


func get_base_stat(stat_name: String) -> float:
	return float(get(stat_name)) if _is_stat_available(stat_name) else 0.0


func get_enhancement_ratio(stat_name: String) -> float:
	return float(enhancement_modifiers.get(stat_name, 0.0)) if _is_stat_supported(stat_name) else 0.0


func get_maximum_durability() -> float:
	# 装备耐久上限；读取耐久值乘算词条后的最终结果，最低保持 1，供损耗、修复、锻造和显示统一使用。
	return maxf(get_effective_stat("max_durability"), 1.0)


func get_effective_stat(stat_name: String) -> float:
	# 分类公式；暴击率、暴击伤害、闪避率与冷却缩减直接加算百分点，其余装备属性继续按基础值乘算。
	return EnhancementRules.calculate_effective_stat(get_base_stat(stat_name), stat_name, get_enhancement_ratio(stat_name))


func can_apply_enhancement(modifiers: Dictionary) -> bool:
	for raw_stat_name in modifiers.keys():
		if _is_stat_supported(str(raw_stat_name)):
			return true
	return false


func apply_enhancement_with_result(modifiers: Dictionary) -> Dictionary:
	# 强化结果；结构与武器强化完全一致，UI 可直接复用结果弹窗。
	var result: Dictionary = {"success": false, "weapon": self, "beneficial_changes": [], "detrimental_changes": []}
	for raw_stat_name in modifiers.keys():
		# 属性名；不支持的部位专属属性直接跳过。
		var stat_name: String = str(raw_stat_name)
		if not _is_stat_supported(stat_name):
			continue
		# 本次强化比例；品质规则已在消耗强化石时生成实际幅度。
		var modifier_ratio: float = EnhancementRules.get_effect_value(stat_name, modifiers.get(raw_stat_name, 0.0))
		if is_zero_approx(modifier_ratio):
			continue
		# 强化前后数值；始终以基础属性为百分比换算基准。
		var base_value: float = get_base_stat(stat_name)
		var before_value: float = get_effective_stat(stat_name)
		# 累计精度；0.001 可准确保存 0.3 至 0.5 个百分点等加算词条端点。
		enhancement_modifiers[stat_name] = snappedf(float(enhancement_modifiers.get(stat_name, 0.0)) + modifier_ratio, EnhancementRules.MODIFIER_VALUE_PRECISION)
		if stat_name == "max_durability":
			# 当前耐久同步；耐久上限降低时立即限制现值，上限提高时不免费补充新增耐久。
			set_current_durability(current_durability)
		var after_value: float = get_effective_stat(stat_name)
		var change_entry: Dictionary = {"stat_name": stat_name, "modifier_ratio": modifier_ratio, "calculation_mode": EnhancementRules.get_calculation_mode(stat_name), "base_value": base_value, "before_value": before_value, "change_value": after_value - before_value, "after_value": after_value}
		if EnhancementRules.is_direction_beneficial(stat_name, modifier_ratio):
			(result["beneficial_changes"] as Array).append(change_entry)
		else:
			(result["detrimental_changes"] as Array).append(change_entry)
		result["success"] = true
	if bool(result.get("success", false)):
		# 强化次数；一次 apply 调用代表消费一颗装备强化石，多词条仍只累计一次。
		enhancement_count = maxi(enhancement_count, 0) + 1
	return result


func apply_enhancement(modifiers: Dictionary) -> bool:
	return bool(apply_enhancement_with_result(modifiers).get("success", false))


func get_effective_value() -> int:
	# 强化价值倍率；所有装备属性增加均提高价值，减少均降低价值，最低保留 10%。
	var modifier_total: float = 0.0
	for raw_stat_name in enhancement_modifiers.keys():
		if _is_stat_supported(str(raw_stat_name)):
			modifier_total += float(enhancement_modifiers.get(raw_stat_name, 0.0))
	# 耐久价值倍率；零耐久保留满耐久有效价值的 10%。
	var durability_ratio: float = clampf(current_durability / get_maximum_durability(), 0.0, 1.0)
	return maxi(roundi(float(value) * maxf(1.0 + modifier_total, 0.1) * lerpf(0.1, 1.0, durability_ratio)), 1) if value > 0 else 0


func get_durability_ratio() -> float:
	# 当前耐久比例；与 WeaponData 使用同一计算规则，供耐久条、价值和通用 UI 读取稳定的 0 到 1 数值。
	return clampf(current_durability / get_maximum_durability(), 0.0, 1.0)


func is_broken() -> bool:
	return current_durability <= 0.0 or is_zero_approx(current_durability)


func set_current_durability(value: float) -> void:
	current_durability = clampf(value, 0.0, get_maximum_durability())


func _is_stat_supported(stat_name: String) -> bool:
	# 部位允许状态；通用属性适用于所有装备，专属属性只允许对应部位参与共有属性判断。
	var is_allowed_for_slot: bool = stat_name in COMMON_ENHANCEMENT_STATS or (equipment_slot == "feet" and stat_name in FEET_ENHANCEMENT_STATS) or (equipment_slot == "legs" and stat_name in LEGS_ENHANCEMENT_STATS) or (equipment_slot == "head" and stat_name in HEAD_ENHANCEMENT_STATS) or (equipment_slot == "body" and stat_name in BODY_ENHANCEMENT_STATS)
	if not is_allowed_for_slot:
		return false
	# 基础属性值；通常只有非零基础值代表目标实际拥有该属性，零基础白名单属性可由部位资格开启强化。
	var base_property_value: Variant = get(stat_name)
	return base_property_value != null and (not is_zero_approx(float(base_property_value)) or stat_name in ZERO_BASE_ENHANCEMENT_STATS)


func _is_stat_available(stat_name: String) -> bool:
	# 可读取属性；包含强化支持属性和仅允许模板配置的暴击属性，避免移除强化能力时破坏既有装备基础数值。
	return _is_stat_supported(stat_name) or stat_name in BASE_ONLY_STATS
