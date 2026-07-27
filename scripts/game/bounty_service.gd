extends Node

## 悬赏服务：维护每日随机悬赏的刷新、进度推进、自动发奖与独立持久化。
## 悬赏进度完全依赖 StatsService 广播的战斗事实事件（击杀、开箱、送回、对局结束），
## 本服务不直接接触战斗节点；训练场与超频骇入的事件在统计服务挂点处已被排除，悬赏天然不计。
## 每日按本地日期刷新一批随机悬赏；完成的悬赏立即自动发放星穹或稀有强化石，并广播完成信号供横幅播报。

## 悬赏列表变化信号；刷新、进度推进与发奖后派发，悬赏面板据此重建展示。
signal bounties_changed
## 悬赏完成信号；参数为悬赏标题与奖励描述文本，横幅通知服务订阅后播报“悬赏完成”。
signal bounty_completed(bounty_title: String, reward_text: String)

## 悬赏存档路径；独立文件保存，纳入导出、导入与删除存档白名单。
const SAVE_PATH: String = "user://bounty_state.json"
## 悬赏存档版本；默认 1 标识当前写入结构，未来字段调整时用于兼容判断。
const SAVE_VERSION: int = 1
## 悬赏类型标识：击杀指定类型怪物。
const BOUNTY_KIND_KILL: String = "kill"
## 悬赏类型标识：开启高级或极品宝箱。
const BOUNTY_KIND_CHEST: String = "chest"
## 悬赏类型标识：单局送回指定价值的物资。
const BOUNTY_KIND_SHIP: String = "ship"
## 悬赏类型标识：存活指定秒数并成功撤离。
const BOUNTY_KIND_SURVIVE: String = "survive"
## 奖励类型标识：星穹。
const REWARD_KIND_GOLD: String = "gold"
## 奖励类型标识：稀有强化石（高级、极品或特化品质）。
const REWARD_KIND_STONE: String = "stone"
## 每日悬赏数量；默认 3 条，从四种悬赏类型中不重复抽取，修改会线性改变每日悬赏总收益。
const DAILY_BOUNTY_COUNT: int = 3
## 击杀悬赏目标数量；默认 30 只，按第 25 章口径约一局出头的击杀量即可完成。
const KILL_BOUNTY_REQUIRED_COUNT: int = 30
## 击杀悬赏星穹报酬；默认 240，与其他悬赏共同把每日悬赏总额控制在约一局收益（约 1000 星穹）内。
const KILL_BOUNTY_REWARD_GOLD: int = 240
## 宝箱悬赏目标数量；默认 3 个高级或极品宝箱，按 15%+3% 生成占比约需开启 17 个宝箱。
const CHEST_BOUNTY_REQUIRED_COUNT: int = 3
## 宝箱悬赏星穹报酬；默认 280。
const CHEST_BOUNTY_REWARD_GOLD: int = 280
## 高品质宝箱品质集合；与 LootChest 品质标识一致，高级与极品宝箱都计入宝箱悬赏进度。
const CHEST_BOUNTY_QUALITY_IDS: Array[String] = ["high", "supreme"]
## 送回悬赏单局目标价值；默认 600 星穹，占单局送回上限 1000 的六成，需要有计划地使用物资撤离点。
const SHIP_BOUNTY_REQUIRED_VALUE: int = 600
## 送回悬赏星穹报酬；默认 320，为四类悬赏最高，对应其对局内行为约束最强。
const SHIP_BOUNTY_REWARD_GOLD: int = 320
## 撤离悬赏存活时长门槛；默认 360 秒，超过正式撤离点标记时间（300 秒）一分钟后再撤离即可达成。
const SURVIVE_BOUNTY_REQUIRED_SECONDS: float = 360.0
## 撤离悬赏星穹报酬；默认 300。
const SURVIVE_BOUNTY_REWARD_GOLD: int = 300
## 稀有强化石奖励概率；默认 0.25，悬赏刷新时按该概率把星穹报酬替换为一颗稀有强化石。
const STONE_REWARD_CHANCE: float = 0.25
## 稀有强化石品质集合；与宝箱高品质强化石口径一致，高级、极品与特化均视为稀有。
const RARE_STONE_QUALITY_IDS: Array[String] = ["high", "supreme", "specialized"]
## 稀有强化石抽取尝试次数；默认 12 次，与宝箱高品质强化石保底流程一致，未命中时强制提升为高级。
const RARE_STONE_ROLL_ATTEMPTS: int = 12
## 奖励强化石最少词条数；默认 1，与战斗掉落默认配置一致。
const REWARD_STONE_MIN_MODIFIER_COUNT: int = 1
## 奖励强化石最多词条数；默认 3，与战斗掉落默认配置一致。
const REWARD_STONE_MAX_MODIFIER_COUNT: int = 3
## 奖励强化石削弱词条概率；默认 0.28，与战斗掉落默认配置一致。
const REWARD_STONE_DETRIMENTAL_CHANCE: float = 0.28
## 奖励强化石单词条基础价值；默认 30 星穹，与战斗掉落默认配置一致。
const REWARD_STONE_BASE_SELL_PRICE: int = 30
## 日期变更检查间隔；默认 60 秒，跨零点持续在线时最多一分钟后刷新新一天的悬赏。
const DATE_CHECK_INTERVAL_SECONDS: float = 60.0

