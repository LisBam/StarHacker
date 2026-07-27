extends Node

## 局域网联机会话服务负责建房、房间发现、加入、成员名册、准备状态和统一开局。
## 服务本身只维护网络连接与队伍状态；战斗内的实体同步由 GameWorld 动态挂载的 NetworkCombatSync 通过本服务的通用消息通道完成。
## 本服务为 AutoLoad 常驻节点，场景切换不会中断连接；主机固定使用 ENet 服务器身份（peer_id = 1）。

## 名册发生任何变化时派发；联机面板据此重建成员列表与按钮状态。
signal roster_changed
## 会话连接状态变化时派发；包含建房、加入成功、离开与被动断开，供界面统一刷新。
signal session_state_changed
## 主动加入房间失败时派发；参数为可直接展示给玩家的失败原因文本。
signal connection_failed(reason: String)
## 与主机的连接被动断开时派发；参数为可直接展示给玩家的原因文本。
signal disconnected_from_host(reason: String)
## 收到其他成员战斗同步消息时派发；参数为发送方 peer_id 与消息字典，由 NetworkCombatSync 消费。
signal combat_message_received(sender_peer_id: int, payload: Dictionary)
## 局域网房间发现列表变化时派发；联机面板据此刷新可加入房间列表。
signal discovered_rooms_changed
## 联机战斗统一开局时派发；此时共享种子已经写入，场景切换由本服务直接执行。
signal combat_session_started

## 正式骇入模式标识；联机开局固定写入该模式，训练场不参与组队。
const GAME_MODE_HACK: String = "hack"
## 联机战斗模式：组队骇入；全员合作对抗敌人，玩家之间不可互相伤害，为默认模式。
const COMBAT_MODE_TEAM: String = "team"
## 联机战斗模式：大逃杀；全员随机分散出生在地图各处且可以互相攻击，敌人与物资规则保持不变。
const COMBAT_MODE_BATTLE_ROYALE: String = "battle_royale"
## 联机对战 ENet 端口；默认 24857，主机监听该端口，直连加入也使用该端口。
const GAME_PORT: int = 24857
## 局域网房间发现 UDP 端口；默认 24858，主机监听探测请求并回复房间信息。
const DISCOVERY_PORT: int = 24858
## 房间探测请求魔法字符串；双方版本一致才会互相识别，防止无关 UDP 包被误解析。
const DISCOVERY_REQUEST_MAGIC: String = "star_hacker_room_probe_v1"
## 房间探测回复魔法字符串；客户端只接受携带该标识的回复。
const DISCOVERY_REPLY_MAGIC: String = "star_hacker_room_reply_v1"
## 联机协议版本；版本 3 新增局内骇入协议快照与团队平均代价，版本不一致的房间会显示为不可加入。
const PROTOCOL_VERSION: int = 3
## 房间最大成员数量；默认 4 人小队，超出后主机会拒绝新的连接。
const MAX_PLAYERS: int = 4
## 房间探测广播间隔；单位秒，发现开启期间按该周期向局域网发送探测请求。
const DISCOVERY_PROBE_INTERVAL: float = 1.0
## 已发现房间过期时长；单位秒，超过该时长未再次收到回复的房间从列表移除。
const DISCOVERED_ROOM_TIMEOUT: float = 3.0
## 战斗世界场景路径；统一开局时所有成员经 SceneTransition 进入该场景。
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game/game_world.tscn"
## 会话状态枚举：空闲，未建立任何联机连接。
const SESSION_STATE_IDLE: int = 0
## 会话状态枚举：主机模式，本机已创建房间并监听加入。
const SESSION_STATE_HOSTING: int = 1
## 会话状态枚举：正在连接主机，等待 ENet 握手结果。
const SESSION_STATE_JOINING: int = 2
## 会话状态枚举：已加入远程主机房间。
const SESSION_STATE_JOINED: int = 3

