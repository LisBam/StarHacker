extends ConfirmationDialog
class_name LeveragePositionDialog

## 杠杆开仓弹窗只负责方向、杠杆倍数与整数保证金的输入和费用预览，不直接读取行情、余额或存档服务。
## 宿主负责传入实时价格与可用证券币并持续刷新，确认后由股市服务按点击瞬间的实时行情执行最终原子开仓。

signal leverage_confirmed(direction: int, leverage: int, margin: int)

## 全局窗口样式指南；统一杠杆弹窗的按钮、输入、滑条和窗口描边视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 可视进度拖动条组件；统一绘制保证金金额的完整范围、当前进度与滑块位置。
const PROGRESS_SLIDER_VISUAL_SCRIPT: Script = preload("res://scripts/ui/progress_slider_visual.gd")
## 弹窗最外层框架组件；直接绘制不透明标题栏、外框、标题文字和关闭按钮。
const DIALOG_OUTER_FRAME_SCRIPT: Script = preload("res://scripts/ui/dialog_outer_frame.gd")
## 杠杆做多方向标识；与 StockMarketService.LEVERAGE_LONG 保持一致。
const DIRECTION_LONG: int = 1
## 杠杆做空方向标识；与 StockMarketService.LEVERAGE_SHORT 保持一致。
const DIRECTION_SHORT: int = -1

## 弹窗默认宽度；默认 430 像素，完整容纳方向行、倍数行、保证金输入和两行费用预览，运行时无需动态修改。
@export_range(360, 640, 1) var dialog_width: int = 430
## 弹窗默认高度；默认 252 像素，与证券转账弹窗同风格且首次打开即为稳定尺寸，运行时无需动态修改。
## 高倍扩展补充；倍数按钮改为 4 列双行网格后当前默认高度为 292 像素。
@export_range(200, 400, 1) var dialog_height: int = 292
## 弹窗背景透明度；默认 0.82，与股票数量选择和证券转账弹窗保持一致，运行时无需动态修改。
@export_range(0.40, 1.0, 0.01) var dialog_background_alpha: float = 0.82

## 当前展示的股票名称；默认空字符串，由宿主在打开时提供，仅用于说明文本。
var _stock_display_name: String = ""
## 当前实时价格；默认 0.0，宿主每次行情刷新都会覆盖，用于强平价预览。
var _current_price: float = 0.0
## 当前可用证券币余额；默认 0.0，宿主实时提供，用于计算保证金上限与确认可用性。
var _available_balance: float = 0.0
## 当前杠杆手续费比例；默认 0.005 即名义本金的 0.5%，预览公式与股市服务保持一致。
var _fee_ratio: float = 0.005
## 当前最低开仓保证金；默认 10 整数证券币，低于该值的输入直接被滑条下限拦截。
var _minimum_margin: int = 10
## 当前强平亏损线；默认 0.90 即浮亏达保证金 90% 强平，用于计算预计强平价。
var _liquidation_loss_ratio: float = 0.90
## 当前选中方向；默认做多，取值只会是做多或做空常量。
var _selected_direction: int = DIRECTION_LONG
## 当前选中杠杆倍数；默认取倍数目录第一项，切换时会同步收紧保证金上限。
var _selected_leverage: int = 2
## 可选杠杆倍数目录；默认 2、3、5，由宿主从股市服务传入，保证与最终校验一致。
## 高倍扩展补充；默认目录与服务同步为 2 至 999 共 8 档，界面按 4 列网格双行排列。
var _multipliers: Array[int] = [2, 3, 5, 10, 20, 50, 100, 999]
## 方向切换按钮表；键为方向常量，值为对应的可切换按钮。
var _direction_buttons: Dictionary = {}
## 倍数切换按钮表；键为整数倍数，值为对应的可切换按钮。
var _multiplier_buttons: Dictionary = {}
## 保证金滑条；默认运行时创建，使用整数步长并与数字输入框保持双向同步。
var _margin_slider: HSlider
## 保证金输入框；默认运行时创建，只允许输入最低到当前上限之间的整数，并与滑条保持双向同步。
var _margin_spin_box: SpinBox
## 开仓说明标签；默认运行时创建，显示股票名称、实时价格和可用余额。
var _description_label: Label
## 费用预览标签；默认运行时创建，显示名义本金、手续费、总花费和预计强平价。
var _result_label: Label
## 界面是否已经初始化；默认 false，公开展示接口会通过幂等初始化保证控件可用。
var _interface_initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_interface_initialized()