## 当前悬赏所属日期键；格式为本地日期 YYYY-MM-DD，与系统日期不一致时触发每日刷新。
var _current_date_key: String = ""
## 当前悬赏列表；元素为包含类型、标题、说明、目标、进度、奖励与完成状态的字典，按生成顺序展示。
var _bounties: Array[Dictionary] = []
## 服务随机数生成器；启动时随机化，用于抽取悬赏类型、击杀目标与奖励强化石。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 日期检查计时器；常驻子节点，跨零点在线时驱动每日刷新。
var _date_check_timer: Timer = null
## 存档是否已排队；默认 false，同一帧多次进度推进只在帧末写盘一次。
var _save_queued: bool = false


func _ready() -> void:
	_random.randomize()
	_load_state()
	_refresh_daily_bounties_if_needed()
	_connect_stats_signals()
	# 日期检查计时器；跨零点持续挂机时保证新一天的悬赏最多延迟一个检查间隔生效。
	_date_check_timer = Timer.new()
	_date_check_timer.wait_time = DATE_CHECK_INTERVAL_SECONDS
	_date_check_timer.autostart = true
	_date_check_timer.timeout.connect(_refresh_daily_bounties_if_needed)
	add_child(_date_check_timer)


func _connect_stats_signals() -> void:
	## 订阅统计服务的战斗事实信号；统计服务缺失时悬赏仍可展示，只是进度不会推进。
	# 统计服务节点；AutoLoad 注册顺序在本服务之前，正常启动时必定存在。
	var stats_service: Node = get_tree().root.get_node_or_null("StatsService")
	if stats_service == null:
		return
	if stats_service.has_signal("monster_kill_recorded"):
		stats_service.connect("monster_kill_recorded", Callable(self, "_on_monster_kill_recorded"))
	if stats_service.has_signal("chest_open_recorded"):
		stats_service.connect("chest_open_recorded", Callable(self, "_on_chest_open_recorded"))
	if stats_service.has_signal("run_shipped_value_changed"):
		stats_service.connect("run_shipped_value_changed", Callable(self, "_on_run_shipped_value_changed"))
	if stats_service.has_signal("run_finished"):
		stats_service.connect("run_finished", Callable(self, "_on_run_finished"))


# ---------------------------------------------------------------------------
# 每日刷新与悬赏生成
# ---------------------------------------------------------------------------

