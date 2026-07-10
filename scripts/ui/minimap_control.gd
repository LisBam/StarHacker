extends Control

## 小地图控件以 GameWorld 提供的地图边界和障碍矩形为数据源。
## 当前显示玩家、墙体/建筑和已标记撤离点，不显示怪物，避免训练场怪物数量变化干扰地图结构观察。

## 局部小地图模式；默认用于右上角 HUD，只显示玩家周围一段范围。
const DISPLAY_MODE_LOCAL: int = 0
## 完整大地图模式；默认用于 M 键地图，显示整张地图并叠加探索迷雾。
const DISPLAY_MODE_FULL: int = 1

## 游戏世界节点路径；默认从 BattleHUD/Root/MiniMap 回到 GameWorld，修改会影响地图边界和障碍数据来源。
@export var game_world_path: NodePath = ^"../../.."
## 玩家节点路径；默认从 BattleHUD/Root/MiniMap 指向 GameWorld/Player，修改会影响玩家点显示位置。
@export var player_path: NodePath = ^"../../../Player"
## 地图显示模式；0 为玩家周围局部范围，1 为整张地图，默认 0 用于 HUD 小地图。
@export_enum("局部", "完整") var display_mode: int = DISPLAY_MODE_LOCAL
## 局部小地图半径；取值应大于 0，默认 1200 像素，修改会影响右上角小地图能看到的玩家周围范围。
@export_range(128.0, 6000.0, 1.0, "or_greater") var local_view_radius: float = 1200.0
## 局部小地图重绘间隔；取值建议 0.05 到 0.25 秒，默认 0.12 秒，用于降低每帧重画障碍带来的 UI 开销。
@export_range(0.02, 2.0, 0.01) var local_redraw_interval: float = 0.12
## 完整大地图重绘间隔；取值建议 0.1 到 0.5 秒，默认 0.25 秒，用于降低大地图迷雾重绘频率。
@export_range(0.02, 2.0, 0.01) var full_redraw_interval: float = 0.25
## 玩家移动触发重绘距离；取值建议 8 到 64 像素，默认 24 像素，玩家移动超过该距离会提前刷新地图。
@export_range(0.0, 512.0, 1.0) var redraw_player_move_distance: float = 24.0
## 无法读取 GameWorld 时的小地图半边长；取值应大于 0，默认 6144 对应 grid_size 64 和 grid_extent 96。
@export_range(1.0, 99999.0, 1.0, "or_greater") var fallback_map_half_size: float = 6144.0
## 小地图背景颜色；默认深色半透明，修改会影响小地图底色。
@export var minimap_background_color: Color = Color(0.015, 0.02, 0.027, 0.82)
## 小地图边框颜色；默认青蓝半透明，修改会影响边界识别。
@export var minimap_border_color: Color = Color(0.55, 0.82, 0.92, 0.75)
## 小地图障碍颜色；默认浅蓝灰，修改会影响墙体和建筑可见度。
@export var obstacle_color: Color = Color(0.54, 0.72, 0.78, 0.85)
## 大地图迷雾颜色；默认半透明黑色滤镜，修改会影响未探索区域被遮挡的强度。
@export var fog_overlay_color: Color = Color(0.0, 0.0, 0.0, 0.58)
## 小地图玩家颜色；默认亮青色，修改会影响玩家点可见度。
@export var player_color: Color = Color(0.34, 0.93, 1.0, 1.0)
## 撤离点标记颜色；默认亮绿色，只有 GameWorld 标记撤离点后才绘制。
@export var extraction_marker_color: Color = Color(0.35, 1.0, 0.72, 1.0)
## 物资撤离点标记颜色；默认亮金色，开局生成后始终显示并与正式撤离点区分。
## 探索显示补充：点位虽然开局生成，但只有所在探索格被发现后才会实际绘制。
@export var supply_extraction_marker_color: Color = Color(1.0, 0.72, 0.22, 1.0)
## 玩家点半径；取值建议大于 0，默认 4 像素，修改会影响小地图上玩家标记大小。
@export_range(1.0, 20.0, 0.5) var player_marker_radius: float = 4.0
## 撤离点标记半径；取值建议大于玩家点半径，默认 6 像素，修改会影响地图上撤离点识别度。
@export_range(2.0, 32.0, 0.5) var extraction_marker_radius: float = 6.0
## 玩家导航标点颜色；默认柔和绿色，大小地图共同使用以降低指引线对战斗画面的突兀感。
@export var navigation_marker_color: Color = Color(0.30, 0.92, 0.48, 0.92)
## 玩家导航指示线宽度；默认 2 像素，从玩家点持续连接到标点或局部小地图边缘。
@export_range(0.5, 12.0, 0.5) var navigation_line_width: float = 2.0
## 玩家导航虚线单段长度；默认 10 像素，数值越大每段绿色指引线越长。
@export_range(1.0, 64.0, 1.0) var navigation_dash_length: float = 10.0
## 玩家导航虚线间隔长度；默认 7 像素，数值越大相邻指引线段之间留白越明显。
@export_range(1.0, 64.0, 1.0) var navigation_dash_gap: float = 7.0
## 玩家导航标点半径；默认 7 像素，用于绘制圆环和十字标记。
@export_range(2.0, 32.0, 0.5) var navigation_marker_radius: float = 7.0
## 大地图点击已有标点的取消半径；默认 16 像素，左键点中标点时清除而不是重新设置。
@export_range(2.0, 64.0, 1.0) var navigation_marker_cancel_radius: float = 16.0
## 是否允许鼠标设置导航标点；默认 true，M 键大地图开启，暂停菜单地图可在场景中关闭。
@export var allow_navigation_marker_input: bool = true

