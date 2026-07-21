extends CanvasLayer
class_name LobbyHud

## 大厅 HUD 显示菜单切换、当前交互目标、角色生命能量、主动技能与已装备武器快照。
## HUD 只读取玩家组件并发出界面请求，不拥有角色数据、交互距离、场景路径或设施动作路由。

## 玩家点击左上角切换按钮时派发；大厅世界负责实际场景路径和转场服务调用。
signal switch_view_requested

## 全局 UI 样式指南；大厅 HUD 的按钮、分区面板与标题跟随当前 UI 风格即时刷新。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 局内共享武器槽视图；大厅与战斗 HUD 复用同一纯展示接口，不引入装备、拖拽或修复操作。
const COMBAT_HUD_SLOT_VIEW_SCRIPT: Script = preload("res://scripts/ui/combat_hud_slot_view.gd")
## 武器与技能动态状态刷新间隔；固定 0.05 秒，即每秒 20 次刷新冷却遮罩与耐久显示。
const DYNAMIC_REFRESH_INTERVAL_SECONDS: float = 0.05
## 大厅武器槽显示尺寸；固定 112×54 像素，与战斗 HUD 右下武器槽保持一致。
const WEAPON_SLOT_SIZE: Vector2 = Vector2(112.0, 54.0)

## 玩家节点路径；默认从 LobbyHud 指向大厅 Player，用于读取名称、属性与战斗组件。
@export var player_path: NodePath = ^"../Player"

## 动态刷新累计时间；默认 0，达到固定刷新间隔后统一更新武器冷却与耐久视图。
var _dynamic_refresh_elapsed: float = 0.0
## 当前是否有主菜单复用面板打开；默认 false，打开时隐藏交互提示并禁用切换按钮避免叠加场景请求。
var _modal_open: bool = false
## 远程武器槽视图数组；元素顺序与 EquipmentComponent 的远程槽索引一致，默认空数组并在 ready 阶段创建。
var _ranged_slot_views: Array[Control] = []
## 近战武器槽视图；默认 null，在 ready 阶段创建唯一实例并持续复用。
var _melee_slot_view: Control

