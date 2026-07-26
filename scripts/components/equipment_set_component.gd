extends Node
class_name EquipmentSetComponent

## 装备套装组件只负责统计当前有效防具的套装件数，并把数据资源中的档位效果转换为属性或世界行为结果。
## 装备槽所有权仍属于 GlobalInventory，普通装备属性仍由 EquipmentComponent 聚合，本组件不移动物品也不保存重复状态。

## 固定防具部位顺序；与 GlobalInventory 和 EquipmentComponent 保持一致，套装只统计头部、躯干、腿部与脚部。
const ARMOR_SLOT_IDS: Array[String] = ["head", "body", "legs", "feet"]
## 附近掉落物触发缓存有效窗口；单位毫秒，0.12 秒对移速倍率与受击免伤精度足够，用于消除逐物理帧的掉落物组全量扫描。
const NEARBY_DROP_EFFECTS_CACHE_WINDOW_MSEC: int = 120

## 装备组件路径；默认指向同级 EquipmentComponent，运行时通常不修改，替换玩家组件结构时可在检查器中调整。
@export var equipment_component_path: NodePath = ^"../EquipmentComponent"

## 装备组件缓存；用于世界特殊效果结算时读取当前四部位资源，不持有或复制装备所有权。
var _equipment_component: Node
## 最近一次满足套装条件的击杀增益剩余时间；取值大于等于 0，重复击杀刷新为当前有效套装的最长持续时间。
var _recent_kill_dodge_remaining: float = 0.0
## 本场战斗是否已经消耗任意套装提供的首次致命恢复；默认 false，成功拦截一次致命伤害后永久变为 true，组件重新进入战斗场景时重置。
var _first_lethal_recovery_consumed: bool = false
## 当前有效套装状态缓存；键为稳定 set_id，值包含套装资源与未损坏穿戴件数，只在装备变化时重建以避免高频战斗查询重复创建字典。
var _active_set_states_cache: Dictionary = {}
## 当前已达到门槛的附近掉落物效果缓存；每项保存半径与攻防比例，装备变化时重建，空数组可让无对应套装的玩家直接跳过掉落物组扫描。
var _nearby_drop_effects_cache: Array[Dictionary] = []
## 附近掉落物触发结果节流缓存；保存最近一次 item_drops 组扫描得到的触发效果，移速与受击查询在窗口内共用同一结果。
var _triggered_drop_effects_cache: Array[Dictionary] = []
## 附近掉落物触发缓存采样时间戳；单位毫秒，默认 -1 表示尚未采样，窗口过期或装备变化后下一次查询会重新扫描。
var _triggered_drop_effects_cache_timestamp_msec: int = -1


func _ready() -> void:
	_equipment_component = get_node_or_null(equipment_component_path)
	# 装备变化信号源；正式玩家优先监听装备组件，隔离场景缺少该组件时回退全局库存服务。
	var equipment_changed_source: Node = _equipment_component
	if equipment_changed_source == null:
		equipment_changed_source = get_tree().root.get_node_or_null("GlobalInventory")
	if equipment_changed_source != null and equipment_changed_source.has_signal("equipment_changed"):
		# 装备变化驱动缓存失效；换装、耐久损坏与已装备物品修复都会通过同一入口刷新。
		var refresh_callable: Callable = Callable(self, "_refresh_active_set_cache")
		if not equipment_changed_source.is_connected("equipment_changed", refresh_callable):
			equipment_changed_source.connect("equipment_changed", refresh_callable)
	# 同级 EquipmentComponent 的初始化顺序可能晚于本节点，延迟到全部 _ready 完成后读取首份权威装备快照。
	call_deferred("_refresh_active_set_cache")
	# 套装常驻查询不需要逐帧处理，只有击杀闪避存在持续时间时才启用计时。
	set_process(false)


func _process(delta: float) -> void:
	## 只维护击杀增益计时；套装在持续期间失效时查询接口会立即返回 0，无需等待计时归零。
	_recent_kill_dodge_remaining = maxf(_recent_kill_dodge_remaining - maxf(delta, 0.0), 0.0)
	if _recent_kill_dodge_remaining <= 0.0:
		# 当前没有需要推进的套装计时；下一次合法击杀通知会重新启用处理。
		set_process(false)


