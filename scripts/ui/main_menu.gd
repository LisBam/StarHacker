extends Control

## 主菜单负责项目启动后的第一个可交互界面。
## 这里保留骇入、训练场、角色系统、设置和退出等清晰路径，避免把游戏流程逻辑写进具体按钮。
## 战斗入口直接使用 SessionState 当前角色；角色选择作为独立系统从底部“角色”按钮进入。

## 大厅面板宿主的聚合可见状态变化信号；大厅据此统一锁定或恢复玩家与实体交互。
signal modal_visibility_changed(visible: bool)

## 正式骇入模式标识；默认写入 SessionState，修改会影响骇入入口进入后的模式判定。
const GAME_MODE_HACK: String = "hack"
## 训练场模式标识；默认写入 SessionState，修改会影响训练场入口进入后的模式判定。
const GAME_MODE_TRAINING: String = "training"
## 按键绑定面板脚本；默认用于主菜单设置中动态创建可重绑定操作列表。
const KEY_BINDING_PANEL_SCRIPT: Script = preload("res://scripts/ui/key_binding_panel.gd")
## 存档传输控件脚本；默认用于主菜单设置中复用导出、导入文件选择和结果提示。
## 删除功能补充：同一复用控件内部提供输入“确认删除”的危险删除入口。
const SAVE_TRANSFER_CONTROL_SCRIPT: Script = preload("res://scripts/ui/save_transfer_control.gd")
## 全局窗口样式指南；统一主菜单、设置页和全部局外遮罩窗口的主题与语义按钮颜色。
const UI_STYLE_GUIDE: Script = preload("res://scripts/ui/ui_style_guide.gd")
## 金融解锁规则；统一提供保险、银行、矿场与炒股的成长顺序和累计获得星穹门槛。
const FINANCE_UNLOCK_RULES: Script = preload("res://scripts/data/finance_unlock_rules.gd")
## 可视进度拖动条组件；为主音量滑条绘制完整轨道、当前进度和实时滑块位置，不改变音量业务逻辑。
const PROGRESS_SLIDER_VISUAL_SCRIPT: Script = preload("res://scripts/ui/progress_slider_visual.gd")
## UI 风格选择组件；主菜单设置复用其选项构建、服务绑定、即时保存与全局刷新逻辑。
const UI_STYLE_SELECTOR_SCRIPT: Script = preload("res://scripts/ui/ui_style_selector.gd")
## 横幅通知开关组件；主菜单设置复用其开关构建、服务绑定与即时保存逻辑。
const BANNER_NOTIFICATION_TOGGLE_SCRIPT: Script = preload("res://scripts/ui/banner_notification_toggle.gd")
## 局外仓库面板脚本；默认在主菜单点击仓库按钮后动态创建并读取全局背包服务。
const WAREHOUSE_PANEL_SCRIPT: Script = preload("res://scripts/ui/warehouse_panel.gd")
## 主菜单背包面板脚本；复用游戏内背包装备结构，局外丢弃会直接永久移除物品。
const MAIN_MENU_BACKPACK_PANEL_SCRIPT: Script = preload("res://scripts/ui/main_menu_backpack_panel.gd")
## 局外商店面板脚本；默认在主菜单点击商店按钮后动态创建并读取全局商店服务。
const SHOP_PANEL_SCRIPT: Script = preload("res://scripts/ui/shop_panel.gd")
## 局外锻造面板脚本；默认在主菜单点击锻造按钮后动态创建并组合库存与锻造服务。
const FORGE_PANEL_SCRIPT: Script = preload("res://scripts/ui/forge_panel.gd")
## 股市面板脚本；默认在主菜单点击炒股按钮后动态创建并组合行情与持仓服务。
const STOCK_MARKET_PANEL_SCRIPT: Script = preload("res://scripts/ui/stock_market_panel.gd")
## 矿场面板脚本；默认在主菜单点击矿场按钮后动态创建并读取全局矿场服务。
const MINING_FARM_PANEL_SCRIPT: Script = preload("res://scripts/ui/mining_farm_panel.gd")
## 保险面板脚本；默认在主菜单点击保险按钮后动态创建并读取全局保险服务。
const INSURANCE_PANEL_SCRIPT: Script = preload("res://scripts/ui/insurance_panel.gd")
## 银行面板脚本；默认在主菜单点击银行按钮后动态创建并读取全局银行服务。
const BANK_PANEL_SCRIPT: Script = preload("res://scripts/ui/bank_panel.gd")
## 据点面板脚本；默认在主菜单点击据点按钮后动态创建并读取全局据点服务。
const HIDEOUT_PANEL_SCRIPT: Script = preload("res://scripts/ui/hideout_panel.gd")
## 派遣面板脚本；默认在主菜单点击派遣按钮后动态创建并读取全局派遣服务。
const DISPATCH_PANEL_SCRIPT: Script = preload("res://scripts/ui/dispatch_panel.gd")
## 图鉴面板脚本；默认在主菜单点击图鉴按钮后动态创建，并从内容目录和永久库存读取展示与解锁状态。
const ENCYCLOPEDIA_PANEL_SCRIPT: Script = preload("res://scripts/ui/encyclopedia_panel.gd")
## 悬赏面板脚本；默认在主菜单点击右侧“悬赏”按钮后动态创建并读取全局悬赏服务。
const BOUNTY_PANEL_SCRIPT: Script = preload("res://scripts/ui/bounty_panel.gd")
## 统计面板脚本；默认在主菜单点击右侧“统计”按钮后动态创建并读取全局生涯统计服务。
const STATS_PANEL_SCRIPT: Script = preload("res://scripts/ui/stats_panel.gd")
## 骇入模式选择面板脚本；点击“骇入”后先打开该面板选择标准、零装或超频模式再进入战斗。
const HACK_MODE_SELECT_PANEL_SCRIPT: Script = preload("res://scripts/ui/hack_mode_select_panel.gd")
## 模式扩展选择面板脚本；骇入模式确定后继续配置可多选扩展与风险合约词条，再进入正式战斗。
const MODE_EXTENSION_SELECT_PANEL_SCRIPT: Script = preload("res://scripts/ui/mode_extension_select_panel.gd")
## 联机组队面板脚本；默认在主菜单点击联机组队按钮后动态创建，调用 NetworkSession 完成建房、发现、加入与统一开局。
const MULTIPLAYER_PANEL_SCRIPT: Script = preload("res://scripts/ui/multiplayer_lobby_panel.gd")
## 隐藏开发者菜单脚本；默认只在主菜单依次输入 LISBAM 后显示。
const DEVELOPER_MENU_SCRIPT: Script = preload("res://scripts/ui/developer_menu.gd")
## 开发者模式解锁序列；默认由六个英文字母组成，输入错误会按首字母重新匹配。
const DEVELOPER_UNLOCK_SEQUENCE: String = "LISBAM"
## 底部分类展开面板与所属按钮的垂直间距；默认 10 像素，保证展开面板从按钮上方升起时保留清晰边界。
const CATEGORY_EXPANSION_GAP: float = 10.0
## 底部分类展开动画时长；默认 0.18 秒，使用从下向上的缩放让纵向入口列表快速且清晰地出现。
const CATEGORY_EXPANSION_ANIMATION_DURATION: float = 0.18
## 大厅正式骇入动作标识；固定 hack，由实体交互协议映射到现有骇入入口。
const LOBBY_ACTION_HACK: String = "hack"
## 大厅训练场动作标识；固定 training，由实体交互协议映射到现有训练场入口。
const LOBBY_ACTION_TRAINING: String = "training"
## 大厅角色动作标识；固定 character，进入独立角色系统并把返回目标设置为当前大厅。
const LOBBY_ACTION_CHARACTER: String = "character"
## 大厅背包动作标识；固定 backpack，复用主菜单局外背包面板。
const LOBBY_ACTION_BACKPACK: String = "backpack"
## 大厅仓库动作标识；固定 warehouse，复用主菜单仓库面板。
const LOBBY_ACTION_WAREHOUSE: String = "warehouse"
## 大厅商店动作标识；固定 shop，复用主菜单商店面板。
const LOBBY_ACTION_SHOP: String = "shop"
## 大厅锻造动作标识；固定 forge，复用主菜单锻造面板。
const LOBBY_ACTION_FORGE: String = "forge"
## 大厅股市动作标识；固定 stock_market，复用主菜单股市面板。
const LOBBY_ACTION_STOCK_MARKET: String = "stock_market"
## 大厅矿场动作标识；固定 mining_farm，复用主菜单矿场面板。
const LOBBY_ACTION_MINING_FARM: String = "mining_farm"
## 大厅保险动作标识；固定 insurance，复用主菜单保险面板。
const LOBBY_ACTION_INSURANCE: String = "insurance"
## 大厅银行动作标识；固定 bank，复用主菜单银行面板。
const LOBBY_ACTION_BANK: String = "bank"
## 大厅据点动作标识；固定 hideout，复用主菜单据点面板。
const LOBBY_ACTION_HIDEOUT: String = "hideout"
## 大厅派遣动作标识；固定 dispatch，复用主菜单派遣面板。
const LOBBY_ACTION_DISPATCH: String = "dispatch"
## 大厅图鉴动作标识；固定 encyclopedia，复用主菜单图鉴面板。
const LOBBY_ACTION_ENCYCLOPEDIA: String = "encyclopedia"
## 大厅悬赏动作标识；固定 bounty，复用主菜单悬赏面板，当前大厅尚未放置对应实体。
const LOBBY_ACTION_BOUNTY: String = "bounty"
## 首次成功撤离成长入口锁定提示；锻造、据点、派遣与悬赏在完成首局正式成功撤离前统一显示该文案。
const FIRST_SUCCESSFUL_EXTRACTION_UNLOCK_TOOLTIP: String = "首次成功撤离后解锁"
## 首次成功撤离模式解锁补充：娱乐模式与模式扩展同样复用该永久资格，避免新手在首撤前接触高级规则。
## 大厅统计动作标识；固定 stats，复用主菜单统计面板，当前大厅尚未放置对应实体。
const LOBBY_ACTION_STATS: String = "stats"
## 大厅联机组队动作标识；固定 multiplayer，复用主菜单联机组队面板。
const LOBBY_ACTION_MULTIPLAYER: String = "multiplayer"
## 大厅设置动作标识；固定 settings，复用主菜单设置面板。
const LOBBY_ACTION_SETTINGS: String = "settings"
## 大厅退出动作标识；固定 quit，执行与主菜单退出按钮相同的关闭程序命令。
const LOBBY_ACTION_QUIT: String = "quit"
## 角色系统场景路径；默认由主菜单底部“角色”按钮进入，只允许填写 tscn 资源，运行时通常不动态修改。
@export_file("*.tscn") var character_select_scene_path: String = "res://scenes/ui/character_select.tscn"
## 游戏场景路径；骇入和训练场入口写入模式后直接进入该场景，当前角色由 SessionState 提供。
@export_file("*.tscn") var game_scene_path: String = "res://scenes/game/game_world.tscn"
## 主大厅场景路径；默认由左上角“切换大厅/菜单”按钮进入，只允许填写 tscn 资源。
@export_file("*.tscn") var lobby_scene_path: String = "res://scenes/game/main_lobby.tscn"
## 联机大厅场景路径；完整主菜单点击“联机”后进入该场景，进场后由大厅自动打开联机面板。
@export_file("*.tscn") var multiplayer_lobby_scene_path: String = "res://scenes/game/multiplayer_lobby.tscn"
## 大厅面板宿主模式；默认 false 显示完整主菜单，设为 true 时隐藏菜单本体并只保留可由实体打开的复用面板。
@export var lobby_host_mode: bool = false