## 本机玩家昵称；默认取系统用户名，联机面板可在建房或加入前修改，仅运行期保存。
var _local_player_name: String = ""
## 成员名册；键为 peer_id，值为包含 name、character_id、ready 的字典，主机为权威来源并向全员广播。
var _roster: Dictionary = {}
## 当前会话状态；取值为 SESSION_STATE_* 枚举，默认空闲。
var _session_state: int = SESSION_STATE_IDLE
## 联机战斗是否进行中；开局广播后置 true，本机离开战斗场景后由 NetworkCombatSync 通知复位。
var _combat_session_active: bool = false
## 联机共享地图种子；开局时由主机生成并广播，GameWorld 用它复现同一张地图。
var _shared_map_seed: int = 0
## 当前联机战斗模式；取值为 COMBAT_MODE_TEAM 或 COMBAT_MODE_BATTLE_ROYALE，由主机选择并同步给全体成员，开局指令再次携带确保一致。
var _session_combat_mode: String = COMBAT_MODE_TEAM
## 当前联机骇入模式；取值为 HackModeRules 定义的 standard、bare 或 overclock，由主机选择并同步给全体成员。
## 与多人模式（组队/对抗）为两个独立维度；开局指令再次携带该值作为最终权威，成员各自写入 SessionState。
var _session_hack_variant: String = HackModeRules.VARIANT_STANDARD
## 当前联机模式扩展 ID；由房主选择并同步给全体成员，当前可包含 risk_contract。
var _session_mode_extension_ids: Array[String] = []
## 当前联机风险合约词条 ID；只有启用 risk_contract 且至少一项合法时有效，开局指令再次携带。
var _session_risk_modifier_ids: Array[String] = []
## 主机侧房间发现监听套接字；仅主机绑定发现端口，收到探测请求后回复房间信息。
var _discovery_server_socket: PacketPeerUDP = null
## 客户端房间探测套接字；仅发现模式开启时存在，负责广播探测与接收回复。
var _discovery_client_socket: PacketPeerUDP = null
## 房间发现是否开启；联机面板打开房间列表时开启，关闭面板或加入房间后关闭。
var _discovery_active: bool = false
## 距离下一次探测广播的剩余时间；单位秒，归零后重新发送并复位为探测间隔。
var _discovery_probe_remaining: float = 0.0
## 已发现房间表；键为 "ip:端口" 字符串，值为包含 ip、room_name、player_count、max_players、version、last_seen 的字典。
var _discovered_rooms: Dictionary = {}


func _ready() -> void:
	# 网络服务必须无视场景树暂停持续处理；否则战斗内打开界面会阻断心跳与状态同步。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_local_player_name = _get_default_player_name()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	_poll_discovery_server()
	_poll_discovery_client(delta)


# ---------------------------------------------------------------------------
# 建房、加入与离开
# ---------------------------------------------------------------------------

func create_room() -> bool:
	## 以主机身份创建局域网房间；成功后本机进入名册并开始应答房间探测。
	if _session_state != SESSION_STATE_IDLE:
		return false
	# ENet 服务器对等体；监听联机端口，容量按最大成员数配置。
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# 服务器创建结果；端口被占用或权限不足时返回非 OK 错误码。
	var create_error: int = server_peer.create_server(GAME_PORT, MAX_PLAYERS)
	if create_error != OK:
		connection_failed.emit("创建房间失败（端口 %d 可能被占用）" % GAME_PORT)
		return false
	multiplayer.multiplayer_peer = server_peer
	_session_state = SESSION_STATE_HOSTING
	_roster.clear()
	_roster[1] = _build_local_profile(true)
	_start_discovery_server()
	roster_changed.emit()
	session_state_changed.emit()
	return true


func join_room(host_ip: String) -> bool:
	## 按 IP 直连加入远程主机房间；握手结果通过 connected_to_server 或 connection_failed 回调异步返回。
	if _session_state != SESSION_STATE_IDLE:
		return false
	# 规范化主机地址；去除首尾空白后必须是合法 IPv4/IPv6 地址或主机名。
	var resolved_ip: String = host_ip.strip_edges()
	if resolved_ip.is_empty():
		connection_failed.emit("请输入主机 IP 地址")
		return false
	# ENet 客户端对等体；向主机联机端口发起连接。
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# 客户端创建结果；本机网络栈异常时返回非 OK 错误码。
	var join_error: int = client_peer.create_client(resolved_ip, GAME_PORT)
	if join_error != OK:
		connection_failed.emit("无法连接到 %s" % resolved_ip)
		return false
	multiplayer.multiplayer_peer = client_peer
	_session_state = SESSION_STATE_JOINING
	session_state_changed.emit()
	return true


func leave_session(notify_reason: String = "") -> void:
	## 主动关闭当前联机会话；主机关闭房间时所有成员会收到被动断开，客户端离开只影响自身。
	if _session_state == SESSION_STATE_IDLE:
		return
	_stop_discovery_server()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_reset_session_state()
	if not notify_reason.is_empty():
		disconnected_from_host.emit(notify_reason)
	session_state_changed.emit()
	roster_changed.emit()


func _reset_session_state() -> void:
	## 清空会话运行状态；连接对象的关闭由调用方负责，本函数只复位数据。
	_session_state = SESSION_STATE_IDLE
	_combat_session_active = false
	_shared_map_seed = 0
	_session_combat_mode = COMBAT_MODE_TEAM
	_session_hack_variant = HackModeRules.VARIANT_STANDARD
	_session_mode_extension_ids.clear()
	_session_risk_modifier_ids.clear()
	_roster.clear()


# ---------------------------------------------------------------------------
# 名册与准备状态
# ---------------------------------------------------------------------------

func set_local_player_name(new_player_name: String) -> void:
	## 修改本机昵称；已入房时立即向主机重新提交个人档案并同步全员。
	# 规范化昵称；去除首尾空白，空昵称回退为系统默认名称。
	var resolved_player_name: String = new_player_name.strip_edges()
	_local_player_name = resolved_player_name if not resolved_player_name.is_empty() else _get_default_player_name()
	_submit_local_profile()


