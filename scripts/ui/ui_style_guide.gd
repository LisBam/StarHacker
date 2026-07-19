extends RefCounted
class_name UiStyleGuide

## 全局窗口 UI 样式指南集中定义局外系统、暂停菜单、结算窗口与通用弹窗的视觉语言。
## 本脚本不读取任何业务服务，只生成 Theme 和 StyleBox 资源，所有功能面板都可独立复用。

## 全屏背景色；默认使用接近量子矿场的深蓝黑色，适合菜单和角色选择等完整页面。
const SCREEN_BACKGROUND_COLOR: Color = Color(0.025, 0.038, 0.052, 1.0)
## 全屏窗口遮罩色；默认保留少量蓝色分量，使遮罩与深蓝窗口自然融合而不是纯黑割裂。
const OVERLAY_DIM_COLOR: Color = Color(0.008, 0.018, 0.028, 0.72)
## 主窗口背景色；默认高不透明深蓝黑，保证复杂物品卡片与行情文字的对比度。
const WINDOW_BACKGROUND_COLOR: Color = Color(0.025, 0.045, 0.065, 0.985)
## 主窗口边框色；默认青蓝描边，来源于量子矿场的高亮边界。
const WINDOW_BORDER_COLOR: Color = Color(0.30, 0.68, 0.82, 0.94)
## 子分区背景色；用于装备栏、交易区、统计区和暂停地图等窗口内部区域。
const SECTION_BACKGROUND_COLOR: Color = Color(0.045, 0.068, 0.090, 0.94)
## 子分区边框色；比主窗口描边更弱，避免嵌套面板争夺视觉焦点。
const SECTION_BORDER_COLOR: Color = Color(0.20, 0.38, 0.47, 0.90)
## 输入框背景色；默认比子分区更深，用于搜索框、数字输入和文本编辑区域。
const INPUT_BACKGROUND_COLOR: Color = Color(0.018, 0.032, 0.044, 0.98)
## 普通按钮背景色；使用冷色深蓝承载非破坏性操作。
const BUTTON_BACKGROUND_COLOR: Color = Color(0.065, 0.125, 0.165, 0.98)
## 普通按钮悬停色；提高蓝绿色亮度，明确鼠标当前指向。
const BUTTON_HOVER_COLOR: Color = Color(0.085, 0.235, 0.305, 1.0)
## 普通按钮按下色；比正常状态更深，提供清晰点击反馈。
const BUTTON_PRESSED_COLOR: Color = Color(0.035, 0.090, 0.125, 1.0)
## 角色选择按钮选中色；默认使用稳定青蓝底区分当前角色，修改会影响角色列表的常驻选中状态。
const CHARACTER_SELECTED_COLOR: Color = Color(0.045, 0.285, 0.365, 1.0)
## 角色选择按钮选中悬停色；默认比选中色更亮，确保当前角色在鼠标悬停时仍有明确反馈。
const CHARACTER_SELECTED_HOVER_COLOR: Color = Color(0.075, 0.43, 0.54, 1.0)
## 主操作按钮背景色；用于进入、确认、购买和锻造等页面主要动作。
const PRIMARY_BUTTON_COLOR: Color = Color(0.055, 0.30, 0.39, 1.0)
## 主操作按钮悬停色；默认提高青蓝亮度但保持白色文字可读性。
const PRIMARY_BUTTON_HOVER_COLOR: Color = Color(0.075, 0.43, 0.54, 1.0)
## 主操作按钮按下色；用于主操作被点击时的下沉反馈。
const PRIMARY_BUTTON_PRESSED_COLOR: Color = Color(0.035, 0.22, 0.29, 1.0)
## 危险按钮背景色；用于退出、清空、卖出等需要谨慎确认的操作。
const DANGER_BUTTON_COLOR: Color = Color(0.30, 0.065, 0.085, 0.98)
## 危险按钮悬停色；提高红色亮度以提示操作风险。
const DANGER_BUTTON_HOVER_COLOR: Color = Color(0.48, 0.09, 0.12, 1.0)
## 危险按钮按下色；保持暗红反馈且不造成刺眼闪烁。
const DANGER_BUTTON_PRESSED_COLOR: Color = Color(0.21, 0.035, 0.052, 1.0)
## 禁用控件背景色；默认低饱和灰蓝，确保仍可辨认控件边界。
const DISABLED_BACKGROUND_COLOR: Color = Color(0.055, 0.065, 0.072, 0.82)
## 主要文字色；用于普通标签、按钮和输入内容。
const PRIMARY_TEXT_COLOR: Color = Color(0.90, 0.96, 0.99, 1.0)
## 次要文字色；用于规则说明、占位提示和弱化信息。
const SECONDARY_TEXT_COLOR: Color = Color(0.63, 0.72, 0.78, 1.0)
## 禁用文字色；用于不可操作按钮和只读弱提示。
const DISABLED_TEXT_COLOR: Color = Color(0.42, 0.48, 0.52, 0.92)
## 青蓝强调色；用于标题、焦点、选中状态和滑条。
const ACCENT_COLOR: Color = Color(0.55, 0.92, 1.0, 1.0)
## 青蓝弱强调色；用于非主要标题和细分区描边。
const ACCENT_MUTED_COLOR: Color = Color(0.30, 0.60, 0.72, 0.92)
## 角色技能卡片高亮背景色；悬停或展开时使用，修改会影响全部角色详情技能卡片。
const CHARACTER_SKILL_CARD_HIGHLIGHT_COLOR: Color = Color(0.055, 0.085, 0.108, 0.98)
## 角色技能标题悬停背景色；只覆盖卡片第一行，修改会影响技能展开入口的鼠标反馈。
const CHARACTER_SKILL_HEADER_HOVER_COLOR: Color = Color(0.08, 0.22, 0.28, 0.72)
## 主动技能类型徽章背景色；默认青蓝色，用于角色详情中的“主动”分类。
const CHARACTER_SKILL_ACTIVE_BADGE_COLOR: Color = Color(0.08, 0.34, 0.42, 0.98)
## 被动技能类型徽章背景色；默认紫蓝色，用于角色详情中的“被动”分类。
const CHARACTER_SKILL_PASSIVE_BADGE_COLOR: Color = Color(0.25, 0.16, 0.40, 0.98)
## 技能冷却徽章背景色；默认弱青蓝色，用于角色详情中的基础 CD。
const CHARACTER_SKILL_COOLDOWN_BADGE_COLOR: Color = Color(0.16, 0.34, 0.42, 0.98)
## 技能能耗徽章背景色；默认暖黄色，用于角色详情中的整数能量消耗。
const CHARACTER_SKILL_ENERGY_BADGE_COLOR: Color = Color(0.34, 0.27, 0.08, 0.98)
## 技能徽章边框色；默认使用 72% 不透明度青蓝色，保持三个徽章边界一致。
const CHARACTER_SKILL_BADGE_BORDER_COLOR: Color = Color(0.55, 0.92, 1.0, 0.72)
## 成功语义色；用于收益、上涨、完成和正向状态。
const SUCCESS_COLOR: Color = Color(0.34, 1.0, 0.62, 1.0)
## 警告语义色；用于费用、限制、提示和需要注意的信息。
const WARNING_COLOR: Color = Color(1.0, 0.80, 0.30, 1.0)
## 危险语义色；用于亏损、失败、丢失和破坏性提示。
const DANGER_COLOR: Color = Color(1.0, 0.42, 0.48, 1.0)
## 主窗口圆角；默认 8 像素，与股市、矿场面板保持一致。
const WINDOW_CORNER_RADIUS: int = 8
## 子分区圆角；默认 6 像素，使内部层级略弱于主窗口。
const SECTION_CORNER_RADIUS: int = 6
## 弹窗最外层边框宽度；默认 2 像素，完整包围标题栏和内容区域，运行时无需动态修改。
const DIALOG_OUTER_BORDER_WIDTH: int = 2
## 弹窗最外层圆角；默认 10 像素，比内容面板圆角略大，形成清晰的双层窗口轮廓，运行时无需动态修改。
const DIALOG_OUTER_CORNER_RADIUS: int = 10
## 数量与转账弹窗按钮区底部净空；默认 8 像素，使确认和取消按钮不与内容面板边框相连，运行时无需动态修改。
const DIALOG_ACTION_BOTTOM_CLEARANCE: float = 8.0
## 自定义弹窗标题栏高度；默认 30 像素，为标题文字和关闭按钮提供稳定空间，运行时无需动态修改。
const DIALOG_TITLE_HEIGHT: float = 30.0
## 自定义弹窗标题字体大小；默认 14 像素，与项目统一控件字体一致，运行时无需动态修改。
const DIALOG_TITLE_FONT_SIZE: int = 14
## 自定义弹窗标题左右安全边距；默认 34 像素，避免标题文字与关闭按钮重叠，运行时无需动态修改。
const DIALOG_TITLE_SIDE_PADDING: float = 34.0
## 自定义弹窗关闭按钮边长；默认 26 像素，在紧凑标题栏内保持清晰点击区域，运行时无需动态修改。
const DIALOG_CLOSE_BUTTON_SIZE: float = 26.0
## 滚动条可交互厚度；固定 14 像素，避免仅设置颜色样式时引擎把无图标滚动条压缩为 0 像素。
const SCROLLBAR_THICKNESS: float = 14.0
## 装备栏武器组与防具组之间的空白控件高度；默认 6 像素，与 VBox 两侧各 6 像素间距共同形成 18 像素总分隔。
const EQUIPMENT_GROUP_SPACER_HEIGHT: float = 6.0
## 自定义弹窗标题栏背景；固定完全不透明的深蓝色，避免最外层标题区域透出场景背景。
const DIALOG_TITLE_BACKGROUND_COLOR: Color = Color(0.025, 0.045, 0.065, 1.0)
## 黑白简约风完整页面背景；使用纯黑保留最大文字对比度，运行时由风格设置服务选择。
const BLACK_WHITE_SCREEN_BACKGROUND_COLOR: Color = Color(0.015, 0.015, 0.015, 1.0)
## 黑白简约风聚焦遮罩；保持纯黑半透明，避免在弹窗外继续出现彩色环境干扰。
const BLACK_WHITE_OVERLAY_DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.76)
## 黑白简约风主窗口背景；略高于纯黑以区分页面与窗口层级。
const BLACK_WHITE_WINDOW_BACKGROUND_COLOR: Color = Color(0.055, 0.055, 0.055, 0.985)
## 黑白简约风主窗口边框；使用高亮白灰线形成简洁高对比轮廓。
const BLACK_WHITE_WINDOW_BORDER_COLOR: Color = Color(0.88, 0.88, 0.88, 0.96)
## 黑白简约风子分区背景；比主窗口略亮，用灰度差异表达嵌套层级。
const BLACK_WHITE_SECTION_BACKGROUND_COLOR: Color = Color(0.105, 0.105, 0.105, 0.96)
## 黑白简约风子分区边框；使用中灰弱化内部区域，避免与主窗口白边争夺焦点。
const BLACK_WHITE_SECTION_BORDER_COLOR: Color = Color(0.42, 0.42, 0.42, 0.94)
## 黑白简约风标题栏背景；使用不透明近黑色，保证标题文字和关闭按钮清晰可读。
const BLACK_WHITE_DIALOG_TITLE_BACKGROUND_COLOR: Color = Color(0.035, 0.035, 0.035, 1.0)


