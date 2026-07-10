extends PanelContainer

## 局外仓库面板显示全局背包和装备栏，并提供装备、卸下与背包顺序调整操作。
## 面板只调用 GlobalInventory 能力接口，不持有独立物品副本，确保主菜单和战斗 HUD 始终读取同一份数据。

signal closed

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = panel_minimum_size
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	if _global_inventory != null:
		if _global_inventory.has_signal("inventory_changed"):
			_global_inventory.connect("inventory_changed", Callable(self, "_rebuild_content"))
		if _global_inventory.has_signal("equipment_changed"):
			_global_inventory.connect("equipment_changed", Callable(self, "_rebuild_content"))
	_rebuild_content()


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
