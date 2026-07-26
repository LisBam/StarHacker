extends Node

## 星海银行服务在全部场景中持续运行，统一维护活期账户、定期存单、信用贷款与独立存档。
## 银行定位为与股市（高风险）、矿场（挂机）互补的“保本与杠杆”出口：活期低息随存随取，
## 定期锁仓换取更高利率且签订时按大盘周期锁定，信用贷款按总资产授信、到期自动级联扣款。
## 星穹所有权仍由 GlobalInventory 持有；证券币与算力币的违约抵扣通过对应服务公开接口执行。

## 活期账户变化信号；存入、取出与利息到账后发送，银行面板据此刷新余额展示。
signal account_changed(balance: int)
## 定期存单状态变化信号；签订、到期和异常回退时发送，面板据此重建定期页内容。
signal fixed_deposit_changed
## 定期存单到期信号；参数为本息合计到账星穹与说明文本，横幅通知服务据此提醒玩家。
signal deposit_matured(gold_amount: int, message: String)
## 贷款状态变化信号；放款、还款、自动扣款和违约后发送，面板据此重建贷款页内容。
signal loan_changed
## 贷款自动结算信号；到期自动扣款或违约时发出，参数为说明文本与是否违约，供横幅通知联动。
signal loan_auto_settled(message: String, defaulted: bool)

## 银行独立存档路径；与库存、股市、矿场存档分离，避免账户字段污染其他玩法的序列化结构。
const SAVE_PATH: String = "user://bank_state.json"
## 银行存档版本；版本 1 保存活期余额、计息进度、定期存单、贷款与违约冻结剩余时长。
const SAVE_VERSION: int = 1
## 活期计息周期；默认 3600 秒即 1 在线小时，每满一个周期按当时活期余额结算一次利息。
const DEMAND_INTEREST_INTERVAL_SECONDS: float = 3600.0
## 活期每周期利率；默认 0.2%，利息向下取整为整数星穹并直接计入活期余额。
const DEMAND_INTEREST_RATE_PER_INTERVAL: float = 0.002
## 信用贷款授信比例；默认按玩家总资产估值的 50% 向下取整作为单笔贷款上限。
const LOAN_LIMIT_RATIO: float = 0.50
## 信用贷款利率；默认 15%，应还金额为本金乘 1.15 后向上取整。
const LOAN_INTEREST_RATIO: float = 0.15
## 信用贷款在线期限；默认 7200 秒即 2 小时，到期自动从各资产级联扣款。
const LOAN_DURATION_SECONDS: int = 7200
## 违约冻结在线时长；默认 21600 秒即 6 小时，冻结期间不能申请新贷款与签订新定期存单。
const DEFAULT_FREEZE_SECONDS: float = 21600.0
## 牛市定期利率倍率；默认 0.9，牛市资金涌向股市，银行揽储意愿降低。
const BULL_FIXED_RATE_MULTIPLIER: float = 0.9
## 熊市定期利率倍率；默认 1.25，熊市避险资金回流，银行提高利率揽储。
const BEAR_FIXED_RATE_MULTIPLIER: float = 1.25
## 算力币兑星穹换算比例；与矿场充值比例一致，违约抵扣按每 10000 算力币折抵 1 星穹执行。
const COMPUTE_COINS_PER_GOLD: int = 10000
## 定期存单定义表；基础利率按在线时长阶梯递增，签订时再乘大盘与金库倍率后锁定。
## 利率阶梯说明；三档基础利率折算每在线小时依次约 0.8%、0.9%、1.0%，时长越长效率越高，且始终显著低于贷款利率，杜绝存贷套利。
const FIXED_DEPOSIT_DEFINITIONS: Array[Dictionary] = [
	{"id": "short_term", "name": "短期存单", "duration_seconds": 1800, "base_rate": 0.004, "description": "锁定 30 分钟在线时间，基础利率 0.4%，小额资金快速周转"},
	{"id": "standard_term", "name": "标准存单", "duration_seconds": 7200, "base_rate": 0.018, "description": "锁定 2 小时在线时间，基础利率 1.8%，收益风险均衡"},
	{"id": "long_term", "name": "长期存单", "duration_seconds": 21600, "base_rate": 0.060, "description": "锁定 6 小时在线时间，基础利率 6.0%，长线挂机保本首选"},
]

