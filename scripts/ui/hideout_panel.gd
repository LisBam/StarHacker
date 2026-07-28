extends PanelContainer

## 据点面板只负责展示设施等级、建造队列与升级入口，不拥有任何等级或货币数据。
## 升级费用与建造时长全部来自 HideoutService 公开接口，确认后由服务原子校验并扣款。

signal closed

## 股市同款二次确认弹窗；设施升级在展示费用与建造时长后统一等待再次确认。
const COMMON_CONFIRMATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/common_confirmation_dialog.gd")
## 全局窗口样式指南；为据点界面补充统一窗口、按钮与文字主题。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 建造倒计时轮询间隔；默认 0.25 秒，配合文本变化守卫以低成本刷新倒计时文字。
const STATUS_POLL_INTERVAL_SECONDS: float = 0.25

## 面板固定尺寸；默认 1080×640，与矿场面板一致，适配 1280×720 主菜单并保留四周遮罩空间。
@export var panel_size: Vector2 = Vector2(1080.0, 640.0)

## 据点服务缓存；默认读取 Autoload，所有升级与倒计时快照都经由该服务完成。
var _service: Node
## 全局库存服务缓存；只读永久星穹余额，用于状态栏提示与升级前的余额预检。
var _global_inventory: Node
## 当前等待确认的设施标识；默认空字符串，二次确认后路由到服务升级接口。
var _pending_facility_id: String = ""
## 倒计时轮询累计秒数；默认 0，达到轮询间隔后刷新建造状态文字。
var _status_poll_accumulator: float = 0.0
## 上次建造状态文本；默认空字符串，轮询刷新时文本未变化则跳过标签重写。
var _last_construction_text: String = ""
## 设施卡片重建是否已排队；默认 false，同帧多个服务信号合并为一次延迟重建。
var _cards_rebuild_queued: bool = false

## 星穹余额文本；显示当前局外星穹，升级扣款后由库存信号即时刷新。
var _coins_label: Label
## 建造状态文本；显示进行中建造的设施与剩余在线时间，无建造时显示提示文案。
var _construction_label: Label
## 设施卡片流式容器；六座设施按定义顺序排列并自动换行。
## 现行设施数量补充：容器按 HideoutService 定义表动态渲染七座设施，战术仓储舱与其他设施共用同一张卡片协议。
var _facility_container: HFlowContainer
## 二次确认弹窗；完整展示升级费用、建造时长与效果说明后才执行真实升级。
var _confirmation_dialog: CommonConfirmationDialog
## 信息提示弹窗；升级失败时展示服务返回原因，不修改任何数据。
var _message_dialog: CommonConfirmationDialog


func _ready() -> void:
	custom_minimum_size = panel_size
	UI_STYLE_GUIDE.apply_screen_theme(self)
	_service = get_tree().root.get_node_or_null("HideoutService")
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_build_interface()
	_connect_services()
	# UI 风格服务；设施卡片使用手动取色，监听切换信号后立即重建而不等待下次打开。
	var ui_style_settings: Node = get_tree().root.get_node_or_null("UiStyleSettings")
	if ui_style_settings != null and ui_style_settings.has_signal("ui_style_changed") and not ui_style_settings.is_connected("ui_style_changed", Callable(self, "_on_ui_style_changed")):
		ui_style_settings.connect("ui_style_changed", Callable(self, "_on_ui_style_changed"))
	set_process(false)
	_refresh_all()


func _process(delta: float) -> void:
	# 倒计时轮询；建造状态按固定间隔拉取服务快照，文本未变化时不产生任何控件写入。
	_status_poll_accumulator += maxf(delta, 0.0)
	if _status_poll_accumulator >= STATUS_POLL_INTERVAL_SECONDS:
		_status_poll_accumulator = 0.0
		_refresh_construction_status()


func refresh() -> void:
	## 主菜单打开面板时调用；重新读取服务快照并恢复倒计时轮询。
	visible = true
	set_process(true)
	_refresh_all()


func _connect_services() -> void:
	if _service != null:
		if _service.has_signal("facility_levels_changed"):
			_service.connect("facility_levels_changed", Callable(self, "_queue_cards_rebuild"))
		if _service.has_signal("construction_changed"):
			_service.connect("construction_changed", Callable(self, "_on_construction_changed"))
	if _global_inventory != null and _global_inventory.has_signal("coins_changed"):
		_global_inventory.connect("coins_changed", Callable(self, "_refresh_coins"))


