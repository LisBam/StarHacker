extends PanelContainer

## 局外仓库面板显示全局背包和装备栏，并提供装备、卸下与背包顺序调整操作。
## 面板只调用 GlobalInventory 能力接口，不持有独立物品副本，确保主菜单和战斗 HUD 始终读取同一份数据。

signal closed

## 仓库物品交互控件脚本；默认复用统一摘要、悬停详情、点击和拖拽协议。
const STORAGE_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/storage_item_control.gd")
## 存储拖放区域脚本；默认让仓库和背包空白区域都能接收跨容器拖拽。
const STORAGE_DROP_AREA_SCRIPT: Script = preload("res://scripts/ui/storage_drop_area.gd")

## 面板最小尺寸；默认 960x620，适配当前 1280x720 主菜单并保留边缘空间。
@export var panel_minimum_size: Vector2 = Vector2(960.0, 620.0)

## 全局背包服务；默认从自动加载 GlobalInventory 获取，缺失时面板显示不可用提示。
var _global_inventory: Node
## 背包列表容器；默认运行时创建，用于按全局仓库顺序显示物品行。
var _backpack_list: VBoxContainer
## 远程装备容器；默认运行时创建，显示双远程槽及卸下按钮。
var _ranged_equipment_list: VBoxContainer
## 近战装备容器；默认运行时创建，显示近战槽及卸下按钮。
var _melee_equipment_list: VBoxContainer
## 仓库摘要文本；默认运行时创建，显示背包数量和默认排序规则。
var _summary_label: Label
## 空仓库提示文本；默认运行时创建，背包无物品时显示。
var _empty_label: Label
## 当前是否展开随身背包；默认 false 进入纯仓库模式，只显示安全物品并允许出售。
var _backpack_expanded: bool = false
## 新版永久仓库拖放区域；默认运行时创建，上方始终显示且不参与死亡损失。
var _warehouse_drop_area: PanelContainer
## 新版永久仓库物品列表；默认运行时从拖放区域取得，用于创建可拖拽物品行。
var _warehouse_item_list: VBoxContainer
## 新版随身背包拖放区域；默认运行时创建，仅展开模式可见并会随玩家进入战斗。
var _carried_drop_area: PanelContainer
## 新版随身背包物品列表；默认运行时从拖放区域取得，用于创建快捷转仓与装备按钮。
var _carried_item_list: VBoxContainer
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
	_warehouse_drop_area.call("configure", "warehouse")
	_warehouse_drop_area.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	_warehouse_scroll.add_child(_warehouse_drop_area)
	_warehouse_item_list = _warehouse_drop_area.call("get_content_container") as VBoxContainer

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
	_carried_drop_area.call("configure", "backpack")
	_carried_drop_area.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	carried_scroll.add_child(_carried_drop_area)
	_carried_item_list = _carried_drop_area.call("get_content_container") as VBoxContainer

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


func _build_storage_entries(entries: Array, location: String, target_container: VBoxContainer) -> void:
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


func _build_storage_entry_row(entry: Dictionary, location: String, entry_index: int, entry_count: int, target_container: VBoxContainer) -> void:
	# 条目物品资源；取值应为 Resource，缺失时忽略该行避免产生无效转移请求。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return

	# 物品操作行；横向组合可拖拽详情按钮、装备或出售操作以及顺序调整按钮。
	var row: HBoxContainer = HBoxContainer.new()
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
	elif location == "backpack":
		_add_equipment_action_button(row, item_resource)

	# 上移按钮；首项禁用，其他项通过当前容器移动接口调整手工顺序。
	var move_up_button: Button = Button.new()
	move_up_button.text = "↑"
	move_up_button.disabled = entry_index <= 0
	move_up_button.pressed.connect(Callable(self, "_on_storage_move_pressed").bind(location, entry_index, entry_index - 1))
	row.add_child(move_up_button)
	# 下移按钮；末项禁用，目标使用插入到下一项之后的语义。
	var move_down_button: Button = Button.new()
	move_down_button.text = "↓"
	move_down_button.disabled = entry_index >= entry_count - 1
	move_down_button.pressed.connect(Callable(self, "_on_storage_move_pressed").bind(location, entry_index, entry_index + 2))
	row.add_child(move_down_button)


