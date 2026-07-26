extends Node

## 量子算力矿场服务在全部场景中持续运行，统一维护算力币、永久资产、在线增益与独立存档。
## UI、战斗结算和股市只通过公开接口或信号协作，不直接修改矿场内部状态。

signal balance_changed(balance: int, delta: int)
signal production_changed(production_per_second: int)
## 产出结算完成信号；参数为本次实际收益和覆盖的完整秒数，UI 可逐次播放收益飘字。
signal production_settled(earned: int, settled_seconds: int)
signal assets_changed
signal buffs_changed
## 超频状态变化信号；启动、结束和散热完成时发送，UI 据此刷新超频按钮的可用状态与倒计时。
signal overclock_changed
## 算力合同状态变化信号；签订、完成和异常回退时发送，UI 据此重建合同页内容。
signal contract_changed
## 算力合同完成信号；参数为本次实际到账的整数星穹，面板可见时播放交付反馈文字。
signal contract_completed(gold_amount: int)

## 矿场独立存档路径；默认与库存、股市存档分离，避免不同玩法的数据结构互相污染。
const SAVE_PATH: String = "user://mining_farm_state.json"
## 矿场存档版本；版本 1 保存整数余额、资产数量、永久解锁和在线增益剩余时间。
const SAVE_VERSION: int = 1
## 永久星穹充值倍率；默认 1 星穹兑换 10000 算力币，运行时不动态修改。
const COMPUTE_COINS_PER_GOLD: int = 10000
## 基础提现手续费率；默认 10%，提现所需算力币按到账星穹反推并向上取整。
const WITHDRAWAL_FEE_RATIO: float = 0.10
## 资产出售返还比例；默认按当前官方购买价的 60% 向上取整返还算力币。
const ASSET_SELL_RETURN_RATIO: float = 0.60
## 骇入增益每星穹加成比例；默认每 10 星穹增加 0.01%，换算为每星穹 0.00001 小数倍率。
const HACK_BUFF_RATIO_PER_GOLD: float = 0.00001
## 骇入增益在线持续时间；默认 1800 秒即 30 分钟，游戏关闭期间不会消耗。
const HACK_BUFF_DURATION_SECONDS: float = 1800.0
## 股市联动触发涨幅；默认骇客数字科技单轮上涨达到 10% 时激活矿场增益。
const STOCK_BUFF_TRIGGER_RATIO: float = 0.10
## 股市联动产出加成；默认全部资产产出提高 15%，持续到下一次正式全量刷新。
const STOCK_BUFF_PRODUCTION_RATIO: float = 0.15
## 股市联动股票标识；固定对应骇客数字科技，避免通过显示名称建立脆弱依赖。
const STOCK_BUFF_STOCK_ID: String = "hacker_tech"
## 正式股市全量刷新标识；与股市服务公开刷新来源保持一致，用于限定联动的触发和失效时机。
const STOCK_FULL_REFRESH_SOURCE: String = "settlement"
## 离线收益折算比例；默认 25%，离线期间按基础总产出（含固件、不含临时增益）的该比例补发。
const OFFLINE_INCOME_RATIO: float = 0.25
## 离线收益计时上限；默认 28800 秒即 8 小时，超出部分不参与补发，保持在线游玩收益更高的定位。
const OFFLINE_INCOME_MAX_SECONDS: int = 28800
## 超频产出加成比例；默认 0.5，与其他增益加算叠加，单独生效时产出为基础的 1.5 倍。
const OVERCLOCK_PRODUCTION_RATIO: float = 0.5
## 超频持续时间；默认 300 秒在线时间，结束后立即进入散热冷却。
const OVERCLOCK_DURATION_SECONDS: float = 300.0
## 超频散热冷却时间；默认 1800 秒在线时间，冷却期间产出恢复正常且不能再次超频。
const OVERCLOCK_COOLDOWN_SECONDS: float = 1800.0
## 资产固件最大等级；默认 5 级，每类资产独立计算且达到上限后升级入口禁用。
const ASSET_UPGRADE_MAX_LEVEL: int = 5
## 资产固件每级产出加成比例；默认 10%，按资产类别对“单台基础产出×持有数量”整体加成后向下取整。
const ASSET_UPGRADE_PRODUCTION_RATIO_PER_LEVEL: float = 0.10
## 资产固件各级升级费用倍率；下标 0 对应从 0 级升到 1 级，费用为官方购买价乘对应倍率。
const ASSET_UPGRADE_COST_MULTIPLIERS: Array[int] = [2, 6, 18, 54, 162]
## 算力合同定义表；锁定算力币在线到期后按费率结算为星穹，费率优于 10% 的即时提现手续费。
const CONTRACT_DEFINITIONS: Array[Dictionary] = [
	{"id": "short_term", "name": "短期算力合同", "duration_seconds": 1800, "payout_ratio": 0.92, "description": "锁定 30 分钟在线时间，费率 8%，适合小额快速周转"},
	{"id": "standard_term", "name": "标准算力合同", "duration_seconds": 7200, "payout_ratio": 0.95, "description": "锁定 2 小时在线时间，费率 5%，兑换效率均衡"},
	{"id": "long_term", "name": "长期算力合同", "duration_seconds": 21600, "payout_ratio": 0.98, "description": "锁定 6 小时在线时间，费率仅 2%，长线挂机最优出口"},
]
## 资产定义表；价格、单台整数产出、解锁门槛和说明均集中维护，UI 只读取公开副本。
const ASSET_DEFINITIONS: Array[Dictionary] = [
	{"id": "embedded_chip", "name": "嵌入式算力芯片", "price": 80000, "production": 8, "unlock_rate": 0, "description": "入门级低功耗算力单元，适合小额试水"},
	{"id": "desktop_node", "name": "桌面矿机节点", "price": 450000, "production": 52, "unlock_rate": 30, "description": "家用级矿机，稳定产出，性价比均衡"},
	{"id": "rack_server", "name": "机架式服务器组", "price": 2800000, "production": 360, "unlock_rate": 200, "description": "企业级服务器阵列，产出效率显著提升"},
	{"id": "edge_station", "name": "边缘计算基站", "price": 16000000, "production": 2200, "unlock_rate": 1500, "description": "区域分布式算力节点，覆盖范围广"},
	{"id": "regional_center", "name": "区域数据中心", "price": 95000000, "production": 14000, "unlock_rate": 10000, "description": "大型数据中心，算力密度极高"},
	{"id": "quantum_cluster", "name": "量子计算集群", "price": 580000000, "production": 92000, "unlock_rate": 70000, "description": "顶级量子算力单元，游戏内产出天花板"},
]

