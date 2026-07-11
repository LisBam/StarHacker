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
## 锻造槽允许的最小边长；默认 48 像素，用于保护外部调用传入异常小尺寸时的文字与投放区域可用性。
const MINIMUM_SLOT_SIZE: float = 48.0

## 槽位下标；主锻造槽固定为 -1，周围牺牲槽使用 0 到 4。
var _slot_index: int = -1
## 是否为主锻造槽；主槽只接收武器，牺牲槽接收武器或强化石。
var _is_main_slot: bool = false
## 当前槽位条目；包含资源和来源位置，空字典表示尚未放入物品。
var _entry: Dictionary = {}
## 当前槽位物品是否不符合主物品锻造规则；默认 false，启用时显示红色滤镜但仍允许点击归还。
var _is_invalid: bool = false
## 槽位普通样式缓存；默认在 configure 创建，用于无效材料禁用悬停提亮。
var _normal_style: StyleBoxFlat
## 槽位悬停样式缓存；默认在 configure 创建，合法槽位继续使用轻微提亮反馈。
var _hover_style: StyleBoxFlat
## 槽位按下样式缓存；默认在 configure 创建，合法槽位继续使用按下反馈。
var _pressed_style: StyleBoxFlat


func configure(slot_index: int, is_main_slot: bool, slot_size: float = 84.0) -> void:
	_slot_index = slot_index
	_is_main_slot = is_main_slot
	# 槽位尺寸；由锻造面板统一配置，主槽和牺牲槽保持一致以维持环形布局的视觉平衡。
	var resolved_slot_size: float = maxf(slot_size, MINIMUM_SLOT_SIZE)
	custom_minimum_size = Vector2.ONE * resolved_slot_size
	# 槽位基础样式；六个槽位统一正方形深色底与白色边框，主槽与牺牲槽仅通过位置区分职责。
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(0.06, 0.075, 0.09, 0.94)
	_normal_style.border_color = Color.WHITE
	_normal_style.set_border_width_all(2)
	_normal_style.set_corner_radius_all(4)
	# 槽位悬停样式；保留白色边框并轻微提亮背景，便于确认可点击归还操作。
	_hover_style = _normal_style.duplicate() as StyleBoxFlat
	_hover_style.bg_color = Color(0.13, 0.17, 0.21, 0.98)
	# 槽位按下样式；保持边框不变，避免锻造区视觉层级随点击发生跳变。
	_pressed_style = _normal_style.duplicate() as StyleBoxFlat
	_pressed_style.bg_color = Color(0.18, 0.22, 0.26, 1.0)
	_refresh_interaction_styles()
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	refresh({})


func refresh(entry: Dictionary) -> void:
	_entry = entry.duplicate()
	# 当前物品；空槽不显示文字，有物品时只显示名称并允许单击快速归还。
	var item_resource: Resource = _entry.get("resource") as Resource
	if item_resource == null:
		text = ""
		tooltip_text = ""
		self_modulate = Color.WHITE
	else:
		# 物品名称；槽位保持简洁，仅展示已放入材料的名称，完整来源和属性仍可通过悬停查看。
		text = str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", item_resource))
		tooltip_text = ITEM_DETAIL_FORMATTER.call("build_plain_text", item_resource, 1)
		self_modulate = Color(1.0, 0.28, 0.28, 0.92) if _is_invalid else (Color(0.78, 0.95, 1.0, 1.0) if _is_main_slot else Color(1.0, 0.88, 0.66, 1.0))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_invalid_state(is_invalid: bool) -> void:
	# 无效状态只改变当前槽位视觉与提示，不禁用按钮，玩家仍可单击移除红色材料。
	_is_invalid = is_invalid
	_refresh_interaction_styles()
	refresh(_entry)


func _refresh_interaction_styles() -> void:
	if _normal_style == null:
		return
	add_theme_stylebox_override("normal", _normal_style)
	# 红色无效材料仍允许点击归还，但 hover 和 pressed 不再提亮为可锻造状态。
	add_theme_stylebox_override("hover", _normal_style if _is_invalid else _hover_style)
	add_theme_stylebox_override("pressed", _normal_style if _is_invalid else _pressed_style)


func get_entry() -> Dictionary:
	return _entry.duplicate()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not _entry.is_empty():
		return false
	# 拖拽字典；只接受仓库与背包卡片生成的稳定协议。
	var drag_data: Dictionary = data as Dictionary
	if str(drag_data.get("type", "")) != STORAGE_DRAG_DATA_TYPE:
		return false
	# 拖拽物品；主槽允许武器、装备或强化石，牺牲槽先接受三类锻造物品，再由面板结合主物品做精确校验。
	var item_resource: Resource = drag_data.get("resource") as Resource
	if item_resource == null:
		return false
	# 是否为武器；通过 weapon_type 识别，避免依赖具体 WeaponData 类。
	var is_weapon: bool = str(item_resource.get("weapon_type")) in ["ranged", "melee"]
	# 是否为装备；四个固定部位都属于可恢复耐久和接受装备强化石的锻造目标。
	var is_equipment: bool = str(item_resource.get("item_kind")) == "equipment"
	# 是否为强化石；当前唯一可锻造资源类型。
	var is_stone: bool = str(item_resource.get("item_kind")) == "enhancement_stone"
	return is_weapon or is_equipment or is_stone


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
