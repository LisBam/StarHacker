extends CharacterBody2D
class_name PlayerController

## 玩家聚合脚本只负责把输入、移动、远程攻击、近战攻击等组件串起来。
## 具体能力放在独立组件中实现，后续替换角色、武器或控制方式时可以局部替换节点。

## 战斗爆发特效脚本；默认通过路径预加载，避免依赖 Godot 全局类名缓存解析顺序。
const COMBAT_BURST_EFFECT_SCRIPT: Script = preload("res://scripts/effects/combat_burst_effect.gd")

## 玩家显示名称；默认值为“角色”，会由当前选择角色覆盖，运行时修改会影响后续 UI 展示文本。
@export var player_display_name: String = "角色"
## 输入组件路径；默认指向同场景子节点 InputComponent，必须解析到提供输入查询方法的节点，修改会影响所有玩家操作来源。
@export var input_component_path: NodePath = ^"InputComponent"
## 移动组件路径；默认指向 MovementComponent，必须解析到提供 move 方法的节点，修改会影响角色移动执行方式。
@export var movement_component_path: NodePath = ^"MovementComponent"
## 远程攻击组件路径；默认指向 RangedAttackComponent，必须解析到提供 try_attack 方法的节点，修改会影响鼠标左键射击逻辑。
@export var ranged_attack_component_path: NodePath = ^"RangedAttackComponent"
## 近战攻击组件路径；默认指向 MeleeAttackComponent，必须解析到提供 try_attack 方法的节点，修改会影响鼠标右键近战逻辑。
@export var melee_attack_component_path: NodePath = ^"MeleeAttackComponent"
## 战斗属性组件路径；默认指向 StatsComponent，必须解析到提供能量和生命方法的节点，修改会影响武器消耗与受伤转发。
@export var stats_component_path: NodePath = ^"StatsComponent"
## 装备组件路径；默认指向 EquipmentComponent，必须解析到提供当前武器和切换方法的节点，修改会影响武器选择。
@export var equipment_component_path: NodePath = ^"EquipmentComponent"
## 瞄准旋转轴路径；默认指向 AimPivot，必须解析到 Node2D，修改会影响武器朝向和枪口位置。
@export var aim_pivot_path: NodePath = ^"AimPivot"
## 战斗相机路径；默认指向玩家子节点 Camera2D，必须解析到提供 add_shake 方法的节点，修改会影响屏幕震动反馈。
@export var camera_path: NodePath = ^"Camera2D"
## 疾跑速度倍率；取值建议大于等于 1，默认 1.55 表示按住 Shift 时移动速度提升 55%，运行时修改会影响疾跑手感。
@export_range(1.0, 4.0, 0.05, "or_greater") var sprint_speed_multiplier: float = 1.55
## 疾跑每秒能量消耗；取值建议大于等于 0，默认 24 表示持续疾跑会稳定消耗能量，运行时修改会影响疾跑续航。
@export_range(0.0, 9999.0, 0.1, "or_greater") var sprint_energy_cost_per_second: float = 24.0
## 闪避单次能量消耗；取值建议大于等于 0，默认 18 表示每次 Space 突进需要付出固定能量，运行时修改会影响闪避频率。
@export_range(0.0, 9999.0, 0.1, "or_greater") var dodge_energy_cost: float = 18.0
## 闪避突进距离；取值建议大于 0，默认 140 像素适合当前角色尺寸，运行时修改会影响 Space 突进位移。
@export_range(1.0, 1200.0, 1.0, "or_greater") var dodge_distance: float = 140.0
## 闪避持续时间；取值建议 0.05 到 0.5 秒，默认 0.16 秒，运行时修改会影响突进速度和无敌等后续扩展窗口。
@export_range(0.01, 2.0, 0.01) var dodge_duration: float = 0.16
## 击退速度衰减；取值建议大于 0，默认 1800 像素每秒平方，修改会影响后坐力和受击击退持续时间。
@export_range(1.0, 12000.0, 1.0, "or_greater") var knockback_decay: float = 1800.0
## 射击震动后坐力倍率；取值建议 0 到 0.1，默认 0.035 会让高后坐力武器产生更强屏幕震动。
@export_range(0.0, 1.0, 0.001) var fire_shake_per_recoil: float = 0.035
## 受伤震动伤害倍率；取值建议 0 到 1，默认 0.16 会让高伤害受击产生更强屏幕震动。
@export_range(0.0, 2.0, 0.01) var damage_shake_per_damage: float = 0.16
## 最小受伤震动；取值建议 0 到 8，默认 1.6 保证小伤害也有轻微反馈。
@export_range(0.0, 32.0, 0.1) var minimum_damage_shake: float = 1.6
## 玩家受伤间隔；取值建议 0 到 1，默认 0.2 秒用于合并同一瞬间的多颗子弹命中和击退，运行时修改会影响受击容错。
@export_range(0.0, 5.0, 0.01) var damage_interval: float = 0.2
## 玩家受击特效颜色；默认浅青色，修改会影响玩家被命中时的爆发特效颜色。
@export var hit_effect_color: Color = Color(0.55, 0.90, 1.0, 0.95)
## 玩家死亡特效颜色；默认偏红白色，修改会影响玩家死亡时的爆发特效颜色。
@export var death_effect_color: Color = Color(1.0, 0.35, 0.46, 1.0)

