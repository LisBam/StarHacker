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
## 玩家点半径；取值建议大于 0，默认 4 像素，修改会影响小地图上玩家标记大小。
@export_range(1.0, 20.0, 0.5) var player_marker_radius: float = 4.0
## 撤离点标记半径；取值建议大于玩家点半径，默认 6 像素，修改会影响地图上撤离点识别度。
@export_range(2.0, 32.0, 0.5) var extraction_marker_radius: float = 6.0

## 游戏世界节点缓存；默认按 game_world_path 获取，允许为空并使用兜底地图尺寸。
@onready var _game_world: Node = get_node_or_null(game_world_path)
## 玩家节点缓存；默认按 player_path 获取，允许为空并跳过玩家点绘制。
@onready var _player: Node2D = get_node_or_null(player_path) as Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
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


func _get_obstacle_rects() -> Array[Rect2]:
	if _game_world == null or not _game_world.has_method("get_minimap_obstacle_rects"):
		# 空障碍列表；取值为空数组，默认用于 GameWorld 缺失时跳过障碍绘制。
		var empty_result: Array[Rect2] = []
		return empty_result

	# 原始障碍列表；取值来自 GameWorld 动态调用，默认需要重新整理为强类型数组。
	var raw_rects: Array = _game_world.call("get_minimap_obstacle_rects")
	# 强类型障碍列表；元素为 Rect2，默认用于满足小地图绘制接口类型。
	var result: Array[Rect2] = []
	# 原始障碍遍历项；取值可能为任意 Variant，默认只接收 Rect2。
	for raw_rect in raw_rects:
		if raw_rect is Rect2:
			result.append(raw_rect)

	return result


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


func _get_explored_cell_lookup() -> Dictionary:
	# 已探索查询表；键为探索格 Vector2i，值为 true，默认用于大地图迷雾快速判断。
	var result: Dictionary = {}
	if _game_world == null or not _game_world.has_method("get_explored_cells"):
		return result

	# 原始探索格列表；取值来自 GameWorld 动态调用，默认整理为字典查询表。
	var raw_cells: Array = _game_world.call("get_explored_cells")
	# 原始探索格遍历项；取值可能为任意 Variant，默认只接收 Vector2i。
	for raw_cell in raw_cells:
		if raw_cell is Vector2i:
			result[raw_cell] = true

	return result


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
