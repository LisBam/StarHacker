# 游戏基础框架

本文档记录《崩坏：量子骇袭》的入口流程、玩家控制框架和可扩展点，用于后续长期维护。

## 场景入口

- `res://scenes/ui/main_menu.tscn` 是项目主场景，由 `project.godot` 的 `run/main_scene` 指向。
- 主菜单脚本 `res://scripts/ui/main_menu.gd` 通过 `character_select_scene_path` 加载独立角色选择场景，默认第一行按钮文案为“骇入”。主菜单同时保留“训练场”按钮，两者都会先写入当前模式，再进入 `res://scenes/ui/character_select.tscn`。
- `res://scenes/ui/character_select.tscn` 是进入战斗前的角色选择场景。玩家在左侧选择“星”“穹”“银狼”，右侧会显示角色名称、定位、说明、固定生命上限、固定能量上限、固定速度和技能占位信息，点击确认后进入 `res://scenes/game/game_world.tscn`。
- 主菜单提供“设置”入口，设置首页包含全局 Master 主音量和“按键绑定”入口；左下角固定提供“仓库”按钮，打开后可在纯永久仓库模式与仓库/背包联合模式间切换，出售安全物品并通过拖拽管理仓库、背包和装备槽。
- 主菜单依次输入 `LISBAM` 会显示隐藏开发者菜单，当前提供“一键获取所有武器”“一键增加 1000 金币”“一键减少 1000 金币”。开发者武器直接发放到永久仓库，金币最低限制为 0。
- `res://scripts/game/session_state.gd` 通过 `project.godot` 自动加载为 `SessionState`，负责保存本次进入的模式和角色，避免把入口参数写进场景路径。
- `res://scripts/game/global_inventory.gd` 通过 `project.godot` 自动加载为 `GlobalInventory`，分别保存随身背包、永久仓库、装备槽、局外金币、获得时间、上次撤离优先级和战斗结算，并写入 `user://global_inventory.json`。
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
- `pickup_nearby`：F，快速拾取玩家附近最近的一件地面掉落武器
- `toggle_drop_list`：G，常驻开启或关闭附近掉落物列表自动显示

`InputBindings` 会在项目启动时记录 InputMap 默认值，并从 `user://input_bindings.cfg` 读取玩家自定义绑定。主菜单设置和暂停设置都会提供“按键绑定”页面，玩家点击操作对应按钮后，按下新的键盘键或鼠标按钮即可覆盖该操作的主绑定；多个可配置操作允许绑定到同一个输入事件，用于支持一键多用。未绑定状态会写入 `EVENT_TYPE_UNBOUND` 并记录到显式未绑定缓存，玩家输入层和 HUD 会识别该状态，不会再启用默认物理键兜底。点击“恢复默认”会把所有可配置操作恢复到项目默认输入。`PlayerInputComponent` 仍保留物理键兜底，但只在对应 InputMap 动作缺失，或事件为空且不是玩家显式未绑定时启用，因此玩家完成自定义绑定后，旧默认按键不会继续触发同一操作。

数字键切换通过 `max_direct_ranged_slots` 控制可直接访问的远程槽数量，默认值为 2。扩展远程槽位时，需要同步提高 `EquipmentComponent.ranged_slot_count` 和 `PlayerInputComponent.max_direct_ranged_slots`。

## 组件职责

