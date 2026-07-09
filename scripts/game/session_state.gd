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


func set_game_mode(next_game_mode: String) -> void:
	game_mode = normalize_game_mode(next_game_mode)


func set_selected_character(next_character_id: String) -> void:
	selected_character_id = normalize_character_id(next_character_id)


func is_training_mode() -> bool:
	return game_mode == MODE_TRAINING


func get_selected_character_id() -> String:
	return selected_character_id


func get_selected_character_name() -> String:
	return get_character_display_name(selected_character_id)


func get_game_mode_label() -> String:
	if game_mode == MODE_TRAINING:
		return "训练场"

	return "骇入"


func get_character_profile(character_id: String) -> Dictionary:
	# 标准化角色标识；取值为三个可选角色之一，默认兜底为星，修改会影响档案分支。
	var normalized_character_id: String = normalize_character_id(character_id)
	if normalized_character_id == CHARACTER_CAEULUS:
		return {
			"id": CHARACTER_CAEULUS,
			"display_name": "穹",
			"role": "均衡型开拓者",
			"description": "生命上限较高，能量上限偏低，适合测试更稳定的近距离战斗节奏。",
			"max_health": 150.0,
			"max_energy": 95.0,
			"passive": "被动技能：待配置",
			"active": "主动技能：待配置"
		}
	if normalized_character_id == CHARACTER_SILVER_WOLF:
		return {
			"id": CHARACTER_SILVER_WOLF,
			"display_name": "银狼",
			"role": "高能量骇客",
			"description": "生命上限偏低，能量上限较高，适合测试高频武器和持续消耗型动作。",
			"max_health": 105.0,
			"max_energy": 155.0,
			"passive": "被动技能：待配置",
			"active": "主动技能：待配置"
		}

	return {
		"id": CHARACTER_STELLE,
		"display_name": "星",
		"role": "标准型开拓者",
		"description": "生命和能量上限都较平衡，适合验证默认战斗、背包和武器流程。",
		"max_health": 130.0,
		"max_energy": 110.0,
		"passive": "被动技能：待配置",
		"active": "主动技能：待配置"
	}


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
