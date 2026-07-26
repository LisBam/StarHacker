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
## 派遣存档版本；版本 1 保存进行中委托、锁定报酬、剩余在线时长与最近一次完成报告。
const SAVE_VERSION: int = 1
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
const MISSION_DEFINITIONS: Array[Dictionary] = [
	{"id": "intel_sweep", "name": "情报收集", "duration_seconds": 1800, "base_reward": 150, "affinity_stat": "move_speed", "affinity_name": "移动速度", "description": "潜入街区搜集骇入情报，脚程越快越不容易暴露"},
	{"id": "relic_escort", "name": "遗迹护送", "duration_seconds": 7200, "base_reward": 700, "affinity_stat": "defense_power", "affinity_name": "防御力", "description": "护送勘探商队穿越遗迹，防御越高越能扛住伏击"},
	{"id": "deep_net_raid", "name": "深网渗透", "duration_seconds": 21600, "base_reward": 2400, "affinity_stat": "attack_power", "affinity_name": "攻击力", "description": "突袭深网数据堡垒，火力越强战果越丰厚"},
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
## 最近一次完成报告；默认空字典，交付后写入并持久化，面板据此展示上次委托结果。
var _last_report: Dictionary = {}
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
	_active_remaining_seconds = maxf(_active_remaining_seconds - maxf(delta, 0.0), 0.0)
	if _active_remaining_seconds <= 0.0:
		_complete_active_dispatch()


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
	return not _active_mission_id.is_empty()


func is_character_dispatched(character_id: String) -> bool:
	## 查询指定角色是否处于派遣中；角色选择页据此锁定确认按钮，派遣面板据此标注状态。
	return has_active_dispatch() and _active_character_id == character_id.strip_edges()


func get_active_dispatch_snapshot() -> Dictionary:
	## 返回进行中委托快照；无委托时返回空字典，面板据此渲染倒计时、角色与预期报酬。
	if not has_active_dispatch():
		return {}
	# 委托定义；进行中委托的标识在签订与加载时都已经过校验，此处必定存在。
	var definition: Dictionary = _get_mission_definition(_active_mission_id)
	return {
		"mission_id": _active_mission_id,
		"mission_name": str(definition.get("name", "派遣委托")),
		"character_id": _active_character_id,
		"character_name": _active_character_name,
		"remaining_seconds": _active_remaining_seconds,
		"duration_seconds": int(definition.get("duration_seconds", 0)),
		"reward_amount": _active_reward_amount,
		"crit_chance": _active_crit_chance,
	}


func get_last_report() -> Dictionary:
	## 读取最近一次完成报告；报告保留到下一次签订委托时清空，面板可重复读取展示。
	return _last_report.duplicate(true)


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
	if has_active_dispatch():
		return {"success": false, "message": "已有进行中的派遣委托"}
	# 标准化角色标识；避免空白字符造成锁定状态与角色选择页不一致。
	var normalized_character_id: String = character_id.strip_edges()
	# 会话状态服务；负责角色解锁校验与当前上场角色判断。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null or not session_state.has_method("is_character_unlocked"):
		return {"success": false, "message": "角色服务不可用"}
	if not bool(session_state.call("is_character_unlocked", normalized_character_id)):
		return {"success": false, "message": "角色尚未解锁"}
	if session_state.has_method("get_selected_character_id") and str(session_state.call("get_selected_character_id")) == normalized_character_id:
		return {"success": false, "message": "当前上场角色无法派遣"}
	_active_mission_id = mission_id
	_active_character_id = normalized_character_id
	_active_character_name = str(session_state.call("get_character_display_name", normalized_character_id)) if session_state.has_method("get_character_display_name") else normalized_character_id
	_active_remaining_seconds = maxf(float(int(definition.get("duration_seconds", 0))), 1.0)
	_active_reward_amount = get_quoted_reward(mission_id)
	_active_crit_chance = get_crit_chance_for_character(mission_id, normalized_character_id)
	# 新委托开始后清空上一份完成报告；面板的报告卡片让位给进行中委托卡片。
	_last_report.clear()
	_queue_save()
	dispatch_changed.emit()
	return {"success": true, "message": "派遣已出发", "mission_id": mission_id, "character_id": normalized_character_id, "reward": _active_reward_amount, "crit_chance": _active_crit_chance}


func _complete_active_dispatch() -> void:
	## 完成进行中委托；判定大成功、发放报酬、写入完成报告并广播完成信号供横幅提醒。
	# 委托定义；用于报告文本中的委托名称。
	var definition: Dictionary = _get_mission_definition(_active_mission_id)
	# 是否大成功；按签订时锁定的概率一次性判定。
	var is_critical: bool = _random.randf() < _active_crit_chance
	# 实际到账报酬；大成功按倍率放大后向下取整。
	var payout: int = int(floor(float(_active_reward_amount) * CRIT_REWARD_MULTIPLIER)) if is_critical else _active_reward_amount
	# 完成说明文本；同时用于报告、完成信号与横幅通知。
	var report_message: String = "%s完成「%s」%s，报酬 %d 星穹" % [_active_character_name, str(definition.get("name", "派遣委托")), "（大成功 ×1.5）" if is_critical else "", payout]
	_last_report = {
		"mission_name": str(definition.get("name", "派遣委托")),
		"character_name": _active_character_name,
		"reward": payout,
		"critical": is_critical,
		"message": report_message,
	}
	_active_mission_id = ""
	_active_character_id = ""
	_active_character_name = ""
	_active_remaining_seconds = 0.0
	_active_reward_amount = 0
	_active_crit_chance = 0.0
	if _global_inventory != null and _global_inventory.has_method("adjust_coins"):
		_global_inventory.call("adjust_coins", payout)
	if _is_combat_run_active():
		# 战斗期间交付；只做内存结算并挂起写盘，战斗结束或退出路径统一落盘。
		_queue_save()
	else:
		_flush_linked_saves()
	dispatch_changed.emit()
	dispatch_completed.emit(payout, report_message)


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
	# 存档数据；报酬与概率在签订时锁定，计时字段只保存剩余在线时长而不保存系统时间戳。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"active_mission_id": _active_mission_id,
		"active_character_id": _active_character_id,
		"active_character_name": _active_character_name,
		"active_remaining_seconds": _active_remaining_seconds,
		"active_reward_amount": _active_reward_amount,
		"active_crit_chance": _active_crit_chance,
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
	# 存档字典；版本字段为未来迁移保留稳定入口。
	var save_data: Dictionary = parsed as Dictionary
	_active_mission_id = str(save_data.get("active_mission_id", ""))
	_active_character_id = str(save_data.get("active_character_id", ""))
	_active_character_name = str(save_data.get("active_character_name", ""))
	_active_remaining_seconds = maxf(float(save_data.get("active_remaining_seconds", 0.0)), 0.0)
	_active_reward_amount = maxi(int(save_data.get("active_reward_amount", 0)), 0)
	_active_crit_chance = clampf(float(save_data.get("active_crit_chance", 0.0)), 0.0, 1.0)
	if not _active_mission_id.is_empty() and (_get_mission_definition(_active_mission_id).is_empty() or _active_character_id.is_empty() or _active_remaining_seconds <= 0.0 or _active_reward_amount <= 0):
		# 委托数据异常兜底；委托类型被移除或计时数据损坏时直接结束派遣，不发放报酬。
		_active_mission_id = ""
		_active_character_id = ""
		_active_character_name = ""
		_active_remaining_seconds = 0.0
		_active_reward_amount = 0
		_active_crit_chance = 0.0
		_queue_save()
	# 原始完成报告；非字典结构按空报告处理。
	var raw_report: Variant = save_data.get("last_report", {})
	_last_report = (raw_report as Dictionary).duplicate(true) if raw_report is Dictionary else {}
	return true
