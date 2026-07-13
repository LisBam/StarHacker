extends Node

## 幻影现实二段行为读取一段共享记录并回到原位置、恢复记录生命；致命伤害可通过通用拦截协议立即触发本段。

## 当前施法者；默认 null，由主动技能组件注入并执行位置回溯与外部移动清理。
var _caster: Node2D
## 当前属性组件；默认 null，用于把生命调整到一段记录值。
var _stats_component: Node
## 当前技能数据；默认 null，提供致命触发时的额外冷却比例。
var _skill_data: Resource
## 主动技能组件；默认 null，用于在致命触发的最终段结算前设置一次性冷却倍率。
var _active_skill_component: Node


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, active_skill_component: Node) -> void:
	## 注入二段行为依赖；阶段记录不复制到本节点，始终从释放上下文 chain_state 读取。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_active_skill_component = active_skill_component


func can_intercept_lethal_damage(_incoming_damage: float, _source: Node) -> bool:
	## 当前行为只会在二段等待窗口内存在，组件已经复核窗口状态；记录字段存在时允许拦截致命伤害。
	return is_instance_valid(_caster) and _stats_component != null


func execute(context: Dictionary) -> bool:
	## 执行位置与生命回溯；共享记录缺失时返回 false，让二段窗口继续等待而不错误进入冷却。
	if not is_instance_valid(_caster) or _stats_component == null or not context.get("chain_state") is Dictionary:
		return false
	# 阶段共享状态；由一段写入记录位置与生命，当前段只读取并在完成后由组件清空。
	var chain_state: Dictionary = context.get("chain_state") as Dictionary
	if not chain_state.get("recorded_position") is Vector2 or not chain_state.has("recorded_health"):
		return false
	# 记录位置；来自一段传送前的合法玩家位置，可直接恢复且不需要再次寻找目标附近空地。
	var recorded_position: Vector2 = chain_state.get("recorded_position") as Vector2
	_caster.global_position = recorded_position
	if _caster.has_method("clear_external_motion"):
		_caster.call("clear_external_motion")
	if _stats_component.has_method("set_health"):
		_stats_component.call("set_health", float(chain_state.get("recorded_health", 0.0)))
	# 致命自动触发；本次整套技能最终冷却按 1+99% 结算，普通手动二段保持 1 倍。
	if bool(context.get("triggered_by_lethal_damage", false)) and _active_skill_component != null and _active_skill_component.has_method("set_completion_cooldown_multiplier"):
		_active_skill_component.call("set_completion_cooldown_multiplier", int(context.get("slot_index", -1)), 1.0 + maxf(float(_skill_data.get("lethal_cooldown_extension_ratio")), 0.0))
	return true
