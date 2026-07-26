extends ConfirmationDialog
class_name StockStopOrderDialog

## 止盈止损设置弹窗只负责选择目标类型（现货持仓 / 杠杆仓位）、输入止盈价与止损价并做本地方向预览。
## 弹窗不读取行情、持仓或存档服务；宿主在打开与每秒行情刷新时传入实时价格与持仓快照，确认后由股市服务按同一规则原子校验。
## 价格约定；输入 0 或留空表示该方向不启用，止盈价必须位于当前价的盈利方向、止损价必须位于亏损方向，做空仓位方向整体翻转。

## 保存设置信号；携带目标类型（spot / leverage）与两位小数目标价，宿主必须调用股市服务重新校验后执行。
signal stop_order_confirmed(kind: String, take_profit_price: float, stop_loss_price: float)
## 清除设置信号；携带目标类型，宿主调用股市服务清除对应档案，弹窗在发出信号前自行关闭。
signal stop_order_clear_requested(kind: String)

## 全局窗口样式指南；统一止盈止损弹窗的按钮、输入框和窗口描边视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 弹窗最外层框架组件；直接绘制不透明标题栏、外框、标题文字和关闭按钮。
const DIALOG_OUTER_FRAME_SCRIPT: Script = preload("res://scripts/ui/dialog_outer_frame.gd")
## 现货目标类型标识；与 StockMarketService.STOP_ORDER_KIND_SPOT 保持一致。
const KIND_SPOT: String = "spot"
## 杠杆目标类型标识；与 StockMarketService.STOP_ORDER_KIND_LEVERAGE 保持一致。
const KIND_LEVERAGE: String = "leverage"
## 清除按钮的自定义动作标识；custom_action 信号据此识别清除请求。
const CLEAR_ACTION: String = "clear_stop_order"

## 弹窗默认宽度；默认 430 像素，与杠杆开仓弹窗同规格，完整容纳目标切换行与两行价格输入，运行时无需动态修改。
@export_range(360, 640, 1) var dialog_width: int = 430
## 弹窗默认高度；默认 330 像素，纵向容纳说明、目标切换、两行输入与两行预览，运行时无需动态修改。
@export_range(240, 480, 1) var dialog_height: int = 330
## 弹窗背景透明度；默认 0.82，与股票数量选择和杠杆开仓弹窗保持一致，运行时无需动态修改。
@export_range(0.40, 1.0, 0.01) var dialog_background_alpha: float = 0.82

## 当前展示的股票名称；默认空字符串，由宿主在打开时提供，仅用于说明文本。
var _stock_display_name: String = ""
## 当前实时价格；默认 0.0，宿主每次行情刷新都会覆盖，用于方向校验与预览。
var _current_price: float = 0.0
## 当前现货持股数量；默认 0，为 0 时现货目标按钮禁用。
var _spot_quantity: int = 0
## 当前杠杆仓位快照；默认空字典表示没有仓位，非空时提供方向与倍数用于预览。
var _leverage_position: Dictionary = {}
## 现货已有档案；默认空字典，打开与切换目标时用于预填输入框。
var _spot_order: Dictionary = {}
## 杠杆已有档案；默认空字典，打开与切换目标时用于预填输入框。
var _leverage_order: Dictionary = {}
## 当前选中目标类型；默认现货，打开时按实际持仓自动选择首个可用目标。
var _selected_kind: String = KIND_SPOT
## 目标类型切换按钮表；键为目标类型标识，值为对应的可切换按钮。
var _kind_buttons: Dictionary = {}
## 止盈价输入框；默认运行时创建，留空或 0 表示不启用止盈。
var _take_profit_edit: LineEdit
## 止损价输入框；默认运行时创建，留空或 0 表示不启用止损。
var _stop_loss_edit: LineEdit
## 止盈方向提示标签；默认运行时创建，按盈利方向显示“≥ / ≤ 目标价触发”。
var _take_profit_hint_label: Label
## 止损方向提示标签；默认运行时创建，按亏损方向显示“≤ / ≥ 目标价触发”。
var _stop_loss_hint_label: Label
## 设置说明标签；默认运行时创建，显示股票名称、实时价格与当前目标持仓概要。
var _description_label: Label
## 校验预览标签；默认运行时创建，显示当前输入的合法性结论或触发规则说明。
var _result_label: Label
## 清除设置按钮；默认运行时创建，仅当前目标已有档案时可用。
var _clear_button: Button
## 界面是否已经初始化；默认 false，公开展示接口会通过幂等初始化保证控件可用。
var _interface_initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_interface_initialized()


