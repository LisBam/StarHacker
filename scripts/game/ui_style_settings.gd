extends Node

## UI 风格设置服务统一保存当前视觉方案，并在切换后刷新所有已注册界面。
## 服务只维护界面表现状态，不读取玩法、库存、角色或战斗数据。

signal ui_style_changed(style_id: String)

## 全局 UI 样式指南；根据当前设置生成 Theme、面板和背景颜色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 当前项目原有风格标识；默认使用黑蓝科技风，保证旧存档和首次启动保持原视觉。
const STYLE_BLACK_BLUE_TECH: String = "black_blue_tech"
## 黑白替代风格标识；用于纯黑、灰阶与白色高对比界面。
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
## 黑白风格灰度材质；默认延迟创建并由全部 UI CanvasItem 共享，避免为每个控件编译重复着色器。
var _monochrome_material: ShaderMaterial
## 被灰度材质临时覆盖的控件记录；键为实例 ID，值保存弱引用与原材质，切回黑蓝风格时原样恢复。
var _original_material_records: Dictionary = {}


func _enter_tree() -> void:
	## 在主场景创建任何 UI 前读取设置，保证首次生成的主题就是玩家上次选择的风格。
	_load_settings()


func _ready() -> void:
	## 监听后续动态加入场景树的控件，使黑白风格同样覆盖运行时创建的面板、卡片和弹窗内容。
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	if not get_tree().node_removed.is_connected(_on_tree_node_removed):
		get_tree().node_removed.connect(_on_tree_node_removed)


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
	## 返回当前是否为纯灰阶风格；样式指南和动态控件覆盖使用该结果统一判断。
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
	## 登记拥有独立 Theme 的界面根节点；重复登记保持幂等，并立即同步当前灰度覆盖状态。
	if target == null:
		return
	_append_unique_reference(_theme_root_references, target)
	_refresh_monochrome_subtree(target)


func register_screen_background(target: ColorRect) -> void:
	## 登记完整页面背景；风格切换后会更新颜色并同步灰度材质。
	if target == null:
		return
	_append_unique_reference(_screen_background_references, target)
	target.color = UI_STYLE_GUIDE.get_screen_background_color()
	_refresh_monochrome_control(target)


func register_overlay_dim(target: ColorRect) -> void:
	## 登记全屏聚焦遮罩；风格切换后会更新颜色并同步灰度材质。
	if target == null:
		return
	_append_unique_reference(_overlay_dim_references, target)
	target.color = UI_STYLE_GUIDE.get_overlay_dim_color()
	_refresh_monochrome_control(target)


func register_window_panel(target: Control) -> void:
	## 登记显式主窗口面板；黑蓝与黑白双向切换时会重建其 panel 覆盖样式。
	if target == null:
		return
	_append_unique_reference(_window_panel_references, target)
	target.add_theme_stylebox_override("panel", UI_STYLE_GUIDE.create_window_panel_style())
	_refresh_monochrome_subtree(target)


func register_section_panel(target: Control) -> void:
	## 登记显式子分区面板；黑蓝与黑白双向切换时会重建其 panel 覆盖样式。
	if target == null:
		return
	_append_unique_reference(_section_panel_references, target)
	target.add_theme_stylebox_override("panel", UI_STYLE_GUIDE.create_section_panel_style())
	_refresh_monochrome_subtree(target)


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
	## 刷新所有独立主题、背景和遮罩，并应用或恢复黑白风格灰度材质。
	_refresh_theme_roots()
	_refresh_registered_panels(_window_panel_references, true)
	_refresh_registered_panels(_section_panel_references, false)
	_refresh_registered_color_rects(_screen_background_references, true)
	_refresh_registered_color_rects(_overlay_dim_references, false)
	if is_black_white_style():
		for root_reference in _theme_root_references:
			# 主题根节点；失效引用会在主题刷新阶段被清理，此处只处理仍存活的 Control。
			var theme_root: Control = root_reference.get_ref() as Control
			if theme_root != null:
				_apply_monochrome_to_subtree(theme_root)
	else:
		_restore_original_materials()


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


func _on_tree_node_added(node: Node) -> void:
	## 黑白风格启用期间覆盖新加入任一已注册 UI 子树的控件，保证动态卡片和弹窗保持灰阶。
	if not is_black_white_style() or not (node is Control):
		return
	# 新控件；只有位于已登记 UI 根之下时才应用灰度，战斗世界和非界面节点不受影响。
	var added_control: Control = node as Control
	if _is_inside_registered_ui(added_control):
		_apply_monochrome_to_subtree(added_control)


func _on_tree_node_removed(node: Node) -> void:
	## 动态 UI 节点离开场景树时延迟检查材质记录；同树重挂载保留原材质，真正释放才清理。
	if not (node is Control):
		return
	# 被移除控件实例 ID；延迟到当前树变更结束后区分重挂载与永久释放。
	var instance_id: int = node.get_instance_id()
	call_deferred("_cleanup_removed_material_record", instance_id)


func _cleanup_removed_material_record(instance_id: int) -> void:
	## 清理已经永久释放或等待释放的材质记录；仍存活的重挂载控件必须保留首次记录的原材质。
	if not _original_material_records.has(instance_id):
		return
	# 材质记录；只由灰度覆盖入口创建，包含控件弱引用与切换前原材质。
	var material_record: Dictionary = _original_material_records.get(instance_id, {}) as Dictionary
	# 控件弱引用；节点已释放时为空，重挂载或暂存节点仍可解析。
	var target_reference: WeakRef = material_record.get("reference") as WeakRef
	# 目标控件；排队释放视为永久离开，普通 remove_child 或 reparent 继续保留记录。
	var target: Control = target_reference.get_ref() as Control if target_reference != null else null
	if target != null and not target.is_queued_for_deletion():
		return
	_original_material_records.erase(instance_id)


