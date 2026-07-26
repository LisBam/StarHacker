extends PanelContainer
class_name MultiplayerLobbyPanel

## 联机组队面板提供局域网建房、房间发现、直连加入、成员名册、准备与统一开局入口。
## 面板只调用 NetworkSession 自动加载服务并响应其信号，不直接持有任何网络连接对象；主菜单与大厅宿主以遮罩方式复用本面板。

## 面板关闭信号；宿主收到后隐藏遮罩并恢复焦点。
signal closed

## 全局窗口样式指南；面板窗口、分区、按钮与文字统一从这里取色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 成员列表刷新用的准备状态文本；下标 0 为未准备、1 为已准备。
const READY_STATE_TEXTS: Array[String] = ["未准备", "已准备"]
## 组队骇入模式标识；与 NetworkSession.COMBAT_MODE_TEAM 保持一致，对应模式下拉框下标 0。
const COMBAT_MODE_TEAM: String = "team"
## 大逃杀模式标识；与 NetworkSession.COMBAT_MODE_BATTLE_ROYALE 保持一致，对应模式下拉框下标 1。
const COMBAT_MODE_BATTLE_ROYALE: String = "battle_royale"
## 模式显示名表；键为模式标识，值为玩家可见名称，房间列表与队伍提示共用。
const COMBAT_MODE_DISPLAY_NAMES: Dictionary = {"team": "组队骇入", "battle_royale": "大逃杀"}

## 联机会话服务缓存；ready 时解析，缺失时面板显示服务不可用提示。
var _network_session: Node = null
## 状态提示标签；显示连接进度、失败原因与操作结果。
var _status_label: Label = null
## 昵称输入框；建房或加入前可修改，入房后修改会即时同步给全员。
var _name_edit: LineEdit = null
## 房间列表控件；展示局域网内发现的可加入房间。
var _room_list: ItemList = null
## 刷新房间按钮；重新开启一轮房间探测广播。
var _refresh_rooms_button: Button = null
## 创建房间按钮；本机成为主机并开始应答房间探测。
var _create_room_button: Button = null
## 直连 IP 输入框；房间发现被防火墙拦截时的兜底加入方式。
var _ip_edit: LineEdit = null
## 直连加入按钮；按输入 IP 或当前选中房间发起加入。
var _join_button: Button = null
## 成员列表容器；按名册快照重建成员行。
var _member_list: VBoxContainer = null
## 队伍提示标签；显示未入房提示或开局条件说明。
var _team_hint_label: Label = null
## 模式下拉框；下标 0 为组队骇入、1 为大逃杀，仅主机可操作，客户端只读显示同步值。
var _mode_option_button: OptionButton = null
## 准备按钮；切换本机准备状态，文本随状态变化。
var _ready_button: Button = null
## 开始骇入按钮；仅主机可见，全员准备后可点击并统一开局。
var _start_button: Button = null
## 离开房间按钮；主机点击等于解散房间，客户端点击只退出自身。
var _leave_button: Button = null
## 已发现房间信息缓存；与房间列表条目下标一一对应，加入时读取选中项 IP。
var _discovered_room_cache: Array[Dictionary] = []


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(self)
	_network_session = get_tree().root.get_node_or_null("NetworkSession")
	_build_content()
	if _network_session != null:
		_network_session.connect("roster_changed", Callable(self, "_on_session_roster_changed"))
		_network_session.connect("session_state_changed", Callable(self, "_on_session_state_changed"))
		_network_session.connect("connection_failed", Callable(self, "_on_session_connection_failed"))
		_network_session.connect("disconnected_from_host", Callable(self, "_on_session_disconnected"))
		_network_session.connect("discovered_rooms_changed", Callable(self, "_on_discovered_rooms_changed"))
	# 面板可见性驱动房间探测开关；遮罩隐藏后立即停止 UDP 广播，不在后台持续发包。
	visibility_changed.connect(_on_panel_visibility_changed)
	refresh()


func refresh() -> void:
	## 面板打开时的统一刷新入口；重新提交本机档案（同步最新角色选择）并重建全部界面状态。
	if _network_session == null:
		if _status_label != null:
			_status_label.text = "联机服务不可用"
		return
	if _name_edit != null and not _name_edit.has_focus():
		_name_edit.text = str(_network_session.call("get_local_player_name"))
	if bool(_network_session.call("is_session_active")):
		# 重新提交档案；把玩家在角色页的最新选择同步进名册，昵称保持当前输入。
		_network_session.call("set_local_player_name", _name_edit.text if _name_edit != null else "")
	_refresh_room_list()
	_refresh_team_section()
	_refresh_action_states()


