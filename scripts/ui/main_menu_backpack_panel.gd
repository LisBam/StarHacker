extends PanelContainer
class_name SharedBackpackPanel

## 主菜单背包面板复用战斗背包的“左侧装备栏 + 右侧随身物品”结构和标准物品卡片。
## 局外没有地面掉落容器，因此丢弃操作直接永久移除对应背包记录，不生成可重新拾取的物品。

signal closed
## 仓库打开请求；仅局外背包右上角按钮发出，宿主负责关闭背包遮罩并展示已有仓库面板。
signal warehouse_requested
## 丢弃请求；战斗上下文由 CombatHud 生成地面掉落，局外上下文由组件直接永久删除。
signal combat_discard_requested(item_resource: Resource, quantity: int)

## 全局窗口样式指南；统一局外与局内共享背包的主窗口、装备分区、查询和操作控件视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 主菜单上下文标识；丢弃直接永久删除，其他装备、修复和查询行为与战斗一致。
const CONTEXT_MAIN_MENU: String = "main_menu"
## 战斗上下文标识；丢弃请求交给 CombatHud 生成地面掉落。
const CONTEXT_COMBAT: String = "combat"

## 仓库物品卡片脚本；随身物品复用完整详情、耐久条、点击和悬停交互。
const STORAGE_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/storage_item_control.gd")
## 物品详情格式化器；局外出售数量弹窗读取统一物品单价，避免不同面板计算不一致。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 通用物品卡片视图；左侧装备栏读取其悬浮安全留白，避免放大后的装备卡牌被滚动区裁剪。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 装备槽控件脚本；远程、近战和四部位装备复用游戏内背包左侧卡片布局。
const EQUIPMENT_STORAGE_SLOT_SCRIPT: Script = preload("res://scripts/ui/equipment_storage_slot_control.gd")
## 背包空白拖放区域脚本；装备可拖到右侧空白处卸下，背包物品也可通过拖放调整顺序。
const STORAGE_DROP_AREA_SCRIPT: Script = preload("res://scripts/ui/storage_drop_area.gd")
## 标准物品操作弹窗脚本；装备和丢弃操作复用全项目功能按钮资源。
const ITEM_ACTION_POPUP_SCRIPT: Script = preload("res://scripts/ui/item_action_popup.gd")
## 数量选择弹窗脚本；堆叠物品部分丢弃时复用战斗背包相同数量输入界面。
const SELL_QUANTITY_DIALOG_SCRIPT: Script = preload("res://scripts/ui/sell_quantity_dialog.gd")
## 角色属性面板脚本；共享背包在主菜单和战斗中复用同一“基础值+额外值”展示组件。
const CHARACTER_STATS_PANEL_SCRIPT: Script = preload("res://scripts/ui/character_stats_panel.gd")
## 套装筛选控件脚本；装备分类使用与强化石筛选一致的多选与清空交互。
const EQUIPMENT_SET_FILTER_CONTROL_SCRIPT: Script = preload("res://scripts/ui/equipment_set_filter_control.gd")
## 库存限制配置；容量标签在全局库存服务缺失时仍使用项目统一的 50 组上限兜底。
const INVENTORY_LIMITS: Script = preload("res://scripts/data/inventory_limits.gd")
## 装备操作编号；背包武器或装备点击后按类型进入对应装备槽。
const ACTION_EQUIP: int = 1
## 远程装备槽一操作编号；远程武器可明确选择第一个远程槽。
const ACTION_EQUIP_RANGED_ONE: int = 2
## 远程装备槽二操作编号；远程武器可明确选择第二个远程槽。
const ACTION_EQUIP_RANGED_TWO: int = 3
## 全部丢弃操作编号；单件物品和整组堆叠共同使用。
const ACTION_DISCARD_ALL: int = 4
## 部分丢弃操作编号；只在堆叠数量大于一时显示。
const ACTION_DISCARD_PARTIAL: int = 5
## 卸下装备操作编号；点击左侧非空装备槽后把物品移动回背包。
const ACTION_UNEQUIP: int = 6
## 使用修复包操作编号；点击后进入背包与装备栏耐久目标选择状态。
const ACTION_USE_REPAIR_KIT: int = 7
## 使用消耗品操作编号；仅战斗背包显示，成功施加临时效果后扣除一个对应道具。
const ACTION_USE_CONSUMABLE: int = 8

## 面板最小尺寸；与战斗背包接近，确保左侧七个装备槽和右侧物品网格可读。
@export var panel_minimum_size: Vector2 = Vector2(960.0, 620.0)

