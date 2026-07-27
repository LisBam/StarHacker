extends Node

## 新手保护服务维护“尚未首次成功撤离”的永久进度，并向战斗世界提供统一的怪物战斗属性倍率。
## 本服务只订阅 GlobalInventory 的正式结算状态，不依赖 HUD、地图或具体怪物类型；首次成功撤离后立即持久化结束状态。
## 任何展示层可在结算后消费一次结束提示，但战斗期间不会向玩家展示保护正在生效的提示。

## 首次成功撤离完成信号；HUD 等展示层可订阅并在当前结算流程中弹出一次结束提示。
signal first_successful_extraction_completed

## 新手保护独立存档路径；与库存、统计分离，保证首次撤离资格不受统计字段扩展影响。
const SAVE_PATH: String = "user://newcomer_protection_state.json"
## 新手保护存档版本；默认 1 仅保存首次成功撤离完成状态，未来字段调整时用于兼容读取。
const SAVE_VERSION: int = 1
## 保护期怪物战斗属性倍率；默认 0.75 表示生命、伤害、防御、移速等战斗属性降低至原来的 75%。
const MONSTER_ATTRIBUTE_MULTIPLIER: float = 0.75
## 成功撤离结算结果标识；与 GlobalInventory 的正式成功结算结果保持一致，其他结果不会结束保护。
const SUCCESS_OUTCOME_RESULT: String = "success"

## 是否已完成首次成功撤离；默认 false，false 时新手保护有效，首次正式成功结算后永久写为 true。
var _has_completed_first_successful_extraction: bool = false
## 结束提示是否尚未被 HUD 消费；默认 false，只在本次运行首次成功撤离后为 true，不写入存档避免跨场景重复弹窗。
var _completion_notice_pending: bool = false
## 全局库存服务缓存；默认从 AutoLoad 获取，用于监听正式对局状态转换与读取最后结算结果。
var _global_inventory: Node


func _ready() -> void:
	## 服务在暂停状态下也需要可靠完成结算状态持久化，避免结算遮罩暂停场景树时遗漏写盘。
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 存档读取结果；首次引入本服务时用于决定是否需要从既有生涯统计迁移已完成的成功撤离记录。
	var state_loaded: bool = _load_state()
	_migrate_existing_successful_extraction(state_loaded)
	_connect_global_inventory()


func _notification(what: int) -> void:
	## 关闭窗口前再次写入已经结束的保护状态，防止结算后立刻关闭游戏造成状态回退。
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()


func is_newcomer_protection_active() -> bool:
	## 返回当前档案是否仍处于首次成功撤离前；战斗世界只读取此查询，不直接访问服务私有状态。
	return not _has_completed_first_successful_extraction


func has_completed_first_successful_extraction() -> bool:
	## 返回当前档案是否已经完成首次正式成功撤离；局外成长入口只读取本资格，不访问新手保护私有状态或复制进度。
	return _has_completed_first_successful_extraction


func get_monster_attribute_multiplier() -> float:
	## 返回当前怪物战斗属性倍率；保护结束后固定返回中性值 1.0，调用方可直接与其他模式倍率相乘。
	return MONSTER_ATTRIBUTE_MULTIPLIER if is_newcomer_protection_active() else 1.0


func consume_completion_notice() -> bool:
	## 消费本次运行的首次撤离结束提示；同一结算流程重复查询只会有第一次返回 true。
	if not _completion_notice_pending:
		return false
	_completion_notice_pending = false
	return true


func _connect_global_inventory() -> void:
	## 连接正式结算状态源；AutoLoad 顺序异常时延后一帧重试，服务缺失不会阻断其他系统启动。
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if _global_inventory == null:
		call_deferred("_connect_global_inventory")
		return
	if _global_inventory.has_signal("run_state_changed") and not _global_inventory.is_connected("run_state_changed", Callable(self, "_on_run_state_changed")):
		_global_inventory.connect("run_state_changed", Callable(self, "_on_run_state_changed"))


func _on_run_state_changed() -> void:
	## 在正式对局结束时读取统一结算结果；开始对局、失败、逃跑和训练场都不会改变首次撤离资格。
	if _has_completed_first_successful_extraction or _global_inventory == null:
		return
	if _global_inventory.has_method("is_combat_run_active") and bool(_global_inventory.call("is_combat_run_active")):
		return
	if not _global_inventory.has_method("get_last_run_outcome"):
		return
	# 最近结算结果；只有库存服务已经完成正式成功结算时才包含 success 标识。
	var outcome: Dictionary = _global_inventory.call("get_last_run_outcome") as Dictionary
	if str(outcome.get("result", "")) != SUCCESS_OUTCOME_RESULT:
		return
	_has_completed_first_successful_extraction = true
	_completion_notice_pending = true
	_save_state()
	first_successful_extraction_completed.emit()


func _migrate_existing_successful_extraction(state_loaded: bool) -> void:
	## 首次引入独立保护存档时，读取既有生涯统计迁移已成功撤离的老档，避免老玩家重新获得保护。
	if state_loaded or _has_completed_first_successful_extraction:
		return
	# 生涯统计服务；本服务注册在 StatsService 之后，缺失或独立测试时保持新档保护默认值。
	var stats_service: Node = get_tree().root.get_node_or_null("StatsService")
	if stats_service == null or not stats_service.has_method("get_statistics_snapshot"):
		return
	# 生涯统计快照；成功撤离大于 0 时说明该档已经越过首次撤离门槛，不应再次显示结束提示。
	var statistics_snapshot: Dictionary = stats_service.call("get_statistics_snapshot") as Dictionary
	if int(statistics_snapshot.get("total_success_extractions", 0)) <= 0:
		return
	_has_completed_first_successful_extraction = true
	_save_state()


func _save_state() -> void:
	## 持久化首次撤离完成状态；只有项目注册的唯一 AutoLoad 可以写入，独立测试实例保持纯内存。
	if get_tree() == null or get_tree().root.get_node_or_null("NewcomerProtectionService") != self:
		return
	# 存档数据；只保存永久进度，不保存当前弹窗是否已展示等运行期 UI 状态。
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"has_completed_first_successful_extraction": _has_completed_first_successful_extraction,
	}
	# 存档文件；打开失败时保留内存状态，后续结算或退出时会再次尝试写入。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()


func _load_state() -> bool:
	## 读取首次撤离完成状态；文件缺失、损坏或字段异常时按新档保护有效处理。
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	# 存档文件；无法读取时继续保持默认保护状态。
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return false
	# 存档文本；读取后立即关闭句柄，避免后续结算覆盖状态时占用同一文件。
	var save_text: String = save_file.get_as_text()
	save_file.close()
	# 解析结果；仅接受字典根节点，避免错误数据关闭玩家的新手保护。
	var parsed_data: Variant = JSON.parse_string(save_text)
	if not (parsed_data is Dictionary):
		return false
	# 存档字典；当前版本只读取完成标识，缺失字段按 false 处理以兼容旧档。
	var save_data: Dictionary = parsed_data as Dictionary
	_has_completed_first_successful_extraction = bool(save_data.get("has_completed_first_successful_extraction", false))
	return true
