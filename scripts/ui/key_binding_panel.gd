extends VBoxContainer
class_name KeyBindingPanel

## 按键绑定面板负责显示可配置操作，并捕获玩家下一次按键或鼠标按钮作为新绑定。
## 面板只修改 InputBindings AutoLoad，不直接读写具体玩家组件，主菜单和暂停设置可以复用同一控件。

signal binding_capture_started
signal binding_capture_finished

## 面板标题；默认“按键绑定”，运行时通常不修改，修改会影响设置界面标题文本。
@export var title_text: String = "按键绑定"
## 列表最小高度；取值建议 180 到 420，默认 260，修改会影响设置界面内按键列表可见行数。
@export_range(120.0, 800.0, 1.0) var list_minimum_height: float = 260.0

## 输入绑定管理器缓存；默认从 AutoLoad InputBindings 获取，缺失时面板会显示为空。
var _input_bindings: Node
## 绑定按钮缓存；键为动作名字符串，值为 Button，用于绑定变化后刷新按钮文本。
var _binding_buttons: Dictionary = {}
## 当前等待绑定的动作名；默认空 StringName 表示未捕获输入。
var _waiting_action: StringName = &""
## 当前等待绑定的按钮；默认 null，仅用于恢复按钮文案和焦点。
var _waiting_button: Button
## 按键行容器缓存；默认运行时创建，用于动态挂载每个操作的绑定行。
var _rows_container: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_input_bindings = get_tree().root.get_node_or_null("InputBindings")
	_build_panel()
	_refresh_binding_buttons()
	if _input_bindings != null and _input_bindings.has_signal("bindings_changed"):
		_input_bindings.connect("bindings_changed", Callable(self, "_on_bindings_changed"))


func _input(event: InputEvent) -> void:
	if _waiting_action == &"":
		return

	if _is_supported_capture_event(event):
		_apply_captured_event(event)
		_mark_input_as_handled()


func is_waiting_for_binding() -> bool:
	return _waiting_action != &""


func _mark_input_as_handled() -> void:
	# 当前视口；取值可能在场景切换期间为空，默认仅在有效时标记输入已处理。
	var current_viewport: Viewport = get_viewport()
	if current_viewport == null:
		return

	current_viewport.set_input_as_handled()


func _build_panel() -> void:
	add_theme_constant_override("separation", 8)

	# 标题标签；取值为动态创建 Label，默认提示当前区域是按键绑定设置。
	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	add_child(title_label)

	# 滚动容器；取值为动态创建 ScrollContainer，默认容纳较多操作行。
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(0.0, list_minimum_height)
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll_container)

	_rows_container = VBoxContainer.new()
	_rows_container.add_theme_constant_override("separation", 6)
	scroll_container.add_child(_rows_container)

	_build_binding_rows()

	# 恢复默认按钮；取值为动态创建 Button，默认把所有操作恢复到项目默认按键。
	var reset_button: Button = Button.new()
	reset_button.text = "恢复默认"
	reset_button.custom_minimum_size = Vector2(0.0, 36.0)
	reset_button.pressed.connect(_on_reset_button_pressed)
	add_child(reset_button)


