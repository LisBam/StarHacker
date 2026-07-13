extends Control

## 独立角色系统负责查看和确认当前角色，不再作为进入骇入或训练场的前置步骤。
## 左侧按钮只切换当前查看目标，右侧详情面板展示角色定位、基础数值和后续技能入口。

## 当前角色展示模式关闭请求；宿主收到后负责隐藏界面并恢复游戏，完整选择模式不会发出。
signal close_requested

## 星角色标识；默认与 SessionState 保持一致，修改会影响星按钮的选择目标。
const CHARACTER_STELLE: String = "stelle"
## 穹角色标识；默认与 SessionState 保持一致，修改会影响穹按钮的选择目标。
const CHARACTER_CAEULUS: String = "caelus"
## 银狼角色标识；默认与 SessionState 保持一致，修改会影响银狼按钮的选择目标。
const CHARACTER_SILVER_WOLF: String = "silver_wolf"
## 全局窗口样式指南；统一角色列表、详情分区、属性条和底部操作按钮的视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 可展开角色技能卡片脚本；只接收展示数据并负责单个技能的圆角边框、徽章和说明展开交互。
const CHARACTER_SKILL_CARD_SCRIPT: Script = preload("res://scripts/ui/character_skill_card.gd")
## 完整角色选择模式；显示左侧角色列表、确认按钮和返回主菜单入口。
const DISPLAY_MODE_SELECTION: int = 0
## 当前角色展示模式；隐藏左侧角色列表，只显示会话中已选角色并由宿主处理关闭请求。
const DISPLAY_MODE_CURRENT_CHARACTER: int = 1
## 当前角色详情面板安全最小宽度；固定 480 像素，避免检查器异常值让技能徽章和说明无法阅读。
const CURRENT_CHARACTER_PANEL_MINIMUM_WIDTH: float = 480.0

## 主菜单场景路径；默认返回项目主菜单，只允许填写 tscn 资源，运行时通常不动态修改。
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
## 数值条显示上限；取值应大于 0，默认 200 覆盖当前占位生命和能量范围，修改会影响详情面板条形比例。
@export_range(1.0, 9999.0, 1.0, "or_greater") var stat_bar_maximum: float = 200.0
## 速度条显示上限；取值应大于 0，默认 140 对应旧规则 420 速度，修改会影响速度条形比例。
@export_range(1.0, 9999.0, 1.0, "or_greater") var speed_bar_maximum: float = 140.0
## 攻击力条显示上限；取值应大于 0，默认 200 覆盖当前角色基础攻击力，修改会影响攻击力条形比例。
@export_range(1.0, 99999.0, 1.0, "or_greater") var attack_bar_maximum: float = 200.0
## 防御力条显示上限；取值应大于 0，默认 200 覆盖当前角色基础防御力，修改会影响防御力条形比例。
@export_range(1.0, 99999.0, 1.0, "or_greater") var defense_bar_maximum: float = 200.0
## 界面展示模式；0 为完整角色选择，1 为战斗内当前角色展示，通常由宿主在实例进入场景树前配置。
@export_enum("角色选择", "当前角色展示") var display_mode: int = DISPLAY_MODE_SELECTION
## 当前角色展示模式的详情面板宽度；默认 860 像素，保持与完整角色系统右侧信息区接近，通常不需要运行时动态修改。
@export_range(480.0, 1600.0, 1.0) var current_character_panel_width: float = 860.0

## 当前选中的角色标识；取值为 stelle、caelus 或 silver_wolf，默认 stelle，修改会影响确认进入的角色。
var _selected_character_id: String = CHARACTER_STELLE
## 角色按钮表；键为自动目录中的稳定角色 ID，值为对应列表按钮，运行时由现有按钮和新增资源共同构建。
var _character_buttons: Dictionary = {}
## 角色按钮滚动内容；默认在 ready 中创建，承载全部内置与自动发现按钮，角色数量增加时可纵向滚动访问。
var _character_button_container: VBoxContainer
## 被动技能卡片缓存；元素为 CharacterSkillCard，切换角色时释放旧卡片并按资源数组重建。
var _passive_skill_cards: Array[Control] = []
## 主动技能卡片缓存；元素为 CharacterSkillCard，切换角色时释放旧卡片并按资源数组重建。
var _active_skill_cards: Array[Control] = []
## 衍生单位卡片缓存；元素为可展开详情卡，切换角色时释放旧卡片并按角色资源重建。
var _derived_unit_cards: Array[Control] = []