## 为完整页面或可复用面板安装统一控件主题；调用后所有后代控件自动继承按钮、输入、滚动和分区样式。
static func apply_screen_theme(target: Control) -> void:
	if target == null:
		return
	target.theme = create_theme()
	# UI 风格服务；存在时登记独立主题根，使设置切换能立即刷新当前页面和后续动态控件。
	var ui_style_settings: Node = _get_ui_style_settings()
	if ui_style_settings != null and ui_style_settings.has_method("register_theme_root"):
		ui_style_settings.call("register_theme_root", target)


## 为顶层 PanelContainer 应用主窗口背景、青蓝描边、圆角和轻量阴影。
static func apply_window_panel(target: Control) -> void:
	if target == null:
		return
	target.add_theme_stylebox_override("panel", create_window_panel_style())
	# UI 风格服务；存在时登记主窗口面板，使黑蓝与黑白双向切换都能刷新显式覆盖。
	var ui_style_settings: Node = _get_ui_style_settings()
	if ui_style_settings != null and ui_style_settings.has_method("register_window_panel"):
		ui_style_settings.call("register_window_panel", target)


## 为窗口内部 PanelContainer 应用弱化分区样式，适合装备栏、交易区、统计区和列表承载区。
static func apply_section_panel(target: Control) -> void:
	if target == null:
		return
	target.add_theme_stylebox_override("panel", create_section_panel_style())
	# UI 风格服务；存在时登记子分区面板，使运行时切换不会保留首次创建时的旧风格。
	var ui_style_settings: Node = _get_ui_style_settings()
	if ui_style_settings != null and ui_style_settings.has_method("register_section_panel"):
		ui_style_settings.call("register_section_panel", target)


