extends Node

## 骇入保险服务在全部场景中持续运行，统一维护保单状态、死亡理赔、账户统计与独立存档。
## 玩家在局外为下一局正式骇入投保；仅“角色死亡”结算按实际丢失价值的固定比例赔付星穹，
## 主动逃跑与退出不予赔付，成功撤离计入安全记录。保费、赔付与安全撤离会累计为
## “星海互助保险”股票的行为影响，由股市服务在正式结算时通过公开接口一次性取走。

## 保单状态变化信号；投保成功与保单结算消耗后发送，保险面板据此刷新保单卡片。
signal policy_changed
## 保单结算完成信号；参数为结算类型（claim/safe/void）与说明文本，面板据此展示结算反馈。
signal insurance_settled(result_type: String, message: String)
## 理赔到账信号；仅死亡赔付路径发出，参数为到账星穹与说明文本，横幅通知服务据此提醒玩家。
signal claim_paid(gold_amount: int, message: String)

## 保险独立存档路径；与库存、股市存档分离，避免保单字段污染其他玩法的序列化结构。
const SAVE_PATH: String = "user://insurance_state.json"
## 保险存档版本；版本 1 保存保单状态、账户统计、理赔记录与待结算的股票行为累计值。
const SAVE_VERSION: int = 1
## 基础保费费率；默认 12%，精算办公室每级降低 0.5 个百分点，最低压到 9.5%。
const PREMIUM_RATE_BASE: float = 0.12
## 死亡赔付比例；默认按实际丢失价值（不超过投保基准）的 80% 向下取整赔付星穹。
const CLAIM_PAYOUT_RATIO: float = 0.80
## 理赔记录保留上限；默认 30 条，索引 0 为最新，超出后丢弃最旧记录，防止存档无限膨胀。
const CLAIM_RECORD_LIMIT: int = 30
## 死亡结算标题；与战斗 HUD 传入库存服务的失败原因保持一致，只有该标题触发赔付。
const DEATH_OUTCOME_TITLE: String = "角色死亡"

## 保单是否生效中；默认 false，投保后保持到下一局正式骇入结算时消耗。
var _policy_active: bool = false
## 保单投保基准价值；默认 0，投保瞬间的随身物品总价值，同时作为赔付上限基准。
var _policy_insured_value: int = 0
## 保单已支付保费；默认 0，仅用于面板展示与统计，不参与赔付计算。
var _policy_premium_paid: int = 0
## 保单锁定的赔付比例；默认为基础比例，投保瞬间锁定，后续规则调整不影响已生效保单。
var _policy_claim_ratio: float = CLAIM_PAYOUT_RATIO
## 待结算的累计保费价值；默认 0，正式结算时由股市服务取走并换算为保险股正向影响。
var _pending_premium_gold: int = 0
## 待结算的累计赔付价值；默认 0，正式结算时由股市服务取走并换算为保险股负向影响。
var _pending_claim_gold: int = 0
## 待结算的安全撤离次数；默认 0，投保状态下成功撤离累计，换算为保险股正向影响。
var _pending_safe_extractions: int = 0
## 历史累计保费；默认 0，只增不减，用于面板账户统计展示。
var _total_premium_paid: int = 0
## 历史累计赔付；默认 0，只增不减，用于面板账户统计展示。
var _total_claims_paid: int = 0
## 历史累计投保次数；默认 0，只增不减，用于面板账户统计展示。
var _total_policies_bought: int = 0
## 历史累计安全撤离次数；默认 0，投保状态下成功撤离才累计。
var _total_safe_extractions: int = 0
## 理赔与结算记录列表；每项包含时间与说明文本，索引 0 为最新记录，随保险存档持久化。
var _claim_records: Array = []
## 上一帧正式对局活动状态；用于从 GlobalInventory 的无参数状态信号识别对局完成边界。
var _previous_run_active: bool = false
## 全局库存服务缓存；默认从 Autoload 获取，用于随身价值统计、保费扣除与赔付发放。
var _global_inventory: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if not _load_state():
		_save_state()
	# 战斗状态信号；保险服务必须先于股市服务注册，保证死亡理赔在股市正式结算刷新之前完成累计。
	if _global_inventory != null and _global_inventory.has_signal("run_state_changed"):
		_global_inventory.connect("run_state_changed", Callable(self, "_on_run_state_changed"))
	_previous_run_active = _is_combat_run_active()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()


func has_active_policy() -> bool:
	## 查询是否存在生效中的保单；同一时间最多一份保单，投保入口据此禁用。
	return _policy_active