# ---------------------------------------------------------------------------
# 界面构建
# ---------------------------------------------------------------------------

func _build_content() -> void:
	## 构建面板完整内容；标题、状态行、昵称行、左侧房间区、右侧队伍区与底部返回按钮。
	# 根布局容器；纵向排列全部分区。
	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 10)
	add_child(root_layout)
	# 面板标题；与其他局外面板一致使用 24 号标题。
	var title_label: Label = Label.new()
	title_label.text = "联机"
	UI_STYLE_GUIDE.apply_title_label(title_label, 24)
	root_layout.add_child(title_label)
	_status_label = Label.new()
	_status_label.text = "在局域网内与其他玩家联机进行骇入"
	UI_STYLE_GUIDE.apply_secondary_label(_status_label)
	root_layout.add_child(_status_label)
	# 昵称行容器；左标签右输入框。
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	root_layout.add_child(name_row)
	# 昵称行标签；固定文本。
	var name_caption: Label = Label.new()
	name_caption.text = "昵称"
	UI_STYLE_GUIDE.apply_secondary_label(name_caption)
	name_row.add_child(name_caption)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "输入联机昵称"
	_name_edit.text_submitted.connect(_on_name_edit_submitted)
	_name_edit.focus_exited.connect(_on_name_edit_focus_exited)
	name_row.add_child(_name_edit)
	# 主体左右分栏；左侧房间发现、右侧队伍名册。
	var main_split: HBoxContainer = HBoxContainer.new()
	main_split.add_theme_constant_override("separation", 10)
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_child(main_split)
	main_split.add_child(_build_room_section())
	main_split.add_child(_build_team_section())
	# 返回按钮；与其他局外面板同规格。
	var close_button: Button = Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.pressed.connect(_on_close_button_pressed)
	root_layout.add_child(close_button)


func _build_room_section() -> Control:
	## 构建左侧局域网房间分区；包含房间列表、刷新、创建与直连加入。
	# 分区外框；使用统一浅色分区面板样式。
	var section_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(section_panel)
	section_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 分区内边距容器；四边 12 像素。
	var section_margin: MarginContainer = MarginContainer.new()
	section_margin.add_theme_constant_override("margin_left", 12)
	section_margin.add_theme_constant_override("margin_right", 12)
	section_margin.add_theme_constant_override("margin_top", 10)
	section_margin.add_theme_constant_override("margin_bottom", 12)
	section_panel.add_child(section_margin)
	# 分区纵向布局；标题、列表与按钮行。
	var section_layout: VBoxContainer = VBoxContainer.new()
	section_layout.add_theme_constant_override("separation", 8)
	section_margin.add_child(section_layout)
	# 分区标题；使用强调文字色。
	var section_title: Label = Label.new()
	section_title.text = "局域网房间"
	UI_STYLE_GUIDE.apply_muted_accent_label(section_title)
	section_layout.add_child(section_title)
	_room_list = ItemList.new()
	_room_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room_list.custom_minimum_size = Vector2(0.0, 220.0)
	_room_list.select_mode = ItemList.SELECT_SINGLE
	section_layout.add_child(_room_list)
	# 房间操作按钮行；刷新与创建。
	var room_button_row: HBoxContainer = HBoxContainer.new()
	room_button_row.add_theme_constant_override("separation", 8)
	section_layout.add_child(room_button_row)
	_refresh_rooms_button = Button.new()
	_refresh_rooms_button.text = "刷新房间"
	_refresh_rooms_button.custom_minimum_size = Vector2(0.0, 38.0)
	_refresh_rooms_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_rooms_button.pressed.connect(_on_refresh_rooms_button_pressed)
	room_button_row.add_child(_refresh_rooms_button)
	_create_room_button = Button.new()
	_create_room_button.text = "创建房间"
	_create_room_button.custom_minimum_size = Vector2(0.0, 38.0)
	_create_room_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_primary_button(_create_room_button)
	_create_room_button.pressed.connect(_on_create_room_button_pressed)
	room_button_row.add_child(_create_room_button)
	# 直连加入行；输入 IP 后点击加入，用于探测被防火墙拦截的场景。
	var join_row: HBoxContainer = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	section_layout.add_child(join_row)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "主机 IP（或从上方列表选择）"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_ip_edit)
	_join_button = Button.new()
	_join_button.text = "加入"
	_join_button.custom_minimum_size = Vector2(96.0, 38.0)
	UI_STYLE_GUIDE.apply_primary_button(_join_button)
	_join_button.pressed.connect(_on_join_button_pressed)
	join_row.add_child(_join_button)
	return section_panel


