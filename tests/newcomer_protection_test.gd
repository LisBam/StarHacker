extends Node

## 新手保护专项自动验证覆盖服务默认倍率、首次成功撤离功能解锁、主菜单与大厅入口防绕过、怪物战斗属性降级和联机协议代际。
## 属性倍率测试只创建未加入场景树的临时对象；正式结算测试会访问 AutoLoad，必须在独立用户数据目录运行以隔离日常存档。

## 基础怪物脚本；用于创建脱离场景树的近战属性测试对象，避免加载完整战斗世界。
const BASIC_MONSTER_SCRIPT: Script = preload("res://scripts/enemies/basic_monster.gd")
## 远程怪物脚本；用于验证父类保护属性与远程弹体专属属性会共同降低。
const RANGED_MONSTER_SCRIPT: Script = preload("res://scripts/enemies/ranged_monster.gd")
## 新手保护服务脚本；用于验证新档默认处于保护状态且统一输出 0.75 倍率。
const NEWCOMER_PROTECTION_SERVICE_SCRIPT: Script = preload("res://scripts/game/newcomer_protection_service.gd")
## 主菜单场景；用于验证锻造、据点、派遣与悬赏在首次成功撤离前锁定并在完成后实时开放。
## 模式解锁补充：同一场景还验证娱乐模式与模式扩展共用首次正式成功撤离资格。
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
## 正式战斗场景；用于验证首次引导两分钟单出口、阶段目标与三项固定保底内容。
const GAME_WORLD_SCENE: PackedScene = preload("res://scenes/game/game_world.tscn")
## 骇入协议组件脚本；用于纯内存验证首次引导固定候选不会影响后续随机规则。
const HACK_PROTOCOL_COMPONENT_SCRIPT: Script = preload("res://scripts/components/hack_protocol_component.gd")
## 联机会话脚本；用于读取新增敌人保护倍率后要求的协议版本。
const NETWORK_SESSION_SCRIPT: Script = preload("res://scripts/game/network_session.gd")

## 当前失败数量；默认 0，任何断言失败后递增，并在全部检查后决定进程退出码。
var _failure_count: int = 0


func _ready() -> void:
	## 顺序执行属性与正式结算验证；测试命令必须指定隔离 APPDATA，保证实际持久化事件不触及日常用户存档。
	_test_newcomer_service_default_state()
	await _test_first_run_tutorial_transition()
	await _test_first_successful_extraction_transition()
	_test_backpack_capacity_and_extraction_rules()
	_test_basic_monster_protection_attributes()
	_test_ranged_monster_protection_attributes()
	_test_network_protocol_version()
	if _failure_count > 0:
		push_error("新手保护专项测试失败：%d 项。" % _failure_count)
		get_tree().quit(1)
		return
	print("NEWCOMER_PROTECTION_TEST_PASS")
	get_tree().quit(0)


func _test_newcomer_service_default_state() -> void:
	## 验证未读取存档的独立服务实例保持新档保护状态，并返回需求声明的 75% 怪物属性倍率。
	# 临时服务实例；未加入根节点，因此其私有保存守卫不会获得用户目录写入权限。
	var protection_service: Node = NEWCOMER_PROTECTION_SERVICE_SCRIPT.new() as Node
	_check(protection_service != null, "新手保护服务脚本必须可实例化。")
	if protection_service == null:
		return
	_check(bool(protection_service.call("is_newcomer_protection_active")), "新档默认必须启用新手保护。")
	_check(is_equal_approx(float(protection_service.call("get_monster_attribute_multiplier")), 0.75), "新手保护怪物属性倍率必须固定为 0.75。")
	_check(bool(protection_service.call("should_start_first_run_tutorial")), "新档第一次启动必须进入一次性首次战斗引导。")
	_check(not bool(protection_service.call("has_completed_first_run_tutorial")), "新档不得提前完成首次战斗引导。")
	protection_service.free()