func _build_interface() -> void:
	# 面板样式；统一取样式指南主窗口样式并自动登记，UI 风格切换时立即刷新背景与描边。
	UI_STYLE_GUIDE.apply_window_panel(self)
	# 外边距；为标题、卡片和底部说明提供统一留白。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	# 主纵向布局；依次承载状态栏、设施卡片区与底部规则说明。
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	# 顶部状态栏；左侧标题与余额，右侧建造状态与关闭按钮。
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)
	# 标题与余额区；标题下方显示当前局外星穹。
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	# 面板标题；据点建设是设施升级的唯一入口。
	var title_label: Label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	UI_STYLE_GUIDE.apply_title_label(title_label)
	title_label.text = "据点建设"
	title_box.add_child(title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 14)
	UI_STYLE_GUIDE.apply_secondary_label(_coins_label)
	title_box.add_child(_coins_label)
	# 建造状态区；右对齐显示进行中建造的设施与剩余在线时间。
	var status_box: VBoxContainer = VBoxContainer.new()
	status_box.custom_minimum_size = Vector2(360.0, 0.0)
	header.add_child(status_box)
	_construction_label = Label.new()
	_construction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_construction_label.add_theme_font_size_override("font_size", 15)
	_construction_label.add_theme_color_override("font_color", Color(0.46, 0.92, 0.72, 1.0))
	status_box.add_child(_construction_label)
	# 建造规则说明；提示同一时间只有一个建造队列且只消耗在线时间。
	var status_note_label: Label = Label.new()
	status_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_note_label.add_theme_font_size_override("font_size", 11)
	UI_STYLE_GUIDE.apply_secondary_label(status_note_label)
	status_note_label.text = "同一时间仅一个建造队列，建造只消耗在线时间"
	status_box.add_child(status_note_label)
	# 关闭按钮；关闭后 UI 停止轮询，建造倒计时继续由服务后台推进。
	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(90.0, 36.0)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.text = "关闭"
	close_button.pressed.connect(_close_panel)
	header.add_child(close_button)
	# 设施滚动区；卡片固定宽度并通过流式容器自动换行。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_facility_container = HFlowContainer.new()
	_facility_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facility_container.add_theme_constant_override("h_separation", 12)
	_facility_container.add_theme_constant_override("v_separation", 12)
	_facility_container.alignment = FlowContainer.ALIGNMENT_CENTER
	scroll.add_child(_facility_container)
	# 底部规则说明；固定展示升级费用与建造时长的成长规则。
	var rule_label: Label = Label.new()
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_label.add_theme_font_size_override("font_size", 13)
	UI_STYLE_GUIDE.apply_secondary_label(rule_label)
	rule_label.text = "设施 0-5 级  |  升级费用 200×[1/3/9/27/81] 星穹  |  建造 5分钟-2小时  |  建成后效果立即生效"
	root.add_child(rule_label)
	# 二次确认弹窗；确认与取消分别路由到升级执行与挂起清理。
	_confirmation_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_confirmation_dialog.confirmed.connect(_confirm_upgrade)
	_confirmation_dialog.canceled.connect(_clear_pending_upgrade)
	add_child(_confirmation_dialog)
	# 信息提示弹窗；独立实例避免确认回调与提示确认互相覆盖。
	_message_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	add_child(_message_dialog)


func _refresh_all() -> void:
	_refresh_coins()
	_refresh_construction_status()
	_rebuild_facility_cards()


func _refresh_coins(_amount: int = 0) -> void:
	if _coins_label == null:
		return
	# 当前局外星穹；库存服务缺失时显示 0，避免面板因单例缺失报错。
	var coins: int = int(_global_inventory.call("get_coins")) if _global_inventory != null and _global_inventory.has_method("get_coins") else 0
	_coins_label.text = "当前星穹：%d" % coins


func _refresh_construction_status() -> void:
	if _construction_label == null or _service == null or not _service.has_method("get_active_construction_snapshot"):
		return
	# 进行中建造快照；为空表示当前没有建造队列。
	var snapshot: Dictionary = _service.call("get_active_construction_snapshot") as Dictionary
	# 目标状态文本；按剩余整数秒生成，未变化时跳过标签重写。
	var construction_text: String = "当前没有进行中的建造"
	if not snapshot.is_empty():
		construction_text = "建造中：%s → Lv.%d  剩余 %s" % [str(snapshot.get("name", "据点设施")), int(snapshot.get("target_level", 0)), _format_duration(float(snapshot.get("remaining_seconds", 0.0)))]
	if construction_text == _last_construction_text:
		return
	_last_construction_text = construction_text
	_construction_label.text = construction_text


