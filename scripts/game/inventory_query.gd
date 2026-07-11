extends RefCounted
class_name InventoryQuery

## 库存查询器为局外仓库和局内背包提供统一的多层分类、关键词、强化属性筛选和展示排序。
## 查询只返回带原始 source_index 的条目副本，不修改 GlobalInventory 的真实顺序和所有权记录。

## 全部主分类；同时包含武器和资源，用于所有一级分类栏的首个聚合入口。
const PRIMARY_ALL: String = "all"
## 武器主分类；包含全部 melee 与 ranged 武器。
const PRIMARY_WEAPONS: String = "weapons"
## 资源主分类；包含强化石及以后扩展的非武器资源。
const PRIMARY_RESOURCES: String = "resources"
## 全部子分类；在当前主分类内不限制具体类型。
const SUBCATEGORY_ALL: String = "all"
## 近战武器子分类；只匹配 weapon_type 为 melee。
const SUBCATEGORY_MELEE: String = "melee"
## 远程武器子分类；只匹配 weapon_type 为 ranged。
const SUBCATEGORY_RANGED: String = "ranged"
## 强化石资源子分类；只匹配 item_kind 为 enhancement_stone。
const SUBCATEGORY_ENHANCEMENT_STONES: String = "enhancement_stones"
## 道具资源子分类；当前匹配 item_kind 为 repair_kit，后续可扩展为更多主动道具。
const SUBCATEGORY_ITEMS: String = "items"
## 获得时间排序；默认按 acquired_at 与 acquisition_sequence 从新到旧排列。
const SORT_ACQUIRED_TIME: String = "acquired_time"
## 物品价值排序；按单价乘堆叠数量从高到低排列，相同价值时回退获得时间。
const SORT_ITEM_VALUE: String = "item_value"
## 强化石方向筛选键分隔符；默认冒号用于把属性名和 +1/-1 方向组合为稳定元数据。
const STONE_ATTRIBUTE_DIRECTION_SEPARATOR: String = ":"
## 强化石方向筛选分组顺序；默认先展示全部“+”属性，再展示全部“-”属性。
const STONE_FILTER_DIRECTIONS: Array[int] = [1, -1]


static func build_stone_attribute_filter_key(stat_name: String, direction: int) -> String:
	# 标准化方向；筛选元数据只保存 +1 或 -1，避免 UI 文本变化影响查询规则。
	var normalized_direction: int = EnhancementRules.normalize_direction(direction)
	return "%s%s%d" % [stat_name, STONE_ATTRIBUTE_DIRECTION_SEPARATOR, normalized_direction]


static func get_stone_attribute_filter_label(stat_name: String, direction: int) -> String:
	# 筛选显示文本；与强化石卡片一致使用“属性+”或“属性-”，便于玩家直接按方向定位。
	return "%s%s" % [EnhancementRules.get_stat_label(stat_name), EnhancementRules.get_direction_symbol(direction)]


static func get_stone_attribute_direction_group_label(direction: int) -> String:
	# 分组标题；只负责说明数值方向，不把“+”或“-”错误等同于增益或减益。
	return "“%s”属性" % EnhancementRules.get_direction_symbol(direction)


static func filter_and_sort_entries(entries: Array, primary_category: String, subcategory: String, search_keyword: String, stone_attribute: Variant, sort_mode: String) -> Array[Dictionary]:
	# 标准化搜索词；忽略首尾空格和英文大小写，中文关键词保持原样。
	var normalized_keyword: String = search_keyword.strip_edges().to_lower()
	# 查询结果；每项复制展示字段并附加真实 source_index，供排序视图中的拖拽仍能操作正确记录。
	var result: Array[Dictionary] = []
	for source_index in range(entries.size()):
		# 原始条目；异常数据直接忽略，不影响其他物品展示。
		var raw_entry: Variant = entries[source_index]
		if not (raw_entry is Dictionary):
			continue
		# 展示条目；复制后写入源下标，外部 UI 不会修改全局库存记录。
		var entry: Dictionary = (raw_entry as Dictionary).duplicate()
		entry["source_index"] = source_index
		if not _matches_category(entry, primary_category, subcategory):
			continue
		if not _matches_stone_attribute(entry, stone_attribute):
			continue
		if not normalized_keyword.is_empty() and not _build_search_text(entry).contains(normalized_keyword):
			continue
		result.append(entry)

	_sort_entries(result, sort_mode)
	return result


