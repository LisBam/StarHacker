extends Node
class_name ControlInteractionFeedback

## 通用控件交互反馈组件：挂在任意 Control 子节点下，为鼠标、键盘与手柄操作补充平滑缩放和明暗变化。
## 组件只修改宿主的 scale、self_modulate、pivot_offset 与临时 z_index，不处理业务点击结果，可被按钮、卡片和列表行独立复用。

## 鼠标悬停时的目标缩放；默认 1.01 仅提供轻微抬升感，调整后会影响宿主越过原布局边界的幅度，运行时无需动态修改。
@export_range(1.0, 1.10, 0.001) var hover_scale: float = 1.01
## 鼠标或确认键按下时的目标缩放；默认 0.985 表达向下按压，值越小点击回缩越明显，运行时无需动态修改。
@export_range(0.85, 1.0, 0.001) var pressed_scale: float = 0.985
## 仅通过键盘或手柄聚焦时的目标缩放；默认 1.006，使焦点可辨认但弱于鼠标悬停，运行时无需动态修改。
@export_range(1.0, 1.10, 0.001) var focus_scale: float = 1.006
## 鼠标悬停时乘到宿主原始 self_modulate 的颜色；默认整体提亮 8%，Alpha 保持 1，运行时无需动态修改。
@export var hover_tint: Color = Color(1.08, 1.08, 1.08, 1.0)
## 鼠标或确认键按下时乘到宿主原始 self_modulate 的颜色；默认降至 86% 亮度，运行时无需动态修改。
@export var pressed_tint: Color = Color(0.86, 0.86, 0.86, 1.0)
## 仅通过键盘或手柄聚焦时乘到宿主原始 self_modulate 的颜色；默认整体提亮 5%，运行时无需动态修改。
@export var focus_tint: Color = Color(1.05, 1.05, 1.05, 1.0)
## 悬停、离开和焦点变化的过渡时长；默认 0.10 秒，兼顾跟手性与平滑度，运行时无需动态修改。
@export_range(0.02, 0.30, 0.01) var hover_duration_seconds: float = 0.10
## 按下和释放的过渡时长；默认 0.06 秒，让确认反馈比普通悬停更干脆，运行时无需动态修改。
@export_range(0.02, 0.20, 0.01) var pressed_duration_seconds: float = 0.06
## 交互期间是否临时提高宿主绘制层级；默认启用以避免放大边缘被同级控件覆盖，运行时无需动态修改。
@export var raise_z_index_while_active: bool = true
## 交互期间相对宿主原始层级增加的数值；默认 1 足以越过相邻列表行，修改会影响同级控件遮挡顺序，运行时无需动态修改。
@export_range(0, 32, 1) var active_z_index_offset: int = 1

## 作为动效宿主的父级控件；ready 时自动解析，父节点不是 Control 时组件保持无操作状态。
var _target: Control = null
## 当前缩放与颜色补间；每次状态变化前终止旧补间，防止快速移入移出时多个动画同时写入宿主属性。
var _active_tween: Tween = null
## 鼠标是否位于宿主范围内；决定释放后回到悬停态还是静止态，默认 false。
var _hovered: bool = false
## 鼠标左键或确认操作是否处于按住状态；按下期间优先使用回缩反馈，默认 false。
var _pressed: bool = false
## 宿主是否持有键盘焦点；鼠标离开但焦点仍在时继续保留弱高亮，默认 false。
var _focused: bool = false
## 宿主启用组件前的 self_modulate；所有明暗状态都以该颜色为基础，避免破坏业务预设透明度或颜色。
var _resting_self_modulate: Color = Color.WHITE
## 宿主启用组件前的绘制层级；交互结束后精确恢复，避免持续覆盖页面原有层级关系。
var _resting_z_index: int = 0


func _ready() -> void:
	## 绑定父级控件公开信号；按钮使用 button_down/button_up，普通控件使用 gui_input 识别按压。
	_target = get_parent() as Control
	if _target == null:
		return
	_resting_self_modulate = _target.self_modulate
	_resting_z_index = _target.z_index
	_target.mouse_entered.connect(_on_target_mouse_entered)
	_target.mouse_exited.connect(_on_target_mouse_exited)
	_target.focus_entered.connect(_on_target_focus_entered)
	_target.focus_exited.connect(_on_target_focus_exited)
	_target.visibility_changed.connect(_on_target_visibility_changed)
	_target.resized.connect(_update_target_pivot)
	# 按钮宿主；使用内置信号覆盖鼠标、键盘和手柄的统一按下与释放语义。
	var target_button: BaseButton = _target as BaseButton
	if target_button != null:
		target_button.button_down.connect(_on_target_button_down)
		target_button.button_up.connect(_on_target_button_up)
	else:
		_target.gui_input.connect(_on_target_gui_input)
	_update_target_pivot()