## 页面背景缓存；完整选择模式显示不透明页面背景，战斗内展示模式显示统一半透明遮罩。
@onready var _background: ColorRect = get_node("Background") as ColorRect
## 主列容器缓存；完整模式左右分栏，当前角色展示模式改为居中单栏。
@onready var _main_columns: HBoxContainer = get_node("RootMargin/RootContent/MainColumns") as HBoxContainer
## 左侧角色列表面板缓存；当前角色展示模式隐藏该面板，避免战斗内切换角色。
@onready var _character_list_panel: PanelContainer = get_node("RootMargin/RootContent/MainColumns/CharacterListPanel") as PanelContainer
## 右侧角色详情面板缓存；两种模式共享同一属性、技能和滚动内容。
@onready var _detail_panel: PanelContainer = get_node("RootMargin/RootContent/MainColumns/DetailPanel") as PanelContainer
## 底部操作容器缓存；完整模式显示返回与确认，当前角色展示模式只保留关闭按钮。
@onready var _bottom_actions: HBoxContainer = get_node("RootMargin/RootContent/BottomActions") as HBoxContainer
## 页面标题缓存；默认绑定 TitleLabel，显示当前模式下的角色选择标题。
@onready var _title_label: Label = %TitleLabel
## 星角色按钮缓存；默认绑定 StelleButton，点击后查看星的详情。
@onready var _stelle_button: Button = %StelleButton
## 穹角色按钮缓存；默认绑定 CaelusButton，点击后查看穹的详情。
@onready var _caelus_button: Button = %CaelusButton
## 银狼角色按钮缓存；默认绑定 SilverWolfButton，点击后查看银狼的详情。
@onready var _silver_wolf_button: Button = %SilverWolfButton
## 角色列表内容容器；默认绑定 CharacterListContent，新发现角色会在底部弹性占位之前动态插入。
@onready var _character_list_content: VBoxContainer = get_node("RootMargin/RootContent/MainColumns/CharacterListPanel/CharacterListMargin/CharacterListContent") as VBoxContainer
## 角色列表底部占位；默认绑定 ListSpacer，动态角色按钮会插入到该节点之前以保持顶部排列。
@onready var _character_list_spacer: Control = get_node("RootMargin/RootContent/MainColumns/CharacterListPanel/CharacterListMargin/CharacterListContent/ListSpacer") as Control
## 角色名称文本缓存；默认绑定 CharacterNameLabel，显示当前查看角色的名称。
@onready var _character_name_label: Label = %CharacterNameLabel
## 角色定位文本缓存；默认绑定 CharacterRoleLabel，显示当前查看角色的临时定位。
@onready var _character_role_label: Label = %CharacterRoleLabel
## 角色说明文本缓存；默认绑定 CharacterDescriptionLabel，显示当前查看角色的占位说明。
@onready var _character_description_label: Label = %CharacterDescriptionLabel
## 生命数值文本缓存；默认绑定 HealthValueLabel，显示当前查看角色的固定生命上限。
@onready var _health_value_label: Label = %HealthValueLabel
## 生命数值条缓存；默认绑定 HealthPreviewBar，用于表现固定生命上限。
@onready var _health_preview_bar: ProgressBar = %HealthPreviewBar
## 能量数值文本缓存；默认绑定 EnergyValueLabel，显示当前查看角色的固定能量上限。
@onready var _energy_value_label: Label = %EnergyValueLabel
## 能量数值条缓存；默认绑定 EnergyPreviewBar，用于表现固定能量上限。
@onready var _energy_preview_bar: ProgressBar = %EnergyPreviewBar
## 速度数值文本缓存；默认绑定 SpeedValueLabel，显示当前查看角色的固定移动速度。
@onready var _speed_value_label: Label = %SpeedValueLabel
## 速度数值条缓存；默认绑定 SpeedPreviewBar，用于表现固定移动速度。
@onready var _speed_preview_bar: ProgressBar = %SpeedPreviewBar
## 攻击力文本缓存；默认绑定 AttackValueLabel，显示当前查看角色的基础攻击力。
@onready var _attack_value_label: Label = %AttackValueLabel
## 攻击力数值条缓存；默认绑定 AttackPreviewBar，用于表现当前查看角色的基础攻击力。
@onready var _attack_preview_bar: ProgressBar = %AttackPreviewBar
## 防御力文本缓存；默认绑定 DefenseValueLabel，显示当前查看角色的基础防御力。
@onready var _defense_value_label: Label = %DefenseValueLabel
## 防御力数值条缓存；默认绑定 DefensePreviewBar，用于表现当前查看角色的基础防御力。
@onready var _defense_preview_bar: ProgressBar = %DefensePreviewBar
## 被动技能文本缓存；默认绑定 PassiveLabel，作为被动技能卡片分区标题。
@onready var _passive_label: Label = %PassiveLabel
## 被动技能卡片容器；默认绑定 PassiveSkillCards，按角色资源数组顺序承载全部被动技能。
@onready var _passive_skill_cards_container: VBoxContainer = %PassiveSkillCards
## 主动技能文本缓存；默认绑定 ActiveLabel，作为主动技能卡片分区标题。
@onready var _active_label: Label = %ActiveLabel
## 主动技能卡片容器；默认绑定 ActiveSkillCards，按角色资源数组顺序承载全部主动技能。
@onready var _active_skill_cards_container: VBoxContainer = %ActiveSkillCards
## 衍生单位分类标题；当前角色没有衍生单位资源时与卡片容器一起隐藏。
@onready var _derived_unit_label: Label = %DerivedUnitLabel
## 衍生单位卡片容器；位于主动技能之后，按角色资源数组顺序显示可展开单位详情。
@onready var _derived_unit_cards_container: VBoxContainer = %DerivedUnitCards
## 确认进入按钮缓存；默认绑定 ConfirmButton，点击后写入角色并进入游戏世界。
@onready var _confirm_button: Button = %ConfirmButton
## 返回按钮缓存；默认绑定 BackButton，点击后回到主菜单。
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_primary_button(_confirm_button)
	UI_STYLE_GUIDE.apply_title_label(_title_label)
	UI_STYLE_GUIDE.apply_title_label(_character_name_label)
	UI_STYLE_GUIDE.apply_section_panel(_character_list_panel)
	UI_STYLE_GUIDE.apply_window_panel(_detail_panel)
	_stelle_button.toggle_mode = true
	_caelus_button.toggle_mode = true
	_silver_wolf_button.toggle_mode = true
	UI_STYLE_GUIDE.apply_character_selector_button(_stelle_button)
	UI_STYLE_GUIDE.apply_character_selector_button(_caelus_button)
	UI_STYLE_GUIDE.apply_character_selector_button(_silver_wolf_button)
	_setup_character_button_scroll()
	_stelle_button.pressed.connect(_on_stelle_button_pressed)
	_caelus_button.pressed.connect(_on_caelus_button_pressed)
	_silver_wolf_button.pressed.connect(_on_silver_wolf_button_pressed)
	_build_character_buttons()
	_confirm_button.pressed.connect(_on_confirm_button_pressed)
	_back_button.pressed.connect(_on_back_button_pressed)
	_selected_character_id = _get_session_selected_character_id()
	_apply_display_mode()
	_refresh_title()
	_select_character(_selected_character_id)


