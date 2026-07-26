extends Node

## 据点设施建设服务在全部场景中持续运行，统一维护六座局外设施的永久等级、建造队列与独立存档。
## 商店、锻造、矿场、保险、银行与派遣只通过只读加成接口查询设施效果，不反向修改据点状态。
## 设施升级消耗局外星穹并占用在线建造时间；同一时间最多存在一个建造队列，建成后等级永久生效。

## 设施等级变化信号；建造完成使等级提升后发送，面板据此重建设施卡片。
signal facility_levels_changed
## 建造队列状态变化信号；开始建造、建造完成和异常回退时发送，面板据此刷新倒计时与按钮。
signal construction_changed
## 建造完成信号；参数为设施稳定标识与建成后的新等级，横幅通知服务据此在任何场景提醒玩家。
signal construction_completed(facility_id: String, new_level: int)

## 据点独立存档路径；与库存、股市、矿场存档分离，避免设施字段污染其他玩法的序列化结构。
const SAVE_PATH: String = "user://hideout_state.json"
## 据点存档版本；版本 1 保存六座设施的整数等级与进行中建造队列的剩余在线时长。
const SAVE_VERSION: int = 1
## 设施最大等级；默认 5 级，全部设施共用同一上限，达到后升级入口禁用。
const FACILITY_MAX_LEVEL: int = 5
## 各级升级费用倍率；下标 0 对应从 0 级升到 1 级，费用为设施基础造价乘对应倍率。
const LEVEL_COST_MULTIPLIERS: Array[int] = [1, 3, 9, 27, 81]
## 各级建造在线时长；下标 0 对应从 0 级升到 1 级，依次为 5 分钟到 2 小时，只消耗在线时间。
const LEVEL_BUILD_DURATIONS: Array[int] = [300, 900, 1800, 3600, 7200]
## 商店设施每级购买折扣比例；默认 1%，满级共 5%，只作用于商店与灰市的实付价格。
const SHOP_DISCOUNT_RATIO_PER_LEVEL: float = 0.01
## 锻造设施每级费用折扣比例；默认 2%，满级共 10%，作用于锻造总费用。
const FORGE_DISCOUNT_RATIO_PER_LEVEL: float = 0.02
## 矿场设施每级离线收益上限追加秒数；默认 3600 秒即 1 小时，满级把 8 小时上限提高到 13 小时。
const MINING_OFFLINE_BONUS_SECONDS_PER_LEVEL: int = 3600
## 保险设施每级保费费率降低值；默认 0.5 个百分点，把基础 12% 费率最低压到 9.5%。
const INSURANCE_RATE_REDUCTION_PER_LEVEL: float = 0.005
## 银行设施每级定期利率相对加成；默认 4%，满级使定期存单利率乘 1.20，只在签订时锁定。
const BANK_FIXED_RATE_BONUS_PER_LEVEL: float = 0.04
## 派遣设施每级报酬加成比例；默认 4%，满级共 20%，只在委托签订时计入预期报酬。
const DISPATCH_REWARD_BONUS_PER_LEVEL: float = 0.04
## 设施定义表；稳定标识、名称、关联模块、基础造价与效果文案集中维护，UI 只读取公开副本。
const FACILITY_DEFINITIONS: Array[Dictionary] = [
	{"id": "supply_hub", "name": "补给中转站", "module": "商店", "base_cost": 200, "effect_text": "商店与灰市购买价格每级 -1%", "description": "打通稳定补给渠道，压低前线物资采购成本"},
	{"id": "forge_workshop", "name": "精工车间", "module": "锻造", "base_cost": 200, "effect_text": "锻造费用每级 -2%", "description": "升级锻造设备，降低耐久修复与强化工费"},
	{"id": "cooling_plant", "name": "散热机房", "module": "矿场", "base_cost": 200, "effect_text": "矿场离线收益上限每级 +1 小时", "description": "扩建机房散热，让矿机离线期间坚持更久"},
	{"id": "actuarial_office", "name": "精算办公室", "module": "保险", "base_cost": 200, "effect_text": "骇入保险保费费率每级 -0.5%", "description": "雇佣专业精算师，为骇客争取更低保费"},
	{"id": "vault", "name": "星海金库", "module": "银行", "base_cost": 200, "effect_text": "定期存单利率每级 +4%（相对）", "description": "加固金库信用评级，换取更优存款利率"},
	{"id": "mercenary_office", "name": "佣兵联络站", "module": "派遣", "base_cost": 200, "effect_text": "派遣委托报酬每级 +4%", "description": "拓展佣兵人脉网络，接到报酬更高的委托"},
]

