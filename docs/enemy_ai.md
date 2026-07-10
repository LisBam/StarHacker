# 敌人移动、感知与小队战术系统

本文档是敌人 AI 的快速理解入口，统一记录实心墙体视野、情报共享、三层记忆、四段警戒、平面合围、职能分配、伏击、巡逻与寻路规则。修改敌人索敌、战术或移动代码时，应同步校验本文档与 `docs/game_framework.md` 的全局参数索引。

## 架构职责

- `res://scripts/enemies/basic_monster.gd`：敌人聚合入口，维护生命、攻击、个体随机数值、组件配置同步和低耦合能力接口，不直接实现完整感知、战术或寻路算法。
- `res://scripts/components/enemy_perception_component.gd`：负责实心墙体视野射线、最后可见历史、短中长期记忆、卡墙次数和四段警戒状态，不执行攻击或物理移动。
- `res://scripts/components/enemy_tactical_component.gd`：负责同区域队友发现、情报广播、按人数与射程分配职能、生成搜查/卡位/迂回/伏击点，不直接修改感知状态或速度。
- `res://scripts/components/enemy_movement_component.gd`：负责预设巡逻、随机游荡、共享 A* 路径请求、局部绕障、卡住恢复、`move_and_slide()` 和击退，不读取玩家实时位置或小队状态。
- `res://scripts/enemies/ranged_monster.gd`：继承基础怪物，只扩展安全距离、远程能力档案和敌方弹体生成；射击视线复用感知组件的实心墙体规则。
- `res://scripts/game/game_world.gd`：提供缓存 A* 网格、`find_navigation_path()` 和环境障碍矩形。战术组件通过能力接口读取障碍矩形推导墙角，移动组件通过能力接口请求路径，不硬编码关卡节点路径。

`basic_monster.tscn` 与 `ranged_monster.tscn` 显式挂载 `EnemyPerceptionComponent`、`EnemyMovementComponent` 和 `EnemyTacticalComponent`。旧敌人场景缺少组件时，`BasicMonster` 会在运行时补齐对应节点。

## 实心墙体专属视野

- 默认只查询物理层 5，即 `vision_line_of_sight_collision_mask = 16`。
- 命中后还会校验碰撞体是否属于 `solid_wall_group`，默认是 `environment_obstacles`。只有同时满足碰撞掩码和实心墙体分组的对象才能完全阻断视线。
- 射线命中非墙体对象时会把该碰撞体加入排除列表并继续向玩家检测，最多跳过 `line_of_sight_skip_limit` 个对象；装饰、区域触发器和其他地图元素不会误触发视野丢失。
- `vision_loss_grace_duration` 默认 0.2 秒。墙体第一次遮挡时立即禁止近战命中和远程开火，但持续超过缓冲后才正式计入一次卡墙并进入战术搜查。
- 远程射击不再维护第二套遮挡结论，`RangedMonster` 直接复用 `_has_vision_line_of_sight_to_target()`。`line_of_sight_collision_mask` 保留为旧场景兼容参数，当前射击阻挡以基础感知配置为准。
- 如果主动关闭 `vision_requires_line_of_sight`，表示设计者明确允许该敌人忽略墙体视线；正常敌人预制体应保持开启。

## 四段警戒状态

| 状态 | 常量 | 进入条件 | 核心行为 | 离开条件 |
| --- | --- | --- | --- | --- |
| 三级常规警戒 | `IDLE = 0` | 未发现玩家；短期主动搜查结束；卡墙次数达到脱战阈值 | 停止主动合围，返回预设巡逻、出生点游荡或原地待机；长期片区内降低巡逻速度；途经中期热点会短时复查 | 真正看见玩家；或触发中期热点复查 |
| 可见追击 | `VISIBLE = 1` | 玩家在有效视野距离内且没有实心墙体遮挡 | 使用玩家实时坐标固定移速追击；近战贴近攻击，远程维持安全攻击距离 | 墙体持续遮挡超过缓冲；或玩家离开有效视野范围 |
| 一级分区搜查 | `SEARCHING = 2` | 首次或普通次数墙体遮挡；收到同区域队友情报；巡逻途经中期热点 | 按小队职能执行墙体周边三层扇形搜查、近口卡位或外侧绕行 | 重新看见玩家；短期记忆耗尽；次数进入二级封锁或达到脱战阈值 |
| 二级全域封锁 | `BLOCKADE = 3` | 卡墙次数达到 `occlusion_break_forget_count - blockade_loss_margin` 且尚未达到阈值 | 扩大外围半径；远程分散守岔路，近战压住墙体近点；长巷道分段封锁 | 重新看见玩家；达到脱战阈值后转三级常规警戒 |

