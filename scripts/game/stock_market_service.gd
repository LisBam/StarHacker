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
## 杠杆仓位变化信号；开仓、平仓和强制平仓成功后通知股市界面刷新杠杆持仓展示。
signal leverage_positions_changed
## 杠杆仓位关闭信号；主动平仓与强制平仓统一携带股票标识和结算说明，供界面显示提示横幅。
signal leverage_position_closed(stock_id: String, message: String)
## 杠杆强制平仓信号；仅强平路径发出，携带股票标识和结算说明，供横幅通知服务与通知中心低耦合联动。
signal leverage_position_liquidated(stock_id: String, message: String)
## 交易记录变化信号；任何买卖、杠杆、充值或提现产生新记录后通知历史记录界面刷新。
signal trade_records_changed
## 通知记录变化信号；强平等重要通知写入后通知面板通知中心刷新。
signal notification_records_changed
## 止盈止损档案变化信号；设置、清除、触发消耗与持仓关闭清理后通知股市界面刷新入口状态。
signal stop_orders_changed
## 止盈止损触发信号；自动卖出或自动平仓完成后携带股票标识与结算说明，供面板提示与横幅通知服务低耦合联动。
signal stop_order_triggered(stock_id: String, message: String)

## 股市全局状态存档路径；与商店状态同级独立保存，避免行情字段污染库存物品序列化结构。
const SAVE_PATH: String = "user://stock_market_state.json"
## 股市状态存档版本；版本 1 保存五只股票的行情、周期、事件、行为连续性和局外运行累计值。
## 版本 2 补充；新增大盘、涨跌周期和随机事件的非战斗在线时长双触发进度。
## 版本 3 补充；在线触发阈值统一扩大 3 倍，并按原进度比例迁移版本 2 的累计时长与事件目标。
## 版本 4 补充；新增支持两位小数的证券币余额，旧存档默认从 0.00 证券币开始。
## 版本 5 补充；新增杠杆合约仓位表，旧存档默认没有任何杠杆仓位。
## 版本 6 补充；新增交易历史记录与通知记录列表，旧存档默认从空记录开始。
## 版本 7 补充；新增“星海互助保险”稳定股票，旧存档缺失该股票时自动按初始价初始化行情。
## 版本 8 补充；新增现货与杠杆的止盈止损档案表，旧存档默认没有任何止盈止损设置。
const SAVE_VERSION: int = 8
## 交易历史记录保留上限；默认 80 条，索引 0 为最新，超出后丢弃最旧记录，防止存档无限膨胀。
const TRADE_RECORD_LIMIT: int = 80
## 通知记录保留上限；默认 50 条，索引 0 为最新，超出后丢弃最旧记录。
const NOTIFICATION_RECORD_LIMIT: int = 50
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
## 保险股补充；第六只股票“星海互助保险”与骇入保险系统联动，行为影响由保险服务累计后在正式结算取走。
const STOCK_IDS: Array[String] = ["quantum_arms", "astral_defense", "hacker_tech", "frontline_supply", "relic_exploration", "astral_insurance"]
## 止盈止损目标类型：现货持仓；触发时按当时全部持股数量以实时价格自动卖出。
const STOP_ORDER_KIND_SPOT: String = "spot"
## 止盈止损目标类型：杠杆仓位；触发时按当时实时价格执行全仓平仓，费用与主动平仓完全一致。
const STOP_ORDER_KIND_LEVERAGE: String = "leverage"
## 杠杆做多方向标识；价格上涨时杠杆仓位盈利，下跌时亏损。
const LEVERAGE_LONG: int = 1
## 杠杆做空方向标识；价格下跌时杠杆仓位盈利，上涨时亏损。
const LEVERAGE_SHORT: int = -1
## 可选杠杆倍数目录；开仓时只能选择该目录内的整数倍率，名义本金等于保证金乘倍数。
## 高倍扩展补充；新增 10、20、50、100 与 999 极限倍率，倍数越高开仓手续费越高且强平价越贴近开仓价。
const LEVERAGE_MULTIPLIERS: Array[int] = [2, 3, 5, 10, 20, 50, 100, 999]
## 单股价格历史保留上限；正式、局外和微行情共用，90 个采样让面板折线覆盖约 1.5 分钟微行情。
const PRICE_HISTORY_LIMIT: int = 90
## 股票静态目录；初始价仅用于首次初始化和极端软上下限，不作为长期强制回归锚点。
const STOCK_DEFINITIONS: Dictionary = {
	"quantum_arms": {"name": "量子军备集团", "module": "全品类远程、近战武器", "base_price": 120.0, "volatility": 0.030},
	"astral_defense": {"name": "星穹防务工业", "module": "四部位防具装备", "base_price": 90.0, "volatility": 0.020},
	"hacker_tech": {"name": "骇客数字科技", "module": "强化石、锻造增幅系统", "base_price": 150.0, "volatility": 0.030},
	"frontline_supply": {"name": "前线保障供应链", "module": "修复包、物资撤离补给", "base_price": 60.0, "volatility": 0.020},
	"relic_exploration": {"name": "遗迹勘探开发", "module": "宝箱、稀有掉落与高价值物资", "base_price": 200.0, "volatility": 0.045},
	"astral_insurance": {"name": "星海互助保险", "module": "骇入保险、死亡风险对冲", "base_price": 80.0, "volatility": 0.025},
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
	{"id": "insurance_good", "message": "全域安全骇入周报发布", "stock_id": "astral_insurance", "direction": 1, "duration_settlement": 2, "duration_refresh": 2},
	{"id": "insurance_bad", "message": "高额连环理赔冲击拨备金", "stock_id": "astral_insurance", "direction": -1, "duration_settlement": 2, "duration_refresh": 2},
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
## 杠杆合约手续费比例；开仓与平仓均按名义本金的 0.5% 收取，向上保留到 0.01 且最低 0.01 证券币，运行时无需动态修改。
@export_range(0.0, 0.20, 0.001) var leverage_fee_ratio: float = 0.005
## 杠杆强制平仓亏损线；默认浮亏达到保证金的 90% 时强制平仓，返还剩余净值并扣除平仓手续费，运行时无需动态修改。
@export_range(0.50, 1.0, 0.01) var leverage_liquidation_loss_ratio: float = 0.90
## 杠杆最低开仓保证金；默认 10 证券币整数，防止刷出大量粉尘仓位，运行时无需动态修改。
@export_range(1, 1000, 1) var leverage_minimum_margin: int = 10

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
## 杠杆仓位表；键为股票标识，值包含方向、倍数、保证金和开仓价，每只股票最多同时持有一个杠杆仓位。
var _leverage_positions: Dictionary = {}
## 止盈止损档案表；键为股票标识，值为按目标类型（spot / leverage）分组的目标价字典，触发消耗或持仓清零后自动移除。
var _stop_orders: Dictionary = {}
## 交易历史记录列表；每项包含时间、类型标识与说明文本，索引 0 为最新记录，随股市状态持久化。
var _trade_records: Array = []
## 通知记录列表；保存强平等重要事件的时间与说明文本，索引 0 为最新记录，随股市状态持久化。
var _notification_records: Array = []
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


func get_stock_price(stock_id: String) -> float:
	## 轻量只读价格接口；复用当前价读取逻辑，直接访问内部行情状态且不做任何深复制，供股市面板每秒刷新股票卡与价格文本。
	return get_current_price(stock_id)


func get_stock_change_ratio(stock_id: String) -> float:
	## 轻量只读涨跌接口；返回最近一次刷新相对刷新前价格的实际变化比例，不复制任何行情字典。
	# 单股运行时状态；只读取涨跌字段，不把内部字典引用返回给调用方。
	var state: Dictionary = _stock_states.get(stock_id, {}) as Dictionary
	return float(state.get("last_change_ratio", 0.0))


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


func get_total_securities_assets() -> float:
	## 返回证券账户总资产；等于证券币余额、现货持仓实时市值与全部杠杆仓位实时净值之和，保留两位小数。
	# 总资产累计值；从标准化余额开始，逐项叠加两类持仓的实时估值。
	var total_assets: float = get_securities_balance()
	for stock_id in STOCK_IDS:
		# 当前股票实时价格；现货市值与杠杆净值共用同一份两位小数报价。
		var price: float = get_current_price(stock_id)
		if _global_inventory != null and _global_inventory.has_method("get_stock_holding"):
			# 当前股票现货持仓；数量为 0 时不产生市值。
			var holding: Dictionary = _global_inventory.call("get_stock_holding", stock_id) as Dictionary
			total_assets += price * float(maxi(int(holding.get("quantity", 0)), 0))
		if _leverage_positions.has(stock_id):
			# 当前股票杠杆仓位净值；保证金加浮动盈亏，最低按 0 计入。
			total_assets += _calculate_leverage_equity(_leverage_positions.get(stock_id) as Dictionary, price)
	return _normalize_securities_amount(total_assets)


func get_leverage_multipliers() -> Array[int]:
	## 返回可选杠杆倍数目录副本；UI 用于生成倍数选择按钮，不允许外部修改常量目录。
	return LEVERAGE_MULTIPLIERS.duplicate()


func get_leverage_fee_ratio() -> float:
	## 返回杠杆合约手续费比例；开仓弹窗只用于实时预览，最终费用仍由服务重新计算。
	return clampf(leverage_fee_ratio, 0.0, 1.0)


func get_leverage_liquidation_loss_ratio() -> float:
	## 返回杠杆强制平仓亏损线；UI 用于预览强平价，实际强平判定仍由服务在每次行情刷新执行。
	return clampf(leverage_liquidation_loss_ratio, 0.0, 1.0)


func get_leverage_minimum_margin() -> int:
	## 返回杠杆最低开仓保证金；开仓弹窗以该值作为滑条下限，服务在开仓请求中再次复核。
	return maxi(leverage_minimum_margin, 1)


func get_maximum_leverage_margin(leverage: int) -> int:
	## 返回指定倍数下当前余额可支付的最大整数保证金；保证金加名义本金手续费不得超过证券币余额。
	# 合法杠杆倍数；目录外的倍数直接返回 0，防止 UI 传入异常倍率。
	if not leverage in LEVERAGE_MULTIPLIERS:
		return 0
	# 当前证券币余额；开仓花费为保证金加开仓手续费。
	var balance: float = get_securities_balance()
	# 估算保证金上限；先按含费比例推算，再向下逐一校验实际含费花费，循环次数受手续费进位限制。
	var estimated_margin: int = maxi(floori(balance / (1.0 + float(leverage) * clampf(leverage_fee_ratio, 0.0, 1.0))), 0)
	while estimated_margin > 0:
		# 估算开仓手续费；与最终开仓请求使用同一公式，防止弹窗出现无法成交的上限。
		var estimated_fee: float = _calculate_securities_fee(float(estimated_margin * leverage), leverage_fee_ratio)
		if _normalize_securities_amount(float(estimated_margin) + estimated_fee) <= balance + 0.0001:
			break
		estimated_margin -= 1
	return estimated_margin


func has_leverage_position(stock_id: String) -> bool:
	## 返回指定股票当前是否已持有杠杆仓位；每只股票最多同时存在一个杠杆仓位。
	return _leverage_positions.has(stock_id)


func get_leverage_position(stock_id: String) -> Dictionary:
	## 返回指定股票杠杆仓位的展示快照；包含存档字段和按实时价格计算的盈亏、净值与强平价，无仓位时返回空字典。
	if not _leverage_positions.has(stock_id):
		return {}
	# 仓位存档字段；深复制后附加实时计算字段，外部不能修改服务内存。
	var position: Dictionary = (_leverage_positions.get(stock_id) as Dictionary).duplicate(true)
	# 当前实时价格；盈亏、净值和强平判定共用同一份两位小数报价。
	var price: float = get_current_price(stock_id)
	position["stock_id"] = stock_id
	position["current_price"] = price
	position["notional"] = _normalize_securities_amount(float(position.get("margin", 0.0)) * float(position.get("leverage", 1)))
	position["profit"] = _calculate_leverage_profit(position, price)
	position["equity"] = _calculate_leverage_equity(position, price)
	position["liquidation_price"] = _calculate_leverage_liquidation_price(position)
	position["direction_name"] = "做多" if int(position.get("direction", LEVERAGE_LONG)) >= 0 else "做空"
	return position


func get_leverage_positions_snapshot() -> Dictionary:
	## 返回全部杠杆仓位的展示快照表；键为股票标识，值为含实时计算字段的仓位副本，供底部持仓区统一刷新。
	var snapshot: Dictionary = {}
	for stock_id in _leverage_positions.keys():
		snapshot[stock_id] = get_leverage_position(str(stock_id))
	return snapshot


func get_leverage_open_quote(stock_id: String, direction: int, leverage: int, margin: int) -> Dictionary:
	## 生成杠杆开仓实时报价；只读取行情与余额，返回名义本金、手续费、总花费、预计强平价和可执行状态。
	if not stock_id in STOCK_IDS or not leverage in LEVERAGE_MULTIPLIERS or margin < get_leverage_minimum_margin() or not direction in [LEVERAGE_LONG, LEVERAGE_SHORT]:
		return {"valid": false, "executable": false, "message": "杠杆开仓参数无效"}
	# 当前实时价格；开仓价以点击确认瞬间的实时行情为准。
	var price: float = get_current_price(stock_id)
	# 名义本金；保证金乘杠杆倍数，是盈亏和手续费的共同基数。
	var notional: float = _normalize_securities_amount(float(margin) * float(leverage))
	# 开仓手续费；按名义本金 0.5% 向上保留到 0.01 且最低 0.01 证券币。
	var fee: float = _calculate_securities_fee(notional, leverage_fee_ratio)
	# 开仓总花费；保证金与手续费之和，从证券币余额一次扣除。
	var total_cost: float = _normalize_securities_amount(float(margin) + fee)
	# 当前证券币余额；余额不足或该股票已有仓位时报价不可执行。
	var balance: float = get_securities_balance()
	# 报价可执行状态；每只股票最多一个杠杆仓位，重复开仓必须先平掉现有仓位。
	var executable: bool = not _leverage_positions.has(stock_id) and balance + 0.0001 >= total_cost
	# 不可执行原因；明确提示重复仓位或余额缺口。
	var message: String = "可以开仓"
	if _leverage_positions.has(stock_id):
		message = "该股票已有杠杆仓位，请先平仓"
	elif not executable:
		message = "证券币不足，需要 %.2f，当前仅有 %.2f" % [total_cost, balance]
	return {
		"valid": true,
		"executable": executable,
		"message": message,
		"price": price,
		"notional": notional,
		"fee": fee,
		"total": total_cost,
		"liquidation_price": _calculate_leverage_liquidation_price({"direction": direction, "leverage": leverage, "entry_price": price}),
	}


func get_leverage_close_quote(stock_id: String) -> Dictionary:
	## 生成杠杆平仓实时报价；返回实时盈亏、净值、平仓手续费和最终返还金额，无仓位时不可执行。
	if not _leverage_positions.has(stock_id):
		return {"valid": false, "executable": false, "message": "当前没有杠杆仓位"}
	# 仓位展示快照；已包含按实时价格计算的盈亏与净值。
	var position: Dictionary = get_leverage_position(stock_id)
	# 平仓手续费；与开仓同样按名义本金收取，从返还净值中扣除。
	var fee: float = _calculate_securities_fee(float(position.get("notional", 0.0)), leverage_fee_ratio)
	# 平仓返还金额；净值扣除手续费后最低为 0，不产生负债。
	var payout: float = _normalize_securities_amount(maxf(float(position.get("equity", 0.0)) - fee, 0.0))
	return {
		"valid": true,
		"executable": true,
		"message": "可以平仓",
		"price": float(position.get("current_price", 0.0)),
		"profit": float(position.get("profit", 0.0)),
		"equity": float(position.get("equity", 0.0)),
		"fee": fee,
		"total": payout,
	}


func request_leverage_open(stock_id: String, direction: int, leverage: int, margin: int) -> Dictionary:
	## 执行杠杆开仓；按点击确认瞬间的实时价格建仓，先复核余额与仓位唯一性，成功后立即持久化。
	# 开仓实时报价；复用报价接口保证校验规则与预览完全一致。
	var quote: Dictionary = get_leverage_open_quote(stock_id, direction, leverage, margin)
	if not bool(quote.get("valid", false)):
		return {"success": false, "message": str(quote.get("message", "无法执行杠杆开仓"))}
	if not bool(quote.get("executable", false)):
		return {"success": false, "message": str(quote.get("message", "当前无法开仓"))}
	_securities_balance = _normalize_securities_amount(_securities_balance - float(quote.get("total", 0.0)))
	_leverage_positions[stock_id] = {
		"direction": direction,
		"leverage": leverage,
		"margin": float(margin),
		"entry_price": float(quote.get("price", 0.0)),
		"opened_settlement_count": _settlement_count,
	}
	# 开仓方向名称；提示消息按方向区分做多与做空。
	var direction_name: String = "做多" if direction >= 0 else "做空"
	# 开仓股票定义；交易记录使用玩家可读的股票名称。
	var record_definition: Dictionary = STOCK_DEFINITIONS.get(stock_id, {}) as Dictionary
	# 开仓交易记录；与下方保存同一路径落盘，保证历史与仓位状态一致。
	_append_trade_record("leverage_open", "杠杆开仓 %s：%d×%s，保证金 %d，开仓价 %.2f，含费花费 %.2f 证券币" % [str(record_definition.get("name", "股票")), leverage, direction_name, margin, float(quote.get("price", 0.0)), float(quote.get("total", 0.0))])
	_save_state()
	securities_balance_changed.emit(_securities_balance)
	leverage_positions_changed.emit()
	return {"success": true, "message": "杠杆开仓成功：%d×%s，保证金 %d 证券币" % [leverage, direction_name, margin], "price": float(quote.get("price", 0.0)), "fee": float(quote.get("fee", 0.0)), "total": float(quote.get("total", 0.0))}


func request_leverage_close(stock_id: String) -> Dictionary:
	## 执行主动杠杆平仓；按点击确认瞬间的实时价格结算净值，扣除平仓手续费后返还证券币并立即持久化。
	if not _leverage_positions.has(stock_id):
		return {"success": false, "message": "当前没有可平仓的杠杆仓位"}
	# 平仓结算结果；主动平仓与强制平仓共用同一结算路径，保证费用与净值公式一致。
	var settlement: Dictionary = _close_leverage_position(stock_id, "平仓")
	return {"success": true, "message": str(settlement.get("message", "平仓完成")), "profit": float(settlement.get("profit", 0.0)), "total": float(settlement.get("payout", 0.0))}


func get_leverage_add_quote(stock_id: String, margin: int) -> Dictionary:
	## 生成杠杆加仓实时报价；沿用现有仓位方向与倍数，返回追加名义本金、手续费、总花费与合并后新均价、新强平价预览。
	if not _leverage_positions.has(stock_id):
		return {"valid": false, "executable": false, "message": "当前没有可加仓的杠杆仓位"}
	if margin < get_leverage_minimum_margin():
		return {"valid": false, "executable": false, "message": "追加保证金不得低于 %d 证券币" % get_leverage_minimum_margin()}
	# 现有仓位；加仓不改变方向与倍数，只追加保证金并按盈亏守恒合并开仓均价。
	var position: Dictionary = _leverage_positions.get(stock_id) as Dictionary
	# 当前实时价格；追加部分按该价格入场，初始浮动盈亏为 0。
	var price: float = get_current_price(stock_id)
	# 追加名义本金；追加保证金乘现有杠杆倍数。
	var added_notional: float = _normalize_securities_amount(float(margin) * float(position.get("leverage", 1)))
	# 加仓手续费；按追加名义本金收取，与开仓手续费同一公式。
	var fee: float = _calculate_securities_fee(added_notional, leverage_fee_ratio)
	# 加仓总花费；追加保证金与手续费之和，从证券币余额一次扣除。
	var total_cost: float = _normalize_securities_amount(float(margin) + fee)
	# 当前证券币余额；余额不足时报价不可执行。
	var balance: float = get_securities_balance()
	# 报价可执行状态；只校验余额，仓位存在性已在入口确认。
	var executable: bool = balance + 0.0001 >= total_cost
	# 合并后仓位预览；浮动盈亏守恒推导新开仓均价，用于返回新均价与新强平价。
	var merged_position: Dictionary = _build_merged_leverage_position(position, margin, price)
	# 不可执行原因；明确提示余额缺口。
	var message: String = "可以加仓"
	if not executable:
		message = "证券币不足，需要 %.2f，当前仅有 %.2f" % [total_cost, balance]
	return {
		"valid": true,
		"executable": executable,
		"message": message,
		"price": price,
		"notional": added_notional,
		"fee": fee,
		"total": total_cost,
		"new_margin": float(merged_position.get("margin", 0.0)),
		"new_entry_price": float(merged_position.get("entry_price", 0.0)),
		"liquidation_price": _calculate_leverage_liquidation_price(merged_position),
	}


func request_leverage_add(stock_id: String, margin: int) -> Dictionary:
	## 执行杠杆加仓；按确认瞬间实时价格复核余额，合并保证金与开仓均价后立即持久化，方向与倍数保持不变。
	# 加仓实时报价；复用报价接口保证校验规则与预览完全一致。
	var quote: Dictionary = get_leverage_add_quote(stock_id, margin)
	if not bool(quote.get("valid", false)):
		return {"success": false, "message": str(quote.get("message", "无法执行杠杆加仓"))}
	if not bool(quote.get("executable", false)):
		return {"success": false, "message": str(quote.get("message", "当前无法加仓"))}
	# 现有仓位；合并计算读取确认瞬间的最新仓位字段。
	var position: Dictionary = _leverage_positions.get(stock_id) as Dictionary
	# 结算实时价格；与报价接口同源，保证合并均价使用同一份两位小数报价。
	var price: float = float(quote.get("price", 0.0))
	_securities_balance = _normalize_securities_amount(_securities_balance - float(quote.get("total", 0.0)))
	_leverage_positions[stock_id] = _build_merged_leverage_position(position, margin, price)
	# 合并后新开仓均价；记录与提示消息共用同一结果。
	var merged_entry_price: float = float((_leverage_positions.get(stock_id) as Dictionary).get("entry_price", 0.0))
	# 加仓股票定义；交易记录使用玩家可读的股票名称。
	var record_definition: Dictionary = STOCK_DEFINITIONS.get(stock_id, {}) as Dictionary
	# 加仓交易记录；与下方保存同一路径落盘，保证历史与仓位状态一致。
	_append_trade_record("leverage_add", "杠杆加仓 %s：追加保证金 %d，新开仓均价 %.2f，含费花费 %.2f 证券币" % [str(record_definition.get("name", "股票")), margin, merged_entry_price, float(quote.get("total", 0.0))])
	_save_state()
	securities_balance_changed.emit(_securities_balance)
	leverage_positions_changed.emit()
	return {"success": true, "message": "杠杆加仓成功：追加保证金 %d 证券币，新开仓均价 %.2f" % [margin, merged_entry_price], "price": price, "fee": float(quote.get("fee", 0.0)), "total": float(quote.get("total", 0.0))}


func _build_merged_leverage_position(position: Dictionary, added_margin: int, price: float) -> Dictionary:
	## 按浮动盈亏守恒合并加仓后的仓位；追加保证金以当前价入场，合并后新开仓均价满足合并前后浮动盈亏完全一致。
	# 合并前浮动盈亏；加仓不结算盈亏，合并后必须原样保留。
	var previous_profit: float = _calculate_leverage_profit(position, price)
	# 合并后保证金；原保证金加追加保证金。
	var merged_margin: float = float(position.get("margin", 0.0)) + float(added_margin)
	# 合并后名义本金；保证金增加后按同一杠杆倍数放大。
	var merged_notional: float = merged_margin * float(position.get("leverage", 1))
	# 仓位方向；正数做多、负数做空，异常值按做多处理。
	var direction: float = -1.0 if int(position.get("direction", LEVERAGE_LONG)) < 0 else 1.0
	# 新开仓均价；由 方向 × (现价 ÷ 新均价 - 1) × 新名义本金 = 原浮动盈亏 反解，存续仓位浮亏上限保证分母恒为正。
	var merged_entry_price: float = maxf(snappedf(price / (1.0 + previous_profit / (direction * merged_notional)), 0.01), 0.01)
	# 合并后仓位字典；除保证金与开仓均价外全部字段保持原值。
	var merged_position: Dictionary = position.duplicate(true)
	merged_position["margin"] = merged_margin
	merged_position["entry_price"] = merged_entry_price
	return merged_position


func clear_leverage_positions() -> int:
	## 开发者调试接口；直接移除全部杠杆仓位且不返还任何证券币，返回被移除的仓位数量。
	# 被移除仓位数量；用于开发者菜单状态提示。
	var cleared_count: int = _leverage_positions.size()
	if cleared_count <= 0:
		return 0
	_leverage_positions.clear()
	# 杠杆止盈止损档案清理；仓位被整体清空后对应档案全部失效，是否有档案被移除决定是否补发档案变化信号。
	var stop_orders_removed: bool = false
	for stock_id in _stop_orders.keys().duplicate():
		stop_orders_removed = _discard_stop_order(str(stock_id), STOP_ORDER_KIND_LEVERAGE) or stop_orders_removed
	_save_state()
	leverage_positions_changed.emit()
	if stop_orders_removed:
		stop_orders_changed.emit()
	return cleared_count


func get_stop_order(stock_id: String, kind: String) -> Dictionary:
	## 返回指定股票指定目标类型的止盈止损档案副本；未设置时返回空字典，价格字段为 0 表示该方向未启用。
	# 股票档案分组；同一股票的现货与杠杆档案互相独立存放。
	var orders: Dictionary = _stop_orders.get(stock_id, {}) as Dictionary
	# 目标类型档案；仅字典结构视为有效档案。
	var order: Variant = orders.get(kind)
	return (order as Dictionary).duplicate(true) if order is Dictionary else {}


func set_stop_order(stock_id: String, kind: String, take_profit_price: float, stop_loss_price: float) -> Dictionary:
	## 设置指定股票的止盈止损目标价；价格为 0 表示该方向不启用，两个方向至少启用一项，成功后立即持久化。
	## 方向约定；止盈价必须位于当前价的盈利方向、止损价必须位于亏损方向，现货与做多以涨为盈利、做空以跌为盈利。
	if not stock_id in STOCK_IDS or not kind in [STOP_ORDER_KIND_SPOT, STOP_ORDER_KIND_LEVERAGE]:
		return {"success": false, "message": "止盈止损参数无效"}
	# 标准化目标价；统一保留两位小数，负数一律视为非法输入。
	var take_profit: float = snappedf(take_profit_price, 0.01)
	var stop_loss: float = snappedf(stop_loss_price, 0.01)
	if take_profit < 0.0 or stop_loss < 0.0:
		return {"success": false, "message": "目标价格不能为负数"}
	if take_profit <= 0.0 and stop_loss <= 0.0:
		return {"success": false, "message": "止盈价与止损价至少设置一项"}
	if kind == STOP_ORDER_KIND_SPOT:
		# 当前现货持股数量；没有持仓时不允许设置现货档案，避免留下永不清理的空目标。
		var holding_quantity: int = 0
		if _global_inventory != null and _global_inventory.has_method("get_stock_holding"):
			holding_quantity = int((_global_inventory.call("get_stock_holding", stock_id) as Dictionary).get("quantity", 0))
		if holding_quantity <= 0:
			return {"success": false, "message": "当前没有现货持仓，无法设置"}
	elif not _leverage_positions.has(stock_id):
		return {"success": false, "message": "当前没有杠杆仓位，无法设置"}
	# 盈利方向系数；现货与做多仓位为 +1（涨盈利），做空仓位为 -1（跌盈利）。
	var profit_direction: float = 1.0
	if kind == STOP_ORDER_KIND_LEVERAGE and int((_leverage_positions.get(stock_id) as Dictionary).get("direction", LEVERAGE_LONG)) < 0:
		profit_direction = -1.0
	# 当前实时价格；方向合法性以设置瞬间的实时行情为基准，触发判定使用后续每次刷新的实时价。
	var price: float = get_current_price(stock_id)
	if take_profit > 0.0 and (take_profit - price) * profit_direction <= 0.0:
		return {"success": false, "message": "止盈价必须位于当前价（%.2f）的盈利方向" % price}
	if stop_loss > 0.0 and (stop_loss - price) * profit_direction >= 0.0:
		return {"success": false, "message": "止损价必须位于当前价（%.2f）的亏损方向" % price}
	# 股票档案分组；写入或覆盖对应目标类型的档案后立即保存。
	var orders: Dictionary = _stop_orders.get(stock_id, {}) as Dictionary
	orders[kind] = {"take_profit": take_profit, "stop_loss": stop_loss}
	_stop_orders[stock_id] = orders
	_save_state()
	stop_orders_changed.emit()
	return {"success": true, "message": "止盈止损设置已保存"}


func clear_stop_order(stock_id: String, kind: String) -> Dictionary:
	## 清除指定股票指定目标类型的止盈止损档案；档案不存在时同样返回成功，保证界面清除操作幂等。
	if not stock_id in STOCK_IDS or not kind in [STOP_ORDER_KIND_SPOT, STOP_ORDER_KIND_LEVERAGE]:
		return {"success": false, "message": "止盈止损参数无效"}
	if not _discard_stop_order(stock_id, kind):
		return {"success": true, "message": "当前没有可清除的止盈止损设置"}
	_save_state()
	stop_orders_changed.emit()
	return {"success": true, "message": "止盈止损设置已清除"}


func _discard_stop_order(stock_id: String, kind: String) -> bool:
	## 静默移除一条止盈止损档案并返回是否发生移除；触发消耗、清仓清理与界面清除共用，调用方负责保存与信号。
	# 股票档案分组；不存在对应目标类型时无需任何修改。
	var orders: Dictionary = _stop_orders.get(stock_id, {}) as Dictionary
	if not orders.has(kind):
		return false
	orders.erase(kind)
	if orders.is_empty():
		_stop_orders.erase(stock_id)
	else:
		_stop_orders[stock_id] = orders
	return true


func _check_stop_orders() -> void:
	## 检查全部止盈止损档案；任意来源的行情刷新改价后调用，实时价到达目标价时自动市价卖出或全仓平仓。
	## 触发优先级；同一次刷新中强制平仓先于止盈止损执行，仓位被强平后对应杠杆档案由平仓结算路径统一清理。
	if _stop_orders.is_empty():
		return
	# 档案是否发生消耗或兜底清理；任一变化在循环结束后统一保存并广播一次档案变化信号。
	var orders_changed: bool = false
	for stock_id_key in _stop_orders.keys().duplicate():
		# 当前遍历股票标识；档案键在遍历中可能被移除，统一使用副本迭代。
		var stock_id: String = str(stock_id_key)
		# 当前股票档案分组；现货与杠杆档案在同一次刷新中独立判定。
		var orders: Dictionary = _stop_orders.get(stock_id, {}) as Dictionary
		# 当前实时价格；现货与杠杆触发共用同一份两位小数报价。
		var price: float = get_current_price(stock_id)
		if orders.has(STOP_ORDER_KIND_SPOT):
			# 现货档案；持仓已被手动清空时静默移除，否则按目标价判定触发方向。
			var spot_order: Dictionary = orders.get(STOP_ORDER_KIND_SPOT) as Dictionary
			# 当前现货持股数量；库存服务缺失时按 0 处理并走档案清理分支。
			var holding_quantity: int = 0
			if _global_inventory != null and _global_inventory.has_method("get_stock_holding"):
				holding_quantity = int((_global_inventory.call("get_stock_holding", stock_id) as Dictionary).get("quantity", 0))
			if holding_quantity <= 0:
				orders_changed = _discard_stop_order(stock_id, STOP_ORDER_KIND_SPOT) or orders_changed
			else:
				# 现货触发动作；止盈在价格达到目标上方触发，止损在价格跌破目标时触发，两者互斥。
				var spot_action: String = _resolve_stop_order_action(spot_order, price, 1.0)
				if not spot_action.is_empty():
					_discard_stop_order(stock_id, STOP_ORDER_KIND_SPOT)
					orders_changed = true
					_execute_spot_stop_order(stock_id, spot_action, holding_quantity)
		if orders.has(STOP_ORDER_KIND_LEVERAGE):
			# 杠杆档案；仓位已不存在时静默移除（正常关闭路径已清理，此处为读档异常等情况兜底）。
			var leverage_order: Dictionary = orders.get(STOP_ORDER_KIND_LEVERAGE) as Dictionary
			if not _leverage_positions.has(stock_id):
				orders_changed = _discard_stop_order(stock_id, STOP_ORDER_KIND_LEVERAGE) or orders_changed
			else:
				# 当前仓位盈利方向；做多以涨为盈利、做空以跌为盈利，触发比较随方向翻转。
				var position_direction: float = -1.0 if int((_leverage_positions.get(stock_id) as Dictionary).get("direction", LEVERAGE_LONG)) < 0 else 1.0
				# 杠杆触发动作；空字符串表示本次刷新未到达任何目标价。
				var leverage_action: String = _resolve_stop_order_action(leverage_order, price, position_direction)
				if not leverage_action.is_empty():
					_discard_stop_order(stock_id, STOP_ORDER_KIND_LEVERAGE)
					orders_changed = true
					# 平仓结算结果；与主动平仓共用同一结算路径，通知记录由结算路径按前缀写入。
					var settlement: Dictionary = _close_leverage_position(stock_id, "%s平仓" % leverage_action, false, "止盈止损通知：")
					stop_order_triggered.emit(stock_id, str(settlement.get("message", "止盈止损平仓完成")))
	if orders_changed:
		_save_state()
		stop_orders_changed.emit()


func _resolve_stop_order_action(order: Dictionary, price: float, profit_direction: float) -> String:
	## 判定一条档案在当前价格下触发的动作；返回“止盈”“止损”或空字符串，判定容差与其他证券币比较保持一致。
	# 止盈目标价；0 表示该方向未启用。
	var take_profit: float = float(order.get("take_profit", 0.0))
	# 止损目标价；0 表示该方向未启用。
	var stop_loss: float = float(order.get("stop_loss", 0.0))
	if take_profit > 0.0 and (price - take_profit) * profit_direction >= -0.0001:
		return "止盈"
	if stop_loss > 0.0 and (price - stop_loss) * profit_direction <= 0.0001:
		return "止损"
	return ""


func _execute_spot_stop_order(stock_id: String, action_label: String, quantity: int) -> void:
	## 执行现货止盈止损自动卖出；复用统一卖出路径保证成交价、手续费、交易记录与均价结算与手动卖出完全一致。
	# 市价卖出结果；卖出内部已完成持仓与余额的原子校验和持久化。
	var sell_result: Dictionary = request_sell(stock_id, quantity)
	# 结算股票定义；提示消息使用玩家可读的股票名称。
	var definition: Dictionary = STOCK_DEFINITIONS.get(stock_id, {}) as Dictionary
	if not bool(sell_result.get("success", false)):
		# 卖出失败兜底；持仓服务异常时只写入通知说明，档案已被消耗不会反复触发。
		_append_notification_record("止盈止损通知：%s%s触发，但自动卖出未能执行" % [str(definition.get("name", "股票")), action_label])
		_save_state()
		return
	# 触发说明文本；随通知记录持久化，并经触发信号交给面板提示与横幅通知服务展示。
	var message: String = "%s%s卖出 %d 股，单价 %.2f，到手 %.2f 证券币" % [str(definition.get("name", "股票")), action_label, quantity, float(sell_result.get("price", 0.0)), float(sell_result.get("total", 0.0))]
	_append_notification_record("止盈止损通知：%s" % message)
	_save_state()
	stop_order_triggered.emit(stock_id, message)


func get_trade_records() -> Array:
	## 返回交易历史记录深复制副本；索引 0 为最新记录，外部修改不影响服务内部状态。
	return _trade_records.duplicate(true)


func get_notification_records() -> Array:
	## 返回通知记录深复制副本；索引 0 为最新记录，外部修改不影响服务内部状态。
	return _notification_records.duplicate(true)


func _create_record_timestamp() -> Dictionary:
	## 生成记录时间字段；同时保存 Unix 秒和本地格式化文本，展示层无需再做时区换算。
	# 本地日期时间字典；直接读取系统本地时间，用于生成玩家可读的月日时分文本。
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return {
		"time_unix": Time.get_unix_time_from_system(),
		"time_text": "%02d-%02d %02d:%02d" % [int(now.get("month", 1)), int(now.get("day", 1)), int(now.get("hour", 0)), int(now.get("minute", 0))],
	}


func _append_trade_record(record_type: String, message: String) -> void:
	## 追加一条交易历史记录并裁剪到上限；调用方负责在同一成功路径内保存状态，本函数只维护内存列表并广播变化。
	# 新交易记录；类型标识供历史界面区分买卖、杠杆、强平与资金转账并着色。
	var record: Dictionary = _create_record_timestamp()
	record["type"] = record_type
	record["message"] = message
	_trade_records.push_front(record)
	while _trade_records.size() > TRADE_RECORD_LIMIT:
		_trade_records.pop_back()
	trade_records_changed.emit()


func _append_notification_record(message: String) -> void:
	## 追加一条通知记录并裁剪到上限；通知中心按列表顺序展示，索引 0 为最新记录。
	# 新通知记录；仅保存时间与说明文本，展示层不需要额外类型字段。
	var record: Dictionary = _create_record_timestamp()
	record["message"] = message
	_notification_records.push_front(record)
	while _notification_records.size() > NOTIFICATION_RECORD_LIMIT:
		_notification_records.pop_back()
	notification_records_changed.emit()


func request_securities_deposit(coin_amount: int) -> Dictionary:
	## 按 1:1 把整数永久星穹充值为证券币；星穹扣除失败时证券币余额保持不变。
	if coin_amount <= 0 or _global_inventory == null or not _global_inventory.has_method("spend_coins"):
		return {"success": false, "message": "无法执行充值"}
	# 星穹扣款结果；库存服务会在同一调用中再次复核实时星穹余额，防止弹窗额度过期。
	var coins_spent: bool = bool(_global_inventory.call("spend_coins", coin_amount))
	if not coins_spent:
		return {"success": false, "message": "星穹不足，充值未执行"}
	_securities_balance = _normalize_securities_amount(_securities_balance + float(coin_amount))
	# 充值交易记录；与本次余额保存同一路径落盘。
	_append_trade_record("deposit", "充值 %d 星穹，到账 %.2f 证券币" % [coin_amount, float(coin_amount)])
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
	# 提现交易记录；与本次余额保存同一路径落盘。
	_append_trade_record("withdraw", "提现 %d 证券币，手续费 %.2f，到账 %d 星穹" % [securities_amount, fee, received_coins])
	# 星穹立即保存；与证券币状态在同一次成功兑换路径落盘，缩短两份资产存档的不一致窗口。
	if _global_inventory.has_method("flush_stock_holdings_save"):
		_global_inventory.call("flush_stock_holdings_save")
	_save_state()
	securities_balance_changed.emit(_securities_balance)
	return {"success": true, "message": "提现成功，到账 %d 星穹" % received_coins, "securities": requested_amount, "fee": fee, "coins": received_coins}


func deduct_securities(amount: float, reason: String) -> float:
	## 银行贷款违约抵扣专用接口；直接按可用余额扣除证券币并写入交易记录，返回实际扣除金额。
	## 该接口不经过提现手续费，只允许信誉级联结算等系统级流程调用，普通交易仍走既有买卖与提现入口。
	if amount <= 0.0:
		return 0.0
	# 实际扣除金额；请求值与当前余额取小，账户不会因抵扣变为负数。
	var deducted: float = _normalize_securities_amount(minf(amount, get_securities_balance()))
	if deducted <= 0.0:
		return 0.0
	_securities_balance = _normalize_securities_amount(_securities_balance - deducted)
	# 抵扣交易记录；说明文本携带调用方原因，供历史记录界面追溯资金去向。
	_append_trade_record("bank_deduct", "%s：扣除 %.2f 证券币" % [reason, deducted])
	_save_state()
	securities_balance_changed.emit(_securities_balance)
	return deducted


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
	# 常数化估算补充；现改为直接按含费单价推算下界，再向上试探修正，避免大额余额时从无费上限逐一递减的长循环。
	var estimated_quantity: int = maxi(floori(coins / (price * (1.0 + clampf(stock_trade_fee_ratio, 0.0, 1.0)))), 0)
	while estimated_quantity + 1 <= floori(coins / price):
		# 向上试探总额；检查再多买一股是否仍可支付，手续费进位使该循环最多前进一到两次。
		var next_gross: float = _normalize_securities_amount(price * (estimated_quantity + 1))
		# 向上试探手续费；与最终买入请求使用同一公式，防止数量弹窗出现无法成交的上限。
		var next_fee: float = _calculate_securities_fee(next_gross, stock_trade_fee_ratio)
		if _normalize_securities_amount(next_gross + next_fee) > coins + 0.0001:
			break
		estimated_quantity += 1
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
		# 买入股票定义；交易记录使用玩家可读的股票名称。
		var buy_record_definition: Dictionary = STOCK_DEFINITIONS.get(stock_id, {}) as Dictionary
		# 买入交易记录；与本次持仓和余额保存同一路径落盘。
		_append_trade_record("buy", "买入 %s %d 股，单价 %.2f，含费花费 %.2f 证券币" % [str(buy_record_definition.get("name", "股票")), quantity, price, total_cost])
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
	# 卖出前加权平均成本；含历史买入手续费，用于计算本次卖出的已实现盈亏提示。
	var average_cost: float = float((_global_inventory.call("get_stock_holding", stock_id) as Dictionary).get("average_cost", 0.0)) if _global_inventory.has_method("get_stock_holding") else 0.0
	# 卖出结果；库存服务会再次校验持仓数量并实时增加永久星穹。
	# 证券币结算规则；旧星穹说明仅保留历史注释兼容，持仓扣除成功后才增加股市独立账户余额。
	var success: bool = bool(_global_inventory.call("remove_stock_holding_without_currency", stock_id, quantity))
	# 本次已实现盈亏；实际到手所得减去按加权成本折算的持仓成本，成本缺失时按 0 展示。
	var realized_profit: float = snappedf(proceeds - average_cost * float(quantity), 0.01) if average_cost > 0.0 else 0.0
	if success:
		_securities_balance = _normalize_securities_amount(_securities_balance + proceeds)
		# 卖出股票定义；交易记录使用玩家可读的股票名称。
		var sell_record_definition: Dictionary = STOCK_DEFINITIONS.get(stock_id, {}) as Dictionary
		# 卖出交易记录；与本次持仓和余额保存同一路径落盘。
		_append_trade_record("sell", "卖出 %s %d 股，单价 %.2f，到手 %.2f 证券币，盈亏 %+.2f" % [str(sell_record_definition.get("name", "股票")), quantity, price, proceeds, realized_profit])
		# 现货止盈止损档案清理；持股清零后同股票的现货档案随之失效，手动清仓与自动触发卖出共用该清理。
		var spot_stop_order_removed: bool = false
		if _global_inventory.has_method("get_stock_holding") and int((_global_inventory.call("get_stock_holding", stock_id) as Dictionary).get("quantity", 0)) <= 0:
			spot_stop_order_removed = _discard_stop_order(stock_id, STOP_ORDER_KIND_SPOT)
		# 持仓立即保存；与下方证券币状态同一次成功路径落盘，缩短跨文件交易状态的不一致窗口。
		if _global_inventory.has_method("flush_stock_holdings_save"):
			_global_inventory.call("flush_stock_holdings_save")
		_save_state()
		securities_balance_changed.emit(_securities_balance)
		if spot_stop_order_removed:
			stop_orders_changed.emit()
	# 卖出成功提示；附带按含费加权成本计算的本次已实现盈亏，帮助玩家直接确认这笔交易的赚亏。
	var success_message: String = "卖出成功，盈亏 %+.2f 证券币" % realized_profit if average_cost > 0.0 else "卖出成功"
	return {"success": success, "message": success_message if success else "持仓数量不足", "quantity": quantity, "price": price, "fee": fee, "total": proceeds, "realized_profit": realized_profit}


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
	# 杠杆强平检查；任意刷新来源改价后立即判定，强制平仓在结算路径内自行保存并广播信号。
	_check_leverage_liquidations()
	# 止盈止损检查；在强平判定之后执行，价格到达玩家目标价时自动卖出现货或平掉杠杆仓位。
	_check_stop_orders()
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
	# 历史扩容补充；保留上限现由 PRICE_HISTORY_LIMIT 统一为 90 个采样，让折线覆盖约 1.5 分钟微行情走势。
	var history: Array = state.get("history", []) as Array
	history.append(maxf(snappedf(new_price, 0.01), 0.01))
	while history.size() > PRICE_HISTORY_LIMIT:
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
	# 保险行为累计值；由保险服务在投保、理赔与安全撤离时累计，正式结算一次性取走后清零。
	var insurance_impact: Dictionary = {}
	# 保险服务；缺失时按零影响处理，行情与其余五只股票不受影响。
	var insurance_service: Node = get_tree().root.get_node_or_null("InsuranceService")
	if insurance_service != null and insurance_service.has_method("consume_market_impact"):
		insurance_impact = insurance_service.call("consume_market_impact") as Dictionary
	return {
		"quantum_arms": clampf(floor(float(_run_metrics.get("shots", 0.0)) / 100.0) * 0.003 + floor(float(_run_metrics.get("weapon_durability", 0.0)) / 500.0) * 0.004 + float(_run_metrics.get("new_weapons", 0.0)) * 0.002 + floor(float(_run_metrics.get("extracted_weapon_value", 0.0)) / 800.0) * 0.003, -0.02, 0.02),
		"astral_defense": clampf(floor(float(_run_metrics.get("damage_taken", 0.0)) / 100.0) * 0.005 + floor(float(_run_metrics.get("armor_durability", 0.0)) / 300.0) * 0.004 + floor(float(_run_metrics.get("dodges", 0.0)) / 20.0) * 0.002 + float(_run_metrics.get("broken_armor", 0.0)) * 0.003, -0.02, 0.02),
		"hacker_tech": clampf(float(_run_metrics.get("enhancement_stones", 0.0)) * 0.002 + float(_run_metrics.get("shipped_enhancement_stones", 0.0)) * 0.003 + floor(float(_run_metrics.get("chests_opened", 0.0)) / 5.0) * 0.002 + float(_run_metrics.get("high_enhancement_stones", 0.0)) * 0.004, -0.02, 0.02),
		"frontline_supply": clampf(float(_run_metrics.get("repair_kits_used", 0.0)) * 0.004 + floor(float(_run_metrics.get("shipped_value", 0.0)) / 500.0) * 0.003 + floor(float(_run_metrics.get("lost_value", 0.0)) / 300.0) * 0.005 + floor(float(_run_metrics.get("survival_seconds", 0.0)) / 120.0) * 0.002, -0.02, 0.02),
		"relic_exploration": clampf(float(_run_metrics.get("chests_opened", 0.0)) * 0.002 + float(_run_metrics.get("high_quality_items", 0.0)) * 0.005 + floor(float(_run_metrics.get("extracted_value", 0.0)) / 1000.0) * 0.003 - floor(float(_run_metrics.get("lost_high_value", 0.0)) / 800.0) * 0.004, -0.02, 0.02),
		"astral_insurance": clampf(floor(float(insurance_impact.get("premium_gold", 0)) / 100.0) * 0.003 + float(insurance_impact.get("safe_extractions", 0)) * 0.004 - floor(float(insurance_impact.get("claim_gold", 0)) / 200.0) * 0.005, -0.02, 0.02),
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


func _calculate_leverage_profit(position: Dictionary, current_price: float) -> float:
	## 计算杠杆仓位浮动盈亏；等于方向乘价格变化率乘名义本金，做多涨盈利、做空跌盈利，保留两位小数。
	# 仓位开仓价；异常为零时按无盈亏处理，避免除零。
	var entry_price: float = float(position.get("entry_price", 0.0))
	if entry_price <= 0.0:
		return 0.0
	# 仓位名义本金；保证金乘杠杆倍数，开仓后固定不随价格变化。
	var notional: float = float(position.get("margin", 0.0)) * float(position.get("leverage", 1))
	# 仓位方向；正数做多、负数做空，异常值按做多处理。
	var direction: float = -1.0 if int(position.get("direction", LEVERAGE_LONG)) < 0 else 1.0
	return snappedf(direction * (current_price / entry_price - 1.0) * notional, 0.01)


func _calculate_leverage_equity(position: Dictionary, current_price: float) -> float:
	## 计算杠杆仓位实时净值；等于保证金加浮动盈亏，最低为 0，代表爆仓后不产生负债。
	return maxf(snappedf(float(position.get("margin", 0.0)) + _calculate_leverage_profit(position, current_price), 0.01), 0.0)


func _calculate_leverage_liquidation_price(position: Dictionary) -> float:
	## 计算杠杆仓位理论强平价；亏损达到保证金乘强平亏损线时的价格，做多低于开仓价、做空高于开仓价。
	# 仓位开仓价；异常为零时返回 0 表示无有效强平价。
	var entry_price: float = float(position.get("entry_price", 0.0))
	# 仓位杠杆倍数；至少为 1，倍数越高强平价越贴近开仓价。
	var leverage: float = maxf(float(position.get("leverage", 1)), 1.0)
	if entry_price <= 0.0:
		return 0.0
	# 强平触发的价格变化率；等于强平亏损线除以杠杆倍数。
	var trigger_change_ratio: float = clampf(leverage_liquidation_loss_ratio, 0.0, 1.0) / leverage
	# 仓位方向；做多时价格下跌触发，做空时价格上涨触发。
	var direction: float = -1.0 if int(position.get("direction", LEVERAGE_LONG)) < 0 else 1.0
	return maxf(snappedf(entry_price * (1.0 - direction * trigger_change_ratio), 0.01), 0.0)


func _close_leverage_position(stock_id: String, action_label: String, is_forced: bool = false, notification_prefix: String = "") -> Dictionary:
	## 统一执行杠杆仓位结算；主动平仓、止盈止损平仓与强制平仓共用，按实时价格计算净值、扣除平仓手续费、返还证券币并立即持久化。
	## 强平通知补充；is_forced 为 true 时额外写入通知记录并广播强平专用信号，供通知中心与横幅通知服务联动。
	## 止盈止损通知补充；notification_prefix 非空时按该前缀写入一条通知记录，触发信号由止盈止损检查路径负责广播。
	# 待结算仓位；调用方必须先确认仓位存在。
	var position: Dictionary = _leverage_positions.get(stock_id, {}) as Dictionary
	# 结算实时价格；与玩家界面展示同源的两位小数报价。
	var settle_price: float = get_current_price(stock_id)
	# 结算浮动盈亏；正值盈利、负值亏损，仅用于提示消息与结果返回。
	var profit: float = _calculate_leverage_profit(position, settle_price)
	# 结算净值；保证金加盈亏且最低为 0。
	var equity: float = _calculate_leverage_equity(position, settle_price)
	# 平仓手续费；按名义本金收取，与开仓手续费同一公式。
	var fee: float = _calculate_securities_fee(float(position.get("margin", 0.0)) * float(position.get("leverage", 1)), leverage_fee_ratio)
	# 最终返还金额；净值扣除手续费后最低为 0，爆仓不产生负债。
	var payout: float = _normalize_securities_amount(maxf(equity - fee, 0.0))
	_leverage_positions.erase(stock_id)
	_securities_balance = _normalize_securities_amount(_securities_balance + payout)
	# 结算股票定义；提示消息使用玩家可读的股票名称。
	var definition: Dictionary = STOCK_DEFINITIONS.get(stock_id, {}) as Dictionary
	# 结算提示消息；统一说明动作、盈亏和返还金额。
	var message: String = "%s%s：盈亏 %+.2f，返还 %.2f 证券币" % [str(definition.get("name", "股票")), action_label, profit, payout]
	# 平仓交易记录；强制平仓与主动平仓使用独立类型标识，供历史记录界面区分着色。
	_append_trade_record("leverage_liquidation" if is_forced else "leverage_close", message)
	if is_forced:
		# 强平通知记录；写入面板通知中心，随下方保存同一路径落盘。
		_append_notification_record("强平通知：%s" % message)
	elif not notification_prefix.is_empty():
		# 止盈止损等自动结算通知记录；按调用方前缀写入面板通知中心，随下方保存同一路径落盘。
		_append_notification_record("%s%s" % [notification_prefix, message])
	# 杠杆止盈止损档案清理；仓位关闭后同股票的杠杆档案随之失效，主动、自动与强制平仓共用该清理。
	var stop_order_removed: bool = _discard_stop_order(stock_id, STOP_ORDER_KIND_LEVERAGE)
	_save_state()
	securities_balance_changed.emit(_securities_balance)
	leverage_positions_changed.emit()
	if stop_order_removed:
		stop_orders_changed.emit()
	leverage_position_closed.emit(stock_id, message)
	if is_forced:
		# 强平专用信号；横幅通知服务据此在任何场景顶端提醒玩家。
		leverage_position_liquidated.emit(stock_id, message)
	return {"message": message, "profit": profit, "payout": payout}


func _check_leverage_liquidations() -> void:
	## 检查全部杠杆仓位的强平条件；任意来源的行情刷新后调用，浮亏达到保证金乘强平亏损线时立即强制平仓。
	if _leverage_positions.is_empty():
		return
	# 待检查股票列表；先复制键避免遍历期间移除仓位破坏迭代。
	var position_stock_ids: Array = _leverage_positions.keys().duplicate()
	for stock_id in position_stock_ids:
		# 当前检查仓位；强平判定与展示共用同一净值公式。
		var position: Dictionary = _leverage_positions.get(stock_id, {}) as Dictionary
		# 当前实时净值；净值跌破保留线时触发强制平仓。
		var equity: float = _calculate_leverage_equity(position, get_current_price(str(stock_id)))
		# 净值保留线；保证金乘（1 - 强平亏损线），默认保证金的 10%。
		var equity_floor: float = float(position.get("margin", 0.0)) * (1.0 - clampf(leverage_liquidation_loss_ratio, 0.0, 1.0))
		if equity <= equity_floor + 0.0001:
			_close_leverage_position(str(stock_id), "强制平仓", true)


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
		"leverage_positions": _leverage_positions,
		"stop_orders": _stop_orders,
		"trade_records": _trade_records,
		"notification_records": _notification_records,
		"stock_states": _stock_states,
	}
	# 股市存档文件；打开失败时保留内存状态并等待下一次刷新重试。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()


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
	# 原始杠杆仓位表；版本 4 及更旧存档没有该字段，默认按无杠杆仓位处理。
	var raw_leverage_positions: Variant = save_data.get("leverage_positions", {})
	_leverage_positions.clear()
	if raw_leverage_positions is Dictionary:
		for leverage_stock_id in STOCK_IDS:
			# 单股原始杠杆仓位；只恢复字段完整且保证金与开仓价为正数的合法仓位。
			var raw_position: Variant = (raw_leverage_positions as Dictionary).get(leverage_stock_id)
			if not (raw_position is Dictionary):
				continue
			# 原始仓位字典；逐字段标准化，异常倍数或方向的仓位直接丢弃。
			var position_data: Dictionary = raw_position as Dictionary
			# 恢复的杠杆倍数；必须命中可选倍数目录。
			var restored_leverage: int = int(position_data.get("leverage", 0))
			# 恢复的保证金；必须为正数。
			var restored_margin: float = float(position_data.get("margin", 0.0))
			# 恢复的开仓价；必须为正数。
			var restored_entry_price: float = float(position_data.get("entry_price", 0.0))
			if not restored_leverage in LEVERAGE_MULTIPLIERS or restored_margin <= 0.0 or restored_entry_price <= 0.0:
				continue
			_leverage_positions[leverage_stock_id] = {
				"direction": LEVERAGE_SHORT if int(position_data.get("direction", LEVERAGE_LONG)) < 0 else LEVERAGE_LONG,
				"leverage": restored_leverage,
				"margin": restored_margin,
				"entry_price": restored_entry_price,
				"opened_settlement_count": maxi(int(position_data.get("opened_settlement_count", 0)), 0),
			}
	# 原始止盈止损档案表；版本 7 及更旧存档没有该字段，默认按无档案处理，价格字段异常的档案直接丢弃。
	var raw_stop_orders: Variant = save_data.get("stop_orders", {})
	_stop_orders.clear()
	if raw_stop_orders is Dictionary:
		for stop_stock_id in STOCK_IDS:
			# 单股原始档案分组；仅字典结构参与恢复。
			var raw_orders: Variant = (raw_stop_orders as Dictionary).get(stop_stock_id)
			if not (raw_orders is Dictionary):
				continue
			# 恢复后的档案分组；逐目标类型校验，至少一个正数目标价才恢复该条档案。
			var restored_orders: Dictionary = {}
			for stop_kind in [STOP_ORDER_KIND_SPOT, STOP_ORDER_KIND_LEVERAGE]:
				# 单条原始档案；缺失或结构异常时跳过。
				var raw_order: Variant = (raw_orders as Dictionary).get(stop_kind)
				if not (raw_order is Dictionary):
					continue
				# 恢复的止盈目标价；负数按未启用处理。
				var restored_take_profit: float = maxf(snappedf(float((raw_order as Dictionary).get("take_profit", 0.0)), 0.01), 0.0)
				# 恢复的止损目标价；负数按未启用处理。
				var restored_stop_loss: float = maxf(snappedf(float((raw_order as Dictionary).get("stop_loss", 0.0)), 0.01), 0.0)
				if restored_take_profit <= 0.0 and restored_stop_loss <= 0.0:
					continue
				restored_orders[stop_kind] = {"take_profit": restored_take_profit, "stop_loss": restored_stop_loss}
			if not restored_orders.is_empty():
				_stop_orders[stop_stock_id] = restored_orders
	# 原始交易记录列表；版本 5 及更旧存档没有该字段，默认按空记录处理，超限部分直接丢弃最旧记录。
	var raw_trade_records: Variant = save_data.get("trade_records", [])
	_trade_records = (raw_trade_records as Array).duplicate(true) if raw_trade_records is Array else []
	while _trade_records.size() > TRADE_RECORD_LIMIT:
		_trade_records.pop_back()
	# 原始通知记录列表；版本 5 及更旧存档没有该字段，默认按空记录处理，超限部分直接丢弃最旧记录。
	var raw_notification_records: Variant = save_data.get("notification_records", [])
	_notification_records = (raw_notification_records as Array).duplicate(true) if raw_notification_records is Array else []
	while _notification_records.size() > NOTIFICATION_RECORD_LIMIT:
		_notification_records.pop_back()
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
