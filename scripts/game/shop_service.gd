extends Node

## 商店服务独立维护普通商店库存、自动刷新时间、手动刷新费用和灰市失败批次。
## UI 只通过公开查询与购买接口交互，金币和物品所有权仍由 GlobalInventory 统一结算与持久化。

signal shop_stock_changed
signal gray_market_changed
signal refresh_state_changed

## 商店独立存档路径；保存当前库存、刷新截止时间和最近五次失败灰市批次。
const SAVE_PATH: String = "user://shop_state.json"
## 商店存档版本；版本 1 保存普通库存、手动刷新次数和灰市滚动批次。
const SAVE_VERSION: int = 1
## 强化石随机生成的单词条基础售价；默认 30 金币，与战斗掉落规则一致。
const STONE_BASE_SELL_PRICE: int = 30
## 强化石随机生成兼容最少词条数；实际词条数由品质规则决定，该值用于保持统一调用签名。
const STONE_MINIMUM_MODIFIER_COUNT: int = 1
## 强化石随机生成兼容最多词条数；实际词条数由品质规则决定，该值用于保持统一调用签名。
const STONE_MAXIMUM_MODIFIER_COUNT: int = 3
## 强化石随机生成兼容削弱概率；实际概率由品质规则决定，该值用于保持统一调用签名。
const STONE_DETRIMENTAL_CHANCE: float = 0.28

## 普通商店自动刷新间隔；默认 600 秒即 10 分钟，运行时通常不动态修改。
@export_range(60.0, 86400.0, 1.0) var automatic_refresh_interval_seconds: float = 600.0
## 普通商店每次刷新的武器商品数量；默认 6 件，修改会影响武器分类的库存密度。
@export_range(1, 30, 1) var weapon_stock_count: int = 6
## 普通商店每次刷新的装备商品数量；默认 4 件，四个部位等概率抽取并允许重复。
@export_range(1, 30, 1) var equipment_stock_count: int = 4
## 普通商店每次刷新的资源商品数量；默认 6 件，当前资源为随机品质强化石。
@export_range(1, 30, 1) var resource_stock_count: int = 6
## 普通商品最低原价倍率；默认 1.5 倍，与设计规则下限一致。
@export_range(1.0, 20.0, 0.05) var normal_price_multiplier_minimum: float = 1.5
## 普通商品最高原价倍率；默认 3.0 倍，与设计规则上限一致。
@export_range(1.0, 20.0, 0.05) var normal_price_multiplier_maximum: float = 3.0
## 二手枪械出现概率；默认 0.30，仅对 ranged 武器生效，近战武器始终为新品。
@export_range(0.0, 1.0, 0.01) var second_hand_firearm_chance: float = 0.30
## 二手枪械最少耐久消耗比例；默认消耗最大耐久的 10%，确保二手状态可见。
@export_range(0.0, 1.0, 0.01) var second_hand_durability_consumption_minimum: float = 0.10
## 二手枪械最多耐久消耗比例；默认消耗最大耐久的 90%，保留至少 10% 可用耐久。
@export_range(0.0, 1.0, 0.01) var second_hand_durability_consumption_maximum: float = 0.90
## 二手枪械累计使用强化石概率；索引 0 到 9 分别表示至少使用过 1 到 10 颗的概率。
@export var second_hand_enhancement_cumulative_chances: PackedFloat32Array = PackedFloat32Array([0.90, 0.80, 0.65, 0.56, 0.47, 0.38, 0.28, 0.19, 0.10, 0.01])
## 单颗二手强化石寻找兼容词条的最大尝试次数；默认 8 次，避免纯远程词条被用于近战等无效情况。
@export_range(1, 50, 1) var second_hand_stone_compatibility_attempts: int = 8
## 首次手动刷新金币费用；默认 10 金币，每次自动刷新后恢复该数值。
@export_range(0, 999999, 1) var manual_refresh_base_cost: int = 10
## 连续手动刷新费用倍率；默认每次乘 1.5，直到下一次自动刷新重置。
@export_range(1.0, 10.0, 0.05) var manual_refresh_cost_growth: float = 1.5
## 灰市最低满耐久价值倍率；默认 4 倍，用于最近失败遗失物的回购价格。
@export_range(1.0, 50.0, 0.05) var gray_market_price_multiplier_minimum: float = 4.0
## 灰市最高满耐久价值倍率；默认 8 倍，用于最近失败遗失物的回购价格。
@export_range(1.0, 50.0, 0.05) var gray_market_price_multiplier_maximum: float = 8.0
## 灰市保留失败批次数；默认最近 5 次，新增第 6 次时移除最早批次剩余物品。
@export_range(1, 20, 1) var gray_market_failure_limit: int = 5
## 可刷新武器资源路径；每次按等概率抽取并复制为独立商品实例，允许同轮出现同类多件武器。
@export var weapon_resource_paths: PackedStringArray = PackedStringArray([
	"res://data/weapons/quantum_pistol.tres",
	"res://data/weapons/pulse_rifle.tres",
	"res://data/weapons/ion_smg.tres",
	"res://data/weapons/scatter_blaster.tres",
	"res://data/weapons/rail_cannon.tres",
	"res://data/weapons/phase_blade.tres",
	"res://data/weapons/quantum_dagger.tres",
])
## 可刷新装备资源路径；每次刷新从四部位基础装备中等概率复制独立商品。
@export var equipment_resource_paths: PackedStringArray = PackedStringArray([
	"res://data/equipment/basic_headgear.tres",
	"res://data/equipment/basic_body_armor.tres",
	"res://data/equipment/basic_leg_armor.tres",
	"res://data/equipment/basic_boots.tres",
])

