extends Node

## 敌人战术组件负责同区域队友发现、情报广播、动态职能分配和二维合围点生成。
## 组件不直接修改感知状态、攻击逻辑或物理速度，只向宿主提供当前战术目的地与驻守请求。

## 敌人战术组名称；默认让所有挂载本组件的敌人通过 SceneTree 分组发现同区域队友。
const ENEMY_TACTICAL_GROUP: StringName = &"enemy_tactical_agents"
## 搜查单位职能；默认优先分配给近战单位，负责逐层排查墙角、死角和最后消失区域。
const TACTICAL_ROLE_SEARCHER: int = 0
## 卡位单位职能；默认远近搭配占据墙体近口、外围岔路和预测逃生路线。
const TACTICAL_ROLE_HOLDER: int = 1
## 迂回单位职能；默认优先或仅由远程单位从墙体外侧绕行并封堵远端路线。
const TACTICAL_ROLE_FLANKER: int = 2

## 同区域小队识别半径；默认 1200 像素，只与该范围内且锁定同一目标的敌人共享情报和分工。
var squad_region_radius: float = 1200.0
## 小队协调刷新间隔；默认 0.25 秒，在实时响应与多 AI 查询开销之间取得平衡。
var coordination_update_interval: float = 0.25
## 多人小队职能轮换间隔；默认 18 秒，仅 4 人及以上时轮换同类单位顺序，兼顾完整搜查与动态换岗。
var role_rotation_interval: float = 18.0
## 近层搜查半径；默认 88 像素，用于近战单位贴墙排查拐角和房间近角。
var search_near_radius: float = 88.0
## 中层搜查半径；默认 176 像素，用于墙体周边第二层扇形排查和近端路口封锁。
var search_middle_radius: float = 176.0
## 远层搜查半径；默认 320 像素，用于远程单位扇形观察和外围岔路卡位。
var search_far_radius: float = 320.0
## 二级封锁半径倍率；默认 1.4，反复卡墙临近阈值时扩大所有外围卡点间距。
var blockade_radius_multiplier: float = 1.4
## 近战搜查半径倍率；默认 0.78，让近战单位更贴近墙体和消失点逐点排查。
var melee_search_radius_multiplier: float = 0.78
## 远程搜查半径倍率；默认 1.25，让远程单位保持安全距离并覆盖更宽的扇形区域。
var ranged_search_radius_multiplier: float = 1.25
## 扇形半角；默认 72 度，以玩家消失前移动方向为中心生成左右分散搜查点。
var search_fan_half_angle_degrees: float = 72.0
## 墙角站位净距；默认 44 像素，把候选点推到实心墙角外侧，避免目的地落入墙体内部。
var wall_corner_clearance: float = 44.0
## 逃跑路线预测时间；默认 1.15 秒，根据最后可见速度把卡位点前推到可能抵达的岔路或出口。
var route_prediction_time: float = 1.15
## 分段封锁间距；默认 164 像素，多名卡位单位会沿预测路线分批占据不同深度的路口。
var lane_segment_spacing: float = 164.0
## 战术点到达距离；默认 42 像素，到点后搜查单位短暂停顿，卡位与迂回单位开始静止驻守。
var tactical_point_arrive_distance: float = 42.0
## 搜查点最短观察时间；默认 0.35 秒，用于制造逐点观察节奏且避免无意义连续折返。
var tactical_point_wait_min: float = 0.35
## 搜查点最长观察时间；默认 0.85 秒，不同单位独立随机等待以避免全队同步移动。
var tactical_point_wait_max: float = 0.85
## 完整搜查前的点位数量；默认 6，依次覆盖近、中、远三层左右扇区后转入墙角伏击。
var search_points_before_ambush: int = 6
## 战术候选尝试次数；默认 8，目的地不可导航时逐步旋转和缩短候选点寻找替代路线。
var tactical_destination_attempts: int = 8
## 战术墙体碰撞掩码；默认只检测第 5 层实心环境墙体，其他地图元素不会参与墙角战术计算。
var obstacle_collision_mask: int = 16
## 实心墙体分组；默认 environment_obstacles，只有属于该组的碰撞体才作为墙角和遮挡物情报。
var solid_wall_group: StringName = &"environment_obstacles"
## 情报最大中继跳数；默认 6，每名收到新消息的敌人只向自己周围继续传递一次，避免无限广播循环。
var intelligence_relay_max_hops: int = 6

## 战术宿主；取值为 CharacterBody2D 或 null，默认由敌人聚合脚本注入，用于位置和队友发现。
var _actor: CharacterBody2D
## 感知组件；取值为 Node 或 null，默认通过只读接口提供警戒状态和本地情报，不形成具体脚本类型依赖。
var _perception_component: Node
## 移动组件；取值为 Node 或 null，默认通过可导航性接口过滤候选战术点。
var _movement_component: Node
## 组件使用的随机源；默认与宿主共享，用于错开搜查等待时间且保持每个敌人的独立节奏。
var _random: RandomNumberGenerator
## 当前共享情报；取值为包含消失点、遮挡点、逃跑方向和记忆热点的字典，默认空字典表示无可用战术依据。
var _intelligence: Dictionary = {}
## 当前是否拥有可用共享情报；默认 false，收到本地或队友情报后变为 true。
var _has_intelligence: bool = false
## 已处理的本地情报版本；默认 -1，版本递增时立即向同区域队友广播且不会回传队友情报形成循环。
var _last_local_intelligence_revision: int = -1
## 小队协调刷新剩余时间；默认 0 表示初始化后立即计算一次在场人数和职能。
var _coordination_update_remaining: float = 0.0
## 当前职能；取值为 TACTICAL_ROLE_* 常量，默认搜查单位以兼容单 AI 行为。
var _current_role: int = TACTICAL_ROLE_SEARCHER
## 当前职能内序号；取值从 0 开始，用于把同职能单位分配到不同扇区、岔路深度和墙体侧面。
var _role_slot_index: int = 0
## 当前同区域有效队友总数；最小值为 1，默认只包含自己。
var _active_squad_size: int = 1
## 当前分工签名；默认空字符串，人数、职能、序号或轮换周期变化时清理旧目的地并重新规划。
var _assignment_signature: String = ""
## 当前战术目的地；取值为世界坐标，仅在 _has_tactical_destination 为 true 时有效。
var _tactical_destination: Vector2 = Vector2.ZERO
## 当前是否已有战术目的地；默认 false，需要时由角色和共享情报生成。
var _has_tactical_destination: bool = false
## 当前战术点观察剩余时间；默认 0，到达搜查点后随机暂停再前往下一层或下一扇区。
var _tactical_wait_remaining: float = 0.0
## 当前是否正在观察搜查点；默认 false，到点后保持至等待计时结束，避免同一位置重复累计搜查次数。
var _is_observing_search_point: bool = false
## 已完成的搜查点数量；默认 0，达到 search_points_before_ambush 后切换为差异化静止伏击。
var _visited_search_point_count: int = 0
## 当前是否处于伏击模式；默认 false，完整搜查一圈后变为 true并保持墙角或远端盲区站位。
var _ambush_mode: bool = false
## 当前卡位或伏击点是否已经到达；默认 false，到达后宿主停止主动移动但继续执行视野检测和攻击。
var _hold_position_reached: bool = false
## 已处理情报消息表；键为消息唯一标识，值为接收时间戳，用于级联传播时阻止消息在小队网络中循环。
var _processed_message_ids: Dictionary = {}


