extends PanelContainer
class_name HackModeSelectPanel

## 骇入模式选择面板：主菜单与主大厅点击“骇入”后先进入本界面，再选择具体骇入模式入场。
## 模式清单、分组与说明完全读取 HackModeRules 定义表，本面板不复制任何模式数值；
## 分组固定为“战斗模式”（正常产出结算）与“娱乐模式”（与训练场一致不产出结算）。
## 面板只负责展示与派发选择结果；写入 SessionState 与切换场景由宿主（主菜单）完成。

## 模式选择信号；参数为 HackModeRules 定义的稳定模式标识，宿主收到后写入会话状态并进入战斗。
signal mode_selected(variant: String)
## 面板关闭信号；宿主收到后隐藏遮罩并恢复入口按钮焦点。
signal closed

## 全局窗口样式指南；面板窗口、分组标题、模式卡与按钮统一从这里取色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 分组展示顺序；战斗模式在上、娱乐模式在下，修改顺序会影响界面分组排列。
const CATEGORY_ORDER: Array[String] = [HackModeRules.CATEGORY_BATTLE, HackModeRules.CATEGORY_CASUAL]
## 分组补充说明表；键为分组标识，值为分组标题右侧的规则提示文案。
const CATEGORY_HINTS: Dictionary = {
	"battle": "正常产出物品与结算",
	"casual": "不产出物品结算",
}
## 模式进入按钮尺寸；宽 96 高 38 像素，与联机面板操作按钮规格一致。
const ENTER_BUTTON_SIZE: Vector2 = Vector2(96.0, 38.0)
## 模式选择窗口内容横向页边距；默认 18 像素，避免模式卡边框贴住或覆盖最外层窗口描边。
const CONTENT_HORIZONTAL_MARGIN: int = 18
## 模式选择窗口内容纵向页边距；默认 16 像素，保证标题、分组滚动区和返回按钮与窗口边框保持稳定留白。
const CONTENT_VERTICAL_MARGIN: int = 16


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_build_content()


func _build_content() -> void:
	## 构建面板完整内容；标题、两个分组区与底部返回按钮全部在运行时创建。
	# 内容页边距容器；为模式分组和卡片提供统一安全距离，内部描边不会再贴住最外层窗口描边。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_top", CONTENT_VERTICAL_MARGIN)
	content_margin.add_theme_constant_override("margin_right", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", CONTENT_VERTICAL_MARGIN)
	add_child(content_margin)
	# 根布局容器；纵向排列标题、分组与返回按钮。
	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 10)
	content_margin.add_child(root_layout)
	# 面板标题；与其他局外面板一致使用 24 号标题。
	var title_label: Label = Label.new()
	title_label.text = "骇入模式"
	UI_STYLE_GUIDE.apply_title_label(title_label, 24)
	root_layout.add_child(title_label)
	# 副标题提示；说明分组含义，帮助玩家理解娱乐模式无结算。
	var subtitle_label: Label = Label.new()
	subtitle_label.text = "选择本次骇入使用的模式；娱乐模式与训练场一致，不产出物品得失结算。"
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(subtitle_label)
	root_layout.add_child(subtitle_label)
	# 分组滚动容器；模式数量增加时保持面板高度稳定，由内部内容滚动。
	var mode_scroll: ScrollContainer = ScrollContainer.new()
	mode_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_layout.add_child(mode_scroll)
	# 分组纵向布局；依次放入战斗模式区与娱乐模式区。
	var category_layout: VBoxContainer = VBoxContainer.new()
	category_layout.add_theme_constant_override("separation", 12)
	category_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_scroll.add_child(category_layout)
	for category_id in CATEGORY_ORDER:
		category_layout.add_child(_build_category_section(category_id))
	# 返回按钮；与其他局外面板同规格，关闭面板不写入任何会话状态。
	var close_button: Button = Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.pressed.connect(_on_close_button_pressed)
	root_layout.add_child(close_button)


func _build_category_section(category_id: String) -> Control:
	## 构建一个模式分组区；分组标题加规则提示在上，分组内全部模式卡纵向排列在下。
	# 分组容器；标题与模式卡共用一个纵向布局。
	var section_layout: VBoxContainer = VBoxContainer.new()
	section_layout.add_theme_constant_override("separation", 8)
	section_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 分组标题行；左侧分组名、右侧规则提示。
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	section_layout.add_child(header_row)
	# 分组标题；使用强调文字色区分两组模式。
	var header_label: Label = Label.new()
	header_label.text = HackModeRules.get_category_display_name(category_id)
	UI_STYLE_GUIDE.apply_muted_accent_label(header_label)
	header_row.add_child(header_label)
	# 分组规则提示；使用次要文字色说明该组是否产出结算。
	var hint_label: Label = Label.new()
	hint_label.text = str(CATEGORY_HINTS.get(category_id, ""))
	UI_STYLE_GUIDE.apply_secondary_label(hint_label)
	header_row.add_child(hint_label)
	# 模式定义遍历项；按定义表顺序创建当前分组的模式卡。
	for mode_definition in HackModeRules.get_mode_definitions():
		if str(mode_definition.get("category", "")) != category_id:
			continue
		section_layout.add_child(_build_mode_card(mode_definition))
	return section_layout


func _build_mode_card(mode_definition: Dictionary) -> Control:
	## 构建单个模式卡；左侧为模式名与说明，右侧为“进入”按钮。
	# 模式卡外框；使用统一浅色分区面板样式与其他局外面板卡片一致。
	var card_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(card_panel)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 模式卡内边距容器；四边留出可读空隙。
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 12)
	card_margin.add_theme_constant_override("margin_right", 12)
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	card_panel.add_child(card_margin)
	# 模式卡横向布局；文本区伸展占满剩余宽度，按钮固定在右侧垂直居中。
	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 12)
	card_margin.add_child(card_row)
	# 模式文本区；模式名在上、说明在下。
	var text_layout: VBoxContainer = VBoxContainer.new()
	text_layout.add_theme_constant_override("separation", 4)
	text_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_row.add_child(text_layout)
	# 模式名称标签；使用 18 号标题字号突出模式名。
	var name_label: Label = Label.new()
	name_label.text = str(mode_definition.get("display_name", "标准骇入"))
	UI_STYLE_GUIDE.apply_title_label(name_label, 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_layout.add_child(name_label)
	# 模式说明标签；自动换行展示完整规则文案。
	var description_label: Label = Label.new()
	description_label.text = str(mode_definition.get("description", ""))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(description_label)
	text_layout.add_child(description_label)
	# 进入按钮；点击后派发模式选择信号，由宿主写入会话状态并进入战斗。
	var enter_button: Button = Button.new()
	enter_button.text = "进入"
	enter_button.custom_minimum_size = ENTER_BUTTON_SIZE
	enter_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI_STYLE_GUIDE.apply_primary_button(enter_button)
	enter_button.pressed.connect(_on_enter_button_pressed.bind(str(mode_definition.get("variant", HackModeRules.VARIANT_STANDARD))))
	card_row.add_child(enter_button)
	return card_panel


func _on_enter_button_pressed(variant: String) -> void:
	mode_selected.emit(HackModeRules.normalize_variant(variant))


func _on_close_button_pressed() -> void:
	closed.emit()