## 骇入按钮缓存；默认绑定唯一名 StartButton，必须是 Button，修改节点名会导致正式入口无法进入战斗。
@onready var _start_button: Button = %StartButton
## 训练场按钮缓存；默认绑定唯一名 TrainingButton，必须是 Button，修改节点名会导致训练场入口无法进入战斗。
@onready var _training_button: Button = %TrainingButton
## 联机组队按钮缓存；默认绑定唯一名 MultiplayerButton，必须是 Button，点击后打开局域网组队面板。
@onready var _multiplayer_button: Button = %MultiplayerButton
## 设置按钮缓存；默认绑定唯一名 SettingsButton，必须是 Button，修改节点名会导致主菜单无法打开设置。
@onready var _settings_button: Button = %SettingsButton
## 退出按钮缓存；默认绑定唯一名 QuitButton，必须是 Button，修改节点名会导致主菜单无法退出程序。
@onready var _quit_button: Button = %QuitButton
## 仓库按钮缓存；默认位于主菜单底部功能栏第三位，点击后打开全局背包与装备调整界面。
@onready var _warehouse_button: Button = %WarehouseButton
## 角色按钮缓存；默认位于主菜单底部功能栏首位，点击后进入独立角色系统。
@onready var _character_button: Button = %CharacterButton
## 背包按钮缓存；默认位于角色按钮右侧，点击后打开游戏内同款装备栏与随身物品界面。
@onready var _backpack_button: Button = %BackpackButton
## 商店按钮缓存；默认位于仓库按钮右侧，点击后打开普通商店与灰市界面。
@onready var _shop_button: Button = %ShopButton
## 锻造按钮缓存；默认位于商店按钮右侧，点击后打开主武器修复与强化界面。
@onready var _forge_button: Button = %ForgeButton
## 炒股按钮缓存；默认位于锻造按钮右侧，点击后打开永久资产股市界面。
@onready var _stock_market_button: Button = %StockMarketButton
## 矿场按钮缓存；默认位于炒股按钮右侧，点击后打开常驻算力资产经营界面。
@onready var _mining_farm_button: Button = %MiningFarmButton
## 保险按钮缓存；默认位于矿场按钮右侧，点击后打开骇入保险投保与理赔界面。
@onready var _insurance_button: Button = %InsuranceButton
## 银行按钮缓存；默认位于保险按钮右侧，点击后打开活期、定期与贷款界面。
@onready var _bank_button: Button = %BankButton
## 据点按钮缓存；默认位于银行按钮右侧，点击后打开据点设施建设界面。
@onready var _hideout_button: Button = %HideoutButton
## 派遣按钮缓存；默认位于据点按钮右侧，点击后打开佣兵派遣委托界面。
@onready var _dispatch_button: Button = %DispatchButton
## 金融分类按钮缓存；默认位于主菜单底部，点击后展开或收起炒股、矿场、保险和银行入口。
@onready var _finance_category_button: Button = %FinanceCategoryButton
## 统计分类按钮缓存；默认位于主菜单底部，点击后展开或收起图鉴与生涯入口。
@onready var _statistics_category_button: Button = %StatisticsCategoryButton
## 图鉴按钮缓存；默认位于“统计”展开分类中，点击后查看武器、装备与资源的永久收集状态。
## 怪物图鉴补充；同一入口还会展示按基础内容和扩展包分组的永久怪物遇敌收集状态。
@onready var _encyclopedia_button: Button = %EncyclopediaButton
## 悬赏按钮缓存；默认位于主菜单底部功能栏，点击后打开每日随机悬赏面板。
@onready var _bounty_button: Button = %BountyButton
## 生涯按钮缓存；默认位于“统计”展开分类中，点击后打开生涯统计与财富曲线面板。
@onready var _stats_button: Button = %StatsButton
## 设置面板缓存；默认绑定唯一名 SettingsPanel，控制主菜单设置界面的显示和隐藏。
@onready var _settings_panel: Control = %SettingsPanel
## 设置内容容器缓存；默认通过场景路径绑定，用于动态挂载按键绑定面板。
@onready var _settings_content: VBoxContainer = get_node("SettingsPanel/SettingsMargin/SettingsContent") as VBoxContainer
## 设置首页标题缓存；默认按节点路径绑定 SettingsTitle，用于多页设置中切换首页显示。
@onready var _settings_title_label: Label = get_node("SettingsPanel/SettingsMargin/SettingsContent/SettingsTitle") as Label
## 主音量滑条缓存；默认绑定唯一名 MasterVolumeSlider，取值 0 到 100，修改会影响全局 Master 音量。
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
## 主音量行容器缓存；默认绑定主音量标签、滑条和数值，用于多页设置中切换首页显示。
@onready var _master_volume_row: HBoxContainer = get_node("SettingsPanel/SettingsMargin/SettingsContent/MasterVolumeRow") as HBoxContainer
## 主音量数值文本缓存；默认绑定唯一名 MasterVolumeValueLabel，显示滑条当前百分比。
@onready var _master_volume_value_label: Label = %MasterVolumeValueLabel
## 设置页弹性留白缓存；默认按节点路径绑定 SettingsSpacer，用于保持首页按钮位置稳定。
@onready var _settings_spacer: Control = get_node("SettingsPanel/SettingsMargin/SettingsContent/SettingsSpacer") as Control
## 设置返回按钮缓存；默认绑定唯一名 SettingsBackButton，点击后关闭设置面板。
@onready var _settings_back_button: Button = %SettingsBackButton
## 菜单与大厅切换按钮缓存；默认位于主菜单左上角，大厅宿主模式下隐藏并由 LobbyHud 提供同名按钮。
@onready var _switch_lobby_menu_button: Button = %SwitchLobbyMenuButton
## 主菜单背景缓存；大厅宿主模式下隐藏，避免覆盖大厅世界画面。
@onready var _background: ColorRect = get_node("Background") as ColorRect
## 主菜单中央入口容器缓存；大厅宿主模式下隐藏，所有入口改由世界实体触发。
@onready var _center_menu: Control = get_node("Center") as Control
## 主菜单底部功能栏缓存；大厅宿主模式下隐藏，局外面板继续由同一脚本动态创建。
@onready var _bottom_menu_margin: Control = get_node("BottomMenuMargin") as Control
## 主菜单底部分类展开层缓存；仅在金融或统计分类展开时显示，面板位置由所属按钮在运行时计算。
@onready var _bottom_category_expansion_margin: Control = get_node("BottomCategoryExpansionMargin") as Control
## 金融分类展开面板缓存；内部承载炒股、矿场、保险和银行四个既有入口。
@onready var _finance_category_panel: PanelContainer = get_node("BottomCategoryExpansionMargin/FinanceCategoryPanel") as PanelContainer
## 统计分类展开面板缓存；内部承载图鉴与生涯两个既有入口。
@onready var _statistics_category_panel: PanelContainer = get_node("BottomCategoryExpansionMargin/StatisticsCategoryPanel") as PanelContainer

## Master 音频总线索引；取值为 -1 或有效总线下标，默认 -1 表示尚未解析，修改会影响音量应用目标。
var _master_bus_index: int = -1
## 主菜单按键绑定面板缓存；默认运行时创建，显示并修改 InputMap 的玩家操作绑定。
var _key_binding_panel: Control
## 按键绑定入口按钮缓存；默认运行时插入设置首页，点击后切换到按键绑定页面。
var _key_binding_button: Button
## 按键绑定页面容器缓存；默认运行时创建并隐藏，显示时替代设置首页内容。
var _key_binding_page: VBoxContainer
## 按键绑定页面返回按钮缓存；默认运行时创建，点击后回到设置首页而不是关闭设置面板。
var _key_binding_back_button: Button
## 设置首页控件列表；元素为 Control，默认用于在多页设置之间统一隐藏或显示首页内容。
var _settings_home_controls: Array[Control] = []
## 主菜单 UI 风格选择组件；默认运行时插入主音量下方并即时同步全局风格设置。
var _ui_style_selector: Control
## 主菜单横幅通知开关组件；默认运行时插入 UI 风格行下方并即时保存全局横幅设置。
var _banner_notification_toggle: Control
## 全局库存服务缓存；读取只增不减的累计获得星穹并监听变化，不直接修改金融资产。
var _global_inventory: Node
## 新手成长服务缓存；只读取首次成功撤离永久资格并监听完成信号，不参与战斗结算或功能业务。
var _newcomer_protection_service: Node
## 主菜单存档传输控件；默认运行时插入设置首页，导入成功后由全局服务重启游戏。
## 删除功能补充：删除成功后同样由全局服务重启，并在其他业务服务读档前清理活动存档。
var _save_transfer_control: Control
## 仓库全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他按钮接收鼠标输入。
var _warehouse_overlay: Control
## 仓库面板实例；默认由 WarehousePanel 脚本创建，关闭后复用而不重复构建服务数据。
var _warehouse_panel: Control
## 背包全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他按钮接收输入。
var _backpack_overlay: Control
## 主菜单背包面板实例；关闭后复用并通过全局库存信号实时刷新。
var _backpack_panel: Control
## 商店全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他按钮接收鼠标输入。
var _shop_overlay: Control
## 商店面板实例；默认由 ShopPanel 脚本创建，关闭后复用并保留当前查询条件。
var _shop_panel: Control
## 锻造全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他按钮接收鼠标输入。
var _forge_overlay: Control
## 锻造面板实例；默认由 ForgePanel 脚本创建，关闭后复用并保留未执行的槽位引用。
var _forge_panel: Control
## 股市全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他入口接收输入。
var _stock_market_overlay: Control
## 股市面板实例；默认由 StockMarketPanel 创建，关闭后复用并由服务信号实时刷新。
var _stock_market_panel: Control
## 矿场全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他入口接收输入。
var _mining_farm_overlay: Control
## 矿场面板实例；关闭后复用，后台收益由独立 Autoload 服务继续低频结算。
var _mining_farm_panel: Control
## 保险全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他入口接收输入。
var _insurance_overlay: Control
## 保险面板实例；关闭后复用，保单结算由独立 Autoload 服务在战斗结束时自动执行。
var _insurance_panel: Control
## 银行全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他入口接收输入。
var _bank_overlay: Control
## 银行面板实例；关闭后复用，计息与倒计时由独立 Autoload 服务后台继续推进。
var _bank_panel: Control
## 据点全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他入口接收输入。
var _hideout_overlay: Control
## 据点面板实例；关闭后复用，建造倒计时由独立 Autoload 服务后台继续推进。
var _hideout_panel: Control
## 派遣全屏遮罩；默认运行时创建并隐藏，打开时阻止主菜单其他入口接收输入。
var _dispatch_overlay: Control
## 派遣面板实例；关闭后复用，委托倒计时由独立 Autoload 服务后台继续推进。
var _dispatch_panel: Control
## 图鉴全屏遮罩；默认运行时创建并隐藏，显示时阻止主菜单其他入口接收鼠标输入。
var _encyclopedia_overlay: Control
## 图鉴面板实例；关闭后复用，打开时从内容目录重新读取全部条目并同步永久发现状态。
var _encyclopedia_panel: Control
## 联机组队全屏遮罩；默认运行时创建并隐藏，显示时阻止主菜单其他入口接收鼠标输入。
var _multiplayer_overlay: Control
## 联机组队面板实例；关闭后复用，网络会话由 NetworkSession 常驻持有，面板关闭不会断开连接。
var _multiplayer_panel: Control
## 悬赏全屏遮罩；默认运行时创建并隐藏，显示时阻止主菜单其他入口接收鼠标输入。
var _bounty_overlay: Control
## 悬赏面板实例；关闭后复用，悬赏进度与每日刷新由独立 AutoLoad 服务后台维护。
var _bounty_panel: Control
## 统计全屏遮罩；默认运行时创建并隐藏，显示时阻止主菜单其他入口接收鼠标输入。
var _stats_overlay: Control
## 统计面板实例；关闭后复用，打开时从生涯统计服务读取最新快照与财富采样。
var _stats_panel: Control
## 骇入模式选择全屏遮罩；默认运行时创建并隐藏，显示时阻止主菜单其他入口接收鼠标输入。
var _hack_mode_overlay: Control
## 骇入模式选择面板实例；关闭后复用，模式清单与说明由 HackModeRules 规则表提供。
var _hack_mode_panel: Control
## 模式扩展选择全屏遮罩；骇入模式确定后显示，阻止主菜单其他入口接收输入。
var _mode_extension_overlay: Control
## 模式扩展选择面板实例；单人流程每次打开时使用空配置，允许多选扩展或不选择。
var _mode_extension_panel: Control
## 等待模式扩展确认的骇入模式标识；默认标准骇入，确认后写入 SessionState 并进入战斗。
var _pending_hack_variant: String = HackModeRules.VARIANT_STANDARD
## 开发者菜单全屏遮罩；默认运行时创建并隐藏，解锁后阻止其他主菜单控件接收输入。
var _developer_overlay: Control
## 开发者菜单实例；默认由 DeveloperMenu 脚本动态创建并在关闭后复用。
var _developer_menu: Control
## 开发者序列当前匹配下标；取值 0 到序列长度，默认 0 表示等待字母 L。
var _developer_sequence_index: int = 0
## 上一次向大厅报告的面板可见状态；默认 false，宿主模式每帧只在状态实际变化时派发一次信号。
var _last_reported_modal_visibility: bool = false
## 设置面板聚焦遮罩；运行时创建并跟随设置面板显示，使设置页与其他局外面板拥有一致的暗化背景。
var _settings_dim_overlay: ColorRect = null
## 金融分类展开动画缓存；默认 null，重新点击或切换分类时停止旧动画以避免面板缩放状态互相覆盖。
var _finance_category_expansion_tween: Tween = null
## 统计分类展开动画缓存；默认 null，职责与金融动画分离，保证两组互斥入口能独立复位。
var _statistics_category_expansion_tween: Tween = null


