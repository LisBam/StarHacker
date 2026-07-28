extends Node

## 仓库批量出售与灰市误售找回专项测试；验证一次结算、同批次归档、4 至 8 倍定价及单件出售兼容链路。
## 测试会修改 GlobalInventory 与 ShopService 的正式存档，必须在独立用户数据目录运行。

## 基础近战武器模板；深拷贝后作为不可堆叠批量出售样本。
const WEAPON_TEMPLATE: Resource = preload("res://data/weapons/basic/dagger.tres")
## 基础修复包模板；深拷贝后作为三件堆叠批量出售样本。
const REPAIR_KIT_TEMPLATE: Resource = preload("res://data/items/repair_kit_basic.tres")
## 仓库面板脚本；用于验证玩家可见多选入口、选中计数和一键出售调用链。
const WAREHOUSE_PANEL_SCRIPT: Script = preload("res://scripts/ui/warehouse_panel.gd")

## 当前失败数量；默认 0，全部检查完成后统一决定测试进程退出码。
var _failure_count: int = 0


func _ready() -> void:
	## 使用正式 AutoLoad 完成出售与灰市接入测试；服务信号同步派发，因此出售返回后即可读取灰市结果。
	# 全局库存服务；负责建立样本、执行批量出售并核对所有权和星穹。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	# 商店服务；监听库存出售信号并生成灰市恢复商品。
	var shop_service: Node = get_tree().root.get_node_or_null("ShopService")
	_check(global_inventory != null, "批量出售测试必须取得 GlobalInventory。")
	_check(shop_service != null, "误售找回测试必须取得 ShopService。")
	if global_inventory == null or shop_service == null:
		_finish_test()
		return

	global_inventory.call("clear_warehouse_items")
	global_inventory.call("set_coins", 0)
	# 武器样本；独立副本保证测试不会修改项目模板的耐久或强化状态。
	var weapon_resource: Resource = WEAPON_TEMPLATE.duplicate(true) as Resource
	# 修复包样本；以三件数量进入同一仓库记录，用于验证整组结算和灰市数量。
	var repair_kit_resource: Resource = REPAIR_KIT_TEMPLATE.duplicate(true) as Resource
	_check(weapon_resource != null and bool(global_inventory.call("add_storage_resource", weapon_resource, "warehouse", 1)), "测试武器必须成功进入仓库。")
	_check(repair_kit_resource != null and bool(global_inventory.call("add_storage_resource", repair_kit_resource, "warehouse", 3)), "三件修复包必须成功进入仓库同一记录。")
	# 武器出售价值；执行前读取真实动态价值，作为批量结算预期值。
	var weapon_sale_value: int = int(global_inventory.call("get_storage_resource_value", weapon_resource, "warehouse"))
	# 修复包整组价值；必须等于单件价值乘三件数量。
	var repair_kit_sale_value: int = int(global_inventory.call("get_storage_resource_value", repair_kit_resource, "warehouse"))
	# 仓库面板实例；直接构建正式多选按钮与卡片选择状态，不复制一套测试 UI。
	var warehouse_panel: Control = WAREHOUSE_PANEL_SCRIPT.new() as Control
	add_child(warehouse_panel)
	await get_tree().process_frame
	# 多选模式按钮；默认可见且使用“多选出售”明确表达操作范围。
	var batch_toggle_button: Button = warehouse_panel.get("_batch_sale_toggle_button") as Button
	# 一键出售按钮；进入多选模式前隐藏，选中有效物品后显示并启用。
	var batch_sale_button: Button = warehouse_panel.get("_batch_sale_button") as Button
	_check(batch_toggle_button != null and batch_toggle_button.text == "多选出售", "仓库标题行必须提供多选出售入口。")
	_check(batch_sale_button != null and not batch_sale_button.visible, "未进入多选模式时一键出售按钮必须隐藏。")
	warehouse_panel.call("_on_batch_sale_toggle_pressed")
	_check(bool(warehouse_panel.get("_batch_sale_mode_active")), "点击多选出售后必须进入仓库多选模式。")
	warehouse_panel.call("_on_item_action_requested", weapon_resource, "warehouse")
	warehouse_panel.call("_on_item_action_requested", repair_kit_resource, "warehouse")
	_check((warehouse_panel.get("_batch_sale_selection") as Dictionary).size() == 2, "点击两张仓库卡片必须选中两组真实记录。")
	_check(batch_sale_button.visible and not batch_sale_button.disabled and "2 组" in batch_sale_button.text, "选中两组后出售按钮必须显示组数并可用。")
	# 一键出售动作；面板应把两项选择作为一次请求交给库存服务，并在成功后清空选择。
	warehouse_panel.call("_on_batch_sale_pressed")
	_check((warehouse_panel.get("_batch_sale_selection") as Dictionary).is_empty(), "批量出售成功后必须清空旧选择。")
	_check(int(global_inventory.call("get_coins")) == weapon_sale_value + repair_kit_sale_value, "批量出售必须只结算一次正确星穹总额。")
	_check(int(global_inventory.call("get_warehouse_count")) == 0, "成功批量出售后两组物品必须离开仓库。")

	# 灰市平铺条目；同一次批量出售应生成两件可独立购回的商品。
	var gray_entries: Array = shop_service.call("get_gray_market_entries") as Array
	_check(gray_entries.size() == 2, "一次两组批量出售必须生成两件灰市找回商品。")
	# 首个恢复批次编号；同一出售事务内的全部商品必须共享该编号。
	var recovery_group_id: String = str((gray_entries[0] as Dictionary).get("failure_group_id", "")) if gray_entries.size() > 0 else ""
	_check(recovery_group_id.begins_with("sale_"), "玩家出售形成的灰市批次必须使用 sale 来源编号。")
	for raw_entry in gray_entries:
		if not (raw_entry is Dictionary):
			_check(false, "灰市恢复条目必须为结构化字典。")
			continue
		# 当前恢复商品；用于核对批次、倍率、数量和定价边界。
		var gray_entry: Dictionary = raw_entry as Dictionary
		# 当前恢复资源；必须是出售资源的独立副本并保留正式物品类型。
		var gray_resource: Resource = gray_entry.get("resource") as Resource
		# 当前恢复数量；武器为一，修复包为三。
		var gray_quantity: int = maxi(int(gray_entry.get("quantity", 1)), 1)
		# 当前锁定倍率；出售物品必须与战斗遗失物共用 4 至 8 倍范围。
		var price_multiplier: float = float(gray_entry.get("price_multiplier", 0.0))
		# 当前满耐久价格基数；测试武器为满耐久，修复包直接读取固定有效价值。
		var base_value: int = int(gray_resource.call("get_effective_value")) if gray_resource != null and gray_resource.has_method("get_effective_value") else int(gray_resource.get("value")) if gray_resource != null else 0
		_check(str(gray_entry.get("failure_group_id", "")) == recovery_group_id, "同一次批量出售的灰市商品必须共享一个恢复批次。")
		_check(price_multiplier >= 4.0 and price_multiplier <= 8.0, "玩家出售物品的灰市倍率必须位于 4 至 8 倍。")
		_check(int(gray_entry.get("price", 0)) >= roundi(float(base_value * gray_quantity) * 4.0), "灰市出售找回价不得低于四倍价格下限。")
		_check(int(gray_entry.get("price", 0)) <= roundi(float(base_value * gray_quantity) * 8.0), "灰市出售找回价不得高于八倍价格上限。")

	# 单件出售样本；验证旧出售入口同样通过库存信号进入灰市，而非只有新批量入口有效。
	var single_sale_resource: Resource = REPAIR_KIT_TEMPLATE.duplicate(true) as Resource
	_check(single_sale_resource != null and bool(global_inventory.call("add_storage_resource", single_sale_resource, "warehouse", 2)), "单件出售兼容样本必须成功进入仓库。")
	_check(bool(global_inventory.call("sell_storage_resource_quantity", single_sale_resource, "warehouse", 1)), "指定数量出售必须保持成功。")
	gray_entries = shop_service.call("get_gray_market_entries") as Array
	_check(gray_entries.size() == 3, "指定数量出售也必须新增一件灰市找回商品。")
	_check(int(global_inventory.call("get_storage_resource_quantity", single_sale_resource, "warehouse")) == 1, "部分出售后仓库必须保留未出售的一件资源。")
	warehouse_panel.queue_free()
	_finish_test()


func _finish_test() -> void:
	## 输出统一测试结果并退出；失败时保留全部断言消息，方便一次定位多个回归点。
	if _failure_count > 0:
		push_error("仓库出售与灰市找回专项测试失败：%d 项。" % _failure_count)
		get_tree().quit(1)
		return
	print("WAREHOUSE_SALE_RECOVERY_TEST_PASS")
	get_tree().quit(0)


func _check(condition: bool, failure_message: String) -> void:
	## 记录单条断言失败；不中断后续检查，确保批量、灰市与部分出售问题可以在一次运行中同时暴露。
	if condition:
		return
	_failure_count += 1
	push_error(failure_message)
