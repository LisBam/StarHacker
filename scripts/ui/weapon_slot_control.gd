extends PanelContainer
class_name WeaponSlotControl

## 武器槽控件负责显示一个装备槽或背包物品槽。
## 它只处理显示、拖拽数据打包、拖拽目标校验和 CD 覆盖绘制，不直接修改装备或背包数据。
## HUD 通过 drop_received 信号接收拖拽结果，再调用装备组件完成装备、移动或卸下。

signal drop_received(drop_data: Dictionary, target_context: String, target_kind: String, target_index: int)
signal drag_released_outside(drop_data: Dictionary)
signal item_selected(item_resource: Resource, selected_context: String, selected_kind: String, selected_index: int)
signal enhancement_drop_received(stone_resource: Resource, source_location: String, weapon_resource: Resource)
signal repair_kit_drop_received(repair_kit_resource: Resource, source_location: String, weapon_resource: Resource)

## 统一物品详情格式化器；用于在战斗装备栏与背包中显示带颜色的基础值和强化值。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 通用物品卡片视图；战斗装备栏与背包武器必须和仓库、锻造、商店使用同一固定尺寸模板。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 全局存储拖拽协议标识；与 StorageItemControl 一致，用于识别从背包拖入的强化石。
const GLOBAL_STORAGE_DRAG_DATA_TYPE: String = "global_storage_item"
## 武器耐久条组件；统一贴在槽位底部并只读取 WeaponData 耐久状态。
## 通用耐久补充：当前实际耐久显示由 ItemCardView 内部组件按耐久属性决定。
const WEAPON_DURABILITY_BAR_SCRIPT: Script = preload("res://scripts/ui/weapon_durability_bar.gd")
## 不可选目标覆盖颜色；默认使用半透明灰黑层，仍允许玩家辨认武器名称和耐久状态。
const UNAVAILABLE_TARGET_OVERLAY_COLOR: Color = Color(0.16, 0.16, 0.16, 0.72)
## 拖拽预览最小尺寸；默认 128×50，保证武器名称在鼠标旁保持清晰且不会遮挡过多背包内容。
const DRAG_PREVIEW_MINIMUM_SIZE: Vector2 = Vector2(128.0, 50.0)
## 拖拽预览背景颜色；默认使用高透明度深蓝黑，与战斗背包武器槽风格一致。
const DRAG_PREVIEW_BACKGROUND_COLOR: Color = Color(0.06, 0.09, 0.12, 0.88)
## 拖拽预览边框颜色；默认使用明亮青色，突出当前正在移动的武器。
const DRAG_PREVIEW_BORDER_COLOR: Color = Color(0.48, 0.90, 1.0, 0.96)
## 绿色可选目标悬停缩放；默认 1.03，让可使用道具的武器具有明确鼠标反馈。
const TARGET_HOVER_SCALE: float = 1.03
## 绿色可选目标悬停时长；默认 0.12 秒，进入和离开时共用。
const TARGET_HOVER_DURATION: float = 0.12

