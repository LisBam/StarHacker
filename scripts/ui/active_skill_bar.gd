extends HBoxContainer
class_name ActiveSkillBar

## 主动技能栏显示三个技能槽的当前实际按键、技能名称与剩余冷却。
## 它只读取 ActiveSkillComponent 和 InputBindings，不处理技能输入、能量或释放结果。

## 标签单轴尺寸安全下限；固定 1 像素，避免检查器内边距超过槽尺寸后生成负区域。
const MINIMUM_LABEL_AXIS_SIZE: float = 1.0

## 单个技能槽最小尺寸；默认 150×58 像素，三个槽并排时适配 1280×720 战斗 HUD。
@export var slot_minimum_size: Vector2 = Vector2(150.0, 58.0)
## 技能槽背景颜色；默认深蓝黑半透明，保持技能栏与现有底部武器栏风格一致。
@export var slot_background_color: Color = Color(0.025, 0.045, 0.075, 0.92)
## 技能槽边框颜色；默认青蓝色，空技能槽会自动降低文本透明度。
@export var slot_border_color: Color = Color(0.26, 0.72, 0.92, 0.86)
## 冷却遮罩颜色；默认黑色半透明，冷却中覆盖技能槽并显示精确剩余秒数。
@export var cooldown_overlay_color: Color = Color(0.01, 0.015, 0.025, 0.72)
## 技能名称颜色；默认浅蓝白色，冷却和空槽状态由独立文本说明。
@export var skill_name_color: Color = Color(0.78, 0.94, 1.0, 1.0)
## 空技能槽透明度；默认 0.42，使占位文本可见但弱于已装载技能。
@export_range(0.0, 1.0, 0.01) var empty_slot_opacity: float = 0.42
## 技能槽间距；默认 8 像素，运行时通常不动态修改。
@export_range(0, 32, 1) var slot_separation: int = 8
## 技能槽边框宽度；默认 2 像素，修改只影响技能栏视觉分区。
@export_range(0, 12, 1) var slot_border_width: int = 2
## 技能槽圆角半径；默认 6 像素，修改只影响技能栏面板轮廓。
@export_range(0, 32, 1) var slot_corner_radius: int = 6
## 技能按键标签位置；默认 (8, 4)，相对单个技能槽左上角定位。
@export var key_label_position: Vector2 = Vector2(8.0, 4.0)
## 技能按键标签边缘留白；默认 16×0 像素，从槽尺寸扣除后得到按键标签区域。
@export var key_label_size_inset: Vector2 = Vector2(16.0, 0.0)
## 技能按键标签高度；默认 20 像素，修改会影响名称区域的起始位置。
@export_range(1.0, 64.0, 1.0) var key_label_height: float = 20.0
## 技能按键字号；默认 12，修改只影响实际绑定文本可读性。
@export_range(8, 48, 1) var key_label_font_size: int = 12
## 技能按键文字颜色；默认亮青色，与项目输入提示保持一致。
@export var key_label_color: Color = Color(0.48, 0.88, 1.0, 1.0)
## 技能名称标签位置；默认 (6, 22)，位于按键提示下方。
@export var name_label_position: Vector2 = Vector2(6.0, 22.0)
## 技能名称标签边缘留白；默认 12×26 像素，从槽尺寸扣除后得到名称区域。
@export var name_label_size_inset: Vector2 = Vector2(12.0, 26.0)
## 冷却文字字号；默认 18，显示一位小数剩余秒数。
@export_range(8, 64, 1) var cooldown_label_font_size: int = 18
## 冷却文字颜色；默认白色，保证黑色遮罩上的剩余时间清晰可读。
@export var cooldown_label_color: Color = Color.WHITE
## 冷却秒数保留小数位；默认 1，修改只影响技能栏文本精度，不改变实际冷却计时。
@export_range(0, 3, 1) var cooldown_decimal_places: int = 1
## 组件缺失时的兼容技能槽数量；默认 3，与技能一、二、三输入协议一致。
@export_range(0, 12, 1) var fallback_slot_count: int = 3

