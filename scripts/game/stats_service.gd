extends Node

## 生涯统计服务：集中记录怪物击杀计数、物品获得计数、对局与撤离统计、单局之最和财富曲线采样，并聚合全局库存维护的累计获得星穹。
## 近期战绩补充：同一服务还拥有单局造成/受到伤害、击杀、开箱和最近 20 局完成快照，结算与战绩界面不保存副本。
## 战斗与库存挂点只上报事实事件，本服务负责口径判定、累计与独立持久化；
## 统计面板、图鉴计数与悬赏系统都只读取本服务或订阅其信号，不各自维护第二份计数。
## 统计口径：只有产出结算的战斗模式（标准骇入、零装骇入，含联机）计入；训练场与超频骇入不计。
## 联机击杀口径：按“本机确认击杀”计数——单机记录本机世界全部击杀，联机按主机回传的击杀归属只记本人击杀。

## 任意统计数值变化信号；统计面板与图鉴按此刷新展示，参数不携带明细避免高频拷贝。
## 战绩刷新补充：正式对局完成时同样派发，已打开的近期战绩面板会重新读取最多 20 条快照。
signal stats_changed
## 怪物击杀事件信号；参数为怪物稳定 ID，悬赏服务订阅它推进击杀类悬赏进度。
signal monster_kill_recorded(monster_id: String)
## 宝箱开启事件信号；参数为宝箱品质标识（common/medium/high/supreme），悬赏服务订阅它推进宝箱类悬赏。
signal chest_open_recorded(quality_id: String)
## 单局物资送回累计信号；参数为本局累计送回价值，悬赏服务订阅它判定“单局送回价值”类悬赏。
signal run_shipped_value_changed(run_shipped_value: int)
## 对局结束信号；参数为结果标识（success/death/escape）、存活秒数与带出价值，悬赏服务订阅它判定撤离类悬赏。
signal run_finished(result_id: String, survival_seconds: float, extracted_value: int)

## 统计存档路径；独立文件保存，纳入导出、导入与删除存档白名单。
const SAVE_PATH: String = "user://stats_state.json"
## 统计存档版本；默认 1 标识当前写入结构，未来字段调整时用于兼容判断。
## 版本演进补充：当前值为 2，用于保存最近 20 局正式战绩；版本 1 存档缺少该字段时按空记录兼容。
const SAVE_VERSION: int = 2
## 对局结果标识：成功撤离。
const RUN_RESULT_SUCCESS: String = "success"
## 对局结果标识：死亡。
const RUN_RESULT_DEATH: String = "death"
## 对局结果标识：主动逃跑。
const RUN_RESULT_ESCAPE: String = "escape"
## 强化石统一统计键；随机强化石没有固定模板，与图鉴共用单一资源类别条目口径。
const ENHANCEMENT_STONE_STATISTICS_KEY: String = "enhancement_stone:any"
## 财富曲线采样上限；默认 240 个点，超出后移除最早采样，防止长期游玩导致存档无限膨胀。
const WEALTH_SAMPLE_LIMIT: int = 240
## 近期战绩保存上限；固定保留最新 20 局正式结算，超出后移除最早记录，避免存档随游玩局数无限增长。
const RECENT_RUN_HISTORY_LIMIT: int = 20

