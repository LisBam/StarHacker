extends PanelContainer

## 局外仓库面板显示全局背包和装备栏，并提供装备、卸下与背包顺序调整操作。
## 面板只调用 GlobalInventory 能力接口，不持有独立物品副本，确保主菜单和战斗 HUD 始终读取同一份数据。

signal closed

## 仓库物品交互控件脚本；默认复用统一摘要、悬停详情、点击和拖拽协议。
const ITEM_ACTION_POPUP_SCRIPT: Script = preload("res://scripts/ui/item_action_popup.gd")
## 全局窗口样式指南；统一仓库主窗口、内部装备分区、查询控件与普通按钮视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
const STORAGE_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/storage_item_control.gd")
## 通用物品卡片视图；仓库、背包与局外装备槽统一读取其固定尺寸。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 存储拖放区域脚本；默认让仓库和背包空白区域都能接收跨容器拖拽。
const STORAGE_DROP_AREA_SCRIPT: Script = preload("res://scripts/ui/storage_drop_area.gd")
## 局外装备拖拽槽脚本；默认负责远近战类型校验以及装备栏双向拖拽数据生成。
const EQUIPMENT_STORAGE_SLOT_SCRIPT: Script = preload("res://scripts/ui/equipment_storage_slot_control.gd")
## 套装筛选控件脚本；装备分类使用统一多选套装筛选，不在仓库内复制查询规则。
const EQUIPMENT_SET_FILTER_CONTROL_SCRIPT: Script = preload("res://scripts/ui/equipment_set_filter_control.gd")
## 物品详情格式化器；用于识别武器、强化石和动态价值，避免仓库面板重复拼接属性文本。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 强化结果弹窗脚本；仓库和局内背包共用同一数值说明格式。
const ENHANCEMENT_RESULT_DIALOG_SCRIPT: Script = preload("res://scripts/ui/enhancement_result_dialog.gd")
## 堆叠出售数量弹窗脚本；默认同时提供滑条和数字输入，确认后由仓库面板调用全局库存服务。
const SELL_QUANTITY_DIALOG_SCRIPT: Script = preload("res://scripts/ui/sell_quantity_dialog.gd")
## 仓库与背包垂直分隔拖条脚本；默认只计算布局占比，不访问库存数据。
const VERTICAL_SPLIT_HANDLE_SCRIPT: Script = preload("res://scripts/ui/vertical_split_handle.gd")
## 通用渐进物品加载器；仓库与背包分别维护任务，首批立即显示后逐帧创建剩余新卡片。
const PROGRESSIVE_ITEM_LOADER_SCRIPT: Script = preload("res://scripts/ui/progressive_item_loader.gd")
## 库存限制配置；仓库与展开背包的卡片数量统一使用单组 10 件上限。
const INVENTORY_LIMITS: Script = preload("res://scripts/data/inventory_limits.gd")
## 操作菜单出售项编号；固定为 1，选择后出售当前仓库或背包整条记录。
const ITEM_ACTION_SELL: int = 1
## 操作菜单使用项编号；固定为 2，只对强化石显示并进入武器选择状态。
const ITEM_ACTION_USE: int = 2
## 操作菜单全部出售项编号；固定为 3，只在数量大于 1 的堆叠物品上显示。
const ITEM_ACTION_SELL_ALL: int = 3
## 操作菜单装备项编号；固定为 4，只对展开背包内的武器显示。
const ITEM_ACTION_EQUIP: int = 4
## 操作菜单装备到远程槽 1 的编号；固定为 5，只对展开背包内的远程武器显示。
const ITEM_ACTION_EQUIP_RANGED_1: int = 5
## 操作菜单装备到远程槽 2 的编号；固定为 6，只对展开背包内的远程武器显示。
const ITEM_ACTION_EQUIP_RANGED_2: int = 6
## 操作菜单使用修复包编号；固定为 7，只对 repair_kit 道具显示并进入武器选择状态。
const ITEM_ACTION_USE_REPAIR_KIT: int = 7
## 仓库区域最小占比；默认 0.10，保证拖条向上时仓库仍保留基础浏览空间。
const STORAGE_SPLIT_MIN_RATIO: float = 0.10
## 仓库区域最大占比；默认 0.90，允许玩家把背包缩小到仅保留必要操作入口。
const STORAGE_SPLIT_MAX_RATIO: float = 0.90
## 仓库菜单可选择的远程装备槽数量；默认 2，与当前双远程装备结构保持一致。
const WAREHOUSE_RANGED_EQUIPMENT_SLOT_COUNT: int = 2
## 数量弹窗空闲操作标识；默认表示当前没有待确认的出售或跨容器移动请求。
const QUANTITY_OPERATION_NONE: String = ""
## 数量弹窗出售操作标识；确认后按选择数量结算星穹并减少来源堆叠。
const QUANTITY_OPERATION_SALE: String = "sale"
## 数量弹窗移动操作标识；确认后把选择数量从仓库或背包原子拆分到另一容器。
const QUANTITY_OPERATION_TRANSFER: String = "transfer"

## 面板最小尺寸；默认 960x620，适配当前 1280x720 主菜单并保留边缘空间。
@export var panel_minimum_size: Vector2 = Vector2(960.0, 620.0)
## 展开背包时仓库占可分配高度的比例；默认 0.38，可通过界面拖条在 0.20 至 0.75 间动态调整。
## 比例范围补充：当前可调范围已扩展为 0.10 至 0.90，并由背包滚动容器保证极限比例下仍可访问内容。
@export_range(0.10, 0.90, 0.01) var warehouse_split_ratio: float = 0.38
## 仓库或背包列表首次同步显示的卡片数量；默认 50，覆盖常规可视内容并减少等待补齐的时间。
@export_range(1, 200, 1) var progressive_initial_item_count: int = 50
## 仓库或背包列表后续每帧创建的卡片数量；默认 8，在加载速度与交互流畅度之间平衡。
@export_range(1, 100, 1) var progressive_item_batch_count: int = 8

