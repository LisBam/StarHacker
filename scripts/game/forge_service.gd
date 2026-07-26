extends RefCounted
class_name ForgeService

## 锻造服务集中计算主物品价值倍率、牺牲材料费用、耐久恢复预览和最终强化结果。
## 服务不持有 UI 节点或槽位状态，调用方传入来源条目即可复用于其他锻造界面或自动化测试。

## 主武器价值换算单位；默认每 100 星穹价值提高一次倍率增量。
const MAIN_WEAPON_VALUE_STEP: float = 100.0
## 主武器每个价值单位增加的费用倍率；默认每 100 星穹增加 0.4。
const MAIN_WEAPON_MULTIPLIER_PER_STEP: float = 0.4
## 锻造基础费用倍率；默认 1.0，低价值武器不会低于该倍率。
const BASE_COST_MULTIPLIER: float = 1.0
## 牺牲武器耐久转化比例；默认取牺牲武器当前耐久的 10% 恢复主武器。
const SACRIFICE_WEAPON_DURABILITY_RATIO: float = 0.10
## 每实际恢复一点耐久的基础星穹费用；默认 2 星穹，最终还会乘主武器价值倍率。
const COST_PER_RESTORED_DURABILITY: float = 2.0
## 强化石品质基础费用；每颗按品质累加后统一乘主武器价值倍率。
const STONE_QUALITY_COSTS: Dictionary = {
	EnhancementRules.QUALITY_LOW: 10,
	EnhancementRules.QUALITY_MEDIUM: 20,
	EnhancementRules.QUALITY_HIGH: 50,
	EnhancementRules.QUALITY_SUPREME: 100,
	EnhancementRules.QUALITY_SPECIALIZED: 200,
}
## 强化石升阶单槽成功率；默认每颗同品质牺牲石提供 20%，五个槽全部放满时达到 100%。
const STONE_UPGRADE_SUCCESS_RATE_PER_SACRIFICE: float = 0.20
## 武器锻造模式标识；用于让 UI 区分耐久/词条预览与强化石升阶预览。
const FORGE_MODE_WEAPON: String = "weapon"
## 强化石升阶模式标识；主锻造槽为可升阶强化石时启用，不收取星穹。
const FORGE_MODE_STONE_UPGRADE: String = "stone_upgrade"

## 全局库存服务；负责校验来源数量、扣除星穹、消费材料和应用随机强化倍率。
var _global_inventory: Node
## 锻造随机数生成器；默认初始化时随机化，仅用于强化石升阶成功判定，不提前生成结果。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(global_inventory: Node) -> void:
	_global_inventory = global_inventory
	_random.randomize()


