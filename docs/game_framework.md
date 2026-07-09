# 游戏基础框架

本文档记录《崩坏：量子骇袭》的入口流程、玩家控制框架和可扩展点，用于后续长期维护。

## 场景入口

- `res://scenes/ui/main_menu.tscn` 是项目主场景，由 `project.godot` 的 `run/main_scene` 指向。
- 主菜单脚本 `res://scripts/ui/main_menu.gd` 通过 `character_select_scene_path` 加载独立角色选择场景，默认第一行按钮文案为“骇入”。主菜单同时保留“训练场”按钮，两者都会先写入当前模式，再进入 `res://scenes/ui/character_select.tscn`。
- `res://scenes/ui/character_select.tscn` 是进入战斗前的角色选择场景。玩家在左侧选择“星”“穹”“银狼”，右侧会显示角色名称、定位、说明、固定生命上限、固定能量上限、固定速度和技能占位信息，点击确认后进入 `res://scenes/game/game_world.tscn`。
- 主菜单提供“设置”入口，当前设置项为全局 Master 主音量，设置值直接写入 `AudioServer`。
- `res://scripts/game/session_state.gd` 通过 `project.godot` 自动加载为 `SessionState`，负责保存本次进入的模式和角色，避免把入口参数写进场景路径。
- `res://scenes/game/game_world.tscn` 是当前战斗承载场景，负责放置玩家、怪物、网格地图、随机墙体建筑和掉落物。它的脚本会在进入场景后生成大型网格地图，再随机摆放一批环境障碍和怪物。

## 玩家角色

- `res://scenes/characters/silver_wolf.tscn` 当前作为通用玩家预制体使用，根节点为 `CharacterBody2D`。实际显示角色由独立角色选择场景决定。
- 当前可选角色为“星”“穹”“银狼”。三名角色暂时只提供占位属性：进入骇入、进入训练场或在训练场内切换角色时，会按固定配置设置生命上限、能量上限和移动速度；主动技能和被动技能后续再接入。
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
- `toggle_large_map`：M，打开或关闭完整大地图
- `pause_game`：ESC，暂停游戏并打开暂停菜单

`PlayerInputComponent` 同时读取 InputMap 和物理按键兜底。即使输入映射被误删，WASD、Shift、Space、鼠标左键、鼠标右键仍可保持基础可控。

数字键切换通过 `max_direct_ranged_slots` 控制可直接访问的远程槽数量，默认值为 2。扩展远程槽位时，需要同步提高 `EquipmentComponent.ranged_slot_count` 和 `PlayerInputComponent.max_direct_ranged_slots`。

## 组件职责

- `PlayerInputComponent`：读取移动向量、鼠标瞄准方向、远程攻击状态、近战攻击请求、疾跑状态和闪避请求。
- `TopDownMovementComponent`：根据方向向量、速度倍率和外部击退速度更新 `CharacterBody2D.velocity`，并执行 `move_and_slide()`。
- `RangedAttackComponent`：按冷却生成弹体，弹体从 `AimPivot/Muzzle` 位置发射，并把武器射程、伤害、速度和冲击力写入弹体。
- `MeleeAttackComponent`：在短时间内开启朝向鼠标方向的 `Area2D` 命中框，支持命中去重、近战冲击力和敌方子弹消除。
- `PlayerProjectile`：按方向移动，按寿命或最大距离自动销毁，通过射线提前检测怪物和环境墙体，命中可调用目标的 `apply_damage(damage, source)`。
- `EnemyProjectile`：远程怪物发射的敌方弹体，会命中玩家或被环境阻挡，也能被玩家近战命中框消除。
- `CombatStatsComponent`：维护玩家生命、能量和能量恢复，武器成功使用后由玩家控制器调用 `spend_energy()` 扣除能量。
- `InventoryComponent`：维护玩家拥有的物品资源列表，当前主要存放武器资源，后续可扩展消耗品、材料和任务道具。
- `EquipmentComponent`：维护远程武器槽、当前远程槽索引和近战武器槽，负责切换与装备状态，不直接执行攻击。
- `WeaponSlotControl`：显示单个武器槽或背包物品槽，负责拖拽数据、投放校验和白色冷却遮罩绘制，不直接修改装备数据。
- `InventoryDropArea`：接收拖到背包空白区域的武器拖拽数据，并转发给 HUD 按背包末尾投放处理。
- `CombatHud`：底部中心显示当前角色名、玩家生命、能量和武器栏，右上角显示玩家周围小地图，E 键打开背包，M 键打开完整大地图，ESC 打开暂停菜单，监听组件信号并处理拖拽装备和卸下。
- `MiniMapControl`：读取 GameWorld 的地图边界、探索格和环境障碍矩形，局部模式绘制玩家周围地图，完整模式绘制整张地图和未探索区域迷雾，当前不显示怪物。
- `BasicMonster`：基础怪物，维护血量、攻击力、韧性、冲击力、移速、视野范围、绕障追击、游荡和近身攻击。
- `RangedMonster`：远程测试怪物，继承基础怪物受击、韧性、绕障和游荡逻辑，发现玩家后保持距离并发射敌方子弹。
- `SessionState`：入口会话状态，保存当前模式和当前角色，供主菜单、GameWorld 和训练场角色切换复用。
- `GameWorld`：战斗承载脚本，生成大型网格地图，按配置随机生成墙体、建筑和怪物，并根据当前角色刷新玩家占位属性。