static func collect_active_set_states(armor_equipment: Dictionary) -> Dictionary:
	## 统计已穿戴且未损坏的套装部件；结果键为 set_id，值包含套装资源与有效件数。
	# 套装状态表；不同资源实例只要 set_id 相同就合并，适配库存深拷贝后的装备。
	var set_states: Dictionary = {}
	for armor_slot in ARMOR_SLOT_IDS:
		# 当前部位装备；空槽或损坏装备不提供普通属性，也不计入套装触发件数。
		var equipment_data: Resource = armor_equipment.get(armor_slot) as Resource
		if equipment_data == null or (equipment_data.has_method("is_broken") and bool(equipment_data.call("is_broken"))):
			continue
		if not _resource_has_property(equipment_data, "equipment_set"):
			continue
		# 套装数据资源；没有 equipment_set 字段或未配置引用的基础装备保持独立，不进入套装表。
		var equipment_set: Resource = equipment_data.get("equipment_set") as Resource
		if equipment_set == null:
			continue
		# 套装稳定标识；空 ID 配置无效，避免所有未命名套装意外合并。
		var set_id: String = str(equipment_set.get("set_id")).strip_edges()
		if set_id.is_empty():
			continue
		# 当前套装状态；首次出现时保存权威套装资源，后续同 ID 装备只增加有效件数。
		var set_state: Dictionary = set_states.get(set_id, {"set_data": equipment_set, "piece_count": 0}) as Dictionary
		set_state["piece_count"] = int(set_state.get("piece_count", 0)) + 1
		set_states[set_id] = set_state
	return set_states


static func get_active_piece_count_for_set(armor_equipment: Dictionary, set_id: String) -> int:
	## 返回指定套装当前有效穿戴件数；未知或空套装 ID 返回 0。
	# 套装状态；复用统一统计确保 UI 激活颜色与实际战斗效果完全一致。
	var set_state: Dictionary = collect_active_set_states(armor_equipment).get(set_id, {}) as Dictionary
	return maxi(int(set_state.get("piece_count", 0)), 0)


static func calculate_active_attribute_bonuses(armor_equipment: Dictionary) -> Dictionary:
	## 汇总全部已触发套装的属性效果；多个不同套装提供同一属性时直接累计。
	# 全部套装属性；只返回数据资源实际声明的键，普通装备聚合器负责校验支持范围。
	var accumulated_bonuses: Dictionary = {}
	# 套装状态遍历项；每项已经排除空槽与损坏装备。
	for raw_set_state in collect_active_set_states(armor_equipment).values():
		# 当前套装状态；包含权威资源和有效件数，异常类型安全跳过。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 套装数据；必须实现统一属性查询接口，避免组件理解每个套装的具体数值字段。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set == null or not equipment_set.has_method("get_attribute_bonuses"):
			continue
		# 当前套装属性；达到的低档位与高档位已经由数据资源内部累计。
		var set_bonuses: Dictionary = equipment_set.call("get_attribute_bonuses", int(set_state.get("piece_count", 0))) as Dictionary
		for raw_stat_name in set_bonuses.keys():
			# 属性稳定名称；与 EquipmentData 有效属性键一致，供装备组件直接合并。
			var stat_name: String = str(raw_stat_name)
			# 属性加成；允许多个套装同属性叠加，正负数都保持数据资源原意。
			var bonus_value: float = float(set_bonuses.get(raw_stat_name, 0.0))
			accumulated_bonuses[stat_name] = float(accumulated_bonuses.get(stat_name, 0.0)) + bonus_value
	return accumulated_bonuses


