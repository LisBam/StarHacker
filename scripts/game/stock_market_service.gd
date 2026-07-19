extends Node

## 股市服务独立维护行情、动态价值中枢、大盘周期、随机事件和对局行为统计。
## UI 只读取公开快照并请求交易；星穹与持仓所有权由 GlobalInventory 统一结算和持久化。
## 证券币职责补充；StockMarketService 独立持有证券币余额并结算股票，GlobalInventory 只持有永久星穹与股票数量。

signal market_changed
signal event_announced(message: String)
## 行情刷新完成信号；参数为刷新来源，供矿场等外部系统只在指定刷新类型上执行低耦合联动。
signal market_refreshed(refresh_source: String)
## 证券币余额变化信号；充值、提现和股票成交成功后通知股市界面刷新独立账户余额。
signal securities_balance_changed(balance: float)

## 股市全局状态存档路径；与商店状态同级独立保存，避免行情字段污染库存物品序列化结构。
const SAVE_PATH: String = "user://stock_market_state.json"
## 股市状态存档版本；版本 1 保存五只股票的行情、周期、事件、行为连续性和局外运行累计值。
## 版本 2 补充；新增大盘、涨跌周期和随机事件的非战斗在线时长双触发进度。
## 版本 3 补充；在线触发阈值统一扩大 3 倍，并按原进度比例迁移版本 2 的累计时长与事件目标。
## 版本 4 补充；新增支持两位小数的证券币余额，旧存档默认从 0.00 证券币开始。
const SAVE_VERSION: int = 4
## 牛市状态标识；价值中枢和短期情绪默认向正方向倾斜。
const MARKET_BULL: String = "bull"
## 熊市状态标识；价值中枢和短期情绪默认向负方向倾斜。
const MARKET_BEAR: String = "bear"
## 震荡市状态标识；方向接近中性且短期波动幅度扩大。
const MARKET_SIDEWAYS: String = "sideways"
## 对局结算刷新来源标识；启用完整波动、玩家行为和对局涨跌停规则。
const REFRESH_SETTLEMENT: String = "settlement"
## 局外运行刷新来源标识；只使用半幅情绪、低概率中枢漂移和半幅均值回归。
const REFRESH_RUNTIME: String = "runtime"
## 股市面板微行情刷新来源标识；面板打开时每秒产生可见小幅波动，不推进玩法周期或事件次数。
const REFRESH_DISPLAY: String = "display"
## 股票稳定顺序；UI、存档迁移、行为统计和事件目标统一使用该顺序。
const STOCK_IDS: Array[String] = ["quantum_arms", "astral_defense", "hacker_tech", "frontline_supply", "relic_exploration"]
## 股票静态目录；初始价仅用于首次初始化和极端软上下限，不作为长期强制回归锚点。
const STOCK_DEFINITIONS: Dictionary = {
	"quantum_arms": {"name": "量子军备集团", "module": "全品类远程、近战武器", "base_price": 120.0, "volatility": 0.030},
	"astral_defense": {"name": "星穹防务工业", "module": "四部位防具装备", "base_price": 90.0, "volatility": 0.020},
	"hacker_tech": {"name": "骇客数字科技", "module": "强化石、锻造增幅系统", "base_price": 150.0, "volatility": 0.030},
	"frontline_supply": {"name": "前线保障供应链", "module": "修复包、物资撤离补给", "base_price": 60.0, "volatility": 0.020},
	"relic_exploration": {"name": "遗迹勘探开发", "module": "宝箱、稀有掉落与高价值物资", "base_price": 200.0, "volatility": 0.045},
}
## 随机事件目录；duration_settlement 控制对局中枢强制次数，duration_refresh 控制全部刷新情绪或波动次数。
const EVENT_DEFINITIONS: Array[Dictionary] = [
	{"id": "arms_good", "message": "量子武器新批次量产下线", "stock_id": "quantum_arms", "direction": 1, "duration_settlement": 2, "duration_refresh": 2},
	{"id": "defense_good", "message": "新型复合护甲通过实战认证", "stock_id": "astral_defense", "direction": 1, "duration_settlement": 2, "duration_refresh": 2},
	{"id": "tech_good", "message": "强化算法取得重大突破", "stock_id": "hacker_tech", "direction": 1, "duration_settlement": 2, "duration_refresh": 3},
	{"id": "supply_good", "message": "前线补给线全线贯通", "stock_id": "frontline_supply", "direction": 1, "duration_settlement": 2, "duration_refresh": 2},
	{"id": "relic_good", "message": "大型遗迹群勘探确认", "stock_id": "relic_exploration", "direction": 1, "duration_settlement": 2, "duration_refresh": 3},
	{"id": "arms_bad", "message": "武器主生产线故障停产", "stock_id": "quantum_arms", "direction": -1, "duration_settlement": 2, "duration_refresh": 2},
	{"id": "defense_bad", "message": "防具原材料价格大幅上涨", "stock_id": "astral_defense", "direction": -1, "duration_settlement": 2, "duration_refresh": 2},
	{"id": "tech_bad", "message": "区域防火墙全面升级", "stock_id": "hacker_tech", "direction": -1, "duration_settlement": 2, "duration_refresh": 3},
	{"id": "supply_bad", "message": "补给通道遭电磁破坏", "stock_id": "frontline_supply", "direction": -1, "duration_settlement": 2, "duration_refresh": 2},
	{"id": "relic_bad", "message": "遗迹勘探发生安全事故", "stock_id": "relic_exploration", "direction": -1, "duration_settlement": 2, "duration_refresh": 3},
	{"id": "global_bull", "message": "量子科技板块牛市行情", "stock_id": "", "direction": 1, "temporary_market": MARKET_BULL, "duration_settlement": 2, "duration_refresh": 2},
	{"id": "global_bear", "message": "市场恐慌情绪蔓延", "stock_id": "", "direction": -1, "temporary_market": MARKET_BEAR, "duration_settlement": 2, "duration_refresh": 2},
	{"id": "global_volatile", "message": "市场震荡整理", "stock_id": "", "direction": 0, "volatility_multiplier": 1.5, "duration_settlement": 0, "duration_refresh": 5},
]