## 玩家节点缓存；默认在 ready 阶段按 player_path 获取，缺失时 HUD 保留占位文本。
@onready var _player: Node = get_node_or_null(player_path)
## 玩家属性组件缓存；默认从玩家 StatsComponent 获取，用于生命、能量与对应信号。
@onready var _stats_component: Node = _player.get_node_or_null("StatsComponent") if _player != null else null
## 玩家装备组件缓存；默认从玩家 EquipmentComponent 获取，用于武器资源、槽位与装备变化信号。
@onready var _equipment_component: Node = _player.get_node_or_null("EquipmentComponent") if _player != null else null
## 玩家主动技能组件缓存；默认从玩家 ActiveSkillComponent 获取并注入纯展示技能栏。
@onready var _active_skill_component: Node = _player.get_node_or_null("ActiveSkillComponent") if _player != null else null
## 玩家远程攻击组件缓存；默认从玩家 RangedAttackComponent 获取当前手持远程武器的冷却比例。
@onready var _ranged_attack_component: Node = _player.get_node_or_null("RangedAttackComponent") if _player != null else null
## 玩家近战攻击组件缓存；默认从玩家 MeleeAttackComponent 获取近战武器冷却比例。
@onready var _melee_attack_component: Node = _player.get_node_or_null("MeleeAttackComponent") if _player != null else null
## HUD 根控件缓存；覆盖完整视口但忽略鼠标，只有明确按钮节点接收输入。
@onready var _root: Control = get_node("Root") as Control
## 菜单与大厅切换按钮缓存；默认位于左上角，点击后仅派发 switch_view_requested。
@onready var _switch_view_button: Button = get_node("Root/SwitchViewButton") as Button
## 大厅标题缓存；默认位于屏幕顶部中心，只显示当前场景身份。
@onready var _lobby_title_label: Label = get_node("Root/LobbyTitleLabel") as Label
## 交互提示面板缓存；仅在存在最近实体且没有复用面板打开时显示。
@onready var _interaction_panel: PanelContainer = get_node("Root/InteractionPanel") as PanelContainer
## 交互提示文字缓存；默认显示“按 F 交互：设施名”，设施名由交互组件信号注入。
@onready var _interaction_label: Label = get_node("Root/InteractionPanel/InteractionMargin/InteractionLabel") as Label
## 底部角色状态面板缓存；承载角色名、生命与能量，不参与属性结算。
@onready var _status_panel: PanelContainer = get_node("Root/StatusPanel") as PanelContainer
## 当前角色名缓存；默认显示“角色”，角色配置完成后读取玩家 player_display_name。
@onready var _character_name_label: Label = get_node("Root/StatusPanel/StatusMargin/StatusContent/CharacterNameLabel") as Label
## 生命数值标签缓存；默认显示占位值，属性变化信号会即时刷新整数显示。
@onready var _health_label: Label = get_node("Root/StatusPanel/StatusMargin/StatusContent/HealthLabel") as Label
## 生命进度条缓存；范围由当前生命上限决定，数值只读 StatsComponent。
@onready var _health_bar: ProgressBar = get_node("Root/StatusPanel/StatusMargin/StatusContent/HealthBar") as ProgressBar
## 能量数值标签缓存；默认显示占位值，实际能量保留 0.1 精度但 HUD 按战斗规则显示整数。
@onready var _energy_label: Label = get_node("Root/StatusPanel/StatusMargin/StatusContent/EnergyLabel") as Label
## 能量进度条缓存；范围由当前能量上限决定，数值只读 StatsComponent。
@onready var _energy_bar: ProgressBar = get_node("Root/StatusPanel/StatusMargin/StatusContent/EnergyBar") as ProgressBar
## 主动技能分区面板缓存；位于左下角并复用 ActiveSkillBar 的三个槽位展示。
@onready var _active_skill_panel: PanelContainer = get_node("Root/ActiveSkillPanel") as PanelContainer
## 主动技能栏缓存；只读取 ActiveSkillComponent，不接收大厅交互输入。
@onready var _active_skill_bar: Control = get_node("Root/ActiveSkillPanel/SkillMargin/ActiveSkillBar") as Control
## 武器分区面板缓存；位于右下角并承载两个远程槽与一个近战槽。
@onready var _weapon_panel: PanelContainer = get_node("Root/WeaponPanel") as PanelContainer
## 远程武器槽容器缓存；ready 阶段按装备组件公开数量创建只读槽位。
@onready var _ranged_slots: HBoxContainer = get_node("Root/WeaponPanel/WeaponMargin/WeaponRows/RangedSlots") as HBoxContainer
## 近战武器槽容器缓存；ready 阶段创建一个只读槽位。
@onready var _melee_slot_host: HBoxContainer = get_node("Root/WeaponPanel/WeaponMargin/WeaponRows/MeleeSlotHost") as HBoxContainer


func _ready() -> void:
	_apply_visual_style()
	_switch_view_button.pressed.connect(_on_switch_view_button_pressed)
	_bind_player_components()
	_build_weapon_slots()
	if _active_skill_bar != null and _active_skill_bar.has_method("configure"):
		_active_skill_bar.call("configure", _active_skill_component)
	refresh_all()


func _process(delta: float) -> void:
	if not is_visible():
		return
	_dynamic_refresh_elapsed += maxf(delta, 0.0)
	if _dynamic_refresh_elapsed < DYNAMIC_REFRESH_INTERVAL_SECONDS:
		return
	_dynamic_refresh_elapsed = fmod(_dynamic_refresh_elapsed, DYNAMIC_REFRESH_INTERVAL_SECONDS)
	_refresh_weapon_cooldowns()


func set_interaction_target(display_name: String, has_target: bool) -> void:
	## 更新最近设施提示；F 是 pickup_nearby 的当前默认绑定，实际触发仍由 InputMap 动作判断。
	_interaction_label.text = "按 F 交互：%s" % display_name
	_interaction_panel.visible = has_target and not _modal_open


func set_modal_open(open: bool) -> void:
	## 同步复用面板状态；打开时隐藏交互提示并禁用场景切换，关闭后等待下一次目标信号恢复提示。
	_modal_open = open
	_switch_view_button.disabled = _modal_open
	if _modal_open:
		_interaction_panel.visible = false


func refresh_all() -> void:
	## 刷新角色状态、技能与武器快照；角色配置或装备变化后调用，不重建固定 HUD 布局。
	_refresh_stats()
	_refresh_weapons()
	if _active_skill_bar != null and _active_skill_bar.has_method("refresh"):
		_active_skill_bar.call("refresh")


