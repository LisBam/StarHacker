extends Node2D
class_name RangedAttackComponent

## 远程攻击组件负责把“攻击请求”转换成独立弹体。
## 弹体场景、冷却时间、速度和枪口节点都暴露在检查器中，方便不同武器复用同一组件。

signal fired(projectile: Node2D)

## 弹体场景资源；默认由角色预制体指定，必须实例化为 Node2D，运行时修改会影响后续射击生成的弹体类型。
@export var projectile_scene: PackedScene
## 枪口节点路径；默认指向玩家 AimPivot/Muzzle，必须解析到 Node2D，修改会影响弹体出生位置。
@export var muzzle_path: NodePath = ^"../AimPivot/Muzzle"
## 弹体发射速度；取值建议大于 0，默认 900 适合快速射击原型，运行时修改会影响新弹体飞行速度。
@export_range(1.0, 2400.0, 1.0, "or_greater") var projectile_speed: float = 900.0
## 默认弹体伤害；取值建议大于等于 0，默认 12 用于未传入武器数据时的兜底伤害，运行时修改会影响无装备模式下的射击伤害。
@export_range(0.0, 9999.0, 1.0, "or_greater") var projectile_damage: float = 12.0
## 冷却时间；取值应大于 0，默认 0.16 秒形成连续点射手感，运行时修改会影响攻击频率。
@export_range(0.01, 5.0, 0.01) var cooldown: float = 0.16
## 枪口缺失时的备用出生距离；取值应大于等于 0，默认 34 让弹体从角色前方出现，修改会影响兜底发射位置。
@export_range(0.0, 160.0, 1.0) var fallback_muzzle_distance: float = 34.0
## 枪口碰撞检查半径；取值建议略大于弹体半径，默认 7 像素，修改会影响贴墙射击被阻止的距离。
@export_range(0.0, 64.0, 0.5) var muzzle_block_check_radius: float = 7.0
## 枪口阻挡检测掩码；默认检测第 5 层环境墙体，修改会影响哪些物体能阻止子弹生成。
@export_flags_2d_physics var muzzle_block_collision_mask: int = 16
## 弹体父节点路径；默认留空表示挂到当前场景，运行时通常不修改，指定后会影响弹体所在层级和坐标继承。
@export var projectile_parent_path: NodePath
## 散射中心弹偏移比例；默认 0.25，主弹只使用完整偏移角的四分之一并随机落在瞄准方向附近。
@export_range(0.0, 1.0, 0.01) var scatter_center_deviation_ratio: float = 0.25
## 散射分层随机比例；默认 0.35，其余弹体围绕左右等距锚点随机抖动且不会跨越所属侧。
@export_range(0.0, 0.49, 0.01) var scatter_layer_jitter_ratio: float = 0.35

## 剩余冷却；取值大于等于 0，默认 0 表示可立即攻击，修改会影响组件是否接受下一次攻击请求。
var _cooldown_remaining: float = 0.0
## 当前冷却总时长；取值大于等于 0，默认 0 表示无冷却基准，修改会影响 HUD 冷却覆盖比例。
var _cooldown_duration: float = 0.0
## 连击剩余轮数；取值大于等于 0，默认 0 表示当前没有正在执行的连击。
var _combo_rounds_remaining: int = 0
## 下一轮连击等待时间；取值大于等于 0，默认 0，归零时生成下一轮全部散射弹体。
var _combo_interval_remaining: float = 0.0
## 当前连击轮次间隔；默认 0.08 秒，由武器资源在攻击开始时覆盖。
var _active_combo_interval: float = 0.08
## 当前连击结束后的武器冷却；默认使用组件冷却，只有末轮成功执行后才写入正式冷却计时。
var _active_combo_cooldown: float = 0.0
## 当前连击攻击方向；默认向右，每轮发射前从持有者读取最新瞄准方向，使连击持续跟随鼠标。
var _active_combo_direction: Vector2 = Vector2.RIGHT
## 当前连击武器资源；默认 null，连击结束后清空，保证中途切换装备不会改变已经开始的攻击参数。
var _active_combo_weapon: Resource
## 弹体偏移随机源；默认启动时随机化，每颗弹体独立生成受分层范围约束的角度偏移。
var _deviation_random: RandomNumberGenerator = RandomNumberGenerator.new()
## 枪口空间查询复用圆形；初始使用引擎默认半径，每次攻击查询前同步 muzzle_block_check_radius，避免每颗弹体重复分配 Shape2D 资源。
var _muzzle_block_shape: CircleShape2D = CircleShape2D.new()
## 枪口形状查询复用参数；对象跨攻击复用，每次查询前只刷新形状、变换与掩码字段，避免每颗弹体重复分配查询参数对象。
var _muzzle_block_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
## 持有者属性组件缓存；首次读取时按节点名解析一次并复用，替代每颗弹体重复执行的字符串路径查找。
var _owner_stats_component: Node = null
## 属性组件是否已完成解析；默认 false，首次读取后置 true，解析失败时不再逐弹体重复查找。
var _owner_stats_component_resolved: bool = false

