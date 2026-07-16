extends Button
class_name StorageItemControl

## 仓库物品控件统一承担物品摘要、悬停详情、快捷点击和拖拽数据生成。
## 控件不直接修改全局物品所有权，所有操作通过信号交给仓库面板调用 GlobalInventory 接口。

signal quick_action_requested(item_resource: Resource)
signal item_action_requested(item_resource: Resource)
signal item_drop_requested(drag_data: Dictionary, target_location: String, target_index: int)
signal enhancement_drop_requested(stone_resource: Resource, source_location: String, weapon_resource: Resource)
signal repair_kit_drop_requested(repair_kit_resource: Resource, source_location: String, weapon_resource: Resource)

## 拖拽数据类型标识；默认用于拒绝来自其他 UI 系统的不兼容拖拽数据。
const DRAG_DATA_TYPE: String = "global_storage_item"
## 统一物品详情格式化器；默认生成基础值、强化值、资源词条和动态价值信息。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 通用物品卡片视图；仓库、背包、锻造来源、物资撤离与结算必须统一复用该固定尺寸模板。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 库存限制配置；卡片显示数量和跨容器移动数量统一使用单组 10 件上限。
const INVENTORY_LIMITS: Script = preload("res://scripts/data/inventory_limits.gd")
## 强化词条增强颜色；默认亮绿色，与悬停详情保持一致。
const STONE_BENEFICIAL_COLOR: String = "#70e889"
## 强化词条削弱颜色；默认亮红色，与悬停详情保持一致。
const STONE_DETRIMENTAL_COLOR: String = "#ff7070"
## 不可选物品灰色覆盖颜色；与战斗武器栏完全一致，完整覆盖卡片但保留名称与耐久信息可辨认。
const UNAVAILABLE_TARGET_FILTER_COLOR: Color = Color(0.16, 0.16, 0.16, 0.72)
## 可选目标悬停缩放；默认 1.03，仅在绿色高亮目标上播放。
const SELECTABLE_TARGET_HOVER_SCALE: float = 1.03
## 可选目标悬停动画时长；默认 0.12 秒，用于平滑进入和退出目标反馈。
const SELECTABLE_TARGET_HOVER_DURATION: float = 0.12
## 武器耐久条组件；用于仓库、展开背包和结算卡片统一显示武器剩余耐久。
## 通用耐久补充：当前实际显示由 ItemCardView 内部按耐久属性决定，不再限定武器类型。
const WEAPON_DURABILITY_BAR_SCRIPT: Script = preload("res://scripts/ui/weapon_durability_bar.gd")

