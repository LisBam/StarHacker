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
## 共用蓄力条所有者 ID；固定 active_skill，保证武器延迟取消不会隐藏当前技能蓄力显示。
const CHARGE_BAR_OWNER_ID: StringName = &"active_skill"
## 技能链临时节点键；行为把跨阶段世界表现写入该数组，组件在技能链结束或重配时统一释放。
const CHAIN_TRANSIENT_NODES_KEY: String = "transient_nodes"

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
## 目标选择刷新间隔；默认 0.05 秒批量刷新瞄准合法目标，与战斗 HUD 冷却刷新节奏一致。
## 设为 0 可恢复瞄准期间每帧全量遍历，仅建议在目标数量极少的调试场景使用。
@export_range(0.0, 1.0, 0.01) var targeting_refresh_interval: float = 0.05

## 当前技能资源槽；元素为 Resource 或 null，默认空数组，角色档案应用后按三个输入槽截取并填充。
var _skill_resources: Array = []
## 每个技能槽的原始技能资源；多段技能临时替换显示与行为时保持根资源不变，用于最终冷却和超时恢复。
var _root_skill_resources: Array = []
## 当前技能行为节点槽；元素为 Node 或 null，与 _skill_resources 保持同下标，角色切换时会完整销毁并重建。
var _behavior_instances: Array = []
## 当前技能冷却剩余时间；元素为大于等于 0 的秒数，与技能槽保持同下标。
var _cooldown_remaining: Array[float] = []
## 每个技能槽当前有效冷却总时长；元素已包含腿部冷却缩减，供 HUD 按实际冷却比例绘制遮罩。
var _cooldown_durations: Array[float] = []
## 每个技能槽未应用装备缩减前的冷却总时长；元素已包含技能专属的延长或缩短倍率，装备变化时用它重算当前进度。
var _cooldown_base_durations: Array[float] = []
## 每个技能槽等待下一段的剩余时间；取值大于等于 0，零表示当前没有已开启的多段释放窗口。
var _follow_up_remaining: Array[float] = []
## 每个技能槽整套多段技能共享的运行时状态；行为可通过释放上下文保存记录位置、生命等阶段间数据。
var _chain_states: Array[Dictionary] = []
## 每个技能槽本次完成时使用的根技能冷却倍率；默认 1，特殊结算可在最终段前设置并在进入冷却后自动复位。
var _completion_cooldown_multipliers: Array[float] = []
## 每个技能槽的冷却暂停来源表；键为稳定来源 ID、值为 true，任一来源存在时该槽剩余冷却保持不变。
var _cooldown_pause_sources: Array[Dictionary] = []
## 当前装备提供的主动技能冷却缩减；使用 0 到 1 小数，默认 0，不影响武器冷却或后续段释放窗口。
## 当前上限补充：公开设置入口会把该缓存限制为 0 至 0.40，超过部分不进入主动技能冷却公式。
var _equipment_cooldown_reduction: float = 0.0
## 是否由训练场设置禁用主动技能冷却；默认 false，开启时所有技能立即可用且后续释放不会写入冷却，不会保存到角色或装备数据。
var _cooldown_disabled: bool = false
## 骇入模式冷却倍率；默认 1.0 不修改冷却，超频骇入入场时由 GameWorld 写入 0.2，训练场无冷却开关优先级更高。
var _mode_cooldown_scale: float = 1.0
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
	set_process_input(true)
	if _input_component != null and _input_component.has_signal("combat_input_enabled_changed"):
		_input_component.connect("combat_input_enabled_changed", Callable(self, "_on_combat_input_enabled_changed"))


func _exit_tree() -> void:
	## 组件离树前释放挂在战斗场景中的技能链临时表现，避免玩家卸载后留下返回点或持续特效。
	_clear_all_chain_transient_nodes()


