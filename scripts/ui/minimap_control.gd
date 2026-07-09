extends Control

## 小地图控件以 GameWorld 提供的地图边界和障碍矩形为数据源。
## 当前只显示玩家与墙体/建筑，不显示怪物，避免训练场怪物数量变化干扰地图结构观察。

## 游戏世界节点路径；默认从 BattleHUD/Root/MiniMap 回到 GameWorld，修改会影响地图边界和障碍数据来源。
@export var game_world_path: NodePath = ^"../../.."
## 玩家节点路径；默认从 BattleHUD/Root/MiniMap 指向 GameWorld/Player，修改会影响玩家点显示位置。
@export var player_path: NodePath = ^"../../../Player"
## 无法读取 GameWorld 时的小地图半边长；取值应大于 0，默认 6144 对应 grid_size 64 和 grid_extent 96。
@export_range(1.0, 99999.0, 1.0, "or_greater") var fallback_map_half_size: float = 6144.0
## 小地图背景颜色；默认深色半透明，修改会影响小地图底色。
@export var minimap_background_color: Color = Color(0.015, 0.02, 0.027, 0.82)
## 小地图边框颜色；默认青蓝半透明，修改会影响边界识别。
@export var minimap_border_color: Color = Color(0.55, 0.82, 0.92, 0.75)
## 小地图障碍颜色；默认浅蓝灰，修改会影响墙体和建筑可见度。
@export var obstacle_color: Color = Color(0.54, 0.72, 0.78, 0.85)
## 小地图玩家颜色；默认亮青色，修改会影响玩家点可见度。
@export var player_color: Color = Color(0.34, 0.93, 1.0, 1.0)
## 玩家点半径；取值建议大于 0，默认 4 像素，修改会影响小地图上玩家标记大小。
@export_range(1.0, 20.0, 0.5) var player_marker_radius: float = 4.0

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
	draw_rect(minimap_rect, minimap_background_color, true)
	draw_rect(minimap_rect, minimap_border_color, false, 2.0)
	_draw_obstacles()
	_draw_player_marker()


func _draw_obstacles() -> void:
	# 障碍矩形列表；取值来自 GameWorld，默认只包含墙体和建筑，不包含怪物。
	var obstacle_rects: Array[Rect2] = _get_obstacle_rects()
	# 障碍矩形遍历项；取值为世界坐标 Rect2，默认逐项转换为小地图本地矩形。
	for obstacle_rect in obstacle_rects:
		# 小地图矩形；取值为障碍世界矩形映射后的本地 Rect2，默认用于绘制墙体和建筑。
		var minimap_obstacle_rect: Rect2 = _world_rect_to_minimap_rect(obstacle_rect)
		draw_rect(minimap_obstacle_rect, obstacle_color, true)


func _draw_player_marker() -> void:
	if _player == null:
		return

	# 玩家小地图坐标；取值为玩家全局坐标映射到控件本地空间，默认用于绘制玩家圆点。
	var player_position: Vector2 = _world_position_to_minimap_position(_player.global_position)
	draw_circle(player_position, player_marker_radius, player_color)


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


func _world_rect_to_minimap_rect(world_rect: Rect2) -> Rect2:
	# 障碍左上角小地图坐标；取值由世界矩形 position 映射，默认用于构建本地矩形。
	var minimap_start: Vector2 = _world_position_to_minimap_position(world_rect.position)
	# 障碍右下角小地图坐标；取值由世界矩形 end 映射，默认用于构建本地矩形。
	var minimap_end: Vector2 = _world_position_to_minimap_position(world_rect.end)
	# 小地图矩形位置；取值为两个映射点的最小坐标，默认支持坐标反转时仍正确绘制。
	var minimap_position: Vector2 = minimap_start.min(minimap_end)
	# 小地图矩形尺寸；取值为两个映射点差值绝对值，默认用于绘制障碍块。
	var minimap_size: Vector2 = (minimap_end - minimap_start).abs()
	return Rect2(minimap_position, minimap_size)


func _world_position_to_minimap_position(world_position: Vector2) -> Vector2:
	# 地图半边长；取值来自 GameWorld 或 fallback_map_half_size，默认用于归一化世界坐标。
	var half_size: float = _get_map_half_size()
	# 地图完整尺寸；取值至少为 1，默认防止配置错误导致除零。
	var map_size: float = maxf(half_size * 2.0, 1.0)
	# 标准化坐标；取值通常在 0 到 1，默认超出地图时会被夹取到小地图边缘。
	var normalized_position: Vector2 = (world_position + Vector2(half_size, half_size)) / map_size
	normalized_position.x = clampf(normalized_position.x, 0.0, 1.0)
	normalized_position.y = clampf(normalized_position.y, 0.0, 1.0)
	return Vector2(normalized_position.x * size.x, normalized_position.y * size.y)


func _get_map_half_size() -> float:
	if _game_world != null and _game_world.has_method("get_map_half_size"):
		return maxf(float(_game_world.call("get_map_half_size")), 1.0)

	return maxf(fallback_map_half_size, 1.0)
