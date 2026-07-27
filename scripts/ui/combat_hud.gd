extends CanvasLayer
class_name CombatHud

## 战斗 HUD 显示玩家生命、能量、底部武器栏和可开关背包。
## HUD 只负责界面呈现、拖拽投放和输入转发，背包与装备数据仍由独立组件维护。
## 武器槽的冷却覆盖由攻击组件的冷却比例驱动，近战和远程使用同一套白色遮罩表现。

## 可拖拽武器槽控件脚本；默认预加载本项目 UI 控件，修改会影响所有装备槽和背包槽的生成方式。
const WEAPON_SLOT_CONTROL_SCRIPT: Script = preload("res://scripts/ui/weapon_slot_control.gd")
## 按键绑定面板脚本；默认用于暂停设置中动态创建可重绑定操作列表。
const KEY_BINDING_PANEL_SCRIPT: Script = preload("res://scripts/ui/key_binding_panel.gd")
## 存档传输控件脚本；默认用于暂停设置复用导出、导入文件选择和安全重启流程。
## 删除功能补充：同一复用控件内部提供输入“确认删除”的危险删除入口。
const SAVE_TRANSFER_CONTROL_SCRIPT: Script = preload("res://scripts/ui/save_transfer_control.gd")
## 结算物品控件脚本；默认复用仓库的标准物品摘要与完整悬停详情，但结算列表不启用点击和拖拽。
const STORAGE_ITEM_CONTROL_SCRIPT: Script = preload("res://scripts/ui/storage_item_control.gd")
## 通用物品卡片视图；战斗装备栏、背包与结算列表统一读取其固定尺寸，禁止场景内单独覆盖。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 通用物品详情格式器；结算标题复用其有效价值读取规则计算武器、装备和堆叠资源总价值。
const ITEM_DETAIL_FORMATTER_SCRIPT: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 统一装备槽控件；四部位装备复用仓库武器槽的排版、耐久条、拖拽视觉与悬浮窗。
const EQUIPMENT_STORAGE_SLOT_SCRIPT: Script = preload("res://scripts/ui/equipment_storage_slot_control.gd")
## 隐藏开发者菜单脚本；默认在暂停界面输入 LISBAM 后以战斗调试上下文显示。
const DEVELOPER_MENU_SCRIPT: Script = preload("res://scripts/ui/developer_menu.gd")
## 强化结果弹窗脚本；用于局内使用或拖动强化石后展示完整属性变化。
const ENHANCEMENT_RESULT_DIALOG_SCRIPT: Script = preload("res://scripts/ui/enhancement_result_dialog.gd")
## 数量选择弹窗脚本；局内部分丢弃和物资送回仓库复用仓库已有滑条与数字输入 UI。
const SELL_QUANTITY_DIALOG_SCRIPT: Script = preload("res://scripts/ui/sell_quantity_dialog.gd")
## 标准物品操作弹窗脚本；战斗背包的装备、使用与丢弃按钮复用局外物品操作视觉资源。
const ITEM_ACTION_POPUP_SCRIPT: Script = preload("res://scripts/ui/item_action_popup.gd")
## 通用信息确认弹窗脚本；正式战斗逃跑确认复用全项目白边信息确认样式。
const COMMON_CONFIRMATION_DIALOG_SCRIPT: Script = preload("res://scripts/ui/common_confirmation_dialog.gd")
## 通用背包面板脚本；局内与局外共享分类、搜索、排序、装备、修复和拖放交互，仅丢弃策略由上下文区分。
const SHARED_BACKPACK_PANEL_SCRIPT: Script = preload("res://scripts/ui/main_menu_backpack_panel.gd")
## 物资撤离面板脚本；玩家在物资撤离点驻留 3 秒后按冲刺键打开，面板期间暂停游戏。
const SUPPLY_EXTRACTION_PANEL_SCRIPT: Script = preload("res://scripts/ui/supply_extraction_panel.gd")
## 全局窗口样式指南；统一战斗背包、暂停菜单、地图、物资撤离、开发者菜单和结算窗口视觉。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 可视进度拖动条组件；为暂停设置主音量滑条绘制实时进度，不接管原生输入与音量换算。
const PROGRESS_SLIDER_VISUAL_SCRIPT: Script = preload("res://scripts/ui/progress_slider_visual.gd")
## UI 风格选择组件；暂停设置复用其选项构建、服务绑定、即时保存与全局刷新逻辑。
const UI_STYLE_SELECTOR_SCRIPT: Script = preload("res://scripts/ui/ui_style_selector.gd")
## 横幅通知开关组件；暂停设置复用其开关构建、服务绑定与即时保存逻辑。
const BANNER_NOTIFICATION_TOGGLE_SCRIPT: Script = preload("res://scripts/ui/banner_notification_toggle.gd")
## 风险合约只读查看面板；暂停界面左栏使用该组件展示本局已确认词条与掉落奖励。
const RISK_CONTRACT_VIEW_PANEL_SCRIPT: Script = preload("res://scripts/ui/risk_contract_view_panel.gd")
## 骇入协议只读查看面板；暂停界面左栏使用该组件展示本机本局协议与叠加层数。
const HACK_PROTOCOL_VIEW_PANEL_SCRIPT: Script = preload("res://scripts/ui/hack_protocol_view_panel.gd")
## 骇入协议三选一面板；碎片积满并完成长按后显示，窗口存在期间不暂停场景树。
const HACK_PROTOCOL_SELECT_PANEL_SCRIPT: Script = preload("res://scripts/ui/hack_protocol_select_panel.gd")
## 主动技能栏脚本；动态显示三个技能槽的实际按键、名称和冷却，不接管技能输入状态机。
const ACTIVE_SKILL_BAR_SCRIPT: Script = preload("res://scripts/ui/active_skill_bar.gd")
## 局内共享槽位视图；左侧技能栏和右侧纯展示武器栏直接复用同一视觉组件。
const COMBAT_HUD_SLOT_VIEW_SCRIPT: Script = preload("res://scripts/ui/combat_hud_slot_view.gd")
## 库存限制配置；旧背包兼容界面、地面丢弃与结算卡片统一使用单组 10 件上限。
const INVENTORY_LIMITS: Script = preload("res://scripts/data/inventory_limits.gd")
## 角色系统当前角色展示模式编号；与 CharacterSelect 的公开展示模式保持一致，只隐藏角色选择栏并复用完整详情。
const CHARACTER_SHOWCASE_DISPLAY_MODE: int = 1
## 战斗开发者模式解锁序列；默认六个英文字母，输入错误时按首字母重新开始匹配。
const DEVELOPER_UNLOCK_SEQUENCE: String = "LISBAM"
## 背包全部分页标识；默认显示所有背包武器，修改会影响筛选按钮与背包网格过滤。
const INVENTORY_FILTER_ALL: String = "all"
## 背包远程分页标识；默认匹配武器资源 weapon_type 的 ranged 值，修改会影响远程筛选页。
const INVENTORY_FILTER_RANGED: String = "ranged"
## 背包近战分页标识；默认匹配武器资源 weapon_type 的 melee 值，修改会影响近战筛选页。
const INVENTORY_FILTER_MELEE: String = "melee"
## 背包强化石分页标识；默认匹配 item_kind 为 enhancement_stone 的可堆叠资源。
const INVENTORY_FILTER_STONES: String = "enhancement_stones"
## 背包道具分页标识；默认匹配 item_kind 为 repair_kit 的可用道具资源。
const INVENTORY_FILTER_ITEMS: String = "items"
## 背包头部装备分页标识；默认匹配 equipment_slot 为 head 的装备资源。
const INVENTORY_FILTER_EQUIPMENT_HEAD: String = "head"
## 背包躯干装备分页标识；默认匹配 equipment_slot 为 body 的装备资源。
const INVENTORY_FILTER_EQUIPMENT_BODY: String = "body"
## 背包腿部装备分页标识；默认匹配 equipment_slot 为 legs 的装备资源。
const INVENTORY_FILTER_EQUIPMENT_LEGS: String = "legs"
## 背包脚部装备分页标识；默认匹配 equipment_slot 为 feet 的装备资源。
const INVENTORY_FILTER_EQUIPMENT_FEET: String = "feet"
## 局内强化石操作菜单使用项编号；固定为 1，选择后进入背包或装备栏武器选择状态。
const INVENTORY_ITEM_ACTION_USE: int = 1
## 局内武器操作菜单装备项编号；固定为 2，远程武器替换当前手持槽，近战武器替换近战槽。
const INVENTORY_ITEM_ACTION_EQUIP: int = 2
## 局内单件或整组丢弃操作编号；点击后直接把当前背包物品生成到玩家附近地面。
const INVENTORY_ITEM_ACTION_DISCARD_ALL: int = 3
## 局内部分丢弃操作编号；堆叠数量大于 1 时打开共用数量选择弹窗。
const INVENTORY_ITEM_ACTION_DISCARD_PARTIAL: int = 4
## 星角色标识；默认与 SessionState 和 GameWorld 保持一致，修改会影响训练场切换角色目标。
const CHARACTER_STELLE: String = "stelle"
## 穹角色标识；默认与 SessionState 和 GameWorld 保持一致，修改会影响训练场切换角色目标。
const CHARACTER_CAEULUS: String = "caelus"
## 银狼角色标识；默认与 SessionState 和 GameWorld 保持一致，修改会影响训练场切换角色目标。
const CHARACTER_SILVER_WOLF: String = "silver_wolf"
## 掉落物列表鼠标交互后的战斗输入抑制时长；默认 0.18 秒，用于覆盖鼠标按下到松开的短暂窗口。
const DROP_LIST_COMBAT_SUPPRESSION_DURATION: float = 0.18
## 风险合约左栏左上偏移；相对屏幕中心为 (-620, -210)，与右侧暂停地图构成对称三栏布局。
const RISK_CONTRACT_VIEW_PANEL_TOP_LEFT: Vector2 = Vector2(-620.0, -210.0)
## 风险合约左栏右下偏移；相对屏幕中心为 (-200, 210)，形成固定 420×420 查看区域。
const RISK_CONTRACT_VIEW_PANEL_BOTTOM_RIGHT: Vector2 = Vector2(-200.0, 210.0)
## 风险合约入口按钮左上偏移；相对屏幕中心为 (-620, -50)，与骇入协议入口上下并列。
const RISK_CONTRACT_VIEW_BUTTON_TOP_LEFT: Vector2 = Vector2(-620.0, -50.0)
## 风险合约入口按钮右下偏移；相对屏幕中心为 (-200, -6)，形成固定 420×44 按钮。
const RISK_CONTRACT_VIEW_BUTTON_BOTTOM_RIGHT: Vector2 = Vector2(-200.0, -6.0)
## 骇入协议入口按钮左上偏移；相对屏幕中心为 (-620, 6)，位于风险合约入口下方。
const HACK_PROTOCOL_VIEW_BUTTON_TOP_LEFT: Vector2 = Vector2(-620.0, 6.0)
## 骇入协议入口按钮右下偏移；相对屏幕中心为 (-200, 50)，形成固定 420×44 按钮。
const HACK_PROTOCOL_VIEW_BUTTON_BOTTOM_RIGHT: Vector2 = Vector2(-200.0, 50.0)
## 单个模式扩展入口顶部偏移；相对屏幕中心为 -22，使唯一启用的扩展按钮在左栏垂直居中。
const SINGLE_MODE_EXTENSION_VIEW_BUTTON_TOP: float = -22.0
## 单个模式扩展入口底部偏移；相对屏幕中心为 22，与顶部共同形成固定 44 像素高度。
const SINGLE_MODE_EXTENSION_VIEW_BUTTON_BOTTOM: float = 22.0
## 骇入协议选择窗口半尺寸；默认 390×250，完整窗口为 780×500 并容纳三张等宽候选卡。
const HACK_PROTOCOL_SELECT_PANEL_HALF_SIZE: Vector2 = Vector2(390.0, 250.0)

## 玩家节点路径；默认指向同一游戏世界下的 Player，必须解析到玩家根节点，运行时通常不修改。
@export var player_path: NodePath = ^"../Player"
## 游戏世界节点路径；默认指向 HUD 父节点 GameWorld，必须解析到提供训练场测试接口的节点。
@export var game_world_path: NodePath = ^".."
## 玩家主动技能组件相对路径；默认 ActiveSkillComponent，技能栏通过该组件读取角色技能和冷却。
@export var active_skill_component_path: NodePath = ^"ActiveSkillComponent"
## 主动技能栏场景；默认使用独立 active_skill_bar.tscn，使槽位样式参数可在编辑器检查器中统一调整。
@export var active_skill_bar_scene: PackedScene = preload("res://scenes/ui/active_skill_bar.tscn")
## 战斗内角色展示场景；默认复用角色系统场景并切换为仅当前角色模式，替换场景时必须提供 display_mode、refresh_current_character 和 close_requested 接口。
@export var character_showcase_scene: PackedScene = preload("res://scenes/ui/character_select.tscn")
## 主动技能栏相对屏幕左下角的位置；默认 (18, -82)，保留 18 像素左边距并把紧凑面板放在底边上方。
@export var active_skill_bar_position: Vector2 = Vector2(18.0, -82.0)
## 主动技能栏外层面板尺寸；默认 362×64 像素，容纳三个紧凑技能槽、槽间距与统一面板内边距。
@export var active_skill_bar_size: Vector2 = Vector2(362.0, 64.0)
## 单个主动技能槽紧凑尺寸；默认 106×50 像素，与外层分区样式合成后保持 362×64 实际面板尺寸。
@export var active_skill_slot_size: Vector2 = Vector2(106.0, 50.0)
## 主动技能栏水平内边距；默认 8 像素，与战斗武器面板的紧凑内容留白保持一致。
@export_range(0, 32, 1) var active_skill_bar_horizontal_margin: int = 8
## 主动技能栏垂直内边距；默认 5 像素，与战斗武器面板上下留白保持一致。
@export_range(0, 32, 1) var active_skill_bar_vertical_margin: int = 5
## 背包开关输入动作名；默认 toggle_inventory 对应 E 键，运行时通常不修改，改名会影响背包打开/关闭。
@export var toggle_inventory_action: StringName = &"toggle_inventory"
## 暂停输入动作名；默认 pause_game 对应 ESC，运行时通常不修改，改名会影响暂停菜单打开方式。
@export var pause_action: StringName = &"pause_game"
## 大地图开关输入动作名；默认 toggle_large_map 对应 Q 键，运行时通常不修改，改名会影响大地图打开方式。
@export var toggle_large_map_action: StringName = &"toggle_large_map"
## 角色展示开关输入动作名；默认 toggle_character_showcase 对应 O 键，运行时通常不修改，改名会影响战斗内角色技能查看入口。
@export var toggle_character_showcase_action: StringName = &"toggle_character_showcase"
## 快速拾取输入动作名；默认 pickup_nearby 对应 F 键，运行时通常不修改，改名会影响附近掉落物快速拾取。
@export var pickup_action: StringName = &"pickup_nearby"
## 掉落物列表开关输入动作名；默认 toggle_drop_list 对应 G 键，运行时通常不修改，改名会影响自动展开开关。
@export var toggle_drop_list_action: StringName = &"toggle_drop_list"
## 骇入协议选择输入动作名；默认 select_hack_protocol 对应 H 键，玩家改键后进度条会实时显示实际绑定。
@export var select_hack_protocol_action: StringName = &"select_hack_protocol"
## 撤离确认输入动作名；默认复用兼容 ID dodge 对应冲刺键，运行时通常不修改，改名会影响撤离点可撤离后的确认操作。
@export var extraction_action: StringName = &"dodge"
## 主菜单场景路径；默认返回项目主菜单，必须填写 tscn 资源，运行时通常不修改，改错会导致暂停菜单返回失败。
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
## 远程装备槽紧凑尺寸；默认 112×54 像素，仅用于右下常驻武器栏，背包和仓库仍使用 160×72 标准卡片。
@export var ranged_slot_minimum_size: Vector2 = Vector2(112.0, 54.0)
## 近战装备槽紧凑尺寸；默认 112×54 像素，与右下远程槽保持一致，不影响其他物品界面。
@export var melee_slot_minimum_size: Vector2 = Vector2(112.0, 54.0)
## 背包物品槽最小尺寸；默认 112x72 适合网格展示，运行时通常不修改，修改会影响背包容量视觉密度。
## 统一模板补充：当前默认值已固定为 160x72，运行时不应通过该兼容字段改变卡片尺寸。
@export var inventory_slot_minimum_size: Vector2 = Vector2(160.0, 72.0)
## 附近掉落物检测距离；取值建议大于玩家半径，默认 120 像素，修改会影响掉落物列表出现距离。
@export_range(16.0, 600.0, 1.0) var nearby_drop_pickup_range: float = 120.0
## 附近掉落物列表最大显示数量；取值建议 1 到 8，默认 5，修改会影响列表高度和拾取选择数量。
@export_range(1, 12, 1) var max_nearby_drop_buttons: int = 5
## 附近掉落物列表刷新间隔；取值建议 0.05 到 0.5 秒，默认 0.12 秒，修改会影响列表响应速度和 UI 重建频率。
@export_range(0.01, 2.0, 0.01) var nearby_drop_refresh_interval: float = 0.12
## 战斗状态文本刷新间隔；默认 0.1 秒，生命与能量仍由信号即时刷新，本参数只限制计时、人口和撤离提示的只读轮询频率。
@export_range(0.02, 2.0, 0.01) var combat_status_refresh_interval: float = 0.1
## 附近掉落物展开高度；默认 220 像素，显示标题和完整拾取按钮列表。
@export_range(80.0, 600.0, 1.0) var nearby_drop_expanded_height: float = 220.0
## 附近掉落物收起高度；默认 42 像素，只保留标题和紧贴标题的背景板。
@export_range(24.0, 120.0, 1.0) var nearby_drop_collapsed_height: float = 42.0
## 战斗开发者菜单半尺寸；默认 280x310，修改会影响暂停遮罩中调试面板的可用空间，运行时通常不动态修改。
@export var combat_developer_menu_half_size: Vector2 = Vector2(280.0, 310.0)
## 短时逃跑判定时长；默认 30.0 秒，玩家在该时间内主动逃跑时应用较低损失比例，运行时通常不动态修改。
@export_range(0.0, 600.0, 0.1) var early_escape_duration_seconds: float = 30.0
## 短时逃跑物品损失比例；默认 0.20 表示背包每个物品单位独立保留 80%，只影响主动逃跑且不影响死亡结算。
## 现行短时逃跑规则补充：默认值为 0.30，对应死亡时背包 60% 丢失概率减半。
@export_range(0.0, 1.0, 0.01) var early_escape_loss_ratio: float = 0.30
## 正常失败背包损失比例；默认 0.60，死亡与超过短时保护期的主动逃跑都会让背包每个物品单位独立判定，运行时通常不动态修改。
@export_range(0.0, 1.0, 0.01) var failure_backpack_loss_ratio: float = 0.60
## 正常失败装备栏损失比例；默认 0.20，武器栏和四个防具槽中的每件物品独立判定，运行时通常不动态修改。
@export_range(0.0, 1.0, 0.01) var failure_equipment_loss_ratio: float = 0.20
## 短时逃跑装备栏损失比例；默认 0.10，对应正常失败时装备栏 20% 丢失概率减半，运行时通常不动态修改。
@export_range(0.0, 1.0, 0.01) var early_escape_equipment_loss_ratio: float = 0.10
## 远程冷却遮罩最短显示时长；默认 0.12 秒，更短或相等的高射速冷却不显示遮罩以避免持续闪烁。
@export_range(0.0, 1.0, 0.01) var cooldown_overlay_minimum_duration: float = 0.12

## 玩家节点缓存；默认按 player_path 获取，允许为空但 HUD 不会显示有效状态，修改会影响所有组件绑定。
var _player: Node
## 游戏世界节点缓存；默认按 game_world_path 获取，允许为空但训练场设置无法清怪或重刷怪物。
var _game_world: Node
## 战斗属性组件缓存；默认从玩家子节点 StatsComponent 获取，允许为空但生命和能量无法刷新。
var _stats_component: Node
## 玩家护盾组件缓存；默认从玩家子节点 ShieldComponent 获取，允许为空并按无护盾状态显示。
var _shield_component: Node
## 装备组件缓存；默认从玩家子节点 EquipmentComponent 获取，允许为空但装备栏无法刷新。
var _equipment_component: Node
## 背包组件缓存；默认从玩家子节点 InventoryComponent 获取，允许为空但背包网格无法刷新。
var _inventory_component: Node
## 输入组件缓存；默认从玩家子节点 InputComponent 获取，允许为空但背包打开时无法主动锁定战斗输入。
var _input_component: Node
## 远程攻击组件缓存；默认从玩家子节点 RangedAttackComponent 获取，允许为空但远程槽无法显示冷却覆盖。
var _ranged_attack_component: Node
## 近战攻击组件缓存；默认从玩家子节点 MeleeAttackComponent 获取，允许为空但近战槽无法显示冷却覆盖。
var _melee_attack_component: Node
## 远程攻击组件是否提供冷却比例接口；组件注入时缓存 has_method 结果，每帧冷却遮罩刷新不再重复做方法名字符串查找。
var _ranged_component_has_cooldown_ratio: bool = false
## 远程攻击组件是否提供冷却总时长接口；组件注入时缓存，供高射速武器判断是否隐藏快速闪烁遮罩。
var _ranged_component_has_cooldown_duration: bool = false
## 近战攻击组件是否提供冷却比例接口；组件注入时缓存，每帧冷却遮罩刷新不再重复做方法名字符串查找。
var _melee_component_has_cooldown_ratio: bool = false
## 近战攻击组件是否提供冷却总时长接口；组件注入时缓存，供高攻速近战判断是否隐藏快速闪烁遮罩。
var _melee_component_has_cooldown_duration: bool = false
## 主动技能组件缓存；默认从玩家子节点 ActiveSkillComponent 获取，允许为空但不会显示角色主动技能或冷却。
var _active_skill_component: Node
## 本地玩家骇入协议组件；仅在启用扩展的正式战斗存在，碎片与协议不会读取其他玩家状态。
var _hack_protocol_component: Node
## 数据碎片进度分区；动态插入生命能量面板上方，扩展未启用时隐藏且不占布局。
var _hack_protocol_progress_panel: PanelContainer
## 数据碎片文本；显示实际碎片、当前需求、真实绑定键和长按秒数。
var _hack_protocol_progress_label: Label
## 数据碎片进度条；数值比例最高显示 100%，溢出量仍由文本完整展示。
var _hack_protocol_progress_bar: ProgressBar
## 当前选择键持续按住时间；松开、界面受阻或打开候选后归零。
var _hack_protocol_hold_elapsed: float = 0.0
## 骇入协议选择全屏遮罩；打开时只锁定本机战斗输入，不暂停单机或联机场景树。
var _hack_protocol_select_overlay: Control
## 骇入协议三选一面板；每次打开读取组件已固定候选，关闭不会重新随机。
var _hack_protocol_select_panel: Control
## 主动技能栏缓存；默认运行时创建在屏幕左下角，三个技能槽按技能一、二、三顺序显示。
var _active_skill_bar: Control
## 主动技能栏标准分区面板；默认位于普通 HUD 层并排在所有菜单遮罩之前，避免覆盖背包、暂停或结算界面。
var _active_skill_bar_panel: PanelContainer
## 远程槽控件缓存；元素为 WeaponSlotControl 实例，默认按装备槽数量动态创建，修改会影响 HUD 刷新目标。
var _ranged_slot_controls: Array = []
## 近战槽控件缓存；取值为 WeaponSlotControl 或 null，默认动态创建，修改会影响近战装备显示目标。
var _melee_slot_control: Control
## 背包槽控件缓存；元素为 WeaponSlotControl 实例，默认按背包物品动态创建，修改会影响背包刷新目标。
var _inventory_slot_controls: Array = []
## 背包左侧远程装备槽控件缓存；元素为 WeaponSlotControl 实例，默认按装备槽数量动态创建，修改会影响背包内装备显示。
var _inventory_equipment_ranged_controls: Array = []
## 背包左侧近战装备槽控件缓存；取值为 WeaponSlotControl 或 null，默认动态创建，修改会影响背包内近战显示。
var _inventory_equipment_melee_control: Control
## 背包左侧四部位装备槽按钮；键为 head、body、legs、feet，值为动态 Button。
var _inventory_armor_slot_buttons: Dictionary = {}
## 最近触发冷却的远程槽索引；取值为 -1 或有效远程槽，默认 -1 表示无远程冷却显示目标，修改会影响远程 CD 遮罩位置。
var _last_cooling_ranged_slot: int = -1
## 背包当前二级筛选页；取值为 all、武器类型、装备部位或资源类型，默认 all。
var _inventory_filter: String = INVENTORY_FILTER_ALL
## 背包当前主分类；取值为 all、weapons、equipment 或 resources，默认全部并决定二级按钮内容。
var _inventory_primary_category: String = InventoryQuery.PRIMARY_ALL
## 背包全部主分类按钮；默认运行时创建，同时展示武器和资源并隐藏类型专属二级入口。
var _inventory_primary_all_button: Button
## 背包武器主分类按钮；默认运行时创建，点击后显示全部/近战/远程二级页。
var _inventory_primary_weapons_button: Button
## 背包装备一级分类按钮；显示四部位装备物品。
var _inventory_primary_equipment_button: Button
## 背包资源主分类按钮；默认运行时创建，点击后显示全部/强化石二级页。
var _inventory_primary_resources_button: Button
## 背包强化石筛选按钮；默认运行时追加到现有筛选栏，点击后显示正方形强化石格子。
var _inventory_filter_stones_button: Button
## 背包道具筛选按钮；默认运行时追加到资源筛选栏，点击后只显示修复包等道具。
var _inventory_filter_items_button: Button
## 背包头部装备筛选按钮；默认运行时追加到二级分类栏，仅在装备主分类显示。
var _inventory_filter_equipment_head_button: Button
## 背包躯干装备筛选按钮；默认运行时追加到二级分类栏，仅在装备主分类显示。
var _inventory_filter_equipment_body_button: Button
## 背包腿部装备筛选按钮；默认运行时追加到二级分类栏，仅在装备主分类显示。
var _inventory_filter_equipment_legs_button: Button
## 背包脚部装备筛选按钮；默认运行时追加到二级分类栏，仅在装备主分类显示。
var _inventory_filter_equipment_feet_button: Button
## 背包关键词搜索框；默认空字符串，按名称、说明和强化词条实时筛选。
var _inventory_search_edit: LineEdit
## 背包排序下拉框；默认获得时间，可切换物品价值降序。
var _inventory_sort_option: OptionButton
## 背包强化石品质筛选框；只在资源主分类显示，选项与锻造系统使用同一品质顺序和短名称。
var _inventory_stone_quality_option: OptionButton
## 背包强化属性筛选框；默认全部属性，只在资源主分类显示。
var _inventory_stone_attribute_option: OptionButton
## 背包清空强化属性筛选按钮；默认只在资源主分类显示，用于移除全部多选条件。
var _inventory_stone_attribute_clear_button: Button
## 背包当前强化属性筛选键集合；默认空数组表示不过滤具体属性，多项条件按并集展示。
var _inventory_stone_attribute_filter: Array[String] = []
## 背包当前强化石品质筛选；默认空字符串表示全部品质，其他值使用 EnhancementRules 的稳定品质标识。
var _inventory_stone_quality_filter: String = ""
## 背包当前排序模式；默认 acquired_time，只改变显示顺序。
var _inventory_sort_mode: String = InventoryQuery.SORT_ACQUIRED_TIME
## 标准局内物品操作弹窗；点击物品后显示装备、使用与丢弃功能按钮，不在战斗内提供星穹出售。
var _inventory_item_action_menu: ItemActionPopup
## 当前局内待使用强化石；非空时下一次点击背包或装备栏武器会尝试强化。
var _pending_combat_stone_resource: Resource
## 当前局内操作菜单指向的强化石；只有玩家确认“使用”后才复制到待选择状态，关闭菜单不会误消费。
var _combat_action_stone_resource: Resource
## 当前局内操作菜单指向的背包武器；非空时选择“装备”会替换对应装备槽。
var _combat_action_weapon_resource: Resource
## 当前局内操作武器的背包原始下标；默认 -1，装备替换后用于把旧武器放回相同位置。
var _combat_action_weapon_source_index: int = -1
## 当前局内操作菜单物品的堆叠数量；默认 1，资源菜单用它决定显示单个、全部或部分丢弃。
var _combat_action_item_quantity: int = 1
## 当前局内部分丢弃等待确认的物品；默认 null，数量弹窗确认后按当前背包真实数量再次限制。
var _pending_discard_resource: Resource
## 局内数量选择弹窗；默认运行时创建一次，部分丢弃时切换为丢弃模式。
var _combat_quantity_dialog: SellQuantityDialog
## 通用局内背包面板；运行时替代场景中的旧背包实现，CombatHud 只管理显示、输入锁定和地面丢弃。
var _shared_backpack_panel: SharedBackpackPanel
## 局内取消使用按钮；默认隐藏，进入强化目标选择后显示。
var _inventory_cancel_stone_use_button: Button
## 局内强化结果弹窗；默认运行时创建一次并在每次成功强化时复用。
var _enhancement_result_dialog: EnhancementResultDialog
## 强化选择前主分类；默认资源分类，成功使用强化石后恢复到玩家跳转前的资源页面。
var _combat_stone_return_primary_category: String = InventoryQuery.PRIMARY_RESOURCES
## 强化选择前子分类；默认强化石，成功使用强化石后恢复原分页。
var _combat_stone_return_filter: String = INVENTORY_FILTER_STONES
## 强化选择前搜索文本；默认空字符串，成功强化后恢复原查询内容。
var _combat_stone_return_search_text: String = ""
## 强化选择前属性筛选集合；默认空数组表示全部属性，成功使用道具后恢复原多选组合。
var _combat_stone_return_attribute_filter: Array[String] = []
## 强化选择前品质筛选；默认空字符串表示全部品质，目标选择结束后恢复原背包查询条件。
var _combat_stone_return_quality_filter: String = ""
## 是否存在待恢复的强化石页面；默认 false，只有点击“使用”触发页面跳转后才恢复，拖拽强化不会改变当前页面。
var _combat_stone_return_view_pending: bool = false
## Master 音频总线索引；取值为 -1 或有效总线下标，默认 -1 表示尚未解析，修改会影响暂停设置音量应用目标。
var _master_bus_index: int = -1
## 当前是否为训练场模式；取值为 true/false，默认 false，修改会影响训练场设置按钮和角色切换入口是否可见。
var _is_training_mode: bool = false
## 当前是否为无结算娱乐模式；训练场与超频骇入均为 true，控制离开按钮文本、死亡复活与拾取消耗行为。
## 训练场专属工具（测试设置、角色切换）仍只看 _is_training_mode，本变量不扩大工具入口范围。
var _is_casual_mode: bool = false
## 玩家是否已经死亡；取值为 true/false，默认 false，生命归零后用于阻止继续打开暂停、背包和大地图。
var _is_player_dead: bool = false
## 本局结算是否已经完成；默认 false，成功撤离、死亡或主动退出只允许执行一次全局背包结算。
var _run_outcome_resolved: bool = false
## 掉落物列表是否允许自动显示；取值为 true/false，默认 true，按 G 可切换以避免战斗时误触列表。
var _drop_list_enabled: bool = true
## 掉落物列表点击后的战斗输入抑制时间；取值大于等于 0，默认 0 表示不额外阻止射击。
var _drop_list_combat_suppression_remaining: float = 0.0
## 附近掉落物面板缓存；默认运行时创建，显示玩家可拾取的地面武器列表。
var _nearby_drop_panel: PanelContainer
## 附近掉落物标题缓存；默认运行时创建，G 关闭列表时仍保留该标题提示当前附近存在掉落物。
var _nearby_drop_title_label: Label
## 附近掉落物列表容器缓存；默认运行时创建，只承载拾取按钮，不承载标题。
var _nearby_drop_list: VBoxContainer
## 附近掉落物按钮缓存；元素为 Button，默认每次刷新前清空，修改会影响拾取列表复用方式。
var _nearby_drop_buttons: Array[Button] = []
## 附近掉落物刷新剩余时间；取值大于等于 0，默认 0 表示下一帧可刷新列表。
var _nearby_drop_refresh_remaining: float = 0.0
## 战斗状态刷新剩余时间；取值大于等于 0，默认 0 表示下一帧立即同步计时、人口和撤离提示。
var _combat_status_refresh_remaining: float = 0.0
## 当前掉落物列表签名；元素为实例、名称和位置组成的字符串，默认用于判断列表内容是否需要重建。
## 签名结构补充：现为每个掉落物一条 [实例编号, 显示名称, 取整X, 取整Y] 数组条目，比较语义不变且不再产生字符串格式化分配。
var _nearby_drop_signature: Array = []
## 最近一次附近掉落物刷新结果；元素按距离从近到远排列，仅在同一批 UI 与宝箱优先级检查中复用，不作为物品所有权来源。
var _nearby_drop_cache: Array[Node2D] = []
## 当前正在长按开启的宝箱；默认 null，周围存在掉落物、松开 F、离开范围或打开其他面板时会立即取消并重置进度。
var _active_loot_chest: Node2D
## 当前宝箱是否已收到持续开启请求；默认 false，只在按键状态变化时写入宝箱，避免同一目标每帧重复启停处理。
var _active_loot_chest_opening: bool = false
## 当前宝箱开启请求是否已经完成首次同步；默认 false，新目标即使处于未按住状态也必须先显示交互提示。
var _has_active_loot_chest_opening_state: bool = false
## 上一帧拾取键是否处于按住状态；默认 false，用于识别长按起始帧，只有该帧执行即时全量场景组补查。
var _pickup_action_held_last_frame: bool = false
## 物理键兜底判定缓存；键为动作名字符串，值为布尔判定结果，InputBindings 的 bindings_changed 信号触发时整体失效并重算。
var _physical_fallback_cache: Dictionary = {}
## 物资撤离全屏遮罩；默认运行时创建并隐藏，打开时阻止其余 HUD 鼠标交互。
var _supply_extraction_overlay: Control
## 物资撤离面板实例；默认运行时创建一次并复用，显示背包、装备、星穹和剩余送回价值。
var _supply_extraction_panel: Control
## 战斗内角色展示界面；默认运行时从角色系统场景创建并隐藏，打开时只显示当前已选角色并暂停游戏。
var _character_showcase_view: Control
## 最近一次显示的存活时间整秒数；默认 -1 表示尚未刷新，用于避免每帧重复写入相同计时文本。
var _last_survival_time_whole_seconds: int = -1
## 最近一次显示的存活怪物数量；默认 -1 表示尚未刷新，虚拟人口变化时才更新左上角文本。
var _last_alive_monster_count: int = -1
## 最近一次显示的撤离状态文本；默认空字符串，用于避免每帧重复写入相同撤离提示。
var _last_extraction_status_text: String = ""
## 最近一次撤离状态是否可见；默认 false，用于避免每帧重复写入相同可见状态。
var _last_extraction_status_visible: bool = false
## 是否已经缓存战斗输入启用状态；默认 false，第一次刷新时会强制同步输入组件。
var _has_combat_input_enabled_state: bool = false
## 最近一次战斗输入启用状态；默认 true，仅状态变化时才写入玩家输入组件。
var _last_combat_input_enabled: bool = true
## 战斗顶部状态容器缓存；默认运行时创建，用于显示生存时间和撤离点状态。
var _combat_status_container: VBoxContainer
## 生存时间文本缓存；默认运行时创建，显示进入战斗后的 mm:ss 计时。
var _survival_timer_label: Label
## 存活怪物数量文本缓存；默认运行时创建并固定在 HUD 左上角，显示全地图虚拟存活人口。
var _monster_count_label: Label
## 撤离状态文本缓存；默认运行时创建，撤离点未出现时隐藏。
var _extraction_status_label: Label
## 暂停设置按键绑定面板缓存；默认运行时创建，显示并修改 InputMap 的玩家操作绑定。
var _pause_key_binding_panel: Control
## 暂停设置按键绑定入口按钮缓存；默认运行时插入设置首页，点击后切换到按键绑定页面。
var _pause_key_binding_button: Button
## 暂停设置按键绑定页面缓存；默认运行时创建并隐藏，用于分页显示完整按键绑定面板。
var _pause_key_binding_page: VBoxContainer
## 暂停设置按键绑定返回按钮缓存；默认运行时创建，点击后回到暂停设置首页。
var _pause_key_binding_back_button: Button
## 暂停设置首页控件列表；元素为 Control，默认用于在设置首页和按键绑定页之间切换可见性。
var _pause_settings_home_controls: Array[Control] = []
## 暂停设置 UI 风格选择组件；默认运行时插入主音量下方并与主菜单共享同一持久化服务。
var _pause_ui_style_selector: Control
## 暂停设置横幅通知开关组件；默认运行时插入 UI 风格行下方并与主菜单共享同一持久化服务。
var _pause_banner_notification_toggle: Control
## 暂停设置存档传输控件；默认运行时创建，导出仅包含各服务已经落盘的持久化状态。
## 删除功能补充：删除会丢弃本局未落盘内存变化，并通过重启恢复到首次启动默认状态。
var _pause_save_transfer_control: Control
## 风险合约查看入口按钮；默认运行时创建在暂停界面左栏，其他暂停子页打开时隐藏。
var _risk_contract_view_button: Button
## 风险合约只读查看面板；默认运行时创建并隐藏，打开时占用暂停界面左侧 420×420 空栏。
var _risk_contract_view_panel: Control
## 骇入协议查看入口按钮；默认运行时创建在暂停界面左栏，与风险合约入口上下排列。
var _hack_protocol_view_button: Button
## 骇入协议只读查看面板；默认运行时创建并隐藏，只展示本机本局协议。
var _hack_protocol_view_panel: Control
## 战斗开发者全屏遮罩；默认运行时创建并隐藏，暂停界面完成 LISBAM 序列后显示。
var _combat_developer_overlay: Control
## 战斗开发者菜单实例；默认复用 DeveloperMenu 并切换到无限属性与训练工具上下文。
var _combat_developer_menu: Control
## 战斗开发者序列当前匹配下标；取值 0 到序列长度，默认 0 表示等待字母 L。
var _developer_sequence_index: int = 0
## 是否已解锁正式模式训练工具；默认 false，完成 LISBAM 后允许打开训练场设置和切换角色。
var _developer_training_access_unlocked: bool = false
## 逃跑二次确认弹窗；默认运行时创建并在暂停状态处理输入，确认后才执行正式战斗损失结算。
var _escape_confirmation_dialog: CommonConfirmationDialog
## 新手保护结束提示弹窗；默认运行时创建，仅在玩家本档首次成功撤离的结算后展示一次。
var _newcomer_protection_ended_dialog: CommonConfirmationDialog
## 当前结算结构化结果；默认空字典，结算弹窗打开后缓存获得与丢失条目供分类按钮重复重建。
var _settlement_outcome: Dictionary = {}
## 结算获得物品主分类；取值为 all、weapons 或 resources，默认全部与战斗背包分类入口一致。
var _settlement_primary_category: String = InventoryQuery.PRIMARY_ALL
## 结算获得物品子分类；取值随主分类变化，默认 all 表示展示当前主分类全部条目。
var _settlement_subcategory: String = InventoryQuery.SUBCATEGORY_ALL