static func calculate_active_attribute_multipliers(armor_equipment: Dictionary) -> Dictionary:
	## 汇总全部已触发套装的最终属性比例；多个套装提供同一属性时比例直接相加，再由属性组件统一乘算。
	var accumulated_multipliers: Dictionary = {}
	for raw_set_state in collect_active_set_states(armor_equipment).values():
		# 当前套装状态；包含套装资源和有效件数，异常类型安全跳过。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 套装数据；只有实现倍率查询接口的资源参与，旧套装继续保持原有直接属性效果。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set == null or not equipment_set.has_method("get_attribute_multipliers"):
			continue
		# 当前套装倍率；达到的低档位与高档位已经在数据资源内累计。
		var set_multipliers: Dictionary = equipment_set.call("get_attribute_multipliers", int(set_state.get("piece_count", 0))) as Dictionary
		for raw_stat_name in set_multipliers.keys():
			# 属性稳定名称；空键跳过，比例允许为正负值以支持风险型套装。
			var stat_name: String = str(raw_stat_name).strip_edges()
			if not stat_name.is_empty():
				accumulated_multipliers[stat_name] = float(accumulated_multipliers.get(stat_name, 0.0)) + float(set_multipliers.get(raw_stat_name, 0.0))
	return accumulated_multipliers


func get_active_attribute_bonuses(armor_equipment: Dictionary) -> Dictionary:
	## 为玩家装备组件提供实例接口；内部复用纯静态计算，便于局外 UI 与无头测试使用相同规则。
	return calculate_active_attribute_bonuses(armor_equipment)


func get_active_attribute_multipliers(armor_equipment: Dictionary) -> Dictionary:
	## 为玩家战斗属性组件提供最终属性比例快照；内部复用纯静态计算，UI 和无头验证可得到相同结果。
	return calculate_active_attribute_multipliers(armor_equipment)


func roll_manual_chest_extra_drop_count(random_source: RandomNumberGenerator) -> int:
	## 为一次主动长按宝箱结算全部已触发套装特殊效果；不同套装的额外数量允许累计。
	# 当前防具；统一从装备组件或全局库存读取，保证世界行为与角色属性使用同一装备快照。
	# 该权威快照已在装备变化时写入套装状态缓存，此入口直接消费缓存以避免宝箱结算再次聚合相同防具。
	# 额外掉落总数；初始为 0，未达到任何特殊效果门槛时保持不变。
	var extra_drop_count: int = 0
	# 套装状态遍历项；每个已触发四件档位的套装独立执行自身概率判定。
	for raw_set_state in _active_set_states_cache.values():
		# 当前套装状态；包含套装资源与有效件数。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 套装数据；没有宝箱结算接口的兼容资源不会影响其他套装。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set == null or not equipment_set.has_method("roll_manual_chest_extra_drop_count"):
			continue
		extra_drop_count += maxi(int(equipment_set.call("roll_manual_chest_extra_drop_count", int(set_state.get("piece_count", 0)), random_source)), 0)
	return extra_drop_count


func try_consume_first_lethal_recovery() -> float:
	## 尝试消费本场战斗唯一一次套装致命恢复；成功返回应恢复的生命上限比例，失败返回 0。
	if _first_lethal_recovery_consumed:
		return 0.0
	# 当前防具；只统计致命伤害发生瞬间仍穿戴且未损坏的套装部件，背包与仓库装备不会参与。
	# 装备变化信号会在换装、损坏与修复时同步重建缓存，因此致命伤害入口读取的仍是当前有效状态。
	# 最终恢复比例；多个套装同时提供效果时取最高值，确保一次致命伤害只消费一次且不会叠加超过设计值。
	var recovery_health_ratio: float = 0.0
	for raw_set_state in _active_set_states_cache.values():
		# 当前套装状态；包含共享套装资源与当前有效件数，异常资源会被安全跳过。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 套装数据；只有实现统一致命恢复查询接口的资源才参与，组件不依赖具体 set_id。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set == null or not equipment_set.has_method("get_first_lethal_recovery_health_ratio"):
			continue
		# 当前套装恢复比例；限制到 0 至 1，防止异常资源把生命设置到上限之外。
		var set_recovery_health_ratio: float = clampf(float(equipment_set.call("get_first_lethal_recovery_health_ratio", int(set_state.get("piece_count", 0)))), 0.0, 1.0)
		recovery_health_ratio = maxf(recovery_health_ratio, set_recovery_health_ratio)
	if recovery_health_ratio <= 0.0:
		return 0.0
	_first_lethal_recovery_consumed = true
	return recovery_health_ratio


