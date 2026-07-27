# 游戏基础框架

本文档说明《星穹骇客（Star Hacker）》的运行入口、系统分层、数据流、持久化边界和扩展协议。玩家规则与数值以 `docs/游戏机制与玩法内容.md` 为准；内容创建、敌人 AI、股市、矿场、局域网联机和 UI 分别由对应模块文档维护。

## 1. 运行入口

| 入口 | 实现 | 职责 |
| --- | --- | --- |
| 主菜单 | `res://scenes/ui/main_menu.tscn`、`res://scripts/ui/main_menu.gd` | 项目主场景；底部直接打开角色、背包、仓库、商店、锻造、据点、派遣、悬赏及模式入口；普通样式“金融 ▲”位于“统计 ▲”左侧，两者分别向上展开单列的股市/矿场/保险/银行和图鉴/生涯入口；点击“骇入”先选择标准/零装/超频骇入，再进入可多选或不选的模式扩展窗口；同一场景可作为大厅局外面板宿主 |
| 主大厅 | `res://scenes/game/main_lobby.tscn`、`res://scripts/game/lobby_world.gd` | 承载当前角色自由移动、攻击、技能、静态交互设施与大厅 HUD；不创建敌人、掉落、撤离或战斗结算 |
| 联机大厅 | `res://scenes/game/multiplayer_lobby.tscn`、`res://scripts/game/multiplayer_lobby_world.gd`（继承 `LobbyWorld`） | 主菜单“联机”入口目标场景；进场自动打开联机面板，左上角提供“联机设置”入口，房间成员经 `NetworkLobbySync` 在同一大厅内互相可见；玩法约束与主大厅一致 |
| 角色系统 | `res://scenes/ui/character_select.tscn`、`res://scripts/ui/character_select.gd` | 完整模式展示可选角色并持久化确认结果；当前角色模式隐藏角色列表，供战斗内只读查看同一套属性与技能详情 |
| 战斗世界 | `res://scenes/game/game_world.tscn`、`res://scripts/game/game_world.gd` | 承载玩家、地图、环境、敌人人口、宝箱、掉落与撤离流程 |
| 玩家预制体 | `res://scenes/characters/player.tscn`、`res://scripts/player/player_controller.gd` | 组合输入、移动、战斗属性、装备和攻击组件 |

主菜单和主大厅进入正式骇入前，把模式、骇入模式变体、模式扩展 ID 与扩展专属配置写入 `SessionState`；这些字段都只在运行期有效。训练场入口显式复位为 standard 并清空扩展，联机开局由 `NetworkSession` 按房主最终权威值写入。三种骇入模式的分组、文案与倍率集中在 `HackModeRules`，模式扩展与风险词条集中在 `ModeExtensionRules`，31 项局内协议与碎片/代价数值集中在 `HackProtocolRules`。`GameWorld` 入场时取得模式结果并按需动态创建 `HackProtocolComponent`：骇入模式负责人口、二手概率与超频豁免，风险合约汇总字典把怪物属性、耐久、视野、背包、小地图和掉落倍率分发给各数据所有者，骇入协议组件只维护本机本局状态。`CombatHud` 在 GameWorld 完成状态应用后的延后帧重新读取娱乐模式、小地图禁用状态与协议组件，零装封存由 `GlobalInventory.begin_combat_run(bare_loadout)` 负责。完整模式扩展边界见 `docs/mode_extensions.md`。已确认角色由同一服务跨场景保存；角色页的一次性返回场景同样由该服务持有但不写入存档，使主菜单与大厅入口能各自原路返回。所有主场景切换统一经 `SceneTransition` 执行，业务 UI 不直接维护过渡动画。

## 2. AutoLoad 服务

`project.godot` 是 AutoLoad 注册的唯一清单。