## HUD 根控件缓存；默认绑定 Root，用于动态挂载附近掉落物面板。
@onready var _root_control: Control = get_node("Root") as Control
## 右上角小地图缓存；默认绑定 Root/MiniMap，风险合约“禁用小地图”只隐藏此节点，不影响 Q 键大地图。
@onready var _mini_map: Control = get_node_or_null("Root/MiniMap") as Control
## 角色名称文本缓存；默认绑定 CharacterNameLabel，显示当前选择角色名称，节点缺失会导致 HUD 无法展示角色名。
@onready var _character_name_label: Label = %CharacterNameLabel
## 生命文本缓存；默认绑定 HealthLabel，显示当前生命和最大生命，节点缺失会导致生命文本无法刷新。
@onready var _health_label: Label = %HealthLabel
## 生命条缓存；默认绑定 HealthBar，显示当前生命比例，节点缺失会导致生命条无法刷新。
@onready var _health_bar: ProgressBar = %HealthBar
## 护盾白色滤镜缓存；默认覆盖生命条完整区域，仅在当前护盾大于 0 时显示。
@onready var _shield_overlay: ColorRect = %ShieldOverlay
## 能量文本缓存；默认绑定 EnergyLabel，显示当前能量和最大能量，节点缺失会导致能量文本无法刷新。
@onready var _energy_label: Label = %EnergyLabel
## 能量条缓存；默认绑定 EnergyBar，显示当前能量比例，节点缺失会导致能量条无法刷新。
@onready var _energy_bar: ProgressBar = %EnergyBar
## 远程装备槽容器缓存；默认绑定 RangedSlots，动态创建远程槽控件，节点缺失会导致远程装备栏无法显示。
@onready var _ranged_slots_container: HBoxContainer = %RangedSlots
## 近战装备槽容器缓存；默认绑定 MeleeSlotHost，动态创建近战槽控件，节点缺失会导致近战装备栏无法显示。
@onready var _melee_slot_host: HBoxContainer = %MeleeSlotHost
## 背包面板缓存；默认绑定 InventoryPanel，E 键切换显示，节点缺失会导致背包无法打开。
@onready var _inventory_panel: Control = %InventoryPanel
## 背包标题文本缓存；默认绑定 InventoryTitleLabel，显示背包数量和操作提示，节点缺失会导致背包标题无法刷新。
@onready var _inventory_title_label: Label = %InventoryTitleLabel
## 背包左侧远程装备槽容器缓存；默认绑定 InventoryEquipmentRangedSlots，动态创建当前远程装备槽。
@onready var _inventory_equipment_ranged_container: VBoxContainer = %InventoryEquipmentRangedSlots
## 背包左侧近战装备槽容器缓存；默认绑定 InventoryEquipmentMeleeSlotHost，动态创建当前近战装备槽。
@onready var _inventory_equipment_melee_host: VBoxContainer = %InventoryEquipmentMeleeSlotHost
## 背包右侧武器网格缓存；默认绑定 InventoryWeaponGrid，动态创建背包武器物品槽，节点缺失会导致背包物品无法显示。
@onready var _inventory_weapon_grid: HFlowContainer = %InventoryWeaponGrid
## 背包空白投放区域缓存；默认绑定 InventoryScroll，拖拽到空白处时把武器放入背包末尾。
@onready var _inventory_drop_area: Node = %InventoryScroll
## 背包全部筛选按钮缓存；默认绑定 InventoryFilterAllButton，点击后显示全部武器。
@onready var _inventory_filter_all_button: Button = %InventoryFilterAllButton
## 背包近战筛选按钮缓存；默认绑定 InventoryFilterMeleeButton，点击后只显示近战武器。
@onready var _inventory_filter_melee_button: Button = %InventoryFilterMeleeButton
## 背包远程筛选按钮缓存；默认绑定 InventoryFilterRangedButton，点击后只显示远程武器。
@onready var _inventory_filter_ranged_button: Button = %InventoryFilterRangedButton
## 暂停菜单遮罩缓存；默认绑定 PauseOverlay，ESC 切换显示，显示时暂停场景树。
@onready var _pause_overlay: Control = %PauseOverlay
## 暂停主菜单面板缓存；默认绑定 PauseMenuPanel，显示继续、设置和返回主菜单按钮。
@onready var _pause_menu_panel: Control = %PauseMenuPanel
## 暂停设置面板缓存；默认绑定 PauseSettingsPanel，显示主音量设置。
@onready var _pause_settings_panel: Control = %PauseSettingsPanel
## 继续游戏按钮缓存；默认绑定 ResumeButton，点击后恢复场景树运行。
@onready var _resume_button: Button = %ResumeButton
## 暂停设置按钮缓存；默认绑定 PauseSettingsButton，点击后打开暂停设置面板。
@onready var _pause_settings_button: Button = %PauseSettingsButton
## 训练场设置按钮缓存；默认绑定 TestSettingsButton，点击后打开训练场设置面板。
@onready var _test_settings_button: Button = %TestSettingsButton
## 脱离卡死按钮缓存；默认绑定 UnstuckButton，点击后请求 GameWorld 把玩家传送到附近无障碍位置。
@onready var _unstuck_button: Button = %UnstuckButton
## 返回主菜单按钮缓存；默认绑定 ReturnMainMenuButton，点击后解除暂停并切换到主菜单。
@onready var _return_main_menu_button: Button = %ReturnMainMenuButton
## 训练场设置面板缓存；默认绑定 TestSettingsPanel，显示清怪、重刷和无限属性开关。
@onready var _test_settings_panel: Control = %TestSettingsPanel
## 清空怪物按钮缓存；默认绑定 ClearMonstersButton，点击后清空训练场怪物。
@onready var _clear_monsters_button: Button = %ClearMonstersButton
## 重新生成怪物按钮缓存；默认绑定 RespawnMonstersButton，点击后按当前训练场配置追加一批怪物。
@onready var _respawn_monsters_button: Button = %RespawnMonstersButton
## 切换角色按钮缓存；默认绑定 SwitchCharacterButton，仅训练场显示，点击后打开角色切换面板。
@onready var _switch_character_button: Button = %SwitchCharacterButton
## 增加游戏时间按钮缓存；默认绑定 AddGameTimeButton，每次点击调用 GameWorld 增加 60 秒生存时间并立即刷新撤离阶段。
@onready var _add_game_time_button: Button = %AddGameTimeButton
## 无限能量开关缓存；默认绑定 InfiniteEnergyCheckButton，切换后修改玩家属性组件的无限能量状态。
@onready var _infinite_energy_check_button: CheckButton = %InfiniteEnergyCheckButton
## 无限血量开关缓存；默认绑定 InfiniteHealthCheckButton，切换后修改玩家属性组件的无限血量状态。
@onready var _infinite_health_check_button: CheckButton = %InfiniteHealthCheckButton
## 主动技能无冷却开关缓存；默认绑定 ActiveSkillNoCooldownCheckButton，仅训练场或开发者训练工具中切换当前角色技能组件状态。
@onready var _active_skill_no_cooldown_check_button: CheckButton = %ActiveSkillNoCooldownCheckButton
## 训练场设置返回按钮缓存；默认绑定 TestSettingsBackButton，点击后返回暂停主菜单。
@onready var _test_settings_back_button: Button = %TestSettingsBackButton
## 获取地图视野按钮；位于训练场设置中，点击后立即把完整战斗地图标记为已探索。
@onready var _unlock_map_vision_button: Button = %UnlockMapVisionButton
## 训练场角色切换面板缓存；默认绑定 CharacterSwitchPanel，只在训练场设置中打开。
@onready var _character_switch_panel: Control = %CharacterSwitchPanel
## 训练场星角色按钮缓存；默认绑定 SwitchCharacterStelleButton，点击后切换为星并刷新占位属性。
@onready var _switch_character_stelle_button: Button = %SwitchCharacterStelleButton
## 训练场穹角色按钮缓存；默认绑定 SwitchCharacterCaelusButton，点击后切换为穹并刷新占位属性。
@onready var _switch_character_caelus_button: Button = %SwitchCharacterCaelusButton
## 训练场银狼角色按钮缓存；默认绑定 SwitchCharacterSilverWolfButton，点击后切换为银狼并刷新占位属性。
@onready var _switch_character_silver_wolf_button: Button = %SwitchCharacterSilverWolfButton
## 训练场角色按钮容器；默认绑定 CharacterSwitchContent，新发现角色会动态插入返回按钮前的弹性占位之前。
@onready var _character_switch_content: VBoxContainer = get_node("Root/PauseOverlay/CharacterSwitchPanel/CharacterSwitchMargin/CharacterSwitchContent") as VBoxContainer
## 训练场角色列表底部占位；默认绑定 CharacterSwitchBottomSpacer，动态按钮会插入到该节点之前。
@onready var _character_switch_bottom_spacer: Control = get_node("Root/PauseOverlay/CharacterSwitchPanel/CharacterSwitchMargin/CharacterSwitchContent/CharacterSwitchBottomSpacer") as Control
## 训练场角色按钮滚动内容；默认在 ready 中创建，承载内置与自动发现角色，避免新角色超出固定面板。
var _training_character_button_container: VBoxContainer
## 训练场角色切换返回按钮缓存；默认绑定 CharacterSwitchBackButton，点击后回到训练场设置面板。
@onready var _character_switch_back_button: Button = %CharacterSwitchBackButton
## 暂停设置主音量滑条缓存；默认绑定 PauseMasterVolumeSlider，取值 0 到 100，修改会影响全局 Master 音量。
@onready var _pause_master_volume_slider: HSlider = %PauseMasterVolumeSlider
## 暂停设置内容容器缓存；默认通过场景路径绑定，用于动态挂载按键绑定面板。
@onready var _pause_settings_content: VBoxContainer = get_node("Root/PauseOverlay/PauseSettingsPanel/PauseSettingsMargin/PauseSettingsContent") as VBoxContainer
## 暂停设置主音量数值文本缓存；默认绑定 PauseMasterVolumeValueLabel，显示滑条当前百分比。
@onready var _pause_master_volume_value_label: Label = %PauseMasterVolumeValueLabel
## 暂停设置返回按钮缓存；默认绑定 PauseSettingsBackButton，点击后返回暂停主菜单。
@onready var _pause_settings_back_button: Button = %PauseSettingsBackButton
## 大地图遮罩缓存；默认绑定 LargeMapOverlay，Q 键切换显示，显示时锁定战斗输入。
@onready var _large_map_overlay: Control = %LargeMapOverlay
## 死亡遮罩缓存；默认绑定 DeathOverlay，玩家生命归零时显示并暂停场景树。
@onready var _death_overlay: Control = %DeathOverlay
## 死亡返回主菜单按钮缓存；默认绑定 DeathReturnMainMenuButton，点击后解除暂停并切换回主菜单。
@onready var _death_return_main_menu_button: Button = %DeathReturnMainMenuButton
## 结算标题缓存；默认绑定 DeathTitle，成功撤离、死亡和主动退出会显示不同标题。
@onready var _death_title_label: Label = %DeathTitle
## 结算物品列表缓存；默认绑定 DeathSettlementList，以每行四个的居中网格展示本局获得和实际丢失物品。
@onready var _death_settlement_list: VBoxContainer = %DeathSettlementList


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI_STYLE_GUIDE.apply_screen_theme(_root_control)
	UI_STYLE_GUIDE.apply_semantic_progress_bar(_health_bar)
	UI_STYLE_GUIDE.apply_semantic_progress_bar(_energy_bar)
	UI_STYLE_GUIDE.apply_window_panel(_inventory_panel)
	UI_STYLE_GUIDE.apply_window_panel(_pause_menu_panel)
	UI_STYLE_GUIDE.apply_window_panel(_pause_settings_panel)
	UI_STYLE_GUIDE.apply_window_panel(_test_settings_panel)
	UI_STYLE_GUIDE.apply_window_panel(_character_switch_panel)
	UI_STYLE_GUIDE.apply_window_panel(get_node("Root/PauseOverlay/PauseMapPanel") as Control)
	UI_STYLE_GUIDE.apply_window_panel(get_node("Root/DeathOverlay/DeathPanel") as Control)
	UI_STYLE_GUIDE.apply_overlay_dim(get_node("Root/LargeMapOverlay/LargeMapDim") as ColorRect)
	UI_STYLE_GUIDE.apply_overlay_dim(get_node("Root/PauseOverlay/PauseDim") as ColorRect)
	UI_STYLE_GUIDE.apply_overlay_dim(get_node("Root/DeathOverlay/DeathDim") as ColorRect)
	UI_STYLE_GUIDE.apply_title_label(_death_title_label)
	UI_STYLE_GUIDE.apply_title_label(_character_name_label)
	UI_STYLE_GUIDE.apply_primary_button(_death_return_main_menu_button)
	UI_STYLE_GUIDE.apply_danger_button(_return_main_menu_button)
	PROGRESS_SLIDER_VISUAL_SCRIPT.install(_pause_master_volume_slider)
	_master_bus_index = AudioServer.get_bus_index("Master")
	_bind_game_world()
	_bind_player_components()
	_build_hack_protocol_progress()
	_build_hack_protocol_select_overlay()
	_build_active_skill_bar()
	_build_shared_backpack_panel()
	_bind_pause_menu()
	_build_risk_contract_view()
	_build_hack_protocol_view()
	_build_escape_confirmation_dialog()
	_build_newcomer_protection_ended_dialog()
	_build_combat_status_panel()
	_build_nearby_drop_panel()
	_build_supply_extraction_overlay()
	_build_character_showcase_view()
	_build_combat_developer_overlay()
	# 输入绑定服务；绑定变更信号触发时清空物理键兜底缓存，改键、单项恢复与全部恢复都会让下一次输入判定重算。
	var input_bindings_service: Node = get_tree().root.get_node_or_null("InputBindings")
	if input_bindings_service != null and input_bindings_service.has_signal("bindings_changed") and not input_bindings_service.is_connected("bindings_changed", Callable(self, "_on_input_bindings_changed")):
		input_bindings_service.connect("bindings_changed", Callable(self, "_on_input_bindings_changed"))
	_refresh_all()
	_refresh_combat_status()
	_set_inventory_visible(false)
	_set_large_map_visible(false)
	_set_pause_menu_visible(false)
	if not _is_player_dead:
		_set_death_overlay_visible(false)
	# 模式状态延后刷新；CombatHud 子节点会先于 GameWorld 父节点 ready，等待父节点写入 SessionState 的超频变体后再同步离开入口。
	call_deferred("_refresh_mode_state_after_game_world_initialized")


func _process(delta: float) -> void:
	_refresh_cooldown_overlays()
	_update_hack_protocol_hold(delta)
	_combat_status_refresh_remaining = maxf(_combat_status_refresh_remaining - delta, 0.0)
	if _combat_status_refresh_remaining <= 0.0:
		_combat_status_refresh_remaining = maxf(combat_status_refresh_interval, 0.02)
		_refresh_combat_status()
	_drop_list_combat_suppression_remaining = maxf(_drop_list_combat_suppression_remaining - delta, 0.0)
	_nearby_drop_refresh_remaining = maxf(_nearby_drop_refresh_remaining - delta, 0.0)
	# 本帧拾取键按住状态；统一读取一次，供批量刷新分支与长按复核分支共用。
	var pickup_action_held: bool = _is_pickup_action_held()
	# 本帧是否为长按起始帧；只有从未按住转为按住的第一帧才执行即时全量场景组补查，持续期间复用批量缓存。
	var pickup_press_started: bool = pickup_action_held and not _pickup_action_held_last_frame
	_pickup_action_held_last_frame = pickup_action_held
	if _nearby_drop_refresh_remaining <= 0.0:
		_nearby_drop_refresh_remaining = maxf(nearby_drop_refresh_interval, 0.01)
		_refresh_nearby_drop_panel()
		# 宝箱目标选择与掉落物优先级共用同一次分批刷新，长按开始后宝箱自身仍按帧推进精确开启进度。
		_update_loot_chest_interaction(true)
	elif _active_loot_chest != null and is_instance_valid(_active_loot_chest):
		if pickup_action_held:
			# 长按期间继续逐帧复核新出现的地面掉落物，保证掉落物优先级不会因批量刷新而延迟。
			# 长按复核优化补充：仅按下第一帧执行全量场景组扫描，持续期间基于 0.12 秒批量缓存与当前宝箱距离做轻量复核。
			if pickup_press_started:
				_update_loot_chest_interaction()
			else:
				_update_loot_chest_interaction_from_cache()
		else:
			# 松开按键会在当前帧停止进度，未按住期间不重复扫描节点组。
			_refresh_active_loot_chest_state(false)
	elif pickup_press_started:
		# 玩家在两次批量刷新之间按下拾取键时立即补做一次目标选择，避免交互开始产生可感知延迟。
		# 补查频率补充：仅长按起始帧执行本分支，持续按住且无宝箱目标时等待下一次 0.12 秒批量刷新接管目标选择。
		_update_loot_chest_interaction()

	_refresh_combat_input_state()


func _unhandled_input(event: InputEvent) -> void:
	if _is_player_dead or _death_overlay.visible:
		return

	if _is_key_binding_capture_active():
		return

	if _is_supply_extraction_open_event(event):
		_mark_input_as_handled()
		_open_supply_extraction_panel()
		return

	if _is_extraction_return_event(event):
		_mark_input_as_handled()
		_show_success_settlement()
		return

	if event is InputEventKey:
		# 当前键盘事件；取值来自输入系统，默认用于识别界面开关动作，修改会影响背包、地图、暂停和角色展示响应。
		var key_event: InputEventKey = event as InputEventKey
		if _pause_overlay.visible and not _is_combat_developer_menu_visible() and key_event.pressed and not key_event.echo and _try_unlock_combat_developer_menu(key_event):
			_mark_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and _is_toggle_character_showcase_event(key_event):
			if not _pause_overlay.visible and not _is_combat_developer_menu_visible() and (_supply_extraction_overlay == null or not _supply_extraction_overlay.visible):
				_toggle_character_showcase()
				_mark_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and _is_pause_event(key_event):
			if _close_top_interactive_panel():
				_mark_input_as_handled()
				return

			_toggle_pause_menu()
			_mark_input_as_handled()
			return

		if _pause_overlay.visible or _is_character_showcase_visible():
			return

		if key_event.pressed and not key_event.echo and _is_toggle_inventory_event(key_event):
			_toggle_inventory()
			_mark_input_as_handled()
			return

		if key_event.pressed and not key_event.echo and _is_toggle_large_map_event(key_event):
			_toggle_large_map()
			_mark_input_as_handled()
			return

		if key_event.pressed and not key_event.echo and _is_toggle_drop_list_event(key_event):
			_toggle_drop_list_enabled()
			_mark_input_as_handled()
			return

		if key_event.pressed and not key_event.echo and _is_pickup_event(key_event):
			_pickup_nearest_drop()
			_mark_input_as_handled()


func _bind_game_world() -> void:
	_game_world = get_node_or_null(game_world_path)
	_is_training_mode = _resolve_training_mode()
	_is_casual_mode = _resolve_casual_mode()


func _refresh_mode_state_after_game_world_initialized() -> void:
	## 在 GameWorld 应用会话模式后重新读取 HUD 模式状态；保证超频骇入从首帧起使用娱乐模式的离开与拾取规则。
	## 模式扩展补充：同一延后刷新同时应用风险合约的右上角小地图可见性。
	_is_training_mode = _resolve_training_mode()
	_is_casual_mode = _resolve_casual_mode()
	if _mini_map != null:
		_mini_map.visible = not (_game_world != null and _game_world.has_method("is_minimap_disabled_by_mode_extension") and bool(_game_world.call("is_minimap_disabled_by_mode_extension")))
	_bind_hack_protocol_component()
	_refresh_hack_protocol_progress()
	_sync_mode_controls()


func _bind_player_components() -> void:
	_player = get_node_or_null(player_path)
	if _player == null:
		return
	if _player.has_signal("weapon_durability_changed"):
		_player.connect("weapon_durability_changed", Callable(self, "_on_weapon_durability_changed"))
	if _player.has_signal("weapon_attack_succeeded"):
		_player.connect("weapon_attack_succeeded", Callable(self, "_on_weapon_attack_succeeded"))

	_stats_component = _player.get_node_or_null("StatsComponent")
	_shield_component = _player.get_node_or_null("ShieldComponent")
	_equipment_component = _player.get_node_or_null("EquipmentComponent")
	_inventory_component = _player.get_node_or_null("InventoryComponent")
	_input_component = _player.get_node_or_null("InputComponent")
	_ranged_attack_component = _player.get_node_or_null("RangedAttackComponent")
	_melee_attack_component = _player.get_node_or_null("MeleeAttackComponent")
	# 攻击组件冷却接口判定缓存；注入时一次性完成 has_method 查询，每帧遮罩刷新直接使用布尔分支加动态调用。
	_ranged_component_has_cooldown_ratio = _ranged_attack_component != null and _ranged_attack_component.has_method("get_cooldown_ratio")
	_ranged_component_has_cooldown_duration = _ranged_attack_component != null and _ranged_attack_component.has_method("get_cooldown_duration")
	_melee_component_has_cooldown_ratio = _melee_attack_component != null and _melee_attack_component.has_method("get_cooldown_ratio")
	_melee_component_has_cooldown_duration = _melee_attack_component != null and _melee_attack_component.has_method("get_cooldown_duration")
	_active_skill_component = _player.get_node_or_null(active_skill_component_path)
	_hack_protocol_component = _player.get_node_or_null("HackProtocolComponent")

	if _stats_component != null:
		_stats_component.connect("health_changed", Callable(self, "_on_health_changed"))
		_stats_component.connect("energy_changed", Callable(self, "_on_energy_changed"))
		if _stats_component.has_signal("died"):
			_stats_component.connect("died", Callable(self, "_on_player_died"))
		if _stats_component.has_method("is_dead") and bool(_stats_component.call("is_dead")):
			_on_player_died()
	if _shield_component != null and _shield_component.has_signal("shield_changed"):
		_shield_component.connect("shield_changed", Callable(self, "_on_shield_changed"))
	_bind_hack_protocol_component()

	if _equipment_component != null:
		_equipment_component.connect("equipment_changed", Callable(self, "_on_equipment_changed"))

	if _inventory_component != null:
		_inventory_component.connect("inventory_changed", Callable(self, "_on_inventory_changed"))

	if _active_skill_component != null and _active_skill_component.has_signal("skill_loadout_changed"):
		_active_skill_component.connect("skill_loadout_changed", Callable(self, "_on_active_skill_loadout_changed"))


func _bind_hack_protocol_component() -> void:
	## 绑定 GameWorld 在父节点 ready 阶段动态创建的本机协议组件；信号只连接一次。
	if _hack_protocol_component == null and _game_world != null and _game_world.has_method("get_hack_protocol_component"):
		_hack_protocol_component = _game_world.call("get_hack_protocol_component") as Node
	if _hack_protocol_component == null:
		return
	if _hack_protocol_component.has_signal("fragments_changed") and not _hack_protocol_component.is_connected("fragments_changed", Callable(self, "_on_hack_protocol_fragments_changed")):
		_hack_protocol_component.connect("fragments_changed", Callable(self, "_on_hack_protocol_fragments_changed"))
	if _hack_protocol_component.has_signal("offer_ready") and not _hack_protocol_component.is_connected("offer_ready", Callable(self, "_on_hack_protocol_offer_ready")):
		_hack_protocol_component.connect("offer_ready", Callable(self, "_on_hack_protocol_offer_ready"))
	if _hack_protocol_component.has_signal("protocols_changed") and not _hack_protocol_component.is_connected("protocols_changed", Callable(self, "_on_hack_protocols_changed")):
		_hack_protocol_component.connect("protocols_changed", Callable(self, "_on_hack_protocols_changed"))


func _build_hack_protocol_progress() -> void:
	## 在生命能量面板上方创建数据碎片条；扩展未启用时整个分区隐藏。
	if _hack_protocol_progress_panel != null:
		return
	# 底部状态容器；场景固定为 VBoxContainer，缺失时保持 HUD 其他功能可用。
	var bottom_dock: VBoxContainer = get_node_or_null("Root/BottomDock") as VBoxContainer
	if bottom_dock == null:
		return
	_hack_protocol_progress_panel = PanelContainer.new()
	_hack_protocol_progress_panel.name = "HackProtocolProgressPanel"
	_hack_protocol_progress_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI_STYLE_GUIDE.apply_section_panel(_hack_protocol_progress_panel)
	bottom_dock.add_child(_hack_protocol_progress_panel)
	bottom_dock.move_child(_hack_protocol_progress_panel, 0)
	# 分区内容边距；与生命能量面板使用相同紧凑留白。
	var progress_margin: MarginContainer = MarginContainer.new()
	progress_margin.add_theme_constant_override("margin_left", 8)
	progress_margin.add_theme_constant_override("margin_top", 4)
	progress_margin.add_theme_constant_override("margin_right", 8)
	progress_margin.add_theme_constant_override("margin_bottom", 4)
	_hack_protocol_progress_panel.add_child(progress_margin)
	# 文本与进度条纵向布局；文字负责完整溢出量和长按提示，进度条只表达当前阶段比例。
	var progress_layout: VBoxContainer = VBoxContainer.new()
	progress_layout.add_theme_constant_override("separation", 2)
	progress_margin.add_child(progress_layout)
	_hack_protocol_progress_label = Label.new()
	_hack_protocol_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hack_protocol_progress_label.add_theme_font_size_override("font_size", 11)
	progress_layout.add_child(_hack_protocol_progress_label)
	_hack_protocol_progress_bar = ProgressBar.new()
	_hack_protocol_progress_bar.custom_minimum_size = Vector2(0.0, 8.0)
	_hack_protocol_progress_bar.show_percentage = false
	UI_STYLE_GUIDE.apply_semantic_progress_bar(_hack_protocol_progress_bar)
	progress_layout.add_child(_hack_protocol_progress_bar)
	_refresh_hack_protocol_progress()


