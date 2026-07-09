extends CanvasLayer
class_name CombatHud

## 战斗 HUD 显示玩家生命、能量、底部武器栏和可开关背包。
## HUD 只负责界面呈现、拖拽投放和输入转发，背包与装备数据仍由独立组件维护。
## 武器槽的冷却覆盖由攻击组件的冷却比例驱动，近战和远程使用同一套白色遮罩表现。

## 可拖拽武器槽控件脚本；默认预加载本项目 UI 控件，修改会影响所有装备槽和背包槽的生成方式。
const WEAPON_SLOT_CONTROL_SCRIPT: Script = preload("res://scripts/ui/weapon_slot_control.gd")

## 玩家节点路径；默认指向同一游戏世界下的 SilverWolf，必须解析到玩家根节点，运行时通常不修改。
@export var player_path: NodePath = ^"../SilverWolf"
## 背包开关输入动作名；默认 toggle_inventory 对应 E 键，运行时通常不修改，改名会影响背包打开/关闭。
@export var toggle_inventory_action: StringName = &"toggle_inventory"
## 远程装备槽最小尺寸；默认 88x60 适合底部低遮挡显示，运行时通常不修改，扩展槽数量时可调小。
@export var ranged_slot_minimum_size: Vector2 = Vector2(88.0, 60.0)
## 近战装备槽最小尺寸；默认 88x60 与远程槽一致，运行时通常不修改，修改会影响底部装备栏对齐。
@export var melee_slot_minimum_size: Vector2 = Vector2(88.0, 60.0)
## 背包物品槽最小尺寸；默认 116x74 适合网格展示，运行时通常不修改，修改会影响背包容量视觉密度。
@export var inventory_slot_minimum_size: Vector2 = Vector2(116.0, 74.0)

## 玩家节点缓存；默认按 player_path 获取，允许为空但 HUD 不会显示有效状态，修改会影响所有组件绑定。
var _player: Node
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


func _ready() -> void:
	_bind_player_components()
	_refresh_all()
	_set_inventory_visible(false)


func _process(_delta: float) -> void:
	_refresh_cooldown_overlays()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		# 当前键盘事件；取值来自输入系统，默认用于识别 E 键和背包动作，修改会影响背包开关响应。
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and _is_toggle_inventory_event(key_event):
			_toggle_inventory()
			get_viewport().set_input_as_handled()


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
		_refresh_inventory_title(0)
		return

	# 背包物品列表；取值来自背包组件副本，默认空数组，修改会影响背包网格显示内容。
	var items: Array = _inventory_component.call("get_items")
	_refresh_inventory_title(items.size())

	# 背包物品槽索引；取值为背包物品数组下标，默认逐个创建，修改循环范围会影响背包显示数量。
	for item_index in range(items.size()):
		# 背包物品资源；取值为 Resource 或 null，默认来自背包组件，修改会影响当前背包槽显示和拖拽内容。
		var item_data: Resource = items[item_index] as Resource
		# 背包物品槽控件；取值为 WeaponSlotControl 实例，默认动态创建，修改会影响背包槽显示与拖拽行为。
		var inventory_slot: Control = _create_weapon_slot_control(inventory_slot_minimum_size)
		inventory_slot.call("set_slot_data", "inventory", "inventory", item_index, item_data, false)
		inventory_slot.call("set_empty_text", "空")
		_inventory_weapon_grid.add_child(inventory_slot)
		_inventory_slot_controls.append(inventory_slot)


func _refresh_inventory_title(item_count: int) -> void:
	_inventory_title_label.text = "背包  E关闭  %d件武器" % item_count


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
	_inventory_panel.visible = visible
	_set_combat_input_enabled(not visible)
	if visible:
		_rebuild_inventory_slots()


func _set_combat_input_enabled(enabled: bool) -> void:
	if _input_component == null or not _input_component.has_method("set_combat_input_enabled"):
		return

	_input_component.call("set_combat_input_enabled", enabled)


