extends Node

## 存档归档服务统一负责把多个独立服务拥有的持久化文件封装为单文件，并安全恢复到用户目录。
## 本服务不解析任何业务存档内容，也不替代各服务的保存职责；导出只读取已经落盘的数据，导入后通过重启让各服务重新加载。

## 归档格式版本；默认 1，用于拒绝未来不兼容的结构，修改时必须同步迁移规则与框架文档。
const ARCHIVE_VERSION: int = 1
## 归档文件扩展名；默认 lisbamsave，供设置界面的文件选择器限制可见文件类型。
const ARCHIVE_EXTENSION: String = "lisbamsave"
## 导入备份目录前缀；默认位于 user://，每次成功导入前按时间戳保存被覆盖的旧文件。
const BACKUP_DIRECTORY_PREFIX: String = "save_import_backup_"
## 临时导入文件后缀；默认 temp_import，所有文件验证并写入成功后才替换正式存档。
const IMPORT_TEMPORARY_SUFFIX: String = ".temp_import"
## 游戏英文名；写入归档元数据便于跨语言环境识别，不参与兼容校验或导入资格判断。
const GAME_ENGLISH_NAME: String = "Star Hacker"
## 项目允许导出与导入的存档文件白名单；新增持久化服务时必须同步追加，避免遗漏或允许任意路径写入。
const SAVE_FILE_NAMES: Array[String] = [
	"character_unlocks.json",
	"input_bindings.cfg",
	"debug_settings.cfg",
	"global_inventory.json",
	"shop_state.json",
	"stock_market_state.json",
	"mining_farm_state.json",
]


func export_archive(destination_path: String) -> Dictionary:
	## 把当前已落盘的白名单存档编码为单个 JSON 归档；返回 success、message 与最终路径供 UI 展示。
	# 标准化导出路径；空路径直接拒绝，缺少扩展名时自动补全项目专用后缀。
	var resolved_path: String = destination_path.strip_edges()
	if resolved_path.is_empty():
		return _build_result(false, "未选择导出位置。")
	if resolved_path.get_extension().to_lower() != ARCHIVE_EXTENSION:
		resolved_path += "." + ARCHIVE_EXTENSION

	# 归档文件内容；键为固定文件名，值为 Base64 字节，业务 JSON 与 CFG 均保持原始内容不被二次解析。
	var archived_files: Dictionary = {}
	for file_name in SAVE_FILE_NAMES:
		# 用户目录源路径；只由固定白名单拼接，不接受归档或 UI 提供的相对路径。
		var source_path: String = "user://" + file_name
		if not FileAccess.file_exists(source_path):
			continue
		# 源存档字节；读取失败时中止，避免生成表面成功但缺少部分已有存档的归档。
		var source_bytes: PackedByteArray = FileAccess.get_file_as_bytes(source_path)
		if FileAccess.get_open_error() != OK:
			return _build_result(false, "读取存档失败：%s" % file_name)
		archived_files[file_name] = Marshalls.raw_to_base64(source_bytes)

	# 归档根数据；项目名与时间仅用于人工识别，兼容判断只依赖格式版本和文件白名单。
	var archive_data: Dictionary = {
		"archive_version": ARCHIVE_VERSION,
		"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
		"project_name_en": str(ProjectSettings.get_setting("application/config/name_en", GAME_ENGLISH_NAME)),
		"exported_unix_time": int(Time.get_unix_time_from_system()),
		"files": archived_files,
	}
	# 目标文件；采用格式化 JSON 便于人工检查，内容字节仍使用 Base64 保证 CFG 与 Unicode 无损往返。
	var archive_file: FileAccess = FileAccess.open(resolved_path, FileAccess.WRITE)
	if archive_file == null:
		return _build_result(false, "无法写入导出文件。")
	archive_file.store_string(JSON.stringify(archive_data, "\t"))
	archive_file.close()
	return {"success": true, "message": "存档已导出。", "path": resolved_path}


