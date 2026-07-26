extends PanelContainer

## 派遣面板只负责展示委托目录、角色选择、进行中派遣与完成报告，不拥有任何委托或货币数据。
## 报酬、大成功率与角色锁定规则全部来自 DispatchService 公开接口，确认后由服务原子校验执行。

signal closed

## 股市同款二次确认弹窗；派遣在展示角色、报酬与时长后统一等待再次确认。
const COMMON_CONFIRMATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/common_confirmation_dialog.gd")
## 全局窗口样式指南；为派遣界面补充统一窗口、按钮与文字主题。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 倒计时轮询间隔；默认 0.25 秒，配合文本变化守卫刷新进行中派遣的剩余时间。
const STATUS_POLL_INTERVAL_SECONDS: float = 0.25

## 面板固定尺寸；默认 1000×620，角色选择行与三张委托卡在该尺寸下保留完整可读空间。
@export var panel_size: Vector2 = Vector2(1000.0, 620.0)

## 派遣服务缓存；默认读取 Autoload，所有委托与角色锁定快照都经由该服务完成。
var _service: Node
## 全局库存服务缓存；只读永久星穹余额，用于状态栏提示。
var _global_inventory: Node
## 会话状态服务缓存；只读角色档案与当前上场角色，用于角色按钮状态。
var _session_state: Node
## 当前选择的派遣角色标识；默认空字符串，重建时自动选中第一个可派遣角色。
var _selected_character_id: String = ""
## 当前等待确认的委托标识；默认空字符串，二次确认后路由到服务签订接口。
var _pending_mission_id: String = ""
## 倒计时轮询累计秒数；默认 0，达到轮询间隔后刷新进行中派遣文字。
var _status_poll_accumulator: float = 0.0
## 上次倒计时文本；默认空字符串，轮询刷新时文本未变化则跳过标签重写。
var _last_countdown_text: String = ""
## 内容重建是否已排队；默认 false，同帧多个服务信号合并为一次延迟重建。
var _content_rebuild_queued: bool = false

## 星穹余额文本；显示当前局外星穹，报酬到账后由库存信号即时刷新。
var _coins_label: Label
## 状态区容器；按派遣状态在进行中卡片与完成报告卡片之间切换重建。
var _status_container: VBoxContainer
## 进行中派遣倒计时标签；页面重建时重新捕获引用。
var _countdown_label: Label
## 角色按钮容器；按已解锁角色横向排列切换按钮。
var _character_row: HBoxContainer
## 委托卡片流式容器；三档委托按定义顺序排列。
var _mission_container: HFlowContainer
## 二次确认弹窗；完整展示角色、委托、报酬与大成功率后才执行真实派遣。
var _confirmation_dialog: CommonConfirmationDialog
## 信息提示弹窗；派遣失败时展示服务返回原因，不修改任何数据。
var _message_dialog: CommonConfirmationDialog


func _ready() -> void:
	custom_minimum_size = panel_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	_service = get_tree().root.get_node_or_null("DispatchService")
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_session_state = get_tree().root.get_node_or_null("SessionState")
	_build_interface()
	_connect_services()
	# UI 风格服务；委托卡片使用手动取色，监听切换信号后立即重建而不等待下次打开。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))
	set_process(false)
	_refresh_all()


func _process(delta: float) -> void:
	# 倒计时轮询；进行中派遣按固定间隔拉取服务快照，文本未变化时不产生任何控件写入。
	_status_poll_accumulator += maxf(delta, 0.0)
	if _status_poll_accumulator >= STATUS_POLL_INTERVAL_SECONDS:
		_status_poll_accumulator = 0.0
		_refresh_countdown()


func refresh() -> void:
	## 主菜单打开面板时调用；重新读取服务快照并恢复倒计时轮询。
	visible = true
	set_process(true)
	_refresh_all()


