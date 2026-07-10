extends PanelContainer

## 局外仓库面板显示全局背包和装备栏，并提供装备、卸下与背包顺序调整操作。
## 面板只调用 GlobalInventory 能力接口，不持有独立物品副本，确保主菜单和战斗 HUD 始终读取同一份数据。

signal closed

## 仓库物品交互控件脚本；默认复用统一摘要、悬停详情、点击和拖拽协议。
const STORAGE_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/storage_item_control.gd")
## 存储拖放区域脚本；默认让仓库和背包空白区域都能接收跨容器拖拽。
const STORAGE_DROP_AREA_SCRIPT: Script = preload("res://scripts/ui/storage_drop_area.gd")
## 局外装备拖拽槽脚本；默认负责远近战类型校验以及装备栏双向拖拽数据生成。
const EQUIPMENT_STORAGE_SLOT_SCRIPT: Script = preload("res://scripts/ui/equipment_storage_slot_control.gd")

## 面板最小尺寸；默认 960x620，适配当前 1280x720 主菜单并保留边缘空间。
@export var panel_minimum_size: Vector2 = Vector2(960.0, 620.0)

## 全局背包服务；默认从自动加载 GlobalInventory 获取，缺失时面板显示不可用提示。
var _global_inventory: Node
## 当前是否展开随身背包；默认 false 进入纯仓库模式，只显示安全物品并允许出售。
var _backpack_expanded: bool = false
## 新版永久仓库拖放区域；默认运行时创建，上方始终显示且不参与死亡损失。
var _warehouse_drop_area: PanelContainer
## 新版永久仓库物品列表；默认运行时从拖放区域取得，用于创建可拖拽物品行。
var _warehouse_item_list: GridContainer
## 新版随身背包拖放区域；默认运行时创建，仅展开模式可见并会随玩家进入战斗。
var _carried_drop_area: PanelContainer
## 新版随身背包物品列表；默认运行时从拖放区域取得，用于创建快捷转仓与装备按钮。
var _carried_item_list: GridContainer
## 新版装备栏容器；默认运行时创建并固定在展开背包区域左侧。
var _loadout_list: VBoxContainer
## 新版背包区域根容器；默认隐藏，切换显示模式后控制下半区整体可见性。
var _backpack_section: VBoxContainer
## 新版仓库滚动容器；默认填充纯仓库模式，展开背包后限制高度给下半区留出空间。
var _warehouse_scroll: ScrollContainer
## 新版模式切换按钮；默认显示“展开背包”，点击后在纯仓库和仓库背包联合模式间切换。
var _mode_toggle_button: Button
## 新版金币标签；默认显示局外金币余额，出售永久仓库物品后即时刷新。
var _coins_label: Label
## 新版仓库摘要标签；默认显示永久仓库与随身背包数量，并明确安全和死亡损失边界。
var _storage_summary_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = panel_minimum_size
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_storage_interface()
	if _global_inventory != null:
		if _global_inventory.has_signal("inventory_changed"):
			_global_inventory.connect("inventory_changed", Callable(self, "_rebuild_storage_content"))
		if _global_inventory.has_signal("equipment_changed"):
			_global_inventory.connect("equipment_changed", Callable(self, "_rebuild_storage_content"))
		if _global_inventory.has_signal("warehouse_changed"):
			_global_inventory.connect("warehouse_changed", Callable(self, "_rebuild_storage_content"))
		if _global_inventory.has_signal("coins_changed"):
			_global_inventory.connect("coins_changed", Callable(self, "_rebuild_storage_content"))
	_rebuild_storage_content()


