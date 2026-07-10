extends Node

## 全局背包服务统一维护局内背包、局外仓库、装备槽、获得时间和战斗结算。
## 玩家组件与主菜单仓库只通过公开接口读取或移动物品，避免各场景分别保存一份背包副本。

signal inventory_changed
signal equipment_changed
signal run_state_changed
signal warehouse_changed
signal coins_changed

## 全局背包存档路径；默认写入用户目录，保存物品标识、获得时间、排序优先级和装备槽。
const SAVE_PATH: String = "user://global_inventory.json"
## 默认远程槽数量；当前项目使用双远程武器，修改需要同步玩家输入可直接选择的槽位数量。
const DEFAULT_RANGED_SLOT_COUNT: int = 2
## 默认武器资源路径表；键为稳定 weapon_id，值为可重新加载的项目资源路径。
const WEAPON_RESOURCE_PATHS: Dictionary = {
	"quantum_pistol": "res://data/weapons/quantum_pistol.tres",
	"pulse_rifle": "res://data/weapons/pulse_rifle.tres",
	"ion_smg": "res://data/weapons/ion_smg.tres",
	"scatter_blaster": "res://data/weapons/scatter_blaster.tres",
	"rail_cannon": "res://data/weapons/rail_cannon.tres",
	"phase_blade": "res://data/weapons/phase_blade.tres",
	"quantum_dagger": "res://data/weapons/quantum_dagger.tres",
}
## 默认背包武器标识；首次建立存档时放入未装备武器，顺序会按获得时间默认排序。
## 永久仓库初始化补充：常量名称为旧存档兼容保留，当前首次存档会把这些未装备武器放入永久仓库。
const DEFAULT_BACKPACK_WEAPON_IDS: Array[String] = ["ion_smg", "rail_cannon", "scatter_blaster", "quantum_dagger"]
## 默认远程装备标识；首次建立存档时依次装入两个远程槽。
const DEFAULT_RANGED_WEAPON_IDS: Array[String] = ["quantum_pistol", "pulse_rifle"]
## 默认近战装备标识；首次建立存档时装入近战槽。
const DEFAULT_MELEE_WEAPON_ID: String = "phase_blade"
## 默认局外金币数量；首次建立存档时为 0，金币只能通过出售永久仓库物品增加且不会进入战斗。
const DEFAULT_STARTING_COINS: int = 0
## 永久仓库位置标识；默认供局外拖拽接口识别安全存储来源和目标。
const STORAGE_LOCATION_WAREHOUSE: String = "warehouse"
## 随身背包位置标识；默认供局外拖拽接口识别战斗携带来源和目标。
const STORAGE_LOCATION_BACKPACK: String = "backpack"
## 近战装备位置标识；默认对应唯一近战槽，拖拽时只接收 melee 武器。
const EQUIPMENT_LOCATION_MELEE: String = "melee"
## 远程装备位置前缀；默认与槽位下标组合为 ranged_0、ranged_1 等稳定目标标识。
const EQUIPMENT_LOCATION_RANGED_PREFIX: String = "ranged_"
## 可堆叠资源单组上限；默认 99，所有仓库、背包、转移、读档和拾取逻辑共同遵守该限制。
const MAX_STACK_QUANTITY: int = 99
## 开发者单次发放强化石数量；默认 10，对应隐藏开发者菜单的固定调试功能。
const DEVELOPER_STONE_GRANT_COUNT: int = 10
## 开发者强化石最少词条数；默认 1，与战斗掉落默认配置保持一致。
const DEVELOPER_STONE_MIN_MODIFIER_COUNT: int = 1
## 开发者强化石最多词条数；默认 3，与战斗掉落默认配置保持一致。
const DEVELOPER_STONE_MAX_MODIFIER_COUNT: int = 3
## 开发者强化石削弱词条概率；默认 0.28，与战斗掉落默认配置保持一致。
const DEVELOPER_STONE_DETRIMENTAL_CHANCE: float = 0.28
## 开发者强化石单词条基础售价；默认 30 金币，与战斗掉落默认配置保持一致。
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
## 存档是否已排队；默认 false，同一帧多次拖拽操作只在帧末写盘一次。
var _save_queued: bool = false
## 服务随机数生成器；默认启动时随机化，用于失败结算随机保留 20% 背包物品。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 局外金币余额；取值大于等于 0，默认 0，只在主菜单仓库出售永久物品时增加。
var _coins: int = DEFAULT_STARTING_COINS


