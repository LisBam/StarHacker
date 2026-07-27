extends Node

## 佣兵派遣服务在全部场景中持续运行，统一维护委托目录、进行中派遣、完成报告与独立存档。
## 玩家可把已解锁且未上场的角色派去执行限时委托；委托只消耗在线时间，到期自动交付星穹报酬。
## 每个委托拥有一项适性属性，角色对应属性越高大成功概率越高；派遣中的角色在角色选择页锁定确认。

## 派遣状态变化信号；签订、完成和异常回退时发送，面板与角色选择页据此刷新锁定状态。
signal dispatch_changed
## 派遣完成信号；参数为实际到账星穹与说明文本，横幅通知服务据此在任何场景提醒玩家。
signal dispatch_completed(gold_amount: int, message: String)

## 派遣独立存档路径；与角色解锁、库存存档分离，避免委托字段污染其他玩法的序列化结构。
const SAVE_PATH: String = "user://dispatch_state.json"
## 派遣存档版本；版本 2 保存多名角色的进行中委托、锁定报酬、剩余在线时长与近期完成报告。
const SAVE_VERSION: int = 2
## 近期完成报告的最大保留数量；默认 10 条，保证并行委托同一时段完成时每条结果都可追溯。
const RECENT_REPORT_LIMIT: int = 10
## 大成功基础概率；默认 15%，按角色适性属性相对 90 的差值每点增加 0.5 个百分点。
const CRIT_CHANCE_BASE: float = 0.15
## 大成功概率的属性基准值；默认 90，角色适性属性高于该值时概率上升，低于时下降。
const CRIT_CHANCE_ATTRIBUTE_BASELINE: float = 90.0
## 大成功概率的每点属性增量；默认 0.5 个百分点，与基础概率相加后受上下限约束。
const CRIT_CHANCE_PER_ATTRIBUTE_POINT: float = 0.005
## 大成功概率下限；默认 5%，属性极低的角色仍保留少量大成功可能。
const CRIT_CHANCE_MINIMUM: float = 0.05
## 大成功概率上限；默认 50%，防止未来高属性角色让大成功变成必然事件。
const CRIT_CHANCE_MAXIMUM: float = 0.50
## 大成功报酬倍率；默认 1.5，实际到账为锁定报酬乘该倍率后向下取整。
const CRIT_REWARD_MULTIPLIER: float = 1.5
## 委托定义表；时长、基础报酬、适性属性与说明集中维护，UI 只读取公开副本。
## 报酬阶梯说明；五档委托按在线时长递增，报酬效率依次约为每小时 300、321、350、374、400 星穹，时长越长效率越高以奖励长线锁定。
## 适性覆盖说明；五档委托的适性属性正好覆盖角色档案的移动速度、生命上限、防御力、能量上限与攻击力五维，任何角色都存在相对擅长的委托。
const MISSION_DEFINITIONS: Array[Dictionary] = [
	{"id": "intel_sweep", "name": "情报收集", "duration_seconds": 600, "base_reward": 50, "affinity_stat": "move_speed", "affinity_name": "移动速度", "description": "潜入街区搜集骇入情报，脚程越快越不容易暴露"},
	{"id": "garrison_watch", "name": "前线驻守", "duration_seconds": 1200, "base_reward": 107, "affinity_stat": "max_health", "affinity_name": "生命上限", "description": "驻守前哨要塞抵御持续袭扰，生命上限越高越能持久作战"},
	{"id": "relic_escort", "name": "遗迹护送", "duration_seconds": 1800, "base_reward": 175, "affinity_stat": "defense_power", "affinity_name": "防御力", "description": "护送勘探商队穿越遗迹，防御越高越能扛住伏击"},
	{"id": "energy_grid_patrol", "name": "能源网巡检", "duration_seconds": 2400, "base_reward": 249, "affinity_stat": "max_energy", "affinity_name": "能量上限", "description": "巡检星海能源中继网络，能量上限越高越能支撑长时间作业"},
	{"id": "deep_net_raid", "name": "深网渗透", "duration_seconds": 3000, "base_reward": 333, "affinity_stat": "attack_power", "affinity_name": "攻击力", "description": "突袭深网数据堡垒，火力越强战果越丰厚"},
]

## 派遣存档合并延迟；默认 0.5 秒，倒计时的高频状态变化只执行一次磁盘写入。
@export_range(0.05, 10.0, 0.05) var save_delay_seconds: float = 0.5

