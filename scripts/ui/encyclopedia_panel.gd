extends PanelContainer
class_name EncyclopediaPanel

## 图鉴面板只负责展示内容目录提供的武器、装备、资源与怪物模板。
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
## 怪物图鉴页签稳定标识；读取全部怪物场景并按内容扩展包归属分组展示。
const TAB_MONSTERS: String = "monsters"
## 未解锁条目的统一占位文本；名称、类型与说明均使用该文本，避免泄露未获取物品信息。
const UNKNOWN_ENTRY_TEXT: String = "？？？"
## 图鉴扩展包展示优先级；默认将稳定 ID 为 stelle 的“星”扩展包固定在基础内容之后，未注册时自动跳过且不影响其余扩展包目录顺序。
const PRIORITIZED_CONTENT_PACK_ID: String = "stelle"
## 图鉴装备部位排序表；同一套装按头部、躯干、腿部、脚部顺序展示，未知部位使用兜底序号并排在已知部位之后。
const EQUIPMENT_SLOT_SORT_ORDERS: Dictionary = {"head": 0, "body": 1, "legs": 2, "feet": 3}
## 图鉴资源品质标识排序表；强化石等直接提供 quality_id 的资源按初级、中级、高级、极品顺序展示。
## 特化品质排序补充；特化是独立品质而非普通升阶节点，稳定排在四个普通品质之后。
const RESOURCE_QUALITY_ID_SORT_ORDERS: Dictionary = {"low": 0, "medium": 1, "high": 2, "supreme": 3, "specialized": 4}
## 图鉴资源品质名称前缀；没有 quality_id 的资源通过正式名称前缀识别品质，顺序与强化石品质定义保持一致。
const RESOURCE_QUALITY_NAME_PREFIXES: Array[String] = ["初级", "中级", "高级", "极品", "特化"]
## 无法识别的装备部位或资源品质排序序号；默认 999999，确保已定义的排序规则始终优先于兼容资源。
const FALLBACK_SORT_ORDER: int = 999999
## 图鉴搜索框最小宽度；默认 260 像素，容纳中文关键词并在页签下方保持清晰单行布局。
const SEARCH_FIELD_MINIMUM_WIDTH: float = 260.0
## 搜索防抖等待时间；默认 0.2 秒，输入停止后才刷新一次左侧条目列表。
const SEARCH_DEBOUNCE_SECONDS: float = 0.2
## 扩展包标题分割最小高度；默认 32 像素，使每组内容在左侧列表中拥有清晰可读的视觉边界。
const CONTENT_PACK_DIVIDER_MINIMUM_HEIGHT: float = 32.0
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
## 图鉴关键词搜索框；默认空字符串，按正式名称、类型和说明过滤左侧条目列表。
var _search_edit: LineEdit
## 扩展包显示名称表；键为稳定 pack_id，值为正式扩展包名称，用于构建左侧分组标题而不充当筛选状态。
var _content_pack_display_names: Dictionary = {}
## 扩展包排序序号表；键为稳定 pack_id，值为目录排序索引，基础内容固定序号 0 并排在全部扩展包之前。
var _content_pack_sort_orders: Dictionary = {}
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
## 装备套装展开状态；默认收起，点击套装标题右侧箭头后展开该套装的四件装备。
var _expanded_equipment_sets: Dictionary = {}
## 图鉴目录条目缓存；键为页签稳定标识，值为该页签全部条目数组，命中后不再重新加载资源或实例化怪物场景，解锁状态仍在展示阶段实时判定。
var _catalog_cache: Dictionary = {}
## 搜索防抖计时器；单次触发，输入停止 0.2 秒后才执行一次完整刷新，清空搜索框时立即刷新。
var _search_debounce_timer: Timer


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_resolve_services()
	_build_content()
	_connect_inventory_signal()
	_connect_content_catalog_signal()
	refresh()