func present_stop_order(stock_display_name: String, current_price: float, spot_quantity: int, leverage_position: Dictionary, spot_order: Dictionary, leverage_order: Dictionary) -> void:
	## 展示止盈止损设置界面；按当前持仓自动选中首个可用目标并预填已有档案，宿主随每秒行情调用 update_market 刷新。
	_ensure_interface_initialized()
	_stock_display_name = stock_display_name
	_current_price = maxf(current_price, 0.01)
	_spot_quantity = maxi(spot_quantity, 0)
	_leverage_position = leverage_position.duplicate(true)
	_spot_order = spot_order.duplicate(true)
	_leverage_order = leverage_order.duplicate(true)
	# 默认目标类型；优先现货持仓，没有现货时回退杠杆仓位，两者由宿主保证至少存在一个。
	_selected_kind = KIND_SPOT if _spot_quantity > 0 else KIND_LEVERAGE
	title = "止盈止损 · %s" % stock_display_name
	get_ok_button().text = "保存设置"
	_apply_kind_availability()
	_apply_kind_selection()
	_fill_inputs_from_order()
	_refresh_preview()
	popup_centered(Vector2i(dialog_width, dialog_height))


func update_market(current_price: float, spot_quantity: int, leverage_position: Dictionary) -> void:
	## 刷新已打开弹窗的实时行情与持仓；保留玩家当前输入，仅重新校验方向合法性与目标可用性。
	if not visible:
		return
	_current_price = maxf(current_price, 0.01)
	_spot_quantity = maxi(spot_quantity, 0)
	_leverage_position = leverage_position.duplicate(true)
	_apply_kind_availability()
	# 目标失效兜底；当前目标持仓消失（清仓或被强平）时预览阶段会禁用确认按钮并提示原因。
	_refresh_preview()


func _ensure_interface_initialized() -> void:
	## 初始化输入控件与统一视觉；允许弹窗创建后同一帧直接调用展示接口。
	if _interface_initialized:
		return
	_interface_initialized = true
	# 窗口透明模式；关闭原生透明合成，保证最外层背景和青蓝描边完全可见。
	transparent = false
	unresizable = true
	get_cancel_button().text = "取消"
	# 清除设置按钮；位于取消按钮一侧，通过自定义动作标识路由到清除信号。
	_clear_button = add_button("清除设置", false, CLEAR_ACTION)
	_apply_dialog_visual_style()
	_build_interface()
	# 弹窗内部根面板；登记后黑白风格覆盖说明、输入框、按钮与预览文本。
	var dialog_content_root: Control = get_child(0, true) as Control
	if dialog_content_root != null:
		UI_STYLE_GUIDE.apply_screen_theme(dialog_content_root)
	DIALOG_OUTER_FRAME_SCRIPT.install(self)
	confirmed.connect(_on_confirmed)
	custom_action.connect(_on_custom_action)
	# UI 风格服务；弹窗可能在设置切换前已经初始化，监听后重建 Window 自身样式。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))


func _build_interface() -> void:
	## 创建固定内容结构；纵向排列设置说明、目标类型切换、止盈价输入、止损价输入与校验预览。
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
	# 自动换行基准宽度；动态 Window 首次布局前没有可用父级宽度，显式提供宽度避免逐字换行撑高窗口。
	_description_label.custom_minimum_size = Vector2(float(dialog_width - 48), 0.0)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_description_label)
	# 目标类型切换行；现货与杠杆互斥切换，按下状态由统一主题的按压样式呈现。
	var kind_row: HBoxContainer = HBoxContainer.new()
	kind_row.add_theme_constant_override("separation", 8)
	content.add_child(kind_row)
	# 目标互斥组；保证任意时刻只有一个目标按钮处于按下状态。
	var kind_group: ButtonGroup = ButtonGroup.new()
	for kind in [KIND_SPOT, KIND_LEVERAGE]:
		# 单个目标按钮；现货在左、杠杆在右，均分整行宽度。
		var kind_button: Button = Button.new()
		kind_button.text = "现货持仓" if kind == KIND_SPOT else "杠杆仓位"
		kind_button.toggle_mode = true
		kind_button.button_group = kind_group
		kind_button.focus_mode = Control.FOCUS_NONE
		kind_button.custom_minimum_size = Vector2(0.0, 34.0)
		kind_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kind_button.pressed.connect(_on_kind_selected.bind(kind))
		kind_row.add_child(kind_button)
		_kind_buttons[kind] = kind_button
	# 止盈价输入行；标题、数字输入与触发方向提示同排。
	_take_profit_edit = _build_price_input_row(content, "止盈价")
	_take_profit_hint_label = _extract_row_hint(_take_profit_edit)
	# 止损价输入行；结构与止盈行一致。
	_stop_loss_edit = _build_price_input_row(content, "止损价")
	_stop_loss_hint_label = _extract_row_hint(_stop_loss_edit)
	_result_label = Label.new()
	_result_label.custom_minimum_size = Vector2(float(dialog_width - 48), 0.0)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_result_label)


