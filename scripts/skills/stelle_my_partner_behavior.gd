extends Node

## “我的伙伴”行为负责维持单个迷迷实例；首次释放召唤，重复释放治疗并刷新 3 秒攻速提升。
## 迷迷命中银河全垒打标记目标后，通过主动技能组件公开入口减少本技能剩余冷却。

## 重复释放攻速来源 ID；固定值保证刷新和到期只影响本技能效果。
const ATTACK_SPEED_SOURCE_ID: String = "stelle_my_partner_boost"
## 银河全垒打标记元数据键；与银河全垒打行为共享，值为 true 表示目标已被标记。
const GRAND_SLAM_MARK_META: StringName = &"stelle_grand_slam_marked"
## 银河全垒打标记到期时间元数据键；超过该毫秒时间戳后旧标记不再触发冷却缩减。
const GRAND_SLAM_MARK_EXPIRES_META: StringName = &"stelle_grand_slam_mark_expires_msec"

## 当前施法者；默认 null，由主动技能组件注入，作为迷迷的跟随主人和召唤坐标来源。
var _caster: Node2D
## 当前战斗属性组件；本技能不直接读取属性，保留统一行为配置协议。
var _stats_component: Node
## 当前技能资源；默认 null，保存衍生单位、治疗、攻速和冷却缩减参数。
var _skill_data: Resource
## 主动技能组件；默认 null，用于按固定秒数减少所属技能槽冷却。
var _active_skill_component: Node
## 本技能所在槽位；默认 -1，首次成功释放时从上下文记录。
var _slot_index: int = -1
## 当前召唤的迷迷实例；默认 null，死亡或离树后下一次释放会重新召唤。
var _summoned_unit: Node2D


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, active_skill_component: Node) -> void:
	## 注入技能依赖；资源和组件只在当前角色主动技能装载期间持有。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_active_skill_component = active_skill_component


func execute(context: Dictionary) -> bool:
	## 召唤迷迷或强化仍在场的同一实例；配置无效时返回 false，不扣除能量也不进入冷却。
	if not is_instance_valid(_caster) or _skill_data == null:
		return false
	_slot_index = int(context.get("slot_index", _slot_index))
	if is_instance_valid(_summoned_unit) and not (_summoned_unit.has_method("is_dead") and bool(_summoned_unit.call("is_dead"))):
		_restore_and_boost_existing_unit()
		return true
	return _summon_unit()


func _summon_unit() -> bool:
	## 从衍生单位资源实例化友方单位并注入跟随玩家；场景根节点必须是 Node2D。
	# 衍生单位资源；空资源或缺少场景字段时不能生成单位。
	var derived_unit: Resource = _skill_data.get("derived_unit") as Resource
	# 单位预制体；必须能实例化为 Node2D，其他节点类型按配置错误处理。
	var unit_scene: PackedScene = derived_unit.get("unit_scene") as PackedScene if derived_unit != null else null
	if unit_scene == null:
		return false
	# 新单位实例；先加入当前场景再设置全局坐标，保证坐标转换与 AI ready 完整生效。
	var unit_instance: Node2D = unit_scene.instantiate() as Node2D
	# 单位父节点；优先当前战斗场景，隔离测试时回退场景树根节点。
	var unit_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	if unit_instance == null or unit_parent == null:
		return false
	unit_parent.add_child(unit_instance)
	unit_instance.global_position = _caster.global_position + (_skill_data.get("summon_offset") as Vector2)
	if unit_instance.has_method("set_follow_owner"):
		unit_instance.call("set_follow_owner", _caster)
	if unit_instance.has_signal("damage_dealt"):
		unit_instance.connect("damage_dealt", Callable(self, "_on_summoned_unit_damage_dealt"))
	_summoned_unit = unit_instance
	return true


func _restore_and_boost_existing_unit() -> void:
	## 为在场迷迷回复生命并刷新同一攻速来源，不重复创建第二个单位。
	if _summoned_unit.has_method("heal"):
		_summoned_unit.call("heal", maxf(float(_skill_data.get("existing_unit_heal_amount")), 0.0))
	else:
		# 兼容基础单位公开字段；没有 heal 接口时直接夹取生命并派发生命变化信号。
		var restored_health: float = clampf(float(_summoned_unit.get("current_health")) + maxf(float(_skill_data.get("existing_unit_heal_amount")), 0.0), 0.0, float(_summoned_unit.get("max_health")))
		_summoned_unit.set("current_health", restored_health)
		if _summoned_unit.has_signal("health_changed"):
			_summoned_unit.emit_signal("health_changed", restored_health, float(_summoned_unit.get("max_health")))
	if _summoned_unit.has_method("set_attack_speed_bonus_source"):
		_summoned_unit.call("set_attack_speed_bonus_source", ATTACK_SPEED_SOURCE_ID, maxf(float(_skill_data.get("existing_unit_attack_speed_bonus_ratio")), 0.0), maxf(float(_skill_data.get("existing_unit_attack_speed_duration")), 0.01))


func _on_summoned_unit_damage_dealt(target: Node, _damage: float) -> void:
	## 只有命中仍带有银河全垒打标记的目标时，才减少“我的伙伴”当前剩余冷却。
	if not is_instance_valid(target) or not bool(target.get_meta(GRAND_SLAM_MARK_META, false)) or Time.get_ticks_msec() >= int(target.get_meta(GRAND_SLAM_MARK_EXPIRES_META, 0)):
		return
	if _active_skill_component != null and _active_skill_component.has_method("reduce_cooldown_remaining") and _slot_index >= 0:
		_active_skill_component.call("reduce_cooldown_remaining", _slot_index, maxf(float(_skill_data.get("marked_target_cooldown_reduction")), 0.0))


func shutdown() -> void:
	## 角色切换时回收本技能召唤的单位，避免旧角色友方继续留在战斗场景。
	if is_instance_valid(_summoned_unit):
		_summoned_unit.queue_free()
	_summoned_unit = null
