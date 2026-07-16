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

## 全局窗口样式指南；统一主菜单与战斗开发者窗口、调试分区和高风险操作视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 通用整数选择弹窗；开发者强化石数量和目标金币余额复用滑条与数字输入协议。
const SELL_QUANTITY_DIALOG_SCRIPT: Script = preload("res://scripts/ui/sell_quantity_dialog.gd")
## 通用信息确认弹窗脚本；清空仓库等不可逆调试操作统一使用白边信息确认样式。
const COMMON_CONFIRMATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/common_confirmation_dialog.gd")
## 强化规则脚本；读取正式属性池、品质标识与中文名称，避免开发者菜单重复维护强化数据。
const ENHANCEMENT_RULES_SCRIPT: Script = preload("res://scripts/data/enhancement_rules.gd")

## 菜单最小尺寸；默认 520x580，适合在主菜单中央显示资源操作和调试信息开关。
@export var panel_minimum_size: Vector2 = Vector2(520.0, 640.0)
## 战斗调试上下文面板高度；默认 580 像素，用于容纳无限属性、地图视野和训练设置入口，运行时通常不动态修改。
@export_range(360.0, 720.0, 1.0) var combat_panel_height: float = 580.0
## 旧版单次金币调整数量；默认 1000，仅保留历史场景兼容，现行菜单改为直接输入目标金币余额。
@export_range(1, 9999999, 1) var coin_step: int = 1000
## 随机强化石数量默认值；默认 10，打开数量弹窗时作为初始选择，玩家可在 1 至最大值之间修改。
@export_range(1, 1000, 1) var enhancement_stone_grant_count: int = 10
## 随机强化石单次发放上限；固定为 1000，兼顾批量概率验证与调试存档规模。
@export_range(1, 1000, 1) var enhancement_stone_grant_maximum: int = 1000
## 随机强化石每帧生成数量；默认 25，使最大 1000 颗在较短时间内分批完成并避免单帧卡顿。
@export_range(1, 100, 1) var enhancement_stone_grant_batch_size: int = 25
## 可直接设置的金币余额上限；默认 9999999，避免调试输入超过项目整数经济显示范围。
@export_range(1, 999999999, 1) var coin_value_maximum: int = 9999999

