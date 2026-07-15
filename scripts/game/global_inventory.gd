extends Node

## 全局背包服务统一维护局内背包、局外仓库、装备槽、获得时间和战斗结算。
## 玩家组件与主菜单仓库只通过公开接口读取或移动物品，避免各场景分别保存一份背包副本。

signal inventory_changed
signal equipment_changed
signal run_state_changed
signal warehouse_changed
signal coins_changed
## 图鉴发现状态变化信号；只有首次获得新的稳定物品条目时派发，图鉴 UI 据此刷新已解锁卡片。
signal encyclopedia_changed
## 股票持仓变化信号；买入、卖出、旧存档迁移或开发者清空持仓后通知股市 UI 刷新。
signal stock_holdings_changed
## 战斗失败遗失记录信号；参数为本次实际遗失条目，商店灰市通过该只读快照维护最近五次失败物品。
signal combat_failure_losses_recorded(lost_entries: Array)

## 全局背包存档路径；默认写入用户目录，保存物品标识、获得时间、排序优先级和装备槽。
const SAVE_PATH: String = "user://global_inventory.json"
## 当前库存存档版本；默认 7，版本 7 起支持可堆叠修复包的独立数据恢复。
## 版本 9 补充；当前值升级为 9，用于保存股票持仓数量和加权平均成本，旧存档自动初始化为空持仓。
## 星内容精简补充：当前值升级为 10，用于在旧内容资源移除后为旧存档补齐星扩展包的可用初始装备。
## 强化石词条清理补充：版本 12 会移除旧强化石中的散射、穿透、弹射和连击词条并回写有效结果。
const SAVE_VERSION: int = 12
## 图鉴系统补充：当前库存存档版本为 11，新增永久图鉴发现记录；旧存档会从当前持有与已装备物品初始化已发现条目。
## 当前版本说明：库存版本现为 12；版本 11 的图鉴发现迁移继续保留，版本 12 在其后追加强化石词条清理。
## 强化公式存档版本；版本 2 起暴击率、暴击伤害和闪避率的累计值按直接百分点保存。
const ENHANCEMENT_FORMULA_VERSION: int = 2
## 旧版耐久上限；固定 100.0，用于把版本 5 的当前耐久按比例迁移到新版上限。
const LEGACY_DURABILITY_MAX: float = 100.0
## 默认远程槽数量；当前项目使用双远程武器，修改需要同步玩家输入可直接选择的槽位数量。
const DEFAULT_RANGED_SLOT_COUNT: int = 2
## 默认武器资源路径表；键为稳定 weapon_id，值为可重新加载的项目资源路径。
const WEAPON_RESOURCE_PATHS: Dictionary = {
	"as_ive_written": "res://data/weapons/stelle/as_ive_written.tres",
	"galactic_baseball_bat": "res://data/weapons/stelle/galactic_baseball_bat.tres",
}
## 修复包资源路径表；键为稳定 item_id，值为项目内模板路径，用于存档恢复和未来扩展。
const REPAIR_KIT_RESOURCE_PATHS: Dictionary = {
	"repair_kit_basic": "res://data/items/repair_kit_basic.tres",
	"repair_kit_medium": "res://data/items/repair_kit_medium.tres",
	"repair_kit_advanced": "res://data/items/repair_kit_advanced.tres",
}
## 装备资源路径表；键为稳定 equipment_id，值用于存档恢复与开发者默认发放。
const EQUIPMENT_RESOURCE_PATHS: Dictionary = {
	"trailblazer_hat": "res://data/equipment/stelle/trailblazer_hat.tres",
	"trailblazer_coat": "res://data/equipment/stelle/trailblazer_coat.tres",
	"trailblazer_pants": "res://data/equipment/stelle/trailblazer_pants.tres",
	"trailblazer_boots": "res://data/equipment/stelle/trailblazer_boots.tres",
}
## 默认背包武器标识；首次建立存档时放入未装备武器，顺序会按获得时间默认排序。
## 永久仓库初始化补充：常量名称为旧存档兼容保留，当前首次存档会把这些未装备武器放入永久仓库。
## 星内容精简补充：当前没有额外初始仓库武器，两把星扩展包武器分别直接进入远程与近战装备槽。
const DEFAULT_BACKPACK_WEAPON_IDS: Array[String] = []
## 默认远程装备标识；首次建立存档时依次装入两个远程槽。
## 星内容精简补充：当前只装备一把“如我所书”，第二个远程槽保持为空且不会复制同一模板。
const DEFAULT_RANGED_WEAPON_IDS: Array[String] = ["as_ive_written"]
## 默认近战装备标识；首次建立存档时装入近战槽。
## 星内容精简补充：当前近战初始武器为“银河球棒”。
const DEFAULT_MELEE_WEAPON_ID: String = "galactic_baseball_bat"
## 默认局外金币数量；首次建立存档时为 0，金币只能通过出售永久仓库物品增加且不会进入战斗。
const DEFAULT_STARTING_COINS: int = 0
## 战斗失败默认保留比例；默认 0.5，使背包内每件武器和每颗资源长期平均各保留 50%。
const DEFAULT_FAILURE_RETENTION_RATIO: float = 0.5
## 单局物资送回价值上限；默认 1000 金币，背包与装备栏送回价值共同累计且不会因关闭面板重置。
const COMBAT_SHIPPING_VALUE_LIMIT: int = 1000
## 物资送回运费比例；默认按物品价值的 20% 向上取整扣除局外金币。
const COMBAT_SHIPPING_FEE_RATIO: float = 0.20
## 永久仓库位置标识；默认供局外拖拽接口识别安全存储来源和目标。
const STORAGE_LOCATION_WAREHOUSE: String = "warehouse"
## 随身背包位置标识；默认供局外拖拽接口识别战斗携带来源和目标。
const STORAGE_LOCATION_BACKPACK: String = "backpack"
## 近战装备位置标识；默认对应唯一近战槽，拖拽时只接收 melee 武器。
const EQUIPMENT_LOCATION_MELEE: String = "melee"
## 远程装备位置前缀；默认与槽位下标组合为 ranged_0、ranged_1 等稳定目标标识。
const EQUIPMENT_LOCATION_RANGED_PREFIX: String = "ranged_"
## 防具装备位置前缀；与 head、body、legs、feet 组合成稳定存档位置。
const EQUIPMENT_LOCATION_ARMOR_PREFIX: String = "armor_"
## 防具部位顺序；固定用于 UI、存档和属性聚合。
const ARMOR_SLOT_IDS: Array[String] = ["head", "body", "legs", "feet"]
## 可堆叠资源单组上限；默认 99，所有仓库、背包、转移、读档和拾取逻辑共同遵守该限制。
const MAX_STACK_QUANTITY: int = 99
## 强化石图鉴稳定发现键；随机生成的强化石没有固定模板，任意一颗首次获得后统一解锁该资源类别条目。
const ENHANCEMENT_STONE_DISCOVERY_KEY: String = "enhancement_stone:any"
## 开发者单次发放强化石数量；默认 10，对应隐藏开发者菜单的固定调试功能。
const DEVELOPER_STONE_GRANT_COUNT: int = 10
## 开发者强化石最少词条数；默认 1，与战斗掉落默认配置保持一致。
const DEVELOPER_STONE_MIN_MODIFIER_COUNT: int = 1
## 开发者强化石最多词条数；默认 3，与战斗掉落默认配置保持一致。
const DEVELOPER_STONE_MAX_MODIFIER_COUNT: int = 3
## 开发者强化石削弱词条概率；默认 0.28，与战斗掉落默认配置保持一致。
const DEVELOPER_STONE_DETRIMENTAL_CHANCE: float = 0.28
## 开发者强化石单词条基础价值；默认 30 金币，与战斗掉落默认配置保持一致。
const DEVELOPER_STONE_BASE_SELL_PRICE: int = 30
## 开发者强化石兼容说明；词条数和削弱概率已由品质规则接管，上述三项随机常量仅用于保持旧调用签名稳定。

## 永久仓库记录数组；每项包含唯一记录编号、武器资源、获得时间与撤离优先级，战斗失败不会修改该数组。
var _warehouse_records: Array[Dictionary] = []
## 背包记录数组；每项包含唯一记录编号、武器资源、获得时间与上次撤离优先级。
var _backpack_records: Array[Dictionary] = []
## 远程装备记录数组；元素为 Dictionary 或 null，默认固定两个槽并允许空槽。
var _ranged_equipment_records: Array = []
## 近战装备记录；默认空字典表示没有装备近战武器。
var _melee_equipment_record: Dictionary = {}
## 四部位防具记录；键为 head、body、legs、feet，值为空字典或装备记录。
var _armor_equipment_records: Dictionary = {}
## 临时脱离容器的记录表；键为资源实例编号，值为记录，用于兼容 HUD 分步移除、装备和回滚流程。
var _detached_records: Dictionary = {}
## 当前选中远程槽；取值为 0 到远程槽数量减一，默认 0 并跨场景保存。
var _current_ranged_slot: int = 0
## 当前获得顺序编号；取值单调递增，默认用于同秒获得多个物品时保持稳定排序。
var _acquisition_sequence: int = 0
## 最近一次成功撤离编号；取值单调递增，默认用于把上次撤离携带物品排在仓库前方。
var _last_extraction_epoch: int = 0
## 当前是否处于正式战斗局；默认 false，只有 GameWorld 正式骇入模式会开启损失与撤离结算。
var _run_active: bool = false
## 本局已经持有过的资源实例集合；键为 Resource 实例编号，值为 true，用于排除自己丢弃后重新捡回的开局物品。
var _run_seen_resource_instance_ids: Dictionary = {}
## 本局首次从战场获得的资源；元素为稳定 Resource 引用，同一实例反复丢弃和捡回只记录一次。
var _run_gained_resources: Array[Resource] = []
## 最近一次战斗结算；包含 result、gained_entries、lost_entries 及兼容名称数组，默认空字典。
var _last_run_outcome: Dictionary = {}
## 当前正式战斗已经送回仓库的物品总价值；默认 0，每次开始新战斗时重置，最大不超过 1000。
var _combat_shipped_value: int = 0
## 存档是否已排队；默认 false，同一帧多次拖拽操作只在帧末写盘一次。
var _save_queued: bool = false
## 正式战斗库存是否存在尚未落盘的变化；默认 false，拾取、丢弃和耐久变化只更新内存，撤离或失败结算后统一保存，避免仓库较大时每次交互都序列化完整库存。
var _combat_inventory_save_pending: bool = false
## 耐久变化合并存档间隔；默认 0.5 秒，高射速连续射击期间最多每半秒触发一次实际存档写入。
@export_range(0.05, 10.0, 0.05) var durability_save_delay_seconds: float = 0.5
## 是否已有耐久存档等待执行；默认 false，用于把短时间内多次射击合并为一次磁盘写入。
var _durability_save_queued: bool = false
## 股票交易合并存档间隔；默认 0.5 秒，连续买卖会合并磁盘写入但内存余额和持仓实时生效。
@export_range(0.05, 10.0, 0.05) var stock_trade_save_delay_seconds: float = 0.5
## 是否已有股票交易存档等待执行；默认 false，用于限制高频连续交易的磁盘写入次数。
var _stock_trade_save_queued: bool = false
## 服务随机数生成器；默认启动时随机化，用于失败结算随机保留 50% 背包物品。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 局外金币余额；取值大于等于 0，默认 0，只在主菜单仓库出售永久物品时增加。
var _coins: int = DEFAULT_STARTING_COINS
## 股票持仓表；键为稳定股票标识，值包含非负整数 quantity 与非负浮点 average_cost。
var _stock_holdings: Dictionary = {}
## 已发现图鉴条目表；键为“物品类型:稳定 ID”或强化石统一键，值为 true，物品出售、消耗与战斗失败都不会移除记录。
var _discovered_encyclopedia_entries: Dictionary = {}
## 已读取存档是否完成内容精简迁移；默认 false，版本 10 之前补齐星扩展包装备后置为 true，并在启动阶段立即回写避免重复发放。
var _loaded_inventory_requires_resave: bool = false


func _ready() -> void:
	_random.randomize()
	_initialize_equipment_slots()
	if not _load_inventory():
		_initialize_default_inventory()
		_save_inventory()
	elif _loaded_inventory_requires_resave:
		_save_inventory()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _run_active:
		complete_combat_run_failure("主动退出游戏")
		_save_inventory()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and _stock_trade_save_queued:
		# 关闭窗口前立即落盘；避免最后 0.5 秒内的交易尚未触发合并计时器而丢失。
		_save_inventory()


func begin_combat_run() -> void:
	_run_active = true
	_combat_inventory_save_pending = false
	_combat_shipped_value = 0
	_run_seen_resource_instance_ids.clear()
	_run_gained_resources.clear()
	_reset_run_gained_quantities()
	# 开局物品记录；取值为背包和装备中的全部有效记录，用于建立战斗内已见资源身份集合。
	for record in _get_all_owned_records():
		# 开局物品资源；加入已见实例集合后，玩家把它扔到地面再捡回时不会误算为本局战利品。
		var item_resource: Resource = record.get("resource") as Resource
		if item_resource != null:
			_run_seen_resource_instance_ids[item_resource.get_instance_id()] = true
	_last_run_outcome.clear()
	run_state_changed.emit()


func is_combat_run_active() -> bool:
	return _run_active


func complete_combat_run_success() -> Dictionary:
	if not _run_active:
		return _last_run_outcome.duplicate(true)

	_last_extraction_epoch += 1
	# 本局获得物品条目；从当前全部所有权记录读取本局来源数量，覆盖背包、装备和物资撤离点已送回仓库的物品。
	var gained_entries: Array[Dictionary] = _build_retained_run_gained_entries()
	# 本局获得物品名称；保留为兼容字段，列表式结算优先读取包含 Resource 的 gained_entries。
	var gained_items: Array[String] = _get_outcome_entry_names(gained_entries)
	# 成功撤离携带记录；包含背包与装备，全部写入本次撤离编号以支持以后卸下时仍优先排序。
	for record in _get_all_owned_records():
		record["last_extraction_epoch"] = _last_extraction_epoch
	# 成功撤离只保留随身背包现状，不自动转入永久仓库；玩家需要在局外仓库手动整理安全物品。
	_run_active = false
	_run_seen_resource_instance_ids.clear()
	_run_gained_resources.clear()
	_last_run_outcome = {
		"result": "success",
		"title": "撤离成功",
		"gained_entries": gained_entries,
		"lost_entries": [],
		"gained_items": gained_items,
		"lost_items": [],
	}
	_queue_save_inventory()
	inventory_changed.emit()
	equipment_changed.emit()
	run_state_changed.emit()
	return _last_run_outcome.duplicate(true)


