extends RefCounted
class_name HackProtocolRules

## 骇入协议规则表集中声明数据碎片成长、随机候选、协议数值与动态模式代价。
## 运行期组件、选择窗口、只读查看面板和多人同步只交换稳定 ID 或读取本表，
## 不在各自脚本中复制名称、说明和具体数值，确保数值策划只维护一个事实来源。

## 每次选择展示的随机候选数量；固定为 3，候选内部不重复但允许已经获得的协议再次出现并叠加。
const OFFER_COUNT: int = 3
## 打开协议选择窗口所需持续按住时间；默认 3 秒，松开、界面受阻或碎片不足都会清空本次进度。
const HOLD_DURATION_SECONDS: float = 3.0
## 首次获得协议需要的数据碎片；默认 100，配合翻倍后的三类来源使正常战斗约 0.75 至 1.25 分钟出现第一次选择。
const BASE_FRAGMENT_REQUIREMENT: float = 100.0
## 每获得一项协议后增加的碎片需求；默认每层 +75，控制中后期协议成长速度不会失控。
const FRAGMENT_REQUIREMENT_INCREMENT: float = 75.0
## 存活获得碎片的时间间隔；默认每 5 秒结算一次，死亡和结算状态不累计。
const SURVIVAL_FRAGMENT_INTERVAL_SECONDS: float = 5.0
## 每个完整存活结算间隔获得的碎片；默认 2 点，是原效率的两倍并作为不依赖击杀能力的保底来源。
const SURVIVAL_FRAGMENT_AMOUNT: float = 2.0
## 本机确认击杀一名敌人获得的碎片；默认 6 点，是原效率的两倍且多人模式只奖励最终击杀者。
const KILL_FRAGMENT_AMOUNT: float = 6.0
## 成功认领并释放一个宝箱获得的碎片；默认 36 点，是原效率的两倍且主动开启与击毁开启使用相同事实口径。
const CHEST_FRAGMENT_AMOUNT: float = 36.0
## 每个团队平均协议层级提供的目标怪物人口增幅；默认 +12%，协议数为 0 时严格保持中性值。
const POPULATION_BONUS_PER_AVERAGE_PROTOCOL: float = 0.12
## 骇入协议带来的目标怪物人口最大增幅；默认 +72%，防止长局人口和实体化上限无限增长。
const MAXIMUM_POPULATION_BONUS: float = 0.72
## 每个团队平均协议层级降低的怪物物品掉落率；默认 -7%，与额外击杀来源共同形成成长代价。
const DROP_REDUCTION_PER_AVERAGE_PROTOCOL: float = 0.07
## 骇入协议带来的怪物物品掉落率最大降幅；默认 -35%，保证长局仍有至少 65% 的原始掉落倍率。
const MAXIMUM_DROP_REDUCTION: float = 0.35