## 全局背包服务；默认从自动加载 GlobalInventory 获取，缺失时面板显示不可用提示。
var _global_inventory: Node
## 当前是否展开背包；默认 false 进入纯仓库模式，只显示安全物品并允许出售。
var _backpack_expanded: bool = false
## 新版仓库拖放区域；默认运行时创建，上方始终显示且不参与死亡损失。
var _warehouse_drop_area: PanelContainer
## 新版仓库物品列表；默认运行时从拖放区域取得，用于创建可拖拽物品行。
var _warehouse_item_list: HFlowContainer
## 新版背包拖放区域；默认运行时创建，仅展开模式可见并会随玩家进入战斗。
var _carried_drop_area: PanelContainer
## 新版背包物品列表；默认运行时从拖放区域取得，用于创建快捷转仓与装备按钮。
var _carried_item_list: HFlowContainer
## 新版装备栏容器；默认运行时创建并固定在展开背包区域左侧。
var _loadout_list: VBoxContainer
## 新版背包区域根容器；默认隐藏，切换显示模式后控制下半区整体可见性。
var _backpack_section: VBoxContainer
## 新版背包区域外层滚动容器；默认隐藏，允许背包缩小后通过滚动继续访问装备栏和物品列表。
var _backpack_scroll: ScrollContainer
## 新版仓库滚动容器；默认填充纯仓库模式，展开背包后限制高度给下半区留出空间。
var _warehouse_scroll: ScrollContainer
## 仓库与背包分隔拖条；默认运行时创建，仅展开背包时显示并允许调整上下区域占比。
var _storage_split_handle: Control
## 新版模式切换按钮；默认显示“展开背包”，点击后在纯仓库和仓库背包联合模式间切换。
var _mode_toggle_button: Button
## 一键存入仓库按钮；仅展开背包时显示，把背包内全部物品立即移动到安全仓库。
var _store_all_button: Button
## 新版星穹标签；默认显示局外星穹余额，出售仓库物品后即时刷新。
var _coins_label: Label
## 新版仓库摘要标签；默认显示仓库与背包数量，并明确安全和死亡损失边界。
## 现行摘要补充：常规状态仅显示仓库与背包组数，目标选择状态显示当前操作说明。
var _storage_summary_label: Label
## 展开仓库中的背包标题；显示真实背包组数与容量上限，库存变化后由统一重建入口刷新。
var _backpack_title_label: Label
## 当前主分类；取值为 all、weapons 或 resources，默认全部并同步作用于仓库和背包。
var _storage_primary_category: String = InventoryQuery.PRIMARY_ALL
## 当前子分类；默认 all，进入武器或资源主分类时分别显示对应二级分类。
var _storage_subcategory: String = InventoryQuery.SUBCATEGORY_ALL
## 主分类按钮表；键为 all、weapons 或 resources，值为运行时按钮。
var _storage_primary_buttons: Dictionary = {}
## 子分类按钮表；键为当前分类标识，值为运行时按钮，每次切换主分类时重建。
var _storage_subcategory_buttons: Dictionary = {}
## 子分类按钮容器；默认位于主分类下一行，武器显示近战/远程，资源显示强化石。
var _storage_subcategory_bar: HBoxContainer
## 关键词搜索框；默认空字符串，输入时同时筛选仓库和背包的名称、说明与词条。
var _storage_search_edit: LineEdit
## 排序下拉框；默认获得时间，可切换为物品价值降序。
var _storage_sort_option: OptionButton
## 强化属性筛选下拉框；默认全部属性，只在资源分类显示并按强化石词条键筛选。
var _stone_attribute_option: OptionButton
## 清空强化属性筛选按钮；默认只在资源分类显示，用于一次移除所有多选条件。
var _stone_attribute_clear_button: Button
## 套装多选筛选控件；同时作用于仓库与展开后的背包列表。
var _equipment_set_filter_control: EquipmentSetFilterControl
## 当前强化属性筛选键集合；默认空数组表示不过滤具体属性，多项按并集匹配。
var _stone_attribute_filter: Array[String] = []
## 当前展示排序；默认 acquired_time，可切换 item_value 且不修改真实库存顺序。
var _storage_sort_mode: String = InventoryQuery.SORT_ACQUIRED_TIME
## 标准物品操作弹窗；普通点击物品时显示出售、使用和装备等统一功能按钮。
var _item_action_menu: ItemActionPopup
## 当前操作物品资源；菜单关闭前保持资源实例引用，用于精确出售或启动强化选择。
var _action_item_resource: Resource
## 当前操作物品位置；取值 warehouse 或 backpack，用于出售和消费强化石。
var _action_item_location: String = ""
## 待使用强化石资源；非空时下一次普通点击任意兼容武器会尝试强化该武器。
var _pending_stone_resource: Resource
## 待使用强化石来源；取值 warehouse 或 backpack，强化成功后从对应堆叠扣除一颗。
var _pending_stone_location: String = ""
## 取消使用按钮；默认隐藏，玩家点击强化石“使用”后显示并可退出目标选择。
var _cancel_stone_use_button: Button
## 强化结果弹窗；默认运行时创建一次，每次成功强化时复用。
var _enhancement_result_dialog: EnhancementResultDialog
## 堆叠出售数量弹窗；默认运行时创建一次，重复出售时复用并刷新最大数量和单价。
var _sell_quantity_dialog: SellQuantityDialog
## 数量出售待处理资源；默认 null，打开数量弹窗后保存精确资源实例直到玩家确认或覆盖下一次操作。
var _quantity_sale_item_resource: Resource
## 数量出售待处理位置；取值 warehouse 或 backpack，默认空字符串表示没有有效出售请求。
var _quantity_sale_item_location: String = ""
## 数量弹窗当前操作；取值为空、sale 或 transfer，默认空字符串防止旧弹窗确认执行错误动作。
var _quantity_operation: String = QUANTITY_OPERATION_NONE
## 数量移动待处理资源；默认 null，拖动堆叠到另一容器后保存真实资源实例直到玩家确认。
var _quantity_transfer_item_resource: Resource
## 数量移动来源位置；取值 warehouse 或 backpack，默认空字符串表示没有有效移动来源。
var _quantity_transfer_source_location: String = ""
## 数量移动目标位置；取值 warehouse 或 backpack，默认空字符串表示没有有效移动目标。
var _quantity_transfer_target_location: String = ""
## 数量移动目标下标；取值 -1 或目标容器合法插入位置，默认 -1 表示追加或按堆叠规则合并。
var _quantity_transfer_target_index: int = -1
## 强化选择前主分类；默认资源分类，成功强化后用于返回跳转之前的强化石页面。
var _stone_return_primary_category: String = InventoryQuery.PRIMARY_RESOURCES
## 强化选择前子分类；默认强化石，成功强化后用于恢复原页面筛选。
var _stone_return_subcategory: String = InventoryQuery.SUBCATEGORY_ENHANCEMENT_STONES
## 强化选择前搜索文本；默认空字符串，成功强化后恢复玩家原查询。
var _stone_return_search_text: String = ""
## 强化选择前属性筛选集合；默认空数组表示全部属性，成功强化后恢复原多选状态。
var _stone_return_attribute_filter: Array[String] = []
## 是否存在待恢复的强化石页面；默认 false，点击“使用”跳转武器页后设为 true，取消或成功强化后清除。
var _stone_return_view_pending: bool = false
## 待使用修复包资源；非空时下一次点击任意持有武器会消耗一件修复包并恢复耐久。
var _pending_repair_kit_resource: Resource
## 待使用修复包来源；取值 warehouse 或 backpack，修复成功后从对应堆叠扣除一件。
var _pending_repair_kit_location: String = ""
## 仓库刷新是否已排队；默认 false，同一项跨容器操作触发多个库存信号时只重建一次可见列表。
var _refresh_queued: bool = false
## 隐藏期间仓库数据是否发生变化；默认 false，后台不创建仓库卡片，下一次打开时由公开刷新入口读取最新库存。
var _refresh_pending: bool = false
## 仓库新卡片渐进加载器；刷新查询时会取消旧任务，现有资源卡片仍按实例复用。
var _warehouse_item_loader: ProgressiveItemLoader
## 背包新卡片渐进加载器；与仓库任务独立，展开模式下可同时逐帧补齐上下两个区域。
var _backpack_item_loader: ProgressiveItemLoader


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = panel_minimum_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_warehouse_item_loader = PROGRESSIVE_ITEM_LOADER_SCRIPT.new() as ProgressiveItemLoader
	add_child(_warehouse_item_loader)
	_backpack_item_loader = PROGRESSIVE_ITEM_LOADER_SCRIPT.new() as ProgressiveItemLoader
	add_child(_backpack_item_loader)
	_build_storage_interface()
	if _global_inventory != null:
		if _global_inventory.has_signal("inventory_changed"):
			_global_inventory.connect("inventory_changed", Callable(self, "_on_inventory_state_changed"))
		if _global_inventory.has_signal("equipment_changed"):
			_global_inventory.connect("equipment_changed", Callable(self, "_on_inventory_state_changed"))
		if _global_inventory.has_signal("warehouse_changed"):
			_global_inventory.connect("warehouse_changed", Callable(self, "_on_inventory_state_changed"))
		if _global_inventory.has_signal("coins_changed"):
			_global_inventory.connect("coins_changed", Callable(self, "_on_inventory_state_changed"))
	_rebuild_storage_content()


func refresh() -> void:
	## 公开同步入口；主菜单打开仓库时调用，确保隐藏期间积累的库存变化一次性反映到当前列表。
	_refresh_queued = false
	_refresh_pending = false
	_rebuild_storage_content()


func _on_inventory_state_changed() -> void:
	## 合并全局库存信号；隐藏仓库只标记待刷新，避免背包丢弃时按仓库总量重建不可见卡片。
	if not is_visible_in_tree():
		_refresh_pending = true
		return
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_queued_refresh")


