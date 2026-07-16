extends Control

## 主菜单负责项目启动后的第一个可交互界面。
## 这里保留骇入、训练场、角色系统、设置和退出等清晰路径，避免把游戏流程逻辑写进具体按钮。
## 战斗入口直接使用 SessionState 当前角色；角色选择作为独立系统从底部“角色”按钮进入。

## 正式骇入模式标识；默认写入 SessionState，修改会影响骇入入口进入后的模式判定。
const GAME_MODE_HACK: String = "hack"
## 训练场模式标识；默认写入 SessionState，修改会影响训练场入口进入后的模式判定。
const GAME_MODE_TRAINING: String = "training"
## 按键绑定面板脚本；默认用于主菜单设置中动态创建可重绑定操作列表。
const KEY_BINDING_PANEL_SCRIPT: Script = preload("res://scripts/ui/key_binding_panel.gd")
## 存档传输控件脚本；默认用于主菜单设置中复用导出、导入文件选择和结果提示。
const SAVE_TRANSFER_CONTROL_SCRIPT: Script = preload("res://scripts/ui/save_transfer_control.gd")
## 全局窗口样式指南；统一主菜单、设置页和全部局外遮罩窗口的主题与语义按钮颜色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 可视进度拖动条组件；为主音量滑条绘制完整轨道、当前进度和实时滑块位置，不改变音量业务逻辑。
const PROGRESS_SLIDER_VISUAL_SCRIPT: Script = preload("res://scripts/ui/progress_slider_visual.gd")
## 局外仓库面板脚本；默认在主菜单点击仓库按钮后动态创建并读取全局背包服务。
const WAREHOUSE_PANEL_SCRIPT: Script = preload("res://scripts/ui/warehouse_panel.gd")
## 主菜单背包面板脚本；复用游戏内背包装备结构，局外丢弃会直接永久移除物品。
const MAIN_MENU_BACKPACK_PANEL_SCRIPT: Script = preload("res://scripts/ui/main_menu_backpack_panel.gd")
## 局外商店面板脚本；默认在主菜单点击商店按钮后动态创建并读取全局商店服务。
const SHOP_PANEL_SCRIPT: Script = preload("res://scripts/ui/shop_panel.gd")
## 局外锻造面板脚本；默认在主菜单点击锻造按钮后动态创建并组合库存与锻造服务。
const FORGE_PANEL_SCRIPT: Script = preload("res://scripts/ui/forge_panel.gd")
## 股市面板脚本；默认在主菜单点击炒股按钮后动态创建并组合行情与持仓服务。
const STOCK_MARKET_PANEL_SCRIPT: Script = preload("res://scripts/ui/stock_market_panel.gd")
## 矿场面板脚本；默认在主菜单点击矿场按钮后动态创建并读取全局矿场服务。
const MINING_FARM_PANEL_SCRIPT: Script = preload("res://scripts/ui/mining_farm_panel.gd")
## 图鉴面板脚本；默认在主菜单点击图鉴按钮后动态创建，并从内容目录和永久库存读取展示与解锁状态。
const ENCYCLOPEDIA_PANEL_SCRIPT: Script = preload("res://scripts/ui/encyclopedia_panel.gd")
## 隐藏开发者菜单脚本；默认只在主菜单依次输入 LISBAM 后显示。
const DEVELOPER_MENU_SCRIPT: Script = preload("res://scripts/ui/developer_menu.gd")
## 开发者模式解锁序列；默认由六个英文字母组成，输入错误会按首字母重新匹配。
const DEVELOPER_UNLOCK_SEQUENCE: String = "LISBAM"
## 角色系统场景路径；默认由主菜单底部“角色”按钮进入，只允许填写 tscn 资源，运行时通常不动态修改。
@export_file("*.tscn") var character_select_scene_path: String = "res://scenes/ui/character_select.tscn"
## 游戏场景路径；骇入和训练场入口写入模式后直接进入该场景，当前角色由 SessionState 提供。
@export_file("*.tscn") var game_scene_path: String = "res://scenes/game/game_world.tscn"