## 银行存档合并延迟；默认 0.5 秒，计息与倒计时的高频状态变化只执行一次磁盘写入。
@export_range(0.05, 10.0, 0.05) var save_delay_seconds: float = 0.5

## 活期账户整数余额；默认 0，只能通过存入、取出、利息与违约抵扣变化。
var _account_balance: int = 0
## 活期计息累计在线秒数；默认 0，每满一个计息周期结算一次并扣除周期时长。
var _interest_accumulated_seconds: float = 0.0
## 进行中定期存单标识；默认空字符串表示没有存单，同一时间最多一份进行中存单。
var _fixed_deposit_id: String = ""
## 进行中存单锁定本金；默认 0，签订时从局外星穹立即扣除。
var _fixed_deposit_principal: int = 0
## 进行中存单到期本息合计；默认 0，签订时按锁定利率一次性确定，不随行情变化。
var _fixed_deposit_payout: int = 0
## 进行中存单锁定利率；默认 0，签订瞬间按大盘周期与金库等级锁定，仅用于展示。
var _fixed_deposit_locked_rate: float = 0.0
## 进行中存单剩余在线秒数；默认 0，仅在游戏进程运行时递减，归零后自动兑付。
var _fixed_deposit_remaining_seconds: float = 0.0
## 进行中贷款本金；默认 0，放款时直接进入局外星穹余额。
var _loan_principal: int = 0
## 进行中贷款应还金额；默认 0，放款时按本金乘 1.15 向上取整确定。
var _loan_repay_amount: int = 0
## 进行中贷款剩余在线秒数；默认 0，归零后自动执行级联扣款。
var _loan_remaining_seconds: float = 0.0
## 违约冻结剩余在线秒数；默认 0，大于 0 期间不能申请新贷款与签订新定期存单。
var _default_freeze_remaining_seconds: float = 0.0
## 是否已有存档等待执行；默认 false，用于合并高频计息与倒计时写盘。
var _save_queued: bool = false
## 战斗期间是否有银行存档被挂起；默认 false，战斗中只置位该标志不落盘，战斗结束或退出时统一补写。
var _combat_save_pending: bool = false
## 全局库存服务缓存；默认从 Autoload 获取，负责星穹的原子扣除与发放。
var _global_inventory: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if not _load_state():
		_save_state()
	# 战斗状态信号；与矿场服务使用同一机制监听正式对局边界，战斗结束时统一补写挂起存档。
	if _global_inventory != null and _global_inventory.has_signal("run_state_changed"):
		_global_inventory.connect("run_state_changed", Callable(self, "_on_run_state_changed"))
	set_process(true)


func _process(delta: float) -> void:
	# 有效在线增量；暂停菜单也继续计时，关闭程序后不会再收到帧回调，离线期间全部计时冻结。
	var online_delta: float = maxf(delta, 0.0)
	_update_demand_interest(online_delta)
	_update_fixed_deposit(online_delta)
	_update_loan(online_delta)
	if _default_freeze_remaining_seconds > 0.0:
		_default_freeze_remaining_seconds = maxf(_default_freeze_remaining_seconds - online_delta, 0.0)
		if _default_freeze_remaining_seconds <= 0.0:
			# 冻结结束；仅通知面板刷新贷款入口，不产生任何资产变化。
			_queue_save()
			loan_changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()
	elif what == NOTIFICATION_EXIT_TREE and (_save_queued or _combat_save_pending):
		# 服务退出兜底；不发送窗口关闭通知的退出路径也会补写尚未落盘的银行状态。
		_save_state()


func get_account_balance() -> int:
	return _account_balance


