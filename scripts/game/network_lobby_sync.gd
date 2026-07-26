extends Node2D
class_name NetworkLobbySync

## 联机大厅在场同步器让同一房间的成员在联机大厅内互相可见。
## 它只广播与消费带 lobby 场景上下文的玩家状态包，复用远程队友化身做纯展示；不涉及敌人、掉落、宝箱或任何伤害转发。
## 在场语义；只要成员仍在房间名册中，其化身就常驻联机大厅——成员切到菜单等其他界面后停止发包，
## 化身停在最后位置（尚未进过大厅时停在默认围观位）并在头顶显示“菜单中”，恢复发包后提示消失；只有退出房间或断线才移除化身。

## 队友化身脚本；与战斗同步器共用同一化身实现，大厅内不注入伤害转发回调。
const REMOTE_PLAYER_AVATAR_SCRIPT: Script = preload("res://scripts/player/remote_player_avatar.gd")
## 队友化身配色表；与战斗同步器保持同一顺序，保证同一成员在大厅与战斗中颜色一致。
const AVATAR_COLOR_PALETTE: Array[Color] = [
	Color(0.407843, 0.792157, 1.0, 1.0),
	Color(1.0, 0.62, 0.25, 1.0),
	Color(0.75, 0.55, 1.0, 1.0),
	Color(0.45, 0.9, 0.55, 1.0),
]
## 大厅状态广播间隔；单位秒，默认 0.05 即 20Hz，与战斗内队友状态同频。
const LOBBY_STATE_INTERVAL: float = 0.05
## 在场超时时长；单位秒，超过该时长未收到某成员的大厅状态包即判定其不在大厅现场并显示“菜单中”提示。
const PRESENCE_TIMEOUT_SECONDS: float = 1.6
## 不在大厅现场时的头顶状态提示文本；成员身处菜单、角色页等其他界面时显示，回到大厅后自动清除。
const MENU_STATUS_NOTE: String = "菜单中"
## 默认围观位基准点；成员在房间但尚未发来大厅状态包时化身停放的世界坐标锚点，位于出生区上方。
const DEFAULT_PRESENCE_POSITION: Vector2 = Vector2(0.0, -140.0)
## 默认围观位横向间距；多名未在场成员按名册顺序横向排开，避免化身重叠。
const DEFAULT_PRESENCE_SPACING: float = 72.0

## 联机会话服务缓存；初始化时解析，缺失时同步器保持空转。
var _network_session: Node = null
## 联机大厅世界缓存；作为化身挂载父节点，保证世界坐标一致。
var _lobby_world: Node2D = null
## 本地玩家节点缓存；状态采样来源。
var _player: Node2D = null
## 本地玩家战斗属性组件缓存；读取生命用于化身头顶信息条展示。
var _player_stats_component: Node = null
## 本地玩家护盾组件缓存；读取护盾用于化身头顶信息条展示。
var _player_shield_component: Node = null
## 大厅化身表；键为 peer_id，值为 RemotePlayerAvatar 节点。
var _remote_avatars: Dictionary = {}
## 成员最近状态包时间表；键为 peer_id，值为收包时刻秒数，用于在场超时判断。
var _last_state_seconds: Dictionary = {}
## 状态广播剩余时间；归零后采样本地玩家并广播。
var _state_broadcast_remaining: float = 0.0


func initialize(lobby_world: Node2D, player: Node2D) -> void:
	## 由联机大厅世界调用一次；解析会话服务与玩家组件并订阅消息与名册信号。
	_lobby_world = lobby_world
	_player = player
	_network_session = get_tree().root.get_node_or_null("NetworkSession")
	if _network_session == null:
		return
	_network_session.connect("combat_message_received", Callable(self, "_on_combat_message_received"))
	_network_session.connect("roster_changed", Callable(self, "_on_roster_changed"))
	_network_session.connect("disconnected_from_host", Callable(self, "_on_disconnected_from_host"))
	if _player != null:
		_player_stats_component = _player.get_node_or_null("StatsComponent")
		_player_shield_component = _player.get_node_or_null("ShieldComponent")
	# 进场名册补齐；本机进入联机大厅时房间可能早已建立，延迟一帧为全部既有成员创建常驻化身。
	call_deferred("_sync_roster_avatars")