## 骇入按钮缓存；默认绑定唯一名 StartButton，必须是 Button，修改节点名会导致正式入口无法进入战斗。
@onready var _start_button: Button = %StartButton
## 训练场按钮缓存；默认绑定唯一名 TrainingButton，必须是 Button，修改节点名会导致训练场入口无法进入战斗。
@onready var _training_button: Button = %TrainingButton
## 设置按钮缓存；默认绑定唯一名 SettingsButton，必须是 Button，修改节点名会导致主菜单无法打开设置。
@onready var _settings_button: Button = %SettingsButton
## 退出按钮缓存；默认绑定唯一名 QuitButton，必须是 Button，修改节点名会导致主菜单无法退出程序。
@onready var _quit_button: Button = %QuitButton
## 仓库按钮缓存；默认位于主菜单底部功能栏第三位，点击后打开全局背包与装备调整界面。
@onready var _warehouse_button: Button = %WarehouseButton
## 角色按钮缓存；默认位于主菜单底部功能栏首位，点击后进入独立角色系统。
@onready var _character_button: Button = %CharacterButton
## 背包按钮缓存；默认位于角色按钮右侧，点击后打开游戏内同款装备栏与随身物品界面。
@onready var _backpack_button: Button = %BackpackButton
## 商店按钮缓存；默认位于仓库按钮右侧，点击后打开普通商店与灰市界面。
@onready var _shop_button: Button = %ShopButton
## 锻造按钮缓存；默认位于商店按钮右侧，点击后打开主武器修复与强化界面。
@onready var _forge_button: Button = %ForgeButton
## 炒股按钮缓存；默认位于锻造按钮右侧，点击后打开永久资产股市界面。
@onready var _stock_market_button: Button = %StockMarketButton
## 矿场按钮缓存；默认位于炒股按钮右侧，点击后打开常驻算力资产经营界面。
@onready var _mining_farm_button: Button = %MiningFarmButton
## 图鉴按钮缓存；默认位于主菜单底部功能栏末位，点击后查看武器、装备与资源的永久收集状态。
@onready var _encyclopedia_button: Button = %EncyclopediaButton
## 设置面板缓存；默认绑定唯一名 SettingsPanel，控制主菜单设置界面的显示和隐藏。
@onready var _settings_panel: Control = %SettingsPanel
## 设置内容容器缓存；默认通过场景路径绑定，用于动态挂载按键绑定面板。
@onready var _settings_content: VBoxContainer = get_node("SettingsPanel/SettingsMargin/SettingsContent") as VBoxContainer
## 设置首页标题缓存；默认按节点路径绑定 SettingsTitle，用于多页设置中切换首页显示。
@onready var _settings_title_label: Label = get_node("SettingsPanel/SettingsMargin/SettingsContent/SettingsTitle") as Label
## 主音量滑条缓存；默认绑定唯一名 MasterVolumeSlider，取值 0 到 100，修改会影响全局 Master 音量。
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
## 主音量行容器缓存；默认绑定主音量标签、滑条和数值，用于多页设置中切换首页显示。
@onready var _master_volume_row: HBoxContainer = get_node("SettingsPanel/SettingsMargin/SettingsContent/MasterVolumeRow") as HBoxContainer
## 主音量数值文本缓存；默认绑定唯一名 MasterVolumeValueLabel，显示滑条当前百分比。
@onready var _master_volume_value_label: Label = %MasterVolumeValueLabel
## 设置页弹性留白缓存；默认按节点路径绑定 SettingsSpacer，用于保持首页按钮位置稳定。
@onready var _settings_spacer: Control = get_node("SettingsPanel/SettingsMargin/SettingsContent/SettingsSpacer") as Control
## 设置返回按钮缓存；默认绑定唯一名 SettingsBackButton，点击后关闭设置面板。
@onready var _settings_back_button: Button = %SettingsBackButton