func get_interest_progress_ratio() -> float:
	## 返回当前计息周期进度；取值 0 到 1，面板据此渲染下一次利息的进度提示。
	return clampf(_interest_accumulated_seconds / maxf(DEMAND_INTEREST_INTERVAL_SECONDS, 1.0), 0.0, 1.0)


func get_demand_interest_preview() -> int:
	## 返回按当前活期余额计算的单周期利息预览；实际结算按到点瞬间的余额重新计算。
	return int(floor(float(_account_balance) * DEMAND_INTEREST_RATE_PER_INTERVAL))


func deposit(gold_amount: int) -> Dictionary:
	## 把局外星穹存入活期账户；无手续费，存入后立即参与后续计息周期。
	if gold_amount <= 0:
		return {"success": false, "message": "请输入至少 1 星穹"}
	if _global_inventory == null or not _global_inventory.has_method("spend_coins"):
		return {"success": false, "message": "星穹服务不可用"}
	if not bool(_global_inventory.call("spend_coins", gold_amount)):
		return {"success": false, "message": "星穹不足"}
	_account_balance += gold_amount
	_flush_linked_saves()
	account_changed.emit(_account_balance)
	return {"success": true, "message": "存入成功", "gold": gold_amount}


func withdraw(gold_amount: int) -> Dictionary:
	## 从活期账户取出星穹回局外余额；无手续费，取出立即生效。
	if gold_amount <= 0:
		return {"success": false, "message": "请输入至少 1 星穹"}
	if _account_balance < gold_amount:
		return {"success": false, "message": "活期余额不足"}
	if _global_inventory == null or not _global_inventory.has_method("adjust_coins"):
		return {"success": false, "message": "星穹服务不可用"}
	_account_balance -= gold_amount
	_global_inventory.call("adjust_coins", gold_amount)
	_flush_linked_saves()
	account_changed.emit(_account_balance)
	return {"success": true, "message": "取出成功", "gold": gold_amount}


func get_fixed_deposit_definitions() -> Array[Dictionary]:
	return FIXED_DEPOSIT_DEFINITIONS.duplicate(true)


func has_active_fixed_deposit() -> bool:
	## 查询是否存在进行中定期存单；同一时间最多一份，签订入口据此禁用。
	return not _fixed_deposit_id.is_empty()


func get_active_fixed_deposit_snapshot() -> Dictionary:
	## 返回进行中存单快照；无存单时返回空字典，面板据此渲染倒计时与本息金额。
	if not has_active_fixed_deposit():
		return {}
	# 存单定义；进行中存单的标识在签订与加载时都已经过校验，此处必定存在。
	var definition: Dictionary = _get_fixed_deposit_definition(_fixed_deposit_id)
	return {
		"id": _fixed_deposit_id,
		"name": str(definition.get("name", "定期存单")),
		"principal": _fixed_deposit_principal,
		"payout": _fixed_deposit_payout,
		"locked_rate": _fixed_deposit_locked_rate,
		"remaining_seconds": _fixed_deposit_remaining_seconds,
		"duration_seconds": int(definition.get("duration_seconds", 0)),
	}


func get_quoted_fixed_rate(deposit_id: String) -> float:
	## 返回指定存单当前的报价利率；基础利率乘大盘周期倍率与金库倍率，只在签订瞬间锁定。
	var definition: Dictionary = _get_fixed_deposit_definition(deposit_id)
	if definition.is_empty():
		return 0.0
	return maxf(float(definition.get("base_rate", 0.0)) * _get_market_rate_multiplier() * _get_vault_rate_multiplier(), 0.0)


func get_market_state_description() -> String:
	## 返回当前大盘周期的利率影响说明；面板据此提示玩家择时签订存单。
	# 当前大盘状态；股市服务缺失时按震荡市处理。
	var market_state: String = _get_market_state()
	if market_state == "bull":
		return "牛市：定期利率 ×0.9"
	if market_state == "bear":
		return "熊市：定期利率 ×1.25"
	return "震荡市：定期利率 ×1.0"


