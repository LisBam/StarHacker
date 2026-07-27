extends Node

## 银河全垒打行为只负责一次方向扇形伤害、蓄力倍率、目标击退距离换算和释放特效。
## 输入、范围预览、冷却与蓄力时间由 ActiveSkillComponent 统一管理。

## 一次性扇形特效脚本；释放成功后挂到当前场景并脱离玩家技能组件生命周期播放。
const SKILL_SECTOR_EFFECT_SCRIPT: Script = preload("res://scripts/effects/skill_sector_effect.gd")
## 无属性组件时的攻击力兜底；固定 100，与技能统一公式攻击力基准一致，只用于隔离场景兼容。
const FALLBACK_ATTACK_POWER: float = 100.0
## 基础暴击伤害倍率；固定 1.5，与现有武器和怪物统一伤害协议一致，装备暴伤在其上继续相加。
const BASE_CRITICAL_DAMAGE_MULTIPLIER: float = 1.5
## 无目标衰减接口时的击退衰减兜底；固定 1600 像素/秒²，与当前基础怪物默认值一致。
const FALLBACK_KNOCKBACK_DECAY: float = 1600.0
## 目标击退衰减安全下限；固定 1 像素/秒²，避免异常零值使距离换算退化。
const MINIMUM_KNOCKBACK_DECAY: float = 1.0
## 技能扇形最大半角；固定 180 度，与技能资源导出范围一致。
const MAXIMUM_HALF_ANGLE_DEGREES: float = 180.0
## 匀减速距离换算系数；固定 2，来自运动公式 v²=2ad。
const KINEMATIC_DISTANCE_FACTOR: float = 2.0
## 银河全垒打标记元数据键；迷迷命中带有该标记的目标时可减少“我的伙伴”冷却。
const GRAND_SLAM_MARK_META: StringName = &"stelle_grand_slam_marked"
## 银河全垒打标记到期时间元数据键；值为 Time.get_ticks_msec() 同一时钟下的毫秒时间戳。
const GRAND_SLAM_MARK_EXPIRES_META: StringName = &"stelle_grand_slam_mark_expires_msec"

## 当前施法者；默认 null，由主动技能组件创建行为后注入，执行时必须仍是有效 Node2D。
var _caster: Node2D
## 当前战斗属性组件；默认 null，用于读取释放瞬间的最终攻击力、暴击率和暴击伤害。
var _stats_component: Node
## 当前技能资源；默认 null，提供伤害、范围、角度、蓄力、击退和视觉参数。
var _skill_data: Resource
## 所属主动技能组件；默认 null，用于复用统一合法目标枚举，不自行维护目标组规则。
var _active_skill_component: Node
## 当前命中查询使用的公式攻击力；默认 100，技能威力已包含 20% 当前攻击力，因此目标伤害公式不会再次乘算当前攻击力。
var _current_attack_power: float = FALLBACK_ATTACK_POWER
## 当前命中查询使用的暴击率；默认 0，释放时从玩家属性组件读取装备加成。
var _current_critical_chance: float = 0.0
## 当前命中查询使用的暴击伤害倍率；默认 1.5，释放时从玩家属性组件读取。
var _current_critical_damage_multiplier: float = BASE_CRITICAL_DAMAGE_MULTIPLIER
## 当前目标命中使用的击退初速度；默认 0，每个目标调用伤害前按其衰减值和目标距离重新换算。
var _current_impact_force: float = 0.0
## 当前技能击退方向；默认向右，目标在同步伤害回调中通过公开接口读取。
var _current_knockback_direction: Vector2 = Vector2.RIGHT


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, active_skill_component: Node) -> void:
	## 注入行为依赖；所有引用只在当前玩家技能组件生命周期内使用，角色切换会销毁本节点。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_active_skill_component = active_skill_component