## 小地图重绘剩余时间；取值大于等于 0，默认 0 表示下一帧可根据状态触发重绘。
var _redraw_remaining: float = 0.0
## 缓存障碍矩形列表；元素为世界坐标 Rect2，默认只在 GameWorld 障碍版本变化时更新。
var _cached_obstacle_rects: Array[Rect2] = []
## 缓存障碍版本号；取值来自 GameWorld，默认 -1 表示尚未拉取障碍数据。
var _cached_obstacle_version: int = -1
## 是否已经初始化障碍缓存；取值为 true/false，默认 false 用于首次强制拉取地图障碍。
var _has_obstacle_cache: bool = false
## 缓存探索格查询表；键为 Vector2i，值为 true，默认只在完整大地图绘制迷雾时使用。
var _cached_explored_lookup: Dictionary = {}
## 缓存探索格版本号；取值来自 GameWorld，默认 -1 表示尚未拉取探索数据。
var _cached_explored_version: int = -1
## 是否已经初始化探索缓存；取值为 true/false，默认 false 用于首次打开大地图时构建迷雾查询。
var _has_explored_cache: bool = false
## 上次请求重绘时的玩家位置；取值为世界坐标，默认零向量，仅在 _has_last_redraw_player_position 为 true 时有效。
var _last_redraw_player_position: Vector2 = Vector2.ZERO
## 是否已有上次重绘玩家位置；取值为 true/false，默认 false 用于首次强制重绘。
var _has_last_redraw_player_position: bool = false
## 上次请求重绘时撤离点是否可见；取值为 true/false，默认 false，用于撤离点标记出现时立即刷新。
var _last_redraw_extraction_visible: bool = false
## 上次请求重绘时撤离点位置；取值为世界坐标，默认零向量，用于撤离点位置变化时刷新地图。
var _last_redraw_extraction_position: Vector2 = Vector2.ZERO
## 上次请求重绘时控件尺寸；取值为 Control.size，默认零向量，用于窗口或布局变化时刷新地图。
var _last_redraw_size: Vector2 = Vector2.ZERO
## 上次请求重绘时是否存在导航标点；默认 false，用于标点创建或取消后立即刷新大小地图。
var _last_redraw_navigation_marker_visible: bool = false
## 上次请求重绘时导航标点位置；默认零向量，用于标点移动后立即刷新指示线。
var _last_redraw_navigation_marker_position: Vector2 = Vector2.ZERO