## 全局库存服务缓存；负责金币扣除、商品入仓库和资源快照序列化。
var _global_inventory: Node
## 普通商店运行时商品；每项包含唯一编号、资源、数量、价格、倍率和二手说明。
var _shop_stock: Array[Dictionary] = []
## 灰市失败批次；每项包含批次编号和该次失败仍未购回的商品数组。
var _gray_market_failure_groups: Array[Dictionary] = []
## 下次自动刷新 Unix 时间；达到该时间后重建普通库存并重置手动刷新次数。
var _next_automatic_refresh_unix: int = 0
## 当前自动刷新周期内已手动刷新次数；默认 0，每次成功手动刷新后增加 1。
var _manual_refresh_count: int = 0
## 唯一编号递增序号；与毫秒时间组合，避免同一帧创建多个商品时编号冲突。
var _entry_sequence: int = 0
## 商店随机数生成器；启动时随机化，集中负责商品、价格、耐久与二手强化状态。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 已加载商店存档是否修复过异常二手耐久；默认 false，修复后在启动阶段立即回写，避免下次启动再次随机。
var _loaded_state_was_repaired: bool = false


func _ready() -> void:
	_random.randomize()
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if _global_inventory != null and _global_inventory.has_signal("combat_failure_losses_recorded"):
		_global_inventory.connect("combat_failure_losses_recorded", Callable(self, "_on_combat_failure_losses_recorded"))
	if not _load_state():
		_refresh_normal_stock(true)
	elif _loaded_state_was_repaired:
		_save_state()
	ensure_automatic_refresh()


func get_shop_entries() -> Array[Dictionary]:
	ensure_automatic_refresh()
	return _shop_stock.duplicate(true)


func get_gray_market_entries() -> Array[Dictionary]:
	# 灰市平铺结果；保留失败批次编号，UI 无需理解内部滚动批次结构即可分类展示和购买。
	var result: Array[Dictionary] = []
	for failure_group in _gray_market_failure_groups:
		# 批次商品；每项复制后附加批次编号，购买时可精确移除对应条目。
		var group_entries: Array = failure_group.get("entries", []) as Array
		for raw_entry in group_entries:
			if raw_entry is Dictionary:
				var display_entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
				display_entry["failure_group_id"] = str(failure_group.get("group_id", ""))
				result.append(display_entry)
	return result


