extends Node

## 输入绑定管理器统一维护可自定义操作、默认绑定、保存和恢复。
## 节点作为 AutoLoad 存在，主菜单设置和暂停设置都通过它修改 InputMap，玩家控制组件只读取 InputMap。
## 脚本不声明 class_name，避免全局类名与 project.godot 中的 InputBindings AutoLoad 单例重名。

signal bindings_changed

## 绑定配置保存路径；默认写入 user://，运行时修改会影响玩家自定义按键持久化位置。
const SAVE_PATH: String = "user://input_bindings.cfg"
## 键盘事件类型标识；默认用于序列化 InputEventKey。
const EVENT_TYPE_KEY: String = "key"
## 鼠标按钮事件类型标识；默认用于序列化 InputEventMouseButton。
const EVENT_TYPE_MOUSE_BUTTON: String = "mouse_button"
## 未绑定事件类型标识；默认用于保存被冲突处理清空的操作，避免下次启动恢复旧默认键。
const EVENT_TYPE_UNBOUND: String = "unbound"

## 可配置动作列表；每项包含 action 和 label，默认覆盖玩家战斗、界面和拾取相关操作。
var _action_entries: Array[Dictionary] = [
	{"action": "move_left", "label": "左移"},
	{"action": "move_right", "label": "右移"},
	{"action": "move_up", "label": "上移"},
	{"action": "move_down", "label": "下移"},
	{"action": "attack_fire", "label": "远程攻击"},
	{"action": "attack_melee", "label": "近战攻击"},
	{"action": "active_skill_1", "label": "技能一"},
	{"action": "active_skill_2", "label": "技能二"},
	{"action": "active_skill_3", "label": "技能三"},
	{"action": "sprint", "label": "疾跑"},
	{"action": "dodge", "label": "闪避"},
	{"action": "switch_ranged_1", "label": "远程槽 1"},
	{"action": "switch_ranged_2", "label": "远程槽 2"},
	{"action": "switch_ranged_previous", "label": "上一把远程"},
	{"action": "switch_ranged_next", "label": "下一把远程"},
	{"action": "toggle_inventory", "label": "背包"},
	{"action": "toggle_large_map", "label": "大地图"},
	{"action": "pause_game", "label": "暂停菜单"},
	{"action": "pickup_nearby", "label": "快速拾取"},
	{"action": "toggle_drop_list", "label": "掉落列表"},
]
## 默认输入事件缓存；键为动作名，值为 InputEvent 数组，用于恢复默认绑定。
var _default_events_by_action: Dictionary = {}
## 显式未绑定动作缓存；键为动作名字符串，值为 true，用于阻止空 InputMap 动作继续走物理默认键兜底。
var _explicitly_unbound_actions: Dictionary = {}


func _ready() -> void:
	_capture_default_events()
	_load_saved_bindings()


func get_action_entries() -> Array[Dictionary]:
	return _action_entries.duplicate(true)


func is_configurable_action(action_name: StringName) -> bool:
	# 动作条目遍历项；取值为配置字典，默认用于判断外部传入动作是否允许改键。
	for action_entry in _action_entries:
		if str(action_entry.get("action", "")) == str(action_name):
			return true

	return false


func get_action_display_text(action_name: StringName) -> String:
	if not InputMap.has_action(action_name):
		return "未绑定"

	# 动作事件列表；元素为 InputEvent，默认只显示第一个事件，当前 UI 每个操作维护一个主绑定。
	var events: Array = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "未绑定"

	return get_event_display_text(events[0] as InputEvent)


func is_action_explicitly_unbound(action_name: StringName) -> bool:
	return bool(_explicitly_unbound_actions.get(str(action_name), false))


func is_action_using_default(action_name: StringName) -> bool:
	# 显式未绑定一定不是默认状态，即使项目默认事件数组为空也显示恢复按钮。
	if is_action_explicitly_unbound(action_name):
		return false
	# 默认事件数组；动作未进入启动缓存时视为非默认，避免错误隐藏按钮。
	var action_name_string: String = str(action_name)
	if not _default_events_by_action.has(action_name_string):
		return false
	# 当前事件和默认事件；按顺序比较实际键位、修饰键或鼠标按钮，忽略捕获事件携带的冗余运行时字段。
	var current_events: Array = InputMap.action_get_events(action_name) if InputMap.has_action(action_name) else []
	var default_events: Array = _default_events_by_action[action_name_string]
	if current_events.size() != default_events.size():
		return false
	for event_index in range(current_events.size()):
		if not _are_binding_events_equivalent(current_events[event_index] as InputEvent, default_events[event_index] as InputEvent):
			return false
	return true