func _ready() -> void:
	UI_STYLE_GUIDE.apply_screen_theme(self)
	UI_STYLE_GUIDE.apply_window_panel(_settings_panel)
	UI_STYLE_GUIDE.apply_primary_button(_start_button)
	UI_STYLE_GUIDE.apply_danger_button(_quit_button)
	UI_STYLE_GUIDE.apply_title_label(get_node("Center/Title") as Label)
	UI_STYLE_GUIDE.apply_muted_accent_label(get_node("Center/EnglishTitle") as Label)
	UI_STYLE_GUIDE.apply_title_label(_settings_title_label)
	UI_STYLE_GUIDE.apply_screen_background(_background)
	_build_settings_dim_overlay()
	UI_STYLE_GUIDE.apply_primary_button(_switch_lobby_menu_button)
	# 底部分类按钮保持普通按钮样式；它们与角色、背包等同级入口共用场景主题，只以三角形表达展开状态。
	UI_STYLE_GUIDE.apply_section_panel(_finance_category_panel)
	UI_STYLE_GUIDE.apply_section_panel(_statistics_category_panel)
	PROGRESS_SLIDER_VISUAL_SCRIPT.install(_master_volume_slider)
	_master_bus_index = AudioServer.get_bus_index("Master")
	_start_button.pressed.connect(_on_start_button_pressed)
	_training_button.pressed.connect(_on_training_button_pressed)
	_multiplayer_button.pressed.connect(_on_multiplayer_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_character_button.pressed.connect(_on_character_button_pressed)
	_warehouse_button.pressed.connect(_on_warehouse_button_pressed)
	_backpack_button.pressed.connect(_on_backpack_button_pressed)
	_shop_button.pressed.connect(_on_shop_button_pressed)
	_forge_button.pressed.connect(_on_forge_button_pressed)
	_stock_market_button.pressed.connect(_on_stock_market_button_pressed)
	_mining_farm_button.pressed.connect(_on_mining_farm_button_pressed)
	_insurance_button.pressed.connect(_on_insurance_button_pressed)
	_bank_button.pressed.connect(_on_bank_button_pressed)
	_hideout_button.pressed.connect(_on_hideout_button_pressed)
	_dispatch_button.pressed.connect(_on_dispatch_button_pressed)
	_finance_category_button.pressed.connect(_on_finance_category_button_pressed)
	_statistics_category_button.pressed.connect(_on_statistics_category_button_pressed)
	_encyclopedia_button.pressed.connect(_on_encyclopedia_button_pressed)
	_bounty_button.pressed.connect(_on_bounty_button_pressed)
	_stats_button.pressed.connect(_on_stats_button_pressed)
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	if _global_inventory != null and _global_inventory.has_signal("total_coins_earned_changed"):
		_global_inventory.connect("total_coins_earned_changed", Callable(self, "_refresh_finance_unlock_buttons"))
	_refresh_finance_unlock_buttons()
	_newcomer_protection_service = get_tree().root.get_node_or_null("NewcomerProtectionService")
	if _newcomer_protection_service != null and _newcomer_protection_service.has_signal("first_successful_extraction_completed"):
		_newcomer_protection_service.connect("first_successful_extraction_completed", Callable(self, "_refresh_first_successful_extraction_unlock_buttons"))
	_refresh_first_successful_extraction_unlock_buttons()
	_master_volume_slider.value_changed.connect(_on_master_volume_slider_value_changed)
	_settings_back_button.pressed.connect(_on_settings_back_button_pressed)
	_switch_lobby_menu_button.pressed.connect(_on_switch_lobby_menu_button_pressed)
	_build_key_binding_navigation()
	_build_warehouse_overlay()
	_build_backpack_overlay()
	_build_shop_overlay()
	_build_forge_overlay()
	_build_stock_market_overlay()
	_build_mining_farm_overlay()
	_build_insurance_overlay()
	_build_bank_overlay()
	_build_hideout_overlay()
	_build_dispatch_overlay()
	_build_encyclopedia_overlay()
	_build_multiplayer_overlay()
	_build_bounty_overlay()
	_build_stats_overlay()
	_build_hack_mode_overlay()
	_build_mode_extension_overlay()
	_build_developer_overlay()
	_settings_panel.visible = false
	_set_bottom_category_visibility(false, false)
	resized.connect(_on_main_menu_resized)
	_show_key_binding_page(false)
	_sync_master_volume_slider()
	_apply_lobby_host_mode()
	set_process(lobby_host_mode)
	if not lobby_host_mode:
		_start_button.grab_focus()


func _refresh_finance_unlock_buttons(_total_coins_earned: int = -1) -> void:
	## 按永久累计获得星穹刷新四个金融入口；信号参数只用于触发，实际值始终重新读取唯一库存所有者。
	# 当前累计获得星穹；服务缺失或接口不可用时按 0 处理，避免独立场景错误开放金融功能。
	var total_coins_earned: int = int(_global_inventory.call("get_total_coins_earned")) if _global_inventory != null and _global_inventory.has_method("get_total_coins_earned") else 0
	_apply_finance_button_unlock_state(_insurance_button, FINANCE_UNLOCK_RULES.FEATURE_INSURANCE, total_coins_earned)
	_apply_finance_button_unlock_state(_bank_button, FINANCE_UNLOCK_RULES.FEATURE_BANK, total_coins_earned)
	_apply_finance_button_unlock_state(_mining_farm_button, FINANCE_UNLOCK_RULES.FEATURE_MINING_FARM, total_coins_earned)
	_apply_finance_button_unlock_state(_stock_market_button, FINANCE_UNLOCK_RULES.FEATURE_STOCK_MARKET, total_coins_earned)


func _apply_finance_button_unlock_state(button: Button, feature_id: String, total_coins_earned: int) -> void:
	## 把单个金融按钮同步为可用或纯黑禁用状态，并只在锁定时展示统一门槛提示。
	if button == null:
		return
	# 是否已经永久解锁；累计值达到规则门槛后保持可用，不受当前余额变化影响。
	var is_unlocked: bool = bool(FINANCE_UNLOCK_RULES.is_feature_unlocked(feature_id, total_coins_earned))
	button.disabled = not is_unlocked
	button.tooltip_text = "" if is_unlocked else str(FINANCE_UNLOCK_RULES.get_locked_tooltip(feature_id))
	UI_STYLE_GUIDE.apply_locked_button_visual(button, not is_unlocked)


func _is_finance_feature_unlocked(feature_id: String) -> bool:
	## 返回指定金融功能的当前永久解锁状态；所有按钮与大厅动作在真正打开面板前都执行同一防御检查。
	if _global_inventory == null or not _global_inventory.has_method("get_total_coins_earned"):
		return false
	return bool(FINANCE_UNLOCK_RULES.is_feature_unlocked(feature_id, int(_global_inventory.call("get_total_coins_earned"))))


func _refresh_first_successful_extraction_unlock_buttons() -> void:
	## 按首次正式成功撤离永久资格统一刷新四个局外成长入口；完成信号到达后立即解除全部锁定。
	# 是否已经完成首次成功撤离；服务缺失或查询接口不可用时保持安全锁定。
	var is_unlocked: bool = _has_completed_first_successful_extraction()
	_apply_first_successful_extraction_button_state(_forge_button, is_unlocked)
	_apply_first_successful_extraction_button_state(_hideout_button, is_unlocked)
	_apply_first_successful_extraction_button_state(_dispatch_button, is_unlocked)
	_apply_first_successful_extraction_button_state(_bounty_button, is_unlocked)
	# 骇入模式面板；娱乐模式卡片由独立展示组件维护，资格变化时同步刷新其禁用状态与悬停提示。
	if _hack_mode_panel != null and _hack_mode_panel.has_method("configure_first_successful_extraction_unlock"):
		_hack_mode_panel.call("configure_first_successful_extraction_unlock", is_unlocked, FIRST_SUCCESSFUL_EXTRACTION_UNLOCK_TOOLTIP)


func _apply_first_successful_extraction_button_state(button: Button, is_unlocked: bool) -> void:
	## 把单个首次撤离成长入口同步为普通可用或纯黑禁用状态；锁定时显示统一完成条件。
	if button == null:
		return
	button.disabled = not is_unlocked
	button.tooltip_text = "" if is_unlocked else FIRST_SUCCESSFUL_EXTRACTION_UNLOCK_TOOLTIP
	UI_STYLE_GUIDE.apply_locked_button_visual(button, not is_unlocked)


func _has_completed_first_successful_extraction() -> bool:
	## 返回四个局外成长功能共享的永久资格；实际状态只由新手成长服务在正式成功结算后修改。
	if _newcomer_protection_service == null or not _newcomer_protection_service.has_method("has_completed_first_successful_extraction"):
		return false
	return bool(_newcomer_protection_service.call("has_completed_first_successful_extraction"))


func _build_settings_dim_overlay() -> void:
	## 在设置面板下方插入全屏聚焦遮罩，避免主菜单中心按钮透过半透明设置窗口产生残影。
	_settings_dim_overlay = ColorRect.new()
	_settings_dim_overlay.name = "SettingsDimOverlay"
	_settings_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 遮罩拦截鼠标；设置页打开期间阻止误点背后的主菜单与底部功能入口。
	_settings_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_dim_overlay.visible = _settings_panel.visible
	add_child(_settings_dim_overlay)
	# 插入到设置面板之前的绘制顺序；遮罩位于设置窗口下方、其余界面上方。
	move_child(_settings_dim_overlay, _settings_panel.get_index())
	UI_STYLE_GUIDE.apply_overlay_dim(_settings_dim_overlay)
	_settings_panel.visibility_changed.connect(_on_settings_panel_visibility_changed)


func _on_settings_panel_visibility_changed() -> void:
	## 设置面板显示状态变化时同步遮罩；任意入口开关设置页都无需单独维护遮罩状态。
	if _settings_dim_overlay != null:
		_settings_dim_overlay.visible = _settings_panel.visible


func _process(_delta: float) -> void:
	if not lobby_host_mode:
		return
	# 当前面板状态；只要任意设置页、局外功能页或开发者页可见，就需要大厅锁定玩家与实体交互。
	var current_modal_visibility: bool = is_modal_open()
	if current_modal_visibility == _last_reported_modal_visibility:
		return
	_last_reported_modal_visibility = current_modal_visibility
	modal_visibility_changed.emit(_last_reported_modal_visibility)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _is_bottom_category_expanded():
		_collapse_bottom_categories()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey):
		return
	# 键盘事件；只处理首次按下且具有 Unicode 字符的字母键，长按重复不会推进序列。
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.unicode <= 0:
		return
	# 输入字符；统一转为大写后与隐藏序列逐位比较，键盘大小写状态不会影响解锁。
	var input_character: String = String.chr(key_event.unicode).to_upper()
	# 当前期望字符；取值为序列匹配下标对应单字符，用于推进或重置解锁进度。
	var expected_character: String = DEVELOPER_UNLOCK_SEQUENCE.substr(_developer_sequence_index, 1)
	if input_character == expected_character:
		_developer_sequence_index += 1
	else:
		_developer_sequence_index = 1 if input_character == DEVELOPER_UNLOCK_SEQUENCE.substr(0, 1) else 0
	if _developer_sequence_index < DEVELOPER_UNLOCK_SEQUENCE.length():
		return
	_developer_sequence_index = 0
	_open_developer_menu()
	get_viewport().set_input_as_handled()


