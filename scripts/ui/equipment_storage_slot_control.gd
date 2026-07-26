extends Button
class_name EquipmentStorageSlotControl

## 局外装备槽控件负责显示远程或近战槽、提供悬停详情，并在装备栏与仓库/背包之间生成和接收拖拽。
## 控件只验证武器类型并发出结构化请求，所有权交换由 GlobalInventory 原子接口完成。

signal item_drop_requested(drag_data: Dictionary, target_location: String, target_index: int)
signal item_selected(item_resource: Resource)
signal quick_unequip_requested
signal enhancement_drop_requested(stone_resource: Resource, source_location: String, weapon_resource: Resource)
signal repair_kit_drop_requested(repair_kit_resource: Resource, source_location: String, weapon_resource: Resource)

## 拖拽数据类型标识；必须与 StorageItemControl 和 StorageDropArea 保持一致。
const DRAG_DATA_TYPE: String = "global_storage_item"
## 统一物品详情格式化器；装备槽悬停时显示武器基础值、强化差值和动态价值。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 通用物品卡片视图；局外与战斗装备槽必须和背包、仓库、锻造、商店使用同一固定尺寸模板。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 武器耐久条组件；局外装备槽使用与战斗和仓库卡片相同的底部读条。
## 通用耐久补充：当前实际显示由 ItemCardView 内部按耐久属性决定。
const WEAPON_DURABILITY_BAR_SCRIPT: Script = preload("res://scripts/ui/weapon_durability_bar.gd")
## 不可选武器灰色滤镜；默认半透明灰黑层，与武器栏和物品卡片滤镜取值一致，保留武器名称和耐久信息可辨认。
const UNAVAILABLE_TARGET_FILTER_COLOR: Color = Color(0.16, 0.16, 0.16, 0.72)
## 可选装备悬停缩放；默认 1.03，仅在绿色修复目标状态中启用。
const TARGET_HOVER_SCALE: float = 1.03
## 可选装备悬停动画时长；默认 0.12 秒，进入和退出共用。
const TARGET_HOVER_DURATION: float = 0.12

## 当前装备资源；默认 null 表示空槽，空槽可以接收兼容武器但不能作为拖拽来源。
var _item_resource: Resource
## 当前装备位置；取值为 ranged_0、ranged_1 或 melee，默认空字符串表示尚未配置。
var _location: String = ""
## 当前槽位显示名称；默认“装备槽”，用于空槽和有装备时的摘要文本。
var _slot_label: String = "装备槽"
## 当前槽位接收武器类型；取值为 ranged 或 melee，默认 ranged。
var _accepted_weapon_type: String = "ranged"
## 是否将当前装备标记为强化目标；默认 false，使用强化石期间会点亮所有非空装备槽。
var _enhancement_target_highlight: bool = false
## 当前装备是否处于目标选择但不可选择状态；默认 false，满耐久武器在修复包选择期间会启用灰色滤镜。
var _weapon_target_selection_blocked: bool = false
## 武器耐久条缓存；默认首次配置时创建，空槽隐藏，有武器时显示剩余耐久。
## 通用模板补充：该缓存仅保留旧接口兼容，当前可见耐久条由 _item_card_view 承担。
var _durability_bar: Control
## 当前目标悬停补间；默认 null，用于避免连续悬停产生重复缩放。
var _target_hover_tween: Tween
## 通用物品卡片视图缓存；默认首次配置时创建，承担槽位职责、名称、类型、固定尺寸与耐久显示。
var _item_card_view: Control
## 当前装备槽是否正在作为拖拽来源；默认 false，拖拽结束时统一恢复卡片比例与透明度。
var _is_drag_source_active: bool = false


