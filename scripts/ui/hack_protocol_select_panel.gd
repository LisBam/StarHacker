extends PanelContainer
class_name HackProtocolSelectPanel

## 骇入协议选择面板只呈现玩家组件已经固定的三个候选，并把点击选择交回组件验证。
## 面板不会暂停场景树、不会自行刷新候选，也不持有碎片；关闭后再次长按会展示同一批候选。

signal protocol_selected(protocol_id: String)
signal closed

## 全局窗口样式指南；面板和候选卡片随玩家选择的 UI 风格统一刷新。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 内容水平内边距；默认 20 像素，为三列协议卡片保留清晰边界。
const CONTENT_HORIZONTAL_MARGIN: int = 20
## 内容垂直内边距；默认 18 像素，让标题、说明、候选与关闭按钮保持稳定间距。
const CONTENT_VERTICAL_MARGIN: int = 18

## 当前玩家骇入协议组件；只通过候选快照与选择接口交互，允许为空并显示无候选状态。
var _protocol_component: Node = null
## 三张候选卡片的横向容器；每次打开前清空并按组件固定候选重建。
var _offer_row: HBoxContainer = null
## 无候选说明标签；碎片不足或组件缺失时显示，合法三选一存在时隐藏。
var _empty_state_label: Label = null


func _ready() -> void:
	## 构建一次固定窗口结构；运行期间只重建三个候选卡片。
	UI_STYLE_GUIDE.apply_window_panel(self)
	_build_content()
	_refresh_offers()


func present(protocol_component: Node) -> void:
	## 打开当前玩家的固定候选；调用不改变候选随机结果，也不修改场景树暂停状态。
	_protocol_component = protocol_component
	if is_node_ready():
		_refresh_offers()
	visible = true


func dismiss() -> void:
	## 隐藏选择窗口；未选择协议时组件保留候选与全部溢出碎片。
	visible = false


func _build_content() -> void:
	## 构建标题、规则说明、三列候选和“稍后选择”按钮。
	# 外层内容边距；隔离窗口边框与内部交互控件。
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_top", CONTENT_VERTICAL_MARGIN)
	content_margin.add_theme_constant_override("margin_right", CONTENT_HORIZONTAL_MARGIN)
	content_margin.add_theme_constant_override("margin_bottom", CONTENT_VERTICAL_MARGIN)
	add_child(content_margin)
	# 根纵向布局；候选行占用主要空间，底部按钮保持固定高度。
	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 12)
	content_margin.add_child(root_layout)
	# 窗口标题；明确本次操作是从三项中获得一项本局协议。
	var title_label: Label = Label.new()
	title_label.text = "选择骇入协议"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_STYLE_GUIDE.apply_title_label(title_label, 24)
	root_layout.add_child(title_label)
	# 操作说明；告知关闭不会丢失候选且游戏仍在运行。
	var description_label: Label = Label.new()
	description_label.text = "选择 1 项仅本局生效的协议。战斗不会暂停，关闭后候选与溢出碎片都会保留。"
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(description_label)
	root_layout.add_child(description_label)
	_offer_row = HBoxContainer.new()
	_offer_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offer_row.add_theme_constant_override("separation", 12)
	root_layout.add_child(_offer_row)
	_empty_state_label = Label.new()
	_empty_state_label.text = "当前没有可选择的骇入协议。"
	_empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_state_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_secondary_label(_empty_state_label)
	_offer_row.add_child(_empty_state_label)
	# 稍后选择按钮；只关闭窗口，不扣除碎片、不重掷候选。
	var close_button: Button = Button.new()
	close_button.text = "稍后选择"
	close_button.custom_minimum_size = Vector2(0.0, 44.0)
	close_button.pressed.connect(_on_close_button_pressed)
	root_layout.add_child(close_button)


func _refresh_offers() -> void:
	## 从组件读取候选并重建卡片；候选不足时不伪造协议，保持安全空状态。
	if _offer_row == null or _empty_state_label == null:
		return
	for offer_child in _offer_row.get_children():
		if offer_child != _empty_state_label:
			_offer_row.remove_child(offer_child)
			offer_child.queue_free()
	# 候选协议 ID；组件已经保证内部无重复，面板仍通过规则表过滤未知定义。
	var offer_ids: Array[String] = []
	if _protocol_component != null and _protocol_component.has_method("get_offer_ids"):
		offer_ids = HackProtocolRules.normalize_protocol_ids(_protocol_component.call("get_offer_ids") as Array)
	_empty_state_label.visible = offer_ids.is_empty()
	for protocol_id in offer_ids:
		# 协议定义；名称、描述与数值统一从规则表读取，不在 UI 复制策划参数。
		var protocol_definition: Dictionary = HackProtocolRules.get_protocol_definition(protocol_id)
		if protocol_definition.is_empty():
			continue
		_offer_row.add_child(_build_offer_card(protocol_id, protocol_definition))


func _build_offer_card(protocol_id: String, protocol_definition: Dictionary) -> PanelContainer:
	## 构建一张等宽候选卡；按钮绑定稳定 ID，点击时仍由玩家组件验证候选与碎片状态。
	# 候选卡片；三张卡使用横向扩展标记平分可用宽度。
	var card_panel: PanelContainer = PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.custom_minimum_size = Vector2(220.0, 0.0)
	UI_STYLE_GUIDE.apply_section_panel(card_panel)
	# 卡片边距；为名称、说明和选择按钮提供统一留白。
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 14)
	card_margin.add_theme_constant_override("margin_top", 14)
	card_margin.add_theme_constant_override("margin_right", 14)
	card_margin.add_theme_constant_override("margin_bottom", 14)
	card_panel.add_child(card_margin)
	# 卡片纵向布局；说明文本伸展填充，让三列按钮底边对齐。
	var card_layout: VBoxContainer = VBoxContainer.new()
	card_layout.add_theme_constant_override("separation", 10)
	card_margin.add_child(card_layout)
	# 协议名称；直接读取规则表的人类可读名称。
	var name_label: Label = Label.new()
	name_label.text = str(protocol_definition.get("display_name", "未知协议"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_title_label(name_label, 18)
	card_layout.add_child(name_label)
	# 协议完整效果说明；包含所有平衡数值与触发条件。
	var effect_label: Label = Label.new()
	effect_label.text = str(protocol_definition.get("description", "暂无效果说明。"))
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_secondary_label(effect_label)
	card_layout.add_child(effect_label)
	# 选择按钮；传入稳定 ID，成功后由宿主关闭窗口并刷新 HUD。
	var select_button: Button = Button.new()
	select_button.text = "获得协议"
	select_button.custom_minimum_size = Vector2(0.0, 44.0)
	UI_STYLE_GUIDE.apply_primary_button(select_button)
	select_button.pressed.connect(_on_protocol_button_pressed.bind(protocol_id))
	card_layout.add_child(select_button)
	return card_panel


func _on_protocol_button_pressed(protocol_id: String) -> void:
	## 尝试获得协议；组件拒绝过期或伪造 ID 时保持窗口打开，避免 UI 与真实状态分叉。
	if _protocol_component == null or not _protocol_component.has_method("select_protocol"):
		return
	if not bool(_protocol_component.call("select_protocol", protocol_id)):
		_refresh_offers()
		return
	dismiss()
	protocol_selected.emit(protocol_id)


func _on_close_button_pressed() -> void:
	## 关闭本次查看但保留原候选，玩家可重新长按绑定键继续选择。
	dismiss()
	closed.emit()