## 全部骇入协议定义；value、threshold、duration 等字段的含义由稳定 kind 决定。
## 同一协议重复获得时，数值型效果按层数加算；阈值、持续时间和布尔效果不会随层数改变。
const PROTOCOL_DEFINITIONS: Array[Dictionary] = [
	{"id": "kill_energy_restore", "display_name": "回收供能", "description": "每次击杀敌人回复8点能量。", "kind": "kill_energy_restore", "value": 8.0},
	{"id": "weapon_bounce_bonus", "display_name": "折返路由", "description": "所有武器弹射+1。", "kind": "weapon_bounce_bonus", "value": 1},
	{"id": "weapon_piercing_bonus", "display_name": "贯穿指令", "description": "所有武器穿透+1。", "kind": "weapon_piercing_bonus", "value": 1},
	{"id": "weapon_combo_bonus", "display_name": "连发覆写", "description": "所有武器连击+1。", "kind": "weapon_combo_bonus", "value": 1},
	{"id": "weapon_scatter_bonus", "display_name": "分形散射", "description": "所有武器散射+1。", "kind": "weapon_scatter_bonus", "value": 1},
	{"id": "attack_power_bonus", "display_name": "攻击增幅", "description": "攻击力+12%。", "kind": "attack_power_bonus", "value": 0.12},
	{"id": "defense_power_bonus", "display_name": "防御增幅", "description": "防御力+15%。", "kind": "defense_power_bonus", "value": 0.15},
	{"id": "move_speed_bonus", "display_name": "超频步进", "description": "速度+10%。", "kind": "move_speed_bonus", "value": 0.10},
	{"id": "max_health_bonus", "display_name": "生命扩容", "description": "生命上限+15%。", "kind": "max_health_bonus", "value": 0.15},
	{"id": "max_energy_bonus", "display_name": "能量扩容", "description": "能量上限+15%。", "kind": "max_energy_bonus", "value": 0.15},
	{"id": "outgoing_damage_bonus", "display_name": "输出增幅", "description": "造成的伤害+10%。", "kind": "outgoing_damage_bonus", "value": 0.10},
	{"id": "damage_reduction", "display_name": "损伤过滤", "description": "受到的伤害降低8%。", "kind": "damage_reduction", "value": 0.08},
	{"id": "kill_drop_chance_bonus", "display_name": "战利品嗅探", "description": "击杀敌人的物品掉落概率+12%。", "kind": "kill_drop_chance_bonus", "value": 0.12},
	{"id": "kill_health_restore", "display_name": "生命回收", "description": "击杀敌人回复6点生命值。", "kind": "kill_health_restore", "value": 6.0},
	{"id": "dodge_energy_reduction", "display_name": "冲刺节流", "description": "闪避消耗的能量-20%。", "kind": "dodge_energy_reduction", "value": 0.20},
	{"id": "sprint_energy_reduction", "display_name": "疾跑节流", "description": "冲刺消耗的能量-20%。", "kind": "sprint_energy_reduction", "value": 0.20},
	{"id": "kill_skill_cooldown_reduction", "display_name": "终止回路", "description": "击杀敌人缩短主动技能10%的冷却。", "kind": "kill_skill_cooldown_reduction", "value": 0.10},
	{"id": "attack_speed_bonus", "display_name": "攻速超频", "description": "攻速+12%。", "kind": "attack_speed_bonus", "value": 0.12},
	{"id": "critical_chance_bonus", "display_name": "暴击注入", "description": "暴击率+8%。", "kind": "critical_chance_bonus", "value": 0.08},
	{"id": "critical_damage_bonus", "display_name": "暴伤注入", "description": "暴击伤害+30%。", "kind": "critical_damage_bonus", "value": 0.30},
	{"id": "low_health_shield", "display_name": "濒危防火墙", "description": "生命值低于30%时获得18（+10%最大生命值）的护盾。", "kind": "low_health_shield", "threshold": 0.30, "flat_value": 18.0, "max_health_ratio": 0.10},
	{"id": "dodge_damage_reduction", "display_name": "冲刺残影", "description": "冲刺后获得2秒的20%减伤。", "kind": "dodge_damage_reduction", "duration": 2.0, "value": 0.20},
	{"id": "damage_energy_restore", "display_name": "受击充能", "description": "受到伤害回复7点能量。", "kind": "damage_energy_restore", "value": 7.0},
	{"id": "high_energy_damage_bonus", "display_name": "高能输出", "description": "当能量高于70%时提高15%的伤害。", "kind": "high_energy_damage_bonus", "threshold": 0.70, "value": 0.15},
	{"id": "overheal_to_shield", "display_name": "冗余治疗缓存", "description": "将溢出的50%的治疗转化为持续6秒的护盾。", "kind": "overheal_to_shield", "value": 0.50, "duration": 6.0},
	{"id": "shield_damage_bonus", "display_name": "护盾火力链路", "description": "持有护盾时，伤害提高15%。", "kind": "shield_damage_bonus", "value": 0.15},
	{"id": "shield_break_knockback", "display_name": "破盾震荡", "description": "护盾被击破时击退周围的敌人。", "kind": "shield_break_knockback", "radius": 220.0, "force": 280.0},
	{"id": "execute_damage_bonus", "display_name": "终结算法", "description": "对生命值低于30%的敌人造成的伤害提高25%。", "kind": "execute_damage_bonus", "threshold": 0.30, "value": 0.25},
	{"id": "miss_energy_refund", "display_name": "空弹回收", "description": "弹体未命中敌人时，返回40%的能耗。", "kind": "miss_energy_refund", "value": 0.40},
	{"id": "low_health_attack_speed", "display_name": "濒危超频", "description": "生命值低于30%时，攻速提高25%。", "kind": "low_health_attack_speed", "threshold": 0.30, "value": 0.25},
	{"id": "full_health_guaranteed_critical", "display_name": "首击漏洞", "description": "对满血敌人造成的伤害必定暴击。", "kind": "full_health_guaranteed_critical"},
]


static func get_protocol_definitions() -> Array[Dictionary]:
	## 返回全部协议定义深拷贝；UI 和验证代码不得修改共享常量内容。
	# 协议定义副本列表会逐项深复制，调用方修改嵌套字段也不会污染共享平衡表。
	var definitions: Array[Dictionary] = []
	for protocol_definition in PROTOCOL_DEFINITIONS:
		definitions.append(protocol_definition.duplicate(true))
	return definitions


