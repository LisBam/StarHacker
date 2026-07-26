extends Node2D
class_name NetworkCombatSync

## 战斗网络同步器是联机骇入局内的唯一实体复制协调者，由 GameWorld 在联机模式下动态创建。
## 职责划分：队友化身状态互播（全员对等）、敌人主机权威复制（主机产出、客户端傀儡）、伤害双向转发、掉落物创建广播与拾取仲裁、宝箱开启仲裁与事件提示。
## 地图、宝箱布点与撤离点依靠共享种子在各端确定性复现，不经网络传输；本节点只同步运行期动态状态。

## 同步器节点组名；WeaponDrop 与 RangedMonster 通过该组查找当前局内同步器，避免硬编码节点路径。
const SYNC_GROUP: StringName = &"network_combat_sync"
## 队友状态广播间隔；单位秒，默认 0.05 即 20Hz，兼顾局域网带宽与位置平滑度。
const PLAYER_STATE_INTERVAL: float = 0.05
## 敌人快照广播间隔；单位秒，默认 0.1 即 10Hz，傀儡端用插值补足视觉平滑。
const ENEMY_STATE_INTERVAL: float = 0.1
## 单条敌人快照消息的最大条目数；超出后拆分多条，控制单包体积在常见 MTU 之内，避免不可靠通道分片丢包。
const ENEMY_STATE_CHUNK_SIZE: int = 16
## 客户端拾取仲裁超时；单位秒，超时未收到主机答复则清理挂起记录，掉落物以主机移除广播为准。
const PICKUP_PENDING_TIMEOUT: float = 2.0
## 队友化身配色表；按名册顺序循环取用，第一名成员与本地玩家默认体色一致。
const AVATAR_COLOR_PALETTE: Array[Color] = [
	Color(0.407843, 0.792157, 1.0, 1.0),
	Color(1.0, 0.62, 0.25, 1.0),
	Color(0.75, 0.55, 1.0, 1.0),
	Color(0.45, 0.9, 0.55, 1.0),
]
## 远程队友化身脚本；纯代码构建外观，创建后由本同步器驱动状态。
const REMOTE_PLAYER_AVATAR_SCRIPT: Script = preload("res://scripts/player/remote_player_avatar.gd")
## 网络伤害代理脚本；本机重建远程伤害来源数值后走本地标准受击流程。
const NETWORK_DAMAGE_PROXY_SCRIPT: Script = preload("res://scripts/game/network_damage_proxy.gd")
## 敌方弹体场景；客户端按主机广播生成纯视觉弹体，保留近战可清除层。
const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/enemy_projectile.tscn")
## 远程弹体视觉场景路径白名单前缀；只允许实例化弹体目录下的场景，防止异常消息加载任意资源。
const REMOTE_PROJECTILE_PATH_PREFIX: String = "res://scenes/projectiles/"
## 全局窗口样式指南；观战切换按钮复用主要按钮语义配色，与局外面板保持一致。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 观战镜头跟随速率；数值越大跟随越紧，默认 8 在化身插值之上再叠加一层平滑形成柔和观战移动。
const SPECTATOR_CAMERA_FOLLOW_RATE: float = 8.0

## 联机会话服务缓存；由初始化时从 AutoLoad 解析，本节点全部收发都经过它。
var _network_session: Node = null
## 战斗世界缓存；用于调用掉落生成、宝箱释放执行与撤离等公开接口。
var _game_world: Node2D = null
## 本地玩家节点缓存；状态采样与远程伤害落地的目标。
var _player: Node2D = null
## 本地玩家战斗属性组件缓存；读取生命与死亡状态。
var _player_stats_component: Node = null
## 本地玩家护盾组件缓存；读取当前护盾值用于状态广播。
var _player_shield_component: Node = null
## 怪物挂载父节点缓存；主机扫描真实敌人、客户端挂载傀儡敌人共用。
var _monster_parent: Node = null
## 怪物加载管理器缓存；主机把队友化身注册为额外物化锚点并订阅死亡信号。
var _monster_simulation_manager: Node = null
## 本机是否为主机；初始化时由会话服务确定，决定敌人权威与仲裁职责。
var _is_host: bool = false
## 主机是否仍在战局中；主机离开后客户端降级为本地仲裁，不再等待主机答复。
var _host_available: bool = true
## 队友化身表；键为 peer_id，值为 RemotePlayerAvatar 节点。
var _remote_avatars: Dictionary = {}
## 已离开本局的成员集合；键为 peer_id，用于忽略离场成员的滞后状态包。
var _departed_peer_ids: Dictionary = {}
## 队友状态广播剩余时间；归零后采样本地玩家并广播。
var _player_state_remaining: float = 0.0
## 敌人快照广播剩余时间；仅主机使用，归零后扫描并广播敌人状态。
var _enemy_state_remaining: float = 0.0
## 主机敌人网络编号表；键为怪物节点实例 ID，值为网络编号。
var _host_enemy_ids_by_instance: Dictionary = {}
## 主机敌人节点表；键为网络编号，值为怪物节点。
var _host_enemy_nodes_by_id: Dictionary = {}
## 下一个敌人网络编号；主机单调递增分配，本局内稳定。
var _next_enemy_network_id: int = 1
## 已广播死亡的敌人编号集合；主机用于区分死亡移除与休眠移除。
var _host_dead_enemy_ids: Dictionary = {}
## 最近一次网络伤害击杀归属表；键为敌人网络编号，值为攻击方 peer_id，用于死亡广播附带击杀者。
var _last_network_damage_peer_by_enemy_id: Dictionary = {}
## 客户端傀儡敌人表；键为敌人网络编号，值为傀儡怪物节点。
var _puppet_enemies_by_id: Dictionary = {}
## 客户端傀儡场景缓存；键为场景路径，值为 PackedScene，避免重复加载。
var _puppet_scene_cache: Dictionary = {}
## 客户端已知全图敌人人口；来自主机快照头，供 HUD 人口显示。
var _replicated_population_count: int = 0
## 掉落物节点表；键为掉落网络编号，值为 WeaponDrop 节点。
var _drop_nodes_by_id: Dictionary = {}
## 主机存活掉落编号集合；键为掉落网络编号，仲裁时判断是否仍可拾取。
var _host_alive_drop_ids: Dictionary = {}
## 下一个本机掉落序号；与 peer_id 组合成全局唯一掉落编号。
var _next_local_drop_sequence: int = 1
## 正在应用的远程掉落编号；非空时本机掉落生成钩子只登记不再广播，防止复制回环。
var _applying_remote_drop_id: String = ""
## 拾取仲裁旁路开关；同步器代持拾取执行时置 true，使掉落物走原始本地拾取流程。
var _pickup_bypass_active: bool = false
## 客户端挂起拾取表；键为掉落编号，值为包含 drop、inventory、elapsed 的字典。
var _pending_pickups: Dictionary = {}
## 已认领宝箱集合；键为宝箱位置键，主机用于保证同一宝箱只出一次货。
var _claimed_chest_keys: Dictionary = {}
## 网络伤害代理节点；复用单实例，每次转发前重新配置数值。
var _damage_proxy: Node2D = null
## 事件提示画布层；承载“队友倒下/离开”等短暂提示文本。
var _toast_canvas_layer: CanvasLayer = null
## 事件提示容器；提示按创建顺序自上而下排列并自动淡出。
var _toast_container: VBoxContainer = null
## 远程弹体视觉场景缓存；键为场景路径，值为 PackedScene。
var _remote_projectile_scene_cache: Dictionary = {}
## 本机是否已广播离场事件；离场事件只广播一次，撤离与退出共用。
var _departure_broadcasted: bool = false
## 观战模式是否激活；本机死亡且仍有存活队友时置 true，期间死亡结算被推迟。
var _spectator_active: bool = false
## 当前观战目标成员 peer_id；0 表示无目标，目标死亡或离场时自动切换。
var _spectator_target_peer_id: int = 0
## 观战镜头节点；懒创建并复用，观战期间设为当前相机并平滑跟随目标化身。
var _spectator_camera: Camera2D = null
## 观战界面画布层；承载目标横幅、左右切换箭头与结算退出按钮，懒创建并按观战状态显隐。
var _spectator_layer: CanvasLayer = null
## 观战目标横幅标签；显示当前被观战成员的昵称与角色。
var _spectator_banner_label: Label = null
## 观战结束回调；由战斗 HUD 在推迟死亡结算时注入，观战结束后调用以恢复原死亡结算流程。
var _spectator_finished_callback: Callable = Callable()