## 面板打开时结算周期；默认 1 秒，直接形成清晰的逐秒整数产出节律。
@export_range(0.1, 10.0, 0.1) var foreground_settlement_interval_seconds: float = 1.0
## 面板关闭时结算周期；默认 5 秒，批量累加等额收益以降低后台信号和存档频率。
@export_range(1.0, 60.0, 1.0) var background_settlement_interval_seconds: float = 5.0
## 产出存档合并延迟；默认 0.5 秒，短时间连续结算或交易只执行一次磁盘写入。
@export_range(0.05, 10.0, 0.05) var save_delay_seconds: float = 0.5

## 当前整数算力币余额；默认 0，所有增减都必须通过服务公开接口执行。
var _balance: int = 0
## 资产持有数量表；键为稳定资产标识，值为大于等于 0 的整数且不设置上限。
var _asset_quantities: Dictionary = {}
## 永久解锁表；键为稳定资产标识，达到门槛后保持 true，即使出售全部资产也不会重新锁定。
var _unlocked_assets: Dictionary = {}
## 骇入增益比例；默认 0，成功撤离后按撤离物品总价值计算并允许多次叠加。
var _hack_buff_ratio: float = 0.0
## 骇入增益剩余在线秒数；默认 0，仅在游戏进程运行时递减。
var _hack_buff_remaining_seconds: float = 0.0
## 股市联动是否生效；默认 false，达到触发涨幅后保持到下一次正式全量刷新。
var _stock_buff_active: bool = false
## 资产固件等级表；键为稳定资产标识，值为 0 到最大等级的整数，出售资产不回退固件等级。
var _asset_upgrade_levels: Dictionary = {}
## 超频剩余在线秒数；默认 0，大于 0 表示超频生效中，仅消耗在线帧时间。
var _overclock_remaining_seconds: float = 0.0
## 超频散热剩余在线秒数；默认 0，大于 0 表示冷却中不可再次启动，仅消耗在线帧时间。
var _overclock_cooldown_remaining_seconds: float = 0.0
## 进行中合同标识；默认空字符串表示没有合同，同一时间最多存在一份进行中合同。
var _active_contract_id: String = ""
## 进行中合同剩余在线秒数；默认 0，仅在游戏进程运行时递减，归零后自动完成结算。
var _contract_remaining_seconds: float = 0.0
## 进行中合同到期到账星穹；默认 0，签订时确定且到期后原样发放，不受行情或增益影响。
var _contract_gold_amount: int = 0
## 进行中合同锁定的算力币；默认 0，签订时立即从余额扣除，仅用于展示与异常回退。
var _contract_locked_compute: int = 0
## 待展示的离线收益报告；默认空字典，启动补发离线收益后填充，面板首次打开时消费并清空。
var _pending_offline_report: Dictionary = {}
## 当前累计未结算在线秒数；默认 0，达到前台或后台周期后批量结算完整秒数。
var _settlement_accumulator_seconds: float = 0.0
## 当前矿场面板是否打开；默认 false，决定结算信号频率但不改变单位时间收益。
var _panel_open: bool = false
## 是否已有存档等待执行；默认 false，用于合并频繁的逐秒收益写盘。
var _save_queued: bool = false
## 战斗期间是否有矿场存档被挂起；默认 false，战斗中 _queue_save 只置位该标志不落盘，战斗结束、关闭窗口或服务退出时统一补写。
var _combat_save_pending: bool = false
## 全局库存服务缓存；默认从 Autoload 获取，只用于永久星穹的原子扣除和增加。
var _global_inventory: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_initialize_default_state()
	if not _load_state():
		_save_state()
	_connect_stock_market_service()
	_refresh_unlocks()
	# 战斗状态信号；与股市服务使用同一机制监听 GlobalInventory 的正式对局边界，战斗结束时统一补写挂起存档。
	if _global_inventory != null and _global_inventory.has_signal("run_state_changed"):
		_global_inventory.connect("run_state_changed", Callable(self, "_on_run_state_changed"))
	set_process(true)


func _process(delta: float) -> void:
	# 有效在线增量；暂停菜单也继续计时，关闭程序后不会再收到帧回调，因此天然没有离线收益。
	var online_delta: float = maxf(delta, 0.0)
	_update_timed_buffs(online_delta)
	_settlement_accumulator_seconds += online_delta
	# 当前结算周期；面板打开为 1 秒，关闭为 5 秒，均只结算完整整数秒。
	var interval: float = maxf(foreground_settlement_interval_seconds if _panel_open else background_settlement_interval_seconds, 0.1)
	if _settlement_accumulator_seconds < interval:
		return
	# 完整收益秒数；余下小数继续保留，确保切换场景和帧率波动不会损失收益。
	var whole_seconds: int = int(floor(_settlement_accumulator_seconds))
	if whole_seconds <= 0:
		return
	_settlement_accumulator_seconds -= float(whole_seconds)
	_settle_production(whole_seconds)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()
	elif what == NOTIFICATION_EXIT_TREE and (_save_queued or _combat_save_pending):
		# 服务退出兜底；主菜单 get_tree().quit() 等不发送窗口关闭通知的退出路径也会补写尚未落盘的矿场状态。
		_save_state()