## Master 音频总线索引；取值为 -1 或有效总线下标，默认 -1 表示尚未解析，修改会影响音量应用目标。
var _master_bus_index: int = -1
## 主菜单按键绑定面板缓存；默认运行时创建，显示并修改 InputMap 的玩家操作绑定。
var _key_binding_panel: Control
## 按键绑定入口按钮缓存；默认运行时插入设置首页，点击后切换到按键绑定页面。
var _key_binding_button: Button
## 按键绑定页面容器缓存；默认运行时创建并隐藏，显示时替代设置首页内容。
var _key_binding_page: VBoxContainer
## 按键绑定页面返回按钮缓存；默认运行时创建，点击后回到设置首页而不是关闭设置面板。
var _key_binding_back_button: Button
## 设置首页控件列表；元素为 Control，默认用于在多页设置之间统一隐藏或显示首页内容。
var _settings_home_controls: Array[Control] = []
## 主菜单存档传输控件；默认运行时插入设置首页，导入成功后由全局服务重启游戏。
var _save_transfer_control: Control
## 仓库全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他按钮接收鼠标输入。
var _warehouse_overlay: Control
## 仓库面板实例；默认由 WarehousePanel 脚本创建，关闭后复用而不重复构建服务数据。
var _warehouse_panel: Control
## 背包全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他按钮接收输入。
var _backpack_overlay: Control
## 主菜单背包面板实例；关闭后复用并通过全局库存信号实时刷新。
var _backpack_panel: Control
## 商店全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他按钮接收鼠标输入。
var _shop_overlay: Control
## 商店面板实例；默认由 ShopPanel 脚本创建，关闭后复用并保留当前查询条件。
var _shop_panel: Control
## 锻造全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他按钮接收鼠标输入。
var _forge_overlay: Control
## 锻造面板实例；默认由 ForgePanel 脚本创建，关闭后复用并保留未执行的槽位引用。
var _forge_panel: Control
## 股市全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他入口接收输入。
var _stock_market_overlay: Control
## 股市面板实例；默认由 StockMarketPanel 创建，关闭后复用并由服务信号实时刷新。
var _stock_market_panel: Control
## 矿场全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他入口接收输入。
var _mining_farm_overlay: Control
## 矿场面板实例；关闭后复用，后台收益由独立 Autoload 服务继续低频结算。
var _mining_farm_panel: Control
## 图鉴全屏遮罩；默认运行时创建并隐藏，显示时阻止主菜单其他入口接收鼠标输入。
var _encyclopedia_overlay: Control
## 图鉴面板实例；关闭后复用，打开时从内容目录重新读取全部条目并同步永久发现状态。
var _encyclopedia_panel: Control
## 开发者菜单全屏遮罩；默认运行时创建并隐藏，解锁后阻止其他主菜单控件接收输入。
var _developer_overlay: Control
## 开发者菜单实例；默认由 DeveloperMenu 脚本动态创建并在关闭后复用。
var _developer_menu: Control
## 开发者序列当前匹配下标；取值 0 到序列长度，默认 0 表示等待字母 L。
var _developer_sequence_index: int = 0


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(_settings_panel)
	UI_STYLE_GUIDE.apply_primary_button(_start_button)
	UI_STYLE_GUIDE.apply_danger_button(_quit_button)
	UI_STYLE_GUIDE.apply_title_label(get_node("Center/Title") as Label)
	UI_STYLE_GUIDE.apply_title_label(_settings_title_label)
	(get_node("Background") as ColorRect).color = UI_STYLE_GUIDE.SCREEN_BACKGROUND_COLOR
	PROGRESS_SLIDER_VISUAL_SCRIPT.install(_master_volume_slider)
	_master_bus_index = AudioServer.get_bus_index("Master")
	_start_button.pressed.connect(_on_start_button_pressed)
	_training_button.pressed.connect(_on_training_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_character_button.pressed.connect(_on_character_button_pressed)
	_warehouse_button.pressed.connect(_on_warehouse_button_pressed)
	_backpack_button.pressed.connect(_on_backpack_button_pressed)
	_shop_button.pressed.connect(_on_shop_button_pressed)
	_forge_button.pressed.connect(_on_forge_button_pressed)
	_stock_market_button.pressed.connect(_on_stock_market_button_pressed)
	_mining_farm_button.pressed.connect(_on_mining_farm_button_pressed)
	_encyclopedia_button.pressed.connect(_on_encyclopedia_button_pressed)
	_master_volume_slider.value_changed.connect(_on_master_volume_slider_value_changed)
	_settings_back_button.pressed.connect(_on_settings_back_button_pressed)
	_build_key_binding_navigation()
	_build_warehouse_overlay()
	_build_backpack_overlay()
	_build_shop_overlay()
	_build_forge_overlay()
	_build_stock_market_overlay()
	_build_mining_farm_overlay()
	_build_encyclopedia_overlay()
	_build_developer_overlay()
	_settings_panel.visible = false
	_show_key_binding_page(false)
	_sync_master_volume_slider()
	_start_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	# 键盘事件；只处理首次按下且具有 Unicode 字符的字母键，长按重复不会推进序列。
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.unicode <= 0:
		return
	# 输入字符；统一转为大写后与隐藏序列逐位比较，键盘大小写状态不会影响解锁。
	var input_character: String = String.chr(key_event.unicode).to_upper()
	# 当前期望字符；取值为序列匹配下标对应单字符，用于推进或重置解锁进度。
	var expected_character: String = DEVELOPER_UNLOCK_SEQUENCE.substr(_developer_sequence_index, 1)
	if input_character == expected_character:
		_developer_sequence_index += 1
	else:
		_developer_sequence_index = 1 if input_character == DEVELOPER_UNLOCK_SEQUENCE.substr(0, 1) else 0
	if _developer_sequence_index < DEVELOPER_UNLOCK_SEQUENCE.length():
		return
	_developer_sequence_index = 0
	_open_developer_menu()
	get_viewport().set_input_as_handled()


func _on_start_button_pressed() -> void:
	_start_game(GAME_MODE_HACK)


func _on_training_button_pressed() -> void:
	_start_game(GAME_MODE_TRAINING)


func _on_character_button_pressed() -> void:
	_settings_panel.visible = false
	_change_scene_with_transition(character_select_scene_path)


func _on_settings_button_pressed() -> void:
	_settings_panel.visible = true
	_show_key_binding_page(false)
	_settings_back_button.grab_focus()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_warehouse_button_pressed() -> void:
	if _warehouse_overlay == null:
		return
	_settings_panel.visible = false
	_warehouse_overlay.visible = true
	if _warehouse_panel != null and _warehouse_panel.has_method("refresh"):
		_warehouse_panel.call("refresh")


func _on_backpack_button_pressed() -> void:
	if _backpack_overlay == null:
		return
	_settings_panel.visible = false
	_backpack_overlay.visible = true
	if _backpack_panel != null and _backpack_panel.has_method("refresh"):
		_backpack_panel.call("refresh")


func _on_shop_button_pressed() -> void:
	if _shop_overlay == null:
		return
	_settings_panel.visible = false
	_shop_overlay.visible = true


func _on_forge_button_pressed() -> void:
	if _forge_overlay == null:
		return
	_settings_panel.visible = false
	_forge_overlay.visible = true
	if _forge_panel != null and _forge_panel.has_method("refresh"):
		_forge_panel.call("refresh")


func _on_stock_market_button_pressed() -> void:
	if _stock_market_overlay == null:
		return
	_settings_panel.visible = false
	_stock_market_overlay.visible = true
	if _stock_market_panel != null and _stock_market_panel.has_method("set_market_display_active"):
		_stock_market_panel.call("set_market_display_active", true)


func _on_mining_farm_button_pressed() -> void:
	if _mining_farm_overlay == null:
		return
	_settings_panel.visible = false
	_mining_farm_overlay.visible = true
	if _mining_farm_panel != null and _mining_farm_panel.has_method("present"):
		_mining_farm_panel.call("present")


func _on_encyclopedia_button_pressed() -> void:
	if _encyclopedia_overlay == null:
		return
	_settings_panel.visible = false
	_encyclopedia_overlay.visible = true
	if _encyclopedia_panel != null and _encyclopedia_panel.has_method("refresh"):
		_encyclopedia_panel.call("refresh")


func _build_warehouse_overlay() -> void:
	if _warehouse_overlay != null:
		return

	# 仓库遮罩；覆盖整个主菜单并拦截输入，关闭时整体隐藏。
	var warehouse_overlay: Control = Control.new()
	warehouse_overlay.name = "WarehouseOverlay"
	warehouse_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warehouse_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(warehouse_overlay)
	_warehouse_overlay = warehouse_overlay

	# 仓库背景遮罩；使用半透明黑色突出仓库内容。
	var warehouse_dim: ColorRect = ColorRect.new()
	warehouse_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 全局遮罩补充；实际颜色由样式指南统一为带蓝色分量的深色透明层。
	warehouse_dim.color = UI_STYLE_GUIDE.OVERLAY_DIM_COLOR
	warehouse_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	warehouse_overlay.add_child(warehouse_dim)

	# 仓库面板；居中显示并由独立组件维护装备和物品列表。
	var warehouse_panel: Control = WAREHOUSE_PANEL_SCRIPT.new() as Control
	if warehouse_panel == null:
		warehouse_overlay.visible = false
		return
	warehouse_panel.anchor_left = 0.5
	warehouse_panel.anchor_top = 0.5
	warehouse_panel.anchor_right = 0.5
	warehouse_panel.anchor_bottom = 0.5
	warehouse_panel.offset_left = -480.0
	warehouse_panel.offset_top = -310.0
	warehouse_panel.offset_right = 480.0
	warehouse_panel.offset_bottom = 310.0
	warehouse_panel.connect("closed", Callable(self, "_on_warehouse_closed"))
	warehouse_overlay.add_child(warehouse_panel)
	_warehouse_panel = warehouse_panel
	warehouse_overlay.visible = false


func _build_backpack_overlay() -> void:
	if _backpack_overlay != null:
		return
	# 背包遮罩；覆盖完整主菜单并拦截输入，视觉透明度与仓库遮罩一致。
	var backpack_overlay: Control = Control.new()
	backpack_overlay.name = "BackpackOverlay"
	backpack_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backpack_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backpack_overlay)
	_backpack_overlay = backpack_overlay
	var backpack_dim: ColorRect = ColorRect.new()
	backpack_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 全局遮罩补充；背包与其他局外窗口使用同一深蓝黑透明层。
	backpack_dim.color = UI_STYLE_GUIDE.OVERLAY_DIM_COLOR
	backpack_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	backpack_overlay.add_child(backpack_dim)
	# 背包面板；居中显示并保持与游戏内背包接近的 960×620 尺寸。
	var backpack_panel: Control = MAIN_MENU_BACKPACK_PANEL_SCRIPT.new() as Control
	if backpack_panel == null:
		backpack_overlay.visible = false
		return
	backpack_panel.call("configure_context", SharedBackpackPanel.CONTEXT_MAIN_MENU)
	backpack_panel.anchor_left = 0.5
	backpack_panel.anchor_top = 0.5
	backpack_panel.anchor_right = 0.5
	backpack_panel.anchor_bottom = 0.5
	backpack_panel.offset_left = -480.0
	backpack_panel.offset_top = -310.0
	backpack_panel.offset_right = 480.0
	backpack_panel.offset_bottom = 310.0
	backpack_panel.connect("closed", Callable(self, "_on_backpack_closed"))
	backpack_overlay.add_child(backpack_panel)
	_backpack_panel = backpack_panel
	backpack_overlay.visible = false