func _refresh_title() -> void:
	if display_mode == DISPLAY_MODE_CURRENT_CHARACTER:
		_title_label.text = "角色展示"
		_back_button.text = "关闭"
		return
	_title_label.text = "角色系统"
	_confirm_button.text = "确认选择"
	_back_button.text = "返回"


func refresh_current_character() -> void:
	## 从 SessionState 重新读取当前已选角色并刷新详情；战斗内每次打开展示界面前调用可同步训练场角色切换结果。
	_selected_character_id = _get_session_selected_character_id()
	_select_character(_selected_character_id)


func focus_default_control() -> void:
	## 把键盘焦点交给当前模式的默认操作；战斗内展示使用关闭按钮，完整模式使用确认按钮。
	if display_mode == DISPLAY_MODE_CURRENT_CHARACTER:
		_back_button.grab_focus()
	else:
		_confirm_button.grab_focus()


func _select_character(character_id: String) -> void:
	_selected_character_id = _normalize_character_id(character_id)
	_set_button_states()
	_refresh_character_detail()


func _set_button_states() -> void:
	for raw_character_id in _character_buttons.keys():
		# 角色按钮；每次选择只更新按下状态，不重新创建节点，保持键盘焦点和交互反馈稳定。
		var character_button: Button = _character_buttons.get(raw_character_id) as Button
		if character_button != null:
			character_button.set_pressed_no_signal(str(raw_character_id) == _selected_character_id)


