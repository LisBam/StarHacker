extends PanelContainer
class_name EncyclopediaPanel

## 图鉴面板只负责展示内容目录提供的武器、装备与资源模板。
## 解锁状态由 GlobalInventory 永久保存；本组件不保存物品副本，也不参与购买、装备或消耗流程。

signal closed

## 全局窗口样式指南；为图鉴根面板、条目卡片和按钮提供统一深蓝青色视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 通用物品详情格式化器；已解锁条目的类型名与悬停详情复用库存界面的现有规则。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 武器图鉴页签稳定标识；只用于本面板内部切换，不写入任何存档。
const TAB_WEAPONS: String = "weapons"
## 装备图鉴页签稳定标识；只用于本面板内部切换，不写入任何存档。
const TAB_EQUIPMENT: String = "equipment"
## 资源图鉴页签稳定标识；包含内容目录道具与统一的强化石条目。
const TAB_RESOURCES: String = "resources"
## 未解锁条目的统一占位文本；名称、类型与说明均使用该文本，避免泄露未获取物品信息。
const UNKNOWN_ENTRY_TEXT: String = "？？？"
## 每张图鉴条目的固定最小尺寸；四列网格在 1000 像素宽窗口中保持稳定可读的卡片密度。
const ENTRY_CARD_MINIMUM_SIZE: Vector2 = Vector2(220.0, 126.0)
## 条目网格列数；武器、装备与资源页使用同一列数，窗口尺寸变化时由滚动容器承载溢出内容。
const ENTRY_GRID_COLUMNS: int = 4

## 当前激活图鉴页签；默认武器页，点击页签后只重建当前类别的纯展示卡片。
var _active_tab: String = TAB_WEAPONS
## 全局库存服务缓存；提供已发现状态查询和图鉴更新信号，缺失时所有条目安全显示为未解锁。
var _global_inventory: Node
## 内容目录服务缓存；提供不受角色内容池过滤影响的全量模板路径，缺失时列表保持为空。
var _content_catalog: Node
## 页签按钮缓存表；键为页签稳定标识，值为对应 Button，用于保持当前页签按下状态同步。
var _tab_buttons: Dictionary = {}
## 收集进度文本缓存；显示当前类别已解锁数和总条目数，不参与解锁判定。
var _progress_label: Label
## 图鉴条目网格缓存；当前页签切换或解锁状态变化时清理并重建其子控件。
var _entry_grid: GridContainer
## 返回按钮缓存；点击后仅派发 closed 信号，由主菜单遮罩负责隐藏和恢复焦点。
var _close_button: Button


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_resolve_services()
	_build_content()
	_connect_inventory_signal()
	refresh()


func refresh() -> void:
	## 刷新当前页签图鉴；内容模板始终从 ContentCatalog 重新读取，保证启动后新发现状态能立即反映到卡片。
	if _entry_grid == null or _progress_label == null:
		return
	_clear_entry_grid()
	# 当前类别条目；包含可静态发现的目录资源，以及资源页统一的强化石条目。
	var entries: Array[Dictionary] = _build_catalog_entries(_active_tab)
	# 已解锁条目数；只统计当前页签内通过 GlobalInventory 发现记录验证的条目。
	var discovered_count: int = 0
	for entry in entries:
		# 当前条目是否已解锁；没有库存服务时安全回退为 false，避免目录数据直接泄露。
		var is_discovered: bool = _is_entry_discovered(entry)
		if is_discovered:
			discovered_count += 1
		_entry_grid.add_child(_build_entry_card(entry, is_discovered))
	_progress_label.text = "收集进度：%d / %d" % [discovered_count, entries.size()]


func _resolve_services() -> void:
	## 当前场景树；AutoLoad 服务仅从根节点获取，面板不依赖主菜单脚本向内部注入实例。
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	_global_inventory = scene_tree.root.get_node_or_null("GlobalInventory")
	_content_catalog = scene_tree.root.get_node_or_null("ContentCatalog")


func _connect_inventory_signal() -> void:
	## 图鉴状态变化信号；只在库存服务公开该信号时连接，保持独立场景或测试环境可正常展示空图鉴。
	if _global_inventory == null or not _global_inventory.has_signal("encyclopedia_changed"):
		return
	# 已连接状态；防止组件重入场景树时把同一回调重复注册。
	var is_already_connected: bool = _global_inventory.is_connected("encyclopedia_changed", Callable(self, "_on_encyclopedia_changed"))
	if not is_already_connected:
		_global_inventory.connect("encyclopedia_changed", Callable(self, "_on_encyclopedia_changed"))


