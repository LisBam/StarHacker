extends Resource
class_name WeaponData

## 武器数据资源集中描述一把武器的装备类型、消耗、伤害和攻击节奏。
## 背包、装备、攻击和 HUD 都只读取这个资源，不直接互相写死参数。
## 同一套字段同时覆盖远程和近战武器，未使用字段保持默认值即可。

## 武器物品类型；固定为 weapon，供库存和 UI 与可堆叠资源解耦识别。
@export var item_kind: String = "weapon"

## 武器唯一标识；默认空字符串表示未配置，建议使用稳定英文 ID，修改会影响存档和调试定位。
@export var weapon_id: String = ""
## 武器显示名称；默认“未命名武器”用于兜底显示，运行时通常不修改，改名会影响 HUD 和背包文本。
@export var display_name: String = "未命名武器"
## 武器类型；取值为 ranged、melee 或 hybrid，默认 ranged，hybrid 可放入任一武器槽且每次使用同时执行远程与近战攻击。
## 混合武器的副通道由玩家专用组件执行，不占用另一装备槽的主攻击组件，因此完整混合攻击后仍可立即使用另一把武器。
@export_enum("ranged", "melee", "hybrid") var weapon_type: String = "ranged"
## 武器说明文本；默认空字符串，主要用于背包详情和调试展示，运行时通常不动态修改。
@export_multiline var description: String = ""
## HUD 图标文本；默认问号用于未配置图标时兜底，建议保持 1 到 2 个字符，修改会影响装备栏显示。
@export var icon_text: String = "?"
## 物品价值；取值大于等于 0，默认 0 表示不可出售，玩家出售时以该值为基础结算且运行时通常不修改。
@export_range(0, 999999, 1) var value: int = 0
## 武器最大耐久；取值大于 0，默认 500.0，运行时通常不修改，调整会影响耐久比例、读条与价格折损速度。
## 耐久上限保留 0.1 浮点精度供特殊武器扩展；已存档武器会按原耐久比例迁移到当前基础上限。
@export_range(1.0, 999999.0, 0.1, "or_greater") var max_durability: float = 500.0
## 武器当前耐久；取值会限制在 0 到最大耐久，默认 500.0 表示新武器以满耐久创建，归零后武器保留但不可继续使用。
## 该字段允许运行时因攻击、修复与强化变化，不应绕过统一耐久接口直接写入。
@export_range(0.0, 999999.0, 0.1) var current_durability: float = 500.0
## 每次成功使用消耗的耐久；取值大于等于 0，默认 1，远程射击和近战挥击成功后各扣除一次。
## 独立消耗配置补充：默认参考值为 1.0，每把武器资源可覆盖为不同浮点消耗。
## 固定消耗规则补充：武器不再暴露独立耐久消耗属性；普通武器成功使用扣除 1 点，混合武器完整攻击由控制器传入 2 点且运行时不可按武器修改。
const FIXED_DURABILITY_COST_PER_USE: float = 1.0
## 每次成功使用武器的基础能耗；取值为非负整数，默认 0 表示免费攻击，强化后的最终值也会统一取整。
@export_range(0, 9999, 1, "or_greater") var energy_consumption: int = 0
## 远程武器使用的弹体场景；默认空表示不能发射，必须实例化为 Node2D，修改会影响远程攻击生成对象。
@export var projectile_scene: PackedScene
## 远程弹体速度；取值建议大于 0，默认 900，修改会影响远程弹道速度。
@export_range(1.0, 3000.0, 1.0, "or_greater") var projectile_speed: float = 900.0
## 武器攻击距离；取值应大于 0，默认 340 像素。远程武器表示弹体最大飞行距离，近战武器表示攻击判定区域沿攻击方向最远端到玩家本体的距离。
@export_range(1.0, 12000.0, 1.0, "or_greater") var attack_distance: float = 340.0
## 远程弹体伤害；取值建议大于等于 0，默认 12，修改会影响弹体命中后的伤害值。
@export_range(0.0, 9999.0, 1.0, "or_greater") var ranged_damage: float = 12.0
## 武器冷却；取值应大于 0，远程默认 0.16 秒、近战资源应自行覆盖，修改会影响连续攻击频率。
@export_range(0.01, 5.0, 0.01) var cooldown: float = 0.16
## 武器偏移角度；取值大于等于 0，默认 0 度表示完全精准，数值越高每颗弹体相对瞄准方向的随机角度越大。
@export_range(0.0, 45.0, 0.1, "or_greater") var deviation_degrees: float = 0.0
## 是否具有散射属性；默认 false，只有显式启用的远程武器才能发射多颗弹体并接受散射强化。
@export var has_scatter: bool = false
## 每轮射击生成的弹体总数；默认 1 表示单弹体，只有 has_scatter 为 true 时参与战斗与强化结算。
@export_range(1, 100, 1, "or_greater") var scatter_count: int = 1
## 是否具有穿透属性；默认 false，只有显式启用的远程武器才能穿透目标并接受穿透强化。
## 远程攻击通道默认持有穿透属性；默认 true 但穿透次数为 0，因此首个命中后仍销毁，同时允许直接接受穿透强化。
@export var has_piercing: bool = true
## 每颗弹体可额外穿过的目标数量；默认 0 表示命中首个目标后销毁，只有 has_piercing 为 true 时参与战斗与强化结算。
@export_range(0, 100, 1, "or_greater") var piercing_count: int = 0
## 是否具有弹射属性；默认 false，只有显式启用的远程武器才能在碰撞后改变弹道并接受弹射强化。
@export var has_bounce: bool = false
## 每颗弹体最多可执行的弹射次数；默认 0 表示不弹射，只有 has_bounce 为 true 时参与战斗、展示与强化结算。
@export_range(0, 100, 1, "or_greater") var bounce_count: int = 0
## 是否具有连击属性；默认 false，只有显式启用的远程武器才能连续发射多轮并接受连击强化。
@export var has_combo: bool = false
## 一次攻击连续执行的射击轮数；默认 1 表示只发射一轮，完整连击结束后才进入武器冷却。
@export_range(1, 100, 1, "or_greater") var combo_count: int = 1
## 连击相邻两轮之间的时间；默认 0.08 秒，运行时通常不修改，调整会改变连击持续时间但不改变结束后的武器冷却。
@export_range(0.01, 5.0, 0.01) var combo_interval: float = 0.08
## 是否具有后坐力属性；默认 false，启用时自动关闭前坐力，保证一把武器至多拥有一种坐力属性。
@export var has_recoil: bool = false:
	set(value_enabled):
		has_recoil = value_enabled
		if has_recoil:
			has_front_recoil = false