## 怪物击杀计数表；键为怪物稳定 monster_id，值为累计击杀数量，训练场与超频骇入不计入。
var _monster_kill_counts: Dictionary = {}
## 物品获得计数表；键与图鉴发现键同构（item_kind:稳定ID，强化石统一键），值为累计获得数量。
var _item_acquire_counts: Dictionary = {}
## 已开始正式对局总数；标准与零装骇入进入战斗即计 1，中途关闭进程的对局也保留在分母中。
var _total_runs_started: int = 0
## 成功撤离总数；只统计正式战斗模式的成功撤离结算。
var _total_success_extractions: int = 0
## 死亡结算总数；只统计正式战斗模式的死亡结算。
var _total_deaths: int = 0
## 主动逃跑结算总数；只统计正式战斗模式的逃跑结算。
var _total_escapes: int = 0
## 累计击杀总数；与怪物分表同步累加，避免展示时反复求和。
var _total_monster_kills: int = 0
## 累计开启宝箱总数；四种品质合并累计，供统计面板展示。
var _total_chests_opened: int = 0
## 累计送回仓库总价值；全部对局的物资撤离点送回价值之和。
var _total_shipped_value: int = 0
## 单局最多击杀纪录；对局结束时用本局击杀数刷新。
var _best_run_kills: int = 0
## 单局最长存活纪录；单位秒，任何正式对局结束时刷新。
var _best_run_survival_seconds: float = 0.0
## 单局最高带出价值纪录；只在成功撤离时按随身与送回总价值刷新。
var _best_run_extracted_value: int = 0
## 单局最高送回价值纪录；对局结束时用本局送回累计刷新。
var _best_run_shipped_value: int = 0
## 财富曲线采样数组；元素为包含 unix_time 与 total_assets 的字典，按时间先后排列。
var _wealth_samples: Array[Dictionary] = []
## 近期正式战绩数组；索引 0 为最新结算，每项保存结果、时间、单局战斗统计和结算价值，最多 20 项。
var _recent_run_history: Array[Dictionary] = []
## 当前对局击杀计数；对局开始清零，结束时参与单局之最刷新。
var _current_run_kills: int = 0
## 当前对局开启宝箱计数；对局开始清零，正式结算时写入结算快照与近期战绩。
var _current_run_chests_opened: int = 0
## 当前对局本机造成的最终伤害累计；对局开始清零，取值为非负整数伤害之和，训练场与无结算模式不会写入。
var _current_run_damage_dealt: int = 0
## 当前对局玩家实际承受的最终伤害累计；包含被护盾吸收的最终伤害，闪避伤害不计，对局开始时清零。
var _current_run_damage_received: int = 0
## 当前对局送回价值累计；对局开始清零，供“单局送回价值”悬赏与单局之最使用。
var _current_run_shipped_value: int = 0
## 当前是否正在追踪一局正式对局；只在 record_run_started 与 record_run_finished 之间为 true，防止孤立伤害或重复结算生成错误战绩。
var _current_run_tracking_active: bool = false
## 全局库存服务缓存；只读取永久累计获得星穹并转发变化通知，不复制或持久化第二份累计值。
var _global_inventory: Node = null
## 存档是否已排队；默认 false，同一帧多次事件只在帧末写盘一次。
var _save_queued: bool = false


func _ready() -> void:
	_load_state()
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if _global_inventory != null and _global_inventory.has_signal("total_coins_earned_changed"):
		_global_inventory.connect("total_coins_earned_changed", Callable(self, "_on_total_coins_earned_changed"))
	# 启动财富采样；每次启动补一个当前总资产点，保证长时间未进战斗时曲线仍随离线收益更新。
	record_wealth_sample()


# ---------------------------------------------------------------------------
# 事件上报接口（由战斗与库存挂点调用）
# ---------------------------------------------------------------------------

func record_run_started() -> void:
	## 记录一局正式战斗开始；只允许标准与零装骇入的开局挂点调用，训练场与超频骇入不得上报。
	if _is_permanent_progression_suppressed():
		return
	_total_runs_started += 1
	_current_run_tracking_active = true
	_current_run_kills = 0
	_current_run_chests_opened = 0
	_current_run_damage_dealt = 0
	_current_run_damage_received = 0
	_current_run_shipped_value = 0
	_queue_save()
	stats_changed.emit()