func present_open(stock_display_name: String, current_price: float, available_balance: float, fee_ratio: float, minimum_margin: int, liquidation_loss_ratio: float, multipliers: Array) -> void:
	## 展示杠杆开仓界面；每次打开重置为做多、最低倍数和最低保证金，避免沿用上次高风险配置造成误操作。
	_ensure_interface_initialized()
	_stock_display_name = stock_display_name
	_current_price = maxf(current_price, 0.01)
	_available_balance = maxf(available_balance, 0.0)
	_fee_ratio = clampf(fee_ratio, 0.0, 1.0)
	_minimum_margin = maxi(minimum_margin, 1)
	_liquidation_loss_ratio = clampf(liquidation_loss_ratio, 0.0, 1.0)
	# 合法倍数目录；宿主传入空数组时保留默认目录，防止界面出现零个倍数按钮。
	if not multipliers.is_empty():
		_multipliers.clear()
		for multiplier in multipliers:
			_multipliers.append(int(multiplier))
	_selected_direction = DIRECTION_LONG
	_selected_leverage = _multipliers[0]
	_rebuild_multiplier_buttons()
	_apply_direction_selection()
	title = "杠杆开仓 · %s" % stock_display_name
	get_ok_button().text = "确认开仓"
	# 保证金输入重置；范围按当前余额与选中倍数收紧，默认停在最低保证金。
	_refresh_margin_range(true)
	_refresh_preview()
	popup_centered(Vector2i(dialog_width, dialog_height))


func update_market(current_price: float, available_balance: float) -> void:
	## 刷新已打开弹窗的实时行情；保留玩家当前方向、倍数与保证金选择，并在余额上限下降时安全收紧金额。
	if not visible:
		return
	_current_price = maxf(current_price, 0.01)
	_available_balance = maxf(available_balance, 0.0)
	_refresh_margin_range(false)
	_refresh_preview()


func _ensure_interface_initialized() -> void:
	## 初始化杠杆输入控件与统一视觉；允许弹窗创建后同一帧直接调用展示接口。
	if _interface_initialized:
		return
	_interface_initialized = true
	# 窗口透明模式；关闭原生透明合成，保证包围标题栏与内容区域的最外层背景和青蓝描边保持完全可见。
	transparent = false
	unresizable = true
	get_cancel_button().text = "取消"
	_apply_dialog_visual_style()
	_build_interface()
	# 弹窗内部根面板；登记后黑白风格覆盖说明、按钮、滑条、数字输入、结果和操作按钮。
	var dialog_content_root: Control = get_child(0, true) as Control
	if dialog_content_root != null:
		UI_STYLE_GUIDE.apply_screen_theme(dialog_content_root)
	DIALOG_OUTER_FRAME_SCRIPT.install(self)
	confirmed.connect(_on_confirmed)
	# UI 风格服务；弹窗可能在设置切换前已经初始化，监听后重建 Window 自身样式。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))