| 服务 | 核心职责 | 持久化 |
| --- | --- | --- |
| `SaveArchiveService` | 作为首个 AutoLoad，按白名单导出、导入或删除全部活动存档；导入前备份，导入或删除成功后重启，删除重启时在其他服务读档前完成保护性清理 | 玩家选择的 `.lisbamsave`；导入备份位于 `user://save_import_backup_<时间戳>/`；删除保护标记位于 `user://save_delete_pending_v1.marker` |
| `SaveLocationMigration` | 历史迁移实现占位；未在 `project.godot` 注册，不参与当前 AutoLoad 启动 | 无新增持久化；既有完成标记不再读取 |
| `ContentCatalog` | 启动时扫描角色、武器、装备、道具、怪物和扩展包清单，按角色解锁状态过滤内容池 | 无 |
| `SessionState` | 保存当前游戏模式、骇入模式、模式扩展与风险词条、已确认角色、永久角色/扩展包解锁状态及角色页一次性返回目标 | `user://character_unlocks.json`；角色选择和解锁永久保存，模式、扩展配置与返回目标仅运行期 |
| `InputBindings` | 管理默认与自定义输入映射 | `user://input_bindings.cfg` |
| `UiStyleSettings` | 管理“黑蓝科技风 / 黑白简约风”选择与通用控件主题即时刷新，不覆盖业务语义颜色或节点材质 | `user://ui_style_settings.cfg` |
| `DebugSettings` | 管理开发者调试选项 | `user://debug_settings.cfg` |
| `GlobalInventory` | 拥有星穹、仓库、背包、装备槽、持仓、永久图鉴发现记录和战斗结算数据 | `user://global_inventory.json` |
| `ShopService` | 生成普通商店与灰市库存，维护刷新状态 | `user://shop_state.json` |
| `HideoutService` | 维护六座据点设施等级、建造队列与六类只读加成接口 | `user://hideout_state.json` |
| `InsuranceService` | 维护骇入保单、死亡理赔、账户统计与保险股行为累计；必须注册在 `StockMarketService` 之前，保证对局结束时理赔先于股市正式结算入池 | `user://insurance_state.json` |
| `StockMarketService` | 维护行情、事件、证券币、杠杆合约、交易历史记录、通知记录和对局行为影响 | `user://stock_market_state.json` |
| `MiningFarmService` | 维护算力币、矿场资产、在线收益和临时增益 | `user://mining_farm_state.json` |
| `BankService` | 维护活期账户、定期存单、信用贷款、违约冻结与到期级联扣款 | `user://bank_state.json` |
| `DispatchService` | 维护派遣委托、在线倒计时、大成功判定、完成报告与角色锁定查询 | `user://dispatch_state.json` |
| `StatsService` | 生涯统计：怪物击杀计数、物品获得计数、对局与撤离统计、单局之最与财富曲线采样；战斗与库存挂点上报事实事件，图鉴计数、统计面板与悬赏系统只读取本服务或订阅其信号 | `user://stats_state.json` |
| `BountyService` | 每日悬赏：按本地日期刷新随机悬赏、订阅 `StatsService` 事实信号推进进度、完成后自动发放星穹或稀有强化石；必须注册在 `StatsService` 之后 | `user://bounty_state.json` |
| `BannerNotificationService` | 屏幕顶端全局横幅通知：CanvasLayer 图层 `1200` 高于场景过渡层，`process_mode = ALWAYS` 战斗内外与暂停期间均可播放；持有横幅开关并订阅强平等业务信号，业务服务不反向依赖 | `user://banner_notification_settings.cfg` |
| `SceneTransition` | 统一场景切换和黑屏过渡 | 无 |
| `NetworkSession` | 局域网联机会话：建房、UDP 房间发现、加入、成员名册与准备、共享地图种子分发、统一开局与战斗消息中继；`process_mode = ALWAYS` 且跨场景保持连接，完整协议见 `docs/multiplayer.md` | 无 |
| `NetworkRoomStatusOverlay` | 联机房间状态字幕：CanvasLayer 图层 `120`，入房期间屏幕顶部常驻“联机房间 N/M”（已准备数/总人数），订阅名册与会话信号即时刷新并按 0.25 秒轮询兜底，正式战斗场景内隐藏；纯展示不拦截鼠标 | 无 |

服务是数据所有者，面板只读取快照、发出命令并响应信号。新增跨场景状态时先确认归属，不得在多个 UI 脚本中各保存一份可变副本。

## 3. 分层与职责

### 3.1 数据层

- `CharacterData`、`ActiveSkillData`、`PassiveSkillData`、`WeaponData`、`EquipmentData`、`RepairKitData` 和 `ConsumableData` 描述可保存、可复制的角色、技能与物品配置；技能详细协议见 `docs/skill_system.md`。
- `ContentPackData` 只声明一个角色扩展包拥有的武器、装备、道具与怪物路径；`EquipmentSetData` 只声明共享套装门槛、显示原文、属性加成与特殊效果参数。
- `EnhancementStoneData` 保存强化石品质、目标类型和词条方向；逐属性强化幅度、兼容规则与正式词条池集中在 `EnhancementRules`。特化品质额外在资源中保存散射、穿透、弹射或连击的 `+1/+2` 离散点数；四项机制不进入普通四品质词条池。
- `EnhancementRules` 同时声明单件武器或装备最多使用 20 颗强化石；`WeaponData` 与 `EquipmentData` 分别在数据层记录已使用次数、返回剩余次数并拒绝第 21 次强化。
- `InventoryLimits` 集中声明背包 50 组容量与资源单组 10 件现行上限；库存、地面掉落和 UI 不各自复制这些数字。历史 99 件常量只保留未调用兼容接口，不参与当前读档。
- `SecondHandItemGenerator` 集中执行武器装备 30% 二手判定、1 至 20 次按 `21 - 次数` 递减权重抽取的历史强化，以及 1% 至 99% 耐久消耗；怪物、宝箱和普通商店只负责提供新物品实例与随机源。
- `.tres` 保存单个内容的基础数值。脚本默认值只作为缺省值，场景或资源覆盖值优先。
- 新内容通过 `ContentCatalog` 自动注册，创建流程见 `docs/content_authoring.md`。

### 3.2 组件层