func get_policy_snapshot() -> Dictionary:
	## 返回保单展示快照；无保单时返回空字典，面板据此渲染保单卡片。
	if not _policy_active:
		return {}
	return {
		"insured_value": _policy_insured_value,
		"premium_paid": _policy_premium_paid,
		"claim_ratio": _policy_claim_ratio,
	}


func get_premium_rate() -> float:
	## 返回当前保费费率；基础 12% 扣除精算办公室每级 0.5 个百分点，最低不低于 1%。
	# 据点服务；缺失时按无折扣处理，保险投保仍可独立运行。
	var hideout_service: Node = get_tree().root.get_node_or_null("HideoutService")
	# 费率降低值；由精算办公室等级换算，最高 2.5 个百分点。
	var rate_reduction: float = float(hideout_service.call("get_insurance_rate_reduction")) if hideout_service != null and hideout_service.has_method("get_insurance_rate_reduction") else 0.0
	return maxf(PREMIUM_RATE_BASE - rate_reduction, 0.01)


func get_current_carried_value() -> int:
	## 返回当前背包与全部装备槽的物品总价值；投保基准与保费都以该值为基础，只读不修改库存。
	if _global_inventory == null:
		return 0
	# 随身价值累计；背包按堆叠数量累计，装备槽逐件累计。
	var total_value: int = 0
	if _global_inventory.has_method("get_backpack_entries"):
		for raw_entry in _global_inventory.call("get_backpack_entries") as Array:
			if not (raw_entry is Dictionary):
				continue
			# 背包条目字典；提供资源引用与堆叠数量。
			var entry: Dictionary = raw_entry as Dictionary
			total_value += _get_resource_value(entry.get("resource") as Resource) * maxi(int(entry.get("quantity", 1)), 1)
	# 装备槽位置列表；两个远程槽、唯一近战槽与四个防具部位，与库存服务稳定位置标识一致。
	var equipment_locations: Array[String] = ["ranged_0", "ranged_1", "melee", "armor_head", "armor_body", "armor_legs", "armor_feet"]
	if _global_inventory.has_method("get_equipment_location_resource"):
		for location in equipment_locations:
			total_value += _get_resource_value(_global_inventory.call("get_equipment_location_resource", location) as Resource)
	return maxi(total_value, 0)


func get_premium_quote() -> Dictionary:
	## 生成当前投保报价；返回随身价值、费率与保费预览，确认投保时服务仍会重新计算。
	# 当前随身价值；投保基准与赔付上限都以此为准。
	var carried_value: int = get_current_carried_value()
	# 当前保费费率；含精算办公室折扣。
	var premium_rate: float = get_premium_rate()
	return {
		"carried_value": carried_value,
		"premium_rate": premium_rate,
		"premium": maxi(ceili(float(carried_value) * premium_rate), 1) if carried_value > 0 else 0,
		"claim_ratio": CLAIM_PAYOUT_RATIO,
	}


func purchase_policy() -> Dictionary:
	## 购买一份下一局保单；立即扣除保费，保单保持到下一局正式骇入结算，期间不可退保。
	if _policy_active:
		return {"success": false, "message": "已有生效中的保单"}
	if _is_combat_run_active():
		return {"success": false, "message": "战斗期间无法投保"}
	# 投保实时报价；确认瞬间重新计算随身价值与保费。
	var quote: Dictionary = get_premium_quote()
	# 投保基准价值；没有随身物品时保单没有意义，直接拒绝。
	var insured_value: int = int(quote.get("carried_value", 0))
	if insured_value <= 0:
		return {"success": false, "message": "当前没有可投保的随身物品"}
	# 本次保费；至少 1 星穹，向上取整。
	var premium: int = int(quote.get("premium", 0))
	if _global_inventory == null or not _global_inventory.has_method("spend_coins"):
		return {"success": false, "message": "星穹服务不可用"}
	if not bool(_global_inventory.call("spend_coins", premium)):
		return {"success": false, "message": "星穹不足，无法支付保费"}
	_policy_active = true
	_policy_insured_value = insured_value
	_policy_premium_paid = premium
	_policy_claim_ratio = CLAIM_PAYOUT_RATIO
	_pending_premium_gold += premium
	_total_premium_paid += premium
	_total_policies_bought += 1
	_append_claim_record("投保成功：投保价值 %d 星穹，保费 %d 星穹" % [insured_value, premium])
	_flush_linked_saves()
	policy_changed.emit()
	return {"success": true, "message": "投保成功", "insured_value": insured_value, "premium": premium}