func _refresh_daily_bounties_if_needed() -> void:
	## 检查本地日期并按需刷新每日悬赏；同一天内重复调用不产生任何变化。
	# 本地日期键；使用系统本地时区，跨零点后与存档日期不一致即触发刷新。
	var today_key: String = Time.get_date_string_from_system(false)
	if today_key == _current_date_key and not _bounties.is_empty():
		return
	_current_date_key = today_key
	_bounties = _generate_daily_bounties()
	_queue_save()
	bounties_changed.emit()


func _generate_daily_bounties() -> Array[Dictionary]:
	## 生成一批每日悬赏；从四种类型中不重复抽取固定数量，每条独立掷奖励类型。
	# 候选悬赏类型池；洗牌后取前几项，保证同一天内类型不重复。
	var kind_pool: Array[String] = [BOUNTY_KIND_KILL, BOUNTY_KIND_CHEST, BOUNTY_KIND_SHIP, BOUNTY_KIND_SURVIVE]
	kind_pool.shuffle()
	# 生成结果；元素为完整悬赏字典，数量受候选池与每日数量共同限制。
	var generated_bounties: Array[Dictionary] = []
	for kind_index in range(mini(DAILY_BOUNTY_COUNT, kind_pool.size())):
		# 单条悬赏；击杀类可能因怪物目录为空生成失败，失败时跳过不补位。
		var bounty: Dictionary = _build_bounty(kind_pool[kind_index])
		if not bounty.is_empty():
			generated_bounties.append(bounty)
	return generated_bounties


func _build_bounty(bounty_kind: String) -> Dictionary:
	## 构建单条悬赏字典；标题与说明在生成时固化，后续内容包变化不影响当天已发布悬赏。
	# 通用悬赏骨架；进度从 0 开始，完成与发奖状态一体维护（完成即自动发奖）。
	var bounty: Dictionary = {
		"kind": bounty_kind,
		"title": "",
		"description": "",
		"required": 0,
		"progress": 0,
		"completed": false,
		"target_monster_id": "",
		"target_monster_name": "",
		"reward_kind": REWARD_KIND_GOLD,
		"reward_gold": 0,
	}
	if bounty_kind == BOUNTY_KIND_KILL:
		# 击杀目标怪物；从当前已解锁内容池随机抽取，目录为空时该悬赏生成失败。
		var kill_target: Dictionary = _pick_random_monster_target()
		if kill_target.is_empty():
			return {}
		bounty["target_monster_id"] = str(kill_target.get("monster_id", ""))
		bounty["target_monster_name"] = str(kill_target.get("display_name", "怪物"))
		bounty["title"] = "猎杀委托：%s" % bounty["target_monster_name"]
		bounty["required"] = KILL_BOUNTY_REQUIRED_COUNT
		bounty["description"] = "在正式骇入中累计击杀 %d 只「%s」。" % [KILL_BOUNTY_REQUIRED_COUNT, bounty["target_monster_name"]]
		bounty["reward_gold"] = KILL_BOUNTY_REWARD_GOLD
	elif bounty_kind == BOUNTY_KIND_CHEST:
		bounty["title"] = "开箱委托：高级物资"
		bounty["required"] = CHEST_BOUNTY_REQUIRED_COUNT
		bounty["description"] = "在正式骇入中累计开启 %d 个高级或极品宝箱。" % CHEST_BOUNTY_REQUIRED_COUNT
		bounty["reward_gold"] = CHEST_BOUNTY_REWARD_GOLD
	elif bounty_kind == BOUNTY_KIND_SHIP:
		bounty["title"] = "押运委托：物资回送"
		bounty["required"] = SHIP_BOUNTY_REQUIRED_VALUE
		bounty["description"] = "在单局内通过物资撤离点累计送回价值 %d 星穹的物资。" % SHIP_BOUNTY_REQUIRED_VALUE
		bounty["reward_gold"] = SHIP_BOUNTY_REWARD_GOLD
	elif bounty_kind == BOUNTY_KIND_SURVIVE:
		bounty["title"] = "驻留委托：长线撤离"
		bounty["required"] = 1
		bounty["description"] = "单局存活至少 %d 秒并成功撤离。" % roundi(SURVIVE_BOUNTY_REQUIRED_SECONDS)
		bounty["reward_gold"] = SURVIVE_BOUNTY_REWARD_GOLD
	else:
		return {}
	# 奖励类型掷点；按固定概率把星穹报酬替换为一颗稀有强化石，替换后不再发放星穹。
	if _random.randf() < STONE_REWARD_CHANCE:
		bounty["reward_kind"] = REWARD_KIND_STONE
	return bounty