func _build_shop_overlay() -> void:
	if _shop_overlay != null:
		return

	# 商店遮罩；覆盖整个主菜单并拦截输入，关闭时整体隐藏。
	var shop_overlay: Control = Control.new()
	shop_overlay.name = "ShopOverlay"
	shop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shop_overlay)
	_shop_overlay = shop_overlay

	# 商店背景遮罩；使用半透明黑色突出商品查询和购买区域。
	var shop_dim: ColorRect = ColorRect.new()
	shop_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 全局遮罩补充；实际颜色由样式指南统一管理。
	shop_dim.color = UI_STYLE_GUIDE.OVERLAY_DIM_COLOR
	shop_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.add_child(shop_dim)

	# 商店面板；居中显示并由独立组件维护商品刷新、筛选与购买确认。
	var shop_panel: Control = SHOP_PANEL_SCRIPT.new() as Control
	if shop_panel == null:
		shop_overlay.visible = false
		return
	shop_panel.anchor_left = 0.5
	shop_panel.anchor_top = 0.5
	shop_panel.anchor_right = 0.5
	shop_panel.anchor_bottom = 0.5
	shop_panel.offset_left = -480.0
	shop_panel.offset_top = -310.0
	shop_panel.offset_right = 480.0
	shop_panel.offset_bottom = 310.0
	shop_panel.connect("closed", Callable(self, "_on_shop_closed"))
	shop_overlay.add_child(shop_panel)
	_shop_panel = shop_panel
	shop_overlay.visible = false


