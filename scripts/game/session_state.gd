extends Node

## 会话状态保存从主菜单进入游戏世界前选择的模式和角色。
## 该节点通过 project.godot 自动加载为 SessionState，避免把入口参数硬写进场景路径。

## 正式骇入模式标识；默认用于主线入口，修改会影响模式判断和暂停菜单可见项。
const MODE_HACK: String = "hack"
## 训练场模式标识；默认用于训练入口，修改会影响训练场设置是否显示。
const MODE_TRAINING: String = "training"
## 星角色标识；默认用于主菜单角色选择和占位属性随机。
const CHARACTER_STELLE: String = "stelle"
## 穹角色标识；默认用于主菜单角色选择和占位属性随机。
const CHARACTER_CAEULUS: String = "caelus"
## 银狼角色标识；默认用于主菜单角色选择和占位属性随机。
const CHARACTER_SILVER_WOLF: String = "silver_wolf"

## 当前游戏模式；取值为 hack 或 training，默认 hack 保证直接进游戏时不会打开训练场设置。
var game_mode: String = MODE_HACK
## 当前选择角色；取值为 stelle、caelus 或 silver_wolf，默认 stelle 作为未选择时的兜底角色。
var selected_character_id: String = CHARACTER_STELLE


func configure(next_game_mode: String, next_character_id: String) -> void:
	game_mode = normalize_game_mode(next_game_mode)
	selected_character_id = normalize_character_id(next_character_id)


func is_training_mode() -> bool:
	return game_mode == MODE_TRAINING


func get_selected_character_id() -> String:
	return selected_character_id


func get_selected_character_name() -> String:
	return get_character_display_name(selected_character_id)


func normalize_game_mode(value: String) -> String:
	if value == MODE_TRAINING:
		return MODE_TRAINING

	return MODE_HACK


func normalize_character_id(value: String) -> String:
	if value == CHARACTER_CAEULUS:
		return CHARACTER_CAEULUS
	if value == CHARACTER_SILVER_WOLF:
		return CHARACTER_SILVER_WOLF

	return CHARACTER_STELLE


func get_character_display_name(character_id: String) -> String:
	if character_id == CHARACTER_CAEULUS:
		return "穹"
	if character_id == CHARACTER_SILVER_WOLF:
		return "银狼"

	return "星"