## 最近一次有效瞄准方向；取值为单位向量，默认向右保证鼠标贴近角色时仍有攻击方向，修改会影响无有效鼠标方向时的攻击朝向。
var _last_aim_direction: Vector2 = Vector2.RIGHT
## 当前闪避方向；取值为单位向量或 Vector2.ZERO，默认空向量表示未闪避，修改会影响突进移动方向。
var _dodge_direction: Vector2 = Vector2.ZERO
## 当前闪避剩余时间；取值大于等于 0，默认 0 表示未闪避，修改会影响突进持续帧数。
var _dodge_time_remaining: float = 0.0
## 当前外部击退速度；取值为 Vector2，默认零向量，修改会影响后坐力和受击击退叠加到移动上的强度。
var _knockback_velocity: Vector2 = Vector2.ZERO
## 当前受伤间隔剩余时间；取值大于等于 0，默认 0 表示可以受伤，修改会影响连续受伤过滤。
var _damage_interval_remaining: float = 0.0

## 输入组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以降低脚本类名缓存依赖，修改会影响移动与攻击输入读取。
@onready var _input_component = get_node(input_component_path)
## 移动组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以支持可替换组件，修改会影响 CharacterBody2D 速度更新。
@onready var _movement_component = get_node(movement_component_path)
## 远程攻击组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以避免自定义类解析顺序问题，修改会影响弹体生成。
@onready var _ranged_attack_component = get_node(ranged_attack_component_path)
## 近战攻击组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以避免自定义类解析顺序问题，修改会影响近战命中框开启。
@onready var _melee_attack_component = get_node(melee_attack_component_path)
## 战斗属性组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以支持可替换属性系统，修改会影响能量消耗和生命处理。
@onready var _stats_component = get_node(stats_component_path)
## 装备组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以支持可替换装备系统，修改会影响当前武器读取和切换。
@onready var _equipment_component = get_node(equipment_component_path)
## 瞄准轴节点缓存；默认按 aim_pivot_path 获取 Node2D，运行时跟随鼠标方向旋转，修改会影响武器视觉和枪口朝向。
@onready var _aim_pivot: Node2D = get_node(aim_pivot_path) as Node2D
## 战斗相机节点缓存；默认按 camera_path 获取，允许为空，缺失时只跳过屏幕震动不影响移动和攻击。
@onready var _camera: Node = get_node_or_null(camera_path)


func _physics_process(delta: float) -> void:
	_damage_interval_remaining = maxf(_damage_interval_remaining - delta, 0.0)
	_handle_weapon_switch_input()

	# 当前帧移动方向；取值为归一化 Vector2 或 Vector2.ZERO，无持久默认值，修改会直接影响本帧移动速度方向。
	var movement_direction: Vector2 = _input_component.get_movement_vector()

	# 当前帧瞄准方向；取值为归一化 Vector2 或 Vector2.ZERO，无持久默认值，修改会影响本帧武器旋转和攻击朝向缓存。
	var aim_direction: Vector2 = _input_component.get_aim_direction(global_position)
	if not aim_direction.is_zero_approx():
		_last_aim_direction = aim_direction
		_aim_pivot.rotation = _last_aim_direction.angle()

	_handle_dodge_request(movement_direction)
	if _dodge_time_remaining > 0.0:
		_move_dodge(delta)
	else:
		# 当前帧移动速度倍率；取值大于等于 1，默认由疾跑状态和能量消耗计算，修改会影响普通移动速度。
		var movement_speed_multiplier: float = _get_movement_speed_multiplier(movement_direction, delta)
		_movement_component.move(self, movement_direction, delta, movement_speed_multiplier, _knockback_velocity)
		_decay_knockback(delta)

	if _input_component.is_fire_requested():
		_try_fire_ranged_weapon()

	if _input_component.consume_melee_request():
		_try_use_melee_weapon()