static func get_protocol_definition(protocol_id: String) -> Dictionary:
	## 按稳定 ID 返回协议定义；未知 ID 返回空字典，网络与运行期组件会安全忽略。
	for protocol_definition in PROTOCOL_DEFINITIONS:
		if str(protocol_definition.get("id", "")) == protocol_id:
			return protocol_definition.duplicate(true)
	return {}


static func normalize_protocol_ids(raw_protocol_ids: Array) -> Array[String]:
	## 规范化协议 ID 数组；保留合法重复项和获得顺序，使叠加层数与只读列表可准确还原。
	# 规范化 ID 列表仅接收平衡表中存在的条目，同时保留重复项和原始顺序。
	var normalized_ids: Array[String] = []
	for raw_protocol_id in raw_protocol_ids:
		# 当前协议 ID 会被统一转为去除首尾空白的字符串，兼容网络反序列化产生的宽泛数组类型。
		var protocol_id: String = str(raw_protocol_id).strip_edges()
		if not get_protocol_definition(protocol_id).is_empty():
			normalized_ids.append(protocol_id)
	return normalized_ids


static func get_stacked_effect_total(raw_protocol_ids: Array, effect_kind: String) -> float:
	## 汇总协议列表中指定 kind 的 value；保留合法重复层数，供主机按远端击杀归属结算个人掉落增益。
	# 目标效果累计值从零开始，重复协议按定义中的单层 value 线性叠加。
	var total_value: float = 0.0
	for protocol_id in normalize_protocol_ids(raw_protocol_ids):
		# 当前协议定义用于读取稳定效果类型与数值，合法 ID 必定能解析为非空字典。
		var protocol_definition: Dictionary = get_protocol_definition(protocol_id)
		if str(protocol_definition.get("kind", "")) == effect_kind:
			total_value += float(protocol_definition.get("value", 0.0))
	return total_value


static func roll_offer_ids(random_source: RandomNumberGenerator, count: int = OFFER_COUNT) -> Array[String]:
	## 从完整协议池中无放回抽取本次候选；候选内部不重复，已获得协议仍可再次出现并叠加。
	# 实际随机源优先使用调用方传入实例，空值时创建并随机化独立实例供正常游戏使用。
	var resolved_random: RandomNumberGenerator = random_source
	if resolved_random == null:
		resolved_random = RandomNumberGenerator.new()
		resolved_random.randomize()
	# 可用协议 ID 池包含全部协议，抽取后会移除条目以保证单次候选不重复。
	var available_ids: Array[String] = []
	for protocol_definition in PROTOCOL_DEFINITIONS:
		available_ids.append(str(protocol_definition.get("id", "")))
	# 候选 ID 列表保存本次固定结果，已获得的相同协议仍允许在后续批次再次出现。
	var offer_ids: Array[String] = []
	for _offer_index in range(mini(maxi(count, 0), available_ids.size())):
		# 随机下标始终限制在剩余协议池内，用于执行无放回抽取。
		var selected_index: int = resolved_random.randi_range(0, available_ids.size() - 1)
		offer_ids.append(available_ids.pop_at(selected_index))
	return offer_ids


static func get_fragment_requirement(acquired_protocol_count: int) -> float:
	## 返回下一次选择需要的碎片；使用线性成长并限制计数非负，避免异常网络值降低需求。
	return BASE_FRAGMENT_REQUIREMENT + float(maxi(acquired_protocol_count, 0)) * FRAGMENT_REQUIREMENT_INCREMENT


static func get_population_multiplier(average_protocol_count: float) -> float:
	## 按团队平均协议数计算动态人口倍率；0 层严格返回 1，多人不会把每个人的协议数直接相加。
	# 人口增幅按团队平均层数线性增长并受全局上限约束，防止后期生成压力无限膨胀。
	var population_bonus: float = minf(maxf(average_protocol_count, 0.0) * POPULATION_BONUS_PER_AVERAGE_PROTOCOL, MAXIMUM_POPULATION_BONUS)
	return 1.0 + population_bonus


static func get_drop_chance_multiplier(average_protocol_count: float) -> float:
	## 按团队平均协议数计算怪物物品掉落倍率；最低保留 65%，宝箱和其他产出不受影响。
	# 掉落降幅按团队平均层数线性增长并受全局上限约束，最终由调用方换算为剩余倍率。
	var drop_reduction: float = minf(maxf(average_protocol_count, 0.0) * DROP_REDUCTION_PER_AVERAGE_PROTOCOL, MAXIMUM_DROP_REDUCTION)
	return 1.0 - drop_reduction
