extends Node2D
class_name SkillTargetingVisual

## 技能瞄准视觉只负责绘制当前主动技能的方向扇形、位置范围、索敌圆和锁定目标标记。
## ActiveSkillComponent 注入只读技能配置与瞄准结果，视觉节点不参与目标合法性或释放结算。

## 指向技能类型编号；固定 0，与 ActiveSkillData 数据协议保持一致。
const TARGETING_DIRECTIONAL: int = 0
## 锁定目标技能类型编号；固定 1，与 ActiveSkillData 数据协议保持一致。
const TARGETING_TARGET_LOCK: int = 1
## 位置指向输入编号；固定 1，与 ActiveSkillData 数据协议保持一致。
const DIRECTIONAL_INPUT_POSITION: int = 1
## 可绘制距离与标记半径安全下限；固定 1 像素，避免异常资源生成退化图形。
const MINIMUM_DRAW_RADIUS: float = 1.0
## 扇形采样段数安全下限；固定 4 段，保证范围填充至少形成可辨认外弧。
const MINIMUM_SECTOR_SEGMENT_COUNT: int = 4
## 完整圆弧采样段数安全下限；固定 8 段，避免圆形范围退化为多边形尖角。
const MINIMUM_CIRCLE_SEGMENT_COUNT: int = 8
## 技能扇形最大半角；固定 180 度，与 ActiveSkillData 导出范围一致。
const MAXIMUM_HALF_ANGLE_DEGREES: float = 180.0
## 扇形角跨度倍率；固定 2，使半角区间转换为完整左右角跨度。
const SECTOR_ANGLE_SPAN_MULTIPLIER: float = 2.0

## 指向范围填充颜色；默认半透明青蓝色，修改只影响瞄准阶段视觉，不影响技能命中范围。
@export var directional_fill_color: Color = Color(0.22, 0.82, 1.0, 0.14)
## 指向范围边缘颜色；默认高亮青蓝色，修改只影响扇形和圆形轮廓。
@export var directional_outline_color: Color = Color(0.35, 0.92, 1.0, 0.88)
## 锁定索敌范围颜色；默认半透明紫色，用于区分锁定目标技能与方向技能。
@export var target_lock_range_color: Color = Color(0.72, 0.46, 1.0, 0.78)
## 锁定目标标记颜色；默认亮金色，鼠标移动切换目标时圆环会跟随当前合法目标。
@export var locked_target_color: Color = Color(1.0, 0.82, 0.28, 0.96)
## 位置指向标记颜色；默认浅青色，用于显示限制在最大释放距离内的目标位置。
@export var target_position_color: Color = Color(0.42, 1.0, 0.86, 0.92)
## 范围轮廓线宽；默认 2 像素，修改只影响所有技能范围线条粗细。
@export_range(0.5, 12.0, 0.5) var outline_width: float = 2.0
## 扇形采样段数；默认 32 段，在视觉平滑度和绘制开销之间取得平衡，运行时通常不动态修改。
@export_range(4, 128, 1) var sector_segment_count: int = 32
## 位置目标标记填充透明度；默认 0.16，只影响瞄准视觉，不改变实际释放位置。
@export_range(0.0, 1.0, 0.01) var target_position_fill_opacity: float = 0.16
## 位置目标标记圆弧段数；默认 24 段，修改只影响圆环平滑度。
@export_range(4, 128, 1) var target_position_segment_count: int = 24
## 锁定索敌范围填充透明度；默认 0.06，保持完整索敌圆不遮挡战斗画面。
@export_range(0.0, 1.0, 0.01) var target_lock_range_fill_opacity: float = 0.06
## 锁定目标标记填充透明度；默认 0.14，用于突出当前目标且不遮盖其精灵。
@export_range(0.0, 1.0, 0.01) var locked_target_fill_opacity: float = 0.14
## 锁定目标标记圆弧段数；默认 28 段，修改只影响圆环平滑度。
@export_range(4, 128, 1) var locked_target_segment_count: int = 28
## 锁定目标十字相对标记半径的长度倍率；默认 1.3，修改只影响目标识别视觉。
@export_range(0.5, 4.0, 0.05) var locked_target_cross_radius_multiplier: float = 1.3

## 当前是否显示瞄准视觉；默认 false，技能按下并通过冷却与资源预检后才启用。
var _is_active: bool = false
## 当前技能资源；默认 null，由主动技能组件在开始瞄准时注入，只读取范围和类型字段。
var _skill_data: Resource
## 当前瞄准方向；默认向右，指向技能按鼠标位置持续更新为单位向量。
var _aim_direction: Vector2 = Vector2.RIGHT
## 当前目标位置相对角色的局部坐标；默认零向量，位置指向技能会限制到技能最大距离。
var _target_local_position: Vector2 = Vector2.ZERO
## 当前锁定目标相对角色的局部坐标；默认零向量，仅在 _has_locked_target 为 true 时用于绘制。
var _locked_target_local_position: Vector2 = Vector2.ZERO
## 当前是否存在合法锁定目标；默认 false，无目标时只显示索敌范围圆而不绘制目标标记。
var _has_locked_target: bool = false


func show_targeting(skill_data: Resource) -> void:
	## 开始显示指定技能的瞄准视觉；无效资源会保持隐藏，避免绘制缺少范围的占位技能。
	_skill_data = skill_data
	_is_active = _skill_data != null
	visible = _is_active
	queue_redraw()


func update_targeting(aim_direction: Vector2, target_world_position: Vector2, locked_target: Node2D) -> void:
	## 更新当前鼠标瞄准和锁定结果；世界坐标统一转换为本节点局部坐标，适配玩家移动与相机变化。
	if not aim_direction.is_zero_approx():
		_aim_direction = aim_direction.normalized()
	_target_local_position = to_local(target_world_position)
	_has_locked_target = is_instance_valid(locked_target)
	_locked_target_local_position = to_local(locked_target.global_position) if _has_locked_target else Vector2.ZERO
	queue_redraw()