func refresh() -> void:
	## 刷新当前页签图鉴；内容模板始终从 ContentCatalog 重新读取，保证启动后新发现状态能立即反映到卡片。
	if _entry_grid == null or _progress_label == null:
		return
	if _content_catalog == null or _global_inventory == null:
		_resolve_services()
		_connect_inventory_signal()
		_connect_content_catalog_signal()
	_refresh_content_pack_group_metadata()
	_clear_entry_grid()
	# 当前类别全部条目；包含目录资源、统一强化石条目或怪物场景，筛选前用于统计完整收集进度。
	var all_entries: Array[Dictionary] = _build_catalog_entries(_active_tab)
	# 已解锁条目数；只统计当前类别全部条目，不因搜索或扩展包筛选改变永久收集进度。
	var discovered_count: int = 0
	for entry in all_entries:
		if _is_entry_discovered(entry):
			discovered_count += 1
	# 当前类别可见条目；关键词筛选仅缩小左侧列表，不修改内容目录、扩展包分组或解锁状态。
	_current_entries = _filter_catalog_entries(all_entries)
	# 上一个已显示条目的扩展包标识；空字符串保证第一个可见条目总会先插入对应内容组标题。
	var previous_content_pack_id: String = "__no_previous_content_pack__"
	var previous_equipment_set_id: String = "__no_previous_equipment_set__"
	for entry_index in range(_current_entries.size()):
		# 当前条目是否已解锁；没有库存服务时安全回退为 false，避免目录数据直接泄露。
		var entry: Dictionary = _current_entries[entry_index]
		var is_discovered: bool = _is_entry_discovered(entry)
		# 当前条目扩展包归属；归属变化时先插入标题分割，再追加本组的可点击名称按钮。
		var content_pack_id: String = str(entry.get("content_pack_id", ""))
		if content_pack_id != previous_content_pack_id:
			_entry_grid.add_child(_build_content_pack_divider(entry))
			previous_content_pack_id = content_pack_id
		var equipment_set_id: String = str(entry.get("equipment_set_id", "")) if _active_tab == TAB_EQUIPMENT else ""
		if _active_tab == TAB_EQUIPMENT and not equipment_set_id.is_empty() and equipment_set_id != previous_equipment_set_id:
			_entry_grid.add_child(_build_equipment_set_header(entry))
			previous_equipment_set_id = equipment_set_id
		if _active_tab == TAB_EQUIPMENT and not equipment_set_id.is_empty() and not bool(_expanded_equipment_sets.get(equipment_set_id, false)):
			continue
		# 当前列表条目按钮；点击后仅更新右侧详情，不会改变图鉴解锁或库存状态。
		var entry_button: Button = _build_entry_card(entry, is_discovered, entry_index) as Button
		_entry_grid.add_child(entry_button)
		_entry_buttons.append(entry_button)
	_progress_label.text = "显示：%d 项  ·  收集进度：%d / %d" % [_current_entries.size(), discovered_count, all_entries.size()]
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


func _connect_content_catalog_signal() -> void:
	## 内容可用状态变化信号；扩展包解锁等目录侧变化发生时清空页签目录缓存，下一次刷新按最新目录重新构建条目。
	if _content_catalog == null or not _content_catalog.has_signal("content_availability_changed"):
		return
	# 目录信号已连接状态；防止刷新流程重复解析服务时把同一回调重复注册。
	var is_catalog_signal_connected: bool = _content_catalog.is_connected("content_availability_changed", Callable(self, "_on_content_availability_changed"))
	if not is_catalog_signal_connected:
		_content_catalog.connect("content_availability_changed", Callable(self, "_on_content_availability_changed"))


func _on_content_availability_changed() -> void:
	## 内容可用状态变化回调；只负责清空目录缓存，实际列表由下一次刷新或宿主打开面板时重新构建。
	_catalog_cache.clear()


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
	# 分类页签容器；四个类别互斥切换，始终保持当前类别的高亮按下状态。
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	content.add_child(tabs)
	_add_tab_button(tabs, TAB_WEAPONS, "武器")
	_add_tab_button(tabs, TAB_EQUIPMENT, "装备")
	_add_tab_button(tabs, TAB_RESOURCES, "资源")
	_add_tab_button(tabs, TAB_MONSTERS, "怪物")
	# 图鉴查询栏；关键词筛选与仓库搜索保持相同匹配范围，只改变当前左侧列表而不改变图鉴永久状态。
	var query_bar: HBoxContainer = HBoxContainer.new()
	query_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	query_bar.add_theme_constant_override("separation", 8)
	content.add_child(query_bar)
	# 关键词搜索框；输入名称、类型或说明片段后立即刷新左侧条目列表并保留当前页签。
	var search_edit: LineEdit = LineEdit.new()
	search_edit.name = "EncyclopediaSearch"
	search_edit.placeholder_text = "搜索名称、类型或说明"
	search_edit.custom_minimum_size = Vector2(SEARCH_FIELD_MINIMUM_WIDTH, 36.0)
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.text_changed.connect(_on_search_text_changed)
	query_bar.add_child(search_edit)
	_search_edit = search_edit
	# 搜索防抖计时器初始化；常驻面板子节点，超时回调直接复用原有整体刷新入口。
	_search_debounce_timer = Timer.new()
	_search_debounce_timer.one_shot = true
	_search_debounce_timer.wait_time = SEARCH_DEBOUNCE_SECONDS
	_search_debounce_timer.timeout.connect(refresh)
	add_child(_search_debounce_timer)
	# 当前分类收集进度；刷新时按当前目录全部条目和永久发现记录更新。
	var progress_label: Label = Label.new()
	progress_label.name = "EncyclopediaProgress"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_muted_accent_label(progress_label)
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