func build_preview(main_entry: Dictionary, sacrifice_entries: Array[Dictionary]) -> Dictionary:
	# 主物品；武器或装备进入耐久修复与强化流程，可升阶强化石进入同品质合成流程。
	var main_weapon: Resource = main_entry.get("resource") as Resource
	if _is_enhancement_stone(main_weapon):
		return _build_stone_upgrade_preview(main_entry, sacrifice_entries)
	if not _is_weapon(main_weapon):
		return _build_invalid_preview("请先放入主锻造武器、装备或可升阶强化石")
	# 强化前耐久；预览和结果弹窗共同使用，取值限制在 0 到最大耐久。
	var durability_before: float = maxf(float(main_weapon.get("current_durability")), 0.0)
	# 最大耐久；支持未来不同武器拥有不同上限。
	var maximum_durability: float = _get_maximum_durability(main_weapon)
	# 当前强化次数；武器与装备优先读取各自公开接口，旧扩展资源回退统一 20 次范围。
	var enhancement_count_before: int = int(main_weapon.call("get_enhancement_count")) if main_weapon.has_method("get_enhancement_count") else clampi(int(main_weapon.get("enhancement_count")), 0, EnhancementRules.MAX_TARGET_ENHANCEMENT_COUNT)
	# 强化次数上限；所有武器与四部位装备统一为 20。
	var maximum_enhancement_count: int = EnhancementRules.MAX_TARGET_ENHANCEMENT_COUNT
	# 剩余强化次数；锻造材料中的有效强化石数量不得超过该值。
	var remaining_enhancement_count: int = maxi(maximum_enhancement_count - enhancement_count_before, 0)
	# 剩余可恢复耐久；牺牲武器或装备依次提供当前耐久的 10%，超过上限的部分不收费也不计入结果。
	var remaining_durability_capacity: float = maxf(maximum_durability - durability_before, 0.0)
	# 实际预计恢复耐久；默认 0，按牺牲槽顺序累加并限制到缺失耐久。
	var durability_restored: float = 0.0
	# 强化石基础费用；按低级 2、中级 5、高级 10、极品 20 累加。
	# 特化品质补充：特化强化石按 20 星穹基础费用累加。
	# 现行费用补充：初级、中级、高级、极品、特化实际基础费用依次为 10、20、50、100、200 星穹。
	var stone_base_cost: int = 0
	# 有效强化石数量；只统计至少有一条可用于主武器的强化石。
	var compatible_stone_count: int = 0
	# 有效牺牲材料数量；至少一件能恢复耐久的武器或兼容强化石才允许开始锻造。
	var effective_material_count: int = 0
	# 有效牺牲材料；只记录实际恢复耐久或能应用强化的条目，执行阶段不会误消耗无效果材料。
	var effective_sacrifice_entries: Array[Dictionary] = []
	# 无效牺牲材料；任一非空槽不能产生锻造效果时整次锻造禁用，UI 会将对应槽位标为红色。
	var invalid_sacrifice_entries: Array[Dictionary] = []
	# 是否因武器强化次数不足出现无效材料；用于返回比普通不兼容更明确的限制提示。
	var enhancement_limit_exceeded: bool = false
	for sacrifice_entry in sacrifice_entries:
		# 牺牲资源；武器和装备提供耐久，匹配主物品类型的强化石提供随机强化，其他资源不参与锻造。
		var sacrifice_resource: Resource = sacrifice_entry.get("resource") as Resource
		if _is_weapon(sacrifice_resource):
			# 可提供耐久；使用牺牲武器或装备当前耐久的 10%，已损坏物品不会产生恢复或费用。
			var offered_durability: float = maxf(float(sacrifice_resource.get("current_durability")), 0.0) * SACRIFICE_WEAPON_DURABILITY_RATIO
			# 本槽实际恢复量；主武器即将满耐久时只计算剩余缺口。
			var applied_durability: float = minf(offered_durability, remaining_durability_capacity)
			# 正耐久牺牲品；只要主物品在锻造开始时存在耐久缺口就属于合法材料，超过缺口的部分不恢复也不收费。
			if offered_durability > 0.0 and maximum_durability > durability_before:
				durability_restored += applied_durability
				remaining_durability_capacity -= applied_durability
				effective_material_count += 1
				effective_sacrifice_entries.append(sacrifice_entry)
			else:
				invalid_sacrifice_entries.append(sacrifice_entry)
		elif _is_enhancement_stone(sacrifice_resource) and bool(sacrifice_resource.call("can_apply_to_weapon", main_weapon)):
			if compatible_stone_count >= remaining_enhancement_count:
				enhancement_limit_exceeded = true
				invalid_sacrifice_entries.append(sacrifice_entry)
			else:
				stone_base_cost += _get_stone_quality_cost(sacrifice_resource)
				compatible_stone_count += 1
				effective_material_count += 1
				effective_sacrifice_entries.append(sacrifice_entry)
		else:
			invalid_sacrifice_entries.append(sacrifice_entry)
	if sacrifice_entries.is_empty():
		return _build_invalid_preview("请至少放入一件牺牲材料")
	if not invalid_sacrifice_entries.is_empty():
		if enhancement_limit_exceeded:
			return _build_invalid_preview("武器或装备剩余强化次数不足，请移除超出上限的强化石", invalid_sacrifice_entries)
		return _build_invalid_preview("牺牲槽中存在无法用于当前主物品的材料", invalid_sacrifice_entries)
	if effective_material_count <= 0:
		return _build_invalid_preview("当前材料无法为主物品提供有效锻造效果")
	# 主物品满耐久价值；锻造费用忽略当前耐久折价，只读取基础价值与历史强化石品质固定加值。
	var main_weapon_value: int = _get_full_durability_value(main_weapon)
	# 主武器价值倍率；连续按价值比例计算，例如价值 250 星穹时倍率为 1 + 2.5×0.4 = 2.0。
	var cost_multiplier: float = BASE_COST_MULTIPLIER + float(main_weapon_value) / MAIN_WEAPON_VALUE_STEP * MAIN_WEAPON_MULTIPLIER_PER_STEP
	# 耐久基础费用；只对实际能恢复的耐久收费，超过最大耐久的材料部分不产生费用。
	var durability_base_cost: float = durability_restored * COST_PER_RESTORED_DURABILITY
	# 最终费用；耐久与强化石基础费用相加后乘主武器价值倍率并向上取整。
	# 据点折扣补充：精工车间每级降低 2% 总费用，预览与执行共用本公式因此扣款始终一致。
	var total_cost: int = maxi(ceili((durability_base_cost + float(stone_base_cost)) * cost_multiplier * (1.0 - _get_hideout_forge_discount_ratio())), 1)
	return {
		"valid": true,
		"forge_mode": FORGE_MODE_WEAPON,
		"message": "可以锻造",
		"weapon": main_weapon,
		"main_weapon_value": main_weapon_value,
		"cost_multiplier": cost_multiplier,
		"durability_before": durability_before,
		"durability_after": minf(durability_before + durability_restored, maximum_durability),
		"durability_restored": durability_restored,
		"compatible_stone_count": compatible_stone_count,
		"enhancement_count_before": enhancement_count_before,
		"enhancement_count_after": enhancement_count_before + compatible_stone_count,
		"maximum_enhancement_count": maximum_enhancement_count,
		"remaining_enhancement_count": maxi(remaining_enhancement_count - compatible_stone_count, 0),
		"has_enhancement_limit": true,
		"effective_sacrifice_entries": effective_sacrifice_entries,
		"invalid_sacrifice_entries": [],
		"cost": total_cost,
	}


