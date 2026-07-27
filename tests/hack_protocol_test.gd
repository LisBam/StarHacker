extends Node

## 骇入协议专项自动验证覆盖规则表、模式配置、战斗组件、HUD 长按入口、非暂停窗口与碎片溢出。
## 测试通过独立场景运行，不写入项目资源或永久存档；任一断言失败会以非零退出码结束。

## 正式战斗场景；用于验证真实玩家、GameWorld 与 CombatHud 的动态组件接线。
const GAME_WORLD_SCENE: PackedScene = preload("res://scenes/game/game_world.tscn")
## 用户指定的协议说明顺序；逐项与规则表比对，防止 UI 文案再次加入额外限定词或改写句式。
const EXPECTED_PROTOCOL_DESCRIPTIONS: Array[String] = [
	"每次击杀敌人回复8点能量。",
	"所有武器弹射+1。",
	"所有武器穿透+1。",
	"所有武器连击+1。",
	"所有武器散射+1。",
	"攻击力+12%。",
	"防御力+15%。",
	"速度+10%。",
	"生命上限+15%。",
	"能量上限+15%。",
	"造成的伤害+10%。",
	"受到的伤害降低8%。",
	"击杀敌人的物品掉落概率+12%。",
	"击杀敌人回复6点生命值。",
	"闪避消耗的能量-20%。",
	"冲刺消耗的能量-20%。",
	"击杀敌人缩短主动技能10%的冷却。",
	"攻速+12%。",
	"暴击率+8%。",
	"暴击伤害+30%。",
	"生命值低于30%时获得18（+10%最大生命值）的护盾。",
	"冲刺后获得2秒的20%减伤。",
	"受到伤害回复7点能量。",
	"当能量高于70%时提高15%的伤害。",
	"将溢出的50%的治疗转化为持续6秒的护盾。",
	"持有护盾时，伤害提高15%。",
	"护盾被击破时击退周围的敌人。",
	"对生命值低于30%的敌人造成的伤害提高25%。",
	"弹体未命中敌人时，返回40%的能耗。",
	"生命值低于30%时，攻速提高25%。",
	"对满血敌人造成的伤害必定暴击。",
]

## 当前失败数量；默认 0，每个失败断言加一并在测试结束时作为退出码依据。
var _failure_count: int = 0


func _ready() -> void:
	## 顺序执行纯规则与真实场景验证；协程等待确保动态子节点完成 ready。
	_test_rule_table()
	_test_mode_extension_configuration()
	await _test_runtime_flow()
	# 会话清理；防止编辑器中手动运行测试后下一次进入战斗仍保留测试扩展。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	if session_state != null and session_state.has_method("clear_mode_extensions"):
		session_state.call("clear_mode_extensions")
	if _failure_count > 0:
		push_error("骇入协议专项测试失败：%d 项。" % _failure_count)
		get_tree().quit(1)
		return
	print("HACK_PROTOCOL_TEST_PASS")
	get_tree().quit(0)


