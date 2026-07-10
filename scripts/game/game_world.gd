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
## 探索格更新间隔；取值建议 0.1 到 0.5 秒，默认 0.2 秒，修改会影响大地图迷雾刷新频率和每帧 CPU 开销。
@export_range(0.02, 5.0, 0.01) var exploration_update_interval: float = 0.2
## 探索格强制更新移动距离；取值建议小于探索格子尺寸，默认 96 像素，玩家移动超过该距离会立即刷新探索缓存。
@export_range(0.0, 2048.0, 1.0) var exploration_update_distance: float = 96.0
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
## 全地图布怪补充：项目当前默认生成 48 名敌人，旧 8 名说明保留用于追溯原型基线。
@export_range(0, 256, 1) var monster_spawn_count: int = 48
## 怪物生成最小距离；取值应大于等于 0，默认 280 像素，运行时修改会影响怪物是否离玩家过近。
## 全地图布怪补充：项目当前默认至少离玩家 900 像素，避免开局和补充刷新直接出现在屏幕附近。
@export_range(0.0, 8000.0, 1.0) var monster_spawn_min_distance: float = 900.0
## 怪物生成最大距离；取值应大于最小距离，默认 900 像素，运行时修改会影响怪物分布范围。
@export_range(1.0, 8000.0, 1.0, "or_greater") var monster_spawn_max_distance: float = 900.0
## 是否在整张地图均匀生成敌人；默认 true，关闭后恢复以玩家为中心的最小/最大距离环形生成。
@export var monster_spawn_across_full_map: bool = true
## 全地图敌人生成边界留白；默认 256 像素，防止敌人贴着边界墙或生成到地图外侧。
@export_range(0.0, 4000.0, 1.0) var monster_spawn_edge_margin: float = 256.0
## 正式战斗最低存活敌人数；默认 36，低于该值时会在玩家安全范围外分批补充敌人。
@export_range(0, 256, 1) var monster_minimum_alive_count: int = 36
## 敌人补充检查间隔；默认 2 秒，避免每帧统计和生成大量节点。
@export_range(0.1, 60.0, 0.1) var monster_replenish_interval: float = 2.0
## 单次补充敌人数量；默认 4，实际生成数不会超过恢复到最低存活数量所需的缺口。
@export_range(1, 32, 1) var monster_replenish_batch_size: int = 4
## 敌人尺寸与属性随机波动比例；默认 0.3 表示每只敌人的大小和战斗属性分别在 70% 到 130% 范围内生成。
@export_range(0.0, 0.9, 0.05) var monster_spawn_variation_ratio: float = 0.3
## 怪物父节点路径；默认指向 Enemies 容器，允许为空并回退到 GameWorld，修改会影响怪物节点层级。
@export var monster_parent_path: NodePath = ^"Enemies"
## 掉落物父节点路径；默认指向 Drops 容器，允许为空并回退到 GameWorld，修改会影响武器掉落物节点层级。
@export var drop_parent_path: NodePath = ^"Drops"
## 武器掉落物场景；默认由 game_world.tscn 指向 WeaponDrop，必须实例化为 Node2D，修改会影响所有地面武器表现。
@export var weapon_drop_scene: PackedScene
## 武器掉落随机池；元素为 WeaponData 资源，怪物死亡掉落时会从中随机复制一把作为独立掉落物。
@export var weapon_drop_table: Array[Resource] = []
## 玩家丢弃武器散落半径；取值建议大于玩家半径，默认 52 像素，修改会影响拖出背包时武器落点距离。
@export_range(0.0, 400.0, 1.0) var dropped_weapon_scatter_radius: float = 52.0
## 撤离点生成时间；取值为进入战斗后的秒数，默认 120 表示存活 2 分钟后生成撤离点。
@export_range(1.0, 7200.0, 1.0, "or_greater") var extraction_spawn_time_seconds: float = 120.0
## 撤离点地图标记时间；取值为进入战斗后的秒数，默认 300 表示存活 5 分钟后在地图上显示撤离点标记。
@export_range(1.0, 7200.0, 1.0, "or_greater") var extraction_map_marker_time_seconds: float = 300.0
## 撤离驻留时长；取值应大于 0，默认 5 秒，玩家在撤离范围内连续停留满该时间后可按闪避撤离。
@export_range(0.1, 120.0, 0.1, "or_greater") var extraction_hold_duration_seconds: float = 5.0
## 撤离点半径；取值建议大于玩家碰撞半径，默认 96 像素，修改会影响可驻留撤离范围。
@export_range(16.0, 512.0, 1.0, "or_greater") var extraction_radius: float = 96.0
## 撤离点生成边界留白；取值应大于撤离半径，默认 420 像素，修改会影响撤离点离地图边缘的距离。
@export_range(0.0, 4000.0, 1.0) var extraction_spawn_edge_margin: float = 420.0
## 撤离点生成最小玩家距离；取值建议大于屏幕半径，默认 900 像素，避免撤离点直接刷在玩家脚下。
@export_range(0.0, 8000.0, 1.0) var extraction_spawn_min_distance_from_player: float = 900.0
## 撤离点生成尝试次数；取值建议 1 到 128，默认 36，用于寻找不被环境障碍覆盖的位置。
@export_range(1, 128, 1) var extraction_spawn_attempt_count: int = 36
## 撤离点填充颜色；默认青绿色半透明，修改只影响撤离范围视觉反馈。
@export var extraction_fill_color: Color = Color(0.1, 0.9, 0.62, 0.18)
## 撤离点边框颜色；默认亮青绿色，修改只影响撤离范围边界视觉反馈。
@export var extraction_ring_color: Color = Color(0.35, 1.0, 0.76, 0.88)
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
## 小地图障碍版本号；取值从 0 递增，默认用于地图 UI 判断是否需要重新复制障碍矩形。
var _environment_obstacle_version: int = 0
## 已探索迷雾格子缓存；键为 Vector2i，值为 true，默认由玩家位置持续写入，修改会影响大地图可见区域。
var _explored_cells: Dictionary = {}
## 已探索格版本号；取值从 0 递增，默认仅在新增探索格时变化，供地图 UI 避免重复构建查询表。
var _explored_cells_version: int = 0
## 导航网格缓存；键为寻路格尺寸与代理半径组合，值为 AStarGrid2D，用于避免每只怪物重复重建整张地图网格。
var _navigation_grid_cache: Dictionary = {}
## 探索更新剩余时间；取值大于等于 0，默认 0 表示下一帧允许检查探索格刷新。
var _exploration_update_remaining: float = 0.0
## 上次刷新探索格时的玩家位置；取值为世界坐标，默认零向量，仅在 _has_last_exploration_update_position 为 true 时有效。
var _last_exploration_update_position: Vector2 = Vector2.ZERO
## 是否已有上次探索刷新位置；取值为 true/false，默认 false 用于首次强制刷新探索格。
var _has_last_exploration_update_position: bool = false
## 当前是否为训练场模式；默认 false 表示正式骇入，修改会影响 HUD 是否显示训练场设置。
var _is_training_mode: bool = false
## 当前选择角色标识；取值为 stelle、caelus 或 silver_wolf，默认 stelle，用于角色切换和属性随机。
var _selected_character_id: String = CHARACTER_STELLE
## 当前战斗存活时间；取值为进入 GameWorld 后玩家未死亡的累计秒数，默认 0 用于 HUD 计时显示。
var _survival_time_seconds: float = 0.0
## 撤离点节点缓存；取值为运行时生成的 Node2D 或 null，默认 null 表示撤离点尚未生成。
var _extraction_point_node: Node2D
## 撤离点位置缓存；取值为世界坐标，默认零向量，仅在 _has_extraction_point 为 true 时有效。
var _extraction_point_position: Vector2 = Vector2.ZERO
## 是否已经生成撤离点；取值为 true/false，默认 false，避免 2 分钟后重复生成多个撤离点。
var _has_extraction_point: bool = false
## 撤离点是否已经显示在地图上；取值为 true/false，默认 false，达到地图标记时间后变为 true。
var _extraction_point_marked_on_map: bool = false
## 玩家是否处于撤离范围内；取值为 true/false，默认 false，用于 HUD 显示驻留状态。
var _player_inside_extraction_area: bool = false
## 撤离驻留累计时间；取值大于等于 0，默认 0，离开撤离范围会重置。
var _extraction_hold_elapsed_seconds: float = 0.0
## 是否已经满足撤离条件；取值为 true/false，默认 false，达到驻留时长且仍在范围内时变为 true。
var _extraction_ready_to_leave: bool = false
## 敌人补充检查剩余时间；取值大于等于 0，默认按配置间隔初始化，正式战斗中持续递减。
var _monster_replenish_remaining: float = 0.0
## 玩家导航标点位置；取值为世界坐标，仅在 _has_navigation_marker 为 true 时有效。
var _navigation_marker_position: Vector2 = Vector2.ZERO
## 是否存在玩家导航标点；默认 false，大地图左键设置后由大小地图共同读取。
var _has_navigation_marker: bool = false

