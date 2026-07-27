# 每日悬赏系统

本文档是悬赏模块的唯一架构维护入口，说明服务职责、进度事件流、奖励发放与持久化边界。玩家可见规则与全部数值同步维护在 `docs/游戏机制与玩法内容.md` 第 27 章；界面规格见 `docs/ui_style.md`。

## 1. 模块组成

| 模块 | 实现 | 职责 |
| --- | --- | --- |
| 悬赏服务 | `scripts/game/bounty_service.gd`（AutoLoad `BountyService`） | 每日按本地日期刷新随机悬赏、订阅统计服务事实信号推进进度、完成后自动发奖并广播完成信号、独立持久化 |
| 悬赏面板 | `scripts/ui/bounty_panel.gd`（`BountyPanel`） | 840×560 居中窗口；四周使用左右 18、上下 16 像素内容页边距，按服务快照展示悬赏卡（标题、说明、进度条、奖励与完成状态），只读不推进 |
| 横幅播报 | `BannerNotificationService` 订阅 `bounty_completed` | 完成时播出“【悬赏完成】标题：奖励结果”全局横幅；悬赏服务不反向依赖横幅 |

悬赏入口在玩家个人首次完成一次正式成功撤离后永久开放；此前主菜单按钮为纯黑禁用状态并提示“首次成功撤离后解锁”，大厅 `bounty` 动作不能绕过该资格。锁定期间每日悬赏可以按日期预生成，但击杀、开箱、送回和结算事实事件均不推进进度、不发放奖励；首次成功撤离本身也不计入悬赏，完成后的下一局才开始累计。

## 2. 数据流

```text
战斗与库存挂点（击杀 / 开箱 / 送回 / 结算）
        -> StatsService 事实信号（monster_kill_recorded / chest_open_recorded / run_shipped_value_changed / run_finished）
        -> BountyService 匹配悬赏类型并推进进度
        -> 达标后 _try_complete_bounty：GlobalInventory 入账（grant_coins / add_storage_resource）
        -> bounty_completed 信号 -> 横幅播报 / bounties_changed -> 面板刷新
```

- 悬赏服务不直接接触战斗节点；统计挂点已经按“产出结算的战斗模式”过滤，训练场与超频骇入天然不推进悬赏；四类事实事件回调还会读取 `NewcomerProtectionService.has_completed_first_successful_extraction()`，在首次成功撤离前统一提前返回。
- 击杀目标从 `ContentCatalog.get_enemy_scene_paths()`（已按角色解锁过滤）随机抽取，离树实例化只读取 `monster_id` 与 `display_name`，标题与说明在刷新时固化。
- 稀有强化石奖励复用 `EnhancementStoneData.create_random` 与宝箱高品质保底流程（最多 12 次重试后强制提升高级），入库走 `GlobalInventory.add_storage_resource` 公共接口并回写 `StatsService` 获得计数。
- 星穹报酬与强化石发放失败补偿统一走 `GlobalInventory.grant_coins()`，因此会增加金融系统使用的生涯累计获得星穹；强化石直接入库本身不增加该累计值。

## 3. 持久化边界

- 存档文件为 `user://bounty_state.json`，仅保存日期键与悬赏数组（类型、标题、说明、目标、进度、奖励与完成状态）；服务只在注册为 AutoLoad 的唯一实例上写盘。
- 已列入 `SaveArchiveService.SAVE_FILE_NAMES` 白名单，随导出、导入与删除存档统一处理。
- 每日刷新以本地日期字符串为键；跨零点在线由 60 秒计时器兜底触发，刷新即作废未完成悬赏，不做跨日结转。

## 4. 扩展协议

- 新增悬赏类型时在 `bounty_service.gd` 顶部补充类型常量与数值常量，在 `_build_bounty` 增加构建分支，并按需订阅 `StatsService` 的新事实信号；面板按快照字段渲染，无需修改。
- 悬赏奖励数值调整必须按机制总表第 25 章口径复核“每日悬赏总额 ≈ 一局收益上浮”的定位，并回写第 27 章数值表。
