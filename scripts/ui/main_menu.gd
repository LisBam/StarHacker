extends Control

## 主菜单负责项目启动后的第一个可交互界面。
## 这里只保留“开始游戏”和“退出游戏”两条清晰路径，避免把游戏流程逻辑写进具体按钮。
## game_scene_path 暴露在检查器中，后续替换关卡入口时无需修改脚本。

## 游戏场景路径；默认进入当前基础战斗场景，只允许填写 tscn 资源，运行时通常不动态修改，改错会导致开始游戏无法切场景。
@export_file("*.tscn") var game_scene_path: String = "res://scenes/game/game_world.tscn"

## 开始按钮缓存；默认绑定唯一名 StartButton，必须是 Button，修改节点名会导致主菜单无法进入游戏。
@onready var _start_button: Button = %StartButton
## 退出按钮缓存；默认绑定唯一名 QuitButton，必须是 Button，修改节点名会导致主菜单无法退出程序。
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_start_button.grab_focus()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