func _test_first_run_tutorial_transition() -> void:
	## 验证启动引导配置、0 至 8 分钟阶段规则、固定协议候选与 tutorial_success 结算不会结束新手保护或解锁正式功能。
	# 全局库存服务；本测试运行于隔离用户目录，用于验证独立引导结算结果与永久字段。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	# 新手保护服务；负责开始与完成一次性引导，同时保持首次正式撤离资格为 false。
	var protection_service: Node = get_tree().root.get_node_or_null("NewcomerProtectionService")
	# 会话状态服务；引导开始后应固定标准骇入、星角色、骇入协议与运行期教学标志。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	_check(global_inventory != null and protection_service != null and session_state != null, "首次引导测试必须取得库存、新手保护与会话三个 AutoLoad。")
	if global_inventory == null or protection_service == null or session_state == null:
		return
	protection_service.call("begin_first_run_tutorial")
	_check(bool(session_state.call("is_first_run_tutorial_active")), "首次启动必须写入引导会话标志。")
	_check(str(session_state.get("game_mode")) == "hack" and str(session_state.call("get_hack_variant")) == "standard", "首次引导必须固定使用标准骇入。")
	_check(str(session_state.call("get_selected_character_id")) == "stelle", "首次引导必须固定使用星角色。")
	_check(bool(session_state.call("is_hack_protocol_enabled")), "首次引导必须启用骇入协议扩展。")
	# 脱离场景树的战斗世界；只验证纯规则与导出资源，不启动真实人口、库存或 UI。
	var tutorial_world: Node = GAME_WORLD_SCENE.instantiate()
	_check(tutorial_world != null, "首次引导规则测试必须可以实例化战斗世界。")
	if tutorial_world != null:
		tutorial_world.set("_is_first_run_tutorial", true)
		_check(int(tutorial_world.call("_get_effective_extraction_point_count")) == 1, "首次引导只能生成 1 个正式撤离点。")
		_check(is_equal_approx(float(tutorial_world.call("_get_effective_extraction_spawn_time_seconds")), 120.0), "首次引导撤离点必须在 120 秒出现。")
		_check(is_equal_approx(float(tutorial_world.call("_get_effective_extraction_map_marker_time_seconds")), 120.0), "首次引导撤离点出现时必须立即在地图标记。")
		_check(str(tutorial_world.call("get_first_run_tutorial_objective_text")).contains("普通敌人"), "首次引导第一阶段必须明确要求击败普通敌人。")
		# 首杀武器模板；稳定 ID 必须为 formation_breaker，对应玩家可见名称“陷阵”。
		var tutorial_weapon: Resource = tutorial_world.get("tutorial_first_kill_weapon") as Resource
		# 首箱防具模板；稳定 ID 必须为 origin_armor，对应玩家可见名称“起源护甲”。
		var tutorial_equipment: Resource = tutorial_world.get("tutorial_first_chest_equipment") as Resource
		_check(tutorial_weapon != null and str(tutorial_weapon.get("weapon_id")) == "formation_breaker", "首次击杀必须保底掉落“陷阵”。")
		_check(tutorial_equipment != null and str(tutorial_equipment.get("equipment_id")) == "origin_armor", "首次开箱必须保底掉落“起源护甲”。")
		tutorial_world.free()
	# 临时协议组件；不加入场景树，不读取玩家组件或写入存档，只验证固定首轮候选。
	var protocol_component: Node = HACK_PROTOCOL_COMPONENT_SCRIPT.new() as Node
	_check(protocol_component != null, "首次引导固定协议候选测试必须可以实例化组件。")
	if protocol_component != null:
		# 预期首轮候选；按设计顺序提供连发、散射与击杀回血。
		var expected_offer_ids: Array[String] = ["weapon_combo_bonus", "weapon_scatter_bonus", "kill_health_restore"]
		_check(bool(protocol_component.call("set_first_offer_override_ids", expected_offer_ids)), "首轮固定协议候选必须可在碎片满足前注入。")
		protocol_component.call("add_fragments", HackProtocolRules.BASE_FRAGMENT_REQUIREMENT)
		# 实际首轮候选；规范为强类型列表后与设计顺序逐项比较。
		var actual_offer_ids: Array[String] = HackProtocolRules.normalize_protocol_ids(protocol_component.call("get_offer_ids") as Array)
		_check(actual_offer_ids == expected_offer_ids, "首次引导协议候选必须严格保持设计顺序且不随机，实际为 %s。" % str(actual_offer_ids))
		protocol_component.free()
	global_inventory.call("begin_combat_run", false, true)
	# 引导结算结果；保留物品但显式声明不参与永久进度。
	var tutorial_outcome: Dictionary = global_inventory.call("complete_combat_run_tutorial") as Dictionary
	_check(str(tutorial_outcome.get("result", "")) == "tutorial_success", "首次引导撤离必须产生独立 tutorial_success 结果。")
	_check(not bool(tutorial_outcome.get("progression_eligible", true)), "首次引导结算必须禁止正式统计、行情和解锁进度。")
	_check(bool(protection_service.call("has_completed_first_run_tutorial")), "引导撤离后必须永久完成一次性教学。")
	_check(not bool(protection_service.call("has_completed_first_successful_extraction")), "引导撤离不得计为首次正式成功撤离。")
	_check(bool(protection_service.call("is_newcomer_protection_active")), "引导撤离后新手保护必须继续有效。")
	_check(not bool(session_state.call("is_first_run_tutorial_active")), "引导结束后必须清除运行期教学标志。")
	await get_tree().process_frame
	# 引导状态存档；必须只写教学完成，正式首次撤离字段仍为 false。
	var tutorial_save_file: FileAccess = FileAccess.open("user://newcomer_protection_state.json", FileAccess.READ)
	_check(tutorial_save_file != null, "首次引导完成状态必须写入新手成长存档。")
	if tutorial_save_file != null:
		# 引导存档数据；只读验证两个永久字段彼此独立。
		var tutorial_save_data: Variant = JSON.parse_string(tutorial_save_file.get_as_text())
		tutorial_save_file.close()
		_check(tutorial_save_data is Dictionary and bool((tutorial_save_data as Dictionary).get("has_completed_first_run_tutorial", false)), "新手成长存档必须保存首次引导完成状态。")
		_check(tutorial_save_data is Dictionary and not bool((tutorial_save_data as Dictionary).get("has_completed_first_successful_extraction", true)), "首次引导存档不得提前写入正式首撤完成状态。")