func set_panel_open(open: bool) -> void:
	_panel_open = open
	if open:
		# 面板打开时立即补齐后台已经积累的完整秒数，UI 可据此播放余额滚动动画。
		var whole_seconds: int = int(floor(_settlement_accumulator_seconds))
		if whole_seconds > 0:
			_settlement_accumulator_seconds -= float(whole_seconds)
			_settle_production(whole_seconds)


func get_balance() -> int:
	return _balance


func get_gold_equivalent() -> float:
	return float(_balance) / float(COMPUTE_COINS_PER_GOLD)


func get_asset_definitions() -> Array[Dictionary]:
	return ASSET_DEFINITIONS.duplicate(true)


func get_asset_quantity(asset_id: String) -> int:
	return maxi(int(_asset_quantities.get(asset_id, 0)), 0)


func is_asset_unlocked(asset_id: String) -> bool:
	return bool(_unlocked_assets.get(asset_id, false))


func get_base_production_per_second() -> int:
	# 基础整数产出；逐类按单台产出乘持有数量累计，不包含任何百分比增益。
	# 固件升级补充；每类资产按“单台基础产出×数量×(1+每级比例×固件等级)”整体向下取整，保证小额资产也能获得升级收益。
	var total: int = 0
	for definition in ASSET_DEFINITIONS:
		# 当前资产标识；用于同时读取持有数量与固件等级。
		var asset_id: String = str(definition.get("id", ""))
		total += _calculate_asset_type_production(int(definition.get("production", 0)), get_asset_quantity(asset_id), get_asset_upgrade_level(asset_id))
	return maxi(total, 0)


func get_production_per_second() -> int:
	# 总倍率；多个增益采用加算叠加，最终对总基础产出向下取整以维持整数货币规则。
	# 超频补充；超频生效期间在加算队列追加固定比例，单独生效时产出为基础的 1.5 倍。
	var multiplier: float = 1.0 + _hack_buff_ratio + (STOCK_BUFF_PRODUCTION_RATIO if _stock_buff_active else 0.0) + (OVERCLOCK_PRODUCTION_RATIO if is_overclock_active() else 0.0)
	return maxi(int(floor(float(get_base_production_per_second()) * multiplier)), 0)


func get_active_buffs() -> Array[Dictionary]:
	# 增益快照；UI 可安全显示名称、百分比和倒计时，不获得修改内部状态的引用。
	var buffs: Array[Dictionary] = []
	if is_overclock_active():
		buffs.append({"id": "overclock", "name": "超频", "ratio": OVERCLOCK_PRODUCTION_RATIO, "remaining_seconds": _overclock_remaining_seconds})
	if _hack_buff_ratio > 0.0 and _hack_buff_remaining_seconds > 0.0:
		buffs.append({"id": "hack_extraction", "name": "骇入增益", "ratio": _hack_buff_ratio, "remaining_seconds": _hack_buff_remaining_seconds})
	if _stock_buff_active:
		buffs.append({"id": "stock_link", "name": "股市联动", "ratio": STOCK_BUFF_PRODUCTION_RATIO, "remaining_seconds": -1.0})
	return buffs


func get_withdrawal_cost(gold_amount: int) -> int:
	if gold_amount <= 0:
		return 0
	return int(ceil(float(gold_amount * COMPUTE_COINS_PER_GOLD) / (1.0 - WITHDRAWAL_FEE_RATIO)))


func get_maximum_withdrawable_gold() -> int:
	## 返回当前余额最多可到账的整数星穹；公式与正式提现完全一致，不使用单星穹成本近似。
	if _balance <= 0:
		return 0
	# 理论上界；忽略手续费时余额最多兑换的星穹数一定不小于真实结果，可作为二分搜索右边界。
	var upper_bound: int = maxi(int(_balance / COMPUTE_COINS_PER_GOLD), 1)
	# 二分下界；始终表示当前已确认可支付的星穹数量。
	var lower_bound: int = 0
	while lower_bound < upper_bound:
		# 中间数量；向上取中点保证相邻区间可以正常收敛。
		var middle: int = int((lower_bound + upper_bound + 1) / 2)
		if get_withdrawal_cost(middle) <= _balance:
			lower_bound = middle
		else:
			upper_bound = middle - 1
	return lower_bound


func get_maximum_buy_quantity(asset_id: String) -> int:
	## 返回当前余额可购买的最大资产数量；未解锁、无效价格或余额不足时返回 0。
	var definition: Dictionary = _get_asset_definition(asset_id)
	if definition.is_empty() or not is_asset_unlocked(asset_id):
		return 0
	# 当前官方单价；必须为正整数，异常配置不会参与除法。
	var unit_price: int = int(definition.get("price", 0))
	return int(_balance / unit_price) if unit_price > 0 else 0


func get_asset_sell_return(asset_id: String, quantity: int) -> int:
	# 资产定义；出售始终使用当前官方价格，不读取历史购买成本或临时折扣。
	var definition: Dictionary = _get_asset_definition(asset_id)
	if definition.is_empty() or quantity <= 0:
		return 0
	return int(ceil(float(int(definition.get("price", 0)) * quantity) * ASSET_SELL_RETURN_RATIO))


func recharge(gold_amount: int) -> Dictionary:
	if gold_amount <= 0:
		return {"success": false, "message": "请输入至少 1 星穹"}
	if _global_inventory == null or not _global_inventory.has_method("spend_coins"):
		return {"success": false, "message": "星穹服务不可用"}
	if not bool(_global_inventory.call("spend_coins", gold_amount)):
		return {"success": false, "message": "星穹不足"}
	# 到账算力币；兑换倍率为整数，充值不会产生任何手续费或精度损失。
	var compute_amount: int = gold_amount * COMPUTE_COINS_PER_GOLD
	_change_balance(compute_amount)
	_flush_linked_saves()
	return {"success": true, "message": "充值成功", "gold": gold_amount, "compute_coins": compute_amount}


