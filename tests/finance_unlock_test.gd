extends Node

## 金融解锁专项自动验证覆盖规则门槛、累计获得口径、资金转移防刷、主菜单按钮顺序、纯黑锁定样式与实时解锁。
## 测试会访问 GlobalInventory AutoLoad，必须在独立用户数据目录运行，避免修改开发者日常存档。

## 金融解锁规则脚本；用于验证四档门槛和未知功能的安全锁定行为。
const FINANCE_UNLOCK_RULES: Script = preload("res://scripts/data/finance_unlock_rules.gd")
## 主菜单场景；用于验证玩家实际可见按钮的禁用、提示、排列和信号刷新。
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
## 全局库存脚本；用于从隔离存档重新加载第二个只读实例，验证累计值序列化往返。
const GLOBAL_INVENTORY_SCRIPT: Script = preload("res://scripts/game/global_inventory.gd")

## 当前失败数量；默认 0，任何断言失败后递增，并在全部检查后决定进程退出码。
var _failure_count: int = 0


func _ready() -> void:
	## 顺序执行规则、累计口径与主菜单集成验证；所有门槛变化都通过正式公开接口触发。
	_test_rule_table()
	await _test_inventory_and_main_menu_integration()
	if _failure_count > 0:
		push_error("金融解锁专项测试失败：%d 项。" % _failure_count)
		get_tree().quit(1)
		return
	print("FINANCE_UNLOCK_TEST_PASS")
	get_tree().quit(0)


func _test_rule_table() -> void:
	## 验证数值策划定义的约 1、3、6、10 局解锁梯度与稳定成长顺序。
	_check(int(FINANCE_UNLOCK_RULES.get_unlock_threshold(FINANCE_UNLOCK_RULES.FEATURE_INSURANCE)) == 1000, "保险必须在累计获得 1000 星穹时解锁。")
	_check(int(FINANCE_UNLOCK_RULES.get_unlock_threshold(FINANCE_UNLOCK_RULES.FEATURE_BANK)) == 3000, "银行必须在累计获得 3000 星穹时解锁。")
	_check(int(FINANCE_UNLOCK_RULES.get_unlock_threshold(FINANCE_UNLOCK_RULES.FEATURE_MINING_FARM)) == 6000, "矿场必须在累计获得 6000 星穹时解锁。")
	_check(int(FINANCE_UNLOCK_RULES.get_unlock_threshold(FINANCE_UNLOCK_RULES.FEATURE_STOCK_MARKET)) == 10000, "炒股必须在累计获得 10000 星穹时解锁。")
	_check(FINANCE_UNLOCK_RULES.UNLOCK_ORDER == ["insurance", "bank", "mining_farm", "stock_market"], "金融成长顺序必须固定为保险、银行、矿场、炒股。")
	_check(not bool(FINANCE_UNLOCK_RULES.is_feature_unlocked("unknown", 2147483647)), "未知金融功能必须保持安全锁定。")