func record_monster_killed(monster_id: String) -> void:
	## 记录一次本机确认击杀；空 ID 回退为未知怪物键，训练场与超频骇入由挂点负责不调用本接口。
	if _is_permanent_progression_suppressed():
		return
	# 规范化怪物标识；异常空值统一落入 unknown 键，保证总数与分表一致。
	var resolved_monster_id: String = monster_id.strip_edges()
	if resolved_monster_id.is_empty():
		resolved_monster_id = "unknown"
	_monster_kill_counts[resolved_monster_id] = int(_monster_kill_counts.get(resolved_monster_id, 0)) + 1
	_total_monster_kills += 1
	if _current_run_tracking_active:
		_current_run_kills += 1
	_queue_save()
	monster_kill_recorded.emit(resolved_monster_id)
	stats_changed.emit()


func record_chest_opened(quality_id: String) -> void:
	## 记录一次宝箱开启；联机中只有实际出货的认领端上报，训练场与超频骇入由挂点负责不调用本接口。
	if _is_permanent_progression_suppressed():
		return
	_total_chests_opened += 1
	if _current_run_tracking_active:
		_current_run_chests_opened += 1
	_queue_save()
	chest_open_recorded.emit(quality_id.strip_edges())
	stats_changed.emit()


func record_damage_dealt(final_damage: float) -> void:
	## 记录当前正式对局由本机玩家或归属本机的友方单位对敌人造成的最终伤害；伤害按项目整数飘字口径累计。
	if _is_permanent_progression_suppressed() or not _current_run_tracking_active:
		return
	# 规范化最终伤害；非正值不形成有效伤害事件，小数兼容值按项目统一的四舍五入规则转为整数。
	var resolved_damage: int = maxi(roundi(final_damage), 0)
	if resolved_damage <= 0:
		return
	_current_run_damage_dealt += resolved_damage


func record_damage_received(final_damage: float) -> void:
	## 记录当前正式对局玩家实际收到的最终伤害；闪避不会调用，护盾吸收仍属于有效承伤并计入。
	if _is_permanent_progression_suppressed() or not _current_run_tracking_active:
		return
	# 规范化最终伤害；与造成伤害使用相同整数口径，保证结算显示可直接和战斗飘字核对。
	var resolved_damage: int = maxi(roundi(final_damage), 0)
	if resolved_damage <= 0:
		return
	_current_run_damage_received += resolved_damage


func record_shipped_value(shipped_value: int) -> void:
	## 记录一次物资撤离点送回；同时累计生涯总额与本局额度，本局累计经信号广播给悬赏系统。
	if _is_permanent_progression_suppressed():
		return
	if shipped_value <= 0:
		return
	_total_shipped_value += shipped_value
	if _current_run_tracking_active:
		_current_run_shipped_value += shipped_value
	_queue_save()
	run_shipped_value_changed.emit(_current_run_shipped_value)
	stats_changed.emit()


func record_item_acquired(item_resource: Resource, quantity: int = 1) -> void:
	## 记录物品获得数量；键与图鉴发现键同构，战斗拾取与商店购买共用本入口，读档恢复不得调用。
	if _is_permanent_progression_suppressed():
		return
	# 物品统计键；无法生成稳定键的异常资源不计数。
	var statistics_key: String = get_item_statistics_key(item_resource)
	if statistics_key.is_empty():
		return
	# 规范化数量；至少记 1 件，堆叠购买按实际数量累计。
	var resolved_quantity: int = maxi(quantity, 1)
	_item_acquire_counts[statistics_key] = int(_item_acquire_counts.get(statistics_key, 0)) + resolved_quantity
	_queue_save()
	stats_changed.emit()