## 局外运行刷新间隔；默认 60 秒，只在非战斗场景累计，运行时通常不动态修改。
@export_range(10.0, 600.0, 1.0) var runtime_refresh_interval_seconds: float = 60.0
## 面板微行情刷新间隔；默认 1 秒，股市界面打开期间玩家每秒都能看到价格与折线变化。
@export_range(0.2, 10.0, 0.1) var display_refresh_interval_seconds: float = 1.0
## 面板微行情波动尺度；默认使用标准波动的 18%，让两位小数价格持续变化且不破坏长期经济平衡。
## 波动增强补充：现行默认值为 0.22，使面板每秒微行情比原 0.18 尺度提高约 22%。
@export_range(0.01, 0.50, 0.01) var display_fluctuation_scale: float = 0.22
## 全局行情波动倍率；默认 1.25，使正式结算、局外刷新与面板微行情的随机情绪幅度统一提高 25%，运行时通常不动态修改。
@export_range(0.50, 3.00, 0.05) var market_volatility_multiplier: float = 1.25
## 大盘正式结算切换周期；默认 8 局，低于 5 会明显削弱趋势感。
@export_range(5, 30, 1) var market_cycle_settlement_count: int = 8
## 大盘在线时长切换周期；默认 480 秒即 8 分钟，与 8 局正式结算并行且任一先达到即触发。
## 三倍时长补充；当前默认值为 1440 秒即 24 分钟，正式结算阈值仍保持 8 局。
@export_range(60.0, 3600.0, 1.0) var market_cycle_online_seconds: float = 1440.0
## 涨跌停累计周期；默认每 5 次正式结算重置单股累计涨跌幅。
@export_range(3, 20, 1) var price_limit_cycle_settlement_count: int = 5
## 涨跌停在线时长周期；默认 300 秒即 5 分钟，与 5 局正式结算并行且任一先达到即重置周期。
## 三倍时长补充；当前默认值为 900 秒即 15 分钟，正式结算阈值仍保持 5 局。
@export_range(60.0, 1800.0, 1.0) var price_limit_cycle_online_seconds: float = 900.0
## 随机事件最短间隔；默认 2 局，低于 2 会让事件噪音淹没行为影响。
@export_range(2, 20, 1) var event_interval_minimum_settlements: int = 2
## 随机事件最长间隔；默认 6 局，必须不小于最短间隔。
@export_range(2, 30, 1) var event_interval_maximum_settlements: int = 6
## 随机事件最短在线间隔；默认 120 秒即 2 分钟，与正式结算间隔并行计算。
## 三倍时长补充；当前最短在线间隔为 360 秒即 6 分钟。
@export_range(30.0, 1800.0, 1.0) var event_interval_minimum_online_seconds: float = 360.0
## 随机事件最长在线间隔；默认 360 秒即 6 分钟，每次事件后重新随机目标时长。
## 三倍时长补充；当前最长在线间隔为 1080 秒即 18 分钟。
@export_range(30.0, 3600.0, 1.0) var event_interval_maximum_online_seconds: float = 1080.0
## 单次正式结算涨跌幅上限；默认 15%，防止多层因素叠加产生瞬时极端价格。
@export_range(0.01, 0.50, 0.01) var settlement_change_limit: float = 0.15
## 单次局外运行涨跌幅上限；默认 7.5%，等于正式结算上限的一半。
@export_range(0.005, 0.25, 0.005) var runtime_change_limit: float = 0.075
## 单次面板微行情涨跌幅上限；默认 1%，只限制每秒可见波动，不影响正式和 60 秒刷新上限。
@export_range(0.001, 0.05, 0.001) var display_change_limit: float = 0.01
## 周期累计涨跌幅上限；默认正负 30%，达到后剩余正式刷新被限制在周期边界内。
@export_range(0.05, 1.0, 0.01) var cycle_change_limit: float = 0.30
## 股票买卖手续费比例；默认成交额的 0.5%，手续费最低 0.01 证券币，运行时无需动态修改。
@export_range(0.0, 0.20, 0.001) var stock_trade_fee_ratio: float = 0.005
## 证券币提现手续费比例；默认提现额的 0.5%，扣费后只把整数部分转为永久星穹，运行时无需动态修改。
@export_range(0.0, 0.20, 0.001) var securities_withdrawal_fee_ratio: float = 0.005

## 全局库存服务；负责星穹、持仓和正式对局活动状态，缺失时行情仍可独立运行和调试。
var _global_inventory: Node
## 行情运行时状态；键为股票标识，值包含当前价、中枢、历史、周期起点和连续行为方向。
var _stock_states: Dictionary = {}
## 当前长期大盘状态；默认震荡市，每 8 次正式结算随机切换为不同状态。
var _market_state: String = MARKET_SIDEWAYS
## 已完成正式结算总数；用于大盘周期、涨跌停周期与随机事件间隔计数。
var _settlement_count: int = 0
## 大盘正式结算周期进度；达到 8 局时切换大盘并同步清零在线进度。
var _market_cycle_settlement_progress: int = 0
## 大盘非战斗在线时长进度；达到 8 分钟时切换大盘并同步清零正式结算进度。
## 三倍时长补充；当前实际阈值为 24 分钟，修改只影响在线路径。
var _market_cycle_online_accumulated_seconds: float = 0.0
## 涨跌停正式结算周期进度；达到 5 局时重置全部股票的累计涨跌周期起点。
var _price_limit_cycle_settlement_progress: int = 0
## 涨跌停非战斗在线时长进度；达到 5 分钟时重置周期并同步清零正式结算进度。
## 三倍时长补充；当前实际阈值为 15 分钟，修改只影响在线路径。
var _price_limit_cycle_online_accumulated_seconds: float = 0.0
## 距离下一次随机事件的剩余正式结算数；默认启动时在 2 到 6 之间随机生成。
var _settlements_until_event: int = 0
## 随机事件非战斗在线累计时长；达到本轮随机目标时触发事件并同步重置正式结算倒数。
var _event_online_accumulated_seconds: float = 0.0
## 本轮随机事件在线目标时长；默认在 120 至 360 秒之间独立随机。
## 三倍时长补充；当前实际随机区间为 360 至 1080 秒，即 6 至 18 分钟。
var _event_online_target_seconds: float = 0.0
## 当前事件状态；空字典表示没有事件，非空时保存事件定义与剩余作用次数。
var _active_event: Dictionary = {}
## 非战斗场景累计运行秒数；达到 60 秒后扣除一个周期并触发一次小幅刷新。
var _runtime_accumulated_seconds: float = 0.0
## 股市面板微行情累计秒数；仅面板打开且不在战斗中时累计，达到 1 秒后触发可见波动。
var _display_accumulated_seconds: float = 0.0
## 股市面板是否正在显示；默认 false，由 StockMarketPanel 打开和关闭时通过公开接口同步。
var _market_panel_open: bool = false
## 当前证券币余额；默认 0.00，只归股市服务所有，充值、提现和股票成交均保留两位小数。
var _securities_balance: float = 0.0
## 本局行为原始统计；键为通用指标名，值为累计数量或价值，用于正式结算时计算五只股票影响。
var _run_metrics: Dictionary = {}
## 上一帧正式对局活动状态；用于从 GlobalInventory 的无参数状态信号识别开始与完成边界。
var _previous_run_active: bool = false
## 服务随机数生成器；负责中枢、情绪、大盘与事件抽取，启动时随机化。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_initialize_default_states()
	# 行情读档结果；首次运行或损坏存档时立即写入完整默认状态，确保初始化可追溯。
	var state_loaded: bool = _load_state()
	if _settlements_until_event <= 0:
		_roll_next_event_interval()
	if _event_online_target_seconds <= 0.0:
		_roll_next_online_event_interval()
	if not state_loaded:
		_save_state()
	if _global_inventory != null and _global_inventory.has_signal("run_state_changed"):
		_global_inventory.connect("run_state_changed", Callable(self, "_on_run_state_changed"))
	_previous_run_active = _is_combat_run_active()
	set_process(not _previous_run_active)


func _process(delta: float) -> void:
	if _is_combat_run_active():
		return
	_update_online_time_triggers(maxf(delta, 0.0))
	_runtime_accumulated_seconds += maxf(delta, 0.0)
	# 有效局外刷新间隔；至少 1 秒，避免检查器异常配置造成无限循环。
	var interval: float = maxf(runtime_refresh_interval_seconds, 1.0)
	while _runtime_accumulated_seconds >= interval:
		_runtime_accumulated_seconds -= interval
		refresh_market(REFRESH_RUNTIME)
	if not _market_panel_open:
		return
	_display_accumulated_seconds += maxf(delta, 0.0)
	# 有效面板刷新间隔；至少 0.1 秒，默认每 1 秒触发一次真实微行情。
	var display_interval: float = maxf(display_refresh_interval_seconds, 0.1)
	while _display_accumulated_seconds >= display_interval:
		_display_accumulated_seconds -= display_interval
		refresh_market(REFRESH_DISPLAY)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()


func set_market_panel_open(open: bool) -> void:
	if _market_panel_open == open:
		return
	_market_panel_open = open
	_display_accumulated_seconds = 0.0
	if not open:
		# 面板关闭时统一保存每秒微行情最终价格，避免打开期间每秒写盘造成频繁磁盘操作。
		_save_state()


func get_stock_definitions() -> Dictionary:
	return STOCK_DEFINITIONS.duplicate(true)


func get_market_snapshot() -> Dictionary:
	# 股票快照表；逐只深复制运行时状态，外部不能直接修改服务内存。
	var stocks: Dictionary = {}
	for stock_id in STOCK_IDS:
		# 单股运行时状态；包含价格、中枢、历史、行为连续性和调试概率。
		var state: Dictionary = _stock_states.get(stock_id, {}) as Dictionary
		stocks[stock_id] = state.duplicate(true)
	return {
		"market_state": _market_state,
		"market_state_name": _get_market_state_name(_get_effective_market_state()),
		"settlement_count": _settlement_count,
		"runtime_progress": clampf(_runtime_accumulated_seconds / maxf(runtime_refresh_interval_seconds, 1.0), 0.0, 1.0),
		"active_event": _active_event.duplicate(true),
		"stocks": stocks,
	}