func _exit_tree() -> void:
	## 离开大厅场景时断开会话信号；化身随场景销毁，网络连接保持不变。
	if _network_session == null:
		return
	if _network_session.is_connected("combat_message_received", Callable(self, "_on_combat_message_received")):
		_network_session.disconnect("combat_message_received", Callable(self, "_on_combat_message_received"))
	if _network_session.is_connected("roster_changed", Callable(self, "_on_roster_changed")):
		_network_session.disconnect("roster_changed", Callable(self, "_on_roster_changed"))
	if _network_session.is_connected("disconnected_from_host", Callable(self, "_on_disconnected_from_host")):
		_network_session.disconnect("disconnected_from_host", Callable(self, "_on_disconnected_from_host"))


func _process(delta: float) -> void:
	_state_broadcast_remaining -= delta
	if _state_broadcast_remaining <= 0.0:
		_state_broadcast_remaining = LOBBY_STATE_INTERVAL
		_broadcast_local_lobby_state()
	_refresh_presence_notes()


func _broadcast_local_lobby_state() -> void:
	## 采样本地玩家位置、瞄准与生命并按大厅上下文广播；未加入房间时不发包。
	if _network_session == null or _player == null or not is_instance_valid(_player):
		return
	if not bool(_network_session.call("is_session_active")):
		return
	# 本地瞄准方向；玩家控制器提供当前瞄准单位向量，缺失时回退向右。
	var aim_direction: Vector2 = _player.call("get_current_aim_direction") if _player.has_method("get_current_aim_direction") else Vector2.RIGHT
	_network_session.call("broadcast_combat_message", {
		"t": "player_state",
		"ctx": "lobby",
		"x": _player.global_position.x,
		"y": _player.global_position.y,
		"aim": aim_direction.angle(),
		"hp": float(_player_stats_component.get("current_health")) if _player_stats_component != null else 1.0,
		"mhp": float(_player_stats_component.get("max_health")) if _player_stats_component != null else 1.0,
		"sh": float(_player_shield_component.get("current_shield")) if _player_shield_component != null else 0.0,
		"dead": false,
	}, false)


func _on_combat_message_received(sender_peer_id: int, payload: Dictionary) -> void:
	## 大厅消息入口；只消费带 lobby 上下文的玩家状态包，其余消息类型全部忽略。
	if str(payload.get("t", "")) != "player_state" or str(payload.get("ctx", "")) != "lobby":
		return
	# 发送方化身节点；首包按名册信息按需创建。
	var avatar: Node = _ensure_lobby_avatar(sender_peer_id)
	if avatar == null:
		return
	_last_state_seconds[sender_peer_id] = Time.get_ticks_msec() * 0.001
	avatar.call("update_remote_state",
		Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0))),
		float(payload.get("aim", 0.0)),
		float(payload.get("hp", 1.0)),
		float(payload.get("mhp", 1.0)),
		float(payload.get("sh", 0.0)),
		bool(payload.get("dead", false)))


func _ensure_lobby_avatar(peer_id: int) -> Node:
	## 返回成员的大厅化身；不存在时按名册信息创建，不在名册中的来源直接忽略。
	if _remote_avatars.has(peer_id):
		# 已有化身条目；被场景清理时移除记录并等待下一包重建。
		var existing_avatar: Node = _remote_avatars[peer_id] as Node
		if is_instance_valid(existing_avatar):
			return existing_avatar
		_remote_avatars.erase(peer_id)
	if _network_session == null:
		return null
	# 名册展示快照；用于确认来源合法并取得配色下标与显示名。
	var roster_snapshot: Array[Dictionary] = _network_session.call("get_roster_snapshot")
	for member_index in range(roster_snapshot.size()):
		# 单个成员档案；匹配发送方 peer_id 后创建化身。
		var member_profile: Dictionary = roster_snapshot[member_index]
		if int(member_profile.get("peer_id", 0)) != peer_id:
			continue
		# 大厅化身节点；不注入伤害转发回调，大厅内不存在任何针对化身的命中结算。
		var avatar: CharacterBody2D = REMOTE_PLAYER_AVATAR_SCRIPT.new() as CharacterBody2D
		if avatar == null:
			return null
		avatar.name = "LobbyPlayerAvatar_%d" % peer_id
		# 化身标签文本；昵称加角色显示名，与战斗内保持一致格式。
		var avatar_label: String = "%s·%s" % [str(member_profile.get("name", "队友")), _get_character_display_name(str(member_profile.get("character_id", "stelle")))]
		avatar.call("setup_avatar", peer_id, avatar_label, AVATAR_COLOR_PALETTE[member_index % AVATAR_COLOR_PALETTE.size()], Callable())
		# 化身挂载父节点；优先大厅世界，保证与本地玩家同一坐标系。
		var avatar_parent: Node = _lobby_world if _lobby_world != null else self
		avatar_parent.add_child(avatar)
		# 默认围观位；成员尚未发来大厅状态包时按名册序横向排开停放，首个状态包会直接落位到真实位置。
		avatar.global_position = DEFAULT_PRESENCE_POSITION + Vector2(DEFAULT_PRESENCE_SPACING * float(member_index), 0.0)
		_remote_avatars[peer_id] = avatar
		return avatar
	return null