func _process(delta: float) -> void:
	_update_cooldowns(delta)
	_update_follow_up_windows(delta)
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
			_charge_bar.call("set_charge_ratio", _charge_elapsed / maximum_charge_duration, CHARGE_BAR_OWNER_ID)
	_targeting_refresh_remaining = maxf(_targeting_refresh_remaining - maxf(delta, 0.0), 0.0)
	if _targeting_refresh_remaining <= 0.0:
		_targeting_refresh_remaining = maxf(targeting_refresh_interval, 0.0)
		_update_targeting(skill_data)


func _input(event: InputEvent) -> void:
	## 在 GUI 与未处理输入阶段之前接收主动技能动作；战斗输入开关仍负责菜单隔离，确保极短按下与松开都不会因同帧事件被其他控件消费而丢失。
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
	_clear_all_chain_transient_nodes()
	_skill_resources.clear()
	_root_skill_resources.clear()
	_behavior_instances.clear()
	_cooldown_remaining.clear()
	_cooldown_durations.clear()
	_cooldown_base_durations.clear()
	_follow_up_remaining.clear()
	_chain_states.clear()
	_completion_cooldown_multipliers.clear()
	_cooldown_pause_sources.clear()
	for raw_skill_resource in skill_resources:
		if _skill_resources.size() >= skill_actions.size():
			break
		# 当前主动技能资源；必须提供有效配置检查或至少具备稳定 ID 与行为脚本。
		var skill_data: Resource = raw_skill_resource as Resource
		if not _is_valid_skill_resource(skill_data):
			continue
		_skill_resources.append(skill_data)
		_root_skill_resources.append(skill_data)
		# 技能行为节点；每个槽独立创建，避免同资源多次装备时共享运行时命中状态。
		var behavior_instance: Node = _create_behavior_instance(skill_data)
		_behavior_instances.append(behavior_instance)
		_cooldown_remaining.append(0.0)
		_cooldown_durations.append(0.0)
		_cooldown_base_durations.append(0.0)
		_follow_up_remaining.append(0.0)
		_chain_states.append({})
		_completion_cooldown_multipliers.append(1.0)
		_cooldown_pause_sources.append({})
	while _skill_resources.size() < skill_actions.size():
		_skill_resources.append(null)
		_root_skill_resources.append(null)
		_behavior_instances.append(null)
		_cooldown_remaining.append(0.0)
		_cooldown_durations.append(0.0)
		_cooldown_base_durations.append(0.0)
		_follow_up_remaining.append(0.0)
		_chain_states.append({})
		_completion_cooldown_multipliers.append(1.0)
		_cooldown_pause_sources.append({})
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


func is_skill_activation_condition_met(slot_index: int) -> bool:
	## 返回指定技能的专属发动条件是否满足；普通技能默认可发动，行为可通过 can_activate() 声明局内解锁条件。
	var skill_data: Resource = get_skill_resource(slot_index)
	if skill_data == null or slot_index < 0 or slot_index >= _behavior_instances.size():
		return false
	# 当前技能行为；缺失行为不具备可执行入口，应与空槽一样显示为不可发动。
	var behavior_instance: Node = _behavior_instances[slot_index] as Node
	if not is_instance_valid(behavior_instance):
		return false
	if behavior_instance.has_method("can_activate"):
		return bool(behavior_instance.call("can_activate"))
	return true


func get_cooldown_remaining(slot_index: int) -> float:
	## 返回指定槽剩余冷却秒数；无效下标按 0 处理，不会阻止其他技能释放。
	if slot_index < 0 or slot_index >= _cooldown_remaining.size():
		return 0.0
	return maxf(_cooldown_remaining[slot_index], 0.0)


func is_cooldown_paused(slot_index: int) -> bool:
	## 返回指定槽是否处于“技能结束后暂不倒计时”状态；无效下标按未暂停处理，供 HUD 隐藏尚未开始的冷却数字。
	return slot_index >= 0 and slot_index < _cooldown_pause_sources.size() and not _cooldown_pause_sources[slot_index].is_empty()