func _flush_queued_refresh() -> void:
	## 执行单次仓库重建；同帧 inventory、equipment、warehouse 与 coins 信号会共享这一次刷新。
	if not _refresh_queued:
		return
	_refresh_queued = false
	if not is_visible_in_tree():
		_refresh_pending = true
		return
	_refresh_pending = false
	_rebuild_storage_content()


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey):
		return
	# 仓库键盘事件；只处理首次按下，避免长按 E 导致背包区域连续展开和收起。
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E:
		_on_mode_toggle_pressed()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _build_storage_interface() -> void:
	# 新版外层边距；默认让联合仓库界面在主菜单遮罩内保持稳定留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	# 新版主内容容器；纵向排列标题栏、仓库、可折叠背包与返回按钮。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	# 新版标题栏；横向显示仓库标题、局外星穹和模式切换按钮。
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	# 新版仓库标题；默认左对齐并占据标题栏剩余空间。
	var title_label: Label = Label.new()
	title_label.text = "仓库"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 25)
	UI_STYLE_GUIDE.apply_title_label(title_label)
	header.add_child(title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_coins_label)
	_mode_toggle_button = Button.new()
	_mode_toggle_button.custom_minimum_size = Vector2(128.0, 38.0)
	_mode_toggle_button.pressed.connect(_on_mode_toggle_pressed)
	header.add_child(_mode_toggle_button)
	_store_all_button = Button.new()
	_store_all_button.text = "一键存入仓库"
	_store_all_button.custom_minimum_size = Vector2(144.0, 38.0)
	_store_all_button.visible = false
	_store_all_button.pressed.connect(_on_store_all_backpack_pressed)
	header.add_child(_store_all_button)
	_cancel_stone_use_button = Button.new()
	_cancel_stone_use_button.custom_minimum_size = Vector2(112.0, 38.0)
	_cancel_stone_use_button.text = "取消使用"
	_cancel_stone_use_button.visible = false
	_cancel_stone_use_button.pressed.connect(_on_cancel_stone_use_pressed)
	_apply_danger_button_style(_cancel_stone_use_button)
	header.add_child(_cancel_stone_use_button)
	# 顶部关闭按钮；固定在标题栏内，展开背包后不会被下方内容推到窗口外。
	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(112.0, 38.0)
	close_button.text = "关闭仓库"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	_storage_summary_label = Label.new()
	_storage_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_storage_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_storage_summary_label)

	# 搜索与排序栏；关键词、排序方式和强化属性过滤统一作用于上下两个库存区域。
	var query_bar: HBoxContainer = HBoxContainer.new()
	query_bar.add_theme_constant_override("separation", 8)
	content.add_child(query_bar)
	_storage_search_edit = LineEdit.new()
	_storage_search_edit.placeholder_text = "搜索武器、强化石或属性关键词"
	_storage_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_storage_search_edit.text_changed.connect(_on_storage_search_changed)
	query_bar.add_child(_storage_search_edit)
	_storage_sort_option = OptionButton.new()
	_storage_sort_option.custom_minimum_size = Vector2(142.0, 36.0)
	_storage_sort_option.add_item("获得时间")
	_storage_sort_option.set_item_metadata(0, InventoryQuery.SORT_ACQUIRED_TIME)
	_storage_sort_option.add_item("物品价值")
	_storage_sort_option.set_item_metadata(1, InventoryQuery.SORT_ITEM_VALUE)
	_storage_sort_option.add_item("耐久")
	_storage_sort_option.set_item_metadata(2, InventoryQuery.SORT_DURABILITY)
	_storage_sort_option.item_selected.connect(_on_storage_sort_selected)
	query_bar.add_child(_storage_sort_option)
	_stone_attribute_option = OptionButton.new()
	_stone_attribute_option.custom_minimum_size = Vector2(142.0, 36.0)
	_stone_attribute_option.add_item("强化筛选（0）")
	_stone_attribute_option.set_item_metadata(0, "")
	# 筛选方向顺序；先列出全部“+”词条，再列出全部“-”词条，方便按方向连续浏览。
	for direction in InventoryQuery.STONE_FILTER_DIRECTIONS:
		_stone_attribute_option.add_separator(InventoryQuery.get_stone_attribute_direction_group_label(direction))
		# 可筛选属性；每个属性分别建立精确方向选项，例如“伤害+”和“伤害-”。
		for stat_name in EnhancementRules.STAT_KEYS:
			_stone_attribute_option.add_item(InventoryQuery.get_stone_attribute_filter_label(stat_name, (1 if EnhancementRules.is_direction_beneficial(stat_name, 1) == (direction > 0) else -1)))
			# 当前属性选项下标；用于绑定筛选键并开启复选状态。
			var attribute_item_index: int = _stone_attribute_option.item_count - 1
			_stone_attribute_option.set_item_metadata(attribute_item_index, InventoryQuery.build_stone_attribute_filter_key(stat_name, (1 if EnhancementRules.is_direction_beneficial(stat_name, 1) == (direction > 0) else -1)))
			_stone_attribute_option.get_popup().set_item_as_checkable(attribute_item_index, true)
	_stone_attribute_option.get_popup().hide_on_checkable_item_selection = false
	_stone_attribute_option.item_selected.connect(_on_stone_attribute_selected)
	query_bar.add_child(_stone_attribute_option)
	_stone_attribute_clear_button = Button.new()
	_stone_attribute_clear_button.text = "清空筛选"
	_stone_attribute_clear_button.custom_minimum_size = Vector2(92.0, 36.0)
	_stone_attribute_clear_button.pressed.connect(_on_clear_stone_attribute_filter_pressed)
	query_bar.add_child(_stone_attribute_clear_button)
	_equipment_set_filter_control = EQUIPMENT_SET_FILTER_CONTROL_SCRIPT.new() as EquipmentSetFilterControl
	_equipment_set_filter_control.filters_changed.connect(_on_equipment_set_filters_changed)
	query_bar.add_child(_equipment_set_filter_control)

	# 一级分类栏；全部入口同时展示武器和资源，二级分类由下一行根据主分类动态生成。
	var primary_filter_bar: HBoxContainer = HBoxContainer.new()
	primary_filter_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	primary_filter_bar.add_theme_constant_override("separation", 8)
	content.add_child(primary_filter_bar)
	_create_storage_category_button(primary_filter_bar, "全部", InventoryQuery.PRIMARY_ALL, true)
	_create_storage_category_button(primary_filter_bar, "武器", InventoryQuery.PRIMARY_WEAPONS, true)
	_create_storage_category_button(primary_filter_bar, "装备", InventoryQuery.PRIMARY_EQUIPMENT, true)
	_create_storage_category_button(primary_filter_bar, "资源", InventoryQuery.PRIMARY_RESOURCES, true)
	_storage_subcategory_bar = HBoxContainer.new()
	_storage_subcategory_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_storage_subcategory_bar.add_theme_constant_override("separation", 6)
	content.add_child(_storage_subcategory_bar)
	_rebuild_storage_subcategory_buttons()

	# 仓库标题；始终位于界面上方并说明安全存储属性。
	var warehouse_title: Label = Label.new()
	warehouse_title.text = "仓库"
	warehouse_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warehouse_title.add_theme_font_size_override("font_size", 17)
	content.add_child(warehouse_title)

	_warehouse_scroll = ScrollContainer.new()
	_warehouse_scroll.name = "WarehouseItemScroll"
	_warehouse_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_warehouse_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_warehouse_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	content.add_child(_warehouse_scroll)
	_warehouse_drop_area = STORAGE_DROP_AREA_SCRIPT.new() as PanelContainer
	_warehouse_drop_area.custom_minimum_size = Vector2(0.0, 220.0)
	_warehouse_drop_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warehouse_drop_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_warehouse_drop_area.call("configure", "warehouse", 2)
	_warehouse_drop_area.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	_warehouse_scroll.add_child(_warehouse_drop_area)
	_warehouse_item_list = _warehouse_drop_area.call("get_content_container") as HFlowContainer
	_storage_split_handle = VERTICAL_SPLIT_HANDLE_SCRIPT.new() as Control
	_storage_split_handle.call("configure", warehouse_split_ratio)
	_storage_split_handle.connect("split_ratio_changed", Callable(self, "_on_storage_split_ratio_changed"))
	content.add_child(_storage_split_handle)

	_backpack_scroll = ScrollContainer.new()
	_backpack_scroll.name = "BackpackSectionScroll"
	_backpack_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backpack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_backpack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	content.add_child(_backpack_scroll)
	_backpack_section = VBoxContainer.new()
	_backpack_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backpack_section.add_theme_constant_override("separation", 6)
	_backpack_scroll.add_child(_backpack_section)
	# 随身区标题；默认强调下半区会进入战斗并参与失败损失结算。
	# 容量标题补充：现行文本改为“背包 当前组数/容量上限”，不再展示失败保留说明。
	_backpack_title_label = Label.new()
	_backpack_title_label.text = "背包 --/--"
	_backpack_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_backpack_title_label.add_theme_font_size_override("font_size", 17)
	_backpack_section.add_child(_backpack_title_label)

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

	# 背包滚动区；默认填充双栏剩余宽度和高度，物品可点击快速转仓或拖拽调整。
	var carried_scroll: ScrollContainer = ScrollContainer.new()
	carried_scroll.name = "CarriedItemScroll"
	carried_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carried_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carried_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	carried_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	carried_columns.add_child(carried_scroll)
	_carried_drop_area = STORAGE_DROP_AREA_SCRIPT.new() as PanelContainer
	_carried_drop_area.custom_minimum_size = Vector2(0.0, 215.0)
	_carried_drop_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_carried_drop_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_carried_drop_area.call("configure", "backpack", 2)
	_carried_drop_area.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	carried_scroll.add_child(_carried_drop_area)
	_carried_item_list = _carried_drop_area.call("get_content_container") as HFlowContainer

	_item_action_menu = ITEM_ACTION_POPUP_SCRIPT.new() as ItemActionPopup
	_item_action_menu.action_pressed.connect(_on_item_action_menu_id_pressed)
	add_child(_item_action_menu)
	_enhancement_result_dialog = ENHANCEMENT_RESULT_DIALOG_SCRIPT.new() as EnhancementResultDialog
	add_child(_enhancement_result_dialog)
	_sell_quantity_dialog = SELL_QUANTITY_DIALOG_SCRIPT.new() as SellQuantityDialog
	_sell_quantity_dialog.connect("quantity_confirmed", Callable(self, "_on_sell_quantity_confirmed"))
	add_child(_sell_quantity_dialog)
	_apply_storage_display_mode()
	_refresh_storage_category_buttons()