## 当前显示的物品资源；默认 null 表示尚未配置，配置后用于摘要、详情和拖拽身份校验。
var _item_resource: Resource
## 当前物品所在容器；取值为 warehouse 或 backpack，默认空字符串表示不可拖拽。
var _location: String = ""
## 当前物品展示索引；取值大于等于 0，默认 -1 表示没有合法排序位置。
var _item_index: int = -1
## 是否允许左键快捷操作；默认 false，纯仓库模式只浏览和出售，展开背包后才启用容器互转。
var _quick_action_enabled: bool = false
## 当前堆叠数量；武器固定为 1，强化石取值 1 到 99，修改会影响卡片数量角标和整组价值。
## 现行限制补充：武器与装备固定为 1，强化石与其他可堆叠资源取值 1 到 10。
var _quantity: int = 1
## 强化石卡片富文本；默认运行时按需创建，用于在方形资源格内直接区分绿色增强与红色削弱词条。
## 宽卡布局补充；强化石已与武器统一为宽卡片，该富文本仅负责品质、百分比和利弊颜色。
## 通用模板补充：该标签仅保留旧接口兼容，当前强化石摘要由 _item_card_view 统一显示。
var _stone_summary_label: RichTextLabel
## 是否将当前武器标记为强化目标；默认 false，选择强化武器期间会临时点亮所有武器卡片。
var _enhancement_target_highlight: bool = false
## 当前是否处于武器目标选择状态；默认 false，启用后会同时管理可选高亮和不可选灰色滤镜。
var _weapon_target_selection_active: bool = false
## 当前武器是否因目标条件不满足而禁止选择；默认 false，修复包选择期间满耐久武器会设为 true。
var _weapon_target_selection_blocked: bool = false
## 当前物品是否由外部界面标记为可选目标；默认 false，锻造与物资撤离界面会用它统一控制所有物品类型的滤镜。
var _item_selection_active: bool = false
## 当前物品是否因外部规则不满足而禁止选择；默认 false，启用时会覆盖灰色滤镜并同时阻止点击与拖拽。
var _item_selection_blocked: bool = false
## 当前物品是否在外部选择状态中显示可选高亮；默认 false，锻造可选材料通常保持原色，目标道具可按需启用绿色提示。
var _item_selection_highlight: bool = false
## 当前卡片是否允许生成拖拽数据；默认 true，物资撤离等纯点击界面会关闭以避免跨系统拖动物品。
var _drag_enabled: bool = true
## 是否采用战斗武器槽视觉；默认 false 保持仓库宽卡布局，战斗背包开启后会同步深色背景、边框和三行排版。
var _weapon_slot_visual_style_enabled: bool = false
## 武器耐久条缓存；默认按需创建，资源卡片隐藏，武器卡片始终贴在 UI 最底部。
## 通用模板补充：该缓存仅保留旧接口兼容，当前耐久组件由 _item_card_view 按属性控制。
var _durability_bar: Control
## 当前绿色目标悬停补间；默认 null，新悬停状态会终止旧补间以避免缩放叠加。
var _selection_hover_tween: Tween
## 当前卡片价值标签；默认“价值”，物资撤离面板会改为“撤离收费”。
var _price_label: String = "价值"
## 当前卡片数值覆盖；默认 -1 使用物品有效价值，物资撤离面板传入实际运费。
var _displayed_price_override: int = -1
## 不可选目标灰色覆盖层；默认隐藏，选择状态阻止当前物品时完整覆盖按钮、富文本与耐久条。
var _target_filter_overlay: ColorRect
## 通用物品卡片视图缓存；默认首次配置时创建，承担全部物品名称、类型、摘要、尺寸与耐久显示。
var _item_card_view: Control
## 当前卡片名称前缀；默认空字符串，上次撤离等长期状态会在耐久刷新后继续保留。
var _extraction_prefix: String = ""
## 当前卡片是否正在作为拖拽来源；默认 false，拖拽结束时用于统一恢复缩放与透明度。
var _is_drag_source_active: bool = false


func configure(item_resource: Resource, location: String, item_index: int, quick_action_enabled: bool, extraction_prefix: String = "", quantity: int = 1, price_label: String = "价值", displayed_price_override: int = -1) -> void:
	_item_resource = item_resource
	_location = location
	_item_index = item_index
	_quick_action_enabled = quick_action_enabled
	_quantity = clampi(quantity, 1, INVENTORY_LIMITS.MAX_STACK_QUANTITY)
	_price_label = price_label if not price_label.is_empty() else "价值"
	_displayed_price_override = displayed_price_override
	_extraction_prefix = extraction_prefix
	# 物品摘要；强化石和修复包共用紧凑富文本资源卡，武器保持两列宽卡片显示分类和动态价值。
	# 通用模板补充：当前所有物品使用相同固定卡片，类型差异只影响摘要内容，不影响布局结构。
	text = ""
	if _stone_summary_label != null:
		_stone_summary_label.visible = false
	_ensure_item_card_view()
	_refresh_item_card_view()
	tooltip_text = ITEM_DETAIL_FORMATTER.call("build_plain_text", _item_resource, _quantity, _get_tooltip_price_label(), _get_tooltip_price_override())
	disabled = _item_resource == null
	custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flat = true
	# 鼠标指针形态；可操作容器使用手型，结算只读条目使用普通箭头。
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _location.is_empty() and _item_index >= 0 else Control.CURSOR_ARROW
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_refresh_enhancement_target_highlight()


