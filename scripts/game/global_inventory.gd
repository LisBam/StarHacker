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
## 本局开始时的物品编号集合；键为记录编号，值为 true，用于结算本局新获得物品。
var _run_start_record_ids: Dictionary = {}
## 最近一次战斗结算；包含 result、gained_items、lost_items 和 retained_items，默认空字典。
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
	_run_start_record_ids.clear()
	# 开局物品记录；取值为背包和装备中的全部有效记录，用于识别本局新增物品。
	for record in _get_all_owned_records():
		_run_start_record_ids[str(record.get("record_id", ""))] = true
	_last_run_outcome.clear()
	run_state_changed.emit()


func is_combat_run_active() -> bool:
	return _run_active


func complete_combat_run_success() -> Dictionary:
	if not _run_active:
		return _last_run_outcome.duplicate(true)

	_last_extraction_epoch += 1
	# 本局获得物品名称；元素为显示名，用于撤离结算界面向玩家展示收益。
	var gained_items: Array[String] = []
	# 成功撤离携带记录；包含背包与装备，全部写入本次撤离编号以支持以后卸下时仍优先排序。
	for record in _get_all_owned_records():
		record["last_extraction_epoch"] = _last_extraction_epoch
		# 记录编号；取值为稳定字符串，用于判断是否在本局开始快照中出现过。
		var record_id: String = str(record.get("record_id", ""))
		if not _run_start_record_ids.has(record_id):
			gained_items.append(_get_record_display_name(record))

	# 成功撤离背包记录；撤离后自动转入永久仓库，避免玩家下一局未整理时再次承担死亡损失。
	var extracted_backpack_records: Array[Dictionary] = _backpack_records.duplicate()
	_backpack_records.clear()
	# 原有永久仓库记录；追加到撤离物品之后，保证最近一次撤离携带物品整体位于仓库前方且不打乱玩家手工顺序。
	extracted_backpack_records.append_array(_warehouse_records)
	_warehouse_records = extracted_backpack_records
	_run_active = false
	_run_start_record_ids.clear()
	_last_run_outcome = {
		"result": "success",
		"title": "撤离成功",
		"gained_items": gained_items,
		"lost_items": [],
		"retained_items": [],
	}
	_queue_save_inventory()
	warehouse_changed.emit()
	inventory_changed.emit()
	equipment_changed.emit()
	run_state_changed.emit()
	return _last_run_outcome.duplicate(true)


func complete_combat_run_failure(reason: String = "战斗失败", retained_ratio: float = 0.2) -> Dictionary:
	if not _run_active:
		return _last_run_outcome.duplicate(true)

	# 背包总数；取值为结算前背包记录数量，装备槽不参与本次 80% 掉落规则。
	var backpack_count: int = _backpack_records.size()
	# 实际保留数量；默认按 20% 四舍五入，限制在 0 到背包总数。
	var retained_count: int = clampi(roundi(float(backpack_count) * clampf(retained_ratio, 0.0, 1.0)), 0, backpack_count)
	# 随机索引数组；元素为背包下标，通过洗牌选择本次保留记录。
	var shuffled_indices: Array[int] = []
	# 背包索引；取值为 0 到物品数量减一，用于构建随机选择池。
	for record_index in range(backpack_count):
		shuffled_indices.append(record_index)
	_shuffle_integer_array(shuffled_indices)

	# 保留下标查询表；键为背包下标，值为 true，用于保持原有排序构建结算后背包。
	var retained_index_lookup: Dictionary = {}
	# 保留选择索引；取值为 0 到 retained_count 减一，读取洗牌后的随机下标。
	for retained_selection_index in range(retained_count):
		retained_index_lookup[shuffled_indices[retained_selection_index]] = true

	# 结算后背包记录；只保留随机选中的约 20% 物品，并维持原仓库相对顺序。
	var retained_records: Array[Dictionary] = []
	# 丢失物品名称；元素为显示名，用于死亡或主动退出结算界面。
	var lost_items: Array[String] = []
	# 保留物品名称；元素为显示名，用于向玩家确认随机保留结果。
	var retained_items: Array[String] = []
	# 结算背包索引；取值为原背包有效下标，用于区分保留和丢失记录。
	for record_index in range(_backpack_records.size()):
		# 当前结算记录；取值为包含资源和元数据的物品记录。
		var record: Dictionary = _backpack_records[record_index]
		if retained_index_lookup.has(record_index):
			retained_records.append(record)
			retained_items.append(_get_record_display_name(record))
		else:
			lost_items.append(_get_record_display_name(record))

	_backpack_records = retained_records
	_detached_records.clear()
	_run_active = false
	_run_start_record_ids.clear()
	_last_run_outcome = {
		"result": "failure",
		"title": reason,
		"gained_items": [],
		"lost_items": lost_items,
		"retained_items": retained_items,
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
			"resource": item_resource,
			"acquired_at": float(record.get("acquired_at", 0.0)),
			"is_last_extraction": _last_extraction_epoch > 0 and int(record.get("last_extraction_epoch", 0)) == _last_extraction_epoch,
		})
	return result