- `PlayerInputComponent`：读取移动向量、鼠标瞄准方向、远程攻击状态、近战攻击请求、疾跑状态和闪避请求。
- `TopDownMovementComponent`：根据方向向量、速度倍率和外部击退速度更新 `CharacterBody2D.velocity`，并执行 `move_and_slide()`。
- `RangedAttackComponent`：按冷却生成弹体，弹体从 `AimPivot/Muzzle` 位置发射，并把武器射程、伤害、速度和冲击力写入弹体。发射前会检测角色到枪口的线段和枪口圆形范围是否被环境墙体阻挡，避免贴墙时把子弹生成到墙体内部。
- `MeleeAttackComponent`：在短时间内开启朝向鼠标方向的 `Area2D` 命中框，支持命中去重、近战冲击力和敌方子弹消除。
- `PlayerProjectile`：按方向移动，按寿命或最大距离自动销毁，通过射线提前检测怪物和环境墙体，命中可调用目标的 `apply_damage(damage, source)`。
- `EnemyProjectile`：远程怪物发射的敌方弹体，会命中玩家或被环境阻挡，也能被玩家近战命中框消除。弹体内部有一次性命中锁，扫线检测和 `body_entered` 即使同帧触发，也只会结算一次伤害和击退。
- `CombatStatsComponent`：维护玩家生命、能量、能量恢复和死亡状态，武器成功使用后由玩家控制器调用 `spend_energy()` 扣除能量，生命降到 0 时只派发一次 `died` 信号。
- `InventoryComponent`：作为玩家节点上的背包能力代理，默认把增删、移动和查询转发给 `GlobalInventory`；自动加载缺失时才回退场景内本地数组。
- `EquipmentComponent`：作为玩家节点上的装备能力代理，默认把远程槽、当前槽和近战槽操作转发给 `GlobalInventory`，不直接执行攻击。
- `WeaponSlotControl`：显示单个武器槽或背包物品槽，负责拖拽数据、投放校验、白色冷却遮罩绘制和武器悬浮提示；冷却比例未变化时不会重复重绘，不直接修改装备数据。
- `InventoryDropArea`：接收拖到背包空白区域的武器拖拽数据，并转发给 HUD 按背包末尾投放处理。
- `InputBindings`：全局输入绑定管理器，以 AutoLoad 单例存在，不声明同名 `class_name`，保存可配置动作、默认事件、玩家自定义事件和恢复默认逻辑，直接写入 Godot `InputMap`，允许多个动作共享同一个输入事件。
- `KeyBindingPanel`：复用型按键绑定 UI，主菜单设置和暂停设置的按键绑定页面都会动态创建它，用于捕获下一次键盘或鼠标输入并调用 `InputBindings.rebind_action()`。
- `CombatCamera`：玩家子节点上的战斗相机，关闭 Camera2D 位置平滑并使用物理帧回调跟随玩家，避免物理移动和渲染相机不同步造成移动抖动；屏幕震动只修改相机 `offset`，不会改变玩家或相机节点真实位置。
- `CombatHud`：除原战斗 HUD、背包和暂停职责外，负责调用全局背包完成撤离成功、死亡和主动退出结算，并在滚动结算界面完整展示获得、保留和丢失物品。
- `MiniMapControl`：读取 GameWorld 的地图、探索、撤离点和玩家导航标点；M 键大地图允许左键设置或点中已有标点取消，局部小地图与完整地图都会绘制玩家到标点的黄色指示线。
- `WarehousePanel`：主菜单局外仓库 UI，只调用 `GlobalInventory`。纯仓库模式仅显示永久仓库、局外金币和出售按钮；展开背包后，上方保留仓库，下方左侧显示装备栏、右侧显示随身背包，并支持点击快捷转移、拖拽转移、列表排序、装备替换和卸下。
- `StorageItemControl`：局外物品交互控件，统一生成摘要、完整悬停属性、快捷点击和跨容器拖拽数据，不直接修改物品所有权。
- `StorageDropArea`：仓库与随身背包共用的两列网格拖放区域，只校验拖拽协议并把目标容器交给 `WarehousePanel`。
- `EquipmentStorageSlotControl`：局外装备槽拖拽控件，校验远程或近战武器类型，支持装备与仓库、背包以及远程装备槽之间的双向拖拽。
- `DeveloperMenu`：隐藏开发者调试面板，通过 `GlobalInventory` 公开接口发放武器和调整金币。
- `GlobalInventory`：全局物品所有权服务，使用唯一记录区分同类重复武器，分别维护永久仓库、随身背包、装备、局外金币、临时拖拽记录、本局快照和存档。正式战斗失败只随机保留约 20% 随身背包物品，永久仓库和局外金币不进入战斗；成功撤离会把随身背包全部转入永久仓库。
- `MonsterSimulationManager`：集中注册整图怪物，分批启用玩家加载半径内的 AI、物理、碰撞和绘制，并让远距离怪物保持原坐标休眠。
- `BasicMonster`：基础怪物聚合入口，维护血量、攻击、韧性、个体数值随机和组件配置，通过子组件组合索敌与移动能力，并保留近战、击退和继承扩展接口。
- `EnemyPerceptionComponent`：维护视野射线、目标记忆、视野丢失缓冲、遮挡次数、最后线索预测、障碍背后锚点、范围搜查和彻底脱战，不执行移动或攻击。
- `EnemyMovementComponent`：维护预设巡逻、出生点游荡、A* 路径缓存、局部绕障、空路径重试节流、卡住恢复、击退和实际移动，不读取玩家实时位置。
- `RangedMonster`：远程测试怪物，继承基础怪物受击、韧性、索敌记忆、绕障、个体移动差异和游荡逻辑，只有基础索敌确认玩家可见且射击线无遮挡时才保持距离并按个体射击冷却差异发射敌方子弹。
- `WeaponDrop`：地面武器掉落物，保存单把武器资源并加入 `weapon_drops` 组，HUD 按距离扫描后生成附近掉落列表；拾取成功后会把同一个武器资源加入背包并释放掉落物节点。
- `CombatBurstEffect`：代码绘制的短促战斗爆发特效，用于玩家和怪物受击、死亡反馈；默认挂到当前场景根节点，保证死亡节点释放后特效仍能播放完成。
- `SessionState`：入口会话状态，保存当前模式和当前角色，供主菜单、GameWorld 和训练场角色切换复用。
- `GameWorld`：战斗承载脚本，生成大型网格地图、整图敌人分布、正式模式敌人补充、导航标点、墙体建筑、撤离点和掉落物，并提供共享 A* 路径查询接口。

