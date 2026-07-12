extends Node

## 会话状态保存从主菜单进入游戏世界前选择的模式和角色。
## 该节点通过 project.godot 自动加载为 SessionState，避免把入口参数硬写进场景路径。

## 角色永久解锁信号；参数分别为角色 ID 与其扩展包 ID，后续解锁界面和内容消费者可按需监听。
signal character_unlocked(character_id: String, content_pack_id: String)

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
## 角色解锁存档路径；保存全部已解锁角色，默认角色也会写入以兼容未来默认解锁配置调整。
const CHARACTER_UNLOCK_SAVE_PATH: String = "user://character_unlocks.json"
## 角色解锁存档版本；版本 1 保存稳定角色 ID 数组，未来迁移必须保留已解锁状态。
const CHARACTER_UNLOCK_SAVE_VERSION: int = 1

## 当前游戏模式；取值为 hack 或 training，默认 hack 保证直接进游戏时不会打开训练场设置。
var game_mode: String = MODE_HACK
## 当前选择角色；取值为 stelle、caelus 或 silver_wolf，默认 stelle 作为未选择时的兜底角色。
var selected_character_id: String = CHARACTER_STELLE
## 已解锁角色标识；启动时合并角色档案中的默认解锁项与存档项，运行时只允许通过 unlock_character 增加。
var _unlocked_character_ids: Array[String] = []


func _ready() -> void:
	_initialize_character_unlocks()
	selected_character_id = normalize_character_id(selected_character_id)


func configure(next_game_mode: String, next_character_id: String) -> void:
	game_mode = normalize_game_mode(next_game_mode)
	selected_character_id = normalize_character_id(next_character_id)


func set_game_mode(next_game_mode: String) -> void:
	game_mode = normalize_game_mode(next_game_mode)


func set_selected_character(next_character_id: String) -> void:
	selected_character_id = normalize_character_id(next_character_id)


func unlock_character(character_id: String) -> bool:
	## 永久解锁角色及其专属扩展包；接口幂等，已解锁角色返回 true 且不会重复写盘或派发信号。
	# 标准角色标识；只去除首尾空白，不把无效角色回退为星，避免错误请求意外解锁默认角色。
	var normalized_id: String = character_id.strip_edges()
	if not _is_known_character(normalized_id):
		return false
	if _unlocked_character_ids.has(normalized_id):
		return true
	_unlocked_character_ids.append(normalized_id)
	_save_character_unlocks()
	# 内容目录；用于查找该角色唯一扩展包并通知所有长期运行的内容消费者刷新可用路径。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	# 扩展包标识；角色清单尚未创建时允许为空，角色本身仍会保持永久解锁。
	var content_pack_id: String = str(content_catalog.call("get_content_pack_id_for_character", normalized_id)) if content_catalog != null and content_catalog.has_method("get_content_pack_id_for_character") else ""
	if content_catalog != null and content_catalog.has_method("notify_unlock_state_changed"):
		content_catalog.call("notify_unlock_state_changed")
	character_unlocked.emit(normalized_id, content_pack_id)
	return true


func is_character_unlocked(character_id: String) -> bool:
	## 判断角色是否已经永久解锁；空值与未知角色不会因默认回退逻辑被视为星。
	return _unlocked_character_ids.has(character_id.strip_edges())


func is_content_pack_unlocked(content_pack_id: String) -> bool:
	## 扩展包解锁状态完全跟随所属角色；基础内容没有扩展包 ID，不通过本接口判断。
	# 内容目录；扩展包不存在或尚未关联角色时保持锁定，避免配置错误泄漏专属内容。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog == null or not content_catalog.has_method("get_content_pack_character_id"):
		return false
	# 所属角色标识；每个扩展包只允许一个角色作为永久解锁来源。
	var character_id: String = str(content_catalog.call("get_content_pack_character_id", content_pack_id))
	return not character_id.is_empty() and is_character_unlocked(character_id)