## 全局库存服务；负责背包、装备栏、直接丢弃和持久化。
var _global_inventory: Node
## 左侧装备栏列表；每次装备变化后完整重建，保持槽位顺序稳定。
var _equipment_list: VBoxContainer
## 左侧装备页滚动容器；切换到角色页时隐藏，垂直滚动条始终可拖动。
var _equipment_scroll: ScrollContainer
## 左侧角色属性页；展示总值、基础值和全部额外贡献，切换到装备页时隐藏。
var _character_stats_panel: CharacterStatsPanel
## 左侧角色页滚动容器；窄栏文本换行后仍可拖动查看全部九项属性。
var _character_scroll: ScrollContainer
## 角色页签按钮；用于显示角色属性并同步按钮禁用状态。
var _character_tab_button: Button
## 装备页签按钮；默认选中并显示现有装备槽列表。
var _equipment_tab_button: Button
## 战斗属性组件；默认空表示主菜单上下文，由 CombatHud 在加入场景树前注入。
var _runtime_stats_component: Node
## 战斗装备组件；默认空表示主菜单上下文，由 CombatHud 在加入场景树前注入。
var _runtime_equipment_component: Node
## 战斗临时增益组件；默认空表示主菜单没有玩家实体，战斗背包用它安全应用能量饮料与可乐效果。
var _runtime_temporary_buff_component: Node
## 右侧背包物品网格；按真实背包顺序显示全部物品。
var _item_grid: HFlowContainer
## 背包拖放区域；接收装备拖到右侧空白处的卸下操作和背包内部排序。
var _backpack_drop_area: PanelContainer
## 标准物品操作弹窗；根据当前物品类型生成装备和丢弃功能按钮。
var _action_popup: ItemActionPopup
## 部分丢弃数量弹窗；确认后从背包直接消费选择数量。
var _quantity_dialog: SellQuantityDialog
## 当前操作物品；弹窗关闭前保持精确资源实例引用。
var _action_resource: Resource
## 当前操作物品真实数量；用于决定全部或部分丢弃入口。
var _action_quantity: int = 1
## 等待部分丢弃的资源；数量确认后读取并立即清空，防止重复确认。
var _pending_partial_resource: Resource
## 当前操作装备位置；点击装备槽后保存 ranged_N、melee 或 armor_部位，用于卸下操作。
var _action_equipment_location: String = ""
## 待使用修复包资源；非空时下一次点击兼容武器或装备会尝试修复。
var _pending_repair_kit_resource: Resource
## 待使用修复包来源；主菜单背包固定为 backpack，但仍保存稳定来源供拖放和服务接口复用。
var _pending_repair_kit_location: String = ""
## 修复目标选择状态文本；显示当前修复包名称、成功恢复量或取消提示。
var _status_label: Label
## 取消修复包使用按钮；只在目标选择期间显示，避免玩家被锁定在选择状态。
var _cancel_use_button: Button
## 局外仓库快捷按钮；默认仅主菜单上下文显示，点击后由主菜单宿主切换到仓库界面。
var _warehouse_button: Button
## 背包容量标签；固定显示当前物品组数与 50 组上限，并与二级分类栏保持同一垂直高度。
var _capacity_label: Label
## 当前运行上下文；默认主菜单，必须在加入场景树前通过 configure_context 修改。
var _context_mode: String = CONTEXT_MAIN_MENU
## 当前一级分类；默认全部，取值与 InventoryQuery 主分类常量一致。
var _primary_category: String = InventoryQuery.PRIMARY_ALL
## 当前二级分类；默认全部，切换一级分类时重置并重建按钮。
var _subcategory: String = InventoryQuery.SUBCATEGORY_ALL
## 当前排序模式；默认获得时间，可切换物品价值或耐久降序。
var _sort_mode: String = InventoryQuery.SORT_ACQUIRED_TIME
## 当前强化石属性方向筛选集合；默认空数组表示不过滤词条，多项条件按并集匹配。
var _stone_attribute_filter: Array[String] = []
## 关键词搜索框；按名称、说明、分类和强化词条实时过滤右侧背包物品。
var _search_edit: LineEdit
## 排序下拉框；提供获得时间、物品价值和耐久三种统一排序。
var _sort_option: OptionButton
## 强化词条筛选下拉框；只在资源分类显示并支持多项属性方向勾选。
var _stone_attribute_option: OptionButton
## 清空强化筛选按钮；当前没有筛选条件时禁用。
var _stone_attribute_clear_button: Button
## 套装多选筛选控件；只在装备分类显示，并根据当前背包条目动态列出可用套装。
var _equipment_set_filter_control: EquipmentSetFilterControl
## 一级分类按钮表；用于同步全部、武器、装备和资源的选中状态。
var _primary_buttons: Dictionary = {}
## 二级分类按钮表；根据当前一级分类动态重建。
var _subcategory_buttons: Dictionary = {}
## 二级分类按钮栏；武器、装备和资源显示各自子分类。
var _subcategory_bar: HBoxContainer
## 库存刷新是否已排队；默认 false，同一帧连续收到库存与装备信号时只在帧末重建一次可见面板。
var _refresh_queued: bool = false
## 隐藏期间库存是否发生变化；默认 false，隐藏面板不创建物品卡片，下一次宿主打开面板时通过公开刷新入口同步最新状态。
var _refresh_pending: bool = false


func _ready() -> void:
	custom_minimum_size = panel_minimum_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	_connect_inventory_signals()
	_refresh_all()


func configure_context(context_mode: String) -> void:
	# 上下文模式；只接受主菜单或战斗两个稳定值，异常输入回退主菜单安全策略。
	_context_mode = context_mode if context_mode in [CONTEXT_MAIN_MENU, CONTEXT_COMBAT] else CONTEXT_MAIN_MENU
	if _warehouse_button != null:
		_warehouse_button.visible = _context_mode == CONTEXT_MAIN_MENU


func configure_runtime_character_components(stats_component: Node, equipment_component: Node, temporary_buff_component: Node = null) -> void:
	## 注入战斗中的实时角色组件；主菜单不调用并自动读取角色档案与全局装备，临时增益组件只在战斗背包使用消耗品时读取。
	_runtime_stats_component = stats_component
	_runtime_equipment_component = equipment_component
	_runtime_temporary_buff_component = temporary_buff_component
	if _character_stats_panel != null:
		_character_stats_panel.configure_runtime_components(_runtime_stats_component, _runtime_equipment_component)


