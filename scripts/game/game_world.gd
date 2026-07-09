extends Node2D

## 随机生成怪物组名；默认所有随机生成怪物都会加入该组，修改会影响清怪兜底范围。
const TRAINING_MONSTER_GROUP: StringName = &"training_monsters"
## 基础地面瓦片编号；默认用于随机地图的主要地面。
const MAP_TILE_BASE: int = 0
## 暗色地面瓦片编号；默认用于随机地图的轻微色块变化。
const MAP_TILE_DARK: int = 1
## 高亮线路瓦片编号；默认用于随机地图的量子线路装饰。
const MAP_TILE_LINE: int = 2
## 裂隙地面瓦片编号；默认用于随机地图的低频危险视觉点。
const MAP_TILE_RIFT: int = 3
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
## 进入战斗场景时会生成一张大型随机视觉地图，并在地图上刷新怪物。

## 调试网格单格尺寸；取值应大于 0，默认 64 匹配常见 2D 地图尺度，运行时修改会改变距离参照密度。
@export var grid_size: float = 64.0
## 随机地图向每个方向延伸的格数；取值应为正整数，默认 96 生成 192x192 格大型战斗地图，运行时修改会改变地图尺寸。
@export var grid_extent: int = 96
## 背景填充颜色；取值为 RGBA，默认深色用于突出角色和弹体，运行时修改只影响关卡背景观感。
@export var background_color: Color = Color(0.055, 0.07, 0.09, 1.0)
## 普通网格线颜色；取值为 RGBA，默认低透明度避免干扰战斗观察，运行时修改会影响非坐标轴网格可见度。
@export var grid_color: Color = Color(0.18, 0.25, 0.30, 0.42)
## 坐标轴网格线颜色；取值为 RGBA，默认更亮用于定位世界原点，运行时修改会影响原点参照识别。
@export var axis_color: Color = Color(0.28, 0.52, 0.72, 0.62)
## 地图随机种子；默认 0 表示每次进入战斗场景随机生成，设置为正数可复现同一张地图。
@export var map_seed: int = 0
## 暗色地面密度；取值 0 到 1，默认 0.22 提供足够变化，运行时修改会影响随机地图色块丰富度。
@export_range(0.0, 1.0, 0.01) var dark_tile_density: float = 0.22
## 高亮线路密度；取值 0 到 1，默认 0.045 形成稀疏科技线条，运行时修改会影响地图装饰密度。
@export_range(0.0, 1.0, 0.01) var line_tile_density: float = 0.045
## 裂隙地面密度；取值 0 到 1，默认 0.018 形成低频视觉重点，运行时修改会影响地图危险视觉点数量。
@export_range(0.0, 1.0, 0.01) var rift_tile_density: float = 0.018
## 基础地面颜色；默认深蓝灰，运行时修改会影响随机地图主色。
@export var base_floor_color: Color = Color(0.055, 0.07, 0.09, 1.0)
## 暗色地面颜色；默认偏暗蓝灰，运行时修改会影响随机地图暗色块。
@export var dark_floor_color: Color = Color(0.035, 0.048, 0.064, 1.0)
## 高亮线路颜色；默认青蓝半透明，运行时修改会影响随机地图量子线路视觉。
@export var line_floor_color: Color = Color(0.075, 0.20, 0.24, 1.0)
## 裂隙地面颜色；默认紫红暗色，运行时修改会影响随机地图裂隙视觉。
@export var rift_floor_color: Color = Color(0.15, 0.055, 0.12, 1.0)
## 玩家节点路径；默认指向当前场景 Player，必须解析到 Node2D，修改会影响怪物索敌目标。
@export var player_path: NodePath = ^"Player"
## 随机怪物场景；默认由 game_world.tscn 指向 BasicMonster，必须实例化为 Node2D，修改会影响随机生成的敌人类型。
@export var monster_scene: PackedScene
## 怪物生成数量；取值建议 0 到 64，默认 8，运行时修改会影响开局战斗压力。
@export_range(0, 64, 1) var monster_spawn_count: int = 8
## 怪物生成最小距离；取值应大于等于 0，默认 280 像素，运行时修改会影响怪物是否离玩家过近。
@export_range(0.0, 4000.0, 1.0) var monster_spawn_min_distance: float = 280.0
## 怪物生成最大距离；取值应大于最小距离，默认 900 像素，运行时修改会影响怪物分布范围。
@export_range(1.0, 8000.0, 1.0, "or_greater") var monster_spawn_max_distance: float = 900.0
## 怪物父节点路径；默认指向 Enemies 容器，允许为空并回退到 GameWorld，修改会影响怪物节点层级。
@export var monster_parent_path: NodePath = ^"Enemies"
## 星的随机生命上限范围；默认 115 到 145，运行时切换角色会重新随机，修改会影响星的生存定位。
@export var stelle_health_range: Vector2 = Vector2(115.0, 145.0)
## 星的随机能量上限范围；默认 95 到 125，运行时切换角色会重新随机，修改会影响星的资源上限。
@export var stelle_energy_range: Vector2 = Vector2(95.0, 125.0)
## 穹的随机生命上限范围；默认 130 到 165，运行时切换角色会重新随机，修改会影响穹的生存定位。
@export var caelus_health_range: Vector2 = Vector2(130.0, 165.0)
## 穹的随机能量上限范围；默认 80 到 110，运行时切换角色会重新随机，修改会影响穹的资源上限。
@export var caelus_energy_range: Vector2 = Vector2(80.0, 110.0)
## 银狼的随机生命上限范围；默认 90 到 120，运行时切换角色会重新随机，修改会影响银狼的生存定位。
@export var silver_wolf_health_range: Vector2 = Vector2(90.0, 120.0)
## 银狼的随机能量上限范围；默认 130 到 170，运行时切换角色会重新随机，修改会影响银狼的资源上限。
@export var silver_wolf_energy_range: Vector2 = Vector2(130.0, 170.0)