func _bind_player_components() -> void:
	if _stats_component != null:
		if _stats_component.has_signal("health_changed"):
			_stats_component.connect("health_changed", Callable(self, "_on_health_changed"))
		if _stats_component.has_signal("energy_changed"):
			_stats_component.connect("energy_changed", Callable(self, "_on_energy_changed"))
	if _equipment_component != null and _equipment_component.has_signal("equipment_changed"):
		_equipment_component.connect("equipment_changed", Callable(self, "_on_equipment_changed"))
	if _active_skill_component != null and _active_skill_component.has_signal("skill_loadout_changed"):
		_active_skill_component.connect("skill_loadout_changed", Callable(self, "_on_skill_loadout_changed"))


func _build_weapon_slots() -> void:
	# 远程槽数量；默认 2，装备组件公开其他数量时按其真实结构创建。
	var ranged_slot_count: int = int(_equipment_component.call("get_ranged_slot_count")) if _equipment_component != null and _equipment_component.has_method("get_ranged_slot_count") else 2
	for slot_index in range(maxi(ranged_slot_count, 0)):
		# 远程槽视图；每个槽固定 112×54 像素并忽略鼠标，不承担装备交互。
		var slot_view: Control = _create_weapon_slot_view()
		if slot_view == null:
			continue
		_ranged_slots.add_child(slot_view)
		_ranged_slot_views.append(slot_view)
	_melee_slot_view = _create_weapon_slot_view()
	if _melee_slot_view != null:
		_melee_slot_host.add_child(_melee_slot_view)


func _create_weapon_slot_view() -> Control:
	# 共享槽位实例；脚本缺失或实例类型异常时返回 null，HUD 其他区域仍可独立显示。
	var slot_view: Control = COMBAT_HUD_SLOT_VIEW_SCRIPT.new() as Control
	if slot_view != null:
		slot_view.custom_minimum_size = WEAPON_SLOT_SIZE
		slot_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot_view


func _refresh_weapons() -> void:
	if _equipment_component == null:
		return
	# 当前远程槽；默认 0，决定远程武器边框高亮与主攻击组件冷却归属。
	var current_ranged_slot: int = int(_equipment_component.call("get_current_ranged_slot")) if _equipment_component.has_method("get_current_ranged_slot") else 0
	for slot_index in range(_ranged_slot_views.size()):
		# 远程武器资源；空槽保持职责标题并显示“空武器”。
		var ranged_weapon: Resource = _equipment_component.call("get_ranged_weapon", slot_index) as Resource if _equipment_component.has_method("get_ranged_weapon") else null
		_configure_weapon_slot(_ranged_slot_views[slot_index], "远程 %d" % (slot_index + 1), ranged_weapon, slot_index == current_ranged_slot)
	# 近战武器资源；空槽保持唯一近战职责标题并显示“空武器”。
	var melee_weapon: Resource = _equipment_component.call("get_melee_weapon") as Resource if _equipment_component.has_method("get_melee_weapon") else null
	_configure_weapon_slot(_melee_slot_view, "近战", melee_weapon, melee_weapon != null)
	_refresh_weapon_cooldowns()


func _configure_weapon_slot(slot_view: Control, header_text: String, weapon_data: Resource, selected: bool) -> void:
	if slot_view == null:
		return
	# 武器显示名称；损坏资源追加状态文本，空槽使用固定占位名称。
	var display_name: String = "空武器"
	if weapon_data != null:
		display_name = str(weapon_data.get("display_name"))
		if weapon_data.has_method("is_broken") and bool(weapon_data.call("is_broken")):
			display_name += "（损坏）"
	# 武器能耗；优先读取强化后的有效属性，空槽不显示辅助文本。
	var energy_consumption: int = maxi(roundi(float(weapon_data.call("get_effective_stat", "energy_consumption"))), 0) if weapon_data != null and weapon_data.has_method("get_effective_stat") else (maxi(roundi(float(weapon_data.get("energy_consumption"))), 0) if weapon_data != null else 0)
	# 武器辅助文本；零能耗武器仍明确显示 0，避免空槽与免费武器混淆。
	var detail_text: String = "能耗 %d" % energy_consumption if weapon_data != null else ""
	slot_view.call("configure_hud_content", WEAPON_SLOT_SIZE, header_text, display_name, detail_text, weapon_data, 1.0)
	slot_view.call("set_visual_state", selected and weapon_data != null, false)


