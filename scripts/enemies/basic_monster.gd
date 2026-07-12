extends CharacterBody2D
class_name BasicMonster

## 基础怪物维护生命、攻击、移动、视野索敌和近距离攻击。
## GameWorld 负责生成怪物并设置玩家目标，怪物自身不依赖具体关卡结构。
## 感知与移动分别由独立子组件处理，基础怪物作为聚合入口调度组件并保留原有对外接口。

signal health_changed(current_health: float, max_health: float)
signal died

## 战斗爆发特效脚本；默认通过路径预加载，避免怪物脚本依赖 Godot 全局类名缓存解析顺序。
const COMBAT_BURST_EFFECT_SCRIPT: Script = preload("res://scripts/effects/combat_burst_effect.gd")
## 敌人感知组件脚本；默认用于兼容旧场景缺少组件节点时动态补齐，不依赖全局类名解析顺序。
const ENEMY_PERCEPTION_COMPONENT_SCRIPT: Script = preload("res://scripts/components/enemy_perception_component.gd")
## 敌人移动组件脚本；默认用于兼容旧场景缺少组件节点时动态补齐，不依赖全局类名解析顺序。
const ENEMY_MOVEMENT_COMPONENT_SCRIPT: Script = preload("res://scripts/components/enemy_movement_component.gd")
## 敌人战术组件脚本；默认用于兼容旧场景缺少组件节点时动态补齐，只处理本怪物独立搜查与伏击点。
const ENEMY_TACTICAL_COMPONENT_SCRIPT: Script = preload("res://scripts/components/enemy_tactical_component.gd")
## 统一伤害计算器脚本；集中执行攻防和暴击公式。
const COMBAT_DAMAGE_CALCULATOR_SCRIPT: Script = preload("res://scripts/components/combat_damage_calculator.gd")
## 伤害飘字脚本；怪物受伤时在世界坐标生成上浮文本。
const DAMAGE_NUMBER_POPUP_SCRIPT: Script = preload("res://scripts/effects/damage_number_popup.gd")
## AI 空闲状态；默认表示怪物没有玩家记忆，会回到出生点附近巡逻或待机警戒。
const TARGET_AI_STATE_IDLE: int = 0
## AI 可见追击状态；默认表示怪物拥有无遮挡视线，会直接锁定玩家并寻路追击。
const TARGET_AI_STATE_VISIBLE: int = 1
## AI 丢失搜查状态；默认表示玩家被障碍遮挡，怪物只根据最后线索前往遮挡物背后和附近区域搜索。
const TARGET_AI_STATE_SEARCHING: int = 2
## AI 二级扩大搜查状态；默认表示玩家反复卡墙且临近脱战阈值，本怪物扩大自身搜查范围。
const TARGET_AI_STATE_BLOCKADE: int = 3
## 玩家物理层位掩码；固定为第 1 层，用于从怪物碰撞掩码中移除玩家并建立双向碰撞例外。
const PLAYER_PHYSICS_LAYER_MASK: int = 1