func initialize(actor: CharacterBody2D, perception_component: Node, movement_component: Node, random_source: RandomNumberGenerator) -> void:
	_actor = actor
	_perception_component = perception_component
	_movement_component = movement_component
	_random = random_source
	if is_instance_valid(_actor):
		_actor.add_to_group(ENEMY_TACTICAL_GROUP)


func apply_configuration(settings: Dictionary) -> void:
	squad_region_radius = maxf(float(settings.get("squad_region_radius", squad_region_radius)), 1.0)
	coordination_update_interval = maxf(float(settings.get("coordination_update_interval", coordination_update_interval)), 0.05)
	role_rotation_interval = maxf(float(settings.get("role_rotation_interval", role_rotation_interval)), 0.5)
	search_near_radius = maxf(float(settings.get("search_near_radius", search_near_radius)), 1.0)
	search_middle_radius = maxf(float(settings.get("search_middle_radius", search_middle_radius)), search_near_radius)
	search_far_radius = maxf(float(settings.get("search_far_radius", search_far_radius)), search_middle_radius)
	blockade_radius_multiplier = maxf(float(settings.get("blockade_radius_multiplier", blockade_radius_multiplier)), 1.0)
	melee_search_radius_multiplier = maxf(float(settings.get("melee_search_radius_multiplier", melee_search_radius_multiplier)), 0.1)
	ranged_search_radius_multiplier = maxf(float(settings.get("ranged_search_radius_multiplier", ranged_search_radius_multiplier)), 0.1)
	search_fan_half_angle_degrees = clampf(float(settings.get("search_fan_half_angle_degrees", search_fan_half_angle_degrees)), 1.0, 179.0)
	wall_corner_clearance = maxf(float(settings.get("wall_corner_clearance", wall_corner_clearance)), 0.0)
	route_prediction_time = maxf(float(settings.get("route_prediction_time", route_prediction_time)), 0.0)
	lane_segment_spacing = maxf(float(settings.get("lane_segment_spacing", lane_segment_spacing)), 1.0)
	tactical_point_arrive_distance = maxf(float(settings.get("tactical_point_arrive_distance", tactical_point_arrive_distance)), 1.0)
	tactical_point_wait_min = maxf(float(settings.get("tactical_point_wait_min", tactical_point_wait_min)), 0.0)
	tactical_point_wait_max = maxf(float(settings.get("tactical_point_wait_max", tactical_point_wait_max)), tactical_point_wait_min)
	search_points_before_ambush = maxi(int(settings.get("search_points_before_ambush", search_points_before_ambush)), 1)
	tactical_destination_attempts = maxi(int(settings.get("tactical_destination_attempts", tactical_destination_attempts)), 1)
	obstacle_collision_mask = int(settings.get("obstacle_collision_mask", obstacle_collision_mask))
	solid_wall_group = StringName(str(settings.get("solid_wall_group", solid_wall_group)))
	intelligence_relay_max_hops = maxi(int(settings.get("intelligence_relay_max_hops", intelligence_relay_max_hops)), 0)


func reset_intelligence() -> void:
	_intelligence.clear()
	_has_intelligence = false
	_last_local_intelligence_revision = -1
	_processed_message_ids.clear()
	_reset_tactical_route()


func update(delta: float) -> void:
	if not is_instance_valid(_actor):
		return

	_pull_and_broadcast_local_intelligence()
	_coordination_update_remaining = maxf(_coordination_update_remaining - delta, 0.0)
	if _coordination_update_remaining <= 0.0:
		_refresh_squad_assignment()
		_coordination_update_remaining = coordination_update_interval

	if not _is_tactical_state_active() or not _has_intelligence:
		_hold_position_reached = false
		return

	_tactical_wait_remaining = maxf(_tactical_wait_remaining - delta, 0.0)
	if not _has_tactical_destination:
		_build_next_tactical_destination()
		return

	# 当前战术点距离；取值为宿主到战术目的地的世界距离，用于切换搜查点或进入静止卡位。
	var destination_distance: float = _actor.global_position.distance_to(_tactical_destination)
	if destination_distance > tactical_point_arrive_distance:
		_hold_position_reached = false
		return

	if _current_role != TACTICAL_ROLE_SEARCHER or _ambush_mode:
		_hold_position_reached = true
		return

	if not _is_observing_search_point:
		_is_observing_search_point = true
		_tactical_wait_remaining = _get_next_tactical_wait()
		return
	if _tactical_wait_remaining > 0.0:
		return

	_is_observing_search_point = false
	_visited_search_point_count += 1
	if _visited_search_point_count >= search_points_before_ambush:
		_ambush_mode = true
	_has_tactical_destination = false
	_hold_position_reached = false


