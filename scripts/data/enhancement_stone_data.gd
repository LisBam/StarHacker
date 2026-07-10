extends Resource
class_name EnhancementStoneData

## 强化石数据资源描述可堆叠的武器强化材料及其百分比词条。
## 同一词条集合与数值完全一致的强化石拥有相同堆叠签名，仓库和背包最多将其合并为 99 个一组。

## 物品类型；固定为 enhancement_stone，供库存、分类和 UI 与武器资源解耦识别。
@export var item_kind: String = "enhancement_stone"
## 强化石显示名称；默认“强化石”，随机生成时会按词条数量补充品质描述。
@export var display_name: String = "强化石"
## 强化石说明；默认说明百分比词条用途，运行时通常不动态修改。
@export_multiline var description: String = "用于强化武器，正负词条会永久累计到所选武器。"
## 强化石图标文本；默认菱形符号，地面掉落和资源方格共用该简写。
@export var icon_text: String = "◆"
## 单颗基础售价；取值大于等于 0，实际出售整组时会乘以堆叠数量。
@export_range(0, 999999, 1) var sell_price: int = 30
## 强化百分比词典；键为统一属性名，值为小数比例，例如 0.1 表示对应基础属性增加 10%。
@export var modifiers: Dictionary = {}


func get_stack_signature() -> String:
	# 排序后的属性键；稳定排序保证相同词条不会因 Dictionary 遍历顺序不同而拆成两组。
	var sorted_keys: Array[String] = []
	# 原始属性键；只接收非空字符串，异常字段不会污染堆叠签名。
	for raw_key in modifiers.keys():
		var modifier_key: String = str(raw_key)
		if not modifier_key.is_empty():
			sorted_keys.append(modifier_key)
	sorted_keys.sort()

	# 签名片段；数值固定保留六位小数，避免浮点显示误差导致相同强化石无法堆叠。
	var signature_parts: PackedStringArray = PackedStringArray()
	for modifier_key in sorted_keys:
		signature_parts.append("%s=%.6f" % [modifier_key, float(modifiers.get(modifier_key, 0.0))])
	return "|".join(signature_parts)


func get_effective_sell_price() -> int:
	return maxi(sell_price, 0)


func can_apply_to_weapon(weapon_data: Resource) -> bool:
	if weapon_data == null:
		return false
	if weapon_data.has_method("can_apply_enhancement"):
		return bool(weapon_data.call("can_apply_enhancement", modifiers))
	return not modifiers.is_empty() and not str(weapon_data.get("weapon_type")).is_empty()

