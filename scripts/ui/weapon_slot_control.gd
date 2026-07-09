extends PanelContainer
class_name WeaponSlotControl

## 武器槽控件负责显示一个装备槽或背包物品槽。
## 它只处理显示、拖拽数据打包、拖拽目标校验和 CD 覆盖绘制，不直接修改装备或背包数据。
## HUD 通过 drop_received 信号接收拖拽结果，再调用装备组件完成装备、移动或卸下。

signal drop_received(drop_data: Dictionary, target_context: String, target_kind: String, target_index: int)
signal drag_released_outside(drop_data: Dictionary)

## 槽位所属上下文；取值为 equipment 或 inventory，默认 equipment，修改会影响拖拽来源和投放规则。
var slot_context: String = "equipment"
## 槽位类型；取值为 ranged、melee、inventory 或 inventory_drop，默认 ranged，修改会影响可接受的武器类型。
var slot_kind: String = "ranged"
## 槽位索引；远程槽和背包槽使用有效下标，近战槽和卸下区默认 -1，修改会影响拖拽目标定位。
var slot_index: int = -1
## 当前槽位武器资源；取值为 Resource 或 null，默认空槽，修改会影响显示文本和是否可被拖拽。
var weapon_data: Resource
## 当前槽位是否被选中；取值为 true/false，默认 false，修改会影响槽位边框和标题状态。
var is_selected: bool = false
## 冷却覆盖比例；取值为 0 到 1，默认 0 表示无覆盖，修改会影响白色 CD 进度遮罩高度。
var cooldown_ratio: float = 0.0
## 空槽显示文本；默认“空”，用于没有武器资源时的槽位提示，修改会影响空槽可读性。
var empty_text: String = "空"

## 标题标签缓存；默认由 _ready 创建，显示槽位编号或槽位名称，修改会影响标题刷新目标。
var _title_label: Label
## 武器名标签缓存；默认由 _ready 创建，显示武器名称或空槽文本，修改会影响武器名称刷新目标。
var _name_label: Label
## 详情标签缓存；默认由 _ready 创建，显示能量消耗和冷却信息，修改会影响槽位辅助信息刷新目标。
var _detail_label: Label
## 当前拖拽数据缓存；取值为拖拽字典或空字典，默认用于拖拽结束时判断是否需要丢弃到世界。
var _active_drag_data: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(96.0, 76.0)
	_build_content()
	_refresh_text()


func set_slot_data(new_context: String, new_kind: String, new_index: int, new_weapon_data: Resource, new_is_selected: bool) -> void:
	slot_context = new_context
	slot_kind = new_kind
	slot_index = new_index
	weapon_data = new_weapon_data
	is_selected = new_is_selected
	_refresh_text()
	queue_redraw()


func set_empty_text(new_empty_text: String) -> void:
	empty_text = new_empty_text
	_refresh_text()