func start_fixed_deposit(deposit_id: String, principal: int) -> Dictionary:
	## 签订一份定期存单；本金立即从局外星穹扣除，在线到期后本息自动发放，中途不可支取。
	var definition: Dictionary = _get_fixed_deposit_definition(deposit_id)
	if definition.is_empty():
		return {"success": false, "message": "存单类型无效"}
	if has_active_fixed_deposit():
		return {"success": false, "message": "已有进行中的定期存单"}
	if is_default_frozen():
		return {"success": false, "message": "信用违约冻结期间无法签订存单"}
	if principal <= 0:
		return {"success": false, "message": "请输入至少 1 星穹"}
	if _global_inventory == null or not _global_inventory.has_method("spend_coins"):
		return {"success": false, "message": "星穹服务不可用"}
	# 签订瞬间锁定利率；含大盘周期与金库加成，存续期间行情变化不再影响本息。
	var locked_rate: float = get_quoted_fixed_rate(deposit_id)
	if not bool(_global_inventory.call("spend_coins", principal)):
		return {"success": false, "message": "星穹不足，无法签订存单"}
	_fixed_deposit_id = deposit_id
	_fixed_deposit_principal = principal
	_fixed_deposit_payout = principal + int(floor(float(principal) * locked_rate))
	_fixed_deposit_locked_rate = locked_rate
	_fixed_deposit_remaining_seconds = maxf(float(int(definition.get("duration_seconds", 0))), 1.0)
	_flush_linked_saves()
	fixed_deposit_changed.emit()
	return {"success": true, "message": "存单签订成功", "principal": principal, "payout": _fixed_deposit_payout, "rate": locked_rate}


func has_active_loan() -> bool:
	## 查询是否存在进行中贷款；同一时间最多一笔，申请入口据此禁用。
	return _loan_principal > 0


func is_default_frozen() -> bool:
	## 查询是否处于信用违约冻结；冻结期间不能申请新贷款与签订新定期存单。
	return _default_freeze_remaining_seconds > 0.0


func get_default_freeze_remaining_seconds() -> float:
	return _default_freeze_remaining_seconds


func get_loan_snapshot() -> Dictionary:
	## 返回进行中贷款快照；无贷款时返回空字典，面板据此渲染应还金额与剩余时间。
	if not has_active_loan():
		return {}
	return {
		"principal": _loan_principal,
		"repay_amount": _loan_repay_amount,
		"remaining_seconds": _loan_remaining_seconds,
	}


func get_total_asset_estimate() -> int:
	## 返回玩家总资产估值；覆盖局外星穹、活期余额、定期本金、整数证券币与算力币折算星穹。
	# 总资产累计值；从局外星穹开始逐项叠加，全部按整数星穹口径统计。
	var total_assets: int = 0
	if _global_inventory != null and _global_inventory.has_method("get_coins"):
		total_assets += maxi(int(_global_inventory.call("get_coins")), 0)
	total_assets += _account_balance + _fixed_deposit_principal
	# 股市服务；证券币按 1:1 计入整数部分，现货与杠杆市值波动大，不计入授信基数。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_method("get_securities_balance"):
		total_assets += maxi(int(floor(float(stock_market_service.call("get_securities_balance")))), 0)
	# 矿场服务；算力币按固定 10000:1 折算为整数星穹计入。
	var mining_farm_service: Node = get_tree().root.get_node_or_null("MiningFarmService")
	if mining_farm_service != null and mining_farm_service.has_method("get_balance"):
		total_assets += maxi(int(mining_farm_service.call("get_balance")) / COMPUTE_COINS_PER_GOLD, 0)
	return total_assets