## 玩家节点缓存；默认按 player_path 获取，允许为空并以世界原点作为生成中心。
@onready var _player: Node2D = get_node_or_null(player_path) as Node2D
## 环境物父节点缓存；默认按 environment_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _environment_parent: Node = get_node_or_null(environment_parent_path)
## 怪物父节点缓存；默认按 monster_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _monster_parent: Node = get_node_or_null(monster_parent_path)
## 掉落物父节点缓存；默认按 drop_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _drop_parent: Node = get_node_or_null(drop_parent_path)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_random.randomize()
	_apply_session_state()
	_begin_global_inventory_run()
	_prepare_map_seed()
	_environment_obstacle_rects.clear()
	_navigation_grid_cache.clear()
	_spawn_boundary_walls()
	_spawn_random_environment()
	_environment_obstacle_version += 1
	_spawn_monster_batch()
	_monster_replenish_remaining = monster_replenish_interval
	_update_explored_cells(true)


func _process(delta: float) -> void:
	_update_survival_time(delta)
	_update_extraction_state(delta)
	_update_explored_cells_if_needed(delta)
	_update_monster_replenishment(delta)


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


func get_minimap_obstacle_version() -> int:
	return _environment_obstacle_version


func get_explored_cells() -> Array[Vector2i]:
	# 已探索格子列表；元素为 Vector2i，默认从字典键复制，供大地图迷雾绘制使用。
	var result: Array[Vector2i] = []
	# 已探索格子键遍历项；取值来自 _explored_cells 的所有键，默认只收集 Vector2i。
	for explored_cell in _explored_cells.keys():
		if explored_cell is Vector2i:
			result.append(explored_cell)

	return result


