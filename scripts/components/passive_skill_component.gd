extends Node
class_name PassiveSkillComponent

## 被动技能组件根据当前角色档案创建任意数量的独立行为节点，并统一负责角色切换时的停用与清理。
## 被动效果不写入玩家控制器；每个行为通过公开组件接口、信号或世界查询完成自己的单一职责。

signal passive_loadout_changed

## 战斗属性组件路径；默认指向同级 StatsComponent，被动行为可通过注入引用修改公开技能倍率或读取属性。
@export var stats_component_path: NodePath = ^"../StatsComponent"

## 当前被动技能资源；元素为有效 Resource，默认空数组，角色档案应用后按原顺序完整保留。
var _passive_resources: Array[Resource] = []
## 当前被动行为节点；元素与 _passive_resources 一一对应，角色切换时先 shutdown 再释放。
var _behavior_instances: Array[Node] = []

## 战斗属性组件缓存；默认在 ready 时解析，允许为空以支持只操作地图或其他系统的被动技能。
@onready var _stats_component: Node = get_node_or_null(stats_component_path)


func configure_skills(passive_resources: Array) -> void:
	## 注入当前角色全部被动技能；无效配置会被跳过，有效行为按资源顺序独立创建。
	_clear_behaviors()
	_passive_resources.clear()
	_behavior_instances.clear()
	for raw_passive_resource in passive_resources:
		# 当前被动技能资源；必须具有稳定 ID 与可实例化行为脚本。
		var passive_data: Resource = raw_passive_resource as Resource
		if not _is_valid_passive_resource(passive_data):
			continue
		# 被动行为脚本；资源只保存配置，运行时状态必须位于新建 Node 中。
		var behavior_script: Script = passive_data.get("behavior_script") as Script
		# 被动行为节点；非 Node 脚本安全跳过，不影响同角色其他被动创建。
		var behavior_instance: Node = behavior_script.new() as Node if behavior_script != null else null
		if behavior_instance == null:
			continue
		behavior_instance.name = "PassiveSkillBehavior_%s" % str(passive_data.get("skill_id"))
		add_child(behavior_instance)
		if behavior_instance.has_method("configure"):
			behavior_instance.call("configure", get_parent() as Node2D, _stats_component, passive_data, self)
		_passive_resources.append(passive_data)
		_behavior_instances.append(behavior_instance)
	passive_loadout_changed.emit()


func get_passive_resources() -> Array[Resource]:
	## 返回当前被动资源数组副本；调用方可用于 HUD 或调试展示，但不得修改模板资源字段。
	return _passive_resources.duplicate()


func apply_successful_extraction_bonuses(global_inventory: Node, game_world: Node) -> int:
	## 结算全部被动行为的成功撤离金币奖励；只有实现明确接口的行为参与，返回实际增加金币总数供结算展示扩展。
	var total_bonus_coins: int = 0
	for behavior_instance in _behavior_instances:
		if is_instance_valid(behavior_instance) and behavior_instance.has_method("apply_successful_extraction_bonus"):
			total_bonus_coins += maxi(int(behavior_instance.call("apply_successful_extraction_bonus", global_inventory, game_world)), 0)
	return total_bonus_coins


func _clear_behaviors() -> void:
	for behavior_instance in _behavior_instances:
		if not is_instance_valid(behavior_instance):
			continue
		if behavior_instance.has_method("shutdown"):
			behavior_instance.call("shutdown")
		behavior_instance.queue_free()


func _is_valid_passive_resource(passive_data: Resource) -> bool:
	if passive_data == null:
		return false
	if passive_data.has_method("is_valid_configuration"):
		return bool(passive_data.call("is_valid_configuration"))
	return not str(passive_data.get("skill_id")).strip_edges().is_empty() and passive_data.get("behavior_script") is Script
