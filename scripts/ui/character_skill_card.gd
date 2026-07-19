extends PanelContainer
class_name CharacterSkillCard

## 角色技能卡片只负责把一个技能的名称、类型、冷却、能耗和说明组织为可展开的独立展示单元。
## 宿主通过 configure() 注入已格式化的展示数据，卡片不读取角色目录、会话状态或战斗组件。

## 全局窗口样式指南；提供统一颜色、边框和文字层级，运行时不读取业务服务。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 徽章普通边框宽度；固定 1 像素，修改会影响类型、冷却和能耗徽章轮廓。
const BADGE_BORDER_WIDTH: int = 1
## 技能卡片普通边框宽度；固定 1 像素，修改会影响收起且未悬停卡片的视觉层级。
const CARD_NORMAL_BORDER_WIDTH: int = 1
## 技能卡片高亮边框宽度；固定 2 像素，修改会影响悬停和展开状态的强调程度。
const CARD_HIGHLIGHT_BORDER_WIDTH: int = 2
## 可配置字号安全下限；固定 8，避免检查器异常值生成不可读文字。
const MINIMUM_FONT_SIZE: int = 8
## 徽章高度安全下限；固定 16 像素，避免检查器异常值压缩文字点击行。
const MINIMUM_BADGE_HEIGHT: float = 16.0

## 卡片内容水平边距；默认 12 像素，修改会影响标题、徽章和说明距离边框的留白，通常不需要运行时动态修改。
@export_range(0, 48, 1) var content_horizontal_margin: int = 12
## 卡片内容垂直边距；默认 9 像素，修改会影响收起高度与展开说明留白，通常不需要运行时动态修改。
@export_range(0, 48, 1) var content_vertical_margin: int = 9
## 标题行元素间距；默认 8 像素，修改会影响技能名与三个徽章之间的距离，通常不需要运行时动态修改。
@export_range(0, 32, 1) var header_separation: int = 8
## 技能名字号；默认 17，修改会影响技能卡片第一行的信息层级，通常不需要运行时动态修改。
@export_range(8, 48, 1) var skill_name_font_size: int = 17
## 徽章字号；默认 12，修改会影响“主动/被动”“CD”和“能耗”的紧凑程度，通常不需要运行时动态修改。
@export_range(8, 32, 1) var badge_font_size: int = 12
## 徽章最小高度；默认 26 像素，修改会影响圆角方框的点击行高度，通常不需要运行时动态修改。
@export_range(16.0, 64.0, 1.0) var badge_minimum_height: float = 26.0
## 徽章水平内边距；默认 9 像素，修改会影响徽章宽度与文字两侧留白，通常不需要运行时动态修改。
@export_range(0.0, 32.0, 1.0) var badge_horizontal_padding: float = 9.0
## 徽章垂直内边距；默认 4 像素，修改会影响徽章文字上下留白，通常不需要运行时动态修改。
@export_range(0.0, 24.0, 1.0) var badge_vertical_padding: float = 4.0
## 说明与标题行间距；默认 8 像素，只在技能卡片展开时生效，通常不需要运行时动态修改。
@export_range(0, 32, 1) var description_top_spacing: int = 8

## 技能显示名称；默认“未命名技能”，由宿主配置，修改会刷新第一行名称但不影响技能行为。
var _skill_name: String = "未命名技能"
## 技能完整说明；默认空字符串，由宿主配置，空值会显示“暂无技能描述”。
var _skill_description: String = ""
## 技能类型文本；取值通常为“主动”或“被动”，默认“主动”，只影响徽章显示与颜色。
var _skill_type: String = "主动"
## 技能冷却秒数；取值大于等于 0，默认 0，由宿主从技能资源读取，只用于展示。
var _cooldown_seconds: float = 0.0
## 技能能量消耗；取值大于等于 0，默认 0，由宿主从技能资源读取，只用于展示。
var _energy_cost: int = 0
## 是否显示冷却与能耗徽章；默认 true，衍生单位详情卡只保留类型徽章时设为 false。
var _show_cost_badges: bool = true
## 卡片展开状态；默认 false 表示只显示第一行，点击标题行后切换说明可见性。
var _expanded: bool = false
## 标题行悬停状态；默认 false，鼠标进入标题行后用于提高卡片背景亮度。
var _header_hovered: bool = false
## 卡片是否已经完成控件构建；默认 false，进入场景树后变为 true，防止配置早于 ready 时访问空节点。
var _interface_ready: bool = false