## 武器后坐力；单位为单次无碰撞理论反向位移像素，1 点对应 1 像素，默认 0 表示不推动使用者，只有 has_recoil 为 true 时参与战斗、显示与强化结算。
@export_range(0.0, 3000.0, 1.0, "or_greater") var recoil_force: float = 0.0
## 是否具有前坐力属性；默认 false，启用时自动关闭后坐力，保证一把武器至多拥有一种坐力属性。
@export var has_front_recoil: bool = false:
	set(value_enabled):
		has_front_recoil = value_enabled
		if has_front_recoil:
			has_recoil = false
## 武器前坐力；单位为单次无碰撞理论正向位移像素，1 点对应 1 像素，默认 0 表示不向攻击方向推动使用者，只有 has_front_recoil 为 true 时参与战斗、显示与强化结算。
@export_range(0.0, 3000.0, 1.0, "or_greater") var front_recoil_force: float = 0.0
## 武器冲击力；单位为目标单次无碰撞理论位移像素，1 点对应 1 像素，默认 0 表示不造成击退，命中怪物时会先按目标韧性减少理论位移。
@export_range(0.0, 5000.0, 1.0, "or_greater") var impact_force: float = 0.0
## 近战伤害；取值建议大于等于 0，默认 35，修改会影响近战命中后的伤害值。
@export_range(0.0, 9999.0, 1.0, "or_greater") var melee_damage: float = 35.0
## 混合武器远程攻击距离；取值大于 0，默认 340 像素，仅 hybrid 使用，攻击距离强化会与近战距离同步按同一比例结算。
@export_range(1.0, 12000.0, 1.0, "or_greater") var ranged_attack_distance: float = 340.0
## 混合武器近战攻击距离；取值大于 0，默认 80 像素，仅 hybrid 使用，攻击距离强化会与远程距离同步按同一比例结算。
@export_range(1.0, 12000.0, 1.0, "or_greater") var melee_attack_distance: float = 80.0
## 混合武器远程冲击力；单位为理论位移像素，默认 0，仅 hybrid 使用，冲击力强化会与近战冲击同步按同一比例结算。
@export_range(0.0, 5000.0, 1.0, "or_greater") var ranged_impact_force: float = 0.0
## 混合武器近战冲击力；单位为理论位移像素，默认 0，仅 hybrid 使用，冲击力强化会与远程冲击同步按同一比例结算。
@export_range(0.0, 5000.0, 1.0, "or_greater") var melee_impact_force: float = 0.0
## 武器暴击率；使用 0 到 1 小数，默认 0，每把武器资源可配置不同初始值并允许强化。
@export_range(0.0, 1.0, 0.01) var critical_chance: float = 0.0
## 武器暴击伤害倍率；默认 1.5 表示造成 150% 伤害，允许强化石永久调整。
@export_range(1.0, 10.0, 0.05, "or_greater") var critical_damage: float = 1.5
## 近战命中框激活时长；取值应大于 0，默认 0.12 秒，修改会影响近战判定窗口。
@export_range(0.01, 2.0, 0.01) var melee_active_duration: float = 0.12
## 是否拥有蓄力效果；默认 false，开启后按住对应攻击键蓄力、松开释放，未开启武器保持原有点击或连射逻辑。
## 检查器说明：勾选此项后才会读取最大蓄力时间、蓄力减速、蓄力减伤与三项满蓄增幅；关闭时这些参数完全不参与输入、数值或资源消耗结算。
@export var has_charge_effect: bool = false
## 武器最大蓄力时间；取值大于 0 秒，默认 1 秒，仅 has_charge_effect 开启时使用，达到上限后保持满蓄力直到松开。
@export_range(0.01, 30.0, 0.01, "or_greater") var maximum_charge_duration: float = 1.0
## 蓄力期间移动速度倍率；取值 0 至 1，默认 1 表示不减速，0.5 表示移动速度降低 50%，仅蓄力进行中生效。
@export_range(0.0, 1.0, 0.01) var charge_movement_speed_multiplier: float = 1.0
## 蓄力期间减伤比例；取值 0 至 1，默认 0 表示不减伤，0.1 表示最终受到伤害降低 10%，松开或取消后立即失效。
@export_range(0.0, 1.0, 0.01) var charge_damage_reduction_ratio: float = 0.0
## 满蓄力伤害提升比例；默认 0 表示不强化，0.5 表示远程与近战伤害在满蓄力时都提高 50%，中间进度线性插值。
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_charge_damage_bonus_ratio: float = 0.0
## 满蓄力冲击力提升比例；默认 0 表示不强化，hybrid 的远程与近战冲击会同时按该比例线性提高。
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_charge_impact_bonus_ratio: float = 0.0
## 满蓄力坐力提升比例；默认 0 表示不强化，前坐力或后坐力按蓄力比例线性提高且不改变武器持有的坐力类型。
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_charge_recoil_bonus_ratio: float = 0.0
## 累计强化百分比词典；键使用 damage、cooldown 等统一属性名，值为相对基础值的小数比例，运行时由强化石永久累加。
## 加算属性补充：暴击率与暴击伤害的累计值表示直接百分点偏移，其余武器属性仍表示相对基础值比例。
@export var enhancement_modifiers: Dictionary = {}

