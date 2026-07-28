extends Node

## 单局统计与近期战绩专项验证：覆盖四项结算数据、三类正式结果、20 局裁剪、训练场排除和主菜单“战绩”入口。
## 被测数据使用非 AutoLoad 的 StatsService 实例且不会取得持久化所有权；项目 AutoLoad 仍会在启动时访问用户目录，因此必须按测试规范使用隔离目录运行。

## 生涯统计服务脚本；独立实例用于验证单局累计、结果归档和 20 局先进后出裁剪。
const STATS_SERVICE_SCRIPT: Script = preload("res://scripts/game/stats_service.gd")
## 主菜单场景；用于验证统计分类按钮顺序、战绩遮罩、面板刷新和关闭协议。
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")

## 当前失败数量；默认 0，所有断言完成后用于决定测试进程退出码。
var _failure_count: int = 0
## 独立统计服务实例；不具备 AutoLoad 名称，因此内部存档所有者校验会阻止任何写盘。
var _test_stats_service: Node = null


func _ready() -> void:
	## 顺序验证服务数据协议与主菜单集成；完成后以明确退出码结束无头测试。
	await _test_recent_run_history_service()
	await _test_main_menu_match_history_integration()
	if _failure_count > 0:
		push_error("单局统计与近期战绩专项测试失败：%d 项。" % _failure_count)
		get_tree().quit(1)
		return
	print("MATCH_HISTORY_TEST_PASS")
	get_tree().quit(0)