## 怪物显示名称；默认“基础怪物”用于内容识别与后续图鉴界面，新怪物场景应填写设计文档中的正式名称。
@export var display_name: String = "基础怪物"
## 最大血量；取值应大于 0，默认 60 用于训练场怪物强度，运行时修改会影响怪物承伤能力。
@export_range(1.0, 9999.0, 1.0, "or_greater") var max_health: float = 60.0
## 当前血量；取值会被限制在 0 到 max_health，默认 60 表示满血生成，运行时修改会影响怪物当前生存状态。
@export_range(0.0, 9999.0, 1.0, "or_greater") var current_health: float = 60.0
## 武器基础掉落概率；取值为 0 到 1，默认 0.03 表示 3%，结算时还会乘该怪物的掉落倍率。
@export_range(0.0, 1.0, 0.001) var weapon_drop_chance: float = 0.03
## 掉落倍率；取值应大于等于 0，默认 1.0 不改变武器、装备、强化石和道具概率，1.5 表示每类概率均变为基础值的 1.5 倍，可在运行时动态修改。
@export_range(0.0, 100.0, 0.05, "or_greater") var drop_multiplier: float = 1.0
## 攻击力；取值建议大于等于 0，默认 12 表示每次近身攻击造成的伤害，运行时修改会影响玩家受击压力。
@export_range(0.0, 9999.0, 1.0, "or_greater") var attack_damage: float = 12.0
## 敌人攻击力；默认 100，与玩家防御 0 组合时保持既有伤害不变，生成属性倍率会同步影响。
@export_range(0.0, 99999.0, 1.0, "or_greater") var attack_power: float = 100.0
## 敌人防御力；默认 0，玩家攻击通过统一公式读取，生成属性倍率会同步影响。
@export_range(0.0, 99999.0, 1.0, "or_greater") var defense_power: float = 0.0
## 韧性；取值为百分比，默认 0 表示不减免控制，1 表示减少 1% 击退效果，100 表示完全免疫击退。
@export_range(0.0, 100.0, 1.0) var toughness: float = 0.0
## 攻击冲击力；取值建议大于等于 0，默认 180 会在命中玩家时造成短距离击退。
@export_range(0.0, 5000.0, 1.0, "or_greater") var attack_impact_force: float = 180.0
## 移动速度；取值建议大于 0，默认 150 像素每秒，运行时修改会影响怪物追击速度。
@export_range(1.0, 2000.0, 1.0, "or_greater") var move_speed: float = 150.0
## 个体移动速度最小倍率；取值建议 0.5 到 1，默认 0.88，让同类怪物移动速度存在下限差异。
@export_range(0.1, 2.0, 0.01) var move_speed_random_multiplier_min: float = 0.88
## 个体移动速度最大倍率；取值建议大于等于最小倍率，默认 1.16，让同类怪物移动速度存在上限差异。
@export_range(0.1, 2.0, 0.01) var move_speed_random_multiplier_max: float = 1.16
## 视野范围；取值建议大于 0，默认 360 像素，玩家进入该范围后怪物开始索敌追击。
@export_range(1.0, 4000.0, 1.0, "or_greater") var vision_range: float = 360.0
## 攻击距离；取值建议大于 0，默认 42 像素，玩家进入该距离后怪物停止移动并尝试攻击。
@export_range(1.0, 400.0, 1.0, "or_greater") var attack_range: float = 42.0
## 攻击冷却；取值应大于 0，默认 0.9 秒，运行时修改会影响怪物连续攻击频率。
@export_range(0.05, 10.0, 0.05) var attack_cooldown: float = 0.9
## 个体攻击冷却最小倍率；取值建议 0.75 到 1，默认 0.9，让近战怪物攻击节奏存在下限差异。
@export_range(0.1, 3.0, 0.01) var attack_cooldown_random_multiplier_min: float = 0.9
## 个体攻击冷却最大倍率；取值建议大于等于最小倍率，默认 1.3，让近战怪物攻击节奏存在上限差异。
@export_range(0.1, 3.0, 0.01) var attack_cooldown_random_multiplier_max: float = 1.3
## 脱战视野倍率；取值建议大于等于 1，默认 1.25 让怪物不会在视野边缘频繁切换索敌状态。
@export_range(1.0, 4.0, 0.05, "or_greater") var lose_target_range_multiplier: float = 1.25
## 索敌是否需要直线视野；默认 true，墙体会阻挡怪物首次发现玩家。
@export var vision_requires_line_of_sight: bool = true
## 索敌视线遮挡检测掩码；默认检测第 5 层环境墙体，修改会影响哪些障碍能阻挡怪物发现玩家。
@export_flags_2d_physics var vision_line_of_sight_collision_mask: int = 16
## 视野丢失确认时间；取值建议 0.1 到 0.4 秒，默认 0.2 秒，运行时修改需调用 refresh_ai_configuration() 同步到感知组件。
@export_range(0.0, 2.0, 0.05) var vision_loss_grace_duration: float = 0.2
## 失去视野后的记忆时间；取值建议大于 0，默认 8 秒，怪物会在这段时间内前往最后看见或推断的玩家位置搜索。
## 战术记忆补充：项目当前默认采用 30 秒短期记忆，原 8 秒说明保留用于追溯旧场景基线。
@export_range(0.0, 120.0, 0.5) var target_memory_duration: float = 30.0
## 搜索到达距离；取值建议大于怪物半径，默认 54 像素，怪物靠近推断位置或当前搜索点后会进入扫荡或切换下一个搜索点。
@export_range(1.0, 512.0, 1.0) var search_arrive_distance: float = 54.0
## 旧隔墙警觉追踪范围倍率；取值建议大于 1，默认 1.85，当前三阶段索敌不会读取墙后玩家实时位置。
## 该值保留为旧场景配置兼容，后续如需警戒范围衰减可复用。
@export_range(1.0, 6.0, 0.05, "or_greater") var hidden_target_tracking_range_multiplier: float = 1.85
## 目标预测时间；取值建议 0 到 2 秒，默认 0.55 会按最近移动趋势把搜索点向玩家移动方向前推。
@export_range(0.0, 5.0, 0.05) var target_prediction_time: float = 0.55
## 目标预测最大距离；取值建议大于等于 0，默认 220 像素，防止高速移动或瞬移导致搜索点偏离过远。
@export_range(0.0, 2000.0, 1.0) var target_prediction_max_distance: float = 220.0
## 到达推断位置后的搜索时间；取值建议大于等于 0，默认 4 秒，怪物会围绕推断位置继续扫荡而不是立刻丢失目标。
@export_range(0.0, 30.0, 0.1) var target_search_duration_after_arrival: float = 4.0
## 到达推断位置后的搜索半径；取值建议大于怪物半径，默认 180 像素，修改会影响怪物在墙后区域的扫荡范围。
@export_range(0.0, 2000.0, 1.0) var target_search_radius: float = 180.0
## 搜查点最短观察时间；取值建议 0 到 1 秒，默认 0.2 秒，运行时修改需调用 refresh_ai_configuration() 同步到感知组件。
@export_range(0.0, 5.0, 0.05) var target_search_point_wait_min: float = 0.2
## 搜查点最长观察时间；取值应大于等于最短时间，默认 0.55 秒，运行时修改需调用 refresh_ai_configuration() 同步到感知组件。
@export_range(0.0, 5.0, 0.05) var target_search_point_wait_max: float = 0.55
## 搜查移动速度倍率；取值建议 0.4 到 1，默认 0.78，让失去目标后的排查速度低于正面追击速度。
@export_range(0.0, 2.0, 0.05) var search_move_speed_multiplier: float = 0.78
## 卡视野脱战次数阈值；取值建议 2 到 5，默认 3，玩家多次依靠障碍遮挡脱离视线后怪物会彻底丢失目标。
@export_range(1, 12, 1) var occlusion_break_forget_count: int = 3
## 卡视野计数恢复时间；取值建议 3 到 15 秒，默认 8 秒，目标持续可见达到该时间后清除旧的规避记录。
@export_range(0.0, 60.0, 0.5) var occlusion_count_reset_duration: float = 8.0
## 遮挡物背后搜查偏移；取值建议接近建筑墙厚或入口宽度，默认 96 像素，用于从视线命中点向玩家消失方向推导搜查锚点。
@export_range(0.0, 600.0, 1.0) var lost_search_occlusion_offset: float = 96.0
## 搜查点选择尝试次数；取值建议 1 到 12，默认 6，用于在搜查锚点周边优先挑选不会直接撞墙的巡逻点。
@export_range(1, 24, 1) var lost_search_destination_attempts: int = 6
## 中期战术记忆时间；默认 60 秒，记录高频墙角和逃生通道，达到脱战阈值后仍保留供巡逻复查。
@export_range(0.0, 300.0, 1.0) var medium_memory_duration: float = 60.0
## 中期热点合并距离；默认 96 像素，相邻墙角记录会合并累计，运行时修改需刷新 AI 配置。
@export_range(1.0, 512.0, 1.0) var medium_hotspot_merge_distance: float = 96.0
## 中期热点最大数量；默认 12，限制单次交战片区保存的高频藏点和逃生路线规模。
@export_range(1, 64, 1) var medium_hotspot_max_count: int = 12
## 中期热点巡逻复查半径；默认 120 像素，三级常规警戒途经热点时主动驻足额外搜查。
@export_range(1.0, 600.0, 1.0) var medium_recheck_trigger_radius: float = 120.0
## 中期热点复查持续时间；默认 3.5 秒，结束后恢复预设巡逻或原地待机。
@export_range(0.0, 30.0, 0.1) var medium_recheck_duration: float = 3.5
## 中期热点复查冷却；默认 8 秒，避免同一 AI 在一个墙角反复转圈搜查。
@export_range(0.0, 60.0, 0.5) var medium_recheck_cooldown: float = 8.0
## 长期交战片区半径；默认 520 像素，短中期记忆消退后路过该片区仍降低巡逻速度并保持高警戒。
@export_range(1.0, 3000.0, 1.0) var long_term_region_radius: float = 520.0
## 长期警戒巡逻速度倍率；默认 0.72，只影响无主动目标时的巡逻，不改变追击和战术搜查固定移速。
@export_range(0.0, 1.0, 0.05) var long_term_alert_patrol_speed_multiplier: float = 0.72
## 二级封锁提前量；默认 1，卡墙次数距离脱战阈值剩余一次时进入全域封锁。
@export_range(0, 6, 1) var blockade_loss_margin: int = 1
## 实心墙体分组；默认 environment_obstacles，只有该组地图碰撞体能够完全阻断 AI 视线。
@export var solid_wall_group: StringName = &"environment_obstacles"
## 非墙体碰撞跳过上限；默认 12，视线射线会跳过其他地图元素并继续检测后方实心墙。
@export_range(1, 64, 1) var line_of_sight_skip_limit: int = 12
## 可见线索刷新间隔；默认 0.45 秒，持续看见玩家时只刷新本怪物内部最后可见坐标，不会通知其他怪物。
@export_range(0.05, 5.0, 0.05) var visible_intelligence_broadcast_interval: float = 0.45
## 近层搜查半径；默认 88 像素，近战 AI 用于贴墙排查拐角和房间近角。
@export_range(1.0, 1000.0, 1.0) var tactical_search_near_radius: float = 88.0
## 中层搜查半径；默认 176 像素，用于第二层扇形排查和近端路口封锁。
@export_range(1.0, 1600.0, 1.0) var tactical_search_middle_radius: float = 176.0
## 远层搜查半径；默认 320 像素，远程 AI 用于覆盖外围岔路和开阔盲区。
@export_range(1.0, 2400.0, 1.0) var tactical_search_far_radius: float = 320.0
## 二级封锁范围倍率；默认 1.4，临近脱战阈值时扩大墙体外围与逃生岔路覆盖。
@export_range(1.0, 3.0, 0.05) var tactical_blockade_radius_multiplier: float = 1.4
## 近战搜查半径倍率；默认 0.78，让近战 AI 更贴近墙体而不执行过远迂回。
@export_range(0.1, 2.0, 0.05) var melee_search_radius_multiplier: float = 0.78
## 远程搜查半径倍率；默认 1.25，让远程 AI 保持安全距离并扩大扇形覆盖。
@export_range(0.1, 3.0, 0.05) var ranged_search_radius_multiplier: float = 1.25
## 扇形搜查半角；默认 72 度，以玩家消失前移动方向为中心向两侧分层排查。
@export_range(1.0, 179.0, 1.0) var search_fan_half_angle_degrees: float = 72.0
## 墙角站位净距；默认 44 像素，防止近战搜查与伏击点落入实心墙体内部。
@export_range(0.0, 256.0, 1.0) var wall_corner_clearance: float = 44.0
## 逃跑路线预测时间；默认 1.15 秒，只使用玩家最后可见速度预判近道和出口，不读取墙后实时位置。
@export_range(0.0, 5.0, 0.05) var route_prediction_time: float = 1.15
## 长巷道分段封锁间距；默认 164 像素，多名卡位 AI 会沿路线占据不同深度路口。
@export_range(1.0, 1000.0, 1.0) var lane_segment_spacing: float = 164.0
## 战术点到达距离；默认 42 像素，搜查单位到点观察，卡位与迂回单位到点静止驻守。
@export_range(1.0, 256.0, 1.0) var tactical_point_arrive_distance: float = 42.0
## 战术点最短观察时间；默认 0.35 秒，用于错开单位逐点排查节奏。
@export_range(0.0, 5.0, 0.05) var tactical_point_wait_min: float = 0.35
## 战术点最长观察时间；默认 0.85 秒，每只 AI 独立随机以避免全队同步移动。
@export_range(0.0, 5.0, 0.05) var tactical_point_wait_max: float = 0.85
## 完整搜查点数量；默认 6，覆盖近中远三层左右扇区后转为差异化墙角伏击。
@export_range(1, 24, 1) var search_points_before_ambush: int = 6
## 战术候选尝试次数；默认 8，不可达时旋转并收缩候选点寻找替代岔路或出口。
@export_range(1, 24, 1) var tactical_destination_attempts: int = 8
## 游荡半径；取值建议大于等于 0，默认 180 表示怪物无目标时围绕出生点小范围移动，修改会影响巡游范围。
@export_range(0.0, 2000.0, 1.0) var wander_radius: float = 180.0
## 游荡速度倍率；取值建议 0 到 1，默认 0.35 表示无目标时慢速移动，修改会影响游荡节奏。
@export_range(0.0, 2.0, 0.05) var wander_speed_multiplier: float = 0.35
## 游荡到点距离；取值建议大于 0，默认 12 像素，怪物距离目标点小于该值时会进入等待并重新选点。
@export_range(1.0, 120.0, 1.0) var wander_arrive_distance: float = 12.0
## 游荡最短等待时间；取值建议大于等于 0，默认 0.6 秒，修改会影响怪物到点后的停顿下限。
@export_range(0.0, 10.0, 0.05) var wander_wait_min: float = 0.6
## 游荡最长等待时间；取值应大于等于最短等待时间，默认 1.8 秒，修改会影响怪物到点后的停顿上限。
@export_range(0.0, 10.0, 0.05) var wander_wait_max: float = 1.8
## 预设巡逻路线节点路径；默认留空使用出生点随机游荡，可指向包含多个 Marker2D 子节点的路线容器。
@export var patrol_route_path: NodePath
## 预设巡逻路线是否循环；默认 true，到达最后一个巡逻点后返回第一个点，关闭后会在终点待机警戒。
@export var patrol_route_loop: bool = true
## 绕障检测距离；取值建议大于怪物半径，默认 56 像素，修改会影响怪物提前绕开墙体的距离。
@export_range(1.0, 400.0, 1.0, "or_greater") var avoidance_probe_distance: float = 56.0
## 绕障候选角度步长；取值建议 5 到 45 度，默认 22.5 度，修改会影响怪物寻找绕行方向的细腻程度。
@export_range(1.0, 90.0, 0.5) var avoidance_angle_step_degrees: float = 22.5
## 单侧绕障候选数量；取值建议 1 到 8，默认 4，修改会影响怪物绕障能力和每帧检测开销。
@export_range(1, 12, 1) var avoidance_candidate_count: int = 4
## 是否启用网格寻路；默认 true，直线被障碍阻挡时会向 GameWorld 请求 A* 路径。
@export var pathfinding_enabled: bool = true
## 寻路格子尺寸；取值建议 24 到 96，默认 32 可识别建筑入口，越小路径越细但计算开销越高。
@export_range(16.0, 512.0, 1.0, "or_greater") var pathfinding_cell_size: float = 32.0
## 寻路代理半径；取值建议接近怪物碰撞半径，默认 18 匹配当前怪物圆形碰撞体并保留入口通行能力。
@export_range(0.0, 256.0, 1.0) var pathfinding_agent_radius: float = 18.0
## 路径重算最短间隔；取值建议大于 0，默认 0.55 秒，修改会影响怪物对移动目标的响应频率。
@export_range(0.05, 5.0, 0.05) var path_recalculation_min_interval: float = 0.55
## 路径重算最长间隔；取值应大于等于最短间隔，默认 1.1 秒，怪物会在区间内随机取值以错开路径更新。
@export_range(0.05, 5.0, 0.05) var path_recalculation_max_interval: float = 1.1
## 路径目标刷新距离；取值建议大于 0，默认 64，目标移动超过该距离会触发重新寻路。
@export_range(1.0, 1024.0, 1.0, "or_greater") var path_destination_refresh_distance: float = 64.0
## 路点到达距离；取值建议略大于怪物半径，默认 28，修改会影响怪物切换到下一个路点的时机。
@export_range(1.0, 256.0, 1.0) var path_waypoint_arrive_distance: float = 28.0
## 路径目标随机半径；取值建议 0 到 64，默认 18，只在目标可见时轻微分散怪物终点。
@export_range(0.0, 512.0, 1.0) var path_random_goal_radius: float = 18.0
## 单次路径最大路点数；取值建议 8 到 160，默认 96，修改会影响远距离寻路缓存长度。
@export_range(1, 256, 1) var path_max_point_count: int = 96
## 卡住判定时间；取值建议 0.3 到 1.2 秒，默认 0.75，避免正常转角减速被误判为卡住。
@export_range(0.05, 5.0, 0.05) var stuck_detection_time: float = 0.75
## 卡住判定最小位移；取值建议 0 到 4 像素，默认 0.35，低于该帧位移会累计卡住时间。
@export_range(0.0, 16.0, 0.05) var stuck_minimum_movement: float = 0.35
## 击退速度衰减；取值建议大于 0，默认 1600 像素每秒平方，修改会影响怪物受击后滑退持续时间。
@export_range(1.0, 12000.0, 1.0, "or_greater") var knockback_decay: float = 1600.0
## 感知组件节点路径；默认指向同级子节点 EnemyPerceptionComponent，运行时无需动态修改。
@export var perception_component_path: NodePath = NodePath("EnemyPerceptionComponent")
## 移动组件节点路径；默认指向同级子节点 EnemyMovementComponent，运行时无需动态修改。
@export var movement_component_path: NodePath = NodePath("EnemyMovementComponent")
## 战术组件节点路径；默认指向同级子节点 EnemyTacticalComponent，运行时无需动态修改。
@export var tactical_component_path: NodePath = NodePath("EnemyTacticalComponent")
## AI 决策更新间隔；默认 0.1 秒让感知、射线、绕障和寻路以 10Hz 错峰运行，物理移动仍逐帧保持平滑。
@export_range(0.016, 0.5, 0.001) var ai_update_interval: float = 0.1
## 休眠时是否隐藏怪物视觉；默认 true，远距离未加载区域不绘制怪物以减少渲染提交。
@export var hide_when_simulation_inactive: bool = true
## 休眠时是否关闭怪物碰撞；默认 true，远距离节点不进入物理宽相检测，靠近玩家前会由加载管理器恢复。
@export var disable_collision_when_simulation_inactive: bool = true
## 怪物受击特效颜色；默认橙红色，修改会影响怪物被命中时的爆发反馈。
@export var hit_effect_color: Color = Color(1.0, 0.45, 0.28, 0.95)
## 怪物死亡特效颜色；默认亮橙色，修改会影响怪物死亡时的爆发反馈。
@export var death_effect_color: Color = Color(1.0, 0.82, 0.34, 1.0)