func apply_damage(damage: float, source: Node) -> void:
	if not _can_receive_damage(damage):
		return

	_damage_interval_remaining = maxf(damage_interval, 0.0)
	# 受伤前死亡状态；取值来自属性组件，默认用于避免死亡特效重复生成。
	var was_dead: bool = _is_stats_dead()
	if _stats_component.has_method("take_damage"):
		_stats_component.call("take_damage", damage)

	# 受伤后死亡状态；取值来自属性组件，默认用于决定播放受击或死亡特效。
	var is_dead_after_damage: bool = _is_stats_dead()
	if is_dead_after_damage and not was_dead:
		_spawn_player_death_effect()
	else:
		_spawn_player_hit_effect()

	_shake_screen_for_damage(damage)
	_apply_knockback_from_source(source)


func _handle_weapon_switch_input() -> void:
	# 数字键请求的远程槽；取值为 -1 或有效槽索引，默认由输入组件消费得出，修改会影响直接切换目标。
	var requested_slot: int = _input_component.consume_ranged_slot_request()
	if requested_slot >= 0 and _equipment_component.has_method("equip_ranged_slot"):
		_equipment_component.call("equip_ranged_slot", requested_slot)

	# 滚轮请求的远程切换方向；取值为 -1、0 或 1，默认由输入组件消费得出，修改会影响循环切换方向。
	var cycle_step: int = _input_component.consume_ranged_cycle_request()
	if cycle_step != 0 and _equipment_component.has_method("cycle_ranged_weapon"):
		_equipment_component.call("cycle_ranged_weapon", cycle_step)


func _try_fire_ranged_weapon() -> void:
	if not _equipment_component.has_method("get_current_ranged_weapon"):
		return

	# 当前远程武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响本次左键攻击参数。
	var current_weapon: Resource = _equipment_component.call("get_current_ranged_weapon") as Resource
	if current_weapon == null:
		return

	# 本次远程攻击能量消耗；取值大于等于 0，默认来自武器数据，修改会影响是否允许开火和扣能量数值。
	var energy_cost: float = _get_weapon_energy_cost(current_weapon)
	if _stats_component.has_method("can_spend_energy") and not _stats_component.call("can_spend_energy", energy_cost):
		return

	# 本次远程攻击是否成功生成弹体；取值为 true/false，默认由远程攻击组件返回，修改会影响是否扣除能量。
	var attack_succeeded: bool = _ranged_attack_component.try_attack(_last_aim_direction, current_weapon)
	if not attack_succeeded:
		return

	_apply_weapon_recoil(current_weapon, _last_aim_direction)
	_apply_weapon_front_recoil(current_weapon, _last_aim_direction)
	_shake_screen_for_weapon_use(current_weapon)
	if _stats_component.has_method("spend_energy"):
		_stats_component.call("spend_energy", energy_cost)


func _try_use_melee_weapon() -> void:
	if not _equipment_component.has_method("get_melee_weapon"):
		return

	# 当前近战武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响本次右键攻击参数。
	var current_weapon: Resource = _equipment_component.call("get_melee_weapon") as Resource
	if current_weapon == null:
		return

	# 本次近战攻击能量消耗；取值大于等于 0，默认来自武器数据，修改会影响是否允许挥击和扣能量数值。
	var energy_cost: float = _get_weapon_energy_cost(current_weapon)
	if _stats_component.has_method("can_spend_energy") and not _stats_component.call("can_spend_energy", energy_cost):
		return

	# 本次近战攻击是否成功开启命中框；取值为 true/false，默认由近战组件返回，修改会影响是否扣除能量。
	var attack_succeeded: bool = _melee_attack_component.try_attack(_last_aim_direction, current_weapon)
	if not attack_succeeded:
		return

	_apply_weapon_recoil(current_weapon, _last_aim_direction)
	_apply_weapon_front_recoil(current_weapon, _last_aim_direction)
	_shake_screen_for_weapon_use(current_weapon)
	if _stats_component.has_method("spend_energy"):
		_stats_component.call("spend_energy", energy_cost)


