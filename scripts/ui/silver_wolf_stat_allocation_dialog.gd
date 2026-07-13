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

## 弹窗固定尺寸；默认 520×430 像素，容纳五行输入、总点数和底部确认按钮。
@export var dialog_size: Vector2i = Vector2i(520, 430)
## 每行属性控件的最小高度；默认 42 像素，保证中文标签与数值微调按钮具有稳定点击区域。
@export_range(28.0, 72.0, 1.0) var row_minimum_height: float = 42.0
## 数值输入控件宽度；默认 180 像素，可完整显示一位小数与两侧微调按钮。
@export_range(120.0, 260.0, 1.0) var spin_box_width: float = 180.0

## 五维共同基准值；默认 99，setup 时由被动技能资源覆盖。
var _base_attribute_value: float = 99.0
## 单项最大浮动比例；默认 0.20，setup 时用于计算每个输入的最小值与最大值。
var _maximum_adjustment_ratio: float = 0.20
## 数值输入步长；默认 0.1，setup 时由技能资源覆盖并用于总点数精度判断。
var _allocation_step: float = 0.1
## 五维总点数；默认 495，由共同基准乘五得到，确认时必须保持不变。
var _total_attribute_points: float = 495.0
## 属性输入表；键为稳定属性名、值为对应 SpinBox，默认空字典并在 ready 时构建。
var _attribute_inputs: Dictionary = {}
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
	_allocation_step = maxf(allocation_step, 0.1)
	_total_attribute_points = _base_attribute_value * float(ATTRIBUTE_DEFINITIONS.size())
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
		# 属性名称；直接使用权威五维术语，不在运行时拼接额外玩法说明。
		var attribute_label: Label = Label.new()
		attribute_label.text = str(definition.get("label", "属性"))
		attribute_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attribute_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(attribute_label)
		# 属性数值输入；最小值、最大值、步长和默认值由统一配置函数写入。
		var attribute_input: SpinBox = SpinBox.new()
		attribute_input.custom_minimum_size = Vector2(spin_box_width, row_minimum_height)
		attribute_input.allow_greater = false
		attribute_input.allow_lesser = false
		attribute_input.value_changed.connect(_on_value_changed)
		row.add_child(attribute_input)
		_attribute_inputs[str(definition.get("key", ""))] = attribute_input
	_total_label = Label.new()
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.ACCENT_COLOR)
	_content_box.add_child(_total_label)


func _apply_input_limits() -> void:
	## 把共同基准与浮动比例应用到全部输入；每次配置重置为等值分配，避免角色切换沿用旧战斗选择。
	# 单项最小值；共同基准按最大负向浮动比例计算。
	var minimum_value: float = _base_attribute_value * (1.0 - _maximum_adjustment_ratio)
	# 单项最大值；共同基准按最大正向浮动比例计算。
	var maximum_value: float = _base_attribute_value * (1.0 + _maximum_adjustment_ratio)
	for raw_input in _attribute_inputs.values():
		# 当前属性输入；异常非 SpinBox 项安全跳过，不影响其他四维配置。
		var attribute_input: SpinBox = raw_input as SpinBox
		if attribute_input == null:
			continue
		attribute_input.min_value = minimum_value
		attribute_input.max_value = maximum_value
		attribute_input.step = _allocation_step
		attribute_input.value = _base_attribute_value
	_refresh_total_state()


func _on_value_changed(_value: float) -> void:
	## 任一属性变化后只刷新总点数校验，不自动改写其他属性，保持玩家明确控制每次分配。
	_refresh_total_state()


func _refresh_total_state() -> void:
	## 更新总点数文本和确认按钮；误差限制为半个输入步长，兼容浮点小数表示。
	if _total_label == null:
		return
	# 当前五维总点数；逐输入累加，用于守恒校验和界面提示。
	var current_total: float = 0.0
	for raw_input in _attribute_inputs.values():
		# 当前属性输入；只累计有效 SpinBox 的实时值。
		var attribute_input: SpinBox = raw_input as SpinBox
		if attribute_input != null:
			current_total += attribute_input.value
	# 分配是否合法；允许半个输入步长的浮点误差，不允许实际多出或缺少一档点数。
	var allocation_valid: bool = absf(current_total - _total_attribute_points) <= _allocation_step * 0.5
	_total_label.text = "总点数：%.1f / %.1f" % [current_total, _total_attribute_points]
	_total_label.modulate = Color.WHITE if allocation_valid else Color(1.0, 0.46, 0.38, 1.0)
	get_ok_button().disabled = not allocation_valid


func _on_confirmed() -> void:
	## 返回五维结构化结果；调用方通过现有属性组件接口应用，本弹窗不直接访问玩家或存档。
	# 属性结果；键使用角色统一属性名，值为玩家确认的浮点点数。
	var attributes: Dictionary = {}
	for definition in ATTRIBUTE_DEFINITIONS:
		# 当前属性键；与 CharacterData 和玩家应用接口字段保持一致。
		var attribute_key: String = str(definition.get("key", ""))
		# 当前属性输入；存在时把最终值写入结果字典。
		var attribute_input: SpinBox = _attribute_inputs.get(attribute_key) as SpinBox
		if attribute_input != null:
			attributes[attribute_key] = attribute_input.value
	allocation_confirmed.emit(attributes)


func _keep_dialog_open() -> void:
	## 被动要求进入游戏时完成一次分配；关闭请求在下一帧重新显示，避免绕过五维配置。
	call_deferred("present")
