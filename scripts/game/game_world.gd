extends Node2D

## 随机生成怪物组名；默认所有随机生成怪物都会加入该组，修改会影响清怪兜底范围。
const TRAINING_MONSTER_GROUP: StringName = &"training_monsters"
## 正式骇入模式标识；默认与 SessionState 保持一致，修改会影响暂停菜单训练场功能是否隐藏。
const GAME_MODE_HACK: String = "hack"
## 训练场模式标识；默认与 SessionState 保持一致，修改会影响训练场专属功能是否开启。
const GAME_MODE_TRAINING: String = "training"
## 星角色标识；默认与主菜单角色选择保持一致，修改会影响角色属性随机分支。
const CHARACTER_STELLE: String = "stelle"
## 穹角色标识；默认与主菜单角色选择保持一致，修改会影响角色属性随机分支。
const CHARACTER_CAEULUS: String = "caelus"
## 银狼角色标识；默认与主菜单角色选择保持一致，修改会影响角色属性随机分支。
const CHARACTER_SILVER_WOLF: String = "silver_wolf"
## 宝箱脚本资源；用于调用统一品质抽取，不要求 GameWorld 强类型依赖宝箱节点类缓存。
const LOOT_CHEST_SCRIPT: Script = preload("res://scripts/environment/loot_chest.gd")
## 二手物品生成器；怪物与宝箱的新武器装备使用和商店完全相同的历史强化与耐久规则。
const SECOND_HAND_ITEM_GENERATOR: Script = preload("res://scripts/data/second_hand_item_generator.gd")
## 战斗网络同步器脚本；联机骇入时由 GameWorld 动态创建，单机流程不实例化任何多人逻辑节点。
const NETWORK_COMBAT_SYNC_SCRIPT: Script = preload("res://scripts/game/network_combat_sync.gd")
## 玩家骇入协议组件脚本；仅在正式骇入且启用对应模式扩展时动态挂载，本局结束后随玩家销毁。
const HACK_PROTOCOL_COMPONENT_SCRIPT: Script = preload("res://scripts/components/hack_protocol_component.gd")
## 联机撤离点随机流种子偏移；与共享地图种子相加派生独立随机流，保证撤离点位置不受各端后续随机消耗影响。
const NETWORK_EXTRACTION_SEED_OFFSET: int = 7717
## 大逃杀出生点随机流种子偏移；与共享地图种子相加派生独立随机流，全员在各自机器上推导出同一组出生点。
const BATTLE_ROYALE_SPAWN_SEED_OFFSET: int = 15473
## 大逃杀出生点离地图边缘留白；默认 640 像素，避免玩家出生贴边界墙或视野一半在图外。
const BATTLE_ROYALE_SPAWN_EDGE_MARGIN: float = 640.0
## 大逃杀出生点两两最小间距；默认 1600 像素，保证开局各玩家彼此在视野与常规交战距离之外。
const BATTLE_ROYALE_SPAWN_MIN_SPACING: float = 1600.0
## 大逃杀单个出生点候选尝试次数；默认 48，用于避开环境障碍与其他玩家出生点，全部失败时采用最后一个候选。
const BATTLE_ROYALE_SPAWN_ATTEMPT_COUNT: int = 48
## 大逃杀出生点障碍安全半径；默认 40 像素，大于玩家 18 像素碰撞半径以保留贴墙间隙。
const BATTLE_ROYALE_SPAWN_CLEARANCE_RADIUS: float = 40.0
## 联机每名额外成员的敌人人口倍率；默认 1.5，实际倍率为该值的（成员数-1）次幂，作用于开局布怪、人口曲线目标与同时活跃敌人上限。
const NETWORK_POPULATION_MULTIPLIER_PER_EXTRA_PLAYER: float = 1.5
## 宝箱高品质掉落概率；普通、中级、高级和极品分别使用 10%、30%、55% 和 75%，极品另保证至少 5 件高品质物品。
const CHEST_HIGH_QUALITY_CHANCES: Dictionary = {"common": 0.10, "medium": 0.30, "high": 0.55, "supreme": 0.75}
## 宝箱武器类别权重；默认 0.25 表示每个掉落槽有 25% 概率选择武器。
const CHEST_WEAPON_CATEGORY_WEIGHT: float = 0.25
## 宝箱装备类别权重；默认 0.15 表示每个掉落槽有 15% 概率选择装备。
const CHEST_EQUIPMENT_CATEGORY_WEIGHT: float = 0.15
## 宝箱强化石类别权重；默认 0.35 表示每个掉落槽有 35% 概率选择强化石。
const CHEST_ENHANCEMENT_STONE_CATEGORY_WEIGHT: float = 0.35
## 宝箱道具类别权重；默认 0.25 表示每个掉落槽有 25% 概率选择道具，四类权重总和必须保持为 1.0。
const CHEST_ITEM_CATEGORY_WEIGHT: float = 0.25

## 游戏世界场景负责提供当前关卡的基础承载环境。
## 玩家、敌人、掉落物、地图装饰都可以作为它的子节点存在。
## 进入战斗场景时会生成一张大型网格地图，并在地图上随机摆放墙体、建筑和怪物。

## 地图边界计算单格尺寸；取值应大于 0，默认 64 与 grid_extent 共同定义完整玩法范围，不控制背景网格线间距。
@export var grid_size: float = 64.0
## 网格地图向每个方向延伸的格数；取值应为正整数，默认 96 生成 192x192 格大型战斗地图，运行时修改会改变地图尺寸。
@export var grid_extent: int = 96
## 背景网格单格尺寸；单位为像素，默认 50 表示每格固定为 50×50 像素，只改变地面视觉参照密度，不影响地图边界、生成或导航范围。
@export_range(1.0, 1024.0, 1.0, "or_greater") var background_grid_cell_size: float = 50.0
## 地图边框颜色；取值为 RGBA，默认更亮用于定位网格地图边界，运行时修改会影响边界识别。
@export var axis_color: Color = Color(0.28, 0.52, 0.72, 0.62)
## 地图随机种子；默认 0 表示每次进入战斗场景随机生成，设置为正数可复现同一张地图。
@export var map_seed: int = 0
## 基础地面颜色；默认深蓝灰，运行时修改会影响网格地图底色。
@export var base_floor_color: Color = Color(0.055, 0.07, 0.09, 1.0)
## 网格线颜色；取值为 RGBA，默认低透明度用于地图定位，运行时修改会影响背景网格可见度。
@export var grid_color: Color = Color(0.18, 0.25, 0.30, 0.34)
## 探索迷雾格子尺寸；取值应大于 0，默认 256 像素，修改会影响大地图迷雾精度和探索记录数量。
@export_range(16.0, 2048.0, 1.0, "or_greater") var exploration_cell_size: float = 256.0
## 玩家探索半径；取值应大于等于 0，默认 760 像素，仅在玩家摄像机缺失时作为探索范围回退值。
@export_range(0.0, 6000.0, 1.0) var exploration_radius: float = 760.0
## 探索格更新间隔；取值建议 0.1 到 0.5 秒，默认 0.2 秒，修改会影响大地图迷雾刷新频率和每帧 CPU 开销。
@export_range(0.02, 5.0, 0.01) var exploration_update_interval: float = 0.2
## 探索格强制更新移动距离；取值建议小于探索格子尺寸，默认 96 像素，玩家移动超过该距离会立即刷新探索缓存。
@export_range(0.0, 2048.0, 1.0) var exploration_update_distance: float = 96.0
## 边界墙厚度；取值应大于 0，默认 64 像素，用于在地图四周生成一圈阻挡玩家和怪物离场的墙体。
@export_range(1.0, 1024.0, 1.0, "or_greater") var boundary_wall_thickness: float = 64.0
## 边界墙颜色；取值为 RGBA，默认深蓝灰，修改会影响地图边缘墙体的可视表现。
@export var boundary_wall_color: Color = Color(0.10, 0.15, 0.18, 1.0)
## 玩家节点路径；默认指向当前场景 Player，必须解析到 Node2D，修改会影响怪物索敌目标。
@export var player_path: NodePath = ^"Player"
## 玩家摄像机路径；默认指向 Player/Camera2D，探索系统读取其实际屏幕范围，运行时缩放或窗口变化会同步改变可发现区域。
@export var player_camera_path: NodePath = ^"Player/Camera2D"
## 玩家战斗属性组件相对路径；默认 StatsComponent，用于角色基础属性、被动倍率和生存状态，运行时通常不动态修改。
@export var player_stats_component_path: NodePath = ^"StatsComponent"
## 玩家被动技能组件相对路径；默认 PassiveSkillComponent，用于角色切换时装载全部被动行为。
@export var player_passive_skill_component_path: NodePath = ^"PassiveSkillComponent"
## 玩家主动技能组件相对路径；默认 ActiveSkillComponent，用于角色切换时装载前三个主动技能槽。
@export var player_active_skill_component_path: NodePath = ^"ActiveSkillComponent"
## 玩家装备组件相对路径；默认 EquipmentComponent，用于角色切换时同步基础移动速度。
@export var player_equipment_component_path: NodePath = ^"EquipmentComponent"
## 当前角色运行时配置组件路径；默认指向世界直属 SelectedCharacterRuntimeComponent，负责统一注入角色档案、技能与基础属性。
@export var selected_character_runtime_component_path: NodePath = ^"SelectedCharacterRuntimeComponent"
## 环境物父节点路径；默认指向 Environment 容器，允许为空并回退到 GameWorld，修改会影响随机墙体和建筑层级。
@export var environment_parent_path: NodePath = ^"Environment"
## 随机环境预制体列表；默认由场景指定墙体和建筑，元素必须能实例化为 Node2D，修改会影响地图障碍类型池。
@export var obstacle_scenes: Array[PackedScene] = []
## 随机环境生成数量；取值建议 0 到 256，默认 96，运行时修改会影响地图障碍密度。
@export_range(0, 256, 1) var obstacle_spawn_count: int = 96
## 环境生成最小玩家距离；取值应大于等于 0，默认 300 像素，运行时修改会影响玩家出生点周围空地大小。
@export_range(0.0, 4000.0, 1.0) var obstacle_spawn_min_distance_from_player: float = 300.0
## 环境生成边界留白；取值应大于等于 0，默认 520 像素，运行时修改会影响墙体和建筑离地图边缘的距离。
@export_range(0.0, 4000.0, 1.0) var obstacle_spawn_edge_margin: float = 520.0
## 环境生成最小间距；取值应大于等于 0，默认 52 像素，运行时修改会影响建筑之间是否拥挤或重叠。
@export_range(0.0, 2000.0, 1.0) var obstacle_spawn_min_spacing: float = 52.0
## 单个环境物生成尝试次数；取值建议 1 到 128，默认 36，运行时修改会影响生成成功率和进入场景耗时。
@export_range(1, 128, 1) var obstacle_spawn_attempts_per_item: int = 36
## 环境物最小随机缩放；取值建议大于 0，默认 0.65，修改会影响墙体和建筑最小体积。
@export_range(0.1, 8.0, 0.05) var obstacle_scale_min: float = 0.65
## 环境物最大随机缩放；取值应大于等于最小缩放，默认 1.9，修改会影响墙体和建筑最大体积。
@export_range(0.1, 8.0, 0.05) var obstacle_scale_max: float = 1.9
## 脱离卡死搜索格尺寸；默认 48 像素，用于在玩家当前位置附近逐圈寻找安全传送点。
@export_range(16.0, 256.0, 1.0) var unstuck_search_cell_size: float = 48.0
## 脱离卡死障碍安全半径；默认 26 像素，大于玩家 18 像素碰撞半径以保留墙体间距。
@export_range(18.0, 128.0, 1.0) var unstuck_clearance_radius: float = 26.0
## 脱离卡死最大搜索圈数；默认 12 圈，在 48 像素格配置下最多搜索约 576 像素范围。
@export_range(1, 64, 1) var unstuck_max_search_radius: int = 12
## 随机怪物场景；默认由 game_world.tscn 指向 BasicMonster，必须实例化为 Node2D，修改会影响随机生成的敌人类型。
## 星内容精简补充：当前正式场景兜底指向虚卒·掠夺者，运行时再由内容目录合并两种星扩展包怪物。
@export var monster_scene: PackedScene
## 随机怪物场景池；默认由场景填入近战和远程怪物，非空时会优先从池中随机选择生成对象。
@export var monster_scenes: Array[PackedScene] = []
## 怪物开局人口；默认 200，远处人口只保存虚拟记录，进入玩家加载范围后才实例化并执行 AI。
@export_range(0, 20000, 1) var monster_spawn_count: int = 200
## 怪物生成最小距离；取值应大于等于 0，默认 280 像素，运行时修改会影响怪物是否离玩家过近。
## 全地图布怪补充：项目当前默认至少离玩家 900 像素，避免开局和补充刷新直接出现在屏幕附近。
@export_range(0.0, 8000.0, 1.0) var monster_spawn_min_distance: float = 900.0
## 怪物生成最大距离；取值应大于最小距离，默认 900 像素，运行时修改会影响怪物分布范围。
@export_range(1.0, 8000.0, 1.0, "or_greater") var monster_spawn_max_distance: float = 900.0
## 是否在整张地图均匀生成敌人；默认 true，关闭后恢复以玩家为中心的最小/最大距离环形生成。
@export var monster_spawn_across_full_map: bool = true
## 全地图敌人生成边界留白；默认 256 像素，防止敌人贴着边界墙或生成到地图外侧。
@export_range(0.0, 4000.0, 1.0) var monster_spawn_edge_margin: float = 256.0
## 正式战斗最低开局人口；默认 200，与开局生成量共同决定 0 秒人口下限，低于目标时持续补充虚拟记录。
@export_range(0, 20000, 1) var monster_minimum_alive_count: int = 200
## 第一人口里程碑时间；默认 300 秒，达到时全地图敌人人口增长到 monster_population_five_minute_count。
@export_range(1.0, 3600.0, 1.0) var monster_population_first_milestone_seconds: float = 300.0
## 第一人口里程碑数量；默认 1200，0 秒到第一里程碑之间按游戏时长线性增长。
@export_range(0, 20000, 1) var monster_population_five_minute_count: int = 1200
## 第二人口里程碑时间；默认 600 秒，达到时全地图敌人人口增长到 monster_population_ten_minute_count。
@export_range(1.0, 7200.0, 1.0) var monster_population_second_milestone_seconds: float = 600.0
## 第二人口里程碑数量；默认 3200，达到第二里程碑后维持该目标人口并补充死亡缺口。
@export_range(0, 20000, 1) var monster_population_ten_minute_count: int = 3200
## 敌人人口补充检查间隔；默认 0.25 秒，平滑创建虚拟记录并及时跟随人口增长曲线。
@export_range(0.05, 60.0, 0.05) var monster_replenish_interval: float = 0.25
## 单次补充虚拟敌人人口数量；默认 64，只创建轻量记录，不会在同一帧实例化同等数量的 AI 节点。
@export_range(1, 1024, 1) var monster_replenish_batch_size: int = 64
## 敌人尺寸与属性随机波动比例；默认 0.3 表示每只敌人的大小和战斗属性分别在 70% 到 130% 范围内生成。
@export_range(0.0, 0.9, 0.05) var monster_spawn_variation_ratio: float = 0.3
## 怪物父节点路径；默认指向 Enemies 容器，允许为空并回退到 GameWorld，修改会影响怪物节点层级。
@export var monster_parent_path: NodePath = ^"Enemies"
## 怪物加载管理器路径；默认指向 MonsterSimulationManager，负责远距离休眠和分批唤醒。
@export var monster_simulation_manager_path: NodePath = ^"MonsterSimulationManager"
## 掉落物父节点路径；默认指向 Drops 容器，允许为空并回退到 GameWorld，修改会影响武器掉落物节点层级。
@export var drop_parent_path: NodePath = ^"Drops"
## 武器掉落物场景；默认由 game_world.tscn 指向 WeaponDrop，必须实例化为 Node2D，修改会影响所有地面武器表现。
@export var weapon_drop_scene: PackedScene
## 武器掉落随机池；元素为 WeaponData 资源，怪物死亡掉落时会从中随机复制一把作为独立掉落物。
@export var weapon_drop_table: Array[Resource] = []
## 装备死亡掉落概率；默认 0.03 表示每只被击杀怪物独立有 3% 基础概率生成一件随机装备，结算时还会乘怪物掉落倍率。
@export_range(0.0, 1.0, 0.001) var equipment_drop_chance: float = 0.03
## 装备掉落随机池；元素为 EquipmentData 资源，内容目录会自动补充所有合法装备，掉落时深拷贝为独立实例。
@export var equipment_drop_table: Array[Resource] = []
## 强化石死亡掉落概率；默认 0.05 表示每只被击杀怪物独立有 5% 概率生成一颗随机强化石。
@export_range(0.0, 1.0, 0.001) var enhancement_stone_drop_chance: float = 0.05
## 单颗强化石最少词条数量；默认 1，运行时随机数量会限制在最少与最多词条之间。
@export_range(1, 9, 1) var enhancement_stone_min_modifier_count: int = 1
## 单颗强化石最多词条数量；默认 3，允许一颗强化石同时包含多种正负属性。
@export_range(1, 9, 1) var enhancement_stone_max_modifier_count: int = 3
## 强化石生成削弱词条的概率；默认 0.28，削弱方向会按属性规则决定，例如冷却增加或伤害降低。
@export_range(0.0, 1.0, 0.01) var enhancement_stone_negative_modifier_chance: float = 0.28
## 强化石单词条基础价值；默认 30 星穹，随机多词条会按词条数量增加单颗价值。
@export_range(0, 999999, 1) var enhancement_stone_base_value: int = 30
## 品质规则兼容说明；词条数量与削弱概率现由 EnhancementRules.QUALITY_CONFIGS 统一决定，上述最小/最大词条和通用削弱概率只保留旧扩展调用兼容。
## 新生成武器装备的二手概率；默认 0.30，怪物掉落与宝箱每件独立判定且与普通商店保持一致。
@export_range(0.0, 1.0, 0.01) var second_hand_equipment_chance: float = 0.30
## 道具死亡掉落概率；默认 0.05 表示每只被击杀怪物独立有 5% 基础概率掉落一个随机道具，结算时还会乘怪物掉落倍率；变量名为旧场景兼容保留。
@export_range(0.0, 1.0, 0.001) var repair_kit_drop_chance: float = 0.05
## 道具掉落随机池；内容目录会自动补充所有合法通用道具，怪物或宝箱掉落时会深拷贝其中一项；变量名为旧场景兼容保留。
@export var repair_kit_drop_table: Array[Resource] = []
## 怪物掉落抛物线动画最短时长；默认 0.36 秒，每件击杀掉落独立随机，运行时通常无需动态修改。
@export_range(0.05, 2.0, 0.01) var monster_drop_launch_duration_min: float = 0.36
## 怪物掉落抛物线动画最长时长；默认 0.56 秒，修改会影响击杀后物品落地等待时间。
@export_range(0.05, 2.0, 0.01) var monster_drop_launch_duration_max: float = 0.56
## 怪物掉落抛物线最小弧高；默认 36 像素，使近距离散落仍具有清晰上抛反馈。
@export_range(0.0, 300.0, 1.0) var monster_drop_launch_arc_height_min: float = 36.0
## 怪物掉落抛物线最大弧高；默认 64 像素，为同次多物品掉落提供自然高度差。
@export_range(0.0, 400.0, 1.0) var monster_drop_launch_arc_height_max: float = 64.0
## 宝箱场景；默认由 game_world.tscn 指向 LootChest，必须实例化为静态 Node2D 建筑。
@export var loot_chest_scene: PackedScene
## 单局最少宝箱数量；默认 20，与最大值组成进入地图时的等概率整数范围。
@export_range(0, 100, 1) var loot_chest_spawn_count_min: int = 15
## 单局最多宝箱数量；默认 40，实际生成数量会先与最少值排序后随机抽取。
@export_range(0, 100, 1) var loot_chest_spawn_count_max: int = 30
## 宝箱优先在建筑周围生成的概率；默认 0.72，其余候选在整张地图均匀抽取。
@export_range(0.0, 1.0, 0.01) var loot_chest_near_building_chance: float = 0.72
## 封闭建筑在附近宝箱候选中的权重倍率；默认 3.0，使封闭建筑周边比普通环境结构更容易被选中。
@export_range(1.0, 12.0, 0.1) var loot_chest_enclosed_building_weight: float = 3.0
## 单个宝箱生成尝试次数；默认 48，用于寻找不与建筑、边界或其他宝箱重叠的位置。
@export_range(1, 160, 1) var loot_chest_spawn_attempt_count: int = 48
## 宝箱离玩家出生点最小距离；默认 240 像素，避免开局直接阻挡玩家移动。
@export_range(0.0, 3000.0, 1.0) var loot_chest_min_distance_from_player: float = 240.0
## 宝箱碰撞检测半径；默认 40 像素，大于实际半尺寸以保留与墙体的移动间隙。
@export_range(16.0, 160.0, 1.0) var loot_chest_clearance_radius: float = 40.0
## 相邻宝箱最小中心距离；默认 112 像素，避免多个静态建筑堆叠成不可通行团块。
@export_range(32.0, 640.0, 1.0) var loot_chest_minimum_spacing: float = 112.0
## 手动开启宝箱掉落最小扩散半径；默认 34 像素，让物品保持聚集但不完全重叠。
@export_range(0.0, 400.0, 1.0) var loot_chest_manual_drop_radius_min: float = 34.0
## 手动开启宝箱掉落最大扩散半径；默认 72 像素，形成紧凑可拾取物资堆。
@export_range(0.0, 600.0, 1.0) var loot_chest_manual_drop_radius_max: float = 72.0
## 击破宝箱掉落最小飞散半径；默认 105 像素，避免爆出的物品堆在箱体中心。
@export_range(0.0, 600.0, 1.0) var loot_chest_broken_drop_radius_min: float = 105.0
## 击破宝箱掉落最大飞散半径；默认 190 像素，使不同掉落物形成明显放射分布。
@export_range(0.0, 900.0, 1.0) var loot_chest_broken_drop_radius_max: float = 190.0
## 宝箱掉落飞出动画最短时长；默认 0.48 秒，手动开启和击破都会在范围内独立随机。
@export_range(0.05, 2.0, 0.01) var loot_chest_launch_duration_min: float = 0.48
## 宝箱掉落飞出动画最长时长；默认 0.72 秒，距离较远时仍保持清晰可见。
@export_range(0.05, 2.0, 0.01) var loot_chest_launch_duration_max: float = 0.72
## 宝箱掉落飞出动画最小弧高；默认 54 像素，控制手动开启和击破掉落物的视觉上抛高度。
@export_range(0.0, 300.0, 1.0) var loot_chest_launch_arc_height_min: float = 54.0
## 宝箱掉落飞出动画最大弧高；默认 92 像素，为多件掉落提供轻微高度差。
@export_range(0.0, 400.0, 1.0) var loot_chest_launch_arc_height_max: float = 92.0
## 玩家丢弃武器散落半径；取值建议大于玩家半径，默认 52 像素，修改会影响拖出背包时武器落点距离。
@export_range(0.0, 400.0, 1.0) var dropped_weapon_scatter_radius: float = 52.0
## 地面掉落最小分离距离；默认 36 像素，多个物品同时生成时会尽量避开已有掉落物中心。
@export_range(0.0, 256.0, 1.0) var dropped_item_minimum_separation: float = 36.0
## 撤离点生成时间；取值为进入战斗后的秒数，默认 120 表示存活 2 分钟后生成撤离点。
@export_range(1.0, 7200.0, 1.0, "or_greater") var extraction_spawn_time_seconds: float = 120.0
## 撤离点地图标记时间；取值为进入战斗后的秒数，默认 300 表示存活 5 分钟后在地图上显示撤离点标记。
## 现行标记时机补充：常规局默认在存活 240 秒（4 分钟）后标记撤离点；首次战斗引导仍由独立 120 秒配置立即标记。
@export_range(1.0, 7200.0, 1.0, "or_greater") var extraction_map_marker_time_seconds: float = 240.0
## 首次新手引导撤离点出现并标记的时间；默认 120 秒，让玩家完成战斗、拾取、开箱和协议选择后进入撤离教学。
@export_range(30.0, 480.0, 1.0) var tutorial_extraction_time_seconds: float = 120.0
## 首次新手引导开局普通敌人与玩家的期望距离；默认 520 像素，保证很快遇敌且不会贴脸出生。
@export_range(240.0, 1600.0, 1.0) var tutorial_anchor_monster_distance: float = 520.0
## 首次新手引导撤离点与生成时玩家的期望距离；默认 1100 像素，保留一次短途探索但可在八分钟内轻松抵达。
@export_range(480.0, 3000.0, 1.0) var tutorial_extraction_distance: float = 1100.0
## 首次击杀保底武器；默认“陷阵”，运行时深复制后掉落，修改模板不会影响其他普通掉落池。
@export var tutorial_first_kill_weapon: Resource = preload("res://data/weapons/basic/formation_breaker.tres")
## 首次开箱保底防具；默认“起源护甲”，与正常宝箱随机产出叠加且不替换原掉落。
@export var tutorial_first_chest_equipment: Resource = preload("res://data/equipment/basic/origin_armor.tres")
## 首次协议固定候选；默认提供连发、散射和击杀回血三种直观收益，只覆盖新手引导的第一轮。
@export var tutorial_first_protocol_offer_ids: Array[String] = ["weapon_combo_bonus", "weapon_scatter_bonus", "kill_health_restore"]
## 训练工具单次增加的游戏时长；默认 60 秒即 1 分钟，运行时修改会影响调试按钮加速撤离点生成与地图标记的幅度。
@export_range(1.0, 3600.0, 1.0, "or_greater") var training_time_addition_seconds: float = 60.0
## 撤离驻留时长；取值应大于 0，默认 5 秒，玩家在撤离范围内连续停留满该时间后可按冲刺键撤离。
## 现行驻留规则补充：正式撤离的 5 秒按整局累计，离开或在多个正式撤离点之间移动都保留已有进度；仅处于范围内时可执行撤离。
@export_range(0.1, 120.0, 0.1, "or_greater") var extraction_hold_duration_seconds: float = 5.0
## 撤离点半径；取值建议大于玩家碰撞半径，默认 96 像素，修改会影响可驻留撤离范围。
@export_range(16.0, 512.0, 1.0, "or_greater") var extraction_radius: float = 96.0
## 撤离点生成边界留白；取值应大于撤离半径，默认 420 像素，修改会影响撤离点离地图边缘的距离。
@export_range(0.0, 4000.0, 1.0) var extraction_spawn_edge_margin: float = 420.0
## 撤离点生成最小玩家距离；取值建议大于屏幕半径，默认 900 像素，避免撤离点直接刷在玩家脚下。
@export_range(0.0, 8000.0, 1.0) var extraction_spawn_min_distance_from_player: float = 900.0
## 撤离点生成尝试次数；取值建议 1 到 128，默认 36，用于寻找不被环境障碍覆盖的位置。
@export_range(1, 128, 1) var extraction_spawn_attempt_count: int = 36
## 常规局正式撤离点数量；默认 3 个，风险合约可在本局覆盖为 1 个，运行时通常不动态修改。
@export_range(1, 8, 1) var extraction_point_count: int = 3
## 正式撤离点优先最小间距；默认 4000 像素，生成器在有效候选中最大化最近点距离，无法满足时才回退最远合法点。
@export_range(0.0, 16000.0, 1.0) var extraction_point_preferred_minimum_spacing: float = 4000.0
## 撤离点填充颜色；默认青绿色半透明，修改只影响撤离范围视觉反馈。
@export var extraction_fill_color: Color = Color(0.1, 0.9, 0.62, 0.18)
## 撤离点边框颜色；默认亮青绿色，修改只影响撤离范围边界视觉反馈。
@export var extraction_ring_color: Color = Color(0.35, 1.0, 0.76, 0.88)
## 物资撤离点数量权重；默认 2、3、4、5 个的概率依次为 45%、30%、17%、8%，数量越多概率越低。
@export var supply_extraction_count_weights: Array[float] = [0.45, 0.30, 0.17, 0.08]
## 物资撤离点驻留时长；默认 3 秒，玩家连续停留后按冲刺键打开暂停式送回面板。
@export_range(0.1, 30.0, 0.1) var supply_extraction_hold_duration_seconds: float = 3.0
## 物资撤离点半径；默认 96 像素，与正式撤离点保持相同站位宽容度。
@export_range(16.0, 512.0, 1.0) var supply_extraction_radius: float = 96.0
## 物资撤离点边缘留白；默认 420 像素，避免点位范围压到地图边界墙。
@export_range(0.0, 4000.0, 1.0) var supply_extraction_spawn_edge_margin: float = 420.0
## 物资撤离点离玩家出生点最小距离；默认 720 像素，鼓励玩家先探索地图。
@export_range(0.0, 8000.0, 1.0) var supply_extraction_min_distance_from_player: float = 720.0
## 单个物资撤离点生成尝试次数；默认 48，用于避开建筑、宝箱和其他撤离点。
@export_range(1, 160, 1) var supply_extraction_spawn_attempt_count: int = 48
## 物资撤离点填充颜色；默认金黄色半透明，用于和绿色正式撤离点区分。
@export var supply_extraction_fill_color: Color = Color(1.0, 0.66, 0.12, 0.16)
## 物资撤离点边框颜色；默认亮金黄色，地图内始终可见但不代表战斗结束。
@export var supply_extraction_ring_color: Color = Color(1.0, 0.72, 0.22, 0.92)
## 星的固定生命上限；取值应大于 0，默认 130，切换角色时直接应用，不再随机。
## 星扩展包数值补充：当前权威基础生命上限为 100，资源档案可继续覆盖该隔离场景兜底值。
@export_range(1.0, 9999.0, 1.0, "or_greater") var stelle_max_health: float = 100.0
## 星的固定能量上限；取值应大于 0，默认 100，支持 0.1 精度，资源档案可继续覆盖该隔离场景兜底值。
@export_range(0.1, 9999.0, 0.1, "or_greater") var stelle_max_energy: float = 100.0
## 星的固定移动速度属性；默认 106.6667，按 1 点等于 3 像素/秒换算，切换角色时写入玩家移动组件。
## 当前星移速按 1 点等于 2 像素/秒换算；100 点基础移速在战斗中对应 200 像素/秒。
## 星扩展包数值补充：当前权威基础移速为 100 点，等效实际速度 300 像素/秒。
## 当前星扩展包数值补充：权威基础移速保持 100 点，等效实际速度按新换算为 200 像素/秒。
@export_range(1.0, 2000.0, 0.0001, "or_greater") var stelle_move_speed: float = 100.0
## 星的固定攻击力；默认 10，切换角色时写入战斗属性组件并参与伤害公式。
## 星扩展包数值补充：当前权威基础攻击力为 100，资源档案可继续覆盖该隔离场景兜底值。
@export_range(0.0, 99999.0, 1.0, "or_greater") var stelle_attack_power: float = 100.0
## 星的固定防御力；默认 5，切换角色时写入战斗属性组件并参与承伤公式。
## 星扩展包数值补充：当前权威基础防御力为 100，资源档案可继续覆盖该隔离场景兜底值。
@export_range(0.0, 99999.0, 1.0, "or_greater") var stelle_defense_power: float = 100.0
## 穹的固定生命上限；取值应大于 0，默认 150，切换角色时直接应用，不再随机。
@export_range(1.0, 9999.0, 1.0, "or_greater") var caelus_max_health: float = 120.0
## 穹的固定能量上限；取值应大于 0，默认 80，支持 0.1 精度，切换角色时直接应用，不再随机。
@export_range(0.1, 9999.0, 0.1, "or_greater") var caelus_max_energy: float = 80.0
## 穹的固定移动速度属性；默认 100，按 1 点等于 3 像素/秒换算，切换角色时写入玩家移动组件。
## 当前穹移速按 1 点等于 2 像素/秒换算；90 点基础移速在战斗中对应 180 像素/秒。
@export_range(1.0, 2000.0, 0.0001, "or_greater") var caelus_move_speed: float = 90.0
## 穹的固定攻击力；默认 9，较低输出与较高生存能力形成角色差异。
@export_range(0.0, 99999.0, 1.0, "or_greater") var caelus_attack_power: float = 90.0
## 穹的固定防御力；默认 10，为三名角色中最高基础防御。
@export_range(0.0, 99999.0, 1.0, "or_greater") var caelus_defense_power: float = 120.0
## 银狼的固定生命上限；取值应大于 0，默认 105，切换角色时直接应用，不再随机。
@export_range(1.0, 9999.0, 1.0, "or_greater") var silver_wolf_max_health: float = 99.0
## 银狼的固定能量上限；取值应大于 0，默认 99，支持 0.1 精度，切换角色时直接应用，不再随机。
@export_range(0.1, 9999.0, 0.1, "or_greater") var silver_wolf_max_energy: float = 99.0
## 银狼的固定移动速度属性；默认 118.3333，按 1 点等于 3 像素/秒换算，切换角色时写入玩家移动组件。
## 当前银狼移速按 1 点等于 2 像素/秒换算；99 点基础移速在战斗中对应 198 像素/秒。
@export_range(1.0, 2000.0, 0.0001, "or_greater") var silver_wolf_move_speed: float = 99.0
## 银狼的固定攻击力；默认 11，为三名角色中最高基础攻击。
@export_range(0.0, 99999.0, 1.0, "or_greater") var silver_wolf_attack_power: float = 99.0
## 银狼的固定防御力；默认 2，以较低防御平衡高攻击、能量和移速。
@export_range(0.0, 99999.0, 1.0, "or_greater") var silver_wolf_defense_power: float = 99.0