## 主动技能组件；默认 null，由 CombatHud 注入，缺失时仍创建三个不可用占位槽。
var _active_skill_component: Node
## 每个技能槽的名称标签；元素顺序与组件技能槽一致，默认空数组并在 configure 时重建。
var _name_labels: Array[Label] = []
## 每个技能槽的按键标签；元素顺序与组件技能槽一致，按键绑定变化时刷新实际显示文本。
var _key_labels: Array[Label] = []
## 每个技能槽的冷却遮罩；元素为 ColorRect，冷却为 0 或空槽时隐藏。
var _cooldown_overlays: Array[ColorRect] = []
## 每个技能槽的冷却文本；元素为 Label，显示一位小数剩余秒数。
var _cooldown_labels: Array[Label] = []


func _ready() -> void:
	add_theme_constant_override("separation", slot_separation)
	set_process(true)
	# 输入绑定服务；玩家改键、单项恢复或全部恢复后即时刷新三个技能槽按键文本。
	var input_bindings: Node = get_tree().root.get_node_or_null("InputBindings")
	if input_bindings != null and input_bindings.has_signal("bindings_changed") and not input_bindings.is_connected("bindings_changed", Callable(self, "refresh")):
		input_bindings.connect("bindings_changed", Callable(self, "refresh"))


func configure(active_skill_component: Node) -> void:
	## 注入主动技能组件并重建固定槽位；角色切换只刷新资源，不需要重建整个战斗 HUD。
	_active_skill_component = active_skill_component
	_rebuild_slots()
	refresh()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		_refresh_cooldowns()


func refresh() -> void:
	## 刷新技能名称、按键与冷却；组件缺失或空技能槽明确显示“空技能槽”。
	if _name_labels.is_empty():
		_rebuild_slots()
	for slot_index in range(_name_labels.size()):
		# 当前技能资源；空槽返回 null，名称使用统一占位文本。
		var skill_data: Resource = _active_skill_component.call("get_skill_resource", slot_index) as Resource if _active_skill_component != null and _active_skill_component.has_method("get_skill_resource") else null
		_name_labels[slot_index].text = str(skill_data.get("display_name")) if skill_data != null else "空技能槽"
		_name_labels[slot_index].modulate = Color.WHITE if skill_data != null else Color(Color.WHITE, empty_slot_opacity)
		# 技能动作；优先从组件读取槽位动作，缺失时按通用命名回退。
		var action_name: StringName = StringName("active_skill_%d" % (slot_index + 1))
		if _active_skill_component != null and _active_skill_component.has_method("get_skill_action_name"):
			action_name = StringName(str(_active_skill_component.call("get_skill_action_name", slot_index)))
		_key_labels[slot_index].text = _get_action_display_text(action_name)
	_refresh_cooldowns()


func _rebuild_slots() -> void:
	## 重建技能槽控件；只在首次配置或槽位数量结构变化时调用。
	for child in get_children():
		child.queue_free()
	_name_labels.clear()
	_key_labels.clear()
	_cooldown_overlays.clear()
	_cooldown_labels.clear()
	# 技能槽数量；默认三个，组件公开其他数量时按其实际值创建。
	var slot_count: int = int(_active_skill_component.call("get_slot_count")) if _active_skill_component != null and _active_skill_component.has_method("get_slot_count") else fallback_slot_count
	for slot_index in range(maxi(slot_count, 0)):
		_add_skill_slot(slot_index)