func get_warehouse_count() -> int:
	return _warehouse_records.size()


func get_coins() -> int:
	return _coins


func transfer_warehouse_to_backpack(item_resource: Resource, target_index: int = -1) -> bool:
	# 永久仓库来源索引；取值为有效下标时才允许把安全物品转为下一局随身物品。
	var warehouse_index: int = _find_warehouse_record_index(item_resource)
	if warehouse_index < 0:
		return false

	# 待转移记录；保持原记录编号和获得时间，避免跨容器移动被误判为新拾取物品。
	var moving_record: Dictionary = _warehouse_records[warehouse_index]
	_warehouse_records.remove_at(warehouse_index)
	# 背包插入位置；负数表示追加到末尾，拖拽到具体条目时限制在合法边界内。
	var insert_index: int = _backpack_records.size() if target_index < 0 else clampi(target_index, 0, _backpack_records.size())
	_backpack_records.insert(insert_index, moving_record)
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
	if target_index < 0:
		_warehouse_records.append(moving_record)
	else:
		# 仓库插入位置；取值限制在 0 到现有仓库数量，供拖拽精确调整展示顺序。
		var insert_index: int = clampi(target_index, 0, _warehouse_records.size())
		_warehouse_records.insert(insert_index, moving_record)
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
	# 待出售仓库索引；只有永久仓库内物品可以出售，背包和装备物品不会被误售。
	var warehouse_index: int = _find_warehouse_record_index(item_resource)
	if warehouse_index < 0:
		return false

	# 待出售资源；取值用于读取数据资源上的固定售价，缺失或零售价物品不可出售。
	var stored_resource: Resource = _warehouse_records[warehouse_index].get("resource") as Resource
	# 物品售价；取值大于 0，负值会被限制为 0，防止异常数据扣除玩家金币。
	var sell_price: int = maxi(int(stored_resource.get("sell_price")) if stored_resource != null else 0, 0)
	if sell_price <= 0:
		return false

	_warehouse_records.remove_at(warehouse_index)
	_coins += sell_price
	_queue_save_inventory()
	warehouse_changed.emit()
	coins_changed.emit()
	return true


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
			"resource": item_resource,
			"acquired_at": float(record.get("acquired_at", 0.0)),
			"is_last_extraction": _last_extraction_epoch > 0 and int(record.get("last_extraction_epoch", 0)) == _last_extraction_epoch,
		})
	return result


func get_backpack_count() -> int:
	return _backpack_records.size()


func has_backpack_resource(item_resource: Resource) -> bool:
	return _find_backpack_record_index(item_resource) >= 0


func add_backpack_resource(item_resource: Resource, target_index: int = -1) -> bool:
	if item_resource == null or has_backpack_resource(item_resource) or _is_resource_equipped(item_resource):
		return false

	# 待加入记录；优先复用 HUD 分步操作留下的临时记录，新拾取物品才创建新的获得时间。
	var record: Dictionary = _take_detached_record(item_resource)
	# 是否为新获得物品；默认由临时记录是否为空判断，新物品加入后按默认获得时间排序。
	var is_new_acquisition: bool = record.is_empty()
	if is_new_acquisition:
		record = _create_record(item_resource)

	if target_index < 0:
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
		"version": 2,
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
	return {
		"record_id": str(record.get("record_id", "")),
		"weapon_id": str(item_resource.get("weapon_id")),
		"resource_path": _resolve_resource_path(item_resource),
		"acquired_at": float(record.get("acquired_at", 0.0)),
		"acquisition_sequence": int(record.get("acquisition_sequence", 0)),
		"last_extraction_epoch": int(record.get("last_extraction_epoch", 0)),
	}


func _deserialize_record(serialized_record: Dictionary) -> Dictionary:
	# 武器标识；取值为稳定 weapon_id，资源路径失效时用于默认表兜底加载。
	var weapon_id: String = str(serialized_record.get("weapon_id", ""))
	# 资源路径；取值为项目内 tres 路径，默认优先使用以支持以后新增武器。
	var resource_path: String = str(serialized_record.get("resource_path", ""))
	# 恢复资源；取值为模板深拷贝，保证同类多件物品仍是独立实例。
	var item_resource: Resource = _load_weapon_resource(weapon_id, resource_path)
	if item_resource == null:
		return {}
	# 恢复记录；保留编号和获得时间，序号缺失时使用当前递增值。
	var record: Dictionary = _create_record(item_resource, float(serialized_record.get("acquired_at", 0.0)), str(serialized_record.get("record_id", "")))
	record["acquisition_sequence"] = int(serialized_record.get("acquisition_sequence", record.get("acquisition_sequence", 0)))
	record["last_extraction_epoch"] = int(serialized_record.get("last_extraction_epoch", 0))
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