func _add_equipment_action_button(row: HBoxContainer, item_resource: Resource) -> void:
	if str(item_resource.get("weapon_type")) == "ranged":
		# 远程槽一按钮；从随身背包把武器装备到第一个远程槽，被替换武器自动回到背包。
		var equip_one_button: Button = Button.new()
		equip_one_button.text = "装1"
		equip_one_button.pressed.connect(Callable(self, "_on_equip_ranged_pressed").bind(item_resource, 0))
		row.add_child(equip_one_button)
		# 远程槽二按钮；槽位不足时禁用，当前项目默认提供两个远程槽。
		var equip_two_button: Button = Button.new()
		equip_two_button.text = "装2"
		equip_two_button.disabled = int(_global_inventory.call("get_ranged_slot_count")) < 2
		equip_two_button.pressed.connect(Callable(self, "_on_equip_ranged_pressed").bind(item_resource, 1))
		row.add_child(equip_two_button)
		return

	# 近战装备按钮；从随身背包装入近战槽，被替换武器自动回到背包。
	var equip_melee_button: Button = Button.new()
	equip_melee_button.text = "装备"
	equip_melee_button.pressed.connect(Callable(self, "_on_equip_melee_pressed").bind(item_resource))
	row.add_child(equip_melee_button)


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
		_loadout_list.add_child(_create_loadout_button("远程 %d" % (slot_index + 1), item_resource, Callable(self, "_on_unequip_ranged_pressed").bind(slot_index)))
	# 近战装备资源；空值显示空槽，有资源时点击直接卸回随身背包。
	var melee_resource: Resource = _global_inventory.call("get_melee_equipment_resource") as Resource
	_loadout_list.add_child(_create_loadout_button("近战", melee_resource, Callable(self, "_on_unequip_melee_pressed")))


func _create_loadout_button(slot_name: String, item_resource: Resource, unequip_callable: Callable) -> Button:
	# 装备槽按钮；点击非空槽会卸回随身背包，空槽禁用并等待背包装备操作。
	var slot_button: Button = Button.new()
	slot_button.text = "%s：%s" % [slot_name, _get_item_display_name(item_resource)]
	slot_button.disabled = item_resource == null
	if item_resource != null:
		# 临时详情控件；复用统一物品控件的 tooltip 构建结果，随后立即释放避免重复交互节点。
		var detail_control: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
		detail_control.call("configure", item_resource, "", -1, false)
		slot_button.tooltip_text = detail_control.tooltip_text
		detail_control.free()
		slot_button.pressed.connect(unequip_callable)
	return slot_button


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
	if item_resource == null or source_index < 0 or not target_location in ["warehouse", "backpack"]:
		return

	if source_location == target_location:
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


func _on_storage_move_pressed(location: String, source_index: int, target_index: int) -> void:
	if location == "warehouse":
		_global_inventory.call("move_warehouse_item", source_index, target_index)
	else:
		_global_inventory.call("move_backpack_item", source_index, target_index)


func _on_sell_pressed(item_resource: Resource) -> void:
	_global_inventory.call("sell_warehouse_resource", item_resource)


func _build_interface() -> void:
	# 外层边距；默认提供仓库内容与面板边缘之间的稳定留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	# 主内容容器；纵向排列标题、摘要、装备/背包双栏和返回按钮。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	# 仓库标题；默认突出显示局外仓库入口。
	var title_label: Label = Label.new()
	title_label.text = "局外仓库"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	content.add_child(title_label)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_summary_label)

	# 双栏容器；左侧显示装备，右侧显示按获得时间排序的全局背包。
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	# 装备面板；固定较窄宽度，集中显示远程和近战槽。
	var equipment_panel: PanelContainer = PanelContainer.new()
	equipment_panel.custom_minimum_size = Vector2(300.0, 0.0)
	columns.add_child(equipment_panel)
	# 装备边距；默认提供槽位文本与按钮留白。
	var equipment_margin: MarginContainer = MarginContainer.new()
	equipment_margin.add_theme_constant_override("margin_left", 12)
	equipment_margin.add_theme_constant_override("margin_top", 10)
	equipment_margin.add_theme_constant_override("margin_right", 12)
	equipment_margin.add_theme_constant_override("margin_bottom", 12)
	equipment_panel.add_child(equipment_margin)
	# 装备内容；纵向排列标题、远程槽和近战槽。
	var equipment_content: VBoxContainer = VBoxContainer.new()
	equipment_content.add_theme_constant_override("separation", 8)
	equipment_margin.add_child(equipment_content)
	# 装备标题；默认显示“当前装备”。
	var equipment_title: Label = Label.new()
	equipment_title.text = "当前装备"
	equipment_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_title.add_theme_font_size_override("font_size", 18)
	equipment_content.add_child(equipment_title)
	_ranged_equipment_list = VBoxContainer.new()
	_ranged_equipment_list.add_theme_constant_override("separation", 6)
	equipment_content.add_child(_ranged_equipment_list)
	_melee_equipment_list = VBoxContainer.new()
	_melee_equipment_list.add_theme_constant_override("separation", 6)
	equipment_content.add_child(_melee_equipment_list)

	# 背包面板；占据剩余宽度并允许大量物品滚动浏览。
	var backpack_panel: PanelContainer = PanelContainer.new()
	backpack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(backpack_panel)
	# 背包边距；默认提供列表与面板边缘留白。
	var backpack_margin: MarginContainer = MarginContainer.new()
	backpack_margin.add_theme_constant_override("margin_left", 12)
	backpack_margin.add_theme_constant_override("margin_top", 10)
	backpack_margin.add_theme_constant_override("margin_right", 12)
	backpack_margin.add_theme_constant_override("margin_bottom", 12)
	backpack_panel.add_child(backpack_margin)
	# 背包内容；纵向排列标题、空提示和滚动列表。
	var backpack_content: VBoxContainer = VBoxContainer.new()
	backpack_content.add_theme_constant_override("separation", 8)
	backpack_margin.add_child(backpack_content)
	# 背包标题；默认说明当前列表为全局共用背包。
	var backpack_title: Label = Label.new()
	backpack_title.text = "全局背包"
	backpack_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	backpack_title.add_theme_font_size_override("font_size", 18)
	backpack_content.add_child(backpack_title)
	_empty_label = Label.new()
	_empty_label.text = "仓库中没有未装备物品"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	backpack_content.add_child(_empty_label)
	# 背包滚动区；默认纵向滚动并填满剩余高度。
	var backpack_scroll: ScrollContainer = ScrollContainer.new()
	backpack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	backpack_content.add_child(backpack_scroll)
	_backpack_list = VBoxContainer.new()
	_backpack_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_list.add_theme_constant_override("separation", 6)
	backpack_scroll.add_child(_backpack_list)

	# 返回按钮；关闭仓库面板并恢复主菜单按钮焦点。
	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(0.0, 44.0)
	close_button.text = "返回主菜单"
	close_button.pressed.connect(_on_close_pressed)
	content.add_child(close_button)


