extends Node

## 存档归档服务统一负责把多个独立服务拥有的持久化文件封装为单文件，并安全恢复到用户目录。
## 本服务不解析任何业务存档内容，也不替代各服务的保存职责；导出只读取已经落盘的数据，导入后通过重启让各服务重新加载。
## 删除功能补充：服务按同一白名单停用活动文件，并通过跨重启保护标记保证旧运行时状态不能重新落盘生效。

## 归档格式版本；默认 1，用于拒绝未来不兼容的结构，修改时必须同步迁移规则与框架文档。
const ARCHIVE_VERSION: int = 1
## 归档文件扩展名；默认 lisbamsave，供设置界面的文件选择器限制可见文件类型。
const ARCHIVE_EXTENSION: String = "lisbamsave"
## 导入备份目录前缀；默认位于 user://，每次成功导入前按时间戳保存被覆盖的旧文件。
const BACKUP_DIRECTORY_PREFIX: String = "save_import_backup_"
## 临时导入文件后缀；默认 temp_import，所有文件验证并写入成功后才替换正式存档。
const IMPORT_TEMPORARY_SUFFIX: String = ".temp_import"
## 临时删除文件后缀；删除时先把全部活动存档移出正式路径，全部成功后再清理，失败时可统一回滚。
const DELETE_TEMPORARY_SUFFIX: String = ".temp_delete"
## 删除待处理标记；删除确认后保留到下一次启动清理完成，用于拦截退出阶段可能发生的旧状态回写。
const DELETE_PENDING_MARKER_PATH: String = "user://save_delete_pending_v1.marker"
## 删除待处理标记内容；只用于人工识别文件用途，不参与业务状态、版本或兼容判断。
const DELETE_PENDING_MARKER_CONTENT: String = "Star Hacker save deletion pending."
## 游戏英文名；写入归档元数据便于跨语言环境识别，不参与兼容校验或导入资格判断。
const GAME_ENGLISH_NAME: String = "Star Hacker"
## 项目允许导出与导入的存档文件白名单；新增持久化服务时必须同步追加，避免遗漏或允许任意路径写入。
## 删除功能补充：同一白名单也是活动存档删除边界，非白名单文件与历史导入备份目录不受影响。
const SAVE_FILE_NAMES: Array[String] = [
	"character_unlocks.json",
	"input_bindings.cfg",
	"ui_style_settings.cfg",
	"debug_settings.cfg",
	"global_inventory.json",
	"shop_state.json",
	"stock_market_state.json",
	"mining_farm_state.json",
]


func _enter_tree() -> void:
	## 在其他持久化 AutoLoad 读取文件前完成上次确认的删除，确保退出阶段回写也不会恢复旧档。
	if FileAccess.file_exists(DELETE_PENDING_MARKER_PATH):
		_complete_pending_save_deletion()


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


func delete_save_data() -> Dictionary:
	## 删除全部白名单活动存档；先统一改名暂存，任一改名失败时回滚，避免下次启动读取半套存档。
	# 删除待处理标记写入结果；标记必须先落盘，保证意外退出或旧状态回写会在下一次启动继续清理。
	var marker_result: Error = _write_delete_pending_marker()
	if marker_result != OK:
		return _build_result(false, "无法创建删除保护标记，当前存档未修改。")
	# 已暂存记录；每项保存原路径与临时路径，供失败回滚和成功清理使用。
	var staged_records: Array[Dictionary] = []
	for file_name in SAVE_FILE_NAMES:
		# 正式存档路径；只由固定白名单拼接，删除入口不接受任何外部文件名或目录。
		var active_path: String = "user://" + file_name
		# 删除临时路径；与正式文件位于同一目录，改名不会跨文件系统。
		var staged_path: String = active_path + DELETE_TEMPORARY_SUFFIX
		# 上次异常退出遗留的临时删除文件；它不参与读档，但本次操作仍应先清理以保证删除结果完整。
		if FileAccess.file_exists(staged_path):
			# 遗留临时文件清理结果；无法清理时不触碰当前活动存档，避免覆盖或混合未知旧数据。
			var stale_remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(staged_path))
			if stale_remove_result != OK:
				return _build_delete_staging_failure_result(staged_records, "无法清理旧的删除临时文件：%s" % file_name)
		if not FileAccess.file_exists(active_path):
			continue
		# 暂存改名结果；只有所有现有活动文件都离开正式路径后才进入永久清理阶段。
		var stage_result: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(active_path), ProjectSettings.globalize_path(staged_path))
		if stage_result != OK:
			return _build_delete_staging_failure_result(staged_records, "删除存档失败：%s" % file_name)
		staged_records.append({"active_path": active_path, "staged_path": staged_path})

	# 临时文件清理失败列表；正式路径已经全部为空，残留临时文件不会被任何业务服务读取。
	var cleanup_failures: Array[String] = []
	for staged_record in staged_records:
		# 暂存文件路径；来源只可能是上方固定白名单改名结果。
		var staged_path: String = str(staged_record.get("staged_path", ""))
		if staged_path.is_empty() or not FileAccess.file_exists(staged_path):
			continue
		# 永久清理结果；失败时记录明确文件名，但不把旧数据恢复到活动路径。
		var remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(staged_path))
		if remove_result != OK:
			cleanup_failures.append(staged_path.get_file().trim_suffix(DELETE_TEMPORARY_SUFFIX))
	if not cleanup_failures.is_empty():
		return _build_result(true, "活动存档已删除，游戏重启后将继续清理临时文件：%s" % "、".join(cleanup_failures))

	return _build_result(true, "存档已删除，游戏将重启。")


