extends HBoxContainer
class_name ActiveSkillBar

## 主动技能栏显示三个技能槽的当前实际按键、技能名称、剩余冷却与专属发动条件状态。
## 它只读取 ActiveSkillComponent 和 InputBindings，不处理技能输入、能量或释放结果。

## 标签单轴尺寸安全下限；固定 1 像素，避免检查器内边距超过槽尺寸后生成负区域。
const MINIMUM_LABEL_AXIS_SIZE: float = 1.0
## 局内共享紧凑槽位视图；主动技能与右侧武器栏通过同一组件统一外观和状态接口。
const COMBAT_HUD_SLOT_VIEW_SCRIPT: Script = preload("res://scripts/ui/combat_hud_slot_view.gd")
## 技能栏动态状态刷新间隔；固定 0.05 秒提供 20 次/秒的冷却与发动条件反馈，避免静态三槽 UI 每个渲染帧重复格式化文本。
const DYNAMIC_REFRESH_INTERVAL_SECONDS: float = 0.05

## 单个技能槽最小尺寸；默认 150×58 像素，三个槽并排时适配 1280×720 战斗 HUD。
@export var slot_minimum_size: Vector2 = Vector2(150.0, 58.0)
## 技能槽背景颜色；默认深蓝黑半透明，保持技能栏与现有底部武器栏风格一致。
@export var slot_background_color: Color = Color(0.025, 0.045, 0.075, 0.92)
## 技能槽边框颜色；默认青蓝色，空技能槽会自动降低文本透明度。
@export var slot_border_color: Color = Color(0.26, 0.72, 0.92, 0.86)
## 冷却遮罩颜色；默认黑色半透明，冷却中覆盖技能槽并显示精确剩余秒数。
@export var cooldown_overlay_color: Color = Color(0.01, 0.015, 0.025, 0.72)
## 后续段等待遮罩颜色；默认青蓝半透明，用于明确表示技能仍可释放而不是已经进入冷却。
@export var follow_up_overlay_color: Color = Color(0.02, 0.24, 0.34, 0.66)
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
## 每个技能槽的共享局内视图；元素顺序与技能组件槽位一致，名称、按键、能耗和遮罩统一由该组件显示。
var _slot_views: Array[Control] = []
## 技能栏动态刷新累计时间；默认 0，达到固定间隔后统一刷新三个槽位并重新计时。
var _dynamic_refresh_elapsed: float = 0.0
## 组件是否提供剩余冷却接口；configure 注入时缓存 has_method 结果，20Hz 冷却刷新不再逐槽做方法名字符串查找。
var _component_has_cooldown_remaining: bool = false
## 组件是否提供后续段剩余窗口接口；configure 注入时缓存，决定青蓝后续段遮罩数据来源是否可用。
var _component_has_follow_up_remaining: bool = false
## 组件是否提供冷却暂停状态接口；configure 注入时缓存，用于延迟开始阶段隐藏冷却数字。
var _component_has_cooldown_paused: bool = false
## 组件是否提供技能资源读取接口；configure 注入时缓存，冷却路径的发动条件刷新复用该判定。
var _component_has_skill_resource: bool = false
## 组件是否提供发动条件判定接口；configure 注入时缓存，禁用滤镜刷新不再逐槽查找方法名。
var _component_has_activation_condition: bool = false
## 每个技能槽上次冷却遮罩状态编码；元素为 int，由量化剩余秒数、可见、后续段与文本标志组成，-1 表示尚未写入，编码未变化时完全跳过文本格式化与遮罩写入。
var _last_cooldown_display_states: Array[int] = []


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
	# 组件方法判定缓存；注入时一次性完成全部高频 has_method 查询，后续 20Hz 冷却刷新只做布尔分支。
	_component_has_cooldown_remaining = _active_skill_component != null and _active_skill_component.has_method("get_cooldown_remaining")
	_component_has_follow_up_remaining = _active_skill_component != null and _active_skill_component.has_method("get_follow_up_remaining")
	_component_has_cooldown_paused = _active_skill_component != null and _active_skill_component.has_method("is_cooldown_paused")
	_component_has_skill_resource = _active_skill_component != null and _active_skill_component.has_method("get_skill_resource")
	_component_has_activation_condition = _active_skill_component != null and _active_skill_component.has_method("is_skill_activation_condition_met")
	_rebuild_slots()
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_dynamic_refresh_elapsed += maxf(delta, 0.0)
	if _dynamic_refresh_elapsed < DYNAMIC_REFRESH_INTERVAL_SECONDS:
		return
	_dynamic_refresh_elapsed = fmod(_dynamic_refresh_elapsed, DYNAMIC_REFRESH_INTERVAL_SECONDS)
	_refresh_cooldowns()