func get_next_automatic_refresh_unix() -> int:
	ensure_automatic_refresh()
	return _next_automatic_refresh_unix


func get_seconds_until_automatic_refresh() -> int:
	ensure_automatic_refresh()
	# 当前 Unix 秒；系统时间用于关闭游戏后继续推进十分钟刷新周期。
	var current_unix: int = int(Time.get_unix_time_from_system())
	return maxi(_next_automatic_refresh_unix - current_unix, 0)


func get_manual_refresh_cost() -> int:
	# 连续刷新费用；每次按 1.5 指数增长并向上取整，自动刷新后次数归零。
	return ceili(float(manual_refresh_base_cost) * pow(manual_refresh_cost_growth, float(_manual_refresh_count)))


func ensure_automatic_refresh() -> bool:
	# 当前 Unix 秒；用于判断离线时间是否已经跨过自动刷新截止点。
	var current_unix: int = int(Time.get_unix_time_from_system())
	if _next_automatic_refresh_unix > current_unix and not _shop_stock.is_empty():
		return false
	_refresh_normal_stock(true)
	return true


func request_manual_refresh() -> Dictionary:
	ensure_automatic_refresh()
	# 本次刷新费用；成功扣款前固定，避免刷新次数变化后 UI 与实际扣款不同。
	var refresh_cost: int = get_manual_refresh_cost()
	if _global_inventory == null or int(_global_inventory.call("get_coins")) < refresh_cost:
		return {"success": false, "cost": refresh_cost, "message": "金币不足，无法刷新商店"}
	_global_inventory.call("adjust_coins", -refresh_cost)
	_manual_refresh_count += 1
	_refresh_normal_stock(false)
	return {"success": true, "cost": refresh_cost, "message": "商店已刷新"}


func purchase_shop_entry(stock_id: String) -> Dictionary:
	ensure_automatic_refresh()
	return _purchase_entry_from_array(_shop_stock, stock_id, "普通商店")


func purchase_gray_market_entry(stock_id: String, failure_group_id: String) -> Dictionary:
	for group_index in range(_gray_market_failure_groups.size()):
		# 失败批次；编号匹配后只在该批次中查找商品，避免不同批次编号异常时误删。
		var failure_group: Dictionary = _gray_market_failure_groups[group_index]
		if str(failure_group.get("group_id", "")) != failure_group_id:
			continue
		# 批次商品数组；购买成功会原地移除，空批次随后一并清理。
		var group_entries: Array[Dictionary] = []
		for raw_entry in failure_group.get("entries", []) as Array:
			if raw_entry is Dictionary:
				group_entries.append(raw_entry as Dictionary)
		var result: Dictionary = _purchase_entry_from_array(group_entries, stock_id, "灰市")
		if bool(result.get("success", false)):
			failure_group["entries"] = group_entries
			if group_entries.is_empty():
				_gray_market_failure_groups.remove_at(group_index)
			_save_state()
			gray_market_changed.emit()
		return result
	return {"success": false, "message": "该灰市物品已不存在"}