func initialize(game_world: Node2D, player: Node2D, monster_parent: Node, monster_simulation_manager: Node) -> void:
	## 由 GameWorld 在联机模式下调用一次；解析会话服务、组件引用并完成主客户端分工初始化。
	_game_world = game_world
	_player = player
	_monster_parent = monster_parent
	_monster_simulation_manager = monster_simulation_manager
	_network_session = get_tree().root.get_node_or_null("NetworkSession")
	if _network_session == null:
		return
	_is_host = bool(_network_session.call("is_session_host"))
	_host_available = true
	add_to_group(SYNC_GROUP)
	# 同步器必须无视暂停持续运行；联机模式下战斗界面不暂停场景树，此设置作为额外保险。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_network_session.connect("combat_message_received", Callable(self, "_on_combat_message_received"))
	_network_session.connect("roster_changed", Callable(self, "_on_roster_changed"))
	_network_session.connect("disconnected_from_host", Callable(self, "_on_disconnected_from_host"))
	if _player != null:
		_player_stats_component = _player.get_node_or_null("StatsComponent")
		_player_shield_component = _player.get_node_or_null("ShieldComponent")
		_connect_local_fire_signals()
		if _player_stats_component != null and _player_stats_component.has_signal("died"):
			_player_stats_component.connect("died", Callable(self, "_on_local_player_died"))
	# 网络伤害代理；作为同步器子节点常驻复用，不参与目标查询组。
	_damage_proxy = NETWORK_DAMAGE_PROXY_SCRIPT.new() as Node2D
	_damage_proxy.name = "NetworkDamageProxy"
	add_child(_damage_proxy)
	_build_toast_layer()
	_rebuild_remote_avatars()
	if _is_host and _monster_simulation_manager != null and _monster_simulation_manager.has_signal("virtual_monster_died"):
		_monster_simulation_manager.connect("virtual_monster_died", Callable(self, "_on_host_monster_died"))


func _exit_tree() -> void:
	## 离开战斗场景时广播离场事件并结束本机战斗会话；网络连接与队伍名册保持，可回到菜单直接开下一局。
	_broadcast_local_departure()
	if _network_session != null:
		if _network_session.is_connected("combat_message_received", Callable(self, "_on_combat_message_received")):
			_network_session.disconnect("combat_message_received", Callable(self, "_on_combat_message_received"))
		if _network_session.is_connected("roster_changed", Callable(self, "_on_roster_changed")):
			_network_session.disconnect("roster_changed", Callable(self, "_on_roster_changed"))
		if _network_session.is_connected("disconnected_from_host", Callable(self, "_on_disconnected_from_host")):
			_network_session.disconnect("disconnected_from_host", Callable(self, "_on_disconnected_from_host"))
		if _network_session.has_method("notify_combat_scene_exited"):
			_network_session.call("notify_combat_scene_exited")


func _process(delta: float) -> void:
	_player_state_remaining -= delta
	if _player_state_remaining <= 0.0:
		_player_state_remaining = PLAYER_STATE_INTERVAL
		_broadcast_local_player_state()
	if _is_host:
		_enemy_state_remaining -= delta
		if _enemy_state_remaining <= 0.0:
			_enemy_state_remaining = ENEMY_STATE_INTERVAL
			_host_scan_and_broadcast_enemies()
	_update_pending_pickups(delta)
	_update_spectator_state(delta)


# ---------------------------------------------------------------------------
# 队友化身
# ---------------------------------------------------------------------------

func _rebuild_remote_avatars() -> void:
	## 按当前名册补齐缺失的队友化身；断线成员由名册变化回调移除，离场成员由事件移除。
	if _network_session == null:
		return
	# 名册展示快照；顺序稳定，用于确定每名成员的配色下标。
	var roster_snapshot: Array[Dictionary] = _network_session.call("get_roster_snapshot")
	# 本机 peer_id；跳过为自己创建化身。
	var local_peer_id: int = int(_network_session.call("get_local_peer_id"))
	for member_index in range(roster_snapshot.size()):
		# 单个成员档案；包含 peer_id、昵称与角色标识。
		var member_profile: Dictionary = roster_snapshot[member_index]
		# 成员 peer_id；已有化身或已离场成员跳过。
		var member_peer_id: int = int(member_profile.get("peer_id", 0))
		if member_peer_id == local_peer_id or member_peer_id <= 0:
			continue
		if _remote_avatars.has(member_peer_id) or _departed_peer_ids.has(member_peer_id):
			continue
		_create_remote_avatar(member_peer_id, member_profile, member_index)
	_refresh_simulation_anchor_nodes()


func _create_remote_avatar(peer_id: int, member_profile: Dictionary, member_index: int) -> void:
	## 创建单个队友化身并挂入战斗世界；初始位置与本地玩家出生点一致，首个状态包会立即校正。
	# 化身节点；纯代码外观，物理层与玩家一致供敌人命中。
	var avatar: CharacterBody2D = REMOTE_PLAYER_AVATAR_SCRIPT.new() as CharacterBody2D
	if avatar == null:
		return
	avatar.name = "RemotePlayerAvatar_%d" % peer_id
	# 化身标签文本；昵称加角色显示名，角色名从会话状态服务读取。
	var avatar_label: String = "%s·%s" % [str(member_profile.get("name", "队友")), _get_character_display_name(str(member_profile.get("character_id", "stelle")))]
	avatar.call("setup_avatar", peer_id, avatar_label, AVATAR_COLOR_PALETTE[member_index % AVATAR_COLOR_PALETTE.size()], Callable(self, "_on_avatar_damage_forward"))
	# 大逃杀模式标记；开启化身互伤碰撞层，并把初始位置指向该成员的确定性出生点。
	var battle_royale_active: bool = _game_world != null and _game_world.has_method("is_network_battle_royale") and bool(_game_world.call("is_network_battle_royale"))
	if battle_royale_active:
		avatar.call("set_pvp_combat_enabled", true)
	# 化身挂载父节点；与本地玩家同级，保证世界坐标与绘制层级一致。
	var avatar_parent: Node = _game_world if _game_world != null else self
	avatar_parent.add_child(avatar)
	# 化身初始位置；大逃杀使用成员出生点避免首包前显示在本机玩家脚下，组队模式沿用共同出生点。
	if battle_royale_active and _game_world.has_method("get_network_spawn_position_for_peer"):
		avatar.global_position = _game_world.call("get_network_spawn_position_for_peer", peer_id)
	else:
		avatar.global_position = _player.global_position if _player != null else Vector2.ZERO
	_remote_avatars[peer_id] = avatar


func _remove_remote_avatar(peer_id: int) -> void:
	## 移除指定成员的化身；断线、撤离与死亡后退出统一走本入口。
	if not _remote_avatars.has(peer_id):
		return
	# 待移除化身节点；可能已随场景销毁，二次校验有效性。
	var avatar: Node = _remote_avatars[peer_id] as Node
	_remote_avatars.erase(peer_id)
	if is_instance_valid(avatar):
		avatar.queue_free()
	_refresh_simulation_anchor_nodes()


func _refresh_simulation_anchor_nodes() -> void:
	## 把当前全部队友化身注册为怪物物化额外锚点；远离主机玩家但靠近队友的虚拟敌人也会实例化并参战。
	if not _is_host or _monster_simulation_manager == null or not _monster_simulation_manager.has_method("set_additional_simulation_anchors"):
		return
	# 锚点节点列表；仅包含仍然有效的化身节点。
	var anchor_nodes: Array[Node2D] = []
	for peer_id in _remote_avatars.keys():
		# 单个化身节点；无效节点跳过并等待名册回调清理。
		var avatar: Node2D = _remote_avatars[peer_id] as Node2D
		if is_instance_valid(avatar):
			anchor_nodes.append(avatar)
	_monster_simulation_manager.call("set_additional_simulation_anchors", anchor_nodes)


func _broadcast_local_player_state() -> void:
	## 采样本地玩家位置、瞄准与生存状态并广播给全体成员；使用不可靠有序通道。
	if _player == null or not is_instance_valid(_player) or _network_session == null:
		return
	# 本地瞄准方向；玩家控制器提供当前瞄准单位向量，缺失时回退向右。
	var aim_direction: Vector2 = _player.call("get_current_aim_direction") if _player.has_method("get_current_aim_direction") else Vector2.RIGHT
	# 本地当前生命；战斗属性组件缺失时回退 1，仅影响队友端显示。
	var current_health: float = float(_player_stats_component.get("current_health")) if _player_stats_component != null else 1.0
	# 本地最大生命；至少为 1，保证队友端比例有效。
	var max_health: float = float(_player_stats_component.get("max_health")) if _player_stats_component != null else 1.0
	# 本地当前护盾；护盾组件缺失时为 0。
	var current_shield: float = float(_player_shield_component.get("current_shield")) if _player_shield_component != null else 0.0
	# 本地死亡状态；死亡后仍继续广播，使队友化身正确灰化。
	var local_dead: bool = bool(_player_stats_component.call("is_dead")) if _player_stats_component != null and _player_stats_component.has_method("is_dead") else false
	_network_session.call("broadcast_combat_message", {
		"t": "player_state",
		"x": _player.global_position.x,
		"y": _player.global_position.y,
		"aim": aim_direction.angle(),
		"hp": current_health,
		"mhp": max_health,
		"sh": current_shield,
		"dead": local_dead,
	}, false)