## 当前追击目标；取值为 Node2D 或 null，默认由 GameWorld 设置，修改会影响怪物追击和攻击对象。
var _target: Node2D
## 当前是否已锁定目标；取值为 true/false，默认 false，修改会影响怪物是否追击视野内玩家。
var _has_target: bool = false
## 当前目标是否处于可见状态；取值为 true/false，默认 false，墙体遮挡时会变为 false。
var _target_is_visible: bool = false
## 当前 AI 索敌状态；取值为 TARGET_AI_STATE_* 常量，默认空闲状态用于区分可见追击和丢失搜查。
var _target_ai_state: int = TARGET_AI_STATE_IDLE
## 当前攻击冷却剩余时间；取值大于等于 0，默认 0 表示可立即攻击，修改会影响下次攻击时机。
var _attack_cooldown_remaining: float = 0.0
## 个体移动速度倍率；取值由出生时随机生成，默认 1 表示不改变检查器中的基础速度。
var _move_speed_multiplier: float = 1.0
## 个体攻击冷却倍率；取值由出生时随机生成，默认 1 表示不改变检查器中的基础冷却。
var _attack_cooldown_multiplier: float = 1.0
## 怪物局部随机数生成器；默认每只怪物独立随机化，修改会影响游荡点和等待时间。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 感知组件实例；取值为 Node 或 null，默认从 perception_component_path 获取，负责索敌状态和记忆。
var _perception_component: Node
## 移动组件实例；取值为 Node 或 null，默认从 movement_component_path 获取，负责寻路、巡逻、绕障和击退。
var _movement_component: Node
## 战术组件实例；取值为 Node 或 null，默认从 tactical_component_path 获取，负责本怪物独立搜查和伏击点。
var _tactical_component: Node
## 出生尺寸倍率；取值通常为 0.7 到 1.3，默认 1，供调试和其他系统读取本敌人的体型波动。
var _spawn_size_multiplier: float = 1.0
## 出生属性倍率；取值通常为 0.7 到 1.3，默认 1，统一作用于生命、伤害、移速、攻击距离和攻击节奏。
var _spawn_attribute_multiplier: float = 1.0
## AI 决策剩余时间；默认 0 表示首次物理帧立即决策，ready 后会随机错峰避免所有怪物同帧射线和寻路。
var _ai_update_remaining: float = 0.0
## AI 决策累计时间；默认 0，低频更新时累加真实经过时间供记忆、冷却和巡逻计时使用。
var _ai_accumulated_delta: float = 0.0
## 当前模拟是否激活；默认 true，远距离休眠后关闭物理处理，重新进入加载范围时恢复。
var _simulation_active: bool = true
## 怪物碰撞形状缓存；默认由 ready 收集所有后代 CollisionShape2D，休眠切换时统一启用或禁用。
var _collision_shapes: Array[CollisionShape2D] = []