func get_follow_up_remaining(slot_index: int) -> float:
	## 返回指定槽下一段技能的剩余释放窗口；无效下标或普通技能返回 0，HUD 可用它区别阶段等待与冷却。
	if slot_index < 0 or slot_index >= _follow_up_remaining.size():
		return 0.0
	return maxf(_follow_up_remaining[slot_index], 0.0)


func is_follow_up_pending(slot_index: int) -> bool:
	## 返回指定槽是否已经释放前一段并正在等待后续段；该状态不属于冷却，技能按键仍可继续释放当前段。
	return get_follow_up_remaining(slot_index) > 0.0


func get_cooldown_ratio(slot_index: int) -> float:
	## 返回指定槽 0 至 1 的冷却比例；1 表示刚释放，0 表示可用或空槽。
	if slot_index < 0 or slot_index >= _cooldown_durations.size():
		return 0.0
	# 当前有效冷却总时长；已包含冷却缩减与本次技能专属倍率，小于等于 0 的技能始终返回 0。
	var cooldown_duration: float = maxf(_cooldown_durations[slot_index], 0.0)
	return clampf(get_cooldown_remaining(slot_index) / cooldown_duration, 0.0, 1.0) if cooldown_duration > 0.0 else 0.0


func is_aiming() -> bool:
	## 返回当前是否处于任意主动技能按住瞄准或蓄力状态。
	return _active_slot_index >= 0


func get_active_slot_index() -> int:
	## 返回当前瞄准技能槽；-1 表示没有活动技能，供 HUD 或测试读取但不得直接改写。
	return _active_slot_index


func cancel_aiming() -> bool:
	## 取消当前主动技能瞄准或蓄力且不释放效果、不消耗能量、不进入冷却；冲刺等已成功动作可通过该接口打断技能。
	if _active_slot_index < 0:
		return false
	_cancel_active_skill(false)
	return true


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
	# 技能最大范围平方；与平方距离比较等价于原判断，全量目标遍历时每个候选省去一次开方。
	var cast_range_squared: float = cast_range * cast_range
	for raw_target in get_tree().get_nodes_in_group(target_group):
		# 候选目标；只有有效 Node2D 且不是施法者自身才进入其余合法性检查。
		var target: Node2D = raw_target as Node2D
		if target == null or target == caster or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		# 先做纯距离剔除；范围外目标不再执行伤害接口与死亡状态等较贵的校验。
		if caster.global_position.distance_squared_to(target.global_position) > cast_range_squared:
			continue
		if bool(skill_data.get("target_requires_damage_method")) and not target.has_method("apply_damage"):
			continue
		if _is_target_dead(target):
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
	if skill_data == null or get_cooldown_remaining(slot_index) > 0.0 or not is_skill_activation_condition_met(slot_index):
		return
	if slot_index >= _behavior_instances.size() or _behavior_instances[slot_index] == null:
		return
	# 技能能量消耗；按下阶段只预检，实际扣除必须等行为成功执行后发生。
	var energy_cost: int = maxi(int(skill_data.get("energy_cost")), 0)
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
		_charge_bar.call("show_charge", CHARGE_BAR_OWNER_ID)
	# 施法者移动倍率；可蓄力技能可在资源中声明按住期间减速，来源 ID 保证结束时只移除自身效果。
	var caster: Node = get_parent()
	if bool(skill_data.get("can_charge")) and caster != null and caster.has_method("set_movement_speed_multiplier_source"):
		caster.call("set_movement_speed_multiplier_source", "active_skill_charge:%s" % str(skill_data.get("skill_id")), clampf(float(skill_data.get("charge_movement_speed_multiplier")), 0.0, 1.0))
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
	var energy_cost: int = maxi(int(skill_data.get("energy_cost")), 0)
	if _stats_component != null and _stats_component.has_method("can_spend_energy") and not bool(_stats_component.call("can_spend_energy", energy_cost)):
		_cancel_active_skill(false)
		return
	# 最大蓄力时间；不可蓄力技能仍用 1 秒作为安全分母并固定返回 0 比例。
	var maximum_charge_duration: float = maxf(float(skill_data.get("maximum_charge_duration")), MINIMUM_CHARGE_DURATION)
	# 本次蓄力比例；不可蓄力技能固定为 0，可蓄力技能限制到 0 至 1。
	var charge_ratio: float = clampf(_charge_elapsed / maximum_charge_duration, 0.0, 1.0) if bool(skill_data.get("can_charge")) else 0.0
	# 最低蓄力释放语义；按下与松开之间尚未经过处理帧时，0 秒与 0% 仍是合法上下文，行为必须按基础效果执行而不是视为取消。
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
		"chain_state": _chain_states[slot_index] if slot_index < _chain_states.size() else {},
	}
	# 对应行为节点；配置时已验证存在，运行时失效按释放失败处理。
	var behavior_instance: Node = _behavior_instances[slot_index] as Node if slot_index < _behavior_instances.size() else null
	# 行为执行结果；只有明确返回 true 才扣除能量、进入冷却并派发释放信号。
	var released_successfully: bool = behavior_instance != null and behavior_instance.has_method("execute") and bool(behavior_instance.call("execute", context))
	if released_successfully:
		# 技能能量消耗；行为同步成功后只结算一次，属性组件缺失时保持无消耗的隔离测试行为。
		if _stats_component != null and _stats_component.has_method("spend_energy"):
			_stats_component.call("spend_energy", energy_cost)
		skill_released.emit(slot_index, skill_data, context)
	_cancel_active_skill(released_successfully)
	if released_successfully:
		_handle_successful_stage(slot_index, skill_data)


