extends RefCounted
class_name InventoryQuery

## 库存查询器为局外仓库和局内背包提供统一的多层分类、关键词、强化属性、强化品质筛选和展示排序。
## 查询只返回带原始 source_index 的条目副本，不修改 GlobalInventory 的真实顺序和所有权记录。

## 全部主分类；同时包含武器和资源，用于所有一级分类栏的首个聚合入口。
const PRIMARY_ALL: String = "all"
## 武器主分类；包含全部 melee 与 ranged 武器。
const PRIMARY_WEAPONS: String = "weapons"
## 资源主分类；包含强化石及以后扩展的非武器资源。
const PRIMARY_RESOURCES: String = "resources"
## 装备主分类；包含头部、躯干、腿部和脚部装备。
const PRIMARY_EQUIPMENT: String = "equipment"
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
## 头部装备子分类；只匹配 equipment_slot 为 head 的装备。
const SUBCATEGORY_EQUIPMENT_HEAD: String = "head"
## 躯干装备子分类；只匹配 equipment_slot 为 body 的装备。
const SUBCATEGORY_EQUIPMENT_BODY: String = "body"
## 腿部装备子分类；只匹配 equipment_slot 为 legs 的装备。
const SUBCATEGORY_EQUIPMENT_LEGS: String = "legs"
## 脚部装备子分类；只匹配 equipment_slot 为 feet 的装备。
const SUBCATEGORY_EQUIPMENT_FEET: String = "feet"
## 获得时间排序；默认按 acquired_at 与 acquisition_sequence 从新到旧排列。
const SORT_ACQUIRED_TIME: String = "acquired_time"
## 物品价值排序；按单价乘堆叠数量从高到低排列，相同价值时回退获得时间。
const SORT_ITEM_VALUE: String = "item_value"
## 耐久排序；带耐久物品按当前耐久比例从高到低排列，相同比例按当前耐久值和获得时间回退，无耐久物品排在最后。
const SORT_DURABILITY: String = "durability"
## 强化石方向筛选键分隔符；默认冒号用于把属性名和 +1/-1 方向组合为稳定元数据。
const STONE_ATTRIBUTE_DIRECTION_SEPARATOR: String = ":"
## 强化石方向筛选分组顺序；默认先展示全部“+”属性，再展示全部“-”属性。
const STONE_FILTER_DIRECTIONS: Array[int] = [1, -1]
## 搜索文本缓存条数上限；默认 2048 条，超限时一次性清空重建，防止长会话按资源实例累计的缓存键无限增长。
const SEARCH_TEXT_CACHE_LIMIT: int = 2048

## 搜索文本静态缓存；键为资源实例组合键，值为已拼接的小写搜索文本，命中后跳过整段搜索字符串重建。
static var _search_text_cache: Dictionary = {}


static func build_stone_attribute_filter_key(stat_name: String, direction: int) -> String:
	# 标准化方向；筛选元数据只保存 +1 或 -1，避免 UI 文本变化影响查询规则。
	var normalized_direction: int = EnhancementRules.normalize_direction(direction)
	return "%s%s%d" % [stat_name, STONE_ATTRIBUTE_DIRECTION_SEPARATOR, normalized_direction]


static func get_stone_attribute_filter_label(stat_name: String, direction: int) -> String:
	# 筛选显示文本；与强化石卡片一致使用“属性+”或“属性-”，便于玩家直接按方向定位。
	return "%s%s" % [EnhancementRules.get_stat_label(stat_name), EnhancementRules.get_direction_symbol(direction)]


static func get_stone_attribute_direction_group_label(direction: int) -> String:
	# 分组标题；按词条对目标的玩法影响展示，玩家无需再从正负号反推冷却、后坐力等反向收益属性。
	return "增强" if direction > 0 else "削弱"


static func filter_and_sort_entries(entries: Array, primary_category: String, subcategory: String, search_keyword: String, stone_attribute: Variant, sort_mode: String, equipment_set_filter: Variant = [], stone_quality_filter: String = "") -> Array[Dictionary]:
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
		if not _matches_stone_quality(entry, stone_quality_filter):
			continue
		if not _matches_equipment_set(entry, equipment_set_filter):
			continue
		if not normalized_keyword.is_empty() and not _build_search_text(entry).contains(normalized_keyword):
			continue
		result.append(entry)

	_sort_entries(result, sort_mode)
	return result


