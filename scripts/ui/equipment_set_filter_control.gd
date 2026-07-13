extends HBoxContainer
class_name EquipmentSetFilterControl

## 套装筛选控件为背包、仓库、商店与锻造提供统一的多选下拉框和清空入口。
## 控件只保存筛选 ID 并派发变化信号，具体物品匹配由 InventoryQuery 统一执行。

signal filters_changed(selected_set_ids: Array[String])

## 下拉框最小宽度；默认 148 像素，与强化石筛选控件保持接近的可读尺寸。
@export_range(100.0, 280.0, 1.0) var option_minimum_width: float = 148.0
## 控件最小高度；默认 34 像素，与共享背包查询栏高度一致。
@export_range(24.0, 64.0, 1.0) var control_minimum_height: float = 34.0

## 当前选中套装 ID；默认空数组表示显示全部装备，多项条件按并集匹配。
var _selected_set_ids: Array[String] = []
## 套装多选下拉框；首项显示已选数量，其余项按当前条目动态生成。
var _option_button: OptionButton
## 清空筛选按钮；无选中套装时禁用，避免无效果点击。
var _clear_button: Button
## 当前可用套装选项；默认空数组，控件进入树前收到配置时会暂存并在 ready 后构建。
var _available_options: Array[Dictionary] = []


func _ready() -> void:
	add_theme_constant_override("separation", 7)
	_option_button = OptionButton.new()
	_option_button.custom_minimum_size = Vector2(option_minimum_width, control_minimum_height)
	_option_button.get_popup().hide_on_checkable_item_selection = false
	_option_button.item_selected.connect(_on_item_selected)
	add_child(_option_button)
	_clear_button = Button.new()
	_clear_button.text = "清空套装"
	_clear_button.custom_minimum_size = Vector2(92.0, control_minimum_height)
	_clear_button.pressed.connect(clear_filters)
	add_child(_clear_button)
	_rebuild_options(_available_options)


func configure_entries(entries: Array) -> void:
	## 根据当前容器条目刷新可选套装；仍存在的已选 ID 保留，已不在列表中的条件自动移除。
	# 当前套装选项；由统一查询器完成去重和显示名排序。
	var options: Array[Dictionary] = InventoryQuery.collect_equipment_set_filter_options(entries)
	_available_options = options.duplicate(true)
	# 可用套装 ID；用于移除购买、转移或筛选后已经不存在的旧选择。
	var available_set_ids: Array[String] = []
	for option in options:
		available_set_ids.append(str(option.get("id", "")))
	for selected_index in range(_selected_set_ids.size() - 1, -1, -1):
		if _selected_set_ids[selected_index] not in available_set_ids:
			_selected_set_ids.remove_at(selected_index)
	_rebuild_options(_available_options)


func get_selected_set_ids() -> Array[String]:
	## 返回筛选 ID 副本；调用方不得修改控件内部选择状态。
	return _selected_set_ids.duplicate()


func clear_filters(emit_change: bool = true) -> void:
	## 清空全部套装筛选；分类切换可关闭信号后自行统一刷新，玩家点击时默认立即通知。
	_selected_set_ids.clear()
	_refresh_display()
	if emit_change:
		filters_changed.emit(get_selected_set_ids())


func _rebuild_options(options: Array[Dictionary]) -> void:
	## 重建动态套装选项并恢复勾选状态；首项只作为数量摘要，不参与筛选。
	if _option_button == null:
		return
	_option_button.clear()
	_option_button.add_item("套装筛选（%d）" % _selected_set_ids.size())
	_option_button.set_item_metadata(0, "")
	for option in options:
		# 套装稳定 ID；空 ID 不创建无效选项。
		var set_id: String = str(option.get("id", "")).strip_edges()
		if set_id.is_empty():
			continue
		_option_button.add_item(str(option.get("label", set_id)))
		# 新选项下标；用于保存稳定元数据并开启复选显示。
		var item_index: int = _option_button.item_count - 1
		_option_button.set_item_metadata(item_index, set_id)
		_option_button.get_popup().set_item_as_checkable(item_index, true)
	_refresh_display()


func _on_item_selected(item_index: int) -> void:
	if item_index <= 0:
		_option_button.select(0)
		return
	# 目标套装 ID；显示名变化不影响选择身份。
	var set_id: String = str(_option_button.get_item_metadata(item_index)).strip_edges()
	if set_id.is_empty():
		return
	# 新勾选状态；再次选择同项时取消，保持与强化石多选筛选一致。
	var should_select: bool = set_id not in _selected_set_ids
	if should_select:
		_selected_set_ids.append(set_id)
	else:
		_selected_set_ids.erase(set_id)
	_refresh_display()
	filters_changed.emit(get_selected_set_ids())


func _refresh_display() -> void:
	## 同步摘要文字、复选勾选和清空按钮状态，不触发外部查询刷新。
	if _option_button == null or _clear_button == null:
		return
	_option_button.set_item_text(0, "套装筛选（%d）" % _selected_set_ids.size())
	_option_button.select(0)
	for item_index in range(1, _option_button.item_count):
		# 当前选项 ID；非空选项根据内部数组恢复勾选。
		var set_id: String = str(_option_button.get_item_metadata(item_index))
		_option_button.get_popup().set_item_checked(item_index, set_id in _selected_set_ids)
	_clear_button.disabled = _selected_set_ids.is_empty()
