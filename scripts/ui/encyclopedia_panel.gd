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
## 左侧条目列表最小宽度；默认 280 像素，保证较长物品名称可读且为右侧完整详情保留主要空间。
const ENTRY_LIST_MINIMUM_WIDTH: float = 280.0
## 左侧单个条目按钮最小高度；默认 40 像素，兼顾紧凑列表密度与清晰的鼠标点击区域。
const ENTRY_LIST_BUTTON_MINIMUM_HEIGHT: float = 40.0
## 右侧详情水平内边距；默认 18 像素，使文字与左右边框保持清晰距离，运行时通常不修改。
const DETAIL_HORIZONTAL_MARGIN: int = 18
## 右侧详情垂直内边距；默认 16 像素，使标题、正文与上下边框保持一致留白，运行时通常不修改。
const DETAIL_VERTICAL_MARGIN: int = 16
## 右侧详情标题字号；默认 18 像素，比普通正文更醒目，修改只影响“详细信息”栏标题。
const DETAIL_TITLE_FONT_SIZE: int = 18
## 右侧详情正文字号；默认 16 像素，覆盖富文本未显式指定字号的属性与说明内容。
const DETAIL_BODY_FONT_SIZE: int = 16
## 右侧详情正文行距；默认 4 像素，增加长属性文本的纵向可读性，修改不改变数值或滚动范围。
const DETAIL_BODY_LINE_SEPARATION: int = 4

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
## 图鉴条目列表容器缓存；当前页签切换或解锁状态变化时清理并重建可点击名称按钮。
var _entry_grid: GridContainer
## 当前页签的图鉴条目快照；列表点击和右侧详情共用同一只读条目数组，避免两侧分别读取内容目录。
var _current_entries: Array[Dictionary] = []
## 左侧条目按钮缓存；下标与当前条目数组一致，用于同步当前选中项的高亮状态。
var _entry_buttons: Array[Button] = []
## 当前选中图鉴条目的稳定键；刷新、首次解锁或切换回面板时尽量保持同一条目详情。
var _selected_entry_key: String = ""
## 右侧完整详情文本缓存；已解锁静态物品使用通用详情格式化器，未解锁项只显示“？？？”。
var _detail_label: RichTextLabel
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
	if _content_catalog == null or _global_inventory == null:
		_resolve_services()
		_connect_inventory_signal()
	_clear_entry_grid()
	# 当前类别条目；包含可静态发现的目录资源，以及资源页统一的强化石条目。
	_current_entries = _build_catalog_entries(_active_tab)
	# 已解锁条目数；只统计当前页签内通过 GlobalInventory 发现记录验证的条目。
	var discovered_count: int = 0
	for entry_index in range(_current_entries.size()):
		# 当前条目是否已解锁；没有库存服务时安全回退为 false，避免目录数据直接泄露。
		var entry: Dictionary = _current_entries[entry_index]
		var is_discovered: bool = _is_entry_discovered(entry)
		if is_discovered:
			discovered_count += 1
		# 当前列表条目按钮；点击后仅更新右侧详情，不会改变图鉴解锁或库存状态。
		var entry_button: Button = _build_entry_card(entry, is_discovered, entry_index) as Button
		_entry_grid.add_child(entry_button)
		_entry_buttons.append(entry_button)
	_progress_label.text = "收集进度：%d / %d" % [discovered_count, _current_entries.size()]
	# 选中条目下标；优先按稳定键恢复上次查看内容，不存在时回退当前分类第一项。
	var selected_index: int = _get_selected_entry_index()
	if selected_index >= 0:
		_set_selected_entry(selected_index, false)
	else:
		_refresh_selected_detail()


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
	# 图鉴主体分栏；左侧为可点击条目列表，右侧为当前选中条目的完整资料，两侧共用当前页签快照。
	var content_split: HBoxContainer = HBoxContainer.new()
	content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.add_theme_constant_override("separation", 12)
	content.add_child(content_split)
	# 左侧列表分区；固定最小宽度并独立滚动，条目较多时不会压缩右侧详情阅读区域。
	var list_panel: PanelContainer = PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(ENTRY_LIST_MINIMUM_WIDTH, 0.0)
	list_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_section_panel(list_panel)
	content_split.add_child(list_panel)
	# 列表分区内容；标题固定在滚动区上方，帮助玩家明确左侧名称用于切换详情。
	var list_content: VBoxContainer = VBoxContainer.new()
	list_content.add_theme_constant_override("separation", 8)
	list_panel.add_child(list_content)
	# 列表标题；说明当前区域仅承担条目选择，不重复展示物品数值。
	var list_title_label: Label = Label.new()
	list_title_label.text = "条目列表"
	UI_STYLE_GUIDE.apply_title_label(list_title_label, 16)
	list_content.add_child(list_title_label)
	# 左侧列表滚动区域；只允许纵向滚动，物品名称永远按单列顺序排列。
	var list_scroll_container: ScrollContainer = ScrollContainer.new()
	list_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_content.add_child(list_scroll_container)
	# 条目网格；保留单个容器缓存以统一重建流程，当前固定一列呈现可点击名称列表。
	var entry_grid: GridContainer = GridContainer.new()
	entry_grid.name = "EncyclopediaEntryList"
	entry_grid.columns = 1
	entry_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_grid.add_theme_constant_override("v_separation", 6)
	list_scroll_container.add_child(entry_grid)
	_entry_grid = entry_grid
	# 右侧详情分区；占用剩余宽度，完整显示选中武器、装备或资源的正式资料。
	var detail_panel: PanelContainer = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_section_panel(detail_panel)
	content_split.add_child(detail_panel)
	# 详情内边距容器；为标题和正文统一保留可调留白，避免文字直接贴住详情分区边框。
	var detail_margin: MarginContainer = MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", DETAIL_HORIZONTAL_MARGIN)
	detail_margin.add_theme_constant_override("margin_top", DETAIL_VERTICAL_MARGIN)
	detail_margin.add_theme_constant_override("margin_right", DETAIL_HORIZONTAL_MARGIN)
	detail_margin.add_theme_constant_override("margin_bottom", DETAIL_VERTICAL_MARGIN)
	detail_panel.add_child(detail_margin)
	# 详情分区内容；标题与可滚动富文本详情分离，长属性列表不会挤压窗口底部返回按钮。
	var detail_content: VBoxContainer = VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 12)
	detail_margin.add_child(detail_content)
	# 详情标题；始终固定在右侧顶部，实际物品名称与属性由下方详情文本提供。
	var detail_title_label: Label = Label.new()
	detail_title_label.text = "详细信息"
	UI_STYLE_GUIDE.apply_title_label(detail_title_label, DETAIL_TITLE_FONT_SIZE)
	detail_content.add_child(detail_title_label)
	# 详情富文本；自身占满右侧剩余空间并使用内部纵向滚动条，避免外层滚动与自适应高度相互挤压导致文字被裁剪。
	var detail_label: RichTextLabel = RichTextLabel.new()
	detail_label.name = "EncyclopediaDetail"
	detail_label.bbcode_enabled = true
	detail_label.fit_content = false
	detail_label.scroll_active = true
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_label.add_theme_font_size_override("normal_font_size", DETAIL_BODY_FONT_SIZE)
	detail_label.add_theme_constant_override("line_separation", DETAIL_BODY_LINE_SEPARATION)
	detail_content.add_child(detail_label)
	_detail_label = detail_label
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
	_selected_entry_key = ""
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
		"entry_key": "resource:%s" % item_resource.resource_path,
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
		"entry_key": "enhancement_stone",
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