func set_local_ready(ready: bool) -> void:
	## 切换本机准备状态；主机成员也使用同一准备协议，开局要求全员准备。
	if _session_state == SESSION_STATE_HOSTING:
		if _roster.has(1):
			(_roster[1] as Dictionary)["ready"] = ready
			_broadcast_roster()
		return
	if _session_state == SESSION_STATE_JOINED:
		_rpc_submit_profile.rpc_id(1, _build_local_profile(ready))


func set_session_combat_mode(combat_mode: String) -> void:
	## 主机切换联机战斗模式；模式变化会清空全员准备状态，要求成员重新确认，客户端调用无效。
	if _session_state != SESSION_STATE_HOSTING or _combat_session_active:
		return
	# 规范化模式标识；未知取值一律回退组队骇入。
	var resolved_combat_mode: String = COMBAT_MODE_BATTLE_ROYALE if combat_mode == COMBAT_MODE_BATTLE_ROYALE else COMBAT_MODE_TEAM
	if resolved_combat_mode == _session_combat_mode:
		return
	_session_combat_mode = resolved_combat_mode
	_set_all_ready_false()
	_rpc_sync_combat_mode.rpc(resolved_combat_mode)
	_broadcast_roster()
	session_state_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_combat_mode(combat_mode: String) -> void:
	## 客户端接收主机的联机战斗模式；同步后刷新界面提示。
	_session_combat_mode = COMBAT_MODE_BATTLE_ROYALE if combat_mode == COMBAT_MODE_BATTLE_ROYALE else COMBAT_MODE_TEAM
	session_state_changed.emit()


func set_session_hack_variant(hack_variant: String) -> void:
	## 主机切换联机骇入模式（标准/零装/超频）；变化会清空全员准备状态并同步全员，客户端调用无效。
	if _session_state != SESSION_STATE_HOSTING or _combat_session_active:
		return
	# 规范化骇入模式标识；未知取值一律回退标准骇入。
	var resolved_hack_variant: String = HackModeRules.normalize_variant(hack_variant)
	if resolved_hack_variant == _session_hack_variant:
		return
	_session_hack_variant = resolved_hack_variant
	# 重新校验的扩展配置；切换到无结算的超频模式时自动清除风险合约，切回其他模式不会恢复旧配置。
	var sanitized_configuration: Dictionary = ModeExtensionRules.sanitize_configuration(_session_mode_extension_ids, _session_risk_modifier_ids, _session_hack_variant)
	_session_mode_extension_ids = _to_string_array(sanitized_configuration.get("extension_ids", []))
	_session_risk_modifier_ids = _to_string_array(sanitized_configuration.get("risk_modifier_ids", []))
	_set_all_ready_false()
	_rpc_sync_hack_variant.rpc(resolved_hack_variant)
	_rpc_sync_mode_extensions.rpc(_session_mode_extension_ids, _session_risk_modifier_ids)
	_broadcast_roster()
	session_state_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_hack_variant(hack_variant: String) -> void:
	## 客户端接收主机的联机骇入模式；同步后刷新界面提示。
	_session_hack_variant = HackModeRules.normalize_variant(hack_variant)
	# 客户端当前扩展配置；先按新骇入模式本地校验，随后主机的扩展同步消息会提供最终权威值。
	var sanitized_configuration: Dictionary = ModeExtensionRules.sanitize_configuration(_session_mode_extension_ids, _session_risk_modifier_ids, _session_hack_variant)
	_session_mode_extension_ids = _to_string_array(sanitized_configuration.get("extension_ids", []))
	_session_risk_modifier_ids = _to_string_array(sanitized_configuration.get("risk_modifier_ids", []))
	session_state_changed.emit()


func set_session_mode_extensions(extension_ids: Array, risk_modifier_ids: Array) -> void:
	## 房主更新模式扩展配置；任何有效变化都会清空全员准备，客户端与战斗进行中调用无效。
	if _session_state != SESSION_STATE_HOSTING or _combat_session_active:
		return
	# 规范化配置；规则表统一过滤未知扩展、同类重复风险词条与当前骇入模式不兼容项。
	var sanitized_configuration: Dictionary = ModeExtensionRules.sanitize_configuration(extension_ids, risk_modifier_ids, _session_hack_variant)
	# 有效扩展 ID；使用强类型副本，避免调用方后续修改原数组影响房间状态。
	var resolved_extension_ids: Array[String] = _to_string_array(sanitized_configuration.get("extension_ids", []))
	# 有效风险词条 ID；只有风险合约合法启用时保留。
	var resolved_risk_modifier_ids: Array[String] = _to_string_array(sanitized_configuration.get("risk_modifier_ids", []))
	if resolved_extension_ids == _session_mode_extension_ids and resolved_risk_modifier_ids == _session_risk_modifier_ids:
		return
	_session_mode_extension_ids = resolved_extension_ids
	_session_risk_modifier_ids = resolved_risk_modifier_ids
	_set_all_ready_false()
	_rpc_sync_mode_extensions.rpc(_session_mode_extension_ids, _session_risk_modifier_ids)
	_broadcast_roster()
	session_state_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_mode_extensions(extension_ids: Array, risk_modifier_ids: Array) -> void:
	## 客户端接收房主的模式扩展权威配置；收到后再次校验稳定 ID 与当前骇入模式兼容性。
	# 规范化配置；网络消息不直接信任，避免异常 ID 写入本地会话。
	var sanitized_configuration: Dictionary = ModeExtensionRules.sanitize_configuration(extension_ids, risk_modifier_ids, _session_hack_variant)
	_session_mode_extension_ids = _to_string_array(sanitized_configuration.get("extension_ids", []))
	_session_risk_modifier_ids = _to_string_array(sanitized_configuration.get("risk_modifier_ids", []))
	session_state_changed.emit()


