extends CharacterBody2D
class_name RemotePlayerAvatar

## 远程队友化身是联机战斗中其他玩家在本机世界里的代表节点。
## 它只负责显示外观、昵称与生命护盾状态，并把主机敌人对它造成的伤害转发给所属客户端；不执行输入、技能、库存或任何战斗结算。
## 化身位于玩家物理层并加入 player_combat_target 组，因此主机敌人可以对队友索敌、近战与弹体命中。

## 玩家物理层掩码；化身与本地玩家同层，保证敌方弹体扫掠射线可以命中队友。
const PLAYER_PHYSICS_LAYER: int = 1
## 玩家战斗目标组名；与本地玩家一致，敌人索敌协议按该组扫描全部玩家阵营单位。
const PLAYER_COMBAT_TARGET_GROUP: StringName = &"player_combat_target"
## 化身碰撞半径；与玩家本体 18 像素保持一致，保证敌人攻击距离手感相同。
const AVATAR_COLLISION_RADIUS: float = 18.0
## 头顶信息条尺寸；与技能蓄力条同宽，显示队友生命与护盾比例。
const STATUS_BAR_SIZE: Vector2 = Vector2(64.0, 8.0)
## 头顶信息条偏移；位于化身原点上方 42 像素，与蓄力条位置规范一致。
const STATUS_BAR_OFFSET: Vector2 = Vector2(0.0, -42.0)
## 位置插值速率；数值越大跟随越紧，默认 14 在 20Hz 状态包下兼顾平滑与延迟。
const POSITION_LERP_RATE: float = 14.0
## 位置硬同步距离；本地显示与远端状态相差超过该像素时直接瞬移，避免长时间追赶。
const POSITION_SNAP_DISTANCE: float = 220.0

## 所属成员 peer_id；由同步器创建时写入，用于伤害转发与名册查询。
var _owner_peer_id: int = 0
## 伤害转发回调；参数为 (peer_id, damage, source)，由 NetworkCombatSync 注入并负责把伤害发往所属客户端。
var _damage_forward_handler: Callable = Callable()
## 远端目标位置；每次收到状态包更新，本地渲染位置向它插值。
var _remote_target_position: Vector2 = Vector2.ZERO
## 是否已收到首个状态包；未收到前化身保持创建位置且不参与插值。
var _has_remote_state: bool = false
## 远端瞄准角度；单位弧度，驱动化身朝向指示线旋转。
var _remote_aim_angle: float = 0.0
## 远端当前生命；用于头顶信息条显示与死亡判定辅助展示。
var _remote_current_health: float = 100.0
## 远端最大生命；至少为 1，避免信息条比例除零。
var _remote_max_health: float = 100.0
## 远端当前护盾；大于 0 时信息条叠加白色护盾段。
var _remote_current_shield: float = 0.0
## 远端死亡状态；死亡后化身灰化并从敌人索敌合法目标中自然剔除。
var _remote_is_dead: bool = false
## 身体视觉节点；六边形轮廓与本地玩家一致，颜色按成员配色区分。
var _body_polygon: Polygon2D = null
## 核心视觉节点；小菱形装饰与本地玩家一致。
var _core_polygon: Polygon2D = null
## 瞄准指示线；从化身中心指向远端瞄准方向，帮助识别队友交战朝向。
var _aim_line: Line2D = null
## 昵称标签；显示成员昵称与角色名，始终保持水平不随化身旋转。
var _name_label: Label = null
## 头顶信息条绘制节点；使用自定义绘制显示生命与护盾比例。
var _status_bar: Node2D = null


func setup_avatar(peer_id: int, display_name: String, body_color: Color, damage_forward_handler: Callable) -> void:
	## 一次性初始化化身；由 NetworkCombatSync 在创建后、入树前调用。
	_owner_peer_id = peer_id
	_damage_forward_handler = damage_forward_handler
	_build_visuals(display_name, body_color)


func _ready() -> void:
	collision_layer = PLAYER_PHYSICS_LAYER
	# 化身不主动移动也不阻挡任何对象；位置完全由远端状态驱动，碰撞掩码保持为空。
	collision_mask = 0
	add_to_group(PLAYER_COMBAT_TARGET_GROUP)
	# 化身碰撞形状；圆形半径与玩家本体一致，供敌方弹体扫掠射线命中。
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	# 化身圆形碰撞数据；独立实例避免与其他化身共享形状资源。
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = AVATAR_COLLISION_RADIUS
	collision_shape.shape = circle_shape
	add_child(collision_shape)


func _process(delta: float) -> void:
	if not _has_remote_state:
		return
	# 本帧与远端目标的距离；超过硬同步阈值直接瞬移，否则指数插值平滑跟随。
	var distance_to_target: float = global_position.distance_to(_remote_target_position)
	if distance_to_target > POSITION_SNAP_DISTANCE:
		global_position = _remote_target_position
	else:
		global_position = global_position.lerp(_remote_target_position, clampf(POSITION_LERP_RATE * delta, 0.0, 1.0))
	if _aim_line != null:
		_aim_line.rotation = _remote_aim_angle