## 为主操作按钮切换到青蓝高亮变体；按钮仍保留统一尺寸和禁用状态。
static func apply_primary_button(target: Button) -> void:
	if target == null:
		return
	target.theme_type_variation = &"PrimaryButton"


## 为破坏性或退出按钮切换到暗红变体，避免与普通导航操作混淆。
static func apply_danger_button(target: Button) -> void:
	if target == null:
		return
	target.theme_type_variation = &"DangerButton"


## 为角色列表按钮启用独立选中与选中悬停状态；按钮必须保持 toggle_mode 才能显示当前角色。
static func apply_character_selector_button(target: Button) -> void:
	if target == null:
		return
	target.theme_type_variation = &"CharacterSelectorButton"


## 为标题标签应用统一青蓝文字；字号小于等于 0 时保留调用方原有字号。
static func apply_title_label(target: Label, font_size: int = 0) -> void:
	if target == null:
		return
	target.add_theme_color_override("font_color", ACCENT_COLOR)
	if font_size > 0:
		target.add_theme_font_size_override("font_size", font_size)


## 将全屏 ColorRect 设置为统一深蓝黑遮罩，保证所有弹出窗口拥有一致聚焦效果。
static func apply_overlay_dim(target: ColorRect) -> void:
	if target == null:
		return
	target.color = get_overlay_dim_color()
	# UI 风格服务；存在时登记遮罩，使设置切换能即时刷新当前已打开或隐藏的窗口背景。
	var ui_style_settings: Node = _get_ui_style_settings()
	if ui_style_settings != null and ui_style_settings.has_method("register_overlay_dim"):
		ui_style_settings.call("register_overlay_dim", target)