func _test_rule_table() -> void:
	## 验证 31 项协议、候选唯一性、碎片成长和动态团队代价的策划常量。
	# 全部协议定义；用户需求当前固定列出 31 项，数量变化必须同步更新测试与权威玩法文档。
	var definitions: Array[Dictionary] = HackProtocolRules.get_protocol_definitions()
	_check(definitions.size() == 31, "协议规则表应包含 31 项定义。")
	_check(definitions.size() == EXPECTED_PROTOCOL_DESCRIPTIONS.size(), "协议定义与指定说明数量必须一致。")
	# 已见协议 ID；用于验证规则表没有重复稳定标识。
	var seen_protocol_ids: Dictionary = {}
	for definition_index in range(definitions.size()):
		# 当前协议定义；按规则表稳定顺序与用户指定文案逐项比对。
		var protocol_definition: Dictionary = definitions[definition_index]
		# 当前协议 ID；必须非空且全表唯一，网络和局内组件均依赖该稳定值。
		var protocol_id: String = str(protocol_definition.get("id", ""))
		_check(not protocol_id.is_empty(), "协议 ID 不得为空。")
		_check(not seen_protocol_ids.has(protocol_id), "协议 ID 不得重复：%s。" % protocol_id)
		seen_protocol_ids[protocol_id] = true
		_check(not str(protocol_definition.get("display_name", "")).is_empty(), "协议名称不得为空：%s。" % protocol_id)
		_check(str(protocol_definition.get("description", "")) == EXPECTED_PROTOCOL_DESCRIPTIONS[definition_index], "协议说明必须严格匹配指定句式：%s。" % protocol_id)
	# 固定随机源；相同种子应稳定产生三个候选，候选内部不得重复。
	var offer_random: RandomNumberGenerator = RandomNumberGenerator.new()
	offer_random.seed = 20260727
	# 三选一候选；规则表负责无放回抽取。
	var offer_ids: Array[String] = HackProtocolRules.roll_offer_ids(offer_random)
	_check(offer_ids.size() == HackProtocolRules.OFFER_COUNT, "每次应生成 3 个协议候选。")
	_check(offer_ids.duplicate().all(func(protocol_id: String) -> bool: return offer_ids.count(protocol_id) == 1), "同一批协议候选不得重复。")
	_check(is_equal_approx(HackProtocolRules.get_fragment_requirement(0), 100.0), "首次协议需求应为 100 碎片。")
	_check(is_equal_approx(HackProtocolRules.get_fragment_requirement(1), 175.0), "第二次协议需求应为 175 碎片。")
	_check(is_equal_approx(HackProtocolRules.SURVIVAL_FRAGMENT_AMOUNT, 2.0), "每 5 秒存活奖励应翻倍为 2 碎片。")
	_check(is_equal_approx(HackProtocolRules.KILL_FRAGMENT_AMOUNT, 6.0), "最终击杀奖励应翻倍为 6 碎片。")
	_check(is_equal_approx(HackProtocolRules.CHEST_FRAGMENT_AMOUNT, 36.0), "开箱奖励应翻倍为 36 碎片。")
	_check(is_equal_approx(HackProtocolRules.get_population_multiplier(0.0), 1.0), "0 层协议不得提前增加怪物。")
	_check(is_equal_approx(HackProtocolRules.get_population_multiplier(2.0), 1.24), "团队平均 2 层协议应增加 24% 怪物。")
	_check(is_equal_approx(HackProtocolRules.get_population_multiplier(99.0), 1.72), "协议怪物增幅应封顶 72%。")
	_check(is_equal_approx(HackProtocolRules.get_drop_chance_multiplier(0.0), 1.0), "0 层协议不得提前降低掉落。")
	_check(is_equal_approx(HackProtocolRules.get_drop_chance_multiplier(2.0), 0.86), "团队平均 2 层协议应降低 14% 掉落。")
	_check(is_equal_approx(HackProtocolRules.get_drop_chance_multiplier(99.0), 0.65), "协议掉落倍率最低应保留 65%。")
	# 临时护盾验证组件；先建立 40 点永久护盾，再追加 50 点限时来源。
	var shield_component: ShieldComponent = ShieldComponent.new()
	add_child(shield_component)
	shield_component.call("configure_shield", 40.0, true)
	shield_component.call("add_shield", 50.0, true)
	shield_component.call("absorb_damage", 20.0)
	shield_component.call("remove_temporary_shield", 30.0, 50.0)
	_check(is_equal_approx(float(shield_component.get("current_shield")), 40.0), "限时护盾承伤后到期不得重复扣除永久护盾。")
	_check(is_equal_approx(float(shield_component.get("max_shield")), 40.0), "限时护盾到期应回收创建时增加的完整上限。")
	shield_component.queue_free()