func get_explored_cells_version() -> int:
	return _explored_cells_version


func get_exploration_cell_size() -> float:
	return maxf(exploration_cell_size, 1.0)


func get_survival_time_seconds() -> float:
	return maxf(_survival_time_seconds, 0.0)


func has_extraction_point_spawned() -> bool:
	return _has_extraction_point


func is_extraction_point_marked_on_map() -> bool:
	return _extraction_point_marked_on_map


func is_player_inside_extraction_area() -> bool:
	return _player_inside_extraction_area


func is_extraction_ready_to_leave() -> bool:
	return _extraction_ready_to_leave


func get_extraction_hold_elapsed_seconds() -> float:
	return maxf(_extraction_hold_elapsed_seconds, 0.0)


func get_extraction_hold_duration_seconds() -> float:
	return maxf(extraction_hold_duration_seconds, 0.1)


func get_extraction_point_position() -> Vector2:
	return _extraction_point_position


func set_navigation_marker(marker_position: Vector2) -> void:
	_navigation_marker_position = _clamp_position_to_map(marker_position)
	_has_navigation_marker = true


func clear_navigation_marker() -> void:
	_has_navigation_marker = false
	_navigation_marker_position = Vector2.ZERO


func has_navigation_marker() -> bool:
	return _has_navigation_marker


func get_navigation_marker_position() -> Vector2:
	return _navigation_marker_position


func find_navigation_path(start_position: Vector2, end_position: Vector2, agent_radius: float = 24.0, navigation_cell_size: float = 96.0, max_path_points: int = 64) -> Array[Vector2]:
	# 路径结果；元素为世界坐标路点，默认空数组表示无法找到可用路径。
	var result: Array[Vector2] = []
	# 标准化寻路格尺寸；取值至少 16 像素，默认避免格子过小导致临时网格开销过大。
	var resolved_cell_size: float = maxf(navigation_cell_size, 16.0)
	# 标准化代理半径；取值至少为 0，默认用于匹配怪物碰撞体与墙体安全间距。
	var resolved_agent_radius: float = maxf(agent_radius, 0.0)
	# 缓存寻路网格；取值为按格子尺寸和代理半径缓存的 AStarGrid2D，默认复用地图障碍标记结果。
	var navigation_grid: AStarGrid2D = _get_cached_navigation_grid(resolved_cell_size, resolved_agent_radius)
	# 寻路区域；取值来自缓存网格，默认用于约束起点和终点格。
	var navigation_region: Rect2i = navigation_grid.region

	# 起点格坐标；取值为世界坐标转换结果并限制在寻路区域内。
	var start_cell: Vector2i = _clamp_navigation_cell_to_region(_world_position_to_navigation_cell(start_position, resolved_cell_size), navigation_region)
	# 终点格坐标；取值为世界坐标转换结果并限制在寻路区域内。
	var end_cell: Vector2i = _clamp_navigation_cell_to_region(_world_position_to_navigation_cell(end_position, resolved_cell_size), navigation_region)
	if navigation_grid.is_point_solid(start_cell):
		start_cell = _find_nearest_walkable_navigation_cell(navigation_grid, start_cell, navigation_region, 5)
	if navigation_grid.is_point_solid(end_cell):
		end_cell = _find_nearest_walkable_navigation_cell(navigation_grid, end_cell, navigation_region, 8)
	if navigation_grid.is_point_solid(start_cell) or navigation_grid.is_point_solid(end_cell):
		return result

	# 原始格路径；取值来自 AStarGrid2D，默认允许部分路径以便障碍复杂时仍能靠近目标。
	var raw_path: Array = navigation_grid.get_id_path(start_cell, end_cell, true)
	# 已加入路径点数量；取值从 0 开始，默认用于限制单次返回的路径长度。
	var added_point_count: int = 0
	# 最大路径点数量；取值至少为 1，默认避免极长路径让怪物缓存过多路点。
	var resolved_max_path_points: int = maxi(max_path_points, 1)
	# 原始路径格遍历项；取值可能为 Vector2i，默认逐项转换成世界坐标。
	for raw_path_cell in raw_path:
		if not (raw_path_cell is Vector2i):
			continue

		# 当前路径格；取值为 Vector2i，默认用于转换世界坐标路点。
		var path_cell: Vector2i = raw_path_cell
		# 当前路径点；取值为格子中心的世界坐标，默认作为怪物移动目标。
		var waypoint: Vector2 = _navigation_cell_to_world_position(path_cell, resolved_cell_size)
		if added_point_count == 0 and waypoint.distance_to(start_position) <= resolved_cell_size * 0.75:
			continue

		result.append(waypoint)
		added_point_count += 1
		if added_point_count >= resolved_max_path_points:
			break

	return result


func _get_cached_navigation_grid(navigation_cell_size: float, agent_radius: float) -> AStarGrid2D:
	# 导航缓存键；取值为格子尺寸和代理半径组合，默认区分不同怪物体积的寻路网格。
	var cache_key: String = _get_navigation_grid_cache_key(navigation_cell_size, agent_radius)
	if _navigation_grid_cache.has(cache_key) and _navigation_grid_cache[cache_key] is AStarGrid2D:
		# 已缓存导航网格；取值为对应格子尺寸和代理半径的 AStarGrid2D，默认直接复用障碍固化结果。
		var cached_navigation_grid: AStarGrid2D = _navigation_grid_cache[cache_key] as AStarGrid2D
		return cached_navigation_grid

	# 新建导航网格；取值为覆盖整张地图的 AStarGrid2D，默认禁用斜向移动避免穿墙角。
	var navigation_grid: AStarGrid2D = _build_navigation_grid(navigation_cell_size, agent_radius)
	_navigation_grid_cache[cache_key] = navigation_grid
	return navigation_grid