## 强化后价值最低倍率；默认 0.1，防止大量负词条把价值降为负数，运行时通常不修改。
const MINIMUM_VALUE_MULTIPLIER: float = 0.1
## 损坏武器最低耐久价值倍率；默认 0.1，使零耐久武器仍保留满耐久有效价值的 10%。
const MINIMUM_DURABILITY_VALUE_MULTIPLIER: float = 0.1
## 冷却和判定时长最小有效值；默认 0.01 秒，防止负强化导致除零或无限攻击。
const MINIMUM_DURATION_VALUE: float = 0.01
## 可应用于所有武器的统一强化属性；新增通用战斗字段时应同步详情格式化器。
const COMMON_ENHANCEMENT_STATS: Array[String] = ["damage", "cooldown", "energy_consumption", "attack_distance", "recoil_force", "front_recoil_force", "impact_force", "critical_chance", "critical_damage", "max_durability"]
## 远程武器专属强化属性；只允许远程武器消费包含这些字段的强化石效果。
const RANGED_ENHANCEMENT_STATS: Array[String] = ["projectile_speed", "deviation_degrees", "scatter_count", "piercing_count", "bounce_count", "combo_count"]
## 近战武器专属强化属性；只允许近战武器消费包含这些字段的强化石效果。
const MELEE_ENHANCEMENT_STATS: Array[String] = ["melee_active_duration"]