func _build_forge_overlay() -> void:
	if _forge_overlay != null:
		return

	# 锻造遮罩；覆盖整个主菜单并拦截输入，锻造动画期间由面板自身阻止关闭。
	var forge_overlay: Control = Control.new()
	forge_overlay.name = "ForgeOverlay"
	forge_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forge_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(forge_overlay)
	_forge_overlay = forge_overlay

	# 锻造背景遮罩；使用半透明黑色突出环形牺牲槽和锻造预览。
	var forge_dim: ColorRect = ColorRect.new()
	forge_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 全局遮罩补充；实际颜色由样式指南统一管理。
	forge_dim.color = UI_STYLE_GUIDE.OVERLAY_DIM_COLOR
	forge_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	forge_overlay.add_child(forge_dim)

	# 锻造面板；居中显示并由独立组件维护材料引用、动画与原子结算。
	var forge_panel: Control = FORGE_PANEL_SCRIPT.new() as Control
	if forge_panel == null:
		forge_overlay.visible = false
		return
	forge_panel.anchor_left = 0.5
	forge_panel.anchor_top = 0.5
	forge_panel.anchor_right = 0.5
	forge_panel.anchor_bottom = 0.5
	forge_panel.offset_left = -480.0
	forge_panel.offset_top = -325.0
	forge_panel.offset_right = 480.0
	forge_panel.offset_bottom = 325.0
	forge_panel.connect("closed", Callable(self, "_on_forge_closed"))
	forge_overlay.add_child(forge_panel)
	_forge_panel = forge_panel
	forge_overlay.visible = false


func _build_stock_market_overlay() -> void:
	if _stock_market_overlay != null:
		return
	# 股市遮罩；覆盖完整主菜单并拦截输入，关闭时只隐藏界面而不停止后台行情服务。
	var stock_market_overlay: Control = Control.new()
	stock_market_overlay.name = "StockMarketOverlay"
	stock_market_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stock_market_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(stock_market_overlay)
	_stock_market_overlay = stock_market_overlay
	# 股市背景遮罩；透明度与商店、仓库保持一致，使行情面板成为清晰的局外焦点。
	var stock_market_dim: ColorRect = ColorRect.new()
	stock_market_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stock_market_dim.color = UI_STYLE_GUIDE.OVERLAY_DIM_COLOR
	stock_market_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	stock_market_overlay.add_child(stock_market_dim)
	# 股市面板；固定 1040×620 像素并由独立组件处理行情展示与交易确认。
	var stock_market_panel: Control = STOCK_MARKET_PANEL_SCRIPT.new() as Control
	if stock_market_panel == null:
		stock_market_overlay.visible = false
		return
	stock_market_panel.anchor_left = 0.5
	stock_market_panel.anchor_top = 0.5
	stock_market_panel.anchor_right = 0.5
	stock_market_panel.anchor_bottom = 0.5
	stock_market_panel.offset_left = -520.0
	stock_market_panel.offset_top = -310.0
	stock_market_panel.offset_right = 520.0
	stock_market_panel.offset_bottom = 310.0
	stock_market_panel.connect("closed", Callable(self, "_on_stock_market_closed"))
	stock_market_overlay.add_child(stock_market_panel)
	_stock_market_panel = stock_market_panel
	stock_market_overlay.visible = false
	stock_market_panel.call("set_market_display_active", false)