static func collect_equipment_set_filter_options(entries: Array) -> Array[Dictionary]:
	## 收集条目中全部套装的稳定 ID 与显示名称；重复套装只返回一次，并按显示名称排序供筛选控件复用。
	# 套装名称表；键为稳定 set_id，值为玩家可见名称，避免同套装四件装备生成四个选项。
	var labels_by_set_id: Dictionary = {}
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		# 当前装备资源；只有 item_kind=equipment 且配置有效套装引用时进入筛选选项。
		var item_resource: Resource = (raw_entry as Dictionary).get("resource") as Resource
		if item_resource == null or str(item_resource.get("item_kind")) != "equipment":
			continue
		# 套装资源；旧无套装装备保持可浏览，但不会生成空筛选项。
		var equipment_set: Resource = item_resource.get("equipment_set") as Resource
		if equipment_set == null:
			continue
		# 套装稳定 ID；空 ID 回退资源路径，保证合法旧资源仍可被精确筛选。
		var set_id: String = str(equipment_set.get("set_id")).strip_edges()
		if set_id.is_empty():
			set_id = equipment_set.resource_path
		if set_id.is_empty():
			continue
		# 套装显示名；缺失时回退稳定 ID，筛选功能不依赖具体中文文本。
		var display_name: String = str(equipment_set.get("display_name")).strip_edges()
		labels_by_set_id[set_id] = display_name if not display_name.is_empty() else set_id
	# 套装选项；结构固定包含 id 与 label，独立控件无需读取装备资源字段。
	var options: Array[Dictionary] = []
	for raw_set_id in labels_by_set_id.keys():
		options.append({"id": str(raw_set_id), "label": str(labels_by_set_id.get(raw_set_id, raw_set_id))})
	options.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return str(first.get("label", "")) < str(second.get("label", "")))
	return options


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
		if weapon_type not in [SUBCATEGORY_MELEE, SUBCATEGORY_RANGED, "hybrid"]:
			return false
		return subcategory == SUBCATEGORY_ALL or weapon_type == subcategory or (weapon_type == "hybrid" and subcategory in [SUBCATEGORY_MELEE, SUBCATEGORY_RANGED])
	if primary_category == PRIMARY_EQUIPMENT:
		return item_kind == "equipment" and (subcategory == SUBCATEGORY_ALL or str(item_resource.get("equipment_slot")) == subcategory)
	if primary_category == PRIMARY_RESOURCES:
		if item_kind in ["weapon", "equipment"] or weapon_type in [SUBCATEGORY_MELEE, SUBCATEGORY_RANGED, "hybrid"]:
			return false
		return subcategory == SUBCATEGORY_ALL or (subcategory == SUBCATEGORY_ENHANCEMENT_STONES and item_kind == "enhancement_stone") or (subcategory == SUBCATEGORY_ITEMS and item_kind in ["repair_kit", "consumable"])
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
	var modifiers: Dictionary = item_resource.call("get_normalized_modifiers") as Dictionary if item_resource.has_method("get_normalized_modifiers") else EnhancementRules.normalize_modifiers(item_resource.get("modifiers") as Dictionary, str(item_resource.get("quality_id")) == EnhancementRules.QUALITY_SPECIALIZED)
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


static func _matches_stone_quality(entry: Dictionary, stone_quality_filter: String) -> bool:
	## 判断条目是否命中强化石品质筛选；空条件不过滤，选中品质后只保留对应强化石并隐藏其他资源。
	# 标准品质条件；只接受规则目录稳定标识，异常字符串按空条件处理，避免调用方误传后隐藏全部物品。
	var normalized_quality_filter: String = stone_quality_filter if stone_quality_filter in EnhancementRules.QUALITY_ORDER else ""
	if normalized_quality_filter.is_empty():
		return true
	# 条目资源；品质条件启用后非强化石资源不参与结果。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null or str(item_resource.get("item_kind")) != "enhancement_stone":
		return false
	# 实际品质；优先读取强化石公开归一化接口，异常扩展资源回退原始 quality_id 字段。
	var actual_quality_id: String = str(item_resource.call("get_resolved_quality_id")) if item_resource.has_method("get_resolved_quality_id") else str(item_resource.get("quality_id"))
	return actual_quality_id == normalized_quality_filter


