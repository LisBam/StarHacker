extends CanvasLayer
class_name CombatHud

## 战斗 HUD 显示玩家生命、能量、底部武器栏和可开关背包。
## HUD 只负责界面呈现、拖拽投放和输入转发，背包与装备数据仍由独立组件维护。
## 武器槽的冷却覆盖由攻击组件的冷却比例驱动，近战和远程使用同一套白色遮罩表现。

## 可拖拽武器槽控件脚本；默认预加载本项目 UI 控件，修改会影响所有装备槽和背包槽的生成方式。
const WEAPON_SLOT_CONTROL_SCRIPT: Script = preload("res://scripts/ui/weapon_slot_control.gd")
## 背包全部分页标识；默认显示所有背包武器，修改会影响筛选按钮与背包网格过滤。
const INVENTORY_FILTER_ALL: String = "all"
## 背包远程分页标识；默认匹配武器资源 weapon_type 的 ranged 值，修改会影响远程筛选页。
const INVENTORY_FILTER_RANGED: String = "ranged"
## 背包近战分页标识；默认匹配武器资源 weapon_type 的 melee 值，修改会影响近战筛选页。
const INVENTORY_FILTER_MELEE: String = "melee"
## 星角色标识；默认与 SessionState 和 GameWorld 保持一致，修改会影响训练场切换角色目标。
const CHARACTER_STELLE: String = "stelle"
## 穹角色标识；默认与 SessionState 和 GameWorld 保持一致，修改会影响训练场切换角色目标。
const CHARACTER_CAEULUS: String = "caelus"
## 银狼角色标识；默认与 SessionState 和 GameWorld 保持一致，修改会影响训练场切换角色目标。
const CHARACTER_SILVER_WOLF: String = "silver_wolf"

## 玩家节点路径；默认指向同一游戏世界下的 Player，必须解析到玩家根节点，运行时通常不修改。
@export var player_path: NodePath = ^"../Player"
## 游戏世界节点路径；默认指向 HUD 父节点 GameWorld，必须解析到提供训练场测试接口的节点。
@export var game_world_path: NodePath = ^".."
## 背包开关输入动作名；默认 toggle_inventory 对应 E 键，运行时通常不修改，改名会影响背包打开/关闭。
@export var toggle_inventory_action: StringName = &"toggle_inventory"
## 暂停输入动作名；默认 pause_game 对应 ESC，运行时通常不修改，改名会影响暂停菜单打开方式。
@export var pause_action: StringName = &"pause_game"
## 大地图开关输入动作名；默认 toggle_large_map 对应 M 键，运行时通常不修改，改名会影响大地图打开方式。
@export var toggle_large_map_action: StringName = &"toggle_large_map"
## 主菜单场景路径；默认返回项目主菜单，必须填写 tscn 资源，运行时通常不修改，改错会导致暂停菜单返回失败。
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
## 远程装备槽最小尺寸；默认 80x54 适合底部低遮挡显示，运行时通常不修改，扩展槽数量时可调小。
@export var ranged_slot_minimum_size: Vector2 = Vector2(80.0, 54.0)
## 近战装备槽最小尺寸；默认 80x54 与远程槽一致，运行时通常不修改，修改会影响底部装备栏对齐。
@export var melee_slot_minimum_size: Vector2 = Vector2(80.0, 54.0)
## 背包物品槽最小尺寸；默认 112x72 适合网格展示，运行时通常不修改，修改会影响背包容量视觉密度。
@export var inventory_slot_minimum_size: Vector2 = Vector2(112.0, 72.0)

## 玩家节点缓存；默认按 player_path 获取，允许为空但 HUD 不会显示有效状态，修改会影响所有组件绑定。
var _player: Node
## 游戏世界节点缓存；默认按 game_world_path 获取，允许为空但训练场设置无法清怪或重刷怪物。
var _game_world: Node
## 战斗属性组件缓存；默认从玩家子节点 StatsComponent 获取，允许为空但生命和能量无法刷新。
var _stats_component: Node
## 装备组件缓存；默认从玩家子节点 EquipmentComponent 获取，允许为空但装备栏无法刷新。
var _equipment_component: Node
## 背包组件缓存；默认从玩家子节点 InventoryComponent 获取，允许为空但背包网格无法刷新。
var _inventory_component: Node
## 输入组件缓存；默认从玩家子节点 InputComponent 获取，允许为空但背包打开时无法主动锁定战斗输入。
var _input_component: Node
## 远程攻击组件缓存；默认从玩家子节点 RangedAttackComponent 获取，允许为空但远程槽无法显示冷却覆盖。
var _ranged_attack_component: Node
## 近战攻击组件缓存；默认从玩家子节点 MeleeAttackComponent 获取，允许为空但近战槽无法显示冷却覆盖。
var _melee_attack_component: Node
## 远程槽控件缓存；元素为 WeaponSlotControl 实例，默认按装备槽数量动态创建，修改会影响 HUD 刷新目标。
var _ranged_slot_controls: Array = []
## 近战槽控件缓存；取值为 WeaponSlotControl 或 null，默认动态创建，修改会影响近战装备显示目标。
var _melee_slot_control: Control
## 背包槽控件缓存；元素为 WeaponSlotControl 实例，默认按背包物品动态创建，修改会影响背包刷新目标。
var _inventory_slot_controls: Array = []
## 背包左侧远程装备槽控件缓存；元素为 WeaponSlotControl 实例，默认按装备槽数量动态创建，修改会影响背包内装备显示。
var _inventory_equipment_ranged_controls: Array = []
## 背包左侧近战装备槽控件缓存；取值为 WeaponSlotControl 或 null，默认动态创建，修改会影响背包内近战显示。
var _inventory_equipment_melee_control: Control
## 最近触发冷却的远程槽索引；取值为 -1 或有效远程槽，默认 -1 表示无远程冷却显示目标，修改会影响远程 CD 遮罩位置。
var _last_cooling_ranged_slot: int = -1
## 背包当前筛选页；取值为 all、ranged 或 melee，默认 all 显示全部武器，修改会影响右侧背包网格内容。
var _inventory_filter: String = INVENTORY_FILTER_ALL
## Master 音频总线索引；取值为 -1 或有效总线下标，默认 -1 表示尚未解析，修改会影响暂停设置音量应用目标。
var _master_bus_index: int = -1
## 当前是否为训练场模式；取值为 true/false，默认 false，修改会影响训练场设置按钮和角色切换入口是否可见。
var _is_training_mode: bool = false