func _on_search_text_changed(_new_text: String) -> void:
	## 处理图鉴关键词变化；输入即时过滤当前分类列表，不改变当前扩展包筛选、解锁记录或详情数据。
	# 搜索防抖处理；清空关键词立即刷新保证响应感，其余输入重置 0.2 秒计时并在停止输入后统一刷新一次。
	if _search_debounce_timer == null or _new_text.strip_edges().is_empty():
		if _search_debounce_timer != null:
			_search_debounce_timer.stop()
		refresh()
		return
	_search_debounce_timer.start()


func _refresh_content_pack_group_metadata() -> void:
	## 刷新扩展包分组元数据；基础内容固定排在最前，其余内容包沿目录稳定顺序生成标题与排序序号。
	## 图鉴会在生成排序序号前将星扩展包提升至全部扩展包首位，使目录原始顺序只用于其余扩展包。
	_content_pack_display_names.clear()
	_content_pack_sort_orders.clear()
	_content_pack_display_names[""] = "基础内容"
	_content_pack_sort_orders[""] = 0
	if _content_catalog == null or not _content_catalog.has_method("get_content_pack_ids"):
		return
	# 全部扩展包标识；目录返回稳定排序结果，图鉴按该顺序建立各分类中的标题分割。
	var content_pack_ids: Array = _content_catalog.call("get_content_pack_ids") as Array
	# 图鉴优先扩展包是否已注册；只在目录中存在“星”扩展包时移动到首位，避免为缺失或无效资源创建空分组。
	var has_prioritized_content_pack: bool = content_pack_ids.has(PRIORITIZED_CONTENT_PACK_ID)
	if has_prioritized_content_pack:
		# 星扩展包原始位置；先移除再插入到扩展包序列首位，使其固定显示在基础内容之后。
		content_pack_ids.erase(PRIORITIZED_CONTENT_PACK_ID)
		content_pack_ids.push_front(PRIORITIZED_CONTENT_PACK_ID)
	for pack_index in range(content_pack_ids.size()):
		# 当前扩展包标识；空 ID 不会作为有效内容组建立，防止异常资源产生无标题分区。
		var content_pack_id: String = str(content_pack_ids[pack_index]).strip_edges()
		if content_pack_id.is_empty():
			continue
		# 扩展包只读档案；优先显示正式名称，缺失时回退稳定 ID，保证所有已登记内容都有标题。
		var content_pack_profile: Dictionary = {}
		if _content_catalog.has_method("get_content_pack_profile"):
			content_pack_profile = _content_catalog.call("get_content_pack_profile", content_pack_id) as Dictionary
		var content_pack_label: String = str(content_pack_profile.get("display_name", "")).strip_edges()
		_content_pack_display_names[content_pack_id] = content_pack_label if not content_pack_label.is_empty() else content_pack_id
		_content_pack_sort_orders[content_pack_id] = pack_index + 1


func _filter_catalog_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	## 返回符合关键词的条目；筛选结果为新数组，绝不改变内容目录的分组顺序、模板或图鉴发现状态。
	# 当前关键词；空字符串表示不按文本过滤，非空时匹配名称、类型与说明的任意片段。
	var search_text: String = _search_edit.text.strip_edges().to_lower() if _search_edit != null else ""
	# 可见图鉴条目；按传入稳定顺序追加，保证清除筛选后恢复原有显示顺序。
	var filtered_entries: Array[Dictionary] = []
	for entry in entries:
		if not _does_entry_match_search_text(entry, search_text):
			continue
		filtered_entries.append(entry)
	return filtered_entries


func _does_entry_match_search_text(entry: Dictionary, search_text: String) -> bool:
	## 判断条目是否匹配关键词；图鉴搜索与仓库一致地按不区分大小写的名称、类型与说明片段进行包含匹配。
	if search_text.is_empty():
		return true
	# 可检索文本；连接三个对玩家开放的字段，不读取未解锁时不应显示的运行时库存信息。
	var searchable_text: String = "%s\n%s\n%s" % [str(entry.get("display_name", "")), str(entry.get("type_text", "")), str(entry.get("description", ""))]
	return search_text in searchable_text.to_lower()