## 据点存档合并延迟；默认 0.5 秒，建造倒计时的高频状态变化只执行一次磁盘写入。
@export_range(0.05, 10.0, 0.05) var save_delay_seconds: float = 0.5

## 设施等级表；键为稳定设施标识，值为 0 到最大等级的整数，只能通过建造完成提升。
var _facility_levels: Dictionary = {}
## 进行中建造设施标识；默认空字符串表示没有建造队列，同一时间最多一个建造中设施。
var _active_construction_id: String = ""
## 进行中建造剩余在线秒数；默认 0，仅在游戏进程运行时递减，归零后自动完成建造。
var _construction_remaining_seconds: float = 0.0
## 进行中建造的目标等级；默认 0，建造完成后设施等级直接写入该值。
var _construction_target_level: int = 0
## 进行中建造已支付的星穹费用；默认 0，仅用于存档数据异常时的退款兜底。
var _construction_locked_cost: int = 0
## 是否已有存档等待执行；默认 false，用于合并高频建造倒计时写盘。
var _save_queued: bool = false
## 战斗期间是否有据点存档被挂起；默认 false，战斗中只置位该标志不落盘，战斗结束或退出时统一补写。
var _combat_save_pending: bool = false
## 全局库存服务缓存；默认从 Autoload 获取，只用于星穹的原子扣除与异常退款。
var _global_inventory: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_initialize_default_state()
	if not _load_state():
		_save_state()
	# 战斗状态信号；与矿场服务使用同一机制监听正式对局边界，战斗结束时统一补写挂起存档。
	if _global_inventory != null and _global_inventory.has_signal("run_state_changed"):
		_global_inventory.connect("run_state_changed", Callable(self, "_on_run_state_changed"))
	set_process(true)


func _process(delta: float) -> void:
	if not has_active_construction():
		return
	_construction_remaining_seconds = maxf(_construction_remaining_seconds - maxf(delta, 0.0), 0.0)
	if _construction_remaining_seconds <= 0.0:
		_complete_active_construction()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()
	elif what == NOTIFICATION_EXIT_TREE and (_save_queued or _combat_save_pending):
		# 服务退出兜底；主菜单 quit 等不发送窗口关闭通知的退出路径也会补写尚未落盘的据点状态。
		_save_state()


func get_facility_definitions() -> Array[Dictionary]:
	return FACILITY_DEFINITIONS.duplicate(true)


func get_facility_level(facility_id: String) -> int:
	## 返回指定设施的当前永久等级；未记录时按 0 级处理，等级只能通过建造完成提升。
	return clampi(int(_facility_levels.get(facility_id, 0)), 0, FACILITY_MAX_LEVEL)


func get_upgrade_cost(facility_id: String) -> int:
	## 返回指定设施升到下一级所需星穹；已满级或设施无效时返回 0。
	var definition: Dictionary = _get_facility_definition(facility_id)
	# 当前设施等级；同时作为费用倍率表下标，满级后不存在下一级费用。
	var current_level: int = get_facility_level(facility_id)
	if definition.is_empty() or current_level >= FACILITY_MAX_LEVEL:
		return 0
	return int(definition.get("base_cost", 0)) * LEVEL_COST_MULTIPLIERS[current_level]


func get_upgrade_duration_seconds(facility_id: String) -> int:
	## 返回指定设施升到下一级所需的在线建造秒数；已满级或设施无效时返回 0。
	# 当前设施等级；同时作为建造时长表下标。
	var current_level: int = get_facility_level(facility_id)
	if _get_facility_definition(facility_id).is_empty() or current_level >= FACILITY_MAX_LEVEL:
		return 0
	return LEVEL_BUILD_DURATIONS[current_level]


func has_active_construction() -> bool:
	## 查询是否存在进行中建造；同一时间最多允许一个建造队列，升级入口据此禁用。
	return not _active_construction_id.is_empty()