func _build_hack_protocol_select_overlay() -> void:
	## 构建不暂停游戏的全屏选择遮罩；只有完成三秒长按时才显示。
	if _hack_protocol_select_overlay != null:
		return
	_hack_protocol_select_overlay = Control.new()
	_hack_protocol_select_overlay.name = "HackProtocolSelectOverlay"
	_hack_protocol_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hack_protocol_select_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.add_child(_hack_protocol_select_overlay)
	# 半透明背景；只用于提高战斗中三选一卡片可读性，场景树继续运行。
	var overlay_dim: ColorRect = ColorRect.new()
	overlay_dim.name = "HackProtocolSelectDim"
	overlay_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UI_STYLE_GUIDE.apply_overlay_dim(overlay_dim)
	_hack_protocol_select_overlay.add_child(overlay_dim)
	# 中央候选面板；脚本负责固定候选展示与选择验证。
	var select_panel: Control = HACK_PROTOCOL_SELECT_PANEL_SCRIPT.new() as Control
	if select_panel == null:
		_hack_protocol_select_overlay.visible = false
		return
	select_panel.name = "HackProtocolSelectPanel"
	select_panel.set_anchors_preset(Control.PRESET_CENTER)
	select_panel.offset_left = -HACK_PROTOCOL_SELECT_PANEL_HALF_SIZE.x
	select_panel.offset_top = -HACK_PROTOCOL_SELECT_PANEL_HALF_SIZE.y
	select_panel.offset_right = HACK_PROTOCOL_SELECT_PANEL_HALF_SIZE.x
	select_panel.offset_bottom = HACK_PROTOCOL_SELECT_PANEL_HALF_SIZE.y
	select_panel.connect("protocol_selected", Callable(self, "_on_hack_protocol_selected"))
	select_panel.connect("closed", Callable(self, "_on_hack_protocol_select_closed"))
	_hack_protocol_select_overlay.add_child(select_panel)
	_hack_protocol_select_panel = select_panel
	_hack_protocol_select_overlay.visible = false


func _update_hack_protocol_hold(delta: float) -> void:
	## 推进选择键长按；任一阻塞界面、松键或碎片未满都会立即清空本次进度。
	if not _can_hold_hack_protocol_action() or not Input.is_action_pressed(select_hack_protocol_action):
		if _hack_protocol_hold_elapsed > 0.0:
			_hack_protocol_hold_elapsed = 0.0
			_refresh_hack_protocol_progress()
		return
	_hack_protocol_hold_elapsed = minf(_hack_protocol_hold_elapsed + maxf(delta, 0.0), HackProtocolRules.HOLD_DURATION_SECONDS)
	_refresh_hack_protocol_progress()
	if _hack_protocol_hold_elapsed < HackProtocolRules.HOLD_DURATION_SECONDS:
		return
	_hack_protocol_hold_elapsed = 0.0
	_open_hack_protocol_select()


func _can_hold_hack_protocol_action() -> bool:
	## 判断当前是否允许累计长按；选择窗口本身不暂停战斗，但其他菜单与死亡状态不能后台触发。
	if _hack_protocol_component == null or not _hack_protocol_component.has_method("is_offer_ready") or not bool(_hack_protocol_component.call("is_offer_ready")):
		return false
	if _is_player_dead or _death_overlay.visible or _pause_overlay.visible or _large_map_overlay.visible or _is_shared_inventory_visible() or _is_character_showcase_visible():
		return false
	if _supply_extraction_overlay != null and _supply_extraction_overlay.visible:
		return false
	return _hack_protocol_select_overlay == null or not _hack_protocol_select_overlay.visible


func _open_hack_protocol_select() -> void:
	## 打开三选一窗口并锁定本机战斗输入；不修改 get_tree().paused。
	if _hack_protocol_select_overlay == null or _hack_protocol_select_panel == null or _hack_protocol_component == null:
		return
	if not _hack_protocol_component.has_method("is_offer_ready") or not bool(_hack_protocol_component.call("is_offer_ready")):
		return
	_hack_protocol_select_overlay.visible = true
	if _hack_protocol_select_panel.has_method("present"):
		_hack_protocol_select_panel.call("present", _hack_protocol_component)
	_refresh_combat_input_state()


func _close_hack_protocol_select() -> void:
	## 关闭三选一窗口并恢复本机战斗输入；候选和溢出碎片由组件继续保留。
	if _hack_protocol_select_overlay != null:
		_hack_protocol_select_overlay.visible = false
	if _hack_protocol_select_panel != null and _hack_protocol_select_panel.has_method("dismiss"):
		_hack_protocol_select_panel.call("dismiss")
	_hack_protocol_hold_elapsed = 0.0
	_refresh_hack_protocol_progress()
	_refresh_combat_input_state()


func _refresh_hack_protocol_progress() -> void:
	## 刷新进度条数值与动态绑定提示；文本保留真实溢出碎片，条形比例限制在本阶段需求。
	if _hack_protocol_progress_panel == null or _hack_protocol_progress_label == null or _hack_protocol_progress_bar == null:
		return
	# 扩展开关；优先使用世界公开接口，组件存在作为独立场景预览兜底。
	var extension_enabled: bool = _game_world != null and _game_world.has_method("is_hack_protocol_enabled") and bool(_game_world.call("is_hack_protocol_enabled"))
	if _game_world == null:
		extension_enabled = _hack_protocol_component != null
	_hack_protocol_progress_panel.visible = extension_enabled
	if not extension_enabled or _hack_protocol_component == null:
		return
	# 当前碎片；允许超过需求，取整展示与策划整数奖励口径一致。
	var current_fragments: float = maxf(float(_hack_protocol_component.call("get_current_fragments")), 0.0)
	# 当前需求；至少为 1，防止异常配置导致原生进度条范围无效。
	var required_fragments: float = maxf(float(_hack_protocol_component.call("get_required_fragments")), 1.0)
	_hack_protocol_progress_bar.max_value = required_fragments
	_hack_protocol_progress_bar.value = minf(current_fragments, required_fragments)
	# 当前实际绑定文本；玩家改键、解绑或恢复默认后均从 InputBindings 即时读取。
	var binding_text: String = _get_action_binding_display_text(select_hack_protocol_action)
	if _hack_protocol_component.has_method("is_offer_ready") and bool(_hack_protocol_component.call("is_offer_ready")):
		_hack_protocol_progress_label.text = "数据碎片 %d / %d · 长按 %s 选择协议（%.1f / %.1f 秒）" % [roundi(current_fragments), roundi(required_fragments), binding_text, _hack_protocol_hold_elapsed, HackProtocolRules.HOLD_DURATION_SECONDS]
	else:
		_hack_protocol_progress_label.text = "数据碎片 %d / %d" % [roundi(current_fragments), roundi(required_fragments)]


func _get_action_binding_display_text(action_name: StringName) -> String:
	## 返回动作当前主绑定的人类可读文本；服务缺失时回退 InputMap 第一个事件。
	# 输入绑定服务；负责把键盘与鼠标事件转换成统一显示文本。
	var input_bindings_service: Node = get_tree().root.get_node_or_null("InputBindings")
	if input_bindings_service != null and input_bindings_service.has_method("get_action_display_text"):
		return str(input_bindings_service.call("get_action_display_text", action_name))
	if not InputMap.has_action(action_name) or InputMap.action_get_events(action_name).is_empty():
		return "未绑定"
	# 首个绑定事件；隔离场景缺少服务时使用事件原生文本作为可读兜底。
	var binding_event: InputEvent = InputMap.action_get_events(action_name)[0] as InputEvent
	return binding_event.as_text() if binding_event != null else "未绑定"


func _on_hack_protocol_fragments_changed(_current_fragments: float, _required_fragments: float) -> void:
	## 组件碎片变化回调；参数已由组件规范化，HUD 重新读取完整状态以包含候选就绪信息。
	_refresh_hack_protocol_progress()


func _on_hack_protocol_offer_ready() -> void:
	## 候选生成回调；只更新长按提示，不自动弹出窗口。
	_refresh_hack_protocol_progress()


func _on_hack_protocols_changed(_protocol_ids: Array[String]) -> void:
	## 本机协议变化回调；刷新碎片新需求，已打开的只读面板在下次进入时读取最新快照。
	_refresh_hack_protocol_progress()


func _on_hack_protocol_selected(_protocol_id: String) -> void:
	## 选择成功回调；关闭窗口并显示扣除旧需求、保留溢出后的新进度。
	_close_hack_protocol_select()


func _on_hack_protocol_select_closed() -> void:
	## “稍后选择”回调；只关闭界面，不触发重掷或碎片扣除。
	_close_hack_protocol_select()


func _build_active_skill_bar() -> void:
	## 在屏幕左下角的标准 HUD 分区面板中创建主动技能栏；面板始终位于背包、暂停和结算遮罩下方。
	# 主动技能栏实例；优先实例化检查器场景，缺失时使用脚本兜底以保持隔离场景兼容。
	var skill_bar: Control = active_skill_bar_scene.instantiate() as Control if active_skill_bar_scene != null else ACTIVE_SKILL_BAR_SCRIPT.new() as Control
	if skill_bar == null:
		return
	skill_bar.set("slot_minimum_size", active_skill_slot_size)
	# 技能栏外层面板；复用其他 HUD 分区的背景、弱描边和圆角，不再以独立顶置元素悬浮在菜单之上。
	var skill_panel: PanelContainer = PanelContainer.new()
	skill_panel.name = "ActiveSkillPanel"
	skill_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	skill_panel.position = active_skill_bar_position
	skill_panel.size = active_skill_bar_size
	skill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI_STYLE_GUIDE.apply_section_panel(skill_panel)
	_root_control.add_child(skill_panel)
	# 普通 HUD 绘制顺序；插入旧背包占位面板之前，使之后的背包、大地图、暂停和结算遮罩始终覆盖技能栏。
	if _inventory_panel != null:
		_root_control.move_child(skill_panel, _inventory_panel.get_index())
	_active_skill_bar_panel = skill_panel
	# 技能栏内边距；与武器面板使用相同的紧凑分区结构，内容组件只负责技能槽本身。
	var skill_margin: MarginContainer = MarginContainer.new()
	skill_margin.add_theme_constant_override("margin_left", maxi(active_skill_bar_horizontal_margin, 0))
	skill_margin.add_theme_constant_override("margin_top", maxi(active_skill_bar_vertical_margin, 0))
	skill_margin.add_theme_constant_override("margin_right", maxi(active_skill_bar_horizontal_margin, 0))
	skill_margin.add_theme_constant_override("margin_bottom", maxi(active_skill_bar_vertical_margin, 0))
	skill_panel.add_child(skill_margin)
	skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_margin.add_child(skill_bar)
	_active_skill_bar = skill_bar
	if _active_skill_bar.has_method("configure"):
		_active_skill_bar.call("configure", _active_skill_component)


func _on_active_skill_loadout_changed() -> void:
	## 角色切换后刷新技能名称与空槽状态；技能栏实例保持不变，避免 HUD 布局跳动。
	if _active_skill_bar != null and _active_skill_bar.has_method("refresh"):
		_active_skill_bar.call("refresh")


func _refresh_all() -> void:
	_refresh_stats()
	_rebuild_equipment_slots()
	_refresh_equipment()
	if _shared_backpack_panel != null:
		_shared_backpack_panel.refresh()
	_refresh_cooldown_overlays()


func _build_shared_backpack_panel() -> void:
	# 旧场景面板只作为迁移期占位并永久隐藏；实际功能全部由共享组件提供。
	_inventory_panel.visible = false
	var shared_panel: SharedBackpackPanel = SHARED_BACKPACK_PANEL_SCRIPT.new() as SharedBackpackPanel
	if shared_panel == null:
		return
	shared_panel.configure_context(SharedBackpackPanel.CONTEXT_COMBAT)
	# 临时增益组件；交给共享背包处理消耗品使用，避免 HUD 与共享面板各自维护一套扣除规则。
	var temporary_buff_component: Node = _player.get_node_or_null("TemporaryBuffComponent") if _player != null else null
	shared_panel.configure_runtime_character_components(_stats_component, _equipment_component, temporary_buff_component)
	shared_panel.anchor_left = 0.5
	shared_panel.anchor_top = 0.5
	shared_panel.anchor_right = 0.5
	shared_panel.anchor_bottom = 0.5
	shared_panel.offset_left = -480.0
	shared_panel.offset_top = -310.0
	shared_panel.offset_right = 480.0
	shared_panel.offset_bottom = 310.0
	shared_panel.visible = false
	shared_panel.closed.connect(func() -> void: _set_inventory_visible(false))
	shared_panel.combat_discard_requested.connect(_on_shared_backpack_discard_requested)
	_root_control.add_child(shared_panel)
	_shared_backpack_panel = shared_panel


func _on_shared_backpack_discard_requested(item_resource: Resource, quantity: int) -> void:
	# 武器地面丢弃仍需要真实背包下标；按资源实例定位可避免排序和筛选改变显示位置后丢错物品。
	_combat_action_weapon_source_index = -1
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory != null and global_inventory.has_method("get_backpack_entries"):
		var entries: Array = global_inventory.call("get_backpack_entries")
		for entry_index in range(entries.size()):
			if (entries[entry_index] as Dictionary).get("resource") == item_resource:
				_combat_action_weapon_source_index = entry_index
				break
	_discard_combat_inventory_item(item_resource, quantity)


func _refresh_stats() -> void:
	_character_name_label.text = _get_current_character_display_name()
	if _stats_component == null:
		_health_label.text = "生命 -- / --"
		_energy_label.text = "能量 -- / --"
		_health_bar.value = 0.0
		_shield_overlay.visible = false
		_energy_bar.value = 0.0
		return

	# 当前生命值；取值来自属性组件，默认 0 用于组件缺失兜底，修改会影响生命文本和进度条。
	var current_health: float = float(_stats_component.get("current_health"))
	# 最大生命值；取值来自属性组件，默认 1 防止除零，修改会影响生命文本和进度条上限。
	var max_health: float = maxf(float(_stats_component.get("max_health")), 1.0)
	# 当前能量值；取值来自属性组件，默认 0 用于组件缺失兜底，修改会影响能量文本和进度条。
	var current_energy: float = float(_stats_component.get("current_energy"))
	# 最大能量值；取值来自属性组件，默认 1 防止除零，修改会影响能量文本和进度条上限。
	var max_energy: float = maxf(float(_stats_component.get("max_energy")), 1.0)
	# 当前护盾值；组件缺失时为 0，只有正值才追加到生命文本并启用白色滤镜。
	var current_shield: float = maxf(float(_shield_component.get("current_shield")), 0.0) if _shield_component != null else 0.0

	_health_label.text = "生命 %d / %d  护盾 %d" % [roundi(current_health), roundi(max_health), roundi(current_shield)] if current_shield > 0.0 else "生命 %d / %d" % [roundi(current_health), roundi(max_health)]
	_health_bar.value = current_health / max_health * 100.0
	_shield_overlay.visible = current_shield > 0.0
	_energy_label.text = "能量 %s / %s" % [_format_energy_display_value(current_energy), _format_energy_display_value(max_energy)]
	_energy_bar.value = current_energy / max_energy * 100.0


func _format_energy_display_value(value: float) -> String:
	## 格式化战斗 HUD 能量数值；整数不显示无意义的小数，0.1 精度的非整数值保留一位小数。
	## 显示协议补充：底部战斗 HUD 统一四舍五入为整数，避免自然回复的 0.1 精度结算在玩家界面出现小数点；该格式化不改变实际能量、能量条比例或技能与武器的消耗判定。
	return str(roundi(value))


func _on_shield_changed(_current_shield: float, _max_shield: float) -> void:
	## 护盾变化与生命变化共享同一刷新入口，确保文本和白色滤镜在同一帧同步更新。
	_refresh_stats()


func _rebuild_equipment_slots() -> void:
	_clear_container(_ranged_slots_container)
	_clear_container(_melee_slot_host)
	_ranged_slot_controls.clear()
	_melee_slot_control = null

	if _equipment_component == null or not _equipment_component.has_method("get_ranged_slot_count"):
		return

	# 远程槽数量；取值来自装备组件，默认至少 0，修改会影响 HUD 创建的远程槽数量。
	var slot_count: int = int(_equipment_component.call("get_ranged_slot_count"))

	# 远程槽 UI 创建索引；取值为 0 到 slot_count - 1，默认逐槽生成，修改循环范围会影响装备栏显示数量。
	for slot_index in range(slot_count):
		# 远程槽视图；只显示当前装备快照、选中状态、耐久和冷却，不承载物品卡牌交互。
		var slot_control: Control = _create_combat_weapon_slot_view(ranged_slot_minimum_size)
		_ranged_slots_container.add_child(slot_control)
		_ranged_slot_controls.append(slot_control)

	# 近战槽视图；与技能槽和远程槽复用同一纯展示组件，不接收拖拽或点击。
	var melee_slot_control: Control = _create_combat_weapon_slot_view(melee_slot_minimum_size)
	_melee_slot_host.add_child(melee_slot_control)
	_melee_slot_control = melee_slot_control


func _refresh_equipment() -> void:
	if _equipment_component == null:
		return

	# 当前远程槽索引；取值来自装备组件，默认 0，修改会影响底部远程槽选中高亮。
	var current_slot: int = int(_equipment_component.call("get_current_ranged_slot"))

	# 远程槽刷新索引；取值为控件数组下标，默认逐个刷新纯展示内容与当前手持高亮。
	for slot_index in range(_ranged_slot_controls.size()):
		# 当前槽武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响当前槽显示内容。
		var ranged_weapon: Resource = _equipment_component.call("get_ranged_weapon", slot_index) as Resource
		_configure_combat_weapon_slot_view(_ranged_slot_controls[slot_index], ranged_slot_minimum_size, "远程 %d" % (slot_index + 1), ranged_weapon, "空武器", slot_index == current_slot)

	if _melee_slot_control != null:
		# 当前近战武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响近战槽显示内容。
		var melee_weapon: Resource = _equipment_component.call("get_melee_weapon") as Resource
		_configure_combat_weapon_slot_view(_melee_slot_control, melee_slot_minimum_size, "近战", melee_weapon, "空武器", true)


func _create_combat_weapon_slot_view(display_size: Vector2) -> Control:
	## 创建右下武器栏纯展示槽位；不连接任何拖拽、点击、修复或装备变更请求信号。
	# 共享槽位视图；与主动技能槽使用相同脚本、背景、边框、圆角和文字结构。
	var slot_view: Control = COMBAT_HUD_SLOT_VIEW_SCRIPT.new() as Control
	if slot_view != null:
		slot_view.custom_minimum_size = display_size
		slot_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot_view


func _configure_combat_weapon_slot_view(slot_view: Control, display_size: Vector2, header_text: String, weapon_data: Resource, empty_name: String, selected: bool) -> void:
	## 把武器快照写入纯展示槽位；顶部标题与技能按键复用同一居中区域，资源为空时仍保留槽位职责。
	if slot_view == null:
		return
	# 武器显示名称；损坏武器追加状态文本，空槽使用调用方占位名称。
	var display_name: String = empty_name
	if weapon_data != null:
		display_name = str(weapon_data.get("display_name"))
		if weapon_data.has_method("is_broken") and bool(weapon_data.call("is_broken")):
			display_name += "（损坏）"
	# 武器能耗；读取强化后的最终整数值，空槽不显示辅助信息，零能耗武器仍明确显示 0。
	var energy_consumption: int = maxi(roundi(float(weapon_data.call("get_effective_stat", "energy_consumption"))), 0) if weapon_data != null and weapon_data.has_method("get_effective_stat") else (maxi(roundi(float(weapon_data.get("energy_consumption"))), 0) if weapon_data != null else 0)
	var detail_text: String = "能耗 %d" % energy_consumption if weapon_data != null else ""
	slot_view.call("configure_hud_content", display_size, header_text, display_name, detail_text, weapon_data, 1.0)
	slot_view.call("set_visual_state", selected and weapon_data != null, false)


func _rebuild_inventory_slots() -> void:
	_clear_container(_inventory_equipment_ranged_container)
	_clear_container(_inventory_equipment_melee_host)
	_clear_container(_inventory_weapon_grid)
	_inventory_slot_controls.clear()
	_inventory_equipment_ranged_controls.clear()
	_inventory_equipment_melee_control = null

	_rebuild_inventory_equipment_slots()

	if _inventory_component == null or not _inventory_component.has_method("get_item_entries"):
		_refresh_inventory_title(0, 0)
		return

	# 背包物品条目；包含资源与堆叠数量，查询组件会附加真实来源下标。
	var item_entries: Array = _inventory_component.call("get_item_entries")
	# 当前查询结果；应用主/子分类、关键词、强化属性和排序，不修改全局库存顺序。
	var visible_entries: Array[Dictionary] = InventoryQuery.filter_and_sort_entries(
		item_entries,
		_inventory_primary_category,
		_inventory_filter,
		_inventory_search_edit.text,
		_inventory_stone_attribute_filter,
		_inventory_sort_mode,
		[],
		_inventory_stone_quality_filter
	)
	# 当前筛选页可见物品数量；取值从 0 到背包物品总数，默认逐项统计，修改会影响标题数量显示。
	var visible_item_count: int = 0

	# 背包物品槽索引；取值为背包物品数组下标，默认逐个创建，修改循环范围会影响背包显示数量。
	for visible_index in range(visible_entries.size()):
		# 背包条目；异常值不生成槽位，避免损坏存档阻断整个背包界面。
		var raw_entry: Variant = visible_entries[visible_index]
		if not (raw_entry is Dictionary):
			continue
		# 背包物品资源；取值为武器或强化石，类型决定使用武器槽还是资源方格。
		var item_data: Resource = (raw_entry as Dictionary).get("resource") as Resource
		if item_data == null:
			continue
		# 真实来源下标；排序后的武器拖拽仍需指向 GlobalInventory 原始记录。
		var source_index: int = int((raw_entry as Dictionary).get("source_index", visible_index))

		visible_item_count += 1
		if str(item_data.get("weapon_type")) not in ["ranged", "melee", "hybrid"]:
			# 资源数量；取值 1 到 99，强化石与修复包都使用资源方格显示。
			# 现行限制补充：正式取值为 1 到 10，旧 99 件堆叠在进入战斗前已经拆组。
			var quantity: int = clampi(int((raw_entry as Dictionary).get("quantity", 1)), 1, INVENTORY_LIMITS.MAX_STACK_QUANTITY)
			# 资源方格；复用仓库控件的方形布局，修复包可点击或拖动到武器，强化石仅保留锻造材料属性。
			# 通用模板补充：资源交互规则保持不变，实际显示区域统一为 160×72 物品卡片。
			var resource_slot: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
			resource_slot.call("configure", item_data, "backpack", source_index, false, "", quantity)
			resource_slot.call("set_weapon_slot_visual_style", true)
			# 道具目标选择期间资源不是合法武器目标，统一覆盖灰色滤镜并阻止点击或拖拽。
			resource_slot.call("set_item_selection_state", _pending_combat_stone_resource != null, false, false)
			resource_slot.custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
			resource_slot.connect("item_action_requested", Callable(self, "_on_combat_resource_action_requested"))
			_inventory_weapon_grid.add_child(resource_slot)
			_inventory_slot_controls.append(resource_slot)
		else:
			# 背包武器槽控件；继续使用原有装备、拖拽和丢弃协议。
			var inventory_slot: Control = _create_weapon_slot_control(inventory_slot_minimum_size)
			inventory_slot.call("set_slot_data", "inventory", "inventory", source_index, item_data, false)
			inventory_slot.call("set_empty_text", "空")
			inventory_slot.call("set_weapon_target_selection_state", _pending_combat_stone_resource != null, _can_pending_combat_repair_target(item_data))
			_inventory_weapon_grid.add_child(inventory_slot)
			_inventory_slot_controls.append(inventory_slot)

	_refresh_inventory_title(item_entries.size(), visible_item_count)

func _refresh_inventory_title(item_count: int, visible_item_count: int) -> void:
	# 当前筛选页中文名；取值为“全部”“近战”或“远程”，默认由 _inventory_filter 转换，修改会影响背包标题。
	var filter_label: String = _get_inventory_filter_label()
	if _pending_combat_stone_resource != null:
		_inventory_title_label.text = "请选择背包或装备栏中的一把兼容武器"
	else:
		_inventory_title_label.text = "%s  E关闭  %d / %d组物品" % [filter_label, visible_item_count, item_count]
	if _inventory_cancel_stone_use_button != null:
		_inventory_cancel_stone_use_button.visible = _pending_combat_stone_resource != null


func _rebuild_inventory_equipment_slots() -> void:
	if _equipment_component == null or not _equipment_component.has_method("get_ranged_slot_count"):
		return

	# 背包界面左侧远程槽数量；取值来自装备组件，默认与底部装备栏一致，修改会影响背包装备栏显示数量。
	var slot_count: int = int(_equipment_component.call("get_ranged_slot_count"))
	# 背包界面左侧远程槽索引；取值为 0 到 slot_count - 1，默认逐槽创建，修改循环范围会影响可拖拽装备槽数量。
	for slot_index in range(slot_count):
		# 背包界面远程装备槽控件；取值为 WeaponSlotControl 实例，默认动态创建，修改会影响左侧远程装备显示。
		var slot_control: Control = _create_weapon_slot_control(inventory_slot_minimum_size)
		_inventory_equipment_ranged_container.add_child(slot_control)
		_inventory_equipment_ranged_controls.append(slot_control)

	# 背包界面近战装备槽控件；取值为 WeaponSlotControl 实例，默认单槽创建，修改会影响左侧近战装备显示。
	var melee_slot_control: Control = _create_weapon_slot_control(inventory_slot_minimum_size)
	_inventory_equipment_melee_host.add_child(melee_slot_control)
	_inventory_equipment_melee_control = melee_slot_control
	_build_inventory_armor_slots()
	_refresh_inventory_equipment_slots()


func _build_inventory_armor_slots() -> void:
	# 防具槽宿主；复用近战槽所在左栏，在其下方追加与武器栏同宽的四个部位槽。
	_inventory_armor_slot_buttons.clear()
	var armor_title: Label = Label.new()
	armor_title.text = "装备"
	armor_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_equipment_melee_host.add_child(armor_title)
	for armor_slot in ["head", "body", "legs", "feet"]:
		# 防具槽按钮；点击已装备物品时卸回战斗背包，空槽不响应。
		var armor_control: Control = EQUIPMENT_STORAGE_SLOT_SCRIPT.new() as Control
		armor_control.custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
		armor_control.connect("item_selected", Callable(self, "_on_inventory_armor_item_selected").bind(armor_slot))
		_inventory_equipment_melee_host.add_child(armor_control)
		_inventory_armor_slot_buttons[armor_slot] = armor_control


func _refresh_inventory_equipment_slots() -> void:
	if _equipment_component == null:
		return

	# 背包界面当前远程槽索引；取值来自装备组件，默认用于左侧装备槽高亮，修改会影响当前装备辨识。
	var current_slot: int = int(_equipment_component.call("get_current_ranged_slot"))
	# 背包界面远程槽刷新索引；取值为控件数组下标，默认逐个刷新，修改循环范围会影响左侧装备内容。
	for slot_index in range(_inventory_equipment_ranged_controls.size()):
		# 背包界面当前远程武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响左侧远程槽显示。
		var ranged_weapon: Resource = _equipment_component.call("get_ranged_weapon", slot_index) as Resource
		_inventory_equipment_ranged_controls[slot_index].call("set_slot_data", "equipment", "ranged", slot_index, ranged_weapon, slot_index == current_slot)
		_inventory_equipment_ranged_controls[slot_index].call("set_empty_text", "空远程")
		_inventory_equipment_ranged_controls[slot_index].call("set_weapon_target_selection_state", _pending_combat_stone_resource != null, _can_pending_combat_repair_target(ranged_weapon))

	if _inventory_equipment_melee_control != null:
		# 背包界面当前近战武器资源；取值为 Resource 或 null，默认来自装备组件，修改会影响左侧近战槽显示。
		var melee_weapon: Resource = _equipment_component.call("get_melee_weapon") as Resource
		_inventory_equipment_melee_control.call("set_slot_data", "equipment", "melee", -1, melee_weapon, true)
		_inventory_equipment_melee_control.call("set_empty_text", "空近战")
		_inventory_equipment_melee_control.call("set_weapon_target_selection_state", _pending_combat_stone_resource != null, _can_pending_combat_repair_target(melee_weapon))
	_refresh_inventory_armor_slots()


func _refresh_inventory_armor_slots() -> void:
	# 部位中文名；固定用于槽位空状态和装备名称前缀。
	var slot_labels: Dictionary = {"head": "头部", "body": "躯干", "legs": "腿部", "feet": "脚部"}
	for armor_slot in _inventory_armor_slot_buttons.keys():
		var armor_button: Control = _inventory_armor_slot_buttons[armor_slot] as Control
		var equipment_resource: Resource = _equipment_component.call("get_armor_equipment", armor_slot) as Resource if _equipment_component != null and _equipment_component.has_method("get_armor_equipment") else null
		armor_button.call("configure", str(slot_labels.get(armor_slot, armor_slot)), "armor_" + str(armor_slot), str(armor_slot), equipment_resource, ItemDetailFormatter.build_plain_text(equipment_resource) if equipment_resource != null else "")
		# 修复目标状态；满耐久装备覆盖灰色并不可点击，有耐久缺口时保持可选。
		var repair_selection_active: bool = _pending_combat_stone_resource != null and str(_pending_combat_stone_resource.get("item_kind")) == "repair_kit"
		var repair_selectable: bool = equipment_resource != null and _can_pending_combat_repair_target(equipment_resource)
		armor_button.call("set_weapon_target_selection_state", repair_selection_active, repair_selectable)


func _on_inventory_armor_slot_pressed(armor_slot: String) -> void:
	# 全局库存服务；防具槽点击卸回背包，所有权和存档由统一接口处理。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory == null or not global_inventory.has_method("transfer_equipment_to_storage"):
		return
	# 修复包选择期间点击装备槽会优先使用修复包，不执行卸下。
	var equipment_resource: Resource = _equipment_component.call("get_armor_equipment", armor_slot) as Resource if _equipment_component != null and _equipment_component.has_method("get_armor_equipment") else null
	if _pending_combat_stone_resource != null and str(_pending_combat_stone_resource.get("item_kind")) == "repair_kit":
		if _can_pending_combat_repair_target(equipment_resource):
			_apply_combat_repair(_pending_combat_stone_resource, equipment_resource)
		return
	if bool(global_inventory.call("transfer_equipment_to_storage", "armor_" + armor_slot, "backpack")):
		_refresh_equipment()
		_rebuild_inventory_slots()


func _on_inventory_armor_item_selected(_item_resource: Resource, armor_slot: String) -> void:
	_on_inventory_armor_slot_pressed(armor_slot)