func _test_first_successful_extraction_transition() -> void:
	## 验证失败结算不解锁，首次正式成功结算会永久结束保护、开放四个成长入口并只产生一次结束提示。
	# 全局库存服务；正式成功撤离由该服务写入结算结果并发送状态变化信号。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	# 项目注册的新手保护服务；本测试运行在独立 APPDATA 中，允许验证真实持久化事件而不影响日常存档。
	var protection_service: Node = get_tree().root.get_node_or_null("NewcomerProtectionService")
	# 悬赏服务；首次成功撤离前必须拒绝统计事实事件推进，完成后才正式启用。
	var bounty_service: Node = get_tree().root.get_node_or_null("BountyService")
	_check(global_inventory != null, "正式结算测试必须取得全局库存服务。")
	_check(protection_service != null, "正式结算测试必须取得项目注册的新手保护服务。")
	_check(bounty_service != null, "正式结算测试必须取得悬赏服务。")
	if global_inventory == null or protection_service == null:
		return
	_check(bool(protection_service.call("is_newcomer_protection_active")), "首次成功撤离前全局新手保护必须有效。")
	_check(not bool(protection_service.call("has_completed_first_successful_extraction")), "新档不得提前取得首次成功撤离资格。")
	if bounty_service != null:
		_check(not bool(bounty_service.call("_is_bounty_feature_unlocked")), "首次成功撤离前悬赏事实事件推进必须锁定。")
	# 主菜单实例；构建正式入口与遮罩，用于验证玩家可见锁定表现和大厅动作旁路。
	var main_menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	_check(main_menu != null, "首次撤离解锁测试必须可以实例化主菜单。")
	if main_menu == null:
		return
	add_child(main_menu)
	await get_tree().process_frame
	# 锻造按钮；首次成功撤离前必须纯黑禁用并显示统一条件。
	var forge_button: Button = main_menu.get_node("%ForgeButton") as Button
	# 据点按钮；与锻造共享同一永久资格。
	var hideout_button: Button = main_menu.get_node("%HideoutButton") as Button
	# 派遣按钮；与锻造共享同一永久资格。
	var dispatch_button: Button = main_menu.get_node("%DispatchButton") as Button
	# 悬赏按钮；与锻造共享同一永久资格。
	var bounty_button: Button = main_menu.get_node("%BountyButton") as Button
	# 骇入模式面板；单人娱乐模式卡片与模式扩展入口同样不得在首次正式成功撤离前使用。
	var hack_mode_panel: Control = main_menu.get_node("HackModeOverlay/HackModeSelectPanel") as Control
	# 超频进入按钮；娱乐模式唯一当前卡片，锁定时必须复用统一首撤提示与纯黑禁用外观。
	var overclock_enter_button: Button = hack_mode_panel.find_child("OverclockEnterButton", true, false) as Button if hack_mode_panel != null else null
	_check(_is_first_extraction_button_locked(forge_button), "首次成功撤离前锻造必须锁定。")
	_check(_is_first_extraction_button_locked(hideout_button), "首次成功撤离前据点必须锁定。")
	_check(_is_first_extraction_button_locked(dispatch_button), "首次成功撤离前派遣必须锁定。")
	_check(_is_first_extraction_button_locked(bounty_button), "首次成功撤离前悬赏必须锁定。")
	_check(_is_first_extraction_button_locked(overclock_enter_button), "首次成功撤离前超频骇入必须锁定。")
	# 锻造锁定样式；四个入口复用同一局部样式，抽查锻造必须为完全不透明纯黑背景。
	var forge_locked_style: StyleBox = forge_button.get_theme_stylebox("disabled")
	_check(forge_locked_style is StyleBoxFlat and (forge_locked_style as StyleBoxFlat).bg_color == Color(0.0, 0.0, 0.0, 1.0), "首次撤离成长入口锁定时必须使用纯黑背景。")
	main_menu.call("perform_lobby_action", "forge")
	main_menu.call("perform_lobby_action", "hideout")
	main_menu.call("perform_lobby_action", "dispatch")
	main_menu.call("perform_lobby_action", "bounty")
	# 锻造遮罩；大厅动作在锁定时不得绕过主菜单按钮。
	var forge_overlay: Control = main_menu.get_node("ForgeOverlay") as Control
	# 据点遮罩；大厅动作在锁定时不得绕过主菜单按钮。
	var hideout_overlay: Control = main_menu.get_node("HideoutOverlay") as Control
	# 派遣遮罩；大厅动作在锁定时不得绕过主菜单按钮。
	var dispatch_overlay: Control = main_menu.get_node("DispatchOverlay") as Control
	# 悬赏遮罩；大厅动作在锁定时不得绕过主菜单按钮。
	var bounty_overlay: Control = main_menu.get_node("BountyOverlay") as Control
	_check(not forge_overlay.visible and not hideout_overlay.visible and not dispatch_overlay.visible and not bounty_overlay.visible, "首次成功撤离前大厅动作不得打开四个成长面板。")
	global_inventory.call("begin_combat_run", false)
	# 正式失败结算结果；死亡或逃跑不能提前满足首次成功撤离条件。
	var failure_outcome: Dictionary = global_inventory.call("complete_combat_run_failure", "测试失败", 1.0, 1.0) as Dictionary
	_check(str(failure_outcome.get("result", "")) == "failure", "正式失败结算必须产生 failure 结果。")
	_check(bool(protection_service.call("is_newcomer_protection_active")), "正式失败结算后新手保护和功能锁定必须继续有效。")
	_check(_is_first_extraction_button_locked(forge_button) and _is_first_extraction_button_locked(hideout_button) and _is_first_extraction_button_locked(dispatch_button) and _is_first_extraction_button_locked(bounty_button), "失败结算不得解锁任何首次撤离成长入口。")
	global_inventory.call("begin_combat_run", false)
	# 正式结算结果；成功标识是服务结束保护的唯一有效触发条件。
	var outcome: Dictionary = global_inventory.call("complete_combat_run_success") as Dictionary
	_check(str(outcome.get("result", "")) == "success", "正式成功撤离必须产生 success 结算结果。")
	_check(not bool(protection_service.call("is_newcomer_protection_active")), "首次正式成功撤离后新手保护必须结束。")
	_check(bool(protection_service.call("has_completed_first_successful_extraction")), "首次正式成功撤离后必须永久取得局外成长功能资格。")
	if bounty_service != null:
		_check(bool(bounty_service.call("_is_bounty_feature_unlocked")), "首次正式成功撤离后悬赏事实事件推进必须开放。")
	_check(not forge_button.disabled and not hideout_button.disabled and not dispatch_button.disabled and not bounty_button.disabled, "首次正式成功撤离后必须同时解锁锻造、据点、派遣与悬赏。")
	_check(forge_button.tooltip_text.is_empty() and hideout_button.tooltip_text.is_empty() and dispatch_button.tooltip_text.is_empty() and bounty_button.tooltip_text.is_empty(), "四个成长入口解锁后必须清除条件提示。")
	await get_tree().process_frame
	# 刷新后的模式选择面板；首次成功信号会重建娱乐模式卡片，因此重新获取节点引用。
	hack_mode_panel = main_menu.get_node("HackModeOverlay/HackModeSelectPanel") as Control
	# 刷新后的超频进入按钮；解锁后必须可用且不保留旧的锁定工具提示。
	overclock_enter_button = hack_mode_panel.find_child("OverclockEnterButton", true, false) as Button if hack_mode_panel != null else null
	_check(overclock_enter_button != null and not overclock_enter_button.disabled and overclock_enter_button.tooltip_text.is_empty(), "首次成功撤离后超频骇入必须立即解锁并清除提示。")
	# 模式扩展遮罩；完成首次正式成功撤离后选择标准骇入必须进入扩展配置流程。
	main_menu.call("_on_hack_mode_selected", HackModeRules.VARIANT_STANDARD)
	var mode_extension_overlay: Control = main_menu.get_node("ModeExtensionOverlay") as Control
	_check(mode_extension_overlay != null and mode_extension_overlay.visible, "首次成功撤离后单人骇入必须开放模式扩展配置窗口。")
	main_menu.call("_on_mode_extension_select_closed")
	_check(bool(protection_service.call("consume_completion_notice")), "首次成功撤离后必须产生一次结束提示。")
	_check(not bool(protection_service.call("consume_completion_notice")), "结束提示被消费后不得在同一结算流程重复弹出。")
	# 新手成长存档；成功结算必须同步落盘永久资格，重启后四个入口不会重新锁定。
	var save_file: FileAccess = FileAccess.open("user://newcomer_protection_state.json", FileAccess.READ)
	_check(save_file != null, "首次成功撤离资格必须写入新手成长存档。")
	if save_file != null:
		# 新手成长存档数据；只读验证唯一完成字段为 true，不修改正式服务内存状态。
		var save_data: Variant = JSON.parse_string(save_file.get_as_text())
		save_file.close()
		_check(save_data is Dictionary and bool((save_data as Dictionary).get("has_completed_first_successful_extraction", false)), "新手成长存档必须永久保存首次成功撤离完成状态。")
		_check(save_data is Dictionary and bool((save_data as Dictionary).get("has_completed_first_run_tutorial", false)), "正式首撤完成后不得丢失已经完成的一次性引导状态。")
	main_menu.queue_free()


