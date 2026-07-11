extends PanelContainer
class_name DeveloperMenu

## 隐藏开发者菜单根据所在场景显示局外资源操作或局内战斗调试操作。
## 主菜单模式只调用 GlobalInventory；战斗模式通过信号把无限属性和训练工具请求交给 CombatHud。

signal closed
signal infinite_health_toggled(enabled: bool)
signal infinite_energy_toggled(enabled: bool)
signal weapon_durability_consumption_toggled(disabled: bool)
signal training_settings_requested
signal map_vision_requested

## 菜单最小尺寸；默认 520x580，适合在主菜单中央显示资源操作和调试信息开关。
@export var panel_minimum_size: Vector2 = Vector2(520.0, 640.0)
## 战斗调试上下文面板高度；默认 580 像素，用于容纳无限属性、地图视野和训练设置入口，运行时通常不动态修改。
@export_range(360.0, 720.0, 1.0) var combat_panel_height: float = 580.0
## 单次金币调整数量；默认 1000，对应增加和减少按钮的固定测试步长。
@export_range(1, 9999999, 1) var coin_step: int = 1000
## 单次随机强化石发放数量；默认 10，修改会同步按钮文案和实际永久仓库发放数量。
@export_range(1, 999, 1) var enhancement_stone_grant_count: int = 10

## 全局物品服务；默认从 AutoLoad 获取，缺失时禁用资源修改按钮。
var _global_inventory: Node
## 金币余额标签；默认运行时创建，在金币变化后显示最新局外余额。
var _coins_label: Label
## 操作结果标签；默认显示开发者模式提示，执行功能后反馈发放数量或金币变化。
var _status_label: Label
## 获取全部武器按钮；默认运行时创建，服务不可用时禁用。
var _grant_weapons_button: Button
## 获取全部装备按钮；点击后向永久仓库发放所有已知四部位装备。
var _grant_equipment_button: Button
## 随机强化石按钮；默认运行时创建，点击后向永久仓库发放 10 颗随机强化石。
var _grant_stones_button: Button
## 获取全部道具按钮；默认运行时创建，点击后向永久仓库各发放一件已知修复包。
var _grant_all_items_button: Button
## 增加金币按钮；默认运行时创建，点击增加 coin_step。
var _add_coins_button: Button
## 减少金币按钮；默认运行时创建，金币最低限制为 0。
var _remove_coins_button: Button
## 清空仓库按钮；默认运行时创建，点击后先弹出确认框再移除永久仓库中的全部物品。
var _clear_warehouse_button: Button
## 隐藏入口提示标签；默认显示 LISBAM 说明，战斗模式会改为局内调试提示。
var _hint_label: Label
## 调试信息显示开关；默认关闭，开启后允许商店等界面显示原价倍率等开发计算信息。
var _debug_information_check_button: CheckButton
## 局外经济控件列表；元素为金币标签、武器、强化石和两个金币按钮，战斗模式中统一隐藏。
var _economy_controls: Array[Control] = []
## 战斗调试控件容器；默认隐藏，配置战斗上下文后显示无限属性与训练工具入口。
var _combat_controls_container: VBoxContainer
## 无限血量开关；默认关闭，战斗模式中切换后向 CombatHud 发送状态。
var _infinite_health_check_button: CheckButton
## 无限能量开关；默认关闭，战斗模式中切换后向 CombatHud 发送状态。
var _infinite_energy_check_button: CheckButton
## 不消耗武器耐久开关；默认关闭，战斗模式中切换后请求 PlayerController 跳过耐久扣除。
var _disable_weapon_durability_check_button: CheckButton
## 获取地图视野按钮；默认只在战斗开发者上下文显示，点击后请求 GameWorld 把整张地图标记为已探索。
var _map_vision_button: Button
## 训练场设置按钮；默认只在战斗模式显示，请求 CombatHud 打开现有训练工具面板。
var _training_settings_button: Button
## 当前是否为战斗开发者上下文；默认 false 表示主菜单局外资源模式。
var _combat_context_enabled: bool = false
## 待同步无限血量状态；默认 false，允许在控件 ready 前先配置战斗状态。
var _configured_infinite_health: bool = false
## 待同步无限能量状态；默认 false，允许在控件 ready 前先配置战斗状态。
var _configured_infinite_energy: bool = false
## 待同步不消耗武器耐久状态；默认 false，允许在控件 ready 前先配置战斗调试状态。
var _configured_weapon_durability_disabled: bool = false
## 清空仓库确认框；默认运行时创建，防止开发者调试时误触不可逆的永久仓库清理。
var _clear_warehouse_confirmation: ConfirmationDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = panel_minimum_size
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	if _global_inventory != null and _global_inventory.has_signal("coins_changed"):
		_global_inventory.connect("coins_changed", Callable(self, "_refresh_coins"))
	_refresh_availability()
	_refresh_coins()
	_refresh_context_visibility()