func _on_avatar_damage_forward(peer_id: int, damage: float, source: Node) -> void:
	## 主机敌人命中队友化身后，把伤害与来源战斗数值转发给该成员；对方在本地走完整受击流程（闪避、防御、护盾）。
	if _network_session == null:
		return
	# 来源世界位置；用于对方本地重建击退方向兜底，非 Node2D 来源回退化身位置。
	var source_position: Vector2 = (source as Node2D).global_position if source is Node2D else Vector2.ZERO
	# 来源击退方向；来源实现方向接口时原样转发，否则交由对方按位置推导。
	var knockback_direction: Vector2 = source.call("get_knockback_direction") if source != null and source.has_method("get_knockback_direction") else Vector2.ZERO
	_network_session.call("send_combat_message", peer_id, {
		"t": "player_hit",
		"dmg": damage,
		"ap": _get_source_value(source, "get_attack_power", 100.0),
		"cc": _get_source_value(source, "get_critical_chance", 0.0),
		"cm": _get_source_value(source, "get_critical_damage_multiplier", 1.5),
		"imp": _get_source_value(source, "get_impact_force", 0.0),
		"kx": knockback_direction.x,
		"ky": knockback_direction.y,
		"sx": source_position.x,
		"sy": source_position.y,
	}, true)


func _apply_remote_player_hit(payload: Dictionary) -> void:
	## 客户端接收主机转发的敌方伤害；用伤害代理重建来源后调用本地玩家标准受击入口。
	if _player == null or not is_instance_valid(_player) or _damage_proxy == null:
		return
	_damage_proxy.call("configure_remote_damage",
		float(payload.get("ap", 100.0)),
		float(payload.get("cc", 0.0)),
		float(payload.get("cm", 1.5)),
		float(payload.get("imp", 0.0)),
		Vector2(float(payload.get("kx", 0.0)), float(payload.get("ky", 0.0))),
		Vector2(float(payload.get("sx", 0.0)), float(payload.get("sy", 0.0))))
	if _player.has_method("apply_damage"):
		_player.call("apply_damage", float(payload.get("dmg", 0.0)), _damage_proxy)


# ---------------------------------------------------------------------------
# 队友攻击视觉
# ---------------------------------------------------------------------------

func _connect_local_fire_signals() -> void:
	## 订阅本地玩家远程与混合远程攻击组件的开火信号；把弹体出膛参数广播给队友做纯视觉重放。
	for component_name in ["RangedAttackComponent", "HybridRangedAttackComponent"]:
		# 攻击组件节点；旧场景可能缺失混合组件，逐个判空。
		var attack_component: Node = _player.get_node_or_null(NodePath(component_name))
		if attack_component != null and attack_component.has_signal("fired"):
			attack_component.connect("fired", Callable(self, "_on_local_projectile_fired"))


func _on_local_projectile_fired(projectile: Node2D) -> void:
	## 本地玩家弹体发射回调；读取弹体实际速度向量与场景路径并广播。
	if projectile == null or not is_instance_valid(projectile) or _network_session == null:
		return
	# 弹体实际速度向量；读取弹体私有速度字段，包含武器覆盖后的真实速度与方向。
	var projectile_velocity: Variant = projectile.get("_velocity")
	# 有效速度向量；异常时按弹体朝向与默认速度回退。
	var resolved_velocity: Vector2 = projectile_velocity if projectile_velocity is Vector2 else Vector2.RIGHT.rotated(projectile.global_rotation) * 900.0
	_network_session.call("broadcast_combat_message", {
		"t": "player_fire",
		"sp": projectile.scene_file_path,
		"x": projectile.global_position.x,
		"y": projectile.global_position.y,
		"dx": resolved_velocity.x,
		"dy": resolved_velocity.y,
		"md": float(projectile.get("max_distance")) if projectile.get("max_distance") != null else 340.0,
	}, false)


func _spawn_remote_fire_visual(payload: Dictionary) -> void:
	## 生成队友弹体的纯视觉副本；关闭全部碰撞与伤害，仅按相同速度飞行并自动回收。
	# 弹体场景路径；只接受弹体目录下的场景，防止异常消息加载任意资源。
	var scene_path: String = str(payload.get("sp", ""))
	if not scene_path.begins_with(REMOTE_PROJECTILE_PATH_PREFIX) or not scene_path.ends_with(".tscn"):
		return
	if not _remote_projectile_scene_cache.has(scene_path):
		_remote_projectile_scene_cache[scene_path] = load(scene_path)
	# 弹体场景资源；加载失败时缓存空值避免反复加载。
	var projectile_scene: PackedScene = _remote_projectile_scene_cache[scene_path] as PackedScene
	if projectile_scene == null:
		return
	# 视觉弹体实例；碰撞层与掩码清零后不会命中任何目标。
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	if projectile == null:
		return
	# 速度向量；来自发射方弹体真实速度，方向与速度一并还原。
	var velocity: Vector2 = Vector2(float(payload.get("dx", 900.0)), float(payload.get("dy", 0.0)))
	projectile.set("collision_layer", 0)
	projectile.set("collision_mask", 0)
	if projectile.has_method("set_damage"):
		projectile.call("set_damage", 0.0)
	if projectile.has_method("set_max_distance"):
		projectile.call("set_max_distance", maxf(float(payload.get("md", 340.0)), 1.0))
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0)))
	if projectile.has_method("launch") and not velocity.is_zero_approx():
		projectile.call("launch", velocity.normalized(), velocity.length())


func notify_host_enemy_projectile(projectile: Node2D, direction: Vector2, projectile_speed: float) -> void:
	## 主机远程怪物发射弹体后调用；把出膛位置与方向广播给客户端生成视觉弹体。
	if not _is_host or projectile == null or _network_session == null:
		return
	_network_session.call("broadcast_combat_message", {
		"t": "enemy_shot",
		"x": projectile.global_position.x,
		"y": projectile.global_position.y,
		"dx": direction.x,
		"dy": direction.y,
		"spd": projectile_speed,
	}, false)


func _spawn_remote_enemy_projectile_visual(payload: Dictionary) -> void:
	## 客户端生成敌方弹体视觉副本；保留敌方弹体层使玩家近战仍可清除它，但掩码清零不造成伤害。
	# 视觉弹体实例；伤害配置为 0，命中结算完全由主机权威执行。
	var projectile: Node2D = ENEMY_PROJECTILE_SCENE.instantiate() as Node2D
	if projectile == null:
		return
	projectile.set("collision_mask", 0)
	if projectile.has_method("configure_projectile"):
		projectile.call("configure_projectile", 0.0, 0.0, 620.0)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0)))
	# 弹体飞行方向；主机已包含散布随机偏移，客户端只做确定性重放。
	var direction: Vector2 = Vector2(float(payload.get("dx", 1.0)), float(payload.get("dy", 0.0)))
	if projectile.has_method("launch") and not direction.is_zero_approx():
		projectile.call("launch", direction, maxf(float(payload.get("spd", 620.0)), 1.0))


# ---------------------------------------------------------------------------
# 敌人复制：主机侧
# ---------------------------------------------------------------------------

