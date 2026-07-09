extends Node2D

## 随机生成怪物组名；默认所有随机生成怪物都会加入该组，修改会影响清怪兜底范围。
const TRAINING_MONSTER_GROUP: StringName = &"training_monsters"
## 正式骇入模式标识；默认与 SessionState 保持一致，修改会影响暂停菜单训练场功能是否隐藏。
const GAME_MODE_HACK: String = "hack"
## 训练场模式标识；默认与 SessionState 保持一致，修改会影响训练场专属功能是否开启。
const GAME_MODE_TRAINING: String = "training"
## 星角色标识；默认与主菜单角色选择保持一致，修改会影响角色属性随机分支。
const CHARACTER_STELLE: String = "stelle"
## 穹角色标识；默认与主菜单角色选择保持一致，修改会影响角色属性随机分支。
const CHARACTER_CAEULUS: String = "caelus"
## 银狼角色标识；默认与主菜单角色选择保持一致，修改会影响角色属性随机分支。
const CHARACTER_SILVER_WOLF: String = "silver_wolf"

## 游戏世界场景负责提供当前关卡的基础承载环境。
## 玩家、敌人、掉落物、地图装饰都可以作为它的子节点存在。
## 进入战斗场景时会生成一张大型网格地图，并在地图上随机摆放墙体、建筑和怪物。

