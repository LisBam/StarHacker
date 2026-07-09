extends Node
class_name CombatStatsComponent

## 战斗属性组件管理玩家生命值、能量值和能量恢复。
## 其他系统只通过 can_spend_energy、spend_energy、heal、take_damage 访问属性，避免直接改内部变量。
## UI 通过信号同步显示，不需要轮询玩家节点。

signal health_changed(current_health: float, max_health: float)
signal energy_changed(current_energy: float, max_energy: float)
signal stats_changed

## 最大生命值；取值应大于 0，默认 100 作为基础玩家血量，运行时修改会影响生命条上限。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_health: float = 100.0
## 当前生命值；取值会被限制在 0 到 max_health，默认 100 表示满血开局，运行时修改会影响玩家当前生存状态。
@export_range(0.0, 9999.0, 1.0, "or_greater") var current_health: float = 100.0
## 最大能量值；取值应大于 0，默认 100 作为基础技能资源上限，运行时修改会影响能量条上限。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_energy: float = 100.0
## 当前能量值；取值会被限制在 0 到 max_energy，默认 100 表示满能量开局，运行时修改会影响武器可用性。
@export_range(0.0, 9999.0, 1.0, "or_greater") var current_energy: float = 100.0
## 每秒能量恢复量；取值建议大于等于 0，默认 18 让原型战斗保持节奏，运行时修改会影响持续作战能力。
@export_range(0.0, 9999.0, 0.1, "or_greater") var energy_regeneration_per_second: float = 18.0


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	current_energy = clampf(current_energy, 0.0, max_energy)
	_emit_all_stats_changed()


func _process(delta: float) -> void:
	if energy_regeneration_per_second <= 0.0 or current_energy >= max_energy:
		return

	# 本帧恢复后的能量值；取值限制在 0 到 max_energy，默认由恢复速度和 delta 计算，修改会影响能量自然回复结果。
	var regenerated_energy: float = minf(current_energy + energy_regeneration_per_second * delta, max_energy)
	set_energy(regenerated_energy)


func can_spend_energy(amount: float) -> bool:
	return amount <= 0.0 or current_energy >= amount


func spend_energy(amount: float) -> bool:
	if amount <= 0.0:
		return true

	if not can_spend_energy(amount):
		return false

	set_energy(current_energy - amount)
	return true


func set_energy(value: float) -> void:
	# 标准化后的能量值；取值限制在 0 到 max_energy，默认由传入值夹取，修改会影响信号派发前的最终能量。
	var clamped_energy: float = clampf(value, 0.0, max_energy)
	if is_equal_approx(clamped_energy, current_energy):
		return

	current_energy = clamped_energy
	energy_changed.emit(current_energy, max_energy)
	stats_changed.emit()


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	set_health(current_health - amount)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return

	set_health(current_health + amount)


func set_health(value: float) -> void:
	# 标准化后的生命值；取值限制在 0 到 max_health，默认由传入值夹取，修改会影响信号派发前的最终生命。
	var clamped_health: float = clampf(value, 0.0, max_health)
	if is_equal_approx(clamped_health, current_health):
		return

	current_health = clamped_health
	health_changed.emit(current_health, max_health)
	stats_changed.emit()


func get_health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


func get_energy_ratio() -> float:
	return current_energy / max_energy if max_energy > 0.0 else 0.0


func _emit_all_stats_changed() -> void:
	health_changed.emit(current_health, max_health)
	energy_changed.emit(current_energy, max_energy)
	stats_changed.emit()
