extends PanelContainer
class_name ForgePanel

## 锻造面板在上半区维护一个主武器槽与五个牺牲槽，下半区浏览背包或仓库物品。
## 放入槽位只建立来源引用，不提前移除物品；点击锻造后由 ForgeService 原子校验并消费材料。

signal closed

## 锻造槽脚本；主槽与牺牲槽共用拖拽、悬停和单击归还协议。
const FORGE_SLOT_CONTROL_SCRIPT: Script = preload("res://scripts/ui/forge_slot_control.gd")
## 仓库物品卡片脚本；下半区复用仓库同款摘要、拖拽数据和完整详情。
const STORAGE_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/storage_item_control.gd")
## 锻造结果弹窗脚本；展示强化前后属性、价格与额外耐久恢复。
const ENHANCEMENT_RESULT_DIALOG_SCRIPT: Script = preload("res://scripts/ui/enhancement_result_dialog.gd")
## 背包来源标识；与 GlobalInventory 公开接口保持一致。
const SOURCE_BACKPACK: String = "backpack"
## 仓库来源标识；与 GlobalInventory 公开接口保持一致。
const SOURCE_WAREHOUSE: String = "warehouse"
## 牺牲槽数量；固定 5 个并围绕主锻造槽排列。
const SACRIFICE_SLOT_COUNT: int = 5
## 锻造动画持续时间；默认 1.35 秒，材料旋转一圈半并逐渐靠近主物品。
const FORGE_ANIMATION_DURATION: float = 1.35
## 锻造动画旋转圈数；默认 1.5 圈，兼顾可读性和等待时长。
const FORGE_ANIMATION_ROTATIONS: float = 1.5

## 锻造面板最小尺寸；默认 960×650，在主菜单 720 高窗口中保留外层遮罩边距。
@export var panel_minimum_size: Vector2 = Vector2(960.0, 650.0)
## 主武器槽与牺牲槽边长；默认 84 像素，相比旧版 104 像素更紧凑，运行时无需动态修改。
@export_range(64.0, 104.0, 1.0) var forge_slot_size: float = 84.0
## 顶部中心牺牲槽额外上移距离；默认 16 像素，用于与主锻造槽保持清晰间隔，运行时无需动态修改。
@export_range(0.0, 64.0, 1.0) var top_sacrifice_slot_upward_offset: float = 16.0

## 全局库存服务缓存；提供背包/仓库条目、金币、材料数量与强化应用。
var _global_inventory: Node
## 锻造规则服务；只持有全局库存引用，不依赖当前面板节点结构。
var _forge_service: ForgeService
## 当前下半区来源；默认背包，可通过按钮切换到永久仓库。
var _current_source: String = SOURCE_BACKPACK
## 当前一级分类；默认武器，切换来源时保留方便连续挑选材料。
var _primary_category: String = InventoryQuery.PRIMARY_WEAPONS
## 当前二级分类；默认全部，切换一级分类时重置。
var _subcategory: String = InventoryQuery.SUBCATEGORY_ALL
## 当前强化石属性筛选键集合；默认空数组表示全部属性与方向，多项条件按并集展示。
var _stone_attribute_filter: Array[String] = []
## 当前排序模式；默认获得时间从新到旧，与背包仓库一致。
var _sort_mode: String = InventoryQuery.SORT_ACQUIRED_TIME
## 主锻造条目；包含资源与原来源，空字典表示主槽未放入武器。
var _main_entry: Dictionary = {}
## 五个牺牲条目；每项为空字典或包含资源与原来源，数组下标对应环形槽位。
var _sacrifice_entries: Array[Dictionary] = []
## 主锻造槽控件；固定显示在锻造区中央。
var _main_slot: Button
## 牺牲槽控件数组；元素按 0 到 4 顺时针围绕主槽排列。
var _sacrifice_slots: Array[Button] = []
## 锻造板容器；承载六个槽位和融合动画临时控件。
var _forge_board: Control
## 背包来源按钮；选中时禁用并显示背包条目。
var _backpack_source_button: Button
## 仓库来源按钮；选中时禁用并显示永久仓库条目。
var _warehouse_source_button: Button
## 金币标签；锻造完成扣款后即时刷新。
var _coins_label: Label
## 锻造预览标签；显示主武器、耐久前后和强化石数量，但不泄露最终强化倍率。
var _preview_label: Label
## 锻造按钮；预览有效时可点击，动画期间禁用。
var _forge_button: Button
## 锻造费用标签；固定显示在按钮下方并包含本次总金币费用。
var _forge_cost_label: Label
## 状态提示标签；用于显示放入失败、材料不足或锻造结果。
var _status_label: Label
## 搜索输入框；按名称、说明、分类和强化词条过滤当前来源。
var _search_edit: LineEdit
## 排序下拉框；支持获得时间和物品价值两种仓库同款排序。
var _sort_option: OptionButton
## 强化属性筛选框；只在资源分类显示并按正负方向精确筛选。
var _stone_attribute_option: OptionButton
## 清空强化属性筛选按钮；默认只在资源分类显示，点击后一次移除全部勾选条件。
var _stone_attribute_clear_button: Button
## 一级分类按钮表；用于同步当前武器或资源分类的选中状态。
var _primary_buttons: Dictionary = {}
## 二级分类按钮表；根据一级分类动态重建。
var _subcategory_buttons: Dictionary = {}
## 二级分类栏；武器显示全部/近战/远程，资源显示全部/强化石。
var _subcategory_bar: HBoxContainer
## 下半区物品网格；每次槽位、来源或查询变化后重建。
var _item_grid: GridContainer
## 锻造结果弹窗；完成动画和实际结算后展示属性与耐久变化。
var _result_dialog: AcceptDialog
## 当前是否正在播放锻造并执行结算；为 true 时阻止关闭、换槽和重复点击。
var _forging_in_progress: bool = false
## 动画临时控件；每项对应一个非空牺牲槽的名称标签。
var _animation_ghosts: Array[Control] = []
## 动画起始偏移；元素为牺牲品中心相对主物品中心的位置，用于旋转并收拢。
var _animation_start_offsets: Array[Vector2] = []