func _refresh_weapon_cooldowns() -> void:
	if _equipment_component == null:
		return
	# 当前远程槽；只有手持槽显示远程主攻击组件冷却，其他槽保持 0。
	var current_ranged_slot: int = int(_equipment_component.call("get_current_ranged_slot")) if _equipment_component.has_method("get_current_ranged_slot") else 0
	# 远程主组件冷却比例；范围 0 至 1，组件缺失时回退 0。
	var ranged_cooldown_ratio: float = float(_ranged_attack_component.call("get_cooldown_ratio")) if _ranged_attack_component != null and _ranged_attack_component.has_method("get_cooldown_ratio") else 0.0
	for slot_index in range(_ranged_slot_views.size()):
		_ranged_slot_views[slot_index].call("set_cooldown_ratio", ranged_cooldown_ratio if slot_index == current_ranged_slot else 0.0)
		_ranged_slot_views[slot_index].call("refresh_durability")
	# 近战主组件冷却比例；范围 0 至 1，组件缺失时回退 0。
	var melee_cooldown_ratio: float = float(_melee_attack_component.call("get_cooldown_ratio")) if _melee_attack_component != null and _melee_attack_component.has_method("get_cooldown_ratio") else 0.0
	if _melee_slot_view != null:
		_melee_slot_view.call("set_cooldown_ratio", melee_cooldown_ratio)
		_melee_slot_view.call("refresh_durability")


func _refresh_stats() -> void:
	_character_name_label.text = str(_player.get("player_display_name")) if _player != null else "角色"
	if _stats_component == null:
		return
	# 当前生命；属性组件会限制在 0 至生命上限，HUD 四舍五入为整数展示。
	var current_health: float = float(_stats_component.get("current_health"))
	# 当前生命上限；最低 1，避免进度条 max_value 退化为 0。
	var maximum_health: float = maxf(float(_stats_component.get("max_health")), 1.0)
	# 当前能量；组件内部保留 0.1 精度，HUD 延续战斗界面的整数显示规则。
	var current_energy: float = float(_stats_component.get("current_energy"))
	# 当前能量上限；最低 0.1，保持能量条比例稳定。
	var maximum_energy: float = maxf(float(_stats_component.get("max_energy")), 0.1)
	_health_label.text = "生命 %d / %d" % [roundi(current_health), roundi(maximum_health)]
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health
	_energy_label.text = "能量 %d / %d" % [roundi(current_energy), roundi(maximum_energy)]
	_energy_bar.max_value = maximum_energy
	_energy_bar.value = current_energy


func _apply_visual_style() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(_root)
	UI_STYLE_GUIDE.apply_primary_button(_switch_view_button)
	UI_STYLE_GUIDE.apply_title_label(_lobby_title_label, 24)
	UI_STYLE_GUIDE.apply_section_panel(_interaction_panel)
	UI_STYLE_GUIDE.apply_section_panel(_status_panel)
	UI_STYLE_GUIDE.apply_section_panel(_active_skill_panel)
	UI_STYLE_GUIDE.apply_section_panel(_weapon_panel)
	UI_STYLE_GUIDE.apply_title_label(_character_name_label, 12)
	# 生命填充样式；绿色属于生命业务语义色，不随通用黑白 UI 风格替换。
	var health_fill_style: StyleBoxFlat = StyleBoxFlat.new()
	health_fill_style.bg_color = Color(0.16, 0.82, 0.42, 0.96)
	health_fill_style.set_corner_radius_all(3)
	_health_bar.add_theme_stylebox_override("fill", health_fill_style)
	# 能量填充样式；青蓝色属于能量业务语义色，不随通用黑白 UI 风格替换。
	var energy_fill_style: StyleBoxFlat = StyleBoxFlat.new()
	energy_fill_style.bg_color = Color(0.18, 0.62, 0.96, 0.96)
	energy_fill_style.set_corner_radius_all(3)
	_energy_bar.add_theme_stylebox_override("fill", energy_fill_style)


func _on_switch_view_button_pressed() -> void:
	switch_view_requested.emit()


func _on_health_changed(_current_health: float, _maximum_health: float) -> void:
	_refresh_stats()


func _on_energy_changed(_current_energy: float, _maximum_energy: float) -> void:
	_refresh_stats()


func _on_equipment_changed() -> void:
	_refresh_weapons()


func _on_skill_loadout_changed() -> void:
	if _active_skill_bar != null and _active_skill_bar.has_method("refresh"):
		_active_skill_bar.call("refresh")
	_refresh_stats()
