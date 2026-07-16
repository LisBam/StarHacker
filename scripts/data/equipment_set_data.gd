extends Resource
class_name EquipmentSetData

## 装备套装数据资源集中定义同一套装的显示文本、触发件数、属性加成与特殊效果参数。
## 每件装备只引用本资源，运行时组件按稳定 set_id 聚合，避免套装文本和数值在四件装备中重复维护。

## 套装稳定标识；必须使用唯一英文 ID，默认空字符串表示不参与套装统计，发布后修改会使旧装备无法与新装备组成同套装。
@export var set_id: String = ""
## 套装显示名称；默认“未命名套装”，用于装备详情中的所属套装与效果标题，运行时通常不动态修改。
@export var display_name: String = "未命名套装"
## 两件套触发件数；默认 2，取值至少为 1，修改会影响详情激活颜色与属性生效门槛。
@export_range(1, 64, 1) var two_piece_required_count: int = 2
## 两件套效果原文；默认空字符串，填写后会在装备悬停详情中按当前触发状态显示绿色或灰色。
@export_multiline var two_piece_description: String = ""
## 两件套属性加成；键使用装备统一属性名，值为直接加到有效装备聚合结果的点数或比例，运行时不应动态修改。
@export var two_piece_attribute_bonuses: Dictionary = {}
## 两件套最终属性倍率；键使用角色统一属性名，值为额外比例，0.2 表示对应基础与装备合计值提高 20%，运行时不应动态修改。
@export var two_piece_attribute_multipliers: Dictionary = {}
## 四件套触发件数；默认 4，取值至少为 1，修改会影响详情激活颜色与特殊效果生效门槛。
@export_range(1, 64, 1) var four_piece_required_count: int = 4
## 四件套效果原文；默认空字符串，填写后会在装备悬停详情中按当前触发状态显示绿色或灰色。
@export_multiline var four_piece_description: String = ""
## 四件套属性加成；键和值语义与两件套一致，达到四件门槛后会与两件套加成累计。
@export var four_piece_attribute_bonuses: Dictionary = {}
## 四件套最终属性倍率；键和值语义与两件套倍率一致，达到四件门槛后与低档位比例直接相加。
@export var four_piece_attribute_multipliers: Dictionary = {}
## 主动长按开启宝箱时必定追加的物品数量；默认 0 表示没有该特殊效果，击毁宝箱始终不会读取此值。
@export_range(0, 64, 1) var manual_chest_guaranteed_extra_drop_count: int = 0
## 主动长按开启宝箱时再次追加掉落的概率；使用 0 到 1 小数，默认 0 表示不执行额外随机判定。
@export_range(0.0, 1.0, 0.01) var manual_chest_additional_drop_chance: float = 0.0
## 主动长按开启宝箱随机判定成功后追加的物品数量；默认 0，概率成功但数量为 0 时不会生成物品。
@export_range(0, 64, 1) var manual_chest_additional_drop_count: int = 0
## 四件套附近掉落物检测半径；单位为世界像素，默认 0 表示没有该特殊效果，正值时仅检测半径内可拾取掉落物。
@export_range(0.0, 6000.0, 1.0, "or_greater") var nearby_drop_detection_radius: float = 0.0
## 朝附近掉落物移动时的移速提升比例；默认 0 表示不加速，0.4 表示提高 40%，仅达到四件门槛且移动方向指向目标时生效。
@export_range(0.0, 10.0, 0.01, "or_greater") var nearby_drop_move_speed_bonus_ratio: float = 0.0
## 朝附近掉落物移动时的减伤比例；默认 0 表示不减伤，0.15 表示受到伤害降低 15%，与其他来源按剩余伤害连乘。
@export_range(0.0, 1.0, 0.01) var nearby_drop_damage_reduction_ratio: float = 0.0
## 两件套击杀后的额外闪避率；默认 0 表示没有击杀触发，0.05 表示触发期间额外增加 5 个百分点。
@export_range(0.0, 1.0, 0.01) var recent_kill_dodge_chance_bonus: float = 0.0
## 两件套击杀闪避效果持续时间；单位为秒，默认 0 表示关闭，重复击杀只刷新持续时间而不重复叠加自身。
@export_range(0.0, 60.0, 0.01, "or_greater") var recent_kill_dodge_duration: float = 0.0
## 四件套移速换算的单档属性点；默认 0 表示没有该效果，10 表示每拥有 10 点当前移速获得一档增伤与减伤。
@export_range(0.0, 1000.0, 0.1, "or_greater") var move_speed_effect_points_per_stack: float = 0.0
## 四件套移速换算计入上限；默认 0 表示没有该效果，210 表示超过 210 点的移速不再增加档数。
@export_range(0.0, 10000.0, 1.0, "or_greater") var move_speed_effect_maximum_points: float = 0.0
## 四件套每档造成伤害提升比例；默认 0，0.01 表示每档提高 1%，与武器和技能自身倍率乘算。
@export_range(0.0, 1.0, 0.001) var move_speed_damage_bonus_per_stack: float = 0.0
## 四件套每档受到伤害降低比例；默认 0，0.01 表示每档降低 1%，最终结果限制在 0% 至 100%。
@export_range(0.0, 1.0, 0.001) var move_speed_damage_reduction_per_stack: float = 0.0
## 四件套单场战斗首次致命伤害后的生命恢复比例；默认 0 表示没有复苏效果，0.3 表示阻止该次死亡并把当前生命设置为生命上限的 30%。
## 该参数只由战斗中的套装组件消费一次，运行时不应动态修改；卸下、损坏或重新穿齐套装不会重置同一场战斗内已经消耗的次数。
@export_range(0.0, 1.0, 0.01) var first_lethal_recovery_health_ratio: float = 0.0