func _handle_dodge_request(movement_direction: Vector2) -> void:
	if not _input_component.has_method("consume_dodge_request"):
		return

	# 本帧是否请求闪避；取值为 true/false，默认由输入组件消费 Space 得出，修改会影响是否尝试突进。
	var dodge_requested: bool = bool(_input_component.call("consume_dodge_request"))
	if not dodge_requested or _dodge_time_remaining > 0.0:
		return

	if movement_direction.is_zero_approx():
		return

	if not _spend_energy(dodge_energy_cost):
		return

	_dodge_direction = movement_direction.normalized()
	_dodge_time_remaining = maxf(dodge_duration, 0.01)


func _move_dodge(delta: float) -> void:
	# 有效闪避时长；取值至少 0.01 秒，默认由 dodge_duration 夹取，修改会影响突进速度计算。
	var effective_dodge_duration: float = maxf(dodge_duration, 0.01)
	# 闪避速度；取值为距离除以时长，默认确保总位移接近 dodge_distance，修改会影响突进帧速度。
	var dodge_speed: float = maxf(dodge_distance, 0.0) / effective_dodge_duration
	velocity = _dodge_direction * dodge_speed + _knockback_velocity
	move_and_slide()
	_decay_knockback(delta)
	_dodge_time_remaining = maxf(_dodge_time_remaining - delta, 0.0)
	if _dodge_time_remaining <= 0.0:
		_dodge_direction = Vector2.ZERO
		velocity = Vector2.ZERO


func _get_movement_speed_multiplier(movement_direction: Vector2, delta: float) -> float:
	if movement_direction.is_zero_approx():
		return 1.0

	if not _input_component.has_method("is_sprint_pressed") or not bool(_input_component.call("is_sprint_pressed")):
		return 1.0

	# 本帧疾跑能量消耗；取值大于等于 0，默认由每秒消耗乘 delta 得出，修改会影响疾跑扣能节奏。
	var sprint_energy_cost: float = maxf(sprint_energy_cost_per_second, 0.0) * delta
	if not _spend_energy(sprint_energy_cost):
		return 1.0

	return maxf(sprint_speed_multiplier, 1.0)


func _spend_energy(amount: float) -> bool:
	if amount <= 0.0:
		return true

	if not _stats_component.has_method("spend_energy"):
		return true

	return bool(_stats_component.call("spend_energy", amount))


func _get_weapon_energy_cost(weapon_data: Resource) -> float:
	if weapon_data == null:
		return 0.0
	if weapon_data.has_method("get_effective_stat"):
		return maxf(float(weapon_data.call("get_effective_stat", "energy_cost")), 0.0)

	return maxf(float(weapon_data.get("energy_cost")), 0.0)


func apply_knockback(direction: Vector2, force: float) -> void:
	if direction.is_zero_approx() or force <= 0.0:
		return

	_knockback_velocity += direction.normalized() * force


func _apply_weapon_recoil(weapon_data: Resource, attack_direction: Vector2) -> void:
	if weapon_data == null or attack_direction.is_zero_approx():
		return

	# 武器后坐力；取值来自武器资源 recoil_force，默认 0 表示不推动玩家。
	var recoil_force: float = _get_weapon_recoil_force(weapon_data)
	if recoil_force <= 0.0:
		return

	apply_knockback(-attack_direction.normalized(), recoil_force)


func _apply_weapon_front_recoil(weapon_data: Resource, attack_direction: Vector2) -> void:
	if weapon_data == null or attack_direction.is_zero_approx():
		return

	# 武器前坐力；取值来自武器资源 front_recoil_force，默认 0 表示不把玩家推向攻击方向。
	var front_recoil_force: float = _get_weapon_front_recoil_force(weapon_data)
	if front_recoil_force <= 0.0:
		return

	apply_knockback(attack_direction.normalized(), front_recoil_force)


func _get_weapon_recoil_force(weapon_data: Resource) -> float:
	if weapon_data == null:
		return 0.0
	if weapon_data.has_method("get_effective_stat"):
		return maxf(float(weapon_data.call("get_effective_stat", "recoil_force")), 0.0)

	return maxf(float(weapon_data.get("recoil_force")), 0.0)


func _get_weapon_front_recoil_force(weapon_data: Resource) -> float:
	if weapon_data == null:
		return 0.0
	if weapon_data.has_method("get_effective_stat"):
		return maxf(float(weapon_data.call("get_effective_stat", "front_recoil_force")), 0.0)

	return maxf(float(weapon_data.get("front_recoil_force")), 0.0)