func _build_team_section() -> Control:
	## 构建右侧当前队伍分区；包含成员名册、开局条件提示、准备、开始与离开。
	# 分区外框；与左侧共用分区面板样式。
	var section_panel: PanelContainer = PanelContainer.new()
	UI_STYLE_GUIDE.apply_section_panel(section_panel)
	section_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 分区内边距容器；与左侧一致。
	var section_margin: MarginContainer = MarginContainer.new()
	section_margin.add_theme_constant_override("margin_left", 12)
	section_margin.add_theme_constant_override("margin_right", 12)
	section_margin.add_theme_constant_override("margin_top", 10)
	section_margin.add_theme_constant_override("margin_bottom", 12)
	section_panel.add_child(section_margin)
	# 分区纵向布局；标题、成员列表、提示与操作按钮。
	var section_layout: VBoxContainer = VBoxContainer.new()
	section_layout.add_theme_constant_override("separation", 8)
	section_margin.add_child(section_layout)
	# 分区标题；使用强调文字色。
	var section_title: Label = Label.new()
	section_title.text = "当前队伍"
	UI_STYLE_GUIDE.apply_muted_accent_label(section_title)
	section_layout.add_child(section_title)
	# 模式选择行容器；左标签右下拉框。
	var mode_row: HBoxContainer = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	section_layout.add_child(mode_row)
	# 模式行标签；固定文本。
	var mode_caption: Label = Label.new()
	mode_caption.text = "模式"
	UI_STYLE_GUIDE.apply_secondary_label(mode_caption)
	mode_row.add_child(mode_caption)
	_mode_option_button = OptionButton.new()
	_mode_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_option_button.custom_minimum_size = Vector2(0.0, 36.0)
	_mode_option_button.add_item(str(COMBAT_MODE_DISPLAY_NAMES[COMBAT_MODE_TEAM]), 0)
	_mode_option_button.add_item(str(COMBAT_MODE_DISPLAY_NAMES[COMBAT_MODE_BATTLE_ROYALE]), 1)
	_mode_option_button.item_selected.connect(_on_mode_option_selected)
	mode_row.add_child(_mode_option_button)
	_member_list = VBoxContainer.new()
	_member_list.add_theme_constant_override("separation", 6)
	_member_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section_layout.add_child(_member_list)
	_team_hint_label = Label.new()
	_team_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE_GUIDE.apply_secondary_label(_team_hint_label)
	section_layout.add_child(_team_hint_label)
	# 队伍操作按钮行；准备与开始。
	var team_button_row: HBoxContainer = HBoxContainer.new()
	team_button_row.add_theme_constant_override("separation", 8)
	section_layout.add_child(team_button_row)
	_ready_button = Button.new()
	_ready_button.text = "准备"
	_ready_button.custom_minimum_size = Vector2(0.0, 38.0)
	_ready_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_button.pressed.connect(_on_ready_button_pressed)
	team_button_row.add_child(_ready_button)
	_start_button = Button.new()
	_start_button.text = "开始骇入"
	_start_button.custom_minimum_size = Vector2(0.0, 38.0)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_STYLE_GUIDE.apply_primary_button(_start_button)
	_start_button.pressed.connect(_on_start_button_pressed)
	team_button_row.add_child(_start_button)
	_leave_button = Button.new()
	_leave_button.text = "离开房间"
	_leave_button.custom_minimum_size = Vector2(0.0, 38.0)
	UI_STYLE_GUIDE.apply_danger_button(_leave_button)
	_leave_button.pressed.connect(_on_leave_button_pressed)
	section_layout.add_child(_leave_button)
	return section_panel


# ---------------------------------------------------------------------------
# 界面刷新
# ---------------------------------------------------------------------------

func _refresh_room_list() -> void:
	## 重建局域网房间列表；缓存房间信息供加入按钮读取选中项。
	if _room_list == null or _network_session == null:
		return
	# 之前选中的房间 IP；重建后尽量恢复选择，避免刷新打断玩家操作。
	var previously_selected_ip: String = ""
	if not _room_list.get_selected_items().is_empty():
		# 之前选中的条目下标；用于回读缓存中的 IP。
		var selected_index: int = _room_list.get_selected_items()[0]
		if selected_index >= 0 and selected_index < _discovered_room_cache.size():
			previously_selected_ip = str(_discovered_room_cache[selected_index].get("ip", ""))
	_room_list.clear()
	_discovered_room_cache = _network_session.call("get_discovered_rooms")
	for room_index in range(_discovered_room_cache.size()):
		# 单个房间信息；包含房名、IP、人数与是否在战斗中。
		var room_info: Dictionary = _discovered_room_cache[room_index]
		# 房间展示文本；附带当前模式，战斗中的房间标注不可中途加入。
		var room_text: String = "%s（%s）%d/%d·%s%s" % [
			str(room_info.get("room_name", "未命名房间")),
			str(room_info.get("ip", "?")),
			int(room_info.get("player_count", 0)),
			int(room_info.get("max_players", 4)),
			str(COMBAT_MODE_DISPLAY_NAMES.get(str(room_info.get("mode", COMBAT_MODE_TEAM)), "组队骇入")),
			"·战斗中" if bool(room_info.get("in_combat", false)) else "",
		]
		_room_list.add_item(room_text)
		if str(room_info.get("ip", "")) == previously_selected_ip:
			_room_list.select(room_index)
	if _discovered_room_cache.is_empty():
		_room_list.add_item("未发现房间；可让主机先创建房间，或直接输入 IP 加入")
		_room_list.set_item_disabled(0, true)


