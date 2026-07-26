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
## 通用物品卡片视图；主锻造槽和牺牲槽中的物品必须与背包、仓库和商店使用同一固定尺寸模板。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 锻造槽允许的最小边长；默认 48 像素，用于保护外部调用传入异常小尺寸时的文字与投放区域可用性。
const MINIMUM_SLOT_SIZE: float = 48.0
## 全局窗口样式指南；锻造槽宿主五态样式统一读取当前 UI 风格卡片色板，与仓库武器槽保持同一状态映射。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")

## 槽位下标；主锻造槽固定为 -1，周围牺牲槽使用 0 到 4。
var _slot_index: int = -1
## 是否为主锻造槽；主锻造槽接收武器、装备或可升阶强化石，牺牲槽接收兼容锻造物品。
var _is_main_slot: bool = false
## 当前槽位条目；包含资源和来源位置，空字典表示尚未放入物品。
var _entry: Dictionary = {}
## 当前槽位物品是否不符合主物品锻造规则；默认 false，启用时显示红色滤镜但仍允许点击归还。
## 统一禁用补充：当前无效物品改用通用灰色遮罩，仍保留点击归还能力。
var _is_invalid: bool = false
## 槽位普通样式缓存；默认在 configure 创建，用于无效材料禁用悬停提亮。
var _normal_style: StyleBoxFlat
## 槽位悬停样式缓存；默认在 configure 创建，合法槽位继续使用轻微提亮反馈。
var _hover_style: StyleBoxFlat
## 槽位按下样式缓存；默认在 configure 创建，合法槽位继续使用按下反馈。
var _pressed_style: StyleBoxFlat
## 槽位禁用样式缓存；默认在 configure 创建，保持卡片底色与弱边框的低饱和可辨认状态。
var _disabled_style: StyleBoxFlat
## 槽位焦点样式缓存；默认在 configure 创建，透明背景配当前风格强调色描边。
var _focus_style: StyleBoxFlat
## 主题刷新重入保护；重建样式盒会再次触发主题变更通知，置位期间跳过嵌套刷新以避免递归。
var _theme_refresh_in_progress: bool = false
## 通用物品卡片视图缓存；默认在配置槽位时创建，空槽与已放入物品共享同一排版和尺寸。
var _item_card_view: Control


func configure(slot_index: int, is_main_slot: bool, slot_size: float = 84.0) -> void:
	_slot_index = slot_index
	_is_main_slot = is_main_slot
	# 槽位尺寸；由锻造面板统一配置，主锻造槽和牺牲槽保持一致以维持环形布局的视觉平衡。
	# 通用模板补充：参数仅为旧场景兼容入口，实际显示强制使用全项目统一物品卡片固定尺寸。
	var resolved_slot_size: float = maxf(slot_size, MINIMUM_SLOT_SIZE)
	custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 槽位基础样式；六个槽位统一正方形深色底与白色边框，主锻造槽与牺牲槽仅通过位置区分职责。
	# 通用模板补充：该宿主样式仅保留交互兼容，最终可见轮廓由 160×72 的 ItemCardView 覆盖绘制。
	# 风格化补充：五态样式统一读取样式指南卡片色板并集中在 _rebuild_interaction_styles()，风格切换后可重建。
	_rebuild_interaction_styles()
	_refresh_interaction_styles()
	_ensure_item_card_view()
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	refresh({})


func refresh(entry: Dictionary) -> void:
	_entry = entry.duplicate()
	# 当前物品；空槽不显示文字，有物品时只显示名称并允许单击快速归还。
	var item_resource: Resource = _entry.get("resource") as Resource
	if item_resource == null:
		text = ""
		tooltip_text = ""
		self_modulate = Color.WHITE
		_item_card_view.call("configure", null, 1, "主锻造槽" if _is_main_slot else "牺牲槽 %d" % (_slot_index + 1), "", "空", "")
	else:
		# 物品名称；槽位保持简洁，仅展示已放入材料的名称，完整来源和属性仍可通过悬停查看。
		text = ""
		tooltip_text = ITEM_DETAIL_FORMATTER.call("build_plain_text", item_resource, 1)
		self_modulate = Color.WHITE
		# 锻造槽摘要；强化石第三行显示彩色属性方向，其他物品继续显示类型，名称和耐久条仍由通用模板处理。
		var item_type: String = str(ITEM_DETAIL_FORMATTER.call("get_item_type_label", item_resource))
		# 第三行摘要；强化石复用统一属性富文本，避免放入槽位后退化为通用“资源 · 强化石”分类文本。
		var detail_text: String = str(ITEM_DETAIL_FORMATTER.call("build_stone_attribute_bbcode", item_resource)) if str(item_resource.get("item_kind")) == "enhancement_stone" else item_type
		_item_card_view.call("configure", item_resource, maxi(int(_entry.get("quantity", 1)), 1), "主锻造槽" if _is_main_slot else "牺牲槽 %d" % (_slot_index + 1), detail_text, "空", "")
	_item_card_view.call("set_visual_state", _is_main_slot and item_resource != null, false)
	_item_card_view.call("set_disabled_state", _is_invalid and item_resource != null)
	if _is_invalid:
		_item_card_view.call("play_hover", self, false)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_invalid_state(is_invalid: bool) -> void:
	# 无效状态只改变当前槽位视觉与提示，不禁用按钮，玩家仍可单击移除红色材料。
	# 统一禁用补充：当前视觉统一为灰色遮罩，不再使用红色材料滤镜。
	_is_invalid = is_invalid
	_refresh_interaction_styles()
	refresh(_entry)