func _get_hideout_forge_discount_ratio() -> float:
	## 读取据点精工车间当前的锻造费用折扣比例；据点服务缺失时按无折扣处理，锻造仍可独立运行。
	# 主循环场景树；锻造服务继承 RefCounted 而非场景节点，必须经引擎主循环访问 AutoLoad 所在根节点。
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null or scene_tree.root == null:
		return 0.0
	# 据点服务；折扣上限由据点服务自身约束，此处只做非负与不超过 90% 的防御性钳制。
	var hideout_service: Node = scene_tree.root.get_node_or_null("HideoutService")
	if hideout_service != null and hideout_service.has_method("get_forge_discount_ratio"):
		return clampf(float(hideout_service.call("get_forge_discount_ratio")), 0.0, 0.9)
	return 0.0


func execute_forge(main_entry: Dictionary, sacrifice_entries: Array[Dictionary]) -> Dictionary:
	# 锻造预览；最终执行复用同一公式，确保按钮下方费用与实际扣款完全一致。
	var preview: Dictionary = build_preview(main_entry, sacrifice_entries)
	if not bool(preview.get("valid", false)):
		return {"success": false, "message": str(preview.get("message", "无法锻造"))}
	if str(preview.get("forge_mode", FORGE_MODE_WEAPON)) == FORGE_MODE_STONE_UPGRADE:
		return _execute_stone_upgrade(main_entry, sacrifice_entries, preview)
	if _global_inventory == null:
		return {"success": false, "message": "全局库存服务不可用"}
	# 主武器；执行前再次确认仍存在于原来源，防止动画期间库存状态发生变化。
	var main_weapon: Resource = main_entry.get("resource") as Resource
	# 主武器来源；只接受 warehouse 或 backpack，与锻造下半区可选容器一致。
	var main_location: String = str(main_entry.get("source_location", ""))
	if not bool(_global_inventory.call("has_owned_resource_quantity", main_weapon, main_location, 1)):
		return {"success": false, "message": "主武器已不在原来源中"}
	# 有效牺牲材料；预览已经排除零耐久、超出修复上限和不兼容的条目，执行时只消费这些材料。
	var effective_sacrifice_entries: Array[Dictionary] = preview.get("effective_sacrifice_entries", []) as Array[Dictionary]
	# 材料需求表；同一强化石堆叠可被多个有效牺牲槽引用，必须合并数量后一次性校验。
	var required_materials: Dictionary = _build_required_material_counts(effective_sacrifice_entries)
	for material_key in required_materials.keys():
		# 材料需求；包含资源实例、来源和所需数量，任一不足都在扣款前终止。
		var requirement: Dictionary = required_materials[material_key] as Dictionary
		if not bool(_global_inventory.call("has_owned_resource_quantity", requirement.get("resource") as Resource, str(requirement.get("source_location", "")), int(requirement.get("quantity", 1)))):
			return {"success": false, "message": "牺牲材料数量不足或已被移动"}
	# 锻造费用；扣款前检查余额，失败时不消费任何材料或改变武器状态。
	var forge_cost: int = int(preview.get("cost", 0))
	if int(_global_inventory.call("get_coins")) < forge_cost:
		return {"success": false, "message": "星穹不足，无法完成锻造"}
	# 强化前价值；结果弹窗展示全部强化石与耐久修复共同完成后的价值变化。
	var value_before: int = int(main_weapon.call("get_effective_value")) if main_weapon.has_method("get_effective_value") else maxi(int(main_weapon.get("value")), 0)
	_global_inventory.call("adjust_coins", -forge_cost)
	# 强化结果聚合；多颗强化石的提升和削弱明细按实际应用顺序合并。
	var combined_result: Dictionary = {
		"success": false,
		"weapon": main_weapon,
		"beneficial_changes": [],
		"detrimental_changes": [],
		"value_before": value_before,
		"durability_before": float(preview.get("durability_before", 0.0)),
		"durability_after": float(preview.get("durability_after", 0.0)),
		"durability_restored": float(preview.get("durability_restored", 0.0)),
		"forge_cost": forge_cost,
	}
	# 预计耐久恢复；先写入主武器，再消费对应牺牲武器，结果与预览保持一致。
	var durability_restored: float = float(preview.get("durability_restored", 0.0))
	if durability_restored > 0.0:
		main_weapon.call("set_current_durability", float(preview.get("durability_after", 0.0)))
		combined_result["success"] = true
	for sacrifice_entry in effective_sacrifice_entries:
		# 当前牺牲资源；武器直接消费，强化石通过全局强化接口随机倍率并消费一颗。
		var sacrifice_resource: Resource = sacrifice_entry.get("resource") as Resource
		# 当前来源；锻造结束后材料从其原仓库或背包位置扣除。
		var source_location: String = str(sacrifice_entry.get("source_location", ""))
		if _is_weapon(sacrifice_resource):
			_global_inventory.call("consume_owned_resource_quantity", sacrifice_resource, source_location, 1)
		elif _is_enhancement_stone(sacrifice_resource) and bool(sacrifice_resource.call("can_apply_to_weapon", main_weapon)):
			# 单颗强化结果；具体倍率只在此时随机，预览阶段不会提前泄露。
			var stone_result: Dictionary = _global_inventory.call("use_enhancement_stone_with_result", sacrifice_resource, source_location, main_weapon) as Dictionary
			if bool(stone_result.get("success", false)):
				(combined_result["beneficial_changes"] as Array).append_array(stone_result.get("beneficial_changes", []) as Array)
				(combined_result["detrimental_changes"] as Array).append_array(stone_result.get("detrimental_changes", []) as Array)
				combined_result["success"] = true
	# 实际锻造后耐久；耐久值词条可能改变装备上限并限制当前耐久，结果弹窗必须读取最终资源状态。
	# 名称与目标补充：该词条现统一显示为“耐久”，并可改变武器或装备的有效耐久上限。
	combined_result["durability_after"] = maxf(float(main_weapon.get("current_durability")), 0.0)
	combined_result["value_after"] = int(main_weapon.call("get_effective_value")) if main_weapon.has_method("get_effective_value") else value_before
	_global_inventory.call("notify_weapon_runtime_state_changed", main_weapon)
	return combined_result


