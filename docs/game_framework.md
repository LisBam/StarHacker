# 游戏基础框架

本文档说明《崩坏：量子骇袭》的运行入口、系统分层、数据流、持久化边界和扩展协议。玩家规则与数值以 `docs/游戏机制与玩法内容.md` 为准；内容创建、敌人 AI、股市、矿场和 UI 分别由对应模块文档维护。

## 1. 运行入口

| 入口 | 实现 | 职责 |
| --- | --- | --- |
| 主菜单 | `res://scenes/ui/main_menu.tscn`、`res://scripts/ui/main_menu.gd` | 项目主场景；打开角色、背包、仓库、商店、锻造、股市、矿场及模式入口 |
| 角色选择 | `res://scenes/ui/character_select.tscn`、`res://scripts/ui/character_select.gd` | 展示自动发现的角色档案；确认后只更新当前角色并返回主菜单 |
| 战斗世界 | `res://scenes/game/game_world.tscn`、`res://scripts/game/game_world.gd` | 承载玩家、地图、环境、敌人人口、宝箱、掉落与撤离流程 |
| 玩家预制体 | `res://scenes/characters/player.tscn`、`res://scripts/player/player_controller.gd` | 组合输入、移动、战斗属性、装备和攻击组件 |

主菜单进入正式骇入或训练场前，只把模式写入 `SessionState`。已确认角色由同一服务跨场景保存。所有主场景切换统一经 `SceneTransition` 执行，业务 UI 不直接维护过渡动画。

## 2. AutoLoad 服务

`project.godot` 是 AutoLoad 注册的唯一清单。

| 服务 | 核心职责 | 持久化 |
| --- | --- | --- |
| `ContentCatalog` | 启动时扫描角色、武器、装备、道具、怪物和扩展包清单，按角色解锁状态过滤内容池 | 无 |
| `SessionState` | 保存当前游戏模式、已确认角色与永久角色/扩展包解锁状态 | `user://character_unlocks.json`；模式和当前选择仅运行期 |
| `InputBindings` | 管理默认与自定义输入映射 | `user://input_bindings.cfg` |
| `DebugSettings` | 管理开发者调试选项 | `user://debug_settings.cfg` |
| `GlobalInventory` | 拥有金币、仓库、随身背包、装备槽、持仓和战斗结算数据 | `user://global_inventory.json` |
| `ShopService` | 生成普通商店与灰市库存，维护刷新状态 | `user://shop_state.json` |
| `StockMarketService` | 维护行情、事件、证券币和对局行为影响 | `user://stock_market_state.json` |
| `MiningFarmService` | 维护算力币、矿场资产、在线收益和临时增益 | `user://mining_farm_state.json` |
| `SceneTransition` | 统一场景切换和黑屏过渡 | 无 |

服务是数据所有者，面板只读取快照、发出命令并响应信号。新增跨场景状态时先确认归属，不得在多个 UI 脚本中各保存一份可变副本。

## 3. 分层与职责

### 3.1 数据层

- `CharacterData`、`ActiveSkillData`、`PassiveSkillData`、`WeaponData`、`EquipmentData` 和 `RepairKitData` 描述可保存、可复制的角色、技能与物品配置；技能详细协议见 `docs/skill_system.md`。
- `ContentPackData` 只声明一个角色扩展包拥有的武器、装备、道具与怪物路径；`EquipmentSetData` 只声明共享套装门槛、显示原文、属性加成与特殊效果参数。
- `EnhancementStoneData` 保存强化石品质、目标类型和词条方向；强化幅度与兼容规则集中在 `EnhancementRules`。
- `.tres` 保存单个内容的基础数值。脚本默认值只作为缺省值，场景或资源覆盖值优先。
- 新内容通过 `ContentCatalog` 自动注册，创建流程见 `docs/content_authoring.md`。

### 3.2 组件层

