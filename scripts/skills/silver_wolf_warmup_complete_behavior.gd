extends Node

## 热身结束统计本局造成与受到的伤害；达到 999 后允许释放一次，打开额外 99 点五维分配并刷新技能。

## 五维分配弹窗脚本；复用我的主场界面与确认协议。
const ALLOCATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/silver_wolf_stat_allocation_dialog.gd")

## 当前施法者；默认 null，用于监听伤害、应用属性和保存一次性负面免除标记。
var _caster: Node2D
## 当前战斗属性组件；默认 null，保留统一行为配置协议。
var _stats_component: Node
## 当前技能资源；默认 null，保存 999 阈值与 99 点额外分配。
var _skill_data: Resource
## 主动技能组件；默认 null，确认分配后刷新全部技能冷却。
var _active_skill_component: Node
## 本局累计造成与受到伤害；默认 0，达到阈值后不再限制增长精度。
var _accumulated_damage: float = 0.0
## 是否已经完成本局热身结束；默认 false，成功分配后永久阻止再次释放。
var _completed: bool = false
## 当前额外分配弹窗；默认 null，确认前保持游戏暂停和战斗输入关闭。
var _dialog: ConfirmationDialog


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, active_skill_component: Node) -> void:
	## 注入依赖并连接玩家受伤、武器命中与技能命中信号。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_active_skill_component = active_skill_component
	_caster.connect("damage_received", Callable(self, "_on_damage_received"))
	_caster.connect("skill_target_hit", Callable(self, "_on_skill_target_hit"))
	for component_name in ["MeleeAttackComponent", "HybridMeleeAttackComponent"]:
		var component: Node = _caster.get_node_or_null(component_name)
		if component != null:
			component.connect("body_hit", Callable(self, "_on_weapon_hit"))
			component.connect("area_hit", Callable(self, "_on_weapon_hit"))
	for component_name in ["RangedAttackComponent", "HybridRangedAttackComponent"]:
		var component: Node = _caster.get_node_or_null(component_name)
		if component != null:
			component.connect("fired", Callable(self, "_on_projectile_fired"))


func execute(_context: Dictionary) -> bool:
	## 未达到 999 或已经完成时释放失败且不产生能量与冷却；解锁后打开一次额外分配。
	if _completed or _skill_data == null or _accumulated_damage < maxf(float(_skill_data.get("unlock_damage_total")), 1.0):
		return false
	_show_dialog()
	return true


func can_activate() -> bool:
	## 返回热身结束是否已经解锁且尚未完成；主动技能组件用该状态阻止输入并驱动无文字禁用滤镜。
	return not _completed and _skill_data != null and _accumulated_damage >= maxf(float(_skill_data.get("unlock_damage_total")), 1.0)


func _on_damage_received(amount: float, _source: Node) -> void:
	_accumulated_damage += maxf(amount, 0.0)


func _on_weapon_hit(_target: Node, damage: float) -> void:
	_accumulated_damage += maxf(damage, 0.0)


func _on_skill_target_hit(_skill_id: String, _target: Node) -> void:
	## 技能命中缺少最终伤害参数时至少按 1 点记录事件，武器与受伤仍按实际信号数值累计。
	_accumulated_damage += 1.0


func _on_projectile_fired(projectile: Node2D) -> void:
	if projectile.has_signal("hit_body"):
		projectile.connect("hit_body", Callable(self, "_on_weapon_hit"), CONNECT_ONE_SHOT)
	if projectile.has_signal("hit_area"):
		projectile.connect("hit_area", Callable(self, "_on_weapon_hit"), CONNECT_ONE_SHOT)


func _show_dialog() -> void:
	## 暂停游戏并以当前基础面板五维作为初始显示，在相对 99 点基准的正负 40%范围内分配额外 99 点。
	if is_instance_valid(_dialog):
		return
	_dialog = ALLOCATION_DIALOG_SCRIPT.new() as ConfirmationDialog
	_dialog.call("setup_additional_allocation", _caster.call("get_current_attribute_allocation_snapshot"), int(_skill_data.get("additional_attribute_points")), float(_skill_data.get("base_attribute_value")), float(_skill_data.get("maximum_adjustment_ratio")), float(_skill_data.get("allocation_step")))
	_dialog.connect("allocation_confirmed", Callable(self, "_on_allocation_confirmed"))
	(get_tree().current_scene if get_tree().current_scene != null else get_tree().root).add_child(_dialog)
	_dialog.title = "热身结束"
	get_tree().paused = true
	_dialog.call("present")


func _on_allocation_confirmed(attributes: Dictionary) -> void:
	## 应用额外分配、刷新全部技能，并赋予幻影现实与二倍速各一次负面免除。
	if not bool(_caster.call("apply_character_base_attribute_allocation", attributes)):
		_dialog.call_deferred("present")
		return
	_completed = true
	_caster.set_meta("silver_wolf_ignore_phantom_penalty_once", true)
	_caster.set_meta("silver_wolf_ignore_double_speed_penalty_once", true)
	if _active_skill_component != null and _active_skill_component.has_method("refresh_all_cooldowns"):
		_active_skill_component.call("refresh_all_cooldowns")
	get_tree().paused = false
	_dialog.queue_free()
	_dialog = null


func shutdown() -> void:
	## 角色切换时关闭弹窗并恢复暂停状态。
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
	get_tree().paused = false