func apply_spawn_variation(size_multiplier: float, attribute_multiplier: float) -> void:
	_spawn_size_multiplier = maxf(size_multiplier, 0.1)
	_spawn_attribute_multiplier = maxf(attribute_multiplier, 0.1)
	scale *= Vector2(_spawn_size_multiplier, _spawn_size_multiplier)
	max_health *= _spawn_attribute_multiplier
	current_health = max_health
	attack_damage *= _spawn_attribute_multiplier
	attack_power *= _spawn_attribute_multiplier
	defense_power *= _spawn_attribute_multiplier
	attack_impact_force *= _spawn_attribute_multiplier
	move_speed *= _spawn_attribute_multiplier
	vision_range *= _spawn_attribute_multiplier
	attack_range *= _spawn_size_multiplier
	attack_cooldown /= _spawn_attribute_multiplier
	if is_inside_tree():
		refresh_ai_configuration()
		health_changed.emit(current_health, max_health)


func _ready() -> void:
	# 怪物实体碰撞只保留环境层；即使旧场景或运行时生成路径仍包含玩家层，也会在进入场景树时统一清除。
	collision_mask &= ~PLAYER_PHYSICS_LAYER_MASK
	current_health = clampf(current_health, 0.0, max_health)
	_random.randomize()
	_randomize_individual_behavior()
	_resolve_ai_components()
	refresh_ai_configuration()
	_cache_collision_shapes()
	_ai_update_remaining = _random.randf_range(0.0, maxf(ai_update_interval, 0.016))
	health_changed.emit(current_health, max_health)


