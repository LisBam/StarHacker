extends Node

## 开拓！行为在世界完成初始生成后选择距离角色最远的宝箱，并写入独立技能地图标记。
## 标记不占用玩家手动导航点；宝箱被开启、击毁或角色切换时会自动清理。

## 当前施法角色；默认 null，由被动技能组件注入，用于计算宝箱距离和查找所属 GameWorld。
var _caster: Node2D
## 当前战斗属性组件；默认 null，仅保留统一配置签名，本被动不修改角色数值。
var _stats_component: Node
## 当前被动技能资源；默认 null，提供地图标记 ID 与类型。
var _skill_data: Resource
## 当前被动技能组件；默认 null，仅保留统一配置签名，行为不访问其内部状态。
var _passive_skill_component: Node
## 当前游戏世界；默认 null，必须提供 set_skill_map_marker 与 remove_skill_map_marker 才能显示和清理标记。
var _game_world: Node
## 当前被标记宝箱；默认 null，目标退出场景树时触发标记清理。
var _marked_chest: Node2D
## 当前宝箱退出连接；默认空 Callable，停用或切换目标时用于安全断开旧信号。
var _chest_exit_callable: Callable


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, passive_skill_component: Node) -> void:
	## 注入依赖并延迟选择宝箱；GameWorld 父节点会在玩家子节点 ready 之后生成初始宝箱。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_passive_skill_component = passive_skill_component
	_game_world = _find_game_world()
	call_deferred("_mark_farthest_chest")


func shutdown() -> void:
	## 停用被动时断开宝箱信号并移除本技能专属地图标记，不影响导航点或其他技能标记。
	_disconnect_marked_chest()
	_remove_map_marker()


func _mark_farthest_chest() -> void:
	if not is_instance_valid(_caster) or _skill_data == null:
		return
	_game_world = _find_game_world() if _game_world == null else _game_world
	if _game_world == null or not _game_world.has_method("set_skill_map_marker"):
		return
	# 最远宝箱；默认 null，遍历当前世界全部未打开宝箱后保留距离平方最大者。
	var farthest_chest: Node2D
	# 当前最远距离平方；默认负无穷，任何合法宝箱都能成为首次候选。
	var farthest_distance_squared: float = -INF
	# 可标记宝箱组；空组不会选择目标，避免错误配置扫描无关节点。
	var chest_group: StringName = StringName(str(_skill_data.get("chest_group")))
	if chest_group.is_empty():
		_remove_map_marker()
		return
	for raw_chest in get_tree().get_nodes_in_group(chest_group):
		# 宝箱候选；只接受有效 Node2D 且未进入释放队列的当前世界节点。
		var chest: Node2D = raw_chest as Node2D
		if chest == null or not is_instance_valid(chest) or chest.is_queued_for_deletion():
			continue
		# 宝箱距离平方；避免不必要开方并稳定比较最远目标。
		var distance_squared: float = _caster.global_position.distance_squared_to(chest.global_position)
		if distance_squared > farthest_distance_squared:
			farthest_distance_squared = distance_squared
			farthest_chest = chest
	_disconnect_marked_chest()
	_marked_chest = farthest_chest
	if not is_instance_valid(_marked_chest):
		_remove_map_marker()
		return
	# 宝箱退出回调；目标打开、击毁或世界卸载时精确清理当前标记。
	_chest_exit_callable = Callable(self, "_on_marked_chest_tree_exiting")
	_marked_chest.tree_exiting.connect(_chest_exit_callable, CONNECT_ONE_SHOT)
	_game_world.call("set_skill_map_marker", str(_skill_data.get("map_marker_id")), _marked_chest.global_position, str(_skill_data.get("map_marker_kind")))


func _on_marked_chest_tree_exiting() -> void:
	_marked_chest = null
	_chest_exit_callable = Callable()
	_remove_map_marker()


func _disconnect_marked_chest() -> void:
	if is_instance_valid(_marked_chest) and _chest_exit_callable.is_valid() and _marked_chest.tree_exiting.is_connected(_chest_exit_callable):
		_marked_chest.tree_exiting.disconnect(_chest_exit_callable)
	_marked_chest = null
	_chest_exit_callable = Callable()


func _remove_map_marker() -> void:
	if _game_world != null and _game_world.has_method("remove_skill_map_marker") and _skill_data != null:
		_game_world.call("remove_skill_map_marker", str(_skill_data.get("map_marker_id")))


func _find_game_world() -> Node:
	# 当前祖先；从玩家父节点向上查找技能地图标记接口，避免行为硬编码 GameWorld 场景路径。
	var ancestor: Node = _caster.get_parent() if is_instance_valid(_caster) else null
	while ancestor != null:
		if ancestor.has_method("set_skill_map_marker") and ancestor.has_method("remove_skill_map_marker"):
			return ancestor
		ancestor = ancestor.get_parent()
	return null