static func _matches_equipment_set(entry: Dictionary, equipment_set_filter: Variant) -> bool:
	## 判断装备是否命中套装多选筛选；空条件不过滤，非装备和无套装装备在存在条件时不显示。
	# 标准筛选 ID；兼容 Array 与 PackedStringArray，忽略空值和重复项。
	var selected_set_ids: Array[String] = []
	if equipment_set_filter is Array or equipment_set_filter is PackedStringArray:
		for raw_set_id in equipment_set_filter:
			var selected_set_id: String = str(raw_set_id).strip_edges()
			if not selected_set_id.is_empty() and selected_set_id not in selected_set_ids:
				selected_set_ids.append(selected_set_id)
	elif equipment_set_filter is String and not str(equipment_set_filter).strip_edges().is_empty():
		selected_set_ids.append(str(equipment_set_filter).strip_edges())
	if selected_set_ids.is_empty():
		return true
	# 条目装备；筛选开启后只保留配置套装的穿戴装备。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null or str(item_resource.get("item_kind")) != "equipment":
		return false
	# 套装资源；无套装装备不会命中任何具体套装 ID。
	var equipment_set: Resource = item_resource.get("equipment_set") as Resource
	if equipment_set == null:
		return false
	# 实际套装 ID；规则与选项收集保持一致，空稳定 ID 回退资源路径。
	var actual_set_id: String = str(equipment_set.get("set_id")).strip_edges()
	if actual_set_id.is_empty():
		actual_set_id = equipment_set.resource_path
	return actual_set_id in selected_set_ids


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


static func clear_search_text_cache() -> void:
	## 清空搜索文本静态缓存；库存被整体重载或外部希望强制重建搜索文本时调用，日常运行依赖容量上限自动清理。
	_search_text_cache.clear()


static func _build_search_text_cache_key(item_resource: Resource) -> String:
	## 生成搜索文本缓存键；普通物品的搜索字段在实例创建后不再变化，直接使用资源实例 id 即可。
	## 强化石的搜索文本包含词条方向，额外并入品质与词条哈希组成组合键，任何词条差异都会落到新键，保证搜索结果永远正确。
	# 物品类型；只有强化石的搜索文本内容依赖词条数据，其余物品名称、说明与分类均为创建后不变的静态字段。
	var item_kind: String = str(item_resource.get("item_kind"))
	if item_kind != "enhancement_stone":
		return str(item_resource.get_instance_id())
	# 强化石词条词典；升阶与读档都会生成新资源实例，这里仍并入哈希防御任何未来的在位改写路径。
	var stone_modifiers: Variant = item_resource.get("modifiers")
	# 词条哈希值；词典缺失的异常扩展资源按 0 处理，仍能获得稳定组合键。
	var modifiers_hash: int = hash(stone_modifiers) if stone_modifiers is Dictionary else 0
	return "%d:%s:%d" % [item_resource.get_instance_id(), str(item_resource.get("quality_id")), modifiers_hash]


static func _build_search_text(entry: Dictionary) -> String:
	# 条目资源；空资源使用空文本，避免关键词查询报错。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return ""
	# 搜索文本缓存键；命中静态缓存时直接返回历史拼接结果，避免每条目每次查询都重建大字符串。
	var cache_key: String = _build_search_text_cache_key(item_resource)
	if _search_text_cache.has(cache_key):
		return str(_search_text_cache.get(cache_key, ""))
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
	elif weapon_type == "hybrid":
		search_parts.append("武器 远程 近战 混合")
	else:
		search_parts.append("资源 强化石" if str(item_resource.get("item_kind")) == "enhancement_stone" else ("资源 道具 修复包" if str(item_resource.get("item_kind")) == "repair_kit" else ("资源 道具 消耗品" if str(item_resource.get("item_kind")) == "consumable" else ("装备 头部 躯干 腿部 脚部" if str(item_resource.get("item_kind")) == "equipment" else "资源"))))
	if str(item_resource.get("item_kind")) == "enhancement_stone":
		# 强化词典；将“伤害+”“冷却+”等可见词条加入搜索内容。
		var modifiers: Dictionary = item_resource.call("get_normalized_modifiers") as Dictionary if item_resource.has_method("get_normalized_modifiers") else EnhancementRules.normalize_modifiers(item_resource.get("modifiers") as Dictionary, str(item_resource.get("quality_id")) == EnhancementRules.QUALITY_SPECIALIZED)
		for stat_name in EnhancementRules.STAT_KEYS:
			if modifiers.has(stat_name):
				search_parts.append(EnhancementRules.build_modifier_token(stat_name, modifiers.get(stat_name, 0.0)))
	if str(item_resource.get("item_kind")) == "equipment":
		# 套装搜索文本；允许直接输入“开拓者套装”“骇客套装”等显示名定位全部部件。
		var equipment_set: Resource = item_resource.get("equipment_set") as Resource
		if equipment_set != null:
			search_parts.append(str(equipment_set.get("set_id")))
			search_parts.append(str(equipment_set.get("display_name")))
	# 完整搜索文本；写入缓存前检查容量上限，超限时整体清空而不是逐条淘汰，绝不返回过期文本。
	var search_text: String = " ".join(search_parts).to_lower()
	if _search_text_cache.size() >= SEARCH_TEXT_CACHE_LIMIT:
		_search_text_cache.clear()
	_search_text_cache[cache_key] = search_text
	return search_text


