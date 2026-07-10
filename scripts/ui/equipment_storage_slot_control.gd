extends Button
class_name EquipmentStorageSlotControl

## 局外装备槽控件负责显示远程或近战槽、提供悬停详情，并在装备栏与仓库/背包之间生成和接收拖拽。
## 控件只验证武器类型并发出结构化请求，所有权交换由 GlobalInventory 原子接口完成。

signal item_drop_requested(drag_data: Dictionary, target_location: String, target_index: int)
signal item_selected(item_resource: Resource)
signal enhancement_drop_requested(stone_resource: Resource, source_location: String, weapon_resource: Resource)

## 拖拽数据类型标识；必须与 StorageItemControl 和 StorageDropArea 保持一致。
const DRAG_DATA_TYPE: String = "global_storage_item"
## 统一物品详情格式化器；装备槽悬停时显示武器基础值、强化差值和动态售价。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 武器耐久条组件；局外装备槽使用与战斗和仓库卡片相同的底部读条。
const WEAPON_DURABILITY_BAR_SCRIPT: Script = preload("res://scripts/ui/weapon_durability_bar.gd")

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
## 武器耐久条缓存；默认首次配置时创建，空槽隐藏，有武器时显示剩余耐久。
var _durability_bar: Control


func configure(slot_label: String, location: String, accepted_weapon_type: String, item_resource: Resource, detail_tooltip: String = "") -> void:
	_slot_label = slot_label
	_location = location
	_accepted_weapon_type = accepted_weapon_type
	_item_resource = item_resource
	_ensure_durability_bar()
	_durability_bar.call("configure", _item_resource)
	text = "%s：%s" % [_slot_label, _get_item_display_name()]
	tooltip_text = detail_tooltip if not detail_tooltip.is_empty() else ("拖入%s武器" % ("远程" if _accepted_weapon_type == "ranged" else "近战"))
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_DRAG if _item_resource != null else Control.CURSOR_POINTING_HAND
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_refresh_enhancement_target_highlight()


func set_enhancement_target_highlight(enabled: bool) -> void:
	_enhancement_target_highlight = enabled and _item_resource != null
	_refresh_enhancement_target_highlight()


func refresh_durability() -> void:
	if _durability_bar != null:
		_durability_bar.call("refresh")
	text = "%s：%s" % [_slot_label, _get_item_display_name()]


func _on_pressed() -> void:
	if _item_resource != null:
		item_selected.emit(_item_resource)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _item_resource == null or _location.is_empty():
		return null
	# 装备拖拽预览；只显示槽名和武器名，避免复制真实装备控件产生重复投放信号。
	var preview_label: Label = Label.new()
	preview_label.text = text
	preview_label.add_theme_font_size_override("font_size", 16)
	set_drag_preview(preview_label)
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
		return _item_resource != null and not str(drag_data.get("source_location", "")).is_empty()
	return dragged_resource != null and str(dragged_resource.get("weapon_type")) == _accepted_weapon_type


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	# 拖拽字典；复制后发给仓库面板，装备槽目标不使用列表下标所以固定为 -1。
	var drag_data: Dictionary = (data as Dictionary).duplicate()
	# 拖拽资源；强化石命中已装备武器时直接请求强化，不进入装备交换逻辑。
	var dragged_resource: Resource = drag_data.get("resource") as Resource
	if dragged_resource != null and str(dragged_resource.get("item_kind")) == "enhancement_stone":
		enhancement_drop_requested.emit(dragged_resource, str(drag_data.get("source_location", "")), _item_resource)
		return
	item_drop_requested.emit(drag_data, _location, -1)


func _get_item_display_name() -> String:
	if _item_resource == null:
		return "空"
	return str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", _item_resource))


func _make_custom_tooltip(_for_text: String) -> Object:
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", _item_resource, 1)


func _refresh_enhancement_target_highlight() -> void:
	# 装备槽色调；浅绿色明确表示当前可作为强化目标，取消后恢复原主题。
	self_modulate = Color(0.68, 1.0, 0.76, 1.0) if _enhancement_target_highlight else Color.WHITE


func _ensure_durability_bar() -> void:
	if _durability_bar != null:
		return
	_durability_bar = WEAPON_DURABILITY_BAR_SCRIPT.new() as Control
	add_child(_durability_bar)