## 游戏世界节点缓存；默认按 game_world_path 获取，允许为空并使用兜底地图尺寸。
@onready var _game_world: Node = get_node_or_null(game_world_path)
## 玩家节点缓存；默认按 player_path 获取，允许为空并跳过玩家点绘制。
@onready var _player: Node2D = get_node_or_null(player_path) as Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if display_mode == DISPLAY_MODE_FULL and allow_navigation_marker_input else Control.MOUSE_FILTER_IGNORE
	if display_mode == DISPLAY_MODE_FULL and allow_navigation_marker_input:
		gui_input.connect(_on_map_gui_input)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	_redraw_remaining = maxf(_redraw_remaining - maxf(delta, 0.0), 0.0)
	# 地图结构是否变化；取值为 true/false，默认用于障碍或探索缓存变化后立即重绘。
	var map_cache_changed: bool = _refresh_obstacle_cache_if_needed()
	# 两种地图模式都刷新探索缓存，物资撤离点只有被玩家发现后才允许显示。
	map_cache_changed = _refresh_explored_cache_if_needed() or map_cache_changed

	if map_cache_changed or _should_redraw_map():
		_remember_redraw_state()
		_redraw_remaining = _get_redraw_interval()
		queue_redraw()


func _draw() -> void:
	# 小地图绘制区域；取值为控件本地矩形，默认覆盖整个 Control。
	var minimap_rect: Rect2 = Rect2(Vector2.ZERO, size)
	# 当前世界可视区域；取值由显示模式决定，默认局部模式跟随玩家。
	var world_view_rect: Rect2 = _get_current_world_view_rect()
	draw_rect(minimap_rect, minimap_background_color, true)
	_draw_obstacles(world_view_rect)
	_draw_fog(world_view_rect)
	_draw_extraction_marker(world_view_rect)
	_draw_supply_extraction_markers(world_view_rect)
	_draw_navigation_marker(world_view_rect)
	_draw_player_marker(world_view_rect)
	draw_rect(minimap_rect, minimap_border_color, false, 2.0)


func _draw_obstacles(world_view_rect: Rect2) -> void:
	# 障碍矩形列表；取值来自 GameWorld，默认只包含墙体和建筑，不包含怪物。
	var obstacle_rects: Array[Rect2] = _get_obstacle_rects()
	# 障碍矩形遍历项；取值为世界坐标 Rect2，默认逐项转换为小地图本地矩形。
	for obstacle_rect in obstacle_rects:
		if not obstacle_rect.intersects(world_view_rect):
			continue

		# 局部可见障碍矩形；取值为障碍和当前视野的交集，默认避免绘制范围外结构。
		var visible_obstacle_rect: Rect2 = obstacle_rect.intersection(world_view_rect)
		# 小地图矩形；取值为障碍世界矩形映射后的本地 Rect2，默认用于绘制墙体和建筑。
		var minimap_obstacle_rect: Rect2 = _world_rect_to_minimap_rect(visible_obstacle_rect, world_view_rect)
		draw_rect(minimap_obstacle_rect, obstacle_color, true)


