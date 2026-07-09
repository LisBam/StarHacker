extends Control

## 主菜单负责项目启动后的第一个可交互界面。
## 这里保留骇入、训练场、设置和退出四条清晰路径，避免把游戏流程逻辑写进具体按钮。
## game_scene_path 暴露在检查器中，后续替换关卡入口时无需修改脚本。

## 正式骇入模式标识；默认写入 SessionState，修改会影响骇入入口进入后的模式判定。
const GAME_MODE_HACK: String = "hack"
## 训练场模式标识；默认写入 SessionState，修改会影响训练场入口进入后的模式判定。
const GAME_MODE_TRAINING: String = "training"
## 星角色标识；默认写入 SessionState，修改会影响游戏世界应用的占位属性。
const CHARACTER_STELLE: String = "stelle"
## 穹角色标识；默认写入 SessionState，修改会影响游戏世界应用的占位属性。
const CHARACTER_CAEULUS: String = "caelus"
## 银狼角色标识；默认写入 SessionState，修改会影响游戏世界应用的占位属性。
const CHARACTER_SILVER_WOLF: String = "silver_wolf"

## 游戏场景路径；默认进入当前基础战斗场景，只允许填写 tscn 资源，运行时通常不动态修改，改错会导致开始游戏无法切场景。
@export_file("*.tscn") var game_scene_path: String = "res://scenes/game/game_world.tscn"

## 骇入按钮缓存；默认绑定唯一名 StartButton，必须是 Button，修改节点名会导致正式入口无法进入角色选择。
@onready var _start_button: Button = %StartButton
## 训练场按钮缓存；默认绑定唯一名 TrainingButton，必须是 Button，修改节点名会导致训练场入口无法进入角色选择。
@onready var _training_button: Button = %TrainingButton
## 设置按钮缓存；默认绑定唯一名 SettingsButton，必须是 Button，修改节点名会导致主菜单无法打开设置。
@onready var _settings_button: Button = %SettingsButton
## 退出按钮缓存；默认绑定唯一名 QuitButton，必须是 Button，修改节点名会导致主菜单无法退出程序。
@onready var _quit_button: Button = %QuitButton
## 设置面板缓存；默认绑定唯一名 SettingsPanel，控制主菜单设置界面的显示和隐藏。
@onready var _settings_panel: Control = %SettingsPanel
## 主音量滑条缓存；默认绑定唯一名 MasterVolumeSlider，取值 0 到 100，修改会影响全局 Master 音量。
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
## 主音量数值文本缓存；默认绑定唯一名 MasterVolumeValueLabel，显示滑条当前百分比。
@onready var _master_volume_value_label: Label = %MasterVolumeValueLabel
## 设置返回按钮缓存；默认绑定唯一名 SettingsBackButton，点击后关闭设置面板。
@onready var _settings_back_button: Button = %SettingsBackButton
## 角色选择面板缓存；默认绑定唯一名 CharacterSelectPanel，负责在进入游戏世界前选择占位角色。
@onready var _character_select_panel: Control = %CharacterSelectPanel
## 角色选择标题缓存；默认绑定唯一名 CharacterSelectTitleLabel，按入口显示当前要进入的模式。
@onready var _character_select_title_label: Label = %CharacterSelectTitleLabel
## 星角色按钮缓存；默认绑定唯一名 CharacterStelleButton，点击后以星进入当前待定模式。
@onready var _character_stelle_button: Button = %CharacterStelleButton
## 穹角色按钮缓存；默认绑定唯一名 CharacterCaelusButton，点击后以穹进入当前待定模式。
@onready var _character_caelus_button: Button = %CharacterCaelusButton
## 银狼角色按钮缓存；默认绑定唯一名 CharacterSilverWolfButton，点击后以银狼进入当前待定模式。
@onready var _character_silver_wolf_button: Button = %CharacterSilverWolfButton
## 角色选择返回按钮缓存；默认绑定唯一名 CharacterSelectBackButton，点击后回到主菜单按钮区。
@onready var _character_select_back_button: Button = %CharacterSelectBackButton