func _cancel_active_skill(released: bool) -> void:
	if _active_slot_index < 0:
		return
	# 被结束的技能槽；先缓存再复位，信号订阅者收到时组件已经不再处于瞄准状态。
	var slot_index: int = _active_slot_index
	# 被结束的技能资源；角色切换清空槽位前仍可用于结束信号说明来源。
	var skill_data: Resource = get_skill_resource(slot_index)
	# 施法者节点；活动技能结束时先移除按住期间移动倍率，成功释放后的行为可独立添加持续效果。
	var caster: Node = get_parent()
	if skill_data != null and caster != null and caster.has_method("remove_movement_speed_multiplier_source"):
		caster.call("remove_movement_speed_multiplier_source", "active_skill_charge:%s" % str(skill_data.get("skill_id")))
	_active_slot_index = -1
	_charge_elapsed = 0.0
	_locked_target = null
	_targeting_refresh_remaining = 0.0
	if _targeting_visual != null and _targeting_visual.has_method("hide_targeting"):
		_targeting_visual.call("hide_targeting")
	if _charge_bar != null and _charge_bar.has_method("hide_charge"):
		_charge_bar.call("hide_charge", CHARGE_BAR_OWNER_ID)
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
	if _cooldown_disabled:
		# 无冷却模式残留清理；开启开关后任何已经开始的主动技能冷却都在本帧归零。
		for slot_index in range(_cooldown_remaining.size()):
			if _cooldown_remaining[slot_index] > 0.0:
				_cooldown_remaining[slot_index] = 0.0
				changed = true
		if changed:
			cooldowns_changed.emit()
		return
	for slot_index in range(_cooldown_remaining.size()):
		if _cooldown_remaining[slot_index] <= 0.0:
			continue
		if slot_index < _cooldown_pause_sources.size() and not _cooldown_pause_sources[slot_index].is_empty():
			continue
		_cooldown_remaining[slot_index] = maxf(_cooldown_remaining[slot_index] - maxf(delta, 0.0), 0.0)
		changed = true
	if changed:
		cooldowns_changed.emit()


