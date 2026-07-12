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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_standard_style()
	DIALOG_OUTER_FRAME_SCRIPT.install(self)


func present(dialog_title: String, message: String, confirm_text: String = "确认", cancel_text: String = "取消", requested_width: int = -1, requested_height: int = 0, confirmation_enabled: bool = true) -> void:
	title = dialog_title
	dialog_text = message
	get_ok_button().text = confirm_text
	# 确认按钮初始状态；复用弹窗时清除上一次动态校验留下的禁用状态，再由调用方按当前报价覆盖。
	# 动态校验补充；在窗口弹出前直接应用最终状态，避免首次布局完成后立即二次更新正文与按钮触发异常高度重算。
	get_ok_button().disabled = not confirmation_enabled
	get_cancel_button().text = cancel_text
	get_cancel_button().visible = true
	# 确认窗口尺寸；高度为 0 时保持通用自动布局，专用多行确认窗口可传入稳定高度避免首次布局抖动。
	popup_centered(Vector2i(requested_width if requested_width > 0 else dialog_width, maxi(requested_height, 0)))


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
	# 弹窗尺寸；宽度回退通用默认值，高度为 0 时继续由系统按纯文本内容自动计算。
	var popup_size: Vector2i = Vector2i(requested_width if requested_width > 0 else dialog_width, maxi(requested_height, 0))
	popup_centered(popup_size)


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
