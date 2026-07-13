extends "res://scripts/enemies/basic_monster.gd"
class_name FriendlyUnit

## 友方单位复用基础怪物的感知、寻路、攻击、承伤和死亡流程，只替换阵营目标与玩家跟随规则。
## 可移动单位会在无战斗目标时跟随玩家，距离过远时传送回玩家附近；不可移动单位只攻击自身范围内的敌人。

signal damage_dealt(target: Node, damage: float)

## 是否允许单位主动移动；默认 true，可移动友方会追敌和跟随玩家，false 时只保留原地索敌与攻击。
@export var movable: bool = true
## 开始跟随玩家的距离；默认 150 像素，距离更近时保持当前位置避免与玩家持续挤压。
@export_range(0.0, 2000.0, 1.0, "or_greater") var follow_start_distance: float = 150.0
## 停止跟随玩家的距离；默认 82 像素，应小于开始距离，形成稳定迟滞区间避免频繁启停。
@export_range(0.0, 2000.0, 1.0, "or_greater") var follow_stop_distance: float = 82.0
## 触发回传的玩家距离；默认 900 像素，可移动友方超过该距离会立即传送到玩家附近。
@export_range(1.0, 12000.0, 1.0, "or_greater") var teleport_distance: float = 900.0
## 回传后与玩家的水平偏移；默认 52 像素，避免友方单位与玩家碰撞体完全重叠。
@export_range(0.0, 500.0, 1.0, "or_greater") var teleport_offset: float = 52.0
## 敌对目标组；默认 skill_targets，与玩家技能和武器认可的敌人集合保持一致。
@export var hostile_target_group: StringName = &"skill_targets"

## 跟随的玩家节点；默认 null，由召唤技能或关卡生成器通过 set_follow_owner 注入。
var _follow_owner: Node2D
## 是否处于跟随移动状态；默认 false，通过开始/停止距离形成迟滞，减少路径反复重建。
var _is_following_owner: bool = false
## 攻速提升来源表；键为稳定来源 ID、值为非负提升比例，多个来源直接加算后缩短基础攻击冷却。
var _attack_speed_bonus_sources: Dictionary = {}
## 限时攻速来源剩余时间；键与攻速来源一致、值为秒数，归零后自动移除对应效果。
var _attack_speed_bonus_durations: Dictionary = {}


func _ready() -> void:
	# 友方不属于玩家技能目标组，避免玩家武器和主动技能误伤；presence_units 仍保留以参与单位计数被动。
	active_skill_target_group = &""
	super._ready()
	# 阵营组最终清理；兼容旧场景预先写入的组与外部生成器误配置，确保友方永远不会被登记为敌人或玩家目标。
	remove_from_group(&"skill_targets")
	remove_from_group(&"player_combat_target")
	add_to_group(&"friendly_units")
	spawn_weight = 0.0


func _physics_process(delta: float) -> void:
	_update_attack_speed_bonus_durations(delta)
	super._physics_process(delta)


func set_follow_owner(owner_node: Node) -> void:
	## 注入或替换友方单位跟随的玩家；非 Node2D 输入会清空跟随目标但不影响当前战斗目标。
	_follow_owner = owner_node as Node2D
	_is_following_owner = false


func set_primary_target(_target_node: Node) -> void:
	## 友方不接受基础怪物的玩家主要目标注入；即使外部生成器误用敌人初始化入口也只会保持无战斗目标。
	set_target(null)


func set_target(target_node: Node) -> void:
	## 只允许 hostile_target_group 中的合法敌人进入感知组件；玩家、其他友方和未知单位会被拒绝。
	if target_node == null:
		super.set_target(null)
		return
	var candidate: Node2D = target_node as Node2D
	if not _is_hostile_target(candidate):
		return
	super.set_target(candidate)


func get_follow_owner() -> Node2D:
	## 返回当前跟随玩家，供召唤技能与调试界面确认归属。
	return _follow_owner


func _update_ai_decision(delta: float) -> void:
	## 优先选择视野内最近敌人并复用基础 AI；无敌人时按可移动配置跟随玩家。
	_try_teleport_to_owner()
	# 最近敌对目标；只从指定组选择存活且在视野范围内的 Node2D。
	var hostile_target: Node2D = _find_nearest_hostile_target()
	if is_instance_valid(hostile_target):
		if _target != hostile_target:
			set_target(hostile_target)
		if movable:
			super._update_ai_decision(delta)
		else:
			_update_stationary_combat(delta)
		return
	if is_instance_valid(_target):
		set_target(null)
	_update_owner_follow(delta)


func _update_stationary_combat(delta: float) -> void:
	## 不可移动友方仍更新感知与攻击冷却，但永远不产生主动位移。
	if _movement_component != null:
		_movement_component.call("update", delta)
	if _perception_component != null:
		_perception_component.call("update", delta)
	_sync_perception_state()
	velocity = Vector2.ZERO
	if _target_is_visible and is_instance_valid(_target) and global_position.distance_to(_target.global_position) <= attack_range:
		_try_attack_target()