func restart_game() -> void:
	## 请求桌面平台在退出后重启当前项目，使新导入存档由全部 AutoLoad 从干净状态重新读取。
	## 删除功能补充：删除成功时同样使用本入口，让下一进程在业务读档前消费保护标记并初始化默认状态。
	OS.set_restart_on_exit(true)
	get_tree().quit()


func _build_delete_staging_failure_result(staged_records: Array[Dictionary], failure_message: String) -> Dictionary:
	## 处理删除暂存阶段失败；只有文件回滚与保护标记解除都成功时才允许报告“当前存档已保留”。
	# 暂存文件回滚是否完整成功；false 表示部分活动文件已经无法安全恢复，必须继续执行删除保护。
	var rollback_succeeded: bool = _rollback_staged_save_files(staged_records)
	# 保护标记移除结果；仅在回滚完整时尝试解除，失败则保留标记并通过立即重启完成确定性删除。
	var marker_remove_result: Error = _remove_delete_pending_marker() if rollback_succeeded else FAILED
	if rollback_succeeded and marker_remove_result == OK:
		return _build_result(false, "%s，当前存档已保留。" % failure_message)
	return _build_result(true, "%s，无法安全恢复原状态，游戏将重启并完成存档删除。" % failure_message)


func _rollback_staged_save_files(staged_records: Array[Dictionary]) -> bool:
	## 把尚未进入永久清理阶段的临时文件恢复到原路径；按逆序处理并返回是否完整恢复。
	# 回滚是否完整成功；默认 true，任一路径冲突或改名失败后变为 false，调用方不得再承诺保留存档。
	var rollback_succeeded: bool = true
	for record_index in range(staged_records.size() - 1, -1, -1):
		# 暂存记录；键只由 delete_save_data() 创建，不接受归档或 UI 外部数据。
		var staged_record: Dictionary = staged_records[record_index]
		# 原活动路径；回滚前必须为空，避免覆盖删除流程之外新生成的数据。
		var active_path: String = str(staged_record.get("active_path", ""))
		# 临时路径；存在时才尝试改回正式文件名。
		var staged_path: String = str(staged_record.get("staged_path", ""))
		if active_path.is_empty() or staged_path.is_empty():
			rollback_succeeded = false
			continue
		if not FileAccess.file_exists(staged_path):
			continue
		if FileAccess.file_exists(active_path):
			rollback_succeeded = false
			continue
		# 回滚结果；失败表示底层文件系统异常，记录警告供开发者定位但不继续覆盖其他路径。
		var rollback_result: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(staged_path), ProjectSettings.globalize_path(active_path))
		if rollback_result != OK:
			rollback_succeeded = false
			push_warning("删除存档回滚失败：%s" % active_path.get_file())
	return rollback_succeeded


func _write_delete_pending_marker() -> Error:
	## 写入一次性删除保护标记；文件成功关闭后才返回 OK，调用方据此决定是否允许触碰活动存档。
	# 标记文件；位于固定 user:// 路径，不接受外部路径或文件名。
	var marker_file: FileAccess = FileAccess.open(DELETE_PENDING_MARKER_PATH, FileAccess.WRITE)
	if marker_file == null:
		return FileAccess.get_open_error()
	marker_file.store_string(DELETE_PENDING_MARKER_CONTENT)
	marker_file.close()
	return OK


func _remove_delete_pending_marker() -> Error:
	## 删除一次性保护标记；标记不存在视为已经完成，不影响删除失败后的安全回滚。
	if not FileAccess.file_exists(DELETE_PENDING_MARKER_PATH):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(DELETE_PENDING_MARKER_PATH))


func _complete_pending_save_deletion() -> void:
	## 清除活动文件、导入临时文件和删除临时文件；全部成功后才移除保护标记。
	# 清理失败路径；只记录固定白名单派生路径，非空表示下次启动仍需继续尝试。
	var cleanup_failures: Array[String] = []
	for file_name in SAVE_FILE_NAMES:
		# 当前模块相关路径；活动文件与两种临时文件都可能在异常退出后残留。
		var related_paths: Array[String] = [
			"user://" + file_name,
			"user://" + file_name + IMPORT_TEMPORARY_SUFFIX,
			"user://" + file_name + DELETE_TEMPORARY_SUFFIX,
		]
		for related_path in related_paths:
			if not FileAccess.file_exists(related_path):
				continue
			# 路径清理结果；失败时保留标记并继续处理其他模块，避免单文件异常阻断整体清理。
			var remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(related_path))
			if remove_result != OK:
				cleanup_failures.append(related_path.get_file())
	if not cleanup_failures.is_empty():
		push_warning("存档删除启动清理未完成：%s" % "、".join(cleanup_failures))
		return
	# 保护标记移除结果；失败时下次启动会幂等重复清理，不会恢复任何已经删除的数据。
	var marker_remove_result: Error = _remove_delete_pending_marker()
	if marker_remove_result != OK:
		push_warning("存档删除保护标记无法移除，将在下次启动重试。")


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