func _are_binding_events_equivalent(current_event: InputEvent, default_event: InputEvent) -> bool:
	if current_event is InputEventKey and default_event is InputEventKey:
		# 当前键盘事件；玩家现场捕获时可能同时包含 physical_keycode 与 keycode。
		var current_key_event: InputEventKey = current_event as InputEventKey
		# 默认键盘事件；项目 InputMap 通常只保存 physical_keycode，因此不能直接依赖 InputEvent.is_match。
		var default_key_event: InputEventKey = default_event as InputEventKey
		# 当前有效键位；优先比较物理键位，确保键盘布局变化时仍按同一实体按键判定。
		var current_effective_keycode: Key = current_key_event.physical_keycode if current_key_event.physical_keycode != KEY_NONE else current_key_event.keycode
		# 默认有效键位；与当前事件使用同一优先级，避免 Q 重新绑定为 Q 后被误判为自定义键位。
		var default_effective_keycode: Key = default_key_event.physical_keycode if default_key_event.physical_keycode != KEY_NONE else default_key_event.keycode
		return current_effective_keycode == default_effective_keycode \
			and current_key_event.alt_pressed == default_key_event.alt_pressed \
			and current_key_event.shift_pressed == default_key_event.shift_pressed \
			and current_key_event.ctrl_pressed == default_key_event.ctrl_pressed \
			and current_key_event.meta_pressed == default_key_event.meta_pressed
	if current_event is InputEventMouseButton and default_event is InputEventMouseButton:
		# 当前鼠标事件；绑定语义只由按钮编号决定，位置、按下状态和滚轮运行时数据不参与默认判定。
		var current_mouse_event: InputEventMouseButton = current_event as InputEventMouseButton
		# 默认鼠标事件；与当前事件比较相同按钮编号即可确认是否恢复原键位。
		var default_mouse_event: InputEventMouseButton = default_event as InputEventMouseButton
		return current_mouse_event.button_index == default_mouse_event.button_index
	return false


func get_event_display_text(event: InputEvent) -> String:
	if event is InputEventKey:
		# 键盘事件；取值为 InputEventKey，默认优先使用物理键码显示，保证键盘布局变化时绑定稳定。
		var key_event: InputEventKey = event as InputEventKey
		# 显示键码；取值为 physical_keycode 或 keycode，用于转换成 Godot 内置按键名。
		var display_keycode: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		return OS.get_keycode_string(display_keycode)

	if event is InputEventMouseButton:
		# 鼠标事件；取值为 InputEventMouseButton，默认转换成中文按钮名。
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		return _get_mouse_button_text(mouse_event.button_index)

	return "未知"


func rebind_action(action_name: StringName, event: InputEvent) -> bool:
	if not is_configurable_action(action_name) or event == null:
		return false

	# 标准化输入事件；取值为可保存的键盘或鼠标按钮事件，默认去除按下状态和运行时坐标。
	var normalized_event: InputEvent = _duplicate_supported_event(event)
	if normalized_event == null:
		return false

	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, normalized_event)
	_set_action_explicitly_unbound(action_name, false)
	_save_bindings()
	bindings_changed.emit()
	return true


func reset_to_defaults() -> void:
	_explicitly_unbound_actions.clear()
	# 默认绑定动作名遍历项；取值为 _default_events_by_action 的键，默认逐项恢复项目启动时的 InputMap。
	for raw_action_name in _default_events_by_action.keys():
		# 动作名；取值为 StringName，默认用于访问 InputMap。
		var action_name: StringName = StringName(str(raw_action_name))
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		InputMap.action_erase_events(action_name)
		# 默认事件数组；元素为 InputEvent，默认逐项复制回 InputMap，避免共享运行时对象。
		var default_events: Array = _default_events_by_action[raw_action_name]
		for default_event in default_events:
			if default_event is InputEvent:
				InputMap.action_add_event(action_name, (default_event as InputEvent).duplicate())

	_save_bindings()
	bindings_changed.emit()