func receive_shared_intelligence(report: Dictionary) -> bool:
	if report.is_empty():
		return false

	# 情报消息标识；默认由起点敌人、版本和时间组成，所有中继副本保持相同标识以便全网去重。
	var message_id: String = str(report.get("message_id", _build_message_id(report)))
	if _processed_message_ids.has(message_id):
		return false

	# 新情报时间戳；取值为发送者物理帧时刻，默认用于拒绝比当前情报更旧的队友报告。
	var incoming_timestamp: int = int(report.get("timestamp_msec", 0))
	# 当前情报时间戳；取值为已接收报告时刻，默认 0 表示尚未收到任何带时间的情报。
	var current_timestamp: int = int(_intelligence.get("timestamp_msec", 0))
	if _has_intelligence and incoming_timestamp < current_timestamp:
		return false

	_processed_message_ids[message_id] = Time.get_ticks_msec()
	_prune_processed_messages()
	_intelligence = report.duplicate(true)
	_intelligence["message_id"] = message_id
	_has_intelligence = true
	_reset_tactical_route()
	_coordination_update_remaining = 0.0

	# 剩余中继跳数；取值大于 0 时把消息延迟转发给本单位周围敌人，形成跨区域链式发现。
	var relay_hops_remaining: int = int(report.get("relay_hops_remaining", 0))
	if relay_hops_remaining > 0:
		# 中继报告；保持原始消息标识与情报内容，只减少一次剩余跳数。
		var relay_report: Dictionary = report.duplicate(true)
		relay_report["message_id"] = message_id
		relay_report["relay_hops_remaining"] = relay_hops_remaining - 1
		call_deferred("_broadcast_intelligence", relay_report)
	return true


func get_tactical_destination(fallback_destination: Vector2) -> Vector2:
	if not _is_tactical_state_active() or not _has_intelligence:
		return fallback_destination

	if not _has_tactical_destination:
		_build_next_tactical_destination()
	return _tactical_destination if _has_tactical_destination else fallback_destination


func should_pause_movement() -> bool:
	if not _is_tactical_state_active() or not _has_tactical_destination:
		return false

	if _current_role != TACTICAL_ROLE_SEARCHER or _ambush_mode:
		return _hold_position_reached

	return _is_observing_search_point


func get_current_role() -> int:
	return _current_role


func get_active_squad_size() -> int:
	return _active_squad_size


func _pull_and_broadcast_local_intelligence() -> void:
	if _perception_component == null or not _perception_component.has_method("get_tactical_intelligence"):
		return

	# 感知组件原始情报；取值为 Dictionary 或其他 Variant，默认只处理结构化字典。
	var raw_report: Variant = _perception_component.call("get_tactical_intelligence")
	if not (raw_report is Dictionary):
		return

	# 本地情报报告；取值包含版本、来源、目标和消失线索，空字典表示当前没有新情报。
	var report: Dictionary = raw_report.duplicate(true)
	if report.is_empty():
		return

	# 本地情报版本；取值单调递增，默认避免每个物理帧重复向全队广播同一份报告。
	var report_revision: int = int(report.get("revision", -1))
	if report_revision <= _last_local_intelligence_revision:
		return

	_last_local_intelligence_revision = report_revision
	report["message_id"] = _build_message_id(report)
	report["relay_hops_remaining"] = intelligence_relay_max_hops
	_processed_message_ids[str(report["message_id"])] = Time.get_ticks_msec()
	_prune_processed_messages()
	_intelligence = report.duplicate(true)
	_has_intelligence = true
	_reset_tactical_route()
	_broadcast_intelligence(report)


func _broadcast_intelligence(report: Dictionary) -> void:
	# 同区域战术单位；元素为拥有战术能力接口的敌人节点，默认包含自己并在发送时跳过。
	var squad_agents: Array[Node2D] = _collect_squad_agents()
	# 队友战术单位；取值为当前遍历的有效敌人，用于立即同步玩家消失与墙体情报。
	for squad_agent in squad_agents:
		if squad_agent == _actor or not squad_agent.has_method("receive_squad_intelligence"):
			continue
		squad_agent.call("receive_squad_intelligence", report)


func _refresh_squad_assignment() -> void:
	# 同区域战术单位；元素已按实例编号稳定排序，默认让所有敌人独立计算出一致的小队分工。
	var squad_agents: Array[Node2D] = _collect_squad_agents()
	_active_squad_size = maxi(squad_agents.size(), 1)
	# 小队能力档案；每项包含实例编号、远近程属性与攻击射程，用于按数量和射程双重分工。
	var profiles: Array[Dictionary] = []
	# 小队成员节点；取值为同区域且锁定同一玩家的敌人，默认逐个转换为低耦合能力档案。
	for squad_agent in squad_agents:
		profiles.append(_build_agent_profile(squad_agent))

	profiles.sort_custom(Callable(self, "_compare_profile_instance_id"))
	if profiles.is_empty():
		profiles.append(_build_agent_profile(_actor))

	# 轮换周期；取值随全局运行时间递增，仅多人小队用于轮换同类候选顺序。
	var rotation_epoch: int = 0
	if profiles.size() >= 4:
		rotation_epoch = floori(float(Time.get_ticks_msec()) * 0.001 / role_rotation_interval)

	# 职能映射；键为敌人实例编号，值为 TACTICAL_ROLE_*，由全队一致的档案列表生成。
	var role_by_instance_id: Dictionary = _assign_roles(profiles, rotation_epoch)
	# 宿主实例编号；取值为 Object 唯一编号，用于查找本单位职能。
	var actor_instance_id: int = _actor.get_instance_id()
	# 新职能；默认回退搜查单位，确保单 AI 和异常档案仍执行贴墙排查而不远距离迂回。
	var new_role: int = int(role_by_instance_id.get(actor_instance_id, TACTICAL_ROLE_SEARCHER))
	# 新职能序号；取值为同职能稳定列表中的下标，用于把同类单位分散到不同路线。
	var new_role_slot: int = _find_role_slot(profiles, role_by_instance_id, actor_instance_id, new_role)
	# 新分工签名；人数、职能、序号或轮换周期变化都会生成不同字符串并触发重规划。
	var new_signature: String = "%d:%d:%d:%d" % [profiles.size(), new_role, new_role_slot, rotation_epoch]
	if new_signature == _assignment_signature:
		return

	_current_role = new_role
	_role_slot_index = new_role_slot
	_assignment_signature = new_signature
	_reset_tactical_route()