func get_stock_snapshot(stock_id: String) -> Dictionary:
	if not stock_id in STOCK_IDS:
		return {}
	# 合并快照；先复制静态定义，再用运行时行情字段覆盖同名键。
	var result: Dictionary = (STOCK_DEFINITIONS.get(stock_id, {}) as Dictionary).duplicate(true)
	result.merge((_stock_states.get(stock_id, {}) as Dictionary).duplicate(true), true)
	result["stock_id"] = stock_id
	return result


func get_current_price(stock_id: String) -> float:
	# 单股运行时状态；内部价格使用浮点平滑计算，成交时四舍五入为正整数星穹。
	# 证券币成交规则；旧整数说明仅保留历史注释兼容，当前返回与玩家界面一致的两位小数证券币价格，不再转换为整数。
	var state: Dictionary = _stock_states.get(stock_id, {}) as Dictionary
	return maxf(snappedf(float(state.get("price", 0.0)), 0.01), 0.01)


func get_securities_balance() -> float:
	## 返回证券币账户余额；统一标准化为非负两位小数，外部只能通过股市服务公开接口修改。
	return _normalize_securities_amount(_securities_balance)


func get_withdrawal_fee_ratio() -> float:
	## 返回当前证券币提现手续费比例；UI 只读取该值进行预览，最终费用仍由服务重新计算。
	return clampf(securities_withdrawal_fee_ratio, 0.0, 1.0)


func get_minimum_withdrawal_amount() -> int:
	## 返回扣除当前手续费后至少到账 1 星穹所需的最小整数证券币；异常高费率无法到账时返回 0。
	for securities_amount in range(1, 101):
		# 当前候选手续费；复用最终提现公式，确保按钮门槛和服务执行结果一致。
		var fee: float = _calculate_securities_fee(float(securities_amount), securities_withdrawal_fee_ratio)
		if floori(float(securities_amount) - fee) >= 1:
			return securities_amount
	return 0


func get_stock_trade_fee_ratio() -> float:
	## 返回当前股票买卖手续费比例；数量弹窗只用于实时预览，最终手续费仍由服务重新计算。
	return clampf(stock_trade_fee_ratio, 0.0, 1.0)


func request_securities_deposit(coin_amount: int) -> Dictionary:
	## 按 1:1 把整数永久星穹充值为证券币；星穹扣除失败时证券币余额保持不变。
	if coin_amount <= 0 or _global_inventory == null or not _global_inventory.has_method("spend_coins"):
		return {"success": false, "message": "无法执行充值"}
	# 星穹扣款结果；库存服务会在同一调用中再次复核实时星穹余额，防止弹窗额度过期。
	var coins_spent: bool = bool(_global_inventory.call("spend_coins", coin_amount))
	if not coins_spent:
		return {"success": false, "message": "星穹不足，充值未执行"}
	_securities_balance = _normalize_securities_amount(_securities_balance + float(coin_amount))
	# 星穹立即保存；与证券币状态在同一次成功兑换路径落盘，缩短两份资产存档的不一致窗口。
	if _global_inventory.has_method("flush_stock_holdings_save"):
		_global_inventory.call("flush_stock_holdings_save")
	_save_state()
	securities_balance_changed.emit(_securities_balance)
	return {"success": true, "message": "已充值 %d.00 证券币" % coin_amount, "coins": coin_amount, "securities": float(coin_amount)}


func request_securities_withdrawal(securities_amount: int) -> Dictionary:
	## 把整数证券币提现为永久星穹；手续费从提现额中扣除，到账星穹取扣费后金额的整数部分。
	if securities_amount <= 0 or _global_inventory == null or not _global_inventory.has_method("adjust_coins"):
		return {"success": false, "message": "无法执行提现"}
	# 当前提现额；接口只接受整数，仍转为浮点用于证券币两位小数结算。
	var requested_amount: float = float(securities_amount)
	if _securities_balance + 0.0001 < requested_amount:
		return {"success": false, "message": "证券币不足，提现未执行"}
	# 提现手续费；按配置比例计算并向上保留到 0.01 证券币，正额提现最低收取 0.01。
	var fee: float = _calculate_securities_fee(requested_amount, securities_withdrawal_fee_ratio)
	# 扣费后可兑换额；外部星穹只支持整数，因此只发放向下取整的整数部分。
	var received_coins: int = floori(maxf(requested_amount - fee, 0.0))
	if received_coins <= 0:
		return {"success": false, "message": "扣除手续费后不足 1 星穹"}
	_global_inventory.call("adjust_coins", received_coins)
	_securities_balance = _normalize_securities_amount(_securities_balance - requested_amount)
	# 星穹立即保存；与证券币状态在同一次成功兑换路径落盘，缩短两份资产存档的不一致窗口。
	if _global_inventory.has_method("flush_stock_holdings_save"):
		_global_inventory.call("flush_stock_holdings_save")
	_save_state()
	securities_balance_changed.emit(_securities_balance)
	return {"success": true, "message": "提现成功，到账 %d 星穹" % received_coins, "securities": requested_amount, "fee": fee, "coins": received_coins}


func get_maximum_buy_quantity(stock_id: String) -> int:
	# 当前整数成交价；必须大于 0 才可计算可买数量。
	# 证券币成交规则；旧整数说明仅保留历史注释兼容，当前价格为两位小数证券币。
	var price: float = get_current_price(stock_id)
	# 当前永久星穹；由 GlobalInventory 作为唯一所有者提供。
	# 证券币余额规则；旧星穹说明仅保留历史注释兼容，股票买入只使用股市服务独立证券币余额。
	var coins: float = get_securities_balance()
	if price <= 0.0 or coins <= 0.0:
		return 0
	# 初始数量估算；先按不含手续费的整股数量计算，再向下校验含费实际花费。
	var estimated_quantity: int = maxi(floori(coins / price), 0)
	while estimated_quantity > 0:
		# 估算总额；手续费按总成交额 0.5% 向上取整且最低 1 星穹。
		# 证券币手续费规则；旧整数说明仅保留历史注释兼容，手续费向上保留至 0.01 证券币且最低 0.01。
		var estimated_gross: float = _normalize_securities_amount(price * estimated_quantity)
		# 估算手续费；与最终买入请求使用同一公式，防止数量弹窗出现无法成交的上限。
		var estimated_fee: float = _calculate_securities_fee(estimated_gross, stock_trade_fee_ratio)
		if _normalize_securities_amount(estimated_gross + estimated_fee) <= coins + 0.0001:
			break
		estimated_quantity -= 1
	return estimated_quantity


