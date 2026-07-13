extends ConfirmationDialog
class_name SilverWolfStatAllocationDialog

## 银狼五维分配弹窗只负责收集一次战斗内的基础属性分配，并在总点数守恒时返回结构化结果。

signal allocation_confirmed(attributes: Dictionary)

## 全局 UI 样式指南；弹窗主题与项目其他确认窗口保持相同字号、颜色和按钮规格。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 五维字段定义；顺序决定弹窗从上到下的显示和结果字典键，不在运行时动态修改。
const ATTRIBUTE_DEFINITIONS: Array[Dictionary] = [
	{"key": "max_health", "label": "最大生命值"},
	{"key": "max_energy", "label": "最大能量"},
	{"key": "attack_power", "label": "攻击力"},
	{"key": "defense_power", "label": "防御力"},
	{"key": "move_speed", "label": "移动速度"},
]

## 弹窗固定尺寸；默认 680×430 像素，容纳五行整数滑条、数字框、总点数和底部确认按钮。
@export var dialog_size: Vector2i = Vector2i(680, 430)
## 每行属性控件的最小高度；默认 42 像素，保证中文标签与数值微调按钮具有稳定点击区域。
@export_range(28.0, 72.0, 1.0) var row_minimum_height: float = 42.0
## 数值输入控件宽度；默认 120 像素，可完整显示三位整数与两侧微调按钮。
@export_range(96.0, 220.0, 1.0) var spin_box_width: float = 120.0
## 属性滑条最小宽度；默认 260 像素，拖动时按 1 点整数步长调整。
@export_range(160.0, 420.0, 1.0) var slider_minimum_width: float = 260.0
## 数字框箭头单次调整点数；默认 10，运行时通常不修改，手动输入和滑条仍允许任意整数。
@export_range(1.0, 100.0, 1.0) var arrow_adjustment_step: float = 10.0

## 五维共同基准值；默认 99，setup 时由被动技能资源覆盖。
var _base_attribute_value: float = 99.0
## 单项最大浮动比例；默认 0.20，setup 时用于计算每个输入的最小值与最大值。
var _maximum_adjustment_ratio: float = 0.20
## 数值输入步长；默认 1，setup 时由技能资源覆盖，当前规则强制最低为 1 且只允许整数属性。
var _allocation_step: float = 1.0
## 五维总点数；默认 495，由共同基准乘五得到，确认时必须保持不变。
var _total_attribute_points: float = 495.0
## 属性输入表；键为稳定属性名、值为对应 SpinBox，默认空字典并在 ready 时构建。
var _attribute_inputs: Dictionary = {}
## 属性滑条表；键与数字框一致、值为对应 HSlider，默认空字典并在 ready 时构建。
var _attribute_sliders: Dictionary = {}
## 当前是否正在同步滑条与数字框；默认 false，更新期间阻止互相触发递归刷新。
var _synchronizing_attribute_controls: bool = false
## 总点数提示标签；默认 null，数值变化时同步显示当前值和目标值。
var _total_label: Label
## 主内容容器；默认 null，ready 时创建并承载五行属性与总点数提示。
var _content_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "我的主场！"
	dialog_text = ""
	exclusive = true
	unresizable = true
	theme = UI_STYLE_GUIDE.create_theme()
	get_ok_button().text = "确认分配"
	get_ok_button().custom_minimum_size = Vector2(116.0, 36.0)
	UI_STYLE_GUIDE.apply_primary_button(get_ok_button())
	get_cancel_button().visible = false
	confirmed.connect(_on_confirmed)
	canceled.connect(_keep_dialog_open)
	_build_content()
	_apply_input_limits()


func setup(base_attribute_value: float, maximum_adjustment_ratio: float, allocation_step: float) -> void:
	## 配置本次五维分配规则；可在节点进入树前调用，ready 后也会立即刷新既有输入范围。
	_base_attribute_value = maxf(base_attribute_value, 1.0)
	_maximum_adjustment_ratio = clampf(maximum_adjustment_ratio, 0.0, 1.0)
	_allocation_step = maxf(roundf(allocation_step), 1.0)
	_total_attribute_points = float(roundi(_base_attribute_value) * ATTRIBUTE_DEFINITIONS.size())
	if is_node_ready():
		_apply_input_limits()


func present() -> void:
	## 居中显示强制分配弹窗；默认五项均为基准值，因此玩家可以直接确认原始 99 点配置。
	popup_centered(dialog_size)


func _build_content() -> void:
	## 构建五行单一职责输入控件；弹窗重复展示继续复用同一组节点与当前数值。
	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 10)
	_content_box.custom_minimum_size = Vector2(float(dialog_size.x - 64), float(dialog_size.y - 130))
	add_child(_content_box)
	for definition in ATTRIBUTE_DEFINITIONS:
		# 单行容器；标签占满剩余空间，数值框保持固定宽度以保证五行对齐。
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, row_minimum_height)
		_content_box.add_child(row)
		# 当前属性键；数字框和滑条共用该稳定键进行双向同步。
		var attribute_key: String = str(definition.get("key", ""))
		# 属性名称；直接使用权威五维术语，不在运行时拼接额外玩法说明。
		var attribute_label: Label = Label.new()
		attribute_label.text = str(definition.get("label", "属性"))
		attribute_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attribute_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(attribute_label)
		# 属性整数滑条；拖动按 1 点变化，具体范围和默认值由统一配置函数写入。
		var attribute_slider: HSlider = HSlider.new()
		attribute_slider.custom_minimum_size = Vector2(slider_minimum_width, row_minimum_height)
		attribute_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attribute_slider.value_changed.connect(_on_slider_value_changed.bind(attribute_key))
		row.add_child(attribute_slider)
		# 属性数值输入；最小值、最大值、步长和默认值由统一配置函数写入。
		var attribute_input: SpinBox = SpinBox.new()
		attribute_input.custom_minimum_size = Vector2(spin_box_width, row_minimum_height)
		attribute_input.allow_greater = false
		attribute_input.allow_lesser = false
		attribute_input.value_changed.connect(_on_spin_box_value_changed.bind(attribute_key))
		row.add_child(attribute_input)
		_attribute_inputs[attribute_key] = attribute_input
		_attribute_sliders[attribute_key] = attribute_slider
	_total_label = Label.new()
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.ACCENT_COLOR)
	_content_box.add_child(_total_label)