func configure_combat_context(infinite_health_enabled: bool, infinite_energy_enabled: bool, weapon_durability_disabled: bool = false) -> void:
	_combat_context_enabled = true
	_configured_infinite_health = infinite_health_enabled
	_configured_infinite_energy = infinite_energy_enabled
	_configured_weapon_durability_disabled = weapon_durability_disabled
	_refresh_context_visibility()


func sync_combat_states(infinite_health_enabled: bool, infinite_energy_enabled: bool, weapon_durability_disabled: bool = false) -> void:
	_configured_infinite_health = infinite_health_enabled
	_configured_infinite_energy = infinite_energy_enabled
	_configured_weapon_durability_disabled = weapon_durability_disabled
	if _infinite_health_check_button != null:
		_infinite_health_check_button.set_pressed_no_signal(_configured_infinite_health)
	if _infinite_energy_check_button != null:
		_infinite_energy_check_button.set_pressed_no_signal(_configured_infinite_energy)
	if _disable_weapon_durability_check_button != null:
		_disable_weapon_durability_check_button.set_pressed_no_signal(_configured_weapon_durability_disabled)


func _build_interface() -> void:
	# 滚动容器；窗口高度不足时允许访问底部关闭按钮，避免新增调试项后控件超出屏幕。
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll_container)
	# 外层边距；默认让标题、按钮和状态文本与面板边缘保持稳定距离。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll_container.add_child(margin)
	# 主内容容器；纵向排列标题、余额、武器/强化石/金币功能、状态与关闭按钮。
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
	_hint_label = Label.new()
	_hint_label.text = "隐藏调试功能 · 输入序列 LISBAM 开启"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_hint_label)
	# 调试信息开关；所有业务 UI 通过 DebugSettings 读取统一状态，菜单不直接修改商店节点。
	_debug_information_check_button = CheckButton.new()
	_debug_information_check_button.text = "调试信息显示"
	_debug_information_check_button.custom_minimum_size = Vector2(0.0, 40.0)
	_debug_information_check_button.toggled.connect(_on_debug_information_toggled)
	content.add_child(_debug_information_check_button)
	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_size_override("font_size", 18)
	content.add_child(_coins_label)
	_economy_controls.append(_coins_label)
	_grant_weapons_button = Button.new()
	_grant_weapons_button.custom_minimum_size = Vector2(0.0, 46.0)
	_grant_weapons_button.text = "一键获取所有武器"
	_grant_weapons_button.pressed.connect(_on_grant_weapons_pressed)
	content.add_child(_grant_weapons_button)
	_economy_controls.append(_grant_weapons_button)
	_grant_equipment_button = Button.new()
	_grant_equipment_button.custom_minimum_size = Vector2(0.0, 46.0)
	_grant_equipment_button.text = "一键获取所有装备"
	_grant_equipment_button.pressed.connect(_on_grant_equipment_pressed)
	content.add_child(_grant_equipment_button)
	_economy_controls.append(_grant_equipment_button)
	_grant_stones_button = Button.new()
	_grant_stones_button.custom_minimum_size = Vector2(0.0, 46.0)
	_grant_stones_button.text = "随机获得%d颗强化石" % enhancement_stone_grant_count
	_grant_stones_button.pressed.connect(_on_grant_stones_pressed)
	content.add_child(_grant_stones_button)
	_economy_controls.append(_grant_stones_button)
	_grant_all_items_button = Button.new()
	_grant_all_items_button.custom_minimum_size = Vector2(0.0, 46.0)
	_grant_all_items_button.text = "一键获取所有道具"
	_grant_all_items_button.pressed.connect(_on_grant_all_items_pressed)
	content.add_child(_grant_all_items_button)
	_economy_controls.append(_grant_all_items_button)
	_add_coins_button = Button.new()
	_add_coins_button.custom_minimum_size = Vector2(0.0, 46.0)
	_add_coins_button.text = "一键增加 %d 金币" % coin_step
	_add_coins_button.pressed.connect(_on_add_coins_pressed)
	content.add_child(_add_coins_button)
	_economy_controls.append(_add_coins_button)
	_remove_coins_button = Button.new()
	_remove_coins_button.custom_minimum_size = Vector2(0.0, 46.0)
	_remove_coins_button.text = "一键减少 %d 金币" % coin_step
	_remove_coins_button.pressed.connect(_on_remove_coins_pressed)
	content.add_child(_remove_coins_button)
	_economy_controls.append(_remove_coins_button)
	_clear_warehouse_button = Button.new()
	_clear_warehouse_button.custom_minimum_size = Vector2(0.0, 46.0)
	_clear_warehouse_button.text = "清空仓库物品"
	_clear_warehouse_button.pressed.connect(_on_clear_warehouse_pressed)
	content.add_child(_clear_warehouse_button)
	_economy_controls.append(_clear_warehouse_button)
	_clear_warehouse_confirmation = ConfirmationDialog.new()
	_clear_warehouse_confirmation.title = "确认清空仓库"
	_clear_warehouse_confirmation.dialog_text = "将永久删除仓库中的全部物品，随身背包和装备不会受影响。"
	_clear_warehouse_confirmation.get_ok_button().text = "确认清空"
	_clear_warehouse_confirmation.get_cancel_button().text = "取消"
	_clear_warehouse_confirmation.confirmed.connect(_on_clear_warehouse_confirmed)
	add_child(_clear_warehouse_confirmation)

	# 战斗调试容器；仅在 CombatHud 配置战斗上下文后显示，不访问具体玩家组件。
	_combat_controls_container = VBoxContainer.new()
	_combat_controls_container.add_theme_constant_override("separation", 10)
	content.add_child(_combat_controls_container)
	# 战斗调试标题；用于区分局外经济操作与局内无敌和训练工具。
	var combat_title_label: Label = Label.new()
	combat_title_label.text = "战斗调试"
	combat_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_title_label.add_theme_font_size_override("font_size", 18)
	_combat_controls_container.add_child(combat_title_label)
	_infinite_health_check_button = CheckButton.new()
	_infinite_health_check_button.text = "无限血量"
	_infinite_health_check_button.custom_minimum_size = Vector2(0.0, 40.0)
	_infinite_health_check_button.toggled.connect(_on_infinite_health_toggled)
	_combat_controls_container.add_child(_infinite_health_check_button)
	_infinite_energy_check_button = CheckButton.new()
	_infinite_energy_check_button.text = "无限能量"
	_infinite_energy_check_button.custom_minimum_size = Vector2(0.0, 40.0)
	_infinite_energy_check_button.toggled.connect(_on_infinite_energy_toggled)
	_combat_controls_container.add_child(_infinite_energy_check_button)
	_disable_weapon_durability_check_button = CheckButton.new()
	_disable_weapon_durability_check_button.text = "不消耗武器耐久"
	_disable_weapon_durability_check_button.custom_minimum_size = Vector2(0.0, 40.0)
	_disable_weapon_durability_check_button.toggled.connect(_on_weapon_durability_consumption_toggled)
	_combat_controls_container.add_child(_disable_weapon_durability_check_button)
	_map_vision_button = Button.new()
	_map_vision_button.text = "获取地图视野"
	_map_vision_button.custom_minimum_size = Vector2(0.0, 44.0)
	_map_vision_button.pressed.connect(_on_map_vision_pressed)
	_combat_controls_container.add_child(_map_vision_button)
	_training_settings_button = Button.new()
	_training_settings_button.text = "打开训练场设置"
	_training_settings_button.custom_minimum_size = Vector2(0.0, 44.0)
	_training_settings_button.pressed.connect(_on_training_settings_pressed)
	_combat_controls_container.add_child(_training_settings_button)
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
	_grant_equipment_button.disabled = not service_available
	_grant_stones_button.disabled = not service_available
	_grant_all_items_button.disabled = not service_available
	_add_coins_button.disabled = not service_available
	_remove_coins_button.disabled = not service_available
	_clear_warehouse_button.disabled = not service_available
	if not service_available:
		_status_label.text = "GlobalInventory 服务不可用"