func refresh() -> void:
	## 刷新技能名称、按键与冷却；组件缺失或空技能槽明确显示“空技能槽”。
	if not _slot_views.is_empty():
		_refresh_shared_slot_content()
		_refresh_cooldowns()
		return
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
	_slot_views.clear()
	# 冷却遮罩状态编码缓存清理；槽位重建后全部恢复为未写入状态，保证新槽位第一次刷新必然写入遮罩。
	_last_cooldown_display_states.clear()
	# 技能槽数量；默认三个，组件公开其他数量时按其实际值创建。
	var slot_count: int = int(_active_skill_component.call("get_slot_count")) if _active_skill_component != null and _active_skill_component.has_method("get_slot_count") else fallback_slot_count
	for slot_index in range(maxi(slot_count, 0)):
		_add_shared_skill_slot(slot_index)


func _add_shared_skill_slot(_slot_index: int) -> void:
	## 创建一个共享局内槽位视图；具体技能内容由 refresh() 统一写入，槽位本身不处理输入。
	# 共享槽位实例；与右侧武器栏复用相同脚本和外观接口。
	var slot_view: Control = COMBAT_HUD_SLOT_VIEW_SCRIPT.new() as Control
	if slot_view == null:
		return
	slot_view.custom_minimum_size = slot_minimum_size
	add_child(slot_view)
	_slot_views.append(slot_view)
	# 冷却遮罩状态编码占位；-1 表示该槽尚未写入过遮罩，与槽位视图数组保持同下标对应。
	_last_cooldown_display_states.append(-1)