func get_active_construction_snapshot() -> Dictionary:
	## 返回进行中建造快照；无建造时返回空字典，面板据此渲染倒计时与目标等级。
	if not has_active_construction():
		return {}
	# 建造设施定义；进行中建造的标识在开始与加载时都已经过校验，此处必定存在。
	var definition: Dictionary = _get_facility_definition(_active_construction_id)
	return {
		"facility_id": _active_construction_id,
		"name": str(definition.get("name", "据点设施")),
		"remaining_seconds": _construction_remaining_seconds,
		"target_level": _construction_target_level,
		"locked_cost": _construction_locked_cost,
	}


func start_upgrade(facility_id: String) -> Dictionary:
	## 开始一次设施升级建造；立即扣除星穹费用并进入在线倒计时，建成前效果不生效且不可撤销。
	var definition: Dictionary = _get_facility_definition(facility_id)
	if definition.is_empty():
		return {"success": false, "message": "设施无效"}
	if has_active_construction():
		return {"success": false, "message": "已有进行中的建造队列"}
	# 当前设施等级；确认瞬间重新读取，防止连续弹窗导致越级建造。
	var current_level: int = get_facility_level(facility_id)
	if current_level >= FACILITY_MAX_LEVEL:
		return {"success": false, "message": "设施已达到最大等级"}
	# 本次升级费用；按设施基础造价乘当前等级对应倍率。
	var cost: int = get_upgrade_cost(facility_id)
	if _global_inventory == null or not _global_inventory.has_method("spend_coins"):
		return {"success": false, "message": "星穹服务不可用"}
	if not bool(_global_inventory.call("spend_coins", cost)):
		return {"success": false, "message": "星穹不足，无法开始建造"}
	_active_construction_id = facility_id
	_construction_remaining_seconds = maxf(float(get_upgrade_duration_seconds(facility_id)), 1.0)
	_construction_target_level = current_level + 1
	_construction_locked_cost = cost
	_flush_linked_saves()
	construction_changed.emit()
	return {"success": true, "message": "建造已开始", "facility_id": facility_id, "cost": cost, "target_level": current_level + 1}


func get_shop_discount_ratio() -> float:
	## 返回商店与灰市当前的购买折扣比例；补给中转站每级 1%，满级 5%，商店服务在实付时调用。
	return SHOP_DISCOUNT_RATIO_PER_LEVEL * float(get_facility_level("supply_hub"))


func get_forge_discount_ratio() -> float:
	## 返回锻造费用当前的折扣比例；精工车间每级 2%，满级 10%，锻造服务在费用公式中调用。
	return FORGE_DISCOUNT_RATIO_PER_LEVEL * float(get_facility_level("forge_workshop"))


func get_mining_offline_bonus_seconds() -> int:
	## 返回矿场离线收益上限的追加秒数；散热机房每级 1 小时，矿场服务在启动补发时调用。
	return MINING_OFFLINE_BONUS_SECONDS_PER_LEVEL * get_facility_level("cooling_plant")


func get_insurance_rate_reduction() -> float:
	## 返回骇入保险保费费率的降低值；精算办公室每级 0.5 个百分点，保险服务在投保报价时调用。
	return INSURANCE_RATE_REDUCTION_PER_LEVEL * float(get_facility_level("actuarial_office"))


func get_bank_fixed_rate_multiplier() -> float:
	## 返回银行定期存单利率的相对倍率；星海金库每级 +4%，银行服务只在签订存单时锁定该值。
	return 1.0 + BANK_FIXED_RATE_BONUS_PER_LEVEL * float(get_facility_level("vault"))


func get_dispatch_reward_bonus_ratio() -> float:
	## 返回派遣委托报酬的加成比例；佣兵联络站每级 4%，派遣服务只在委托签订时锁定该值。
	return DISPATCH_REWARD_BONUS_PER_LEVEL * float(get_facility_level("mercenary_office"))


func _complete_active_construction() -> void:
	## 完成进行中建造；清空建造队列并把设施等级提升到目标等级，随后广播完成信号供横幅提醒。
	# 本次建成设施标识；先取出再清空状态，防止信号回调期间重复结算。
	var facility_id: String = _active_construction_id
	# 本次建成后的新等级；受最大等级钳制，异常目标值不会越过上限。
	var new_level: int = clampi(_construction_target_level, 0, FACILITY_MAX_LEVEL)
	_active_construction_id = ""
	_construction_remaining_seconds = 0.0
	_construction_target_level = 0
	_construction_locked_cost = 0
	_facility_levels[facility_id] = maxi(get_facility_level(facility_id), new_level)
	_queue_save()
	facility_levels_changed.emit()
	construction_changed.emit()
	construction_completed.emit(facility_id, new_level)