func _exit_tree() -> void:
	# 怪物卸载或死亡释放前同步清除玩家侧例外，避免虚拟人口反复实例化后留下失效物理 RID。
	_remove_target_collision_exception(_target)


func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	_ai_accumulated_delta += delta
	_ai_update_remaining = maxf(_ai_update_remaining - delta, 0.0)
	if _ai_update_remaining <= 0.0:
		# 本次 AI 时间步长；取值为两次决策之间累计的真实时间，保证低频更新不会缩短记忆与等待计时。
		var ai_delta: float = maxf(_ai_accumulated_delta, delta)
		_ai_accumulated_delta = 0.0
		_ai_update_remaining = maxf(ai_update_interval, 0.016)
		_update_ai_decision(ai_delta)
	_move_with_external_velocity(delta)


func _update_ai_decision(delta: float) -> void:
	if _movement_component != null:
		_movement_component.call("update", delta)
	if _perception_component != null:
		_perception_component.call("update", delta)
	_sync_perception_state()
	if _tactical_component != null:
		_tactical_component.call("update", delta)

	if not _has_target:
		_update_wander(delta)
		return

	# 目标距离；取值为当前怪物到玩家的距离，默认每帧计算，修改会影响索敌、追击和攻击判定。
	var target_distance: float = global_position.distance_to(_target.global_position) if is_instance_valid(_target) else INF
	_update_target_behavior(delta, target_distance)


func set_simulation_active(active: bool) -> void:
	if _simulation_active == active:
		return
	_simulation_active = active
	set_physics_process(active)
	if hide_when_simulation_inactive:
		visible = active
	if disable_collision_when_simulation_inactive:
		# 碰撞形状遍历项；取值为 ready 缓存的有效形状，使用 deferred 避免物理查询期间直接改状态。
		for collision_shape in _collision_shapes:
			if is_instance_valid(collision_shape):
				collision_shape.set_deferred("disabled", not active)
	if active:
		_ai_update_remaining = 0.0
		_ai_accumulated_delta = 0.0
	else:
		velocity = Vector2.ZERO
		_clear_navigation_path()


func is_simulation_active() -> bool:
	return _simulation_active


func _cache_collision_shapes() -> void:
	_collision_shapes.clear()
	# 后代节点列表；取值为怪物全部子孙节点，默认只缓存 CollisionShape2D 供休眠时切换。
	var descendant_nodes: Array[Node] = find_children("*", "CollisionShape2D", true, false)
	# 后代节点遍历项；取值可能为其他 Node 类型，经过类型校验后加入强类型缓存。
	for descendant_node in descendant_nodes:
		if descendant_node is CollisionShape2D:
			_collision_shapes.append(descendant_node as CollisionShape2D)


func set_target(target_node: Node) -> void:
	_remove_target_collision_exception(_target)
	_target = target_node as Node2D
	_add_target_collision_exception(_target)
	if _movement_component != null:
		_movement_component.call("set_spawn_position", global_position)
	if _perception_component != null:
		_perception_component.call("set_target", target_node)
	if _tactical_component != null:
		_tactical_component.call("reset_intelligence")
	_sync_perception_state()
	_clear_navigation_path()


func _add_target_collision_exception(target_node: Node) -> void:
	if not (target_node is PhysicsBody2D):
		return
	add_collision_exception_with(target_node)
	(target_node as PhysicsBody2D).add_collision_exception_with(self)


func _remove_target_collision_exception(target_node: Node) -> void:
	if not is_instance_valid(target_node) or not (target_node is PhysicsBody2D):
		return
	remove_collision_exception_with(target_node)
	(target_node as PhysicsBody2D).remove_collision_exception_with(self)