func _update_follow_up_windows(delta: float) -> void:
	## 递减全部多段技能释放窗口；窗口归零时立即恢复根技能并按根技能完整冷却结算。
	# 安全帧增量；负数按 0 处理，避免异常调用延长后续段窗口。
	var resolved_delta: float = maxf(delta, 0.0)
	if resolved_delta <= 0.0:
		return
	for slot_index in range(_follow_up_remaining.size()):
		if _follow_up_remaining[slot_index] <= 0.0:
			continue
		_follow_up_remaining[slot_index] = maxf(_follow_up_remaining[slot_index] - resolved_delta, 0.0)
		if _follow_up_remaining[slot_index] > 0.0:
			continue
		if _active_slot_index == slot_index:
			_cancel_active_skill(false)
		_complete_skill_chain(slot_index)


func _handle_successful_stage(slot_index: int, released_skill_data: Resource) -> void:
	## 根据已成功释放段的 next_stage 决定继续等待或完成整套技能；任何阶段成功前都不会提前写入根技能冷却。
	if slot_index < 0 or slot_index >= _skill_resources.size() or released_skill_data == null:
		return
	# 下一段资源；必须符合普通主动技能配置，否则把当前段视为最终段，避免无效资源永久占用技能槽。
	var next_stage_resource: Resource = released_skill_data.get("next_stage") as Resource
	# 下一段窗口；只有正持续时间才允许技能槽进入等待状态，零窗口按没有下一段处理。
	var follow_up_duration: float = maxf(float(released_skill_data.get("next_stage_window_duration")), 0.0)
	if _is_valid_skill_resource(next_stage_resource) and follow_up_duration > 0.0:
		_replace_slot_skill(slot_index, next_stage_resource)
		_follow_up_remaining[slot_index] = follow_up_duration
		skill_loadout_changed.emit()
		cooldowns_changed.emit()
		return
	_complete_skill_chain(slot_index)


func _complete_skill_chain(slot_index: int) -> void:
	## 恢复指定槽的根技能并开始本套技能唯一一次冷却；阶段状态和一次性冷却倍率在结算后全部清空。
	if slot_index < 0 or slot_index >= _root_skill_resources.size():
		return
	# 根技能资源；普通单段技能与多段技能最终都以它的冷却时长为准。
	var root_skill_data: Resource = _root_skill_resources[slot_index] as Resource
	if get_skill_resource(slot_index) != root_skill_data:
		_replace_slot_skill(slot_index, root_skill_data)
	_follow_up_remaining[slot_index] = 0.0
	_clear_chain_transient_nodes(slot_index)
	_chain_states[slot_index] = {}
	# 本次完成冷却倍率；最低为 0，允许专属技能免除冷却或延长冷却，不会影响后续释放。
	var completion_multiplier: float = maxf(_completion_cooldown_multipliers[slot_index], 0.0)
	_completion_cooldown_multipliers[slot_index] = 1.0
	# 装备缩减前冷却时长；根技能基础 CD 与本次技能专属倍率先相乘，避免二者互相覆盖。
	var base_cooldown_duration: float = maxf(float(root_skill_data.get("cooldown_duration")), 0.0) * completion_multiplier if root_skill_data != null else 0.0
	_cooldown_base_durations[slot_index] = base_cooldown_duration
	# 实际冷却时长；腿部装备冷却缩减只在整套技能完成并进入 CD 时应用，后续段窗口不受影响。
	# 骇入模式倍率补充：超频骇入按模式冷却倍率整体缩短写入值，展示时长与剩余时间同步缩短。
	var resolved_cooldown_duration: float = _get_effective_cooldown_duration(base_cooldown_duration) * maxf(_mode_cooldown_scale, 0.0)
	_cooldown_durations[slot_index] = resolved_cooldown_duration
	# 训练场无冷却开关；仅跳过本次进入冷却，资源冷却与装备缩减结果仍保留给关闭开关后的下一次释放使用。
	_cooldown_remaining[slot_index] = 0.0 if _cooldown_disabled else resolved_cooldown_duration
	skill_loadout_changed.emit()
	cooldowns_changed.emit()