func _ready() -> void:
	_random.randomize()
	_initialize_equipment_slots()
	if not _load_inventory():
		_initialize_default_inventory()
		_save_inventory()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _run_active:
		complete_combat_run_failure("主动退出游戏")
		_save_inventory()


func begin_combat_run() -> void:
	_run_active = true
	_run_seen_resource_instance_ids.clear()
	_run_gained_resources.clear()
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
	# 本局获得物品条目；由首次从战场拾取的资源构建，自己丢弃后重新捡回不会重复或新增统计。
	var gained_entries: Array[Dictionary] = _build_run_gained_entries()
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


func complete_combat_run_failure(reason: String = "战斗失败", retained_ratio: float = 0.2) -> Dictionary:
	if not _run_active:
		return _last_run_outcome.duplicate(true)

	# 标准化保留概率；每件武器或每颗堆叠资源独立判定，长期平均保留约 20%。
	var resolved_retained_ratio: float = clampf(retained_ratio, 0.0, 1.0)
	# 结算后背包记录；武器整件保留或丢失，强化石堆叠按单颗随机后保留剩余数量。
	var retained_records: Array[Dictionary] = []
	# 本局获得物品条目；失败结算同样展示本局真正首次拾取的战利品，不因最终是否保留而改变获得事实。
	var gained_entries: Array[Dictionary] = _build_run_gained_entries()
	# 本局获得物品名称；保留为兼容字段，列表式结算使用 gained_entries 提供悬停详情。
	var gained_items: Array[String] = _get_outcome_entry_names(gained_entries)
	# 丢失物品条目；每项携带 Resource 与显示名，结算列表可直接复用仓库物品详情。
	var lost_entries: Array[Dictionary] = []
	# 丢失物品名称；元素为显示名，用于死亡或主动退出结算界面。
	var lost_items: Array[String] = []
	# 当前结算记录；逐组处理数量，保证 99 个强化石不会被当成一件物品整体保留或整体丢失。
	for record in _backpack_records:
		# 原始数量；武器默认 1，堆叠资源限制在 1 到 99。
		var original_quantity: int = clampi(int(record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
		# 实际保留数量；每个单位独立随机判定，武器数量固定为 1。
		var retained_quantity: int = 0
		for _unit_index in range(original_quantity):
			if _random.randf() < resolved_retained_ratio:
				retained_quantity += 1
		# 丢失数量；用于结算列表在一个条目上显示 xN。
		var lost_quantity: int = original_quantity - retained_quantity
		if retained_quantity > 0:
			record["quantity"] = retained_quantity
			retained_records.append(record)
		if lost_quantity > 0:
			lost_entries.append(_build_outcome_entry(record.get("resource") as Resource, lost_quantity))
			lost_items.append("%s x%d" % [_get_record_display_name(record), lost_quantity] if lost_quantity > 1 else _get_record_display_name(record))

	_backpack_records = retained_records
	_detached_records.clear()
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
	}
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


func adjust_coins(amount: int) -> int:
	# 调整后金币；取值至少为 0，开发者减少金币时不会形成负数余额。
	var adjusted_coins: int = maxi(_coins + amount, 0)
	if adjusted_coins == _coins:
		return _coins
	_coins = adjusted_coins
	_queue_save_inventory()
	coins_changed.emit()
	return _coins


func grant_all_known_weapons_to_warehouse() -> int:
	# 实际发放数量；默认从 0 累加，只统计成功加载并写入永久仓库的武器资源。
	var granted_count: int = 0
	# 已知武器标识；取值来自稳定资源路径表，每次调用都会为每种武器创建独立实例。
	for weapon_id in WEAPON_RESOURCE_PATHS.keys():
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


func grant_random_enhancement_stones_to_warehouse(stone_count: int = DEVELOPER_STONE_GRANT_COUNT) -> int:
	# 实际发放数量；限制为非负数，每颗独立随机并按词条方向自动合并到永久仓库堆叠。
	var granted_count: int = 0
	# 请求数量；开发者菜单默认 10，外部调试调用可传入其他非负数量。
	var resolved_stone_count: int = maxi(stone_count, 0)
	for _stone_index in range(resolved_stone_count):
		# 随机强化石；使用与战斗掉落相同的词条数量、削弱概率和售价规则。
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
	# 出售来源记录数组；局外仓库界面允许出售永久仓库或已展开的随身背包物品。
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	# 待出售索引；使用资源实例身份精确定位重复武器或强化石堆叠。
	var record_index: int = _find_storage_record_index(source_location, item_resource)
	if record_index < 0 or record_index >= source_records.size():
		return false
	# 待出售记录；强化石出售整组，武器数量固定为 1。
	var stored_record: Dictionary = source_records[record_index]
	# 单件售价；武器使用强化后动态售价，强化石使用资源基础售价。
	var unit_sell_price: int = _get_resource_sell_price(item_resource)
	# 出售总价；堆叠资源乘以当前数量。
	var total_sell_price: int = unit_sell_price * maxi(int(stored_record.get("quantity", 1)), 1)
	if total_sell_price <= 0:
		return false

	source_records.remove_at(record_index)
	_coins += total_sell_price
	_queue_save_inventory()
	_emit_storage_changed(source_location)
	coins_changed.emit()
	return true


func get_storage_resource_sell_price(item_resource: Resource, source_location: String) -> int:
	# 来源记录；不存在时返回 0，防止 UI 对已经移动的旧引用显示可出售价格。
	var record_index: int = _find_storage_record_index(source_location, item_resource)
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	if record_index < 0 or record_index >= source_records.size():
		return 0
	return _get_resource_sell_price(item_resource) * maxi(int(source_records[record_index].get("quantity", 1)), 1)


func use_enhancement_stone(stone_resource: Resource, source_location: String, weapon_resource: Resource) -> bool:
	return bool(use_enhancement_stone_with_result(stone_resource, source_location, weapon_resource).get("success", false))


func use_enhancement_stone_with_result(stone_resource: Resource, source_location: String, weapon_resource: Resource) -> Dictionary:
	# 失败结果；任何校验失败都返回相同结构，调用方可以无需特判 null 即安全读取。
	var failed_result: Dictionary = {
		"success": false,
		"weapon": weapon_resource,
		"stone": stone_resource,
		"beneficial_changes": [],
		"detrimental_changes": [],
	}
	if not _is_enhancement_stone(stone_resource) or not _is_weapon_resource(weapon_resource):
		return failed_result
	# 强化石来源索引；仅允许消费仓库或背包内仍由玩家持有的资源。
	var stone_record_index: int = _find_storage_record_index(source_location, stone_resource)
	# 强化石来源记录数组；非法位置返回空数组并拒绝消费。
	var source_records: Array[Dictionary] = _get_storage_records(source_location)
	if stone_record_index < 0 or stone_record_index >= source_records.size() or not _is_owned_weapon_resource(weapon_resource):
		return failed_result
	# 强化词条；从石头资源读取，WeaponData 负责过滤与目标武器不兼容的属性。
	var modifiers: Dictionary = stone_resource.call("get_normalized_modifiers") as Dictionary if stone_resource.has_method("get_normalized_modifiers") else EnhancementRules.normalize_modifiers(stone_resource.get("modifiers") as Dictionary)
	if modifiers.is_empty() or not weapon_resource.has_method("apply_enhancement"):
		return failed_result
	# 武器强化结果；新资源返回完整变化明细，旧扩展资源仍可通过 bool 接口完成强化。
	var enhancement_result: Dictionary = failed_result.duplicate(true)
	if weapon_resource.has_method("apply_enhancement_with_result"):
		enhancement_result = weapon_resource.call("apply_enhancement_with_result", modifiers) as Dictionary
	else:
		enhancement_result["success"] = bool(weapon_resource.call("apply_enhancement", modifiers))
	if not bool(enhancement_result.get("success", false)):
		return failed_result
	enhancement_result["weapon"] = weapon_resource
	enhancement_result["stone"] = stone_resource

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
	# 远程槽索引；取值为解析后的合法下标，-1 表示目标不是远程装备位置。
	var ranged_slot_index: int = _get_ranged_slot_index_from_location(location)
	return get_ranged_equipment_resource(ranged_slot_index) if ranged_slot_index >= 0 else null


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


func add_backpack_resource(item_resource: Resource, target_index: int = -1) -> bool:
	if item_resource == null or _is_resource_equipped(item_resource):
		return false
	if has_backpack_resource(item_resource):
		return false

	# 待加入记录；优先复用 HUD 分步操作留下的临时记录，新拾取物品才创建新的获得时间。
	var record: Dictionary = _take_detached_record(item_resource)
	# 是否为新获得物品；默认由临时记录是否为空判断，新物品加入后按默认获得时间排序。
	var is_new_acquisition: bool = record.is_empty()
	if is_new_acquisition:
		record = _create_record(item_resource)
		_track_combat_acquisition(item_resource)

	if _is_enhancement_stone(item_resource):
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
	var melee_resource: Resource = _load_weapon_resource(DEFAULT_MELEE_WEAPON_ID)
	if melee_resource != null:
		_melee_equipment_record = _create_record(melee_resource)
	_sort_warehouse_default()


func _create_record(item_resource: Resource, acquired_at: float = -1.0, record_id: String = "") -> Dictionary:
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
	}


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
	return item_resource != null and not _is_enhancement_stone(item_resource) and str(item_resource.get("weapon_type")) in ["ranged", "melee"]