func _connect_services() -> void:
	if _service != null:
		if _service.has_signal("dispatch_changed"):
			_service.connect("dispatch_changed", Callable(self, "_queue_content_rebuild"))
		if _service.has_signal("dispatch_completed"):
			_service.connect("dispatch_completed", Callable(self, "_on_dispatch_completed"))
	if _global_inventory != null and _global_inventory.has_signal("coins_changed"):
		_global_inventory.connect("coins_changed", Callable(self, "_refresh_coins"))


func _build_interface() -> void:
	# 面板样式；统一取样式指南主窗口样式并自动登记，UI 风格切换时立即刷新背景与描边。
	UI_STYLE_GUIDE.apply_window_panel(self)
	# 外边距；为标题、角色行与委托卡提供统一留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	# 主纵向布局；依次承载状态栏、派遣状态区、角色选择行与委托卡片区。
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	# 顶部状态栏；左侧标题与余额，右侧关闭按钮。
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)
	# 标题与余额区；标题下方显示当前局外星穹。
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	# 面板标题；佣兵派遣是闲置角色创造收益的唯一入口。
	var title_label: Label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	UI_STYLE_GUIDE.apply_title_label(title_label)
	title_label.text = "佣兵派遣"
	title_box.add_child(title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 14)
	UI_STYLE_GUIDE.apply_secondary_label(_coins_label)
	title_box.add_child(_coins_label)
	# 关闭按钮；关闭后 UI 停止轮询，委托倒计时继续由服务后台推进。
	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(90.0, 36.0)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.text = "关闭"
	close_button.pressed.connect(_close_panel)
	header.add_child(close_button)
	# 派遣状态区；进行中卡片或完成报告卡片按需重建。
	_status_container = VBoxContainer.new()
	_status_container.add_theme_constant_override("separation", 8)
	root.add_child(_status_container)
	# 角色选择标题；提示当前上场与派遣中角色的锁定规则。
	var character_title_label: Label = Label.new()
	character_title_label.add_theme_font_size_override("font_size", 15)
	UI_STYLE_GUIDE.apply_muted_accent_label(character_title_label)
	character_title_label.text = "选择派遣角色（当前上场与派遣中的角色不可选）"
	root.add_child(character_title_label)
	# 角色按钮行；按已解锁角色横向排列。
	_character_row = HBoxContainer.new()
	_character_row.add_theme_constant_override("separation", 8)
	root.add_child(_character_row)
	# 委托滚动区；三张委托卡片通过流式容器排列。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_mission_container = HFlowContainer.new()
	_mission_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_container.add_theme_constant_override("h_separation", 12)
	_mission_container.add_theme_constant_override("v_separation", 12)
	_mission_container.alignment = FlowContainer.ALIGNMENT_CENTER
	scroll.add_child(_mission_container)
	# 底部规则说明；固定展示派遣的核心规则摘要。
	var rule_label: Label = Label.new()
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_label.add_theme_font_size_override("font_size", 12)
	UI_STYLE_GUIDE.apply_secondary_label(rule_label)
	rule_label.text = "委托仅消耗在线时间，同一时间一个委托  |  大成功报酬 ×1.5，概率随角色适性属性提高  |  佣兵联络站每级报酬 +4%"
	root.add_child(rule_label)
	# 二次确认弹窗；确认与取消分别路由到派遣执行与挂起清理。
	_confirmation_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_confirmation_dialog.confirmed.connect(_confirm_dispatch)
	_confirmation_dialog.canceled.connect(_clear_pending_dispatch)
	add_child(_confirmation_dialog)
	# 信息提示弹窗；独立实例避免确认回调与提示确认互相覆盖。
	_message_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	add_child(_message_dialog)


func _refresh_all() -> void:
	_refresh_coins()
	_rebuild_status_section()
	_rebuild_character_row()
	_rebuild_mission_cards()


func _refresh_coins(_amount: int = 0) -> void:
	if _coins_label == null:
		return
	# 当前局外星穹；库存服务缺失时显示 0，避免面板因单例缺失报错。
	var coins: int = int(_global_inventory.call("get_coins")) if _global_inventory != null and _global_inventory.has_method("get_coins") else 0
	_coins_label.text = "当前星穹：%d" % coins