## 将完整页面 ColorRect 设置为当前 UI 风格背景，并登记后续即时刷新。
static func apply_screen_background(target: ColorRect) -> void:
	if target == null:
		return
	target.color = get_screen_background_color()
	# UI 风格服务；存在时登记页面背景，切换风格后无需重建场景即可刷新。
	var ui_style_settings: Node = _get_ui_style_settings()
	if ui_style_settings != null and ui_style_settings.has_method("register_screen_background"):
		ui_style_settings.call("register_screen_background", target)


## 返回当前 UI 风格的完整页面背景色；服务不可用时保持原黑蓝科技风。
static func get_screen_background_color() -> Color:
	return BLACK_WHITE_SCREEN_BACKGROUND_COLOR if is_black_white_style_active() else SCREEN_BACKGROUND_COLOR


## 返回当前 UI 风格的聚焦遮罩色；服务不可用时保持原黑蓝科技风。
static func get_overlay_dim_color() -> Color:
	return BLACK_WHITE_OVERLAY_DIM_COLOR if is_black_white_style_active() else OVERLAY_DIM_COLOR


## 返回当前 UI 风格的主窗口背景色；黑白风格使用纯灰阶表面。
static func get_window_background_color() -> Color:
	return BLACK_WHITE_WINDOW_BACKGROUND_COLOR if is_black_white_style_active() else WINDOW_BACKGROUND_COLOR


## 返回当前 UI 风格的主窗口边框色；黑白风格使用高对比白灰描边。
static func get_window_border_color() -> Color:
	return BLACK_WHITE_WINDOW_BORDER_COLOR if is_black_white_style_active() else WINDOW_BORDER_COLOR


## 返回当前 UI 风格的子分区背景色；黑白风格只通过灰阶明度表达层级。
static func get_section_background_color() -> Color:
	return BLACK_WHITE_SECTION_BACKGROUND_COLOR if is_black_white_style_active() else SECTION_BACKGROUND_COLOR


## 返回当前 UI 风格的子分区边框色；黑白风格使用弱中灰描边。
static func get_section_border_color() -> Color:
	return BLACK_WHITE_SECTION_BORDER_COLOR if is_black_white_style_active() else SECTION_BORDER_COLOR


## 返回当前 UI 风格的弹窗标题栏背景色；黑白风格使用不透明近黑色。
static func get_dialog_title_background_color() -> Color:
	return BLACK_WHITE_DIALOG_TITLE_BACKGROUND_COLOR if is_black_white_style_active() else DIALOG_TITLE_BACKGROUND_COLOR


## 返回当前是否启用黑白简约风；没有主循环或服务时安全返回 false。
static func is_black_white_style_active() -> bool:
	# UI 风格服务；运行时由 AutoLoad 提供，资源导入和纯脚本验证阶段允许为空。
	var ui_style_settings: Node = _get_ui_style_settings()
	return ui_style_settings != null and ui_style_settings.has_method("is_black_white_style") and bool(ui_style_settings.call("is_black_white_style"))


