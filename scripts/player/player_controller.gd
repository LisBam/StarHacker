extends CharacterBody2D
class_name PlayerController

## 玩家聚合脚本只负责把输入、移动、远程攻击、近战攻击等组件串起来。
## 具体能力放在独立组件中实现，后续替换角色、武器或控制方式时可以局部替换节点。

signal weapon_durability_changed(weapon_data: Resource)
## 玩家成功完成一次武器攻击请求后派发实际来源槽；HUD 据此区分混合武器的执行通道冷却与玩家可见槽位冷却。
signal weapon_attack_succeeded(source_kind: String, source_index: int, weapon_data: Resource)
## 玩家实际受到一次未闪避攻击后派发；技能可据此缩短持续时间，但不得从信号回调重复扣除生命或防具耐久。
signal damage_received(final_damage: float, source: Node)
## 玩家固定移速技能来源变化后派发；角色面板据此即时刷新“技能”移速分项，不参与实际移动结算。
signal movement_speed_attribute_bonus_changed

## 战斗爆发特效脚本；默认通过路径预加载，避免依赖 Godot 全局类名缓存解析顺序。
const COMBAT_BURST_EFFECT_SCRIPT: Script = preload("res://scripts/effects/combat_burst_effect.gd")
## 疾跑自然回能阻止来源 ID；固定值只属于本玩家控制器，停止疾跑时通过同一 ID 恢复属性组件自然回能。
const SPRINT_ENERGY_REGENERATION_BLOCK_SOURCE_ID: String = "player_sprint"

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
## 武器蓄力组件路径；默认指向 WeaponChargeComponent，必须解析到通用蓄力状态组件，缺失时可蓄力武器不会接受攻击输入。
@export var weapon_charge_component_path: NodePath = ^"WeaponChargeComponent"
## 战斗属性组件路径；默认指向 StatsComponent，必须解析到提供能量和生命方法的节点，修改会影响武器消耗与受伤转发。
@export var stats_component_path: NodePath = ^"StatsComponent"
## 装备组件路径；默认指向 EquipmentComponent，必须解析到提供当前武器和切换方法的节点，修改会影响武器选择。
@export var equipment_component_path: NodePath = ^"EquipmentComponent"
## 装备套装组件路径；默认指向 EquipmentSetComponent，用于查询朝掉落物移动等运行时套装效果，缺失时普通装备属性仍正常生效。
@export var equipment_set_component_path: NodePath = ^"EquipmentSetComponent"
## 临时增益组件路径；默认指向 TemporaryBuffComponent，用于读取消耗品提供的移动倍率，缺失时其他战斗属性不受影响。
@export var temporary_buff_component_path: NodePath = ^"TemporaryBuffComponent"
## 主动技能组件路径；默认指向 ActiveSkillComponent，用于在技能瞄准或蓄力期间屏蔽武器输入，避免共享蓄力条互相覆盖。
@export var active_skill_component_path: NodePath = ^"ActiveSkillComponent"
## 闪避视觉反馈组件路径；默认指向 DodgeFeedbackComponent，只在装备或套装概率闪避成功后播放透明与 MISS 飘字。
@export var dodge_feedback_component_path: NodePath = ^"DodgeFeedbackComponent"
## 瞄准旋转轴路径；默认指向 AimPivot，必须解析到 Node2D，修改会影响武器朝向和枪口位置。
@export var aim_pivot_path: NodePath = ^"AimPivot"
## 战斗相机路径；默认指向玩家子节点 Camera2D，必须解析到提供 add_shake 方法的节点，修改会影响屏幕震动反馈。
@export var camera_path: NodePath = ^"Camera2D"
## 疾跑速度倍率；取值建议大于等于 1，默认 1.55 表示按住 Shift 时移动速度提升 55%，运行时修改会影响疾跑手感。
## 当前疾跑速度倍率；默认 1.5 表示按住 Shift 时移动速度提升 50%，运行时修改会同时影响能量支出成功后的实际移动速度。
@export_range(1.0, 4.0, 0.05, "or_greater") var sprint_speed_multiplier: float = 1.5
## 疾跑每秒能耗；取值建议大于等于 0，默认 24 表示持续疾跑会稳定消耗能量，运行时修改会影响疾跑续航。
## 当前疾跑每秒能耗；默认 20 表示每个实际疾跑秒稳定消费 20 点能量，能量不足当前帧不会获得疾跑倍率。
## 当前项目配置补充：默认值为每秒 5 点，检查器可按角色或测试场景覆盖；运行时通常不动态修改，数值越低可持续疾跑时间越长。
@export_range(0.0, 9999.0, 0.1, "or_greater") var sprint_energy_consumption_per_second: float = 5.0
## 冲刺单次能耗；取值建议大于等于 0，默认 18 表示每次 Space 突进需要付出固定能量，运行时修改会影响冲刺频率。
## 当前冲刺单次能耗；默认 20 表示每次成功 Space 突进固定消费 20 点能量，支付失败不会打断已有蓄力。
## 当前项目配置补充：默认值为每次 10 点，检查器可按角色或测试场景覆盖；运行时通常不动态修改，数值越低连续冲刺次数越多。
@export_range(0.0, 9999.0, 0.1, "or_greater") var dodge_energy_consumption: float = 10.0
## 冲刺距离；取值建议大于 0，默认 140 像素适合当前角色尺寸，运行时修改会影响 Space 突进位移。
@export_range(1.0, 1200.0, 1.0, "or_greater") var dodge_distance: float = 140.0
## 冲刺持续时间；取值建议 0.05 到 0.5 秒，默认 0.16 秒；该时间只控制突进位移，不提供无敌效果。
@export_range(0.01, 2.0, 0.01) var dodge_duration: float = 0.16
## 击退速度衰减；取值建议大于 0，默认 1800 像素每秒平方，修改会影响武器坐力的初速度换算以及所有外部速度的持续时间。
@export_range(1.0, 12000.0, 1.0, "or_greater") var knockback_decay: float = 1800.0
## 外部击退最大累计速度；默认 4300 像素每秒，可完整容纳 5000 点冲击力按默认衰减换算出的单次初速度，同时限制连续攻击与受击无限叠加。
@export_range(1.0, 12000.0, 1.0, "or_greater") var max_accumulated_knockback_speed: float = 4300.0
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
## 当前冲刺方向；取值为单位向量或 Vector2.ZERO，默认空向量表示未冲刺，修改会影响突进移动方向。
var _dodge_direction: Vector2 = Vector2.ZERO
## 当前冲刺剩余时间；取值大于等于 0，默认 0 表示未冲刺，修改会影响突进持续帧数。
var _dodge_time_remaining: float = 0.0
## 当前外部击退速度；取值为 Vector2，默认零向量，修改会影响后坐力和受击击退叠加到移动上的强度。
var _knockback_velocity: Vector2 = Vector2.ZERO
## 当前受伤间隔剩余时间；取值大于等于 0，默认 0 表示可以受伤，修改会影响连续受伤过滤。
var _damage_interval_remaining: float = 0.0
## 是否由战斗开发者工具禁用耐久消耗；默认 false，开启后正式战斗成功攻击也不会扣除武器耐久。
var _durability_consumption_disabled_by_debug: bool = false
## 外部移动倍率来源；键为稳定效果 ID、值为非负倍率，默认空字典，主动技能蓄力等临时效果分别写入并连乘。
var _movement_speed_multiplier_sources: Dictionary = {}
## 临时移动速度属性点来源；键为稳定来源 ID、值为可正向叠加的属性点，银狼技能等效果结束时按来源精确移除。
var _movement_speed_attribute_bonus_sources: Dictionary = {}
## 临时武器攻速提升来源；键为稳定来源 ID、值为 0 到更高的提升比例，只影响手持武器有效冷却。
var _attack_speed_bonus_sources: Dictionary = {}
## 外部减伤来源；键为稳定效果 ID、值为 0 至 1 的减伤比例，默认空字典，所有来源在同一免伤乘区内加算。
var _damage_reduction_sources: Dictionary = {}
## 外部增伤来源；键为稳定效果 ID、值为大于等于 0 的增伤比例，默认空字典，所有来源与蓄力增伤在同一乘区内加算。
var _outgoing_damage_bonus_sources: Dictionary = {}
## 强制移动方向；默认向右，主动冲锋开始时覆盖为单位向量，持续期间玩家输入不改变该方向。
var _forced_movement_direction: Vector2 = Vector2.RIGHT
## 强制移动剩余时间；取值大于等于 0 秒，默认 0 表示玩家可正常操控，归零后立即恢复输入移动。
var _forced_movement_remaining: float = 0.0
## 强制移动速度；单位为像素/秒，默认 0，主动冲锋按角色移速属性与技能额外移速换算后写入。
var _forced_movement_speed: float = 0.0
## 本物理帧强制移动是否被环境墙体阻挡；默认 false，仅在强制移动 move_and_slide 后按碰撞法线更新。
var _forced_movement_blocked_this_frame: bool = false
## 当前是否已经成功支付疾跑能耗；默认 false，状态变化时同步暂停或恢复自然能量回复，确保疾跑净耗能符合配置值。
var _is_sprinting: bool = false