func _build_catalog_entries(tab_id: String) -> Array[Dictionary]:
	## 当前类别全部图鉴条目；每项保存只读模板资源、怪物场景快照或强化石通用元数据，不保存玩家库存实例。
	## 目录缓存补充：条目为构建列表所需的纯展示数据，解锁判定不进缓存并由 _is_entry_discovered 每次实时计算。
	# 页签缓存命中检查；命中时直接复用已构建条目数组，搜索按键不再触碰磁盘加载与怪物场景实例化。
	if _catalog_cache.has(tab_id):
		# 已缓存条目数组；构建时即为类型化数组且刷新流程只读取不修改，可安全返回同一引用。
		var cached_entries: Array[Dictionary] = _catalog_cache.get(tab_id)
		return cached_entries
	var entries: Array[Dictionary] = []
	if _content_catalog == null:
		return entries
	if tab_id == TAB_MONSTERS:
		# 全部怪物场景路径；图鉴必须保留未解锁扩展包怪物的占位条目，因此不读取可用内容池接口。
		if not _content_catalog.has_method("get_all_enemy_scene_paths"):
			return entries
		var monster_scene_paths: PackedStringArray = _content_catalog.call("get_all_enemy_scene_paths") as PackedStringArray
		for monster_scene_path in monster_scene_paths:
			# 怪物图鉴条目；场景根缺少稳定 monster_id 时安全跳过，避免生成永远无法解锁的占位项。
			var monster_entry: Dictionary = _build_monster_entry(monster_scene_path)
			if not monster_entry.is_empty():
				entries.append(monster_entry)
		entries.sort_custom(Callable(self, "_compare_catalog_entries"))
		# 怪物页签缓存写入；离树实例化成本最高，缓存后同页签刷新不再重新实例化任何怪物场景。
		_catalog_cache[tab_id] = entries
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
	# 物品页签缓存写入；同页签后续刷新直接复用条目数组，不再触发任何磁盘资源加载。
	_catalog_cache[tab_id] = entries
	return entries


func _build_monster_entry(monster_scene_path: String) -> Dictionary:
	## 从怪物场景构建图鉴只读快照；仅实例化离树根节点读取导出数据，不启动 AI、物理、掉落或战斗行为。
	# 怪物预制体；只有可加载 PackedScene 才能提供稳定的类型、数值和内容包归属。
	var monster_scene: PackedScene = load(monster_scene_path) as PackedScene
	if monster_scene == null:
		return {}
	# 怪物离树实例；未加入场景树不会触发 ready，因此不会被误登记为玩家遇到。
	var monster_root: Node = monster_scene.instantiate()
	if monster_root == null:
		return {}
	# 稳定怪物标识；图鉴发现记录以该 ID 保存，空值表示场景未满足内容创作协议。
	var monster_id: String = str(monster_root.get("monster_id")).strip_edges()
	if monster_id.is_empty():
		monster_root.free()
		return {}
	# 内容包归属；与物品图鉴使用同一个路径索引，未登记路径属于基础内容。
	var content_pack_id: String = ""
	if _content_catalog != null and _content_catalog.has_method("get_content_pack_id_for_resource_path"):
		content_pack_id = str(_content_catalog.call("get_content_pack_id_for_resource_path", monster_scene_path)).strip_edges()
	# 内容组标题；基础内容和各扩展包复用当前图鉴的正式名称缓存。
	var content_pack_title: String = str(_content_pack_display_names.get(content_pack_id, content_pack_id if not content_pack_id.is_empty() else "基础内容"))
	# 内容组排序序号；基础内容固定在最前，已登记扩展包沿目录规则排序。
	var content_pack_order: int = int(_content_pack_sort_orders.get(content_pack_id, FALLBACK_SORT_ORDER))
	# 攻击类型；远程怪物公开 ranged_projectile_damage，其他当前基础怪物均按近战展示。
	var is_ranged_monster: bool = "ranged_projectile_damage" in monster_root
	# 图鉴战斗数值；仅读取导出配置，不读取出生倍率或当前战斗中的临时生命值。
	var maximum_health: float = maxf(float(monster_root.get("max_health")), 0.0)
	var attack_power: float = maxf(float(monster_root.get("attack_power")), 0.0)
	var defense_power: float = maxf(float(monster_root.get("defense_power")), 0.0)
	var move_speed: float = maxf(float(monster_root.get("move_speed")), 0.0)
	var damage_value: float = maxf(float(monster_root.get("ranged_projectile_damage")) if is_ranged_monster else float(monster_root.get("attack_damage")), 0.0)
	var attack_cooldown: float = maxf(float(monster_root.get("cooldown")) if is_ranged_monster else float(monster_root.get("attack_cooldown")), 0.0)
	# 只读展示快照；所有字段在释放离树实例前复制，后续 UI 不再持有怪物节点。
	var entry: Dictionary = {
		"entry_key": "monster:%s" % monster_id,
		"content_pack_id": content_pack_id,
		"content_pack_title": content_pack_title,
		"content_pack_order": content_pack_order,
		"equipment_set_sort_key": "",
		"equipment_slot_sort_order": FALLBACK_SORT_ORDER,
		"resource_quality_sort_order": FALLBACK_SORT_ORDER,
		"resource": null,
		"is_enhancement_stone": false,
		"is_monster": true,
		"monster_id": monster_id,
		"monster_scene_path": monster_scene_path,
		"display_name": str(monster_root.get("display_name")).strip_edges(),
		"icon_text": "敌",
		"type_text": "怪物 · %s" % ("远程" if is_ranged_monster else "近战"),
		"description": str(monster_root.get("description")).strip_edges(),
		"max_health": maximum_health,
		"attack_power": attack_power,
		"defense_power": defense_power,
		"move_speed": move_speed,
		"damage_value": damage_value,
		"attack_cooldown": attack_cooldown,
	}
	monster_root.free()
	return entry