func _ready() -> void:
	custom_minimum_size = panel_minimum_size
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_forge_service = ForgeService.new(_global_inventory)
	_initialize_sacrifice_entries()
	_build_interface()
	_connect_inventory_signals()
	_refresh_all()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not _forging_in_progress:
		closed.emit()
		get_viewport().set_input_as_handled()


func _initialize_sacrifice_entries() -> void:
	_sacrifice_entries.clear()
	for _slot_index in range(SACRIFICE_SLOT_COUNT):
		_sacrifice_entries.append({})


func _build_interface() -> void:
	# 外层边距；保证锻造板、查询栏和物品网格在面板内保持统一留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	# 主内容容器；上方为锻造，下方为可切换背包或仓库页面。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	# 标题栏；显示锻造标题、金币与关闭按钮。
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	# 标题文本；占据剩余宽度，避免金币和关闭按钮挤压。
	var title_label: Label = Label.new()
	title_label.text = "锻造"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 25)
	header.add_child(title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_coins_label)
	# 关闭按钮；动画期间由状态控制禁用，正常点击返回主菜单。
	var close_button: Button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "关闭锻造"
	close_button.custom_minimum_size = Vector2(116.0, 36.0)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	# 上方锻造区；固定高度容纳环形五槽、中央主槽和右侧预览操作。
	var forge_section: HBoxContainer = HBoxContainer.new()
	forge_section.custom_minimum_size = Vector2(0.0, 275.0)
	forge_section.add_theme_constant_override("separation", 12)
	content.add_child(forge_section)
	_forge_board = Control.new()
	_forge_board.custom_minimum_size = Vector2(620.0, 275.0)
	_forge_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_section.add_child(_forge_board)
	_build_forge_slots()
	# 右侧预览面板；显示可提前知道的耐久与费用，强化石最终倍率明确保持未知。
	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(285.0, 0.0)
	forge_section.add_child(preview_panel)
	# 预览边距；为多行文字和锻造按钮保留可读空间。
	var preview_margin: MarginContainer = MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 12)
	preview_margin.add_theme_constant_override("margin_top", 10)
	preview_margin.add_theme_constant_override("margin_right", 12)
	preview_margin.add_theme_constant_override("margin_bottom", 10)
	preview_panel.add_child(preview_margin)
	# 预览纵向布局；顶部文本占剩余高度，底部按钮和费用固定可见。
	var preview_content: VBoxContainer = VBoxContainer.new()
	preview_content.add_theme_constant_override("separation", 7)
	preview_margin.add_child(preview_content)
	# 预览标题；说明该区域不会显示强化石最终随机倍率。
	var preview_title: Label = Label.new()
	preview_title.text = "锻造预览"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 19)
	preview_content.add_child(preview_title)
	_preview_label = Label.new()
	_preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_content.add_child(_preview_label)
	_forge_button = Button.new()
	_forge_button.text = "开始锻造"
	_forge_button.custom_minimum_size = Vector2(0.0, 42.0)
	_forge_button.pressed.connect(_on_forge_pressed)
	preview_content.add_child(_forge_button)
	_forge_cost_label = Label.new()
	_forge_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_content.add_child(_forge_cost_label)
	# 分隔线；明确上方锻造区和下方库存选择区的职责边界。
	var separator: HSeparator = HSeparator.new()
	content.add_child(separator)
	# 下半区标题与来源切换；玩家可在背包和永久仓库之间选择材料来源。
	var inventory_header: HBoxContainer = HBoxContainer.new()
	inventory_header.add_theme_constant_override("separation", 8)
	content.add_child(inventory_header)
	# 下半区标题；占据剩余宽度并提示支持拖动或单击放入。
	var inventory_title: Label = Label.new()
	inventory_title.text = "材料选择 · 可拖动到槽位，单击则按主槽→牺牲槽优先放入"
	inventory_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_header.add_child(inventory_title)
	_backpack_source_button = Button.new()
	_backpack_source_button.text = "背包"
	_backpack_source_button.custom_minimum_size = Vector2(90.0, 34.0)
	_backpack_source_button.pressed.connect(_on_source_pressed.bind(SOURCE_BACKPACK))
	inventory_header.add_child(_backpack_source_button)
	_warehouse_source_button = Button.new()
	_warehouse_source_button.text = "仓库"
	_warehouse_source_button.custom_minimum_size = Vector2(90.0, 34.0)
	_warehouse_source_button.pressed.connect(_on_source_pressed.bind(SOURCE_WAREHOUSE))
	inventory_header.add_child(_warehouse_source_button)
	# 查询栏；关键词、排序和强化属性方向筛选沿用库存统一规则。
	var query_bar: HBoxContainer = HBoxContainer.new()
	query_bar.add_theme_constant_override("separation", 7)
	content.add_child(query_bar)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索武器、强化石或属性"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_changed)
	query_bar.add_child(_search_edit)
	_sort_option = OptionButton.new()
	_sort_option.custom_minimum_size = Vector2(130.0, 34.0)
	_sort_option.add_item("获得时间")
	_sort_option.set_item_metadata(0, InventoryQuery.SORT_ACQUIRED_TIME)
	_sort_option.add_item("物品价值")
	_sort_option.set_item_metadata(1, InventoryQuery.SORT_ITEM_VALUE)
	_sort_option.item_selected.connect(_on_sort_selected)
	query_bar.add_child(_sort_option)
	_stone_attribute_option = OptionButton.new()
	_stone_attribute_option.custom_minimum_size = Vector2(150.0, 34.0)
	_stone_attribute_option.add_item("强化筛选（0）")
	_stone_attribute_option.set_item_metadata(0, "")
	for direction in InventoryQuery.STONE_FILTER_DIRECTIONS:
		_stone_attribute_option.add_separator(InventoryQuery.get_stone_attribute_direction_group_label(direction))
		for stat_name in EnhancementRules.STAT_KEYS:
			_stone_attribute_option.add_item(InventoryQuery.get_stone_attribute_filter_label(stat_name, direction))
			# 当前属性选项下标；用于写入筛选键并开启复选状态。
			var attribute_item_index: int = _stone_attribute_option.item_count - 1
			_stone_attribute_option.set_item_metadata(attribute_item_index, InventoryQuery.build_stone_attribute_filter_key(stat_name, direction))
			_stone_attribute_option.get_popup().set_item_as_checkable(attribute_item_index, true)
	# 多选弹窗；勾选单项后保持展开，便于连续组合“伤害+”“伤害-”等并集条件。
	_stone_attribute_option.get_popup().hide_on_checkable_item_selection = false
	_stone_attribute_option.item_selected.connect(_on_stone_attribute_selected)
	query_bar.add_child(_stone_attribute_option)
	_stone_attribute_clear_button = Button.new()
	_stone_attribute_clear_button.text = "清空筛选"
	_stone_attribute_clear_button.custom_minimum_size = Vector2(92.0, 34.0)
	_stone_attribute_clear_button.pressed.connect(_on_clear_stone_attribute_filter_pressed)
	query_bar.add_child(_stone_attribute_clear_button)
	# 分类栏；保持背包仓库同款一级与二级结构。
	var category_columns: VBoxContainer = VBoxContainer.new()
	category_columns.add_theme_constant_override("separation", 3)
	content.add_child(category_columns)
	var primary_bar: HBoxContainer = HBoxContainer.new()
	primary_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	primary_bar.add_theme_constant_override("separation", 8)
	category_columns.add_child(primary_bar)
	_create_category_button(primary_bar, "武器", InventoryQuery.PRIMARY_WEAPONS, true)
	_create_category_button(primary_bar, "资源", InventoryQuery.PRIMARY_RESOURCES, true)
	_subcategory_bar = HBoxContainer.new()
	_subcategory_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_subcategory_bar.add_theme_constant_override("separation", 6)
	category_columns.add_child(_subcategory_bar)
	_rebuild_subcategory_buttons()
	# 下半区物品滚动网格；双列卡片与仓库保持一致，已选武器隐藏，强化石按剩余可选数量显示。
	var inventory_scroll: ScrollContainer = ScrollContainer.new()
	inventory_scroll.custom_minimum_size = Vector2(0.0, 135.0)
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(inventory_scroll)
	_item_grid = GridContainer.new()
	_item_grid.columns = 2
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.add_theme_constant_override("h_separation", 8)
	_item_grid.add_theme_constant_override("v_separation", 6)
	inventory_scroll.add_child(_item_grid)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)
	_result_dialog = ENHANCEMENT_RESULT_DIALOG_SCRIPT.new() as AcceptDialog
	add_child(_result_dialog)