func withdraw(gold_amount: int) -> Dictionary:
	# 所需算力币；按 10% 手续费反推并向上取整，因此提现 1 星穹固定消耗 11112 算力币。
	var cost: int = get_withdrawal_cost(gold_amount)
	if gold_amount <= 0 or cost <= 0:
		return {"success": false, "message": "请输入至少 1 星穹"}
	if _balance < cost:
		return {"success": false, "message": "算力币余额不足"}
	if _global_inventory == null or not _global_inventory.has_method("adjust_coins"):
		return {"success": false, "message": "星穹服务不可用"}
	_change_balance(-cost)
	_global_inventory.call("adjust_coins", gold_amount)
	_flush_linked_saves()
	return {"success": true, "message": "提现成功", "gold": gold_amount, "compute_coins": cost, "fee": cost - gold_amount * COMPUTE_COINS_PER_GOLD}


func buy_asset(asset_id: String, quantity: int = 1) -> Dictionary:
	# 资产定义；无效标识不会扣款，避免 UI 状态过期或外部错误调用污染存档。
	var definition: Dictionary = _get_asset_definition(asset_id)
	if definition.is_empty() or quantity <= 0:
		return {"success": false, "message": "资产或数量无效"}
	if not is_asset_unlocked(asset_id):
		return {"success": false, "message": "资产尚未解锁"}
	# 总购买成本；价格和数量均为整数，资产数量没有上限。
	var total_cost: int = int(definition.get("price", 0)) * quantity
	if _balance < total_cost:
		return {"success": false, "message": "算力币余额不足"}
	_change_balance(-total_cost)
	_asset_quantities[asset_id] = get_asset_quantity(asset_id) + quantity
	_refresh_unlocks()
	_queue_save()
	assets_changed.emit()
	production_changed.emit(get_production_per_second())
	return {"success": true, "message": "资产已上线", "asset_id": asset_id, "quantity": quantity, "cost": total_cost}


func sell_asset(asset_id: String, quantity: int) -> Dictionary:
	# 当前持有量；确认瞬间重新校验，防止连续出售弹窗导致超额扣减。
	var current_quantity: int = get_asset_quantity(asset_id)
	if quantity <= 0 or current_quantity < quantity:
		return {"success": false, "message": "持有数量不足"}
	# 返还算力币；按当前官方价的 60% 向上取整，折价已经包含全部变现成本。
	var returned_amount: int = get_asset_sell_return(asset_id, quantity)
	_asset_quantities[asset_id] = current_quantity - quantity
	_change_balance(returned_amount)
	_queue_save()
	assets_changed.emit()
	production_changed.emit(get_production_per_second())
	return {"success": true, "message": "资产出售成功", "asset_id": asset_id, "quantity": quantity, "returned": returned_amount}


func apply_successful_extraction_buff(extracted_value_gold: int) -> void:
	if extracted_value_gold <= 0:
		return
	# 新增比例；每 10 星穹固定增加 0.01%，允许与当前骇入增益直接叠加。
	var added_ratio: float = float(extracted_value_gold) * HACK_BUFF_RATIO_PER_GOLD
	_hack_buff_ratio += added_ratio
	_hack_buff_remaining_seconds = maxf(_hack_buff_remaining_seconds, 0.0) + HACK_BUFF_DURATION_SECONDS
	_queue_save()
	buffs_changed.emit()
	production_changed.emit(get_production_per_second())


func get_asset_upgrade_level(asset_id: String) -> int:
	## 返回指定资产的当前固件等级；未记录时按 0 级处理，等级只增不减。
	return clampi(int(_asset_upgrade_levels.get(asset_id, 0)), 0, ASSET_UPGRADE_MAX_LEVEL)


func get_asset_upgrade_cost(asset_id: String) -> int:
	## 返回指定资产升到下一固件等级所需算力币；已满级或资产无效时返回 0。
	var definition: Dictionary = _get_asset_definition(asset_id)
	# 当前固件等级；同时作为费用倍率表下标，满级后不存在下一级费用。
	var current_level: int = get_asset_upgrade_level(asset_id)
	if definition.is_empty() or current_level >= ASSET_UPGRADE_MAX_LEVEL:
		return 0
	return int(definition.get("price", 0)) * ASSET_UPGRADE_COST_MULTIPLIERS[current_level]


func get_asset_type_production(asset_id: String) -> int:
	## 返回指定资产类别当前的整数总产出；包含固件加成，不包含任何临时增益。
	var definition: Dictionary = _get_asset_definition(asset_id)
	if definition.is_empty():
		return 0
	return _calculate_asset_type_production(int(definition.get("production", 0)), get_asset_quantity(asset_id), get_asset_upgrade_level(asset_id))


func get_asset_effective_unit_production(asset_id: String) -> int:
	## 返回固件加成后的单台整数产出；仅用于收益飘字等视觉展示，真实结算始终按类别整体取整。
	var definition: Dictionary = _get_asset_definition(asset_id)
	if definition.is_empty():
		return 0
	# 固件加成倍率；单台展示值向下取整，低产出资产在低等级时可能与基础值相同。
	var upgrade_multiplier: float = 1.0 + ASSET_UPGRADE_PRODUCTION_RATIO_PER_LEVEL * float(get_asset_upgrade_level(asset_id))
	return maxi(int(floor(float(int(definition.get("production", 0))) * upgrade_multiplier)), 0)


