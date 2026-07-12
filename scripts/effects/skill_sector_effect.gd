extends Node2D
class_name SkillSectorEffect

## 技能扇形特效在释放瞬间绘制一次范围并随时间淡出，结束后自动释放。
## 命中结算由技能行为在创建特效前完成，本节点只表现方向、半角、距离、颜色和持续时间。

## 可绘制半径安全下限；固定 1 像素，避免异常配置生成退化扇形。
const MINIMUM_RADIUS: float = 1.0
## 特效持续时间安全下限；固定 0.01 秒，避免淡出比例除零。
const MINIMUM_DURATION: float = 0.01
## 扇形采样段数安全下限；固定 4 段，保证外弧至少形成可辨认多边形。
const MINIMUM_SEGMENT_COUNT: int = 4
## 特效轮廓线宽安全下限；固定 0.01 像素，防止异常资源生成不可绘制负线宽。
const MINIMUM_OUTLINE_WIDTH: float = 0.01
## 技能扇形最大半角；固定 180 度，与技能资源导出范围一致。
const MAXIMUM_HALF_ANGLE_DEGREES: float = 180.0
## 扇形角跨度倍率；固定 2，使半角区间转换为完整左右角跨度。
const SECTOR_ANGLE_SPAN_MULTIPLIER: float = 2.0

## 扇形半径；默认 240 像素，配置时由实际技能释放距离覆盖。
var _radius: float = 240.0
## 扇形半角；默认 45 度弧度，配置时由实际技能资源覆盖。
var _half_angle: float = PI * 0.25
## 扇形中心方向角；默认向右，配置时由释放方向覆盖。
var _direction_angle: float = 0.0
## 特效基础颜色；默认金色，透明度会按剩余时间比例递减。
var _effect_color: Color = Color(1.0, 0.82, 0.34, 0.92)
## 特效完整持续时间；默认 0.24 秒，配置时至少限制为 0.01 秒。
var _duration: float = 0.24
## 特效剩余时间；默认 0.24 秒，进入场景树后逐帧递减到 0 并释放。
var _remaining: float = 0.24
## 扇形采样段数；默认 32 段，提供平滑外弧且只存在很短时间。
var _segment_count: int = 32
## 填充透明度倍率；默认 0.28，配置时由技能资源覆盖并限制在 0 至 1。
var _fill_opacity_ratio: float = 0.28
## 特效轮廓线宽；默认 3 像素，配置时由技能资源覆盖并保持大于 0。
var _outline_width: float = 3.0


func configure(radius: float, half_angle_degrees: float, direction: Vector2, effect_color: Color, duration: float, segment_count: int, fill_opacity_ratio: float, outline_width: float) -> void:
	## 配置一次性扇形视觉；零方向回退向右，其他数值限制到可绘制范围。
	_radius = maxf(radius, MINIMUM_RADIUS)
	_half_angle = deg_to_rad(clampf(half_angle_degrees, 0.0, MAXIMUM_HALF_ANGLE_DEGREES))
	_direction_angle = (direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT).angle()
	_effect_color = effect_color
	_duration = maxf(duration, MINIMUM_DURATION)
	_remaining = _duration
	_segment_count = maxi(segment_count, MINIMUM_SEGMENT_COUNT)
	_fill_opacity_ratio = clampf(fill_opacity_ratio, 0.0, 1.0)
	_outline_width = maxf(outline_width, MINIMUM_OUTLINE_WIDTH)
	queue_redraw()


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - maxf(delta, 0.0), 0.0)
	if _remaining <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	# 淡出比例；从 1 线性降低到 0，同时轻微保持边线比填充更清晰。
	var fade_ratio: float = clampf(_remaining / maxf(_duration, MINIMUM_DURATION), 0.0, 1.0)
	# 扇形点集；首点为施法中心，其余点沿释放外弧均匀采样。
	var sector_points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for segment_index in range(_segment_count + 1):
		# 当前采样角；从方向左边界均匀推进到右边界。
		var sample_angle: float = _direction_angle - _half_angle + _half_angle * SECTOR_ANGLE_SPAN_MULTIPLIER * float(segment_index) / float(_segment_count)
		sector_points.append(Vector2.RIGHT.rotated(sample_angle) * _radius)
	# 填充颜色；基础透明度乘淡出比例并额外降低，避免短时特效完全遮住目标。
	var fill_color: Color = Color(_effect_color, _effect_color.a * _fill_opacity_ratio * fade_ratio)
	# 边缘颜色；基础透明度直接乘淡出比例，保持挥击轮廓清晰。
	var outline_color: Color = Color(_effect_color, _effect_color.a * fade_ratio)
	draw_colored_polygon(sector_points, fill_color)
	# 左右边缘；与外弧共同构成完整释放范围反馈。
	var left_edge: Vector2 = Vector2.RIGHT.rotated(_direction_angle - _half_angle) * _radius
	# 右侧边缘；从施法中心连接到外弧右端。
	var right_edge: Vector2 = Vector2.RIGHT.rotated(_direction_angle + _half_angle) * _radius
	draw_line(Vector2.ZERO, left_edge, outline_color, _outline_width, true)
	draw_line(Vector2.ZERO, right_edge, outline_color, _outline_width, true)
	draw_arc(Vector2.ZERO, _radius, _direction_angle - _half_angle, _direction_angle + _half_angle, _segment_count, outline_color, _outline_width, true)
