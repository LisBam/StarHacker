extends Control

## 主菜单负责项目启动后的第一个可交互界面。
## 这里只保留训练场、设置和退出三条清晰路径，避免把游戏流程逻辑写进具体按钮。
## game_scene_path 暴露在检查器中，后续替换关卡入口时无需修改脚本。

## 游戏场景路径；默认进入当前基础战斗场景，只允许填写 tscn 资源，运行时通常不动态修改，改错会导致开始游戏无法切场景。
@export_file("*.tscn") var game_scene_path: String = "res://scenes/game/game_world.tscn"

## 开始按钮缓存；默认绑定唯一名 StartButton，必须是 Button，修改节点名会导致主菜单无法进入游戏。
@onready var _start_button: Button = %StartButton
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

## Master 音频总线索引；取值为 -1 或有效总线下标，默认 -1 表示尚未解析，修改会影响音量应用目标。
var _master_bus_index: int = -1


func _ready() -> void:
	_master_bus_index = AudioServer.get_bus_index("Master")
	_start_button.pressed.connect(_on_start_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_master_volume_slider.value_changed.connect(_on_master_volume_slider_value_changed)
	_settings_back_button.pressed.connect(_on_settings_back_button_pressed)
	_settings_panel.visible = false
	_sync_master_volume_slider()
	_start_button.grab_focus()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)


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