func _is_inside_registered_ui(target: Control) -> bool:
	## 返回目标是否等于或从属于任一已注册主题根；失效根节点在检查时同步清理。
	for reference_index in range(_theme_root_references.size() - 1, -1, -1):
		# 候选主题根；用于限制灰度材质只影响 UI，不覆盖战斗场景与角色画面。
		var theme_root: Control = _theme_root_references[reference_index].get_ref() as Control
		if theme_root == null:
			_theme_root_references.remove_at(reference_index)
			continue
		if target == theme_root or theme_root.is_ancestor_of(target):
			return true
	return false


func _refresh_monochrome_subtree(root_control: Control) -> void:
	## 根据当前风格对新登记子树应用灰度或恢复原材质；登记阶段不会等待下一次设置切换。
	if is_black_white_style():
		_apply_monochrome_to_subtree(root_control)
	else:
		_restore_materials_in_subtree(root_control)


func _refresh_monochrome_control(target: Control) -> void:
	## 根据当前风格处理单个颜色控件；用于背景和遮罩在登记时立即同步。
	if is_black_white_style():
		_apply_monochrome_material(target)
	else:
		_restore_original_material(target)


func _apply_monochrome_to_subtree(root_control: Control) -> void:
	## 为当前 UI 子树内全部 Control 安装灰度材质；每个控件单独处理可覆盖自绘颜色和业务局部覆盖。
	_apply_monochrome_material(root_control)
	for child_node in root_control.get_children():
		if child_node is Control:
			_apply_monochrome_to_subtree(child_node as Control)
		else:
			_apply_monochrome_to_control_descendants(child_node)


func _apply_monochrome_to_control_descendants(parent_node: Node) -> void:
	## 穿过非 Control 中间节点继续查找界面控件，兼容 CanvasLayer、Window 和普通组织节点。
	for child_node in parent_node.get_children():
		if child_node is Control:
			_apply_monochrome_to_subtree(child_node as Control)
		else:
			_apply_monochrome_to_control_descendants(child_node)


func _apply_monochrome_material(target: Control) -> void:
	## 保存控件原材质并安装共享灰度材质；同一实例只记录一次，避免覆盖原始恢复信息。
	# 控件实例 ID；作为材质恢复记录的稳定运行时键，节点释放后不会用于新实例。
	var instance_id: int = target.get_instance_id()
	if not _original_material_records.has(instance_id):
		_original_material_records[instance_id] = {"reference": weakref(target), "material": target.material}
	target.material = _get_monochrome_material()
	target.queue_redraw()


func _get_monochrome_material() -> ShaderMaterial:
	## 延迟创建并返回共享灰度 CanvasItem 材质；着色器保留原透明度，只把 RGB 转为视觉亮度。
	if _monochrome_material != null:
		return _monochrome_material
	# 灰度着色器；同时处理纹理、文字、StyleBox 和自绘图元，保证分散的业务颜色也进入黑白风格。
	var monochrome_shader: Shader = Shader.new()
	monochrome_shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 sampled_ui_color = texture(TEXTURE, UV) * COLOR;\n\tfloat luminance = dot(sampled_ui_color.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(vec3(luminance), sampled_ui_color.a);\n}"
	_monochrome_material = ShaderMaterial.new()
	_monochrome_material.shader = monochrome_shader
	return _monochrome_material


func _restore_original_materials() -> void:
	## 恢复全部仍存活控件的原材质并清空记录；已释放节点的弱引用会安全跳过。
	for instance_id in _original_material_records.keys():
		# 材质记录；只由本服务创建，包含控件弱引用与切换前原材质。
		var material_record: Dictionary = _original_material_records.get(instance_id, {}) as Dictionary
		# 目标控件；节点可能已经关闭释放，失效时无需恢复。
		var target: Control = (material_record.get("reference") as WeakRef).get_ref() as Control if material_record.get("reference") is WeakRef else null
		if target != null:
			target.material = material_record.get("material") as Material
			target.queue_redraw()
	_original_material_records.clear()


func _restore_materials_in_subtree(root_control: Control) -> void:
	## 恢复指定子树内已经被本服务覆盖的材质；通常用于黑蓝风格下登记复用界面。
	_restore_original_material(root_control)
	for child_node in root_control.get_children():
		if child_node is Control:
			_restore_materials_in_subtree(child_node as Control)
		else:
			_restore_materials_in_control_descendants(child_node)


func _restore_materials_in_control_descendants(parent_node: Node) -> void:
	## 穿过非 Control 中间节点恢复后代控件，保持与灰度应用遍历规则完全一致。
	for child_node in parent_node.get_children():
		if child_node is Control:
			_restore_materials_in_subtree(child_node as Control)
		else:
			_restore_materials_in_control_descendants(child_node)


func _restore_original_material(target: Control) -> void:
	## 恢复单个控件在启用黑白风格前的材质；没有记录时保持调用方现状。
	# 控件实例 ID；用于查找当前运行期内的原材质记录。
	var instance_id: int = target.get_instance_id()
	if not _original_material_records.has(instance_id):
		return
	# 材质记录；恢复完成后立即移除，防止后续实例 ID 复用读取旧状态。
	var material_record: Dictionary = _original_material_records.get(instance_id, {}) as Dictionary
	target.material = material_record.get("material") as Material
	target.queue_redraw()
	_original_material_records.erase(instance_id)