func _is_toggle_inventory_event(key_event: InputEventKey) -> bool:
	if key_event.physical_keycode == KEY_E:
		return true

	return InputMap.has_action(toggle_inventory_action) and Input.is_action_just_pressed(toggle_inventory_action)


func _get_component_cooldown_ratio(component: Node) -> float:
	if component == null or not component.has_method("get_cooldown_ratio"):
		return 0.0

	return clampf(float(component.call("get_cooldown_ratio")), 0.0, 1.0)


func _on_weapon_slot_drop_received(drop_data: Dictionary, target_context: String, target_kind: String, target_index: int) -> void:
	if _equipment_component == null or not drop_data.has("weapon_data"):
		return

	# 被拖拽武器资源；取值为 Resource 或 null，默认来自槽位拖拽数据，修改会影响装备和卸下目标。
	var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
	if dragged_weapon == null:
		return

	if target_context == "inventory":
		_unequip_from_drop_source(drop_data)
	elif target_kind == "ranged" and _equipment_component.has_method("equip_ranged_weapon"):
		_equipment_component.call("equip_ranged_weapon", target_index, dragged_weapon)
		_clear_original_equipment_slot_if_moved(drop_data, "ranged", target_index)
	elif target_kind == "melee" and _equipment_component.has_method("equip_melee_weapon"):
		_equipment_component.call("equip_melee_weapon", dragged_weapon)
		_clear_original_equipment_slot_if_moved(drop_data, "melee", target_index)

	_refresh_equipment()
	if _inventory_panel.visible:
		_refresh_inventory_equipment_slots()
	_rebuild_inventory_slots()


func _unequip_from_drop_source(drop_data: Dictionary) -> void:
	if str(drop_data.get("source_context", "")) != "equipment":
		return

	# 拖拽来源槽类型；取值来自拖拽数据，默认用于判断卸下远程或近战，修改会影响卸下分支。
	var source_kind: String = str(drop_data.get("slot_kind", ""))
	if source_kind == "ranged" and _equipment_component.has_method("unequip_ranged_weapon"):
		# 拖拽来源远程槽索引；取值为有效槽下标，默认来自拖拽数据，修改会影响被卸下的远程槽。
		var source_index: int = int(drop_data.get("slot_index", -1))
		_equipment_component.call("unequip_ranged_weapon", source_index)
	elif source_kind == "melee" and _equipment_component.has_method("unequip_melee_weapon"):
		_equipment_component.call("unequip_melee_weapon")


func _clear_original_equipment_slot_if_moved(drop_data: Dictionary, target_kind: String, target_index: int) -> void:
	if str(drop_data.get("source_context", "")) != "equipment":
		return

	# 拖拽来源槽类型；取值来自拖拽数据，默认用于判断是否需要清空原槽，修改会影响装备移动行为。
	var source_kind: String = str(drop_data.get("slot_kind", ""))
	# 拖拽来源槽索引；取值为有效远程槽下标或 -1，默认来自拖拽数据，修改会影响原槽清理目标。
	var source_index: int = int(drop_data.get("slot_index", -1))
	if source_kind == "ranged" and target_kind == "ranged" and source_index != target_index:
		if _equipment_component.has_method("unequip_ranged_weapon"):
			_equipment_component.call("unequip_ranged_weapon", source_index)
	elif source_kind == "melee" and target_kind != "melee":
		if _equipment_component.has_method("unequip_melee_weapon"):
			_equipment_component.call("unequip_melee_weapon")


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


func _on_inventory_changed() -> void:
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _on_ranged_weapon_fired(_projectile: Node2D) -> void:
	if _equipment_component == null or not _equipment_component.has_method("get_current_ranged_slot"):
		return

	_last_cooling_ranged_slot = int(_equipment_component.call("get_current_ranged_slot"))