## 角色名称文本缓存；默认绑定 CharacterNameLabel，显示当前选择角色名称，节点缺失会导致 HUD 无法展示角色名。
@onready var _character_name_label: Label = %CharacterNameLabel
## 生命文本缓存；默认绑定 HealthLabel，显示当前生命和最大生命，节点缺失会导致生命文本无法刷新。
@onready var _health_label: Label = %HealthLabel
## 生命条缓存；默认绑定 HealthBar，显示当前生命比例，节点缺失会导致生命条无法刷新。
@onready var _health_bar: ProgressBar = %HealthBar
## 能量文本缓存；默认绑定 EnergyLabel，显示当前能量和最大能量，节点缺失会导致能量文本无法刷新。
@onready var _energy_label: Label = %EnergyLabel
## 能量条缓存；默认绑定 EnergyBar，显示当前能量比例，节点缺失会导致能量条无法刷新。
@onready var _energy_bar: ProgressBar = %EnergyBar
## 远程装备槽容器缓存；默认绑定 RangedSlots，动态创建远程槽控件，节点缺失会导致远程装备栏无法显示。
@onready var _ranged_slots_container: HBoxContainer = %RangedSlots
## 近战装备槽容器缓存；默认绑定 MeleeSlotHost，动态创建近战槽控件，节点缺失会导致近战装备栏无法显示。
@onready var _melee_slot_host: HBoxContainer = %MeleeSlotHost
## 背包面板缓存；默认绑定 InventoryPanel，E 键切换显示，节点缺失会导致背包无法打开。
@onready var _inventory_panel: Control = %InventoryPanel
## 背包标题文本缓存；默认绑定 InventoryTitleLabel，显示背包数量和操作提示，节点缺失会导致背包标题无法刷新。
@onready var _inventory_title_label: Label = %InventoryTitleLabel
## 背包左侧远程装备槽容器缓存；默认绑定 InventoryEquipmentRangedSlots，动态创建当前远程装备槽。
@onready var _inventory_equipment_ranged_container: VBoxContainer = %InventoryEquipmentRangedSlots
## 背包左侧近战装备槽容器缓存；默认绑定 InventoryEquipmentMeleeSlotHost，动态创建当前近战装备槽。
@onready var _inventory_equipment_melee_host: VBoxContainer = %InventoryEquipmentMeleeSlotHost
## 背包右侧武器网格缓存；默认绑定 InventoryWeaponGrid，动态创建背包武器物品槽，节点缺失会导致背包物品无法显示。
@onready var _inventory_weapon_grid: GridContainer = %InventoryWeaponGrid
## 背包空白投放区域缓存；默认绑定 InventoryScroll，拖拽到空白处时把武器放入背包末尾。
@onready var _inventory_drop_area: Node = %InventoryScroll
## 背包全部筛选按钮缓存；默认绑定 InventoryFilterAllButton，点击后显示全部武器。
@onready var _inventory_filter_all_button: Button = %InventoryFilterAllButton
## 背包近战筛选按钮缓存；默认绑定 InventoryFilterMeleeButton，点击后只显示近战武器。
@onready var _inventory_filter_melee_button: Button = %InventoryFilterMeleeButton
## 背包远程筛选按钮缓存；默认绑定 InventoryFilterRangedButton，点击后只显示远程武器。
@onready var _inventory_filter_ranged_button: Button = %InventoryFilterRangedButton
## 暂停菜单遮罩缓存；默认绑定 PauseOverlay，ESC 切换显示，显示时暂停场景树。
@onready var _pause_overlay: Control = %PauseOverlay
## 暂停主菜单面板缓存；默认绑定 PauseMenuPanel，显示继续、设置和返回主菜单按钮。
@onready var _pause_menu_panel: Control = %PauseMenuPanel
## 暂停设置面板缓存；默认绑定 PauseSettingsPanel，显示主音量设置。
@onready var _pause_settings_panel: Control = %PauseSettingsPanel
## 继续游戏按钮缓存；默认绑定 ResumeButton，点击后恢复场景树运行。
@onready var _resume_button: Button = %ResumeButton
## 暂停设置按钮缓存；默认绑定 PauseSettingsButton，点击后打开暂停设置面板。
@onready var _pause_settings_button: Button = %PauseSettingsButton
## 训练场设置按钮缓存；默认绑定 TestSettingsButton，点击后打开训练场设置面板。
@onready var _test_settings_button: Button = %TestSettingsButton
## 返回主菜单按钮缓存；默认绑定 ReturnMainMenuButton，点击后解除暂停并切换到主菜单。
@onready var _return_main_menu_button: Button = %ReturnMainMenuButton
## 训练场设置面板缓存；默认绑定 TestSettingsPanel，显示清怪、重刷和无限属性开关。
@onready var _test_settings_panel: Control = %TestSettingsPanel
## 清空怪物按钮缓存；默认绑定 ClearMonstersButton，点击后清空训练场怪物。
@onready var _clear_monsters_button: Button = %ClearMonstersButton
## 重新生成怪物按钮缓存；默认绑定 RespawnMonstersButton，点击后按当前训练场配置追加一批怪物。
@onready var _respawn_monsters_button: Button = %RespawnMonstersButton
## 切换角色按钮缓存；默认绑定 SwitchCharacterButton，仅训练场显示，点击后打开角色切换面板。
@onready var _switch_character_button: Button = %SwitchCharacterButton
## 无限能量开关缓存；默认绑定 InfiniteEnergyCheckButton，切换后修改玩家属性组件的无限能量状态。
@onready var _infinite_energy_check_button: CheckButton = %InfiniteEnergyCheckButton
## 无限血量开关缓存；默认绑定 InfiniteHealthCheckButton，切换后修改玩家属性组件的无限血量状态。
@onready var _infinite_health_check_button: CheckButton = %InfiniteHealthCheckButton
## 训练场设置返回按钮缓存；默认绑定 TestSettingsBackButton，点击后返回暂停主菜单。
@onready var _test_settings_back_button: Button = %TestSettingsBackButton
## 训练场角色切换面板缓存；默认绑定 CharacterSwitchPanel，只在训练场设置中打开。
@onready var _character_switch_panel: Control = %CharacterSwitchPanel
## 训练场星角色按钮缓存；默认绑定 SwitchCharacterStelleButton，点击后切换为星并刷新占位属性。
@onready var _switch_character_stelle_button: Button = %SwitchCharacterStelleButton
## 训练场穹角色按钮缓存；默认绑定 SwitchCharacterCaelusButton，点击后切换为穹并刷新占位属性。
@onready var _switch_character_caelus_button: Button = %SwitchCharacterCaelusButton
## 训练场银狼角色按钮缓存；默认绑定 SwitchCharacterSilverWolfButton，点击后切换为银狼并刷新占位属性。
@onready var _switch_character_silver_wolf_button: Button = %SwitchCharacterSilverWolfButton
## 训练场角色切换返回按钮缓存；默认绑定 CharacterSwitchBackButton，点击后回到训练场设置面板。
@onready var _character_switch_back_button: Button = %CharacterSwitchBackButton
## 暂停设置主音量滑条缓存；默认绑定 PauseMasterVolumeSlider，取值 0 到 100，修改会影响全局 Master 音量。
@onready var _pause_master_volume_slider: HSlider = %PauseMasterVolumeSlider
## 暂停设置主音量数值文本缓存；默认绑定 PauseMasterVolumeValueLabel，显示滑条当前百分比。
@onready var _pause_master_volume_value_label: Label = %PauseMasterVolumeValueLabel
## 暂停设置返回按钮缓存；默认绑定 PauseSettingsBackButton，点击后返回暂停主菜单。
@onready var _pause_settings_back_button: Button = %PauseSettingsBackButton
## 大地图遮罩缓存；默认绑定 LargeMapOverlay，M 键切换显示，显示时锁定战斗输入。
@onready var _large_map_overlay: Control = %LargeMapOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_master_bus_index = AudioServer.get_bus_index("Master")
	_bind_game_world()
	_bind_player_components()
	_bind_inventory_filter_buttons()
	_bind_inventory_drop_area()
	_bind_pause_menu()
	_refresh_all()
	_set_inventory_visible(false)
	_set_large_map_visible(false)
	_set_pause_menu_visible(false)