func can_use_as_main(item_resource: Resource) -> bool:
	# 主锻造槽允许武器、装备或仍有下一品质的强化石；极品强化石不能作为升阶主石，但仍可作为对应物品的强化材料。
	if _is_weapon(item_resource):
		return true
	if not _is_enhancement_stone(item_resource):
		return false
	return EnhancementRules.can_upgrade_quality(_get_stone_quality_id(item_resource))


func can_use_as_sacrifice(main_resource: Resource, candidate_resource: Resource) -> bool:
	if main_resource == null or candidate_resource == null:
		return false
	if _is_enhancement_stone(main_resource):
		# 升阶牺牲石只比较品质，不要求词条组合一致；极品主石没有下一阶，因此始终拒绝材料。
		return EnhancementRules.can_upgrade_quality(_get_stone_quality_id(main_resource)) and _is_enhancement_stone(candidate_resource) and _get_stone_quality_id(candidate_resource) == _get_stone_quality_id(main_resource)
	if not _is_weapon(main_resource):
		return false
	if _is_weapon(candidate_resource):
		# 牺牲武器或装备必须仍有耐久且主物品存在耐久缺口；两类耐久物品允许跨类型互相作为牺牲品。
		var main_maximum_durability: float = _get_maximum_durability(main_resource)
		return float(main_resource.get("current_durability")) < main_maximum_durability and float(candidate_resource.get("current_durability")) > 0.0
	if not _is_enhancement_stone(candidate_resource) or not bool(candidate_resource.call("can_apply_to_weapon", main_resource)):
		return false
	# 武器与装备强化上限；达到 20 次后仍可使用耐久牺牲品修复，但所有强化石候选立即禁用。
	return not main_resource.has_method("can_receive_enhancement") or bool(main_resource.call("can_receive_enhancement", 1))