## Master 音频总线索引；取值为 -1 或有效总线下标，默认 -1 表示尚未解析，修改会影响音量应用目标。
var _master_bus_index: int = -1
## 待进入的游戏模式；取值为 hack 或 training，默认 hack，点击角色按钮时写入会话状态。
var _pending_game_mode: String = GAME_MODE_HACK


func _ready() -> void:
	_master_bus_index = AudioServer.get_bus_index("Master")
	_start_button.pressed.connect(_on_start_button_pressed)
	_training_button.pressed.connect(_on_training_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_master_volume_slider.value_changed.connect(_on_master_volume_slider_value_changed)
	_settings_back_button.pressed.connect(_on_settings_back_button_pressed)
	_character_stelle_button.pressed.connect(_on_character_stelle_button_pressed)
	_character_caelus_button.pressed.connect(_on_character_caelus_button_pressed)
	_character_silver_wolf_button.pressed.connect(_on_character_silver_wolf_button_pressed)
	_character_select_back_button.pressed.connect(_on_character_select_back_button_pressed)
	_settings_panel.visible = false
	_character_select_panel.visible = false
	_sync_master_volume_slider()
	_start_button.grab_focus()


func _on_start_button_pressed() -> void:
	_open_character_select(GAME_MODE_HACK)


func _on_training_button_pressed() -> void:
	_open_character_select(GAME_MODE_TRAINING)


func _on_settings_button_pressed() -> void:
	_settings_panel.visible = true
	_settings_back_button.grab_focus()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_master_volume_slider_value_changed(value: float) -> void:
	_apply_master_volume(value)


func _on_settings_back_button_pressed() -> void:
	_settings_panel.visible = false
	_settings_button.grab_focus()


func _open_character_select(game_mode: String) -> void:
	_pending_game_mode = game_mode
	_settings_panel.visible = false
	_character_select_panel.visible = true
	if _pending_game_mode == GAME_MODE_TRAINING:
		_character_select_title_label.text = "选择训练场角色"
	else:
		_character_select_title_label.text = "选择骇入角色"

	_character_stelle_button.grab_focus()


func _enter_game_with_character(character_id: String) -> void:
	_configure_session(_pending_game_mode, character_id)
	get_tree().change_scene_to_file(game_scene_path)


func _configure_session(game_mode: String, character_id: String) -> void:
	# 会话状态节点；默认由 project.godot 自动加载，缺失时直接跳过配置以保留场景兜底能力。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null or not session_state.has_method("configure"):
		return

	session_state.call("configure", game_mode, character_id)


func _on_character_stelle_button_pressed() -> void:
	_enter_game_with_character(CHARACTER_STELLE)


func _on_character_caelus_button_pressed() -> void:
	_enter_game_with_character(CHARACTER_CAEULUS)


func _on_character_silver_wolf_button_pressed() -> void:
	_enter_game_with_character(CHARACTER_SILVER_WOLF)


func _on_character_select_back_button_pressed() -> void:
	_character_select_panel.visible = false
	if _pending_game_mode == GAME_MODE_TRAINING:
		_training_button.grab_focus()
	else:
		_start_button.grab_focus()


func _sync_master_volume_slider() -> void:
	if _master_bus_index < 0:
		return

	# 当前 Master 音量线性值；取值为 0 到 1，默认由 AudioServer 读取，修改会影响设置滑条初始位置。
	var linear_volume: float = 0.0 if AudioServer.is_bus_mute(_master_bus_index) else db_to_linear(AudioServer.get_bus_volume_db(_master_bus_index))
	_master_volume_slider.set_value_no_signal(clampf(linear_volume, 0.0, 1.0) * 100.0)
	_refresh_master_volume_label(_master_volume_slider.value)


func _apply_master_volume(value: float) -> void:
	if _master_bus_index < 0:
		return

	# 标准化音量值；取值为 0 到 1，默认由滑条百分比换算，修改会影响最终写入 AudioServer 的音量。
	var linear_volume: float = clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(_master_bus_index, linear_volume <= 0.001)
	if linear_volume > 0.001:
		AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(linear_volume))

	_refresh_master_volume_label(value)


func _refresh_master_volume_label(value: float) -> void:
	_master_volume_value_label.text = "%d%%" % roundi(value)