func _build_forge_slots() -> void:
	# 槽位半边长；所有锚点偏移共用该值，保证检查器调整槽位大小后仍以中心准确对齐。
	var slot_half_size: float = forge_slot_size * 0.5
	_main_slot = FORGE_SLOT_CONTROL_SCRIPT.new() as Button
	_main_slot.call("configure", -1, true, forge_slot_size)
	_main_slot.anchor_left = 0.5
	_main_slot.anchor_top = 0.5
	_main_slot.anchor_right = 0.5
	_main_slot.anchor_bottom = 0.5
	_main_slot.offset_left = -slot_half_size
	_main_slot.offset_top = -slot_half_size
	_main_slot.offset_right = slot_half_size
	_main_slot.offset_bottom = slot_half_size
	_main_slot.connect("item_requested", Callable(self, "_on_slot_item_requested"))
	_main_slot.connect("return_requested", Callable(self, "_on_slot_return_requested"))
	_forge_board.add_child(_main_slot)
	for slot_index in range(SACRIFICE_SLOT_COUNT):
		# 环形角度；从顶部开始平均分布五个槽位，顺时针排列。
		var slot_angle: float = -PI * 0.5 + TAU * float(slot_index) / float(SACRIFICE_SLOT_COUNT)
		# 牺牲槽；锚点按椭圆半径分布，适配横向锻造板比例。
		var sacrifice_slot: Button = FORGE_SLOT_CONTROL_SCRIPT.new() as Button
		sacrifice_slot.call("configure", slot_index, false, forge_slot_size)
		sacrifice_slot.anchor_left = 0.5 + cos(slot_angle) * 0.34
		sacrifice_slot.anchor_top = 0.5 + sin(slot_angle) * 0.31
		sacrifice_slot.anchor_right = sacrifice_slot.anchor_left
		sacrifice_slot.anchor_bottom = sacrifice_slot.anchor_top
		sacrifice_slot.offset_left = -slot_half_size
		sacrifice_slot.offset_top = -slot_half_size
		sacrifice_slot.offset_right = slot_half_size
		sacrifice_slot.offset_bottom = slot_half_size
		if slot_index == 0:
			# 顶部槽额外上移；保持环形结构不变，仅增加它与中央主槽之间的可读间隔。
			sacrifice_slot.offset_top -= top_sacrifice_slot_upward_offset
			sacrifice_slot.offset_bottom -= top_sacrifice_slot_upward_offset
		sacrifice_slot.connect("item_requested", Callable(self, "_on_slot_item_requested"))
		sacrifice_slot.connect("return_requested", Callable(self, "_on_slot_return_requested"))
		_forge_board.add_child(sacrifice_slot)
		_sacrifice_slots.append(sacrifice_slot)