## 输入组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以降低脚本类名缓存依赖，修改会影响移动与攻击输入读取。
@onready var _input_component = get_node(input_component_path)
## 移动组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以支持可替换组件，修改会影响 CharacterBody2D 速度更新。
@onready var _movement_component = get_node(movement_component_path)
## 远程攻击组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以避免自定义类解析顺序问题，修改会影响弹体生成。
@onready var _ranged_attack_component = get_node(ranged_attack_component_path)
## 近战攻击组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以避免自定义类解析顺序问题，修改会影响近战命中框开启。
@onready var _melee_attack_component = get_node(melee_attack_component_path)
## 武器蓄力组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以支持独立替换蓄力表现与状态管理。
@onready var _weapon_charge_component: Node = get_node_or_null(weapon_charge_component_path)
## 战斗属性组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以支持可替换属性系统，修改会影响能量消耗和生命处理。
@onready var _stats_component = get_node(stats_component_path)
## 装备组件实例缓存；默认在 ready 阶段按路径获取，保持动态类型以支持可替换装备系统，修改会影响当前武器读取和切换。
@onready var _equipment_component = get_node(equipment_component_path)
## 装备套装组件实例缓存；默认按路径解析，允许为空，缺失时只跳过套装特殊移动和减伤效果。
@onready var _equipment_set_component: Node = get_node_or_null(equipment_set_component_path)
## 临时增益组件实例缓存；默认按路径解析，允许为空，缺失时只跳过移速饮料效果。
@onready var _temporary_buff_component: Node = get_node_or_null(temporary_buff_component_path)
## 主动技能组件实例缓存；默认按路径解析，允许为空，缺失时武器输入保持独立场景兼容行为。
@onready var _active_skill_component: Node = get_node_or_null(active_skill_component_path)
## 闪避反馈组件实例缓存；默认按路径解析，允许为空，缺失时闪避判定仍正常但不播放视觉反馈。
@onready var _dodge_feedback_component: Node = get_node_or_null(dodge_feedback_component_path)
## 瞄准轴节点缓存；默认按 aim_pivot_path 获取 Node2D，运行时跟随鼠标方向旋转，修改会影响武器视觉和枪口朝向。
@onready var _aim_pivot: Node2D = get_node(aim_pivot_path) as Node2D
## 战斗相机节点缓存；默认按 camera_path 获取，允许为空，缺失时只跳过屏幕震动不影响移动和攻击。
@onready var _camera: Node = get_node_or_null(camera_path)


func _physics_process(delta: float) -> void:
	_damage_interval_remaining = maxf(_damage_interval_remaining - delta, 0.0)
	_forced_movement_blocked_this_frame = false
	_handle_weapon_switch_input()

	# 当前帧移动方向；取值为归一化 Vector2 或 Vector2.ZERO，无持久默认值，修改会直接影响本帧移动速度方向。
	var movement_direction: Vector2 = _input_component.get_movement_vector()

	# 当前帧瞄准方向；取值为归一化 Vector2 或 Vector2.ZERO，无持久默认值，修改会影响本帧武器旋转和攻击朝向缓存。
	var aim_direction: Vector2 = _input_component.get_aim_direction(global_position)
	if not aim_direction.is_zero_approx():
		_last_aim_direction = aim_direction
		_aim_pivot.rotation = _last_aim_direction.angle()
	_handle_dodge_request(movement_direction)
	_update_weapon_attack_input(delta)
	if _forced_movement_remaining > 0.0:
		_set_sprinting_state(false)
		_move_forced_movement(delta)
	elif _dodge_time_remaining > 0.0:
		_set_sprinting_state(false)
		_move_dodge(delta)
	else:
		# 当前帧移动速度倍率；取值大于等于 1，默认由疾跑状态和能耗计算，修改会影响普通移动速度。
		var movement_speed_multiplier: float = _get_movement_speed_multiplier(movement_direction, delta)
		_movement_component.move(self, movement_direction, delta, movement_speed_multiplier, _knockback_velocity)
		_cancel_blocked_knockback_components()
		_decay_knockback(delta)