## 武器与装备

武器由 `res://scripts/data/weapon_data.gd` 定义，默认资源位于 `res://data/weapons/`：

- `quantum_pistol.tres`：量子手枪，远程武器，低能耗、稳定射速。
- `pulse_rifle.tres`：脉冲步枪，远程武器，高射速、高能耗。
- `phase_blade.tres`：相位刃，近战武器，右键消耗能量开启近战命中框，默认前坐力为 140。
- `ion_smg.tres`：离子冲锋枪，远程测试武器，高射速、低单发伤害。
- `rail_cannon.tres`：磁轨炮，远程测试武器，高伤害、长冷却。
- `scatter_blaster.tres`：散射爆能枪，远程测试武器，中等射速和中等消耗。
- `quantum_dagger.tres`：量子短刃，近战测试武器，低消耗、短冷却，默认前坐力为 140。

当前通用玩家预制体默认装备两把远程武器和一把近战武器：

- 远程槽 1：量子手枪
- 远程槽 2：脉冲步枪
- 近战槽：相位刃

远程攻击流程为：玩家输入左键 -> `PlayerController` 读取当前远程武器 -> 检查 `CombatStatsComponent` 能量是否足够 -> `RangedAttackComponent.try_attack(direction, weapon_data)` 成功生成弹体 -> 弹体获得武器 `bullet_range`、`impact_force`、速度和伤害 -> 玩家受到 `recoil_force` 反方向后坐力和可选 `front_recoil_force` 正方向前坐力 -> 扣除武器 `energy_cost`。

近战攻击流程为：玩家输入右键 -> `PlayerController` 读取当前近战武器 -> 检查能量是否足够 -> `MeleeAttackComponent.try_attack(direction, weapon_data)` 成功开启命中框 -> 玩家按 `front_recoil_force` 向攻击方向获得前坐力反馈 -> 命中怪物时按武器 `impact_force` 击退，命中敌方子弹时直接消除 -> 扣除武器 `energy_cost`。

战斗反馈流程为：玩家成功使用武器后，`PlayerController` 会按武器 `recoil_force * fire_shake_per_recoil` 和 `front_recoil_force * fire_shake_per_recoil * 0.5` 向 `CombatCamera` 累加屏幕震动；玩家受到伤害时，会先检查 `damage_interval`，默认受伤后的 0.2 秒内忽略新的伤害、击退和受伤震动，再按伤害值和 `minimum_damage_shake` 计算本次受击震动。玩家和怪物受击时生成短促 `CombatBurstEffect`，生命归零时生成更大的死亡爆发特效。

武器新增四项控制相关属性：`bullet_range` 仅远程武器使用，用于覆盖弹体最大飞行距离，未配置时兜底为 340 像素；`recoil_force` 表示开火后坐力，会把玩家向射击反方向推开；`front_recoil_force` 表示前坐力，会把玩家向攻击方向推开，适合近战突进或特殊枪械反馈；`impact_force` 表示命中冲击力，怪物会按自身韧性折算击退强度。当前远程测试武器采用短射程默认值，避免玩家在大地图上过早跨屏清怪：手枪 340、步枪 420、冲锋枪 280、磁轨炮 520、散射爆能枪 260。

移动能力流程为：玩家按住 Shift 且存在移动输入时，`PlayerController` 每帧按 `sprint_energy_cost_per_second * delta` 扣除能量，并把本帧移动速度倍率提升到 `sprint_speed_multiplier`；玩家按下 Space 且当前存在移动输入时，先扣除 `dodge_energy_cost`，再按 `dodge_distance / dodge_duration` 朝当前移动方向突进。背包打开时战斗输入被锁定，疾跑和闪避也不会触发能量消耗。