## 随机数生成器；默认新建并在 ready 随机化，修改会影响地图和怪物生成结果。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 当前实际地图种子；取值为 map_seed 或随机值，默认 0 表示尚未生成，用于调试复现地图。
var _active_map_seed: int = 0
## 小地图障碍矩形缓存；元素为世界坐标 Rect2，默认由随机环境碰撞形状生成，修改会影响小地图绘制内容。
var _environment_obstacle_rects: Array[Rect2] = []
## 小地图障碍版本号；取值从 0 递增，默认用于地图 UI 判断是否需要重新复制障碍矩形。
var _environment_obstacle_version: int = 0
## 环境结构整体边界缓存；每项包含 bounds 和 enclosed，用于让宝箱优先在建筑周围特别是封闭建筑附近生成。
var _environment_feature_bounds: Array[Dictionary] = []
## 宝箱障碍矩形表；键为宝箱实例编号，值为写入小地图与导航缓存的世界矩形，宝箱开启后用于精确移除。
var _loot_chest_obstacle_rects: Dictionary = {}
## 已探索迷雾格子缓存；键为 Vector2i，值为 true，默认由玩家位置持续写入，修改会影响大地图可见区域。
var _explored_cells: Dictionary = {}
## 已探索格版本号；取值从 0 递增，默认仅在新增探索格时变化，供地图 UI 避免重复构建查询表。
var _explored_cells_version: int = 0
## 导航网格缓存；键为寻路格尺寸与代理半径组合，值为 AStarGrid2D，用于避免每只怪物重复重建整张地图网格。
var _navigation_grid_cache: Dictionary = {}
## 探索更新剩余时间；取值大于等于 0，默认 0 表示下一帧允许检查探索格刷新。
var _exploration_update_remaining: float = 0.0
## 上次刷新探索格时的玩家位置；取值为世界坐标，默认零向量，仅在 _has_last_exploration_update_position 为 true 时有效。
var _last_exploration_update_position: Vector2 = Vector2.ZERO
## 是否已有上次探索刷新位置；取值为 true/false，默认 false 用于首次强制刷新探索格。
var _has_last_exploration_update_position: bool = false
## 上次探索使用的摄像机世界视野矩形；默认空矩形，用于相机缩放或窗口尺寸变化后立即刷新探索范围。
var _last_exploration_view_rect: Rect2 = Rect2()
## 是否已有上次摄像机探索矩形；默认 false，首次进入地图时强制记录当前真实视野。
var _has_last_exploration_view_rect: bool = false
## 上次绘制背景网格的窗口签名；按网格步长取整的可见格边界，默认极小值保证首帧必然重绘一次。
var _last_grid_window_signature: Vector4i = Vector4i(-2147483648, -2147483648, -2147483648, -2147483648)
## 当前是否为训练场模式；默认 false 表示正式骇入，修改会影响 HUD 是否显示训练场设置。
var _is_training_mode: bool = false
## 当前是否为一次性首次战斗新手引导；默认 false，入场时从 SessionState 缓存并决定专属流程与结算。
var _is_first_run_tutorial: bool = false
## 引导局是否已经完成首次击杀；默认 false，首次变为 true 时生成固定武器奖励并推进目标文案。
var _tutorial_first_enemy_defeated: bool = false
## 引导局是否已经释放首次宝箱；默认 false，首次变为 true 时追加固定防具、强化石并补足首轮协议碎片。
var _tutorial_first_chest_opened: bool = false
## 引导局是否已经获得第一项协议；默认 false，协议组件首次产生有效获得列表时变为 true。
var _tutorial_first_protocol_acquired: bool = false
## 当前骇入模式变体；取值为 HackModeRules 定义的 standard、bare 或 overclock，训练场固定回退 standard。
## 入场时从 SessionState 读取一次并缓存整局；决定人口倍率、二手概率覆盖、结算资格与玩家规则豁免。
var _hack_variant: String = HackModeRules.VARIANT_STANDARD
## 当前模式扩展汇总效果；键由 ModeExtensionRules 定义，入场时从 SessionState 读取一次并缓存整局。
## 中性配置的数值倍率均为 1.0、布尔开关均为 false，训练场与无扩展骇入不会改变现有规则。
var _mode_extension_effect_multipliers: Dictionary = ModeExtensionRules.get_effect_multipliers([])
## 当前是否启用骇入协议模式扩展；入场时从 SessionState 缓存，决定是否创建玩家局内协议组件。
var _hack_protocol_enabled: bool = false
## 本地玩家骇入协议组件；每台设备只保存本机碎片、候选与效果，多人摘要交由网络同步器维护。
var _hack_protocol_component: Node = null
## 当前选择角色标识；取值为 stelle、caelus 或 silver_wolf，默认 stelle，用于角色切换和属性随机。
var _selected_character_id: String = CHARACTER_STELLE
## 当前战斗存活时间；取值为进入 GameWorld 后玩家未死亡的累计秒数，默认 0 用于 HUD 计时显示。
var _survival_time_seconds: float = 0.0
## 撤离点节点缓存；取值为运行时生成的 Node2D 或 null，默认 null 表示撤离点尚未生成。
var _extraction_point_node: Node2D
## 正式撤离点节点列表；默认空数组，生成后每个点各拥有独立的范围视觉节点，首项同步给旧单点缓存。
var _extraction_point_nodes: Array[Node2D] = []
## 撤离点位置缓存；取值为世界坐标，默认零向量，仅在 _has_extraction_point 为 true 时有效。
var _extraction_point_position: Vector2 = Vector2.ZERO
## 正式撤离点位置列表；默认空数组，常规局保存 3 个远距点位，风险合约可将其覆盖为 1 个。
var _extraction_point_positions: Array[Vector2] = []
## 是否已经生成撤离点；取值为 true/false，默认 false，避免 2 分钟后重复生成多个撤离点。
var _has_extraction_point: bool = false
## 撤离点是否已经显示在地图上；取值为 true/false，默认 false，达到地图标记时间后变为 true。
var _extraction_point_marked_on_map: bool = false
## 玩家是否处于撤离范围内；取值为 true/false，默认 false，用于 HUD 显示驻留状态。
var _player_inside_extraction_area: bool = false
## 撤离驻留累计时间；取值大于等于 0，默认 0，离开撤离范围会重置。
## 现行累计行为补充：离开正式撤离范围不会清零；本局只在点位尚未生成、玩家缺失或死亡时重置，防止死亡状态保留撤离资格。
var _extraction_hold_elapsed_seconds: float = 0.0
## 是否已经满足撤离条件；取值为 true/false，默认 false，达到驻留时长且仍在范围内时变为 true。
## 现行就绪状态补充：累计时间达到阈值后保持 true，但 CombatHud 仍会额外校验玩家在正式撤离范围内才能确认撤离。
var _extraction_ready_to_leave: bool = false
## 当前玩家所在正式撤离点下标；默认 -1 表示不在任一撤离范围内，用于多点驻留计时切换时正确清零。
## 现行点位切换补充：该下标仅表示 HUD 当前所在点位；正式撤离驻留改为整局累计后，切换点位不再重置累计时间。
var _active_extraction_point_index: int = -1
## 物资撤离点位置列表；默认空数组，进入地图时按 2 至 5 个递减概率生成。
var _supply_extraction_positions: Array[Vector2] = []
## 当前玩家所在物资撤离点下标；默认 -1 表示未进入任一点位范围。
var _active_supply_extraction_index: int = -1
## 当前物资撤离点驻留累计时间；默认 0，离开范围或切换点位时重置。
var _supply_extraction_hold_elapsed_seconds: float = 0.0
## 当前物资撤离点是否可以打开送回面板；默认 false，驻留满 3 秒后变为 true。
var _supply_extraction_ready: bool = false
## 敌人补充检查剩余时间；取值大于等于 0，默认按配置间隔初始化，正式战斗中持续递减。
var _monster_replenish_remaining: float = 0.0
## 是否由训练工具暂停自动补怪；默认 false，正式模式使用开发者清怪后保持为空，手动重生怪物时恢复人口曲线补充。
var _monster_replenishment_paused_by_training_tools: bool = false
## 怪物场景生成权重缓存；键为场景资源路径或临时实例 ID，值为根节点的 spawn_weight，避免每只虚拟敌人重复读取场景状态。
var _monster_scene_spawn_weights: Dictionary = {}
## 玩家导航标点位置；取值为世界坐标，仅在 _has_navigation_marker 为 true 时有效。
var _navigation_marker_position: Vector2 = Vector2.ZERO
## 是否存在玩家导航标点；默认 false，大地图左键设置后由大小地图共同读取。
var _has_navigation_marker: bool = false
## 技能地图标记表；键为技能稳定标记 ID，值为包含 position 与 kind 的只读数据，独立于玩家导航点和撤离点。
var _skill_map_markers: Dictionary = {}
## 联机战斗是否激活；默认 false，进入场景时从 NetworkSession 解析，影响地图种子来源、敌人产出归属与掉落宝箱同步。
var _network_combat_active: bool = false
## 本机是否为联机主机；默认 false，仅联机战斗激活时有效，客户端跳过敌人生成与人口补充。
var _network_is_host: bool = false
## 战斗网络同步器实例；默认 null，仅联机战斗激活时创建，负责队友化身、敌人复制与掉落宝箱仲裁。
var _network_combat_sync: Node2D = null
## 联机撤离点专用随机源；默认 null，联机时以共享种子派生，与主随机流隔离保证各端撤离点一致。
var _network_extraction_random: RandomNumberGenerator = null
## 联机预生成的正式撤离点位置列表；默认空数组，使用共享种子专用随机流推导，保证全端得到相同的多点布局。
var _network_extraction_positions: Array[Vector2] = []
## 联机预生成撤离点位置；进入地图时以专用随机流立即推导（此时全员世界状态一致），120 秒后直接使用。
var _network_extraction_position: Vector2 = Vector2.ZERO
## 联机是否已经预生成正式撤离点位置列表；默认 false，仅联机战斗置 true，首点同时兼容旧布尔缓存。
var _has_network_extraction_positions: bool = false
## 是否已经预生成联机撤离点位置；默认 false，仅联机战斗置 true。
var _has_network_extraction_position: bool = false
## 联机大逃杀模式是否激活；默认 false，进入场景时从 NetworkSession 解析，影响出生点分散与玩家互伤。
var _network_battle_royale_active: bool = false
## 联机全员出生点表；键为 peer_id，值为世界坐标，大逃杀模式下由共享随机流确定性推导，组队模式为空。
var _network_spawn_positions: Dictionary = {}
## 联机敌人人口倍率；默认 1.0，开局按成员数量解析为 1.5 的（成员数-1）次幂并在本局内固定，仅主机的人口逻辑消费。
var _network_population_multiplier: float = 1.0
## 怪物管理器未应用任何模式倍率前的实体化上限；协议层数变化时从该值重算，避免在旧倍率上重复相乘。
var _base_materialized_monster_limit: int = 0

## 玩家节点缓存；默认按 player_path 获取，允许为空并以世界原点作为生成中心。
@onready var _player: Node2D = get_node_or_null(player_path) as Node2D
## 当前角色运行时配置组件缓存；缺失时继续执行本脚本保留的旧初始化流程，保证迁移场景可独立运行。
@onready var _selected_character_runtime_component: Node = get_node_or_null(selected_character_runtime_component_path)
## 玩家摄像机缓存；默认按 player_camera_path 获取，缺失时探索系统回退 exploration_radius 圆形范围。
@onready var _player_camera: Camera2D = get_node_or_null(player_camera_path) as Camera2D
## 环境物父节点缓存；默认按 environment_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _environment_parent: Node = get_node_or_null(environment_parent_path)
## 怪物父节点缓存；默认按 monster_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _monster_parent: Node = get_node_or_null(monster_parent_path)
## 怪物加载管理器缓存；默认按 monster_simulation_manager_path 获取，缺失时怪物仍可运行但不会远距离休眠。
@onready var _monster_simulation_manager: Node = get_node_or_null(monster_simulation_manager_path)
## 掉落物父节点缓存；默认按 drop_parent_path 获取，允许为空并回退到当前 GameWorld。
@onready var _drop_parent: Node = get_node_or_null(drop_parent_path)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# 清空伤害飘字的跨局静态追踪；上一局死亡目标的实例 ID 不会复用，进入新战斗时统一释放残留键。
	DamageNumberPopup.reset_tracking()
	_random.randomize()
	_merge_automatically_discovered_content()
	_apply_session_state()
	_create_hack_protocol_component()
	# 骇入模式玩家规则；角色应用完成后立即写入超频等模式的能量、耐久与技能冷却豁免。
	_apply_hack_variant_player_rules()
	_resolve_network_combat_session()
	_begin_global_inventory_run()
	_prepare_map_seed()
	_environment_obstacle_rects.clear()
	_environment_feature_bounds.clear()
	_loot_chest_obstacle_rects.clear()
	_navigation_grid_cache.clear()
	_spawn_boundary_walls()
	_spawn_random_environment()
	_spawn_loot_chests()
	# 首次引导聚焦正式撤离；隐藏物资送回点，避免新玩家把“送回物品”误认为结束本局。
	if not _is_first_run_tutorial:
		_spawn_supply_extraction_points()
	_environment_obstacle_version += 1
	if _network_combat_active:
		# 联机撤离点预推导；此刻全员环境障碍、宝箱缓存与玩家位置（出生原点）完全一致，专用随机流保证各端得到同一位置。
		# 注意必须先于大逃杀传送执行：撤离点校验读取玩家位置，传送后各端玩家位置不同会破坏确定性。
		_network_extraction_positions = _get_random_extraction_positions(_get_effective_extraction_point_count())
		_has_network_extraction_positions = not _network_extraction_positions.is_empty()
		# 首个联机撤离点；继续同步旧单点缓存，保证尚未升级的读取接口仍能获得有效位置。
		_network_extraction_position = _network_extraction_positions.front() if _has_network_extraction_positions else Vector2.ZERO
		_has_network_extraction_position = _has_network_extraction_positions
		if _network_battle_royale_active:
			# 大逃杀出生点表必须先于开局布怪推导；主机布怪据此避开每名玩家出生点周围的安全距离，防止玩家降生在怪堆中。
			_compute_battle_royale_spawn_positions()
	if not _is_network_remote_client():
		# 联机客户端不初始化虚拟人口；全部敌人由主机权威复制，本机只承载傀儡节点。
		if _monster_simulation_manager != null and _monster_simulation_manager.has_method("initialize"):
			# 怪物挂载父节点；优先使用 Enemies 容器，缺失时回退 GameWorld，供加载管理器按需创建真实节点。
			var spawn_parent: Node = _monster_parent if _monster_parent != null else self
			_monster_simulation_manager.call("initialize", _player, spawn_parent, _player, TRAINING_MONSTER_GROUP)
			if _monster_simulation_manager.has_signal("virtual_monster_died") and not _monster_simulation_manager.is_connected("virtual_monster_died", Callable(self, "_on_monster_died")):
				_monster_simulation_manager.connect("virtual_monster_died", Callable(self, "_on_monster_died"))
			if _monster_simulation_manager.has_signal("monster_encountered") and not _monster_simulation_manager.is_connected("monster_encountered", Callable(self, "_on_monster_encountered")):
				_monster_simulation_manager.connect("monster_encountered", Callable(self, "_on_monster_encountered"))
			if _monster_simulation_manager.has_method("set_mode_extension_multipliers"):
				# 怪物扩展倍率；虚拟人口每次物化时统一应用，反复卸载与恢复不会重复叠加。
				_monster_simulation_manager.call("set_mode_extension_multipliers", _mode_extension_effect_multipliers)
			if _monster_simulation_manager.has_method("set_newcomer_protection_multiplier"):
				# 新手保护倍率；由主机本地档案决定，虚拟人口和直接实例化回退路径均使用同一倍率。
				_monster_simulation_manager.call("set_newcomer_protection_multiplier", _get_newcomer_protection_monster_attribute_multiplier())
			# 同时活跃敌人上限缩放；骇入模式倍率（零装 0.6、超频 2.0）与联机成员倍率统一应用，标准单机保持原值。
			_base_materialized_monster_limit = int(_monster_simulation_manager.get("max_materialized_monsters"))
			_refresh_hack_protocol_population_limit()
		# 引导锚点敌人；始终使用普通怪物兜底场景在玩家附近创建一条虚拟记录，不生成任何精英怪。
		_spawn_first_run_tutorial_anchor_monster()
		_spawn_monster_batch()
		if _is_first_run_tutorial and _monster_simulation_manager != null and _monster_simulation_manager.has_method("refresh_all"):
			# 引导即时物化；让附近锚点敌人在开局首批扫描中出现，无需等待全地图人口轮询。
			_monster_simulation_manager.call("refresh_all")
	_monster_replenish_remaining = monster_replenish_interval
	if _network_combat_active:
		if _network_battle_royale_active:
			_teleport_local_player_to_network_spawn()
		_create_network_combat_sync()
	_update_explored_cells(true)


func _process(delta: float) -> void:
	_update_survival_time(delta)
	_update_extraction_state(delta)
	_update_supply_extraction_state(delta)
	_update_explored_cells_if_needed(delta)
	_update_background_grid_redraw()
	_update_monster_replenishment(delta)
	if _monster_simulation_manager != null and _monster_simulation_manager.has_method("update"):
		_monster_simulation_manager.call("update", delta)


func _draw() -> void:
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，无固定默认值，修改会影响背景矩形和线段端点。
	var half_size: float = grid_size * float(grid_extent)
	# 背景绘制区域；取值为以世界原点居中的 Rect2，无固定默认值，修改会影响可视背景覆盖范围。
	var play_area: Rect2 = Rect2(Vector2(-half_size, -half_size), Vector2(half_size * 2.0, half_size * 2.0))
	draw_rect(play_area, base_floor_color, true)

	# 有效背景网格尺寸；最低为 1 像素，异常检查器数据不会导致零步长循环。
	var resolved_background_grid_cell_size: float = maxf(background_grid_cell_size, 1.0)
	# 网格绘制窗口；默认只覆盖玩家相机可见范围外扩一格并夹取到地图内，避免每帧提交覆盖全图的数百条线段命令。
	var grid_window: Rect2 = _get_background_grid_draw_window(play_area, resolved_background_grid_cell_size)
	# 纵向网格线偏移；从窗口左边界内的首个整格倍数开始，逐格绘制到窗口右边界。
	var vertical_line_offset: float = ceilf(grid_window.position.x / resolved_background_grid_cell_size) * resolved_background_grid_cell_size
	while vertical_line_offset <= grid_window.end.x:
		draw_line(Vector2(vertical_line_offset, grid_window.position.y), Vector2(vertical_line_offset, grid_window.end.y), grid_color, 1.0)
		vertical_line_offset += resolved_background_grid_cell_size
	# 横向网格线偏移；从窗口上边界内的首个整格倍数开始，逐格绘制到窗口下边界。
	var horizontal_line_offset: float = ceilf(grid_window.position.y / resolved_background_grid_cell_size) * resolved_background_grid_cell_size
	while horizontal_line_offset <= grid_window.end.y:
		draw_line(Vector2(grid_window.position.x, horizontal_line_offset), Vector2(grid_window.end.x, horizontal_line_offset), grid_color, 1.0)
		horizontal_line_offset += resolved_background_grid_cell_size

	# 地图边框颜色；取值来自 axis_color，默认用于网格地图边界提示。
	var border_color: Color = axis_color
	draw_rect(play_area, border_color, false, 2.0)


func _get_background_grid_draw_window(play_area: Rect2, grid_cell_size: float) -> Rect2:
	# 背景网格绘制窗口；玩家相机存在时取其世界视野外扩一格，缺失时回退整张地图保持原有表现。
	if _player_camera == null or not is_instance_valid(_player_camera):
		return play_area
	# 相机世界视野；外扩一格避免相机移动时网格线在屏幕边缘出现迟到绘制。
	var camera_view_rect: Rect2 = _get_player_camera_world_view_rect().grow(grid_cell_size)
	return camera_view_rect.intersection(play_area)


func _update_background_grid_redraw() -> void:
	# 玩家相机缺失时背景按全图绘制，无需跟随相机刷新。
	if _player_camera == null or not is_instance_valid(_player_camera):
		return
	# 有效网格步长；与绘制阶段保持一致，保证签名与实际线位对齐。
	var grid_cell_size: float = maxf(background_grid_cell_size, 1.0)
	# 当前相机世界视野；用于计算按网格步长取整的可见格边界。
	var camera_view_rect: Rect2 = _get_player_camera_world_view_rect()
	# 当前网格窗口签名；只有相机跨过网格线或视野尺寸变化时签名才变化，从而触发一次背景重绘。
	var window_signature: Vector4i = Vector4i(
		int(floorf(camera_view_rect.position.x / grid_cell_size)),
		int(floorf(camera_view_rect.position.y / grid_cell_size)),
		int(ceilf(camera_view_rect.end.x / grid_cell_size)),
		int(ceilf(camera_view_rect.end.y / grid_cell_size))
	)
	if window_signature != _last_grid_window_signature:
		_last_grid_window_signature = window_signature
		queue_redraw()