func _host_scan_and_broadcast_enemies() -> void:
	## 主机扫描当前已物化的真实敌人；新增节点广播生成，消失节点广播移除，存活节点打包状态快照。
	if _network_session == null:
		return
	# 当前批次仍然有效的敌人编号集合；用于找出已消失（休眠或异常释放）的编号。
	var seen_enemy_ids: Dictionary = {}
	# 敌人状态快照条目；元素为 [编号, x, y, 当前生命] 数组。
	var state_entries: Array = []
	for raw_monster in get_tree().get_nodes_in_group("training_monsters"):
		# 候选怪物节点；必须是有效、未死亡且支持网络协议的真实敌人。
		var monster: Node2D = raw_monster as Node2D
		if monster == null or not is_instance_valid(monster) or monster.is_queued_for_deletion():
			continue
		if not monster.has_method("is_network_puppet") or bool(monster.call("is_network_puppet")):
			continue
		if bool(monster.call("is_dead")):
			continue
		# 怪物网络编号；首次发现时分配并广播生成消息。
		var enemy_id: int = int(_host_enemy_ids_by_instance.get(monster.get_instance_id(), 0))
		if enemy_id == 0:
			enemy_id = _next_enemy_network_id
			_next_enemy_network_id += 1
			_host_enemy_ids_by_instance[monster.get_instance_id()] = enemy_id
			_host_enemy_nodes_by_id[enemy_id] = monster
			_broadcast_enemy_add(enemy_id, monster)
		seen_enemy_ids[enemy_id] = true
		state_entries.append([enemy_id, monster.global_position.x, monster.global_position.y, float(monster.get("current_health"))])
	# 已消失敌人编号列表；死亡节点由死亡回调提前广播，剩余视为休眠移除。
	for known_enemy_id in _host_enemy_nodes_by_id.keys().duplicate():
		if seen_enemy_ids.has(known_enemy_id):
			continue
		_host_forget_enemy(int(known_enemy_id), false)
	# 分块广播状态快照；附带全图人口供客户端 HUD 显示。
	var population_count: int = int(_monster_simulation_manager.call("get_population_count")) if _monster_simulation_manager != null and _monster_simulation_manager.has_method("get_population_count") else state_entries.size()
	# 分块起始下标；每条消息最多携带固定条目数。
	var chunk_start: int = 0
	while chunk_start < state_entries.size() or chunk_start == 0:
		_network_session.call("broadcast_combat_message", {
			"t": "enemy_state",
			"e": state_entries.slice(chunk_start, chunk_start + ENEMY_STATE_CHUNK_SIZE),
			"pop": population_count,
		}, false)
		chunk_start += ENEMY_STATE_CHUNK_SIZE
		if chunk_start >= state_entries.size():
			break


func _broadcast_enemy_add(enemy_id: int, monster: Node2D) -> void:
	## 广播一名敌人的生成参数；客户端据此实例化同场景傀儡并还原体型与属性倍率。
	_network_session.call("broadcast_combat_message", {
		"t": "enemy_add",
		"id": enemy_id,
		"sp": monster.scene_file_path,
		"x": monster.global_position.x,
		"y": monster.global_position.y,
		"sm": float(monster.get("_spawn_size_multiplier")) if monster.get("_spawn_size_multiplier") != null else 1.0,
		"am": float(monster.get("_spawn_attribute_multiplier")) if monster.get("_spawn_attribute_multiplier") != null else 1.0,
		"hp": float(monster.get("current_health")),
		"mhp": float(monster.get("max_health")),
	}, true)


func _on_host_monster_died(monster: Node2D) -> void:
	## 主机真实敌人死亡回调；广播死亡移除并附带击杀归属，供客户端播放死亡动画与套装击杀通知。
	if monster == null or not is_instance_valid(monster):
		return
	# 死亡敌人网络编号；尚未进入复制表的敌人（生成即死亡）无需广播。
	var enemy_id: int = int(_host_enemy_ids_by_instance.get(monster.get_instance_id(), 0))
	if enemy_id == 0:
		return
	_host_dead_enemy_ids[enemy_id] = true
	_host_forget_enemy(enemy_id, true)


func _host_forget_enemy(enemy_id: int, died: bool) -> void:
	## 主机移除一条敌人复制记录并广播移除消息；died 区分死亡动画与静默回收。
	# 敌人节点条目；可能已经无效，仅用于清理实例映射。
	var monster: Node = _host_enemy_nodes_by_id.get(enemy_id) as Node
	if monster != null and is_instance_valid(monster):
		_host_enemy_ids_by_instance.erase(monster.get_instance_id())
	_host_enemy_nodes_by_id.erase(enemy_id)
	# 击杀归属 peer_id；仅死亡移除时附带，0 表示主机自身或环境击杀。
	var killer_peer_id: int = int(_last_network_damage_peer_by_enemy_id.get(enemy_id, 0)) if died else 0
	_last_network_damage_peer_by_enemy_id.erase(enemy_id)
	_host_dead_enemy_ids.erase(enemy_id)
	if _network_session != null:
		_network_session.call("broadcast_combat_message", {"t": "enemy_remove", "id": enemy_id, "died": died, "kp": killer_peer_id}, true)


func _apply_network_enemy_damage(sender_peer_id: int, payload: Dictionary) -> void:
	## 主机接收客户端对敌人的最终伤害；直接落到权威敌人身上并把攻击方化身注入仇恨。
	# 目标敌人编号；复制表中不存在时说明敌人已死亡或休眠，直接忽略。
	var enemy_id: int = int(payload.get("id", 0))
	# 目标敌人节点；无效时忽略本次伤害。
	var monster: Node = _host_enemy_nodes_by_id.get(enemy_id) as Node
	if monster == null or not is_instance_valid(monster) or not monster.has_method("receive_network_final_damage"):
		return
	# 攻击方化身节点；作为仇恨来源注入，缺失时敌人不改变当前目标。
	var attacker_avatar: Node2D = _remote_avatars.get(sender_peer_id) as Node2D
	_last_network_damage_peer_by_enemy_id[enemy_id] = sender_peer_id
	monster.call("receive_network_final_damage",
		float(payload.get("fd", 0.0)),
		bool(payload.get("cr", false)),
		float(payload.get("imp", 0.0)),
		Vector2(float(payload.get("kx", 0.0)), float(payload.get("ky", 0.0))),
		attacker_avatar)


# ---------------------------------------------------------------------------
# 敌人复制：客户端傀儡侧
# ---------------------------------------------------------------------------

func _spawn_puppet_enemy(payload: Dictionary) -> void:
	## 客户端按主机生成消息实例化傀儡敌人；傀儡保留外观、碰撞与技能目标组，但不执行任何 AI。
	# 敌人网络编号；重复消息直接忽略。
	var enemy_id: int = int(payload.get("id", 0))
	if enemy_id <= 0 or _puppet_enemies_by_id.has(enemy_id):
		return
	# 敌人场景路径；限制在敌人目录内，异常路径直接丢弃。
	var scene_path: String = str(payload.get("sp", ""))
	if not scene_path.begins_with("res://scenes/enemies/") or not scene_path.ends_with(".tscn"):
		return
	if not _puppet_scene_cache.has(scene_path):
		_puppet_scene_cache[scene_path] = load(scene_path)
	# 敌人场景资源；加载失败时忽略该敌人，后续快照同样跳过。
	var monster_scene: PackedScene = _puppet_scene_cache[scene_path] as PackedScene
	if monster_scene == null:
		return
	# 傀儡怪物实例；与主机同场景同倍率，视觉与碰撞完全一致。
	var puppet: Node2D = monster_scene.instantiate() as Node2D
	if puppet == null:
		return
	if puppet.has_method("apply_spawn_variation"):
		puppet.call("apply_spawn_variation", float(payload.get("sm", 1.0)), float(payload.get("am", 1.0)))
	if puppet.has_method("enter_network_puppet_mode"):
		puppet.call("enter_network_puppet_mode", Callable(self, "_on_puppet_damage_forward"))
	# 傀儡的敌人网络编号元数据；受击转发按该编号定位主机权威敌人，避免每次命中反查傀儡表。
	puppet.set_meta("network_enemy_id", enemy_id)
	# 傀儡挂载父节点；沿用 Enemies 容器保持层级一致。
	var puppet_parent: Node = _monster_parent if _monster_parent != null else _game_world
	puppet_parent.add_child(puppet)
	puppet.global_position = Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0)))
	puppet.set("max_health", maxf(float(payload.get("mhp", 1.0)), 1.0))
	puppet.set("current_health", clampf(float(payload.get("hp", 1.0)), 0.0, maxf(float(payload.get("mhp", 1.0)), 1.0)))
	_puppet_enemies_by_id[enemy_id] = puppet


func _apply_enemy_state_snapshot(payload: Dictionary) -> void:
	## 客户端应用一条敌人状态快照；逐条更新傀儡目标位置与权威生命。
	_replicated_population_count = int(payload.get("pop", _replicated_population_count))
	for raw_entry in (payload.get("e", []) as Array):
		# 单条状态条目；固定为 [编号, x, y, 生命] 数组，异常条目跳过。
		var entry: Array = raw_entry as Array
		if entry == null or entry.size() < 4:
			continue
		# 目标傀儡节点；尚未收到生成消息或已死亡时跳过。
		var puppet: Node = _puppet_enemies_by_id.get(int(entry[0])) as Node
		if puppet == null or not is_instance_valid(puppet) or not puppet.has_method("apply_network_puppet_state"):
			continue
		puppet.call("apply_network_puppet_state", Vector2(float(entry[1]), float(entry[2])), float(entry[3]))