func _is_first_extraction_button_locked(button: Button) -> bool:
	## 返回成长入口是否处于标准首次撤离锁定状态；同时验证禁用与玩家可见提示，避免只做视觉伪锁定。
	if button == null:
		return false
	return button.disabled and button.tooltip_text == "首次成功撤离后解锁"


func _test_basic_monster_protection_attributes() -> void:
	## 验证近战怪物的生命、护盾、攻防、移动、视野、攻击距离和攻击频率均按保护规则变弱。
	# 临时近战怪物；所有字段显式赋值，避免默认值变化掩盖倍率错误。
	var monster: BasicMonster = BASIC_MONSTER_SCRIPT.new() as BasicMonster
	_check(monster != null, "基础怪物脚本必须可实例化。")
	if monster == null:
		return
	monster.max_health = 100.0
	monster.current_health = 80.0
	monster.max_shield = 40.0
	monster.current_shield = 30.0
	monster.attack_damage = 40.0
	monster.attack_power = 120.0
	monster.defense_power = 60.0
	monster.toughness = 20.0
	monster.attack_impact_force = 100.0
	monster.attack_front_recoil_force = 30.0
	monster.attack_recoil_force = 10.0
	monster.move_speed = 200.0
	monster.vision_range = 500.0
	monster.attack_range = 80.0
	monster.attack_cooldown = 0.8
	monster.apply_newcomer_protection_multiplier(0.75)
	_check(is_equal_approx(monster.max_health, 75.0), "近战怪物最大生命必须降低至 75%。")
	_check(is_equal_approx(monster.current_health, 60.0), "近战怪物当前生命必须按相同比例降低。")
	_check(is_equal_approx(monster.max_shield, 30.0) and is_equal_approx(monster.current_shield, 22.5), "近战怪物护盾上限与当前值必须降低至 75%。")
	_check(is_equal_approx(monster.attack_damage, 30.0) and is_equal_approx(monster.attack_power, 90.0), "近战怪物伤害与攻击力必须降低至 75%。")
	_check(is_equal_approx(monster.defense_power, 45.0) and is_equal_approx(monster.toughness, 15.0), "近战怪物防御与韧性必须降低至 75%。")
	_check(is_equal_approx(monster.move_speed, 150.0) and is_equal_approx(monster.vision_range, 375.0) and is_equal_approx(monster.attack_range, 60.0), "近战怪物移速、视野与攻击距离必须降低至 75%。")
	_check(is_equal_approx(monster.attack_cooldown, 0.8 / 0.75), "近战怪物冷却必须乘 4/3，使每秒攻击次数降低至 75%。")
	monster.free()