func _rebuild_storage_content() -> void:
	# 任意即时重建都会接管同帧已排队任务；延迟回调随后安全跳过，避免业务显式刷新与库存信号各重建一次。
	_refresh_queued = false
	_refresh_pending = false
	_clear_container(_loadout_list)
	if _global_inventory == null:
		_coins_label.text = "星穹：不可用"
		_storage_summary_label.text = "全局物品服务不可用"
		if _backpack_title_label != null:
			_backpack_title_label.text = "背包 --/--"
		return

	# 仓库条目；顺序由全局服务按上次撤离优先和获得时间维护。
	var warehouse_entries: Array = _global_inventory.call("get_warehouse_entries")
	# 背包条目；顺序只影响当前携带布局，进入战斗后由 HUD 读取同一数组。
	var backpack_entries: Array = _global_inventory.call("get_backpack_entries")
	if _backpack_title_label != null:
		_backpack_title_label.text = _get_backpack_capacity_title(backpack_entries)
	_equipment_set_filter_control.configure_entries(warehouse_entries + backpack_entries)
	_coins_label.text = "星穹：%d" % int(_global_inventory.call("get_coins"))
	_storage_summary_label.text = _get_storage_summary_text(warehouse_entries, backpack_entries)
	# 已查询仓库条目；按当前多层分类、关键词、属性和排序生成展示副本。
	var visible_warehouse_entries: Array[Dictionary] = InventoryQuery.filter_and_sort_entries(warehouse_entries, _storage_primary_category, _storage_subcategory, _storage_search_edit.text, _stone_attribute_filter, _storage_sort_mode, _equipment_set_filter_control.get_selected_set_ids())
	# 已查询背包条目；使用同一查询条件保证上下区域对比一致。
	var visible_backpack_entries: Array[Dictionary] = InventoryQuery.filter_and_sort_entries(backpack_entries, _storage_primary_category, _storage_subcategory, _storage_search_edit.text, _stone_attribute_filter, _storage_sort_mode, _equipment_set_filter_control.get_selected_set_ids())
	_sync_storage_entries(visible_warehouse_entries, "warehouse", _warehouse_item_list)
	if _backpack_expanded:
		_sync_storage_entries(visible_backpack_entries, "backpack", _carried_item_list)
		_build_loadout_entries()
	else:
		_sync_storage_entries([], "backpack", _carried_item_list)


func _sync_storage_entries(entries: Array, location: String, target_container: Container) -> void:
	## 按资源实例复用仓库或背包卡片；移动、转移和堆叠变化只更新必要节点，筛选与排序后的显示顺序仍以 entries 为准。
	if target_container == null:
		return
	# 当前区域加载器；仓库与背包使用独立代数，任一区域刷新都不会中断另一区域的有效任务。
	var item_loader: ProgressiveItemLoader = _warehouse_item_loader if location == "warehouse" else _backpack_item_loader
	if item_loader != null:
		item_loader.cancel()
	# 现有卡片表；键为资源实例编号，值为仍可复用的 StorageItemControl，空状态文本和异常节点不进入复用表。
	var existing_controls: Dictionary = {}
	for child in target_container.get_children():
		if child == null or child.is_queued_for_deletion() or not child.has_method("get_item_resource"):
			continue
		# 现有卡片资源；实例身份在容器移动前后保持稳定，用于避免同名或同类物品错误复用。
		var existing_resource: Resource = child.call("get_item_resource") as Resource
		if existing_resource != null:
			existing_controls[existing_resource.get_instance_id()] = child
	if entries.is_empty():
		_clear_container(target_container)
		# 空容器提示；根据所在区域明确物品安全属性和快捷转移方向。
		var empty_state_label: Label = Label.new()
		if location == "warehouse":
			empty_state_label.text = "当前分类没有仓库物品"
		elif _global_inventory != null and int(_global_inventory.call("get_backpack_count")) > 0:
			empty_state_label.text = "当前分类没有背包物品，可用 Shift+点击或拖入上方仓库物品"
		else:
			empty_state_label.text = ""
		empty_state_label.visible = not empty_state_label.text.is_empty()
		empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_state_label.custom_minimum_size = Vector2(0.0, 52.0)
		target_container.add_child(empty_state_label)
		return

		return
	# 本轮目标资源集合；用于立即移除筛选后不可见或已经转出当前容器的旧卡片。
	var desired_resource_ids: Dictionary = {}
	# 待创建条目；只包含当前没有可复用控件的资源，后续交由渐进加载器分批实例化。
	var pending_entries: Array[Dictionary] = []
	# 展示条目索引；取值为列表所有有效下标，用于同步筛选排序后的视觉顺序和真实来源下标。
	for visible_index in range(entries.size()):
		# 展示条目原始值；取值应为 Dictionary，异常数据不会生成可操作控件。
		var raw_entry: Variant = entries[visible_index]
		if raw_entry is Dictionary:
			# 真实来源下标；查询排序不会改变库存数组，拖拽和点击仍使用原始记录索引。
			var source_index: int = int((raw_entry as Dictionary).get("source_index", visible_index))
			# 条目物品资源；缺失资源不会占用显示位置，也不会保留旧卡片。
			var item_resource: Resource = (raw_entry as Dictionary).get("resource") as Resource
			if item_resource == null:
				continue
			desired_resource_ids[item_resource.get_instance_id()] = true
			# 复用控件；同一资源仍位于当前容器时直接更新上下文，否则只为新进入当前容器的物品创建一张卡片。
			var item_control: Button = existing_controls.get(item_resource.get_instance_id()) as Button
			if item_control == null:
				pending_entries.append({"entry": raw_entry, "source_index": source_index, "visible_index": visible_index})
			else:
				_update_storage_entry_control(item_control, raw_entry as Dictionary, location, source_index)
				target_container.move_child(item_control, mini(visible_index, target_container.get_child_count() - 1))
	# 过期子节点；移除未被本轮条目复用的卡片与旧空状态文本，避免隐藏筛选项继续参与布局。
	for child in target_container.get_children():
		if child == null:
			continue
		# 子节点资源；空状态标签或不在目标集合中的旧卡片立即移除，避免渐进加载期间显示过期内容。
		var child_resource: Resource = child.call("get_item_resource") as Resource if child.has_method("get_item_resource") else null
		if child_resource == null or not desired_resource_ids.has(child_resource.get_instance_id()):
			target_container.remove_child(child)
			child.queue_free()
	if item_loader != null and not pending_entries.is_empty():
		item_loader.start(pending_entries, Callable(self, "_create_progressive_storage_entry").bind(location, target_container), progressive_initial_item_count, progressive_item_batch_count)


func _create_progressive_storage_entry(pending_entry: Dictionary, _batch_index: int, location: String, target_container: Container) -> void:
	## 创建一张渐进列表卡片；回调执行前复核容器仍有效，防止关闭或刷新后的旧批次写入当前页面。
	if target_container == null or not is_instance_valid(target_container):
		return
	# 条目数据；包含查询结果、真实来源下标与最终视觉顺序。
	var entry: Dictionary = pending_entry.get("entry", {}) as Dictionary
	# 新物品卡片；沿用仓库原创建协议并只连接一次信号。
	var item_control: Button = _create_storage_entry_control(entry, location, int(pending_entry.get("source_index", -1)))
	if item_control == null:
		return
	target_container.add_child(item_control)
	target_container.move_child(item_control, mini(int(pending_entry.get("visible_index", target_container.get_child_count() - 1)), target_container.get_child_count() - 1))


func _create_storage_entry_control(entry: Dictionary, location: String, entry_index: int) -> Button:
	## 创建首次进入当前可见容器的物品卡片并连接一次稳定信号；后续刷新由上下文更新接口复用该节点。
	# 条目物品资源；取值应为 Resource，缺失时忽略该行避免产生无效转移请求。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return null

	# 物品数量；武器固定为 1，强化石按 1 到 99 显示在方形资源格中。
	# 现行限制补充：武器与装备固定为 1，可堆叠资源卡片按 1 到 10 显示。
	# 通用模板补充：强化石数量规则保持不变，但显示区域现与所有物品统一为 160×72 卡片。
	var quantity: int = clampi(int(entry.get("quantity", 1)), 1, INVENTORY_LIMITS.MAX_STACK_QUANTITY)
	# 上次撤离前缀；最近一次成功撤离携带的物品手动转入仓库后继续显示该标记。
	var extraction_prefix: String = "[上次撤离] " if bool(entry.get("is_last_extraction", false)) else ""
	# 物品控件；展开模式允许点击跨容器转移，纯仓库模式只提供浏览、拖拽和出售。
	var item_control: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
	item_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_control.call("configure", item_resource, location, entry_index, _backpack_expanded, extraction_prefix, quantity)
	item_control.call("set_stone_value_on_fourth_line", true)
	item_control.call("set_weapon_target_selection_state", _is_weapon_target_selection_active(), _is_pending_item_usable_on_weapon(item_resource))
	item_control.connect("quick_action_requested", Callable(self, "_on_quick_action_requested").bind(location))
	item_control.connect("item_action_requested", Callable(self, "_on_item_action_requested").bind(location))
	item_control.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	item_control.connect("enhancement_drop_requested", Callable(self, "_on_enhancement_drop_requested"))
	item_control.connect("repair_kit_drop_requested", Callable(self, "_on_repair_kit_drop_requested"))
	return item_control