func _refresh_cooldown_overlays() -> void:
	# 远程冷却比例；取值为 0 到 1，默认从远程攻击组件读取，修改会影响远程槽白色 CD 遮罩。
	var ranged_cooldown_ratio: float = _get_component_cooldown_ratio(_ranged_attack_component, _ranged_component_has_cooldown_ratio)
	# 本次远程冷却总时长；高射速武器不显示快速闪烁的遮罩，但实际攻击冷却保持不变。
	var ranged_cooldown_duration: float = _get_component_cooldown_duration(_ranged_attack_component, _ranged_component_has_cooldown_duration)
	if ranged_cooldown_duration <= cooldown_overlay_minimum_duration:
		ranged_cooldown_ratio = 0.0
	if ranged_cooldown_ratio <= 0.0:
		_last_cooling_ranged_slot = -1

	# 远程槽冷却刷新索引；取值为控件数组下标，默认逐槽清理或设置遮罩，修改循环范围会影响 CD 显示目标。
	for slot_index in range(_ranged_slot_controls.size()):
		# 当前远程槽遮罩比例；取值为 0 到 1，默认只给最近开火槽显示，修改会影响远程 CD 归属。
		var slot_cooldown_ratio: float = ranged_cooldown_ratio if slot_index == _last_cooling_ranged_slot else 0.0
		_ranged_slot_controls[slot_index].call("set_cooldown_ratio", slot_cooldown_ratio)

	if _melee_slot_control != null:
		# 近战冷却比例；取值为 0 到 1，默认从近战攻击组件读取，修改会影响近战槽白色 CD 遮罩。
		var melee_slot_cooldown_ratio: float = _get_component_cooldown_ratio(_melee_attack_component, _melee_component_has_cooldown_ratio)
		# 本次近战冷却总时长；高攻速近战不显示快速闪烁的遮罩，但实际攻击冷却保持不变。
		var melee_cooldown_duration: float = _get_component_cooldown_duration(_melee_attack_component, _melee_component_has_cooldown_duration)
		if melee_cooldown_duration <= cooldown_overlay_minimum_duration:
			melee_slot_cooldown_ratio = 0.0
		_melee_slot_control.call("set_cooldown_ratio", melee_slot_cooldown_ratio)


func _create_weapon_slot_control(minimum_size: Vector2) -> Control:
	# 新建武器槽控件；取值为 WeaponSlotControl 实例，默认由预加载脚本创建，修改会影响所有槽位基础控件。
	var slot_control: Control = WEAPON_SLOT_CONTROL_SCRIPT.new() as Control
	# 固定卡片尺寸；本接口只服务背包和装备交互区域，继续使用统一标准物品卡片模板。
	slot_control.custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
	slot_control.connect("drop_received", Callable(self, "_on_weapon_slot_drop_received"))
	slot_control.connect("drag_released_outside", Callable(self, "_on_weapon_slot_drag_released_outside"))
	slot_control.connect("item_selected", Callable(self, "_on_combat_weapon_selected"))
	slot_control.connect("enhancement_drop_received", Callable(self, "_on_combat_enhancement_drop_received"))
	slot_control.connect("repair_kit_drop_received", Callable(self, "_on_combat_repair_kit_drop_received"))
	return slot_control


func _clear_container(container: Node) -> void:
	# 容器旧子节点遍历项；取值来自容器子节点，默认全部移除并排队释放，修改循环来源会影响 UI 重建范围。
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_combat_status_panel() -> void:
	if _root_control == null:
		return

	# 顶部状态容器；取值为 VBoxContainer，默认锚定屏幕顶部中央显示战斗时间和撤离状态。
	var status_container: VBoxContainer = VBoxContainer.new()
	status_container.name = "CombatStatus"
	status_container.anchor_left = 0.5
	status_container.anchor_top = 0.0
	status_container.anchor_right = 0.5
	status_container.anchor_bottom = 0.0
	status_container.offset_left = -120.0
	status_container.offset_top = 12.0
	status_container.offset_right = 120.0
	status_container.offset_bottom = 68.0
	status_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_container.add_theme_constant_override("separation", 4)
	_root_control.add_child(status_container)
	_combat_status_container = status_container

	# 生存时间标签；取值为 Label，默认以两位分钟和两位秒数显示战斗存活时间。
	var survival_timer_label: Label = Label.new()
	survival_timer_label.text = "00:00"
	survival_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	survival_timer_label.add_theme_font_size_override("font_size", 24)
	status_container.add_child(survival_timer_label)
	_survival_timer_label = survival_timer_label

	# 撤离状态标签；取值为 Label，默认撤离点未出现时隐藏，出现后提示驻留进度和撤离确认。
	var extraction_status_label: Label = Label.new()
	extraction_status_label.visible = false
	extraction_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extraction_status_label.add_theme_font_size_override("font_size", 13)
	extraction_status_label.add_theme_color_override("font_color", Color(0.68, 1.0, 0.86, 1.0))
	status_container.add_child(extraction_status_label)
	_extraction_status_label = extraction_status_label

	# 存活怪物数量标签；固定在左上角显示全地图人口，不只统计玩家附近已实例化敌人。
	var monster_count_label: Label = Label.new()
	monster_count_label.name = "MonsterCountLabel"
	monster_count_label.anchor_left = 0.0
	monster_count_label.anchor_top = 0.0
	monster_count_label.anchor_right = 0.0
	monster_count_label.anchor_bottom = 0.0
	monster_count_label.offset_left = 18.0
	monster_count_label.offset_top = 16.0
	monster_count_label.offset_right = 230.0
	monster_count_label.offset_bottom = 48.0
	monster_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monster_count_label.text = "存活怪物：0"
	monster_count_label.add_theme_font_size_override("font_size", 18)
	monster_count_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.78, 1.0))
	monster_count_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.03, 0.9))
	monster_count_label.add_theme_constant_override("outline_size", 4)
	_root_control.add_child(monster_count_label)
	_monster_count_label = monster_count_label


func _build_nearby_drop_panel() -> void:
	_nearby_drop_panel = PanelContainer.new()
	_nearby_drop_panel.name = "NearbyDropPanel"
	_nearby_drop_panel.visible = false
	_nearby_drop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_nearby_drop_panel.custom_minimum_size = Vector2(220.0, 0.0)
	_nearby_drop_panel.anchor_left = 0.0
	_nearby_drop_panel.anchor_top = 0.5
	_nearby_drop_panel.anchor_right = 0.0
	_nearby_drop_panel.anchor_bottom = 0.5
	_nearby_drop_panel.offset_left = 18.0
	_nearby_drop_panel.offset_top = -110.0
	_nearby_drop_panel.offset_right = 238.0
	_nearby_drop_panel.offset_bottom = 110.0
	_nearby_drop_panel.gui_input.connect(_on_nearby_drop_panel_gui_input)
	_root_control.add_child(_nearby_drop_panel)

	# 面板内边距；取值为动态创建的 MarginContainer，默认给掉落物列表留出点击空间。
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.gui_input.connect(_on_nearby_drop_panel_gui_input)
	_nearby_drop_panel.add_child(margin)

	# 面板内容容器；取值为 VBoxContainer，默认把固定标题和可隐藏按钮列表垂直排列。
	var drop_content: VBoxContainer = VBoxContainer.new()
	drop_content.mouse_filter = Control.MOUSE_FILTER_STOP
	drop_content.add_theme_constant_override("separation", 5)
	drop_content.gui_input.connect(_on_nearby_drop_panel_gui_input)
	margin.add_child(drop_content)

	# 列表标题；取值为动态创建 Label，默认在 G 关闭列表后仍保留用于提示附近存在掉落物。
	var title_label: Label = Label.new()
	title_label.text = "附近掉落物  G显示"
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.gui_input.connect(_on_nearby_drop_panel_gui_input)
	drop_content.add_child(title_label)
	_nearby_drop_title_label = title_label

	_nearby_drop_list = VBoxContainer.new()
	_nearby_drop_list.mouse_filter = Control.MOUSE_FILTER_STOP
	_nearby_drop_list.add_theme_constant_override("separation", 5)
	_nearby_drop_list.gui_input.connect(_on_nearby_drop_panel_gui_input)
	drop_content.add_child(_nearby_drop_list)
	_apply_nearby_drop_panel_display_mode()


