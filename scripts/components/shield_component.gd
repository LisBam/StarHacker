extends Node
class_name ShieldComponent

## 护盾组件为任意单位提供独立于生命值的额外承伤层。
## 伤害入口应先调用 absorb_damage，返回值再交给生命系统结算；护盾不会主动恢复，也不会改变单位死亡条件。

signal shield_changed(current_shield: float, max_shield: float)
signal shield_broken

## 最大护盾值；取值大于等于 0，默认 0 表示单位生成时没有护盾，运行时修改会限制当前护盾上限。
@export_range(0.0, 99999.0, 1.0, "or_greater") var max_shield: float = 0.0
## 当前护盾值；取值限制在 0 到 max_shield，默认 0，运行时可通过 set_shield、add_shield 或 configure_shield 修改。
@export_range(0.0, 99999.0, 1.0, "or_greater") var current_shield: float = 0.0


func _ready() -> void:
	current_shield = clampf(current_shield, 0.0, maxf(max_shield, 0.0))
	shield_changed.emit(current_shield, max_shield)


func configure_shield(new_max_shield: float, fill_to_maximum: bool = true) -> void:
	## 配置护盾上限；默认同时补满，适合单位生成或角色配置，关闭补满时只夹取现有护盾。
	max_shield = maxf(new_max_shield, 0.0)
	set_shield(max_shield if fill_to_maximum else current_shield)


func set_shield(value: float) -> void:
	## 直接设置当前护盾；数值会被限制到有效范围，变化后派发统一信号供 HUD 和状态效果监听。
	# 标准化护盾值；最低为 0、最高为 max_shield，异常负值不会转化为生命伤害。
	var resolved_shield: float = clampf(value, 0.0, maxf(max_shield, 0.0))
	if is_equal_approx(resolved_shield, current_shield):
		return
	# 修改前是否持有护盾；用于只在正值首次归零时派发破盾信号。
	var had_shield: bool = current_shield > 0.0
	current_shield = resolved_shield
	shield_changed.emit(current_shield, max_shield)
	if had_shield and current_shield <= 0.0:
		shield_broken.emit()


func add_shield(amount: float, expand_maximum: bool = false) -> float:
	## 增加护盾并返回实际增加量；expand_maximum 为 true 时允许本次增量同步抬高上限。
	if amount <= 0.0:
		return 0.0
	# 修改前护盾；用于计算受上限限制后的实际增量。
	var previous_shield: float = current_shield
	if expand_maximum:
		max_shield = maxf(max_shield + amount, 0.0)
	set_shield(current_shield + amount)
	return maxf(current_shield - previous_shield, 0.0)


func remove_shield(amount: float, reduce_maximum: bool = false) -> float:
	## 移除护盾并返回实际移除量；限时护盾到期时可同时降低上限，已被伤害消耗的部分不会重复扣除。
	if amount <= 0.0:
		return 0.0
	var previous_shield: float = current_shield
	set_shield(current_shield - amount)
	var removed_shield: float = maxf(previous_shield - current_shield, 0.0)
	if reduce_maximum:
		max_shield = maxf(max_shield - amount, current_shield)
		shield_changed.emit(current_shield, max_shield)
	return removed_shield


func absorb_damage(amount: float) -> float:
	## 使用当前护盾吸收伤害并返回仍需由生命值承担的剩余伤害；护盾不足时允许同一次伤害溢出。
	if amount <= 0.0 or current_shield <= 0.0:
		return maxf(amount, 0.0)
	# 本次可吸收伤害；不会超过当前护盾，也不会产生负数剩余伤害。
	var absorbed_damage: float = minf(amount, current_shield)
	set_shield(current_shield - absorbed_damage)
	return maxf(amount - absorbed_damage, 0.0)


func has_shield() -> bool:
	## 返回当前是否仍有可吸收伤害的护盾值。
	return current_shield > 0.0


func get_shield_ratio() -> float:
	## 返回 0 至 1 的护盾比例；上限为 0 时固定返回 0，避免 UI 除零。
	return current_shield / max_shield if max_shield > 0.0 else 0.0