func _apply_input_limits() -> void:
	## 把共同基准与浮动比例应用到全部输入；每次配置重置为等值分配，避免角色切换沿用旧战斗选择。
	# 单项整数最小值；小数边界向上取整，确保最终值仍位于允许比例范围内。
	var minimum_value: float = float(ceili(_base_attribute_value * (1.0 - _maximum_adjustment_ratio)))
	# 单项整数最大值；小数边界向下取整，确保最终值不超过允许比例范围。
	var maximum_value: float = float(floori(_base_attribute_value * (1.0 + _maximum_adjustment_ratio)))
	# 整数默认值；共同基准取最近整数，当前 99 点保持不变。
	var default_value: float = float(roundi(_base_attribute_value))
	for attribute_key in _attribute_inputs.keys():
		# 当前数字框；异常项安全跳过，不影响其他四维配置。
		var attribute_input: SpinBox = _attribute_inputs.get(attribute_key) as SpinBox
		# 当前滑条；必须与数字框同时存在才能完成双向同步。
		var attribute_slider: HSlider = _attribute_sliders.get(attribute_key) as HSlider
		if attribute_input == null or attribute_slider == null:
			continue
		attribute_input.min_value = minimum_value
		attribute_input.max_value = maximum_value
		attribute_input.step = 1.0
		attribute_input.custom_arrow_step = arrow_adjustment_step
		attribute_input.value = default_value
		attribute_slider.min_value = minimum_value
		attribute_slider.max_value = maximum_value
		attribute_slider.step = 1.0
		attribute_slider.value = default_value
	_refresh_total_state()


func _on_slider_value_changed(value: float, attribute_key: String) -> void:
	## 滑条变化后把整数值同步到数字框，并刷新总点数校验。
	_sync_attribute_controls(attribute_key, value, true)


func _on_spin_box_value_changed(value: float, attribute_key: String) -> void:
	## 数字框输入或箭头变化后把整数值同步到滑条；手动小数会四舍五入为最近整数。
	_sync_attribute_controls(attribute_key, value, false)


func _sync_attribute_controls(attribute_key: String, value: float, source_is_slider: bool) -> void:
	## 双向同步同一属性的滑条与数字框；同步期间只写一次目标控件，避免递归信号循环。
	if _synchronizing_attribute_controls:
		return
	_synchronizing_attribute_controls = true
	# 标准整数值；输入框粘贴小数时也不会把小数属性写入最终结果。
	var integer_value: float = float(roundi(value))
	# 当前数字框；用于数字显示和最终结果读取。
	var attribute_input: SpinBox = _attribute_inputs.get(attribute_key) as SpinBox
	# 当前滑条；用于拖动调整和显示在合法区间内的位置。
	var attribute_slider: HSlider = _attribute_sliders.get(attribute_key) as HSlider
	if attribute_input != null and (source_is_slider or not is_equal_approx(attribute_input.value, integer_value)):
		attribute_input.value = integer_value
	if attribute_slider != null and (not source_is_slider or not is_equal_approx(attribute_slider.value, integer_value)):
		attribute_slider.value = integer_value
	_synchronizing_attribute_controls = false
	_refresh_total_state()


func _refresh_total_state() -> void:
	## 更新整数总点数文本和确认按钮；五项之和必须精确等于目标点数。
	if _total_label == null:
		return
	# 当前五维总点数；逐输入累加，用于守恒校验和界面提示。
	var current_total: int = 0
	for raw_input in _attribute_inputs.values():
		# 当前属性输入；只累计有效 SpinBox 的实时值。
		var attribute_input: SpinBox = raw_input as SpinBox
		if attribute_input != null:
			current_total += roundi(attribute_input.value)
	# 分配是否合法；整数总和必须与目标 495 点完全一致。
	var allocation_valid: bool = current_total == roundi(_total_attribute_points)
	_total_label.text = "总点数：%d / %d" % [current_total, roundi(_total_attribute_points)]
	_total_label.modulate = Color.WHITE if allocation_valid else Color(1.0, 0.46, 0.38, 1.0)
	get_ok_button().disabled = not allocation_valid


func _on_confirmed() -> void:
	## 返回五维结构化结果；调用方通过现有属性组件接口应用，本弹窗不直接访问玩家或存档。
	# 属性结果；键使用角色统一属性名，值强制为整数点数。
	var attributes: Dictionary = {}
	for definition in ATTRIBUTE_DEFINITIONS:
		# 当前属性键；与 CharacterData 和玩家应用接口字段保持一致。
		var attribute_key: String = str(definition.get("key", ""))
		# 当前属性输入；存在时把最终值写入结果字典。
		var attribute_input: SpinBox = _attribute_inputs.get(attribute_key) as SpinBox
		if attribute_input != null:
			attributes[attribute_key] = roundi(attribute_input.value)
	allocation_confirmed.emit(attributes)


func _keep_dialog_open() -> void:
	## 被动要求进入游戏时完成一次分配；关闭请求在下一帧重新显示，避免绕过五维配置。
	call_deferred("present")