func _test_recent_run_history_service() -> void:
	## 生成 21 次正式结算并验证只保留最新 20 次，同时核对结算快照的四项战斗统计。
	# 会话状态服务；测试暂时切换模式验证训练场守卫，结束前恢复全部运行期字段。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	_check(session_state != null, "近期战绩测试必须取得 SessionState。")
	if session_state == null:
		return
	# 原游戏模式；测试结束时原样恢复，避免影响同一进程中的后续验证。
	var original_game_mode: String = str(session_state.get("game_mode"))
	# 原骇入变体；与游戏模式一同恢复，防止测试残留训练或娱乐模式。
	var original_hack_variant: String = str(session_state.get("hack_variant"))
	# 原首次教学标志；正式统计要求该标志为 false，结束时通过公开接口恢复。
	var original_tutorial_active: bool = bool(session_state.call("is_first_run_tutorial_active"))
	session_state.call("set_game_mode", "hack")
	session_state.call("set_hack_variant", "standard")
	session_state.call("set_first_run_tutorial_active", false)

	_test_stats_service = STATS_SERVICE_SCRIPT.new() as Node
	add_child(_test_stats_service)
	await get_tree().process_frame
	_reset_test_service_state()
	# 依次生成 21 局；结果按成功、死亡、逃跑循环，最终列表应覆盖全部三类结果并移除第 1 局。
	for run_index in range(21):
		_test_stats_service.call("record_run_started")
		_test_stats_service.call("record_damage_dealt", 10.0 + float(run_index))
		_test_stats_service.call("record_damage_received", 5.0 + float(run_index))
		# 本局击杀次数；每局为 1 至 4 次循环，验证完成快照读取的是当前局而非生涯总数。
		var run_kill_count: int = run_index % 4 + 1
		for _kill_index in range(run_kill_count):
			_test_stats_service.call("record_monster_killed", "test_monster")
		# 本局开箱次数；每局为 1 至 3 次循环，验证总开箱与当前局开箱分别累计。
		var run_chest_count: int = run_index % 3 + 1
		for _chest_index in range(run_chest_count):
			_test_stats_service.call("record_chest_opened", "common")
		_test_stats_service.call("record_shipped_value", run_index * 10)
		# 本局结果标识；固定循环确保历史中同时存在成功、撤离失败和逃跑。
		var result_id: String = ["success", "death", "escape"][run_index % 3]
		# 成功带出价值；失败结果即使传入正值也必须由服务规范化为 0。
		var extracted_value: int = run_index * 100
		_test_stats_service.call("record_run_finished", result_id, float(run_index * 60 + 5), extracted_value)

	# 近期战绩快照；服务必须返回最新在前的深复制数组。
	var history: Array = _test_stats_service.call("get_recent_run_history") as Array
	_check(history.size() == 20, "近期战绩必须固定保留最新 20 局。")
	if history.size() == 20:
		# 最新战绩；对应生成循环的第 21 局（run_index=20）。
		var latest_run: Dictionary = history[0] as Dictionary
		_check(str(latest_run.get("result_id", "")) == "escape", "最新战绩必须保留第 21 局的逃跑结果。")
		_check(int(latest_run.get("damage_dealt", -1)) == 30, "结算快照必须记录本局造成伤害 30。")
		_check(int(latest_run.get("damage_received", -1)) == 25, "结算快照必须记录本局受到伤害 25。")
		_check(int(latest_run.get("monster_kills", -1)) == 1, "结算快照必须记录本局击杀数 1。")
		_check(int(latest_run.get("chests_opened", -1)) == 3, "结算快照必须记录本局开启宝箱数 3。")
		_check(int(latest_run.get("extracted_value", -1)) == 0, "逃跑战绩的带出价值必须规范化为 0。")
		_check(int(latest_run.get("shipped_value", -1)) == 200, "战绩必须保留本局已送回价值 200。")
		# 第二、第三条结果；对应 run_index=19 和 18，用于核对三类结果均被保存。
		var second_run: Dictionary = history[1] as Dictionary
		var third_run: Dictionary = history[2] as Dictionary
		_check(str(second_run.get("result_id", "")) == "death", "近期战绩必须保存撤离失败结果。")
		_check(str(third_run.get("result_id", "")) == "success", "近期战绩必须保存撤离成功结果。")
		# 最早保留战绩；第 1 局已被裁剪，因此末尾应为 run_index=1。
		var oldest_kept_run: Dictionary = history[19] as Dictionary
		_check(int(oldest_kept_run.get("damage_dealt", -1)) == 11, "超过上限后必须移除最早一局并保留第 2 局。")
	# 重复结算结果；没有新的 record_run_started 时必须返回空字典，避免同一局被二次写入历史。
	var duplicate_result: Dictionary = _test_stats_service.call("record_run_finished", "success", 1.0, 1) as Dictionary
	_check(duplicate_result.is_empty(), "没有活动正式对局时不得生成重复战绩。")
	_check((_test_stats_service.call("get_recent_run_history") as Array).size() == 20, "重复结算不得改变最近 20 局列表。")

	# 训练场前的正式对局总数；训练场事实入口全部调用后该数值和战绩数量都不得变化。
	var total_runs_before_training: int = int((_test_stats_service.call("get_statistics_snapshot") as Dictionary).get("total_runs_started", -1))
	session_state.call("set_game_mode", "training")
	_test_stats_service.call("record_run_started")
	_test_stats_service.call("record_damage_dealt", 999.0)
	_test_stats_service.call("record_damage_received", 999.0)
	_test_stats_service.call("record_monster_killed", "training_monster")
	_test_stats_service.call("record_chest_opened", "supreme")
	# 训练场结束返回值；永久进度守卫应直接返回空字典且不形成战绩。
	var training_result: Dictionary = _test_stats_service.call("record_run_finished", "success", 999.0, 9999) as Dictionary
	_check(training_result.is_empty(), "训练场结算上报必须被永久进度守卫拒绝。")
	_check((_test_stats_service.call("get_recent_run_history") as Array).size() == 20, "训练场不得进入最近 20 局战绩。")
	_check(int((_test_stats_service.call("get_statistics_snapshot") as Dictionary).get("total_runs_started", -1)) == total_runs_before_training, "训练场不得增加正式对局数。")

	session_state.call("set_game_mode", original_game_mode)
	session_state.call("set_hack_variant", original_hack_variant)
	session_state.call("set_first_run_tutorial_active", original_tutorial_active)