## 创建项目统一主题；主题只包含视觉资源，不持有节点或服务引用，可安全分配给任意 Control 根节点。
static func create_theme() -> Theme:
	# 新主题资源；每个窗口持有独立实例，局部覆盖不会污染其他界面。
	var interface_theme: Theme = Theme.new()
	interface_theme.default_font_size = 14
	# 普通按钮样式组；所有非特殊按钮默认继承该交互状态。
	_set_button_styles(interface_theme, "Button", BUTTON_BACKGROUND_COLOR, BUTTON_HOVER_COLOR, BUTTON_PRESSED_COLOR, ACCENT_MUTED_COLOR)
	# 主操作按钮类型变体；只由进入、确认、购买和锻造等核心按钮显式启用。
	interface_theme.set_type_variation("PrimaryButton", "Button")
	_set_button_styles(interface_theme, "PrimaryButton", PRIMARY_BUTTON_COLOR, PRIMARY_BUTTON_HOVER_COLOR, PRIMARY_BUTTON_PRESSED_COLOR, ACCENT_COLOR)
	# 角色选择按钮类型变体；普通悬停与常驻选中使用不同色阶，选中后再次悬停仍会继续提亮。
	interface_theme.set_type_variation("CharacterSelectorButton", "Button")
	_set_character_selector_button_styles(interface_theme)
	# 危险按钮类型变体；只由退出、清空和高风险操作显式启用。
	interface_theme.set_type_variation("DangerButton", "Button")
	_set_button_styles(interface_theme, "DangerButton", DANGER_BUTTON_COLOR, DANGER_BUTTON_HOVER_COLOR, DANGER_BUTTON_PRESSED_COLOR, DANGER_COLOR)
	# 选项按钮样式组；下拉选择器与普通按钮使用一致的交互语言。
	_set_button_styles(interface_theme, "OptionButton", BUTTON_BACKGROUND_COLOR, BUTTON_HOVER_COLOR, BUTTON_PRESSED_COLOR, ACCENT_MUTED_COLOR)
	# 菜单按钮样式组；未来新增菜单入口时无需单独配置默认灰色控件。
	_set_button_styles(interface_theme, "MenuButton", BUTTON_BACKGROUND_COLOR, BUTTON_HOVER_COLOR, BUTTON_PRESSED_COLOR, ACCENT_MUTED_COLOR)
	# 子分区面板样式；所有嵌套 PanelContainer 默认使用弱边框，顶层窗口由调用方显式覆盖。
	interface_theme.set_stylebox("panel", "PanelContainer", create_section_panel_style())
	# 弹出菜单背景；用于 OptionButton 下拉列表和后续菜单控件。
	interface_theme.set_stylebox("panel", "PopupMenu", create_section_panel_style())
	# 菜单悬停行；使用低透明青蓝底突出当前条目。
	interface_theme.set_stylebox("hover", "PopupMenu", _create_flat_style(Color(0.08, 0.25, 0.32, 0.94), ACCENT_MUTED_COLOR, 1, 4, 8.0, 5.0))
	interface_theme.set_color("font_color", "PopupMenu", PRIMARY_TEXT_COLOR)
	interface_theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	interface_theme.set_color("font_disabled_color", "PopupMenu", DISABLED_TEXT_COLOR)
	interface_theme.set_color("font_separator_color", "PopupMenu", SECONDARY_TEXT_COLOR)
	# 输入框正常样式；深色底与青灰边框让搜索和数字输入融入窗口而不突兀。
	var input_normal_style: StyleBoxFlat = _create_flat_style(INPUT_BACKGROUND_COLOR, SECTION_BORDER_COLOR, 1, 5, 9.0, 6.0)
	# 输入框焦点样式；只提高边框亮度，不改变布局尺寸。
	var input_focus_style: StyleBoxFlat = _create_flat_style(INPUT_BACKGROUND_COLOR, ACCENT_COLOR, 2, 5, 9.0, 6.0)
	# 输入框只读样式；降低背景和边框饱和度以传达不可编辑状态。
	var input_read_only_style: StyleBoxFlat = _create_flat_style(DISABLED_BACKGROUND_COLOR, Color(0.20, 0.24, 0.27, 0.86), 1, 5, 9.0, 6.0)
	interface_theme.set_stylebox("normal", "LineEdit", input_normal_style)
	interface_theme.set_stylebox("focus", "LineEdit", input_focus_style)
	interface_theme.set_stylebox("read_only", "LineEdit", input_read_only_style)
	interface_theme.set_color("font_color", "LineEdit", PRIMARY_TEXT_COLOR)
	interface_theme.set_color("font_uneditable_color", "LineEdit", DISABLED_TEXT_COLOR)
	interface_theme.set_color("font_placeholder_color", "LineEdit", Color(SECONDARY_TEXT_COLOR, 0.72))
	interface_theme.set_color("caret_color", "LineEdit", ACCENT_COLOR)
	interface_theme.set_color("selection_color", "LineEdit", Color(0.18, 0.58, 0.72, 0.52))
	# 多行文本框复用输入框视觉；后续说明编辑或调试文本无需另建样式。
	interface_theme.set_stylebox("normal", "TextEdit", input_normal_style)
	interface_theme.set_stylebox("focus", "TextEdit", input_focus_style)
	interface_theme.set_stylebox("read_only", "TextEdit", input_read_only_style)
	interface_theme.set_color("font_color", "TextEdit", PRIMARY_TEXT_COLOR)
	interface_theme.set_color("font_readonly_color", "TextEdit", DISABLED_TEXT_COLOR)
	interface_theme.set_color("caret_color", "TextEdit", ACCENT_COLOR)
	interface_theme.set_color("selection_color", "TextEdit", Color(0.18, 0.58, 0.72, 0.52))
	# 标签默认颜色；具体收益、亏损和警告仍由业务面板使用语义色覆盖。
	interface_theme.set_color("font_color", "Label", PRIMARY_TEXT_COLOR)
	interface_theme.set_color("font_color", "RichTextLabel", PRIMARY_TEXT_COLOR)
	interface_theme.set_color("default_color", "RichTextLabel", PRIMARY_TEXT_COLOR)
	# 复选控件颜色；保留引擎图标，只统一文字与交互状态。
	_set_toggle_colors(interface_theme, "CheckBox")
	_set_toggle_colors(interface_theme, "CheckButton")
	# 进度条背景；默认用于角色属性、矿场产出和其他非语义专属进度。
	var progress_background_style: StyleBoxFlat = _create_flat_style(Color(0.015, 0.026, 0.036, 0.96), SECTION_BORDER_COLOR, 1, 4)
	# 进度条填充；青蓝渐层感由高亮边框与深色填充共同形成。
	var progress_fill_style: StyleBoxFlat = _create_flat_style(Color(0.08, 0.48, 0.60, 0.98), ACCENT_COLOR, 1, 4)
	interface_theme.set_stylebox("background", "ProgressBar", progress_background_style)
	interface_theme.set_stylebox("fill", "ProgressBar", progress_fill_style)
	interface_theme.set_color("font_color", "ProgressBar", PRIMARY_TEXT_COLOR)
	# 滑条轨道；用于音量、数量和转账额度选择。
	var slider_track_style: StyleBoxFlat = _create_flat_style(Color(0.025, 0.055, 0.072, 1.0), SECTION_BORDER_COLOR, 1, 3)
	# 滑条已选择区域；使用统一青蓝强调色显示当前数值占比。
	var slider_fill_style: StyleBoxFlat = _create_flat_style(Color(0.10, 0.50, 0.62, 1.0), ACCENT_COLOR, 1, 3)
	interface_theme.set_stylebox("slider", "HSlider", slider_track_style)
	interface_theme.set_stylebox("grabber_area", "HSlider", slider_fill_style)
	interface_theme.set_stylebox("grabber_area_highlight", "HSlider", _create_flat_style(Color(0.12, 0.62, 0.74, 1.0), Color.WHITE, 1, 3))
	# 水平滚动条轨道；上下内容边距共同形成固定可交互高度。
	var horizontal_scroll_track_style: StyleBoxFlat = _create_flat_style(Color(0.018, 0.032, 0.042, 0.72), Color.TRANSPARENT, 0, 4)
	horizontal_scroll_track_style.content_margin_top = SCROLLBAR_THICKNESS * 0.5
	horizontal_scroll_track_style.content_margin_bottom = SCROLLBAR_THICKNESS * 0.5
	# 垂直滚动条轨道；左右内容边距共同形成固定可交互宽度，确保滑块可见且可直接拖动。
	var vertical_scroll_track_style: StyleBoxFlat = _create_flat_style(Color(0.018, 0.032, 0.042, 0.72), Color.TRANSPARENT, 0, 4)
	vertical_scroll_track_style.content_margin_left = SCROLLBAR_THICKNESS * 0.5
	vertical_scroll_track_style.content_margin_right = SCROLLBAR_THICKNESS * 0.5
	# 滚动条滑块；默认青灰色，悬停和按压时提高亮度。
	var scroll_grabber_style: StyleBoxFlat = _create_flat_style(Color(0.18, 0.40, 0.48, 0.92), Color(0.28, 0.58, 0.68, 0.92), 1, 4)
	interface_theme.set_stylebox("scroll", "HScrollBar", horizontal_scroll_track_style)
	interface_theme.set_stylebox("scroll", "VScrollBar", vertical_scroll_track_style)
	for scroll_type in ["HScrollBar", "VScrollBar"]:
		interface_theme.set_stylebox("grabber", scroll_type, scroll_grabber_style)
		interface_theme.set_stylebox("grabber_highlight", scroll_type, _create_flat_style(Color(0.24, 0.58, 0.68, 1.0), ACCENT_COLOR, 1, 4))
		interface_theme.set_stylebox("grabber_pressed", scroll_type, _create_flat_style(Color(0.12, 0.34, 0.42, 1.0), ACCENT_COLOR, 1, 4))
	# 分隔线；使用低透明青蓝线区分装备、背包、状态和操作区域。
	var separator_style: StyleBoxFlat = _create_flat_style(Color(0.22, 0.52, 0.62, 0.55), Color.TRANSPARENT, 0, 0)
	separator_style.content_margin_top = 1.0
	separator_style.content_margin_bottom = 1.0
	interface_theme.set_stylebox("separator", "HSeparator", separator_style)
	interface_theme.set_stylebox("separator", "VSeparator", separator_style)
	# 工具提示背景；与物品详情和通用确认窗口共享深蓝黑白边视觉。
	var tooltip_style: StyleBoxFlat = _create_flat_style(Color(0.025, 0.04, 0.055, 0.96), Color(1.0, 1.0, 1.0, 0.88), 2, 6, 12.0, 8.0)
	interface_theme.set_stylebox("panel", "TooltipPanel", tooltip_style)
	interface_theme.set_color("font_color", "TooltipLabel", PRIMARY_TEXT_COLOR)
	# 通用 Window 背景；专用弹窗可通过自身透明度参数继续覆盖。
	var dialog_panel_style: StyleBoxFlat = create_dialog_panel_style(0.92)
	interface_theme.set_stylebox("panel", "Window", dialog_panel_style)
	interface_theme.set_stylebox("panel", "AcceptDialog", dialog_panel_style)
	interface_theme.set_stylebox("panel", "ConfirmationDialog", dialog_panel_style)
	return interface_theme


