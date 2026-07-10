extends Control

## 主菜单负责项目启动后的第一个可交互界面。
## 这里保留骇入、训练场、设置和退出四条清晰路径，避免把游戏流程逻辑写进具体按钮。
## character_select_scene_path 暴露在检查器中，后续替换角色选择入口时无需修改脚本。

## 正式骇入模式标识；默认写入 SessionState，修改会影响骇入入口进入后的模式判定。
const GAME_MODE_HACK: String = "hack"
## 训练场模式标识；默认写入 SessionState，修改会影响训练场入口进入后的模式判定。
const GAME_MODE_TRAINING: String = "training"
## 按键绑定面板脚本；默认用于主菜单设置中动态创建可重绑定操作列表。
const KEY_BINDING_PANEL_SCRIPT: Script = preload("res://scripts/ui/key_binding_panel.gd")
## 局外仓库面板脚本；默认在主菜单点击仓库按钮后动态创建并读取全局背包服务。
const WAREHOUSE_PANEL_SCRIPT: Script = preload("res://scripts/ui/warehouse_panel.gd")
## 角色选择场景路径；默认进入独立角色选择场景，只允许填写 tscn 资源，运行时通常不动态修改，改错会导致入口无法继续。
@export_file("*.tscn") var character_select_scene_path: String = "res://scenes/ui/character_select.tscn"

## 骇入按钮缓存；默认绑定唯一名 StartButton，必须是 Button，修改节点名会导致正式入口无法进入角色选择。
@onready var _start_button: Button = %StartButton
## 训练场按钮缓存；默认绑定唯一名 TrainingButton，必须是 Button，修改节点名会导致训练场入口无法进入角色选择。
@onready var _training_button: Button = %TrainingButton
## 设置按钮缓存；默认绑定唯一名 SettingsButton，必须是 Button，修改节点名会导致主菜单无法打开设置。
@onready var _settings_button: Button = %SettingsButton
## 退出按钮缓存；默认绑定唯一名 QuitButton，必须是 Button，修改节点名会导致主菜单无法退出程序。
@onready var _quit_button: Button = %QuitButton
## 仓库按钮缓存；默认固定在主菜单左下角，点击后打开全局背包与装备调整界面。
@onready var _warehouse_button: Button = %WarehouseButton
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
## 仓库全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他按钮接收鼠标输入。
var _warehouse_overlay: Control
## 仓库面板实例；默认由 WarehousePanel 脚本创建，关闭后复用而不重复构建服务数据。
var _warehouse_panel: Control


func _ready() -> void:
	_master_bus_index = AudioServer.get_bus_index("Master")
	_start_button.pressed.connect(_on_start_button_pressed)
	_training_button.pressed.connect(_on_training_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_warehouse_button.pressed.connect(_on_warehouse_button_pressed)
	_master_volume_slider.value_changed.connect(_on_master_volume_slider_value_changed)
	_settings_back_button.pressed.connect(_on_settings_back_button_pressed)
	_build_key_binding_navigation()
	_build_warehouse_overlay()
	_settings_panel.visible = false
	_show_key_binding_page(false)
	_sync_master_volume_slider()
	_start_button.grab_focus()


func _on_start_button_pressed() -> void:
	_open_character_select(GAME_MODE_HACK)


func _on_training_button_pressed() -> void:
	_open_character_select(GAME_MODE_TRAINING)


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
	warehouse_dim.color = Color(0.0, 0.0, 0.0, 0.62)
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


func _on_warehouse_closed() -> void:
	if _warehouse_overlay != null:
		_warehouse_overlay.visible = false
	_warehouse_button.grab_focus()


func _on_master_volume_slider_value_changed(value: float) -> void:
	_apply_master_volume(value)


func _on_settings_back_button_pressed() -> void:
	if _is_key_binding_page_visible():
		_show_key_binding_page(false)
		return

	_settings_panel.visible = false
	_settings_button.grab_focus()


func _open_character_select(game_mode: String) -> void:
	_settings_panel.visible = false
	_set_session_game_mode(game_mode)
	get_tree().change_scene_to_file(character_select_scene_path)


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
	_settings_home_controls = [
		_settings_title_label,
		_master_volume_row,
		_key_binding_button,
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