func _refresh_context_visibility() -> void:
	custom_minimum_size = Vector2(panel_minimum_size.x, combat_panel_height if _combat_context_enabled else panel_minimum_size.y)
	if _hint_label != null:
		_hint_label.text = "战斗暂停时输入 LISBAM 开启" if _combat_context_enabled else "隐藏调试功能 · 输入序列 LISBAM 开启"
	# 局外经济控件遍历项；战斗模式隐藏，避免把永久仓库和金币操作混入当前战斗工具。
	for economy_control in _economy_controls:
		if economy_control != null:
			economy_control.visible = not _combat_context_enabled
	if _combat_controls_container != null:
		_combat_controls_container.visible = _combat_context_enabled
	if _status_label != null:
		_status_label.text = "可切换无限属性或打开训练工具" if _combat_context_enabled else "请选择开发者操作"
	sync_combat_states(_configured_infinite_health, _configured_infinite_energy, _configured_weapon_durability_disabled)
	_refresh_debug_information_toggle()


func _refresh_coins() -> void:
	if _global_inventory == null or not _global_inventory.has_method("get_coins"):
		_coins_label.text = "当前金币：不可用"
		return
	_coins_label.text = "当前金币：%d" % int(_global_inventory.call("get_coins"))


func _refresh_debug_information_toggle() -> void:
	if _debug_information_check_button == null:
		return
	# 调试设置服务；缺失时禁用开关，避免 UI 选择与实际显示状态不一致。
	var debug_settings: Node = get_tree().root.get_node_or_null("DebugSettings")
	var is_available: bool = debug_settings != null and debug_settings.has_method("is_debug_information_visible")
	_debug_information_check_button.disabled = not is_available
	_debug_information_check_button.set_pressed_no_signal(bool(debug_settings.call("is_debug_information_visible")) if is_available else false)