func _build_mining_farm_overlay() -> void:
	if _mining_farm_overlay != null:
		return
	# 矿场遮罩；覆盖完整主菜单并拦截输入，关闭面板后整体停止渲染与动效。
	var mining_farm_overlay: Control = Control.new()
	mining_farm_overlay.name = "MiningFarmOverlay"
	mining_farm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mining_farm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mining_farm_overlay)
	_mining_farm_overlay = mining_farm_overlay
	# 矿场背景遮罩；使用与股市一致的深色透明度，使两个局外资产系统视觉并列。
	var mining_farm_dim: ColorRect = ColorRect.new()
	mining_farm_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mining_farm_dim.color = UI_STYLE_GUIDE.OVERLAY_DIM_COLOR
	mining_farm_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	mining_farm_overlay.add_child(mining_farm_dim)
	# 矿场面板；固定 1080×640 像素并由独立组件维护卡片、交易与动画。
	var mining_farm_panel: Control = MINING_FARM_PANEL_SCRIPT.new() as Control
	if mining_farm_panel == null:
		mining_farm_overlay.visible = false
		return
	mining_farm_panel.anchor_left = 0.5
	mining_farm_panel.anchor_top = 0.5
	mining_farm_panel.anchor_right = 0.5
	mining_farm_panel.anchor_bottom = 0.5
	mining_farm_panel.offset_left = -540.0
	mining_farm_panel.offset_top = -320.0
	mining_farm_panel.offset_right = 540.0
	mining_farm_panel.offset_bottom = 320.0
	mining_farm_panel.connect("closed", Callable(self, "_on_mining_farm_closed"))
	mining_farm_overlay.add_child(mining_farm_panel)
	_mining_farm_panel = mining_farm_panel
	mining_farm_overlay.visible = false


func _build_encyclopedia_overlay() -> void:
	if _encyclopedia_overlay != null:
		return
	# 图鉴遮罩；覆盖完整主菜单并拦截输入，隐藏时不保留任何主菜单交互焦点。
	var encyclopedia_overlay: Control = Control.new()
	encyclopedia_overlay.name = "EncyclopediaOverlay"
	encyclopedia_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encyclopedia_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(encyclopedia_overlay)
	_encyclopedia_overlay = encyclopedia_overlay
	# 图鉴背景遮罩；使用与仓库、商店和矿场一致的深蓝黑透明层突出收集信息。
	var encyclopedia_dim: ColorRect = ColorRect.new()
	encyclopedia_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encyclopedia_dim.color = UI_STYLE_GUIDE.OVERLAY_DIM_COLOR
	encyclopedia_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	encyclopedia_overlay.add_child(encyclopedia_dim)
	# 图鉴面板；固定 1000×640 像素，四列条目网格在该尺寸下保留名称与说明的可读空间。
	var encyclopedia_panel: Control = ENCYCLOPEDIA_PANEL_SCRIPT.new() as Control
	if encyclopedia_panel == null:
		encyclopedia_overlay.visible = false
		return
	encyclopedia_panel.name = "EncyclopediaPanel"
	encyclopedia_panel.anchor_left = 0.5
	encyclopedia_panel.anchor_top = 0.5
	encyclopedia_panel.anchor_right = 0.5
	encyclopedia_panel.anchor_bottom = 0.5
	encyclopedia_panel.offset_left = -500.0
	encyclopedia_panel.offset_top = -320.0
	encyclopedia_panel.offset_right = 500.0
	encyclopedia_panel.offset_bottom = 320.0
	encyclopedia_panel.connect("closed", Callable(self, "_on_encyclopedia_closed"))
	encyclopedia_overlay.add_child(encyclopedia_panel)
	_encyclopedia_panel = encyclopedia_panel
	encyclopedia_overlay.visible = false