func _test_ranged_monster_protection_attributes() -> void:
	## 验证远程怪物除继承属性外，射程、弹体伤害、速度、距离、冲击力和冷却均按保护规则处理。
	# 临时远程怪物；显式写入基础与远程字段，确保父类与覆写函数都被验证。
	var monster: RangedMonster = RANGED_MONSTER_SCRIPT.new() as RangedMonster
	_check(monster != null, "远程怪物脚本必须可实例化。")
	if monster == null:
		return
	monster.max_health = 80.0
	monster.current_health = 80.0
	monster.attack_power = 150.0
	monster.shoot_range = 500.0
	monster.keep_distance = 260.0
	monster.ranged_projectile_speed = 600.0
	monster.ranged_projectile_damage = 20.0
	monster.ranged_projectile_max_distance = 550.0
	monster.ranged_projectile_impact_force = 25.0
	monster.cooldown = 1.0
	monster.apply_newcomer_protection_multiplier(0.75)
	_check(is_equal_approx(monster.max_health, 60.0) and is_equal_approx(monster.attack_power, 112.5), "远程怪物继承生命与攻击力必须降低至 75%。")
	_check(is_equal_approx(monster.shoot_range, 375.0) and is_equal_approx(monster.keep_distance, 195.0), "远程怪物射程与保持距离必须降低至 75%。")
	_check(is_equal_approx(monster.ranged_projectile_speed, 450.0) and is_equal_approx(monster.ranged_projectile_damage, 15.0), "远程弹体速度与伤害必须降低至 75%。")
	_check(is_equal_approx(monster.ranged_projectile_max_distance, 412.5) and is_equal_approx(monster.ranged_projectile_impact_force, 18.75), "远程弹体距离与冲击力必须降低至 75%。")
	_check(is_equal_approx(monster.cooldown, 1.0 / 0.75), "远程怪物冷却必须乘 4/3，使每秒开火次数降低至 75%。")
	monster.free()


