## 敌人战术组件全局类名；供宿主聚合脚本与其他系统做类型化引用，不改变节点运行行为。
class_name EnemyTacticalComponent
extends Node

## 敌人战术组件只读取本怪物的感知线索并生成二维搜查与伏击目标。
## 组件不发现队友、不共享情报，也不直接修改感知状态、攻击逻辑或物理速度。

## 搜查单位职能；默认优先分配给近战单位，负责逐层排查墙角、死角和最后消失区域。
const TACTICAL_ROLE_SEARCHER: int = 0
## 卡位单位职能；默认远近搭配占据墙体近口、外围岔路和预测逃生路线。
const TACTICAL_ROLE_HOLDER: int = 1
## 迂回单位职能；默认优先或仅由远程单位从墙体外侧绕行并封堵远端路线。
const TACTICAL_ROLE_FLANKER: int = 2

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
## 战术宿主；取值为 CharacterBody2D 或 null，默认由敌人聚合脚本注入，用于读取本怪物位置。
var _actor: CharacterBody2D
## 感知组件；取值为 Node 或 null，默认通过只读接口提供警戒状态和本地情报，不形成具体脚本类型依赖。
var _perception_component: Node
## 移动组件；取值为 Node 或 null，默认通过可导航性接口过滤候选战术点。
var _movement_component: Node
## 组件使用的随机源；默认与宿主共享，用于错开搜查等待时间且保持每个敌人的独立节奏。
var _random: RandomNumberGenerator
## 当前本地线索；取值为本怪物感知生成的消失点、遮挡点、逃跑方向和记忆热点字典。
var _intelligence: Dictionary = {}
## 当前是否拥有可用本地线索；默认 false，本怪物形成可见或消失报告后变为 true。
var _has_intelligence: bool = false
## 已处理的本地线索版本；默认 -1，版本递增时刷新本怪物独立战术路线。
var _last_local_intelligence_revision: int = -1
## 当前职能；取值为 TACTICAL_ROLE_* 常量，默认搜查单位以兼容单 AI 行为。
var _current_role: int = TACTICAL_ROLE_SEARCHER
## 当前职能内序号；取值从 0 开始，用于把同职能单位分配到不同扇区、岔路深度和墙体侧面。
var _role_slot_index: int = 0
## 当前战术目的地；取值为世界坐标，仅在 _has_tactical_destination 为 true 时有效。
var _tactical_destination: Vector2 = Vector2.ZERO
## 当前是否已有战术目的地；默认 false，需要时由固定单体职能和本怪物感知线索生成。
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
func initialize(actor: CharacterBody2D, perception_component: Node, movement_component: Node, random_source: RandomNumberGenerator) -> void:
	_actor = actor
	_perception_component = perception_component
	_movement_component = movement_component
	_random = random_source


func apply_configuration(settings: Dictionary) -> void:
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


func reset_intelligence() -> void:
	_intelligence.clear()
	_has_intelligence = false
	_last_local_intelligence_revision = -1
	_reset_tactical_route()


func update(delta: float) -> void:
	if not is_instance_valid(_actor):
		return

	_pull_local_intelligence()

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