func update_storage_context(item_resource: Resource, location: String, item_index: int, quick_action_enabled: bool, extraction_prefix: String = "", quantity: int = 1) -> void:
	## 复用现有卡片并同步库存上下文；资源、数量或显示前缀变化时执行完整配置，仅下标或容器变化时只更新拖拽数据，避免长列表移动物品后重复生成详情与视觉节点。
	# 实际数量；与完整配置保持相同的 1 至 99 堆叠范围，异常调用不会写入非法卡片状态。
	# 现行限制补充：正式范围已调整为 1 至 10，旧注释中的 99 仅表示历史兼容来源。
	var resolved_quantity: int = clampi(quantity, 1, INVENTORY_LIMITS.MAX_STACK_QUANTITY)
	if _item_resource != item_resource or _quantity != resolved_quantity or _extraction_prefix != extraction_prefix:
		configure(item_resource, location, item_index, quick_action_enabled, extraction_prefix, resolved_quantity)
		return
	_location = location
	_item_index = item_index
	_quick_action_enabled = quick_action_enabled
	# 鼠标指针形态；移动后按最新容器与下标恢复可操作状态，不重新创建悬停动画或详情控件。
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _location.is_empty() and _item_index >= 0 else Control.CURSOR_ARROW


func get_item_resource() -> Resource:
	## 返回当前卡片绑定的资源实例；库存面板通过实例身份复用节点，不得通过该引用直接修改物品所有权。
	return _item_resource


func set_enhancement_target_highlight(enabled: bool) -> void:
	_enhancement_target_highlight = enabled and _is_weapon_resource()
	_weapon_target_selection_active = _enhancement_target_highlight
	_weapon_target_selection_blocked = false
	_refresh_enhancement_target_highlight()


func set_weapon_target_selection_state(selection_active: bool, selectable: bool) -> void:
	# 武器选择状态；非武器卡片始终保持正常显示，避免资源卡片被目标选择滤镜误伤。
	_weapon_target_selection_active = selection_active and _is_weapon_resource()
	_enhancement_target_highlight = _weapon_target_selection_active and selectable
	_weapon_target_selection_blocked = _weapon_target_selection_active and not selectable
	_refresh_enhancement_target_highlight()


func set_item_selection_state(selection_active: bool, selectable: bool, highlight_selectable: bool = false) -> void:
	# 通用物品选择状态；与武器专用目标状态并行，适用于强化石、道具和武器的统一灰显与点击阻断。
	_item_selection_active = selection_active and _item_resource != null
	_item_selection_blocked = _item_selection_active and not selectable
	_item_selection_highlight = _item_selection_active and selectable and highlight_selectable
	_refresh_enhancement_target_highlight()


func set_drag_enabled(enabled: bool) -> void:
	# 拖拽开关只影响新的拖拽开始，不改变普通点击、悬停详情或已存在的物品所有权。
	_drag_enabled = enabled


func set_weapon_slot_visual_style(enabled: bool) -> void:
	_weapon_slot_visual_style_enabled = enabled
	_apply_weapon_slot_visual_style()
	if _stone_summary_label != null and (_is_enhancement_stone() or _is_repair_kit()):
		_stone_summary_label.text = _build_stone_card_bbcode("") if _is_enhancement_stone() else _build_repair_kit_card_bbcode("")
	_refresh_item_card_view()