func configure(slot_label: String, location: String, accepted_weapon_type: String, item_resource: Resource, detail_tooltip: String = "") -> void:
	_slot_label = slot_label
	_location = location
	_accepted_weapon_type = accepted_weapon_type
	_item_resource = item_resource
	_ensure_item_card_view()
	text = ""
	var accepted_label: String = {"ranged": "远程武器", "melee": "近战武器", "head": "头部装备", "body": "躯干装备", "legs": "腿部装备", "feet": "脚部装备"}.get(_accepted_weapon_type, "物品")
	# 装备槽摘要；有物品时显示其统一类型，空槽时提示可接收类型，排版始终由通用模板负责。
	var detail_text: String = str(ITEM_DETAIL_FORMATTER.call("get_item_type_label", _item_resource)) if _item_resource != null else "拖入%s" % accepted_label
	_item_card_view.call("configure", _item_resource, 1, _slot_label, detail_text, "空", _get_item_display_name())
	_item_card_view.call("set_visual_state", false, _enhancement_target_highlight)
	tooltip_text = detail_tooltip if not detail_tooltip.is_empty() else "拖入%s" % accepted_label
	disabled = false
	custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_DRAG if _item_resource != null else Control.CURSOR_POINTING_HAND
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_refresh_enhancement_target_highlight()


func set_enhancement_target_highlight(enabled: bool) -> void:
	_enhancement_target_highlight = enabled and _item_resource != null
	_weapon_target_selection_blocked = false
	_refresh_enhancement_target_highlight()