战斗 HUD 顶部中心显示进入战斗后的存活时间，格式为 `mm:ss`，例如 `02:05` 表示已存活 2 分 5 秒。计时文本只在整秒变化时写入，撤离提示和战斗输入启用状态只在状态变化时同步，避免 HUD 每帧重复刷新相同内容。底部中心保持紧凑尺寸以降低视野遮挡：当前角色名、生命条和能量条在武器栏上方，远程武器槽和近战武器槽在下方。右上角小地图只显示玩家周围一段范围，并显示玩家、墙体、建筑和已标记撤离点，不显示怪物。使用武器后，对应武器槽会绘制白色半透明冷却遮罩，冷却刚开始时覆盖整个槽位，随后随 `get_cooldown_ratio()` 返回值降低而缩短；冷却比例不变时槽位不会重复请求重绘。

按 M 会打开完整大地图。大地图使用正方形显示区域，显示整张战斗地图、玩家位置、墙体、建筑和已标记撤离点，并读取 `GameWorld` 的探索格缓存绘制迷雾。左键点击空白地图会设置或替换唯一导航标点；左键点中已有标点会取消。M 键大地图和右上角小地图都会绘制玩家到标点的黄色指示线，标点超出局部小地图范围时线段指向地图边缘。大地图打开时仍会锁定战斗输入。

背包通过 E 键打开或关闭。背包打开时，`CombatHud` 会通过 `PlayerInputComponent.set_combat_input_enabled(false)` 禁用射击、近战和切换武器，避免拖拽装备时误触战斗输入；WASD 移动不受影响。

局内背包界面采用左右分栏：左侧是当前装备，右侧是随身物品。数据不再属于当前 Player 场景，而是通过 `InventoryComponent` 与 `EquipmentComponent` 代理到 `GlobalInventory`；随身背包会带入战斗并参与失败损失，永久仓库不会在局内背包中出现，也不会因玩家死亡或主动退出而丢失。

装备和背包使用单实例流转规则：一把武器资源同一时间只能存在于一个位置。右侧背包武器拖到左侧装备槽后，会从背包列表移除；如果目标装备槽已有武器，旧武器会回到原背包位置。左侧装备拖回右侧背包的空白区域或任意背包物品上都会卸下并插入背包；背包武器之间拖拽会移动原物品顺序，不会复制资源；远程装备槽之间拖拽会移动或交换同一个武器引用。

局外仓库与随身背包是两个独立容器。仓库和背包都使用每行两个物品的网格布局，不显示上下调整按钮。纯仓库模式只显示永久物品，允许查看完整属性并按武器 `sell_price` 出售为局外金币；金币不会带入战斗。展开背包后，上方为永久仓库，下方为装备栏和随身背包：点击仓库物品会快速装入背包，点击背包物品会快速存回仓库；拖拽物品可以在仓库、背包、远程装备槽和近战装备槽之间原子交换。装备栏不提供“装1”“装2”或卸下按钮，所有装备调整统一使用拖拽。

永久仓库首次建立或从旧存档迁移时默认按获得时间从新到旧排列，之后会保存玩家手工调整的列表顺序。成功撤离时，本局随身背包全部写入新的撤离编号并自动转入永久仓库前方；上次撤离物品显示“上次撤离”标记并整体排在原有仓库物品之前。存档版本 2 分别保存 `warehouse`、`backpack`、装备槽与 `coins`；读取没有 `warehouse` 字段的旧存档时，会把旧版混合背包物品安全迁移到永久仓库。

地面掉落物使用同一套武器资源流转规则。怪物死亡时，`GameWorld` 会读取该怪物的 `weapon_drop_chance`，默认 0.03 表示 3% 概率从 `weapon_drop_table` 随机复制一把武器并生成 `WeaponDrop`。掉落物默认保持静止，不再播放上下浮动动画。玩家靠近地面武器时，HUD 左侧会显示附近掉落物面板；标题始终表示附近存在可拾取掉落物，按钮列表按距离从近到远显示武器名称。列表按钮不显示名称后的距离数字，距离只用于内部排序和 F 快速拾取最近目标。HUD 会按固定刷新间隔扫描附近掉落物，并用实例、名称和位置组成的签名判断是否需要重建按钮，避免从一个掉落物移动到另一个掉落物时继续显示旧列表。点击列表项会在鼠标按下时立即拾取指定武器。按 F 会拾取最近的一件，即使掉落物列表被关闭也可使用。鼠标悬停或点击掉落物面板时，HUD 会临时禁用射击、近战和切枪输入，避免点击拾取时触发开火。按 G 会常驻开启或关闭掉落物按钮列表；关闭后只隐藏按钮列表并保留标题，靠近掉落物时仍能看到标题提示，用于降低战斗中误触 UI 的概率。背包打开时，把右侧背包武器或左侧已装备武器拖到背包面板外，会从原位置移除该武器并在玩家附近生成地面掉落物；如果世界掉落生成失败，系统会把武器回滚到原背包位置或原装备槽。