func _build_entry_card(entry: Dictionary, is_discovered: bool, entry_index: int) -> Control:
	## 创建左侧可点击图鉴名称；已解锁显示正式名称，未解锁只显示“？？？”，点击后刷新右侧详情而不改变数据状态。
	# 条目列表按钮；固定单行高度以形成稳定纵向列表，选择状态由 _sync_entry_button_selection 统一维护。
	var entry_button: Button = Button.new()
	entry_button.toggle_mode = true
	entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_button.custom_minimum_size = Vector2(0.0, ENTRY_LIST_BUTTON_MINIMUM_HEIGHT)
	entry_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry_button.text = str(entry.get("display_name", "未命名物品")) if is_discovered else UNKNOWN_ENTRY_TEXT
	entry_button.tooltip_text = entry_button.text
	entry_button.pressed.connect(_on_entry_button_pressed.bind(entry_index))
	if not is_discovered:
		entry_button.add_theme_color_override("font_color", UI_STYLE_GUIDE.DISABLED_TEXT_COLOR)
	return entry_button


func _get_selected_entry_index() -> int:
	## 返回当前选中稳定键在本页签中的下标；当前条目不存在时回退第一个条目，空分类返回 -1。
	if _current_entries.is_empty():
		return -1
	for entry_index in range(_current_entries.size()):
		# 当前候选条目；只比较稳定键，不依赖显示名称，因此改名后仍可保留当前详情选择。
		var entry: Dictionary = _current_entries[entry_index]
		if str(entry.get("entry_key", "")) == _selected_entry_key:
			return entry_index
	return 0