func _update_storage_entry_control(item_control: Button, entry: Dictionary, location: String, entry_index: int) -> void:
	## 更新复用卡片的容器、真实下标、数量与目标选择状态；未变化的资源详情和视觉节点保持原样。
	if item_control == null:
		return
	# 条目物品资源；与现有卡片实例身份一致，作为完整配置回退和目标资格判断的数据来源。
	var item_resource: Resource = entry.get("resource") as Resource
	if item_resource == null:
		return
	# 物品数量；堆叠资源限制为 1 至 99，数量变化时卡片组件会自动执行必要的完整内容刷新。
	# 现行限制补充：正式堆叠范围为 1 至 10，旧 99 件记录已在读档阶段拆分。
	var quantity: int = clampi(int(entry.get("quantity", 1)), 1, INVENTORY_LIMITS.MAX_STACK_QUANTITY)
	# 上次撤离前缀；状态变化时由卡片组件刷新文字，普通移动只更新来源下标。
	var extraction_prefix: String = "[上次撤离] " if bool(entry.get("is_last_extraction", false)) else ""
	item_control.call("update_storage_context", item_resource, location, entry_index, _backpack_expanded, extraction_prefix, quantity)
	item_control.call("set_stone_value_on_fourth_line", true)
	item_control.call("set_weapon_target_selection_state", _is_weapon_target_selection_active(), _is_pending_item_usable_on_weapon(item_resource))


func _build_loadout_entries() -> void:
	# 装备栏标题；默认说明槽内物品随角色使用但不属于仓库。
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
	# 近战装备资源；空值显示可接收近战武器的槽位，有资源时可拖往仓库或背包。
	var melee_resource: Resource = _global_inventory.call("get_melee_equipment_resource") as Resource
	_loadout_list.add_child(_create_storage_equipment_slot("近战", "melee", "melee", melee_resource))
	# 武器与防具分组间距；与共享背包读取同一全局样式值，保证两处装备栏层级一致。
	var weapon_armor_spacer: Control = Control.new()
	weapon_armor_spacer.custom_minimum_size = Vector2(0.0, UI_STYLE_GUIDE.EQUIPMENT_GROUP_SPACER_HEIGHT)
	_loadout_list.add_child(weapon_armor_spacer)
	# 四部位装备槽；复用武器装备槽控件、排版、耐久条和悬浮窗。
	var armor_slot_labels: Dictionary = {"head": "头部", "body": "躯干", "legs": "腿部", "feet": "脚部"}
	for armor_slot in ["head", "body", "legs", "feet"]:
		var armor_resource: Resource = _global_inventory.call("get_armor_equipment_resource", armor_slot) as Resource
		_loadout_list.add_child(_create_storage_equipment_slot(str(armor_slot_labels[armor_slot]), "armor_" + armor_slot, armor_slot, armor_resource))


func _create_storage_equipment_slot(slot_label: String, location: String, weapon_type: String, item_resource: Resource) -> Control:
	# 装备槽控件；取值为独立拖拽组件，既可把装备拖出到存储区，也可接收仓库或背包武器。
	var slot_control: Control = EQUIPMENT_STORAGE_SLOT_SCRIPT.new() as Control
	# 装备详情文本；空槽保持空字符串并由槽控件显示类型提示，有装备时复用完整武器悬停详情。
	var detail_tooltip: String = _get_item_detail_tooltip(item_resource)
	slot_control.call("configure", slot_label, location, weapon_type, item_resource, detail_tooltip)
	slot_control.connect("item_drop_requested", Callable(self, "_on_item_drop_requested"))
	slot_control.connect("item_selected", Callable(self, "_on_enhancement_weapon_selected"))
	slot_control.connect("item_selected", Callable(self, "_on_repair_kit_weapon_selected"))
	slot_control.connect("quick_unequip_requested", Callable(self, "_on_quick_unequip_requested").bind(location))
	slot_control.connect("enhancement_drop_requested", Callable(self, "_on_enhancement_drop_requested"))
	slot_control.connect("repair_kit_drop_requested", Callable(self, "_on_repair_kit_drop_requested"))
	slot_control.call("set_weapon_target_selection_state", _is_weapon_target_selection_active(), _is_pending_item_usable_on_weapon(item_resource))
	slot_control.custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
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


func _is_pending_item_usable_on_weapon(weapon_resource: Resource) -> bool:
	if weapon_resource == null or (str(weapon_resource.get("weapon_type")) not in ["ranged", "melee", "hybrid"] and str(weapon_resource.get("item_kind")) != "equipment"):
		return false
	if _pending_repair_kit_resource != null:
		# 当前耐久；修复包只应高亮仍有耐久缺口的武器，满耐久武器不提供无效选择。
		var current_durability: float = maxf(float(weapon_resource.get("current_durability")), 0.0)
		# 最大耐久；至少为 1，兼容旧资源字段缺失时的安全读取。
		var maximum_durability: float = float(weapon_resource.call("get_maximum_durability")) if weapon_resource.has_method("get_maximum_durability") else maxf(float(weapon_resource.get("max_durability")), 1.0)
		return current_durability < maximum_durability
	return _pending_stone_resource != null


func _is_weapon_target_selection_active() -> bool:
	return _pending_stone_resource != null or _pending_repair_kit_resource != null


func _create_storage_category_button(target_bar: HBoxContainer, button_text: String, category_name: String, is_primary: bool) -> void:
	# 分类按钮；一级与二级共用创建逻辑，但分别写入不同按钮表和回调。
	var category_button: Button = Button.new()
	category_button.text = button_text
	category_button.toggle_mode = true
	category_button.custom_minimum_size = Vector2(104.0, 30.0)
	if is_primary:
		category_button.pressed.connect(Callable(self, "_on_storage_primary_category_pressed").bind(category_name))
		_storage_primary_buttons[category_name] = category_button
	else:
		category_button.pressed.connect(Callable(self, "_on_storage_subcategory_pressed").bind(category_name))
		_storage_subcategory_buttons[category_name] = category_button
	target_bar.add_child(category_button)


func _rebuild_storage_subcategory_buttons() -> void:
	_clear_container(_storage_subcategory_bar)
	_storage_subcategory_buttons.clear()
	_create_storage_category_button(_storage_subcategory_bar, "全部", InventoryQuery.SUBCATEGORY_ALL, false)
	if _storage_primary_category == InventoryQuery.PRIMARY_WEAPONS:
		_create_storage_category_button(_storage_subcategory_bar, "近战", InventoryQuery.SUBCATEGORY_MELEE, false)
		_create_storage_category_button(_storage_subcategory_bar, "远程", InventoryQuery.SUBCATEGORY_RANGED, false)
	elif _storage_primary_category == InventoryQuery.PRIMARY_EQUIPMENT:
		_create_storage_category_button(_storage_subcategory_bar, "头部", "head", false)
		_create_storage_category_button(_storage_subcategory_bar, "躯干", "body", false)
		_create_storage_category_button(_storage_subcategory_bar, "腿部", "legs", false)
		_create_storage_category_button(_storage_subcategory_bar, "脚部", "feet", false)
	elif _storage_primary_category == InventoryQuery.PRIMARY_RESOURCES:
		_create_storage_category_button(_storage_subcategory_bar, "强化石", InventoryQuery.SUBCATEGORY_ENHANCEMENT_STONES, false)
		_create_storage_category_button(_storage_subcategory_bar, "道具", InventoryQuery.SUBCATEGORY_ITEMS, false)
	_refresh_storage_category_buttons()


func _on_storage_primary_category_pressed(category_name: String) -> void:
	_storage_primary_category = category_name
	_storage_subcategory = InventoryQuery.SUBCATEGORY_ALL
	_clear_stone_attribute_filter()
	_equipment_set_filter_control.clear_filters(false)
	_rebuild_storage_subcategory_buttons()
	_refresh_storage_category_buttons()
	_rebuild_storage_content()