func upgrade_asset(asset_id: String) -> Dictionary:
	## 将指定资产的固件提升 1 级；升级按类别永久生效，出售资产不返还也不回退固件等级。
	var definition: Dictionary = _get_asset_definition(asset_id)
	if definition.is_empty():
		return {"success": false, "message": "资产无效"}
	if get_asset_quantity(asset_id) <= 0:
		return {"success": false, "message": "尚未持有该资产，无法升级固件"}
	# 当前固件等级；确认瞬间重新读取，防止连续弹窗导致越级升级。
	var current_level: int = get_asset_upgrade_level(asset_id)
	if current_level >= ASSET_UPGRADE_MAX_LEVEL:
		return {"success": false, "message": "固件已达到最大等级"}
	# 本次升级费用；按官方购买价乘当前等级对应倍率，等级越高费用越陡峭。
	var cost: int = get_asset_upgrade_cost(asset_id)
	if cost <= 0 or _balance < cost:
		return {"success": false, "message": "算力币余额不足"}
	_change_balance(-cost)
	_asset_upgrade_levels[asset_id] = current_level + 1
	_refresh_unlocks()
	_queue_save()
	assets_changed.emit()
	production_changed.emit(get_production_per_second())
	return {"success": true, "message": "固件升级完成", "asset_id": asset_id, "level": current_level + 1, "cost": cost}


func is_overclock_active() -> bool:
	## 查询超频是否生效中；剩余时间大于 0 即视为生效，散热冷却不属于生效状态。
	return _overclock_remaining_seconds > 0.0


func get_overclock_snapshot() -> Dictionary:
	## 返回超频状态快照；UI 据此渲染按钮文案、倒计时和可用状态，不获得内部引用。
	return {
		"active": is_overclock_active(),
		"remaining_seconds": _overclock_remaining_seconds,
		"cooldown_remaining_seconds": _overclock_cooldown_remaining_seconds,
		"ready": not is_overclock_active() and _overclock_cooldown_remaining_seconds <= 0.0,
		"ratio": OVERCLOCK_PRODUCTION_RATIO,
		"duration_seconds": OVERCLOCK_DURATION_SECONDS,
		"cooldown_seconds": OVERCLOCK_COOLDOWN_SECONDS,
	}


func activate_overclock() -> Dictionary:
	## 启动一次超频；生效期间产出加算 50%，结束后自动进入散热冷却，全部计时只消耗在线时间。
	if is_overclock_active():
		return {"success": false, "message": "超频正在进行中"}
	if _overclock_cooldown_remaining_seconds > 0.0:
		return {"success": false, "message": "矿场正在散热，暂时无法超频"}
	if get_base_production_per_second() <= 0:
		return {"success": false, "message": "没有运行中的算力资产"}
	_overclock_remaining_seconds = OVERCLOCK_DURATION_SECONDS
	_queue_save()
	overclock_changed.emit()
	buffs_changed.emit()
	production_changed.emit(get_production_per_second())
	return {"success": true, "message": "超频已启动", "duration_seconds": OVERCLOCK_DURATION_SECONDS}


func get_contract_definitions() -> Array[Dictionary]:
	return CONTRACT_DEFINITIONS.duplicate(true)


func has_active_contract() -> bool:
	## 查询是否存在进行中合同；同一时间最多允许一份合同，签订入口据此禁用。
	return not _active_contract_id.is_empty()


func get_active_contract_snapshot() -> Dictionary:
	## 返回进行中合同快照；无合同时返回空字典，UI 据此渲染倒计时与锁定金额。
	if not has_active_contract():
		return {}
	# 合同定义；进行中合同的标识在签订与加载时都已经过校验，此处必定存在。
	var definition: Dictionary = _get_contract_definition(_active_contract_id)
	return {
		"id": _active_contract_id,
		"name": str(definition.get("name", "算力合同")),
		"remaining_seconds": _contract_remaining_seconds,
		"duration_seconds": int(definition.get("duration_seconds", 0)),
		"gold_amount": _contract_gold_amount,
		"locked_compute": _contract_locked_compute,
		"payout_ratio": float(definition.get("payout_ratio", 0.0)),
	}


func get_contract_cost(contract_id: String, gold_amount: int) -> int:
	## 返回签订指定合同并到账指定星穹所需锁定的算力币；按费率整体反推并向上取整。
	var definition: Dictionary = _get_contract_definition(contract_id)
	if definition.is_empty() or gold_amount <= 0:
		return 0
	# 合同兑付比例；表示锁定算力币中最终转化为星穹的比例，剩余部分为费率损耗。
	var payout_ratio: float = clampf(float(definition.get("payout_ratio", 0.0)), 0.01, 1.0)
	return int(ceil(float(gold_amount * COMPUTE_COINS_PER_GOLD) / payout_ratio))


func get_maximum_contract_gold(contract_id: String) -> int:
	## 返回当前余额签订指定合同最多可到账的整数星穹；公式与正式签订完全一致。
	if _balance <= 0 or _get_contract_definition(contract_id).is_empty():
		return 0
	# 理论上界；忽略费率损耗时余额可兑换的星穹数一定不小于真实结果，可作为二分搜索右边界。
	var upper_bound: int = maxi(int(_balance / COMPUTE_COINS_PER_GOLD), 1)
	# 二分下界；始终表示当前已确认可支付的星穹数量。
	var lower_bound: int = 0
	while lower_bound < upper_bound:
		# 中间数量；向上取中点保证相邻区间可以正常收敛。
		var middle: int = int((lower_bound + upper_bound + 1) / 2)
		if get_contract_cost(contract_id, middle) <= _balance:
			lower_bound = middle
		else:
			upper_bound = middle - 1
	return lower_bound