func _connect_inventory_signals() -> void:
	if _global_inventory == null:
		return
	_global_inventory.connect("inventory_changed", Callable(self, "_on_inventory_state_changed"))
	_global_inventory.connect("warehouse_changed", Callable(self, "_on_inventory_state_changed"))
	_global_inventory.connect("coins_changed", Callable(self, "_on_inventory_state_changed"))


func _refresh_all() -> void:
	_refresh_slots()
	_rebuild_inventory_items()
	_refresh_preview()
	_refresh_source_and_category_buttons()


func _refresh_slots() -> void:
	_main_slot.call("refresh", _main_entry)
	# 主槽有效性；极品强化石不能继续升阶，放入后会标红并阻止执行，但仍可单击归还。
	var main_resource: Resource = _main_entry.get("resource") as Resource
	_main_slot.call("set_invalid_state", main_resource != null and not _forge_service.can_use_as_main(main_resource))
	# 当前预览；用于识别顺序计算后没有任何实际效果的牺牲材料。
	var preview: Dictionary = _forge_service.build_preview(_main_entry, _get_active_sacrifice_entries())
	# 无效材料列表；由服务按当前主物品和槽位顺序计算，UI 用于标红对应牺牲槽。
	var invalid_entries: Array = preview.get("invalid_sacrifice_entries", []) as Array
	for slot_index in range(_sacrifice_slots.size()):
		_sacrifice_slots[slot_index].call("refresh", _sacrifice_entries[slot_index])
		# 当前牺牲条目；无主物品、类型/品质不匹配或服务预览判定无效果时显示红色滤镜。
		var sacrifice_entry: Dictionary = _sacrifice_entries[slot_index]
		# 当前牺牲资源；空槽保持正常视觉。
		var sacrifice_resource: Resource = sacrifice_entry.get("resource") as Resource
		# 当前槽位是否无效；无效槽仍保留点击归还能力。
		var sacrifice_invalid: bool = sacrifice_resource != null and (main_resource == null or not _forge_service.can_use_as_sacrifice(main_resource, sacrifice_resource) or sacrifice_entry in invalid_entries)
		_sacrifice_slots[slot_index].call("set_invalid_state", sacrifice_invalid)


func _refresh_preview() -> void:
	_coins_label.text = "金币：%d" % int(_global_inventory.call("get_coins")) if _global_inventory != null else "金币：不可用"
	# 当前非空牺牲材料；锻造服务不需要处理固定五槽中的空字典。
	var active_sacrifices: Array[Dictionary] = _get_active_sacrifice_entries()
	# 锻造预览；只包含确定的耐久、材料数量和费用，不包含强化石最终随机倍率。
	var preview: Dictionary = _forge_service.build_preview(_main_entry, active_sacrifices)
	if not bool(preview.get("valid", false)):
		_preview_label.text = str(preview.get("message", "请配置锻造物品"))
		_forge_cost_label.text = "本次锻造消耗：--"
		_forge_button.disabled = true
		return
	if str(preview.get("forge_mode", ForgeService.FORGE_MODE_WEAPON)) == ForgeService.FORGE_MODE_STONE_UPGRADE:
		# 强化石升阶预览；只显示品质、材料数量和确定成功率，不收取金币。
		var main_stone: Resource = preview.get("main_stone") as Resource
		_preview_label.text = "主强化石：%s\n升阶结果：%s\n牺牲石：%d 颗\n当前成功率：%d%%" % [
			str(main_stone.get("display_name")) if main_stone != null else "未知强化石",
			EnhancementRules.get_quality_display_name(str(preview.get("next_quality_id", EnhancementRules.QUALITY_MEDIUM))),
			int(preview.get("compatible_stone_count", 0)),
			roundi(float(preview.get("success_rate", 0.0)) * 100.0),
		]
		_forge_cost_label.text = "本次升阶消耗：0 金币"
		_forge_button.disabled = _forging_in_progress
		return
	# 主武器名称；预览有效时必定为武器资源。
	var main_weapon: Resource = preview.get("weapon") as Resource
	# 耐久恢复；只展示最终可确定值，超过上限的牺牲耐久不会计入。
	var restored_durability: float = float(preview.get("durability_restored", 0.0))
	_preview_label.text = "主武器：%s\n耐久：%.1f → %.1f（+%.1f）\n强化石：%d 颗\n费用倍率：×%.2f" % [
		str(main_weapon.get("display_name")) if main_weapon != null else "未知武器",
		float(preview.get("durability_before", 0.0)),
		float(preview.get("durability_after", 0.0)),
		restored_durability,
		int(preview.get("compatible_stone_count", 0)),
		float(preview.get("cost_multiplier", 1.0)),
	]
	_forge_cost_label.text = "本次锻造消耗：%d 金币" % int(preview.get("cost", 0))
	_forge_button.disabled = _forging_in_progress