func record_run_finished(result_id: String, survival_seconds: float, extracted_value: int) -> Dictionary:
	## 记录一局正式战斗结算；刷新对局计数、单局之最并追加一次财富采样。
	## 近期战绩补充：同一次调用还会持久化完成快照并返回其副本；没有活动正式对局或重复调用时返回空字典。
	if _is_permanent_progression_suppressed() or not _current_run_tracking_active:
		return {}
	# 规范化结果标识；未知取值按逃跑处理，保证三类计数总和不漏计。
	var resolved_result_id: String = result_id
	if resolved_result_id not in [RUN_RESULT_SUCCESS, RUN_RESULT_DEATH, RUN_RESULT_ESCAPE]:
		resolved_result_id = RUN_RESULT_ESCAPE
	# 规范化存活时间；负值按 0 处理，战绩与信号共用同一数值。
	var resolved_survival_seconds: float = maxf(survival_seconds, 0.0)
	# 规范化带出价值；失败与异常负值均按 0 保存，成功撤离值由 HUD 在库存结算前聚合。
	var resolved_extracted_value: int = maxi(extracted_value, 0) if resolved_result_id == RUN_RESULT_SUCCESS else 0
	if resolved_result_id == RUN_RESULT_SUCCESS:
		_total_success_extractions += 1
		_best_run_extracted_value = maxi(_best_run_extracted_value, resolved_extracted_value)
	elif resolved_result_id == RUN_RESULT_DEATH:
		_total_deaths += 1
	else:
		_total_escapes += 1
	_best_run_kills = maxi(_best_run_kills, _current_run_kills)
	_best_run_survival_seconds = maxf(_best_run_survival_seconds, resolved_survival_seconds)
	_best_run_shipped_value = maxi(_best_run_shipped_value, _current_run_shipped_value)
	# 本局完成快照；同时作为结算界面数据源与近期战绩持久化条目，避免两个消费方分别拼装字段。
	var completed_run: Dictionary = {
		"unix_time": int(Time.get_unix_time_from_system()),
		"completed_at": Time.get_datetime_string_from_system(false, true),
		"result_id": resolved_result_id,
		"survival_seconds": resolved_survival_seconds,
		"damage_dealt": _current_run_damage_dealt,
		"damage_received": _current_run_damage_received,
		"monster_kills": _current_run_kills,
		"chests_opened": _current_run_chests_opened,
		"extracted_value": resolved_extracted_value,
		"shipped_value": _current_run_shipped_value,
	}
	_recent_run_history.push_front(completed_run)
	while _recent_run_history.size() > RECENT_RUN_HISTORY_LIMIT:
		_recent_run_history.pop_back()
	_current_run_tracking_active = false
	run_finished.emit(resolved_result_id, resolved_survival_seconds, resolved_extracted_value)
	_current_run_kills = 0
	_current_run_chests_opened = 0
	_current_run_damage_dealt = 0
	_current_run_damage_received = 0
	_current_run_shipped_value = 0
	record_wealth_sample()
	_queue_save()
	stats_changed.emit()
	return completed_run.duplicate()


func _is_permanent_progression_suppressed() -> bool:
	## 返回当前会话是否禁止写入生涯统计与悬赏事实；首次战斗引导和娱乐模式只教学或体验，不形成永久记录。
	# 会话状态服务；独立统计测试缺少服务时保持原有记录行为。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	return session_state != null and session_state.has_method("is_permanent_progression_suppressed") and bool(session_state.call("is_permanent_progression_suppressed"))


func record_wealth_sample() -> void:
	## 追加一次财富曲线采样；优先使用银行总资产口径（星穹+活期+定期+证券币+算力币折算），银行缺失时回退局外星穹。
	# 当前总资产；口径与银行授信基数一致，保证统计面板与银行面板数字可互相印证。
	var total_assets: int = _get_current_total_assets()
	_wealth_samples.append({"unix_time": int(Time.get_unix_time_from_system()), "total_assets": total_assets})
	while _wealth_samples.size() > WEALTH_SAMPLE_LIMIT:
		_wealth_samples.pop_front()
	_queue_save()
	stats_changed.emit()


# ---------------------------------------------------------------------------
# 查询接口（统计面板、图鉴与悬赏读取）
# ---------------------------------------------------------------------------

func get_monster_kill_count(monster_id: String) -> int:
	## 返回指定怪物的累计击杀数量；未击杀过返回 0，图鉴条目计数直接使用本查询。
	return int(_monster_kill_counts.get(monster_id.strip_edges(), 0))