func is_ranged() -> bool:
	return weapon_type in ["ranged", "hybrid"]


func is_melee() -> bool:
	return weapon_type in ["melee", "hybrid"]


func is_hybrid() -> bool:
	## 返回武器是否会在一次使用中同时触发远程和近战攻击；调用方不得用该结果重复结算能量、冷却或坐力。
	return weapon_type == "hybrid"


func get_maximum_durability() -> float:
	# 武器当前不生成耐久上限词条，统一接口返回模板上限，供锻造、修复和 UI 与装备共用读取方式。
	# 耐久强化补充：现行武器强化石允许改变耐久上限，因此统一返回乘算词条结算后的有效值。
	return maxf(get_effective_stat("max_durability"), 1.0)


func get_durability_ratio() -> float:
	return clampf(current_durability / get_maximum_durability(), 0.0, 1.0)


func is_broken() -> bool:
	return current_durability <= 0.0 or is_zero_approx(current_durability)


func can_be_used() -> bool:
	return not is_broken()


func set_current_durability(value: float) -> void:
	current_durability = clampf(value, 0.0, get_maximum_durability())


func consume_durability(requested_amount: float = FIXED_DURABILITY_COST_PER_USE) -> bool:
	if is_broken():
		return false
	# 实际消耗量；普通武器固定传入 1，混合武器传入 2；当前耐久不足时只消耗剩余值，因此 1 点耐久仍可完成最后一次攻击。
	var resolved_amount: float = minf(maxf(requested_amount, 0.0), current_durability)
	if resolved_amount <= 0.0:
		return false
	# 消耗前耐久；用于判断本次调用是否实际改变了资源状态。
	var durability_before: float = current_durability
	set_current_durability(current_durability - resolved_amount)
	return not is_equal_approx(durability_before, current_durability)


func get_base_stat(stat_name: String) -> float:
	# 基础字段名；damage 根据武器类型映射到远程或近战伤害字段，其他属性使用统一字段名。
	var property_name: String = _resolve_base_property_name(stat_name)
	if property_name.is_empty():
		return 0.0
	# 基础字段值；取值来自资源原始导出属性，强化过程不会写回这些字段。
	var property_value: Variant = get(property_name)
	return float(property_value) if property_value != null else 0.0