## 进行中委托标识；默认空字符串表示没有派遣，同一时间最多一个进行中委托。
var _active_mission_id: String = ""
## 进行中委托的角色标识；默认空字符串，该角色在委托结束前无法在角色选择页确认。
var _active_character_id: String = ""
## 进行中委托的角色显示名；默认空字符串，交付与报告文本直接使用避免重复查询档案。
var _active_character_name: String = ""
## 进行中委托剩余在线秒数；默认 0，仅在游戏进程运行时递减，归零后自动交付。
var _active_remaining_seconds: float = 0.0
## 进行中委托锁定报酬；默认 0，签订时按基础报酬乘佣兵联络站加成向下取整确定。
var _active_reward_amount: int = 0
## 进行中委托大成功概率；默认 0，签订时按角色适性属性锁定，交付时按该概率判定。
var _active_crit_chance: float = 0.0
## 进行中委托表；以角色 ID 为键，每条记录独立保存任务、角色、剩余时间、锁定报酬与大成功概率，实现多角色并行派遣。
var _active_dispatches: Dictionary = {}
## 最近一次完成报告；默认空字典，交付后写入并持久化，面板据此展示上次委托结果。
var _last_report: Dictionary = {}
## 近期完成报告；按完成时间倒序保存，默认空数组，最多保留 RECENT_REPORT_LIMIT 条供多委托结果追溯。
var _recent_reports: Array[Dictionary] = []
## 是否已有存档等待执行；默认 false，用于合并高频倒计时写盘。
var _save_queued: bool = false
## 战斗期间是否有派遣存档被挂起；默认 false，战斗中只置位该标志不落盘，战斗结束或退出时统一补写。
var _combat_save_pending: bool = false
## 服务随机数生成器；负责大成功判定，启动时随机化。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 全局库存服务缓存；默认从 Autoload 获取，只用于报酬星穹的发放。
var _global_inventory: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random.randomize()
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if not _load_state():
		_save_state()
	# 战斗状态信号；与其他局外服务使用同一机制监听正式对局边界，战斗结束时统一补写挂起存档。
	if _global_inventory != null and _global_inventory.has_signal("run_state_changed"):
		_global_inventory.connect("run_state_changed", Callable(self, "_on_run_state_changed"))
	set_process(true)


func _process(delta: float) -> void:
	if not has_active_dispatch():
		return
	# 本帧完成的角色标识；先完整推进所有委托，再批量结算，避免字典遍历时修改集合。
	var completed_character_ids: Array[String] = []
	# 经过标准化的在线时间增量；负数增量不影响任何委托计时。
	var elapsed_seconds: float = maxf(delta, 0.0)
	for raw_character_id in _active_dispatches.keys():
		# 当前角色的委托记录；异常条目跳过并在下次存档时由加载校验清理。
		var character_id: String = str(raw_character_id)
		var dispatch: Dictionary = _active_dispatches.get(character_id, {}) as Dictionary
		if dispatch.is_empty():
			continue
		# 新的剩余在线时间；所有角色使用同一帧增量独立递减。
		var remaining_seconds: float = maxf(float(dispatch.get("remaining_seconds", 0.0)) - elapsed_seconds, 0.0)
		dispatch["remaining_seconds"] = remaining_seconds
		_active_dispatches[character_id] = dispatch
		if remaining_seconds <= 0.0:
			completed_character_ids.append(character_id)
	if completed_character_ids.is_empty():
		_sync_legacy_active_cache()
		_queue_save()
		return
	completed_character_ids.sort()
	_complete_dispatches(completed_character_ids)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()
	elif what == NOTIFICATION_EXIT_TREE and (_save_queued or _combat_save_pending):
		# 服务退出兜底；不发送窗口关闭通知的退出路径也会补写尚未落盘的派遣状态。
		_save_state()


func get_mission_definitions() -> Array[Dictionary]:
	return MISSION_DEFINITIONS.duplicate(true)


func has_active_dispatch() -> bool:
	## 查询是否存在进行中委托；同一时间最多一个派遣，签订入口据此禁用。
	# 多角色并行扩展：存在任意角色委托即返回 true，保留原有方法签名供旧调用方兼容使用。
	return not _active_dispatches.is_empty()