func _prepare_map_seed() -> void:
	_active_map_seed = map_seed
	if _active_map_seed == 0:
		_active_map_seed = int(_random.randi())

	_random.seed = _active_map_seed
	queue_redraw()


func _resolve_network_combat_session() -> void:
	## 解析联机战斗会话；联机时用主机广播的共享种子覆盖地图种子，使全员复现同一张地图、宝箱与物资撤离点，训练场不参与联机。
	_network_combat_active = false
	_network_is_host = false
	_network_battle_royale_active = false
	_network_spawn_positions.clear()
	_network_population_multiplier = 1.0
	_network_extraction_random = null
	_network_extraction_positions.clear()
	_has_network_extraction_positions = false
	_network_extraction_position = Vector2.ZERO
	_has_network_extraction_position = false
	# 联机会话服务；由自动加载提供，缺失或战斗会话未激活时保持单机流程。
	var network_session: Node = get_tree().root.get_node_or_null("NetworkSession")
	if network_session == null or not network_session.has_method("is_combat_session_active"):
		return
	if _is_training_mode or not bool(network_session.call("is_combat_session_active")):
		return
	_network_combat_active = true
	_network_is_host = bool(network_session.call("is_session_host"))
	_network_battle_royale_active = network_session.has_method("is_battle_royale_mode") and bool(network_session.call("is_battle_royale_mode"))
	# 本局成员数量；开局时刻的名册规模决定人口倍率，中途离场不缩减本局人口目标。
	var member_count: int = (network_session.call("get_roster_snapshot") as Array).size()
	_network_population_multiplier = pow(NETWORK_POPULATION_MULTIPLIER_PER_EXTRA_PLAYER, maxf(float(member_count - 1), 0.0))
	# 共享地图种子；非零时覆盖检查器种子，_prepare_map_seed 将据此产生确定性世界。
	var shared_seed: int = int(network_session.call("get_shared_map_seed"))
	if shared_seed != 0:
		map_seed = shared_seed
	# 联机撤离点随机源；以共享种子加固定偏移派生独立随机流，客户端跳过怪物随机消耗也不影响撤离点一致性。
	_network_extraction_random = RandomNumberGenerator.new()
	_network_extraction_random.seed = shared_seed + NETWORK_EXTRACTION_SEED_OFFSET


func _create_network_combat_sync() -> void:
	## 创建战斗网络同步器；同步器负责队友化身、敌人复制、掉落与宝箱仲裁，单机不创建该节点。
	_network_combat_sync = NETWORK_COMBAT_SYNC_SCRIPT.new() as Node2D
	if _network_combat_sync == null:
		return
	_network_combat_sync.name = "NetworkCombatSync"
	add_child(_network_combat_sync)
	# 傀儡挂载父节点；与敌人生成使用同一 Enemies 容器回退规则。
	var spawn_parent: Node = _monster_parent if _monster_parent != null else self
	_network_combat_sync.call("initialize", self, _player, spawn_parent, _monster_simulation_manager)
	if _network_combat_sync.has_signal("hack_protocol_team_state_changed"):
		_network_combat_sync.connect("hack_protocol_team_state_changed", Callable(self, "_on_hack_protocol_team_state_changed"))
	_refresh_hack_protocol_population_limit()


func _create_hack_protocol_component() -> void:
	## 为本地玩家创建局内协议组件；未启用扩展、训练场或玩家缺失时完全不产生额外运行期状态。
	if not _hack_protocol_enabled or _player == null or _hack_protocol_component != null:
		return
	_hack_protocol_component = HACK_PROTOCOL_COMPONENT_SCRIPT.new()
	_hack_protocol_component.name = "HackProtocolComponent"
	_player.add_child(_hack_protocol_component)
	if _is_first_run_tutorial and _hack_protocol_component.has_method("set_first_offer_override_ids"):
		# 引导首轮协议；固定三个易理解候选，后续轮次恢复完整随机池。
		_hack_protocol_component.call("set_first_offer_override_ids", tutorial_first_protocol_offer_ids)
	if _player.has_method("set_hack_protocol_component"):
		_player.call("set_hack_protocol_component", _hack_protocol_component)
	if _hack_protocol_component.has_signal("protocols_changed"):
		_hack_protocol_component.connect("protocols_changed", Callable(self, "_on_local_hack_protocols_changed"))


func get_hack_protocol_component() -> Node:
	## 返回本机玩家的局内协议组件；扩展未启用时返回 null，HUD 不需要自行推断节点结构。
	return _hack_protocol_component


func is_hack_protocol_enabled() -> bool:
	## 返回本局是否启用了骇入协议扩展；仅正式骇入可为 true。
	return _hack_protocol_enabled


func _on_local_hack_protocols_changed(_protocol_ids: Array[String]) -> void:
	## 单机协议层数变化时立即重算人口上限；联机同步器会再发团队状态信号并使用全队平均值校正。
	if _is_first_run_tutorial and not _protocol_ids.is_empty():
		_tutorial_first_protocol_acquired = true
	_refresh_hack_protocol_population_limit()


func _on_hack_protocol_team_state_changed() -> void:
	## 多人协议快照变化时刷新动态人口上限；每名成员独立协议数先求平均，再进入统一倍率公式。
	_refresh_hack_protocol_population_limit()


func _refresh_hack_protocol_population_limit() -> void:
	## 从未缩放基础值重算实体化上限；开局协议数为 0 时严格保持原模式与联机规则结果。
	if _monster_simulation_manager == null or _base_materialized_monster_limit <= 0:
		return
	_monster_simulation_manager.set("max_materialized_monsters", _apply_population_scales(_base_materialized_monster_limit))


func _get_average_hack_protocol_count() -> float:
	## 返回当前动态代价使用的协议层级；多人读取同步器团队均值，单机读取本地协议总层数。
	if not _hack_protocol_enabled:
		return 0.0
	if _network_combat_active and _network_combat_sync != null and _network_combat_sync.has_method("get_team_average_hack_protocol_count"):
		return maxf(float(_network_combat_sync.call("get_team_average_hack_protocol_count")), 0.0)
	return float(_hack_protocol_component.call("get_acquired_protocol_count")) if _hack_protocol_component != null and _hack_protocol_component.has_method("get_acquired_protocol_count") else 0.0


func _is_network_remote_client() -> bool:
	## 返回本机是否为联机客户端；客户端不生成、不补充敌人，全部敌人来自主机复制。
	return _network_combat_active and not _network_is_host


func is_network_combat_active() -> bool:
	## 返回当前世界是否处于联机战斗；HUD 与调试工具据此调整暂停与人口展示行为。
	return _network_combat_active


func is_network_battle_royale() -> bool:
	## 返回当前是否为联机大逃杀模式；战斗同步器据此开启队友化身的玩家互伤碰撞层。
	return _network_battle_royale_active


func get_network_spawn_position_for_peer(peer_id: int) -> Vector2:
	## 返回指定成员的联机出生点；大逃杀返回确定性推导结果，组队模式或未知成员回退本机玩家当前位置。
	# 出生点条目；表中缺失时使用回退位置。
	var spawn_entry: Variant = _network_spawn_positions.get(peer_id)
	if spawn_entry is Vector2:
		return spawn_entry
	return _player.global_position if _player != null else Vector2.ZERO


func _compute_battle_royale_spawn_positions() -> void:
	## 推导大逃杀全员出生点表；本机玩家的实际传送由 _teleport_local_player_to_network_spawn 在主机布怪完成后执行。
	## 各端使用同一共享随机流与同一环境缓存执行相同算法，因此无需网络传输即可得到全网一致的出生点表。
	# 联机会话服务；提供按 peer_id 排序的成员名册，排序保证各端推导顺序一致。
	var network_session: Node = get_tree().root.get_node_or_null("NetworkSession")
	if network_session == null or _player == null:
		return
	# 出生点专用随机流；与地图主随机流及撤离点随机流互相独立。
	var spawn_random: RandomNumberGenerator = RandomNumberGenerator.new()
	spawn_random.seed = _active_map_seed + BATTLE_ROYALE_SPAWN_SEED_OFFSET
	# 成员 peer_id 有序列表；名册快照本身按 peer_id 升序，此处再排序一次作为确定性保险。
	var sorted_peer_ids: Array[int] = []
	for member_profile in (network_session.call("get_roster_snapshot") as Array):
		sorted_peer_ids.append(int((member_profile as Dictionary).get("peer_id", 0)))
	sorted_peer_ids.sort()
	# 出生点候选上限；地图半边长扣除边缘留白，保证出生视野完整。
	var spawn_limit: float = maxf(get_map_half_size() - BATTLE_ROYALE_SPAWN_EDGE_MARGIN, 1.0)
	# 已确定出生点列表；后续成员的候选需要与之保持最小间距。
	var placed_positions: Array[Vector2] = []
	_network_spawn_positions.clear()
	for peer_id in sorted_peer_ids:
		# 本成员最终出生点；全部尝试失败时保留最后一个候选，各端因同随机流得到相同回退结果。
		var resolved_position: Vector2 = Vector2.ZERO
		for _attempt_index in range(BATTLE_ROYALE_SPAWN_ATTEMPT_COUNT):
			# 当前候选出生点；在留白后的地图范围内均匀抽取。
			var candidate_position: Vector2 = Vector2(spawn_random.randf_range(-spawn_limit, spawn_limit), spawn_random.randf_range(-spawn_limit, spawn_limit))
			resolved_position = candidate_position
			if _is_position_blocked_by_environment(candidate_position, BATTLE_ROYALE_SPAWN_CLEARANCE_RADIUS):
				continue
			# 是否离已确定出生点过近；保证开局玩家彼此分散。
			var too_close_to_placed: bool = false
			for placed_position in placed_positions:
				if placed_position.distance_to(candidate_position) < BATTLE_ROYALE_SPAWN_MIN_SPACING:
					too_close_to_placed = true
					break
			if not too_close_to_placed:
				break
		placed_positions.append(resolved_position)
		_network_spawn_positions[int(peer_id)] = resolved_position


func _teleport_local_player_to_network_spawn() -> void:
	## 把本机玩家传送到自己的大逃杀出生点；其余成员位置由化身状态同步呈现。
	# 联机会话服务；提供本机 peer_id。
	var network_session: Node = get_tree().root.get_node_or_null("NetworkSession")
	if network_session == null or _player == null:
		return
	# 本机出生点条目；异常缺失时保持原点出生。
	var local_spawn_entry: Variant = _network_spawn_positions.get(int(network_session.call("get_local_peer_id")))
	if local_spawn_entry is Vector2:
		_player.global_position = local_spawn_entry
		if _player.has_method("clear_external_motion"):
			_player.call("clear_external_motion")


func _get_extraction_random_source() -> RandomNumberGenerator:
	## 返回撤离点使用的随机源；联机时使用共享种子派生的专用随机流，单机沿用主随机源保持旧行为。
	return _network_extraction_random if _network_extraction_random != null else _random


func is_training_mode() -> bool:
	# 会话状态节点；默认由自动加载提供，允许 HUD 在 GameWorld ready 前也能读到正确模式。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("is_training_mode"):
		return bool(session_state.call("is_training_mode"))

	return _is_training_mode


func is_first_run_tutorial() -> bool:
	## 返回本世界是否正在执行一次性首次战斗引导；HUD 只依赖该接口选择教学展示和独立结算。
	return _is_first_run_tutorial


func get_first_run_tutorial_objective_text() -> String:
	## 返回当前引导阶段的单一行动目标；文本由战斗事实推导，不保存冗余阶段编号，死亡复活后仍可继续原目标。
	if not _is_first_run_tutorial:
		return ""
	if not _tutorial_first_enemy_defeated:
		return "W/A/S/D 移动 · 左键远程攻击 · 右键近战攻击｜击败附近的普通敌人"
	if not _tutorial_first_chest_opened:
		return "按 F 拾取“陷阵”，按 E 打开背包装备｜前往金色标记并长按 F 开启宝箱"
	if not _tutorial_first_protocol_acquired:
		return "数据碎片已充足｜从三个骇入协议中选择一项"
	if not _has_extraction_point:
		return "可用 C / V / B 施放主动技能｜生存至 02:00，等待撤离信号"
	if not _player_inside_extraction_area:
		return "撤离点已标记｜按 Q 查看地图，前往绿色撤离点"
	if not _extraction_ready_to_leave:
		return "保持在撤离区域内｜累计驻留 %.1f 秒" % get_extraction_hold_duration_seconds()
	return "撤离准备完成｜按 Space 完成本次新手引导"


func get_hack_variant() -> String:
	## 返回本局骇入模式变体；训练场固定返回标准值，HUD、统计与联机侧按需读取。
	return _hack_variant


func is_minimap_disabled_by_mode_extension() -> bool:
	## 返回右上角局部小地图是否被模式扩展禁用；完整大地图与暂停地图不受“禁用小地图”词条影响。
	return bool(_mode_extension_effect_multipliers.get("disable_minimap", false))


func is_settlement_disabled_mode() -> bool:
	## 返回本局是否不产出物品得失结算；训练场与超频骇入（娱乐模式）都返回 true。
	## HUD 据此切换“离开”按钮、死亡复活与拾取消耗行为，库存服务在这些模式下不开启战斗快照。
	return is_training_mode() or not HackModeRules.is_settlement_enabled(_hack_variant)


func _apply_hack_variant_player_rules() -> void:
	## 把当前骇入模式的玩家规则豁免写入玩家组件；标准与零装模式全部保持默认值，超频模式开启三类豁免。
	## 模式扩展补充：汇总倍率同时写入对应独立组件，各组件不解析具体词条。
	## 该函数只在入场时调用一次；全部开关都属于场景内组件状态，离开战斗后自动失效，不写入任何存档。
	if _player == null:
		return
	# 战斗属性组件；通过已导出的玩家属性路径解析，避免预制体节点名变动使超频无限能量开关失效。
	var stats_component: Node = _player.get_node_or_null(player_stats_component_path)
	if HackModeRules.is_energy_consumption_disabled(_hack_variant) and stats_component != null and stats_component.has_method("set_infinite_energy"):
		stats_component.call("set_infinite_energy", true)
	# 武器耐久豁免；写入玩家控制器的模式级开关，与开发者调试开关互不覆盖。
	if HackModeRules.is_durability_consumption_disabled(_hack_variant) and _player.has_method("set_weapon_durability_consumption_disabled_by_mode"):
		_player.call("set_weapon_durability_consumption_disabled_by_mode", true)
	if _player.has_method("set_weapon_durability_consumption_multiplier_by_mode_extension"):
		# 武器耐久消耗倍率；风险合约“耐久消耗翻倍”写入 2.0，其余配置保持 1.0。
		_player.call("set_weapon_durability_consumption_multiplier_by_mode_extension", float(_mode_extension_effect_multipliers.get("durability_consumption_multiplier", 1.0)))
	# 装备组件；防具耐久豁免与武器豁免分开挂载，保持两类耐久规则各自可测试。
	var equipment_component: Node = _player.get_node_or_null("EquipmentComponent")
	if HackModeRules.is_durability_consumption_disabled(_hack_variant) and equipment_component != null and equipment_component.has_method("set_armor_durability_consumption_disabled_by_mode"):
		equipment_component.call("set_armor_durability_consumption_disabled_by_mode", true)
	if equipment_component != null and equipment_component.has_method("set_armor_durability_consumption_multiplier_by_mode_extension"):
		# 防具耐久消耗倍率；与武器使用同一风险词条汇总值，保证两类耐久都准确翻倍。
		equipment_component.call("set_armor_durability_consumption_multiplier_by_mode_extension", float(_mode_extension_effect_multipliers.get("durability_consumption_multiplier", 1.0)))
	if equipment_component != null and equipment_component.has_method("set_vision_multiplier_by_mode_extension"):
		# 玩家视野倍率；作为最终视野独立乘区，0.75 与 0.50 分别表示总视野降低 25% 与 50%。
		equipment_component.call("set_vision_multiplier_by_mode_extension", float(_mode_extension_effect_multipliers.get("player_vision_multiplier", 1.0)))
	# 主动技能组件；超频模式把技能冷却写入倍率降到规则表配置值，训练场无冷却开关优先级更高。
	var active_skill_component: Node = _player.get_node_or_null("ActiveSkillComponent")
	if active_skill_component != null and active_skill_component.has_method("set_mode_cooldown_scale"):
		active_skill_component.call("set_mode_cooldown_scale", HackModeRules.get_skill_cooldown_scale(_hack_variant))


func get_selected_character_id() -> String:
	return _selected_character_id


func get_selected_character_name() -> String:
	return _get_character_display_name(_selected_character_id)


func get_map_half_size() -> float:
	return grid_size * float(grid_extent)


func get_minimap_obstacle_rects(include_loot_chests: bool = true) -> Array[Rect2]:
	# 障碍矩形副本；局部小地图可排除宝箱，完整地图仍可按已探索规则显示其建筑占位。
	var result: Array[Rect2] = []
	# 宝箱矩形查找表；提前构建一次，避免在循环体内反复重建 values() 数组造成 O(n²) 扫描。
	var loot_chest_rect_lookup: Dictionary = {}
	if not include_loot_chests:
		for loot_chest_rect in _loot_chest_obstacle_rects.values():
			loot_chest_rect_lookup[loot_chest_rect] = true
	# 障碍矩形遍历项；取值为世界坐标 Rect2，默认逐项复制到返回数组。
	for obstacle_rect in _environment_obstacle_rects:
		if not include_loot_chests and loot_chest_rect_lookup.has(obstacle_rect):
			continue
		result.append(obstacle_rect)

	return result


func get_minimap_obstacle_rects_readonly() -> Array[Rect2]:
	# 障碍矩形内部数组引用；供敌人战术选点等高频只读调用方使用，禁止调用方修改返回数组。
	return _environment_obstacle_rects


func get_minimap_obstacle_version() -> int:
	return _environment_obstacle_version


func get_explored_cells() -> Array[Vector2i]:
	# 已探索格子列表；元素为 Vector2i，默认从字典键复制，供大地图迷雾绘制使用。
	var result: Array[Vector2i] = []
	# 已探索格子键遍历项；取值来自 _explored_cells 的所有键，默认只收集 Vector2i。
	for explored_cell in _explored_cells.keys():
		if explored_cell is Vector2i:
			result.append(explored_cell)

	return result


func get_explored_cells_version() -> int:
	return _explored_cells_version


func get_explored_cells_readonly() -> Dictionary:
	# 已探索格子内部字典引用；键为 Vector2i 格坐标，供小地图等高频只读调用方直接查询，禁止调用方修改。
	return _explored_cells


func has_explored_cell(cell: Vector2i) -> bool:
	# 单格探索状态查询；避免调用方为一次判断复制整张探索格列表。
	return _explored_cells.has(cell)


func get_exploration_cell_size() -> float:
	return maxf(exploration_cell_size, 1.0)


func is_world_position_explored(world_position: Vector2) -> bool:
	# 世界位置探索状态；地图标记通过同一迷雾格查询，未进入玩家探索范围的撤离点不会提前泄露。
	return _explored_cells.has(_world_position_to_exploration_cell(world_position))


func unlock_full_map_vision() -> int:
	# 有效探索格尺寸；用于把完整地图边界稳定拆分为与常规探索相同的缓存键。
	var cell_size: float = get_exploration_cell_size()
	# 地图半边长；完整解锁只覆盖实际战斗地图，不在边界外创建无意义探索格。
	var half_size: float = get_map_half_size()
	# 最小探索格坐标；向下取整确保包含地图负方向边缘。
	var minimum_cell: Vector2i = Vector2i(floori(-half_size / cell_size), floori(-half_size / cell_size))
	# 最大探索格坐标；向上取整后减一，确保包含地图正方向边缘且不多出整格。
	var maximum_cell: Vector2i = Vector2i(ceili(half_size / cell_size) - 1, ceili(half_size / cell_size) - 1)
	# 新增探索格数量；用于开发者界面反馈，已解锁格不会重复计数。
	var unlocked_cell_count: int = 0
	# 完整地图 X 格遍历；覆盖最小到最大探索格的全部横向坐标。
	for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
		# 完整地图 Y 格遍历；与当前 X 坐标组合形成每个地图探索格。
		for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
			# 当前完整地图探索格；写入后大小地图会在下一次缓存刷新时显示对应墙体和标记。
			var explored_cell: Vector2i = Vector2i(cell_x, cell_y)
			if _explored_cells.has(explored_cell):
				continue
			_explored_cells[explored_cell] = true
			unlocked_cell_count += 1
	if unlocked_cell_count > 0:
		_explored_cells_version += 1
	return unlocked_cell_count


func get_survival_time_seconds() -> float:
	return maxf(_survival_time_seconds, 0.0)


func add_training_survival_time() -> float:
	# 增加后的存活时间；使用统一导出参数，确保训练按钮与撤离阶段判定共享同一数值来源。
	_survival_time_seconds += maxf(training_time_addition_seconds, 1.0)
	_update_extraction_timeline()
	return get_survival_time_seconds()


func get_alive_monster_count() -> int:
	return _get_alive_monster_count()


func has_extraction_point_spawned() -> bool:
	return _has_extraction_point


func is_extraction_point_marked_on_map() -> bool:
	return _extraction_point_marked_on_map


func is_player_inside_extraction_area() -> bool:
	return _player_inside_extraction_area


func is_extraction_ready_to_leave() -> bool:
	return _extraction_ready_to_leave


func get_extraction_hold_elapsed_seconds() -> float:
	return maxf(_extraction_hold_elapsed_seconds, 0.0)


func get_extraction_hold_duration_seconds() -> float:
	return maxf(extraction_hold_duration_seconds, 0.1)


func get_extraction_point_position() -> Vector2:
	## 旧单点位置读取接口；多点模式下始终返回排序生成的首个撤离点，供历史调用方平滑兼容。
	return _extraction_point_position


func get_extraction_point_positions() -> Array[Vector2]:
	## 返回全部正式撤离点位置副本；小地图和联机显示应使用该接口，不得修改世界内部列表。
	return _extraction_point_positions.duplicate()


func get_supply_extraction_positions() -> Array[Vector2]:
	# 位置副本；地图 UI 和 HUD 只能读取，不能修改世界内部点位状态。
	return _supply_extraction_positions.duplicate()


func is_player_inside_supply_extraction_area() -> bool:
	return _active_supply_extraction_index >= 0


func is_supply_extraction_ready() -> bool:
	return _supply_extraction_ready


func get_supply_extraction_hold_elapsed_seconds() -> float:
	return maxf(_supply_extraction_hold_elapsed_seconds, 0.0)


func get_supply_extraction_hold_duration_seconds() -> float:
	return maxf(supply_extraction_hold_duration_seconds, 0.1)


func set_navigation_marker(marker_position: Vector2) -> void:
	_navigation_marker_position = _clamp_position_to_map(marker_position)
	_has_navigation_marker = true


func clear_navigation_marker() -> void:
	_has_navigation_marker = false
	_navigation_marker_position = Vector2.ZERO


func has_navigation_marker() -> bool:
	return _has_navigation_marker


func get_navigation_marker_position() -> Vector2:
	return _navigation_marker_position


func set_skill_map_marker(marker_id: String, marker_position: Vector2, marker_kind: String = "generic") -> void:
	## 新增或覆盖一个技能专属地图标记；相同 ID 始终只保留一个，位置限制在当前地图边界内。
	var normalized_marker_id: String = marker_id.strip_edges()
	if normalized_marker_id.is_empty():
		return
	_skill_map_markers[normalized_marker_id] = {
		"id": normalized_marker_id,
		"position": _clamp_position_to_map(marker_position),
		"kind": marker_kind.strip_edges() if not marker_kind.strip_edges().is_empty() else "generic",
	}


func remove_skill_map_marker(marker_id: String) -> void:
	## 移除指定技能地图标记；不存在时保持幂等，不影响其他技能或玩家导航点。
	_skill_map_markers.erase(marker_id.strip_edges())


func get_skill_map_markers() -> Array[Dictionary]:
	## 返回技能地图标记深拷贝；地图控件可以绘制但不能修改世界内部标记表。
	var markers: Array[Dictionary] = []
	for raw_marker in _skill_map_markers.values():
		if raw_marker is Dictionary:
			markers.append((raw_marker as Dictionary).duplicate(true))
	return markers


func teleport_player_to_nearest_clear_position() -> bool:
	if _player == null:
		return false
	# 搜索格尺寸；至少 16 像素，避免过细网格造成不必要的整图导航缓存开销。
	var resolved_cell_size: float = maxf(unstuck_search_cell_size, 16.0)
	# 安全半径；至少等于玩家碰撞半径 18，确保候选点周围不会紧贴障碍物。
	var resolved_clearance_radius: float = maxf(unstuck_clearance_radius, 18.0)
	# 脱离导航网格；复用 GameWorld 的障碍缓存，并按玩家安全半径扩张所有障碍。
	var navigation_grid: AStarGrid2D = _get_cached_navigation_grid(resolved_cell_size, resolved_clearance_radius)
	# 导航区域；用于限制逐圈候选格始终位于地图内。
	var navigation_region: Rect2i = navigation_grid.region
	# 玩家原始格；从当前世界坐标转换并限制在合法导航区域。
	var origin_cell: Vector2i = _clamp_navigation_cell_to_region(_world_position_to_navigation_cell(_player.global_position, resolved_cell_size), navigation_region)
	# 最终安全位置；默认零向量，仅在找到候选点后使用。
	var safe_position: Vector2 = Vector2.ZERO
	# 是否找到安全位置；默认 false，搜索成功后终止后续外圈遍历。
	var safe_position_found: bool = false
	# 搜索圈半径；从玩家所在格外侧第一圈开始，避免按钮执行后仍停留在原地。
	for search_radius in range(1, maxi(unstuck_max_search_radius, 1) + 1):
		# 当前搜索圈候选位置；先收集同一圈全部安全格，再选择真实距离最近者。
		var ring_candidates: Array[Vector2] = []
		# 横向格偏移；遍历当前方形搜索圈的完整宽度。
		for offset_x in range(-search_radius, search_radius + 1):
			# 纵向格偏移；与横向偏移共同筛选当前搜索圈边界格。
			for offset_y in range(-search_radius, search_radius + 1):
				if abs(offset_x) != search_radius and abs(offset_y) != search_radius:
					continue
				# 候选格；由原始格加当前外圈偏移形成。
				var candidate_cell: Vector2i = origin_cell + Vector2i(offset_x, offset_y)
				if not _is_navigation_cell_in_region(candidate_cell, navigation_region) or navigation_grid.is_point_solid(candidate_cell):
					continue
				# 候选世界坐标；使用格子中心并再次通过障碍矩形精确检查安全半径。
				var candidate_position: Vector2 = _navigation_cell_to_world_position(candidate_cell, resolved_cell_size)
				if _is_position_blocked_by_environment(candidate_position, resolved_clearance_radius):
					continue
				ring_candidates.append(candidate_position)
		if ring_candidates.is_empty():
			continue
		# 最近候选距离；默认使用本圈第一个候选初始化，随后选择离玩家当前位置最近的安全点。
		var nearest_distance: float = _player.global_position.distance_squared_to(ring_candidates[0])
		safe_position = ring_candidates[0]
		# 本圈安全候选；逐个比较与玩家当前位置的真实距离，选择最近点。
		for candidate_position in ring_candidates:
			# 当前候选距离；使用平方距离避免无意义开方。
			var candidate_distance: float = _player.global_position.distance_squared_to(candidate_position)
			if candidate_distance < nearest_distance:
				nearest_distance = candidate_distance
				safe_position = candidate_position
		safe_position_found = true
		break
	if not safe_position_found:
		return false
	_player.global_position = safe_position
	if _player.has_method("clear_external_motion"):
		_player.call("clear_external_motion")
	elif _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = Vector2.ZERO
	_update_explored_cells(true)
	return true