func apply_damage(damage: float, source: Node) -> void:
	if not _can_receive_damage(damage):
		return
	# 装备闪避；每次有效受击请求独立判定，成功时不扣血、不触发受击间隔和击退。
	var dodge_chance: float = float(_stats_component.call("get_dodge_chance")) if _stats_component != null and _stats_component.has_method("get_dodge_chance") else 0.0
	if _equipment_set_component != null and _equipment_set_component.has_method("get_recent_kill_dodge_chance_bonus"):
		dodge_chance += maxf(float(_equipment_set_component.call("get_recent_kill_dodge_chance_bonus")), 0.0)
	if dodge_chance > 0.0 and randf() < clampf(dodge_chance, 0.0, EnhancementRules.DODGE_CHANCE_MAXIMUM):
		_play_dodge_feedback()
		return

	# 统一伤害计算器；敌方攻击力与玩家防御力在此完成结算。
	var calculator_script: Script = preload("res://scripts/components/combat_damage_calculator.gd")
	# 来源攻击力；旧来源缺少接口时按 100 处理，使既有伤害保持不变。
	var source_attack_power: float = float(source.call("get_attack_power")) if source != null and source.has_method("get_attack_power") else 100.0
	# 玩家防御力；属性组件缺失接口时按 0 处理。
	var player_defense_power: float = float(_stats_component.call("get_defense_power")) if _stats_component != null and _stats_component.has_method("get_defense_power") else 0.0
	# 最终伤害结果；敌方默认不暴击，接口为特殊敌人保留扩展能力。
	var damage_result: Dictionary = calculator_script.calculate_damage(damage, source_attack_power, player_defense_power, float(source.call("get_critical_chance")) if source != null and source.has_method("get_critical_chance") else 0.0, float(source.call("get_critical_damage_multiplier")) if source != null and source.has_method("get_critical_damage_multiplier") else 1.5)
	# 最终伤害；生命扣除、镜头震动和受击反馈使用同一整数结果。
	# 减伤前最终伤害；已经完成攻防与暴击结算，所有临时减伤只对该结果应用一次。
	var damage_before_reduction: float = float(damage_result.get("damage", 0))
		# 最终伤害；武器蓄力、套装与技能来源先在免伤乘区加算，四舍五入到项目统一整数伤害。
	var final_damage: float = float(maxi(roundi(damage_before_reduction * _get_received_damage_multiplier()), 1)) if damage_before_reduction > 0.0 else 0.0
	_record_stock_metric("damage_taken", final_damage)
	_damage_interval_remaining = maxf(damage_interval, 0.0)
	# 受伤前死亡状态；取值来自属性组件，默认用于避免死亡特效重复生成。
	var was_dead: bool = _is_stats_dead()
	# 致命伤害拦截；只有正在等待的技能后续段可以同步处理，成功后本次扣血由回溯效果替代且不会发出死亡信号。
	var current_health_before_damage: float = float(_stats_component.get("current_health")) if _stats_component != null else 0.0
	# 是否完成致命伤害回溯；只有伤害达到当前生命且技能组件明确成功执行后续段时为 true。
	var lethal_damage_intercepted: bool = final_damage >= current_health_before_damage and _active_skill_component != null and _active_skill_component.has_method("try_intercept_lethal_damage") and bool(_active_skill_component.call("try_intercept_lethal_damage", final_damage, source))
	if not lethal_damage_intercepted and _stats_component.has_method("take_damage"):
		_stats_component.call("take_damage", final_damage)
	if _equipment_component != null and _equipment_component.has_method("consume_armor_durability_on_hit"):
		_equipment_component.call("consume_armor_durability_on_hit")
	damage_received.emit(final_damage, source)

	# 受伤后死亡状态；取值来自属性组件，默认用于决定播放受击或死亡特效。
	var is_dead_after_damage: bool = _is_stats_dead()
	if is_dead_after_damage and not was_dead:
		_spawn_player_death_effect()
	else:
		_spawn_player_hit_effect()

	_shake_screen_for_damage(final_damage)
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
	if current_weapon == null or not _can_use_weapon(current_weapon):
		return

	_execute_weapon_attack(current_weapon, "ranged", 0.0)


func _try_use_melee_weapon() -> void:
	if not _equipment_component.has_method("get_melee_weapon"):
		return

	# 当前近战武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响本次右键攻击参数。
	var current_weapon: Resource = _equipment_component.call("get_melee_weapon") as Resource
	if current_weapon == null or not _can_use_weapon(current_weapon):
		return

	_execute_weapon_attack(current_weapon, "melee", 0.0)


func _update_weapon_attack_input(delta: float) -> void:
	## 统一处理普通攻击与可蓄力武器；同一帧只允许一个武器蓄力来源，避免左右键同时持有时共享进度条和成本状态冲突。
	if _active_skill_component != null and _active_skill_component.has_method("is_aiming") and bool(_active_skill_component.call("is_aiming")):
		if _weapon_charge_component != null:
			_weapon_charge_component.call("cancel_charge")
		return
	if _forced_movement_remaining > 0.0:
		if _weapon_charge_component != null:
			_weapon_charge_component.call("cancel_charge")
		return
	if _dodge_time_remaining > 0.0:
		if _weapon_charge_component != null:
			_weapon_charge_component.call("cancel_charge")
		return
	if _weapon_charge_component == null:
		if _input_component.is_fire_requested():
			_try_fire_ranged_weapon()
		if _input_component.consume_melee_request():
			_try_use_melee_weapon()
		return
	# 战斗输入是否启用；背包、地图、暂停或结算打开时取消蓄力且不把输入关闭误判为松手释放。
	var combat_input_enabled: bool = bool(_input_component.call("is_combat_input_enabled")) if _input_component.has_method("is_combat_input_enabled") else true
	if not combat_input_enabled or _is_stats_dead():
		_weapon_charge_component.call("cancel_charge")
		return
	# 近战单次按下请求；每帧只消费一次，普通武器立即攻击，可蓄力武器进入按住状态。
	var melee_requested: bool = bool(_input_component.call("consume_melee_request"))
	if bool(_weapon_charge_component.call("is_charging")):
		# 蓄力攻击通道；决定当前应继续读取左键还是右键保持状态。
		var charging_mode: String = str(_weapon_charge_component.call("get_attack_mode"))
		# 对应攻击键是否仍按住；松开时释放当前快照，武器切换不会改变已开始蓄力的来源。
		var attack_held: bool = bool(_input_component.call("is_fire_requested")) if charging_mode == "ranged" else bool(_input_component.call("is_melee_pressed"))
		if attack_held:
			_weapon_charge_component.call("update_charge", delta)
			return
		# 释放上下文；组件先清理减速与减伤，再由控制器执行一次成本结算。
		var release_context: Dictionary = _weapon_charge_component.call("release_charge") as Dictionary
		var released_weapon: Resource = release_context.get("weapon") as Resource
		_execute_weapon_attack(released_weapon, str(release_context.get("attack_mode", charging_mode)), float(release_context.get("charge_ratio", 0.0)))
		return
	# 当前远程武器；只在左键按住时读取，可蓄力武器开始蓄力，普通武器沿用冷却控制的连续射击。
	var ranged_weapon: Resource = _equipment_component.call("get_current_ranged_weapon") as Resource if _equipment_component.has_method("get_current_ranged_weapon") else null
	if _input_component.is_fire_requested() and ranged_weapon != null and bool(ranged_weapon.get("has_charge_effect")):
		_weapon_charge_component.call("begin_charge", ranged_weapon, "ranged")
		return
	if _input_component.is_fire_requested():
		_try_fire_ranged_weapon()
	# 当前近战武器；普通近战保持单次请求语义，可蓄力近战从第一次按下开始累计。
	var melee_weapon: Resource = _equipment_component.call("get_melee_weapon") as Resource if _equipment_component.has_method("get_melee_weapon") else null
	if melee_requested and melee_weapon != null and bool(melee_weapon.get("has_charge_effect")):
		_weapon_charge_component.call("begin_charge", melee_weapon, "melee")
	elif melee_requested:
		_try_use_melee_weapon()