func _refresh_character_detail() -> void:
	# 当前角色档案；取值来自 SessionState，默认返回星的占位档案，修改会影响详情面板全部显示内容。
	var profile: Dictionary = _get_character_profile(_selected_character_id)
	# 固定生命上限；取值来自角色档案，默认用于文字和条形预览。
	var max_health: float = float(profile.get("max_health", 0.0))
	# 固定能量上限；取值来自角色档案，默认用于文字和条形预览。
	var max_energy: float = float(profile.get("max_energy", 0.0))
	# 固定移动速度；取值来自角色档案，默认用于文字和条形预览。
	var move_speed: float = float(profile.get("move_speed", 0.0))
	# 固定攻击力；取值来自角色档案，默认用于角色选择详情文字。
	var attack_power: float = float(profile.get("attack_power", 0.0))
	# 固定防御力；取值来自角色档案，默认用于角色选择详情文字。
	var defense_power: float = float(profile.get("defense_power", 0.0))
	_character_name_label.text = str(profile.get("display_name", "角色"))
	_character_role_label.text = str(profile.get("role", "未配置定位"))
	_character_description_label.text = str(profile.get("description", "暂无角色说明"))
	_health_value_label.text = "生命上限  %d" % roundi(max_health)
	_energy_value_label.text = "能量上限  %d" % roundi(max_energy)
	_speed_value_label.text = "速度  %d" % roundi(move_speed)
	_attack_value_label.text = "攻击力  %d" % roundi(attack_power)
	_defense_value_label.text = "防御力  %d" % roundi(defense_power)
	_health_preview_bar.max_value = stat_bar_maximum
	_energy_preview_bar.max_value = stat_bar_maximum
	_speed_preview_bar.max_value = speed_bar_maximum
	_attack_preview_bar.max_value = attack_bar_maximum
	_defense_preview_bar.max_value = defense_bar_maximum
	_health_preview_bar.value = clampf(max_health, 0.0, stat_bar_maximum)
	_energy_preview_bar.value = clampf(max_energy, 0.0, stat_bar_maximum)
	_speed_preview_bar.value = clampf(move_speed, 0.0, speed_bar_maximum)
	_attack_preview_bar.value = clampf(attack_power, 0.0, attack_bar_maximum)
	_defense_preview_bar.value = clampf(defense_power, 0.0, defense_bar_maximum)
	_passive_label.text = "被动技能"
	_active_label.text = "主动技能"
	_refresh_skill_cards(_passive_skill_cards_container, _passive_skill_cards, profile.get("passive_skills", []) as Array, str(profile.get("passive", "被动技能：待配置")), "被动")
	_refresh_skill_cards(_active_skill_cards_container, _active_skill_cards, profile.get("active_skills", []) as Array, str(profile.get("active", "主动技能：待配置")), "主动")
	_refresh_derived_unit_cards(profile.get("derived_units", []) as Array)


