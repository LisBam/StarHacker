extends Node

## UI 风格设置服务统一保存当前视觉方案，并在切换后刷新所有已注册界面。
## 服务只维护界面表现状态，不读取玩法、库存、角色或战斗数据。

signal ui_style_changed(style_id: String)

## 全局 UI 样式指南；根据当前设置生成 Theme、面板和背景颜色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 当前项目原有风格标识；默认使用黑蓝科技风，保证旧存档和首次启动保持原视觉。
const STYLE_BLACK_BLUE_TECH: String = "black_blue_tech"
## 黑白替代风格标识；用于纯黑、白灰控件和高对比界面，不改变业务语义颜色。
const STYLE_BLACK_WHITE_MINIMAL: String = "black_white_minimal"
## UI 风格配置文件路径；独立保存以便导出、导入和删除存档时统一处理。
const SAVE_PATH: String = "user://ui_style_settings.cfg"
## UI 风格配置段名称；固定为 interface，后续界面偏好可继续在此段扩展。
const CONFIG_SECTION: String = "interface"
## UI 风格配置键；保存稳定风格标识而不是下拉框索引，避免选项顺序变化破坏存档。
const UI_STYLE_KEY: String = "ui_style"

## 当前 UI 风格标识；默认黑蓝科技风，非法或缺失存档都会回退到该值。
var _ui_style_id: String = STYLE_BLACK_BLUE_TECH
## 已注册主题根节点弱引用；每项指向一个独立 Control 根，用于切换时重建继承主题。
var _theme_root_references: Array[WeakRef] = []
## 已注册完整页面背景弱引用；每项指向 ColorRect，用于切换时更新黑蓝或黑白背景色。
var _screen_background_references: Array[WeakRef] = []
## 已注册窗口遮罩弱引用；每项指向 ColorRect，用于切换时更新聚焦遮罩颜色。
var _overlay_dim_references: Array[WeakRef] = []
## 已注册主窗口面板弱引用；每项指向显式覆盖 panel 样式的 Control，用于双向切换时重建窗口表面。
var _window_panel_references: Array[WeakRef] = []
## 已注册子分区面板弱引用；每项指向显式覆盖 panel 样式的 Control，用于双向切换时重建内部区域。
var _section_panel_references: Array[WeakRef] = []


func _enter_tree() -> void:
	## 在主场景创建任何 UI 前读取设置，保证首次生成的主题就是玩家上次选择的风格。
	_load_settings()


func get_ui_style_id() -> String:
	## 返回当前稳定风格标识；界面下拉框与样式指南都通过本接口读取同一状态。
	return _ui_style_id


func get_available_style_ids() -> Array[String]:
	## 返回按设置界面展示顺序排列的风格标识副本；调用方可安全遍历但不能修改服务内部状态。
	return [STYLE_BLACK_BLUE_TECH, STYLE_BLACK_WHITE_MINIMAL]


func get_style_display_name(style_id: String) -> String:
	## 返回面向玩家的中文风格名称；未知标识显示默认风格名称，避免设置页出现空文本。
	match _normalize_style_id(style_id):
		STYLE_BLACK_WHITE_MINIMAL:
			return "黑白简约风"
		_:
			return "黑蓝科技风"


func is_black_white_style() -> bool:
	## 返回当前是否为黑白简约风；样式指南据此替换通用控件色板，不处理业务语义颜色。
	return _ui_style_id == STYLE_BLACK_WHITE_MINIMAL


func set_ui_style_id(style_id: String) -> void:
	## 校验、保存并立即应用新的 UI 风格；相同值不会重复写盘或广播信号。
	# 标准风格标识；非法值统一回退默认黑蓝科技风，避免配置文件注入不存在的主题。
	var normalized_style_id: String = _normalize_style_id(style_id)
	if _ui_style_id == normalized_style_id:
		return
	_ui_style_id = normalized_style_id
	_save_settings()
	_refresh_registered_ui()
	ui_style_changed.emit(_ui_style_id)


func register_theme_root(target: Control) -> void:
	## 登记拥有独立 Theme 的界面根节点；重复登记保持幂等，切换时立即重建通用控件主题。
	if target == null:
		return
	_append_unique_reference(_theme_root_references, target)


func register_screen_background(target: ColorRect) -> void:
	## 登记完整页面背景；风格切换后只更新页面基础色，不修改节点材质或子控件颜色。
	if target == null:
		return
	_append_unique_reference(_screen_background_references, target)
	target.color = UI_STYLE_GUIDE.get_screen_background_color()


func register_overlay_dim(target: ColorRect) -> void:
	## 登记全屏聚焦遮罩；风格切换后只更新遮罩基础色，不修改节点材质或子控件颜色。
	if target == null:
		return
	_append_unique_reference(_overlay_dim_references, target)
	target.color = UI_STYLE_GUIDE.get_overlay_dim_color()


func register_window_panel(target: Control) -> void:
	## 登记显式主窗口面板；黑蓝与黑白双向切换时会重建其 panel 覆盖样式。
	if target == null:
		return
	_append_unique_reference(_window_panel_references, target)
	target.add_theme_stylebox_override("panel", UI_STYLE_GUIDE.create_window_panel_style())