## 标题交互面板；承载技能名与徽章并处理鼠标、键盘展开操作。
var _header_panel: PanelContainer
## 技能名称标签；显示卡片第一行左侧名称，并占用剩余水平空间。
var _skill_name_label: Label
## 技能类型徽章标签；显示“主动”或“被动”。
var _type_badge_label: Label
## 冷却徽章标签；显示“CD xxs”格式的基础冷却时间。
var _cooldown_badge_label: Label
## 冷却徽章面板；衍生单位详情卡会隐藏整个面板，技能卡保持显示。
var _cooldown_badge_panel: PanelContainer
## 能耗徽章标签；显示“能耗 xx”格式的整数能量消耗。
var _energy_badge_label: Label
## 能耗徽章面板；衍生单位详情卡会隐藏整个面板，技能卡保持显示。
var _energy_badge_panel: PanelContainer
## 技能说明标签；默认隐藏，展开后自动换行显示完整技能说明。
var _description_label: Label


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	_build_interface()
	_interface_ready = true
	_refresh_display()
	# UI 风格服务；主题根重建完成后才同步局部卡片样式，避免在主题通知的递归阶段重复创建 StyleBox。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))


func configure(skill_name: String, skill_description: String, skill_type: String, cooldown_seconds: float, energy_cost: int) -> void:
	## 注入一个技能的只读展示数据；该方法可在节点进入场景树前调用，进入后会自动同步控件。
	_skill_name = skill_name.strip_edges() if not skill_name.strip_edges().is_empty() else "未命名技能"
	_skill_description = skill_description.strip_edges()
	_skill_type = skill_type.strip_edges() if not skill_type.strip_edges().is_empty() else "主动"
	_cooldown_seconds = maxf(cooldown_seconds, 0.0)
	_energy_cost = maxi(energy_cost, 0)
	_show_cost_badges = true
	if _interface_ready:
		_refresh_display()


func configure_detail_card(title: String, detail_text: String, type_text: String) -> void:
	## 配置不含冷却与能耗的通用展开卡片；当前用于角色展示中的衍生单位分类。
	_skill_name = title.strip_edges() if not title.strip_edges().is_empty() else "未命名单位"
	_skill_description = detail_text.strip_edges()
	_skill_type = type_text.strip_edges() if not type_text.strip_edges().is_empty() else "衍生单位"
	_show_cost_badges = false
	if _interface_ready:
		_refresh_display()


func set_expanded(expanded: bool) -> void:
	## 显式设置说明展开状态；宿主可用于恢复界面状态，重复设置不会触发额外重建。
	if _expanded == expanded:
		return
	_expanded = expanded
	if _interface_ready:
		_refresh_expanded_state()


