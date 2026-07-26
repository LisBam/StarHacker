extends CanvasLayer

## 联机房间状态字幕在屏幕顶部常驻显示“联机房间 N/M”（N 为已准备成员数、M 为房间总人数）。
## 字幕只读取 NetworkSession 的名册快照做纯展示，提醒玩家当前仍身处联机房间；不拦截鼠标、不参与 UI 换肤重建。
## 显示规则；本机处于任一联机会话（主机或已加入）且不在正式战斗场景时显示，战斗场景内隐藏以避免遮挡战斗 HUD。

## 字幕画布图层序号；高于常规界面与局外面板，低于场景过渡层（1000）与横幅通知层（1200），转场黑屏期间自然被覆盖。
const OVERLAY_CANVAS_LAYER: int = 120
## 战斗世界场景路径；当前场景等于该路径时隐藏字幕，与 NetworkSession 的统一开局目标场景保持一致。
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game/game_world.tscn"
## 状态轮询间隔；单位秒，字幕按该周期复核场景与名册变化，文本未变化时不写入控件。
const STATUS_POLL_INTERVAL_SECONDS: float = 0.25

## 字幕顶部偏移；默认 50 像素，位于大厅顶部标题正下方，同时避开顶部横幅通知的常用区域，运行时无需动态修改。
@export_range(0.0, 200.0, 1.0) var top_offset: float = 50.0

## 联机会话服务缓存；ready 阶段解析一次，缺失时字幕保持隐藏。
var _network_session: Node = null
## 字幕面板容器；运行时创建，深色底加青蓝描边，整体忽略鼠标。
var _panel: PanelContainer = null
## 字幕文本标签；运行时创建，显示“联机房间 N/M”。
var _label: Label = null
## 轮询累计秒数；默认 0，达到轮询间隔后复核一次显示状态与文本。
var _poll_accumulated_seconds: float = 0.0
## 上次写入的字幕文本；默认空字符串，未变化时跳过控件写入。
var _last_text: String = ""


func _ready() -> void:
	layer = OVERLAY_CANVAS_LAYER
	# 暂停豁免；暂停界面与局外面板打开期间字幕仍需保持状态正确。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_network_session = get_tree().root.get_node_or_null("NetworkSession")
	if _network_session != null:
		if _network_session.has_signal("roster_changed"):
			# 名册变化信号；成员加入、退出与准备状态切换时立即刷新 N/M 读数。
			_network_session.connect("roster_changed", Callable(self, "_refresh_now"))
		if _network_session.has_signal("session_state_changed"):
			# 会话状态信号；建房、加入与离开房间时立即切换字幕可见性。
			_network_session.connect("session_state_changed", Callable(self, "_refresh_now"))
	_refresh_now()


func _process(delta: float) -> void:
	# 低频轮询兜底；场景切换没有专用信号，按固定间隔复核战斗场景隐藏规则。
	_poll_accumulated_seconds += maxf(delta, 0.0)
	if _poll_accumulated_seconds < STATUS_POLL_INTERVAL_SECONDS:
		return
	_poll_accumulated_seconds = 0.0
	_refresh_now()


func _build_interface() -> void:
	## 创建字幕控件结构；全屏透明宿主内放置顶部居中的自适应宽度深色面板。
	# 全屏宿主控件；只负责布局锚定，完全忽略鼠标输入。
	var host: Control = Control.new()
	host.name = "OverlayHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	# 顶部居中行；横向容器让面板按内容宽度自动居中，窗口尺寸变化时保持水平居中。
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_row.offset_top = top_offset
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(top_row)
	_panel = PanelContainer.new()
	_panel.name = "StatusPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 字幕面板样式；深色底配青蓝描边，与联机界面的强调色一致，不参与 UI 换肤重建。
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.020, 0.045, 0.065, 0.90)
	panel_style.border_color = Color(0.30, 0.68, 0.82, 0.94)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 4.0
	panel_style.content_margin_bottom = 4.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.visible = false
	top_row.add_child(_panel)
	_label = Label.new()
	_label.name = "StatusLabel"
	_label.add_theme_font_size_override("font_size", 15)
	# 字幕文字颜色；青蓝强调色说明这是联机会话状态而非警告信息。
	_label.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func _refresh_now() -> void:
	## 复核字幕可见性与文本；入房且不在战斗场景时显示“联机房间 已准备数/总人数”。
	if _panel == null:
		return
	# 会话活跃状态；主机或已加入都算在房间内，加入握手期不显示。
	var session_active: bool = _network_session != null and _network_session.has_method("is_session_active") and bool(_network_session.call("is_session_active"))
	# 是否处于正式战斗场景；战斗内隐藏字幕，避免与战斗 HUD 顶部信息重叠。
	var in_combat_scene: bool = false
	# 当前场景节点；启动早期可能为空，此时按非战斗场景处理。
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path == GAME_WORLD_SCENE_PATH:
		in_combat_scene = true
	# 字幕目标可见性；与当前可见性一致时不重复写入。
	var should_show: bool = session_active and not in_combat_scene
	if _panel.visible != should_show:
		_panel.visible = should_show
	if not should_show:
		return
	# 名册展示快照；统计已准备成员数与房间总人数。
	var roster: Array = _network_session.call("get_roster_snapshot") as Array
	# 已准备成员数；含主机在内逐个统计准备位。
	var ready_count: int = 0
	for member_profile in roster:
		if bool((member_profile as Dictionary).get("ready", false)):
			ready_count += 1
	# 目标字幕文本；未变化时跳过标签写入。
	var status_text: String = "联机房间 %d/%d" % [ready_count, roster.size()]
	if status_text != _last_text:
		_last_text = status_text
		_label.text = status_text