func _build_supply_extraction_overlay() -> void:
	# 全屏遮罩；暂停时仍处理 UI，深色背景明确当前正在进行安全物资转移。
	var overlay: Control = Control.new()
	overlay.name = "SupplyExtractionOverlay"
	overlay.visible = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.add_child(overlay)
	_supply_extraction_overlay = overlay
	# 遮罩暗层；覆盖全部 HUD 并吸收鼠标输入。
	var dim: ColorRect = ColorRect.new()
	UI_STYLE_GUIDE.apply_overlay_dim(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	# 物资撤离面板；居中固定 920×620 并在暂停模式下继续响应。
	var panel: Control = SUPPLY_EXTRACTION_PANEL_SCRIPT.new() as Control
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -460.0
	panel.offset_top = -310.0
	panel.offset_right = 460.0
	panel.offset_bottom = 310.0
	panel.connect("closed", Callable(self, "_close_supply_extraction_panel"))
	overlay.add_child(panel)
	_supply_extraction_panel = panel
	# 全局库存服务；送回报价、星穹与所有权转移均由该单例处理。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	panel.call("configure", global_inventory)


func _build_character_showcase_view() -> void:
	## 创建战斗内当前角色展示界面；视图复用角色系统场景，HUD 只负责显示、关闭与暂停编排。
	if _root_control == null or _character_showcase_view != null or character_showcase_scene == null:
		return
	# 角色展示实例；进入场景树前切换为仅当前角色模式，避免 ready 阶段创建可见的左侧角色选择栏。
	var showcase_view: Control = character_showcase_scene.instantiate() as Control
	if showcase_view == null:
		return
	showcase_view.name = "CharacterShowcaseView"
	showcase_view.set("display_mode", CHARACTER_SHOWCASE_DISPLAY_MODE)
	showcase_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	showcase_view.process_mode = Node.PROCESS_MODE_ALWAYS
	showcase_view.visible = false
	if showcase_view.has_signal("close_requested"):
		showcase_view.connect("close_requested", Callable(self, "_on_character_showcase_close_requested"))
	_root_control.add_child(showcase_view)
	_character_showcase_view = showcase_view


func _build_combat_developer_overlay() -> void:
	if _root_control == null or _combat_developer_overlay != null:
		return
	# 开发者遮罩；覆盖完整 HUD 并拦截鼠标，场景暂停时仍由 ALWAYS 模式处理交互。
	var developer_overlay: Control = Control.new()
	developer_overlay.name = "CombatDeveloperOverlay"
	developer_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	developer_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	developer_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	developer_overlay.visible = false
	_root_control.add_child(developer_overlay)
	_combat_developer_overlay = developer_overlay
	# 开发者背景遮罩；使用深色半透明背景把战斗调试菜单与暂停地图分离。
	var developer_dim: ColorRect = ColorRect.new()
	developer_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(developer_dim)
	developer_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	developer_overlay.add_child(developer_dim)
	# 战斗开发者菜单；复用局外组件，但隐藏星穹与仓库操作并显示无限属性和训练工具。
	var developer_menu: Control = DEVELOPER_MENU_SCRIPT.new() as Control
	developer_menu.anchor_left = 0.5
	developer_menu.anchor_top = 0.5
	developer_menu.anchor_right = 0.5
	developer_menu.anchor_bottom = 0.5
	developer_menu.offset_left = -combat_developer_menu_half_size.x
	developer_menu.offset_top = -combat_developer_menu_half_size.y
	developer_menu.offset_right = combat_developer_menu_half_size.x
	developer_menu.offset_bottom = combat_developer_menu_half_size.y
	developer_menu.connect("closed", Callable(self, "_on_combat_developer_menu_closed"))
	developer_menu.connect("infinite_health_toggled", Callable(self, "_on_developer_infinite_health_toggled"))
	developer_menu.connect("infinite_energy_toggled", Callable(self, "_on_developer_infinite_energy_toggled"))
	developer_menu.connect("weapon_durability_consumption_toggled", Callable(self, "_on_developer_weapon_durability_consumption_toggled"))
	developer_menu.connect("training_settings_requested", Callable(self, "_on_developer_training_settings_requested"))
	developer_overlay.add_child(developer_menu)
	_combat_developer_menu = developer_menu
	developer_menu.call("configure_combat_context", _is_infinite_health_enabled(), _is_infinite_energy_enabled(), _is_weapon_durability_consumption_disabled_by_debug())


func _refresh_nearby_drop_panel() -> void:
	_nearby_drop_cache.clear()
	if _nearby_drop_panel == null or _nearby_drop_list == null:
		return

	if not _can_pickup_nearby_drops():
		_hide_nearby_drop_panel()
		return

	# 附近掉落物列表；元素为 WeaponDrop Node2D，默认按距离从近到远排序。
	var nearby_drops: Array[Node2D] = _get_nearby_weapon_drops()
	_nearby_drop_cache = nearby_drops
	if nearby_drops.is_empty():
		_hide_nearby_drop_panel()
		return

	_nearby_drop_panel.visible = true
	_refresh_nearby_drop_title()
	_apply_nearby_drop_panel_display_mode()
	if not _drop_list_enabled:
		_clear_container(_nearby_drop_list)
		_nearby_drop_list.visible = false
		_nearby_drop_buttons.clear()
		_nearby_drop_signature.clear()
		return

	_nearby_drop_list.visible = true
	# 新掉落物列表签名；元素为掉落物实例、名称和位置，默认用于判断是否需要重建按钮节点。
	# 签名结构补充：条目为可直接比较的数组，整体相等比较逐项进行，判定语义与原字符串签名一致。
	var next_signature: Array = _get_nearby_drop_signature(nearby_drops)
	if _nearby_drop_panel.visible and _nearby_drop_signature == next_signature:
		return

	_clear_container(_nearby_drop_list)
	_nearby_drop_buttons.clear()
	_nearby_drop_signature = next_signature

	# 附近掉落物遍历项；取值为按距离排序后的 WeaponDrop，默认逐个创建拾取按钮。
	for drop_node in nearby_drops:
		# 掉落物按钮；取值为动态创建 Button，默认点击后尝试拾取对应掉落物。
		var pickup_button: Button = Button.new()
		pickup_button.text = _get_drop_button_text(drop_node)
		pickup_button.focus_mode = Control.FOCUS_NONE
		pickup_button.mouse_filter = Control.MOUSE_FILTER_STOP
		pickup_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		pickup_button.gui_input.connect(Callable(self, "_on_pickup_drop_button_gui_input").bind(drop_node))
		pickup_button.button_down.connect(Callable(self, "_on_pickup_drop_button_pressed").bind(drop_node))
		_nearby_drop_list.add_child(pickup_button)
		_nearby_drop_buttons.append(pickup_button)


func _hide_nearby_drop_panel() -> void:
	if _nearby_drop_panel != null:
		_nearby_drop_panel.visible = false

	if _nearby_drop_list != null:
		_clear_container(_nearby_drop_list)
		_nearby_drop_list.visible = true

	_nearby_drop_buttons.clear()
	_nearby_drop_signature.clear()


func _can_pickup_nearby_drops() -> bool:
	return not _is_player_dead and not _inventory_panel.visible and not _large_map_overlay.visible and not _pause_overlay.visible and not _death_overlay.visible


func _get_nearby_weapon_drops() -> Array[Node2D]:
	# 候选掉落物列表；元素为 Node2D，默认从 item_drops 组筛选玩家拾取范围内的武器或资源。
	var candidate_drops: Array[Node2D] = []
	if _player == null:
		return candidate_drops

	# 组内掉落物遍历项；取值来自场景树 item_drops 组，默认只接收有效 Node2D。
	for raw_drop in get_tree().get_nodes_in_group("item_drops"):
		if not (raw_drop is Node2D):
			continue

		# 掉落物节点；取值为 Node2D，默认用于计算与玩家的距离。
		var drop_node: Node2D = raw_drop as Node2D
		if not _is_drop_in_pickup_range(drop_node):
			continue

		candidate_drops.append(drop_node)

	# 排序后的掉落物列表；元素为 Node2D，默认按距离从近到远选择有限数量。
	var sorted_drops: Array[Node2D] = []
	while not candidate_drops.is_empty() and sorted_drops.size() < max_nearby_drop_buttons:
		# 最近候选索引；取值为 candidate_drops 的有效下标，默认用于逐个取出最近掉落物。
		var nearest_index: int = _find_nearest_drop_index(candidate_drops)
		sorted_drops.append(candidate_drops[nearest_index])
		candidate_drops.remove_at(nearest_index)

	return sorted_drops


func _update_loot_chest_interaction(use_refreshed_drop_cache: bool = false) -> void:
	## 更新宝箱交互目标；批量 HUD 刷新可复用刚计算的掉落物列表，输入即时补查则重新读取场景组。
	if not _can_pickup_nearby_drops():
		_set_active_loot_chest(null, false)
		return
	# 拾取优先级；只要周围存在可拾取掉落物，长按 F 不会同时推进宝箱开启进度。
	# 本次附近掉落物；批量刷新路径读取同批缓存，输入即时路径重新查询场景组。
	var nearby_drops: Array[Node2D] = _nearby_drop_cache if use_refreshed_drop_cache else _get_nearby_weapon_drops()
	if not nearby_drops.is_empty():
		_set_active_loot_chest(null, false)
		return
	# 最近宝箱；进入范围后立即显示提示，只有实际按住拾取键时才切换为进度条并推进开启。
	var nearest_chest: Node2D = _get_nearest_interactable_loot_chest()
	_set_active_loot_chest(nearest_chest, nearest_chest != null and _is_pickup_action_held())


func _update_loot_chest_interaction_from_cache() -> void:
	## 长按持续期间的轻量复核；不再扫描 item_drops 与 loot_chests 场景组，掉落物优先级基于最近一次 0.12 秒批量缓存，当前宝箱的有效性与交互范围仍逐帧校验。
	if not _can_pickup_nearby_drops():
		_set_active_loot_chest(null, false)
		return
	# 缓存掉落物遍历项；批量缓存中仍存活的掉落物保持拾取优先级，已被拾取释放的节点不会错误打断宝箱开启。
	for cached_drop in _nearby_drop_cache:
		if cached_drop != null and is_instance_valid(cached_drop):
			_set_active_loot_chest(null, false)
			return
	if _active_loot_chest == null or not is_instance_valid(_active_loot_chest):
		_set_active_loot_chest(null, false)
		return
	# 当前宝箱交互半径；与全量扫描使用相同的宝箱配置读取规则，接口缺失时回退 HUD 拾取距离。
	var active_chest_interaction_distance: float = float(_active_loot_chest.call("get_interaction_radius")) if _active_loot_chest.has_method("get_interaction_radius") else nearby_drop_pickup_range
	# 玩家到当前宝箱距离平方；玩家缺失时按无穷大处理，离开交互范围的当前帧立即取消开启进度，保持原有范围语义。
	var active_chest_distance_squared: float = _active_loot_chest.global_position.distance_squared_to((_player as Node2D).global_position) if _player != null else INF
	if active_chest_distance_squared > active_chest_interaction_distance * active_chest_interaction_distance:
		_set_active_loot_chest(null, false)
		return
	_refresh_active_loot_chest_state(true)


func _get_nearest_interactable_loot_chest() -> Node2D:
	if _player == null:
		return null
	# 最近宝箱；从 loot_chests 组读取，按宝箱自身交互半径和玩家距离共同筛选。
	var nearest_chest: Node2D
	# 最近宝箱距离；默认无穷大，遇到更近合法目标时持续缩小。
	# 最近宝箱距离平方；默认无穷大，排序结果与真实距离一致且避免候选遍历开方。
	var nearest_distance_squared: float = INF
	for raw_chest in get_tree().get_nodes_in_group("loot_chests"):
		if not (raw_chest is Node2D) or not is_instance_valid(raw_chest):
			continue
		# 当前宝箱节点；用于读取位置和自定义交互半径。
		var chest_node: Node2D = raw_chest as Node2D
		# 当前交互半径；优先读取宝箱配置，接口缺失时回退 HUD 拾取距离。
		var interaction_distance: float = float(chest_node.call("get_interaction_radius")) if chest_node.has_method("get_interaction_radius") else nearby_drop_pickup_range
		# 玩家到当前宝箱距离；用于范围校验和最近目标排序。
		# 玩家到当前宝箱距离平方；用于范围校验和最近目标排序。
		var chest_distance_squared: float = chest_node.global_position.distance_squared_to((_player as Node2D).global_position)
		if chest_distance_squared <= interaction_distance * interaction_distance and chest_distance_squared < nearest_distance_squared:
			nearest_distance_squared = chest_distance_squared
			nearest_chest = chest_node
	return nearest_chest


func _set_active_loot_chest(chest_node: Node2D, opening: bool) -> void:
	if _active_loot_chest == chest_node:
		_refresh_active_loot_chest_state(opening)
		return
	if _active_loot_chest != null and is_instance_valid(_active_loot_chest):
		if _active_loot_chest.has_method("set_open_interaction_active"):
			_active_loot_chest.call("set_open_interaction_active", false, null)
		if _active_loot_chest.has_method("set_interaction_prompt_visible"):
			_active_loot_chest.call("set_interaction_prompt_visible", false)
	_active_loot_chest = chest_node
	_active_loot_chest_opening = false
	_has_active_loot_chest_opening_state = false
	_refresh_active_loot_chest_state(opening)


func _refresh_active_loot_chest_state(opening: bool) -> void:
	if _active_loot_chest == null or not is_instance_valid(_active_loot_chest):
		_active_loot_chest_opening = false
		_has_active_loot_chest_opening_state = false
		return
	if _has_active_loot_chest_opening_state and _active_loot_chest_opening == opening:
		return
	_active_loot_chest_opening = opening
	_has_active_loot_chest_opening_state = true
	if _active_loot_chest.has_method("set_open_interaction_active"):
		_active_loot_chest.call("set_open_interaction_active", opening, _player as Node2D if opening else null)
	if _active_loot_chest.has_method("set_interaction_prompt_visible"):
		_active_loot_chest.call("set_interaction_prompt_visible", not opening)


func _is_pickup_action_held() -> bool:
	if InputMap.has_action(pickup_action) and Input.is_action_pressed(pickup_action):
		return true
	# 物理键兜底；只有动作缺失或未显式解绑时才继续识别默认 F 键。
	return _should_use_physical_fallback(pickup_action) and Input.is_physical_key_pressed(KEY_F)


func _find_nearest_drop_index(drop_nodes: Array[Node2D]) -> int:
	# 最近索引；取值为 drop_nodes 的有效下标，默认 0 用于初始化比较。
	var nearest_index: int = 0
	# 最近距离；取值为玩家到当前最近掉落物的距离，默认用于排序比较。
	# 最近距离平方；取值为玩家到当前最近掉落物的平方距离，排序结果与真实距离一致且避免候选遍历开方。
	var nearest_distance_squared: float = _get_drop_distance_squared(drop_nodes[0])
	# 掉落物索引；取值从 1 到数组末尾，默认跳过已经作为初始值的第一个元素。
	for drop_index in range(1, drop_nodes.size()):
		# 当前距离；取值为玩家到当前掉落物距离，默认用于更新最近索引。
		# 当前距离平方；只用于大小比较，不改变最终按距离从近到远的顺序。
		var current_distance_squared: float = _get_drop_distance_squared(drop_nodes[drop_index])
		if current_distance_squared < nearest_distance_squared:
			nearest_distance_squared = current_distance_squared
			nearest_index = drop_index

	return nearest_index


func _is_drop_in_pickup_range(drop_node: Node2D) -> bool:
	if _player == null or drop_node == null or not is_instance_valid(drop_node):
		return false

	# 掉落物拾取半径；取值来自掉落物自身或 HUD 默认范围，默认两者取较小值避免远距离误拾取。
	var drop_pickup_radius: float = nearby_drop_pickup_range
	if drop_node.has_method("get_pickup_radius"):
		drop_pickup_radius = minf(drop_pickup_radius, maxf(float(drop_node.call("get_pickup_radius")), 1.0))

	return _get_drop_distance_squared(drop_node) <= drop_pickup_radius * drop_pickup_radius


func _get_drop_distance_squared(drop_node: Node2D) -> float:
	## 返回玩家到掉落物的平方距离；附近筛选与排序只比较大小，不需要为每个候选执行平方根计算。
	if _player == null or drop_node == null:
		return INF

	return (_player as Node2D).global_position.distance_squared_to(drop_node.global_position)


func _get_drop_button_text(drop_node: Node2D) -> String:
	# 掉落物名称；取值来自 WeaponDrop.get_pickup_display_name，默认用于按钮文本。
	var drop_name: String = "未知武器"
	if drop_node.has_method("get_pickup_display_name"):
		drop_name = str(drop_node.call("get_pickup_display_name"))

	return drop_name


func _refresh_nearby_drop_title() -> void:
	if _nearby_drop_title_label == null:
		return

	_nearby_drop_title_label.text = "附近掉落物  F拾取  G关闭" if _drop_list_enabled else "附近掉落物  G显示"


func _apply_nearby_drop_panel_display_mode() -> void:
	if _nearby_drop_panel == null:
		return
	# 当前面板高度；展开时容纳按钮列表，收起时只包裹标题和边距，不保留完整列表背景。
	var panel_height: float = maxf(nearby_drop_expanded_height if _drop_list_enabled else nearby_drop_collapsed_height, 1.0)
	_nearby_drop_panel.custom_minimum_size = Vector2(220.0, panel_height)
	_nearby_drop_panel.offset_top = -panel_height * 0.5
	_nearby_drop_panel.offset_bottom = panel_height * 0.5


func _get_nearby_drop_signature(drop_nodes: Array[Node2D]) -> Array:
	# 掉落物列表签名；元素为实例、名称和位置组成的字符串，默认用于判断 UI 列表是否需要重建。
	# 签名结构补充：改为可比较的数组条目，消除每 0.12 秒批量刷新为每个掉落物执行的字符串格式化分配。
	var signature: Array = []
	# 签名遍历项；取值为当前附近掉落物节点，默认按显示顺序写入。
	for drop_node in drop_nodes:
		# 掉落物显示名；取值来自按钮文本，默认用于武器资源变化时触发列表重建。
		var drop_display_name: String = _get_drop_button_text(drop_node)
		# 掉落物签名文本；取值包含实例、名称和固定世界位置，默认避免相同实例内容变化时列表不刷新。
		# 签名条目补充：以 [实例编号, 显示名称, 取整X, 取整Y] 数组承载相同判定信息，逐项比较代替字符串拼接。
		var drop_signature: Array = [
			int(drop_node.get_instance_id()),
			drop_display_name,
			roundi(drop_node.global_position.x),
			roundi(drop_node.global_position.y),
		]
		signature.append(drop_signature)

	return signature


func _toggle_inventory() -> void:
	_set_inventory_visible(not _is_shared_inventory_visible())


func _is_shared_inventory_visible() -> bool:
	## 背包显示状态统一入口；避免战斗逻辑继续依赖已经停用的旧场景节点。
	return _shared_backpack_panel != null and _shared_backpack_panel.visible


func _set_inventory_visible(visible: bool) -> void:
	if visible and _large_map_overlay.visible:
		_large_map_overlay.visible = false

	_inventory_panel.visible = false
	if _shared_backpack_panel != null:
		_shared_backpack_panel.visible = visible
	if visible:
		_shared_backpack_panel.refresh()
	else:
		_pending_combat_stone_resource = null
		_combat_stone_return_view_pending = false
		_combat_action_stone_resource = null
		_combat_action_weapon_resource = null
		_combat_action_weapon_source_index = -1
		if _inventory_cancel_stone_use_button != null:
			_inventory_cancel_stone_use_button.visible = false
		_refresh_equipment()

	# 背包暂停规则；打开时立即暂停战斗，关闭时只有其他暂停型界面仍显示才继续保持暂停。
	var should_keep_paused: bool = visible or _pause_overlay.visible or _is_character_showcase_visible() or (_supply_extraction_overlay != null and _supply_extraction_overlay.visible)
	_set_battle_tree_paused(should_keep_paused)

	_refresh_combat_input_state()


func _toggle_large_map() -> void:
	_set_large_map_visible(not _large_map_overlay.visible)


func _set_large_map_visible(visible: bool) -> void:
	if visible and _is_shared_inventory_visible():
		_set_inventory_visible(false)

	_large_map_overlay.visible = visible
	_refresh_combat_input_state()


func _toggle_character_showcase() -> void:
	_set_character_showcase_visible(not _is_character_showcase_visible())


func _is_character_showcase_visible() -> bool:
	## 返回战斗内角色展示状态；界面未创建时安全返回 false。
	return _character_showcase_view != null and _character_showcase_view.visible


func _set_character_showcase_visible(visible: bool) -> void:
	## 切换当前角色展示并同步暂停状态；打开前关闭背包和大地图，关闭后恢复战斗运行。
	if _character_showcase_view == null or _is_player_dead:
		return
	if visible:
		_set_inventory_visible(false)
		_set_large_map_visible(false)
		_character_showcase_view.visible = true
		if _character_showcase_view.has_method("refresh_current_character"):
			_character_showcase_view.call("refresh_current_character")
		if _character_showcase_view.has_method("focus_default_control"):
			_character_showcase_view.call("focus_default_control")
	else:
		_character_showcase_view.visible = false
	_set_battle_tree_paused(visible)
	_refresh_combat_input_state()


func _refresh_combat_input_state() -> void:
	# 战斗输入启用状态；取值由背包、大地图、角色展示、暂停菜单和掉落物 UI 共同决定，默认任意交互界面打开都会禁用战斗输入。
	var combat_input_enabled: bool = not _is_shared_inventory_visible() and not _large_map_overlay.visible and not _is_character_showcase_visible() and not _pause_overlay.visible and not _death_overlay.visible and (_supply_extraction_overlay == null or not _supply_extraction_overlay.visible) and (_hack_protocol_select_overlay == null or not _hack_protocol_select_overlay.visible) and not _is_player_dead and not _should_drop_ui_block_combat_input()
	if _has_combat_input_enabled_state and _last_combat_input_enabled == combat_input_enabled:
		return

	_has_combat_input_enabled_state = true
	_last_combat_input_enabled = combat_input_enabled
	_set_combat_input_enabled(combat_input_enabled)


func _set_combat_input_enabled(enabled: bool) -> void:
	if _input_component == null or not _input_component.has_method("set_combat_input_enabled"):
		return

	_input_component.call("set_combat_input_enabled", enabled)


func _refresh_combat_status() -> void:
	if _monster_count_label != null:
		# 当前全地图存活怪物数量；由 GameWorld 虚拟人口管理器提供，远处未实例化敌人同样计入。
		var alive_monster_count: int = _get_alive_monster_count()
		if alive_monster_count != _last_alive_monster_count:
			_last_alive_monster_count = alive_monster_count
			_monster_count_label.text = "存活怪物：%d" % alive_monster_count

	if _survival_timer_label != null:
		# 当前存活整秒数；取值为非负整数，默认只在数值变化时刷新 Label 文本。
		var survival_time_whole_seconds: int = maxi(floori(_get_survival_time_seconds()), 0)
		if survival_time_whole_seconds != _last_survival_time_whole_seconds:
			_last_survival_time_whole_seconds = survival_time_whole_seconds
			_survival_timer_label.text = _format_survival_time(float(survival_time_whole_seconds))

	_refresh_extraction_status()


func _get_survival_time_seconds() -> float:
	if _game_world != null and _game_world.has_method("get_survival_time_seconds"):
		return maxf(float(_game_world.call("get_survival_time_seconds")), 0.0)

	return 0.0


func _get_alive_monster_count() -> int:
	if _game_world != null and _game_world.has_method("get_alive_monster_count"):
		return maxi(int(_game_world.call("get_alive_monster_count")), 0)
	return 0


func _format_survival_time(total_seconds: float) -> String:
	# 总秒数整数；取值为非负秒数向下取整，默认用于稳定显示 mm:ss。
	var total_whole_seconds: int = maxi(floori(total_seconds), 0)
	# 分钟数；取值为总秒数除以 60，默认允许超过两位以支持长时间战斗。
	var minute_count: int = floori(float(total_whole_seconds) / 60.0)
	# 秒数；取值为 0 到 59，默认显示两位补零。
	var second_count: int = total_whole_seconds % 60
	return "%02d:%02d" % [minute_count, second_count]


func _refresh_extraction_status() -> void:
	if _extraction_status_label == null:
		return

	if _game_world == null:
		_set_extraction_status(false, "")
		return
	# 物资撤离点驻留提示优先显示；正式撤离点尚未生成时仍可查看 3 秒送回准备进度。
	var inside_supply_extraction: bool = _game_world.has_method("is_player_inside_supply_extraction_area") and bool(_game_world.call("is_player_inside_supply_extraction_area"))
	# 正式撤离点生成状态；没有物资撤离驻留时决定顶部提示是否继续显示。
	var regular_extraction_spawned: bool = _game_world.has_method("has_extraction_point_spawned") and bool(_game_world.call("has_extraction_point_spawned"))
	if not inside_supply_extraction and not regular_extraction_spawned:
		_set_extraction_status(false, "")
		return

	_set_extraction_status(true, _get_extraction_status_text())


func _set_extraction_status(visible: bool, status_text: String) -> void:
	if _last_extraction_status_visible != visible:
		_last_extraction_status_visible = visible
		_extraction_status_label.visible = visible

	if visible and _last_extraction_status_text != status_text:
		_last_extraction_status_text = status_text
		_extraction_status_label.text = status_text
	elif not visible:
		_last_extraction_status_text = ""


func _get_extraction_status_text() -> String:
	if _game_world != null and _game_world.has_method("is_player_inside_supply_extraction_area") and bool(_game_world.call("is_player_inside_supply_extraction_area")):
		if _game_world.has_method("is_supply_extraction_ready") and bool(_game_world.call("is_supply_extraction_ready")):
			return "物资撤离就绪  按冲刺打开送回面板"
		# 物资撤离驻留总时长；默认 3 秒，接口缺失时使用同一玩法兜底值。
		var supply_duration: float = maxf(float(_game_world.call("get_supply_extraction_hold_duration_seconds")), 0.1) if _game_world.has_method("get_supply_extraction_hold_duration_seconds") else 3.0
		# 当前驻留进度；限制在 0 到总时长，避免帧延迟显示超出分母。
		var supply_elapsed: float = clampf(float(_game_world.call("get_supply_extraction_hold_elapsed_seconds")), 0.0, supply_duration) if _game_world.has_method("get_supply_extraction_hold_elapsed_seconds") else 0.0
		return "物资撤离准备  %d / %d秒" % [ceili(supply_elapsed), ceili(supply_duration)]
	if _is_extraction_ready_to_leave():
		return "撤离就绪  按冲刺返回"

	# 是否在撤离范围内；取值来自 GameWorld，默认用于区分驻留倒计时和地图提示。
	var is_inside_extraction_area: bool = false
	if _game_world != null and _game_world.has_method("is_player_inside_extraction_area"):
		is_inside_extraction_area = bool(_game_world.call("is_player_inside_extraction_area"))
	if not is_inside_extraction_area:
		if _is_extraction_point_marked_on_map():
			return "撤离点已在地图上标记"

		return "撤离点已出现"

	# 撤离驻留时长；取值来自 GameWorld，默认至少 1 秒用于显示倒计时分母。
	var hold_duration: float = 1.0
	if _game_world != null and _game_world.has_method("get_extraction_hold_duration_seconds"):
		hold_duration = maxf(float(_game_world.call("get_extraction_hold_duration_seconds")), 1.0)

	# 已驻留时长；取值来自 GameWorld，默认限制到 0 到驻留时长。
	var hold_elapsed: float = 0.0
	if _game_world != null and _game_world.has_method("get_extraction_hold_elapsed_seconds"):
		hold_elapsed = clampf(float(_game_world.call("get_extraction_hold_elapsed_seconds")), 0.0, hold_duration)

	return "撤离准备  %d / %d秒" % [ceili(hold_elapsed), ceili(hold_duration)]


func _is_extraction_return_event(event: InputEvent) -> bool:
	if not _can_process_extraction_input() or not _is_extraction_ready_to_leave():
		return false

	if event is InputEventKey:
		# 撤离键盘事件；取值来自输入系统，默认只响应非 echo 的按下事件。
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		if _should_use_physical_fallback(extraction_action) and key_event.physical_keycode == KEY_SPACE:
			return true
	elif event is InputEventMouseButton:
		# 撤离鼠标事件；取值来自输入系统，默认支持玩家把冲刺动作绑定到鼠标按钮。
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed:
			return false
	else:
		return false

	return InputMap.has_action(extraction_action) and Input.is_action_just_pressed(extraction_action)


func _is_supply_extraction_open_event(event: InputEvent) -> bool:
	if not _can_process_extraction_input() or _game_world == null or not _game_world.has_method("is_supply_extraction_ready") or not bool(_game_world.call("is_supply_extraction_ready")):
		return false
	if event is InputEventKey:
		# 物资撤离键盘事件；只响应非 echo 的按下事件，并兼容默认空格物理键兜底。
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		if _should_use_physical_fallback(extraction_action) and key_event.physical_keycode == KEY_SPACE:
			return true
	elif event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed:
			return false
	else:
		return false
	return InputMap.has_action(extraction_action) and Input.is_action_just_pressed(extraction_action)


func _can_process_extraction_input() -> bool:
	return not _is_player_dead and not _inventory_panel.visible and not _large_map_overlay.visible and not _is_character_showcase_visible() and not _pause_overlay.visible and not _death_overlay.visible and (_supply_extraction_overlay == null or not _supply_extraction_overlay.visible)


func _is_extraction_ready_to_leave() -> bool:
	if _game_world == null or not _game_world.has_method("is_extraction_ready_to_leave"):
		return false

	return bool(_game_world.call("is_extraction_ready_to_leave"))


func _is_extraction_point_marked_on_map() -> bool:
	if _game_world == null or not _game_world.has_method("is_extraction_point_marked_on_map"):
		return false

	return bool(_game_world.call("is_extraction_point_marked_on_map"))


func _bind_inventory_filter_buttons() -> void:
	_inventory_filter_all_button.toggle_mode = true
	_inventory_filter_melee_button.toggle_mode = true
	_inventory_filter_ranged_button.toggle_mode = true
	_inventory_filter_all_button.connect("pressed", Callable(self, "_on_inventory_filter_all_pressed"))
	_inventory_filter_melee_button.connect("pressed", Callable(self, "_on_inventory_filter_melee_pressed"))
	_inventory_filter_ranged_button.connect("pressed", Callable(self, "_on_inventory_filter_ranged_pressed"))
	_inventory_filter_all_button.text = "全部"
	_inventory_filter_melee_button.text = "近战"
	_inventory_filter_ranged_button.text = "远程"
	# 强化石按钮；追加到原筛选栏，作为资源分类当前唯一子类入口。
	var filter_parent: HBoxContainer = _inventory_filter_all_button.get_parent() as HBoxContainer
	if filter_parent != null:
		_inventory_filter_stones_button = Button.new()
		_inventory_filter_stones_button.text = "强化石"
		_inventory_filter_stones_button.toggle_mode = true
		_inventory_filter_stones_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_inventory_filter_stones_button.pressed.connect(_on_inventory_filter_stones_pressed)
		filter_parent.add_child(_inventory_filter_stones_button)
		_inventory_filter_items_button = Button.new()
		_inventory_filter_items_button.text = "道具"
		_inventory_filter_items_button.toggle_mode = true
		_inventory_filter_items_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_inventory_filter_items_button.pressed.connect(_on_inventory_filter_items_pressed)
		filter_parent.add_child(_inventory_filter_items_button)
		# 头部装备按钮；装备主分类激活时按固定部位筛选背包装备。
		_inventory_filter_equipment_head_button = _create_inventory_subcategory_button("头部", INVENTORY_FILTER_EQUIPMENT_HEAD)
		filter_parent.add_child(_inventory_filter_equipment_head_button)
		# 躯干装备按钮；装备主分类激活时按固定部位筛选背包装备。
		_inventory_filter_equipment_body_button = _create_inventory_subcategory_button("躯干", INVENTORY_FILTER_EQUIPMENT_BODY)
		filter_parent.add_child(_inventory_filter_equipment_body_button)
		# 腿部装备按钮；装备主分类激活时按固定部位筛选背包装备。
		_inventory_filter_equipment_legs_button = _create_inventory_subcategory_button("腿部", INVENTORY_FILTER_EQUIPMENT_LEGS)
		filter_parent.add_child(_inventory_filter_equipment_legs_button)
		# 脚部装备按钮；装备主分类激活时按固定部位筛选背包装备。
		_inventory_filter_equipment_feet_button = _create_inventory_subcategory_button("脚部", INVENTORY_FILTER_EQUIPMENT_FEET)
		filter_parent.add_child(_inventory_filter_equipment_feet_button)

		# 背包内容容器；查询栏和一级分类栏会插入现有二级分类栏之前。
		var backpack_content: VBoxContainer = filter_parent.get_parent() as VBoxContainer
		if backpack_content != null:
			# 查询栏；提供关键词搜索、排序和强化属性筛选。
			var query_bar: HBoxContainer = HBoxContainer.new()
			query_bar.add_theme_constant_override("separation", 5)
			backpack_content.add_child(query_bar)
			backpack_content.move_child(query_bar, filter_parent.get_index())
			_inventory_search_edit = LineEdit.new()
			_inventory_search_edit.placeholder_text = "搜索物品或词条"
			_inventory_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_inventory_search_edit.text_changed.connect(_on_inventory_search_changed)
			query_bar.add_child(_inventory_search_edit)
			_inventory_sort_option = OptionButton.new()
			_inventory_sort_option.custom_minimum_size = Vector2(112.0, 34.0)
			_inventory_sort_option.add_item("获得时间")
			_inventory_sort_option.set_item_metadata(0, InventoryQuery.SORT_ACQUIRED_TIME)
			_inventory_sort_option.add_item("物品价值")
			_inventory_sort_option.set_item_metadata(1, InventoryQuery.SORT_ITEM_VALUE)
			_inventory_sort_option.add_item("耐久")
			_inventory_sort_option.set_item_metadata(2, InventoryQuery.SORT_DURABILITY)
			_inventory_sort_option.item_selected.connect(_on_inventory_sort_selected)
			query_bar.add_child(_inventory_sort_option)
			_inventory_stone_quality_option = OptionButton.new()
			_inventory_stone_quality_option.custom_minimum_size = Vector2(88.0, 34.0)
			_inventory_stone_quality_option.add_item("全部")
			_inventory_stone_quality_option.set_item_metadata(0, "")
			for quality_id in EnhancementRules.QUALITY_ORDER:
				# 品质短名；移除“强化石”后缀，使局内背包与锻造系统的列表文本保持一致。
				var quality_label: String = EnhancementRules.get_quality_display_name(quality_id).trim_suffix("强化石")
				_inventory_stone_quality_option.add_item(quality_label)
				_inventory_stone_quality_option.set_item_metadata(_inventory_stone_quality_option.item_count - 1, quality_id)
			_inventory_stone_quality_option.item_selected.connect(_on_inventory_stone_quality_selected)
			query_bar.add_child(_inventory_stone_quality_option)
			_inventory_stone_attribute_option = OptionButton.new()
			_inventory_stone_attribute_option.custom_minimum_size = Vector2(112.0, 34.0)
			_inventory_stone_attribute_option.add_item("强化筛选（0）")
			_inventory_stone_attribute_option.set_item_metadata(0, "")
			# 筛选方向顺序；先列出全部“+”词条，再列出全部“-”词条，保持与仓库筛选一致。
			for direction in InventoryQuery.STONE_FILTER_DIRECTIONS:
				_inventory_stone_attribute_option.add_separator(InventoryQuery.get_stone_attribute_direction_group_label(direction))
				# 可筛选属性；每个属性分别建立精确方向选项，例如“伤害+”和“伤害-”。
				for stat_name in EnhancementRules.STAT_KEYS:
					_inventory_stone_attribute_option.add_item(InventoryQuery.get_stone_attribute_filter_label(stat_name, (1 if EnhancementRules.is_direction_beneficial(stat_name, 1) == (direction > 0) else -1)))
					# 当前属性选项下标；用于绑定稳定筛选键并启用复选状态。
					var attribute_item_index: int = _inventory_stone_attribute_option.item_count - 1
					_inventory_stone_attribute_option.set_item_metadata(attribute_item_index, InventoryQuery.build_stone_attribute_filter_key(stat_name, (1 if EnhancementRules.is_direction_beneficial(stat_name, 1) == (direction > 0) else -1)))
					_inventory_stone_attribute_option.get_popup().set_item_as_checkable(attribute_item_index, true)
			_inventory_stone_attribute_option.get_popup().hide_on_checkable_item_selection = false
			_inventory_stone_attribute_option.item_selected.connect(_on_inventory_stone_attribute_selected)
			query_bar.add_child(_inventory_stone_attribute_option)
			_inventory_stone_attribute_clear_button = Button.new()
			_inventory_stone_attribute_clear_button.text = "清空筛选"
			_inventory_stone_attribute_clear_button.custom_minimum_size = Vector2(82.0, 34.0)
			_inventory_stone_attribute_clear_button.pressed.connect(_on_clear_inventory_stone_attribute_filter_pressed)
			query_bar.add_child(_inventory_stone_attribute_clear_button)

			# 一级分类栏；全部、武器和资源独立于原二级分类栏，形成清晰的多层结构。
			var primary_bar: HBoxContainer = HBoxContainer.new()
			primary_bar.add_theme_constant_override("separation", 6)
			backpack_content.add_child(primary_bar)
			backpack_content.move_child(primary_bar, filter_parent.get_index())
			_inventory_primary_all_button = Button.new()
			_inventory_primary_all_button.text = "全部"
			_inventory_primary_all_button.toggle_mode = true
			_inventory_primary_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_inventory_primary_all_button.pressed.connect(Callable(self, "_on_inventory_primary_category_pressed").bind(InventoryQuery.PRIMARY_ALL))
			primary_bar.add_child(_inventory_primary_all_button)
			_inventory_primary_weapons_button = Button.new()
			_inventory_primary_weapons_button.text = "武器"
			_inventory_primary_weapons_button.toggle_mode = true
			_inventory_primary_weapons_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_inventory_primary_weapons_button.pressed.connect(Callable(self, "_on_inventory_primary_category_pressed").bind(InventoryQuery.PRIMARY_WEAPONS))
			primary_bar.add_child(_inventory_primary_weapons_button)
			_inventory_primary_equipment_button = Button.new()
			_inventory_primary_equipment_button.text = "装备"
			_inventory_primary_equipment_button.toggle_mode = true
			_inventory_primary_equipment_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_inventory_primary_equipment_button.pressed.connect(Callable(self, "_on_inventory_primary_category_pressed").bind(InventoryQuery.PRIMARY_EQUIPMENT))
			primary_bar.add_child(_inventory_primary_equipment_button)
			_inventory_primary_resources_button = Button.new()
			_inventory_primary_resources_button.text = "资源"
			_inventory_primary_resources_button.toggle_mode = true
			_inventory_primary_resources_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_inventory_primary_resources_button.pressed.connect(Callable(self, "_on_inventory_primary_category_pressed").bind(InventoryQuery.PRIMARY_RESOURCES))
			primary_bar.add_child(_inventory_primary_resources_button)

			# 背包滚动区高度；给新增查询和两级分类预留空间，避免面板内容溢出。
			var inventory_scroll_control: Control = _inventory_drop_area as Control
			if inventory_scroll_control != null:
				inventory_scroll_control.custom_minimum_size = Vector2(0.0, 210.0)
	_refresh_inventory_filter_buttons()


func _create_inventory_subcategory_button(button_text: String, filter_name: String) -> Button:
	# 二级分类按钮；统一使用可扩展宽度和切换模式，具体筛选值通过绑定参数传递。
	var filter_button: Button = Button.new()
	filter_button.text = button_text
	filter_button.toggle_mode = true
	filter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_button.pressed.connect(Callable(self, "_set_inventory_filter").bind(filter_name))
	return filter_button


func _build_inventory_item_action_menu() -> void:
	_inventory_item_action_menu = ITEM_ACTION_POPUP_SCRIPT.new() as ItemActionPopup
	_inventory_item_action_menu.action_pressed.connect(_on_inventory_item_action_menu_id_pressed)
	_root_control.add_child(_inventory_item_action_menu)
	# 取消使用按钮；插入背包标题下方，仅强化目标选择期间占用布局高度。
	_inventory_cancel_stone_use_button = Button.new()
	_inventory_cancel_stone_use_button.text = "取消使用"
	_inventory_cancel_stone_use_button.visible = false
	_inventory_cancel_stone_use_button.custom_minimum_size = Vector2(0.0, 32.0)
	_inventory_cancel_stone_use_button.pressed.connect(_on_cancel_combat_stone_use_pressed)
	_apply_danger_button_style(_inventory_cancel_stone_use_button)
	# 背包标题容器；默认为 VBoxContainer，节点结构异常时按钮挂到背包面板作为兜底。
	var title_parent: Node = _inventory_title_label.get_parent()
	title_parent.add_child(_inventory_cancel_stone_use_button)
	title_parent.move_child(_inventory_cancel_stone_use_button, _inventory_title_label.get_index() + 1)
	_enhancement_result_dialog = ENHANCEMENT_RESULT_DIALOG_SCRIPT.new() as EnhancementResultDialog
	_root_control.add_child(_enhancement_result_dialog)
	_combat_quantity_dialog = SELL_QUANTITY_DIALOG_SCRIPT.new() as SellQuantityDialog
	_combat_quantity_dialog.connect("quantity_confirmed", Callable(self, "_on_combat_quantity_confirmed"))
	_root_control.add_child(_combat_quantity_dialog)


func _bind_inventory_drop_area() -> void:
	if _inventory_drop_area == null or not _inventory_drop_area.has_signal("drop_received"):
		return

	_inventory_drop_area.connect("drop_received", Callable(self, "_on_inventory_drop_area_drop_received"))


func _bind_pause_menu() -> void:
	_resume_button.pressed.connect(_on_resume_button_pressed)
	_pause_settings_button.pressed.connect(_on_pause_settings_button_pressed)
	_test_settings_button.pressed.connect(_on_test_settings_button_pressed)
	_unstuck_button.pressed.connect(_on_unstuck_button_pressed)
	_return_main_menu_button.pressed.connect(_on_return_main_menu_button_pressed)
	_death_return_main_menu_button.pressed.connect(_on_death_return_main_menu_button_pressed)
	_pause_settings_back_button.pressed.connect(_on_pause_settings_back_button_pressed)
	_clear_monsters_button.pressed.connect(_on_clear_monsters_button_pressed)
	_respawn_monsters_button.pressed.connect(_on_respawn_monsters_button_pressed)
	_switch_character_button.pressed.connect(_on_switch_character_button_pressed)
	_add_game_time_button.pressed.connect(_on_add_game_time_button_pressed)
	_unlock_map_vision_button.pressed.connect(_on_unlock_map_vision_button_pressed)
	_switch_character_stelle_button.pressed.connect(_on_switch_character_stelle_button_pressed)
	_switch_character_caelus_button.pressed.connect(_on_switch_character_caelus_button_pressed)
	_switch_character_silver_wolf_button.pressed.connect(_on_switch_character_silver_wolf_button_pressed)
	_setup_training_character_button_scroll()
	_build_dynamic_training_character_buttons()
	_character_switch_back_button.pressed.connect(_on_character_switch_back_button_pressed)
	_infinite_energy_check_button.toggled.connect(_on_infinite_energy_toggled)
	_infinite_health_check_button.toggled.connect(_on_infinite_health_toggled)
	_active_skill_no_cooldown_check_button.toggled.connect(_on_active_skill_no_cooldown_toggled)
	_test_settings_back_button.pressed.connect(_on_test_settings_back_button_pressed)
	_pause_master_volume_slider.value_changed.connect(_on_pause_master_volume_slider_value_changed)
	_build_pause_key_binding_navigation()
	_sync_pause_master_volume_slider()
	_sync_mode_controls()


func _build_risk_contract_view() -> void:
	## 构建暂停界面左栏的风险合约入口与只读面板；不修改场景文件中的中央菜单和右侧地图职责。
	if _risk_contract_view_button != null or _risk_contract_view_panel != null:
		return
	# 左栏查看按钮；未展开合约面板时显示，固定与右侧地图同宽并垂直居中。
	var view_button: Button = Button.new()
	view_button.name = "RiskContractViewButton"
	view_button.text = "查看风险合约"
	view_button.set_anchors_preset(Control.PRESET_CENTER)
	view_button.offset_left = RISK_CONTRACT_VIEW_BUTTON_TOP_LEFT.x
	view_button.offset_top = RISK_CONTRACT_VIEW_BUTTON_TOP_LEFT.y
	view_button.offset_right = RISK_CONTRACT_VIEW_BUTTON_BOTTOM_RIGHT.x
	view_button.offset_bottom = RISK_CONTRACT_VIEW_BUTTON_BOTTOM_RIGHT.y
	view_button.pressed.connect(_on_risk_contract_view_button_pressed)
	_pause_overlay.add_child(view_button)
	_risk_contract_view_button = view_button
	# 左栏只读面板；与右侧地图同为 420×420，关闭后恢复入口按钮。
	var view_panel: Control = RISK_CONTRACT_VIEW_PANEL_SCRIPT.new() as Control
	if view_panel == null:
		view_button.visible = false
		return
	view_panel.name = "RiskContractViewPanel"
	view_panel.set_anchors_preset(Control.PRESET_CENTER)
	view_panel.offset_left = RISK_CONTRACT_VIEW_PANEL_TOP_LEFT.x
	view_panel.offset_top = RISK_CONTRACT_VIEW_PANEL_TOP_LEFT.y
	view_panel.offset_right = RISK_CONTRACT_VIEW_PANEL_BOTTOM_RIGHT.x
	view_panel.offset_bottom = RISK_CONTRACT_VIEW_PANEL_BOTTOM_RIGHT.y
	view_panel.connect("closed", Callable(self, "_on_risk_contract_view_closed"))
	_pause_overlay.add_child(view_panel)
	_risk_contract_view_panel = view_panel
	view_panel.visible = false
	_sync_risk_contract_view_visibility()


func _build_hack_protocol_view() -> void:
	## 构建暂停界面左栏的骇入协议入口与只读面板；与风险合约入口上下排列并共享同一查看区域。
	if _hack_protocol_view_button != null or _hack_protocol_view_panel != null:
		return
	# 左栏查看按钮；只在本局启用骇入协议时可见，与其他已启用扩展共享入口布局。
	var view_button: Button = Button.new()
	view_button.name = "HackProtocolViewButton"
	view_button.text = "查看骇入协议"
	view_button.set_anchors_preset(Control.PRESET_CENTER)
	view_button.offset_left = HACK_PROTOCOL_VIEW_BUTTON_TOP_LEFT.x
	view_button.offset_top = HACK_PROTOCOL_VIEW_BUTTON_TOP_LEFT.y
	view_button.offset_right = HACK_PROTOCOL_VIEW_BUTTON_BOTTOM_RIGHT.x
	view_button.offset_bottom = HACK_PROTOCOL_VIEW_BUTTON_BOTTOM_RIGHT.y
	view_button.pressed.connect(_on_hack_protocol_view_button_pressed)
	_pause_overlay.add_child(view_button)
	_hack_protocol_view_button = view_button
	# 左栏只读面板；复用风险合约 420×420 查看区域，两者永不同时展开。
	var view_panel: Control = HACK_PROTOCOL_VIEW_PANEL_SCRIPT.new() as Control
	if view_panel == null:
		view_button.visible = false
		return
	view_panel.name = "HackProtocolViewPanel"
	view_panel.set_anchors_preset(Control.PRESET_CENTER)
	view_panel.offset_left = RISK_CONTRACT_VIEW_PANEL_TOP_LEFT.x
	view_panel.offset_top = RISK_CONTRACT_VIEW_PANEL_TOP_LEFT.y
	view_panel.offset_right = RISK_CONTRACT_VIEW_PANEL_BOTTOM_RIGHT.x
	view_panel.offset_bottom = RISK_CONTRACT_VIEW_PANEL_BOTTOM_RIGHT.y
	view_panel.connect("closed", Callable(self, "_on_hack_protocol_view_closed"))
	_pause_overlay.add_child(view_panel)
	_hack_protocol_view_panel = view_panel
	view_panel.visible = false
	_sync_risk_contract_view_visibility()


func _get_current_risk_contract_modifier_ids() -> Array[String]:
	## 从运行期会话读取本局风险词条；训练场、未启用合约或服务缺失时返回空数组。
	# 会话状态服务；只读取本局稳定 ID，不让查看面板依赖 GameWorld 内部倍率缓存。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null or not session_state.has_method("get_mode_extension_ids") or not session_state.has_method("get_risk_contract_modifier_ids"):
		return []
	# 本局模式扩展 ID；只有显式包含 risk_contract 时才允许展示风险词条。
	var extension_ids: Array = session_state.call("get_mode_extension_ids")
	if not extension_ids.has(ModeExtensionRules.EXTENSION_RISK_CONTRACT):
		return []
	# 本局风险词条 ID；再次规范化可防止异常运行期数据进入只读界面。
	var modifier_ids: Array = session_state.call("get_risk_contract_modifier_ids")
	return ModeExtensionRules.normalize_risk_modifier_ids(modifier_ids)


func _get_current_hack_protocol_ids() -> Array[String]:
	## 返回本机本局协议快照；组件缺失或扩展未启用时返回空数组。
	if _hack_protocol_component == null or not _hack_protocol_component.has_method("get_acquired_protocol_ids"):
		return []
	return HackProtocolRules.normalize_protocol_ids(_hack_protocol_component.call("get_acquired_protocol_ids") as Array)


func _is_risk_contract_extension_enabled() -> bool:
	## 返回本局风险合约扩展开关；入口显隐只读取稳定扩展 ID，不以词条数组是否为空替代启用状态。
	# 会话状态服务；模式扩展由其保存为本局运行期配置，缺失时按未启用处理。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null or not session_state.has_method("get_mode_extension_ids"):
		return false
	# 本局模式扩展 ID；只有显式包含风险合约时才允许暂停左栏显示对应入口。
	var extension_ids: Array = session_state.call("get_mode_extension_ids")
	return extension_ids.has(ModeExtensionRules.EXTENSION_RISK_CONTRACT)


func _is_hack_protocol_extension_enabled() -> bool:
	## 返回本局骇入协议扩展开关；优先读取 GameWorld 已缓存状态，独立 UI 场景回退组件是否存在。
	if _game_world != null and _game_world.has_method("is_hack_protocol_enabled"):
		return bool(_game_world.call("is_hack_protocol_enabled"))
	return _hack_protocol_component != null


func _show_risk_contract_view(visible: bool) -> void:
	## 打开或关闭左栏只读面板；中央暂停菜单与右侧地图保持可见，战斗继续处于暂停状态。
	if _risk_contract_view_panel == null:
		return
	if visible and not _is_risk_contract_extension_enabled():
		return
	if visible and _risk_contract_view_panel.has_method("present"):
		if _hack_protocol_view_panel != null:
			_hack_protocol_view_panel.visible = false
		_risk_contract_view_panel.call("present", _get_current_risk_contract_modifier_ids())
	else:
		_risk_contract_view_panel.visible = false
	_sync_risk_contract_view_visibility()


func _show_hack_protocol_view(visible: bool) -> void:
	## 打开或关闭本机协议只读面板；多人不会展示其他成员的协议、碎片或候选。
	if _hack_protocol_view_panel == null:
		return
	if visible and not _is_hack_protocol_extension_enabled():
		return
	if visible and _hack_protocol_view_panel.has_method("present"):
		if _risk_contract_view_panel != null:
			_risk_contract_view_panel.visible = false
		_hack_protocol_view_panel.call("present", _get_current_hack_protocol_ids(), _is_hack_protocol_extension_enabled())
	else:
		_hack_protocol_view_panel.visible = false
	_sync_risk_contract_view_visibility()


func _hide_mode_extension_views() -> void:
	## 同时关闭暂停左栏的两种模式扩展查看面板；进入宽版子页前统一调用。
	if _risk_contract_view_panel != null:
		_risk_contract_view_panel.visible = false
	if _hack_protocol_view_panel != null:
		_hack_protocol_view_panel.visible = false
	_sync_risk_contract_view_visibility()


func _sync_risk_contract_view_visibility() -> void:
	## 根据暂停页层级和本局扩展开关切换左栏入口；未启用的扩展永远不显示，唯一入口自动居中。
	if _risk_contract_view_button == null and _hack_protocol_view_button == null:
		return
	# 查看面板是否展开；风险合约与骇入协议共享左栏区域，任一展开时两个入口都隐藏。
	var view_panel_visible: bool = (_risk_contract_view_panel != null and _risk_contract_view_panel.visible) or (_hack_protocol_view_panel != null and _hack_protocol_view_panel.visible)
	# 入口基础可见条件；只在暂停主页且开发者菜单关闭时成立。
	var entry_visible: bool = _pause_overlay.visible and _pause_menu_panel.visible and not view_panel_visible and not _is_combat_developer_menu_visible()
	# 风险合约入口最终可见性；必须同时满足暂停主页条件与本局扩展已启用。
	var risk_entry_visible: bool = entry_visible and _is_risk_contract_extension_enabled()
	# 骇入协议入口最终可见性；必须同时满足暂停主页条件与本局扩展已启用。
	var hack_entry_visible: bool = entry_visible and _is_hack_protocol_extension_enabled()
	if _risk_contract_view_button != null:
		_risk_contract_view_button.visible = risk_entry_visible
		_risk_contract_view_button.offset_top = SINGLE_MODE_EXTENSION_VIEW_BUTTON_TOP if risk_entry_visible and not hack_entry_visible else RISK_CONTRACT_VIEW_BUTTON_TOP_LEFT.y
		_risk_contract_view_button.offset_bottom = SINGLE_MODE_EXTENSION_VIEW_BUTTON_BOTTOM if risk_entry_visible and not hack_entry_visible else RISK_CONTRACT_VIEW_BUTTON_BOTTOM_RIGHT.y
	if _hack_protocol_view_button != null:
		_hack_protocol_view_button.visible = hack_entry_visible
		_hack_protocol_view_button.offset_top = SINGLE_MODE_EXTENSION_VIEW_BUTTON_TOP if hack_entry_visible and not risk_entry_visible else HACK_PROTOCOL_VIEW_BUTTON_TOP_LEFT.y
		_hack_protocol_view_button.offset_bottom = SINGLE_MODE_EXTENSION_VIEW_BUTTON_BOTTOM if hack_entry_visible and not risk_entry_visible else HACK_PROTOCOL_VIEW_BUTTON_BOTTOM_RIGHT.y


func _build_escape_confirmation_dialog() -> void:
	if _escape_confirmation_dialog != null:
		return
	_escape_confirmation_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_escape_confirmation_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_escape_confirmation_dialog.confirmed.connect(_on_escape_confirmed)
	_root_control.add_child(_escape_confirmation_dialog)


func _build_newcomer_protection_ended_dialog() -> void:
	## 创建首次成功撤离后的单按钮信息弹窗；与逃跑确认分离实例，避免两个结算流程复用时状态串扰。
	if _newcomer_protection_ended_dialog != null:
		return
	_newcomer_protection_ended_dialog = COMMON_CONFIRMATION_DIALOG_SCRIPT.new() as CommonConfirmationDialog
	_newcomer_protection_ended_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_root_control.add_child(_newcomer_protection_ended_dialog)


func _build_pause_key_binding_navigation() -> void:
	if _pause_settings_content == null:
		return

	if _pause_key_binding_page != null:
		return

	# 暂停设置 UI 风格选择组件；放在主音量行之后，切换结果立即作用于战斗内全部 UI。
	var ui_style_selector: Control = UI_STYLE_SELECTOR_SCRIPT.new() as Control
	if ui_style_selector != null:
		ui_style_selector.name = "PauseUiStyleSelector"
		_pause_settings_content.add_child(ui_style_selector)
		# 主音量行；作为固定插入锚点，避免后续存档与按键入口顺序变化影响 UI 风格位置。
		var pause_master_volume_row: Control = get_node("Root/PauseOverlay/PauseSettingsPanel/PauseSettingsMargin/PauseSettingsContent/PauseMasterVolumeRow") as Control
		_pause_settings_content.move_child(ui_style_selector, pause_master_volume_row.get_index() + 1)
		_pause_ui_style_selector = ui_style_selector

	# 暂停设置横幅通知开关组件；放在 UI 风格行之后，与主菜单设置共享同一横幅通知服务状态。
	var banner_notification_toggle: Control = BANNER_NOTIFICATION_TOGGLE_SCRIPT.new() as Control
	if banner_notification_toggle != null:
		banner_notification_toggle.name = "PauseBannerNotificationToggle"
		_pause_settings_content.add_child(banner_notification_toggle)
		if _pause_ui_style_selector != null:
			_pause_settings_content.move_child(banner_notification_toggle, _pause_ui_style_selector.get_index() + 1)
		_pause_banner_notification_toggle = banner_notification_toggle

	# 按键绑定入口按钮；取值为 Button，默认放在暂停设置首页用于进入独立按键绑定页。
	var key_binding_button: Button = Button.new()
	key_binding_button.name = "PauseKeyBindingPageButton"
	key_binding_button.custom_minimum_size = Vector2(0.0, 42.0)
	key_binding_button.text = "按键绑定"
	key_binding_button.pressed.connect(_on_pause_key_binding_button_pressed)
	_pause_settings_content.add_child(key_binding_button)
	_pause_settings_content.move_child(key_binding_button, maxi(_pause_settings_content.get_child_count() - 3, 0))
	_pause_key_binding_button = key_binding_button
	# 存档传输控件；战斗中不强制保存本局临时所有权，继续遵守结算后统一落盘的框架规则。
	# 删除功能补充；玩家确认删除时不执行战斗结算，复用控件会直接清理活动存档并重启。
	var save_transfer_control: Control = SAVE_TRANSFER_CONTROL_SCRIPT.new() as Control
	if save_transfer_control != null:
		save_transfer_control.name = "PauseSaveTransferControl"
		_pause_settings_content.add_child(save_transfer_control)
		_pause_settings_content.move_child(save_transfer_control, maxi(_pause_settings_content.get_child_count() - 3, 0))
		_pause_save_transfer_control = save_transfer_control
	_pause_settings_home_controls = [
		get_node("Root/PauseOverlay/PauseSettingsPanel/PauseSettingsMargin/PauseSettingsContent/PauseSettingsTitle") as Control,
		get_node("Root/PauseOverlay/PauseSettingsPanel/PauseSettingsMargin/PauseSettingsContent/PauseMasterVolumeRow") as Control,
		_pause_ui_style_selector,
		_pause_banner_notification_toggle,
		_pause_key_binding_button,
		_pause_save_transfer_control,
		get_node("Root/PauseOverlay/PauseSettingsPanel/PauseSettingsMargin/PauseSettingsContent/PauseSettingsSpacer") as Control,
		_pause_settings_back_button,
	]

	# 按键绑定页面；取值为 VBoxContainer，默认隐藏并在点击入口后显示。
	var key_binding_page: VBoxContainer = VBoxContainer.new()
	key_binding_page.name = "PauseKeyBindingPage"
	key_binding_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	key_binding_page.add_theme_constant_override("separation", 10)
	_pause_settings_content.add_child(key_binding_page)
	_pause_key_binding_page = key_binding_page

	# 按键绑定面板；取值为 KeyBindingPanel 实例，默认只在按键绑定页面内显示。
	var key_binding_panel: Control = KEY_BINDING_PANEL_SCRIPT.new() as Control
	if key_binding_panel == null:
		return

	key_binding_panel.name = "PauseKeyBindingPanel"
	key_binding_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pause_key_binding_page.add_child(key_binding_panel)
	_pause_key_binding_panel = key_binding_panel

	# 按键绑定返回按钮；取值为 Button，默认回到暂停设置首页。
	var key_binding_back_button: Button = Button.new()
	key_binding_back_button.name = "PauseKeyBindingBackButton"
	key_binding_back_button.custom_minimum_size = Vector2(0.0, 42.0)
	key_binding_back_button.text = "返回"
	key_binding_back_button.pressed.connect(_on_pause_key_binding_back_button_pressed)
	_pause_key_binding_page.add_child(key_binding_back_button)
	_pause_key_binding_back_button = key_binding_back_button
	_show_pause_key_binding_page(false)


func _is_key_binding_capture_active() -> bool:
	if _pause_key_binding_panel == null or not _pause_key_binding_panel.has_method("is_waiting_for_binding"):
		return false

	return bool(_pause_key_binding_panel.call("is_waiting_for_binding"))


func _resolve_training_mode() -> bool:
	if _game_world == null or not _game_world.has_method("is_training_mode"):
		return false

	return bool(_game_world.call("is_training_mode"))


func _resolve_casual_mode() -> bool:
	## 解析本局是否为无结算娱乐模式；训练场与超频骇入都返回 true，世界节点缺失时回退训练场判定。
	if _game_world != null and _game_world.has_method("is_settlement_disabled_mode"):
		return bool(_game_world.call("is_settlement_disabled_mode"))
	return _resolve_training_mode()


func _sync_mode_controls() -> void:
	_test_settings_button.visible = _is_training_mode
	# 返回主菜单按钮文本；训练场与超频骇入没有物品损失结算，因此使用“离开”并直接返回主菜单。
	_return_main_menu_button.text = "离开" if _is_casual_mode else "逃跑"
	if not _can_use_training_tools():
		_test_settings_panel.visible = false
		_character_switch_panel.visible = false


func _can_use_training_tools() -> bool:
	return _is_training_mode or _developer_training_access_unlocked


func _can_pending_combat_repair_target(weapon_resource: Resource) -> bool:
	if _pending_combat_stone_resource == null or str(_pending_combat_stone_resource.get("item_kind")) != "repair_kit" or weapon_resource == null:
		return false
	# 合法修复目标；武器与四部位装备都必须提供耐久字段。
	var item_kind: String = str(weapon_resource.get("item_kind"))
	if str(weapon_resource.get("weapon_type")) not in ["ranged", "melee", "hybrid"] and item_kind != "equipment":
		return false
	# 当前耐久；只有存在耐久缺口的武器才应被绿色高亮为修复包目标。
	var current_durability: float = maxf(float(weapon_resource.get("current_durability")), 0.0)
	# 最大耐久；至少为 1，避免旧资源数据异常导致比较无效。
	var maximum_durability: float = float(weapon_resource.call("get_maximum_durability")) if weapon_resource.has_method("get_maximum_durability") else maxf(float(weapon_resource.get("max_durability")), 1.0)
	return current_durability < maximum_durability and not is_equal_approx(current_durability, maximum_durability)


func _set_inventory_filter(new_filter: String) -> void:
	if _inventory_filter == new_filter:
		_refresh_inventory_filter_buttons()
		return

	_inventory_filter = new_filter
	_refresh_inventory_filter_buttons()
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _refresh_inventory_filter_buttons() -> void:
	if _inventory_primary_all_button != null:
		_inventory_primary_all_button.set_pressed_no_signal(_inventory_primary_category == InventoryQuery.PRIMARY_ALL)
	if _inventory_primary_weapons_button != null:
		_inventory_primary_weapons_button.set_pressed_no_signal(_inventory_primary_category == InventoryQuery.PRIMARY_WEAPONS)
	if _inventory_primary_equipment_button != null:
		_inventory_primary_equipment_button.set_pressed_no_signal(_inventory_primary_category == InventoryQuery.PRIMARY_EQUIPMENT)
	if _inventory_primary_resources_button != null:
		_inventory_primary_resources_button.set_pressed_no_signal(_inventory_primary_category == InventoryQuery.PRIMARY_RESOURCES)
	_inventory_filter_all_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_ALL)
	_inventory_filter_melee_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_MELEE)
	_inventory_filter_ranged_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_RANGED)
	if _inventory_filter_stones_button != null:
		_inventory_filter_stones_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_STONES)
	if _inventory_filter_items_button != null:
		_inventory_filter_items_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_ITEMS)
	if _inventory_filter_equipment_head_button != null:
		_inventory_filter_equipment_head_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_EQUIPMENT_HEAD)
	if _inventory_filter_equipment_body_button != null:
		_inventory_filter_equipment_body_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_EQUIPMENT_BODY)
	if _inventory_filter_equipment_legs_button != null:
		_inventory_filter_equipment_legs_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_EQUIPMENT_LEGS)
	if _inventory_filter_equipment_feet_button != null:
		_inventory_filter_equipment_feet_button.set_pressed_no_signal(_inventory_filter == INVENTORY_FILTER_EQUIPMENT_FEET)
	# 二级分类可见性；全部主分类只保留聚合“全部”，武器和资源分别显示各自专属入口。
	var weapon_category_visible: bool = _inventory_primary_category == InventoryQuery.PRIMARY_WEAPONS
	# 装备分类可见状态；仅装备页展示头部、躯干、腿部和脚部入口。
	var equipment_category_visible: bool = _inventory_primary_category == InventoryQuery.PRIMARY_EQUIPMENT
	# 资源分类可见状态；仅资源页展示强化石、道具和属性筛选，聚合页不会误套用资源条件。
	var resource_category_visible: bool = _inventory_primary_category == InventoryQuery.PRIMARY_RESOURCES
	_inventory_filter_melee_button.visible = weapon_category_visible
	_inventory_filter_ranged_button.visible = weapon_category_visible
	if _inventory_filter_stones_button != null:
		_inventory_filter_stones_button.visible = resource_category_visible
	if _inventory_filter_items_button != null:
		_inventory_filter_items_button.visible = resource_category_visible
	if _inventory_filter_equipment_head_button != null:
		_inventory_filter_equipment_head_button.visible = equipment_category_visible
	if _inventory_filter_equipment_body_button != null:
		_inventory_filter_equipment_body_button.visible = equipment_category_visible
	if _inventory_filter_equipment_legs_button != null:
		_inventory_filter_equipment_legs_button.visible = equipment_category_visible
	if _inventory_filter_equipment_feet_button != null:
		_inventory_filter_equipment_feet_button.visible = equipment_category_visible
	if _inventory_stone_attribute_option != null:
		_inventory_stone_attribute_option.visible = resource_category_visible
	if _inventory_stone_quality_option != null:
		_inventory_stone_quality_option.visible = resource_category_visible
	if _inventory_stone_attribute_clear_button != null:
		_inventory_stone_attribute_clear_button.visible = resource_category_visible
		_inventory_stone_attribute_clear_button.disabled = _inventory_stone_attribute_filter.is_empty()