func _purchase_entry_from_array(entries: Array[Dictionary], stock_id: String, channel_name: String) -> Dictionary:
	if _global_inventory == null:
		return {"success": false, "message": "全局库存服务不可用"}
	for entry_index in range(entries.size()):
		# 待购商品；通过稳定编号定位，UI 分类排序不会影响真实库存下标。
		var entry: Dictionary = entries[entry_index]
		if str(entry.get("stock_id", "")) != stock_id:
			continue
		# 商品资源；购买后转交永久仓库，空资源商品视为失效并拒绝扣款。
		var item_resource: Resource = entry.get("resource") as Resource
		# 商品数量；当前武器为一件，资源条目保留扩展堆叠能力。
		var quantity: int = maxi(int(entry.get("quantity", 1)), 1)
		# 商品价格；由刷新或失败记录时固定，购买时不重新抽取倍率。
		var purchase_price: int = maxi(int(entry.get("price", 0)), 0)
		if item_resource == null or not bool(_global_inventory.call("purchase_resource_to_warehouse", item_resource, purchase_price, quantity)):
			return {"success": false, "message": "金币不足，无法购买该物品"}
		entries.remove_at(entry_index)
		_save_state()
		if channel_name == "普通商店":
			shop_stock_changed.emit()
		return {"success": true, "message": "%s购买成功，物品已存入永久仓库" % channel_name, "price": purchase_price}
	return {"success": false, "message": "该商品已售出或已经刷新"}


func _refresh_normal_stock(reset_manual_refresh_count: bool) -> void:
	if reset_manual_refresh_count:
		_manual_refresh_count = 0
		_next_automatic_refresh_unix = int(Time.get_unix_time_from_system() + automatic_refresh_interval_seconds)
	_shop_stock.clear()
	for _weapon_index in range(maxi(weapon_stock_count, 1)):
		# 随机武器商品；加载失败时跳过，不阻断其他商品生成。
		var weapon_resource: Resource = _create_random_weapon()
		if weapon_resource != null:
			_shop_stock.append(_create_normal_stock_entry(weapon_resource))
	for _equipment_index in range(maxi(equipment_stock_count, 1)):
		# 随机装备商品；四部位等概率刷新，资源深拷贝后拥有独立耐久与强化状态。
		var equipment_resource: Resource = _create_random_equipment()
		if equipment_resource != null:
			_shop_stock.append(_create_normal_stock_entry(equipment_resource))
	for _resource_index in range(maxi(resource_stock_count, 1)):
		# 随机资源商品；当前使用与怪物掉落相同的品质强化石生成器。
		var enhancement_stone: EnhancementStoneData = EnhancementStoneData.create_random(_random, STONE_MINIMUM_MODIFIER_COUNT, STONE_MAXIMUM_MODIFIER_COUNT, STONE_DETRIMENTAL_CHANCE, STONE_BASE_SELL_PRICE)
		if enhancement_stone != null:
			_shop_stock.append(_create_normal_stock_entry(enhancement_stone))
	_save_state()
	shop_stock_changed.emit()
	refresh_state_changed.emit()


func _create_random_weapon() -> Resource:
	if weapon_resource_paths.is_empty():
		return null
	# 资源路径；全部已配置武器等概率抽取，允许同轮出现多件同类武器但实例状态独立。
	var resource_path: String = weapon_resource_paths[_random.randi_range(0, weapon_resource_paths.size() - 1)]
	if not ResourceLoader.exists(resource_path):
		return null
	# 武器模板；项目资源保持只读，商品必须深拷贝后才能随机耐久和强化。
	var weapon_template: Resource = load(resource_path) as Resource
	if weapon_template == null:
		return null
	# 武器商品实例；深拷贝保证购买后不会修改同类模板或其他商品。
	var weapon_resource: Resource = weapon_template.duplicate(true) as Resource
	if weapon_resource == null:
		return null
	if str(weapon_resource.get("weapon_type")) == "ranged" and _random.randf() < second_hand_firearm_chance:
		_apply_second_hand_state(weapon_resource)
	return weapon_resource