| 组件 | 单一职责 |
| --- | --- |
| `PlayerInputComponent` | 把 InputMap 转换为移动、瞄准、攻击、疾跑和闪避意图 |
| `ActiveSkillComponent` | 管理三个主动技能槽的按下、瞄准、锁定、蓄力、松手释放、能量与冷却 |
| `PassiveSkillComponent` | 按角色资源同时创建多个被动行为，并在角色切换时清理各自长期状态 |
| `SkillTargetingVisual` | 绘制方向、位置和锁定目标范围，不参与目标合法性或命中结算 |
| `SkillChargeBar` | 显示角色头顶蓄力比例，不拥有蓄力时间 |
| `TopDownMovementComponent` | 合成输入速度与外部击退并执行角色物理移动 |
| `CombatStatsComponent` | 维护生命、能量、攻防、恢复和死亡状态 |
| `RangedAttackComponent` | 校验攻击条件、为普通或散射攻击构造弹体偏移并处理连击与弹体生成 |
| `MeleeAttackComponent` | 管理近战命中框、命中去重、冲击和敌方弹体清除 |
| `EquipmentComponent` | 代理装备槽并聚合有效战斗属性 |
| `EquipmentSetComponent` | 按套装稳定 ID 统计未损坏穿戴件、汇总档位属性并结算世界特殊效果 |
| `InventoryComponent` | 代理随身背包操作；全局服务缺失时才使用本地回退 |
| `DamageReceiverComponent` | 统一可受伤目标的伤害接收入口 |
| `CombatDamageCalculator` | 统一伤害、攻防和暴击计算 |

`PlayerController` 是组合根，只协调组件、朝向和战斗反馈，不拥有库存、输入解析或攻击公式。新增角色优先替换数据和子组件，避免扩张聚合脚本。

角色技能同样不进入 `PlayerController`。`GameWorld` 只负责把当前 `CharacterData` 的主动与被动资源数组注入技能组件；行为实例通过明确接口访问属性、目标和地图标记。

### 3.3 世界与敌人层

- `GameWorld` 负责地图边界、环境生成、探索记录、撤离点、宝箱、掉落池、虚拟人口目标和共享导航缓存。
- `MonsterSimulationManager` 只负责虚拟敌人记录与真实节点之间的分批物化和休眠。
- `BasicMonster` 组合感知、战术和移动组件；`RangedMonster` 只增加安全距离与射击行为。
- `WeaponDrop` 是统一地面物品载体，可承载武器、装备、强化石和道具的独立资源副本。

敌人状态机与加载协议见 `docs/enemy_ai.md`，掉落概率、人口曲线和撤离数值见机制总表。

### 3.4 UI 层

- `CombatHud` 负责局内信息、暂停、地图、拾取提示、物资撤离和结算编排，不直接拥有库存数据。
- `SharedBackpackPanel` 同时服务主菜单和战斗 HUD；上下文只决定丢弃等少量业务差异。
- `InventoryQuery` 为仓库、背包、商店、锻造与结算提供无副作用的分类、筛选、搜索和排序结果。
- `ItemCardView`、`WeaponDurabilityBar` 和 `ItemDetailFormatter` 统一物品展示，宿主只提供操作协议。
- `CommonConfirmationDialog`、`SellQuantityDialog`、`SecuritiesTransferDialog`、`EnhancementResultDialog` 和 `ItemActionPopup` 分别承载明确的弹窗交互。
- `UiStyleGuide`、`DialogOuterFrame` 和 `ProgressSliderVisual` 统一窗口、弹窗和滑条视觉，规则见 `docs/ui_style.md`。

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
         -> RangedAttackComponent / MeleeAttackComponent
         -> 弹体或命中框 -> DamageReceiverComponent
         -> CombatDamageCalculator -> 生命、击退与反馈
```

一次攻击的能量、耐久、冷却和坐力由攻击流程统一结算。弹体数量或连击轮数不得重复扣除单次成本。

### 4.3 角色技能

```text
CharacterData 主动/被动资源数组
        -> GameWorld 注入玩家技能组件
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
        -> 地面掉落 -> GlobalInventory 随身背包
        -> 装备栏 / 物资撤离 / 战斗结算
        -> 随身背包或永久仓库