func _draw_fog(world_view_rect: Rect2) -> void:
	if display_mode != DISPLAY_MODE_FULL:
		return

	# 探索格子尺寸；取值来自 GameWorld 或兜底值，默认用于把迷雾拆成稳定网格。
	var cell_size: float = _get_exploration_cell_size()
	# 已探索格查询表；键为 Vector2i，默认让大地图快速判断哪些格子不需要迷雾。
	var explored_lookup: Dictionary = _get_explored_cell_lookup()
	# 起始 X 格；取值为当前世界视野左边界所在格，默认覆盖完整大地图。
	var start_cell_x: int = floori(world_view_rect.position.x / cell_size)
	# 结束 X 格；取值为当前世界视野右边界所在格，默认覆盖完整大地图。
	var end_cell_x: int = ceili(world_view_rect.end.x / cell_size) - 1
	# 起始 Y 格；取值为当前世界视野上边界所在格，默认覆盖完整大地图。
	var start_cell_y: int = floori(world_view_rect.position.y / cell_size)
	# 结束 Y 格；取值为当前世界视野下边界所在格，默认覆盖完整大地图。
	var end_cell_y: int = ceili(world_view_rect.end.y / cell_size) - 1

	# 迷雾 X 格遍历；取值为当前大地图视野覆盖范围，默认逐列绘制未探索滤镜。
	for cell_x in range(start_cell_x, end_cell_x + 1):
		# 迷雾 Y 格遍历；取值为当前大地图视野覆盖范围，默认逐行绘制未探索滤镜。
		for cell_y in range(start_cell_y, end_cell_y + 1):
			# 当前迷雾格坐标；取值为 Vector2i，默认用于查询是否已经探索。
			var current_cell: Vector2i = Vector2i(cell_x, cell_y)
			if explored_lookup.has(current_cell):
				continue

			# 当前迷雾世界矩形；取值为探索格对应世界范围，默认用于映射到大地图控件。
			var fog_world_rect: Rect2 = Rect2(Vector2(float(cell_x) * cell_size, float(cell_y) * cell_size), Vector2(cell_size, cell_size))
			# 当前可见迷雾矩形；取值为迷雾格和大地图视野交集，默认避免边缘溢出。
			var visible_fog_rect: Rect2 = fog_world_rect.intersection(world_view_rect)
			# 当前迷雾本地矩形；取值为世界迷雾矩形映射到控件后的结果，默认用于绘制滤镜。
			var minimap_fog_rect: Rect2 = _world_rect_to_minimap_rect(visible_fog_rect, world_view_rect)
			draw_rect(minimap_fog_rect, fog_overlay_color, true)


func _draw_player_marker(world_view_rect: Rect2) -> void:
	if _player == null:
		return

	# 玩家小地图坐标；取值为玩家全局坐标映射到控件本地空间，默认用于绘制玩家圆点。
	var player_position: Vector2 = _world_position_to_minimap_position(_player.global_position, world_view_rect)
	draw_circle(player_position, player_marker_radius, player_color)


func _draw_extraction_marker(world_view_rect: Rect2) -> void:
	if not _is_extraction_marker_visible():
		return

	# 撤离点世界坐标；取值来自 GameWorld，默认只在地图标记时间到达后使用。
	var extraction_position: Vector2 = _get_extraction_marker_position()
	if not world_view_rect.has_point(extraction_position):
		return

	# 撤离点小地图坐标；取值为撤离点世界坐标映射到控件本地空间。
	var marker_position: Vector2 = _world_position_to_minimap_position(extraction_position, world_view_rect)
	# 标记半径；取值至少为 2，默认让撤离点比玩家点更易识别。
	var marker_radius: float = maxf(extraction_marker_radius, 2.0)
	draw_circle(marker_position, marker_radius, extraction_marker_color)
	draw_line(marker_position + Vector2(-marker_radius * 1.7, 0.0), marker_position + Vector2(marker_radius * 1.7, 0.0), extraction_marker_color, 2.0)
	draw_line(marker_position + Vector2(0.0, -marker_radius * 1.7), marker_position + Vector2(0.0, marker_radius * 1.7), extraction_marker_color, 2.0)