func _build_stone_upgrade_preview(main_entry: Dictionary, sacrifice_entries: Array[Dictionary]) -> Dictionary:
	# 主强化石；主锻造槽中的资源实例在失败时保留，成功时仅替换其中一颗为下一品质。
	var main_stone: Resource = main_entry.get("resource") as Resource
	# 主石品质；升阶路径只允许初级、中级和高级。
	var main_quality_id: String = _get_stone_quality_id(main_stone)
	# 下一品质；空字符串表示已经达到极品品质。
	var next_quality_id: String = EnhancementRules.get_next_quality_id(main_quality_id)
	if next_quality_id.is_empty():
		return _build_invalid_preview("极品强化石已经达到最高品质")
	if sacrifice_entries.is_empty():
		return _build_invalid_preview("请至少放入一颗同品质牺牲强化石")
	# 无效牺牲材料；不同品质、非强化石或其他资源都会阻止开始升阶。
	var invalid_sacrifice_entries: Array[Dictionary] = []
	for sacrifice_entry in sacrifice_entries:
		# 当前牺牲资源；必须是与主石品质完全相同的强化石。
		var sacrifice_resource: Resource = sacrifice_entry.get("resource") as Resource
		if not can_use_as_sacrifice(main_stone, sacrifice_resource):
			invalid_sacrifice_entries.append(sacrifice_entry)
	if not invalid_sacrifice_entries.is_empty():
		return _build_invalid_preview("牺牲槽只能放入与主石同品质的强化石", invalid_sacrifice_entries)
	# 升阶成功率；每个有效牺牲槽固定提供 20%，五槽上限 100%。
	var success_rate: float = clampf(float(sacrifice_entries.size()) * STONE_UPGRADE_SUCCESS_RATE_PER_SACRIFICE, 0.0, 1.0)
	return {
		"valid": true,
		"forge_mode": FORGE_MODE_STONE_UPGRADE,
		"message": "可以升阶强化石",
		"main_stone": main_stone,
		"main_quality_id": main_quality_id,
		"next_quality_id": next_quality_id,
		"success_rate": success_rate,
		"compatible_stone_count": sacrifice_entries.size(),
		"effective_sacrifice_entries": sacrifice_entries.duplicate(true),
		"invalid_sacrifice_entries": [],
		"cost": 0,
	}