func _refresh_team_section() -> void:
	## 重建成员名册显示；未入房时清空并显示引导提示。
	if _member_list == null or _network_session == null:
		return
	for member_row in _member_list.get_children():
		member_row.queue_free()
	if not bool(_network_session.call("is_session_active")):
		_team_hint_label.text = "尚未加入房间。创建房间成为主机，或从左侧加入队友的房间。"
		return
	# 名册快照；元素包含 peer_id、昵称、角色与准备状态。
	var roster_snapshot: Array[Dictionary] = _network_session.call("get_roster_snapshot")
	for member_profile in roster_snapshot:
		# 单行成员标签；主机附加标识，准备状态用语义色区分。
		var member_label: Label = Label.new()
		# 成员角色显示名；从会话状态服务读取，保证与角色系统一致。
		var character_display_name: String = _get_character_display_name(str(member_profile.get("character_id", "stelle")))
		# 成员准备状态；决定行尾文本与颜色。
		var member_ready: bool = bool(member_profile.get("ready", false))
		member_label.text = "%s（%s）%s — %s" % [
			str(member_profile.get("name", "玩家")),
			character_display_name,
			"［主机］" if int(member_profile.get("peer_id", 0)) == 1 else "",
			READY_STATE_TEXTS[1] if member_ready else READY_STATE_TEXTS[0],
		]
		member_label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55, 1.0) if member_ready else UI_STYLE_GUIDE.get_secondary_text_color())
		_member_list.add_child(member_label)
	# 当前模式说明；大逃杀提示随机分散出生与玩家互伤，组队骇入提示合作规则。
	var mode_description: String = "大逃杀：全员随机分散出生，玩家可互相攻击。" if str(_network_session.call("get_session_combat_mode")) == COMBAT_MODE_BATTLE_ROYALE else "组队骇入：全员同点出生并肩作战，玩家之间不可互伤。"
	if bool(_network_session.call("is_session_host")):
		_team_hint_label.text = "%s全员准备后可开始（至少 2 名成员）；切换模式会清空全员准备。" % mode_description
	else:
		_team_hint_label.text = "%s等待主机开始；请先点击“准备”。" % mode_description


func _refresh_action_states() -> void:
	## 按会话状态刷新全部按钮可用性与准备按钮文本。
	if _network_session == null:
		return
	# 当前是否已入房；决定左右两个分区的可交互性。
	var session_active: bool = bool(_network_session.call("is_session_active"))
	# 当前是否正在连接；连接期禁用全部会话操作避免重复请求。
	var joining: bool = bool(_network_session.call("is_joining"))
	if _create_room_button != null:
		_create_room_button.disabled = session_active or joining
	if _join_button != null:
		_join_button.disabled = session_active or joining
	if _refresh_rooms_button != null:
		_refresh_rooms_button.disabled = session_active or joining
	if _ready_button != null:
		_ready_button.disabled = not session_active
		_ready_button.text = "取消准备" if session_active and bool(_network_session.call("is_local_ready")) else "准备"
	if _mode_option_button != null:
		# 模式下拉框状态；仅主机在房间内可切换，其余情况只读显示当前同步值。
		_mode_option_button.disabled = not (session_active and bool(_network_session.call("is_session_host")))
		_mode_option_button.select(1 if str(_network_session.call("get_session_combat_mode")) == COMBAT_MODE_BATTLE_ROYALE else 0)
	if _start_button != null:
		_start_button.visible = session_active and bool(_network_session.call("is_session_host"))
		_start_button.disabled = not bool(_network_session.call("is_everyone_ready"))
	if _leave_button != null:
		_leave_button.disabled = not session_active and not joining
	if joining and _status_label != null:
		_status_label.text = "正在连接主机…"


