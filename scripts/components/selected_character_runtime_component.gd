extends Node
class_name SelectedCharacterRuntimeComponent

## 当前角色运行时配置组件负责把 SessionState 中已确认的角色档案注入玩家预制体。
## 战斗世界、大厅和后续需要可操作角色的场景都复用该组件，避免各自复制属性与技能装载流程。

## 玩家节点路径；默认指向组件同级的 Player，必须提供角色显示名属性及标准战斗子组件，运行时通常不动态修改。
@export var player_path: NodePath = ^"../Player"
## 战斗属性组件路径；默认相对玩家指向 StatsComponent，缺失时只跳过生命、能量、攻击与防御配置。
@export var stats_component_path: NodePath = ^"StatsComponent"
## 被动技能组件路径；默认相对玩家指向 PassiveSkillComponent，缺失时角色被动不会在当前场景创建。
@export var passive_skill_component_path: NodePath = ^"PassiveSkillComponent"
## 主动技能组件路径；默认相对玩家指向 ActiveSkillComponent，缺失时角色主动技能槽保持空配置。
@export var active_skill_component_path: NodePath = ^"ActiveSkillComponent"
## 装备组件路径；默认相对玩家指向 EquipmentComponent，用于在保留脚部装备加成的同时应用角色基础移速。
@export var equipment_component_path: NodePath = ^"EquipmentComponent"

## 当前已应用角色标识；默认空字符串表示尚未完成配置，成功应用后保存标准化角色 ID 供 HUD 查询。
var _selected_character_id: String = ""
## 当前已应用角色档案快照；默认空字典，保存本场景使用的显示名称、属性与技能资源引用供只读查询。
var _selected_character_profile: Dictionary = {}

## 玩家节点缓存；默认在 ready 阶段按 player_path 获取，允许为空以支持组件隔离场景验证。
@onready var _player: Node = get_node_or_null(player_path)


func apply_selected_character(fallback_profile: Dictionary = {}) -> bool:
	## 从 SessionState 读取当前角色并应用；服务缺失时使用回退档案中的 id，仍可完成独立场景测试。
	# 会话状态节点；默认由 AutoLoad 提供，缺失时不会阻止检查器回退档案生效。
	var session_state: Node = _get_session_state()
	# 回退角色标识；默认使用档案 id，档案未提供时使用 stelle 保持现有默认角色语义。
	var fallback_character_id: String = str(fallback_profile.get("id", "stelle"))
	# 待应用角色标识；优先读取服务公开接口，兼容旧服务时读取同名属性。
	var character_id: String = fallback_character_id
	if session_state != null and session_state.has_method("get_selected_character_id"):
		character_id = str(session_state.call("get_selected_character_id"))
	elif session_state != null:
		character_id = str(session_state.get("selected_character_id"))
	return apply_character(character_id, fallback_profile)