## 暂停与设置

ESC 会优先关闭当前打开的交互界面；没有背包或大地图时打开暂停菜单。正式战斗点击“返回主菜单”会先按失败规则结算：随身背包物品随机保留约 20%，其余约 80% 从背包移除，然后显示完整保留/丢失列表；永久仓库和局外金币完全不参与该结算。结算窗口下方按钮统一显示“确定”，点击后返回主菜单。操作系统关闭窗口时，`GlobalInventory` 也会在正式战斗活动期间执行同一失败结算并立即保存。

玩家生命值降到 0 后，`CombatStatsComponent.died` 会通知 `CombatHud`。正式战斗随机保留约 20% 随身背包物品，已装备物品、永久仓库物品和局外金币不参与“背包内 80% 掉落”规则；滚动结算框会逐项展示保留和丢失物品。训练场死亡或从暂停菜单返回主菜单时都不会打开物品结算窗口，也不会修改永久仓库、背包或金币。

暂停设置和主菜单设置共用同一条 Master 音量规则：滑条范围为 0 到 100，0 会静音 Master 总线，大于 0 时使用 `linear_to_db()` 写入音量。

暂停设置和主菜单设置都采用分页结构。设置首页只显示主音量、“按键绑定”入口和返回按钮；点击“按键绑定”后切换到独立按键绑定页面，按该页“返回”只回到设置首页，不会直接关闭设置面板。绑定面板修改的是全局 `InputMap`，因此在主菜单中修改的按键会影响后续进入战斗后的玩家操作，在暂停菜单中修改的按键会立即影响当前战斗。按键绑定保存到 `user://input_bindings.cfg`，下次启动游戏时自动恢复；多个操作可以保存为相同按键或鼠标按钮。

训练场暂停菜单额外提供“训练场设置”面板。正式“骇入”模式会隐藏该入口，不能打开训练场专属功能。训练场设置包含“清空场上怪物”“重新生成怪物”“切换角色”三个按钮，以及“无限能量”“无限血量”两个开关。无限能量通过 `CombatStatsComponent.set_infinite_energy()` 生效，开启后武器、疾跑和闪避消耗都不会降低能量；无限血量通过 `CombatStatsComponent.set_infinite_health()` 生效，开启后怪物攻击不会降低玩家生命；切换角色通过 `GameWorld.switch_character(character_id)` 生效，并按固定配置刷新当前角色的生命上限、能量上限和移动速度。

## 怪物与训练场

当前怪物场景包括 `res://scenes/enemies/basic_monster.tscn` 和 `res://scenes/enemies/ranged_monster.tscn`。怪物使用 `CharacterBody2D`，碰撞层为 2，玩家弹体和近战命中框通过碰撞层 2 命中怪物。

敌人加载休眠、实心墙体视野、独立三层记忆、四段警戒、平面搜查、移动寻路与巡逻配置统一记录在 `res://docs/enemy_ai.md`。当前没有怪物情报共享：一只怪物发现玩家不会唤醒或改变其他怪物索敌状态。本节只保留全局框架摘要与检查器参数索引。

基础怪物属性包括：