func _refresh_shared_slot_content() -> void:
	## 把当前技能按键、名称与能耗写入共享槽位；按键在共享组件顶部居中显示。
	for slot_index in range(_slot_views.size()):
		# 当前技能资源；空槽使用统一占位文本并降低全部文字透明度。
		var skill_data: Resource = _active_skill_component.call("get_skill_resource", slot_index) as Resource if _active_skill_component != null and _active_skill_component.has_method("get_skill_resource") else null
		# 技能动作；优先读取组件公开动作名，缺失时回退通用槽位命名。
		var action_name: StringName = StringName("active_skill_%d" % (slot_index + 1))
		if _active_skill_component != null and _active_skill_component.has_method("get_skill_action_name"):
			action_name = StringName(str(_active_skill_component.call("get_skill_action_name", slot_index)))
		# 技能名称；空资源明确显示空技能槽，避免误认为 HUD 加载失败。
		var skill_name: String = str(skill_data.get("display_name")) if skill_data != null else "空技能槽"
		# 技能能耗；有资源时始终显示整数能耗，空槽不显示辅助信息。
		var energy_cost: int = maxi(int(skill_data.get("energy_cost")), 0) if skill_data != null else 0
		var detail_text: String = "能耗 %d" % energy_cost if skill_data != null else ""
		# 内容透明度；空槽使用原有 0.42 默认值，已配置技能保持完全可读。
		var content_opacity: float = 1.0 if skill_data != null else empty_slot_opacity
		_slot_views[slot_index].call("configure_hud_content", slot_minimum_size, _get_action_display_text(action_name), skill_name, detail_text, null, content_opacity)
		# 专属发动条件；未解锁或已经永久完成的技能只覆盖禁用滤镜，不追加状态文字。
		var activation_condition_met: bool = bool(_active_skill_component.call("is_skill_activation_condition_met", slot_index)) if skill_data != null and _active_skill_component != null and _active_skill_component.has_method("is_skill_activation_condition_met") else skill_data != null
		_slot_views[slot_index].call("set_disabled_state", skill_data != null and not activation_condition_met)


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
	if not _slot_views.is_empty():
		# 冷却文本量化倍率；循环外读取一次供全部槽位复用，与显示小数位保持同一精度。
		var quantize_scale: float = _get_cooldown_quantize_scale()
		for slot_index in range(_slot_views.size()):
			# 当前剩余冷却；组件缺失或无效槽按 0 处理。
			var shared_cooldown_remaining: float = float(_active_skill_component.call("get_cooldown_remaining", slot_index)) if _active_skill_component != null and _component_has_cooldown_remaining else 0.0
			# 后续段剩余窗口；大于零时使用青蓝遮罩，表示当前槽仍可继续释放。
			var shared_follow_up_remaining: float = float(_active_skill_component.call("get_follow_up_remaining", slot_index)) if _active_skill_component != null and _component_has_follow_up_remaining else 0.0
			# 冷却是否仍处于延迟开始阶段；暂停只隐藏普通冷却数字，后续段窗口仍正常显示自己的可释放倒计时。
			var shared_cooldown_paused: bool = bool(_active_skill_component.call("is_cooldown_paused", slot_index)) if _active_skill_component != null and _component_has_cooldown_paused else false
			# 遮罩剩余时间；后续段优先于普通冷却显示。
			var display_remaining: float = shared_follow_up_remaining if shared_follow_up_remaining > 0.0 else shared_cooldown_remaining
			# 后续段激活状态；决定遮罩颜色与文本分支，并参与遮罩状态编码比较。
			var follow_up_active: bool = shared_follow_up_remaining > 0.0
			# 遮罩文本显示条件；与原有文字分支完全一致，后续段激活或普通冷却未暂停时才显示秒数。
			var overlay_text_visible: bool = display_remaining > 0.0 and (follow_up_active or not shared_cooldown_paused)
			# 本帧遮罩状态编码；量化剩余秒数与可见、后续段、文本三个标志合并，任一变化才继续执行格式化与遮罩写入。
			var display_state: int = roundi(display_remaining * quantize_scale) * 8 + (4 if display_remaining > 0.0 else 0) + (2 if follow_up_active else 0) + (1 if overlay_text_visible else 0)
			# 上次遮罩状态编码；-1 表示尚未写入，编码一致时完全跳过冷却文本格式化与 set_state_overlay 调用。
			var last_display_state: int = _last_cooldown_display_states[slot_index] if slot_index < _last_cooldown_display_states.size() else -1
			if last_display_state != display_state:
				if slot_index < _last_cooldown_display_states.size():
					_last_cooldown_display_states[slot_index] = display_state
				# 遮罩颜色；后续段使用原青蓝色，普通冷却使用原黑色。
				var display_color: Color = follow_up_overlay_color if follow_up_active else cooldown_overlay_color
				# 遮罩文字；只在剩余时间大于零时显示一位小数秒数。
				var display_text: String = "%ss" % String.num(display_remaining, cooldown_decimal_places) if overlay_text_visible else ""
				_slot_views[slot_index].call("set_state_overlay", display_remaining > 0.0, display_color, display_text)
			# 发动条件状态；逐帧读取使伤害累计达到阈值时无需重建技能栏即可移除禁用滤镜。
			var skill_data: Resource = _active_skill_component.call("get_skill_resource", slot_index) as Resource if _active_skill_component != null and _component_has_skill_resource else null
			var activation_condition_met: bool = bool(_active_skill_component.call("is_skill_activation_condition_met", slot_index)) if skill_data != null and _active_skill_component != null and _component_has_activation_condition else skill_data != null
			_slot_views[slot_index].call("set_disabled_state", skill_data != null and not activation_condition_met)
		return
	for slot_index in range(_cooldown_overlays.size()):
		# 当前剩余冷却；组件缺失或无效槽按 0 处理。
		var cooldown_remaining: float = float(_active_skill_component.call("get_cooldown_remaining", slot_index)) if _active_skill_component != null and _component_has_cooldown_remaining else 0.0
		# 后续段剩余窗口；大于零时优先显示剩余秒数，提醒玩家技能槽当前仍可再次触发。
		var follow_up_remaining: float = float(_active_skill_component.call("get_follow_up_remaining", slot_index)) if _active_skill_component != null and _component_has_follow_up_remaining else 0.0
		# 冷却暂停状态；延迟进入冷却时继续表明技能不可用，但不提前展示尚未开始递减的秒数。
		var cooldown_paused: bool = bool(_active_skill_component.call("is_cooldown_paused", slot_index)) if _active_skill_component != null and _component_has_cooldown_paused else false
		_cooldown_overlays[slot_index].visible = cooldown_remaining > 0.0 or follow_up_remaining > 0.0
		_cooldown_overlays[slot_index].color = follow_up_overlay_color if follow_up_remaining > 0.0 else cooldown_overlay_color
		if follow_up_remaining > 0.0:
			_cooldown_labels[slot_index].text = "%ss" % String.num(follow_up_remaining, cooldown_decimal_places)
		else:
			_cooldown_labels[slot_index].text = "%ss" % String.num(cooldown_remaining, cooldown_decimal_places) if cooldown_remaining > 0.0 and not cooldown_paused else ""


func _get_cooldown_quantize_scale() -> float:
	## 返回冷却文本量化倍率；按检查器保留小数位换算，默认一位小数对应 10 倍，守卫精度始终与显示精度一致，显示语义不变。
	return pow(10.0, float(clampi(cooldown_decimal_places, 0, 3)))


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