func get_trade_quote(stock_id: String, quantity: int, trade_type: String) -> Dictionary:
	## 生成指定数量的实时交易报价；该接口只读取行情、星穹和持仓，不修改任何资产。
	## 返回字典包含单价、成交额、手续费、最终金额和当前可执行状态，供所有交易界面统一展示。
	if not stock_id in STOCK_IDS or quantity <= 0 or not trade_type in ["buy", "sell"]:
		return {"valid": false, "executable": false, "message": "交易参数无效"}
	# 当前整数成交价；每次调用都读取当秒行情，交易流程中的旧报价不会参与计算。
	# 证券币成交规则；旧整数说明仅保留历史注释兼容，当前报价保留两位小数且不进行整数四舍五入。
	var price: float = get_current_price(stock_id)
	# 实时成交额；数量乘当前整数单价，不包含手续费。
	# 证券币成交规则；旧整数说明仅保留历史注释兼容，成交额按两位小数证券币结算。
	var gross: float = _normalize_securities_amount(price * quantity)
	# 实时手续费；买卖均按成交额 0.5% 向上取整且最低 1 星穹。
	# 证券币手续费规则；旧整数说明仅保留历史注释兼容，手续费向上保留至 0.01 且最低 0.01 证券币。
	var fee: float = _calculate_securities_fee(gross, stock_trade_fee_ratio)
	# 当前可用星穹；库存服务不可用时按 0 处理并令买入报价不可执行。
	# 证券币余额规则；旧星穹说明仅保留历史注释兼容，买入可用余额来自股市独立账户。
	var available_coins: float = get_securities_balance()
	# 当前持仓数量；库存服务不可用或没有持仓时按 0 处理并令卖出报价不可执行。
	var available_quantity: int = int((_global_inventory.call("get_stock_holding", stock_id) as Dictionary).get("quantity", 0)) if _global_inventory != null and _global_inventory.has_method("get_stock_holding") else 0
	# 最终结算金额；买入为成交额加手续费，卖出为扣除 0.5% 后向下取整且最低 1 星穹。
	# 证券币最终金额；买入加手续费，卖出扣手续费，全部保留两位小数且卖出最低为 0.01 证券币。
	var total: float = _normalize_securities_amount(gross + fee) if trade_type == "buy" else maxf(_normalize_securities_amount(gross - fee), 0.01)
	# 当前报价是否可执行；买入复核星穹，卖出复核持仓，防止弹窗展示期间资产或价格变化造成非法成交。
	var executable: bool = available_coins + 0.0001 >= total if trade_type == "buy" else available_quantity >= quantity
	# 不可执行原因；用于二次确认窗口明确提示玩家需要等待价格回落、减少数量或检查持仓。
	var message: String = "可以成交"
	if not executable:
		message = "证券币不足，需要 %.2f，当前仅有 %.2f" % [total, available_coins] if trade_type == "buy" else "持仓不足，当前仅有 %d 股" % available_quantity
	return {
		"valid": true,
		"executable": executable,
		"message": message,
		"quantity": quantity,
		"price": price,
		"gross": gross,
		"fee": fee,
		"total": total,
		"available_coins": available_coins,
		"available_quantity": available_quantity,
	}


func request_buy(stock_id: String, quantity: int, quoted_price: int = -1) -> Dictionary:
	if not stock_id in STOCK_IDS or quantity <= 0 or _global_inventory == null or not _global_inventory.has_method("add_stock_holding_without_currency"):
		return {"success": false, "message": "无法执行买入"}
	# 当前成交单价；确认时重新读取，避免数量选择期间行情变化后使用旧价格。
	# 报价锁定补充；UI 传入正整数 quoted_price 时使用弹窗打开瞬间的锁定价格，未传入时读取实时价格。
	# 实时成交规则；旧锁价说明仅保留历史注释兼容，quoted_price 参数只维持调用兼容，任何传入值都不会覆盖点击确认瞬间的实时行情。
	var price: float = get_current_price(stock_id)
	# 买入成交额；数量乘当前价，不包含手续费。
	var gross: float = _normalize_securities_amount(price * quantity)
	# 买入手续费；成交额 0.5% 向上取整且最低 1 星穹。
	var fee: float = _calculate_securities_fee(gross, stock_trade_fee_ratio)
	# 买入总花费；成交额与手续费相加后交给库存原子扣款。
	var total_cost: float = _normalize_securities_amount(gross + fee)
	# 买入结果；库存服务会再次校验星穹并更新加权成本。
	# 证券币原子校验；旧星穹说明仅保留历史注释兼容，先复核股市余额，再写入不处理货币的持仓接口。
	if _securities_balance + 0.0001 < total_cost:
		return {"success": false, "message": "证券币不足，需要 %.2f，当前仅有 %.2f" % [total_cost, _securities_balance], "quantity": quantity, "price": price, "fee": fee, "total": total_cost}
	# 本次含费单位成本；持仓加权成本使用证券币实际支出，不丢弃小数部分。
	var transaction_unit_cost: float = total_cost / float(quantity)
	var success: bool = bool(_global_inventory.call("add_stock_holding_without_currency", stock_id, quantity, transaction_unit_cost))
	if success:
		_securities_balance = _normalize_securities_amount(_securities_balance - total_cost)
		# 持仓立即保存；与下方证券币状态同一次成功路径落盘，缩短跨文件交易状态的不一致窗口。
		if _global_inventory.has_method("flush_stock_holdings_save"):
			_global_inventory.call("flush_stock_holdings_save")
		_save_state()
		securities_balance_changed.emit(_securities_balance)
	# 买入失败说明；库存原子扣款失败时返回点击瞬间所需金额与余额，避免旧弹窗价格造成原因不明。
	# 证券币失败说明；旧星穹说明仅保留历史注释兼容，持仓接口失败时不会扣除证券币。
	var failure_message: String = "持仓服务不可用，证券币未扣除"
	return {"success": success, "message": "买入成功" if success else failure_message, "quantity": quantity, "price": price, "fee": fee, "total": total_cost}


func request_sell(stock_id: String, quantity: int, quoted_price: int = -1) -> Dictionary:
	if not stock_id in STOCK_IDS or quantity <= 0 or _global_inventory == null or not _global_inventory.has_method("remove_stock_holding_without_currency"):
		return {"success": false, "message": "无法执行卖出"}
	# 当前成交单价；确认时重新读取，确保即时交易使用实时报价。
	# 报价锁定补充；UI 传入正整数 quoted_price 时使用弹窗打开瞬间的锁定价格，未传入时读取实时价格。
	# 实时成交规则；旧锁价说明仅保留历史注释兼容，quoted_price 参数只维持调用兼容，任何传入值都不会覆盖点击确认瞬间的实时行情。
	var price: float = get_current_price(stock_id)
	# 卖出成交额；数量乘当前价，不包含手续费。
	var gross: float = _normalize_securities_amount(price * quantity)
	# 卖出手续费；用于确认框明示，实际所得按乘 0.995 后向下取整。
	var fee: float = _calculate_securities_fee(gross, stock_trade_fee_ratio)
	# 卖出实际所得；向下取整且最低 1 星穹。
	# 证券币卖出所得；旧整数说明仅保留历史注释兼容，成交额扣除两位小数手续费后最低为 0.01 证券币。
	var proceeds: float = maxf(_normalize_securities_amount(gross - fee), 0.01)
	# 卖出结果；库存服务会再次校验持仓数量并实时增加永久星穹。
	# 证券币结算规则；旧星穹说明仅保留历史注释兼容，持仓扣除成功后才增加股市独立账户余额。
	var success: bool = bool(_global_inventory.call("remove_stock_holding_without_currency", stock_id, quantity))
	if success:
		_securities_balance = _normalize_securities_amount(_securities_balance + proceeds)
		# 持仓立即保存；与下方证券币状态同一次成功路径落盘，缩短跨文件交易状态的不一致窗口。
		if _global_inventory.has_method("flush_stock_holdings_save"):
			_global_inventory.call("flush_stock_holdings_save")
		_save_state()
		securities_balance_changed.emit(_securities_balance)
	return {"success": success, "message": "卖出成功" if success else "持仓数量不足", "quantity": quantity, "price": price, "fee": fee, "total": proceeds}


func refresh_market(refresh_source: String = REFRESH_SETTLEMENT) -> void:
	# 是否为正式结算刷新；决定完整波动、玩家行为、周期和事件计数是否生效。
	var is_settlement: bool = refresh_source == REFRESH_SETTLEMENT
	# 是否为面板微行情刷新；该来源只更新价格、涨跌幅和历史，不推进玩法计数。
	var is_display_refresh: bool = refresh_source == REFRESH_DISPLAY
	# 五只股票行为影响；局外刷新使用空字典并视为零影响。
	var behavior_impacts: Dictionary = _calculate_behavior_impacts() if is_settlement else {}
	if is_settlement:
		_settlement_count += 1
		_market_cycle_settlement_progress += 1
		_price_limit_cycle_settlement_progress += 1
		_update_market_cycles_before_refresh()
	for stock_id in STOCK_IDS:
		_refresh_stock(stock_id, refresh_source, float(behavior_impacts.get(stock_id, 0.0)))
	if not is_display_refresh:
		_consume_event_duration(refresh_source)
	if is_settlement:
		_update_behavior_streaks(behavior_impacts)
		_settlements_until_event -= 1
		if _settlements_until_event <= 0:
			trigger_random_event()
		_run_metrics.clear()
	if not is_display_refresh:
		_save_state()
	market_changed.emit()
	market_refreshed.emit(refresh_source)


