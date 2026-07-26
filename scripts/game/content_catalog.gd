extends Node

## 内容目录在项目启动时扫描约定目录，为武器、装备、道具、怪物和角色提供统一自动注册入口。
## 内容文件只需放入对应目录并通过类型校验，商店、掉落、开发者发放、生成和角色系统即可共同读取。

## 可用内容发生变化信号；角色解锁扩展包后通知长期运行的商店等服务合并新路径。
signal content_availability_changed

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
## 扩展包清单目录；递归扫描 .tres 与 .res，清单把角色解锁状态映射到四类自动发现内容。
@export_dir var content_packs_directory: String = "res://data/content_packs"

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
## 已发现扩展包资源；键为稳定 pack_id，值为 ContentPackData 兼容资源，同 ID 重复时保留排序靠前的文件。
var _content_packs_by_id: Dictionary = {}
## 已发现扩展包顺序；按清单资源路径稳定排序，供解锁服务和调试界面复用。
var _content_pack_ids: Array[String] = []
## 角色对应扩展包索引；键为 character_id，值为该角色唯一扩展包 ID，重复归属时保留排序靠前的清单。
var _content_pack_id_by_character_id: Dictionary = {}
## 内容路径对应扩展包索引；没有登记的路径属于基础内容并始终可用，登记路径随所属角色解锁。
var _content_pack_id_by_resource_path: Dictionary = {}


func _ready() -> void:
	reload_catalog()


func reload_catalog() -> void:
	_weapon_paths_by_id = _scan_identified_resources(weapons_directory, "weapon_id", "weapon")
	_equipment_paths_by_id = _scan_identified_resources(equipment_directory, "equipment_id", "equipment")
	_item_paths_by_id = _scan_identified_resources(items_directory, "item_id", "item")
	_scan_character_profiles()
	_enemy_scene_paths = _scan_scene_paths(enemies_directory)
	_scan_content_packs()


func get_weapon_paths() -> PackedStringArray:
	return _filter_unlocked_content_paths(_dictionary_values_as_paths(_weapon_paths_by_id))


func get_all_weapon_paths() -> PackedStringArray:
	## 返回目录中全部已注册武器模板路径；图鉴等只读内容展示使用此接口，不受角色扩展包当前可用状态过滤。
	return _dictionary_values_as_paths(_weapon_paths_by_id)


func get_equipment_paths() -> PackedStringArray:
	return _filter_unlocked_content_paths(_dictionary_values_as_paths(_equipment_paths_by_id))


func get_all_equipment_paths() -> PackedStringArray:
	## 返回目录中全部已注册装备模板路径；调用方只能读取模板元数据，不能把此接口作为掉落或商店内容池使用。
	return _dictionary_values_as_paths(_equipment_paths_by_id)


func get_item_paths() -> PackedStringArray:
	return _filter_unlocked_content_paths(_dictionary_values_as_paths(_item_paths_by_id))


func get_all_item_paths() -> PackedStringArray:
	## 返回目录中全部已注册通用道具模板路径；图鉴借此为未发现的资源保留“？？？”占位条目。
	return _dictionary_values_as_paths(_item_paths_by_id)


func get_enemy_scene_paths() -> PackedStringArray:
	return _filter_unlocked_content_paths(_enemy_scene_paths)


func get_all_enemy_scene_paths() -> PackedStringArray:
	## 返回全部已注册怪物场景路径；图鉴使用未经过角色扩展包可用性过滤的目录，保留未遇到怪物的占位条目。
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


func get_content_pack_ids() -> Array[String]:
	## 返回全部合法扩展包 ID；是否已解锁由 SessionState 根据所属角色单独判断。
	return _content_pack_ids.duplicate()


func has_content_pack(pack_id: String) -> bool:
	## 判断扩展包是否存在于当前目录；空 ID 与重复后被忽略的清单均返回 false。
	return _content_packs_by_id.has(pack_id)


func get_content_pack_character_id(pack_id: String) -> String:
	## 返回扩展包所属角色；无效扩展包回退空字符串，避免误把基础内容绑定到默认角色。
	# 扩展包资源；只读取公开 character_id 字段，不让解锁服务依赖具体资源脚本类型。
	var content_pack: Resource = _content_packs_by_id.get(pack_id) as Resource
	return str(content_pack.get("character_id")).strip_edges() if content_pack != null else ""


func get_content_pack_id_for_character(character_id: String) -> String:
	## 返回角色对应的唯一扩展包 ID；当前未创建清单的角色返回空字符串并保持原有角色内容不变。
	return str(_content_pack_id_by_character_id.get(character_id, ""))


func get_content_pack_id_for_resource_path(resource_path: String) -> String:
	## 返回内容资源所属扩展包 ID；未登记路径属于基础内容并返回空字符串，图鉴等只读界面可据此筛选而不触碰可用内容池规则。
	# 标准化资源路径；空路径没有可追溯的内容归属，直接按基础内容处理以避免误匹配。
	var normalized_resource_path: String = resource_path.strip_edges()
	return str(_content_pack_id_by_resource_path.get(normalized_resource_path, "")) if not normalized_resource_path.is_empty() else ""