func get_unlocked_content_pack_ids() -> Array[String]:
	## 返回当前全部已解锁扩展包 ID；顺序跟随 ContentCatalog 的稳定清单顺序。
	# 已解锁扩展包；只包含当前项目实际存在且所属角色已解锁的清单。
	var unlocked_pack_ids: Array[String] = []
	# 内容目录；缺失时没有可枚举扩展包，但角色默认解锁状态仍正常工作。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog == null or not content_catalog.has_method("get_content_pack_ids"):
		return unlocked_pack_ids
	# 扩展包遍历项；逐个复用唯一解锁判断，避免 UI 与内容过滤维护两套规则。
	for content_pack_id in content_catalog.call("get_content_pack_ids") as Array[String]:
		if is_content_pack_unlocked(content_pack_id):
			unlocked_pack_ids.append(content_pack_id)
	return unlocked_pack_ids


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
	# 内容目录；默认由自动加载提供，新建角色资源后可直接返回其完整档案。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog != null and content_catalog.has_method("get_character_profile"):
		# 自动注册档案；空结果表示角色标识无效，此时继续使用内置档案保证旧场景可独立运行。
		var catalog_profile: Dictionary = content_catalog.call("get_character_profile", character_id) as Dictionary
		if not catalog_profile.is_empty():
			return catalog_profile
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
			"move_speed": 100.0,
			"attack_power": 9.0,
			"defense_power": 10.0,
			"health_regeneration_per_five_seconds": 0.0,
			"vision_range": 1.0,
			"dodge_chance": 0.0,
			"energy_regeneration": 18.0,
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
			"move_speed": 118.3333,
			"attack_power": 11.0,
			"defense_power": 2.0,
			"health_regeneration_per_five_seconds": 0.0,
			"vision_range": 1.0,
			"dodge_chance": 0.0,
			"energy_regeneration": 18.0,
			"passive": "被动技能：待配置",
			"active": "主动技能：待配置"
		}

	return {
		"id": CHARACTER_STELLE,
		"display_name": "星",
		"role": "标准型开拓者",
		"description": "生命和能量上限都较平衡，适合验证默认战斗、背包和武器流程。",
		"max_health": 100.0,
		"max_energy": 100.0,
		"move_speed": 100.0,
		"attack_power": 100.0,
		"defense_power": 100.0,
		"health_regeneration_per_five_seconds": 0.0,
		"vision_range": 1.0,
		"dodge_chance": 0.0,
		"energy_regeneration": 18.0,
		"passive": "被动技能：待配置",
		"active": "主动技能：待配置"
	}


func normalize_game_mode(value: String) -> String:
	if value == MODE_TRAINING:
		return MODE_TRAINING

	return MODE_HACK


func normalize_character_id(value: String) -> String:
	# 内容目录；有效的自动注册角色直接保留其稳定 ID，允许外部复制的新角色进入会话。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog != null and content_catalog.has_method("has_character") and bool(content_catalog.call("has_character", value)) and is_character_unlocked(value):
		return value
	if value == CHARACTER_CAEULUS and is_character_unlocked(CHARACTER_CAEULUS):
		return CHARACTER_CAEULUS
	if value == CHARACTER_SILVER_WOLF and is_character_unlocked(CHARACTER_SILVER_WOLF):
		return CHARACTER_SILVER_WOLF

	return CHARACTER_STELLE


func get_character_display_name(character_id: String) -> String:
	# 角色档案；优先读取自动内容目录，确保新角色名称同步显示在主菜单和战斗 HUD。
	var profile: Dictionary = get_character_profile(character_id)
	if not profile.is_empty():
		return str(profile.get("display_name", "角色"))
	if character_id == CHARACTER_CAEULUS:
		return "穹"
	if character_id == CHARACTER_SILVER_WOLF:
		return "银狼"

	return "星"


func get_character_ids() -> Array[String]:
	# 内容目录；返回按资源路径稳定排序的已解锁角色，供角色选择和训练场动态创建按钮。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog != null and content_catalog.has_method("get_character_ids"):
		# 自动角色标识；只保留永久解锁项，锁定角色不会提前进入选择与训练切换列表。
		var catalog_ids: Array[String] = content_catalog.call("get_character_ids") as Array[String]
		# 已解锁目录角色；保持目录原顺序并避免角色选择界面自行复制过滤规则。
		var unlocked_catalog_ids: Array[String] = []
		for character_id in catalog_ids:
			if is_character_unlocked(character_id):
				unlocked_catalog_ids.append(character_id)
		if not unlocked_catalog_ids.is_empty():
			return unlocked_catalog_ids
	# 内置角色标识；隔离场景缺少内容目录时仍按相同解锁状态过滤。
	var fallback_ids: Array[String] = [CHARACTER_STELLE, CHARACTER_CAEULUS, CHARACTER_SILVER_WOLF]
	# 已解锁内置角色；正常启动时三名角色均由资源档案默认解锁。
	var unlocked_fallback_ids: Array[String] = []
	for character_id in fallback_ids:
		if is_character_unlocked(character_id):
			unlocked_fallback_ids.append(character_id)
	return unlocked_fallback_ids if not unlocked_fallback_ids.is_empty() else [CHARACTER_STELLE]