func refresh_durability() -> void:
	if _item_card_view != null:
		_item_card_view.call("refresh_durability")
	_refresh_item_card_view()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _drag_enabled or _item_resource == null or _location.is_empty() or _item_index < 0 or _weapon_target_selection_blocked or _item_selection_blocked:
		return null

	# 拖拽预览标签；显示物品名称并跟随鼠标，避免复制完整交互控件造成信号副作用。
	# 通用交互补充：当前使用完整标准物品卡片预览，并统一播放来源淡化与预览呼吸摆动。
	var preview_control: Control = _item_card_view.call("create_drag_preview") as Control
	set_drag_preview(preview_control)
	_item_card_view.call("play_drag_source", self, true)
	_item_card_view.call("play_drag_preview", preview_control)
	_is_drag_source_active = true
	return {
		"type": DRAG_DATA_TYPE,
		"resource": _item_resource,
		"source_location": _location,
		"source_index": _item_index,
		"quantity": _quantity,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	# 拖拽字典；取值应由同类物品控件创建，类型和资源均合法时允许容器内排序或跨容器转移。
	var drag_data: Dictionary = data
	if str(drag_data.get("type", "")) != DRAG_DATA_TYPE or not (drag_data.get("resource") is Resource):
		return false
	# 拖拽资源；强化石不能再投放使用，修复包投放到武器卡片时走修复协议，其他组合保持原容器移动协议。
	var dragged_resource: Resource = drag_data.get("resource") as Resource
	if str(dragged_resource.get("item_kind")) == "enhancement_stone" and _is_weapon_resource():
		return false
	if str(dragged_resource.get("item_kind")) == "repair_kit" and _is_weapon_resource():
		return not str(drag_data.get("source_location", "")).is_empty() and not _location.is_empty() and _item_index >= 0
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	# 拖拽字典；已通过类型检查，复制后交给仓库面板决定移动或转移规则。
	var drag_data: Dictionary = (data as Dictionary).duplicate()
	# 拖拽资源；修复包命中武器时不改变容器位置，只由上层消费一件并恢复耐久。
	var dragged_resource: Resource = drag_data.get("resource") as Resource
	if dragged_resource != null and str(dragged_resource.get("item_kind")) == "repair_kit" and _is_weapon_resource():
		repair_kit_drop_requested.emit(dragged_resource, str(drag_data.get("source_location", "")), _item_resource)
		return
	item_drop_requested.emit(drag_data, _location, _item_index)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _is_drag_source_active:
		return
	# 拖拽结束恢复；无论投放成功或取消，都使用通用卡片动画恢复来源外观。
	_is_drag_source_active = false
	if _item_card_view != null:
		_item_card_view.call("play_drag_source", self, false)


func _on_pressed() -> void:
	if _item_resource == null or _weapon_target_selection_blocked or _item_selection_blocked:
		return
	# Shift 快速转移；只有展开背包模式启用，普通点击始终交给上层打开出售或使用菜单。
	if _quick_action_enabled and Input.is_key_pressed(KEY_SHIFT):
		quick_action_requested.emit(_item_resource)
	elif not _location.is_empty() and _item_index >= 0:
		item_action_requested.emit(_item_resource)


func _get_item_display_name() -> String:
	return str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", _item_resource))


func _get_weapon_type_label() -> String:
	if _item_resource == null:
		return "未知"
	return str(ITEM_DETAIL_FORMATTER.call("get_item_type_label", _item_resource))


func _get_item_value() -> int:
	return int(ITEM_DETAIL_FORMATTER.call("get_item_value", _item_resource))


func _get_displayed_price() -> int:
	if _displayed_price_override >= 0:
		return _displayed_price_override
	return _get_item_value() if _is_weapon_resource() else _get_item_value() * _quantity


func _build_item_details() -> String:
	return str(ITEM_DETAIL_FORMATTER.call("build_plain_text", _item_resource, _quantity))


func _make_custom_tooltip(_for_text: String) -> Object:
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", _item_resource, _quantity, _get_tooltip_price_label(), _get_tooltip_price_override())


func _get_tooltip_price_label() -> String:
	# 撤离卡片表面显示实际收费，悬停详情仍展示物品自身价值，便于玩家判断价值与运费关系。
	return "价值" if _price_label == "撤离收费" else _price_label


func _get_tooltip_price_override() -> int:
	# 撤离收费覆盖值只属于卡片摘要，详情回退资源自身价值；其他自定义数值继续按调用方覆盖显示。
	return -1 if _price_label == "撤离收费" else _displayed_price_override


func _is_enhancement_stone() -> bool:
	return _item_resource != null and str(_item_resource.get("item_kind")) == "enhancement_stone"


func _is_repair_kit() -> bool:
	return _item_resource != null and str(_item_resource.get("item_kind")) == "repair_kit"


func _is_weapon_resource() -> bool:
	# 武器式物品；四部位装备复用武器卡片排版、耐久条、灰色滤镜和拖拽反馈。
	return _item_resource != null and (str(_item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"] or str(_item_resource.get("item_kind")) == "equipment")


func _refresh_enhancement_target_highlight() -> void:
	# 卡片色调；浅绿色表示可点击或可投放的强化目标，取消选择后恢复白色不影响原主题。
	# 修复目标补充；当前不可选武器会优先使用灰色滤镜，可选武器继续使用浅绿色。
	var selection_blocked: bool = _weapon_target_selection_blocked or _item_selection_blocked
	if selection_blocked:
		modulate = Color.WHITE
	else:
		modulate = Color.WHITE
	if _target_filter_overlay != null:
		_target_filter_overlay.visible = false
	if _item_card_view != null:
		_item_card_view.call("set_visual_state", false, not selection_blocked and (_enhancement_target_highlight or _item_selection_highlight))
		_item_card_view.call("set_disabled_state", selection_blocked)
		if selection_blocked:
			_item_card_view.call("play_hover", self, false)
	_refresh_interaction_theme(selection_blocked)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if selection_blocked else (Control.CURSOR_POINTING_HAND if not _location.is_empty() and _item_index >= 0 else Control.CURSOR_ARROW)


func _refresh_interaction_theme(selection_blocked: bool) -> void:
	_apply_weapon_slot_visual_style()
	if not selection_blocked:
		return
	# 不可选卡片的悬停与按下样式完全复用普通样式，鼠标经过时不再变白或提亮。
	var normal_style: StyleBox = get_theme_stylebox("normal").duplicate()
	add_theme_stylebox_override("hover", normal_style.duplicate())
	add_theme_stylebox_override("pressed", normal_style.duplicate())


func _on_mouse_entered() -> void:
	if _item_card_view != null and _item_resource != null:
		_item_card_view.call("play_hover", self, true)


func _on_mouse_exited() -> void:
	if _item_card_view != null:
		_item_card_view.call("play_hover", self, false)


func _play_selection_hover_animation(target_scale: float) -> void:
	if _selection_hover_tween != null and _selection_hover_tween.is_valid():
		_selection_hover_tween.kill()
	pivot_offset = size * 0.5
	_selection_hover_tween = create_tween()
	_selection_hover_tween.tween_property(self, "scale", Vector2.ONE * target_scale, SELECTABLE_TARGET_HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _stop_selection_hover_animation(reset_immediately: bool) -> void:
	if _selection_hover_tween != null and _selection_hover_tween.is_valid():
		_selection_hover_tween.kill()
	_selection_hover_tween = null
	if reset_immediately:
		scale = Vector2.ONE


func _ensure_stone_summary_label() -> void:
	if _stone_summary_label != null:
		return
	# 方格富文本；覆盖按钮内部并忽略鼠标，让按钮继续负责点击、拖拽和 tooltip。
	_stone_summary_label = RichTextLabel.new()
	_stone_summary_label.bbcode_enabled = true
	_stone_summary_label.fit_content = true
	_stone_summary_label.scroll_active = false
	_stone_summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stone_summary_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stone_summary_label.offset_left = 6.0
	_stone_summary_label.offset_top = 5.0
	_stone_summary_label.offset_right = -6.0
	_stone_summary_label.offset_bottom = -5.0
	add_child(_stone_summary_label)
	_apply_weapon_slot_visual_style()


func _ensure_durability_bar() -> void:
	if _durability_bar != null:
		return
	_durability_bar = WEAPON_DURABILITY_BAR_SCRIPT.new() as Control
	add_child(_durability_bar)


func _ensure_item_card_view() -> void:
	if _item_card_view != null:
		return
	# 单一通用视图；交互按钮只作为点击与拖拽宿主，视觉内容完全交由固定尺寸模板绘制。
	_item_card_view = ITEM_CARD_VIEW_SCRIPT.new() as Control
	_item_card_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_item_card_view)


func _refresh_item_card_view() -> void:
	if _item_card_view == null:
		return
	# 名称文本；上次撤离等前缀与标准物品名组合后交给通用模板统一截断和居中。
	var display_name: String = "%s%s" % [_extraction_prefix, _get_item_display_name()]
	# 底部摘要；不同物品只提供数据文本，字号、位置、颜色承载与耐久组件均由通用模板控制。
	var detail_bbcode: String = _build_common_detail_bbcode()
	_item_card_view.call("configure", _item_resource, _quantity, _get_weapon_type_label(), detail_bbcode, "空", display_name)
	_item_card_view.call("set_visual_state", false, _enhancement_target_highlight or _item_selection_highlight)


func _build_common_detail_bbcode() -> String:
	if _is_enhancement_stone():
		# 强化石方向摘要；保留绿色增益与红色减益，但不再创建独立资源卡片布局。
		var modifiers: Dictionary = _item_resource.call("get_normalized_modifiers") as Dictionary if _item_resource.has_method("get_normalized_modifiers") else EnhancementRules.normalize_modifiers(_item_resource.get("modifiers") as Dictionary, str(_item_resource.get("quality_id")) == EnhancementRules.QUALITY_SPECIALIZED)
		# 彩色方向词条；顺序继续遵循强化规则目录，保证堆叠资源显示稳定。
		var colored_tokens: PackedStringArray = PackedStringArray()
		_append_colored_stone_tokens(colored_tokens, modifiers, true)
		_append_colored_stone_tokens(colored_tokens, modifiers, false)
		var stone_text: String = " ".join(colored_tokens) if not colored_tokens.is_empty() else "无词条"
		return "%s · %s %d" % [stone_text, _price_label, _get_displayed_price()] if not _weapon_slot_visual_style_enabled else stone_text
	if _is_repair_kit():
		# 修复包摘要；恢复值继续使用绿色，名称与数量统一由通用模板上方两行显示。
		var repair_amount: float = maxf(float(_item_resource.get("repair_amount")), 0.0)
		var repair_text: String = "[color=%s]耐久+%.0f[/color]" % [STONE_BENEFICIAL_COLOR, repair_amount]
		return "%s · %s %d" % [repair_text, _price_label, _get_displayed_price()] if not _weapon_slot_visual_style_enabled else repair_text
	return "%s %d" % [_price_label, _get_displayed_price()]


func _ensure_target_filter_overlay() -> void:
	if _target_filter_overlay != null:
		return
	# 完整灰色覆盖层；放在卡片全部内容之后并忽略鼠标，使底层按钮继续统一处理阻止逻辑与悬停详情。
	_target_filter_overlay = ColorRect.new()
	_target_filter_overlay.color = UNAVAILABLE_TARGET_FILTER_COLOR
	_target_filter_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_filter_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_target_filter_overlay.visible = false
	add_child(_target_filter_overlay)


func _apply_weapon_slot_visual_style() -> void:
	flat = false
	if not _weapon_slot_visual_style_enabled:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")
		return
	# 普通样式；颜色、边框宽度与 WeaponSlotControl 的绘制参数保持一致。
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.06, 0.075, 0.09, 0.92)
	normal_style.border_color = Color(0.22, 0.30, 0.36, 1.0)
	normal_style.set_border_width_all(2)
	# 悬停样式；在不改变整体深色风格的前提下提供鼠标反馈。
	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.09, 0.12, 0.15, 0.96)
	hover_style.border_color = Color(0.42, 0.72, 0.82, 1.0)
	# 按下样式；短暂加亮背景，保持与武器槽相同的紧凑边界。
	var pressed_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.12, 0.17, 0.20, 1.0)
	pressed_style.border_color = Color(0.55, 0.92, 1.0, 1.0)
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)