func refresh_ai_configuration() -> void:
	if _perception_component != null:
		_perception_component.call("apply_configuration", _build_perception_configuration())
	if _movement_component != null:
		_movement_component.call("apply_configuration", _build_movement_configuration())
	if _tactical_component != null:
		_tactical_component.call("apply_configuration", _build_tactical_configuration())


func _resolve_ai_components() -> void:
	_perception_component = _resolve_or_create_component(perception_component_path, ENEMY_PERCEPTION_COMPONENT_SCRIPT, "EnemyPerceptionComponent")
	_movement_component = _resolve_or_create_component(movement_component_path, ENEMY_MOVEMENT_COMPONENT_SCRIPT, "EnemyMovementComponent")
	_tactical_component = _resolve_or_create_component(tactical_component_path, ENEMY_TACTICAL_COMPONENT_SCRIPT, "EnemyTacticalComponent")
	if _movement_component != null:
		_movement_component.call("initialize", self, _random)
	if _perception_component != null:
		# 搜查点验证回调；取值为移动组件的即时可行性检查，默认缺少移动组件时不执行候选过滤。
		var destination_validator: Callable = Callable(_movement_component, "is_destination_immediately_reachable") if _movement_component != null else Callable()
		_perception_component.call("initialize", self, _random, destination_validator)
	if _tactical_component != null:
		_tactical_component.call("initialize", self, _perception_component, _movement_component, _random)


func _resolve_or_create_component(component_path: NodePath, component_script: Script, fallback_name: String) -> Node:
	# 场景中配置的组件；取值为 Node 或 null，默认优先复用预制体显式挂载的组件节点。
	var configured_component: Node = get_node_or_null(component_path) if not component_path.is_empty() else null
	if configured_component != null:
		return configured_component

	# 兼容组件实例；取值由预加载脚本创建，默认仅在旧场景尚未挂载组件节点时动态补齐。
	var fallback_component: Node = component_script.new() as Node
	if fallback_component != null:
		fallback_component.name = fallback_name
		add_child(fallback_component)
	return fallback_component


func _build_perception_configuration() -> Dictionary:
	return {
		"vision_range": vision_range,
		"lose_target_range_multiplier": lose_target_range_multiplier,
		"vision_requires_line_of_sight": vision_requires_line_of_sight,
		"vision_line_of_sight_collision_mask": vision_line_of_sight_collision_mask,
		"vision_loss_grace_duration": vision_loss_grace_duration,
		"target_memory_duration": target_memory_duration,
		"search_arrive_distance": search_arrive_distance,
		"target_prediction_time": target_prediction_time,
		"target_prediction_max_distance": target_prediction_max_distance,
		"target_search_duration_after_arrival": target_search_duration_after_arrival,
		"target_search_radius": target_search_radius,
		"target_search_point_wait_min": target_search_point_wait_min,
		"target_search_point_wait_max": target_search_point_wait_max,
		"occlusion_break_forget_count": occlusion_break_forget_count,
		"occlusion_count_reset_duration": occlusion_count_reset_duration,
		"lost_search_occlusion_offset": lost_search_occlusion_offset,
		"lost_search_destination_attempts": lost_search_destination_attempts,
		"medium_memory_duration": medium_memory_duration,
		"medium_hotspot_merge_distance": medium_hotspot_merge_distance,
		"medium_hotspot_max_count": medium_hotspot_max_count,
		"medium_recheck_trigger_radius": medium_recheck_trigger_radius,
		"medium_recheck_duration": medium_recheck_duration,
		"medium_recheck_cooldown": medium_recheck_cooldown,
		"long_term_region_radius": long_term_region_radius,
		"blockade_loss_margin": blockade_loss_margin,
		"solid_wall_group": solid_wall_group,
		"line_of_sight_skip_limit": line_of_sight_skip_limit,
		"visible_intelligence_broadcast_interval": visible_intelligence_broadcast_interval
	}


func _build_movement_configuration() -> Dictionary:
	return {
		"wander_radius": wander_radius,
		"wander_speed_multiplier": wander_speed_multiplier,
		"wander_arrive_distance": wander_arrive_distance,
		"wander_wait_min": wander_wait_min,
		"wander_wait_max": wander_wait_max,
		"patrol_route_path": patrol_route_path,
		"patrol_route_loop": patrol_route_loop,
		"avoidance_probe_distance": avoidance_probe_distance,
		"avoidance_angle_step_degrees": avoidance_angle_step_degrees,
		"avoidance_candidate_count": avoidance_candidate_count,
		"pathfinding_enabled": pathfinding_enabled,
		"pathfinding_cell_size": pathfinding_cell_size,
		"pathfinding_agent_radius": pathfinding_agent_radius,
		"path_recalculation_min_interval": path_recalculation_min_interval,
		"path_recalculation_max_interval": path_recalculation_max_interval,
		"path_destination_refresh_distance": path_destination_refresh_distance,
		"path_waypoint_arrive_distance": path_waypoint_arrive_distance,
		"path_random_goal_radius": path_random_goal_radius,
		"path_max_point_count": path_max_point_count,
		"stuck_detection_time": stuck_detection_time,
		"stuck_minimum_movement": stuck_minimum_movement,
		"knockback_decay": knockback_decay,
		"obstacle_collision_mask": vision_line_of_sight_collision_mask
	}


func _build_tactical_configuration() -> Dictionary:
	return {
		"search_near_radius": tactical_search_near_radius,
		"search_middle_radius": tactical_search_middle_radius,
		"search_far_radius": tactical_search_far_radius,
		"blockade_radius_multiplier": tactical_blockade_radius_multiplier,
		"melee_search_radius_multiplier": melee_search_radius_multiplier,
		"ranged_search_radius_multiplier": ranged_search_radius_multiplier,
		"search_fan_half_angle_degrees": search_fan_half_angle_degrees,
		"wall_corner_clearance": wall_corner_clearance,
		"route_prediction_time": route_prediction_time,
		"lane_segment_spacing": lane_segment_spacing,
		"tactical_point_arrive_distance": tactical_point_arrive_distance,
		"tactical_point_wait_min": tactical_point_wait_min,
		"tactical_point_wait_max": tactical_point_wait_max,
		"search_points_before_ambush": search_points_before_ambush,
		"tactical_destination_attempts": tactical_destination_attempts,
		"obstacle_collision_mask": vision_line_of_sight_collision_mask,
		"solid_wall_group": solid_wall_group
	}