## 调试网格单格尺寸；取值应大于 0，默认 64 匹配常见 2D 地图尺度，运行时修改会改变距离参照密度。
@export var grid_size: float = 64.0
## 网格地图向每个方向延伸的格数；取值应为正整数，默认 96 生成 192x192 格大型战斗地图，运行时修改会改变地图尺寸。
@export var grid_extent: int = 96
## 地图边框颜色；取值为 RGBA，默认更亮用于定位网格地图边界，运行时修改会影响边界识别。
@export var axis_color: Color = Color(0.28, 0.52, 0.72, 0.62)
## 地图随机种子；默认 0 表示每次进入战斗场景随机生成，设置为正数可复现同一张地图。
@export var map_seed: int = 0
## 基础地面颜色；默认深蓝灰，运行时修改会影响网格地图底色。
@export var base_floor_color: Color = Color(0.055, 0.07, 0.09, 1.0)
## 网格线颜色；取值为 RGBA，默认低透明度用于地图定位，运行时修改会影响背景网格可见度。
@export var grid_color: Color = Color(0.18, 0.25, 0.30, 0.34)
## 探索迷雾格子尺寸；取值应大于 0，默认 256 像素，修改会影响大地图迷雾精度和探索记录数量。
@export_range(16.0, 2048.0, 1.0, "or_greater") var exploration_cell_size: float = 256.0
## 玩家探索半径；取值应大于等于 0，默认 760 像素，修改会影响玩家走过后大地图可见区域大小。
@export_range(0.0, 6000.0, 1.0) var exploration_radius: float = 760.0
## 边界墙厚度；取值应大于 0，默认 64 像素，用于在地图四周生成一圈阻挡玩家和怪物离场的墙体。
@export_range(1.0, 1024.0, 1.0, "or_greater") var boundary_wall_thickness: float = 64.0
## 边界墙颜色；取值为 RGBA，默认深蓝灰，修改会影响地图边缘墙体的可视表现。
@export var boundary_wall_color: Color = Color(0.10, 0.15, 0.18, 1.0)
## 玩家节点路径；默认指向当前场景 Player，必须解析到 Node2D，修改会影响怪物索敌目标。
@export var player_path: NodePath = ^"Player"
## 环境物父节点路径；默认指向 Environment 容器，允许为空并回退到 GameWorld，修改会影响随机墙体和建筑层级。
@export var environment_parent_path: NodePath = ^"Environment"
## 随机环境预制体列表；默认由场景指定墙体和建筑，元素必须能实例化为 Node2D，修改会影响地图障碍类型池。
@export var obstacle_scenes: Array[PackedScene] = []
## 随机环境生成数量；取值建议 0 到 256，默认 96，运行时修改会影响地图障碍密度。
@export_range(0, 256, 1) var obstacle_spawn_count: int = 96
## 环境生成最小玩家距离；取值应大于等于 0，默认 300 像素，运行时修改会影响玩家出生点周围空地大小。
@export_range(0.0, 4000.0, 1.0) var obstacle_spawn_min_distance_from_player: float = 300.0
## 环境生成边界留白；取值应大于等于 0，默认 520 像素，运行时修改会影响墙体和建筑离地图边缘的距离。
@export_range(0.0, 4000.0, 1.0) var obstacle_spawn_edge_margin: float = 520.0
## 环境生成最小间距；取值应大于等于 0，默认 52 像素，运行时修改会影响建筑之间是否拥挤或重叠。
@export_range(0.0, 2000.0, 1.0) var obstacle_spawn_min_spacing: float = 52.0
## 单个环境物生成尝试次数；取值建议 1 到 128，默认 36，运行时修改会影响生成成功率和进入场景耗时。
@export_range(1, 128, 1) var obstacle_spawn_attempts_per_item: int = 36
## 环境物最小随机缩放；取值建议大于 0，默认 0.65，修改会影响墙体和建筑最小体积。
@export_range(0.1, 8.0, 0.05) var obstacle_scale_min: float = 0.65
## 环境物最大随机缩放；取值应大于等于最小缩放，默认 1.9，修改会影响墙体和建筑最大体积。
@export_range(0.1, 8.0, 0.05) var obstacle_scale_max: float = 1.9
## 随机怪物场景；默认由 game_world.tscn 指向 BasicMonster，必须实例化为 Node2D，修改会影响随机生成的敌人类型。
@export var monster_scene: PackedScene
## 随机怪物场景池；默认由场景填入近战和远程怪物，非空时会优先从池中随机选择生成对象。
@export var monster_scenes: Array[PackedScene] = []
## 怪物生成数量；取值建议 0 到 64，默认 8，运行时修改会影响开局战斗压力。
@export_range(0, 64, 1) var monster_spawn_count: int = 8
## 怪物生成最小距离；取值应大于等于 0，默认 280 像素，运行时修改会影响怪物是否离玩家过近。
@export_range(0.0, 4000.0, 1.0) var monster_spawn_min_distance: float = 280.0
## 怪物生成最大距离；取值应大于最小距离，默认 900 像素，运行时修改会影响怪物分布范围。
@export_range(1.0, 8000.0, 1.0, "or_greater") var monster_spawn_max_distance: float = 900.0
## 怪物父节点路径；默认指向 Enemies 容器，允许为空并回退到 GameWorld，修改会影响怪物节点层级。
@export var monster_parent_path: NodePath = ^"Enemies"
## 星的固定生命上限；取值应大于 0，默认 130，切换角色时直接应用，不再随机。
@export_range(1.0, 9999.0, 1.0, "or_greater") var stelle_max_health: float = 130.0
## 星的固定能量上限；取值应大于 0，默认 110，切换角色时直接应用，不再随机。
@export_range(1.0, 9999.0, 1.0, "or_greater") var stelle_max_energy: float = 110.0
## 星的固定移动速度；取值应大于 0，默认 320，切换角色时会写入玩家移动组件。
@export_range(1.0, 2000.0, 1.0, "or_greater") var stelle_move_speed: float = 320.0
## 穹的固定生命上限；取值应大于 0，默认 150，切换角色时直接应用，不再随机。
@export_range(1.0, 9999.0, 1.0, "or_greater") var caelus_max_health: float = 150.0
## 穹的固定能量上限；取值应大于 0，默认 95，切换角色时直接应用，不再随机。
@export_range(1.0, 9999.0, 1.0, "or_greater") var caelus_max_energy: float = 95.0
## 穹的固定移动速度；取值应大于 0，默认 300，切换角色时会写入玩家移动组件。
@export_range(1.0, 2000.0, 1.0, "or_greater") var caelus_move_speed: float = 300.0
## 银狼的固定生命上限；取值应大于 0，默认 105，切换角色时直接应用，不再随机。
@export_range(1.0, 9999.0, 1.0, "or_greater") var silver_wolf_max_health: float = 105.0
## 银狼的固定能量上限；取值应大于 0，默认 155，切换角色时直接应用，不再随机。
@export_range(1.0, 9999.0, 1.0, "or_greater") var silver_wolf_max_energy: float = 155.0
## 银狼的固定移动速度；取值应大于 0，默认 355，切换角色时会写入玩家移动组件。
@export_range(1.0, 2000.0, 1.0, "or_greater") var silver_wolf_move_speed: float = 355.0

## 随机数生成器；默认新建并在 ready 随机化，修改会影响地图和怪物生成结果。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 当前实际地图种子；取值为 map_seed 或随机值，默认 0 表示尚未生成，用于调试复现地图。
var _active_map_seed: int = 0
## 小地图障碍矩形缓存；元素为世界坐标 Rect2，默认由随机环境碰撞形状生成，修改会影响小地图绘制内容。
var _environment_obstacle_rects: Array[Rect2] = []
## 已探索迷雾格子缓存；键为 Vector2i，值为 true，默认由玩家位置持续写入，修改会影响大地图可见区域。
var _explored_cells: Dictionary = {}
## 当前是否为训练场模式；默认 false 表示正式骇入，修改会影响 HUD 是否显示训练场设置。
var _is_training_mode: bool = false
## 当前选择角色标识；取值为 stelle、caelus 或 silver_wolf，默认 stelle，用于角色切换和属性随机。
var _selected_character_id: String = CHARACTER_STELLE