| 组件 | 单一职责 |
| --- | --- |
| `PlayerInputComponent` | 把 InputMap 转换为移动、瞄准、攻击、疾跑和冲刺意图，并分别保存攻击按下边沿与持续状态；战斗输入关闭时移动意图同步归零，内部 `dodge` ID 仅用于旧按键存档兼容 |
| `ActiveSkillComponent` | 管理三个主动技能槽的按下、瞄准、锁定、蓄力、松手释放、能量与冷却；技能动作在 GUI 前接收并由战斗输入开关统一隔离，训练场可临时禁用主动技能冷却 |
| `PassiveSkillComponent` | 按角色资源同时创建多个被动行为，并在角色切换时清理各自长期状态 |
| `SkillTargetingVisual` | 绘制方向、位置和锁定目标范围，不参与目标合法性或命中结算 |
| `SkillChargeBar` | 显示角色头顶蓄力比例，由武器与主动技能共用，不拥有蓄力时间 |
| `WeaponChargeComponent` | 维护可蓄力武器的时间、移动倍率与蓄力期间减伤；近战蓄力时请求真实命中形状的纯视觉范围预览，不执行攻击成本 |
| `TemporaryBuffComponent` | 管理消耗品限时效果、同 ID 刷新和到期属性清理 |
| `TopDownMovementComponent` | 合成输入速度与外部击退并执行角色物理移动 |
| `CombatStatsComponent` | 维护生命、0.1 精度能量、攻防、恢复和死亡状态；支持按稳定来源临时暂停自然能量恢复 |
| `HackProtocolComponent` | 每名玩家独立维护局内数据碎片、固定三选一、协议叠加层与条件效果；通过稳定来源接口写入玩家和属性组件，不拥有 UI、联机或永久存档 |
| `CombatCamera` | 跟随玩家、叠加屏幕震动，并在玩家传送时用反向偏移和短时补间平滑追赶新位置 |
| `RangedAttackComponent` | 校验攻击条件、为普通或散射攻击构造弹体偏移，并把穿透、弹射、连击参数传入弹体；空闲时关闭处理，枪口空间查询复用组件私有形状 |
| `MeleeAttackComponent` | 管理近战命中框、命中去重、冲击、敌方弹体清除和不启用碰撞的蓄力范围预览；命中窗口与冷却均结束后关闭处理 |
| `EquipmentComponent` | 代理装备槽并聚合有效战斗属性 |
| `EquipmentSetComponent` | 按套装稳定 ID 统计未损坏穿戴件、汇总档位属性并结算世界特殊效果；运行时套装状态由装备变化信号驱动缓存 |
| `InventoryComponent` | 代理背包操作；全局服务缺失时才使用本地回退 |
| `DamageReceiverComponent` | 统一可受伤目标的伤害接收入口 |
| `CombatDamageCalculator` | 统一伤害、攻防和暴击计算 |
| `CombatHudSlotView` | 统一局内主动技能槽与常驻武器槽的纯展示接口，不拥有技能或装备数据，不承担物品卡牌交互 |
| `SelectedCharacterRuntimeComponent` | 从 `SessionState` 读取当前角色档案，并统一把名称、基础属性、主动技能、被动技能和基础移速注入玩家预制体 |
| `LobbyInteractionComponent` | 按固定批次选择大厅中距离碰撞边缘最近的合法实体，把可重绑定 F 动作转换为稳定 action ID 请求 |

`PlayerController` 是组合根，只协调组件、朝向和战斗反馈，不拥有库存、输入解析或攻击公式。新增角色优先替换数据和子组件，避免扩张聚合脚本。

角色技能同样不进入 `PlayerController`。`GameWorld` 与 `LobbyWorld` 都委托 `SelectedCharacterRuntimeComponent` 把当前 `CharacterData` 的主动与被动资源数组注入技能组件；行为实例通过明确接口访问属性、目标和地图标记。

### 3.3 世界与敌人层

- `GameWorld` 负责地图边界、独立背景网格绘制、环境生成、探索记录、撤离点、宝箱、掉落池、虚拟人口目标和共享导航缓存；怪物类型按各场景根节点的 `spawn_weight` 占比抽取，背景网格间距不参与玩法边界或导航计算。它还接收怪物遇敌事件并交给 `GlobalInventory` 持久化图鉴发现状态。
- `LobbyWorld` 只组合玩家、共享角色配置、大厅交互、HUD 与主菜单面板宿主；面板打开时统一禁用玩家物理处理和实体交互，关闭后恢复，不启动 `GlobalInventory.begin_combat_run()` 或任何战斗时间线。
- `LobbyInteractable` 是大厅当前统一设施占位体：使用第 5 物理层的 `StaticBody2D` 阻挡玩家与弹体，不实现受伤接口；未来可替换视觉子节点，但必须保留 action ID、边缘距离查询和不可移动碰撞协议。
- `MonsterSimulationManager` 只负责虚拟敌人记录与真实节点之间的分批物化和休眠，并转发真实怪物的遇敌事件，不访问存档服务。
- `BasicMonster` 组合感知、战术和移动组件；`RangedMonster` 只增加安全距离与射击行为。
- `WeaponDrop` 是统一地面物品载体，可承载武器、装备、强化石和道具的独立资源副本；武器与自然掉落默认数量为 1，玩家整组丢弃的可堆叠资源由单个节点保存 1 至 10 的数量并在拾取时原子合并。
- 虚拟敌人物化时优先调用 `set_primary_target()`，确保组合根同时保存长期玩家目标与当前目标；只有不支持该协议的自定义节点才回退 `set_target()`。带有稳定 `monster_id` 的基础怪物会在有效玩家目标注入时发出遇敌信号，重复物化由库存服务按 ID 去重。
- 未交互宝箱不注册逐帧处理；HUD 以 0.12 秒默认批次刷新附近掉落物与宝箱目标，并在同一批次复用掉落物查询结果。按下或松开拾取键仍即时开始或停止已选宝箱交互，长按期间继续逐帧复核新掉落物以维持拾取优先级。