func _replace_slot_skill(slot_index: int, skill_data: Resource) -> void:
	## 替换一个槽当前显示与执行的技能段；根技能数组保持不变，旧行为先 shutdown 再释放以清理独立运行状态。
	if slot_index < 0 or slot_index >= _skill_resources.size():
		return
	# 旧行为实例；阶段切换只销毁当前槽节点，不影响其他技能槽的行为和冷却。
	var previous_behavior: Node = _behavior_instances[slot_index] as Node if slot_index < _behavior_instances.size() else null
	if is_instance_valid(previous_behavior):
		if previous_behavior.has_method("shutdown"):
			previous_behavior.call("shutdown")
		previous_behavior.queue_free()
	_skill_resources[slot_index] = skill_data
	_behavior_instances[slot_index] = _create_behavior_instance(skill_data) if skill_data != null else null


func set_completion_cooldown_multiplier(slot_index: int, multiplier: float) -> void:
	## 设置指定多段技能本次完成时的根冷却倍率；相同槽后写入值覆盖旧值，进入冷却后自动恢复 1 倍。
	if slot_index < 0 or slot_index >= _completion_cooldown_multipliers.size():
		return
	_completion_cooldown_multipliers[slot_index] = maxf(multiplier, 0.0)


func scale_cooldown_remaining(slot_index: int, multiplier: float) -> void:
	## 按倍率缩放指定槽当前剩余冷却；0.9 表示减少剩余冷却的 10%，不会改变资源中的基础冷却。
	if slot_index < 0 or slot_index >= _cooldown_remaining.size():
		return
	_cooldown_remaining[slot_index] = maxf(_cooldown_remaining[slot_index] * maxf(multiplier, 0.0), 0.0)
	cooldowns_changed.emit()


func reduce_cooldown_remaining(slot_index: int, seconds: float) -> void:
	## 按固定秒数减少指定槽当前剩余冷却；不会改变基础冷却时长，最低归零。
	if slot_index < 0 or slot_index >= _cooldown_remaining.size() or seconds <= 0.0:
		return
	_cooldown_remaining[slot_index] = maxf(_cooldown_remaining[slot_index] - seconds, 0.0)
	cooldowns_changed.emit()


func refresh_all_cooldowns() -> void:
	## 立即清空全部主动技能冷却；角色专属刷新效果使用，不改变技能资源、阶段或装备冷却缩减。
	for slot_index in range(_cooldown_remaining.size()):
		_cooldown_remaining[slot_index] = 0.0
	cooldowns_changed.emit()


func set_cooldown_paused_source(slot_index: int, source_id: String, paused: bool) -> void:
	## 设置指定槽的独立冷却暂停来源；所有来源清空后下一帧恢复递减，HUD 在暂停期间保留遮罩但隐藏冷却数字。
	if slot_index < 0 or slot_index >= _cooldown_pause_sources.size():
		return
	# 标准来源 ID；空字符串无法稳定解除，因此直接忽略。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	if paused:
		_cooldown_pause_sources[slot_index][normalized_source_id] = true
	else:
		_cooldown_pause_sources[slot_index].erase(normalized_source_id)
	cooldowns_changed.emit()