## 随机数生成器；默认新建并在 ready 随机化，修改会影响地图和怪物生成结果。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 随机地图瓦片表；元素为地图瓦片编号，默认 ready 时生成，修改会影响 _draw 绘制出的地图内容。
var _map_tiles: Array[int] = []
## 当前实际地图种子；取值为 map_seed 或随机值，默认 0 表示尚未生成，用于调试复现地图。
var _active_map_seed: int = 0
## 当前是否为训练场模式；默认 false 表示正式骇入，修改会影响 HUD 是否显示训练场设置。
var _is_training_mode: bool = false
## 当前选择角色标识；取值为 stelle、caelus 或 silver_wolf，默认 stelle，用于角色切换和属性随机。
var _selected_character_id: String = CHARACTER_STELLE

## 玩家节点缓存；默认按 player_path 获取，允许为空并以世界原点作为生成中心。
@onready var _player: Node2D = get_node_or_null(player_path) as Node2D
## 怪物父节点缓存；默认按 monster_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _monster_parent: Node = get_node_or_null(monster_parent_path)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_random.randomize()
	_apply_session_state()
	_generate_random_map()
	_spawn_monster_batch()


func _draw() -> void:
	# 网格半边长；取值由 grid_size 和 grid_extent 计算，无固定默认值，修改会影响背景矩形和线段端点。
	var half_size: float = grid_size * float(grid_extent)
	# 背景绘制区域；取值为以世界原点居中的 Rect2，无固定默认值，修改会影响可视背景覆盖范围。
	var play_area: Rect2 = Rect2(Vector2(-half_size, -half_size), Vector2(half_size * 2.0, half_size * 2.0))
	draw_rect(play_area, background_color, true)
	_draw_random_map(half_size)

	# 网格线循环索引；取值范围为 -grid_extent 到 grid_extent，默认由网格范围生成，修改循环范围会影响绘制线条数量。
	for index in range(-grid_extent, grid_extent + 1):
		# 当前网格线偏移；取值由循环索引乘单格尺寸得出，无固定默认值，修改会移动当前线段位置。
		var offset: float = float(index) * grid_size
		# 当前网格线颜色；原点轴使用 axis_color，其余使用 grid_color，修改会影响当前线段视觉层级。
		var color: Color = axis_color if index == 0 else grid_color
		draw_line(Vector2(offset, -half_size), Vector2(offset, half_size), color, 1.0)
		draw_line(Vector2(-half_size, offset), Vector2(half_size, offset), color, 1.0)