## 枪口节点缓存；默认按 muzzle_path 解析，允许为空并走备用距离，修改会影响弹体出生位置来源。
@onready var _muzzle: Node2D = get_node_or_null(muzzle_path) as Node2D


func _ready() -> void:
	_deviation_random.randomize()
	# 组件初始没有冷却或连击状态，首次成功攻击会按需重新启用处理。
	set_process(false)


func _process(delta: float) -> void:
	if _combo_rounds_remaining <= 0:
		_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
		if _cooldown_remaining <= 0.0:
			# 空闲处理关闭；后续攻击会由 _start_cooldown 重新启用，不改变公开冷却状态。
			set_process(false)
		return
	# 连击期间冷却保持满值；HUD 从首轮开始显示冷却覆盖，末轮完成后才开始正常减少。
	_cooldown_remaining = _cooldown_duration
	_combo_interval_remaining = maxf(_combo_interval_remaining - delta, 0.0)
	if _combo_interval_remaining > 0.0:
		return
	# 最新瞄准方向；玩家控制器公开当前鼠标瞄准方向时逐轮刷新，独立测试场景则安全沿用首发方向。
	var latest_combo_direction: Vector2 = _get_latest_combo_direction()
	_active_combo_direction = latest_combo_direction if not latest_combo_direction.is_zero_approx() else _active_combo_direction
	_fire_round(_active_combo_direction, _active_combo_weapon)
	_combo_rounds_remaining -= 1
	if _combo_rounds_remaining > 0:
		_combo_interval_remaining = _active_combo_interval
		return
	_start_cooldown(_active_combo_cooldown)
	_active_combo_weapon = null


func _get_latest_combo_direction() -> Vector2:
	## 返回连击当前轮次的瞄准方向；组件保持独立，只依赖父节点可选的公开接口，不硬编码玩家脚本类型。
	var owner_node: Node = get_parent()
	if owner_node != null and owner_node.has_method("get_current_aim_direction"):
		return owner_node.call("get_current_aim_direction") as Vector2
	return _active_combo_direction