func get_tier_definitions() -> Array[Dictionary]:
	## 返回用于 UI 的稳定档位定义；效果文本保持资源原文，不由格式化器重新拼写机制描述。
	return [
		{
			"required_count": maxi(two_piece_required_count, 1),
			"description": two_piece_description,
		},
		{
			"required_count": maxi(four_piece_required_count, 1),
			"description": four_piece_description,
		},
	]


func get_attribute_bonuses(active_piece_count: int) -> Dictionary:
	## 根据当前有效穿戴件数返回累计属性加成；达到高档位时会同时保留低档位效果。
	# 累计属性加成；键为装备聚合支持的统一属性名，值允许为普通点数或百分比小数。
	var accumulated_bonuses: Dictionary = {}
	if active_piece_count >= maxi(two_piece_required_count, 1):
		_merge_attribute_bonuses(accumulated_bonuses, two_piece_attribute_bonuses)
	if active_piece_count >= maxi(four_piece_required_count, 1):
		_merge_attribute_bonuses(accumulated_bonuses, four_piece_attribute_bonuses)
	return accumulated_bonuses


func get_attribute_multipliers(active_piece_count: int) -> Dictionary:
	## 根据当前有效穿戴件数返回累计最终属性比例；倍率与直接点数分离，避免“提高20%防御力”被误解为增加0.2点。
	var accumulated_multipliers: Dictionary = {}
	if active_piece_count >= maxi(two_piece_required_count, 1):
		_merge_attribute_bonuses(accumulated_multipliers, two_piece_attribute_multipliers)
	if active_piece_count >= maxi(four_piece_required_count, 1):
		_merge_attribute_bonuses(accumulated_multipliers, four_piece_attribute_multipliers)
	return accumulated_multipliers


func roll_manual_chest_extra_drop_count(active_piece_count: int, random_source: RandomNumberGenerator) -> int:
	## 结算主动长按宝箱的额外掉落数量；未达到四件门槛或随机源缺失时只返回合法的确定部分。
	if active_piece_count < maxi(four_piece_required_count, 1):
		return 0
	# 必定额外数量；限制为非负值，避免检查器异常数据减少宝箱原始掉落。
	var extra_drop_count: int = maxi(manual_chest_guaranteed_extra_drop_count, 0)
	# 再次追加概率；限制到 0 至 1，确保资源文本与运行时随机边界一致。
	var additional_drop_chance: float = clampf(manual_chest_additional_drop_chance, 0.0, 1.0)
	if random_source != null and additional_drop_chance > 0.0 and random_source.randf() < additional_drop_chance:
		extra_drop_count += maxi(manual_chest_additional_drop_count, 0)
	return extra_drop_count