func _create_random_equipment() -> Resource:
	if equipment_resource_paths.is_empty():
		return null
	# 装备路径；允许同一轮出现同部位或同类装备。
	var resource_path: String = equipment_resource_paths[_random.randi_range(0, equipment_resource_paths.size() - 1)]
	if not ResourceLoader.exists(resource_path):
		return null
	# 装备商品；深拷贝保证购买后的耐久和强化不会污染模板或其他商品。
	var equipment_template: Resource = load(resource_path) as Resource
	var equipment_resource: Resource = equipment_template.duplicate(true) as Resource if equipment_template != null else null
	if equipment_resource != null and _random.randf() < second_hand_firearm_chance:
		# 二手装备；与远程武器使用相同概率、耐久区间和历史强化次数规则。
		_apply_second_hand_state(equipment_resource)
	return equipment_resource


func _apply_second_hand_state(weapon_resource: Resource) -> void:
	if weapon_resource == null or not weapon_resource.has_method("set_current_durability"):
		return
	# 历史强化石数量；使用同一个累计概率随机值，保证至少 N 颗概率严格单调且第 10 颗为 1%。
	var used_stone_count: int = _roll_second_hand_used_stone_count()
	for _stone_index in range(used_stone_count):
		_apply_random_compatible_enhancement(weapon_resource)
	_apply_random_second_hand_durability(weapon_resource)
	# 运行时商品元数据；Resource 未声明该字段时不能直接 set，因此由商品条目读取返回值单独保存。
	weapon_resource.set_meta("shop_second_hand", true)
	weapon_resource.set_meta("shop_used_stone_count", used_stone_count)


func _apply_random_second_hand_durability(item_resource: Resource) -> void:
	if item_resource == null or not item_resource.has_method("set_current_durability"):
		return
	# 耐久消耗比例下限；限制配置到 0 至 1，并允许检查器中上下限顺序颠倒。
	var minimum_consumption: float = clampf(minf(second_hand_durability_consumption_minimum, second_hand_durability_consumption_maximum), 0.0, 1.0)
	# 耐久消耗比例上限；与下限共同决定二手商品随机剩余耐久区间。
	var maximum_consumption: float = clampf(maxf(second_hand_durability_consumption_minimum, second_hand_durability_consumption_maximum), 0.0, 1.0)
	# 本次消耗比例；默认 10% 至 90%，因此最终剩余耐久为最大值的 10% 至 90%。
	var consumed_ratio: float = _random.randf_range(minimum_consumption, maximum_consumption)
	# 最大耐久；武器与装备读取各自模板上限，保证不同耐久规格都按比例随机。
	var maximum_durability: float = maxf(float(item_resource.get("max_durability")), 1.0)
	item_resource.call("set_current_durability", maximum_durability * (1.0 - consumed_ratio))


func _repair_invalid_second_hand_durability(item_resource: Resource, is_second_hand: bool) -> void:
	if not is_second_hand or item_resource == null or not item_resource.has_method("set_current_durability"):
		return
	# 当前耐久；旧商店存档可能已经带二手标记，但仍保存模板满耐久，需要在加载时补齐随机状态。
	var current_durability: float = maxf(float(item_resource.get("current_durability")), 0.0)
	# 最大耐久；只修复达到满耐久的异常二手商品，正常随机商品保持原值并继续跨刷新周期稳定保存。
	var maximum_durability: float = maxf(float(item_resource.get("max_durability")), 1.0)
	if current_durability >= maximum_durability or is_equal_approx(current_durability, maximum_durability):
		_apply_random_second_hand_durability(item_resource)
		_loaded_state_was_repaired = true


func _roll_second_hand_used_stone_count() -> int:
	# 单次累计随机值；低于第 N 项阈值代表至少使用过 N 颗，阈值必须从高到低排列。
	var cumulative_roll: float = _random.randf()
	# 最终颗数；默认 0，10% 情况不会使用过任何强化石。
	var used_stone_count: int = 0
	for chance_index in range(second_hand_enhancement_cumulative_chances.size()):
		# 至少使用概率；限制到 0 至 1，异常配置不会产生越界概率。
		var cumulative_chance: float = clampf(second_hand_enhancement_cumulative_chances[chance_index], 0.0, 1.0)
		if cumulative_roll < cumulative_chance:
			used_stone_count = chance_index + 1
	return used_stone_count