func _test_network_protocol_version() -> void:
	## 验证含 npm 字段的敌人生成消息通过新协议代际隔离，旧客户端不会误以中性倍率解析。
	# 临时会话服务；只读取协议常量，不创建网络端口或写入任何会话状态。
	var network_session: Node = NETWORK_SESSION_SCRIPT.new() as Node
	_check(network_session != null, "联机会话脚本必须可实例化。")
	if network_session == null:
		return
	_check(int(network_session.call("get_protocol_version")) == 4, "敌人新手保护倍率同步后联机协议版本必须为 4。")
	network_session.free()


func _test_backpack_capacity_and_extraction_rules() -> void:
	## 验证战术仓储舱的六档背包容量、风险倍率的实时基数、四分钟地图标记与正式撤离驻留离开后累计规则。
	# 全局库存服务；用于验证 UI 与拾取共用的公开容量接口会读取据点实时等级。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	# 据点服务；用于构造 0 至 5 级战术仓储舱的纯内存等级快照。
	var hideout_service: Node = get_tree().root.get_node_or_null("HideoutService")
	_check(global_inventory != null and hideout_service != null, "背包容量验证必须取得库存与据点 AutoLoad。")
	if global_inventory == null or hideout_service == null:
		return
	# 原始设施等级表；测试完成后完整恢复，避免影响同一进程内后续用例。
	var original_levels: Dictionary = (hideout_service.get("_facility_levels") as Dictionary).duplicate(true)
	# 容量等级遍历值；依次覆盖用户指定的 0 至 5 级升级档位。
	for tactical_storage_level in range(6):
		# 本轮设施等级表；只覆盖战术仓储舱，其他设施保持原测试状态。
		var test_levels: Dictionary = original_levels.duplicate(true)
		test_levels["tactical_storage"] = tactical_storage_level
		hideout_service.set("_facility_levels", test_levels)
		# 本轮期望容量；初始 25 组，每级增加 5 组，5 级达到 50 组。
		var expected_capacity_groups: int = 25 + tactical_storage_level * 5
		_check(int(hideout_service.call("get_backpack_capacity_groups")) == expected_capacity_groups, "战术仓储舱等级 %d 的背包上限应为 %d 组。" % [tactical_storage_level, expected_capacity_groups])
		_check(int(global_inventory.call("get_backpack_max_groups")) == expected_capacity_groups, "GlobalInventory 必须读取战术仓储舱等级 %d 的实时背包上限。" % tactical_storage_level)
	# 0 级据点等级表；风险合约容量倍率必须以新的 25 组初始值计算。
	var level_zero: Dictionary = original_levels.duplicate(true)
	level_zero["tactical_storage"] = 0
	hideout_service.set("_facility_levels", level_zero)
	global_inventory.call("set_combat_backpack_capacity_multiplier", 0.50)
	_check(int(global_inventory.call("get_backpack_max_groups")) == 13, "25 组基础容量在 50% 风险合约下应四舍五入为 13 组。")
	global_inventory.call("set_combat_backpack_capacity_multiplier", 1.0)
	hideout_service.set("_facility_levels", original_levels)

	# 正式战斗世界；仅调用撤离纯状态函数，不启动场景人口、HUD 或库存结算。
	var game_world: Node = GAME_WORLD_SCENE.instantiate()
	_check(game_world != null, "撤离累计规则测试必须可以实例化战斗世界。")
	if game_world == null:
		return
	# 临时玩家节点；没有属性组件时世界按存活状态处理，位置用于模拟进出撤离范围。
	var test_player: Node2D = Node2D.new()
	game_world.add_child(test_player)
	# 正式撤离点位置表；使用原点单点即可覆盖进入、离开和重新进入的累计状态。
	var extraction_positions: Array[Vector2] = [Vector2.ZERO]
	game_world.set("_player", test_player)
	game_world.set("_has_extraction_point", true)
	game_world.set("_extraction_point_positions", extraction_positions)
	game_world.set("extraction_radius", 96.0)
	_check(is_equal_approx(float(game_world.get("extraction_map_marker_time_seconds")), 240.0), "常规正式撤离点地图标记时间应为 240 秒。")
	test_player.global_position = Vector2.ZERO
	game_world.call("_update_extraction_state", 2.0)
	_check(is_equal_approx(float(game_world.call("get_extraction_hold_elapsed_seconds")), 2.0), "首次进入正式撤离点应累计 2 秒。")
	test_player.global_position = Vector2(1000.0, 0.0)
	game_world.call("_update_extraction_state", 10.0)
	_check(is_equal_approx(float(game_world.call("get_extraction_hold_elapsed_seconds")), 2.0), "离开正式撤离点后累计驻留时间不得重置或继续增加。")
	test_player.global_position = Vector2.ZERO
	game_world.call("_update_extraction_state", 3.0)
	_check(bool(game_world.call("is_extraction_ready_to_leave")), "重新进入后累计满 5 秒应达到正式撤离就绪状态。")
	test_player.global_position = Vector2(1000.0, 0.0)
	game_world.call("_update_extraction_state", 1.0)
	_check(bool(game_world.call("is_extraction_ready_to_leave")) and not bool(game_world.call("is_player_inside_extraction_area")), "离开已就绪撤离点必须保留累计进度，但输入层仍可依据范围状态拒绝撤离。")
	game_world.free()


func _check(condition: bool, failure_message: String) -> void:
	## 记录单条断言失败；保留后续检查以便一次运行输出全部不符合预期的属性。
	if condition:
		return
	_failure_count += 1
	push_error(failure_message)