func trigger_random_event() -> Dictionary:
	if EVENT_DEFINITIONS.is_empty():
		return {}
	# 随机事件定义；深复制后附加剩余次数，避免修改静态事件目录。
	var definition: Dictionary = EVENT_DEFINITIONS[_random.randi_range(0, EVENT_DEFINITIONS.size() - 1)].duplicate(true)
	definition["remaining_settlements"] = int(definition.get("duration_settlement", 0))
	definition["remaining_refreshes"] = int(definition.get("duration_refresh", 0))
	_active_event = definition
	_roll_next_event_interval()
	_roll_next_online_event_interval()
	_event_online_accumulated_seconds = 0.0
	_save_state()
	event_announced.emit(str(definition.get("message", "市场出现新变化")))
	market_changed.emit()
	return definition.duplicate(true)


func set_market_state(market_state: String) -> void:
	if not market_state in [MARKET_BULL, MARKET_BEAR, MARKET_SIDEWAYS]:
		return
	_market_state = market_state
	_market_cycle_settlement_progress = 0
	_market_cycle_online_accumulated_seconds = 0.0
	_save_state()
	market_changed.emit()


func cycle_market_state() -> String:
	# 大盘循环顺序；开发者按钮按牛、熊、震荡依次切换。
	var states: Array[String] = [MARKET_BULL, MARKET_BEAR, MARKET_SIDEWAYS]
	# 当前大盘下标；异常状态会得到 -1 并自然切换到牛市。
	var current_index: int = states.find(_market_state)
	set_market_state(states[(current_index + 1) % states.size()])
	return _market_state


func record_run_metric(metric_name: String, amount: float = 1.0) -> void:
	if metric_name.is_empty() or amount == 0.0 or not _is_combat_run_active():
		return
	_run_metrics[metric_name] = float(_run_metrics.get(metric_name, 0.0)) + amount


func record_resource_obtained(item_resource: Resource, quantity: int = 1) -> void:
	if item_resource == null or quantity <= 0:
		return
	# 物品类型；用于区分强化石、修复包和其他资源。
	var item_kind: String = str(item_resource.get("item_kind"))
	if item_kind == "enhancement_stone":
		record_run_metric("enhancement_stones", quantity)
		# 强化石品质；高级和极品会额外计入高品质强化石指标。
		# 特化品质补充；特化强化石与高级、极品共用稀有物品的市场行为指标。
		var quality_id: String = str(item_resource.get("quality_id"))
		if quality_id in ["high", "supreme", "specialized"]:
			record_run_metric("high_enhancement_stones", quantity)
	elif not str(item_resource.get("weapon_id")).is_empty():
		record_run_metric("new_weapons", quantity)
	# 通用物品品质；高级和极品物品共同影响遗迹勘探开发。
	var item_quality_id: String = str(item_resource.get("quality_id"))
	if item_quality_id in ["high", "supreme", "specialized"]:
		record_run_metric("high_quality_items", quantity)


func _refresh_stock(stock_id: String, refresh_source: String, player_impact: float) -> void:
	# 股票静态定义；提供初始价、名称和基础波动率。
	var definition: Dictionary = STOCK_DEFINITIONS.get(stock_id, {}) as Dictionary
	# 股票运行时状态；刷新后会原位更新并重新写回状态表。
	var state: Dictionary = _stock_states.get(stock_id, {}) as Dictionary
	# 刷新前价格；至少 1 星穹，作为本次涨跌幅与单次限制的基准。
	var old_price: float = maxf(float(state.get("price", definition.get("base_price", 1.0))), 1.0)
	# 当前动态价值中枢；至少 1 星穹，长期回归只围绕该值而非初始价。
	var center: float = maxf(float(state.get("center", old_price)), 1.0)
	# 是否正式结算刷新；决定波动倍率、中枢概率和玩家行为是否启用。
	var is_settlement: bool = refresh_source == REFRESH_SETTLEMENT
	# 是否局外 60 秒刷新；随机事件的正式结算效果可以由该在线刷新作为替代次数推进。
	var is_runtime_refresh: bool = refresh_source == REFRESH_RUNTIME
	# 是否面板微行情刷新；启用时禁用中枢漂移并把全部短期变化缩放为稳定的每秒波动。
	var is_display_refresh: bool = refresh_source == REFRESH_DISPLAY
	# 小幅刷新尺度；局外运行时为 0.5，正式结算为 1.0。
	var scale: float = 1.0 if is_settlement else 0.5
	if is_display_refresh:
		scale = clampf(display_fluctuation_scale, 0.01, 0.50)
	# 本次定价使用的大盘状态；微行情只读取长期大盘，避免重复放大全局事件的临时状态。
	var pricing_market_state: String = _market_state if is_display_refresh else _get_effective_market_state()
	# 大盘方向分数；牛市为 1、熊市为 -1、震荡为 0。
	var market_direction: float = _get_market_direction(pricing_market_state)
	# 当前事件方向；目标不匹配或事件无有效次数时为 0。
	var event_direction: float = _get_event_direction_for_stock(stock_id, is_settlement)
	if is_display_refresh:
		event_direction = 0.0
	# 本次中枢漂移概率；正式基础 25%、局外基础 10%，连续行为和事件会覆盖。
	var drift_probability: float = 0.25 if is_settlement else 0.10
	if is_display_refresh:
		drift_probability = 0.0
	# 上一轮连续同向行为局数；达到 2 时增强下一局中枢传导。
	var same_direction_count: int = int(state.get("behavior_streak", 0))
	if is_settlement and same_direction_count >= 2 and not is_zero_approx(player_impact):
		drift_probability = 0.55
	if event_direction != 0.0 and (is_settlement or is_runtime_refresh):
		drift_probability = 0.80
	if _random.randf() < drift_probability:
		# 中枢最小漂移比例；正式为 0.6%，局外为 0.3%。
		var minimum_drift: float = 0.006 if is_settlement else 0.003
		# 中枢最大漂移比例；正式为 1.2%，局外为 0.6%，连续行为可扩大 1.3 倍。
		var maximum_drift: float = 0.012 if is_settlement else 0.006
		if is_settlement and same_direction_count >= 2 and not is_zero_approx(player_impact):
			maximum_drift *= 1.3
		# 漂移方向总分；事件优先，否则叠加大盘和玩家行为方向。
		var direction_score: float = event_direction if event_direction != 0.0 else market_direction + signf(player_impact) * 0.65
		# 最终漂移方向；总分为零时等概率选择正负方向。
		var drift_direction: float = signf(direction_score) if not is_zero_approx(direction_score) else (-1.0 if _random.randf() < 0.5 else 1.0)
		center *= 1.0 + _random.randf_range(minimum_drift, maximum_drift) * drift_direction
	# 初始基准价；仅用于 50% 至 300% 极端软保护，不参与日常回归。
	var base_price: float = float(definition.get("base_price", old_price))
	center = clampf(center, base_price * 0.5, base_price * 3.0)
	# 当前价格相对中枢偏离率；正值高于中枢，负值低于中枢。
	var deviation_ratio: float = (old_price - center) / center
	# 本次均值回归变化量；局外刷新按 0.5 尺度减半。
	var reversion: float = _calculate_mean_reversion(deviation_ratio) * scale
	# 本次情绪基础波动率；来自股票类型并受刷新源、大盘和事件倍率调整。
	var volatility: float = float(definition.get("volatility", 0.03)) * scale * maxf(market_volatility_multiplier, 0.0)
	if pricing_market_state == MARKET_SIDEWAYS:
		volatility *= 1.2
	if not is_display_refresh:
		volatility *= _get_event_volatility_multiplier()
	# 情绪方向偏置；大盘提供较弱倾斜，目标事件提供更强倾斜。
	var sentiment_bias: float = market_direction * volatility * 0.28 + event_direction * volatility * 0.55
	# 短期市场情绪；每次刷新必定抽取随机波动并叠加方向偏置。
	var sentiment: float = _random.randf_range(-volatility, volatility) + sentiment_bias
	# 中枢层刷新尺度；面板微行情按微波动尺度缩小，其他刷新保持原有中枢权重。
	var center_refresh_scale: float = scale if is_display_refresh else 1.0
	# 三层定价与回归合成变化；中枢、情绪、行为权重分别为 50%、35%、15%。
	var weighted_change: float = ((center / old_price) - 1.0) * 0.50 * center_refresh_scale + sentiment * 0.35 + clampf(player_impact, -0.02, 0.02) * 0.15 + reversion
	# 单次涨跌上限；正式为 15%，局外为 7.5%。
	var single_limit: float = settlement_change_limit if is_settlement else runtime_change_limit
	if is_display_refresh:
		single_limit = display_change_limit
	weighted_change = clampf(weighted_change, -single_limit, single_limit)
	# 限制后的新价格；后续继续应用软边界和正式周期累计边界。
	var new_price: float = old_price * (1.0 + weighted_change)
	new_price = clampf(new_price, base_price * 0.5, base_price * 3.0)
	# 当前涨跌周期起始价；每 5 次正式结算重置，周期内正式与局外刷新共同遵守 ±30% 边界。
	var cycle_start_price: float = maxf(float(state.get("cycle_start_price", old_price)), 1.0)
	new_price = clampf(new_price, cycle_start_price * (1.0 - cycle_change_limit), cycle_start_price * (1.0 + cycle_change_limit))
	if is_display_refresh and is_equal_approx(snappedf(new_price, 0.01), snappedf(old_price, 0.01)):
		# 微行情可见步长；当随机结果不足 0.01 星穹时强制移动一分钱，确保每秒刷新肉眼可见。
		var visible_step: float = 0.01 if sentiment >= 0.0 else -0.01
		# 微行情有效最低价；同时遵守初始价软下限和当前涨跌周期下限。
		var visible_minimum_price: float = maxf(base_price * 0.5, cycle_start_price * (1.0 - cycle_change_limit))
		# 微行情有效最高价；同时遵守初始价软上限和当前涨跌周期上限。
		var visible_maximum_price: float = minf(base_price * 3.0, cycle_start_price * (1.0 + cycle_change_limit))
		new_price = clampf(old_price + visible_step, visible_minimum_price, visible_maximum_price)
		if is_equal_approx(snappedf(new_price, 0.01), snappedf(old_price, 0.01)):
			new_price = clampf(old_price - visible_step, visible_minimum_price, visible_maximum_price)
	state["center"] = center
	state["price"] = maxf(new_price, 1.0)
	state["last_change_ratio"] = (new_price - old_price) / old_price
	if not is_display_refresh:
		state["last_player_impact"] = player_impact if is_settlement else 0.0
		# 玩家行为贡献占比；行为层加权变化占最终实际涨跌幅的绝对比例，最终持平时按 0 处理。
		var actual_change_ratio: float = float(state.get("last_change_ratio", 0.0))
		state["last_player_contribution_ratio"] = clampf(absf(player_impact * 0.15) / absf(actual_change_ratio), 0.0, 1.0) if is_settlement and not is_zero_approx(actual_change_ratio) else 0.0
		state["next_drift_probability"] = drift_probability
	# 最近价格历史；保留两位小数后追加并只保留最近 30 次刷新，使每秒微行情能在折线中清晰呈现。
	var history: Array = state.get("history", []) as Array
	history.append(maxf(snappedf(new_price, 0.01), 0.01))
	while history.size() > 30:
		history.remove_at(0)
	state["history"] = history
	_stock_states[stock_id] = state