func _get_inventory_filter_label() -> String:
	if _inventory_filter == INVENTORY_FILTER_MELEE:
		return "近战"
	if _inventory_filter == INVENTORY_FILTER_RANGED:
		return "远程"
	if _inventory_filter == INVENTORY_FILTER_STONES:
		return "资源 · 强化石"
	if _inventory_filter == INVENTORY_FILTER_ITEMS:
		return "资源 · 道具"
	if _inventory_filter == INVENTORY_FILTER_EQUIPMENT_HEAD:
		return "装备 · 头部"
	if _inventory_filter == INVENTORY_FILTER_EQUIPMENT_BODY:
		return "装备 · 躯干"
	if _inventory_filter == INVENTORY_FILTER_EQUIPMENT_LEGS:
		return "装备 · 腿部"
	if _inventory_filter == INVENTORY_FILTER_EQUIPMENT_FEET:
		return "装备 · 脚部"
	if _inventory_primary_category == InventoryQuery.PRIMARY_RESOURCES:
		return "资源 · 全部"
	if _inventory_primary_category == InventoryQuery.PRIMARY_EQUIPMENT:
		return "装备 · 全部"
	if _inventory_primary_category == InventoryQuery.PRIMARY_ALL:
		return "全部物品"

	return "武器 · 全部"


func _is_toggle_inventory_event(key_event: InputEventKey) -> bool:
	if _should_use_physical_fallback(toggle_inventory_action) and key_event.physical_keycode == KEY_E:
		return true

	return InputMap.has_action(toggle_inventory_action) and Input.is_action_just_pressed(toggle_inventory_action)


func _is_pause_event(key_event: InputEventKey) -> bool:
	if _should_use_physical_fallback(pause_action) and key_event.physical_keycode == KEY_ESCAPE:
		return true

	return InputMap.has_action(pause_action) and Input.is_action_just_pressed(pause_action)


func _is_toggle_large_map_event(key_event: InputEventKey) -> bool:
	if _should_use_physical_fallback(toggle_large_map_action) and key_event.physical_keycode == KEY_M:
		return true

	return InputMap.has_action(toggle_large_map_action) and Input.is_action_just_pressed(toggle_large_map_action)


func _is_toggle_character_showcase_event(key_event: InputEventKey) -> bool:
	if _should_use_physical_fallback(toggle_character_showcase_action) and key_event.physical_keycode == KEY_O:
		return true

	return InputMap.has_action(toggle_character_showcase_action) and Input.is_action_just_pressed(toggle_character_showcase_action)


func _is_toggle_drop_list_event(key_event: InputEventKey) -> bool:
	if _should_use_physical_fallback(toggle_drop_list_action) and key_event.physical_keycode == KEY_G:
		return true

	return InputMap.has_action(toggle_drop_list_action) and Input.is_action_just_pressed(toggle_drop_list_action)


func _is_pickup_event(key_event: InputEventKey) -> bool:
	if _should_use_physical_fallback(pickup_action) and key_event.physical_keycode == KEY_F:
		return true

	return InputMap.has_action(pickup_action) and Input.is_action_just_pressed(pickup_action)


func _should_use_physical_fallback(action_name: StringName) -> bool:
	# 兜底判定缓存键；动作名转字符串，同一动作在绑定未变更期间直接复用上次判定，避免每帧 action_get_events 分配数组。
	var fallback_cache_key: String = String(action_name)
	if _physical_fallback_cache.has(fallback_cache_key):
		return bool(_physical_fallback_cache[fallback_cache_key])
	# 本次兜底判定结果；沿用原有三段规则，动作缺失兜底、已有事件不兜底、空事件按显式解绑状态决定。
	var fallback_result: bool = true
	if InputMap.has_action(action_name):
		if not InputMap.action_get_events(action_name).is_empty():
			fallback_result = false
		else:
			fallback_result = not _is_action_explicitly_unbound(action_name)
	_physical_fallback_cache[fallback_cache_key] = fallback_result
	return fallback_result


func _on_input_bindings_changed() -> void:
	## 绑定变更回调；清空物理键兜底判定缓存，下一次输入判定按最新 InputMap 事件与显式解绑状态重算。
	_physical_fallback_cache.clear()
	_refresh_hack_protocol_progress()


func _is_action_explicitly_unbound(action_name: StringName) -> bool:
	# 输入绑定单例；取值为 AutoLoad InputBindings，默认用于区分玩家主动未绑定和 InputMap 配置缺失。
	var input_bindings: Node = get_tree().root.get_node_or_null("InputBindings")
	if input_bindings == null or not input_bindings.has_method("is_action_explicitly_unbound"):
		return false

	return bool(input_bindings.call("is_action_explicitly_unbound", action_name))


func _try_unlock_combat_developer_menu(key_event: InputEventKey) -> bool:
	if key_event.unicode <= 0:
		return false
	# 当前输入字符；统一转为大写，使大小写状态不会影响 LISBAM 解锁序列。
	var input_character: String = String.chr(key_event.unicode).to_upper()
	# 当前期望字符；由匹配下标读取，输入错误时仅在当前字符为 L 时立即开始下一轮。
	var expected_character: String = DEVELOPER_UNLOCK_SEQUENCE.substr(_developer_sequence_index, 1)
	if input_character == expected_character:
		_developer_sequence_index += 1
	else:
		_developer_sequence_index = 1 if input_character == DEVELOPER_UNLOCK_SEQUENCE.substr(0, 1) else 0
	if _developer_sequence_index < DEVELOPER_UNLOCK_SEQUENCE.length():
		return false
	_developer_sequence_index = 0
	_developer_training_access_unlocked = true
	_open_combat_developer_menu()
	return true


func _is_combat_developer_menu_visible() -> bool:
	return _combat_developer_overlay != null and _combat_developer_overlay.visible


func _open_combat_developer_menu() -> void:
	if _combat_developer_overlay == null or _combat_developer_menu == null:
		return
	_hide_mode_extension_views()
	_pause_menu_panel.visible = false
	_pause_settings_panel.visible = false
	_test_settings_panel.visible = false
	_character_switch_panel.visible = false
	_combat_developer_menu.call("sync_combat_states", _is_infinite_health_enabled(), _is_infinite_energy_enabled(), _is_weapon_durability_consumption_disabled_by_debug())
	_combat_developer_overlay.visible = true
	_sync_risk_contract_view_visibility()
	_refresh_combat_input_state()


func _is_infinite_health_enabled() -> bool:
	return _stats_component != null and bool(_stats_component.get("infinite_health"))


func _is_infinite_energy_enabled() -> bool:
	return _stats_component != null and bool(_stats_component.get("infinite_energy"))


func _is_weapon_durability_consumption_disabled_by_debug() -> bool:
	return _player != null and _player.has_method("is_weapon_durability_consumption_disabled_by_debug") and bool(_player.call("is_weapon_durability_consumption_disabled_by_debug"))


func _close_top_interactive_panel() -> bool:
	if _hack_protocol_select_overlay != null and _hack_protocol_select_overlay.visible:
		_close_hack_protocol_select()
		return true
	if _supply_extraction_overlay != null and _supply_extraction_overlay.visible:
		_close_supply_extraction_panel()
		return true
	if _is_combat_developer_menu_visible():
		_on_combat_developer_menu_closed()
		return true
	if _is_character_showcase_visible():
		_set_character_showcase_visible(false)
		return true
	if (_risk_contract_view_panel != null and _risk_contract_view_panel.visible) or (_hack_protocol_view_panel != null and _hack_protocol_view_panel.visible):
		_hide_mode_extension_views()
		return true

	if _inventory_panel.visible:
		_set_inventory_visible(false)
		return true

	if _large_map_overlay.visible:
		_set_large_map_visible(false)
		return true

	return false


func _open_supply_extraction_panel() -> void:
	if _supply_extraction_overlay == null or _supply_extraction_panel == null:
		return
	if _is_character_showcase_visible():
		_set_character_showcase_visible(false)
	_set_inventory_visible(false)
	_set_large_map_visible(false)
	_supply_extraction_overlay.visible = true
	_supply_extraction_panel.call("present")
	_set_battle_tree_paused(true)
	_refresh_combat_input_state()


func _close_supply_extraction_panel() -> void:
	if _supply_extraction_overlay == null:
		return
	_supply_extraction_overlay.visible = false
	if _supply_extraction_panel != null and _supply_extraction_panel.has_method("dismiss"):
		_supply_extraction_panel.call("dismiss")
	get_tree().paused = false
	_refresh_combat_input_state()


func _toggle_drop_list_enabled() -> void:
	_drop_list_enabled = not _drop_list_enabled
	_nearby_drop_refresh_remaining = 0.0
	_refresh_nearby_drop_panel()
	_refresh_combat_input_state()


func _pickup_nearest_drop() -> void:
	if not _can_pickup_nearby_drops():
		return

	# 附近掉落物列表；元素为按距离排序的 WeaponDrop，默认第一个就是最近目标。
	var nearby_drops: Array[Node2D] = _get_nearby_weapon_drops()
	if nearby_drops.is_empty():
		return

	_pickup_drop(nearby_drops[0])


func _pickup_drop(drop_node: Node) -> void:
	if drop_node == null or not is_instance_valid(drop_node) or _inventory_component == null:
		return

	if not (drop_node is Node2D):
		return

	# 掉落物节点；取值为 Node2D，默认用于最后一次拾取距离校验。
	var drop_node_2d: Node2D = drop_node as Node2D
	if not _is_drop_in_pickup_range(drop_node_2d):
		return

	# 娱乐模式拾取；训练场与超频骇入只消费地面对象，不写入背包、仓库或存档。
	if _is_casual_mode and drop_node.has_method("consume_for_training") and bool(drop_node.call("consume_for_training")):
		_refresh_nearby_drop_panel()
		return
	if drop_node.has_method("pickup_to_inventory") and bool(drop_node.call("pickup_to_inventory", _inventory_component)):
		_refresh_nearby_drop_panel()
		if _inventory_panel.visible:
			_rebuild_inventory_slots()
	elif drop_node.has_method("show_pickup_status"):
		drop_node.call("show_pickup_status", "背包已满！")


func _drop_weapon_to_world(drop_data: Dictionary) -> void:
	if _game_world == null or not _game_world.has_method("spawn_weapon_drop_near_player"):
		return

	# 拖拽来源上下文；取值为 inventory 或 equipment，默认用于决定从背包移除还是从装备槽卸下。
	var source_context: String = str(drop_data.get("source_context", ""))
	# 被丢弃武器资源；取值为 Resource 或 null，默认来自拖拽数据，修改会影响世界掉落物内容。
	var dragged_weapon: Resource = drop_data.get("weapon_data", null) as Resource
	if dragged_weapon == null:
		return

	if source_context == "inventory":
		_drop_inventory_source_weapon_to_world(drop_data, dragged_weapon)
	elif source_context == "equipment":
		_drop_equipment_source_weapon_to_world(drop_data, dragged_weapon)


func _drop_inventory_source_weapon_to_world(drop_data: Dictionary, dragged_weapon: Resource) -> void:
	if _inventory_component == null:
		return

	# 背包来源索引；取值为有效背包下标或 -1，默认用于生成失败时回滚到原位置。
	var source_index: int = int(drop_data.get("slot_index", -1))
	if not _remove_item_from_inventory(dragged_weapon):
		return

	if not _spawn_dragged_weapon_or_restore_to_inventory(dragged_weapon, source_index):
		return

	if _shared_backpack_panel != null:
		_shared_backpack_panel.refresh()
	_refresh_nearby_drop_panel()


func _drop_equipment_source_weapon_to_world(drop_data: Dictionary, dragged_weapon: Resource) -> void:
	if _equipment_component == null:
		return

	# 装备来源槽类型；取值为 ranged 或 melee，默认用于生成失败时把武器放回原装备槽。
	var source_kind: String = str(drop_data.get("slot_kind", ""))
	# 装备来源槽索引；取值为远程槽有效下标或 -1，默认用于远程武器回滚到原槽。
	var source_index: int = int(drop_data.get("slot_index", -1))
	# 来源远程槽是否当前选中；取值为 true/false，默认用于生成失败后恢复当前武器选择。
	var source_was_current_ranged: bool = _is_current_ranged_source(source_kind, source_index)
	if not _unequip_from_drop_source(drop_data):
		return

	if not _spawn_dragged_weapon_or_restore_to_equipment(dragged_weapon, source_kind, source_index, source_was_current_ranged):
		return

	_refresh_equipment()
	if _shared_backpack_panel != null:
		_shared_backpack_panel.refresh()
	_refresh_nearby_drop_panel()


func _spawn_dragged_weapon_or_restore_to_inventory(dragged_weapon: Resource, source_index: int) -> bool:
	# 是否成功生成世界掉落物；取值为 true/false，默认失败时把武器放回背包。
	var drop_spawned: bool = bool(_game_world.call("spawn_weapon_drop_near_player", dragged_weapon))
	if drop_spawned:
		_discard_detached_inventory_record(dragged_weapon)
		return true

	_add_item_to_inventory(dragged_weapon, source_index)
	return false


func _spawn_dragged_weapon_or_restore_to_equipment(dragged_weapon: Resource, source_kind: String, source_index: int, source_was_current_ranged: bool) -> bool:
	# 是否成功生成世界掉落物；取值为 true/false，默认失败时把武器放回原装备槽。
	var drop_spawned: bool = bool(_game_world.call("spawn_weapon_drop_near_player", dragged_weapon))
	if drop_spawned:
		_discard_detached_inventory_record(dragged_weapon)
		return true

	_equip_weapon_to_target(source_kind, source_index, dragged_weapon)
	if source_was_current_ranged and _equipment_component.has_method("equip_ranged_slot"):
		_equipment_component.call("equip_ranged_slot", source_index)
	return false


func _discard_detached_inventory_record(item_data: Resource) -> void:
	if _inventory_component != null and _inventory_component.has_method("discard_detached_item"):
		_inventory_component.call("discard_detached_item", item_data)


func _toggle_pause_menu() -> void:
	if _is_player_dead:
		return
	if _is_combat_developer_menu_visible():
		_on_combat_developer_menu_closed()
		return

	if (_risk_contract_view_panel != null and _risk_contract_view_panel.visible) or (_hack_protocol_view_panel != null and _hack_protocol_view_panel.visible):
		_hide_mode_extension_views()
		return

	if _pause_overlay.visible and _pause_settings_panel.visible and _is_pause_key_binding_page_visible():
		_show_pause_key_binding_page(false)
		return

	if _pause_overlay.visible and _pause_settings_panel.visible:
		_show_pause_settings(false)
		return

	if _pause_overlay.visible and _character_switch_panel.visible:
		_show_character_switch(false)
		return

	if _pause_overlay.visible and _test_settings_panel.visible:
		_show_test_settings(false)
		return

	_set_pause_menu_visible(not _pause_overlay.visible)


func _set_pause_menu_visible(visible: bool) -> void:
	if _is_player_dead:
		return
	if visible and _is_character_showcase_visible():
		_set_character_showcase_visible(false)

	_pause_overlay.visible = visible
	if _combat_developer_overlay != null:
		_combat_developer_overlay.visible = false
	_pause_menu_panel.visible = visible
	_pause_settings_panel.visible = false
	_test_settings_panel.visible = false
	_character_switch_panel.visible = false
	if _risk_contract_view_panel != null:
		_risk_contract_view_panel.visible = false
	if _hack_protocol_view_panel != null:
		_hack_protocol_view_panel.visible = false
	_sync_mode_controls()
	_set_battle_tree_paused(visible)
	if visible:
		_developer_sequence_index = 0
		if _inventory_panel.visible:
			_set_inventory_visible(false)
		if _large_map_overlay.visible:
			_set_large_map_visible(false)
		_refresh_combat_input_state()
		_sync_pause_master_volume_slider()
		_resume_button.grab_focus()
	else:
		_refresh_combat_input_state()
	_sync_risk_contract_view_visibility()


func _show_pause_settings(visible: bool) -> void:
	_hide_mode_extension_views()
	_pause_menu_panel.visible = not visible
	_pause_settings_panel.visible = visible
	_test_settings_panel.visible = false
	_character_switch_panel.visible = false
	if visible:
		_show_pause_key_binding_page(false)
		_sync_pause_master_volume_slider()
		_pause_settings_back_button.grab_focus()
	else:
		_pause_settings_button.grab_focus()
	_sync_risk_contract_view_visibility()


func _show_pause_key_binding_page(visible: bool) -> void:
	# 暂停设置首页控件遍历项；取值为设置首页直接控件，默认与按键绑定页面互斥显示。
	for home_control in _pause_settings_home_controls:
		if home_control != null:
			home_control.visible = not visible

	if _pause_key_binding_page != null:
		_pause_key_binding_page.visible = visible

	if visible and _pause_key_binding_back_button != null:
		_pause_key_binding_back_button.grab_focus()
	elif _pause_settings_back_button != null:
		_pause_settings_back_button.grab_focus()


func _is_pause_key_binding_page_visible() -> bool:
	return _pause_key_binding_page != null and _pause_key_binding_page.visible


func _show_test_settings(visible: bool) -> void:
	if visible and not _can_use_training_tools():
		return

	_hide_mode_extension_views()
	_pause_menu_panel.visible = not visible
	_pause_settings_panel.visible = false
	_test_settings_panel.visible = visible
	_character_switch_panel.visible = false
	if visible:
		_sync_test_settings_controls()
		_clear_monsters_button.grab_focus()
	else:
		if _test_settings_button.visible:
			_test_settings_button.grab_focus()
		else:
			_resume_button.grab_focus()
	_sync_risk_contract_view_visibility()


func _show_character_switch(visible: bool) -> void:
	if visible and not _can_use_training_tools():
		return

	_hide_mode_extension_views()
	_pause_menu_panel.visible = false
	_pause_settings_panel.visible = false
	_test_settings_panel.visible = not visible
	_character_switch_panel.visible = visible
	if visible:
		_switch_character_stelle_button.grab_focus()
	else:
		_switch_character_button.grab_focus()
	_sync_risk_contract_view_visibility()


func _sync_test_settings_controls() -> void:
	if _stats_component == null:
		_infinite_energy_check_button.set_pressed_no_signal(false)
		_infinite_health_check_button.set_pressed_no_signal(false)
		_active_skill_no_cooldown_check_button.set_pressed_no_signal(false)
		return

	# 无限能量状态；取值来自属性组件，默认 false，修改会影响训练场设置开关显示。
	var infinite_energy_enabled: bool = bool(_stats_component.get("infinite_energy"))
	# 无限血量状态；取值来自属性组件，默认 false，修改会影响训练场设置开关显示。
	var infinite_health_enabled: bool = bool(_stats_component.get("infinite_health"))
	_infinite_energy_check_button.set_pressed_no_signal(infinite_energy_enabled)
	_infinite_health_check_button.set_pressed_no_signal(infinite_health_enabled)
	# 主动技能无冷却状态；由独立技能组件维护，角色切换后读取新组件默认状态而不写入永久存档。
	var active_skill_no_cooldown_enabled: bool = bool(_active_skill_component.call("is_cooldown_disabled")) if _active_skill_component != null and _active_skill_component.has_method("is_cooldown_disabled") else false
	_active_skill_no_cooldown_check_button.set_pressed_no_signal(active_skill_no_cooldown_enabled)


func _sync_pause_master_volume_slider() -> void:
	if _master_bus_index < 0:
		return

	# 当前 Master 音量线性值；取值为 0 到 1，默认由 AudioServer 读取，修改会影响暂停设置滑条初始位置。
	var linear_volume: float = 0.0 if AudioServer.is_bus_mute(_master_bus_index) else db_to_linear(AudioServer.get_bus_volume_db(_master_bus_index))
	_pause_master_volume_slider.set_value_no_signal(clampf(linear_volume, 0.0, 1.0) * 100.0)
	_refresh_pause_master_volume_label(_pause_master_volume_slider.value)


func _apply_pause_master_volume(value: float) -> void:
	if _master_bus_index < 0:
		return

	# 标准化音量值；取值为 0 到 1，默认由滑条百分比换算，修改会影响最终写入 AudioServer 的音量。
	var linear_volume: float = clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(_master_bus_index, linear_volume <= 0.001)
	if linear_volume > 0.001:
		AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(linear_volume))

	_refresh_pause_master_volume_label(value)


func _refresh_pause_master_volume_label(value: float) -> void:
	_pause_master_volume_value_label.text = "%d%%" % roundi(value)


func _get_component_cooldown_ratio(component: Node, component_has_cooldown_ratio: bool) -> float:
	# 接口判定来源补充：has_method 结果已在组件注入处缓存为布尔参数，每帧刷新不再做方法名字符串查找。
	if component == null or not component_has_cooldown_ratio:
		return 0.0

	return clampf(float(component.call("get_cooldown_ratio")), 0.0, 1.0)


func _get_component_cooldown_duration(component: Node, component_has_cooldown_duration: bool) -> float:
	# 接口判定来源补充：has_method 结果已在组件注入处缓存为布尔参数，每帧刷新不再做方法名字符串查找。
	if component == null or not component_has_cooldown_duration:
		return 0.0

	return maxf(float(component.call("get_cooldown_duration")), 0.0)


func _get_current_character_display_name() -> String:
	if _game_world != null and _game_world.has_method("get_selected_character_name"):
		# 游戏世界角色名；取值来自当前会话选择，默认用于 HUD 最优先显示。
		var world_character_name: String = str(_game_world.call("get_selected_character_name"))
		if not world_character_name.is_empty():
			return world_character_name

	if _player != null:
		# 玩家节点显示名；取值来自 player_display_name 属性，默认作为 GameWorld 缺失时的兜底。
		var player_character_name: String = str(_player.get("player_display_name"))
		if not player_character_name.is_empty():
			return player_character_name

	return "角色"


func _on_weapon_slot_drop_received(drop_data: Dictionary, target_context: String, target_kind: String, target_index: int) -> void:
	if _equipment_component == null or not drop_data.has("weapon_data"):
		return

	# 被拖拽武器资源；取值为 Resource 或 null，默认来自槽位拖拽数据，修改会影响装备和卸下目标。
	var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
	if dragged_weapon == null:
		return

	if target_context == "inventory":
		_handle_drop_to_inventory(drop_data, target_index)
	elif target_context == "equipment":
		_handle_drop_to_equipment(drop_data, target_kind, target_index)

	_refresh_equipment()
	_rebuild_inventory_slots()