func set_cooldown_ratio(new_cooldown_ratio: float) -> void:
	cooldown_ratio = clampf(new_cooldown_ratio, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	# 槽位背景矩形；取值覆盖控件完整尺寸，默认用于绘制稳定底色，修改会影响武器槽视觉边界。
	var background_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(background_rect, Color(0.06, 0.075, 0.09, 0.92), true)

	if cooldown_ratio > 0.0:
		# CD 覆盖高度；取值为控件高度乘冷却比例，默认从满槽随冷却减少，修改会影响白色遮罩退减速度表现。
		var cooldown_height: float = size.y * cooldown_ratio
		# CD 覆盖矩形；取值从槽位底部向上覆盖，默认白色半透明，修改会影响冷却期间的视觉反馈区域。
		var cooldown_rect: Rect2 = Rect2(Vector2(0.0, size.y - cooldown_height), Vector2(size.x, cooldown_height))
		draw_rect(cooldown_rect, Color(1.0, 1.0, 1.0, 0.42), true)

	# 边框颜色；取值根据选中状态决定，默认选中槽更亮，修改会影响当前武器辨识度。
	var border_color: Color = Color(0.55, 0.92, 1.0, 1.0) if is_selected else Color(0.22, 0.30, 0.36, 1.0)
	draw_rect(background_rect, border_color, false, 2.0)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if weapon_data == null:
		return null

	# 拖拽预览控件；取值为临时 Label，默认显示武器名称，修改会影响拖拽时鼠标旁的提示。
	var preview_label: Label = Label.new()
	preview_label.text = _get_weapon_display_name(weapon_data, empty_text)
	preview_label.modulate = Color(0.9, 0.98, 1.0, 0.92)
	set_drag_preview(preview_label)

	_active_drag_data = {
		"source_context": slot_context,
		"slot_kind": slot_kind,
		"slot_index": slot_index,
		"weapon_data": weapon_data,
	}
	return _active_drag_data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false

	# 拖拽字典；取值来自其他 WeaponSlotControl，默认包含来源和武器资源，修改会影响投放校验。
	var drop_data: Dictionary = data as Dictionary
	if not drop_data.has("weapon_data") or not (drop_data["weapon_data"] is Resource):
		return false

	# 被拖拽武器资源；取值为 Resource，默认来自拖拽数据，修改会影响槽位类型校验。
	var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
	if slot_context == "inventory":
		# 拖拽来源上下文；取值为 equipment 或 inventory，默认空字符串表示非法来源，修改会影响背包槽可接收的来源。
		var source_context: String = str(drop_data.get("source_context", ""))
		return source_context == "equipment" or source_context == "inventory"

	if slot_kind == "ranged":
		return str(dragged_weapon.get("weapon_type")) == "ranged"
	if slot_kind == "melee":
		return str(dragged_weapon.get("weapon_type")) == "melee"

	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return

	# 投放数据；取值来自拖拽源，默认传递给 HUD 处理，修改会影响装备和卸下目标解析。
	var drop_data: Dictionary = data as Dictionary
	drop_received.emit(drop_data, slot_context, slot_kind, slot_index)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return

	if _active_drag_data.is_empty():
		return

	# 拖拽是否被目标成功接收；取值来自 Viewport，默认 false 表示释放在无效区域。
	var drag_successful: bool = get_viewport().gui_is_drag_successful()
	if not drag_successful:
		drag_released_outside.emit(_active_drag_data)

	_active_drag_data = {}


func _build_content() -> void:
	# 内边距容器；取值为新建 MarginContainer，默认提供文字呼吸空间，修改会影响槽位内容排版。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	# 文本垂直容器；取值为新建 VBoxContainer，默认纵向排列标题、名称和详情，修改会影响槽位内容结构。
	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 1)
	margin.add_child(text_box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 10)
	text_box.add_child(_title_label)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 12)
	text_box.add_child(_name_label)

	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 9)
	text_box.add_child(_detail_label)


func _refresh_text() -> void:
	if _title_label == null or _name_label == null or _detail_label == null:
		return

	_title_label.text = _get_slot_title()
	_name_label.text = _get_weapon_display_name(weapon_data, empty_text)
	_detail_label.text = _get_weapon_detail_text()
	tooltip_text = _get_weapon_tooltip_text()


func _get_slot_title() -> String:
	if slot_context == "inventory" and weapon_data != null:
		return _get_weapon_type_label(weapon_data)
	if slot_kind == "inventory_drop":
		return "放入"
	if slot_kind == "ranged":
		return "远程 %d" % (slot_index + 1)
	if slot_kind == "melee":
		return "近战"
	return "空位"


func _get_weapon_display_name(target_weapon_data: Resource, fallback_name: String) -> String:
	if target_weapon_data == null:
		return fallback_name

	# 武器显示名；取值来自资源 display_name 字段，默认 fallback_name，修改会影响槽位主文本。
	var display_name: String = str(target_weapon_data.get("display_name"))
	if display_name.is_empty():
		return fallback_name

	return display_name


func _get_weapon_detail_text() -> String:
	if weapon_data == null:
		return ""

	# 武器能量消耗；取值来自资源 energy_cost 字段，默认 0，修改会影响槽位能量提示。
	var energy_cost: float = maxf(float(weapon_data.get("energy_cost")), 0.0)
	if energy_cost <= 0.0:
		return "能量 0"

	return "能量 %d" % roundi(energy_cost)


func _get_weapon_type_label(target_weapon_data: Resource) -> String:
	if target_weapon_data == null:
		return "空位"

	# 武器类型字段；取值为 ranged 或 melee，默认由武器资源配置，修改会影响背包槽标题显示。
	var weapon_type: String = str(target_weapon_data.get("weapon_type"))
	if weapon_type == "ranged":
		return "远程"
	if weapon_type == "melee":
		return "近战"

	return "未知"