func _rebuild_status_section() -> void:
	if _status_container == null or _service == null:
		return
	# 倒计时引用清理；旧标签随子节点释放，避免轮询刷新访问已销毁控件。
	_countdown_label = null
	_last_countdown_text = ""
	for child in _status_container.get_children():
		child.queue_free()
	# 进行中派遣快照；非空时展示进行中卡片并隐藏完成报告。
	var snapshot: Dictionary = _service.call("get_active_dispatch_snapshot") as Dictionary if _service.has_method("get_active_dispatch_snapshot") else {}
	if not snapshot.is_empty():
		_status_container.add_child(_create_active_dispatch_card(snapshot))
		return
	# 最近完成报告；非空时展示报告卡片，签订新委托后由服务清空。
	var report: Dictionary = _service.call("get_last_report") as Dictionary if _service.has_method("get_last_report") else {}
	if not report.is_empty():
		_status_container.add_child(_create_report_card(report))


func _create_active_dispatch_card(snapshot: Dictionary) -> Control:
	# 进行中派遣卡片；使用亮色语义突出委托进行中。
	var card: PanelContainer = _create_card_base(true, Vector2(0.0, 0.0))
	var content: VBoxContainer = _get_card_content(card)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color())
	name_label.text = "派遣中：%s 执行「%s」" % [str(snapshot.get("character_name", "角色")), str(snapshot.get("mission_name", "派遣委托"))]
	content.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	detail_label.text = "预期报酬：%d 星穹  |  大成功率：%d%%（大成功 ×1.5）" % [int(snapshot.get("reward_amount", 0)), int(round(float(snapshot.get("crit_chance", 0.0)) * 100.0))]
	content.add_child(detail_label)
	# 倒计时标签；文本由轮询按剩余整数秒刷新。
	_countdown_label = Label.new()
	_countdown_label.add_theme_font_size_override("font_size", 14)
	_countdown_label.add_theme_color_override("font_color", Color(0.46, 0.92, 0.72, 1.0))
	content.add_child(_countdown_label)
	_refresh_countdown()
	var note_label: Label = Label.new()
	note_label.add_theme_font_size_override("font_size", 11)
	note_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	note_label.text = "委托仅消耗在线时间，中途不可召回；到期自动交付并解除角色锁定"
	content.add_child(note_label)
	return card


func _create_report_card(report: Dictionary) -> Control:
	# 完成报告卡片；大成功使用金色语义，普通完成使用收益绿色语义。
	var card: PanelContainer = _create_card_base(true, Vector2(0.0, 0.0))
	var content: VBoxContainer = _get_card_content(card)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30, 1.0) if bool(report.get("critical", false)) else Color(0.46, 0.92, 0.72, 1.0))
	name_label.text = "上次委托报告"
	content.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_secondary_text_color())
	detail_label.text = str(report.get("message", ""))
	content.add_child(detail_label)
	return card