func get_session_hack_variant() -> String:
	## 返回当前联机骇入模式标识；联机面板下拉框与开局流程共用该查询。
	return _session_hack_variant


func get_session_mode_extension_ids() -> Array[String]:
	## 返回当前联机模式扩展 ID 副本；联机界面和开局流程不得直接改写内部数组。
	return _session_mode_extension_ids.duplicate()


func get_session_risk_modifier_ids() -> Array[String]:
	## 返回当前联机风险合约词条 ID 副本；未启用风险合约时为空。
	return _session_risk_modifier_ids.duplicate()


func get_session_mode_extension_summary() -> String:
	## 返回适合房间界面展示的模式扩展摘要；未启用时明确显示“未开启”。
	return ModeExtensionRules.get_configuration_summary(_session_mode_extension_ids, _session_risk_modifier_ids)


func get_protocol_version() -> int:
	## 返回当前联机会话协议版本；房间列表据此禁用无法安全解析模式扩展字段的旧版本房间。
	return PROTOCOL_VERSION


func get_session_combat_mode() -> String:
	## 返回当前联机战斗模式标识；组队面板与 GameWorld 共用该查询。
	return _session_combat_mode


func is_battle_royale_mode() -> bool:
	## 返回当前是否为大逃杀模式；GameWorld 据此启用分散出生与玩家互伤。
	return _session_combat_mode == COMBAT_MODE_BATTLE_ROYALE


func _submit_local_profile() -> void:
	## 把本机昵称与当前角色提交进名册；主机直接写入，客户端通过 RPC 发给主机。
	if _session_state == SESSION_STATE_HOSTING:
		if _roster.has(1):
			# 主机既有准备状态；重新提交档案时保留，避免改名导致准备被动取消。
			var host_ready: bool = bool((_roster[1] as Dictionary).get("ready", false))
			_roster[1] = _build_local_profile(host_ready)
			_broadcast_roster()
		return
	if _session_state == SESSION_STATE_JOINED:
		# 本机名册快照；保留已提交的准备状态，档案更新不重置准备。
		var local_ready: bool = is_local_ready()
		_rpc_submit_profile.rpc_id(1, _build_local_profile(local_ready))


func _build_local_profile(ready: bool) -> Dictionary:
	## 构造本机成员档案；角色标识实时读取 SessionState，保证联机队友看到最新选择。
	return {
		"name": _local_player_name,
		"character_id": _get_local_character_id(),
		"ready": ready,
	}


func _get_local_character_id() -> String:
	# 会话状态服务；提供当前已确认角色标识，缺失时回退星。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state != null and session_state.has_method("get_selected_character_id"):
		return str(session_state.call("get_selected_character_id"))
	return "stelle"


func _broadcast_roster() -> void:
	## 主机把权威名册广播给全部客户端并刷新本地界面；客户端不调用本函数。
	if _session_state != SESSION_STATE_HOSTING:
		return
	_rpc_sync_roster.rpc(_roster.duplicate(true))
	roster_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit_profile(profile: Dictionary) -> void:
	## 主机接收成员档案提交；容量已满或非主机身份时忽略请求。
	if _session_state != SESSION_STATE_HOSTING:
		return
	# 提交方 peer_id；由多人接口提供，0 表示异常来源直接忽略。
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		return
	if not _roster.has(sender_peer_id) and _roster.size() >= MAX_PLAYERS:
		return
	# 该成员是否首次进入名册；新成员需要补发当前战斗模式，保证晚加入者界面一致。
	var is_new_member: bool = not _roster.has(sender_peer_id)
	_roster[sender_peer_id] = {
		"name": str(profile.get("name", "玩家")).strip_edges(),
		"character_id": str(profile.get("character_id", "stelle")),
		"ready": bool(profile.get("ready", false)),
	}
	_broadcast_roster()
	if is_new_member:
		_rpc_sync_combat_mode.rpc_id(sender_peer_id, _session_combat_mode)
		# 新成员骇入模式补发；保证晚加入者的骇入模式下拉框与主机当前选择一致。
		_rpc_sync_hack_variant.rpc_id(sender_peer_id, _session_hack_variant)
		# 新成员模式扩展补发；必须在骇入模式之后发送，使客户端按正确兼容条件校验风险合约。
		_rpc_sync_mode_extensions.rpc_id(sender_peer_id, _session_mode_extension_ids, _session_risk_modifier_ids)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_roster(roster_snapshot: Dictionary) -> void:
	## 客户端接收主机名册快照；字典键经网络传输后统一转回整数 peer_id。
	_roster.clear()
	for raw_peer_id in roster_snapshot.keys():
		_roster[int(raw_peer_id)] = roster_snapshot[raw_peer_id]
	roster_changed.emit()


