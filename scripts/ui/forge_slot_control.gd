extends Button
class_name ForgeSlotControl

## 锻造槽控件负责显示主物品或牺牲品，并验证仓库/背包通用拖拽协议。
## 单击已放入物品只发出归还请求，真实来源与所有权始终由锻造面板和 GlobalInventory 维护。

signal item_requested(slot_index: int, drag_data: Dictionary)
signal return_requested(slot_index: int)

## 仓库与背包物品拖拽类型；必须与 StorageItemControl 返回的数据一致。
const STORAGE_DRAG_DATA_TYPE: String = "global_storage_item"
## 物品详情格式化器；槽位悬停继续显示完整武器或强化石信息。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")

## 槽位下标；主锻造槽固定为 -1，周围牺牲槽使用 0 到 4。
var _slot_index: int = -1
## 是否为主锻造槽；主槽只接收武器，牺牲槽接收武器或强化石。
var _is_main_slot: bool = false
## 当前槽位条目；包含资源和来源位置，空字典表示尚未放入物品。
var _entry: Dictionary = {}


func configure(slot_index: int, is_main_slot: bool) -> void:
	_slot_index = slot_index
	_is_main_slot = is_main_slot
	custom_minimum_size = Vector2(138.0, 72.0) if is_main_slot else Vector2(124.0, 64.0)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	refresh({})


func refresh(entry: Dictionary) -> void:
	_entry = entry.duplicate()
	# 当前物品；空槽显示用途提示，有物品时显示名称与来源并允许单击快速归还。
	var item_resource: Resource = _entry.get("resource") as Resource
	if item_resource == null:
		text = "主锻造武器\n拖入或单击放入" if _is_main_slot else "牺牲品\n武器 / 强化石"
		tooltip_text = ""
		self_modulate = Color.WHITE
	else:
		# 来源名称；仓库和背包使用清晰中文，方便确认单击会回到哪里。
		var source_name: String = "仓库" if str(_entry.get("source_location", "")) == "warehouse" else "背包"
		text = "%s\n来源：%s" % [str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", item_resource)), source_name]
		tooltip_text = ITEM_DETAIL_FORMATTER.call("build_plain_text", item_resource, 1)
		self_modulate = Color(0.78, 0.95, 1.0, 1.0) if _is_main_slot else Color(1.0, 0.88, 0.66, 1.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func get_entry() -> Dictionary:
	return _entry.duplicate()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not _entry.is_empty():
		return false
	# 拖拽字典；只接受仓库与背包卡片生成的稳定协议。
	var drag_data: Dictionary = data as Dictionary
	if str(drag_data.get("type", "")) != STORAGE_DRAG_DATA_TYPE:
		return false
	# 拖拽物品；主槽只允许武器，牺牲槽允许武器和强化石。
	var item_resource: Resource = drag_data.get("resource") as Resource
	if item_resource == null:
		return false
	# 是否为武器；通过 weapon_type 识别，避免依赖具体 WeaponData 类。
	var is_weapon: bool = str(item_resource.get("weapon_type")) in ["ranged", "melee"]
	# 是否为强化石；当前唯一可锻造资源类型。
	var is_stone: bool = str(item_resource.get("item_kind")) == "enhancement_stone"
	return is_weapon if _is_main_slot else (is_weapon or is_stone)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	item_requested.emit(_slot_index, (data as Dictionary).duplicate())


func _on_pressed() -> void:
	if not _entry.is_empty():
		return_requested.emit(_slot_index)


func _make_custom_tooltip(_for_text: String) -> Object:
	# 当前槽位资源；空槽不会请求自定义提示，已放入物品复用仓库详情卡。
	var item_resource: Resource = _entry.get("resource") as Resource
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", item_resource, 1) if item_resource != null else null