func _pick_random_monster_target() -> Dictionary:
	## 从内容目录当前可用怪物池随机抽取击杀目标；离树实例化只读取稳定 ID 与名称，不触发 AI 或遇敌登记。
	# 内容目录服务；缺失时无法确定怪物池，击杀悬赏生成失败。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog == null or not content_catalog.has_method("get_enemy_scene_paths"):
		return {}
	# 可用怪物场景路径；已按角色解锁状态过滤，未解锁扩展包的怪物不会成为悬赏目标。
	var enemy_scene_paths: PackedStringArray = content_catalog.call("get_enemy_scene_paths") as PackedStringArray
	if enemy_scene_paths.is_empty():
		return {}
	# 随机场景路径；等概率抽取一条并读取其图鉴级基础信息。
	var selected_scene_path: String = enemy_scene_paths[_random.randi_range(0, enemy_scene_paths.size() - 1)]
	# 怪物预制体；无法加载时按生成失败处理。
	var monster_scene: PackedScene = load(selected_scene_path) as PackedScene
	if monster_scene == null:
		return {}
	# 怪物离树实例；未加入场景树不会触发 ready，因此不会产生任何战斗副作用。
	var monster_root: Node = monster_scene.instantiate()
	if monster_root == null:
		return {}
	# 目标怪物信息；先复制稳定字段再释放离树实例。
	var target_info: Dictionary = {
		"monster_id": str(monster_root.get("monster_id")).strip_edges(),
		"display_name": str(monster_root.get("display_name")).strip_edges(),
	}
	monster_root.free()
	if str(target_info.get("monster_id", "")).is_empty():
		return {}
	if str(target_info.get("display_name", "")).is_empty():
		target_info["display_name"] = "未知怪物"
	return target_info


# ---------------------------------------------------------------------------
# 进度推进（订阅统计服务事实信号）
# ---------------------------------------------------------------------------

func _on_monster_kill_recorded(monster_id: String) -> void:
	## 击杀事件回调；推进目标怪物匹配的击杀悬赏进度。
	for bounty in _bounties:
		if bool(bounty.get("completed", false)) or str(bounty.get("kind", "")) != BOUNTY_KIND_KILL:
			continue
		if str(bounty.get("target_monster_id", "")) != monster_id:
			continue
		bounty["progress"] = int(bounty.get("progress", 0)) + 1
		_try_complete_bounty(bounty)
	_queue_save()
	bounties_changed.emit()


func _on_chest_open_recorded(quality_id: String) -> void:
	## 开箱事件回调；只有高级与极品宝箱推进宝箱悬赏进度。
	if quality_id not in CHEST_BOUNTY_QUALITY_IDS:
		return
	for bounty in _bounties:
		if bool(bounty.get("completed", false)) or str(bounty.get("kind", "")) != BOUNTY_KIND_CHEST:
			continue
		bounty["progress"] = int(bounty.get("progress", 0)) + 1
		_try_complete_bounty(bounty)
	_queue_save()
	bounties_changed.emit()


