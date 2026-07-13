extends Node2D
class_name PlayerInputComponent

## 玩家输入组件统一读取键盘和鼠标状态。
## 上层角色脚本只向它询问“移动方向、瞄准方向、是否攻击”，不直接依赖具体按键。
## 组件同时支持 InputMap 和物理键兜底，避免输入映射缺失时角色完全不可控。

## 战斗输入开关变化信号；背包、地图、暂停或结算禁用输入时，主动技能组件可立即取消按住状态。
signal combat_input_enabled_changed(enabled: bool)

## 左移输入动作名；默认 move_left 对应 A 键，必须存在于 InputMap 或依赖物理键兜底，修改会影响左移触发来源。
@export var move_left_action: StringName = &"move_left"
## 右移输入动作名；默认 move_right 对应 D 键，必须存在于 InputMap 或依赖物理键兜底，修改会影响右移触发来源。
@export var move_right_action: StringName = &"move_right"
## 上移输入动作名；默认 move_up 对应 W 键，必须存在于 InputMap 或依赖物理键兜底，修改会影响上移触发来源。
@export var move_up_action: StringName = &"move_up"
## 下移输入动作名；默认 move_down 对应 S 键，必须存在于 InputMap 或依赖物理键兜底，修改会影响下移触发来源。
@export var move_down_action: StringName = &"move_down"
## 远程攻击输入动作名；默认 attack_fire 对应鼠标左键，运行时通常不修改，改名会影响射击触发。
@export var fire_action: StringName = &"attack_fire"
## 近战攻击输入动作名；默认 attack_melee 对应鼠标右键，运行时通常不修改，改名会影响近战触发。
@export var melee_action: StringName = &"attack_melee"
## 疾跑输入动作名；默认 sprint 对应 Shift，运行时通常不修改，改名会影响按住疾跑触发。
@export var sprint_action: StringName = &"sprint"
## 冲刺输入动作名；默认保留兼容 ID dodge 并对应 Space，运行时通常不修改，改名会影响单次突进触发与旧按键存档。
@export var dodge_action: StringName = &"dodge"
## 切换到第 1 个远程槽的输入动作名；默认 switch_ranged_1 对应数字键 1，运行时通常不修改，改名会影响快捷切枪。
@export var switch_ranged_1_action: StringName = &"switch_ranged_1"
## 切换到第 2 个远程槽的输入动作名；默认 switch_ranged_2 对应数字键 2，运行时通常不修改，改名会影响快捷切枪。
@export var switch_ranged_2_action: StringName = &"switch_ranged_2"
## 切换到下一把远程武器的输入动作名；默认 switch_ranged_next 对应鼠标滚轮下，运行时通常不修改，改名会影响滚轮切枪。
@export var switch_ranged_next_action: StringName = &"switch_ranged_next"
## 切换到上一把远程武器的输入动作名；默认 switch_ranged_previous 对应鼠标滚轮上，运行时通常不修改，改名会影响滚轮切枪。
@export var switch_ranged_previous_action: StringName = &"switch_ranged_previous"
## 数字键直接切换远程槽的最大数量；取值建议 1 到 9，默认 2 匹配当前双远程槽，扩展槽位时可同步提高。
@export_range(1, 9, 1) var max_direct_ranged_slots: int = 2
## 鼠标瞄准死区半径；取值应大于等于 0，默认 4 像素避免鼠标贴身抖动，修改会影响极近距离瞄准响应。
@export var aim_dead_zone: float = 4.0