func _collect_squad_agents() -> Array[Node2D]:
	# 筛选后的同区域单位；元素为 Node2D，默认至少在正常场景树中包含宿主自己。
	var result: Array[Node2D] = []
	if not is_instance_valid(_actor):
		return result

	# 宿主目标编号；取值为当前玩家实例编号，默认 0 表示未配置目标且只匹配同样未配置的单位。
	var actor_target_id: int = _get_agent_target_instance_id(_actor)
	# 场景树战术组成员；取值可能包含即将释放或不完整节点，默认逐项做能力和距离校验。
	var grouped_agents: Array = _actor.get_tree().get_nodes_in_group(ENEMY_TACTICAL_GROUP)
	# 战术组遍历项；取值为 Variant，默认只接收有效 Node2D。
	for grouped_agent in grouped_agents:
		if not (grouped_agent is Node2D):
			continue

		# 候选敌人节点；取值为战术组内 Node2D，用于检查区域和目标一致性。
		var candidate_agent: Node2D = grouped_agent as Node2D
		if not is_instance_valid(candidate_agent) or candidate_agent.is_queued_for_deletion():
			continue
		if _actor.global_position.distance_to(candidate_agent.global_position) > squad_region_radius:
			continue
		if _get_agent_target_instance_id(candidate_agent) != actor_target_id:
			continue
		result.append(candidate_agent)

	return result


func _build_agent_profile(agent: Node2D) -> Dictionary:
	# 是否为远程单位；默认 false，只有宿主显式提供能力接口时才参与远程优先迂回和外围卡位。
	var is_ranged: bool = bool(agent.call("is_ranged_tactical_unit")) if agent.has_method("is_ranged_tactical_unit") else false
	# 有效攻击射程；默认 0，射程越大越优先承担远端迂回或出口外侧卡位。
	var attack_range: float = float(agent.call("get_tactical_attack_range")) if agent.has_method("get_tactical_attack_range") else 0.0
	return {
		"instance_id": agent.get_instance_id(),
		"is_ranged": is_ranged,
		"attack_range": attack_range
	}


func _assign_roles(profiles: Array[Dictionary], rotation_epoch: int) -> Dictionary:
	# 职能分配结果；键为实例编号，值为职能常量，默认在不同人数规则下逐项填充。
	var result: Dictionary = {}
	# 在场人数；取值为有效档案数量，默认至少 1。
	var agent_count: int = profiles.size()
	if agent_count <= 1:
		result[int(profiles[0].get("instance_id", 0))] = TACTICAL_ROLE_SEARCHER
		return result

	if agent_count <= 3:
		# 小队迂回成员编号；优先选择远程且射程最长者，没有远程时选择射程最长者保证仍有一人绕侧路。
		var flanker_id: int = _select_best_flanker_id(profiles, true)
		# 2~3 人档案项；取值为全部有效单位，默认除唯一迂回单位外都承担贴墙搜查。
		for profile in profiles:
			# 档案实例编号；取值为敌人唯一编号，用于写入一致的分工结果。
			var profile_id: int = int(profile.get("instance_id", 0))
			result[profile_id] = TACTICAL_ROLE_FLANKER if profile_id == flanker_id else TACTICAL_ROLE_SEARCHER
		return result

	# 远程档案；元素只包含远程敌人，4 人及以上时迂回职能不会分配给近战单位。
	var ranged_profiles: Array[Dictionary] = []
	# 多人小队档案项；取值为全部有效敌人，用于筛选远程迂回候选。
	for profile in profiles:
		if bool(profile.get("is_ranged", false)):
			ranged_profiles.append(profile)

	ranged_profiles.sort_custom(Callable(self, "_compare_profile_attack_range_descending"))
	_rotate_profile_order(ranged_profiles, rotation_epoch)
	# 期望迂回人数；默认约占全队四分之一，且只有存在远程单位时才实际分配。
	var desired_flanker_count: int = maxi(1, floori(float(agent_count) * 0.25))
	# 实际迂回人数；不会超过远程单位数量，保证 4 人以上的迂回单位全部为远程。
	var flanker_count: int = mini(desired_flanker_count, ranged_profiles.size())
	# 迂回成员编号集合；键为实例编号，值固定 true，用于后续快速排除。
	var flanker_ids: Dictionary = {}
	# 迂回候选索引；取值为 0 到实际迂回人数减一，优先选择射程更远且经过周期轮换的远程单位。
	for flanker_index in range(flanker_count):
		flanker_ids[int(ranged_profiles[flanker_index].get("instance_id", 0))] = true

	# 非迂回档案；元素用于均衡分配搜查和卡位，默认近战优先排列到搜查侧。
	var remaining_profiles: Array[Dictionary] = []
	# 多人小队剩余筛选项；取值为全部档案，跳过已分配的远程迂回单位。
	for profile in profiles:
		# 剩余筛选实例编号；取值为敌人唯一编号，用于查询是否已经承担迂回。
		var remaining_profile_id: int = int(profile.get("instance_id", 0))
		if not flanker_ids.has(remaining_profile_id):
			remaining_profiles.append(profile)

	# 剩余近战档案；默认优先放入搜查序列，并只在近战内部轮换，保证近战优先规则不被周期打乱。
	var melee_remaining_profiles: Array[Dictionary] = []
	# 剩余远程档案；默认排在近战之后，主要承担外围卡位并在远程内部轮换。
	var ranged_remaining_profiles: Array[Dictionary] = []
	# 非迂回档案分类项；取值为剩余敌人能力档案，用于按远近程拆分轮换。
	for remaining_profile in remaining_profiles:
		if bool(remaining_profile.get("is_ranged", false)):
			ranged_remaining_profiles.append(remaining_profile)
		else:
			melee_remaining_profiles.append(remaining_profile)

	melee_remaining_profiles.sort_custom(Callable(self, "_compare_profile_instance_id"))
	ranged_remaining_profiles.sort_custom(Callable(self, "_compare_profile_instance_id"))
	_rotate_profile_order(melee_remaining_profiles, rotation_epoch)
	_rotate_profile_order(ranged_remaining_profiles, rotation_epoch)
	remaining_profiles.clear()
	remaining_profiles.append_array(melee_remaining_profiles)
	remaining_profiles.append_array(ranged_remaining_profiles)
	# 搜查人数；默认占非迂回成员约一半，剩余成员远近搭配承担卡位。
	var searcher_count: int = ceili(float(remaining_profiles.size()) * 0.5)
	# 非迂回档案索引；取值为数组有效下标，前半分配搜查，后半分配卡位。
	for remaining_index in range(remaining_profiles.size()):
		# 非迂回实例编号；取值为当前档案唯一编号，用于写入分工映射。
		var remaining_id: int = int(remaining_profiles[remaining_index].get("instance_id", 0))
		result[remaining_id] = TACTICAL_ROLE_SEARCHER if remaining_index < searcher_count else TACTICAL_ROLE_HOLDER

	# 迂回编号遍历项；取值为字典键，用于最后覆盖为远程迂回职能。
	for flanker_id_variant in flanker_ids.keys():
		result[int(flanker_id_variant)] = TACTICAL_ROLE_FLANKER
	return result