static func _sort_entries(entries: Array[Dictionary], sort_mode: String) -> void:
	## 装饰-排序-还原：排序前一次性为每条 entry 预计算当前 sort_mode 需要的排序键，比较阶段只读取预计算键，
	## 不再让每次比较重新走价值与耐久的完整计算链；比较链本身与 _should_come_before 保持逐条一致。
	## 稳定性说明：原插入排序稳定，且原比较函数末级已按唯一 source_index 升序收尾，构成严格全序；
	## 装饰比较器保留同一 source_index 末级比较（结果数组本身按 source_index 升序构建，等价于原始顺序），
	## 因此即使 Array.sort_custom 不稳定，相等键条目的最终顺序也与原实现逐位一致。
	# 待排序条目数量；0 或 1 条时无需预计算排序键，直接保持原有顺序返回。
	var entry_count: int = entries.size()
	if entry_count <= 1:
		return
	# 装饰条目数组；每项持有原条目引用与预计算键，排序完成后按新顺序写回原数组并丢弃装饰记录。
	var decorated_entries: Array[Dictionary] = []
	for entry in entries:
		# 单条装饰记录；键名仅存在于本地临时数组，不写入业务 entry 字典，因此无需前缀防冲突也无需事后清理。
		var decorated_entry: Dictionary = {"entry": entry}
		if sort_mode == SORT_ITEM_VALUE:
			# 预计算总价值；单价乘堆叠数量，与 _should_come_before 的即时计算结果一致，每条只计算一次。
			decorated_entry["total_value"] = _get_entry_total_value(entry)
		elif sort_mode == SORT_DURABILITY:
			# 预计算耐久比例；无耐久物品为 -1，保持与原比较函数相同的末尾排序位置。
			decorated_entry["durability_ratio"] = _get_entry_durability_ratio(entry)
			# 预计算当前耐久值；相同比例时的第二级降序比较键。
			decorated_entry["current_durability"] = _get_entry_current_durability(entry)
		# 预计算获得时间；默认排序与各模式回退比较统一使用的时间倒序键。
		decorated_entry["acquired_at"] = float(entry.get("acquired_at", 0.0))
		# 预计算源下标；唯一末级比较键，保证相等键条目维持原插入排序的稳定顺序。
		decorated_entry["source_index"] = int(entry.get("source_index", 0))
		decorated_entries.append(decorated_entry)
	decorated_entries.sort_custom(_compare_decorated_entries.bind(sort_mode))
	for entry_index in range(entry_count):
		entries[entry_index] = decorated_entries[entry_index].get("entry") as Dictionary