func set_weapon_target_selection_state(selection_active: bool, selectable: bool) -> void:
	# 目标选择状态；空装备槽不参与可用或不可用表现，只有真实武器会被高亮或置灰。
	var has_weapon: bool = _item_resource != null and (str(_item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"] or str(_item_resource.get("item_kind")) == "equipment")
	_enhancement_target_highlight = selection_active and selectable and has_weapon
	_weapon_target_selection_blocked = selection_active and not selectable and has_weapon
	_refresh_enhancement_target_highlight()


func refresh_durability() -> void:
	if _item_card_view != null:
		_item_card_view.call("refresh_durability")
		var detail_text: String = str(ITEM_DETAIL_FORMATTER.call("get_item_type_label", _item_resource)) if _item_resource != null else ""
		_item_card_view.call("configure", _item_resource, 1, _slot_label, detail_text, "空", _get_item_display_name())


func _on_pressed() -> void:
	if _item_resource != null and not _weapon_target_selection_blocked:
		# Shift 快速卸下；强化石或修复包目标选择期间保持普通选择，避免快捷键绕过道具使用流程。
		if Input.is_key_pressed(KEY_SHIFT) and not _enhancement_target_highlight:
			quick_unequip_requested.emit()
		else:
			item_selected.emit(_item_resource)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _item_resource == null or _location.is_empty() or _weapon_target_selection_blocked:
		return null
	# 装备拖拽预览；只显示槽名和武器名，避免复制真实装备控件产生重复投放信号。
	# 通用交互补充：当前统一复制完整标准物品卡片，并播放相同来源淡化与预览呼吸动效。
	var preview_control: Control = _item_card_view.call("create_drag_preview") as Control
	set_drag_preview(preview_control)
	_item_card_view.call("play_drag_source", self, true)
	_item_card_view.call("play_drag_preview", preview_control)
	_is_drag_source_active = true
	return {
		"type": DRAG_DATA_TYPE,
		"resource": _item_resource,
		"source_location": _location,
		"source_index": -1,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _location.is_empty() or not (data is Dictionary):
		return false
	# 拖拽字典；取值必须来自局外存储协议，并携带与当前槽位类型一致的武器资源。
	var drag_data: Dictionary = data
	if str(drag_data.get("type", "")) != DRAG_DATA_TYPE:
		return false
	# 拖拽物品资源；取值为 WeaponData 或兼容 Resource，类型字段决定能否投放。
	var dragged_resource: Resource = drag_data.get("resource") as Resource
	if dragged_resource != null and str(dragged_resource.get("item_kind")) == "enhancement_stone":
		return false
	if dragged_resource != null and str(dragged_resource.get("item_kind")) == "repair_kit":
		return _item_resource != null and not str(drag_data.get("source_location", "")).is_empty()
	if dragged_resource == null:
		return false
	if _accepted_weapon_type in ["ranged", "melee"]:
		return str(dragged_resource.get("weapon_type")) in [_accepted_weapon_type, "hybrid"]
	return str(dragged_resource.get("item_kind")) == "equipment" and str(dragged_resource.get("equipment_slot")) == _accepted_weapon_type


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	# 拖拽字典；复制后发给仓库面板，装备槽目标不使用列表下标所以固定为 -1。
	var drag_data: Dictionary = (data as Dictionary).duplicate()
	# 拖拽资源；修复包命中已装备武器时直接请求修复，不进入装备交换逻辑。
	var dragged_resource: Resource = drag_data.get("resource") as Resource
	if dragged_resource != null and str(dragged_resource.get("item_kind")) == "repair_kit":
		repair_kit_drop_requested.emit(dragged_resource, str(drag_data.get("source_location", "")), _item_resource)
		return
	item_drop_requested.emit(drag_data, _location, -1)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _is_drag_source_active:
		return
	# 拖拽结束恢复；成功投放和取消投放都使用统一通用卡片恢复动画。
	_is_drag_source_active = false
	if _item_card_view != null:
		_item_card_view.call("play_drag_source", self, false)


func _get_item_display_name() -> String:
	if _item_resource == null:
		return "空"
	return str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", _item_resource))


func _make_custom_tooltip(_for_text: String) -> Object:
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", _item_resource, 1)


func _refresh_enhancement_target_highlight() -> void:
	# 装备槽色调；浅绿色明确表示当前可作为强化目标，取消后恢复原主题。
	# 修复目标补充；当前不可选武器会优先应用灰色滤镜，可选武器继续沿用浅绿色反馈。
	if _weapon_target_selection_blocked:
		modulate = Color.WHITE
	else:
		modulate = Color.WHITE
	if _item_card_view != null:
		_item_card_view.call("set_visual_state", false, _enhancement_target_highlight and not _weapon_target_selection_blocked)
		_item_card_view.call("set_disabled_state", _weapon_target_selection_blocked)
		if _weapon_target_selection_blocked:
			_item_card_view.call("play_hover", self, false)
	_refresh_disabled_hover_style()


func _refresh_disabled_hover_style() -> void:
	remove_theme_stylebox_override("hover")
	remove_theme_stylebox_override("pressed")
	if not _weapon_target_selection_blocked:
		return
	# 禁用悬停样式；满耐久等不可选装备经过鼠标时保持原始灰色外观。
	var normal_style: StyleBox = get_theme_stylebox("normal").duplicate()
	add_theme_stylebox_override("hover", normal_style.duplicate())
	add_theme_stylebox_override("pressed", normal_style.duplicate())


func _on_mouse_entered() -> void:
	if _item_card_view != null and _item_resource != null:
		_item_card_view.call("play_hover", self, true)


func _on_mouse_exited() -> void:
	if _item_card_view != null:
		_item_card_view.call("play_hover", self, false)


func _play_target_hover(target_scale: float) -> void:
	if _target_hover_tween != null and _target_hover_tween.is_valid():
		_target_hover_tween.kill()
	pivot_offset = size * 0.5
	_target_hover_tween = create_tween()
	_target_hover_tween.tween_property(self, "scale", Vector2.ONE * target_scale, TARGET_HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _stop_target_hover(reset_immediately: bool) -> void:
	if _target_hover_tween != null and _target_hover_tween.is_valid():
		_target_hover_tween.kill()
	_target_hover_tween = null
	if reset_immediately:
		scale = Vector2.ONE


func _ensure_durability_bar() -> void:
	if _durability_bar != null:
		return
	_durability_bar = WEAPON_DURABILITY_BAR_SCRIPT.new() as Control
	add_child(_durability_bar)


func _ensure_item_card_view() -> void:
	if _item_card_view != null:
		return
	# 装备按钮只保留投放、卸下与选择协议，全部可见内容统一复用固定尺寸物品模板。
	_item_card_view = ITEM_CARD_VIEW_SCRIPT.new() as Control
	_item_card_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_item_card_view)