func find_navigation_path(start_position: Vector2, end_position: Vector2, agent_radius: float = 24.0, navigation_cell_size: float = 96.0, max_path_points: int = 64) -> Array[Vector2]:
	# 路径结果；元素为世界坐标路点，默认空数组表示无法找到可用路径。
	var result: Array[Vector2] = []
	# 标准化寻路格尺寸；取值至少 16 像素，默认避免格子过小导致临时网格开销过大。
	var resolved_cell_size: float = maxf(navigation_cell_size, 16.0)
	# 标准化代理半径；取值至少为 0，默认用于匹配怪物碰撞体与墙体安全间距。
	var resolved_agent_radius: float = maxf(agent_radius, 0.0)
	# 缓存寻路网格；取值为按格子尺寸和代理半径缓存的 AStarGrid2D，默认复用地图障碍标记结果。
	var navigation_grid: AStarGrid2D = _get_cached_navigation_grid(resolved_cell_size, resolved_agent_radius)
	# 寻路区域；取值来自缓存网格，默认用于约束起点和终点格。
	var navigation_region: Rect2i = navigation_grid.region

	# 起点格坐标；取值为世界坐标转换结果并限制在寻路区域内。
	var start_cell: Vector2i = _clamp_navigation_cell_to_region(_world_position_to_navigation_cell(start_position, resolved_cell_size), navigation_region)
	# 终点格坐标；取值为世界坐标转换结果并限制在寻路区域内。
	var end_cell: Vector2i = _clamp_navigation_cell_to_region(_world_position_to_navigation_cell(end_position, resolved_cell_size), navigation_region)
	if navigation_grid.is_point_solid(start_cell):
		start_cell = _find_nearest_walkable_navigation_cell(navigation_grid, start_cell, navigation_region, 5)
	if navigation_grid.is_point_solid(end_cell):
		end_cell = _find_nearest_walkable_navigation_cell(navigation_grid, end_cell, navigation_region, 8)
	if navigation_grid.is_point_solid(start_cell) or navigation_grid.is_point_solid(end_cell):
		return result

	# 原始格路径；取值来自 AStarGrid2D，默认允许部分路径以便障碍复杂时仍能靠近目标。
	var raw_path: Array = navigation_grid.get_id_path(start_cell, end_cell, true)
	# 已加入路径点数量；取值从 0 开始，默认用于限制单次返回的路径长度。
	var added_point_count: int = 0
	# 最大路径点数量；取值至少为 1，默认避免极长路径让怪物缓存过多路点。
	var resolved_max_path_points: int = maxi(max_path_points, 1)
	# 原始路径格遍历项；取值可能为 Vector2i，默认逐项转换成世界坐标。
	for raw_path_cell in raw_path:
		if not (raw_path_cell is Vector2i):
			continue

		# 当前路径格；取值为 Vector2i，默认用于转换世界坐标路点。
		var path_cell: Vector2i = raw_path_cell
		# 当前路径点；取值为格子中心的世界坐标，默认作为怪物移动目标。
		var waypoint: Vector2 = _navigation_cell_to_world_position(path_cell, resolved_cell_size)
		if added_point_count == 0 and waypoint.distance_to(start_position) <= resolved_cell_size * 0.75:
			continue

		result.append(waypoint)
		added_point_count += 1
		if added_point_count >= resolved_max_path_points:
			break

	return result


func _get_cached_navigation_grid(navigation_cell_size: float, agent_radius: float) -> AStarGrid2D:
	# 导航缓存键；取值为格子尺寸和代理半径组合，默认区分不同怪物体积的寻路网格。
	var cache_key: String = _get_navigation_grid_cache_key(navigation_cell_size, agent_radius)
	if _navigation_grid_cache.has(cache_key) and _navigation_grid_cache[cache_key] is AStarGrid2D:
		# 已缓存导航网格；取值为对应格子尺寸和代理半径的 AStarGrid2D，默认直接复用障碍固化结果。
		var cached_navigation_grid: AStarGrid2D = _navigation_grid_cache[cache_key] as AStarGrid2D
		return cached_navigation_grid

	# 新建导航网格；取值为覆盖整张地图的 AStarGrid2D，默认禁用斜向移动避免穿墙角。
	var navigation_grid: AStarGrid2D = _build_navigation_grid(navigation_cell_size, agent_radius)
	_navigation_grid_cache[cache_key] = navigation_grid
	return navigation_grid


func _get_navigation_grid_cache_key(navigation_cell_size: float, agent_radius: float) -> String:
	return "%d:%d" % [roundi(navigation_cell_size), roundi(agent_radius)]


func _build_navigation_grid(navigation_cell_size: float, agent_radius: float) -> AStarGrid2D:
	# 地图半边长；取值来自当前地图配置，默认用于计算寻路网格覆盖范围。
	var half_size: float = get_map_half_size()
	# 最小格坐标；取值为地图左上角所在格，默认允许负格坐标覆盖以原点居中的地图。
	var min_cell: int = floori(-half_size / navigation_cell_size)
	# 最大格坐标；取值为地图右下角所在格，默认包含地图边界。
	var max_cell: int = ceili(half_size / navigation_cell_size)
	# 寻路区域起点；取值为左上格坐标，默认传给 AStarGrid2D.region。
	var region_position: Vector2i = Vector2i(min_cell, min_cell)
	# 寻路区域尺寸；取值为横纵格数量，默认覆盖整张地图。
	var region_size: Vector2i = Vector2i(max_cell - min_cell + 1, max_cell - min_cell + 1)
	# 寻路区域；取值为 AStarGrid2D 使用的格坐标矩形。
	var navigation_region: Rect2i = Rect2i(region_position, region_size)
	# 导航网格；取值为 AStarGrid2D，默认仅在首次请求对应配置时创建。
	var navigation_grid: AStarGrid2D = AStarGrid2D.new()
	navigation_grid.region = navigation_region
	navigation_grid.cell_size = Vector2(navigation_cell_size, navigation_cell_size)
	navigation_grid.offset = Vector2(navigation_cell_size * 0.5, navigation_cell_size * 0.5)
	navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation_grid.update()
	_mark_navigation_obstacles(navigation_grid, navigation_region, navigation_cell_size, agent_radius)
	return navigation_grid


func spawn_weapon_drop(weapon_data: Resource, drop_position: Vector2) -> bool:
	if weapon_data == null or weapon_drop_scene == null:
		return false

	# 掉落物实例；取值为 Node2D 或 null，默认由 weapon_drop_scene 实例化。
	var drop_instance: Node2D = weapon_drop_scene.instantiate() as Node2D
	if drop_instance == null:
		return false

	# 掉落物父节点；取值为 Drops 容器或 GameWorld，默认用于集中组织地面武器。
	var spawn_parent: Node = _drop_parent if _drop_parent != null else self
	spawn_parent.add_child(drop_instance)
	drop_instance.global_position = _clamp_position_to_map(drop_position)
	if drop_instance.has_method("configure_drop"):
		drop_instance.call("configure_drop", weapon_data)
	else:
		drop_instance.set("weapon_data", weapon_data)

	_notify_network_drop_spawned(drop_instance, weapon_data, 1, drop_instance.global_position, Vector2.INF, 0.0, 0.0)
	return true


func spawn_weapon_drop_near_player(weapon_data: Resource) -> bool:
	if weapon_data == null:
		return false

	# 丢弃中心点；取值为玩家当前位置或世界原点，默认用于从背包拖出武器时生成落点。
	var drop_center: Vector2 = _player.global_position if _player != null else Vector2.ZERO
	# 丢弃位置；取值为玩家附近随机点，默认尽量避免直接落入墙体。
	var drop_position: Vector2 = _get_scattered_drop_position(drop_center)
	return spawn_weapon_drop(weapon_data, drop_position)


func spawn_item_drop_near_player(item_data: Resource, quantity: int = 1) -> bool:
	if item_data == null:
		return false
	# 通用丢弃中心；强化石和修复包与武器共用玩家附近散落及墙体避让规则。
	var drop_center: Vector2 = _player.global_position if _player != null else Vector2.ZERO
	return spawn_item_drop(item_data, _get_scattered_drop_position(drop_center), Vector2.INF, 0.0, 0.0, quantity)


func switch_character(character_id: String) -> void:
	_selected_character_id = _normalize_character_id(character_id)

	# 会话状态节点；默认由自动加载提供，修改后可让后续场景继续继承当前角色选择。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("configure"):
		# 当前模式标识；取值为 training 或 hack，默认按本世界缓存回写，修改会影响后续场景入口状态。
		var current_mode: String = GAME_MODE_TRAINING if _is_training_mode else GAME_MODE_HACK
		session_state.call("configure", current_mode, _selected_character_id)

	_apply_selected_character()


func _apply_session_state() -> void:
	# 会话状态节点；默认由自动加载提供，缺失时使用正式骇入和星作为兜底。
	var session_state: Node = _get_session_state()
	if session_state == null:
		_is_training_mode = false
		_is_first_run_tutorial = false
		_hack_variant = HackModeRules.VARIANT_STANDARD
		_mode_extension_effect_multipliers = ModeExtensionRules.get_effect_multipliers([])
		_hack_protocol_enabled = false
		_selected_character_id = CHARACTER_STELLE
		_apply_selected_character()
		return

	if session_state.has_method("is_training_mode"):
		_is_training_mode = bool(session_state.call("is_training_mode"))
	else:
		# 会话模式属性；取值为字符串，默认 hack，修改会影响当前 GameWorld 模式缓存。
		var session_mode: String = str(session_state.get("game_mode"))
		_is_training_mode = session_mode == GAME_MODE_TRAINING
	# 首次新手引导会话；只读取显式运行期标志，普通新手保护状态不会自动套用教学规则。
	_is_first_run_tutorial = session_state.has_method("is_first_run_tutorial_active") and bool(session_state.call("is_first_run_tutorial_active"))
	# 骇入模式变体；训练场固定使用标准值，正式骇入按会话状态读取，缺少接口时按标准骇入兜底。
	_hack_variant = HackModeRules.normalize_variant(str(session_state.call("get_hack_variant"))) if not _is_training_mode and session_state.has_method("get_hack_variant") else HackModeRules.VARIANT_STANDARD
	# 模式扩展效果；训练场固定使用中性值，正式骇入从 SessionState 获取已经规范化的整局汇总倍率。
	_mode_extension_effect_multipliers = session_state.call("get_mode_extension_effect_multipliers") as Dictionary if not _is_training_mode and session_state.has_method("get_mode_extension_effect_multipliers") else ModeExtensionRules.get_effect_multipliers([])
	# 骇入协议扩展开关；由 SessionState 同时校验正式模式与扩展 ID，训练场固定关闭。
	_hack_protocol_enabled = not _is_training_mode and session_state.has_method("is_hack_protocol_enabled") and bool(session_state.call("is_hack_protocol_enabled"))
	# 二手概率模式覆盖；零装骇入把局内掉落武器装备的二手概率从基础值提高到规则表覆盖值，负值表示不覆盖。
	var second_hand_override: float = HackModeRules.get_second_hand_chance_override(_hack_variant)
	if second_hand_override >= 0.0:
		second_hand_equipment_chance = second_hand_override

	if session_state.has_method("get_selected_character_id"):
		_selected_character_id = _normalize_character_id(str(session_state.call("get_selected_character_id")))
	else:
		# 会话角色属性；取值为字符串，默认 stelle，修改会影响当前 GameWorld 角色缓存。
		var session_character_id: String = str(session_state.get("selected_character_id"))
		_selected_character_id = _normalize_character_id(session_character_id)

	_apply_selected_character()


func _get_session_state() -> Node:
	return get_tree().root.get_node_or_null("SessionState")


func _begin_global_inventory_run() -> void:
	# 全局背包服务；模式扩展容量倍率在正式对局开始前写入，训练场与娱乐模式显式恢复为标准容量。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory != null and global_inventory.has_method("set_combat_backpack_capacity_multiplier"):
		# 本局容量倍率；风险合约只在有结算的正式骇入生效，其他入口固定为 1.0。
		var capacity_multiplier: float = float(_mode_extension_effect_multipliers.get("backpack_capacity_multiplier", 1.0)) if not _is_training_mode and not is_settlement_disabled_mode() else 1.0
		global_inventory.call("set_combat_backpack_capacity_multiplier", capacity_multiplier)
	# 娱乐模式补充：训练场与超频骇入都不开启正式战斗库存快照，拾取与死亡都不影响正式库存。
	if _is_training_mode or is_settlement_disabled_mode():
		return

	# 全局背包服务；默认由自动加载提供，正式骇入开始时记录本局物品快照用于撤离和失败结算。
	# 零装骇入补充：传入 true 让库存服务先封存真实背包与装备，再以空所有权开始本局。
	if global_inventory != null and global_inventory.has_method("begin_combat_run"):
		global_inventory.call("begin_combat_run", HackModeRules.is_bare_loadout(_hack_variant), _is_first_run_tutorial)
	# 生涯统计服务；只有产出结算的战斗模式会走到这里，对局开始计入总局数并清零本局临时计数。
	var stats_service: Node = get_tree().root.get_node_or_null("StatsService")
	if not _is_first_run_tutorial and stats_service != null and stats_service.has_method("record_run_started"):
		stats_service.call("record_run_started")


func _apply_selected_character() -> void:
	if _player == null:
		return
	if _selected_character_runtime_component != null and _selected_character_runtime_component.has_method("apply_character"):
		# 兼容回退档案；正式内容档案缺失时继续使用 GameWorld 原有检查器参数，保留独立场景的可配置能力。
		var fallback_profile: Dictionary = {
			"id": _selected_character_id,
			"display_name": _get_character_display_name(_selected_character_id),
			"max_health": _get_character_max_health(_selected_character_id),
			"max_energy": _get_character_max_energy(_selected_character_id),
			"move_speed": _get_character_move_speed(_selected_character_id),
			"attack_power": _get_character_attack_power(_selected_character_id),
			"defense_power": _get_character_defense_power(_selected_character_id),
		}
		_selected_character_runtime_component.call("apply_character", _selected_character_id, fallback_profile)
		return

	# 当前角色档案；优先来自自动内容目录，旧场景缺少目录服务时继续使用现有导出参数。
	var character_profile: Dictionary = _get_character_profile(_selected_character_id)
	_player.set("player_display_name", str(character_profile.get("display_name", _get_character_display_name(_selected_character_id))))
	# 玩家属性组件；先清空旧角色技能倍率，再重建被动，确保新被动首次计数使用新的角色基础数值。
	var stats_component: Node = _player.get_node_or_null(player_stats_component_path)
	if stats_component != null and stats_component.has_method("clear_skill_stat_multipliers"):
		stats_component.call("clear_skill_stat_multipliers")
	# 被动技能组件；角色切换前先重建全部被动行为，旧角色被动会通过 shutdown 精确清理地图标记和属性倍率。
	var passive_skill_component: Node = _player.get_node_or_null(player_passive_skill_component_path)
	if passive_skill_component != null and passive_skill_component.has_method("configure_skills"):
		passive_skill_component.call("configure_skills", character_profile.get("passive_skills", []) as Array)
	# 主动技能组件；按角色资源数组顺序写入技能一、二、三，多余项等待未来技能装备界面选择。
	var active_skill_component: Node = _player.get_node_or_null(player_active_skill_component_path)
	if active_skill_component != null and active_skill_component.has_method("configure_skills"):
		active_skill_component.call("configure_skills", character_profile.get("active_skills", []) as Array)

	# 玩家属性组件；默认从玩家子节点 StatsComponent 获取，缺失时跳过占位属性应用。
	if stats_component != null and stats_component.has_method("configure_character_base_stats"):
		# 固定生命上限；取值来自当前角色配置，默认用于进入场景或训练场切换角色时刷新生命。
		var resolved_max_health: float = float(character_profile.get("max_health", _get_character_max_health(_selected_character_id)))
		# 固定能量上限；取值来自当前角色配置，默认用于进入场景或训练场切换角色时刷新能量。
		var resolved_max_energy: float = float(character_profile.get("max_energy", _get_character_max_energy(_selected_character_id)))
		# 固定攻击力；取值来自当前角色配置，装备加成会由属性组件继续叠加。
		var resolved_attack_power: float = float(character_profile.get("attack_power", _get_character_attack_power(_selected_character_id)))
		# 固定防御力；取值来自当前角色配置，装备加成会由属性组件继续叠加。
		var resolved_defense_power: float = float(character_profile.get("defense_power", _get_character_defense_power(_selected_character_id)))
		stats_component.call("configure_character_base_stats", resolved_max_health, resolved_max_energy, resolved_attack_power, resolved_defense_power)

	# 玩家移动组件；默认从玩家子节点 MovementComponent 获取，缺失时跳过速度应用。
	var equipment_component: Node = _player.get_node_or_null(player_equipment_component_path)
	if equipment_component == null:
		return

	# 固定移动速度；取值来自当前角色配置，默认用于进入场景或训练场切换角色时刷新移动速度。
	var resolved_move_speed: float = float(character_profile.get("move_speed", _get_character_move_speed(_selected_character_id)))
	if equipment_component.has_method("configure_base_move_speed"):
		equipment_component.call("configure_base_move_speed", resolved_move_speed)


func _get_character_max_health(character_id: String) -> float:
	if character_id == CHARACTER_CAEULUS:
		return maxf(caelus_max_health, 1.0)
	if character_id == CHARACTER_SILVER_WOLF:
		return maxf(silver_wolf_max_health, 1.0)

	return maxf(stelle_max_health, 1.0)


func _get_character_max_energy(character_id: String) -> float:
	if character_id == CHARACTER_CAEULUS:
		return maxf(caelus_max_energy, 1.0)
	if character_id == CHARACTER_SILVER_WOLF:
		return maxf(silver_wolf_max_energy, 1.0)

	return maxf(stelle_max_energy, 1.0)


func _get_character_move_speed(character_id: String) -> float:
	if character_id == CHARACTER_CAEULUS:
		return maxf(caelus_move_speed, 1.0)
	if character_id == CHARACTER_SILVER_WOLF:
		return maxf(silver_wolf_move_speed, 1.0)

	return maxf(stelle_move_speed, 1.0)


func _get_character_attack_power(character_id: String) -> float:
	if character_id == CHARACTER_CAEULUS:
		return maxf(caelus_attack_power, 0.0)
	if character_id == CHARACTER_SILVER_WOLF:
		return maxf(silver_wolf_attack_power, 0.0)

	return maxf(stelle_attack_power, 0.0)


func _get_character_defense_power(character_id: String) -> float:
	if character_id == CHARACTER_CAEULUS:
		return maxf(caelus_defense_power, 0.0)
	if character_id == CHARACTER_SILVER_WOLF:
		return maxf(silver_wolf_defense_power, 0.0)

	return maxf(stelle_defense_power, 0.0)


func _normalize_character_id(character_id: String) -> String:
	# 会话状态；统一复用动态角色校验，避免 GameWorld 再维护一份角色 ID 白名单。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("normalize_character_id"):
		return str(session_state.call("normalize_character_id", character_id))
	if character_id == CHARACTER_CAEULUS:
		return CHARACTER_CAEULUS
	if character_id == CHARACTER_SILVER_WOLF:
		return CHARACTER_SILVER_WOLF

	return CHARACTER_STELLE


func _get_character_display_name(character_id: String) -> String:
	# 角色档案；自动注册角色直接使用资源中的显示名称，旧角色仍保留后续内置兜底。
	var profile: Dictionary = _get_character_profile(character_id)
	if not profile.is_empty():
		return str(profile.get("display_name", "角色"))
	if character_id == CHARACTER_CAEULUS:
		return "穹"
	if character_id == CHARACTER_SILVER_WOLF:
		return "银狼"

	return "星"


func _get_character_profile(character_id: String) -> Dictionary:
	# 会话状态；角色档案由 SessionState 统一转发内容目录，保证 UI 与战斗读取完全一致。
	var session_state: Node = _get_session_state()
	if session_state != null and session_state.has_method("get_character_profile"):
		return session_state.call("get_character_profile", character_id) as Dictionary
	return {}


func _merge_automatically_discovered_content() -> void:
	# 内容目录；自动加载缺失时保留场景检查器中的原始怪物和掉落池，方便场景单独迁移。
	var content_catalog: Node = get_tree().root.get_node_or_null("ContentCatalog")
	if content_catalog == null:
		return
	# 旧场景内容池过滤；扩展包接管既有资源时先移除未解锁模板，避免检查器兜底绕过目录可用性。
	monster_scenes = _filter_available_scene_pool(monster_scenes, content_catalog)
	weapon_drop_table = _filter_available_resource_pool(weapon_drop_table, content_catalog)
	equipment_drop_table = _filter_available_resource_pool(equipment_drop_table, content_catalog)
	repair_kit_drop_table = _filter_available_resource_pool(repair_kit_drop_table, content_catalog)
	# 单项怪物兜底过滤；当复数池为空时同样不得让已归属但未解锁的 monster_scene 绕过目录可用性。
	if monster_scene != null and content_catalog.has_method("is_content_path_available") and not monster_scene.resource_path.is_empty() and not bool(content_catalog.call("is_content_path_available", monster_scene.resource_path)):
		monster_scene = null
	if content_catalog.has_method("get_enemy_scene_paths"):
		for scene_path in content_catalog.call("get_enemy_scene_paths") as PackedStringArray:
			# 怪物场景；只合并尚未存在的资源路径，避免原有检查器列表和目录扫描产生重复权重。
			var enemy_scene: PackedScene = load(scene_path) as PackedScene
			if enemy_scene != null and not _packed_scene_pool_has_path(monster_scenes, scene_path):
				monster_scenes.append(enemy_scene)
	if content_catalog.has_method("get_weapon_paths"):
		for weapon_path in content_catalog.call("get_weapon_paths") as PackedStringArray:
			# 武器模板；合法自动资源会加入怪物与宝箱掉落池，实例生成时仍执行深拷贝。
			var weapon_template: Resource = load(weapon_path) as Resource
			if weapon_template != null and not _resource_pool_has_path(weapon_drop_table, weapon_path):
				weapon_drop_table.append(weapon_template)
	if content_catalog.has_method("get_equipment_paths"):
		for equipment_path in content_catalog.call("get_equipment_paths") as PackedStringArray:
			# 装备模板；合法自动资源会同时进入怪物与宝箱掉落池，实际掉落保持独立实例。
			var equipment_template: Resource = load(equipment_path) as Resource
			if equipment_template != null and not _resource_pool_has_path(equipment_drop_table, equipment_path):
				equipment_drop_table.append(equipment_template)
	if content_catalog.has_method("get_item_paths"):
		for item_path in content_catalog.call("get_item_paths") as PackedStringArray:
			# 道具模板；所有内容目录认可的通用道具都会进入怪物与宝箱池，不需要单独维护类型白名单。
			var item_template: Resource = load(item_path) as Resource
			if item_template != null and not _resource_pool_has_path(repair_kit_drop_table, item_path):
				repair_kit_drop_table.append(item_template)


func _filter_available_scene_pool(scene_pool: Array[PackedScene], content_catalog: Node) -> Array[PackedScene]:
	## 过滤场景检查器兜底池；运行时临时场景没有资源路径时保留，项目资源按扩展包状态判断。
	if content_catalog == null or not content_catalog.has_method("is_content_path_available"):
		return scene_pool.duplicate()
	# 可用场景池；保持原权重顺序，锁定路径不进入随机生成。
	var available_scenes: Array[PackedScene] = []
	for scene_resource in scene_pool:
		if scene_resource == null:
			continue
		# 场景资源路径；空路径代表运行时注入场景，不属于目录扩展包过滤范围。
		var scene_path: String = scene_resource.resource_path
		if scene_path.is_empty() or bool(content_catalog.call("is_content_path_available", scene_path)):
			available_scenes.append(scene_resource)
	return available_scenes


func _filter_available_resource_pool(resource_pool: Array[Resource], content_catalog: Node) -> Array[Resource]:
	## 过滤武器、装备和道具检查器兜底池；锁定扩展包模板不会进入怪物或宝箱掉落。
	if content_catalog == null or not content_catalog.has_method("is_content_path_available"):
		return resource_pool.duplicate()
	# 可用资源池；保持检查器顺序与原抽取权重。
	var available_resources: Array[Resource] = []
	for content_resource in resource_pool:
		if content_resource == null:
			continue
		# 内容资源路径；空路径代表运行时注入模板并继续保留。
		var content_path: String = content_resource.resource_path
		if content_path.is_empty() or bool(content_catalog.call("is_content_path_available", content_path)):
			available_resources.append(content_resource)
	return available_resources


func _packed_scene_pool_has_path(scene_pool: Array[PackedScene], resource_path: String) -> bool:
	for scene_resource in scene_pool:
		if scene_resource != null and scene_resource.resource_path == resource_path:
			return true
	return false


func _resource_pool_has_path(resource_pool: Array[Resource], resource_path: String) -> bool:
	for content_resource in resource_pool:
		if content_resource != null and content_resource.resource_path == resource_path:
			return true
	return false


func _update_survival_time(delta: float) -> void:
	if _is_player_dead():
		return

	_survival_time_seconds += maxf(delta, 0.0)
	_update_extraction_timeline()


func _update_extraction_timeline() -> void:
	if not _has_extraction_point and _survival_time_seconds >= _get_effective_extraction_spawn_time_seconds():
		_spawn_extraction_point()

	if _has_extraction_point and not _extraction_point_marked_on_map and _survival_time_seconds >= _get_effective_extraction_map_marker_time_seconds():
		_extraction_point_marked_on_map = true


func _get_effective_extraction_spawn_time_seconds() -> float:
	## 返回本局正式撤离点出现时间；首次引导使用独立两分钟节点，其他模式保持检查器配置。
	return maxf(tutorial_extraction_time_seconds, 1.0) if _is_first_run_tutorial else maxf(extraction_spawn_time_seconds, 1.0)


func _get_effective_extraction_map_marker_time_seconds() -> float:
	## 返回本局撤离地图标记时间；首次引导在点位出现时立即标记，普通局继续保留延迟情报阶段。
	return maxf(tutorial_extraction_time_seconds, 1.0) if _is_first_run_tutorial else maxf(extraction_map_marker_time_seconds, 1.0)


func _update_extraction_state(delta: float) -> void:
	if not _has_extraction_point or _player == null or _is_player_dead():
		_player_inside_extraction_area = false
		_active_extraction_point_index = -1
		_extraction_hold_elapsed_seconds = 0.0
		_extraction_ready_to_leave = false
		return

	# 当前命中的撤离点下标；多点布局已按优先间距分离，正常情况下不会同时命中多个范围。
	var next_active_extraction_point_index: int = -1
	for point_index in range(_extraction_point_positions.size()):
		if _player.global_position.distance_to(_extraction_point_positions[point_index]) <= maxf(extraction_radius, 1.0):
			next_active_extraction_point_index = point_index
			break
	_player_inside_extraction_area = next_active_extraction_point_index >= 0
	if not _player_inside_extraction_area:
		_active_extraction_point_index = -1
		# 离开正式撤离范围；累计进度保留到下一次进入，达到阈值后仍需重新站入范围才允许 HUD 确认撤离。
		_extraction_ready_to_leave = _extraction_hold_elapsed_seconds >= get_extraction_hold_duration_seconds()
		return
	if next_active_extraction_point_index != _active_extraction_point_index:
		_active_extraction_point_index = next_active_extraction_point_index

	_extraction_hold_elapsed_seconds = minf(_extraction_hold_elapsed_seconds + maxf(delta, 0.0), get_extraction_hold_duration_seconds())
	_extraction_ready_to_leave = _extraction_hold_elapsed_seconds >= get_extraction_hold_duration_seconds()