static func _matches_category(entry: Dictionary, primary_category: String, subcategory: String) -> bool:
	# 条目资源；空资源不属于任何分类。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return false
	# 物品类型；enhancement_stone 及以后资源类型都归入资源主分类。
	var item_kind: String = str(item_resource.get("item_kind"))
	# 武器类型；只在武器主分类内参与近战和远程子分类判断。
	var weapon_type: String = str(item_resource.get("weapon_type"))
	if primary_category == PRIMARY_ALL:
		return subcategory == SUBCATEGORY_ALL
	if primary_category == PRIMARY_WEAPONS:
		if weapon_type not in [SUBCATEGORY_MELEE, SUBCATEGORY_RANGED]:
			return false
		return subcategory == SUBCATEGORY_ALL or weapon_type == subcategory
	if primary_category == PRIMARY_RESOURCES:
		if item_kind == "weapon" or weapon_type in [SUBCATEGORY_MELEE, SUBCATEGORY_RANGED]:
			return false
		return subcategory == SUBCATEGORY_ALL or (subcategory == SUBCATEGORY_ENHANCEMENT_STONES and item_kind == "enhancement_stone") or (subcategory == SUBCATEGORY_ITEMS and item_kind == "repair_kit")
	return false


static func _matches_stone_attribute(entry: Dictionary, stone_attribute: Variant) -> bool:
	# 多选筛选键；兼容旧版单字符串调用，新版数组中的任意条件命中即可展示，形成并集规则。
	var stone_attribute_filters: Array[String] = _normalize_stone_attribute_filters(stone_attribute)
	if stone_attribute_filters.is_empty():
		return true
	# 条目资源；属性筛选只对强化石生效，选择属性后其他物品不会显示。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null or str(item_resource.get("item_kind")) != "enhancement_stone":
		return false
	# 归一化强化词典；旧百分比存档也能按属性键正确筛选。
	var modifiers: Dictionary = EnhancementRules.normalize_modifiers(item_resource.get("modifiers") as Dictionary)
	for stone_attribute_filter in stone_attribute_filters:
		# 筛选键分段；新版键为“属性:方向”，旧版纯属性键继续匹配该属性的任意方向。
		var filter_parts: PackedStringArray = stone_attribute_filter.split(STONE_ATTRIBUTE_DIRECTION_SEPARATOR, false, 1)
		# 筛选属性名；新版读取分隔符前内容，旧版直接使用完整键。
		var filter_stat_name: String = filter_parts[0] if not filter_parts.is_empty() else stone_attribute_filter
		if not modifiers.has(filter_stat_name):
			continue
		if filter_parts.size() < 2:
			return true
		# 目标筛选方向；无效值按 +1 兜底，正常 UI 始终写入明确的 +1 或 -1。
		var filter_direction: int = EnhancementRules.normalize_direction(int(filter_parts[1]))
		# 强化石实际方向；归一化后与目标方向精确匹配。
		var modifier_direction: int = EnhancementRules.normalize_direction(modifiers.get(filter_stat_name, 1))
		if modifier_direction == filter_direction:
			return true
	return false


static func _normalize_stone_attribute_filters(stone_attribute: Variant) -> Array[String]:
	# 标准化筛选结果；每个非空键只保留一次，避免 UI 重复勾选造成无意义查询开销。
	var normalized_filters: Array[String] = []
	if stone_attribute is String:
		# 旧版单选筛选键；空字符串表示不限制属性。
		var single_filter: String = str(stone_attribute)
		if not single_filter.is_empty():
			normalized_filters.append(single_filter)
		return normalized_filters
	if stone_attribute is Array or stone_attribute is PackedStringArray:
		# 多选筛选项；数组内任意一个属性方向命中即可展示对应强化石。
		for raw_filter in stone_attribute:
			# 当前筛选键；转为字符串后排除空值和重复项。
			var filter_key: String = str(raw_filter)
			if not filter_key.is_empty() and filter_key not in normalized_filters:
				normalized_filters.append(filter_key)
	return normalized_filters