func _on_finance_category_button_pressed() -> void:
	## 切换金融分类；展开时只显示金融入口，并同步把向上三角形翻转为向下三角形。
	_set_bottom_category_visibility(not _finance_category_panel.visible, false)


func _on_statistics_category_button_pressed() -> void:
	## 切换统计分类；展开时只显示图鉴和生涯入口，并同步把向上三角形翻转为向下三角形。
	_set_bottom_category_visibility(false, not _statistics_category_panel.visible)


func _set_bottom_category_visibility(show_finance: bool, show_statistics: bool) -> void:
	## 统一维护底部分类展开状态；金融与统计互斥，展开列表始终从各自按钮的上方纵向出现并同步三角形方向。
	if _finance_category_panel == null or _statistics_category_panel == null or _bottom_category_expansion_margin == null:
		return
	# 实际展开状态；统计与金融互斥时优先保留金融参数，避免异常调用让两组列表同时遮挡底部按钮。
	var should_show_finance: bool = show_finance
	var should_show_statistics: bool = show_statistics and not should_show_finance
	_bottom_category_expansion_margin.visible = should_show_finance or should_show_statistics
	_set_category_panel_open(_finance_category_panel, _finance_category_button, should_show_finance)
	_set_category_panel_open(_statistics_category_panel, _statistics_category_button, should_show_statistics)
	_finance_category_button.text = "金融 ▼" if should_show_finance else "金融 ▲"
	_statistics_category_button.text = "统计 ▼" if should_show_statistics else "统计 ▲"