- `max_health` / `current_health`：血量。
- `weapon_drop_chance`：死亡掉落武器概率，默认 0.03。每只怪物可单独调节，0 表示不掉落，1 表示必定掉落。
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
- `squad_region_radius`、`coordination_update_interval`、`intelligence_relay_max_hops`、`role_rotation_interval`：旧场景兼容字段，当前不参与队友发现、级联传播或人数职能分配。
- `tactical_search_near_radius`、`tactical_search_middle_radius`、`tactical_search_far_radius`、`tactical_blockade_radius_multiplier`、`melee_search_radius_multiplier`、`ranged_search_radius_multiplier`、`search_fan_half_angle_degrees`、`wall_corner_clearance`、`route_prediction_time`、`lane_segment_spacing`、`tactical_point_arrive_distance`、`tactical_point_wait_min`、`tactical_point_wait_max`、`search_points_before_ambush`、`tactical_destination_attempts`：三层扇形搜查、分段卡位、外侧迂回与静止伏击参数。
- `patrol_route_path`、`patrol_route_loop`、`wander_radius`、`wander_speed_multiplier`、`wander_arrive_distance`、`wander_wait_min`、`wander_wait_max`：无目标巡逻参数。配置路线容器时按其 Node2D 子节点顺序巡逻，脱战后从最近路线点返程；未配置路线时围绕出生点随机游荡。
- `avoidance_probe_distance`、`avoidance_angle_step_degrees`、`avoidance_candidate_count`：局部绕障参数。怪物追击或游荡时会先尝试直线方向，若前方被墙体挡住，则按每只怪物随机生成的左右偏好寻找可移动方向。
- `pathfinding_enabled`、`pathfinding_cell_size`、`pathfinding_agent_radius`、`path_recalculation_min_interval`、`path_recalculation_max_interval`、`path_destination_refresh_distance`、`path_waypoint_arrive_distance`、`path_random_goal_radius`、`path_max_point_count`：网格寻路参数。怪物会检测自身到目标点的中心线是否被环境阻挡，一旦追击点、遮挡物背后搜查点或巡逻点被墙体建筑隔开，就提前向 `GameWorld.find_navigation_path()` 请求无斜向穿角的 A* 路径，而不是先直线贴墙移动。默认寻路格子为 32 像素、代理半径为 18 像素，和当前怪物碰撞半径接近，可保留建筑入口通行能力；路径终点随机偏移只在目标可见时使用，固定搜查点和巡逻点不会随机漂移。空路径会等待重算间隔再请求，避免每个物理帧重复执行失败寻路。
- `stuck_detection_time`、`stuck_minimum_movement`：卡住检测参数。怪物持续有移动意图但实际位移过小时，会翻转局部绕障偏好并清空缓存路径，下一帧重新请求路径。
- `knockback_decay`：击退衰减速度，控制怪物被玩家武器命中后滑退多久。
- `hit_effect_color`、`death_effect_color`：怪物受击和死亡特效颜色，只影响视觉反馈，不影响战斗数值。

远程怪物额外属性包括 `projectile_scene`、`shoot_range`、`keep_distance`、`ranged_projectile_speed`、`ranged_projectile_damage`、`ranged_projectile_range`、`ranged_projectile_impact_force`、`shoot_cooldown`、`shoot_cooldown_random_multiplier_min`、`shoot_cooldown_random_multiplier_max`、`muzzle_offset`、`line_of_sight_collision_mask` 和 `projectile_parent_path`。远程怪物只有在自身感知确认玩家可见、玩家进入射击距离且实心墙体视线无遮挡时才会开火；`keep_distance` 只用于本怪物保持安全距离，不会触发队友卡位或迂回。每只远程怪物仍会随机射击冷却倍率和初始冷却，避免同批怪物同步开火。

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

`GameWorld` 通过 `obstacle_scenes`、`obstacle_spawn_count`、`obstacle_spawn_min_distance_from_player`、`obstacle_spawn_edge_margin`、`obstacle_spawn_min_spacing`、`obstacle_spawn_attempts_per_item`、`obstacle_scale_min` 和 `obstacle_scale_max` 控制环境生成。默认环境生成更密集，并会对每个预制体应用随机旋转和随机等比缩放，使同类墙体和建筑出现不同体积。墙体和建筑碰撞层为第 5 层，玩家检测第 5 层，怪物检测玩家层和第 5 层，玩家弹体检测怪物层和第 5 层，敌方弹体检测玩家层和第 5 层，因此墙体和建筑能阻挡玩家、怪物和所有子弹。生成成功后，GameWorld 会缓存环境碰撞矩形，供小地图和大地图绘制墙体和建筑。

`GameWorld` 会按 `exploration_cell_size` 和 `exploration_radius` 记录玩家探索过的地图格子。该数据只由地图 UI 读取，不影响怪物索敌和碰撞。探索记录不会每帧重算，而是按 `exploration_update_interval` 定期检查，并在玩家移动超过 `exploration_update_distance` 时提前刷新；只有新增探索格时才递增探索版本号，供大地图复用迷雾查询缓存。调整格子尺寸会影响迷雾精度和缓存数量；调整探索半径会影响玩家走过后大地图可见区域大小。`GameWorld.find_navigation_path()` 会按寻路格尺寸和代理半径缓存整张地图的 A* 网格，供怪物在目标被墙体或建筑阻挡时自动绕路；寻路网格禁用斜向移动，避免路径从墙角缝隙穿过。环境障碍在地图生成完成后保持静态，因此缓存网格可以被所有怪物复用；如果后续加入可破坏墙体或动态门，需要在障碍变化后清空导航缓存和小地图障碍版本。