func _select_best_flanker_id(profiles: Array[Dictionary], allow_melee_fallback: bool) -> int:
	# 最佳迂回编号；默认首个档案实例编号，保证异常能力数据下仍有确定结果。
	var best_id: int = int(profiles[0].get("instance_id", 0))
	# 最佳候选是否远程；默认取首项属性，远程优先级高于任何近战射程。
	var best_is_ranged: bool = bool(profiles[0].get("is_ranged", false))
	# 最佳攻击射程；默认取首项射程，同类型候选间优先选择射程更长者。
	var best_attack_range: float = float(profiles[0].get("attack_range", 0.0))
	# 迂回候选档案；取值为全部小队单位，用于按远程属性和射程比较。
	for profile in profiles:
		# 候选是否远程；默认 false，远程候选会直接替换当前近战最佳项。
		var candidate_is_ranged: bool = bool(profile.get("is_ranged", false))
		# 候选攻击射程；默认 0，同为远程或同为近战时射程更长者优先。
		var candidate_attack_range: float = float(profile.get("attack_range", 0.0))
		if candidate_is_ranged and not best_is_ranged:
			best_id = int(profile.get("instance_id", 0))
			best_is_ranged = true
			best_attack_range = candidate_attack_range
		elif candidate_is_ranged == best_is_ranged and candidate_attack_range > best_attack_range:
			best_id = int(profile.get("instance_id", 0))
			best_attack_range = candidate_attack_range

	if not best_is_ranged and not allow_melee_fallback:
		return 0
	return best_id


func _find_role_slot(profiles: Array[Dictionary], role_by_instance_id: Dictionary, actor_instance_id: int, role: int) -> int:
	# 同职能序号；默认 0，每遇到同职能的更早档案递增，保证各单位分配不同扇区。
	var role_slot: int = 0
	# 档案项；取值按实例编号排序，默认提供所有敌人一致的职能内顺序。
	for profile in profiles:
		# 档案编号；取值为敌人唯一实例编号，用于查找职能并识别宿主。
		var profile_id: int = int(profile.get("instance_id", 0))
		if profile_id == actor_instance_id:
			return role_slot
		if int(role_by_instance_id.get(profile_id, TACTICAL_ROLE_SEARCHER)) == role:
			role_slot += 1
	return role_slot


func _build_next_tactical_destination() -> void:
	if not _has_intelligence or not is_instance_valid(_actor):
		return

	# 战术锚点；优先使用玩家消失位置，缺失时回退最后可见坐标和宿主当前位置。
	var anchor_position: Vector2 = _get_intelligence_vector("disappearance_position", _actor.global_position)
	# 玩家逃跑方向；优先使用最后速度方向，缺失时使用宿主指向消失点方向。
	var escape_direction: Vector2 = _get_escape_direction(anchor_position)
	# 二级封锁倍率；取值为 1 或 blockade_radius_multiplier，临近脱战阈值时扩大外圈覆盖。
	var alert_radius_multiplier: float = blockade_radius_multiplier if _get_perception_state() == 3 else 1.0
	# 角色候选点；取值由搜查、卡位或迂回规则生成，之后还会做墙角修正和导航验证。
	var candidate_destination: Vector2 = anchor_position
	if _current_role == TACTICAL_ROLE_SEARCHER:
		candidate_destination = _build_searcher_destination(anchor_position, escape_direction, alert_radius_multiplier)
	elif _current_role == TACTICAL_ROLE_HOLDER:
		candidate_destination = _build_holder_destination(anchor_position, escape_direction, alert_radius_multiplier)
	else:
		candidate_destination = _build_flanker_destination(anchor_position, escape_direction, alert_radius_multiplier)

	_tactical_destination = _resolve_navigable_destination(anchor_position, candidate_destination)
	_has_tactical_destination = true
	_hold_position_reached = false


func _build_searcher_destination(anchor_position: Vector2, escape_direction: Vector2, alert_radius_multiplier: float) -> Vector2:
	if _ambush_mode:
		return _build_ambush_destination(anchor_position, escape_direction, alert_radius_multiplier)

	if _visited_search_point_count == 0:
		# 首轮强制追入点；取值为最后发现位置加受限速度预测，确保玩家快速进门或绕墙时搜查单位先追过入口再展开墙角排查。
		var committed_pursuit_destination: Vector2 = anchor_position + _get_route_prediction(search_middle_radius * alert_radius_multiplier)
		return committed_pursuit_destination

	# 三层索引；取值依次为 0、1、2，对应由近到远的扇形平面搜查。
	var layer_index: int = _visited_search_point_count % 3
	# 基础层半径；取值来自近、中、远三层配置，默认依次扩大搜索覆盖。
	var layer_radius: float = search_near_radius
	if layer_index == 1:
		layer_radius = search_middle_radius
	elif layer_index == 2:
		layer_radius = search_far_radius

	# 单位是否远程；默认通过宿主能力接口判断，影响搜查半径和墙体保持距离。
	var is_ranged: bool = _is_actor_ranged()
	# 射程差异倍率；远程扩大扇形，近战收缩半径贴墙排查。
	var range_multiplier: float = ranged_search_radius_multiplier if is_ranged else melee_search_radius_multiplier
	# 左右扇区序号；取值随搜查次数和职能序号变化，避免所有搜查单位走向同一拐角。
	var fan_step_index: int = _visited_search_point_count / 3 + _role_slot_index
	# 扇区方向符号；取值 -1 或 1，相邻搜查点交替覆盖逃跑方向两侧。
	var fan_side: float = -1.0 if fan_step_index % 2 == 0 else 1.0
	# 扇形角度比例；取值 0.35 到 1，逐轮扩大到墙体侧面、巷道岔路和房间角落。
	var fan_angle_ratio: float = minf(0.35 + float(fan_step_index / 2) * 0.3, 1.0)
	# 搜查角度；取值为扇形半角内的弧度，用于生成左右不同平面方向。
	var search_angle: float = deg_to_rad(search_fan_half_angle_degrees) * fan_side * fan_angle_ratio
	# 预测逃跑偏移；取值由最后可见速度乘预测时间并限制在远层半径内，用于优先抢占近道。
	var route_prediction: Vector2 = _get_route_prediction(search_far_radius * alert_radius_multiplier)
	# 普通扇形候选点；取值为消失点、预测偏移和旋转半径之和。
	var fan_destination: Vector2 = anchor_position + route_prediction + escape_direction.rotated(search_angle) * layer_radius * range_multiplier * alert_radius_multiplier
	if not is_ranged and layer_index == 0:
		return _get_best_wall_corner_destination(fan_destination, anchor_position)
	return fan_destination


