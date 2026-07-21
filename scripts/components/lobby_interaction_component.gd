extends Node
class_name LobbyInteractionComponent

## 大厅交互组件只负责查找玩家附近最近的交互实体并把 F 输入转换为动作请求。
## 组件不打开界面、不切换场景，也不理解具体 action_id，所有业务路由由大厅世界组合根完成。

## 最近合法实体变化信号；HUD 只接收显示名称和是否存在目标，不持有世界节点引用。
signal interaction_target_changed(display_name: String, has_target: bool)
## 玩家对当前合法目标按下交互键时派发；参数为实体公开的稳定动作标识。
signal interaction_requested(action_id: String)

## 玩家节点路径；默认指向组件同级 Player，必须解析为 Node2D 才能计算实体边缘距离。
@export var player_path: NodePath = ^"../Player"
## 交互实体父节点路径；默认指向组件同级 Interactables，只筛选该分支下的 lobby_interactables 组节点。
@export var interactable_parent_path: NodePath = ^"../Interactables"
## 交互输入动作名；默认复用 pickup_nearby，其当前默认按键为 F，并自动继承玩家的改键结果。
@export var interaction_action: StringName = &"pickup_nearby"
## 最近目标刷新间隔；默认 0.08 秒，即每秒最多扫描 12.5 次，修改只影响提示响应频率而不改变交互半径。
@export_range(0.02, 1.0, 0.01) var target_refresh_interval: float = 0.08

## 交互是否启用；默认 true，打开局外面板时由大厅世界关闭以阻止界面背后的 F 请求。
var _interaction_enabled: bool = true
## 距离刷新剩余时间；默认 0 使进入大厅后立即查找一次目标，之后按 target_refresh_interval 批次更新。
var _target_refresh_remaining: float = 0.0
## 当前最近合法目标；默认 null，目标离树、超距或交互禁用时立即清空并移除高亮。
var _current_interactable: Node2D

## 玩家节点缓存；默认在 ready 阶段按 player_path 获取，缺失时组件保持无目标状态。
@onready var _player: Node2D = get_node_or_null(player_path) as Node2D
## 交互实体父节点缓存；默认在 ready 阶段按 interactable_parent_path 获取，用于隔离其他场景同组节点。
@onready var _interactable_parent: Node = get_node_or_null(interactable_parent_path)


func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)
	refresh_target_now()


func _process(delta: float) -> void:
	if not _interaction_enabled:
		return
	_target_refresh_remaining = maxf(_target_refresh_remaining - maxf(delta, 0.0), 0.0)
	if _target_refresh_remaining > 0.0:
		return
	_target_refresh_remaining = maxf(target_refresh_interval, 0.02)
	refresh_target_now()


func _unhandled_input(event: InputEvent) -> void:
	if not _interaction_enabled or not _is_interaction_pressed(event):
		return
	refresh_target_now()
	if not is_instance_valid(_current_interactable):
		return
	# 动作标识；只接受目标公开接口返回的非空值，避免节点名意外成为业务协议。
	var action_id: String = str(_current_interactable.call("get_interaction_action_id")) if _current_interactable.has_method("get_interaction_action_id") else ""
	if action_id.is_empty():
		return
	interaction_requested.emit(action_id)
	get_viewport().set_input_as_handled()


func set_interaction_enabled(enabled: bool) -> void:
	## 设置交互开关；关闭时清空当前目标和视觉，重新启用时立即刷新而不等待下一个批次。
	if _interaction_enabled == enabled:
		return
	_interaction_enabled = enabled
	if not _interaction_enabled:
		_set_current_interactable(null)
		return
	_target_refresh_remaining = 0.0
	refresh_target_now()


func refresh_target_now() -> void:
	## 立即选择玩家附近距离碰撞边缘最近的合法实体；按下 F 前调用可避免批次缓存造成误交互。
	if not _interaction_enabled or _player == null or _interactable_parent == null:
		_set_current_interactable(null)
		return
	# 最近实体；默认 null，遍历后只保留当前父分支、协议完整且仍在自身范围内的候选。
	var nearest_interactable: Node2D
	# 最近距离平方；默认正无穷，避免每个候选执行平方根并保持稳定比较。
	var nearest_distance_squared: float = INF
	for raw_interactable in get_tree().get_nodes_in_group(&"lobby_interactables"):
		# 交互候选；只接受当前大厅 Interactables 分支下的有效 Node2D。
		var interactable: Node2D = raw_interactable as Node2D
		if interactable == null or not is_instance_valid(interactable) or not _interactable_parent.is_ancestor_of(interactable):
			continue
		if not interactable.has_method("get_interaction_distance_squared") or not interactable.has_method("is_world_position_in_interaction_range"):
			continue
		if not bool(interactable.call("is_world_position_in_interaction_range", _player.global_position)):
			continue
		# 候选距离平方；实体按碰撞边缘计算，按钮尺寸不会缩短某一方向的有效交互范围。
		var distance_squared: float = float(interactable.call("get_interaction_distance_squared", _player.global_position))
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_interactable = interactable
	_set_current_interactable(nearest_interactable)


func _set_current_interactable(interactable: Node2D) -> void:
	if _current_interactable == interactable:
		return
	if is_instance_valid(_current_interactable) and _current_interactable.has_method("set_interaction_highlighted"):
		_current_interactable.call("set_interaction_highlighted", false)
	_current_interactable = interactable
	if is_instance_valid(_current_interactable) and _current_interactable.has_method("set_interaction_highlighted"):
		_current_interactable.call("set_interaction_highlighted", true)
	# 目标显示名；默认空字符串，无合法目标时 HUD 隐藏 F 提示。
	var display_name: String = ""
	if is_instance_valid(_current_interactable) and _current_interactable.has_method("get_interaction_display_name"):
		display_name = str(_current_interactable.call("get_interaction_display_name"))
	interaction_target_changed.emit(display_name, is_instance_valid(_current_interactable))


func _is_interaction_pressed(event: InputEvent) -> bool:
	if InputMap.has_action(interaction_action):
		return event.is_action_pressed(interaction_action, false)
	# 物理 F 回退；仅在 InputMap 动作缺失时启用，显式解除绑定不会被默认键绕过。
	var key_event: InputEventKey = event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F