func _get_character_display_name(character_id: String) -> String:
	# 会话状态服务；提供角色显示名查询，缺失时直接展示角色标识。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state != null and session_state.has_method("get_character_display_name"):
		return str(session_state.call("get_character_display_name", character_id))
	return character_id


# ---------------------------------------------------------------------------
# 交互回调
# ---------------------------------------------------------------------------

func _on_panel_visibility_changed() -> void:
	## 面板可见性变化时开关房间探测；已入房后无需继续探测。
	if _network_session == null:
		return
	# 是否应开启探测；面板实际可见且尚未入房时才广播探测请求。
	var should_discover: bool = is_visible_in_tree() and not bool(_network_session.call("is_session_active"))
	_network_session.call("set_room_discovery_active", should_discover)


func _on_name_edit_submitted(_submitted_text: String) -> void:
	_apply_local_player_name()


func _on_name_edit_focus_exited() -> void:
	_apply_local_player_name()


func _apply_local_player_name() -> void:
	## 应用昵称输入；写回服务并回读规范化结果（空昵称回退默认名）。
	if _network_session == null or _name_edit == null:
		return
	_network_session.call("set_local_player_name", _name_edit.text)
	_name_edit.text = str(_network_session.call("get_local_player_name"))


func _on_refresh_rooms_button_pressed() -> void:
	## 手动刷新房间列表；重启一轮探测并立即清空过期条目。
	if _network_session == null:
		return
	_network_session.call("set_room_discovery_active", false)
	_network_session.call("set_room_discovery_active", true)
	_status_label.text = "正在搜索局域网房间…"
	_refresh_room_list()


func _on_create_room_button_pressed() -> void:
	if _network_session == null:
		return
	_apply_local_player_name()
	if bool(_network_session.call("create_room")):
		_status_label.text = "房间已创建，等待队友加入（本机 IP 可通过 ipconfig 查看）"
	refresh()


func _on_join_button_pressed() -> void:
	## 加入房间；优先使用直连 IP 输入，否则读取房间列表当前选中项。
	if _network_session == null:
		return
	_apply_local_player_name()
	# 目标主机 IP；输入框为空时回退列表选中房间。
	var target_ip: String = _ip_edit.text.strip_edges() if _ip_edit != null else ""
	if target_ip.is_empty() and _room_list != null and not _room_list.get_selected_items().is_empty():
		# 列表选中下标；映射回缓存房间信息。
		var selected_index: int = _room_list.get_selected_items()[0]
		if selected_index >= 0 and selected_index < _discovered_room_cache.size():
			target_ip = str(_discovered_room_cache[selected_index].get("ip", ""))
	if target_ip.is_empty():
		_status_label.text = "请先选择一个房间或输入主机 IP"
		return
	if bool(_network_session.call("join_room", target_ip)):
		_status_label.text = "正在连接 %s …" % target_ip
	_refresh_action_states()


func _on_mode_option_selected(selected_index: int) -> void:
	## 主机切换联机战斗模式；服务端会清空全员准备并向全体成员同步新模式。
	if _network_session == null:
		return
	_network_session.call("set_session_combat_mode", COMBAT_MODE_BATTLE_ROYALE if selected_index == 1 else COMBAT_MODE_TEAM)
	_refresh_team_section()


func _on_ready_button_pressed() -> void:
	if _network_session == null:
		return
	_network_session.call("set_local_ready", not bool(_network_session.call("is_local_ready")))
	_refresh_action_states()


func _on_start_button_pressed() -> void:
	if _network_session == null:
		return
	if not bool(_network_session.call("request_start_combat")):
		_status_label.text = "开局失败：需要至少 2 名成员且全员准备"


func _on_leave_button_pressed() -> void:
	if _network_session == null:
		return
	_network_session.call("leave_session")
	_status_label.text = "已离开房间"
	refresh()


func _on_close_button_pressed() -> void:
	closed.emit()


# ---------------------------------------------------------------------------
# 服务信号回调
# ---------------------------------------------------------------------------

func _on_session_roster_changed() -> void:
	_refresh_team_section()
	_refresh_action_states()


func _on_session_state_changed() -> void:
	_refresh_team_section()
	_refresh_action_states()
	_on_panel_visibility_changed()


func _on_session_connection_failed(reason: String) -> void:
	if _status_label != null:
		_status_label.text = reason
	_refresh_action_states()


func _on_session_disconnected(reason: String) -> void:
	if _status_label != null:
		_status_label.text = reason
	_refresh_team_section()
	_refresh_action_states()


func _on_discovered_rooms_changed() -> void:
	_refresh_room_list()