func _build_price_input_row(parent: Control, title_text: String) -> LineEdit:
	## 创建一行目标价输入；返回行内的 LineEdit，提示标签通过元数据挂在输入框上供后续读取。
	# 输入行容器；标题固定宽度，输入框与提示均分剩余空间。
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	# 行标题；固定 64 像素宽保证两行输入对齐。
	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.custom_minimum_size = Vector2(64.0, 0.0)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)
	# 目标价输入框；留空或 0 表示不启用该方向。
	var price_edit: LineEdit = LineEdit.new()
	price_edit.placeholder_text = "留空 = 不启用"
	price_edit.custom_minimum_size = Vector2(130.0, 32.0)
	price_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_edit.text_changed.connect(_on_price_text_changed)
	row.add_child(price_edit)
	# 触发方向提示；按当前目标的盈利方向动态刷新。
	var hint_label: Label = Label.new()
	hint_label.custom_minimum_size = Vector2(132.0, 0.0)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	UI_STYLE_GUIDE.apply_secondary_label(hint_label)
	row.add_child(hint_label)
	price_edit.set_meta("hint_label", hint_label)
	return price_edit


func _extract_row_hint(price_edit: LineEdit) -> Label:
	## 读取输入行创建时挂载的提示标签；与 _build_price_input_row 配套使用。
	return price_edit.get_meta("hint_label") as Label


func _apply_dialog_visual_style() -> void:
	## 应用半透明深色窗口样式；规格与杠杆开仓弹窗一致，保持股市弹窗视觉统一。
	var dialog_theme: Theme = UI_STYLE_GUIDE.create_theme()
	# 窗口面板样式；透明度由检查器参数统一控制。
	var dialog_panel_style: StyleBoxFlat = UI_STYLE_GUIDE.create_dialog_panel_style(dialog_background_alpha)
	# 面板左右留白；本弹窗内容已有专用 MarginContainer，回退为跟随边框的自动留白以保持原布局。
	dialog_panel_style.content_margin_left = -1.0
	dialog_panel_style.content_margin_right = -1.0
	dialog_panel_style.content_margin_top = UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT
	dialog_panel_style.content_margin_bottom = UI_STYLE_GUIDE.DIALOG_ACTION_BOTTOM_CLEARANCE
	dialog_theme.set_stylebox("panel", "Window", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "AcceptDialog", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "ConfirmationDialog", dialog_panel_style)
	theme = dialog_theme


func _on_ui_style_changed(_style_id: String) -> void:
	## 风格切换后重建弹窗背景、边框和基础控件主题，当前目标类型与输入内容保持不变。
	_apply_dialog_visual_style()
	DIALOG_OUTER_FRAME_SCRIPT.install(self)


func _on_kind_selected(kind: String) -> void:
	## 切换目标类型；输入框改为预填该目标的已有档案，方向提示与校验同步刷新。
	_selected_kind = KIND_LEVERAGE if kind == KIND_LEVERAGE else KIND_SPOT
	_fill_inputs_from_order()
	_refresh_preview()


func _on_price_text_changed(_new_text: String) -> void:
	## 任一目标价输入变化；只做本地预览校验，不触发任何服务调用。
	_refresh_preview()


func _apply_kind_availability() -> void:
	## 按当前持仓刷新目标按钮可用性；现货无持股或杠杆无仓位时对应按钮禁用。
	if _kind_buttons.has(KIND_SPOT):
		(_kind_buttons[KIND_SPOT] as Button).disabled = _spot_quantity <= 0
	if _kind_buttons.has(KIND_LEVERAGE):
		(_kind_buttons[KIND_LEVERAGE] as Button).disabled = _leverage_position.is_empty()


func _apply_kind_selection() -> void:
	## 同步目标按钮按下状态；只呈现当前选中目标，不触发按钮信号。
	for kind in _kind_buttons.keys():
		(_kind_buttons[kind] as Button).set_pressed_no_signal(str(kind) == _selected_kind)


func _fill_inputs_from_order() -> void:
	## 用当前目标的已有档案预填两个输入框；未设置的方向清空为占位提示。
	# 当前目标已有档案；现货与杠杆分别缓存。
	var order: Dictionary = _spot_order if _selected_kind == KIND_SPOT else _leverage_order
	# 已有止盈目标价；0 表示未启用。
	var take_profit: float = float(order.get("take_profit", 0.0))
	# 已有止损目标价；0 表示未启用。
	var stop_loss: float = float(order.get("stop_loss", 0.0))
	_take_profit_edit.text = "%.2f" % take_profit if take_profit > 0.0 else ""
	_stop_loss_edit.text = "%.2f" % stop_loss if stop_loss > 0.0 else ""


