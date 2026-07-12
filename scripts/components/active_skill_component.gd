extends Node
class_name ActiveSkillComponent

## 主动技能组件把三个 InputMap 动作转换为按下瞄准、持续蓄力、锁定目标和松手释放状态。
## 组件支持任意角色资源注入最多三个主动技能；具体效果由每个技能自己的行为节点执行。

## 指向技能类型编号；固定 0，与 ActiveSkillData 数据协议保持一致，不作为运行时参数修改。
const TARGETING_DIRECTIONAL: int = 0
## 锁定目标技能类型编号；固定 1，与 ActiveSkillData 数据协议保持一致。
const TARGETING_TARGET_LOCK: int = 1
## 无索敌技能类型编号；固定 2，与 ActiveSkillData 数据协议保持一致。
const TARGETING_NO_TARGET: int = 2
## 技能范围安全下限；固定 1 像素，防止异常资源生成退化距离判断。
const MINIMUM_CAST_RANGE: float = 1.0
## 蓄力持续时间安全下限；固定 0.01 秒，防止异常资源导致比例除零。
const MINIMUM_CHARGE_DURATION: float = 0.01

signal skill_loadout_changed
signal skill_aiming_started(slot_index: int, skill_data: Resource)
signal skill_aiming_ended(slot_index: int, skill_data: Resource, released: bool)
signal skill_released(slot_index: int, skill_data: Resource, context: Dictionary)
signal cooldowns_changed

## 主动技能槽输入动作；默认依次对应技能一、二、三，数组顺序决定角色资源中前三个主动技能的按键。
@export var skill_actions: Array[StringName] = [&"active_skill_1", &"active_skill_2", &"active_skill_3"]
## 输入组件路径；默认指向同级玩家输入组件，用于在背包、地图、暂停或结算打开时取消并阻止技能输入。
@export var input_component_path: NodePath = ^"../InputComponent"
## 战斗属性组件路径；默认指向同级属性组件，用于验证和扣除主动技能能量消耗。
@export var stats_component_path: NodePath = ^"../StatsComponent"
## 技能瞄准视觉路径；默认指向同级 SkillTargetingVisual，缺失时技能逻辑仍可释放但不显示范围。
@export var targeting_visual_path: NodePath = ^"../SkillTargetingVisual"
## 技能蓄力条路径；默认指向同级 SkillChargeBar，缺失时蓄力数值仍会正常累计但不显示头顶进度。
@export var charge_bar_path: NodePath = ^"../SkillChargeBar"
## 目标选择刷新间隔；默认 0 表示瞄准期间每帧响应鼠标，设为正数可降低超大目标数量下的遍历频率。
@export_range(0.0, 1.0, 0.01) var targeting_refresh_interval: float = 0.0

## 当前技能资源槽；元素为 Resource 或 null，默认空数组，角色档案应用后按三个输入槽截取并填充。
var _skill_resources: Array = []
## 当前技能行为节点槽；元素为 Node 或 null，与 _skill_resources 保持同下标，角色切换时会完整销毁并重建。
var _behavior_instances: Array = []
## 当前技能冷却剩余时间；元素为大于等于 0 的秒数，与技能槽保持同下标。
var _cooldown_remaining: Array[float] = []
## 当前正在瞄准的技能槽；取值 -1 或有效下标，默认 -1 表示没有按住任何主动技能。
var _active_slot_index: int = -1
## 当前技能按住累计蓄力时间；取值大于等于 0 秒，默认 0，只有技能允许蓄力时才参与释放比例。
var _charge_elapsed: float = 0.0
## 当前瞄准方向；默认向右，鼠标离角色过近时沿用该稳定方向以避免零向量释放。
var _aim_direction: Vector2 = Vector2.RIGHT
## 当前限制后的目标世界位置；默认零向量，位置指向技能把鼠标坐标限制在最大释放距离内。
var _aim_position: Vector2 = Vector2.ZERO
## 当前锁定目标；默认 null，锁定技能瞄准期间持续选择技能范围内距离鼠标最近的合法目标。
var _locked_target: Node2D
## 下次允许刷新瞄准的剩余时间；取值大于等于 0，默认 0，配置为逐帧时始终保持 0。
var _targeting_refresh_remaining: float = 0.0