func _on_debug_information_toggled(enabled: bool) -> void:
	# 调试设置服务；只调用公开开关接口，使所有监听者同步刷新其展示文本。
	var debug_settings: Node = get_tree().root.get_node_or_null("DebugSettings")
	if debug_settings == null or not debug_settings.has_method("set_debug_information_visible"):
		return
	debug_settings.call("set_debug_information_visible", enabled)
	_status_label.text = "调试信息显示已%s" % ("开启" if enabled else "关闭")


func _on_grant_weapons_pressed() -> void:
	if _global_inventory == null or not _global_inventory.has_method("grant_all_known_weapons_to_warehouse"):
		return
	# 发放武器数量；取值为本次成功加入永久仓库的已知武器种类数。
	var granted_count: int = int(_global_inventory.call("grant_all_known_weapons_to_warehouse"))
	_status_label.text = "已向永久仓库发放 %d 件武器" % granted_count


func _on_grant_equipment_pressed() -> void:
	if _global_inventory == null or not _global_inventory.has_method("grant_all_known_equipment_to_warehouse"):
		return
	# 发放装备数量；当前为四种基础装备各一件。
	var granted_count: int = int(_global_inventory.call("grant_all_known_equipment_to_warehouse"))
	_status_label.text = "已向永久仓库发放 %d 件装备" % granted_count


