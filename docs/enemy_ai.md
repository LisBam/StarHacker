# 敌人移动、感知与独立战术系统

本文档是敌人 AI 的快速理解入口，统一记录远距离加载休眠、实心墙体视野、独立记忆、四段警戒、平面搜查、巡逻与寻路规则。当前版本不共享任何怪物情报：一只怪物发现玩家不会改变其他怪物的索敌状态。

## 架构职责

- `res://scripts/enemies/basic_monster.gd`：敌人聚合入口，维护生命、攻击、个体随机属性、AI 错峰更新和模拟启停。
- `res://scripts/components/enemy_perception_component.gd`：负责实心墙体视野、最后可见历史、短中长期记忆、卡墙次数和四段警戒状态。
- `res://scripts/components/enemy_tactical_component.gd`：只读取本怪物感知报告，生成独立的墙角、扇形搜查和伏击目标，不再发现队友、广播报告或分配小队职能。
- `res://scripts/components/enemy_movement_component.gd`：负责巡逻、随机游荡、共享 A* 路径请求、局部绕障、卡住恢复、物理移动和击退。
- `res://scripts/components/monster_simulation_manager.gd`：集中注册整张地图上的怪物，分批切换玩家加载范围内外的模拟状态。
- `res://scripts/enemies/ranged_monster.gd`：继承基础怪物，扩展安全距离、射击条件和敌方弹体生成。
- `res://scripts/game/game_world.gd`：负责整图生成、怪物补充、加载管理器注册、环境矩形缓存和共享 A* 网格。

`basic_monster.tscn` 与 `ranged_monster.tscn` 显式挂载感知、移动和独立战术组件。`GameWorld` 显式挂载 `MonsterSimulationManager`。

## 怪物加载与性能规则

- 地图默认生成 160 名敌人，最低存活数量为 144，每批补充 16 名。刷新点仍分布在玩家安全距离外的整张地图。
- `MonsterSimulationManager.active_radius` 默认 2400 像素。只有玩家周围该范围内的怪物执行 AI、碰撞和绘制。
- 已激活怪物使用 `sleep_hysteresis` 默认 400 像素迟滞距离，离开 2800 像素后才休眠，防止边界反复切换。
- 休眠怪物仍作为存活节点保留在原地图坐标并计入补充数量，但会隐藏视觉、关闭碰撞、停止物理帧和全部 AI 逻辑。
- 加载管理器每 `update_interval` 默认 0.1 秒检查一批，单批最多 `monsters_per_update` 默认 40 名。160 名怪物约 0.4 秒完成一次完整距离刷新。
- 激活怪物的物理移动仍逐帧执行；感知、射线、绕障和寻路决策按 `ai_update_interval` 默认 0.1 秒运行。每只怪物在出生时随机错开首次更新时间，避免同帧峰值。
- 已缓存的 A* 网格由所有激活怪物复用。路径重算继续受随机间隔和目标移动阈值限制。

## 实心墙体专属视野

- 视线默认只查询物理层 5，即 `vision_line_of_sight_collision_mask = 16`。
- 命中后还会校验碰撞体是否属于 `solid_wall_group`，默认 `environment_obstacles`。只有同时满足掩码和分组的实心墙体才能完全阻断视线。
- 射线命中其他地图元素时会继续跳过，最多跳过 `line_of_sight_skip_limit` 个对象。
- `vision_loss_grace_duration` 默认 0.2 秒，用于过滤单帧射线抖动；遮挡期间立即禁止攻击，持续超过缓冲后才正式进入搜查。
- 远程射击复用感知组件的实心墙体判定，不维护第二套遮挡结论。

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

- 加载与错峰：`active_radius`、`sleep_hysteresis`、`update_interval`、`monsters_per_update`、`ai_update_interval`、`hide_when_simulation_inactive`、`disable_collision_when_simulation_inactive`。
- 实心墙体视野：`vision_range`、`lose_target_range_multiplier`、`vision_requires_line_of_sight`、`vision_line_of_sight_collision_mask`、`vision_loss_grace_duration`、`solid_wall_group`、`line_of_sight_skip_limit`。
- 短期线索：`target_memory_duration`、`target_prediction_time`、`target_prediction_max_distance`、`search_arrive_distance`、`lost_search_occlusion_offset`。
- 中长期记忆：`medium_memory_duration`、`medium_hotspot_merge_distance`、`medium_hotspot_max_count`、`medium_recheck_trigger_radius`、`medium_recheck_duration`、`medium_recheck_cooldown`、`long_term_region_radius`、`long_term_alert_patrol_speed_multiplier`。
- 反卡墙状态：`occlusion_break_forget_count`、`occlusion_count_reset_duration`、`blockade_loss_margin`。
- 独立平面搜查：`tactical_search_near_radius`、`tactical_search_middle_radius`、`tactical_search_far_radius`、`tactical_blockade_radius_multiplier`、`melee_search_radius_multiplier`、`ranged_search_radius_multiplier`、`search_fan_half_angle_degrees`、`wall_corner_clearance`、`route_prediction_time`、`tactical_point_arrive_distance`、`tactical_point_wait_min`、`tactical_point_wait_max`、`search_points_before_ambush`、`tactical_destination_attempts`。
- 感知兜底：`target_search_duration_after_arrival`、`target_search_radius`、`target_search_point_wait_min`、`target_search_point_wait_max`、`lost_search_destination_attempts`。
- 空闲巡逻：`patrol_route_path`、`patrol_route_loop`、`wander_radius`、`wander_speed_multiplier`、`wander_arrive_distance`、`wander_wait_min`、`wander_wait_max`。
- 导航恢复：`avoidance_probe_distance`、`avoidance_angle_step_degrees`、`avoidance_candidate_count`、`pathfinding_enabled`、`pathfinding_cell_size`、`pathfinding_agent_radius`、`path_recalculation_min_interval`、`path_recalculation_max_interval`、`path_destination_refresh_distance`、`path_waypoint_arrive_distance`、`path_random_goal_radius`、`path_max_point_count`、`stuck_detection_time`、`stuck_minimum_movement`。

旧版 `squad_region_radius`、`coordination_update_interval`、`intelligence_relay_max_hops` 和 `role_rotation_interval` 字段仅为场景兼容保留，不参与队友发现、情报传播或人数分工。

## 扩展约定

- 新敌人优先继承 `BasicMonster`，覆写 `_update_target_behavior()`，不要复制感知或加载状态机。
- 感知组件不得调用攻击、动画或移动代码。
- 战术组件只能读取本怪物感知报告和地图障碍信息，不得访问其他怪物感知状态。
- 移动组件只接收目的地、速度和导航验证请求。
- 新的实心遮挡物必须位于感知碰撞掩码内并加入 `environment_obstacles`。
- 新敌人必须实现或继承 `set_simulation_active()`，确保远距离加载管理能停止其 AI 与物理。