`GameWorld` 默认使用 `monster_spawn_across_full_map = true` 在整张地图可用区域均匀生成 160 名敌人；所有候选点必须位于 `monster_spawn_min_distance` 默认 900 像素之外、避开环境障碍并保留 `monster_spawn_edge_margin`。正式模式中，存活敌人数低于 `monster_minimum_alive_count` 默认 144 时，每隔 2 秒检查并按每批 16 名补充。训练场清怪后不会自动补充，手动“重新生成怪物”使用当前批次数量。

整图敌人生成后统一注册到 `MonsterSimulationManager`。默认只有玩家 2400 像素范围内的怪物加载 AI、碰撞和绘制；已激活怪物离开 2800 像素后休眠。管理器每 0.1 秒检查最多 40 名怪物，160 名怪物约 0.4 秒完成一轮。休眠怪物仍存在于远处并计入存活数量，但不会执行任何 AI 或物理逻辑。加载范围内怪物的感知、射线、绕障和寻路也按 `ai_update_interval` 默认 0.1 秒错峰更新，移动保持逐帧执行。

每只随机生成敌人在加入场景树前分别生成尺寸倍率和属性倍率，范围由 `monster_spawn_variation_ratio` 控制，默认 0.3 即 70% 到 130%。尺寸直接影响视觉和碰撞缩放；基础属性倍率作用于生命、伤害、冲击力、移速、视野和攻击节奏，远程怪物还会同步波动射击距离、保持距离、弹体伤害、弹体冲击力和射击冷却。

`GameWorld` 通过 `drop_parent_path`、`weapon_drop_scene`、`weapon_drop_table` 和 `dropped_weapon_scatter_radius` 控制地面武器生成。怪物死亡掉落会从掉落表复制武器模板，背包拖出丢弃会直接使用背包里的同一个武器资源；落点会尽量避开环境障碍并限制在地图范围内。

`GameWorld` 会记录进入战斗后的存活时间，玩家死亡后不再增加。默认存活 120 秒时生成撤离点，300 秒时标记到地图。玩家在撤离范围内连续停留 `extraction_hold_duration_seconds` 默认 5 秒后按闪避确认撤离。成功撤离会调用 `GlobalInventory.complete_combat_run_success()`：保留装备，把随身背包全部转入永久仓库，标记上次撤离携带记录，统计本局快照之后新增的物品，并先显示“撤离成功”收益结算界面；玩家确认后才返回主菜单。