## 武器与装备

武器由 `res://scripts/data/weapon_data.gd` 定义，默认资源位于 `res://data/weapons/`：

- `quantum_pistol.tres`：量子手枪，远程武器，低能耗、稳定射速。
- `pulse_rifle.tres`：脉冲步枪，远程武器，高射速、高能耗。
- `phase_blade.tres`：相位刃，近战武器，右键消耗能量开启近战命中框。
- `ion_smg.tres`：离子冲锋枪，远程测试武器，高射速、低单发伤害。
- `rail_cannon.tres`：磁轨炮，远程测试武器，高伤害、长冷却。
- `scatter_blaster.tres`：散射爆能枪，远程测试武器，中等射速和中等消耗。
- `quantum_dagger.tres`：量子短刃，近战测试武器，低消耗、短冷却。

当前通用玩家预制体默认装备两把远程武器和一把近战武器：

- 远程槽 1：量子手枪
- 远程槽 2：脉冲步枪
- 近战槽：相位刃

远程攻击流程为：玩家输入左键 -> `PlayerController` 读取当前远程武器 -> 检查 `CombatStatsComponent` 能量是否足够 -> `RangedAttackComponent.try_attack(direction, weapon_data)` 成功生成弹体 -> 弹体获得武器 `bullet_range`、`impact_force`、速度和伤害 -> 玩家受到 `recoil_force` 反方向后坐力 -> 扣除武器 `energy_cost`。

近战攻击流程为：玩家输入右键 -> `PlayerController` 读取当前近战武器 -> 检查能量是否足够 -> `MeleeAttackComponent.try_attack(direction, weapon_data)` 成功开启命中框 -> 命中怪物时按武器 `impact_force` 击退，命中敌方子弹时直接消除 -> 扣除武器 `energy_cost`。

武器新增三项控制相关属性：`bullet_range` 仅远程武器使用，用于覆盖弹体最大飞行距离；`recoil_force` 表示开火后坐力，会把玩家向射击反方向推开；`impact_force` 表示命中冲击力，怪物会按自身韧性折算击退强度。

移动能力流程为：玩家按住 Shift 且存在移动输入时，`PlayerController` 每帧按 `sprint_energy_cost_per_second * delta` 扣除能量，并把本帧移动速度倍率提升到 `sprint_speed_multiplier`；玩家按下 Space 且当前存在移动输入时，先扣除 `dodge_energy_cost`，再按 `dodge_distance / dodge_duration` 朝当前移动方向突进。背包打开时战斗输入被锁定，疾跑和闪避也不会触发能量消耗。

战斗 HUD 布局固定为底部中心，并保持紧凑尺寸以降低视野遮挡：当前角色名、生命条和能量条在武器栏上方，远程武器槽和近战武器槽在下方。右上角小地图只显示玩家周围一段范围，并显示玩家以及墙体、建筑，不显示怪物。使用武器后，对应武器槽会绘制白色半透明冷却遮罩，冷却刚开始时覆盖整个槽位，随后随 `get_cooldown_ratio()` 返回值降低而缩短。