func _spawn_extraction_point() -> void:
	if _has_extraction_point:
		return

	# 撤离点最终位置；联机时使用进图预推导的确定性列表，单机按远距生成器实时选取全部点位。
	_extraction_point_positions = _network_extraction_positions.duplicate() if _has_network_extraction_positions else _get_random_extraction_positions(_get_effective_extraction_point_count())
	# 生成失败兜底；任何异常配置至少保留一个合法尝试结果，避免撤离流程永久不可用。
	if _extraction_point_positions.is_empty():
		_extraction_point_positions.append(_get_random_extraction_position())
	_extraction_point_nodes.clear()
	for point_index in range(_extraction_point_positions.size()):
		# 当前撤离点位置；每个位置创建独立视觉节点并按序加入撤离点组。
		var point_position: Vector2 = _extraction_point_positions[point_index]
		_extraction_point_nodes.append(_create_extraction_point_node(point_position, point_index))
	# 首个撤离点；继续更新历史单点缓存，兼容旧 HUD、测试桩与外部调用方。
	_extraction_point_position = _extraction_point_positions.front()
	_extraction_point_node = _extraction_point_nodes.front() if not _extraction_point_nodes.is_empty() else null
	_has_extraction_point = true
	_extraction_point_marked_on_map = _survival_time_seconds >= _get_effective_extraction_map_marker_time_seconds()
	_player_inside_extraction_area = false
	_active_extraction_point_index = -1
	_extraction_hold_elapsed_seconds = 0.0
	_extraction_ready_to_leave = false


func _create_extraction_point_node(point_position: Vector2, point_index: int = 0) -> Node2D:
	# 撤离点根节点；取值为运行时创建的 Node2D，默认挂在 GameWorld 下并显示撤离范围。
	var extraction_point: Node2D = Node2D.new()
	extraction_point.name = "ExtractionPoint%d" % (point_index + 1)
	extraction_point.add_to_group("extraction_points")
	add_child(extraction_point)
	extraction_point.global_position = point_position

	# 撤离范围填充；取值为 Polygon2D，默认绘制半透明圆形范围用于站位判断。
	var fill_polygon: Polygon2D = Polygon2D.new()
	fill_polygon.color = extraction_fill_color
	fill_polygon.polygon = _build_circle_points(maxf(extraction_radius, 1.0), 48, false)
	extraction_point.add_child(fill_polygon)

	# 撤离范围边框；取值为 Line2D，默认绘制闭合圆环便于玩家识别边界。
	var ring_line: Line2D = Line2D.new()
	ring_line.default_color = extraction_ring_color
	ring_line.width = 4.0
	ring_line.closed = true
	ring_line.points = _build_circle_points(maxf(extraction_radius, 1.0), 64, false)
	extraction_point.add_child(ring_line)

	# 撤离中心横线；取值为 Line2D，默认和竖线组成短十字用于定位中心点。
	var center_horizontal_line: Line2D = Line2D.new()
	center_horizontal_line.default_color = extraction_ring_color
	center_horizontal_line.width = 3.0
	center_horizontal_line.points = PackedVector2Array([
		Vector2(-14.0, 0.0),
		Vector2(14.0, 0.0)
	])
	extraction_point.add_child(center_horizontal_line)

	# 撤离中心竖线；取值为 Line2D，默认和横线组成短十字用于定位中心点。
	var center_vertical_line: Line2D = Line2D.new()
	center_vertical_line.default_color = extraction_ring_color
	center_vertical_line.width = 3.0
	center_vertical_line.points = PackedVector2Array([
		Vector2(0.0, -14.0),
		Vector2(0.0, 14.0)
	])
	extraction_point.add_child(center_vertical_line)
	return extraction_point


func _spawn_supply_extraction_points() -> void:
	_supply_extraction_positions.clear()
	# 物资撤离点数量；数组四项分别对应 2、3、4、5 个，默认权重随数量递减。
	var point_count: int = _roll_supply_extraction_count()
	for point_index in range(point_count):
		# 当前点位位置；每次生成都会避开环境障碍、玩家出生点和已生成点位。
		var point_position: Vector2 = _get_random_supply_extraction_position()
		_supply_extraction_positions.append(point_position)
		_create_supply_extraction_point_node(point_position, point_index)


func _roll_supply_extraction_count() -> int:
	# 权重总和；允许检查器自定义但所有负值按 0 处理，异常全零时回退 2 个点。
	var total_weight: float = 0.0
	for raw_weight in supply_extraction_count_weights:
		total_weight += maxf(raw_weight, 0.0)
	if total_weight <= 0.0:
		return 2
	# 数量随机值；在全部有效权重总和内映射到 2 至 5 个点位。
	var count_roll: float = _random.randf_range(0.0, total_weight)
	# 累计数量权重；按 2、3、4、5 的顺序逐项覆盖随机区间。
	var cumulative_weight: float = 0.0
	for weight_index in range(4):
		# 当前数量权重；缺失数组项按 0 处理，允许检查器保留较短兼容配置。
		var configured_weight: float = float(supply_extraction_count_weights[weight_index]) if weight_index < supply_extraction_count_weights.size() else 0.0
		cumulative_weight += maxf(configured_weight, 0.0)
		if count_roll <= cumulative_weight:
			return weight_index + 2
	return 5


func _get_random_supply_extraction_position() -> Vector2:
	for _attempt_index in range(maxi(supply_extraction_spawn_attempt_count, 1)):
		# 当前候选位置；通过统一有效性校验后才作为实际物资撤离点。
		var candidate_position: Vector2 = _get_random_supply_extraction_candidate()
		if _is_supply_extraction_position_valid(candidate_position):
			return candidate_position
	return _get_random_supply_extraction_candidate()


func _get_random_supply_extraction_candidate() -> Vector2:
	# 地图半边长；用于计算扣除边缘留白后的均匀生成范围。
	var half_size: float = get_map_half_size()
	# 实际边缘留白；至少等于点位半径，避免范围压到边界墙。
	var edge_margin: float = maxf(supply_extraction_spawn_edge_margin, supply_extraction_radius)
	# 坐标生成上限；在正负范围内分别均匀抽取 X 与 Y。
	var spawn_limit: float = maxf(half_size - edge_margin, 1.0)
	return Vector2(_random.randf_range(-spawn_limit, spawn_limit), _random.randf_range(-spawn_limit, spawn_limit))


func _is_supply_extraction_position_valid(candidate_position: Vector2) -> bool:
	if _player != null and candidate_position.distance_to(_player.global_position) < maxf(supply_extraction_min_distance_from_player, 0.0):
		return false
	if _is_position_blocked_by_environment(candidate_position, maxf(supply_extraction_radius, 1.0)):
		return false
	# 点位间距；至少保持两倍半径，防止两个驻留范围重叠导致当前点下标抖动。
	for existing_position in _supply_extraction_positions:
		if existing_position.distance_to(candidate_position) < maxf(supply_extraction_radius * 2.0, 1.0):
			return false
	return true


func _create_supply_extraction_point_node(point_position: Vector2, point_index: int) -> void:
	# 物资撤离点根节点；始终在地图内显示金色圆环，属于地面提示且不产生实体碰撞。
	var supply_point: Node2D = Node2D.new()
	supply_point.name = "SupplyExtractionPoint%d" % (point_index + 1)
	supply_point.add_to_group("supply_extraction_points")
	add_child(supply_point)
	supply_point.global_position = point_position
	# 范围填充；使用半透明金色圆形表示驻留区域。
	var fill_polygon: Polygon2D = Polygon2D.new()
	fill_polygon.color = supply_extraction_fill_color
	fill_polygon.polygon = _build_circle_points(maxf(supply_extraction_radius, 1.0), 48, false)
	supply_point.add_child(fill_polygon)
	# 范围边框；闭合圆环用于远距离识别点位边界。
	var ring_line: Line2D = Line2D.new()
	ring_line.default_color = supply_extraction_ring_color
	ring_line.width = 4.0
	ring_line.closed = true
	ring_line.points = _build_circle_points(maxf(supply_extraction_radius, 1.0), 64, false)
	supply_point.add_child(ring_line)
	# 中心标签；明确该点位只负责物资送回而不是直接结束战斗。
	var center_label: Label = Label.new()
	center_label.text = "物资撤离"
	center_label.position = Vector2(-42.0, -10.0)
	center_label.size = Vector2(84.0, 20.0)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.add_theme_color_override("font_color", supply_extraction_ring_color)
	supply_point.add_child(center_label)


func _update_supply_extraction_state(delta: float) -> void:
	if _player == null or _is_player_dead() or _supply_extraction_positions.is_empty():
		_active_supply_extraction_index = -1
		_supply_extraction_hold_elapsed_seconds = 0.0
		_supply_extraction_ready = false
		return
	# 当前所在点；按列表顺序寻找第一个命中范围，生成阶段已保证范围不会互相重叠。
	var next_active_index: int = -1
	for point_index in range(_supply_extraction_positions.size()):
		if _player.global_position.distance_to(_supply_extraction_positions[point_index]) <= maxf(supply_extraction_radius, 1.0):
			next_active_index = point_index
			break
	if next_active_index < 0:
		_active_supply_extraction_index = -1
		_supply_extraction_hold_elapsed_seconds = 0.0
		_supply_extraction_ready = false
		return
	if next_active_index != _active_supply_extraction_index:
		_active_supply_extraction_index = next_active_index
		_supply_extraction_hold_elapsed_seconds = 0.0
	_supply_extraction_hold_elapsed_seconds = minf(_supply_extraction_hold_elapsed_seconds + maxf(delta, 0.0), get_supply_extraction_hold_duration_seconds())
	_supply_extraction_ready = _supply_extraction_hold_elapsed_seconds >= get_supply_extraction_hold_duration_seconds()


func _build_circle_points(radius: float, point_count: int, close_loop: bool) -> PackedVector2Array:
	# 圆点列表；元素为局部坐标，默认用于 Polygon2D 和 Line2D 绘制圆形撤离范围。
	var points: PackedVector2Array = PackedVector2Array()
	# 有效圆点数量；取值至少为 8，默认避免圆形视觉过于粗糙。
	var resolved_point_count: int = maxi(point_count, 8)
	# 圆点索引；取值为 0 到 resolved_point_count - 1，默认按角度均匀生成。
	for point_index in range(resolved_point_count):
		# 圆点角度；取值为 0 到 TAU 的弧度，默认用于计算当前圆周点。
		var point_angle: float = TAU * float(point_index) / float(resolved_point_count)
		points.append(Vector2.RIGHT.rotated(point_angle) * radius)

	if close_loop and not points.is_empty():
		points.append(points[0])

	return points


func _get_effective_extraction_point_count() -> int:
	## 返回本局正式撤离点数量；常规局使用检查器配置，风险合约的有效数量字段可将其覆盖为 1。
	if _is_first_run_tutorial:
		return 1
	# 风险合约指定数量；中性值 0 表示未限制，正数表示本局强制使用该数量。
	var contracted_count: int = int(_mode_extension_effect_multipliers.get("extraction_point_count", 0))
	if contracted_count > 0:
		return contracted_count
	return maxi(extraction_point_count, 1)


func _get_random_extraction_positions(point_count: int) -> Array[Vector2]:
	## 生成多个尽量远离的正式撤离点；每个新点从有效候选中选择与已选点最近距离最大的候选，优先满足期望间距。
	if _is_first_run_tutorial:
		return [_get_first_run_tutorial_extraction_position()]
	# 目标点位数量；至少生成一个，避免错误配置把撤离流程变为无出口状态。
	var resolved_point_count: int = maxi(point_count, 1)
	# 已选点位；按生成顺序保存，每轮都会作为下一点距离评分的参照集合。
	var positions: Array[Vector2] = []
	for _point_index in range(resolved_point_count):
		# 当前最远合法候选；环境或玩家距离无解时仍由旧单点回退路径保证输出。
		positions.append(_get_farthest_extraction_position(positions))
	return positions


func _get_farthest_extraction_position(existing_positions: Array[Vector2]) -> Vector2:
	## 选择与已有撤离点最分散的合法候选；先偏好达到配置间距的点，候选不足时仍返回距离最远的合法点。
	# 每点候选采样数量；复用正式撤离点尝试配置，默认 36 次以平衡分布质量与生成成本。
	var resolved_attempt_count: int = maxi(extraction_spawn_attempt_count, 1)
	# 期望最近间距；仅作为优先目标而非硬失败条件，极端地图配置下仍能生成全部出口。
	var preferred_spacing: float = maxf(extraction_point_preferred_minimum_spacing, 0.0)
	# 最佳优先候选；满足期望间距后继续比较最近距离，默认未找到。
	var best_preferred_position: Vector2 = Vector2.ZERO
	# 最佳优先候选是否存在；默认 false，用于与退化候选区分。
	var has_best_preferred_position: bool = false
	# 最佳退化候选；无法满足期望间距时保留距离最远的环境合法点。
	var best_fallback_position: Vector2 = Vector2.ZERO
	# 最佳退化候选是否存在；默认 false，全部候选无效时调用历史回退逻辑。
	var has_best_fallback_position: bool = false
	# 当前已知最佳最近距离；默认 -1，任何合法候选都可替换。
	var best_minimum_distance: float = -1.0
	# 当前已知最佳退化最近距离；默认 -1，任何合法候选都可替换。
	var best_fallback_minimum_distance: float = -1.0
	for _attempt_index in range(resolved_attempt_count):
		# 当前候选位置；先沿用旧校验，确保不贴玩家或环境障碍。
		var candidate_position: Vector2 = _get_random_extraction_candidate()
		if not _is_extraction_position_valid(candidate_position):
			continue
		# 候选到最近已选点的距离；首个点没有参照时视为无穷远，随机合法点即可成为起点。
		var nearest_distance: float = _get_nearest_extraction_position_distance(candidate_position, existing_positions)
		if nearest_distance > best_fallback_minimum_distance:
			best_fallback_minimum_distance = nearest_distance
			best_fallback_position = candidate_position
			has_best_fallback_position = true
		if nearest_distance >= preferred_spacing and nearest_distance > best_minimum_distance:
			best_minimum_distance = nearest_distance
			best_preferred_position = candidate_position
			has_best_preferred_position = true
	if has_best_preferred_position:
		return best_preferred_position
	if has_best_fallback_position:
		return best_fallback_position
	return _get_random_extraction_position()


func _get_nearest_extraction_position_distance(candidate_position: Vector2, existing_positions: Array[Vector2]) -> float:
	## 计算候选点到已选撤离点的最短中心距离；没有已选点时返回无穷大，使首点只受环境和玩家限制。
	if existing_positions.is_empty():
		return INF
	# 当前最短距离；默认无穷大，在遍历中收敛为候选点与任一已选点的最近距离。
	var nearest_distance: float = INF
	for existing_position in existing_positions:
		nearest_distance = minf(nearest_distance, candidate_position.distance_to(existing_position))
	return nearest_distance


func _get_first_run_tutorial_extraction_position() -> Vector2:
	## 在玩家当前位置附近生成唯一引导撤离点；点位仍避开环境障碍和地图边缘，缩短首次学习局的无效赶路时间。
	return _find_tutorial_clear_position(tutorial_extraction_distance, maxf(extraction_radius, 1.0))


func _get_random_extraction_position() -> Vector2:
	# 撤离点尝试次数；取值来自检查器配置，默认用于寻找不被障碍遮挡的位置。
	var resolved_attempt_count: int = maxi(extraction_spawn_attempt_count, 1)
	# 撤离点尝试索引；取值为 0 到 resolved_attempt_count - 1，默认逐次测试候选位置。
	for _attempt_index in range(resolved_attempt_count):
		# 候选撤离位置；取值为地图内随机点，默认会继续校验玩家距离和环境障碍。
		var candidate_position: Vector2 = _get_random_extraction_candidate()
		if _is_extraction_position_valid(candidate_position):
			return candidate_position

	return _get_random_extraction_candidate()


func _get_random_extraction_candidate() -> Vector2:
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于限制撤离点候选范围。
	var half_size: float = get_map_half_size()
	# 有效边界留白；取值至少为撤离半径，默认避免撤离范围压到地图边界。
	var edge_margin: float = maxf(extraction_spawn_edge_margin, extraction_radius)
	# 有效生成边界；取值为半边长减边界留白，默认确保撤离点位于地图内部。
	var spawn_limit: float = maxf(0.0, half_size - edge_margin)
	# 撤离点随机源；联机为共享种子派生的专用随机流，单机为世界主随机源。
	var extraction_random: RandomNumberGenerator = _get_extraction_random_source()
	return Vector2(
		extraction_random.randf_range(-spawn_limit, spawn_limit),
		extraction_random.randf_range(-spawn_limit, spawn_limit)
	)


func _is_extraction_position_valid(candidate_position: Vector2) -> bool:
	if _player != null and candidate_position.distance_to(_player.global_position) < maxf(extraction_spawn_min_distance_from_player, 0.0):
		return false

	if _is_position_blocked_by_environment(candidate_position, maxf(extraction_radius, 1.0)):
		return false

	return true


func _is_player_dead() -> bool:
	if _player == null:
		return false

	# 玩家属性组件；默认从玩家子节点 StatsComponent 获取，用于停止死亡后的存活计时和撤离进度。
	var stats_component: Node = _player.get_node_or_null(player_stats_component_path)
	if stats_component != null and stats_component.has_method("is_dead"):
		return bool(stats_component.call("is_dead"))

	return false


func _update_explored_cells_if_needed(delta: float) -> void:
	if _player == null:
		return

	_exploration_update_remaining = maxf(_exploration_update_remaining - maxf(delta, 0.0), 0.0)
	if _should_update_explored_cells():
		_update_explored_cells(false)


func _should_update_explored_cells() -> bool:
	if _player == null:
		return false

	if not _has_last_exploration_update_position:
		return true

	if _exploration_update_remaining <= 0.0:
		return true

	# 当前摄像机世界视野尺寸；相机缩放或窗口尺寸改变会改变该值，因此不等待玩家移动阈值即可刷新探索。
	# 只计算尺寸而非完整矩形，使计时等待期的每帧检查不再读取相机屏幕中心位置。
	var current_view_size: Vector2 = _get_player_camera_world_view_size()
	if not _has_last_exploration_view_rect or current_view_size != _last_exploration_view_rect.size:
		return true

	# 本次探索刷新距离阈值；取值至少为 0，默认让玩家快速移动时不等待固定计时器。
	var update_distance: float = maxf(exploration_update_distance, 0.0)
	if update_distance <= 0.0:
		return false

	return _player.global_position.distance_to(_last_exploration_update_position) >= update_distance


func _update_explored_cells(force_update: bool) -> void:
	if _player == null:
		return

	if not force_update and not _should_update_explored_cells():
		return

	_last_exploration_update_position = _player.global_position
	_has_last_exploration_update_position = true
	_exploration_update_remaining = maxf(exploration_update_interval, 0.02)
	# 本次摄像机世界视野；有效玩家相机存在时，探索严格按屏幕实际可见矩形写入并随缩放变化。
	var current_view_rect: Rect2 = _get_player_camera_world_view_rect()
	_last_exploration_view_rect = current_view_rect
	_has_last_exploration_view_rect = true
	# 是否新增探索格；取值为 true/false，默认只在实际扩展迷雾缓存时递增版本号。
	var explored_cells_changed: bool = false
	if _player_camera != null and is_instance_valid(_player_camera):
		explored_cells_changed = _mark_explored_cells_in_world_rect(current_view_rect)
		if explored_cells_changed:
			_explored_cells_version += 1
		return
	# 有效探索格子尺寸；取值至少 1，默认防止配置错误导致除零。
	var cell_size: float = get_exploration_cell_size()
	# 玩家所在探索格；取值为玩家当前全局坐标转换后的格子坐标。
	var center_cell: Vector2i = _world_position_to_exploration_cell(_player.global_position)
	# 探索格半径；取值为探索半径除以格子尺寸后向上取整，默认用于批量标记圆形附近格子。
	var cell_radius: int = ceili(maxf(exploration_radius, 0.0) / cell_size)
	# X 轴探索偏移；取值为 -cell_radius 到 cell_radius，默认覆盖玩家附近探索范围。
	for offset_x in range(-cell_radius, cell_radius + 1):
		# Y 轴探索偏移；取值为 -cell_radius 到 cell_radius，默认覆盖玩家附近探索范围。
		for offset_y in range(-cell_radius, cell_radius + 1):
			# 探索偏移向量；取值为当前循环偏移，默认用于圆形范围过滤。
			var offset_vector: Vector2 = Vector2(float(offset_x), float(offset_y)) * cell_size
			if offset_vector.length() > exploration_radius + cell_size * 0.5:
				continue

			# 当前探索格；取值为玩家中心格加偏移，默认写入已探索字典。
			var explored_cell: Vector2i = center_cell + Vector2i(offset_x, offset_y)
			if _explored_cells.has(explored_cell):
				continue

			_explored_cells[explored_cell] = true
			explored_cells_changed = true

	if explored_cells_changed:
		_explored_cells_version += 1


func _get_player_camera_world_view_size() -> Vector2:
	# 摄像机世界视野尺寸；只做视口尺寸与缩放的除法，供每帧变化检测使用，不读取相机屏幕中心。
	if _player_camera != null and is_instance_valid(_player_camera):
		# 当前视口；其可见尺寸与相机缩放共同决定玩家屏幕实际覆盖的世界范围。
		var current_viewport: Viewport = _player_camera.get_viewport()
		if current_viewport != null:
			# 安全相机缩放；每轴至少 0.001，避免异常配置导致除零或无限视野。
			var camera_zoom: Vector2 = Vector2(maxf(absf(_player_camera.zoom.x), 0.001), maxf(absf(_player_camera.zoom.y), 0.001))
			return current_viewport.get_visible_rect().size / camera_zoom
	# 摄像机缺失回退；与完整矩形接口的回退分支保持同一探索半径语义。
	return Vector2.ONE * maxf(exploration_radius, 0.0) * 2.0


func _get_player_camera_world_view_rect() -> Rect2:
	if _player_camera != null and is_instance_valid(_player_camera):
		# 当前视口；其可见尺寸与相机缩放共同决定玩家屏幕实际覆盖的世界范围。
		var current_viewport: Viewport = _player_camera.get_viewport()
		if current_viewport != null:
			# 视口像素尺寸；窗口或拉伸模式变化后会即时反映到下一次探索刷新。
			var viewport_size: Vector2 = current_viewport.get_visible_rect().size
			# 安全相机缩放；每轴至少 0.001，避免异常配置导致除零或无限视野。
			var camera_zoom: Vector2 = Vector2(maxf(absf(_player_camera.zoom.x), 0.001), maxf(absf(_player_camera.zoom.y), 0.001))
			# 世界视野尺寸；相机放大时范围缩小，相机缩小时范围扩大。
			var world_view_size: Vector2 = viewport_size / camera_zoom
			# 相机屏幕中心；使用 Camera2D 最终中心位置，使跟随、偏移和缩放后的探索边界保持一致。
			var camera_center: Vector2 = _player_camera.get_screen_center_position()
			return Rect2(camera_center - world_view_size * 0.5, world_view_size)

	# 玩家探索半径；取值应大于等于 0，默认 760 像素，修改会影响摄像机缺失时的回退探索范围。
	# 摄像机缺失回退：保留原有 exploration_radius 配置，使独立测试场景仍能建立探索记录。
	var fallback_radius: float = maxf(exploration_radius, 0.0)
	return Rect2(_player.global_position - Vector2.ONE * fallback_radius, Vector2.ONE * fallback_radius * 2.0)


func _mark_explored_cells_in_world_rect(world_view_rect: Rect2) -> bool:
	# 有效探索格尺寸；与大地图迷雾和墙体裁剪共用同一网格。
	var cell_size: float = get_exploration_cell_size()
	# 实际地图矩形；摄像机视野只在战斗边界内形成探索记录。
	var half_size: float = get_map_half_size()
	# 裁剪后摄像机矩形；视野超出边界时不会在地图外生成缓存键。
	var clipped_view_rect: Rect2 = world_view_rect.intersection(Rect2(Vector2(-half_size, -half_size), Vector2.ONE * half_size * 2.0))
	if clipped_view_rect.size.x <= 0.0 or clipped_view_rect.size.y <= 0.0:
		return false
	# 起始探索格；向下取整以包含视野左上边缘接触的格子。
	var start_cell: Vector2i = Vector2i(floori(clipped_view_rect.position.x / cell_size), floori(clipped_view_rect.position.y / cell_size))
	# 结束探索格；向上取整后减一以包含视野右下边缘覆盖的最后一格。
	var end_cell: Vector2i = Vector2i(ceili(clipped_view_rect.end.x / cell_size) - 1, ceili(clipped_view_rect.end.y / cell_size) - 1)
	# 是否新增探索格；调用方据此只在地图信息变化时递增版本号。
	var explored_cells_changed: bool = false
	# 摄像机视野 X 格遍历；覆盖当前裁剪视野的全部横向探索格。
	for cell_x in range(start_cell.x, end_cell.x + 1):
		# 摄像机视野 Y 格遍历；与当前 X 坐标组合形成实际进入屏幕的探索格。
		for cell_y in range(start_cell.y, end_cell.y + 1):
			# 当前摄像机覆盖格；格子一旦进入实际屏幕范围就永久视为已探索。
			var explored_cell: Vector2i = Vector2i(cell_x, cell_y)
			if _explored_cells.has(explored_cell):
				continue
			_explored_cells[explored_cell] = true
			explored_cells_changed = true
	return explored_cells_changed


func _world_position_to_exploration_cell(world_position: Vector2) -> Vector2i:
	# 有效探索格子尺寸；取值至少 1，默认防止配置错误导致除零。
	var cell_size: float = get_exploration_cell_size()
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.y / cell_size))


func _mark_navigation_obstacles(navigation_grid: AStarGrid2D, navigation_region: Rect2i, navigation_cell_size: float, agent_radius: float) -> void:
	# 障碍矩形遍历项；取值为世界坐标 Rect2，默认逐项写入寻路网格的不可通行格。
	for obstacle_rect in _environment_obstacle_rects:
		# 扩张后的障碍矩形；取值按怪物半径向外扩展，默认让路径与墙体保持安全距离。
		var expanded_rect: Rect2 = obstacle_rect.grow(agent_radius)
		# 障碍起始格；取值为扩张矩形左上角转换结果，默认用于标记格子范围。
		var start_cell: Vector2i = _world_position_to_navigation_cell(expanded_rect.position, navigation_cell_size)
		# 障碍结束格；取值为扩张矩形右下角转换结果，默认用于标记格子范围。
		var end_cell: Vector2i = _world_position_to_navigation_cell(expanded_rect.end, navigation_cell_size)
		# 障碍 X 格遍历；取值为障碍覆盖的横向格坐标范围。
		for cell_x in range(start_cell.x, end_cell.x + 1):
			# 障碍 Y 格遍历；取值为障碍覆盖的纵向格坐标范围。
			for cell_y in range(start_cell.y, end_cell.y + 1):
				# 当前障碍格；取值为 Vector2i，默认用于 AStarGrid2D 设置 solid。
				var obstacle_cell: Vector2i = Vector2i(cell_x, cell_y)
				if _is_navigation_cell_in_region(obstacle_cell, navigation_region):
					navigation_grid.set_point_solid(obstacle_cell, true)