func _on_entry_button_pressed(entry_index: int) -> void:
	_set_selected_entry(entry_index)


func _set_selected_entry(entry_index: int, focus_entry_button: bool = true) -> void:
	## 切换当前详情条目；参数控制刷新后是否把键盘焦点交给左侧名称按钮，避免自动刷新抢走用户输入。
	if entry_index < 0 or entry_index >= _current_entries.size():
		return
	# 当前选中条目；保存稳定键使图鉴发现状态变化后仍能保留玩家正在查看的详情。
	var selected_entry: Dictionary = _current_entries[entry_index]
	_selected_entry_key = str(selected_entry.get("entry_key", ""))
	_sync_entry_button_selection(entry_index)
	_refresh_selected_detail()
	if focus_entry_button and entry_index < _entry_buttons.size():
		_entry_buttons[entry_index].grab_focus()


func _sync_entry_button_selection(selected_index: int) -> void:
	## 左侧条目按钮遍历项；仅当前选中条目使用主操作高亮，其他条目恢复普通列表按钮外观。
	for entry_index in range(_entry_buttons.size()):
		# 当前条目按钮；数组与图鉴条目数组在刷新时按相同顺序重建，异常空值安全跳过。
		var entry_button: Button = _entry_buttons[entry_index]
		if entry_button == null:
			continue
		entry_button.set_pressed_no_signal(entry_index == selected_index)
		if entry_index == selected_index:
			UI_STYLE_GUIDE.apply_primary_button(entry_button)
		else:
			entry_button.theme_type_variation = &""


func _refresh_selected_detail() -> void:
	## 刷新右侧详细信息；未解锁条目不读取名称、类型或属性，已解锁静态资源复用统一库存详情格式。
	if _detail_label == null:
		return
	# 当前详情下标；空列表时显示统一占位文本，避免右侧保留上个分类的过期信息。
	var selected_index: int = _get_selected_entry_index()
	if selected_index < 0:
		_detail_label.text = "[center][font_size=22]%s[/font_size][/center]" % UNKNOWN_ENTRY_TEXT
		return
	# 当前详情条目；已解锁判定始终由永久库存服务计算，不由列表按钮文本反推。
	var selected_entry: Dictionary = _current_entries[selected_index]
	if not _is_entry_discovered(selected_entry):
		_detail_label.text = "[center][font_size=28]%s[/font_size][/center]" % UNKNOWN_ENTRY_TEXT
		return
	# 已解锁静态资源；使用库存与仓库相同的完整 BBCode，避免图鉴复制耐久、套装与强化属性公式。
	var item_resource: Resource = selected_entry.get("resource") as Resource
	if item_resource != null:
		_detail_label.text = str(ITEM_DETAIL_FORMATTER.call("build_bbcode", item_resource))
		return
	# 已解锁强化石通用条目；随机强化石没有固定实例，详情仅展示其长期不变的类别说明。
	_detail_label.text = "[font_size=18][b]%s[/b][/font_size]\n类型：%s\n\n%s" % [str(selected_entry.get("display_name", "强化石")), str(selected_entry.get("type_text", "资源 · 强化石")), str(selected_entry.get("description", ""))]


func _clear_entry_grid() -> void:
	## 清空左侧条目列表；列表按钮为纯运行时展示节点，刷新后释放旧节点和缓存以避免保留过期选择状态。
	_entry_buttons.clear()
	for entry_button in _entry_grid.get_children():
		_entry_grid.remove_child(entry_button)
		entry_button.queue_free()


func _on_encyclopedia_changed() -> void:
	refresh()


func _on_close_button_pressed() -> void:
	closed.emit()
