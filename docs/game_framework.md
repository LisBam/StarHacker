# 游戏基础框架

本文档记录《崩坏：量子骇袭》的入口流程、玩家控制框架和可扩展点，用于后续长期维护。

玩法规则与当前默认数值的权威快照统一维护在 `docs/游戏机制与玩法内容.md`；本文档重点记录代码架构、组件职责和扩展约定。

## 场景入口

- `res://scenes/ui/main_menu.tscn` 是项目主场景，由 `project.godot` 的 `run/main_scene` 指向。
- 主菜单脚本 `res://scripts/ui/main_menu.gd` 通过 `character_select_scene_path` 加载独立角色选择场景，默认第一行按钮文案为“骇入”。主菜单同时保留“训练场”按钮，两者都会先写入当前模式，再进入 `res://scenes/ui/character_select.tscn`。
- `res://scenes/ui/character_select.tscn` 是进入战斗前的角色选择场景。玩家在左侧选择“星”“穹”“银狼”，右侧会显示角色名称、定位、说明、固定生命上限、固定能量上限、固定速度和技能占位信息，点击确认后进入 `res://scenes/game/game_world.tscn`。
- 主菜单提供“设置”入口，设置首页包含全局 Master 主音量和“按键绑定”入口；左下角固定提供“仓库”按钮，打开后可在纯永久仓库模式与仓库/背包联合模式间切换，出售安全物品并通过拖拽管理仓库、背包和装备槽。
- 主菜单依次输入 `LISBAM` 会显示局外开发者菜单，提供“一键获取所有武器”“随机获得 10 颗强化石”“一键增加 1000 金币”“一键减少 1000 金币”和二次确认的“清空仓库物品”。战斗内打开 ESC 暂停菜单后同样可输入 `LISBAM`，此时显示战斗开发者菜单，可切换无限血量、无限能量并在正式模式打开训练场设置。
- `res://scripts/game/session_state.gd` 通过 `project.godot` 自动加载为 `SessionState`，负责保存本次进入的模式和角色，避免把入口参数写进场景路径。
- `res://scripts/game/global_inventory.gd` 通过 `project.godot` 自动加载为 `GlobalInventory`，分别保存随身背包、永久仓库、装备槽、局外金币、获得时间、上次撤离优先级和战斗结算，并写入 `user://global_inventory.json`。
- `res://scripts/game/scene_transition.gd` 通过 `project.godot` 自动加载为 `SceneTransition`，统一接管主菜单、角色选择与战斗场景切换。完整黑屏过渡固定为 0.30 秒：前 0.15 秒淡至黑色并切换场景，后 0.15 秒恢复画面；暂停状态下也继续执行。
- `res://scenes/game/game_world.tscn` 是当前战斗承载场景，负责放置玩家、怪物、网格地图、随机墙体建筑和掉落物。它的脚本会在进入场景后生成大型网格地图，再随机摆放一批环境障碍和怪物。

## 玩家角色

- `res://scenes/characters/player.tscn` 是当前通用玩家预制体，根节点为 `CharacterBody2D`。实际显示角色由独立角色选择场景决定。
- 当前可选角色为“星”“穹”“银狼”。三名角色暂时只提供占位属性：进入骇入、进入训练场或在训练场内切换角色时，会按固定配置设置生命上限、能量上限和移动速度；主动技能和被动技能后续再接入。
- `res://scripts/player/player_controller.gd` 是聚合脚本，只负责调度输入、移动、远程攻击、近战攻击和瞄准朝向。聚合脚本通过节点路径获取组件，不直接强类型依赖自定义组件类，避免新项目或缓存刷新时出现全局类名解析顺序问题。
- 玩家视觉、碰撞、摄像机、枪口、输入组件、移动组件、远程攻击组件和近战攻击组件都以子节点形式挂载，便于逐项替换。

## 输入规则

输入映射在 `project.godot` 的 `[input]` 中维护：

- `move_left`：A
- `move_right`：D
- `move_up`：W
- `move_down`：S
- `attack_fire`：鼠标左键
- `attack_melee`：鼠标右键
- `sprint`：Shift，按住疾跑并持续消耗能量
- `dodge`：Space，朝当前移动方向闪避突进
- `switch_ranged_1`：数字键 1，切换到第 1 个远程武器槽
- `switch_ranged_2`：数字键 2，切换到第 2 个远程武器槽
- `switch_ranged_previous`：鼠标滚轮上，切换到上一把远程武器
- `switch_ranged_next`：鼠标滚轮下，切换到下一把远程武器
- `toggle_inventory`：E，打开或关闭背包界面
- `toggle_large_map`：M，打开或关闭完整大地图
- `pause_game`：ESC，暂停游戏并打开暂停菜单
- `pickup_nearby`：F，快速拾取玩家附近最近的一件地面武器或资源
- `toggle_drop_list`：G，常驻开启或关闭附近掉落物列表自动显示

`InputBindings` 会在项目启动时记录 InputMap 默认值，并从 `user://input_bindings.cfg` 读取玩家自定义绑定。主菜单设置和暂停设置都会提供“按键绑定”页面，玩家点击操作对应按钮后，按下新的键盘键或鼠标按钮即可覆盖该操作的主绑定；多个可配置操作允许绑定到同一个输入事件，用于支持一键多用。未绑定状态会写入 `EVENT_TYPE_UNBOUND` 并记录到显式未绑定缓存，玩家输入层和 HUD 会识别该状态，不会再启用默认物理键兜底。单项默认状态按实际物理键位、修饰键或鼠标按钮进行语义比较，重新把操作绑定到原键位仍视为默认，不显示单项“默认”按钮。点击“恢复默认”会把所有可配置操作恢复到项目默认输入。`PlayerInputComponent` 仍保留物理键兜底，但只在对应 InputMap 动作缺失，或事件为空且不是玩家显式未绑定时启用，因此玩家完成自定义绑定后，旧默认按键不会继续触发同一操作。

数字键切换通过 `max_direct_ranged_slots` 控制可直接访问的远程槽数量，默认值为 2。扩展远程槽位时，需要同步提高 `EquipmentComponent.ranged_slot_count` 和 `PlayerInputComponent.max_direct_ranged_slots`。

## 组件职责