func _get_navigation_grid_cache_key(navigation_cell_size: float, agent_radius: float) -> String:
	return "%d:%d" % [roundi(navigation_cell_size), roundi(agent_radius)]


func _build_navigation_grid(navigation_cell_size: float, agent_radius: float) -> AStarGrid2D:
	# 地图半边长；取值来自当前地图配置，默认用于计算寻路网格覆盖范围。
	var half_size: float = get_map_half_size()
	# 最小格坐标；取值为地图左上角所在格，默认允许负格坐标覆盖以原点居中的地图。
	var min_cell: int = floori(-half_size / navigation_cell_size)
	# 最大格坐标；取值为地图右下角所在格，默认包含地图边界。
	var max_cell: int = ceili(half_size / navigation_cell_size)
	# 寻路区域起点；取值为左上格坐标，默认传给 AStarGrid2D.region。
	var region_position: Vector2i = Vector2i(min_cell, min_cell)
	# 寻路区域尺寸；取值为横纵格数量，默认覆盖整张地图。
	var region_size: Vector2i = Vector2i(max_cell - min_cell + 1, max_cell - min_cell + 1)
	# 寻路区域；取值为 AStarGrid2D 使用的格坐标矩形。
	var navigation_region: Rect2i = Rect2i(region_position, region_size)
	# 导航网格；取值为 AStarGrid2D，默认仅在首次请求对应配置时创建。
	var navigation_grid: AStarGrid2D = AStarGrid2D.new()
	navigation_grid.region = navigation_region
	navigation_grid.cell_size = Vector2(navigation_cell_size, navigation_cell_size)
	navigation_grid.offset = Vector2(navigation_cell_size * 0.5, navigation_cell_size * 0.5)
	navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation_grid.update()
	_mark_navigation_obstacles(navigation_grid, navigation_region, navigation_cell_size, agent_radius)
	return navigation_grid


func spawn_weapon_drop(weapon_data: Resource, drop_position: Vector2) -> bool:
	if weapon_data == null or weapon_drop_scene == null:
		return false

	# 掉落物实例；取值为 Node2D 或 null，默认由 weapon_drop_scene 实例化。
	var drop_instance: Node2D = weapon_drop_scene.instantiate() as Node2D
	if drop_instance == null:
		return false

	# 掉落物父节点；取值为 Drops 容器或 GameWorld，默认用于集中组织地面武器。
	var spawn_parent: Node = _drop_parent if _drop_parent != null else self
	spawn_parent.add_child(drop_instance)
	drop_instance.global_position = _clamp_position_to_map(drop_position)
	if drop_instance.has_method("configure_drop"):
		drop_instance.call("configure_drop", weapon_data)
	else:
		drop_instance.set("weapon_data", weapon_data)

	return true


func spawn_weapon_drop_near_player(weapon_data: Resource) -> bool:
	if weapon_data == null:
		return false

	# 丢弃中心点；取值为玩家当前位置或世界原点，默认用于从背包拖出武器时生成落点。
	var drop_center: Vector2 = _player.global_position if _player != null else Vector2.ZERO
	# 丢弃位置；取值为玩家附近随机点，默认尽量避免直接落入墙体。
	var drop_position: Vector2 = _get_scattered_drop_position(drop_center)
	return spawn_weapon_drop(weapon_data, drop_position)


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


func _begin_global_inventory_run() -> void:
	if _is_training_mode:
		return

	# 全局背包服务；默认由自动加载提供，正式骇入开始时记录本局物品快照用于撤离和失败结算。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory != null and global_inventory.has_method("begin_combat_run"):
		global_inventory.call("begin_combat_run")


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


func _update_survival_time(delta: float) -> void:
	if _is_player_dead():
		return

	_survival_time_seconds += maxf(delta, 0.0)
	if not _has_extraction_point and _survival_time_seconds >= maxf(extraction_spawn_time_seconds, 1.0):
		_spawn_extraction_point()

	if _has_extraction_point and not _extraction_point_marked_on_map and _survival_time_seconds >= maxf(extraction_map_marker_time_seconds, 1.0):
		_extraction_point_marked_on_map = true


func _update_extraction_state(delta: float) -> void:
	if not _has_extraction_point or _player == null or _is_player_dead():
		_player_inside_extraction_area = false
		_extraction_hold_elapsed_seconds = 0.0
		_extraction_ready_to_leave = false
		return

	_player_inside_extraction_area = _player.global_position.distance_to(_extraction_point_position) <= maxf(extraction_radius, 1.0)
	if not _player_inside_extraction_area:
		_extraction_hold_elapsed_seconds = 0.0
		_extraction_ready_to_leave = false
		return

	_extraction_hold_elapsed_seconds = minf(_extraction_hold_elapsed_seconds + maxf(delta, 0.0), get_extraction_hold_duration_seconds())
	_extraction_ready_to_leave = _extraction_hold_elapsed_seconds >= get_extraction_hold_duration_seconds()