func _test_mode_extension_configuration() -> void:
	## 验证骇入协议可独立启用，且不会被风险合约“必须选择词条”的校验误删。
	# 标准骇入配置；仅启用骇入协议且不选择风险词条。
	var standard_configuration: Dictionary = ModeExtensionRules.sanitize_configuration([ModeExtensionRules.EXTENSION_HACK_PROTOCOL], [], HackModeRules.VARIANT_STANDARD)
	_check((standard_configuration.get("extension_ids", []) as Array).has(ModeExtensionRules.EXTENSION_HACK_PROTOCOL), "标准骇入应允许独立启用骇入协议。")
	# 超频配置；骇入协议没有永久结算奖励，因此允许在无结算娱乐变体运行。
	var overclock_configuration: Dictionary = ModeExtensionRules.sanitize_configuration([ModeExtensionRules.EXTENSION_HACK_PROTOCOL], [], HackModeRules.VARIANT_OVERCLOCK)
	_check((overclock_configuration.get("extension_ids", []) as Array).has(ModeExtensionRules.EXTENSION_HACK_PROTOCOL), "超频骇入应保留骇入协议扩展。")
	_check(ModeExtensionRules.get_configuration_summary([ModeExtensionRules.EXTENSION_HACK_PROTOCOL], []).contains("骇入协议"), "模式扩展摘要应显示骇入协议。")
	# 撤离点风险词条定义；稳定 ID、类别、单出口数量与掉落补偿必须由规则表统一提供。
	var extraction_risk_definition: Dictionary = ModeExtensionRules.get_risk_definition("extraction_points_one")
	_check(str(extraction_risk_definition.get("family", "")) == ModeExtensionRules.FAMILY_EXTRACTION, "撤离点风险词条必须属于独立撤离类别。")
	_check(int(extraction_risk_definition.get("extraction_point_count", 0)) == 1, "撤离点风险词条必须将本局正式撤离点限制为 1 个。")
	_check(is_equal_approx(float(extraction_risk_definition.get("drop_bonus_ratio", 0.0)), 0.35), "撤离点风险词条的怪物掉落加成必须为 35%。")
	# 撤离点风险效果汇总；普通配置保持中性值，启用词条后只覆盖撤离点数量字段。
	var neutral_risk_effects: Dictionary = ModeExtensionRules.get_effect_multipliers([])
	var extraction_risk_effects: Dictionary = ModeExtensionRules.get_effect_multipliers(["extraction_points_one"])
	_check(int(neutral_risk_effects.get("extraction_point_count", -1)) == 0, "未启用撤离点风险时数量覆盖字段必须保持中性值。")
	_check(int(extraction_risk_effects.get("extraction_point_count", 0)) == 1, "已启用撤离点风险时汇总字段必须为 1。")