## 全局物品服务；默认从 AutoLoad 获取，缺失时禁用资源修改按钮。
var _global_inventory: Node
## 股市服务；默认从 AutoLoad 获取，负责行情刷新、随机事件和大盘状态调试。
var _stock_market_service: Node
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
## 自定义强化石展开按钮；默认运行时创建，点击后显示或收起详细配置，避免主菜单初始展示过长设置表单。
var _custom_stone_toggle_button: Button
## 自定义强化石配置容器；默认运行时创建，包含品质、适用对象和三条可选词条，战斗开发者上下文会统一隐藏。
var _custom_stone_controls_container: VBoxContainer
## 自定义强化石品质选项；默认初级，玩家可从初级、中级、高级、极品中选择实际品质。
## 特化品质补充：下拉菜单同时提供特化，选中后会切换到特化独立属性池。
var _custom_stone_quality_option: OptionButton
## 自定义强化石适用对象选项；默认武器，决定后三个词条只显示武器或装备可用属性。
var _custom_stone_target_option: OptionButton
## 自定义强化石第一条加强词条选项；默认未选择且为必填，缺失时不会生成无效强化石。
var _custom_stone_beneficial_one_option: OptionButton
## 自定义强化石第二条加强词条选项；默认无，可选填且与第一条重复时会在生成阶段安全忽略。
var _custom_stone_beneficial_two_option: OptionButton
## 自定义强化石削弱词条选项；默认无，可选填且会按属性的反向收益方向写入强化石。
var _custom_stone_detrimental_option: OptionButton
## 创建自定义强化石按钮；点击后把当前配置生成一颗并存入永久仓库。
var _grant_custom_stone_button: Button
## 获取全部道具按钮；默认运行时创建，点击后向永久仓库各发放一件内容目录当前注册道具。
var _grant_all_items_button: Button
## 修改金币按钮；点击后通过滑条或数字输入直接设置目标金币余额。
var _modify_coins_button: Button
## 清空仓库按钮；默认运行时创建，点击后先弹出确认框再移除永久仓库中的全部物品。
var _clear_warehouse_button: Button
## 全量行情刷新按钮；模拟一次正式对局结算级别刷新，但不修改玩家行为统计。
var _stock_full_refresh_button: Button
## 小幅行情刷新按钮；模拟一次局外 60 秒运行级别刷新。
var _stock_runtime_refresh_button: Button
## 随机股市事件按钮；立即抽取并生效一个单股或全局事件。
var _stock_event_button: Button
## 大盘状态切换按钮；按牛市、熊市、震荡市顺序循环切换并显示结果。
var _stock_market_cycle_button: Button
## 清空股票持仓按钮；移除全部持仓且不返还金币，仅用于测试迁移和空状态界面。
var _clear_stock_holdings_button: Button
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
var _clear_warehouse_confirmation: CommonConfirmationDialog
## 开发者整数选择弹窗；强化石数量与目标金币余额共用，确认时按当前操作模式执行。
var _developer_value_dialog: SellQuantityDialog
## 当前开发者数值操作；取值为 stones 或 coins，默认空字符串表示没有待确认操作。
var _pending_developer_value_action: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = panel_minimum_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_stock_market_service = get_tree().root.get_node_or_null("StockMarketService")
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
	UI_STYLE_GUIDE.apply_title_label(title_label)
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
	_grant_stones_button.text = "获取指定数量强化石"
	_grant_stones_button.pressed.connect(_on_grant_stones_pressed)
	content.add_child(_grant_stones_button)
	_economy_controls.append(_grant_stones_button)
	_build_custom_stone_controls(content)
	_grant_all_items_button = Button.new()
	_grant_all_items_button.custom_minimum_size = Vector2(0.0, 46.0)
	_grant_all_items_button.text = "一键获取所有道具"
	_grant_all_items_button.pressed.connect(_on_grant_all_items_pressed)
	content.add_child(_grant_all_items_button)
	_economy_controls.append(_grant_all_items_button)
	_modify_coins_button = Button.new()
	_modify_coins_button.custom_minimum_size = Vector2(0.0, 46.0)
	_modify_coins_button.text = "修改金币数量"
	_modify_coins_button.pressed.connect(_on_modify_coins_pressed)
	content.add_child(_modify_coins_button)
	_economy_controls.append(_modify_coins_button)
	_clear_warehouse_button = Button.new()
	_clear_warehouse_button.custom_minimum_size = Vector2(0.0, 46.0)
	_clear_warehouse_button.text = "清空仓库物品"
	UI_STYLE_GUIDE.apply_danger_button(_clear_warehouse_button)
	_clear_warehouse_button.pressed.connect(_on_clear_warehouse_pressed)
	content.add_child(_clear_warehouse_button)
	_economy_controls.append(_clear_warehouse_button)
	# 股市调试标题；归入局外经济控件，战斗开发者上下文会统一隐藏。
	var stock_debug_title: Label = Label.new()
	stock_debug_title.text = "股市调试"
	stock_debug_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_debug_title.add_theme_font_size_override("font_size", 18)
	content.add_child(stock_debug_title)
	_economy_controls.append(stock_debug_title)
	_stock_full_refresh_button = Button.new()
	_stock_full_refresh_button.custom_minimum_size = Vector2(0.0, 42.0)
	_stock_full_refresh_button.text = "立即触发全量刷新"
	_stock_full_refresh_button.pressed.connect(_on_stock_full_refresh_pressed)
	content.add_child(_stock_full_refresh_button)
	_economy_controls.append(_stock_full_refresh_button)
	_stock_runtime_refresh_button = Button.new()
	_stock_runtime_refresh_button.custom_minimum_size = Vector2(0.0, 42.0)
	_stock_runtime_refresh_button.text = "立即触发小幅刷新"
	_stock_runtime_refresh_button.pressed.connect(_on_stock_runtime_refresh_pressed)
	content.add_child(_stock_runtime_refresh_button)
	_economy_controls.append(_stock_runtime_refresh_button)
	_stock_event_button = Button.new()
	_stock_event_button.custom_minimum_size = Vector2(0.0, 42.0)
	_stock_event_button.text = "触发随机事件"
	_stock_event_button.pressed.connect(_on_stock_event_pressed)
	content.add_child(_stock_event_button)
	_economy_controls.append(_stock_event_button)
	_stock_market_cycle_button = Button.new()
	_stock_market_cycle_button.custom_minimum_size = Vector2(0.0, 42.0)
	_stock_market_cycle_button.text = "切换大盘状态"
	_stock_market_cycle_button.pressed.connect(_on_stock_market_cycle_pressed)
	content.add_child(_stock_market_cycle_button)
	_economy_controls.append(_stock_market_cycle_button)
	_clear_stock_holdings_button = Button.new()
	_clear_stock_holdings_button.custom_minimum_size = Vector2(0.0, 42.0)
	_clear_stock_holdings_button.text = "清空全部持仓"
	UI_STYLE_GUIDE.apply_danger_button(_clear_stock_holdings_button)
	_clear_stock_holdings_button.pressed.connect(_on_clear_stock_holdings_pressed)
	content.add_child(_clear_stock_holdings_button)
	_economy_controls.append(_clear_stock_holdings_button)
	_clear_warehouse_confirmation = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_clear_warehouse_confirmation.confirmed.connect(_on_clear_warehouse_confirmed)
	add_child(_clear_warehouse_confirmation)
	_developer_value_dialog = SELL_QUANTITY_DIALOG_SCRIPT.new() as SellQuantityDialog
	_developer_value_dialog.quantity_confirmed.connect(_on_developer_value_confirmed)
	add_child(_developer_value_dialog)

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