func try_attack(direction: Vector2, weapon_data: Resource = null, attack_modifiers: Dictionary = {}) -> bool:
	# 本次使用的弹体场景；取值来自武器数据或组件默认值，默认 projectile_scene，修改会影响实际生成的弹体类型。
	var selected_projectile_scene: PackedScene = _get_weapon_packed_scene(weapon_data, "projectile_scene", projectile_scene)
	# 本次使用的弹体速度；取值来自武器数据或组件默认值，默认 projectile_speed，修改会影响本次弹体飞行速度。
	var selected_projectile_speed: float = _get_weapon_float(weapon_data, "projectile_speed", projectile_speed)
	# 本次使用的攻击距离；远程武器以该值限制弹体最大飞行距离，默认 340 像素。
	var selected_attack_distance: float = _get_weapon_attack_float(weapon_data, "attack_distance", "ranged", 340.0)
	# 本次使用的弹体伤害；取值来自武器数据或组件默认值，默认 projectile_damage，修改会影响本次弹体命中伤害。
	var selected_projectile_damage: float = _get_weapon_attack_float(weapon_data, "damage", "ranged", projectile_damage) * maxf(float(attack_modifiers.get("damage_multiplier", 1.0)), 0.0)
	# 本次使用的冷却；取值来自武器数据或组件默认值，默认 cooldown，修改会影响下一次可攻击时间。
	var selected_cooldown: float = _get_weapon_float(weapon_data, "cooldown", cooldown) * maxf(float(attack_modifiers.get("cooldown_multiplier", 1.0)), 0.0)
	# 本次使用的弹体冲击力；取值来自武器数据，单位为目标单次无碰撞理论位移像素，默认 0 表示只造成伤害不击退。
	var selected_impact_force: float = _get_weapon_attack_float(weapon_data, "impact_force", "ranged", 0.0) * maxf(float(attack_modifiers.get("impact_multiplier", 1.0)), 0.0)
	# 本次使用的偏移角度；取值来自武器数据，默认 0 度表示弹体严格沿瞄准方向发射。
	var selected_deviation_degrees: float = maxf(_get_weapon_float(weapon_data, "deviation_degrees", 0.0), 0.0)
	# 本次每轮散射弹体数；未持有散射属性的武器固定为 1，避免默认字段让普通武器获得额外弹体。
	var selected_scatter_count: int = maxi(roundi(_get_weapon_float(weapon_data, "scatter_count", 1.0)), 1) if _weapon_has_attribute(weapon_data, "has_scatter") else 1
	# 本次连击轮数；未持有连击属性的武器固定为 1，完整轮次结束后才进入正式冷却。
	var selected_combo_count: int = maxi(roundi(_get_weapon_float(weapon_data, "combo_count", 1.0)), 1) if _weapon_has_attribute(weapon_data, "has_combo") else 1
	# 本次穿透次数；表示每颗弹体在首个目标之后还能额外穿过的目标数量。
	var selected_piercing_count: int = maxi(roundi(_get_weapon_float(weapon_data, "piercing_count", 0.0)), 0) if _weapon_has_attribute(weapon_data, "has_piercing") else 0
	# 本次弹射次数；表示每颗弹体在墙体或可穿透目标命中后最多还能改变方向的次数。
	var selected_bounce_count: int = maxi(roundi(_get_weapon_float(weapon_data, "bounce_count", 0.0)), 0) if _weapon_has_attribute(weapon_data, "has_bounce") else 0

	if not _is_attack_ready(direction, weapon_data):
		return false
	# 连击运行参数；集中保存本次攻击数据，后续轮次无需依赖玩家当前装备槽状态。
	weapon_data.set_meta("active_scatter_count", selected_scatter_count)
	weapon_data.set_meta("active_has_scatter", _weapon_has_attribute(weapon_data, "has_scatter"))
	weapon_data.set_meta("active_piercing_count", selected_piercing_count)
	weapon_data.set_meta("active_bounce_count", selected_bounce_count)
	weapon_data.set_meta("active_projectile_scene", selected_projectile_scene)
	weapon_data.set_meta("active_projectile_speed", selected_projectile_speed)
	weapon_data.set_meta("active_attack_distance", selected_attack_distance)
	weapon_data.set_meta("active_projectile_damage", selected_projectile_damage)
	weapon_data.set_meta("active_impact_force", selected_impact_force)
	weapon_data.set_meta("active_deviation_degrees", selected_deviation_degrees)
	if not _fire_round(direction.normalized(), weapon_data):
		return false
	_combo_rounds_remaining = selected_combo_count - 1
	_active_combo_direction = direction.normalized()
	_active_combo_weapon = weapon_data if _combo_rounds_remaining > 0 else null
	_active_combo_interval = maxf(float(weapon_data.get("combo_interval")), 0.01)
	_combo_interval_remaining = _active_combo_interval
	_active_combo_cooldown = selected_cooldown
	# 首轮成功时立即显示完整冷却；连击期间保持满值，末轮结束后重新开始减少。
	_start_cooldown(selected_cooldown)
	return true