func is_character_dispatched(character_id: String) -> bool:
	## 查询指定角色是否处于派遣中；角色选择页据此锁定确认按钮，派遣面板据此标注状态。
	return _active_dispatches.has(character_id.strip_edges())


func get_active_dispatch_snapshots() -> Array[Dictionary]:
	## 返回所有进行中委托快照；按角色 ID 排序，供面板稳定渲染多张进行中委托卡片。
	var character_ids: Array[String] = []
	for raw_character_id in _active_dispatches.keys():
		# 角色标识；统一转为字符串并排序，避免字典迭代顺序改变 UI 展示顺序。
		var character_id: String = str(raw_character_id)
		character_ids.append(character_id)
	character_ids.sort()
	# 有效快照集合；无效任务定义不会向 UI 暴露，并将在后续存档加载时被清理。
	var snapshots: Array[Dictionary] = []
	for character_id in character_ids:
		# 角色对应的委托记录；每名角色最多拥有一条记录。
		var dispatch: Dictionary = _active_dispatches.get(character_id, {}) as Dictionary
		var snapshot: Dictionary = _build_dispatch_snapshot(dispatch)
		if not snapshot.is_empty():
			snapshots.append(snapshot)
	return snapshots


func get_active_dispatch_snapshot() -> Dictionary:
	## 返回进行中委托快照；无委托时返回空字典，面板据此渲染倒计时、角色与预期报酬。
	# 多角色并行扩展：旧调用方仍读取排序后的首条快照，新面板改用 get_active_dispatch_snapshots()。
	var snapshots: Array[Dictionary] = get_active_dispatch_snapshots()
	if snapshots.is_empty():
		return {}
	return snapshots.front().duplicate(true)


func get_last_report() -> Dictionary:
	## 读取最近一次完成报告；报告保留到下一次签订委托时清空，面板可重复读取展示。
	return _last_report.duplicate(true)


func get_recent_reports() -> Array[Dictionary]:
	## 返回近期完成报告；按完成时间倒序，供未来报告列表或记录页读取，不会暴露内部可变数组。
	return _recent_reports.duplicate(true)


func get_crit_chance_for_character(mission_id: String, character_id: String) -> float:
	## 返回指定角色执行指定委托的大成功概率预览；签订时按同一公式锁定。
	var definition: Dictionary = _get_mission_definition(mission_id)
	if definition.is_empty():
		return 0.0
	# 角色适性属性值；从会话服务的角色档案读取，档案缺失时按基准值处理。
	var attribute_value: float = _get_character_attribute(character_id, str(definition.get("affinity_stat", "")))
	return clampf(CRIT_CHANCE_BASE + (attribute_value - CRIT_CHANCE_ATTRIBUTE_BASELINE) * CRIT_CHANCE_PER_ATTRIBUTE_POINT, CRIT_CHANCE_MINIMUM, CRIT_CHANCE_MAXIMUM)


func get_quoted_reward(mission_id: String) -> int:
	## 返回指定委托当前的报酬报价；基础报酬乘佣兵联络站加成向下取整，只在签订瞬间锁定。
	var definition: Dictionary = _get_mission_definition(mission_id)
	if definition.is_empty():
		return 0
	# 据点服务；缺失时按无加成处理，派遣仍可独立运行。
	var hideout_service: Node = get_tree().root.get_node_or_null("HideoutService")
	# 报酬加成比例；由佣兵联络站等级换算，最高 20%。
	var bonus_ratio: float = float(hideout_service.call("get_dispatch_reward_bonus_ratio")) if hideout_service != null and hideout_service.has_method("get_dispatch_reward_bonus_ratio") else 0.0
	return int(floor(float(int(definition.get("base_reward", 0))) * (1.0 + maxf(bonus_ratio, 0.0))))


func get_dispatchable_character_ids() -> Array[String]:
	## 返回当前可参与派遣展示的已解锁角色；当前上场角色仍会返回，但签订时会被拒绝。
	# 会话状态服务；缺失时返回空列表，面板显示无可派遣角色。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null or not session_state.has_method("get_character_ids"):
		return []
	return session_state.call("get_character_ids") as Array[String]