## 玩家节点缓存；默认按 player_path 获取，允许为空并以世界原点作为生成中心。
@onready var _player: Node2D = get_node_or_null(player_path) as Node2D
## 环境物父节点缓存；默认按 environment_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _environment_parent: Node = get_node_or_null(environment_parent_path)
## 怪物父节点缓存；默认按 monster_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _monster_parent: Node = get_node_or_null(monster_parent_path)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_random.randomize()
	_apply_session_state()
	_prepare_map_seed()
	_environment_obstacle_rects.clear()
	_spawn_boundary_walls()
	_spawn_random_environment()
	_spawn_monster_batch()
	_update_explored_cells()


func _process(_delta: float) -> void:
	_update_explored_cells()


func _draw() -> void:
	# 网格半边长；取值由 grid_size 和 grid_extent 计算，无固定默认值，修改会影响背景矩形和线段端点。
	var half_size: float = grid_size * float(grid_extent)
	# 背景绘制区域；取值为以世界原点居中的 Rect2，无固定默认值，修改会影响可视背景覆盖范围。
	var play_area: Rect2 = Rect2(Vector2(-half_size, -half_size), Vector2(half_size * 2.0, half_size * 2.0))
	draw_rect(play_area, base_floor_color, true)

	# 网格线循环索引；取值范围为 -grid_extent 到 grid_extent，默认每格绘制一条水平线和垂直线。
	for index in range(-grid_extent, grid_extent + 1):
		# 当前网格线偏移；取值由循环索引乘单格尺寸得出，默认用于生成世界坐标线段。
		var offset: float = float(index) * grid_size
		draw_line(Vector2(offset, -half_size), Vector2(offset, half_size), grid_color, 1.0)
		draw_line(Vector2(-half_size, offset), Vector2(half_size, offset), grid_color, 1.0)

	# 地图边框颜色；取值来自 axis_color，默认用于网格地图边界提示。
	var border_color: Color = axis_color
	draw_rect(play_area, border_color, false, 2.0)


func _prepare_map_seed() -> void:
	_active_map_seed = map_seed
	if _active_map_seed == 0:
		_active_map_seed = int(_random.randi())

	_random.seed = _active_map_seed
	queue_redraw()


func is_training_mode() -> bool:
	# 会话状态节点；默认由自动加载提供，允许 HUD 在 GameWorld ready 前也能读到正确模式。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("is_training_mode"):
		return bool(session_state.call("is_training_mode"))

	return _is_training_mode


func get_selected_character_id() -> String:
	return _selected_character_id


func get_selected_character_name() -> String:
	return _get_character_display_name(_selected_character_id)


func get_map_half_size() -> float:
	return grid_size * float(grid_extent)


func get_minimap_obstacle_rects() -> Array[Rect2]:
	# 障碍矩形副本；取值为当前环境碰撞矩形列表，默认用于小地图绘制，修改返回方式会影响外部是否能误改缓存。
	var result: Array[Rect2] = []
	# 障碍矩形遍历项；取值为世界坐标 Rect2，默认逐项复制到返回数组。
	for obstacle_rect in _environment_obstacle_rects:
		result.append(obstacle_rect)

	return result


func get_explored_cells() -> Array[Vector2i]:
	# 已探索格子列表；元素为 Vector2i，默认从字典键复制，供大地图迷雾绘制使用。
	var result: Array[Vector2i] = []
	# 已探索格子键遍历项；取值来自 _explored_cells 的所有键，默认只收集 Vector2i。
	for explored_cell in _explored_cells.keys():
		if explored_cell is Vector2i:
			result.append(explored_cell)

	return result


func get_exploration_cell_size() -> float:
	return maxf(exploration_cell_size, 1.0)


func switch_character(character_id: String) -> void:
	_selected_character_id = _normalize_character_id(character_id)

	# 会话状态节点；默认由自动加载提供，修改后可让后续场景继续继承当前角色选择。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("configure"):
		# 当前模式标识；取值为 training 或 hack，默认按本世界缓存回写，修改会影响后续场景入口状态。
		var current_mode: String = GAME_MODE_TRAINING if _is_training_mode else GAME_MODE_HACK
		session_state.call("configure", current_mode, _selected_character_id)

	_apply_selected_character()


