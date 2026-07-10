extends RefCounted
class_name ForgeService

## 锻造服务集中计算主武器价值倍率、牺牲材料费用、耐久恢复预览和最终强化结果。
## 服务不持有 UI 节点或槽位状态，调用方传入来源条目即可复用于其他锻造界面或自动化测试。

## 主武器价值换算单位；默认每 100 金币价值提高一次倍率增量。
const MAIN_WEAPON_VALUE_STEP: float = 100.0
## 主武器每个价值单位增加的费用倍率；默认每 100 金币增加 0.4。
const MAIN_WEAPON_MULTIPLIER_PER_STEP: float = 0.4
## 锻造基础费用倍率；默认 1.0，低价值武器不会低于该倍率。
const BASE_COST_MULTIPLIER: float = 1.0
## 牺牲武器耐久转化比例；默认取牺牲武器当前耐久的 10% 恢复主武器。
const SACRIFICE_WEAPON_DURABILITY_RATIO: float = 0.10
## 每实际恢复一点耐久的基础金币费用；默认 2 金币，最终还会乘主武器价值倍率。
const COST_PER_RESTORED_DURABILITY: float = 2.0
## 强化石品质基础费用；每颗按品质累加后统一乘主武器价值倍率。
const STONE_QUALITY_COSTS: Dictionary = {
	EnhancementRules.QUALITY_LOW: 2,
	EnhancementRules.QUALITY_MEDIUM: 5,
	EnhancementRules.QUALITY_HIGH: 10,
	EnhancementRules.QUALITY_SUPREME: 20,
}

## 全局库存服务；负责校验来源数量、扣除金币、消费材料和应用随机强化倍率。
var _global_inventory: Node


func _init(global_inventory: Node) -> void:
	_global_inventory = global_inventory


func build_preview(main_entry: Dictionary, sacrifice_entries: Array[Dictionary]) -> Dictionary:
	# 主武器；必须仍是仓库或背包中的武器资源，锻造不会接受强化石或空槽作为主物品。
	var main_weapon: Resource = main_entry.get("resource") as Resource
	if not _is_weapon(main_weapon):
		return _build_invalid_preview("请先放入主锻造武器")
	# 强化前耐久；预览和结果弹窗共同使用，取值限制在 0 到最大耐久。
	var durability_before: float = maxf(float(main_weapon.get("current_durability")), 0.0)
	# 最大耐久；支持未来不同武器拥有不同上限。
	var maximum_durability: float = maxf(float(main_weapon.get("max_durability")), 1.0)
	# 剩余可恢复耐久；牺牲武器依次提供当前耐久的 10%，超过上限的部分不收费也不计入结果。
	var remaining_durability_capacity: float = maxf(maximum_durability - durability_before, 0.0)
	# 实际预计恢复耐久；默认 0，按牺牲槽顺序累加并限制到缺失耐久。
	var durability_restored: float = 0.0
	# 强化石基础费用；按低级 2、中级 5、高级 10、极品 20 累加。
	var stone_base_cost: int = 0
	# 有效强化石数量；只统计至少有一条可用于主武器的强化石。
	var compatible_stone_count: int = 0
	# 有效牺牲材料数量；至少一件能恢复耐久的武器或兼容强化石才允许开始锻造。
	var effective_material_count: int = 0
	# 有效牺牲材料；只记录实际恢复耐久或能应用强化的条目，执行阶段不会误消耗无效果材料。
	var effective_sacrifice_entries: Array[Dictionary] = []
	for sacrifice_entry in sacrifice_entries:
		# 牺牲资源；武器提供耐久，强化石提供随机强化，其他资源不参与锻造。
		var sacrifice_resource: Resource = sacrifice_entry.get("resource") as Resource
		if _is_weapon(sacrifice_resource):
			# 可提供耐久；使用牺牲武器当前耐久的 10%，已损坏武器不会产生恢复或费用。
			var offered_durability: float = maxf(float(sacrifice_resource.get("current_durability")), 0.0) * SACRIFICE_WEAPON_DURABILITY_RATIO
			# 本槽实际恢复量；主武器即将满耐久时只计算剩余缺口。
			var applied_durability: float = minf(offered_durability, remaining_durability_capacity)
			if applied_durability > 0.0:
				durability_restored += applied_durability
				remaining_durability_capacity -= applied_durability
				effective_material_count += 1
				effective_sacrifice_entries.append(sacrifice_entry)
		elif _is_enhancement_stone(sacrifice_resource) and bool(sacrifice_resource.call("can_apply_to_weapon", main_weapon)):
			stone_base_cost += _get_stone_quality_cost(sacrifice_resource)
			compatible_stone_count += 1
			effective_material_count += 1
			effective_sacrifice_entries.append(sacrifice_entry)
	if sacrifice_entries.is_empty():
		return _build_invalid_preview("请至少放入一件牺牲材料")
	if effective_material_count <= 0:
		return _build_invalid_preview("当前材料无法为主武器提供有效锻造效果")
	# 主武器当前价值；强化与耐久共同影响有效售价，价值越高最终锻造倍率越高。
	var main_weapon_value: int = int(main_weapon.call("get_effective_sell_price")) if main_weapon.has_method("get_effective_sell_price") else maxi(int(main_weapon.get("sell_price")), 0)
	# 主武器价值倍率；连续按价值比例计算，例如价值 250 金币时倍率为 1 + 2.5×0.4 = 2.0。
	var cost_multiplier: float = BASE_COST_MULTIPLIER + float(main_weapon_value) / MAIN_WEAPON_VALUE_STEP * MAIN_WEAPON_MULTIPLIER_PER_STEP
	# 耐久基础费用；只对实际能恢复的耐久收费，超过最大耐久的材料部分不产生费用。
	var durability_base_cost: float = durability_restored * COST_PER_RESTORED_DURABILITY
	# 最终费用；耐久与强化石基础费用相加后乘主武器价值倍率并向上取整。
	var total_cost: int = maxi(ceili((durability_base_cost + float(stone_base_cost)) * cost_multiplier), 1)
	return {
		"valid": true,
		"message": "可以锻造",
		"weapon": main_weapon,
		"main_weapon_value": main_weapon_value,
		"cost_multiplier": cost_multiplier,
		"durability_before": durability_before,
		"durability_after": minf(durability_before + durability_restored, maximum_durability),
		"durability_restored": durability_restored,
		"compatible_stone_count": compatible_stone_count,
		"effective_sacrifice_entries": effective_sacrifice_entries,
		"cost": total_cost,
	}