func apply_character(character_id: String, fallback_profile: Dictionary = {}) -> bool:
	## 应用指定角色档案并重建角色技能运行时；返回 false 表示玩家节点缺失且没有发生任何修改。
	if _player == null:
		return false
	_selected_character_id = _normalize_character_id(character_id)
	_selected_character_profile = _resolve_character_profile(_selected_character_id, fallback_profile)
	_player.set("player_display_name", str(_selected_character_profile.get("display_name", _selected_character_id)))

	# 玩家属性组件；先清理旧角色技能倍率，避免切换角色后保留旧被动提供的长期属性来源。
	var stats_component: Node = _player.get_node_or_null(stats_component_path)
	if stats_component != null and stats_component.has_method("clear_skill_stat_multipliers"):
		stats_component.call("clear_skill_stat_multipliers")

	# 被动技能组件；每次应用档案都会关闭旧行为并按资源数组重建，确保长期状态跟随当前角色。
	var passive_skill_component: Node = _player.get_node_or_null(passive_skill_component_path)
	if passive_skill_component != null and passive_skill_component.has_method("configure_skills"):
		passive_skill_component.call("configure_skills", _selected_character_profile.get("passive_skills", []) as Array)

	# 主动技能组件；按档案资源顺序写入标准技能槽，多余技能由组件按自身槽位上限截断。
	var active_skill_component: Node = _player.get_node_or_null(active_skill_component_path)
	if active_skill_component != null and active_skill_component.has_method("configure_skills"):
		active_skill_component.call("configure_skills", _selected_character_profile.get("active_skills", []) as Array)

	if stats_component != null and stats_component.has_method("configure_character_base_stats"):
		# 生命上限；默认 100，修改档案会同时影响当前生命重置值与 HUD 上限。
		var max_health: float = maxf(float(_selected_character_profile.get("max_health", 100.0)), 1.0)
		# 能量上限；默认 100，保留 0.1 点运行时精度并由属性组件统一量化。
		var max_energy: float = maxf(float(_selected_character_profile.get("max_energy", 100.0)), 0.1)
		# 基础攻击力；默认 100，装备与技能加成仍由属性组件在该基准上聚合。
		var attack_power: float = maxf(float(_selected_character_profile.get("attack_power", 100.0)), 0.0)
		# 基础防御力；默认 100，装备与技能加成仍由属性组件在该基准上聚合。
		var defense_power: float = maxf(float(_selected_character_profile.get("defense_power", 100.0)), 0.0)
		stats_component.call("configure_character_base_stats", max_health, max_energy, attack_power, defense_power)

	# 装备组件；基础移速通过公开接口写入，脚部比例加成会由组件重新聚合而不会被覆盖。
	var equipment_component: Node = _player.get_node_or_null(equipment_component_path)
	if equipment_component != null and equipment_component.has_method("configure_base_move_speed"):
		# 基础移动速度；默认 100 点，实际像素速度继续由移动组件的统一倍率换算。
		var move_speed: float = maxf(float(_selected_character_profile.get("move_speed", 100.0)), 1.0)
		equipment_component.call("configure_base_move_speed", move_speed)
	return true


func get_selected_character_id() -> String:
	## 返回本组件最近一次成功应用的标准化角色标识；尚未配置时返回空字符串。
	return _selected_character_id


func get_selected_character_name() -> String:
	## 返回当前角色显示名称；档案缺失名称时回退角色标识，供大厅与战斗 HUD 统一展示。
	return str(_selected_character_profile.get("display_name", _selected_character_id))


func get_selected_character_profile() -> Dictionary:
	## 返回角色档案浅复制；调用方可读取资源引用，但不能替换组件内部字典键值。
	return _selected_character_profile.duplicate()


func _resolve_character_profile(character_id: String, fallback_profile: Dictionary) -> Dictionary:
	# 合并档案；先复制场景回退值，再让 SessionState 的正式内容档案覆盖同名字段。
	var resolved_profile: Dictionary = fallback_profile.duplicate(true)
	# 会话角色档案；正常运行时来自 ContentCatalog，包含角色数值与主动、被动技能资源数组。
	var session_profile: Dictionary = {}
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("get_character_profile"):
		session_profile = session_state.call("get_character_profile", character_id) as Dictionary
	resolved_profile.merge(session_profile, true)
	resolved_profile["id"] = character_id
	if not resolved_profile.has("display_name"):
		resolved_profile["display_name"] = character_id
	return resolved_profile


func _normalize_character_id(character_id: String) -> String:
	# 会话状态服务；统一复用其内容目录与解锁校验，新增角色无需修改本组件白名单。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("normalize_character_id"):
		return str(session_state.call("normalize_character_id", character_id))
	return character_id.strip_edges() if not character_id.strip_edges().is_empty() else "stelle"


func _get_session_state() -> Node:
	## 返回全局会话服务；独立组件测试缺少 AutoLoad 时允许返回 null。
	return get_tree().root.get_node_or_null("SessionState")
