extends PanelContainer
class_name HackProtocolViewPanel

## 骇入协议查看面板只读展示本机本局已经获得的协议。
## 重复协议聚合为层数，名称和数值说明统一读取 HackProtocolRules，不参与任何效果结算。

signal closed

## 全局窗口样式指南；查看面板与协议卡片跟随当前 UI 风格。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 内容水平内边距；默认 16 像素，与风险合约查看面板保持同一左栏密度。
const CONTENT_HORIZONTAL_MARGIN: int = 16
## 内容垂直内边距；默认 14 像素，为 420×420 左栏保留足够列表空间。
const CONTENT_VERTICAL_MARGIN: int = 14

## 当前规范化协议 ID；保留重复项和获得顺序，卡片刷新时再聚合显示层数。
var _protocol_ids: Array[String] = []
## 当前模式扩展是否启用；用于区分“未开启扩展”和“已开启但尚未获得协议”。
var _extension_enabled: bool = false
## 协议卡片列表容器；每次打开按首次获得顺序重建聚合卡片。
var _protocol_list: VBoxContainer = null
## 空状态说明；根据扩展开关显示不同提示。
var _empty_state_label: Label = null
## 协议总层数标签；显示本机独立层数，不展示也不泄露队友候选或碎片。
var _total_count_label: Label = null


func _ready() -> void:
	## 构建一次只读窗口结构；present() 只更新快照和卡片。
	UI_STYLE_GUIDE.apply_window_panel(self)
	_build_content()
	_refresh_content()


func present(protocol_ids: Array, extension_enabled: bool) -> void:
	## 展示本机协议快照；未知 ID 被过滤，合法重复项作为叠加层数保留。
	_protocol_ids = HackProtocolRules.normalize_protocol_ids(protocol_ids)
	_extension_enabled = extension_enabled
	if is_node_ready():
		_refresh_content()
	visible = true


func dismiss() -> void:
	## 关闭只读面板；不改变协议、碎片、候选或团队动态代价。
	visible = false


func _build_content() -> void:
	## 构建标题、说明、滚动列表、总层数与关闭按钮。
	# 外层内容边距；与风险合约查看面板保持相同边距体系。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_top", CONTENT_VERTICAL_MARGIN)
	content_margin.add_theme_constant_override("margin_right", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", CONTENT_VERTICAL_MARGIN)
	add_child(content_margin)
	# 根纵向布局；滚动列表占用剩余高度。
	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 9)
	content_margin.add_child(root_layout)
	# 查看标题；强调列表只属于本机玩家与当前战局。
	var title_label: Label = Label.new()
	title_label.text = "本局骇入协议"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_title_label(title_label, 22)
	root_layout.add_child(title_label)
	# 列表说明；多人不会展示或混合其他成员的协议。
	var description_label: Label = Label.new()
	description_label.text = "查看你在本局获得的独立协议；重复协议会叠加层数。"
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(description_label)
	root_layout.add_child(description_label)
	# 协议滚动区；长局协议较多时仍能完整查看。
	var protocol_scroll: ScrollContainer = ScrollContainer.new()
	protocol_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	protocol_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_layout.add_child(protocol_scroll)
	_protocol_list = VBoxContainer.new()
	_protocol_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_protocol_list.add_theme_constant_override("separation", 7)
	protocol_scroll.add_child(_protocol_list)
	_empty_state_label = Label.new()
	_empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_state_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_secondary_label(_empty_state_label)
	_protocol_list.add_child(_empty_state_label)
	_total_count_label = Label.new()
	_total_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_layout.add_child(_total_count_label)
	# 关闭按钮；只返回暂停左栏入口，不关闭暂停菜单。
	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.pressed.connect(_on_close_button_pressed)
	root_layout.add_child(close_button)


func _refresh_content() -> void:
	## 按首次获得顺序聚合协议层数并重建只读卡片。
	if _protocol_list == null or _empty_state_label == null or _total_count_label == null:
		return
	for list_child in _protocol_list.get_children():
		if list_child != _empty_state_label:
			_protocol_list.remove_child(list_child)
			list_child.queue_free()
	# 协议层数表；键为协议 ID，值为本局重复获得次数。
	var stack_counts: Dictionary = {}
	# 首次获得顺序；聚合后仍按玩家第一次取得协议的顺序展示。
	var ordered_unique_ids: Array[String] = []
	for protocol_id in _protocol_ids:
		if not stack_counts.has(protocol_id):
			stack_counts[protocol_id] = 0
			ordered_unique_ids.append(protocol_id)
		stack_counts[protocol_id] = int(stack_counts[protocol_id]) + 1
	_empty_state_label.visible = _protocol_ids.is_empty()
	if not _extension_enabled:
		_empty_state_label.text = "本局未启用骇入协议。"
	elif _protocol_ids.is_empty():
		_empty_state_label.text = "尚未获得协议；积满数据碎片后长按绑定键进行选择。"
	for protocol_id in ordered_unique_ids:
		# 协议定义；规范化后通常存在，空定义作为热更新安全保护跳过。
		var protocol_definition: Dictionary = HackProtocolRules.get_protocol_definition(protocol_id)
		if not protocol_definition.is_empty():
			_protocol_list.add_child(_build_protocol_card(protocol_definition, int(stack_counts.get(protocol_id, 1))))
	_total_count_label.text = "本机协议总层数：%d" % _protocol_ids.size() if _extension_enabled else "骇入协议扩展未开启"


func _build_protocol_card(protocol_definition: Dictionary, stack_count: int) -> PanelContainer:
	## 构建聚合协议卡；名称附带层数，说明始终展示规则表的单层基础数值。
	# 协议卡外框；复用全局分区样式。
	var card_panel: PanelContainer = PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_section_panel(card_panel)
	# 卡片内边距；保持紧凑但确保多行说明易读。
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 10)
	card_margin.add_theme_constant_override("margin_top", 8)
	card_margin.add_theme_constant_override("margin_right", 10)
	card_margin.add_theme_constant_override("margin_bottom", 8)
	card_panel.add_child(card_margin)
	# 卡片纵向布局；名称与效果说明分行。
	var card_layout: VBoxContainer = VBoxContainer.new()
	card_layout.add_theme_constant_override("separation", 3)
	card_margin.add_child(card_layout)
	# 聚合名称；仅多层时追加“×N”，避免单层产生冗余信息。
	var name_label: Label = Label.new()
	name_label.text = "%s ×%d" % [str(protocol_definition.get("display_name", "未知协议")), stack_count] if stack_count > 1 else str(protocol_definition.get("display_name", "未知协议"))
	card_layout.add_child(name_label)
	# 单层效果说明；叠加规则由总层数表达，避免 UI 推导有上限或阈值的最终值造成歧义。
	var effect_label: Label = Label.new()
	effect_label.text = str(protocol_definition.get("description", "暂无效果说明。"))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(effect_label)
	card_layout.add_child(effect_label)
	return card_panel


func _on_close_button_pressed() -> void:
	## 隐藏面板并通知 HUD 恢复骇入协议查看入口。
	dismiss()
	closed.emit()
