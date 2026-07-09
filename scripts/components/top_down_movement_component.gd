extends Node
class_name TopDownMovementComponent

## 俯视角移动组件只处理 CharacterBody2D 的速度变化与 move_and_slide。
## acceleration 控制起步手感，friction 控制松开方向后的刹停速度，max_speed 控制最终移动速度。

## 最大移动速度；取值建议大于 0，默认 320 适合俯视角原型手感，运行时修改会影响角色最高速度。
@export_range(1.0, 2000.0, 1.0, "or_greater") var max_speed: float = 320.0
## 加速度；取值建议大于 0，默认 2200 让角色起步迅速，运行时修改会影响按键后的提速手感。
@export_range(1.0, 6000.0, 1.0, "or_greater") var acceleration: float = 2200.0
## 摩擦减速度；取值建议大于 0，默认 2600 让角色松手后快速停下，运行时修改会影响刹停距离。
@export_range(1.0, 6000.0, 1.0, "or_greater") var friction: float = 2600.0
## 停止阈值；取值建议大于等于 0，默认 4 用于清除极小残余速度，运行时修改会影响停稳判定。
@export_range(0.0, 20.0, 0.1) var stop_threshold: float = 4.0


func move(body: CharacterBody2D, direction: Vector2, delta: float, speed_multiplier: float = 1.0) -> void:
	# 标准化速度倍率；取值大于等于 0，默认 1 表示正常移动，修改会影响疾跑等临时速度加成。
	var clamped_speed_multiplier: float = maxf(speed_multiplier, 0.0)
	# 目标速度；取值由方向和最大速度计算，默认随输入实时变化，修改会直接影响本帧期望移动速度。
	var target_velocity: Vector2 = direction * max_speed * clamped_speed_multiplier
	# 当前速度变化率；取值在 acceleration 与 friction 间切换，默认由是否有输入决定，修改会影响本帧加减速力度。
	var change_rate: float = acceleration if not direction.is_zero_approx() else friction
	body.velocity = body.velocity.move_toward(target_velocity, change_rate * delta)

	if target_velocity.is_zero_approx() and body.velocity.length() <= stop_threshold:
		body.velocity = Vector2.ZERO

	body.move_and_slide()