func _build_holder_destination(anchor_position: Vector2, escape_direction: Vector2, alert_radius_multiplier: float) -> Vector2:
	# 单位是否远程；远程卡外围岔路，近战堵墙体近口。
	var is_ranged: bool = _is_actor_ranged()
	# 分段深度；取值至少 1，相邻卡位单位沿逃跑路线占据不同路口而不扎堆同一拐角。
	var segment_index: int = _role_slot_index + 1
	# 路线推进距离；远程使用更远分段，近战保持墙体近侧。
	var forward_distance: float = lane_segment_spacing * float(segment_index) * (1.35 if is_ranged else 0.62) * alert_radius_multiplier
	# 侧向符号；取值 -1 或 1，把相邻卡位单位分散到预测路线两侧。
	var side_sign: float = -1.0 if _role_slot_index % 2 == 0 else 1.0
	# 侧向距离；远程覆盖更宽外围岔路，近战只离开主线少量距离堵近口。
	var lateral_distance: float = (search_middle_radius if is_ranged else search_near_radius * 0.55) * side_sign * alert_radius_multiplier
	# 路线法线；取值为逃跑方向旋转 90 度，用于构造双向封锁宽度。
	var route_normal: Vector2 = escape_direction.orthogonal()
	# 卡位候选点；取值沿预测路线分段并带左右偏移，模拟长巷道分批守路口。
	var holder_destination: Vector2 = anchor_position + escape_direction * forward_distance + route_normal * lateral_distance + _get_route_prediction(forward_distance)
	if not is_ranged:
		return _get_best_wall_corner_destination(holder_destination, anchor_position)
	return holder_destination


func _build_flanker_destination(anchor_position: Vector2, escape_direction: Vector2, alert_radius_multiplier: float) -> Vector2:
	# 迂回侧向符号；取值 -1 或 1，不同迂回单位分别绕墙体两侧外圈。
	var side_sign: float = -1.0 if _role_slot_index % 2 == 0 else 1.0
	# 迂回外圈距离；取值随职能序号增加，避免多名远程单位路径完全重叠。
	var flank_radius: float = search_far_radius * (1.0 + float(_role_slot_index) * 0.22) * alert_radius_multiplier
	# 外侧绕行方向；取值为逃跑方向向左右旋转约 72 度，优先从墙体外侧接近出口远端。
	var flank_direction: Vector2 = escape_direction.rotated(deg_to_rad(72.0) * side_sign)
	# 迂回候选点；取值同时包含外侧绕行和逃跑路线前推，用于封堵远端逃生路线。
	return anchor_position + flank_direction * flank_radius + escape_direction * lane_segment_spacing * 1.35 + _get_route_prediction(flank_radius)


func _build_ambush_destination(anchor_position: Vector2, escape_direction: Vector2, alert_radius_multiplier: float) -> Vector2:
	# 单位是否远程；远程伏击开阔盲区，近战伏击墙体近拐角。
	var is_ranged: bool = _is_actor_ranged()
	if not is_ranged:
		# 近战伏击参考点；取值为消失点沿逃跑方向稍微前推，优先选择该侧最近墙角。
		var melee_reference: Vector2 = anchor_position + escape_direction * search_near_radius * alert_radius_multiplier
		return _get_best_wall_corner_destination(melee_reference, anchor_position)

	# 远程偏好距离；取值来自宿主攻击能力，至少使用中层半径以保持安全射程。
	var preferred_distance: float = maxf(_get_actor_preferred_distance(), search_middle_radius) * alert_radius_multiplier
	# 远程伏击侧向符号；取值 -1 或 1，让多名远程单位分别覆盖不同露头线。
	var ranged_side: float = -1.0 if _role_slot_index % 2 == 0 else 1.0
	# 远程伏击法线；取值为逃跑方向垂线，用于离开正面通道并占据开阔盲区。
	var ambush_normal: Vector2 = escape_direction.orthogonal() * ranged_side
	return anchor_position - escape_direction * preferred_distance * 0.55 + ambush_normal * preferred_distance * 0.72


func _resolve_navigable_destination(anchor_position: Vector2, desired_destination: Vector2) -> Vector2:
	if _is_destination_navigable(desired_destination):
		return desired_destination

	# 候选偏移；取值为锚点到期望点的向量，默认用于逐步旋转并缩短不可达战术点。
	var desired_offset: Vector2 = desired_destination - anchor_position
	if desired_offset.is_zero_approx():
		return anchor_position

	# 战术候选索引；取值为 0 到尝试次数减一，左右交替旋转并逐步收缩半径寻找可行点。
	for attempt_index in range(tactical_destination_attempts):
		# 尝试侧向符号；取值 -1 或 1，相邻尝试交替搜索墙体两侧路线。
		var attempt_side: float = -1.0 if attempt_index % 2 == 0 else 1.0
		# 尝试角度；取值每两次增加 18 度，用于避开落在实心墙内或不可达区域的候选。
		var attempt_angle: float = deg_to_rad(18.0 * float(attempt_index / 2 + 1)) * attempt_side
		# 尝试半径倍率；取值最低 0.45，越后续的候选越靠近锚点以提高可达概率。
		var attempt_radius_multiplier: float = maxf(1.0 - float(attempt_index) * 0.08, 0.45)
		# 替代候选点；取值为旋转并收缩后的偏移，交给移动组件验证导航可达性。
		var alternative_destination: Vector2 = anchor_position + desired_offset.rotated(attempt_angle) * attempt_radius_multiplier
		if _is_destination_navigable(alternative_destination):
			return alternative_destination

	return anchor_position