func _on_storage_subcategory_pressed(category_name: String) -> void:
	_storage_subcategory = category_name
	_refresh_storage_category_buttons()
	_rebuild_storage_content()


func _refresh_storage_category_buttons() -> void:
	for category_name in _storage_primary_buttons.keys():
		# 一级分类按钮；当前主分类保持按下状态。
		var primary_button: Button = _storage_primary_buttons.get(category_name) as Button
		if primary_button != null:
			primary_button.set_pressed_no_signal(str(category_name) == _storage_primary_category)
	for category_name in _storage_subcategory_buttons.keys():
		# 二级分类按钮；当前子分类保持按下状态。
		var subcategory_button: Button = _storage_subcategory_buttons.get(category_name) as Button
		if subcategory_button != null:
			subcategory_button.set_pressed_no_signal(str(category_name) == _storage_subcategory)
	_stone_attribute_option.visible = _storage_primary_category == InventoryQuery.PRIMARY_RESOURCES
	_stone_attribute_clear_button.visible = _storage_primary_category == InventoryQuery.PRIMARY_RESOURCES
	_equipment_set_filter_control.visible = _storage_primary_category == InventoryQuery.PRIMARY_EQUIPMENT
	_stone_attribute_clear_button.disabled = _stone_attribute_filter.is_empty()


func _on_equipment_set_filters_changed(_selected_set_ids: Array[String]) -> void:
	## 套装筛选变化后同时刷新仓库与背包两区，不修改任一容器真实顺序。
	_rebuild_storage_content()


func _on_quick_unequip_requested(equipment_location: String) -> void:
	## Shift+点击装备栏时直接卸到背包；仓库是否展开不影响物品所有权目标。
	if _global_inventory != null and not equipment_location.is_empty():
		_global_inventory.call("transfer_equipment_to_storage", equipment_location, "backpack")


func _on_storage_search_changed(_new_text: String) -> void:
	_rebuild_storage_content()


func _on_storage_sort_selected(item_index: int) -> void:
	# 排序元数据；取值为 acquired_time 或 item_value，异常值回退获得时间。
	var selected_sort_mode: String = str(_storage_sort_option.get_item_metadata(item_index))
	_storage_sort_mode = selected_sort_mode if selected_sort_mode in [InventoryQuery.SORT_ACQUIRED_TIME, InventoryQuery.SORT_ITEM_VALUE, InventoryQuery.SORT_DURABILITY] else InventoryQuery.SORT_ACQUIRED_TIME
	_rebuild_storage_content()


func _on_stone_attribute_selected(item_index: int) -> void:
	if item_index <= 0:
		_stone_attribute_option.select(0)
		return
	# 当前筛选键；分隔项和摘要项不会进入多选集合。
	var filter_key: String = str(_stone_attribute_option.get_item_metadata(item_index))
	if filter_key.is_empty():
		return
	# 新勾选状态；同一条件再次选择会从并集筛选中移除。
	var should_select: bool = filter_key not in _stone_attribute_filter
	_stone_attribute_option.get_popup().set_item_checked(item_index, should_select)
	if should_select:
		_stone_attribute_filter.append(filter_key)
	else:
		_stone_attribute_filter.erase(filter_key)
	_refresh_stone_attribute_filter_display()
	_rebuild_storage_content()


func _on_clear_stone_attribute_filter_pressed() -> void:
	_clear_stone_attribute_filter()
	_rebuild_storage_content()


func _clear_stone_attribute_filter() -> void:
	_stone_attribute_filter.clear()
	for item_index in range(1, _stone_attribute_option.item_count):
		if not str(_stone_attribute_option.get_item_metadata(item_index)).is_empty():
			_stone_attribute_option.get_popup().set_item_checked(item_index, false)
	_refresh_stone_attribute_filter_display()


func _refresh_stone_attribute_filter_display() -> void:
	_stone_attribute_option.set_item_text(0, "强化筛选（%d）" % _stone_attribute_filter.size())
	_stone_attribute_option.select(0)
	# 勾选状态同步；切回摘要项后重新按当前筛选集合绘制复选框，确保玩家能看到已选择的属性方向。
	for item_index in range(1, _stone_attribute_option.item_count):
		# 当前筛选键；分隔项没有筛选元数据，应保持不可勾选状态。
		var filter_key: String = str(_stone_attribute_option.get_item_metadata(item_index))
		if not filter_key.is_empty():
			_stone_attribute_option.get_popup().set_item_checked(item_index, filter_key in _stone_attribute_filter)
	if _stone_attribute_clear_button != null:
		_stone_attribute_clear_button.disabled = _stone_attribute_filter.is_empty()


func _get_storage_summary_text(warehouse_entries: Array, backpack_entries: Array) -> String:
	if _pending_repair_kit_resource != null:
		return "正在使用 %s：请选择仓库、背包或装备栏中的一把武器" % str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", _pending_repair_kit_resource))
	if _pending_stone_resource != null:
		return "正在使用 %s：请选择仓库、背包或装备栏中的一把兼容武器" % str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", _pending_stone_resource))
	return "仓库 %d 组 · 背包 %d 组" % [warehouse_entries.size(), backpack_entries.size()]


func _get_backpack_capacity_title(backpack_entries: Array) -> String:
	## 返回仓库展开区域的背包容量标题；真实库存接口优先，传入条目仅作为旧服务兼容回退。
	if _global_inventory == null:
		return "背包 --/--"
	# 背包当前组数；读取未筛选的真实库存数量，分类、搜索与排序不会改变显示。
	var backpack_group_count: int = int(_global_inventory.call("get_backpack_count")) if _global_inventory.has_method("get_backpack_count") else backpack_entries.size()
	# 背包容量上限；优先读取库存服务公开接口，旧服务回退项目统一 50 组配置。
	var backpack_maximum_groups: int = int(_global_inventory.call("get_backpack_max_groups")) if _global_inventory.has_method("get_backpack_max_groups") else INVENTORY_LIMITS.BACKPACK_MAX_GROUPS
	return "背包 %d/%d" % [backpack_group_count, backpack_maximum_groups]


func _apply_storage_display_mode() -> void:
	_backpack_scroll.visible = _backpack_expanded
	if _storage_split_handle != null:
		_storage_split_handle.visible = _backpack_expanded
	_mode_toggle_button.text = "收起背包 E" if _backpack_expanded else "展开背包 E"
	if _store_all_button != null:
		_store_all_button.visible = _backpack_expanded
		_store_all_button.disabled = _global_inventory == null or int(_global_inventory.call("get_backpack_count")) <= 0
	_warehouse_scroll.custom_minimum_size = Vector2(0.0, 80.0 if _backpack_expanded else 386.0)
	if _carried_drop_area != null:
		_carried_drop_area.custom_minimum_size = Vector2(0.0, 100.0 if _backpack_expanded else 215.0)
	_warehouse_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_warehouse_scroll.size_flags_stretch_ratio = warehouse_split_ratio if _backpack_expanded else 1.0
	_backpack_scroll.size_flags_stretch_ratio = 1.0 - warehouse_split_ratio
	if _cancel_stone_use_button != null:
		_cancel_stone_use_button.visible = _pending_stone_resource != null or _pending_repair_kit_resource != null


func _on_mode_toggle_pressed() -> void:
	_backpack_expanded = not _backpack_expanded
	_apply_storage_display_mode()
	_rebuild_storage_content()


func _on_store_all_backpack_pressed() -> void:
	## 一键存入当前背包全部物品；装备栏不属于背包，不会被此操作卸下或移动。
	if _global_inventory == null or not _global_inventory.has_method("transfer_all_backpack_to_warehouse"):
		return
	_global_inventory.call("transfer_all_backpack_to_warehouse")
	_rebuild_storage_content()


func _on_quick_action_requested(item_resource: Resource, source_location: String) -> void:
	if not _backpack_expanded or _global_inventory == null:
		return
	if source_location == "warehouse":
		_global_inventory.call("transfer_warehouse_to_backpack", item_resource)
	elif source_location == "backpack":
		_global_inventory.call("transfer_backpack_to_warehouse", item_resource)