func set_equipment_cooldown_reduction(reduction_ratio: float) -> void:
	## 设置腿部装备提供的主动技能冷却缩减；换装或装备损坏时保留当前 CD 百分比并用新的缩减结果重算剩余秒数。
	# 有效缩减比例；范围限制为 0 至 1，默认 0 表示玩家不穿腿部装备时的基础状态。
	# 当前上限补充：最终范围限制为 0 至 40%，超过部分不参与当前和后续主动技能冷却计算。
	var resolved_reduction: float = clampf(reduction_ratio, 0.0, EnhancementRules.COOLDOWN_REDUCTION_MAXIMUM)
	if is_equal_approx(_equipment_cooldown_reduction, resolved_reduction):
		return
	_equipment_cooldown_reduction = resolved_reduction
	# 冷却槽索引；遍历所有技能槽，使换装时已经开始的冷却也按原有进度连续变化。
	for slot_index in range(_cooldown_remaining.size()):
		# 旧有效冷却时长；为 0 时没有可保留的进度，直接写入新的总时长即可。
		var previous_duration: float = maxf(_cooldown_durations[slot_index], 0.0)
		# 当前冷却进度；1 表示刚进入冷却，0 表示已完成，读取前限制防止历史异常数据放大时间。
		var remaining_ratio: float = clampf(_cooldown_remaining[slot_index] / previous_duration, 0.0, 1.0) if previous_duration > 0.0 else 0.0
		# 重新计算后的有效冷却时长；使用已记录的技能专属倍率结果，不重新读取或改写资源模板。
		var updated_duration: float = _get_effective_cooldown_duration(_cooldown_base_durations[slot_index])
		_cooldown_durations[slot_index] = updated_duration
		_cooldown_remaining[slot_index] = updated_duration * remaining_ratio
	cooldowns_changed.emit()


func get_equipment_cooldown_reduction() -> float:
	## 返回当前由装备聚合后的冷却缩减比例；供角色面板、测试或未来效果查询，默认值为 0。
	return clampf(_equipment_cooldown_reduction, 0.0, EnhancementRules.COOLDOWN_REDUCTION_MAXIMUM)


func set_cooldown_disabled(enabled: bool) -> void:
	## 设置训练场主动技能无冷却状态；开启时清除已有冷却，关闭后不追溯已经跳过的冷却且后续释放恢复正常结算。
	if _cooldown_disabled == enabled:
		return
	_cooldown_disabled = enabled
	if _cooldown_disabled:
		# 剩余冷却清理；每个有效槽立即可再次释放，HUD 会在同一信号周期移除冷却遮罩。
		for slot_index in range(_cooldown_remaining.size()):
			_cooldown_remaining[slot_index] = 0.0
	cooldowns_changed.emit()


func is_cooldown_disabled() -> bool:
	## 返回当前是否处于训练场主动技能无冷却状态；仅供训练场界面同步开关，不用于装备冷却缩减计算。
	return _cooldown_disabled


func set_mode_cooldown_scale(cooldown_scale: float) -> void:
	## 写入骇入模式冷却倍率；超频骇入入场时由 GameWorld 传入 0.2，负值按 0 处理，只影响后续进入冷却的写入值。
	_mode_cooldown_scale = maxf(cooldown_scale, 0.0)


func _get_effective_cooldown_duration(base_cooldown_duration: float) -> float:
	## 计算装备缩减后的技能总冷却；100% 冷却缩减允许结果为 0，主动技能组件会把它视为立即可用。
	## 当前上限补充：装备冷却缩减最多为 40%，因此正常结算后的技能冷却至少保留基础冷却与技能专属倍率结果的 60%。
	return maxf(base_cooldown_duration, 0.0) * (1.0 - clampf(_equipment_cooldown_reduction, 0.0, EnhancementRules.COOLDOWN_REDUCTION_MAXIMUM))