func _execute_stone_upgrade(main_entry: Dictionary, sacrifice_entries: Array[Dictionary], preview: Dictionary) -> Dictionary:
	if _global_inventory == null:
		return {"success": false, "message": "全局库存服务不可用"}
	# 主强化石与来源；失败不消费主石，成功时在同一来源完成一颗替换。
	var main_stone: Resource = main_entry.get("resource") as Resource
	# 主石来源；取值为 backpack 或 warehouse，升阶成功后新品质资源写回该容器。
	var main_location: String = str(main_entry.get("source_location", ""))
	# 全部需求；执行前把主石与牺牲石合并校验，支持同一堆叠同时占据主锻造槽和多个牺牲槽。
	var all_required_entries: Array[Dictionary] = []
	all_required_entries.append(main_entry.duplicate())
	all_required_entries.append_array(sacrifice_entries)
	# 合并需求表；同一堆叠同时占据主锻造槽和牺牲槽时按总数量一次校验。
	var all_required_materials: Dictionary = _build_required_material_counts(all_required_entries)
	for material_key in all_required_materials.keys():
		# 单项需求；包含资源实例、来源位置和主锻造槽加牺牲槽的合计数量。
		var requirement: Dictionary = all_required_materials[material_key] as Dictionary
		if not bool(_global_inventory.call("has_owned_resource_quantity", requirement.get("resource") as Resource, str(requirement.get("source_location", "")), int(requirement.get("quantity", 1)))):
			return {"success": false, "message": "强化石数量不足或已被移动"}
	# 升阶资源；在消费任何材料前先完成复制校验，避免异常资源导致牺牲石已经扣除却无法生成结果。
	var upgraded_stone: Resource = main_stone.call("create_upgraded_copy") as Resource if main_stone != null and main_stone.has_method("create_upgraded_copy") else null
	if upgraded_stone == null:
		return {"success": false, "message": "无法创建升阶后的强化石"}
	# 升阶结果；随机值只在动画结束后的执行阶段生成，预览只显示确定成功率。
	var upgrade_succeeded: bool = _random.randf() < clampf(float(preview.get("success_rate", 0.0)), 0.0, 1.0)
	# 牺牲材料始终全部消耗；预检已经保证逐项扣除不会在中途失败。
	for sacrifice_entry in sacrifice_entries:
		_global_inventory.call("consume_owned_resource_quantity", sacrifice_entry.get("resource") as Resource, str(sacrifice_entry.get("source_location", "")), 1)
	if not upgrade_succeeded:
		return {
			"success": true,
			"forge_mode": FORGE_MODE_STONE_UPGRADE,
			"upgrade_succeeded": false,
			"message": "升阶失败，主强化石已保留",
			"result_main_entry": main_entry.duplicate(),
			"success_rate": float(preview.get("success_rate", 0.0)),
		}
	_global_inventory.call("consume_owned_resource_quantity", main_stone, main_location, 1)
	if not bool(_global_inventory.call("add_storage_resource", upgraded_stone, main_location, 1)):
		return {"success": false, "message": "升阶物品写入原来源失败"}
	return {
		"success": true,
		"forge_mode": FORGE_MODE_STONE_UPGRADE,
		"upgrade_succeeded": true,
		"message": "%s已升级为%s" % [EnhancementRules.get_quality_display_name(str(preview.get("main_quality_id", EnhancementRules.QUALITY_LOW))), EnhancementRules.get_quality_display_name(str(preview.get("next_quality_id", EnhancementRules.QUALITY_MEDIUM)))],
		"upgraded_stone": upgraded_stone,
		"result_main_entry": {"resource": upgraded_stone, "source_location": main_location},
		"success_rate": float(preview.get("success_rate", 0.0)),
	}