func _build_interface() -> void:
	## 创建稳定控件树；后续配置与展开只更新文本、可见性和样式，不销毁或重建子节点。
	# 卡片边距容器；保证标题和说明不会贴住整体圆角边框。
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", maxi(content_horizontal_margin, 0))
	card_margin.add_theme_constant_override("margin_top", maxi(content_vertical_margin, 0))
	card_margin.add_theme_constant_override("margin_right", maxi(content_horizontal_margin, 0))
	card_margin.add_theme_constant_override("margin_bottom", maxi(content_vertical_margin, 0))
	add_child(card_margin)
	# 卡片纵向内容；标题行固定在第一行，说明只在展开状态加入可见高度。
	var card_content: VBoxContainer = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", maxi(description_top_spacing, 0))
	card_margin.add_child(card_content)
	# 标题交互面板；完整覆盖第一行并提供焦点、悬停和点击输入。
	_header_panel = PanelContainer.new()
	_header_panel.focus_mode = Control.FOCUS_ALL
	_header_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_header_panel.tooltip_text = "点击展开技能描述"
	_header_panel.gui_input.connect(_on_header_gui_input)
	_header_panel.mouse_entered.connect(_on_header_mouse_entered)
	_header_panel.mouse_exited.connect(_on_header_mouse_exited)
	card_content.add_child(_header_panel)
	# 标题行内容；技能名伸展占位，三个徽章保持内容宽度并右对齐。
	var header_content: HBoxContainer = HBoxContainer.new()
	header_content.add_theme_constant_override("separation", maxi(header_separation, 0))
	_header_panel.add_child(header_content)
	_skill_name_label = Label.new()
	_skill_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_name_label.add_theme_font_size_override("font_size", maxi(skill_name_font_size, MINIMUM_FONT_SIZE))
	_skill_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_content.add_child(_skill_name_label)
	# 技能类型徽章；主动使用青蓝色，被动使用紫蓝色，颜色在刷新时按类型更新。
	var type_badge: PanelContainer = _create_badge_panel(UI_STYLE_GUIDE.CHARACTER_SKILL_ACTIVE_BADGE_COLOR)
	_type_badge_label = type_badge.get_child(0) as Label
	header_content.add_child(type_badge)
	# 冷却徽章；统一使用弱青蓝色，数值来自技能资源基础冷却。
	_cooldown_badge_panel = _create_badge_panel(UI_STYLE_GUIDE.CHARACTER_SKILL_COOLDOWN_BADGE_COLOR)
	_cooldown_badge_label = _cooldown_badge_panel.get_child(0) as Label
	header_content.add_child(_cooldown_badge_panel)
	# 能耗徽章；使用暖黄色弱背景，帮助与冷却信息快速区分。
	_energy_badge_panel = _create_badge_panel(UI_STYLE_GUIDE.CHARACTER_SKILL_ENERGY_BADGE_COLOR)
	_energy_badge_label = _energy_badge_panel.get_child(0) as Label
	header_content.add_child(_energy_badge_panel)
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI_STYLE_GUIDE.apply_secondary_label(_description_label)
	card_content.add_child(_description_label)


func _create_badge_panel(background_color: Color) -> PanelContainer:
	## 创建一个带圆角边框的只读徽章；返回面板的第一个子节点固定为文本标签。
	# 徽章面板；最小高度保证三个徽章在同一标题行中对齐。
	var badge_panel: PanelContainer = PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(0.0, maxf(badge_minimum_height, MINIMUM_BADGE_HEIGHT))
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 徽章样式；使用 1 像素强调边框和 6 像素圆角形成紧凑方框。
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = background_color
	badge_style.border_color = UI_STYLE_GUIDE.CHARACTER_SKILL_BADGE_BORDER_COLOR
	badge_style.set_border_width_all(BADGE_BORDER_WIDTH)
	badge_style.set_corner_radius_all(UI_STYLE_GUIDE.SECTION_CORNER_RADIUS)
	badge_style.content_margin_left = maxf(badge_horizontal_padding, 0.0)
	badge_style.content_margin_top = maxf(badge_vertical_padding, 0.0)
	badge_style.content_margin_right = maxf(badge_horizontal_padding, 0.0)
	badge_style.content_margin_bottom = maxf(badge_vertical_padding, 0.0)
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	# 徽章文本；水平和垂直居中，鼠标事件继续交给标题交互面板。
	var badge_label: Label = Label.new()
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", maxi(badge_font_size, MINIMUM_FONT_SIZE))
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_child(badge_label)
	return badge_panel


func _refresh_display() -> void:
	## 同步全部展示文本与类型颜色；不改变宿主保存的技能资源或技能运行状态。
	_skill_name_label.text = _skill_name
	_type_badge_label.text = _skill_type
	_cooldown_badge_label.text = "CD %s" % _format_seconds(_cooldown_seconds)
	_energy_badge_label.text = "能耗 %d" % _energy_cost
	# 冷却徽章可见性；主动技能保持完整展示，被动技能仅在确实配置正冷却时显示。
	_cooldown_badge_panel.visible = _show_cost_badges and (_skill_type != "被动" or _cooldown_seconds > 0.0)
	# 能耗徽章可见性；主动技能保持完整展示，被动技能仅在确实配置正能耗时显示。
	_energy_badge_panel.visible = _show_cost_badges and (_skill_type != "被动" or _energy_cost > 0)
	_description_label.text = _skill_description if not _skill_description.is_empty() else "暂无技能描述"
	# 类型徽章父面板；被动使用紫蓝底，主动使用青蓝底，未知类型继续按主动视觉处理。
	var type_badge_panel: PanelContainer = _type_badge_label.get_parent() as PanelContainer
	# 类型徽章背景色；只影响技能分类辨识，不表达冷却或可释放状态。
	var type_background_color: Color = UI_STYLE_GUIDE.CHARACTER_SKILL_PASSIVE_BADGE_COLOR if _skill_type == "被动" else UI_STYLE_GUIDE.CHARACTER_SKILL_ACTIVE_BADGE_COLOR
	# 类型徽章样式；保留创建时的尺寸、边框和圆角，仅替换背景颜色。
	var type_badge_style: StyleBoxFlat = type_badge_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if type_badge_style != null:
		# 独立样式副本；避免多个卡片共享资源时相互覆盖类型颜色。
		var duplicated_style: StyleBoxFlat = type_badge_style.duplicate() as StyleBoxFlat
		duplicated_style.bg_color = type_background_color
		type_badge_panel.add_theme_stylebox_override("panel", duplicated_style)
	_refresh_expanded_state()


