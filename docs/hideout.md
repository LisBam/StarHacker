# 据点设施建设

本文档说明据点建设系统的服务职责、设施数值、加成挂钩与持久化边界。玩家可见数值以《游戏机制与玩法内容》为准；本文维护实现结构与跨模块协作规则。

## 1. 系统定位

- 据点入口在玩家个人首次完成一次正式成功撤离后永久开放；此前主菜单按钮为纯黑禁用状态并提示“首次成功撤离后解锁”，大厅 `hideout` 动作执行相同资格校验。
- 据点建设是局外常驻的长线成长玩法：消耗局外星穹升级七座设施，每座设施为一个既有局外模块或随身背包提供永久被动加成。
- 升级采用“扣款 + 在线建造倒计时”模式，与矿场算力合同同族：同一时间最多一个建造队列，倒计时只消耗在线时间，离线不推进。
- 建成后等级永久生效，没有降级、拆除或返还入口。

## 2. 服务与职责

| 部分 | 实现 | 职责 |
| --- | --- | --- |
| 据点服务 | `res://scripts/game/hideout_service.gd`（AutoLoad `HideoutService`） | 维护设施等级、建造队列、在线倒计时、独立存档与七个只读加成接口 |
| 据点面板 | `res://scripts/ui/hideout_panel.gd` | 展示设施卡片、建造倒计时与升级二次确认；复用 `CommonConfirmationDialog` |
| 主菜单入口 | `main_menu.gd` 底部“据点”按钮与大厅 `hideout` 动作 | 动态创建遮罩与面板，复用局外面板打开/关闭协议 |

服务是数据唯一所有者；面板只读取快照、发出升级请求并响应 `facility_levels_changed`、`construction_changed` 信号。

## 3. 设施与数值

| 设施 | 稳定 ID | 关联模块 | 每级效果 | 满级累计 |
| --- | --- | --- | --- | --- |
| 补给中转站 | `supply_hub` | 商店 | 购买实付 -1% | -5% |
| 精工车间 | `forge_workshop` | 锻造 | 锻造费用 -2% | -10% |
| 散热机房 | `cooling_plant` | 矿场 | 离线收益上限 +3600 秒 | +5 小时 |
| 精算办公室 | `actuarial_office` | 保险 | 保费费率 -0.5 个百分点 | -2.5 个百分点 |
| 星海金库 | `vault` | 银行 | 定期利率相对 +4% | ×1.20 |
| 佣兵联络站 | `mercenary_office` | 派遣 | 委托报酬 +4% | +20% |
| 战术仓储舱 | `tactical_storage` | 背包 | 背包上限 +5 组 | +25 组（25→50 组） |

- 全部设施 0 至 5 级；升级费用为“基础造价 200 星穹 × [1, 3, 9, 27, 81]”，即 200 / 600 / 1800 / 5400 / 16200，单设施满级累计 24200 星穹。
- 建造在线时长依次为 300 / 900 / 1800 / 3600 / 7200 秒（5 分钟到 2 小时）。
- 开始建造立即扣款且不可撤销；建成瞬间等级 +1 并广播 `construction_completed`，横幅通知服务据此播放“【据点建成】”横幅。

## 4. 加成挂钩协议

- 效果消费方通过 `get_node_or_null("HideoutService")` 加 `has_method` 防御式查询，据点服务缺失时一律按无加成运行：
  - `ShopService._purchase_entry_from_array()` 调用 `get_shop_discount_ratio()`，实付 = `ceil(挂牌价 × (1 - 折扣))` 且最低 1 星穹；挂牌价展示不变。
  - `ForgeService` 费用公式调用 `get_forge_discount_ratio()`；锻造服务继承 `RefCounted`，必须经 `Engine.get_main_loop()` 访问根节点。预览与执行共用公式，扣款始终一致。
  - `MiningFarmService._settle_offline_income()` 调用 `get_mining_offline_bonus_seconds()` 提升离线补发上限。
  - `InsuranceService.get_premium_rate()` 调用 `get_insurance_rate_reduction()`。
  - `BankService` 只在签订存单瞬间调用 `get_bank_fixed_rate_multiplier()` 锁定利率。
  - `DispatchService` 只在签订委托瞬间调用 `get_dispatch_reward_bonus_ratio()` 锁定报酬。
  - `GlobalInventory` 通过 `get_backpack_capacity_groups()` 实时读取战术仓储舱等级：0/1/2/3/4/5 级对应 `25/30/35/40/45/50` 组；风险合约再以该实时上限乘容量倍率并四舍五入。既有旧档背包记录不会因初始上限改为 25 组而被读档迁移，只有后续新增、拾取和仓库转入受当前上限校验。
- 新增设施效果时必须保持同一方向：据点服务只暴露只读查询，不反向调用业务服务。

## 5. 持久化

- 独立写入 `user://hideout_state.json`，版本 1；保存设施等级表与建造队列（设施 ID、剩余在线秒数、目标等级、已付费用）。
- 建造扣款走 `_flush_linked_saves()` 立即保存据点与星穹两份存档；倒计时高频变化按 0.5 秒合并写盘。
- 战斗期间存档挂起（`_combat_save_pending`），战斗结束、窗口关闭或服务退出时统一补写，与矿场服务同一模式。
- 读档时建造数据异常（设施被移除、倒计时非法）会退还已付星穹并清空队列，不提升等级。
- 文件已加入 `SaveArchiveService.SAVE_FILE_NAMES` 白名单，随导出、导入与删除统一处理。

## 6. 扩展注意

- 新增设施时在 `FACILITY_DEFINITIONS` 追加条目并提供对应只读加成接口；费用与建造时长阶梯默认沿用现有常量。
- 大厅“据点”实体与主菜单按钮使用稳定动作 ID `hideout`；替换设施视觉不得改变该 ID。
