extends Node

## 新手保护专项自动验证覆盖服务默认倍率、首次成功撤离功能解锁、主菜单与大厅入口防绕过、怪物战斗属性降级和联机协议代际。
## 属性倍率测试只创建未加入场景树的临时对象；正式结算测试会访问 AutoLoad，必须在独立用户数据目录运行以隔离日常存档。

## 基础怪物脚本；用于创建脱离场景树的近战属性测试对象，避免加载完整战斗世界。
const BASIC_MONSTER_SCRIPT: Script = preload("res://scripts/enemies/basic_monster.gd")
## 远程怪物脚本；用于验证父类保护属性与远程弹体专属属性会共同降低。
const RANGED_MONSTER_SCRIPT: Script = preload("res://scripts/enemies/ranged_monster.gd")
## 新手保护服务脚本；用于验证新档默认处于保护状态且统一输出 0.50 倍率。
const NEWCOMER_PROTECTION_SERVICE_SCRIPT: Script = preload("res://scripts/game/newcomer_protection_service.gd")
## 主菜单场景；用于验证锻造、据点、派遣与悬赏在首次成功撤离前锁定并在完成后实时开放。
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
## 联机会话脚本；用于读取新增敌人保护倍率后要求的协议版本。
const NETWORK_SESSION_SCRIPT: Script = preload("res://scripts/game/network_session.gd")

## 当前失败数量；默认 0，任何断言失败后递增，并在全部检查后决定进程退出码。
var _failure_count: int = 0


func _ready() -> void:
	## 顺序执行属性与正式结算验证；测试命令必须指定隔离 APPDATA，保证实际持久化事件不触及日常用户存档。
	_test_newcomer_service_default_state()
	await _test_first_successful_extraction_transition()
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
	## 验证未读取存档的独立服务实例保持新档保护状态，并返回需求声明的 50% 怪物属性倍率。
	# 临时服务实例；未加入根节点，因此其私有保存守卫不会获得用户目录写入权限。
	var protection_service: Node = NEWCOMER_PROTECTION_SERVICE_SCRIPT.new() as Node
	_check(protection_service != null, "新手保护服务脚本必须可实例化。")
	if protection_service == null:
		return
	_check(bool(protection_service.call("is_newcomer_protection_active")), "新档默认必须启用新手保护。")
	_check(is_equal_approx(float(protection_service.call("get_monster_attribute_multiplier")), 0.50), "新手保护怪物属性倍率必须固定为 0.50。")
	protection_service.free()


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
	_check(_is_first_extraction_button_locked(forge_button), "首次成功撤离前锻造必须锁定。")
	_check(_is_first_extraction_button_locked(hideout_button), "首次成功撤离前据点必须锁定。")
	_check(_is_first_extraction_button_locked(dispatch_button), "首次成功撤离前派遣必须锁定。")
	_check(_is_first_extraction_button_locked(bounty_button), "首次成功撤离前悬赏必须锁定。")
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
	monster.apply_newcomer_protection_multiplier(0.50)
	_check(is_equal_approx(monster.max_health, 50.0), "近战怪物最大生命必须降低至 50%。")
	_check(is_equal_approx(monster.current_health, 40.0), "近战怪物当前生命必须按相同比例降低。")
	_check(is_equal_approx(monster.max_shield, 20.0) and is_equal_approx(monster.current_shield, 15.0), "近战怪物护盾上限与当前值必须降低至 50%。")
	_check(is_equal_approx(monster.attack_damage, 20.0) and is_equal_approx(monster.attack_power, 60.0), "近战怪物伤害与攻击力必须降低至 50%。")
	_check(is_equal_approx(monster.defense_power, 30.0) and is_equal_approx(monster.toughness, 10.0), "近战怪物防御与韧性必须降低至 50%。")
	_check(is_equal_approx(monster.move_speed, 100.0) and is_equal_approx(monster.vision_range, 250.0) and is_equal_approx(monster.attack_range, 40.0), "近战怪物移速、视野与攻击距离必须降低至 50%。")
	_check(is_equal_approx(monster.attack_cooldown, 1.6), "近战怪物冷却必须翻倍，使每秒攻击次数降低至 50%。")
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
	monster.apply_newcomer_protection_multiplier(0.50)
	_check(is_equal_approx(monster.max_health, 40.0) and is_equal_approx(monster.attack_power, 75.0), "远程怪物继承生命与攻击力必须降低至 50%。")
	_check(is_equal_approx(monster.shoot_range, 250.0) and is_equal_approx(monster.keep_distance, 130.0), "远程怪物射程与保持距离必须降低至 50%。")
	_check(is_equal_approx(monster.ranged_projectile_speed, 300.0) and is_equal_approx(monster.ranged_projectile_damage, 10.0), "远程弹体速度与伤害必须降低至 50%。")
	_check(is_equal_approx(monster.ranged_projectile_max_distance, 275.0) and is_equal_approx(monster.ranged_projectile_impact_force, 12.5), "远程弹体距离与冲击力必须降低至 50%。")
	_check(is_equal_approx(monster.cooldown, 2.0), "远程怪物冷却必须翻倍，使每秒开火次数降低至 50%。")
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


func _check(condition: bool, failure_message: String) -> void:
	## 记录单条断言失败；保留后续检查以便一次运行输出全部不符合预期的属性。
	if condition:
		return
	_failure_count += 1
	push_error(failure_message)
