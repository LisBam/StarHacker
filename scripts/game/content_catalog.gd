extends Node

## 内容目录在项目启动时扫描约定目录，为武器、装备、道具、怪物和角色提供统一自动注册入口。
## 内容文件只需放入对应目录并通过类型校验，商店、掉落、开发者发放、生成和角色系统即可共同读取。

## 武器资源目录；递归扫描 .tres 与 .res，运行时通常不动态修改。
@export_dir var weapons_directory: String = "res://data/weapons"
## 装备资源目录；递归扫描 .tres 与 .res，运行时通常不动态修改。
@export_dir var equipment_directory: String = "res://data/equipment"
## 通用道具资源目录；递归扫描 .tres 与 .res，当前接收 item_kind 不为空且不是武器或装备的资源。
@export_dir var items_directory: String = "res://data/items"
## 角色档案目录；递归扫描 .tres 与 .res，只接收声明有效 character_id 的角色资源。
@export_dir var characters_directory: String = "res://data/characters"
## 怪物场景目录；递归扫描 .tscn 与 .scn，所有可加载 PackedScene 都会进入随机怪物池。
@export_dir var enemies_directory: String = "res://scenes/enemies"

## 已发现武器路径；键为稳定 weapon_id，值为项目资源路径，同 ID 重复时保留排序靠前的文件。
var _weapon_paths_by_id: Dictionary = {}
## 已发现装备路径；键为稳定 equipment_id，值为项目资源路径，同 ID 重复时保留排序靠前的文件。
var _equipment_paths_by_id: Dictionary = {}
## 已发现道具路径；键为稳定 item_id，值为项目资源路径，同 ID 重复时保留排序靠前的文件。
var _item_paths_by_id: Dictionary = {}
## 已发现角色档案；键为稳定 character_id，值为只读角色档案词典，同 ID 重复时保留排序靠前的文件。
var _character_profiles_by_id: Dictionary = {}
## 已发现角色顺序；按资源路径稳定排序，默认角色 stelle 存在时会固定排在首位。
var _character_ids: Array[String] = []
## 已发现怪物场景路径；按路径稳定排序，供世界生成时加载为随机场景池。
var _enemy_scene_paths: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reload_catalog()


func reload_catalog() -> void:
	_weapon_paths_by_id = _scan_identified_resources(weapons_directory, "weapon_id", "weapon")
	_equipment_paths_by_id = _scan_identified_resources(equipment_directory, "equipment_id", "equipment")
	_item_paths_by_id = _scan_identified_resources(items_directory, "item_id", "item")
	_scan_character_profiles()
	_enemy_scene_paths = _scan_scene_paths(enemies_directory)


func get_weapon_paths() -> PackedStringArray:
	return _dictionary_values_as_paths(_weapon_paths_by_id)


func get_equipment_paths() -> PackedStringArray:
	return _dictionary_values_as_paths(_equipment_paths_by_id)


func get_item_paths() -> PackedStringArray:
	return _dictionary_values_as_paths(_item_paths_by_id)


func get_enemy_scene_paths() -> PackedStringArray:
	return _enemy_scene_paths.duplicate()


func get_weapon_path(weapon_id: String) -> String:
	return str(_weapon_paths_by_id.get(weapon_id, ""))


func get_equipment_path(equipment_id: String) -> String:
	return str(_equipment_paths_by_id.get(equipment_id, ""))


func get_item_path(item_id: String) -> String:
	return str(_item_paths_by_id.get(item_id, ""))


func get_character_ids() -> Array[String]:
	return _character_ids.duplicate()


func has_character(character_id: String) -> bool:
	return _character_profiles_by_id.has(character_id)


func get_default_character_id() -> String:
	if _character_profiles_by_id.has("stelle"):
		return "stelle"
	return _character_ids[0] if not _character_ids.is_empty() else "stelle"


func get_character_profile(character_id: String) -> Dictionary:
	# 已注册档案；返回深拷贝，避免 UI 或战斗系统意外修改目录中的权威配置。
	var profile: Dictionary = _character_profiles_by_id.get(character_id, {}) as Dictionary
	return profile.duplicate(true)