func get_enhancement_ratio(stat_name: String) -> float:
	# 统一属性名；允许战斗组件传入 ranged_damage 等旧字段名并映射到 damage 强化词条。
	var canonical_stat_name: String = _resolve_canonical_stat_name(stat_name)
	# 已迁移累计词典；历史 spread_degrees 强化会与现行 deviation_degrees 合并，保证旧存档最终值不变。
	var migrated_modifiers: Dictionary = EnhancementRules.migrate_stat_aliases(enhancement_modifiers)
	return float(migrated_modifiers.get(canonical_stat_name, 0.0))


func get_enhancement_value(stat_name: String) -> float:
	# 公式分类补充；乘算属性返回基础值换算后的差值，加算属性直接返回累计百分点对最终值造成的真实差值。
	return get_effective_stat(stat_name) - get_base_stat(stat_name)


func get_effective_stat(stat_name: String) -> float:
	# 有效属性值；基础值乘以累计百分比，所有攻击与玩家反馈组件应通过该接口读取。
	# 分类公式补充；暴击率与暴击伤害改为直接加算百分点，其余武器属性继续使用基础值乘算。
	var effective_value: float = EnhancementRules.calculate_effective_stat(get_base_stat(stat_name), _resolve_canonical_stat_name(stat_name), get_enhancement_ratio(stat_name))
	# 统一属性名；持续时间保持正数，其余不能为负，避免异常强化破坏战斗组件。
	# 边界规则补充；具体上下限已集中到 EnhancementRules，避免武器与装备产生不同解释。
	return effective_value


func get_effective_attack_stat(stat_name: String, attack_mode: String) -> float:
	## 返回指定攻击通道的有效属性；混合武器保留各自基础值，但共享通用强化比例，普通武器继续读取原有统一字段。
	# 通道基础属性名；只对混合武器的距离与冲击拆分，伤害字段原本已经按远近战独立保存。
	var property_name: String = stat_name
	if stat_name == "damage":
		property_name = "ranged_damage" if attack_mode == "ranged" else "melee_damage"
	elif is_hybrid() and stat_name == "attack_distance":
		property_name = "ranged_attack_distance" if attack_mode == "ranged" else "melee_attack_distance"
	elif is_hybrid() and stat_name == "impact_force":
		property_name = "ranged_impact_force" if attack_mode == "ranged" else "melee_impact_force"
	# 通道基础值；普通武器未拆分距离和冲击时仍使用原字段，避免改变既有资源与存档。
	var base_value: float = float(get(property_name)) if get(property_name) != null else 0.0
	# 共享强化键；三类双通道属性分别映射到 damage、attack_distance 与 impact_force 的唯一累计比例。
	var canonical_stat_name: String = _resolve_canonical_stat_name(stat_name)
	return EnhancementRules.calculate_effective_stat(base_value, canonical_stat_name, get_enhancement_ratio(canonical_stat_name))


func can_apply_enhancement(modifiers: Dictionary) -> bool:
	for raw_stat_name in modifiers.keys():
		if _is_stat_supported(str(raw_stat_name)):
			return true
	return false


func apply_enhancement(modifiers: Dictionary) -> bool:
	# 是否实际应用词条；只有与当前武器兼容的字段会写入，避免远程专属属性污染近战武器。
	var applied_any_modifier: bool = bool(apply_enhancement_with_result(modifiers).get("success", false))
	return applied_any_modifier