func _sync_roster_avatars() -> void:
	## 按名册补齐全部远程成员的常驻化身；成员在房间但不在大厅时化身仍留在大厅并由在场提示标注状态。
	if _network_session == null or not bool(_network_session.call("is_session_active")):
		return
	# 本机 peer_id；名册包含自己，本机由真实玩家节点表现，不创建化身。
	var local_peer_id: int = int(_network_session.call("get_local_peer_id"))
	for member_profile in (_network_session.call("get_roster_snapshot") as Array):
		# 单个成员 peer_id；非法编号与本机编号直接跳过。
		var member_peer_id: int = int((member_profile as Dictionary).get("peer_id", 0))
		if member_peer_id <= 0 or member_peer_id == local_peer_id:
			continue
		_ensure_lobby_avatar(member_peer_id)


func _refresh_presence_notes() -> void:
	## 按最近状态包时间刷新化身在场提示；停止发包的成员化身保持在大厅并显示“菜单中”，恢复发包后提示自动消失。
	# 当前时刻秒数；与收包时间比较判断成员是否仍在大厅现场。
	var current_seconds: float = Time.get_ticks_msec() * 0.001
	for peer_id in _remote_avatars.keys():
		# 成员化身节点；可能已随场景清理，无效实例交由名册变化路径移除记录。
		var avatar: Node = _remote_avatars[peer_id] as Node
		if avatar == null or not is_instance_valid(avatar):
			continue
		# 成员是否在大厅现场；从未发包或超过在场超时都视为身处菜单等其他界面。
		var present_in_lobby: bool = _last_state_seconds.has(peer_id) and current_seconds - float(_last_state_seconds.get(peer_id, 0.0)) <= PRESENCE_TIMEOUT_SECONDS
		if avatar.has_method("set_status_note"):
			avatar.call("set_status_note", "" if present_in_lobby else MENU_STATUS_NOTE)


func _remove_lobby_avatar(peer_id: int) -> void:
	## 移除单个大厅化身；超时、退员与断线共用本入口。
	# 待移除化身节点；可能已随场景销毁。
	var avatar: Node = _remote_avatars.get(peer_id) as Node
	_remote_avatars.erase(peer_id)
	_last_state_seconds.erase(peer_id)
	if avatar != null and is_instance_valid(avatar):
		avatar.queue_free()


func _on_roster_changed() -> void:
	## 名册变化回调；移除已退出房间成员的大厅化身，并为新入房成员补建常驻化身。
	if _network_session == null:
		return
	# 当前名册 peer_id 集合；不在集合中的化身立即移除。
	var roster_peer_ids: Dictionary = {}
	for member_profile in (_network_session.call("get_roster_snapshot") as Array):
		roster_peer_ids[int((member_profile as Dictionary).get("peer_id", 0))] = true
	for avatar_peer_id in _remote_avatars.keys().duplicate():
		if not roster_peer_ids.has(avatar_peer_id):
			_remove_lobby_avatar(int(avatar_peer_id))
	# 新成员补建；入房成员即使从未进入大厅也在本机大厅拥有常驻化身，未在场时由“菜单中”提示标注。
	_sync_roster_avatars()


func _on_disconnected_from_host(_reason: String) -> void:
	## 与主机断开回调；清空全部大厅化身，本地玩家继续留在大厅可重新建房或加入。
	for avatar_peer_id in _remote_avatars.keys().duplicate():
		_remove_lobby_avatar(int(avatar_peer_id))


func _get_character_display_name(character_id: String) -> String:
	# 会话状态服务；提供角色显示名查询，缺失时直接展示角色标识。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state != null and session_state.has_method("get_character_display_name"):
		return str(session_state.call("get_character_display_name", character_id))
	return character_id