func _remove_puppet_enemy(payload: Dictionary) -> void:
	## 客户端移除傀儡敌人；死亡移除播放原版死亡动画，休眠移除直接静默释放。
	# 敌人网络编号；未知编号直接忽略。
	var enemy_id: int = int(payload.get("id", 0))
	# 目标傀儡节点；可能已被场景清理。
	var puppet: Node = _puppet_enemies_by_id.get(enemy_id) as Node
	_puppet_enemies_by_id.erase(enemy_id)
	if puppet == null or not is_instance_valid(puppet):
		return
	if bool(payload.get("died", false)) and puppet.has_method("play_network_puppet_death"):
		puppet.call("play_network_puppet_death")
	else:
		puppet.queue_free()
	# 击杀归属；本机击杀时通知套装组件，保持“击杀触发”类效果在联机下生效。
	if bool(payload.get("died", false)) and _network_session != null and int(payload.get("kp", 0)) == int(_network_session.call("get_local_peer_id")):
		_notify_local_kill_effects()


func _notify_local_kill_effects() -> void:
	## 本机确认击杀后触发套装击杀通知；与单机 GameWorld 的击杀链路语义一致。
	if _player == null or not is_instance_valid(_player):
		return
	# 套装组件节点；缺失时静默跳过。
	var equipment_set_component: Node = _player.get_node_or_null("EquipmentSetComponent")
	if equipment_set_component != null and equipment_set_component.has_method("notify_enemy_killed"):
		equipment_set_component.call("notify_enemy_killed")


func _on_puppet_damage_forward(puppet: Node2D, final_damage: float, is_critical: bool, impact_force: float, knockback_direction: Vector2) -> void:
	## 客户端傀儡受击回调；本地已完成伤害公式与暴击判定，把最终伤害转发给主机落账。
	if _network_session == null or puppet == null:
		return
	# 傀儡对应的敌人网络编号；生成时写入元数据，缺失说明敌人已被移除或消息异常。
	var enemy_id: int = int(puppet.get_meta("network_enemy_id", 0))
	if enemy_id <= 0:
		return
	_network_session.call("send_combat_message", 1, {
		"t": "enemy_hit",
		"id": enemy_id,
		"fd": final_damage,
		"cr": is_critical,
		"imp": impact_force,
		"kx": knockback_direction.x,
		"ky": knockback_direction.y,
	}, true)


func get_replicated_population_count() -> int:
	## 返回主机广播的全图敌人人口；客户端 HUD 人口显示读取该值。
	return _replicated_population_count


# ---------------------------------------------------------------------------
# 掉落物复制与拾取仲裁
# ---------------------------------------------------------------------------

func on_local_drop_spawned(drop_instance: Node, item_data: Resource, quantity: int, drop_position: Vector2, launch_origin: Vector2, launch_duration: float, launch_arc_height: float) -> void:
	## GameWorld 掉落生成钩子；本地产生的新掉落分配网络编号并广播，远程复制的掉落只登记编号。
	if drop_instance == null or _network_session == null:
		return
	if not _applying_remote_drop_id.is_empty():
		drop_instance.set_meta("network_drop_id", _applying_remote_drop_id)
		_drop_nodes_by_id[_applying_remote_drop_id] = drop_instance
		if _is_host:
			_host_alive_drop_ids[_applying_remote_drop_id] = true
		return
	# 新掉落网络编号；本机 peer_id 与本机序号组合，全局唯一。
	var drop_id: String = "%d_%d" % [int(_network_session.call("get_local_peer_id")), _next_local_drop_sequence]
	_next_local_drop_sequence += 1
	drop_instance.set_meta("network_drop_id", drop_id)
	_drop_nodes_by_id[drop_id] = drop_instance
	if _is_host:
		_host_alive_drop_ids[drop_id] = true
	# 物品快照字典；复用全局库存稳定存档格式，可完整还原强化、耐久与二手状态。
	var item_snapshot: Dictionary = _serialize_item_snapshot(item_data, quantity)
	if item_snapshot.is_empty():
		return
	_network_session.call("broadcast_combat_message", {
		"t": "drop_add",
		"id": drop_id,
		"item": item_snapshot,
		"q": quantity,
		"x": drop_position.x,
		"y": drop_position.y,
		"lx": launch_origin.x,
		"ly": launch_origin.y,
		"ld": launch_duration,
		"lh": launch_arc_height,
	}, true)


func _apply_remote_drop_spawn(payload: Dictionary) -> void:
	## 应用一条远程掉落生成消息；反序列化物品后调用 GameWorld 原生掉落生成接口。
	# 掉落网络编号；重复消息直接忽略。
	var drop_id: String = str(payload.get("id", ""))
	if drop_id.is_empty() or _drop_nodes_by_id.has(drop_id):
		return
	# 物品反序列化结果；包含 resource 与 quantity，失败时忽略本条消息。
	var restored_item: Dictionary = _deserialize_item_snapshot(payload.get("item", {}) as Dictionary)
	# 还原的物品资源；为空说明快照损坏或版本不符。
	var item_resource: Resource = restored_item.get("resource") as Resource
	if item_resource == null or _game_world == null or not _game_world.has_method("spawn_item_drop"):
		return
	_applying_remote_drop_id = drop_id
	_game_world.call("spawn_item_drop",
		item_resource,
		Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0))),
		Vector2(float(payload.get("lx", INF)), float(payload.get("ly", INF))),
		float(payload.get("ld", 0.0)),
		float(payload.get("lh", 0.0)),
		maxi(int(payload.get("q", 1)), 1))
	_applying_remote_drop_id = ""


func request_network_pickup(drop_node: Node, inventory_component: Node) -> bool:
	## 联机拾取统一入口；主机本地仲裁后立即拾取，客户端向主机发起请求并等待答复。
	if _pickup_bypass_active:
		return false
	# 掉落网络编号；没有编号的节点（极早期竞态）退回普通本地拾取。
	var drop_id: String = str(drop_node.get_meta("network_drop_id", ""))
	if drop_id.is_empty():
		return _execute_bypass_pickup(drop_node, inventory_component)
	if _is_host or not _host_available:
		# 主机或主机缺席降级模式；本地直接执行拾取并广播移除。
		if _is_host and not _host_alive_drop_ids.has(drop_id):
			return false
		# 本地拾取结果；失败（背包满）时不移除掉落，其他成员不受影响。
		var pickup_succeeded: bool = _execute_bypass_pickup(drop_node, inventory_component)
		if pickup_succeeded:
			_host_alive_drop_ids.erase(drop_id)
			_drop_nodes_by_id.erase(drop_id)
			if _network_session != null:
				_network_session.call("broadcast_combat_message", {"t": "drop_remove", "id": drop_id}, true)
		return pickup_succeeded
	if _pending_pickups.has(drop_id):
		return true
	_pending_pickups[drop_id] = {"drop": drop_node, "inventory": inventory_component, "elapsed": 0.0}
	if _network_session != null:
		_network_session.call("send_combat_message", 1, {"t": "drop_request", "id": drop_id}, true)
	return true


func is_pickup_bypass_active() -> bool:
	## 返回同步器是否正在代持执行原生拾取；掉落物据此跳过联机仲裁分支，避免委托递归。
	return _pickup_bypass_active


func _execute_bypass_pickup(drop_node: Node, inventory_component: Node) -> bool:
	## 以旁路模式执行掉落物原生拾取流程；旁路开关避免再次进入联机仲裁入口。
	if drop_node == null or not is_instance_valid(drop_node) or not drop_node.has_method("pickup_to_inventory"):
		return false
	_pickup_bypass_active = true
	# 原生拾取结果；容量校验与库存写入全部由掉落物与库存服务完成。
	var pickup_result: bool = bool(drop_node.call("pickup_to_inventory", inventory_component))
	_pickup_bypass_active = false
	return pickup_result


func _handle_drop_request(sender_peer_id: int, payload: Dictionary) -> void:
	## 主机处理客户端拾取请求；先到先得，同意后先答复请求方再广播移除，保证同链路消息顺序。
	# 请求的掉落编号；不在存活集合中说明已被拾取或移除。
	var drop_id: String = str(payload.get("id", ""))
	if not _host_alive_drop_ids.has(drop_id):
		_network_session.call("send_combat_message", sender_peer_id, {"t": "drop_grant", "id": drop_id, "ok": false}, true)
		return
	_host_alive_drop_ids.erase(drop_id)
	_network_session.call("send_combat_message", sender_peer_id, {"t": "drop_grant", "id": drop_id, "ok": true}, true)
	_network_session.call("broadcast_combat_message", {"t": "drop_remove", "id": drop_id}, true)
	# 主机本地掉落节点；广播不含自身，主机在此直接移除。
	var local_drop: Node = _drop_nodes_by_id.get(drop_id) as Node
	_drop_nodes_by_id.erase(drop_id)
	if local_drop != null and is_instance_valid(local_drop) and int(payload.get("keep_local", 0)) == 0:
		local_drop.queue_free()


