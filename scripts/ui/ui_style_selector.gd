extends HBoxContainer
class_name UiStyleSelector

## UI 风格选择组件统一提供标签、下拉选项、服务绑定和即时保存行为。
## 主菜单设置与暂停设置只负责挂载本组件，不重复维护风格名称、索引或存档逻辑。

## 风格标签最小宽度；默认 96 像素，可完整显示“UI风格设置”并与主音量标签形成稳定左侧列，运行时无需动态修改。
@export_range(72.0, 180.0, 1.0) var label_minimum_width: float = 96.0
## 风格下拉框最小宽度；默认 220 像素，可完整显示两套中文风格名称，运行时无需动态修改。
@export_range(160.0, 420.0, 1.0) var option_minimum_width: float = 220.0
## 控件横向间距；默认 10 像素，与设置页主音量行保持一致，运行时无需动态修改。
@export_range(0, 32, 1) var control_separation: int = 10

## UI 风格设置服务；默认从 AutoLoad 获取，负责可用选项、当前值、保存和全局刷新。
var _ui_style_settings: Node
## 风格名称标签；默认运行时创建并显示固定文本“UI风格设置”。
var _style_label: Label
## 风格下拉框；默认运行时创建，选项元数据保存稳定风格标识。
var _style_option: OptionButton
## 是否正在从服务同步下拉框；默认 false，同步期间阻止 item_selected 回写造成重复保存。
var _is_synchronizing: bool = false


func _ready() -> void:
	## 创建独立可复用设置行并绑定服务；服务缺失时安全禁用下拉框并显示提示。
	_build_interface()
	_bind_ui_style_settings()


func refresh() -> void:
	## 从服务重新读取可用风格和当前选择；供自动验证或未来设置页复用时主动同步。
	_populate_options()


func _build_interface() -> void:
	## 创建标签与下拉框；重复调用保持幂等，避免场景重新进入时叠加控件。
	if _style_option != null:
		return
	add_theme_constant_override("separation", control_separation)
	# 风格标签；固定最小宽度使设置页各行标题形成稳定左侧列。
	var style_label: Label = Label.new()
	style_label.custom_minimum_size = Vector2(label_minimum_width, 0.0)
	style_label.text = "UI风格设置"
	style_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(style_label)
	_style_label = style_label
	# 风格下拉框；横向扩展占用剩余空间，稳定标识存入每项元数据而不是依赖显示文本。
	var style_option: OptionButton = OptionButton.new()
	style_option.custom_minimum_size = Vector2(option_minimum_width, 38.0)
	style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_option.item_selected.connect(_on_style_option_selected)
	add_child(style_option)
	_style_option = style_option


func _bind_ui_style_settings() -> void:
	## 获取 AutoLoad 服务并监听外部切换；服务缺失时保持组件可见但不可操作，便于定位注册错误。
	_ui_style_settings = get_tree().root.get_node_or_null("UiStyleSettings")
	if _ui_style_settings == null:
		_style_option.disabled = true
		_style_option.add_item("UI 风格服务不可用")
		return
	if _ui_style_settings.has_signal("ui_style_changed") and not _ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		_ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))
	_populate_options()


func _populate_options() -> void:
	## 按服务声明顺序重建下拉项并选中当前风格；显示名变化不会影响保存兼容性。
	if _style_option == null or _ui_style_settings == null:
		return
	_is_synchronizing = true
	_style_option.clear()
	# 当前风格标识；用于在完成选项重建后恢复实际选择。
	var current_style_id: String = str(_ui_style_settings.call("get_ui_style_id"))
	# 当前选中索引；默认 0，服务返回未知标识时自然回退第一项黑蓝科技风。
	var selected_index: int = 0
	# 可用风格标识列表；由服务返回副本，组件只负责展示。
	var available_style_ids: Array = _ui_style_settings.call("get_available_style_ids") as Array
	for style_id_value in available_style_ids:
		# 稳定风格标识；写入选项元数据，后续选择事件不读取中文名称。
		var style_id: String = str(style_id_value)
		# 风格显示名；由服务统一维护，保证主菜单与暂停设置完全一致。
		var display_name: String = str(_ui_style_settings.call("get_style_display_name", style_id))
		_style_option.add_item(display_name)
		# 新增选项索引；用于写入元数据和匹配当前保存值。
		var option_index: int = _style_option.item_count - 1
		_style_option.set_item_metadata(option_index, style_id)
		if style_id == current_style_id:
			selected_index = option_index
	if _style_option.item_count > 0:
		_style_option.select(selected_index)
	_style_option.disabled = _style_option.item_count <= 0
	_is_synchronizing = false


func _on_style_option_selected(option_index: int) -> void:
	## 把玩家选择的稳定风格标识提交给服务；服务负责校验、保存和刷新全部 UI。
	if _is_synchronizing or _ui_style_settings == null:
		return
	if option_index < 0 or option_index >= _style_option.item_count:
		return
	# 选中风格标识；来自组件自己写入的元数据，不接受显示文本作为持久化值。
	var style_id: String = str(_style_option.get_item_metadata(option_index))
	_ui_style_settings.call("set_ui_style_id", style_id)


func _on_ui_style_changed(_style_id: String) -> void:
	## 外部设置组件切换风格后同步当前下拉框，保证同场景多个入口状态一致。
	_populate_options()