按 M 会打开完整大地图。大地图显示整张战斗地图、玩家位置、墙体和建筑，并读取 `GameWorld` 的探索格缓存绘制迷雾；玩家探索过的格子正常显示，未探索格子会叠加半透明滤镜。大地图打开时会锁定射击、近战、切换武器、疾跑和闪避输入，避免查看地图时误触战斗操作。

背包通过 E 键打开或关闭。背包打开时，`CombatHud` 会通过 `PlayerInputComponent.set_combat_input_enabled(false)` 禁用射击、近战和切换武器，避免拖拽装备时误触战斗输入；WASD 移动不受影响。

背包界面采用左右分栏：左侧是当前装备的远程槽和近战槽，右侧是背包内未装备的武器。右侧提供“全部”“近战”“远程”分页筛选，背包物品槽第一行直接显示武器类型，避免把近战和远程武器混淆。

装备和背包使用单实例流转规则：一把武器资源同一时间只能存在于一个位置。右侧背包武器拖到左侧装备槽后，会从背包列表移除；如果目标装备槽已有武器，旧武器会回到原背包位置。左侧装备拖回右侧背包的空白区域或任意背包物品上都会卸下并插入背包；背包武器之间拖拽会移动原物品顺序，不会复制资源；远程装备槽之间拖拽会移动或交换同一个武器引用。

## 暂停与设置

ESC 会打开战斗暂停菜单，并通过 `get_tree().paused` 暂停游戏世界。暂停菜单提供“继续游戏”“设置”“返回主菜单”，右侧会显示与 M 键大地图同源的完整地图和迷雾。返回主菜单前会先解除暂停，再切换到 `res://scenes/ui/main_menu.tscn`。

暂停设置和主菜单设置共用同一条 Master 音量规则：滑条范围为 0 到 100，0 会静音 Master 总线，大于 0 时使用 `linear_to_db()` 写入音量。

训练场暂停菜单额外提供“训练场设置”面板。正式“骇入”模式会隐藏该入口，不能打开训练场专属功能。训练场设置包含“清空场上怪物”“重新生成怪物”“切换角色”三个按钮，以及“无限能量”“无限血量”两个开关。无限能量通过 `CombatStatsComponent.set_infinite_energy()` 生效，开启后武器、疾跑和闪避消耗都不会降低能量；无限血量通过 `CombatStatsComponent.set_infinite_health()` 生效，开启后怪物攻击不会降低玩家生命；切换角色通过 `GameWorld.switch_character(character_id)` 生效，并按固定配置刷新当前角色的生命上限、能量上限和移动速度。

## 怪物与训练场

当前怪物场景包括 `res://scenes/enemies/basic_monster.tscn` 和 `res://scenes/enemies/ranged_monster.tscn`。怪物使用 `CharacterBody2D`，碰撞层为 2，玩家弹体和近战命中框通过碰撞层 2 命中怪物。

基础怪物属性包括：

- `max_health` / `current_health`：血量。
- `attack_damage`：攻击力，近身攻击玩家时传给玩家的 `apply_damage(damage, source)`。
- `toughness`：韧性百分比，默认 0；数值为 1 时减少 1% 击退效果，数值为 100 时完全免疫击退。
- `attack_impact_force`：怪物近身攻击冲击力，玩家受伤时会按来源方向被击退。
- `move_speed`：移速，索敌后直线追击玩家。
- `vision_range`：视野范围，玩家进入范围后怪物锁定并追击。
- `attack_range`：攻击距离，玩家进入后怪物停止移动并按冷却攻击。
- `attack_cooldown`：攻击冷却。
- `wander_radius`、`wander_speed_multiplier`、`wander_arrive_distance`、`wander_wait_min`、`wander_wait_max`：无目标游荡参数。怪物未发现玩家时会围绕出生点随机选点移动，到达后等待一小段时间再选下一个点。
- `avoidance_probe_distance`、`avoidance_angle_step_degrees`、`avoidance_candidate_count`：绕障参数。怪物追击或游荡时会先尝试直线方向，若前方被墙体挡住，则按左右候选角度寻找可移动方向。
- `knockback_decay`：击退衰减速度，控制怪物被玩家武器命中后滑退多久。

远程怪物额外属性包括 `projectile_scene`、`shoot_range`、`keep_distance`、`ranged_projectile_speed`、`ranged_projectile_damage`、`ranged_projectile_range`、`ranged_projectile_impact_force`、`shoot_cooldown`、`muzzle_offset`、`line_of_sight_collision_mask` 和 `projectile_parent_path`。远程怪物只有在玩家进入射击距离且与怪物之间没有环境墙体遮挡时才会开火；如果距离太远或视线被挡，会先绕障接近；如果玩家太近，会尝试后撤保持距离。