static func _build_search_text(entry: Dictionary) -> String:
	# 条目资源；空资源使用空文本，避免关键词查询报错。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return ""
	# 搜索文本片段；包含名称、说明、分类和强化石属性方向，支持中文属性关键词。
	var search_parts: PackedStringArray = PackedStringArray()
	search_parts.append(str(item_resource.get("display_name")))
	search_parts.append(str(item_resource.get("description")))
	search_parts.append(str(item_resource.get("weapon_type")))
	search_parts.append(str(item_resource.get("item_kind")))
	# 中文分类文本；允许直接搜索“武器”“近战”“远程”“资源”或“强化石”。
	var weapon_type: String = str(item_resource.get("weapon_type"))
	if weapon_type == SUBCATEGORY_MELEE:
		search_parts.append("武器 近战")
	elif weapon_type == SUBCATEGORY_RANGED:
		search_parts.append("武器 远程")
	else:
		search_parts.append("资源 强化石" if str(item_resource.get("item_kind")) == "enhancement_stone" else ("资源 道具 修复包" if str(item_resource.get("item_kind")) == "repair_kit" else "资源"))
	if str(item_resource.get("item_kind")) == "enhancement_stone":
		# 强化词典；将“伤害+”“冷却+”等可见词条加入搜索内容。
		var modifiers: Dictionary = EnhancementRules.normalize_modifiers(item_resource.get("modifiers") as Dictionary)
		for stat_name in EnhancementRules.STAT_KEYS:
			if modifiers.has(stat_name):
				search_parts.append(EnhancementRules.build_modifier_token(stat_name, modifiers.get(stat_name, 0.0)))
	return " ".join(search_parts).to_lower()


static func _sort_entries(entries: Array[Dictionary], sort_mode: String) -> void:
	# 插入排序索引；库存展示规模有限，稳定插入排序可保留相同值物品的原始顺序并避免闭包依赖。
	for entry_index in range(1, entries.size()):
		# 当前待插入条目；向前移动直到找到正确位置。
		var moving_entry: Dictionary = entries[entry_index]
		# 比较下标；从当前项前一位开始向左比较。
		var compare_index: int = entry_index - 1
		while compare_index >= 0 and _should_come_before(moving_entry, entries[compare_index], sort_mode):
			entries[compare_index + 1] = entries[compare_index]
			compare_index -= 1
		entries[compare_index + 1] = moving_entry


static func _should_come_before(first_entry: Dictionary, second_entry: Dictionary, sort_mode: String) -> bool:
	if sort_mode == SORT_ITEM_VALUE:
		# 第一项总价值；单价乘堆叠数量，武器数量固定为 1。
		var first_value: int = _get_entry_total_value(first_entry)
		# 第二项总价值；用于降序比较。
		var second_value: int = _get_entry_total_value(second_entry)
		if first_value != second_value:
			return first_value > second_value
	# 第一项获得时间；时间越新越靠前。
	var first_time: float = float(first_entry.get("acquired_at", 0.0))
	# 第二项获得时间；用于默认时间倒序比较。
	var second_time: float = float(second_entry.get("acquired_at", 0.0))
	if not is_equal_approx(first_time, second_time):
		return first_time > second_time
	return int(first_entry.get("source_index", 0)) < int(second_entry.get("source_index", 0))


static func _get_entry_total_value(entry: Dictionary) -> int:
	# 条目资源；空资源价值为 0。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return 0
	# 单件价值；武器优先读取强化后售价，资源读取固定售价。
	var unit_value: int = int(item_resource.call("get_effective_sell_price")) if item_resource.has_method("get_effective_sell_price") else maxi(int(item_resource.get("sell_price")), 0)
	# 堆叠数量；武器为 1，资源限制在至少 1。
	var quantity: int = maxi(int(entry.get("quantity", 1)), 1)
	return unit_value * quantity
