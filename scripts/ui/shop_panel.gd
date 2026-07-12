extends PanelContainer
class_name ShopPanel

## 商店面板提供普通商店与灰市通道，并复用仓库同款武器/资源两级分类查询。
## 商品刷新、价格和购买结算全部委托 ShopService，面板只维护当前查看条件和确认弹窗。

signal closed

## 商店商品卡片脚本；每个条目独立展示最终价格、倍率和二手说明。
const SHOP_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/shop_item_control.gd")
## 通用物品卡片视图；商品滚动区读取其悬浮安全留白，避免放大后的边缘被裁剪。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 全局窗口样式指南；统一商店主窗口、频道标签、查询控件和状态区域视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 普通商店通道标识；显示随机刷新武器与资源，并允许金币手动刷新。
const CHANNEL_NORMAL: String = "normal"
## 灰市通道标识；显示最近五次撤离失败中实际遗失且尚未购回的物品。
const CHANNEL_GRAY: String = "gray"

## 商店面板最小尺寸；默认与仓库主面板一致适配 1280×720 窗口。
@export var panel_minimum_size: Vector2 = Vector2(960.0, 620.0)
## 底部状态提示淡出时长；默认 3 秒，商店刷新和购买结果会在该时间内线性淡出后清空。
@export_range(0.5, 10.0, 0.1) var status_fade_duration_seconds: float = 3.0

## 商店服务缓存；负责库存、刷新倒计时、灰市批次和购买结算。
var _shop_service: Node
## 全局库存服务缓存；只读取金币余额并监听变化，不直接执行购买。
var _global_inventory: Node
## 当前商店通道；默认普通商店，可切换到灰市查看失败遗失物。
var _current_channel: String = CHANNEL_NORMAL
## 当前一级分类；默认全部，同时展示武器和资源并与仓库查询规则保持一致。
var _primary_category: String = InventoryQuery.PRIMARY_ALL
## 当前二级分类；默认全部，切换一级分类时自动重置。
var _subcategory: String = InventoryQuery.SUBCATEGORY_ALL
## 当前强化石属性筛选键；默认空字符串表示全部属性与方向。
var _stone_attribute_filter: String = ""
## 当前排序模式；默认按刷新列表原始顺序，查询器使用获得时间模式稳定保留下标顺序。
var _sort_mode: String = InventoryQuery.SORT_ACQUIRED_TIME
## 普通商店通道按钮；选中时禁用以表示当前页面。
var _normal_channel_button: Button
## 灰市通道按钮；选中时禁用以表示当前页面。
var _gray_channel_button: Button
## 金币标签；监听 GlobalInventory 金币变化后即时刷新。
var _coins_label: Label
## 自动刷新倒计时标签；每秒显示距离下次十分钟刷新剩余时间。
var _refresh_countdown_label: Label
## 手动刷新按钮；文本包含本次所需金币并随连续刷新次数更新。
var _manual_refresh_button: Button
## 状态提示标签；用于显示刷新成功、金币不足或购买结果。
var _status_label: Label
## 搜索输入框；按商品名称、说明、分类和强化词条实时过滤。
var _search_edit: LineEdit
## 强化属性筛选框；只在资源分类显示，规则与背包仓库一致。
var _stone_attribute_option: OptionButton
## 一级分类按钮表；键为分类标识，值为对应按钮，用于同步禁用状态。
var _primary_buttons: Dictionary = {}
## 二级分类按钮表；每次一级分类变化后重建。
var _subcategory_buttons: Dictionary = {}
## 二级分类按钮栏；武器显示全部/近战/远程，资源显示全部/强化石。
var _subcategory_bar: HBoxContainer
## 商品网格；每次筛选、刷新或购买后重建可见商品卡片。
var _item_grid: HFlowContainer
## 商品滚动区；商品数量超过当前高度时允许垂直滚动。
var _item_scroll: ScrollContainer
## 购买确认弹窗；确认前显示物品名称和金币价格，避免误购。
var _purchase_dialog: CommonConfirmationDialog
## 待购买商品编号；弹窗确认时交给 ShopService，默认空字符串表示无待处理商品。
var _pending_stock_id: String = ""
## 待购买灰市批次编号；普通商店为空，灰市用于精确定位失败批次。
var _pending_failure_group_id: String = ""
## 倒计时刷新累计时间；默认 0，达到一秒后更新文本并检查自动刷新。
var _countdown_update_accumulator: float = 0.0
## 当前状态提示已显示时长；默认 -1 表示没有待淡出的提示，非负值用于计算透明度。
var _status_fade_elapsed_seconds: float = -1.0