func _refresh_derived_unit_cards(derived_unit_resources: Array) -> void:
	## 重建当前角色衍生单位分类；空数组隐藏整个分类，不生成占位卡片。
	for unit_card in _derived_unit_cards:
		if unit_card != null and is_instance_valid(unit_card):
			unit_card.queue_free()
	_derived_unit_cards.clear()
	for raw_unit_resource in derived_unit_resources:
		# 衍生单位资源；必须至少提供可读取的名称，空资源直接跳过。
		var unit_resource: Resource = raw_unit_resource as Resource
		if unit_resource == null:
			continue
		# 单位名称；资源缺失名称时使用稳定兜底，避免卡片标题为空。
		var unit_name: String = str(unit_resource.get("display_name")).strip_edges()
		# 单位类型；默认“衍生单位”，友方单位资源可显示更具体阵营。
		var unit_type: String = str(unit_resource.get("unit_type")).strip_edges()
		# 单位详情；优先使用资源格式化入口，缺失时显示暂无详情。
		var detail_text: String = str(unit_resource.call("get_detail_text")) if unit_resource.has_method("get_detail_text") else "暂无单位详情"
		# 通用展开卡片；复用技能卡规格但隐藏无意义的冷却与能耗徽章。
		var unit_card: CharacterSkillCard = CHARACTER_SKILL_CARD_SCRIPT.new() as CharacterSkillCard
		unit_card.configure_detail_card(unit_name, detail_text, unit_type)
		_derived_unit_cards_container.add_child(unit_card)
		_derived_unit_cards.append(unit_card)
	# 分类可见性；标题和容器始终同步，防止空分类留下多余间距。
	var has_derived_units: bool = not _derived_unit_cards.is_empty()
	_derived_unit_label.visible = has_derived_units
	_derived_unit_cards_container.visible = has_derived_units


func _build_skill_detail_text(section_name: String, skill_resources: Array, fallback_text: String) -> String:
	## 把角色的多个技能资源格式化为长期详情文本；空数组继续显示旧档案说明以兼容未迁移角色。
	var skill_lines: PackedStringArray = PackedStringArray()
	for raw_skill_resource in skill_resources:
		# 技能资源；有效项读取显示名称与说明，空资源不会生成占位行。
		var skill_resource: Resource = raw_skill_resource as Resource
		if skill_resource == null:
			continue
		# 技能名称；缺失时回退通用“未命名技能”，保证详情仍能识别资源槽数量。
		var skill_name: String = str(skill_resource.get("display_name")).strip_edges()
		# 技能说明；空说明只显示名称，不额外生成尾随分隔符。
		var skill_description: String = str(skill_resource.get("description")).strip_edges()
		skill_lines.append("%s：%s" % [skill_name if not skill_name.is_empty() else "未命名技能", skill_description] if not skill_description.is_empty() else (skill_name if not skill_name.is_empty() else "未命名技能"))
	return "%s\n%s" % [section_name, "\n\n".join(skill_lines)] if not skill_lines.is_empty() else fallback_text


func _refresh_skill_cards(container: VBoxContainer, card_cache: Array[Control], skill_resources: Array, fallback_text: String, skill_type: String) -> void:
	## 按角色技能资源重建指定分区；切换角色属于低频操作，卡片内部展开时不会重建其他技能。
	for skill_card in card_cache:
		if skill_card != null and is_instance_valid(skill_card):
			skill_card.queue_free()
	card_cache.clear()
	for raw_skill_resource in skill_resources:
		# 技能资源；空资源不会生成技能卡片，避免无效数组项占用界面空间。
		var skill_resource: Resource = raw_skill_resource as Resource
		if skill_resource == null:
			continue
		# 技能名称；缺失时使用稳定兜底文本，避免卡片第一行为空。
		var skill_name: String = str(skill_resource.get("display_name")).strip_edges()
		# 技能说明；允许为空，卡片会统一显示“暂无技能描述”。
		var skill_description: String = str(skill_resource.get("description")).strip_edges()
		# 基础冷却；主动与派生被动资源都按实际字段读取，完全没有该字段的普通被动按 0 处理并由卡片隐藏徽章。
		var cooldown_seconds: float = maxf(float(skill_resource.get("cooldown_duration")), 0.0) if "cooldown_duration" in skill_resource else 0.0
		# 基础能耗；主动与派生被动资源都按实际字段读取，没有该字段的普通被动按 0 处理并由卡片隐藏徽章。
		var energy_cost: int = maxi(int(skill_resource.get("energy_cost")), 0) if "energy_cost" in skill_resource else 0
		_add_skill_card(container, card_cache, skill_name, skill_description, skill_type, cooldown_seconds, energy_cost)
	if not card_cache.is_empty():
		return
	# 兼容技能名称；旧角色只有文本字段时从第一个中文冒号前提取名称。
	var fallback_skill_name: String = skill_type + "技能"
	# 兼容技能说明；默认保留完整旧文本，解析成功时移除开头名称和冒号。
	var fallback_description: String = fallback_text.strip_edges()
	# 中文冒号位置；取值大于 0 时把冒号前文本作为兼容技能名。
	var separator_index: int = fallback_description.find("：")
	if separator_index > 0:
		fallback_skill_name = fallback_description.left(separator_index).strip_edges()
		fallback_description = fallback_description.substr(separator_index + 1).strip_edges()
	_add_skill_card(container, card_cache, fallback_skill_name, fallback_description, skill_type, 0.0, 0)


