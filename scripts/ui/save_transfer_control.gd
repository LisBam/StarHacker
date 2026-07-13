extends VBoxContainer
class_name SaveTransferControl

## 存档传输控件为主菜单与暂停设置提供统一的导出、导入文件选择和结果提示。
## 控件只调用 SaveArchiveService 的公开接口，不读取任何业务存档文件，也不持有游戏数据副本。

## 操作按钮最小高度；默认 42 像素，与设置页按键绑定及返回按钮保持一致，运行时无需动态修改。
@export_range(24.0, 96.0, 1.0) var button_minimum_height: float = 42.0
## 状态文本自动隐藏时间；默认 4 秒，0 表示保持到下一次操作，修改只影响提示可见时长。
@export_range(0.0, 30.0, 0.5) var status_visible_duration: float = 4.0

## 导出按钮；默认运行时创建，点击后打开保存文件对话框。
var _export_button: Button
## 导入按钮；默认运行时创建，点击后打开文件选择对话框。
var _import_button: Button
## 操作状态标签；默认隐藏，显示成功、失败和战斗中导出边界提示。
var _status_label: Label
## 导出文件对话框；默认允许访问系统文件，保存扩展名为 lisbamsave 的归档。
var _export_dialog: FileDialog
## 导入文件对话框；默认允许访问系统文件，只选择单个 lisbamsave 归档。
var _import_dialog: FileDialog
## 状态提示剩余时间；取值大于等于 0，默认 0 表示不自动倒计时。
var _status_time_remaining: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 6)
	_build_controls()


func _process(delta: float) -> void:
	if _status_label == null or not _status_label.visible or _status_time_remaining <= 0.0:
		return
	_status_time_remaining = maxf(_status_time_remaining - delta, 0.0)
	if _status_time_remaining <= 0.0:
		_status_label.visible = false


func _build_controls() -> void:
	## 创建一行双按钮、状态标签和两个系统文件对话框；重复进入场景不会重复构建。
	if _export_button != null:
		return
	# 按钮行；两个操作等宽显示，避免设置首页因文本长度产生不对称布局。
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	add_child(button_row)
	# 导出按钮；选择目标路径后由服务生成单文件归档。
	var export_button: Button = Button.new()
	export_button.text = "导出存档"
	export_button.custom_minimum_size.y = button_minimum_height
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(_on_export_button_pressed)
	button_row.add_child(export_button)
	_export_button = export_button
	# 导入按钮；选择归档后完成校验、备份和覆盖，成功时自动重启。
	var import_button: Button = Button.new()
	import_button.text = "导入存档"
	import_button.custom_minimum_size.y = button_minimum_height
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.pressed.connect(_on_import_button_pressed)
	button_row.add_child(import_button)
	_import_button = import_button
	# 状态标签；自动换行并居中显示，不拦截鼠标输入。
	var status_label: Label = Label.new()
	status_label.visible = false
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)
	_status_label = status_label
	# 导出对话框；ACCESS_FILESYSTEM 允许玩家把归档保存到桌面、移动盘或自选备份目录。
	var export_dialog: FileDialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.use_native_dialog = true
	export_dialog.add_filter("*.lisbamsave", "崩坏：量子骇袭存档")
	export_dialog.file_selected.connect(_on_export_file_selected)
	add_child(export_dialog)
	_export_dialog = export_dialog
	# 导入对话框；只允许选择现有文件，实际格式与内容仍由服务再次校验。
	var import_dialog: FileDialog = FileDialog.new()
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.use_native_dialog = true
	import_dialog.add_filter("*.lisbamsave", "崩坏：量子骇袭存档")
	import_dialog.file_selected.connect(_on_import_file_selected)
	add_child(import_dialog)
	_import_dialog = import_dialog


func _on_export_button_pressed() -> void:
	if _export_dialog == null:
		return
	# 默认文件名；使用本地时间避免连续备份互相覆盖，玩家仍可在系统对话框中修改。
	var time_data: Dictionary = Time.get_datetime_dict_from_system()
	_export_dialog.current_file = "HQI_save_%04d%02d%02d_%02d%02d%02d.lisbamsave" % [int(time_data.year), int(time_data.month), int(time_data.day), int(time_data.hour), int(time_data.minute), int(time_data.second)]
	_export_dialog.popup_centered_ratio(0.72)


func _on_import_button_pressed() -> void:
	if _import_dialog != null:
		_import_dialog.popup_centered_ratio(0.72)


func _on_export_file_selected(path: String) -> void:
	# 存档归档服务；缺失时显示明确错误，使控件仍可在独立 UI 场景中安全运行。
	var archive_service: Node = get_tree().root.get_node_or_null("SaveArchiveService")
	if archive_service == null or not archive_service.has_method("export_archive"):
		_show_status("存档服务不可用。", true)
		return
	# 导出结果；服务返回统一字典，UI 不解释文件系统错误码。
	var result: Dictionary = archive_service.call("export_archive", path) as Dictionary
	_show_status(str(result.get("message", "导出失败。")), not bool(result.get("success", false)))


func _on_import_file_selected(path: String) -> void:
	# 存档归档服务；导入成功后由同一服务重启游戏，使所有数据所有者重新读取文件。
	var archive_service: Node = get_tree().root.get_node_or_null("SaveArchiveService")
	if archive_service == null or not archive_service.has_method("import_archive"):
		_show_status("存档服务不可用。", true)
		return
	# 导入结果；失败时保留当前运行状态，成功时先显示提示再延迟到下一帧重启。
	var result: Dictionary = archive_service.call("import_archive", path) as Dictionary
	var succeeded: bool = bool(result.get("success", false))
	_show_status(str(result.get("message", "导入失败。")), not succeeded)
	if succeeded and archive_service.has_method("restart_game"):
		archive_service.call_deferred("restart_game")


func _show_status(message: String, is_error: bool) -> void:
	## 显示一次操作结果；错误使用浅红色，成功使用浅绿色，颜色只表达语义不影响业务状态。
	if _status_label == null:
		return
	_status_label.text = message
	_status_label.modulate = Color(1.0, 0.58, 0.58, 1.0) if is_error else Color(0.62, 1.0, 0.72, 1.0)
	_status_label.visible = true
	_status_time_remaining = maxf(status_visible_duration, 0.0)