func _spawn_extraction_point() -> void:
	if _has_extraction_point:
		return

	_extraction_point_position = _get_random_extraction_position()
	_extraction_point_node = _create_extraction_point_node(_extraction_point_position)
	_has_extraction_point = true
	_extraction_point_marked_on_map = _survival_time_seconds >= maxf(extraction_map_marker_time_seconds, 1.0)
	_player_inside_extraction_area = false
	_extraction_hold_elapsed_seconds = 0.0
	_extraction_ready_to_leave = false


func _create_extraction_point_node(point_position: Vector2) -> Node2D:
	# 撤离点根节点；取值为运行时创建的 Node2D，默认挂在 GameWorld 下并显示撤离范围。
	var extraction_point: Node2D = Node2D.new()
	extraction_point.name = "ExtractionPoint"
	extraction_point.add_to_group("extraction_points")
	add_child(extraction_point)
	extraction_point.global_position = point_position

	# 撤离范围填充；取值为 Polygon2D，默认绘制半透明圆形范围用于站位判断。
	var fill_polygon: Polygon2D = Polygon2D.new()
	fill_polygon.color = extraction_fill_color
	fill_polygon.polygon = _build_circle_points(maxf(extraction_radius, 1.0), 48, false)
	extraction_point.add_child(fill_polygon)

	# 撤离范围边框；取值为 Line2D，默认绘制闭合圆环便于玩家识别边界。
	var ring_line: Line2D = Line2D.new()
	ring_line.default_color = extraction_ring_color
	ring_line.width = 4.0
	ring_line.closed = true
	ring_line.points = _build_circle_points(maxf(extraction_radius, 1.0), 64, false)
	extraction_point.add_child(ring_line)

	# 撤离中心横线；取值为 Line2D，默认和竖线组成短十字用于定位中心点。
	var center_horizontal_line: Line2D = Line2D.new()
	center_horizontal_line.default_color = extraction_ring_color
	center_horizontal_line.width = 3.0
	center_horizontal_line.points = PackedVector2Array([
		Vector2(-14.0, 0.0),
		Vector2(14.0, 0.0)
	])
	extraction_point.add_child(center_horizontal_line)

	# 撤离中心竖线；取值为 Line2D，默认和横线组成短十字用于定位中心点。
	var center_vertical_line: Line2D = Line2D.new()
	center_vertical_line.default_color = extraction_ring_color
	center_vertical_line.width = 3.0
	center_vertical_line.points = PackedVector2Array([
		Vector2(0.0, -14.0),
		Vector2(0.0, 14.0)
	])
	extraction_point.add_child(center_vertical_line)
	return extraction_point


func _build_circle_points(radius: float, point_count: int, close_loop: bool) -> PackedVector2Array:
	# 圆点列表；元素为局部坐标，默认用于 Polygon2D 和 Line2D 绘制圆形撤离范围。
	var points: PackedVector2Array = PackedVector2Array()
	# 有效圆点数量；取值至少为 8，默认避免圆形视觉过于粗糙。
	var resolved_point_count: int = maxi(point_count, 8)
	# 圆点索引；取值为 0 到 resolved_point_count - 1，默认按角度均匀生成。
	for point_index in range(resolved_point_count):
		# 圆点角度；取值为 0 到 TAU 的弧度，默认用于计算当前圆周点。
		var point_angle: float = TAU * float(point_index) / float(resolved_point_count)
		points.append(Vector2.RIGHT.rotated(point_angle) * radius)

	if close_loop and not points.is_empty():
		points.append(points[0])

	return points


func _get_random_extraction_position() -> Vector2:
	# 撤离点尝试次数；取值来自检查器配置，默认用于寻找不被障碍遮挡的位置。
	var resolved_attempt_count: int = maxi(extraction_spawn_attempt_count, 1)
	# 撤离点尝试索引；取值为 0 到 resolved_attempt_count - 1，默认逐次测试候选位置。
	for _attempt_index in range(resolved_attempt_count):
		# 候选撤离位置；取值为地图内随机点，默认会继续校验玩家距离和环境障碍。
		var candidate_position: Vector2 = _get_random_extraction_candidate()
		if _is_extraction_position_valid(candidate_position):
			return candidate_position

	return _get_random_extraction_candidate()


func _get_random_extraction_candidate() -> Vector2:
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于限制撤离点候选范围。
	var half_size: float = get_map_half_size()
	# 有效边界留白；取值至少为撤离半径，默认避免撤离范围压到地图边界。
	var edge_margin: float = maxf(extraction_spawn_edge_margin, extraction_radius)
	# 有效生成边界；取值为半边长减边界留白，默认确保撤离点位于地图内部。
	var spawn_limit: float = maxf(0.0, half_size - edge_margin)
	return Vector2(
		_random.randf_range(-spawn_limit, spawn_limit),
		_random.randf_range(-spawn_limit, spawn_limit)
	)


func _is_extraction_position_valid(candidate_position: Vector2) -> bool:
	if _player != null and candidate_position.distance_to(_player.global_position) < maxf(extraction_spawn_min_distance_from_player, 0.0):
		return false

	if _is_position_blocked_by_environment(candidate_position, maxf(extraction_radius, 1.0)):
		return false

	return true


func _is_player_dead() -> bool:
	if _player == null:
		return false

	# 玩家属性组件；默认从玩家子节点 StatsComponent 获取，用于停止死亡后的存活计时和撤离进度。
	var stats_component: Node = _player.get_node_or_null("StatsComponent")
	if stats_component != null and stats_component.has_method("is_dead"):
		return bool(stats_component.call("is_dead"))

	return false