func reset_action_to_default(action_name: StringName) -> bool:
	if not is_configurable_action(action_name):
		return false

	# 动作名字符串；用于从启动时缓存的默认绑定表读取指定操作，避免单项恢复影响其他自定义按键。
	var action_name_string: String = str(action_name)
	if not _default_events_by_action.has(action_name_string):
		return false
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)
	# 指定动作默认事件；元素为 InputEvent，逐项复制回 InputMap，避免运行时事件对象共享状态。
	var default_events: Array = _default_events_by_action[action_name_string]
	# 默认事件遍历项；取值为 InputEvent，复制后恢复到当前指定动作。
	for default_event in default_events:
		if default_event is InputEvent:
			InputMap.action_add_event(action_name, (default_event as InputEvent).duplicate())

	_set_action_explicitly_unbound(action_name, false)
	_save_bindings()
	bindings_changed.emit()
	return true


func _capture_default_events() -> void:
	_default_events_by_action.clear()
	# 可配置动作遍历项；取值为 action_entries 字典，默认记录项目输入映射中的初始事件。
	for action_entry in _action_entries:
		# 动作名；取值来自配置字典，默认对应 project.godot 的 InputMap action。
		var action_name: StringName = StringName(str(action_entry.get("action", "")))
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		# 默认事件副本数组；元素为 InputEvent，默认用于后续恢复默认按键。
		var copied_events: Array[InputEvent] = []
		# 原始事件遍历项；取值来自 InputMap，默认复制后保存，避免被运行时修改污染。
		for input_event in InputMap.action_get_events(action_name):
			if input_event is InputEvent:
				copied_events.append((input_event as InputEvent).duplicate())

		_default_events_by_action[str(action_name)] = copied_events


func _load_saved_bindings() -> void:
	# 配置文件；默认从 user:// 读取玩家按键设置，缺失时保持项目默认绑定。
	var config_file: ConfigFile = ConfigFile.new()
	# 加载结果；取值为 Error，默认 OK 表示存在可用配置。
	var load_result: Error = config_file.load(SAVE_PATH)
	if load_result != OK:
		return

	# 可配置动作遍历项；取值为 action_entries 字典，默认逐项尝试读取保存的绑定。
	for action_entry in _action_entries:
		# 动作名字符串；取值来自配置字典，默认作为配置键。
		var action_name_string: String = str(action_entry.get("action", ""))
		if not config_file.has_section_key("bindings", action_name_string):
			continue

		# 序列化事件字典；取值来自配置文件，默认还原成 InputEvent。
		var serialized_event: Dictionary = config_file.get_value("bindings", action_name_string, {})
		# 动作名；取值为 StringName，默认用于写回 InputMap。
		var action_name: StringName = StringName(action_name_string)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		if _is_serialized_unbound_event(serialized_event):
			InputMap.action_erase_events(action_name)
			_set_action_explicitly_unbound(action_name, true)
			continue

		# 还原事件；取值为 InputEvent 或 null，默认 null 表示配置不可用。
		var restored_event: InputEvent = _deserialize_event(serialized_event)
		if restored_event == null:
			continue

		InputMap.action_erase_events(action_name)
		InputMap.action_add_event(action_name, restored_event)
		_set_action_explicitly_unbound(action_name, false)


func _save_bindings() -> void:
	# 配置文件；默认重建后保存所有可配置动作的当前主绑定。
	var config_file: ConfigFile = ConfigFile.new()
	# 可配置动作遍历项；取值为 action_entries 字典，默认逐项写入当前 InputMap 首个事件。
	for action_entry in _action_entries:
		# 动作名字符串；取值来自配置字典，默认作为配置键。
		var action_name_string: String = str(action_entry.get("action", ""))
		# 动作名；取值为 StringName，默认用于读取 InputMap。
		var action_name: StringName = StringName(action_name_string)
		if not InputMap.has_action(action_name):
			continue

		# 当前事件列表；元素为 InputEvent，默认保存第一个主绑定。
		var events: Array = InputMap.action_get_events(action_name)
		if events.is_empty() or not (events[0] is InputEvent):
			_set_action_explicitly_unbound(action_name, true)
			config_file.set_value("bindings", action_name_string, _serialize_unbound_event())
			continue

		_set_action_explicitly_unbound(action_name, false)
		config_file.set_value("bindings", action_name_string, _serialize_event(events[0] as InputEvent))

	config_file.save(SAVE_PATH)