func _draw_supply_extraction_markers(world_view_rect: Rect2) -> void:
	if _game_world == null or not _game_world.has_method("get_supply_extraction_positions"):
		return
	# 物资撤离点列表；局部地图只绘制视野内点位，完整地图显示全部 2 至 5 个金色标记。
	var raw_positions: Array = _game_world.call("get_supply_extraction_positions")
	for raw_position in raw_positions:
		if not (raw_position is Vector2):
			continue
		# 物资撤离点世界坐标；只接收 GameWorld 返回的 Vector2 项。
		var supply_position: Vector2 = raw_position
		if not _is_world_position_discovered(supply_position):
			continue
		if not world_view_rect.has_point(supply_position):
			continue
		# 物资撤离点小地图坐标；完整地图显示全部点位，局部地图只显示范围内点位。
		# 探索规则补充：进入坐标映射前已过滤未发现点位，因此“全部”仅指全部已发现点位。
		var marker_position: Vector2 = _world_position_to_minimap_position(supply_position, world_view_rect)
		# 方形标记半径；略小于正式撤离点圆形标记，颜色和形状共同区分用途。
		var marker_radius: float = maxf(extraction_marker_radius - 1.0, 2.0)
		draw_rect(Rect2(marker_position - Vector2.ONE * marker_radius, Vector2.ONE * marker_radius * 2.0), supply_extraction_marker_color, false, 2.0)


func _is_world_position_discovered(world_position: Vector2) -> bool:
	if _game_world != null and _game_world.has_method("is_world_position_explored"):
		return bool(_game_world.call("is_world_position_explored", world_position))
	# 兼容接口缺失的临时场景；使用本地探索格缓存判断，不默认泄露未知点位。
	var cell_size: float = _get_exploration_cell_size()
	var exploration_cell: Vector2i = Vector2i(floori(world_position.x / cell_size), floori(world_position.y / cell_size))
	return _get_explored_cell_lookup().has(exploration_cell)


func _draw_navigation_marker(world_view_rect: Rect2) -> void:
	if not _has_navigation_marker() or _player == null:
		return

	# 导航标点世界坐标；取值来自 GameWorld，局部小地图范围外坐标会映射到边缘形成方向指示。
	var marker_world_position: Vector2 = _get_navigation_marker_position()
	# 玩家地图坐标；取值为当前玩家世界位置映射结果，用于指示线起点。
	var player_map_position: Vector2 = _world_position_to_minimap_position(_player.global_position, world_view_rect)
	# 标点地图坐标；取值为世界标点映射结果，局部模式超出范围时自动夹在边缘。
	var marker_map_position: Vector2 = _world_position_to_minimap_position(marker_world_position, world_view_rect)
	_draw_dashed_navigation_line(player_map_position, marker_map_position)
	# 标点半径；取值至少 2，用于绘制稳定圆环和十字。
	var marker_radius: float = maxf(navigation_marker_radius, 2.0)
	draw_circle(marker_map_position, marker_radius, Color(navigation_marker_color, 0.22))
	draw_arc(marker_map_position, marker_radius, 0.0, TAU, 24, navigation_marker_color, 2.0, true)
	draw_line(marker_map_position + Vector2(-marker_radius * 1.35, 0.0), marker_map_position + Vector2(marker_radius * 1.35, 0.0), navigation_marker_color, 2.0)
	draw_line(marker_map_position + Vector2(0.0, -marker_radius * 1.35), marker_map_position + Vector2(0.0, marker_radius * 1.35), navigation_marker_color, 2.0)


func _draw_dashed_navigation_line(start_position: Vector2, end_position: Vector2) -> void:
	# 完整指引向量；取值为玩家地图坐标指向导航标点，用于计算虚线方向和总长度。
	var line_vector: Vector2 = end_position - start_position
	# 完整指引长度；小于等于 0 时不绘制，避免归一化零向量。
	var line_length: float = line_vector.length()
	if line_length <= 0.0:
		return
	# 虚线单位方向；用于按累计距离计算每一段的起点和终点。
	var line_direction: Vector2 = line_vector / line_length
	# 标准化单段长度；至少 1 像素，避免错误配置导致循环无法推进。
	var dash_length: float = maxf(navigation_dash_length, 1.0)
	# 标准化间隔长度；至少 1 像素，使绿色指引始终保持虚线表现。
	var dash_gap: float = maxf(navigation_dash_gap, 1.0)
	# 当前虚线累计距离；默认从玩家位置开始，按线段长度和间隔逐段推进。
	var current_distance: float = 0.0
	while current_distance < line_length:
		# 当前线段结束距离；限制到完整指引长度，避免最后一段越过标点。
		var dash_end_distance: float = minf(current_distance + dash_length, line_length)
		draw_line(start_position + line_direction * current_distance, start_position + line_direction * dash_end_distance, navigation_marker_color, navigation_line_width, true)
		current_distance += dash_length + dash_gap