## 玩家输入组件缓存；默认在 ready 时按路径解析，允许为空并按输入启用处理。
@onready var _input_component: Node = get_node_or_null(input_component_path)
## 玩家属性组件缓存；默认在 ready 时按路径解析，允许为空并把技能视为无需属性服务即可释放。
@onready var _stats_component: Node = get_node_or_null(stats_component_path)
## 技能瞄准视觉缓存；默认在 ready 时按路径解析，允许为空以支持无界面的组件测试。
@onready var _targeting_visual: Node = get_node_or_null(targeting_visual_path)
## 技能蓄力条缓存；默认在 ready 时按路径解析，允许为空以支持无界面的组件测试。
@onready var _charge_bar: Node = get_node_or_null(charge_bar_path)


func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)
	if _input_component != null and _input_component.has_signal("combat_input_enabled_changed"):
		_input_component.connect("combat_input_enabled_changed", Callable(self, "_on_combat_input_enabled_changed"))


func _process(delta: float) -> void:
	_update_cooldowns(delta)
	if _active_slot_index < 0:
		return
	if not _is_combat_input_enabled() or _is_caster_dead():
		_cancel_active_skill(false)
		return
	# 当前瞄准技能；角色切换等异常状态使槽位失效时立即取消，不进入释放路径。
	var skill_data: Resource = get_skill_resource(_active_slot_index)
	if skill_data == null:
		_cancel_active_skill(false)
		return
	if bool(skill_data.get("can_charge")):
		# 最大蓄力时间；至少 0.01 秒，避免错误配置导致除零。
		var maximum_charge_duration: float = maxf(float(skill_data.get("maximum_charge_duration")), MINIMUM_CHARGE_DURATION)
		_charge_elapsed = minf(_charge_elapsed + maxf(delta, 0.0), maximum_charge_duration)
		if _charge_bar != null and _charge_bar.has_method("set_charge_ratio"):
			_charge_bar.call("set_charge_ratio", _charge_elapsed / maximum_charge_duration)
	_targeting_refresh_remaining = maxf(_targeting_refresh_remaining - maxf(delta, 0.0), 0.0)
	if _targeting_refresh_remaining <= 0.0:
		_targeting_refresh_remaining = maxf(targeting_refresh_interval, 0.0)
		_update_targeting(skill_data)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_combat_input_enabled() or _is_caster_dead():
		return
	for slot_index in range(skill_actions.size()):
		# 当前技能动作；空动作或 InputMap 缺失动作不会响应，允许场景按需减少可用槽位。
		var action_name: StringName = skill_actions[slot_index]
		if action_name.is_empty() or not InputMap.has_action(action_name):
			continue
		if event.is_action_pressed(action_name, false) and not _is_echo_event(event):
			_try_begin_skill(slot_index)
			return
		if event.is_action_released(action_name, false) and _active_slot_index == slot_index:
			_release_active_skill()
			return


func configure_skills(skill_resources: Array) -> void:
	## 注入当前角色主动技能；保留资源数组顺序，最多使用可配置输入动作数量，其余技能可在未来装备界面选择后再进入槽位。
	_cancel_active_skill(false)
	_clear_behavior_instances()
	_skill_resources.clear()
	_behavior_instances.clear()
	_cooldown_remaining.clear()
	for raw_skill_resource in skill_resources:
		if _skill_resources.size() >= skill_actions.size():
			break
		# 当前主动技能资源；必须提供有效配置检查或至少具备稳定 ID 与行为脚本。
		var skill_data: Resource = raw_skill_resource as Resource
		if not _is_valid_skill_resource(skill_data):
			continue
		_skill_resources.append(skill_data)
		# 技能行为节点；每个槽独立创建，避免同资源多次装备时共享运行时命中状态。
		var behavior_instance: Node = _create_behavior_instance(skill_data)
		_behavior_instances.append(behavior_instance)
		_cooldown_remaining.append(0.0)
	while _skill_resources.size() < skill_actions.size():
		_skill_resources.append(null)
		_behavior_instances.append(null)
		_cooldown_remaining.append(0.0)
	skill_loadout_changed.emit()
	cooldowns_changed.emit()