func _build_custom_stone_controls(content: VBoxContainer) -> void:
	# 自定义强化石展开按钮；默认只显示入口，玩家明确点击后才创建视觉上的配置流程。
	_custom_stone_toggle_button = Button.new()
	_custom_stone_toggle_button.text = "自定义强化石效果"
	_custom_stone_toggle_button.custom_minimum_size = Vector2(0.0, 46.0)
	_custom_stone_toggle_button.pressed.connect(_on_custom_stone_toggle_pressed)
	content.add_child(_custom_stone_toggle_button)
	_economy_controls.append(_custom_stone_toggle_button)
	# 自定义强化石容器；独立归入局外经济区，初始隐藏，战斗开发者菜单会通过统一控件列表隐藏。
	_custom_stone_controls_container = VBoxContainer.new()
	_custom_stone_controls_container.add_theme_constant_override("separation", 8)
	content.add_child(_custom_stone_controls_container)
	_economy_controls.append(_custom_stone_controls_container)
	# 分区标题；明确这些选项只影响即将发放的一颗开发者强化石，不会改写随机掉落规则。
	var custom_stone_title: Label = Label.new()
	custom_stone_title.text = "自定义强化石配置"
	custom_stone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_stone_title.add_theme_font_size_override("font_size", 18)
	_custom_stone_controls_container.add_child(custom_stone_title)
	_custom_stone_quality_option = _create_custom_stone_selector("强化石品质")
	_custom_stone_target_option = _create_custom_stone_selector("适用对象")
	_custom_stone_beneficial_one_option = _create_custom_stone_selector("加强词条1")
	_custom_stone_beneficial_two_option = _create_custom_stone_selector("加强词条2")
	_custom_stone_detrimental_option = _create_custom_stone_selector("削弱词条1")
	# 品质选项；显示文本遵循扩展包和背包的中文命名，元数据使用强化规则的稳定 ID。
	_custom_stone_quality_option.add_item("初级")
	_custom_stone_quality_option.set_item_metadata(0, ENHANCEMENT_RULES_SCRIPT.QUALITY_LOW)
	_custom_stone_quality_option.add_item("中级")
	_custom_stone_quality_option.set_item_metadata(1, ENHANCEMENT_RULES_SCRIPT.QUALITY_MEDIUM)
	_custom_stone_quality_option.add_item("高级")
	_custom_stone_quality_option.set_item_metadata(2, ENHANCEMENT_RULES_SCRIPT.QUALITY_HIGH)
	_custom_stone_quality_option.add_item("极品")
	_custom_stone_quality_option.set_item_metadata(3, ENHANCEMENT_RULES_SCRIPT.QUALITY_SUPREME)
	_custom_stone_quality_option.add_item("特化")
	_custom_stone_quality_option.set_item_metadata(4, ENHANCEMENT_RULES_SCRIPT.QUALITY_SPECIALIZED)
	_custom_stone_quality_option.item_selected.connect(_on_custom_stone_quality_selected)
	# 适用对象选项；强化石现行协议区分武器与装备，选择后实时缩小可选词条池以避免无效物品。
	_custom_stone_target_option.add_item("武器")
	_custom_stone_target_option.set_item_metadata(0, "weapon")
	_custom_stone_target_option.add_item("装备")
	_custom_stone_target_option.set_item_metadata(1, "equipment")
	_custom_stone_target_option.item_selected.connect(_on_custom_stone_target_selected)
	_refresh_custom_stone_stat_options()
	_grant_custom_stone_button = Button.new()
	_grant_custom_stone_button.text = "生成自定义强化石"
	_grant_custom_stone_button.custom_minimum_size = Vector2(0.0, 42.0)
	_grant_custom_stone_button.pressed.connect(_on_grant_custom_stone_pressed)
	_custom_stone_controls_container.add_child(_grant_custom_stone_button)
	_custom_stone_controls_container.visible = false