func can_attack(direction: Vector2, weapon_data: Resource = null) -> bool:
	## 返回组件当前是否具备开始一次远程攻击的基础条件；控制器可在混合攻击前预检双通道，避免只启动其中一侧。
	if not _is_attack_ready(direction, weapon_data):
		return false
	# 标准化攻击方向；预检使用瞄准中心线，确保枪口被墙体阻挡时混合攻击不会先启动近战效果。
	var resolved_direction: Vector2 = direction.normalized()
	# 标准枪口位置；与实际生成流程使用同一出生点解析，避免预检和执行读取不同节点。
	var spawn_position: Vector2 = _get_spawn_position(resolved_direction)
	return not _is_spawn_blocked(resolved_direction, spawn_position)


func _is_attack_ready(direction: Vector2, weapon_data: Resource = null) -> bool:
	## 返回不包含环境阻挡的远程组件可用状态；普通射击继续让每颗偏移弹体独立检测枪口，避免中心线预检改变散射和偏移武器行为。
	# 本次使用的弹体场景；优先读取武器资源覆盖值，空资源时回退组件默认场景。
	var selected_projectile_scene: PackedScene = _get_weapon_packed_scene(weapon_data, "projectile_scene", projectile_scene)
	return selected_projectile_scene != null and _cooldown_remaining <= 0.0 and _combo_rounds_remaining <= 0 and not direction.is_zero_approx()


func _fire_round(direction: Vector2, weapon_data: Resource) -> bool:
	if weapon_data == null:
		return false
	# 当前轮成功弹体数量；至少一颗成功生成才把该轮视为有效攻击。
	var spawned_projectile_count: int = 0
	# 当前轮散射数量；显式散射武器按扇形角度表生成，普通武器仍只发射一颗弹体。
	var scatter_count: int = maxi(int(weapon_data.get_meta("active_scatter_count", 1)), 1)
	# 当前轮偏移角度；限制为非负数，表示瞄准方向两侧各自允许使用的最大角度。
	var deviation_degrees: float = maxf(float(weapon_data.get_meta("active_deviation_degrees", 0.0)), 0.0)
	# 是否为显式散射武器；散射武器保留瞄准附近主弹，普通武器继续使用单弹随机偏移。
	var has_scatter: bool = bool(weapon_data.get_meta("active_has_scatter", false))
	# 当前轮弹体角度表；元素为相对瞄准方向的浮点随机角度，默认空表会按散射状态填入本轮全部弹体偏移。
	var projectile_offsets: Array[float] = []
	if has_scatter:
		projectile_offsets = _build_scatter_deviation_offsets_degrees(scatter_count, deviation_degrees)
	else:
		projectile_offsets.append(_deviation_random.randf_range(-deviation_degrees, deviation_degrees))
	# 本轮弹体父节点；同轮全部弹体挂载到同一父节点，提升到循环外只解析一次避免逐弹体节点查找。
	var projectile_parent: Node = _resolve_projectile_parent()
	# 本轮是否使用共享枪口出生点；枪口节点有效时全部散射弹体共用同一出生位置，阻挡检测与弹体方向无关。
	var uses_shared_spawn_position: bool = is_instance_valid(_muzzle)
	# 本轮共享阻挡结果；共享出生点成立时线段起终点固定且检测形状为圆形不受旋转影响，因此只需按瞄准方向预计算一次。
	var shared_spawn_blocked: bool = uses_shared_spawn_position and _is_spawn_blocked(direction, _muzzle.global_position)
	for projectile_offset in projectile_offsets:
		# 本颗弹体方向；散射武器使用分层随机偏移，普通武器使用完整区间随机偏移。
		var resolved_direction: Vector2 = direction.rotated(deg_to_rad(projectile_offset))
		# 本颗弹体出生位置；枪口或备用位置被墙体阻挡时只跳过该颗弹体。
		var spawn_position: Vector2 = _get_spawn_position(resolved_direction)
		# 本颗弹体阻挡状态；共享出生点直接复用本轮预计算结果，只有无枪口兜底出生点随方向变化时才保留逐弹体检测。
		var spawn_blocked: bool = shared_spawn_blocked if uses_shared_spawn_position else _is_spawn_blocked(resolved_direction, spawn_position)
		if spawn_blocked:
			continue
		# 本颗弹体实例；资源异常时跳过，不影响同轮其他散射弹体继续生成。
		var projectile_scene_resource: PackedScene = weapon_data.get_meta("active_projectile_scene") as PackedScene
		var projectile: Node2D = projectile_scene_resource.instantiate() as Node2D if projectile_scene_resource != null else null
		if projectile == null:
			continue
		if projectile.has_method("set_damage"):
			projectile.call("set_damage", float(weapon_data.get_meta("active_projectile_damage", projectile_damage)))
		if projectile.has_method("set_max_distance"):
			projectile.call("set_max_distance", float(weapon_data.get_meta("active_attack_distance", 340.0)))
		if projectile.has_method("set_impact_force"):
			projectile.call("set_impact_force", float(weapon_data.get_meta("active_impact_force", 0.0)))
		if projectile.has_method("set_piercing_count"):
			projectile.call("set_piercing_count", int(weapon_data.get_meta("active_piercing_count", 0)))
		if projectile.has_method("set_bounce_count"):
			projectile.call("set_bounce_count", int(weapon_data.get_meta("active_bounce_count", 0)))
		if projectile.has_method("configure_combat_attributes"):
			projectile.call("configure_combat_attributes", _get_owner_attack_power(), clampf(_get_weapon_float(weapon_data, "critical_chance", 0.0) + _get_stats_float("get_equipment_critical_chance", 0.0), 0.0, EnhancementRules.CRITICAL_CHANCE_MAXIMUM), _get_weapon_float(weapon_data, "critical_damage", 1.5) + _get_stats_float("get_equipment_critical_damage", 0.0))
		if projectile.has_method("set_damage_instigator"):
			projectile.call("set_damage_instigator", owner)
		projectile.global_position = spawn_position
		projectile.global_rotation = resolved_direction.angle()
		projectile_parent.add_child(projectile)
		projectile.global_position = spawn_position
		projectile.global_rotation = resolved_direction.angle()
		if projectile.has_method("launch"):
			projectile.call("launch", resolved_direction, float(weapon_data.get_meta("active_projectile_speed", projectile_speed)))
		fired.emit(projectile)
		spawned_projectile_count += 1
	return spawned_projectile_count > 0