func get_item_acquire_count(item_resource: Resource) -> int:
	## 返回指定物品模板的累计获得数量；强化石返回全部品质合并计数，与图鉴单条目口径一致。
	return int(_item_acquire_counts.get(get_item_statistics_key(item_resource), 0))


func get_enhancement_stone_acquire_count() -> int:
	## 返回全部强化石的累计获得数量；图鉴的强化石通用条目没有固定模板资源，使用本查询读取统一键计数。
	return int(_item_acquire_counts.get(ENHANCEMENT_STONE_STATISTICS_KEY, 0))


func get_item_statistics_key(item_resource: Resource) -> String:
	## 生成物品统计稳定键；与 GlobalInventory 图鉴发现键同构（item_kind:稳定ID，强化石统一键），保证两套口径可互相对照。
	if item_resource == null:
		return ""
	# 物品类型；强化石由随机运行时字段构成，统一映射到单一资源类别键。
	var item_kind: String = str(item_resource.get("item_kind")).strip_edges()
	if item_kind == "enhancement_stone":
		return ENHANCEMENT_STONE_STATISTICS_KEY
	# 稳定物品标识；武器、装备与通用道具分别读取既有 ID 字段，避免不同类型同名 ID 相互覆盖。
	var item_id: String = str(item_resource.get("weapon_id")).strip_edges() if item_kind == "weapon" else (str(item_resource.get("equipment_id")).strip_edges() if item_kind == "equipment" else str(item_resource.get("item_id")).strip_edges())
	return "%s:%s" % [item_kind, item_id] if not item_kind.is_empty() and not item_id.is_empty() else ""


func get_statistics_snapshot() -> Dictionary:
	## 返回统计面板展示快照；全部为值拷贝，调用方只读展示不影响服务状态。
	return {
		"total_runs_started": _total_runs_started,
		"total_success_extractions": _total_success_extractions,
		"total_deaths": _total_deaths,
		"total_escapes": _total_escapes,
		"extraction_rate": float(_total_success_extractions) / float(_total_runs_started) if _total_runs_started > 0 else 0.0,
		"total_monster_kills": _total_monster_kills,
		"total_chests_opened": _total_chests_opened,
		"total_shipped_value": _total_shipped_value,
		"total_coins_earned": _get_total_coins_earned(),
		"best_run_kills": _best_run_kills,
		"best_run_survival_seconds": _best_run_survival_seconds,
		"best_run_extracted_value": _best_run_extracted_value,
		"best_run_shipped_value": _best_run_shipped_value,
		"current_total_assets": _get_current_total_assets(),
	}


func get_wealth_samples() -> Array[Dictionary]:
	## 返回财富曲线采样副本；按时间先后排列，统计面板用它绘制折线。
	# 采样结果副本；逐项复制防止面板意外改写服务内部数组。
	var samples: Array[Dictionary] = []
	for sample in _wealth_samples:
		samples.append(sample.duplicate())
	return samples


func get_recent_run_history() -> Array[Dictionary]:
	## 返回最近 20 局正式战绩的深复制数组；索引 0 为最新结算，界面修改副本不会影响服务状态。
	# 战绩结果副本；逐项复制字典，防止展示层意外改写持久化数据。
	var history_snapshot: Array[Dictionary] = []
	for run_record in _recent_run_history:
		history_snapshot.append(run_record.duplicate(true))
	return history_snapshot


func get_latest_completed_run() -> Dictionary:
	## 返回最近一次正式结算快照；尚无战绩时返回空字典，主要供结算界面兼容查询。
	return _recent_run_history[0].duplicate(true) if not _recent_run_history.is_empty() else {}


func get_current_run_shipped_value() -> int:
	## 返回当前对局已送回价值累计；悬赏面板在局外查询时为 0。
	return _current_run_shipped_value