## 点击与拖拽判定阈值；默认 6 像素，鼠标移动达到该距离后只允许拖拽，不再触发点击操作菜单。
@export_range(0.0, 64.0, 0.5) var click_drag_threshold_pixels: float = 6.0
@export_category("背包武器交互动效")
## 点击按压缩放；默认 0.94，仅用于局内背包武器，数值越小按压反馈越明显，运行时无需动态修改。
@export_range(0.80, 1.0, 0.01) var inventory_click_press_scale: float = 0.94
## 点击回弹峰值；默认 1.04，仅用于普通点击释放，数值越大弹性表现越强，运行时无需动态修改。
@export_range(1.0, 1.20, 0.01) var inventory_click_bounce_scale: float = 1.04
## 点击按压动画时长；默认 0.07 秒，控制鼠标按下后的收缩速度，运行时无需动态修改。
@export_range(0.01, 0.30, 0.01) var inventory_click_press_duration: float = 0.07
## 点击释放动画时长；默认 0.14 秒，控制回弹恢复速度，运行时无需动态修改。
@export_range(0.04, 0.50, 0.01) var inventory_click_release_duration: float = 0.14
## 拖拽来源缩放；默认 0.96，拖动期间让原槽位轻微收缩以表达物品已被拿起，运行时无需动态修改。
@export_range(0.80, 1.0, 0.01) var inventory_drag_source_scale: float = 0.96
## 拖拽来源透明度；默认 0.58，拖动期间降低原槽位存在感，取值越低原位置越淡，运行时无需动态修改。
@export_range(0.20, 1.0, 0.01) var inventory_drag_source_opacity: float = 0.58
## 拖拽预览初始缩放；默认 0.92，预览出现后会回弹放大，运行时无需动态修改。
@export_range(0.70, 1.0, 0.01) var inventory_drag_preview_start_scale: float = 0.92
## 拖拽预览脉冲缩放；默认 1.04，拖动期间循环轻微呼吸，运行时无需动态修改。
@export_range(1.0, 1.20, 0.01) var inventory_drag_preview_pulse_scale: float = 1.04
## 拖拽预览单段脉冲时长；默认 0.32 秒，数值越小呼吸与摆动越快，运行时无需动态修改。
@export_range(0.08, 1.0, 0.01) var inventory_drag_preview_pulse_duration: float = 0.32
## 拖拽预览摆动弧度；默认 0.035 弧度，提供轻微左右动态且避免影响文字阅读，运行时无需动态修改。
@export_range(0.0, 0.15, 0.005) var inventory_drag_preview_tilt_radians: float = 0.035

## 槽位所属上下文；取值为 equipment 或 inventory，默认 equipment，修改会影响拖拽来源和投放规则。
var slot_context: String = "equipment"
## 槽位类型；取值为 ranged、melee、inventory 或 inventory_drop，默认 ranged，修改会影响可接受的武器类型。
var slot_kind: String = "ranged"
## 槽位索引；远程槽和背包槽使用有效下标，近战槽和卸下区默认 -1，修改会影响拖拽目标定位。
var slot_index: int = -1
## 当前槽位武器资源；取值为 Resource 或 null，默认空槽，修改会影响显示文本和是否可被拖拽。
var weapon_data: Resource
## 当前槽位是否被选中；取值为 true/false，默认 false，修改会影响槽位边框和标题状态。
var is_selected: bool = false
## 冷却覆盖比例；取值为 0 到 1，默认 0 表示无覆盖，修改会影响白色 CD 进度遮罩高度。
var cooldown_ratio: float = 0.0
## 空槽显示文本；默认“空”，用于没有武器资源时的槽位提示，修改会影响空槽可读性。
var empty_text: String = "空"
## 当前槽位是否为强化目标；默认 false，选择强化武器期间会临时绘制绿色边框和背景。
var is_enhancement_target_highlight: bool = false
## 当前武器是否处于目标选择但不可选择状态；默认 false，满耐久武器在修复包选择期间会显示灰色覆盖层。
var _weapon_target_selection_blocked: bool = false

