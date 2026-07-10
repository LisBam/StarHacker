extends Button
class_name StorageItemControl

## 仓库物品控件统一承担物品摘要、悬停详情、快捷点击和拖拽数据生成。
## 控件不直接修改全局物品所有权，所有操作通过信号交给仓库面板调用 GlobalInventory 接口。

signal quick_action_requested(item_resource: Resource)
signal item_drop_requested(drag_data: Dictionary, target_location: String, target_index: int)

## 拖拽数据类型标识；默认用于拒绝来自其他 UI 系统的不兼容拖拽数据。
const DRAG_DATA_TYPE: String = "global_storage_item"

## 当前显示的物品资源；默认 null 表示尚未配置，配置后用于摘要、详情和拖拽身份校验。
var _item_resource: Resource
## 当前物品所在容器；取值为 warehouse 或 backpack，默认空字符串表示不可拖拽。
var _location: String = ""
## 当前物品展示索引；取值大于等于 0，默认 -1 表示没有合法排序位置。
var _item_index: int = -1
## 是否允许左键快捷操作；默认 false，纯仓库模式只浏览和出售，展开背包后才启用容器互转。
var _quick_action_enabled: bool = false


func configure(item_resource: Resource, location: String, item_index: int, quick_action_enabled: bool, extraction_prefix: String = "") -> void:
	_item_resource = item_resource
	_location = location
	_item_index = item_index
	_quick_action_enabled = quick_action_enabled
	text = "%s%s · %s · 售价 %d" % [extraction_prefix, _get_item_display_name(), _get_weapon_type_label(), _get_sell_price()]
	tooltip_text = _build_item_details()
	disabled = _item_resource == null
	# 鼠标指针形态；快捷点击使用手型，可拖拽容器使用拖拽形态，结算只读条目使用普通箭头。
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _quick_action_enabled else (Control.CURSOR_DRAG if not _location.is_empty() and _item_index >= 0 else Control.CURSOR_ARROW)
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
	if _quick_action_enabled and _item_resource != null:
		quick_action_requested.emit(_item_resource)


func _get_item_display_name() -> String:
	if _item_resource == null:
		return "未知物品"
	# 物品显示名称；优先使用 display_name，空值时回退稳定 weapon_id。
	var display_name: String = str(_item_resource.get("display_name"))
	return str(_item_resource.get("weapon_id")) if display_name.is_empty() else display_name


func _get_weapon_type_label() -> String:
	if _item_resource == null:
		return "未知"
	return "远程" if str(_item_resource.get("weapon_type")) == "ranged" else "近战"


func _get_sell_price() -> int:
	return maxi(int(_item_resource.get("sell_price")) if _item_resource != null else 0, 0)


func _build_item_details() -> String:
	if _item_resource == null:
		return "物品数据不可用"

	# 详情文本行；按物品类型组合通用字段和远近程专属战斗属性，供鼠标悬停直接阅读。
	var detail_lines: Array[String] = []
	detail_lines.append(_get_item_display_name())
	detail_lines.append("类型：%s" % _get_weapon_type_label())
	detail_lines.append("出售价格：%d 金币" % _get_sell_price())
	# 武器说明；空字符串时显示统一兜底说明，避免悬停详情出现无意义空行。
	var description: String = str(_item_resource.get("description"))
	detail_lines.append("说明：%s" % ("暂无说明" if description.is_empty() else description))
	detail_lines.append("能量消耗：%.1f" % float(_item_resource.get("energy_cost")))
	if str(_item_resource.get("weapon_type")) == "ranged":
		detail_lines.append("远程伤害：%.1f" % float(_item_resource.get("ranged_damage")))
		detail_lines.append("射击冷却：%.2f 秒" % float(_item_resource.get("ranged_cooldown")))
		detail_lines.append("弹体射程：%.1f" % float(_item_resource.get("bullet_range")))
		detail_lines.append("弹体速度：%.1f" % float(_item_resource.get("projectile_speed")))
	else:
		detail_lines.append("近战伤害：%.1f" % float(_item_resource.get("melee_damage")))
		detail_lines.append("近战冷却：%.2f 秒" % float(_item_resource.get("melee_cooldown")))
		detail_lines.append("判定时长：%.2f 秒" % float(_item_resource.get("melee_active_duration")))
	detail_lines.append("后坐力：%.1f" % float(_item_resource.get("recoil_force")))
	detail_lines.append("前坐力：%.1f" % float(_item_resource.get("front_recoil_force")))
	detail_lines.append("冲击力：%.1f" % float(_item_resource.get("impact_force")))
	return "\n".join(detail_lines)