func _rebuild_content() -> void:
	_clear_container(_ranged_equipment_list)
	_clear_container(_melee_equipment_list)
	_clear_container(_backpack_list)
	if _global_inventory == null:
		_summary_label.text = "全局背包服务不可用"
		_empty_label.visible = true
		return

	# 背包展示条目；每项包含资源、获得时间和上次撤离标记，顺序由全局服务决定。
	var entries: Array = _global_inventory.call("get_backpack_entries")
	_summary_label.text = "共 %d 件未装备物品 · 默认按获得时间排序 · 上次撤离携带物品优先" % entries.size()
	_empty_label.visible = entries.is_empty()
	_build_equipment_rows()

	# 背包条目索引；取值为 0 到条目数量减一，用于显示顺序调整和装备操作。
	for entry_index in range(entries.size()):
		# 背包条目原始值；取值应为 Dictionary，异常项忽略。
		var raw_entry: Variant = entries[entry_index]
		if not (raw_entry is Dictionary):
			continue
		_build_backpack_row(raw_entry as Dictionary, entry_index, entries.size())


func _build_equipment_rows() -> void:
	# 远程装备标题；默认分隔双远程槽。
	var ranged_title: Label = Label.new()
	ranged_title.text = "远程装备"
	ranged_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ranged_equipment_list.add_child(ranged_title)
	# 远程槽数量；取值来自全局服务，默认当前为 2。
	var ranged_slot_count: int = int(_global_inventory.call("get_ranged_slot_count"))
	# 远程槽索引；取值为所有远程装备槽，用于创建名称和卸下按钮。
	for slot_index in range(ranged_slot_count):
		# 远程槽资源；取值为 Resource 或 null，默认显示对应武器名或空槽。
		var item_resource: Resource = _global_inventory.call("get_ranged_equipment_resource", slot_index) as Resource
		_ranged_equipment_list.add_child(_create_equipment_row("远程 %d" % (slot_index + 1), item_resource, Callable(self, "_on_unequip_ranged_pressed").bind(slot_index)))

	# 近战装备标题；默认分隔单近战槽。
	var melee_title: Label = Label.new()
	melee_title.text = "近战装备"
	melee_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_melee_equipment_list.add_child(melee_title)
	# 近战资源；取值为 Resource 或 null，用于创建近战槽行。
	var melee_resource: Resource = _global_inventory.call("get_melee_equipment_resource") as Resource
	_melee_equipment_list.add_child(_create_equipment_row("近战", melee_resource, Callable(self, "_on_unequip_melee_pressed")))


func _create_equipment_row(slot_label: String, item_resource: Resource, unequip_callable: Callable) -> Control:
	# 装备行；横向显示槽名、武器名和卸下按钮。
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	# 装备名称；空槽显示“空”，有物品时显示资源名称。
	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = "%s：%s" % [slot_label, _get_item_display_name(item_resource)]
	row.add_child(name_label)
	# 卸下按钮；空槽时禁用，有装备时调用对应全局仓库接口。
	var unequip_button: Button = Button.new()
	unequip_button.text = "卸下"
	unequip_button.disabled = item_resource == null
	unequip_button.pressed.connect(unequip_callable)
	row.add_child(unequip_button)
	return row


