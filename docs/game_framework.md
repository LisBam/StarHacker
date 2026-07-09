# 游戏基础框架

本文档记录当前项目的入口流程、玩家控制框架和可扩展点，用于后续长期维护。

## 场景入口

- `res://scenes/ui/main_menu.tscn` 是项目主场景，由 `project.godot` 的 `run/main_scene` 指向。
- 主菜单脚本 `res://scripts/ui/main_menu.gd` 通过 `game_scene_path` 加载游戏世界，默认进入 `res://scenes/game/game_world.tscn`。
- `res://scenes/game/game_world.tscn` 是当前关卡承载场景，负责放置玩家、敌人、地图和掉落物。它的脚本会绘制调试网格，用于观察移动距离、射击方向和近战范围。

## 玩家角色

- `res://scenes/characters/silver_wolf.tscn` 是玩家角色“银狼”的预制体，根节点为 `CharacterBody2D`。
- `res://scripts/player/player_controller.gd` 是聚合脚本，只负责调度输入、移动、远程攻击、近战攻击和瞄准朝向。聚合脚本通过节点路径获取组件，不直接强类型依赖自定义组件类，避免新项目或缓存刷新时出现全局类名解析顺序问题。
- 玩家视觉、碰撞、摄像机、枪口、输入组件、移动组件、远程攻击组件和近战攻击组件都以子节点形式挂载，便于逐项替换。

## 输入规则

输入映射在 `project.godot` 的 `[input]` 中维护：

- `move_left`：A
- `move_right`：D
- `move_up`：W
- `move_down`：S
- `attack_fire`：鼠标左键
- `attack_melee`：鼠标右键
- `switch_ranged_1`：数字键 1，切换到第 1 个远程武器槽
- `switch_ranged_2`：数字键 2，切换到第 2 个远程武器槽
- `switch_ranged_previous`：鼠标滚轮上，切换到上一把远程武器
- `switch_ranged_next`：鼠标滚轮下，切换到下一把远程武器
- `toggle_inventory`：E，打开或关闭背包界面

`PlayerInputComponent` 同时读取 InputMap 和物理按键兜底。即使输入映射被误删，WASD、鼠标左键、鼠标右键仍可保持基础可控。

数字键切换通过 `max_direct_ranged_slots` 控制可直接访问的远程槽数量，默认值为 2。扩展远程槽位时，需要同步提高 `EquipmentComponent.ranged_slot_count` 和 `PlayerInputComponent.max_direct_ranged_slots`。

## 组件职责

- `PlayerInputComponent`：读取移动向量、鼠标瞄准方向、远程攻击状态和近战攻击请求。
- `TopDownMovementComponent`：根据方向向量更新 `CharacterBody2D.velocity`，并执行 `move_and_slide()`。
- `RangedAttackComponent`：按冷却生成弹体，弹体从 `AimPivot/Muzzle` 位置发射。
- `MeleeAttackComponent`：在短时间内开启朝向鼠标方向的 `Area2D` 命中框，支持命中去重和伤害回调。
- `PlayerProjectile`：按方向移动，按寿命或最大距离自动销毁，命中可调用目标的 `apply_damage(damage, source)`。
- `CombatStatsComponent`：维护玩家生命、能量和能量恢复，武器成功使用后由玩家控制器调用 `spend_energy()` 扣除能量。
- `InventoryComponent`：维护玩家拥有的物品资源列表，当前主要存放武器资源，后续可扩展消耗品、材料和任务道具。
- `EquipmentComponent`：维护远程武器槽、当前远程槽索引和近战武器槽，负责切换与装备状态，不直接执行攻击。
- `WeaponSlotControl`：显示单个武器槽或背包物品槽，负责拖拽数据、投放校验和白色冷却遮罩绘制，不直接修改装备数据。
- `CombatHud`：底部中心显示玩家生命、能量和武器栏，E 键打开背包，监听组件信号并处理拖拽装备和卸下。

## 武器与装备

武器由 `res://scripts/data/weapon_data.gd` 定义，默认资源位于 `res://data/weapons/`：