- `PlayerInputComponent`：读取移动向量、鼠标瞄准方向、远程攻击状态、近战攻击请求、疾跑状态和闪避请求。
- `TopDownMovementComponent`：独立保存输入产生的基础移动速度，再与本帧外部击退速度合成 `CharacterBody2D.velocity` 并执行 `move_and_slide()`，避免上帧后坐力被重复计入基础移动。
- `RangedAttackComponent`：按冷却生成弹体，弹体从 `AimPivot/Muzzle` 位置发射，并把武器射程、伤害、速度和冲击力写入弹体。发射前会检测角色到枪口的线段和枪口圆形范围是否被环境墙体阻挡，避免贴墙时把子弹生成到墙体内部。
- `MeleeAttackComponent`：在短时间内开启朝向鼠标方向的 `Area2D` 命中框，支持命中去重、近战冲击力和敌方子弹消除。
- `PlayerProjectile`：按方向移动，按寿命或最大距离自动销毁，通过射线提前检测怪物和环境墙体，命中可调用目标的 `apply_damage(damage, source)`。
- `EnemyProjectile`：远程怪物发射的敌方弹体，会命中玩家或被环境阻挡，也能被玩家近战命中框消除。弹体内部有一次性命中锁，扫线检测和 `body_entered` 即使同帧触发，也只会结算一次伤害和击退。
- `CombatStatsComponent`：维护玩家生命、能量、能量恢复、攻击力、防御力和死亡状态，默认攻击力 100、防御力 0；武器成功使用后由玩家控制器调用 `spend_energy()` 扣除能量，生命降到 0 时只派发一次 `died` 信号。
- `CombatDamageCalculator`：统一执行 `C=100` 的攻防公式、暴击判定、增伤/减伤乘积和最终取整，弹体、近战、玩家与敌人不再分别实现伤害换算。
- `DamageNumberPopup`：在怪物受击位置显示最终整数伤害，暴击使用红色，字号按伤害值对数增长并限制最大尺寸。
- `InventoryComponent`：作为玩家节点上的背包能力代理，默认把增删、移动、堆叠条目查询和强化石使用转发给 `GlobalInventory`；强化可返回提升/削弱属性、百分比、基础值和实际变化值；自动加载缺失时才回退场景内本地数组。
- `EquipmentComponent`：作为玩家节点上的装备能力代理，除远程与近战武器槽外维护头部、躯干、腿部和脚部四个防具槽；从 `GlobalInventory` 同步装备后聚合攻击、防御、生命、回血、闪避、暴击和移速属性。玩家每次实际受到伤害时，四件未损坏防具各消耗 1 点耐久。
- `ItemCardView`：全项目唯一物品视觉与交互模板，固定尺寸为 160×72 像素，统一深色背景、2 像素边框、4 像素圆角、三行信息结构与底部耐久承载。三行内容在卡片内部横向、纵向双向居中；所有卡片悬浮统一在 0.12 秒内缩放至 1.03 倍，点击按下统一在 0.07 秒内缩放至 0.96 倍，释放后在 0.12 秒内恢复悬浮或普通比例；拖拽来源统一缩放至 0.96 倍且透明度降至 0.58；拖拽预览复制完整标准卡片，从 0.92 倍开始，以 0.32 秒单段周期在 1.0 至 1.04 倍间呼吸并左右摆动 0.035 弧度；禁用状态统一覆盖 RGBA `0.16, 0.16, 0.16, 0.72` 灰色遮罩且不播放交互动画。背包、仓库、锻造、商店、灰市、物资撤离、结算及装备槽只负责交互协议，不得自行创建差异化视觉或动画。
- `WeaponSlotControl`：显示单个武器槽或背包武器槽，负责拖拽数据、投放校验、向 `ItemCardView` 传递白色冷却遮罩、修复目标可用/禁用表现和带上下文的点击事件；普通点击延迟到左键释放确认，鼠标移动达到默认 6 像素或进入拖拽后不会发送选择信号，点击复用 `ItemCardView` 标准按下与释放动画，不播放武器专属回弹。
- `InventoryDropArea`：接收拖到背包空白区域的武器拖拽数据，并转发给 HUD 按背包末尾投放处理。
- `InputBindings`：全局输入绑定管理器，以 AutoLoad 单例存在，不声明同名 `class_name`，保存可配置动作、默认事件、玩家自定义事件和恢复默认逻辑，直接写入 Godot `InputMap`，允许多个动作共享同一个输入事件；同时提供单项恢复与全部恢复接口。
- `KeyBindingPanel`：复用型按键绑定 UI，主菜单设置和暂停设置的按键绑定页面都会动态创建它，用于捕获下一次键盘或鼠标输入并调用 `InputBindings.rebind_action()`；只有当前绑定偏离项目默认值时才显示单项“默认”按钮，底部始终保留全量“恢复默认”。
- `CombatCamera`：玩家子节点上的战斗相机，关闭 Camera2D 位置平滑并使用物理帧回调跟随玩家，避免物理移动和渲染相机不同步造成移动抖动；屏幕震动只修改相机 `offset`，不会改变玩家或相机节点真实位置。
- `CombatHud`：除原战斗 HUD、背包和暂停职责外，负责显示左上角全地图存活怪物数量、调用全局背包完成结算，并以背包同款两级分类和双列列表展示本局首次获得物品；局内背包一级分类为“全部/武器/装备/资源”，装备二级分类为“全部/头部/躯干/腿部/脚部”，并支持装备、修复和单件/整组/部分丢弃，部分丢弃复用数量弹窗；道具目标选择会给装备栏、背包武器和背包资源中的不可选物品统一添加武器栏同款完整灰色覆盖层并阻止无效点击；F 键附近存在掉落物时优先拾取，否则管理宝箱范围提示和长按进度；物资撤离点准备完成后按闪避打开暂停式送回面板；战斗开发者菜单可请求一键解锁地图视野。
- `MiniMapControl`：读取 GameWorld 的地图、探索、正式撤离点、开局物资撤离点和玩家导航标点；障碍在绘制前按探索格裁剪，未探索墙体在大小地图均不显示，未探索区域在大小地图共同覆盖高透明度蓝黑迷雾与细网格纹理；局部小地图额外排除宝箱，点位只有在对应探索格被发现后才标记。
- `WarehousePanel`：主菜单局外仓库 UI，只调用 `GlobalInventory`。展开背包后，远程武器提供“装备1”“装备2”并明确替换对应远程槽，近战武器提供“装备”；仓库与背包之间拖动数量大于 1 的强化石或修复包时复用数量弹窗选择实际移动量，Shift+点击仍转移整组；仓库/背包分隔拖条使用全局鼠标跟踪和按下时缓存的稳定高度，默认仓库占 0.38，可调范围为 0.10 至 0.90，背包缩小时通过外层滚动容器继续访问全部内容。
- `StorageItemControl`：仓库、背包、锻造来源、物资撤离和结算共用交互控件，内部统一挂载 `ItemCardView`；强化石摘要显示品质、堆叠数量和属性方向，修复包显示恢复值，仓库资源可显示整组售价，物资撤离显示整组实际收费但悬停详情显示出售价格。通用选择状态使用完整灰色覆盖层，不可选时禁用悬停提亮，可选绿色目标提供缩放反馈；控件不直接修改物品所有权。
- `StorageDropArea`：仓库与随身背包共用的流式拖放区域，只校验拖拽协议并把目标容器交给 `WarehousePanel`；内部使用 `HFlowContainer` 按可用宽度自动换行，每一行都居中排列固定尺寸卡片，避免固定两列导致右侧大面积空白。
- `InventoryQuery`：仓库、局内背包、商店、锻造材料和结算列表共用的只读查询组件，支持“全部/武器/装备/资源”一级分类、近战/远程武器二级分类、头部/躯干/腿部/脚部装备二级分类与强化石/道具资源二级分类；“全部”返回所有物品类型。查询为条目附加真实来源下标并执行多层分类、关键词、强化属性正负方向多选筛选和获得时间/物品价值排序，多个筛选键按并集匹配，旧版纯属性键继续匹配任意方向，不修改全局库存顺序。
- `EquipmentStorageSlotControl`：局外与战斗背包共用的装备槽交互控件，同时支持远程、近战、头部、躯干、腿部和脚部；内部复用 `ItemCardView`，并保留拖拽反馈、修复目标滤镜和 `ItemDetailFormatter` 悬浮窗。
- `WeaponDurabilityBar`：只读通用耐久显示组件，贴在 `ItemCardView` 最底部并保持等宽；仅当资源同时声明 `current_durability` 与 `max_durability` 属性时显示，耐久高于 50% 为绿色、20% 至 50% 为黄色、低于 20% 为红色、归零为灰色。物品类型名称不参与是否显示耐久条的判断。
- `EquipmentData`：四部位防具共用的数据资源，保存当前耐久、最大耐久、攻击、防御、最大生命、每 5 秒回血、闪避、暴击与强化累计值；提供与 `WeaponData` 相同的 0 至 1 耐久比例接口，脚部额外支持移速，损坏后全部属性暂时失效。装备悬停详情与武器统一显示“当前耐久 / 最大耐久”。
- 头部装备额外支持视野百分比；`EquipmentComponent` 将相机缩放除以 `1 + 视野比例`，因此视野越高，相机高度越高，探索系统也会自动读取更大的实际世界视野。
- `EnhancementResultDialog`：仓库与局内背包共用的强化结果弹窗，先列提升、后列削弱，每条显示使用时随机出的百分比、基础值、本次变化值和强化后数值，并显示强化前后售价与价格差。
- `SellQuantityDialog`：堆叠出售、跨容器移动、战斗内部分丢弃和物资部分送回共用数量弹窗，以 1 到当前可操作数量为范围，同步提供整数滑条和数字框；送回模式实时预览价值、20% 运费和操作后剩余额度。默认窗口为 400×170，背景透明度为 0.82，弹窗不直接修改库存。
- `DeveloperMenu`：可复用隐藏开发者调试面板；主菜单上下文通过 `GlobalInventory` 发放全部武器、全部装备、强化石、全部修复包和调整金币，战斗上下文隐藏经济操作并通过信号切换无限属性、不消耗武器耐久、获取整张地图视野和训练场设置。
- `GlobalInventory`：全局物品所有权服务，使用唯一记录区分武器与可堆叠资源，分别维护永久仓库、随身背包、装备、局外金币、临时拖拽记录、本局快照和存档。仓库与背包的部分堆叠转移会复制独立资源实例、保留获得时间与撤离标记，并通过原子接口同时更新两侧数量；只有签名一致的强化石或同类修复包才会合并，单组上限 99；出售接口支持指定数量、整组出售和开发者清空永久仓库。
- `MonsterSimulationManager`：维护整图轻量虚拟敌人人口，分批实例化玩家加载半径内的真实敌人，并在远离后保存位置和生命比例再释放节点；远处人口不执行任何 AI、物理、碰撞或绘制。
- `BasicMonster`：基础怪物聚合入口，维护血量、攻击、韧性、个体数值随机和组件配置，通过子组件组合索敌与移动能力，并保留近战、击退和继承扩展接口。
- `EnemyPerceptionComponent`：维护视野射线、目标记忆、视野丢失缓冲、遮挡次数、最后线索预测、障碍背后锚点、范围搜查和彻底脱战，不执行移动或攻击。
- `EnemyMovementComponent`：维护预设巡逻、出生点游荡、A* 路径缓存、局部绕障、空路径重试节流、卡住恢复、击退和实际移动，不读取玩家实时位置。
- `RangedMonster`：远程测试怪物，继承基础怪物受击、韧性、索敌记忆、绕障、个体移动差异和游荡逻辑；只有玩家可见、实时距离不超过 `shoot_range` 且射击线无遮挡时才发射敌方子弹，并按 `ranged_projectile_spread_degrees` 对实际方向施加随机扩散。
- `WeaponDrop`：通用地面物品掉落物，兼容武器、强化石和修复包并加入 `item_drops` 组，HUD 按距离扫描后生成附近掉落列表；拾取成功后会把同一个资源实例加入背包并释放掉落物节点。
- `CombatBurstEffect`：代码绘制的短促战斗爆发特效，用于玩家和怪物受击、死亡反馈；默认挂到当前场景根节点，保证死亡节点释放后特效仍能播放完成。
- `SessionState`：入口会话状态，保存当前模式和当前角色，供主菜单、GameWorld 和训练场角色切换复用。
- `LootChest`：独立宝箱建筑，集中维护四档品质、生命、范围内“长按F开启”提示、受击缩短后的有效开启时间、宝箱上方进度条、开启方式和一次性掉落请求；静态本体阻挡移动与双方弹体，`DamageReceiverComponent` 子组件额外接收玩家近战命中。
- `SupplyExtractionPanel`：战斗内暂停式物资送回面板，只通过 `GlobalInventory` 获取报价并原子转移背包或装备栏物品；金币不足或超过剩余价值的物品灰显不可选，堆叠部分送回复用 `SellQuantityDialog`。
- `GameWorld`：战斗承载脚本，生成大型网格地图、整图敌人分布、正式模式敌人补充、导航标点、墙体建筑、20 至 40 个宝箱、2 至 5 个物资撤离点、正式撤离点和掉落物，并提供摄像机探索、全图视野解锁与共享 A* 路径查询接口。

