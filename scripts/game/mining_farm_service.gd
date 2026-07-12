extends Node

## 量子算力矿场服务在全部场景中持续运行，统一维护算力币、永久资产、在线增益与独立存档。
## UI、战斗结算和股市只通过公开接口或信号协作，不直接修改矿场内部状态。

signal balance_changed(balance: int, delta: int)
signal production_changed(production_per_second: int)
signal assets_changed
signal buffs_changed

## 矿场独立存档路径；默认与库存、股市存档分离，避免不同玩法的数据结构互相污染。
const SAVE_PATH: String = "user://mining_farm_state.json"
## 矿场存档版本；版本 1 保存整数余额、资产数量、永久解锁和在线增益剩余时间。
const SAVE_VERSION: int = 1
## 永久金币充值倍率；默认 1 金币兑换 10000 算力币，运行时不动态修改。
const COMPUTE_COINS_PER_GOLD: int = 10000
## 基础提现手续费率；默认 10%，提现所需算力币按到账金币反推并向上取整。
const WITHDRAWAL_FEE_RATIO: float = 0.10
## 资产出售返还比例；默认按当前官方购买价的 60% 向上取整返还算力币。
const ASSET_SELL_RETURN_RATIO: float = 0.60
## 骇入增益每金币加成比例；默认每 10 金币增加 0.01%，换算为每金币 0.00001 小数倍率。
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
## 当前累计未结算在线秒数；默认 0，达到前台或后台周期后批量结算完整秒数。
var _settlement_accumulator_seconds: float = 0.0
## 当前矿场面板是否打开；默认 false，决定结算信号频率但不改变单位时间收益。
var _panel_open: bool = false
## 是否已有存档等待执行；默认 false，用于合并频繁的逐秒收益写盘。
var _save_queued: bool = false
## 全局库存服务缓存；默认从 Autoload 获取，只用于永久金币的原子扣除和增加。
var _global_inventory: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_initialize_default_state()
	if not _load_state():
		_save_state()
	_connect_stock_market_service()
	_refresh_unlocks()
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
	var total: int = 0
	for definition in ASSET_DEFINITIONS:
		total += int(definition.get("production", 0)) * get_asset_quantity(str(definition.get("id", "")))
	return maxi(total, 0)


func get_production_per_second() -> int:
	# 总倍率；多个增益采用加算叠加，最终对总基础产出向下取整以维持整数货币规则。
	var multiplier: float = 1.0 + _hack_buff_ratio + (STOCK_BUFF_PRODUCTION_RATIO if _stock_buff_active else 0.0)
	return maxi(int(floor(float(get_base_production_per_second()) * multiplier)), 0)


func get_active_buffs() -> Array[Dictionary]:
	# 增益快照；UI 可安全显示名称、百分比和倒计时，不获得修改内部状态的引用。
	var buffs: Array[Dictionary] = []
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
	## 返回当前余额最多可到账的整数金币；公式与正式提现完全一致，不使用单金币成本近似。
	if _balance <= 0:
		return 0
	# 理论上界；忽略手续费时余额最多兑换的金币数一定不小于真实结果，可作为二分搜索右边界。
	var upper_bound: int = maxi(int(_balance / COMPUTE_COINS_PER_GOLD), 1)
	# 二分下界；始终表示当前已确认可支付的金币数量。
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
		return {"success": false, "message": "请输入至少 1 金币"}
	if _global_inventory == null or not _global_inventory.has_method("spend_coins"):
		return {"success": false, "message": "永久金币服务不可用"}
	if not bool(_global_inventory.call("spend_coins", gold_amount)):
		return {"success": false, "message": "永久金币不足"}
	# 到账算力币；兑换倍率为整数，充值不会产生任何手续费或精度损失。
	var compute_amount: int = gold_amount * COMPUTE_COINS_PER_GOLD
	_change_balance(compute_amount)
	_flush_linked_saves()
	return {"success": true, "message": "充值成功", "gold": gold_amount, "compute_coins": compute_amount}