func _handle_drop_grant(payload: Dictionary) -> void:
	## 客户端处理主机拾取答复；同意后执行本地拾取，背包已满时以新编号重新登记该掉落。
	# 答复的掉落编号；无挂起记录说明已超时清理。
	var drop_id: String = str(payload.get("id", ""))
	# 挂起拾取记录；包含掉落节点与库存组件引用。
	var pending_entry: Variant = _pending_pickups.get(drop_id)
	_pending_pickups.erase(drop_id)
	if not (pending_entry is Dictionary) or not bool(payload.get("ok", false)):
		return
	# 挂起的掉落节点；主机移除广播按发送顺序晚于本答复，此时节点仍应有效。
	var drop_node: Node = (pending_entry as Dictionary).get("drop") as Node
	if drop_node == null or not is_instance_valid(drop_node):
		return
	_drop_nodes_by_id.erase(drop_id)
	if _execute_bypass_pickup(drop_node, (pending_entry as Dictionary).get("inventory") as Node):
		return
	# 拾取失败（背包已满）；以新编号重新广播该掉落，使全员恢复可见可拾取状态。
	drop_node.set_meta("network_drop_id", "")
	if drop_node.has_method("show_pickup_status"):
		drop_node.call("show_pickup_status", "背包已满！")
	_reauthor_existing_drop(drop_node)


func _reauthor_existing_drop(drop_node: Node) -> void:
	## 把仍在本机存在的掉落节点按新编号重新登记并广播；用于拾取仲裁通过但入包失败的回滚。
	if drop_node == null or not is_instance_valid(drop_node) or not drop_node.has_method("get_item_data"):
		return
	# 掉落物品资源；节点仍持有原资源实例。
	var item_resource: Resource = drop_node.call("get_item_data") as Resource
	# 掉落数量；读取节点当前数量接口。
	var drop_quantity: int = int(drop_node.call("get_quantity")) if drop_node.has_method("get_quantity") else 1
	if item_resource == null:
		return
	on_local_drop_spawned(drop_node, item_resource, drop_quantity, (drop_node as Node2D).global_position, Vector2.INF, 0.0, 0.0)


func _handle_drop_remove(payload: Dictionary) -> void:
	## 应用掉落移除广播；被其他成员拾取或主机仲裁移除的掉落在本机消失。
	# 目标掉落编号；同时清理挂起拾取记录。
	var drop_id: String = str(payload.get("id", ""))
	_pending_pickups.erase(drop_id)
	_host_alive_drop_ids.erase(drop_id)
	# 本机掉落节点；已被本机拾取时表内不存在，无需处理。
	var drop_node: Node = _drop_nodes_by_id.get(drop_id) as Node
	_drop_nodes_by_id.erase(drop_id)
	if drop_node != null and is_instance_valid(drop_node):
		drop_node.queue_free()


func _update_pending_pickups(delta: float) -> void:
	## 客户端挂起拾取超时清理；主机答复丢失时不锁死该掉落，以移除广播为最终一致依据。
	for drop_id in _pending_pickups.keys().duplicate():
		# 单条挂起记录；累计等待时长超时后移除。
		var pending_entry: Dictionary = _pending_pickups[drop_id] as Dictionary
		pending_entry["elapsed"] = float(pending_entry.get("elapsed", 0.0)) + delta
		if float(pending_entry["elapsed"]) > PICKUP_PENDING_TIMEOUT:
			_pending_pickups.erase(drop_id)


func _serialize_item_snapshot(item_data: Resource, quantity: int) -> Dictionary:
	# 全局库存服务；提供稳定物品快照序列化，缺失时无法跨端复制物品。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory == null or not global_inventory.has_method("serialize_item_snapshot"):
		return {}
	return global_inventory.call("serialize_item_snapshot", item_data, quantity) as Dictionary


func _deserialize_item_snapshot(item_snapshot: Dictionary) -> Dictionary:
	# 全局库存服务；提供稳定物品快照反序列化。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory == null or not global_inventory.has_method("deserialize_item_snapshot"):
		return {}
	return global_inventory.call("deserialize_item_snapshot", item_snapshot) as Dictionary


# ---------------------------------------------------------------------------
# 宝箱开启仲裁
# ---------------------------------------------------------------------------

func request_chest_release(chest_position: Vector2, quality_id: String, drop_count: int, minimum_high_quality_count: int, broken_open: bool) -> void:
	## 联机宝箱出货统一入口；主机本地先到先得，客户端向主机认领成功后由开启方本地掷点出货。
	# 宝箱位置键；宝箱布点由共享种子确定性生成，位置在各端逐位一致，可作为稳定标识。
	var chest_key: String = _build_chest_key(chest_position)
	if _is_host or not _host_available:
		if _claimed_chest_keys.has(chest_key):
			return
		_claimed_chest_keys[chest_key] = true
		_execute_chest_release(chest_position, quality_id, drop_count, minimum_high_quality_count, broken_open)
		if _network_session != null:
			_network_session.call("broadcast_combat_message", {"t": "chest_gone", "k": chest_key}, true)
		return
	if _network_session != null:
		_network_session.call("send_combat_message", 1, {
			"t": "chest_claim",
			"k": chest_key,
			"x": chest_position.x,
			"y": chest_position.y,
			"q": quality_id,
			"dc": drop_count,
			"mh": minimum_high_quality_count,
			"br": broken_open,
		}, true)


func _handle_chest_claim(sender_peer_id: int, payload: Dictionary) -> void:
	## 主机处理宝箱认领；首个认领者获得出货权，主机同时移除本地宝箱并通知其余成员移除。
	# 认领的宝箱位置键；已认领时拒绝，防止双开双出货。
	var chest_key: String = str(payload.get("k", ""))
	if _claimed_chest_keys.has(chest_key):
		_network_session.call("send_combat_message", sender_peer_id, {"t": "chest_grant", "k": chest_key, "ok": false}, true)
		return
	_claimed_chest_keys[chest_key] = true
	# 认领答复；原样回传出货参数，认领方据此本地掷点。
	var grant_payload: Dictionary = payload.duplicate()
	grant_payload["t"] = "chest_grant"
	grant_payload["ok"] = true
	_network_session.call("send_combat_message", sender_peer_id, grant_payload, true)
	_network_session.call("broadcast_combat_message", {"t": "chest_gone", "k": chest_key}, true)
	_remove_local_chest_by_key(chest_key)


func _handle_chest_grant(payload: Dictionary) -> void:
	## 客户端处理宝箱认领答复；认领成功后本地执行出货，掉落经掉落广播同步给全员。
	if not bool(payload.get("ok", false)):
		return
	_execute_chest_release(
		Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0))),
		str(payload.get("q", "common")),
		int(payload.get("dc", 0)),
		int(payload.get("mh", 0)),
		bool(payload.get("br", false)))


func _execute_chest_release(chest_position: Vector2, quality_id: String, drop_count: int, minimum_high_quality_count: int, broken_open: bool) -> void:
	## 调用 GameWorld 的宝箱出货执行入口；本函数只在获得出货权的一端运行一次。
	if _game_world != null and _game_world.has_method("execute_loot_chest_release"):
		_game_world.call("execute_loot_chest_release", chest_position, quality_id, drop_count, minimum_high_quality_count, broken_open)


func _handle_chest_gone(payload: Dictionary) -> void:
	## 应用宝箱移除广播；本机同位置宝箱若尚未开启则静默移除，不出货不掉落。
	_claimed_chest_keys[str(payload.get("k", ""))] = true
	_remove_local_chest_by_key(str(payload.get("k", "")))


func _remove_local_chest_by_key(chest_key: String) -> void:
	## 按位置键移除本机宝箱节点；委托 GameWorld 遍历宝箱缓存执行静默移除。
	if _game_world != null and _game_world.has_method("remove_network_loot_chest_by_key"):
		_game_world.call("remove_network_loot_chest_by_key", chest_key)


func _build_chest_key(chest_position: Vector2) -> String:
	## 把宝箱世界位置量化为稳定字符串键；各端由同种子生成的同一宝箱得到相同键。
	return "%.1f_%.1f" % [chest_position.x, chest_position.y]


# ---------------------------------------------------------------------------
# 死亡观战
# ---------------------------------------------------------------------------