func _on_custom_stone_toggle_pressed() -> void:
	## 切换自定义强化石配置的可见性；入口按钮始终保留，防止收起后无法再次打开。
	if _custom_stone_controls_container == null:
		return
	# 展开后的可见性；默认从隐藏切换为显示，后续每次点击在两种稳定状态间反转。
	var should_show_controls: bool = not _custom_stone_controls_container.visible
	_custom_stone_controls_container.visible = should_show_controls
	if _custom_stone_toggle_button != null:
		_custom_stone_toggle_button.text = "收起自定义强化石效果" if should_show_controls else "自定义强化石效果"


func _create_custom_stone_selector(label_text: String) -> OptionButton:
	## 创建一行开发者强化石选项；所有行使用相同布局，避免品质与三条词条各自维护重复 UI 逻辑。
	# 选项行；横向摆放固定宽度说明标签与可扩展的下拉选择器。
	var selector_row: HBoxContainer = HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 12)
	_custom_stone_controls_container.add_child(selector_row)
	# 选项标签；取值为调用方传入的永久功能名称，直接对应开发者设置中的可配置项。
	var selector_label: Label = Label.new()
	selector_label.text = label_text
	selector_label.custom_minimum_size = Vector2(112.0, 32.0)
	selector_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selector_row.add_child(selector_label)
	# 下拉选择器；默认按调用方随后填入的选项显示，横向占满可用区域。
	var selector_option: OptionButton = OptionButton.new()
	selector_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_option.custom_minimum_size = Vector2(0.0, 32.0)
	selector_row.add_child(selector_option)
	return selector_option