func _build_scatter_deviation_offsets_degrees(scatter_count: int, deviation_degrees: float) -> Array[float]:
	## 生成显式散射武器的分层随机角度；主弹随机靠近瞄准方向，其余弹体在左右各自层级内随机并保持分散。
	# 安全弹体数量；最低为 1，异常强化数据不会生成空射击轮次。
	var resolved_scatter_count: int = maxi(scatter_count, 1)
	# 安全偏移角；最低为 0，零偏移时全部弹体只能沿瞄准方向重合。
	var resolved_deviation_degrees: float = maxf(deviation_degrees, 0.0)
	# 中心弹随机范围；只使用完整偏移角的一部分，使主弹受偏移影响但仍优先靠近瞄准方向。
	var center_deviation: float = resolved_deviation_degrees * clampf(scatter_center_deviation_ratio, 0.0, 1.0)
	# 角度结果；第一项为主弹的随机偏移，零偏移时保持 0 度。
	var offsets: Array[float] = [_deviation_random.randf_range(-center_deviation, center_deviation)]
	if resolved_scatter_count <= 1 or resolved_deviation_degrees <= 0.0:
		while offsets.size() < resolved_scatter_count:
			offsets.append(0.0)
		return offsets

	# 中心弹之外的弹体数量；尽量平均分配到瞄准方向左右两侧。
	var remaining_projectile_count: int = resolved_scatter_count - 1
	# 左侧弹体数量；偶数总弹数会随机决定多出的一颗位于哪一侧，避免长期固定偏向。
	var left_projectile_count: int = remaining_projectile_count / 2
	# 右侧弹体数量；与左侧共同占满全部剩余弹体。
	var right_projectile_count: int = remaining_projectile_count - left_projectile_count
	if remaining_projectile_count % 2 == 1 and _deviation_random.randi_range(0, 1) == 0:
		left_projectile_count = right_projectile_count
		right_projectile_count = remaining_projectile_count - left_projectile_count

	for left_index in range(1, left_projectile_count + 1):
		# 左侧层级间距；本侧弹体以等距锚点为中心随机，较大下标逐步靠近负偏移边界。
		var left_layer_step: float = resolved_deviation_degrees / float(left_projectile_count)
		# 左侧锚点；固定为负角度，确保随机抖动后仍从瞄准方向左侧射出。
		var left_anchor: float = -left_layer_step * float(left_index)
		# 左侧随机半径；限制在层级间距的 49% 内，避免相邻层级交叉或越过瞄准线。
		var left_jitter: float = left_layer_step * clampf(scatter_layer_jitter_ratio, 0.0, 0.49)
		# 左侧角度；每颗弹体独立随机并夹取到完整偏移范围。
		var left_offset: float = clampf(_deviation_random.randf_range(left_anchor - left_jitter, left_anchor + left_jitter), -resolved_deviation_degrees, -0.0001)
		offsets.append(left_offset)
	for right_index in range(1, right_projectile_count + 1):
		# 右侧层级间距；与左侧使用相同规则，保证两侧总体密度接近。
		var right_layer_step: float = resolved_deviation_degrees / float(right_projectile_count)
		# 右侧锚点；固定为正角度，确保随机抖动后仍从瞄准方向右侧射出。
		var right_anchor: float = right_layer_step * float(right_index)
		# 右侧随机半径；限制在层级间距的 49% 内，避免相邻层级交叉或越过瞄准线。
		var right_jitter: float = right_layer_step * clampf(scatter_layer_jitter_ratio, 0.0, 0.49)
		# 右侧角度；每颗弹体独立随机并夹取到完整偏移范围。
		var right_offset: float = clampf(_deviation_random.randf_range(right_anchor - right_jitter, right_anchor + right_jitter), 0.0001, resolved_deviation_degrees)
		offsets.append(right_offset)
	return offsets