func get_account_statistics() -> Dictionary:
	## 返回账户统计快照；面板据此展示累计保费、累计赔付、投保次数与安全撤离次数。
	return {
		"total_premium": _total_premium_paid,
		"total_claims": _total_claims_paid,
		"total_policies": _total_policies_bought,
		"total_safe_extractions": _total_safe_extractions,
	}


func get_claim_records() -> Array:
	## 返回理赔与结算记录深复制副本；索引 0 为最新记录，外部修改不影响服务内部状态。
	return _claim_records.duplicate(true)


func consume_market_impact() -> Dictionary:
	## 取走并清空待结算的股票行为累计值；股市服务在每次正式结算时调用，保证影响只生效一次。
	# 累计值快照；交给股市服务后立即清零，重复调用返回全零。
	var impact: Dictionary = {
		"premium_gold": _pending_premium_gold,
		"claim_gold": _pending_claim_gold,
		"safe_extractions": _pending_safe_extractions,
	}
	if _pending_premium_gold != 0 or _pending_claim_gold != 0 or _pending_safe_extractions != 0:
		_pending_premium_gold = 0
		_pending_claim_gold = 0
		_pending_safe_extractions = 0
		_save_state()
	return impact


func _on_run_state_changed() -> void:
	# 当前正式对局活动状态；与上一状态比较，只在对局完成边界结算保单。
	var is_active: bool = _is_combat_run_active()
	if not is_active and _previous_run_active and _policy_active:
		_settle_policy_after_run()
	_previous_run_active = is_active


func _settle_policy_after_run() -> void:
	## 按最近一次战斗结算消耗保单；死亡赔付、成功撤离计安全记录、主动脱离不予赔付。
	if _global_inventory == null or not _global_inventory.has_method("get_last_run_outcome"):
		return
	# 最近一次战斗结算；包含成功或失败类型、失败标题与实际丢失条目。
	var outcome: Dictionary = _global_inventory.call("get_last_run_outcome") as Dictionary
	# 保单快照字段；先取出再消耗保单，防止信号回调期间读取到中间状态。
	var insured_value: int = _policy_insured_value
	# 保单锁定赔付比例；投保瞬间写入，结算时原样使用。
	var claim_ratio: float = _policy_claim_ratio
	_policy_active = false
	_policy_insured_value = 0
	_policy_premium_paid = 0
	if str(outcome.get("result", "failure")) == "success":
		# 成功撤离；保单未触发赔付，计入安全撤离并作为保险股正向影响。
		_pending_safe_extractions += 1
		_total_safe_extractions += 1
		_append_claim_record("保单结算：成功撤离，未发生理赔")
		_save_state()
		policy_changed.emit()
		insurance_settled.emit("safe", "本局安全撤离，保单已结算")
		return
	if str(outcome.get("title", "")) != DEATH_OUTCOME_TITLE:
		# 主动逃跑或退出游戏；条款不覆盖主动脱离战斗，保单直接消耗且不赔付。
		_append_claim_record("保单结算：主动脱离战斗，按条款不予赔付")
		_save_state()
		policy_changed.emit()
		insurance_settled.emit("void", "主动脱离战斗，保单不予赔付")
		return
	# 实际丢失总价值；逐条按物品当前有效价值乘丢失数量累计。
	var lost_value: int = 0
	for raw_entry in outcome.get("lost_entries", []) as Array:
		if not (raw_entry is Dictionary):
			continue
		# 丢失条目字典；提供资源引用与实际丢失数量。
		var entry: Dictionary = raw_entry as Dictionary
		lost_value += _get_resource_value(entry.get("resource") as Resource) * maxi(int(entry.get("quantity", 1)), 1)
	# 本次赔付金额；实际丢失价值与投保基准取小后按赔付比例向下取整。
	var payout: int = int(floor(float(mini(lost_value, insured_value)) * claim_ratio))
	if payout <= 0:
		_append_claim_record("保单结算：死亡但没有可赔付的丢失物品")
		_save_state()
		policy_changed.emit()
		insurance_settled.emit("claim", "死亡结算完成，本局没有可赔付的丢失物品")
		return
	if _global_inventory.has_method("adjust_coins"):
		_global_inventory.call("adjust_coins", payout)
	_pending_claim_gold += payout
	_total_claims_paid += payout
	# 理赔说明文本；同时用于记录、结算信号与横幅通知。
	var claim_message: String = "死亡理赔到账 %d 星穹（丢失价值 %d，赔付比例 %d%%）" % [payout, lost_value, int(round(claim_ratio * 100.0))]
	_append_claim_record("保单理赔：%s" % claim_message)
	_flush_linked_saves()
	policy_changed.emit()
	insurance_settled.emit("claim", claim_message)
	claim_paid.emit(payout, claim_message)


