extends Node
class_name TopDownMovementComponent

## 俯视角移动组件只处理 CharacterBody2D 的速度变化与 move_and_slide。
## acceleration 控制起步手感，friction 控制松开方向后的刹停速度，max_speed 控制可读属性点。

## 移动速度属性点到像素速度的换算倍率；固定为 3，使 100 点移速等效于旧规则的 300 像素/秒。
## 当前移动速度属性点换算倍率；固定为 2，使 100 点移速对应 200 像素/秒，疾跑与强制移动均复用这一基准。
const MOVE_SPEED_TO_PIXELS_PER_SECOND: float = 2.0
## 最大移动速度属性；取值建议大于 0，默认 106.6667 对应 320 像素/秒，运行时修改会影响角色最高速度。
@export_range(1.0, 2000.0, 0.0001, "or_greater") var max_speed: float = 106.6667
## 加速度；取值建议大于 0，默认 2200 让角色起步迅速，运行时修改会影响按键后的提速手感。
@export_range(1.0, 6000.0, 1.0, "or_greater") var acceleration: float = 2200.0
## 摩擦减速度；取值建议大于 0，默认 2600 让角色松手后快速停下，运行时修改会影响刹停距离。
@export_range(1.0, 6000.0, 1.0, "or_greater") var friction: float = 2600.0
## 停止阈值；取值建议大于等于 0，默认 4 用于清除极小残余速度，运行时修改会影响停稳判定。
@export_range(0.0, 20.0, 0.1) var stop_threshold: float = 4.0

## 组件内部基础移动速度；默认零向量，只保存玩家输入产生的速度，避免把上帧外部后坐力再次累加进基础移动。
var _movement_velocity: Vector2 = Vector2.ZERO


func move(body: CharacterBody2D, direction: Vector2, delta: float, speed_multiplier: float = 1.0, external_velocity: Vector2 = Vector2.ZERO) -> void:
	# 标准化速度倍率；取值大于等于 0，默认 1 表示正常移动，修改会影响疾跑等临时速度加成。
	var clamped_speed_multiplier: float = maxf(speed_multiplier, 0.0)
	# 目标速度；取值由方向和最大速度计算，默认随输入实时变化，修改会直接影响本帧期望移动速度。
	var target_velocity: Vector2 = direction * max_speed * MOVE_SPEED_TO_PIXELS_PER_SECOND * clamped_speed_multiplier
	# 当前速度变化率；取值在 acceleration 与 friction 间切换，默认由是否有输入决定，修改会影响本帧加减速力度。
	var change_rate: float = acceleration if not direction.is_zero_approx() else friction
	_movement_velocity = _movement_velocity.move_toward(target_velocity, change_rate * delta)

	if target_velocity.is_zero_approx() and _movement_velocity.length() <= stop_threshold:
		_movement_velocity = Vector2.ZERO

	body.velocity = _movement_velocity + external_velocity
	body.move_and_slide()


func configure_max_speed(new_max_speed: float) -> void:
	max_speed = maxf(new_max_speed, 1.0)


func reset_motion() -> void:
	_movement_velocity = Vector2.ZERO


func get_max_speed() -> float:
	return max_speed
