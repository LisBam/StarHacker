extends PanelContainer
class_name DeveloperMenu

## 隐藏开发者菜单提供局外测试资源快捷操作，仅由主菜单完成 LISBAM 序列后显示。
## 菜单只调用 GlobalInventory 的公开调试接口，不直接修改存档数组或武器资源。

signal closed

## 菜单最小尺寸；默认 520x420，适合在主菜单中央显示三项开发者操作和结果反馈。
@export var panel_minimum_size: Vector2 = Vector2(520.0, 420.0)
## 单次金币调整数量；默认 1000，对应增加和减少按钮的固定测试步长。
@export_range(1, 9999999, 1) var coin_step: int = 1000

## 全局物品服务；默认从 AutoLoad 获取，缺失时禁用资源修改按钮。
var _global_inventory: Node
## 金币余额标签；默认运行时创建，在金币变化后显示最新局外余额。
var _coins_label: Label
## 操作结果标签；默认显示开发者模式提示，执行功能后反馈发放数量或金币变化。
var _status_label: Label
## 获取全部武器按钮；默认运行时创建，服务不可用时禁用。
var _grant_weapons_button: Button
## 增加金币按钮；默认运行时创建，点击增加 coin_step。
var _add_coins_button: Button
## 减少金币按钮；默认运行时创建，金币最低限制为 0。
var _remove_coins_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = panel_minimum_size
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	if _global_inventory != null and _global_inventory.has_signal("coins_changed"):
		_global_inventory.connect("coins_changed", Callable(self, "_refresh_coins"))
	_refresh_availability()
	_refresh_coins()


func _build_interface() -> void:
	# 外层边距；默认让标题、按钮和状态文本与面板边缘保持稳定距离。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	# 主内容容器；纵向排列标题、余额、三项功能、状态与关闭按钮。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	# 开发者菜单标题；默认居中并使用较大字号与普通设置区分。
	var title_label: Label = Label.new()
	title_label.text = "开发者菜单"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	content.add_child(title_label)
	# 隐藏入口提示；明确该菜单属于调试能力，避免误认为正式经济系统入口。
	var hint_label: Label = Label.new()
	hint_label.text = "隐藏调试功能 · 输入序列 LISBAM 开启"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint_label)
	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_size_override("font_size", 18)
	content.add_child(_coins_label)
	_grant_weapons_button = Button.new()
	_grant_weapons_button.custom_minimum_size = Vector2(0.0, 46.0)
	_grant_weapons_button.text = "一键获取所有武器"
	_grant_weapons_button.pressed.connect(_on_grant_weapons_pressed)
	content.add_child(_grant_weapons_button)
	_add_coins_button = Button.new()
	_add_coins_button.custom_minimum_size = Vector2(0.0, 46.0)
	_add_coins_button.text = "一键增加 %d 金币" % coin_step
	_add_coins_button.pressed.connect(_on_add_coins_pressed)
	content.add_child(_add_coins_button)
	_remove_coins_button = Button.new()
	_remove_coins_button.custom_minimum_size = Vector2(0.0, 46.0)
	_remove_coins_button.text = "一键减少 %d 金币" % coin_step
	_remove_coins_button.pressed.connect(_on_remove_coins_pressed)
	content.add_child(_remove_coins_button)
	_status_label = Label.new()
	_status_label.text = "请选择开发者操作"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)
	# 弹性留白；默认把关闭按钮固定在面板下方。
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	# 关闭按钮；隐藏菜单但不会关闭游戏或修改当前主菜单页面。
	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.text = "关闭"
	close_button.pressed.connect(_on_close_pressed)
	content.add_child(close_button)


func _refresh_availability() -> void:
	# 服务是否可用；取值决定所有会修改局外存档的开发者按钮是否可点击。
	var service_available: bool = _global_inventory != null
	_grant_weapons_button.disabled = not service_available
	_add_coins_button.disabled = not service_available
	_remove_coins_button.disabled = not service_available
	if not service_available:
		_status_label.text = "GlobalInventory 服务不可用"


func _refresh_coins() -> void:
	if _global_inventory == null or not _global_inventory.has_method("get_coins"):
		_coins_label.text = "当前金币：不可用"
		return
	_coins_label.text = "当前金币：%d" % int(_global_inventory.call("get_coins"))


func _on_grant_weapons_pressed() -> void:
	if _global_inventory == null or not _global_inventory.has_method("grant_all_known_weapons_to_warehouse"):
		return
	# 发放武器数量；取值为本次成功加入永久仓库的已知武器种类数。
	var granted_count: int = int(_global_inventory.call("grant_all_known_weapons_to_warehouse"))
	_status_label.text = "已向永久仓库发放 %d 件武器" % granted_count


func _on_add_coins_pressed() -> void:
	_adjust_coins(coin_step)


func _on_remove_coins_pressed() -> void:
	_adjust_coins(-coin_step)


func _adjust_coins(amount: int) -> void:
	if _global_inventory == null or not _global_inventory.has_method("adjust_coins"):
		return
	# 调整后金币；取值至少为 0，用于开发者操作完成后的即时反馈。
	var adjusted_coins: int = int(_global_inventory.call("adjust_coins", amount))
	_status_label.text = "金币已%s %d，当前为 %d" % ["增加" if amount >= 0 else "减少", absi(amount), adjusted_coins]
	_refresh_coins()


func _on_close_pressed() -> void:
	closed.emit()
