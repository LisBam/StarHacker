extends Control

## 角色选择场景负责在骇入或训练场开始前确认当前角色。
## 左侧按钮只切换当前查看目标，右侧详情面板展示角色定位、说明、占位数值和后续技能入口。

## 星角色标识；默认与 SessionState 保持一致，修改会影响星按钮的选择目标。
const CHARACTER_STELLE: String = "stelle"
## 穹角色标识；默认与 SessionState 保持一致，修改会影响穹按钮的选择目标。
const CHARACTER_CAEULUS: String = "caelus"
## 银狼角色标识；默认与 SessionState 保持一致，修改会影响银狼按钮的选择目标。
const CHARACTER_SILVER_WOLF: String = "silver_wolf"
## 全局窗口样式指南；统一角色列表、详情分区、属性条和底部操作按钮的视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 游戏场景路径；默认进入当前战斗承载场景，只允许填写 tscn 资源，运行时通常不动态修改。
@export_file("*.tscn") var game_scene_path: String = "res://scenes/game/game_world.tscn"
## 主菜单场景路径；默认返回项目主菜单，只允许填写 tscn 资源，运行时通常不动态修改。
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
## 数值条显示上限；取值应大于 0，默认 200 覆盖当前占位生命和能量范围，修改会影响详情面板条形比例。
@export_range(1.0, 9999.0, 1.0, "or_greater") var stat_bar_maximum: float = 200.0
## 速度条显示上限；取值应大于 0，默认 420 覆盖当前占位速度范围，修改会影响速度条形比例。
@export_range(1.0, 9999.0, 1.0, "or_greater") var speed_bar_maximum: float = 420.0

## 当前选中的角色标识；取值为 stelle、caelus 或 silver_wolf，默认 stelle，修改会影响确认进入的角色。
var _selected_character_id: String = CHARACTER_STELLE

## 页面标题缓存；默认绑定 TitleLabel，显示当前模式下的角色选择标题。
@onready var _title_label: Label = %TitleLabel
## 星角色按钮缓存；默认绑定 StelleButton，点击后查看星的详情。
@onready var _stelle_button: Button = %StelleButton
## 穹角色按钮缓存；默认绑定 CaelusButton，点击后查看穹的详情。
@onready var _caelus_button: Button = %CaelusButton
## 银狼角色按钮缓存；默认绑定 SilverWolfButton，点击后查看银狼的详情。
@onready var _silver_wolf_button: Button = %SilverWolfButton
## 角色名称文本缓存；默认绑定 CharacterNameLabel，显示当前查看角色的名称。
@onready var _character_name_label: Label = %CharacterNameLabel
## 角色定位文本缓存；默认绑定 CharacterRoleLabel，显示当前查看角色的临时定位。
@onready var _character_role_label: Label = %CharacterRoleLabel
## 角色说明文本缓存；默认绑定 CharacterDescriptionLabel，显示当前查看角色的占位说明。
@onready var _character_description_label: Label = %CharacterDescriptionLabel
## 生命数值文本缓存；默认绑定 HealthValueLabel，显示当前查看角色的固定生命上限。
@onready var _health_value_label: Label = %HealthValueLabel
## 生命数值条缓存；默认绑定 HealthPreviewBar，用于表现固定生命上限。
@onready var _health_preview_bar: ProgressBar = %HealthPreviewBar
## 能量数值文本缓存；默认绑定 EnergyValueLabel，显示当前查看角色的固定能量上限。
@onready var _energy_value_label: Label = %EnergyValueLabel
## 能量数值条缓存；默认绑定 EnergyPreviewBar，用于表现固定能量上限。
@onready var _energy_preview_bar: ProgressBar = %EnergyPreviewBar
## 速度数值文本缓存；默认绑定 SpeedValueLabel，显示当前查看角色的固定移动速度。
@onready var _speed_value_label: Label = %SpeedValueLabel
## 速度数值条缓存；默认绑定 SpeedPreviewBar，用于表现固定移动速度。
@onready var _speed_preview_bar: ProgressBar = %SpeedPreviewBar
## 攻击力文本缓存；默认绑定 AttackValueLabel，显示当前查看角色的基础攻击力。
@onready var _attack_value_label: Label = %AttackValueLabel
## 防御力文本缓存；默认绑定 DefenseValueLabel，显示当前查看角色的基础防御力。
@onready var _defense_value_label: Label = %DefenseValueLabel
## 被动技能文本缓存；默认绑定 PassiveLabel，显示后续被动技能占位信息。
@onready var _passive_label: Label = %PassiveLabel
## 主动技能文本缓存；默认绑定 ActiveLabel，显示后续主动技能占位信息。
@onready var _active_label: Label = %ActiveLabel
## 确认进入按钮缓存；默认绑定 ConfirmButton，点击后写入角色并进入游戏世界。
@onready var _confirm_button: Button = %ConfirmButton
## 返回按钮缓存；默认绑定 BackButton，点击后回到主菜单。
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_primary_button(_confirm_button)
	UI_STYLE_GUIDE.apply_title_label(_title_label)
	UI_STYLE_GUIDE.apply_title_label(_character_name_label)
	(get_node("Background") as ColorRect).color = UI_STYLE_GUIDE.SCREEN_BACKGROUND_COLOR
	_stelle_button.toggle_mode = true
	_caelus_button.toggle_mode = true
	_silver_wolf_button.toggle_mode = true
	_stelle_button.pressed.connect(_on_stelle_button_pressed)
	_caelus_button.pressed.connect(_on_caelus_button_pressed)
	_silver_wolf_button.pressed.connect(_on_silver_wolf_button_pressed)
	_confirm_button.pressed.connect(_on_confirm_button_pressed)
	_back_button.pressed.connect(_on_back_button_pressed)
	_selected_character_id = _get_session_selected_character_id()
	_refresh_title()
	_select_character(_selected_character_id)