static func _compare_decorated_entries(first_decorated: Dictionary, second_decorated: Dictionary, sort_mode: String) -> bool:
	## 比较两条装饰记录；比较层级、方向与相等判断和 _should_come_before 完全一致，只是读取预计算键而不重新计算。
	if sort_mode == SORT_ITEM_VALUE:
		# 第一项预计算总价值；来自装饰阶段的一次性计算结果。
		var first_value: int = int(first_decorated.get("total_value", 0))
		# 第二项预计算总价值；用于降序比较。
		var second_value: int = int(second_decorated.get("total_value", 0))
		if first_value != second_value:
			return first_value > second_value
	elif sort_mode == SORT_DURABILITY:
		# 第一项预计算耐久比例；无耐久物品为 -1，始终排在全部带耐久物品之后。
		var first_durability_ratio: float = float(first_decorated.get("durability_ratio", -1.0))
		# 第二项预计算耐久比例；与第一项执行降序比较。
		var second_durability_ratio: float = float(second_decorated.get("durability_ratio", -1.0))
		if not is_equal_approx(first_durability_ratio, second_durability_ratio):
			return first_durability_ratio > second_durability_ratio
		# 第一项预计算当前耐久值；相同比例时优先显示实际剩余耐久更高的物品。
		var first_current_durability: float = float(first_decorated.get("current_durability", -1.0))
		# 第二项预计算当前耐久值；用于同耐久比例下的降序比较。
		var second_current_durability: float = float(second_decorated.get("current_durability", -1.0))
		if not is_equal_approx(first_current_durability, second_current_durability):
			return first_current_durability > second_current_durability
	# 第一项预计算获得时间；时间越新越靠前。
	var first_time: float = float(first_decorated.get("acquired_at", 0.0))
	# 第二项预计算获得时间；用于默认时间倒序比较。
	var second_time: float = float(second_decorated.get("acquired_at", 0.0))
	if not is_equal_approx(first_time, second_time):
		return first_time > second_time
	return int(first_decorated.get("source_index", 0)) < int(second_decorated.get("source_index", 0))


static func _should_come_before(first_entry: Dictionary, second_entry: Dictionary, sort_mode: String) -> bool:
	## 原始逐条比较实现；现作为装饰比较器的语义参照保留，任何排序规则调整必须同步修改 _compare_decorated_entries。
	if sort_mode == SORT_ITEM_VALUE:
		# 第一项总价值；单价乘堆叠数量，武器数量固定为 1。
		var first_value: int = _get_entry_total_value(first_entry)
		# 第二项总价值；用于降序比较。
		var second_value: int = _get_entry_total_value(second_entry)
		if first_value != second_value:
			return first_value > second_value
	elif sort_mode == SORT_DURABILITY:
		# 第一项耐久比例；无耐久物品使用 -1，始终排在全部带耐久物品之后。
		var first_durability_ratio: float = _get_entry_durability_ratio(first_entry)
		# 第二项耐久比例；与第一项执行降序比较。
		var second_durability_ratio: float = _get_entry_durability_ratio(second_entry)
		if not is_equal_approx(first_durability_ratio, second_durability_ratio):
			return first_durability_ratio > second_durability_ratio
		# 当前耐久值；相同比例时优先显示实际剩余耐久更高的物品，避免不同上限物品顺序含糊。
		var first_current_durability: float = _get_entry_current_durability(first_entry)
		# 第二项当前耐久值；用于同耐久比例下的降序比较。
		var second_current_durability: float = _get_entry_current_durability(second_entry)
		if not is_equal_approx(first_current_durability, second_current_durability):
			return first_current_durability > second_current_durability
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
	# 单件价值；武器优先读取强化和耐久结算后的有效价值，其他资源读取固定价值。
	var unit_value: int = int(item_resource.call("get_effective_value")) if item_resource.has_method("get_effective_value") else maxi(int(item_resource.get("value")), 0)
	# 堆叠数量；武器为 1，资源限制在至少 1。
	var quantity: int = maxi(int(entry.get("quantity", 1)), 1)
	return unit_value * quantity


static func _get_entry_durability_ratio(entry: Dictionary) -> float:
	# 条目资源；只有同时具有当前耐久和最大耐久字段的物品参与耐久排序。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null or item_resource.get("current_durability") == null or item_resource.get("max_durability") == null:
		return -1.0
	if item_resource.has_method("get_durability_ratio"):
		# 有效耐久比例；装备接口会纳入耐久上限强化，避免排序仍按模板上限计算。
		return clampf(float(item_resource.call("get_durability_ratio")), 0.0, 1.0)
	# 最大耐久；异常非正数按无耐久处理，避免除零并防止损坏数据排到有效物品前方。
	var maximum_durability: float = float(item_resource.get("max_durability"))
	if maximum_durability <= 0.0:
		return -1.0
	return clampf(float(item_resource.get("current_durability")) / maximum_durability, 0.0, 1.0)


static func _get_entry_current_durability(entry: Dictionary) -> float:
	# 条目资源；无当前耐久字段时返回 -1，与耐久比例的无属性排序位置保持一致。
	var item_resource: Resource = entry.get("resource") as Resource
	return maxf(float(item_resource.get("current_durability")), 0.0) if item_resource != null and item_resource.get("current_durability") != null else -1.0