流转要点：

1. 玩家可见时，感知组件逐物理帧记录最后可见位置和估算速度；战术预测只使用这段可见历史。
2. 任意敌人真正看见玩家后会立即广播 `visible_contact`，并按 `visible_intelligence_broadcast_interval` 定期刷新当前最后可见坐标；墙体确认遮挡后再广播 `occlusion_loss`，附带消失位置、墙体命中点、逃跑方向、估算速度和卡墙次数。
3. 默认 `occlusion_break_forget_count = 3`、`blockade_loss_margin = 1`：第一次遮挡进入一级搜查，第二次进入二级封锁，第三次停止主动搜寻并进入三级常规警戒。
4. 达到阈值不会一次性清空消失坐标、热点和交战片区。短、中、长期记忆按各自生命周期继续生效。
5. 只有玩家连续清晰可见达到 `occlusion_count_reset_duration`，卡墙次数才会清零；短暂露头不会刷新出无限次普通搜查。

## 三层分级记忆

### 短期记忆

- 使用 `target_memory_duration`，默认 30 秒。
- 保存最后可见坐标、实心墙体命中坐标、最后可见估算速度和逃跑方向。
- 一级搜查与二级封锁全过程只使用这些历史数据，不读取墙后玩家实时位置。
- 达到脱战阈值后停止主动移动，但短期数据仍保留到计时结束，可用于玩家再次露头时延续反卡墙判断。

### 中期记忆

- 使用 `medium_memory_duration`，默认 60 秒。
- 墙体命中点与预测逃生点按 `medium_hotspot_merge_distance` 合并，相同墙角或通道会累计 `count` 频次。
- 最多保存 `medium_hotspot_max_count` 项，超过容量时移除频次最低的热点。
- 达到脱战阈值不会清空中期热点。三级常规警戒中的 AI 距离高优先级热点小于 `medium_recheck_trigger_radius` 时，会执行 `medium_recheck_duration` 秒短时复查；`medium_recheck_cooldown` 防止同一点重复转圈。

### 长期记忆

- 保存当前交战片区中心和 `long_term_region_radius`，默认 520 像素。
- 新的战斗采样点仍在当前片区时，中心会缓慢向新位置修正；与旧中心距离超过片区半径 1.8 倍时，视为新的交战片区并覆盖旧片区。
- 短、中期记忆消退后，长期片区仍保留。AI 路过片区时使用 `long_term_alert_patrol_speed_multiplier` 降低巡逻速度并维持高警戒，但不会隔墙重新锁定玩家。

## 区域情报共享

- 每个战术组件把宿主加入 `enemy_tactical_agents` 组。
- 同区域判定使用 `squad_region_radius`，并要求敌人锁定同一个目标实例；区域外敌人不会参与当前小队分工。
- 本地发现与消失情报都使用单调递增版本和稳定 `message_id`。收到 `visible_contact` 的队友会进入一级追踪搜查并前往发送者最后看见的坐标，但不会在自己没有视线时攻击；收到 `occlusion_loss` 时还会同步墙体位置、逃跑方向、全队最高卡墙次数和中期热点。
- 队友收到新消息后会把剩余中继跳数减一，再向自己周围的敌人继续传播。`intelligence_relay_max_hops` 默认 6，因此首尾无法直接通信的敌人也能经中间单位依次发现玩家。
- 每个战术组件缓存最近 256 个已处理 `message_id`。同一消息通过不同邻居返回时会被去重，不会形成广播循环或反复重置搜查目的地。
- 人数与能力档案按 `coordination_update_interval` 定期重算；4 人及以上按 `role_rotation_interval` 轮换同类候选顺序。
- 地图当前没有手工标注“巷道/房间/出口”的语义图。战术组件使用墙体障碍矩形、墙角外推、逃跑方向扇形和共享 A* 可达性动态推导近口、外围岔路与出口候选点，因此新地图无需额外绑定专用节点。