func _refresh_title() -> void:
	# 当前模式显示名；取值来自 SessionState，默认骇入，用于标题和确认按钮文案。
	var mode_label: String = _get_session_game_mode_label()
	_title_label.text = "%s - 角色选择" % mode_label
	_confirm_button.text = "进入%s" % mode_label


func _select_character(character_id: String) -> void:
	_selected_character_id = _normalize_character_id(character_id)
	_set_button_states()
	_refresh_character_detail()


func _set_button_states() -> void:
	_stelle_button.set_pressed_no_signal(_selected_character_id == CHARACTER_STELLE)
	_caelus_button.set_pressed_no_signal(_selected_character_id == CHARACTER_CAEULUS)
	_silver_wolf_button.set_pressed_no_signal(_selected_character_id == CHARACTER_SILVER_WOLF)


func _refresh_character_detail() -> void:
	# 当前角色档案；取值来自 SessionState，默认返回星的占位档案，修改会影响详情面板全部显示内容。
	var profile: Dictionary = _get_character_profile(_selected_character_id)
	# 固定生命上限；取值来自角色档案，默认用于文字和条形预览。
	var max_health: float = float(profile.get("max_health", 0.0))
	# 固定能量上限；取值来自角色档案，默认用于文字和条形预览。
	var max_energy: float = float(profile.get("max_energy", 0.0))
	# 固定移动速度；取值来自角色档案，默认用于文字和条形预览。
	var move_speed: float = float(profile.get("move_speed", 0.0))
	# 固定攻击力；取值来自角色档案，默认用于角色选择详情文字。
	var attack_power: float = float(profile.get("attack_power", 0.0))
	# 固定防御力；取值来自角色档案，默认用于角色选择详情文字。
	var defense_power: float = float(profile.get("defense_power", 0.0))
	_character_name_label.text = str(profile.get("display_name", "角色"))
	_character_role_label.text = str(profile.get("role", "未配置定位"))
	_character_description_label.text = str(profile.get("description", "暂无角色说明"))
	_health_value_label.text = "生命上限  %d" % roundi(max_health)
	_energy_value_label.text = "能量上限  %d" % roundi(max_energy)
	_speed_value_label.text = "速度  %d" % roundi(move_speed)
	_attack_value_label.text = "攻击力  %d" % roundi(attack_power)
	_defense_value_label.text = "防御力  %d" % roundi(defense_power)
	_health_preview_bar.max_value = stat_bar_maximum
	_energy_preview_bar.max_value = stat_bar_maximum
	_speed_preview_bar.max_value = speed_bar_maximum
	_health_preview_bar.value = clampf(max_health, 0.0, stat_bar_maximum)
	_energy_preview_bar.value = clampf(max_energy, 0.0, stat_bar_maximum)
	_speed_preview_bar.value = clampf(move_speed, 0.0, speed_bar_maximum)
	_passive_label.text = str(profile.get("passive", "被动技能：待配置"))
	_active_label.text = str(profile.get("active", "主动技能：待配置"))