func start_dispatch(mission_id: String, character_id: String) -> Dictionary:
	## 签订一次派遣委托；锁定角色与报酬并进入在线倒计时，到期自动交付，中途不可召回。
	var definition: Dictionary = _get_mission_definition(mission_id)
	if definition.is_empty():
		return {"success": false, "message": "委托类型无效"}
	# 标准化角色标识；避免空白字符造成锁定状态与角色选择页不一致。
	var normalized_character_id: String = character_id.strip_edges()
	if normalized_character_id.is_empty():
		return {"success": false, "message": "角色标识无效"}
	# 多角色并行校验：全局不再限制一条委托，但同一角色不能重复签订。
	if is_character_dispatched(normalized_character_id):
		return {"success": false, "message": "该角色已有进行中的派遣委托"}
	# 会话状态服务；负责角色解锁校验与当前上场角色判断。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null or not session_state.has_method("is_character_unlocked"):
		return {"success": false, "message": "角色服务不可用"}
	if not bool(session_state.call("is_character_unlocked", normalized_character_id)):
		return {"success": false, "message": "角色尚未解锁"}
	if session_state.has_method("get_selected_character_id") and str(session_state.call("get_selected_character_id")) == normalized_character_id:
		return {"success": false, "message": "当前上场角色无法派遣"}
	# 新委托的角色显示名；签订时锁定，完成报告不依赖角色目录之后是否变更。
	var character_name: String = str(session_state.call("get_character_display_name", normalized_character_id)) if session_state.has_method("get_character_display_name") else normalized_character_id
	# 新委托的在线时长；由任务定义提供，最少保留一秒避免非法零时长状态。
	var remaining_seconds: float = maxf(float(int(definition.get("duration_seconds", 0))), 1.0)
	# 新委托的报价；据点联络站加成仅在签订瞬间锁定。
	var reward_amount: int = get_quoted_reward(mission_id)
	# 新委托的大成功概率；按角色适性属性在签订瞬间锁定。
	var crit_chance: float = get_crit_chance_for_character(mission_id, normalized_character_id)
	_active_dispatches[normalized_character_id] = {
		"mission_id": mission_id,
		"character_id": normalized_character_id,
		"character_name": character_name,
		"remaining_seconds": remaining_seconds,
		"reward_amount": reward_amount,
		"crit_chance": crit_chance,
	}
	_sync_legacy_active_cache()
	# 新委托开始后清空上一份完成报告；面板的报告卡片让位给进行中委托卡片。
	# 多角色并行扩展：保留近期报告，避免另一名角色完成的结果因新签订被意外抹除。
	_queue_save()
	dispatch_changed.emit()
	return {"success": true, "message": "派遣已出发", "mission_id": mission_id, "character_id": normalized_character_id, "reward": reward_amount, "crit_chance": crit_chance}


func _complete_active_dispatch() -> void:
	## 完成进行中委托；判定大成功、发放报酬、写入完成报告并广播完成信号供横幅提醒。
	# 兼容旧的单条完成入口：委托缓存存在时，按该缓存角色交给多委托结算流程。
	if not _active_character_id.is_empty():
		_complete_dispatches([_active_character_id])


func _complete_dispatches(completed_character_ids: Array[String]) -> void:
	## 批量结算到期委托；每条委托独立判定大成功，但共享一次存档落盘以保证同帧完成的一致性。
	# 本批次完成报告；用于在统一保存后依次发送每名角色的横幅通知。
	var completion_reports: Array[Dictionary] = []
	for character_id in completed_character_ids:
		# 单名角色的完成报告；无效或已被移除的委托返回空字典，不重复结算。
		var report: Dictionary = _complete_dispatch(character_id)
		if not report.is_empty():
			completion_reports.append(report)
	if completion_reports.is_empty():
		return
	_sync_legacy_active_cache()
	if _is_combat_run_active():
		# 战斗期间交付；只做内存结算并挂起写盘，战斗结束或退出路径统一落盘。
		_queue_save()
	else:
		_flush_linked_saves()
	dispatch_changed.emit()
	for report in completion_reports:
		# 完成通知的实际报酬与说明；逐条发射，确保横幅不会吞掉并行完成的角色结果。
		var payout: int = int(report.get("reward", 0))
		var report_message: String = str(report.get("message", ""))
		dispatch_completed.emit(payout, report_message)