func _build_storage_interface() -> void:
	# 新版外层边距；默认让联合仓库界面在主菜单遮罩内保持稳定留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	# 新版主内容容器；纵向排列标题栏、永久仓库、可折叠背包与返回按钮。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	# 新版标题栏；横向显示仓库标题、局外金币和模式切换按钮。
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	# 新版仓库标题；默认左对齐并占据标题栏剩余空间。
	var title_label: Label = Label.new()
	title_label.text = "局外永久仓库"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 25)
	header.add_child(title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_coins_label)
	_mode_toggle_button = Button.new()
	_mode_toggle_button.custom_minimum_size = Vector2(128.0, 38.0)
	_mode_toggle_button.pressed.connect(_on_mode_toggle_pressed)
	header.add_child(_mode_toggle_button)

	_storage_summary_label = Label.new()
	_storage_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_storage_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_storage_summary_label)

	# 永久仓库标题；始终位于界面上方并说明安全存储属性。
	var warehouse_title: Label = Label.new()
	warehouse_title.text = "永久仓库 · 未放入背包的物品不会因死亡或退出丢失"
	warehouse_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warehouse_title.add_theme_font_size_override("font_size", 17)
	content.add_child(warehouse_title)

	_warehouse_scroll = ScrollContainer.new()
	_warehouse_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_warehouse_scroll)
	_warehouse_drop_area = STORAGE_DROP_AREA_SCRIPT.new() as PanelContainer
	_warehouse_drop_area.custom_minimum_size = Vector2(0.0, 220.0)
	_warehouse_drop_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warehouse_drop_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_warehouse_drop_area.call("configure", "warehouse", 2)
	_warehouse_drop_area.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	_warehouse_scroll.add_child(_warehouse_drop_area)
	_warehouse_item_list = _warehouse_drop_area.call("get_content_container") as GridContainer

	_backpack_section = VBoxContainer.new()
	_backpack_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backpack_section.add_theme_constant_override("separation", 6)
	content.add_child(_backpack_section)
	# 随身区标题；默认强调下半区会进入战斗并参与失败损失结算。
	var backpack_title: Label = Label.new()
	backpack_title.text = "随身背包 · 会带入战斗，死亡或主动退出时随机保留约 20%"
	backpack_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	backpack_title.add_theme_font_size_override("font_size", 17)
	_backpack_section.add_child(backpack_title)

	# 随身区双栏；左侧固定装备槽，右侧显示背包物品并接收仓库拖拽。
	var carried_columns: HBoxContainer = HBoxContainer.new()
	carried_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carried_columns.add_theme_constant_override("separation", 10)
	_backpack_section.add_child(carried_columns)
	# 装备栏面板；默认宽 270 像素，满足背包左侧划分装备栏的布局要求。
	var loadout_panel: PanelContainer = PanelContainer.new()
	loadout_panel.custom_minimum_size = Vector2(270.0, 0.0)
	carried_columns.add_child(loadout_panel)
	# 装备栏边距；默认提供槽位按钮与边框之间的可读留白。
	var loadout_margin: MarginContainer = MarginContainer.new()
	loadout_margin.add_theme_constant_override("margin_left", 10)
	loadout_margin.add_theme_constant_override("margin_top", 8)
	loadout_margin.add_theme_constant_override("margin_right", 10)
	loadout_margin.add_theme_constant_override("margin_bottom", 8)
	loadout_panel.add_child(loadout_margin)
	_loadout_list = VBoxContainer.new()
	_loadout_list.add_theme_constant_override("separation", 6)
	loadout_margin.add_child(_loadout_list)

	# 随身背包滚动区；默认填充双栏剩余宽度和高度，物品可点击快速转仓或拖拽调整。
	var carried_scroll: ScrollContainer = ScrollContainer.new()
	carried_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carried_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carried_columns.add_child(carried_scroll)
	_carried_drop_area = STORAGE_DROP_AREA_SCRIPT.new() as PanelContainer
	_carried_drop_area.custom_minimum_size = Vector2(0.0, 215.0)
	_carried_drop_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_carried_drop_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_carried_drop_area.call("configure", "backpack", 2)
	_carried_drop_area.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	carried_scroll.add_child(_carried_drop_area)
	_carried_item_list = _carried_drop_area.call("get_content_container") as GridContainer

	# 新版返回按钮；关闭仓库面板并恢复主菜单交互。
	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.text = "返回主菜单"
	close_button.pressed.connect(_on_close_pressed)
	content.add_child(close_button)
	_apply_storage_display_mode()


func _rebuild_storage_content() -> void:
	_clear_container(_warehouse_item_list)
	_clear_container(_carried_item_list)
	_clear_container(_loadout_list)
	if _global_inventory == null:
		_coins_label.text = "金币：不可用"
		_storage_summary_label.text = "全局物品服务不可用"
		return

	# 永久仓库条目；顺序由全局服务按上次撤离优先和获得时间维护。
	var warehouse_entries: Array = _global_inventory.call("get_warehouse_entries")
	# 随身背包条目；顺序只影响当前携带布局，进入战斗后由 HUD 读取同一数组。
	var backpack_entries: Array = _global_inventory.call("get_backpack_entries")
	_coins_label.text = "金币：%d" % int(_global_inventory.call("get_coins"))
	_storage_summary_label.text = "永久仓库 %d 件 · 随身背包 %d 件 · %s" % [warehouse_entries.size(), backpack_entries.size(), "点击仓库物品可装入背包，点击背包物品可存入仓库" if _backpack_expanded else "当前可出售永久仓库物品"]
	_build_storage_entries(warehouse_entries, "warehouse", _warehouse_item_list)
	if _backpack_expanded:
		_build_storage_entries(backpack_entries, "backpack", _carried_item_list)
		_build_loadout_entries()