## 创建主窗口 StyleBox；包含 2 像素青蓝边框、8 像素圆角、内容留白与柔和阴影。
static func create_window_panel_style() -> StyleBoxFlat:
	# 主窗口样式；独立创建以允许调用方后续局部修改而不影响共享主题。
	var panel_style: StyleBoxFlat = _create_flat_style(get_window_background_color(), get_window_border_color(), 2, WINDOW_CORNER_RADIUS)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	panel_style.shadow_size = 10
	return panel_style


## 创建窗口内部子分区 StyleBox；默认使用 1 像素弱描边和 6 像素圆角。
static func create_section_panel_style() -> StyleBoxFlat:
	return _create_flat_style(get_section_background_color(), get_section_border_color(), 1, SECTION_CORNER_RADIUS)


## 创建弹窗 StyleBox；透明度会同时影响背景和边框，用于数量、转账、确认及信息提示窗口。
static func create_dialog_panel_style(background_alpha: float = 0.92) -> StyleBoxFlat:
	# 安全透明度；限制在可读范围内，防止调用方传入异常值导致窗口完全透明或不透明。
	var resolved_alpha: float = clampf(background_alpha, 0.40, 1.0)
	# 弹窗背景色；沿用主窗口 RGB，仅替换调用方指定透明度。
	var dialog_background: Color = Color(get_window_background_color(), resolved_alpha)
	# 弹窗边框色；始终比背景略不透明，保证复杂场景上仍能辨认窗口边界。
	var dialog_border: Color = Color(get_window_border_color(), minf(resolved_alpha + 0.10, 1.0))
	return _create_flat_style(dialog_background, dialog_border, 2, WINDOW_CORNER_RADIUS, 14.0, 10.0)