func get_skill_resource(slot_index: int) -> Resource:
	## 返回指定技能槽资源；无效下标或空槽返回 null，调用方不得修改返回的模板资源。
	if slot_index < 0 or slot_index >= _skill_resources.size():
		return null
	return _skill_resources[slot_index] as Resource


func get_skill_action_name(slot_index: int) -> StringName:
	## 返回指定技能槽 InputMap 动作；无效下标返回空 StringName，供 HUD 显示当前实际绑定。
	if slot_index < 0 or slot_index >= skill_actions.size():
		return &""
	return skill_actions[slot_index]


func get_slot_count() -> int:
	## 返回可用主动技能输入槽数量；默认等于三个 action，HUD 和测试使用同一来源。
	return skill_actions.size()


func get_cooldown_remaining(slot_index: int) -> float:
	## 返回指定槽剩余冷却秒数；无效下标按 0 处理，不会阻止其他技能释放。
	if slot_index < 0 or slot_index >= _cooldown_remaining.size():
		return 0.0
	return maxf(_cooldown_remaining[slot_index], 0.0)


func get_cooldown_ratio(slot_index: int) -> float:
	## 返回指定槽 0 至 1 的冷却比例；1 表示刚释放，0 表示可用或空槽。
	# 当前技能资源；缺失时没有可计算的冷却总时长。
	var skill_data: Resource = get_skill_resource(slot_index)
	if skill_data == null:
		return 0.0
	# 冷却总时长；小于等于 0 的技能始终返回 0。
	var cooldown_duration: float = maxf(float(skill_data.get("cooldown_duration")), 0.0)
	return clampf(get_cooldown_remaining(slot_index) / cooldown_duration, 0.0, 1.0) if cooldown_duration > 0.0 else 0.0


func is_aiming() -> bool:
	## 返回当前是否处于任意主动技能按住瞄准或蓄力状态。
	return _active_slot_index >= 0


func get_active_slot_index() -> int:
	## 返回当前瞄准技能槽；-1 表示没有活动技能，供 HUD 或测试读取但不得直接改写。
	return _active_slot_index


func get_legal_targets(skill_data: Resource) -> Array[Node2D]:
	## 返回技能范围内全部合法目标；目标组、伤害接口、死亡状态、距离和可选视线均在此统一复核。
	var legal_targets: Array[Node2D] = []
	if skill_data == null or not is_inside_tree():
		return legal_targets
	# 施法者节点；主动技能组件挂在玩家下方，非 Node2D 所有者无法进行世界距离筛选。
	var caster: Node2D = get_parent() as Node2D
	if caster == null:
		return legal_targets
	# 技能目标组；空组不枚举任何目标，避免误把全场节点视为合法对象。
	var target_group: StringName = StringName(str(skill_data.get("target_group")))
	if target_group.is_empty():
		return legal_targets
	# 技能最大范围；至少 1 像素，所有目标按根节点世界位置判断。
	var cast_range: float = maxf(float(skill_data.get("cast_range")), MINIMUM_CAST_RANGE)
	for raw_target in get_tree().get_nodes_in_group(target_group):
		# 候选目标；只有有效 Node2D 且不是施法者自身才进入其余合法性检查。
		var target: Node2D = raw_target as Node2D
		if target == null or target == caster or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if bool(skill_data.get("target_requires_damage_method")) and not target.has_method("apply_damage"):
			continue
		if _is_target_dead(target) or caster.global_position.distance_to(target.global_position) > cast_range:
			continue
		if bool(skill_data.get("target_requires_line_of_sight")) and not _has_line_of_sight(caster, target, int(skill_data.get("line_of_sight_collision_mask"))):
			continue
		legal_targets.append(target)
	return legal_targets