func get_asset_breakdown() -> Dictionary:
	## 返回总资产估值的分项明细；口径与 get_total_asset_estimate 完全一致，供银行面板展示授信基数构成。
	# 局外星穹；库存服务缺失时按 0 计入。
	var coins: int = maxi(int(_global_inventory.call("get_coins")), 0) if _global_inventory != null and _global_inventory.has_method("get_coins") else 0
	# 整数证券币；现货与杠杆市值波动大，不计入授信基数。
	var securities_gold: int = 0
	# 股市服务；缺失时证券币按 0 计入。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_method("get_securities_balance"):
		securities_gold = maxi(int(floor(float(stock_market_service.call("get_securities_balance")))), 0)
	# 算力币折算星穹；固定 10000:1 向下取整。
	var compute_gold: int = 0
	# 矿场服务；缺失时算力币按 0 计入。
	var mining_farm_service: Node = get_tree().root.get_node_or_null("MiningFarmService")
	if mining_farm_service != null and mining_farm_service.has_method("get_balance"):
		compute_gold = maxi(int(mining_farm_service.call("get_balance")) / COMPUTE_COINS_PER_GOLD, 0)
	return {
		"coins": coins,
		"account_balance": _account_balance,
		"fixed_deposit_principal": _fixed_deposit_principal,
		"securities_gold": securities_gold,
		"compute_gold": compute_gold,
		"total": coins + _account_balance + _fixed_deposit_principal + securities_gold + compute_gold,
	}


func get_maximum_loan_amount() -> int:
	## 返回当前可申请的最大贷款金额；按总资产估值乘授信比例向下取整。
	if has_active_loan() or is_default_frozen():
		return 0
	return int(floor(float(get_total_asset_estimate()) * LOAN_LIMIT_RATIO))


func start_loan(gold_amount: int) -> Dictionary:
	## 申请一笔信用贷款；星穹立即放款到局外余额，在线到期后自动还款，无法还清将触发违约。
	if has_active_loan():
		return {"success": false, "message": "已有进行中的贷款"}
	if is_default_frozen():
		return {"success": false, "message": "信用违约冻结期间无法贷款"}
	if gold_amount <= 0:
		return {"success": false, "message": "请输入至少 1 星穹"}
	# 当前授信上限；确认瞬间按最新总资产重新计算。
	var maximum_amount: int = get_maximum_loan_amount()
	if gold_amount > maximum_amount:
		return {"success": false, "message": "超出当前授信上限 %d 星穹" % maximum_amount}
	if _global_inventory == null or not _global_inventory.has_method("adjust_coins"):
		return {"success": false, "message": "星穹服务不可用"}
	_loan_principal = gold_amount
	_loan_repay_amount = ceili(float(gold_amount) * (1.0 + LOAN_INTEREST_RATIO))
	_loan_remaining_seconds = float(LOAN_DURATION_SECONDS)
	_global_inventory.call("adjust_coins", gold_amount)
	_flush_linked_saves()
	loan_changed.emit()
	return {"success": true, "message": "放款成功", "principal": gold_amount, "repay_amount": _loan_repay_amount}


func repay_loan() -> Dictionary:
	## 主动一次性还清贷款；只从局外星穹扣除应还金额，余额不足时不执行任何扣款。
	if not has_active_loan():
		return {"success": false, "message": "当前没有进行中的贷款"}
	if _global_inventory == null or not _global_inventory.has_method("spend_coins"):
		return {"success": false, "message": "星穹服务不可用"}
	# 本次应还金额；先取出再清空状态，防止扣款回调期间重复结算。
	var repay_amount: int = _loan_repay_amount
	if not bool(_global_inventory.call("spend_coins", repay_amount)):
		return {"success": false, "message": "星穹不足，需要 %d 星穹" % repay_amount}
	_clear_loan_state()
	_flush_linked_saves()
	loan_changed.emit()
	return {"success": true, "message": "贷款已结清", "repay_amount": repay_amount}


func _update_demand_interest(online_delta: float) -> void:
	## 推进活期计息周期；每满 1 在线小时按当时余额结算一次利息，余额为 0 时周期照常推进。
	_interest_accumulated_seconds += online_delta
	if _interest_accumulated_seconds < DEMAND_INTEREST_INTERVAL_SECONDS:
		return
	_interest_accumulated_seconds -= DEMAND_INTEREST_INTERVAL_SECONDS
	# 本周期利息；按结算瞬间的活期余额向下取整，不足 1 星穹时本周期没有利息。
	var interest: int = get_demand_interest_preview()
	if interest <= 0:
		return
	_account_balance += interest
	_queue_save()
	account_changed.emit(_account_balance)