func _test_main_menu_match_history_integration() -> void:
	## 验证统计分类第三个按钮、战绩遮罩、20 张卡片刷新和关闭后的焦点宿主协议。
	if _test_stats_service == null:
		return
	# 主菜单实例；完整执行动态面板构建，确保新增脚本能够在真实宿主中正常初始化。
	var main_menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	_check(main_menu != null, "主菜单场景必须可以实例化。")
	if main_menu == null:
		return
	add_child(main_menu)
	await get_tree().process_frame
	# 统计按钮容器；直接子节点顺序就是玩家展开分类后看到的纵向顺序。
	var statistics_button_container: VBoxContainer = main_menu.get_node("BottomCategoryExpansionMargin/StatisticsCategoryPanel/Margin/Buttons") as VBoxContainer
	_check(_get_child_name_order(statistics_button_container) == ["EncyclopediaButton", "StatsButton", "MatchHistoryButton"], "统计分类必须按图鉴、生涯、战绩排列。")
	main_menu.call("_on_match_history_button_pressed")
	# 战绩遮罩；点击入口后必须显示并阻止主菜单其他控件交互。
	var match_history_overlay: Control = main_menu.get_node("MatchHistoryOverlay") as Control
	_check(match_history_overlay != null and match_history_overlay.visible, "点击战绩后必须打开独立遮罩。")
	# 战绩面板；测试注入独立服务后刷新，验证 20 条服务快照都生成卡片。
	var match_history_panel: Control = main_menu.get_node("MatchHistoryOverlay/MatchHistoryPanel") as Control
	_check(match_history_panel != null, "战绩遮罩必须创建 MatchHistoryPanel。")
	if match_history_panel != null:
		match_history_panel.set("_stats_service", _test_stats_service)
		match_history_panel.call("refresh")
		# 战绩卡片列表；非空记录时每条正式战绩对应一个直接子卡片。
		var history_list: VBoxContainer = match_history_panel.get("_history_list") as VBoxContainer
		# 战绩数量说明；必须明确 20 局上限和模式排除口径。
		var history_summary_label: Label = match_history_panel.get("_history_summary_label") as Label
		_check(history_list != null and history_list.get_child_count() == 20, "战绩面板必须展示最近 20 张记录卡片。")
		_check(history_summary_label != null and history_summary_label.text.begins_with("最近 20 / 20 局正式战绩"), "战绩面板必须显示当前记录数量与 20 局上限。")
		match_history_panel.call("_on_close_button_pressed")
		_check(not match_history_overlay.visible, "点击战绩返回按钮后必须关闭遮罩。")
	main_menu.queue_free()
	_test_stats_service.queue_free()


func _reset_test_service_state() -> void:
	## 清空独立服务从磁盘只读恢复的字段；非 AutoLoad 实例不会写盘，测试从确定的全零状态开始。
	# 空字典；分别赋给怪物与物品累计表，防止开发者存档内容影响断言。
	var empty_dictionary: Dictionary = {}
	# 空财富采样数组；本测试不验证资产曲线，移除 ready 阶段自动追加的启动采样。
	var empty_wealth_samples: Array[Dictionary] = []
	# 空战绩数组；确保 21 局裁剪断言从零条记录开始。
	var empty_history: Array[Dictionary] = []
	_test_stats_service.set("_monster_kill_counts", empty_dictionary.duplicate())
	_test_stats_service.set("_item_acquire_counts", empty_dictionary.duplicate())
	_test_stats_service.set("_wealth_samples", empty_wealth_samples)
	_test_stats_service.set("_recent_run_history", empty_history)
	_test_stats_service.set("_current_run_tracking_active", false)
	for property_name in [
		"_total_runs_started",
		"_total_success_extractions",
		"_total_deaths",
		"_total_escapes",
		"_total_monster_kills",
		"_total_chests_opened",
		"_total_shipped_value",
		"_best_run_kills",
		"_best_run_extracted_value",
		"_best_run_shipped_value",
		"_current_run_kills",
		"_current_run_chests_opened",
		"_current_run_damage_dealt",
		"_current_run_damage_received",
		"_current_run_shipped_value",
	]:
		_test_stats_service.set(property_name, 0)
	_test_stats_service.set("_best_run_survival_seconds", 0.0)


func _get_child_name_order(container: Container) -> Array[String]:
	## 返回容器直接子节点名称顺序；用于验证统计展开列表的玩家可见排列。
	# 子节点名称结果；容器缺失时返回空数组并由断言报告失败。
	var child_names: Array[String] = []
	if container == null:
		return child_names
	for child in container.get_children():
		child_names.append(str(child.name))
	return child_names


func _check(condition: bool, failure_message: String) -> void:
	## 记录一项断言；失败时打印清晰原因但继续执行其余检查，便于一次测试收集全部问题。
	if condition:
		return
	_failure_count += 1
	push_error(failure_message)
