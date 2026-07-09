extends Control

## 主菜单负责项目启动后的第一个可交互界面。
## 这里保留骇入、训练场、设置和退出四条清晰路径，避免把游戏流程逻辑写进具体按钮。
## character_select_scene_path 暴露在检查器中，后续替换角色选择入口时无需修改脚本。

## 正式骇入模式标识；默认写入 SessionState，修改会影响骇入入口进入后的模式判定。
const GAME_MODE_HACK: String = "hack"
## 训练场模式标识；默认写入 SessionState，修改会影响训练场入口进入后的模式判定。
const GAME_MODE_TRAINING: String = "training"
## 按键绑定面板脚本；默认用于主菜单设置中动态创建可重绑定操作列表。
const KEY_BINDING_PANEL_SCRIPT: Script = preload("res://scripts/ui/key_binding_panel.gd")
## 角色选择场景路径；默认进入独立角色选择场景，只允许填写 tscn 资源，运行时通常不动态修改，改错会导致入口无法继续。
@export_file("*.tscn") var character_select_scene_path: String = "res://scenes/ui/character_select.tscn"

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
## 设置内容容器缓存；默认通过场景路径绑定，用于动态挂载按键绑定面板。
@onready var _settings_content: VBoxContainer = get_node("SettingsPanel/SettingsMargin/SettingsContent") as VBoxContainer
## 主音量滑条缓存；默认绑定唯一名 MasterVolumeSlider，取值 0 到 100，修改会影响全局 Master 音量。
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
## 主音量数值文本缓存；默认绑定唯一名 MasterVolumeValueLabel，显示滑条当前百分比。
@onready var _master_volume_value_label: Label = %MasterVolumeValueLabel
## 设置返回按钮缓存；默认绑定唯一名 SettingsBackButton，点击后关闭设置面板。
@onready var _settings_back_button: Button = %SettingsBackButton

## Master 音频总线索引；取值为 -1 或有效总线下标，默认 -1 表示尚未解析，修改会影响音量应用目标。
var _master_bus_index: int = -1
## 主菜单按键绑定面板缓存；默认运行时创建，显示并修改 InputMap 的玩家操作绑定。
var _key_binding_panel: Control


func _ready() -> void:
	_master_bus_index = AudioServer.get_bus_index("Master")
	_start_button.pressed.connect(_on_start_button_pressed)
	_training_button.pressed.connect(_on_training_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_master_volume_slider.value_changed.connect(_on_master_volume_slider_value_changed)
	_settings_back_button.pressed.connect(_on_settings_back_button_pressed)
	_build_key_binding_panel()
	_settings_panel.visible = false
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
	_settings_panel.visible = false
	_set_session_game_mode(game_mode)
	get_tree().change_scene_to_file(character_select_scene_path)


func _set_session_game_mode(game_mode: String) -> void:
	# 会话状态节点；默认由 project.godot 自动加载，缺失时直接跳过配置以保留场景兜底能力。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null:
		return

	if session_state.has_method("set_game_mode"):
		session_state.call("set_game_mode", game_mode)
	elif session_state.has_method("configure"):
		session_state.call("configure", game_mode, str(session_state.get("selected_character_id")))


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


func _build_key_binding_panel() -> void:
	if _settings_content == null:
		return

	if _key_binding_panel != null:
		return

	# 按键绑定面板；取值为 KeyBindingPanel 实例，默认添加到主菜单设置音量下方。
	var key_binding_panel: Control = KEY_BINDING_PANEL_SCRIPT.new() as Control
	if key_binding_panel == null:
		return

	key_binding_panel.name = "MainMenuKeyBindingPanel"
	key_binding_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_content.add_child(key_binding_panel)
	_settings_content.move_child(key_binding_panel, maxi(_settings_content.get_child_count() - 3, 0))
	_key_binding_panel = key_binding_panel