## 武器与装备

武器由 `res://scripts/data/weapon_data.gd` 定义，默认资源位于 `res://data/weapons/`：

- `quantum_pistol.tres`：量子手枪，远程武器，低能耗、稳定射速。
- `pulse_rifle.tres`：脉冲步枪，远程武器，高射速、高能耗。
- `phase_blade.tres`：相位刃，近战武器，右键消耗能量开启近战命中框，默认前坐力为 140。
- `ion_smg.tres`：离子冲锋枪，远程测试武器，高射速、低单发伤害。
- `rail_cannon.tres`：磁轨炮，远程测试武器，高伤害、长冷却。
- `scatter_blaster.tres`：散射爆能枪，远程测试武器，中等射速和中等消耗。
- `quantum_dagger.tres`：量子短刃，近战测试武器，低消耗、短冷却，默认前坐力为 140。

### 武器强化与强化石

`WeaponData` 将原有导出字段作为永久基础值，强化结果单独保存在 `enhancement_modifiers` 累计比例词典中。战斗组件不再直接把基础字段当作最终值，而是统一调用 `get_effective_stat()` 读取 `基础值 × (1 + 累计强化比例)`。内部继续保留 `ranged_damage`、`melee_damage`、`ranged_cooldown` 和 `melee_cooldown` 以兼容现有 `.tres`，所有 UI 统一显示为“伤害”和“冷却”。

强化石由 `res://scripts/data/enhancement_stone_data.gd` 定义，`item_kind` 固定为 `enhancement_stone`，`quality_id` 区分 low、medium、high、supreme，`modifiers` 只保存属性的 `+1/-1` 方向。掉落品质权重为 40% 初级、30% 中级、20% 高级、10% 极品；初级增强 10%–20% 且 80% 带 10%–20% 削弱，中级增强 20%–40%、10% 额外增强、40% 带 5%–20% 削弱，高级增强 30%–50%、20% 额外增强、10% 带 5%–10% 削弱，极品增强 40%–60%、30% 额外增强且永不附带削弱。每颗石头必定至少一条增强，词条不重复；具体幅度在每颗石头用于武器锻造时按品质重新随机。只有品质、属性和方向全部一致时才堆叠，旧存档中的具体百分比读取后只保留方向。

武器悬停详情只在属性确实发生强化变化时使用“总值（基础值±强化值）”格式；未变化属性只显示最终值，不显示“（100+0）”。强化石详情只显示属性与方向，增强词条全部排在削弱词条之前；颜色严格表达玩法收益，增强为绿色、削弱为红色，因此冷却-、能量消耗-、扩散-和后坐力-均显示绿色，对应反方向显示红色。强化成功后的共用弹窗会按同一规则着色，并展示使用时随机出的百分比、武器基础值、本次变化值、强化后数值和售价变化。

每把武器默认最大耐久与初始当前耐久均为 1000.0。每次成功使用按该武器的浮点属性 `durability_cost_per_use` 扣除耐久；训练场固定不消耗，正式战斗可通过开发者开关临时禁用。耐久售价倍率按 `0.1 + 0.9 × 当前耐久比例` 线性计算，满耐久为强化后有效售价的 100%，零耐久损坏武器仍可出售且售价为同强化状态满耐久售价的 10%；原始售价大于 0 时四舍五入后的最低结果为 1 金币。版本 6 存档同时保存当前耐久和保存时上限；版本 5 的 100 上限耐久按比例迁移到 1000.0，避免旧满耐久武器变为 10%。

默认耐久消耗：量子手枪 1.0、脉冲步枪 0.8、离子冲锋枪 0.5、磁轨炮 3.0、散射爆能枪 2.0、相位刃 1.5、量子短刃 0.75。物品悬停信息会显示当前/最大耐久与单次耐久消耗；悬停背景使用透明度 0.68 的深色框，并绘制 2 像素白色边框和 6 像素圆角。

当前通用玩家预制体默认装备两把远程武器和一把近战武器：

- 远程槽 1：量子手枪
- 远程槽 2：脉冲步枪
- 近战槽：相位刃

远程攻击流程为：玩家输入左键 -> `PlayerController` 读取当前远程武器并拒绝损坏武器 -> 检查能量 -> 成功生成弹体 -> 扣除能量；非训练场且未开启调试免消耗时，再按武器 `durability_cost_per_use` 扣除耐久。

近战攻击流程为：玩家输入右键 -> `PlayerController` 读取当前近战武器并拒绝损坏武器 -> 检查能量 -> 成功开启命中框 -> 扣除能量；非训练场且未开启调试免消耗时，再按武器 `durability_cost_per_use` 扣除耐久。

战斗反馈流程为：玩家成功使用武器后，`PlayerController` 会按武器 `recoil_force * fire_shake_per_recoil` 和 `front_recoil_force * fire_shake_per_recoil * 0.5` 向 `CombatCamera` 累加屏幕震动；后坐力与受击击退的累计速度上限为 720，按每秒 1800 衰减，撞墙后会立即移除压向墙体的法线分量并保留沿墙分量。玩家受到伤害时，会先检查 `damage_interval`，默认受伤后的 0.2 秒内忽略新的伤害、击退和受伤震动，再按伤害值和 `minimum_damage_shake` 计算本次受击震动。玩家和怪物受击时生成短促 `CombatBurstEffect`，生命归零时生成更大的死亡爆发特效。

武器新增四项控制相关属性：`bullet_range` 仅远程武器使用，用于覆盖弹体最大飞行距离，未配置时兜底为 340 像素；`recoil_force` 表示开火后坐力，会把玩家向射击反方向推开；`front_recoil_force` 表示前坐力，会把玩家向攻击方向推开，适合近战突进或特殊枪械反馈；`impact_force` 表示命中冲击力，怪物会按自身韧性折算击退强度。当前远程测试武器采用短射程默认值，避免玩家在大地图上过早跨屏清怪：手枪 340、步枪 420、冲锋枪 280、磁轨炮 520、散射爆能枪 260。