func _build_binding_rows() -> void:
	if _input_bindings == null or not _input_bindings.has_method("get_action_entries"):
		return

	# 操作条目列表；元素为字典，默认由 InputBindings 提供。
	var action_entries: Array = _input_bindings.call("get_action_entries")
	# 操作条目遍历项；取值为包含 action 和 label 的字典，默认逐项生成一行 UI。
	for raw_action_entry in action_entries:
		if not (raw_action_entry is Dictionary):
			continue

		# 操作条目；取值为 Dictionary，默认解析动作名和中文名。
		var action_entry: Dictionary = raw_action_entry
		# 动作名字符串；取值来自 action_entry，默认对应 InputMap action。
		var action_name_string: String = str(action_entry.get("action", ""))
		# 动作中文名；取值来自 action_entry，默认显示在按钮左侧。
		var action_label_text: String = str(action_entry.get("label", action_name_string))
		if action_name_string.is_empty():
			continue

		# 操作行容器；取值为 HBoxContainer，默认左侧名称右侧绑定按钮。
		var row_container: HBoxContainer = HBoxContainer.new()
		row_container.add_theme_constant_override("separation", 10)
		_rows_container.add_child(row_container)

		# 操作名称标签；取值为 Label，默认显示中文操作名。
		var action_label: Label = Label.new()
		action_label.text = action_label_text
		action_label.custom_minimum_size = Vector2(130.0, 0.0)
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_container.add_child(action_label)

		# 绑定按钮；取值为 Button，默认显示当前绑定并点击进入捕获状态。
		var bind_button: Button = Button.new()
		bind_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bind_button.custom_minimum_size = Vector2(0.0, 34.0)
		bind_button.pressed.connect(Callable(self, "_on_bind_button_pressed").bind(StringName(action_name_string), bind_button))
		row_container.add_child(bind_button)
		_binding_buttons[action_name_string] = bind_button

		# 单项默认按钮；只恢复当前操作的项目默认绑定，不覆盖玩家对其他操作的自定义设置。
		var default_button: Button = Button.new()
		default_button.text = "默认"
		default_button.custom_minimum_size = Vector2(72.0, 34.0)
		default_button.pressed.connect(Callable(self, "_on_action_default_button_pressed").bind(StringName(action_name_string)))
		row_container.add_child(default_button)


func _refresh_binding_buttons() -> void:
	if _input_bindings == null or not _input_bindings.has_method("get_action_display_text"):
		return

	# 绑定按钮动作名遍历项；取值为动作名字符串，默认逐项刷新按钮文案。
	for action_name_string in _binding_buttons.keys():
		# 绑定按钮；取值为 Button，默认从缓存字典读取。
		var bind_button: Button = _binding_buttons[action_name_string] as Button
		if bind_button == null:
			continue

		bind_button.text = str(_input_bindings.call("get_action_display_text", StringName(str(action_name_string))))


func _begin_binding_capture(action_name: StringName, bind_button: Button) -> void:
	_cancel_binding_capture()
	_waiting_action = action_name
	_waiting_button = bind_button
	if _waiting_button != null:
		_waiting_button.text = "按下新按键..."
		_waiting_button.grab_focus()

	binding_capture_started.emit()


func _cancel_binding_capture() -> void:
	if _waiting_action == &"":
		return

	_waiting_action = &""
	_waiting_button = null
	_refresh_binding_buttons()
	binding_capture_finished.emit()


func _is_supported_capture_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		# 键盘事件；取值来自输入系统，默认只捕获非 echo 的按下事件。
		var key_event: InputEventKey = event as InputEventKey
		return key_event.pressed and not key_event.echo

	if event is InputEventMouseButton:
		# 鼠标事件；取值来自输入系统，默认只捕获按下事件。
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		return mouse_event.pressed

	return false


func _apply_captured_event(event: InputEvent) -> void:
	if _input_bindings == null or not _input_bindings.has_method("rebind_action"):
		_cancel_binding_capture()
		return

	_input_bindings.call("rebind_action", _waiting_action, event)
	_waiting_action = &""
	_waiting_button = null
	_refresh_binding_buttons()
	binding_capture_finished.emit()


func _on_bind_button_pressed(action_name: StringName, bind_button: Button) -> void:
	_begin_binding_capture(action_name, bind_button)


func _on_action_default_button_pressed(action_name: StringName) -> void:
	_cancel_binding_capture()
	if _input_bindings != null and _input_bindings.has_method("reset_action_to_default"):
		_input_bindings.call("reset_action_to_default", action_name)


func _on_reset_button_pressed() -> void:
	if _input_bindings != null and _input_bindings.has_method("reset_to_defaults"):
		_input_bindings.call("reset_to_defaults")

	_cancel_binding_capture()


func _on_bindings_changed() -> void:
	_refresh_binding_buttons()