func _pull_local_intelligence() -> void:
	if _perception_component == null or not _perception_component.has_method("get_tactical_intelligence"):
		return

	if _perception_component.has_method("get_tactical_intelligence_revision"):
		# 感知情报当前版本号；取值单调递增，先经轻量接口比对，与已处理版本一致或更旧时完全跳过情报字典构造与解析。
		var current_intelligence_revision: int = int(_perception_component.call("get_tactical_intelligence_revision"))
		if current_intelligence_revision <= _last_local_intelligence_revision:
			return

	# 感知组件原始情报；取值为 Dictionary 或其他 Variant，默认只处理结构化字典。
	# 补充说明：感知接口每次调用都构造全新字典且自身不保留引用，这里直接使用返回值，无需深拷贝。
	var raw_report: Variant = _perception_component.call("get_tactical_intelligence")
	if not (raw_report is Dictionary):
		return

	# 本地情报报告；取值包含版本、来源、目标和消失线索，空字典表示当前没有新情报。
	var report: Dictionary = raw_report
	if report.is_empty():
		return

	# 本地线索版本；取值单调递增，默认避免每个 AI 决策周期重复重建同一条搜查路线。
	var report_revision: int = int(report.get("revision", -1))
	if report_revision <= _last_local_intelligence_revision:
		return

	_last_local_intelligence_revision = report_revision
	_intelligence = report
	_has_intelligence = true
	_reset_tactical_route()


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
	# 攻击距离差异倍率；远程扩大扇形，近战收缩半径贴墙排查。
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

	# 远程偏好距离；取值来自宿主攻击能力，至少使用中层半径以保持安全攻击距离。
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

	# 剩余完整验证预算；默认 2，限制单次旋转重试中触发含 A* 完整验证的候选数量，预算耗尽后剩余候选只做射线粗筛。
	var full_validation_budget: int = 2
	# 战术候选索引；取值为 0 到尝试次数减一，左右交替旋转并逐步收缩半径寻找可行点。
	for attempt_index in range(tactical_destination_attempts):
		# 尝试侧向符号；取值 -1 或 1，相邻尝试交替搜索墙体两侧路线。
		var attempt_side: float = -1.0 if attempt_index % 2 == 0 else 1.0
		# 尝试角度；取值每两次增加 18 度，用于避开落在实心墙内或不可达区域的候选。
		var attempt_angle: float = deg_to_rad(18.0 * float(attempt_index / 2 + 1)) * attempt_side
		# 尝试半径倍率；取值最低 0.45，越后续的候选越靠近锚点以提高可达概率。
		var attempt_radius_multiplier: float = maxf(1.0 - float(attempt_index) * 0.08, 0.45)
		# 替代候选点；取值为旋转并收缩后的偏移，交给移动组件验证导航可达性。
		# 补充说明：先做低成本射线粗筛，射线通畅即等价于完整验证通过；射线受阻时才消耗预算执行含 A* 的完整验证。
		var alternative_destination: Vector2 = anchor_position + desired_offset.rotated(attempt_angle) * attempt_radius_multiplier
		if _is_destination_ray_clear(alternative_destination):
			return alternative_destination
		if full_validation_budget <= 0:
			continue
		full_validation_budget -= 1
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
		# 射线粗筛：先用低成本中心线射线过滤墙角候选，避免对每个候选都触发全图 A*；全部射线受阻时按原兜底返回参考位置。
		if not _is_destination_ray_clear(corner_destination):
			continue
		# 墙角评分；取值为候选到参考位置距离，并加入职能序号微小偏置以分散同类单位。
		var corner_score: float = corner_destination.distance_to(reference_position) + absf(float(_role_slot_index) * 4.0)
		if corner_score < best_score:
			best_score = corner_score
			best_destination = corner_destination

	# 最优墙角完整验证：仅对通过射线粗筛的最优候选执行一次含 A* 的完整可导航验证，失败时退回参考位置兜底。
	if best_score < INF and not _is_destination_navigable(best_destination):
		return reference_position

	return best_destination


func _find_nearest_wall_rect(reference_position: Vector2) -> Rect2:
	# 障碍信息提供者；取值通常为 GameWorld，只要求实现 get_minimap_obstacle_rects 能力接口。
	var obstacle_provider: Node = _resolve_obstacle_provider()
	if obstacle_provider == null or not obstacle_provider.has_method("get_minimap_obstacle_rects"):
		return Rect2()

	# 原始障碍矩形数组；取值来自地图共享缓存，默认只处理 Rect2 元素。
	# 补充说明：优先使用只读内部引用接口避免每次战术选点复制整份矩形数组；本函数只遍历读取该数组，禁止修改（只读契约）。
	var raw_rects: Variant = obstacle_provider.call("get_minimap_obstacle_rects_readonly") if obstacle_provider.has_method("get_minimap_obstacle_rects_readonly") else obstacle_provider.call("get_minimap_obstacle_rects")
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


## 目的地射线粗筛；只做中心线射线检测不触发 A*，射线通畅时与完整可导航验证结果等价。
func _is_destination_ray_clear(destination: Vector2) -> bool:
	if _movement_component == null or not _movement_component.has_method("is_destination_ray_clear"):
		# 兜底行为：移动组件缺少射线粗筛接口时退回完整可导航验证，保持战术选点结果与旧逻辑一致。
		return _is_destination_navigable(destination)
	return bool(_movement_component.call("is_destination_ray_clear", destination))


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
	# 线索原始值；取值可能为任意 Variant，默认只接收 Vector2 以避免本地报告数据类型异常。
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


func _is_actor_ranged() -> bool:
	return is_instance_valid(_actor) and _actor.has_method("is_ranged_tactical_unit") and bool(_actor.call("is_ranged_tactical_unit"))


func _get_actor_preferred_distance() -> float:
	if is_instance_valid(_actor) and _actor.has_method("get_tactical_preferred_distance"):
		return maxf(float(_actor.call("get_tactical_preferred_distance")), 1.0)
	return search_middle_radius


func _get_next_tactical_wait() -> float:
	return _random.randf_range(tactical_point_wait_min, tactical_point_wait_max) if _random != null else randf_range(tactical_point_wait_min, tactical_point_wait_max)


func _reset_tactical_route() -> void:
	_has_tactical_destination = false
	_tactical_wait_remaining = 0.0
	_is_observing_search_point = false
	_visited_search_point_count = 0
	_ambush_mode = false
	_hold_position_reached = false