func try_begin_spectator_mode(finished_callback: Callable) -> bool:
	## 尝试进入死亡观战；仅当仍有存活队友时接管视角并返回 true，调用方（战斗 HUD）据此推迟死亡结算。
	## 观战期间目标死亡或离场会自动切换，全部队友倒下、离场或玩家点击“结算退出”后调用回调恢复原死亡结算流程。
	if _spectator_active or _network_session == null:
		return false
	# 首个观战目标；没有任何存活队友时不进入观战，调用方立即执行原结算。
	var initial_target_peer_id: int = _find_alive_spectator_target(0, 1)
	if initial_target_peer_id <= 0:
		return false
	_spectator_finished_callback = finished_callback
	_spectator_active = true
	_build_spectator_ui()
	_spectator_layer.visible = true
	if _spectator_camera == null:
		_spectator_camera = Camera2D.new()
		_spectator_camera.name = "SpectatorCamera"
		_spectator_camera.zoom = _get_player_camera_zoom()
		add_child(_spectator_camera)
	_set_spectator_target(initial_target_peer_id)
	_spectator_camera.make_current()
	return true


func is_spectator_active() -> bool:
	## 返回观战模式是否进行中；供调试工具与验证脚本查询。
	return _spectator_active


func _update_spectator_state(delta: float) -> void:
	## 观战逐帧维护；复核目标有效性、自动切换与镜头平滑跟随，无人可观战时结束并交还结算。
	if not _spectator_active:
		return
	# 当前目标化身；目标死亡、离场或节点失效时自动切到下一名存活队友。
	var target_avatar: Node2D = _remote_avatars.get(_spectator_target_peer_id) as Node2D
	if not _is_spectator_target_valid(_spectator_target_peer_id):
		# 下一个存活目标；返回 0 表示全员倒下或离场，观战结束。
		var next_target_peer_id: int = _find_alive_spectator_target(_spectator_target_peer_id, 1)
		if next_target_peer_id <= 0:
			_end_spectator_mode()
			return
		_set_spectator_target(next_target_peer_id)
		target_avatar = _remote_avatars.get(_spectator_target_peer_id) as Node2D
	if _spectator_camera != null and target_avatar != null and is_instance_valid(target_avatar):
		_spectator_camera.global_position = _spectator_camera.global_position.lerp(target_avatar.global_position, clampf(SPECTATOR_CAMERA_FOLLOW_RATE * delta, 0.0, 1.0))


func _is_spectator_target_valid(peer_id: int) -> bool:
	## 判断成员是否仍可被观战；要求化身有效、未离场且远端状态未死亡。
	if peer_id <= 0 or _departed_peer_ids.has(peer_id):
		return false
	# 目标化身节点；断线成员的化身已由名册回调移除。
	var avatar: Node = _remote_avatars.get(peer_id) as Node
	return avatar != null and is_instance_valid(avatar) and avatar.has_method("is_dead") and not bool(avatar.call("is_dead"))


func _find_alive_spectator_target(from_peer_id: int, direction: int) -> int:
	## 按 peer_id 升序在存活队友之间循环查找观战目标；from_peer_id 为 0 或已失效时返回首个存活者，无人存活返回 0。
	# 存活成员有序列表；顺序稳定保证左右切换在各次调用间一致。
	var alive_peer_ids: Array[int] = []
	# 化身 peer_id 有序副本；字典键顺序不稳定，先排序再过滤。
	var sorted_peer_ids: Array = _remote_avatars.keys()
	sorted_peer_ids.sort()
	for peer_id in sorted_peer_ids:
		if _is_spectator_target_valid(int(peer_id)):
			alive_peer_ids.append(int(peer_id))
	if alive_peer_ids.is_empty():
		return 0
	# 当前目标在存活列表中的下标；-1 表示当前目标已失效，直接取首个存活者。
	var current_index: int = alive_peer_ids.find(from_peer_id)
	if current_index < 0:
		return alive_peer_ids[0]
	return alive_peer_ids[wrapi(current_index + direction, 0, alive_peer_ids.size())]


func _set_spectator_target(peer_id: int) -> void:
	## 切换观战目标；镜头直接落位到新目标避免跨越半张地图的长镜头漂移，横幅同步刷新昵称与角色。
	_spectator_target_peer_id = peer_id
	# 新目标化身；有效时镜头立即对位。
	var target_avatar: Node2D = _remote_avatars.get(peer_id) as Node2D
	if _spectator_camera != null and target_avatar != null and is_instance_valid(target_avatar):
		_spectator_camera.global_position = target_avatar.global_position
	if _spectator_banner_label != null and _network_session != null:
		_spectator_banner_label.text = "观战中：%s·%s" % [str(_network_session.call("get_peer_display_name", peer_id)), _get_character_display_name(str(_network_session.call("get_peer_character_id", peer_id)))]


func _end_spectator_mode() -> void:
	## 结束观战；恢复本地玩家相机、隐藏观战界面并调用结算回调交还死亡结算流程。
	if not _spectator_active:
		return
	_spectator_active = false
	_spectator_target_peer_id = 0
	if _spectator_layer != null:
		_spectator_layer.visible = false
	# 本地玩家相机；结算界面不依赖相机，但恢复当前相机可避免结算背景停留在他人位置。
	if _player != null and is_instance_valid(_player):
		var player_camera: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
		if player_camera != null:
			player_camera.make_current()
	# 结算回调副本；先清空成员变量再调用，防止回调内部重入观战状态。
	var finished_callback: Callable = _spectator_finished_callback
	_spectator_finished_callback = Callable()
	if finished_callback.is_valid():
		finished_callback.call()


func _build_spectator_ui() -> void:
	## 懒构建观战界面；顶部目标横幅、屏幕两侧切换箭头与底部“结算退出”按钮，构建一次后按观战状态显隐。
	if _spectator_layer != null:
		return
	_spectator_layer = CanvasLayer.new()
	_spectator_layer.name = "SpectatorLayer"
	# 观战层级；低于事件提示层，高于普通战斗 HUD。
	_spectator_layer.layer = 54
	add_child(_spectator_layer)
	# 观战根控件；铺满屏幕但不拦截鼠标，只有按钮自身可交互。
	var spectator_root: Control = Control.new()
	spectator_root.name = "SpectatorRoot"
	spectator_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	spectator_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spectator_layer.add_child(spectator_root)
	_spectator_banner_label = Label.new()
	_spectator_banner_label.name = "SpectatorBanner"
	_spectator_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spectator_banner_label.add_theme_font_size_override("font_size", 20)
	_spectator_banner_label.add_theme_color_override("font_color", Color(0.62, 0.88, 1.0, 1.0))
	# 横幅定位；位于屏幕顶部中央、事件提示下方。
	_spectator_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_spectator_banner_label.position = Vector2(-220.0, 108.0)
	_spectator_banner_label.custom_minimum_size = Vector2(440.0, 0.0)
	_spectator_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spectator_root.add_child(_spectator_banner_label)
	# 左切换箭头；位于屏幕左边缘垂直居中，切换到上一名存活队友。
	var previous_button: Button = Button.new()
	previous_button.name = "SpectatePreviousButton"
	previous_button.text = "◀"
	previous_button.custom_minimum_size = Vector2(64.0, 96.0)
	previous_button.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	previous_button.position = Vector2(24.0, -48.0)
	previous_button.add_theme_font_size_override("font_size", 26)
	UI_STYLE_GUIDE.apply_primary_button(previous_button)
	previous_button.pressed.connect(_on_spectator_switch_pressed.bind(-1))
	spectator_root.add_child(previous_button)
	# 右切换箭头；位于屏幕右边缘垂直居中，切换到下一名存活队友。
	var next_button: Button = Button.new()
	next_button.name = "SpectateNextButton"
	next_button.text = "▶"
	next_button.custom_minimum_size = Vector2(64.0, 96.0)
	next_button.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	next_button.position = Vector2(-88.0, -48.0)
	next_button.add_theme_font_size_override("font_size", 26)
	UI_STYLE_GUIDE.apply_primary_button(next_button)
	next_button.pressed.connect(_on_spectator_switch_pressed.bind(1))
	spectator_root.add_child(next_button)
	# 结算退出按钮；主动结束观战并立即执行推迟的死亡结算。
	var settle_button: Button = Button.new()
	settle_button.name = "SpectateSettleButton"
	settle_button.text = "结算退出"
	settle_button.custom_minimum_size = Vector2(160.0, 44.0)
	settle_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	settle_button.position = Vector2(-80.0, -132.0)
	UI_STYLE_GUIDE.apply_danger_button(settle_button)
	settle_button.pressed.connect(_on_spectator_settle_pressed)
	spectator_root.add_child(settle_button)
	_spectator_layer.visible = false


func _on_spectator_switch_pressed(direction: int) -> void:
	## 左右箭头回调；在存活队友之间循环切换观战目标，无其他存活者时保持当前目标。
	# 下一个观战目标；只有一名存活队友时返回其本身，切换等效无操作。
	var next_target_peer_id: int = _find_alive_spectator_target(_spectator_target_peer_id, direction)
	if next_target_peer_id > 0 and next_target_peer_id != _spectator_target_peer_id:
		_set_spectator_target(next_target_peer_id)