func _rebuild_facility_cards() -> void:
	# 任何直接重建都消化当前挂起的合并刷新；同帧稍后的延迟回调据此跳过重复重建。
	_cards_rebuild_queued = false
	if _facility_container == null or _service == null:
		return
	for child in _facility_container.get_children():
		child.queue_free()
	# 是否存在建造队列；占用期间全部设施的升级按钮统一禁用。
	var construction_occupied: bool = _service.has_method("has_active_construction") and bool(_service.call("has_active_construction"))
	# 设施定义副本；卡片只读取当前快照，点击时服务仍会再次校验真实状态。
	var definitions: Array = _service.call("get_facility_definitions") as Array if _service.has_method("get_facility_definitions") else []
	for raw_definition in definitions:
		# 单座设施定义；包含稳定标识、名称、关联模块、基础造价与效果文案。
		var definition: Dictionary = raw_definition as Dictionary
		_facility_container.add_child(_create_facility_card(definition, construction_occupied))


func _create_facility_card(definition: Dictionary, construction_occupied: bool) -> Control:
	# 设施卡片；固定 318×190 并以独立 PanelContainer 承载，与矿场资产卡片保持同族视觉。
	var card: PanelContainer = PanelContainer.new()
	var facility_id: String = str(definition.get("id", ""))
	card.name = facility_id
	card.custom_minimum_size = Vector2(318.0, 190.0)
	# 当前设施等级；决定卡片是否使用运行中的亮色语义。
	var level: int = int(_service.call("get_facility_level", facility_id))
	# 卡片激活状态；已建成任意等级时显示亮色，0 级显示待建的暗色语义。
	var card_active: bool = level > 0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	# 卡片背景与边框；激活时取当前风格子分区色与弱强调描边，0 级降低透明度表达待建状态。
	style.bg_color = UI_STYLE_GUIDE.get_section_background_color() if card_active else Color(UI_STYLE_GUIDE.get_item_card_background_color(), 0.62)
	style.border_color = UI_STYLE_GUIDE.get_accent_muted_color() if card_active else Color(UI_STYLE_GUIDE.get_section_border_color(), 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	# 名称与等级行；名称左对齐，等级右对齐使用等宽展示。
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	content.add_child(name_row)
	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_STYLE_GUIDE.get_accent_color() if card_active else UI_STYLE_GUIDE.get_disabled_text_color())
	name_label.text = "%s（%s）" % [str(definition.get("name", "据点设施")), str(definition.get("module", ""))]
	name_row.add_child(name_label)
	var level_label: Label = Label.new()
	level_label.add_theme_font_size_override("font_size", 15)
	level_label.add_theme_color_override("font_color", Color(0.46, 0.92, 0.72, 1.0) if card_active else UI_STYLE_GUIDE.get_disabled_text_color())
	level_label.text = "Lv.%d/5" % level
	name_row.add_child(level_label)
	# 卡片说明文字色；取当前风格次要文字色，待建卡片降低透明度。
	var card_detail_color: Color = UI_STYLE_GUIDE.get_secondary_text_color() if card_active else Color(UI_STYLE_GUIDE.get_secondary_text_color(), 0.72)
	# 效果说明；固定展示每级效果与当前累计效果。
	var effect_label: Label = Label.new()
	effect_label.add_theme_font_size_override("font_size", 12)
	effect_label.add_theme_color_override("font_color", card_detail_color)
	effect_label.text = "%s\n当前效果：%s" % [str(definition.get("effect_text", "")), _get_current_effect_text(facility_id, level)]
	content.add_child(effect_label)
	var description_label: Label = Label.new()
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", card_detail_color)
	description_label.text = str(definition.get("description", ""))
	content.add_child(description_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	# 下一级费用与时长；满级时显示已满级说明。
	var upgrade_cost: int = int(_service.call("get_upgrade_cost", facility_id))
	var next_label: Label = Label.new()
	next_label.add_theme_font_size_override("font_size", 12)
	next_label.add_theme_color_override("font_color", card_detail_color)
	next_label.text = "下一级：%d 星穹  |  建造 %s" % [upgrade_cost, _format_hour_minute_duration(int(_service.call("get_upgrade_duration_seconds", facility_id)))] if upgrade_cost > 0 else "设施已达到最大等级"
	content.add_child(next_label)
	# 升级按钮；满级禁用，存在建造队列时统一显示占用文案。
	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(0.0, 32.0)
	if upgrade_cost <= 0:
		action_button.text = "已满级"
		action_button.disabled = true
	elif construction_occupied:
		action_button.text = "建造队列占用中"
		action_button.disabled = true
	else:
		action_button.text = "升级 Lv.%d→%d" % [level, level + 1]
		UI_STYLE_GUIDE.apply_primary_button(action_button)
		action_button.pressed.connect(Callable(self, "_open_upgrade_confirmation").bind(facility_id))
	content.add_child(action_button)
	return card


func _get_current_effect_text(facility_id: String, level: int) -> String:
	## 按设施标识与等级生成当前累计效果文本；0 级统一显示尚未生效。
	if level <= 0:
		return "尚未生效"
	if facility_id == "supply_hub":
		return "购买价格 -%d%%" % level
	if facility_id == "forge_workshop":
		return "锻造费用 -%d%%" % (level * 2)
	if facility_id == "cooling_plant":
		return "离线收益上限 +%d 小时" % level
	if facility_id == "actuarial_office":
		return "保费费率 -%.1f%%" % (float(level) * 0.5)
	if facility_id == "vault":
		return "定期利率 ×%.2f" % (1.0 + 0.04 * float(level))
	if facility_id == "mercenary_office":
		return "派遣报酬 +%d%%" % (level * 4)
	return "效果生效中"


func _open_upgrade_confirmation(facility_id: String) -> void:
	_pending_facility_id = facility_id
	# 设施定义与升级快照；确认正文展示费用、建造时长与升级后的效果。
	var definition: Dictionary = _get_facility_definition(facility_id)
	var level: int = int(_service.call("get_facility_level", facility_id))
	var cost: int = int(_service.call("get_upgrade_cost", facility_id))
	var duration_seconds: int = int(_service.call("get_upgrade_duration_seconds", facility_id))
	# 确认正文；升级后效果按目标等级预览。
	var message: String = "%s Lv.%d→%d\n需要：%d 星穹\n建造时长：%s（仅消耗在线时间）\n建成后效果：%s\n建造期间无法开始其他设施升级" % [str(definition.get("name", "据点设施")), level, level + 1, cost, _format_hour_minute_duration(duration_seconds), _get_current_effect_text(facility_id, level + 1)]
	_confirmation_dialog.present_adaptive("确认建造", message, "开始建造", "取消", true)


func _confirm_upgrade() -> void:
	if _service == null or _pending_facility_id.is_empty():
		return
	# 升级执行结果；服务在确认瞬间重新校验余额、等级与建造队列占用。
	var result: Dictionary = _service.call("start_upgrade", _pending_facility_id) as Dictionary
	if not bool(result.get("success", false)):
		_message_dialog.present_information("据点提示", str(result.get("message", "建造失败")))
	_clear_pending_upgrade()
	_rebuild_facility_cards()
	_refresh_construction_status()


func _clear_pending_upgrade() -> void:
	_pending_facility_id = ""


func _on_construction_changed() -> void:
	_queue_cards_rebuild()
	_refresh_construction_status()


func _queue_cards_rebuild() -> void:
	## 合并设施卡片重建；同帧内等级与建造信号多次触发只执行一次重建。
	if _cards_rebuild_queued:
		return
	_cards_rebuild_queued = true
	call_deferred("_flush_queued_cards_rebuild")


func _flush_queued_cards_rebuild() -> void:
	## 执行单次设施卡片重建；期间若已发生直接重建，标志会被消化并跳过重复工作。
	if not _cards_rebuild_queued:
		return
	_rebuild_facility_cards()


func _on_ui_style_changed(_style_id: String) -> void:
	## UI 风格切换后立即重建设施卡片，刷新其中手动取色的背景、边框与文字。
	_rebuild_facility_cards()


func _close_panel() -> void:
	visible = false
	set_process(false)
	_clear_pending_upgrade()
	closed.emit()


func _get_facility_definition(facility_id: String) -> Dictionary:
	## 从服务公开定义中查找指定设施；返回副本，UI 不修改静态配置。
	var definitions: Array = _service.call("get_facility_definitions") as Array if _service != null and _service.has_method("get_facility_definitions") else []
	for raw_definition in definitions:
		var definition: Dictionary = raw_definition as Dictionary
		if str(definition.get("id", "")) == facility_id:
			return definition
	return {}


func _format_duration(seconds: float) -> String:
	# 完整剩余秒数；向上取整避免 0.1 秒时提前显示 00:00。
	var total_seconds: int = maxi(int(ceil(seconds)), 0)
	# 分钟部分；建造最长 2 小时，因此不对分钟取模。
	var minutes: int = total_seconds / 60
	# 秒部分；固定显示两位，形成稳定倒计时宽度。
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]


func _format_hour_minute_duration(total_seconds: int) -> String:
	## 把秒数格式化为“X小时X分”样式的中文时长；用于建造时长展示，不用于逐秒倒计时。
	if total_seconds < 60:
		return "%d秒" % maxi(total_seconds, 0)
	# 完整小时数；建造时长最长 2 小时，不换算为天。
	var hours: int = total_seconds / 3600
	# 剩余分钟数；不足 1 分钟的秒数直接舍去，保持文本简洁。
	var minutes: int = (total_seconds % 3600) / 60
	if hours <= 0:
		return "%d分钟" % minutes
	if minutes <= 0:
		return "%d小时" % hours
	return "%d小时%d分" % [hours, minutes]