func _set_category_panel_open(panel: PanelContainer, source_button: Button, should_show: bool) -> void:
	## 设置单个底部分类面板的可见状态；展开时以所属按钮为锚点从下向上缩放为一列，收起时立即复位避免残留动画状态。
	if panel == null or source_button == null:
		return
	_stop_category_panel_animation(panel)
	if not should_show:
		panel.visible = false
		panel.scale = Vector2.ONE
		return
	# 面板最小尺寸；纵向按钮容器按内容决定宽高，脱离容器布局后由这里写入实际尺寸。
	panel.size = panel.get_combined_minimum_size()
	_position_category_panel(panel, source_button)
	# 动画基准点；底部中心固定在按钮上方，缩放高度时所有入口会从上方按钮处逐项向上展开。
	panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y)
	panel.visible = true
	panel.scale = Vector2(1.0, 0.0)
	# 展开补间；只缩放纵向高度，横向宽度保持完整，视觉上形成自下而上的单列展开动画。
	var expansion_tween: Tween = create_tween()
	_set_category_panel_animation(panel, expansion_tween)
	expansion_tween.tween_property(panel, "scale", Vector2.ONE, CATEGORY_EXPANSION_ANIMATION_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _position_category_panel(panel: PanelContainer, source_button: Button) -> void:
	## 把分类面板居中定位至所属按钮正上方；窗口尺寸变化时重算并限制在主菜单可见范围内。
	if _bottom_category_expansion_margin == null or panel == null or source_button == null:
		return
	# 展开层全局逆变换；CanvasItem 提供坐标变换，避免把 Node2D 专属的 to_local 接口误用于 Control。
	var expansion_layer_inverse_transform: Transform2D = _bottom_category_expansion_margin.get_global_transform_with_canvas().affine_inverse()
	# 按钮局部坐标；将所属按钮的全局画布坐标换算到展开层，避免底部边距容器改变时出现横向偏移。
	var button_position: Vector2 = expansion_layer_inverse_transform * source_button.get_global_transform_with_canvas().origin
	# 期望位置；面板水平中心与按钮中心对齐，底边与按钮顶边之间保持固定留白。
	var desired_position: Vector2 = Vector2(
		button_position.x + (source_button.size.x - panel.size.x) * 0.5,
		button_position.y - panel.size.y - CATEGORY_EXPANSION_GAP
	)
	# 可用宽高；窗口过小时仍保证夹取上限非负，防止 clampf 传入反向范围。
	var maximum_x: float = maxf(_bottom_category_expansion_margin.size.x - panel.size.x, 0.0)
	var maximum_y: float = maxf(_bottom_category_expansion_margin.size.y - panel.size.y, 0.0)
	panel.position = Vector2(clampf(desired_position.x, 0.0, maximum_x), clampf(desired_position.y, 0.0, maximum_y))


func _stop_category_panel_animation(panel: PanelContainer) -> void:
	## 停止指定分类的旧补间；连续点击或在两类之间切换时确保只有当前请求能控制面板缩放。
	var active_tween: Tween = _get_category_panel_animation(panel)
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	_set_category_panel_animation(panel, null)


func _get_category_panel_animation(panel: PanelContainer) -> Tween:
	## 返回指定分类面板当前补间；未识别面板返回 null，保持辅助函数对未来分类扩展的安全性。
	if panel == _finance_category_panel:
		return _finance_category_expansion_tween
	if panel == _statistics_category_panel:
		return _statistics_category_expansion_tween
	return null


func _set_category_panel_animation(panel: PanelContainer, animation_tween: Tween) -> void:
	## 保存指定分类面板的当前补间引用；金融与统计分别持有，避免字典键或节点生命周期造成无效引用。
	if panel == _finance_category_panel:
		_finance_category_expansion_tween = animation_tween
	elif panel == _statistics_category_panel:
		_statistics_category_expansion_tween = animation_tween


func _on_main_menu_resized() -> void:
	## 主菜单尺寸改变后重新锚定已展开列表；全屏或窗口模式切换时仍保持面板位于所属按钮正上方。
	if _finance_category_panel != null and _finance_category_panel.visible:
		_position_category_panel(_finance_category_panel, _finance_category_button)
	if _statistics_category_panel != null and _statistics_category_panel.visible:
		_position_category_panel(_statistics_category_panel, _statistics_category_button)


func _collapse_bottom_categories() -> void:
	## 收起全部底部分类；从分类中的入口打开功能页或按取消键时调用，使返回主菜单后保持紧凑布局。
	_set_bottom_category_visibility(false, false)


func _is_bottom_category_expanded() -> bool:
	## 返回是否存在已展开的底部分类；仅供取消键优先收起菜单使用，不参与大厅模态状态。
	return _bottom_category_expansion_margin != null and _bottom_category_expansion_margin.visible


func _on_start_button_pressed() -> void:
	## 打开骇入模式选择界面；实际进入战斗由模式面板的“进入”按钮经 _on_hack_mode_selected 完成。
	if _hack_mode_overlay == null:
		return
	_settings_panel.visible = false
	_hack_mode_overlay.visible = true


func _on_training_button_pressed() -> void:
	_start_game(GAME_MODE_TRAINING)


func _on_hack_mode_selected(hack_variant: String) -> void:
	## 模式面板选择回调；写入所选骇入模式变体后按正式骇入流程进入战斗。
	## 模式扩展补充：正式骇入流程会先打开扩展窗口，只有确认扩展配置后才切换战斗场景。
	# 标准化后的模式标识；先复核娱乐模式永久资格，防止外部信号绕过模式卡禁用状态。
	var resolved_hack_variant: String = HackModeRules.normalize_variant(hack_variant)
	if HackModeRules.requires_first_successful_extraction(resolved_hack_variant) and not _has_completed_first_successful_extraction():
		return
	if _hack_mode_overlay != null:
		_hack_mode_overlay.visible = false
	_pending_hack_variant = resolved_hack_variant
	# 会话状态节点；缺失时仍按标准流程进入，模式变体留待战斗世界按标准骇入兜底。
	# 模式扩展补充：先写入骇入模式，使扩展规则能正确判断超频等无结算模式的兼容性。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state != null and session_state.has_method("set_hack_variant"):
		session_state.call("set_hack_variant", _pending_hack_variant)
	# 首次正式成功撤离前不提供模式扩展窗口；明确清空上一局运行期配置后直接进入本次标准或零装骇入。
	if not _has_completed_first_successful_extraction():
		if session_state != null and session_state.has_method("clear_mode_extensions"):
			session_state.call("clear_mode_extensions")
		elif session_state != null and session_state.has_method("configure_mode_extensions"):
			session_state.call("configure_mode_extensions", [], [])
		_start_game(GAME_MODE_HACK)
		return
	if _mode_extension_panel != null and _mode_extension_panel.has_method("configure"):
		# 单人每次模式选择都从空扩展开始；玩家必须主动确认本局配置，不继承上一局风险词条。
		_mode_extension_panel.call("configure", _pending_hack_variant, [], [], "进入游戏")
	if _mode_extension_overlay != null:
		_mode_extension_overlay.visible = true


func _on_hack_mode_select_closed() -> void:
	if _hack_mode_overlay != null:
		_hack_mode_overlay.visible = false
	_start_button.grab_focus()


func _on_mode_extension_configuration_confirmed(extension_ids: Array[String], risk_modifier_ids: Array[String]) -> void:
	## 模式扩展确认回调；把骇入模式与扩展配置一并写入会话状态后进入正式战斗。
	if _mode_extension_overlay != null:
		_mode_extension_overlay.visible = false
	# 会话状态节点；缺失时仍可进入战斗，GameWorld 会按标准无扩展规则安全回退。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state != null and session_state.has_method("set_hack_variant"):
		session_state.call("set_hack_variant", _pending_hack_variant)
	if session_state != null and session_state.has_method("configure_mode_extensions"):
		# 回调防御；即使外部脚本直接派发确认信号，首次正式成功撤离前也不能把扩展写入本局会话。
		if _has_completed_first_successful_extraction():
			session_state.call("configure_mode_extensions", extension_ids, risk_modifier_ids)
		else:
			session_state.call("configure_mode_extensions", [], [])
	_start_game(GAME_MODE_HACK)


func _on_mode_extension_select_closed() -> void:
	## 返回骇入模式选择界面；未确认的扩展与风险词条不会写入 SessionState。
	if _mode_extension_overlay != null:
		_mode_extension_overlay.visible = false
	if _hack_mode_overlay != null:
		_hack_mode_overlay.visible = true


func _on_character_button_pressed() -> void:
	_settings_panel.visible = false
	_set_character_select_return_scene_path()
	_change_scene_with_transition(character_select_scene_path)


func _on_settings_button_pressed() -> void:
	_settings_panel.visible = true
	_show_key_binding_page(false)
	_settings_back_button.grab_focus()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_switch_lobby_menu_button_pressed() -> void:
	## 左上角切换按钮；默认进入主大厅，身处联机房间（主机或已加入）时改为进入联机大厅，与房间成员保持在场互见。
	# 联机会话服务；缺失或未入房时保持单机主大厅路径。
	var network_session: Node = get_tree().root.get_node_or_null("NetworkSession")
	if network_session != null and network_session.has_method("is_session_active") and bool(network_session.call("is_session_active")):
		_change_scene_with_transition(multiplayer_lobby_scene_path)
		return
	_change_scene_with_transition(lobby_scene_path)


func perform_lobby_action(action_id: String) -> bool:
	## 把大厅实体的稳定动作标识映射到现有主菜单入口；返回 false 表示动作未注册且不会产生副作用。
	match action_id:
		LOBBY_ACTION_HACK:
			_on_start_button_pressed()
		LOBBY_ACTION_TRAINING:
			_on_training_button_pressed()
		LOBBY_ACTION_CHARACTER:
			_on_character_button_pressed()
		LOBBY_ACTION_BACKPACK:
			_on_backpack_button_pressed()
		LOBBY_ACTION_WAREHOUSE:
			_on_warehouse_button_pressed()
		LOBBY_ACTION_SHOP:
			_on_shop_button_pressed()
		LOBBY_ACTION_FORGE:
			_on_forge_button_pressed()
		LOBBY_ACTION_STOCK_MARKET:
			_on_stock_market_button_pressed()
		LOBBY_ACTION_MINING_FARM:
			_on_mining_farm_button_pressed()
		LOBBY_ACTION_INSURANCE:
			_on_insurance_button_pressed()
		LOBBY_ACTION_BANK:
			_on_bank_button_pressed()
		LOBBY_ACTION_HIDEOUT:
			_on_hideout_button_pressed()
		LOBBY_ACTION_DISPATCH:
			_on_dispatch_button_pressed()
		LOBBY_ACTION_ENCYCLOPEDIA:
			_on_encyclopedia_button_pressed()
		LOBBY_ACTION_BOUNTY:
			_on_bounty_button_pressed()
		LOBBY_ACTION_STATS:
			_on_stats_button_pressed()
		LOBBY_ACTION_MULTIPLAYER:
			_on_multiplayer_button_pressed()
		LOBBY_ACTION_SETTINGS:
			_on_settings_button_pressed()
		LOBBY_ACTION_QUIT:
			_on_quit_button_pressed()
		_:
			return false
	return true


func is_modal_open() -> bool:
	## 返回当前是否显示任意复用局外界面；大厅只依赖该聚合结果，不读取具体面板节点。
	return (
		_settings_panel.visible
		or (_warehouse_overlay != null and _warehouse_overlay.visible)
		or (_backpack_overlay != null and _backpack_overlay.visible)
		or (_shop_overlay != null and _shop_overlay.visible)
		or (_forge_overlay != null and _forge_overlay.visible)
		or (_stock_market_overlay != null and _stock_market_overlay.visible)
		or (_mining_farm_overlay != null and _mining_farm_overlay.visible)
		or (_insurance_overlay != null and _insurance_overlay.visible)
		or (_bank_overlay != null and _bank_overlay.visible)
		or (_hideout_overlay != null and _hideout_overlay.visible)
		or (_dispatch_overlay != null and _dispatch_overlay.visible)
		or (_encyclopedia_overlay != null and _encyclopedia_overlay.visible)
		or (_multiplayer_overlay != null and _multiplayer_overlay.visible)
		or (_bounty_overlay != null and _bounty_overlay.visible)
		or (_stats_overlay != null and _stats_overlay.visible)
		or (_hack_mode_overlay != null and _hack_mode_overlay.visible)
		or (_mode_extension_overlay != null and _mode_extension_overlay.visible)
		or (_developer_overlay != null and _developer_overlay.visible)
	)


func _apply_lobby_host_mode() -> void:
	## 切换完整菜单与大厅面板宿主表现；业务面板始终创建一次并由原关闭协议复用。
	_background.visible = not lobby_host_mode
	_center_menu.visible = not lobby_host_mode
	_bottom_menu_margin.visible = not lobby_host_mode
	# 底部分类展开区；与功能栏同属完整主菜单本体，大厅宿主模式下一并隐藏并复位为收起状态。
	if lobby_host_mode:
		_collapse_bottom_categories()
	_bottom_category_expansion_margin.visible = not lobby_host_mode and _is_bottom_category_expanded()
	_switch_lobby_menu_button.visible = not lobby_host_mode
	mouse_filter = Control.MOUSE_FILTER_IGNORE if lobby_host_mode else Control.MOUSE_FILTER_STOP
	if lobby_host_mode:
		process_mode = Node.PROCESS_MODE_ALWAYS


func _set_character_select_return_scene_path() -> void:
	# 会话状态节点；一次性返回目标属于跨场景导航状态，由 SessionState 统一持有而不写入永久存档。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null or not session_state.has_method("set_character_select_return_scene_path"):
		return
	# 当前场景路径；完整主菜单返回自身，大厅宿主嵌入时返回 MainLobby，避免角色页固定跳回菜单。
	var current_scene_path: String = get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "res://scenes/ui/main_menu.tscn"
	session_state.call("set_character_select_return_scene_path", current_scene_path)


func _on_warehouse_button_pressed() -> void:
	if _warehouse_overlay == null:
		return
	_settings_panel.visible = false
	_warehouse_overlay.visible = true
	if _warehouse_panel != null and _warehouse_panel.has_method("refresh"):
		_warehouse_panel.call("refresh")


func _on_backpack_button_pressed() -> void:
	if _backpack_overlay == null:
		return
	_settings_panel.visible = false
	_backpack_overlay.visible = true
	if _backpack_panel != null and _backpack_panel.has_method("refresh"):
		_backpack_panel.call("refresh")


func _on_shop_button_pressed() -> void:
	if _shop_overlay == null:
		return
	_settings_panel.visible = false
	_shop_overlay.visible = true


func _on_forge_button_pressed() -> void:
	if _forge_overlay == null or not _has_completed_first_successful_extraction():
		return
	_settings_panel.visible = false
	_forge_overlay.visible = true
	if _forge_panel != null and _forge_panel.has_method("refresh"):
		_forge_panel.call("refresh")


func _on_stock_market_button_pressed() -> void:
	if _stock_market_overlay == null or not _is_finance_feature_unlocked(FINANCE_UNLOCK_RULES.FEATURE_STOCK_MARKET):
		return
	_collapse_bottom_categories()
	_settings_panel.visible = false
	_stock_market_overlay.visible = true
	if _stock_market_panel != null and _stock_market_panel.has_method("set_market_display_active"):
		_stock_market_panel.call("set_market_display_active", true)


func _on_mining_farm_button_pressed() -> void:
	if _mining_farm_overlay == null or not _is_finance_feature_unlocked(FINANCE_UNLOCK_RULES.FEATURE_MINING_FARM):
		return
	_collapse_bottom_categories()
	_settings_panel.visible = false
	_mining_farm_overlay.visible = true
	if _mining_farm_panel != null and _mining_farm_panel.has_method("present"):
		_mining_farm_panel.call("present")


func _on_insurance_button_pressed() -> void:
	if _insurance_overlay == null or not _is_finance_feature_unlocked(FINANCE_UNLOCK_RULES.FEATURE_INSURANCE):
		return
	_collapse_bottom_categories()
	_settings_panel.visible = false
	_insurance_overlay.visible = true
	if _insurance_panel != null and _insurance_panel.has_method("refresh"):
		_insurance_panel.call("refresh")


func _on_bank_button_pressed() -> void:
	if _bank_overlay == null or not _is_finance_feature_unlocked(FINANCE_UNLOCK_RULES.FEATURE_BANK):
		return
	_collapse_bottom_categories()
	_settings_panel.visible = false
	_bank_overlay.visible = true
	if _bank_panel != null and _bank_panel.has_method("refresh"):
		_bank_panel.call("refresh")


func _on_hideout_button_pressed() -> void:
	if _hideout_overlay == null or not _has_completed_first_successful_extraction():
		return
	_settings_panel.visible = false
	_hideout_overlay.visible = true
	if _hideout_panel != null and _hideout_panel.has_method("refresh"):
		_hideout_panel.call("refresh")


func _on_dispatch_button_pressed() -> void:
	if _dispatch_overlay == null or not _has_completed_first_successful_extraction():
		return
	_settings_panel.visible = false
	_dispatch_overlay.visible = true
	if _dispatch_panel != null and _dispatch_panel.has_method("refresh"):
		_dispatch_panel.call("refresh")


func _on_encyclopedia_button_pressed() -> void:
	if _encyclopedia_overlay == null:
		return
	_collapse_bottom_categories()
	_settings_panel.visible = false
	_encyclopedia_overlay.visible = true
	if _encyclopedia_panel != null and _encyclopedia_panel.has_method("refresh"):
		_encyclopedia_panel.call("refresh")


func _on_bounty_button_pressed() -> void:
	if _bounty_overlay == null or not _has_completed_first_successful_extraction():
		return
	_settings_panel.visible = false
	_bounty_overlay.visible = true
	if _bounty_panel != null and _bounty_panel.has_method("refresh"):
		_bounty_panel.call("refresh")


func _on_stats_button_pressed() -> void:
	if _stats_overlay == null:
		return
	_collapse_bottom_categories()
	_settings_panel.visible = false
	_stats_overlay.visible = true
	if _stats_panel != null and _stats_panel.has_method("refresh"):
		_stats_panel.call("refresh")


func _build_warehouse_overlay() -> void:
	if _warehouse_overlay != null:
		return

	# 仓库遮罩；覆盖整个主菜单并拦截输入，关闭时整体隐藏。
	var warehouse_overlay: Control = Control.new()
	warehouse_overlay.name = "WarehouseOverlay"
	warehouse_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warehouse_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(warehouse_overlay)
	_warehouse_overlay = warehouse_overlay

	# 仓库背景遮罩；使用半透明黑色突出仓库内容。
	var warehouse_dim: ColorRect = ColorRect.new()
	warehouse_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 全局遮罩补充；实际颜色由样式指南统一为带蓝色分量的深色透明层。
	UI_STYLE_GUIDE.apply_overlay_dim(warehouse_dim)
	warehouse_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	warehouse_overlay.add_child(warehouse_dim)

	# 仓库面板；居中显示并由独立组件维护装备和物品列表。
	var warehouse_panel: Control = WAREHOUSE_PANEL_SCRIPT.new() as Control
	if warehouse_panel == null:
		warehouse_overlay.visible = false
		return
	warehouse_panel.anchor_left = 0.5
	warehouse_panel.anchor_top = 0.5
	warehouse_panel.anchor_right = 0.5
	warehouse_panel.anchor_bottom = 0.5
	warehouse_panel.offset_left = -480.0
	warehouse_panel.offset_top = -310.0
	warehouse_panel.offset_right = 480.0
	warehouse_panel.offset_bottom = 310.0
	warehouse_panel.connect("closed", Callable(self, "_on_warehouse_closed"))
	warehouse_overlay.add_child(warehouse_panel)
	_warehouse_panel = warehouse_panel
	warehouse_overlay.visible = false


func _build_backpack_overlay() -> void:
	if _backpack_overlay != null:
		return
	# 背包遮罩；覆盖完整主菜单并拦截输入，视觉透明度与仓库遮罩一致。
	var backpack_overlay: Control = Control.new()
	backpack_overlay.name = "BackpackOverlay"
	backpack_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backpack_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backpack_overlay)
	_backpack_overlay = backpack_overlay
	var backpack_dim: ColorRect = ColorRect.new()
	backpack_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 全局遮罩补充；背包与其他局外窗口使用同一深蓝黑透明层。
	UI_STYLE_GUIDE.apply_overlay_dim(backpack_dim)
	backpack_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	backpack_overlay.add_child(backpack_dim)
	# 背包面板；居中显示并保持与游戏内背包接近的 960×620 尺寸。
	var backpack_panel: Control = MAIN_MENU_BACKPACK_PANEL_SCRIPT.new() as Control
	if backpack_panel == null:
		backpack_overlay.visible = false
		return
	backpack_panel.call("configure_context", SharedBackpackPanel.CONTEXT_MAIN_MENU)
	backpack_panel.anchor_left = 0.5
	backpack_panel.anchor_top = 0.5
	backpack_panel.anchor_right = 0.5
	backpack_panel.anchor_bottom = 0.5
	backpack_panel.offset_left = -480.0
	backpack_panel.offset_top = -310.0
	backpack_panel.offset_right = 480.0
	backpack_panel.offset_bottom = 310.0
	backpack_panel.connect("closed", Callable(self, "_on_backpack_closed"))
	backpack_panel.connect("warehouse_requested", Callable(self, "_on_backpack_warehouse_requested"))
	backpack_overlay.add_child(backpack_panel)
	_backpack_panel = backpack_panel
	backpack_overlay.visible = false


func _build_shop_overlay() -> void:
	if _shop_overlay != null:
		return

	# 商店遮罩；覆盖整个主菜单并拦截输入，关闭时整体隐藏。
	var shop_overlay: Control = Control.new()
	shop_overlay.name = "ShopOverlay"
	shop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shop_overlay)
	_shop_overlay = shop_overlay

	# 商店背景遮罩；使用半透明黑色突出商品查询和购买区域。
	var shop_dim: ColorRect = ColorRect.new()
	shop_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 全局遮罩补充；实际颜色由样式指南统一管理。
	UI_STYLE_GUIDE.apply_overlay_dim(shop_dim)
	shop_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.add_child(shop_dim)

	# 商店面板；居中显示并由独立组件维护商品刷新、筛选与购买确认。
	var shop_panel: Control = SHOP_PANEL_SCRIPT.new() as Control
	if shop_panel == null:
		shop_overlay.visible = false
		return
	shop_panel.anchor_left = 0.5
	shop_panel.anchor_top = 0.5
	shop_panel.anchor_right = 0.5
	shop_panel.anchor_bottom = 0.5
	shop_panel.offset_left = -480.0
	shop_panel.offset_top = -310.0
	shop_panel.offset_right = 480.0
	shop_panel.offset_bottom = 310.0
	shop_panel.connect("closed", Callable(self, "_on_shop_closed"))
	shop_overlay.add_child(shop_panel)
	_shop_panel = shop_panel
	shop_overlay.visible = false