- 联机骇入时 `GameWorld` 动态创建 `NetworkCombatSync`（节点组 `network_combat_sync`）作为局内唯一实体复制协调者：主机权威产出敌人并向客户端复制傀儡，队友以 `RemotePlayerAvatar` 化身互相可见且可被敌人索敌命中，掉落与宝箱由主机先到先得仲裁；客户端 `GameWorld` 跳过虚拟人口初始化与补充。骇入协议仅互播每名成员已获得的稳定 ID，主机用有效成员平均层数结算动态人口和掉落代价。地图、宝箱布点与撤离点位置依靠共享种子在各端确定性复现，不经网络传输。架构与消息协议见 `docs/multiplayer.md`。

敌人状态机与加载协议见 `docs/enemy_ai.md`，掉落概率、人口曲线和撤离数值见机制总表。

### 3.4 UI 层

- `CombatHud` 负责局内信息、暂停、地图、模式扩展查看入口、拾取提示、物资撤离和结算编排，不直接拥有库存或模式扩展数据。暂停左栏只为本局已启用扩展显示入口：`RiskContractViewPanel` 从 `SessionState` 读取风险 ID，`HackProtocolViewPanel` 从本机组件读取协议 ID；生命能量面板上方的数据碎片条读取组件快照与 `InputBindings` 实际键位，长按达标才显示不暂停世界的 `HackProtocolSelectPanel`。物资撤离面板由 `SupplyExtractionPanel` 在左侧武器栏和右侧防具栏中展示全部已装备槽位，两个分区只向 `GlobalInventory` 的统一报价与原子送回接口发起操作。
- `LobbyHud` 负责大厅左上切换按钮、最近设施提示、角色生命能量、主动技能和武器快照；它不处理 F 输入、设施距离或场景动作。主菜单以 `lobby_host_mode` 嵌入更高 CanvasLayer，只复用局外面板，不复制背包、仓库、商店等业务 UI。
- `EncyclopediaPanel` 读取 `ContentCatalog` 的全量武器、装备、道具与怪物模板，并通过 `GlobalInventory` 的稳定发现记录决定显示正式信息或“？？？”。怪物只在离树场景实例中读取稳定 ID、说明和基础属性，首次有效遇敌后解锁；左侧列表只负责选择当前条目，右侧物品详情复用 `ItemDetailFormatter`，怪物详情显示其固定基础数值。关键词筛选匹配名称、类型和说明，条目固定按基础内容、`stelle`（星）扩展包、其余扩展包目录顺序分组，并在每个扩展包前显示标题分割。组内装备按套装聚合并固定为头部、躯干、腿部、脚部；资源按初级、中级、高级、极品排列，无法识别品质时回退名称排序。它不复制物品数值或规则、不修改库存，也不把浏览、商店预览或临时快照视为获得。图鉴条目名称行最右侧与详情首行显示 `StatsService` 提供的获得数量或击杀数量，图鉴只读取计数不写入统计。
- `HackModeSelectPanel` 按 `HackModeRules` 定义表构建“战斗模式 / 娱乐模式”两组模式卡并派发 `mode_selected`；窗口内容四周使用左右 18、上下 16 像素页边距，写入会话状态与场景切换由主菜单宿主完成。`MainMenu` 自身维护金融与统计两个互斥分类：普通样式的分类按钮展开时在所属按钮正上方以 0.18 秒动画打开纵向列表，分类子按钮仍复用原有面板打开回调；`BountyPanel` 与 `StatsPanel` 同样使用左右 18、上下 16 像素页边距，前者只读取 `BountyService` 快照并订阅其变化信号，后者只读取 `StatsService` 快照，财富曲线由面板内部类 `WealthCurveChart` 按采样数组绘制。三个面板都通过主菜单遮罩复用，不直接访问战斗节点。
- `CombatHud` 运行时实例化角色系统的当前角色模式，负责 O 键打开、关闭、输入锁定和场景树暂停；角色档案、属性条与技能卡片仍由角色系统从 `SessionState` 读取，HUD 不保存副本。
- 战斗常驻 HUD 将技能栏放在屏幕左下角、武器栏放在屏幕右下角，角色名字、生命与能量独立保留在底部中心；常驻 HUD 节点必须位于全部交互遮罩之前，菜单显示时不依赖逐项隐藏也不会覆盖菜单内容。
- 右下常驻武器栏由 `CombatHud` 直接创建 `CombatHudSlotView` 并读取装备组件快照，顶部使用与技能按键相同的居中区域显示“远程 1 / 远程 2 / 近战”，下方显示武器名、能耗、耐久、当前手持高亮和攻击冷却；它不复用 `WeaponSlotControl` 或 `ItemCardView`，装备、卸下、修复、强化和拖拽操作只存在于背包等交互界面。
- 主菜单与暂停设置复用 `SaveTransferControl` 提供存档导出、导入、删除和文件选择；控件只调用 `SaveArchiveService`，不直接访问各业务存档。`SaveDeletionConfirmationDialog` 独立负责“确认删除”精确输入校验，不拥有文件删除权限。
- `SharedBackpackPanel` 同时服务主菜单和战斗 HUD；上下文只决定丢弃和局外仓库快捷入口等少量业务差异，容量标签始终读取 `GlobalInventory` 的真实背包组数。
- `InventoryQuery` 为仓库、背包、商店、锻造与结算提供无副作用的分类、强化词条筛选、套装筛选、搜索和排序结果；`EquipmentSetFilterControl` 统一维护套装多选 UI，不拥有库存数据。
- `ItemCardView`、`WeaponDurabilityBar` 和 `ItemDetailFormatter` 统一物品展示，宿主只提供操作协议。`ItemCardView` 和 `CombatHudSlotView` 通过 `UiStyleGuide` 切换卡片表面色板，耐久和其他业务语义色不参与主题替换。
- `CommonConfirmationDialog`、`SaveDeletionConfirmationDialog`、`SellQuantityDialog`、`SecuritiesTransferDialog`、`EnhancementResultDialog` 和 `ItemActionPopup` 分别承载明确的弹窗交互。
- `UiStyleSettings`、`UiStyleSelector`、`UiStyleGuide`、`DialogOuterFrame`、`ProgressSliderVisual` 和 `CharacterSkillCard` 分别统一风格状态、设置入口、窗口、弹窗、滑条与角色技能详情视觉，规则见 `docs/ui_style.md`。
- 背包、仓库和锻造等库存长列表只在自身可见时消费库存变化信号；隐藏期间仅记录待刷新状态，重新打开后从 `GlobalInventory` 读取一次最新快照。同一帧连续出现库存、装备、仓库或星穹信号时，每个可见面板最多重建 1 次列表。
- 可见的仓库与共享背包按资源实例身份复用 `StorageItemControl`：容器内移动只更新真实来源下标，数量或状态变化只刷新对应卡片，跨容器移动只创建目标新增卡片并释放来源移出卡片；未变化物品不重新创建视觉节点、详情文本或信号连接。
- 战斗 HUD 的生命、能量与护盾继续由信号即时刷新；生存时间、全地图人口和撤离提示默认每 0.1 秒刷新。主动技能栏以固定 0.05 秒间隔更新三槽冷却与发动条件，不参与技能实际计时。