func apply_enhancement_with_result(modifiers: Dictionary) -> Dictionary:
	# 强化结果；分开保存提升和削弱明细，UI 可直接展示百分比、基础值、变化值和强化后数值。
	var result: Dictionary = {
		"success": false,
		"weapon": self,
		"beneficial_changes": [],
		"detrimental_changes": [],
	}
	# 已迁移累计强化；应用新词条前合并历史偏移键，确保旧武器继续强化时不会丢失原累计幅度。
	enhancement_modifiers = EnhancementRules.migrate_stat_aliases(enhancement_modifiers)
	# 是否实际应用词条；只有与当前武器兼容的字段会写入，避免远程专属属性污染近战武器。
	var applied_any_modifier: bool = false
	for raw_stat_name in modifiers.keys():
		# 统一属性名；空值或当前武器不支持的字段直接跳过。
		var stat_name: String = _resolve_canonical_stat_name(str(raw_stat_name))
		if not _is_stat_supported(stat_name):
			continue
		# 词条方向；新版只读取 +1 或 -1，旧百分比也会按正负号归一化。
		var modifier_direction: int = EnhancementRules.normalize_direction(modifiers.get(raw_stat_name, 1))
		# 词条实际比例；品质化数据保留 5% 至 60% 幅度，旧 +1/-1 数据迁移为 10%。
		var modifier_ratio: float = EnhancementRules.get_effect_value(stat_name, modifiers.get(raw_stat_name, modifier_direction))
		if is_zero_approx(modifier_ratio):
			continue
		# 基础数值；不包含任何历史强化，用于结果弹窗说明本次百分比的换算基准。
		var base_value: float = get_base_stat(stat_name)
		# 强化前数值；包含历史累计强化，用于计算本次实际变化量。
		var before_value: float = get_effective_stat(stat_name)
		# 新累计比例；每条词条按固定 10% 步长累计，强化允许正负相抵且基础属性始终保持不变。
		# 品质随机补充：正常强化流程传入使用瞬间生成的 5% 至 60% 实际比例，固定 10% 仅保留给旧方向值直接调用兼容。
		# 独立区间补充：现行乘算幅度最高 55%，加算幅度最高 9.0 个百分点，具体范围由属性和品质共同决定。
		var accumulated_ratio: float = float(enhancement_modifiers.get(stat_name, 0.0)) + modifier_ratio
		# 累计精度补充；0.001 可保存加算属性的 0.1 个百分点，同时兼容乘算属性的 0.1% 幅度。
		enhancement_modifiers[stat_name] = snappedf(accumulated_ratio, EnhancementRules.MODIFIER_VALUE_PRECISION)
		if stat_name == "max_durability":
			# 当前耐久同步；耐久上限降低时限制现值，上限提高时不免费补充新增耐久。
			set_current_durability(current_durability)
		# 强化后数值；已应用属性下限保护，可以直接交给弹窗和战斗组件使用。
		var after_value: float = get_effective_stat(stat_name)
		# 单条变化明细；保留属性名、百分比和基础/前后数值，避免 UI 重新计算造成误差。
		var change_entry: Dictionary = {
			"stat_name": stat_name,
			"modifier_ratio": modifier_ratio,
			"calculation_mode": EnhancementRules.get_calculation_mode(stat_name),
			"base_value": base_value,
			"before_value": before_value,
			"change_value": after_value - before_value,
			"after_value": after_value,
		}
		if EnhancementRules.is_direction_beneficial(stat_name, modifier_ratio):
			(result["beneficial_changes"] as Array).append(change_entry)
		else:
			(result["detrimental_changes"] as Array).append(change_entry)
		applied_any_modifier = true
	result["success"] = applied_any_modifier
	return result