func _world_position_to_navigation_cell(world_position: Vector2, navigation_cell_size: float) -> Vector2i:
	# 有效寻路格尺寸；取值至少 1，默认防止转换时除零。
	var resolved_cell_size: float = maxf(navigation_cell_size, 1.0)
	return Vector2i(floori(world_position.x / resolved_cell_size), floori(world_position.y / resolved_cell_size))


func _navigation_cell_to_world_position(navigation_cell: Vector2i, navigation_cell_size: float) -> Vector2:
	# 有效寻路格尺寸；取值至少 1，默认用于把格坐标转换成世界坐标。
	var resolved_cell_size: float = maxf(navigation_cell_size, 1.0)
	# 格坐标浮点值；取值来自 Vector2i 的 x/y，默认用于安全转换成世界坐标。
	var cell_position: Vector2 = Vector2(float(navigation_cell.x), float(navigation_cell.y))
	# 格子中心世界坐标；取值为格坐标加半格偏移，默认让怪物朝格子中心移动。
	var world_position: Vector2 = (cell_position + Vector2(0.5, 0.5)) * resolved_cell_size
	return _clamp_position_to_map(world_position)


func _is_navigation_cell_in_region(navigation_cell: Vector2i, navigation_region: Rect2i) -> bool:
	if navigation_cell.x < navigation_region.position.x or navigation_cell.y < navigation_region.position.y:
		return false
	if navigation_cell.x >= navigation_region.end.x or navigation_cell.y >= navigation_region.end.y:
		return false

	return true


func _clamp_navigation_cell_to_region(navigation_cell: Vector2i, navigation_region: Rect2i) -> Vector2i:
	return Vector2i(
		clampi(navigation_cell.x, navigation_region.position.x, navigation_region.end.x - 1),
		clampi(navigation_cell.y, navigation_region.position.y, navigation_region.end.y - 1)
	)


func _find_nearest_walkable_navigation_cell(navigation_grid: AStarGrid2D, origin_cell: Vector2i, navigation_region: Rect2i, max_search_radius: int) -> Vector2i:
	if _is_navigation_cell_in_region(origin_cell, navigation_region) and not navigation_grid.is_point_solid(origin_cell):
		return origin_cell

	# 标准化搜索半径；取值至少为 0，默认用于限制向外寻找可走格的范围。
	var resolved_max_radius: int = maxi(max_search_radius, 0)
	# 搜索半径遍历；取值从 1 到最大半径，默认逐圈向外找最近可走格。
	for search_radius in range(1, resolved_max_radius + 1):
		# X 偏移遍历；取值为当前搜索圈的横向偏移。
		for offset_x in range(-search_radius, search_radius + 1):
			# Y 偏移遍历；取值为当前搜索圈的纵向偏移。
			for offset_y in range(-search_radius, search_radius + 1):
				if abs(offset_x) != search_radius and abs(offset_y) != search_radius:
					continue

				# 候选格；取值为原始格加当前偏移，默认用于测试是否可通行。
				var candidate_cell: Vector2i = origin_cell + Vector2i(offset_x, offset_y)
				if not _is_navigation_cell_in_region(candidate_cell, navigation_region):
					continue
				if not navigation_grid.is_point_solid(candidate_cell):
					return candidate_cell

	return origin_cell


func _spawn_boundary_walls() -> void:
	# 边界墙挂载父节点；取值为 Environment 容器或 GameWorld，默认用于组织地图边缘阻挡体。
	var spawn_parent: Node = _environment_parent if _environment_parent != null else self
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于定位四周边界。
	var half_size: float = get_map_half_size()
	# 边界墙厚度；取值至少为 1，默认用于生成四条矩形墙体。
	var wall_thickness: float = maxf(boundary_wall_thickness, 1.0)
	# 地图完整宽度；取值为半边长两倍，默认用于横向墙体长度。
	var map_width: float = half_size * 2.0
	# 横向墙体尺寸；取值覆盖地图宽度，默认放置在地图上下边缘内侧。
	var horizontal_wall_size: Vector2 = Vector2(map_width, wall_thickness)
	# 纵向墙体尺寸；取值覆盖地图高度，默认放置在地图左右边缘内侧。
	var vertical_wall_size: Vector2 = Vector2(wall_thickness, map_width)
	_create_boundary_wall(spawn_parent, "TopBoundaryWall", Vector2(0.0, -half_size + wall_thickness * 0.5), horizontal_wall_size)
	_create_boundary_wall(spawn_parent, "BottomBoundaryWall", Vector2(0.0, half_size - wall_thickness * 0.5), horizontal_wall_size)
	_create_boundary_wall(spawn_parent, "LeftBoundaryWall", Vector2(-half_size + wall_thickness * 0.5, 0.0), vertical_wall_size)
	_create_boundary_wall(spawn_parent, "RightBoundaryWall", Vector2(half_size - wall_thickness * 0.5, 0.0), vertical_wall_size)


func _create_boundary_wall(parent_node: Node, wall_name: String, wall_position: Vector2, wall_size: Vector2) -> void:
	# 边界墙物理体；取值为新建 StaticBody2D，默认使用环境层阻挡玩家、怪物和弹体。
	var wall_body: StaticBody2D = StaticBody2D.new()
	wall_body.name = wall_name
	wall_body.collision_layer = 16
	wall_body.collision_mask = 0
	wall_body.add_to_group("environment_obstacles")
	parent_node.add_child(wall_body)
	wall_body.global_position = wall_position

	# 边界墙碰撞形状资源；取值为 RectangleShape2D，默认尺寸等于传入墙体尺寸。
	var rectangle_shape: RectangleShape2D = RectangleShape2D.new()
	rectangle_shape.size = wall_size
	# 边界墙碰撞节点；取值为 CollisionShape2D，默认挂载到墙体物理节点。
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rectangle_shape
	wall_body.add_child(collision_shape)

	# 边界墙视觉节点；取值为 Polygon2D，默认用半透明深色矩形标记地图边缘。
	var visual: Polygon2D = Polygon2D.new()
	visual.color = boundary_wall_color
	visual.polygon = PackedVector2Array([
		Vector2(-wall_size.x * 0.5, -wall_size.y * 0.5),
		Vector2(wall_size.x * 0.5, -wall_size.y * 0.5),
		Vector2(wall_size.x * 0.5, wall_size.y * 0.5),
		Vector2(-wall_size.x * 0.5, wall_size.y * 0.5)
	])
	wall_body.add_child(visual)

	# 边界墙世界矩形；取值为墙体全局位置和尺寸计算结果，默认写入地图障碍缓存。
	var wall_rect: Rect2 = Rect2(wall_position - wall_size * 0.5, wall_size)
	_environment_obstacle_rects.append(wall_rect)


func _spawn_random_environment() -> void:
	if obstacle_scenes.is_empty() or obstacle_spawn_count <= 0:
		return

	# 环境挂载父节点；取值为 Environment 容器或 GameWorld，默认用于组织随机墙体和建筑。
	var spawn_parent: Node = _environment_parent if _environment_parent != null else self
	# 环境生成循环索引；取值为 0 到 obstacle_spawn_count - 1，默认逐个尝试生成环境预制体。
	for _spawn_index in range(obstacle_spawn_count):
		# 环境预制体资源；取值来自 obstacle_scenes 随机下标，默认用于提供不同墙体和建筑类型。
		var obstacle_scene: PackedScene = obstacle_scenes[_random.randi_range(0, obstacle_scenes.size() - 1)]
		if obstacle_scene == null:
			continue

		# 环境实例；取值为 Node2D 或 null，默认由预制体实例化，修改会影响实际摆放对象。
		var obstacle_instance: Node2D = obstacle_scene.instantiate() as Node2D
		if obstacle_instance == null:
			continue

		spawn_parent.add_child(obstacle_instance)
		if not _place_environment_instance(obstacle_instance):
			spawn_parent.remove_child(obstacle_instance)
			obstacle_instance.queue_free()


func _place_environment_instance(obstacle_instance: Node2D) -> bool:
	# 环境摆放尝试索引；取值为 0 到 obstacle_spawn_attempts_per_item - 1，默认用于多次寻找合法位置。
	for _attempt_index in range(obstacle_spawn_attempts_per_item):
		obstacle_instance.global_position = _get_random_environment_spawn_position()
		obstacle_instance.rotation = float(_random.randi_range(0, 3)) * PI * 0.5
		# 环境随机缩放；取值为 obstacle_scale_min 到 obstacle_scale_max，默认让同类型建筑拥有不同体积。
		var obstacle_scale: float = _get_random_obstacle_scale()
		obstacle_instance.scale = Vector2(obstacle_scale, obstacle_scale)

		# 当前实例碰撞矩形列表；取值为世界坐标 Rect2 数组，默认用于小地图和摆放合法性判断。
		var obstacle_rects: Array[Rect2] = _get_obstacle_collision_rects(obstacle_instance)
		# 当前实例整体边界；取值为所有碰撞矩形的并集，默认用于快速判断边界和间距。
		var obstacle_bounds: Rect2 = _get_rects_bounds(obstacle_rects)
		if not _is_environment_bounds_valid(obstacle_bounds):
			continue

		# 当前实例矩形遍历项；取值为世界坐标 Rect2，默认写入小地图障碍缓存。
		for obstacle_rect in obstacle_rects:
			_environment_obstacle_rects.append(obstacle_rect)
		# 环境结构记录；封闭环形建筑和实心紧凑建筑使用更高宝箱生成权重，其余结构仍可作为周边候选。
		var obstacle_name: String = obstacle_instance.name.to_lower()
		# 封闭建筑判断；当前环形建筑和紧凑实心建筑使用三倍默认候选权重。
		var is_enclosed_building: bool = obstacle_name.contains("wallring") or obstacle_name.contains("compact")
		_environment_feature_bounds.append({"bounds": obstacle_bounds, "enclosed": is_enclosed_building})

		return true

	return false


func _get_random_environment_spawn_position() -> Vector2:
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于限制环境物出生范围。
	var half_size: float = get_map_half_size()
	# 有效生成边界；取值为半边长减边界留白，默认避免建筑贴边或超出网格地图。
	var spawn_limit: float = maxf(0.0, half_size - obstacle_spawn_edge_margin)
	return Vector2(
		_random.randf_range(-spawn_limit, spawn_limit),
		_random.randf_range(-spawn_limit, spawn_limit)
	)


func _get_random_obstacle_scale() -> float:
	# 标准化最小缩放；取值至少为 0.1，默认防止环境物过小或配置为 0。
	var min_scale: float = maxf(minf(obstacle_scale_min, obstacle_scale_max), 0.1)
	# 标准化最大缩放；取值至少为最小缩放，默认防止配置反转导致随机范围错误。
	var max_scale: float = maxf(maxf(obstacle_scale_min, obstacle_scale_max), min_scale)
	return _random.randf_range(min_scale, max_scale)


func _is_environment_bounds_valid(obstacle_bounds: Rect2) -> bool:
	if obstacle_bounds.size.x <= 0.0 or obstacle_bounds.size.y <= 0.0:
		return false

	# 障碍中心点；取值为整体边界中心，默认用于玩家出生点安全距离判断。
	var obstacle_center: Vector2 = obstacle_bounds.get_center()
	if _player != null and obstacle_center.distance_to(_player.global_position) < obstacle_spawn_min_distance_from_player:
		return false

	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于判断障碍是否完全在地图内。
	var half_size: float = get_map_half_size()
	if obstacle_bounds.position.x < -half_size or obstacle_bounds.position.y < -half_size:
		return false
	if obstacle_bounds.end.x > half_size or obstacle_bounds.end.y > half_size:
		return false

	# 带间距的候选边界；取值为障碍整体边界向外扩张，默认用于避免建筑互相贴脸。
	var spaced_bounds: Rect2 = obstacle_bounds.grow(obstacle_spawn_min_spacing)
	# 既有障碍矩形遍历项；取值为世界坐标 Rect2，默认用于检测新障碍是否过度重叠。
	for existing_rect in _environment_obstacle_rects:
		if spaced_bounds.intersects(existing_rect):
			return false

	return true


func _get_obstacle_collision_rects(root: Node) -> Array[Rect2]:
	# 碰撞矩形结果；元素为世界坐标 Rect2，默认供小地图和障碍摆放检测使用。
	var result: Array[Rect2] = []
	_collect_obstacle_collision_rects(root, result)
	if result.is_empty() and root is Node2D:
		# 根节点兜底位置；取值为 Node2D 全局坐标，默认用于预制体缺少碰撞形状时仍有最小边界。
		var root_position: Vector2 = (root as Node2D).global_position
		result.append(Rect2(root_position - Vector2(16.0, 16.0), Vector2(32.0, 32.0)))

	return result


func _collect_obstacle_collision_rects(node: Node, result: Array[Rect2]) -> void:
	if node is CollisionShape2D:
		# 碰撞形状节点；取值为 CollisionShape2D，默认只处理矩形碰撞体用于小地图绘制。
		var collision_shape: CollisionShape2D = node as CollisionShape2D
		if collision_shape.shape is RectangleShape2D:
			# 矩形碰撞体；取值为 RectangleShape2D，默认与墙体和建筑预制体保持一致。
			var rectangle_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
			result.append(_get_global_rect_from_rectangle_shape(collision_shape, rectangle_shape))

	# 子节点遍历项；取值为当前节点所有子节点，默认递归查找预制体内的墙体碰撞形状。
	for child in node.get_children():
		_collect_obstacle_collision_rects(child, result)


func _get_global_rect_from_rectangle_shape(collision_shape: CollisionShape2D, rectangle_shape: RectangleShape2D) -> Rect2:
	# 矩形半尺寸；取值为碰撞形状尺寸一半，默认用于生成四个局部角点。
	var half_size: Vector2 = rectangle_shape.size * 0.5
	# 矩形全局变换；取值来自碰撞形状节点，默认用于支持建筑整体旋转。
	var shape_transform: Transform2D = collision_shape.global_transform
	# 第一个角点；取值为左上局部角点转换到世界坐标，默认初始化包围盒。
	var first_corner: Vector2 = shape_transform * Vector2(-half_size.x, -half_size.y)
	# 最小坐标；取值会随其他角点更新，默认用于构建世界轴对齐包围盒。
	var min_position: Vector2 = first_corner
	# 最大坐标；取值会随其他角点更新，默认用于构建世界轴对齐包围盒。
	var max_position: Vector2 = first_corner
	# 矩形局部角点数组；取值为四个角点，默认用于计算旋转后的轴对齐包围盒。
	var corners: Array[Vector2] = [
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	]
	# 角点遍历项；取值为局部坐标，默认逐个转换并扩展包围盒。
	for corner in corners:
		# 当前世界角点；取值为局部角点经全局变换后的坐标，默认用于更新包围盒。
		var world_corner: Vector2 = shape_transform * corner
		min_position = min_position.min(world_corner)
		max_position = max_position.max(world_corner)

	return Rect2(min_position, max_position - min_position)


func _get_rects_bounds(rects: Array[Rect2]) -> Rect2:
	if rects.is_empty():
		return Rect2()

	# 合并边界；取值初始为第一个矩形，默认逐项扩展为所有矩形的并集。
	var merged_bounds: Rect2 = rects[0]
	# 矩形索引；取值从 1 到数组末尾，默认跳过已作为初始值的第一个矩形。
	for rect_index in range(1, rects.size()):
		merged_bounds = merged_bounds.merge(rects[rect_index])

	return merged_bounds


func _spawn_loot_chests() -> void:
	if loot_chest_scene == null:
		return
	# 宝箱数量范围；先排序检查器最小和最大值，再在闭区间内等概率抽取 20 至 40 的默认数量。
	var minimum_count: int = maxi(mini(loot_chest_spawn_count_min, loot_chest_spawn_count_max), 0)
	# 宝箱数量上限；异常反向配置会自动与最小值交换解释。
	var maximum_count: int = maxi(maxi(loot_chest_spawn_count_min, loot_chest_spawn_count_max), minimum_count)
	# 本局宝箱数量；最小与最大相同时使用固定值，否则在闭区间内等概率抽取。
	var chest_count: int = _random.randi_range(minimum_count, maximum_count) if maximum_count > minimum_count else minimum_count
	# 宝箱父节点；作为建筑挂在 Environment 下，统一参与世界层级、移动阻挡和小地图障碍缓存。
	var spawn_parent: Node = _environment_parent if _environment_parent != null else self
	for _chest_index in range(chest_count):
		# 宝箱实例；必须能够作为 Node2D 放入 Environment 层级。
		var chest_instance: Node2D = loot_chest_scene.instantiate() as Node2D
		if chest_instance == null:
			continue
		# 宝箱位置；无法在规定尝试次数内找到安全点时返回无穷向量并跳过本实例。
		var chest_position: Vector2 = _get_random_loot_chest_position()
		if chest_position == Vector2.INF:
			chest_instance.queue_free()
			continue
		spawn_parent.add_child(chest_instance)
		chest_instance.global_position = chest_position
		# 宝箱品质；每个实例独立按 47%、35%、15% 和 3% 权重抽取。
		var quality_id: String = str(LOOT_CHEST_SCRIPT.call("roll_quality", _random))
		if chest_instance.has_method("configure_quality"):
			chest_instance.call("configure_quality", quality_id)
		if chest_instance.has_signal("loot_released"):
			chest_instance.connect("loot_released", Callable(self, "_on_loot_chest_released"))
		if chest_instance.has_signal("chest_removed"):
			chest_instance.connect("chest_removed", Callable(self, "_on_loot_chest_removed"))
		# 宝箱障碍矩形；与场景 64×52 碰撞尺寸一致，供小地图、生成避让和共享导航网格读取。
		var chest_rect: Rect2 = Rect2(chest_position - Vector2(32.0, 26.0), Vector2(64.0, 52.0))
		_environment_obstacle_rects.append(chest_rect)
		_loot_chest_obstacle_rects[chest_instance.get_instance_id()] = chest_rect


func _get_random_loot_chest_position() -> Vector2:
	for _attempt_index in range(maxi(loot_chest_spawn_attempt_count, 1)):
		# 候选点；优先从建筑周边生成，剩余概率覆盖整张地图，保证开阔区仍可能出现宝箱。
		var candidate_position: Vector2 = _get_loot_chest_candidate()
		if _is_loot_chest_position_valid(candidate_position):
			return candidate_position
	return Vector2.INF


func _get_loot_chest_candidate() -> Vector2:
	if not _environment_feature_bounds.is_empty() and _random.randf() < clampf(loot_chest_near_building_chance, 0.0, 1.0):
		# 加权环境结构；封闭建筑默认拥有普通结构三倍被选中概率。
		var selected_feature: Dictionary = _select_weighted_environment_feature()
		if not selected_feature.is_empty():
			# 建筑整体边界；用于从四条外侧边随机选择宝箱周边位置。
			var feature_bounds: Rect2 = selected_feature.get("bounds", Rect2())
			# 建筑周边边距；碰撞检测半径再增加 20 像素，避免宝箱紧贴墙体导致无法绕行或开启。
			var perimeter_margin: float = maxf(loot_chest_clearance_radius, 1.0) + 20.0
			# 周边边选择；0 至 3 分别表示上、右、下、左。
			var side_index: int = _random.randi_range(0, 3)
			if side_index == 0:
				return Vector2(_random.randf_range(feature_bounds.position.x, feature_bounds.end.x), feature_bounds.position.y - perimeter_margin)
			if side_index == 1:
				return Vector2(feature_bounds.end.x + perimeter_margin, _random.randf_range(feature_bounds.position.y, feature_bounds.end.y))
			if side_index == 2:
				return Vector2(_random.randf_range(feature_bounds.position.x, feature_bounds.end.x), feature_bounds.end.y + perimeter_margin)
			return Vector2(feature_bounds.position.x - perimeter_margin, _random.randf_range(feature_bounds.position.y, feature_bounds.end.y))
	# 整图候选；使用环境生成边界留白，避免宝箱压到地图边界墙。
	var half_size: float = get_map_half_size()
	# 宝箱实际边缘留白；至少等于清障半径，防止静态碰撞越界。
	var edge_margin: float = maxf(obstacle_spawn_edge_margin, loot_chest_clearance_radius)
	# 宝箱均匀生成坐标上限；用于非建筑周边候选。
	var spawn_limit: float = maxf(half_size - edge_margin, 1.0)
	return Vector2(_random.randf_range(-spawn_limit, spawn_limit), _random.randf_range(-spawn_limit, spawn_limit))


func _select_weighted_environment_feature() -> Dictionary:
	# 总权重；封闭建筑按默认 3 倍计入，普通结构权重为 1。
	var total_weight: float = 0.0
	for feature in _environment_feature_bounds:
		total_weight += maxf(loot_chest_enclosed_building_weight, 1.0) if bool(feature.get("enclosed", false)) else 1.0
	if total_weight <= 0.0:
		return {}
	# 结构选择随机值；在全部普通与封闭结构权重总和中抽取。
	var selection_roll: float = _random.randf_range(0.0, total_weight)
	# 累计结构权重；达到随机值时返回当前结构记录。
	var cumulative_weight: float = 0.0
	for feature in _environment_feature_bounds:
		cumulative_weight += maxf(loot_chest_enclosed_building_weight, 1.0) if bool(feature.get("enclosed", false)) else 1.0
		if selection_roll <= cumulative_weight:
			return feature
	return _environment_feature_bounds.back()


func _is_loot_chest_position_valid(candidate_position: Vector2) -> bool:
	if _player != null and candidate_position.distance_to(_player.global_position) < maxf(loot_chest_min_distance_from_player, 0.0):
		return false
	if _is_position_blocked_by_environment(candidate_position, maxf(loot_chest_clearance_radius, 1.0)):
		return false
	# 已生成宝箱中心；按缓存矩形中心检查最小间距，避免多个宝箱互相堵死。
	for chest_rect in _loot_chest_obstacle_rects.values():
		if chest_rect is Rect2 and chest_rect.get_center().distance_to(candidate_position) < maxf(loot_chest_minimum_spacing, 1.0):
			return false
	return true


func _on_loot_chest_released(chest_position: Vector2, quality_id: String, drop_count: int, minimum_high_quality_count: int, broken_open: bool) -> void:
	if _network_combat_active and _network_combat_sync != null and _network_combat_sync.has_method("request_chest_release"):
		# 联机出货仲裁；先向主机认领该宝箱，取得认领权的一端才执行本地掷点，防止两名成员同时开箱产生重复物资。
		_network_combat_sync.call("request_chest_release", chest_position, quality_id, drop_count, minimum_high_quality_count, broken_open)
		return
	execute_loot_chest_release(chest_position, quality_id, drop_count, minimum_high_quality_count, broken_open)


func execute_loot_chest_release(chest_position: Vector2, quality_id: String, drop_count: int, minimum_high_quality_count: int, broken_open: bool) -> void:
	## 执行宝箱实际出货；单机由信号回调直接调用，联机由取得认领权的一端调用一次，掉落经网络登记钩子同步给全员。
	if _hack_protocol_component != null and _hack_protocol_component.has_method("notify_chest_opened"):
		# 宝箱碎片事实；只有实际取得出货权的一端执行本函数，因此联机不会给其他成员重复奖励。
		_hack_protocol_component.call("notify_chest_opened")
	if _is_first_run_tutorial and not _tutorial_first_chest_opened:
		_spawn_first_run_tutorial_chest_rewards(chest_position, broken_open)
	# 最终掉落数量；主动长按开启时允许已触发套装追加物品，击毁宝箱始终保持品质原始数量。
	var resolved_drop_count: int = _get_resolved_loot_chest_drop_count(drop_count, broken_open)
	# 宝箱掉落循环；极品前五件强制高品质，其余物品按当前宝箱品质对应概率独立判定。
	for drop_index in range(resolved_drop_count):
		# 是否为极品保底高品质物品；默认前五件为 true，其余按品质概率判定。
		var force_high_quality: bool = drop_index < maxi(minimum_high_quality_count, 0)
		# 本次掉落资源；从武器、装备、强化石和道具池中生成独立实例。
		var item_resource: Resource = _create_random_loot_chest_item(quality_id, force_high_quality)
		if item_resource != null:
			# 掉落目标；手动开启使用紧凑扩散，击破使用更大的放射半径并播放飞出动画。
			var drop_target: Vector2 = _get_loot_chest_drop_position(chest_position, drop_index, resolved_drop_count, broken_open)
			# 飞出时长；在配置范围内独立随机，避免所有物品完全同步落地。
			var launch_duration: float = _random.randf_range(minf(loot_chest_launch_duration_min, loot_chest_launch_duration_max), maxf(loot_chest_launch_duration_min, loot_chest_launch_duration_max))
			# 飞出弧高；在配置范围内独立随机，为多件物品提供自然高度差。
			var launch_arc_height: float = _random.randf_range(minf(loot_chest_launch_arc_height_min, loot_chest_launch_arc_height_max), maxf(loot_chest_launch_arc_height_min, loot_chest_launch_arc_height_max))
			# 开启方式只改变最终扩散半径；手动开启和击破统一从箱体中心播放同款抛物线动画。
			spawn_item_drop(item_resource, drop_target, chest_position, launch_duration, launch_arc_height)


func _spawn_first_run_tutorial_chest_rewards(chest_position: Vector2, broken_open: bool) -> void:
	## 为引导局首次开箱追加固定防具与高级正向伤害强化石，并补足首轮协议碎片；普通宝箱原掉落仍完整保留。
	_tutorial_first_chest_opened = true
	# 保底奖励列表；每项均为独立运行时资源，避免强化或耐久变化污染项目模板。
	var tutorial_rewards: Array[Resource] = []
	if tutorial_first_chest_equipment != null:
		# 保底防具副本；深复制保留完整套装引用与耐久字段，同时隔离本次物品状态。
		var tutorial_equipment: Resource = tutorial_first_chest_equipment.duplicate(true) as Resource
		tutorial_rewards.append(tutorial_equipment if tutorial_equipment != null else tutorial_first_chest_equipment)
	# 高级武器强化石；固定正向伤害词条，让玩家第一次使用强化系统获得直观收益且不会抽到负面词条。
	var tutorial_stone: EnhancementStoneData = EnhancementStoneData.create_custom(EnhancementRules.QUALITY_HIGH, "weapon", "damage")
	if tutorial_stone != null:
		tutorial_rewards.append(tutorial_stone)
	for reward_index in range(tutorial_rewards.size()):
		# 当前保底资源；顺序固定为防具、强化石，便于掉落位置分散和测试断言。
		var reward_resource: Resource = tutorial_rewards[reward_index]
		# 保底掉落目标；复用宝箱手动或击破扩散规则，不创建不可拾取的直接库存注入。
		var reward_drop_target: Vector2 = _get_loot_chest_drop_position(chest_position, reward_index, tutorial_rewards.size(), broken_open)
		# 保底掉落动画时长；取现有宝箱动画区间中值，反馈稳定且不引入额外随机等待。
		var reward_launch_duration: float = (loot_chest_launch_duration_min + loot_chest_launch_duration_max) * 0.5
		# 保底掉落弧高；取现有宝箱弧高区间中值，与普通随机掉落保持统一视觉语言。
		var reward_launch_arc_height: float = (loot_chest_launch_arc_height_min + loot_chest_launch_arc_height_max) * 0.5
		spawn_item_drop(reward_resource, reward_drop_target, chest_position, reward_launch_duration, reward_launch_arc_height)
	if _hack_protocol_component != null and _hack_protocol_component.has_method("get_required_fragments") and _hack_protocol_component.has_method("get_current_fragments") and _hack_protocol_component.has_method("add_fragments"):
		# 首轮碎片缺口；开箱原奖励先结算，再只补足尚缺数量，已有击杀与生存碎片不会被覆盖或浪费。
		var tutorial_fragment_shortfall: float = maxf(float(_hack_protocol_component.call("get_required_fragments")) - float(_hack_protocol_component.call("get_current_fragments")), 0.0)
		if tutorial_fragment_shortfall > 0.0:
			_hack_protocol_component.call("add_fragments", tutorial_fragment_shortfall)