func _build_resource_entry(item_resource: Resource) -> Dictionary:
	## 静态目录物品条目；显示信息全部来自模板，实际解锁资格仍由 GlobalInventory 对稳定物品标识判定。
	# 内容包归属；基础内容保持空字符串，已登记路径通过内容目录映射到唯一稳定 pack_id。
	var content_pack_id: String = ""
	if _content_catalog != null and _content_catalog.has_method("get_content_pack_id_for_resource_path"):
		content_pack_id = str(_content_catalog.call("get_content_pack_id_for_resource_path", item_resource.resource_path)).strip_edges()
	# 内容组标题；基础内容和所有扩展包均由本页缓存提供正式名称，未知归属安全回退其稳定 ID。
	var content_pack_title: String = str(_content_pack_display_names.get(content_pack_id, content_pack_id if not content_pack_id.is_empty() else "基础内容"))
	# 内容组排序序号；基础内容为 0，扩展包按目录稳定顺序递增，异常归属排到最后。
	# 图鉴分组元数据已先应用星扩展包优先级，因此此处读取的序号同时反映基础内容、星和其余目录顺序。
	var content_pack_order: int = int(_content_pack_sort_orders.get(content_pack_id, 999999))
	# 装备套装排序键；同一内容包内先保持同一套装相邻，未配置套装的装备回退自身稳定路径。
	var equipment_set_sort_key: String = _get_equipment_set_sort_key(item_resource)
	# 装备部位排序序号；头部、躯干、腿部、脚部依次为 0 至 3，非装备资源使用兜底值。
	var equipment_slot_sort_order: int = _get_equipment_slot_sort_order(item_resource)
	# 资源品质排序序号；初级、中级、高级、极品依次为 0 至 3，未分级资源使用兜底值。
	# 特化品质补充：特化使用序号 4，稳定排在四个普通品质之后。
	var resource_quality_sort_order: int = _get_resource_quality_sort_order(item_resource)
	return {
		"entry_key": "resource:%s" % item_resource.resource_path,
		"content_pack_id": content_pack_id,
		"content_pack_title": content_pack_title,
		"content_pack_order": content_pack_order,
		"equipment_set_sort_key": equipment_set_sort_key,
		"equipment_set_id": equipment_set_sort_key if str(item_resource.get("item_kind")) == "equipment" else "",
		"equipment_set_title": str((item_resource.get("equipment_set") as Resource).get("display_name")) if item_resource.get("equipment_set") is Resource else "",
		"equipment_slot_sort_order": equipment_slot_sort_order,
		"resource_quality_sort_order": resource_quality_sort_order,
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
		"content_pack_id": "",
		"content_pack_title": "基础内容",
		"content_pack_order": 0,
		"equipment_set_sort_key": "",
		"equipment_slot_sort_order": FALLBACK_SORT_ORDER,
		"resource_quality_sort_order": FALLBACK_SORT_ORDER,
		"resource": null,
		"is_enhancement_stone": true,
		"display_name": "强化石",
		"icon_text": "◆",
		"type_text": "资源 · 强化石",
		"description": "用于锻造武器或装备的随机材料。品质、适用类型和词条在获得时确定。",
	}