func _add_skill_card(container: VBoxContainer, card_cache: Array[Control], skill_name: String, skill_description: String, skill_type: String, cooldown_seconds: float, energy_cost: int) -> void:
	## 创建并配置单个纯展示技能卡片；资源解析留在角色系统，卡片不依赖具体技能数据类型。
	# 技能卡片；使用共享组件确保局外角色系统与战斗内角色展示拥有完全一致的布局和交互。
	var skill_card: CharacterSkillCard = CHARACTER_SKILL_CARD_SCRIPT.new() as CharacterSkillCard
	skill_card.configure(skill_name, skill_description, skill_type, cooldown_seconds, energy_cost)
	container.add_child(skill_card)
	card_cache.append(skill_card)


func _apply_display_mode() -> void:
	## 根据宿主用途切换完整选择或当前角色展示；详情内容始终复用同一滚动面板。
	# 是否仅展示当前角色；true 时禁止通过本界面切换或确认其他角色。
	var current_character_only: bool = display_mode == DISPLAY_MODE_CURRENT_CHARACTER
	_background.color = UI_STYLE_GUIDE.OVERLAY_DIM_COLOR if current_character_only else UI_STYLE_GUIDE.SCREEN_BACKGROUND_COLOR
	_character_list_panel.visible = not current_character_only
	_confirm_button.visible = not current_character_only
	_bottom_actions.alignment = BoxContainer.ALIGNMENT_CENTER if current_character_only else BoxContainer.ALIGNMENT_END
	if current_character_only:
		_main_columns.alignment = BoxContainer.ALIGNMENT_CENTER
		_detail_panel.custom_minimum_size = Vector2(maxf(current_character_panel_width, CURRENT_CHARACTER_PANEL_MINIMUM_WIDTH), 0.0)
		_detail_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		_main_columns.alignment = BoxContainer.ALIGNMENT_BEGIN
		_detail_panel.custom_minimum_size = Vector2.ZERO
		_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _get_session_state() -> Node:
	return get_tree().root.get_node_or_null("SessionState")


func _get_session_selected_character_id() -> String:
	# 会话状态节点；默认由自动加载提供，缺失时使用星作为兜底。
	var session_state: Node = _get_session_state()
	if session_state == null:
		return CHARACTER_STELLE

	if session_state.has_method("get_selected_character_id"):
		return _normalize_character_id(str(session_state.call("get_selected_character_id")))

	return _normalize_character_id(str(session_state.get("selected_character_id")))


func _get_character_profile(character_id: String) -> Dictionary:
	# 会话状态节点；默认由自动加载提供，缺失时使用本地最小兜底档案。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("get_character_profile"):
		# 角色档案；取值为 Dictionary，默认由 SessionState 统一维护，修改会影响详情面板显示。
		var profile: Dictionary = session_state.call("get_character_profile", character_id)
		return profile

	return {
		"id": CHARACTER_STELLE,
		"display_name": "星",
		"role": "标准型开拓者",
		"description": "生命和能量上限都较平衡，适合验证默认战斗流程。",
		"max_health": 100.0,
		"max_energy": 100.0,
		"move_speed": 100.0,
		"attack_power": 100.0,
		"defense_power": 100.0,
		"passive": "被动技能：待配置",
		"active": "主动技能：待配置"
	}