## 创建只覆盖 Window 系列的独立弹窗主题；专用弹窗可保留自己的尺寸和内容布局。
static func create_dialog_theme(background_alpha: float = 0.92) -> Theme:
	# 弹窗主题；先继承完整控件主题，确保底部确认、取消和输入控件同样统一。
	var dialog_theme: Theme = create_theme()
	# 弹窗面板样式；同时覆盖三种窗口类型以兼容不同 Godot 版本的主题查找路径。
	var dialog_panel_style: StyleBoxFlat = create_dialog_panel_style(background_alpha)
	dialog_theme.set_stylebox("panel", "Window", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "AcceptDialog", dialog_panel_style)
	dialog_theme.set_stylebox("panel", "ConfirmationDialog", dialog_panel_style)
	return dialog_theme


## 创建由 DialogOuterFrame 直接绘制的最外层轮廓；中心透明，仅覆盖完全不透明的青蓝边框与阴影。
static func create_dialog_outer_frame_style() -> StyleBoxFlat:
	# 最外层样式；中心关闭绘制，避免覆盖弹窗正文、输入控件和按钮。
	var outer_style: StyleBoxFlat = _create_flat_style(Color.TRANSPARENT, Color(get_window_border_color(), 1.0), DIALOG_OUTER_BORDER_WIDTH, DIALOG_OUTER_CORNER_RADIUS)
	outer_style.draw_center = false
	outer_style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	outer_style.shadow_size = 8
	return outer_style


## 写入指定主题类型的完整按钮状态；同一函数保证普通、主操作、危险和下拉按钮结构一致。
static func _set_button_styles(target_theme: Theme, theme_type: StringName, normal_color: Color, hover_color: Color, pressed_color: Color, border_color: Color) -> void:
	# 正常按钮样式；提供稳定边框、圆角和左右内容留白。
	var normal_style: StyleBoxFlat = _create_flat_style(normal_color, border_color, 1, 5, 11.0, 6.0)
	# 悬停按钮样式；提高背景和描边亮度，帮助鼠标定位。
	var hover_style: StyleBoxFlat = _create_flat_style(hover_color, ACCENT_COLOR, 1, 5, 11.0, 6.0)
	# 按下按钮样式；使用更深背景和明亮描边确认点击状态。
	var pressed_style: StyleBoxFlat = _create_flat_style(pressed_color, ACCENT_COLOR, 1, 5, 11.0, 6.0)
	# 禁用按钮样式；保持边界可辨认但显著降低饱和度。
	var disabled_style: StyleBoxFlat = _create_flat_style(DISABLED_BACKGROUND_COLOR, Color(0.20, 0.24, 0.27, 0.82), 1, 5, 11.0, 6.0)
	# 焦点按钮样式；透明背景只绘制青蓝描边，避免覆盖当前交互状态。
	var focus_style: StyleBoxFlat = _create_flat_style(Color.TRANSPARENT, ACCENT_COLOR, 2, 5)
	target_theme.set_stylebox("normal", theme_type, normal_style)
	target_theme.set_stylebox("hover", theme_type, hover_style)
	target_theme.set_stylebox("pressed", theme_type, pressed_style)
	target_theme.set_stylebox("hover_pressed", theme_type, hover_style)
	target_theme.set_stylebox("disabled", theme_type, disabled_style)
	target_theme.set_stylebox("focus", theme_type, focus_style)
	target_theme.set_color("font_color", theme_type, PRIMARY_TEXT_COLOR)
	target_theme.set_color("font_hover_color", theme_type, Color.WHITE)
	target_theme.set_color("font_pressed_color", theme_type, Color.WHITE)
	target_theme.set_color("font_focus_color", theme_type, Color.WHITE)
	target_theme.set_color("font_hover_pressed_color", theme_type, Color.WHITE)
	target_theme.set_color("font_disabled_color", theme_type, DISABLED_TEXT_COLOR)