func hide_targeting() -> void:
	## 停止并清空瞄准视觉；技能释放、取消、角色切换和输入禁用都会调用该入口。
	_is_active = false
	_skill_data = null
	_has_locked_target = false
	visible = false
	queue_redraw()


func _draw() -> void:
	if not _is_active or _skill_data == null:
		return
	# 技能索敌类型；0 为指向、1 为锁定目标、2 为无索敌，无索敌不绘制范围。
	var targeting_mode: int = int(_skill_data.get("targeting_mode"))
	# 技能有效范围；至少 1 像素，防止错误资源生成退化圆形或扇形。
	var cast_range: float = maxf(float(_skill_data.get("cast_range")), MINIMUM_DRAW_RADIUS)
	if targeting_mode == TARGETING_DIRECTIONAL:
		_draw_directional_targeting(cast_range)
	elif targeting_mode == TARGETING_TARGET_LOCK:
		_draw_target_locking(cast_range)


func _draw_directional_targeting(cast_range: float) -> void:
	# 指向输入模式；0 绘制方向扇形，1 绘制完整释放圆和目标位置圆环。
	var directional_input_mode: int = int(_skill_data.get("directional_input_mode"))
	if directional_input_mode == DIRECTIONAL_INPUT_POSITION:
		draw_arc(Vector2.ZERO, cast_range, 0.0, TAU, maxi(sector_segment_count, MINIMUM_CIRCLE_SEGMENT_COUNT), directional_outline_color, outline_width, true)
		# 位置标记半径；至少 1 像素，取值来自技能资源以适配不同范围效果体积。
		var marker_radius: float = maxf(float(_skill_data.get("target_marker_radius")), MINIMUM_DRAW_RADIUS)
		draw_circle(_target_local_position, marker_radius, Color(target_position_color, target_position_fill_opacity))
		draw_arc(_target_local_position, marker_radius, 0.0, TAU, maxi(target_position_segment_count, MINIMUM_CIRCLE_SEGMENT_COUNT), target_position_color, outline_width, true)
		return
	# 扇形半角弧度；限制到 0 至 PI，180 度时覆盖完整圆形范围。
	var half_angle: float = deg_to_rad(clampf(float(_skill_data.get("directional_half_angle_degrees")), 0.0, MAXIMUM_HALF_ANGLE_DEGREES))
	# 扇形中心角；由当前瞄准方向提供，默认向右。
	var center_angle: float = _aim_direction.angle()
	# 扇形顶点；第一个点固定为角色中心，其余点沿外弧采样形成填充多边形。
	var sector_points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	# 实际采样段数；至少 4 段，半角越大仍保持稳定平滑度。
	var resolved_segment_count: int = maxi(sector_segment_count, MINIMUM_SECTOR_SEGMENT_COUNT)
	for segment_index in range(resolved_segment_count + 1):
		# 当前外弧角度；从中心角减半角均匀推进到中心角加半角。
		var sample_angle: float = center_angle - half_angle + half_angle * SECTOR_ANGLE_SPAN_MULTIPLIER * float(segment_index) / float(resolved_segment_count)
		sector_points.append(Vector2.RIGHT.rotated(sample_angle) * cast_range)
	draw_colored_polygon(sector_points, directional_fill_color)
	# 扇形左右边缘终点；与外弧共同明确实际释放区域。
	var left_edge: Vector2 = Vector2.RIGHT.rotated(center_angle - half_angle) * cast_range
	# 扇形右边缘终点；从角色中心连接到外弧另一端。
	var right_edge: Vector2 = Vector2.RIGHT.rotated(center_angle + half_angle) * cast_range
	draw_line(Vector2.ZERO, left_edge, directional_outline_color, outline_width, true)
	draw_line(Vector2.ZERO, right_edge, directional_outline_color, outline_width, true)
	draw_arc(Vector2.ZERO, cast_range, center_angle - half_angle, center_angle + half_angle, resolved_segment_count, directional_outline_color, outline_width, true)


func _draw_target_locking(cast_range: float) -> void:
	draw_circle(Vector2.ZERO, cast_range, Color(target_lock_range_color, target_lock_range_fill_opacity))
	draw_arc(Vector2.ZERO, cast_range, 0.0, TAU, maxi(sector_segment_count, MINIMUM_CIRCLE_SEGMENT_COUNT), target_lock_range_color, outline_width, true)
	if not _has_locked_target:
		return
	# 锁定目标标记半径；至少 1 像素，取值来自当前技能资源。
	var marker_radius: float = maxf(float(_skill_data.get("target_marker_radius")), MINIMUM_DRAW_RADIUS)
	draw_circle(_locked_target_local_position, marker_radius, Color(locked_target_color, locked_target_fill_opacity))
	draw_arc(_locked_target_local_position, marker_radius, 0.0, TAU, maxi(locked_target_segment_count, MINIMUM_CIRCLE_SEGMENT_COUNT), locked_target_color, outline_width, true)
	# 锁定十字半长；由标记半径和检查器倍率共同决定，水平与垂直线共享同一尺寸。
	var cross_half_length: float = marker_radius * locked_target_cross_radius_multiplier
	draw_line(_locked_target_local_position + Vector2(-cross_half_length, 0.0), _locked_target_local_position + Vector2(cross_half_length, 0.0), locked_target_color, outline_width, true)
	draw_line(_locked_target_local_position + Vector2(0.0, -cross_half_length), _locked_target_local_position + Vector2(0.0, cross_half_length), locked_target_color, outline_width, true)