func _generate_random_map() -> void:
	_map_tiles.clear()
	_active_map_seed = map_seed
	if _active_map_seed == 0:
		_active_map_seed = int(_random.randi())

	# 地图随机生成器；取值为独立 RandomNumberGenerator，默认使用当前地图种子，修改会影响地图瓦片序列。
	var map_random: RandomNumberGenerator = RandomNumberGenerator.new()
	map_random.seed = _active_map_seed

	# 单边瓦片数量；取值至少为 2，默认由 grid_extent 生成，修改会影响地图数组容量。
	var side_tile_count: int = maxi(2, grid_extent * 2)
	# 地图总瓦片数量；取值为单边数量平方，默认用于预生成所有瓦片。
	var total_tile_count: int = side_tile_count * side_tile_count
	# 瓦片生成索引；取值为 0 到 total_tile_count - 1，默认逐格生成地图，修改循环范围会影响地图覆盖面积。
	for _tile_index in range(total_tile_count):
		# 随机权重；取值 0 到 1，默认用于选择当前瓦片类型。
		var roll: float = map_random.randf()
		# 当前瓦片类型；取值为 MAP_TILE_* 常量，默认基础地面，修改会影响绘制颜色。
		var tile_type: int = MAP_TILE_BASE
		if roll < rift_tile_density:
			tile_type = MAP_TILE_RIFT
		elif roll < rift_tile_density + line_tile_density:
			tile_type = MAP_TILE_LINE
		elif roll < rift_tile_density + line_tile_density + dark_tile_density:
			tile_type = MAP_TILE_DARK

		_map_tiles.append(tile_type)

	queue_redraw()


func _draw_random_map(half_size: float) -> void:
	if _map_tiles.is_empty():
		return

	# 单边瓦片数量；取值至少为 2，默认与 _generate_random_map 保持一致，修改会影响瓦片索引解析。
	var side_tile_count: int = maxi(2, grid_extent * 2)
	# 地图左上角坐标；取值为世界坐标，默认让地图以世界原点居中。
	var map_top_left: Vector2 = Vector2(-half_size, -half_size)
	# Y 轴瓦片索引；取值为 0 到 side_tile_count - 1，默认逐行绘制地图。
	for tile_y in range(side_tile_count):
		# X 轴瓦片索引；取值为 0 到 side_tile_count - 1，默认逐列绘制地图。
		for tile_x in range(side_tile_count):
			# 当前瓦片索引；取值为地图数组有效下标，默认由二维坐标转换，修改会影响读取的瓦片类型。
			var tile_index: int = tile_y * side_tile_count + tile_x
			if tile_index >= _map_tiles.size():
				continue

			# 当前瓦片类型；取值为 MAP_TILE_* 常量，默认来自预生成地图数组，修改会影响当前格颜色。
			var tile_type: int = _map_tiles[tile_index]
			# 当前瓦片位置；取值为世界坐标，默认按左上角和格子尺寸计算。
			var tile_position: Vector2 = map_top_left + Vector2(float(tile_x) * grid_size, float(tile_y) * grid_size)
			# 当前瓦片矩形；取值为完整瓦片区域，默认覆盖一格地图。
			var tile_rect: Rect2 = Rect2(tile_position, Vector2(grid_size, grid_size))
			draw_rect(tile_rect, _get_map_tile_color(tile_type), true)