func _execute_weapon_attack(weapon_data: Resource, requested_mode: String, charge_ratio: float) -> bool:
	## 执行一次武器使用并统一结算能量、耐久、冷却反馈和坐力；混合武器同时调用两个攻击组件但成本只结算一次。
	if weapon_data == null or not _can_use_weapon(weapon_data):
		return false
	# 本次武器能耗；远程与近战通道共享该成本，混合攻击不得因生成两个命中而重复扣除。
	var energy_consumption: float = _get_weapon_energy_consumption(weapon_data)
	if _stats_component.has_method("can_spend_energy") and not bool(_stats_component.call("can_spend_energy", energy_consumption)):
		return false
	# 安全蓄力比例；普通武器固定传入 0，可蓄力武器取 0 至 1 线性插值三个效果倍率。
	var resolved_charge_ratio: float = clampf(charge_ratio, 0.0, 1.0)
	# 蓄力增伤比例；满蓄提升来自武器数据，与玩家其他“造成的伤害提高”来源进入同一增伤乘区。
	var charge_damage_bonus_ratio: float = maxf(float(weapon_data.get("maximum_charge_damage_bonus_ratio")), 0.0) * resolved_charge_ratio
	# 伤害倍率；同乘区比例直接加算，两个 10% 增伤得到 1.20 而不是 1.21。
	var damage_multiplier: float = 1.0 + charge_damage_bonus_ratio + get_outgoing_damage_bonus_ratio()
	# 冲击倍率；只影响目标位移语义，不改变攻击距离或攻击成本。
	var impact_multiplier: float = 1.0 + maxf(float(weapon_data.get("maximum_charge_impact_bonus_ratio")), 0.0) * resolved_charge_ratio
	# 坐力倍率；用于攻击成功后的单次前坐力或后坐力反馈，混合武器不会按通道重复施加。
	var recoil_multiplier: float = 1.0 + maxf(float(weapon_data.get("maximum_charge_recoil_bonus_ratio")), 0.0) * resolved_charge_ratio
	# 攻击参数；两个攻击组件只读取自身相关倍率，冷却仍从同一武器数据读取。
	# 玩家攻速倍率；提高 99% 时为 1.99，武器有效冷却除以该倍率，技能专属效果可在强化 0.01 秒下限之后继续突破该值。
	var attack_speed_multiplier: float = get_attack_speed_multiplier()
	# 攻击参数；攻速只转换为冷却倍率，不改变弹体速度、近战判定时长或武器资源基础数值。
	var attack_modifiers: Dictionary = {"damage_multiplier": damage_multiplier, "impact_multiplier": impact_multiplier, "cooldown_multiplier": 1.0 / maxf(attack_speed_multiplier, 0.01)}
	# 是否为混合武器；兼容资源缺少方法时按 weapon_type 字段判断。
	var is_hybrid_weapon: bool = bool(weapon_data.call("is_hybrid")) if weapon_data.has_method("is_hybrid") else str(weapon_data.get("weapon_type")) == "hybrid"
	# 远程通道是否成功；混合武器始终尝试，普通武器只按请求通道执行。
	var ranged_succeeded: bool = false
	# 近战通道是否成功；与远程结果共同决定是否支付本次使用成本。
	var melee_succeeded: bool = false
	if requested_mode == "ranged" or is_hybrid_weapon:
		ranged_succeeded = bool(_ranged_attack_component.call("try_attack", _last_aim_direction, weapon_data, attack_modifiers))
	if requested_mode == "melee" or is_hybrid_weapon:
		melee_succeeded = bool(_melee_attack_component.call("try_attack", _last_aim_direction, weapon_data, attack_modifiers))
	if not ranged_succeeded and not melee_succeeded:
		return false
	# 攻击来源槽索引；远程请求记录当前手持远程槽，近战请求固定为 -1，混合武器不会因同时执行两个通道改变来源归属。
	var source_slot_index: int = int(_equipment_component.call("get_current_ranged_slot")) if requested_mode == "ranged" and _equipment_component != null and _equipment_component.has_method("get_current_ranged_slot") else -1
	weapon_attack_succeeded.emit(requested_mode, source_slot_index, weapon_data)
	if ranged_succeeded:
		_record_stock_metric("shots", 1.0)
	_apply_weapon_recoil(weapon_data, _last_aim_direction, recoil_multiplier)
	_apply_weapon_front_recoil(weapon_data, _last_aim_direction, recoil_multiplier)
	_shake_screen_for_weapon_use(weapon_data, recoil_multiplier)
	if _stats_component.has_method("spend_energy"):
		_stats_component.call("spend_energy", energy_consumption)
	# 本次耐久成本；混合武器固定 2 点，当前仅剩 1 点时资源接口会消耗剩余 1 点并允许这次攻击完成。
	var durability_cost: float = 2.0 if is_hybrid_weapon else 1.0
	_consume_weapon_durability(weapon_data, durability_cost)
	return true


func _can_use_weapon(weapon_data: Resource) -> bool:
	if weapon_data == null:
		return false
	return bool(weapon_data.call("can_be_used")) if weapon_data.has_method("can_be_used") else true


func set_weapon_durability_consumption_disabled(enabled: bool) -> void:
	_durability_consumption_disabled_by_debug = enabled


func is_weapon_durability_consumption_disabled_by_debug() -> bool:
	return _durability_consumption_disabled_by_debug


func _consume_weapon_durability(weapon_data: Resource, durability_cost: float = 1.0) -> void:
	if _should_skip_weapon_durability_consumption() or weapon_data == null or not weapon_data.has_method("consume_durability"):
		return
	# 是否实际消耗耐久；耐久消耗为 0 或武器已损坏时不触发持久化和 UI 刷新。
	# 固定消耗补充：现行武器成功使用统一扣除 1 点，此返回值只用于识别损坏武器等未发生变化的情况。
	# 消耗前耐久；用于股市指标记录真实变化，混合武器剩余 1 点时只能记录 1 点而不是固定 2 点。
	var durability_before: float = maxf(float(weapon_data.get("current_durability")), 0.0)
	var durability_changed: bool = bool(weapon_data.call("consume_durability", durability_cost))
	if not durability_changed:
		return
	# 实际耐久变化；资源会限制在零以上，因此该值始终非负且不超过请求成本。
	var durability_consumed: float = maxf(durability_before - float(weapon_data.get("current_durability")), 0.0)
	_record_stock_metric("weapon_durability", durability_consumed)
	if _equipment_component.has_method("notify_weapon_runtime_state_changed"):
		_equipment_component.call("notify_weapon_runtime_state_changed", weapon_data)
	weapon_durability_changed.emit(weapon_data)