func _calculate_mean_reversion(deviation_ratio: float) -> float:
	# 绝对偏离率；决定分段概率和修正力度。
	var absolute_deviation: float = absf(deviation_ratio)
	if absolute_deviation <= 0.10:
		return 0.0
	# 当前分段修正强度；表示修正偏离量的比例。
	var strength: float = 0.0
	# 当前分段触发概率；超过 50% 偏离时为 100%。
	var probability: float = 0.0
	if absolute_deviation <= 0.25:
		strength = 0.10
		probability = 0.60
	elif absolute_deviation <= 0.50:
		strength = 0.18
		probability = 0.85
	else:
		strength = 0.25
		probability = 1.0
	if _random.randf() > probability:
		return 0.0
	return -deviation_ratio * strength


func _calculate_behavior_impacts() -> Dictionary:
	return {
		"quantum_arms": clampf(floor(float(_run_metrics.get("shots", 0.0)) / 100.0) * 0.003 + floor(float(_run_metrics.get("weapon_durability", 0.0)) / 500.0) * 0.004 + float(_run_metrics.get("new_weapons", 0.0)) * 0.002 + floor(float(_run_metrics.get("extracted_weapon_value", 0.0)) / 800.0) * 0.003, -0.02, 0.02),
		"astral_defense": clampf(floor(float(_run_metrics.get("damage_taken", 0.0)) / 100.0) * 0.005 + floor(float(_run_metrics.get("armor_durability", 0.0)) / 300.0) * 0.004 + floor(float(_run_metrics.get("dodges", 0.0)) / 20.0) * 0.002 + float(_run_metrics.get("broken_armor", 0.0)) * 0.003, -0.02, 0.02),
		"hacker_tech": clampf(float(_run_metrics.get("enhancement_stones", 0.0)) * 0.002 + float(_run_metrics.get("shipped_enhancement_stones", 0.0)) * 0.003 + floor(float(_run_metrics.get("chests_opened", 0.0)) / 5.0) * 0.002 + float(_run_metrics.get("high_enhancement_stones", 0.0)) * 0.004, -0.02, 0.02),
		"frontline_supply": clampf(float(_run_metrics.get("repair_kits_used", 0.0)) * 0.004 + floor(float(_run_metrics.get("shipped_value", 0.0)) / 500.0) * 0.003 + floor(float(_run_metrics.get("lost_value", 0.0)) / 300.0) * 0.005 + floor(float(_run_metrics.get("survival_seconds", 0.0)) / 120.0) * 0.002, -0.02, 0.02),
		"relic_exploration": clampf(float(_run_metrics.get("chests_opened", 0.0)) * 0.002 + float(_run_metrics.get("high_quality_items", 0.0)) * 0.005 + floor(float(_run_metrics.get("extracted_value", 0.0)) / 1000.0) * 0.003 - floor(float(_run_metrics.get("lost_high_value", 0.0)) / 800.0) * 0.004, -0.02, 0.02),
	}


func _update_behavior_streaks(impacts: Dictionary) -> void:
	for stock_id in STOCK_IDS:
		# 当前股票状态；读取上局方向和连续次数后更新本局传导记录。
		var state: Dictionary = _stock_states.get(stock_id, {}) as Dictionary
		# 本局行为方向；正影响为 1、负影响为 -1、无影响为 0。
		var impact_direction: int = int(signf(float(impacts.get(stock_id, 0.0))))
		# 上局行为方向；用于判断是否继续同向累计。
		var previous_direction: int = int(state.get("behavior_direction", 0))
		if impact_direction == 0:
			state["behavior_streak"] = 0
			state["behavior_direction"] = 0
		elif impact_direction == previous_direction:
			state["behavior_streak"] = int(state.get("behavior_streak", 0)) + 1
		else:
			state["behavior_streak"] = 1
			state["behavior_direction"] = impact_direction
		_stock_states[stock_id] = state


func _update_market_cycles_before_refresh() -> void:
	if _market_cycle_settlement_progress >= maxi(market_cycle_settlement_count, 1):
		_switch_market_state()
		_market_cycle_settlement_progress = 0
		_market_cycle_online_accumulated_seconds = 0.0
	if _price_limit_cycle_settlement_progress >= maxi(price_limit_cycle_settlement_count, 1):
		_reset_price_limit_cycle()
		_price_limit_cycle_settlement_progress = 0
		_price_limit_cycle_online_accumulated_seconds = 0.0