func _build_forge_overlay() -> void:
	if _forge_overlay != null:
		return

	# 锻造遮罩；覆盖整个主菜单并拦截输入，锻造动画期间由面板自身阻止关闭。
	var forge_overlay: Control = Control.new()
	forge_overlay.name = "ForgeOverlay"
	forge_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forge_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(forge_overlay)
	_forge_overlay = forge_overlay

	# 锻造背景遮罩；使用半透明黑色突出环形牺牲槽和锻造预览。
	var forge_dim: ColorRect = ColorRect.new()
	forge_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 全局遮罩补充；实际颜色由样式指南统一管理。
	UI_STYLE_GUIDE.apply_overlay_dim(forge_dim)
	forge_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	forge_overlay.add_child(forge_dim)

	# 锻造面板；居中显示并由独立组件维护材料引用、动画与原子结算。
	var forge_panel: Control = FORGE_PANEL_SCRIPT.new() as Control
	if forge_panel == null:
		forge_overlay.visible = false
		return
	forge_panel.anchor_left = 0.5
	forge_panel.anchor_top = 0.5
	forge_panel.anchor_right = 0.5
	forge_panel.anchor_bottom = 0.5
	forge_panel.offset_left = -480.0
	forge_panel.offset_top = -325.0
	forge_panel.offset_right = 480.0
	forge_panel.offset_bottom = 325.0
	forge_panel.connect("closed", Callable(self, "_on_forge_closed"))
	forge_overlay.add_child(forge_panel)
	_forge_panel = forge_panel
	forge_overlay.visible = false


func _build_stock_market_overlay() -> void:
	if _stock_market_overlay != null:
		return
	# 股市遮罩；覆盖完整主菜单并拦截输入，关闭时只隐藏界面而不停止后台行情服务。
	var stock_market_overlay: Control = Control.new()
	stock_market_overlay.name = "StockMarketOverlay"
	stock_market_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stock_market_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(stock_market_overlay)
	_stock_market_overlay = stock_market_overlay
	# 股市背景遮罩；透明度与商店、仓库保持一致，使行情面板成为清晰的局外焦点。
	var stock_market_dim: ColorRect = ColorRect.new()
	stock_market_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(stock_market_dim)
	stock_market_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	stock_market_overlay.add_child(stock_market_dim)
	# 股市面板；固定 1040×620 像素并由独立组件处理行情展示与交易确认。
	# 实际高度补充；交易区内容会把最小高度撑到约 665 像素，下方双向生长设置保证超出部分上下均匀延伸。
	var stock_market_panel: Control = STOCK_MARKET_PANEL_SCRIPT.new() as Control
	if stock_market_panel == null:
		stock_market_overlay.visible = false
		return
	stock_market_panel.anchor_left = 0.5
	stock_market_panel.anchor_top = 0.5
	stock_market_panel.anchor_right = 0.5
	stock_market_panel.anchor_bottom = 0.5
	stock_market_panel.offset_left = -520.0
	stock_market_panel.offset_top = -310.0
	stock_market_panel.offset_right = 520.0
	stock_market_panel.offset_bottom = 310.0
	# 面板双向生长；交易区内容把实际最小高度撑到超过预设 620 偏移时，超出部分向上下两侧均匀延伸，保证窗口始终屏幕居中。
	stock_market_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stock_market_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	stock_market_panel.connect("closed", Callable(self, "_on_stock_market_closed"))
	stock_market_overlay.add_child(stock_market_panel)
	_stock_market_panel = stock_market_panel
	stock_market_overlay.visible = false
	stock_market_panel.call("set_market_display_active", false)


func _build_mining_farm_overlay() -> void:
	if _mining_farm_overlay != null:
		return
	# 矿场遮罩；覆盖完整主菜单并拦截输入，关闭面板后整体停止渲染与动效。
	var mining_farm_overlay: Control = Control.new()
	mining_farm_overlay.name = "MiningFarmOverlay"
	mining_farm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mining_farm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mining_farm_overlay)
	_mining_farm_overlay = mining_farm_overlay
	# 矿场背景遮罩；使用与股市一致的深色透明度，使两个局外资产系统视觉并列。
	var mining_farm_dim: ColorRect = ColorRect.new()
	mining_farm_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(mining_farm_dim)
	mining_farm_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	mining_farm_overlay.add_child(mining_farm_dim)
	# 矿场面板；固定 1080×640 像素并由独立组件维护卡片、交易与动画。
	var mining_farm_panel: Control = MINING_FARM_PANEL_SCRIPT.new() as Control
	if mining_farm_panel == null:
		mining_farm_overlay.visible = false
		return
	mining_farm_panel.anchor_left = 0.5
	mining_farm_panel.anchor_top = 0.5
	mining_farm_panel.anchor_right = 0.5
	mining_farm_panel.anchor_bottom = 0.5
	mining_farm_panel.offset_left = -540.0
	mining_farm_panel.offset_top = -320.0
	mining_farm_panel.offset_right = 540.0
	mining_farm_panel.offset_bottom = 320.0
	mining_farm_panel.connect("closed", Callable(self, "_on_mining_farm_closed"))
	mining_farm_overlay.add_child(mining_farm_panel)
	_mining_farm_panel = mining_farm_panel
	mining_farm_overlay.visible = false


func _build_insurance_overlay() -> void:
	if _insurance_overlay != null:
		return
	# 保险遮罩；覆盖完整主菜单并拦截输入，关闭时只隐藏界面而不影响保单后台结算。
	var insurance_overlay: Control = Control.new()
	insurance_overlay.name = "InsuranceOverlay"
	insurance_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	insurance_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(insurance_overlay)
	_insurance_overlay = insurance_overlay
	# 保险背景遮罩；使用与其他局外面板一致的深色透明层。
	var insurance_dim: ColorRect = ColorRect.new()
	insurance_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(insurance_dim)
	insurance_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	insurance_overlay.add_child(insurance_dim)
	# 保险面板；固定 880×600 像素并由独立组件维护保单卡、统计与记录列表。
	var insurance_panel: Control = INSURANCE_PANEL_SCRIPT.new() as Control
	if insurance_panel == null:
		insurance_overlay.visible = false
		return
	insurance_panel.name = "InsurancePanel"
	insurance_panel.anchor_left = 0.5
	insurance_panel.anchor_top = 0.5
	insurance_panel.anchor_right = 0.5
	insurance_panel.anchor_bottom = 0.5
	insurance_panel.offset_left = -440.0
	insurance_panel.offset_top = -300.0
	insurance_panel.offset_right = 440.0
	insurance_panel.offset_bottom = 300.0
	insurance_panel.connect("closed", Callable(self, "_on_insurance_closed"))
	insurance_overlay.add_child(insurance_panel)
	_insurance_panel = insurance_panel
	insurance_overlay.visible = false


func _build_bank_overlay() -> void:
	if _bank_overlay != null:
		return
	# 银行遮罩；覆盖完整主菜单并拦截输入，关闭时只隐藏界面而不停止后台计息。
	var bank_overlay: Control = Control.new()
	bank_overlay.name = "BankOverlay"
	bank_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bank_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bank_overlay)
	_bank_overlay = bank_overlay
	# 银行背景遮罩；使用与股市、矿场一致的深色透明层，使金融面板视觉并列。
	var bank_dim: ColorRect = ColorRect.new()
	bank_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(bank_dim)
	bank_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	bank_overlay.add_child(bank_dim)
	# 银行面板；固定 1080×640 像素并由独立组件维护活期、定期与贷款页。
	var bank_panel: Control = BANK_PANEL_SCRIPT.new() as Control
	if bank_panel == null:
		bank_overlay.visible = false
		return
	bank_panel.name = "BankPanel"
	bank_panel.anchor_left = 0.5
	bank_panel.anchor_top = 0.5
	bank_panel.anchor_right = 0.5
	bank_panel.anchor_bottom = 0.5
	bank_panel.offset_left = -540.0
	bank_panel.offset_top = -320.0
	bank_panel.offset_right = 540.0
	bank_panel.offset_bottom = 320.0
	bank_panel.connect("closed", Callable(self, "_on_bank_closed"))
	bank_overlay.add_child(bank_panel)
	_bank_panel = bank_panel
	bank_overlay.visible = false


func _build_hideout_overlay() -> void:
	if _hideout_overlay != null:
		return
	# 据点遮罩；覆盖完整主菜单并拦截输入，关闭时只隐藏界面而不停止后台建造。
	var hideout_overlay: Control = Control.new()
	hideout_overlay.name = "HideoutOverlay"
	hideout_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hideout_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(hideout_overlay)
	_hideout_overlay = hideout_overlay
	# 据点背景遮罩；使用与其他局外面板一致的深色透明层。
	var hideout_dim: ColorRect = ColorRect.new()
	hideout_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(hideout_dim)
	hideout_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	hideout_overlay.add_child(hideout_dim)
	# 据点面板；固定 1080×640 像素并由独立组件维护六座设施卡与建造队列。
	var hideout_panel: Control = HIDEOUT_PANEL_SCRIPT.new() as Control
	if hideout_panel == null:
		hideout_overlay.visible = false
		return
	hideout_panel.name = "HideoutPanel"
	hideout_panel.anchor_left = 0.5
	hideout_panel.anchor_top = 0.5
	hideout_panel.anchor_right = 0.5
	hideout_panel.anchor_bottom = 0.5
	hideout_panel.offset_left = -540.0
	hideout_panel.offset_top = -320.0
	hideout_panel.offset_right = 540.0
	hideout_panel.offset_bottom = 320.0
	hideout_panel.connect("closed", Callable(self, "_on_hideout_closed"))
	hideout_overlay.add_child(hideout_panel)
	_hideout_panel = hideout_panel
	hideout_overlay.visible = false


func _build_dispatch_overlay() -> void:
	if _dispatch_overlay != null:
		return
	# 派遣遮罩；覆盖完整主菜单并拦截输入，关闭时只隐藏界面而不停止后台委托计时。
	var dispatch_overlay: Control = Control.new()
	dispatch_overlay.name = "DispatchOverlay"
	dispatch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dispatch_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dispatch_overlay)
	_dispatch_overlay = dispatch_overlay
	# 派遣背景遮罩；使用与其他局外面板一致的深色透明层。
	var dispatch_dim: ColorRect = ColorRect.new()
	dispatch_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(dispatch_dim)
	dispatch_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dispatch_overlay.add_child(dispatch_dim)
	# 派遣面板；固定 1000×620 像素并由独立组件维护委托卡、角色行与派遣状态。
	var dispatch_panel: Control = DISPATCH_PANEL_SCRIPT.new() as Control
	if dispatch_panel == null:
		dispatch_overlay.visible = false
		return
	dispatch_panel.name = "DispatchPanel"
	dispatch_panel.anchor_left = 0.5
	dispatch_panel.anchor_top = 0.5
	dispatch_panel.anchor_right = 0.5
	dispatch_panel.anchor_bottom = 0.5
	dispatch_panel.offset_left = -500.0
	dispatch_panel.offset_top = -310.0
	dispatch_panel.offset_right = 500.0
	dispatch_panel.offset_bottom = 310.0
	dispatch_panel.connect("closed", Callable(self, "_on_dispatch_closed"))
	dispatch_overlay.add_child(dispatch_panel)
	_dispatch_panel = dispatch_panel
	dispatch_overlay.visible = false


func _on_multiplayer_button_pressed() -> void:
	## 打开联机面板；完整主菜单与大厅宿主共用同一遮罩入口，不再强制切换到联机大厅场景。
	## 场景自由补充；入房后玩家可停留在主菜单，左上角“切换大厅/菜单”按钮负责在联机大厅与菜单之间往返。
	if _multiplayer_overlay == null:
		return
	_settings_panel.visible = false
	_multiplayer_overlay.visible = true
	if _multiplayer_panel != null and _multiplayer_panel.has_method("refresh"):
		_multiplayer_panel.call("refresh")