func _process(_delta: float) -> void:
	_refresh_cooldown_overlays()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		# 当前键盘事件；取值来自输入系统，默认用于识别 E 键和背包动作，修改会影响背包开关响应。
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and _is_pause_event(key_event):
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()
			return

		if _pause_overlay.visible:
			return

		if key_event.pressed and not key_event.echo and _is_toggle_inventory_event(key_event):
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return

		if key_event.pressed and not key_event.echo and _is_toggle_large_map_event(key_event):
			_toggle_large_map()
			get_viewport().set_input_as_handled()


func _bind_game_world() -> void:
	_game_world = get_node_or_null(game_world_path)
	_is_training_mode = _resolve_training_mode()


func _bind_player_components() -> void:
	_player = get_node_or_null(player_path)
	if _player == null:
		return

	_stats_component = _player.get_node_or_null("StatsComponent")
	_equipment_component = _player.get_node_or_null("EquipmentComponent")
	_inventory_component = _player.get_node_or_null("InventoryComponent")
	_input_component = _player.get_node_or_null("InputComponent")
	_ranged_attack_component = _player.get_node_or_null("RangedAttackComponent")
	_melee_attack_component = _player.get_node_or_null("MeleeAttackComponent")

	if _stats_component != null:
		_stats_component.connect("health_changed", Callable(self, "_on_health_changed"))
		_stats_component.connect("energy_changed", Callable(self, "_on_energy_changed"))

	if _equipment_component != null:
		_equipment_component.connect("equipment_changed", Callable(self, "_on_equipment_changed"))

	if _inventory_component != null:
		_inventory_component.connect("inventory_changed", Callable(self, "_on_inventory_changed"))

	if _ranged_attack_component != null:
		_ranged_attack_component.connect("fired", Callable(self, "_on_ranged_weapon_fired"))


func _refresh_all() -> void:
	_refresh_stats()
	_rebuild_equipment_slots()
	_refresh_equipment()
	_rebuild_inventory_slots()
	_refresh_cooldown_overlays()


func _refresh_stats() -> void:
	_character_name_label.text = _get_current_character_display_name()
	if _stats_component == null:
		_health_label.text = "生命 -- / --"
		_energy_label.text = "能量 -- / --"
		_health_bar.value = 0.0
		_energy_bar.value = 0.0
		return

	# 当前生命值；取值来自属性组件，默认 0 用于组件缺失兜底，修改会影响生命文本和进度条。
	var current_health: float = float(_stats_component.get("current_health"))
	# 最大生命值；取值来自属性组件，默认 1 防止除零，修改会影响生命文本和进度条上限。
	var max_health: float = maxf(float(_stats_component.get("max_health")), 1.0)
	# 当前能量值；取值来自属性组件，默认 0 用于组件缺失兜底，修改会影响能量文本和进度条。
	var current_energy: float = float(_stats_component.get("current_energy"))
	# 最大能量值；取值来自属性组件，默认 1 防止除零，修改会影响能量文本和进度条上限。
	var max_energy: float = maxf(float(_stats_component.get("max_energy")), 1.0)

	_health_label.text = "生命 %d / %d" % [roundi(current_health), roundi(max_health)]
	_health_bar.value = current_health / max_health * 100.0
	_energy_label.text = "能量 %d / %d" % [roundi(current_energy), roundi(max_energy)]
	_energy_bar.value = current_energy / max_energy * 100.0


func _rebuild_equipment_slots() -> void:
	_clear_container(_ranged_slots_container)
	_clear_container(_melee_slot_host)
	_ranged_slot_controls.clear()
	_melee_slot_control = null

	if _equipment_component == null or not _equipment_component.has_method("get_ranged_slot_count"):
		return

	# 远程槽数量；取值来自装备组件，默认至少 0，修改会影响 HUD 创建的远程槽数量。
	var slot_count: int = int(_equipment_component.call("get_ranged_slot_count"))

	# 远程槽 UI 创建索引；取值为 0 到 slot_count - 1，默认逐槽生成，修改循环范围会影响装备栏显示数量。
	for slot_index in range(slot_count):
		# 远程槽控件；取值为 WeaponSlotControl 实例，默认动态创建，修改会影响远程槽显示与拖拽行为。
		var slot_control: Control = _create_weapon_slot_control(ranged_slot_minimum_size)
		_ranged_slots_container.add_child(slot_control)
		_ranged_slot_controls.append(slot_control)

	# 近战槽控件；取值为 WeaponSlotControl 实例，默认单槽创建，修改会影响近战槽显示与拖拽行为。
	var melee_slot_control: Control = _create_weapon_slot_control(melee_slot_minimum_size)
	_melee_slot_host.add_child(melee_slot_control)
	_melee_slot_control = melee_slot_control