func _rebuild_character_row() -> void:
	if _character_row == null or _service == null:
		return
	for child in _character_row.get_children():
		child.queue_free()
	# 可展示角色列表；包含全部已解锁角色，锁定状态在按钮上标注。
	var character_ids: Array = _service.call("get_dispatchable_character_ids") as Array if _service.has_method("get_dispatchable_character_ids") else []
	# 当前上场角色；派遣中与上场角色都不可被选择。
	var selected_in_battle: String = str(_session_state.call("get_selected_character_id")) if _session_state != null and _session_state.has_method("get_selected_character_id") else ""
	# 默认选择修正；当前选择无效或不可用时回退到第一个可派遣角色。
	var first_selectable_id: String = ""
	for raw_character_id in character_ids:
		# 角色标识与状态；上场与派遣中的角色禁用按钮。
		var character_id: String = str(raw_character_id)
		var dispatched: bool = bool(_service.call("is_character_dispatched", character_id))
		var in_battle: bool = character_id == selected_in_battle
		var selectable: bool = not dispatched and not in_battle
		if selectable and first_selectable_id.is_empty():
			first_selectable_id = character_id
		# 角色显示名；从会话档案读取，保证与角色系统一致。
		var display_name: String = str(_session_state.call("get_character_display_name", character_id)) if _session_state != null and _session_state.has_method("get_character_display_name") else character_id
		# 角色按钮；使用切换模式表达当前选择，锁定角色附带状态后缀。
		var character_button: Button = Button.new()
		character_button.custom_minimum_size = Vector2(0.0, 44.0)
		character_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		character_button.toggle_mode = true
		if in_battle:
			character_button.text = "%s（上场中）" % display_name
			character_button.disabled = true
		elif dispatched:
			character_button.text = "%s（派遣中）" % display_name
			character_button.disabled = true
		else:
			character_button.text = display_name
			character_button.pressed.connect(Callable(self, "_on_character_selected").bind(character_id))
		_character_row.add_child(character_button)
	if _selected_character_id.is_empty() or not _is_character_selectable(_selected_character_id):
		_selected_character_id = first_selectable_id
	_sync_character_button_states()


func _is_character_selectable(character_id: String) -> bool:
	## 判断角色当前是否可被派遣选择；上场中与派遣中的角色都不可选。
	if _service == null or character_id.is_empty():
		return false
	# 当前上场角色；与派遣锁定共同构成不可选条件。
	var selected_in_battle: String = str(_session_state.call("get_selected_character_id")) if _session_state != null and _session_state.has_method("get_selected_character_id") else ""
	return character_id != selected_in_battle and not bool(_service.call("is_character_dispatched", character_id))


func _on_character_selected(character_id: String) -> void:
	_selected_character_id = character_id
	_sync_character_button_states()
	_rebuild_mission_cards()


func _sync_character_button_states() -> void:
	## 同步角色按钮按下状态；按钮文本以显示名开头，通过绑定回调的顺序保持与列表一致。
	if _character_row == null:
		return
	# 可展示角色列表；与重建时相同顺序，逐个按钮比对选择状态。
	var character_ids: Array = _service.call("get_dispatchable_character_ids") as Array if _service != null and _service.has_method("get_dispatchable_character_ids") else []
	for button_index in range(mini(_character_row.get_child_count(), character_ids.size())):
		# 角色按钮；按下状态只表达当前选择，不触发信号。
		var character_button: Button = _character_row.get_child(button_index) as Button
		if character_button != null:
			character_button.set_pressed_no_signal(str(character_ids[button_index]) == _selected_character_id)


func _rebuild_mission_cards() -> void:
	# 任何直接重建都消化当前挂起的合并刷新；同帧稍后的延迟回调据此跳过重复重建。
	_content_rebuild_queued = false
	if _mission_container == null or _service == null:
		return
	for child in _mission_container.get_children():
		child.queue_free()
	# 是否存在进行中派遣；占用期间全部委托的签订按钮统一禁用。
	var dispatch_occupied: bool = _service.has_method("has_active_dispatch") and bool(_service.call("has_active_dispatch"))
	# 委托定义副本；卡片只读取快照，签订时服务仍会再次校验角色与占用。
	var definitions: Array = _service.call("get_mission_definitions") as Array if _service.has_method("get_mission_definitions") else []
	for raw_definition in definitions:
		# 单档委托定义；包含稳定标识、名称、时长、基础报酬与适性属性。
		var definition: Dictionary = raw_definition as Dictionary
		_mission_container.add_child(_create_mission_card(definition, dispatch_occupied))