func _build_developer_overlay() -> void:
	if _developer_overlay != null:
		return
	# 开发者遮罩；覆盖完整主菜单并拦截鼠标输入，默认保持隐藏。
	var developer_overlay: Control = Control.new()
	developer_overlay.name = "DeveloperOverlay"
	developer_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	developer_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(developer_overlay)
	_developer_overlay = developer_overlay
	# 开发者背景遮罩；使用深色半透明背景突出隐藏调试菜单。
	var developer_dim: ColorRect = ColorRect.new()
	developer_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	developer_dim.color = UI_STYLE_GUIDE.OVERLAY_DIM_COLOR
	developer_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	developer_overlay.add_child(developer_dim)
	# 开发者菜单面板；居中显示资源与星穹快捷操作。
	var developer_menu: Control = DEVELOPER_MENU_SCRIPT.new() as Control
	developer_menu.anchor_left = 0.5
	developer_menu.anchor_top = 0.5
	developer_menu.anchor_right = 0.5
	developer_menu.anchor_bottom = 0.5
	developer_menu.offset_left = -260.0
	developer_menu.offset_top = -285.0
	developer_menu.offset_right = 260.0
	developer_menu.offset_bottom = 285.0
	developer_menu.connect("closed", Callable(self, "_on_developer_menu_closed"))
	developer_overlay.add_child(developer_menu)
	_developer_menu = developer_menu
	developer_overlay.visible = false


func _open_developer_menu() -> void:
	if _developer_overlay == null:
		return
	_settings_panel.visible = false
	if _warehouse_overlay != null:
		_warehouse_overlay.visible = false
	if _shop_overlay != null:
		_shop_overlay.visible = false
	if _forge_overlay != null:
		_forge_overlay.visible = false
	if _stock_market_overlay != null:
		_stock_market_overlay.visible = false
	if _stock_market_panel != null and _stock_market_panel.has_method("set_market_display_active"):
		_stock_market_panel.call("set_market_display_active", false)
	if _mining_farm_overlay != null:
		_mining_farm_overlay.visible = false
	if _mining_farm_panel != null and _mining_farm_panel.has_method("_close_panel"):
		_mining_farm_panel.call("_close_panel")
	if _encyclopedia_overlay != null:
		_encyclopedia_overlay.visible = false
	_developer_overlay.visible = true


func _on_developer_menu_closed() -> void:
	if _developer_overlay != null:
		_developer_overlay.visible = false
	_start_button.grab_focus()


func _on_warehouse_closed() -> void:
	if _warehouse_overlay != null:
		_warehouse_overlay.visible = false
	_warehouse_button.grab_focus()


func _on_backpack_closed() -> void:
	if _backpack_overlay != null:
		_backpack_overlay.visible = false
	_backpack_button.grab_focus()


func _on_shop_closed() -> void:
	if _shop_overlay != null:
		_shop_overlay.visible = false
	_shop_button.grab_focus()


func _on_forge_closed() -> void:
	if _forge_overlay != null:
		_forge_overlay.visible = false
	_forge_button.grab_focus()


func _on_stock_market_closed() -> void:
	if _stock_market_overlay != null:
		_stock_market_overlay.visible = false
	if _stock_market_panel != null and _stock_market_panel.has_method("set_market_display_active"):
		_stock_market_panel.call("set_market_display_active", false)
	_stock_market_button.grab_focus()


func _on_mining_farm_closed() -> void:
	if _mining_farm_overlay != null:
		_mining_farm_overlay.visible = false
	_mining_farm_button.grab_focus()


func _on_encyclopedia_closed() -> void:
	if _encyclopedia_overlay != null:
		_encyclopedia_overlay.visible = false
	_encyclopedia_button.grab_focus()


func _on_master_volume_slider_value_changed(value: float) -> void:
	_apply_master_volume(value)


func _on_settings_back_button_pressed() -> void:
	if _is_key_binding_page_visible():
		_show_key_binding_page(false)
		return

	_settings_panel.visible = false
	_settings_button.grab_focus()


func _start_game(game_mode: String) -> void:
	## 写入本次模式并直接进入战斗；角色由独立角色系统最后确认的 SessionState 选择提供。
	_settings_panel.visible = false
	_set_session_game_mode(game_mode)
	_change_scene_with_transition(game_scene_path)