func _should_redraw_map() -> bool:
	if not _has_last_redraw_player_position:
		return true

	if _last_redraw_size != size:
		return true

	# 当前撤离点可见状态；取值来自 GameWorld，默认用于标记出现或消失时立即刷新地图。
	var extraction_visible: bool = _is_extraction_marker_visible()
	if extraction_visible != _last_redraw_extraction_visible:
		return true

	if extraction_visible and _get_extraction_marker_position() != _last_redraw_extraction_position:
		return true

	# 当前导航标点可见状态；取值来自 GameWorld，用于创建或取消标点时立即刷新。
	var navigation_marker_visible: bool = _has_navigation_marker()
	if navigation_marker_visible != _last_redraw_navigation_marker_visible:
		return true
	if navigation_marker_visible and _get_navigation_marker_position() != _last_redraw_navigation_marker_position:
		return true

	if _player != null:
		# 玩家移动阈值；取值至少为 0，默认移动超过阈值时提前刷新局部地图和玩家点。
		var move_distance: float = maxf(redraw_player_move_distance, 0.0)
		if move_distance <= 0.0 or _player.global_position.distance_to(_last_redraw_player_position) >= move_distance:
			return true

	return _redraw_remaining <= 0.0


func _remember_redraw_state() -> void:
	_has_last_redraw_player_position = true
	_last_redraw_player_position = _player.global_position if _player != null else Vector2.ZERO
	_last_redraw_extraction_visible = _is_extraction_marker_visible()
	_last_redraw_extraction_position = _get_extraction_marker_position() if _last_redraw_extraction_visible else Vector2.ZERO
	_last_redraw_navigation_marker_visible = _has_navigation_marker()
	_last_redraw_navigation_marker_position = _get_navigation_marker_position() if _last_redraw_navigation_marker_visible else Vector2.ZERO
	_last_redraw_size = size


func _get_redraw_interval() -> float:
	if display_mode == DISPLAY_MODE_FULL:
		return maxf(full_redraw_interval, 0.02)

	return maxf(local_redraw_interval, 0.02)


func _refresh_obstacle_cache_if_needed() -> bool:
	if _game_world == null or not _game_world.has_method("get_minimap_obstacle_rects"):
		if _has_obstacle_cache and _cached_obstacle_rects.is_empty():
			return false

		_cached_obstacle_rects.clear()
		_cached_obstacle_version = -1
		_has_obstacle_cache = true
		return true

	# 当前障碍版本号；取值来自 GameWorld，缺少版本接口时使用 0 并只拉取一次。
	var obstacle_version: int = 0
	if _game_world.has_method("get_minimap_obstacle_version"):
		obstacle_version = int(_game_world.call("get_minimap_obstacle_version"))
	if _has_obstacle_cache and obstacle_version == _cached_obstacle_version:
		return false

	# 原始障碍列表；取值来自 GameWorld 动态调用，默认只在版本变化时整理为强类型缓存。
	var raw_rects: Array = _game_world.call("get_minimap_obstacle_rects")
	_cached_obstacle_rects.clear()
	# 原始障碍遍历项；取值可能为任意 Variant，默认只接收 Rect2。
	for raw_rect in raw_rects:
		if raw_rect is Rect2:
			_cached_obstacle_rects.append(raw_rect)

	_cached_obstacle_version = obstacle_version
	_has_obstacle_cache = true
	return true