移动能力流程为：玩家按住 Shift 且存在移动输入时，`PlayerController` 每帧按 `sprint_energy_cost_per_second * delta` 扣除能量，并把本帧移动速度倍率提升到 `sprint_speed_multiplier`；玩家按下 Space 且当前存在移动输入时，先扣除 `dodge_energy_cost`，再按 `dodge_distance / dodge_duration` 朝当前移动方向突进。背包打开时战斗输入被锁定，疾跑和闪避也不会触发能量消耗。

战斗 HUD 顶部中心显示进入战斗后的存活时间，格式为 `mm:ss`，例如 `02:05` 表示已存活 2 分 5 秒；左上角显示全地图存活怪物数量，包含远处尚未实例化的虚拟人口。计时和怪物数量只在数值变化时更新。底部中心保持紧凑尺寸以降低视野遮挡：当前角色名、生命条和能量条在武器栏上方，远程武器槽和近战武器槽在下方。右上角小地图只显示玩家周围一段范围，并显示已经进入玩家摄像机视野的墙体、建筑和撤离点，不显示怪物或宝箱；未探索结构不会提前绘制。远程武器本次冷却总时长大于 `ranged_cooldown_overlay_minimum_duration = 0.12` 秒时才绘制白色半透明冷却遮罩；0.12 秒及以下的高射速武器不显示遮罩，实际射击冷却不变。近战冷却遮罩不受该阈值影响。

按 Q 会打开完整大地图。大地图使用正方形显示区域，显示整张战斗地图、玩家位置、已探索墙体、建筑和已标记撤离点，并读取 `GameWorld` 的探索格缓存绘制迷雾；未探索墙体不会透过迷雾显示。左键点击空白地图会设置或替换唯一导航标点；左键点中已有标点会取消。Q 键大地图和右上角小地图都会绘制玩家到标点的绿色虚线，标点超出局部小地图范围时线段指向地图边缘。虚线段长和间隔分别由 `navigation_dash_length`、`navigation_dash_gap` 控制。

背包通过 E 键打开或关闭。背包打开时，`CombatHud` 会通过 `PlayerInputComponent.set_combat_input_enabled(false)` 禁用射击、近战和切换武器，避免拖拽装备时误触战斗输入；WASD 移动不受影响。

局内背包界面采用左右分栏：左侧是当前装备，右侧是随身物品。整体面板固定扩展为 1040×620 像素，右侧物品区域净宽稳定容纳每行 4 张 160×72 卡片和 3 段 10 像素间距，同时不足 5 列；流式布局每行居中且自动换行。点击左侧已装备远程武器会切换当前手持槽；点击右侧背包武器会显示“装备”，远程武器替换当前手持槽，近战武器替换近战槽。武器槽在左键释放且移动距离小于等于 6 像素时才发送点击选择，移动达到阈值或已经开始拖拽时不会弹出菜单；所有物品的悬浮、点击、拖拽来源、拖拽预览与禁用遮罩统一由 `ItemCardView` 执行。强化石不可作为战斗消耗品直接使用，但可以通过物品菜单丢弃。修复包可点击“使用”进入目标选择，也可直接拖到武器上；选择期间所有不符合当前目标规则的物品统一使用 RGBA `0.16, 0.16, 0.16, 0.72` 完整覆盖层并不可选择。仓库、战斗背包和锻造来源查询统一支持获得时间、物品价值和耐久三种排序；耐久按当前/最大比例降序，相同比例比较当前值，无耐久物品排在末尾。

装备和背包使用单实例流转规则：一把武器资源同一时间只能存在于一个位置。右侧背包武器拖到左侧装备槽后，会从背包列表移除；如果目标装备槽已有武器，旧武器会回到原背包位置。左侧装备拖回右侧背包的空白区域或任意背包物品上都会卸下并插入背包；背包武器之间拖拽会移动原物品顺序，不会复制资源；远程装备槽之间拖拽会移动或交换同一个武器引用。

局外仓库与随身背包是两个独立容器。仓库和背包使用居中流式布局，根据当前面板可用宽度自动增加每行卡片数量并换行，消除固定两列造成的右侧空白；所有条目固定使用 160×72 像素 `ItemCardView`，不会因物品类型改变尺寸。普通点击强化石只提供出售，强化石只能放入锻造系统；修复包提供出售和使用。堆叠出售可通过滑条或数字框选择数量，也可直接全部出售；把数量大于 1 的强化石或修复包拖到另一容器时，同一数量弹窗切换为移动模式，玩家可选择 1 到当前堆叠数量，目标侧按签名自动合并且单组不超过 99。修复包选择使用后自动展开背包并显示红色“取消使用”，仓库、背包和装备栏内未满耐久物品高亮，满耐久物品置灰且不可选择。仓库出售、战斗背包装备/使用/丢弃和物资撤离送回均由 `ItemActionPopup` 生成统一功能按钮；该组件集中维护 268 像素弹窗、42 像素按钮、普通/危险/禁用样式及悬停按压缩放，非物品按钮不接入。

永久仓库首次建立或从旧存档迁移时默认按获得时间从新到旧排列，之后会保存玩家手工调整的列表顺序。强化石保存品质、属性和方向；读取旧存档时，通用“强化石”按初级品质恢复，旧方向或百分比词条统一保留正负方向。

地面掉落物使用同一套通用物品流转规则。玩家靠近地面武器或资源时，HUD 左侧按距离显示列表；按 F 拾取最近一件。进入宝箱范围后显示“长按F开启”，按住后切换为进度条，但只要周围存在可拾取掉落物就优先执行拾取。普通、中级、高级、极品宝箱基础开启时间分别为 1、2、3、5 秒；实际需求乘当前生命比例。手动开启和击破宝箱都会从箱体中心播放抛物线飞出动画，手动开启使用 34 至 72 像素紧凑落点，击破使用 105 至 190 像素放射落点；怪物死亡掉落也通过同一 `WeaponDrop.play_launch_animation()` 接口播放独立配置的短抛物线。战斗背包点击物品可丢弃，堆叠资源提供全部或部分丢弃，部分丢弃复用数量弹窗；拆分出的地面资源会登记为本局已见实例，重新拾取不会被误计为新战利品。

## 局外商店与锻造

主菜单左下角依次提供仓库、商店和锻造三个局外入口，每个入口使用独立全屏遮罩和可复用面板。`MainMenu` 只负责创建、显示和关闭面板，不直接执行购买或锻造结算；隐藏面板不会响应 ESC，避免多个常驻面板同时消费同一输入事件。

`ShopService` 作为 AutoLoad 独立维护普通商店、十分钟自动刷新截止时间、连续手动刷新费用和最近五次失败灰市批次，并把状态保存到 `user://shop_state.json`。商品物品状态通过 `GlobalInventory.serialize_item_snapshot()` 与 `deserialize_item_snapshot()` 复用库存版本兼容格式，购买则统一调用 `purchase_resource_to_warehouse()` 完成金币检查、扣款和入库，UI 不直接修改库存。普通商品购买后从本轮库存移除；灰市购买同时按失败批次和商品编号定位，空批次自动清理。

普通商店每轮生成 6 件武器、4 件随机部位装备与 6 颗强化石，售价为物品原价的 1.5 至 3.0 倍。远程武器和装备各有 30% 概率成为二手商品，名称以“【二手】”标识并显示真实耐久，不显示历史强化石数量；二手商品消耗最大耐久的 10% 至 90%，并按累计概率表决定历史强化次数。商店商品快照保存并恢复二手武器与装备的真实耐久；读取旧商店存档时，若商品已标记为二手但仍是模板满耐久，会自动补生成 10% 至 90% 的剩余耐久，正常随机耐久不会被重新抽取。商店与灰市商品区使用居中流式布局，按面板可用宽度自动换行并尽量填充每行；所有商品固定复用 160×72 像素 `ItemCardView`，带耐久属性的商品显示底部耐久条，完整数值可在悬停详情中查看。商店持有金币与商品价格统一使用黄色字体；强化石卡片顶部直接显示全部属性名称和正负方向，不提前公开使用时随机生成的实际百分比。默认商品价格仅显示最终金币，`DebugSettings` 开启后才追加原价倍率。刷新、购买和失败提示在 3 秒内线性淡出。首次手动刷新为 10 金币，同一自动刷新周期内每次乘 1.5 并向上取整，自动刷新后恢复 10 金币。