func _compare_catalog_entries(first_entry: Dictionary, second_entry: Dictionary) -> bool:
	## 两个图鉴条目；先按基础内容与扩展包目录顺序分组，再按正式显示名稳定排序，未解锁时仍保留该顺序但不会显示名称。
	## 星扩展包在元数据生成阶段已固定为基础内容后的首个扩展包，剩余扩展包继续使用目录顺序。
	# 第一条目内容组序号；基础内容固定为 0，数值越小越靠前。
	var first_content_pack_order: int = int(first_entry.get("content_pack_order", 999999))
	# 第二条目内容组序号；用于先完成组间排序，组内再比较正式名称。
	var second_content_pack_order: int = int(second_entry.get("content_pack_order", 999999))
	if first_content_pack_order != second_content_pack_order:
		return first_content_pack_order < second_content_pack_order
	# 第一项装备套装排序键；同一扩展包内的装备优先按套装聚合，空键用于非装备条目。
	var first_equipment_set_sort_key: String = str(first_entry.get("equipment_set_sort_key", ""))
	# 第二项装备套装排序键；与第一项不同才结束比较，避免不同套装的部位被交叉排列。
	var second_equipment_set_sort_key: String = str(second_entry.get("equipment_set_sort_key", ""))
	if first_equipment_set_sort_key != second_equipment_set_sort_key:
		return first_equipment_set_sort_key < second_equipment_set_sort_key
	# 第一项装备部位排序序号；同套装备按头部、躯干、腿部、脚部的固定序列排列。
	var first_equipment_slot_sort_order: int = int(first_entry.get("equipment_slot_sort_order", FALLBACK_SORT_ORDER))
	# 第二项装备部位排序序号；只在同一套装内与第一项比较，保持套装部位完整连续。
	var second_equipment_slot_sort_order: int = int(second_entry.get("equipment_slot_sort_order", FALLBACK_SORT_ORDER))
	if first_equipment_slot_sort_order != second_equipment_slot_sort_order:
		return first_equipment_slot_sort_order < second_equipment_slot_sort_order
	# 第一项资源品质排序序号；资源按初级、中级、高级、极品的既定品质路径排列。
	# 特化品质补充：特化不属于升阶路径，但资源列表统一放在极品之后。
	var first_resource_quality_sort_order: int = int(first_entry.get("resource_quality_sort_order", FALLBACK_SORT_ORDER))
	# 第二项资源品质排序序号；仅在相同扩展包与装备排序层级后参与比较。
	var second_resource_quality_sort_order: int = int(second_entry.get("resource_quality_sort_order", FALLBACK_SORT_ORDER))
	if first_resource_quality_sort_order != second_resource_quality_sort_order:
		return first_resource_quality_sort_order < second_resource_quality_sort_order
	return str(first_entry.get("display_name", "")) < str(second_entry.get("display_name", ""))


func _get_equipment_set_sort_key(item_resource: Resource) -> String:
	## 返回装备套装排序键；同套装的四个部位共享稳定键，未配置套装的装备仅按自身路径参与排序。
	if item_resource == null or str(item_resource.get("item_kind")) != "equipment":
		return ""
	# 装备套装资源；为空时表示独立装备，不应被错误合并到任何已有套装。
	var equipment_set: Resource = item_resource.get("equipment_set") as Resource
	if equipment_set == null:
		return item_resource.resource_path
	# 套装稳定标识；优先使用 set_id，避免显示名称调整改变已定义的图鉴组内顺序。
	var equipment_set_id: String = str(equipment_set.get("set_id")).strip_edges()
	return equipment_set_id if not equipment_set_id.is_empty() else equipment_set.resource_path


func _get_equipment_slot_sort_order(item_resource: Resource) -> int:
	## 返回装备部位排序序号；固定使用头部、躯干、腿部、脚部规则，非装备或异常部位排在其后。
	if item_resource == null or str(item_resource.get("item_kind")) != "equipment":
		return FALLBACK_SORT_ORDER
	# 装备部位稳定标识；仅接受 EquipmentData 公开的 head、body、legs、feet 四种值。
	var equipment_slot: String = str(item_resource.get("equipment_slot")).strip_edges()
	return int(EQUIPMENT_SLOT_SORT_ORDERS.get(equipment_slot, FALLBACK_SORT_ORDER))


func _get_resource_quality_sort_order(item_resource: Resource) -> int:
	## 返回资源品质排序序号；优先读取 quality_id，缺失时按正式名称的初级、中级、高级、极品前缀识别。
	## 特化品质补充：quality_id 为 specialized 或名称以“特化”开头时返回特化排序序号。
	if item_resource == null:
		return FALLBACK_SORT_ORDER
	# 物品类型；武器和装备不属于资源品质排序范围，保持图鉴各分类的独立排序规则。
	var item_kind: String = str(item_resource.get("item_kind")).strip_edges()
	if item_kind in ["weapon", "equipment"]:
		return FALLBACK_SORT_ORDER
	# 资源品质稳定标识；强化石等资源直接填写 low、medium、high 或 supreme 时无需解析显示文本。
	# 特化品质补充：specialized 与四个普通品质使用相同的稳定 ID 直接查表流程。
	var quality_id: String = str(item_resource.get("quality_id")).strip_edges()
	if RESOURCE_QUALITY_ID_SORT_ORDERS.has(quality_id):
		return int(RESOURCE_QUALITY_ID_SORT_ORDERS.get(quality_id, FALLBACK_SORT_ORDER))
	# 资源正式名称；修复包等没有 quality_id 的静态资源按中文品质前缀进入相同顺序。
	var display_name: String = str(item_resource.get("display_name")).strip_edges()
	for quality_index in range(RESOURCE_QUALITY_NAME_PREFIXES.size()):
		# 当前品质名称前缀；仅匹配名称开头，避免说明文本或普通名称的偶然包含改变排序。
		var quality_name_prefix: String = RESOURCE_QUALITY_NAME_PREFIXES[quality_index]
		if display_name.begins_with(quality_name_prefix):
			return quality_index
	return FALLBACK_SORT_ORDER


