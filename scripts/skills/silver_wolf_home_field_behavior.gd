extends Node

## 我的主场！行为在进入战斗后创建一次五维分配弹窗，并通过玩家公开入口应用本局基础属性。

## 属性分配弹窗脚本；行为只负责生命周期和结果转发，不在技能节点内构建具体 UI 控件。
const ALLOCATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/silver_wolf_stat_allocation_dialog.gd")

## 当前施法者；默认 null，由被动技能组件注入并提供五维属性应用接口。
var _caster: Node2D
## 当前技能数据；默认 null，保存 99 点基准、20% 单项范围和 0.1 点输入步长。
var _skill_data: Resource
## 当前属性分配弹窗；默认 null，确认或角色切换后释放，不保留到永久存档。
var _allocation_dialog: ConfirmationDialog
## 玩家输入组件；默认 null，弹窗显示期间临时关闭战斗输入，确认后恢复。
var _input_component: Node


func configure(caster: Node2D, _stats_component: Node, skill_data: Resource, _passive_skill_component: Node) -> void:
	## 注入行为依赖并延迟展示一帧，确保 GameWorld 已先应用银狼原始 99 点角色档案。
	_caster = caster
	_skill_data = skill_data
	_input_component = _caster.get_node_or_null("InputComponent") if is_instance_valid(_caster) else null
	call_deferred("_show_allocation_dialog")


func _show_allocation_dialog() -> void:
	## 创建并显示本局唯一弹窗；缺少玩家或应用接口时安全跳过，不生成无法确认的窗口。
	if not is_instance_valid(_caster) or _skill_data == null or not _caster.has_method("apply_character_base_attribute_allocation"):
		return
	if is_instance_valid(_allocation_dialog):
		_allocation_dialog.call("present")
		return
	_allocation_dialog = ALLOCATION_DIALOG_SCRIPT.new() as ConfirmationDialog
	if _allocation_dialog == null:
		return
	_allocation_dialog.call("setup", float(_skill_data.get("base_attribute_value")), float(_skill_data.get("maximum_adjustment_ratio")), float(_skill_data.get("allocation_step")))
	_allocation_dialog.connect("allocation_confirmed", Callable(self, "_on_allocation_confirmed"))
	# 弹窗父节点；优先当前场景，确保 Window 位于战斗根树并能接收独立窗口输入。
	var dialog_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	dialog_parent.add_child(_allocation_dialog)
	if _input_component != null and _input_component.has_method("set_combat_input_enabled"):
		_input_component.call("set_combat_input_enabled", false)
	_allocation_dialog.call("present")


func _on_allocation_confirmed(attributes: Dictionary) -> void:
	## 应用合法分配并恢复战斗输入；分配失败时保持弹窗可见，避免无效数据绕过被动。
	if not is_instance_valid(_caster) or not bool(_caster.call("apply_character_base_attribute_allocation", attributes)):
		if is_instance_valid(_allocation_dialog):
			_allocation_dialog.call_deferred("present")
		return
	if _input_component != null and _input_component.has_method("set_combat_input_enabled"):
		_input_component.call("set_combat_input_enabled", true)
	if is_instance_valid(_allocation_dialog):
		_allocation_dialog.queue_free()
	_allocation_dialog = null


func shutdown() -> void:
	## 角色切换时关闭尚未确认的弹窗并恢复输入；已经应用的基础值会由 GameWorld 随后写入新角色档案覆盖。
	if _input_component != null and _input_component.has_method("set_combat_input_enabled"):
		_input_component.call("set_combat_input_enabled", true)
	if is_instance_valid(_allocation_dialog):
		_allocation_dialog.queue_free()
	_allocation_dialog = null