func _apply_random_compatible_enhancement(weapon_resource: Resource) -> bool:
	for _attempt_index in range(maxi(second_hand_stone_compatibility_attempts, 1)):
		# 历史强化石；品质、属性和方向与正常掉落一致，但不会进入玩家库存。
		# 适用类型；装备商品固定使用装备强化石，武器商品固定使用武器强化石。
		var target_kind: String = "equipment" if str(weapon_resource.get("item_kind")) == "equipment" else "weapon"
		var enhancement_stone: EnhancementStoneData = EnhancementStoneData.create_random(_random, STONE_MINIMUM_MODIFIER_COUNT, STONE_MAXIMUM_MODIFIER_COUNT, STONE_DETRIMENTAL_CHANCE, STONE_BASE_SELL_PRICE, target_kind)
		if enhancement_stone == null or not enhancement_stone.can_apply_to_weapon(weapon_resource):
			continue
		# 延迟实际倍率；按品质逐条生成百分比，与玩家在锻造中消耗强化石使用同一规则。
		var rolled_modifiers: Dictionary = {}
		for stat_name in EnhancementRules.STAT_KEYS:
			if enhancement_stone.modifiers.has(stat_name):
				rolled_modifiers[stat_name] = EnhancementRules.roll_quality_modifier_ratio(_random, enhancement_stone.quality_id, stat_name, enhancement_stone.modifiers.get(stat_name, 1))
		if bool(weapon_resource.call("apply_enhancement", rolled_modifiers)):
			return true
	return false


func _create_normal_stock_entry(item_resource: Resource) -> Dictionary:
	# 原价；武器忽略二手耐久和历史强化状态，资源使用自身基础售价。
	var original_price: int = maxi(int(item_resource.get("sell_price")), 0)
	# 价格倍率；每件商品在 1.5 至 3.0 倍范围内独立抽取并在刷新周期内固定。
	var price_multiplier: float = _random.randf_range(minf(normal_price_multiplier_minimum, normal_price_multiplier_maximum), maxf(normal_price_multiplier_minimum, normal_price_multiplier_maximum))
	return {
		"stock_id": _create_unique_id("shop"),
		"resource": item_resource,
		"quantity": 1,
		"price": maxi(roundi(float(original_price) * price_multiplier), 1) if original_price > 0 else 0,
		"price_multiplier": snappedf(price_multiplier, 0.01),
		"second_hand": bool(item_resource.get_meta("shop_second_hand", false)),
		"used_stone_count": int(item_resource.get_meta("shop_used_stone_count", 0)),
	}


func _on_combat_failure_losses_recorded(lost_entries: Array) -> void:
	# 新失败批次商品；每个结构化遗失条目复制成独立灰市商品，后续库存引用不会依赖结算弹窗生命周期。
	var gray_entries: Array[Dictionary] = []
	for raw_entry in lost_entries:
		if not (raw_entry is Dictionary):
			continue
		# 遗失资源；深拷贝保留当时耐久和强化状态，避免原引用被释放或外部修改。
		var lost_resource: Resource = (raw_entry as Dictionary).get("resource") as Resource
		if lost_resource == null:
			continue
		# 灰市资源副本；每个遗失条目只生成一件商品记录，堆叠数量保留在 quantity 字段。
		var gray_resource: Resource = lost_resource.duplicate(true) as Resource
		if gray_resource == null:
			continue
		# 满耐久价值；武器按当前强化状态恢复到满耐久后估值，资源直接使用有效售价。
		var full_durability_value: int = _get_full_durability_value(gray_resource)
		# 遗失数量；武器固定为一，强化石保留该次失败实际遗失的堆叠数量。
		var lost_quantity: int = maxi(int((raw_entry as Dictionary).get("quantity", 1)), 1)
		# 灰市倍率；每项在 4 至 8 倍范围内独立抽取并永久固定到该条目。
		var price_multiplier: float = _random.randf_range(minf(gray_market_price_multiplier_minimum, gray_market_price_multiplier_maximum), maxf(gray_market_price_multiplier_minimum, gray_market_price_multiplier_maximum))
		gray_entries.append({
			"stock_id": _create_unique_id("gray"),
			"resource": gray_resource,
			"quantity": lost_quantity,
			"price": maxi(roundi(float(full_durability_value * lost_quantity) * price_multiplier), 1) if full_durability_value > 0 else 0,
			"price_multiplier": snappedf(price_multiplier, 0.01),
			"second_hand": false,
			"used_stone_count": 0,
		})
	if gray_entries.is_empty():
		return
	_gray_market_failure_groups.append({"group_id": _create_unique_id("failure"), "entries": gray_entries})
	while _gray_market_failure_groups.size() > maxi(gray_market_failure_limit, 1):
		_gray_market_failure_groups.remove_at(0)
	_save_state()
	gray_market_changed.emit()


