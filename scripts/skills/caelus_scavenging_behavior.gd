extends Node

## 拾荒行为只在成功撤离结算入口被调用，按地图上仍可拾取掉落物的实时总价值发放星穹。
## 失败、训练场离开和物资撤离都不会调用该入口，因此不会误发撤离奖励。

## 当前被动资源；默认 null，由 PassiveSkillComponent 创建后注入，提供星穹换算比例。
var _skill_data: Resource


func configure(_caster: Node2D, _stats_component: Node, skill_data: Resource, _passive_skill_component: Node) -> void:
	## 注入被动资源；拾荒不持续引用玩家或属性组件，避免与结算 UI 建立反向依赖。
	_skill_data = skill_data


func apply_successful_extraction_bonus(global_inventory: Node, game_world: Node) -> int:
	## 发放一次成功撤离星穹并返回实际增加量；服务或世界接口缺失时安全返回 0。
	if _skill_data == null or global_inventory == null or game_world == null or (not global_inventory.has_method("grant_coins") and not global_inventory.has_method("adjust_coins")) or not game_world.has_method("get_world_drop_total_value"):
		return 0
	# 地图剩余掉落物总价值；只统计仍处于 item_drops 组的可拾取物，堆叠节点按实际数量计价。
	var world_drop_total_value: int = maxi(int(game_world.call("get_world_drop_total_value")), 0)
	# 星穹换算比例；最低为 0，扩展包默认 20%，结果按星穹整数语义向下取整。
	var gold_ratio: float = maxf(float(_skill_data.get("world_drop_value_gold_ratio")), 0.0)
	# 实际奖励星穹；小于 1 星穹的零碎价值不会发放，也不会累计到后续对局。
	var bonus_coins: int = floori(float(world_drop_total_value) * gold_ratio)
	if bonus_coins > 0:
		if global_inventory.has_method("grant_coins"):
			global_inventory.call("grant_coins", bonus_coins)
		else:
			global_inventory.call("adjust_coins", bonus_coins)
	return bonus_coins