func _on_spectator_settle_pressed() -> void:
	## “结算退出”回调；玩家主动放弃观战，立即恢复死亡结算流程。
	_end_spectator_mode()


func _get_player_camera_zoom() -> Vector2:
	## 返回本地玩家战斗相机缩放；观战镜头沿用同一视野比例，相机缺失时回退项目默认 0.95。
	if _player != null and is_instance_valid(_player):
		# 玩家相机节点；战斗场景固定挂在玩家预制体下。
		var player_camera: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
		if player_camera != null:
			return player_camera.zoom
	return Vector2(0.95, 0.95)


# ---------------------------------------------------------------------------
# 成员事件与消息分发
# ---------------------------------------------------------------------------

func _on_local_player_died() -> void:
	## 本地玩家死亡；广播倒下事件供队友提示，状态包会同步灰化化身。
	if _network_session != null:
		_network_session.call("broadcast_combat_message", {"t": "event", "k": "player_dead", "pid": int(_network_session.call("get_local_peer_id"))}, true)


func _broadcast_local_departure() -> void:
	## 广播本机离场事件；主机离场时附带主机身份，客户端据此进入无主机降级模式。
	if _departure_broadcasted or _network_session == null or not bool(_network_session.call("is_combat_session_active")):
		return
	_departure_broadcasted = true
	_network_session.call("broadcast_combat_message", {
		"t": "event",
		"k": "host_left" if _is_host else "player_left",
		"pid": int(_network_session.call("get_local_peer_id")),
	}, true)


func _on_roster_changed() -> void:
	## 名册变化回调；断线成员移除化身并提示，新名册不会在战局中途新增成员。
	if _network_session == null:
		return
	# 当前名册中的 peer_id 集合；用于找出已不在名册中的化身。
	var roster_peer_ids: Dictionary = {}
	for member_profile in (_network_session.call("get_roster_snapshot") as Array):
		roster_peer_ids[int((member_profile as Dictionary).get("peer_id", 0))] = true
	for avatar_peer_id in _remote_avatars.keys().duplicate():
		if not roster_peer_ids.has(avatar_peer_id):
			_show_toast("%s 已断开连接" % _network_session.call("get_peer_display_name", avatar_peer_id))
			_remove_remote_avatar(int(avatar_peer_id))


func _on_disconnected_from_host() -> void:
	## 与主机连接中断；按主机离场规则降级，清空傀儡敌人并提示尽快撤离。
	_handle_host_left()


func _handle_host_left() -> void:
	## 主机离开战局的统一处理；客户端不再有敌人权威，清空傀儡并降级为本地仲裁。
	if _is_host or not _host_available:
		return
	_host_available = false
	for enemy_id in _puppet_enemies_by_id.keys().duplicate():
		# 残留傀儡节点；主机离开后不再收到状态更新，统一静默清除。
		var puppet: Node = _puppet_enemies_by_id[enemy_id] as Node
		if puppet != null and is_instance_valid(puppet):
			puppet.queue_free()
	_puppet_enemies_by_id.clear()
	_replicated_population_count = 0
	_show_toast("主机已离开战斗，敌人已撤除，请尽快撤离")


func _on_combat_message_received(sender_peer_id: int, payload: Dictionary) -> void:
	## 战斗消息统一分发入口；按消息类型路由到对应处理函数。
	# 消息类型标识；未知类型直接忽略，保证协议前向兼容。
	var message_type: String = str(payload.get("t", ""))
	match message_type:
		"player_state":
			_apply_remote_player_state(sender_peer_id, payload)
		"player_fire":
			_spawn_remote_fire_visual(payload)
		"player_hit":
			_apply_remote_player_hit(payload)
		"enemy_add":
			if not _is_host:
				_spawn_puppet_enemy(payload)
		"enemy_state":
			if not _is_host:
				_apply_enemy_state_snapshot(payload)
		"enemy_remove":
			if not _is_host:
				_remove_puppet_enemy(payload)
		"enemy_shot":
			if not _is_host:
				_spawn_remote_enemy_projectile_visual(payload)
		"enemy_hit":
			if _is_host:
				_apply_network_enemy_damage(sender_peer_id, payload)
		"drop_add":
			_apply_remote_drop_spawn(payload)
		"drop_remove":
			_handle_drop_remove(payload)
		"drop_request":
			if _is_host:
				_handle_drop_request(sender_peer_id, payload)
		"drop_grant":
			_handle_drop_grant(payload)
		"chest_claim":
			if _is_host:
				_handle_chest_claim(sender_peer_id, payload)
		"chest_grant":
			_handle_chest_grant(payload)
		"chest_gone":
			_handle_chest_gone(payload)
		"event":
			_handle_member_event(sender_peer_id, payload)


func _apply_remote_player_state(sender_peer_id: int, payload: Dictionary) -> void:
	## 应用一条队友状态包；离场成员的滞后状态包直接忽略。
	if _departed_peer_ids.has(sender_peer_id):
		return
	# 队友化身节点；名册同步竞态下可能尚未创建，触发一次补建。
	var avatar: Node = _remote_avatars.get(sender_peer_id) as Node
	if avatar == null or not is_instance_valid(avatar):
		_rebuild_remote_avatars()
		avatar = _remote_avatars.get(sender_peer_id) as Node
		if avatar == null:
			return
	avatar.call("update_remote_state",
		Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0))),
		float(payload.get("aim", 0.0)),
		float(payload.get("hp", 0.0)),
		float(payload.get("mhp", 1.0)),
		float(payload.get("sh", 0.0)),
		bool(payload.get("dead", false)))


func _handle_member_event(sender_peer_id: int, payload: Dictionary) -> void:
	## 处理成员事件广播；倒下与离场生成提示，主机离场额外触发降级流程。
	# 事件类型；当前支持 player_dead、player_left 与 host_left。
	var event_kind: String = str(payload.get("k", ""))
	# 事件成员显示名；从名册读取，断线成员回退编号名。
	var member_display_name: String = str(_network_session.call("get_peer_display_name", sender_peer_id)) if _network_session != null else "队友"
	match event_kind:
		"player_dead":
			_show_toast("%s 已倒下" % member_display_name)
		"player_left":
			_departed_peer_ids[sender_peer_id] = true
			_show_toast("%s 已离开战斗" % member_display_name)
			_remove_remote_avatar(sender_peer_id)
		"host_left":
			_departed_peer_ids[sender_peer_id] = true
			_show_toast("%s 已离开战斗" % member_display_name)
			_remove_remote_avatar(sender_peer_id)
			_handle_host_left()


func _get_character_display_name(character_id: String) -> String:
	# 会话状态服务；提供角色显示名查询，缺失时直接展示角色标识。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state != null and session_state.has_method("get_character_display_name"):
		return str(session_state.call("get_character_display_name", character_id))
	return character_id


func _get_source_value(source: Node, method_name: String, fallback_value: float) -> float:
	## 鸭子类型读取伤害来源战斗数值；与怪物受击流程使用相同的兼容规则。
	return float(source.call(method_name)) if source != null and source.has_method(method_name) else fallback_value


# ---------------------------------------------------------------------------
# 事件提示
# ---------------------------------------------------------------------------

func _build_toast_layer() -> void:
	## 构建事件提示层；提示位于屏幕上方居中，不遮挡战斗 HUD 主要区域。
	_toast_canvas_layer = CanvasLayer.new()
	_toast_canvas_layer.name = "NetworkToastLayer"
	# 提示层级；高于普通 HUD、低于全屏结算遮罩，短提示不需要交互。
	_toast_canvas_layer.layer = 55
	add_child(_toast_canvas_layer)
	_toast_container = VBoxContainer.new()
	_toast_container.name = "ToastContainer"
	_toast_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_container.position = Vector2(-220.0, 64.0)
	_toast_container.custom_minimum_size = Vector2(440.0, 0.0)
	_toast_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_canvas_layer.add_child(_toast_container)


func _show_toast(message: String) -> void:
	## 显示一条约 3 秒的事件提示；淡出后自动释放，不参与输入。
	if _toast_container == null:
		return
	# 提示文本标签；浅青色文字与项目提示语义色一致。
	var toast_label: Label = Label.new()
	toast_label.text = message
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 18)
	toast_label.add_theme_color_override("font_color", Color(0.62, 0.88, 1.0, 1.0))
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_container.add_child(toast_label)
	# 提示淡出补间；停留 2.2 秒后 0.8 秒淡出并释放标签。
	var toast_tween: Tween = toast_label.create_tween()
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.8)
	toast_tween.tween_callback(toast_label.queue_free)