UI 不得通过字符串 `call()` 猜测已知组件接口，也不得复制服务公式来预判最终结果。操作提交前后的合法性都由数据所有者复核。

## 4. 核心数据流

### 4.1 内容发现

```text
约定目录中的资源或场景
        -> ContentCatalog 启动扫描与稳定 ID 去重
        -> ContentPackData 建立内容路径与所属角色关系
        -> SessionState 永久角色解锁状态过滤专属内容
        -> 商店 / 掉落 / 开发者工具 / 角色列表查询
        -> 业务系统复制实例或实例化场景
```

目录在单次运行中不持续轮询。新增内容后需等待 Godot 导入并重新启动项目。

### 4.2 战斗攻击

```text
InputMap -> PlayerInputComponent -> PlayerController
         -> WeaponChargeComponent（仅显式蓄力武器）
         -> RangedAttackComponent / MeleeAttackComponent（装备槽主通道）
         -> HybridRangedAttackComponent / HybridMeleeAttackComponent（混合副通道）
         -> 弹体或命中框 -> DamageReceiverComponent
         -> CombatDamageCalculator -> 生命、击退与反馈
```

一次攻击的能量、耐久和坐力由攻击流程统一结算。弹体数量、连击轮数或混合武器的两个命中通道不得重复扣除单次成本。`hybrid` 武器每次同时执行远程与近战效果，统一结算 1 次能量、1 次坐力和 2 点耐久；普通武器结算 1 点耐久。怪物攻击坐力由 `BasicMonster` 独立结算：近战前坐在命中后触发，远程后坐在弹体创建成功后触发，不与玩家武器成本或韧性规则耦合。

攻击输入同时保留“一次按下请求”和“当前是否按住”两种状态。普通武器可用按下请求完成单发攻击；可蓄力武器用按住状态累计时间。若完整按下与松开发生在两个物理帧之间，控制器仍消费一次按下请求，并在开始蓄力后立即生成 `0 秒/0%` 最低蓄力快照，不等待下一物理帧也不把该点击视为取消。主动技能瞄准、强制移动、冲刺、战斗输入关闭或死亡期间会丢弃尚未消费的武器按下请求，限制解除后不会延迟补发旧攻击。

混合武器的远程与近战伤害、距离、冲击分别拥有独立基础值；`damage`、`attack_distance`、`impact_force` 强化各保存一份累计比例并由两个通道共同读取。远程槽和近战槽各自保留主攻击组件，混合武器附带的另一通道由专用副组件执行；四个组件分别保存运行时状态，来源槽主组件决定该混合武器何时可再次使用，副组件状态不得占用另一装备槽主组件。武器效果通过显式能力字段启用，未持有效果的武器不会进入蓄力状态。

玩家控制器固定按输入读取装备来源：左键只读取当前远程槽，右键只读取近战槽，不进行空槽跨类型回退。混合攻击开始前会预检主、副两个组件，任一组件仍在冷却或攻击窗口中时都不会退化为单通道攻击。HUD 只读取远程槽与近战槽的主攻击组件冷却；混合副通道冷却不显示、不映射到装备槽，也不参与遮罩比例合并。