## 标题标签缓存；默认由 _ready 创建，显示槽位编号或槽位名称，修改会影响标题刷新目标。
var _title_label: Label
## 武器名标签缓存；默认由 _ready 创建，显示武器名称或空槽文本，修改会影响武器名称刷新目标。
var _name_label: Label
## 详情标签缓存；默认由 _ready 创建，显示能量消耗和冷却信息，修改会影响槽位辅助信息刷新目标。
var _detail_label: Label
## 当前拖拽数据缓存；取值为拖拽字典或空字典，默认用于拖拽结束时判断是否需要丢弃到世界。
var _active_drag_data: Dictionary = {}
## 武器耐久条缓存；默认在 ready 创建，宽度跟随槽位并在武器耐久变化时单独刷新。
## 通用模板补充：该缓存保留旧结构兼容，当前可见耐久条由 _item_card_view 统一刷新。
var _durability_bar: Control
## 武器耐久条覆盖宿主；默认由 PanelContainer 拉伸为完整槽位，耐久条在宿主内部仅贴底占用 5 像素。
var _durability_overlay: Control
## 左键点击是否等待释放确认；默认 false，按下武器时设为 true，进入拖拽或释放后立即清理。
var _pending_left_click: bool = false
## 左键按下位置；默认零向量，使用槽位本地坐标计算移动距离并区分普通点击与拖拽。
var _left_press_position: Vector2 = Vector2.ZERO
## 当前按压是否已超过拖拽阈值；默认 false，超过后即使没有成功投放也不会弹出“装备”菜单。
var _left_drag_exceeded_threshold: bool = false
## 当前交互动效补间；默认 null，新点击或拖拽状态会终止旧补间，避免快速操作造成缩放叠加。
var _interaction_tween: Tween
## 不可选目标覆盖层；默认由 ready 创建并隐藏，仅在修复包选择期间覆盖满耐久武器。
var _target_filter_overlay: ColorRect
## 通用物品卡片视图缓存；默认在 ready 创建，统一武器名称、槽位职责、摘要、尺寸、冷却与耐久显示。
var _item_card_view: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_item_card_view()
	_refresh_text()
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_slot_data(new_context: String, new_kind: String, new_index: int, new_weapon_data: Resource, new_is_selected: bool) -> void:
	slot_context = new_context
	slot_kind = new_kind
	slot_index = new_index
	weapon_data = new_weapon_data
	is_selected = new_is_selected
	if _item_card_view != null:
		_item_card_view.call("set_visual_state", is_selected, is_enhancement_target_highlight)
	_refresh_target_filter_overlay()
	_refresh_text()
	queue_redraw()


func set_empty_text(new_empty_text: String) -> void:
	empty_text = new_empty_text
	_refresh_text()


func set_cooldown_ratio(new_cooldown_ratio: float) -> void:
	# 标准化冷却比例；取值为 0 到 1，默认用于判断是否需要重绘冷却遮罩。
	var resolved_cooldown_ratio: float = clampf(new_cooldown_ratio, 0.0, 1.0)
	if is_equal_approx(cooldown_ratio, resolved_cooldown_ratio):
		return

	cooldown_ratio = resolved_cooldown_ratio
	if _item_card_view != null:
		_item_card_view.call("set_cooldown_ratio", cooldown_ratio)
	queue_redraw()


func set_enhancement_target_highlight(enabled: bool) -> void:
	is_enhancement_target_highlight = enabled and weapon_data != null
	_weapon_target_selection_blocked = false
	_refresh_target_filter_overlay()
	if _item_card_view != null:
		_item_card_view.call("set_visual_state", is_selected, is_enhancement_target_highlight)
	queue_redraw()


func set_weapon_target_selection_state(selection_active: bool, selectable: bool) -> void:
	# 目标选择状态；空槽不参与选择表现，已有武器根据可用性显示绿色高亮或灰色滤镜。
	var has_weapon: bool = weapon_data != null and str(weapon_data.get("weapon_type")) in ["ranged", "melee"]
	is_enhancement_target_highlight = selection_active and selectable and has_weapon
	_weapon_target_selection_blocked = selection_active and not selectable and has_weapon
	if _weapon_target_selection_blocked or not is_enhancement_target_highlight:
		_restore_target_hover_visual()
	_refresh_target_filter_overlay()
	if _item_card_view != null:
		_item_card_view.call("set_visual_state", is_selected, is_enhancement_target_highlight)
	queue_redraw()


func refresh_durability() -> void:
	if _item_card_view != null:
		_item_card_view.call("refresh_durability")
	_refresh_text()