func _on_run_shipped_value_changed(run_shipped_value: int) -> void:
	## 单局送回累计回调；送回悬赏按“单局内累计值”判定，跨局不叠加。
	for bounty in _bounties:
		if bool(bounty.get("completed", false)) or str(bounty.get("kind", "")) != BOUNTY_KIND_SHIP:
			continue
		# 送回悬赏进度展示值；取历史单局最好成绩与当前局累计的较大值，只用于面板展示不改变判定。
		bounty["progress"] = maxi(int(bounty.get("progress", 0)), run_shipped_value)
		_try_complete_bounty(bounty)
	_queue_save()
	bounties_changed.emit()


func _on_run_finished(result_id: String, survival_seconds: float, _extracted_value: int) -> void:
	## 对局结束回调；撤离悬赏要求成功撤离且存活时长达标，其余结果不推进。
	if result_id != "success":
		return
	for bounty in _bounties:
		if bool(bounty.get("completed", false)) or str(bounty.get("kind", "")) != BOUNTY_KIND_SURVIVE:
			continue
		if survival_seconds < SURVIVE_BOUNTY_REQUIRED_SECONDS:
			continue
		bounty["progress"] = 1
		_try_complete_bounty(bounty)
	_queue_save()
	bounties_changed.emit()


func _try_complete_bounty(bounty: Dictionary) -> void:
	## 判定并结算单条悬赏；达到目标后立即发放奖励、标记完成并广播完成信号。
	if bool(bounty.get("completed", false)) or int(bounty.get("progress", 0)) < int(bounty.get("required", 0)):
		return
	bounty["completed"] = true
	# 奖励描述文本；发奖成功后写入横幅与面板共用的固定描述。
	var reward_text: String = _grant_bounty_reward(bounty)
	bounty_completed.emit(str(bounty.get("title", "悬赏")), reward_text)


func _grant_bounty_reward(bounty: Dictionary) -> String:
	## 发放单条悬赏奖励；星穹直接入账，稀有强化石写入仓库，返回玩家可读的奖励描述。
	# 全局库存服务；缺失时奖励视为发放失败并返回提示文本，不阻塞完成标记。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory == null:
		return "奖励发放失败（库存服务不可用）"
	if str(bounty.get("reward_kind", REWARD_KIND_GOLD)) == REWARD_KIND_STONE:
		# 稀有强化石奖励；生成后直接写入仓库并同步获得数量统计。
		var reward_stone: EnhancementStoneData = _create_rare_reward_stone()
		if reward_stone != null and global_inventory.has_method("add_storage_resource") and bool(global_inventory.call("add_storage_resource", reward_stone, "warehouse", 1)):
			# 统计服务；悬赏奖励属于真实获得，与战斗拾取和商店购买共用获得计数口径。
			var stats_service: Node = get_tree().root.get_node_or_null("StatsService")
			if stats_service != null and stats_service.has_method("record_item_acquired"):
				stats_service.call("record_item_acquired", reward_stone, 1)
			return "稀有强化石「%s」已存入仓库" % str(reward_stone.get("display_name"))
		# 强化石生成或入库失败兜底；按星穹报酬补偿，保证完成的悬赏不会空手而归。
		if global_inventory.has_method("grant_coins"):
			global_inventory.call("grant_coins", int(bounty.get("reward_gold", 0)))
		elif global_inventory.has_method("adjust_coins"):
			global_inventory.call("adjust_coins", int(bounty.get("reward_gold", 0)))
		return "%d 星穹已入账（强化石发放失败补偿）" % int(bounty.get("reward_gold", 0))
	if global_inventory.has_method("grant_coins"):
		global_inventory.call("grant_coins", int(bounty.get("reward_gold", 0)))
	elif global_inventory.has_method("adjust_coins"):
		global_inventory.call("adjust_coins", int(bounty.get("reward_gold", 0)))
	return "%d 星穹已入账" % int(bounty.get("reward_gold", 0))