func get_content_pack_profile(pack_id: String) -> Dictionary:
	## 返回扩展包只读快照；调用方可检查归属与各类内容路径，但不能修改目录内的权威清单资源。
	# 扩展包资源；不存在时返回空词典，调用方可据此判断无效 ID。
	var content_pack: Resource = _content_packs_by_id.get(pack_id) as Resource
	if content_pack == null:
		return {}
	return {
		"pack_id": pack_id,
		"display_name": str(content_pack.get("display_name")),
		"character_id": str(content_pack.get("character_id")),
		"weapon_paths": content_pack.call("get_weapon_paths"),
		"equipment_paths": content_pack.call("get_equipment_paths"),
		"item_paths": content_pack.call("get_item_paths"),
		"enemy_scene_paths": content_pack.call("get_enemy_scene_paths"),
	}


func is_content_path_available(content_path: String) -> bool:
	## 公开查询任意资源路径当前是否可用；旧场景和服务的检查器兜底数组必须通过此接口避免绕过扩展包过滤。
	return _is_content_path_unlocked(content_path)


func notify_unlock_state_changed() -> void:
	## 由角色解锁服务在永久解锁成功后调用；目录内容本身不重扫，只通知消费者重新查询过滤结果。
	content_availability_changed.emit()


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


func _scan_content_packs() -> void:
	## 扫描扩展包清单并建立角色、内容路径到扩展包的双向索引。
	_content_packs_by_id.clear()
	_content_pack_ids.clear()
	_content_pack_id_by_character_id.clear()
	_content_pack_id_by_resource_path.clear()
	# 扩展包资源路径；按完整路径稳定排序，重复 ID 与重复归属始终保留第一份。
	var content_pack_paths: PackedStringArray = _collect_files(content_packs_directory, PackedStringArray(["tres", "res"]))
	for content_pack_path in content_pack_paths:
		# 扩展包资源；必须同时公开稳定 ID、所属角色与完整路径查询接口。
		var content_pack: Resource = load(content_pack_path) as Resource
		if content_pack == null or not _resource_has_property(content_pack, "pack_id") or not _resource_has_property(content_pack, "character_id") or not content_pack.has_method("get_all_content_paths"):
			continue
		# 扩展包标识；空值或重复值不会注册，避免一个解锁键对应多份不确定清单。
		var pack_id: String = str(content_pack.get("pack_id")).strip_edges()
		# 所属角色标识；必须已经存在于角色目录，防止无法通过任何角色解锁的内容进入归属表。
		var character_id: String = str(content_pack.get("character_id")).strip_edges()
		if pack_id.is_empty() or character_id.is_empty() or _content_packs_by_id.has(pack_id) or _content_pack_id_by_character_id.has(character_id) or not _character_profiles_by_id.has(character_id):
			continue
		_content_packs_by_id[pack_id] = content_pack
		_content_pack_ids.append(pack_id)
		_content_pack_id_by_character_id[character_id] = pack_id
		# 归属内容路径；多个清单误填同一路径时保留排序靠前的扩展包，保证过滤结果可复现。
		for owned_content_path in content_pack.call("get_all_content_paths") as PackedStringArray:
			if not owned_content_path.is_empty() and not _content_pack_id_by_resource_path.has(owned_content_path):
				_content_pack_id_by_resource_path[owned_content_path] = pack_id


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


func _filter_unlocked_content_paths(content_paths: PackedStringArray) -> PackedStringArray:
	## 过滤扩展包内容并保持原路径顺序；基础内容不绑定扩展包，因此始终保留。
	# 可用内容路径；每次查询实时读取 SessionState，使角色解锁后无需重启目录服务。
	var unlocked_paths: PackedStringArray = PackedStringArray()
	# 会话状态服务快照；整次过滤只在循环外解析一次根节点，循环内不再对每条路径重复执行节点查找。
	var resolved_session_state: Node = get_tree().root.get_node_or_null("SessionState")
	for content_path in content_paths:
		if _is_content_path_unlocked(content_path, resolved_session_state):
			unlocked_paths.append(content_path)
	return unlocked_paths


func _is_content_path_unlocked(content_path: String, session_state_override: Node = null) -> bool:
	## 判断单个内容路径是否可用；未登记路径属于基础内容，扩展包路径必须由所属角色解锁。
	## 批量过滤补充：调用方可传入已解析的会话状态实例避免循环内重复查找，未传入时保持原实时查询行为不变。
	# 扩展包标识；空值表示该内容没有专属归属限制。
	var pack_id: String = str(_content_pack_id_by_resource_path.get(content_path, ""))
	if pack_id.is_empty():
		return true
	# 会话状态服务；正常项目运行时统一持有永久角色解锁列表。
	var session_state: Node = session_state_override if session_state_override != null else get_tree().root.get_node_or_null("SessionState")
	if session_state != null and session_state.has_method("is_content_pack_unlocked"):
		return bool(session_state.call("is_content_pack_unlocked", pack_id))
	# 所属角色档案；隔离加载 ContentCatalog 时按角色默认解锁字段回退，避免启动顺序造成内容暂时消失。
	var character_id: String = get_content_pack_character_id(pack_id)
	# 角色档案；只有显式声明默认解锁才允许在 SessionState 缺失时开放扩展包。
	var character_profile: Dictionary = _character_profiles_by_id.get(character_id, {}) as Dictionary
	return bool(character_profile.get("unlocked_by_default", false))


func _resource_has_property(content_resource: Resource, property_name: String) -> bool:
	if content_resource == null:
		return false
	# 属性描述；Godot 资源通过属性列表公开脚本导出字段，先检查可避免误放资源触发无效 get 错误。
	# 性能补充：in 运算符按属性名直接查询对象，与逐条遍历 get_property_list 匹配 name 字段的语义等价且无需构建完整属性数组。
	return property_name in content_resource
