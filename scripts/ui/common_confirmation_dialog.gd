extends ConfirmationDialog
class_name CommonConfirmationDialog

## 通用信息确认弹窗统一承载购买、离开、清空等“说明文本 + 确认/取消”交互。
## 数量选择、强化结果等包含专用控件或单按钮结果展示的弹窗不使用本组件。

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


func present(dialog_title: String, message: String, confirm_text: String = "确认", cancel_text: String = "取消", requested_width: int = -1) -> void:
	title = dialog_title
	dialog_text = message
	get_ok_button().text = confirm_text
	get_cancel_button().text = cancel_text
	popup_centered(Vector2i(requested_width if requested_width > 0 else dialog_width, 0))


func _apply_standard_style() -> void:
	# 弹窗面板样式；颜色、透明度、白边和圆角直接对齐物品悬浮信息浮窗。
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.055, background_alpha)
	panel_style.border_color = Color(1.0, 1.0, 1.0, 0.92)
	panel_style.set_border_width_all(border_width)
	panel_style.set_corner_radius_all(corner_radius)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_bottom = 14.0
	# 独立主题；同时覆盖 AcceptDialog 与 ConfirmationDialog 类型，避免引擎版本主题类型差异。
	var dialog_theme: Theme = Theme.new()
	dialog_theme.set_stylebox("panel", "AcceptDialog", panel_style)
	dialog_theme.set_stylebox("panel", "ConfirmationDialog", panel_style)
	theme = dialog_theme
	get_ok_button().custom_minimum_size = Vector2(96.0, 34.0)
	get_cancel_button().custom_minimum_size = Vector2(96.0, 34.0)