func _get_full_durability_value(item_resource: Resource) -> int:
	if item_resource == null:
		return 0
	if str(item_resource.get("weapon_type")) in ["ranged", "melee"]:
		# 估值副本；只在副本上恢复满耐久，灰市最终售卖的真实遗失武器仍保持丢失时耐久。
		var valuation_weapon: Resource = item_resource.duplicate(true) as Resource
		if valuation_weapon == null:
			return 0
		valuation_weapon.call("set_current_durability", float(valuation_weapon.get("max_durability")))
		return int(valuation_weapon.call("get_effective_sell_price"))
	return int(item_resource.call("get_effective_sell_price")) if item_resource.has_method("get_effective_sell_price") else maxi(int(item_resource.get("sell_price")), 0)


func _create_unique_id(prefix: String) -> String:
	_entry_sequence += 1
	return "%s_%d_%d" % [prefix, Time.get_ticks_msec(), _entry_sequence]


func _save_state() -> void:
	if _global_inventory == null:
		return
	# 普通库存序列化数组；Resource 通过 GlobalInventory 稳定快照格式写入 JSON。
	var serialized_shop_stock: Array[Dictionary] = []
	for entry in _shop_stock:
		serialized_shop_stock.append(_serialize_stock_entry(entry))
	# 灰市批次序列化数组；保留批次边界才能在新增失败时准确移除最早一次。
	var serialized_gray_groups: Array[Dictionary] = []
	for failure_group in _gray_market_failure_groups:
		# 单批次序列化商品；已购买条目不会再次写回存档。
		var serialized_group_entries: Array[Dictionary] = []
		for raw_entry in failure_group.get("entries", []) as Array:
			if raw_entry is Dictionary:
				serialized_group_entries.append(_serialize_stock_entry(raw_entry as Dictionary))
		serialized_gray_groups.append({"group_id": str(failure_group.get("group_id", "")), "entries": serialized_group_entries})
	# 商店存档根字典；自动刷新截止时间使用 Unix 秒，退出游戏期间仍会正常流逝。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"next_automatic_refresh_unix": _next_automatic_refresh_unix,
		"manual_refresh_count": _manual_refresh_count,
		"entry_sequence": _entry_sequence,
		"shop_stock": serialized_shop_stock,
		"gray_market_failure_groups": serialized_gray_groups,
	}
	# 商店存档文件；打开失败时保留内存状态，不影响本次会话购买与刷新。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data))