func _build_stone_card_bbcode(extraction_prefix: String) -> String:
	# 卡片文本行；名称、彩色方向词条、数量与整组价值固定居中显示。
	var card_lines: Array[String] = []
	if _weapon_slot_visual_style_enabled:
		card_lines.append("[center][font_size=12][b]%s%s[/b]  x%d[/font_size][/center]" % [extraction_prefix, _get_item_display_name(), _quantity])
	else:
		card_lines.append("[center][b]%s%s[/b]  x%d[/center]" % [extraction_prefix, _get_item_display_name(), _quantity])
	# 归一化词典；按规则目录顺序生成稳定且可堆叠识别的词条组合。
	var modifiers: Dictionary = _item_resource.call("get_normalized_modifiers") as Dictionary if _item_resource.has_method("get_normalized_modifiers") else EnhancementRules.normalize_modifiers(_item_resource.get("modifiers") as Dictionary, str(_item_resource.get("quality_id")) == EnhancementRules.QUALITY_SPECIALIZED)
	# 彩色词条；增强为绿色，削弱为红色，不显示具体百分比。
	# 品质化数值补充；当前卡片会直接显示每条实际百分比，上述颜色规则保持不变。
	# 方向化显示补充；当前卡片只显示属性与 +/-，具体百分比在使用时随机后由结果弹窗展示。
	var colored_tokens: PackedStringArray = PackedStringArray()
	_append_colored_stone_tokens(colored_tokens, modifiers, true)
	_append_colored_stone_tokens(colored_tokens, modifiers, false)
	if _weapon_slot_visual_style_enabled:
		card_lines.append("[center][font_size=9]%s[/font_size][/center]" % (" ".join(colored_tokens) if not colored_tokens.is_empty() else "无词条"))
	else:
		card_lines.append("[center]%s  ·  %s %d[/center]" % [(" ".join(colored_tokens) if not colored_tokens.is_empty() else "无词条"), _price_label, _get_displayed_price()])
	return "\n".join(card_lines)


