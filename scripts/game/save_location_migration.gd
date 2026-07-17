extends Node

## 存档目录迁移服务在其他 AutoLoad 初始化前，把旧游戏名对应 user:// 目录中的持久化文件复制到新目录。
## 迁移只在新目录缺少完成标记时执行一次；业务服务仍各自拥有文件内容、版本和后续保存职责。

## 旧项目目录名；仅用于游戏重命名后的首次兼容迁移，不再作为任何玩家可见名称或新存档标识。
const LEGACY_PROJECT_DIRECTORY_NAME: String = "崩坏：量子骇袭"
## 迁移完成标记；成功复制全部可用旧文件后写入新 user://，后续启动不再覆盖新存档。
const MIGRATION_MARKER_PATH: String = "user://save_location_migration_v1.complete"
## 单文件迁移临时后缀；先完整复制到同目录临时文件，再替换目标，避免复制失败破坏已有新目录文件。
const MIGRATION_TEMPORARY_SUFFIX: String = ".legacy_migration_temp"
## 旧目录允许迁移的持久化文件白名单；与存档归档服务保持相同业务范围，禁止复制未知文件。
const PERSISTENT_FILE_NAMES: Array[String] = [
	"character_unlocks.json",
	"input_bindings.cfg",
	"debug_settings.cfg",
	"global_inventory.json",
	"shop_state.json",
	"stock_market_state.json",
	"mining_farm_state.json",
]


func _enter_tree() -> void:
	## 在后续 AutoLoad 读取业务存档前完成目录迁移；失败时不写标记，下次启动会再次尝试。
	# 存档迁移停用；项目尚未发布正式版本，不再自动复制任何历史项目目录中的存档文件。
	# _migrate_legacy_save_directory()
	pass


func _migrate_legacy_save_directory() -> void:
	## 从当前 user:// 的同级旧项目目录复制白名单文件；旧目录不存在时直接写入完成标记。
	if FileAccess.file_exists(MIGRATION_MARKER_PATH):
		return
	# 当前用户数据绝对目录；项目名已经是星穹骇客，所有新业务服务都会从这里读取文件。
	var current_user_directory: String = ProjectSettings.globalize_path("user://").trim_suffix("/").trim_suffix("\\")
	# Godot 项目用户目录父级；旧名与新名目录在默认桌面配置下位于同一父目录。
	var user_directories_parent: String = current_user_directory.get_base_dir()
	# 旧用户数据绝对目录；只由固定历史项目名拼接，不接受外部输入。
	var legacy_user_directory: String = user_directories_parent.path_join(LEGACY_PROJECT_DIRECTORY_NAME)
	# 迁移是否完整成功；任一存在的旧文件复制失败时保持 false 并留待下次启动重试。
	var migration_succeeded: bool = true
	if DirAccess.dir_exists_absolute(legacy_user_directory) and current_user_directory.simplify_path() != legacy_user_directory.simplify_path():
		# 新用户目录创建结果；目录通常已由 Godot 建立，异常缺失时递归创建。
		var make_directory_result: Error = DirAccess.make_dir_recursive_absolute(current_user_directory)
		if make_directory_result != OK:
			migration_succeeded = false
		else:
			for file_name in PERSISTENT_FILE_NAMES:
				# 旧存档源路径；缺失文件代表对应模块尚未生成，不视为迁移失败。
				var source_path: String = legacy_user_directory.path_join(file_name)
				if not FileAccess.file_exists(source_path):
					continue
				# 新存档目标路径；首次迁移标记缺失时以旧目录快照覆盖本次启动前可能产生的空白默认文件。
				var destination_path: String = current_user_directory.path_join(file_name)
				# 同目录临时路径；完整复制成功前不触碰已有目标文件，下一次重试会先清理旧临时残留。
				var temporary_path: String = destination_path + MIGRATION_TEMPORARY_SUFFIX
				if FileAccess.file_exists(temporary_path):
					DirAccess.remove_absolute(temporary_path)
				# 文件复制结果；失败时保留旧目录原文件和当前目标文件，并通过无标记状态在下次启动继续尝试。
				var copy_result: Error = DirAccess.copy_absolute(source_path, temporary_path)
				if copy_result != OK:
					migration_succeeded = false
					push_warning("旧存档迁移失败：%s" % file_name)
					continue
				# 旧目标移除结果；只有临时副本已经完整生成后才删除本次启动前的目标文件。
				var remove_result: Error = DirAccess.remove_absolute(destination_path) if FileAccess.file_exists(destination_path) else OK
				if remove_result != OK:
					migration_succeeded = false
					DirAccess.remove_absolute(temporary_path)
					push_warning("旧存档迁移无法替换目标：%s" % file_name)
					continue
				# 临时文件转正结果；同目录重命名保证不会跨文件系统，并在失败时保留旧目录源文件供重试。
				var rename_result: Error = DirAccess.rename_absolute(temporary_path, destination_path)
				if rename_result != OK:
					migration_succeeded = false
					push_warning("旧存档迁移转正失败：%s" % file_name)
	if not migration_succeeded:
		return
	# 完成标记文件；内容只用于人工识别迁移来源，不参与业务存档解析。
	var marker_file: FileAccess = FileAccess.open(MIGRATION_MARKER_PATH, FileAccess.WRITE)
	if marker_file != null:
		marker_file.store_string("Star Hacker save directory migration completed.")
		marker_file.close()
