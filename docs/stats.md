# 生涯统计系统

本文档是统计模块的唯一架构维护入口，说明服务职责、事实事件挂点、消费方与持久化边界。玩家可见口径与展示内容同步维护在 `docs/游戏机制与玩法内容.md` 第 28 章；界面规格见 `docs/ui_style.md`。

## 1. 模块组成

| 模块 | 实现 | 职责 |
| --- | --- | --- |
| 统计服务 | `scripts/game/stats_service.gd`（AutoLoad `StatsService`） | 集中记录怪物击杀计数、物品获得计数、对局与撤离统计、单局之最与财富曲线采样；对外提供只读查询与事实信号，独立持久化 |
| 统计分类入口 | `scenes/ui/main_menu.tscn`、`scripts/ui/main_menu.gd` | 底部“统计 ▲”展开后显示“图鉴、生涯”；展开时箭头翻为“▼”，再次点击、按 ESC 或打开子入口后收起 |
| 生涯面板 | `scripts/ui/stats_panel.gd`（`StatsPanel`） | 由统计分类中的“生涯”按钮打开；使用 880×600 居中窗口展示对局统计、单局之最与财富曲线，折线由内部类 `WealthCurveChart` 绘制 |
| 图鉴计数 | `EncyclopediaPanel` 读取 `get_monster_kill_count` / `get_item_acquire_count` / `get_enhancement_stone_acquire_count` | 由统计分类中的“图鉴”按钮打开；条目名称行右缘数字与详情首行统计行只读展示 |
| 悬赏进度 | `BountyService` 订阅统计事实信号 | 见 `docs/bounty.md` |

## 2. 事实事件挂点

统计服务自身不接触战斗节点；以下挂点在事实发生处上报，全部带 `has_method` 防御，服务缺失时业务照常运行。

| 事件 | 挂点 | 口径守卫 |
| --- | --- | --- |
| 对局开始 `record_run_started` | `GameWorld._begin_global_inventory_run` | 训练场与超频骇入在挂点前提前返回，天然不计 |
| 击杀 `record_monster_killed` | 单机：`GameWorld._on_monster_died`（联机时跳过）；联机主机：`NetworkCombatSync._on_host_monster_died`（伤害归属为 0 即主机击杀）；联机客户端：`NetworkCombatSync._remove_puppet_enemy`（`kp` 等于本机） | “本机确认击杀”口径；联机侧另经 `SessionState.is_item_settlement_disabled()` 排除超频局 |
| 开箱 `record_chest_opened` | `LootChest._release_loot`（携带品质标识） | 经 `SessionState.is_item_settlement_disabled()` 排除训练场与超频；联机只有实际出货的认领端执行 |
| 送回 `record_shipped_value` | `GlobalInventory.ship_combat_resource_to_warehouse` | 仅正式对局可达该路径 |
| 物品获得 `record_item_acquired` | `GlobalInventory._track_combat_acquisition`（战场首次获得）、`GlobalInventory.purchase_resource_to_warehouse`（商店与灰市购买）、`BountyService` 强化石奖励 | 读档恢复、容器转移与送回不经过这些入口，不会重复计数 |
| 对局结束 `record_run_finished` | `CombatHud._record_stats_run_finished`（成功撤离 / 死亡 / 逃跑，须在库存正式结算前调用） | 娱乐模式结算入口已提前返回主菜单 |

- 物品统计键与图鉴发现键同构（`item_kind:稳定ID`，强化石统一 `enhancement_stone:any`），两套口径可互相对照。
- 财富采样在服务启动与每局结束时各执行一次，口径复用 `BankService.get_asset_breakdown().total`（银行缺失时回退局外星穹），上限 240 个点先进先出。

## 3. 持久化边界

- 存档文件为 `user://stats_state.json`；仅保存稳定计数、纪录与采样数组，服务只在注册为 AutoLoad 的唯一实例上写盘，同帧多次事件合并为一次落盘。
- 已列入 `SaveArchiveService.SAVE_FILE_NAMES` 白名单，随导出、导入与删除存档统一处理。

## 4. 扩展协议

- 新增统计维度时优先在本服务补充计数字段、快照字段与（按需）事实信号；面板与图鉴只消费快照或查询，不得各自维护第二份计数。
- 新增挂点必须自带模式口径守卫（训练场与超频骇入不计），并在本文件的挂点表中登记。