func _get_total_coins_earned() -> int:
	## 返回全局库存维护的永久累计获得星穹；服务缺失时安全回退为 0，且不在统计存档中保存副本。
	if _global_inventory != null and _global_inventory.has_method("get_total_coins_earned"):
		return maxi(int(_global_inventory.call("get_total_coins_earned")), 0)
	return 0


func _get_current_total_assets() -> int:
	## 计算当前总资产；优先复用银行授信口径避免重复维护资产公式，银行服务缺失时回退局外星穹余额。
	# 银行服务节点；提供与授信一致的总资产分项接口。
	var bank_service: Node = get_tree().root.get_node_or_null("BankService")
	if bank_service != null and bank_service.has_method("get_asset_breakdown"):
		return maxi(int((bank_service.call("get_asset_breakdown") as Dictionary).get("total", 0)), 0)
	# 全局库存服务；银行缺失时仅统计局外星穹，保证独立场景测试仍可运行。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory != null and global_inventory.has_method("get_coins"):
		return maxi(int(global_inventory.call("get_coins")), 0)
	return 0


func _on_total_coins_earned_changed(_total_coins_earned: int) -> void:
	## 转发累计获得星穹变化，使已打开的生涯面板立即读取最新快照；信号参数不作为第二份状态保存。
	stats_changed.emit()


# ---------------------------------------------------------------------------
# 持久化
# ---------------------------------------------------------------------------

func _queue_save() -> void:
	## 合并同帧多次统计写入；帧末统一落盘一次，避免高频击杀事件反复序列化。
	if _save_queued:
		return
	_save_queued = true
	call_deferred("_save_state")


func _save_state() -> void:
	_save_queued = false
	# 持久化所有者校验；只有注册为 AutoLoad 的唯一实例可以写盘，独立测试实例保持纯内存。
	if get_tree() == null or get_tree().root.get_node_or_null("StatsService") != self:
		return
	# 存档根字典；只保存稳定计数与采样，不保存任何运行时节点或临时对局状态。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"monster_kill_counts": _monster_kill_counts,
		"item_acquire_counts": _item_acquire_counts,
		"total_runs_started": _total_runs_started,
		"total_success_extractions": _total_success_extractions,
		"total_deaths": _total_deaths,
		"total_escapes": _total_escapes,
		"total_monster_kills": _total_monster_kills,
		"total_chests_opened": _total_chests_opened,
		"total_shipped_value": _total_shipped_value,
		"best_run_kills": _best_run_kills,
		"best_run_survival_seconds": _best_run_survival_seconds,
		"best_run_extracted_value": _best_run_extracted_value,
		"best_run_shipped_value": _best_run_shipped_value,
		"wealth_samples": _wealth_samples,
		"recent_run_history": _recent_run_history,
	}
	# 存档文件；打开失败时保留内存状态，不中断游戏流程。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()