func _refresh_equipment() -> void:
	if _equipment_component == null:
		return

	# 当前远程槽索引；取值来自装备组件，默认 0，修改会影响底部远程槽选中高亮。
	var current_slot: int = int(_equipment_component.call("get_current_ranged_slot"))

	# 远程槽刷新索引；取值为控件数组下标，默认逐个刷新，修改循环范围会影响装备栏文本和拖拽源。
	for slot_index in range(_ranged_slot_controls.size()):
		# 当前槽武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响当前槽显示内容。
		var ranged_weapon: Resource = _equipment_component.call("get_ranged_weapon", slot_index) as Resource
		_ranged_slot_controls[slot_index].call("set_slot_data", "equipment", "ranged", slot_index, ranged_weapon, slot_index == current_slot)
		_ranged_slot_controls[slot_index].call("set_empty_text", "空远程")

	if _melee_slot_control != null:
		# 当前近战武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响近战槽显示内容。
		var melee_weapon: Resource = _equipment_component.call("get_melee_weapon") as Resource
		_melee_slot_control.call("set_slot_data", "equipment", "melee", -1, melee_weapon, true)
		_melee_slot_control.call("set_empty_text", "空近战")


func _rebuild_inventory_slots() -> void:
	_clear_container(_inventory_equipment_ranged_container)
	_clear_container(_inventory_equipment_melee_host)
	_clear_container(_inventory_weapon_grid)
	_inventory_slot_controls.clear()
	_inventory_equipment_ranged_controls.clear()
	_inventory_equipment_melee_control = null

	_rebuild_inventory_equipment_slots()

	if _inventory_component == null or not _inventory_component.has_method("get_items"):
		_refresh_inventory_title(0, 0)
		return

	# 背包物品列表；取值来自背包组件副本，默认空数组，修改会影响背包网格显示内容。
	var items: Array = _inventory_component.call("get_items")
	# 当前筛选页可见物品数量；取值从 0 到背包物品总数，默认逐项统计，修改会影响标题数量显示。
	var visible_item_count: int = 0

	# 背包物品槽索引；取值为背包物品数组下标，默认逐个创建，修改循环范围会影响背包显示数量。
	for item_index in range(items.size()):
		# 背包物品资源；取值为 Resource 或 null，默认来自背包组件，修改会影响当前背包槽显示和拖拽内容。
		var item_data: Resource = items[item_index] as Resource
		if not _does_item_match_inventory_filter(item_data):
			continue

		visible_item_count += 1
		# 背包物品槽控件；取值为 WeaponSlotControl 实例，默认动态创建，修改会影响背包槽显示与拖拽行为。
		var inventory_slot: Control = _create_weapon_slot_control(inventory_slot_minimum_size)
		inventory_slot.call("set_slot_data", "inventory", "inventory", item_index, item_data, false)
		inventory_slot.call("set_empty_text", "空")
		_inventory_weapon_grid.add_child(inventory_slot)
		_inventory_slot_controls.append(inventory_slot)

	_refresh_inventory_title(items.size(), visible_item_count)

func _refresh_inventory_title(item_count: int, visible_item_count: int) -> void:
	# 当前筛选页中文名；取值为“全部”“近战”或“远程”，默认由 _inventory_filter 转换，修改会影响背包标题。
	var filter_label: String = _get_inventory_filter_label()
	if _inventory_filter == INVENTORY_FILTER_ALL:
		_inventory_title_label.text = "背包  E关闭  %d件武器" % item_count
	else:
		_inventory_title_label.text = "%s  E关闭  %d / %d件武器" % [filter_label, visible_item_count, item_count]


func _rebuild_inventory_equipment_slots() -> void:
	if _equipment_component == null or not _equipment_component.has_method("get_ranged_slot_count"):
		return

	# 背包界面左侧远程槽数量；取值来自装备组件，默认与底部装备栏一致，修改会影响背包装备栏显示数量。
	var slot_count: int = int(_equipment_component.call("get_ranged_slot_count"))
	# 背包界面左侧远程槽索引；取值为 0 到 slot_count - 1，默认逐槽创建，修改循环范围会影响可拖拽装备槽数量。
	for slot_index in range(slot_count):
		# 背包界面远程装备槽控件；取值为 WeaponSlotControl 实例，默认动态创建，修改会影响左侧远程装备显示。
		var slot_control: Control = _create_weapon_slot_control(inventory_slot_minimum_size)
		_inventory_equipment_ranged_container.add_child(slot_control)
		_inventory_equipment_ranged_controls.append(slot_control)

	# 背包界面近战装备槽控件；取值为 WeaponSlotControl 实例，默认单槽创建，修改会影响左侧近战装备显示。
	var melee_slot_control: Control = _create_weapon_slot_control(inventory_slot_minimum_size)
	_inventory_equipment_melee_host.add_child(melee_slot_control)
	_inventory_equipment_melee_control = melee_slot_control
	_refresh_inventory_equipment_slots()


func _refresh_inventory_equipment_slots() -> void:
	if _equipment_component == null:
		return

	# 背包界面当前远程槽索引；取值来自装备组件，默认用于左侧装备槽高亮，修改会影响当前装备辨识。
	var current_slot: int = int(_equipment_component.call("get_current_ranged_slot"))
	# 背包界面远程槽刷新索引；取值为控件数组下标，默认逐个刷新，修改循环范围会影响左侧装备内容。
	for slot_index in range(_inventory_equipment_ranged_controls.size()):
		# 背包界面当前远程武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响左侧远程槽显示。
		var ranged_weapon: Resource = _equipment_component.call("get_ranged_weapon", slot_index) as Resource
		_inventory_equipment_ranged_controls[slot_index].call("set_slot_data", "equipment", "ranged", slot_index, ranged_weapon, slot_index == current_slot)
		_inventory_equipment_ranged_controls[slot_index].call("set_empty_text", "空远程")

	if _inventory_equipment_melee_control != null:
		# 背包界面当前近战武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响左侧近战槽显示。
		var melee_weapon: Resource = _equipment_component.call("get_melee_weapon") as Resource
		_inventory_equipment_melee_control.call("set_slot_data", "equipment", "melee", -1, melee_weapon, true)
		_inventory_equipment_melee_control.call("set_empty_text", "空近战")