func execute(context: Dictionary) -> bool:
	## 对当前方向扇形内全部合法目标结算一次伤害与击退；没有目标时仍视为成功挥击并进入冷却。
	if not is_instance_valid(_caster) or _skill_data == null or _active_skill_component == null:
		return false
	# 原始瞄准方向；只接收 Vector2，零向量回退角色右侧，保证扇形和击退方向一致。
	var raw_direction: Variant = context.get("aim_direction", Vector2.RIGHT)
	# 标准释放方向；默认向右，后续扇形夹角和来源击退接口共同复用。
	var cast_direction: Vector2 = Vector2.RIGHT
	if raw_direction is Vector2:
		# 资源上下文方向；经过类型校验后再归一化，零向量继续使用默认向右。
		var provided_direction: Vector2 = raw_direction
		if not provided_direction.is_zero_approx():
			cast_direction = provided_direction.normalized()
	# 蓄力比例；取值 0 至 1，由主动技能组件按最大 3 秒换算。
	var charge_ratio: float = clampf(float(context.get("charge_ratio", 0.0)), 0.0, 1.0)
	# 当前最终攻击力；包含基础、装备和被动技能倍率，释放瞬间固定到本次全部目标。
	var attack_power: float = float(_stats_component.call("get_attack_power")) if _stats_component != null and _stats_component.has_method("get_attack_power") else FALLBACK_ATTACK_POWER
	# 未蓄力技能威力；固定伤害与当前攻击力比例直接相加，再交给项目统一攻防与暴击公式。
	var uncharged_damage: float = maxf(float(_skill_data.get("base_damage")), 0.0) + attack_power * maxf(float(_skill_data.get("attack_power_ratio")), 0.0)
	# 蓄力增伤比例；0 蓄力为 0，满蓄力按资源 maximum_charge_damage_bonus_ratio 提高，并与其他增伤进入同一乘区。
	var charge_damage_bonus_ratio: float = maxf(float(_skill_data.get("maximum_charge_damage_bonus_ratio")), 0.0) * charge_ratio
	# 本次传给目标的原始技能伤害；所有目标共享同一释放数值，防止命中顺序改变结果。
	# 玩家综合增伤比例；装备套装等来源由玩家公开接口统一聚合，技能行为不识别具体套装 ID。
	var outgoing_damage_bonus_ratio: float = 0.0
	if _caster.has_method("get_outgoing_damage_bonus_ratio"):
		outgoing_damage_bonus_ratio = maxf(float(_caster.call("get_outgoing_damage_bonus_ratio")), 0.0)
	elif _caster.has_method("get_outgoing_damage_multiplier"):
		outgoing_damage_bonus_ratio = maxf(float(_caster.call("get_outgoing_damage_multiplier")) - 1.0, 0.0)
	# 本次技能伤害；蓄力增伤与“造成的伤害提高”比例加算后只形成一个最终倍率。
	var cast_damage: float = uncharged_damage * maxf(1.0 + charge_damage_bonus_ratio + outgoing_damage_bonus_ratio, 0.0)
	# 基础击退距离；取值来自资源，满蓄力再按独立比例提高。
	var base_knockback_distance: float = maxf(float(_skill_data.get("knockback_distance")), 0.0)
	# 本次期望击退距离；0 蓄力为 100，满蓄力默认为 180 像素。
	var knockback_distance: float = base_knockback_distance * (1.0 + maxf(float(_skill_data.get("maximum_charge_knockback_bonus_ratio")), 0.0) * charge_ratio)
	# 基础冲击力；新资源以理论位移点数直接传给目标统一结算，旧击退距离字段仅在资源把冲击力明确设为 0 时作为兼容回退。
	var base_impact_force: float = maxf(float(_skill_data.get("impact_force")), 0.0)
	if base_impact_force <= 0.0:
		base_impact_force = base_knockback_distance
	# 本次实际冲击力；未蓄力为 150，满蓄力按 80% 提升至 270，怪物会再按自身韧性折算理论位移。
	var impact_force: float = base_impact_force * (1.0 + maxf(float(_skill_data.get("maximum_charge_knockback_bonus_ratio")), 0.0) * charge_ratio)
	_current_attack_power = maxf(float(_skill_data.get("damage_formula_attack_power")), 0.0)
	_current_critical_chance = float(_stats_component.call("get_equipment_critical_chance")) if _stats_component != null and _stats_component.has_method("get_equipment_critical_chance") else 0.0
	_current_critical_damage_multiplier = maxf(BASE_CRITICAL_DAMAGE_MULTIPLIER + (float(_stats_component.call("get_equipment_critical_damage")) if _stats_component != null and _stats_component.has_method("get_equipment_critical_damage") else 0.0), 1.0)
	_current_knockback_direction = cast_direction
	# 本次技能前坐力距离；未蓄力为基础值，满蓄力达到资源上限，使用与武器相同的理论位移语义。
	var front_recoil_distance: float = lerpf(maxf(float(_skill_data.get("base_front_recoil_distance")), 0.0), maxf(float(_skill_data.get("maximum_front_recoil_distance")), 0.0), charge_ratio)
	if _caster.has_method("apply_front_recoil_distance"):
		_caster.call("apply_front_recoil_distance", cast_direction, front_recoil_distance)
	# 扇形半角；限制到 0 至 180 度，使用余弦避免逐目标计算反三角函数。
	var half_angle_radians: float = deg_to_rad(clampf(float(_skill_data.get("directional_half_angle_degrees")), 0.0, MAXIMUM_HALF_ANGLE_DEGREES))
	# 扇形边界余弦；目标方向与释放方向点积大于等于该值时位于扇形内。
	var minimum_direction_dot: float = cos(half_angle_radians)
	# 合法目标列表；统一组件已过滤目标组、距离、生命和可选视线规则。
	var legal_targets: Array[Node2D] = _active_skill_component.call("get_legal_targets", _skill_data) as Array[Node2D]
	for target in legal_targets:
		# 目标方向；与施法者重合的目标不具备明确扇形方向，安全跳过。
		var target_offset: Vector2 = target.global_position - _caster.global_position
		if target_offset.is_zero_approx() or cast_direction.dot(target_offset.normalized()) < minimum_direction_dot:
			continue
		if bool(_skill_data.get("blocked_by_environment")) and not _has_clear_path_to(target):
			continue
		_current_impact_force = impact_force
		target.call("apply_damage", cast_damage, self)
		target.set_meta(GRAND_SLAM_MARK_META, true)
		target.set_meta(GRAND_SLAM_MARK_EXPIRES_META, Time.get_ticks_msec() + roundi(maxf(float(_skill_data.get("mark_duration")), 0.01) * 1000.0))
		if _caster.has_method("notify_skill_target_hit"):
			_caster.call("notify_skill_target_hit", str(_skill_data.get("skill_id")), target)
	_spawn_cast_effect(cast_direction)
	return true