func import_archive(source_path: String) -> Dictionary:
	## 校验归档、写入临时文件、备份旧存档并原子替换；成功后调用方应重启游戏使所有 AutoLoad 重新加载。
	if source_path.strip_edges().is_empty() or not FileAccess.file_exists(source_path):
		return _build_result(false, "未找到要导入的存档文件。")
	# 归档文本；读取失败或空文件都不能进入覆盖流程。
	var archive_text: String = FileAccess.get_file_as_string(source_path)
	if FileAccess.get_open_error() != OK or archive_text.is_empty():
		return _build_result(false, "无法读取导入文件。")
	# JSON 解析结果；仅接受字典根节点，防止数组或普通值绕过字段校验。
	var parsed_archive: Variant = JSON.parse_string(archive_text)
	if not (parsed_archive is Dictionary):
		return _build_result(false, "导入文件不是有效的存档归档。")
	# 归档根字典；版本必须精确匹配，未来版本需先实现迁移再放宽读取范围。
	var archive_data: Dictionary = parsed_archive as Dictionary
	if int(archive_data.get("archive_version", 0)) != ARCHIVE_VERSION:
		return _build_result(false, "存档归档版本不受支持。")
	# 文件集合；至少包含一个白名单文件，且不得带入未知文件名或路径分隔符。
	var archived_files_value: Variant = archive_data.get("files", {})
	if not (archived_files_value is Dictionary):
		return _build_result(false, "存档归档缺少文件内容。")
	var archived_files: Dictionary = archived_files_value as Dictionary
	if archived_files.is_empty():
		return _build_result(false, "存档归档中没有可导入的数据。")

	# 已验证字节；全部文件通过名称与 Base64 往返校验后才创建任何临时文件。
	var decoded_files: Dictionary = {}
	for raw_file_name in archived_files.keys():
		# 归档文件名；必须精确命中白名单，禁止目录穿越与额外配置文件写入用户目录。
		var file_name: String = str(raw_file_name)
		if not SAVE_FILE_NAMES.has(file_name):
			return _build_result(false, "存档归档包含未知文件：%s" % file_name)
		# Base64 文本；空文件允许导入，但字段类型必须为字符串以保持结构稳定。
		var encoded_content_value: Variant = archived_files.get(raw_file_name)
		if not (encoded_content_value is String):
			return _build_result(false, "存档归档文件内容无效：%s" % file_name)
		var encoded_content: String = encoded_content_value
		# 解码字节；重新编码必须与标准化输入一致，避免非法字符被静默忽略后写入损坏文件。
		var decoded_content: PackedByteArray = Marshalls.base64_to_raw(encoded_content)
		if Marshalls.raw_to_base64(decoded_content) != encoded_content:
			return _build_result(false, "存档归档文件编码损坏：%s" % file_name)
		decoded_files[file_name] = decoded_content

	# 临时文件名列表；记录已成功写入的路径，任一步失败时统一清理而不触碰正式存档。
	var temporary_paths: Array[String] = []
	for file_name in decoded_files.keys():
		# 临时目标路径；与正式文件同处 user://，保证后续重命名不跨文件系统。
		var temporary_path: String = "user://" + str(file_name) + IMPORT_TEMPORARY_SUFFIX
		# 临时文件；二进制写入保留原始 JSON、CFG 编码与换行。
		var temporary_file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
		if temporary_file == null:
			_cleanup_temporary_files(temporary_paths)
			return _build_result(false, "无法准备导入文件：%s" % str(file_name))
		temporary_file.store_buffer(decoded_files[file_name] as PackedByteArray)
		temporary_file.close()
		temporary_paths.append(temporary_path)

	# 备份目录；只在所有临时文件完整写入后创建，目录名使用秒级时间戳并在冲突时追加序号。
	var backup_directory: String = _create_unique_backup_directory()
	if backup_directory.is_empty():
		_cleanup_temporary_files(temporary_paths)
		return _build_result(false, "无法创建导入前备份目录。")
	for file_name in SAVE_FILE_NAMES:
		# 当前正式存档；缺失文件无需生成空备份。
		var current_path: String = "user://" + file_name
		if FileAccess.file_exists(current_path):
			# 备份结果；任一已有文件复制失败都停止导入，确保正式文件尚未被触碰且旧状态完整保留。
			var copy_result: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(current_path), ProjectSettings.globalize_path(backup_directory + "/" + file_name))
			if copy_result != OK:
				_cleanup_temporary_files(temporary_paths)
				return _build_result(false, "备份当前存档失败：%s" % file_name)

	# 正式存档清理；归档中缺失的白名单文件代表当时尚未产生该模块数据，必须移除当前同名文件避免混合两套状态。
	for file_name in SAVE_FILE_NAMES:
		# 待替换正式路径；所有旧文件已完整备份，因此此处可以按归档快照统一清理。
		var existing_destination_path: String = "user://" + file_name
		if FileAccess.file_exists(existing_destination_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(existing_destination_path))

	for file_name in decoded_files.keys():
		# 正式目标路径；先移除旧文件，再把同目录临时文件改名为正式文件。
		var destination_path: String = "user://" + str(file_name)
		var temporary_path: String = destination_path + IMPORT_TEMPORARY_SUFFIX
		# 重命名结果；失败时保留其他已导入文件与完整备份，并明确要求用户可从备份恢复。
		var rename_result: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(destination_path))
		if rename_result != OK:
			_cleanup_temporary_files(temporary_paths)
			return _build_result(false, "替换存档失败，旧存档已备份到：%s" % backup_directory)

	return {"success": true, "message": "存档导入成功，游戏将重启。", "backup_path": backup_directory}


func restart_game() -> void:
	## 请求桌面平台在退出后重启当前项目，使新导入存档由全部 AutoLoad 从干净状态重新读取。
	OS.set_restart_on_exit(true)
	get_tree().quit()


func _create_unique_backup_directory() -> String:
	# 基础备份目录；时间戳便于玩家按导入时间定位旧存档，冲突时通过递增后缀解决。
	var base_directory: String = "user://" + BACKUP_DIRECTORY_PREFIX + str(int(Time.get_unix_time_from_system()))
	# 当前候选目录；默认使用基础目录，最多尝试 100 个后缀避免异常循环。
	var candidate_directory: String = base_directory
	for suffix_index in range(100):
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate_directory)):
			# 创建结果；只有递归创建成功才返回路径，调用方据此决定是否继续覆盖正式文件。
			var make_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(candidate_directory))
			return candidate_directory if make_result == OK else ""
		candidate_directory = "%s_%d" % [base_directory, suffix_index + 1]
	return ""


func _cleanup_temporary_files(temporary_paths: Array[String]) -> void:
	## 删除本次导入创建但尚未转正的临时文件；正式存档和备份目录不在清理范围内。
	for temporary_path in temporary_paths:
		if FileAccess.file_exists(temporary_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))


func _build_result(success: bool, message: String) -> Dictionary:
	## 构建统一操作结果，避免 UI 依赖错误码或服务内部实现细节。
	return {"success": success, "message": message}