正式战斗失败结算由 `GlobalInventory.combat_failure_losses_recorded` 发送实际遗失条目的只读快照，`ShopService` 将其加入灰市并只保留最近 5 次失败。灰市武器按当前强化状态的满耐久有效价值估价，强化石按单颗有效价值估价，最终购买价为 `满耐久或单颗价值 × 实际遗失数量 × 4 至 8 倍随机倍率`；回购物品保留失败时的实际耐久、强化状态和堆叠数量。

`ForgePanel` 维护一个主锻造槽、五个牺牲槽、来源查询、多选词条筛选和动画状态，真实规则集中在无 UI 依赖的 `ForgeService`。主锻造槽、牺牲槽与来源列表全部固定复用 160×72 像素 `ItemCardView`，旧 `forge_slot_size` 参数仅保留调用兼容，不能再改变物品卡片尺寸；选择背包来源时下方区域使用左右分栏，左侧独立滚动装备栏复用 `EquipmentStorageSlotControl` 的真实点击和拖拽协议，右侧独立显示背包物品，仓库来源则隐藏左栏并使用完整宽度。装备来源通过 `ranged_N`、`melee` 和 `armor_部位` 稳定标识参与与背包、仓库相同的所有权校验和原子消费；来源列表使用居中流式布局按可用宽度自动换行；顶部中心牺牲槽额外上移 16 像素，右下与左下两个牺牲槽额外下移 24 像素，避免与主锻造槽重叠。槽位仅保存资源实例与原来源引用。主锻造槽可放武器或装备，两类物品可跨类型互相作为耐久牺牲品并提供当前耐久的 10%；耐久溢出部分不恢复、不计费但不会把正耐久牺牲品判为无效。武器强化石只强化武器，装备强化石只强化装备，初级、中级、高级、极品强化石基础费用为 2、5、10、20 金币，总费用按主物品价值倍率计算。主锻造槽放初级、中级或高级强化石时进入升阶模式，牺牲槽只接受同品质强化石，每颗提供 20% 成功率，最高 100%，不收取金币；成功按“初级→中级→高级→极品”替换一颗主石，失败消耗全部牺牲石并保留主石。主锻造槽确定后，背包、装备栏、仓库候选和槽内失效牺牲品都使用统一灰色遮罩且禁用开始按钮；仓库、战斗背包和锻造来源列表的“强化筛选”都在切回摘要项后按筛选集合重新同步复选框，已选属性方向始终可见。锻造结果弹窗统一展示属性、耐久和售价前后变化。

## 暂停与设置

ESC 会优先关闭当前打开的交互界面；没有背包或大地图时打开暂停菜单。暂停菜单的“脱离卡死”会按 48 像素格、26 像素障碍安全半径向外搜索最多 12 圈，并把玩家传送到最近安全点后清空外部速度。正式战斗的“逃跑”会先弹出二次确认；训练场按钮显示为“离开”，点击后直接返回主菜单且不结算物品。正式战斗明确提示随身背包物品约保留 50%、丢失 50%，确认后才执行失败结算，已装备物品、永久仓库和局外金币不参与损失。结算窗口下方按钮统一显示“确定”，点击后返回主菜单。操作系统关闭窗口时，`GlobalInventory` 也会在正式战斗活动期间执行同一失败结算并立即保存。

玩家生命值降到 0 后，`CombatStatsComponent.died` 会通知 `CombatHud`。正式战斗中，每把随身背包武器和每颗堆叠资源独立以 50% 概率保留、50% 概率丢失，已装备物品、永久仓库物品和局外金币不参与损失；仓库式双列结算列表只展示本局首次获得和实际丢失物品，不展示随机保留列表，堆叠资源以 xN 显示数量。每个物品都可悬停查看完整详情。训练场死亡或从暂停菜单返回主菜单时都不会打开物品结算窗口，也不会修改永久仓库、背包或金币。

暂停设置和主菜单设置共用同一条 Master 音量规则：滑条范围为 0 到 100，0 会静音 Master 总线，大于 0 时使用 `linear_to_db()` 写入音量。

暂停设置和主菜单设置都采用分页结构。设置首页只显示主音量、“按键绑定”入口和返回按钮；点击“按键绑定”后切换到独立按键绑定页面，按该页“返回”只回到设置首页，不会直接关闭设置面板。绑定面板修改的是全局 `InputMap`，因此在主菜单中修改的按键会影响后续进入战斗后的玩家操作，在暂停菜单中修改的按键会立即影响当前战斗。按键绑定保存到 `user://input_bindings.cfg`，下次启动游戏时自动恢复；多个操作可以保存为相同按键或鼠标按钮。每行“默认”只恢复对应操作，底部“恢复默认”恢复全部操作；大地图项目默认键为 Q。

训练场暂停菜单默认提供“训练场设置”面板，且训练场成功攻击不会消耗武器耐久。正式“骇入”模式可通过战斗开发者菜单开启“不消耗武器耐久”，该开关只影响当前战斗运行时状态；其他训练工具和撤离时间调试规则保持不变。

## 怪物与训练场

当前怪物场景包括 `res://scenes/enemies/basic_monster.tscn` 和 `res://scenes/enemies/ranged_monster.tscn`。怪物使用 `CharacterBody2D`，碰撞层为 2、碰撞掩码为 16，只与第 5 层环境障碍发生物理碰撞；`BasicMonster._ready()` 还会从旧配置中强制移除玩家第 1 层，`set_target()` 为玩家和怪物建立双向碰撞例外，目标切换或怪物卸载时再双向清理，因此基础怪物、远程怪物和动态生成实例都不能与玩家产生实体碰撞或互相推动，也不会在虚拟人口反复加载后留下失效例外。玩家弹体和近战命中框仍通过碰撞层 2 命中怪物。

敌人加载休眠、实心墙体视野、独立三层记忆、四段警戒、平面搜查、移动寻路与巡逻配置统一记录在 `res://docs/enemy_ai.md`。当前没有怪物情报共享：一只怪物发现玩家不会唤醒或改变其他怪物索敌状态。本节只保留全局框架摘要与检查器参数索引。

基础怪物属性包括：