func _is_enhancement_stone(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "enhancement_stone"


func _is_owned_weapon_resource(item_resource: Resource) -> bool:
	if not _is_weapon_resource(item_resource):
		return false
	if _find_backpack_record_index(item_resource) >= 0 or _find_warehouse_record_index(item_resource) >= 0:
		return true
	if _is_resource_equipped(item_resource):
		return true
	return _detached_records.has(item_resource.get_instance_id())


func _get_resource_sell_price(item_resource: Resource) -> int:
	if item_resource == null:
		return 0
	if item_resource.has_method("get_effective_sell_price"):
		return maxi(int(item_resource.call("get_effective_sell_price")), 0)
	return maxi(int(item_resource.get("sell_price")), 0)


func _get_stack_signature(item_resource: Resource) -> String:
	if not _is_enhancement_stone(item_resource):
		return ""
	if item_resource.has_method("get_stack_signature"):
		return str(item_resource.call("get_stack_signature"))
	return str(item_resource.get("modifiers"))


func _insert_record_with_stack_merge(target_records: Array[Dictionary], record: Dictionary, target_index: int = -1) -> void:
	if record.is_empty():
		return
	# 待插入资源；武器保持单实例记录，只有强化石参与堆叠合并。
	var item_resource: Resource = record.get("resource") as Resource
	if not _is_enhancement_stone(item_resource):
		# 武器插入下标；负数追加，指定下标用于拖拽排序和装备替换回滚。
		var weapon_insert_index: int = target_records.size() if target_index < 0 else clampi(target_index, 0, target_records.size())
		target_records.insert(weapon_insert_index, record)
		return

	# 剩余待放数量；合法记录限制在 1 到 99，跨容器移动时会优先填充相同词条堆叠。
	var remaining_quantity: int = clampi(int(record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
	# 待插入签名；只有词条键和值完全一致的强化石才允许合并。
	var stack_signature: String = _get_stack_signature(item_resource)
	for existing_record in target_records:
		# 已有资源；非强化石或签名不一致时跳过。
		var existing_resource: Resource = existing_record.get("resource") as Resource
		if not _is_enhancement_stone(existing_resource) or _get_stack_signature(existing_resource) != stack_signature:
			continue
		# 已有数量；达到 99 时继续寻找下一组相同强化石。
		var existing_quantity: int = clampi(int(existing_record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
		if existing_quantity >= MAX_STACK_QUANTITY:
			continue
		# 可合并数量；不超过当前堆叠空余和待插入剩余数量。
		var merged_quantity: int = mini(MAX_STACK_QUANTITY - existing_quantity, remaining_quantity)
		existing_record["quantity"] = existing_quantity + merged_quantity
		remaining_quantity -= merged_quantity
		if remaining_quantity <= 0:
			return

	# 溢出记录；原记录资源继续代表新堆叠，数量不会超过 99。
	record["quantity"] = mini(remaining_quantity, MAX_STACK_QUANTITY)
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


func _does_resource_match_equipment_location(item_resource: Resource, location: String) -> bool:
	if location == EQUIPMENT_LOCATION_MELEE:
		return _is_weapon_type(item_resource, "melee")
	return _get_ranged_slot_index_from_location(location) >= 0 and _is_weapon_type(item_resource, "ranged")


func _take_equipment_record(location: String) -> Dictionary:
	if location == EQUIPMENT_LOCATION_MELEE:
		if _melee_equipment_record.is_empty():
			return {}
		# 近战来源记录；取出后立即清空唯一近战槽，等待原子操作写入新位置。
		var melee_record: Dictionary = _melee_equipment_record
		_melee_equipment_record = {}
		return melee_record
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
	return get_melee_equipment_resource() == item_resource


func _is_weapon_type(item_resource: Resource, weapon_type: String) -> bool:
	return item_resource != null and str(item_resource.get("weapon_type")) == weapon_type


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


func _track_combat_acquisition(item_resource: Resource) -> void:
	if not _run_active or item_resource == null:
		return
	# 资源实例编号；当前战斗内保持稳定，用于区分首次战场拾取与自己丢弃后的重新捡回。
	var resource_instance_id: int = item_resource.get_instance_id()
	if _run_seen_resource_instance_ids.has(resource_instance_id):
		return
	_run_seen_resource_instance_ids[resource_instance_id] = true
	_run_gained_resources.append(item_resource)


func _build_run_gained_entries() -> Array[Dictionary]:
	# 本局收益条目；顺序与首次拾取顺序一致，便于结算界面还原本次探索过程。
	var gained_entries: Array[Dictionary] = []
	# 本局收益资源遍历项；每个资源实例只会在首次拾取时加入一次。
	for item_resource in _run_gained_resources:
		if item_resource != null:
			gained_entries.append(_build_outcome_entry(item_resource))
	return gained_entries


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


func _queue_save_inventory() -> void:
	if _save_queued:
		return
	_save_queued = true
	call_deferred("_save_inventory")


func _save_inventory() -> void:
	_save_queued = false
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

	# 存档根字典；保存版本、排序计数、永久仓库、随身背包、装备和局外金币状态。
	var save_data: Dictionary = {
		"version": 4,
		"acquisition_sequence": _acquisition_sequence,
		"last_extraction_epoch": _last_extraction_epoch,
		"current_ranged_slot": _current_ranged_slot,
		"coins": _coins,
		"warehouse": serialized_warehouse,
		"backpack": serialized_backpack,
		"ranged_equipment": serialized_ranged,
		"melee_equipment": _serialize_record(_melee_equipment_record) if not _melee_equipment_record.is_empty() else null,
	}
	# 存档文件；取值为 user:// 下可写 FileAccess，打开失败时保留内存状态但不抛出运行时错误。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data))


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
	_initialize_equipment_slots()
	_warehouse_records.clear()
	_backpack_records.clear()
	_detached_records.clear()
	_melee_equipment_record = {}
	_acquisition_sequence = maxi(int(save_data.get("acquisition_sequence", 0)), 0)
	_last_extraction_epoch = maxi(int(save_data.get("last_extraction_epoch", 0)), 0)
	_current_ranged_slot = clampi(int(save_data.get("current_ranged_slot", 0)), 0, DEFAULT_RANGED_SLOT_COUNT - 1)
	_coins = maxi(int(save_data.get("coins", DEFAULT_STARTING_COINS)), 0)

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
		"resource_path": _resolve_resource_path(item_resource),
		"quantity": clampi(int(record.get("quantity", 1)), 1, MAX_STACK_QUANTITY),
		"acquired_at": float(record.get("acquired_at", 0.0)),
		"acquisition_sequence": int(record.get("acquisition_sequence", 0)),
		"last_extraction_epoch": int(record.get("last_extraction_epoch", 0)),
	}
	if _is_enhancement_stone(item_resource):
		# 强化石品质；版本 4 起与实际百分比一起保存，旧存档读取时回退为低级。
		serialized_record["quality_id"] = str(item_resource.get("quality_id"))
		serialized_record["display_name"] = str(item_resource.get("display_name"))
		serialized_record["description"] = str(item_resource.get("description"))
		serialized_record["icon_text"] = str(item_resource.get("icon_text"))
		serialized_record["sell_price"] = int(item_resource.get("sell_price"))
		serialized_record["modifiers"] = EnhancementRules.normalize_modifiers(item_resource.get("modifiers") as Dictionary)
	elif item_resource.has_method("get_enhancement_ratio"):
		serialized_record["enhancement_modifiers"] = (item_resource.get("enhancement_modifiers") as Dictionary).duplicate(true)
	return serialized_record


func _deserialize_record(serialized_record: Dictionary) -> Dictionary:
	# 物品类型；旧版存档缺失时按武器处理，保证版本 1/2 存档可继续读取。
	var item_kind: String = str(serialized_record.get("item_kind", "weapon"))
	# 武器标识；取值为稳定 weapon_id，资源路径失效时用于默认表兜底加载。
	var weapon_id: String = str(serialized_record.get("weapon_id", ""))
	# 资源路径；取值为项目内 tres 路径，默认优先使用以支持以后新增武器。
	var resource_path: String = str(serialized_record.get("resource_path", ""))
	# 恢复资源；取值为模板深拷贝，保证同类多件物品仍是独立实例。
	var item_resource: Resource
	if item_kind == "enhancement_stone":
		# 强化石资源；由存档字段直接重建，避免依赖项目内固定 tres 模板。
		var enhancement_stone: EnhancementStoneData = EnhancementStoneData.new()
		enhancement_stone.quality_id = str(serialized_record.get("quality_id", EnhancementRules.QUALITY_LOW))
		# 恢复显示名称；旧存档的通用“强化石”自动升级为对应品质名称。
		var saved_display_name: String = str(serialized_record.get("display_name", ""))
		enhancement_stone.display_name = EnhancementRules.get_quality_display_name(enhancement_stone.quality_id) if saved_display_name.is_empty() or saved_display_name == "强化石" else saved_display_name
		enhancement_stone.description = str(serialized_record.get("description", enhancement_stone.description))
		enhancement_stone.icon_text = str(serialized_record.get("icon_text", enhancement_stone.icon_text))
		enhancement_stone.sell_price = maxi(int(serialized_record.get("sell_price", 0)), 0)
		enhancement_stone.modifiers = EnhancementRules.normalize_modifiers(serialized_record.get("modifiers", {}) as Dictionary)
		item_resource = enhancement_stone
	else:
		item_resource = _load_weapon_resource(weapon_id, resource_path)
	if item_resource == null:
		return {}
	if item_kind != "enhancement_stone" and serialized_record.get("enhancement_modifiers") is Dictionary:
		item_resource.set("enhancement_modifiers", (serialized_record.get("enhancement_modifiers") as Dictionary).duplicate(true))
	# 恢复记录；保留编号和获得时间，序号缺失时使用当前递增值。
	var record: Dictionary = _create_record(item_resource, float(serialized_record.get("acquired_at", 0.0)), str(serialized_record.get("record_id", "")))
	record["acquisition_sequence"] = int(serialized_record.get("acquisition_sequence", record.get("acquisition_sequence", 0)))
	record["last_extraction_epoch"] = int(serialized_record.get("last_extraction_epoch", 0))
	record["quantity"] = clampi(int(serialized_record.get("quantity", 1)), 1, MAX_STACK_QUANTITY)
	_acquisition_sequence = maxi(_acquisition_sequence, int(record["acquisition_sequence"]))
	return record


func _load_weapon_resource(weapon_id: String, preferred_path: String = "") -> Resource:
	# 实际资源路径；优先使用存档路径，缺失时按稳定武器标识查询默认表。
	var resolved_path: String = preferred_path
	if resolved_path.is_empty():
		resolved_path = str(WEAPON_RESOURCE_PATHS.get(weapon_id, ""))
	if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
		return null
	# 武器模板；取值为项目 Resource，加载成功后深拷贝为独立物品实例。
	var weapon_template: Resource = load(resolved_path) as Resource
	if weapon_template == null:
		return null
	# 独立资源；取值为模板深拷贝，复制失败时回退模板以保证存档可用。
	var duplicated_resource: Resource = weapon_template.duplicate(true) as Resource
	return duplicated_resource if duplicated_resource != null else weapon_template


func _resolve_resource_path(item_resource: Resource) -> String:
	if item_resource == null:
		return ""
	if not item_resource.resource_path.is_empty():
		return item_resource.resource_path
	return str(WEAPON_RESOURCE_PATHS.get(str(item_resource.get("weapon_id")), ""))