func _build_interface() -> void:
	## 创建固定内容结构；纵向排列开仓说明、方向选择、倍数选择、保证金输入和费用预览。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_bottom", 1)
	add_child(content_margin)
	# 内容容器；统一使用 8 像素间距保持紧凑且可读。
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content_margin.add_child(content)
	_description_label = Label.new()
	# 自动换行基准宽度；动态 Window 首次布局前没有可用父级宽度，显式提供宽度可避免文字按 1 像素宽逐字换行并撑高窗口。
	_description_label.custom_minimum_size = Vector2(float(dialog_width - 48), 0.0)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_description_label)
	# 方向选择行；做多与做空互斥切换，按下状态由统一主题的按压样式呈现。
	var direction_row: HBoxContainer = HBoxContainer.new()
	direction_row.add_theme_constant_override("separation", 8)
	content.add_child(direction_row)
	# 方向互斥组；保证任意时刻只有一个方向按钮处于按下状态。
	var direction_group: ButtonGroup = ButtonGroup.new()
	for direction in [DIRECTION_LONG, DIRECTION_SHORT]:
		# 单个方向按钮；做多在左、做空在右，均分整行宽度。
		var direction_button: Button = Button.new()
		direction_button.text = "做多（涨盈利）" if direction == DIRECTION_LONG else "做空（跌盈利）"
		direction_button.toggle_mode = true
		direction_button.button_group = direction_group
		direction_button.focus_mode = Control.FOCUS_NONE
		direction_button.custom_minimum_size = Vector2(0.0, 34.0)
		direction_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		direction_button.pressed.connect(_on_direction_selected.bind(direction))
		direction_row.add_child(direction_button)
		_direction_buttons[direction] = direction_button
	# 倍数选择行；按倍数目录动态生成互斥按钮，打开时可能按服务目录重建。
	# 高倍扩展补充；倍数增至 8 档后改用 4 列网格容器，自动折成双行且每格等宽。
	var multiplier_row: GridContainer = GridContainer.new()
	multiplier_row.name = "MultiplierRow"
	multiplier_row.columns = 4
	multiplier_row.add_theme_constant_override("h_separation", 8)
	multiplier_row.add_theme_constant_override("v_separation", 4)
	content.add_child(multiplier_row)
	_rebuild_multiplier_buttons()
	# 保证金输入行；滑条负责快速选择，数字输入框负责键盘精确输入，与证券转账窗口保持一致。
	var margin_row: HBoxContainer = HBoxContainer.new()
	margin_row.add_theme_constant_override("separation", 8)
	content.add_child(margin_row)
	_margin_slider = HSlider.new()
	_margin_slider.min_value = 1.0
	_margin_slider.max_value = 1.0
	_margin_slider.step = 1.0
	_margin_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin_slider.value_changed.connect(_on_margin_slider_changed)
	margin_row.add_child(_margin_slider)
	PROGRESS_SLIDER_VISUAL_SCRIPT.install(_margin_slider)
	_margin_spin_box = SpinBox.new()
	_margin_spin_box.min_value = 1.0
	_margin_spin_box.max_value = 1.0
	_margin_spin_box.step = 1.0
	_margin_spin_box.allow_greater = false
	_margin_spin_box.allow_lesser = false
	_margin_spin_box.custom_minimum_size = Vector2(82.0, 32.0)
	_margin_spin_box.value_changed.connect(_on_margin_spin_box_changed)
	margin_row.add_child(_margin_spin_box)
	_result_label = Label.new()
	_result_label.custom_minimum_size = Vector2(float(dialog_width - 48), 0.0)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_result_label)


func _rebuild_multiplier_buttons() -> void:
	## 按当前倍数目录重建倍数按钮；目录未变化时保留既有按钮，避免每次打开重复销毁节点。
	# 倍数按钮行；界面尚未构建时直接跳过，首次构建流程会再次调用。
	# 高倍扩展补充；容器类型随布局改为 4 列网格。
	var multiplier_row: GridContainer = null
	if _interface_initialized and get_child_count(true) > 0:
		multiplier_row = find_child("MultiplierRow", true, false) as GridContainer
	if multiplier_row == null:
		return
	# 目录一致性检查；按钮数量与倍数目录完全一致时只同步按下状态。
	if _multiplier_buttons.size() == _multipliers.size():
		# 目录是否完全命中；任何一个倍数缺少按钮都会触发重建。
		var all_present: bool = true
		for multiplier in _multipliers:
			if not _multiplier_buttons.has(multiplier):
				all_present = false
				break
		if all_present:
			_apply_multiplier_selection()
			return
	for child in multiplier_row.get_children():
		child.queue_free()
	_multiplier_buttons.clear()
	# 倍数互斥组；保证任意时刻只有一个倍数按钮处于按下状态。
	var multiplier_group: ButtonGroup = ButtonGroup.new()
	for multiplier in _multipliers:
		# 单个倍数按钮；按目录顺序排列并均分整行宽度。
		# 高倍扩展补充；8 档倍数按 4 列网格排列，文本缩短为纯倍率并固定统一最小宽度保证双行整齐。
		var multiplier_button: Button = Button.new()
		multiplier_button.text = "%d×" % multiplier
		multiplier_button.toggle_mode = true
		multiplier_button.button_group = multiplier_group
		multiplier_button.focus_mode = Control.FOCUS_NONE
		multiplier_button.custom_minimum_size = Vector2(86.0, 34.0)
		multiplier_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		multiplier_button.pressed.connect(_on_multiplier_selected.bind(multiplier))
		multiplier_row.add_child(multiplier_button)
		_multiplier_buttons[multiplier] = multiplier_button
	_apply_multiplier_selection()