func _add_skill_slot(_slot_index: int) -> void:
	# 技能槽面板；使用独立样式，空槽和冷却只改变子节点而不修改全局主题。
	var slot_panel: PanelContainer = PanelContainer.new()
	slot_panel.custom_minimum_size = slot_minimum_size
	# 技能槽样式；深色背景、两像素边框和六像素圆角提供清晰分区。
	var slot_style: StyleBoxFlat = StyleBoxFlat.new()
	slot_style.bg_color = slot_background_color
	slot_style.border_color = slot_border_color
	slot_style.set_border_width_all(slot_border_width)
	slot_style.set_corner_radius_all(slot_corner_radius)
	slot_panel.add_theme_stylebox_override("panel", slot_style)
	add_child(slot_panel)
	# 技能槽叠层容器；基础文本和冷却遮罩共用完整矩形。
	var slot_layers: Control = Control.new()
	slot_layers.custom_minimum_size = slot_minimum_size
	slot_panel.add_child(slot_layers)
	# 技能按键标签；固定左上角显示当前实际绑定，帮助玩家改键后仍可识别槽位。
	var key_label: Label = Label.new()
	key_label.position = key_label_position
	key_label.size = Vector2(maxf(slot_minimum_size.x - key_label_size_inset.x, MINIMUM_LABEL_AXIS_SIZE), key_label_height)
	key_label.add_theme_font_size_override("font_size", key_label_font_size)
	key_label.add_theme_color_override("font_color", key_label_color)
	slot_layers.add_child(key_label)
	_key_labels.append(key_label)
	# 技能名称标签；占用槽位下方区域并居中，长名称会自动换行而不溢出。
	var name_label: Label = Label.new()
	name_label.position = name_label_position
	name_label.size = Vector2(maxf(slot_minimum_size.x - name_label_size_inset.x, MINIMUM_LABEL_AXIS_SIZE), maxf(slot_minimum_size.y - name_label_size_inset.y, MINIMUM_LABEL_AXIS_SIZE))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", skill_name_color)
	slot_layers.add_child(name_label)
	_name_labels.append(name_label)
	# 冷却遮罩；覆盖完整槽位内容，只有剩余冷却大于 0 时显示。
	var cooldown_overlay: ColorRect = ColorRect.new()
	cooldown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown_overlay.color = cooldown_overlay_color
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.visible = false
	slot_layers.add_child(cooldown_overlay)
	_cooldown_overlays.append(cooldown_overlay)
	# 冷却文本；居中显示精确剩余秒数，跟随遮罩显隐。
	var cooldown_label: Label = Label.new()
	cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", cooldown_label_font_size)
	cooldown_label.add_theme_color_override("font_color", cooldown_label_color)
	cooldown_overlay.add_child(cooldown_label)
	_cooldown_labels.append(cooldown_label)


func _refresh_cooldowns() -> void:
	for slot_index in range(_cooldown_overlays.size()):
		# 当前剩余冷却；组件缺失或无效槽按 0 处理。
		var cooldown_remaining: float = float(_active_skill_component.call("get_cooldown_remaining", slot_index)) if _active_skill_component != null and _active_skill_component.has_method("get_cooldown_remaining") else 0.0
		_cooldown_overlays[slot_index].visible = cooldown_remaining > 0.0
		_cooldown_labels[slot_index].text = "%ss" % String.num(cooldown_remaining, cooldown_decimal_places) if cooldown_remaining > 0.0 else ""


func _get_action_display_text(action_name: StringName) -> String:
	# 输入绑定服务；优先复用设置页面的当前实际绑定显示格式。
	var input_bindings: Node = get_tree().root.get_node_or_null("InputBindings")
	if input_bindings != null and input_bindings.has_method("get_action_display_text"):
		return str(input_bindings.call("get_action_display_text", action_name))
	if not InputMap.has_action(action_name) or InputMap.action_get_events(action_name).is_empty():
		return "未绑定"
	# 输入事件；服务缺失时使用 Godot 事件文本作为隔离场景兜底。
	var input_event: InputEvent = InputMap.action_get_events(action_name)[0] as InputEvent
	return input_event.as_text() if input_event != null else "未绑定"