func _refresh_expanded_state() -> void:
	## 更新说明可见性、提示文字与卡片高亮，展开不会修改技能数据。
	_description_label.visible = _expanded
	_header_panel.tooltip_text = "点击收起技能描述" if _expanded else "点击展开技能描述"
	_apply_card_style(_expanded or _header_hovered)
	_apply_header_style(_header_hovered)


func _apply_card_style(highlighted: bool) -> void:
	## 根据展开或悬停状态更新整体边框；尺寸与内容留白保持不变，避免列表跳动。
	# 卡片样式；普通状态使用弱分区色，高亮状态提高背景和边框亮度。
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = UI_STYLE_GUIDE.get_character_skill_card_highlight_color() if highlighted else UI_STYLE_GUIDE.get_section_background_color()
	card_style.border_color = UI_STYLE_GUIDE.get_accent_color() if highlighted else UI_STYLE_GUIDE.get_section_border_color()
	card_style.set_border_width_all(CARD_HIGHLIGHT_BORDER_WIDTH if highlighted else CARD_NORMAL_BORDER_WIDTH)
	card_style.set_corner_radius_all(UI_STYLE_GUIDE.SECTION_CORNER_RADIUS)
	add_theme_stylebox_override("panel", card_style)


func _apply_header_style(hovered: bool) -> void:
	## 更新标题行背景；悬停时显示弱青蓝底，普通状态保持透明以突出整体卡片边框。
	# 标题样式；透明边框避免标题行与卡片整体边框形成重复轮廓。
	var header_style: StyleBoxFlat = StyleBoxFlat.new()
	header_style.bg_color = UI_STYLE_GUIDE.get_character_skill_header_hover_color() if hovered else Color.TRANSPARENT
	header_style.set_corner_radius_all(UI_STYLE_GUIDE.SECTION_CORNER_RADIUS)
	_header_panel.add_theme_stylebox_override("panel", header_style)


func _format_seconds(seconds: float) -> String:
	## 把冷却秒数格式化为紧凑文本；整数不显示小数，非整数最多保留一位。
	if is_equal_approx(seconds, roundf(seconds)):
		return "%ds" % roundi(seconds)
	return "%.1fs" % seconds


func _toggle_expanded() -> void:
	## 切换说明可见性并保留当前卡片实例，滚动容器会自动更新内容高度。
	_expanded = not _expanded
	_refresh_expanded_state()


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# 鼠标按钮事件；只在左键按下边沿切换，释放事件不会再次触发。
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_toggle_expanded()
			_header_panel.grab_focus()
			accept_event()
		return
	if event is InputEventKey:
		# 键盘事件；标题行获得焦点后允许回车或空格展开，便于无鼠标操作。
		var key_event: InputEventKey = event as InputEventKey
		# 有效键码；优先读取物理键位，兼容只填写 keycode 的人工输入事件。
		var effective_keycode: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		if key_event.pressed and not key_event.echo and effective_keycode in [KEY_ENTER, KEY_SPACE]:
			_toggle_expanded()
			accept_event()


func _on_header_mouse_entered() -> void:
	_header_hovered = true
	_refresh_expanded_state()


func _on_header_mouse_exited() -> void:
	_header_hovered = false
	_refresh_expanded_state()


func _on_ui_style_changed(_style_id: String) -> void:
	## 在风格服务完成根主题刷新后重建局部卡片样式；技能徽章的业务颜色不在此处改写。
	if not _interface_ready or not is_inside_tree() or _header_panel == null or not is_instance_valid(_header_panel):
		return
	_refresh_expanded_state()
