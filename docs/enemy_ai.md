# 敌人移动、感知与独立战术系统

本文档是敌人 AI 的快速理解入口，统一记录虚拟人口加载、实心墙体视野、独立记忆、四段警戒、平面搜查、巡逻与寻路规则。当前版本不共享任何怪物情报：一只怪物发现玩家不会改变其他怪物的索敌状态，共享接收入口、共享战术组和不可达旧接收逻辑均已从代码中物理删除。

完整玩法规则和默认数值同时汇总在 `docs/游戏机制与玩法内容.md`。

## 架构职责

- `res://scripts/enemies/basic_monster.gd`：敌人聚合入口，维护生命、攻击、个体随机属性、AI 错峰更新和模拟启停。
- `res://scripts/components/enemy_perception_component.gd`：负责实心墙体视野、最后可见历史、短中长期记忆、卡墙次数和四段警戒状态。
- `res://scripts/components/enemy_tactical_component.gd`：只读取本怪物感知报告，生成独立的墙角、扇形搜查和伏击目标，不再发现队友、广播报告或分配小队职能。
- `res://scripts/components/enemy_movement_component.gd`：负责巡逻、随机游荡、共享 A* 路径请求、局部绕障、卡住恢复、物理移动和击退。
- `res://scripts/components/monster_simulation_manager.gd`：维护整张地图的轻量虚拟敌人人口，只在玩家附近分批实例化真实节点，并在远离后保存位置和生命比例再卸载。
- `res://scripts/enemies/ranged_monster.gd`：继承基础怪物，扩展安全距离、射击条件和敌方弹体生成。
- `res://scripts/game/game_world.gd`：负责整图虚拟人口生成、按游戏时长补充、环境矩形缓存和共享 A* 网格。

`basic_monster.tscn` 与 `ranged_monster.tscn` 显式挂载感知、移动和独立战术组件。`GameWorld` 显式挂载 `MonsterSimulationManager`。

两类怪物根节点的碰撞层固定为 2、碰撞掩码固定为 16，只与第 5 层环境障碍发生实体阻挡。基础怪物进入场景树时会强制从碰撞掩码移除玩家第 1 层，设置玩家目标时还会在怪物与玩家两侧建立双向碰撞例外，并在目标切换或怪物退出场景树时同步清理；远程怪物继承同一规则，因此旧场景配置和动态生成路径也无法恢复玩家实体碰撞。玩家与怪物可以交错经过，不会通过角色物理碰撞互相推动；伤害、近战距离判断、玩家弹体和敌方弹体仍使用各自独立判定，不受该调整影响。

## 怪物加载与性能规则

- `ContentCatalog` 在项目启动时递归扫描 `res://scenes/enemies/` 下的 `.tscn` 与 `.scn`，`GameWorld` 将结果与旧场景检查器池去重合并。复制现有怪物场景并重新进入战斗后，新场景会自动参与虚拟人口随机生成；完全不同的怪物实现仍必须遵守加载、目标、死亡信号和注销协议，创建规则见 `docs/content_authoring.md`。

- 地图 0 秒默认建立 200 名虚拟敌人人口，0 到 5 分钟连续增长到 1200 名，5 到 10 分钟连续增长到 3200 名，10 分钟后维持 3200 名目标并补充死亡缺口。刷新点始终位于玩家安全距离外并分布到整张地图。
- 虚拟记录只保存场景类型、世界位置、尺寸倍率、属性倍率和剩余生命比例，不创建节点、不执行 AI、不参与物理和绘制。
- `MonsterSimulationManager.active_radius` 默认 2400 像素。虚拟记录进入该范围后才允许实例化；真实敌人离开 2800 像素后还原为虚拟记录。
- `max_materialized_monsters` 默认 220，限制同时执行 AI 的真实敌人数量；人口增长主要提高地图分布密度，不会把 3200 名敌人同时加入场景树。
- 加载管理器每 `update_interval` 默认 0.05 秒扫描最多 `monsters_per_update` 默认 256 条记录；每批最多创建 `materializations_per_update` 默认 12 个节点，3200 条记录约 0.7 秒完成一轮范围检查。
- 激活怪物的物理移动仍逐帧执行；感知、射线、绕障和寻路决策按 `ai_update_interval` 默认 0.1 秒运行。每只怪物在出生时随机错开首次更新时间，避免同帧峰值。
- 已缓存的 A* 网格由所有激活怪物复用。路径重算继续受随机间隔和目标移动阈值限制。

## 死亡掉落