func _update_owner_follow(_delta: float) -> void:
	## 无战斗目标时跟随玩家；不可移动、玩家无效或已经进入停止距离时保持静止。
	if not movable or not is_instance_valid(_follow_owner):
		velocity = Vector2.ZERO
		return
	# 当前玩家距离；用于迟滞跟随，避免在阈值附近逐帧切换移动状态。
	var owner_distance: float = global_position.distance_to(_follow_owner.global_position)
	if _is_following_owner and owner_distance <= maxf(follow_stop_distance, 0.0):
		_is_following_owner = false
	elif not _is_following_owner and owner_distance >= maxf(follow_start_distance, follow_stop_distance):
		_is_following_owner = true
	if not _is_following_owner:
		velocity = Vector2.ZERO
		return
	velocity = _get_steered_direction_to(_follow_owner.global_position) * _get_resolved_move_speed()


func _try_teleport_to_owner() -> void:
	## 可移动友方距离玩家过远时回传；不可移动单位不会因玩家离开部署点而移动。
	if not movable or not is_instance_valid(_follow_owner) or global_position.distance_to(_follow_owner.global_position) <= maxf(teleport_distance, 1.0):
		return
	# 回传方向；使用实例 ID 决定左右，多个友方同时回传时不会全部堆在同一侧。
	var offset_direction: float = -1.0 if get_instance_id() % 2 == 0 else 1.0
	global_position = _follow_owner.global_position + Vector2(maxf(teleport_offset, 0.0) * offset_direction, 0.0)
	velocity = Vector2.ZERO
	_clear_navigation_path()


func _find_nearest_hostile_target() -> Node2D:
	## 返回视野范围内最近合法敌人；死亡、离树、友方自身和缺少受伤接口的节点会被忽略。
	# 最近目标；默认 null，遍历后按距离平方保留最近候选。
	var nearest_target: Node2D
	# 最近距离平方；默认使用视野半径平方作为合法上限。
	var nearest_distance_squared: float = maxf(vision_range, 0.0) * maxf(vision_range, 0.0)
	for raw_target in get_tree().get_nodes_in_group(hostile_target_group):
		var candidate: Node2D = raw_target as Node2D
		if candidate == self or not _is_hostile_target(candidate):
			continue
		# 候选距离平方；等距时保留先出现者，保证目标选择稳定。
		var distance_squared: float = global_position.distance_squared_to(candidate.global_position)
		if distance_squared <= nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = candidate
	return nearest_target


func _try_attack_target() -> void:
	## 复用基础攻击结算，并在一次攻击确实开始后派发伤害事件供召唤技能响应标记目标。
	if not _is_hostile_target(_target):
		set_target(null)
		return
	# 攻击前目标；同步缓存避免基础攻击后目标状态变化导致事件对象不一致。
	var attacked_target: Node = _target
	# 攻击前是否可释放；基础方法仍负责最终合法性检查和冷却写入。
	var was_ready: bool = _attack_cooldown_remaining <= 0.0 and is_instance_valid(attacked_target) and attacked_target.has_method("apply_damage")
	super._try_attack_target()
	if was_ready:
		damage_dealt.emit(attacked_target, attack_damage)


func _is_hostile_target(candidate: Node2D) -> bool:
	## 返回候选是否属于敌对目标组且仍可受伤；该检查同时保护索敌、外部目标注入和最终攻击入口。
	if not is_instance_valid(candidate) or candidate == self or not candidate.is_inside_tree():
		return false
	if not candidate.is_in_group(hostile_target_group) or not candidate.has_method("apply_damage"):
		return false
	return not (candidate.has_method("is_dead") and bool(candidate.call("is_dead")))


func _get_resolved_attack_cooldown() -> float:
	## 在基础随机冷却上应用全部友方攻速提升；100% 攻速使攻击冷却减半。
	# 综合攻速提升比例；多个独立来源直接加算，最低为 0。
	var combined_attack_speed_bonus: float = 0.0
	for raw_bonus in _attack_speed_bonus_sources.values():
		combined_attack_speed_bonus += maxf(float(raw_bonus), 0.0)
	return super._get_resolved_attack_cooldown() / maxf(1.0 + combined_attack_speed_bonus, 0.01)


func set_attack_speed_bonus_source(source_id: String, bonus_ratio: float, duration_seconds: float = 0.0) -> void:
	## 设置独立攻速来源；相同 ID 覆盖旧值，正持续时间到期后自动移除，0 表示持续到显式清理。
	# 标准来源 ID；空字符串无法稳定清理，因此直接忽略。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	_attack_speed_bonus_sources[normalized_source_id] = maxf(bonus_ratio, 0.0)
	if duration_seconds > 0.0:
		_attack_speed_bonus_durations[normalized_source_id] = duration_seconds
	else:
		_attack_speed_bonus_durations.erase(normalized_source_id)


func remove_attack_speed_bonus_source(source_id: String) -> void:
	## 移除指定攻速来源及其计时器；不存在时保持幂等。
	var normalized_source_id: String = source_id.strip_edges()
	_attack_speed_bonus_sources.erase(normalized_source_id)
	_attack_speed_bonus_durations.erase(normalized_source_id)


func _update_attack_speed_bonus_durations(delta: float) -> void:
	## 递减全部限时攻速来源，并在归零时精确移除对应来源。
	for raw_source_id in _attack_speed_bonus_durations.keys():
		# 当前来源 ID；键由公开设置入口保证为非空字符串。
		var source_id: String = str(raw_source_id)
		# 更新后剩余时间；最低为 0，归零时不再写回字典。
		var remaining_duration: float = maxf(float(_attack_speed_bonus_durations[source_id]) - maxf(delta, 0.0), 0.0)
		if remaining_duration <= 0.0:
			remove_attack_speed_bonus_source(source_id)
		else:
			_attack_speed_bonus_durations[source_id] = remaining_duration