func _build_content() -> void:
	## 主内容纵向容器；承载标题、分类页签、进度、滚动条目区与返回按钮，所有间距只影响图鉴视觉。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	# 标题文本；固定说明这是永久收集记录，避免玩家误认为它是当前仓库清单。
	var title_label: Label = Label.new()
	title_label.text = "图鉴"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_title_label(title_label, 24)
	content.add_child(title_label)
	# 规则说明；明确只有实际获得后才能查看条目，出售和消耗不会重新锁定。
	var hint_label: Label = Label.new()
	hint_label.text = "获得物品即可解锁对应条目；未解锁内容显示“？？？”。"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.SECONDARY_TEXT_COLOR)
	content.add_child(hint_label)
	# 分类页签容器；三个类别互斥切换，始终保持当前类别的高亮按下状态。
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	content.add_child(tabs)
	_add_tab_button(tabs, TAB_WEAPONS, "武器")
	_add_tab_button(tabs, TAB_EQUIPMENT, "装备")
	_add_tab_button(tabs, TAB_RESOURCES, "资源")
	# 当前分类收集进度；刷新时按当前目录全部条目和永久发现记录更新。
	var progress_label: Label = Label.new()
	progress_label.name = "EncyclopediaProgress"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.ACCENT_MUTED_COLOR)
	content.add_child(progress_label)
	_progress_label = progress_label
	# 图鉴滚动区域；条目超出固定窗口高度时只滚动内容，不改变顶部页签和底部返回按钮位置。
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll_container)
	# 条目网格；每个类别以相同四列布局显示已解锁与未解锁卡片，保持收集缺口清晰可见。
	var entry_grid: GridContainer = GridContainer.new()
	entry_grid.name = "EncyclopediaEntryGrid"
	entry_grid.columns = ENTRY_GRID_COLUMNS
	entry_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_grid.add_theme_constant_override("h_separation", 10)
	entry_grid.add_theme_constant_override("v_separation", 10)
	scroll_container.add_child(entry_grid)
	_entry_grid = entry_grid
	# 返回按钮；主菜单遮罩监听 closed 后隐藏面板，本组件不直接引用任何主菜单节点。
	var close_button: Button = Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.pressed.connect(_on_close_button_pressed)
	content.add_child(close_button)
	_close_button = close_button
	_sync_tab_buttons()


func _add_tab_button(container: HBoxContainer, tab_id: String, button_text: String) -> void:
	## 分类页签按钮；使用稳定标识保存到缓存表，后续切换时只更新视觉按下状态。
	var tab_button: Button = Button.new()
	tab_button.text = button_text
	tab_button.toggle_mode = true
	tab_button.custom_minimum_size = Vector2(120.0, 38.0)
	tab_button.pressed.connect(_on_tab_button_pressed.bind(tab_id))
	container.add_child(tab_button)
	_tab_buttons[tab_id] = tab_button


func _on_tab_button_pressed(tab_id: String) -> void:
	if tab_id == _active_tab:
		_sync_tab_buttons()
		return
	_active_tab = tab_id
	_sync_tab_buttons()
	refresh()


func _sync_tab_buttons() -> void:
	## 页签按钮遍历项；只允许当前页签保持按下，避免三个 Button 的 toggle 状态彼此独立。
	for raw_tab_id in _tab_buttons.keys():
		# 当前页签按钮；缓存缺失或异常类型时跳过，保持图鉴面板在局部测试中的容错能力。
		var tab_button: Button = _tab_buttons.get(raw_tab_id) as Button
		if tab_button != null:
			tab_button.set_pressed_no_signal(str(raw_tab_id) == _active_tab)
			if str(raw_tab_id) == _active_tab:
				UI_STYLE_GUIDE.apply_primary_button(tab_button)
			else:
				tab_button.theme_type_variation = &""


func _build_catalog_entries(tab_id: String) -> Array[Dictionary]:
	## 当前类别全部图鉴条目；每项保存只读模板资源或强化石通用元数据，不保存玩家库存实例。
	var entries: Array[Dictionary] = []
	if _content_catalog == null:
		return entries
	# 内容目录查询方法；全量路径接口不受可用内容池过滤，确保未获得条目也会占用一个“？？？”图鉴位置。
	var method_name: String = "get_all_weapon_paths" if tab_id == TAB_WEAPONS else ("get_all_equipment_paths" if tab_id == TAB_EQUIPMENT else "get_all_item_paths")
	if not _content_catalog.has_method(method_name):
		return entries
	# 当前类别模板路径；ContentCatalog 已按资源路径稳定排序，后续仍按显示名二次排序便于玩家查阅。
	var resource_paths: PackedStringArray = _content_catalog.call(method_name) as PackedStringArray
	for resource_path in resource_paths:
		# 图鉴模板资源；只读加载，不复制、不写入，也不把查看行为视为获得物品。
		var item_resource: Resource = load(resource_path) as Resource
		if item_resource == null:
			continue
		entries.append(_build_resource_entry(item_resource))
	if tab_id == TAB_RESOURCES:
		entries.append(_build_enhancement_stone_entry())
	entries.sort_custom(Callable(self, "_compare_catalog_entries"))
	return entries