func register_section_panel(target: Control) -> void:
	## 登记显式子分区面板；黑蓝与黑白双向切换时会重建其 panel 覆盖样式。
	if target == null:
		return
	_append_unique_reference(_section_panel_references, target)
	target.add_theme_stylebox_override("panel", UI_STYLE_GUIDE.create_section_panel_style())


func _load_settings() -> void:
	## 读取 UI 风格配置；文件缺失、损坏或字段非法时保持黑蓝科技风默认值。
	# 配置文件；只读取本服务拥有的固定路径，不解析其他模块设置。
	var config_file: ConfigFile = ConfigFile.new()
	# 加载结果；非 OK 表示首次启动或文件不可读，此时不创建额外文件。
	var load_result: Error = config_file.load(SAVE_PATH)
	if load_result != OK or not config_file.has_section_key(CONFIG_SECTION, UI_STYLE_KEY):
		return
	_ui_style_id = _normalize_style_id(str(config_file.get_value(CONFIG_SECTION, UI_STYLE_KEY, STYLE_BLACK_BLUE_TECH)))


func _save_settings() -> void:
	## 覆写当前 UI 风格配置；文件只包含稳定标识，不保存控件实例或临时界面状态。
	# 配置文件；每次切换重新创建，避免遗留未知字段影响当前结构。
	var config_file: ConfigFile = ConfigFile.new()
	config_file.set_value(CONFIG_SECTION, UI_STYLE_KEY, _ui_style_id)
	# 保存结果；写入失败不会撤销内存中的即时切换，但会输出错误供开发者定位权限或磁盘问题。
	var save_result: Error = config_file.save(SAVE_PATH)
	if save_result != OK:
		push_error("保存 UI 风格设置失败，错误码：%d" % save_result)


func _normalize_style_id(style_id: String) -> String:
	## 把外部输入限制到项目正式支持的两种风格，未知值回退黑蓝科技风。
	if style_id == STYLE_BLACK_WHITE_MINIMAL:
		return STYLE_BLACK_WHITE_MINIMAL
	return STYLE_BLACK_BLUE_TECH


func _refresh_registered_ui() -> void:
	## 刷新所有独立主题、背景、遮罩和面板；主题切换只替换通用 UI 色板，绝不覆盖节点材质。
	_refresh_theme_roots()
	_refresh_registered_panels(_window_panel_references, true)
	_refresh_registered_panels(_section_panel_references, false)
	_refresh_registered_color_rects(_screen_background_references, true)
	_refresh_registered_color_rects(_overlay_dim_references, false)


func _refresh_theme_roots() -> void:
	## 为全部独立 UI 根重新生成当前风格主题；倒序清理已经释放的弱引用。
	for reference_index in range(_theme_root_references.size() - 1, -1, -1):
		# 当前主题根；可能已经随关闭场景释放，失效引用直接移除。
		var theme_root: Control = _theme_root_references[reference_index].get_ref() as Control
		if theme_root == null:
			_theme_root_references.remove_at(reference_index)
			continue
		theme_root.theme = UI_STYLE_GUIDE.create_theme()
		theme_root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)
		theme_root.queue_redraw()


func _refresh_registered_color_rects(references: Array[WeakRef], use_screen_background: bool) -> void:
	## 更新指定颜色矩形集合；失效节点会被移除，存活节点使用当前风格颜色。
	for reference_index in range(references.size() - 1, -1, -1):
		# 当前颜色矩形；由样式指南登记，可能随场景切换失效。
		var color_rect: ColorRect = references[reference_index].get_ref() as ColorRect
		if color_rect == null:
			references.remove_at(reference_index)
			continue
		color_rect.color = UI_STYLE_GUIDE.get_screen_background_color() if use_screen_background else UI_STYLE_GUIDE.get_overlay_dim_color()
		color_rect.queue_redraw()


func _refresh_registered_panels(references: Array[WeakRef], use_window_style: bool) -> void:
	## 更新显式面板覆盖；失效节点会被移除，存活节点按当前风格重新创建独立 StyleBoxFlat。
	for reference_index in range(references.size() - 1, -1, -1):
		# 当前面板控件；可能已经随关闭场景释放，失效引用直接移除。
		var panel_control: Control = references[reference_index].get_ref() as Control
		if panel_control == null:
			references.remove_at(reference_index)
			continue
		panel_control.add_theme_stylebox_override("panel", UI_STYLE_GUIDE.create_window_panel_style() if use_window_style else UI_STYLE_GUIDE.create_section_panel_style())
		panel_control.queue_redraw()


func _append_unique_reference(references: Array[WeakRef], target: Control) -> void:
	## 把控件以弱引用形式幂等加入集合；同时清理已经释放的旧记录。
	for reference_index in range(references.size() - 1, -1, -1):
		# 已登记控件；实例相同则无需追加，失效引用直接移除。
		var registered_target: Control = references[reference_index].get_ref() as Control
		if registered_target == null:
			references.remove_at(reference_index)
			continue
		if registered_target == target:
			return
	references.append(weakref(target))