func _apply_session_state() -> void:
	# 会话状态节点；默认由自动加载提供，缺失时使用正式骇入和星作为兜底。
	var session_state: Node = _get_session_state()
	if session_state == null:
		_is_training_mode = false
		_selected_character_id = CHARACTER_STELLE
		_apply_selected_character()
		return

	if session_state.has_method("is_training_mode"):
		_is_training_mode = bool(session_state.call("is_training_mode"))
	else:
		# 会话模式属性；取值为字符串，默认 hack，修改会影响当前 GameWorld 模式缓存。
		var session_mode: String = str(session_state.get("game_mode"))
		_is_training_mode = session_mode == GAME_MODE_TRAINING

	if session_state.has_method("get_selected_character_id"):
		_selected_character_id = _normalize_character_id(str(session_state.call("get_selected_character_id")))
	else:
		# 会话角色属性；取值为字符串，默认 stelle，修改会影响当前 GameWorld 角色缓存。
		var session_character_id: String = str(session_state.get("selected_character_id"))
		_selected_character_id = _normalize_character_id(session_character_id)

	_apply_selected_character()


func _get_session_state() -> Node:
	return get_tree().root.get_node_or_null("SessionState")


func _apply_selected_character() -> void:
	if _player == null:
		return

	_player.set("player_display_name", _get_character_display_name(_selected_character_id))

	# 玩家属性组件；默认从玩家子节点 StatsComponent 获取，缺失时跳过占位属性应用。
	var stats_component: Node = _player.get_node_or_null("StatsComponent")
	if stats_component != null and stats_component.has_method("configure_max_stats"):
		# 固定生命上限；取值来自当前角色配置，默认用于进入场景或训练场切换角色时刷新生命。
		var resolved_max_health: float = _get_character_max_health(_selected_character_id)
		# 固定能量上限；取值来自当前角色配置，默认用于进入场景或训练场切换角色时刷新能量。
		var resolved_max_energy: float = _get_character_max_energy(_selected_character_id)
		stats_component.call("configure_max_stats", resolved_max_health, resolved_max_energy)

	# 玩家移动组件；默认从玩家子节点 MovementComponent 获取，缺失时跳过速度应用。
	var movement_component: Node = _player.get_node_or_null("MovementComponent")
	if movement_component == null:
		return

	# 固定移动速度；取值来自当前角色配置，默认用于进入场景或训练场切换角色时刷新移动速度。
	var resolved_move_speed: float = _get_character_move_speed(_selected_character_id)
	if movement_component.has_method("configure_max_speed"):
		movement_component.call("configure_max_speed", resolved_move_speed)
	else:
		movement_component.set("max_speed", resolved_move_speed)


func _get_character_max_health(character_id: String) -> float:
	if character_id == CHARACTER_CAEULUS:
		return maxf(caelus_max_health, 1.0)
	if character_id == CHARACTER_SILVER_WOLF:
		return maxf(silver_wolf_max_health, 1.0)

	return maxf(stelle_max_health, 1.0)


func _get_character_max_energy(character_id: String) -> float:
	if character_id == CHARACTER_CAEULUS:
		return maxf(caelus_max_energy, 1.0)
	if character_id == CHARACTER_SILVER_WOLF:
		return maxf(silver_wolf_max_energy, 1.0)

	return maxf(stelle_max_energy, 1.0)


func _get_character_move_speed(character_id: String) -> float:
	if character_id == CHARACTER_CAEULUS:
		return maxf(caelus_move_speed, 1.0)
	if character_id == CHARACTER_SILVER_WOLF:
		return maxf(silver_wolf_move_speed, 1.0)

	return maxf(stelle_move_speed, 1.0)


func _normalize_character_id(character_id: String) -> String:
	if character_id == CHARACTER_CAEULUS:
		return CHARACTER_CAEULUS
	if character_id == CHARACTER_SILVER_WOLF:
		return CHARACTER_SILVER_WOLF

	return CHARACTER_STELLE


func _get_character_display_name(character_id: String) -> String:
	if character_id == CHARACTER_CAEULUS:
		return "穹"
	if character_id == CHARACTER_SILVER_WOLF:
		return "银狼"

	return "星"


func _update_explored_cells() -> void:
	if _player == null:
		return

	# 有效探索格子尺寸；取值至少 1，默认防止配置错误导致除零。
	var cell_size: float = get_exploration_cell_size()
	# 玩家所在探索格；取值为玩家当前全局坐标转换后的格子坐标。
	var center_cell: Vector2i = _world_position_to_exploration_cell(_player.global_position)
	# 探索格半径；取值为探索半径除以格子尺寸后向上取整，默认用于批量标记圆形附近格子。
	var cell_radius: int = ceili(maxf(exploration_radius, 0.0) / cell_size)
	# X 轴探索偏移；取值为 -cell_radius 到 cell_radius，默认覆盖玩家附近探索范围。
	for offset_x in range(-cell_radius, cell_radius + 1):
		# Y 轴探索偏移；取值为 -cell_radius 到 cell_radius，默认覆盖玩家附近探索范围。
		for offset_y in range(-cell_radius, cell_radius + 1):
			# 探索偏移向量；取值为当前循环偏移，默认用于圆形范围过滤。
			var offset_vector: Vector2 = Vector2(float(offset_x), float(offset_y)) * cell_size
			if offset_vector.length() > exploration_radius + cell_size * 0.5:
				continue

			# 当前探索格；取值为玩家中心格加偏移，默认写入已探索字典。
			var explored_cell: Vector2i = center_cell + Vector2i(offset_x, offset_y)
			_explored_cells[explored_cell] = true