func _apply_direction_selection() -> void:
	## 同步方向按钮按下状态；只呈现当前选中方向，不触发按钮信号。
	for direction in _direction_buttons.keys():
		(_direction_buttons[direction] as Button).set_pressed_no_signal(int(direction) == _selected_direction)


func _apply_multiplier_selection() -> void:
	## 同步倍数按钮按下状态；只呈现当前选中倍数，不触发按钮信号。
	for multiplier in _multiplier_buttons.keys():
		(_multiplier_buttons[multiplier] as Button).set_pressed_no_signal(int(multiplier) == _selected_leverage)


func _apply_dialog_visual_style() -> void:
	## 应用半透明深色窗口样式；规格与证券转账弹窗一致，保持股市弹窗视觉统一。
	var dialog_theme: Theme = UI_STYLE_GUIDE.create_theme()
	# 窗口面板样式；透明度由检查器参数统一控制。
	var dialog_panel_style: StyleBoxFlat = UI_STYLE_GUIDE.create_dialog_panel_style(dialog_background_alpha)
	# 面板左右留白；统一函数默认 14 像素，本弹窗内容已有专用 MarginContainer，回退为跟随边框的自动留白以保持原布局。
	dialog_panel_style.content_margin_left = -1.0
	dialog_panel_style.content_margin_right = -1.0
	dialog_panel_style.content_margin_top = UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT
	dialog_panel_style.content_margin_bottom = UI_STYLE_GUIDE.DIALOG_ACTION_BOTTOM_CLEARANCE
	dialog_theme.set_stylebox("panel", "Window", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "AcceptDialog", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "ConfirmationDialog", dialog_panel_style)
	theme = dialog_theme


func _on_ui_style_changed(_style_id: String) -> void:
	## 风格切换后重建杠杆弹窗背景、边框和基础控件主题，当前方向、倍数与保证金配置保持不变。
	_apply_dialog_visual_style()
	DIALOG_OUTER_FRAME_SCRIPT.install(self)


func _on_direction_selected(direction: int) -> void:
	## 切换开仓方向；方向不影响保证金上限，只需要刷新强平价预览。
	_selected_direction = DIRECTION_SHORT if direction < 0 else DIRECTION_LONG
	_refresh_preview()


func _on_multiplier_selected(multiplier: int) -> void:
	## 切换杠杆倍数；倍数越高开仓手续费越高，保证金上限会同步收紧后刷新预览。
	if multiplier in _multipliers:
		_selected_leverage = multiplier
	_refresh_margin_range(false)
	_refresh_preview()


func _on_margin_slider_changed(value: float) -> void:
	## 同步滑条选择到数字框；显式取整保证保证金始终为整数。
	var resolved_margin: int = clampi(roundi(value), _minimum_margin, _get_current_maximum_margin())
	_margin_spin_box.set_value_no_signal(float(resolved_margin))
	_refresh_preview()


func _on_margin_spin_box_changed(value: float) -> void:
	## 同步数字输入到滑条；直接键盘输入同样限制在当前合法额度内。
	var resolved_margin: int = clampi(roundi(value), _minimum_margin, _get_current_maximum_margin())
	_margin_slider.set_value_no_signal(float(resolved_margin))
	_refresh_preview()