func _get_resolved_loot_chest_drop_count(base_drop_count: int, broken_open: bool) -> int:
	## 结算宝箱最终掉落数量；套装特殊效果只响应主动长按，不响应伤害击毁。
	# 基础掉落数量；限制为非负值，异常宝箱配置不会导致负范围循环。
	var resolved_drop_count: int = maxi(base_drop_count, 0)
	if broken_open or _player == null:
		return resolved_drop_count
	# 套装组件；由玩家预制体提供，只公开本次主动宝箱的额外掉落结算接口。
	var equipment_set_component: Node = _player.get_node_or_null("EquipmentSetComponent")
	if equipment_set_component != null and equipment_set_component.has_method("roll_manual_chest_extra_drop_count"):
		resolved_drop_count += maxi(int(equipment_set_component.call("roll_manual_chest_extra_drop_count", _random)), 0)
	return resolved_drop_count


func _get_loot_chest_drop_position(center_position: Vector2, drop_index: int, drop_count: int, broken_open: bool) -> Vector2:
	# 扩散半径范围；击破使用 105 至 190 像素，手动开启使用 34 至 72 像素默认范围。
	var minimum_radius: float = loot_chest_broken_drop_radius_min if broken_open else loot_chest_manual_drop_radius_min
	# 最大扩散半径；与最小值排序后抽取，允许检查器反向配置仍保持有效。
	var maximum_radius: float = loot_chest_broken_drop_radius_max if broken_open else loot_chest_manual_drop_radius_max
	# 均匀基础角度；按物品索引分配扇区，避免多件物品随机到同一方向。
	var base_angle: float = TAU * float(drop_index) / float(maxi(drop_count, 1))
	# 角度扰动；限制在半个扇区内，保留放射分布同时避免视觉过于机械。
	var angle_jitter: float = _random.randf_range(-PI / float(maxi(drop_count, 2)), PI / float(maxi(drop_count, 2)))
	# 实际扩散距离；在当前开启方式的闭区间内随机。
	var scatter_distance: float = _random.randf_range(minf(minimum_radius, maximum_radius), maxf(minimum_radius, maximum_radius))
	# 候选落点；先限制到地图内，再避开环境碰撞。
	var candidate_position: Vector2 = _clamp_position_to_map(center_position + Vector2.RIGHT.rotated(base_angle + angle_jitter) * scatter_distance)
	if not _is_position_blocked_by_environment(candidate_position, 18.0):
		return candidate_position
	return _get_scattered_drop_position(center_position)


func _create_random_loot_chest_item(quality_id: String, force_high_quality: bool) -> Resource:
	# 高品质判定；普通、中级、高级和极品的非保底物品分别使用 10%、30%、55% 和 75%。
	var high_quality_chance: float = clampf(float(CHEST_HIGH_QUALITY_CHANCES.get(quality_id, 0.10)), 0.0, 1.0)
	# 是否使用高品质物品池；极品保底直接为 true，其余按当前品质概率随机。
	var should_use_high_quality_pool: bool = force_high_quality or _random.randf() < high_quality_chance
	# 类别总权重；默认总和为 1.0，集中参与抽取可确保以后调整常量时仍按相对权重结算。
	var total_category_weight: float = CHEST_WEAPON_CATEGORY_WEIGHT + CHEST_EQUIPMENT_CATEGORY_WEIGHT + CHEST_ENHANCEMENT_STONE_CATEGORY_WEIGHT + CHEST_ITEM_CATEGORY_WEIGHT
	# 类别抽取；武器 25%、装备 15%、强化石 35%、道具 25%，在四类总权重内均匀生成随机值。
	var category_roll: float = _random.randf() * maxf(total_category_weight, 0.001)
	if category_roll < CHEST_WEAPON_CATEGORY_WEIGHT:
		return _get_random_chest_weapon(should_use_high_quality_pool)
	if category_roll < CHEST_WEAPON_CATEGORY_WEIGHT + CHEST_EQUIPMENT_CATEGORY_WEIGHT:
		return _get_random_chest_equipment(should_use_high_quality_pool)
	if category_roll < CHEST_WEAPON_CATEGORY_WEIGHT + CHEST_EQUIPMENT_CATEGORY_WEIGHT + CHEST_ENHANCEMENT_STONE_CATEGORY_WEIGHT:
		return _get_random_chest_stone(should_use_high_quality_pool)
	return _get_random_chest_repair_kit(should_use_high_quality_pool)


func _get_random_chest_weapon(high_quality: bool) -> Resource:
	if weapon_drop_table.is_empty():
		return _get_random_chest_stone(high_quality)
	# 高品质武器池；当前以基础价值不低于 120 星穹识别，覆盖脉冲步枪、散射爆能枪和磁轨炮等高价值枪械。
	# 星内容精简补充：当前两把保留武器价值均为 50，高品质候选为空时会按既有规则回退完整星武器池。
	var candidate_weapons: Array[Resource] = []
	for weapon_template in weapon_drop_table:
		if weapon_template != null and (not high_quality or int(weapon_template.get("value")) >= 120):
			candidate_weapons.append(weapon_template)
	if candidate_weapons.is_empty():
		candidate_weapons = weapon_drop_table.duplicate()
	# 选中武器模板；从当前普通或高品质候选池等概率抽取。
	var selected_weapon: Resource = candidate_weapons[_random.randi_range(0, candidate_weapons.size() - 1)]
	# 独立武器实例；保留模板数值但避免多个宝箱掉落共享耐久与强化状态。
	var duplicated_weapon: Resource = selected_weapon.duplicate(true) as Resource
	# 宝箱武器实例；复制成功后才允许写入二手状态，避免异常复制失败时污染项目模板。
	var chest_weapon: Resource = duplicated_weapon if duplicated_weapon != null else selected_weapon
	if duplicated_weapon != null:
		SECOND_HAND_ITEM_GENERATOR.call("roll_and_apply", chest_weapon, _random, second_hand_equipment_chance)
	return chest_weapon


func _get_random_chest_equipment(high_quality: bool) -> Resource:
	# 随机装备；高品质池选择当前基础价值最高的模板，普通池从全部合法装备中等概率抽取。
	var selected_equipment: Resource = _duplicate_random_or_highest_value_resource(equipment_drop_table, high_quality)
	if selected_equipment != null:
		SECOND_HAND_ITEM_GENERATOR.call("roll_and_apply", selected_equipment, _random, second_hand_equipment_chance)
	return selected_equipment if selected_equipment != null else _get_random_chest_stone(high_quality)


func _get_random_chest_stone(high_quality: bool) -> Resource:
	# 高品质强化石；最多尝试 12 次抽取高级或极品，确保保底物品确实进入高品质池。
	# 特化品质补充；特化强化石同样属于高品质产出，命中时直接满足宝箱高品质判定。
	var selected_stone: EnhancementStoneData
	for _attempt_index in range(12 if high_quality else 1):
		selected_stone = _create_random_enhancement_stone()
		if selected_stone == null or not high_quality:
			break
		# 当前强化石品质；高级或极品即可满足高品质池要求。
		# 特化品质补充；特化与高级、极品共同纳入宝箱高品质识别列表。
		var stone_quality_id: String = selected_stone.get_resolved_quality_id()
		if stone_quality_id in [EnhancementRules.QUALITY_HIGH, EnhancementRules.QUALITY_SUPREME, EnhancementRules.QUALITY_SPECIALIZED]:
			return selected_stone
	if high_quality and selected_stone != null:
		# 极小概率连续未命中时强制提升到高级，保留已生成词条方向并更新统一品质名称。
		selected_stone.quality_id = EnhancementRules.QUALITY_HIGH
		selected_stone.display_name = EnhancementStoneData._build_display_name(EnhancementRules.QUALITY_HIGH, selected_stone.get_resolved_target_kind())
		selected_stone.value = EnhancementStoneData.calculate_value(EnhancementRules.QUALITY_HIGH, selected_stone.get_normalized_modifiers())
	return selected_stone


func _get_random_chest_repair_kit(high_quality: bool) -> Resource:
	# 随机道具；高品质池选择当前基础价值最高的模板，普通池从全部合法道具中等概率抽取。
	var selected_item: Resource = _duplicate_random_or_highest_value_resource(repair_kit_drop_table, high_quality)
	return selected_item if selected_item != null else _get_random_chest_stone(high_quality)


func _duplicate_random_or_highest_value_resource(resource_pool: Array[Resource], use_highest_value: bool) -> Resource:
	# 有效模板池；过滤空资源，避免内容目录中单个损坏资源中断其他合法掉落。
	var valid_templates: Array[Resource] = []
	for resource_template in resource_pool:
		if resource_template != null:
			valid_templates.append(resource_template)
	if valid_templates.is_empty():
		return null
	# 选中模板；高品质请求选择基础价值最高项，普通请求在完整池中等概率抽取。
	var selected_template: Resource = valid_templates[0]
	if use_highest_value:
		for resource_template in valid_templates:
			if int(resource_template.get("value")) > int(selected_template.get("value")):
				selected_template = resource_template
	else:
		selected_template = valid_templates[_random.randi_range(0, valid_templates.size() - 1)]
	# 独立资源实例；武器以外物品也可能保存耐久或强化状态，深拷贝可隔离每件掉落。
	var duplicated_resource: Resource = selected_template.duplicate(true) as Resource
	return duplicated_resource if duplicated_resource != null else selected_template


func remove_network_loot_chest_by_key(chest_key: String) -> void:
	## 按位置键静默移除本机宝箱；联机中其他成员开启或击毁同位置宝箱后，本机对应宝箱不出货直接消失，障碍缓存经原移除信号更新。
	for chest_instance_id in _loot_chest_obstacle_rects.keys():
		# 宝箱实例对象；缓存键为实例编号，节点可能已被释放。
		var chest_object: Object = instance_from_id(int(chest_instance_id))
		if not (chest_object is Node2D):
			continue
		# 宝箱节点；位置键使用与同步器一致的 0.1 像素量化格式，宝箱布点由共享种子保证各端一致。
		var chest_node: Node2D = chest_object as Node2D
		if "%.1f_%.1f" % [chest_node.global_position.x, chest_node.global_position.y] != chest_key:
			continue
		if chest_node.has_method("force_network_remove"):
			chest_node.call("force_network_remove")
		return


func _on_loot_chest_removed(chest: Node) -> void:
	if chest == null:
		return
	# 宝箱实例键；与生成时写入的障碍矩形表精确对应。
	var chest_key: int = chest.get_instance_id()
	if not _loot_chest_obstacle_rects.has(chest_key):
		return
	# 宝箱障碍移除；开启或击毁后立即恢复导航、小地图和后续生成点的通行状态。
	var chest_rect: Rect2 = _loot_chest_obstacle_rects[chest_key]
	_loot_chest_obstacle_rects.erase(chest_key)
	_environment_obstacle_rects.erase(chest_rect)
	_navigation_grid_cache.clear()
	_environment_obstacle_version += 1


func _spawn_first_run_tutorial_anchor_monster() -> void:
	## 为首次引导在玩家附近加入一只普通敌人；只使用场景配置的普通兜底怪物，不创建精英类型或第二套 AI。
	if not _is_first_run_tutorial or not _has_monster_scene_available():
		return
	# 普通怪物场景；优先使用 GameWorld 的单场景兜底，它在正式场景中固定为普通虚卒·掠夺者。
	var tutorial_monster_scene: PackedScene = monster_scene if monster_scene != null else _get_random_monster_scene()
	if tutorial_monster_scene == null:
		return
	# 引导敌人位置；围绕玩家搜索清晰点位，距离由检查器参数控制且不会贴进建筑。
	var tutorial_monster_position: Vector2 = _find_tutorial_clear_position(tutorial_anchor_monster_distance, 36.0)
	if _monster_simulation_manager != null and _monster_simulation_manager.has_method("add_virtual_monster"):
		_monster_simulation_manager.call("add_virtual_monster", tutorial_monster_scene, tutorial_monster_position, 1.0, 1.0)
		return
	# 兼容直接实例；加载管理器缺失时仍生成同一普通敌人并连接既有死亡、遇敌和索敌接口。
	var tutorial_monster: Node2D = tutorial_monster_scene.instantiate() as Node2D
	if tutorial_monster == null:
		return
	_apply_monster_spawn_variation_values(tutorial_monster, 1.0, 1.0)
	tutorial_monster.add_to_group(TRAINING_MONSTER_GROUP)
	# 引导怪物父节点；沿用正式怪物容器，缺失时回退 GameWorld。
	var tutorial_spawn_parent: Node = _monster_parent if _monster_parent != null else self
	tutorial_spawn_parent.add_child(tutorial_monster)
	tutorial_monster.global_position = tutorial_monster_position
	if tutorial_monster.has_signal("player_encountered"):
		tutorial_monster.connect("player_encountered", Callable(self, "_on_monster_encountered"))
	if tutorial_monster.has_signal("died"):
		tutorial_monster.connect("died", Callable(self, "_on_monster_died").bind(tutorial_monster))
	if tutorial_monster.has_method("set_primary_target"):
		tutorial_monster.call("set_primary_target", _player)
	elif tutorial_monster.has_method("set_target"):
		tutorial_monster.call("set_target", _player)


func _spawn_monster_batch(requested_count: int = -1) -> void:
	# 实际生成数量；负值使用开局配置（先按骇入模式倍率缩放，联机再按成员数量倍率放大），补充刷新会传入当前缺口对应的批次数量。
	var resolved_spawn_count: int = _apply_population_scales(monster_spawn_count) if requested_count < 0 else requested_count
	if not _has_monster_scene_available() or resolved_spawn_count <= 0:
		return

	# 怪物生成循环索引；取值为 0 到实际生成数量减一，默认逐个创建虚拟人口并分散到整张地图。
	for _spawn_index in range(resolved_spawn_count):
		# 本次怪物场景；取值来自 monster_scenes 随机池或 monster_scene 兜底，默认用于生成不同怪物类型。
		var selected_monster_scene: PackedScene = _get_random_monster_scene()
		if selected_monster_scene == null:
			continue

		# 怪物生成位置；始终位于玩家安全距离外并避开环境障碍，虚拟记录和真实节点使用同一套位置规则。
		var spawn_position: Vector2 = _get_random_monster_spawn_position()
		# 怪物出生倍率；x 为尺寸倍率、y 为属性倍率，首次生成后由虚拟记录永久保存。
		var spawn_variation: Vector2 = _get_monster_spawn_variation()
		if _monster_simulation_manager != null and _monster_simulation_manager.has_method("add_virtual_monster"):
			_monster_simulation_manager.call("add_virtual_monster", selected_monster_scene, spawn_position, spawn_variation.x, spawn_variation.y)
			continue

		# 兼容怪物实例；加载管理器缺失时回退旧式直接实例化，确保独立场景仍可生成敌人。
		var monster: Node2D = selected_monster_scene.instantiate() as Node2D
		if monster == null:
			continue
		_apply_monster_spawn_variation_values(monster, spawn_variation.x, spawn_variation.y)
		monster.add_to_group(TRAINING_MONSTER_GROUP)
		# 怪物挂载父节点；取值为 Enemies 容器或 GameWorld，默认用于组织兼容生成节点。
		var spawn_parent: Node = _monster_parent if _monster_parent != null else self
		spawn_parent.add_child(monster)
		monster.global_position = spawn_position
		# 兼容直生怪物的遇敌信号；加载管理器缺失时仍由 GameWorld 统一写入怪物图鉴。
		if monster.has_signal("player_encountered") and not monster.is_connected("player_encountered", Callable(self, "_on_monster_encountered")):
			monster.connect("player_encountered", Callable(self, "_on_monster_encountered"))
		if monster.has_signal("died"):
			monster.connect("died", Callable(self, "_on_monster_died").bind(monster))
		if monster.has_method("set_primary_target"):
			monster.call("set_primary_target", _player)
		elif monster.has_method("set_target"):
			monster.call("set_target", _player)
		if _monster_simulation_manager != null and _monster_simulation_manager.has_method("register_monster"):
			_monster_simulation_manager.call("register_monster", monster)


func _has_monster_scene_available() -> bool:
	if not monster_scenes.is_empty():
		return true

	return monster_scene != null


func _get_random_monster_scene() -> PackedScene:
	if not monster_scenes.is_empty():
		# 全部有效权重；按怪物场景根节点配置的 spawn_weight 加总，权重越高越容易被抽中。
		var total_spawn_weight: float = 0.0
		for candidate_scene in monster_scenes:
			# 候选场景；空项不计入权重，避免损坏的检查器数组影响其它已注册怪物。
			var packed_scene: PackedScene = candidate_scene as PackedScene
			if packed_scene != null:
				total_spawn_weight += _get_monster_scene_spawn_weight(packed_scene)
		if total_spawn_weight > 0.0:
			# 本次随机阈值；落在每个场景累积权重区间内即选择该类型，概率严格等于其权重占总权重比例。
			var selection_threshold: float = _random.randf_range(0.0, total_spawn_weight)
			var accumulated_weight: float = 0.0
			for candidate_scene in monster_scenes:
				var packed_scene: PackedScene = candidate_scene as PackedScene
				if packed_scene == null:
					continue
				accumulated_weight += _get_monster_scene_spawn_weight(packed_scene)
				if accumulated_weight > 0.0 and selection_threshold <= accumulated_weight:
					return packed_scene
		# 全部权重为零；保留场景注册资格但不自然生成，符合单个场景权重为 0 的同一语义。
		return null

	return monster_scene


func _get_monster_scene_spawn_weight(monster_packed_scene: PackedScene) -> float:
	## 读取怪物场景根节点的生成权重；使用 PackedScene 状态而不实例化敌人，避免抽取概率时创建临时 AI 节点。
	if monster_packed_scene == null:
		return 0.0
	# 缓存键；资源路径稳定时跨同一局共享，运行时临时场景没有路径则使用实例 ID 隔离。
	var cache_key: String = monster_packed_scene.resource_path if not monster_packed_scene.resource_path.is_empty() else str(monster_packed_scene.get_instance_id())
	if _monster_scene_spawn_weights.has(cache_key):
		return maxf(float(_monster_scene_spawn_weights.get(cache_key, 0.0)), 0.0)
	# 场景根节点状态；怪物配置全部写在根节点，缺失字段时使用 100 的兼容默认权重。
	var scene_state: SceneState = monster_packed_scene.get_state()
	var resolved_weight: float = 100.0
	if scene_state != null and scene_state.get_node_count() > 0:
		for property_index in range(scene_state.get_node_property_count(0)):
			if str(scene_state.get_node_property_name(0, property_index)) == "spawn_weight":
				resolved_weight = maxf(float(scene_state.get_node_property_value(0, property_index)), 0.0)
				break
	_monster_scene_spawn_weights[cache_key] = resolved_weight
	return resolved_weight


func clear_monsters() -> void:
	_monster_replenishment_paused_by_training_tools = true
	if _monster_simulation_manager != null and _monster_simulation_manager.has_method("clear_population"):
		_monster_simulation_manager.call("clear_population")

	# 组内怪物节点列表；取值来自场景树训练场怪物组，默认用于清理曾经生成但不在 Enemies 容器中的怪物。
	var grouped_monsters: Array = get_tree().get_nodes_in_group(TRAINING_MONSTER_GROUP)
	# 组内怪物遍历项；取值为 Node 或其他对象，默认只处理有效 Node，修改循环来源会影响兜底清理范围。
	for grouped_monster in grouped_monsters:
		if grouped_monster is Node:
			# 组内怪物节点；取值为有效 Node，默认用于从父节点移除并立即释放。
			var grouped_monster_node: Node = grouped_monster as Node
			_free_monster_node(grouped_monster_node)

	if _monster_parent != null:
		# 怪物挂载父节点；取值为 Enemies 容器，默认用于查找需要清空的训练场怪物。
		var spawn_parent: Node = _monster_parent
		# 现有怪物节点遍历项；取值为怪物父节点下的子节点，默认全部移除，修改循环来源会影响清怪范围。
		for monster_node in spawn_parent.get_children():
			_free_monster_node(monster_node)


func respawn_monsters() -> void:
	_monster_replenishment_paused_by_training_tools = false
	_spawn_monster_batch()


func _update_monster_replenishment(delta: float) -> void:
	if _is_network_remote_client():
		# 联机客户端没有虚拟人口；补充逻辑完全由主机执行并通过复制体现。
		return
	if _is_training_mode or _monster_replenishment_paused_by_training_tools:
		return

	_monster_replenish_remaining = maxf(_monster_replenish_remaining - delta, 0.0)
	if _monster_replenish_remaining > 0.0:
		return
	_monster_replenish_remaining = maxf(monster_replenish_interval, 0.1)

	# 当前目标人口；根据正式战斗存活时间从开局人口连续增长到 5 分钟和 10 分钟里程碑。
	var target_monster_population: int = _get_target_monster_population()
	if target_monster_population <= 0:
		return

	# 当前存活敌人数；优先读取虚拟人口总量，加载范围外且未实例化的敌人同样计入。
	var alive_monster_count: int = _get_alive_monster_count()
	if alive_monster_count >= target_monster_population:
		return

	# 当前敌人缺口；取值为时间目标人口减存活人口，用于限制单批补充不会越过曲线目标。
	var monster_deficit: int = target_monster_population - alive_monster_count
	# 本次补充数量；取值为缺口与批次上限较小值，避免瞬间生成过多节点。
	var replenish_count: int = mini(monster_deficit, maxi(monster_replenish_batch_size, 1))
	_spawn_monster_batch(replenish_count)


func _get_alive_monster_count() -> int:
	if _is_network_remote_client() and _network_combat_sync != null and _network_combat_sync.has_method("get_replicated_population_count"):
		# 联机客户端人口显示；读取主机敌人快照附带的全图人口，本机没有虚拟人口记录。
		return int(_network_combat_sync.call("get_replicated_population_count"))
	if _monster_simulation_manager != null and _monster_simulation_manager.has_method("get_population_count"):
		return int(_monster_simulation_manager.call("get_population_count"))

	# 存活数量；默认从 0 开始统计组内有效敌人。
	var alive_count: int = 0
	# 怪物组成员；取值可能包含即将释放节点，默认逐项校验。
	var grouped_monsters: Array = get_tree().get_nodes_in_group(TRAINING_MONSTER_GROUP)
	# 怪物组遍历项；取值为 Variant，只统计有效 Node 且未排队释放的成员。
	for grouped_monster in grouped_monsters:
		if grouped_monster is Node and is_instance_valid(grouped_monster) and not (grouped_monster as Node).is_queued_for_deletion():
			alive_count += 1
	return alive_count


func _apply_monster_spawn_variation(monster: Node2D) -> void:
	if monster == null:
		return
	# 怪物出生倍率；x 为尺寸倍率、y 为属性倍率，兼容直接实例化路径使用同一随机规则。
	var spawn_variation: Vector2 = _get_monster_spawn_variation()
	_apply_monster_spawn_variation_values(monster, spawn_variation.x, spawn_variation.y)


func _get_monster_spawn_variation() -> Vector2:

	# 标准化波动比例；取值为 0 到 0.9，默认 0.3 形成 70% 到 130% 范围。
	var variation_ratio: float = clampf(monster_spawn_variation_ratio, 0.0, 0.9)
	# 尺寸倍率；取值在 1±波动范围内，每只敌人独立随机并直接影响视觉与碰撞尺寸。
	var size_multiplier: float = _random.randf_range(1.0 - variation_ratio, 1.0 + variation_ratio)
	# 属性倍率；与尺寸独立随机，避免大体型敌人必然拥有完全相同强度趋势。
	var attribute_multiplier: float = _random.randf_range(1.0 - variation_ratio, 1.0 + variation_ratio)
	return Vector2(size_multiplier, attribute_multiplier)


func _apply_monster_spawn_variation_values(monster: Node2D, size_multiplier: float, attribute_multiplier: float) -> void:
	if monster == null:
		return
	if monster.has_method("apply_spawn_variation"):
		monster.call("apply_spawn_variation", size_multiplier, attribute_multiplier)
	else:
		monster.scale *= Vector2(size_multiplier, size_multiplier)
	_apply_mode_extension_monster_effects(monster)


func _apply_mode_extension_monster_effects(monster: Node2D) -> void:
	## 按固定顺序把风险合约与新手保护交给怪物自身处理；直接生成与虚拟人口实体化路径均使用同一接口。
	if monster == null:
		return
	if monster.has_method("apply_mode_extension_multipliers"):
		monster.call("apply_mode_extension_multipliers", _mode_extension_effect_multipliers)
	if monster.has_method("apply_newcomer_protection_multiplier"):
		monster.call("apply_newcomer_protection_multiplier", _get_newcomer_protection_monster_attribute_multiplier())


func _get_newcomer_protection_monster_attribute_multiplier() -> float:
	## 返回本局怪物应使用的新手保护倍率；联机由主机生成路径读取自身档案并通过敌人生成消息同步给客户端。
	# 新手保护服务；缺失时按中性倍率运行，避免独立场景或旧测试缺少 AutoLoad 时阻断怪物生成。
	var newcomer_protection_service: Node = get_tree().root.get_node_or_null("NewcomerProtectionService")
	if newcomer_protection_service == null or not newcomer_protection_service.has_method("get_monster_attribute_multiplier"):
		return 1.0
	return clampf(float(newcomer_protection_service.call("get_monster_attribute_multiplier")), 0.01, 1.0)


func _get_target_monster_population() -> int:
	# 开局目标人口；取开局生成量与最低人口较大值，保证 0 秒正式战斗至少拥有 200 名地图人口。
	var initial_population: int = maxi(monster_spawn_count, monster_minimum_alive_count)
	# 第一里程碑时间；至少为 1 秒，避免检查器异常值导致插值除零。
	var first_milestone_time: float = maxf(monster_population_first_milestone_seconds, 1.0)
	# 第二里程碑时间；至少比第一里程碑晚 1 秒，保证第二段插值区间有效。
	var second_milestone_time: float = maxf(monster_population_second_milestone_seconds, first_milestone_time + 1.0)
	if _survival_time_seconds <= first_milestone_time:
		# 第一阶段比例；取值 0 到 1，控制人口从 200 连续增长到 1200。
		var first_stage_ratio: float = clampf(_survival_time_seconds / first_milestone_time, 0.0, 1.0)
		return _apply_population_scales(roundi(lerpf(float(initial_population), float(monster_population_five_minute_count), first_stage_ratio)))
	if _survival_time_seconds <= second_milestone_time:
		# 第二阶段比例；取值 0 到 1，控制人口从 1200 连续增长到 3200。
		var second_stage_ratio: float = clampf((_survival_time_seconds - first_milestone_time) / (second_milestone_time - first_milestone_time), 0.0, 1.0)
		return _apply_population_scales(roundi(lerpf(float(monster_population_five_minute_count), float(monster_population_ten_minute_count), second_stage_ratio)))
	return _apply_population_scales(maxi(monster_population_ten_minute_count, 0))