func update_remote_state(remote_position: Vector2, aim_angle: float, current_health: float, max_health: float, current_shield: float, is_remote_dead: bool) -> void:
	## 应用一份远端玩家状态；位置进入插值目标，生命护盾立即刷新头顶信息条。
	_remote_target_position = remote_position
	if not _has_remote_state:
		# 首个状态包直接落位；避免化身从世界原点飞向队友真实位置。
		global_position = remote_position
		_has_remote_state = true
	_remote_aim_angle = aim_angle
	_remote_current_health = maxf(current_health, 0.0)
	_remote_max_health = maxf(max_health, 1.0)
	_remote_current_shield = maxf(current_shield, 0.0)
	if is_remote_dead != _remote_is_dead:
		_remote_is_dead = is_remote_dead
		_apply_death_visual_state()
	if _status_bar != null:
		_status_bar.queue_redraw()


func apply_damage(damage: float, source: Node) -> void:
	## 主机敌人命中化身的统一入口；不在本机结算，只把伤害与来源数值转发给所属客户端。
	if _remote_is_dead or damage <= 0.0:
		return
	if _damage_forward_handler.is_valid():
		_damage_forward_handler.call(_owner_peer_id, damage, source)


func is_dead() -> bool:
	## 返回远端玩家是否已死亡；敌人索敌合法性检查通过该接口跳过阵亡队友。
	return _remote_is_dead


func get_owner_peer_id() -> int:
	return _owner_peer_id


func _build_visuals(display_name: String, body_color: Color) -> void:
	## 构建化身外观；六边形身体、菱形核心与本地玩家一致，配色按成员区分。
	_body_polygon = Polygon2D.new()
	_body_polygon.name = "Body"
	_body_polygon.polygon = _build_regular_polygon_points(24.0, 6)
	_body_polygon.color = body_color
	add_child(_body_polygon)
	_core_polygon = Polygon2D.new()
	_core_polygon.name = "Core"
	_core_polygon.polygon = PackedVector2Array([
		Vector2(0.0, -9.0),
		Vector2(9.0, 0.0),
		Vector2(0.0, 9.0),
		Vector2(-9.0, 0.0),
	])
	# 核心配色；在身体颜色基础上提亮，保持与本地玩家“亮核心”的层次关系。
	_core_polygon.color = body_color.lightened(0.65)
	add_child(_core_polygon)
	_aim_line = Line2D.new()
	_aim_line.name = "AimLine"
	_aim_line.points = PackedVector2Array([Vector2(14.0, 0.0), Vector2(30.0, 0.0)])
	_aim_line.width = 3.0
	_aim_line.default_color = Color(body_color.r, body_color.g, body_color.b, 0.85)
	add_child(_aim_line)
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.text = display_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 0.95))
	# 昵称标签定位；固定宽度居中放在信息条上方，不随化身缩放旋转。
	_name_label.position = Vector2(-70.0, -74.0)
	_name_label.custom_minimum_size = Vector2(140.0, 0.0)
	add_child(_name_label)
	_status_bar = Node2D.new()
	_status_bar.name = "StatusBar"
	_status_bar.position = STATUS_BAR_OFFSET
	_status_bar.draw.connect(_draw_status_bar)
	add_child(_status_bar)


func _build_regular_polygon_points(radius: float, side_count: int) -> PackedVector2Array:
	## 生成正多边形顶点；用于复刻玩家六边形身体轮廓。
	# 顶点结果数组；按角度均分生成 side_count 个顶点。
	var points: PackedVector2Array = PackedVector2Array()
	for point_index in range(side_count):
		# 当前顶点角度；从正右方向开始逆时针均分整圆。
		var point_angle: float = TAU * float(point_index) / float(side_count)
		points.append(Vector2(cos(point_angle), sin(point_angle)) * radius)
	return points


func _draw_status_bar() -> void:
	## 绘制头顶生命护盾条；生命为绿色填充，存在护盾时叠加白色内边框提示。
	if _status_bar == null:
		return
	# 信息条背景矩形；以偏移原点居中，深色底保证各种地面颜色下可读。
	var background_rect: Rect2 = Rect2(Vector2(-STATUS_BAR_SIZE.x * 0.5, -STATUS_BAR_SIZE.y * 0.5), STATUS_BAR_SIZE)
	_status_bar.draw_rect(background_rect, Color(0.05, 0.08, 0.1, 0.82), true)
	# 生命比例；远端最大生命至少为 1，死亡时比例为 0。
	var health_ratio: float = clampf(_remote_current_health / _remote_max_health, 0.0, 1.0)
	if health_ratio > 0.0:
		# 生命填充矩形；宽度按生命比例截取。
		var fill_rect: Rect2 = Rect2(background_rect.position, Vector2(STATUS_BAR_SIZE.x * health_ratio, STATUS_BAR_SIZE.y))
		_status_bar.draw_rect(fill_rect, Color(0.36, 0.86, 0.5, 0.95), true)
	if _remote_current_shield > 0.0:
		# 护盾提示边框；与本地玩家血条护盾内边框语义一致，使用高不透明度白色。
		_status_bar.draw_rect(background_rect.grow(-1.0), Color(1.0, 1.0, 1.0, 0.92), false, 1.0)
	_status_bar.draw_rect(background_rect, Color(0.2, 0.32, 0.4, 0.9), false, 1.0)


func _apply_death_visual_state() -> void:
	## 切换死亡视觉；阵亡队友整体灰化降透明度，复活协议当前不存在，仅撤离或重开恢复。
	if _remote_is_dead:
		modulate = Color(0.55, 0.55, 0.55, 0.45)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