func _update_explored_cells_if_needed(delta: float) -> void:
	if _player == null:
		return

	_exploration_update_remaining = maxf(_exploration_update_remaining - maxf(delta, 0.0), 0.0)
	if _should_update_explored_cells():
		_update_explored_cells(false)


func _should_update_explored_cells() -> bool:
	if _player == null:
		return false

	if not _has_last_exploration_update_position:
		return true

	if _exploration_update_remaining <= 0.0:
		return true

	# 本次探索刷新距离阈值；取值至少为 0，默认让玩家快速移动时不等待固定计时器。
	var update_distance: float = maxf(exploration_update_distance, 0.0)
	if update_distance <= 0.0:
		return false

	return _player.global_position.distance_to(_last_exploration_update_position) >= update_distance


func _update_explored_cells(force_update: bool) -> void:
	if _player == null:
		return

	if not force_update and not _should_update_explored_cells():
		return

	_last_exploration_update_position = _player.global_position
	_has_last_exploration_update_position = true
	_exploration_update_remaining = maxf(exploration_update_interval, 0.02)
	# 是否新增探索格；取值为 true/false，默认只在实际扩展迷雾缓存时递增版本号。
	var explored_cells_changed: bool = false
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
			if _explored_cells.has(explored_cell):
				continue

			_explored_cells[explored_cell] = true
			explored_cells_changed = true

	if explored_cells_changed:
		_explored_cells_version += 1


func _world_position_to_exploration_cell(world_position: Vector2) -> Vector2i:
	# 有效探索格子尺寸；取值至少 1，默认防止配置错误导致除零。
	var cell_size: float = get_exploration_cell_size()
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.y / cell_size))


func _mark_navigation_obstacles(navigation_grid: AStarGrid2D, navigation_region: Rect2i, navigation_cell_size: float, agent_radius: float) -> void:
	# 障碍矩形遍历项；取值为世界坐标 Rect2，默认逐项写入寻路网格的不可通行格。
	for obstacle_rect in _environment_obstacle_rects:
		# 扩张后的障碍矩形；取值按怪物半径向外扩展，默认让路径与墙体保持安全距离。
		var expanded_rect: Rect2 = obstacle_rect.grow(agent_radius)
		# 障碍起始格；取值为扩张矩形左上角转换结果，默认用于标记格子范围。
		var start_cell: Vector2i = _world_position_to_navigation_cell(expanded_rect.position, navigation_cell_size)
		# 障碍结束格；取值为扩张矩形右下角转换结果，默认用于标记格子范围。
		var end_cell: Vector2i = _world_position_to_navigation_cell(expanded_rect.end, navigation_cell_size)
		# 障碍 X 格遍历；取值为障碍覆盖的横向格坐标范围。
		for cell_x in range(start_cell.x, end_cell.x + 1):
			# 障碍 Y 格遍历；取值为障碍覆盖的纵向格坐标范围。
			for cell_y in range(start_cell.y, end_cell.y + 1):
				# 当前障碍格；取值为 Vector2i，默认用于 AStarGrid2D 设置 solid。
				var obstacle_cell: Vector2i = Vector2i(cell_x, cell_y)
				if _is_navigation_cell_in_region(obstacle_cell, navigation_region):
					navigation_grid.set_point_solid(obstacle_cell, true)


func _world_position_to_navigation_cell(world_position: Vector2, navigation_cell_size: float) -> Vector2i:
	# 有效寻路格尺寸；取值至少 1，默认防止转换时除零。
	var resolved_cell_size: float = maxf(navigation_cell_size, 1.0)
	return Vector2i(floori(world_position.x / resolved_cell_size), floori(world_position.y / resolved_cell_size))


func _navigation_cell_to_world_position(navigation_cell: Vector2i, navigation_cell_size: float) -> Vector2:
	# 有效寻路格尺寸；取值至少 1，默认用于把格坐标转换成世界坐标。
	var resolved_cell_size: float = maxf(navigation_cell_size, 1.0)
	# 格坐标浮点值；取值来自 Vector2i 的 x/y，默认用于安全转换成世界坐标。
	var cell_position: Vector2 = Vector2(float(navigation_cell.x), float(navigation_cell.y))
	# 格子中心世界坐标；取值为格坐标加半格偏移，默认让怪物朝格子中心移动。
	var world_position: Vector2 = (cell_position + Vector2(0.5, 0.5)) * resolved_cell_size
	return _clamp_position_to_map(world_position)


func _is_navigation_cell_in_region(navigation_cell: Vector2i, navigation_region: Rect2i) -> bool:
	if navigation_cell.x < navigation_region.position.x or navigation_cell.y < navigation_region.position.y:
		return false
	if navigation_cell.x >= navigation_region.end.x or navigation_cell.y >= navigation_region.end.y:
		return false

	return true


func _clamp_navigation_cell_to_region(navigation_cell: Vector2i, navigation_region: Rect2i) -> Vector2i:
	return Vector2i(
		clampi(navigation_cell.x, navigation_region.position.x, navigation_region.end.x - 1),
		clampi(navigation_cell.y, navigation_region.position.y, navigation_region.end.y - 1)
	)