func _should_skip_weapon_durability_consumption() -> bool:
	if _durability_consumption_disabled_by_debug:
		return true
	# 会话状态；训练场固定不消耗武器耐久，缺少 AutoLoad 时按正式战斗处理以保持独立场景测试可预测。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	return session_state != null and session_state.has_method("is_training_mode") and bool(session_state.call("is_training_mode"))


func _handle_dodge_request(movement_direction: Vector2) -> void:
	if not _input_component.has_method("consume_dodge_request"):
		return

	# 本帧是否请求冲刺；取值为 true/false，默认由输入组件消费 Space 得出，修改会影响是否尝试突进。
	var dodge_requested: bool = bool(_input_component.call("consume_dodge_request"))
	if not dodge_requested or _dodge_time_remaining > 0.0 or _forced_movement_remaining > 0.0:
		return

	if movement_direction.is_zero_approx():
		return

	if not _spend_energy(dodge_energy_consumption):
		return

	# 蓄力打断只发生在冲刺能量已成功支付后；方向无效、能量不足或状态冲突不会改变当前蓄力。
	if _weapon_charge_component != null and _weapon_charge_component.has_method("cancel_charge"):
		_weapon_charge_component.call("cancel_charge")
	if _active_skill_component != null and _active_skill_component.has_method("cancel_aiming"):
		_active_skill_component.call("cancel_aiming")
	_dodge_direction = movement_direction.normalized()
	_dodge_time_remaining = maxf(dodge_duration, 0.01)
	_record_stock_metric("dodges", 1.0)


func _record_stock_metric(metric_name: String, amount: float) -> void:
	# 股市统计服务；缺失时直接跳过，使玩家控制器仍可在独立测试场景运行。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_method("record_run_metric"):
		stock_market_service.call("record_run_metric", metric_name, amount)


func _move_dodge(delta: float) -> void:
	# 有效冲刺时长；取值至少 0.01 秒，默认由 dodge_duration 夹取，修改会影响突进速度计算。
	var effective_dodge_duration: float = maxf(dodge_duration, 0.01)
	# 冲刺速度；取值为距离除以时长，默认确保总位移接近 dodge_distance，修改会影响突进帧速度。
	var dodge_speed: float = maxf(dodge_distance, 0.0) / effective_dodge_duration
	velocity = _dodge_direction * dodge_speed + _knockback_velocity
	move_and_slide()
	_cancel_blocked_knockback_components()
	_decay_knockback(delta)
	_dodge_time_remaining = maxf(_dodge_time_remaining - delta, 0.0)
	if _dodge_time_remaining <= 0.0:
		_dodge_direction = Vector2.ZERO
		velocity = Vector2.ZERO


func _get_movement_speed_multiplier(movement_direction: Vector2, delta: float) -> float:
	# 综合移动倍率；默认 1，疾跑、蓄力、技能和套装效果依次连乘，互不覆盖其他来源。
	var resolved_multiplier: float = 1.0
	# 本帧是否成功进入疾跑；只有满足移动、输入与能量支付条件时才暂停自然回能并应用疾跑倍率。
	var sprinting_this_frame: bool = false
	if not movement_direction.is_zero_approx() and _input_component.has_method("is_sprint_pressed") and bool(_input_component.call("is_sprint_pressed")):
		# 本帧疾跑能耗；取值大于等于 0，只有成功支付时才应用疾跑倍率。
		var sprint_energy_consumption: float = maxf(sprint_energy_consumption_per_second, 0.0) * delta
		if _spend_energy(sprint_energy_consumption):
			sprinting_this_frame = true
			resolved_multiplier *= maxf(sprint_speed_multiplier, 1.0)
	_set_sprinting_state(sprinting_this_frame)
	if _weapon_charge_component != null and _weapon_charge_component.has_method("get_movement_speed_multiplier"):
		resolved_multiplier *= maxf(float(_weapon_charge_component.call("get_movement_speed_multiplier")), 0.0)
	if _temporary_buff_component != null and _temporary_buff_component.has_method("get_move_speed_multiplier"):
		resolved_multiplier *= maxf(float(_temporary_buff_component.call("get_move_speed_multiplier")), 0.0)
	# 临时属性点倍率；以装备结算后的当前基础移速为分母，把技能提供的固定点数转换为移动组件可消费的倍率。
	var base_move_speed_attribute: float = float(_movement_component.call("get_max_speed")) if _movement_component != null and _movement_component.has_method("get_max_speed") else 1.0
	resolved_multiplier *= maxf((base_move_speed_attribute + _get_movement_speed_attribute_bonus()) / maxf(base_move_speed_attribute, 1.0), 0.0)
	for raw_multiplier in _movement_speed_multiplier_sources.values():
		resolved_multiplier *= maxf(float(raw_multiplier), 0.0)
	if _equipment_set_component != null and _equipment_set_component.has_method("get_contextual_movement_speed_multiplier"):
		resolved_multiplier *= maxf(float(_equipment_set_component.call("get_contextual_movement_speed_multiplier", global_position, movement_direction)), 0.0)
	return maxf(resolved_multiplier, 0.0)


func set_movement_speed_multiplier_source(source_id: String, multiplier: float) -> void:
	## 设置一个独立临时移动倍率；相同来源覆盖旧值，空 ID 被忽略，角色切换或效果结束时必须显式移除。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	_movement_speed_multiplier_sources[normalized_source_id] = maxf(multiplier, 0.0)


func remove_movement_speed_multiplier_source(source_id: String) -> void:
	## 移除指定移动倍率来源；不存在时保持幂等，不影响疾跑、装备或其他技能。
	_movement_speed_multiplier_sources.erase(source_id.strip_edges())


func set_movement_speed_attribute_bonus_source(source_id: String, bonus_attribute: float) -> void:
	## 设置一个独立固定移速属性来源；相同来源覆盖旧值，负值按 0 处理，适用于“移速增加 99 点”而不是比例加速。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	# 标准移速加成；相同来源数值未变化时不重复刷新角色面板。
	var resolved_bonus_attribute: float = maxf(bonus_attribute, 0.0)
	if is_equal_approx(float(_movement_speed_attribute_bonus_sources.get(normalized_source_id, -1.0)), resolved_bonus_attribute):
		return
	_movement_speed_attribute_bonus_sources[normalized_source_id] = resolved_bonus_attribute
	movement_speed_attribute_bonus_changed.emit()


func remove_movement_speed_attribute_bonus_source(source_id: String) -> void:
	## 移除指定固定移速属性来源；不存在时保持幂等，不影响装备比例、疾跑或其他移动倍率。
	if _movement_speed_attribute_bonus_sources.erase(source_id.strip_edges()):
		movement_speed_attribute_bonus_changed.emit()