func _on_custom_stone_target_selected(_selected_index: int) -> void:
	## 在武器与装备之间切换时刷新三条词条的候选池；旧选项不跨目标保留，避免生成无法应用的词条。
	_refresh_custom_stone_stat_options()


func _on_custom_stone_quality_selected(_selected_index: int) -> void:
	## 切换品质时同步刷新增强与削弱词条池；特化品质不与普通四品质共用属性列表。
	_refresh_custom_stone_stat_options()


func _refresh_custom_stone_stat_options() -> void:
	## 根据当前适用对象填充词条选项；第一条加强必须选择有效属性，其他两条保留“无”作为可选空值。
	if _custom_stone_target_option == null or _custom_stone_beneficial_one_option == null or _custom_stone_beneficial_two_option == null or _custom_stone_detrimental_option == null:
		return
	# 当前适用对象；默认武器，元数据异常时同样安全回退武器属性池。
	var target_kind: String = str(_custom_stone_target_option.get_item_metadata(_custom_stone_target_option.selected))
	# 当前品质；元数据来自品质下拉菜单，决定是读取普通属性池还是特化独立池。
	var quality_id: String = str(_custom_stone_quality_option.get_item_metadata(_custom_stone_quality_option.selected))
	# 当前增强属性池；由正式规则目录提供，新增特化属性后会自动进入开发者下拉菜单。
	var beneficial_stat_names: Array[String] = ENHANCEMENT_RULES_SCRIPT.get_beneficial_stat_keys_for_quality(quality_id, target_kind)
	# 第二增强属性池；先复制为强类型字符串数组，避免特化品质的空数组分支退化为未类型化 Array。
	var second_beneficial_stat_names: Array[String] = beneficial_stat_names.duplicate()
	# 特化第二增强限制；特化强化石固定只有一条正向机制，因此清空候选池并只保留下拉框的“无”。
	if quality_id == ENHANCEMENT_RULES_SCRIPT.QUALITY_SPECIALIZED:
		second_beneficial_stat_names.clear()
	# 当前削弱属性池；特化武器词条与正向离散机制分开配置。
	var detrimental_stat_names: Array[String] = ENHANCEMENT_RULES_SCRIPT.get_detrimental_stat_keys_for_quality(quality_id, target_kind)
	_populate_custom_stone_stat_option(_custom_stone_beneficial_one_option, beneficial_stat_names, "请选择加强词条")
	_populate_custom_stone_stat_option(_custom_stone_beneficial_two_option, second_beneficial_stat_names, "无")
	_populate_custom_stone_stat_option(_custom_stone_detrimental_option, detrimental_stat_names, "无")


func _populate_custom_stone_stat_option(option_button: OptionButton, supported_stat_names: Array[String], empty_label: String) -> void:
	## 把正式属性池写入单个下拉框；首项的空元数据使生成器可区分“未选择”与一个真实词条。
	if option_button == null:
		return
	option_button.clear()
	option_button.add_item(empty_label)
	option_button.set_item_metadata(0, "")
	for stat_name in supported_stat_names:
		option_button.add_item(str(ENHANCEMENT_RULES_SCRIPT.get_stat_label(stat_name)))
		option_button.set_item_metadata(option_button.item_count - 1, stat_name)


func _get_custom_stone_option_value(option_button: OptionButton) -> String:
	## 返回下拉框当前的稳定属性或品质标识；控件尚未创建、未选中或元数据异常时返回空字符串。
	if option_button == null or option_button.selected < 0:
		return ""
	return str(option_button.get_item_metadata(option_button.selected))


