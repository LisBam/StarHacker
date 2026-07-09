# 敌人移动与索敌系统

本文档是敌人 AI 的快速理解入口，记录感知、玩家记忆、遮挡搜查、脱战、巡逻和寻路规则。修改敌人索敌或移动代码时，应优先同步本文档，再校验 `docs/game_framework.md` 中的全局摘要与参数清单。

## 架构职责

- `res://scripts/enemies/basic_monster.gd`：敌人聚合入口，保留生命、攻击、个体数值随机、组件配置同步和对外接口，不再直接维护完整感知与寻路状态。
- `res://scripts/components/enemy_perception_component.gd`：只负责视野射线、目标记忆、状态流转、遮挡次数、搜查锚点和区域搜查点，不执行移动或攻击。
- `res://scripts/components/enemy_movement_component.gd`：只负责预设巡逻、随机游荡、A* 路径缓存、局部绕障、卡住恢复、`move_and_slide()` 和击退，不读取玩家实时位置或索敌状态。
- `res://scripts/enemies/ranged_monster.gd`：继承基础怪物聚合接口，只扩展保持距离、射击线检测和敌方弹体生成。
- `res://scripts/game/game_world.gd`：提供共享的缓存 A* 网格与 `find_navigation_path()`，敌人组件通过能力接口查找服务，不硬编码具体关卡节点路径。

`basic_monster.tscn` 和 `ranged_monster.tscn` 都显式挂载 `EnemyPerceptionComponent` 与 `EnemyMovementComponent`。旧场景如果尚未挂载组件，基础怪物会在运行时补齐，避免已有敌人预制体立即失效。

## 三阶段状态流

| 状态 | 进入条件 | 使用的信息 | 行为 | 离开条件 |
| --- | --- | --- | --- | --- |
| 空闲巡逻 `IDLE` | 没有发现玩家，或搜索结束、达到卡视野脱战阈值 | 出生点或预设巡逻点 | 优先返回预设路线；未配置路线时在出生点周边游荡；两者都不可用时待机警戒 | 玩家进入视野且射线无遮挡 |
| 可见追击 `VISIBLE` | 玩家位于有效视野内，且环境遮挡射线没有命中 | 玩家当前实时坐标、当前距离 | 直接追击；中心线被障碍阻挡时请求 A*；近战怪进入攻击距离后攻击，远程怪满足射击距离与射击线条件后开火 | 玩家离开有效视野，或持续被障碍完全遮挡超过丢失确认时间 |
| 丢失搜查 `SEARCHING` | 已锁定玩家，但视野丢失确认完成且未达到脱战阈值 | 最后可见坐标、最后可见阶段速度、遮挡命中点、固定搜索点 | 前往遮挡物背后或最后线索处，再在周边多点巡逻搜查；不读取墙后玩家实时坐标 | 重新看见玩家、记忆/搜查时间耗尽，或卡视野次数达到阈值 |

完整流转为：

1. 空闲状态只使用视野范围与环境射线发现玩家，不会隔墙获得目标。
2. 玩家可见后进入追击，感知组件逐帧记录最后可见坐标，并根据相邻可见帧估算移动趋势。
3. 射线第一次被挡时立即禁止攻击和远程射击，但会等待 `vision_loss_grace_duration`。默认 0.2 秒，用于过滤墙角擦边和单帧物理抖动，不会因此误计一次卡视野。
4. 遮挡持续超过确认时间后，记录环境射线的遮挡命中点，并将卡视野次数加一。离开视野范围触发的丢失也会搜索最后线索，但不会增加卡视野次数。
5. 未达到 `occlusion_break_forget_count` 时，根据遮挡命中点沿怪物视角向障碍后方推进 `lost_search_occlusion_offset`，生成初始搜查锚点。没有有效遮挡点时，使用最后可见位置加受限速度预测作为锚点。
6. 移动组件向 `GameWorld.find_navigation_path()` 请求路径。锚点位于墙体或建筑内部时，GameWorld 会选择附近可行走网格，因此怪物会尝试绕向建筑入口、通道或遮挡物背侧，而不是直线贴墙。
7. 到达锚点后，在 `target_search_radius` 内挑选多个搜查点。每到一个点停留 `target_search_point_wait_min` 到 `target_search_point_wait_max` 秒观察，再继续移动；搜查阶段使用 `search_move_speed_multiplier`，默认慢于正面追击。
8. 搜查途中重新看到玩家会立即回到可见追击。之前的卡视野次数会保留；只有目标连续清晰可见达到 `occlusion_count_reset_duration` 后才会清零，避免短暂露头反复骗取无限搜索。
9. 卡视野次数达到阈值时，立即清除最后位置、速度、遮挡点、搜查点和路径，回到空闲巡逻。之后只有玩家再次真实进入视野且无遮挡时才能重新锁定。