func _try_begin_skill(slot_index: int) -> void:
	if _active_slot_index >= 0:
		return
	# 待启动技能；空槽、冷却中或行为节点缺失时不进入瞄准状态。
	var skill_data: Resource = get_skill_resource(slot_index)
	if skill_data == null or get_cooldown_remaining(slot_index) > 0.0:
		return
	if slot_index >= _behavior_instances.size() or _behavior_instances[slot_index] == null:
		return
	# 技能能量消耗；按下阶段只预检，实际扣除必须等行为成功执行后发生。
	var energy_cost: float = maxf(float(skill_data.get("energy_cost")), 0.0)
	if _stats_component != null and _stats_component.has_method("can_spend_energy") and not bool(_stats_component.call("can_spend_energy", energy_cost)):
		return
	_active_slot_index = slot_index
	_charge_elapsed = 0.0
	_targeting_refresh_remaining = 0.0
	_update_targeting(skill_data)
	if int(skill_data.get("targeting_mode")) != TARGETING_NO_TARGET and _targeting_visual != null and _targeting_visual.has_method("show_targeting"):
		_targeting_visual.call("show_targeting", skill_data)
		_update_targeting_visual()
	if bool(skill_data.get("can_charge")) and _charge_bar != null and _charge_bar.has_method("show_charge"):
		_charge_bar.call("show_charge")
	skill_aiming_started.emit(slot_index, skill_data)


func _release_active_skill() -> void:
	if _active_slot_index < 0:
		return
	# 本次释放槽位；在清理活动状态前缓存，用于访问对应行为、冷却与信号参数。
	var slot_index: int = _active_slot_index
	# 本次释放技能；槽位异常时按取消处理，不写入冷却。
	var skill_data: Resource = get_skill_resource(slot_index)
	if skill_data == null:
		_cancel_active_skill(false)
		return
	_update_targeting(skill_data)
	# 索敌类型；锁定目标技能在松手时没有合法目标则取消且不消耗资源或冷却。
	var targeting_mode: int = int(skill_data.get("targeting_mode"))
	if targeting_mode == TARGETING_TARGET_LOCK and not is_instance_valid(_locked_target):
		_cancel_active_skill(false)
		return
	# 技能能量消耗；按下后的蓄力与瞄准期间其他动作可能消耗能量，松手时必须再次复核才能执行行为。
	var energy_cost: float = maxf(float(skill_data.get("energy_cost")), 0.0)
	if _stats_component != null and _stats_component.has_method("can_spend_energy") and not bool(_stats_component.call("can_spend_energy", energy_cost)):
		_cancel_active_skill(false)
		return
	# 最大蓄力时间；不可蓄力技能仍用 1 秒作为安全分母并固定返回 0 比例。
	var maximum_charge_duration: float = maxf(float(skill_data.get("maximum_charge_duration")), MINIMUM_CHARGE_DURATION)
	# 本次蓄力比例；不可蓄力技能固定为 0，可蓄力技能限制到 0 至 1。
	var charge_ratio: float = clampf(_charge_elapsed / maximum_charge_duration, 0.0, 1.0) if bool(skill_data.get("can_charge")) else 0.0
	# 施法上下文；具体行为只读取公开字段，不能修改组件内部活动状态。
	var context: Dictionary = {
		"caster": get_parent() as Node2D,
		"stats_component": _stats_component,
		"skill_data": skill_data,
		"slot_index": slot_index,
		"aim_direction": _aim_direction,
		"target_position": _aim_position,
		"target": _locked_target,
		"charge_seconds": _charge_elapsed,
		"charge_ratio": charge_ratio,
	}
	# 对应行为节点；配置时已验证存在，运行时失效按释放失败处理。
	var behavior_instance: Node = _behavior_instances[slot_index] as Node if slot_index < _behavior_instances.size() else null
	# 行为执行结果；只有明确返回 true 才扣除能量、进入冷却并派发释放信号。
	var released_successfully: bool = behavior_instance != null and behavior_instance.has_method("execute") and bool(behavior_instance.call("execute", context))
	if released_successfully:
		# 技能能量消耗；行为同步成功后只结算一次，属性组件缺失时保持无消耗的隔离测试行为。
		if _stats_component != null and _stats_component.has_method("spend_energy"):
			_stats_component.call("spend_energy", energy_cost)
		_cooldown_remaining[slot_index] = maxf(float(skill_data.get("cooldown_duration")), 0.0)
		cooldowns_changed.emit()
		skill_released.emit(slot_index, skill_data, context)
	_cancel_active_skill(released_successfully)


