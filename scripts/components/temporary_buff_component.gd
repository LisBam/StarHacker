extends Node
class_name TemporaryBuffComponent

## 临时增益组件管理当前角色由消耗品产生的独立限时效果。
## 同一 item_id 再次使用只刷新持续时间，不叠加自身数值；不同道具对同一属性允许相加。

## 战斗属性组件路径；默认指向同级 StatsComponent，用于同步闪避率和能量恢复临时加成。
@export var stats_component_path: NodePath = ^"../StatsComponent"

## 活动效果表；键为道具 item_id，值包含属性名、数值和剩余秒数，默认空字典，离开角色场景后自然清空。
var _active_effects: Dictionary = {}

## 战斗属性组件缓存；默认按 stats_component_path 解析，允许为空，缺失时移速效果仍可由玩家控制器读取。
@onready var _stats_component: Node = get_node_or_null(stats_component_path)


func _ready() -> void:
	## 没有活动效果时关闭逐帧回调；首次成功使用消耗品后再启用，避免空组件长期参与场景树处理。
	set_process(not _active_effects.is_empty())


func _process(delta: float) -> void:
	if _active_effects.is_empty():
		set_process(false)
		return
	# 是否有任一效果到期；只有到期时才重新汇总属性，普通倒计时帧不重复派发属性变化信号。
	var effects_changed: bool = false
	for effect_id in _active_effects.keys():
		# 当前效果；复制字典后写回剩余时间，避免 Variant 临时值修改不进入主表。
		var effect: Dictionary = (_active_effects.get(effect_id, {}) as Dictionary).duplicate()
		# 新剩余时间；最低为 0，归零时本帧移除并刷新属性。
		var remaining_seconds: float = maxf(float(effect.get("remaining_seconds", 0.0)) - maxf(delta, 0.0), 0.0)
		if remaining_seconds <= 0.0:
			_active_effects.erase(effect_id)
			effects_changed = true
		else:
			effect["remaining_seconds"] = remaining_seconds
			_active_effects[effect_id] = effect
	if effects_changed:
		_refresh_stats_component()
	if _active_effects.is_empty():
		# 全部效果已经到期；下一次成功应用消耗品会重新启用处理。
		set_process(false)


func apply_consumable(consumable_data: Resource) -> bool:
	## 应用或刷新一件消耗品；配置无效时返回 false，调用方只有在 true 时才从库存扣除数量。
	if consumable_data == null or str(consumable_data.get("item_kind")) != "consumable":
		return false
	# 效果标识；使用稳定 item_id 隔离不同饮料，同一 ID 重复使用覆盖旧剩余时间。
	var effect_id: String = str(consumable_data.get("item_id")).strip_edges()
	# 效果属性；只接受组件明确支持的三类属性，未知值不会消费道具。
	var effect_stat: String = str(consumable_data.get("effect_stat"))
	# 效果数值；必须大于 0，零效果道具不会进入活动表。
	var effect_amount: float = maxf(float(consumable_data.get("effect_amount")), 0.0)
	# 持续时间；必须大于 0 秒，防止使用后同帧消失仍消费库存。
	var duration_seconds: float = maxf(float(consumable_data.get("duration_seconds")), 0.0)
	if effect_id.is_empty() or effect_stat not in ["move_speed_ratio", "attack_speed_ratio", "dodge_chance", "energy_regeneration"] or effect_amount <= 0.0 or duration_seconds <= 0.0:
		return false
	_active_effects[effect_id] = {"stat": effect_stat, "amount": effect_amount, "remaining_seconds": duration_seconds}
	_refresh_stats_component()
	# 只有成功进入活动效果表后才启用倒计时，非法消耗品不会产生空闲回调。
	set_process(true)
	return true


func get_move_speed_multiplier() -> float:
	## 返回全部活动移速比例的加算结果；例如单个 10% 饮料返回 1.1，不修改角色基础移速属性。
	var bonus_ratio: float = 0.0
	for raw_effect in _active_effects.values():
		# 当前活动效果；只有 move_speed_ratio 进入移速汇总，其他属性由战斗属性组件处理。
		var effect: Dictionary = raw_effect as Dictionary
		if str(effect.get("stat", "")) == "move_speed_ratio":
			bonus_ratio += maxf(float(effect.get("amount", 0.0)), 0.0)
	return maxf(1.0 + bonus_ratio, 0.0)


func get_attack_speed_multiplier() -> float:
	## 返回全部活动攻速比例的加算结果；效果只用于玩家当前手持武器冷却，不写入角色属性面板或武器资源。
	# 综合攻速提升比例；不同 item_id 加算，同一 ID 在活动表中始终只有一项。
	var bonus_ratio: float = 0.0
	for raw_effect in _active_effects.values():
		# 当前活动效果；只有 attack_speed_ratio 参与攻速汇总，移速与战斗属性继续走各自独立入口。
		var effect: Dictionary = raw_effect as Dictionary
		if str(effect.get("stat", "")) == "attack_speed_ratio":
			bonus_ratio += maxf(float(effect.get("amount", 0.0)), 0.0)
	return maxf(1.0 + bonus_ratio, 0.01)


func _refresh_stats_component() -> void:
	## 汇总闪避与能量恢复并整体覆盖临时来源；不修改装备、角色基础值或技能倍率。
	if _stats_component == null or not _stats_component.has_method("set_temporary_buff_attributes"):
		return
	# 临时闪避率；不同 item_id 直接相加，最终上限由 CombatStatsComponent 统一限制。
	var dodge_chance: float = 0.0
	# 临时每秒能量恢复；不同 item_id 直接相加，允许以后扩展更多恢复类消耗品。
	var energy_regeneration: float = 0.0
	for raw_effect in _active_effects.values():
		# 当前活动效果；按稳定属性名分别累加，未知值在应用阶段已经被拒绝。
		var effect: Dictionary = raw_effect as Dictionary
		if str(effect.get("stat", "")) == "dodge_chance":
			dodge_chance += maxf(float(effect.get("amount", 0.0)), 0.0)
		elif str(effect.get("stat", "")) == "energy_regeneration":
			energy_regeneration += maxf(float(effect.get("amount", 0.0)), 0.0)
	_stats_component.call("set_temporary_buff_attributes", dodge_chance, energy_regeneration)
