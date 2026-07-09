extends CharacterBody2D
class_name PlayerController

## 玩家聚合脚本只负责把输入、移动、远程攻击、近战攻击等组件串起来。
## 具体能力放在独立组件中实现，后续替换角色、武器或控制方式时可以局部替换节点。

## 玩家显示名称；默认值为“银狼”，仅用于界面和调试标识，运行时通常不需要修改，改名会影响后续 UI 展示文本。
@export var player_display_name: String = "银狼"
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

## 最近一次有效瞄准方向；取值为单位向量，默认向右保证鼠标贴近角色时仍有攻击方向，修改会影响无有效鼠标方向时的攻击朝向。
var _last_aim_direction: Vector2 = Vector2.RIGHT

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


func _physics_process(delta: float) -> void:
	_handle_weapon_switch_input()

	# 当前帧移动方向；取值为归一化 Vector2 或 Vector2.ZERO，无持久默认值，修改会直接影响本帧移动速度方向。
	var movement_direction: Vector2 = _input_component.get_movement_vector()
	_movement_component.move(self, movement_direction, delta)

	# 当前帧瞄准方向；取值为归一化 Vector2 或 Vector2.ZERO，无持久默认值，修改会影响本帧武器旋转和攻击朝向缓存。
	var aim_direction: Vector2 = _input_component.get_aim_direction(global_position)
	if not aim_direction.is_zero_approx():
		_last_aim_direction = aim_direction
		_aim_pivot.rotation = _last_aim_direction.angle()

	if _input_component.is_fire_requested():
		_try_fire_ranged_weapon()

	if _input_component.consume_melee_request():
		_try_use_melee_weapon()


func apply_damage(damage: float, source: Node) -> void:
	if _stats_component.has_method("take_damage"):
		_stats_component.call("take_damage", damage)


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
	if attack_succeeded and _stats_component.has_method("spend_energy"):
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
	if attack_succeeded and _stats_component.has_method("spend_energy"):
		_stats_component.call("spend_energy", energy_cost)


func _get_weapon_energy_cost(weapon_data: Resource) -> float:
	if weapon_data == null:
		return 0.0

	return maxf(float(weapon_data.get("energy_cost")), 0.0)