func execute_pending_stage_immediately(slot_index: int, context_overrides: Dictionary = {}) -> bool:
	## 不经过输入瞄准立即执行一个正在等待的后续段；供死亡拦截等同步机制复用，能量、阶段推进和最终冷却仍由本组件统一结算。
	if not is_follow_up_pending(slot_index) or slot_index < 0 or slot_index >= _behavior_instances.size():
		return false
	# 当前后续段；已经由阶段切换完成配置，仍复核资源和行为节点以隔离运行时损坏。
	var skill_data: Resource = get_skill_resource(slot_index)
	# 当前后续段行为；必须仍在场景树中并实现 execute 才允许自动触发。
	var behavior_instance: Node = _behavior_instances[slot_index] as Node
	if skill_data == null or not is_instance_valid(behavior_instance) or not behavior_instance.has_method("execute"):
		return false
	# 后续段能耗；自动触发与手动释放遵守相同资源成本，能量不足时不能绕过技能配置。
	var energy_cost: int = maxi(int(skill_data.get("energy_cost")), 0)
	if _stats_component != null and _stats_component.has_method("can_spend_energy") and not bool(_stats_component.call("can_spend_energy", energy_cost)):
		return false
	# 自动释放上下文；默认使用施法者当前位置与最后有效方向，调用方只覆盖死亡来源等必要字段。
	var caster: Node2D = get_parent() as Node2D
	# 自动释放数据；字段与手动释放一致，并额外标记 automatic_release 供专属行为判断来源。
	var context: Dictionary = {
		"caster": caster,
		"stats_component": _stats_component,
		"skill_data": skill_data,
		"slot_index": slot_index,
		"aim_direction": _aim_direction,
		"target_position": caster.global_position if caster != null else Vector2.ZERO,
		"target": null,
		"charge_seconds": 0.0,
		"charge_ratio": 0.0,
		"chain_state": _chain_states[slot_index],
		"automatic_release": true,
	}
	context.merge(context_overrides, true)
	if not bool(behavior_instance.call("execute", context)):
		return false
	if _stats_component != null and _stats_component.has_method("spend_energy"):
		_stats_component.call("spend_energy", energy_cost)
	skill_released.emit(slot_index, skill_data, context)
	_handle_successful_stage(slot_index, skill_data)
	return true


func try_intercept_lethal_damage(incoming_damage: float, source: Node) -> bool:
	## 允许当前等待中的后续段声明致命伤害拦截；组件只负责协议与结算，是否拦截由具体阶段行为决定。
	if incoming_damage <= 0.0:
		return false
	for slot_index in range(_behavior_instances.size()):
		if not is_follow_up_pending(slot_index):
			continue
		# 当前阶段行为；只有显式实现拦截判断的技能才可能消费本次致命伤害。
		var behavior_instance: Node = _behavior_instances[slot_index] as Node
		if not is_instance_valid(behavior_instance) or not behavior_instance.has_method("can_intercept_lethal_damage"):
			continue
		if not bool(behavior_instance.call("can_intercept_lethal_damage", incoming_damage, source)):
			continue
		return execute_pending_stage_immediately(slot_index, {"triggered_by_lethal_damage": true, "incoming_damage": incoming_damage, "damage_source": source})
	return false


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


func _clear_all_chain_transient_nodes() -> void:
	## 清理全部技能槽登记的跨阶段世界节点；数组尚未初始化或重复调用时保持幂等。
	for slot_index in range(_chain_states.size()):
		_clear_chain_transient_nodes(slot_index)


func _clear_chain_transient_nodes(slot_index: int) -> void:
	## 释放指定技能链登记的临时节点；无效节点和已经排队释放的节点会安全跳过。
	if slot_index < 0 or slot_index >= _chain_states.size():
		return
	# 当前技能链状态；只读取通用临时节点数组，不识别具体技能字段。
	var chain_state: Dictionary = _chain_states[slot_index]
	# 临时节点列表；行为可登记任意 Node，组件仅负责生命周期回收。
	var transient_nodes: Array = chain_state.get(CHAIN_TRANSIENT_NODES_KEY, []) as Array
	for raw_transient_node in transient_nodes:
		# 当前临时节点；非 Node 值按 null 跳过，合法节点统一进入安全释放队列。
		var transient_node: Node = raw_transient_node as Node
		if is_instance_valid(transient_node) and not transient_node.is_queued_for_deletion():
			transient_node.queue_free()
	chain_state.erase(CHAIN_TRANSIENT_NODES_KEY)


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
