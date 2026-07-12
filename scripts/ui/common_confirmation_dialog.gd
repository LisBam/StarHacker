extends ConfirmationDialog
class_name CommonConfirmationDialog

## 通用信息确认弹窗统一承载购买、离开、清空等“说明文本 + 确认/取消”交互。
## 数量选择、强化结果等包含专用控件或单按钮结果展示的弹窗不使用本组件。
## 信息结果补充：单按钮结果弹窗可继承本组件并调用 present_information()，统一复用背景、边框、圆角和确认按钮规格。

## 全局窗口样式指南；为确认弹窗补充统一按钮、文字和青蓝边框视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 弹窗最外层框架组件；直接绘制不透明标题栏、外框、标题文字和关闭按钮。
const DIALOG_OUTER_FRAME_SCRIPT: Script = preload("res://scripts/ui/dialog_outer_frame.gd")

## 默认弹窗宽度；默认 460 像素，可容纳两行中文说明且不会大面积遮挡背景。
@export_range(280, 760, 1) var dialog_width: int = 460
## 默认背景透明度；与物品悬浮信息浮窗一致使用 0.68，突出内容同时保留场景上下文。
@export_range(0.0, 1.0, 0.01) var background_alpha: float = 0.68
## 白色边框宽度；默认 2 像素，与物品悬浮信息浮窗保持一致。
@export_range(1, 6, 1) var border_width: int = 2
## 圆角半径；默认 6 像素，与物品悬浮信息浮窗保持一致。
@export_range(0, 24, 1) var corner_radius: int = 6
## 自适应弹窗最小宽度；默认 280 像素，可稳定容纳两个 96 像素操作按钮，运行时无需动态修改。
@export_range(240, 480, 1) var adaptive_minimum_width: int = 280
## 自适应弹窗最大宽度；默认 520 像素，长说明超过该宽度后自动换行，运行时无需动态修改。
@export_range(320, 760, 1) var adaptive_maximum_width: int = 520
## 自适应正文水平留白；默认 44 像素，包含内容面板左右边距和文字安全空间，运行时无需动态修改。
@export_range(24, 96, 1) var adaptive_horizontal_padding: int = 44


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_standard_style()
	DIALOG_OUTER_FRAME_SCRIPT.install(self)


func present(dialog_title: String, message: String, confirm_text: String = "确认", cancel_text: String = "取消", requested_width: int = -1, requested_height: int = 0, confirmation_enabled: bool = true) -> void:
	_configure_confirmation(dialog_title, message, confirm_text, cancel_text, confirmation_enabled)
	# 固定尺寸正文；清除上一次自适应展示留下的正文宽度，允许调用方提供稳定窗口规格。
	_reset_message_layout()
	# 确认窗口尺寸；高度为 0 时保持通用自动布局，专用多行确认窗口可传入稳定高度避免首次布局抖动。
	popup_centered(Vector2i(requested_width if requested_width > 0 else dialog_width, maxi(requested_height, 0)))


func present_adaptive(dialog_title: String, message: String, confirm_text: String = "确认", cancel_text: String = "取消", confirmation_enabled: bool = true, requested_maximum_width: int = -1) -> void:
	## 按标题、正文最长行和按钮区域计算紧凑窗口宽度，高度完全交给当前正文行数与控件最小尺寸决定。
	_configure_confirmation(dialog_title, message, confirm_text, cancel_text, confirmation_enabled)
	# 自适应宽度；最大值可由专用入口临时收紧，负数继续使用检查器统一配置。
	var resolved_width: int = _calculate_adaptive_width(dialog_title, message, true, requested_maximum_width)
	# 正文布局；限制到窗口内容宽度并启用智能换行，使长说明只增加必要高度而不产生右侧空区。
	_apply_adaptive_message_layout(resolved_width)
	popup_centered(Vector2i(resolved_width, 0))


func update_confirmation_message(message: String, confirmation_enabled: bool = true) -> void:
	## 更新已打开确认窗口的正文与确认可用性；不会重新弹出窗口、改变焦点或重置取消按钮。
	dialog_text = message
	get_ok_button().disabled = not confirmation_enabled


func present_information(dialog_title: String, message: String, confirm_text: String = "确定", requested_width: int = -1, requested_height: int = 0) -> void:
	# 信息弹窗标题；与双按钮确认模式共用窗口标题配置，不创建第二套弹窗样式。
	title = dialog_title
	# 信息正文；允许子类隐藏系统标签并使用自定义富文本控件，空字符串不会额外占用正文内容。
	dialog_text = message
	get_ok_button().text = confirm_text
	# 取消按钮；信息结果只需要单个确认出口，每次普通 present() 都会重新恢复显示。
	get_cancel_button().visible = false
	if requested_width <= 0 and requested_height <= 0:
		# 单按钮信息窗口；未指定固定尺寸时复用与二次确认相同的内容自适应规则。
		var resolved_width: int = _calculate_adaptive_width(dialog_title, message, false)
		_apply_adaptive_message_layout(resolved_width)
		popup_centered(Vector2i(resolved_width, 0))
		return
	# 固定尺寸信息窗口；强化结果等专用窗口继续保留自身稳定布局。
	_reset_message_layout()
	# 弹窗尺寸；宽度回退通用默认值，高度为 0 时继续由系统按纯文本内容自动计算。
	var popup_size: Vector2i = Vector2i(requested_width if requested_width > 0 else dialog_width, maxi(requested_height, 0))
	popup_centered(popup_size)