func _refresh_availability() -> void:
	# 服务是否可用；取值决定所有会修改局外存档的开发者按钮是否可点击。
	var service_available: bool = _global_inventory != null
	_grant_weapons_button.disabled = not service_available
	_grant_equipment_button.disabled = not service_available
	_grant_stones_button.disabled = not service_available
	if _custom_stone_toggle_button != null:
		_custom_stone_toggle_button.disabled = not service_available
	if _grant_custom_stone_button != null:
		_grant_custom_stone_button.disabled = not service_available
	_grant_all_items_button.disabled = not service_available
	_modify_coins_button.disabled = not service_available
	_clear_warehouse_button.disabled = not service_available
	# 股市服务可用性；决定行情刷新、事件和大盘按钮是否允许点击。
	var stock_service_available: bool = _stock_market_service != null
	_stock_full_refresh_button.disabled = not stock_service_available
	_stock_runtime_refresh_button.disabled = not stock_service_available
	_stock_event_button.disabled = not stock_service_available
	_stock_market_cycle_button.disabled = not stock_service_available
	_clear_stock_holdings_button.disabled = not service_available
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
	if _global_inventory == null or _developer_value_dialog == null:
		return
	_pending_developer_value_action = "stones"
	_developer_value_dialog.present_developer_value("获取强化石", "选择要生成并存入永久仓库的随机强化石数量", 1, maxi(enhancement_stone_grant_maximum, 1), clampi(enhancement_stone_grant_count, 1, maxi(enhancement_stone_grant_maximum, 1)), "获取")


func _on_grant_custom_stone_pressed() -> void:
	## 读取当前开发者配置并生成一颗自定义强化石；只允许第一条加强词条为空时阻止生成，其余重复或空词条由数据层安全归一化。
	if _global_inventory == null or not _global_inventory.has_method("grant_custom_enhancement_stone_to_warehouse"):
		return
	# 第一条加强词条；取值为空代表玩家尚未完成必填配置，不调用库存服务以避免产生无效资源。
	var beneficial_stat_name_one: String = _get_custom_stone_option_value(_custom_stone_beneficial_one_option)
	if beneficial_stat_name_one.is_empty():
		_status_label.text = "请先选择加强词条1"
		return
	# 创建结果；库存服务复用正式强化石数据生成与保存流程，false 表示配置与目标类型不兼容。
	var granted: bool = bool(_global_inventory.call("grant_custom_enhancement_stone_to_warehouse", _get_custom_stone_option_value(_custom_stone_quality_option), _get_custom_stone_option_value(_custom_stone_target_option), beneficial_stat_name_one, _get_custom_stone_option_value(_custom_stone_beneficial_two_option), _get_custom_stone_option_value(_custom_stone_detrimental_option)))
	_status_label.text = "已向永久仓库发放自定义强化石" if granted else "自定义强化石配置无效，请重新选择词条"


func _on_grant_all_items_pressed() -> void:
	if _global_inventory == null or not _global_inventory.has_method("grant_all_repair_kits_to_warehouse"):
		return
	# 发放道具数量；当前包含三种修复包和三种能量饮料，后续新增道具由内容目录自动纳入。
	var granted_count: int = int(_global_inventory.call("grant_all_repair_kits_to_warehouse"))
	_status_label.text = "已向永久仓库发放 %d 种道具" % granted_count


func _on_modify_coins_pressed() -> void:
	if _global_inventory == null or _developer_value_dialog == null or not _global_inventory.has_method("get_coins"):
		return
	_pending_developer_value_action = "coins"
	# 当前金币；作为弹窗初始值，玩家可拉条或输入 0 至配置上限的目标余额。
	var current_coins: int = clampi(int(_global_inventory.call("get_coins")), 0, maxi(coin_value_maximum, 1))
	_developer_value_dialog.present_developer_value("修改金币数量", "直接设置永久金币余额", 0, maxi(coin_value_maximum, 1), current_coins, "修改")