func _refresh_cooldown_overlays() -> void:
	# 远程冷却比例；取值为 0 到 1，默认从远程攻击组件读取，修改会影响远程槽白色 CD 遮罩。
	var ranged_cooldown_ratio: float = _get_component_cooldown_ratio(_ranged_attack_component)
	if ranged_cooldown_ratio <= 0.0:
		_last_cooling_ranged_slot = -1

	# 远程槽冷却刷新索引；取值为控件数组下标，默认逐槽清理或设置遮罩，修改循环范围会影响 CD 显示目标。
	for slot_index in range(_ranged_slot_controls.size()):
		# 当前远程槽遮罩比例；取值为 0 到 1，默认只给最近开火槽显示，修改会影响远程 CD 归属。
		var slot_cooldown_ratio: float = ranged_cooldown_ratio if slot_index == _last_cooling_ranged_slot else 0.0
		_ranged_slot_controls[slot_index].call("set_cooldown_ratio", slot_cooldown_ratio)

	if _melee_slot_control != null:
		# 近战冷却比例；取值为 0 到 1，默认从近战攻击组件读取，修改会影响近战槽白色 CD 遮罩。
		var melee_cooldown_ratio: float = _get_component_cooldown_ratio(_melee_attack_component)
		_melee_slot_control.call("set_cooldown_ratio", melee_cooldown_ratio)


func _create_weapon_slot_control(minimum_size: Vector2) -> Control:
	# 新建武器槽控件；取值为 WeaponSlotControl 实例，默认由预加载脚本创建，修改会影响所有槽位基础控件。
	var slot_control: Control = WEAPON_SLOT_CONTROL_SCRIPT.new() as Control
	slot_control.custom_minimum_size = minimum_size
	slot_control.connect("drop_received", Callable(self, "_on_weapon_slot_drop_received"))
	return slot_control


func _clear_container(container: Node) -> void:
	# 容器旧子节点遍历项；取值来自容器子节点，默认全部移除并排队释放，修改循环来源会影响 UI 重建范围。
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _toggle_inventory() -> void:
	_set_inventory_visible(not _inventory_panel.visible)


func _set_inventory_visible(visible: bool) -> void:
	if visible and _large_map_overlay.visible:
		_large_map_overlay.visible = false

	_inventory_panel.visible = visible
	if visible:
		_rebuild_inventory_slots()

	_refresh_combat_input_state()


func _toggle_large_map() -> void:
	_set_large_map_visible(not _large_map_overlay.visible)


func _set_large_map_visible(visible: bool) -> void:
	if visible and _inventory_panel.visible:
		_inventory_panel.visible = false

	_large_map_overlay.visible = visible
	_refresh_combat_input_state()


func _refresh_combat_input_state() -> void:
	# 战斗输入启用状态；取值由背包、大地图和暂停菜单共同决定，默认任意界面打开都会禁用战斗输入。
	var combat_input_enabled: bool = not _inventory_panel.visible and not _large_map_overlay.visible and not _pause_overlay.visible
	_set_combat_input_enabled(combat_input_enabled)


func _set_combat_input_enabled(enabled: bool) -> void:
	if _input_component == null or not _input_component.has_method("set_combat_input_enabled"):
		return

	_input_component.call("set_combat_input_enabled", enabled)


func _bind_inventory_filter_buttons() -> void:
	_inventory_filter_all_button.toggle_mode = true
	_inventory_filter_melee_button.toggle_mode = true
	_inventory_filter_ranged_button.toggle_mode = true
	_inventory_filter_all_button.connect("pressed", Callable(self, "_on_inventory_filter_all_pressed"))
	_inventory_filter_melee_button.connect("pressed", Callable(self, "_on_inventory_filter_melee_pressed"))
	_inventory_filter_ranged_button.connect("pressed", Callable(self, "_on_inventory_filter_ranged_pressed"))
	_refresh_inventory_filter_buttons()


func _bind_inventory_drop_area() -> void:
	if _inventory_drop_area == null or not _inventory_drop_area.has_signal("drop_received"):
		return

	_inventory_drop_area.connect("drop_received", Callable(self, "_on_inventory_drop_area_drop_received"))


func _bind_pause_menu() -> void:
	_resume_button.pressed.connect(_on_resume_button_pressed)
	_pause_settings_button.pressed.connect(_on_pause_settings_button_pressed)
	_test_settings_button.pressed.connect(_on_test_settings_button_pressed)
	_return_main_menu_button.pressed.connect(_on_return_main_menu_button_pressed)
	_pause_settings_back_button.pressed.connect(_on_pause_settings_back_button_pressed)
	_clear_monsters_button.pressed.connect(_on_clear_monsters_button_pressed)
	_respawn_monsters_button.pressed.connect(_on_respawn_monsters_button_pressed)
	_switch_character_button.pressed.connect(_on_switch_character_button_pressed)
	_switch_character_stelle_button.pressed.connect(_on_switch_character_stelle_button_pressed)
	_switch_character_caelus_button.pressed.connect(_on_switch_character_caelus_button_pressed)
	_switch_character_silver_wolf_button.pressed.connect(_on_switch_character_silver_wolf_button_pressed)
	_character_switch_back_button.pressed.connect(_on_character_switch_back_button_pressed)
	_infinite_energy_check_button.toggled.connect(_on_infinite_energy_toggled)
	_infinite_health_check_button.toggled.connect(_on_infinite_health_toggled)
	_test_settings_back_button.pressed.connect(_on_test_settings_back_button_pressed)
	_pause_master_volume_slider.value_changed.connect(_on_pause_master_volume_slider_value_changed)
	_sync_pause_master_volume_slider()
	_sync_mode_controls()


func _resolve_training_mode() -> bool:
	if _game_world == null or not _game_world.has_method("is_training_mode"):
		return false

	return bool(_game_world.call("is_training_mode"))


func _sync_mode_controls() -> void:
	_test_settings_button.visible = _is_training_mode
	if not _is_training_mode:
		_test_settings_panel.visible = false
		_character_switch_panel.visible = false