## 信息边界

- 可见追击阶段允许读取玩家实时坐标。
- 失去视野后，射线仍以目标节点作为检测终点来判断是否被环境遮挡，但 AI 只保存射线命中的障碍位置；搜索目的地不会写入墙后玩家实时坐标。
- 搜查阶段只使用最后可见历史和已经生成的固定点位。玩家在墙后改变方向不会让怪物同步转向。
- 远程怪物只有 `_target_is_visible` 为 true 且独立射击线无遮挡时才能开火；丢失确认缓冲和搜查停顿期间都不会隔墙射击。

## 移动与寻路规则

- 目的地中心线无遮挡时优先直线移动，降低不必要的 A* 请求。
- 中心线被墙体或建筑阻断时，使用 GameWorld 的缓存 A* 网格；可见追击允许小范围随机化终点以分散多个敌人，固定搜查点和巡逻点不随机偏移。
- A* 返回空路径或找不到服务时，会等待随机重算间隔后再请求，期间使用局部绕障，避免空路径导致每个物理帧重复寻路。
- 局部绕障按敌人出生时随机生成的左右偏好尝试多个角度；持续有移动意图但位移过小时翻转偏好并清空旧路径。
- 击退速度由移动组件单独叠加和衰减，不会覆盖 AI 本身的追击、搜查或巡逻速度。

## 巡逻路线配置

`patrol_route_path` 默认留空，此时敌人围绕出生点随机游荡。需要固定路线时：

1. 在敌人可访问的节点层级中创建一个路线容器。
2. 在容器下按场景树顺序放置多个 `Marker2D` 或其他 `Node2D` 子节点。
3. 将敌人的 `patrol_route_path` 指向该容器。
4. `patrol_route_loop = true` 时循环路线；关闭后到达最后一点会停止并待机警戒。

敌人脱战后会选择离当前位置最近的巡逻点返程，不会强制先回到路线第一个点。

## 关键参数

- 感知稳定：`vision_range`、`lose_target_range_multiplier`、`vision_requires_line_of_sight`、`vision_line_of_sight_collision_mask`、`vision_loss_grace_duration`。
- 最后线索：`target_memory_duration`、`target_prediction_time`、`target_prediction_max_distance`、`search_arrive_distance`。
- 区域搜查：`target_search_duration_after_arrival`、`target_search_radius`、`target_search_point_wait_min`、`target_search_point_wait_max`、`search_move_speed_multiplier`。
- 反复规避：`occlusion_break_forget_count`、`occlusion_count_reset_duration`、`lost_search_occlusion_offset`、`lost_search_destination_attempts`。
- 空闲巡逻：`patrol_route_path`、`patrol_route_loop`、`wander_radius`、`wander_speed_multiplier`、`wander_arrive_distance`、`wander_wait_min`、`wander_wait_max`。
- 导航恢复：`avoidance_probe_distance`、`avoidance_angle_step_degrees`、`avoidance_candidate_count`、`pathfinding_enabled`、`pathfinding_cell_size`、`pathfinding_agent_radius`、`path_recalculation_min_interval`、`path_recalculation_max_interval`、`path_destination_refresh_distance`、`path_waypoint_arrive_distance`、`path_random_goal_radius`、`path_max_point_count`、`stuck_detection_time`、`stuck_minimum_movement`。
- 组件挂载：`perception_component_path`、`movement_component_path`。正常使用预制体时保持默认值即可。

检查器参数会在敌人 `_ready()` 时同步到组件。运行时脚本动态修改上述 AI 配置后，应调用 `refresh_ai_configuration()` 让两个组件重新读取参数；该操作只刷新配置，不会清除当前目标记忆或路径状态。

## 扩展约定

- 新敌人类型优先继承 `BasicMonster` 并覆写 `_update_target_behavior()`，复用 `_get_current_chase_destination()`、`_get_steered_direction_to()` 与 `_should_pause_target_movement()`，不要复制感知状态机。
- 感知组件不应直接调用攻击、动画或移动代码；需要表现反馈时，可监听其 `state_changed(previous_state, current_state)` 信号。
- 移动组件不应读取 `_target` 或玩家组；它只接收宿主传入的目的地和速度，确保巡逻、搜查和其他 NPC 行为都能复用。
- 动态门或可破坏障碍改变通行区域后，需要让 GameWorld 清空导航网格缓存；只清除单个敌人的路径无法更新共享网格中的障碍数据。