武器与主动技能只使用玩家节点下的唯一 `SkillChargeBar`。组件通过稳定所有者 ID 取得显示，只有当前所有者可更新或隐藏；近战武器蓄力期间，主近战组件使用同一有效攻击距离和瞄准方向显示命中区域，但保持 `monitoring=false`，不会提前造成伤害。成功冲刺先取消当前武器或技能蓄力，再进入位移，失败冲刺不改变蓄力状态。冲刺本身不向受伤入口提供无敌或伤害过滤。

玩家伤害修正按语义聚合：全部“增伤/造成的伤害提高”比例在一个增伤乘区内加算，全部“免伤/受到的伤害降低”比例在一个免伤乘区内加算。稳定来源由 `PlayerController` 的来源 ID 接口覆盖写入，套装和蓄力效果通过比例查询并入对应乘区，具体公式以机制总表为准。

### 4.3 角色技能

```text
CharacterData 主动/被动资源数组
		-> SelectedCharacterRuntimeComponent 注入玩家技能组件
		-> GameWorld / LobbyWorld 组合场景
        -> InputMap C/V/B 或被动初始化
        -> 通用瞄准、锁定、蓄力与冷却状态
        -> 独立行为节点 -> 属性 / 目标 / 地图公开接口
        -> SkillTargetingVisual / SkillChargeBar / ActiveSkillBar
```

主动行为只有明确成功后才扣能量并进入对应槽冷却。被动行为使用稳定来源 ID 写入长期状态，并必须在角色切换时精确清理；完整协议见 `docs/skill_system.md`。

### 4.4 物品所有权

```text
ContentCatalog 模板
        -> 商店 / 怪物 / 宝箱生成独立实例
        -> 地面掉落 -> GlobalInventory 背包
        -> 装备栏 / 物资撤离 / 战斗结算
        -> 背包或仓库
```

`GlobalInventory` 是物品所有权的唯一来源。UI 查询结果只附加来源下标，不调整真实数组顺序。所有移动、购买、出售、装备、修复和锻造操作都必须由服务进行原子校验后再通知界面刷新。

### 4.5 场景与输入

`InputBindings` 直接更新 Godot `InputMap`，技能一、二、三、角色展示与移动、武器和其他界面操作共用同一改键与持久化流程。大厅交互复用 `pickup_nearby` 动作并由 `LobbyInteractionComponent` 转为设施 action ID；玩家显式解除绑定后不得回退到默认物理键，只有动作缺失或尚未初始化时才允许组件兜底。任意界面关闭战斗输入后，移动意图、攻击、技能、冲刺与切枪同时失效。默认操作及玩家可见规则以机制总表为准。

### 4.6 模式扩展

```text
HackModeRules + ModeExtensionRules + HackProtocolRules
        -> ModeExtensionSelectPanel（单人或房主编辑）
        -> SessionState / NetworkSession（只保存稳定 ID）
        -> GameWorld 获取效果字典并按需创建 HackProtocolComponent
        -> 人口 / BasicMonster / PlayerController / EquipmentComponent
        -> GlobalInventory / CombatHud / 怪物掉落 / NetworkCombatSync
```

规则层只返回数据，不持有 UI、场景树或存档。`GameWorld` 是整局配置的协调边界，但具体状态仍由最近的数据所有者维护：怪物属性由 `BasicMonster` 应用，虚拟人口由 `MonsterSimulationManager` 补齐，耐久由玩家与装备组件结算，容量由 `GlobalInventory` 原子校验，小地图由 `CombatHud` 显隐。新扩展必须保持中性默认值，使无配置、训练场和旧调用路径无需增加分支。

局内查看链路不经过效果字典：`CombatHud` 打开暂停左栏时，风险合约从 `SessionState` 读取稳定 ID，骇入协议从本机 `HackProtocolComponent` 读取稳定 ID；两个面板分别通过对应规则表构建只读文本。这样显示层与实际效果共享同一规则来源，同时不会获得修改本局配置的权限。

## 5. 存档边界

