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
## 统一物品详情格式化器；默认生成基础值、强化值、资源词条和动态售价信息。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 强化词条增强颜色；默认亮绿色，与悬停详情保持一致。
const STONE_BENEFICIAL_COLOR: String = "#70e889"
## 强化词条削弱颜色；默认亮红色，与悬停详情保持一致。
const STONE_DETRIMENTAL_COLOR: String = "#ff7070"
## 不可选武器灰色滤镜；默认降低亮度和饱和度，用于修复包目标选择期间明确区分满耐久武器。
const UNAVAILABLE_TARGET_FILTER_COLOR: Color = Color(0.42, 0.42, 0.42, 0.78)
## 武器耐久条组件；用于仓库、展开背包和结算卡片统一显示武器剩余耐久。
const WEAPON_DURABILITY_BAR_SCRIPT: Script = preload("res://scripts/ui/weapon_durability_bar.gd")

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
## 强化石卡片富文本；默认运行时按需创建，用于在方形资源格内直接区分绿色增强与红色削弱词条。
## 宽卡布局补充；强化石已与武器统一为宽卡片，该富文本仅负责品质、百分比和利弊颜色。
var _stone_summary_label: RichTextLabel
## 是否将当前武器标记为强化目标；默认 false，选择强化武器期间会临时点亮所有武器卡片。
var _enhancement_target_highlight: bool = false
## 当前是否处于武器目标选择状态；默认 false，启用后会同时管理可选高亮和不可选灰色滤镜。
var _weapon_target_selection_active: bool = false
## 当前武器是否因目标条件不满足而禁止选择；默认 false，修复包选择期间满耐久武器会设为 true。
var _weapon_target_selection_blocked: bool = false
## 是否采用战斗武器槽视觉；默认 false 保持仓库宽卡布局，战斗背包开启后会同步深色背景、边框和三行排版。
var _weapon_slot_visual_style_enabled: bool = false
## 武器耐久条缓存；默认按需创建，资源卡片隐藏，武器卡片始终贴在 UI 最底部。
var _durability_bar: Control


func configure(item_resource: Resource, location: String, item_index: int, quick_action_enabled: bool, extraction_prefix: String = "", quantity: int = 1) -> void:
	_item_resource = item_resource
	_location = location
	_item_index = item_index
	_quick_action_enabled = quick_action_enabled
	_quantity = clampi(quantity, 1, 99)
	# 物品摘要；强化石和修复包共用紧凑富文本资源卡，武器保持两列宽卡片显示分类和动态售价。
	if _is_enhancement_stone() or _is_repair_kit():
		text = ""
		_ensure_stone_summary_label()
		_stone_summary_label.visible = true
		_stone_summary_label.text = _build_stone_card_bbcode(extraction_prefix) if _is_enhancement_stone() else _build_repair_kit_card_bbcode(extraction_prefix)
	else:
		text = "%s%s · %s · 售价 %d" % [extraction_prefix, _get_item_display_name(), _get_weapon_type_label(), _get_sell_price()]
		if _stone_summary_label != null:
			_stone_summary_label.visible = false
	_ensure_durability_bar()
	_durability_bar.call("configure", _item_resource)
	tooltip_text = ITEM_DETAIL_FORMATTER.call("build_plain_text", _item_resource, _quantity)
	disabled = _item_resource == null
	custom_minimum_size = Vector2(0.0, 48.0)
	# 鼠标指针形态；可操作容器使用手型，结算只读条目使用普通箭头。
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _location.is_empty() and _item_index >= 0 else Control.CURSOR_ARROW
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_refresh_enhancement_target_highlight()


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


func set_weapon_slot_visual_style(enabled: bool) -> void:
	_weapon_slot_visual_style_enabled = enabled
	_apply_weapon_slot_visual_style()
	if _stone_summary_label != null and (_is_enhancement_stone() or _is_repair_kit()):
		_stone_summary_label.text = _build_stone_card_bbcode("") if _is_enhancement_stone() else _build_repair_kit_card_bbcode("")


func refresh_durability() -> void:
	if _durability_bar != null:
		_durability_bar.call("refresh")
	if _is_weapon_resource():
		text = "%s · %s · 售价 %d" % [_get_item_display_name(), _get_weapon_type_label(), _get_sell_price()]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _item_resource == null or _location.is_empty() or _item_index < 0 or _weapon_target_selection_blocked:
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


func _on_pressed() -> void:
	if _item_resource == null or _weapon_target_selection_blocked:
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


func _get_sell_price() -> int:
	return int(ITEM_DETAIL_FORMATTER.call("get_item_sell_price", _item_resource))


func _build_item_details() -> String:
	return str(ITEM_DETAIL_FORMATTER.call("build_plain_text", _item_resource, _quantity))


func _make_custom_tooltip(_for_text: String) -> Object:
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", _item_resource, _quantity)


func _is_enhancement_stone() -> bool:
	return _item_resource != null and str(_item_resource.get("item_kind")) == "enhancement_stone"


func _is_repair_kit() -> bool:
	return _item_resource != null and str(_item_resource.get("item_kind")) == "repair_kit"


func _is_weapon_resource() -> bool:
	return _item_resource != null and str(_item_resource.get("weapon_type")) in ["ranged", "melee"]


func _refresh_enhancement_target_highlight() -> void:
	# 卡片色调；浅绿色表示可点击或可投放的强化目标，取消选择后恢复白色不影响原主题。
	# 修复目标补充；当前不可选武器会优先使用灰色滤镜，可选武器继续使用浅绿色。
	if _weapon_target_selection_blocked:
		self_modulate = UNAVAILABLE_TARGET_FILTER_COLOR
	else:
		self_modulate = Color(0.68, 1.0, 0.76, 1.0) if _enhancement_target_highlight else Color.WHITE


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
	var modifiers: Dictionary = EnhancementRules.normalize_modifiers(_item_resource.get("modifiers") as Dictionary)
	# 彩色词条；增强为绿色，削弱为红色，不显示具体百分比。
	# 品质化数值补充；当前卡片会直接显示每条实际百分比，上述颜色规则保持不变。
	# 方向化显示补充；当前卡片只显示属性与 +/-，具体百分比在使用时随机后由结果弹窗展示。
	var colored_tokens: PackedStringArray = PackedStringArray()
	_append_colored_stone_tokens(colored_tokens, modifiers, true)
	_append_colored_stone_tokens(colored_tokens, modifiers, false)
	if _weapon_slot_visual_style_enabled:
		card_lines.append("[center][font_size=9]%s[/font_size][/center]" % (" ".join(colored_tokens) if not colored_tokens.is_empty() else "无词条"))
	else:
		card_lines.append("[center]%s  ·  售价 %d[/center]" % [(" ".join(colored_tokens) if not colored_tokens.is_empty() else "无词条"), _get_sell_price() * _quantity])
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
	card_lines.append("[center][font_size=9]%s[/font_size][/center]" % repair_text if _weapon_slot_visual_style_enabled else "[center]%s  ·  售价 %d[/center]" % [repair_text, _get_sell_price() * _quantity])
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