func _get_best_wall_corner_destination(reference_position: Vector2, anchor_position: Vector2) -> Vector2:
	# 最近墙体矩形；取值来自地图障碍服务，空矩形表示无法获取当前遮挡墙体几何信息。
	var wall_rect: Rect2 = _find_nearest_wall_rect(anchor_position)
	if wall_rect.size.x <= 0.0 or wall_rect.size.y <= 0.0:
		return reference_position

	# 墙体中心；取值为障碍矩形中心，用于把四个拐角向实心墙外侧推出安全净距。
	var wall_center: Vector2 = wall_rect.get_center()
	# 原始墙角数组；元素依次覆盖矩形四角，默认用于选择离参考战术方向最近且可导航的拐角。
	var raw_corners: Array[Vector2] = [
		wall_rect.position,
		Vector2(wall_rect.end.x, wall_rect.position.y),
		wall_rect.end,
		Vector2(wall_rect.position.x, wall_rect.end.y)
	]
	# 最佳墙角点；默认回退参考位置，只有找到可导航墙角时才替换。
	var best_destination: Vector2 = reference_position
	# 最佳墙角评分；默认无穷大，距离参考位置越近越优先。
	var best_score: float = INF
	# 原始墙角；取值为矩形四角之一，用于计算外推方向和候选点。
	for raw_corner in raw_corners:
		# 墙角外推方向；取值为墙体中心指向墙角的单位向量，避免候选落在实心碰撞内部。
		var corner_outward_direction: Vector2 = raw_corner - wall_center
		if corner_outward_direction.is_zero_approx():
			continue
		# 墙角候选点；取值为原始角点沿外侧推出 wall_corner_clearance。
		var corner_destination: Vector2 = raw_corner + corner_outward_direction.normalized() * wall_corner_clearance
		if not _is_destination_navigable(corner_destination):
			continue
		# 墙角评分；取值为候选到参考位置距离，并加入职能序号微小偏置以分散同类单位。
		var corner_score: float = corner_destination.distance_to(reference_position) + absf(float(_role_slot_index) * 4.0)
		if corner_score < best_score:
			best_score = corner_score
			best_destination = corner_destination

	return best_destination


func _find_nearest_wall_rect(reference_position: Vector2) -> Rect2:
	# 障碍信息提供者；取值通常为 GameWorld，只要求实现 get_minimap_obstacle_rects 能力接口。
	var obstacle_provider: Node = _resolve_obstacle_provider()
	if obstacle_provider == null or not obstacle_provider.has_method("get_minimap_obstacle_rects"):
		return Rect2()

	# 原始障碍矩形数组；取值来自地图共享缓存，默认只处理 Rect2 元素。
	var raw_rects: Variant = obstacle_provider.call("get_minimap_obstacle_rects")
	if not (raw_rects is Array):
		return Rect2()

	# 最近墙体矩形；默认空矩形，找到第一项有效 Rect2 后初始化。
	var nearest_rect: Rect2 = Rect2()
	# 最近墙体距离；默认无穷大，按参考点到矩形边界的最短距离比较。
	var nearest_distance: float = INF
	# 障碍矩形遍历项；取值为 Variant，默认忽略非 Rect2 数据。
	for raw_rect in raw_rects:
		if not (raw_rect is Rect2):
			continue
		# 当前墙体矩形；取值为地图环境碰撞外包矩形，用于近似墙角和出口边缘。
		var obstacle_rect: Rect2 = raw_rect
		# 矩形最近点；取值为参考点限制到矩形边界范围后的坐标，用于计算点到矩形距离。
		var closest_point: Vector2 = Vector2(
			clampf(reference_position.x, obstacle_rect.position.x, obstacle_rect.end.x),
			clampf(reference_position.y, obstacle_rect.position.y, obstacle_rect.end.y)
		)
		# 当前墙体距离；取值为参考点到矩形最近点距离，越小越可能是本次遮挡墙体。
		var obstacle_distance: float = reference_position.distance_to(closest_point)
		if obstacle_distance < nearest_distance:
			nearest_distance = obstacle_distance
			nearest_rect = obstacle_rect

	return nearest_rect


func _resolve_obstacle_provider() -> Node:
	if not is_instance_valid(_actor):
		return null

	# 当前场景节点；取值通常为 GameWorld，默认优先复用其障碍矩形缓存。
	var current_scene: Node = _actor.get_tree().current_scene
	if current_scene != null and current_scene.has_method("get_minimap_obstacle_rects"):
		return current_scene

	# 父级扫描节点；取值从敌人父节点向上，兼容怪物容器层级变化。
	var parent_node: Node = _actor.get_parent()
	while parent_node != null:
		if parent_node.has_method("get_minimap_obstacle_rects"):
			return parent_node
		parent_node = parent_node.get_parent()
	return null


func _is_destination_navigable(destination: Vector2) -> bool:
	if _movement_component == null or not _movement_component.has_method("is_destination_navigable"):
		return true
	return bool(_movement_component.call("is_destination_navigable", destination))


func _get_escape_direction(anchor_position: Vector2) -> Vector2:
	# 情报逃跑方向；取值为最后可见速度归一化结果，零向量时使用位置关系兜底。
	var escape_direction: Vector2 = _get_intelligence_vector("escape_direction", Vector2.ZERO)
	if not escape_direction.is_zero_approx():
		return escape_direction.normalized()

	# 宿主到消失点方向；取值为当前敌人指向最后线索的单位向量，避免无速度时生成重叠点。
	var anchor_direction: Vector2 = anchor_position - _actor.global_position
	return anchor_direction.normalized() if not anchor_direction.is_zero_approx() else Vector2.RIGHT