func get_attack_power() -> float:
	## 返回本次释放固定攻击力，供目标统一伤害公式同步读取。
	return maxf(_current_attack_power, 0.0)


func get_damage_instigator() -> Node:
	## 返回技能的实际施放者；目标据此查询玩家独立的骇入协议条件增伤与必定暴击规则。
	return _caster


func get_critical_chance() -> float:
	## 返回本次释放固定暴击率，限制到 0 至 100%。
	return clampf(_current_critical_chance, 0.0, 1.0)


func get_critical_damage_multiplier() -> float:
	## 返回本次释放固定暴击伤害倍率，最低为 1 倍。
	return maxf(_current_critical_damage_multiplier, 1.0)


func get_impact_force() -> float:
	## 返回当前目标对应的击退初速度；目标同步处理伤害时读取，下一目标前会重新计算。
	return maxf(_current_impact_force, 0.0)


func get_knockback_direction() -> Vector2:
	## 返回当前技能统一击退方向；银河全垒打把所有命中目标沿挥击方向推出，而不是径向散开。
	return _current_knockback_direction


func _calculate_impact_force_for_distance(target: Node, knockback_distance: float) -> float:
	if knockback_distance <= 0.0:
		return 0.0
	# 目标击退衰减；优先读取公开接口，缺失时使用基础怪物兼容兜底。
	var target_decay: float = float(target.call("get_knockback_decay")) if target.has_method("get_knockback_decay") else FALLBACK_KNOCKBACK_DECAY
	# 线性减速初速度；由 d=v²/(2a) 反推，无遮挡时停止距离近似等于技能配置距离。
	var impact_force: float = sqrt(KINEMATIC_DISTANCE_FACTOR * maxf(target_decay, MINIMUM_KNOCKBACK_DECAY) * knockback_distance)
	return maxf(impact_force, 0.0)


func _has_clear_path_to(target: Node2D) -> bool:
	if not is_instance_valid(_caster) or not is_instance_valid(target):
		return false
	# 施法者排除 RID；玩家本体不应被环境射线立即命中，非碰撞对象使用空排除数组。
	var exclusions: Array[RID] = []
	if _caster is CollisionObject2D:
		exclusions.append((_caster as CollisionObject2D).get_rid())
	# 环境视线查询；只检测技能资源指定环境层，目标本体不在该掩码中。
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(_caster.global_position, target.global_position, int(_skill_data.get("environment_collision_mask")), exclusions)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# 环境命中结果；空字典表示目标可被当前方向挥击触及。
	var hit_result: Dictionary = _caster.get_world_2d().direct_space_state.intersect_ray(query)
	return hit_result.is_empty()


func _spawn_cast_effect(cast_direction: Vector2) -> void:
	# 特效挂载父节点；优先当前场景，使角色切换或技能组件销毁不会中断已经释放的短时视觉。
	var effect_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	# 扇形特效节点；脚本创建失败时只跳过视觉，不影响已经完成的伤害结算。
	var effect: Node2D = SKILL_SECTOR_EFFECT_SCRIPT.new() as Node2D
	if effect == null or effect_parent == null:
		return
	effect_parent.add_child(effect)
	effect.global_position = _caster.global_position
	# 释放特效颜色；资源字段为 Color，异常缺失时回退金色，不影响技能伤害。
	var raw_effect_color: Variant = _skill_data.get("cast_effect_color")
	# 实际释放特效颜色；只接收 Color，其他类型回退星技能默认金色。
	var effect_color: Color = raw_effect_color if raw_effect_color is Color else Color(1.0, 0.82, 0.34, 0.92)
	effect.call(
		"configure",
		float(_skill_data.get("cast_range")),
		float(_skill_data.get("directional_half_angle_degrees")),
		cast_direction,
		effect_color,
		float(_skill_data.get("cast_effect_duration")),
		int(_skill_data.get("cast_effect_segment_count")),
		float(_skill_data.get("cast_effect_fill_opacity_ratio")),
		float(_skill_data.get("cast_effect_outline_width"))
	)
