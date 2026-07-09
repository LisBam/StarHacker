extends Camera2D
class_name CombatCamera

## 战斗相机负责稳定跟随玩家并提供屏幕震动。
## 位置跟随交给 Camera2D 作为玩家子节点完成，脚本只通过 offset 添加短促震动，避免直接改相机位置造成移动抖动。

## 震动衰减速度；取值建议大于 0，默认 18 表示强震动会快速回落，修改会影响屏幕震动持续时间。
@export_range(1.0, 80.0, 0.1, "or_greater") var shake_decay: float = 18.0
## 最大震动偏移；取值建议 0 到 32 像素，默认 18，修改会影响最高强度震动幅度。
@export_range(0.0, 128.0, 0.5) var max_shake_offset: float = 18.0
## 单次震动强度上限；取值建议大于 0，默认 18，修改会影响 add_shake 可累计的最大震动。
@export_range(0.0, 128.0, 0.5) var max_shake_strength: float = 18.0

## 相机基础偏移；取值为 ready 时的 offset，默认用于震动结束后恢复到原始偏移。
var _base_offset: Vector2 = Vector2.ZERO
## 当前震动强度；取值大于等于 0，默认 0 表示无震动，修改会影响下一帧 offset 随机偏移。
var _shake_strength: float = 0.0
## 局部随机数生成器；默认每个相机独立随机化，修改会影响震动方向分布。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	_base_offset = offset
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func _process(delta: float) -> void:
	if _shake_strength <= 0.01:
		_shake_strength = 0.0
		offset = _base_offset
		return

	# 标准化震动强度；取值限制在最大震动偏移内，默认用于生成本帧随机 offset。
	var resolved_strength: float = minf(_shake_strength, max_shake_offset)
	# 本帧随机震动偏移；取值为以当前强度为半径的随机向量，默认不改变相机真实位置。
	var shake_offset: Vector2 = Vector2(
		_random.randf_range(-resolved_strength, resolved_strength),
		_random.randf_range(-resolved_strength, resolved_strength)
	)
	offset = _base_offset + shake_offset
	_shake_strength = maxf(_shake_strength - shake_decay * delta, 0.0)


func add_shake(amount: float) -> void:
	if amount <= 0.0:
		return

	_shake_strength = clampf(_shake_strength + amount, 0.0, max_shake_strength)