- `quantum_pistol.tres`：量子手枪，远程武器，低能耗、稳定射速。
- `pulse_rifle.tres`：脉冲步枪，远程武器，高射速、高能耗。
- `phase_blade.tres`：相位刃，近战武器，右键消耗能量开启近战命中框。
- `ion_smg.tres`：离子冲锋枪，远程测试武器，高射速、低单发伤害。
- `rail_cannon.tres`：磁轨炮，远程测试武器，高伤害、长冷却。
- `scatter_blaster.tres`：散射爆能枪，远程测试武器，中等射速和中等消耗。
- `quantum_dagger.tres`：量子短刃，近战测试武器，低消耗、短冷却。

`silver_wolf.tscn` 默认装备两把远程武器和一把近战武器：

- 远程槽 1：量子手枪
- 远程槽 2：脉冲步枪
- 近战槽：相位刃

远程攻击流程为：玩家输入左键 -> `PlayerController` 读取当前远程武器 -> 检查 `CombatStatsComponent` 能量是否足够 -> `RangedAttackComponent.try_attack(direction, weapon_data)` 成功生成弹体 -> 扣除武器 `energy_cost`。

近战攻击流程为：玩家输入右键 -> `PlayerController` 读取当前近战武器 -> 检查能量是否足够 -> `MeleeAttackComponent.try_attack(direction, weapon_data)` 成功开启命中框 -> 扣除武器 `energy_cost`。

战斗 HUD 布局固定为底部中心，并保持紧凑尺寸以降低视野遮挡：生命条和能量条在武器栏上方，远程武器槽和近战武器槽在下方。使用武器后，对应武器槽会绘制白色半透明冷却遮罩，冷却刚开始时覆盖整个槽位，随后随 `get_cooldown_ratio()` 返回值降低而缩短。

背包通过 E 键打开或关闭。背包打开时，`CombatHud` 会通过 `PlayerInputComponent.set_combat_input_enabled(false)` 禁用射击、近战和切换武器，避免拖拽装备时误触战斗输入；WASD 移动不受影响。

背包界面采用左右分栏：左侧是当前装备的远程槽和近战槽，右侧是背包内拥有的武器。玩家可以从右侧拖拽武器到左侧装备槽完成装备，也可以把左侧已装备武器拖到右侧背包区域完成卸下。卸下不会从背包物品列表删除武器，背包仍作为玩家拥有物品的来源。

## 可调参数

所有核心数值都暴露为 `@export`：

- 移动：`max_speed`、`acceleration`、`friction`、`stop_threshold`
- 远程攻击：`projectile_scene`、`projectile_speed`、`projectile_damage`、`fire_cooldown`、`fallback_muzzle_distance`
- 近战攻击：`damage`、`cooldown_duration`、`active_duration`、`rotation_offset`
- 弹体：`speed`、`lifetime`、`max_distance`、`damage`、`destroy_on_hit`
- 战斗属性：`max_health`、`current_health`、`max_energy`、`current_energy`、`energy_regeneration_per_second`
- 装备：`ranged_slot_count`、`starting_ranged_weapons`、`starting_melee_weapon`
- 武器数据：`weapon_type`、`energy_cost`、`projectile_speed`、`ranged_damage`、`ranged_cooldown`、`melee_damage`、`melee_cooldown`、`melee_active_duration`
- HUD：`ranged_slot_minimum_size`、`melee_slot_minimum_size`、`inventory_slot_minimum_size`、`toggle_inventory_action`

调参优先在 Godot 检查器中完成，只有新增规则或默认值需要沉淀时再修改脚本。

## 扩展约定

- 敌人、可破坏物或训练靶如果需要接收伤害，应实现 `apply_damage(damage: float, source: Node)`。
- 新武器优先复用 `RangedAttackComponent` 或 `MeleeAttackComponent`，通过替换弹体场景、枪口节点和参数形成差异。
- 新角色优先复用现有组件，根节点只保留聚合逻辑，避免把移动、攻击、输入全部塞进同一个脚本。
- 聚合脚本为了保持低耦合，可以通过 `NodePath` 获取组件并保持动态类型；从动态组件方法接收返回值时，局部变量必须显式标注类型，例如 `var movement_direction: Vector2 = ...`，避免 Godot 无法推断返回类型。
- GDScript 中每个 `var`、`@export var`、`@onready var` 变量定义前必须有独立注释，说明变量用途、数据含义、默认值原因、推荐取值范围和修改影响；循环变量也应在循环前说明范围和影响。