func _on_grant_stones_pressed() -> void:
	if _global_inventory == null or not _global_inventory.has_method("grant_random_enhancement_stones_to_warehouse"):
		return
	# 发放强化石数量；默认应为 10，随机同词条强化石可能在仓库中自动合并为同一堆叠。
	var granted_count: int = int(_global_inventory.call("grant_random_enhancement_stones_to_warehouse", enhancement_stone_grant_count))
	_status_label.text = "已向永久仓库发放 %d 颗随机强化石" % granted_count


func _on_grant_all_items_pressed() -> void:
	if _global_inventory == null or not _global_inventory.has_method("grant_all_repair_kits_to_warehouse"):
		return
	# 发放道具数量；当前应为初级、中级和高级修复包各一件，后续新增道具会由路径表自动纳入。
	var granted_count: int = int(_global_inventory.call("grant_all_repair_kits_to_warehouse"))
	_status_label.text = "已向永久仓库发放 %d 种道具" % granted_count


func _on_add_coins_pressed() -> void:
	_adjust_coins(coin_step)


func _on_remove_coins_pressed() -> void:
	_adjust_coins(-coin_step)


func _on_clear_warehouse_pressed() -> void:
	if _clear_warehouse_confirmation == null:
		return
	_clear_warehouse_confirmation.popup_centered(Vector2i(520, 0))


func _on_clear_warehouse_confirmed() -> void:
	if _global_inventory == null or not _global_inventory.has_method("clear_warehouse_items"):
		return
	# 清空记录组数；武器每件一组，强化石按当前堆叠组统计，用于开发者操作反馈。
	var cleared_record_count: int = int(_global_inventory.call("clear_warehouse_items"))
	_status_label.text = "已清空永久仓库，共移除 %d 组物品" % cleared_record_count


func _adjust_coins(amount: int) -> void:
	if _global_inventory == null or not _global_inventory.has_method("adjust_coins"):
		return
	# 调整后金币；取值至少为 0，用于开发者操作完成后的即时反馈。
	var adjusted_coins: int = int(_global_inventory.call("adjust_coins", amount))
	_status_label.text = "金币已%s %d，当前为 %d" % ["增加" if amount >= 0 else "减少", absi(amount), adjusted_coins]
	_refresh_coins()


func _on_infinite_health_toggled(enabled: bool) -> void:
	_configured_infinite_health = enabled
	infinite_health_toggled.emit(enabled)
	_status_label.text = "无限血量已%s" % ("开启" if enabled else "关闭")


func _on_infinite_energy_toggled(enabled: bool) -> void:
	_configured_infinite_energy = enabled
	infinite_energy_toggled.emit(enabled)
	_status_label.text = "无限能量已%s" % ("开启" if enabled else "关闭")


func _on_weapon_durability_consumption_toggled(disabled: bool) -> void:
	_configured_weapon_durability_disabled = disabled
	weapon_durability_consumption_toggled.emit(disabled)
	_status_label.text = "武器耐久消耗已%s" % ("关闭" if disabled else "恢复")


func _on_training_settings_pressed() -> void:
	training_settings_requested.emit()


func _on_map_vision_pressed() -> void:
	map_vision_requested.emit()
	_status_label.text = "已获取整张地图视野"


func _on_close_pressed() -> void:
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	# ESC 关闭开发者菜单；仅处理按下且非重复事件，防止一次长按连续触发。
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			closed.emit()
			get_viewport().set_input_as_handled()
