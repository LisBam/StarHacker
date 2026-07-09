# 游戏基础框架

本文档记录当前项目的入口流程、玩家控制框架和可扩展点，用于后续长期维护。

## 场景入口

- `res://scenes/ui/main_menu.tscn` 是项目主场景，由 `project.godot` 的 `run/main_scene` 指向。
- 主菜单脚本 `res://scripts/ui/main_menu.gd` 通过 `game_scene_path` 加载游戏世界，默认按钮文案为“测试战斗”，进入 `res://scenes/game/game_world.tscn`。
- 主菜单提供“设置”入口，当前设置项为全局 Master 主音量，设置值直接写入 `AudioServer`。
- `res://scenes/game/game_world.tscn` 是当前测试战斗场景，负责放置玩家、怪物、地图和掉落物。它的脚本会绘制调试网格，并在进入场景后随机刷新测试怪物。

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
- `sprint`：Shift，按住疾跑并持续消耗能量
- `dodge`：Space，朝当前移动方向闪避突进
- `switch_ranged_1`：数字键 1，切换到第 1 个远程武器槽
- `switch_ranged_2`：数字键 2，切换到第 2 个远程武器槽
- `switch_ranged_previous`：鼠标滚轮上，切换到上一把远程武器
- `switch_ranged_next`：鼠标滚轮下，切换到下一把远程武器
- `toggle_inventory`：E，打开或关闭背包界面
- `pause_game`：ESC，暂停游戏并打开暂停菜单

`PlayerInputComponent` 同时读取 InputMap 和物理按键兜底。即使输入映射被误删，WASD、Shift、Space、鼠标左键、鼠标右键仍可保持基础可控。

数字键切换通过 `max_direct_ranged_slots` 控制可直接访问的远程槽数量，默认值为 2。扩展远程槽位时，需要同步提高 `EquipmentComponent.ranged_slot_count` 和 `PlayerInputComponent.max_direct_ranged_slots`。

## 组件职责

- `PlayerInputComponent`：读取移动向量、鼠标瞄准方向、远程攻击状态、近战攻击请求、疾跑状态和闪避请求。
- `TopDownMovementComponent`：根据方向向量和速度倍率更新 `CharacterBody2D.velocity`，并执行 `move_and_slide()`。
- `RangedAttackComponent`：按冷却生成弹体，弹体从 `AimPivot/Muzzle` 位置发射。
- `MeleeAttackComponent`：在短时间内开启朝向鼠标方向的 `Area2D` 命中框，支持命中去重和伤害回调。
- `PlayerProjectile`：按方向移动，按寿命或最大距离自动销毁，命中可调用目标的 `apply_damage(damage, source)`。
- `CombatStatsComponent`：维护玩家生命、能量和能量恢复，武器成功使用后由玩家控制器调用 `spend_energy()` 扣除能量。
- `InventoryComponent`：维护玩家拥有的物品资源列表，当前主要存放武器资源，后续可扩展消耗品、材料和任务道具。
- `EquipmentComponent`：维护远程武器槽、当前远程槽索引和近战武器槽，负责切换与装备状态，不直接执行攻击。
- `WeaponSlotControl`：显示单个武器槽或背包物品槽，负责拖拽数据、投放校验和白色冷却遮罩绘制，不直接修改装备数据。
- `InventoryDropArea`：接收拖到背包空白区域的武器拖拽数据，并转发给 HUD 按背包末尾投放处理。
- `CombatHud`：底部中心显示玩家生命、能量和武器栏，E 键打开背包，ESC 打开暂停菜单，监听组件信号并处理拖拽装备和卸下。
- `BasicMonster`：基础怪物，维护血量、攻击力、移速、视野范围、索敌追击和近身攻击。
- `GameWorld`：测试战斗承载脚本，绘制调试网格，并按配置随机刷新怪物。

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

移动能力流程为：玩家按住 Shift 且存在移动输入时，`PlayerController` 每帧按 `sprint_energy_cost_per_second * delta` 扣除能量，并把本帧移动速度倍率提升到 `sprint_speed_multiplier`；玩家按下 Space 且当前存在移动输入时，先扣除 `dodge_energy_cost`，再按 `dodge_distance / dodge_duration` 朝当前移动方向突进。背包打开时战斗输入被锁定，疾跑和闪避也不会触发能量消耗。

战斗 HUD 布局固定为底部中心，并保持紧凑尺寸以降低视野遮挡：生命条和能量条在武器栏上方，远程武器槽和近战武器槽在下方。使用武器后，对应武器槽会绘制白色半透明冷却遮罩，冷却刚开始时覆盖整个槽位，随后随 `get_cooldown_ratio()` 返回值降低而缩短。

背包通过 E 键打开或关闭。背包打开时，`CombatHud` 会通过 `PlayerInputComponent.set_combat_input_enabled(false)` 禁用射击、近战和切换武器，避免拖拽装备时误触战斗输入；WASD 移动不受影响。