func get_contextual_movement_speed_multiplier(player_position: Vector2, movement_direction: Vector2) -> float:
	## 返回当前朝附近掉落物移动时的综合移速倍率；不同套装分别触发并连乘，未触发固定返回 1。
	if movement_direction.is_zero_approx():
		return 1.0
	# 综合移速倍率；每个已激活套装按 1+比例连乘，避免一个套装覆盖另一个套装效果。
	var combined_multiplier: float = 1.0
	for effect in _get_triggered_nearby_drop_effects(player_position, movement_direction):
		combined_multiplier *= 1.0 + maxf(float(effect.get("move_speed_bonus_ratio", 0.0)), 0.0)
	return maxf(combined_multiplier, 0.0)


func get_contextual_damage_reduction_ratio(player_position: Vector2, movement_direction: Vector2) -> float:
	## 返回当前朝附近掉落物移动时的综合免伤比例；不同套装与其他“受到的伤害降低”来源处于同一乘区并直接加算。
	if movement_direction.is_zero_approx():
		return 0.0
	# 综合免伤比例；这里只聚合同类套装比例，玩家控制器继续与技能、蓄力等来源统一加算和限制。
	var combined_reduction_ratio: float = 0.0
	for effect in _get_triggered_nearby_drop_effects(player_position, movement_direction):
		combined_reduction_ratio += clampf(float(effect.get("damage_reduction_ratio", 0.0)), 0.0, 1.0)
	return clampf(combined_reduction_ratio, 0.0, 1.0)


func notify_enemy_killed() -> void:
	## 通知套装组件玩家完成一次击杀；所有达到两件门槛的套装分别读取自身持续时间，最终使用最长值刷新公共计时。
	# 本次刷新持续时间；多个合法套装同时触发时取最长值，避免短效果覆盖长效果。
	var refreshed_duration: float = 0.0
	for raw_set_state in _active_set_states_cache.values():
		# 当前套装状态；资源没有击杀效果接口时保持兼容并跳过。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 当前套装资源；提供门槛和击杀闪避参数查询接口。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set == null or not equipment_set.has_method("get_recent_kill_dodge_effect"):
			continue
		# 击杀效果；空词典表示门槛未达到或套装没有配置该机制。
		var effect: Dictionary = equipment_set.call("get_recent_kill_dodge_effect", int(set_state.get("piece_count", 0))) as Dictionary
		refreshed_duration = maxf(refreshed_duration, float(effect.get("duration", 0.0)))
	if refreshed_duration > 0.0:
		_recent_kill_dodge_remaining = refreshed_duration
		# 仅在确实存在正持续时间时启用计时，重复击杀继续刷新同一个公共倒计时。
		set_process(true)


func get_recent_kill_dodge_chance_bonus() -> float:
	## 返回当前有效两件套提供的击杀后额外闪避率；计时结束、部件损坏或卸下后立即归零。
	if _recent_kill_dodge_remaining <= 0.0:
		return 0.0
	# 综合额外闪避率；不同套装直接加算，最终由玩家闪避上限统一限制。
	var combined_bonus: float = 0.0
	for raw_set_state in _active_set_states_cache.values():
		# 当前套装状态；包含资源与有效部件数量。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 当前套装资源；缺少击杀接口时不参与本次聚合。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set != null and equipment_set.has_method("get_recent_kill_dodge_effect"):
			# 当前击杀效果；只读取已满足门槛资源返回的额外闪避率。
			var effect: Dictionary = equipment_set.call("get_recent_kill_dodge_effect", int(set_state.get("piece_count", 0))) as Dictionary
			combined_bonus += maxf(float(effect.get("dodge_chance_bonus", 0.0)), 0.0)
	return clampf(combined_bonus, 0.0, 1.0)