func _rebuild_inventory_items() -> void:
	_clear_container(_item_grid)
	if _global_inventory == null:
		_status_label.text = "全局库存服务不可用"
		return
	# 当前来源原始条目；背包和仓库都由 GlobalInventory 返回只读展示副本。
	var source_entries: Array = _global_inventory.call("get_backpack_entries") if _current_source == SOURCE_BACKPACK else _global_inventory.call("get_warehouse_entries")
	# 可选择条目；移除已选武器并扣减同堆强化石已占用数量，防止一个物品被重复放入超过库存。
	var available_entries: Array[Dictionary] = _build_available_entries(source_entries)
	# 可见条目；分类、搜索、属性方向和排序与背包仓库完全一致。
	var visible_entries: Array[Dictionary] = InventoryQuery.filter_and_sort_entries(available_entries, _primary_category, _subcategory, _search_edit.text, _stone_attribute_filter, _sort_mode)
	if visible_entries.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "当前来源与分类没有可放入的物品"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0.0, 54.0)
		_item_grid.add_child(empty_label)
		return
	for entry in visible_entries:
		# 物品资源；空条目不创建控件。
		var item_resource: Resource = entry.get("resource") as Resource
		if item_resource == null:
			continue
		# 锻造材料卡片；单击发出放入请求，拖拽数据可投放到指定主槽或牺牲槽。
		var item_control: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
		item_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_control.call("configure", item_resource, _current_source, int(entry.get("source_index", -1)), false, "", int(entry.get("quantity", 1)))
		# 材料可选状态；主槽为空时只允许合法主物品，主槽已有物品时只允许符合其牺牲规则的候选材料。
		var main_resource: Resource = _main_entry.get("resource") as Resource
		# 当前卡片是否可选；不可选物品显示灰色滤镜并阻止点击与拖拽。
		var item_selectable: bool = _forge_service.can_use_as_main(item_resource) if main_resource == null else _forge_service.can_use_as_sacrifice(main_resource, item_resource)
		item_control.call("set_item_selection_state", true, item_selectable, false)
		item_control.connect("item_action_requested", Callable(self, "_on_inventory_item_pressed").bind(_current_source))
		_item_grid.add_child(item_control)


func _build_available_entries(source_entries: Array) -> Array[Dictionary]:
	# 可用条目结果；每项复制后保留查询所需字段，不修改真实库存记录。
	var available_entries: Array[Dictionary] = []
	for source_index in range(source_entries.size()):
		if not (source_entries[source_index] is Dictionary):
			continue
		# 原始展示条目；包含资源、数量和获得时间。
		var entry: Dictionary = (source_entries[source_index] as Dictionary).duplicate()
		# 条目资源；用于判断是否已被槽位占用。
		var item_resource: Resource = entry.get("resource") as Resource
		if item_resource == null:
			continue
		entry["source_index"] = source_index
		# 已选数量；武器为 0 或 1，强化石允许同一堆按数量进入多个牺牲槽。
		var selected_quantity: int = _count_selected_resource(item_resource, _current_source)
		# 库存数量；强化石从堆叠数量扣减，武器被选后直接隐藏。
		var stored_quantity: int = maxi(int(entry.get("quantity", 1)), 1)
		if selected_quantity >= stored_quantity:
			continue
		entry["quantity"] = stored_quantity - selected_quantity
		available_entries.append(entry)
	return available_entries


func _count_selected_resource(item_resource: Resource, source_location: String) -> int:
	# 已选数量；主槽与五个牺牲槽都按资源实例和来源精确匹配。
	var selected_quantity: int = 0
	if _entry_matches(_main_entry, item_resource, source_location):
		selected_quantity += 1
	for sacrifice_entry in _sacrifice_entries:
		if _entry_matches(sacrifice_entry, item_resource, source_location):
			selected_quantity += 1
	return selected_quantity


func _entry_matches(entry: Dictionary, item_resource: Resource, source_location: String) -> bool:
	return entry.get("resource") == item_resource and str(entry.get("source_location", "")) == source_location


