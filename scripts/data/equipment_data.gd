extends Resource
class_name EquipmentData

## 装备数据资源描述头部、躯干、腿部和脚部装备的耐久与战斗属性。
## 所有数值通过统一有效属性接口读取，强化只累计百分比而不修改基础字段。

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
## 装备图标文本；默认护盾符号，用于紧凑物品卡片。
@export var icon_text: String = "◇"
## 装备出售价格；默认 0，强化和耐久会共同影响实际售价。
@export_range(0, 999999, 1) var sell_price: int = 0
## 最大耐久值；默认 1000，归零后装备属性失效但物品不会消失。
@export_range(1.0, 999999.0, 0.1, "or_greater") var max_durability: float = 1000.0
## 当前耐久值；默认 1000，受到玩家伤害时由装备组件统一消耗。
@export_range(0.0, 999999.0, 0.1) var current_durability: float = 1000.0
## 攻击力加成；默认 0，装备有效时加到玩家基础攻击力。
@export_range(0.0, 99999.0, 1.0, "or_greater") var attack_power: float = 0.0
## 防御力加成；默认 0，装备有效时加到玩家基础防御力。
@export_range(0.0, 99999.0, 1.0, "or_greater") var defense_power: float = 0.0
## 最大生命值加成；默认 0，装备变化时同步更新玩家生命上限。
@export_range(0.0, 99999.0, 1.0, "or_greater") var max_health: float = 0.0
## 每 5 秒回血值；默认 0，装备有效时由属性组件每 5 秒结算一次。
@export_range(0.0, 99999.0, 0.1, "or_greater") var health_regeneration_per_five_seconds: float = 0.0
## 闪避率；使用 0 到 1 小数，默认 0，受到攻击时独立判定。
@export_range(0.0, 1.0, 0.01) var dodge_chance: float = 0.0
## 移速加成比例；使用 0 到 1 小数，默认 0，仅脚部装备支持，0.06 表示提高 6%。
@export_range(0.0, 10.0, 0.01, "or_greater") var move_speed: float = 0.0
## 视野加成比例；使用 0 到 1 小数，默认 0，仅头部装备支持，数值越高相机视野越广。
@export_range(0.0, 10.0, 0.01, "or_greater") var vision_range: float = 0.0
## 暴击率加成；使用 0 到 1 小数，默认 0，装备有效时与武器暴击率相加。
@export_range(0.0, 1.0, 0.01) var critical_chance: float = 0.0
## 暴击伤害倍率增量；默认 0，0.1 表示在基础 150% 上增加 10 个百分点。
@export_range(0.0, 9.0, 0.01, "or_greater") var critical_damage: float = 0.0
## 累计强化百分比；键为统一属性名，值为相对基础值的小数比例。
@export var enhancement_modifiers: Dictionary = {}

## 装备通用强化属性；所有部位均可应用。
const COMMON_ENHANCEMENT_STATS: Array[String] = ["max_durability", "attack_power", "defense_power", "max_health", "health_regeneration_per_five_seconds", "dodge_chance", "critical_chance", "critical_damage"]
## 脚部专属强化属性；其他部位不会消费该词条。
const FEET_ENHANCEMENT_STATS: Array[String] = ["move_speed"]
## 头部专属强化属性；其他部位不会消费视野词条。
const HEAD_ENHANCEMENT_STATS: Array[String] = ["vision_range"]


func get_base_stat(stat_name: String) -> float:
	return float(get(stat_name)) if _is_stat_supported(stat_name) else 0.0


func get_enhancement_ratio(stat_name: String) -> float:
	return float(enhancement_modifiers.get(stat_name, 0.0))


func get_effective_stat(stat_name: String) -> float:
	return maxf(get_base_stat(stat_name) * (1.0 + get_enhancement_ratio(stat_name)), 0.0)


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
		var modifier_ratio: float = EnhancementRules.get_effect_ratio(modifiers.get(raw_stat_name, 0.0))
		if is_zero_approx(modifier_ratio):
			continue
		# 强化前后数值；始终以基础属性为百分比换算基准。
		var base_value: float = get_base_stat(stat_name)
		var before_value: float = get_effective_stat(stat_name)
		enhancement_modifiers[stat_name] = snappedf(float(enhancement_modifiers.get(stat_name, 0.0)) + modifier_ratio, 0.01)
		var after_value: float = get_effective_stat(stat_name)
		var change_entry: Dictionary = {"stat_name": stat_name, "modifier_ratio": modifier_ratio, "base_value": base_value, "before_value": before_value, "change_value": after_value - before_value, "after_value": after_value}
		if EnhancementRules.is_direction_beneficial(stat_name, modifier_ratio):
			(result["beneficial_changes"] as Array).append(change_entry)
		else:
			(result["detrimental_changes"] as Array).append(change_entry)
		result["success"] = true
	return result


func apply_enhancement(modifiers: Dictionary) -> bool:
	return bool(apply_enhancement_with_result(modifiers).get("success", false))


func get_effective_sell_price() -> int:
	# 强化售价倍率；所有装备属性增加均提高售价，减少均降低售价，最低保留 10%。
	var modifier_total: float = 0.0
	for raw_ratio in enhancement_modifiers.values():
		modifier_total += float(raw_ratio)
	# 耐久售价倍率；零耐久保留满耐久有效售价的 10%。
	var durability_ratio: float = clampf(current_durability / maxf(max_durability, 1.0), 0.0, 1.0)
	return maxi(roundi(float(sell_price) * maxf(1.0 + modifier_total, 0.1) * lerpf(0.1, 1.0, durability_ratio)), 1) if sell_price > 0 else 0


func get_durability_ratio() -> float:
	# 当前耐久比例；与 WeaponData 使用同一计算规则，供耐久条、售价和通用 UI 读取稳定的 0 到 1 数值。
	return clampf(current_durability / maxf(max_durability, 1.0), 0.0, 1.0)


func is_broken() -> bool:
	return current_durability <= 0.0 or is_zero_approx(current_durability)


func set_current_durability(value: float) -> void:
	current_durability = clampf(value, 0.0, maxf(max_durability, 1.0))


func _is_stat_supported(stat_name: String) -> bool:
	return stat_name in COMMON_ENHANCEMENT_STATS or (equipment_slot == "feet" and stat_name in FEET_ENHANCEMENT_STATS) or (equipment_slot == "head" and stat_name in HEAD_ENHANCEMENT_STATS)