func get_move_speed_damage_bonus_ratio(move_speed_attribute: float) -> float:
	## 汇总当前四件套按移速提供的增伤比例；不同套装比例直接相加后由攻击入口转换为单一伤害倍率。
	# 综合增伤比例；初始 0，每个有效套装返回值只累计一次。
	var combined_bonus: float = 0.0
	for effect in _get_move_speed_combat_effects(move_speed_attribute):
		combined_bonus += maxf(float(effect.get("damage_bonus_ratio", 0.0)), 0.0)
	return maxf(combined_bonus, 0.0)


func get_move_speed_damage_reduction_ratio(move_speed_attribute: float) -> float:
	## 汇总当前四件套按移速提供的免伤；不同套装与其他“受到的伤害降低”来源处于同一乘区并直接加算。
	# 综合免伤比例；同类效果先加算，最终与其余来源一起由玩家控制器限制到 100%。
	var combined_reduction_ratio: float = 0.0
	for effect in _get_move_speed_combat_effects(move_speed_attribute):
		combined_reduction_ratio += clampf(float(effect.get("damage_reduction_ratio", 0.0)), 0.0, 1.0)
	return clampf(combined_reduction_ratio, 0.0, 1.0)


func _get_move_speed_combat_effects(move_speed_attribute: float) -> Array[Dictionary]:
	## 收集全部已激活套装的移速战斗效果；资源负责门槛和档数公式，组件只聚合结果。
	# 已触发效果列表；每个套装最多追加一项结构化结果。
	var effects: Array[Dictionary] = []
	for raw_set_state in _active_set_states_cache.values():
		# 当前套装状态；包含资源与有效部件数量。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 当前套装资源；缺少移速战斗接口时安全跳过。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set == null or not equipment_set.has_method("get_move_speed_combat_effect"):
			continue
		# 当前移速效果；空词典表示未达到门槛或资源没有配置该机制。
		var effect: Dictionary = equipment_set.call("get_move_speed_combat_effect", int(set_state.get("piece_count", 0)), move_speed_attribute) as Dictionary
		if not effect.is_empty():
			effects.append(effect)
	return effects


func _get_triggered_nearby_drop_effects(player_position: Vector2, movement_direction: Vector2) -> Array[Dictionary]:
	## 收集当前方向确实指向至少一个附近掉落物的四件套效果；掉落物必须仍在 item_drops 组且位于配置半径内。
	# 触发效果结果；每个套装最多追加一次，即使范围内存在多个掉落物也不会重复叠加自身效果。
	var triggered_effects: Array[Dictionary] = []
	if _nearby_drop_effects_cache.is_empty():
		return triggered_effects
	# 当前毫秒时间戳；用于判断节流缓存是否仍处于有效窗口内，窗口过期后强制重新扫描保证效果不会永久失效。
	var current_time_msec: int = Time.get_ticks_msec()
	if _triggered_drop_effects_cache_timestamp_msec >= 0 and current_time_msec - _triggered_drop_effects_cache_timestamp_msec < NEARBY_DROP_EFFECTS_CACHE_WINDOW_MSEC:
		# 命中节流窗口；直接返回最近一次扫描结果，0.12 秒精度对移速与受击倍率足够且不改变数值语义。
		return _triggered_drop_effects_cache
	# 标准移动方向；零向量已由调用方过滤，归一化后只比较朝向点积是否大于零。
	var normalized_movement_direction: Vector2 = movement_direction.normalized()
	# 当前防具套装状态；统一排除损坏部件并按稳定 set_id 聚合。
	# 聚合结果已在装备变化时转换为附近掉落物效果缓存，当前帧只执行必要的空间与朝向判断。
	for effect in _nearby_drop_effects_cache:
		# 当前效果参数；未达到四件门槛时资源返回空词典。
		# 缓存只保留非空效果，因此这里无需再次调用套装资源或重复检查档位门槛。
		# 检测半径平方；平方距离比较避免每个掉落物重复开方。
		var detection_radius_squared: float = maxf(float(effect.get("detection_radius_squared", 0.0)), 0.0)
		for raw_drop in get_tree().get_nodes_in_group("item_drops"):
			# 掉落物节点；必须为有效 Node2D 且尚未排队删除，飞出动画期间不在组内因此不会触发。
			var drop_node: Node2D = raw_drop as Node2D
			if drop_node == null or not is_instance_valid(drop_node) or drop_node.is_queued_for_deletion():
				continue
			# 掉落物偏移；同位置目标没有可定义的移动方向，不触发朝向效果。
			var drop_offset: Vector2 = drop_node.global_position - player_position
			if drop_offset.is_zero_approx() or drop_offset.length_squared() > detection_radius_squared:
				continue
			# 只判断点积正负无需归一化掉落物偏移，避免为每个候选目标执行平方根计算。
			if normalized_movement_direction.dot(drop_offset) > 0.0:
				triggered_effects.append(effect)
				break
	# 写入节流缓存；本次完整扫描结果连同时间戳一起保存，窗口内的移速与受击查询直接复用。
	_triggered_drop_effects_cache = triggered_effects
	_triggered_drop_effects_cache_timestamp_msec = current_time_msec
	return triggered_effects