- 真实怪物死亡后由 `GameWorld._on_monster_died()` 统一处理掉落和虚拟人口注销，怪物脚本不直接依赖库存或强化系统。
- 武器继续读取怪物自身 `weapon_drop_chance`，默认 20%，并从 `weapon_drop_table` 随机复制独立武器实例。
- 强化石使用世界级 `enhancement_stone_drop_chance`，默认 0.10，即每次击杀独立有 10% 概率掉落一颗。
- 强化石品质权重为初级 40%、中级 30%、高级 20%、极品 10%。每颗必定 1 条增强；初级有 80% 概率附带 1 条削弱，中级有 10% 概率追加增强且 40% 概率附带削弱，高级对应概率为 20% 与 10%，极品有 30% 概率追加增强且无削弱。掉落时只保存属性方向，具体幅度在玩家使用时按属性幅度组与品质独立随机；乘算属性分为一级、二级、三级区间，暴击率、暴击伤害和闪避率使用各自的加算百分点区间。完整数值以 `docs/游戏机制与玩法内容.md` 的强化系统章节为准；地面拾取列表只显示品质和增强属性预览，不显示削弱属性。
- 虚拟记录本身不会在远处自动死亡或生成地面掉落；只有玩家附近已经实例化且实际被击杀的怪物才执行死亡掉落，避免远距离模拟产生无法拾取的资源节点。

## 实心墙体专属视野

- 视线默认只查询物理层 5，即 `vision_line_of_sight_collision_mask = 16`。
- 命中后还会校验碰撞体是否属于 `solid_wall_group`，默认 `environment_obstacles`。只有同时满足掩码和分组的实心墙体才能完全阻断视线。
- 未开启宝箱位于第 5 物理层并加入 `environment_obstacles`，且其 64×52 像素障碍矩形会在敌人人口生成前写入共享 A* 缓存来源，因此会同时参与敌人局部碰撞、寻路、视线和射击判定；开启或击毁后障碍矩形被移除并清空导航缓存，后续路径请求会恢复该位置通行。
- 射线命中其他地图元素时会继续跳过，最多跳过 `line_of_sight_skip_limit` 个对象。
- `vision_loss_grace_duration` 默认 0.2 秒，用于过滤单帧射线抖动；遮挡期间立即禁止攻击，持续超过缓冲后才正式进入搜查。
- 远程射击复用感知组件的实心墙体判定，并在真正创建弹体前再次校验玩家可见、实时距离不超过 `shoot_range` 且视线无遮挡，玩家已经离开射程时不会放空枪。
- 远程敌人使用 `ranged_projectile_deviation_degrees` 控制弹体偏移，默认 4 度；每次发射会在瞄准方向两侧随机变化，数值越高命中分布越分散。

## 四段警戒状态

| 状态 | 常量 | 进入条件 | 核心行为 |
| --- | --- | --- | --- |
| 三级常规警戒 | `IDLE = 0` | 未发现玩家、搜查结束或达到脱战阈值 | 返回预设巡逻或出生点游荡；途经本怪物中期热点时短时复查 |
| 可见追击 | `VISIBLE = 1` | 本怪物视野内直接看见玩家 | 使用玩家实时坐标固定移速追击；近战贴近，远程保持安全距离 |
| 一级独立搜查 | `SEARCHING = 2` | 本怪物因墙体遮挡、超距丢失目标或触发热点复查 | 前往最后线索和预测位置，再执行近中远三层扇形搜查 |
| 二级扩大搜查 | `BLOCKADE = 3` | 本怪物卡墙次数接近脱战阈值 | 扩大自身搜查半径，但不会通知或调动其他怪物 |

流转规则：

1. 玩家可见时只由当前怪物记录最后可见位置和估算速度。
2. `visible_contact`、`occlusion_loss` 和 `target_lost` 是当前怪物内部报告。它们只提供给该怪物自己的战术组件，不广播到场上其他怪物。
3. 玩家快速进入建筑、跑出扩展视野或绕过障碍时，`target_lost` 会刷新本怪物的最后线索，使其继续通过 A* 追入入口或通道。
4. 默认第三次确认墙体脱战后停止主动搜索，但短、中、长期数据不会一次性清空。
5. 只有玩家持续清晰可见达到 `occlusion_count_reset_duration`，本怪物的卡墙次数才会清零。

## 三层独立记忆

### 短期记忆

- 使用 `target_memory_duration`，默认 30 秒。
- 保存本怪物最后看见的坐标、墙体命中点、估算速度和逃跑方向。
- 搜查期间只使用历史线索，不读取墙后玩家实时坐标。

### 中期记忆

- 使用 `medium_memory_duration`，默认 60 秒。
- 本怪物的墙体命中点和预测逃生点按 `medium_hotspot_merge_distance` 合并并累计频次。
- 三级常规警戒途经热点时，会执行 `medium_recheck_duration` 秒额外复查。

### 长期记忆

- 使用 `long_term_region_radius` 保存本怪物本次交战片区。
- 短中期记忆消退后，路过该片区仍会降低巡逻速度并保持警戒，但不会隔墙锁定玩家。

## 独立平面搜查与伏击