func _append_claim_record(message: String) -> void:
	## 追加一条理赔与结算记录并裁剪到上限；索引 0 为最新记录，调用方负责在同一路径保存状态。
	# 本地日期时间字典；直接读取系统本地时间，用于生成玩家可读的月日时分文本。
	var now: Dictionary = Time.get_datetime_dict_from_system()
	# 新结算记录；仅保存时间与说明文本，展示层不需要额外类型字段。
	var record: Dictionary = {
		"time_unix": Time.get_unix_time_from_system(),
		"time_text": "%02d-%02d %02d:%02d" % [int(now.get("month", 1)), int(now.get("day", 1)), int(now.get("hour", 0)), int(now.get("minute", 0))],
		"message": message,
	}
	_claim_records.push_front(record)
	while _claim_records.size() > CLAIM_RECORD_LIMIT:
		_claim_records.pop_back()


func _get_resource_value(item_resource: Resource) -> int:
	## 读取单件物品的当前有效价值；优先使用含耐久与强化折算的有效价值接口，缺失时回退基础价值。
	if item_resource == null:
		return 0
	if item_resource.has_method("get_effective_value"):
		return maxi(int(item_resource.call("get_effective_value")), 0)
	return maxi(int(item_resource.get("value")), 0)


func _is_combat_run_active() -> bool:
	## 查询当前是否处于正式战斗局；与其他局外服务使用同一 GlobalInventory 状态源。
	return _global_inventory != null and _global_inventory.has_method("is_combat_run_active") and bool(_global_inventory.call("is_combat_run_active"))


func _flush_linked_saves() -> void:
	## 立即保存保险与星穹存档；保费与赔付属于跨文件资产变更，同一路径落盘缩短状态不一致窗口。
	_save_state()
	if _global_inventory != null and _global_inventory.has_method("flush_stock_holdings_save"):
		# 库存即时保存接口会保存完整永久星穹数据，名称虽保留股票历史用途，但可安全复用跨存档兑换。
		_global_inventory.call("flush_stock_holdings_save")


func _save_state() -> void:
	# 存档数据；保单、统计与待结算累计值全部为整数，理赔记录随存档持久化。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"policy_active": _policy_active,
		"policy_insured_value": _policy_insured_value,
		"policy_premium_paid": _policy_premium_paid,
		"policy_claim_ratio": _policy_claim_ratio,
		"pending_premium_gold": _pending_premium_gold,
		"pending_claim_gold": _pending_claim_gold,
		"pending_safe_extractions": _pending_safe_extractions,
		"total_premium_paid": _total_premium_paid,
		"total_claims_paid": _total_claims_paid,
		"total_policies_bought": _total_policies_bought,
		"total_safe_extractions": _total_safe_extractions,
		"claim_records": _claim_records,
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
	_policy_active = bool(save_data.get("policy_active", false))
	_policy_insured_value = maxi(int(save_data.get("policy_insured_value", 0)), 0)
	_policy_premium_paid = maxi(int(save_data.get("policy_premium_paid", 0)), 0)
	_policy_claim_ratio = clampf(float(save_data.get("policy_claim_ratio", CLAIM_PAYOUT_RATIO)), 0.0, 1.0)
	if _policy_active and _policy_insured_value <= 0:
		# 保单数据异常兜底；投保基准损坏时直接作废保单，不发放任何赔付。
		_policy_active = false
		_policy_insured_value = 0
		_policy_premium_paid = 0
	_pending_premium_gold = maxi(int(save_data.get("pending_premium_gold", 0)), 0)
	_pending_claim_gold = maxi(int(save_data.get("pending_claim_gold", 0)), 0)
	_pending_safe_extractions = maxi(int(save_data.get("pending_safe_extractions", 0)), 0)
	_total_premium_paid = maxi(int(save_data.get("total_premium_paid", 0)), 0)
	_total_claims_paid = maxi(int(save_data.get("total_claims_paid", 0)), 0)
	_total_policies_bought = maxi(int(save_data.get("total_policies_bought", 0)), 0)
	_total_safe_extractions = maxi(int(save_data.get("total_safe_extractions", 0)), 0)
	# 原始理赔记录列表；非数组结构按空记录处理，超限部分丢弃最旧记录。
	var raw_records: Variant = save_data.get("claim_records", [])
	_claim_records = (raw_records as Array).duplicate(true) if raw_records is Array else []
	while _claim_records.size() > CLAIM_RECORD_LIMIT:
		_claim_records.pop_back()
	return true