func _on_inventory_item_pressed(item_resource: Resource, source_location: String) -> void:
	if _forging_in_progress or item_resource == null:
		return
	# 快捷放入条目；来源必须保持为点击时所在背包或仓库，后续单击槽位即可回到原处。
	var forge_entry: Dictionary = {"resource": item_resource, "source_location": source_location}
	if _main_entry.is_empty() and _forge_service.can_use_as_main(item_resource):
		_main_entry = forge_entry
	elif not _main_entry.is_empty() and _forge_service.can_use_as_sacrifice(_main_entry.get("resource") as Resource, item_resource) and _place_in_first_empty_sacrifice(forge_entry):
		pass
	elif _main_entry.is_empty():
		_status_label.text = "该物品不能放入主锻造槽"
		return
	elif not _forge_service.can_use_as_sacrifice(_main_entry.get("resource") as Resource, item_resource):
		_status_label.text = "该物品不符合当前主物品的牺牲规则"
		return
	else:
		_status_label.text = "五个牺牲槽均已放满"
		return
	_status_label.text = "已放入锻造槽；单击槽内物品可快速放回原来源"
	_refresh_all()


func _on_slot_item_requested(slot_index: int, drag_data: Dictionary) -> void:
	if _forging_in_progress:
		return
	# 拖拽物品；ForgeSlotControl 已完成基本类型校验，此处补充库存数量和重复选择校验。
	var item_resource: Resource = drag_data.get("resource") as Resource
	# 拖拽来源；必须为背包或仓库，其他上下文不参与局外锻造。
	var source_location: String = str(drag_data.get("source_location", ""))
	if item_resource == null or source_location not in [SOURCE_BACKPACK, SOURCE_WAREHOUSE]:
		return
	# 当前库存数量；同堆强化石允许按剩余数量放入多个牺牲槽。
	var stored_quantity: int = int(_global_inventory.call("get_storage_resource_quantity", item_resource, source_location))
	if _count_selected_resource(item_resource, source_location) >= stored_quantity:
		_status_label.text = "该物品已全部放入锻造槽"
		return
	# 新槽位条目；只保存真实资源引用和原来源，不提前改变所有权。
	var forge_entry: Dictionary = {"resource": item_resource, "source_location": source_location}
	if slot_index < 0:
		if not _main_entry.is_empty() or not _forge_service.can_use_as_main(item_resource):
			return
		_main_entry = forge_entry
	elif slot_index < _sacrifice_entries.size() and _sacrifice_entries[slot_index].is_empty():
		if _main_entry.is_empty() or not _forge_service.can_use_as_sacrifice(_main_entry.get("resource") as Resource, item_resource):
			_status_label.text = "该物品不符合当前主物品的牺牲规则"
			return
		_sacrifice_entries[slot_index] = forge_entry
	_status_label.text = "已放入指定锻造槽"
	_refresh_all()


func _place_in_first_empty_sacrifice(forge_entry: Dictionary) -> bool:
	for slot_index in range(_sacrifice_entries.size()):
		if _sacrifice_entries[slot_index].is_empty():
			_sacrifice_entries[slot_index] = forge_entry
			return true
	return false


func _on_slot_return_requested(slot_index: int) -> void:
	if _forging_in_progress:
		return
	if slot_index < 0:
		_main_entry.clear()
	elif slot_index < _sacrifice_entries.size():
		_sacrifice_entries[slot_index].clear()
	_status_label.text = "物品已放回原来源"
	_refresh_all()


func _on_forge_pressed() -> void:
	if _forging_in_progress:
		return
	# 非空牺牲材料；动画和最终服务执行共用同一槽位快照。
	var active_sacrifices: Array[Dictionary] = _get_active_sacrifice_entries()
	# 点击时预览；先验证金币以避免金币不足时仍播放完整动画。
	var preview: Dictionary = _forge_service.build_preview(_main_entry, active_sacrifices)
	if not bool(preview.get("valid", false)):
		_status_label.text = str(preview.get("message", "无法锻造"))
		return
	if _global_inventory == null or int(_global_inventory.call("get_coins")) < int(preview.get("cost", 0)):
		_status_label.text = "金币不足，无法开始锻造"
		return
	_forging_in_progress = true
	_status_label.text = "锻造中……"
	_refresh_interaction_state()
	await _play_forge_animation()
	# 最终锻造结果；倍率在动画结束后才由强化石品质规则逐条随机生成。
	var forge_result: Dictionary = _forge_service.execute_forge(_main_entry, active_sacrifices)
	_forging_in_progress = false
	if not bool(forge_result.get("success", false)):
		_status_label.text = str(forge_result.get("message", "锻造失败"))
		_refresh_all()
		return
	_initialize_sacrifice_entries()
	if str(forge_result.get("forge_mode", ForgeService.FORGE_MODE_WEAPON)) == ForgeService.FORGE_MODE_STONE_UPGRADE:
		# 升阶失败保留原主石，成功后主槽引用新品质资源；两种结果都已正常消费全部牺牲石。
		_main_entry = (forge_result.get("result_main_entry", _main_entry) as Dictionary).duplicate()
		_status_label.text = str(forge_result.get("message", "强化石升阶已完成"))
		_refresh_all()
		return
	_status_label.text = "锻造完成"
	_refresh_all()
	_result_dialog.call("present", forge_result)