func _change_scene_with_transition(scene_path: String) -> void:
	# 全局转场服务；默认由 AutoLoad 提供，缺失时回退引擎直接切换以保留场景独立运行能力。
	var scene_transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_to_file"):
		scene_transition.call("change_scene_to_file", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _set_session_game_mode(game_mode: String) -> void:
	# 会话状态节点；默认由 project.godot 自动加载，缺失时直接跳过配置以保留场景兜底能力。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null:
		return

	if session_state.has_method("set_game_mode"):
		session_state.call("set_game_mode", game_mode)
	elif session_state.has_method("configure"):
		session_state.call("configure", game_mode, str(session_state.get("selected_character_id")))


func _sync_master_volume_slider() -> void:
	if _master_bus_index < 0:
		return

	# 当前 Master 音量线性值；取值为 0 到 1，默认由 AudioServer 读取，修改会影响设置滑条初始位置。
	var linear_volume: float = 0.0 if AudioServer.is_bus_mute(_master_bus_index) else db_to_linear(AudioServer.get_bus_volume_db(_master_bus_index))
	_master_volume_slider.set_value_no_signal(clampf(linear_volume, 0.0, 1.0) * 100.0)
	_refresh_master_volume_label(_master_volume_slider.value)


func _apply_master_volume(value: float) -> void:
	if _master_bus_index < 0:
		return

	# 标准化音量值；取值为 0 到 1，默认由滑条百分比换算，修改会影响最终写入 AudioServer 的音量。
	var linear_volume: float = clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(_master_bus_index, linear_volume <= 0.001)
	if linear_volume > 0.001:
		AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(linear_volume))

	_refresh_master_volume_label(value)


func _refresh_master_volume_label(value: float) -> void:
	_master_volume_value_label.text = "%d%%" % roundi(value)


func _build_key_binding_navigation() -> void:
	if _settings_content == null:
		return

	if _key_binding_page != null:
		return

	# 按键绑定入口按钮；取值为 Button，默认放在设置首页用于进入独立按键绑定页面。
	var key_binding_button: Button = Button.new()
	key_binding_button.name = "KeyBindingPageButton"
	key_binding_button.custom_minimum_size = Vector2(0.0, 42.0)
	key_binding_button.text = "按键绑定"
	key_binding_button.pressed.connect(_on_key_binding_button_pressed)
	_settings_content.add_child(key_binding_button)
	_settings_content.move_child(key_binding_button, maxi(_settings_content.get_child_count() - 3, 0))
	_key_binding_button = key_binding_button
	# 存档传输控件；主菜单导出可覆盖全部已经落盘的永久状态，导入由服务自动备份旧文件。
	var save_transfer_control: Control = SAVE_TRANSFER_CONTROL_SCRIPT.new() as Control
	if save_transfer_control != null:
		save_transfer_control.name = "MainMenuSaveTransferControl"
		_settings_content.add_child(save_transfer_control)
		_settings_content.move_child(save_transfer_control, maxi(_settings_content.get_child_count() - 3, 0))
		_save_transfer_control = save_transfer_control
	_settings_home_controls = [
		_settings_title_label,
		_master_volume_row,
		_key_binding_button,
		_save_transfer_control,
		_settings_spacer,
		_settings_back_button,
	]

	# 按键绑定页面；取值为 VBoxContainer，默认隐藏并在点击入口按钮时显示。
	var key_binding_page: VBoxContainer = VBoxContainer.new()
	key_binding_page.name = "KeyBindingPage"
	key_binding_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	key_binding_page.add_theme_constant_override("separation", 10)
	_settings_content.add_child(key_binding_page)
	_key_binding_page = key_binding_page

	# 按键绑定面板；取值为 KeyBindingPanel 实例，默认只在按键绑定页面内显示。
	var key_binding_panel: Control = KEY_BINDING_PANEL_SCRIPT.new() as Control
	if key_binding_panel == null:
		return

	key_binding_panel.name = "MainMenuKeyBindingPanel"
	key_binding_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_key_binding_page.add_child(key_binding_panel)
	_key_binding_panel = key_binding_panel

	# 按键绑定返回按钮；取值为 Button，默认从按键绑定页面回到设置首页。
	var key_binding_back_button: Button = Button.new()
	key_binding_back_button.name = "KeyBindingBackButton"
	key_binding_back_button.custom_minimum_size = Vector2(0.0, 42.0)
	key_binding_back_button.text = "返回"
	key_binding_back_button.pressed.connect(_on_key_binding_back_button_pressed)
	_key_binding_page.add_child(key_binding_back_button)
	_key_binding_back_button = key_binding_back_button


func _show_key_binding_page(visible: bool) -> void:
	# 首页控件遍历项；取值为设置首页的直接控件，默认与按键绑定页面互斥显示。
	for home_control in _settings_home_controls:
		if home_control != null:
			home_control.visible = not visible

	if _key_binding_page != null:
		_key_binding_page.visible = visible

	if visible and _key_binding_back_button != null:
		_key_binding_back_button.grab_focus()
	elif _settings_back_button != null:
		_settings_back_button.grab_focus()


func _is_key_binding_page_visible() -> bool:
	return _key_binding_page != null and _key_binding_page.visible


func _on_key_binding_button_pressed() -> void:
	_show_key_binding_page(true)


func _on_key_binding_back_button_pressed() -> void:
	_show_key_binding_page(false)
