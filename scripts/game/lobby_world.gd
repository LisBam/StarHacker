extends Node2D
class_name LobbyWorld

## 主大厅世界组合玩家预制体、当前角色配置、静态交互设施、专用 HUD 与主菜单面板宿主。
## 大厅不创建敌人、掉落、撤离、战斗结算或本局库存快照，玩家能力仍由原有战斗组件完整执行。

## 主菜单场景路径；默认用于大厅 HUD 左上角切换按钮，场景切换统一交给 SceneTransition。
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
## 玩家节点路径；默认指向 Player，必须是 player.tscn 实例才能提供完整移动、攻击、技能与装备组件。
@export var player_path: NodePath = ^"Player"
## 当前角色运行时配置组件路径；默认指向 SelectedCharacterRuntimeComponent，负责从 SessionState 注入角色档案。
@export var selected_character_runtime_component_path: NodePath = ^"SelectedCharacterRuntimeComponent"
## 大厅交互组件路径；默认指向 LobbyInteractionComponent，只负责最近目标与 F 动作请求。
@export var lobby_interaction_component_path: NodePath = ^"LobbyInteractionComponent"
## 大厅 HUD 路径；默认指向 LobbyHud，用于显示状态、提示并派发菜单切换请求。
@export var lobby_hud_path: NodePath = ^"LobbyHud"
## 主菜单面板宿主路径；默认指向 MainMenuLayer 内的 MainMenuPanelHost，复用全部局外业务面板与场景入口。
@export var main_menu_panel_host_path: NodePath = ^"MainMenuLayer/MainMenuPanelHost"
## 大厅地面尺寸；默认 1600×1000 像素，与场景四面静态边界对应，修改时必须同步边界碰撞体位置与尺寸。
@export var floor_size: Vector2 = Vector2(1600.0, 1000.0)
## 大厅地面网格间距；默认 64 像素，只影响背景导航感，不参与碰撞、交互距离或角色移动速度。
@export_range(16.0, 256.0, 1.0) var floor_grid_size: float = 64.0
## 大厅地面底色；默认中性深灰黑，避免场景只由单一蓝色系构成。
@export var floor_color: Color = Color(0.055, 0.062, 0.065, 1.0)
## 大厅网格颜色；默认低透明冷灰色，帮助玩家判断移动但不与交互设施争夺视觉焦点。
@export var floor_grid_color: Color = Color(0.24, 0.28, 0.29, 0.24)
## 大厅中心通道颜色；默认低透明青绿色，标示主要移动区域且不参与任何玩法判定。
@export var center_lane_color: Color = Color(0.08, 0.26, 0.23, 0.24)
## 大厅边界线颜色；默认偏白冷灰色，对应四面不可穿越静态墙体的可视范围。
@export var boundary_color: Color = Color(0.62, 0.70, 0.72, 0.82)

## 最近交互设施显示名称；默认空字符串，面板关闭后用于恢复仍在范围内的 HUD 提示。
var _current_interaction_display_name: String = ""
## 当前是否存在合法交互目标；默认 false，由 LobbyInteractionComponent 的目标变化信号维护。
var _has_interaction_target: bool = false
## 主菜单复用面板是否打开；默认 false，状态变化时统一锁定玩家物理处理、战斗输入与大厅交互。
var _is_modal_open: bool = false

## 玩家节点缓存；默认按 player_path 获取，缺失时大厅仍可显示但不会提供角色控制。
@onready var _player: Node = get_node_or_null(player_path)
## 当前角色运行时配置组件缓存；默认按路径获取，ready 阶段只应用一次 SessionState 当前角色。
@onready var _selected_character_runtime_component: Node = get_node_or_null(selected_character_runtime_component_path)
## 大厅交互组件缓存；默认按路径获取并连接目标变化与动作请求信号。
@onready var _lobby_interaction_component: Node = get_node_or_null(lobby_interaction_component_path)
## 大厅 HUD 缓存；默认按路径获取并连接左上角菜单切换请求。
@onready var _lobby_hud: Node = get_node_or_null(lobby_hud_path)
## 主菜单面板宿主缓存；默认以 lobby_host_mode 运行，只显示被实体动作打开的复用面板。
@onready var _main_menu_panel_host: Node = get_node_or_null(main_menu_panel_host_path)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _selected_character_runtime_component != null and _selected_character_runtime_component.has_method("apply_selected_character"):
		_selected_character_runtime_component.call("apply_selected_character", _get_default_character_profile())
	# 大厅武器耐久保护；只关闭武器耐久消费，能量、攻击冷却、技能冷却与自然恢复仍按原组件运行。
	if _player != null and _player.has_method("set_weapon_durability_consumption_disabled"):
		_player.call("set_weapon_durability_consumption_disabled", true)
	_bind_interaction_component()
	_bind_lobby_hud()
	_bind_main_menu_panel_host()
	if _lobby_hud != null and _lobby_hud.has_method("refresh_all"):
		_lobby_hud.call_deferred("refresh_all")
	queue_redraw()