func _get_weapon_tooltip_text() -> String:
	if weapon_data == null:
		return ""

	# 提示框文本行；取值为字符串数组，默认逐项追加武器详细属性。
	var tooltip_lines: PackedStringArray = PackedStringArray()
	# 武器名称；取值来自资源 display_name 字段，默认用于提示框第一行。
	var display_name: String = _get_weapon_display_name(weapon_data, empty_text)
	# 武器类型；取值为 ranged 或 melee，默认转换为中文类型文本。
	var weapon_type: String = str(weapon_data.get("weapon_type"))
	tooltip_lines.append(display_name)
	tooltip_lines.append("类型：%s" % _get_weapon_type_label(weapon_data))

	# 武器说明；取值来自资源 description 字段，默认空字符串表示不显示说明行。
	var description: String = str(weapon_data.get("description"))
	if not description.is_empty():
		tooltip_lines.append(description)

	# 武器能量消耗；取值来自资源 energy_cost 字段，默认 0 表示不消耗能量。
	var energy_cost: float = maxf(float(weapon_data.get("energy_cost")), 0.0)
	# 武器后坐力；取值来自资源 recoil_force 字段，默认 0 表示不开火后推。
	var recoil_force: float = maxf(float(weapon_data.get("recoil_force")), 0.0)
	# 武器前坐力；取值来自资源 front_recoil_force 字段，默认 0 表示不向攻击方向推动使用者。
	var front_recoil_force: float = maxf(float(weapon_data.get("front_recoil_force")), 0.0)
	# 武器冲击力；取值来自资源 impact_force 字段，默认 0 表示不击退目标。
	var impact_force: float = maxf(float(weapon_data.get("impact_force")), 0.0)
	tooltip_lines.append("能量消耗：%d" % roundi(energy_cost))
	if recoil_force > 0.0:
		tooltip_lines.append("后坐力：%d" % roundi(recoil_force))
	if front_recoil_force > 0.0:
		tooltip_lines.append("前坐力：%d" % roundi(front_recoil_force))
	tooltip_lines.append("冲击力：%d" % roundi(impact_force))

	if weapon_type == "ranged":
		_append_ranged_tooltip_lines(tooltip_lines)
	elif weapon_type == "melee":
		_append_melee_tooltip_lines(tooltip_lines)

	return "\n".join(tooltip_lines)


func _append_ranged_tooltip_lines(tooltip_lines: PackedStringArray) -> void:
	# 远程伤害；取值来自资源 ranged_damage 字段，默认用于提示远程命中伤害。
	var ranged_damage: float = maxf(float(weapon_data.get("ranged_damage")), 0.0)
	# 子弹速度；取值来自资源 projectile_speed 字段，默认用于提示弹体飞行速度。
	var projectile_speed: float = maxf(float(weapon_data.get("projectile_speed")), 0.0)
	# 子弹射程；取值来自资源 bullet_range 字段，默认用于提示弹体最大飞行距离。
	var bullet_range: float = maxf(float(weapon_data.get("bullet_range")), 0.0)
	# 远程冷却；取值来自资源 ranged_cooldown 字段，默认用于提示连续射击间隔。
	var ranged_cooldown: float = maxf(float(weapon_data.get("ranged_cooldown")), 0.0)
	tooltip_lines.append("远程伤害：%d" % roundi(ranged_damage))
	tooltip_lines.append("子弹速度：%d" % roundi(projectile_speed))
	tooltip_lines.append("子弹射程：%d" % roundi(bullet_range))
	tooltip_lines.append("射击冷却：%.2f 秒" % ranged_cooldown)


func _append_melee_tooltip_lines(tooltip_lines: PackedStringArray) -> void:
	# 近战伤害；取值来自资源 melee_damage 字段，默认用于提示挥击伤害。
	var melee_damage: float = maxf(float(weapon_data.get("melee_damage")), 0.0)
	# 近战冷却；取值来自资源 melee_cooldown 字段，默认用于提示连续挥击间隔。
	var melee_cooldown: float = maxf(float(weapon_data.get("melee_cooldown")), 0.0)
	# 命中框持续时间；取值来自资源 melee_active_duration 字段，默认用于提示近战判定窗口。
	var melee_active_duration: float = maxf(float(weapon_data.get("melee_active_duration")), 0.0)
	tooltip_lines.append("近战伤害：%d" % roundi(melee_damage))
	tooltip_lines.append("近战冷却：%.2f 秒" % melee_cooldown)
	tooltip_lines.append("判定时长：%.2f 秒" % melee_active_duration)