func _world_position_to_exploration_cell(world_position: Vector2) -> Vector2i:
	# 有效探索格子尺寸；取值至少 1，默认防止配置错误导致除零。
	var cell_size: float = get_exploration_cell_size()
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.y / cell_size))


func _spawn_boundary_walls() -> void:
	# 边界墙挂载父节点；取值为 Environment 容器或 GameWorld，默认用于组织地图边缘阻挡体。
	var spawn_parent: Node = _environment_parent if _environment_parent != null else self
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于定位四周边界。
	var half_size: float = get_map_half_size()
	# 边界墙厚度；取值至少为 1，默认用于生成四条矩形墙体。
	var wall_thickness: float = maxf(boundary_wall_thickness, 1.0)
	# 地图完整宽度；取值为半边长两倍，默认用于横向墙体长度。
	var map_width: float = half_size * 2.0
	# 横向墙体尺寸；取值覆盖地图宽度，默认放置在地图上下边缘内侧。
	var horizontal_wall_size: Vector2 = Vector2(map_width, wall_thickness)
	# 纵向墙体尺寸；取值覆盖地图高度，默认放置在地图左右边缘内侧。
	var vertical_wall_size: Vector2 = Vector2(wall_thickness, map_width)
	_create_boundary_wall(spawn_parent, "TopBoundaryWall", Vector2(0.0, -half_size + wall_thickness * 0.5), horizontal_wall_size)
	_create_boundary_wall(spawn_parent, "BottomBoundaryWall", Vector2(0.0, half_size - wall_thickness * 0.5), horizontal_wall_size)
	_create_boundary_wall(spawn_parent, "LeftBoundaryWall", Vector2(-half_size + wall_thickness * 0.5, 0.0), vertical_wall_size)
	_create_boundary_wall(spawn_parent, "RightBoundaryWall", Vector2(half_size - wall_thickness * 0.5, 0.0), vertical_wall_size)


func _create_boundary_wall(parent_node: Node, wall_name: String, wall_position: Vector2, wall_size: Vector2) -> void:
	# 边界墙物理体；取值为新建 StaticBody2D，默认使用环境层阻挡玩家、怪物和弹体。
	var wall_body: StaticBody2D = StaticBody2D.new()
	wall_body.name = wall_name
	wall_body.collision_layer = 16
	wall_body.collision_mask = 0
	wall_body.add_to_group("environment_obstacles")
	parent_node.add_child(wall_body)
	wall_body.global_position = wall_position

	# 边界墙碰撞形状资源；取值为 RectangleShape2D，默认尺寸等于传入墙体尺寸。
	var rectangle_shape: RectangleShape2D = RectangleShape2D.new()
	rectangle_shape.size = wall_size
	# 边界墙碰撞节点；取值为 CollisionShape2D，默认挂载到墙体物理节点。
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rectangle_shape
	wall_body.add_child(collision_shape)

	# 边界墙视觉节点；取值为 Polygon2D，默认用半透明深色矩形标记地图边缘。
	var visual: Polygon2D = Polygon2D.new()
	visual.color = boundary_wall_color
	visual.polygon = PackedVector2Array([
		Vector2(-wall_size.x * 0.5, -wall_size.y * 0.5),
		Vector2(wall_size.x * 0.5, -wall_size.y * 0.5),
		Vector2(wall_size.x * 0.5, wall_size.y * 0.5),
		Vector2(-wall_size.x * 0.5, wall_size.y * 0.5)
	])
	wall_body.add_child(visual)

	# 边界墙世界矩形；取值为墙体全局位置和尺寸计算结果，默认写入地图障碍缓存。
	var wall_rect: Rect2 = Rect2(wall_position - wall_size * 0.5, wall_size)
	_environment_obstacle_rects.append(wall_rect)


