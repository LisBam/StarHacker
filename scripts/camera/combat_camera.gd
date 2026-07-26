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
## 传送后镜头追赶时长；默认 0.22 秒，角色位置会立即完成结算，但画面从传送前位置快速平滑追到新位置。
@export_range(0.01, 2.0, 0.01) var teleport_follow_duration: float = 0.22

## 相机基础偏移；取值为 ready 时的 offset，默认用于震动结束后恢复到原始偏移。
var _base_offset: Vector2 = Vector2.ZERO
## 当前震动强度；取值大于等于 0，默认 0 表示无震动，修改会影响下一帧 offset 随机偏移。
var _shake_strength: float = 0.0
## 传送平滑附加偏移；默认零向量，传送瞬间抵消角色位移并通过补间快速回到零。
var _teleport_follow_offset: Vector2 = Vector2.ZERO
## 当前传送镜头补间；默认 null，连续传送会从当前画面位置重新计算并替换旧补间。
var _teleport_follow_tween: Tween
## 局部随机数生成器；默认每个相机独立随机化，修改会影响震动方向分布。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	_base_offset = offset
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func _process(delta: float) -> void:
	# 本帧震动偏移；默认零向量，无震动时仍保留传送追赶偏移。
	var shake_offset: Vector2 = Vector2.ZERO
	if _shake_strength <= 0.01:
		_shake_strength = 0.0
	else:
		# 标准化震动强度；取值限制在最大震动偏移内，默认用于生成本帧随机 offset。
		var resolved_strength: float = minf(_shake_strength, max_shake_offset)
		shake_offset = Vector2(
			_random.randf_range(-resolved_strength, resolved_strength),
			_random.randf_range(-resolved_strength, resolved_strength)
		)
		_shake_strength = maxf(_shake_strength - shake_decay * delta, 0.0)
	offset = _base_offset + _teleport_follow_offset + shake_offset
	if _shake_strength <= 0.0 and _teleport_follow_offset.is_zero_approx():
		# 震动结束且传送追赶偏移已经回正；最后一帧把 offset 精确归位到基础偏移后停止逐帧处理，避免空闲相机每帧空转。
		offset = _base_offset
		set_process(false)


func add_shake(amount: float) -> void:
	if amount <= 0.0:
		return

	_shake_strength = clampf(_shake_strength + amount, 0.0, max_shake_strength)
	# 震动强度已写入，恢复逐帧处理；空闲停用期间 offset 不会再随机抖动。
	set_process(true)


func smooth_after_owner_teleport(previous_owner_position: Vector2, current_owner_position: Vector2) -> void:
	## 用相机局部偏移抵消宿主瞬移，并在配置时长内快速回正；连续传送会保留当前尚未完成的画面偏移。
	# 本次宿主位移；当前相机作为玩家子节点已经同步跳到新位置，反向偏移可让画面保持在传送前世界坐标。
	var owner_displacement: Vector2 = current_owner_position - previous_owner_position
	if owner_displacement.is_zero_approx():
		return
	_teleport_follow_offset -= owner_displacement
	# 立即抵消本次宿主位移；即使本帧相机处理已经执行，也不会先渲染一帧瞬移后的画面。
	offset -= owner_displacement
	if _teleport_follow_tween != null and _teleport_follow_tween.is_valid():
		_teleport_follow_tween.kill()
	_teleport_follow_tween = create_tween()
	_teleport_follow_tween.tween_property(self, "_teleport_follow_offset", Vector2.ZERO, maxf(teleport_follow_duration, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 传送追赶偏移进入回正补间，恢复逐帧处理；偏移归零后 _process 会再次自动停用。
	set_process(true)