func _on_multiplayer_closed() -> void:
	_multiplayer_overlay.visible = false
	_multiplayer_button.grab_focus()


func _build_multiplayer_overlay() -> void:
	if _multiplayer_overlay != null:
		return
	# 联机组队遮罩；覆盖完整主菜单并拦截输入，网络会话保存在常驻服务中，关闭遮罩不断开连接。
	var multiplayer_overlay: Control = Control.new()
	multiplayer_overlay.name = "MultiplayerOverlay"
	multiplayer_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	multiplayer_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(multiplayer_overlay)
	_multiplayer_overlay = multiplayer_overlay
	# 联机组队背景遮罩；使用与其他局外面板一致的深色透明层。
	var multiplayer_dim: ColorRect = ColorRect.new()
	multiplayer_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(multiplayer_dim)
	multiplayer_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	multiplayer_overlay.add_child(multiplayer_dim)
	# 联机组队面板；固定 960×620 像素，左侧房间发现、右侧队伍名册。
	var multiplayer_panel: Control = MULTIPLAYER_PANEL_SCRIPT.new() as Control
	if multiplayer_panel == null:
		multiplayer_overlay.visible = false
		return
	multiplayer_panel.name = "MultiplayerLobbyPanel"
	multiplayer_panel.anchor_left = 0.5
	multiplayer_panel.anchor_top = 0.5
	multiplayer_panel.anchor_right = 0.5
	multiplayer_panel.anchor_bottom = 0.5
	multiplayer_panel.offset_left = -480.0
	multiplayer_panel.offset_top = -310.0
	multiplayer_panel.offset_right = 480.0
	multiplayer_panel.offset_bottom = 310.0
	multiplayer_panel.connect("closed", Callable(self, "_on_multiplayer_closed"))
	multiplayer_overlay.add_child(multiplayer_panel)
	_multiplayer_panel = multiplayer_panel
	multiplayer_overlay.visible = false


func _build_encyclopedia_overlay() -> void:
	if _encyclopedia_overlay != null:
		return
	# 图鉴遮罩；覆盖完整主菜单并拦截输入，隐藏时不保留任何主菜单交互焦点。
	var encyclopedia_overlay: Control = Control.new()
	encyclopedia_overlay.name = "EncyclopediaOverlay"
	encyclopedia_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encyclopedia_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(encyclopedia_overlay)
	_encyclopedia_overlay = encyclopedia_overlay
	# 图鉴背景遮罩；使用与仓库、商店和矿场一致的深蓝黑透明层突出收集信息。
	var encyclopedia_dim: ColorRect = ColorRect.new()
	encyclopedia_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(encyclopedia_dim)
	encyclopedia_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	encyclopedia_overlay.add_child(encyclopedia_dim)
	# 图鉴面板；固定 1000×640 像素，四列条目网格在该尺寸下保留名称与说明的可读空间。
	var encyclopedia_panel: Control = ENCYCLOPEDIA_PANEL_SCRIPT.new() as Control
	if encyclopedia_panel == null:
		encyclopedia_overlay.visible = false
		return
	encyclopedia_panel.name = "EncyclopediaPanel"
	encyclopedia_panel.anchor_left = 0.5
	encyclopedia_panel.anchor_top = 0.5
	encyclopedia_panel.anchor_right = 0.5
	encyclopedia_panel.anchor_bottom = 0.5
	encyclopedia_panel.offset_left = -500.0
	encyclopedia_panel.offset_top = -320.0
	encyclopedia_panel.offset_right = 500.0
	encyclopedia_panel.offset_bottom = 320.0
	encyclopedia_panel.connect("closed", Callable(self, "_on_encyclopedia_closed"))
	encyclopedia_overlay.add_child(encyclopedia_panel)
	_encyclopedia_panel = encyclopedia_panel
	encyclopedia_overlay.visible = false


func _build_bounty_overlay() -> void:
	if _bounty_overlay != null:
		return
	# 悬赏遮罩；覆盖完整主菜单并拦截输入，关闭时只隐藏界面而不停止每日刷新与进度推进。
	var bounty_overlay: Control = Control.new()
	bounty_overlay.name = "BountyOverlay"
	bounty_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bounty_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bounty_overlay)
	_bounty_overlay = bounty_overlay
	# 悬赏背景遮罩；使用与其他局外面板一致的深色透明层。
	var bounty_dim: ColorRect = ColorRect.new()
	bounty_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(bounty_dim)
	bounty_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	bounty_overlay.add_child(bounty_dim)
	# 悬赏面板；固定 840×560 像素并由独立组件维护悬赏卡与进度展示。
	var bounty_panel: Control = BOUNTY_PANEL_SCRIPT.new() as Control
	if bounty_panel == null:
		bounty_overlay.visible = false
		return
	bounty_panel.name = "BountyPanel"
	bounty_panel.anchor_left = 0.5
	bounty_panel.anchor_top = 0.5
	bounty_panel.anchor_right = 0.5
	bounty_panel.anchor_bottom = 0.5
	bounty_panel.offset_left = -420.0
	bounty_panel.offset_top = -280.0
	bounty_panel.offset_right = 420.0
	bounty_panel.offset_bottom = 280.0
	bounty_panel.connect("closed", Callable(self, "_on_bounty_closed"))
	bounty_overlay.add_child(bounty_panel)
	_bounty_panel = bounty_panel
	bounty_overlay.visible = false


func _build_stats_overlay() -> void:
	if _stats_overlay != null:
		return
	# 统计遮罩；覆盖完整主菜单并拦截输入，关闭时只隐藏界面，统计采集由后台服务持续进行。
	var stats_overlay: Control = Control.new()
	stats_overlay.name = "StatsOverlay"
	stats_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(stats_overlay)
	_stats_overlay = stats_overlay
	# 统计背景遮罩；使用与其他局外面板一致的深色透明层。
	var stats_dim: ColorRect = ColorRect.new()
	stats_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(stats_dim)
	stats_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_overlay.add_child(stats_dim)
	# 统计面板；固定 880×600 像素并由独立组件维护统计分区与财富曲线。
	var stats_panel: Control = STATS_PANEL_SCRIPT.new() as Control
	if stats_panel == null:
		stats_overlay.visible = false
		return
	stats_panel.name = "StatsPanel"
	stats_panel.anchor_left = 0.5
	stats_panel.anchor_top = 0.5
	stats_panel.anchor_right = 0.5
	stats_panel.anchor_bottom = 0.5
	stats_panel.offset_left = -440.0
	stats_panel.offset_top = -300.0
	stats_panel.offset_right = 440.0
	stats_panel.offset_bottom = 300.0
	stats_panel.connect("closed", Callable(self, "_on_stats_closed"))
	stats_overlay.add_child(stats_panel)
	_stats_panel = stats_panel
	stats_overlay.visible = false


func _build_hack_mode_overlay() -> void:
	if _hack_mode_overlay != null:
		return
	# 骇入模式遮罩；覆盖完整主菜单并拦截输入，选择模式或返回后隐藏。
	var hack_mode_overlay: Control = Control.new()
	hack_mode_overlay.name = "HackModeOverlay"
	hack_mode_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hack_mode_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(hack_mode_overlay)
	_hack_mode_overlay = hack_mode_overlay
	# 骇入模式背景遮罩；使用与其他局外面板一致的深色透明层。
	var hack_mode_dim: ColorRect = ColorRect.new()
	hack_mode_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(hack_mode_dim)
	hack_mode_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	hack_mode_overlay.add_child(hack_mode_dim)
	# 骇入模式选择面板；固定 680×560 像素，战斗模式与娱乐模式分组展示全部可选骇入模式。
	var hack_mode_panel: Control = HACK_MODE_SELECT_PANEL_SCRIPT.new() as Control
	if hack_mode_panel == null:
		hack_mode_overlay.visible = false
		return
	hack_mode_panel.name = "HackModeSelectPanel"
	# 初始成长资格；面板进入场景树前注入，避免新档首帧短暂显示可进入的娱乐模式按钮。
	if hack_mode_panel.has_method("configure_first_successful_extraction_unlock"):
		hack_mode_panel.call("configure_first_successful_extraction_unlock", _has_completed_first_successful_extraction(), FIRST_SUCCESSFUL_EXTRACTION_UNLOCK_TOOLTIP)
	hack_mode_panel.anchor_left = 0.5
	hack_mode_panel.anchor_top = 0.5
	hack_mode_panel.anchor_right = 0.5
	hack_mode_panel.anchor_bottom = 0.5
	hack_mode_panel.offset_left = -340.0
	hack_mode_panel.offset_top = -280.0
	hack_mode_panel.offset_right = 340.0
	hack_mode_panel.offset_bottom = 280.0
	hack_mode_panel.connect("mode_selected", Callable(self, "_on_hack_mode_selected"))
	hack_mode_panel.connect("closed", Callable(self, "_on_hack_mode_select_closed"))
	hack_mode_overlay.add_child(hack_mode_panel)
	_hack_mode_panel = hack_mode_panel
	hack_mode_overlay.visible = false


func _build_mode_extension_overlay() -> void:
	## 构建单人模式扩展遮罩；骇入模式选择完成后显示，配置确认或返回时隐藏并复用。
	if _mode_extension_overlay != null:
		return
	# 模式扩展遮罩；覆盖完整主菜单并拦截鼠标输入。
	var mode_extension_overlay: Control = Control.new()
	mode_extension_overlay.name = "ModeExtensionOverlay"
	mode_extension_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_extension_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mode_extension_overlay)
	_mode_extension_overlay = mode_extension_overlay
	# 模式扩展背景遮罩；使用与其他局外窗口一致的深色透明层。
	var mode_extension_dim: ColorRect = ColorRect.new()
	mode_extension_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(mode_extension_dim)
	mode_extension_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	mode_extension_overlay.add_child(mode_extension_dim)
	# 模式扩展选择面板；固定 780×620 像素，容纳扩展卡、四项风险词条与底部校验提示。
	var mode_extension_panel: Control = MODE_EXTENSION_SELECT_PANEL_SCRIPT.new() as Control
	if mode_extension_panel == null:
		mode_extension_overlay.visible = false
		return
	mode_extension_panel.name = "ModeExtensionSelectPanel"
	mode_extension_panel.anchor_left = 0.5
	mode_extension_panel.anchor_top = 0.5
	mode_extension_panel.anchor_right = 0.5
	mode_extension_panel.anchor_bottom = 0.5
	mode_extension_panel.offset_left = -390.0
	mode_extension_panel.offset_top = -310.0
	mode_extension_panel.offset_right = 390.0
	mode_extension_panel.offset_bottom = 310.0
	mode_extension_panel.connect("configuration_confirmed", Callable(self, "_on_mode_extension_configuration_confirmed"))
	mode_extension_panel.connect("closed", Callable(self, "_on_mode_extension_select_closed"))
	mode_extension_overlay.add_child(mode_extension_panel)
	_mode_extension_panel = mode_extension_panel
	mode_extension_overlay.visible = false


func _on_bounty_closed() -> void:
	if _bounty_overlay != null:
		_bounty_overlay.visible = false
	_bounty_button.grab_focus()


func _on_stats_closed() -> void:
	if _stats_overlay != null:
		_stats_overlay.visible = false
	_statistics_category_button.grab_focus()


func _build_developer_overlay() -> void:
	if _developer_overlay != null:
		return
	# 开发者遮罩；覆盖完整主菜单并拦截鼠标输入，默认保持隐藏。
	var developer_overlay: Control = Control.new()
	developer_overlay.name = "DeveloperOverlay"
	developer_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	developer_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(developer_overlay)
	_developer_overlay = developer_overlay
	# 开发者背景遮罩；使用深色半透明背景突出隐藏调试菜单。
	var developer_dim: ColorRect = ColorRect.new()
	developer_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI_STYLE_GUIDE.apply_overlay_dim(developer_dim)
	developer_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	developer_overlay.add_child(developer_dim)
	# 开发者菜单面板；居中显示资源与星穹快捷操作。
	var developer_menu: Control = DEVELOPER_MENU_SCRIPT.new() as Control
	developer_menu.anchor_left = 0.5
	developer_menu.anchor_top = 0.5
	developer_menu.anchor_right = 0.5
	developer_menu.anchor_bottom = 0.5
	developer_menu.offset_left = -260.0
	developer_menu.offset_top = -285.0
	developer_menu.offset_right = 260.0
	developer_menu.offset_bottom = 285.0
	developer_menu.connect("closed", Callable(self, "_on_developer_menu_closed"))
	developer_overlay.add_child(developer_menu)
	_developer_menu = developer_menu
	developer_overlay.visible = false