func _on_developer_value_confirmed(value: int) -> void:
	if _global_inventory == null:
		return
	if _pending_developer_value_action == "stones":
		if not _global_inventory.has_method("grant_random_enhancement_stones_to_warehouse_gradually"):
			return
		_grant_stones_button.disabled = true
		_status_label.text = "正在分批生成 %d 颗随机强化石……" % maxi(value, 1)
		# 实际发放数量；每颗使用正式生成器，按帧分批生成并在全部完成后统一刷新仓库。
		var granted_count: int = int(await _global_inventory.call("grant_random_enhancement_stones_to_warehouse_gradually", maxi(value, 1), maxi(enhancement_stone_grant_batch_size, 1)))
		_grant_stones_button.disabled = false
		_status_label.text = "已向永久仓库发放 %d 颗随机强化石" % granted_count
	elif _pending_developer_value_action == "coins":
		if not _global_inventory.has_method("set_coins"):
			return
		# 修改后金币；直接设置为目标余额，不再进行固定步长的增减运算。
		var adjusted_coins: int = int(_global_inventory.call("set_coins", maxi(value, 0)))
		_status_label.text = "金币数量已修改为 %d" % adjusted_coins
		_refresh_coins()
	_pending_developer_value_action = ""


func _on_clear_warehouse_pressed() -> void:
	if _clear_warehouse_confirmation == null:
		return
	_clear_warehouse_confirmation.present_adaptive("确认清空仓库", "将永久删除仓库中的全部物品，随身背包和装备不会受影响。", "确认清空", "取消", true)


func _on_clear_warehouse_confirmed() -> void:
	if _global_inventory == null or not _global_inventory.has_method("clear_warehouse_items"):
		return
	# 清空记录组数；武器每件一组，强化石按当前堆叠组统计，用于开发者操作反馈。
	var cleared_record_count: int = int(_global_inventory.call("clear_warehouse_items"))
	_status_label.text = "已清空永久仓库，共移除 %d 组物品" % cleared_record_count


func _on_stock_full_refresh_pressed() -> void:
	if _stock_market_service == null or not _stock_market_service.has_method("refresh_market"):
		return
	_stock_market_service.call("refresh_market", "settlement")
	_status_label.text = "已触发一次全量行情刷新"


func _on_stock_runtime_refresh_pressed() -> void:
	if _stock_market_service == null or not _stock_market_service.has_method("refresh_market"):
		return
	_stock_market_service.call("refresh_market", "runtime")
	_status_label.text = "已触发一次小幅行情刷新"


func _on_stock_event_pressed() -> void:
	if _stock_market_service == null or not _stock_market_service.has_method("trigger_random_event"):
		return
	# 新触发事件数据；读取消息字段用于开发者操作反馈。
	var event_data: Dictionary = _stock_market_service.call("trigger_random_event") as Dictionary
	_status_label.text = "已触发事件：%s" % str(event_data.get("message", "未知事件"))


func _on_stock_market_cycle_pressed() -> void:
	if _stock_market_service == null or not _stock_market_service.has_method("cycle_market_state"):
		return
	# 切换后大盘标识；取值为 bull、bear 或 sideways。
	var market_state: String = str(_stock_market_service.call("cycle_market_state"))
	# 切换后中文名称；用于状态标签直接展示。
	var market_name: String = "牛市" if market_state == "bull" else ("熊市" if market_state == "bear" else "震荡市")
	_status_label.text = "大盘已切换为%s" % market_name


func _on_clear_stock_holdings_pressed() -> void:
	if _global_inventory == null or not _global_inventory.has_method("clear_stock_holdings"):
		return
	# 清空股数；统计所有股票被移除的总股数，不返还金币。
	var cleared_quantity: int = int(_global_inventory.call("clear_stock_holdings"))
	_status_label.text = "已清空全部持仓，共移除 %d 股，不返还金币" % cleared_quantity


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
	# 隐藏菜单不得拦截 ESC，否则暂停菜单、仓库、背包和设置界面无法收到关闭输入。
	if not is_visible_in_tree():
		return
	# ESC 关闭开发者菜单；仅处理按下且非重复事件，防止一次长按连续触发。
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE):
			closed.emit()
			get_viewport().set_input_as_handled()