func _draw() -> void:
	# 安全地面尺寸；每个轴至少 64 像素，避免检查器异常值导致网格循环或边界矩形退化。
	var resolved_floor_size: Vector2 = Vector2(maxf(floor_size.x, 64.0), maxf(floor_size.y, 64.0))
	# 地面矩形；以世界原点为中心，场景中的四面边界碰撞体与该矩形外沿重合。
	var floor_rect: Rect2 = Rect2(-resolved_floor_size * 0.5, resolved_floor_size)
	draw_rect(floor_rect, floor_color, true)
	# 中央通道矩形；固定覆盖地面中部 36% 宽度，纯视觉强调从出生点通往两排设施的路线。
	var center_lane_rect: Rect2 = Rect2(Vector2(-resolved_floor_size.x * 0.18, floor_rect.position.y), Vector2(resolved_floor_size.x * 0.36, resolved_floor_size.y))
	draw_rect(center_lane_rect, center_lane_color, true)
	# 安全网格间距；最低 16 像素，防止过小步长产生不必要的大量绘制调用。
	var resolved_grid_size: float = maxf(floor_grid_size, 16.0)
	# 当前竖线坐标；从地面左边界开始逐格绘制到右边界。
	var grid_x: float = floor_rect.position.x
	while grid_x <= floor_rect.end.x:
		draw_line(Vector2(grid_x, floor_rect.position.y), Vector2(grid_x, floor_rect.end.y), floor_grid_color, 1.0)
		grid_x += resolved_grid_size
	# 当前横线坐标；从地面上边界开始逐格绘制到下边界。
	var grid_y: float = floor_rect.position.y
	while grid_y <= floor_rect.end.y:
		draw_line(Vector2(floor_rect.position.x, grid_y), Vector2(floor_rect.end.x, grid_y), floor_grid_color, 1.0)
		grid_y += resolved_grid_size
	draw_rect(floor_rect, boundary_color, false, 4.0)


func _bind_interaction_component() -> void:
	if _lobby_interaction_component == null:
		return
	if _lobby_interaction_component.has_signal("interaction_target_changed"):
		_lobby_interaction_component.connect("interaction_target_changed", Callable(self, "_on_interaction_target_changed"))
	if _lobby_interaction_component.has_signal("interaction_requested"):
		_lobby_interaction_component.connect("interaction_requested", Callable(self, "_on_interaction_requested"))
	if _lobby_interaction_component.has_method("refresh_target_now"):
		_lobby_interaction_component.call_deferred("refresh_target_now")


func _bind_lobby_hud() -> void:
	if _lobby_hud != null and _lobby_hud.has_signal("switch_view_requested"):
		_lobby_hud.connect("switch_view_requested", Callable(self, "_on_switch_view_requested"))


func _bind_main_menu_panel_host() -> void:
	if _main_menu_panel_host != null and _main_menu_panel_host.has_signal("modal_visibility_changed"):
		_main_menu_panel_host.connect("modal_visibility_changed", Callable(self, "_on_modal_visibility_changed"))


func _on_interaction_target_changed(display_name: String, has_target: bool) -> void:
	_current_interaction_display_name = display_name
	_has_interaction_target = has_target
	if _lobby_hud != null and _lobby_hud.has_method("set_interaction_target"):
		_lobby_hud.call("set_interaction_target", _current_interaction_display_name, _has_interaction_target and not _is_modal_open)


func _on_interaction_requested(action_id: String) -> void:
	if _is_modal_open or _main_menu_panel_host == null or not _main_menu_panel_host.has_method("perform_lobby_action"):
		return
	_main_menu_panel_host.call("perform_lobby_action", action_id)


func _on_modal_visibility_changed(visible: bool) -> void:
	_is_modal_open = visible
	if _lobby_interaction_component != null and _lobby_interaction_component.has_method("set_interaction_enabled"):
		_lobby_interaction_component.call("set_interaction_enabled", not _is_modal_open)
	_set_player_control_enabled(not _is_modal_open)
	if _lobby_hud != null and _lobby_hud.has_method("set_modal_open"):
		_lobby_hud.call("set_modal_open", _is_modal_open)
	if not _is_modal_open and _lobby_hud != null and _lobby_hud.has_method("set_interaction_target"):
		_lobby_hud.call("set_interaction_target", _current_interaction_display_name, _has_interaction_target)


func _set_player_control_enabled(enabled: bool) -> void:
	if _player == null:
		return
	# 玩家输入组件；关闭时清除攻击、冲刺和切枪缓存，打开后继续使用当前 InputMap 状态。
	var input_component: Node = _player.get_node_or_null("InputComponent")
	if input_component != null and input_component.has_method("set_combat_input_enabled"):
		input_component.call("set_combat_input_enabled", enabled)
	_player.set_physics_process(enabled)
	if enabled:
		return
	# 玩家移动组件；打开界面时清除加速残量，关闭后不会在无按键状态下继续滑行。
	var movement_component: Node = _player.get_node_or_null("MovementComponent")
	if movement_component != null and movement_component.has_method("reset_motion"):
		movement_component.call("reset_motion")
	if _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = Vector2.ZERO


func _on_switch_view_requested() -> void:
	if _is_modal_open:
		return
	_change_scene_with_transition(main_menu_scene_path)


func _change_scene_with_transition(scene_path: String) -> void:
	# 全局转场服务；默认提供 0.30 秒黑屏过渡，缺失时回退引擎直接切换以支持大厅隔离测试。
	var scene_transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_to_file"):
		scene_transition.call("change_scene_to_file", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _get_default_character_profile() -> Dictionary:
	## 返回 AutoLoad 缺失时的大厅角色回退档案；正式运行时 SessionState 内容会覆盖全部同名字段。
	return {
		"id": "stelle",
		"display_name": "星",
		"max_health": 100.0,
		"max_energy": 100.0,
		"move_speed": 100.0,
		"attack_power": 100.0,
		"defense_power": 100.0,
		"passive_skills": [],
		"active_skills": [],
	}