func _complete_dispatch(character_id: String) -> Dictionary:
	## 结算单名角色的到期委托；生成报告、发放星穹并从进行中表移除，调用方负责统一落盘与发信号。
	# 角色对应的委托记录；不存在时代表已由其他路径结算，直接忽略。
	var dispatch: Dictionary = _active_dispatches.get(character_id, {}) as Dictionary
	if dispatch.is_empty():
		return {}
	# 委托定义；定义缺失时不发放报酬，直接清理损坏记录防止无限卡住。
	var definition: Dictionary = _get_mission_definition(str(dispatch.get("mission_id", "")))
	if definition.is_empty():
		_active_dispatches.erase(character_id)
		return {}
	# 是否大成功；按签订时锁定的概率一次性判定。
	var is_critical: bool = _random.randf() < float(dispatch.get("crit_chance", 0.0))
	# 原始锁定报酬；异常负值按零处理，防止损坏存档产生扣款。
	var base_payout: int = maxi(int(dispatch.get("reward_amount", 0)), 0)
	# 实际到账报酬；大成功按倍率放大后向下取整。
	var payout: int = int(floor(float(base_payout) * CRIT_REWARD_MULTIPLIER)) if is_critical else base_payout
	# 完成角色显示名；优先使用签订时锁定名称，保证报告与委托开始时一致。
	var character_name: String = str(dispatch.get("character_name", character_id))
	# 完成说明文本；同时用于报告、完成信号与横幅通知。
	var report_message: String = "%s完成「%s」%s，报酬 %d 星穹" % [character_name, str(definition.get("name", "派遣委托")), "（大成功 ×1.5）" if is_critical else "", payout]
	# 完成报告；保留任务与角色标识，便于未来完整报告列表精确追溯来源。
	var report: Dictionary = {
		"mission_id": str(definition.get("id", "")),
		"mission_name": str(definition.get("name", "派遣委托")),
		"character_id": character_id,
		"character_name": character_name,
		"reward": payout,
		"critical": is_critical,
		"message": report_message,
	}
	_active_dispatches.erase(character_id)
	_recent_reports.push_front(report)
	while _recent_reports.size() > RECENT_REPORT_LIMIT:
		_recent_reports.pop_back()
	_last_report = report.duplicate(true)
	if _global_inventory != null and _global_inventory.has_method("adjust_coins"):
		_global_inventory.call("adjust_coins", payout)
	return report


func _build_dispatch_snapshot(dispatch: Dictionary) -> Dictionary:
	## 将内部委托记录转换为只读展示快照；任务名称和总时长始终以当前定义表为准，避免 UI 依赖内部状态结构。
	# 委托标识；定义缺失时返回空快照，不让无效存档数据进入 UI。
	var mission_id: String = str(dispatch.get("mission_id", ""))
	var definition: Dictionary = _get_mission_definition(mission_id)
	if definition.is_empty():
		return {}
	# 角色标识；内部字典按角色 ID 存储，快照也必须包含非空 ID 才能用于倒计时标签映射。
	var character_id: String = str(dispatch.get("character_id", ""))
	if character_id.is_empty():
		return {}
	return {
		"mission_id": mission_id,
		"mission_name": str(definition.get("name", "派遣委托")),
		"character_id": character_id,
		"character_name": str(dispatch.get("character_name", character_id)),
		"remaining_seconds": maxf(float(dispatch.get("remaining_seconds", 0.0)), 0.0),
		"duration_seconds": int(definition.get("duration_seconds", 0)),
		"reward_amount": maxi(int(dispatch.get("reward_amount", 0)), 0),
		"crit_chance": clampf(float(dispatch.get("crit_chance", 0.0)), 0.0, 1.0),
	}


func _sync_legacy_active_cache() -> void:
	## 同步旧单委托字段；保留历史公开接口和旧存档迁移所需的首条委托缓存，不作为多委托逻辑的数据源。
	# 排序后的首条快照；空快照表示当前没有任何有效进行中委托。
	var snapshot: Dictionary = get_active_dispatch_snapshot()
	if snapshot.is_empty():
		_active_mission_id = ""
		_active_character_id = ""
		_active_character_name = ""
		_active_remaining_seconds = 0.0
		_active_reward_amount = 0
		_active_crit_chance = 0.0
		return
	_active_mission_id = str(snapshot.get("mission_id", ""))
	_active_character_id = str(snapshot.get("character_id", ""))
	_active_character_name = str(snapshot.get("character_name", ""))
	_active_remaining_seconds = float(snapshot.get("remaining_seconds", 0.0))
	_active_reward_amount = int(snapshot.get("reward_amount", 0))
	_active_crit_chance = float(snapshot.get("crit_chance", 0.0))