func get_nearby_drop_effect(active_piece_count: int) -> Dictionary:
	## 返回达到四件门槛后的附近掉落物效果参数；未触发或半径为零时返回空词典，组件无需识别具体套装 ID。
	if active_piece_count < maxi(four_piece_required_count, 1) or nearby_drop_detection_radius <= 0.0:
		return {}
	return {
		"detection_radius": maxf(nearby_drop_detection_radius, 0.0),
		"move_speed_bonus_ratio": maxf(nearby_drop_move_speed_bonus_ratio, 0.0),
		"damage_reduction_ratio": clampf(nearby_drop_damage_reduction_ratio, 0.0, 1.0),
	}


func get_recent_kill_dodge_effect(active_piece_count: int) -> Dictionary:
	## 返回达到两件门槛后的击杀闪避参数；未配置数值或未触发套装时返回空词典。
	if active_piece_count < maxi(two_piece_required_count, 1) or recent_kill_dodge_chance_bonus <= 0.0 or recent_kill_dodge_duration <= 0.0:
		return {}
	return {
		"dodge_chance_bonus": clampf(recent_kill_dodge_chance_bonus, 0.0, 1.0),
		"duration": maxf(recent_kill_dodge_duration, 0.0),
	}


func get_move_speed_combat_effect(active_piece_count: int, move_speed_attribute: float) -> Dictionary:
	## 按当前移速计算四件套完整档数；不足一档的余数不生效，超过配置上限的部分不再计入。
	if active_piece_count < maxi(four_piece_required_count, 1) or move_speed_effect_points_per_stack <= 0.0 or move_speed_effect_maximum_points <= 0.0:
		return {}
	# 计入移速；最低为 0，最高限制到套装配置上限，避免临时高速无限放大攻防效果。
	var counted_move_speed: float = clampf(move_speed_attribute, 0.0, move_speed_effect_maximum_points)
	# 完整档数；使用向下取整对应“每拥有若干点”语义，余数不会提前提供下一档收益。
	var stack_count: int = maxi(floori(counted_move_speed / move_speed_effect_points_per_stack), 0)
	return {
		"stack_count": stack_count,
		"damage_bonus_ratio": float(stack_count) * maxf(move_speed_damage_bonus_per_stack, 0.0),
		"damage_reduction_ratio": clampf(float(stack_count) * maxf(move_speed_damage_reduction_per_stack, 0.0), 0.0, 1.0),
	}


func get_first_lethal_recovery_health_ratio(active_piece_count: int) -> float:
	## 返回四件套首次致命伤害后的生命恢复比例；未达到门槛或未配置效果时固定返回 0。
	if active_piece_count < maxi(four_piece_required_count, 1):
		return 0.0
	return clampf(first_lethal_recovery_health_ratio, 0.0, 1.0)


func _merge_attribute_bonuses(target_bonuses: Dictionary, source_bonuses: Dictionary) -> void:
	## 把一个档位的属性加成累加到结果中；空键与零值安全跳过，避免生成无意义属性项。
	# 属性名原始值；资源字典允许 StringName 等键，统一转换为 String 后聚合。
	for raw_stat_name in source_bonuses.keys():
		# 属性稳定名称；空白键不会进入装备组件，避免对不存在字段执行动态访问。
		var stat_name: String = str(raw_stat_name).strip_edges()
		# 属性加成值；直接使用有效点数或比例，正负值均可支持后续风险型套装设计。
		var bonus_value: float = float(source_bonuses.get(raw_stat_name, 0.0))
		if stat_name.is_empty() or is_zero_approx(bonus_value):
			continue
		target_bonuses[stat_name] = float(target_bonuses.get(stat_name, 0.0)) + bonus_value