func _update_fixed_deposit(online_delta: float) -> void:
	## 推进定期存单在线倒计时；归零后本息自动发放到局外星穹并广播到期信号。
	if not has_active_fixed_deposit():
		return
	_fixed_deposit_remaining_seconds = maxf(_fixed_deposit_remaining_seconds - online_delta, 0.0)
	if _fixed_deposit_remaining_seconds > 0.0:
		return
	# 本次到账本息；先取出再清空状态，防止星穹服务回调期间重复兑付。
	var payout: int = _fixed_deposit_payout
	# 到期说明文本；同时用于信号与横幅通知。
	var mature_message: String = "定期存单到期，本息 %d 星穹已到账" % payout
	_fixed_deposit_id = ""
	_fixed_deposit_principal = 0
	_fixed_deposit_payout = 0
	_fixed_deposit_locked_rate = 0.0
	_fixed_deposit_remaining_seconds = 0.0
	if _global_inventory != null and _global_inventory.has_method("adjust_coins"):
		_global_inventory.call("adjust_coins", payout)
	if _is_combat_run_active():
		# 战斗期间兑付；只做内存结算并挂起写盘，战斗结束或退出路径统一落盘。
		_queue_save()
	else:
		_flush_linked_saves()
	fixed_deposit_changed.emit()
	deposit_matured.emit(payout, mature_message)


func _update_loan(online_delta: float) -> void:
	## 推进贷款在线倒计时；归零后自动执行级联扣款，扣不满应还金额时触发信用违约。
	if not has_active_loan():
		return
	_loan_remaining_seconds = maxf(_loan_remaining_seconds - online_delta, 0.0)
	if _loan_remaining_seconds <= 0.0:
		_execute_loan_auto_settlement()


func _execute_loan_auto_settlement() -> void:
	## 执行贷款到期级联扣款；按局外星穹、活期余额、算力币、证券币顺序抵扣，不足部分核销并违约。
	# 剩余应还金额；逐层扣款后递减，归零表示全额还清。
	var remaining_debt: int = _loan_repay_amount
	# 第一层：局外星穹；直接按可用余额扣除。
	if _global_inventory != null and _global_inventory.has_method("get_coins") and _global_inventory.has_method("spend_coins"):
		# 本层可扣金额；星穹余额与剩余债务取小。
		var coins_take: int = mini(maxi(int(_global_inventory.call("get_coins")), 0), remaining_debt)
		if coins_take > 0 and bool(_global_inventory.call("spend_coins", coins_take)):
			remaining_debt -= coins_take
	# 第二层：银行活期余额；违约抵扣不享受任何手续费豁免以外的保护。
	if remaining_debt > 0 and _account_balance > 0:
		# 本层可扣金额；活期余额与剩余债务取小。
		var account_take: int = mini(_account_balance, remaining_debt)
		_account_balance -= account_take
		remaining_debt -= account_take
		account_changed.emit(_account_balance)
	# 第三层：矿场算力币；按 10000:1 整数折算，通过矿场公开违约抵扣接口执行。
	if remaining_debt > 0:
		# 矿场服务；缺失时跳过本层继续向下抵扣。
		var mining_farm_service: Node = get_tree().root.get_node_or_null("MiningFarmService")
		if mining_farm_service != null and mining_farm_service.has_method("get_balance") and mining_farm_service.has_method("deduct_compute_coins"):
			# 本层可折抵星穹；算力币余额按固定比例向下取整后与剩余债务取小。
			var compute_gold_available: int = maxi(int(mining_farm_service.call("get_balance")) / COMPUTE_COINS_PER_GOLD, 0)
			var compute_take_gold: int = mini(compute_gold_available, remaining_debt)
			if compute_take_gold > 0:
				# 实际扣除算力币；服务返回真实扣除量，按整数比例回推抵扣的星穹。
				var deducted_compute: int = int(mining_farm_service.call("deduct_compute_coins", compute_take_gold * COMPUTE_COINS_PER_GOLD, "银行贷款违约抵扣"))
				remaining_debt -= deducted_compute / COMPUTE_COINS_PER_GOLD
	# 第四层：股市证券币；按 1:1 整数折算，通过股市公开违约抵扣接口执行。
	if remaining_debt > 0:
		# 股市服务；缺失时跳过本层直接进入违约判定。
		var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
		if stock_market_service != null and stock_market_service.has_method("get_securities_balance") and stock_market_service.has_method("deduct_securities"):
			# 本层可折抵星穹；证券币余额向下取整后与剩余债务取小。
			var securities_available: int = maxi(int(floor(float(stock_market_service.call("get_securities_balance")))), 0)
			var securities_take: int = mini(securities_available, remaining_debt)
			if securities_take > 0:
				# 实际扣除证券币；服务返回真实扣除量，向下取整回推抵扣的星穹。
				var deducted_securities: float = float(stock_market_service.call("deduct_securities", float(securities_take), "银行贷款违约抵扣"))
				remaining_debt -= int(floor(deducted_securities))
	# 结算说明文本；违约与正常扣款使用不同文案，供面板与横幅展示。
	var settle_message: String = ""
	# 是否触发违约；剩余债务大于 0 表示全部资产仍不足以偿还。
	var defaulted: bool = remaining_debt > 0
	if defaulted:
		_default_freeze_remaining_seconds = DEFAULT_FREEZE_SECONDS
		settle_message = "贷款违约：资产不足，未偿 %d 星穹已核销，银行信贷冻结 6 小时" % remaining_debt
	else:
		settle_message = "贷款到期，已自动扣款 %d 星穹结清" % _loan_repay_amount
	_clear_loan_state()
	if _is_combat_run_active():
		# 战斗期间结算；只做内存扣款并挂起写盘，战斗结束或退出路径统一落盘。
		_queue_save()
	else:
		_flush_linked_saves()
	loan_changed.emit()
	loan_auto_settled.emit(settle_message, defaulted)