func refresh() -> void:
	## 公开刷新入口；宿主在打开面板或上下文数据批量变化后调用，不需要了解组件内部控件结构。
	_refresh_queued = false
	_refresh_pending = false
	_refresh_all()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	# 外层边距；与战斗背包保持足够留白，避免卡片贴边。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	# 主内容；标题栏位于顶部，装备与背包使用左右分栏填充剩余区域。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var header: HBoxContainer = HBoxContainer.new()
	content.add_child(header)
	var title_label: Label = Label.new()
	title_label.text = "背包"
	title_label.add_theme_font_size_override("font_size", 25)
	UI_STYLE_GUIDE.apply_title_label(title_label)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	_cancel_use_button = Button.new()
	_cancel_use_button.text = "取消使用"
	_cancel_use_button.visible = false
	_cancel_use_button.pressed.connect(_cancel_repair_kit_use)
	header.add_child(_cancel_use_button)
	_warehouse_button = Button.new()
	_warehouse_button.text = "仓库"
	_warehouse_button.custom_minimum_size = Vector2(90.0, 36.0)
	_warehouse_button.visible = _context_mode == CONTEXT_MAIN_MENU
	_warehouse_button.pressed.connect(func() -> void: warehouse_requested.emit())
	header.add_child(_warehouse_button)
	var close_button: Button = Button.new()
	close_button.text = "关闭背包"
	close_button.custom_minimum_size = Vector2(116.0, 36.0)
	close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_button)
	# 查询栏；布局和功能与游戏内背包一致，只作用于右侧随身物品列表。
	var query_bar: HBoxContainer = HBoxContainer.new()
	query_bar.add_theme_constant_override("separation", 7)
	content.add_child(query_bar)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索物品、分类或强化词条"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(func(_text: String) -> void: _rebuild_items())
	query_bar.add_child(_search_edit)
	_sort_option = OptionButton.new()
	_sort_option.add_item("获得时间")
	_sort_option.set_item_metadata(0, InventoryQuery.SORT_ACQUIRED_TIME)
	_sort_option.add_item("物品价值")
	_sort_option.set_item_metadata(1, InventoryQuery.SORT_ITEM_VALUE)
	_sort_option.add_item("耐久")
	_sort_option.set_item_metadata(2, InventoryQuery.SORT_DURABILITY)
	_sort_option.item_selected.connect(_on_sort_selected)
	query_bar.add_child(_sort_option)
	_stone_attribute_option = OptionButton.new()
	_stone_attribute_option.custom_minimum_size = Vector2(148.0, 34.0)
	_stone_attribute_option.add_item("强化筛选（0）")
	_stone_attribute_option.set_item_metadata(0, "")
	for direction in InventoryQuery.STONE_FILTER_DIRECTIONS:
		_stone_attribute_option.add_separator(InventoryQuery.get_stone_attribute_direction_group_label(direction))
		for stat_name in EnhancementRules.STAT_KEYS:
			_stone_attribute_option.add_item(InventoryQuery.get_stone_attribute_filter_label(stat_name, (1 if EnhancementRules.is_direction_beneficial(stat_name, 1) == (direction > 0) else -1)))
			var filter_index: int = _stone_attribute_option.item_count - 1
			_stone_attribute_option.set_item_metadata(filter_index, InventoryQuery.build_stone_attribute_filter_key(stat_name, (1 if EnhancementRules.is_direction_beneficial(stat_name, 1) == (direction > 0) else -1)))
			_stone_attribute_option.get_popup().set_item_as_checkable(filter_index, true)
	_stone_attribute_option.get_popup().hide_on_checkable_item_selection = false
	_stone_attribute_option.item_selected.connect(_on_stone_attribute_selected)
	query_bar.add_child(_stone_attribute_option)
	_stone_attribute_clear_button = Button.new()
	_stone_attribute_clear_button.text = "清空筛选"
	_stone_attribute_clear_button.pressed.connect(_clear_stone_attribute_filter)
	query_bar.add_child(_stone_attribute_clear_button)
	_equipment_set_filter_control = EQUIPMENT_SET_FILTER_CONTROL_SCRIPT.new() as EquipmentSetFilterControl
	_equipment_set_filter_control.filters_changed.connect(_on_equipment_set_filters_changed)
	query_bar.add_child(_equipment_set_filter_control)
	# 分类栏；一级分类固定一行，二级分类根据当前类型动态变化。
	var category_columns: VBoxContainer = VBoxContainer.new()
	category_columns.add_theme_constant_override("separation", 3)
	content.add_child(category_columns)
	var primary_bar: HBoxContainer = HBoxContainer.new()
	primary_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	category_columns.add_child(primary_bar)
	_create_category_button(primary_bar, "全部", InventoryQuery.PRIMARY_ALL, true)
	_create_category_button(primary_bar, "武器", InventoryQuery.PRIMARY_WEAPONS, true)
	_create_category_button(primary_bar, "装备", InventoryQuery.PRIMARY_EQUIPMENT, true)
	_create_category_button(primary_bar, "资源", InventoryQuery.PRIMARY_RESOURCES, true)
	# 二级分类行；左侧弹性空间保持分类居中，右侧固定显示完整背包组数与上限。
	var subcategory_row: HBoxContainer = HBoxContainer.new()
	category_columns.add_child(subcategory_row)
	# 二级分类左侧占位；与右侧容量标签使用相同最小宽度，使分类按钮保持页面中心对齐。
	var subcategory_left_spacer: Control = Control.new()
	subcategory_left_spacer.custom_minimum_size = Vector2(92.0, 0.0)
	subcategory_row.add_child(subcategory_left_spacer)
	_subcategory_bar = HBoxContainer.new()
	_subcategory_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_subcategory_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subcategory_row.add_child(_subcategory_bar)
	_capacity_label = Label.new()
	_capacity_label.custom_minimum_size = Vector2(92.0, 30.0)
	_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subcategory_row.add_child(_capacity_label)
	_rebuild_subcategory_buttons()
	# 左右分栏；左侧固定装备栏，右侧背包物品独立滚动。
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 205
	content.add_child(split)
	var equipment_panel: PanelContainer = PanelContainer.new()
	equipment_panel.custom_minimum_size = Vector2(196.0, 0.0)
	split.add_child(equipment_panel)
	# 左侧页面根容器；页签固定在滚动内容上方，切换页面不会改变左右分栏结构。
	var equipment_pages: VBoxContainer = VBoxContainer.new()
	equipment_pages.add_theme_constant_override("separation", 6)
	equipment_panel.add_child(equipment_pages)
	# 左侧页签栏；“装备”默认选中，保持首次打开背包时与旧版一致。
	var equipment_tabs: HBoxContainer = HBoxContainer.new()
	equipment_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	equipment_pages.add_child(equipment_tabs)
	_character_tab_button = Button.new()
	_character_tab_button.text = "角色"
	_character_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_tab_button.pressed.connect(_show_character_page)
	equipment_tabs.add_child(_character_tab_button)
	_equipment_tab_button = Button.new()
	_equipment_tab_button.text = "装备"
	_equipment_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_tab_button.pressed.connect(_show_equipment_page)
	equipment_tabs.add_child(_equipment_tab_button)
	_equipment_scroll = ScrollContainer.new()
	_equipment_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_equipment_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	equipment_pages.add_child(_equipment_scroll)
	# 左侧装备卡牌悬浮安全边距；滚动容器四周预留 4 像素，确保 1.03 倍放大不会被装备栏边框裁剪。
	var equipment_scroll_margin: MarginContainer = MarginContainer.new()
	equipment_scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_scroll_margin.add_theme_constant_override("margin_left", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	equipment_scroll_margin.add_theme_constant_override("margin_top", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	equipment_scroll_margin.add_theme_constant_override("margin_right", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	equipment_scroll_margin.add_theme_constant_override("margin_bottom", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	_equipment_scroll.add_child(equipment_scroll_margin)
	_equipment_list = VBoxContainer.new()
	_equipment_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_equipment_list.add_theme_constant_override("separation", 6)
	equipment_scroll_margin.add_child(_equipment_list)
	_character_scroll = ScrollContainer.new()
	_character_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_character_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_character_scroll.visible = false
	equipment_pages.add_child(_character_scroll)
	_character_stats_panel = CHARACTER_STATS_PANEL_SCRIPT.new() as CharacterStatsPanel
	_character_stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character_stats_panel.configure_runtime_components(_runtime_stats_component, _runtime_equipment_component)
	_character_scroll.add_child(_character_stats_panel)
	_show_equipment_page()
	# 背包物品滚动区；滚动条始终显示，可用鼠标直接拖动浏览大量物品。
	var backpack_scroll: ScrollContainer = ScrollContainer.new()
	backpack_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	backpack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	backpack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	split.add_child(backpack_scroll)
	_backpack_drop_area = STORAGE_DROP_AREA_SCRIPT.new() as PanelContainer
	_backpack_drop_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_drop_area.call("configure", "backpack", 4)
	_backpack_drop_area.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	backpack_scroll.add_child(_backpack_drop_area)
	# 物品网格；由通用拖放区域内部创建，整个右侧空白都可接收装备卸下。
	_item_grid = _backpack_drop_area.call("get_content_container") as HFlowContainer
	_action_popup = ITEM_ACTION_POPUP_SCRIPT.new() as ItemActionPopup
	_action_popup.action_pressed.connect(_on_action_pressed)
	add_child(_action_popup)
	_quantity_dialog = SELL_QUANTITY_DIALOG_SCRIPT.new() as SellQuantityDialog
	_quantity_dialog.connect("quantity_confirmed", Callable(self, "_on_quantity_confirmed"))
	add_child(_quantity_dialog)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status_label)


func _show_character_page() -> void:
	## 显示角色属性页并刷新当前快照；选中的页签禁用，明确当前页面状态。
	_equipment_scroll.visible = false
	_character_scroll.visible = true
	_character_tab_button.disabled = true
	_equipment_tab_button.disabled = false
	_character_stats_panel.refresh()


func _show_equipment_page() -> void:
	## 显示现有装备槽列表；首次打开背包默认进入此页。
	_equipment_scroll.visible = true
	_character_scroll.visible = false
	_character_tab_button.disabled = false
	_equipment_tab_button.disabled = true


func _connect_inventory_signals() -> void:
	if _global_inventory == null:
		return
	for signal_name in ["inventory_changed", "equipment_changed"]:
		if _global_inventory.has_signal(signal_name):
			_global_inventory.connect(signal_name, Callable(self, "_on_inventory_state_changed"))


func _on_inventory_state_changed() -> void:
	## 合并库存变化刷新；隐藏面板只记录脏状态，避免拾取或其他界面操作时在后台销毁并重建完整背包。
	if not is_visible_in_tree():
		_refresh_pending = true
		return
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_queued_refresh")


func _flush_queued_refresh() -> void:
	## 执行已经合并的可见刷新；公开 refresh() 若已同步过界面会清除排队标识，使本回调安全跳过重复重建。
	if not _refresh_queued:
		return
	_refresh_queued = false
	if not is_visible_in_tree():
		_refresh_pending = true
		return
	_refresh_pending = false
	_refresh_all()


func _refresh_all() -> void:
	# 任意即时刷新都会接管同帧已排队任务；延迟回调随后检测到标识已清除并跳过，避免一次操作重复重建。
	_refresh_queued = false
	_refresh_pending = false
	_rebuild_equipment()
	_rebuild_items()
	_refresh_capacity_label()
	if _character_stats_panel != null:
		_character_stats_panel.refresh()


func _rebuild_equipment() -> void:
	_clear_container(_equipment_list)
	if _global_inventory == null:
		return
	for slot_index in range(int(_global_inventory.call("get_ranged_slot_count"))):
		_add_equipment_slot("远程 %d" % (slot_index + 1), "ranged_%d" % slot_index, "ranged")
	_add_equipment_slot("近战", "melee", "melee")
	# 武器与防具分组间距；独立空白控件只负责视觉分组，不参与拖放、选择或装备位置计算。
	var weapon_armor_spacer: Control = Control.new()
	weapon_armor_spacer.custom_minimum_size = Vector2(0.0, UI_STYLE_GUIDE.EQUIPMENT_GROUP_SPACER_HEIGHT)
	_equipment_list.add_child(weapon_armor_spacer)
	for armor_slot in ["head", "body", "legs", "feet"]:
		_add_equipment_slot({"head": "头部", "body": "躯干", "legs": "腿部", "feet": "脚部"}[armor_slot], "armor_" + armor_slot, armor_slot)


func _add_equipment_slot(slot_label: String, location: String, accepted_type: String) -> void:
	# 装备资源；空槽同样显示，确保主菜单背包与游戏内背包槽位结构一致。
	var item_resource: Resource = _global_inventory.call("get_equipment_location_resource", location) as Resource
	var slot_control: Button = EQUIPMENT_STORAGE_SLOT_SCRIPT.new() as Button
	slot_control.call("configure", slot_label, location, accepted_type, item_resource)
	slot_control.connect("item_selected", Callable(self, "_on_equipment_selected").bind(location))
	slot_control.connect("quick_unequip_requested", Callable(self, "_on_quick_unequip_requested").bind(location))
	slot_control.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	slot_control.connect("repair_kit_drop_requested", Callable(self, "_on_repair_kit_drop_requested"))
	# 修复选择状态；可修复目标保持绿色，满耐久目标灰显并阻止无效使用。
	slot_control.call("set_weapon_target_selection_state", _pending_repair_kit_resource != null, _can_repair_target(item_resource))
	_equipment_list.add_child(slot_control)


func _rebuild_items() -> void:
	if _global_inventory == null:
		return
	var entries: Array = _global_inventory.call("get_backpack_entries")
	_equipment_set_filter_control.configure_entries(entries)
	# 可见条目；统一查询器保留每项原始 source_index，排序和筛选后拖拽仍操作正确背包记录。
	var visible_entries: Array[Dictionary] = InventoryQuery.filter_and_sort_entries(entries, _primary_category, _subcategory, _search_edit.text, _stone_attribute_filter, _sort_mode, _equipment_set_filter_control.get_selected_set_ids())
	# 现有卡片表；键为资源实例编号，值为可复用背包卡片，空状态文本和异常节点不参与复用。
	var existing_controls: Dictionary = {}
	for child in _item_grid.get_children():
		if child == null or child.is_queued_for_deletion() or not child.has_method("get_item_resource"):
			continue
		# 现有卡片资源；实例身份用于区分同名武器和相同模板的独立物品。
		var existing_resource: Resource = child.call("get_item_resource") as Resource
		if existing_resource != null:
			existing_controls[existing_resource.get_instance_id()] = child
	# 本轮保留控件集合；用于移除筛选后不可见、已装备或已丢弃物品对应的旧卡片。
	var retained_control_ids: Dictionary = {}
	for visible_index in range(visible_entries.size()):
		# 当前可见条目；包含真实来源下标、资源、数量和排序元数据。
		var entry: Dictionary = visible_entries[visible_index]
		# 真实来源下标；筛选和排序只改变显示顺序，拖拽仍必须写回全局背包中的原记录位置。
		var entry_index: int = int(entry.get("source_index", -1))
		# 条目资源；实例身份用于复用卡片并区分同名或同模板的独立物品。
		var item_resource: Resource = entry.get("resource") as Resource
		if item_resource == null:
			continue
		# 复用背包卡片；普通移动只更新真实下标，新物品或重新进入筛选结果时才创建节点并连接信号。
		var item_control: Button = existing_controls.get(item_resource.get_instance_id()) as Button
		if item_control == null:
			item_control = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
			item_control.call("configure", item_resource, "backpack", entry_index, true, "", int(entry.get("quantity", 1)))
			item_control.call("set_stone_value_on_fourth_line", true)
			item_control.call("set_weapon_slot_visual_style", true)
			item_control.connect("item_action_requested", Callable(self, "_on_item_pressed"))
			item_control.connect("quick_action_requested", Callable(self, "_on_quick_equip_requested"))
			item_control.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
			item_control.connect("repair_kit_drop_requested", Callable(self, "_on_repair_kit_drop_requested"))
			_item_grid.add_child(item_control)
		else:
			item_control.call("update_storage_context", item_resource, "backpack", entry_index, true, "", int(entry.get("quantity", 1)))
			item_control.call("set_stone_value_on_fourth_line", true)
		# 修复目标选择；背包武器与装备使用和左侧装备栏相同的可选与灰显规则。
		var is_durable_item: bool = str(item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"] or str(item_resource.get("item_kind")) == "equipment"
		item_control.call("set_weapon_target_selection_state", _pending_repair_kit_resource != null and is_durable_item, _can_repair_target(item_resource))
		retained_control_ids[item_control.get_instance_id()] = true
		_item_grid.move_child(item_control, mini(visible_index, _item_grid.get_child_count() - 1))
	# 过期卡片与旧空状态；从布局中立即移除，释放动作延后到安全时机执行。
	for child in _item_grid.get_children():
		if child != null and not retained_control_ids.has(child.get_instance_id()):
			_item_grid.remove_child(child)
			child.queue_free()
	if visible_entries.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "当前分类与筛选没有物品"
		_item_grid.add_child(empty_label)


func _refresh_capacity_label() -> void:
	## 刷新背包组数显示；筛选结果不会改变已占用组数，始终读取全局库存真实记录数量。
	if _capacity_label == null:
		return
	if _global_inventory == null:
		_capacity_label.text = "--/--"
		return
	# 当前背包组数；武器、装备和每个资源堆叠记录都各计为一组。
	var current_group_count: int = int(_global_inventory.call("get_backpack_count")) if _global_inventory.has_method("get_backpack_count") else 0
	# 背包组数上限；优先读取库存服务公开接口，兼容旧服务时回退现行固定 50 组。
	var maximum_group_count: int = int(_global_inventory.call("get_backpack_max_groups")) if _global_inventory.has_method("get_backpack_max_groups") else INVENTORY_LIMITS.BACKPACK_MAX_GROUPS
	_capacity_label.text = "%d/%d" % [current_group_count, maximum_group_count]


func _create_category_button(target_bar: HBoxContainer, button_text: String, category_name: String, is_primary: bool) -> void:
	# 分类按钮；稳定分类标识通过绑定参数传递，显示文字变化不会影响查询。
	var category_button: Button = Button.new()
	category_button.text = button_text
	category_button.custom_minimum_size = Vector2(92.0, 30.0)
	if is_primary:
		category_button.pressed.connect(_on_primary_category_pressed.bind(category_name))
		_primary_buttons[category_name] = category_button
	else:
		category_button.pressed.connect(_on_subcategory_pressed.bind(category_name))
		_subcategory_buttons[category_name] = category_button
	target_bar.add_child(category_button)


func _rebuild_subcategory_buttons() -> void:
	_clear_container(_subcategory_bar)
	_subcategory_buttons.clear()
	_create_category_button(_subcategory_bar, "全部", InventoryQuery.SUBCATEGORY_ALL, false)
	if _primary_category == InventoryQuery.PRIMARY_WEAPONS:
		_create_category_button(_subcategory_bar, "近战", InventoryQuery.SUBCATEGORY_MELEE, false)
		_create_category_button(_subcategory_bar, "远程", InventoryQuery.SUBCATEGORY_RANGED, false)
	elif _primary_category == InventoryQuery.PRIMARY_EQUIPMENT:
		_create_category_button(_subcategory_bar, "头部", InventoryQuery.SUBCATEGORY_EQUIPMENT_HEAD, false)
		_create_category_button(_subcategory_bar, "躯干", InventoryQuery.SUBCATEGORY_EQUIPMENT_BODY, false)
		_create_category_button(_subcategory_bar, "腿部", InventoryQuery.SUBCATEGORY_EQUIPMENT_LEGS, false)
		_create_category_button(_subcategory_bar, "脚部", InventoryQuery.SUBCATEGORY_EQUIPMENT_FEET, false)
	elif _primary_category == InventoryQuery.PRIMARY_RESOURCES:
		_create_category_button(_subcategory_bar, "强化石", InventoryQuery.SUBCATEGORY_ENHANCEMENT_STONES, false)
		_create_category_button(_subcategory_bar, "道具", InventoryQuery.SUBCATEGORY_ITEMS, false)
	_refresh_query_controls()


func _on_primary_category_pressed(category_name: String) -> void:
	_primary_category = category_name
	_subcategory = InventoryQuery.SUBCATEGORY_ALL
	_clear_stone_attribute_filter(false)
	_equipment_set_filter_control.clear_filters(false)
	_rebuild_subcategory_buttons()
	_rebuild_items()


func _on_subcategory_pressed(category_name: String) -> void:
	_subcategory = category_name
	_refresh_query_controls()
	_rebuild_items()


func _on_sort_selected(item_index: int) -> void:
	var selected_mode: String = str(_sort_option.get_item_metadata(item_index))
	_sort_mode = selected_mode if selected_mode in [InventoryQuery.SORT_ACQUIRED_TIME, InventoryQuery.SORT_ITEM_VALUE, InventoryQuery.SORT_DURABILITY] else InventoryQuery.SORT_ACQUIRED_TIME
	_rebuild_items()


func _on_stone_attribute_selected(item_index: int) -> void:
	if item_index <= 0:
		_stone_attribute_option.select(0)
		return
	var filter_key: String = str(_stone_attribute_option.get_item_metadata(item_index))
	if filter_key.is_empty():
		return
	var should_select: bool = filter_key not in _stone_attribute_filter
	_stone_attribute_option.get_popup().set_item_checked(item_index, should_select)
	if should_select:
		_stone_attribute_filter.append(filter_key)
	else:
		_stone_attribute_filter.erase(filter_key)
	_refresh_stone_attribute_filter_display()
	_rebuild_items()


func _clear_stone_attribute_filter(rebuild_items: bool = true) -> void:
	_stone_attribute_filter.clear()
	for item_index in range(1, _stone_attribute_option.item_count):
		if not str(_stone_attribute_option.get_item_metadata(item_index)).is_empty():
			_stone_attribute_option.get_popup().set_item_checked(item_index, false)
	_refresh_stone_attribute_filter_display()
	if rebuild_items:
		_rebuild_items()


func _on_equipment_set_filters_changed(_selected_set_ids: Array[String]) -> void:
	## 套装多选变化后重建背包展示；真实库存顺序和所有权保持不变。
	_rebuild_items()


func _refresh_stone_attribute_filter_display() -> void:
	_stone_attribute_option.set_item_text(0, "强化筛选（%d）" % _stone_attribute_filter.size())
	_stone_attribute_option.select(0)
	for item_index in range(1, _stone_attribute_option.item_count):
		var filter_key: String = str(_stone_attribute_option.get_item_metadata(item_index))
		if not filter_key.is_empty():
			_stone_attribute_option.get_popup().set_item_checked(item_index, filter_key in _stone_attribute_filter)
	_stone_attribute_clear_button.disabled = _stone_attribute_filter.is_empty()


func _refresh_query_controls() -> void:
	for category_name in _primary_buttons.keys():
		(_primary_buttons[category_name] as Button).disabled = str(category_name) == _primary_category
	for category_name in _subcategory_buttons.keys():
		(_subcategory_buttons[category_name] as Button).disabled = str(category_name) == _subcategory
	var resource_category_active: bool = _primary_category == InventoryQuery.PRIMARY_RESOURCES
	_stone_attribute_option.visible = resource_category_active
	_stone_attribute_clear_button.visible = resource_category_active
	_equipment_set_filter_control.visible = _primary_category == InventoryQuery.PRIMARY_EQUIPMENT
	_refresh_stone_attribute_filter_display()


func _on_item_pressed(item_resource: Resource) -> void:
	if _pending_repair_kit_resource != null:
		if _can_repair_target(item_resource):
			_apply_repair_kit(_pending_repair_kit_resource, _pending_repair_kit_location, item_resource)
		return
	_action_resource = item_resource
	_action_equipment_location = ""
	_action_quantity = int(_global_inventory.call("get_storage_resource_quantity", item_resource, "backpack")) if _global_inventory != null else 1
	_action_popup.clear_actions()
	if str(item_resource.get("item_kind")) == "equipment" or str(item_resource.get("weapon_type")) in ["melee", "hybrid"]:
		_action_popup.add_action("装备", ACTION_EQUIP)
	if str(item_resource.get("weapon_type")) in ["ranged", "hybrid"]:
		_action_popup.add_action("装备1", ACTION_EQUIP_RANGED_ONE)
		_action_popup.add_action("装备2", ACTION_EQUIP_RANGED_TWO)
	elif str(item_resource.get("item_kind")) == "repair_kit":
		_action_popup.add_action("使用", ACTION_USE_REPAIR_KIT)
	elif _context_mode == CONTEXT_COMBAT and str(item_resource.get("item_kind")) == "consumable":
		_action_popup.add_action("使用", ACTION_USE_CONSUMABLE)
	if _action_quantity > 1:
		_action_popup.add_action("全部出售" if _context_mode == CONTEXT_MAIN_MENU else "全部丢弃", ACTION_DISCARD_ALL, false, true)
		_action_popup.add_action("部分出售" if _context_mode == CONTEXT_MAIN_MENU else "部分丢弃", ACTION_DISCARD_PARTIAL, false, true)
	else:
		_action_popup.add_action("出售" if _context_mode == CONTEXT_MAIN_MENU else "丢弃", ACTION_DISCARD_ALL, false, true)
	_action_popup.present_at(get_viewport().get_mouse_position())


func _on_quick_equip_requested(item_resource: Resource) -> void:
	## Shift+点击仅在共享背包中尝试装备到兼容空槽；仓库展开背包使用自己的快捷转移处理，不会连接本回调。
	if _global_inventory == null or item_resource == null or _pending_repair_kit_resource != null:
		return
	# 防具目标；每个部位只有一个固定槽，已有装备时不执行替换。
	if str(item_resource.get("item_kind")) == "equipment":
		var armor_location: String = "armor_" + str(item_resource.get("equipment_slot"))
		if _global_inventory.call("get_equipment_location_resource", armor_location) == null:
			_global_inventory.call("transfer_storage_to_equipment", item_resource, "backpack", armor_location)
		return
	# 武器目标；远程优先第一个空远程槽，近战使用唯一空近战槽，混合武器在远程已满时回退近战槽。
	var weapon_type: String = str(item_resource.get("weapon_type"))
	if weapon_type in ["ranged", "hybrid"]:
		var ranged_slot_count: int = int(_global_inventory.call("get_ranged_slot_count"))
		for slot_index in range(ranged_slot_count):
			if _global_inventory.call("get_ranged_equipment_resource", slot_index) == null:
				_global_inventory.call("transfer_storage_to_equipment", item_resource, "backpack", "ranged_%d" % slot_index)
				return
	if weapon_type in ["melee", "hybrid"] and _global_inventory.call("get_melee_equipment_resource") == null:
		_global_inventory.call("transfer_storage_to_equipment", item_resource, "backpack", "melee")


func _on_action_pressed(action_id: int) -> void:
	if _global_inventory == null or _action_resource == null:
		return
	if action_id in [ACTION_EQUIP, ACTION_EQUIP_RANGED_ONE, ACTION_EQUIP_RANGED_TWO]:
		var target_location: String = ""
		if str(_action_resource.get("item_kind")) == "equipment":
			target_location = "armor_" + str(_action_resource.get("equipment_slot"))
		elif str(_action_resource.get("weapon_type")) in ["melee", "hybrid"] and action_id == ACTION_EQUIP:
			target_location = "melee"
		else:
			target_location = "ranged_0" if action_id == ACTION_EQUIP_RANGED_ONE else "ranged_1"
		_global_inventory.call("transfer_storage_to_equipment", _action_resource, "backpack", target_location)
	elif action_id == ACTION_DISCARD_ALL:
		_execute_discard(_action_resource, maxi(_action_quantity, 1))
	elif action_id == ACTION_DISCARD_PARTIAL:
		_pending_partial_resource = _action_resource
		if _context_mode == CONTEXT_MAIN_MENU:
			var unit_value: int = int(ITEM_DETAIL_FORMATTER.call("get_item_value", _action_resource))
			_quantity_dialog.present(str(_action_resource.get("display_name")), maxi(_action_quantity, 1), unit_value)
		else:
			_quantity_dialog.present_discard(str(_action_resource.get("display_name")), maxi(_action_quantity, 1))
	elif action_id == ACTION_UNEQUIP and not _action_equipment_location.is_empty():
		_global_inventory.call("transfer_equipment_to_storage", _action_equipment_location, "backpack")
	elif action_id == ACTION_USE_REPAIR_KIT and str(_action_resource.get("item_kind")) == "repair_kit":
		_pending_repair_kit_resource = _action_resource
		_pending_repair_kit_location = "backpack"
		_cancel_use_button.visible = true
		_status_label.text = "正在使用 %s：请选择或拖到未满耐久的武器/装备" % str(_action_resource.get("display_name"))
		_refresh_all()
	elif action_id == ACTION_USE_CONSUMABLE and _context_mode == CONTEXT_COMBAT and str(_action_resource.get("item_kind")) == "consumable":
		# 临时增益组件；先成功写入或刷新效果，再从真实背包扣除一个，避免配置无效导致道具丢失。
		if _runtime_temporary_buff_component != null and _runtime_temporary_buff_component.has_method("apply_consumable") and bool(_runtime_temporary_buff_component.call("apply_consumable", _action_resource)) and bool(_global_inventory.call("consume_storage_resource_quantity", _action_resource, "backpack", 1)):
			_status_label.text = "已使用 %s" % str(_action_resource.get("display_name"))
		_refresh_all()


func _on_equipment_selected(item_resource: Resource, equipment_location: String) -> void:
	if item_resource == null:
		return
	if _pending_repair_kit_resource != null:
		if _can_repair_target(item_resource):
			_apply_repair_kit(_pending_repair_kit_resource, _pending_repair_kit_location, item_resource)
		return
	_action_resource = item_resource
	_action_equipment_location = equipment_location
	_action_quantity = 1
	_action_popup.clear_actions()
	_action_popup.add_action("卸下", ACTION_UNEQUIP)
	_action_popup.present_at(get_viewport().get_mouse_position())


func _on_quick_unequip_requested(equipment_location: String) -> void:
	## Shift+点击装备槽时直接卸到背包；目标选择期间由槽控件保留普通点击语义，不会误卸下。
	if _global_inventory != null and not equipment_location.is_empty():
		_global_inventory.call("transfer_equipment_to_storage", equipment_location, "backpack")


func _on_item_drop_requested(drag_data: Dictionary, target_location: String, target_index: int) -> void:
	if _global_inventory == null:
		return
	# 拖拽资源与来源；存储来源为 backpack，装备来源使用具体装备槽位置。
	var item_resource: Resource = drag_data.get("resource") as Resource
	var source_location: String = str(drag_data.get("source_location", ""))
	var source_index: int = int(drag_data.get("source_index", -1))
	if item_resource == null or source_location.is_empty():
		return
	var source_is_backpack: bool = source_location == "backpack"
	var target_is_backpack: bool = target_location == "backpack"
	if source_is_backpack and target_is_backpack:
		var resolved_target_index: int = int(_global_inventory.call("get_backpack_count")) if target_index < 0 else target_index
		_global_inventory.call("move_backpack_item", source_index, resolved_target_index)
	elif source_is_backpack and not target_is_backpack:
		# 背包物品拖入装备槽；GlobalInventory 负责类型验证和已有装备替换回背包。
		_global_inventory.call("transfer_storage_to_equipment", item_resource, "backpack", target_location)
	elif not source_is_backpack and target_is_backpack:
		# 装备拖入背包卡片或空白区域；物品从装备槽卸下并插入目标位置。
		_global_inventory.call("transfer_equipment_to_storage", source_location, "backpack", target_index)
	else:
		# 装备槽之间拖动；兼容类型时移动或交换资源，类型不匹配时由全局服务拒绝。
		_global_inventory.call("swap_equipment_locations", source_location, target_location)


func _on_repair_kit_drop_requested(repair_kit_resource: Resource, source_location: String, weapon_resource: Resource) -> void:
	_apply_repair_kit(repair_kit_resource, source_location, weapon_resource)


func _apply_repair_kit(repair_kit_resource: Resource, source_location: String, weapon_resource: Resource) -> void:
	if _global_inventory == null or repair_kit_resource == null or weapon_resource == null:
		return
	var repair_result: Dictionary = _global_inventory.call("use_repair_kit_with_result", repair_kit_resource, source_location, weapon_resource) as Dictionary
	if bool(repair_result.get("success", false)):
		_status_label.text = "修复完成，恢复 %.0f 点耐久" % float(repair_result.get("durability_restored", 0.0))
		_pending_repair_kit_resource = null
		_pending_repair_kit_location = ""
		_cancel_use_button.visible = false
		_refresh_all()


func _can_repair_target(item_resource: Resource) -> bool:
	if item_resource == null or (str(item_resource.get("weapon_type")) not in ["ranged", "melee", "hybrid"] and str(item_resource.get("item_kind")) != "equipment"):
		return false
	# 最大耐久；装备优先读取耐久强化后的有效上限，旧资源回退导出字段。
	var maximum_durability: float = float(item_resource.call("get_maximum_durability")) if item_resource.has_method("get_maximum_durability") else maxf(float(item_resource.get("max_durability")), 1.0)
	return float(item_resource.get("current_durability")) < maximum_durability


func _cancel_repair_kit_use() -> void:
	_pending_repair_kit_resource = null
	_pending_repair_kit_location = ""
	_cancel_use_button.visible = false
	_status_label.text = "已取消使用修复包"
	_refresh_all()


func _on_quantity_confirmed(quantity: int) -> void:
	if _pending_partial_resource == null or _global_inventory == null:
		return
	var item_resource: Resource = _pending_partial_resource
	_pending_partial_resource = null
	if _context_mode == CONTEXT_MAIN_MENU:
		_global_inventory.call("sell_storage_resource_quantity", item_resource, "backpack", maxi(quantity, 1))
	else:
		_execute_discard(item_resource, quantity)


func _execute_discard(item_resource: Resource, quantity: int) -> void:
	# 战斗丢弃；所有权扣除和地面生成由 CombatHud 原有流程处理，组件只发出上下文请求。
	if _context_mode == CONTEXT_COMBAT:
		combat_discard_requested.emit(item_resource, maxi(quantity, 1))
		return
	# 局外丢弃；没有地面容器，直接从全局背包永久消费指定数量。
	if _global_inventory != null:
		if _context_mode == CONTEXT_MAIN_MENU:
			_global_inventory.call("sell_storage_resource_quantity", item_resource, "backpack", maxi(quantity, 1))
		else:
			_global_inventory.call("consume_storage_resource_quantity", item_resource, "backpack", maxi(quantity, 1))


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