- 每只怪物固定作为独立搜查单位，不扫描附近怪物数量，不再分配卡位或迂回队员。
- 第一个战术目标为最后发现坐标加受限速度预测，优先追过建筑入口、墙体缺口或通道。
- 后续使用 `tactical_search_near_radius`、`tactical_search_middle_radius` 和 `tactical_search_far_radius` 生成近、中、远三层扇形点。
- 近战使用 `melee_search_radius_multiplier` 贴墙搜查；远程使用 `ranged_search_radius_multiplier` 扩大范围并保持安全距离。
- 完成 `search_points_before_ambush` 个搜查点后进入静止伏击，避免反复转圈巡逻。
- 候选点不可达时，按 `tactical_destination_attempts` 旋转和收缩目标，并通过移动组件验证导航可达性。

## 固定移速与寻路

- 追击和主动搜查统一使用每只怪物出生时确定的固定个体移速，不按玩家逃跑方式临时变速。
- 目的地中心线无遮挡时优先直线移动；被墙体阻挡时请求 `GameWorld.find_navigation_path()`。
- A* 返回空路径时等待重算间隔并回退局部绕障，不会每个决策周期重复构建路径。
- 局部绕障使用每只怪物独立的左右偏好；持续卡住会翻转偏好并清空旧路径。
- `patrol_route_path` 留空时围绕出生点随机游荡；配置路线时按直接 Node2D 子节点顺序巡逻。

## 参数分组

- 加载与错峰：`active_radius`、`sleep_hysteresis`、`update_interval`、`monsters_per_update`、`materializations_per_update`、`max_materialized_monsters`、`ai_update_interval`。
- 死亡掉落：`weapon_drop_chance`、`enhancement_stone_drop_chance`、`enhancement_stone_min_modifier_count`、`enhancement_stone_max_modifier_count`、`enhancement_stone_negative_modifier_chance`、`enhancement_stone_base_value`、`EnhancementRules.ENHANCEMENT_STEP_RATIO`。
- 实心墙体视野：`vision_range`、`lose_target_range_multiplier`、`vision_requires_line_of_sight`、`vision_line_of_sight_collision_mask`、`vision_loss_grace_duration`、`solid_wall_group`、`line_of_sight_skip_limit`。
- 短期线索：`target_memory_duration`、`target_prediction_time`、`target_prediction_max_distance`、`search_arrive_distance`、`lost_search_occlusion_offset`。
- 中长期记忆：`medium_memory_duration`、`medium_hotspot_merge_distance`、`medium_hotspot_max_count`、`medium_recheck_trigger_radius`、`medium_recheck_duration`、`medium_recheck_cooldown`、`long_term_region_radius`、`long_term_alert_patrol_speed_multiplier`。
- 反卡墙状态：`occlusion_break_forget_count`、`occlusion_count_reset_duration`、`blockade_loss_margin`。
- 独立平面搜查：`tactical_search_near_radius`、`tactical_search_middle_radius`、`tactical_search_far_radius`、`tactical_blockade_radius_multiplier`、`melee_search_radius_multiplier`、`ranged_search_radius_multiplier`、`search_fan_half_angle_degrees`、`wall_corner_clearance`、`route_prediction_time`、`tactical_point_arrive_distance`、`tactical_point_wait_min`、`tactical_point_wait_max`、`search_points_before_ambush`、`tactical_destination_attempts`。
- 感知兜底：`target_search_duration_after_arrival`、`target_search_radius`、`target_search_point_wait_min`、`target_search_point_wait_max`、`lost_search_destination_attempts`。
- 空闲巡逻：`patrol_route_path`、`patrol_route_loop`、`wander_radius`、`wander_speed_multiplier`、`wander_arrive_distance`、`wander_wait_min`、`wander_wait_max`。
- 导航恢复：`avoidance_probe_distance`、`avoidance_angle_step_degrees`、`avoidance_candidate_count`、`pathfinding_enabled`、`pathfinding_cell_size`、`pathfinding_agent_radius`、`path_recalculation_min_interval`、`path_recalculation_max_interval`、`path_destination_refresh_distance`、`path_waypoint_arrive_distance`、`path_random_goal_radius`、`path_max_point_count`、`stuck_detection_time`、`stuck_minimum_movement`。

旧版 `squad_region_radius`、`coordination_update_interval`、`intelligence_relay_max_hops` 和 `role_rotation_interval` 导出字段已删除。运行代码中不存在共享接收方法、共享怪物组、级联传递调用或对外小队人数查询入口。

## 扩展约定

- 新敌人优先继承 `BasicMonster`，覆写 `_update_target_behavior()`，不要复制感知或加载状态机。
- 感知组件不得调用攻击、动画或移动代码。
- 战术组件只能读取本怪物感知报告和地图障碍信息，不得访问其他怪物感知状态。
- 移动组件只接收目的地、速度和导航验证请求。
- 新的实心遮挡物必须位于感知碰撞掩码内并加入 `environment_obstacles`。
- 新敌人场景必须可实例化为 `Node2D`，并提供 `set_target()`、`apply_spawn_variation()` 和 `died` 信号时优先复用现有加载、属性与死亡回收流程。