func _update_online_time_triggers(delta: float) -> void:
	_market_cycle_online_accumulated_seconds += delta
	_price_limit_cycle_online_accumulated_seconds += delta
	_event_online_accumulated_seconds += delta
	# 本帧是否修改了周期状态；没有变化时不触发额外存档和 UI 刷新。
	var cycle_state_changed: bool = false
	if _market_cycle_online_accumulated_seconds >= maxf(market_cycle_online_seconds, 1.0):
		_switch_market_state()
		_market_cycle_online_accumulated_seconds = 0.0
		_market_cycle_settlement_progress = 0
		cycle_state_changed = true
	if _price_limit_cycle_online_accumulated_seconds >= maxf(price_limit_cycle_online_seconds, 1.0):
		_reset_price_limit_cycle()
		_price_limit_cycle_online_accumulated_seconds = 0.0
		_price_limit_cycle_settlement_progress = 0
		cycle_state_changed = true
	if _event_online_accumulated_seconds >= maxf(_event_online_target_seconds, 1.0):
		trigger_random_event()
		return
	if cycle_state_changed:
		_save_state()
		market_changed.emit()


func _switch_market_state() -> void:
	# 可切换大盘候选；移除当前状态，确保正式结算或在线时长触发后不会原地不变。
	var candidates: Array[String] = [MARKET_BULL, MARKET_BEAR, MARKET_SIDEWAYS]
	candidates.erase(_market_state)
	_market_state = candidates[_random.randi_range(0, candidates.size() - 1)]


func _reset_price_limit_cycle() -> void:
	for stock_id in STOCK_IDS:
		# 当前股票状态；把周期起始价更新为触发时的实时价格，解除上一周期累计涨跌限制。
		var state: Dictionary = _stock_states.get(stock_id, {}) as Dictionary
		state["cycle_start_price"] = float(state.get("price", 1.0))
		_stock_states[stock_id] = state


func _consume_event_duration(refresh_source: String) -> void:
	if _active_event.is_empty():
		return
	# 是否正式结算刷新；推进事件的正式结算持续次数。
	var is_settlement: bool = refresh_source == REFRESH_SETTLEMENT
	# 是否局外 60 秒刷新；作为不进行对局时的替代次数，同样推进正式结算类事件效果。
	var is_runtime_refresh: bool = refresh_source == REFRESH_RUNTIME
	if int(_active_event.get("remaining_refreshes", 0)) > 0:
		_active_event["remaining_refreshes"] = int(_active_event.get("remaining_refreshes", 0)) - 1
	if (is_settlement or is_runtime_refresh) and int(_active_event.get("remaining_settlements", 0)) > 0:
		_active_event["remaining_settlements"] = int(_active_event.get("remaining_settlements", 0)) - 1
	if int(_active_event.get("remaining_refreshes", 0)) <= 0 and int(_active_event.get("remaining_settlements", 0)) <= 0:
		_active_event.clear()


func _get_event_direction_for_stock(stock_id: String, is_settlement: bool) -> float:
	if _active_event.is_empty():
		return 0.0
	# 事件目标股票；空字符串表示作用于全部股票。
	var target_stock_id: String = str(_active_event.get("stock_id", ""))
	if not target_stock_id.is_empty() and target_stock_id != stock_id:
		return 0.0
	if is_settlement and int(_active_event.get("remaining_settlements", 0)) > 0:
		return float(_active_event.get("direction", 0))
	if int(_active_event.get("remaining_refreshes", 0)) > 0:
		return float(_active_event.get("direction", 0))
	return 0.0


func _get_event_volatility_multiplier() -> float:
	if int(_active_event.get("remaining_refreshes", 0)) <= 0:
		return 1.0
	return maxf(float(_active_event.get("volatility_multiplier", 1.0)), 0.0)


func _get_effective_market_state() -> String:
	if int(_active_event.get("remaining_settlements", 0)) > 0:
		# 临时大盘标识；只有三个合法状态才覆盖长期大盘。
		var temporary_market: String = str(_active_event.get("temporary_market", ""))
		if temporary_market in [MARKET_BULL, MARKET_BEAR, MARKET_SIDEWAYS]:
			return temporary_market
	return _market_state


func _get_market_direction(market_state: String) -> float:
	if market_state == MARKET_BULL:
		return 1.0
	if market_state == MARKET_BEAR:
		return -1.0
	return 0.0


func _get_market_state_name(market_state: String) -> String:
	if market_state == MARKET_BULL:
		return "牛市"
	if market_state == MARKET_BEAR:
		return "熊市"
	return "震荡市"


func _roll_next_event_interval() -> void:
	# 事件最短间隔；至少 2 局，防止事件每局扎堆触发。
	var minimum_value: int = maxi(event_interval_minimum_settlements, 2)
	# 事件最长间隔；不得小于最短间隔，异常配置会自动向上修正。
	var maximum_value: int = maxi(event_interval_maximum_settlements, minimum_value)
	_settlements_until_event = _random.randi_range(minimum_value, maximum_value)


func _roll_next_online_event_interval() -> void:
	# 在线事件最短间隔；至少 1 秒，默认 120 秒。
	var minimum_value: float = maxf(event_interval_minimum_online_seconds, 1.0)
	# 在线事件最长间隔；不得小于最短间隔，默认 360 秒。
	var maximum_value: float = maxf(event_interval_maximum_online_seconds, minimum_value)
	_event_online_target_seconds = _random.randf_range(minimum_value, maximum_value)


func _on_run_state_changed() -> void:
	# 当前正式对局活动状态；与上一状态比较以识别开始和完成边界。
	var is_active: bool = _is_combat_run_active()
	if is_active and not _previous_run_active:
		_run_metrics.clear()
	elif not is_active and _previous_run_active:
		_collect_outcome_metrics()
		refresh_market(REFRESH_SETTLEMENT)
	_previous_run_active = is_active
	# 正式战斗期间在线行情本就停止推进；关闭 process 可避免每帧重复查询同一战斗状态，结算信号仍会负责恢复局外计时。
	set_process(not is_active)


func _collect_outcome_metrics() -> void:
	if _global_inventory == null or not _global_inventory.has_method("get_last_run_outcome"):
		return
	# 当前战斗场景；操作系统关闭窗口等绕过 HUD 的结算路径仍可从 GameWorld 补取存活时长。
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("get_survival_time_seconds"):
		# 场景存活时长；与 HUD 上报值取较大者，避免同一次正常结算重复相加。
		var scene_survival_seconds: float = maxf(float(current_scene.call("get_survival_time_seconds")), 0.0)
		_run_metrics["survival_seconds"] = maxf(float(_run_metrics.get("survival_seconds", 0.0)), scene_survival_seconds)
	# 最近一次战斗结算；包含成功/失败类型以及获得、丢失条目。
	var outcome: Dictionary = _global_inventory.call("get_last_run_outcome") as Dictionary
	# 实际丢失条目；失败时用于累计供应链和遗迹勘探的负向价值指标。
	var lost_entries: Array = outcome.get("lost_entries", []) as Array
	# 本局首次获得条目；成功时用于估算撤离带出总价值和武器价值。
	var gained_entries: Array = outcome.get("gained_entries", []) as Array
	# 本局丢失总价值；每个条目按单位售价乘实际丢失数量累计。
	var lost_value: int = 0
	# 本局丢失高价值物品累计；单条总价值达到 800 星穹时计入。
	var lost_high_value: int = 0
	# 成功撤离带出总价值；按本局首次获得条目累计。
	var extracted_value: int = 0
	# 成功撤离带出武器价值；只累计具有 weapon_id 的条目。
	var extracted_weapon_value: int = 0
	for raw_entry in gained_entries:
		if not (raw_entry is Dictionary):
			continue
		# 获得条目字典；提供资源引用和实际数量。
		var gained_entry: Dictionary = raw_entry as Dictionary
		# 获得物品资源；用于读取售价和武器标识。
		var gained_resource: Resource = gained_entry.get("resource") as Resource
		# 获得数量；至少为 1，堆叠资源按结算记录数量计算。
		var gained_quantity: int = maxi(int(gained_entry.get("quantity", 1)), 1)
		# 获得物品单位价值；缺失资源时按 0 处理。
		var gained_unit_value: int = int(gained_resource.call("get_effective_value")) if gained_resource != null and gained_resource.has_method("get_effective_value") else (int(gained_resource.get("value")) if gained_resource != null else 0)
		extracted_value += gained_unit_value * gained_quantity
		if gained_resource != null and not str(gained_resource.get("weapon_id")).is_empty():
			extracted_weapon_value += gained_unit_value * gained_quantity
	for raw_entry in lost_entries:
		if not (raw_entry is Dictionary):
			continue
		# 丢失条目字典；提供资源引用和实际数量。
		var entry: Dictionary = raw_entry as Dictionary
		# 丢失物品资源；用于读取当前有效售价。
		var resource: Resource = entry.get("resource") as Resource
		# 丢失数量；至少为 1，强化石等堆叠按实际颗数计算。
		var quantity: int = maxi(int(entry.get("quantity", 1)), 1)
		# 丢失物品单位价值；缺失资源时按 0 处理。
		var unit_value: int = int(resource.call("get_effective_value")) if resource != null and resource.has_method("get_effective_value") else (int(resource.get("value")) if resource != null else 0)
		lost_value += unit_value * quantity
		if unit_value * quantity >= 800:
			lost_high_value += unit_value * quantity
	_run_metrics["lost_value"] = float(_run_metrics.get("lost_value", 0.0)) + lost_value
	_run_metrics["lost_high_value"] = float(_run_metrics.get("lost_high_value", 0.0)) + lost_high_value
	if str(outcome.get("result", "failure")) == "success":
		_run_metrics["extracted_value"] = maxf(float(_run_metrics.get("extracted_value", 0.0)), extracted_value)
		_run_metrics["extracted_weapon_value"] = maxf(float(_run_metrics.get("extracted_weapon_value", 0.0)), extracted_weapon_value)