func start_contract(contract_id: String, gold_amount: int) -> Dictionary:
	## 签订一份算力合同；立即锁定所需算力币，在线到期后自动按约定星穹结算，中途不可撤销。
	var definition: Dictionary = _get_contract_definition(contract_id)
	if definition.is_empty():
		return {"success": false, "message": "合同类型无效"}
	if has_active_contract():
		return {"success": false, "message": "已有进行中合同"}
	if gold_amount <= 0:
		return {"success": false, "message": "请输入至少 1 星穹"}
	# 本次锁定算力币；按费率反推并向上取整，签订后立即从余额扣除。
	var cost: int = get_contract_cost(contract_id, gold_amount)
	if _balance < cost:
		return {"success": false, "message": "算力币余额不足"}
	_change_balance(-cost)
	_active_contract_id = contract_id
	_contract_remaining_seconds = maxf(float(int(definition.get("duration_seconds", 0))), 1.0)
	_contract_gold_amount = gold_amount
	_contract_locked_compute = cost
	_queue_save()
	contract_changed.emit()
	return {"success": true, "message": "合同签订成功", "contract_id": contract_id, "gold": gold_amount, "locked": cost}


func take_offline_income_report() -> Dictionary:
	## 取走并清空待展示的离线收益报告；矿场面板首次打开时调用，重复调用返回空字典。
	if _pending_offline_report.is_empty():
		return {}
	# 报告副本；交给 UI 后立即清空内部记录，保证一次离线只弹一次报告。
	var report: Dictionary = _pending_offline_report.duplicate(true)
	_pending_offline_report.clear()
	return report


func _settle_production(whole_seconds: int) -> void:
	# 本次整数收益；当前每秒产出本身已向下取整，批量乘完整秒数不会产生小数或精度损耗。
	var earned: int = get_production_per_second() * maxi(whole_seconds, 0)
	if earned <= 0:
		return
	_change_balance(earned)
	production_settled.emit(earned, maxi(whole_seconds, 0))


func _change_balance(delta: int) -> void:
	if delta == 0:
		return
	# 新余额；所有扣款接口会预先校验，仍使用非负限制防止损坏数据继续扩散。
	var old_balance: int = _balance
	_balance = maxi(_balance + delta, 0)
	# 实际变化量；非负限制触发时以真实差额通知 UI，而不是使用请求值。
	var actual_delta: int = _balance - old_balance
	_queue_save()
	balance_changed.emit(_balance, actual_delta)


func _update_timed_buffs(delta: float) -> void:
	# 超频与合同计时；与骇入增益一样只消耗在线帧时间，系统时钟和关闭时长都不会参与计算。
	_update_overclock_state(delta)
	_update_contract_state(delta)
	if _hack_buff_remaining_seconds <= 0.0:
		return
	# 更新后的剩余时间；只消耗在线帧时间，系统时钟和关闭时长都不会参与计算。
	var previous_whole_second: int = int(ceil(_hack_buff_remaining_seconds))
	_hack_buff_remaining_seconds = maxf(_hack_buff_remaining_seconds - delta, 0.0)
	if _hack_buff_remaining_seconds <= 0.0:
		_hack_buff_ratio = 0.0
		_queue_save()
		buffs_changed.emit()
		production_changed.emit(get_production_per_second())
	elif int(ceil(_hack_buff_remaining_seconds)) != previous_whole_second and _panel_open:
		buffs_changed.emit()


func _update_overclock_state(delta: float) -> void:
	## 更新超频与散热的在线倒计时；超频归零时自动进入散热，散热归零时恢复可用并通知按钮刷新。
	if is_overclock_active():
		# 更新前的整数剩余秒；用于面板打开时按秒刷新增益倒计时而不逐帧发送信号。
		var previous_whole_second: int = int(ceil(_overclock_remaining_seconds))
		_overclock_remaining_seconds = maxf(_overclock_remaining_seconds - delta, 0.0)
		if _overclock_remaining_seconds <= 0.0:
			# 超频结束；立即写入完整散热时长，产出恢复为无超频状态。
			_overclock_cooldown_remaining_seconds = OVERCLOCK_COOLDOWN_SECONDS
			_queue_save()
			overclock_changed.emit()
			buffs_changed.emit()
			production_changed.emit(get_production_per_second())
		elif int(ceil(_overclock_remaining_seconds)) != previous_whole_second and _panel_open:
			buffs_changed.emit()
		return
	if _overclock_cooldown_remaining_seconds <= 0.0:
		return
	_overclock_cooldown_remaining_seconds = maxf(_overclock_cooldown_remaining_seconds - delta, 0.0)
	if _overclock_cooldown_remaining_seconds <= 0.0:
		# 散热完成；超频重新可用，仅通知按钮状态刷新，不影响产出数值。
		_queue_save()
		overclock_changed.emit()


func _update_contract_state(delta: float) -> void:
	## 更新进行中合同的在线倒计时；归零后自动完成结算，把约定星穹发放到局外库存。
	if not has_active_contract():
		return
	_contract_remaining_seconds = maxf(_contract_remaining_seconds - delta, 0.0)
	if _contract_remaining_seconds <= 0.0:
		_complete_active_contract()


func _complete_active_contract() -> void:
	## 完成进行中合同；清空合同状态并把约定星穹加入局外库存，战斗期间只标记挂起存档。
	# 本次到账星穹；先取出再清空状态，防止星穹服务回调期间重复结算。
	var gold_amount: int = _contract_gold_amount
	_active_contract_id = ""
	_contract_remaining_seconds = 0.0
	_contract_gold_amount = 0
	_contract_locked_compute = 0
	if _global_inventory != null and _global_inventory.has_method("adjust_coins"):
		_global_inventory.call("adjust_coins", gold_amount)
	if _is_combat_run_active():
		# 战斗期间完成；只做内存结算并挂起写盘，战斗结束或退出路径统一落盘，保证战斗帧不受磁盘 IO 影响。
		_queue_save()
	else:
		# 局外完成；合同结算属于跨文件资产变更，矿场与星穹存档立即同步保存。
		_flush_linked_saves()
	contract_completed.emit(gold_amount)
	contract_changed.emit()


