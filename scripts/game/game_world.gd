extends Node2D

## 游戏世界场景负责提供当前关卡的基础承载环境。
## 玩家、敌人、掉落物、地图装饰都可以作为它的子节点存在。
## 这里先绘制一张调试网格，帮助确认移动、瞄准、弹道和距离感是否符合预期。

## 调试网格单格尺寸；取值应大于 0，默认 64 匹配常见 2D 地图尺度，运行时修改会改变距离参照密度。
@export var grid_size: float = 64.0
## 调试网格向每个方向延伸的格数；取值应为正整数，默认 24 覆盖初始活动区域，运行时修改会改变网格可视范围。
@export var grid_extent: int = 24
## 背景填充颜色；取值为 RGBA，默认深色用于突出角色和弹体，运行时修改只影响关卡背景观感。
@export var background_color: Color = Color(0.055, 0.07, 0.09, 1.0)
## 普通网格线颜色；取值为 RGBA，默认低透明度避免干扰战斗观察，运行时修改会影响非坐标轴网格可见度。
@export var grid_color: Color = Color(0.18, 0.25, 0.30, 0.42)
## 坐标轴网格线颜色；取值为 RGBA，默认更亮用于定位世界原点，运行时修改会影响原点参照识别。
@export var axis_color: Color = Color(0.28, 0.52, 0.72, 0.62)
## 玩家节点路径；默认指向当前场景 SilverWolf，必须解析到 Node2D，修改会影响怪物索敌目标。
@export var player_path: NodePath = ^"SilverWolf"
## 训练场怪物场景；默认由 game_world.tscn 指向 BasicMonster，必须实例化为 Node2D，修改会影响随机生成的敌人类型。
@export var monster_scene: PackedScene
## 训练场怪物生成数量；取值建议 0 到 64，默认 8，运行时修改会影响开局战斗压力。
@export_range(0, 64, 1) var monster_spawn_count: int = 8
## 怪物生成最小距离；取值应大于等于 0，默认 280 像素，运行时修改会影响怪物是否离玩家过近。
@export_range(0.0, 4000.0, 1.0) var monster_spawn_min_distance: float = 280.0
## 怪物生成最大距离；取值应大于最小距离，默认 900 像素，运行时修改会影响怪物分布范围。
@export_range(1.0, 8000.0, 1.0, "or_greater") var monster_spawn_max_distance: float = 900.0
## 怪物父节点路径；默认指向 Enemies 容器，允许为空并回退到 GameWorld，修改会影响怪物节点层级。
@export var monster_parent_path: NodePath = ^"Enemies"

## 随机数生成器；默认新建并在 ready 随机化，修改会影响训练场怪物刷新位置。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

## 玩家节点缓存；默认按 player_path 获取，允许为空并以世界原点作为生成中心。
@onready var _player: Node2D = get_node_or_null(player_path) as Node2D
## 怪物父节点缓存；默认按 monster_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _monster_parent: Node = get_node_or_null(monster_parent_path)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_random.randomize()
	_spawn_test_monsters()


func _draw() -> void:
	# 网格半边长；取值由 grid_size 和 grid_extent 计算，无固定默认值，修改会影响背景矩形和线段端点。
	var half_size: float = grid_size * float(grid_extent)
	# 背景绘制区域；取值为以世界原点居中的 Rect2，无固定默认值，修改会影响可视背景覆盖范围。
	var play_area: Rect2 = Rect2(Vector2(-half_size, -half_size), Vector2(half_size * 2.0, half_size * 2.0))
	draw_rect(play_area, background_color, true)

	# 网格线循环索引；取值范围为 -grid_extent 到 grid_extent，默认由网格范围生成，修改循环范围会影响绘制线条数量。
	for index in range(-grid_extent, grid_extent + 1):
		# 当前网格线偏移；取值由循环索引乘单格尺寸得出，无固定默认值，修改会移动当前线段位置。
		var offset: float = float(index) * grid_size
		# 当前网格线颜色；原点轴使用 axis_color，其余使用 grid_color，修改会影响当前线段视觉层级。
		var color: Color = axis_color if index == 0 else grid_color
		draw_line(Vector2(offset, -half_size), Vector2(offset, half_size), color, 1.0)
		draw_line(Vector2(-half_size, offset), Vector2(half_size, offset), color, 1.0)


func _spawn_test_monsters() -> void:
	if monster_scene == null or monster_spawn_count <= 0:
		return

	# 怪物挂载父节点；取值为 Enemies 容器或 GameWorld，默认用于组织训练场生成物。
	var spawn_parent: Node = _monster_parent if _monster_parent != null else self
	# 怪物生成循环索引；取值为 0 到 monster_spawn_count - 1，默认逐个生成怪物，修改循环范围会影响生成数量。
	for _spawn_index in range(monster_spawn_count):
		# 怪物实例；取值为 Node2D 或 null，默认由 monster_scene 实例化，修改会影响生成对象。
		var monster: Node2D = monster_scene.instantiate() as Node2D
		if monster == null:
			continue

		spawn_parent.add_child(monster)
		monster.global_position = _get_random_monster_spawn_position()
		if monster.has_method("set_target"):
			monster.call("set_target", _player)


func clear_monsters() -> void:
	# 怪物挂载父节点；取值为 Enemies 容器或 GameWorld，默认用于查找需要清空的测试怪物。
	var spawn_parent: Node = _monster_parent if _monster_parent != null else self
	# 现有怪物节点遍历项；取值为怪物父节点下的子节点，默认全部移除，修改循环来源会影响清怪范围。
	for monster_node in spawn_parent.get_children():
		spawn_parent.remove_child(monster_node)
		monster_node.queue_free()


func respawn_monsters() -> void:
	clear_monsters()
	_spawn_test_monsters()


func _get_random_monster_spawn_position() -> Vector2:
	# 生成中心点；取值为玩家位置或世界原点，默认让怪物围绕玩家随机刷新。
	var spawn_center: Vector2 = _player.global_position if _player != null else Vector2.ZERO
	# 标准化最大生成距离；取值至少为最小距离，默认防止配置错误导致随机范围反转。
	var resolved_max_distance: float = maxf(monster_spawn_max_distance, monster_spawn_min_distance)
	# 本次生成角度；取值为 0 到 TAU 的随机弧度，默认用于环形分布。
	var spawn_angle: float = _random.randf_range(0.0, TAU)
	# 本次生成距离；取值为最小到最大生成距离，默认用于控制怪物远近。
	var spawn_distance: float = _random.randf_range(monster_spawn_min_distance, resolved_max_distance)
	return spawn_center + Vector2.RIGHT.rotated(spawn_angle) * spawn_distance