func _refresh_explored_cache_if_needed() -> bool:
	if _game_world == null or not _game_world.has_method("get_explored_cells"):
		if _has_explored_cache and _cached_explored_lookup.is_empty():
			return false

		_cached_explored_lookup.clear()
		_cached_explored_version = -1
		_has_explored_cache = true
		return true

	# 当前探索版本号；取值来自 GameWorld，缺少版本接口时使用 0 并只拉取一次。
	var explored_version: int = 0
	if _game_world.has_method("get_explored_cells_version"):
		explored_version = int(_game_world.call("get_explored_cells_version"))
	if _has_explored_cache and explored_version == _cached_explored_version:
		return false

	# 原始探索格列表；取值来自 GameWorld 动态调用，默认整理为字典查询表。
	var raw_cells: Array = _game_world.call("get_explored_cells")
	_cached_explored_lookup.clear()
	# 原始探索格遍历项；取值可能为任意 Variant，默认只接收 Vector2i。
	for raw_cell in raw_cells:
		if raw_cell is Vector2i:
			_cached_explored_lookup[raw_cell] = true

	_cached_explored_version = explored_version
	_has_explored_cache = true
	return true


func _get_obstacle_rects() -> Array[Rect2]:
	if not _has_obstacle_cache:
		_refresh_obstacle_cache_if_needed()

	return _cached_obstacle_rects


func _is_extraction_marker_visible() -> bool:
	if _game_world == null or not _game_world.has_method("is_extraction_point_marked_on_map"):
		return false

	return bool(_game_world.call("is_extraction_point_marked_on_map"))


func _get_extraction_marker_position() -> Vector2:
	if _game_world == null or not _game_world.has_method("get_extraction_point_position"):
		return Vector2.ZERO

	# 原始撤离点位置；取值可能为 Variant，默认只接收 Vector2。
	var raw_position: Variant = _game_world.call("get_extraction_point_position")
	if raw_position is Vector2:
		return raw_position

	return Vector2.ZERO


func _has_navigation_marker() -> bool:
	return _game_world != null and _game_world.has_method("has_navigation_marker") and bool(_game_world.call("has_navigation_marker"))


func _get_navigation_marker_position() -> Vector2:
	if _game_world == null or not _game_world.has_method("get_navigation_marker_position"):
		return Vector2.ZERO
	# 导航标点原始位置；取值可能为任意 Variant，默认只接收 Vector2。
	var raw_position: Variant = _game_world.call("get_navigation_marker_position")
	return raw_position if raw_position is Vector2 else Vector2.ZERO


func _on_map_gui_input(event: InputEvent) -> void:
	if display_mode != DISPLAY_MODE_FULL or not allow_navigation_marker_input or _game_world == null or not (event is InputEventMouseButton):
		return
	# 地图鼠标事件；取值为完整地图上的鼠标按钮输入，只处理左键按下。
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	# 完整地图世界范围；取值由 GameWorld 地图边界决定，用于把点击位置转换为世界坐标。
	var world_view_rect: Rect2 = _get_current_world_view_rect()
	if _has_navigation_marker():
		# 已有标点本地位置；取值为当前标点映射坐标，用于判定点击是否命中取消范围。
		var current_marker_local_position: Vector2 = _world_position_to_minimap_position(_get_navigation_marker_position(), world_view_rect)
		if current_marker_local_position.distance_to(mouse_event.position) <= navigation_marker_cancel_radius:
			if _game_world.has_method("clear_navigation_marker"):
				_game_world.call("clear_navigation_marker")
			queue_redraw()
			accept_event()
			return

	# 点击世界位置；取值为大地图本地坐标反向映射结果，新标点会替换旧标点，始终最多保留一个。
	var clicked_world_position: Vector2 = _minimap_position_to_world_position(mouse_event.position, world_view_rect)
	if _game_world.has_method("set_navigation_marker"):
		_game_world.call("set_navigation_marker", clicked_world_position)
	queue_redraw()
	accept_event()