func _get_route_prediction(maximum_distance: float) -> Vector2:
	# 最后估算速度；取值为玩家可见阶段世界速度，用于预测逃跑路线而不读取墙后实时位置。
	var estimated_velocity: Vector2 = _get_intelligence_vector("estimated_velocity", Vector2.ZERO)
	# 预测偏移；取值为速度乘预测时间，默认限制在调用方允许的最大距离内。
	var prediction_offset: Vector2 = estimated_velocity * route_prediction_time
	if maximum_distance > 0.0 and prediction_offset.length() > maximum_distance:
		prediction_offset = prediction_offset.normalized() * maximum_distance
	return prediction_offset


func _get_intelligence_vector(key: String, fallback_value: Vector2) -> Vector2:
	# 情报原始值；取值可能为任意 Variant，默认只接收 Vector2 以避免共享数据类型异常。
	var raw_value: Variant = _intelligence.get(key, fallback_value)
	return raw_value if raw_value is Vector2 else fallback_value


func _is_tactical_state_active() -> bool:
	if _perception_component != null and _perception_component.has_method("is_medium_memory_recheck") and bool(_perception_component.call("is_medium_memory_recheck")):
		return false

	# 当前感知状态；取值由感知组件只读接口提供，2 表示一级搜查，3 表示二级全域封锁。
	var perception_state: int = _get_perception_state()
	return perception_state == 2 or perception_state == 3


func _get_perception_state() -> int:
	if _perception_component == null or not _perception_component.has_method("get_ai_state"):
		return 0
	return int(_perception_component.call("get_ai_state"))


func _get_agent_target_instance_id(agent: Node) -> int:
	if agent != null and agent.has_method("get_tactical_target_instance_id"):
		return int(agent.call("get_tactical_target_instance_id"))
	return 0


func _is_actor_ranged() -> bool:
	return is_instance_valid(_actor) and _actor.has_method("is_ranged_tactical_unit") and bool(_actor.call("is_ranged_tactical_unit"))


func _get_actor_preferred_distance() -> float:
	if is_instance_valid(_actor) and _actor.has_method("get_tactical_preferred_distance"):
		return maxf(float(_actor.call("get_tactical_preferred_distance")), 1.0)
	return search_middle_radius


func _get_next_tactical_wait() -> float:
	return _random.randf_range(tactical_point_wait_min, tactical_point_wait_max) if _random != null else randf_range(tactical_point_wait_min, tactical_point_wait_max)


func _build_message_id(report: Dictionary) -> String:
	return "%d:%d:%d" % [
		int(report.get("source_instance_id", 0)),
		int(report.get("revision", 0)),
		int(report.get("timestamp_msec", 0))
	]


func _prune_processed_messages() -> void:
	# 消息缓存容量上限；默认 256 条，足以覆盖连续发现广播且防止长局战斗无限增长。
	var message_capacity: int = 256
	while _processed_message_ids.size() > message_capacity:
		# 最旧消息标识；默认空字符串，遍历后用于删除时间戳最小的缓存项。
		var oldest_message_id: String = ""
		# 最旧消息时间；默认最大整数，遇到更早接收时间时更新。
		var oldest_timestamp: int = 9223372036854775807
		# 消息标识遍历项；取值为字典键，用于查找最早接收的情报。
		for raw_message_id in _processed_message_ids.keys():
			# 候选消息标识；取值转为 String，保证删除键与构建时一致。
			var candidate_message_id: String = str(raw_message_id)
			# 候选接收时间；取值来自缓存字典，默认 0 代表最优先清理。
			var candidate_timestamp: int = int(_processed_message_ids[raw_message_id])
			if candidate_timestamp < oldest_timestamp:
				oldest_timestamp = candidate_timestamp
				oldest_message_id = candidate_message_id
		if oldest_message_id.is_empty():
			return
		_processed_message_ids.erase(oldest_message_id)


func _reset_tactical_route() -> void:
	_has_tactical_destination = false
	_tactical_wait_remaining = 0.0
	_is_observing_search_point = false
	_visited_search_point_count = 0
	_ambush_mode = false
	_hold_position_reached = false


func _rotate_profile_order(profiles: Array[Dictionary], rotation_epoch: int) -> void:
	if profiles.size() <= 1:
		return

	# 轮换次数；取值为周期编号对数组长度取模，默认保持全队一致且避免无效整圈移动。
	var rotation_count: int = posmod(rotation_epoch, profiles.size())
	# 轮换索引；取值为 0 到轮换次数减一，每次把首项移动到末尾。
	for _rotation_index in range(rotation_count):
		# 首项档案；取值为数组第一个 Dictionary，用于周期轮换同类单位承担顺序。
		var first_profile: Dictionary = profiles.pop_front()
		profiles.append(first_profile)


func _compare_profile_instance_id(first_profile: Dictionary, second_profile: Dictionary) -> bool:
	return int(first_profile.get("instance_id", 0)) < int(second_profile.get("instance_id", 0))


func _compare_profile_attack_range_descending(first_profile: Dictionary, second_profile: Dictionary) -> bool:
	# 第一项射程；取值默认 0，用于远程迂回候选从长射程到短射程排序。
	var first_range: float = float(first_profile.get("attack_range", 0.0))
	# 第二项射程；取值默认 0，与第一项比较决定排序顺序。
	var second_range: float = float(second_profile.get("attack_range", 0.0))
	if not is_equal_approx(first_range, second_range):
		return first_range > second_range
	return int(first_profile.get("instance_id", 0)) < int(second_profile.get("instance_id", 0))


func _compare_search_priority(first_profile: Dictionary, second_profile: Dictionary) -> bool:
	# 第一项远程标记；false 的近战单位应排在前方优先承担贴墙搜查。
	var first_is_ranged: bool = bool(first_profile.get("is_ranged", false))
	# 第二项远程标记；用于与第一项比较近战优先级。
	var second_is_ranged: bool = bool(second_profile.get("is_ranged", false))
	if first_is_ranged != second_is_ranged:
		return not first_is_ranged
	return int(first_profile.get("instance_id", 0)) < int(second_profile.get("instance_id", 0))