func _is_entry_discovered(entry: Dictionary) -> bool:
	if _global_inventory == null:
		return false
	# 是否为怪物条目；怪物不属于库存资源，首次获得有效玩家目标时由怪物组件登记稳定 monster_id。
	if bool(entry.get("is_monster", false)):
		return _global_inventory.has_method("is_monster_discovered") and bool(_global_inventory.call("is_monster_discovered", str(entry.get("monster_id", ""))))
	# 是否为强化石通用条目；随机资源使用独立公开查询，不伪造不存在的固定 Resource 模板。
	var is_enhancement_stone: bool = bool(entry.get("is_enhancement_stone", false))
	if is_enhancement_stone:
		return _global_inventory.has_method("is_enhancement_stone_discovered") and bool(_global_inventory.call("is_enhancement_stone_discovered"))
	# 当前目录模板资源；库存服务只读取其稳定 ID，模板对象本身不会进入玩家所有权记录。
	var item_resource: Resource = entry.get("resource") as Resource
	return item_resource != null and _global_inventory.has_method("is_resource_discovered") and bool(_global_inventory.call("is_resource_discovered", item_resource))


func _build_content_pack_divider(entry: Dictionary) -> Control:
	## 创建扩展包标题分割；每个可见内容组只在首个条目前插入一次，用于明确基础内容或对应扩展包的边界。
	# 扩展包标题分割面板；使用二级面板样式与普通条目按钮区分，不接收点击或焦点输入。
	var divider_panel: PanelContainer = PanelContainer.new()
	divider_panel.custom_minimum_size = Vector2(0.0, CONTENT_PACK_DIVIDER_MINIMUM_HEIGHT)
	divider_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI_STYLE_GUIDE.apply_section_panel(divider_panel)
	# 标题文字；基础内容直接显示名称，扩展包标题显式追加“扩展包”语义，便于长列表快速扫描。
	var divider_label: Label = Label.new()
	var content_pack_id: String = str(entry.get("content_pack_id", ""))
	var content_pack_title: String = str(entry.get("content_pack_title", "基础内容"))
	divider_label.text = content_pack_title if content_pack_id.is_empty() else "%s · 扩展包" % content_pack_title
	divider_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divider_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_title_label(divider_label, 14)
	divider_panel.add_child(divider_label)
	return divider_panel


func _build_equipment_set_header(entry: Dictionary) -> Control:
	## 套装折叠标题；每个套装只创建一个按钮，右侧箭头明确当前展开状态。
	var header_button: Button = Button.new()
	var set_id: String = str(entry.get("equipment_set_id", ""))
	var set_title: String = str(entry.get("equipment_set_title", "套装"))
	var is_expanded: bool = bool(_expanded_equipment_sets.get(set_id, false))
	header_button.text = set_title if not set_title.is_empty() else "套装"
	header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_button.custom_minimum_size = Vector2(0.0, 36.0)
	header_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 展开提示；独立锚定在按钮最右侧，不跟随套装名称长度移动。
	var expansion_hint: Label = Label.new()
	expansion_hint.text = "▲" if is_expanded else "▼"
	expansion_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expansion_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	expansion_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	expansion_hint.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	expansion_hint.offset_left = -34.0
	expansion_hint.offset_top = -18.0
	expansion_hint.offset_right = -6.0
	expansion_hint.offset_bottom = 18.0
	header_button.add_child(expansion_hint)
	header_button.pressed.connect(_toggle_equipment_set.bind(set_id))
	return header_button