训练场提供 `clear_monsters()` 和 `respawn_monsters()` 两个接口给 HUD 训练场设置调用。清怪会先按训练怪物组清理，再清理 `monster_parent_path` 指向的怪物容器；重新生成会按当前配置追加一批新怪物，不会清空场上已有怪物。

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
- 远程怪物：`projectile_scene`、`shoot_range`、`keep_distance`、`ranged_projectile_speed`、`ranged_projectile_damage`、`ranged_projectile_range`、`ranged_projectile_impact_force`、`shoot_cooldown`、`shoot_cooldown_random_multiplier_min`、`shoot_cooldown_random_multiplier_max`、`muzzle_offset`、`line_of_sight_collision_mask`、`projectile_parent_path`
- 战斗地图：`grid_size`、`grid_extent`、`map_seed`、`base_floor_color`、`grid_color`、`axis_color`、`exploration_cell_size`、`exploration_radius`、`exploration_update_interval`、`exploration_update_distance`、`boundary_wall_thickness`、`boundary_wall_color`、`extraction_spawn_time_seconds`、`extraction_map_marker_time_seconds`、`extraction_hold_duration_seconds`、`extraction_radius`、`extraction_spawn_edge_margin`、`extraction_spawn_min_distance_from_player`、`extraction_spawn_attempt_count`、`extraction_fill_color`、`extraction_ring_color`
- 敌人生成与加载：`monster_scene`、`monster_scenes`、`monster_spawn_count`、`monster_spawn_min_distance`、`monster_spawn_max_distance`、`monster_spawn_across_full_map`、`monster_spawn_edge_margin`、`monster_minimum_alive_count`、`monster_replenish_interval`、`monster_replenish_batch_size`、`monster_spawn_variation_ratio`、`monster_parent_path`、`monster_simulation_manager_path`、`active_radius`、`sleep_hysteresis`、`update_interval`、`monsters_per_update`
- 掉落物：`drop_parent_path`、`weapon_drop_scene`、`weapon_drop_table`、`dropped_weapon_scatter_radius`、`weapon_data`、`pickup_radius`、`bob_amplitude`、`bob_speed`
- 环境生成：`environment_parent_path`、`obstacle_scenes`、`obstacle_spawn_count`、`obstacle_spawn_min_distance_from_player`、`obstacle_spawn_edge_margin`、`obstacle_spawn_min_spacing`、`obstacle_spawn_attempts_per_item`、`obstacle_scale_min`、`obstacle_scale_max`
- 角色占位属性：`stelle_max_health`、`stelle_max_energy`、`stelle_move_speed`、`caelus_max_health`、`caelus_max_energy`、`caelus_move_speed`、`silver_wolf_max_health`、`silver_wolf_max_energy`、`silver_wolf_move_speed`
- 武器数据：`weapon_type`、`sell_price`、`energy_cost`、`projectile_speed`、`bullet_range`、`ranged_damage`、`ranged_cooldown`、`recoil_force`、`front_recoil_force`、`impact_force`、`melee_damage`、`melee_cooldown`、`melee_active_duration`
- 主菜单入口：`character_select_scene_path`、`WarehouseButton`、`DEVELOPER_UNLOCK_SEQUENCE`
- 全局仓库：`SAVE_PATH`、`DEFAULT_RANGED_SLOT_COUNT`、`WEAPON_RESOURCE_PATHS`、`DEFAULT_BACKPACK_WEAPON_IDS`、`DEFAULT_RANGED_WEAPON_IDS`、`DEFAULT_MELEE_WEAPON_ID`、`DEFAULT_STARTING_COINS`
- 仓库与开发者面板：`panel_minimum_size`、`coin_step`
- 角色选择：`game_scene_path`、`main_menu_scene_path`、`stat_bar_maximum`、`speed_bar_maximum`
- 输入绑定：`SAVE_PATH`、`EVENT_TYPE_UNBOUND`、`_action_entries`
- HUD：`DROP_LIST_COMBAT_SUPPRESSION_DURATION`、`ranged_slot_minimum_size`、`melee_slot_minimum_size`、`inventory_slot_minimum_size`、`toggle_inventory_action`、`toggle_large_map_action`、`pause_action`、`pickup_action`、`toggle_drop_list_action`、`extraction_action`、`nearby_drop_pickup_range`、`max_nearby_drop_buttons`、`nearby_drop_refresh_interval`、`main_menu_scene_path`
- 按键绑定面板：`title_text`、`list_minimum_height`
- 小地图和大地图：`game_world_path`、`player_path`、`display_mode`、`local_view_radius`、`local_redraw_interval`、`full_redraw_interval`、`redraw_player_move_distance`、`fallback_map_half_size`、`minimap_background_color`、`minimap_border_color`、`obstacle_color`、`fog_overlay_color`、`player_color`、`extraction_marker_color`、`player_marker_radius`、`extraction_marker_radius`、`navigation_marker_color`、`navigation_line_width`、`navigation_marker_radius`、`navigation_marker_cancel_radius`、`allow_navigation_marker_input`

调参优先在 Godot 检查器中完成，只有新增规则或默认值需要沉淀时再修改脚本。

## 扩展约定

- 敌人、可破坏物或训练靶如果需要接收伤害，应实现 `apply_damage(damage: float, source: Node)`。需要支持击退时，可从 `source.get_impact_force()` 和 `source.get_knockback_direction()` 读取冲击力与方向。
- 可被玩家近战清除的敌方弹体应实现 `destroy_by_melee(source: Node)`，并放在 `EnemyProjectile` 物理层上。
- 新武器优先复用 `RangedAttackComponent` 或 `MeleeAttackComponent`，通过替换弹体场景、枪口节点和参数形成差异。
- 新角色优先复用现有组件，根节点只保留聚合逻辑，避免把移动、攻击、输入全部塞进同一个脚本。
- 聚合脚本为了保持低耦合，可以通过 `NodePath` 获取组件并保持动态类型；从动态组件方法接收返回值时，局部变量必须显式标注类型，例如 `var movement_direction: Vector2 = ...`，避免 Godot 无法推断返回类型。
- GDScript 中每个 `var`、`@export var`、`@onready var` 变量定义前必须有独立注释，说明变量用途、数据含义、默认值原因、推荐取值范围和修改影响；循环变量也应在循环前说明范围和影响。