func _load_state() -> void:
	## 读取统计存档；文件缺失、JSON 损坏或字段非法时保持全零默认值，不阻断启动。
	if not FileAccess.file_exists(SAVE_PATH):
		return
	# 存档文件；打开失败时保持默认状态。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return
	# JSON 解析结果；只有 Dictionary 结构才继续恢复字段。
	var parsed_data: Variant = JSON.parse_string(save_file.get_as_text())
	if not (parsed_data is Dictionary):
		return
	# 存档字典；逐字段带类型防御恢复。
	var save_data: Dictionary = parsed_data as Dictionary
	# 怪物击杀原始表；只接受字典，键值逐项转为字符串与非负整数。
	var raw_kill_counts: Variant = save_data.get("monster_kill_counts", {})
	if raw_kill_counts is Dictionary:
		for raw_monster_id in (raw_kill_counts as Dictionary).keys():
			_monster_kill_counts[str(raw_monster_id)] = maxi(int((raw_kill_counts as Dictionary).get(raw_monster_id, 0)), 0)
	# 物品获得原始表；与击杀表相同的防御式恢复。
	var raw_acquire_counts: Variant = save_data.get("item_acquire_counts", {})
	if raw_acquire_counts is Dictionary:
		for raw_item_key in (raw_acquire_counts as Dictionary).keys():
			_item_acquire_counts[str(raw_item_key)] = maxi(int((raw_acquire_counts as Dictionary).get(raw_item_key, 0)), 0)
	_total_runs_started = maxi(int(save_data.get("total_runs_started", 0)), 0)
	_total_success_extractions = maxi(int(save_data.get("total_success_extractions", 0)), 0)
	_total_deaths = maxi(int(save_data.get("total_deaths", 0)), 0)
	_total_escapes = maxi(int(save_data.get("total_escapes", 0)), 0)
	_total_monster_kills = maxi(int(save_data.get("total_monster_kills", 0)), 0)
	_total_chests_opened = maxi(int(save_data.get("total_chests_opened", 0)), 0)
	_total_shipped_value = maxi(int(save_data.get("total_shipped_value", 0)), 0)
	_best_run_kills = maxi(int(save_data.get("best_run_kills", 0)), 0)
	_best_run_survival_seconds = maxf(float(save_data.get("best_run_survival_seconds", 0.0)), 0.0)
	_best_run_extracted_value = maxi(int(save_data.get("best_run_extracted_value", 0)), 0)
	_best_run_shipped_value = maxi(int(save_data.get("best_run_shipped_value", 0)), 0)
	# 财富采样原始数组；逐项恢复合法字典并按上限截断。
	var raw_wealth_samples: Variant = save_data.get("wealth_samples", [])
	if raw_wealth_samples is Array:
		for raw_sample in raw_wealth_samples:
			if raw_sample is Dictionary:
				_wealth_samples.append({
					"unix_time": int((raw_sample as Dictionary).get("unix_time", 0)),
					"total_assets": maxi(int((raw_sample as Dictionary).get("total_assets", 0)), 0),
				})
		while _wealth_samples.size() > WEALTH_SAMPLE_LIMIT:
			_wealth_samples.pop_front()
	# 近期战绩原始数组；版本 1 存档缺少该字段时保持空数组，异常条目经统一清洗后再恢复。
	var raw_recent_run_history: Variant = save_data.get("recent_run_history", [])
	if raw_recent_run_history is Array:
		for raw_run_record in raw_recent_run_history:
			if raw_run_record is Dictionary:
				_recent_run_history.append(_sanitize_run_record(raw_run_record as Dictionary))
		while _recent_run_history.size() > RECENT_RUN_HISTORY_LIMIT:
			_recent_run_history.pop_back()


func _sanitize_run_record(raw_run_record: Dictionary) -> Dictionary:
	## 清洗一条读档战绩；未知结果回退逃跑、全部数值限制为非负，确保损坏存档不会把非法数据传入界面。
	# 结果标识；只保留服务公开的三类正式结算结果。
	var result_id: String = str(raw_run_record.get("result_id", RUN_RESULT_ESCAPE))
	if result_id not in [RUN_RESULT_SUCCESS, RUN_RESULT_DEATH, RUN_RESULT_ESCAPE]:
		result_id = RUN_RESULT_ESCAPE
	return {
		"unix_time": maxi(int(raw_run_record.get("unix_time", 0)), 0),
		"completed_at": str(raw_run_record.get("completed_at", "")).strip_edges(),
		"result_id": result_id,
		"survival_seconds": maxf(float(raw_run_record.get("survival_seconds", 0.0)), 0.0),
		"damage_dealt": maxi(int(raw_run_record.get("damage_dealt", 0)), 0),
		"damage_received": maxi(int(raw_run_record.get("damage_received", 0)), 0),
		"monster_kills": maxi(int(raw_run_record.get("monster_kills", 0)), 0),
		"chests_opened": maxi(int(raw_run_record.get("chests_opened", 0)), 0),
		"extracted_value": maxi(int(raw_run_record.get("extracted_value", 0)), 0),
		"shipped_value": maxi(int(raw_run_record.get("shipped_value", 0)), 0),
	}