`GameWorld` 进入骇入或训练场时都会先生成大型网格地图。默认地图以世界原点居中，`grid_extent = 96` 会生成 192x192 格地图；`map_seed = 0` 表示每次进入都随机生成环境布局，设置为固定正数可以复现同一套墙体、建筑和怪物位置。当前地表绘制纯色底面、低透明度网格线和地图边界，地图结构主要由随机墙体和建筑提供。地图四周会按 `boundary_wall_thickness` 自动生成一圈环境墙，阻挡玩家、怪物和子弹离开地图。

环境预制体位于 `res://scenes/environment/`：

- `wall_segment.tscn`：单段直墙。
- `compact_building.tscn`：实心建筑块。
- `wall_ring_building.tscn`：一圈墙体构成的建筑结构，底部保留入口缺口，玩家和怪物可以进入内部。
- `corridor_building.tscn`：两侧墙体构成的通道建筑，前后开口可通行。
- `cross_access_building.tscn`：四角建筑块构成的四向出入口建筑，中心与上下左右方向可通行。
- `l_wall.tscn`：L 型墙体，用于制造转角掩体和局部阻挡。
- `l_building.tscn`：L 型实心建筑块，用于制造更大的转角建筑轮廓。

`GameWorld` 通过 `obstacle_scenes`、`obstacle_spawn_count`、`obstacle_spawn_min_distance_from_player`、`obstacle_spawn_edge_margin`、`obstacle_spawn_min_spacing`、`obstacle_spawn_attempts_per_item`、`obstacle_scale_min` 和 `obstacle_scale_max` 控制环境生成。默认环境生成更密集，并会对每个预制体应用随机旋转和随机等比缩放，使同类墙体和建筑出现不同体积。墙体和建筑碰撞层为第 5 层，玩家检测第 5 层，怪物检测玩家层和第 5 层，玩家弹体检测怪物层和第 5 层，敌方弹体检测玩家层和第 5 层，因此墙体和建筑能阻挡玩家、怪物和所有子弹。生成成功后，GameWorld 会缓存环境碰撞矩形，供小地图和大地图绘制墙体和建筑。

`GameWorld` 会按 `exploration_cell_size` 和 `exploration_radius` 记录玩家探索过的地图格子。该数据只由地图 UI 读取，不影响怪物索敌和碰撞。调整格子尺寸会影响迷雾精度和缓存数量；调整探索半径会影响玩家走过后大地图可见区域大小。

`GameWorld` 通过 `monster_scene`、`monster_scenes`、`monster_spawn_count`、`monster_spawn_min_distance`、`monster_spawn_max_distance` 和 `monster_parent_path` 控制怪物生成。`monster_scenes` 非空时会优先从该数组随机选择怪物场景，当前默认混合生成近战基础怪物和远程测试怪物。默认进入战斗场景时，以玩家位置为中心，在最小和最大距离之间随机生成 8 个怪物，并调用怪物的 `set_target(player)` 设置索敌目标。

训练场提供 `clear_monsters()` 和 `respawn_monsters()` 两个接口给 HUD 训练场设置调用。清怪会先按训练怪物组清理，再清理 `monster_parent_path` 指向的怪物容器；重新生成会按当前配置追加一批新怪物，不会清空场上已有怪物。

## 可调参数

所有核心数值都暴露为 `@export`：