func _refresh_active_set_cache() -> void:
	## 从当前权威防具快照重建运行时套装缓存；只由初始化与装备变化信号调用，不参与逐帧查询。
	# 当前防具快照；统一排除空槽与损坏装备，保证缓存结果与静态 UI 统计规则一致。
	var armor_equipment: Dictionary = _get_armor_equipment_resources()
	_active_set_states_cache = collect_active_set_states(armor_equipment)
	_nearby_drop_effects_cache.clear()
	# 节流缓存同步失效；装备变化后立即作废最近扫描结果，防止换装或部件损坏后的窗口期内沿用旧触发效果。
	_triggered_drop_effects_cache = []
	_triggered_drop_effects_cache_timestamp_msec = -1
	for raw_set_state in _active_set_states_cache.values():
		# 当前套装状态；提供套装资源与有效件数，异常资源安全跳过。
		# 当前套装状态；包含权威套装资源和有效穿戴件数，异常类型安全跳过。
		var set_state: Dictionary = raw_set_state as Dictionary
		# 套装数据；只有实现通用附近掉落物效果查询接口的资源才参与方向判定。
		# 套装数据；只有实现通用附近掉落物查询接口的资源才需要预计算该类高频效果。
		var equipment_set: Resource = set_state.get("set_data") as Resource
		if equipment_set == null or not equipment_set.has_method("get_nearby_drop_effect"):
			continue
		# 附近掉落物效果；空词典表示当前件数未达到门槛或该套装没有配置该机制。
		var effect: Dictionary = equipment_set.call("get_nearby_drop_effect", int(set_state.get("piece_count", 0))) as Dictionary
		if not effect.is_empty():
			# 检测半径；取值至少为 0，只在缓存重建时读取一次并转换为平方距离供高频查询复用。
			var detection_radius: float = maxf(float(effect.get("detection_radius", 0.0)), 0.0)
			effect["detection_radius_squared"] = detection_radius * detection_radius
			_nearby_drop_effects_cache.append(effect)


func _get_armor_equipment_resources() -> Dictionary:
	## 读取当前四部位装备；优先使用注入组件，隔离测试缺少玩家组件时回退全局库存服务。
	if _equipment_component == null:
		_equipment_component = get_node_or_null(equipment_component_path)
	if _equipment_component != null and _equipment_component.has_method("get_armor_equipment_resources"):
		return _equipment_component.call("get_armor_equipment_resources") as Dictionary
	# 全局库存服务；只读取公开装备快照，不访问内部记录结构。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory != null and global_inventory.has_method("get_armor_equipment_resources"):
		return global_inventory.call("get_armor_equipment_resources") as Dictionary
	return {}


static func _resource_has_property(content_resource: Resource, property_name: String) -> bool:
	## 判断兼容装备资源是否公开指定字段；旧自定义资源缺少套装字段时保持独立装备，不产生无效 get 错误。
	if content_resource == null:
		return false
	# 属性描述遍历项；脚本导出字段与内置属性都通过统一属性列表检查。
	for property_info in content_resource.get_property_list():
		if str((property_info as Dictionary).get("name", "")) == property_name:
			return true
	return false