func _cancel_active_skill(released: bool) -> void:
	if _active_slot_index < 0:
		return
	# 被结束的技能槽；先缓存再复位，信号订阅者收到时组件已经不再处于瞄准状态。
	var slot_index: int = _active_slot_index
	# 被结束的技能资源；角色切换清空槽位前仍可用于结束信号说明来源。
	var skill_data: Resource = get_skill_resource(slot_index)
	_active_slot_index = -1
	_charge_elapsed = 0.0
	_locked_target = null
	_targeting_refresh_remaining = 0.0
	if _targeting_visual != null and _targeting_visual.has_method("hide_targeting"):
		_targeting_visual.call("hide_targeting")
	if _charge_bar != null and _charge_bar.has_method("hide_charge"):
		_charge_bar.call("hide_charge")
	skill_aiming_ended.emit(slot_index, skill_data, released)


func _update_targeting(skill_data: Resource) -> void:
	# 施法者节点；非 Node2D 所有者无法读取鼠标世界坐标，异常时保持已有瞄准结果。
	var caster: Node2D = get_parent() as Node2D
	if caster == null or skill_data == null:
		return
	# 鼠标世界坐标；由玩家所在画布和当前相机共同换算，支持相机缩放与移动。
	var mouse_world_position: Vector2 = caster.get_global_mouse_position()
	# 鼠标相对角色方向；过近时沿用上一有效方向，避免松手产生零向量。
	var mouse_direction: Vector2 = mouse_world_position - caster.global_position
	if not mouse_direction.is_zero_approx():
		_aim_direction = mouse_direction.normalized()
	# 技能最大距离；至少 1 像素，位置指向时用于夹取鼠标目标点。
	var cast_range: float = maxf(float(skill_data.get("cast_range")), MINIMUM_CAST_RANGE)
	_aim_position = caster.global_position + _aim_direction * minf(mouse_direction.length(), cast_range)
	_locked_target = null
	if int(skill_data.get("targeting_mode")) == TARGETING_TARGET_LOCK:
		_locked_target = _select_target_nearest_to_mouse(skill_data, mouse_world_position)
		if is_instance_valid(_locked_target):
			_aim_position = _locked_target.global_position
			# 锁定目标方向；目标与角色不重合时同步作为行为释放方向。
			var locked_direction: Vector2 = _locked_target.global_position - caster.global_position
			if not locked_direction.is_zero_approx():
				_aim_direction = locked_direction.normalized()
	_update_targeting_visual()


func _update_targeting_visual() -> void:
	if _targeting_visual == null or not _targeting_visual.has_method("update_targeting"):
		return
	_targeting_visual.call("update_targeting", _aim_direction, _aim_position, _locked_target)