func _test_runtime_flow() -> void:
	## 在真实战斗场景验证组件创建、满碎片提示、三秒长按、非暂停窗口和两阶段溢出结算。
	# 会话状态；配置禁用正式结算的超频协议与骇入协议，确保自动测试不会写入永久战绩。
	var session_state: Node = get_tree().root.get_node_or_null("SessionState")
	_check(session_state != null, "测试需要 SessionState 自动加载。")
	if session_state == null:
		return
	session_state.call("set_game_mode", "hack")
	session_state.call("set_hack_variant", HackModeRules.VARIANT_OVERCLOCK)
	session_state.call("configure_mode_extensions", [ModeExtensionRules.EXTENSION_HACK_PROTOCOL], [])
	# 战斗世界实例；真实执行 GameWorld、玩家和 CombatHud 的 ready 顺序。
	var game_world: Node = GAME_WORLD_SCENE.instantiate()
	add_child(game_world)
	await get_tree().process_frame
	await get_tree().process_frame
	# 常规撤离点布局；生存时间达到 120 秒后固定生成 3 个点位，候选选择优先满足 4000 像素最近间距。
	game_world.call("add_training_survival_time")
	game_world.call("add_training_survival_time")
	var extraction_positions: Array = game_world.call("get_extraction_point_positions") as Array
	_check(extraction_positions.size() == 3, "常规局达到撤离时间后必须生成 3 个正式撤离点。")
	if extraction_positions.size() == 3:
		# 三点两两距离；默认地图应满足配置的优先最小间距，验证远距分布不会退化为相邻出口。
		var preferred_spacing: float = float(game_world.get("extraction_point_preferred_minimum_spacing"))
		for first_index in range(extraction_positions.size()):
			for second_index in range(first_index + 1, extraction_positions.size()):
				var first_position: Vector2 = extraction_positions[first_index] as Vector2
				var second_position: Vector2 = extraction_positions[second_index] as Vector2
				_check(first_position.distance_to(second_position) >= preferred_spacing, "常规撤离点应优先保持配置的远距分布。")
	# 风险覆盖接口；同一规则字典传入时，GameWorld 必须把常规三出口覆盖为单出口目标。
	var extraction_risk_effects: Dictionary = ModeExtensionRules.get_effect_multipliers(["extraction_points_one"])
	game_world.set("_mode_extension_effect_multipliers", extraction_risk_effects)
	_check(int(game_world.call("_get_effective_extraction_point_count")) == 1, "撤离点风险合约必须覆盖正式撤离点目标数量。")
	# 玩家协议组件；必须由 GameWorld 动态挂载且只存在于本局玩家节点。
	var protocol_component: Node = game_world.call("get_hack_protocol_component") as Node
	_check(protocol_component != null, "启用扩展后应创建玩家骇入协议组件。")
	if protocol_component == null:
		game_world.queue_free()
		return
	# 战斗 HUD 与进度分区；扩展启用时进度条必须可见。
	var combat_hud: Node = game_world.get_node_or_null("BattleHUD")
	# 数据碎片分区；固定插入生命能量面板上方。
	var progress_panel: Control = game_world.get_node_or_null("BattleHUD/Root/BottomDock/HackProtocolProgressPanel") as Control
	_check(combat_hud != null, "战斗场景应包含 CombatHud。")
	_check(progress_panel != null and progress_panel.visible, "启用扩展后数据碎片进度条应显示。")
	# 风险合约查看入口；本局没有启用该扩展，暂停主页必须保持隐藏。
	var risk_view_button: Button = game_world.get_node_or_null("BattleHUD/Root/PauseOverlay/RiskContractViewButton") as Button
	# 骇入协议查看入口；本局显式启用该扩展，暂停主页必须显示并独占居中位置。
	var hack_view_button: Button = game_world.get_node_or_null("BattleHUD/Root/PauseOverlay/HackProtocolViewButton") as Button
	if combat_hud != null:
		combat_hud.call("_set_pause_menu_visible", true)
	_check(risk_view_button != null and not risk_view_button.visible, "未启用的风险合约不得显示在暂停菜单左侧。")
	_check(hack_view_button != null and hack_view_button.visible, "已启用的骇入协议应显示在暂停菜单左侧。")
	if combat_hud != null:
		combat_hud.call("_set_pause_menu_visible", false)
	protocol_component.call("add_fragments", 250.0)
	_check(bool(protocol_component.call("is_offer_ready")), "达到 100 碎片后应固定生成三项候选。")
	# 选择遮罩；碎片刚满时必须保持隐藏，证明系统没有立即弹窗。
	var selection_overlay: Control = game_world.get_node_or_null("BattleHUD/Root/HackProtocolSelectOverlay") as Control
	_check(selection_overlay != null and not selection_overlay.visible, "碎片攒满后不应立即弹出选择窗口。")
	if combat_hud != null:
		Input.action_press("select_hack_protocol")
		combat_hud.call("_update_hack_protocol_hold", HackProtocolRules.HOLD_DURATION_SECONDS)
		Input.action_release("select_hack_protocol")
	_check(selection_overlay != null and selection_overlay.visible, "持续按住选择键 3 秒后应打开协议窗口。")
	_check(not get_tree().paused, "骇入协议选择窗口打开期间不得暂停游戏。")
	if combat_hud != null:
		combat_hud.call("_close_hack_protocol_select")
	# 第一阶段选择；250 碎片扣除 100 后保留 150 溢出，下一阶段需求变为 175。
	var first_offer_ids: Array[String] = HackProtocolRules.normalize_protocol_ids(protocol_component.call("get_offer_ids") as Array)
	_check(not first_offer_ids.is_empty() and bool(protocol_component.call("select_protocol", first_offer_ids[0])), "应能从固定候选中获得第一项协议。")
	_check(is_equal_approx(float(protocol_component.call("get_current_fragments")), 150.0), "第一项协议选择后应保留 150 点溢出碎片。")
	_check(is_equal_approx(float(protocol_component.call("get_required_fragments")), 175.0), "获得一项协议后需求应提高到 175。")
	_check(not bool(protocol_component.call("is_offer_ready")), "150 点溢出不足 175 时不应提前生成下一批候选。")
	protocol_component.call("add_fragments", 25.0)
	_check(bool(protocol_component.call("is_offer_ready")), "补足 25 点后应生成下一批三选一。")
	# 动态人口倍率；超频基础 2 倍与第 1 层协议 1.12 倍共同作用，开局 0 层仍不会承担协议代价。
	var scaled_population: int = int(game_world.call("_apply_population_scales", 100))
	_check(scaled_population == 224, "超频下单人获得 1 层协议后基础人口 100 应动态变为 224。")
	# 第二阶段选择；175 点正好扣清，第三阶段需求为 250。
	var second_offer_ids: Array[String] = HackProtocolRules.normalize_protocol_ids(protocol_component.call("get_offer_ids") as Array)
	_check(not second_offer_ids.is_empty() and bool(protocol_component.call("select_protocol", second_offer_ids[0])), "应能获得第二项协议。")
	_check(is_zero_approx(float(protocol_component.call("get_current_fragments"))), "第二阶段正好支付 175 后碎片应归零。")
	_check(is_equal_approx(float(protocol_component.call("get_required_fragments")), 250.0), "获得两项协议后下一需求应为 250。")
	game_world.queue_free()
	await get_tree().process_frame


func _check(condition: bool, failure_message: String) -> void:
	## 记录单条验证结果；不中断后续断言，便于一次运行暴露全部回归点。
	if condition:
		return
	_failure_count += 1
	push_error(failure_message)