func _start_cooldown(duration: float) -> void:
	_cooldown_remaining = maxf(duration, 0.0)
	_cooldown_duration = maxf(duration, 0.0)
	set_process(_cooldown_remaining > 0.0 or _combo_rounds_remaining > 0)


func _weapon_has_attribute(weapon_data: Resource, property_name: StringName) -> bool:
	if weapon_data == null:
		return false
	# 有效机制持有状态；支持武器数据把模板开关与特化累计点数统一结算。
	if weapon_data.has_method("has_effective_attribute"):
		return bool(weapon_data.call("has_effective_attribute", str(property_name)))
	return bool(weapon_data.get(property_name))


func _get_spawn_position(direction: Vector2) -> Vector2:
	if is_instance_valid(_muzzle):
		return _muzzle.global_position

	return global_position + direction.normalized() * fallback_muzzle_distance


func _is_spawn_blocked(direction: Vector2, spawn_position: Vector2) -> bool:
	if muzzle_block_collision_mask == 0:
		return false

	if _is_muzzle_line_blocked(spawn_position):
		return true

	return _is_muzzle_area_blocked(direction, spawn_position)


func _is_muzzle_line_blocked(spawn_position: Vector2) -> bool:
	# 枪口线段检测参数；取值为角色中心到枪口位置，默认用于发现枪口已经越过墙体的情况。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, spawn_position, muzzle_block_collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 枪口线段命中结果；取值为空字典或包含 collider/position，默认非空表示不允许生成子弹。
	var hit_result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit_result.is_empty()


func _is_muzzle_area_blocked(direction: Vector2, spawn_position: Vector2) -> bool:
	# 检查半径；取值至少为 0，默认用于近似弹体出生时占用的空间。
	var check_radius: float = maxf(muzzle_block_check_radius, 0.0)
	if check_radius <= 0.0:
		return false

	# 枪口碰撞圆形；取值为临时 CircleShape2D，默认检测枪口是否已经在墙体内部。
	# 当前局部变量引用组件私有 Shape2D；资源本体跨攻击复用，只更新查询半径以避免连续射击时产生短生命周期资源。
	_muzzle_block_shape.radius = check_radius
	var circle_shape: CircleShape2D = _muzzle_block_shape
	# 枪口检测朝向；取值来自攻击方向，默认只用于构建 Transform2D。
	var check_rotation: float = direction.angle() if not direction.is_zero_approx() else 0.0
	# 枪口形状查询参数；取值为枪口圆形和环境掩码，默认用于阻止墙内生成弹体。
	# 当前局部变量引用组件私有查询参数；对象本体跨攻击复用，每次只刷新字段值以避免连续射击时产生短生命周期对象。
	var query: PhysicsShapeQueryParameters2D = _muzzle_block_query
	query.shape = circle_shape
	query.transform = Transform2D(check_rotation, spawn_position)
	query.collision_mask = muzzle_block_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 枪口形状命中列表；取值为空数组或若干碰撞结果，默认非空表示枪口空间被墙体占用。
	var hit_results: Array = get_world_2d().direct_space_state.intersect_shape(query, 1)
	return not hit_results.is_empty()