func _handle_drop_to_inventory(drop_data: Dictionary, target_index: int) -> void:
	if _inventory_component == null:
		return

	# 拖拽来源上下文；取值为 equipment 或 inventory，默认空字符串表示非法来源，修改会影响背包投放分支。
	var source_context: String = str(drop_data.get("source_context", ""))
	if source_context == "inventory":
		# 背包拖拽来源索引；取值为有效背包下标，默认来自拖拽数据，修改会影响物品排序来源。
		var source_index: int = int(drop_data.get("slot_index", -1))
		if _inventory_component.has_method("move_item"):
			_inventory_component.call("move_item", source_index, target_index)
	elif source_context == "equipment":
		# 被卸下武器资源；取值为 Resource 或 null，默认来自拖拽数据，修改会影响回到背包的对象。
		var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
		if _unequip_from_drop_source(drop_data):
			_add_item_to_inventory(dragged_weapon, target_index)


func _handle_drop_to_equipment(drop_data: Dictionary, target_kind: String, target_index: int) -> void:
	# 拖拽来源上下文；取值为 equipment 或 inventory，默认空字符串表示非法来源，修改会影响装备投放分支。
	var source_context: String = str(drop_data.get("source_context", ""))
	if source_context == "inventory":
		_equip_inventory_weapon_to_target(drop_data, target_kind, target_index)
	elif source_context == "equipment":
		_move_equipped_weapon_to_target(drop_data, target_kind, target_index)


func _equip_inventory_weapon_to_target(drop_data: Dictionary, target_kind: String, target_index: int) -> void:
	if _inventory_component == null:
		return

	# 被装备武器资源；取值为 Resource 或 null，默认来自拖拽数据，修改会影响目标装备槽内容。
	var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
	if dragged_weapon == null:
		return

	# 背包来源索引；取值为有效背包下标，默认来自拖拽数据，修改会影响被替换武器返回背包的位置。
	var source_index: int = int(drop_data.get("slot_index", -1))
	if not _inventory_has_item(dragged_weapon):
		return

	# 目标槽原有武器；取值为 Resource 或 null，默认用于装备替换后放回背包，修改会影响替换规则。
	var replaced_weapon: Resource = _get_equipped_weapon(target_kind, target_index)
	if not _remove_item_from_inventory(dragged_weapon):
		return

	if not _equip_weapon_to_target(target_kind, target_index, dragged_weapon):
		_add_item_to_inventory(dragged_weapon, source_index)
		return

	if replaced_weapon != null and replaced_weapon != dragged_weapon:
		_add_item_to_inventory(replaced_weapon, source_index)


func _move_equipped_weapon_to_target(drop_data: Dictionary, target_kind: String, target_index: int) -> void:
	# 拖拽来源槽类型；取值为 ranged 或 melee，默认来自拖拽数据，修改会影响装备槽互拖规则。
	var source_kind: String = str(drop_data.get("slot_kind", ""))
	# 拖拽来源槽索引；取值为有效远程槽下标或 -1，默认来自拖拽数据，修改会影响原槽清理目标。
	var source_index: int = int(drop_data.get("slot_index", -1))
	if source_kind == target_kind and source_index == target_index:
		return

	# 被移动武器资源；取值为 Resource 或 null，默认来自拖拽数据，修改会影响目标装备槽内容。
	var dragged_weapon: Resource = drop_data["weapon_data"] as Resource
	if dragged_weapon == null:
		return

	# 目标槽原有武器；取值为 Resource 或 null，默认用于同类型装备槽之间交换，修改会影响互拖结果。
	var target_weapon: Resource = _get_equipped_weapon(target_kind, target_index)
	# 来源远程槽是否当前选中；取值为 true/false，默认用于交换后让当前武器跟随被拖拽武器，修改会影响切枪状态。
	var source_was_current_ranged: bool = _is_current_ranged_source(source_kind, source_index)
	if not _equip_weapon_to_target(target_kind, target_index, dragged_weapon):
		return

	if source_kind == "ranged" and target_kind == "ranged":
		if target_weapon != null and target_weapon != dragged_weapon:
			_equipment_component.call("equip_ranged_weapon", source_index, target_weapon)
		elif _equipment_component.has_method("unequip_ranged_weapon"):
			_equipment_component.call("unequip_ranged_weapon", source_index)

		if source_was_current_ranged and _equipment_component.has_method("equip_ranged_slot"):
			_equipment_component.call("equip_ranged_slot", target_index)


func _unequip_from_drop_source(drop_data: Dictionary) -> bool:
	if str(drop_data.get("source_context", "")) != "equipment":
		return false

	# 拖拽来源槽类型；取值来自拖拽数据，默认用于判断卸下远程或近战，修改会影响卸下分支。
	var source_kind: String = str(drop_data.get("slot_kind", ""))
	if source_kind == "ranged" and _equipment_component.has_method("unequip_ranged_weapon"):
		# 拖拽来源远程槽索引；取值为有效槽下标，默认来自拖拽数据，修改会影响被卸下的远程槽。
		var source_index: int = int(drop_data.get("slot_index", -1))
		return bool(_equipment_component.call("unequip_ranged_weapon", source_index))
	elif source_kind == "melee" and _equipment_component.has_method("unequip_melee_weapon"):
		return bool(_equipment_component.call("unequip_melee_weapon"))

	return false


func _get_equipped_weapon(target_kind: String, target_index: int) -> Resource:
	if target_kind == "ranged" and _equipment_component.has_method("get_ranged_weapon"):
		return _equipment_component.call("get_ranged_weapon", target_index) as Resource
	if target_kind == "melee" and _equipment_component.has_method("get_melee_weapon"):
		return _equipment_component.call("get_melee_weapon") as Resource

	return null


func _equip_weapon_to_target(target_kind: String, target_index: int, weapon_data: Resource) -> bool:
	if target_kind == "ranged" and _equipment_component.has_method("equip_ranged_weapon"):
		return bool(_equipment_component.call("equip_ranged_weapon", target_index, weapon_data))
	if target_kind == "melee" and _equipment_component.has_method("equip_melee_weapon"):
		return bool(_equipment_component.call("equip_melee_weapon", weapon_data))

	return false


func _inventory_has_item(item_data: Resource) -> bool:
	if _inventory_component == null or item_data == null or not _inventory_component.has_method("has_item"):
		return false

	return bool(_inventory_component.call("has_item", item_data))


func _remove_item_from_inventory(item_data: Resource) -> bool:
	if _inventory_component == null or item_data == null or not _inventory_component.has_method("remove_item"):
		return false

	return bool(_inventory_component.call("remove_item", item_data))


func _add_item_to_inventory(item_data: Resource, target_index: int) -> bool:
	if _inventory_component == null or item_data == null:
		return false

	if _inventory_component.has_method("add_item_at"):
		return bool(_inventory_component.call("add_item_at", item_data, target_index))
	if _inventory_component.has_method("add_item"):
		return bool(_inventory_component.call("add_item", item_data))

	return false


func _get_inventory_item_count() -> int:
	if _inventory_component == null or not _inventory_component.has_method("get_item_count"):
		return 0

	return int(_inventory_component.call("get_item_count"))


func _clear_training_monsters() -> void:
	if _game_world == null or not _game_world.has_method("clear_monsters"):
		return

	_game_world.call("clear_monsters")


func _respawn_training_monsters() -> void:
	if _game_world == null or not _game_world.has_method("respawn_monsters"):
		return

	_game_world.call("respawn_monsters")


func _set_infinite_energy_enabled(enabled: bool) -> void:
	if _stats_component == null or not _stats_component.has_method("set_infinite_energy"):
		return

	_stats_component.call("set_infinite_energy", enabled)
	_refresh_stats()


func _set_infinite_health_enabled(enabled: bool) -> void:
	if _stats_component == null or not _stats_component.has_method("set_infinite_health"):
		return

	_stats_component.call("set_infinite_health", enabled)
	_refresh_stats()


func _set_active_skill_no_cooldown_enabled(enabled: bool) -> void:
	## 将训练场主动技能无冷却开关写入当前技能组件；组件缺失时安全忽略，不影响其他训练设置。
	if _active_skill_component == null or not _active_skill_component.has_method("set_cooldown_disabled"):
		return
	_active_skill_component.call("set_cooldown_disabled", enabled)


func _switch_training_character(character_id: String) -> void:
	if not _can_use_training_tools():
		return

	if _game_world == null or not _game_world.has_method("switch_character"):
		return

	_game_world.call("switch_character", character_id)
	_refresh_all()
	_show_character_switch(false)


func _is_current_ranged_source(source_kind: String, source_index: int) -> bool:
	if source_kind != "ranged" or not _equipment_component.has_method("get_current_ranged_slot"):
		return false

	return int(_equipment_component.call("get_current_ranged_slot")) == source_index


func _on_health_changed(_current_health: float, _max_health: float) -> void:
	_refresh_stats()


func _on_energy_changed(_current_energy: float, _max_energy: float) -> void:
	_refresh_stats()


func _on_equipment_changed() -> void:
	if _equipment_component != null and _equipment_component.has_method("get_ranged_slot_count"):
		# 当前装备组件远程槽数量；取值来自装备组件，默认用于判断是否需要重建 UI，修改会影响槽位重建频率。
		var slot_count: int = int(_equipment_component.call("get_ranged_slot_count"))
		if _ranged_slot_controls.size() != slot_count or _melee_slot_control == null:
			_rebuild_equipment_slots()

	_refresh_equipment()
	if _inventory_panel.visible:
		_refresh_inventory_equipment_slots()


func _on_inventory_changed() -> void:
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _on_weapon_durability_changed(_weapon_data: Resource) -> void:
	# 所有耐久显示控件；战斗底栏、背包装备栏和背包武器槽都复用独立刷新接口，避免每次射击重建完整背包。
	var durability_controls: Array = _ranged_slot_controls + _inventory_slot_controls + _inventory_equipment_ranged_controls
	if _melee_slot_control != null:
		durability_controls.append(_melee_slot_control)
	if _inventory_equipment_melee_control != null:
		durability_controls.append(_inventory_equipment_melee_control)
	for durability_control in durability_controls:
		if durability_control != null and durability_control.has_method("refresh_durability"):
			durability_control.call("refresh_durability")


func _on_ranged_weapon_fired(_projectile: Node2D) -> void:
	if _equipment_component == null or not _equipment_component.has_method("get_current_ranged_slot"):
		return

	_last_cooling_ranged_slot = int(_equipment_component.call("get_current_ranged_slot"))


func _on_weapon_attack_succeeded(source_kind: String, source_index: int, _weapon_data: Resource) -> void:
	## 记录远程主组件实际对应的装备槽；混合副通道冷却不进入 HUD，也不与来源槽主冷却合并比较。
	if source_kind == "ranged":
		_last_cooling_ranged_slot = source_index


func _on_player_died() -> void:
	_is_player_dead = true
	if _is_casual_mode:
		# 训练场与超频骇入不进入正式结算；下一空闲帧恢复玩家生命并重新开放输入，避免死亡标记永久锁死 HUD。
		call_deferred("_revive_training_player")
		return
	# 联机观战分支；仍有存活队友时由战斗同步器接管视角并推迟死亡结算，观战结束后经回调恢复原结算流程，单机无同步器时直接结算。
	var network_combat_sync: Node = get_tree().get_first_node_in_group("network_combat_sync")
	if network_combat_sync != null and network_combat_sync.has_method("try_begin_spectator_mode") and bool(network_combat_sync.call("try_begin_spectator_mode", Callable(self, "_show_deferred_death_settlement"))):
		return
	_show_failure_settlement("角色死亡", 1.0 - clampf(failure_backpack_loss_ratio, 0.0, 1.0), 1.0 - clampf(failure_equipment_loss_ratio, 0.0, 1.0))


func _show_deferred_death_settlement() -> void:
	## 观战结束回调；执行被推迟的死亡结算，参数与即时死亡结算完全一致，重复结算由结算完成标记保护。
	if _is_casual_mode or not _is_player_dead:
		return
	_show_failure_settlement("角色死亡", 1.0 - clampf(failure_backpack_loss_ratio, 0.0, 1.0), 1.0 - clampf(failure_equipment_loss_ratio, 0.0, 1.0))


func _revive_training_player() -> void:
	# 娱乐模式复活补充：训练场与超频骇入共用本复活流程，正式模式不允许触发。
	if not _is_casual_mode or _stats_component == null:
		return
	# 最大生命；训练场复活直接恢复满血，不修改角色或装备提供的生命上限。
	var maximum_health: float = maxf(float(_stats_component.get("max_health")), 1.0)
	if _stats_component.has_method("set_health"):
		_stats_component.call("set_health", maximum_health)
	_is_player_dead = false
	_set_death_overlay_visible(false)
	_refresh_combat_input_state()


func _on_inventory_filter_all_pressed() -> void:
	_set_inventory_filter(INVENTORY_FILTER_ALL)


func _on_inventory_filter_melee_pressed() -> void:
	_set_inventory_filter(INVENTORY_FILTER_MELEE)


func _on_inventory_filter_ranged_pressed() -> void:
	_set_inventory_filter(INVENTORY_FILTER_RANGED)


func _on_inventory_filter_stones_pressed() -> void:
	_set_inventory_filter(INVENTORY_FILTER_STONES)


func _on_inventory_filter_items_pressed() -> void:
	_set_inventory_filter(INVENTORY_FILTER_ITEMS)


func _on_inventory_primary_category_pressed(category_name: String) -> void:
	_inventory_primary_category = category_name
	_inventory_filter = INVENTORY_FILTER_ALL
	_clear_inventory_stone_attribute_filter()
	_clear_inventory_stone_quality_filter()
	_refresh_inventory_filter_buttons()
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _on_inventory_search_changed(_new_text: String) -> void:
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _on_inventory_sort_selected(item_index: int) -> void:
	# 排序元数据；异常选项回退获得时间。
	var selected_sort_mode: String = str(_inventory_sort_option.get_item_metadata(item_index))
	_inventory_sort_mode = selected_sort_mode if selected_sort_mode in [InventoryQuery.SORT_ACQUIRED_TIME, InventoryQuery.SORT_ITEM_VALUE, InventoryQuery.SORT_DURABILITY] else InventoryQuery.SORT_ACQUIRED_TIME
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _on_inventory_stone_quality_selected(item_index: int) -> void:
	## 应用局内背包强化石品质条件；非法选项回退全部品质，真实背包顺序与所有权保持不变。
	var selected_quality_id: String = str(_inventory_stone_quality_option.get_item_metadata(item_index)) if item_index >= 0 and item_index < _inventory_stone_quality_option.item_count else ""
	_inventory_stone_quality_filter = selected_quality_id if selected_quality_id in EnhancementRules.QUALITY_ORDER else ""
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _clear_inventory_stone_quality_filter() -> void:
	## 清空局内背包强化石品质条件并恢复“全部”；切换主分类和目标选择页时统一调用。
	_inventory_stone_quality_filter = ""
	if _inventory_stone_quality_option != null:
		_inventory_stone_quality_option.select(0)


func _on_inventory_stone_attribute_selected(item_index: int) -> void:
	if item_index <= 0:
		_inventory_stone_attribute_option.select(0)
		return
	# 当前筛选键；为空的分隔项不会进入多选集合。
	var filter_key: String = str(_inventory_stone_attribute_option.get_item_metadata(item_index))
	if filter_key.is_empty():
		return
	# 新勾选状态；已存在条件再次点击时从并集筛选中移除。
	var should_select: bool = filter_key not in _inventory_stone_attribute_filter
	_inventory_stone_attribute_option.get_popup().set_item_checked(item_index, should_select)
	if should_select:
		_inventory_stone_attribute_filter.append(filter_key)
	else:
		_inventory_stone_attribute_filter.erase(filter_key)
	_refresh_inventory_stone_attribute_filter_display()
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _on_clear_inventory_stone_attribute_filter_pressed() -> void:
	_clear_inventory_stone_attribute_filter()
	if _inventory_panel.visible:
		_rebuild_inventory_slots()


func _clear_inventory_stone_attribute_filter() -> void:
	_inventory_stone_attribute_filter.clear()
	if _inventory_stone_attribute_option == null:
		return
	for item_index in range(1, _inventory_stone_attribute_option.item_count):
		if not str(_inventory_stone_attribute_option.get_item_metadata(item_index)).is_empty():
			_inventory_stone_attribute_option.get_popup().set_item_checked(item_index, false)
	_refresh_inventory_stone_attribute_filter_display()


func _refresh_inventory_stone_attribute_filter_display() -> void:
	if _inventory_stone_attribute_option == null:
		return
	_inventory_stone_attribute_option.set_item_text(0, "强化筛选（%d）" % _inventory_stone_attribute_filter.size())
	_inventory_stone_attribute_option.select(0)
	# 勾选状态同步；切回摘要项后重新应用全部多选条件，避免弹出菜单中的复选框被清空而看不出当前筛选。
	for item_index in range(1, _inventory_stone_attribute_option.item_count):
		# 当前筛选键；分隔项元数据为空，仅真实属性方向选项参与同步。
		var filter_key: String = str(_inventory_stone_attribute_option.get_item_metadata(item_index))
		if not filter_key.is_empty():
			_inventory_stone_attribute_option.get_popup().set_item_checked(item_index, filter_key in _inventory_stone_attribute_filter)
	if _inventory_stone_attribute_clear_button != null:
		_inventory_stone_attribute_clear_button.disabled = _inventory_stone_attribute_filter.is_empty()


func _on_combat_resource_action_requested(item_resource: Resource) -> void:
	if item_resource == null:
		return
	if str(item_resource.get("item_kind")) == "equipment":
		_combat_action_weapon_resource = item_resource
		_combat_action_stone_resource = null
		_combat_action_weapon_source_index = -1
		var equipment_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
		_combat_action_item_quantity = 1
		_inventory_item_action_menu.clear_actions()
		_inventory_item_action_menu.add_action("装备", INVENTORY_ITEM_ACTION_EQUIP)
		_add_inventory_discard_actions(1)
		_inventory_item_action_menu.present_at(get_viewport().get_mouse_position())
		return
	_combat_action_stone_resource = item_resource
	_combat_action_weapon_resource = null
	_combat_action_weapon_source_index = -1
	# 全局库存服务；用于读取当前资源真实堆叠数量并决定丢弃菜单结构。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	_combat_action_item_quantity = int(global_inventory.call("get_storage_resource_quantity", item_resource, "backpack")) if global_inventory != null and global_inventory.has_method("get_storage_resource_quantity") else 1
	_inventory_item_action_menu.clear_actions()
	if str(item_resource.get("item_kind")) in ["repair_kit", "consumable"]:
		_inventory_item_action_menu.add_action("使用", INVENTORY_ITEM_ACTION_USE)
	_add_inventory_discard_actions(_combat_action_item_quantity)
	_inventory_item_action_menu.present_at(get_viewport().get_mouse_position())


func _on_inventory_item_action_menu_id_pressed(action_id: int) -> void:
	if action_id == INVENTORY_ITEM_ACTION_USE and _combat_action_stone_resource != null:
		if str(_combat_action_stone_resource.get("item_kind")) == "consumable":
			# 临时增益组件；只有效果成功应用后才从背包原子扣除一个道具，异常配置不会造成物品丢失。
			var temporary_buff_component: Node = _player.get_node_or_null("TemporaryBuffComponent") if _player != null else null
			# 全局库存服务；消耗品与修复包共用背包堆叠数量，但不进入耐久目标选择流程。
			var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
			if temporary_buff_component != null and temporary_buff_component.has_method("apply_consumable") and bool(temporary_buff_component.call("apply_consumable", _combat_action_stone_resource)) and global_inventory != null and global_inventory.has_method("consume_storage_resource_quantity"):
				global_inventory.call("consume_storage_resource_quantity", _combat_action_stone_resource, "backpack", 1)
			_combat_action_stone_resource = null
			_combat_action_item_quantity = 1
			if _shared_backpack_panel != null:
				_shared_backpack_panel.refresh()
			return
		_pending_combat_stone_resource = _combat_action_stone_resource
		_combat_action_stone_resource = null
		_capture_combat_stone_return_view()
		# 强化目标选择页；自动显示全部背包武器并清空资源属性筛选和关键词。
		_inventory_primary_category = InventoryQuery.PRIMARY_WEAPONS
		_inventory_filter = INVENTORY_FILTER_ALL
		_clear_inventory_stone_attribute_filter()
		_clear_inventory_stone_quality_filter()
		if _inventory_search_edit != null:
			_inventory_search_edit.clear()
		_refresh_inventory_filter_buttons()
		_refresh_equipment()
		_rebuild_inventory_slots()
	elif action_id == INVENTORY_ITEM_ACTION_EQUIP and _combat_action_weapon_resource != null and _equipment_component != null:
		# 待装备武器；远程目标为当前手持槽，近战目标为唯一近战槽。
		var weapon_resource: Resource = _combat_action_weapon_resource
		if str(weapon_resource.get("item_kind")) == "equipment":
			# 防具部位；从背包原子装备到对应固定槽，被替换装备回到原背包位置。
			var armor_slot: String = str(weapon_resource.get("equipment_slot"))
			var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
			if global_inventory != null and global_inventory.has_method("transfer_storage_to_equipment"):
				global_inventory.call("transfer_storage_to_equipment", weapon_resource, "backpack", "armor_" + armor_slot)
			_refresh_equipment()
			_rebuild_inventory_slots()
			_combat_action_weapon_resource = null
			_combat_action_weapon_source_index = -1
			return
		# 装备目标类型；与武器 weapon_type 一致，用于复用原子替换流程。
		var target_kind: String = "ranged" if str(weapon_resource.get("weapon_type")) == "hybrid" else str(weapon_resource.get("weapon_type"))
		# 远程目标下标；近战槽使用 -1，远程读取当前手持槽以实现直接替换。
		var target_index: int = int(_equipment_component.call("get_current_ranged_slot")) if target_kind == "ranged" else -1
		# 伪装拖拽数据；复用现有背包到装备槽的原子替换逻辑，避免点击装备产生第二套所有权流程。
		var drop_data: Dictionary = {"source_context": "inventory", "slot_kind": "inventory", "slot_index": _combat_action_weapon_source_index, "weapon_data": weapon_resource}
		_equip_inventory_weapon_to_target(drop_data, target_kind, target_index)
		_refresh_equipment()
		_rebuild_inventory_slots()
		_combat_action_weapon_resource = null
		_combat_action_weapon_source_index = -1
	elif action_id == INVENTORY_ITEM_ACTION_DISCARD_ALL:
		# 整组丢弃目标；武器优先使用武器引用，资源使用当前资源菜单引用。
		var discard_resource: Resource = _combat_action_weapon_resource if _combat_action_weapon_resource != null else _combat_action_stone_resource
		_discard_combat_inventory_item(discard_resource, _combat_action_item_quantity)
	elif action_id == INVENTORY_ITEM_ACTION_DISCARD_PARTIAL:
		# 部分丢弃目标；只对数量大于 1 的背包资源显示该操作。
		var partial_resource: Resource = _combat_action_weapon_resource if _combat_action_weapon_resource != null else _combat_action_stone_resource
		if partial_resource != null and _combat_quantity_dialog != null:
			_pending_discard_resource = partial_resource
			_combat_quantity_dialog.present_discard(str(partial_resource.get("display_name")), maxi(_combat_action_item_quantity, 1))


func _on_combat_weapon_selected(weapon_resource: Resource, selected_context: String, selected_kind: String, selected_index: int) -> void:
	if weapon_resource == null or not _inventory_panel.visible:
		return
	if _pending_combat_stone_resource != null:
		if not _can_pending_combat_repair_target(weapon_resource):
			return
		_apply_combat_repair(_pending_combat_stone_resource, weapon_resource)
		return
	if selected_context == "equipment" and selected_kind == "ranged" and _equipment_component != null and _equipment_component.has_method("equip_ranged_slot"):
		_equipment_component.call("equip_ranged_slot", selected_index)
		_refresh_equipment()
		_refresh_inventory_equipment_slots()
		return
	if selected_context != "inventory":
		return
	_combat_action_weapon_resource = weapon_resource
	_combat_action_weapon_source_index = selected_index
	_combat_action_stone_resource = null
	_combat_action_item_quantity = 1
	_inventory_item_action_menu.clear_actions()
	_inventory_item_action_menu.add_action("装备", INVENTORY_ITEM_ACTION_EQUIP)
	_add_inventory_discard_actions(1)
	_inventory_item_action_menu.present_at(get_viewport().get_mouse_position())


func _add_inventory_discard_actions(item_quantity: int) -> void:
	# 丢弃菜单；单件显示“丢弃”，堆叠资源显示“全部丢弃”和“部分丢弃”。
	if item_quantity > 1:
		_inventory_item_action_menu.add_action("全部丢弃", INVENTORY_ITEM_ACTION_DISCARD_ALL, false, true)
		_inventory_item_action_menu.add_action("部分丢弃", INVENTORY_ITEM_ACTION_DISCARD_PARTIAL, false, true)
	else:
		_inventory_item_action_menu.add_action("丢弃", INVENTORY_ITEM_ACTION_DISCARD_ALL, false, true)


func _on_combat_quantity_confirmed(quantity: int) -> void:
	if _pending_discard_resource == null:
		return
	# 已确认丢弃资源；清空等待状态后执行，避免重复信号再次消费。
	var discard_resource: Resource = _pending_discard_resource
	_pending_discard_resource = null
	_discard_combat_inventory_item(discard_resource, quantity)