func _draw() -> void:
	# 槽位背景矩形；取值覆盖控件完整尺寸，默认用于绘制稳定底色，修改会影响武器槽视觉边界。
	var background_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(background_rect, Color(0.06, 0.075, 0.09, 0.92), true)
	if is_enhancement_target_highlight:
		draw_rect(background_rect, Color(0.16, 0.52, 0.24, 0.34), true)

	if cooldown_ratio > 0.0:
		# CD 覆盖高度；取值为控件高度乘冷却比例，默认从满槽随冷却减少，修改会影响白色遮罩退减速度表现。
		var cooldown_height: float = size.y * cooldown_ratio
		# CD 覆盖矩形；取值从槽位底部向上覆盖，默认白色半透明，修改会影响冷却期间的视觉反馈区域。
		var cooldown_rect: Rect2 = Rect2(Vector2(0.0, size.y - cooldown_height), Vector2(size.x, cooldown_height))
		draw_rect(cooldown_rect, Color(1.0, 1.0, 1.0, 0.42), true)

	# 边框颜色；取值根据选中状态决定，默认选中槽更亮，修改会影响当前武器辨识度。
	var border_color: Color = Color(0.52, 1.0, 0.62, 1.0) if is_enhancement_target_highlight else (Color(0.55, 0.92, 1.0, 1.0) if is_selected else Color(0.22, 0.30, 0.36, 1.0))
	draw_rect(background_rect, border_color, false, 2.0)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if weapon_data == null or _weapon_target_selection_blocked:
		return null
	_pending_left_click = false
	_left_drag_exceeded_threshold = true

	# 拖拽预览控件；取值为临时 Label，默认显示武器名称，修改会影响拖拽时鼠标旁的提示。
	# 动态预览补充；当前使用临时卡片替代纯文本标签，背包武器会循环呼吸摆动，其他槽位不播放循环动画。
	var preview_control: Control = _create_drag_preview_control()
	set_drag_preview(preview_control)
	_play_inventory_drag_source_animation()
	_play_inventory_drag_preview_animation(preview_control)

	_active_drag_data = {
		"source_context": slot_context,
		"slot_kind": slot_kind,
		"slot_index": slot_index,
		"weapon_data": weapon_data,
	}
	return _active_drag_data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false

	# 拖拽字典；取值来自其他 WeaponSlotControl，默认包含来源和武器资源，修改会影响投放校验。
	var drop_data: Dictionary = data as Dictionary
	if str(drop_data.get("type", "")) == GLOBAL_STORAGE_DRAG_DATA_TYPE:
		# 全局存储拖拽资源；局内只接受修复包投放到已有武器的槽位，强化石只能进入锻造系统。
		var storage_resource: Resource = drop_data.get("resource") as Resource
		return storage_resource != null and str(storage_resource.get("item_kind")) == "repair_kit" and weapon_data != null and not str(drop_data.get("source_location", "")).is_empty()
	if not drop_data.has("weapon_data") or not (drop_data["weapon_data"] is Resource):
		return false

	# 被拖拽武器资源；取值为 Resource，默认来自拖拽数据，修改会影响槽位类型校验。
	var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
	if slot_context == "inventory":
		# 拖拽来源上下文；取值为 equipment 或 inventory，默认空字符串表示非法来源，修改会影响背包槽可接收的来源。
		var source_context: String = str(drop_data.get("source_context", ""))
		return source_context == "equipment" or source_context == "inventory"

	if slot_kind == "ranged":
		return str(dragged_weapon.get("weapon_type")) == "ranged"
	if slot_kind == "melee":
		return str(dragged_weapon.get("weapon_type")) == "melee"

	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return

	# 投放数据；取值来自拖拽源，默认传递给 HUD 处理，修改会影响装备和卸下目标解析。
	var drop_data: Dictionary = data as Dictionary
	if str(drop_data.get("type", "")) == GLOBAL_STORAGE_DRAG_DATA_TYPE:
		# 修复包资源；已通过投放校验，只发送修复请求而不执行武器位置交换。
		var repair_kit_resource: Resource = drop_data.get("resource") as Resource
		repair_kit_drop_received.emit(repair_kit_resource, str(drop_data.get("source_location", "")), weapon_data)
		return
	drop_received.emit(drop_data, slot_context, slot_kind, slot_index)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return

	if _active_drag_data.is_empty():
		return

	# 当前视口；取值可能在场景切换或节点释放期间为空，默认为空时只清理拖拽状态。
	var current_viewport: Viewport = get_viewport()
	if current_viewport == null:
		_active_drag_data = {}
		return

	# 拖拽是否被目标成功接收；取值来自 Viewport，默认 false 表示释放在无效区域。
	var drag_successful: bool = current_viewport.gui_is_drag_successful()
	if not drag_successful:
		drag_released_outside.emit(_active_drag_data)

	_active_drag_data = {}
	_restore_inventory_interaction_visual()