func _spawn_random_environment() -> void:
	if obstacle_scenes.is_empty() or obstacle_spawn_count <= 0:
		return

	# 环境挂载父节点；取值为 Environment 容器或 GameWorld，默认用于组织随机墙体和建筑。
	var spawn_parent: Node = _environment_parent if _environment_parent != null else self
	# 环境生成循环索引；取值为 0 到 obstacle_spawn_count - 1，默认逐个尝试生成环境预制体。
	for _spawn_index in range(obstacle_spawn_count):
		# 环境预制体资源；取值来自 obstacle_scenes 随机下标，默认用于提供不同墙体和建筑类型。
		var obstacle_scene: PackedScene = obstacle_scenes[_random.randi_range(0, obstacle_scenes.size() - 1)]
		if obstacle_scene == null:
			continue

		# 环境实例；取值为 Node2D 或 null，默认由预制体实例化，修改会影响实际摆放对象。
		var obstacle_instance: Node2D = obstacle_scene.instantiate() as Node2D
		if obstacle_instance == null:
			continue

		spawn_parent.add_child(obstacle_instance)
		if not _place_environment_instance(obstacle_instance):
			spawn_parent.remove_child(obstacle_instance)
			obstacle_instance.queue_free()


func _place_environment_instance(obstacle_instance: Node2D) -> bool:
	# 环境摆放尝试索引；取值为 0 到 obstacle_spawn_attempts_per_item - 1，默认用于多次寻找合法位置。
	for _attempt_index in range(obstacle_spawn_attempts_per_item):
		obstacle_instance.global_position = _get_random_environment_spawn_position()
		obstacle_instance.rotation = float(_random.randi_range(0, 3)) * PI * 0.5
		# 环境随机缩放；取值为 obstacle_scale_min 到 obstacle_scale_max，默认让同类型建筑拥有不同体积。
		var obstacle_scale: float = _get_random_obstacle_scale()
		obstacle_instance.scale = Vector2(obstacle_scale, obstacle_scale)

		# 当前实例碰撞矩形列表；取值为世界坐标 Rect2 数组，默认用于小地图和摆放合法性判断。
		var obstacle_rects: Array[Rect2] = _get_obstacle_collision_rects(obstacle_instance)
		# 当前实例整体边界；取值为所有碰撞矩形的并集，默认用于快速判断边界和间距。
		var obstacle_bounds: Rect2 = _get_rects_bounds(obstacle_rects)
		if not _is_environment_bounds_valid(obstacle_bounds):
			continue

		# 当前实例矩形遍历项；取值为世界坐标 Rect2，默认写入小地图障碍缓存。
		for obstacle_rect in obstacle_rects:
			_environment_obstacle_rects.append(obstacle_rect)

		return true

	return false


func _get_random_environment_spawn_position() -> Vector2:
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于限制环境物出生范围。
	var half_size: float = get_map_half_size()
	# 有效生成边界；取值为半边长减边界留白，默认避免建筑贴边或超出网格地图。
	var spawn_limit: float = maxf(0.0, half_size - obstacle_spawn_edge_margin)
	return Vector2(
		_random.randf_range(-spawn_limit, spawn_limit),
		_random.randf_range(-spawn_limit, spawn_limit)
	)


func _get_random_obstacle_scale() -> float:
	# 标准化最小缩放；取值至少为 0.1，默认防止环境物过小或配置为 0。
	var min_scale: float = maxf(minf(obstacle_scale_min, obstacle_scale_max), 0.1)
	# 标准化最大缩放；取值至少为最小缩放，默认防止配置反转导致随机范围错误。
	var max_scale: float = maxf(maxf(obstacle_scale_min, obstacle_scale_max), min_scale)
	return _random.randf_range(min_scale, max_scale)


func _is_environment_bounds_valid(obstacle_bounds: Rect2) -> bool:
	if obstacle_bounds.size.x <= 0.0 or obstacle_bounds.size.y <= 0.0:
		return false

	# 障碍中心点；取值为整体边界中心，默认用于玩家出生点安全距离判断。
	var obstacle_center: Vector2 = obstacle_bounds.get_center()
	if _player != null and obstacle_center.distance_to(_player.global_position) < obstacle_spawn_min_distance_from_player:
		return false

	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于判断障碍是否完全在地图内。
	var half_size: float = get_map_half_size()
	if obstacle_bounds.position.x < -half_size or obstacle_bounds.position.y < -half_size:
		return false
	if obstacle_bounds.end.x > half_size or obstacle_bounds.end.y > half_size:
		return false

	# 带间距的候选边界；取值为障碍整体边界向外扩张，默认用于避免建筑互相贴脸。
	var spaced_bounds: Rect2 = obstacle_bounds.grow(obstacle_spawn_min_spacing)
	# 既有障碍矩形遍历项；取值为世界坐标 Rect2，默认用于检测新障碍是否过度重叠。
	for existing_rect in _environment_obstacle_rects:
		if spaced_bounds.intersects(existing_rect):
			return false

	return true