func _get_session_state() -> Node:
	return get_tree().root.get_node_or_null("SessionState")


func _get_session_selected_character_id() -> String:
	# 会话状态节点；默认由自动加载提供，缺失时使用星作为兜底。
	var session_state: Node = _get_session_state()
	if session_state == null:
		return CHARACTER_STELLE

	if session_state.has_method("get_selected_character_id"):
		return _normalize_character_id(str(session_state.call("get_selected_character_id")))

	return _normalize_character_id(str(session_state.get("selected_character_id")))


func _get_session_game_mode_label() -> String:
	# 会话状态节点；默认由自动加载提供，缺失时按骇入显示。
	var session_state: Node = _get_session_state()
	if session_state == null:
		return "骇入"

	if session_state.has_method("get_game_mode_label"):
		return str(session_state.call("get_game_mode_label"))

	if session_state.has_method("is_training_mode") and bool(session_state.call("is_training_mode")):
		return "训练场"

	return "骇入"


func _get_character_profile(character_id: String) -> Dictionary:
	# 会话状态节点；默认由自动加载提供，缺失时使用本地最小兜底档案。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("get_character_profile"):
		# 角色档案；取值为 Dictionary，默认由 SessionState 统一维护，修改会影响详情面板显示。
		var profile: Dictionary = session_state.call("get_character_profile", character_id)
		return profile

	return {
		"id": CHARACTER_STELLE,
		"display_name": "星",
		"role": "标准型开拓者",
		"description": "生命和能量上限都较平衡，适合验证默认战斗流程。",
		"max_health": 130.0,
		"max_energy": 110.0,
		"move_speed": 320.0,
		"attack_power": 10.0,
		"defense_power": 5.0,
		"passive": "被动技能：待配置",
		"active": "主动技能：待配置"
	}


func _set_session_selected_character(character_id: String) -> void:
	# 会话状态节点；默认由自动加载提供，缺失时无法跨场景传递角色选择。
	var session_state: Node = _get_session_state()
	if session_state == null:
		return

	if session_state.has_method("set_selected_character"):
		session_state.call("set_selected_character", character_id)
	elif session_state.has_method("configure"):
		session_state.call("configure", str(session_state.get("game_mode")), character_id)


func _normalize_character_id(character_id: String) -> String:
	if character_id == CHARACTER_CAEULUS:
		return CHARACTER_CAEULUS
	if character_id == CHARACTER_SILVER_WOLF:
		return CHARACTER_SILVER_WOLF

	return CHARACTER_STELLE


func _on_stelle_button_pressed() -> void:
	_select_character(CHARACTER_STELLE)


func _on_caelus_button_pressed() -> void:
	_select_character(CHARACTER_CAEULUS)


func _on_silver_wolf_button_pressed() -> void:
	_select_character(CHARACTER_SILVER_WOLF)


func _on_confirm_button_pressed() -> void:
	_set_session_selected_character(_selected_character_id)
	_change_scene_with_transition(game_scene_path)


func _on_back_button_pressed() -> void:
	_change_scene_with_transition(main_menu_scene_path)


func _change_scene_with_transition(scene_path: String) -> void:
	# 全局转场服务；默认执行 0.3 秒黑屏过渡，缺失时回退直接切换保证场景可单独测试。
	var scene_transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_to_file"):
		scene_transition.call("change_scene_to_file", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)