func _scan_identified_resources(directory_path: String, id_property: String, expected_kind: String) -> Dictionary:
	# 扫描结果；按路径排序后首次出现的稳定 ID 生效，避免文件系统遍历顺序造成结果变化。
	var result: Dictionary = {}
	# 候选路径；递归读取资源扩展名，子目录可用于内容分组且无需额外登记。
	var candidate_paths: PackedStringArray = _collect_files(directory_path, PackedStringArray(["tres", "res"]))
	for resource_path in candidate_paths:
		# 内容模板；加载失败或缺少稳定 ID 时忽略，其他合法内容仍可正常注册。
		var content_resource: Resource = load(resource_path) as Resource
		if content_resource == null or not _resource_has_property(content_resource, id_property) or not _resource_has_property(content_resource, "item_kind"):
			continue
		# 稳定内容标识；必须非空，复制模板时必须同步修改以避免覆盖原内容注册。
		var content_id: String = str(content_resource.get(id_property)).strip_edges()
		if content_id.is_empty() or result.has(content_id):
			continue
		# 内容类型；武器和装备必须精确匹配，items 目录接收其余声明 item_kind 的通用道具。
		var item_kind: String = str(content_resource.get("item_kind")).strip_edges()
		if expected_kind == "item":
			if item_kind.is_empty() or item_kind in ["weapon", "equipment"]:
				continue
		elif item_kind != expected_kind:
			continue
		result[content_id] = resource_path
	return result


func _scan_character_profiles() -> void:
	_character_profiles_by_id.clear()
	_character_ids.clear()
	# 角色资源路径；按路径稳定排序，允许通过子目录组织不同阵营或版本的角色档案。
	var character_paths: PackedStringArray = _collect_files(characters_directory, PackedStringArray(["tres", "res"]))
	for resource_path in character_paths:
		# 角色资源；只要求公开 character_id 和 to_profile，避免内容目录依赖脚本全局类解析顺序。
		var character_resource: Resource = load(resource_path) as Resource
		if character_resource == null or not character_resource.has_method("to_profile") or not _resource_has_property(character_resource, "character_id"):
			continue
		# 角色标识；空值或重复值不会注册，保证选择与存档映射始终唯一。
		var character_id: String = str(character_resource.get("character_id")).strip_edges()
		if character_id.is_empty() or _character_profiles_by_id.has(character_id):
			continue
		# 角色档案；资源方法负责生成完整字段，目录额外写入源路径便于维护时追踪。
		var profile: Dictionary = character_resource.call("to_profile") as Dictionary
		profile["resource_path"] = resource_path
		_character_profiles_by_id[character_id] = profile
		_character_ids.append(character_id)
	if _character_ids.has("stelle"):
		_character_ids.erase("stelle")
		_character_ids.push_front("stelle")


func _scan_scene_paths(directory_path: String) -> PackedStringArray:
	# 场景结果；只保留 ResourceLoader 可识别且实际加载为 PackedScene 的文件。
	var result: PackedStringArray = PackedStringArray()
	for scene_path in _collect_files(directory_path, PackedStringArray(["tscn", "scn"])):
		var enemy_scene: PackedScene = load(scene_path) as PackedScene
		if enemy_scene != null:
			result.append(scene_path)
	return result


func _collect_files(directory_path: String, allowed_extensions: PackedStringArray) -> PackedStringArray:
	# 收集结果；目录缺失时保持为空，调用方会继续使用原有检查器配置作为兼容兜底。
	var result: PackedStringArray = PackedStringArray()
	# 待扫描目录；使用数组模拟队列并递归处理所有子目录。
	var pending_directories: PackedStringArray = PackedStringArray([directory_path])
	while not pending_directories.is_empty():
		# 当前目录；从队列尾部取出，遍历完成后结果统一排序，因此不依赖访问次序。
		var current_directory: String = pending_directories[pending_directories.size() - 1]
		pending_directories.remove_at(pending_directories.size() - 1)
		# 目录访问器；外部复制尚未完成或目录不存在时忽略该目录，不中断其他内容扫描。
		var directory: DirAccess = DirAccess.open(current_directory)
		if directory == null:
			continue
		directory.list_dir_begin()
		# 当前文件名；空字符串表示本目录遍历完成。
		var entry_name: String = directory.get_next()
		while not entry_name.is_empty():
			if entry_name != "." and entry_name != "..":
				# 完整内容路径；统一使用正斜杠拼接 Godot 资源路径。
				var entry_path: String = current_directory.path_join(entry_name)
				if directory.current_is_dir():
					pending_directories.append(entry_path)
				elif entry_name.get_extension().to_lower() in allowed_extensions:
					result.append(entry_path)
			entry_name = directory.get_next()
		directory.list_dir_end()
	result.sort()
	return result


func _dictionary_values_as_paths(path_dictionary: Dictionary) -> PackedStringArray:
	# 路径数组；先按路径排序，保证随机池之外的列表和开发者发放顺序可复现。
	var result: PackedStringArray = PackedStringArray()
	for raw_path in path_dictionary.values():
		result.append(str(raw_path))
	result.sort()
	return result


func _resource_has_property(content_resource: Resource, property_name: String) -> bool:
	if content_resource == null:
		return false
	# 属性描述；Godot 资源通过属性列表公开脚本导出字段，先检查可避免误放资源触发无效 get 错误。
	for property_info in content_resource.get_property_list():
		if str((property_info as Dictionary).get("name", "")) == property_name:
			return true
	return false
