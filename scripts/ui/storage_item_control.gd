extends Button
class_name StorageItemControl

## 仓库物品控件统一承担物品摘要、悬停详情、快捷点击和拖拽数据生成。
## 控件不直接修改全局物品所有权，所有操作通过信号交给仓库面板调用 GlobalInventory 接口。

signal quick_action_requested(item_resource: Resource)
signal item_action_requested(item_resource: Resource)
signal item_drop_requested(drag_data: Dictionary, target_location: String, target_index: int)

## 拖拽数据类型标识；默认用于拒绝来自其他 UI 系统的不兼容拖拽数据。
const DRAG_DATA_TYPE: String = "global_storage_item"
## 统一物品详情格式化器；默认生成基础值、强化值、资源词条和动态售价信息。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")

## 当前显示的物品资源；默认 null 表示尚未配置，配置后用于摘要、详情和拖拽身份校验。
var _item_resource: Resource
## 当前物品所在容器；取值为 warehouse 或 backpack，默认空字符串表示不可拖拽。
var _location: String = ""
## 当前物品展示索引；取值大于等于 0，默认 -1 表示没有合法排序位置。
var _item_index: int = -1
## 是否允许左键快捷操作；默认 false，纯仓库模式只浏览和出售，展开背包后才启用容器互转。
var _quick_action_enabled: bool = false
## 当前堆叠数量；武器固定为 1，强化石取值 1 到 99，修改会影响卡片数量角标和整组售价。
var _quantity: int = 1


func configure(item_resource: Resource, location: String, item_index: int, quick_action_enabled: bool, extraction_prefix: String = "", quantity: int = 1) -> void:
	_item_resource = item_resource
	_location = location
	_item_index = item_index
	_quick_action_enabled = quick_action_enabled
	_quantity = clampi(quantity, 1, 99)
	# 物品摘要；资源使用方形卡片并显示堆叠数，武器保持两列宽卡片显示分类和动态售价。
	text = "%s%s\n%s\nx%d · 售价 %d" % [extraction_prefix, _get_item_display_name(), _get_weapon_type_label(), _quantity, _get_sell_price() * _quantity] if _is_enhancement_stone() else "%s%s · %s · 售价 %d" % [extraction_prefix, _get_item_display_name(), _get_weapon_type_label(), _get_sell_price()]
	tooltip_text = ITEM_DETAIL_FORMATTER.call("build_plain_text", _item_resource, _quantity)
	disabled = _item_resource == null
	custom_minimum_size = Vector2(132.0, 112.0) if _is_enhancement_stone() else Vector2(0.0, 48.0)
	# 鼠标指针形态；可操作容器使用手型，结算只读条目使用普通箭头。
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _location.is_empty() and _item_index >= 0 else Control.CURSOR_ARROW
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _item_resource == null or _location.is_empty() or _item_index < 0:
		return null

	# 拖拽预览标签；显示物品名称并跟随鼠标，避免复制完整交互控件造成信号副作用。
	var preview_label: Label = Label.new()
	preview_label.text = _get_item_display_name()
	preview_label.add_theme_font_size_override("font_size", 16)
	set_drag_preview(preview_label)
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
	return str(drag_data.get("type", "")) == DRAG_DATA_TYPE and drag_data.get("resource") is Resource


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	# 拖拽字典；已通过类型检查，复制后交给仓库面板决定移动或转移规则。
	var drag_data: Dictionary = (data as Dictionary).duplicate()
	item_drop_requested.emit(drag_data, _location, _item_index)


func _on_pressed() -> void:
	if _item_resource == null:
		return
	# Shift 快速转移；只有展开背包模式启用，普通点击始终交给上层打开出售或使用菜单。
	if _quick_action_enabled and Input.is_key_pressed(KEY_SHIFT):
		quick_action_requested.emit(_item_resource)
	elif not _location.is_empty() and _item_index >= 0:
		item_action_requested.emit(_item_resource)


func _get_item_display_name() -> String:
	if _item_resource == null:
		return "未知物品"
	# 物品显示名称；优先使用 display_name，空值时回退稳定 weapon_id。
	var display_name: String = str(_item_resource.get("display_name"))
	return str(_item_resource.get("weapon_id")) if display_name.is_empty() else display_name


func _get_weapon_type_label() -> String:
	if _item_resource == null:
		return "未知"
	return str(ITEM_DETAIL_FORMATTER.call("get_item_type_label", _item_resource))


func _get_sell_price() -> int:
	return int(ITEM_DETAIL_FORMATTER.call("get_item_sell_price", _item_resource))


func _build_item_details() -> String:
	return str(ITEM_DETAIL_FORMATTER.call("build_plain_text", _item_resource, _quantity))


func _make_custom_tooltip(_for_text: String) -> Object:
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", _item_resource, _quantity)


func _is_enhancement_stone() -> bool:
	return _item_resource != null and str(_item_resource.get("item_kind")) == "enhancement_stone"