func _get_obstacle_collision_rects(root: Node) -> Array[Rect2]:
	# 碰撞矩形结果；元素为世界坐标 Rect2，默认供小地图和障碍摆放检测使用。
	var result: Array[Rect2] = []
	_collect_obstacle_collision_rects(root, result)
	if result.is_empty() and root is Node2D:
		# 根节点兜底位置；取值为 Node2D 全局坐标，默认用于预制体缺少碰撞形状时仍有最小边界。
		var root_position: Vector2 = (root as Node2D).global_position
		result.append(Rect2(root_position - Vector2(16.0, 16.0), Vector2(32.0, 32.0)))

	return result


func _collect_obstacle_collision_rects(node: Node, result: Array[Rect2]) -> void:
	if node is CollisionShape2D:
		# 碰撞形状节点；取值为 CollisionShape2D，默认只处理矩形碰撞体用于小地图绘制。
		var collision_shape: CollisionShape2D = node as CollisionShape2D
		if collision_shape.shape is RectangleShape2D:
			# 矩形碰撞体；取值为 RectangleShape2D，默认与墙体和建筑预制体保持一致。
			var rectangle_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
			result.append(_get_global_rect_from_rectangle_shape(collision_shape, rectangle_shape))

	# 子节点遍历项；取值为当前节点所有子节点，默认递归查找预制体内的墙体碰撞形状。
	for child in node.get_children():
		_collect_obstacle_collision_rects(child, result)


func _get_global_rect_from_rectangle_shape(collision_shape: CollisionShape2D, rectangle_shape: RectangleShape2D) -> Rect2:
	# 矩形半尺寸；取值为碰撞形状尺寸一半，默认用于生成四个局部角点。
	var half_size: Vector2 = rectangle_shape.size * 0.5
	# 矩形全局变换；取值来自碰撞形状节点，默认用于支持建筑整体旋转。
	var shape_transform: Transform2D = collision_shape.global_transform
	# 第一个角点；取值为左上局部角点转换到世界坐标，默认初始化包围盒。
	var first_corner: Vector2 = shape_transform * Vector2(-half_size.x, -half_size.y)
	# 最小坐标；取值会随其他角点更新，默认用于构建世界轴对齐包围盒。
	var min_position: Vector2 = first_corner
	# 最大坐标；取值会随其他角点更新，默认用于构建世界轴对齐包围盒。
	var max_position: Vector2 = first_corner
	# 矩形局部角点数组；取值为四个角点，默认用于计算旋转后的轴对齐包围盒。
	var corners: Array[Vector2] = [
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	]
	# 角点遍历项；取值为局部坐标，默认逐个转换并扩展包围盒。
	for corner in corners:
		# 当前世界角点；取值为局部角点经全局变换后的坐标，默认用于更新包围盒。
		var world_corner: Vector2 = shape_transform * corner
		min_position = min_position.min(world_corner)
		max_position = max_position.max(world_corner)

	return Rect2(min_position, max_position - min_position)


func _get_rects_bounds(rects: Array[Rect2]) -> Rect2:
	if rects.is_empty():
		return Rect2()

	# 合并边界；取值初始为第一个矩形，默认逐项扩展为所有矩形的并集。
	var merged_bounds: Rect2 = rects[0]
	# 矩形索引；取值从 1 到数组末尾，默认跳过已作为初始值的第一个矩形。
	for rect_index in range(1, rects.size()):
		merged_bounds = merged_bounds.merge(rects[rect_index])

	return merged_bounds


func _spawn_monster_batch() -> void:
	if not _has_monster_scene_available() or monster_spawn_count <= 0:
		return

	# 怪物挂载父节点；取值为 Enemies 容器或 GameWorld，默认用于组织随机生成物。
	var spawn_parent: Node = _monster_parent if _monster_parent != null else self
	# 怪物生成循环索引；取值为 0 到 monster_spawn_count - 1，默认逐个生成怪物，修改循环范围会影响生成数量。
	for _spawn_index in range(monster_spawn_count):
		# 本次怪物场景；取值来自 monster_scenes 随机池或 monster_scene 兜底，默认用于生成不同怪物类型。
		var selected_monster_scene: PackedScene = _get_random_monster_scene()
		if selected_monster_scene == null:
			continue

		# 怪物实例；取值为 Node2D 或 null，默认由选中的怪物场景实例化，修改会影响生成对象。
		var monster: Node2D = selected_monster_scene.instantiate() as Node2D
		if monster == null:
			continue

		monster.add_to_group(TRAINING_MONSTER_GROUP)
		spawn_parent.add_child(monster)
		monster.global_position = _get_random_monster_spawn_position()
		if monster.has_method("set_target"):
			monster.call("set_target", _player)