func _build_content() -> void:
	# 内边距容器；取值为新建 MarginContainer，默认提供文字呼吸空间，修改会影响槽位内容排版。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	# 文本垂直容器；取值为新建 VBoxContainer，默认纵向排列标题、名称和详情，修改会影响槽位内容结构。
	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 1)
	margin.add_child(text_box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 10)
	text_box.add_child(_title_label)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 12)
	text_box.add_child(_name_label)

	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 9)
	text_box.add_child(_detail_label)


func _build_durability_bar() -> void:
	_durability_overlay = Control.new()
	_durability_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_durability_overlay)
	_durability_bar = WEAPON_DURABILITY_BAR_SCRIPT.new() as Control
	_durability_overlay.add_child(_durability_bar)
	_durability_bar.call("configure", weapon_data)


func _build_item_card_view() -> void:
	if _item_card_view != null:
		return
	# 战斗槽保留拖拽、点击和冷却数据协议，全部可见内容统一交给跨系统物品卡片模板。
	_item_card_view = ITEM_CARD_VIEW_SCRIPT.new() as Control
	_item_card_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_item_card_view)


func _build_target_filter_overlay() -> void:
	_target_filter_overlay = ColorRect.new()
	_target_filter_overlay.color = UNAVAILABLE_TARGET_OVERLAY_COLOR
	_target_filter_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_filter_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_target_filter_overlay.visible = false
	add_child(_target_filter_overlay)


func _refresh_target_filter_overlay() -> void:
	if _target_filter_overlay != null:
		_target_filter_overlay.visible = false
	if _item_card_view != null:
		_item_card_view.call("set_disabled_state", _weapon_target_selection_blocked and weapon_data != null)
		if _weapon_target_selection_blocked:
			_item_card_view.call("play_hover", self, false)


func _refresh_text() -> void:
	# 旧版文本节点兼容；仅当外部旧场景已经创建这些节点时同步内容，新建槽位不再重复生成第二套物品视觉。
	if _title_label != null and _name_label != null and _detail_label != null:
		_title_label.text = _get_slot_title()
		_name_label.text = _get_weapon_display_name(weapon_data, empty_text)
		_detail_label.text = _get_weapon_detail_text()
	# 通用卡片内容；槽位职责、武器名称和能量摘要沿用原数据，但排版与耐久组件不再由本控件单独实现。
	if _item_card_view != null:
		_item_card_view.call("configure", weapon_data, 1, _get_slot_title(), _get_weapon_detail_text(), empty_text, _get_weapon_display_name(weapon_data, empty_text))
		_item_card_view.call("set_visual_state", is_selected, is_enhancement_target_highlight)
		_item_card_view.call("set_cooldown_ratio", cooldown_ratio)
	tooltip_text = str(ITEM_DETAIL_FORMATTER.call("build_plain_text", weapon_data, 1)) if weapon_data != null else ""


func _make_custom_tooltip(_for_text: String) -> Object:
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", weapon_data, 1)