func _build_backpack_row(entry: Dictionary, entry_index: int, entry_count: int) -> void:
	# 条目资源；取值应为 Resource，缺失时不创建无效操作按钮。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return
	# 物品行面板；默认用独立边框区分相邻记录。
	var row_panel: PanelContainer = PanelContainer.new()
	_backpack_list.add_child(row_panel)
	# 物品行边距；提供文本与按钮间距。
	var row_margin: MarginContainer = MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 8)
	row_margin.add_theme_constant_override("margin_top", 5)
	row_margin.add_theme_constant_override("margin_right", 8)
	row_margin.add_theme_constant_override("margin_bottom", 5)
	row_panel.add_child(row_margin)
	# 物品行；横向显示名称、获得时间标记与操作按钮。
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row_margin.add_child(row)
	# 物品说明；上次撤离物品带“撤离”前缀，便于确认优先排序来源。
	var item_label: Label = Label.new()
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 上次撤离前缀；只有当前最后一次成功撤离携带记录显示。
	var extraction_prefix: String = "[上次撤离] " if bool(entry.get("is_last_extraction", false)) else ""
	item_label.text = "%s%s · %s" % [extraction_prefix, _get_item_display_name(item_resource), _get_weapon_type_label(item_resource)]
	row.add_child(item_label)

	if str(item_resource.get("weapon_type")) == "ranged":
		# 远程槽一按钮；把当前背包武器原子替换到远程槽 1。
		var equip_one_button: Button = Button.new()
		equip_one_button.text = "装1"
		equip_one_button.pressed.connect(Callable(self, "_on_equip_ranged_pressed").bind(item_resource, 0))
		row.add_child(equip_one_button)
		# 远程槽二按钮；把当前背包武器原子替换到远程槽 2。
		var equip_two_button: Button = Button.new()
		equip_two_button.text = "装2"
		equip_two_button.disabled = int(_global_inventory.call("get_ranged_slot_count")) < 2
		equip_two_button.pressed.connect(Callable(self, "_on_equip_ranged_pressed").bind(item_resource, 1))
		row.add_child(equip_two_button)
	else:
		# 近战装备按钮；把当前背包武器原子替换到近战槽。
		var equip_melee_button: Button = Button.new()
		equip_melee_button.text = "装备"
		equip_melee_button.pressed.connect(Callable(self, "_on_equip_melee_pressed").bind(item_resource))
		row.add_child(equip_melee_button)

	# 上移按钮；首项禁用，其他项按现有背包移动接口调整顺序。
	var move_up_button: Button = Button.new()
	move_up_button.text = "↑"
	move_up_button.disabled = entry_index <= 0
	move_up_button.pressed.connect(Callable(self, "_on_move_item_pressed").bind(entry_index, entry_index - 1))
	row.add_child(move_up_button)
	# 下移按钮；末项禁用，目标索引使用现有插入语义向后移动一位。
	var move_down_button: Button = Button.new()
	move_down_button.text = "↓"
	move_down_button.disabled = entry_index >= entry_count - 1
	move_down_button.pressed.connect(Callable(self, "_on_move_item_pressed").bind(entry_index, entry_index + 2))
	row.add_child(move_down_button)


func _clear_container(container: Node) -> void:
	if container == null:
		return
	# 旧 UI 子节点；取值为容器直接子节点，重建前全部排队释放。
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _get_item_display_name(item_resource: Resource) -> String:
	if item_resource == null:
		return "空"
	# 显示名称；取值来自武器资源，空值时回退 weapon_id。
	var display_name: String = str(item_resource.get("display_name"))
	return str(item_resource.get("weapon_id")) if display_name.is_empty() else display_name


func _get_weapon_type_label(item_resource: Resource) -> String:
	if item_resource == null:
		return "未知"
	return "远程" if str(item_resource.get("weapon_type")) == "ranged" else "近战"


func _on_equip_ranged_pressed(item_resource: Resource, slot_index: int) -> void:
	_global_inventory.call("warehouse_equip_ranged", item_resource, slot_index)


func _on_equip_melee_pressed(item_resource: Resource) -> void:
	_global_inventory.call("warehouse_equip_melee", item_resource)


func _on_unequip_ranged_pressed(slot_index: int) -> void:
	_global_inventory.call("warehouse_unequip_ranged", slot_index)


func _on_unequip_melee_pressed() -> void:
	_global_inventory.call("warehouse_unequip_melee")


func _on_move_item_pressed(source_index: int, target_index: int) -> void:
	_global_inventory.call("move_backpack_item", source_index, target_index)


func _on_close_pressed() -> void:
	closed.emit()