func _get_character_attribute(character_id: String, attribute_name: String) -> float:
	## 读取角色档案中的指定基础属性；档案或字段缺失时返回基准值，保持概率公式中性。
	if attribute_name.is_empty():
		return CRIT_CHANCE_ATTRIBUTE_BASELINE
	# 会话状态服务；角色档案统一由该服务提供，包含目录角色与内置回退档案。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null or not session_state.has_method("get_character_profile"):
		return CRIT_CHANCE_ATTRIBUTE_BASELINE
	# 角色档案字典；空档案按基准值处理。
	var profile: Dictionary = session_state.call("get_character_profile", character_id) as Dictionary
	return float(profile.get(attribute_name, CRIT_CHANCE_ATTRIBUTE_BASELINE))


func _get_mission_definition(mission_id: String) -> Dictionary:
	for definition in MISSION_DEFINITIONS:
		if str(definition.get("id", "")) == mission_id:
			return definition
	return {}


func _queue_save() -> void:
	if _is_combat_run_active():
		# 战斗期间挂起写盘；倒计时仍在内存实时递减，磁盘写入统一延迟到战斗结束或退出。
		_combat_save_pending = true
		return
	if _save_queued:
		return
	_save_queued = true
	# 合并计时器；暂停状态继续运行，保证暂停界面期间的委托交付仍能按时落盘。
	var timer: SceneTreeTimer = get_tree().create_timer(maxf(save_delay_seconds, 0.05), true, false, true)
	timer.timeout.connect(_flush_queued_save, CONNECT_ONE_SHOT)


func _flush_queued_save() -> void:
	_save_queued = false
	_save_state()


func _on_run_state_changed() -> void:
	## 正式对局边界回调；战斗结束且存在挂起存档时统一落盘一次，战斗开始不执行任何磁盘操作。
	if not _is_combat_run_active() and _combat_save_pending:
		_save_state()


func _is_combat_run_active() -> bool:
	## 查询当前是否处于正式战斗局；与其他局外服务使用同一 GlobalInventory 状态源。
	return _global_inventory != null and _global_inventory.has_method("is_combat_run_active") and bool(_global_inventory.call("is_combat_run_active"))


func _flush_linked_saves() -> void:
	## 立即保存派遣与星穹存档；报酬发放属于跨文件资产变更，同一路径落盘缩短状态不一致窗口。
	_save_queued = false
	_save_state()
	if _global_inventory != null and _global_inventory.has_method("flush_stock_holdings_save"):
		# 库存即时保存接口会保存完整永久星穹数据，名称虽保留股票历史用途，但可安全复用跨存档兑换。
		_global_inventory.call("flush_stock_holdings_save")


func _save_state() -> void:
	# 任何真实落盘都会消化战斗期间的挂起标志；战斗结束、关闭窗口与联动保存共用该出口。
	_combat_save_pending = false
	# 存档数据；每条委托独立锁定报酬与概率，只保存剩余在线时长而不保存系统时间戳。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"active_dispatches": get_active_dispatch_snapshots(),
		"recent_reports": _recent_reports,
		"last_report": _last_report,
	}
	# 存档文件；失败时保持内存状态，下一次变更仍会再次尝试写入。
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data))
		file.close()