func _duplicate_supported_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		# 原始键盘事件；取值来自玩家按下的新绑定键。
		var source_key_event: InputEventKey = event as InputEventKey
		# 标准键盘事件；默认只保留键位和修饰键，避免 pressed/echo 等运行时状态进入 InputMap。
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = source_key_event.physical_keycode
		key_event.keycode = source_key_event.keycode
		key_event.alt_pressed = source_key_event.alt_pressed and not _is_key_event_modifier(source_key_event, KEY_ALT)
		key_event.shift_pressed = source_key_event.shift_pressed and not _is_key_event_modifier(source_key_event, KEY_SHIFT)
		key_event.ctrl_pressed = source_key_event.ctrl_pressed and not _is_key_event_modifier(source_key_event, KEY_CTRL)
		key_event.meta_pressed = source_key_event.meta_pressed and not _is_key_event_modifier(source_key_event, KEY_META)
		return key_event

	if event is InputEventMouseButton:
		# 原始鼠标事件；取值来自玩家按下的新绑定按钮。
		var source_mouse_event: InputEventMouseButton = event as InputEventMouseButton
		# 标准鼠标事件；默认只保留按钮编号，避免坐标和按下状态进入 InputMap。
		var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_event.button_index = source_mouse_event.button_index
		return mouse_event

	return null


func _is_key_event_modifier(key_event: InputEventKey, modifier_key: Key) -> bool:
	return key_event.physical_keycode == modifier_key or key_event.keycode == modifier_key


func _set_action_explicitly_unbound(action_name: StringName, unbound: bool) -> void:
	# 动作名字符串；取值为 StringName 转换结果，默认作为显式未绑定缓存键。
	var action_name_string: String = str(action_name)
	if unbound:
		_explicitly_unbound_actions[action_name_string] = true
	else:
		_explicitly_unbound_actions.erase(action_name_string)


func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		# 键盘事件；取值为 InputEventKey，默认写成简单字典以稳定跨会话保存。
		var key_event: InputEventKey = event as InputEventKey
		return {
			"type": EVENT_TYPE_KEY,
			"physical_keycode": int(key_event.physical_keycode),
			"keycode": int(key_event.keycode),
			"alt": key_event.alt_pressed,
			"shift": key_event.shift_pressed,
			"ctrl": key_event.ctrl_pressed,
			"meta": key_event.meta_pressed,
		}

	if event is InputEventMouseButton:
		# 鼠标事件；取值为 InputEventMouseButton，默认只保存按钮编号。
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		return {
			"type": EVENT_TYPE_MOUSE_BUTTON,
			"button_index": int(mouse_event.button_index),
		}

	return {}


func _serialize_unbound_event() -> Dictionary:
	return {
		"type": EVENT_TYPE_UNBOUND,
	}


func _is_serialized_unbound_event(serialized_event: Dictionary) -> bool:
	return str(serialized_event.get("type", "")) == EVENT_TYPE_UNBOUND


func _deserialize_event(serialized_event: Dictionary) -> InputEvent:
	# 事件类型；取值为 key 或 mouse_button，默认空字符串表示配置无效。
	var event_type: String = str(serialized_event.get("type", ""))
	if event_type == EVENT_TYPE_KEY:
		# 键盘事件；默认从保存字典恢复 InputEventKey。
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = int(serialized_event.get("physical_keycode", 0))
		key_event.keycode = int(serialized_event.get("keycode", 0))
		key_event.alt_pressed = bool(serialized_event.get("alt", false))
		key_event.shift_pressed = bool(serialized_event.get("shift", false))
		key_event.ctrl_pressed = bool(serialized_event.get("ctrl", false))
		key_event.meta_pressed = bool(serialized_event.get("meta", false))
		return key_event

	if event_type == EVENT_TYPE_MOUSE_BUTTON:
		# 鼠标事件；默认从保存字典恢复 InputEventMouseButton。
		var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_event.button_index = int(serialized_event.get("button_index", 0))
		return mouse_event

	return null


func _get_mouse_button_text(button_index: MouseButton) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return "鼠标左键"
		MOUSE_BUTTON_RIGHT:
			return "鼠标右键"
		MOUSE_BUTTON_MIDDLE:
			return "鼠标中键"
		MOUSE_BUTTON_WHEEL_UP:
			return "滚轮上"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "滚轮下"
		_:
			return "鼠标按钮 %d" % int(button_index)