func _has_monster_scene_available() -> bool:
	if not monster_scenes.is_empty():
		return true

	return monster_scene != null


func _get_random_monster_scene() -> PackedScene:
	if not monster_scenes.is_empty():
		# 怪物场景随机下标；取值为 0 到怪物场景池末尾，默认用于混合生成近战和远程怪物。
		var scene_index: int = _random.randi_range(0, monster_scenes.size() - 1)
		return monster_scenes[scene_index]

	return monster_scene


func clear_monsters() -> void:
	# 组内怪物节点列表；取值来自场景树训练场怪物组，默认用于清理曾经生成但不在 Enemies 容器中的怪物。
	var grouped_monsters: Array = get_tree().get_nodes_in_group(TRAINING_MONSTER_GROUP)
	# 组内怪物遍历项；取值为 Node 或其他对象，默认只处理有效 Node，修改循环来源会影响兜底清理范围。
	for grouped_monster in grouped_monsters:
		if grouped_monster is Node:
			# 组内怪物节点；取值为有效 Node，默认用于从父节点移除并立即释放。
			var grouped_monster_node: Node = grouped_monster as Node
			_free_monster_node(grouped_monster_node)

	if _monster_parent != null:
		# 怪物挂载父节点；取值为 Enemies 容器，默认用于查找需要清空的训练场怪物。
		var spawn_parent: Node = _monster_parent
		# 现有怪物节点遍历项；取值为怪物父节点下的子节点，默认全部移除，修改循环来源会影响清怪范围。
		for monster_node in spawn_parent.get_children():
			_free_monster_node(monster_node)


func respawn_monsters() -> void:
	_spawn_monster_batch()


func _free_monster_node(monster_node: Node) -> void:
	if monster_node == null or not is_instance_valid(monster_node):
		return

	if monster_node.get_parent() != null:
		monster_node.get_parent().remove_child(monster_node)

	monster_node.free()


func _get_random_monster_spawn_position() -> Vector2:
	# 怪物生成尝试次数；取值为固定 18 次，默认用于避开墙体和建筑内部。
	var spawn_attempt_count: int = 18
	# 怪物生成尝试索引；取值为 0 到 spawn_attempt_count - 1，默认逐次寻找不被障碍覆盖的位置。
	for _attempt_index in range(spawn_attempt_count):
		# 候选生成点；取值来自环形随机位置并夹取到地图内，默认用于检测是否避开环境障碍。
		var candidate_position: Vector2 = _get_random_monster_spawn_candidate()
		if not _is_position_blocked_by_environment(candidate_position, 36.0):
			return candidate_position

	return _get_random_monster_spawn_candidate()


func _get_random_monster_spawn_candidate() -> Vector2:
	# 生成中心点；取值为玩家位置或世界原点，默认让怪物围绕玩家随机刷新。
	var spawn_center: Vector2 = _player.global_position if _player != null else Vector2.ZERO
	# 标准化最大生成距离；取值至少为最小距离，默认防止配置错误导致随机范围反转。
	var resolved_max_distance: float = maxf(monster_spawn_max_distance, monster_spawn_min_distance)
	# 本次生成角度；取值为 0 到 TAU 的随机弧度，默认用于环形分布。
	var spawn_angle: float = _random.randf_range(0.0, TAU)
	# 本次生成距离；取值为最小到最大生成距离，默认用于控制怪物远近。
	var spawn_distance: float = _random.randf_range(monster_spawn_min_distance, resolved_max_distance)
	# 原始生成位置；取值可能超出地图边界，默认用于后续边界夹取。
	var raw_spawn_position: Vector2 = spawn_center + Vector2.RIGHT.rotated(spawn_angle) * spawn_distance
	return _clamp_position_to_map(raw_spawn_position)


func _is_position_blocked_by_environment(position: Vector2, radius: float) -> bool:
	# 检测矩形；取值为以 position 为中心的方形区域，默认近似角色或怪物碰撞体范围。
	var check_rect: Rect2 = Rect2(position - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	# 环境障碍矩形遍历项；取值为世界坐标 Rect2，默认用于判断候选点是否落入墙体或建筑。
	for obstacle_rect in _environment_obstacle_rects:
		if obstacle_rect.intersects(check_rect):
			return true

	return false


func _clamp_position_to_map(position: Vector2) -> Vector2:
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于限制出生点不超出网格地图。
	var half_size: float = grid_size * float(grid_extent)
	# 地图边界留白；取值为一个网格尺寸，默认避免怪物贴边生成。
	var edge_margin: float = grid_size
	return Vector2(
		clampf(position.x, -half_size + edge_margin, half_size - edge_margin),
		clampf(position.y, -half_size + edge_margin, half_size - edge_margin)
	)