## 小队职能分配

| 在场数量 | 搜查单位 | 卡位单位 | 迂回单位 |
| --- | --- | --- | --- |
| 1 | 唯一职能。近战缩小半径贴墙搜角；远程扩大扇形并保持安全距离 | 不分配 | 不分配，禁止单 AI 远距离绕图 |
| 2~3 | 除迂回单位外全部承担搜查，近战沿墙体近点排查 | 不单独分配 | 固定 1 名；优先选择远程和更长射程，没有远程时选择射程最长者 |
| 4 及以上 | 约占非迂回成员一半，近战优先并在近战内部轮换 | 剩余非迂回成员，远程偏外围、近战偏墙体近口 | 约占全队四分之一且全部来自远程单位；没有远程单位时不会强迫近战执行远距离迂回 |

职能按敌人能力接口判断：

- `is_ranged_tactical_unit()`：是否属于远程战术单位。
- `get_tactical_attack_range()`：分工排序使用的有效攻击射程。
- `get_tactical_preferred_distance()`：远程搜查、卡位和伏击使用的安全距离。

`BasicMonster` 默认返回近战档案；`RangedMonster` 使用 `shoot_range` 和 `keep_distance` 返回远程档案。新增敌人类型只需覆写这些能力接口，不需要修改战术组件。

## 平面合围、分层搜查与伏击

- 搜查以玩家消失点和预测逃跑方向为基准，使用 `tactical_search_near_radius`、`tactical_search_middle_radius`、`tactical_search_far_radius` 依次生成近、中、远三层扇形点。
- 搜查单位的第一个战术点固定为玩家最后发现坐标加受限速度预测，不先选择墙角。玩家快速绕到障碍后或当面进入建筑时，AI 会先通过共享 A* 追过墙体入口、建筑门口或通道，再开始近中远分层排查。
- 近战使用 `melee_search_radius_multiplier` 收缩半径，近层优先选择遮挡墙体四角外推点；远程使用 `ranged_search_radius_multiplier` 扩大覆盖并保持安全距离。
- 同职能单位使用不同左右扇区和职能序号，避免全队扎堆同一拐角。
- 卡位单位沿逃跑方向按 `lane_segment_spacing` 分段占据不同深度，远程站更远且横向覆盖更宽，近战堵墙体近口。
- 迂回单位沿逃跑方向左右约 72 度的墙体外侧生成远端点，再由共享 A* 寻找可走路径；2~3 人优先远程，4 人及以上只允许远程承担。
- 反复卡墙进入二级封锁后，所有外围战术半径乘 `tactical_blockade_radius_multiplier`，形成墙体近点和外围岔路双向封锁。
- 搜查单位完成 `search_points_before_ambush` 个近中远扇区后不再重复转圈。近战选择墙体近拐角静止伏击，远程选择安全距离外的开阔盲区静止伏击。
- 卡位、迂回和伏击单位到达 `tactical_point_arrive_distance` 后停止移动，但感知与攻击继续运行；玩家露头后立即恢复可见追击。
- 战术候选不可达时，组件按 `tactical_destination_attempts` 左右交替旋转并收缩目标；移动组件使用 `is_destination_navigable()` 和 GameWorld 共享 A* 校验远端点。

## 固定移速规则

- 可见追击、一级搜查、二级封锁、卡位接近和外侧迂回统一使用每只敌人出生时确定的固定个体移速 `_get_resolved_move_speed()`。
- AI 不根据玩家疾跑、折返、卡墙次数或逃跑方式临时加速、减速。
- 搜查的谨慎感由分层半径、到点观察停顿和静止驻守实现，不通过追击变速实现。
- `search_move_speed_multiplier` 保留为旧场景兼容参数，当前主动目标行为不再读取该值。
- `long_term_alert_patrol_speed_multiplier` 只影响没有主动目标时的长期片区巡逻，不属于追击变速。

## 移动、寻路与巡逻

- 目的地中心线无遮挡时优先直线移动，减少不必要的 A* 请求。
- 中心线被墙体阻断时使用 GameWorld 缓存 A*；可见追击允许终点小幅随机分散，固定搜查、卡位、迂回和巡逻点不随机漂移。
- A* 返回空路径时等待随机重算间隔并回退局部绕障，不会每个物理帧重复构建路径。
- 局部绕障使用每只敌人的独立左右偏好；持续移动失败会翻转偏好并清空旧路径。
- 击退速度由移动组件独立叠加和衰减，不覆盖 AI 当前固定移动速度。