func _test_inventory_and_main_menu_integration() -> void:
	## 验证只有外部新增收益推进累计值，菜单能够立即刷新且消费后不会重新上锁。
	# 全局库存服务；测试必须在全新隔离用户目录中取得默认 0 星穹档案。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	_check(global_inventory != null, "金融解锁测试必须取得 GlobalInventory。")
	if global_inventory == null:
		return
	_check(int(global_inventory.call("get_total_coins_earned")) == 0, "全新档案累计获得星穹必须为 0。")
	# 账户转移模拟；adjust_coins 只改余额，不得推进永久金融成长。
	global_inventory.call("adjust_coins", 5000)
	_check(int(global_inventory.call("get_total_coins_earned")) == 0, "账户转入与兼容余额调整不得计入累计获得星穹。")
	global_inventory.call("spend_coins", 5000)

	# 主菜单实例；完整构建实际金融按钮和覆盖面板，验证锁定入口无法通过大厅动作旁路打开。
	var main_menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	_check(main_menu != null, "主菜单场景必须可以实例化。")
	if main_menu == null:
		return
	add_child(main_menu)
	await get_tree().process_frame
	# 金融按钮容器；子节点顺序必须与规则表成长顺序完全一致。
	var finance_button_container: VBoxContainer = main_menu.get_node("BottomCategoryExpansionMargin/FinanceCategoryPanel/Margin/Buttons") as VBoxContainer
	# 保险按钮；新档应使用纯黑禁用样式并展示第一档门槛提示。
	var insurance_button: Button = main_menu.get_node("%InsuranceButton") as Button
	# 银行按钮；达到 3000 前保持锁定。
	var bank_button: Button = main_menu.get_node("%BankButton") as Button
	# 矿场按钮；达到 6000 前保持锁定。
	var mining_button: Button = main_menu.get_node("%MiningFarmButton") as Button
	# 炒股按钮；达到 10000 前保持锁定。
	var stock_button: Button = main_menu.get_node("%StockMarketButton") as Button
	_check(_get_child_name_order(finance_button_container) == ["InsuranceButton", "BankButton", "MiningFarmButton", "StockMarketButton"], "金融列表必须按保险、银行、矿场、炒股排列。")
	_check(insurance_button.disabled and insurance_button.tooltip_text == "累计获得1000星穹解锁", "新档保险按钮必须锁定并显示 1000 星穹提示。")
	_check(bank_button.disabled and bank_button.tooltip_text == "累计获得3000星穹解锁", "新档银行按钮必须锁定并显示 3000 星穹提示。")
	_check(mining_button.disabled and mining_button.tooltip_text == "累计获得6000星穹解锁", "新档矿场按钮必须锁定并显示 6000 星穹提示。")
	_check(stock_button.disabled and stock_button.tooltip_text == "累计获得10000星穹解锁", "新档炒股按钮必须锁定并显示 10000 星穹提示。")
	# 保险锁定样式；必须使用完全不透明纯黑背景，而不是普通灰蓝禁用色。
	var insurance_locked_style: StyleBox = insurance_button.get_theme_stylebox("disabled")
	_check(insurance_locked_style is StyleBoxFlat and (insurance_locked_style as StyleBoxFlat).bg_color == Color(0.0, 0.0, 0.0, 1.0), "未解锁金融按钮必须使用纯黑背景。")
	main_menu.call("perform_lobby_action", "bank")
	# 银行遮罩；锁定时大厅实体动作也不得绕过按钮直接打开金融功能。
	var bank_overlay: Control = main_menu.get_node("BankOverlay") as Control
	_check(not bank_overlay.visible, "锁定银行不得通过大厅动作旁路打开。")

	global_inventory.call("grant_coins", 1000)
	_check(not insurance_button.disabled and bank_button.disabled, "累计 1000 时只能解锁保险。")
	global_inventory.call("grant_coins", 2000)
	_check(not bank_button.disabled and mining_button.disabled, "累计 3000 时必须继续解锁银行。")
	global_inventory.call("grant_coins", 3000)
	_check(not mining_button.disabled and stock_button.disabled, "累计 6000 时必须继续解锁矿场。")
	global_inventory.call("grant_coins", 4000)
	_check(not stock_button.disabled, "累计 10000 时必须解锁炒股。")
	_check(insurance_button.tooltip_text.is_empty() and bank_button.tooltip_text.is_empty() and mining_button.tooltip_text.is_empty() and stock_button.tooltip_text.is_empty(), "已解锁金融按钮必须清除门槛提示。")
	global_inventory.call("spend_coins", 10000)
	_check(not insurance_button.disabled and not bank_button.disabled and not mining_button.disabled and not stock_button.disabled, "消费全部当前星穹后所有永久解锁必须保持。")
	global_inventory.call("_save_inventory")
	# 隔离存档文件；显式读取当前 JSON，验证累计值与当前余额使用两个独立字段持久化。
	var save_file: FileAccess = FileAccess.open("user://global_inventory.json", FileAccess.READ)
	_check(save_file != null, "金融解锁累计值必须写入全局库存存档。")
	if save_file != null:
		# 隔离存档数据；当前余额已消费为 0，但累计获得值必须继续保存为 10000。
		var save_data: Variant = JSON.parse_string(save_file.get_as_text())
		save_file.close()
		_check(save_data is Dictionary and int((save_data as Dictionary).get("coins", -1)) == 0, "存档中的当前星穹余额必须与累计获得值独立。")
		_check(save_data is Dictionary and int((save_data as Dictionary).get("total_coins_earned", -1)) == 10000, "存档必须保存 10000 累计获得星穹。")
	# 重载库存实例；非 AutoLoad 实例只读取隔离存档且没有持久化所有权，用于验证当前结构恢复结果。
	var reloaded_inventory: Node = GLOBAL_INVENTORY_SCRIPT.new() as Node
	add_child(reloaded_inventory)
	_check(int(reloaded_inventory.call("get_coins")) == 0, "重载库存必须恢复独立的当前余额。")
	_check(int(reloaded_inventory.call("get_total_coins_earned")) == 10000, "重载库存必须恢复永久累计获得星穹。")
	reloaded_inventory.queue_free()
	# 高于累计值的账户转入余额；保存并重载后仍不得被迁移逻辑误记为外部收益。
	global_inventory.call("adjust_coins", 15000)
	global_inventory.call("_save_inventory")
	# 转入后重载实例；验证现行存档只读取显式累计字段，不重复执行旧档余额兼容。
	var transfer_reloaded_inventory: Node = GLOBAL_INVENTORY_SCRIPT.new() as Node
	add_child(transfer_reloaded_inventory)
	_check(int(transfer_reloaded_inventory.call("get_coins")) == 15000, "账户转入后的余额必须正常持久化。")
	_check(int(transfer_reloaded_inventory.call("get_total_coins_earned")) == 10000, "现行存档重载不得把账户转入余额计入累计获得星穹。")
	transfer_reloaded_inventory.queue_free()
	main_menu.queue_free()


func _get_child_name_order(container: Container) -> Array[String]:
	## 返回容器直接子节点名称顺序；只用于验证金融成长列表的玩家可见排列。
	# 子节点名称顺序；每个名称与主菜单场景中的唯一按钮节点一一对应。
	var result: Array[String] = []
	if container == null:
		return result
	# 当前直接子节点；金融容器只承载四个入口按钮，名称顺序即玩家从上到下看到的顺序。
	for child in container.get_children():
		result.append(str(child.name))
	return result


func _check(condition: bool, failure_message: String) -> void:
	## 记录单条断言失败；保留后续检查以便一次运行输出全部不符合预期的规则与界面状态。
	if condition:
		return
	_failure_count += 1
	push_error(failure_message)