func _get_facility_definition(facility_id: String) -> Dictionary:
	for definition in FACILITY_DEFINITIONS:
		if str(definition.get("id", "")) == facility_id:
			return definition
	return {}


func _initialize_default_state() -> void:
	_facility_levels.clear()
	_active_construction_id = ""
	_construction_remaining_seconds = 0.0
	_construction_target_level = 0
	_construction_locked_cost = 0
	for definition in FACILITY_DEFINITIONS:
		# 默认设施标识；全部设施从 0 级开始，没有初始建造队列。
		var facility_id: String = str(definition.get("id", ""))
		_facility_levels[facility_id] = 0


func _queue_save() -> void:
	if _is_combat_run_active():
		# 战斗期间挂起写盘；建造倒计时仍在内存实时递减，磁盘写入统一延迟到战斗结束或退出。
		_combat_save_pending = true
		return
	if _save_queued:
		return
	_save_queued = true
	# 合并计时器；暂停状态继续运行，保证暂停界面期间的建造完成仍能按时落盘。
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
	## 查询当前是否处于正式战斗局；与矿场服务使用同一 GlobalInventory 状态源，服务缺失时按局外处理。
	return _global_inventory != null and _global_inventory.has_method("is_combat_run_active") and bool(_global_inventory.call("is_combat_run_active"))


func _flush_linked_saves() -> void:
	## 立即保存据点与星穹存档；建造扣款属于跨文件资产变更，同一路径落盘缩短状态不一致窗口。
	_save_queued = false
	_save_state()
	if _global_inventory != null and _global_inventory.has_method("flush_stock_holdings_save"):
		# 库存即时保存接口会保存完整永久星穹数据，名称虽保留股票历史用途，但可安全复用跨存档兑换。
		_global_inventory.call("flush_stock_holdings_save")


func _save_state() -> void:
	# 任何真实落盘都会消化战斗期间的挂起标志；战斗结束、关闭窗口与联动保存共用该出口。
	_combat_save_pending = false
	# 存档数据；设施等级为整数，建造队列只保存剩余在线时长而不保存系统时间戳。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"facility_levels": _facility_levels,
		"active_construction_id": _active_construction_id,
		"construction_remaining_seconds": _construction_remaining_seconds,
		"construction_target_level": _construction_target_level,
		"construction_locked_cost": _construction_locked_cost,
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
	# 已保存等级表；逐个官方设施读取，未知设施不会进入运行时状态。
	var saved_levels: Dictionary = save_data.get("facility_levels", {}) as Dictionary
	for definition in FACILITY_DEFINITIONS:
		# 设施标识；用于从存档表恢复同一设施的等级。
		var facility_id: String = str(definition.get("id", ""))
		_facility_levels[facility_id] = clampi(int(saved_levels.get(facility_id, 0)), 0, FACILITY_MAX_LEVEL)
	_active_construction_id = str(save_data.get("active_construction_id", ""))
	_construction_remaining_seconds = maxf(float(save_data.get("construction_remaining_seconds", 0.0)), 0.0)
	_construction_target_level = clampi(int(save_data.get("construction_target_level", 0)), 0, FACILITY_MAX_LEVEL)
	_construction_locked_cost = maxi(int(save_data.get("construction_locked_cost", 0)), 0)
	if not _active_construction_id.is_empty() and (_get_facility_definition(_active_construction_id).is_empty() or _construction_remaining_seconds <= 0.0 or _construction_target_level <= 0):
		# 建造数据异常兜底；设施被移除或计时数据损坏时退还已支付星穹并清空队列，不提升等级。
		if _global_inventory != null and _global_inventory.has_method("adjust_coins") and _construction_locked_cost > 0:
			_global_inventory.call("adjust_coins", _construction_locked_cost)
		_active_construction_id = ""
		_construction_remaining_seconds = 0.0
		_construction_target_level = 0
		_construction_locked_cost = 0
		_queue_save()
	return true