func _get_map_tile_color(tile_type: int) -> Color:
	if tile_type == MAP_TILE_DARK:
		return dark_floor_color
	if tile_type == MAP_TILE_LINE:
		return line_floor_color
	if tile_type == MAP_TILE_RIFT:
		return rift_floor_color

	return base_floor_color


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
	if stats_component == null or not stats_component.has_method("configure_max_stats"):
		return

	# 随机后的生命上限；取值来自当前角色生命范围，默认用于进入场景或训练场切换角色时刷新生命。
	var rolled_max_health: float = _roll_character_max_health(_selected_character_id)
	# 随机后的能量上限；取值来自当前角色能量范围，默认用于进入场景或训练场切换角色时刷新能量。
	var rolled_max_energy: float = _roll_character_max_energy(_selected_character_id)
	stats_component.call("configure_max_stats", rolled_max_health, rolled_max_energy)


func _roll_character_max_health(character_id: String) -> float:
	# 角色生命范围；取值为 Vector2(x 最小值, y 最大值)，默认由角色配置导出项返回。
	var health_range: Vector2 = _get_character_health_range(character_id)
	# 标准化生命最小值；取值至少 1，默认防止配置反转或无效导致属性异常。
	var min_health: float = maxf(minf(health_range.x, health_range.y), 1.0)
	# 标准化生命最大值；取值至少为最小值，默认防止配置反转导致随机范围错误。
	var max_health: float = maxf(maxf(health_range.x, health_range.y), min_health)
	return _random.randf_range(min_health, max_health)


func _roll_character_max_energy(character_id: String) -> float:
	# 角色能量范围；取值为 Vector2(x 最小值, y 最大值)，默认由角色配置导出项返回。
	var energy_range: Vector2 = _get_character_energy_range(character_id)
	# 标准化能量最小值；取值至少 1，默认防止配置反转或无效导致属性异常。
	var min_energy: float = maxf(minf(energy_range.x, energy_range.y), 1.0)
	# 标准化能量最大值；取值至少为最小值，默认防止配置反转导致随机范围错误。
	var max_energy: float = maxf(maxf(energy_range.x, energy_range.y), min_energy)
	return _random.randf_range(min_energy, max_energy)


func _get_character_health_range(character_id: String) -> Vector2:
	if character_id == CHARACTER_CAEULUS:
		return caelus_health_range
	if character_id == CHARACTER_SILVER_WOLF:
		return silver_wolf_health_range

	return stelle_health_range


func _get_character_energy_range(character_id: String) -> Vector2:
	if character_id == CHARACTER_CAEULUS:
		return caelus_energy_range
	if character_id == CHARACTER_SILVER_WOLF:
		return silver_wolf_energy_range

	return stelle_energy_range


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


func _spawn_monster_batch() -> void:
	if monster_scene == null or monster_spawn_count <= 0:
		return

	# 怪物挂载父节点；取值为 Enemies 容器或 GameWorld，默认用于组织随机生成物。
	var spawn_parent: Node = _monster_parent if _monster_parent != null else self
	# 怪物生成循环索引；取值为 0 到 monster_spawn_count - 1，默认逐个生成怪物，修改循环范围会影响生成数量。
	for _spawn_index in range(monster_spawn_count):
		# 怪物实例；取值为 Node2D 或 null，默认由 monster_scene 实例化，修改会影响生成对象。
		var monster: Node2D = monster_scene.instantiate() as Node2D
		if monster == null:
			continue

		monster.add_to_group(TRAINING_MONSTER_GROUP)
		spawn_parent.add_child(monster)
		monster.global_position = _get_random_monster_spawn_position()
		if monster.has_method("set_target"):
			monster.call("set_target", _player)


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


func _clamp_position_to_map(position: Vector2) -> Vector2:
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于限制出生点不超出随机地图。
	var half_size: float = grid_size * float(grid_extent)
	# 地图边界留白；取值为一个网格尺寸，默认避免怪物贴边生成。
	var edge_margin: float = grid_size
	return Vector2(
		clampf(position.x, -half_size + edge_margin, half_size - edge_margin),
		clampf(position.y, -half_size + edge_margin, half_size - edge_margin)
	)