func _set_inventory_filter(new_filter: String) -> void:
	if _inventory_filter == new_filter:
		_refresh_inventory_filter_buttons()
		return

	_inventory_filter = new_filter
	_refresh_inventory_filter_buttons()
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _refresh_inventory_filter_buttons() -> void:
	_inventory_filter_all_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_ALL)
	_inventory_filter_melee_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_MELEE)
	_inventory_filter_ranged_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_RANGED)


func _does_item_match_inventory_filter(item_data: Resource) -> bool:
	if item_data == null:
		return false

	if _inventory_filter == INVENTORY_FILTER_ALL:
		return true

	# 背包物品武器类型；取值来自资源 weapon_type 字段，默认用于和当前筛选页比较，修改会影响物品是否显示。
	var weapon_type: String = str(item_data.get("weapon_type"))
	return weapon_type == _inventory_filter


func _get_inventory_filter_label() -> String:
	if _inventory_filter == INVENTORY_FILTER_MELEE:
		return "近战"
	if _inventory_filter == INVENTORY_FILTER_RANGED:
		return "远程"

	return "全部"


func _is_toggle_inventory_event(key_event: InputEventKey) -> bool:
	if key_event.physical_keycode == KEY_E:
		return true

	return InputMap.has_action(toggle_inventory_action) and Input.is_action_just_pressed(toggle_inventory_action)


func _is_pause_event(key_event: InputEventKey) -> bool:
	if key_event.physical_keycode == KEY_ESCAPE:
		return true

	return InputMap.has_action(pause_action) and Input.is_action_just_pressed(pause_action)


func _is_toggle_large_map_event(key_event: InputEventKey) -> bool:
	if key_event.physical_keycode == KEY_M:
		return true

	return InputMap.has_action(toggle_large_map_action) and Input.is_action_just_pressed(toggle_large_map_action)


func _toggle_pause_menu() -> void:
	if _pause_overlay.visible and _pause_settings_panel.visible:
		_show_pause_settings(false)
		return

	if _pause_overlay.visible and _character_switch_panel.visible:
		_show_character_switch(false)
		return

	if _pause_overlay.visible and _test_settings_panel.visible:
		_show_test_settings(false)
		return

	_set_pause_menu_visible(not _pause_overlay.visible)


func _set_pause_menu_visible(visible: bool) -> void:
	_pause_overlay.visible = visible
	_pause_menu_panel.visible = visible
	_pause_settings_panel.visible = false
	_test_settings_panel.visible = false
	_character_switch_panel.visible = false
	_sync_mode_controls()
	get_tree().paused = visible
	if visible:
		if _inventory_panel.visible:
			_set_inventory_visible(false)
		if _large_map_overlay.visible:
			_set_large_map_visible(false)
		_refresh_combat_input_state()
		_sync_pause_master_volume_slider()
		_resume_button.grab_focus()
	else:
		_refresh_combat_input_state()


func _show_pause_settings(visible: bool) -> void:
	_pause_menu_panel.visible = not visible
	_pause_settings_panel.visible = visible
	_test_settings_panel.visible = false
	_character_switch_panel.visible = false
	if visible:
		_sync_pause_master_volume_slider()
		_pause_settings_back_button.grab_focus()
	else:
		_pause_settings_button.grab_focus()


func _show_test_settings(visible: bool) -> void:
	if visible and not _is_training_mode:
		return

	_pause_menu_panel.visible = not visible
	_pause_settings_panel.visible = false
	_test_settings_panel.visible = visible
	_character_switch_panel.visible = false
	if visible:
		_sync_test_settings_controls()
		_clear_monsters_button.grab_focus()
	else:
		_test_settings_button.grab_focus()


func _show_character_switch(visible: bool) -> void:
	if visible and not _is_training_mode:
		return

	_pause_menu_panel.visible = false
	_pause_settings_panel.visible = false
	_test_settings_panel.visible = not visible
	_character_switch_panel.visible = visible
	if visible:
		_switch_character_stelle_button.grab_focus()
	else:
		_switch_character_button.grab_focus()


func _sync_test_settings_controls() -> void:
	if _stats_component == null:
		_infinite_energy_check_button.set_pressed_no_signal(false)
		_infinite_health_check_button.set_pressed_no_signal(false)
		return

	# 无限能量状态；取值来自属性组件，默认 false，修改会影响训练场设置开关显示。
	var infinite_energy_enabled: bool = bool(_stats_component.get("infinite_energy"))
	# 无限血量状态；取值来自属性组件，默认 false，修改会影响训练场设置开关显示。
	var infinite_health_enabled: bool = bool(_stats_component.get("infinite_health"))
	_infinite_energy_check_button.set_pressed_no_signal(infinite_energy_enabled)
	_infinite_health_check_button.set_pressed_no_signal(infinite_health_enabled)


func _sync_pause_master_volume_slider() -> void:
	if _master_bus_index < 0:
		return

	# 当前 Master 音量线性值；取值为 0 到 1，默认由 AudioServer 读取，修改会影响暂停设置滑条初始位置。
	var linear_volume: float = 0.0 if AudioServer.is_bus_mute(_master_bus_index) else db_to_linear(AudioServer.get_bus_volume_db(_master_bus_index))
	_pause_master_volume_slider.set_value_no_signal(clampf(linear_volume, 0.0, 1.0) * 100.0)
	_refresh_pause_master_volume_label(_pause_master_volume_slider.value)


func _apply_pause_master_volume(value: float) -> void:
	if _master_bus_index < 0:
		return

	# 标准化音量值；取值为 0 到 1，默认由滑条百分比换算，修改会影响最终写入 AudioServer 的音量。
	var linear_volume: float = clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(_master_bus_index, linear_volume <= 0.001)
	if linear_volume > 0.001:
		AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(linear_volume))

	_refresh_pause_master_volume_label(value)


func _refresh_pause_master_volume_label(value: float) -> void:
	_pause_master_volume_value_label.text = "%d%%" % roundi(value)


func _get_component_cooldown_ratio(component: Node) -> float:
	if component == null or not component.has_method("get_cooldown_ratio"):
		return 0.0

	return clampf(float(component.call("get_cooldown_ratio")), 0.0, 1.0)