func _discard_combat_inventory_item(item_resource: Resource, requested_quantity: int) -> void:
	if item_resource == null or _game_world == null:
		return
	if str(item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"]:
		# 武器丢弃复用现有拖出背包流程，保留原资源实例、耐久、强化状态和生成失败回滚。
		var drop_data: Dictionary = {"source_context": "inventory", "slot_kind": "inventory", "slot_index": _combat_action_weapon_source_index, "weapon_data": item_resource}
		_drop_inventory_source_weapon_to_world(drop_data, item_resource)
	else:
		# 全局库存服务；资源堆叠必须在地面生成完成后从背包原子扣除。
		var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
		if global_inventory == null or not global_inventory.has_method("get_storage_resource_quantity") or not _game_world.has_method("spawn_item_drop_near_player"):
			return
		# 实际丢弃数量；弹窗确认后再次按背包当前数量限制，避免数量变化造成负堆叠。
		var stored_quantity: int = int(global_inventory.call("get_storage_resource_quantity", item_resource, "backpack"))
		if stored_quantity <= 0:
			return
		# 实际丢弃数量；限制到当前真实堆叠，防止旧弹窗数量过期。
		var discard_quantity: int = clampi(requested_quantity, 1, stored_quantity)
		# 地面堆叠资源；整组只创建一个节点并携带数量，避免最多 99 件资源在同一帧深拷贝和实例化造成卡顿。
		# 现行限制补充：每个地面堆叠节点最多携带 10 件资源。
		var dropped_resource: Resource = item_resource.duplicate(true) as Resource
		if dropped_resource == null or not bool(_game_world.call("spawn_item_drop_near_player", dropped_resource, discard_quantity)):
			return
		if not bool(global_inventory.call("consume_storage_resource_quantity", item_resource, "backpack", discard_quantity)):
			return
		if global_inventory.has_method("register_combat_dropped_resource"):
			global_inventory.call("register_combat_dropped_resource", dropped_resource)
	_combat_action_stone_resource = null
	_combat_action_weapon_resource = null
	_combat_action_weapon_source_index = -1
	_combat_action_item_quantity = 1
	# 共享背包接管局内物品列表后只刷新组件；旧列表查询控件未再构建，继续调用旧重建函数会访问空搜索框。
	if _shared_backpack_panel != null:
		_shared_backpack_panel.refresh()
	_refresh_nearby_drop_panel()


func _on_combat_enhancement_drop_received(stone_resource: Resource, source_location: String, weapon_resource: Resource) -> void:
	if source_location != "backpack" or stone_resource == null or weapon_resource == null:
		return
	_apply_combat_enhancement(stone_resource, weapon_resource)


func _on_combat_repair_kit_drop_received(repair_kit_resource: Resource, source_location: String, weapon_resource: Resource) -> void:
	if source_location != "backpack" or repair_kit_resource == null or weapon_resource == null:
		return
	_apply_combat_repair(repair_kit_resource, weapon_resource)


func _apply_combat_repair(repair_kit_resource: Resource, weapon_resource: Resource) -> void:
	# 全局库存服务；修复包消费与耐久写入必须由统一所有权服务完成，避免 HUD 直接篡改资源。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory == null or not global_inventory.has_method("use_repair_kit_with_result"):
		return
	# 修复结果；点击选择和拖动投放共用同一原子消费流程，满耐久武器不会消耗道具。
	var repair_result: Dictionary = global_inventory.call("use_repair_kit_with_result", repair_kit_resource, "backpack", weapon_resource) as Dictionary
	if not bool(repair_result.get("success", false)):
		return
	# 是否需要恢复页面；使用菜单进入武器选择页后恢复到原资源分页，拖动修复保持当前页面。
	var should_restore_stone_view: bool = _pending_combat_stone_resource != null and _combat_stone_return_view_pending
	_pending_combat_stone_resource = null
	if should_restore_stone_view:
		_restore_combat_stone_return_view()
	_refresh_equipment()
	_rebuild_inventory_slots()


func _apply_combat_enhancement(stone_resource: Resource, weapon_resource: Resource) -> void:
	if _inventory_component == null or not _inventory_component.has_method("use_enhancement_stone_with_result"):
		return
	# 局内强化结果；点击选择和拖动投放共用同一个消费与弹窗流程。
	var enhancement_result: Dictionary = _inventory_component.call("use_enhancement_stone_with_result", stone_resource, weapon_resource) as Dictionary
	if bool(enhancement_result.get("success", false)):
		# 是否需要恢复页面；只有点击“使用”进入武器选择页时为 true，直接拖拽强化保持当前页面。
		var should_restore_stone_view: bool = _pending_combat_stone_resource != null and _combat_stone_return_view_pending
		_pending_combat_stone_resource = null
		if should_restore_stone_view:
			_restore_combat_stone_return_view()
		_present_combat_enhancement_result(enhancement_result)
	_refresh_equipment()
	_rebuild_inventory_slots()


func _on_cancel_combat_stone_use_pressed() -> void:
	_pending_combat_stone_resource = null
	_combat_action_stone_resource = null
	if _combat_stone_return_view_pending:
		_restore_combat_stone_return_view()
	_refresh_equipment()
	_rebuild_inventory_slots()


func _present_combat_enhancement_result(enhancement_result: Dictionary) -> void:
	if _enhancement_result_dialog != null:
		_enhancement_result_dialog.present_result(enhancement_result)


func _capture_combat_stone_return_view() -> void:
	_combat_stone_return_view_pending = true
	_combat_stone_return_primary_category = _inventory_primary_category
	_combat_stone_return_filter = _inventory_filter
	_combat_stone_return_search_text = _inventory_search_edit.text if _inventory_search_edit != null else ""
	_combat_stone_return_attribute_filter = _inventory_stone_attribute_filter.duplicate()
	_combat_stone_return_quality_filter = _inventory_stone_quality_filter


func _restore_combat_stone_return_view() -> void:
	_combat_stone_return_view_pending = false
	_inventory_primary_category = _combat_stone_return_primary_category
	_inventory_filter = _combat_stone_return_filter
	_inventory_stone_attribute_filter = _combat_stone_return_attribute_filter.duplicate()
	_inventory_stone_quality_filter = _combat_stone_return_quality_filter
	if _inventory_search_edit != null:
		_inventory_search_edit.text = _combat_stone_return_search_text
	if _inventory_stone_attribute_option != null:
		for option_index in range(1, _inventory_stone_attribute_option.item_count):
			# 当前选项筛选键；根据返回页面保存的多选集合恢复勾选状态。
			var filter_key: String = str(_inventory_stone_attribute_option.get_item_metadata(option_index))
			if not filter_key.is_empty():
				_inventory_stone_attribute_option.get_popup().set_item_checked(option_index, filter_key in _inventory_stone_attribute_filter)
		_refresh_inventory_stone_attribute_filter_display()
	if _inventory_stone_quality_option != null:
		# 品质选项恢复；根据稳定元数据查找原选择，找不到时回退“全部”。
		var restored_quality_index: int = 0
		for option_index in range(_inventory_stone_quality_option.item_count):
			if str(_inventory_stone_quality_option.get_item_metadata(option_index)) == _inventory_stone_quality_filter:
				restored_quality_index = option_index
				break
		_inventory_stone_quality_option.select(restored_quality_index)
	_refresh_inventory_filter_buttons()


func _apply_danger_button_style(button: Button) -> void:
	UI_STYLE_GUIDE.apply_danger_button(button)


func _on_inventory_drop_area_drop_received(drop_data: Dictionary) -> void:
	# 背包末尾索引；取值为当前背包物品总数，默认用于空白区域投放，修改会影响卸下或排序后的落点。
	var target_index: int = _get_inventory_item_count()
	_handle_drop_to_inventory(drop_data, target_index)
	_refresh_equipment()
	_rebuild_inventory_slots()


func _on_weapon_slot_drag_released_outside(drop_data: Dictionary) -> void:
	if not _inventory_panel.visible:
		return

	if _is_pointer_inside_inventory_panel():
		return

	_drop_weapon_to_world(drop_data)


func _on_pickup_drop_button_pressed(drop_node: Node) -> void:
	_suppress_drop_list_combat_input()
	_pickup_drop(drop_node)
	_mark_input_as_handled()


func _on_pickup_drop_button_gui_input(event: InputEvent, drop_node: Node) -> void:
	if not _is_pressed_mouse_event(event):
		return

	_suppress_drop_list_combat_input()
	if _is_left_mouse_press_event(event):
		_pickup_drop(drop_node)

	_mark_input_as_handled()


func _on_nearby_drop_panel_gui_input(event: InputEvent) -> void:
	if not _is_pressed_mouse_event(event):
		return

	_suppress_drop_list_combat_input()
	_mark_input_as_handled()


func _suppress_drop_list_combat_input() -> void:
	_drop_list_combat_suppression_remaining = DROP_LIST_COMBAT_SUPPRESSION_DURATION
	_refresh_combat_input_state()


func _is_pressed_mouse_event(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false

	# 鼠标按钮事件；取值来自 UI gui_input，用于判断列表交互是否需要阻止战斗输入。
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	return mouse_event.pressed


func _is_left_mouse_press_event(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false

	# 鼠标按钮事件；取值来自 UI gui_input，用于只在左键按下时执行点击拾取。
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT


func _is_pointer_inside_inventory_panel() -> bool:
	if _inventory_panel == null:
		return false

	# 当前视口；取值可能在场景切换期间为空，默认为空时不执行鼠标区域判断。
	var current_viewport: Viewport = get_viewport()
	if current_viewport == null:
		return false

	# 鼠标屏幕位置；取值来自当前视口，用于区分拖拽释放在背包内还是背包外。
	var mouse_position: Vector2 = current_viewport.get_mouse_position()
	# 背包面板全局矩形；取值来自 Control 布局结果，默认用于判断拖出背包的边界。
	var inventory_rect: Rect2 = _inventory_panel.get_global_rect()
	return inventory_rect.has_point(mouse_position)


func _should_drop_ui_block_combat_input() -> bool:
	if _drop_list_combat_suppression_remaining > 0.0:
		return true

	return _is_pointer_inside_nearby_drop_panel()


func _is_pointer_inside_nearby_drop_panel() -> bool:
	if _nearby_drop_panel == null or not _nearby_drop_panel.visible:
		return false

	# 当前视口；取值可能在场景切换期间为空，默认为空时不阻止战斗输入。
	var current_viewport: Viewport = get_viewport()
	if current_viewport == null:
		return false

	# 鼠标屏幕位置；取值来自当前视口，用于判断掉落物列表是否正在被鼠标交互。
	var mouse_position: Vector2 = current_viewport.get_mouse_position()
	# 掉落物面板全局矩形；取值来自 Control 布局结果，默认用于屏蔽射击和暂停列表刷新。
	var panel_rect: Rect2 = _nearby_drop_panel.get_global_rect()
	return panel_rect.has_point(mouse_position)


func _mark_input_as_handled() -> void:
	# 当前视口；取值可能在场景切换后为空，默认只在有效时标记输入已处理。
	var current_viewport: Viewport = get_viewport()
	if current_viewport == null:
		return

	current_viewport.set_input_as_handled()


func _on_resume_button_pressed() -> void:
	_set_pause_menu_visible(false)


func _on_character_showcase_close_requested() -> void:
	_set_character_showcase_visible(false)


func _on_combat_developer_menu_closed() -> void:
	if _combat_developer_overlay != null:
		_combat_developer_overlay.visible = false
	if _pause_overlay.visible:
		_pause_menu_panel.visible = true
		_pause_settings_panel.visible = false
		_test_settings_panel.visible = false
		_character_switch_panel.visible = false
		_resume_button.grab_focus()
	_sync_risk_contract_view_visibility()
	_refresh_combat_input_state()


func _on_developer_infinite_health_toggled(enabled: bool) -> void:
	_set_infinite_health_enabled(enabled)
	_sync_test_settings_controls()


func _on_developer_infinite_energy_toggled(enabled: bool) -> void:
	_set_infinite_energy_enabled(enabled)
	_sync_test_settings_controls()


func _on_developer_weapon_durability_consumption_toggled(disabled: bool) -> void:
	if _player != null and _player.has_method("set_weapon_durability_consumption_disabled"):
		_player.call("set_weapon_durability_consumption_disabled", disabled)


func _on_developer_training_settings_requested() -> void:
	_developer_training_access_unlocked = true
	if _combat_developer_overlay != null:
		_combat_developer_overlay.visible = false
	_show_test_settings(true)
	_refresh_combat_input_state()


func _on_unlock_map_vision_button_pressed() -> void:
	## 训练场设置中的地图视野操作；只改变本局探索状态，不修改地图尺寸、标点或存档。
	if _game_world != null and _game_world.has_method("unlock_full_map_vision"):
		_game_world.call("unlock_full_map_vision")


func _on_pause_settings_button_pressed() -> void:
	_show_pause_settings(true)


func _on_risk_contract_view_button_pressed() -> void:
	## 打开本局风险合约只读面板；不会改变当前合约、刷新候选或恢复战斗运行。
	_show_risk_contract_view(true)


func _on_risk_contract_view_closed() -> void:
	## 关闭左栏面板后恢复查看入口；中央暂停菜单焦点仍保持原位置。
	_sync_risk_contract_view_visibility()
	if _risk_contract_view_button != null and _risk_contract_view_button.visible:
		_risk_contract_view_button.grab_focus()


func _on_hack_protocol_view_button_pressed() -> void:
	## 打开本机骇入协议只读面板；不会影响碎片、候选、协议效果或战斗暂停状态。
	_show_hack_protocol_view(true)


func _on_hack_protocol_view_closed() -> void:
	## 关闭骇入协议查看面板后恢复本局已经启用的模式扩展入口。
	_sync_risk_contract_view_visibility()
	if _hack_protocol_view_button != null and _hack_protocol_view_button.visible:
		_hack_protocol_view_button.grab_focus()


func _on_test_settings_button_pressed() -> void:
	_show_test_settings(true)


func _on_unstuck_button_pressed() -> void:
	if _game_world == null or not _game_world.has_method("teleport_player_to_nearest_clear_position"):
		return
	# 是否成功脱离；成功后直接关闭暂停菜单并恢复游戏，失败时保留菜单供玩家再次操作。
	var unstuck_succeeded: bool = bool(_game_world.call("teleport_player_to_nearest_clear_position"))
	if unstuck_succeeded:
		_set_pause_menu_visible(false)


func _on_return_main_menu_button_pressed() -> void:
	# 娱乐模式离开；训练场与超频骇入没有物品得失结算，直接返回主菜单且不显示二次确认。
	# 离开确认补充：娱乐模式同样保留二次确认以防误触，但正文不展示正式模式的物品丢失概率。
	if _is_casual_mode:
		if _escape_confirmation_dialog != null:
			_escape_confirmation_dialog.present_adaptive("确认离开", "确认离开并返回主菜单吗？", "确认离开", "取消", true)
		return
	if _escape_confirmation_dialog == null:
		return
	# 当前逃跑损失比例；进入游戏 30 秒内为 20%，超过该时长后恢复默认 50%。
	# 现行规则补充：该变量只表示背包概率，30 秒内为 30%、超过后为 60%；装备栏概率由独立变量计算。
	var loss_ratio: float = _get_current_escape_loss_ratio()
	# 当前逃跑装备栏损失比例；与背包使用同一短时保护边界，但按独立概率展示和结算。
	var equipment_loss_ratio: float = _get_current_escape_equipment_loss_ratio()
	# 逃跑警告；根据当前存活时间显示本次实际概率，训练场已在入口处直接离开而不会打开二次确认。
	_escape_confirmation_dialog.present_adaptive("确认逃跑", "确认逃跑并返回主菜单吗？\n背包物品：约 %d%% 保留、约 %d%% 丢失。\n武器栏与装备栏：约 %d%% 保留、约 %d%% 丢失。" % [roundi((1.0 - loss_ratio) * 100.0), roundi(loss_ratio * 100.0), roundi((1.0 - equipment_loss_ratio) * 100.0), roundi(equipment_loss_ratio * 100.0)], "确认逃跑", "取消", true)


func _on_escape_confirmed() -> void:
	if _is_casual_mode:
		_return_to_main_menu()
		return
	_show_failure_settlement("逃跑", 1.0 - _get_current_escape_loss_ratio(), 1.0 - _get_current_escape_equipment_loss_ratio())


func _get_current_escape_loss_ratio() -> float:
	# 是否处于短时保护期；边界包含第 30 秒，超过后由失败结算默认规则丢失 50%。
	# 现行规则补充：超过保护期后背包改为 60% 丢失，原注释中的 50% 仅保留用于说明历史规则。
	var is_early_escape: bool = _get_survival_time_seconds() <= maxf(early_escape_duration_seconds, 0.0)
	return clampf(early_escape_loss_ratio, 0.0, 1.0) if is_early_escape else clampf(failure_backpack_loss_ratio, 0.0, 1.0)


func _get_current_escape_equipment_loss_ratio() -> float:
	# 是否处于短时保护期；与背包共用含第 30 秒的边界，避免同一次逃跑对两类物品采用不同阶段。
	var is_early_escape: bool = _get_survival_time_seconds() <= maxf(early_escape_duration_seconds, 0.0)
	return clampf(early_escape_equipment_loss_ratio, 0.0, 1.0) if is_early_escape else clampf(failure_equipment_loss_ratio, 0.0, 1.0)


func _on_death_return_main_menu_button_pressed() -> void:
	_return_to_main_menu()


func _on_pause_settings_back_button_pressed() -> void:
	if _is_pause_key_binding_page_visible():
		_show_pause_key_binding_page(false)
		return

	_show_pause_settings(false)


func _on_pause_key_binding_button_pressed() -> void:
	_show_pause_key_binding_page(true)


func _on_pause_key_binding_back_button_pressed() -> void:
	_show_pause_key_binding_page(false)


func _on_clear_monsters_button_pressed() -> void:
	_clear_training_monsters()


func _on_respawn_monsters_button_pressed() -> void:
	_respawn_training_monsters()


func _on_switch_character_button_pressed() -> void:
	_show_character_switch(true)


func _on_add_game_time_button_pressed() -> void:
	if _game_world == null or not _game_world.has_method("add_training_survival_time"):
		return
	_game_world.call("add_training_survival_time")
	_last_survival_time_whole_seconds = -1
	_refresh_combat_status()


func _on_switch_character_stelle_button_pressed() -> void:
	_switch_training_character(CHARACTER_STELLE)


func _on_switch_character_caelus_button_pressed() -> void:
	_switch_training_character(CHARACTER_CAEULUS)


func _on_switch_character_silver_wolf_button_pressed() -> void:
	_switch_training_character(CHARACTER_SILVER_WOLF)


func _build_dynamic_training_character_buttons() -> void:
	# 会话状态；内置三个按钮已有固定信号，仅为自动发现的额外角色创建新按钮。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null or not session_state.has_method("get_character_ids"):
		return
	# 内置按钮表；资源中的显示名称也会同步覆盖场景默认文字，保证角色档案是唯一名称来源。
	var built_in_buttons: Dictionary = {
		CHARACTER_STELLE: _switch_character_stelle_button,
		CHARACTER_CAEULUS: _switch_character_caelus_button,
		CHARACTER_SILVER_WOLF: _switch_character_silver_wolf_button,
	}
	for character_id in session_state.call("get_character_ids") as Array[String]:
		# 角色档案；显示名来自自动资源，按钮点击后复用训练场统一切换接口。
		var profile: Dictionary = session_state.call("get_character_profile", character_id) as Dictionary
		var built_in_button: Button = built_in_buttons.get(character_id) as Button
		if built_in_button != null:
			built_in_button.text = str(profile.get("display_name", character_id))
			continue
		var character_button: Button = Button.new()
		character_button.custom_minimum_size = Vector2(0.0, 42.0)
		character_button.text = str(profile.get("display_name", character_id))
		character_button.pressed.connect(_switch_training_character.bind(character_id))
		_training_character_button_container.add_child(character_button)


func _setup_training_character_button_scroll() -> void:
	_character_switch_bottom_spacer.visible = false
	# 角色滚动区；占用标题与返回区之间的剩余高度，新增角色不会扩大或溢出暂停面板。
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_character_switch_content.add_child(scroll_container)
	_character_switch_content.move_child(scroll_container, _switch_character_stelle_button.get_index())
	# 按钮容器；横向填满滚动区并复用原列表 12 像素间距。
	_training_character_button_container = VBoxContainer.new()
	_training_character_button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_training_character_button_container.add_theme_constant_override("separation", 12)
	scroll_container.add_child(_training_character_button_container)
	# 内置按钮；重新挂载后缓存和既有点击信号保持有效。
	_character_switch_content.remove_child(_switch_character_stelle_button)
	_training_character_button_container.add_child(_switch_character_stelle_button)
	_character_switch_content.remove_child(_switch_character_caelus_button)
	_training_character_button_container.add_child(_switch_character_caelus_button)
	_character_switch_content.remove_child(_switch_character_silver_wolf_button)
	_training_character_button_container.add_child(_switch_character_silver_wolf_button)


func _on_character_switch_back_button_pressed() -> void:
	_show_character_switch(false)


func _on_infinite_energy_toggled(enabled: bool) -> void:
	_set_infinite_energy_enabled(enabled)


func _on_infinite_health_toggled(enabled: bool) -> void:
	_set_infinite_health_enabled(enabled)


func _on_active_skill_no_cooldown_toggled(enabled: bool) -> void:
	_set_active_skill_no_cooldown_enabled(enabled)


func _on_test_settings_back_button_pressed() -> void:
	_show_test_settings(false)


func _on_pause_master_volume_slider_value_changed(value: float) -> void:
	_apply_pause_master_volume(value)


func _set_death_overlay_visible(visible: bool) -> void:
	_death_overlay.visible = visible
	if visible:
		_inventory_panel.visible = false
		_large_map_overlay.visible = false
		if _character_showcase_view != null:
			_character_showcase_view.visible = false
		if _supply_extraction_overlay != null:
			_supply_extraction_overlay.visible = false
		_pause_overlay.visible = false
		_pause_menu_panel.visible = false
		_pause_settings_panel.visible = false
		_show_pause_key_binding_page(false)
		_test_settings_panel.visible = false
		_character_switch_panel.visible = false
		_set_battle_tree_paused(true)
		_refresh_combat_input_state()
		_death_return_main_menu_button.grab_focus()
	else:
		_refresh_combat_input_state()


func _set_battle_tree_paused(should_pause: bool) -> void:
	## 统一写入场景树暂停状态；联机战斗中任何界面都不暂停世界，队友与主机敌人持续运行，战斗输入仍由各界面既有逻辑关闭。
	get_tree().paused = should_pause and not _is_network_combat_active()


func _is_network_combat_active() -> bool:
	## 返回当前是否处于联机战斗；由联机会话服务提供，服务缺失或未联机时视为单机并保持原暂停行为。
	# 联机会话服务节点；自动加载常驻，独立场景运行 HUD 时可能不存在。
	var network_session: Node = get_tree().root.get_node_or_null("NetworkSession")
	return network_session != null and network_session.has_method("is_combat_session_active") and bool(network_session.call("is_combat_session_active"))


func _return_to_main_menu() -> void:
	get_tree().paused = false
	# 全局转场服务；战斗结算确认后使用统一 0.3 秒黑屏过渡返回主菜单。返回主菜单必须无条件解除暂停，因此不经过联机暂停守卫。
	var scene_transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_to_file"):
		scene_transition.call("change_scene_to_file", main_menu_scene_path)
	else:
		get_tree().change_scene_to_file(main_menu_scene_path)


func _show_success_settlement() -> void:
	if _run_outcome_resolved:
		return
	# 娱乐模式撤离；训练场与超频骇入不产出结算，进入撤离点确认后直接返回主菜单，不展示结算窗口。
	if _is_casual_mode:
		_run_outcome_resolved = true
		_return_to_main_menu()
		return
	_run_outcome_resolved = true
	# 全局背包服务；正式撤离时保存全部物品、标记上次撤离优先级并返回本局新增物品列表。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	# 成功结算；缺少全局服务时使用空收益兜底，仍展示撤离成功界面。
	var outcome: Dictionary = {"result": "success", "title": "撤离成功", "gained_entries": [], "lost_entries": [], "gained_items": [], "lost_items": []}
	_record_stock_survival_time()
	_record_stock_extracted_values(global_inventory)
	# 生涯统计结算上报；必须在库存完成正式结算前调用，保证随身价值摘要仍然可读。
	_record_stats_run_finished("success")
	# 玩家被动技能组件；成功撤离完成库存结算前读取地图掉落物并发放一次角色专属奖励。
	var passive_skill_component: Node = _player.get_node_or_null("PassiveSkillComponent") if _player != null else null
	if passive_skill_component != null and passive_skill_component.has_method("apply_successful_extraction_bonuses"):
		passive_skill_component.call("apply_successful_extraction_bonuses", global_inventory, _game_world)
	if global_inventory != null and global_inventory.has_method("complete_combat_run_success"):
		outcome = global_inventory.call("complete_combat_run_success")
	_present_run_outcome(outcome)
	_show_newcomer_protection_end_notice_if_needed()


func _show_failure_settlement(reason: String, retained_ratio: float = -1.0, equipment_retained_ratio: float = -1.0) -> void:
	if _run_outcome_resolved:
		_set_death_overlay_visible(true)
		return

	# 全局背包服务；正式战斗失败时按死亡或主动逃跑的当前规则随机结算背包物品。
	var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
	if global_inventory == null or not global_inventory.has_method("is_combat_run_active") or not bool(global_inventory.call("is_combat_run_active")):
		_run_outcome_resolved = true
		_present_run_outcome({"result": "failure", "title": reason, "gained_entries": [], "lost_entries": [], "gained_items": [], "lost_items": []})
		return

	_run_outcome_resolved = true
	# 失败结算；主动逃跑可传入短时保护保留率，死亡等默认路径继续使用全局库存的 50% 规则。
	# 现行规则补充：死亡与主动逃跑都传入背包、装备栏两类保留率，默认分别为 40% 与 80%。
	_record_stock_survival_time()
	# 生涯统计结算上报；按结算原因区分死亡与主动逃跑，两类都计入对局总数分母。
	_record_stats_run_finished("death" if reason == "角色死亡" else "escape")
	# 失败结算结果；两个保留率都有效时使用完整规则，缺省调用保留全局库存的默认失败概率作为兼容兜底。
	var outcome: Dictionary = global_inventory.call("complete_combat_run_failure", reason, retained_ratio, equipment_retained_ratio) if retained_ratio >= 0.0 and equipment_retained_ratio >= 0.0 else global_inventory.call("complete_combat_run_failure", reason)
	_present_run_outcome(outcome)


func _record_stock_survival_time() -> void:
	# 股市统计服务；在库存结束正式对局前记录存活时间，避免 run_active 关闭后统计请求被忽略。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_method("record_run_metric"):
		stock_market_service.call("record_run_metric", "survival_seconds", _get_survival_time_seconds())


func _record_stats_run_finished(result_id: String) -> void:
	## 把一局正式战斗的结果写入生涯统计；娱乐模式的结算入口已提前返回主菜单，不会走到这里。
	## 必须在库存执行正式结算之前调用，保证成功撤离时随身价值摘要与本局送回累计仍然可读。
	# 生涯统计服务；缺失时结算流程照常执行，仅丢失统计。
	var stats_service: Node = get_tree().root.get_node_or_null("StatsService")
	if stats_service == null or not stats_service.has_method("record_run_finished"):
		return
	# 本局带出价值；成功撤离按“随身总价值 + 本局送回价值”计算完整收获，失败结算记 0。
	var extracted_value: int = 0
	if result_id == "success":
		# 全局库存服务；提供随身价值摘要与本局已送回价值两个只读查询。
		var global_inventory: Node = get_tree().root.get_node_or_null("GlobalInventory")
		if global_inventory != null and global_inventory.has_method("get_combat_carried_value_summary"):
			extracted_value = int((global_inventory.call("get_combat_carried_value_summary") as Dictionary).get("total_value", 0))
		if global_inventory != null and global_inventory.has_method("get_combat_shipped_value"):
			extracted_value += int(global_inventory.call("get_combat_shipped_value"))
	stats_service.call("record_run_finished", result_id, _get_survival_time_seconds(), extracted_value)


func _record_stock_extracted_values(global_inventory: Node) -> void:
	if global_inventory == null or not global_inventory.has_method("get_combat_carried_value_summary"):
		return
	# 随身价值摘要；成功撤离完成所有权结算前读取，覆盖开局携带与本局获得的全部物品。
	var value_summary: Dictionary = global_inventory.call("get_combat_carried_value_summary") as Dictionary
	# 矿场服务；成功撤离价值按每 10 星穹增加 0.01% 产出并追加 30 分钟在线持续时间。
	var mining_farm_service: Node = get_tree().root.get_node_or_null("MiningFarmService")
	if mining_farm_service != null and mining_farm_service.has_method("apply_successful_extraction_buff"):
		mining_farm_service.call("apply_successful_extraction_buff", int(value_summary.get("total_value", 0)))
	# 股市统计服务；只在成功撤离路径调用，因此不会把失败前随身价值误记为带出价值。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_method("record_run_metric"):
		stock_market_service.call("record_run_metric", "extracted_value", int(value_summary.get("total_value", 0)))
		stock_market_service.call("record_run_metric", "extracted_weapon_value", int(value_summary.get("weapon_value", 0)))


func _present_run_outcome(outcome: Dictionary) -> void:
	# 结算结果类型；success 表示撤离成功，其他值统一按失败展示。
	var result_type: String = str(outcome.get("result", "failure"))
	_settlement_outcome = outcome.duplicate()
	_settlement_primary_category = InventoryQuery.PRIMARY_ALL
	_settlement_subcategory = InventoryQuery.SUBCATEGORY_ALL
	# 结算窗口标题；统一只显示“结算”，具体获得与损失结果继续由下方物品分区呈现。
	_death_title_label.text = "结算"
	_rebuild_settlement_list()
	_death_return_main_menu_button.text = "确定"
	if result_type == "success":
		_death_title_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72, 1.0))
	else:
		_death_title_label.add_theme_color_override("font_color", Color(1.0, 0.46, 0.52, 1.0))
	_set_death_overlay_visible(true)


func _show_newcomer_protection_end_notice_if_needed() -> void:
	## 在首次成功撤离结算遮罩就绪后展示结束提示；保护期内不创建任何 HUD 文案或战斗内提示。
	if _newcomer_protection_ended_dialog == null:
		return
	# 新手保护服务；负责保证该通知只被当前首次撤离结算消费一次。
	var newcomer_protection_service: Node = get_tree().root.get_node_or_null("NewcomerProtectionService")
	if newcomer_protection_service == null or not newcomer_protection_service.has_method("consume_completion_notice"):
		return
	if not bool(newcomer_protection_service.call("consume_completion_notice")):
		return
	_newcomer_protection_ended_dialog.present_information("提示", "首次成功撤离，新手保护结束！")


func _rebuild_settlement_list() -> void:
	_clear_container(_death_settlement_list)
	# 结算结果类型；用于决定是否创建失败时的实际丢失物品分区。
	var result_type: String = str(_settlement_outcome.get("result", "failure"))
	_build_settlement_category_controls()

	# 本局获得条目；优先读取包含 Resource 的结构化列表，鼠标悬停时可显示完整物品属性。
	var gained_entries: Array = _settlement_outcome.get("gained_entries", [])
	# 分类后获得条目；复用背包查询器，保证武器、资源、近战、远程与强化石判定完全一致。
	var filtered_gained_entries: Array[Dictionary] = InventoryQuery.filter_and_sort_entries(
		gained_entries,
		_settlement_primary_category,
		_settlement_subcategory,
		"",
		"",
		InventoryQuery.SORT_ACQUIRED_TIME
	)
	# 实际丢失条目；失败结算展示按本次概率从背包移除的全部物品，成功结算保持空数组。
	# 现行规则补充：数组同时包含从武器栏与防具装备栏实际移除的物品。
	var lost_entries: Array = _settlement_outcome.get("lost_entries", [])
	_build_settlement_section("本局获得", filtered_gained_entries, "当前分类没有获得物品", Color(0.35, 1.0, 0.72, 1.0))
	if result_type != "success":
		_build_settlement_section("丢失物品", lost_entries, "本次没有丢失物品", Color(1.0, 0.46, 0.52, 1.0))


func _build_settlement_category_controls() -> void:
	# 主分类栏；结构与战斗背包一致，全部入口聚合展示武器和资源。
	var primary_bar: HBoxContainer = HBoxContainer.new()
	primary_bar.add_theme_constant_override("separation", 6)
	_death_settlement_list.add_child(primary_bar)
	# 全部主分类按钮；按下后同时展示本局武器和资源条目。
	var all_button: Button = Button.new()
	all_button.text = "全部"
	all_button.toggle_mode = true
	all_button.button_pressed = _settlement_primary_category == InventoryQuery.PRIMARY_ALL
	all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_button.pressed.connect(Callable(self, "_on_settlement_primary_category_pressed").bind(InventoryQuery.PRIMARY_ALL))
	primary_bar.add_child(all_button)
	# 武器主分类按钮；按下后默认回到武器全部子分类。
	var weapons_button: Button = Button.new()
	weapons_button.text = "武器"
	weapons_button.toggle_mode = true
	weapons_button.button_pressed = _settlement_primary_category == InventoryQuery.PRIMARY_WEAPONS
	weapons_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_button.pressed.connect(Callable(self, "_on_settlement_primary_category_pressed").bind(InventoryQuery.PRIMARY_WEAPONS))
	primary_bar.add_child(weapons_button)
	# 资源主分类按钮；按下后默认回到资源全部子分类。
	var resources_button: Button = Button.new()
	resources_button.text = "资源"
	resources_button.toggle_mode = true
	resources_button.button_pressed = _settlement_primary_category == InventoryQuery.PRIMARY_RESOURCES
	resources_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources_button.pressed.connect(Callable(self, "_on_settlement_primary_category_pressed").bind(InventoryQuery.PRIMARY_RESOURCES))
	primary_bar.add_child(resources_button)

	# 子分类栏；根据当前主分类生成全部、近战、远程或强化石按钮。
	var subcategory_bar: HBoxContainer = HBoxContainer.new()
	subcategory_bar.add_theme_constant_override("separation", 6)
	_death_settlement_list.add_child(subcategory_bar)
	_add_settlement_subcategory_button(subcategory_bar, "全部", InventoryQuery.SUBCATEGORY_ALL)
	if _settlement_primary_category == InventoryQuery.PRIMARY_WEAPONS:
		_add_settlement_subcategory_button(subcategory_bar, "近战", InventoryQuery.SUBCATEGORY_MELEE)
		_add_settlement_subcategory_button(subcategory_bar, "远程", InventoryQuery.SUBCATEGORY_RANGED)
	elif _settlement_primary_category == InventoryQuery.PRIMARY_RESOURCES:
		_add_settlement_subcategory_button(subcategory_bar, "强化石", InventoryQuery.SUBCATEGORY_ENHANCEMENT_STONES)


func _add_settlement_subcategory_button(parent_bar: HBoxContainer, button_text: String, subcategory: String) -> void:
	# 子分类按钮；使用绑定参数切换查询条件，重建后按钮选中状态由当前分类字段恢复。
	var category_button: Button = Button.new()
	category_button.text = button_text
	category_button.toggle_mode = true
	category_button.button_pressed = _settlement_subcategory == subcategory
	category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_button.pressed.connect(Callable(self, "_on_settlement_subcategory_pressed").bind(subcategory))
	parent_bar.add_child(category_button)


func _on_settlement_primary_category_pressed(primary_category: String) -> void:
	_settlement_primary_category = primary_category
	_settlement_subcategory = InventoryQuery.SUBCATEGORY_ALL
	_rebuild_settlement_list()


func _on_settlement_subcategory_pressed(subcategory: String) -> void:
	_settlement_subcategory = subcategory
	_rebuild_settlement_list()


func _build_settlement_section(section_name: String, entries: Array, empty_text: String, accent_color: Color) -> void:
	# 分区总价值；按每个条目的当前有效价值乘实际数量累计，与物品悬停详情和仓库保持一致。
	var total_value: int = _calculate_settlement_entries_total_value(entries)
	# 分区标题；显示分类名称、条目数量和总价值，颜色区分战利品与丢失物品。
	var section_title: Label = Label.new()
	section_title.text = "%s（%d） 总价值：%d" % [section_name, entries.size(), total_value]
	section_title.add_theme_font_size_override("font_size", 18)
	section_title.add_theme_color_override("font_color", accent_color)
	_death_settlement_list.add_child(section_title)
	if entries.is_empty():
		# 空列表提示；用于明确本次结算没有对应类型物品，而不是 UI 加载失败。
		var empty_label: Label = Label.new()
		empty_label.text = empty_text
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0.0, 42.0)
		_death_settlement_list.add_child(empty_label)
		return

	# 居中容器；网格按内容宽度收缩后整体居中，避免行尾空位被拉伸成视觉留白。
	var grid_center: CenterContainer = CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_death_settlement_list.add_child(grid_center)
	# 仓库式四列网格；每行固定显示四个标准卡片，结算条目只读且支持鼠标悬停详情。
	var item_grid: GridContainer = GridContainer.new()
	item_grid.columns = 4
	item_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 6)
	grid_center.add_child(item_grid)
	# 结算条目遍历项；每项应包含 resource 与 display_name，异常数据会回退为普通文本。
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		# 结构化结算条目；携带运行时 Resource 以复用仓库详情生成逻辑。
		var entry: Dictionary = raw_entry
		# 结算物品资源；有效时创建只读 StorageItemControl，缺失时显示名称兜底。
		var item_resource: Resource = entry.get("resource") as Resource
		if item_resource != null:
			# 结算数量；强化石堆叠在同一卡片显示 xN，武器保持数量 1。
			var quantity: int = clampi(int(entry.get("quantity", 1)), 1, INVENTORY_LIMITS.MAX_STACK_QUANTITY)
			var item_control: Button = STORAGE_ITEM_CONTROL_SCRIPT.new() as Button
			item_control.custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
			item_control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			item_control.call("configure", item_resource, "", -1, false, "", quantity)
			item_grid.add_child(item_control)
		else:
			var fallback_label: Label = Label.new()
			fallback_label.text = str(entry.get("display_name", "未知物品"))
			fallback_label.custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
			fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			item_grid.add_child(fallback_label)


func _calculate_settlement_entries_total_value(entries: Array) -> int:
	## 计算结算分区全部物品的整数总价值；无资源的兼容条目按 0 处理，避免猜测缺失价格。
	var total_value: int = 0
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		# 结构化结算条目；包含资源引用和实际数量，武器与装备通常为 1。
		var entry: Dictionary = raw_entry as Dictionary
		# 条目资源；缺失时无法读取有效价值，因此不会计入总价值。
		var item_resource: Resource = entry.get("resource") as Resource
		if item_resource == null:
			continue
		# 条目实际数量；堆叠资源按结算数量累计，异常数量至少按 1 处理。
		var quantity: int = maxi(int(entry.get("quantity", 1)), 1)
		# 单位有效价值；包含强化与耐久对武器、装备价值的实时影响。
		var unit_value: int = int(ITEM_DETAIL_FORMATTER_SCRIPT.call("get_item_value", item_resource))
		total_value += maxi(unit_value, 0) * quantity
	return maxi(total_value, 0)