func _get_profit_direction() -> float:
	## 返回当前目标的盈利方向系数；现货与做多为 +1（涨盈利），做空为 -1（跌盈利）。
	if _selected_kind == KIND_LEVERAGE and int(_leverage_position.get("direction", 1)) < 0:
		return -1.0
	return 1.0


func _parse_price_input(price_edit: LineEdit) -> float:
	## 解析目标价输入；空文本返回 0 表示不启用，其余按两位小数标准化，非法文本按 -1 返回交由校验提示。
	# 规范化输入文本；去除首尾空白后判断是否为空。
	var text: String = price_edit.text.strip_edges()
	if text.is_empty():
		return 0.0
	if not text.is_valid_float():
		return -1.0
	return snappedf(text.to_float(), 0.01)


func _refresh_preview() -> void:
	## 刷新说明、方向提示与校验预览；输入非法或目标持仓消失时禁用保存按钮，最终仍由股市服务重新校验。
	# 当前目标持仓概要；现货显示持股数量，杠杆显示倍数与方向。
	var target_summary: String = ""
	# 当前目标是否仍然有效；清仓或强平后保存按钮禁用。
	var target_available: bool = true
	if _selected_kind == KIND_SPOT:
		target_summary = "现货持仓 %d 股" % _spot_quantity
		target_available = _spot_quantity > 0
	elif _leverage_position.is_empty():
		target_summary = "杠杆仓位已不存在"
		target_available = false
	else:
		target_summary = "杠杆 %d×%s" % [int(_leverage_position.get("leverage", 1)), str(_leverage_position.get("direction_name", "做多"))]
	_description_label.text = "%s · 现价 %.2f 证券币\n%s · 到价后按实时价自动%s" % [_stock_display_name, _current_price, target_summary, "卖出全部持股" if _selected_kind == KIND_SPOT else "全仓平仓"]
	# 盈利方向系数；提示与校验共用。
	var profit_direction: float = _get_profit_direction()
	_take_profit_hint_label.text = "现价上方，到价止盈" if profit_direction > 0.0 else "现价下方，到价止盈"
	_stop_loss_hint_label.text = "现价下方，到价止损" if profit_direction > 0.0 else "现价上方，到价止损"
	# 解析后的止盈目标价；-1 表示文本非法。
	var take_profit: float = _parse_price_input(_take_profit_edit)
	# 解析后的止损目标价；-1 表示文本非法。
	var stop_loss: float = _parse_price_input(_stop_loss_edit)
	# 校验结论文本；合法时说明触发规则，非法时说明具体原因。
	var verdict: String = ""
	# 输入整体是否合法；决定保存按钮可用性。
	var inputs_valid: bool = true
	if take_profit < 0.0 or stop_loss < 0.0:
		verdict = "目标价必须是数字，留空表示不启用"
		inputs_valid = false
	elif take_profit <= 0.0 and stop_loss <= 0.0:
		verdict = "止盈价与止损价至少设置一项"
		inputs_valid = false
	elif take_profit > 0.0 and (take_profit - _current_price) * profit_direction <= 0.0:
		verdict = "止盈价必须位于当前价（%.2f）的盈利方向" % _current_price
		inputs_valid = false
	elif stop_loss > 0.0 and (stop_loss - _current_price) * profit_direction >= 0.0:
		verdict = "止损价必须位于当前价（%.2f）的亏损方向" % _current_price
		inputs_valid = false
	else:
		# 合法输入摘要；未启用方向显示为“—”。
		verdict = "止盈 %s · 止损 %s\n任意行情刷新到价即触发，触发后设置自动失效" % ["%.2f" % take_profit if take_profit > 0.0 else "—", "%.2f" % stop_loss if stop_loss > 0.0 else "—"]
	if not target_available:
		verdict = "目标持仓已不存在，无法保存设置"
	_result_label.text = verdict
	get_ok_button().disabled = not inputs_valid or not target_available
	# 清除按钮可用性；当前目标已有档案时才可清除。
	var existing_order: Dictionary = _spot_order if _selected_kind == KIND_SPOT else _leverage_order
	if _clear_button != null:
		_clear_button.disabled = existing_order.is_empty()


func _on_confirmed() -> void:
	## 发出最终目标类型与两位小数目标价；宿主必须调用股市服务重新校验持仓与方向后执行。
	stop_order_confirmed.emit(_selected_kind, maxf(_parse_price_input(_take_profit_edit), 0.0), maxf(_parse_price_input(_stop_loss_edit), 0.0))


func _on_custom_action(action: StringName) -> void:
	## 自定义按钮回调；清除动作先关闭弹窗再发出清除信号，由宿主执行真实清除。
	if String(action) != CLEAR_ACTION:
		return
	hide()
	stop_order_clear_requested.emit(_selected_kind)