func _get_current_character_display_name() -> String:
	if _game_world != null and _game_world.has_method("get_selected_character_name"):
		# 游戏世界角色名；取值来自当前会话选择，默认用于 HUD 最优先显示。
		var world_character_name: String = str(_game_world.call("get_selected_character_name"))
		if not world_character_name.is_empty():
			return world_character_name

	if _player != null:
		# 玩家节点显示名；取值来自 player_display_name 属性，默认作为 GameWorld 缺失时的兜底。
		var player_character_name: String = str(_player.get("player_display_name"))
		if not player_character_name.is_empty():
			return player_character_name

	return "角色"


func _on_weapon_slot_drop_received(drop_data: Dictionary, target_context: String, target_kind: String, target_index: int) -> void:
	if _equipment_component == null or not drop_data.has("weapon_data"):
		return

	# 被拖拽武器资源；取值为 Resource 或 null，默认来自槽位拖拽数据，修改会影响装备和卸下目标。
	var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
	if dragged_weapon == null:
		return

	if target_context == "inventory":
		_handle_drop_to_inventory(drop_data, target_index)
	elif target_context == "equipment":
		_handle_drop_to_equipment(drop_data, target_kind, target_index)

	_refresh_equipment()
	_rebuild_inventory_slots()


func _handle_drop_to_inventory(drop_data: Dictionary, target_index: int) -> void:
	if _inventory_component == null:
		return

	# 拖拽来源上下文；取值为 equipment 或 inventory，默认空字符串表示非法来源，修改会影响背包投放分支。
	var source_context: String = str(drop_data.get("source_context", ""))
	if source_context == "inventory":
		# 背包拖拽来源索引；取值为有效背包下标，默认来自拖拽数据，修改会影响物品排序来源。
		var source_index: int = int(drop_data.get("slot_index", -1))
		if _inventory_component.has_method("move_item"):
			_inventory_component.call("move_item", source_index, target_index)
	elif source_context == "equipment":
		# 被卸下武器资源；取值为 Resource 或 null，默认来自拖拽数据，修改会影响回到背包的对象。
		var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
		if _unequip_from_drop_source(drop_data):
			_add_item_to_inventory(dragged_weapon, target_index)


func _handle_drop_to_equipment(drop_data: Dictionary, target_kind: String, target_index: int) -> void:
	# 拖拽来源上下文；取值为 equipment 或 inventory，默认空字符串表示非法来源，修改会影响装备投放分支。
	var source_context: String = str(drop_data.get("source_context", ""))
	if source_context == "inventory":
		_equip_inventory_weapon_to_target(drop_data, target_kind, target_index)
	elif source_context == "equipment":
		_move_equipped_weapon_to_target(drop_data, target_kind, target_index)


func _equip_inventory_weapon_to_target(drop_data: Dictionary, target_kind: String, target_index: int) -> void:
	if _inventory_component == null:
		return

	# 被装备武器资源；取值为 Resource 或 null，默认来自拖拽数据，修改会影响目标装备槽内容。
	var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
	if dragged_weapon == null:
		return

	# 背包来源索引；取值为有效背包下标，默认来自拖拽数据，修改会影响被替换武器返回背包的位置。
	var source_index: int = int(drop_data.get("slot_index", -1))
	if not _inventory_has_item(dragged_weapon):
		return

	# 目标槽原有武器；取值为 Resource 或 null，默认用于装备替换后放回背包，修改会影响替换规则。
	var replaced_weapon: Resource = _get_equipped_weapon(target_kind, target_index)
	if not _remove_item_from_inventory(dragged_weapon):
		return

	if not _equip_weapon_to_target(target_kind, target_index, dragged_weapon):
		_add_item_to_inventory(dragged_weapon, source_index)
		return

	if replaced_weapon != null and replaced_weapon != dragged_weapon:
		_add_item_to_inventory(replaced_weapon, source_index)


func _move_equipped_weapon_to_target(drop_data: Dictionary, target_kind: String, target_index: int) -> void:
	# 拖拽来源槽类型；取值为 ranged 或 melee，默认来自拖拽数据，修改会影响装备槽互拖规则。
	var source_kind: String = str(drop_data.get("slot_kind", ""))
	# 拖拽来源槽索引；取值为有效远程槽下标或 -1，默认来自拖拽数据，修改会影响原槽清理目标。
	var source_index: int = int(drop_data.get("slot_index", -1))
	if source_kind == target_kind and source_index == target_index:
		return

	# 被移动武器资源；取值为 Resource 或 null，默认来自拖拽数据，修改会影响目标装备槽内容。
	var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
	if dragged_weapon == null:
		return

	# 目标槽原有武器；取值为 Resource 或 null，默认用于同类型装备槽之间交换，修改会影响互拖结果。
	var target_weapon: Resource = _get_equipped_weapon(target_kind, target_index)
	# 来源远程槽是否当前选中；取值为 true/false，默认用于交换后让当前武器跟随被拖拽武器，修改会影响切枪状态。
	var source_was_current_ranged: bool = _is_current_ranged_source(source_kind, source_index)
	if not _equip_weapon_to_target(target_kind, target_index, dragged_weapon):
		return

	if source_kind == "ranged" and target_kind == "ranged":
		if target_weapon != null and target_weapon != dragged_weapon:
			_equipment_component.call("equip_ranged_weapon", source_index, target_weapon)
		elif _equipment_component.has_method("unequip_ranged_weapon"):
			_equipment_component.call("unequip_ranged_weapon", source_index)

		if source_was_current_ranged and _equipment_component.has_method("equip_ranged_slot"):
			_equipment_component.call("equip_ranged_slot", target_index)


func _unequip_from_drop_source(drop_data: Dictionary) -> bool:
	if str(drop_data.get("source_context", "")) != "equipment":
		return false

	# 拖拽来源槽类型；取值来自拖拽数据，默认用于判断卸下远程或近战，修改会影响卸下分支。
	var source_kind: String = str(drop_data.get("slot_kind", ""))
	if source_kind == "ranged" and _equipment_component.has_method("unequip_ranged_weapon"):
		# 拖拽来源远程槽索引；取值为有效槽下标，默认来自拖拽数据，修改会影响被卸下的远程槽。
		var source_index: int = int(drop_data.get("slot_index", -1))
		return bool(_equipment_component.call("unequip_ranged_weapon", source_index))
	elif source_kind == "melee" and _equipment_component.has_method("unequip_melee_weapon"):
		return bool(_equipment_component.call("unequip_melee_weapon"))

	return false