- `max_health` / `current_health`：血量。
- `weapon_drop_chance`：死亡掉落武器概率，默认 0.20。每只怪物可单独调节，0 表示不掉落，1 表示必定掉落。
- `attack_damage`：攻击力，近身攻击玩家时传给玩家的 `apply_damage(damage, source)`。
- `toughness`：韧性百分比，默认 0；数值为 1 时减少 1% 击退效果，数值为 100 时完全免疫击退。
- `attack_impact_force`：怪物近身攻击冲击力，玩家受伤时会按来源方向被击退。
- `move_speed`：基础移速，索敌后按个体移动倍率追击玩家。
- `move_speed_random_multiplier_min` / `move_speed_random_multiplier_max`：个体移动速度随机倍率范围。每只怪物出生时只随机一次，默认 0.88 到 1.16，用于避免同类怪物移动完全一致。
- `vision_range`：视野范围，玩家进入范围且没有被墙体遮挡时怪物锁定并追击。
- `attack_range`：攻击距离，玩家进入后怪物停止移动并按冷却攻击。
- `attack_cooldown`：基础攻击冷却。
- `attack_cooldown_random_multiplier_min` / `attack_cooldown_random_multiplier_max`：个体近战攻击冷却随机倍率范围。每只怪物出生时只随机一次，并会随机初始攻击冷却，用于错开近战攻击节奏。
- `lose_target_range_multiplier`：脱战视野倍率，怪物已经锁定玩家后，会在无遮挡情况下使用扩展视野减少边缘反复丢失目标。
- `vision_requires_line_of_sight`、`vision_line_of_sight_collision_mask`、`solid_wall_group`、`line_of_sight_skip_limit`：索敌视线参数。默认只检测第 5 层并要求碰撞体属于 `environment_obstacles`；非墙体地图元素会被射线跳过，不能触发完整视野丢失。
- `vision_loss_grace_duration`、`visible_intelligence_broadcast_interval`：前者过滤墙角擦边和单帧射线抖动；后者作为旧字段保留，当前只刷新本怪物内部最后线索，不会广播给其他怪物。
- `target_memory_duration`、`search_arrive_distance`：短期线索参数。默认 30 秒保存最后可见位置、实心墙体命中点、最后可见速度和逃跑方向；遮挡后不读取墙后玩家实时坐标。
- `hidden_target_tracking_range_multiplier`：旧隔墙追踪配置保留项。当前四段警戒不会使用该值继续追踪墙后玩家。
- `target_prediction_time`、`target_prediction_max_distance`：目标预测参数。怪物只会根据最后可见阶段的历史位置估算移动趋势，并把初始搜查目标短距离前推；最大距离用于限制预测过头。
- `medium_memory_duration`、`medium_hotspot_merge_distance`、`medium_hotspot_max_count`、`medium_recheck_trigger_radius`、`medium_recheck_duration`、`medium_recheck_cooldown`：中期高频墙角和逃生通道记忆。达到脱战阈值后仍保留，巡逻途经热点会短时复查。
- `long_term_region_radius`、`long_term_alert_patrol_speed_multiplier`：长期交战片区。短中期记忆消退后仍保留路过时的低速高警戒，但不会隔墙重新锁定玩家。
- `target_search_duration_after_arrival`、`target_search_radius`、`target_search_point_wait_min`、`target_search_point_wait_max`：感知组件的兜底区域搜查参数。`search_move_speed_multiplier` 保留为旧场景兼容项，主动追击、搜查、卡位和迂回当前统一使用固定个体移速。
- `occlusion_break_forget_count`、`occlusion_count_reset_duration`、`blockade_loss_margin`、`lost_search_occlusion_offset`、`lost_search_destination_attempts`：反卡墙与状态流参数。临近阈值进入二级全域封锁，达到阈值后停止主动搜寻但不一次性清空短中长期记忆。
- `tactical_search_near_radius`、`tactical_search_middle_radius`、`tactical_search_far_radius`、`tactical_blockade_radius_multiplier`、`melee_search_radius_multiplier`、`ranged_search_radius_multiplier`、`search_fan_half_angle_degrees`、`wall_corner_clearance`、`route_prediction_time`、`lane_segment_spacing`、`tactical_point_arrive_distance`、`tactical_point_wait_min`、`tactical_point_wait_max`、`search_points_before_ambush`、`tactical_destination_attempts`：三层扇形搜查、分段卡位、外侧迂回与静止伏击参数。
- `patrol_route_path`、`patrol_route_loop`、`wander_radius`、`wander_speed_multiplier`、`wander_arrive_distance`、`wander_wait_min`、`wander_wait_max`：无目标巡逻参数。配置路线容器时按其 Node2D 子节点顺序巡逻，脱战后从最近路线点返程；未配置路线时围绕出生点随机游荡。
- `avoidance_probe_distance`、`avoidance_angle_step_degrees`、`avoidance_candidate_count`：局部绕障参数。怪物追击或游荡时会先尝试直线方向，若前方被墙体挡住，则按每只怪物随机生成的左右偏好寻找可移动方向。
- `pathfinding_enabled`、`pathfinding_cell_size`、`pathfinding_agent_radius`、`path_recalculation_min_interval`、`path_recalculation_max_interval`、`path_destination_refresh_distance`、`path_waypoint_arrive_distance`、`path_random_goal_radius`、`path_max_point_count`：网格寻路参数。怪物会检测自身到目标点的中心线是否被环境阻挡，一旦追击点、遮挡物背后搜查点或巡逻点被墙体建筑隔开，就提前向 `GameWorld.find_navigation_path()` 请求无斜向穿角的 A* 路径，而不是先直线贴墙移动。默认寻路格子为 32 像素、代理半径为 18 像素，和当前怪物碰撞半径接近，可保留建筑入口通行能力；路径终点随机偏移只在目标可见时使用，固定搜查点和巡逻点不会随机漂移。空路径会等待重算间隔再请求，避免每个物理帧重复执行失败寻路。
- `stuck_detection_time`、`stuck_minimum_movement`：卡住检测参数。怪物持续有移动意图但实际位移过小时，会翻转局部绕障偏好并清空缓存路径，下一帧重新请求路径。
- `knockback_decay`：击退衰减速度，控制怪物被玩家武器命中后滑退多久。
- `hit_effect_color`、`death_effect_color`：怪物受击和死亡特效颜色，只影响视觉反馈，不影响战斗数值。

远程怪物额外属性包括 `projectile_scene`、`shoot_range`、`keep_distance`、`ranged_projectile_speed`、`ranged_projectile_damage`、`ranged_projectile_range`、`ranged_projectile_impact_force`、`ranged_projectile_spread_degrees`、`shoot_cooldown`、`muzzle_offset` 和视线配置。敌方弹体默认扩散为 4 度，每次发射会随机偏移。

敌方远程怪物默认开火距离为 500 像素，弹体默认最大飞行距离为 520 像素，避免远程怪物在训练场中过早跨屏命中玩家。

`GameWorld` 进入骇入或训练场时都会先生成大型网格地图。默认地图以世界原点居中，`grid_extent = 96` 会生成 192x192 格地图；`map_seed = 0` 表示每次进入都随机生成环境布局，设置为固定正数可以复现同一套墙体、建筑和怪物位置。当前地表绘制纯色底面、低透明度网格线和地图边界，地图结构主要由随机墙体和建筑提供。地图四周会按 `boundary_wall_thickness` 自动生成一圈环境墙，阻挡玩家、怪物和子弹离开地图。

环境预制体位于 `res://scenes/environment/`：

- `wall_segment.tscn`：单段直墙。
- `compact_building.tscn`：实心建筑块。
- `wall_ring_building.tscn`：一圈墙体构成的建筑结构，底部保留入口缺口，玩家和怪物可以进入内部。
- `corridor_building.tscn`：两侧墙体构成的通道建筑，前后开口可通行。
- `cross_access_building.tscn`：四角建筑块构成的四向出入口建筑，中心与上下左右方向可通行。
- `l_wall.tscn`：L 型墙体，用于制造转角掩体和局部阻挡。
- `l_building.tscn`：L 型实心建筑块，用于制造更大的转角建筑轮廓。

`GameWorld` 通过 `obstacle_scenes` 等参数控制环境生成，并缓存环境碰撞矩形供地图和 A* 使用。宝箱生成早于虚拟敌人人口和导航请求，同样写入第 5 物理层、`environment_obstacles` 分组和障碍缓存，因此敌人局部碰撞、视线射线、射击射线和共享 A* 都会考虑宝箱；右上角小地图请求障碍数据时排除宝箱，完整大地图则在探索后保留其占位。开启或击毁后会移除自身障碍矩形、清空导航缓存并刷新地图版本。每局随机生成 20 至 40 个宝箱，72% 候选优先位于建筑周边，封闭环形建筑和紧凑建筑在周边候选中使用 3 倍权重。宝箱品质标签默认隐藏生命，只有 `DebugSettings` 的“调试信息显示”开启后才附加生命值。

`GameWorld` 会按 `exploration_cell_size` 记录曾进入玩家 `Camera2D` 实际世界视野矩形的地图格子；`player_camera_path` 默认指向 `Player/Camera2D`，所以相机缩放与窗口尺寸变化会自动改变发现范围，`exploration_radius = 760` 只在摄像机缺失的独立测试场景中作为回退。该数据只由地图 UI 读取，不影响怪物索敌和碰撞。探索记录不会每帧重算，而是按 `exploration_update_interval` 定期检查，并在玩家移动超过 `exploration_update_distance`、相机缩放或视口尺寸变化时提前刷新；只有新增探索格时才递增探索版本号。`MinimapControl` 先按探索格裁剪障碍矩形再绘制，因此未探索墙体在大小地图都完全不可见；物资撤离点和正式撤离点也要先进入探索格才显示。战斗开发者菜单通过 `unlock_full_map_vision()` 一次写入整张地图全部探索格。`GameWorld.find_navigation_path()` 会按寻路格尺寸和代理半径缓存整张地图的 A* 网格，供怪物在目标被墙体或建筑阻挡时自动绕路；寻路网格禁用斜向移动，避免路径从墙角缝隙穿过。环境障碍在地图生成完成后保持静态，因此缓存网格可以被所有怪物复用；如果后续加入可破坏墙体或动态门，需要在障碍变化后清空导航缓存和地图障碍版本。

`GameWorld` 默认使用 `monster_spawn_across_full_map = true` 在整张地图可用区域均匀建立 200 名虚拟敌人人口。正式模式的人口目标按存活时间连续增长：0 秒 200 名、300 秒 1200 名、600 秒 3200 名，之后维持 3200 名并持续补充死亡缺口。训练工具清怪会暂停自动补充，手动重新生成时恢复。