- 每个服务只写入自己拥有的文件；跨服务交易先完成业务校验，再分别持久化相关资产。
- `SessionState` 把已解锁角色稳定 ID 与最后确认的 `selected_character_id` 写入 `user://character_unlocks.json`；角色档案中的 `unlocked_by_default` 每次启动都会加入当前默认解锁集合，无效或已锁定的角色选择回退为星。
- 资源实例同时保存稳定 ID、资源路径和运行时字段，用于恢复当前版本创建的独立物品实例。
- 存档版本常量只标识当前写入结构。项目尚未发布正式版本，库存补发、强化公式转换、商店重建、股市进度缩放、旧堆叠拆分、图鉴补账和项目目录复制等迁移入口均已停用。
- `SaveLocationMigration` 脚本保留为历史实现参考，但未在 `project.godot` 注册且脚本内迁移调用已注释；启动时不会实例化该服务，也不会读取或复制同级旧项目目录文件。
- 普通高频变化可合并写入；货币兑换、股票成交等跨资产操作应立即保存，缩短文件间状态不一致窗口。
- 零装骇入封存：`GlobalInventory` 在零装局开局时把真实背包与装备序列化为存档内 `bare_run_stash` 字段并立即落盘，结算收尾恢复后清除该字段；读档发现残留封存快照即视为零装局异常中断，恢复真实资产并放弃局内临时所得。该字段只在零装局进行中的存档内出现，不改变其他模块存档结构。
- 测试不得直接覆盖日常 `user://` 数据，具体隔离要求见 `docs/功能验证测试规范.md`。
- 存档导出使用默认名 `Star_Hacker_save_<本地时间>.lisbamsave`，保存 `character_unlocks.json`、`input_bindings.cfg`、`ui_style_settings.cfg`、`banner_notification_settings.cfg`、`debug_settings.cfg`、`global_inventory.json`、`shop_state.json`、`stock_market_state.json`、`mining_farm_state.json`、`hideout_state.json`、`insurance_state.json`、`bank_state.json`、`dispatch_state.json`、`stats_state.json` 与 `bounty_state.json` 的原始字节；尚未生成的文件不写入归档。根元数据同时保存项目中文名与英文名，只用于人工识别，不参与兼容校验。
- 存档导入只接受格式版本 1 与固定文件白名单。服务先完成 JSON、文件名和 Base64 内容校验，再写入同目录临时文件，完整备份当前存档后替换正式文件；归档中缺失的模块文件会按快照语义移除，成功后重启游戏统一加载。
- 存档删除使用与导出、导入相同的十五个文件白名单。服务先写入 `save_delete_pending_v1.marker`，再把全部现有活动存档改名到同目录 `.temp_delete` 路径；任一暂存失败时统一回滚，全部暂存成功后永久移除并立即重启。保护标记保留到下一次启动，`SaveArchiveService` 作为首个 AutoLoad 会在任何业务服务读档前再次删除活动文件、`.temp_import` 与 `.temp_delete` 残留，完成后移除标记，因此退出阶段的旧状态回写也不能恢复被删除存档。
- 存档删除只清理当前项目用户目录中的活动白名单文件和内部临时文件，不删除玩家自行导出的 `.lisbamsave`，也不删除历史导入备份目录；这些外部或备份快照只有玩家主动导入时才会重新成为活动存档。
- 战斗暂停设置导出只包含已经落盘的数据，不强制保存正式战斗中的临时背包、装备与耐久变化，继续遵守本局成功、失败或正常退出结算后统一持久化的所有权规则。
- 战斗暂停设置删除会丢弃当前活动存档及尚未落盘的本局内存变化，不执行战斗结算；重启后全部服务按首次启动默认值初始化。

## 6. 参数管理

- 玩家可调或需要场景差异的参数使用脚本顶部 `@export`，并在检查器中配置。
- 跨实例不应变化的公式常量保留在负责该规则的脚本中。
- 内容基础数值写入对应 `.tres`，不要在商店、UI、掉落和角色分支中重复硬编码。
- 同一数值出现脚本默认值、场景覆盖值和资源值时，以最接近运行实例的覆盖层为准，并同步机制总表。
- 查找可调字段时直接查看目标脚本顶部的导出分组；框架文档不复制全项目变量名清单。

## 7. 扩展协议

### 7.1 伤害与弹体

- 可受伤对象实现 `apply_damage(damage: float, source: Node)`；需要击退时从来源读取冲击力理论位移和方向，再由受击目标按自身韧性与击退衰减换算外部初速度。
- 可被近战清除的敌方弹体实现 `destroy_by_melee(source: Node)`，并使用 `EnemyProjectile` 物理层。
- 新远程或近战武器优先复用现有攻击组件，只替换数据、弹体、枪口和必要参数。
- 玩家与敌方弹体使用平方距离判断最大航程，并复用实例内射线排除表；穿透目标的 RID 只在实际穿透后追加，不能在每个物理帧创建新的排除数组。

### 7.2 背包与物品

- 新筛选、排序或关键词规则进入 `InventoryQuery`，不得由每个面板单独实现。
- 新物品展示字段进入 `ItemDetailFormatter`；标准卡片结构进入 `ItemCardView`。
- 主菜单与战斗背包的共同交互进入 `SharedBackpackPanel`。仅场景特有的所有权结果由宿主通过信号处理。
- 正式战斗中的普通拾取、丢弃、装备与耐久变化先写入 `GlobalInventory` 内存状态，不为每次操作重复序列化包含仓库的完整存档；成功撤离、失败或正常退出结算后统一落盘。物资撤离点已经送回仓库的资产使用强制保存路径，不等待本局最终结算。
- 正式战斗失败结算由 `GlobalInventory` 按所有权位置统一执行：背包堆叠按物品单位独立抽取，武器栏与四个防具装备槽按每件物品独立抽取；实际遗失条目统一进入结算列表、灰市快照和最终存档，HUD 只负责根据死亡或提前逃跑传入两类保留率。
- `GlobalInventory` 对背包执行 50 组原子容量预检，并把所有正式可堆叠资源限制为每组 10 件；武器和装备始终单件成组。读档数量直接限制到现行 10 件上限，不执行历史大堆叠拆分或溢出转仓库。
- `user://global_inventory.json` 只能由 `/root/GlobalInventory` AutoLoad 写入；独立测试实例、临时验证脚本和普通场景节点没有持久化权限。库存服务只维护这一份主存档，不自动生成额外恢复或备份文件。当前存档显式保存物品与怪物的稳定图鉴发现键、强化累计、强化次数、二手状态和耐久字段；读档只恢复这些现行字段，不根据持有物品补建图鉴，也不清理或转换历史强化石数据。

### 7.3 敌人与环境