func _get_movement_speed_attribute_bonus() -> float:
	## 汇总全部固定移速属性来源；每个来源直接加算点数，结果最低为 0。
	var total_bonus: float = 0.0
	for raw_bonus in _movement_speed_attribute_bonus_sources.values():
		total_bonus += maxf(float(raw_bonus), 0.0)
	return maxf(total_bonus, 0.0)


func get_movement_speed_attribute_bonus() -> float:
	## 返回全部技能提供的固定移速属性点；角色面板使用该公开入口显示“技能”分项。
	return _get_movement_speed_attribute_bonus()


func get_current_move_speed_attribute() -> float:
	## 返回用于套装与技能判定的当前移速属性；包含装备、固定点数技能和消耗品比例，不包含疾跑与蓄力控制倍率。
	# 装备结算后的基础移速；移动组件缺失时按 0 处理。
	var base_attribute: float = float(_movement_component.call("get_max_speed")) if _movement_component != null and _movement_component.has_method("get_max_speed") else 0.0
	# 消耗品移速倍率；默认 1，不包含疾跑和其他操作状态倍率。
	var temporary_multiplier: float = float(_temporary_buff_component.call("get_move_speed_multiplier")) if _temporary_buff_component != null and _temporary_buff_component.has_method("get_move_speed_multiplier") else 1.0
	return maxf((base_attribute + _get_movement_speed_attribute_bonus()) * maxf(temporary_multiplier, 0.0), 0.0)


func set_attack_speed_bonus_source(source_id: String, bonus_ratio: float) -> void:
	## 设置一个独立玩家攻速提升比例；0.99 表示手持武器攻速提高 99%，相同来源只覆盖自身且不进入角色面板。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	_attack_speed_bonus_sources[normalized_source_id] = maxf(bonus_ratio, 0.0)


func remove_attack_speed_bonus_source(source_id: String) -> void:
	## 移除指定攻速来源；不存在时保持幂等，不修改武器强化冷却或其他技能效果。
	_attack_speed_bonus_sources.erase(source_id.strip_edges())


func get_attack_speed_multiplier() -> float:
	## 返回玩家手持武器综合攻速倍率；技能与不同消耗品比例加算，同一来源由各自组件保证不重复叠加。
	# 综合攻速提升比例；技能来源与临时道具来源直接加算，最终再加基础 1 倍。
	var bonus_ratio: float = 0.0
	for raw_bonus in _attack_speed_bonus_sources.values():
		bonus_ratio += maxf(float(raw_bonus), 0.0)
	if _temporary_buff_component != null and _temporary_buff_component.has_method("get_attack_speed_multiplier"):
		bonus_ratio += maxf(float(_temporary_buff_component.call("get_attack_speed_multiplier")) - 1.0, 0.0)
	return maxf(1.0 + bonus_ratio, 0.01)


func get_outgoing_damage_multiplier() -> float:
	## 返回玩家当前全部“增伤/造成的伤害提高”来源形成的唯一倍率；武器和主动技能均通过该入口读取。
	return maxf(1.0 + get_outgoing_damage_bonus_ratio(), 0.0)


func get_outgoing_damage_bonus_ratio() -> float:
	## 返回同一增伤乘区内的累计比例；不同来源直接加算，供自带蓄力增伤的攻击合并后只应用一次。
	# 综合增伤比例；稳定来源与当前套装效果均累计为比例，不在这里提前转换成多个独立倍率。
	var combined_bonus_ratio: float = 0.0
	for raw_bonus_ratio in _outgoing_damage_bonus_sources.values():
		combined_bonus_ratio += maxf(float(raw_bonus_ratio), 0.0)
	if _equipment_set_component != null and _equipment_set_component.has_method("get_move_speed_damage_bonus_ratio"):
		combined_bonus_ratio += maxf(float(_equipment_set_component.call("get_move_speed_damage_bonus_ratio", get_current_move_speed_attribute())), 0.0)
	return maxf(combined_bonus_ratio, 0.0)


func set_outgoing_damage_bonus_source(source_id: String, bonus_ratio: float) -> void:
	## 设置一个独立“增伤/造成的伤害提高”来源；相同 ID 覆盖旧值，负值按 0 处理，运行时效果结束时应配对移除。
	# 标准来源 ID；空字符串不写入，避免多个匿名效果互相覆盖且无法精确清理。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	_outgoing_damage_bonus_sources[normalized_source_id] = maxf(bonus_ratio, 0.0)


func remove_outgoing_damage_bonus_source(source_id: String) -> void:
	## 移除指定增伤来源；不存在时保持幂等，不影响套装、蓄力增伤或其他独立来源。
	_outgoing_damage_bonus_sources.erase(source_id.strip_edges())


func set_damage_reduction_source(source_id: String, reduction_ratio: float) -> void:
	## 设置一个独立“免伤/受到的伤害降低”来源；相同来源覆盖旧值，所有来源在同一乘区加算并统一限制到 100%。
	var normalized_source_id: String = source_id.strip_edges()
	if normalized_source_id.is_empty():
		return
	_damage_reduction_sources[normalized_source_id] = clampf(reduction_ratio, 0.0, 1.0)


func remove_damage_reduction_source(source_id: String) -> void:
	## 移除指定减伤来源；不存在时保持幂等，不影响装备套装、武器蓄力或其他技能。
	_damage_reduction_sources.erase(source_id.strip_edges())


func start_forced_movement(direction: Vector2, duration_seconds: float, bonus_move_speed_attribute: float) -> bool:
	## 开始不可操控的定向移动；速度按当前角色移速属性加技能额外属性后统一换算为像素/秒。
	if direction.is_zero_approx() or duration_seconds <= 0.0:
		return false
	_forced_movement_direction = direction.normalized()
	_forced_movement_remaining = maxf(duration_seconds, 0.0)
	# 当前移动速度属性；由移动组件保存角色基础值及装备倍率结算后的基础属性，技能额外值直接相加。
	var current_move_speed_attribute: float = float(_movement_component.call("get_max_speed")) if _movement_component.has_method("get_max_speed") else 100.0
	_forced_movement_speed = maxf(current_move_speed_attribute + bonus_move_speed_attribute, 0.0) * 2.0
	_forced_movement_blocked_this_frame = false
	_dodge_time_remaining = 0.0
	_dodge_direction = Vector2.ZERO
	return true


func cancel_forced_movement() -> void:
	## 立即结束当前强制移动；角色切换或技能行为提前销毁时调用，避免旧角色冲锋状态遗留到新角色。
	_forced_movement_remaining = 0.0
	_forced_movement_speed = 0.0
	velocity = Vector2.ZERO