整图敌人由 `MonsterSimulationManager` 保存为虚拟记录。默认只有玩家 2400 像素范围内的记录会分批实例化，真实敌人离开 2800 像素后保存位置与生命比例并释放；管理器每 0.05 秒扫描最多 256 条记录，每批最多实例化 12 名，并以 `max_materialized_monsters = 220` 限制同时运行的真实敌人数量。HUD 左上角通过 `GameWorld.get_alive_monster_count()` 显示虚拟人口总数。

每只随机生成敌人在加入场景树前分别生成尺寸倍率和属性倍率，范围由 `monster_spawn_variation_ratio` 控制，默认 0.3 即 70% 到 130%。远程怪物额外使用自身扩散参数控制弹体随机偏移。

所有 `WeaponData` 都包含 `spread_degrees` 扩散属性。扩散值表示弹体相对瞄准方向的最大随机角度：0 表示完全精准，数值越高偏移范围越大。当前远程武器分别配置不同扩散，近战武器显式保持 0；仓库、背包和结算悬停详情都会显示该属性。

`GameWorld` 通过 `enhancement_stone_drop_chance = 0.10` 为每次实际击杀独立判定强化石；怪物自身 `weapon_drop_chance = 0.20` 独立判定武器。强化石品质为初级 40%、中级 30%、高级 20%、极品 10%。宝箱掉落类别权重为枪械 50%、强化石 30%、修复包 20%；普通、中级、高级、极品宝箱的单件高品质概率分别为 10%、30%、55%、75%，极品宝箱另保证至少 5 件高品质物品。

`GameWorld` 会记录进入战斗后的存活时间。正式撤离仍在 120 秒生成、300 秒标记，范围内停留 5 秒后按闪避结束战斗。除此之外，开局立即按 45%、30%、17%、8% 概率生成 2、3、4、5 个物资撤离点，但地图只显示已经进入摄像机探索格记录的点位；玩家在任一点连续停留 3 秒后按闪避打开 `SupplyExtractionPanel`，游戏暂停但不会结束战斗。面板卡片用“撤离收费”展示当前物品 20% 运费，悬停详情继续显示物品“出售价格”；关闭时会同步隐藏面板自身，避免后台继续吞掉 ESC。`GlobalInventory` 在单局内累计已送回价值，所有点位共享 1000 金币上限。

训练场提供 `clear_monsters()`、`respawn_monsters()` 和 `add_training_survival_time()` 接口给 HUD 训练场设置调用。清怪会先按训练怪物组清理，再清理 `monster_parent_path` 指向的怪物容器；重新生成会按当前配置追加一批新怪物，不会清空场上已有怪物；增加时间默认使用 `training_time_addition_seconds = 60`。

## 可调参数

所有核心数值都暴露为 `@export`：