func _open_developer_menu() -> void:
	if _developer_overlay == null:
		return
	_settings_panel.visible = false
	if _warehouse_overlay != null:
		_warehouse_overlay.visible = false
	if _shop_overlay != null:
		_shop_overlay.visible = false
	if _forge_overlay != null:
		_forge_overlay.visible = false
	if _stock_market_overlay != null:
		_stock_market_overlay.visible = false
	if _stock_market_panel != null and _stock_market_panel.has_method("set_market_display_active"):
		_stock_market_panel.call("set_market_display_active", false)
	if _mining_farm_overlay != null:
		_mining_farm_overlay.visible = false
	if _mining_farm_panel != null and _mining_farm_panel.has_method("_close_panel"):
		_mining_farm_panel.call("_close_panel")
	if _insurance_overlay != null:
		_insurance_overlay.visible = false
	if _bank_overlay != null:
		_bank_overlay.visible = false
	if _hideout_overlay != null:
		_hideout_overlay.visible = false
	if _dispatch_overlay != null:
		_dispatch_overlay.visible = false
	if _encyclopedia_overlay != null:
		_encyclopedia_overlay.visible = false
	if _bounty_overlay != null:
		_bounty_overlay.visible = false
	if _stats_overlay != null:
		_stats_overlay.visible = false
	if _hack_mode_overlay != null:
		_hack_mode_overlay.visible = false
	if _mode_extension_overlay != null:
		_mode_extension_overlay.visible = false
	_developer_overlay.visible = true


func _on_developer_menu_closed() -> void:
	if _developer_overlay != null:
		_developer_overlay.visible = false
	_start_button.grab_focus()


func _on_warehouse_closed() -> void:
	if _warehouse_overlay != null:
		_warehouse_overlay.visible = false
	_warehouse_button.grab_focus()


func _on_backpack_closed() -> void:
	if _backpack_overlay != null:
		_backpack_overlay.visible = false
	_backpack_button.grab_focus()


func _on_backpack_warehouse_requested() -> void:
	## 从局外背包一键切换到仓库；复用已有两个遮罩与面板实例，不重复创建库存界面。
	if _backpack_overlay != null:
		_backpack_overlay.visible = false
	_on_warehouse_button_pressed()


func _on_shop_closed() -> void:
	if _shop_overlay != null:
		_shop_overlay.visible = false
	_shop_button.grab_focus()


func _on_forge_closed() -> void:
	if _forge_overlay != null:
		_forge_overlay.visible = false
	_forge_button.grab_focus()


func _on_stock_market_closed() -> void:
	if _stock_market_overlay != null:
		_stock_market_overlay.visible = false
	if _stock_market_panel != null and _stock_market_panel.has_method("set_market_display_active"):
		_stock_market_panel.call("set_market_display_active", false)
	_finance_category_button.grab_focus()


func _on_mining_farm_closed() -> void:
	if _mining_farm_overlay != null:
		_mining_farm_overlay.visible = false
	_finance_category_button.grab_focus()


func _on_insurance_closed() -> void:
	if _insurance_overlay != null:
		_insurance_overlay.visible = false
	_finance_category_button.grab_focus()


func _on_bank_closed() -> void:
	if _bank_overlay != null:
		_bank_overlay.visible = false
	_finance_category_button.grab_focus()


func _on_hideout_closed() -> void:
	if _hideout_overlay != null:
		_hideout_overlay.visible = false
	_hideout_button.grab_focus()


func _on_dispatch_closed() -> void:
	if _dispatch_overlay != null:
		_dispatch_overlay.visible = false
	_dispatch_button.grab_focus()


func _on_encyclopedia_closed() -> void:
	if _encyclopedia_overlay != null:
		_encyclopedia_overlay.visible = false
	_statistics_category_button.grab_focus()


func _on_master_volume_slider_value_changed(value: float) -> void:
	_apply_master_volume(value)


func _on_settings_back_button_pressed() -> void:
	if _is_key_binding_page_visible():
		_show_key_binding_page(false)
		return

	_settings_panel.visible = false
	_settings_button.grab_focus()


func _start_game(game_mode: String) -> void:
	## 写入本次模式并直接进入战斗；角色由独立角色系统最后确认的 SessionState 选择提供。
	_settings_panel.visible = false
	_set_session_game_mode(game_mode)
	# 训练场变体复位；训练入口显式把骇入模式变体重置为标准值，避免上一局零装或超频规则残留。
	if game_mode == GAME_MODE_TRAINING:
		# 会话状态节点；缺失时训练场按 GameWorld 的训练判定自动回退标准变体。
		var session_state: Node = get_tree().root.get_node_or_null("SessionState")
		if session_state != null and session_state.has_method("set_hack_variant"):
			session_state.call("set_hack_variant", "standard")
		if session_state != null and session_state.has_method("clear_mode_extensions"):
			session_state.call("clear_mode_extensions")
	_change_scene_with_transition(game_scene_path)


func _change_scene_with_transition(scene_path: String) -> void:
	# 全局转场服务；默认由 AutoLoad 提供，缺失时回退引擎直接切换以保留场景独立运行能力。
	var scene_transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_to_file"):
		scene_transition.call("change_scene_to_file", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _set_session_game_mode(game_mode: String) -> void:
	# 会话状态节点；默认由 project.godot 自动加载，缺失时直接跳过配置以保留场景兜底能力。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state == null:
		return

	if session_state.has_method("set_game_mode"):
		session_state.call("set_game_mode", game_mode)
	elif session_state.has_method("configure"):
		session_state.call("configure", game_mode, str(session_state.get("selected_character_id")))


func _sync_master_volume_slider() -> void:
	if _master_bus_index < 0:
		return

	# 当前 Master 音量线性值；取值为 0 到 1，默认由 AudioServer 读取，修改会影响设置滑条初始位置。
	var linear_volume: float = 0.0 if AudioServer.is_bus_mute(_master_bus_index) else db_to_linear(AudioServer.get_bus_volume_db(_master_bus_index))
	_master_volume_slider.set_value_no_signal(clampf(linear_volume, 0.0, 1.0) * 100.0)
	_refresh_master_volume_label(_master_volume_slider.value)


func _apply_master_volume(value: float) -> void:
	if _master_bus_index < 0:
		return

	# 标准化音量值；取值为 0 到 1，默认由滑条百分比换算，修改会影响最终写入 AudioServer 的音量。
	var linear_volume: float = clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(_master_bus_index, linear_volume <= 0.001)
	if linear_volume > 0.001:
		AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(linear_volume))

	_refresh_master_volume_label(value)


func _refresh_master_volume_label(value: float) -> void:
	_master_volume_value_label.text = "%d%%" % roundi(value)


func _build_key_binding_navigation() -> void:
	if _settings_content == null:
		return

	if _key_binding_page != null:
		return

	# UI 风格选择组件；放在主音量行之后，所有选项名称、保存和全局刷新都由组件与服务共同维护。
	var ui_style_selector: Control = UI_STYLE_SELECTOR_SCRIPT.new() as Control
	if ui_style_selector != null:
		ui_style_selector.name = "MainMenuUiStyleSelector"
		_settings_content.add_child(ui_style_selector)
		_settings_content.move_child(ui_style_selector, _master_volume_row.get_index() + 1)
		_ui_style_selector = ui_style_selector

	# 横幅通知开关组件；放在 UI 风格行之后，开关状态由横幅通知服务统一校验、保存和应用。
	var banner_notification_toggle: Control = BANNER_NOTIFICATION_TOGGLE_SCRIPT.new() as Control
	if banner_notification_toggle != null:
		banner_notification_toggle.name = "MainMenuBannerNotificationToggle"
		_settings_content.add_child(banner_notification_toggle)
		# 开关插入锚点；UI 风格行缺失时回退到主音量行之后，保证设置首页顺序稳定。
		var toggle_anchor_index: int = (_ui_style_selector.get_index() if _ui_style_selector != null else _master_volume_row.get_index()) + 1
		_settings_content.move_child(banner_notification_toggle, toggle_anchor_index)
		_banner_notification_toggle = banner_notification_toggle

	# 按键绑定入口按钮；取值为 Button，默认放在设置首页用于进入独立按键绑定页面。
	var key_binding_button: Button = Button.new()
	key_binding_button.name = "KeyBindingPageButton"
	key_binding_button.custom_minimum_size = Vector2(0.0, 42.0)
	key_binding_button.text = "按键绑定"
	key_binding_button.pressed.connect(_on_key_binding_button_pressed)
	_settings_content.add_child(key_binding_button)
	_settings_content.move_child(key_binding_button, maxi(_settings_content.get_child_count() - 3, 0))
	_key_binding_button = key_binding_button
	# 存档传输控件；主菜单导出可覆盖全部已经落盘的永久状态，导入由服务自动备份旧文件。
	# 删除功能补充；危险删除入口由复用控件内部创建，主菜单不直接访问任何 user:// 文件。
	var save_transfer_control: Control = SAVE_TRANSFER_CONTROL_SCRIPT.new() as Control
	if save_transfer_control != null:
		save_transfer_control.name = "MainMenuSaveTransferControl"
		_settings_content.add_child(save_transfer_control)
		_settings_content.move_child(save_transfer_control, maxi(_settings_content.get_child_count() - 3, 0))
		_save_transfer_control = save_transfer_control
	_settings_home_controls = [
		_settings_title_label,
		_master_volume_row,
		_ui_style_selector,
		_banner_notification_toggle,
		_key_binding_button,
		_save_transfer_control,
		_settings_spacer,
		_settings_back_button,
	]

	# 按键绑定页面；取值为 VBoxContainer，默认隐藏并在点击入口按钮时显示。
	var key_binding_page: VBoxContainer = VBoxContainer.new()
	key_binding_page.name = "KeyBindingPage"
	key_binding_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	key_binding_page.add_theme_constant_override("separation", 10)
	_settings_content.add_child(key_binding_page)
	_key_binding_page = key_binding_page

	# 按键绑定面板；取值为 KeyBindingPanel 实例，默认只在按键绑定页面内显示。
	var key_binding_panel: Control = KEY_BINDING_PANEL_SCRIPT.new() as Control
	if key_binding_panel == null:
		return

	key_binding_panel.name = "MainMenuKeyBindingPanel"
	key_binding_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_key_binding_page.add_child(key_binding_panel)
	_key_binding_panel = key_binding_panel

	# 按键绑定返回按钮；取值为 Button，默认从按键绑定页面回到设置首页。
	var key_binding_back_button: Button = Button.new()
	key_binding_back_button.name = "KeyBindingBackButton"
	key_binding_back_button.custom_minimum_size = Vector2(0.0, 42.0)
	key_binding_back_button.text = "返回"
	key_binding_back_button.pressed.connect(_on_key_binding_back_button_pressed)
	_key_binding_page.add_child(key_binding_back_button)
	_key_binding_back_button = key_binding_back_button


func _show_key_binding_page(visible: bool) -> void:
	# 首页控件遍历项；取值为设置首页的直接控件，默认与按键绑定页面互斥显示。
	for home_control in _settings_home_controls:
		if home_control != null:
			home_control.visible = not visible

	if _key_binding_page != null:
		_key_binding_page.visible = visible

	if visible and _key_binding_back_button != null:
		_key_binding_back_button.grab_focus()
	elif _settings_back_button != null:
		_settings_back_button.grab_focus()


func _is_key_binding_page_visible() -> bool:
	return _key_binding_page != null and _key_binding_page.visible


func _on_key_binding_button_pressed() -> void:
	_show_key_binding_page(true)


func _on_key_binding_back_button_pressed() -> void:
	_show_key_binding_page(false)