func _move_forced_movement(delta: float) -> void:
	## 推进当前强制移动并保留墙体碰撞；持续时间归零后清空速度，下一物理帧恢复正常控制。
	velocity = _forced_movement_direction * _forced_movement_speed + _knockback_velocity
	move_and_slide()
	# 强制移动墙体碰撞；只有法线确实阻挡冲锋方向时标记，沿墙滑动或其他切向碰撞不会提前结束技能。
	for collision_index in range(get_slide_collision_count()):
		# 本次滑动碰撞；空结果跳过，法线用于判断是否阻挡强制移动主方向。
		var slide_collision: KinematicCollision2D = get_slide_collision(collision_index)
		if slide_collision != null and _forced_movement_direction.dot(slide_collision.get_normal()) < 0.0:
			_forced_movement_blocked_this_frame = true
			break
	_cancel_blocked_knockback_components()
	_decay_knockback(delta)
	_forced_movement_remaining = maxf(_forced_movement_remaining - maxf(delta, 0.0), 0.0)
	if _forced_movement_remaining <= 0.0:
		_forced_movement_speed = 0.0
		velocity = Vector2.ZERO


func was_forced_movement_blocked_this_frame() -> bool:
	## 返回最近一次强制移动是否正面撞上环境；具体技能决定是否据此提前结束，不把技能规则写入移动聚合脚本。
	return _forced_movement_blocked_this_frame


func apply_front_recoil_distance(direction: Vector2, recoil_distance: float) -> void:
	## 应用一次不依赖武器资源的前坐力理论位移；主动技能使用与武器相同的匀减速换算和累计速度上限。
	if direction.is_zero_approx() or recoil_distance <= 0.0:
		return
	apply_knockback(direction.normalized(), _calculate_external_motion_initial_speed(recoil_distance))


func _get_received_damage_multiplier() -> float:
	## 汇总全部“免伤/受到的伤害降低”来源并返回唯一剩余伤害倍率；比例先加算，再统一限制到 100%。
	# 综合免伤比例；所有来源处于同一乘区，两个 10% 免伤得到 20% 而不是按剩余伤害得到 19%。
	var combined_reduction_ratio: float = 0.0
	if _weapon_charge_component != null and _weapon_charge_component.has_method("get_damage_reduction_ratio"):
		combined_reduction_ratio += clampf(float(_weapon_charge_component.call("get_damage_reduction_ratio")), 0.0, 1.0)
	for raw_reduction_ratio in _damage_reduction_sources.values():
		combined_reduction_ratio += clampf(float(raw_reduction_ratio), 0.0, 1.0)
	if _equipment_set_component != null and _equipment_set_component.has_method("get_contextual_damage_reduction_ratio"):
		combined_reduction_ratio += clampf(float(_equipment_set_component.call("get_contextual_damage_reduction_ratio", global_position, _input_component.call("get_movement_vector"))), 0.0, 1.0)
	if _equipment_set_component != null and _equipment_set_component.has_method("get_move_speed_damage_reduction_ratio"):
		combined_reduction_ratio += clampf(float(_equipment_set_component.call("get_move_speed_damage_reduction_ratio", get_current_move_speed_attribute())), 0.0, 1.0)
	return 1.0 - clampf(combined_reduction_ratio, 0.0, 1.0)


func _spend_energy(amount: float) -> bool:
	if amount <= 0.0:
		return true

	if not _stats_component.has_method("spend_energy"):
		return true

	return bool(_stats_component.call("spend_energy", amount))


func _set_sprinting_state(enabled: bool) -> void:
	## 同步疾跑状态与自然回能阻止来源；只在实际状态变化时调用属性组件，避免每个物理帧重复改写字典。
	if _is_sprinting == enabled:
		return
	_is_sprinting = enabled
	if _stats_component != null and _stats_component.has_method("set_energy_regeneration_blocked_source"):
		_stats_component.call("set_energy_regeneration_blocked_source", SPRINT_ENERGY_REGENERATION_BLOCK_SOURCE_ID, _is_sprinting)


func _get_weapon_energy_consumption(weapon_data: Resource) -> float:
	if weapon_data == null:
		return 0.0
	if weapon_data.has_method("get_effective_stat"):
		return maxf(float(weapon_data.call("get_effective_stat", "energy_consumption")), 0.0)

	return maxf(float(weapon_data.get("energy_consumption")), 0.0)


func apply_knockback(direction: Vector2, force: float) -> void:
	if direction.is_zero_approx() or force <= 0.0:
		return

	_knockback_velocity += direction.normalized() * force
	# 限制后击退速度；连续射击或多次受击只保留可控上限，避免衰减时间随叠加次数无限增长。
	var resolved_max_knockback_speed: float = maxf(max_accumulated_knockback_speed, 1.0)
	if _knockback_velocity.length() > resolved_max_knockback_speed:
		_knockback_velocity = _knockback_velocity.normalized() * resolved_max_knockback_speed


func _apply_weapon_recoil(weapon_data: Resource, attack_direction: Vector2, force_multiplier: float = 1.0) -> void:
	if weapon_data == null or attack_direction.is_zero_approx():
		return

	# 武器后坐力；取值来自武器资源 recoil_force，单位为单次无碰撞理论位移像素，默认 0 表示不推动玩家。
	var recoil_force: float = _get_weapon_recoil_force(weapon_data) * maxf(force_multiplier, 0.0)
	if recoil_force <= 0.0:
		return

	apply_knockback(-attack_direction.normalized(), _calculate_recoil_initial_speed(recoil_force))


func _apply_weapon_front_recoil(weapon_data: Resource, attack_direction: Vector2, force_multiplier: float = 1.0) -> void:
	if weapon_data == null or attack_direction.is_zero_approx():
		return

	# 武器前坐力；取值来自武器资源 front_recoil_force，单位为单次无碰撞理论位移像素，默认 0 表示不把玩家推向攻击方向。
	var front_recoil_force: float = _get_weapon_front_recoil_force(weapon_data) * maxf(force_multiplier, 0.0)
	if front_recoil_force <= 0.0:
		return

	apply_knockback(attack_direction.normalized(), _calculate_recoil_initial_speed(front_recoil_force))


func _calculate_recoil_initial_speed(recoil_distance: float) -> float:
	## 把武器坐力的理论位移像素换算为匀减速初速度；返回值单位为像素/秒，供共享外部速度接口使用。
	return _calculate_external_motion_initial_speed(recoil_distance)


func _calculate_external_motion_initial_speed(motion_distance: float) -> float:
	## 把单次无碰撞理论位移像素换算为匀减速初速度；坐力与命中冲击共用该公式，返回值单位为像素/秒。
	# 安全理论位移；最低为 0 像素，异常负值不会产生反向或无效平方根。
	var resolved_motion_distance: float = maxf(motion_distance, 0.0)
	# 安全速度衰减；最低为 1 像素/秒²，与实际外部速度衰减使用相同保护值，修改会同步保持理论位移不变。
	var resolved_knockback_decay: float = maxf(knockback_decay, 1.0)
	return sqrt(2.0 * resolved_knockback_decay * resolved_motion_distance)