- 新敌人优先继承 `BasicMonster` 并遵守目标、死亡和模拟启停协议，且必须填写唯一 `monster_id` 与图鉴说明。生命归零时必须立即停止玩法逻辑并派发一次死亡信号；允许保留不可交互模型播放冲击和淡出，默认持续 0.52 秒后回收。尸体继续消耗击杀一击已写入的外部速度并保留环境墙体阻挡，但不再处于可受击战斗层。
- 新实心障碍必须同时满足碰撞层、`environment_obstacles` 分组和导航障碍缓存要求。
- 动态障碍发生变化后必须使导航与地图缓存失效，避免视觉、碰撞和寻路状态分离。

### 7.4 角色扩展包与装备套装

- 新角色默认保持锁定；永久解锁统一调用 `SessionState.unlock_character()`，内容消费者只查询 `ContentCatalog` 的已过滤清单，不直接读取解锁存档。
- 一个角色对应一个 `ContentPackData` 清单。基础内容不写入清单并始终可用；专属内容必须同时位于标准扫描目录并被扩展包清单引用。
- 套装装备共享一份 `EquipmentSetData`。`EquipmentSetComponent` 只读取装备快照并返回结果，`EquipmentComponent` 负责把套装属性并入战斗属性，`GameWorld` 只消费宝箱额外数量接口。
- 局外角色属性与 `ItemDetailFormatter` 复用套装组件的纯统计接口。损坏装备既不提供普通属性，也不计入套装门槛，保证 UI 颜色、角色面板与战斗结果一致。
- 战斗中的套装特殊效果使用装备变化驱动的状态缓存：换装、受击导致防具损坏、强化或修复已装备物品后统一重建，普通移动帧不重复读取四个装备槽或创建套装统计字典。附近掉落物效果只缓存已达到门槛的套装；缓存为空时不扫描 `item_drops`，检测时复用半径平方并用点积符号判断朝向。
- `GlobalInventory` 修复已装备物品后必须派发 `equipment_changed`，使普通装备属性、套装门槛、战斗 HUD 与运行时缓存在同一变化链路内立即刷新；修复仓库或背包物品不触发无关装备重算。

### 7.5 依赖约束

- 组件通过明确接口和信号通信，不直接访问无关面板或服务内部字段。
- 聚合脚本可通过 `NodePath` 获取可替换组件；动态返回值应显式标注局部变量类型。
- 新增变量必须遵守项目注释规范；不得改名或删除已有变量与注释来完成无关整理。
- 新增持久化服务或存档文件时，必须同步更新 `SaveArchiveService.SAVE_FILE_NAMES` 白名单与本文存档清单，否则该模块不会进入导出和导入快照。

### 7.6 角色技能

- 一个角色可以同时配置任意数量被动；当前主动输入只装载资源数组前三项，空槽保持可见但不响应释放。
- 通用索敌目标通过节点组和公开接口声明，技能行为不得按怪物名称、角色 ID 或固定场景路径扫描目标。
- 方向、位置、锁定与无索敌的输入阶段进入 `ActiveSkillComponent`；具体伤害、移动、增益或地图效果进入独立行为节点。
- 技能攻防倍率通过 `CombatStatsComponent` 的稳定来源接口写入；同来源覆盖、不同来源连乘，角色面板把技能、装备、套装和临时效果统一合并为基础值之外的“额外值”。
- 地图情报技能通过 `GameWorld` 的技能标记字典写入，不占用玩家唯一导航点。

### 7.7 护盾、友方与衍生单位

- 任意战斗单位可挂载 `ShieldComponent`。伤害入口先调用 `absorb_damage()`，只把返回的溢出伤害交给生命系统；护盾归零不触发死亡，生命归零仍是唯一死亡条件。
- 玩家预制体固定挂载护盾组件；`BasicMonster` 会为敌人及其派生单位动态补齐同一组件，因此旧场景无需复制承伤逻辑。
- 友方单位继承 `BasicMonster` 的感知、寻路、攻击、承伤和死亡流程，`FriendlyUnit` 负责敌对目标组、玩家目标注入拒绝、攻击前阵营复核、玩家跟随、可移动开关和远距回传。
- `CharacterData.derived_units` 保存角色技能衍生单位的只读资料。角色展示按需显示“衍生单位”，运行时实例仍由具体召唤技能创建和清理。

### 7.8 模式扩展

- 新模式扩展先登记稳定扩展 ID 与兼容条件；扩展专属词条必须登记稳定词条 ID、显示名、类别、效果字段与奖励，不得由选择面板反向成为规则来源。
- 单人、联机、晚加入补发和最终开局必须共同经过 `ModeExtensionRules.sanitize_configuration()`，未知 ID、空风险合约、同类多档和超额词条不能进入战斗。
- 效果字典的每个键必须定义中性值。消费组件只读取自身负责的键，并提供公开设置接口；不得让一个全能脚本长期维护所有效果细节。
- 模式扩展只保存运行期稳定 ID，不进入永久存档。需要永久进度的未来扩展必须另建明确的数据所有者，不能直接扩大 `SessionState` 职责。
- 骇入协议的碎片、候选、协议层与条件状态全部归 `HackProtocolComponent`；多人只同步协议 ID 快照，不能同步或共享碎片和候选。团队代价必须按有效成员平均层数计算。
- 完整随机规则、乘算顺序、掉落边界与验证清单见 `docs/mode_extensions.md`。