背包界面采用左右分栏：左侧是当前装备的远程槽和近战槽，右侧是背包内未装备的武器。右侧提供“全部”“近战”“远程”分页筛选，背包物品槽第一行直接显示武器类型，避免把近战和远程武器混淆。

装备和背包使用单实例流转规则：一把武器资源同一时间只能存在于一个位置。右侧背包武器拖到左侧装备槽后，会从背包列表移除；如果目标装备槽已有武器，旧武器会回到原背包位置。左侧装备拖回右侧背包的空白区域或任意背包物品上都会卸下并插入背包；背包武器之间拖拽会移动原物品顺序，不会复制资源；远程装备槽之间拖拽会移动或交换同一个武器引用。

## 暂停与设置

ESC 会打开战斗暂停菜单，并通过 `get_tree().paused` 暂停游戏世界。暂停菜单提供“继续游戏”“设置”“返回主菜单”。返回主菜单前会先解除暂停，再切换到 `res://scenes/ui/main_menu.tscn`。

暂停设置和主菜单设置共用同一条 Master 音量规则：滑条范围为 0 到 100，0 会静音 Master 总线，大于 0 时使用 `linear_to_db()` 写入音量。

## 怪物与测试战斗

当前怪物场景为 `res://scenes/enemies/basic_monster.tscn`，脚本为 `res://scripts/enemies/basic_monster.gd`。怪物使用 `CharacterBody2D`，碰撞层为 2，玩家弹体和近战命中框通过碰撞层 2 命中怪物。

基础怪物属性包括：

- `max_health` / `current_health`：血量。
- `attack_damage`：攻击力，近身攻击玩家时传给玩家的 `apply_damage(damage, source)`。
- `move_speed`：移速，索敌后直线追击玩家。
- `vision_range`：视野范围，玩家进入范围后怪物锁定并追击。
- `attack_range`：攻击距离，玩家进入后怪物停止移动并按冷却攻击。
- `attack_cooldown`：攻击冷却。

`GameWorld` 通过 `monster_scene`、`monster_spawn_count`、`monster_spawn_min_distance`、`monster_spawn_max_distance` 和 `monster_parent_path` 控制测试战斗怪物生成。默认进入测试战斗时，以玩家位置为中心，在最小和最大距离之间随机生成 8 个怪物，并调用怪物的 `set_target(player)` 设置索敌目标。

## 可调参数

所有核心数值都暴露为 `@export`：

- 移动：`max_speed`、`acceleration`、`friction`、`stop_threshold`
- 玩家移动能力：`sprint_speed_multiplier`、`sprint_energy_cost_per_second`、`dodge_energy_cost`、`dodge_distance`、`dodge_duration`
- 远程攻击：`projectile_scene`、`projectile_speed`、`projectile_damage`、`fire_cooldown`、`fallback_muzzle_distance`
- 近战攻击：`damage`、`cooldown_duration`、`active_duration`、`rotation_offset`
- 弹体：`speed`、`lifetime`、`max_distance`、`damage`、`destroy_on_hit`
- 战斗属性：`max_health`、`current_health`、`max_energy`、`current_energy`、`energy_regeneration_per_second`
- 装备：`ranged_slot_count`、`starting_ranged_weapons`、`starting_melee_weapon`
- 怪物：`max_health`、`current_health`、`attack_damage`、`move_speed`、`vision_range`、`attack_range`、`attack_cooldown`、`lose_target_range_multiplier`
- 测试战斗生成：`monster_scene`、`monster_spawn_count`、`monster_spawn_min_distance`、`monster_spawn_max_distance`、`monster_parent_path`
- 武器数据：`weapon_type`、`energy_cost`、`projectile_speed`、`ranged_damage`、`ranged_cooldown`、`melee_damage`、`melee_cooldown`、`melee_active_duration`
- HUD：`ranged_slot_minimum_size`、`melee_slot_minimum_size`、`inventory_slot_minimum_size`、`toggle_inventory_action`、`pause_action`、`main_menu_scene_path`

调参优先在 Godot 检查器中完成，只有新增规则或默认值需要沉淀时再修改脚本。

## 扩展约定

- 敌人、可破坏物或训练靶如果需要接收伤害，应实现 `apply_damage(damage: float, source: Node)`。
- 新武器优先复用 `RangedAttackComponent` 或 `MeleeAttackComponent`，通过替换弹体场景、枪口节点和参数形成差异。
- 新角色优先复用现有组件，根节点只保留聚合逻辑，避免把移动、攻击、输入全部塞进同一个脚本。
- 聚合脚本为了保持低耦合，可以通过 `NodePath` 获取组件并保持动态类型；从动态组件方法接收返回值时，局部变量必须显式标注类型，例如 `var movement_direction: Vector2 = ...`，避免 Godot 无法推断返回类型。
- GDScript 中每个 `var`、`@export var`、`@onready var` 变量定义前必须有独立注释，说明变量用途、数据含义、默认值原因、推荐取值范围和修改影响；循环变量也应在循环前说明范围和影响。