```

`GlobalInventory` 是物品所有权的唯一来源。UI 查询结果只附加来源下标，不调整真实数组顺序。所有移动、购买、出售、装备、修复和锻造操作都必须由服务进行原子校验后再通知界面刷新。

### 4.5 场景与输入

`InputBindings` 直接更新 Godot `InputMap`，技能一、二、三与移动、武器和界面操作共用同一改键与持久化流程。玩家显式解除绑定后不得回退到默认物理键；只有动作缺失或尚未初始化时才允许组件兜底。默认操作及玩家可见规则以机制总表为准。

## 5. 存档边界

- 每个服务只写入自己拥有的文件；跨服务交易先完成业务校验，再分别持久化相关资产。
- `SessionState` 只把已解锁角色稳定 ID 写入 `user://character_unlocks.json`；角色档案中的 `unlocked_by_default` 每次启动都会补入，旧存档不能回锁默认角色。
- 资源实例同时保存稳定 ID、资源路径和运行时字段，以支持内容重命名与旧记录恢复。
- 存档版本常量与迁移代码位于对应服务脚本。文档只保留仍会被读取的迁移规则，不维护已经失效的历史流水账。
- 普通高频变化可合并写入；货币兑换、股票成交等跨资产操作应立即保存，缩短文件间状态不一致窗口。
- 测试不得直接覆盖日常 `user://` 数据，具体隔离要求见 `docs/功能验证测试规范.md`。

## 6. 参数管理

- 玩家可调或需要场景差异的参数使用脚本顶部 `@export`，并在检查器中配置。
- 跨实例不应变化的公式常量保留在负责该规则的脚本中。
- 内容基础数值写入对应 `.tres`，不要在商店、UI、掉落和角色分支中重复硬编码。
- 同一数值出现脚本默认值、场景覆盖值和资源值时，以最接近运行实例的覆盖层为准，并同步机制总表。
- 查找可调字段时直接查看目标脚本顶部的导出分组；框架文档不复制全项目变量名清单。

## 7. 扩展协议

### 7.1 伤害与弹体

- 可受伤对象实现 `apply_damage(damage: float, source: Node)`；需要击退时从来源读取冲击力和方向。
- 可被近战清除的敌方弹体实现 `destroy_by_melee(source: Node)`，并使用 `EnemyProjectile` 物理层。
- 新远程或近战武器优先复用现有攻击组件，只替换数据、弹体、枪口和必要参数。

### 7.2 背包与物品

- 新筛选、排序或关键词规则进入 `InventoryQuery`，不得由每个面板单独实现。
- 新物品展示字段进入 `ItemDetailFormatter`；标准卡片结构进入 `ItemCardView`。
- 主菜单与战斗背包的共同交互进入 `SharedBackpackPanel`。仅场景特有的所有权结果由宿主通过信号处理。

### 7.3 敌人与环境

- 新敌人优先继承 `BasicMonster` 并遵守目标、死亡和模拟启停协议。
- 新实心障碍必须同时满足碰撞层、`environment_obstacles` 分组和导航障碍缓存要求。
- 动态障碍发生变化后必须使导航与地图缓存失效，避免视觉、碰撞和寻路状态分离。

### 7.4 角色扩展包与装备套装

- 新角色默认保持锁定；永久解锁统一调用 `SessionState.unlock_character()`，内容消费者只查询 `ContentCatalog` 的已过滤清单，不直接读取解锁存档。
- 一个角色对应一个 `ContentPackData` 清单。基础内容不写入清单并始终可用；专属内容必须同时位于标准扫描目录并被扩展包清单引用。
- 套装装备共享一份 `EquipmentSetData`。`EquipmentSetComponent` 只读取装备快照并返回结果，`EquipmentComponent` 负责把套装属性并入战斗属性，`GameWorld` 只消费宝箱额外数量接口。
- 局外角色属性与 `ItemDetailFormatter` 复用套装组件的纯统计接口。损坏装备既不提供普通属性，也不计入套装门槛，保证 UI 颜色、角色面板与战斗结果一致。

### 7.5 依赖约束

- 组件通过明确接口和信号通信，不直接访问无关面板或服务内部字段。
- 聚合脚本可通过 `NodePath` 获取可替换组件；动态返回值应显式标注局部变量类型。
- 新增变量必须遵守项目注释规范；不得改名或删除已有变量与注释来完成无关整理。

### 7.6 角色技能

- 一个角色可以同时配置任意数量被动；当前主动输入只装载资源数组前三项，空槽保持可见但不响应释放。
- 通用索敌目标通过节点组和公开接口声明，技能行为不得按怪物名称、角色 ID 或固定场景路径扫描目标。
- 方向、位置、锁定与无索敌的输入阶段进入 `ActiveSkillComponent`；具体伤害、移动、增益或地图效果进入独立行为节点。
- 技能攻防倍率通过 `CombatStatsComponent` 的稳定来源接口写入；同来源覆盖、不同来源连乘，角色面板单独显示技能值。
- 地图情报技能通过 `GameWorld` 的技能标记字典写入，不占用玩家唯一导航点。