func _build_repair_kit_card_bbcode(extraction_prefix: String) -> String:
	# 卡片文本行；道具与强化石使用相同的紧凑资源卡结构，仅将词条替换为固定耐久恢复效果。
	var card_lines: Array[String] = []
	if _weapon_slot_visual_style_enabled:
		card_lines.append("[center][font_size=12][b]%s%s[/b]  x%d[/font_size][/center]" % [extraction_prefix, _get_item_display_name(), _quantity])
	else:
		card_lines.append("[center][b]%s%s[/b]  x%d[/center]" % [extraction_prefix, _get_item_display_name(), _quantity])
	# 修复耐久；所有当前修复包使用整数数值，绿色明确表示该道具提供正向恢复效果。
	var repair_amount: float = maxf(float(_item_resource.get("repair_amount")), 0.0)
	var repair_text: String = "[color=%s]武器耐久+%.0f[/color]" % [STONE_BENEFICIAL_COLOR, repair_amount]
	card_lines.append("[center][font_size=9]%s[/font_size][/center]" % repair_text if _weapon_slot_visual_style_enabled else "[center]%s  ·  %s %d[/center]" % [repair_text, _price_label, _get_displayed_price()])
	return "\n".join(card_lines)


func _append_colored_stone_tokens(target_tokens: PackedStringArray, modifiers: Dictionary, beneficial: bool) -> void:
	# 属性顺序；先调用增强组再调用削弱组，保证任何强化石都按玩法利弊排列。
	for stat_name in EnhancementRules.STAT_KEYS:
		if not modifiers.has(stat_name):
			continue
		# 属性实际比例；值保留整数百分点精度，用于卡片直接显示强化幅度。
		var modifier_ratio: float = float(modifiers.get(stat_name, 0.0))
		if EnhancementRules.is_direction_beneficial(stat_name, modifier_ratio) != beneficial:
			continue
		# 词条颜色；严格按玩法利弊显示，降低型增益为绿色，增加型减益为红色。
		var color_code: String = STONE_BENEFICIAL_COLOR if beneficial else STONE_DETRIMENTAL_COLOR
		target_tokens.append("[color=%s]%s[/color]" % [color_code, EnhancementRules.build_modifier_token(stat_name, modifier_ratio, false)])