func _settle_offline_income(last_online_unix_time: int) -> void:
	## 按上次在线时间戳补发离线收益；只在存档加载时调用一次，结果写入待展示报告。
	if last_online_unix_time <= 0:
		return
	# 原始离线秒数；系统时钟被回拨时可能为负，此时直接放弃本次补发。
	var raw_offline_seconds: int = int(Time.get_unix_time_from_system()) - last_online_unix_time
	if raw_offline_seconds <= 0:
		return
	# 有效离线秒数；超过上限的部分不参与补发，保持在线游玩收益始终更高。
	var capped_offline_seconds: int = mini(raw_offline_seconds, OFFLINE_INCOME_MAX_SECONDS)
	# 离线补发收益；按不含临时增益的基础总产出乘折算比例后向下取整。
	var earned: int = int(floor(float(get_base_production_per_second()) * float(capped_offline_seconds) * OFFLINE_INCOME_RATIO))
	if earned <= 0:
		return
	# 离线收益直接写入余额；此时面板尚未创建，不需要余额滚动信号，报告由面板打开时统一展示。
	_balance += earned
	_pending_offline_report = {
		"raw_offline_seconds": raw_offline_seconds,
		"offline_seconds": capped_offline_seconds,
		"earned": earned,
	}
	_queue_save()


func _calculate_asset_type_production(unit_production: int, quantity: int, upgrade_level: int) -> int:
	## 计算单类资产的整数总产出；固件加成按类别整体计算后向下取整，避免低产出资产按台取整后无收益。
	if unit_production <= 0 or quantity <= 0:
		return 0
	# 固件加成倍率；0 级为 1.0，每级增加固定比例。
	var upgrade_multiplier: float = 1.0 + ASSET_UPGRADE_PRODUCTION_RATIO_PER_LEVEL * float(clampi(upgrade_level, 0, ASSET_UPGRADE_MAX_LEVEL))
	return maxi(int(floor(float(unit_production * quantity) * upgrade_multiplier)), 0)


func _get_contract_definition(contract_id: String) -> Dictionary:
	for definition in CONTRACT_DEFINITIONS:
		if str(definition.get("id", "")) == contract_id:
			return definition
	return {}


func _connect_stock_market_service() -> void:
	# 股市服务；矿场仅监听公开刷新完成信号，缺失时独立挂机、交易和存档仍可正常工作。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_signal("market_refreshed"):
		stock_market_service.connect("market_refreshed", Callable(self, "_on_market_refreshed"))


func _on_market_refreshed(refresh_source: String) -> void:
	if refresh_source != STOCK_FULL_REFRESH_SOURCE:
		return
	# 股市服务；正式刷新完成后读取骇客数字科技的单轮真实涨幅。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	# 上一轮联动状态；任何正式全量刷新都先结束旧增益，再按本轮涨幅决定是否重新激活。
	var was_active: bool = _stock_buff_active
	_stock_buff_active = false
	if stock_market_service != null and stock_market_service.has_method("get_stock_snapshot"):
		# 股票快照；last_change_ratio 是该次刷新相对刷新前价格的实际变化比例。
		var stock_snapshot: Dictionary = stock_market_service.call("get_stock_snapshot", STOCK_BUFF_STOCK_ID) as Dictionary
		_stock_buff_active = float(stock_snapshot.get("last_change_ratio", 0.0)) >= STOCK_BUFF_TRIGGER_RATIO
	if was_active != _stock_buff_active:
		_queue_save()
		buffs_changed.emit()
		production_changed.emit(get_production_per_second())


func _refresh_unlocks() -> void:
	# 当前基础产出；解锁门槛只看资产基础总产出，不受临时增益影响。
	var base_production: int = get_base_production_per_second()
	# 是否发生新解锁；用于避免每次结算重复发送资产变化信号。
	var changed: bool = false
	for definition in ASSET_DEFINITIONS:
		# 资产标识；稳定写入存档并作为 UI 操作参数。
		var asset_id: String = str(definition.get("id", ""))
		# 解锁门槛；首个资产为 0，因此首次建立存档即解锁。
		var unlock_rate: int = maxi(int(definition.get("unlock_rate", 0)), 0)
		if base_production >= unlock_rate and not bool(_unlocked_assets.get(asset_id, false)):
			_unlocked_assets[asset_id] = true
			changed = true
	if changed:
		_queue_save()
		assets_changed.emit()


func _get_asset_definition(asset_id: String) -> Dictionary:
	for definition in ASSET_DEFINITIONS:
		if str(definition.get("id", "")) == asset_id:
			return definition
	return {}


func _initialize_default_state() -> void:
	_balance = 0
	_asset_quantities.clear()
	_unlocked_assets.clear()
	_asset_upgrade_levels.clear()
	_hack_buff_ratio = 0.0
	_hack_buff_remaining_seconds = 0.0
	_stock_buff_active = false
	_overclock_remaining_seconds = 0.0
	_overclock_cooldown_remaining_seconds = 0.0
	_active_contract_id = ""
	_contract_remaining_seconds = 0.0
	_contract_gold_amount = 0
	_contract_locked_compute = 0
	_pending_offline_report.clear()
	for definition in ASSET_DEFINITIONS:
		# 默认资产标识；所有数量从 0 开始，仅解锁门槛为 0 的入门资产。
		var asset_id: String = str(definition.get("id", ""))
		_asset_quantities[asset_id] = 0
		_unlocked_assets[asset_id] = int(definition.get("unlock_rate", 0)) <= 0
		# 默认固件等级；所有资产从 0 级开始，升级永久保存且不随出售回退。
		_asset_upgrade_levels[asset_id] = 0