`patrol_route_path` 留空时，敌人在出生点附近随机游荡。配置路线时，目标节点的直接 `Node2D` 子节点按场景树顺序组成巡逻点；`patrol_route_loop` 控制是否循环。脱战后从离当前位置最近的巡逻点恢复，不强制返回第一点。

## 参数分组

- 实心墙体视野：`vision_range`、`lose_target_range_multiplier`、`vision_requires_line_of_sight`、`vision_line_of_sight_collision_mask`、`vision_loss_grace_duration`、`solid_wall_group`、`line_of_sight_skip_limit`、`visible_intelligence_broadcast_interval`。
- 短期线索与预测：`target_memory_duration`、`target_prediction_time`、`target_prediction_max_distance`、`search_arrive_distance`、`lost_search_occlusion_offset`。
- 中长期记忆：`medium_memory_duration`、`medium_hotspot_merge_distance`、`medium_hotspot_max_count`、`medium_recheck_trigger_radius`、`medium_recheck_duration`、`medium_recheck_cooldown`、`long_term_region_radius`、`long_term_alert_patrol_speed_multiplier`。
- 反卡墙状态：`occlusion_break_forget_count`、`occlusion_count_reset_duration`、`blockade_loss_margin`。
- 小队同步：`squad_region_radius`、`coordination_update_interval`、`intelligence_relay_max_hops`、`role_rotation_interval`。
- 平面战术：`tactical_search_near_radius`、`tactical_search_middle_radius`、`tactical_search_far_radius`、`tactical_blockade_radius_multiplier`、`melee_search_radius_multiplier`、`ranged_search_radius_multiplier`、`search_fan_half_angle_degrees`、`wall_corner_clearance`、`route_prediction_time`、`lane_segment_spacing`、`tactical_point_arrive_distance`、`tactical_point_wait_min`、`tactical_point_wait_max`、`search_points_before_ambush`、`tactical_destination_attempts`。
- 感知兜底搜查：`target_search_duration_after_arrival`、`target_search_radius`、`target_search_point_wait_min`、`target_search_point_wait_max`、`lost_search_destination_attempts`。
- 空闲巡逻：`patrol_route_path`、`patrol_route_loop`、`wander_radius`、`wander_speed_multiplier`、`wander_arrive_distance`、`wander_wait_min`、`wander_wait_max`。
- 导航恢复：`avoidance_probe_distance`、`avoidance_angle_step_degrees`、`avoidance_candidate_count`、`pathfinding_enabled`、`pathfinding_cell_size`、`pathfinding_agent_radius`、`path_recalculation_min_interval`、`path_recalculation_max_interval`、`path_destination_refresh_distance`、`path_waypoint_arrive_distance`、`path_random_goal_radius`、`path_max_point_count`、`stuck_detection_time`、`stuck_minimum_movement`。
- 组件挂载：`perception_component_path`、`movement_component_path`、`tactical_component_path`。

检查器参数在敌人 `_ready()` 时同步到三个组件。运行时动态修改后，应调用 `refresh_ai_configuration()`；该接口只刷新配置，不主动清空当前目标记忆、战术情报或导航状态。

## 扩展约定

- 新敌人优先继承 `BasicMonster`，覆写 `_update_target_behavior()` 和战术能力接口，不复制感知或小队分工状态机。
- 感知组件不得直接调用攻击、动画或移动代码；表现系统可监听 `state_changed(previous_state, current_state)`。
- 战术组件不得读取墙后目标实时坐标；只能使用感知报告和地图障碍/导航能力接口。
- 移动组件不得读取 `_target`、玩家组或小队职能；它只接收目的地、速度和导航验证请求。
- 新的实心视野遮挡物必须位于感知碰撞掩码内并加入 `environment_obstacles`；缺少任一条件都不会完全阻断 AI 视线。
- 动态门或可破坏墙改变通行区域后，需要清空 GameWorld 导航网格缓存与障碍矩形缓存；只清除单个敌人路径无法更新全队共享地图信息。