- 移动：`max_speed`、`acceleration`、`friction`、`stop_threshold`
- 玩家移动能力：`sprint_speed_multiplier`、`sprint_energy_cost_per_second`、`dodge_energy_cost`、`dodge_distance`、`dodge_duration`、`knockback_decay`
- 玩家战斗反馈：`camera_path`、`fire_shake_per_recoil`、`damage_shake_per_damage`、`minimum_damage_shake`、`damage_interval`、`hit_effect_color`、`death_effect_color`
- 战斗相机：`shake_decay`、`max_shake_offset`、`max_shake_strength`
- 远程攻击：`projectile_scene`、`projectile_speed`、`projectile_damage`、`fire_cooldown`、`fallback_muzzle_distance`、`muzzle_block_check_radius`、`muzzle_block_collision_mask`、`projectile_parent_path`
- 近战攻击：`damage`、`cooldown_duration`、`active_duration`、`rotation_offset`
- 弹体：`speed`、`lifetime`、`max_distance`、`damage`、`destroy_on_hit`、`impact_force`
- 战斗属性：`max_health`、`current_health`、`max_energy`、`current_energy`、`energy_regeneration_per_second`、`infinite_health`、`infinite_energy`
- 装备：`ranged_slot_count`、`starting_ranged_weapons`、`starting_melee_weapon`
- 怪物：`max_health`、`current_health`、`weapon_drop_chance`、`attack_damage`、`toughness`、`attack_impact_force`、`move_speed`、`move_speed_random_multiplier_min`、`move_speed_random_multiplier_max`、`vision_range`、`attack_range`、`attack_cooldown`、`attack_cooldown_random_multiplier_min`、`attack_cooldown_random_multiplier_max`、`lose_target_range_multiplier`、`vision_requires_line_of_sight`、`vision_line_of_sight_collision_mask`、`vision_loss_grace_duration`、`target_memory_duration`、`target_prediction_time`、`target_prediction_max_distance`、`occlusion_break_forget_count`、`medium_memory_duration`、`long_term_region_radius`、`solid_wall_group`、`ai_update_interval`、`hide_when_simulation_inactive`、`disable_collision_when_simulation_inactive`、`tactical_search_near_radius`、`tactical_search_middle_radius`、`tactical_search_far_radius`、`search_points_before_ambush`、`patrol_route_path`、`patrol_route_loop`、`wander_radius`、`wander_speed_multiplier`、`pathfinding_enabled`、`pathfinding_cell_size`、`pathfinding_agent_radius`、`path_recalculation_min_interval`、`path_recalculation_max_interval`、`stuck_detection_time`、`knockback_decay`、`perception_component_path`、`movement_component_path`、`tactical_component_path`、`hit_effect_color`、`death_effect_color`
- 远程怪物：`projectile_scene`、`shoot_range`、`keep_distance`、`ranged_projectile_speed`、`ranged_projectile_damage`、`ranged_projectile_range`、`ranged_projectile_impact_force`、`ranged_projectile_spread_degrees`、`shoot_cooldown`、`shoot_cooldown_random_multiplier_min`、`shoot_cooldown_random_multiplier_max`、`muzzle_offset`、`line_of_sight_collision_mask`、`projectile_parent_path`
- 战斗地图：`grid_size`、`grid_extent`、`map_seed`、`base_floor_color`、`grid_color`、`axis_color`、`player_camera_path`、`exploration_cell_size`、`exploration_radius`、`exploration_update_interval`、`exploration_update_distance`、`boundary_wall_thickness`、`boundary_wall_color`、`extraction_spawn_time_seconds`、`extraction_map_marker_time_seconds`、`extraction_hold_duration_seconds`、`extraction_radius`、`extraction_spawn_edge_margin`、`extraction_spawn_min_distance_from_player`、`extraction_spawn_attempt_count`、`extraction_fill_color`、`extraction_ring_color`
- 强化石掉落：`enhancement_stone_drop_chance`、`enhancement_stone_base_sell_price`、`EnhancementRules.QUALITY_WEIGHTS`、`EnhancementRules.QUALITY_CONFIGS`；`enhancement_stone_min_modifier_count`、`enhancement_stone_max_modifier_count`、`enhancement_stone_negative_modifier_chance` 仅保留旧扩展调用兼容，品质规则不再读取它们。
- 敌人生成与加载：`monster_scene`、`monster_scenes`、`monster_spawn_count`、`monster_spawn_min_distance`、`monster_spawn_max_distance`、`monster_spawn_across_full_map`、`monster_spawn_edge_margin`、`monster_minimum_alive_count`、`monster_population_first_milestone_seconds`、`monster_population_five_minute_count`、`monster_population_second_milestone_seconds`、`monster_population_ten_minute_count`、`monster_replenish_interval`、`monster_replenish_batch_size`、`monster_spawn_variation_ratio`、`monster_parent_path`、`monster_simulation_manager_path`、`active_radius`、`sleep_hysteresis`、`update_interval`、`monsters_per_update`、`materializations_per_update`、`max_materialized_monsters`
- 掉落物：`drop_parent_path`、`weapon_drop_scene`、`weapon_drop_table`、`dropped_weapon_scatter_radius`、`monster_drop_launch_duration_min`、`monster_drop_launch_duration_max`、`monster_drop_launch_arc_height_min`、`monster_drop_launch_arc_height_max`、`weapon_data`、`pickup_radius`、`bob_amplitude`、`bob_speed`
- 环境生成：`environment_parent_path`、`obstacle_scenes`、`obstacle_spawn_count`、`obstacle_spawn_min_distance_from_player`、`obstacle_spawn_edge_margin`、`obstacle_spawn_min_spacing`、`obstacle_spawn_attempts_per_item`、`obstacle_scale_min`、`obstacle_scale_max`
- 角色占位属性：`stelle_max_health`、`stelle_max_energy`、`stelle_move_speed`、`caelus_max_health`、`caelus_max_energy`、`caelus_move_speed`、`silver_wolf_max_health`、`silver_wolf_max_energy`、`silver_wolf_move_speed`
- 武器数据：`weapon_type`、`sell_price`、`max_durability`、`current_durability`、`durability_cost_per_use`、`energy_cost`、`projectile_speed`、`bullet_range`、`ranged_damage`、`ranged_cooldown`、`spread_degrees`、`recoil_force`、`front_recoil_force`、`impact_force`、`melee_damage`、`melee_cooldown`、`melee_active_duration`
- 主菜单入口：`character_select_scene_path`、`WarehouseButton`、`ShopButton`、`ForgeButton`、`DEVELOPER_UNLOCK_SEQUENCE`
- 全局仓库：`SAVE_PATH`、`DEFAULT_RANGED_SLOT_COUNT`、`WEAPON_RESOURCE_PATHS`、`DEFAULT_BACKPACK_WEAPON_IDS`、`DEFAULT_RANGED_WEAPON_IDS`、`DEFAULT_MELEE_WEAPON_ID`、`DEFAULT_STARTING_COINS`
- 仓库与开发者面板：`panel_minimum_size`、`dialog_width`、`dialog_height`、`dialog_background_alpha`、`combat_panel_height`、`coin_step`、`enhancement_stone_grant_count`
- 商店：`automatic_refresh_interval_seconds`、`weapon_stock_count`、`resource_stock_count`、`normal_price_multiplier_minimum`、`normal_price_multiplier_maximum`、`second_hand_firearm_chance`、`second_hand_durability_consumption_minimum`、`second_hand_durability_consumption_maximum`、`second_hand_enhancement_cumulative_chances`、`second_hand_stone_compatibility_attempts`、`manual_refresh_base_cost`、`manual_refresh_cost_growth`、`gray_market_price_multiplier_minimum`、`gray_market_price_multiplier_maximum`、`gray_market_failure_limit`、`weapon_resource_paths`
- 锻造：`MAIN_WEAPON_VALUE_STEP`、`MAIN_WEAPON_MULTIPLIER_PER_STEP`、`BASE_COST_MULTIPLIER`、`SACRIFICE_WEAPON_DURABILITY_RATIO`、`COST_PER_RESTORED_DURABILITY`、`STONE_QUALITY_COSTS`、`STONE_UPGRADE_SUCCESS_RATE_PER_SACRIFICE`、`SACRIFICE_SLOT_COUNT`、`FORGE_ANIMATION_DURATION`、`FORGE_ANIMATION_ROTATIONS`、`panel_minimum_size`、`forge_slot_size`、`top_sacrifice_slot_upward_offset`、`bottom_sacrifice_slot_downward_offset`
- 物品 UI：`ItemCardView.STANDARD_CARD_SIZE`、`ItemCardView.BORDER_WIDTH`、`ItemCardView.CORNER_RADIUS`、`ItemCardView.HOVER_SCALE`、`ItemCardView.HOVER_DURATION`、`ItemCardView.CLICK_PRESS_SCALE`、`ItemCardView.CLICK_PRESS_DURATION`、`ItemCardView.CLICK_RELEASE_DURATION`、`ItemCardView.DRAG_SOURCE_SCALE`、`ItemCardView.DRAG_SOURCE_OPACITY`、`ItemCardView.DRAG_PREVIEW_START_SCALE`、`ItemCardView.DRAG_PREVIEW_PULSE_SCALE`、`ItemCardView.DRAG_PREVIEW_PULSE_DURATION`、`ItemCardView.DRAG_PREVIEW_TILT_RADIANS`、`ItemCardView.DISABLED_OVERLAY_COLOR`、`WeaponDurabilityBar.bar_height`、`WeaponDurabilityBar.medium_threshold`、`WeaponDurabilityBar.low_threshold`
- 宝箱：`loot_chest_spawn_count_min`、`loot_chest_spawn_count_max`、`loot_chest_near_building_chance`、`loot_chest_enclosed_building_weight`、`loot_chest_spawn_attempt_count`、`loot_chest_min_distance_from_player`、`loot_chest_clearance_radius`、`loot_chest_minimum_spacing`、`loot_chest_manual_drop_radius_min`、`loot_chest_manual_drop_radius_max`、`loot_chest_broken_drop_radius_min`、`loot_chest_broken_drop_radius_max`、`loot_chest_launch_duration_min`、`loot_chest_launch_duration_max`、`loot_chest_launch_arc_height_min`、`loot_chest_launch_arc_height_max`、`interaction_radius`、`minimum_hold_duration`、`LootChest.QUALITY_WEIGHTS`、`LootChest.QUALITY_CONFIGS`、`CHEST_HIGH_QUALITY_CHANCES`
- 物资撤离：`supply_extraction_count_weights`、`supply_extraction_hold_duration_seconds`、`supply_extraction_radius`、`supply_extraction_spawn_edge_margin`、`supply_extraction_min_distance_from_player`、`supply_extraction_spawn_attempt_count`、`COMBAT_SHIPPING_VALUE_LIMIT`、`COMBAT_SHIPPING_FEE_RATIO`
- 角色选择：`game_scene_path`、`main_menu_scene_path`、`stat_bar_maximum`、`speed_bar_maximum`
- 输入绑定：`SAVE_PATH`、`EVENT_TYPE_UNBOUND`、`_action_entries`
- HUD：`DROP_LIST_COMBAT_SUPPRESSION_DURATION`、`DEVELOPER_UNLOCK_SEQUENCE`、`ranged_slot_minimum_size`、`melee_slot_minimum_size`、`inventory_slot_minimum_size`、`inventory_click_press_scale`、`inventory_click_bounce_scale`、`inventory_click_press_duration`、`inventory_click_release_duration`、`inventory_drag_source_scale`、`inventory_drag_source_opacity`、`inventory_drag_preview_start_scale`、`inventory_drag_preview_pulse_scale`、`inventory_drag_preview_pulse_duration`、`inventory_drag_preview_tilt_radians`、`combat_developer_menu_half_size`、`toggle_inventory_action`、`toggle_large_map_action`、`pause_action`、`pickup_action`、`toggle_drop_list_action`、`extraction_action`、`nearby_drop_pickup_range`、`max_nearby_drop_buttons`、`nearby_drop_refresh_interval`、`nearby_drop_expanded_height`、`nearby_drop_collapsed_height`、`main_menu_scene_path`
- 按键绑定面板：`title_text`、`list_minimum_height`
- 小地图和大地图：`game_world_path`、`player_path`、`display_mode`、`local_view_radius`、`local_redraw_interval`、`full_redraw_interval`、`redraw_player_move_distance`、`fallback_map_half_size`、`minimap_background_color`、`minimap_border_color`、`obstacle_color`、`fog_overlay_color`、`player_color`、`extraction_marker_color`、`supply_extraction_marker_color`、`player_marker_radius`、`extraction_marker_radius`、`navigation_marker_color`、`navigation_line_width`、`navigation_dash_length`、`navigation_dash_gap`、`navigation_marker_radius`、`navigation_marker_cancel_radius`、`allow_navigation_marker_input`

调参优先在 Godot 检查器中完成，只有新增规则或默认值需要沉淀时再修改脚本。

## 扩展约定

- 敌人、可破坏物或训练靶如果需要接收伤害，应实现 `apply_damage(damage: float, source: Node)`。需要支持击退时，可从 `source.get_impact_force()` 和 `source.get_knockback_direction()` 读取冲击力与方向。
- 可被玩家近战清除的敌方弹体应实现 `destroy_by_melee(source: Node)`，并放在 `EnemyProjectile` 物理层上。
- 新武器优先复用 `RangedAttackComponent` 或 `MeleeAttackComponent`，通过替换弹体场景、枪口节点和参数形成差异。
- 新角色优先复用现有组件，根节点只保留聚合逻辑，避免把移动、攻击、输入全部塞进同一个脚本。
- 聚合脚本为了保持低耦合，可以通过 `NodePath` 获取组件并保持动态类型；从动态组件方法接收返回值时，局部变量必须显式标注类型，例如 `var movement_direction: Vector2 = ...`，避免 Godot 无法推断返回类型。
- GDScript 中每个 `var`、`@export var`、`@onready var` 变量定义前必须有独立注释，说明变量用途、数据含义、默认值原因、推荐取值范围和修改影响；循环变量也应在循环前说明范围和影响。