func _create_rare_reward_stone() -> EnhancementStoneData:
	## 生成一颗稀有品质强化石；复用正式随机生成器并按宝箱高品质保底流程重试，最终强制提升为高级。
	# 当前生成结果；最多重试固定次数，命中稀有品质立即返回。
	var reward_stone: EnhancementStoneData = null
	for _attempt_index in range(RARE_STONE_ROLL_ATTEMPTS):
		reward_stone = EnhancementStoneData.create_random(_random, REWARD_STONE_MIN_MODIFIER_COUNT, REWARD_STONE_MAX_MODIFIER_COUNT, REWARD_STONE_DETRIMENTAL_CHANCE, REWARD_STONE_BASE_SELL_PRICE)
		if reward_stone == null:
			continue
		if reward_stone.get_resolved_quality_id() in RARE_STONE_QUALITY_IDS:
			return reward_stone
	if reward_stone != null:
		# 保底提升；连续未命中稀有品质时强制提升到高级，保留已生成词条方向并更新统一品质名称与价值。
		reward_stone.quality_id = EnhancementRules.QUALITY_HIGH
		reward_stone.display_name = EnhancementStoneData._build_display_name(EnhancementRules.QUALITY_HIGH, reward_stone.get_resolved_target_kind())
		reward_stone.value = EnhancementStoneData.calculate_value(EnhancementRules.QUALITY_HIGH, reward_stone.get_normalized_modifiers())
	return reward_stone


# ---------------------------------------------------------------------------
# 查询与持久化
# ---------------------------------------------------------------------------

func get_bounty_snapshot() -> Dictionary:
	## 返回悬赏面板展示快照；包含当前日期键与全部悬赏的只读副本。
	# 悬赏副本数组；逐项深复制防止面板改写服务状态。
	var bounty_copies: Array[Dictionary] = []
	for bounty in _bounties:
		bounty_copies.append(bounty.duplicate(true))
	return {"date_key": _current_date_key, "bounties": bounty_copies}


func _queue_save() -> void:
	## 合并同帧多次悬赏写入；帧末统一落盘一次。
	if _save_queued:
		return
	_save_queued = true
	call_deferred("_save_state")


func _save_state() -> void:
	_save_queued = false
	# 持久化所有者校验；只有注册为 AutoLoad 的唯一实例可以写盘。
	if get_tree() == null or get_tree().root.get_node_or_null("BountyService") != self:
		return
	# 存档根字典；保存日期键与全部悬赏状态。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"date_key": _current_date_key,
		"bounties": _bounties,
	}
	# 存档文件；打开失败时保留内存状态。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()


func _load_state() -> void:
	## 读取悬赏存档；文件缺失或损坏时保持空列表，随后的每日刷新会立即生成当天悬赏。
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
	_current_date_key = str(save_data.get("date_key", ""))
	# 悬赏原始数组；逐项恢复合法字典并规范化数值字段。
	var raw_bounties: Variant = save_data.get("bounties", [])
	if raw_bounties is Array:
		for raw_bounty in raw_bounties:
			if not (raw_bounty is Dictionary):
				continue
			# 恢复的悬赏字典；只保留已知字段，数值统一非负化。
			var bounty: Dictionary = raw_bounty as Dictionary
			_bounties.append({
				"kind": str(bounty.get("kind", "")),
				"title": str(bounty.get("title", "悬赏")),
				"description": str(bounty.get("description", "")),
				"required": maxi(int(bounty.get("required", 0)), 0),
				"progress": maxi(int(bounty.get("progress", 0)), 0),
				"completed": bool(bounty.get("completed", false)),
				"target_monster_id": str(bounty.get("target_monster_id", "")),
				"target_monster_name": str(bounty.get("target_monster_name", "")),
				"reward_kind": str(bounty.get("reward_kind", REWARD_KIND_GOLD)),
				"reward_gold": maxi(int(bounty.get("reward_gold", 0)), 0),
			})