## 写入角色选择按钮的普通、悬停、选中与选中悬停状态，避免 toggle 按钮在当前角色上失去鼠标反馈。
static func _set_character_selector_button_styles(target_theme: Theme) -> void:
	# 角色按钮正常样式；未选中时沿用普通冷色按钮，保持列表层级稳定。
	var normal_style: StyleBoxFlat = _create_flat_style(BUTTON_BACKGROUND_COLOR, ACCENT_MUTED_COLOR, 1, 5, 11.0, 6.0)
	# 角色按钮悬停样式；未选中角色经过鼠标时使用普通悬停青蓝色。
	var hover_style: StyleBoxFlat = _create_flat_style(BUTTON_HOVER_COLOR, ACCENT_COLOR, 1, 5, 11.0, 6.0)
	# 角色按钮选中样式；常驻显示当前角色并使用更亮描边。
	var selected_style: StyleBoxFlat = _create_flat_style(CHARACTER_SELECTED_COLOR, ACCENT_COLOR, 2, 5, 11.0, 6.0)
	# 角色按钮选中悬停样式；在常驻选中底色上继续提亮，明确当前按钮仍可交互。
	var selected_hover_style: StyleBoxFlat = _create_flat_style(CHARACTER_SELECTED_HOVER_COLOR, Color.WHITE, 2, 5, 11.0, 6.0)
	# 角色按钮禁用样式；保留边界但降低饱和度，供未来锁定角色列表复用。
	var disabled_style: StyleBoxFlat = _create_flat_style(DISABLED_BACKGROUND_COLOR, Color(0.20, 0.24, 0.27, 0.82), 1, 5, 11.0, 6.0)
	# 角色按钮焦点样式；只绘制外层强调边框，避免覆盖鼠标与选中状态底色。
	var focus_style: StyleBoxFlat = _create_flat_style(Color.TRANSPARENT, ACCENT_COLOR, 2, 5)
	target_theme.set_stylebox("normal", "CharacterSelectorButton", normal_style)
	target_theme.set_stylebox("hover", "CharacterSelectorButton", hover_style)
	target_theme.set_stylebox("pressed", "CharacterSelectorButton", selected_style)
	target_theme.set_stylebox("hover_pressed", "CharacterSelectorButton", selected_hover_style)
	target_theme.set_stylebox("disabled", "CharacterSelectorButton", disabled_style)
	target_theme.set_stylebox("focus", "CharacterSelectorButton", focus_style)
	target_theme.set_color("font_color", "CharacterSelectorButton", PRIMARY_TEXT_COLOR)
	target_theme.set_color("font_hover_color", "CharacterSelectorButton", Color.WHITE)
	target_theme.set_color("font_pressed_color", "CharacterSelectorButton", Color.WHITE)
	target_theme.set_color("font_hover_pressed_color", "CharacterSelectorButton", Color.WHITE)
	target_theme.set_color("font_focus_color", "CharacterSelectorButton", Color.WHITE)
	target_theme.set_color("font_disabled_color", "CharacterSelectorButton", DISABLED_TEXT_COLOR)


## 写入复选框和开关文字颜色；图标继续沿用 Godot 内置资源，保证不同输入设备兼容。
static func _set_toggle_colors(target_theme: Theme, theme_type: StringName) -> void:
	target_theme.set_color("font_color", theme_type, PRIMARY_TEXT_COLOR)
	target_theme.set_color("font_hover_color", theme_type, Color.WHITE)
	target_theme.set_color("font_pressed_color", theme_type, ACCENT_COLOR)
	target_theme.set_color("font_focus_color", theme_type, ACCENT_COLOR)
	target_theme.set_color("font_disabled_color", theme_type, DISABLED_TEXT_COLOR)


## 创建统一 StyleBoxFlat；可选内容边距用于按钮、输入框和工具提示，0 表示不额外占用空间。
static func _create_flat_style(background_color: Color, border_color: Color, border_width: int, corner_radius: int, horizontal_content_margin: float = 0.0, vertical_content_margin: float = 0.0) -> StyleBoxFlat:
	# 新平面样式；所有颜色和尺寸均来自调用参数，不引用节点运行时状态。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(maxi(border_width, 0))
	style.set_corner_radius_all(maxi(corner_radius, 0))
	style.content_margin_left = maxf(horizontal_content_margin, 0.0)
	style.content_margin_right = maxf(horizontal_content_margin, 0.0)
	style.content_margin_top = maxf(vertical_content_margin, 0.0)
	style.content_margin_bottom = maxf(vertical_content_margin, 0.0)
	return style


## 获取当前场景树中的 UI 风格设置 AutoLoad；静态样式函数通过本入口保持对业务服务零依赖。
static func _get_ui_style_settings() -> Node:
	# 主循环；编辑器导入、资源检查或纯脚本环境中可能不是 SceneTree，此时不访问场景根节点。
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	# 场景树；只用于读取固定 AutoLoad 节点，不持有其引用或访问其他业务服务。
	var scene_tree: SceneTree = main_loop as SceneTree
	return scene_tree.root.get_node_or_null("UiStyleSettings")