func _toggle_equipment_set(set_id: String) -> void:
	## 切换套装展开状态；状态只属于当前图鉴界面，不写入存档或库存。
	if set_id.is_empty():
		return
	_expanded_equipment_sets[set_id] = not bool(_expanded_equipment_sets.get(set_id, false))
	refresh()


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
		entry_button.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_disabled_text_color())
	# 条目统计计数标签；名称最右侧固定显示获得数量或击杀数量，未解锁条目按 0 展示，便于玩家横向对比。
	var entry_count_label: Label = Label.new()
	entry_count_label.text = str(_get_entry_statistics_count(entry))
	entry_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_count_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	entry_count_label.offset_left = -76.0
	entry_count_label.offset_top = -12.0
	entry_count_label.offset_right = -10.0
	entry_count_label.offset_bottom = 12.0
	UI_STYLE_GUIDE.apply_muted_accent_label(entry_count_label)
	entry_button.add_child(entry_count_label)
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
	# 条目统计行；击杀或获得数量显示在详细信息之前，与左侧列表右缘数字使用同一统计口径。
	var statistics_prefix: String = "[color=#9fd8ff]%s：%d[/color]\n\n" % ["击杀数量" if bool(selected_entry.get("is_monster", false)) else "获得数量", _get_entry_statistics_count(selected_entry)]
	# 已解锁怪物；展示从离树场景快照读取的固定图鉴资料，不实例化 AI 或读取临时战斗状态。
	if bool(selected_entry.get("is_monster", false)):
		_detail_label.text = statistics_prefix + _build_monster_detail_bbcode(selected_entry)
		return
	# 已解锁静态资源；使用库存与仓库相同的完整 BBCode，避免图鉴复制耐久、套装与强化属性公式。
	var item_resource: Resource = selected_entry.get("resource") as Resource
	if item_resource != null:
		_detail_label.text = statistics_prefix + str(ITEM_DETAIL_FORMATTER.call("build_bbcode", item_resource))
		return
	# 已解锁强化石通用条目；随机强化石没有固定实例，详情仅展示其长期不变的类别说明。
	_detail_label.text = statistics_prefix + "[font_size=18][b]%s[/b][/font_size]\n类型：%s\n\n%s" % [str(selected_entry.get("display_name", "强化石")), str(selected_entry.get("type_text", "资源 · 强化石")), str(selected_entry.get("description", ""))]


func _build_monster_detail_bbcode(entry: Dictionary) -> String:
	## 格式化已解锁怪物的固定图鉴资料；只显示场景导出基准值，不把当前出生倍率或剩余生命误写为类型属性。
	# 正式名称；异常空值回退“未知怪物”，正常流程已由 monster_id 和场景作者保证名称存在。
	var display_name: String = str(entry.get("display_name", "未知怪物"))
	# 类型文本；固定为怪物近战或远程分类，便于与场景实际攻击协议对应。
	var type_text: String = str(entry.get("type_text", "怪物"))
	# 图鉴说明；允许空说明，空值时提供固定兜底而不暴露内部场景路径。
	var description: String = str(entry.get("description", "")).strip_edges()
	if description.is_empty():
		description = "暂无怪物描述。"
	# 攻击间隔；保留一位小数与近战和远程场景的导出秒数一致。
	var attack_cooldown: float = float(entry.get("attack_cooldown", 0.0))
	return "[font_size=18][b]%s[/b][/font_size]\n类型：%s\n\n%s\n\n最大生命：%d\n攻击力：%d\n防御力：%d\n移动速度：%d\n单次伤害：%d\n攻击间隔：%.1f 秒" % [display_name, type_text, description, roundi(float(entry.get("max_health", 0.0))), roundi(float(entry.get("attack_power", 0.0))), roundi(float(entry.get("defense_power", 0.0))), roundi(float(entry.get("move_speed", 0.0))), roundi(float(entry.get("damage_value", 0.0))), attack_cooldown]


func _get_entry_statistics_count(entry: Dictionary) -> int:
	## 返回条目对应的统计计数；怪物为击杀数量，物品为获得数量，强化石读取统一类别键，统计服务缺失时返回 0。
	# 当前场景树；独立测试场景可能没有统计服务，此时全部计数按 0 展示。
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return 0
	# 生涯统计服务节点；图鉴只读取计数，不写入任何统计。
	var stats_service: Node = scene_tree.root.get_node_or_null("StatsService")
	if stats_service == null:
		return 0
	if bool(entry.get("is_monster", false)):
		return int(stats_service.call("get_monster_kill_count", str(entry.get("monster_id", "")))) if stats_service.has_method("get_monster_kill_count") else 0
	if bool(entry.get("is_enhancement_stone", false)):
		return int(stats_service.call("get_enhancement_stone_acquire_count")) if stats_service.has_method("get_enhancement_stone_acquire_count") else 0
	# 当前条目模板资源；统计服务按稳定物品键查询累计获得数量。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource != null and stats_service.has_method("get_item_acquire_count"):
		return int(stats_service.call("get_item_acquire_count", item_resource))
	return 0


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