func _exit_tree() -> void:
	## 组件释放前终止仍在运行的补间，避免动态列表清理节点时继续访问即将失效的宿主。
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _on_target_mouse_entered() -> void:
	## 鼠标进入后切换悬停态；若此时仍在按压，则按压态继续拥有更高优先级。
	_hovered = true
	_animate_to_current_state(hover_duration_seconds)


func _on_target_mouse_exited() -> void:
	## 鼠标离开后取消悬停与普通控件的遗留按压状态，防止在控件外释放时永久保持回缩。
	_hovered = false
	if not (_target is BaseButton):
		_pressed = false
	_animate_to_current_state(hover_duration_seconds)


func _on_target_focus_entered() -> void:
	## 键盘或手柄焦点进入后启用弱高亮；鼠标悬停和按压仍覆盖该状态。
	_focused = true
	_animate_to_current_state(hover_duration_seconds)


func _on_target_focus_exited() -> void:
	## 焦点离开时清除确认键按压状态，并根据鼠标是否仍在宿主上决定最终视觉。
	_focused = false
	_pressed = false
	_animate_to_current_state(hover_duration_seconds)


func _on_target_button_down() -> void:
	## Button 宿主按下时立即回缩；禁用按钮不会发出该信号，因此无需额外判断 disabled。
	_pressed = true
	_animate_to_current_state(pressed_duration_seconds)


func _on_target_button_up() -> void:
	## Button 宿主释放时恢复悬停、焦点或静止状态，业务 pressed 信号仍由按钮自身处理。
	_pressed = false
	_animate_to_current_state(pressed_duration_seconds)


func _on_target_gui_input(event: InputEvent) -> void:
	## 普通 Control 宿主从输入事件推导按压状态；只监听左键和 ui_accept，不消费事件或触发业务逻辑。
	if event is InputEventMouseButton:
		# 鼠标按键事件；滚轮与右键不改变点击反馈。
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		_pressed = mouse_event.pressed
		_animate_to_current_state(pressed_duration_seconds)
		return
	if event.is_action_pressed("ui_accept"):
		_pressed = true
		_animate_to_current_state(pressed_duration_seconds)
	elif event.is_action_released("ui_accept"):
		_pressed = false
		_animate_to_current_state(pressed_duration_seconds)


func _on_target_visibility_changed() -> void:
	## 宿主隐藏时立即复位，动态列表或页面切换后再次显示不会残留上一次按压缩放。
	if _target == null or _target.is_visible_in_tree():
		return
	_hovered = false
	_pressed = false
	_focused = false
	_reset_visual_immediately()


func _update_target_pivot() -> void:
	## 始终以宿主中心作为缩放支点；容器重新布局或窗口缩放后同步更新，避免动效向单侧偏移。
	if _target == null:
		return
	_target.pivot_offset = _target.size * 0.5


func _animate_to_current_state(duration_seconds: float) -> void:
	## 根据“按压 > 悬停 > 焦点 > 静止”的优先级计算目标，并从当前值平滑过渡。
	if _target == null or not is_instance_valid(_target):
		return
	_update_target_pivot()
	# 当前状态的目标缩放；默认静止为 1，交互状态按优先级覆盖。
	var target_scale: float = 1.0
	# 当前状态的目标颜色乘数；默认白色表示保留宿主原始颜色。
	var target_tint: Color = Color.WHITE
	if _pressed:
		target_scale = pressed_scale
		target_tint = pressed_tint
	elif _hovered:
		target_scale = hover_scale
		target_tint = hover_tint
	elif _focused:
		target_scale = focus_scale
		target_tint = focus_tint
	_update_target_z_index(_pressed or _hovered or _focused)
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	# 状态补间；并行更新缩放与颜色，使快速连续操作仍从当前视觉自然衔接。
	var state_tween: Tween = _target.create_tween().set_parallel(true)
	state_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	state_tween.tween_property(_target, "scale", Vector2.ONE * target_scale, maxf(duration_seconds, 0.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	state_tween.tween_property(_target, "self_modulate", _resting_self_modulate * target_tint, maxf(duration_seconds, 0.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween = state_tween


func _update_target_z_index(interaction_active: bool) -> void:
	## 只在交互态临时提高绘制层级；关闭配置或返回静止态时恢复组件挂载前的数值。
	if _target == null:
		return
	if raise_z_index_while_active and interaction_active:
		_target.z_index = _resting_z_index + maxi(active_z_index_offset, 0)
	else:
		_target.z_index = _resting_z_index


func _reset_visual_immediately() -> void:
	## 不播放动画地恢复初始视觉；用于页面隐藏和节点生命周期边界，确保下一次展示状态确定。
	if _target == null:
		return
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	_target.scale = Vector2.ONE
	_target.self_modulate = _resting_self_modulate
	_target.z_index = _resting_z_index
	_update_target_pivot()