func _build_required_material_counts(sacrifice_entries: Array[Dictionary]) -> Dictionary:
	# 合并需求表；键由来源与资源实例编号组成，确保同一堆强化石多槽引用时正确累计数量。
	var required_materials: Dictionary = {}
	for sacrifice_entry in sacrifice_entries:
		# 材料资源；空资源不会生成需求项。
		var item_resource: Resource = sacrifice_entry.get("resource") as Resource
		if item_resource == null:
			continue
		# 材料来源；只用于区分仓库和背包中理论上不同的资源记录。
		var source_location: String = str(sacrifice_entry.get("source_location", ""))
		# 需求键；资源实例编号在当前会话稳定，可精确区分同名同状态物品。
		var material_key: String = "%s:%d" % [source_location, item_resource.get_instance_id()]
		if not required_materials.has(material_key):
			required_materials[material_key] = {"resource": item_resource, "source_location": source_location, "quantity": 0}
		required_materials[material_key]["quantity"] = int((required_materials[material_key] as Dictionary).get("quantity", 0)) + 1
	return required_materials


func _get_stone_quality_cost(stone_resource: Resource) -> int:
	# 品质标识；异常品质按低级强化石费用处理，保证费用表始终有稳定兜底。
	var quality_id: String = str(stone_resource.call("get_resolved_quality_id")) if stone_resource.has_method("get_resolved_quality_id") else str(stone_resource.get("quality_id"))
	return int(STONE_QUALITY_COSTS.get(quality_id, STONE_QUALITY_COSTS[EnhancementRules.QUALITY_LOW]))


func _get_stone_quality_id(stone_resource: Resource) -> String:
	# 统一品质读取；异常资源回退初级品质，使比较、费用和升级路径使用同一解释。
	if stone_resource == null:
		return EnhancementRules.QUALITY_LOW
	if stone_resource.has_method("get_resolved_quality_id"):
		return str(stone_resource.call("get_resolved_quality_id"))
	return str(stone_resource.get("quality_id"))


func _build_invalid_preview(message: String, invalid_sacrifice_entries: Array[Dictionary] = []) -> Dictionary:
	return {
		"valid": false,
		"message": message,
		"cost": 0,
		"durability_before": 0.0,
		"durability_after": 0.0,
		"durability_restored": 0.0,
		"compatible_stone_count": 0,
		"effective_sacrifice_entries": [],
		"invalid_sacrifice_entries": invalid_sacrifice_entries.duplicate(true),
	}


func _is_weapon(item_resource: Resource) -> bool:
	# 可锻造耐久物品；保留历史函数名以避免改动既有调用，实际同时识别武器和四部位装备。
	return item_resource != null and (str(item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"] or str(item_resource.get("item_kind")) == "equipment")


func _is_enhancement_stone(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "enhancement_stone"


func _get_maximum_durability(item_resource: Resource) -> float:
	if item_resource == null:
		return 1.0
	# 有效耐久上限；装备读取强化后的耐久值，旧资源和武器回退导出字段。
	return maxf(float(item_resource.call("get_maximum_durability")), 1.0) if item_resource.has_method("get_maximum_durability") else maxf(float(item_resource.get("max_durability")), 1.0)


func _get_full_durability_value(item_resource: Resource) -> int:
	## 返回锻造费用使用的满耐久价值；正式武器装备读取公开接口，旧扩展资源回退基础 value 字段。
	if item_resource == null:
		return 0
	if item_resource.has_method("get_full_durability_value"):
		return maxi(int(item_resource.call("get_full_durability_value")), 0)
	return maxi(int(item_resource.get("value")), 0)