func _sync_perception_state() -> void:
	if _perception_component == null:
		_has_target = false
		_target_is_visible = false
		_target_ai_state = TARGET_AI_STATE_IDLE
		return

	# 同步前的索敌状态；取值用于识别追击、搜查和巡逻之间的状态切换并清理旧路径。
	var previous_ai_state: int = _target_ai_state
	_has_target = bool(_perception_component.call("has_target"))
	_target_is_visible = bool(_perception_component.call("is_target_visible"))
	_target_ai_state = int(_perception_component.call("get_ai_state"))
	if previous_ai_state == _target_ai_state:
		return

	_clear_navigation_path()
	if _target_ai_state == TARGET_AI_STATE_IDLE and _movement_component != null:
		_movement_component.call("reset_idle_movement")


func _randomize_individual_behavior() -> void:
	_move_speed_multiplier = _get_randomized_multiplier(move_speed_random_multiplier_min, move_speed_random_multiplier_max)
	_attack_cooldown_multiplier = _get_randomized_multiplier(attack_cooldown_random_multiplier_min, attack_cooldown_random_multiplier_max)
	_attack_cooldown_remaining = _random.randf_range(0.0, _get_resolved_attack_cooldown())


func _get_randomized_multiplier(minimum_multiplier: float, maximum_multiplier: float) -> float:
	# 标准化最小倍率；取值至少为 0.1，默认防止速度或冷却被随机到 0。
	var resolved_minimum: float = maxf(minf(minimum_multiplier, maximum_multiplier), 0.1)
	# 标准化最大倍率；取值至少为最小倍率，默认防止检查器中上下限反填导致随机范围错误。
	var resolved_maximum: float = maxf(maxf(minimum_multiplier, maximum_multiplier), resolved_minimum)
	return _random.randf_range(resolved_minimum, resolved_maximum)


func _get_resolved_move_speed() -> float:
	return maxf(move_speed, 0.0) * maxf(_move_speed_multiplier, 0.1)


func _get_resolved_attack_cooldown() -> float:
	return maxf(attack_cooldown, 0.05) * maxf(_attack_cooldown_multiplier, 0.1)


