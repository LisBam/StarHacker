extends LobbyWorld
class_name MultiplayerLobbyWorld

## 联机大厅在主大厅组合结构之上增加三项能力：进场自动打开联机面板、左上角“联机设置”入口与房间成员共同在场。
## 大厅玩法约束与主大厅一致：不创建敌人、掉落、撤离或战斗结算；成员在场表现由 NetworkLobbySync 驱动的远程队友化身提供，纯展示不可被攻击。

## 联机大厅在场同步器脚本；进场时动态创建，未加入房间时同步器保持空转不发包。
const NETWORK_LOBBY_SYNC_SCRIPT: Script = preload("res://scripts/game/network_lobby_sync.gd")
## 联机面板的大厅动作标识；与主菜单 perform_lobby_action 注册的联机入口保持一致。
const LOBBY_ACTION_MULTIPLAYER: String = "multiplayer"

## 联机大厅在场同步器实例；默认 null，在 ready 阶段创建并常驻本场景。
var _network_lobby_sync: Node2D = null


func _ready() -> void:
	super._ready()
	if _lobby_hud != null and _lobby_hud.has_method("set_lobby_title"):
		_lobby_hud.call("set_lobby_title", "联机大厅")
	if _lobby_hud != null and _lobby_hud.has_signal("network_settings_requested"):
		_lobby_hud.connect("network_settings_requested", Callable(self, "_on_network_settings_requested"))
	_create_network_lobby_sync()
	# 进场自动打开联机面板；延迟一帧确保宿主菜单完成 ready 与遮罩构建，面板打开会经聚合信号锁定玩家控制。
	# 入房免打扰补充；已在联机房间内时进场不再自动弹出面板（玩家经切换按钮往返大厅与菜单），左上角“联机设置”仍可随时打开。
	if not _is_network_session_active():
		call_deferred("_open_network_panel")


func _is_network_session_active() -> bool:
	## 查询本机是否已处于联机房间（主机或已加入）；会话服务缺失时按未入房处理。
	# 联机会话服务；AutoLoad 常驻，场景切换不会中断连接。
	var network_session: Node = get_tree().root.get_node_or_null("NetworkSession")
	return network_session != null and network_session.has_method("is_session_active") and bool(network_session.call("is_session_active"))


func _open_network_panel() -> void:
	## 打开宿主菜单的联机面板；进场自动弹出与左上角联机设置按钮共用本入口。
	if _main_menu_panel_host != null and _main_menu_panel_host.has_method("perform_lobby_action"):
		_main_menu_panel_host.call("perform_lobby_action", LOBBY_ACTION_MULTIPLAYER)


func _on_network_settings_requested() -> void:
	## 左上角“联机设置”按钮回调；已有面板打开时忽略，避免重复叠加遮罩。
	if _is_modal_open:
		return
	_open_network_panel()


func _create_network_lobby_sync() -> void:
	## 创建大厅在场同步器；同步器只做玩家状态互播与化身展示，加入或创建房间后立即开始工作。
	_network_lobby_sync = NETWORK_LOBBY_SYNC_SCRIPT.new() as Node2D
	if _network_lobby_sync == null:
		return
	_network_lobby_sync.name = "NetworkLobbySync"
	add_child(_network_lobby_sync)
	_network_lobby_sync.call("initialize", self, _player)