func withdraw(gold_amount: int) -> Dictionary:
	# 所需算力币；按 10% 手续费反推并向上取整，因此提现 1 金币固定消耗 11112 算力币。
	var cost: int = get_withdrawal_cost(gold_amount)
	if gold_amount <= 0 or cost <= 0:
		return {"success": false, "message": "请输入至少 1 金币"}
	if _balance < cost:
		return {"success": false, "message": "算力币余额不足"}
	if _global_inventory == null or not _global_inventory.has_method("adjust_coins"):
		return {"success": false, "message": "永久金币服务不可用"}
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
	# 新增比例；每 10 金币固定增加 0.01%，允许与当前骇入增益直接叠加。
	var added_ratio: float = float(extracted_value_gold) * HACK_BUFF_RATIO_PER_GOLD
	_hack_buff_ratio += added_ratio
	_hack_buff_remaining_seconds = maxf(_hack_buff_remaining_seconds, 0.0) + HACK_BUFF_DURATION_SECONDS
	_queue_save()
	buffs_changed.emit()
	production_changed.emit(get_production_per_second())


func _settle_production(whole_seconds: int) -> void:
	# 本次整数收益；当前每秒产出本身已向下取整，批量乘完整秒数不会产生小数或精度损耗。
	var earned: int = get_production_per_second() * maxi(whole_seconds, 0)
	if earned <= 0:
		return
	_change_balance(earned)


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
	_hack_buff_ratio = 0.0
	_hack_buff_remaining_seconds = 0.0
	_stock_buff_active = false
	for definition in ASSET_DEFINITIONS:
		# 默认资产标识；所有数量从 0 开始，仅解锁门槛为 0 的入门资产。
		var asset_id: String = str(definition.get("id", ""))
		_asset_quantities[asset_id] = 0
		_unlocked_assets[asset_id] = int(definition.get("unlock_rate", 0)) <= 0


func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	# 合并计时器；暂停状态继续运行，保证矿场面板或战斗暂停时的交易仍能按时落盘。
	var timer: SceneTreeTimer = get_tree().create_timer(maxf(save_delay_seconds, 0.05), true, false, true)
	timer.timeout.connect(_flush_queued_save, CONNECT_ONE_SHOT)


func _flush_queued_save() -> void:
	_save_queued = false
	_save_state()


func _flush_linked_saves() -> void:
	_save_queued = false
	_save_state()
	if _global_inventory != null and _global_inventory.has_method("flush_stock_holdings_save"):
		# 库存即时保存接口会保存完整永久金币数据，名称虽保留股票历史用途，但可安全复用跨存档兑换。
		_global_inventory.call("flush_stock_holdings_save")


func _save_state() -> void:
	# 存档数据；全部货币和资产数量均保存为整数，在线增益只保存剩余在线时长而不保存系统时间戳。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"balance": _balance,
		"asset_quantities": _asset_quantities,
		"unlocked_assets": _unlocked_assets,
		"hack_buff_ratio": _hack_buff_ratio,
		"hack_buff_remaining_seconds": _hack_buff_remaining_seconds,
		"stock_buff_active": _stock_buff_active,
	}
	# 存档文件；失败时保持内存状态，下一次变更仍会再次尝试写入。
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data))


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
	for definition in ASSET_DEFINITIONS:
		# 资产标识；用于从两张存档表恢复同一资产的数据。
		var asset_id: String = str(definition.get("id", ""))
		_asset_quantities[asset_id] = maxi(int(saved_quantities.get(asset_id, 0)), 0)
		_unlocked_assets[asset_id] = bool(saved_unlocks.get(asset_id, int(definition.get("unlock_rate", 0)) <= 0))
	_hack_buff_ratio = maxf(float(save_data.get("hack_buff_ratio", 0.0)), 0.0)
	_hack_buff_remaining_seconds = maxf(float(save_data.get("hack_buff_remaining_seconds", 0.0)), 0.0)
	if _hack_buff_remaining_seconds <= 0.0:
		_hack_buff_ratio = 0.0
	_stock_buff_active = bool(save_data.get("stock_buff_active", false))
	return true