func _clear_loan_state() -> void:
	## 清空进行中贷款字段；主动还款与自动结算共用，冻结状态由调用方单独维护。
	_loan_principal = 0
	_loan_repay_amount = 0
	_loan_remaining_seconds = 0.0


func _get_fixed_deposit_definition(deposit_id: String) -> Dictionary:
	for definition in FIXED_DEPOSIT_DEFINITIONS:
		if str(definition.get("id", "")) == deposit_id:
			return definition
	return {}


func _get_market_state() -> String:
	## 读取股市长期大盘状态；股市服务缺失时按震荡市处理，银行仍可独立运行。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service == null or not stock_market_service.has_method("get_market_snapshot"):
		return "sideways"
	return str((stock_market_service.call("get_market_snapshot") as Dictionary).get("market_state", "sideways"))


func _get_market_rate_multiplier() -> float:
	## 返回当前大盘周期对定期利率的倍率；牛市 0.9、熊市 1.25、震荡 1.0。
	# 当前大盘状态；只读取长期大盘，不受事件临时大盘影响。
	var market_state: String = _get_market_state()
	if market_state == "bull":
		return BULL_FIXED_RATE_MULTIPLIER
	if market_state == "bear":
		return BEAR_FIXED_RATE_MULTIPLIER
	return 1.0


func _get_vault_rate_multiplier() -> float:
	## 返回星海金库设施对定期利率的倍率；据点服务缺失时按无加成处理。
	var hideout_service: Node = get_tree().root.get_node_or_null("HideoutService")
	if hideout_service != null and hideout_service.has_method("get_bank_fixed_rate_multiplier"):
		return maxf(float(hideout_service.call("get_bank_fixed_rate_multiplier")), 1.0)
	return 1.0