func _build_storage_entries(entries: Array, location: String, target_container: Container) -> void:
	if target_container == null:
		return
	if entries.is_empty():
		# 空容器提示；根据所在区域明确物品安全属性和快捷转移方向。
		var empty_state_label: Label = Label.new()
		empty_state_label.text = "永久仓库为空" if location == "warehouse" else "随身背包为空，可点击或拖入上方仓库物品"
		empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_state_label.custom_minimum_size = Vector2(0.0, 52.0)
		target_container.add_child(empty_state_label)
		return

	# 展示条目索引；取值为列表所有有效下标，用于拖拽排序和上下移动按钮目标计算。
	for entry_index in range(entries.size()):
		# 展示条目原始值；取值应为 Dictionary，异常数据不会生成可操作控件。
		var raw_entry: Variant = entries[entry_index]
		if raw_entry is Dictionary:
			_build_storage_entry_row(raw_entry as Dictionary, location, entry_index, entries.size(), target_container)


func _build_storage_entry_row(entry: Dictionary, location: String, entry_index: int, _entry_count: int, target_container: Container) -> void:
	# 条目物品资源；取值应为 Resource，缺失时忽略该行避免产生无效转移请求。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return

	# 物品操作行；横向组合可拖拽详情按钮、装备或出售操作以及顺序调整按钮。
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 44.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	target_container.add_child(row)
	# 上次撤离前缀；只有自动转入永久仓库且属于最近一次成功撤离的物品显示。
	var extraction_prefix: String = "[上次撤离] " if bool(entry.get("is_last_extraction", false)) else ""
	# 物品控件；展开模式允许点击跨容器转移，纯仓库模式只提供浏览、拖拽和出售。
	var item_control: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
	item_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_control.call("configure", item_resource, location, entry_index, _backpack_expanded, extraction_prefix)
	item_control.connect("quick_action_requested", Callable(self, "_on_quick_action_requested").bind(location))
	item_control.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	row.add_child(item_control)

	if location == "warehouse" and not _backpack_expanded:
		# 出售按钮；纯仓库模式显示固定售价，点击后永久移除物品并增加局外金币。
		var sell_button: Button = Button.new()
		sell_button.text = "出售 +%d" % maxi(int(item_resource.get("sell_price")), 0)
		sell_button.disabled = int(item_resource.get("sell_price")) <= 0
		sell_button.pressed.connect(Callable(self, "_on_sell_pressed").bind(item_resource))
		row.add_child(sell_button)


func _build_loadout_entries() -> void:
	# 装备栏标题；默认说明槽内物品随角色使用但不属于永久仓库。
	var loadout_title: Label = Label.new()
	loadout_title.text = "装备栏"
	loadout_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loadout_title.add_theme_font_size_override("font_size", 18)
	_loadout_list.add_child(loadout_title)
	# 远程槽数量；取值来自全局服务，当前默认双远程槽。
	var ranged_slot_count: int = int(_global_inventory.call("get_ranged_slot_count"))
	# 远程槽索引；取值为全部有效远程槽，用于建立可卸下按钮。
	for slot_index in range(ranged_slot_count):
		# 远程装备资源；空值显示空槽，有资源时悬停可查看武器详细属性。
		var item_resource: Resource = _global_inventory.call("get_ranged_equipment_resource", slot_index) as Resource
		_loadout_list.add_child(_create_storage_equipment_slot("远程 %d" % (slot_index + 1), "ranged_%d" % slot_index, "ranged", item_resource))
	# 近战装备资源；空值显示可接收近战武器的槽位，有资源时可拖往仓库或随身背包。
	var melee_resource: Resource = _global_inventory.call("get_melee_equipment_resource") as Resource
	_loadout_list.add_child(_create_storage_equipment_slot("近战", "melee", "melee", melee_resource))