func _initialize_character_unlocks() -> void:
	## 合并角色档案默认值与已有存档；默认解锁项不可被旧存档遗漏或回锁。
	_unlocked_character_ids.clear()
	# 内容目录；优先从数据资源读取默认解锁字段，便于后续新增角色保持数据驱动。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog != null and content_catalog.has_method("get_character_ids") and content_catalog.has_method("get_character_profile"):
		# 目录角色标识；只有档案显式标记 unlocked_by_default 才自动加入。
		for character_id in content_catalog.call("get_character_ids") as Array[String]:
			# 角色档案；深拷贝由目录服务提供，本方法只读取默认解锁元数据。
			var profile: Dictionary = content_catalog.call("get_character_profile", character_id) as Dictionary
			if bool(profile.get("unlocked_by_default", false)):
				_unlocked_character_ids.append(character_id)
	else:
		# 内置默认角色；内容目录缺失的隔离场景仍保证星、穹、银狼可用。
		_unlocked_character_ids = [CHARACTER_STELLE, CHARACTER_CAEULUS, CHARACTER_SILVER_WOLF]
	_load_character_unlocks()
	# 星安全兜底；异常资源或损坏存档不能让项目进入没有任何可选角色的状态。
	if not _unlocked_character_ids.has(CHARACTER_STELLE):
		_unlocked_character_ids.push_front(CHARACTER_STELLE)


func _load_character_unlocks() -> void:
	## 读取永久解锁列表；文件缺失、JSON 损坏或未知角色只忽略对应数据，不影响档案默认解锁项。
	if not FileAccess.file_exists(CHARACTER_UNLOCK_SAVE_PATH):
		return
	# 解锁存档文件；打开失败时保留已经建立的默认角色列表。
	var save_file: FileAccess = FileAccess.open(CHARACTER_UNLOCK_SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return
	# JSON 解析结果；只有 Dictionary 结构才读取 unlocked_character_ids 数组。
	var parsed_data: Variant = JSON.parse_string(save_file.get_as_text())
	if not parsed_data is Dictionary:
		return
	# 存档角色原始值；非数组结构视为无有效追加项。
	var raw_character_ids: Variant = (parsed_data as Dictionary).get("unlocked_character_ids", [])
	if not raw_character_ids is Array:
		return
	# 存档角色遍历项；稳定 ID 转为字符串后验证存在性并去重。
	for raw_character_id in raw_character_ids as Array:
		# 存档角色标识；空白与当前目录未知角色不会污染运行时解锁表。
		var character_id: String = str(raw_character_id).strip_edges()
		if _is_known_character(character_id) and not _unlocked_character_ids.has(character_id):
			_unlocked_character_ids.append(character_id)


func _save_character_unlocks() -> void:
	## 保存全部已解锁角色稳定 ID；默认角色一并写入可简化未来默认值调整后的向后兼容。
	# 解锁存档文件；打开失败时保留内存状态，不中断本次角色解锁流程。
	var save_file: FileAccess = FileAccess.open(CHARACTER_UNLOCK_SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		return
	# 解锁存档数据；版本号为未来迁移保留，角色数组复制避免序列化期间被外部修改。
	var save_data: Dictionary = {
		"version": CHARACTER_UNLOCK_SAVE_VERSION,
		"unlocked_character_ids": _unlocked_character_ids.duplicate(),
	}
	save_file.store_string(JSON.stringify(save_data))


func _is_known_character(character_id: String) -> bool:
	## 验证角色稳定 ID 是否存在；不使用 normalize_character_id，避免未知值被回退为星。
	if character_id.is_empty():
		return false
	# 内容目录；正常运行时以自动发现结果作为唯一角色存在性来源。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog != null and content_catalog.has_method("has_character"):
		return bool(content_catalog.call("has_character", character_id))
	return character_id in [CHARACTER_STELLE, CHARACTER_CAEULUS, CHARACTER_SILVER_WOLF]