func _play_forge_animation() -> void:
	_animation_ghosts.clear()
	_animation_start_offsets.clear()
	# 主槽中心；所有牺牲品围绕该点旋转并最终融合。
	var main_center: Vector2 = _main_slot.position + _main_slot.size * 0.5
	for slot_index in range(_sacrifice_entries.size()):
		if _sacrifice_entries[slot_index].is_empty():
			# 空置牺牲槽；动画期间隐藏，避免材料旋转时留下无意义的空白提示。
			_sacrifice_slots[slot_index].visible = false
			continue
		# 牺牲资源；动画标签只显示名称，不复制真实交互控件或所有权状态。
		var item_resource: Resource = _sacrifice_entries[slot_index].get("resource") as Resource
		# 融合幽灵标签；从对应槽位中心出发，动画结束后自动释放。
		var ghost: Label = Label.new()
		ghost.text = str(item_resource.get("display_name")) if item_resource != null else "材料"
		ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ghost.custom_minimum_size = Vector2(112.0, 42.0)
		ghost.size = Vector2(112.0, 42.0)
		ghost.pivot_offset = ghost.size * 0.5
		# 槽位中心；相对主槽中心的偏移用于旋转和半径衰减。
		var slot_center: Vector2 = _sacrifice_slots[slot_index].position + _sacrifice_slots[slot_index].size * 0.5
		ghost.position = slot_center - ghost.size * 0.5
		_forge_board.add_child(ghost)
		_animation_ghosts.append(ghost)
		_animation_start_offsets.append(slot_center - main_center)
		_sacrifice_slots[slot_index].visible = false
	# 动画进度补间；统一回调同步更新全部幽灵，保证它们同时旋转、缩小和靠近。
	var forge_tween: Tween = create_tween()
	forge_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	forge_tween.tween_method(Callable(self, "_update_forge_animation"), 0.0, 1.0, FORGE_ANIMATION_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await forge_tween.finished
	for ghost in _animation_ghosts:
		ghost.queue_free()
	for sacrifice_slot in _sacrifice_slots:
		sacrifice_slot.visible = true
	_animation_ghosts.clear()
	_animation_start_offsets.clear()


func _update_forge_animation(progress: float) -> void:
	# 主槽中心；布局在动画期间保持不变，所有幽灵以此为融合终点。
	var main_center: Vector2 = _main_slot.position + _main_slot.size * 0.5
	# 旋转角度；默认一圈半，进度为 1 时半径收敛到 0。
	var rotation_angle: float = progress * TAU * FORGE_ANIMATION_ROTATIONS
	for ghost_index in range(_animation_ghosts.size()):
		# 动画控件；索引与起始偏移数组一一对应。
		var ghost: Control = _animation_ghosts[ghost_index]
		# 收拢偏移；先旋转再按剩余半径比例缩放，形成围绕主物品逐渐融合的轨迹。
		var animated_offset: Vector2 = _animation_start_offsets[ghost_index].rotated(rotation_angle) * (1.0 - progress)
		ghost.position = main_center + animated_offset - ghost.size * 0.5
		ghost.scale = Vector2.ONE * lerpf(1.0, 0.20, progress)
		ghost.modulate.a = lerpf(1.0, 0.15, progress)
	_main_slot.self_modulate = Color.WHITE.lerp(Color(0.45, 1.0, 0.92, 1.0), sin(progress * PI))


func _refresh_interaction_state() -> void:
	_forge_button.disabled = _forging_in_progress or _forge_button.disabled
	_backpack_source_button.disabled = _forging_in_progress or _current_source == SOURCE_BACKPACK
	_warehouse_source_button.disabled = _forging_in_progress or _current_source == SOURCE_WAREHOUSE
	# 关闭按钮；动画和结算期间阻止隐藏面板导致补间节点生命周期异常。
	var close_button: Button = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/CloseButton") as Button
	if close_button != null:
		close_button.disabled = _forging_in_progress


func _get_active_sacrifice_entries() -> Array[Dictionary]:
	# 非空材料结果；保持槽位顺序，耐久恢复和强化结果按玩家摆放顺序结算。
	var active_entries: Array[Dictionary] = []
	for sacrifice_entry in _sacrifice_entries:
		if not sacrifice_entry.is_empty():
			active_entries.append(sacrifice_entry.duplicate())
	return active_entries


func _create_category_button(target_bar: HBoxContainer, button_text: String, category_name: String, is_primary: bool) -> void:
	# 分类按钮；绑定稳定分类标识，显示文字变化不会影响查询。
	var category_button: Button = Button.new()
	category_button.text = button_text
	category_button.custom_minimum_size = Vector2(96.0, 30.0)
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
	else:
		_create_category_button(_subcategory_bar, "强化石", InventoryQuery.SUBCATEGORY_ENHANCEMENT_STONES, false)
		_create_category_button(_subcategory_bar, "道具", InventoryQuery.SUBCATEGORY_ITEMS, false)
	_refresh_source_and_category_buttons()


func _refresh_source_and_category_buttons() -> void:
	_backpack_source_button.disabled = _forging_in_progress or _current_source == SOURCE_BACKPACK
	_warehouse_source_button.disabled = _forging_in_progress or _current_source == SOURCE_WAREHOUSE
	for category_name in _primary_buttons.keys():
		(_primary_buttons[category_name] as Button).disabled = str(category_name) == _primary_category
	for category_name in _subcategory_buttons.keys():
		(_subcategory_buttons[category_name] as Button).disabled = str(category_name) == _subcategory
	_stone_attribute_option.visible = _primary_category == InventoryQuery.PRIMARY_RESOURCES
	_stone_attribute_clear_button.visible = _primary_category == InventoryQuery.PRIMARY_RESOURCES
	_stone_attribute_clear_button.disabled = _stone_attribute_filter.is_empty()


func _on_source_pressed(source_location: String) -> void:
	if _forging_in_progress:
		return
	_current_source = source_location
	_rebuild_inventory_items()
	_refresh_source_and_category_buttons()


func _on_primary_category_pressed(category_name: String) -> void:
	_primary_category = category_name
	_subcategory = InventoryQuery.SUBCATEGORY_ALL
	_clear_stone_attribute_filter()
	_rebuild_subcategory_buttons()
	_rebuild_inventory_items()


func _on_subcategory_pressed(category_name: String) -> void:
	_subcategory = category_name
	_rebuild_inventory_items()
	_refresh_source_and_category_buttons()


func _on_search_changed(_new_text: String) -> void:
	_rebuild_inventory_items()


func _on_sort_selected(item_index: int) -> void:
	# 排序元数据；异常值回退获得时间，避免空元数据导致查询顺序不稳定。
	var selected_sort_mode: String = str(_sort_option.get_item_metadata(item_index))
	_sort_mode = selected_sort_mode if selected_sort_mode in [InventoryQuery.SORT_ACQUIRED_TIME, InventoryQuery.SORT_ITEM_VALUE] else InventoryQuery.SORT_ACQUIRED_TIME
	_rebuild_inventory_items()


func _on_stone_attribute_selected(item_index: int) -> void:
	if item_index <= 0:
		_stone_attribute_option.select(0)
		return
	# 筛选键；同一项再次选择会取消勾选，多项同时保留并由查询器按并集匹配。
	var filter_key: String = str(_stone_attribute_option.get_item_metadata(item_index))
	if filter_key.is_empty():
		return
	# 新勾选状态；已存在筛选再次点击时取消，其他条件继续保留。
	var should_select: bool = filter_key not in _stone_attribute_filter
	_stone_attribute_option.get_popup().set_item_checked(item_index, should_select)
	if should_select:
		_stone_attribute_filter.append(filter_key)
	else:
		_stone_attribute_filter.erase(filter_key)
	_refresh_stone_attribute_filter_display()
	_rebuild_inventory_items()


func _on_clear_stone_attribute_filter_pressed() -> void:
	_clear_stone_attribute_filter()
	_rebuild_inventory_items()


func _clear_stone_attribute_filter() -> void:
	# 清空全部勾选；逐项恢复未选状态并把下拉框标题重置为 0 个条件。
	_stone_attribute_filter.clear()
	for item_index in range(1, _stone_attribute_option.item_count):
		if not str(_stone_attribute_option.get_item_metadata(item_index)).is_empty():
			_stone_attribute_option.get_popup().set_item_checked(item_index, false)
	_refresh_stone_attribute_filter_display()


func _refresh_stone_attribute_filter_display() -> void:
	# 下拉框固定选中摘要项；具体已选条件通过弹出菜单勾选状态查看，避免单选标题覆盖多选结果。
	_stone_attribute_option.set_item_text(0, "强化筛选（%d）" % _stone_attribute_filter.size())
	_stone_attribute_option.select(0)
	if _stone_attribute_clear_button != null:
		_stone_attribute_clear_button.disabled = _stone_attribute_filter.is_empty()


func _on_inventory_state_changed() -> void:
	if _forging_in_progress:
		return
	# 失效槽位清理；库存外部变化后只移除已不在原来源的引用，不改变仍有效的玩家布局。
	_validate_selected_entries()
	_refresh_all()


func _validate_selected_entries() -> void:
	if not _main_entry.is_empty() and not _is_entry_still_owned(_main_entry, 1):
		_main_entry.clear()
	# 已检查数量表；同一强化石堆叠多个槽位时逐个累计并验证所需总数量。
	var checked_quantities: Dictionary = {}
	for slot_index in range(_sacrifice_entries.size()):
		if _sacrifice_entries[slot_index].is_empty():
			continue
		# 当前条目资源；用于构建来源与实例组合键。
		var item_resource: Resource = _sacrifice_entries[slot_index].get("resource") as Resource
		# 当前来源；与资源实例共同定位库存堆叠。
		var source_location: String = str(_sacrifice_entries[slot_index].get("source_location", ""))
		# 数量键；同一资源每遇到一次需求加一。
		var quantity_key: String = "%s:%d" % [source_location, item_resource.get_instance_id()] if item_resource != null else "invalid"
		checked_quantities[quantity_key] = int(checked_quantities.get(quantity_key, 0)) + 1
		if not _is_entry_still_owned(_sacrifice_entries[slot_index], int(checked_quantities[quantity_key])):
			_sacrifice_entries[slot_index].clear()


func _is_entry_still_owned(entry: Dictionary, required_quantity: int) -> bool:
	if _global_inventory == null:
		return false
	return bool(_global_inventory.call("has_storage_resource_quantity", entry.get("resource") as Resource, str(entry.get("source_location", "")), required_quantity))


func _on_close_pressed() -> void:
	if not _forging_in_progress:
		closed.emit()


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