# ---------------------------------------------------------------------------
# 统一开局
# ---------------------------------------------------------------------------

func request_start_combat() -> bool:
	## 主机请求全员进入正式骇入；要求全员准备完毕，成功后广播共享种子并统一切场景。
	if _session_state != SESSION_STATE_HOSTING or _combat_session_active:
		return false
	if not is_everyone_ready():
		return false
	# 共享地图种子；取非零随机整数，全员用同一种子复现地图、宝箱与物资撤离点。
	var shared_seed: int = int(randi()) | 1
	_rpc_begin_combat.rpc(shared_seed, _session_combat_mode, _session_hack_variant, _session_mode_extension_ids, _session_risk_modifier_ids)
	_rpc_begin_combat(shared_seed, _session_combat_mode, _session_hack_variant, _session_mode_extension_ids, _session_risk_modifier_ids)
	return true


@rpc("authority", "call_remote", "reliable")
func _rpc_begin_combat(shared_seed: int, combat_mode: String, hack_variant: String = "standard", extension_ids: Array = [], risk_modifier_ids: Array = []) -> void:
	## 接收主机统一开局指令；写入共享种子、战斗模式与骇入模式后经全局过渡切入战斗场景。
	## 模式扩展补充：开局指令同时携带扩展与风险词条，作为全员本局配置的最终权威。
	if _is_local_scene_busy():
		return
	_shared_map_seed = shared_seed
	_session_combat_mode = COMBAT_MODE_BATTLE_ROYALE if combat_mode == COMBAT_MODE_BATTLE_ROYALE else COMBAT_MODE_TEAM
	# 开局骇入模式；开局指令携带的值为最终权威，防止同步消息与开局指令乱序导致模式不一致。
	_session_hack_variant = HackModeRules.normalize_variant(hack_variant)
	# 开局模式扩展配置；与开局骇入模式一起重新校验，作为所有客户端本局规则的最终权威。
	var sanitized_configuration: Dictionary = ModeExtensionRules.sanitize_configuration(extension_ids, risk_modifier_ids, _session_hack_variant)
	_session_mode_extension_ids = _to_string_array(sanitized_configuration.get("extension_ids", []))
	_session_risk_modifier_ids = _to_string_array(sanitized_configuration.get("risk_modifier_ids", []))
	_combat_session_active = true
	_set_all_ready_false()
	# 会话状态服务；开局统一写入正式骇入模式与主机选择的骇入模式变体，当前角色保持各自选择。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state != null and session_state.has_method("set_game_mode"):
		session_state.call("set_game_mode", GAME_MODE_HACK)
	if session_state != null and session_state.has_method("set_hack_variant"):
		session_state.call("set_hack_variant", _session_hack_variant)
	if session_state != null and session_state.has_method("configure_mode_extensions"):
		session_state.call("configure_mode_extensions", _session_mode_extension_ids, _session_risk_modifier_ids)
	combat_session_started.emit()
	roster_changed.emit()
	# 全局场景过渡服务；与单机入口使用同一 0.3 秒黑屏过渡进入战斗。
	var scene_transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_to_file"):
		scene_transition.call("change_scene_to_file", GAME_WORLD_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(GAME_WORLD_SCENE_PATH)


func _is_local_scene_busy() -> bool:
	## 判断本机是否正处于战斗场景或场景过渡中；忙碌时忽略开局指令，避免把正在单机作战的成员强行拉入联机局。
	# 当前场景节点；启动早期可能为空，此时视为不忙碌。
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path == GAME_WORLD_SCENE_PATH:
		return true
	# 全局场景过渡服务；正在黑屏切换时不重复触发新的场景加载。
	var scene_transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	return scene_transition != null and scene_transition.has_method("is_transitioning") and bool(scene_transition.call("is_transitioning"))


func _set_all_ready_false() -> void:
	## 开局后清空全员准备状态；返回菜单后需要重新准备才能开下一局。
	for peer_id in _roster.keys():
		# 单个成员档案；名册值固定为字典，逐个复位准备位。
		var member_profile: Dictionary = _roster[peer_id] as Dictionary
		member_profile["ready"] = false


func notify_combat_scene_exited() -> void:
	## 战斗同步器离开场景树时调用；本机战斗会话结束，网络连接与名册保持不变。
	_combat_session_active = false
	session_state_changed.emit()


# ---------------------------------------------------------------------------
# 战斗同步消息通道
# ---------------------------------------------------------------------------

func broadcast_combat_message(payload: Dictionary, reliable: bool = true) -> void:
	## 把战斗同步消息发给全部远程成员；reliable 为 false 时使用不可靠有序通道传输高频状态。
	if multiplayer.multiplayer_peer == null or _session_state == SESSION_STATE_IDLE:
		return
	if reliable:
		_rpc_receive_combat_message_reliable.rpc(payload)
	else:
		_rpc_receive_combat_message_unreliable.rpc(payload)


func send_combat_message(target_peer_id: int, payload: Dictionary, reliable: bool = true) -> void:
	## 把战斗同步消息定向发给单个成员；用于拾取仲裁答复与伤害转发。
	if multiplayer.multiplayer_peer == null or target_peer_id <= 0:
		return
	if reliable:
		_rpc_receive_combat_message_reliable.rpc_id(target_peer_id, payload)
	else:
		_rpc_receive_combat_message_unreliable.rpc_id(target_peer_id, payload)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_receive_combat_message_reliable(payload: Dictionary) -> void:
	combat_message_received.emit(multiplayer.get_remote_sender_id(), payload)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_receive_combat_message_unreliable(payload: Dictionary) -> void:
	combat_message_received.emit(multiplayer.get_remote_sender_id(), payload)


# ---------------------------------------------------------------------------
# 局域网房间发现
# ---------------------------------------------------------------------------

func set_room_discovery_active(active: bool) -> void:
	## 开关房间探测；联机面板显示房间列表时开启，面板关闭或已入房时关闭以停止广播。
	if _discovery_active == active:
		return
	_discovery_active = active
	if active:
		_discovery_client_socket = PacketPeerUDP.new()
		# 探测套接字绑定结果；绑定任意可用端口用于接收主机回复。
		var bind_error: int = _discovery_client_socket.bind(0)
		if bind_error != OK:
			_discovery_client_socket = null
			_discovery_active = false
			return
		_discovery_client_socket.set_broadcast_enabled(true)
		_discovery_probe_remaining = 0.0
		_discovered_rooms.clear()
		discovered_rooms_changed.emit()
		return
	if _discovery_client_socket != null:
		_discovery_client_socket.close()
		_discovery_client_socket = null
	_discovered_rooms.clear()
	discovered_rooms_changed.emit()


func get_discovered_rooms() -> Array[Dictionary]:
	## 返回当前有效的已发现房间列表副本；按主机 IP 排序保证列表顺序稳定。
	# 房间列表结果；元素为房间信息字典副本，调用方只读展示。
	var rooms: Array[Dictionary] = []
	for room_key in _discovered_rooms.keys():
		rooms.append((_discovered_rooms[room_key] as Dictionary).duplicate())
	rooms.sort_custom(func(left_room: Dictionary, right_room: Dictionary) -> bool: return str(left_room.get("ip", "")) < str(right_room.get("ip", "")))
	return rooms


func _start_discovery_server() -> void:
	## 主机开始监听房间探测请求；端口被占用时房间仍可用，但只能通过直连 IP 加入。
	_stop_discovery_server()
	_discovery_server_socket = PacketPeerUDP.new()
	# 发现端口绑定结果；同机多开时后启动实例绑定失败，属于可接受的降级。
	var bind_error: int = _discovery_server_socket.bind(DISCOVERY_PORT)
	if bind_error != OK:
		_discovery_server_socket = null


func _stop_discovery_server() -> void:
	if _discovery_server_socket != null:
		_discovery_server_socket.close()
		_discovery_server_socket = null


func _poll_discovery_server() -> void:
	## 主机轮询探测请求；对每个合法请求回复一份房间信息 JSON。
	if _discovery_server_socket == null or _session_state != SESSION_STATE_HOSTING:
		return
	while _discovery_server_socket.get_available_packet_count() > 0:
		# 请求原始内容；按 UTF-8 文本解析，无法解析的数据包直接跳过。
		var request_text: String = _discovery_server_socket.get_packet().get_string_from_utf8()
		# 请求来源地址与端口；必须在读取数据包之后获取，回复直接发回该来源。
		var request_ip: String = _discovery_server_socket.get_packet_ip()
		var request_port: int = _discovery_server_socket.get_packet_port()
		if request_text != DISCOVERY_REQUEST_MAGIC or request_ip.is_empty():
			continue
		# 房间信息回复；包含魔法头、协议版本、房间名与人数，客户端据此展示可加入房间。
		var reply_payload: Dictionary = {
			"magic": DISCOVERY_REPLY_MAGIC,
			"version": PROTOCOL_VERSION,
			"room_name": "%s 的房间" % _local_player_name,
			"player_count": _roster.size(),
			"max_players": MAX_PLAYERS,
			"in_combat": _combat_session_active,
			"mode": _session_combat_mode,
			"hack_variant": _session_hack_variant,
			"mode_extensions": _session_mode_extension_ids,
			"risk_modifiers": _session_risk_modifier_ids,
		}
		_discovery_server_socket.set_dest_address(request_ip, request_port)
		_discovery_server_socket.put_packet(JSON.stringify(reply_payload).to_utf8_buffer())


func _poll_discovery_client(delta: float) -> void:
	## 客户端周期广播探测请求并接收回复；同时清理超时房间条目。
	if not _discovery_active or _discovery_client_socket == null:
		return
	_discovery_probe_remaining -= delta
	if _discovery_probe_remaining <= 0.0:
		_discovery_probe_remaining = DISCOVERY_PROBE_INTERVAL
		_discovery_client_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
		_discovery_client_socket.put_packet(DISCOVERY_REQUEST_MAGIC.to_utf8_buffer())
	# 房间列表是否发生变化；新增、更新或过期任一情况都会派发刷新信号。
	var rooms_changed: bool = false
	while _discovery_client_socket.get_available_packet_count() > 0:
		# 回复原始文本；主机以 JSON 编码房间信息。
		var reply_text: String = _discovery_client_socket.get_packet().get_string_from_utf8()
		# 回复来源 IP；作为加入目标与房间表键的一部分。
		var reply_ip: String = _discovery_client_socket.get_packet_ip()
		# 回复解析结果；非法 JSON 或缺失魔法头的数据包直接忽略。
		var parsed_reply: Variant = JSON.parse_string(reply_text)
		if not (parsed_reply is Dictionary):
			continue
		# 回复内容字典；校验魔法头后写入或更新房间表。
		var reply_payload: Dictionary = parsed_reply as Dictionary
		if str(reply_payload.get("magic", "")) != DISCOVERY_REPLY_MAGIC:
			continue
		_discovered_rooms[reply_ip] = {
			"ip": reply_ip,
			"room_name": str(reply_payload.get("room_name", "未命名房间")),
			"player_count": int(reply_payload.get("player_count", 0)),
			"max_players": int(reply_payload.get("max_players", MAX_PLAYERS)),
			"version": int(reply_payload.get("version", 0)),
			"in_combat": bool(reply_payload.get("in_combat", false)),
			"mode": str(reply_payload.get("mode", COMBAT_MODE_TEAM)),
			"hack_variant": HackModeRules.normalize_variant(str(reply_payload.get("hack_variant", HackModeRules.VARIANT_STANDARD))),
			"mode_extensions": _to_string_array(reply_payload.get("mode_extensions", [])),
			"risk_modifiers": _to_string_array(reply_payload.get("risk_modifiers", [])),
			"last_seen": Time.get_ticks_msec() * 0.001,
		}
		rooms_changed = true
	# 当前时间戳；单位秒，用于清理超过存活时长未刷新的房间。
	var current_time_seconds: float = Time.get_ticks_msec() * 0.001
	for room_key in _discovered_rooms.keys().duplicate():
		if current_time_seconds - float((_discovered_rooms[room_key] as Dictionary).get("last_seen", 0.0)) > DISCOVERED_ROOM_TIMEOUT:
			_discovered_rooms.erase(room_key)
			rooms_changed = true
	if rooms_changed:
		discovered_rooms_changed.emit()


# ---------------------------------------------------------------------------
# 多人接口回调
# ---------------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	## 新成员建立连接；主机等待其档案提交，客户端无需处理其他成员的底层连接事件。
	if _session_state != SESSION_STATE_HOSTING:
		return
	if _roster.size() >= MAX_PLAYERS or _combat_session_active:
		# 超员或战局进行中拒绝加入；直接断开新连接，不影响现有成员。
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	## 成员断开连接；主机把其移出名册并广播，战斗内的实体清理由 NetworkCombatSync 消费名册变化。
	if _session_state == SESSION_STATE_HOSTING and _roster.has(peer_id):
		_roster.erase(peer_id)
		_broadcast_roster()


func _on_connected_to_server() -> void:
	## 客户端与主机握手成功；提交本机档案进入名册。
	_session_state = SESSION_STATE_JOINED
	_rpc_submit_profile.rpc_id(1, _build_local_profile(false))
	set_room_discovery_active(false)
	session_state_changed.emit()


func _on_connection_failed() -> void:
	## 客户端与主机握手失败；复位为闲置状态并通知界面。
	multiplayer.multiplayer_peer = null
	_reset_session_state()
	connection_failed.emit("连接主机失败，请确认对方已创建房间")
	session_state_changed.emit()


func _on_server_disconnected() -> void:
	## 主机关闭或网络中断；客户端复位状态，战斗内表现由 NetworkCombatSync 按主机离开规则处理。
	multiplayer.multiplayer_peer = null
	_reset_session_state()
	disconnected_from_host.emit("与主机的连接已断开")
	session_state_changed.emit()
	roster_changed.emit()


# ---------------------------------------------------------------------------
# 状态查询
# ---------------------------------------------------------------------------

func is_session_active() -> bool:
	## 返回本机是否处于任一联机会话（主机或已加入）；加入握手期不算已建立。
	return _session_state == SESSION_STATE_HOSTING or _session_state == SESSION_STATE_JOINED


func is_session_host() -> bool:
	return _session_state == SESSION_STATE_HOSTING


func is_joining() -> bool:
	return _session_state == SESSION_STATE_JOINING


func is_combat_session_active() -> bool:
	## 返回联机战斗是否进行中；GameWorld 在 ready 时据此进入联机模式。
	return is_session_active() and _combat_session_active


func get_shared_map_seed() -> int:
	return _shared_map_seed


func get_local_peer_id() -> int:
	## 返回本机 peer_id；未联机时返回 0，主机固定为 1。
	if multiplayer.multiplayer_peer == null or not is_session_active():
		return 0
	return multiplayer.get_unique_id()


func get_local_player_name() -> String:
	return _local_player_name


func is_local_ready() -> bool:
	## 返回本机在名册中的准备状态；名册尚未同步到本机时返回 false。
	# 本机名册条目；主机为 1 号，客户端按自身 peer_id 查找。
	var local_profile: Variant = _roster.get(get_local_peer_id())
	return bool((local_profile as Dictionary).get("ready", false)) if local_profile is Dictionary else false


func is_everyone_ready() -> bool:
	## 返回是否全员准备完毕；至少需要 2 名成员才允许联机开局。
	if _roster.size() < 2:
		return false
	for peer_id in _roster.keys():
		if not bool((_roster[peer_id] as Dictionary).get("ready", false)):
			return false
	return true


func get_roster_snapshot() -> Array[Dictionary]:
	## 返回名册展示快照；元素附带 peer_id 并按 peer_id 升序，供联机面板与战斗同步共用。
	# 名册快照结果；元素为包含 peer_id、name、character_id、ready 的字典。
	var snapshot: Array[Dictionary] = []
	# 名册 peer_id 有序列表；主机 1 号固定排在最前。
	var sorted_peer_ids: Array = _roster.keys()
	sorted_peer_ids.sort()
	for peer_id in sorted_peer_ids:
		# 单个成员档案；复制后附加 peer_id 字段，避免调用方改写名册。
		var member_profile: Dictionary = (_roster[peer_id] as Dictionary).duplicate()
		member_profile["peer_id"] = int(peer_id)
		snapshot.append(member_profile)
	return snapshot


func get_remote_peer_ids() -> Array[int]:
	## 返回除本机外的全部成员 peer_id；战斗同步据此创建远程队友化身。
	# 远程成员结果列表；未联机时为空。
	var remote_peer_ids: Array[int] = []
	# 本机 peer_id；用于从名册中排除自己。
	var local_peer_id: int = get_local_peer_id()
	for peer_id in _roster.keys():
		if int(peer_id) != local_peer_id:
			remote_peer_ids.append(int(peer_id))
	remote_peer_ids.sort()
	return remote_peer_ids


func get_peer_display_name(peer_id: int) -> String:
	## 返回指定成员的展示昵称；名册缺失时回退“玩家#编号”。
	# 成员档案条目；断线成员可能已被移出名册。
	var member_profile: Variant = _roster.get(peer_id)
	if member_profile is Dictionary:
		return str((member_profile as Dictionary).get("name", "玩家#%d" % peer_id))
	return "玩家#%d" % peer_id


func get_peer_character_id(peer_id: int) -> String:
	## 返回指定成员的角色标识；名册缺失时回退星，仅影响化身配色与标签。
	# 成员档案条目；值为字典时读取角色字段。
	var member_profile: Variant = _roster.get(peer_id)
	if member_profile is Dictionary:
		return str((member_profile as Dictionary).get("character_id", "stelle"))
	return "stelle"


func _to_string_array(raw_values: Variant) -> Array[String]:
	## 把本地或网络传入的普通数组转换为强类型字符串数组；非数组输入返回空列表。
	# 转换结果；逐项转为字符串，保留原顺序供规则表继续规范化。
	var result: Array[String] = []
	if not (raw_values is Array):
		return result
	for raw_value in raw_values:
		result.append(str(raw_value))
	return result


func _get_default_player_name() -> String:
	## 返回默认昵称；优先系统用户名，取不到时使用固定中文名。
	# 系统用户名；Windows 从 USERNAME 环境变量读取。
	var system_user_name: String = OS.get_environment("USERNAME")
	if system_user_name.is_empty():
		system_user_name = OS.get_environment("USER")
	return system_user_name if not system_user_name.is_empty() else "星穹骇客"