func _find_nearest_walkable_navigation_cell(navigation_grid: AStarGrid2D, origin_cell: Vector2i, navigation_region: Rect2i, max_search_radius: int) -> Vector2i:
	if _is_navigation_cell_in_region(origin_cell, navigation_region) and not navigation_grid.is_point_solid(origin_cell):
		return origin_cell

	# 标准化搜索半径；取值至少为 0，默认用于限制向外寻找可走格的范围。
	var resolved_max_radius: int = maxi(max_search_radius, 0)
	# 搜索半径遍历；取值从 1 到最大半径，默认逐圈向外找最近可走格。
	for search_radius in range(1, resolved_max_radius + 1):
		# X 偏移遍历；取值为当前搜索圈的横向偏移。
		for offset_x in range(-search_radius, search_radius + 1):
			# Y 偏移遍历；取值为当前搜索圈的纵向偏移。
			for offset_y in range(-search_radius, search_radius + 1):
				if abs(offset_x) != search_radius and abs(offset_y) != search_radius:
					continue

				# 候选格；取值为原始格加当前偏移，默认用于测试是否可通行。
				var candidate_cell: Vector2i = origin_cell + Vector2i(offset_x, offset_y)
				if not _is_navigation_cell_in_region(candidate_cell, navigation_region):
					continue
				if not navigation_grid.is_point_solid(candidate_cell):
					return candidate_cell

	return origin_cell


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


func _spawn_monster_batch(requested_count: int = -1) -> void:
	# 实际生成数量；负值使用开局配置，补充刷新会传入当前缺口对应的批次数量。
	var resolved_spawn_count: int = monster_spawn_count if requested_count < 0 else requested_count
	if not _has_monster_scene_available() or resolved_spawn_count <= 0:
		return

	# 怪物挂载父节点；取值为 Enemies 容器或 GameWorld，默认用于组织随机生成物。
	var spawn_parent: Node = _monster_parent if _monster_parent != null else self
	# 怪物生成循环索引；取值为 0 到实际生成数量减一，默认逐个生成并分散到整张地图。
	for _spawn_index in range(resolved_spawn_count):
		# 本次怪物场景；取值来自 monster_scenes 随机池或 monster_scene 兜底，默认用于生成不同怪物类型。
		var selected_monster_scene: PackedScene = _get_random_monster_scene()
		if selected_monster_scene == null:
			continue

		# 怪物实例；取值为 Node2D 或 null，默认由选中的怪物场景实例化，修改会影响生成对象。
		var monster: Node2D = selected_monster_scene.instantiate() as Node2D
		if monster == null:
			continue

		_apply_monster_spawn_variation(monster)
		monster.add_to_group(TRAINING_MONSTER_GROUP)
		spawn_parent.add_child(monster)
		monster.global_position = _get_random_monster_spawn_position()
		if monster.has_signal("died"):
			monster.connect("died", Callable(self, "_on_monster_died").bind(monster))
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


func _update_monster_replenishment(delta: float) -> void:
	if _is_training_mode or monster_minimum_alive_count <= 0:
		return

	_monster_replenish_remaining = maxf(_monster_replenish_remaining - delta, 0.0)
	if _monster_replenish_remaining > 0.0:
		return
	_monster_replenish_remaining = maxf(monster_replenish_interval, 0.1)

	# 当前存活敌人数；取值为怪物组内有效且未排队释放的节点数量。
	var alive_monster_count: int = _get_alive_monster_count()
	if alive_monster_count >= monster_minimum_alive_count:
		return

	# 当前敌人缺口；取值为最低数量减存活数量，用于限制单次补充不会超过目标总数。
	var monster_deficit: int = monster_minimum_alive_count - alive_monster_count
	# 本次补充数量；取值为缺口与批次上限较小值，避免瞬间生成过多节点。
	var replenish_count: int = mini(monster_deficit, maxi(monster_replenish_batch_size, 1))
	_spawn_monster_batch(replenish_count)


func _get_alive_monster_count() -> int:
	# 存活数量；默认从 0 开始统计组内有效敌人。
	var alive_count: int = 0
	# 怪物组成员；取值可能包含即将释放节点，默认逐项校验。
	var grouped_monsters: Array = get_tree().get_nodes_in_group(TRAINING_MONSTER_GROUP)
	# 怪物组遍历项；取值为 Variant，只统计有效 Node 且未排队释放的成员。
	for grouped_monster in grouped_monsters:
		if grouped_monster is Node and is_instance_valid(grouped_monster) and not (grouped_monster as Node).is_queued_for_deletion():
			alive_count += 1
	return alive_count


func _apply_monster_spawn_variation(monster: Node2D) -> void:
	if monster == null:
		return

	# 标准化波动比例；取值为 0 到 0.9，默认 0.3 形成 70% 到 130% 范围。
	var variation_ratio: float = clampf(monster_spawn_variation_ratio, 0.0, 0.9)
	# 尺寸倍率；取值在 1±波动范围内，每只敌人独立随机并直接影响视觉与碰撞尺寸。
	var size_multiplier: float = _random.randf_range(1.0 - variation_ratio, 1.0 + variation_ratio)
	# 属性倍率；与尺寸独立随机，避免大体型敌人必然拥有完全相同强度趋势。
	var attribute_multiplier: float = _random.randf_range(1.0 - variation_ratio, 1.0 + variation_ratio)
	if monster.has_method("apply_spawn_variation"):
		monster.call("apply_spawn_variation", size_multiplier, attribute_multiplier)
	else:
		monster.scale *= Vector2(size_multiplier, size_multiplier)