func execute_forge(main_entry: Dictionary, sacrifice_entries: Array[Dictionary]) -> Dictionary:
	# 锻造预览；最终执行复用同一公式，确保按钮下方费用与实际扣款完全一致。
	var preview: Dictionary = build_preview(main_entry, sacrifice_entries)
	if not bool(preview.get("valid", false)):
		return {"success": false, "message": str(preview.get("message", "无法锻造"))}
	if _global_inventory == null:
		return {"success": false, "message": "全局库存服务不可用"}
	# 主武器；执行前再次确认仍存在于原来源，防止动画期间库存状态发生变化。
	var main_weapon: Resource = main_entry.get("resource") as Resource
	# 主武器来源；只接受 warehouse 或 backpack，与锻造下半区可选容器一致。
	var main_location: String = str(main_entry.get("source_location", ""))
	if not bool(_global_inventory.call("has_storage_resource_quantity", main_weapon, main_location, 1)):
		return {"success": false, "message": "主武器已不在原来源中"}
	# 有效牺牲材料；预览已经排除零耐久、超出修复上限和不兼容的条目，执行时只消费这些材料。
	var effective_sacrifice_entries: Array[Dictionary] = preview.get("effective_sacrifice_entries", []) as Array[Dictionary]
	# 材料需求表；同一强化石堆叠可被多个有效牺牲槽引用，必须合并数量后一次性校验。
	var required_materials: Dictionary = _build_required_material_counts(effective_sacrifice_entries)
	for material_key in required_materials.keys():
		# 材料需求；包含资源实例、来源和所需数量，任一不足都在扣款前终止。
		var requirement: Dictionary = required_materials[material_key] as Dictionary
		if not bool(_global_inventory.call("has_storage_resource_quantity", requirement.get("resource") as Resource, str(requirement.get("source_location", "")), int(requirement.get("quantity", 1)))):
			return {"success": false, "message": "牺牲材料数量不足或已被移动"}
	# 锻造费用；扣款前检查余额，失败时不消费任何材料或改变武器状态。
	var forge_cost: int = int(preview.get("cost", 0))
	if int(_global_inventory.call("get_coins")) < forge_cost:
		return {"success": false, "message": "金币不足，无法完成锻造"}
	# 强化前售价；结果弹窗展示全部强化石与耐久修复共同完成后的价格变化。
	var sell_price_before: int = int(main_weapon.call("get_effective_sell_price")) if main_weapon.has_method("get_effective_sell_price") else maxi(int(main_weapon.get("sell_price")), 0)
	_global_inventory.call("adjust_coins", -forge_cost)
	# 强化结果聚合；多颗强化石的提升和削弱明细按实际应用顺序合并。
	var combined_result: Dictionary = {
		"success": false,
		"weapon": main_weapon,
		"beneficial_changes": [],
		"detrimental_changes": [],
		"sell_price_before": sell_price_before,
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
			_global_inventory.call("consume_storage_resource_quantity", sacrifice_resource, source_location, 1)
		elif _is_enhancement_stone(sacrifice_resource) and bool(sacrifice_resource.call("can_apply_to_weapon", main_weapon)):
			# 单颗强化结果；具体倍率只在此时随机，预览阶段不会提前泄露。
			var stone_result: Dictionary = _global_inventory.call("use_enhancement_stone_with_result", sacrifice_resource, source_location, main_weapon) as Dictionary
			if bool(stone_result.get("success", false)):
				(combined_result["beneficial_changes"] as Array).append_array(stone_result.get("beneficial_changes", []) as Array)
				(combined_result["detrimental_changes"] as Array).append_array(stone_result.get("detrimental_changes", []) as Array)
				combined_result["success"] = true
	combined_result["sell_price_after"] = int(main_weapon.call("get_effective_sell_price")) if main_weapon.has_method("get_effective_sell_price") else sell_price_before
	_global_inventory.call("notify_weapon_runtime_state_changed", main_weapon)
	return combined_result


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


func _build_invalid_preview(message: String) -> Dictionary:
	return {
		"valid": false,
		"message": message,
		"cost": 0,
		"durability_before": 0.0,
		"durability_after": 0.0,
		"durability_restored": 0.0,
		"compatible_stone_count": 0,
		"effective_sacrifice_entries": [],
	}


func _is_weapon(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("weapon_type")) in ["ranged", "melee"]


func _is_enhancement_stone(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "enhancement_stone"
