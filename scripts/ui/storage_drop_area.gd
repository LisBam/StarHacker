extends PanelContainer
class_name StorageDropArea

## 存储拖放区域负责接收物品落到列表空白处的操作，并向上层报告目标容器。
## 区域只验证通用拖拽协议，不直接依赖 GlobalInventory，便于仓库和背包列表共同复用。

signal item_drop_requested(drag_data: Dictionary, target_location: String, target_index: int)

## 拖拽数据类型标识；必须与 StorageItemControl 保持一致，默认拒绝其他 UI 数据。
const DRAG_DATA_TYPE: String = "global_storage_item"

## 当前区域容器标识；取值为 warehouse 或 backpack，默认空字符串表示尚未配置。
var _location: String = ""
## 区域内部网格容器；默认两列显示物品卡片，供上层添加物品和空状态控件。
var _content_container: GridContainer


func configure(location: String, column_count: int = 2) -> void:
	_location = location
	if _content_container != null:
		return

	# 区域内容边距；默认让物品行与面板边缘保持稳定留白，并保留可接收拖拽的空白区域。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(margin)

	_content_container = GridContainer.new()
	_content_container.columns = maxi(column_count, 1)
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("h_separation", 8)
	_content_container.add_theme_constant_override("v_separation", 8)
	_content_container.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(_content_container)


func get_content_container() -> GridContainer:
	return _content_container


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _location.is_empty() or not (data is Dictionary):
		return false
	# 拖拽字典；取值应由 StorageItemControl 创建，资源合法时允许落到列表末尾。
	var drag_data: Dictionary = data
	return str(drag_data.get("type", "")) == DRAG_DATA_TYPE and drag_data.get("resource") is Resource


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	# 拖拽字典；复制后发出，目标索引 -1 表示追加并使用容器默认排序规则。
	var drag_data: Dictionary = (data as Dictionary).duplicate()
	item_drop_requested.emit(drag_data, _location, -1)