func _ready() -> void:
	custom_minimum_size = panel_minimum_size
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_shop_service = get_tree().root.get_node_or_null("ShopService")
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	_connect_services()
	_rebuild_content()
	_refresh_header()


func _process(delta: float) -> void:
	_update_status_fade(delta)
	_countdown_update_accumulator += delta
	if _countdown_update_accumulator < 1.0:
		return
	_countdown_update_accumulator = 0.0
	if _shop_service != null:
		_shop_service.call("ensure_automatic_refresh")
	_refresh_header()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	# 外层边距；保持标题、筛选和商品卡片与面板边缘之间的稳定留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	# 主内容容器；纵向排列标题、通道、查询栏、商品区和底部状态。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	# 标题栏；显示商店标题、金币与关闭按钮。
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	# 标题文本；占据剩余宽度并明确当前为局外商店。
	var title_label: Label = Label.new()
	title_label.text = "量子商店"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 26)
	UI_STYLE_GUIDE.apply_title_label(title_label)
	header.add_child(title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 18)
	_coins_label.add_theme_color_override("font_color", Color("ffd45c"))
	header.add_child(_coins_label)
	# 关闭按钮；返回主菜单并保留当前商店库存状态。
	var close_button: Button = Button.new()
	close_button.text = "关闭商店"
	close_button.custom_minimum_size = Vector2(116.0, 38.0)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	# 通道栏；普通商店和灰市互斥切换，共用下方分类与商品区域。
	var channel_bar: HBoxContainer = HBoxContainer.new()
	channel_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	channel_bar.add_theme_constant_override("separation", 10)
	content.add_child(channel_bar)
	_normal_channel_button = Button.new()
	_normal_channel_button.text = "普通商店"
	_normal_channel_button.custom_minimum_size = Vector2(160.0, 38.0)
	_normal_channel_button.pressed.connect(_on_channel_pressed.bind(CHANNEL_NORMAL))
	channel_bar.add_child(_normal_channel_button)
	_gray_channel_button = Button.new()
	_gray_channel_button.text = "灰市 · 最近5次失败遗失物"
	_gray_channel_button.custom_minimum_size = Vector2(260.0, 38.0)
	_gray_channel_button.pressed.connect(_on_channel_pressed.bind(CHANNEL_GRAY))
	channel_bar.add_child(_gray_channel_button)
	# 刷新栏；灰市不参与十分钟刷新，切换通道时整体隐藏。
	var refresh_bar: HBoxContainer = HBoxContainer.new()
	refresh_bar.name = "RefreshBar"
	refresh_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	refresh_bar.add_theme_constant_override("separation", 12)
	content.add_child(refresh_bar)
	_refresh_countdown_label = Label.new()
	_refresh_countdown_label.custom_minimum_size = Vector2(230.0, 36.0)
	_refresh_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	refresh_bar.add_child(_refresh_countdown_label)
	_manual_refresh_button = Button.new()
	_manual_refresh_button.custom_minimum_size = Vector2(210.0, 36.0)
	_manual_refresh_button.pressed.connect(_on_manual_refresh_pressed)
	refresh_bar.add_child(_manual_refresh_button)
	# 查询栏；关键词和强化属性方向筛选与仓库规则保持一致。
	var query_bar: HBoxContainer = HBoxContainer.new()
	query_bar.add_theme_constant_override("separation", 8)
	content.add_child(query_bar)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索商品、分类或强化词条"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_changed)
	query_bar.add_child(_search_edit)
	_stone_attribute_option = OptionButton.new()
	_stone_attribute_option.custom_minimum_size = Vector2(160.0, 36.0)
	_stone_attribute_option.add_item("全部强化属性")
	_stone_attribute_option.set_item_metadata(0, "")
	for direction in InventoryQuery.STONE_FILTER_DIRECTIONS:
		_stone_attribute_option.add_separator(InventoryQuery.get_stone_attribute_direction_group_label(direction))
		for stat_name in EnhancementRules.STAT_KEYS:
			_stone_attribute_option.add_item(InventoryQuery.get_stone_attribute_filter_label(stat_name, direction))
			_stone_attribute_option.set_item_metadata(_stone_attribute_option.item_count - 1, InventoryQuery.build_stone_attribute_filter_key(stat_name, direction))
	_stone_attribute_option.item_selected.connect(_on_stone_attribute_selected)
	query_bar.add_child(_stone_attribute_option)
	# 一级分类栏；与仓库相同显示全部、武器和资源。
	var primary_bar: HBoxContainer = HBoxContainer.new()
	primary_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	primary_bar.add_theme_constant_override("separation", 8)
	content.add_child(primary_bar)
	_create_category_button(primary_bar, "全部", InventoryQuery.PRIMARY_ALL, true)
	_create_category_button(primary_bar, "武器", InventoryQuery.PRIMARY_WEAPONS, true)
	_create_category_button(primary_bar, "装备", InventoryQuery.PRIMARY_EQUIPMENT, true)
	_create_category_button(primary_bar, "资源", InventoryQuery.PRIMARY_RESOURCES, true)
	_subcategory_bar = HBoxContainer.new()
	_subcategory_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_subcategory_bar.add_theme_constant_override("separation", 6)
	content.add_child(_subcategory_bar)
	_rebuild_subcategory_buttons()
	# 商品滚动区；网格使用双列宽卡片，与仓库分类浏览密度一致。
	# 流式布局补充：当前按可用宽度自动换行并逐行居中，不再限制双列。
	_item_scroll = ScrollContainer.new()
	_item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_item_scroll)
	# 商品悬浮安全边距；滚动容器会裁剪越界内容，因此四周显式预留标准卡牌放大空间。
	var item_scroll_margin: MarginContainer = MarginContainer.new()
	item_scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll_margin.add_theme_constant_override("margin_left", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	item_scroll_margin.add_theme_constant_override("margin_top", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	item_scroll_margin.add_theme_constant_override("margin_right", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	item_scroll_margin.add_theme_constant_override("margin_bottom", ITEM_CARD_VIEW_SCRIPT.HOVER_SAFE_MARGIN)
	_item_scroll.add_child(item_scroll_margin)
	_item_grid = HFlowContainer.new()
	_item_grid.alignment = FlowContainer.ALIGNMENT_CENTER
	_item_grid.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.add_theme_constant_override("h_separation", 8)
	_item_grid.add_theme_constant_override("v_separation", 8)
	item_scroll_margin.add_child(_item_grid)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)
	_purchase_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_purchase_dialog.confirmed.connect(_on_purchase_confirmed)
	add_child(_purchase_dialog)


func _connect_services() -> void:
	if _shop_service != null:
		_shop_service.connect("shop_stock_changed", Callable(self, "_on_shop_stock_changed"))
		_shop_service.connect("gray_market_changed", Callable(self, "_on_gray_market_changed"))
		_shop_service.connect("refresh_state_changed", Callable(self, "_refresh_header"))
	if _global_inventory != null:
		_global_inventory.connect("coins_changed", Callable(self, "_refresh_header"))
	# 开发者调试设置；价格倍率显示切换后重建卡片，避免等待商店刷新才更新文本。
	var debug_settings: Node = get_tree().root.get_node_or_null("DebugSettings")
	if debug_settings != null and debug_settings.has_signal("debug_information_visibility_changed"):
		debug_settings.connect("debug_information_visibility_changed", Callable(self, "_on_debug_information_visibility_changed"))


func _create_category_button(target_bar: HBoxContainer, button_text: String, category_name: String, is_primary: bool) -> void:
	# 分类按钮；绑定稳定分类标识，显示文字未来调整不会影响查询逻辑。
	var category_button: Button = Button.new()
	category_button.text = button_text
	category_button.custom_minimum_size = Vector2(112.0, 34.0)
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
		_create_category_button(_subcategory_bar, "头部", "head", false)
		_create_category_button(_subcategory_bar, "躯干", "body", false)
		_create_category_button(_subcategory_bar, "腿部", "legs", false)
		_create_category_button(_subcategory_bar, "脚部", "feet", false)
	elif _primary_category == InventoryQuery.PRIMARY_RESOURCES:
		_create_category_button(_subcategory_bar, "强化石", InventoryQuery.SUBCATEGORY_ENHANCEMENT_STONES, false)
		_create_category_button(_subcategory_bar, "道具", InventoryQuery.SUBCATEGORY_ITEMS, false)
	_refresh_category_buttons()


func _refresh_category_buttons() -> void:
	for category_name in _primary_buttons.keys():
		(_primary_buttons[category_name] as Button).disabled = str(category_name) == _primary_category
	for category_name in _subcategory_buttons.keys():
		(_subcategory_buttons[category_name] as Button).disabled = str(category_name) == _subcategory
	_normal_channel_button.disabled = _current_channel == CHANNEL_NORMAL
	_gray_channel_button.disabled = _current_channel == CHANNEL_GRAY
	_stone_attribute_option.visible = _primary_category == InventoryQuery.PRIMARY_RESOURCES
	# 刷新栏；通过名称查找固定父节点，灰市通道不显示自动或手动刷新控制。
	var refresh_bar: Control = _refresh_countdown_label.get_parent() as Control
	if refresh_bar != null:
		refresh_bar.visible = _current_channel == CHANNEL_NORMAL


func _rebuild_content() -> void:
	_clear_container(_item_grid)
	if _shop_service == null:
		_show_status("商店服务不可用")
		return
	# 当前通道条目；普通商店会先检查十分钟自动刷新，灰市按最近失败批次平铺。
	var source_entries: Array = _shop_service.call("get_shop_entries") if _current_channel == CHANNEL_NORMAL else _shop_service.call("get_gray_market_entries")
	# 可见条目；复用仓库同款分类、搜索和强化属性方向筛选。
	var visible_entries: Array[Dictionary] = InventoryQuery.filter_and_sort_entries(source_entries, _primary_category, _subcategory, _search_edit.text, _stone_attribute_filter, _sort_mode)
	if visible_entries.is_empty():
		# 空状态；占满双列宽度需要添加两个控件中的第一个提示，当前文本已足够明确通道与分类。
		# 流式布局补充：空状态由居中容器承载，不再依赖双列占位规则。
		var empty_label: Label = Label.new()
		empty_label.text = "当前分类暂无商品" if _current_channel == CHANNEL_NORMAL else "最近五次失败中没有可购回的此类遗失物"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0.0, 70.0)
		_item_grid.add_child(empty_label)
	else:
		for entry in visible_entries:
			# 商品卡片；来源下标只用于查询稳定排序，购买使用 stock_id 和灰市批次编号。
			var item_control: Button = SHOP_ITEM_CONTROL_SCRIPT.new() as Button
			item_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# 先加入场景树；商品配置需要读取全局调试设置，挂载后才能安全访问 get_tree()。
			_item_grid.add_child(item_control)
			item_control.call("configure", entry, _current_channel == CHANNEL_GRAY)
			item_control.connect("purchase_requested", Callable(self, "_on_purchase_requested"))
	_refresh_category_buttons()
	_refresh_header()


func _refresh_header() -> void:
	_coins_label.text = "金币：%d" % int(_global_inventory.call("get_coins")) if _global_inventory != null else "金币：不可用"
	if _shop_service == null:
		_refresh_countdown_label.text = "自动刷新：不可用"
		_manual_refresh_button.text = "刷新不可用"
		_manual_refresh_button.disabled = true
		return
	# 剩余秒数；格式化为分秒，达到 0 时 ShopService 会立即完成自动刷新。
	var remaining_seconds: int = int(_shop_service.call("get_seconds_until_automatic_refresh"))
	# 剩余整分钟；显式使用浮点除法后向下取整，避免整数除法警告且保持倒计时显示稳定。
	var remaining_minutes: int = floori(float(remaining_seconds) / 60.0)
	# 当前分钟内剩余秒数；取值为 0 至 59，与整分钟共同组成 mm:ss。
	var remaining_minute_seconds: int = remaining_seconds % 60
	_refresh_countdown_label.text = "自动刷新：%02d:%02d" % [remaining_minutes, remaining_minute_seconds]
	# 手动刷新费用；每次成功刷新后指数增长，自动刷新后恢复 10 金币。
	var manual_cost: int = int(_shop_service.call("get_manual_refresh_cost"))
	_manual_refresh_button.text = "花费 %d 金币刷新" % manual_cost
	_manual_refresh_button.disabled = _current_channel != CHANNEL_NORMAL


func _on_channel_pressed(channel_name: String) -> void:
	_current_channel = channel_name
	_status_label.text = ""
	_status_label.modulate = Color.WHITE
	_status_fade_elapsed_seconds = -1.0
	_rebuild_content()


func _on_primary_category_pressed(category_name: String) -> void:
	_primary_category = category_name
	_subcategory = InventoryQuery.SUBCATEGORY_ALL
	_stone_attribute_filter = ""
	_stone_attribute_option.select(0)
	_rebuild_subcategory_buttons()
	_rebuild_content()


func _on_subcategory_pressed(category_name: String) -> void:
	_subcategory = category_name
	_rebuild_content()


func _on_search_changed(_new_text: String) -> void:
	_rebuild_content()


func _on_stone_attribute_selected(item_index: int) -> void:
	_stone_attribute_filter = str(_stone_attribute_option.get_item_metadata(item_index))
	_rebuild_content()


func _on_manual_refresh_pressed() -> void:
	if _shop_service == null:
		return
	# 刷新结果；服务先检查金币再扣款和重建库存，失败不会增加连续刷新次数。
	var refresh_result: Dictionary = _shop_service.call("request_manual_refresh") as Dictionary
	_show_status(str(refresh_result.get("message", "刷新失败")))
	_rebuild_content()


func _on_purchase_requested(stock_id: String, failure_group_id: String) -> void:
	# 当前条目集合；重新读取服务以防自动刷新刚好发生，找不到时不打开确认弹窗。
	var source_entries: Array = _shop_service.call("get_shop_entries") if failure_group_id.is_empty() else _shop_service.call("get_gray_market_entries")
	for raw_entry in source_entries:
		if not (raw_entry is Dictionary) or str((raw_entry as Dictionary).get("stock_id", "")) != stock_id:
			continue
		# 待购资源；用于确认弹窗展示名称，最终购买仍以稳定编号定位。
		var item_resource: Resource = (raw_entry as Dictionary).get("resource") as Resource
		_pending_stock_id = stock_id
		_pending_failure_group_id = failure_group_id
		_purchase_dialog.present_adaptive("确认购买", "确认花费 %d 金币购买“%s”吗？\n购买后物品将直接存入永久仓库。" % [int((raw_entry as Dictionary).get("price", 0)), str(item_resource.get("display_name")) if item_resource != null else "未知物品"], "购买", "取消", true)
		return
	_show_status("该商品已售出或已经刷新")


func _on_purchase_confirmed() -> void:
	if _shop_service == null or _pending_stock_id.is_empty():
		return
	# 购买结果；普通商店和灰市分别使用对应服务接口，成功后条目从该通道永久移除。
	var purchase_result: Dictionary
	if _pending_failure_group_id.is_empty():
		purchase_result = _shop_service.call("purchase_shop_entry", _pending_stock_id) as Dictionary
	else:
		purchase_result = _shop_service.call("purchase_gray_market_entry", _pending_stock_id, _pending_failure_group_id) as Dictionary
	_show_status(str(purchase_result.get("message", "购买失败")))
	_pending_stock_id = ""
	_pending_failure_group_id = ""
	_rebuild_content()


func _on_shop_stock_changed() -> void:
	if _current_channel == CHANNEL_NORMAL:
		_show_status("商店已刷新")
		_rebuild_content()


func _on_gray_market_changed() -> void:
	if _current_channel == CHANNEL_GRAY:
		_rebuild_content()


func _on_debug_information_visibility_changed(_visible: bool) -> void:
	_rebuild_content()


func _show_status(message: String) -> void:
	_status_label.text = message
	_status_label.modulate = Color.WHITE
	_status_fade_elapsed_seconds = 0.0 if not message.is_empty() else -1.0


func _update_status_fade(delta: float) -> void:
	if _status_fade_elapsed_seconds < 0.0 or _status_label == null:
		return
	# 有效淡出时长；至少 0.1 秒，避免检查器异常值导致除零。
	var resolved_duration: float = maxf(status_fade_duration_seconds, 0.1)
	_status_fade_elapsed_seconds += maxf(delta, 0.0)
	if _status_fade_elapsed_seconds >= resolved_duration:
		_status_label.text = ""
		_status_label.modulate = Color.WHITE
		_status_fade_elapsed_seconds = -1.0
		return
	# 提示剩余透明度；从 1 线性衰减至 0，文本内容保持可读直到时间结束。
	var remaining_alpha: float = clampf(1.0 - _status_fade_elapsed_seconds / resolved_duration, 0.0, 1.0)
	_status_label.modulate = Color(1.0, 1.0, 1.0, remaining_alpha)


func _on_close_pressed() -> void:
	closed.emit()


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
## 通用信息确认弹窗脚本；购买确认与其他纯信息确认统一使用物品悬浮窗风格和白色边框。
const COMMON_CONFIRMATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/common_confirmation_dialog.gd")