func _create_storage_equipment_slot(slot_label: String, location: String, weapon_type: String, item_resource: Resource) -> Control:
	# 装备槽控件；取值为独立拖拽组件，既可把装备拖出到存储区，也可接收仓库或背包武器。
	var slot_control: Control = EQUIPMENT_STORAGE_SLOT_SCRIPT.new() as Control
	# 装备详情文本；空槽保持空字符串并由槽控件显示类型提示，有装备时复用完整武器悬停详情。
	var detail_tooltip: String = _get_item_detail_tooltip(item_resource)
	slot_control.call("configure", slot_label, location, weapon_type, item_resource, detail_tooltip)
	slot_control.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	slot_control.custom_minimum_size = Vector2(0.0, 54.0)
	return slot_control


func _get_item_detail_tooltip(item_resource: Resource) -> String:
	if item_resource == null:
		return ""
	# 临时物品控件；复用统一详情生成逻辑，只读取 tooltip 后立即释放，不加入场景树。
	var detail_control: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
	detail_control.call("configure", item_resource, "", -1, false)
	# 完整悬停详情；取值来自统一物品控件，避免装备槽与仓库显示字段不一致。
	var detail_tooltip: String = detail_control.tooltip_text
	detail_control.free()
	return detail_tooltip


func _apply_storage_display_mode() -> void:
	_backpack_section.visible = _backpack_expanded
	_mode_toggle_button.text = "收起背包" if _backpack_expanded else "展开背包"
	_warehouse_scroll.custom_minimum_size = Vector2(0.0, 220.0 if _backpack_expanded else 430.0)
	_warehouse_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if _backpack_expanded else Control.SIZE_EXPAND_FILL


func _on_mode_toggle_pressed() -> void:
	_backpack_expanded = not _backpack_expanded
	_apply_storage_display_mode()
	_rebuild_storage_content()


func _on_quick_action_requested(item_resource: Resource, source_location: String) -> void:
	if not _backpack_expanded or _global_inventory == null:
		return
	if source_location == "warehouse":
		_global_inventory.call("transfer_warehouse_to_backpack", item_resource)
	elif source_location == "backpack":
		_global_inventory.call("transfer_backpack_to_warehouse", item_resource)


func _on_item_drop_requested(drag_data: Dictionary, target_location: String, target_index: int) -> void:
	if _global_inventory == null:
		return
	# 拖拽物品资源；取值应为全局服务当前持有的 Resource，异常数据直接忽略。
	var item_resource: Resource = drag_data.get("resource") as Resource
	# 拖拽来源容器；取值为 warehouse 或 backpack，用于决定容器内排序或跨容器转移。
	var source_location: String = str(drag_data.get("source_location", ""))
	# 拖拽来源索引；取值大于等于 0，同容器排序时用于精确移动记录。
	var source_index: int = int(drag_data.get("source_index", -1))
	if item_resource == null:
		return
	# 来源是否为存储容器；仓库和背包支持列表内排序、互转以及拖入装备槽。
	var source_is_storage: bool = source_location in ["warehouse", "backpack"]
	# 目标是否为存储容器；装备可拖入仓库或背包，存储物品也可以投放到具体装备槽。
	var target_is_storage: bool = target_location in ["warehouse", "backpack"]
	if source_is_storage and source_index < 0:
		return

	if source_is_storage and target_is_storage and source_location == target_location:
		# 容器末尾目标；空白区域使用 -1，转换为当前容器记录数量以匹配移动接口插入语义。
		var resolved_target_index: int = target_index
		if resolved_target_index < 0:
			resolved_target_index = int(_global_inventory.call("get_warehouse_count")) if target_location == "warehouse" else int(_global_inventory.call("get_backpack_count"))
		_global_inventory.call("move_warehouse_item" if target_location == "warehouse" else "move_backpack_item", source_index, resolved_target_index)
		return

	if source_location == "warehouse" and target_location == "backpack":
		_global_inventory.call("transfer_warehouse_to_backpack", item_resource, target_index)
	elif source_location == "backpack" and target_location == "warehouse":
		_global_inventory.call("transfer_backpack_to_warehouse", item_resource, target_index)
	elif source_is_storage and not target_is_storage:
		_global_inventory.call("transfer_storage_to_equipment", item_resource, source_location, target_location)
	elif not source_is_storage and target_is_storage:
		_global_inventory.call("transfer_equipment_to_storage", source_location, target_location, target_index)
	elif not source_is_storage and not target_is_storage:
		_global_inventory.call("swap_equipment_locations", source_location, target_location)


func _on_sell_pressed(item_resource: Resource) -> void:
	_global_inventory.call("sell_warehouse_resource", item_resource)


func _clear_container(container: Node) -> void:
	if container == null:
		return
	# 现有列表子节点；取值为容器直接子节点，数据刷新前全部排队释放。
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_close_pressed() -> void:
	closed.emit()