func _load_state() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	# 存档文件；无法打开或 JSON 损坏时回退完整默认状态。
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	# 解析结果；仅接受字典根节点，避免异常结构覆盖服务状态。
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false
	# 存档字典；版本字段为多委托结构迁移保留稳定入口。
	var save_data: Dictionary = parsed as Dictionary
	# 已加载的存档版本；版本 1 使用单条 active_* 字段，版本 2 使用 active_dispatches 数组。
	var save_version: int = int(save_data.get("version", 1))
	# 是否需要立即回写；旧版本迁移、异常条目过滤或缺失列表都会触发一次新结构保存。
	var state_requires_save: bool = save_version < SAVE_VERSION
	_active_dispatches.clear()
	_recent_reports.clear()
	# 新版进行中委托集合；数组中的每条记录均由角色 ID 唯一约束。
	var raw_dispatches: Variant = save_data.get("active_dispatches", [])
	if save_version >= SAVE_VERSION and raw_dispatches is Array:
		for raw_dispatch in raw_dispatches:
			if raw_dispatch is Dictionary:
				if not _restore_active_dispatch(raw_dispatch as Dictionary):
					state_requires_save = true
			else:
				state_requires_save = true
	elif save_version >= SAVE_VERSION and raw_dispatches is Dictionary:
		# 防御性兼容：早期调试版若把多委托写成字典，同样逐条恢复并回写标准数组结构。
		for raw_dispatch in (raw_dispatches as Dictionary).values():
			if raw_dispatch is Dictionary:
				if not _restore_active_dispatch(raw_dispatch as Dictionary):
					state_requires_save = true
			else:
				state_requires_save = true
		state_requires_save = true
	else:
		# 版本 1 单委托迁移；保留原始剩余在线秒数，只把数据形态转换为按角色存储的集合。
		var legacy_dispatch: Dictionary = {
			"mission_id": str(save_data.get("active_mission_id", "")),
			"character_id": str(save_data.get("active_character_id", "")),
			"character_name": str(save_data.get("active_character_name", "")),
			"remaining_seconds": float(save_data.get("active_remaining_seconds", 0.0)),
			"reward_amount": int(save_data.get("active_reward_amount", 0)),
			"crit_chance": float(save_data.get("active_crit_chance", 0.0)),
		}
		if not str(legacy_dispatch.get("mission_id", "")).is_empty() and not _restore_active_dispatch(legacy_dispatch):
			state_requires_save = true
		state_requires_save = true
	# 新版近期完成报告；非字典条目直接丢弃，避免报告 UI 因损坏存档报错。
	var raw_recent_reports: Variant = save_data.get("recent_reports", [])
	if raw_recent_reports is Array:
		for raw_report in raw_recent_reports:
			if raw_report is Dictionary:
				_recent_reports.append((raw_report as Dictionary).duplicate(true))
			else:
				state_requires_save = true
	while _recent_reports.size() > RECENT_REPORT_LIMIT:
		_recent_reports.pop_back()
		state_requires_save = true
	# 原始完成报告；非字典结构按空报告处理。
	var raw_report: Variant = save_data.get("last_report", {})
	_last_report = (raw_report as Dictionary).duplicate(true) if raw_report is Dictionary else {}
	if _recent_reports.is_empty() and not _last_report.is_empty():
		_recent_reports.append(_last_report.duplicate(true))
		state_requires_save = true
	elif not _recent_reports.is_empty():
		_last_report = _recent_reports.front().duplicate(true)
	_sync_legacy_active_cache()
	if state_requires_save:
		_queue_save()
	return true


func _restore_active_dispatch(raw_dispatch: Dictionary) -> bool:
	## 从存档恢复单条委托；仅接受任务、角色、剩余时间和锁定报酬均有效且角色未重复的记录。
	# 标准化后的任务标识；任务定义缺失说明存档无法安全结算该委托。
	var mission_id: String = str(raw_dispatch.get("mission_id", "")).strip_edges()
	if _get_mission_definition(mission_id).is_empty():
		return false
	# 标准化后的角色标识；空角色或重复角色会破坏一人一委托约束，因此拒绝恢复。
	var character_id: String = str(raw_dispatch.get("character_id", "")).strip_edges()
	if character_id.is_empty() or _active_dispatches.has(character_id):
		return false
	# 剩余在线秒数；归零与负数记录应视为已失效，读档时不补发报酬。
	var remaining_seconds: float = maxf(float(raw_dispatch.get("remaining_seconds", 0.0)), 0.0)
	if remaining_seconds <= 0.0:
		return false
	# 签订时锁定的报酬；零或负数记录无法构成有效派遣。
	var reward_amount: int = maxi(int(raw_dispatch.get("reward_amount", 0)), 0)
	if reward_amount <= 0:
		return false
	# 签订时锁定的大成功概率；读取时限制在合法概率范围。
	var crit_chance: float = clampf(float(raw_dispatch.get("crit_chance", 0.0)), 0.0, 1.0)
	# 签订时锁定的显示名；缺失时使用角色 ID，保证完成报告仍有可读主体。
	var character_name: String = str(raw_dispatch.get("character_name", character_id)).strip_edges()
	_active_dispatches[character_id] = {
		"mission_id": mission_id,
		"character_id": character_id,
		"character_name": character_name if not character_name.is_empty() else character_id,
		"remaining_seconds": remaining_seconds,
		"reward_amount": reward_amount,
		"crit_chance": crit_chance,
	}
	return true