func _apply_network_population_scale(base_population: int) -> int:
	## 按联机成员数量缩放敌人人口；每多一名成员整体乘 1.5，单机、训练场与单人房间返回原值。
	if not _network_combat_active or _network_population_multiplier <= 1.0:
		return base_population
	return roundi(float(base_population) * _network_population_multiplier)


func _apply_population_scales(base_population: int) -> int:
	## 统一应用骇入模式人口倍率与联机成员倍率；先按模式缩放（零装 0.6、超频 2.0），再按联机人数放大。
	## 模式扩展补充：风险合约数量倍率与骇入协议动态倍率插入骇入模式与联机成员倍率之间，各层依次取整。
	## 开局布怪数量、人口曲线目标与同时活跃真实敌人上限都必须经过本函数，保证三处口径一致。
	# 模式人口倍率；标准骇入与训练场为 1.0，直接透传避免无意义的取整误差。
	var variant_population_multiplier: float = HackModeRules.get_population_multiplier(_hack_variant)
	# 模式缩放结果；四舍五入为整数后再交给联机倍率，保持与联机缩放相同的取整策略。
	var variant_scaled_population: int = base_population if variant_population_multiplier == 1.0 else roundi(float(base_population) * variant_population_multiplier)
	# 模式扩展人口倍率；风险合约数量词条在骇入变体之后生效，训练场与无词条配置均为 1.0。
	var extension_population_multiplier: float = maxf(float(_mode_extension_effect_multipliers.get("population_multiplier", 1.0)), 0.0)
	# 模式扩展缩放结果；独立取整后再应用联机人数倍率，避免三个调用点出现不同计算顺序。
	var extension_scaled_population: int = variant_scaled_population if extension_population_multiplier == 1.0 else roundi(float(variant_scaled_population) * extension_population_multiplier)
	# 骇入协议人口倍率；按当前团队平均协议层数动态计算，0 层固定为 1.0，不向尚未获得协议的玩家预收代价。
	var protocol_population_multiplier: float = HackProtocolRules.get_population_multiplier(_get_average_hack_protocol_count())
	# 协议缩放结果；在现有模式扩展后独立取整，最后再应用固定的联机成员倍率。
	var protocol_scaled_population: int = extension_scaled_population if protocol_population_multiplier == 1.0 else roundi(float(extension_scaled_population) * protocol_population_multiplier)
	return _apply_network_population_scale(protocol_scaled_population)


func _on_monster_encountered(monster_id: String) -> void:
	## 接收战斗怪物的首次遇敌事件并转交永久图鉴服务；GameWorld 是战斗节点与局外存档之间的协调边界。
	# 娱乐模式图鉴豁免；训练场与超频骇入均不产生正式进度，首次遇敌也不能解锁永久怪物图鉴。
	if is_settlement_disabled_mode() or _is_first_run_tutorial:
		return
	# 全局库存服务；由自动加载创建，缺失时保持战斗可运行，避免独立场景预览依赖完整游戏启动顺序。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory != null and global_inventory.has_method("register_monster_encounter"):
		global_inventory.call("register_monster_encounter", monster_id)


func _on_monster_died(monster_node: Node) -> void:
	if monster_node == null or not (monster_node is Node2D):
		return
	if not _network_combat_active:
		# 玩家套装击杀通知；联机由 NetworkCombatSync 按主机确认的最终击杀者触发，避免主机误领队友击杀。
		var equipment_set_component: Node = _player.get_node_or_null("EquipmentSetComponent") if _player != null else null
		if equipment_set_component != null and equipment_set_component.has_method("notify_enemy_killed"):
			equipment_set_component.call("notify_enemy_killed")
		if _hack_protocol_component != null and _hack_protocol_component.has_method("notify_enemy_killed"):
			# 单机协议击杀事实；联机与套装使用同一击杀归属口径，碎片和回复只奖励最终击杀者。
			_hack_protocol_component.call("notify_enemy_killed")
	if _is_first_run_tutorial and not _tutorial_first_enemy_defeated:
		_tutorial_first_enemy_defeated = true
		if tutorial_first_kill_weapon != null:
			# 首杀武器副本；深复制后作为独立地面物品生成，后续强化、耐久和丢弃都不修改项目模板。
			var tutorial_weapon: Resource = tutorial_first_kill_weapon.duplicate(true) as Resource
			_spawn_monster_drop_with_animation(tutorial_weapon if tutorial_weapon != null else tutorial_first_kill_weapon, (monster_node as Node2D).global_position)

	# 生涯统计击杀上报；单机战斗模式下本机世界的全部击杀都归属玩家侧（含友方单位击杀）。
	# 联机口径补充：联机时由 NetworkCombatSync 按主机回传的击杀归属分别计数，这里不重复上报避免主机多计队友击杀。
	if not _network_combat_active and not is_settlement_disabled_mode() and not _is_first_run_tutorial:
		# 生涯统计服务；缺失时战斗照常运行，仅丢失计数。
		var stats_service: Node = get_tree().root.get_node_or_null("StatsService")
		if stats_service != null and stats_service.has_method("record_monster_killed"):
			stats_service.call("record_monster_killed", str(monster_node.get("monster_id")))

	# 训练场只用于测试战斗，不生成任何怪物掉落，避免调试资源进入正式库存。
	# 超频骇入补充：娱乐模式拾取不进入正式库存，掉落只会堆积干扰视野，因此与训练场一样跳过怪物掉落。
	if not _is_training_mode and not is_settlement_disabled_mode():
		_try_spawn_monster_weapon_drop(monster_node as Node2D)
		_try_spawn_monster_equipment_drop(monster_node as Node2D)
		_try_spawn_enhancement_stone_drop(monster_node as Node2D)
		_try_spawn_repair_kit_drop(monster_node as Node2D)
	if _monster_simulation_manager != null and _monster_simulation_manager.has_method("unregister_monster"):
		_monster_simulation_manager.call("unregister_monster", monster_node)


func _try_spawn_monster_weapon_drop(monster_node: Node2D) -> void:
	if weapon_drop_table.is_empty() or weapon_drop_scene == null:
		return

	# 怪物武器掉落概率；基础值默认 3%，统一乘当前怪物掉落倍率并限制到 100%。
	var drop_chance: float = _get_effective_monster_drop_chance(monster_node, _get_monster_weapon_drop_chance(monster_node))
	if drop_chance <= 0.0 or _random.randf() > drop_chance:
		return

	# 掉落武器资源；取值为随机武器资源的深拷贝，默认让每个地面武器成为独立物品实例。
	var dropped_weapon: Resource = _get_random_weapon_drop_data()
	if dropped_weapon == null:
		return

	_spawn_monster_drop_with_animation(dropped_weapon, monster_node.global_position)


func _get_monster_weapon_drop_chance(monster_node: Node) -> float:
	if monster_node == null:
		return 0.0

	# 原始掉落概率；取值可能来自怪物导出属性，默认转为 0 到 1 范围。
	var raw_drop_chance: Variant = monster_node.get("weapon_drop_chance")
	if raw_drop_chance == null:
		return 0.03

	return clampf(float(raw_drop_chance), 0.0, 1.0)


func _get_random_weapon_drop_data() -> Resource:
	if weapon_drop_table.is_empty():
		return null

	# 武器池随机下标；取值为 0 到武器池末尾，默认用于随机选择掉落模板。
	var weapon_index: int = _random.randi_range(0, weapon_drop_table.size() - 1)
	# 武器模板资源；取值来自 weapon_drop_table，默认会深拷贝为独立掉落物。
	var weapon_template: Resource = weapon_drop_table[weapon_index]
	if weapon_template == null:
		return null

	# 独立武器资源；取值为模板深拷贝，默认避免多个掉落物共享同一个资源实例。
	var dropped_weapon: Resource = weapon_template.duplicate(true) as Resource
	if dropped_weapon != null:
		SECOND_HAND_ITEM_GENERATOR.call("roll_and_apply", dropped_weapon, _random, second_hand_equipment_chance)
	return dropped_weapon if dropped_weapon != null else weapon_template


func _try_spawn_monster_equipment_drop(monster_node: Node2D) -> void:
	if monster_node == null or weapon_drop_scene == null or equipment_drop_table.is_empty():
		return
	# 怪物装备掉落概率；基础值默认 3%，统一乘当前怪物掉落倍率并限制到 100%。
	var drop_chance: float = _get_effective_monster_drop_chance(monster_node, equipment_drop_chance)
	if drop_chance <= 0.0 or _random.randf() > drop_chance:
		return
	# 掉落装备资源；从自动发现池等概率抽取并深拷贝，避免多个地面装备共享状态。
	var dropped_equipment: Resource = _duplicate_random_or_highest_value_resource(equipment_drop_table, false)
	if dropped_equipment != null:
		SECOND_HAND_ITEM_GENERATOR.call("roll_and_apply", dropped_equipment, _random, second_hand_equipment_chance)
		_spawn_monster_drop_with_animation(dropped_equipment, monster_node.global_position)


func _try_spawn_enhancement_stone_drop(monster_node: Node2D) -> void:
	if monster_node == null or weapon_drop_scene == null:
		return
	# 怪物强化石掉落概率；基础值默认 5%，统一乘当前怪物掉落倍率并限制到 100%。
	var drop_chance: float = _get_effective_monster_drop_chance(monster_node, enhancement_stone_drop_chance)
	if drop_chance <= 0.0 or _random.randf() > drop_chance:
		return

	# 随机强化石；每次击杀独立创建资源实例，拾取后可按词条签名与库存已有堆叠合并。
	var enhancement_stone: EnhancementStoneData = _create_random_enhancement_stone()
	if enhancement_stone != null:
		_spawn_monster_drop_with_animation(enhancement_stone, monster_node.global_position)


func _try_spawn_repair_kit_drop(monster_node: Node2D) -> void:
	if monster_node == null or weapon_drop_scene == null or repair_kit_drop_table.is_empty():
		return
	# 怪物道具掉落概率；基础值默认 5%，统一乘当前怪物掉落倍率并限制到 100%。
	var drop_chance: float = _get_effective_monster_drop_chance(monster_node, repair_kit_drop_chance)
	if drop_chance <= 0.0 or _random.randf() > drop_chance:
		return
	# 独立道具；从自动发现池等概率抽取并深拷贝，单个空模板不会影响其他类别判定。
	var dropped_item: Resource = _duplicate_random_or_highest_value_resource(repair_kit_drop_table, false)
	if dropped_item != null:
		_spawn_monster_drop_with_animation(dropped_item, monster_node.global_position)


func _get_effective_monster_drop_chance(monster_node: Node, base_chance: float) -> float:
	# 怪物掉落倍率；未实现该属性的扩展怪物回退 1.0，负值按 0 处理以禁用全部掉落。
	var resolved_drop_multiplier: float = 1.0
	if monster_node != null and "drop_multiplier" in monster_node:
		resolved_drop_multiplier = maxf(float(monster_node.get("drop_multiplier")), 0.0)
	# 风险合约掉落倍率；所有已选词条奖励先在规则表中加算，再统一乘到怪物的四类独立掉落概率。
	var extension_drop_multiplier: float = maxf(float(_mode_extension_effect_multipliers.get("drop_chance_multiplier", 1.0)), 0.0)
	# 骇入协议团队代价倍率；按平均协议层数动态降低，0 层严格为 1.0，最低保留规则表声明的 65%。
	var protocol_team_drop_multiplier: float = HackProtocolRules.get_drop_chance_multiplier(_get_average_hack_protocol_count())
	# 最终击杀者个人掉落倍率；单机读取本机组件，联机主机按该怪物最后伤害归属读取对应成员协议。
	var protocol_killer_drop_multiplier: float = 1.0
	if _network_combat_active and _network_combat_sync != null and _network_combat_sync.has_method("get_hack_protocol_drop_multiplier_for_monster"):
		protocol_killer_drop_multiplier = maxf(float(_network_combat_sync.call("get_hack_protocol_drop_multiplier_for_monster", monster_node)), 0.0)
	elif _hack_protocol_component != null and _hack_protocol_component.has_method("get_kill_drop_chance_multiplier"):
		protocol_killer_drop_multiplier = maxf(float(_hack_protocol_component.call("get_kill_drop_chance_multiplier")), 0.0)
	return clampf(clampf(base_chance, 0.0, 1.0) * resolved_drop_multiplier * extension_drop_multiplier * protocol_team_drop_multiplier * protocol_killer_drop_multiplier, 0.0, 1.0)


func _spawn_monster_drop_with_animation(item_data: Resource, monster_position: Vector2) -> bool:
	if item_data == null:
		return false
	# 怪物掉落最终位置；复用通用散落与墙体避让规则，保证动画结束后物品可正常拾取。
	var drop_target: Vector2 = _get_scattered_drop_position(monster_position)
	# 怪物掉落飞出时长；每件物品独立随机，避免同一次击杀的多类掉落完全同步。
	var launch_duration: float = _random.randf_range(minf(monster_drop_launch_duration_min, monster_drop_launch_duration_max), maxf(monster_drop_launch_duration_min, monster_drop_launch_duration_max))
	# 怪物掉落飞出弧高；在配置范围内独立随机形成轻微层次差。
	var launch_arc_height: float = _random.randf_range(minf(monster_drop_launch_arc_height_min, monster_drop_launch_arc_height_max), maxf(monster_drop_launch_arc_height_min, monster_drop_launch_arc_height_max))
	return spawn_item_drop(item_data, drop_target, monster_position, launch_duration, launch_arc_height)


func _create_random_enhancement_stone() -> EnhancementStoneData:
	return EnhancementStoneData.create_random(
		_random,
		enhancement_stone_min_modifier_count,
		enhancement_stone_max_modifier_count,
		enhancement_stone_negative_modifier_chance,
		enhancement_stone_base_value
	)


func spawn_item_drop(item_data: Resource, drop_position: Vector2, launch_origin: Vector2 = Vector2.INF, launch_duration: float = 0.0, launch_arc_height: float = 0.0, quantity: int = 1) -> bool:
	if item_data == null or weapon_drop_scene == null:
		return false

	# 通用掉落实例；复用现有掉落场景的碰撞、浮动和拾取接口，资源类型由脚本自行显示。
	var drop_instance: Node2D = weapon_drop_scene.instantiate() as Node2D
	if drop_instance == null:
		return false

	# 掉落父节点；优先使用 Drops 容器，缺失时回退 GameWorld。
	var spawn_parent: Node = _drop_parent if _drop_parent != null else self
	spawn_parent.add_child(drop_instance)
	# 最终落点；所有普通掉落和宝箱飞出动画共同限制在地图范围内。
	var resolved_drop_position: Vector2 = _clamp_position_to_map(drop_position)
	# 是否播放飞出动画；有效起点与正时长同时存在时，先生成在箱体中心再飞向最终落点。
	var should_launch: bool = launch_origin != Vector2.INF and launch_duration > 0.0
	drop_instance.global_position = _clamp_position_to_map(launch_origin) if should_launch else resolved_drop_position
	if drop_instance.has_method("configure_item_drop"):
		drop_instance.call("configure_item_drop", item_data, quantity)
	else:
		drop_instance.set("weapon_data", item_data)
	if should_launch and drop_instance.has_method("play_launch_animation"):
		drop_instance.call("play_launch_animation", resolved_drop_position, launch_duration, launch_arc_height)
	_notify_network_drop_spawned(drop_instance, item_data, quantity, resolved_drop_position, launch_origin if should_launch else Vector2.INF, launch_duration if should_launch else 0.0, launch_arc_height if should_launch else 0.0)
	return true


func _notify_network_drop_spawned(drop_instance: Node, item_data: Resource, quantity: int, drop_position: Vector2, launch_origin: Vector2, launch_duration: float, launch_arc_height: float) -> void:
	## 联机掉落登记钩子；本地新产生的掉落广播给全员，远程复制的掉落只登记编号，单机与训练场为空操作。
	if not _network_combat_active or _network_combat_sync == null or not _network_combat_sync.has_method("on_local_drop_spawned"):
		return
	_network_combat_sync.call("on_local_drop_spawned", drop_instance, item_data, quantity, drop_position, launch_origin, launch_duration, launch_arc_height)


func _get_scattered_drop_position(center_position: Vector2) -> Vector2:
	# 丢弃尝试次数；取值为固定 8 次，默认用于尽量避开环境墙体。
	var scatter_attempt_count: int = 8
	# 标准化散落半径；取值至少为 0，默认控制丢弃武器离玩家多远。
	var scatter_radius: float = maxf(dropped_weapon_scatter_radius, 0.0)
	# 场上掉落物快照；一次散布最多 8 次尝试共用同一份列表，避免每次尝试重复分配组查询数组。
	var existing_drop_nodes: Array[Node] = get_tree().get_nodes_in_group("item_drops")
	for _attempt_index in range(scatter_attempt_count):
		# 散落角度；取值为 0 到 TAU 的随机弧度，默认让丢弃落点不完全固定。
		var scatter_angle: float = _random.randf_range(0.0, TAU)
		# 散落距离；取值为半径的 45% 到 100%，默认避免武器直接压在玩家中心。
		var scatter_distance: float = _random.randf_range(scatter_radius * 0.45, scatter_radius)
		# 候选位置；取值为中心点加随机偏移并夹到地图内。
		var candidate_position: Vector2 = _clamp_position_to_map(center_position + Vector2.RIGHT.rotated(scatter_angle) * scatter_distance)
		if not _is_position_blocked_by_environment(candidate_position, 18.0) and not _is_position_near_existing_drop(candidate_position, existing_drop_nodes):
			return candidate_position

	return _clamp_position_to_map(center_position)


func _is_position_near_existing_drop(candidate_position: Vector2, existing_drop_nodes: Array[Node]) -> bool:
	# 最小分离距离；取值至少为 0，关闭时允许多个物品完全重叠以兼容旧调试配置。
	var minimum_separation: float = maxf(dropped_item_minimum_separation, 0.0)
	if minimum_separation <= 0.0:
		return false
	# 最小分离距离平方；与平方距离比较等价于原距离判断，省去每个掉落物一次开方。
	var minimum_separation_squared: float = minimum_separation * minimum_separation
	# 已有掉落物遍历项；只检查仍在场景树中且拥有二维位置的有效节点。
	for drop_node in existing_drop_nodes:
		if drop_node is Node2D and is_instance_valid(drop_node) and (drop_node as Node2D).global_position.distance_squared_to(candidate_position) < minimum_separation_squared:
			return true
	return false


func get_world_drop_total_value() -> int:
	## 返回地图上当前仍可拾取掉落物的总价值；普通节点按一件计价，堆叠丢弃节点按其数量计价，飞出动画期间暂不在组内。
	var total_value: int = 0
	for raw_drop in get_tree().get_nodes_in_group("item_drops"):
		# 掉落节点；必须提供只读资源接口，异常或正在删除的节点不计入成功撤离被动。
		var drop_node: Node = raw_drop as Node
		if drop_node == null or not is_instance_valid(drop_node) or drop_node.is_queued_for_deletion() or not drop_node.has_method("get_item_data"):
			continue
		# 地面物品资源；强化与耐久物品优先使用有效价值，普通堆叠道具使用单个基础价值。
		var item_resource: Resource = drop_node.call("get_item_data") as Resource
		if item_resource == null:
			continue
		# 地面物品数量；旧掉落节点没有数量接口时按一件兼容，整组丢弃节点按实际数量保持总价值不变。
		var drop_quantity: int = maxi(int(drop_node.call("get_quantity")), 1) if drop_node.has_method("get_quantity") else 1
		# 单件有效价值；强化与耐久物品读取动态价值，普通材料读取固定基础价值。
		var unit_value: int = maxi(int(item_resource.call("get_effective_value")) if item_resource.has_method("get_effective_value") else int(item_resource.get("value")), 0)
		total_value += unit_value * drop_quantity
	return total_value


func _free_monster_node(monster_node: Node) -> void:
	if monster_node == null or not is_instance_valid(monster_node):
		return
	if _monster_simulation_manager != null and _monster_simulation_manager.has_method("unregister_monster"):
		_monster_simulation_manager.call("unregister_monster", monster_node)

	if monster_node.get_parent() != null:
		monster_node.get_parent().remove_child(monster_node)

	monster_node.free()


func _find_tutorial_clear_position(preferred_distance: float, clearance_radius: float) -> Vector2:
	## 围绕玩家按等角度搜索引导点位；开局敌人和两分钟撤离点共用该算法，避免各自维护障碍与边界规则。
	# 搜索中心；玩家缺失的隔离场景回退世界原点。
	var search_center: Vector2 = _player.global_position if _player != null else Vector2.ZERO
	# 有效搜索距离；至少大于清障半径两倍，避免候选与玩家位置重叠。
	var resolved_distance: float = maxf(preferred_distance, maxf(clearance_radius, 1.0) * 2.0)
	# 起始角度；每局随机旋转整组候选，但候选间距与尝试数量保持稳定。
	var starting_angle: float = _random.randf_range(0.0, TAU)
	# 等角候选数量；默认 32 个方向足以绕开常规建筑群，同时只在两次引导生成时执行。
	var attempt_count: int = 32
	for attempt_index in range(attempt_count):
		# 候选角度；围绕整圆均匀分布，避免连续随机在同一障碍方向重复失败。
		var candidate_angle: float = starting_angle + TAU * float(attempt_index) / float(attempt_count)
		# 候选位置；先按期望距离生成，再限制到地图范围内。
		var candidate_position: Vector2 = _clamp_position_to_map(search_center + Vector2.RIGHT.rotated(candidate_angle) * resolved_distance)
		if not _is_position_blocked_by_environment(candidate_position, maxf(clearance_radius, 1.0)):
			return candidate_position
	# 退化候选；极端密集地图没有清晰方向时仍给出地图内位置，避免引导流程因无目标永久阻塞。
	var fallback_position: Vector2 = _clamp_position_to_map(search_center + Vector2.RIGHT.rotated(starting_angle) * resolved_distance)
	return fallback_position


func _get_random_monster_spawn_position() -> Vector2:
	# 怪物生成尝试次数；取值为固定 48 次，默认用于同时满足玩家安全距离、地图边界和障碍避让。
	var spawn_attempt_count: int = 48
	# 怪物生成尝试索引；取值为 0 到 spawn_attempt_count - 1，默认逐次寻找不被障碍覆盖的位置。
	for _attempt_index in range(spawn_attempt_count):
		# 候选生成点；取值来自环形随机位置并夹取到地图内，默认用于检测是否避开环境障碍。
		var candidate_position: Vector2 = _get_random_monster_spawn_candidate()
		if _player != null and candidate_position.distance_to(_player.global_position) < monster_spawn_min_distance:
			continue
		if _is_monster_spawn_too_close_to_network_players(candidate_position):
			continue
		if not _is_position_blocked_by_environment(candidate_position, 36.0):
			return candidate_position

	return _get_random_monster_spawn_candidate()


func _is_monster_spawn_too_close_to_network_players(candidate_position: Vector2) -> bool:
	## 联机多玩家生成保护；候选点必须同时远离全部玩家阵营单位（本地玩家与队友化身）和大逃杀预定出生点，单机直接放行。
	## 该保护同时覆盖开局布怪与战斗期间的人口补充，只有主机会生成怪物，客户端不承担该开销。
	if not _network_combat_active:
		return false
	# 最小安全距离平方；与单机玩家保护共用同一配置，使用平方比较避免逐候选开方。
	var min_distance_squared: float = monster_spawn_min_distance * monster_spawn_min_distance
	# 大逃杀预定出生点遍历项；开局布怪时化身尚未创建，用出生点表保证每名玩家降生区域安全。
	for spawn_position in _network_spawn_positions.values():
		if spawn_position is Vector2 and (spawn_position as Vector2).distance_squared_to(candidate_position) < min_distance_squared:
			return true
	# 玩家阵营单位遍历项；战斗期间的人口补充据此避开全部存活玩家与化身当前位置。
	for combat_target in get_tree().get_nodes_in_group("player_combat_target"):
		if combat_target is Node2D and is_instance_valid(combat_target) and (combat_target as Node2D).global_position.distance_squared_to(candidate_position) < min_distance_squared:
			return true
	return false


func _get_random_monster_spawn_candidate() -> Vector2:
	if monster_spawn_across_full_map:
		# 地图半边长；取值来自当前地图尺寸，用于整图均匀采样。
		var half_size: float = get_map_half_size()
		# 实际边界留白；取值至少为一个网格尺寸且不超过地图半边长，防止生成区反转。
		var edge_margin: float = clampf(maxf(monster_spawn_edge_margin, grid_size), 0.0, maxf(half_size - 1.0, 0.0))
		# 可生成坐标上限；取值为地图半边长减留白，默认在正负范围内均匀分布。
		var spawn_limit: float = maxf(half_size - edge_margin, 1.0)
		return Vector2(
			_random.randf_range(-spawn_limit, spawn_limit),
			_random.randf_range(-spawn_limit, spawn_limit)
		)

	# 生成中心点；取值为玩家位置或世界原点，默认让怪物围绕玩家随机刷新。
	var spawn_center: Vector2 = _player.global_position if _player != null else Vector2.ZERO
	# 标准化最大生成距离；取值至少为最小距离，默认防止配置错误导致随机范围反转。
	var resolved_max_distance: float = maxf(monster_spawn_max_distance, monster_spawn_min_distance)
	# 本次生成角度；取值为 0 到 TAU 的随机弧度，默认用于环形分布。
	var spawn_angle: float = _random.randf_range(0.0, TAU)
	# 本次生成距离；取值为最小到最大生成距离，默认用于控制怪物远近。
	var spawn_distance: float = _random.randf_range(monster_spawn_min_distance, resolved_max_distance)
	# 原始生成位置；取值可能超出地图边界，默认用于后续边界夹取。
	var raw_spawn_position: Vector2 = spawn_center + Vector2.RIGHT.rotated(spawn_angle) * spawn_distance
	return _clamp_position_to_map(raw_spawn_position)


func _is_position_blocked_by_environment(position: Vector2, radius: float) -> bool:
	# 检测矩形；取值为以 position 为中心的方形区域，默认近似角色或怪物碰撞体范围。
	var check_rect: Rect2 = Rect2(position - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	# 环境障碍矩形遍历项；取值为世界坐标 Rect2，默认用于判断候选点是否落入墙体或建筑。
	for obstacle_rect in _environment_obstacle_rects:
		if obstacle_rect.intersects(check_rect):
			return true

	return false


func _clamp_position_to_map(position: Vector2) -> Vector2:
	# 地图半边长；取值由 grid_size 和 grid_extent 计算，默认用于限制出生点不超出网格地图。
	var half_size: float = grid_size * float(grid_extent)
	# 地图边界留白；取值为一个网格尺寸，默认避免怪物贴边生成。
	var edge_margin: float = grid_size
	return Vector2(
		clampf(position.x, -half_size + edge_margin, half_size - edge_margin),
		clampf(position.y, -half_size + edge_margin, half_size - edge_margin)
	)