- 移动：`max_speed`、`acceleration`、`friction`、`stop_threshold`
- 玩家移动能力：`sprint_speed_multiplier`、`sprint_energy_cost_per_second`、`dodge_energy_cost`、`dodge_distance`、`dodge_duration`、`knockback_decay`
- 远程攻击：`projectile_scene`、`projectile_speed`、`projectile_damage`、`fire_cooldown`、`fallback_muzzle_distance`、`projectile_parent_path`
- 近战攻击：`damage`、`cooldown_duration`、`active_duration`、`rotation_offset`
- 弹体：`speed`、`lifetime`、`max_distance`、`damage`、`destroy_on_hit`、`impact_force`
- 战斗属性：`max_health`、`current_health`、`max_energy`、`current_energy`、`energy_regeneration_per_second`、`infinite_health`、`infinite_energy`
- 装备：`ranged_slot_count`、`starting_ranged_weapons`、`starting_melee_weapon`
- 怪物：`max_health`、`current_health`、`attack_damage`、`toughness`、`attack_impact_force`、`move_speed`、`vision_range`、`attack_range`、`attack_cooldown`、`lose_target_range_multiplier`、`wander_radius`、`wander_speed_multiplier`、`wander_arrive_distance`、`wander_wait_min`、`wander_wait_max`、`avoidance_probe_distance`、`avoidance_angle_step_degrees`、`avoidance_candidate_count`、`knockback_decay`
- 远程怪物：`projectile_scene`、`shoot_range`、`keep_distance`、`ranged_projectile_speed`、`ranged_projectile_damage`、`ranged_projectile_range`、`ranged_projectile_impact_force`、`shoot_cooldown`、`muzzle_offset`、`line_of_sight_collision_mask`、`projectile_parent_path`
- 战斗地图：`grid_size`、`grid_extent`、`map_seed`、`base_floor_color`、`grid_color`、`axis_color`、`exploration_cell_size`、`exploration_radius`、`boundary_wall_thickness`、`boundary_wall_color`
- 训练场生成：`monster_scene`、`monster_scenes`、`monster_spawn_count`、`monster_spawn_min_distance`、`monster_spawn_max_distance`、`monster_parent_path`
- 环境生成：`environment_parent_path`、`obstacle_scenes`、`obstacle_spawn_count`、`obstacle_spawn_min_distance_from_player`、`obstacle_spawn_edge_margin`、`obstacle_spawn_min_spacing`、`obstacle_spawn_attempts_per_item`、`obstacle_scale_min`、`obstacle_scale_max`
- 角色占位属性：`stelle_max_health`、`stelle_max_energy`、`stelle_move_speed`、`caelus_max_health`、`caelus_max_energy`、`caelus_move_speed`、`silver_wolf_max_health`、`silver_wolf_max_energy`、`silver_wolf_move_speed`
- 武器数据：`weapon_type`、`energy_cost`、`projectile_speed`、`bullet_range`、`ranged_damage`、`ranged_cooldown`、`recoil_force`、`impact_force`、`melee_damage`、`melee_cooldown`、`melee_active_duration`
- 主菜单入口：`character_select_scene_path`
- 角色选择：`game_scene_path`、`main_menu_scene_path`、`stat_bar_maximum`、`speed_bar_maximum`
- HUD：`ranged_slot_minimum_size`、`melee_slot_minimum_size`、`inventory_slot_minimum_size`、`toggle_inventory_action`、`toggle_large_map_action`、`pause_action`、`main_menu_scene_path`
- 小地图和大地图：`game_world_path`、`player_path`、`display_mode`、`local_view_radius`、`fallback_map_half_size`、`minimap_background_color`、`minimap_border_color`、`obstacle_color`、`fog_overlay_color`、`player_color`、`player_marker_radius`

调参优先在 Godot 检查器中完成，只有新增规则或默认值需要沉淀时再修改脚本。

## 扩展约定

- 敌人、可破坏物或训练靶如果需要接收伤害，应实现 `apply_damage(damage: float, source: Node)`。需要支持击退时，可从 `source.get_impact_force()` 和 `source.get_knockback_direction()` 读取冲击力与方向。
- 可被玩家近战清除的敌方弹体应实现 `destroy_by_melee(source: Node)`，并放在 `EnemyProjectile` 物理层上。
- 新武器优先复用 `RangedAttackComponent` 或 `MeleeAttackComponent`，通过替换弹体场景、枪口节点和参数形成差异。
- 新角色优先复用现有组件，根节点只保留聚合逻辑，避免把移动、攻击、输入全部塞进同一个脚本。
- 聚合脚本为了保持低耦合，可以通过 `NodePath` 获取组件并保持动态类型；从动态组件方法接收返回值时，局部变量必须显式标注类型，例如 `var movement_direction: Vector2 = ...`，避免 Godot 无法推断返回类型。
- GDScript 中每个 `var`、`@export var`、`@onready var` 变量定义前必须有独立注释，说明变量用途、数据含义、默认值原因、推荐取值范围和修改影响；循环变量也应在循环前说明范围和影响。