func _queue_save() -> void:
	if _is_combat_run_active():
		# 战斗期间挂起写盘；余额与资产仍在内存按原周期实时结算，磁盘写入统一延迟到战斗结束、关闭窗口或服务退出。
		_combat_save_pending = true
		return
	if _save_queued:
		return
	_save_queued = true
	# 合并计时器；暂停状态继续运行，保证矿场面板或战斗暂停时的交易仍能按时落盘。
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
	## 查询当前是否处于正式战斗局；与股市服务使用同一 GlobalInventory 状态源，服务缺失时按局外处理。
	return _global_inventory != null and _global_inventory.has_method("is_combat_run_active") and bool(_global_inventory.call("is_combat_run_active"))


func _flush_linked_saves() -> void:
	_save_queued = false
	_save_state()
	if _global_inventory != null and _global_inventory.has_method("flush_stock_holdings_save"):
		# 库存即时保存接口会保存完整永久星穹数据，名称虽保留股票历史用途，但可安全复用跨存档兑换。
		_global_inventory.call("flush_stock_holdings_save")


func _save_state() -> void:
	# 任何真实落盘都会消化战斗期间的挂起标志；战斗结束、关闭窗口与联动保存共用该出口。
	_combat_save_pending = false
	# 存档数据；全部货币和资产数量均保存为整数，在线增益只保存剩余在线时长而不保存系统时间戳。
	# 离线收益补充；额外保存最后在线时间戳，仅用于下次启动补发封顶离线收益，不参与任何在线计时。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"balance": _balance,
		"asset_quantities": _asset_quantities,
		"unlocked_assets": _unlocked_assets,
		"asset_upgrade_levels": _asset_upgrade_levels,
		"hack_buff_ratio": _hack_buff_ratio,
		"hack_buff_remaining_seconds": _hack_buff_remaining_seconds,
		"stock_buff_active": _stock_buff_active,
		"overclock_remaining_seconds": _overclock_remaining_seconds,
		"overclock_cooldown_remaining_seconds": _overclock_cooldown_remaining_seconds,
		"active_contract_id": _active_contract_id,
		"contract_remaining_seconds": _contract_remaining_seconds,
		"contract_gold_amount": _contract_gold_amount,
		"contract_locked_compute": _contract_locked_compute,
		"last_online_unix_time": int(Time.get_unix_time_from_system()),
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
	# 解析结果；仅接受字典根节点，避免异常数组或基础类型覆盖服务状态。
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false
	# 存档字典；旧版本当前不存在，版本字段仍为未来迁移保留稳定入口。
	var save_data: Dictionary = parsed as Dictionary
	_balance = maxi(int(save_data.get("balance", 0)), 0)
	# 已保存数量表；逐个官方资产读取，未知资产不会进入运行时状态。
	var saved_quantities: Dictionary = save_data.get("asset_quantities", {}) as Dictionary
	# 已保存解锁表；缺失时按当前门槛重新推导，已有永久解锁不会因出售资产丢失。
	var saved_unlocks: Dictionary = save_data.get("unlocked_assets", {}) as Dictionary
	# 已保存固件等级表；缺失字段按 0 级处理，为固件功能上线前的旧存档提供默认值。
	var saved_upgrade_levels: Dictionary = save_data.get("asset_upgrade_levels", {}) as Dictionary
	for definition in ASSET_DEFINITIONS:
		# 资产标识；用于从两张存档表恢复同一资产的数据。
		var asset_id: String = str(definition.get("id", ""))
		_asset_quantities[asset_id] = maxi(int(saved_quantities.get(asset_id, 0)), 0)
		_unlocked_assets[asset_id] = bool(saved_unlocks.get(asset_id, int(definition.get("unlock_rate", 0)) <= 0))
		_asset_upgrade_levels[asset_id] = clampi(int(saved_upgrade_levels.get(asset_id, 0)), 0, ASSET_UPGRADE_MAX_LEVEL)
	_hack_buff_ratio = maxf(float(save_data.get("hack_buff_ratio", 0.0)), 0.0)
	_hack_buff_remaining_seconds = maxf(float(save_data.get("hack_buff_remaining_seconds", 0.0)), 0.0)
	if _hack_buff_remaining_seconds <= 0.0:
		_hack_buff_ratio = 0.0
	_stock_buff_active = bool(save_data.get("stock_buff_active", false))
	_overclock_remaining_seconds = maxf(float(save_data.get("overclock_remaining_seconds", 0.0)), 0.0)
	_overclock_cooldown_remaining_seconds = maxf(float(save_data.get("overclock_cooldown_remaining_seconds", 0.0)), 0.0)
	_active_contract_id = str(save_data.get("active_contract_id", ""))
	_contract_remaining_seconds = maxf(float(save_data.get("contract_remaining_seconds", 0.0)), 0.0)
	_contract_gold_amount = maxi(int(save_data.get("contract_gold_amount", 0)), 0)
	_contract_locked_compute = maxi(int(save_data.get("contract_locked_compute", 0)), 0)
	if not _active_contract_id.is_empty() and (_get_contract_definition(_active_contract_id).is_empty() or _contract_remaining_seconds <= 0.0 or _contract_gold_amount <= 0):
		# 合同数据异常兜底；合同类型被移除或计时数据损坏时退还锁定算力币并清空合同，不发放星穹。
		_balance += maxi(_contract_locked_compute, 0)
		_active_contract_id = ""
		_contract_remaining_seconds = 0.0
		_contract_gold_amount = 0
		_contract_locked_compute = 0
		_queue_save()
	# 离线收益补发；使用刚恢复的资产与固件状态计算基础产出，必须在全部资产字段就绪后执行。
	_settle_offline_income(int(save_data.get("last_online_unix_time", 0)))
	return true