func _on_gui_input(event: InputEvent) -> void:
	if weapon_data == null or _weapon_target_selection_blocked:
		return
	if event is InputEventMouseMotion and _pending_left_click:
		# 鼠标移动事件；按压期间只记录是否跨过阈值，实际拖拽数据仍由 Godot 控件协议生成。
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		_left_drag_exceeded_threshold = _left_drag_exceeded_threshold or motion_event.position.distance_to(_left_press_position) >= click_drag_threshold_pixels
		return
	if not (event is InputEventMouseButton):
		return
	# 鼠标按钮事件；左键按下只登记候选点击，释放且未拖动时才通知 HUD 打开装备或强化操作。
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_pending_left_click = true
		_left_press_position = mouse_event.position
		_left_drag_exceeded_threshold = false
		_play_inventory_click_press_animation()
		return
	# 是否触发普通点击；释放位置仍处于阈值内且拖拽协议没有启动时才发送选择信号。
	var should_emit_selection: bool = _pending_left_click and not _left_drag_exceeded_threshold and mouse_event.position.distance_to(_left_press_position) <= click_drag_threshold_pixels
	_pending_left_click = false
	_left_drag_exceeded_threshold = false
	if should_emit_selection:
		_play_inventory_click_release_animation()
		item_selected.emit(weapon_data, slot_context, slot_kind, slot_index)
	else:
		_restore_inventory_interaction_visual()


func _on_mouse_entered() -> void:
	if _item_card_view != null and weapon_data != null:
		_item_card_view.call("play_hover", self, true)


func _on_mouse_exited() -> void:
	if _item_card_view != null:
		_item_card_view.call("play_hover", self, false)