func _get_weapon_recoil_force(weapon_data: Resource) -> float:
	if weapon_data == null:
		return 0.0
	if not bool(weapon_data.get("has_recoil")):
		return 0.0
	if weapon_data.has_method("get_effective_stat"):
		return maxf(float(weapon_data.call("get_effective_stat", "recoil_force")), 0.0)

	return maxf(float(weapon_data.get("recoil_force")), 0.0)


func _get_weapon_front_recoil_force(weapon_data: Resource) -> float:
	if weapon_data == null:
		return 0.0
	if not bool(weapon_data.get("has_front_recoil")):
		return 0.0
	if weapon_data.has_method("get_effective_stat"):
		return maxf(float(weapon_data.call("get_effective_stat", "front_recoil_force")), 0.0)

	return maxf(float(weapon_data.get("front_recoil_force")), 0.0)


func _shake_screen_for_weapon_use(weapon_data: Resource, force_multiplier: float = 1.0) -> void:
	# 武器后坐力；取值来自武器资源 recoil_force，默认用于换算射击屏幕震动强度。
	var recoil_force: float = _get_weapon_recoil_force(weapon_data) * maxf(force_multiplier, 0.0)
	# 武器前坐力；取值来自武器资源 front_recoil_force，默认按后坐力一半倍率换算震动强度。
	var front_recoil_force: float = _get_weapon_front_recoil_force(weapon_data) * maxf(force_multiplier, 0.0)
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


func _play_dodge_feedback() -> void:
	## 通知独立视觉组件播放闪避反馈；该入口不修改伤害间隔、无敌状态、能量或闪避概率。
	if _dodge_feedback_component != null and _dodge_feedback_component.has_method("play_feedback"):
		_dodge_feedback_component.call("play_feedback", global_position, _resolve_effect_parent())


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

	# 来源冲击力；取值来自 source.get_impact_force()，单位为单次无碰撞理论位移像素，默认 0 表示不击退玩家。
	var impact_force: float = _get_source_impact_force(source)
	if impact_force <= 0.0:
		return

	# 来源击退方向；取值优先来自 source.get_knockback_direction()，默认由来源位置指向玩家。
	var knockback_direction: Vector2 = _get_source_knockback_direction(source)
	apply_knockback(knockback_direction, _calculate_external_motion_initial_speed(impact_force))


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


func _cancel_blocked_knockback_components() -> void:
	if _knockback_velocity.is_zero_approx():
		return
	# 碰撞索引；只检查本次 move_and_slide 产生的碰撞，将持续推向墙体的后坐力分量立即移除。
	for collision_index in range(get_slide_collision_count()):
		# 滑动碰撞；包含墙体法线，用于分离被阻挡与仍可沿墙移动的外部速度。
		var slide_collision: KinematicCollision2D = get_slide_collision(collision_index)
		if slide_collision == null:
			continue
		# 碰撞法线；指向远离墙体的方向，击退与法线点积为负时表示正在持续压向墙体。
		var collision_normal: Vector2 = slide_collision.get_normal()
		# 被阻挡投影；负值表示外部速度朝向墙体，移除后保留沿墙切向分量供玩家立即移动。
		var blocked_projection: float = _knockback_velocity.dot(collision_normal)
		if blocked_projection < 0.0:
			_knockback_velocity -= collision_normal * blocked_projection


func clear_external_motion() -> void:
	_knockback_velocity = Vector2.ZERO
	_dodge_direction = Vector2.ZERO
	_dodge_time_remaining = 0.0
	velocity = Vector2.ZERO
	if _movement_component != null and _movement_component.has_method("reset_motion"):
		_movement_component.call("reset_motion")


func find_nearest_clear_position(target_position: Vector2, clearance_radius: float, search_step: float, maximum_search_radius: float) -> Vector2:
	## 返回目标点或其周围最近的环境空地；只检测玩家环境碰撞掩码，完全找不到时返回 Vector2.INF 供技能取消释放。
	# 安全检测半径；最低 1 像素，避免退化形状查询。
	var resolved_clearance_radius: float = maxf(clearance_radius, 1.0)
	# 同心圆搜索步长；最低 1 像素，决定相邻搜索圈距离。
	var resolved_search_step: float = maxf(search_step, 1.0)
	# 最大搜索半径；至少覆盖一圈，异常小值不会直接跳过搜索。
	var resolved_maximum_radius: float = maxf(maximum_search_radius, resolved_search_step)
	if _is_teleport_position_clear(target_position, resolved_clearance_radius):
		return target_position
	# 搜索圈数；从最近一圈逐步向外扩展，保证首次找到的候选属于最小半径层。
	var ring_count: int = maxi(ceili(resolved_maximum_radius / resolved_search_step), 1)
	for ring_index in range(1, ring_count + 1):
		# 当前搜索半径；最后一圈不超过配置最大值，防止步长无法整除时越界搜索。
		var ring_radius: float = minf(float(ring_index) * resolved_search_step, resolved_maximum_radius)
		# 当前角度采样数；随周长增加并限制在 8 至 64，兼顾最近空地精度与单次物理查询成本。
		var sample_count: int = clampi(ceili(TAU * ring_radius / resolved_search_step), 8, 64)
		for sample_index in range(sample_count):
			# 候选位置；同圈均匀采样，起始角固定向右使结果在相同地图条件下可复现。
			var candidate_position: Vector2 = target_position + Vector2.RIGHT.rotated(TAU * float(sample_index) / float(sample_count)) * ring_radius
			if _is_teleport_position_clear(candidate_position, resolved_clearance_radius):
				return candidate_position
	return Vector2.INF


func _is_teleport_position_clear(candidate_position: Vector2, clearance_radius: float) -> bool:
	## 使用玩家环境碰撞掩码检查一个圆形占位；排除玩家自身 RID，避免当前位置或邻近候选被自身误判阻挡。
	# 安全占位圆；半径与技能资源一致，用于近似玩家本体空间。
	var clearance_shape: CircleShape2D = CircleShape2D.new()
	clearance_shape.radius = maxf(clearance_radius, 1.0)
	# 物理形状查询；只检测玩家 collision_mask 中的实体环境并排除自身。
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = clearance_shape
	query.transform = Transform2D(0.0, candidate_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func apply_character_base_attribute_allocation(attributes: Dictionary) -> bool:
	## 应用银狼五维基础属性分配；只通过现有属性与装备组件入口更新，不把临时分配写入角色模板或永久存档。
	for required_key in ["max_health", "max_energy", "attack_power", "defense_power", "move_speed"]:
		if not attributes.has(required_key):
			return false
	if _stats_component == null or not _stats_component.has_method("configure_character_base_stats"):
		return false
	_stats_component.call("configure_character_base_stats", float(attributes.get("max_health")), float(attributes.get("max_energy")), float(attributes.get("attack_power")), float(attributes.get("defense_power")))
	if _equipment_component != null and _equipment_component.has_method("configure_base_move_speed"):
		_equipment_component.call("configure_base_move_speed", float(attributes.get("move_speed")))
	return true