## 鼠标左键持续状态；取值为 true/false，默认 false 表示未按下，修改会影响远程攻击是否连续触发。
var _left_mouse_down: bool = false
## 远程攻击按下请求缓存；取值为 true/false，默认 false，记录任意有效绑定的一次按下边沿，保证按下与松开都发生在物理帧之间时仍能执行最低蓄力或普通单发攻击。
var _fire_press_requested: bool = false
## 鼠标右键单次请求缓存；取值为 true/false，默认 false 表示无待处理近战，消费后清空以避免一次点击重复攻击。
var _right_mouse_requested: bool = false
## 近战攻击按下请求缓存；取值为 true/false，默认 false，记录任意有效绑定的一次按下边沿，保证改键后的极短单击不会依赖物理帧轮询。
var _melee_press_requested: bool = false
## 鼠标右键按住状态；取值为 true/false，默认 false，物理回退输入在按下与松开事件中维护，供可蓄力近战武器读取。
var _right_mouse_down: bool = false
## 冲刺单次请求缓存；取值为 true/false，默认 false 表示无待处理冲刺，消费后清空以避免一次按键重复突进。
var _dodge_requested: bool = false
## 远程槽单次切换请求；取值为 -1 或有效槽索引，默认 -1 表示无请求，消费后清空以避免重复切换。
var _ranged_slot_request: int = -1
## 远程武器循环切换请求；取值为负数、0 或正数，默认 0 表示无滚轮切换，消费后清空以避免重复切换。
var _ranged_cycle_request: int = 0
## 战斗输入是否启用；取值为 true/false，默认 true，背包打开时设为 false 以阻止射击、近战和切枪。
var _combat_input_enabled: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not _combat_input_enabled:
		return

	# 远程攻击动作按下边沿；直接按当前 InputMap 绑定识别，鼠标或键盘改键都写入同一单次请求缓存。
	if _is_event_action_pressed(event, fire_action):
		_fire_press_requested = true
	# 近战攻击动作按下边沿；与物理鼠标兜底分开保存，避免有效 InputMap 绑定跳过单击缓存。
	if _is_event_action_pressed(event, melee_action):
		_melee_press_requested = true

	if event is InputEventMouseButton:
		# 当前鼠标按钮事件；取值来自本帧输入事件强转，默认由事件系统提供，修改会影响左右键状态解析。
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and _should_use_physical_fallback(fire_action):
			_left_mouse_down = mouse_event.pressed
			if mouse_event.pressed:
				_fire_press_requested = true
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and _should_use_physical_fallback(melee_action):
			_right_mouse_down = mouse_event.pressed
			if mouse_event.pressed:
				_right_mouse_requested = true
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed and _should_use_physical_fallback(switch_ranged_previous_action):
			_ranged_cycle_request -= 1
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed and _should_use_physical_fallback(switch_ranged_next_action):
			_ranged_cycle_request += 1
	elif event is InputEventKey:
		# 当前键盘事件；取值来自本帧输入事件强转，默认由事件系统提供，修改会影响数字键切枪解析。
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.physical_keycode == KEY_SPACE and _should_use_physical_fallback(dodge_action):
				_dodge_requested = true

			# 数字键对应远程槽索引；取值为 -1 或 0 到 8，默认由物理键位计算，修改会影响快捷槽映射。
			var slot_index: int = _get_ranged_slot_index_from_key(key_event.physical_keycode)
			if _should_use_direct_slot_fallback(slot_index):
				_ranged_slot_request = slot_index


func get_movement_vector() -> Vector2:
	# 水平输入合成值；取值范围通常为 -1 到 1，默认 0 表示无左右输入，修改会影响返回移动方向的 X 分量。
	var horizontal: float = 0.0
	# 垂直输入合成值；取值范围通常为 -1 到 1，默认 0 表示无上下输入，修改会影响返回移动方向的 Y 分量。
	var vertical: float = 0.0

	if _is_action_pressed(move_left_action) or (_should_use_physical_fallback(move_left_action) and Input.is_physical_key_pressed(KEY_A)):
		horizontal -= 1.0
	if _is_action_pressed(move_right_action) or (_should_use_physical_fallback(move_right_action) and Input.is_physical_key_pressed(KEY_D)):
		horizontal += 1.0
	if _is_action_pressed(move_up_action) or (_should_use_physical_fallback(move_up_action) and Input.is_physical_key_pressed(KEY_W)):
		vertical -= 1.0
	if _is_action_pressed(move_down_action) or (_should_use_physical_fallback(move_down_action) and Input.is_physical_key_pressed(KEY_S)):
		vertical += 1.0

	return Vector2(horizontal, vertical).normalized()


func get_aim_direction(from_global_position: Vector2) -> Vector2:
	# 鼠标相对角色的方向向量；取值为任意长度 Vector2，默认由鼠标位置计算，修改会影响瞄准归一化结果。
	var direction: Vector2 = get_global_mouse_position() - from_global_position
	if direction.length() <= aim_dead_zone:
		return Vector2.ZERO

	return direction.normalized()


func is_fire_requested() -> bool:
	if not _combat_input_enabled:
		return false

	return _left_mouse_down or _is_action_pressed(fire_action) or (_should_use_physical_fallback(fire_action) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))


func consume_fire_request() -> bool:
	## 消费一次远程攻击按下请求；按住状态仍由 is_fire_requested 独立提供，调用方可据此区分极短单击与持续输入。
	if not _combat_input_enabled:
		_fire_press_requested = false
		return false

	# 本帧远程攻击请求结果；缓存只表示至少发生过一次有效按下，消费后立即清空以防连续物理帧重复执行同一单击。
	var requested: bool = _fire_press_requested or _is_action_just_pressed(fire_action)
	_fire_press_requested = false
	return requested


func consume_melee_request() -> bool:
	if not _combat_input_enabled:
		_right_mouse_requested = false
		_melee_press_requested = false
		return false

	# 本帧近战请求结果；取值为 true/false，默认由缓存和 InputMap 合成，修改会影响右键点击是否产生一次近战。
	var requested: bool = _right_mouse_requested or _melee_press_requested or _is_action_just_pressed(melee_action)
	_right_mouse_requested = false
	_melee_press_requested = false
	return requested