func _build_resource_entry(item_resource: Resource) -> Dictionary:
	## 静态目录物品条目；显示信息全部来自模板，实际解锁资格仍由 GlobalInventory 对稳定物品标识判定。
	return {
		"resource": item_resource,
		"is_enhancement_stone": false,
		"display_name": str(item_resource.get("display_name")).strip_edges(),
		"icon_text": str(item_resource.get("icon_text")).strip_edges(),
		"type_text": str(ITEM_DETAIL_FORMATTER.call("get_item_type_label", item_resource)),
		"description": str(item_resource.get("description")).strip_edges(),
	}


func _build_enhancement_stone_entry() -> Dictionary:
	## 强化石通用条目；强化石按随机品质与词条生成，不存在固定模板，因此任意一颗实际获得后解锁这一类收集记录。
	return {
		"resource": null,
		"is_enhancement_stone": true,
		"display_name": "强化石",
		"icon_text": "◆",
		"type_text": "资源 · 强化石",
		"description": "用于锻造武器或装备的随机材料。品质、适用类型和词条在获得时确定。",
	}


func _compare_catalog_entries(first_entry: Dictionary, second_entry: Dictionary) -> bool:
	## 两个图鉴条目；按正式显示名稳定排序，未解锁时仍保留该顺序但不会向玩家显示名称。
	return str(first_entry.get("display_name", "")) < str(second_entry.get("display_name", ""))


func _is_entry_discovered(entry: Dictionary) -> bool:
	if _global_inventory == null:
		return false
	# 是否为强化石通用条目；随机资源使用独立公开查询，不伪造不存在的固定 Resource 模板。
	var is_enhancement_stone: bool = bool(entry.get("is_enhancement_stone", false))
	if is_enhancement_stone:
		return _global_inventory.has_method("is_enhancement_stone_discovered") and bool(_global_inventory.call("is_enhancement_stone_discovered"))
	# 当前目录模板资源；库存服务只读取其稳定 ID，模板对象本身不会进入玩家所有权记录。
	var item_resource: Resource = entry.get("resource") as Resource
	return item_resource != null and _global_inventory.has_method("is_resource_discovered") and bool(_global_inventory.call("is_resource_discovered", item_resource))


func _build_entry_card(entry: Dictionary, is_discovered: bool) -> Control:
	## 单张图鉴卡片；已解锁时显示正式信息和原生悬停详情，未解锁时所有玩家可见文本保持“？？？”。
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = ENTRY_CARD_MINIMUM_SIZE
	UI_STYLE_GUIDE.apply_section_panel(card)
	# 卡片内容容器；图标、名称、类型和说明使用垂直层级，避免未解锁条目暴露任何模板字段。
	var card_content: VBoxContainer = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 4)
	card.add_child(card_content)
	# 图标文本；已解锁读取资源图标，未解锁同样使用占位文本以隐藏稀有度和分类线索。
	var icon_label: Label = Label.new()
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 22)
	icon_label.text = str(entry.get("icon_text", UNKNOWN_ENTRY_TEXT)) if is_discovered else UNKNOWN_ENTRY_TEXT
	card_content.add_child(icon_label)
	# 名称文本；已解锁后显示正式名称，异常空名称仍回退“未命名物品”确保卡片可读。
	var name_label: Label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.text = str(entry.get("display_name", "未命名物品")) if is_discovered else UNKNOWN_ENTRY_TEXT
	card_content.add_child(name_label)
	# 类型文本；已解锁后说明武器、装备或资源分类，未解锁时不泄露条目归属之外的额外信息。
	var type_label: Label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.ACCENT_MUTED_COLOR if is_discovered else UI_STYLE_GUIDE.DISABLED_TEXT_COLOR)
	type_label.text = str(entry.get("type_text", "")) if is_discovered else UNKNOWN_ENTRY_TEXT
	card_content.add_child(type_label)
	# 说明文本；限制为两行并自动换行，完整信息可通过已解锁条目的悬停提示查看。
	var description_label: Label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 2
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.SECONDARY_TEXT_COLOR if is_discovered else UI_STYLE_GUIDE.DISABLED_TEXT_COLOR)
	description_label.text = str(entry.get("description", "")) if is_discovered else UNKNOWN_ENTRY_TEXT
	card_content.add_child(description_label)
	if not is_discovered:
		card.modulate = Color(0.62, 0.66, 0.70, 1.0)
		return card
	# 已解锁资源；强化石通用条目没有固定 Resource，因此不创建与随机词条不匹配的详情提示。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource != null:
		card.tooltip_text = str(ITEM_DETAIL_FORMATTER.call("build_plain_text", item_resource))
	return card


func _clear_entry_grid() -> void:
	## 待移除图鉴卡片；条目卡片为纯运行时展示节点，刷新后释放旧节点以避免保留过期解锁文本。
	for entry_card in _entry_grid.get_children():
		_entry_grid.remove_child(entry_card)
		entry_card.queue_free()


func _on_encyclopedia_changed() -> void:
	refresh()


func _on_close_button_pressed() -> void:
	closed.emit()