func _on_monster_died(monster_node: Node) -> void:
	if monster_node == null or not (monster_node is Node2D):
		return

	_try_spawn_monster_weapon_drop(monster_node as Node2D)


func _try_spawn_monster_weapon_drop(monster_node: Node2D) -> void:
	if weapon_drop_table.is_empty() or weapon_drop_scene == null:
		return

	# 怪物武器掉落概率；取值来自怪物 weapon_drop_chance，默认 0.03，修改会影响当前怪物死亡掉落判定。
	var drop_chance: float = _get_monster_weapon_drop_chance(monster_node)
	if drop_chance <= 0.0 or _random.randf() > drop_chance:
		return

	# 掉落武器资源；取值为随机武器资源的深拷贝，默认让每个地面武器成为独立物品实例。
	var dropped_weapon: Resource = _get_random_weapon_drop_data()
	if dropped_weapon == null:
		return

	spawn_weapon_drop(dropped_weapon, monster_node.global_position)


func _get_monster_weapon_drop_chance(monster_node: Node) -> float:
	if monster_node == null:
		return 0.0

	# 原始掉落概率；取值可能来自怪物导出属性，默认转为 0 到 1 范围。
	var raw_drop_chance: Variant = monster_node.get("weapon_drop_chance")
	if raw_drop_chance == null:
		return 0.03

	return clampf(float(raw_drop_chance), 0.0, 1.0)


func _get_random_weapon_drop_data() -> Resource:
	if weapon_drop_table.is_empty():
		return null

	# 武器池随机下标；取值为 0 到武器池末尾，默认用于随机选择掉落模板。
	var weapon_index: int = _random.randi_range(0, weapon_drop_table.size() - 1)
	# 武器模板资源；取值来自 weapon_drop_table，默认会深拷贝为独立掉落物。
	var weapon_template: Resource = weapon_drop_table[weapon_index]
	if weapon_template == null:
		return null

	# 独立武器资源；取值为模板深拷贝，默认避免多个掉落物共享同一个资源实例。
	var dropped_weapon: Resource = weapon_template.duplicate(true) as Resource
	return dropped_weapon if dropped_weapon != null else weapon_template


func _get_scattered_drop_position(center_position: Vector2) -> Vector2:
	# 丢弃尝试次数；取值为固定 8 次，默认用于尽量避开环境墙体。
	var scatter_attempt_count: int = 8
	# 标准化散落半径；取值至少为 0，默认控制丢弃武器离玩家多远。
	var scatter_radius: float = maxf(dropped_weapon_scatter_radius, 0.0)
	for _attempt_index in range(scatter_attempt_count):
		# 散落角度；取值为 0 到 TAU 的随机弧度，默认让丢弃落点不完全固定。
		var scatter_angle: float = _random.randf_range(0.0, TAU)
		# 散落距离；取值为半径的 45% 到 100%，默认避免武器直接压在玩家中心。
		var scatter_distance: float = _random.randf_range(scatter_radius * 0.45, scatter_radius)
		# 候选位置；取值为中心点加随机偏移并夹到地图内。
		var candidate_position: Vector2 = _clamp_position_to_map(center_position + Vector2.RIGHT.rotated(scatter_angle) * scatter_distance)
		if not _is_position_blocked_by_environment(candidate_position, 18.0):
			return candidate_position

	return _clamp_position_to_map(center_position)


func _free_monster_node(monster_node: Node) -> void:
	if monster_node == null or not is_instance_valid(monster_node):
		return

	if monster_node.get_parent() != null:
		monster_node.get_parent().remove_child(monster_node)

	monster_node.free()


func _get_random_monster_spawn_position() -> Vector2:
	# 怪物生成尝试次数；取值为固定 48 次，默认用于同时满足玩家安全距离、地图边界和障碍避让。
	var spawn_attempt_count: int = 48
	# 怪物生成尝试索引；取值为 0 到 spawn_attempt_count - 1，默认逐次寻找不被障碍覆盖的位置。
	for _attempt_index in range(spawn_attempt_count):
		# 候选生成点；取值来自环形随机位置并夹取到地图内，默认用于检测是否避开环境障碍。
		var candidate_position: Vector2 = _get_random_monster_spawn_candidate()
		if _player != null and candidate_position.distance_to(_player.global_position) < monster_spawn_min_distance:
			continue
		if not _is_position_blocked_by_environment(candidate_position, 36.0):
			return candidate_position

	return _get_random_monster_spawn_candidate()


func _get_random_monster_spawn_candidate() -> Vector2:
	if monster_spawn_across_full_map:
		# 地图半边长；取值来自当前地图尺寸，用于整图均匀采样。
		var half_size: float = get_map_half_size()
		# 实际边界留白；取值至少为一个网格尺寸且不超过地图半边长，防止生成区反转。
		var edge_margin: float = clampf(maxf(monster_spawn_edge_margin, grid_size), 0.0, maxf(half_size - 1.0, 0.0))
		# 可生成坐标上限；取值为地图半边长减留白，默认在正负范围内均匀分布。
		var spawn_limit: float = maxf(half_size - edge_margin, 1.0)
		return Vector2(
			_random.randf_range(-spawn_limit, spawn_limit),
			_random.randf_range(-spawn_limit, spawn_limit)
		)

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