func get_effective_value() -> int:
	# 价值调整比例；按玩法利弊判断累计强化，增强提高价值、削弱降低价值。
	var value_ratio: float = 0.0
	# 已迁移累计词典；历史字段先合并到现行键，价值与实际有效属性读取同一份数据。
	var migrated_modifiers: Dictionary = EnhancementRules.migrate_stat_aliases(enhancement_modifiers)
	for raw_stat_name in migrated_modifiers.keys():
		if _is_stat_supported(str(raw_stat_name)):
			# 累计比例；正负号表示当前属性最终变化方向，绝对值表示累计强化幅度。
			var accumulated_ratio: float = float(migrated_modifiers.get(raw_stat_name, 0.0))
			if not is_zero_approx(accumulated_ratio):
				# 累计方向；用于判断该属性最终变化对武器是增强还是削弱。
				var accumulated_direction: int = EnhancementRules.normalize_direction(accumulated_ratio)
				value_ratio += absf(accumulated_ratio) if EnhancementRules.is_direction_beneficial(str(raw_stat_name), accumulated_direction) else -absf(accumulated_ratio)
	# 强化后基础价值；先应用强化利弊，保证耐久折损与强化变化可以稳定组合。
	var enhanced_value: float = float(value) * maxf(1.0 + value_ratio, MINIMUM_VALUE_MULTIPLIER)
	# 耐久价值倍率；从零耐久的 10% 线性增长到满耐久的 100%，确保损坏武器仍保留回收价值。
	var durability_value_multiplier: float = lerpf(MINIMUM_DURABILITY_VALUE_MULTIPLIER, 1.0, get_durability_ratio())
	# 四舍五入价值；强化变化和耐久折损依次组合，零耐久时为强化后满耐久价值的 10%。
	var calculated_value: int = roundi(enhanced_value * durability_value_multiplier)
	# 最终价值；原始价值大于 0 的武器至少可出售 1 金币，避免低价值损坏武器因整数舍入变为不可出售。
	return maxi(calculated_value, 1) if value > 0 else 0


func _resolve_base_property_name(stat_name: String) -> String:
	# 统一属性名；伤害根据武器类型映射，其他字段直接使用统一命名。
	if stat_name in ["ranged_damage", "melee_damage", "ranged_attack_distance", "melee_attack_distance", "ranged_impact_force", "melee_impact_force"]:
		return stat_name
	var canonical_stat_name: String = _resolve_canonical_stat_name(stat_name)
	if canonical_stat_name == "damage":
		return "ranged_damage" if is_ranged() else "melee_damage"
	return canonical_stat_name if canonical_stat_name in COMMON_ENHANCEMENT_STATS + RANGED_ENHANCEMENT_STATS + MELEE_ENHANCEMENT_STATS else ""


func _resolve_canonical_stat_name(stat_name: String) -> String:
	stat_name = EnhancementRules.canonicalize_stat_name(stat_name)
	if stat_name in ["ranged_damage", "melee_damage"]:
		return "damage"
	if stat_name in ["ranged_attack_distance", "melee_attack_distance"]:
		return "attack_distance"
	if stat_name in ["ranged_impact_force", "melee_impact_force"]:
		return "impact_force"
	return stat_name


func _is_stat_supported(stat_name: String) -> bool:
	# 统一属性名；通用词条对所有武器有效，专属词条按 weapon_type 校验。
	var canonical_stat_name: String = _resolve_canonical_stat_name(stat_name)
	if canonical_stat_name == "recoil_force":
		return has_recoil and not is_zero_approx(recoil_force)
	if canonical_stat_name == "front_recoil_force":
		return has_front_recoil and not is_zero_approx(front_recoil_force)
	if canonical_stat_name in COMMON_ENHANCEMENT_STATS:
		return not is_zero_approx(get_base_stat(canonical_stat_name))
	if is_ranged():
		if canonical_stat_name == "scatter_count":
			return has_scatter
		if canonical_stat_name == "piercing_count":
			return has_piercing
		if canonical_stat_name == "bounce_count":
			return has_bounce
		if canonical_stat_name == "combo_count":
			return has_combo
		if canonical_stat_name in RANGED_ENHANCEMENT_STATS:
			return not is_zero_approx(get_base_stat(canonical_stat_name))
	if is_melee() and canonical_stat_name in MELEE_ENHANCEMENT_STATS:
		return not is_zero_approx(get_base_stat(canonical_stat_name))
	return false