func is_melee_pressed() -> bool:
	## 返回近战动作当前是否保持按住；用于蓄力武器，普通近战仍通过 consume_melee_request 保持单次点击语义。
	if not _combat_input_enabled:
		return false
	return _right_mouse_down or _is_action_pressed(melee_action) or (_should_use_physical_fallback(melee_action) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))


func is_sprint_pressed() -> bool:
	if not _combat_input_enabled:
		return false

	return _is_action_pressed(sprint_action) or (_should_use_physical_fallback(sprint_action) and (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SHIFT)))


func consume_dodge_request() -> bool:
	if not _combat_input_enabled:
		_dodge_requested = false
		return false

	# 本帧冲刺请求结果；取值为 true/false，默认由缓存和 InputMap 合成，修改会影响 Space 是否产生一次突进。
	var requested: bool = _dodge_requested or _is_action_just_pressed(dodge_action)
	_dodge_requested = false
	return requested


func consume_ranged_slot_request() -> int:
	if not _combat_input_enabled:
		_ranged_slot_request = -1
		return -1

	# 本帧远程槽请求结果；取值为 -1 或有效槽索引，默认由数字键缓存和 InputMap 合成，修改会影响本帧切换目标。
	var requested_slot: int = _ranged_slot_request
	if _is_action_just_pressed(switch_ranged_1_action):
		requested_slot = 0
	elif _is_action_just_pressed(switch_ranged_2_action):
		requested_slot = 1

	_ranged_slot_request = -1
	return requested_slot


func consume_ranged_cycle_request() -> int:
	if not _combat_input_enabled:
		_ranged_cycle_request = 0
		return 0

	# 本帧远程循环请求结果；取值为 -1、0 或 1，默认由滚轮缓存和 InputMap 合成，修改会影响本帧切枪方向。
	var requested_cycle: int = _ranged_cycle_request
	if _is_action_just_pressed(switch_ranged_previous_action):
		requested_cycle -= 1
	if _is_action_just_pressed(switch_ranged_next_action):
		requested_cycle += 1

	_ranged_cycle_request = 0
	if requested_cycle > 0:
		return 1
	if requested_cycle < 0:
		return -1
	return 0


func set_combat_input_enabled(enabled: bool) -> void:
	if _combat_input_enabled == enabled:
		return
	_combat_input_enabled = enabled
	combat_input_enabled_changed.emit(_combat_input_enabled)
	if _combat_input_enabled:
		return

	_left_mouse_down = false
	_fire_press_requested = false
	_right_mouse_requested = false
	_melee_press_requested = false
	_right_mouse_down = false
	_dodge_requested = false
	_ranged_slot_request = -1
	_ranged_cycle_request = 0


func is_combat_input_enabled() -> bool:
	## 返回当前战斗输入开关；主动技能等独立组件通过该只读接口与背包、地图、暂停和结算状态保持一致。
	return _combat_input_enabled


func _is_action_pressed(action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)


func _is_action_just_pressed(action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name)


func _is_event_action_pressed(event: InputEvent, action_name: StringName) -> bool:
	## 判断单个输入事件是否为指定动作的首次按下；过滤空动作、缺失映射与键盘回响，避免按住改键重复生成单击请求。
	if action_name.is_empty() or not InputMap.has_action(action_name):
		return false
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	return event.is_action_pressed(action_name, false)


func _should_use_physical_fallback(action_name: StringName) -> bool:
	if not InputMap.has_action(action_name):
		return true

	if not InputMap.action_get_events(action_name).is_empty():
		return false

	return not _is_action_explicitly_unbound(action_name)


func _is_action_explicitly_unbound(action_name: StringName) -> bool:
	# 输入绑定单例；取值为 AutoLoad InputBindings，默认用于区分玩家主动未绑定和 InputMap 配置缺失。
	var input_bindings: Node = get_tree().root.get_node_or_null("InputBindings")
	if input_bindings == null or not input_bindings.has_method("is_action_explicitly_unbound"):
		return false

	return bool(input_bindings.call("is_action_explicitly_unbound", action_name))


func _should_use_direct_slot_fallback(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= max_direct_ranged_slots:
		return false

	if slot_index == 0:
		return _should_use_physical_fallback(switch_ranged_1_action)
	if slot_index == 1:
		return _should_use_physical_fallback(switch_ranged_2_action)

	return false


func _get_ranged_slot_index_from_key(physical_keycode: Key) -> int:
	match physical_keycode:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
		KEY_7:
			return 6
		KEY_8:
			return 7
		KEY_9:
			return 8
		_:
			return -1