func _set_session_selected_character(character_id: String) -> void:
	# 会话状态节点；默认由自动加载提供，缺失时无法跨场景传递角色选择。
	var session_state: Node = _get_session_state()
	if session_state == null:
		return

	if session_state.has_method("set_selected_character"):
		session_state.call("set_selected_character", character_id)
	elif session_state.has_method("configure"):
		session_state.call("configure", str(session_state.get("game_mode")), character_id)


func _normalize_character_id(character_id: String) -> String:
	# 会话状态；统一使用内容目录校验新角色 ID，避免本界面维护额外白名单。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("normalize_character_id"):
		return str(session_state.call("normalize_character_id", character_id))
	if character_id == CHARACTER_CAEULUS:
		return CHARACTER_CAEULUS
	if character_id == CHARACTER_SILVER_WOLF:
		return CHARACTER_SILVER_WOLF

	return CHARACTER_STELLE


func _build_character_buttons() -> void:
	# 内置按钮；保留场景节点和现有名称，内容资源可统一覆盖按钮显示名称。
	_character_buttons = {
		CHARACTER_STELLE: _stelle_button,
		CHARACTER_CAEULUS: _caelus_button,
		CHARACTER_SILVER_WOLF: _silver_wolf_button,
	}
	# 会话角色列表；内容目录可用时包含全部自动发现角色，否则保留三个内置角色。
	var character_ids: Array[String] = [CHARACTER_STELLE, CHARACTER_CAEULUS, CHARACTER_SILVER_WOLF]
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("get_character_ids"):
		character_ids = session_state.call("get_character_ids") as Array[String]
	for character_id in character_ids:
		# 角色档案；统一读取显示名称，新资源无需修改场景即可获得列表入口。
		var profile: Dictionary = _get_character_profile(character_id)
		var character_button: Button = _character_buttons.get(character_id) as Button
		if character_button == null:
			character_button = Button.new()
			character_button.custom_minimum_size = Vector2(0.0, 58.0)
			character_button.toggle_mode = true
			UI_STYLE_GUIDE.apply_character_selector_button(character_button)
			character_button.pressed.connect(_on_dynamic_character_pressed.bind(character_id))
			_character_button_container.add_child(character_button)
			_character_buttons[character_id] = character_button
		character_button.text = str(profile.get("display_name", character_id))


func _setup_character_button_scroll() -> void:
	_character_list_spacer.visible = false
	# 角色滚动区；占用列表标题与底部弹性空间之间的剩余高度，角色较少时不会出现滚动条。
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_character_list_content.add_child(scroll_container)
	_character_list_content.move_child(scroll_container, _stelle_button.get_index())
	# 按钮容器；横向填满滚动区，按钮按统一 12 像素间距纵向排列。
	_character_button_container = VBoxContainer.new()
	_character_button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_button_container.add_theme_constant_override("separation", 12)
	scroll_container.add_child(_character_button_container)
	# 内置角色按钮；移动节点不会改变缓存、信号或场景所有权，只改变布局承载关系。
	_character_list_content.remove_child(_stelle_button)
	_character_button_container.add_child(_stelle_button)
	_character_list_content.remove_child(_caelus_button)
	_character_button_container.add_child(_caelus_button)
	_character_list_content.remove_child(_silver_wolf_button)
	_character_button_container.add_child(_silver_wolf_button)


func _on_dynamic_character_pressed(character_id: String) -> void:
	_select_character(character_id)


func _on_stelle_button_pressed() -> void:
	_select_character(CHARACTER_STELLE)


func _on_caelus_button_pressed() -> void:
	_select_character(CHARACTER_CAEULUS)


func _on_silver_wolf_button_pressed() -> void:
	_select_character(CHARACTER_SILVER_WOLF)


func _on_confirm_button_pressed() -> void:
	_set_session_selected_character(_selected_character_id)
	_change_scene_with_transition(main_menu_scene_path)


func _on_back_button_pressed() -> void:
	if display_mode == DISPLAY_MODE_CURRENT_CHARACTER:
		close_requested.emit()
		return
	_change_scene_with_transition(main_menu_scene_path)


func _change_scene_with_transition(scene_path: String) -> void:
	# 全局转场服务；默认执行 0.3 秒黑屏过渡，缺失时回退直接切换保证场景可单独测试。
	var scene_transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_to_file"):
		scene_transition.call("change_scene_to_file", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)