func _get_explored_cell_lookup() -> Dictionary:
	if not _has_explored_cache:
		_refresh_explored_cache_if_needed()

	return _cached_explored_lookup


func _world_rect_to_minimap_rect(world_rect: Rect2, world_view_rect: Rect2) -> Rect2:
	# 障碍左上角小地图坐标；取值由世界矩形 position 映射，默认用于构建本地矩形。
	var minimap_start: Vector2 = _world_position_to_minimap_position(world_rect.position, world_view_rect)
	# 障碍右下角小地图坐标；取值由世界矩形 end 映射，默认用于构建本地矩形。
	var minimap_end: Vector2 = _world_position_to_minimap_position(world_rect.end, world_view_rect)
	# 小地图矩形位置；取值为两个映射点的最小坐标，默认支持坐标反转时仍正确绘制。
	var minimap_position: Vector2 = minimap_start.min(minimap_end)
	# 小地图矩形尺寸；取值为两个映射点差值绝对值，默认用于绘制障碍块。
	var minimap_size: Vector2 = (minimap_end - minimap_start).abs()
	return Rect2(minimap_position, minimap_size)


func _world_position_to_minimap_position(world_position: Vector2, world_view_rect: Rect2) -> Vector2:
	# 视野尺寸；取值至少为 1x1，默认防止配置错误导致除零。
	var view_size: Vector2 = Vector2(maxf(world_view_rect.size.x, 1.0), maxf(world_view_rect.size.y, 1.0))
	# 标准化坐标；取值通常在 0 到 1，默认超出视野时会被夹取到地图边缘。
	var normalized_position: Vector2 = (world_position - world_view_rect.position) / view_size
	normalized_position.x = clampf(normalized_position.x, 0.0, 1.0)
	normalized_position.y = clampf(normalized_position.y, 0.0, 1.0)
	return Vector2(normalized_position.x * size.x, normalized_position.y * size.y)


func _minimap_position_to_world_position(minimap_position: Vector2, world_view_rect: Rect2) -> Vector2:
	# 控件有效尺寸；取值至少 1x1，防止布局初始化期间除零。
	var control_size: Vector2 = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	# 标准化点击坐标；取值限制到 0 到 1，避免边缘点击映射到地图外。
	var normalized_position: Vector2 = Vector2(
		clampf(minimap_position.x / control_size.x, 0.0, 1.0),
		clampf(minimap_position.y / control_size.y, 0.0, 1.0)
	)
	return world_view_rect.position + normalized_position * world_view_rect.size


func _get_current_world_view_rect() -> Rect2:
	if display_mode == DISPLAY_MODE_LOCAL and _player != null:
		# 局部视野半径；取值至少 1，默认由 local_view_radius 决定玩家周围显示范围。
		var local_radius: float = maxf(local_view_radius, 1.0)
		# 局部视野尺寸；取值为半径两倍，默认形成以玩家为中心的正方形地图区域。
		var local_size: Vector2 = Vector2(local_radius * 2.0, local_radius * 2.0)
		return Rect2(_player.global_position - local_size * 0.5, local_size)

	# 地图半边长；取值来自 GameWorld 或 fallback_map_half_size，默认用于完整大地图范围。
	var half_size: float = _get_map_half_size()
	# 地图完整尺寸；取值为半边长两倍，默认与 GameWorld 绘制区域一致。
	var map_size: Vector2 = Vector2(half_size * 2.0, half_size * 2.0)
	return Rect2(Vector2(-half_size, -half_size), map_size)


func _get_map_half_size() -> float:
	if _game_world != null and _game_world.has_method("get_map_half_size"):
		return maxf(float(_game_world.call("get_map_half_size")), 1.0)

	return maxf(fallback_map_half_size, 1.0)


func _get_exploration_cell_size() -> float:
	if _game_world != null and _game_world.has_method("get_exploration_cell_size"):
		return maxf(float(_game_world.call("get_exploration_cell_size")), 1.0)

	return 256.0