func _create_mission_card(definition: Dictionary, dispatch_occupied: bool) -> Control:
	# 委托卡片；固定 302×190 并以独立 PanelContainer 承载，三张卡片单行排列。
	var mission_id: String = str(definition.get("id", ""))
	# 卡片可用状态；被占用或没有可派遣角色时使用暗色语义。
	var card_active: bool = not dispatch_occupied and not _selected_character_id.is_empty()
	var card: PanelContainer = _create_card_base(card_active, Vector2(302.0, 190.0))
	card.name = mission_id
	var content: VBoxContainer = _get_card_content(card)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color() if card_active else UI_STYLE_GUIDE.get_disabled_text_color())
	name_label.text = str(definition.get("name", "派遣委托"))
	content.add_child(name_label)
	# 卡片说明文字色；占用时降低透明度弱化不可操作内容。
	var card_detail_color: Color = UI_STYLE_GUIDE.get_secondary_text_color() if card_active else Color(UI_STYLE_GUIDE.get_secondary_text_color(), 0.72)
	var detail_label: Label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", card_detail_color)
	# 当前报酬报价与大成功率；随所选角色与联络站等级实时变化。
	detail_label.text = "在线 %s  |  报酬 %d 星穹\n适性：%s  |  大成功率 %d%%" % [_format_hour_minute_duration(int(definition.get("duration_seconds", 0))), int(_service.call("get_quoted_reward", mission_id)), str(definition.get("affinity_name", "属性")), int(round(float(_service.call("get_crit_chance_for_character", mission_id, _selected_character_id)) * 100.0)) if not _selected_character_id.is_empty() else 0]
	content.add_child(detail_label)
	var description_label: Label = Label.new()
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", card_detail_color)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text = str(definition.get("description", ""))
	content.add_child(description_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(0.0, 32.0)
	if dispatch_occupied:
		action_button.text = "已有进行中委托"
		action_button.disabled = true
	elif _selected_character_id.is_empty():
		action_button.text = "没有可派遣的角色"
		action_button.disabled = true
	else:
		action_button.text = "派遣出发"
		UI_STYLE_GUIDE.apply_primary_button(action_button)
		action_button.pressed.connect(Callable(self, "_open_dispatch_confirmation").bind(mission_id))
	content.add_child(action_button)
	return card


func _create_card_base(active: bool, minimum_size: Vector2) -> PanelContainer:
	## 创建派遣通用卡片外框；亮暗语义与矿场、据点卡片保持一致。
	var card: PanelContainer = PanelContainer.new()
	if minimum_size != Vector2.ZERO:
		card.custom_minimum_size = minimum_size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	# 卡片背景与边框；激活时取当前风格子分区色与弱强调描边，禁用时降低透明度。
	style.bg_color = UI_STYLE_GUIDE.get_section_background_color() if active else Color(UI_STYLE_GUIDE.get_item_card_background_color(), 0.62)
	style.border_color = UI_STYLE_GUIDE.get_accent_muted_color() if active else Color(UI_STYLE_GUIDE.get_section_border_color(), 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "CardContent"
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	return card


func _get_card_content(card: PanelContainer) -> VBoxContainer:
	## 读取通用卡片外框的内容容器；与 _create_card_base 配套使用。
	return card.get_node("CardMargin/CardContent") as VBoxContainer


func _refresh_countdown() -> void:
	## 按进行中派遣快照刷新倒计时标签；标签只在派遣进行中卡片存在时有效。
	if _countdown_label == null or not is_instance_valid(_countdown_label) or _service == null:
		return
	# 进行中派遣快照；为空表示委托刚完成，页面重建由派遣状态信号负责。
	var snapshot: Dictionary = _service.call("get_active_dispatch_snapshot") as Dictionary
	if snapshot.is_empty():
		return
	# 目标倒计时文本；按剩余整数秒生成，未变化时跳过标签重写。
	var countdown_text: String = "剩余在线 %s" % _format_duration(float(snapshot.get("remaining_seconds", 0.0)))
	if countdown_text == _last_countdown_text:
		return
	_last_countdown_text = countdown_text
	_countdown_label.text = countdown_text


func _open_dispatch_confirmation(mission_id: String) -> void:
	if _service == null or _selected_character_id.is_empty():
		return
	_pending_mission_id = mission_id
	# 委托定义与实时报价；确认正文展示角色、时长、报酬与大成功率。
	var definition: Dictionary = _get_mission_definition(mission_id)
	# 角色显示名；从会话档案读取，保证与角色系统一致。
	var character_name: String = str(_session_state.call("get_character_display_name", _selected_character_id)) if _session_state != null and _session_state.has_method("get_character_display_name") else _selected_character_id
	var message: String = "派遣 %s 执行「%s」\n在线时长：%s（中途不可召回）\n预期报酬：%d 星穹\n大成功率：%d%%（大成功报酬 ×1.5）\n派遣期间该角色无法上场" % [character_name, str(definition.get("name", "派遣委托")), _format_hour_minute_duration(int(definition.get("duration_seconds", 0))), int(_service.call("get_quoted_reward", mission_id)), int(round(float(_service.call("get_crit_chance_for_character", mission_id, _selected_character_id)) * 100.0))]
	_confirmation_dialog.present_adaptive("确认派遣", message, "确认派遣", "取消", true)


func _confirm_dispatch() -> void:
	if _service == null or _pending_mission_id.is_empty():
		return
	# 派遣执行结果；服务在确认瞬间重新校验角色解锁、上场与占用状态。
	var result: Dictionary = _service.call("start_dispatch", _pending_mission_id, _selected_character_id) as Dictionary
	if not bool(result.get("success", false)):
		_message_dialog.present_information("派遣提示", str(result.get("message", "派遣失败")))
	_clear_pending_dispatch()
	_refresh_all()


func _clear_pending_dispatch() -> void:
	_pending_mission_id = ""


func _on_dispatch_completed(_gold_amount: int, _message: String) -> void:
	_queue_content_rebuild()


func _queue_content_rebuild() -> void:
	## 合并内容重建；同帧内派遣信号多次触发只执行一次重建。
	if _content_rebuild_queued:
		return
	_content_rebuild_queued = true
	call_deferred("_flush_queued_content_rebuild")


func _flush_queued_content_rebuild() -> void:
	## 执行单次内容重建；期间若已发生直接重建，标志会被消化并跳过重复工作。
	if not _content_rebuild_queued:
		return
	_refresh_all()


func _on_ui_style_changed(_style_id: String) -> void:
	## UI 风格切换后立即重建状态区与委托卡片，刷新其中手动取色的背景、边框与文字。
	_rebuild_status_section()
	_rebuild_mission_cards()


func _close_panel() -> void:
	visible = false
	set_process(false)
	_clear_pending_dispatch()
	closed.emit()


func _get_mission_definition(mission_id: String) -> Dictionary:
	## 从服务公开定义中查找指定委托类型；返回副本，UI 不修改静态配置。
	var definitions: Array = _service.call("get_mission_definitions") as Array if _service != null and _service.has_method("get_mission_definitions") else []
	for raw_definition in definitions:
		var definition: Dictionary = raw_definition as Dictionary
		if str(definition.get("id", "")) == mission_id:
			return definition
	return {}


func _format_duration(seconds: float) -> String:
	# 完整剩余秒数；向上取整避免 0.1 秒时提前显示 00:00。
	var total_seconds: int = maxi(int(ceil(seconds)), 0)
	# 分钟部分；委托最长 6 小时，因此不对分钟取模。
	var minutes: int = total_seconds / 60
	# 秒部分；固定显示两位，形成稳定倒计时宽度。
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]


func _format_hour_minute_duration(total_seconds: int) -> String:
	## 把秒数格式化为“X小时X分”样式的中文时长；用于委托时长展示，不用于逐秒倒计时。
	if total_seconds < 60:
		return "%d秒" % maxi(total_seconds, 0)
	# 完整小时数；委托时长最长 6 小时，不换算为天。
	var hours: int = total_seconds / 3600
	# 剩余分钟数；不足 1 分钟的秒数直接舍去，保持文本简洁。
	var minutes: int = (total_seconds % 3600) / 60
	if hours <= 0:
		return "%d分钟" % minutes
	if minutes <= 0:
		return "%d小时" % hours
	return "%d小时%d分" % [hours, minutes]