func apply_damage(damage: float, source: Node) -> void:
	if damage <= 0.0 or current_health <= 0.0:
		return

	# 伤害结算结果；旧来源缺少接口时使用 100 攻击、0% 暴击和 150% 暴伤。
	var damage_result: Dictionary = COMBAT_DAMAGE_CALCULATOR_SCRIPT.calculate_damage(damage, _get_source_combat_value(source, "get_attack_power", 100.0), defense_power, _get_source_combat_value(source, "get_critical_chance", 0.0), _get_source_combat_value(source, "get_critical_damage_multiplier", 1.5))
	# 最终伤害；生命与飘字统一使用同一个整数结果。
	var final_damage: float = float(damage_result.get("damage", 0))
	current_health = clampf(current_health - final_damage, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	DAMAGE_NUMBER_POPUP_SCRIPT.spawn_damage_number(get_tree().current_scene, global_position, final_damage, bool(damage_result.get("is_critical", false)))
	_apply_knockback_from_source(source)
	if current_health <= 0.0:
		_spawn_death_effect()
		died.emit()
		queue_free()
	else:
		_spawn_hit_effect()


func get_attack_power() -> float:
	return maxf(attack_power, 0.0)


func get_critical_chance() -> float:
	return 0.0


func get_critical_damage_multiplier() -> float:
	return 1.5


func _get_source_combat_value(source: Node, method_name: String, fallback_value: float) -> float:
	return float(source.call(method_name)) if source != null and source.has_method(method_name) else fallback_value


func _try_attack_target() -> void:
	if _attack_cooldown_remaining > 0.0 or not is_instance_valid(_target):
		return

	if _target.has_method("apply_damage"):
		_target.call("apply_damage", attack_damage, self)

	_attack_cooldown_remaining = _get_resolved_attack_cooldown()


func _has_vision_line_of_sight_to_target() -> bool:
	if _perception_component == null:
		return false

	return bool(_perception_component.call("has_vision_line_of_sight_to_target"))


func _get_vision_line_of_sight_hit() -> Dictionary:
	if _perception_component == null:
		# 空命中结果；取值为空字典，默认表示没有可记录的环境遮挡点。
		var empty_hit_result: Dictionary = {}
		return empty_hit_result

	# 组件视线命中结果；取值为空字典或包含环境碰撞信息，默认供继承怪物复用同一感知规则。
	var raw_hit_result: Variant = _perception_component.call("get_vision_line_of_sight_hit")
	return raw_hit_result if raw_hit_result is Dictionary else {}


func _can_track_hidden_target(_target_distance: float) -> bool:
	# 当前三阶段索敌不允许隔墙读取玩家实时位置；该兼容函数固定返回 false，避免旧调用恢复无脑追踪。
	return false


func _track_hidden_target_position(_delta: float) -> void:
	# 当前三阶段索敌不再写入墙后玩家实时坐标；失去视野后必须通过 _begin_lost_target_search 进入搜查。
	# 实际状态切换现由感知组件内部执行，该兼容入口继续保持只读空实现。
	return


func _get_current_chase_destination() -> Vector2:
	if _perception_component == null:
		return global_position

	# 感知组件提供的目标点；取值为玩家实时位置、最后线索、遮挡物背后锚点或区域搜查点。
	var raw_destination: Variant = _perception_component.call("get_current_chase_destination")
	# 感知兜底目标点；取值为合法 Vector2 或宿主当前位置，战术组件可在丢失状态下替换为分工点位。
	var fallback_destination: Vector2 = raw_destination if raw_destination is Vector2 else global_position
	if _tactical_component == null:
		return fallback_destination

	# 战术组件目标点；取值为墙角搜查、岔路卡位、外侧迂回或伏击坐标，异常时回退感知目标。
	var raw_tactical_destination: Variant = _tactical_component.call("get_tactical_destination", fallback_destination)
	return raw_tactical_destination if raw_tactical_destination is Vector2 else fallback_destination


func _should_pause_target_movement() -> bool:
	# 感知观察暂停；默认用于普通搜查点短暂停留。
	var perception_pause: bool = _perception_component != null and bool(_perception_component.call("is_movement_paused"))
	# 战术驻守暂停；默认用于卡位、迂回到点和完整搜查后的静止伏击。
	var tactical_pause: bool = _tactical_component != null and bool(_tactical_component.call("should_pause_movement"))
	return perception_pause or tactical_pause


func _update_target_behavior(_delta: float, target_distance: float) -> void:
	if _target_is_visible and target_distance <= attack_range:
		velocity = Vector2.ZERO
		_try_attack_target()
		return

	if _should_pause_target_movement():
		velocity = Vector2.ZERO
		return

	# 当前追击目标点；取值为可见玩家位置或最后可见位置，默认用于失去视野后的搜索移动。
	var chase_destination: Vector2 = _get_current_chase_destination()
	# 追击方向；取值为绕障后的单位向量，默认用于设置本帧速度。
	var chase_direction: Vector2 = _get_steered_direction_to(chase_destination)
	# 当前状态速度倍率；取值为 1 或搜查倍率，默认让谨慎搜查慢于正面追击。
	## 战术补充：所有主动追击、搜查、卡位和迂回统一使用固定个体移速，谨慎感由观察停顿而非追击变速实现。
	var state_speed_multiplier: float = 1.0
	velocity = chase_direction * _get_resolved_move_speed() * state_speed_multiplier


func _update_wander(delta: float) -> void:
	if _movement_component == null:
		velocity = Vector2.ZERO
		return

	# 空闲移动速度；取值来自预设巡逻路线或出生点随机游荡，默认由移动组件统一处理绕障。
	var raw_idle_velocity: Variant = _movement_component.call("get_idle_velocity", delta, _get_resolved_move_speed())
	velocity = raw_idle_velocity if raw_idle_velocity is Vector2 else Vector2.ZERO
	if _perception_component != null and bool(_perception_component.call("is_in_long_term_alert_region")):
		velocity *= clampf(long_term_alert_patrol_speed_multiplier, 0.0, 1.0)


func apply_knockback(direction: Vector2, force: float) -> void:
	if direction.is_zero_approx() or force <= 0.0:
		return

	# 韧性减免比例；取值为 0 到 1，默认由 toughness 百分比换算。
	var toughness_reduction: float = clampf(toughness, 0.0, 100.0) * 0.01
	# 实际击退力度；取值为原始力度按韧性减免后的结果，默认用于写入外部速度。
	var resolved_force: float = maxf(force * (1.0 - toughness_reduction), 0.0)
	if resolved_force <= 0.0 or _movement_component == null:
		return

	_movement_component.call("apply_knockback", direction, resolved_force)


func get_impact_force() -> float:
	return maxf(attack_impact_force, 0.0)


func get_knockback_direction() -> Vector2:
	if is_instance_valid(_target):
		# 指向目标方向；取值为怪物到当前目标的单位向量，默认用于近战命中玩家后的击退方向。
		var target_direction: Vector2 = _target.global_position - global_position
		if not target_direction.is_zero_approx():
			return target_direction.normalized()

	if not velocity.is_zero_approx():
		return velocity.normalized()

	return Vector2.RIGHT


func _apply_knockback_from_source(source: Node) -> void:
	if source == null:
		return

	# 来源冲击力；取值来自 source.get_impact_force()，默认 0 表示不击退怪物。
	var impact_force: float = _get_source_impact_force(source)
	if impact_force <= 0.0:
		return

	# 来源击退方向；取值优先来自 source.get_knockback_direction()，默认由来源位置指向怪物。
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
		# 来源节点位置；取值为 Node2D 全局坐标，默认用于从来源指向怪物的击退方向。
		var source_position: Vector2 = (source as Node2D).global_position
		# 位置推导方向；取值为来源到怪物的单位向量，默认用于无方向来源的击退。
		var inferred_direction: Vector2 = global_position - source_position
		if not inferred_direction.is_zero_approx():
			return inferred_direction.normalized()

	return Vector2.RIGHT


func _get_steered_direction_to(destination: Vector2) -> Vector2:
	if _movement_component == null:
		return Vector2.ZERO

	# 移动组件提供的方向；取值为 A* 路径或局部绕障后的单位向量，可见追击时允许终点轻微随机分散。
	var raw_direction: Variant = _movement_component.call("get_steered_direction_to", destination, _target_is_visible)
	return raw_direction if raw_direction is Vector2 else Vector2.ZERO


func _clear_navigation_path() -> void:
	if _movement_component != null:
		_movement_component.call("clear_navigation_path")


func _move_with_external_velocity(delta: float) -> void:
	if _movement_component == null:
		move_and_slide()
		return

	# 本帧基础速度；取值来自追击或游荡逻辑，默认在叠加击退前缓存。
	var desired_velocity: Vector2 = velocity
	_movement_component.call("move_with_external_velocity", desired_velocity, delta)


func get_target_ai_state() -> int:
	return _target_ai_state


func get_occlusion_loss_count() -> int:
	return int(_perception_component.call("get_line_of_sight_loss_count")) if _perception_component != null else 0


func get_target_search_destination() -> Vector2:
	if _perception_component == null:
		return global_position

	# 当前搜查点；取值由感知组件维护，默认供调试显示或扩展动画系统读取。
	var raw_destination: Variant = _perception_component.call("get_search_destination")
	return raw_destination if raw_destination is Vector2 else global_position


func get_tactical_target_instance_id() -> int:
	return _target.get_instance_id() if is_instance_valid(_target) else 0


func is_ranged_tactical_unit() -> bool:
	return false


func get_tactical_attack_range() -> float:
	return maxf(attack_range, 0.0)


func get_tactical_preferred_distance() -> float:
	return maxf(attack_range, 1.0)


func _spawn_hit_effect() -> void:
	_spawn_combat_burst(_resolve_effect_parent(), global_position, hit_effect_color, 26.0, 0.16, 6)


func _spawn_death_effect() -> void:
	_spawn_combat_burst(_resolve_effect_parent(), global_position, death_effect_color, 54.0, 0.34, 16)


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
	# 当前场景节点；取值通常为 GameWorld，默认让特效脱离怪物节点生命周期独立播放。
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		return current_scene

	return get_tree().root