func _resolve_projectile_parent() -> Node:
	if not projectile_parent_path.is_empty():
		# 检查器配置的弹体父节点；取值为 Node 或 null，默认由 projectile_parent_path 查找，修改会影响父节点解析结果。
		var configured_parent: Node = get_node_or_null(projectile_parent_path)
		if configured_parent != null:
			return configured_parent

	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func get_cooldown_duration() -> float:
	return _cooldown_duration


func get_cooldown_ratio() -> float:
	if _cooldown_duration <= 0.0:
		return 0.0

	return clampf(_cooldown_remaining / _cooldown_duration, 0.0, 1.0)


func _get_weapon_float(weapon_data: Resource, property_name: StringName, fallback_value: float) -> float:
	if weapon_data == null:
		return fallback_value
	if weapon_data.has_method("get_effective_stat"):
		return float(weapon_data.call("get_effective_stat", str(property_name)))

	# 武器资源字段值；取值可能为数字或 null，默认通过 Resource.get 读取，修改会影响参数覆盖结果。
	var property_value: Variant = weapon_data.get(property_name)
	if property_value == null:
		return fallback_value

	return float(property_value)


func _get_weapon_attack_float(weapon_data: Resource, stat_name: String, attack_mode: String, fallback_value: float) -> float:
	## 读取指定远近战通道的有效属性；混合武器由资源返回独立基础值与共享强化结果，旧资源继续使用普通有效属性接口。
	if weapon_data == null:
		return fallback_value
	if weapon_data.has_method("get_effective_attack_stat"):
		return float(weapon_data.call("get_effective_attack_stat", stat_name, attack_mode))
	# 旧属性名；伤害在资源中以 ranged_damage 保存，其余字段保持通用名称。
	var legacy_property_name: String = "ranged_damage" if stat_name == "damage" else stat_name
	return _get_weapon_float(weapon_data, legacy_property_name, fallback_value)


func _get_weapon_packed_scene(weapon_data: Resource, property_name: StringName, fallback_scene: PackedScene) -> PackedScene:
	if weapon_data == null:
		return fallback_scene

	# 武器资源场景字段值；取值可能为 PackedScene 或 null，默认通过 Resource.get 读取，修改会影响弹体场景覆盖结果。
	var property_value: Variant = weapon_data.get(property_name)
	if property_value is PackedScene:
		return property_value as PackedScene

	return fallback_scene


func _get_owner_stats_component() -> Node:
	## 返回缓存的持有者属性组件；只在首次读取或缓存节点被释放后重新解析一次，替代每颗弹体的字符串节点查找。
	if not _owner_stats_component_resolved or (_owner_stats_component != null and not is_instance_valid(_owner_stats_component)):
		_owner_stats_component = owner.get_node_or_null("StatsComponent") if owner != null else null
		_owner_stats_component_resolved = true
	return _owner_stats_component


func _get_owner_attack_power() -> float:
	# 玩家属性组件；缺失时使用 100 保持原始伤害。
	var stats_component: Node = _get_owner_stats_component()
	return float(stats_component.call("get_attack_power")) if stats_component != null and stats_component.has_method("get_attack_power") else 100.0


func _get_stats_float(method_name: String, fallback_value: float) -> float:
	# 玩家属性组件；用于读取装备提供的暴击附加值。
	var stats_component: Node = _get_owner_stats_component()
	return float(stats_component.call(method_name)) if stats_component != null and stats_component.has_method(method_name) else fallback_value