func _configure_confirmation(dialog_title: String, message: String, confirm_text: String, cancel_text: String, confirmation_enabled: bool) -> void:
	## 配置双按钮确认窗口的公共内容与状态；固定尺寸和自适应入口共享此逻辑，避免复用时状态残留。
	title = dialog_title
	dialog_text = message
	get_ok_button().text = confirm_text
	# 确认按钮状态；每次展示都按当前业务校验结果覆盖，避免沿用上一次禁用状态。
	get_ok_button().disabled = not confirmation_enabled
	get_cancel_button().text = cancel_text
	get_cancel_button().visible = true


func _calculate_adaptive_width(dialog_title: String, message: String, show_cancel_button: bool, requested_maximum_width: int = -1) -> int:
	## 返回适配标题、正文和按钮的窗口宽度；结果始终限制在检查器配置的最小与最大范围内。
	# 正文标签；使用其实际主题字体测量中文、数字和符号宽度，避免按字符数量粗略估算。
	var message_label: Label = get_label()
	# 正文字体；继承当前弹窗主题，确保测量结果与最终渲染一致。
	var message_font: Font = message_label.get_theme_font("font")
	# 正文字号；继承当前弹窗主题默认值，修改全局字体后无需同步魔法数字。
	var message_font_size: int = message_label.get_theme_font_size("font_size")
	# 最长正文行宽度；逐行测量，换行后的空行不会额外增加窗口宽度。
	var longest_line_width: float = 0.0
	for raw_line in message.split("\n"):
		# 当前正文行；显式转换为字符串以兼容 PackedStringArray 遍历类型。
		var message_line: String = str(raw_line)
		longest_line_width = maxf(longest_line_width, message_font.get_string_size(message_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, message_font_size).x)
	# 标题宽度；复用正文字体并使用自定义标题栏字号，左右安全边距同时为关闭按钮预留空间。
	var title_width: float = message_font.get_string_size(dialog_title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UI_STYLE_GUIDE.DIALOG_TITLE_FONT_SIZE).x + UI_STYLE_GUIDE.DIALOG_TITLE_SIDE_PADDING * 2.0
	# 按钮宽度；确认和取消按钮使用实际最小尺寸，并补充按钮间距与两侧安全留白。
	var buttons_width: float = get_ok_button().get_combined_minimum_size().x + 48.0
	if show_cancel_button:
		buttons_width += get_cancel_button().get_combined_minimum_size().x + 16.0
	# 最大允许宽度；调用方只可进一步收紧，不能突破项目统一上限或低于最小宽度。
	var maximum_width: int = adaptive_maximum_width if requested_maximum_width <= 0 else clampi(requested_maximum_width, adaptive_minimum_width, adaptive_maximum_width)
	# 内容需求宽度；正文补充水平留白后与标题、按钮的最小需求取最大值。
	var desired_width: int = ceili(maxf(longest_line_width + float(adaptive_horizontal_padding), maxf(title_width, buttons_width)))
	return clampi(desired_width, adaptive_minimum_width, maximum_width)


func _apply_adaptive_message_layout(window_width: int) -> void:
	## 限制正文到当前窗口可用宽度；窗口高度随后由换行后的实际行数自动计算。
	# 正文标签；原生 AcceptDialog 标签继续作为唯一正文所有者，不创建重复文本控件。
	var message_label: Label = get_label()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(maxf(float(window_width - adaptive_horizontal_padding), 1.0), 0.0)


func _reset_message_layout() -> void:
	## 清除自适应正文宽度；固定尺寸和强化结果窗口可按自己的规格重新布局。
	# 正文标签；保留智能换行以适配固定窗口，只移除自适应模式设置的最小宽度。
	var message_label: Label = get_label()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2.ZERO


func _apply_standard_style() -> void:
	# 弹窗面板样式；颜色、透明度、白边和圆角直接对齐物品悬浮信息浮窗。
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.055, background_alpha)
	panel_style.border_color = Color(1.0, 1.0, 1.0, 0.92)
	# 全局窗口边框补充；通用确认窗口使用青蓝描边与其他窗口对齐，白边说明保留为历史兼容注释。
	panel_style.border_color = UI_STYLE_GUIDE.WINDOW_BORDER_COLOR
	panel_style.set_border_width_all(border_width)
	panel_style.set_corner_radius_all(corner_radius)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_top = UI_STYLE_GUIDE.DIALOG_TITLE_HEIGHT + 14.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_bottom = 20.0
	# 独立主题；同时覆盖 AcceptDialog 与 ConfirmationDialog 类型，避免引擎版本主题类型差异。
	var dialog_theme: Theme = UI_STYLE_GUIDE.create_theme()
	dialog_theme.set_stylebox("panel", "AcceptDialog", panel_style)
	dialog_theme.set_stylebox("panel", "ConfirmationDialog", panel_style)
	theme = dialog_theme
	UI_STYLE_GUIDE.apply_primary_button(get_ok_button())
	get_ok_button().custom_minimum_size = Vector2(96.0, 34.0)
	get_cancel_button().custom_minimum_size = Vector2(96.0, 34.0)