func _get_current_maximum_margin() -> int:
	## 计算当前倍数与余额下的最大整数保证金；保证金加名义本金手续费不得超过可用余额，公式与股市服务一致。
	# 估算保证金上限；先按含费比例推算，再向上、向下各做有限次校验。
	var estimated_margin: int = maxi(floori(_available_balance / (1.0 + float(_selected_leverage) * _fee_ratio)), 0)
	while _calculate_total_cost(estimated_margin + 1) <= _available_balance + 0.0001:
		estimated_margin += 1
	while estimated_margin > 0 and _calculate_total_cost(estimated_margin) > _available_balance + 0.0001:
		estimated_margin -= 1
	return estimated_margin


func _calculate_total_cost(margin: int) -> float:
	## 计算指定整数保证金的开仓总花费；保证金加名义本金手续费，手续费公式与股市服务保持一致。
	if margin <= 0:
		return 0.0
	# 名义本金；保证金乘当前选中杠杆倍数。
	var notional: float = float(margin) * float(_selected_leverage)
	# 开仓手续费；乘 100 后向上取整且最低 0.01 证券币，微小容差避免整分浮点数被多收 0.01。
	var fee: float = maxf(float(ceili(maxf(notional * _fee_ratio * 100.0 - 0.000001, 0.0))) / 100.0, 0.01)
	return snappedf(float(margin) + fee, 0.01)


func _refresh_margin_range(reset_to_minimum: bool) -> void:
	## 刷新保证金滑条与数字框范围；上限低于下限时锁定为下限并交由预览阶段禁用确认按钮。
	# 当前保证金上限；至少等于最低保证金，保证滑条范围始终合法。
	var maximum_margin: int = maxi(_get_current_maximum_margin(), _minimum_margin)
	_margin_slider.min_value = float(_minimum_margin)
	_margin_slider.max_value = float(maximum_margin)
	_margin_spin_box.min_value = float(_minimum_margin)
	_margin_spin_box.max_value = float(maximum_margin)
	# 目标保证金；打开时重置为下限，行情刷新时保留玩家选择并按新上限收紧。
	var target_margin: int = _minimum_margin if reset_to_minimum else clampi(roundi(_margin_spin_box.value), _minimum_margin, maximum_margin)
	_margin_slider.set_value_no_signal(float(target_margin))
	_margin_spin_box.set_value_no_signal(float(target_margin))


func _refresh_preview() -> void:
	## 刷新说明与费用预览；余额不足最低保证金时禁用确认按钮，最终成交仍由股市服务重新校验。
	_description_label.text = "%s · 现价 %.2f 证券币 · 可用 %.2f 证券币" % [_stock_display_name, _current_price, _available_balance]
	# 当前选择保证金；预览与确认信号使用同一取整结果。
	var margin: int = clampi(roundi(_margin_spin_box.value), _minimum_margin, maxi(_get_current_maximum_margin(), _minimum_margin))
	# 当前名义本金；保证金乘选中倍数。
	var notional: float = float(margin) * float(_selected_leverage)
	# 当前开仓总花费；含名义本金手续费。
	var total_cost: float = _calculate_total_cost(margin)
	# 预计强平价；按当前实时价估算，最终以确认瞬间的实际开仓价为准。
	var direction_sign: float = -1.0 if _selected_direction < 0 else 1.0
	# 强平触发价格变化率；强平亏损线除以杠杆倍数。
	var liquidation_price: float = maxf(snappedf(_current_price * (1.0 - direction_sign * _liquidation_loss_ratio / float(_selected_leverage)), 0.01), 0.0)
	_result_label.text = "名义本金 %.2f · 手续费 %.2f · 总花费 %.2f\n预计强平价 %.2f（浮亏达保证金 %.0f%% 强制平仓）" % [notional, total_cost - float(margin), total_cost, liquidation_price, _liquidation_loss_ratio * 100.0]
	# 确认可用状态；总花费超过可用余额时禁用，价格与余额恢复后由宿主的实时刷新自动解除。
	get_ok_button().disabled = total_cost > _available_balance + 0.0001


func _on_confirmed() -> void:
	## 发出最终方向、倍数与整数保证金；宿主必须调用股市服务重新校验余额与仓位唯一性。
	var confirmed_margin: int = clampi(roundi(_margin_spin_box.value), _minimum_margin, maxi(_get_current_maximum_margin(), _minimum_margin))
	leverage_confirmed.emit(_selected_direction, _selected_leverage, confirmed_margin)
