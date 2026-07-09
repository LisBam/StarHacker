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


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
