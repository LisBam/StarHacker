extends HBoxContainer
class_name BannerNotificationToggle

## 横幅通知开关组件统一提供标签、开关按钮、服务绑定和即时保存行为。
## 主菜单设置与暂停设置只负责挂载本组件，不重复维护开关状态或存档逻辑。

## 开关标签最小宽度；默认 96 像素，与主音量和 UI 风格行标签形成稳定左侧列，运行时无需动态修改。
@export_range(72.0, 180.0, 1.0) var label_minimum_width: float = 96.0
## 控件横向间距；默认 10 像素，与设置页其他行保持一致，运行时无需动态修改。
@export_range(0, 32, 1) var control_separation: int = 10

## 横幅通知服务；默认从 AutoLoad 获取，负责开关校验、保存和全局横幅展示。
var _banner_notification_service: Node
## 开关标签；默认运行时创建并显示固定文本“横幅通知”。
var _toggle_label: Label
## 开关按钮；默认运行时创建，选中表示允许屏幕顶端横幅通知。
var _toggle_button: CheckButton
## 是否正在从服务同步开关；默认 false，同步期间阻止 toggled 回写造成重复保存。
var _is_synchronizing: bool = false


func _ready() -> void:
	## 创建独立可复用设置行并绑定服务；服务缺失时安全禁用开关并显示提示。
	_build_interface()
	_bind_banner_notification_service()


func _build_interface() -> void:
	## 创建标签与开关按钮；重复调用保持幂等，避免场景重新进入时叠加控件。
	if _toggle_button != null:
		return
	add_theme_constant_override("separation", control_separation)
	# 开关标签；固定最小宽度使设置页各行标题形成稳定左侧列。
	var toggle_label: Label = Label.new()
	toggle_label.custom_minimum_size = Vector2(label_minimum_width, 0.0)
	toggle_label.text = "横幅通知"
	toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(toggle_label)
	_toggle_label = toggle_label
	# 开关按钮；横向扩展占用剩余空间，文本随开关状态提示当前效果。
	var toggle_button: CheckButton = CheckButton.new()
	toggle_button.text = "屏幕顶端横幅提醒"
	toggle_button.custom_minimum_size = Vector2(0.0, 38.0)
	toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.toggled.connect(_on_toggle_button_toggled)
	add_child(toggle_button)
	_toggle_button = toggle_button


func _bind_banner_notification_service() -> void:
	## 获取 AutoLoad 服务并监听外部切换；服务缺失时保持组件可见但不可操作，便于定位注册错误。
	_banner_notification_service = get_tree().root.get_node_or_null("BannerNotificationService")
	if _banner_notification_service == null:
		_toggle_button.disabled = true
		_toggle_button.text = "横幅通知服务不可用"
		return
	if _banner_notification_service.has_signal("banner_enabled_changed") and not _banner_notification_service.is_connected("banner_enabled_changed", Callable(self, "_on_banner_enabled_changed")):
		_banner_notification_service.connect("banner_enabled_changed", Callable(self, "_on_banner_enabled_changed"))
	_synchronize_from_service()


func _synchronize_from_service() -> void:
	## 从服务读取当前开关状态并同步按钮；同步期间抑制 toggled 回写，防止重复保存。
	if _toggle_button == null or _banner_notification_service == null:
		return
	_is_synchronizing = true
	_toggle_button.set_pressed_no_signal(bool(_banner_notification_service.call("is_banner_enabled")))
	_is_synchronizing = false


func _on_toggle_button_toggled(pressed: bool) -> void:
	## 把玩家的开关选择提交给服务；服务负责校验、保存和中断当前横幅。
	if _is_synchronizing or _banner_notification_service == null:
		return
	_banner_notification_service.call("set_banner_enabled", pressed)


func _on_banner_enabled_changed(_enabled: bool) -> void:
	## 外部设置组件切换开关后同步当前按钮，保证同场景多个入口状态一致。
	_synchronize_from_service()