func _get_equipped_weapon(target_kind: String, target_index: int) -> Resource:
	if target_kind == "ranged" and _equipment_component.has_method("get_ranged_weapon"):
		return _equipment_component.call("get_ranged_weapon", target_index) as Resource
	if target_kind == "melee" and _equipment_component.has_method("get_melee_weapon"):
		return _equipment_component.call("get_melee_weapon") as Resource

	return null


func _equip_weapon_to_target(target_kind: String, target_index: int, weapon_data: Resource) -> bool:
	if target_kind == "ranged" and _equipment_component.has_method("equip_ranged_weapon"):
		return bool(_equipment_component.call("equip_ranged_weapon", target_index, weapon_data))
	if target_kind == "melee" and _equipment_component.has_method("equip_melee_weapon"):
		return bool(_equipment_component.call("equip_melee_weapon", weapon_data))

	return false


func _inventory_has_item(item_data: Resource) -> bool:
	if _inventory_component == null or item_data == null or not _inventory_component.has_method("has_item"):
		return false

	return bool(_inventory_component.call("has_item", item_data))


func _remove_item_from_inventory(item_data: Resource) -> bool:
	if _inventory_component == null or item_data == null or not _inventory_component.has_method("remove_item"):
		return false

	return bool(_inventory_component.call("remove_item", item_data))


func _add_item_to_inventory(item_data: Resource, target_index: int) -> bool:
	if _inventory_component == null or item_data == null:
		return false

	if _inventory_component.has_method("add_item_at"):
		return bool(_inventory_component.call("add_item_at", item_data, target_index))
	if _inventory_component.has_method("add_item"):
		return bool(_inventory_component.call("add_item", item_data))

	return false


func _get_inventory_item_count() -> int:
	if _inventory_component == null or not _inventory_component.has_method("get_item_count"):
		return 0

	return int(_inventory_component.call("get_item_count"))


func _clear_training_monsters() -> void:
	if _game_world == null or not _game_world.has_method("clear_monsters"):
		return

	_game_world.call("clear_monsters")


func _respawn_training_monsters() -> void:
	if _game_world == null or not _game_world.has_method("respawn_monsters"):
		return

	_game_world.call("respawn_monsters")


func _set_infinite_energy_enabled(enabled: bool) -> void:
	if _stats_component == null or not _stats_component.has_method("set_infinite_energy"):
		return

	_stats_component.call("set_infinite_energy", enabled)
	_refresh_stats()


func _set_infinite_health_enabled(enabled: bool) -> void:
	if _stats_component == null or not _stats_component.has_method("set_infinite_health"):
		return

	_stats_component.call("set_infinite_health", enabled)
	_refresh_stats()


func _switch_training_character(character_id: String) -> void:
	if not _is_training_mode:
		return

	if _game_world == null or not _game_world.has_method("switch_character"):
		return

	_game_world.call("switch_character", character_id)
	_refresh_all()
	_show_character_switch(false)


func _is_current_ranged_source(source_kind: String, source_index: int) -> bool:
	if source_kind != "ranged" or not _equipment_component.has_method("get_current_ranged_slot"):
		return false

	return int(_equipment_component.call("get_current_ranged_slot")) == source_index


func _on_health_changed(_current_health: float, _max_health: float) -> void:
	_refresh_stats()


func _on_energy_changed(_current_energy: float, _max_energy: float) -> void:
	_refresh_stats()


func _on_equipment_changed() -> void:
	if _equipment_component != null and _equipment_component.has_method("get_ranged_slot_count"):
		# 当前装备组件远程槽数量；取值来自装备组件，默认用于判断是否需要重建 UI，修改会影响槽位重建频率。
		var slot_count: int = int(_equipment_component.call("get_ranged_slot_count"))
		if _ranged_slot_controls.size() != slot_count or _melee_slot_control == null:
			_rebuild_equipment_slots()

	_refresh_equipment()
	if _inventory_panel.visible:
		_refresh_inventory_equipment_slots()


func _on_inventory_changed() -> void:
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _on_ranged_weapon_fired(_projectile: Node2D) -> void:
	if _equipment_component == null or not _equipment_component.has_method("get_current_ranged_slot"):
		return

	_last_cooling_ranged_slot = int(_equipment_component.call("get_current_ranged_slot"))


func _on_inventory_filter_all_pressed() -> void:
	_set_inventory_filter(INVENTORY_FILTER_ALL)


func _on_inventory_filter_melee_pressed() -> void:
	_set_inventory_filter(INVENTORY_FILTER_MELEE)


func _on_inventory_filter_ranged_pressed() -> void:
	_set_inventory_filter(INVENTORY_FILTER_RANGED)


func _on_inventory_drop_area_drop_received(drop_data: Dictionary) -> void:
	# 背包末尾索引；取值为当前背包物品总数，默认用于空白区域投放，修改会影响卸下或排序后的落点。
	var target_index: int = _get_inventory_item_count()
	_handle_drop_to_inventory(drop_data, target_index)
	_refresh_equipment()
	_rebuild_inventory_slots()


func _on_resume_button_pressed() -> void:
	_set_pause_menu_visible(false)


func _on_pause_settings_button_pressed() -> void:
	_show_pause_settings(true)


func _on_test_settings_button_pressed() -> void:
	_show_test_settings(true)


func _on_return_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_pause_settings_back_button_pressed() -> void:
	_show_pause_settings(false)


func _on_clear_monsters_button_pressed() -> void:
	_clear_training_monsters()


func _on_respawn_monsters_button_pressed() -> void:
	_respawn_training_monsters()


func _on_switch_character_button_pressed() -> void:
	_show_character_switch(true)


func _on_switch_character_stelle_button_pressed() -> void:
	_switch_training_character(CHARACTER_STELLE)


func _on_switch_character_caelus_button_pressed() -> void:
	_switch_training_character(CHARACTER_CAEULUS)


func _on_switch_character_silver_wolf_button_pressed() -> void:
	_switch_training_character(CHARACTER_SILVER_WOLF)


func _on_character_switch_back_button_pressed() -> void:
	_show_character_switch(false)


func _on_infinite_energy_toggled(enabled: bool) -> void:
	_set_infinite_energy_enabled(enabled)


func _on_infinite_health_toggled(enabled: bool) -> void:
	_set_infinite_health_enabled(enabled)


func _on_test_settings_back_button_pressed() -> void:
	_show_test_settings(false)


func _on_pause_master_volume_slider_value_changed(value: float) -> void:
	_apply_pause_master_volume(value)