func _shake_screen_for_weapon_use(weapon_data: Resource) -> void:
	# 武器后坐力；取值来自武器资源 recoil_force，默认用于换算射击屏幕震动强度。
	var recoil_force: float = _get_weapon_recoil_force(weapon_data)
	# 武器前坐力；取值来自武器资源 front_recoil_force，默认按后坐力一半倍率换算震动强度。
	var front_recoil_force: float = _get_weapon_front_recoil_force(weapon_data)
	# 武器使用震动强度；取值由后坐力和前坐力共同换算，默认 0 表示不震动。
	var shake_amount: float = recoil_force * fire_shake_per_recoil + front_recoil_force * fire_shake_per_recoil * 0.5
	if shake_amount <= 0.0:
		return

	_shake_screen(shake_amount)


func _shake_screen_for_damage(damage: float) -> void:
	if damage <= 0.0:
		return

	# 受伤震动强度；取值由伤害和最小震动共同决定，默认让高伤害反馈更强。
	var shake_amount: float = maxf(damage * damage_shake_per_damage, minimum_damage_shake)
	_shake_screen(shake_amount)


func _can_receive_damage(damage: float) -> bool:
	if damage <= 0.0:
		return false

	if _damage_interval_remaining > 0.0:
		return false

	return not _is_stats_dead()


func _shake_screen(amount: float) -> void:
	if _camera == null or not _camera.has_method("add_shake"):
		return

	_camera.call("add_shake", amount)


func _spawn_player_hit_effect() -> void:
	_spawn_combat_burst(_resolve_effect_parent(), global_position, hit_effect_color, 30.0, 0.18, 7)


func _spawn_player_death_effect() -> void:
	_spawn_combat_burst(_resolve_effect_parent(), global_position, death_effect_color, 58.0, 0.42, 18)


func _spawn_combat_burst(parent_node: Node, burst_position: Vector2, burst_color: Color, burst_radius: float, burst_duration: float, burst_particle_count: int) -> void:
	if parent_node == null:
		return

	# 特效实例；取值为预加载脚本创建的 Node2D，默认挂到当前场景独立播放。
	var effect: Node2D = COMBAT_BURST_EFFECT_SCRIPT.new() as Node2D
	if effect == null:
		return

	effect.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_node.add_child(effect)
	effect.global_position = burst_position
	if effect.has_method("configure"):
		effect.call("configure", burst_color, burst_radius, burst_duration, burst_particle_count)


func _resolve_effect_parent() -> Node:
	# 当前场景节点；取值通常为 GameWorld，默认让特效脱离玩家节点生命周期独立播放。
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		return current_scene

	return get_tree().root


func _is_stats_dead() -> bool:
	if _stats_component != null and _stats_component.has_method("is_dead"):
		return bool(_stats_component.call("is_dead"))

	return false


func _apply_knockback_from_source(source: Node) -> void:
	if source == null:
		return

	# 来源冲击力；取值来自 source.get_impact_force()，默认 0 表示不击退玩家。
	var impact_force: float = _get_source_impact_force(source)
	if impact_force <= 0.0:
		return

	# 来源击退方向；取值优先来自 source.get_knockback_direction()，默认由来源位置指向玩家。
	var knockback_direction: Vector2 = _get_source_knockback_direction(source)
	apply_knockback(knockback_direction, impact_force)


func _get_source_impact_force(source: Node) -> float:
	if source.has_method("get_impact_force"):
		return maxf(float(source.call("get_impact_force")), 0.0)

	return 0.0


func _get_source_knockback_direction(source: Node) -> Vector2:
	if source.has_method("get_knockback_direction"):
		# 来源提供的原始方向；取值可能为任意 Variant，默认只接收 Vector2。
		var raw_direction: Variant = source.call("get_knockback_direction")
		if raw_direction is Vector2:
			# 来源提供的击退方向；取值可能为零向量，默认返回前会做兜底判断。
			var provided_direction: Vector2 = raw_direction
			if not provided_direction.is_zero_approx():
				return provided_direction.normalized()

	if source is Node2D:
		# 来源节点位置；取值为 Node2D 全局坐标，默认用于从来源指向玩家的击退方向。
		var source_position: Vector2 = (source as Node2D).global_position
		# 位置推导方向；取值为来源到玩家的单位向量，默认用于普通怪物近战击退。
		var inferred_direction: Vector2 = global_position - source_position
		if not inferred_direction.is_zero_approx():
			return inferred_direction.normalized()

	return _last_aim_direction


func _decay_knockback(delta: float) -> void:
	if _knockback_velocity.is_zero_approx():
		return

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, maxf(knockback_decay, 1.0) * delta)