func _on_item_action_requested(item_resource: Resource, source_location: String) -> void:
	if item_resource == null or _global_inventory == null:
		return
	if _pending_repair_kit_resource != null and (str(item_resource.get("weapon_type")) in ["melee", "ranged"] or str(item_resource.get("item_kind")) == "equipment"):
		if not _is_pending_item_usable_on_weapon(item_resource):
			return
		_on_repair_kit_weapon_selected(item_resource)
		return
	if _pending_stone_resource != null and (str(item_resource.get("weapon_type")) in ["melee", "ranged"] or str(item_resource.get("item_kind")) == "equipment"):
		_on_enhancement_weapon_selected(item_resource)
		return

	_action_item_resource = item_resource
	_action_item_location = source_location
	_item_action_menu.clear_actions()
	# 出售总价；强化石按整组数量计算，强化武器按动态售价计算。
	var total_value: int = int(_global_inventory.call("get_storage_resource_value", item_resource, source_location))
	# 当前库存数量；数量大于 1 时提供指定数量出售和全部出售两个独立入口。
	var stored_quantity: int = int(_global_inventory.call("get_storage_resource_quantity", item_resource, source_location))
	if stored_quantity > 1:
		_item_action_menu.add_action("出售指定数量…", ITEM_ACTION_SELL, total_value <= 0, true)
		_item_action_menu.add_action("全部出售（+%d）" % total_value, ITEM_ACTION_SELL_ALL, total_value <= 0, true)
	else:
		_item_action_menu.add_action("出售（+%d）" % total_value, ITEM_ACTION_SELL, total_value <= 0, true)
	if str(item_resource.get("item_kind")) == "repair_kit":
		_item_action_menu.add_action("使用", ITEM_ACTION_USE_REPAIR_KIT)
	elif source_location == "backpack" and str(item_resource.get("item_kind")) == "equipment":
		_item_action_menu.add_action("装备", ITEM_ACTION_EQUIP)
	elif source_location == "backpack" and str(item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"]:
		if str(item_resource.get("weapon_type")) in ["ranged", "hybrid"]:
			_item_action_menu.add_action("装备1", ITEM_ACTION_EQUIP_RANGED_1)
			_item_action_menu.add_action("装备2", ITEM_ACTION_EQUIP_RANGED_2)
		if str(item_resource.get("weapon_type")) in ["melee", "hybrid"]:
			_item_action_menu.add_action("装备", ITEM_ACTION_EQUIP)
	_item_action_menu.present_at(get_viewport().get_mouse_position())


func _on_item_action_menu_id_pressed(action_id: int) -> void:
	if _global_inventory == null or _action_item_resource == null:
		return
	if action_id == ITEM_ACTION_SELL:
		# 当前数量；堆叠物品进入数量弹窗，单件物品保持一次点击直接出售。
		var stored_quantity: int = int(_global_inventory.call("get_storage_resource_quantity", _action_item_resource, _action_item_location))
		if stored_quantity > 1:
			_open_sell_quantity_dialog(_action_item_resource, _action_item_location, stored_quantity)
		else:
			_global_inventory.call("sell_storage_resource", _action_item_resource, _action_item_location)
	elif action_id == ITEM_ACTION_SELL_ALL:
		_global_inventory.call("sell_storage_resource", _action_item_resource, _action_item_location)
	elif action_id == ITEM_ACTION_USE and str(_action_item_resource.get("item_kind")) == "enhancement_stone":
		_pending_stone_resource = _action_item_resource
		_pending_stone_location = _action_item_location
		_capture_stone_return_view()
		_backpack_expanded = true
		# 强化目标选择页；自动切回全部武器并清空查询条件，确保仓库、背包和装备栏目标立即可见。
		_storage_primary_category = InventoryQuery.PRIMARY_ALL
		_storage_subcategory = InventoryQuery.SUBCATEGORY_ALL
		_clear_stone_attribute_filter()
		_storage_search_edit.clear()
		_rebuild_storage_subcategory_buttons()
		_refresh_storage_category_buttons()
		_apply_storage_display_mode()
		_rebuild_storage_content()
	elif action_id == ITEM_ACTION_USE_REPAIR_KIT and str(_action_item_resource.get("item_kind")) == "repair_kit":
		_pending_repair_kit_resource = _action_item_resource
		_pending_repair_kit_location = _action_item_location
		_backpack_expanded = true
		# 修复目标选择页；武器可位于仓库、背包或局外装备栏，因此显示完整武器浏览视图。
		_storage_primary_category = InventoryQuery.PRIMARY_ALL
		_storage_subcategory = InventoryQuery.SUBCATEGORY_ALL
		_clear_stone_attribute_filter()
		_storage_search_edit.clear()
		_rebuild_storage_subcategory_buttons()
		_refresh_storage_category_buttons()
		_apply_storage_display_mode()
		_rebuild_storage_content()
	elif action_id == ITEM_ACTION_EQUIP and _action_item_location == "backpack":
		_equip_backpack_weapon(_action_item_resource)
	elif action_id == ITEM_ACTION_EQUIP_RANGED_1 and _action_item_location == "backpack":
		_equip_backpack_weapon(_action_item_resource, 0)
	elif action_id == ITEM_ACTION_EQUIP_RANGED_2 and _action_item_location == "backpack":
		_equip_backpack_weapon(_action_item_resource, 1)
	_action_item_resource = null
	_action_item_location = ""


func _on_enhancement_weapon_selected(weapon_resource: Resource) -> void:
	if _pending_stone_resource == null or weapon_resource == null or _global_inventory == null:
		return
	# 强化结果；成功时扣除一颗材料并展示完整属性变化，失败时保留选择状态。
	var enhancement_result: Dictionary = _global_inventory.call("use_enhancement_stone_with_result", _pending_stone_resource, _pending_stone_location, weapon_resource) as Dictionary
	if bool(enhancement_result.get("success", false)):
		_pending_stone_resource = null
		_pending_stone_location = ""
		_restore_stone_return_view()
		_present_enhancement_result(enhancement_result)
	_apply_storage_display_mode()
	_rebuild_storage_content()


func _on_enhancement_drop_requested(stone_resource: Resource, source_location: String, weapon_resource: Resource) -> void:
	if _global_inventory == null or stone_resource == null or weapon_resource == null:
		return
	# 拖动强化结果；不进入点击选择状态，成功后直接弹出本次数值明细。
	var enhancement_result: Dictionary = _global_inventory.call("use_enhancement_stone_with_result", stone_resource, source_location, weapon_resource) as Dictionary
	if bool(enhancement_result.get("success", false)):
		_present_enhancement_result(enhancement_result)
		_rebuild_storage_content()


func _on_repair_kit_weapon_selected(weapon_resource: Resource) -> void:
	if _pending_repair_kit_resource == null or weapon_resource == null or _global_inventory == null:
		return
	# 修复结果；满耐久武器不会消耗道具，成功后清理选择状态并反馈实际恢复耐久。
	var repair_result: Dictionary = _global_inventory.call("use_repair_kit_with_result", _pending_repair_kit_resource, _pending_repair_kit_location, weapon_resource) as Dictionary
	if bool(repair_result.get("success", false)):
		_pending_repair_kit_resource = null
		_pending_repair_kit_location = ""
		_storage_summary_label.text = "修复完成，恢复 %.0f 点耐久" % float(repair_result.get("durability_restored", 0.0))
	_apply_storage_display_mode()
	_rebuild_storage_content()


func _on_repair_kit_drop_requested(repair_kit_resource: Resource, source_location: String, weapon_resource: Resource) -> void:
	if _global_inventory == null or repair_kit_resource == null or weapon_resource == null:
		return
	# 拖动修复结果；成功后直接刷新库存和武器耐久，失败时不会消费修复包。
	var repair_result: Dictionary = _global_inventory.call("use_repair_kit_with_result", repair_kit_resource, source_location, weapon_resource) as Dictionary
	if bool(repair_result.get("success", false)):
		_storage_summary_label.text = "修复完成，恢复 %.0f 点耐久" % float(repair_result.get("durability_restored", 0.0))
		_rebuild_storage_content()


func _on_cancel_stone_use_pressed() -> void:
	_pending_stone_resource = null
	_pending_stone_location = ""
	_pending_repair_kit_resource = null
	_pending_repair_kit_location = ""
	if _stone_return_view_pending:
		_restore_stone_return_view()
	_apply_storage_display_mode()
	_rebuild_storage_content()


func _present_enhancement_result(enhancement_result: Dictionary) -> void:
	if _enhancement_result_dialog != null:
		_enhancement_result_dialog.present_result(enhancement_result)


func _open_sell_quantity_dialog(item_resource: Resource, source_location: String, maximum_quantity: int) -> void:
	if _sell_quantity_dialog == null or item_resource == null:
		return
	_reset_quantity_operation()
	_quantity_operation = QUANTITY_OPERATION_SALE
	_quantity_sale_item_resource = item_resource
	_quantity_sale_item_location = source_location
	# 单件售价；整组总价除以当前数量，统一复用 GlobalInventory 的动态售价结果。
	var total_value: int = int(_global_inventory.call("get_storage_resource_value", item_resource, source_location))
	# 有效最大数量；至少为 1，防止旧操作菜单确认时物品已经发生变化。
	var resolved_maximum_quantity: int = maxi(maximum_quantity, 1)
	# 单件售价；整数总价由单价乘数量形成，因此整除不会丢失有效星穹。
	var unit_value: int = total_value / resolved_maximum_quantity
	# 物品名称；统一由详情格式化器解析显示名，避免武器旧资源名称为空。
	var item_display_name: String = str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", item_resource))
	_sell_quantity_dialog.present(item_display_name, resolved_maximum_quantity, unit_value)


func _on_sell_quantity_confirmed(quantity: int) -> void:
	if _global_inventory == null:
		return
	if _quantity_operation == QUANTITY_OPERATION_TRANSFER:
		if _quantity_transfer_item_resource != null and not _quantity_transfer_source_location.is_empty() and not _quantity_transfer_target_location.is_empty():
			_global_inventory.call("transfer_storage_resource_quantity", _quantity_transfer_item_resource, _quantity_transfer_source_location, _quantity_transfer_target_location, quantity, _quantity_transfer_target_index)
		_reset_quantity_operation()
		return
	if _quantity_operation == QUANTITY_OPERATION_SALE and _quantity_sale_item_resource != null and not _quantity_sale_item_location.is_empty():
		_global_inventory.call("sell_storage_resource_quantity", _quantity_sale_item_resource, _quantity_sale_item_location, quantity)
	_reset_quantity_operation()


func _open_transfer_quantity_dialog(item_resource: Resource, source_location: String, target_location: String, target_index: int, maximum_quantity: int) -> void:
	if _sell_quantity_dialog == null or item_resource == null:
		return
	_reset_quantity_operation()
	_quantity_operation = QUANTITY_OPERATION_TRANSFER
	_quantity_transfer_item_resource = item_resource
	_quantity_transfer_source_location = source_location
	_quantity_transfer_target_location = target_location
	_quantity_transfer_target_index = target_index
	# 物品名称；统一复用详情格式化器，确保修复包和不同品质强化石名称与卡片一致。
	var item_display_name: String = str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", item_resource))
	# 来源中文名；只对仓库和背包开放，便于弹窗明确显示移动方向。
	var source_display_name: String = "仓库" if source_location == "warehouse" else "背包"
	# 目标中文名；与来源使用同一术语，避免玩家误解为出售或装备操作。
	var target_display_name: String = "仓库" if target_location == "warehouse" else "背包"
	_sell_quantity_dialog.present_transfer(item_display_name, maxi(maximum_quantity, 1), source_display_name, target_display_name)


func _reset_quantity_operation() -> void:
	_quantity_operation = QUANTITY_OPERATION_NONE
	_quantity_sale_item_resource = null
	_quantity_sale_item_location = ""
	_quantity_transfer_item_resource = null
	_quantity_transfer_source_location = ""
	_quantity_transfer_target_location = ""
	_quantity_transfer_target_index = -1


func _equip_backpack_weapon(weapon_resource: Resource, target_ranged_slot: int = -1) -> void:
	if _global_inventory == null or weapon_resource == null:
		return
	# 武器类型；远程武器替换当前手持槽，近战武器替换唯一近战槽，与战斗背包点击装备逻辑一致。
	# 远程槽选择补充：仓库背包菜单现在通过“装备1”“装备2”明确指定远程目标槽，不再隐式使用当前槽。
	var weapon_type: String = str(weapon_resource.get("weapon_type"))
	if str(weapon_resource.get("item_kind")) == "equipment":
		_global_inventory.call("transfer_storage_to_equipment", weapon_resource, "backpack", "armor_" + str(weapon_resource.get("equipment_slot")))
		return
	# 装备目标位置；远程目标由当前选中槽组成，近战目标使用稳定 melee 标识。
	# 显式目标补充：远程分支使用菜单传入的槽位下标生成目标位置。
	var target_location: String = "melee"
	if weapon_type in ["ranged", "hybrid"] and target_ranged_slot >= 0:
		# 当前远程槽；取值来自全局装备服务，默认 0 用于缺少接口时的安全兜底。
		# 菜单目标补充：当前实现不再读取当前远程槽，而是校验用户选择的 0/1 下标。
		if target_ranged_slot < 0 or target_ranged_slot >= WAREHOUSE_RANGED_EQUIPMENT_SLOT_COUNT:
			return
		target_location = "ranged_%d" % target_ranged_slot
	elif weapon_type not in ["melee", "hybrid"]:
		return
	_global_inventory.call("transfer_storage_to_equipment", weapon_resource, "backpack", target_location)


func _on_storage_split_ratio_changed(ratio: float) -> void:
	warehouse_split_ratio = clampf(ratio, STORAGE_SPLIT_MIN_RATIO, STORAGE_SPLIT_MAX_RATIO)
	_apply_storage_display_mode()


func _capture_stone_return_view() -> void:
	_stone_return_view_pending = true
	_stone_return_primary_category = _storage_primary_category
	_stone_return_subcategory = _storage_subcategory
	_stone_return_search_text = _storage_search_edit.text
	_stone_return_attribute_filter = _stone_attribute_filter.duplicate()


func _restore_stone_return_view() -> void:
	_stone_return_view_pending = false
	_storage_primary_category = _stone_return_primary_category
	_storage_subcategory = _stone_return_subcategory
	_stone_attribute_filter = _stone_return_attribute_filter.duplicate()
	_storage_search_edit.text = _stone_return_search_text
	# 恢复全部多选勾选；返回强化石页面后保持玩家原有并集筛选组合。
	for option_index in range(1, _stone_attribute_option.item_count):
		# 当前选项筛选键；用于判断它是否属于保存的返回视图集合。
		var filter_key: String = str(_stone_attribute_option.get_item_metadata(option_index))
		if not filter_key.is_empty():
			_stone_attribute_option.get_popup().set_item_checked(option_index, filter_key in _stone_attribute_filter)
	_refresh_stone_attribute_filter_display()
	_rebuild_storage_subcategory_buttons()
	_refresh_storage_category_buttons()


func _apply_danger_button_style(button: Button) -> void:
	if button == null:
		return
	# 普通危险按钮样式；深红背景和亮红边框用于明确取消当前强化操作。
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.42, 0.08, 0.10, 0.96)
	normal_style.border_color = Color(0.95, 0.24, 0.28, 1.0)
	normal_style.set_border_width_all(2)
	# 悬停危险按钮样式；提高亮度但保持红色语义。
	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.58, 0.10, 0.13, 1.0)
	# 按下危险按钮样式；使用更深红色提供明确点击反馈。
	var pressed_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.30, 0.04, 0.06, 1.0)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.92, 1.0))


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
		# 跨容器堆叠数量；数量大于 1 时先让玩家选择拆分数量，单件资源和武器保持直接移动。
		var warehouse_stack_quantity: int = int(_global_inventory.call("get_storage_resource_quantity", item_resource, source_location))
		if _is_stackable_storage_resource(item_resource) and warehouse_stack_quantity > 1:
			_open_transfer_quantity_dialog(item_resource, source_location, target_location, target_index, warehouse_stack_quantity)
		else:
			_global_inventory.call("transfer_warehouse_to_backpack", item_resource, target_index)
	elif source_location == "backpack" and target_location == "warehouse":
		# 跨容器堆叠数量；背包转仓库与仓库转背包使用同一选择和原子拆分流程。
		var backpack_stack_quantity: int = int(_global_inventory.call("get_storage_resource_quantity", item_resource, source_location))
		if _is_stackable_storage_resource(item_resource) and backpack_stack_quantity > 1:
			_open_transfer_quantity_dialog(item_resource, source_location, target_location, target_index, backpack_stack_quantity)
		else:
			_global_inventory.call("transfer_backpack_to_warehouse", item_resource, target_index)
	elif source_is_storage and not target_is_storage:
		_global_inventory.call("transfer_storage_to_equipment", item_resource, source_location, target_location)
	elif not source_is_storage and target_is_storage:
		_global_inventory.call("transfer_equipment_to_storage", source_location, target_location, target_index)
	elif not source_is_storage and not target_is_storage:
		_global_inventory.call("swap_equipment_locations", source_location, target_location)


func _is_stackable_storage_resource(item_resource: Resource) -> bool:
	if item_resource == null:
		return false
	# 物品类型；当前强化石和修复包支持堆叠，未来新增堆叠资源时可在此扩展稳定类型表。
	var item_kind: String = str(item_resource.get("item_kind"))
	return item_kind in ["enhancement_stone", "repair_kit"]


func _clear_container(container: Node) -> void:
	if container == null:
		return
	# 现有列表子节点；取值为容器直接子节点，数据刷新前全部排队释放。
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_close_pressed() -> void:
	_pending_stone_resource = null
	_pending_stone_location = ""
	_stone_return_view_pending = false
	_reset_quantity_operation()
	_apply_storage_display_mode()
	closed.emit()