func _rebuild_interaction_styles() -> void:
	## 按当前 UI 风格重建槽位五态样式盒；只生成样式资源，实际应用由 _refresh_interaction_styles() 统一执行。
	# 卡片基础背景；读取当前风格标准物品卡片底色，各状态只在其上调整明度与透明度，不再出现字面蓝色或纯白边框。
	var card_background_color: Color = UI_STYLE_GUIDE.get_item_card_background_color()
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(card_background_color, 0.94)
	_normal_style.border_color = UI_STYLE_GUIDE.get_item_card_border_color()
	_normal_style.set_border_width_all(2)
	_normal_style.set_corner_radius_all(4)
	# 槽位悬停样式；保留白色边框并轻微提亮背景，便于确认可点击归还操作。
	# 风格化补充：悬停边框现改用当前风格弱强调色，背景仍维持原有轻微提亮的明度关系。
	_hover_style = _normal_style.duplicate() as StyleBoxFlat
	_hover_style.bg_color = Color(card_background_color.lerp(Color.WHITE, 0.10), 0.98)
	_hover_style.border_color = UI_STYLE_GUIDE.get_accent_muted_color()
	# 槽位按下样式；保持边框不变，避免锻造区视觉层级随点击发生跳变。
	# 风格化补充：按下边框现改用当前风格强调色，背景继续沿用比悬停更亮一档的明度递进。
	_pressed_style = _normal_style.duplicate() as StyleBoxFlat
	_pressed_style.bg_color = Color(card_background_color.lerp(Color.WHITE, 0.16), 1.0)
	_pressed_style.border_color = UI_STYLE_GUIDE.get_accent_color()
	# 槽位禁用样式；沿用卡片底色并弱化边框，保证低饱和状态下仍可辨认投放区域。
	_disabled_style = _normal_style.duplicate() as StyleBoxFlat
	_disabled_style.bg_color = Color(card_background_color, 0.82)
	_disabled_style.border_color = Color(UI_STYLE_GUIDE.get_item_card_border_color(), 0.55)
	# 槽位焦点样式；透明背景只描当前风格强调色 2 像素边框，圆角与统一物品卡片保持一致。
	_focus_style = StyleBoxFlat.new()
	_focus_style.bg_color = Color.TRANSPARENT
	_focus_style.border_color = UI_STYLE_GUIDE.get_accent_color()
	_focus_style.set_border_width_all(2)
	_focus_style.set_corner_radius_all(4)


func _refresh_interaction_styles() -> void:
	if _normal_style == null:
		return
	add_theme_stylebox_override("normal", _normal_style)
	# 红色无效材料仍允许点击归还，但 hover 和 pressed 不再提亮为可锻造状态。
	add_theme_stylebox_override("hover", _normal_style if _is_invalid else _hover_style)
	add_theme_stylebox_override("pressed", _normal_style if _is_invalid else _pressed_style)
	# 补齐禁用与焦点状态；禁用保持低饱和可辨认，焦点用透明底加强调描边，两者均随当前风格重建。
	if _disabled_style != null:
		add_theme_stylebox_override("disabled", _disabled_style)
	if _focus_style != null:
		add_theme_stylebox_override("focus", _focus_style)


func _notification(what: int) -> void:
	if what != NOTIFICATION_THEME_CHANGED:
		return
	# 主题切换刷新；样式仅在配置时创建一次，收到主题通知后按当前风格重建并重新应用，重入保护防止覆盖操作再次触发。
	if _normal_style == null or _theme_refresh_in_progress:
		return
	_theme_refresh_in_progress = true
	_rebuild_interaction_styles()
	_refresh_interaction_styles()
	_theme_refresh_in_progress = false


func get_entry() -> Dictionary:
	return _entry.duplicate()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not _entry.is_empty():
		return false
	# 拖拽字典；只接受仓库与背包卡片生成的稳定协议。
	var drag_data: Dictionary = data as Dictionary
	if str(drag_data.get("type", "")) != STORAGE_DRAG_DATA_TYPE:
		return false
	# 拖拽物品；主锻造槽允许武器、装备或强化石，牺牲槽先接受三类锻造物品，再由面板结合主物品做精确校验。
	var item_resource: Resource = drag_data.get("resource") as Resource
	if item_resource == null:
		return false
	# 是否为武器；通过 weapon_type 识别，避免依赖具体 WeaponData 类。
	var is_weapon: bool = str(item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"]
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


func _on_mouse_entered() -> void:
	# 锻造槽悬浮反馈；空槽不播放，已有物品统一调用通用卡片悬浮动效。
	if _item_card_view != null and not _entry.is_empty():
		_item_card_view.call("play_hover", self, true)


func _on_mouse_exited() -> void:
	if _item_card_view != null:
		_item_card_view.call("play_hover", self, false)


func _make_custom_tooltip(_for_text: String) -> Object:
	# 当前槽位资源；空槽不会请求自定义提示，已放入物品复用仓库详情卡。
	var item_resource: Resource = _entry.get("resource") as Resource
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", item_resource, 1) if item_resource != null else null


func _ensure_item_card_view() -> void:
	if _item_card_view != null:
		return
	# 锻造按钮只处理投放与归还，视觉内容统一交给固定尺寸物品模板。
	_item_card_view = ITEM_CARD_VIEW_SCRIPT.new() as Control
	_item_card_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_item_card_view)
