extends Node

## 新手保护专项自动验证覆盖服务默认倍率、首次成功撤离状态切换、近战与远程怪物战斗属性降级、冷却反向换算和联机协议代际。
## 属性倍率测试只创建未加入场景树的临时对象；正式结算测试会访问 AutoLoad，必须在独立用户数据目录运行以隔离日常存档。

## 基础怪物脚本；用于创建脱离场景树的近战属性测试对象，避免加载完整战斗世界。
const BASIC_MONSTER_SCRIPT: Script = preload("res://scripts/enemies/basic_monster.gd")
## 远程怪物脚本；用于验证父类保护属性与远程弹体专属属性会共同降低。
const RANGED_MONSTER_SCRIPT: Script = preload("res://scripts/enemies/ranged_monster.gd")
## 新手保护服务脚本；用于验证新档默认处于保护状态且统一输出 0.50 倍率。
const NEWCOMER_PROTECTION_SERVICE_SCRIPT: Script = preload("res://scripts/game/newcomer_protection_service.gd")
## 联机会话脚本；用于读取新增敌人保护倍率后要求的协议版本。
const NETWORK_SESSION_SCRIPT: Script = preload("res://scripts/game/network_session.gd")

## 当前失败数量；默认 0，任何断言失败后递增，并在全部检查后决定进程退出码。
var _failure_count: int = 0


func _ready() -> void:
	## 顺序执行属性与正式结算验证；测试命令必须指定隔离 APPDATA，保证实际持久化事件不触及日常用户存档。
	_test_newcomer_service_default_state()
	_test_first_successful_extraction_transition()
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
	## 验证正式对局首次成功结算会永久结束保护，并且结束提示只能在当前结算流程消费一次。
	# 全局库存服务；正式成功撤离由该服务写入结算结果并发送状态变化信号。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	# 项目注册的新手保护服务；本测试运行在独立 APPDATA 中，允许验证真实持久化事件而不影响日常存档。
	var protection_service: Node = get_tree().root.get_node_or_null("NewcomerProtectionService")
	_check(global_inventory != null, "正式结算测试必须取得全局库存服务。")
	_check(protection_service != null, "正式结算测试必须取得项目注册的新手保护服务。")
	if global_inventory == null or protection_service == null:
		return
	_check(bool(protection_service.call("is_newcomer_protection_active")), "首次成功撤离前全局新手保护必须有效。")
	global_inventory.call("begin_combat_run", false)
	# 正式结算结果；成功标识是服务结束保护的唯一有效触发条件。
	var outcome: Dictionary = global_inventory.call("complete_combat_run_success") as Dictionary
	_check(str(outcome.get("result", "")) == "success", "正式成功撤离必须产生 success 结算结果。")
	_check(not bool(protection_service.call("is_newcomer_protection_active")), "首次正式成功撤离后新手保护必须结束。")
	_check(bool(protection_service.call("consume_completion_notice")), "首次成功撤离后必须产生一次结束提示。")
	_check(not bool(protection_service.call("consume_completion_notice")), "结束提示被消费后不得在同一结算流程重复弹出。")


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
