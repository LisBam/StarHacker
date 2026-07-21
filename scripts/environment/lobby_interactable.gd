extends StaticBody2D
class_name LobbyInteractable

## 大厅交互实体是具有固定碰撞体积的不可移动设施占位物。
## 当前统一显示为实体按钮，后续可替换视觉子节点而不改变 action_id、距离查询或大厅动作路由协议。

## 交互动作标识；默认空字符串表示不执行业务，必须与主菜单面板宿主公开的大厅动作协议一致。
@export var action_id: String = ""
## 实体显示名称；默认“交互设施”，会显示在世界实体与大厅 HUD 的靠近提示中。
@export var display_name: String = "交互设施"
## 实体按钮尺寸；默认 150×72 像素，同时控制视觉矩形、碰撞体积与边缘距离计算，运行时通常不动态修改。
@export var body_size: Vector2 = Vector2(150.0, 72.0)
## 从实体碰撞边缘向外延伸的可交互距离；默认 120 像素，修改会影响玩家可按 F 触发设施的范围。
@export_range(1.0, 512.0, 1.0, "or_greater") var interaction_radius: float = 120.0
## 实体常态填充颜色；默认深青黑色，后续替换物品视觉时可保留碰撞与交互协议而隐藏该占位层。
@export var body_color: Color = Color(0.04, 0.12, 0.15, 1.0)
## 实体常态边框颜色；默认弱青蓝色，用于在大厅地面上区分实体设施轮廓。
@export var border_color: Color = Color(0.28, 0.64, 0.72, 1.0)
## 实体成为当前最近目标时的边框颜色；默认亮青色，只提供视觉反馈，不改变交互距离或动作资格。
@export var highlighted_border_color: Color = Color(0.64, 0.96, 1.0, 1.0)

## 当前是否为大厅交互组件选中的最近目标；默认 false，状态变化只更新占位实体边框与文字颜色。
var _is_interaction_highlighted: bool = false

## 实体填充多边形缓存；默认绑定 Body 节点，尺寸由 body_size 在 ready 阶段统一生成。
@onready var _body_polygon: Polygon2D = get_node("Body") as Polygon2D
## 实体边框线缓存；默认绑定 Border 节点，当前目标变化时只更新颜色而不重建节点。
@onready var _border_line: Line2D = get_node("Border") as Line2D
## 实体名称标签缓存；默认绑定 DisplayNameLabel，内容来自 display_name，后续视觉预制体可替换该节点。
@onready var _display_name_label: Label = get_node("DisplayNameLabel") as Label
## 实体交互键标签缓存；默认绑定 InteractionKeyLabel，固定显示 F 作为当前默认交互键提示。
@onready var _interaction_key_label: Label = get_node("InteractionKeyLabel") as Label
## 实体碰撞形状缓存；默认绑定 CollisionShape2D 并复制矩形资源，避免多个实例修改同一共享形状。
@onready var _collision_shape: CollisionShape2D = get_node("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	_configure_placeholder_visual()
	set_interaction_highlighted(false)


func get_interaction_action_id() -> String:
	## 返回稳定大厅动作标识；大厅世界只路由该值，不读取实体节点名或显示文本。
	return action_id


func get_interaction_display_name() -> String:
	## 返回面向玩家的设施名称；HUD 使用该值构建靠近提示。
	return display_name


func get_interaction_distance_squared(world_position: Vector2) -> float:
	## 返回世界坐标到矩形碰撞边缘的最短距离平方；玩家靠近长边时不会被中心点距离错误拒绝。
	# 实体局部坐标；StaticBody2D 可旋转或缩放时仍以本地轴对齐按钮范围计算最近点。
	var local_position: Vector2 = to_local(world_position)
	# 矩形半尺寸；每个轴至少 1 像素，异常检查器数值不会产生负范围。
	var half_size: Vector2 = Vector2(maxf(body_size.x, 2.0), maxf(body_size.y, 2.0)) * 0.5
	# 超出矩形的轴向距离；位于碰撞矩形投影内部的轴返回 0。
	var edge_delta: Vector2 = Vector2(maxf(absf(local_position.x) - half_size.x, 0.0), maxf(absf(local_position.y) - half_size.y, 0.0))
	return edge_delta.length_squared()


func is_world_position_in_interaction_range(world_position: Vector2) -> bool:
	## 判断坐标是否位于实体边缘 interaction_radius 范围内，供交互组件统一筛选候选目标。
	return get_interaction_distance_squared(world_position) <= interaction_radius * interaction_radius


func set_interaction_highlighted(highlighted: bool) -> void:
	## 更新当前目标视觉；设施实体保持不可移动、不可破坏，不因高亮改变碰撞层或监测状态。
	_is_interaction_highlighted = highlighted
	if _border_line != null:
		_border_line.default_color = highlighted_border_color if _is_interaction_highlighted else border_color
		_border_line.width = 3.0 if _is_interaction_highlighted else 2.0
	if _display_name_label != null:
		_display_name_label.modulate = highlighted_border_color if _is_interaction_highlighted else Color.WHITE


func _configure_placeholder_visual() -> void:
	# 安全实体尺寸；每个轴至少 2 像素，避免矩形形状或标签区域退化为空。
	var resolved_size: Vector2 = Vector2(maxf(body_size.x, 2.0), maxf(body_size.y, 2.0))
	# 实体半尺寸；用于生成以节点原点为中心的多边形与闭合边框点。
	var half_size: Vector2 = resolved_size * 0.5
	_body_polygon.color = body_color
	_body_polygon.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	_border_line.points = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
		Vector2(-half_size.x, -half_size.y),
	])
	_display_name_label.position = Vector2(-half_size.x + 6.0, -18.0)
	_display_name_label.size = Vector2(resolved_size.x - 12.0, 28.0)
	_display_name_label.text = display_name
	_interaction_key_label.position = Vector2(-half_size.x + 6.0, 10.0)
	_interaction_key_label.size = Vector2(resolved_size.x - 12.0, 20.0)
	# 独立矩形形状；默认新建资源，原节点已经配置矩形时复制后再修改，避免多个大厅设施共享状态。
	var rectangle_shape: RectangleShape2D = RectangleShape2D.new()
	if _collision_shape.shape is RectangleShape2D:
		rectangle_shape = (_collision_shape.shape as RectangleShape2D).duplicate() as RectangleShape2D
	rectangle_shape.size = resolved_size
	_collision_shape.shape = rectangle_shape
