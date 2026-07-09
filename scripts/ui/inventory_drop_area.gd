extends ScrollContainer
class_name InventoryDropArea

## 背包投放区域负责接收拖到背包空白处的武器。
## 具体装备、卸下和排序逻辑仍由 CombatHud 处理，本控件只校验拖拽数据并转发信号。

signal drop_received(drop_data: Dictionary)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false

	# 拖拽字典；取值来自 WeaponSlotControl，默认包含来源上下文和武器资源，修改会影响空白区域投放校验。
	var drop_data: Dictionary = data as Dictionary
	if not drop_data.has("weapon_data") or not (drop_data["weapon_data"] is Resource):
		return false

	# 拖拽来源上下文；取值为 equipment 或 inventory，默认空字符串表示非法来源，修改会影响背包空白区域可接收来源。
	var source_context: String = str(drop_data.get("source_context", ""))
	return source_context == "equipment" or source_context == "inventory"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return

	# 投放数据；取值来自拖拽源，默认完整转发给 HUD，修改会影响背包空白投放目标解析。
	var drop_data: Dictionary = data as Dictionary
	drop_received.emit(drop_data)