func complete_combat_run_failure(reason: String = "战斗失败", retained_ratio: float = DEFAULT_FAILURE_RETENTION_RATIO) -> Dictionary:
	if not _run_active:
		return _last_run_outcome.duplicate(true)

	# 标准化保留概率；每件武器或每颗堆叠资源独立判定，默认长期平均保留约 50%。
	var resolved_retained_ratio: float = clampf(retained_ratio, 0.0, 1.0)
	# 结算后背包记录；武器整件保留或丢失，强化石堆叠按单颗随机后保留剩余数量。
	var retained_records: Array[Dictionary] = []
	# 丢失物品条目；每项携带 Resource 与显示名，结算列表可直接复用仓库物品详情。
	var lost_entries: Array[Dictionary] = []
	# 丢失物品名称；元素为显示名，用于死亡或主动退出结算界面。
	var lost_items: Array[String] = []
	# 当前结算记录；逐组处理数量，保证 99 个强化石不会被当成一件物品整体保留或整体丢失。
	for record in _backpack_records:
		# 原始数量；武器默认 1，堆叠资源限制在 1 到 99。
		var original_quantity: int = clampi(int(record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
		# 原始本局来源数量；同一堆叠中排在前面的逻辑单位视为本局所得，仅用于分别统计实际保留数量。
		var original_run_gained_quantity: int = clampi(int(record.get("run_gained_quantity", 0)), 0, original_quantity)
		# 实际保留数量；每个单位独立随机判定，武器数量固定为 1。
		var retained_quantity: int = 0
		# 实际保留的本局来源数量；决定失败界面“本局获得”中仍可展示的数量。
		var retained_run_gained_quantity: int = 0
		for unit_index in range(original_quantity):
			if _random.randf() < resolved_retained_ratio:
				retained_quantity += 1
				if unit_index < original_run_gained_quantity:
					retained_run_gained_quantity += 1
		# 丢失数量；用于结算列表在一个条目上显示 xN。
		var lost_quantity: int = original_quantity - retained_quantity
		if retained_quantity > 0:
			record["quantity"] = retained_quantity
			record["run_gained_quantity"] = retained_run_gained_quantity
			retained_records.append(record)
		if lost_quantity > 0:
			lost_entries.append(_build_outcome_entry(record.get("resource") as Resource, lost_quantity))
			lost_items.append("%s x%d" % [_get_record_display_name(record), lost_quantity] if lost_quantity > 1 else _get_record_display_name(record))

	_backpack_records = retained_records
	_detached_records.clear()
	# 本局获得物品条目；只读取结算后仍由玩家持有的本局来源数量，因此本局获得后又丢失的单位不会重复出现在收益区。
	var gained_entries: Array[Dictionary] = _build_retained_run_gained_entries()
	# 本局获得物品名称；保留为兼容字段，列表式结算使用 gained_entries 提供悬停详情。
	var gained_items: Array[String] = _get_outcome_entry_names(gained_entries)
	_run_active = false
	_run_seen_resource_instance_ids.clear()
	_run_gained_resources.clear()
	_last_run_outcome = {
		"result": "failure",
		"title": reason,
		"gained_entries": gained_entries,
		"lost_entries": lost_entries,
		"gained_items": gained_items,
		"lost_items": lost_items,
		"retained_ratio": resolved_retained_ratio,
		"lost_ratio": 1.0 - resolved_retained_ratio,
	}
	# 灰市遗失快照；在背包所有权完成结算后发送，监听方只能读取资源与数量，不会重新取得库存记录。
	combat_failure_losses_recorded.emit(lost_entries.duplicate(true))
	_queue_save_inventory()
	inventory_changed.emit()
	run_state_changed.emit()
	return _last_run_outcome.duplicate(true)


func get_last_run_outcome() -> Dictionary:
	return _last_run_outcome.duplicate(true)


func get_warehouse_resources() -> Array[Resource]:
	# 永久仓库资源结果；元素与仓库记录顺序一致，返回副本防止外部直接修改所有权数据。
	var result: Array[Resource] = []
	# 永久仓库记录；取值为全部局外安全物品，用于提取运行时武器资源。
	for record in _warehouse_records:
		# 仓库物品资源；取值应为 Resource，异常记录不会暴露给外部组件。
		var item_resource: Resource = record.get("resource") as Resource
		if item_resource != null:
			result.append(item_resource)
	return result


func get_warehouse_entries() -> Array[Dictionary]:
	# 永久仓库展示条目；每项暴露资源、获得时间与上次撤离标记，UI 只能通过公开接口调整。
	var result: Array[Dictionary] = []
	# 仓库记录；取值按上次撤离优先、获得时间倒序排列，用于建立局外物品列表。
	for record in _warehouse_records:
		# 仓库条目资源；取值应为 Resource，资源恢复失败的异常记录不会生成交互控件。
		var item_resource: Resource = record.get("resource") as Resource
		if item_resource == null:
			continue
		result.append({
			"record_id": str(record.get("record_id", "")),
			"resource": item_resource,
			"quantity": int(record.get("quantity", 1)),
			"acquired_at": float(record.get("acquired_at", 0.0)),
			"is_last_extraction": _last_extraction_epoch > 0 and int(record.get("last_extraction_epoch", 0)) == _last_extraction_epoch,
		})
	return result


func get_warehouse_count() -> int:
	return _warehouse_records.size()


func get_coins() -> int:
	return _coins


func is_resource_discovered(item_resource: Resource) -> bool:
	## 查询静态物品模板是否已在图鉴中发现；只读取稳定类型与 ID，不比较运行时强化、耐久或资源实例身份。
	# 图鉴稳定键；空键表示资源没有可持久化的物品标识，不能被图鉴错误解锁。
	var discovery_key: String = _get_encyclopedia_discovery_key(item_resource)
	return not discovery_key.is_empty() and _discovered_encyclopedia_entries.has(discovery_key)


func is_enhancement_stone_discovered() -> bool:
	## 查询随机强化石类别是否已发现；任意实际获得的强化石都会永久解锁同一个通用资源条目。
	return _discovered_encyclopedia_entries.has(ENHANCEMENT_STONE_DISCOVERY_KEY)


func get_stock_holdings() -> Dictionary:
	return _stock_holdings.duplicate(true)


func get_stock_holding(stock_id: String) -> Dictionary:
	# 指定股票持仓；返回副本，外部只能通过买卖接口修改真实数量和成本。
	var holding: Dictionary = _stock_holdings.get(stock_id, {}) as Dictionary
	return holding.duplicate(true)


func spend_coins(amount: int) -> bool:
	## 精确扣除指定整数金币；余额不足时保持原值并返回 false，供跨系统兑换执行原子付款校验。
	if amount <= 0 or _coins < amount:
		return false
	_coins -= amount
	_queue_save_inventory()
	coins_changed.emit()
	return true


func add_stock_holding_without_currency(stock_id: String, quantity: int, transaction_unit_cost: float) -> bool:
	## 增加股票持仓但不处理任何货币；调用方必须先完成自身资产扣款，并传入本次含费每股成本。
	if stock_id.is_empty() or quantity <= 0 or transaction_unit_cost <= 0.0:
		return false
	# 原持仓；缺失时按零数量、零成本初始化，股票标识合法性由股市服务负责校验。
	var holding: Dictionary = _stock_holdings.get(stock_id, {"quantity": 0, "average_cost": 0.0}) as Dictionary
	# 原持仓数量；异常负数在合并前归零，防止损坏存档影响新交易。
	var old_quantity: int = maxi(int(holding.get("quantity", 0)), 0)
	# 原持仓成本；单位为每股证券币，异常负值在合并前归零。
	var old_average_cost: float = maxf(float(holding.get("average_cost", 0.0)), 0.0)
	# 新持仓数量；股票不受普通物品单组 99 个的堆叠上限影响。
	var new_quantity: int = old_quantity + quantity
	# 新加权平均成本；按旧持仓总成本和本次含费支出合并，保留证券币小数精度。
	var new_average_cost: float = (old_average_cost * old_quantity + transaction_unit_cost * quantity) / float(new_quantity)
	_stock_holdings[stock_id] = {"quantity": new_quantity, "average_cost": new_average_cost}
	_queue_stock_trade_save()
	stock_holdings_changed.emit()
	return true


func remove_stock_holding_without_currency(stock_id: String, quantity: int) -> bool:
	## 减少股票持仓但不发放任何货币；持仓不足时保持原值并返回 false，供股市服务原子结算。
	if stock_id.is_empty() or quantity <= 0:
		return false
	# 当前持仓；必须仍有足量股票，防止弹窗展示期间的连续操作造成超额卖出。
	var holding: Dictionary = _stock_holdings.get(stock_id, {}) as Dictionary
	# 当前持仓数量；异常负数按零处理，不允许参与卖出。
	var current_quantity: int = maxi(int(holding.get("quantity", 0)), 0)
	if current_quantity < quantity:
		return false
	# 剩余持仓数量；全部卖出时移除记录，部分卖出继续保留原加权平均成本。
	var remaining_quantity: int = current_quantity - quantity
	if remaining_quantity <= 0:
		_stock_holdings.erase(stock_id)
	else:
		holding["quantity"] = remaining_quantity
		_stock_holdings[stock_id] = holding
	_queue_stock_trade_save()
	stock_holdings_changed.emit()
	return true


func buy_stock_holding(stock_id: String, quantity: int, unit_price: int, total_cost: int) -> bool:
	if stock_id.is_empty() or quantity <= 0 or unit_price <= 0 or total_cost <= 0 or _coins < total_cost:
		return false
	# 原持仓；缺失时按零数量、零成本初始化，旧存档无需预先写入五只空记录。
	var holding: Dictionary = _stock_holdings.get(stock_id, {"quantity": 0, "average_cost": 0.0}) as Dictionary
	# 原持仓数量；取值至少为 0，异常负数会在交易前归零。
	var old_quantity: int = maxi(int(holding.get("quantity", 0)), 0)
	# 原持仓成本；取值为每股加权平均实际买入价格，异常负值会归零。
	var old_average_cost: float = maxf(float(holding.get("average_cost", 0.0)), 0.0)
	# 新持仓数量；买入数量直接累加，股票不受物品堆叠上限影响。
	var new_quantity: int = old_quantity + quantity
	# 本次含费每股成本；手续费计入持仓成本，保证浮动盈亏反映真实买入支出。
	var transaction_unit_cost: float = float(total_cost) / float(quantity)
	# 新加权平均成本；按原持仓总成本与本次实际支出合并计算。
	var new_average_cost: float = (old_average_cost * old_quantity + transaction_unit_cost * quantity) / float(new_quantity)
	_coins -= total_cost
	_stock_holdings[stock_id] = {"quantity": new_quantity, "average_cost": new_average_cost}
	_queue_stock_trade_save()
	coins_changed.emit()
	stock_holdings_changed.emit()
	return true


func sell_stock_holding(stock_id: String, quantity: int, proceeds: int) -> bool:
	if stock_id.is_empty() or quantity <= 0 or proceeds <= 0:
		return false
	# 当前持仓；卖出必须由稳定股票标识找到足量持仓，UI 预览过期时会在此重新校验。
	var holding: Dictionary = _stock_holdings.get(stock_id, {}) as Dictionary
	# 当前持仓数量；取值至少为 0，用于限制本次卖出数量。
	var current_quantity: int = maxi(int(holding.get("quantity", 0)), 0)
	if current_quantity < quantity:
		return false
	# 剩余数量；全部卖出时移除空记录，部分卖出继续保留原加权平均成本。
	var remaining_quantity: int = current_quantity - quantity
	_coins += proceeds
	if remaining_quantity <= 0:
		_stock_holdings.erase(stock_id)
	else:
		holding["quantity"] = remaining_quantity
		_stock_holdings[stock_id] = holding
	_queue_stock_trade_save()
	coins_changed.emit()
	stock_holdings_changed.emit()
	return true


func clear_stock_holdings() -> int:
	# 清空前总股数；用于开发者菜单反馈，不返还任何金币。
	var cleared_quantity: int = 0
	for raw_holding in _stock_holdings.values():
		if raw_holding is Dictionary:
			cleared_quantity += maxi(int((raw_holding as Dictionary).get("quantity", 0)), 0)
	_stock_holdings.clear()
	_queue_stock_trade_save()
	stock_holdings_changed.emit()
	return cleared_quantity


func _queue_stock_trade_save() -> void:
	if _stock_trade_save_queued:
		return
	_stock_trade_save_queued = true
	# 合并计时器；暂停与局外界面中仍继续计时，确保确认弹窗连续交易不会逐笔写盘。
	var save_timer: SceneTreeTimer = get_tree().create_timer(maxf(stock_trade_save_delay_seconds, 0.05), true, false, true)
	save_timer.timeout.connect(_flush_queued_stock_trade_save, CONNECT_ONE_SHOT)


func _flush_queued_stock_trade_save() -> void:
	_stock_trade_save_queued = false
	_queue_save_inventory()


func flush_stock_holdings_save() -> void:
	## 立即保存包含股票持仓的完整库存；用于跨股市存档交易完成后缩短两份资产状态的不一致窗口。
	_stock_trade_save_queued = false
	_save_queued = false
	_save_inventory()


func get_combat_shipped_value() -> int:
	# 已送回价值仅在当前战斗内累计，返回值限制在合法范围以兼容旧运行状态。
	return clampi(_combat_shipped_value, 0, COMBAT_SHIPPING_VALUE_LIMIT)


func get_combat_shipping_remaining_value() -> int:
	# 剩余送回价值；所有物资撤离点共用同一单局额度，关闭或重新打开面板不会恢复。
	return maxi(COMBAT_SHIPPING_VALUE_LIMIT - get_combat_shipped_value(), 0)


func get_combat_carried_value_summary() -> Dictionary:
	# 当前随身总价值；包含背包和全部装备槽，供成功撤离前统计带出价值。
	var total_value: int = 0
	# 当前随身武器价值；只包含具有 weapon_id 的近战和远程武器。
	var weapon_value: int = 0
	for record in _get_all_owned_records():
		# 随身物品资源；异常空记录不计入撤离价值。
		var item_resource: Resource = record.get("resource") as Resource
		if item_resource == null:
			continue
		# 随身物品数量；武器和装备通常为 1，堆叠资源按实际数量累计。
		var quantity: int = maxi(int(record.get("quantity", 1)), 1)
		# 随身物品总价值；使用库存统一有效价值，耐久和强化状态会自然反映在结果中。
		var record_value: int = _get_resource_value(item_resource) * quantity
		total_value += record_value
		if _is_weapon_resource(item_resource):
			weapon_value += record_value
	return {"total_value": total_value, "weapon_value": weapon_value}


func get_combat_shipping_quote(item_resource: Resource, source_location: String, requested_quantity: int = 1) -> Dictionary:
	# 默认报价；调用方可统一读取 selectable、value、fee 和 message，不需要对空资源单独判空。
	var quote: Dictionary = {"selectable": false, "value": 0, "fee": 0, "quantity": 0, "message": "物品不可送回"}
	if not _run_active or item_resource == null or requested_quantity <= 0:
		return quote
	# 可送回数量；背包资源可按堆叠数量选择，装备槽只允许整件武器。
	var available_quantity: int = get_storage_resource_quantity(item_resource, source_location) if _is_storage_location(source_location) else (1 if get_equipment_location_resource(source_location) == item_resource else 0)
	if available_quantity <= 0:
		quote["message"] = "物品已不在原位置"
		return quote
	# 实际报价数量；旧弹窗确认后数量变化时限制到当前仍持有的数量。
	var shipping_quantity: int = clampi(requested_quantity, 1, available_quantity)
	# 送回价值；按物品当前有效单价乘数量累计到单局 1000 金币上限。
	var shipping_value: int = _get_resource_value(item_resource) * shipping_quantity
	# 运费；按总价值的 20% 向上取整，零价值物品运费保持 0。
	var shipping_fee: int = ceili(float(shipping_value) * COMBAT_SHIPPING_FEE_RATIO) if shipping_value > 0 else 0
	quote["value"] = shipping_value
	quote["fee"] = shipping_fee
	quote["quantity"] = shipping_quantity
	if shipping_value > get_combat_shipping_remaining_value():
		quote["message"] = "超过本局剩余送回价值"
		return quote
	if _coins < shipping_fee:
		quote["message"] = "金币不足，无法支付运费"
		return quote
	quote["selectable"] = true
	quote["message"] = "可以送回仓库"
	return quote


func ship_combat_resource_to_warehouse(item_resource: Resource, source_location: String, requested_quantity: int = 1) -> Dictionary:
	# 执行前报价；同一接口完成数量、额度和金币复核，避免 UI 预览状态过期后产生负数或超额送回。
	var quote: Dictionary = get_combat_shipping_quote(item_resource, source_location, requested_quantity)
	if not bool(quote.get("selectable", false)):
		return {"success": false, "message": str(quote.get("message", "无法送回仓库"))}
	# 实际送回数量；已经由报价限制到当前所有权范围。
	var shipping_quantity: int = int(quote.get("quantity", 1))
	# 待移动记录；背包支持拆分堆叠，装备槽只会返回完整武器记录。
	var moving_record: Dictionary = {}
	if _is_storage_location(source_location):
		# 来源记录下标；物品必须仍位于背包，仓库物品不允许重复送回仓库。
		if source_location != STORAGE_LOCATION_BACKPACK:
			return {"success": false, "message": "只有背包和装备栏物品可以送回"}
		# 背包来源下标；通过资源实例定位，避免重复物品送回错误记录。
		var source_index: int = _find_storage_record_index(source_location, item_resource)
		if source_index < 0 or source_index >= _backpack_records.size():
			return {"success": false, "message": "物品已不在背包中"}
		# 来源记录；整组直接移动，部分堆叠复制独立资源并保留原记录元数据。
		var source_record: Dictionary = _backpack_records[source_index]
		# 当前背包数量；限制在合法堆叠范围，武器固定为 1。
		var stored_quantity: int = clampi(int(source_record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
		if shipping_quantity >= stored_quantity:
			moving_record = source_record
			_backpack_records.remove_at(source_index)
		else:
			# 部分送回资源副本；目标仓库必须持有独立实例，后续消费和存档不会影响背包余量。
			var moving_resource: Resource = item_resource.duplicate(true) as Resource
			if moving_resource == null:
				return {"success": false, "message": "无法拆分该物品堆叠"}
			moving_record = _create_record(moving_resource, float(source_record.get("acquired_at", -1.0)))
			moving_record["last_extraction_epoch"] = int(source_record.get("last_extraction_epoch", 0))
			moving_record["quantity"] = shipping_quantity
			# 本局来源移动数量；相同堆叠单位无属性差异，部分送回时优先把本局来源单位计入安全仓库。
			var shipped_run_gained_quantity: int = mini(int(source_record.get("run_gained_quantity", 0)), shipping_quantity)
			moving_record["run_gained_quantity"] = shipped_run_gained_quantity
			source_record["run_gained_quantity"] = maxi(int(source_record.get("run_gained_quantity", 0)) - shipped_run_gained_quantity, 0)
			source_record["quantity"] = stored_quantity - shipping_quantity
	else:
		moving_record = _take_equipment_record(source_location)
		if moving_record.is_empty():
			return {"success": false, "message": "装备槽物品已发生变化"}
	_insert_record_with_stack_merge(_warehouse_records, moving_record)
	# 实际费用与额度；所有权移动成功后同步扣费和累计，随后只排队一次存档。
	var shipping_fee: int = int(quote.get("fee", 0))
	# 实际送回价值；累计到当前战斗的 1000 金币总上限。
	var shipping_value: int = int(quote.get("value", 0))
	_coins = maxi(_coins - shipping_fee, 0)
	_combat_shipped_value = clampi(_combat_shipped_value + shipping_value, 0, COMBAT_SHIPPING_VALUE_LIMIT)
	# 股市统计服务；物资送回只上报实际成功结算的价值和强化石数量。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_method("record_run_metric"):
		stock_market_service.call("record_run_metric", "shipped_value", shipping_value)
		if str(item_resource.get("item_kind")) == "enhancement_stone":
			stock_market_service.call("record_run_metric", "shipped_enhancement_stones", shipping_quantity)
	_refresh_current_ranged_slot_after_equipment_change()
	# 物资撤离已经把所有权转入永久仓库；即使正式战斗仍在进行也立即落盘，保证安全送回结果不会等待最终结算。
	_queue_save_inventory(true)
	inventory_changed.emit()
	equipment_changed.emit()
	warehouse_changed.emit()
	coins_changed.emit()
	return {"success": true, "message": "物品已送回仓库", "value": shipping_value, "fee": shipping_fee, "quantity": shipping_quantity}


func adjust_coins(amount: int) -> int:
	# 调整后金币；取值至少为 0，开发者减少金币时不会形成负数余额。
	var adjusted_coins: int = maxi(_coins + amount, 0)
	if adjusted_coins == _coins:
		return _coins
	_coins = adjusted_coins
	_queue_save_inventory()
	coins_changed.emit()
	return _coins


func set_coins(amount: int) -> int:
	## 直接设置局外金币余额；开发者数值工具使用该原子接口，负数统一限制为 0，并立即触发存档与界面刷新。
	var resolved_coins: int = maxi(amount, 0)
	if resolved_coins == _coins:
		return _coins
	_coins = resolved_coins
	_queue_save_inventory()
	coins_changed.emit()
	return _coins


func purchase_resource_to_warehouse(item_resource: Resource, purchase_price: int, quantity: int = 1) -> bool:
	if item_resource == null or purchase_price < 0 or quantity <= 0 or _coins < purchase_price:
		return false
	# 实际购买数量；武器固定为一件，可堆叠资源限制在单组上限以内，防止商店异常数据写入超大堆叠。
	var resolved_quantity: int = 1 if _is_weapon_resource(item_resource) else clampi(quantity, 1, MAX_STACK_QUANTITY)
	# 新增仓库记录；商店资源已经是独立实例，直接转交所有权并允许强化石按签名合并。
	var purchased_record: Dictionary = _create_record(item_resource)
	purchased_record["quantity"] = resolved_quantity
	_coins -= purchase_price
	_insert_record_with_stack_merge(_warehouse_records, purchased_record)
	_queue_save_inventory()
	warehouse_changed.emit()
	coins_changed.emit()
	return true


func add_storage_resource(item_resource: Resource, target_location: String, quantity: int = 1) -> bool:
	if item_resource == null or not _is_storage_location(target_location) or quantity <= 0:
		return false
	# 新增记录；锻造升阶等局外系统通过统一接口取得所有权，资源堆叠继续遵守签名和单组 99 上限。
	var added_record: Dictionary = _create_record(item_resource)
	added_record["quantity"] = 1 if _is_weapon_resource(item_resource) else clampi(quantity, 1, MAX_STACK_QUANTITY)
	_insert_record_with_stack_merge(_get_storage_records(target_location), added_record)
	_queue_save_inventory()
	_emit_storage_changed(target_location)
	return true


func has_storage_resource_quantity(item_resource: Resource, source_location: String, requested_quantity: int = 1) -> bool:
	if requested_quantity <= 0:
		return false
	return get_storage_resource_quantity(item_resource, source_location) >= requested_quantity


func has_owned_resource_quantity(item_resource: Resource, source_location: String, requested_quantity: int = 1) -> bool:
	# 请求数量；背包与仓库支持堆叠，装备栏固定只能持有一件物品，因此所有来源都要求正整数数量。
	if item_resource == null or requested_quantity <= 0:
		return false
	# 存储来源；复用现有数量接口，确保强化石堆叠和普通物品数量规则保持一致。
	if _is_storage_location(source_location):
		return has_storage_resource_quantity(item_resource, source_location, requested_quantity)
	# 装备栏来源；装备槽只能匹配当前资源实例并提供一件所有权。
	return requested_quantity == 1 and get_equipment_location_resource(source_location) == item_resource


func consume_storage_resource_quantity(item_resource: Resource, source_location: String, requested_quantity: int = 1) -> bool:
	if item_resource == null or requested_quantity <= 0:
		return false
	# 消耗来源记录；只允许锻造等局外系统消费仓库或背包中的真实所有权记录。
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	# 消耗记录下标；通过资源实例身份定位，避免同名武器或同类强化石被误删。
	var record_index: int = _find_storage_record_index(source_location, item_resource)
	if record_index < 0 or record_index >= source_records.size():
		return false
	# 当前持有数量；武器固定为一，资源堆叠按记录数量读取。
	var stored_quantity: int = maxi(int(source_records[record_index].get("quantity", 1)), 1)
	if stored_quantity < requested_quantity:
		return false
	# 剩余数量；仍有余量时保留原资源实例，全部消耗时移除完整记录。
	var remaining_quantity: int = stored_quantity - requested_quantity
	if remaining_quantity > 0:
		source_records[record_index]["quantity"] = remaining_quantity
		# 剩余本局来源数量；同类堆叠不可区分具体单位，消费时优先扣除本局来源并限制到剩余总量。
		var remaining_run_gained_quantity: int = maxi(int(source_records[record_index].get("run_gained_quantity", 0)) - requested_quantity, 0)
		source_records[record_index]["run_gained_quantity"] = mini(remaining_run_gained_quantity, remaining_quantity)
	else:
		source_records.remove_at(record_index)
	_queue_save_inventory()
	_emit_storage_changed(source_location)
	return true


func consume_owned_resource_quantity(item_resource: Resource, source_location: String, requested_quantity: int = 1) -> bool:
	# 存储来源；仓库与背包继续通过堆叠安全接口扣除指定数量。
	if _is_storage_location(source_location):
		return consume_storage_resource_quantity(item_resource, source_location, requested_quantity)
	# 装备栏来源；槽位始终只有一件物品，异常数量或资源已更换时拒绝消费。
	if item_resource == null or requested_quantity != 1 or get_equipment_location_resource(source_location) != item_resource:
		return false
	# 装备记录；仅在全部校验通过后取出，避免锻造预览过期时误删其他装备。
	var consumed_record: Dictionary = _take_equipment_record(source_location)
	if consumed_record.is_empty():
		return false
	_refresh_current_ranged_slot_after_equipment_change()
	_queue_save_inventory()
	equipment_changed.emit()
	return true


func serialize_item_snapshot(item_resource: Resource, quantity: int = 1) -> Dictionary:
	if item_resource == null:
		return {}
	# 临时快照记录；不进入任何库存容器，仅复用稳定存档格式保存商店与灰市物品的运行时状态。
	var snapshot_record: Dictionary = {
		"record_id": "",
		"resource": item_resource,
		"quantity": clampi(quantity, 1, MAX_STACK_QUANTITY),
		"acquired_at": 0.0,
		"acquisition_sequence": 0,
		"last_extraction_epoch": 0,
	}
	return _serialize_record(snapshot_record)


func deserialize_item_snapshot(serialized_snapshot: Dictionary) -> Dictionary:
	if serialized_snapshot.is_empty():
		return {}
	# 原获得序号；商店读取临时物品不应改变玩家库存的真实获得顺序，因此反序列化后立即恢复。
	var original_acquisition_sequence: int = _acquisition_sequence
	# 临时恢复记录；使用库存兼容加载器恢复武器强化、耐久或强化石品质与词条。
	var restored_record: Dictionary = _deserialize_record(serialized_snapshot, false)
	_acquisition_sequence = original_acquisition_sequence
	if restored_record.is_empty():
		return {}
	return {
		"resource": restored_record.get("resource") as Resource,
		"quantity": clampi(int(restored_record.get("quantity", 1)), 1, MAX_STACK_QUANTITY),
	}


func clear_warehouse_items() -> int:
	# 清空前记录组数；返回值用于开发者菜单提供明确反馈，强化石堆叠按一组统计。
	var cleared_record_count: int = _warehouse_records.size()
	if cleared_record_count <= 0:
		return 0
	_warehouse_records.clear()
	_queue_save_inventory()
	warehouse_changed.emit()
	return cleared_record_count


func grant_all_known_weapons_to_warehouse() -> int:
	# 实际发放数量；默认从 0 累加，只统计成功加载并写入永久仓库的武器资源。
	var granted_count: int = 0
	# 已知武器标识；取值来自稳定资源路径表，每次调用都会为每种武器创建独立实例。
	for weapon_id in _get_registered_resource_paths("weapon").keys():
		# 开发者发放资源；取值为模板深拷贝，加载失败的条目不会影响其他武器发放。
		var item_resource: Resource = _load_weapon_resource(str(weapon_id))
		if item_resource == null:
			continue
		_warehouse_records.append(_create_record(item_resource))
		granted_count += 1
	if granted_count <= 0:
		return 0
	_queue_save_inventory()
	warehouse_changed.emit()
	return granted_count


func grant_all_known_equipment_to_warehouse() -> int:
	# 发放数量；每种已知装备各深拷贝一件进入永久仓库。
	var granted_count: int = 0
	for equipment_id in _get_registered_resource_paths("equipment").keys():
		var equipment_resource: Resource = _load_equipment_resource(str(equipment_id))
		if equipment_resource == null:
			continue
		_insert_record_with_stack_merge(_warehouse_records, _create_record(equipment_resource))
		granted_count += 1
	if granted_count > 0:
		_queue_save_inventory()
		warehouse_changed.emit()
	return granted_count


func grant_random_enhancement_stones_to_warehouse(stone_count: int = DEVELOPER_STONE_GRANT_COUNT) -> int:
	# 实际发放数量；限制为非负数，每颗独立随机并按词条方向自动合并到永久仓库堆叠。
	var granted_count: int = 0
	# 请求数量；开发者菜单默认 10，外部调试调用可传入其他非负数量。
	var resolved_stone_count: int = maxi(stone_count, 0)
	for _stone_index in range(resolved_stone_count):
		# 随机强化石；使用与战斗掉落相同的词条数量、削弱概率和价值规则。
		var enhancement_stone: EnhancementStoneData = EnhancementStoneData.create_random(
			_random,
			DEVELOPER_STONE_MIN_MODIFIER_COUNT,
			DEVELOPER_STONE_MAX_MODIFIER_COUNT,
			DEVELOPER_STONE_DETRIMENTAL_CHANCE,
			DEVELOPER_STONE_BASE_SELL_PRICE
		)
		if enhancement_stone == null:
			continue
		_insert_record_with_stack_merge(_warehouse_records, _create_record(enhancement_stone))
		granted_count += 1
	if granted_count <= 0:
		return 0
	_queue_save_inventory()
	warehouse_changed.emit()
	return granted_count


func grant_custom_enhancement_stone_to_warehouse(quality_id: String, target_kind: String, beneficial_stat_name_one: String, beneficial_stat_name_two: String = "", detrimental_stat_name: String = "") -> bool:
	## 向永久仓库发放一颗开发者自定义强化石；品质与词条方向由调用方选择，但创建、堆叠和存档仍共用正式强化石协议。
	# 自定义强化石；无第一条合法加强词条时创建会返回空，库存不保存任何无效资源。
	var enhancement_stone: EnhancementStoneData = EnhancementStoneData.create_custom(quality_id, target_kind, beneficial_stat_name_one, beneficial_stat_name_two, detrimental_stat_name, DEVELOPER_STONE_BASE_SELL_PRICE)
	if enhancement_stone == null:
		return false
	_insert_record_with_stack_merge(_warehouse_records, _create_record(enhancement_stone))
	_queue_save_inventory()
	warehouse_changed.emit()
	return true


func grant_random_enhancement_stones_to_warehouse_gradually(stone_count: int, batch_size: int = 25) -> int:
	## 按帧分批向永久仓库生成随机强化石；全部完成后只保存并派发一次仓库变化，避免大量 UI 重建。
	# 实际发放数量；每颗成功创建并插入仓库后加一。
	var granted_count: int = 0
	# 请求数量；负数按 0 处理，上限由调用方开发者菜单限制为 1000。
	var resolved_stone_count: int = maxi(stone_count, 0)
	# 每帧生成数量；最低为 1，默认 25 平衡完成速度与单帧开销。
	var resolved_batch_size: int = maxi(batch_size, 1)
	for stone_index in range(resolved_stone_count):
		# 随机强化石；与战斗掉落、商店和同步开发者入口共用正式品质与词条生成器。
		var enhancement_stone: EnhancementStoneData = EnhancementStoneData.create_random(
			_random,
			DEVELOPER_STONE_MIN_MODIFIER_COUNT,
			DEVELOPER_STONE_MAX_MODIFIER_COUNT,
			DEVELOPER_STONE_DETRIMENTAL_CHANCE,
			DEVELOPER_STONE_BASE_SELL_PRICE
		)
		if enhancement_stone != null:
			_insert_record_with_stack_merge(_warehouse_records, _create_record(enhancement_stone))
			granted_count += 1
		# 批次边界；最后一颗无需额外等待，其他批次让出一帧缓解主线程卡顿。
		if (stone_index + 1) % resolved_batch_size == 0 and stone_index + 1 < resolved_stone_count:
			await get_tree().process_frame
	if granted_count <= 0:
		return 0
	_queue_save_inventory()
	warehouse_changed.emit()
	return granted_count


func grant_all_repair_kits_to_warehouse() -> int:
	## 兼容旧方法名并发放内容目录当前全部道具；修复包与消耗品都按各自稳定堆叠签名合并。
	# 实际发放数量；每种已注册道具各发放一件，空资源或武器装备误项安全跳过。
	var granted_count: int = 0
	# 道具标识；来自 ContentCatalog 通用 item 索引，新增合法道具不需要再补硬编码路径表。
	for item_id in _get_registered_resource_paths("item").keys():
		# 道具资源；从模板深拷贝，避免开发者发放内容引用项目资源本体。
		var item_resource: Resource = _load_item_resource(str(item_id))
		if item_resource == null or str(item_resource.get("item_kind")) in ["", "weapon", "equipment"]:
			continue
		_insert_record_with_stack_merge(_warehouse_records, _create_record(item_resource))
		granted_count += 1
	if granted_count <= 0:
		return 0
	_queue_save_inventory()
	warehouse_changed.emit()
	return granted_count


func transfer_warehouse_to_backpack(item_resource: Resource, target_index: int = -1) -> bool:
	# 永久仓库来源索引；取值为有效下标时才允许把安全物品转为下一局随身物品。
	var warehouse_index: int = _find_warehouse_record_index(item_resource)
	if warehouse_index < 0:
		return false

	# 待转移记录；保持原记录编号和获得时间，避免跨容器移动被误判为新拾取物品。
	var moving_record: Dictionary = _warehouse_records[warehouse_index]
	_warehouse_records.remove_at(warehouse_index)
	_insert_record_with_stack_merge(_backpack_records, moving_record, target_index)
	_queue_save_inventory()
	warehouse_changed.emit()
	inventory_changed.emit()
	return true


func transfer_backpack_to_warehouse(item_resource: Resource, target_index: int = -1) -> bool:
	# 随身背包来源索引；取值为有效下标时才允许把物品转入永久安全仓库。
	var backpack_index: int = _find_backpack_record_index(item_resource)
	if backpack_index < 0:
		return false

	# 待转移记录；直接移动所有权记录，确保死亡结算只处理转移后仍留在背包的物品。
	var moving_record: Dictionary = _backpack_records[backpack_index]
	_backpack_records.remove_at(backpack_index)
	_insert_record_with_stack_merge(_warehouse_records, moving_record, target_index)
	_queue_save_inventory()
	warehouse_changed.emit()
	inventory_changed.emit()
	return true


func transfer_storage_resource_quantity(item_resource: Resource, source_location: String, target_location: String, requested_quantity: int, target_index: int = -1) -> bool:
	if item_resource == null or requested_quantity <= 0 or source_location == target_location:
		return false
	if not _is_storage_location(source_location) or not _is_storage_location(target_location):
		return false
	# 来源记录下标；使用资源实例和来源容器精确定位，避免同类堆叠之间发生错误拆分。
	var source_record_index: int = _find_storage_record_index(source_location, item_resource)
	# 来源记录数组；只接受仓库或随身背包，非法位置会在前置校验中直接拒绝。
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	if source_record_index < 0 or source_record_index >= source_records.size():
		return false
	# 来源记录；部分移动时保留原资源实例并减少数量，整组移动继续复用原有转移接口。
	var source_record: Dictionary = source_records[source_record_index]
	# 当前堆叠数量；所有可堆叠资源限制为 1 到 99，异常旧数据在此标准化。
	var stored_quantity: int = clampi(int(source_record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
	# 实际移动数量；弹窗打开后若库存数量发生变化，会安全限制到当前仍持有的数量。
	var transfer_quantity: int = clampi(requested_quantity, 1, stored_quantity)
	if transfer_quantity >= stored_quantity:
		return transfer_warehouse_to_backpack(item_resource, target_index) if source_location == STORAGE_LOCATION_WAREHOUSE else transfer_backpack_to_warehouse(item_resource, target_index)
	if not _is_stackable_resource(item_resource):
		return false

	# 拆分资源实例；来源和目标必须拥有独立资源引用，确保后续按实例定位、消费和存档互不干扰。
	var moving_resource: Resource = item_resource.duplicate(true) as Resource
	if moving_resource == null:
		return false
	# 拆分记录；保留原获得时间与撤离标记，但使用新的唯一记录编号表示新形成的目标堆叠。
	var moving_record: Dictionary = _create_record(moving_resource, float(source_record.get("acquired_at", -1.0)))
	moving_record["last_extraction_epoch"] = int(source_record.get("last_extraction_epoch", 0))
	moving_record["quantity"] = transfer_quantity
	# 本局来源移动数量；跨背包与仓库拆分时随记录转移，避免安全送回后结算遗漏本局所得。
	var transferred_run_gained_quantity: int = mini(int(source_record.get("run_gained_quantity", 0)), transfer_quantity)
	moving_record["run_gained_quantity"] = transferred_run_gained_quantity
	source_record["run_gained_quantity"] = maxi(int(source_record.get("run_gained_quantity", 0)) - transferred_run_gained_quantity, 0)
	source_record["quantity"] = stored_quantity - transfer_quantity
	# 目标记录数组；插入时会优先合并相同签名堆叠，超过单组上限的剩余数量自动形成新记录。
	var target_records: Array[Dictionary] = _get_storage_records(target_location)
	_insert_record_with_stack_merge(target_records, moving_record, target_index)
	_queue_save_inventory()
	_emit_storage_changed(source_location)
	_emit_storage_changed(target_location)
	return true


func move_warehouse_item(source_index: int, target_index: int) -> bool:
	if source_index < 0 or source_index >= _warehouse_records.size() or target_index < 0 or target_index > _warehouse_records.size():
		return false
	if source_index == target_index or target_index == source_index + 1:
		return true

	# 仓库移动记录；从原位置移除后按插入语义调整目标下标，支持列表内拖拽排序。
	var moved_record: Dictionary = _warehouse_records[source_index]
	_warehouse_records.remove_at(source_index)
	# 修正仓库插入索引；目标位于来源之后时减一，避免移除来源造成一位偏移。
	var insert_index: int = target_index - 1 if target_index > source_index else target_index
	_warehouse_records.insert(clampi(insert_index, 0, _warehouse_records.size()), moved_record)
	_queue_save_inventory()
	warehouse_changed.emit()
	return true


func sell_warehouse_resource(item_resource: Resource) -> bool:
	return sell_storage_resource(item_resource, STORAGE_LOCATION_WAREHOUSE)


func sell_storage_resource(item_resource: Resource, source_location: String) -> bool:
	# 整组出售数量；兼容原公开接口，内部统一转发到可指定数量的原子出售能力。
	var stored_quantity: int = get_storage_resource_quantity(item_resource, source_location)
	return sell_storage_resource_quantity(item_resource, source_location, stored_quantity)


func sell_storage_resource_quantity(item_resource: Resource, source_location: String, requested_quantity: int) -> bool:
	if requested_quantity <= 0:
		return false
	# 出售来源记录数组；局外仓库界面允许出售永久仓库或已展开的随身背包物品。
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	# 待出售索引；使用资源实例身份精确定位重复武器或强化石堆叠。
	var record_index: int = _find_storage_record_index(source_location, item_resource)
	if record_index < 0 or record_index >= source_records.size():
		return false
	# 待出售记录；强化石出售整组，武器数量固定为 1。
	var stored_record: Dictionary = source_records[record_index]
	# 当前库存数量；武器固定为 1，强化石堆叠限制在 1 到 99。
	var stored_quantity: int = maxi(int(stored_record.get("quantity", 1)), 1)
	# 实际出售数量；请求值限制在当前库存范围，避免旧弹窗确认后物品数量变化造成负数。
	var sell_quantity: int = clampi(requested_quantity, 1, stored_quantity)
	# 单件价值；武器使用强化后动态价值，强化石使用资源基础价值。
	var unit_value: int = _get_resource_value(item_resource)
	# 出售所得；堆叠资源以单件价值乘以当前数量。
	var total_value: int = unit_value * sell_quantity
	if total_value <= 0:
		return false

	# 剩余数量；部分出售时保留原记录与资源实例，全部出售时移除整条所有权记录。
	var remaining_quantity: int = stored_quantity - sell_quantity
	if remaining_quantity > 0:
		stored_record["quantity"] = remaining_quantity
	else:
		source_records.remove_at(record_index)
	_coins += total_value
	_queue_save_inventory()
	_emit_storage_changed(source_location)
	coins_changed.emit()
	return true


func get_storage_resource_quantity(item_resource: Resource, source_location: String) -> int:
	# 来源记录；使用资源实例身份定位，返回 0 表示物品已经移动、消费或出售。
	var record_index: int = _find_storage_record_index(source_location, item_resource)
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	if record_index < 0 or record_index >= source_records.size():
		return 0
	return maxi(int(source_records[record_index].get("quantity", 1)), 1)


func get_storage_resource_value(item_resource: Resource, source_location: String) -> int:
	# 来源记录；不存在时返回 0，防止 UI 对已经移动的旧引用显示可出售价值。
	var record_index: int = _find_storage_record_index(source_location, item_resource)
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	if record_index < 0 or record_index >= source_records.size():
		return 0
	return _get_resource_value(item_resource) * maxi(int(source_records[record_index].get("quantity", 1)), 1)


func use_enhancement_stone(stone_resource: Resource, source_location: String, weapon_resource: Resource) -> bool:
	return bool(use_enhancement_stone_with_result(stone_resource, source_location, weapon_resource).get("success", false))


func notify_weapon_runtime_state_changed(weapon_resource: Resource) -> void:
	if not _is_owned_weapon_resource(weapon_resource) or _durability_save_queued:
		return
	_durability_save_queued = true
	# 合并存档计时器；暂停场景树时仍继续计时，避免暂停后立即退出导致耐久状态长期停留在内存。
	var save_timer: SceneTreeTimer = get_tree().create_timer(maxf(durability_save_delay_seconds, 0.05), true, false, true)
	save_timer.timeout.connect(_flush_queued_durability_save, CONNECT_ONE_SHOT)


func _flush_queued_durability_save() -> void:
	_durability_save_queued = false
	_queue_save_inventory()


func use_enhancement_stone_with_result(stone_resource: Resource, source_location: String, weapon_resource: Resource) -> Dictionary:
	# 失败结果；任何校验失败都返回相同结构，调用方可以无需特判 null 即安全读取。
	var failed_result: Dictionary = {
		"success": false,
		"weapon": weapon_resource,
		"stone": stone_resource,
		"beneficial_changes": [],
		"detrimental_changes": [],
	}
	if not _is_enhancement_stone(stone_resource) or not (_is_weapon_resource(weapon_resource) or _is_equipment_resource(weapon_resource)):
		return failed_result
	if stone_resource.has_method("can_apply_to_weapon") and not bool(stone_resource.call("can_apply_to_weapon", weapon_resource)):
		return failed_result
	# 强化石来源索引；仅允许消费仓库或背包内仍由玩家持有的资源。
	var stone_record_index: int = _find_storage_record_index(source_location, stone_resource)
	# 强化石来源记录数组；非法位置返回空数组并拒绝消费。
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	if stone_record_index < 0 or stone_record_index >= source_records.size() or not _is_owned_weapon_resource(weapon_resource):
		return failed_result
	# 强化词条；优先读取强化石与目标实际拥有属性的交集，旧强化石资源回退归一化完整词条并由目标继续过滤。
	var modifiers: Dictionary = {}
	if stone_resource.has_method("get_applicable_modifiers_for_target"):
		modifiers = stone_resource.call("get_applicable_modifiers_for_target", weapon_resource) as Dictionary
	elif stone_resource.has_method("get_normalized_modifiers"):
		modifiers = stone_resource.call("get_normalized_modifiers") as Dictionary
	else:
		modifiers = EnhancementRules.normalize_modifiers(stone_resource.get("modifiers") as Dictionary)
	if modifiers.is_empty() or not weapon_resource.has_method("apply_enhancement"):
		return failed_result
	# 强化石品质；用于在使用瞬间选择对应的增强与削弱随机数值区间。
	var stone_quality_id: String = str(stone_resource.call("get_resolved_quality_id")) if stone_resource.has_method("get_resolved_quality_id") else str(stone_resource.get("quality_id"))
	# 本次实际强化词典；只为目标实际拥有的共有属性生成幅度，不兼容词条不会进入结果或影响目标。
	var rolled_modifiers: Dictionary = {}
	# 可强化属性遍历项；按规则目录稳定顺序生成本次实际比例，便于结果展示和测试复现。
	for stat_name in EnhancementRules.STAT_KEYS:
		if not modifiers.has(stat_name):
			continue
		# 本次词条实际比例；正负方向继承强化石，绝对值由品质区间随机生成。
		var rolled_modifier_ratio: float = EnhancementRules.roll_quality_modifier_ratio(_random, stone_quality_id, stat_name, modifiers.get(stat_name, 1))
		if not is_zero_approx(rolled_modifier_ratio):
			rolled_modifiers[stat_name] = rolled_modifier_ratio
	if rolled_modifiers.is_empty():
		return failed_result
	# 强化前价值；强化结果弹窗用它与强化后价值对比，数值由物品有效价值接口统一计算。
	var value_before: int = _get_resource_value(weapon_resource)
	# 武器强化结果；新资源返回完整变化明细，旧扩展资源仍可通过 bool 接口完成强化。
	var enhancement_result: Dictionary = failed_result.duplicate(true)
	if weapon_resource.has_method("apply_enhancement_with_result"):
		enhancement_result = weapon_resource.call("apply_enhancement_with_result", rolled_modifiers) as Dictionary
	else:
		enhancement_result["success"] = bool(weapon_resource.call("apply_enhancement", rolled_modifiers))
	if not bool(enhancement_result.get("success", false)):
		return failed_result
	enhancement_result["weapon"] = weapon_resource
	enhancement_result["stone"] = stone_resource
	enhancement_result["rolled_modifiers"] = rolled_modifiers
	enhancement_result["value_before"] = value_before
	enhancement_result["value_after"] = _get_resource_value(weapon_resource)

	# 强化石记录；成功应用后才扣除一颗，失败不会消耗材料。
	var stone_record: Dictionary = source_records[stone_record_index]
	# 剩余数量；大于 0 时保留原堆叠，等于 0 时移除整条记录。
	var remaining_quantity: int = maxi(int(stone_record.get("quantity", 1)) - 1, 0)
	if remaining_quantity > 0:
		stone_record["quantity"] = remaining_quantity
	else:
		source_records.remove_at(stone_record_index)
	_queue_save_inventory()
	_emit_storage_changed(source_location)
	equipment_changed.emit()
	return enhancement_result


func use_repair_kit_with_result(repair_kit_resource: Resource, source_location: String, weapon_resource: Resource) -> Dictionary:
	# 默认失败结果；调用方可直接读取成功状态、修复前后耐久和实际恢复量。
	var failed_result: Dictionary = {"success": false, "weapon": weapon_resource, "repair_kit": repair_kit_resource, "durability_before": 0.0, "durability_after": 0.0, "durability_restored": 0.0}
	if not _is_repair_kit(repair_kit_resource) or not (_is_weapon_resource(weapon_resource) or _is_equipment_resource(weapon_resource)) or not _is_storage_location(source_location):
		return failed_result
	# 修复包记录下标；必须仍在原仓库或背包中，避免 UI 的过期引用消耗错误物品。
	var repair_kit_record_index: int = _find_storage_record_index(source_location, repair_kit_resource)
	# 修复包来源记录；非法来源会返回空数组，因此必须先同时校验下标与武器所有权。
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	if repair_kit_record_index < 0 or repair_kit_record_index >= source_records.size() or not _is_owned_weapon_resource(weapon_resource):
		return failed_result
	# 当前耐久；限制到非负数，用于计算可修复缺口。
	var durability_before: float = maxf(float(weapon_resource.get("current_durability")), 0.0)
	# 最大耐久；至少为 1，避免异常旧武器出现无效修复计算。
	var maximum_durability: float = _get_resource_maximum_durability(weapon_resource)
	# 修复包标称恢复量；取值至少为 0，实际恢复量仍会受武器耐久缺口限制。
	var configured_repair_amount: float = maxf(float(repair_kit_resource.get("repair_amount")), 0.0)
	# 实际恢复量；满耐久武器不会消耗修复包。
	var durability_restored: float = minf(configured_repair_amount, maxf(maximum_durability - durability_before, 0.0))
	if durability_restored <= 0.0:
		return failed_result
	# 修复后耐久；写入前限制在武器自身最大耐久以内。
	var durability_after: float = minf(durability_before + durability_restored, maximum_durability)
	if weapon_resource.has_method("set_current_durability"):
		weapon_resource.call("set_current_durability", durability_after)
	else:
		weapon_resource.set("current_durability", durability_after)
	# 修复包记录；成功修复后才扣除一件，失败不会改变库存或武器。
	var repair_kit_record: Dictionary = source_records[repair_kit_record_index]
	# 修复包剩余数量；大于零时保留原堆叠，归零时移除完整记录。
	var remaining_quantity: int = maxi(int(repair_kit_record.get("quantity", 1)) - 1, 0)
	if remaining_quantity > 0:
		repair_kit_record["quantity"] = remaining_quantity
	else:
		source_records.remove_at(repair_kit_record_index)
	_queue_save_inventory()
	_emit_storage_changed(source_location)
	notify_weapon_runtime_state_changed(weapon_resource)
	if _run_active:
		# 股市统计服务；只记录正式战斗内实际成功消耗的修复包，局外整备不会影响行情。
		var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
		if stock_market_service != null and stock_market_service.has_method("record_run_metric"):
			stock_market_service.call("record_run_metric", "repair_kits_used", 1.0)
	return {"success": true, "weapon": weapon_resource, "repair_kit": repair_kit_resource, "durability_before": durability_before, "durability_after": durability_after, "durability_restored": durability_restored}


func transfer_storage_to_equipment(item_resource: Resource, source_location: String, target_location: String) -> bool:
	# 来源记录索引；取值为对应仓库或背包中的有效下标，其他位置不能通过该接口装备。
	var source_index: int = _find_storage_record_index(source_location, item_resource)
	if source_index < 0 or not _does_resource_match_equipment_location(item_resource, target_location):
		return false

	# 待装备记录；从来源容器原子取出，目标槽旧装备会回到相同来源位置形成直观交换。
	var moving_record: Dictionary = _take_storage_record_at(source_location, source_index)
	if moving_record.is_empty():
		return false
	# 被替换装备记录；空字典表示目标槽原本为空，非空时插回拖拽来源容器。
	var replaced_record: Dictionary = _take_equipment_record(target_location)
	if not _set_equipment_record(target_location, moving_record):
		_insert_storage_record(source_location, moving_record, source_index)
		if not replaced_record.is_empty():
			_set_equipment_record(target_location, replaced_record)
		return false
	if not replaced_record.is_empty():
		_insert_storage_record(source_location, replaced_record, source_index)
	_refresh_current_ranged_slot_after_equipment_change()
	_queue_save_inventory()
	_emit_storage_changed(source_location)
	equipment_changed.emit()
	return true


func transfer_equipment_to_storage(source_location: String, target_location: String, target_index: int = -1) -> bool:
	if not _is_storage_location(target_location):
		return false
	# 待卸下装备记录；取值来自远程或近战槽，空槽不能创建存储记录。
	var moving_record: Dictionary = _take_equipment_record(source_location)
	if moving_record.is_empty():
		return false
	if not _insert_storage_record(target_location, moving_record, target_index):
		_set_equipment_record(source_location, moving_record)
		return false
	_refresh_current_ranged_slot_after_equipment_change()
	_queue_save_inventory()
	_emit_storage_changed(target_location)
	equipment_changed.emit()
	return true


func swap_equipment_locations(source_location: String, target_location: String) -> bool:
	if source_location == target_location:
		return true
	# 来源装备资源；取值用于验证目标槽类型，空槽不能主动发起拖拽交换。
	var source_resource: Resource = get_equipment_location_resource(source_location)
	if source_resource == null or not _does_resource_match_equipment_location(source_resource, target_location):
		return false
	# 目标装备资源；非空时也必须兼容来源槽，防止远近战武器交换到错误类型槽位。
	var target_resource: Resource = get_equipment_location_resource(target_location)
	if target_resource != null and not _does_resource_match_equipment_location(target_resource, source_location):
		return false
	# 来源装备记录；先取出两个槽位，再交叉写回，保持资源记录编号和获得时间不变。
	var source_record: Dictionary = _take_equipment_record(source_location)
	# 目标装备记录；允许为空，交叉写回后来源槽会相应变为空槽。
	var target_record: Dictionary = _take_equipment_record(target_location)
	if not source_record.is_empty():
		_set_equipment_record(target_location, source_record)
	if not target_record.is_empty():
		_set_equipment_record(source_location, target_record)
	_refresh_current_ranged_slot_after_equipment_change()
	_queue_save_inventory()
	equipment_changed.emit()
	return true


func get_equipment_location_resource(location: String) -> Resource:
	if location == EQUIPMENT_LOCATION_MELEE:
		return get_melee_equipment_resource()
	# 防具部位；位置使用 armor_ 前缀，与武器槽复用同一所有权接口。
	var armor_slot: String = _get_armor_slot_from_location(location)
	if not armor_slot.is_empty():
		return get_armor_equipment_resource(armor_slot)
	# 远程槽索引；取值为解析后的合法下标，-1 表示目标不是远程装备位置。
	var ranged_slot_index: int = _get_ranged_slot_index_from_location(location)
	return get_ranged_equipment_resource(ranged_slot_index) if ranged_slot_index >= 0 else null


func get_armor_equipment_resource(armor_slot: String) -> Resource:
	# 防具记录；异常部位或空槽统一返回 null。
	var armor_record: Dictionary = _armor_equipment_records.get(armor_slot, {}) as Dictionary
	return armor_record.get("resource") as Resource if not armor_record.is_empty() else null


func get_armor_equipment_resources() -> Dictionary:
	# 防具资源快照；保持固定四部位键，调用方不能直接修改所有权记录。
	var result: Dictionary = {}
	for armor_slot in ARMOR_SLOT_IDS:
		result[armor_slot] = get_armor_equipment_resource(armor_slot)
	return result


func get_backpack_resources() -> Array[Resource]:
	# 背包资源结果；元素与记录数组顺序一致，返回副本防止外部直接改动全局记录。
	var result: Array[Resource] = []
	# 背包记录；取值为所有未装备物品，用于提取运行时武器资源。
	for record in _backpack_records:
		# 记录资源；取值应为 Resource，异常记录不会进入结果数组。
		var item_resource: Resource = record.get("resource") as Resource
		if item_resource != null:
			result.append(item_resource)
	return result


func get_backpack_entries() -> Array[Dictionary]:
	# 仓库展示条目；每项只暴露资源、获得时间和上次撤离标记，不允许 UI 直接修改内部记录。
	var result: Array[Dictionary] = []
	# 背包记录；取值按当前仓库顺序遍历，用于构建局外仓库列表。
	for record in _backpack_records:
		# 记录资源；取值应为 Resource，异常记录不会暴露给 UI。
		var item_resource: Resource = record.get("resource") as Resource
		if item_resource == null:
			continue
		result.append({
			"record_id": str(record.get("record_id", "")),
			"resource": item_resource,
			"quantity": int(record.get("quantity", 1)),
			"acquired_at": float(record.get("acquired_at", 0.0)),
			"is_last_extraction": _last_extraction_epoch > 0 and int(record.get("last_extraction_epoch", 0)) == _last_extraction_epoch,
		})
	return result


func get_backpack_count() -> int:
	return _backpack_records.size()


func has_backpack_resource(item_resource: Resource) -> bool:
	return _find_backpack_record_index(item_resource) >= 0


func add_backpack_resource(item_resource: Resource, target_index: int = -1, quantity: int = 1) -> bool:
	if item_resource == null or _is_resource_equipped(item_resource):
		return false
	if has_backpack_resource(item_resource):
		return false
	# 实际加入数量；武器与装备固定为一件，可堆叠资源允许地面掉落按单组上限一次加入。
	var resolved_quantity: int = clampi(quantity, 1, MAX_STACK_QUANTITY) if _is_stackable_resource(item_resource) else 1

	# 待加入记录；优先复用 HUD 分步操作留下的临时记录，新拾取物品才创建新的获得时间。
	var record: Dictionary = _take_detached_record(item_resource)
	# 是否为新获得物品；默认由临时记录是否为空判断，新物品加入后按默认获得时间排序。
	var is_new_acquisition: bool = record.is_empty()
	if is_new_acquisition:
		record = _create_record(item_resource)
		record["quantity"] = resolved_quantity
		# 是否为本局首次获得；自己丢弃后重新捡回会返回 false，避免堆叠来源数量被重复累计。
		var is_run_acquisition: bool = _track_combat_acquisition(item_resource, resolved_quantity)
		# 本局来源数量；首次拾取的地面堆叠全部属于同一次战场获得，自己丢弃后重新捡回时保持为零。
		record["run_gained_quantity"] = resolved_quantity if is_run_acquisition else 0

	if _is_stackable_resource(item_resource):
		_insert_record_with_stack_merge(_backpack_records, record, target_index)
	elif target_index < 0:
		_backpack_records.append(record)
		_sort_backpack_default()
	else:
		# 标准化插入位置；取值限制在 0 到当前背包数量，支持卸下和拖拽回滚到原槽位附近。
		var insert_index: int = clampi(target_index, 0, _backpack_records.size())
		_backpack_records.insert(insert_index, record)

	_queue_save_inventory()
	inventory_changed.emit()
	return true


func register_combat_dropped_resource(item_resource: Resource) -> void:
	if not _run_active or item_resource == null:
		return
	# 丢弃资源身份；堆叠拆分后形成的新实例仍属于玩家原有物品，重新捡回时不计入本局首次战利品。
	_run_seen_resource_instance_ids[item_resource.get_instance_id()] = true


func remove_backpack_resource(item_resource: Resource) -> bool:
	# 背包记录索引；取值为 -1 或有效下标，默认按资源实例身份精确查找重复武器中的目标。
	var record_index: int = _find_backpack_record_index(item_resource)
	if record_index < 0:
		return false

	# 被移除记录；暂存到 detached，等待同帧装备、世界丢弃或回滚操作决定最终去向。
	var record: Dictionary = _backpack_records[record_index]
	_backpack_records.remove_at(record_index)
	_detached_records[item_resource.get_instance_id()] = record
	_queue_save_inventory()
	inventory_changed.emit()
	return true


func move_backpack_item(source_index: int, target_index: int) -> bool:
	if source_index < 0 or source_index >= _backpack_records.size() or target_index < 0 or target_index > _backpack_records.size():
		return false
	if source_index == target_index or target_index == source_index + 1:
		return true

	# 被移动记录；取值为背包内有效记录，移除后按修正索引重新插入。
	var moved_record: Dictionary = _backpack_records[source_index]
	_backpack_records.remove_at(source_index)
	# 修正插入索引；目标位于源项之后时减一，匹配现有 HUD 的“插入到目标前”语义。
	var insert_index: int = target_index - 1 if target_index > source_index else target_index
	_backpack_records.insert(clampi(insert_index, 0, _backpack_records.size()), moved_record)
	_queue_save_inventory()
	inventory_changed.emit()
	return true


func discard_detached_resource(item_resource: Resource) -> bool:
	if item_resource == null:
		return false
	# 临时记录键；取值为资源实例编号，世界掉落成功后从全局所有权中永久移除。
	var detached_key: int = item_resource.get_instance_id()
	if not _detached_records.has(detached_key):
		return false
	_detached_records.erase(detached_key)
	_queue_save_inventory()
	return true


func get_ranged_slot_count() -> int:
	return _ranged_equipment_records.size()


func get_ranged_equipment_resource(slot_index: int) -> Resource:
	if slot_index < 0 or slot_index >= _ranged_equipment_records.size():
		return null
	# 远程槽记录；取值为 Dictionary 或 null，默认只从有效字典提取资源。
	var raw_record: Variant = _ranged_equipment_records[slot_index]
	if raw_record is Dictionary:
		return (raw_record as Dictionary).get("resource") as Resource
	return null


func get_ranged_equipment_resources() -> Array:
	# 远程装备资源数组；元素为 Resource 或 null，与装备槽下标保持一致。
	var result: Array = []
	# 远程槽索引；取值为所有槽位有效下标，用于逐项提取资源。
	for slot_index in range(_ranged_equipment_records.size()):
		result.append(get_ranged_equipment_resource(slot_index))
	return result


func get_melee_equipment_resource() -> Resource:
	return _melee_equipment_record.get("resource") as Resource if not _melee_equipment_record.is_empty() else null


func get_current_ranged_slot() -> int:
	return _current_ranged_slot


func set_current_ranged_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _ranged_equipment_records.size() or get_ranged_equipment_resource(slot_index) == null:
		return false
	_current_ranged_slot = slot_index
	_queue_save_inventory()
	equipment_changed.emit()
	return true


func equip_resource_to_ranged(slot_index: int, item_resource: Resource) -> bool:
	if slot_index < 0 or slot_index >= _ranged_equipment_records.size() or not _is_weapon_type(item_resource, "ranged"):
		return false

	# 移入装备的记录；可以来自背包临时区或其他装备槽，资源实例身份保持不变。
	var moving_record: Dictionary = _take_owned_record(item_resource)
	if moving_record.is_empty():
		return false

	# 目标槽旧记录；非空时暂存，等待 HUD 放回背包或交换到来源槽。
	var raw_replaced_record: Variant = _ranged_equipment_records[slot_index]
	if raw_replaced_record is Dictionary and not (raw_replaced_record as Dictionary).is_empty():
		_detach_record(raw_replaced_record as Dictionary)
	_ranged_equipment_records[slot_index] = moving_record
	if get_ranged_equipment_resource(_current_ranged_slot) == null:
		_current_ranged_slot = slot_index
	_queue_save_inventory()
	inventory_changed.emit()
	equipment_changed.emit()
	return true


func equip_resource_to_melee(item_resource: Resource) -> bool:
	if not _is_weapon_type(item_resource, "melee"):
		return false
	# 移入近战槽的记录；取值来自背包、临时区或其他槽位。
	var moving_record: Dictionary = _take_owned_record(item_resource)
	if moving_record.is_empty():
		return false
	if not _melee_equipment_record.is_empty():
		_detach_record(_melee_equipment_record)
	_melee_equipment_record = moving_record
	_queue_save_inventory()
	inventory_changed.emit()
	equipment_changed.emit()
	return true


func detach_ranged_equipment(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _ranged_equipment_records.size():
		return false
	# 待卸下远程记录；取值为 Dictionary 或 null，空槽不能卸下。
	var raw_record: Variant = _ranged_equipment_records[slot_index]
	if not (raw_record is Dictionary) or (raw_record as Dictionary).is_empty():
		return false
	_detach_record(raw_record as Dictionary)
	_ranged_equipment_records[slot_index] = null
	if _current_ranged_slot == slot_index:
		_current_ranged_slot = _find_first_equipped_ranged_slot()
	_queue_save_inventory()
	equipment_changed.emit()
	return true


func detach_melee_equipment() -> bool:
	if _melee_equipment_record.is_empty():
		return false
	_detach_record(_melee_equipment_record)
	_melee_equipment_record = {}
	_queue_save_inventory()
	equipment_changed.emit()
	return true


func warehouse_equip_ranged(item_resource: Resource, slot_index: int) -> bool:
	# 背包原位置；取值为有效下标，用于把被替换装备放回相近位置。
	var backpack_index: int = _find_backpack_record_index(item_resource)
	if backpack_index < 0:
		return false
	# 被替换远程资源；取值可为空，装备成功后原武器自动回到背包。
	var replaced_resource: Resource = get_ranged_equipment_resource(slot_index)
	if not remove_backpack_resource(item_resource):
		return false
	if not equip_resource_to_ranged(slot_index, item_resource):
		add_backpack_resource(item_resource, backpack_index)
		return false
	if replaced_resource != null:
		add_backpack_resource(replaced_resource, backpack_index)
	return true


func warehouse_equip_melee(item_resource: Resource) -> bool:
	# 背包原位置；取值为有效下标，用于替换近战后放回旧武器。
	var backpack_index: int = _find_backpack_record_index(item_resource)
	if backpack_index < 0:
		return false
	# 被替换近战资源；取值可为空，装备成功后自动回到背包。
	var replaced_resource: Resource = get_melee_equipment_resource()
	if not remove_backpack_resource(item_resource):
		return false
	if not equip_resource_to_melee(item_resource):
		add_backpack_resource(item_resource, backpack_index)
		return false
	if replaced_resource != null:
		add_backpack_resource(replaced_resource, backpack_index)
	return true


func warehouse_unequip_ranged(slot_index: int) -> bool:
	# 待卸下资源；取值为目标远程槽武器，空槽直接失败。
	var item_resource: Resource = get_ranged_equipment_resource(slot_index)
	if item_resource == null or not detach_ranged_equipment(slot_index):
		return false
	return add_backpack_resource(item_resource)


func warehouse_unequip_melee() -> bool:
	# 待卸下资源；取值为近战槽武器，空槽直接失败。
	var item_resource: Resource = get_melee_equipment_resource()
	if item_resource == null or not detach_melee_equipment():
		return false
	return add_backpack_resource(item_resource)


func _initialize_equipment_slots() -> void:
	_ranged_equipment_records.clear()
	# 远程槽初始化索引；取值为 0 到默认槽数量减一，每项初始为空。
	for _slot_index in range(DEFAULT_RANGED_SLOT_COUNT):
		_ranged_equipment_records.append(null)
	_armor_equipment_records.clear()
	for armor_slot in ARMOR_SLOT_IDS:
		_armor_equipment_records[armor_slot] = {}


func _initialize_default_inventory() -> void:
	_warehouse_records.clear()
	_backpack_records.clear()
	_initialize_equipment_slots()
	_melee_equipment_record = {}
	_detached_records.clear()
	_current_ranged_slot = 0
	_last_extraction_epoch = 0
	_coins = DEFAULT_STARTING_COINS

	# 默认背包武器标识；取值来自项目初始配置，逐项加载为独立资源记录。
	# 永久仓库初始化补充：历史常量名称保持兼容，当前这些未装备武器默认放入永久仓库而不是随身背包。
	for weapon_id in DEFAULT_BACKPACK_WEAPON_IDS:
		# 默认背包资源；取值为武器模板深拷贝，确保每个物品拥有独立实例身份。
		var item_resource: Resource = _load_weapon_resource(weapon_id)
		if item_resource != null:
			_warehouse_records.append(_create_record(item_resource))

	# 默认远程槽索引；取值为默认远程标识数组有效下标，最多填入项目远程槽数量。
	for slot_index in range(mini(DEFAULT_RANGED_WEAPON_IDS.size(), _ranged_equipment_records.size())):
		# 默认远程资源；取值为武器模板深拷贝，直接创建装备记录。
		var ranged_resource: Resource = _load_weapon_resource(DEFAULT_RANGED_WEAPON_IDS[slot_index])
		if ranged_resource != null:
			_ranged_equipment_records[slot_index] = _create_record(ranged_resource)

	# 默认近战资源；取值为相位刃模板深拷贝，加载失败时保持空槽。
	# 星内容精简补充：当前默认标识指向银河球棒，仍保持相同的深拷贝与空槽容错规则。
	var melee_resource: Resource = _load_weapon_resource(DEFAULT_MELEE_WEAPON_ID)
	if melee_resource != null:
		_melee_equipment_record = _create_record(melee_resource)
	# 默认防具；首次存档为四个部位各装备一件基础装备，便于直接体验完整属性链路。
	# 星内容精简补充：当前装备路径表只包含四件开拓者套装，因此新存档会直接装备完整套装。
	for equipment_id in EQUIPMENT_RESOURCE_PATHS.keys():
		var equipment_resource: Resource = _load_equipment_resource(str(equipment_id))
		if equipment_resource == null:
			continue
		var armor_slot: String = str(equipment_resource.get("equipment_slot"))
		if armor_slot in ARMOR_SLOT_IDS:
			_armor_equipment_records[armor_slot] = _create_record(equipment_resource)
	_sort_warehouse_default()


func _create_record(item_resource: Resource, acquired_at: float = -1.0, record_id: String = "", register_encyclopedia_discovery: bool = true) -> Dictionary:
	## 创建库存所有权记录；默认同时登记图鉴发现，商店快照等非所有权反序列化会显式关闭该行为。
	if register_encyclopedia_discovery:
		_register_encyclopedia_discovery(item_resource)
	_acquisition_sequence += 1
	# 实际获得时间；取值为 Unix 秒，新物品使用当前时间，读档时保留存档时间。
	var resolved_acquired_at: float = Time.get_unix_time_from_system() if acquired_at < 0.0 else acquired_at
	# 实际记录编号；默认由时间、帧计时和递增序号组成，保证同类重复武器也能独立结算。
	var resolved_record_id: String = record_id
	if resolved_record_id.is_empty():
		resolved_record_id = "%d_%d_%d" % [roundi(resolved_acquired_at), Time.get_ticks_msec(), _acquisition_sequence]
	return {
		"record_id": resolved_record_id,
		"resource": item_resource,
		"acquired_at": resolved_acquired_at,
		"acquisition_sequence": _acquisition_sequence,
		"last_extraction_epoch": 0,
		"quantity": 1,
		# 本局来源数量；仅在正式战斗内存中使用，不写入永久存档，取值始终限制在 0 到记录总数量。
		"run_gained_quantity": 0,
	}


func _register_encyclopedia_discovery(item_resource: Resource) -> void:
	## 登记一次永久图鉴发现；只有新的稳定条目会写入状态并派发更新信号，重复获得不造成额外存档或 UI 刷新。
	# 图鉴稳定键；由物品类型和稳定 ID 组成，随机强化石使用统一资源类别键。
	var discovery_key: String = _get_encyclopedia_discovery_key(item_resource)
	if discovery_key.is_empty() or _discovered_encyclopedia_entries.has(discovery_key):
		return
	_discovered_encyclopedia_entries[discovery_key] = true
	encyclopedia_changed.emit()


func _get_encyclopedia_discovery_key(item_resource: Resource) -> String:
	## 生成物品图鉴稳定键；资源重命名、耐久变化和强化结果不会改变已发现身份，缺少稳定 ID 的异常资源不进入图鉴。
	if item_resource == null:
		return ""
	# 物品类型；强化石由随机运行时字段构成，因此统一映射到单一资源类别条目。
	var item_kind: String = str(item_resource.get("item_kind")).strip_edges()
	if item_kind == "enhancement_stone":
		return ENHANCEMENT_STONE_DISCOVERY_KEY
	# 稳定物品标识；武器、装备与通用道具分别读取既有 ID 字段，避免不同类型同名 ID 相互覆盖。
	var item_id: String = str(item_resource.get("weapon_id")).strip_edges() if item_kind == "weapon" else (str(item_resource.get("equipment_id")).strip_edges() if item_kind == "equipment" else str(item_resource.get("item_id")).strip_edges())
	return "%s:%s" % [item_kind, item_id] if not item_kind.is_empty() and not item_id.is_empty() else ""


func _sort_backpack_default() -> void:
	_backpack_records.sort_custom(Callable(self, "_compare_backpack_records"))


func _sort_warehouse_default() -> void:
	_warehouse_records.sort_custom(Callable(self, "_compare_backpack_records"))


func _compare_backpack_records(first_record: Dictionary, second_record: Dictionary) -> bool:
	# 第一项是否属于上次撤离；true 时无条件排在普通获得时间项之前。
	var first_is_last_extraction: bool = _last_extraction_epoch > 0 and int(first_record.get("last_extraction_epoch", 0)) == _last_extraction_epoch
	# 第二项是否属于上次撤离；用于与第一项比较优先级。
	var second_is_last_extraction: bool = _last_extraction_epoch > 0 and int(second_record.get("last_extraction_epoch", 0)) == _last_extraction_epoch
	if first_is_last_extraction != second_is_last_extraction:
		return first_is_last_extraction
	# 第一项获得时间；时间越新默认越靠前。
	var first_acquired_at: float = float(first_record.get("acquired_at", 0.0))
	# 第二项获得时间；用于默认获得时间倒序比较。
	var second_acquired_at: float = float(second_record.get("acquired_at", 0.0))
	if not is_equal_approx(first_acquired_at, second_acquired_at):
		return first_acquired_at > second_acquired_at
	return int(first_record.get("acquisition_sequence", 0)) > int(second_record.get("acquisition_sequence", 0))


func _find_backpack_record_index(item_resource: Resource) -> int:
	if item_resource == null:
		return -1
	# 背包查找索引；取值为所有记录有效下标，使用资源实例身份区分同 ID 重复物品。
	for record_index in range(_backpack_records.size()):
		if _backpack_records[record_index].get("resource") == item_resource:
			return record_index
	return -1


func _find_warehouse_record_index(item_resource: Resource) -> int:
	if item_resource == null:
		return -1
	# 永久仓库查找索引；取值为所有安全存储记录下标，使用资源实例身份区分同类重复物品。
	for record_index in range(_warehouse_records.size()):
		if _warehouse_records[record_index].get("resource") == item_resource:
			return record_index
	return -1


func _is_storage_location(location: String) -> bool:
	return location == STORAGE_LOCATION_WAREHOUSE or location == STORAGE_LOCATION_BACKPACK


func _get_storage_records(location: String) -> Array[Dictionary]:
	if location == STORAGE_LOCATION_WAREHOUSE:
		return _warehouse_records
	if location == STORAGE_LOCATION_BACKPACK:
		return _backpack_records
	return []


func _is_weapon_resource(item_resource: Resource) -> bool:
	return item_resource != null and not _is_enhancement_stone(item_resource) and str(item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"]


func _is_equipment_resource(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "equipment" and str(item_resource.get("equipment_slot")) in ARMOR_SLOT_IDS


func _is_enhancement_stone(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "enhancement_stone"


func _is_repair_kit(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "repair_kit"


func _is_consumable(item_resource: Resource) -> bool:
	## 判断资源是否为战斗限时消耗品；与修复包共用堆叠库存，但使用目标和效果结算保持独立。
	return item_resource != null and str(item_resource.get("item_kind")) == "consumable"


func _is_stackable_resource(item_resource: Resource) -> bool:
	return _is_enhancement_stone(item_resource) or _is_repair_kit(item_resource) or _is_consumable(item_resource)


func _is_owned_weapon_resource(item_resource: Resource) -> bool:
	if not (_is_weapon_resource(item_resource) or _is_equipment_resource(item_resource)):
		return false
	if _find_backpack_record_index(item_resource) >= 0 or _find_warehouse_record_index(item_resource) >= 0:
		return true
	if _is_resource_equipped(item_resource):
		return true
	return _detached_records.has(item_resource.get_instance_id())


func _get_resource_value(item_resource: Resource) -> int:
	if item_resource == null:
		return 0
	if item_resource.has_method("get_effective_value"):
		return maxi(int(item_resource.call("get_effective_value")), 0)
	return maxi(int(item_resource.get("value")), 0)


func _get_resource_maximum_durability(item_resource: Resource) -> float:
	if item_resource == null:
		return 1.0
	# 有效耐久上限；装备通过统一接口返回耐久词条结算值，旧资源回退原始导出字段。
	return maxf(float(item_resource.call("get_maximum_durability")), 1.0) if item_resource.has_method("get_maximum_durability") else maxf(float(item_resource.get("max_durability")), 1.0)


func _get_stack_signature(item_resource: Resource) -> String:
	if not _is_stackable_resource(item_resource):
		return ""
	if item_resource.has_method("get_stack_signature"):
		return str(item_resource.call("get_stack_signature"))
	return str(item_resource.get("modifiers"))


func _insert_record_with_stack_merge(target_records: Array[Dictionary], record: Dictionary, target_index: int = -1) -> void:
	if record.is_empty():
		return
	# 待插入资源；武器保持单实例记录，强化石和修复包按同类签名参与堆叠合并。
	var item_resource: Resource = record.get("resource") as Resource
	if not _is_stackable_resource(item_resource):
		# 武器插入下标；负数追加，指定下标用于拖拽排序和装备替换回滚。
		var weapon_insert_index: int = target_records.size() if target_index < 0 else clampi(target_index, 0, target_records.size())
		target_records.insert(weapon_insert_index, record)
		return

	# 剩余待放数量；合法记录限制在 1 到 99，跨容器移动时会优先填充相同词条堆叠。
	var remaining_quantity: int = clampi(int(record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
	# 剩余本局来源数量；随可堆叠记录共同合并，确保同一签名中开局携带与本局拾取的数量仍可分别结算。
	var remaining_run_gained_quantity: int = clampi(int(record.get("run_gained_quantity", 0)), 0, remaining_quantity)
	# 待插入签名；强化石按品质词条方向、修复包按 item_id 合并。
	var stack_signature: String = _get_stack_signature(item_resource)
	for existing_record in target_records:
		# 已有资源；非可堆叠资源或签名不一致时跳过。
		var existing_resource: Resource = existing_record.get("resource") as Resource
		if not _is_stackable_resource(existing_resource) or _get_stack_signature(existing_resource) != stack_signature:
			continue
		# 已有数量；达到 99 时继续寻找下一组相同强化石。
		var existing_quantity: int = clampi(int(existing_record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
		if existing_quantity >= MAX_STACK_QUANTITY:
			continue
		# 可合并数量；不超过当前堆叠空余和待插入剩余数量。
		var merged_quantity: int = mini(MAX_STACK_QUANTITY - existing_quantity, remaining_quantity)
		existing_record["quantity"] = existing_quantity + merged_quantity
		# 合并的本局来源数量；优先随本次插入单位进入目标堆叠，并保持不超过目标总数量。
		var merged_run_gained_quantity: int = mini(remaining_run_gained_quantity, merged_quantity)
		existing_record["run_gained_quantity"] = clampi(int(existing_record.get("run_gained_quantity", 0)) + merged_run_gained_quantity, 0, existing_quantity + merged_quantity)
		remaining_run_gained_quantity -= merged_run_gained_quantity
		remaining_quantity -= merged_quantity
		if remaining_quantity <= 0:
			return

	# 溢出记录；原记录资源继续代表新堆叠，数量不会超过 99。
	record["quantity"] = mini(remaining_quantity, MAX_STACK_QUANTITY)
	record["run_gained_quantity"] = mini(remaining_run_gained_quantity, int(record["quantity"]))
	# 资源插入下标；负数追加，拖拽到具体位置时保持目标附近布局。
	var resource_insert_index: int = target_records.size() if target_index < 0 else clampi(target_index, 0, target_records.size())
	target_records.insert(resource_insert_index, record)


func _find_storage_record_index(location: String, item_resource: Resource) -> int:
	if location == STORAGE_LOCATION_WAREHOUSE:
		return _find_warehouse_record_index(item_resource)
	if location == STORAGE_LOCATION_BACKPACK:
		return _find_backpack_record_index(item_resource)
	return -1


func _take_storage_record_at(location: String, record_index: int) -> Dictionary:
	if location == STORAGE_LOCATION_WAREHOUSE and record_index >= 0 and record_index < _warehouse_records.size():
		# 永久仓库来源记录；移除后由装备槽或其他存储容器立即接管所有权。
		var warehouse_record: Dictionary = _warehouse_records[record_index]
		_warehouse_records.remove_at(record_index)
		return warehouse_record
	if location == STORAGE_LOCATION_BACKPACK and record_index >= 0 and record_index < _backpack_records.size():
		# 随身背包来源记录；移除后由装备槽或其他存储容器立即接管所有权。
		var backpack_record: Dictionary = _backpack_records[record_index]
		_backpack_records.remove_at(record_index)
		return backpack_record
	return {}


func _insert_storage_record(location: String, record: Dictionary, target_index: int = -1) -> bool:
	if record.is_empty():
		return false
	if location == STORAGE_LOCATION_WAREHOUSE:
		_insert_record_with_stack_merge(_warehouse_records, record, target_index)
		return true
	if location == STORAGE_LOCATION_BACKPACK:
		_insert_record_with_stack_merge(_backpack_records, record, target_index)
		return true
	return false


func _emit_storage_changed(location: String) -> void:
	if location == STORAGE_LOCATION_WAREHOUSE:
		warehouse_changed.emit()
	elif location == STORAGE_LOCATION_BACKPACK:
		inventory_changed.emit()


func _get_ranged_slot_index_from_location(location: String) -> int:
	if not location.begins_with(EQUIPMENT_LOCATION_RANGED_PREFIX):
		return -1
	# 远程槽下标文本；取值为位置前缀后的数字部分，非整数内容会解析为 0 因此还需反向校验。
	var slot_text: String = location.trim_prefix(EQUIPMENT_LOCATION_RANGED_PREFIX)
	if not slot_text.is_valid_int():
		return -1
	# 远程槽下标；取值必须落在当前装备槽数组范围内。
	var slot_index: int = int(slot_text)
	return slot_index if slot_index >= 0 and slot_index < _ranged_equipment_records.size() else -1


func _get_armor_slot_from_location(location: String) -> String:
	if not location.begins_with(EQUIPMENT_LOCATION_ARMOR_PREFIX):
		return ""
	# 防具部位文本；只有固定四部位被视为有效装备位置。
	var armor_slot: String = location.trim_prefix(EQUIPMENT_LOCATION_ARMOR_PREFIX)
	return armor_slot if armor_slot in ARMOR_SLOT_IDS else ""


func _does_resource_match_equipment_location(item_resource: Resource, location: String) -> bool:
	if location == EQUIPMENT_LOCATION_MELEE:
		return _is_weapon_type(item_resource, "melee")
	# 防具目标；资源部位必须与目标槽完全一致，禁止跨部位装备。
	var armor_slot: String = _get_armor_slot_from_location(location)
	if not armor_slot.is_empty():
		return _is_equipment_resource(item_resource) and str(item_resource.get("equipment_slot")) == armor_slot
	return _get_ranged_slot_index_from_location(location) >= 0 and _is_weapon_type(item_resource, "ranged")


func _take_equipment_record(location: String) -> Dictionary:
	if location == EQUIPMENT_LOCATION_MELEE:
		if _melee_equipment_record.is_empty():
			return {}
		# 近战来源记录；取出后立即清空唯一近战槽，等待原子操作写入新位置。
		var melee_record: Dictionary = _melee_equipment_record
		_melee_equipment_record = {}
		return melee_record
	# 防具部位；取出后保留固定空字典键，方便属性聚合稳定遍历。
	var armor_slot: String = _get_armor_slot_from_location(location)
	if not armor_slot.is_empty():
		var armor_record: Dictionary = _armor_equipment_records.get(armor_slot, {}) as Dictionary
		_armor_equipment_records[armor_slot] = {}
		return armor_record
	# 远程槽下标；取值为合法槽位或 -1，异常位置不会修改装备数组。
	var ranged_slot_index: int = _get_ranged_slot_index_from_location(location)
	if ranged_slot_index < 0:
		return {}
	# 远程原始记录；取值为 Dictionary 或 null，空槽返回空字典。
	var raw_record: Variant = _ranged_equipment_records[ranged_slot_index]
	if not (raw_record is Dictionary) or (raw_record as Dictionary).is_empty():
		return {}
	# 远程来源记录；取出后清空原槽，等待交换或转移操作写入新位置。
	var ranged_record: Dictionary = raw_record as Dictionary
	_ranged_equipment_records[ranged_slot_index] = null
	return ranged_record


func _set_equipment_record(location: String, record: Dictionary) -> bool:
	if record.is_empty():
		return false
	# 装备记录资源；取值必须与目标装备槽类型一致，防止错误拖拽污染装备存档。
	var item_resource: Resource = record.get("resource") as Resource
	if not _does_resource_match_equipment_location(item_resource, location):
		return false
	if location == EQUIPMENT_LOCATION_MELEE:
		_melee_equipment_record = record
		return true
	# 防具目标；通过前置类型校验后按固定部位写入。
	var armor_slot: String = _get_armor_slot_from_location(location)
	if not armor_slot.is_empty():
		_armor_equipment_records[armor_slot] = record
		return true
	# 远程目标下标；已通过类型匹配校验，仍使用解析结果避免位置字符串与数组下标耦合。
	var ranged_slot_index: int = _get_ranged_slot_index_from_location(location)
	if ranged_slot_index < 0:
		return false
	_ranged_equipment_records[ranged_slot_index] = record
	return true


func _refresh_current_ranged_slot_after_equipment_change() -> void:
	if get_ranged_equipment_resource(_current_ranged_slot) == null:
		_current_ranged_slot = _find_first_equipped_ranged_slot()


func _take_owned_record(item_resource: Resource) -> Dictionary:
	# 背包记录索引；非负时直接从背包移除并返回。
	var backpack_index: int = _find_backpack_record_index(item_resource)
	if backpack_index >= 0:
		# 背包来源记录；取值为目标资源对应记录，移除后交给装备槽接管。
		var backpack_record: Dictionary = _backpack_records[backpack_index]
		_backpack_records.remove_at(backpack_index)
		return backpack_record

	# 临时记录；取值为 HUD 前一步 remove/unequip 保存的记录，存在时从临时表消费。
	var detached_record: Dictionary = _take_detached_record(item_resource)
	if not detached_record.is_empty():
		return detached_record

	# 远程装备槽索引；取值为所有远程槽，用于支持装备槽之间交换武器。
	for slot_index in range(_ranged_equipment_records.size()):
		if get_ranged_equipment_resource(slot_index) == item_resource:
			# 远程来源记录；取值为对应槽字典，取走后原槽清空。
			var ranged_record: Dictionary = _ranged_equipment_records[slot_index]
			_ranged_equipment_records[slot_index] = null
			return ranged_record

	if get_melee_equipment_resource() == item_resource:
		# 近战来源记录；取值为当前近战字典，取走后清空近战槽。
		var melee_record: Dictionary = _melee_equipment_record
		_melee_equipment_record = {}
		return melee_record
	return {}


func _take_detached_record(item_resource: Resource) -> Dictionary:
	if item_resource == null:
		return {}
	# 临时记录键；取值为资源实例编号，用于精确读取分步操作记录。
	var detached_key: int = item_resource.get_instance_id()
	if not _detached_records.has(detached_key):
		return {}
	# 临时记录；读取后立即从表中移除，保证单个物品只有一个所有权位置。
	var record: Dictionary = _detached_records[detached_key]
	_detached_records.erase(detached_key)
	return record


func _detach_record(record: Dictionary) -> void:
	# 记录资源；取值应为 Resource，缺失时不写入临时表。
	var item_resource: Resource = record.get("resource") as Resource
	if item_resource != null:
		_detached_records[item_resource.get_instance_id()] = record


func _is_resource_equipped(item_resource: Resource) -> bool:
	if item_resource == null:
		return false
	# 远程槽索引；取值为全部远程装备槽，用于检查同一资源是否已经装备。
	for slot_index in range(_ranged_equipment_records.size()):
		if get_ranged_equipment_resource(slot_index) == item_resource:
			return true
	if get_melee_equipment_resource() == item_resource:
		return true
	for armor_slot in ARMOR_SLOT_IDS:
		if get_armor_equipment_resource(armor_slot) == item_resource:
			return true
	return false


func _is_weapon_type(item_resource: Resource, weapon_type: String) -> bool:
	if item_resource == null:
		return false
	# 资源武器类型；混合武器兼容远程和近战装备位置，但同一资源实例仍只能由库存所有权记录占用一个槽。
	var resource_weapon_type: String = str(item_resource.get("weapon_type"))
	return resource_weapon_type == weapon_type or (resource_weapon_type == "hybrid" and weapon_type in ["ranged", "melee"])


func _find_first_equipped_ranged_slot() -> int:
	# 远程槽索引；取值为所有槽位，默认返回第一个非空槽。
	for slot_index in range(_ranged_equipment_records.size()):
		if get_ranged_equipment_resource(slot_index) != null:
			return slot_index
	return 0


func _get_all_owned_records() -> Array[Dictionary]:
	# 全部所有权记录；包含背包、装备和临时记录，默认用于存档与本局快照。
	# 战斗所有权补充：永久仓库不进入本局快照、战利品统计或死亡损失，只有随身背包、装备和临时操作记录属于当前战斗携带物。
	var result: Array[Dictionary] = _backpack_records.duplicate()
	# 远程记录原始值；取值为 Dictionary 或 null，只追加有效记录。
	for raw_record in _ranged_equipment_records:
		if raw_record is Dictionary and not (raw_record as Dictionary).is_empty():
			result.append(raw_record)
	if not _melee_equipment_record.is_empty():
		result.append(_melee_equipment_record)
	# 防具记录；四部位装备同样属于战斗携带物并参与成功保留与失败保护规则。
	for armor_slot in ARMOR_SLOT_IDS:
		var armor_record: Dictionary = _armor_equipment_records.get(armor_slot, {}) as Dictionary
		if not armor_record.is_empty():
			result.append(armor_record)
	# 临时记录原始值；取值为分步操作中尚未安置的字典，存档时按所有物处理避免异常丢失。
	for raw_record in _detached_records.values():
		if raw_record is Dictionary and not (raw_record as Dictionary).is_empty():
			result.append(raw_record)
	return result


func _get_record_display_name(record: Dictionary) -> String:
	# 记录资源；取值为 WeaponData 或其他 Resource，缺失时回退“未知物品”。
	var item_resource: Resource = record.get("resource") as Resource
	if item_resource == null:
		return "未知物品"
	# 物品显示名；取值来自资源 display_name，空字符串时回退 weapon_id。
	var display_name: String = str(item_resource.get("display_name"))
	return str(item_resource.get("weapon_id")) if display_name.is_empty() else display_name


func _track_combat_acquisition(item_resource: Resource, quantity: int = 1) -> bool:
	if not _run_active or item_resource == null:
		return false
	# 资源实例编号；当前战斗内保持稳定，用于区分首次战场拾取与自己丢弃后的重新捡回。
	var resource_instance_id: int = item_resource.get_instance_id()
	if _run_seen_resource_instance_ids.has(resource_instance_id):
		return false
	_run_seen_resource_instance_ids[resource_instance_id] = true
	_run_gained_resources.append(item_resource)
	# 股市统计服务；只在首次战场获得时上报，自己丢弃后重新拾取不会重复影响行情。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_method("record_resource_obtained"):
		stock_market_service.call("record_resource_obtained", item_resource, clampi(quantity, 1, MAX_STACK_QUANTITY))
	return true


func _build_run_gained_entries() -> Array[Dictionary]:
	# 本局收益条目；顺序与首次拾取顺序一致，便于结算界面还原本次探索过程。
	var gained_entries: Array[Dictionary] = []
	# 本局收益资源遍历项；每个资源实例只会在首次拾取时加入一次。
	for item_resource in _run_gained_resources:
		if item_resource != null:
			gained_entries.append(_build_outcome_entry(item_resource))
	return gained_entries


func _build_retained_run_gained_entries() -> Array[Dictionary]:
	# 结算后本局收益条目；覆盖背包保留、装备栏保留和已送回仓库的本局来源单位，不包含实际遗失单位。
	var gained_entries: Array[Dictionary] = []
	# 当前全部所有权记录；本局来源数量只在战斗期间非零，因此开局仓库和携带物不会误入收益区。
	for record in _get_all_owned_records():
		# 仍保留的本局来源数量；堆叠资源可能大于 1，武器与装备固定为 1。
		var retained_run_gained_quantity: int = clampi(int(record.get("run_gained_quantity", 0)), 0, maxi(int(record.get("quantity", 1)), 1))
		if retained_run_gained_quantity <= 0:
			continue
		gained_entries.append(_build_outcome_entry(record.get("resource") as Resource, retained_run_gained_quantity))
	return gained_entries


func _reset_run_gained_quantities() -> void:
	# 全部现有所有权记录；新战斗开始时清除上一局的临时来源标记，永久库存和资源本身不受影响。
	for record in _get_all_owned_records():
		record["run_gained_quantity"] = 0


func _build_outcome_entry(item_resource: Resource, quantity: int = 1) -> Dictionary:
	if item_resource == null:
		return {"resource": null, "display_name": "未知物品", "quantity": maxi(quantity, 1)}
	# 物品显示名称；优先使用 display_name，空值时回退稳定 weapon_id，供兼容文本与列表标题共同使用。
	var display_name: String = str(item_resource.get("display_name"))
	if display_name.is_empty():
		display_name = str(item_resource.get("weapon_id"))
	return {"resource": item_resource, "display_name": display_name, "quantity": maxi(quantity, 1)}


func _get_outcome_entry_names(entries: Array[Dictionary]) -> Array[String]:
	# 兼容名称数组；从结构化条目提取显示名，旧调用方仍可读取 gained_items 或 lost_items。
	var item_names: Array[String] = []
	# 结算条目遍历项；每项都使用 display_name 字段，缺失时回退未知物品。
	for entry in entries:
		# 结算数量；强化石等堆叠资源在名称后追加 xN，武器保持原有名称。
		var quantity: int = maxi(int(entry.get("quantity", 1)), 1)
		var display_name: String = str(entry.get("display_name", "未知物品"))
		item_names.append("%s x%d" % [display_name, quantity] if quantity > 1 else display_name)
	return item_names


func _shuffle_integer_array(values: Array[int]) -> void:
	# 洗牌倒序索引；取值从数组末尾递减到 1，使用 Fisher-Yates 保证每个保留组合概率一致。
	for value_index in range(values.size() - 1, 0, -1):
		# 随机交换索引；取值为 0 到当前倒序索引，用于交换两个数组元素。
		var swap_index: int = _random.randi_range(0, value_index)
		# 临时整数；保存当前位置值以完成交换。
		var temporary_value: int = values[value_index]
		values[value_index] = values[swap_index]
		values[swap_index] = temporary_value


func _queue_save_inventory(force_during_combat: bool = false) -> void:
	# 正式战斗中的普通背包变化属于本局临时状态；结算前不反复序列化永久仓库，物资撤离等明确要求即时持久化的流程可通过参数强制保存。
	if _run_active and not force_during_combat:
		_combat_inventory_save_pending = true
		return
	if _save_queued:
		return
	_save_queued = true
	call_deferred("_save_inventory")


func _save_inventory() -> void:
	_save_queued = false
	# 持久化所有者校验；只有项目 AutoLoad 中的唯一 GlobalInventory 服务可以写入 user://，独立测试实例与临时工具实例一律保持纯内存状态。
	if not _is_canonical_persistence_owner():
		return
	_combat_inventory_save_pending = false
	# 存档永久仓库记录；只序列化局外安全物品，读取后不会加入战斗背包或死亡结算范围。
	var serialized_warehouse: Array[Dictionary] = []
	# 永久仓库记录；取值为全部安全存储记录，逐项转换为可恢复的 JSON 字典。
	for record in _warehouse_records:
		serialized_warehouse.append(_serialize_record(record))
	# 存档背包记录；临时记录会作为背包兜底写入，防止场景切换发生在分步拖拽中间时丢失物品。
	var serialized_backpack: Array[Dictionary] = []
	# 背包记录；取值为正式背包记录，逐项序列化可恢复字段。
	for record in _backpack_records:
		serialized_backpack.append(_serialize_record(record))
	# 临时记录；取值为尚未安置记录，存档中按背包项保存。
	for raw_record in _detached_records.values():
		if raw_record is Dictionary:
			serialized_backpack.append(_serialize_record(raw_record as Dictionary))

	# 存档远程槽；元素为记录字典或 null，与运行时槽位下标保持一致。
	var serialized_ranged: Array = []
	# 远程槽原始记录；取值为 Dictionary 或 null，逐项转换为 JSON 可写结构。
	for raw_record in _ranged_equipment_records:
		serialized_ranged.append(_serialize_record(raw_record as Dictionary) if raw_record is Dictionary else null)
	# 存档防具槽；键保持固定部位，空槽写入 null。
	var serialized_armor: Dictionary = {}
	for armor_slot in ARMOR_SLOT_IDS:
		var armor_record: Dictionary = _armor_equipment_records.get(armor_slot, {}) as Dictionary
		serialized_armor[armor_slot] = _serialize_record(armor_record) if not armor_record.is_empty() else null

	# 存档根字典；保存版本、排序计数、永久仓库、随身背包、装备和局外金币状态。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"acquisition_sequence": _acquisition_sequence,
		"last_extraction_epoch": _last_extraction_epoch,
		"current_ranged_slot": _current_ranged_slot,
		"coins": _coins,
		"stock_holdings": _stock_holdings,
		"encyclopedia_discovered_entries": _get_serialized_encyclopedia_discoveries(),
		"warehouse": serialized_warehouse,
		"backpack": serialized_backpack,
		"ranged_equipment": serialized_ranged,
		"melee_equipment": _serialize_record(_melee_equipment_record) if not _melee_equipment_record.is_empty() else null,
		"armor_equipment": serialized_armor,
	}
	# 存档文件；取值为 user:// 下可写 FileAccess，打开失败时保留内存状态但不抛出运行时错误。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data))


func _get_serialized_encyclopedia_discoveries() -> Array[String]:
	## 返回可写入 JSON 的图鉴发现键列表；字典键排序后保存，保证相同状态多次存档输出顺序稳定。
	# 图鉴发现键数组；只保留非空字符串，异常键不会污染后续读档的永久解锁记录。
	var discovered_keys: Array[String] = []
	for raw_discovery_key in _discovered_encyclopedia_entries.keys():
		# 当前发现键；取值来自稳定物品类型与 ID，键存在即代表玩家曾实际获得过该类别物品。
		var discovery_key: String = str(raw_discovery_key).strip_edges()
		if not discovery_key.is_empty():
			discovered_keys.append(discovery_key)
	discovered_keys.sort()
	return discovered_keys


func _is_canonical_persistence_owner() -> bool:
	## 判断当前实例是否为场景树根节点注册的唯一库存 AutoLoad；返回 false 时不得读取测试对象状态覆盖真实用户存档。
	# 当前场景树；独立脚本测试、尚未入树节点或已经退出树的实例没有有效持久化权限。
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return false
	# 已注册库存服务；只接受与当前实例完全相同的 /root/GlobalInventory 节点，名称相同的普通子节点也没有写入权限。
	var registered_inventory: Node = scene_tree.root.get_node_or_null("GlobalInventory")
	return registered_inventory == self


func _load_inventory() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	# 存档文件；取值为只读 FileAccess，打开失败时回退默认仓库。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return false
	# JSON 原始文本；取值为完整文件内容，解析失败时回退默认仓库。
	var json_text: String = save_file.get_as_text()
	# JSON 解析结果；取值应为 Dictionary，其他类型视为损坏存档。
	var parsed_data: Variant = JSON.parse_string(json_text)
	if not (parsed_data is Dictionary):
		return false
	# 存档字典；包含背包、装备和排序元数据。
	var save_data: Dictionary = parsed_data
	# 存档版本；取值为非负整数，版本 10 之前需要清理已删除内容造成的空装备并补齐星扩展包初始装备。
	var saved_version: int = maxi(int(save_data.get("version", 0)), 0)
	_initialize_equipment_slots()
	_warehouse_records.clear()
	_backpack_records.clear()
	_detached_records.clear()
	_discovered_encyclopedia_entries.clear()
	_melee_equipment_record = {}
	for armor_slot in ARMOR_SLOT_IDS:
		_armor_equipment_records[armor_slot] = {}
	_acquisition_sequence = maxi(int(save_data.get("acquisition_sequence", 0)), 0)
	_last_extraction_epoch = maxi(int(save_data.get("last_extraction_epoch", 0)), 0)
	_current_ranged_slot = clampi(int(save_data.get("current_ranged_slot", 0)), 0, DEFAULT_RANGED_SLOT_COUNT - 1)
	_coins = maxi(int(save_data.get("coins", DEFAULT_STARTING_COINS)), 0)
	_stock_holdings.clear()
	# 图鉴发现记录是否存在；版本 11 前的存档没有历史账本，会按本次恢复的当前持有和装备物品生成并在加载后回写。
	var has_encyclopedia_discoveries: bool = save_data.has("encyclopedia_discovered_entries")
	# 图鉴发现记录原始数组；只接受非空字符串，旧档或损坏项不会阻断后续库存恢复。
	var raw_encyclopedia_discoveries: Variant = save_data.get("encyclopedia_discovered_entries", [])
	if raw_encyclopedia_discoveries is Array:
		for raw_discovery_key in raw_encyclopedia_discoveries:
			# 已保存发现键；直接恢复到集合，物品即使已经出售、消耗或遗失也继续保持图鉴解锁。
			var discovery_key: String = str(raw_discovery_key).strip_edges()
			if not discovery_key.is_empty():
				_discovered_encyclopedia_entries[discovery_key] = true
	if not has_encyclopedia_discoveries:
		_loaded_inventory_requires_resave = true
	# 股票持仓存档；版本 9 起逐项恢复数量与成本，旧版存档自然保持空持仓。
	var raw_stock_holdings: Variant = save_data.get("stock_holdings", {})
	if raw_stock_holdings is Dictionary:
		for raw_stock_id in (raw_stock_holdings as Dictionary).keys():
			# 股票标识；空字符串视为损坏记录，不进入运行时持仓表。
			var stock_id: String = str(raw_stock_id)
			# 原始持仓；必须为字典，其他 JSON 值会被忽略。
			var raw_holding: Variant = (raw_stock_holdings as Dictionary).get(raw_stock_id)
			if stock_id.is_empty() or not (raw_holding is Dictionary):
				continue
			# 恢复数量；只保留正整数，零持仓不写入内存表。
			var quantity: int = maxi(int((raw_holding as Dictionary).get("quantity", 0)), 0)
			# 恢复成本；取值至少为 0，修改只影响浮动盈亏显示，不影响卖出所得。
			var average_cost: float = maxf(float((raw_holding as Dictionary).get("average_cost", 0.0)), 0.0)
			if quantity > 0:
				_stock_holdings[stock_id] = {"quantity": quantity, "average_cost": average_cost}

	# 存档是否包含独立永久仓库；旧版存档没有该字段，原“全局背包”物品会安全迁移到永久仓库。
	var has_separate_warehouse: bool = save_data.has("warehouse")
	# 存档永久仓库原始数组；新版本按安全存储恢复，异常值会被忽略。
	var raw_warehouse: Variant = save_data.get("warehouse", [])
	if raw_warehouse is Array:
		# 永久仓库存档项；取值可能为 Dictionary 或异常值，只恢复合法武器记录。
		for raw_record in raw_warehouse:
			if raw_record is Dictionary:
				# 恢复永久仓库记录；空字典表示资源无法加载，不会生成损坏物品。
				var restored_record: Dictionary = _deserialize_record(raw_record as Dictionary)
				if not restored_record.is_empty():
					_warehouse_records.append(restored_record)

	# 存档背包原始数组；取值为 Array 时逐项恢复有效武器记录。
	var raw_backpack: Variant = save_data.get("backpack", [])
	if raw_backpack is Array:
		# 存档背包项；取值可能为 Dictionary 或异常值，只恢复合法记录。
		for raw_record in raw_backpack:
			if raw_record is Dictionary:
				# 恢复背包记录；空字典表示武器资源无法加载，直接跳过。
				var restored_record: Dictionary = _deserialize_record(raw_record as Dictionary)
				if not restored_record.is_empty():
					if has_separate_warehouse:
						_backpack_records.append(restored_record)
					else:
						_warehouse_records.append(restored_record)

	# 存档远程槽原始数组；取值为 Array，按槽位下标恢复并限制到当前双远程槽数量。
	var raw_ranged_equipment: Variant = save_data.get("ranged_equipment", [])
	if raw_ranged_equipment is Array:
		# 远程槽索引；取值为存档数组与当前槽数量交集。
		for slot_index in range(mini(raw_ranged_equipment.size(), _ranged_equipment_records.size())):
			# 远程槽记录原始值；取值为 Dictionary 或 null。
			var raw_record: Variant = raw_ranged_equipment[slot_index]
			if raw_record is Dictionary:
				# 恢复远程记录；空字典保持空槽。
				var restored_record: Dictionary = _deserialize_record(raw_record as Dictionary)
				if not restored_record.is_empty():
					_ranged_equipment_records[slot_index] = restored_record

	# 存档近战记录原始值；取值为 Dictionary 或 null，合法时恢复近战槽。
	var raw_melee_equipment: Variant = save_data.get("melee_equipment")
	if raw_melee_equipment is Dictionary:
		_melee_equipment_record = _deserialize_record(raw_melee_equipment as Dictionary)
	# 存档防具记录；版本 8 之前缺失时保持四个空槽。
	var raw_armor_equipment: Variant = save_data.get("armor_equipment", {})
	if raw_armor_equipment is Dictionary:
		for armor_slot in ARMOR_SLOT_IDS:
			var raw_armor_record: Variant = (raw_armor_equipment as Dictionary).get(armor_slot)
			if raw_armor_record is Dictionary:
				var restored_armor_record: Dictionary = _deserialize_record(raw_armor_record as Dictionary)
				if not restored_armor_record.is_empty() and _does_resource_match_equipment_location(restored_armor_record.get("resource") as Resource, EQUIPMENT_LOCATION_ARMOR_PREFIX + armor_slot):
					_armor_equipment_records[armor_slot] = restored_armor_record
	# 旧存档迁移；版本 8 之前没有防具槽，为四个空部位发放并装备基础防具。
	# 星内容精简补充：版本 10 之前的已删除基础防具会恢复为空，因此所有空部位改为补齐对应开拓者套装部件。
	if saved_version < SAVE_VERSION:
		for equipment_id in EQUIPMENT_RESOURCE_PATHS.keys():
			var migrated_equipment: Resource = _load_equipment_resource(str(equipment_id))
			if migrated_equipment == null:
				continue
			var migrated_slot: String = str(migrated_equipment.get("equipment_slot"))
			if migrated_slot in ARMOR_SLOT_IDS and (_armor_equipment_records.get(migrated_slot, {}) as Dictionary).is_empty():
				_armor_equipment_records[migrated_slot] = _create_record(migrated_equipment)
		# 迁移远程武器；旧远程模板删除后若全部槽位为空，只补入一把如我所书并保留第二槽为空。
		if _find_first_equipped_ranged_slot() < 0 and not DEFAULT_RANGED_WEAPON_IDS.is_empty():
			# 迁移远程资源；加载失败时保持空槽，避免损坏清单阻断其余存档恢复。
			var migrated_ranged_weapon: Resource = _load_weapon_resource(DEFAULT_RANGED_WEAPON_IDS[0])
			if migrated_ranged_weapon != null:
				_ranged_equipment_records[0] = _create_record(migrated_ranged_weapon)
		# 迁移近战武器；只有旧资源已失效并留下空槽时才补入银河球棒，不覆盖仍可恢复的专属内容。
		if _melee_equipment_record.is_empty():
			# 迁移近战资源；加载失败时保持空槽并允许玩家之后从商店或掉落重新获得。
			var migrated_melee_weapon: Resource = _load_weapon_resource(DEFAULT_MELEE_WEAPON_ID)
			if migrated_melee_weapon != null:
				_melee_equipment_record = _create_record(migrated_melee_weapon)
		_loaded_inventory_requires_resave = true
	if not has_separate_warehouse:
		_sort_warehouse_default()
	return true


func _serialize_record(record: Dictionary) -> Dictionary:
	if record.is_empty():
		return {}
	# 记录资源；取值为武器 Resource，缺失时返回空字典避免写入不可恢复记录。
	var item_resource: Resource = record.get("resource") as Resource
	if item_resource == null:
		return {}
	# 通用序列化记录；版本 3 保存物品类型、堆叠数量和运行时强化词条。
	var serialized_record: Dictionary = {
		"record_id": str(record.get("record_id", "")),
		"item_kind": str(item_resource.get("item_kind")),
		"weapon_id": str(item_resource.get("weapon_id")),
		"equipment_id": str(item_resource.get("equipment_id")),
		"resource_path": _resolve_resource_path(item_resource),
		"quantity": clampi(int(record.get("quantity", 1)), 1, MAX_STACK_QUANTITY),
		"acquired_at": float(record.get("acquired_at", 0.0)),
		"acquisition_sequence": int(record.get("acquisition_sequence", 0)),
		"last_extraction_epoch": int(record.get("last_extraction_epoch", 0)),
	}
	if _is_enhancement_stone(item_resource):
		# 强化石品质；版本 4 起与实际百分比一起保存，旧存档读取时回退为低级。
		# 方向化存档补充：当前版本只保存品质、属性和方向，旧百分比读取后会归一化为 +/-1。
		serialized_record["quality_id"] = str(item_resource.get("quality_id"))
		serialized_record["target_kind"] = str(item_resource.get("target_kind"))
		serialized_record["display_name"] = str(item_resource.get("display_name"))
		serialized_record["description"] = str(item_resource.get("description"))
		serialized_record["icon_text"] = str(item_resource.get("icon_text"))
		serialized_record["value"] = int(item_resource.get("value"))
		serialized_record["modifiers"] = EnhancementRules.normalize_modifiers(item_resource.get("modifiers") as Dictionary)
	elif _is_repair_kit(item_resource):
		# 修复包字段；保存稳定标识与显示配置，允许未来运行时生成的道具安全恢复。
		serialized_record["item_id"] = str(item_resource.get("item_id"))
		serialized_record["display_name"] = str(item_resource.get("display_name"))
		serialized_record["description"] = str(item_resource.get("description"))
		serialized_record["icon_text"] = str(item_resource.get("icon_text"))
		serialized_record["value"] = int(item_resource.get("value"))
		serialized_record["repair_amount"] = maxf(float(item_resource.get("repair_amount")), 0.0)
	elif _is_consumable(item_resource):
		# 消耗品字段；保存稳定 ID 与结构化限时效果，资源路径变化时仍可按存档内容恢复。
		serialized_record["item_id"] = str(item_resource.get("item_id"))
		serialized_record["display_name"] = str(item_resource.get("display_name"))
		serialized_record["description"] = str(item_resource.get("description"))
		serialized_record["icon_text"] = str(item_resource.get("icon_text"))
		serialized_record["value"] = int(item_resource.get("value"))
		serialized_record["effect_stat"] = str(item_resource.get("effect_stat"))
		serialized_record["effect_amount"] = maxf(float(item_resource.get("effect_amount")), 0.0)
		serialized_record["duration_seconds"] = maxf(float(item_resource.get("duration_seconds")), 0.01)
	elif _is_equipment_resource(item_resource):
		# 防具运行时字段；保存耐久和强化累计值，基础属性继续由项目模板提供。
		serialized_record["enhancement_formula_version"] = ENHANCEMENT_FORMULA_VERSION
		serialized_record["enhancement_modifiers"] = (item_resource.get("enhancement_modifiers") as Dictionary).duplicate(true)
		serialized_record["current_durability"] = maxf(float(item_resource.get("current_durability")), 0.0)
		serialized_record["max_durability"] = _get_resource_maximum_durability(item_resource)
	elif item_resource.has_method("get_enhancement_ratio"):
		# 武器强化公式版本；与装备共用版本号，旧存档可按基础值迁移加算属性而不改变既有最终值。
		serialized_record["enhancement_formula_version"] = ENHANCEMENT_FORMULA_VERSION
		serialized_record["enhancement_modifiers"] = EnhancementRules.migrate_stat_aliases(item_resource.get("enhancement_modifiers") as Dictionary)
		serialized_record["current_durability"] = maxf(float(item_resource.get("current_durability")), 0.0)
		serialized_record["max_durability"] = _get_resource_maximum_durability(item_resource)
	return serialized_record


func _deserialize_record(serialized_record: Dictionary, register_encyclopedia_discovery: bool = true) -> Dictionary:
	## 从存档或临时快照恢复记录；真实库存恢复默认补登记图鉴，商店等只读临时快照必须关闭发现登记。
	# 物品类型；旧版存档缺失时按武器处理，保证版本 1/2 存档可继续读取。
	var item_kind: String = str(serialized_record.get("item_kind", "weapon"))
	# 武器标识；取值为稳定 weapon_id，资源路径失效时用于默认表兜底加载。
	var weapon_id: String = str(serialized_record.get("weapon_id", ""))
	# 装备标识；版本 8 起用于恢复四部位装备模板。
	var equipment_id: String = str(serialized_record.get("equipment_id", ""))
	# 资源路径；取值为项目内 tres 路径，默认优先使用以支持以后新增武器。
	var resource_path: String = str(serialized_record.get("resource_path", ""))
	# 恢复资源；取值为模板深拷贝，保证同类多件物品仍是独立实例。
	var item_resource: Resource
	if item_kind == "enhancement_stone":
		# 强化石资源；由存档字段直接重建，避免依赖项目内固定 tres 模板。
		var enhancement_stone: EnhancementStoneData = EnhancementStoneData.new()
		enhancement_stone.quality_id = str(serialized_record.get("quality_id", EnhancementRules.QUALITY_LOW))
		enhancement_stone.target_kind = str(serialized_record.get("target_kind", "weapon"))
		# 恢复显示名称；旧存档的通用“强化石”自动升级为对应品质名称。
		var saved_display_name: String = str(serialized_record.get("display_name", ""))
		enhancement_stone.display_name = EnhancementStoneData._build_display_name(enhancement_stone.quality_id, enhancement_stone.get_resolved_target_kind()) if saved_display_name.is_empty() or not ("武器强化石" in saved_display_name or "装备强化石" in saved_display_name) else saved_display_name
		enhancement_stone.description = str(serialized_record.get("description", enhancement_stone.description))
		enhancement_stone.icon_text = str(serialized_record.get("icon_text", enhancement_stone.icon_text))
		# 有效强化词条；归一化时自动移除不再进入强化石系统的离散武器机制，其他词条与方向保持不变。
		var normalized_modifiers: Dictionary = EnhancementRules.normalize_modifiers(serialized_record.get("modifiers", {}) as Dictionary)
		if normalized_modifiers.is_empty():
			# 空强化石没有可展示或可应用属性，载入时直接丢弃以免形成无法处理的库存记录。
			return {}
		enhancement_stone.modifiers = normalized_modifiers
		# 迁移后价值；继续遵守每条有效词条 30 金币，移除旧词条后不会保留已经失效的价值。
		enhancement_stone.value = EnhancementStoneData.VALUE_PER_MODIFIER * normalized_modifiers.size()
		item_resource = enhancement_stone
	elif item_kind == "repair_kit":
		# 修复包资源；优先从项目模板深拷贝恢复，字段异常时仍可按存档内容构建独立道具。
		var repair_kit: RepairKitData = _load_repair_kit_resource(str(serialized_record.get("item_id", "")), resource_path) as RepairKitData
		if repair_kit == null:
			repair_kit = RepairKitData.new()
		repair_kit.item_id = str(serialized_record.get("item_id", repair_kit.item_id))
		repair_kit.display_name = str(serialized_record.get("display_name", repair_kit.display_name))
		repair_kit.description = str(serialized_record.get("description", repair_kit.description))
		repair_kit.icon_text = str(serialized_record.get("icon_text", repair_kit.icon_text))
		repair_kit.value = maxi(int(serialized_record.get("value", serialized_record.get("sell_price", repair_kit.value))), 0)
		repair_kit.repair_amount = maxf(float(serialized_record.get("repair_amount", repair_kit.repair_amount)), 1.0)
		item_resource = repair_kit
	elif item_kind == "consumable":
		# 消耗品资源；优先从内容目录模板恢复，缺失时使用存档结构化字段重建。
		var consumable: Resource = _load_item_resource(str(serialized_record.get("item_id", "")), resource_path)
		if consumable == null:
			consumable = ConsumableData.new()
		consumable.set("item_id", str(serialized_record.get("item_id", consumable.get("item_id"))))
		consumable.set("display_name", str(serialized_record.get("display_name", consumable.get("display_name"))))
		consumable.set("description", str(serialized_record.get("description", consumable.get("description"))))
		consumable.set("icon_text", str(serialized_record.get("icon_text", consumable.get("icon_text"))))
		consumable.set("value", maxi(int(serialized_record.get("value", consumable.get("value"))), 0))
		consumable.set("effect_stat", str(serialized_record.get("effect_stat", consumable.get("effect_stat"))))
		consumable.set("effect_amount", maxf(float(serialized_record.get("effect_amount", consumable.get("effect_amount"))), 0.0))
		consumable.set("duration_seconds", maxf(float(serialized_record.get("duration_seconds", consumable.get("duration_seconds"))), 0.01))
		item_resource = consumable
	elif item_kind == "equipment":
		item_resource = _load_equipment_resource(equipment_id, resource_path)
	else:
		item_resource = _load_weapon_resource(weapon_id, resource_path)
	if item_resource == null:
		return {}
	if (_is_weapon_resource(item_resource) or _is_equipment_resource(item_resource)) and serialized_record.get("enhancement_modifiers") is Dictionary:
		_restore_enhancement_modifiers(item_resource, serialized_record)
	if _is_weapon_resource(item_resource):
		# 恢复耐久；旧存档缺少字段时按模板最大耐久恢复满值，避免升级后全部旧武器意外损坏。
		# 模板最大耐久；当前所有武器默认 500.0，后续单独修改上限时仍作为本次加载的最终上限。
		var template_max_durability: float = _get_resource_maximum_durability(item_resource)
		# 存档最大耐久；版本 5 只保存当前耐久，缺失上限时按旧系统 100.0 推断并保持原耐久比例。
		var saved_max_durability: float = maxf(float(serialized_record.get("max_durability", LEGACY_DURABILITY_MAX)), 1.0)
		# 存档当前耐久；更旧存档完全缺失耐久时直接恢复为当前模板满耐久。
		var saved_current_durability: float = float(serialized_record.get("current_durability", saved_max_durability))
		# 恢复耐久；按保存时上限比例映射到当前 500.0 基础上限，避免历史满耐久物品被误判为残损状态。
		var restored_durability: float = template_max_durability * clampf(saved_current_durability / saved_max_durability, 0.0, 1.0)
		if item_resource.has_method("set_current_durability"):
			item_resource.call("set_current_durability", restored_durability)
		else:
			item_resource.set("current_durability", restored_durability)
	if _is_equipment_resource(item_resource):
		# 防具耐久恢复；使用与武器相同的按比例迁移规则。
		var equipment_max_durability: float = _get_resource_maximum_durability(item_resource)
		var saved_equipment_max_durability: float = maxf(float(serialized_record.get("max_durability", equipment_max_durability)), 1.0)
		var saved_equipment_current_durability: float = float(serialized_record.get("current_durability", saved_equipment_max_durability))
		item_resource.call("set_current_durability", equipment_max_durability * clampf(saved_equipment_current_durability / saved_equipment_max_durability, 0.0, 1.0))
	# 恢复记录；保留编号和获得时间，序号缺失时使用当前递增值。
	var record: Dictionary = _create_record(item_resource, float(serialized_record.get("acquired_at", 0.0)), str(serialized_record.get("record_id", "")), register_encyclopedia_discovery)
	record["acquisition_sequence"] = int(serialized_record.get("acquisition_sequence", record.get("acquisition_sequence", 0)))
	record["last_extraction_epoch"] = int(serialized_record.get("last_extraction_epoch", 0))
	record["quantity"] = clampi(int(serialized_record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
	_acquisition_sequence = maxi(_acquisition_sequence, int(record["acquisition_sequence"]))
	return record


func _restore_enhancement_modifiers(item_resource: Resource, serialized_record: Dictionary) -> void:
	if item_resource == null or not (serialized_record.get("enhancement_modifiers") is Dictionary):
		return
	# 存档强化词典；新版本直接恢复，旧版本会先把加算属性从基础值比例转换为等效百分点。
	var restored_modifiers: Dictionary = EnhancementRules.migrate_stat_aliases(serialized_record.get("enhancement_modifiers") as Dictionary)
	# 存档公式版本；缺失视为旧乘算版本，商店快照和库存记录都可使用同一迁移入口。
	var formula_version: int = int(serialized_record.get("enhancement_formula_version", 1))
	if formula_version < ENHANCEMENT_FORMULA_VERSION:
		# 加算属性基础值；只读取迁移所需字段，避免存档服务了解武器或装备的其他内部属性。
		var additive_base_values: Dictionary = {}
		for raw_stat_name in EnhancementRules.ADDITIVE_POINT_STATS.keys():
			# 加算属性名；固定来自规则目录，转换为 String 后用于调用资源统一基础属性接口。
			var stat_name: String = str(raw_stat_name)
			additive_base_values[stat_name] = float(item_resource.call("get_base_stat", stat_name)) if item_resource.has_method("get_base_stat") else float(item_resource.get(stat_name))
		restored_modifiers = EnhancementRules.convert_legacy_enhancement_modifiers(restored_modifiers, additive_base_values)
	item_resource.set("enhancement_modifiers", restored_modifiers)


func _load_weapon_resource(weapon_id: String, preferred_path: String = "") -> Resource:
	# 实际资源路径；优先使用存档路径，缺失时按稳定武器标识查询默认表。
	var resolved_path: String = preferred_path
	if resolved_path.is_empty():
		resolved_path = _get_catalog_resource_path("weapon", weapon_id, str(WEAPON_RESOURCE_PATHS.get(weapon_id, "")))
	if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
		return null
	# 武器模板；取值为项目 Resource，加载成功后深拷贝为独立物品实例。
	var weapon_template: Resource = load(resolved_path) as Resource
	if weapon_template == null:
		return null
	# 独立资源；取值为模板深拷贝，复制失败时回退模板以保证存档可用。
	var duplicated_resource: Resource = weapon_template.duplicate(true) as Resource
	return duplicated_resource if duplicated_resource != null else weapon_template


func _load_repair_kit_resource(item_id: String, preferred_path: String = "") -> Resource:
	# 实际资源路径；优先读取存档路径，缺失时按稳定修复包标识回退项目默认表。
	var resolved_path: String = preferred_path
	if resolved_path.is_empty():
		resolved_path = _get_catalog_resource_path("item", item_id, str(REPAIR_KIT_RESOURCE_PATHS.get(item_id, "")))
	if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
		return null
	# 修复包模板；读取成功后深拷贝，确保拾取或购买的同类道具不会共享运行时资源状态。
	var repair_kit_template: Resource = load(resolved_path) as Resource
	if repair_kit_template == null:
		return null
	# 独立修复包资源；复制失败时回退模板，仍保持存档可读取。
	var duplicated_resource: Resource = repair_kit_template.duplicate(true) as Resource
	return duplicated_resource if duplicated_resource != null else repair_kit_template


func _load_item_resource(item_id: String, preferred_path: String = "") -> Resource:
	## 从通用道具目录加载并复制资源；消耗品与以后新增道具通过同一内容目录 ID 恢复。
	# 实际资源路径；优先使用存档路径，否则查询 ContentCatalog 的通用 item 索引。
	var resolved_path: String = preferred_path if not preferred_path.is_empty() else _get_catalog_resource_path("item", item_id)
	if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
		return null
	# 道具模板；深拷贝避免同类堆叠记录共享可变运行时字段。
	var item_template: Resource = load(resolved_path) as Resource
	var duplicated_resource: Resource = item_template.duplicate(true) as Resource if item_template != null else null
	return duplicated_resource if duplicated_resource != null else item_template


func _load_equipment_resource(equipment_id: String, preferred_path: String = "") -> Resource:
	# 装备路径；优先使用存档资源路径，缺失时按稳定 ID 回退默认表。
	var resolved_path: String = preferred_path if not preferred_path.is_empty() else _get_catalog_resource_path("equipment", equipment_id, str(EQUIPMENT_RESOURCE_PATHS.get(equipment_id, "")))
	if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
		return null
	# 装备模板；深拷贝保证同类多件装备的耐久和强化状态互不影响。
	var equipment_template: Resource = load(resolved_path) as Resource
	var duplicated_resource: Resource = equipment_template.duplicate(true) as Resource if equipment_template != null else null
	return duplicated_resource if duplicated_resource != null else equipment_template


func _resolve_resource_path(item_resource: Resource) -> String:
	if item_resource == null:
		return ""
	if not item_resource.resource_path.is_empty():
		return item_resource.resource_path
	if _is_repair_kit(item_resource):
		return _get_catalog_resource_path("item", str(item_resource.get("item_id")), str(REPAIR_KIT_RESOURCE_PATHS.get(str(item_resource.get("item_id")), "")))
	if _is_consumable(item_resource):
		return _get_catalog_resource_path("item", str(item_resource.get("item_id")))
	if _is_equipment_resource(item_resource):
		return _get_catalog_resource_path("equipment", str(item_resource.get("equipment_id")), str(EQUIPMENT_RESOURCE_PATHS.get(str(item_resource.get("equipment_id")), "")))
	return _get_catalog_resource_path("weapon", str(item_resource.get("weapon_id")), str(WEAPON_RESOURCE_PATHS.get(str(item_resource.get("weapon_id")), "")))


func _get_catalog_resource_path(content_kind: String, content_id: String, fallback_path: String = "") -> String:
	# 内容目录；按类型调用稳定 ID 查询，自动加载缺失或未找到时返回原硬编码表保证旧存档兼容。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog == null:
		return fallback_path
	# 查询方法；武器、装备和通用道具分别使用独立命名，避免内容类型之间错误恢复。
	var method_name: String = "get_%s_path" % content_kind
	if not content_catalog.has_method(method_name):
		return fallback_path
	# 自动路径；非空时优先使用，使外部复制内容可在后续读档中通过稳定 ID 恢复。
	var catalog_path: String = str(content_catalog.call(method_name, content_id))
	return catalog_path if not catalog_path.is_empty() else fallback_path


func _get_registered_resource_paths(content_kind: String) -> Dictionary:
	# 路径表；先复制内置配置，再合并内容目录，开发者发放可覆盖全部自动发现资源。
	var result: Dictionary = {}
	# 内置兼容路径；按内容类型选择旧硬编码表，自动加载不可用时仍支持已有物品与存档。
	var fallback_paths: Dictionary = WEAPON_RESOURCE_PATHS if content_kind == "weapon" else (EQUIPMENT_RESOURCE_PATHS if content_kind == "equipment" else REPAIR_KIT_RESOURCE_PATHS)
	# 可用性目录；存在时复核内置兼容路径，防止已归入扩展包的旧资源绕过角色解锁过滤。
	var availability_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	for raw_id in fallback_paths.keys():
		# 内置资源路径；空值或当前锁定扩展包路径不进入开发者全量发放清单。
		var fallback_path: String = str(fallback_paths.get(raw_id, ""))
		if availability_catalog != null and availability_catalog.has_method("is_content_path_available") and not bool(availability_catalog.call("is_content_path_available", fallback_path)):
			continue
		result[str(raw_id)] = fallback_path
	# 内容目录；通过路径加载稳定 ID，忽略类型错误或空 ID 的文件。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog == null:
		return result
	# 路径列表查询方法；按内容类型映射到目录服务公开接口。
	var paths_method: String = "get_%s_paths" % content_kind
	if not content_catalog.has_method(paths_method):
		return result
	for resource_path in content_catalog.call(paths_method) as PackedStringArray:
		# 内容模板；加载稳定 ID 用于建立 ID 到路径的开发者发放与存档恢复映射。
		var content_resource: Resource = load(resource_path) as Resource
		if content_resource == null:
			continue
		# ID 属性名；武器、装备和道具各使用自身资源协议中的稳定字段。
		var id_property: String = "weapon_id" if content_kind == "weapon" else ("equipment_id" if content_kind == "equipment" else "item_id")
		# 内容稳定 ID；空值不会覆盖兼容路径表，避免无法恢复的资源进入发放列表。
		var content_id: String = str(content_resource.get(id_property)).strip_edges()
		if not content_id.is_empty():
			result[content_id] = resource_path
	return result