func _load_state() -> bool:
	_loaded_state_was_repaired = false
	if _global_inventory == null or not FileAccess.file_exists(SAVE_PATH):
		return false
	# 商店存档文件；读取失败或 JSON 损坏时回退全新刷新，不影响玩家主库存存档。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return false
	# 商店存档解析结果；根节点必须为 Dictionary，否则视为无效存档。
	var parsed_data: Variant = JSON.parse_string(save_file.get_as_text())
	if not (parsed_data is Dictionary):
		return false
	# 商店存档字典；当前版本只读取已知字段，新增字段可向后兼容。
	var save_data: Dictionary = parsed_data as Dictionary
	_next_automatic_refresh_unix = int(save_data.get("next_automatic_refresh_unix", 0))
	_manual_refresh_count = maxi(int(save_data.get("manual_refresh_count", 0)), 0)
	_entry_sequence = maxi(int(save_data.get("entry_sequence", 0)), 0)
	_shop_stock.clear()
	for raw_entry in save_data.get("shop_stock", []) as Array:
		if raw_entry is Dictionary:
			var restored_entry: Dictionary = _deserialize_stock_entry(raw_entry as Dictionary)
			if not restored_entry.is_empty():
				_shop_stock.append(restored_entry)
	_gray_market_failure_groups.clear()
	for raw_group in save_data.get("gray_market_failure_groups", []) as Array:
		if not (raw_group is Dictionary):
			continue
		# 恢复批次商品；损坏条目单独跳过，其他物品和批次仍然可用。
		var restored_group_entries: Array[Dictionary] = []
		for raw_entry in (raw_group as Dictionary).get("entries", []) as Array:
			if raw_entry is Dictionary:
				var restored_entry: Dictionary = _deserialize_stock_entry(raw_entry as Dictionary)
				if not restored_entry.is_empty():
					restored_group_entries.append(restored_entry)
		if not restored_group_entries.is_empty():
			_gray_market_failure_groups.append({"group_id": str((raw_group as Dictionary).get("group_id", _create_unique_id("failure"))), "entries": restored_group_entries})
	return not _shop_stock.is_empty()


func _serialize_stock_entry(entry: Dictionary) -> Dictionary:
	# 商品资源；空资源返回空字典，加载时会被安全忽略。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return {}
	# 商品数量；传给库存快照以完整保存强化石堆叠或未来可堆叠资源。
	var quantity: int = maxi(int(entry.get("quantity", 1)), 1)
	return {
		"stock_id": str(entry.get("stock_id", "")),
		"item_snapshot": _global_inventory.call("serialize_item_snapshot", item_resource, quantity) as Dictionary,
		"price": maxi(int(entry.get("price", 0)), 0),
		"price_multiplier": float(entry.get("price_multiplier", 1.0)),
		"second_hand": bool(entry.get("second_hand", false)),
		"used_stone_count": maxi(int(entry.get("used_stone_count", 0)), 0),
	}


func _deserialize_stock_entry(serialized_entry: Dictionary) -> Dictionary:
	# 物品快照；由 GlobalInventory 兼容恢复武器耐久、累计强化和强化石品质词条。
	var restored_snapshot: Dictionary = _global_inventory.call("deserialize_item_snapshot", serialized_entry.get("item_snapshot", {}) as Dictionary) as Dictionary
	# 恢复资源；无效路径或损坏字段会返回空资源并丢弃该商品。
	var item_resource: Resource = restored_snapshot.get("resource") as Resource
	if item_resource == null:
		return {}
	# 二手状态；独立读取后用于修复旧存档中二手商品仍为满耐久的问题。
	var is_second_hand: bool = bool(serialized_entry.get("second_hand", false))
	_repair_invalid_second_hand_durability(item_resource, is_second_hand)
	return {
		"stock_id": str(serialized_entry.get("stock_id", _create_unique_id("stock"))),
		"resource": item_resource,
		"quantity": maxi(int(restored_snapshot.get("quantity", 1)), 1),
		"price": maxi(int(serialized_entry.get("price", 0)), 0),
		"price_multiplier": float(serialized_entry.get("price_multiplier", 1.0)),
		"second_hand": is_second_hand,
		"used_stone_count": maxi(int(serialized_entry.get("used_stone_count", 0)), 0),
	}