func _select_target_nearest_to_mouse(skill_data: Resource, mouse_world_position: Vector2) -> Node2D:
	# 当前最佳目标；默认 null，遍历合法目标后保留世界位置距离鼠标最近者。
	var best_target: Node2D
	# 当前最佳鼠标距离平方；默认无穷大，使用平方比较避免为每个候选开方。
	var best_distance_squared: float = INF
	for target in get_legal_targets(skill_data):
		# 候选到鼠标距离平方；严格小于当前最佳值时切换锁定，稳定保留同距时先出现的目标。
		var distance_squared: float = target.global_position.distance_squared_to(mouse_world_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_target = target
	return best_target


func _update_cooldowns(delta: float) -> void:
	# 是否有冷却数值发生变化；仅在至少一项递减时派发统一信号，避免空闲状态产生无意义通知。
	var changed: bool = false
	for slot_index in range(_cooldown_remaining.size()):
		if _cooldown_remaining[slot_index] <= 0.0:
			continue
		_cooldown_remaining[slot_index] = maxf(_cooldown_remaining[slot_index] - maxf(delta, 0.0), 0.0)
		changed = true
	if changed:
		cooldowns_changed.emit()


func _create_behavior_instance(skill_data: Resource) -> Node:
	# 技能行为脚本；有效技能配置已经提供 Script，仍复核实例类型以隔离错误内容资源。
	var behavior_script: Script = skill_data.get("behavior_script") as Script
	if behavior_script == null:
		return null
	# 新技能行为对象；必须继承 Node 才能获得生命周期和场景树访问能力。
	var behavior_instance: Node = behavior_script.new() as Node
	if behavior_instance == null:
		return null
	behavior_instance.name = "ActiveSkillBehavior_%s" % str(skill_data.get("skill_id"))
	add_child(behavior_instance)
	if behavior_instance.has_method("configure"):
		behavior_instance.call("configure", get_parent() as Node2D, _stats_component, skill_data, self)
	return behavior_instance


func _clear_behavior_instances() -> void:
	for raw_behavior_instance in _behavior_instances:
		# 待清理行为节点；角色切换后立即从场景树移除，避免旧技能继续持有信号或计时。
		var behavior_instance: Node = raw_behavior_instance as Node
		if not is_instance_valid(behavior_instance):
			continue
		if behavior_instance.has_method("shutdown"):
			behavior_instance.call("shutdown")
		behavior_instance.queue_free()


func _is_valid_skill_resource(skill_data: Resource) -> bool:
	if skill_data == null:
		return false
	if skill_data.has_method("is_valid_configuration"):
		return bool(skill_data.call("is_valid_configuration"))
	return not str(skill_data.get("skill_id")).strip_edges().is_empty() and skill_data.get("behavior_script") is Script


func _is_combat_input_enabled() -> bool:
	if _input_component == null or not _input_component.has_method("is_combat_input_enabled"):
		return true
	return bool(_input_component.call("is_combat_input_enabled"))


func _on_combat_input_enabled_changed(enabled: bool) -> void:
	## 战斗界面禁用输入时立即取消瞄准与蓄力；重新启用只允许新的按下事件开始技能。
	if not enabled:
		_cancel_active_skill(false)


func _is_caster_dead() -> bool:
	return _stats_component != null and _stats_component.has_method("is_dead") and bool(_stats_component.call("is_dead"))


func _is_echo_event(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).echo


func _is_target_dead(target: Node) -> bool:
	if target.has_method("is_dead"):
		return bool(target.call("is_dead"))
	if "current_health" in target:
		return float(target.get("current_health")) <= 0.0
	return false


func _has_line_of_sight(caster: Node2D, target: Node2D, collision_mask: int) -> bool:
	# 视线查询；只检测技能配置的阻挡层，目标本体无需位于该碰撞掩码中。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(caster.global_position, target.global_position, collision_mask, [caster.get_rid()] if caster is CollisionObject2D else [])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 视线命中；空结果表示角色到目标之间没有指定环境层阻挡。
	var hit_result: Dictionary = caster.get_world_2d().direct_space_state.intersect_ray(query)
	return hit_result.is_empty()