func _play_target_hover_animation(target_scale: float) -> void:
	_prepare_inventory_interaction_tween()
	pivot_offset = size * 0.5
	_interaction_tween.tween_property(self, "scale", Vector2.ONE * target_scale, TARGET_HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _restore_target_hover_visual() -> void:
	if _interaction_tween != null and _interaction_tween.is_valid():
		_interaction_tween.kill()
	_interaction_tween = null
	scale = Vector2.ONE
	modulate = Color.WHITE


func _create_drag_preview_control() -> Control:
	# 预览面板；深色半透明底与青色边框延续背包卡片风格，并通过最小尺寸保证长名称可读。
	if _item_card_view != null:
		return _item_card_view.call("create_drag_preview") as Control
	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.custom_minimum_size = DRAG_PREVIEW_MINIMUM_SIZE
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 预览样式；圆角和两像素边框用于从静态背包槽中分离正在拖动的武器。
	var preview_style: StyleBoxFlat = StyleBoxFlat.new()
	preview_style.bg_color = DRAG_PREVIEW_BACKGROUND_COLOR
	preview_style.border_color = DRAG_PREVIEW_BORDER_COLOR
	preview_style.set_border_width_all(2)
	preview_style.set_corner_radius_all(6)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	# 预览名称；只显示武器名称，完整属性仍由原槽位悬停提示承担。
	var preview_label: Label = Label.new()
	preview_label.text = _get_weapon_display_name(weapon_data, empty_text)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.add_theme_font_size_override("font_size", 14)
	preview_panel.add_child(preview_label)
	return preview_panel


func _play_inventory_click_press_animation() -> void:
	# 全局交互补充：武器点击不再播放专属按压缩放，避免与其他物品卡片产生差异化反馈。
	# 通用点击补充：当前直接调用 ItemCardView 标准点击动画，与全部物品控件保持一致。
	if _item_card_view != null:
		_item_card_view.call("play_click", self, true)


func _play_inventory_click_release_animation() -> void:
	# 回弹阶段；先略微放大并提亮，再回到原始比例和颜色，形成明确但短促的点击确认感。
	# 全局交互补充：当前取消专属回弹，点击释放保持与仓库、商店、锻造和资源卡片一致。
	# 通用点击补充：释放后由 ItemCardView 根据悬浮状态恢复统一比例。
	if _item_card_view != null:
		_item_card_view.call("play_click", self, false)


func _play_inventory_drag_source_animation() -> void:
	if _item_card_view != null:
		_item_card_view.call("play_drag_source", self, true)


func _play_inventory_drag_preview_animation(preview_control: Control) -> void:
	if _item_card_view != null:
		_item_card_view.call("play_drag_preview", preview_control)


func _prepare_inventory_interaction_tween() -> void:
	if _interaction_tween != null and _interaction_tween.is_valid():
		_interaction_tween.kill()
	pivot_offset = size * 0.5
	_interaction_tween = create_tween()
	_interaction_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


func _restore_inventory_interaction_visual() -> void:
	if _item_card_view != null:
		_item_card_view.call("play_drag_source", self, false)


func _get_slot_title() -> String:
	if slot_context == "inventory" and weapon_data != null:
		return _get_weapon_type_label(weapon_data)
	if slot_kind == "inventory_drop":
		return "放入"
	if slot_kind == "ranged":
		return "远程 %d" % (slot_index + 1)
	if slot_kind == "melee":
		return "近战"
	return "空位"


func _get_weapon_display_name(target_weapon_data: Resource, fallback_name: String) -> String:
	if target_weapon_data == null:
		return fallback_name

	# 武器显示名；取值来自资源 display_name 字段，默认 fallback_name，修改会影响槽位主文本。
	var display_name: String = str(target_weapon_data.get("display_name"))
	if display_name.is_empty():
		return fallback_name
	return "%s（损坏）" % display_name if target_weapon_data.has_method("is_broken") and bool(target_weapon_data.call("is_broken")) else display_name


func _get_weapon_detail_text() -> String:
	if weapon_data == null:
		return ""

	# 武器能量消耗；取值来自资源 energy_cost 字段，默认 0，修改会影响槽位能量提示。
	var energy_cost: float = maxf(float(weapon_data.get("energy_cost")), 0.0)
	if energy_cost <= 0.0:
		return "能量 0"

	return "能量 %d" % roundi(energy_cost)


func _get_weapon_type_label(target_weapon_data: Resource) -> String:
	if target_weapon_data == null:
		return "空位"

	# 武器类型字段；取值为 ranged 或 melee，默认由武器资源配置，修改会影响背包槽标题显示。
	var weapon_type: String = str(target_weapon_data.get("weapon_type"))
	if weapon_type == "ranged":
		return "远程"
	if weapon_type == "melee":
		return "近战"

	return "未知"


func _get_weapon_tooltip_text() -> String:
	if weapon_data == null:
		return ""

	# 提示框文本行；取值为字符串数组，默认逐项追加武器详细属性。
	var tooltip_lines: PackedStringArray = PackedStringArray()
	# 武器名称；取值来自资源 display_name 字段，默认用于提示框第一行。
	var display_name: String = _get_weapon_display_name(weapon_data, empty_text)
	# 武器类型；取值为 ranged 或 melee，默认转换为中文类型文本。
	var weapon_type: String = str(weapon_data.get("weapon_type"))
	tooltip_lines.append(display_name)
	tooltip_lines.append("类型：%s" % _get_weapon_type_label(weapon_data))

	# 武器说明；取值来自资源 description 字段，默认空字符串表示不显示说明行。
	var description: String = str(weapon_data.get("description"))
	if not description.is_empty():
		tooltip_lines.append(description)

	# 武器能量消耗；取值来自资源 energy_cost 字段，默认 0 表示不消耗能量。
	var energy_cost: float = maxf(float(weapon_data.get("energy_cost")), 0.0)
	# 武器后坐力；取值来自资源 recoil_force 字段，默认 0 表示不开火后推。
	var recoil_force: float = maxf(float(weapon_data.get("recoil_force")), 0.0)
	# 武器前坐力；取值来自资源 front_recoil_force 字段，默认 0 表示不向攻击方向推动使用者。
	var front_recoil_force: float = maxf(float(weapon_data.get("front_recoil_force")), 0.0)
	# 武器冲击力；取值来自资源 impact_force 字段，默认 0 表示不击退目标。
	var impact_force: float = maxf(float(weapon_data.get("impact_force")), 0.0)
	# 武器暴击率；使用有效属性接口读取强化后的百分比。
	var critical_chance: float = float(weapon_data.call("get_effective_stat", "critical_chance")) if weapon_data.has_method("get_effective_stat") else maxf(float(weapon_data.get("critical_chance")), 0.0)
	# 武器暴击伤害；使用倍率保存，详情转换为百分比展示。
	var critical_damage: float = float(weapon_data.call("get_effective_stat", "critical_damage")) if weapon_data.has_method("get_effective_stat") else maxf(float(weapon_data.get("critical_damage")), 1.0)
	tooltip_lines.append("能量消耗：%d" % roundi(energy_cost))
	if recoil_force > 0.0:
		tooltip_lines.append("后坐力：%d" % roundi(recoil_force))
	if front_recoil_force > 0.0:
		tooltip_lines.append("前坐力：%d" % roundi(front_recoil_force))
	tooltip_lines.append("冲击力：%d" % roundi(impact_force))
	tooltip_lines.append("暴击率：%.0f%%" % (critical_chance * 100.0))
	tooltip_lines.append("暴击伤害：%.0f%%" % (critical_damage * 100.0))

	if weapon_type == "ranged":
		_append_ranged_tooltip_lines(tooltip_lines)
	elif weapon_type == "melee":
		_append_melee_tooltip_lines(tooltip_lines)

	return "\n".join(tooltip_lines)


func _append_ranged_tooltip_lines(tooltip_lines: PackedStringArray) -> void:
	# 远程伤害；取值来自资源 ranged_damage 字段，默认用于提示远程命中伤害。
	var ranged_damage: float = maxf(float(weapon_data.get("ranged_damage")), 0.0)
	# 子弹速度；取值来自资源 projectile_speed 字段，默认用于提示弹体飞行速度。
	var projectile_speed: float = maxf(float(weapon_data.get("projectile_speed")), 0.0)
	# 子弹射程；取值来自资源 bullet_range 字段，默认用于提示弹体最大飞行距离。
	var bullet_range: float = maxf(float(weapon_data.get("bullet_range")), 0.0)
	# 远程冷却；取值来自资源 ranged_cooldown 字段，默认用于提示连续射击间隔。
	var ranged_cooldown: float = maxf(float(weapon_data.get("ranged_cooldown")), 0.0)
	# 武器扩散；取值来自资源 spread_degrees 字段，表示弹体相对瞄准方向的最大随机偏移角度。
	var spread_degrees: float = maxf(float(weapon_data.get("spread_degrees")), 0.0)
	tooltip_lines.append("伤害：%d" % roundi(ranged_damage))
	tooltip_lines.append("子弹速度：%d" % roundi(projectile_speed))
	tooltip_lines.append("子弹射程：%d" % roundi(bullet_range))
	tooltip_lines.append("扩散：%.1f°" % spread_degrees)
	tooltip_lines.append("冷却：%.2f 秒" % ranged_cooldown)


func _append_melee_tooltip_lines(tooltip_lines: PackedStringArray) -> void:
	# 近战伤害；取值来自资源 melee_damage 字段，默认用于提示挥击伤害。
	var melee_damage: float = maxf(float(weapon_data.get("melee_damage")), 0.0)
	# 近战冷却；取值来自资源 melee_cooldown 字段，默认用于提示连续挥击间隔。
	var melee_cooldown: float = maxf(float(weapon_data.get("melee_cooldown")), 0.0)
	# 命中框持续时间；取值来自资源 melee_active_duration 字段，默认用于提示近战判定窗口。
	var melee_active_duration: float = maxf(float(weapon_data.get("melee_active_duration")), 0.0)
	tooltip_lines.append("伤害：%d" % roundi(melee_damage))
	tooltip_lines.append("冷却：%.2f 秒" % melee_cooldown)
	tooltip_lines.append("判定时长：%.2f 秒" % melee_active_duration)