func _queue_save() -> void:
	if _is_combat_run_active():
		# 战斗期间挂起写盘；账户与倒计时仍在内存实时变化，磁盘写入统一延迟到战斗结束或退出。
		_combat_save_pending = true
		return
	if _save_queued:
		return
	_save_queued = true
	# 合并计时器；暂停状态继续运行，保证暂停界面期间的利息与到期仍能按时落盘。
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
	## 立即保存银行与星穹存档；存取款、放款与兑付属于跨文件资产变更，同一路径落盘缩短不一致窗口。
	_save_queued = false
	_save_state()
	if _global_inventory != null and _global_inventory.has_method("flush_stock_holdings_save"):
		# 库存即时保存接口会保存完整永久星穹数据，名称虽保留股票历史用途，但可安全复用跨存档兑换。
		_global_inventory.call("flush_stock_holdings_save")


func _save_state() -> void:
	# 任何真实落盘都会消化战斗期间的挂起标志；战斗结束、关闭窗口与联动保存共用该出口。
	_combat_save_pending = false
	# 存档数据；全部金额为整数星穹，计时字段只保存剩余在线时长而不保存系统时间戳。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"account_balance": _account_balance,
		"interest_accumulated_seconds": _interest_accumulated_seconds,
		"fixed_deposit_id": _fixed_deposit_id,
		"fixed_deposit_principal": _fixed_deposit_principal,
		"fixed_deposit_payout": _fixed_deposit_payout,
		"fixed_deposit_locked_rate": _fixed_deposit_locked_rate,
		"fixed_deposit_remaining_seconds": _fixed_deposit_remaining_seconds,
		"loan_principal": _loan_principal,
		"loan_repay_amount": _loan_repay_amount,
		"loan_remaining_seconds": _loan_remaining_seconds,
		"default_freeze_remaining_seconds": _default_freeze_remaining_seconds,
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
	_account_balance = maxi(int(save_data.get("account_balance", 0)), 0)
	_interest_accumulated_seconds = clampf(float(save_data.get("interest_accumulated_seconds", 0.0)), 0.0, DEMAND_INTEREST_INTERVAL_SECONDS)
	_fixed_deposit_id = str(save_data.get("fixed_deposit_id", ""))
	_fixed_deposit_principal = maxi(int(save_data.get("fixed_deposit_principal", 0)), 0)
	_fixed_deposit_payout = maxi(int(save_data.get("fixed_deposit_payout", 0)), 0)
	_fixed_deposit_locked_rate = maxf(float(save_data.get("fixed_deposit_locked_rate", 0.0)), 0.0)
	_fixed_deposit_remaining_seconds = maxf(float(save_data.get("fixed_deposit_remaining_seconds", 0.0)), 0.0)
	if not _fixed_deposit_id.is_empty() and (_get_fixed_deposit_definition(_fixed_deposit_id).is_empty() or _fixed_deposit_remaining_seconds <= 0.0 or _fixed_deposit_payout <= 0):
		# 存单数据异常兜底；存单类型被移除或计时数据损坏时退还锁定本金，不发放利息。
		if _global_inventory != null and _global_inventory.has_method("adjust_coins") and _fixed_deposit_principal > 0:
			_global_inventory.call("adjust_coins", _fixed_deposit_principal)
		_fixed_deposit_id = ""
		_fixed_deposit_principal = 0
		_fixed_deposit_payout = 0
		_fixed_deposit_locked_rate = 0.0
		_fixed_deposit_remaining_seconds = 0.0
		_queue_save()
	_loan_principal = maxi(int(save_data.get("loan_principal", 0)), 0)
	_loan_repay_amount = maxi(int(save_data.get("loan_repay_amount", 0)), 0)
	_loan_remaining_seconds = maxf(float(save_data.get("loan_remaining_seconds", 0.0)), 0.0)
	if _loan_principal > 0 and (_loan_repay_amount <= 0 or _loan_remaining_seconds <= 0.0):
		# 贷款数据异常兜底；应还金额损坏时直接核销贷款，不执行任何补扣。
		_clear_loan_state()
		_queue_save()
	_default_freeze_remaining_seconds = maxf(float(save_data.get("default_freeze_remaining_seconds", 0.0)), 0.0)
	return true