func _is_combat_run_active() -> bool:
	return _global_inventory != null and _global_inventory.has_method("is_combat_run_active") and bool(_global_inventory.call("is_combat_run_active"))


func _initialize_default_states() -> void:
	_stock_states.clear()
	for stock_id in STOCK_IDS:
		# 股票静态定义；初始化时读取对应初始基准价。
		var definition: Dictionary = STOCK_DEFINITIONS.get(stock_id, {}) as Dictionary
		# 股票初始价；同时作为首次价格、中枢和涨跌周期起点。
		var base_price: float = float(definition.get("base_price", 1.0))
		_stock_states[stock_id] = {
			"price": base_price,
			"center": base_price,
			"history": [roundi(base_price)],
			"last_change_ratio": 0.0,
			"cycle_start_price": base_price,
			"behavior_streak": 0,
			"behavior_direction": 0,
			"last_player_impact": 0.0,
			"last_player_contribution_ratio": 0.0,
			"next_drift_probability": 0.25,
		}


func _normalize_securities_amount(amount: float) -> float:
	## 把证券币金额标准化为非负两位小数；统一消除浮点尾差并确保账户不会出现负数。
	return maxf(snappedf(amount, 0.01), 0.0)


func _calculate_securities_fee(gross: float, fee_ratio: float) -> float:
	## 计算证券币手续费；正成交额按比例向上保留到 0.01，最低收取 0.01 证券币。
	if gross <= 0.0:
		return 0.0
	# 原始手续费分值；乘 100 后向上取整，微小容差避免已是整分的浮点数被错误多收 0.01。
	var fee_in_cents: int = ceili(maxf(gross * clampf(fee_ratio, 0.0, 1.0) * 100.0 - 0.000001, 0.0))
	return maxf(float(fee_in_cents) / 100.0, 0.01)


func _save_state() -> void:
	# 股市存档根字典；保存全部长期行情状态，不包含玩家持仓和星穹。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"market_state": _market_state,
		"settlement_count": _settlement_count,
		"market_cycle_settlement_progress": _market_cycle_settlement_progress,
		"market_cycle_online_accumulated_seconds": _market_cycle_online_accumulated_seconds,
		"price_limit_cycle_settlement_progress": _price_limit_cycle_settlement_progress,
		"price_limit_cycle_online_accumulated_seconds": _price_limit_cycle_online_accumulated_seconds,
		"settlements_until_event": _settlements_until_event,
		"event_online_accumulated_seconds": _event_online_accumulated_seconds,
		"event_online_target_seconds": _event_online_target_seconds,
		"active_event": _active_event,
		"runtime_accumulated_seconds": _runtime_accumulated_seconds,
		"securities_balance": _normalize_securities_amount(_securities_balance),
		"stock_states": _stock_states,
	}
	# 股市存档文件；打开失败时保留内存状态并等待下一次刷新重试。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data))


func _load_state() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	# 股市只读存档文件；打开失败时回退完整默认状态。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return false
	# JSON 解析结果；非字典视为损坏存档并回退默认初始化。
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	if not (parsed is Dictionary):
		return false
	# 股市存档字典；包含大盘、周期、事件、运行累计和单股状态。
	var save_data: Dictionary = parsed as Dictionary
	# 股市存档版本迁移停用；项目尚未发布正式版本，当前读档不再按历史版本缩放累计进度。
	# var saved_version: int = maxi(int(save_data.get("version", 1)), 1)
	# 证券币余额；版本 3 及更旧存档没有该字段，升级时从 0.00 开始且不自动搬运永久星穹。
	_securities_balance = _normalize_securities_amount(float(save_data.get("securities_balance", 0.0)))
	_market_state = str(save_data.get("market_state", MARKET_SIDEWAYS))
	if not _market_state in [MARKET_BULL, MARKET_BEAR, MARKET_SIDEWAYS]:
		_market_state = MARKET_SIDEWAYS
	_settlement_count = maxi(int(save_data.get("settlement_count", 0)), 0)
	_market_cycle_settlement_progress = clampi(int(save_data.get("market_cycle_settlement_progress", _settlement_count % maxi(market_cycle_settlement_count, 1))), 0, maxi(market_cycle_settlement_count - 1, 0))
	_market_cycle_online_accumulated_seconds = clampf(float(save_data.get("market_cycle_online_accumulated_seconds", 0.0)), 0.0, maxf(market_cycle_online_seconds, 1.0))
	_price_limit_cycle_settlement_progress = clampi(int(save_data.get("price_limit_cycle_settlement_progress", _settlement_count % maxi(price_limit_cycle_settlement_count, 1))), 0, maxi(price_limit_cycle_settlement_count - 1, 0))
	_price_limit_cycle_online_accumulated_seconds = clampf(float(save_data.get("price_limit_cycle_online_accumulated_seconds", 0.0)), 0.0, maxf(price_limit_cycle_online_seconds, 1.0))
	_settlements_until_event = maxi(int(save_data.get("settlements_until_event", 0)), 0)
	_event_online_accumulated_seconds = maxf(float(save_data.get("event_online_accumulated_seconds", 0.0)), 0.0)
	_event_online_target_seconds = maxf(float(save_data.get("event_online_target_seconds", 0.0)), 0.0)
	# 历史在线进度迁移停用；旧版本累计时长和事件目标不再自动乘以 3。
	# if saved_version < 3:
	# 	...
	_runtime_accumulated_seconds = clampf(float(save_data.get("runtime_accumulated_seconds", 0.0)), 0.0, maxf(runtime_refresh_interval_seconds, 1.0))
	# 原始事件字段；合法字典会恢复剩余次数，其他类型视为无事件。
	var raw_event: Variant = save_data.get("active_event", {})
	_active_event = (raw_event as Dictionary).duplicate(true) if raw_event is Dictionary else {}
	# 原始股票状态表；只恢复五个已知稳定股票标识。
	var raw_states: Variant = save_data.get("stock_states", {})
	if raw_states is Dictionary:
		for stock_id in STOCK_IDS:
			# 单股原始状态；必须为字典才与默认字段合并。
			var raw_state: Variant = (raw_states as Dictionary).get(stock_id)
			if raw_state is Dictionary:
				# 单股默认状态；先保留新版本新增字段，再用存档值覆盖已有行情。
				var default_state: Dictionary = _stock_states.get(stock_id, {}) as Dictionary
				default_state.merge((raw_state as Dictionary).duplicate(true), true)
				_stock_states[stock_id] = default_state
	return true
