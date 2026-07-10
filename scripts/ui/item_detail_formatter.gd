extends RefCounted
class_name ItemDetailFormatter

## 物品详情格式化器集中生成仓库、背包、装备栏和结算界面的统一悬停信息。
## 武器强化数值使用 RichTextLabel BBCode 着色，同时保留纯文本版本作为系统无富文本环境的兜底。

## 正强化颜色；默认亮绿色，用于高于基础值的总值与正数强化差值。
const POSITIVE_COLOR: String = "#70e889"
## 负强化颜色；默认亮红色，用于低于基础值的总值与负数强化差值。
const NEGATIVE_COLOR: String = "#ff7070"
## 中性数值颜色；默认浅色，用于尚未强化或与基础值相同的总值。
const NEUTRAL_COLOR: String = "#d8e8ee"
## 悬停信息背景颜色；默认深蓝黑且透明度为 0.68，比系统默认背景更通透。
const TOOLTIP_BACKGROUND_COLOR: Color = Color(0.025, 0.04, 0.055, 0.68)
## 悬停信息边框颜色；默认接近纯白，用于在半透明背景外形成清晰轮廓。
const TOOLTIP_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.92)
## 悬停信息边框宽度；默认 2 像素，保证半透明背景在亮色场景中仍有清晰边界。
const TOOLTIP_BORDER_WIDTH: int = 2
## 悬停信息圆角半径；默认 6 像素，使详情框与现有游戏 UI 风格一致。
const TOOLTIP_CORNER_RADIUS: int = 6


static func is_weapon(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) != "enhancement_stone" and str(item_resource.get("weapon_type")) in ["ranged", "melee"]


static func is_enhancement_stone(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "enhancement_stone"


static func is_repair_kit(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "repair_kit"


static func get_item_display_name(item_resource: Resource) -> String:
	if item_resource == null:
		return "未知物品"
	# 显示名称；优先使用通用 display_name，武器旧资源缺失时回退稳定 weapon_id。
	var display_name: String = str(item_resource.get("display_name"))
	if display_name.is_empty():
		display_name = str(item_resource.get("weapon_id"))
	return "%s（损坏）" % display_name if is_weapon(item_resource) and item_resource.has_method("is_broken") and bool(item_resource.call("is_broken")) else display_name


static func get_item_type_label(item_resource: Resource) -> String:
	if is_enhancement_stone(item_resource):
		return "资源 · 强化石"
	if is_repair_kit(item_resource):
		return "道具 · 修复包"
	# 武器类型；ranged 与 melee 分别映射到仓库武器子分类。
	var weapon_type: String = str(item_resource.get("weapon_type")) if item_resource != null else ""
	return "武器 · 远程" if weapon_type == "ranged" else ("武器 · 近战" if weapon_type == "melee" else "未知")


static func get_item_sell_price(item_resource: Resource) -> int:
	if item_resource == null:
		return 0
	if item_resource.has_method("get_effective_sell_price"):
		return maxi(int(item_resource.call("get_effective_sell_price")), 0)
	return maxi(int(item_resource.get("sell_price")), 0)


static func build_plain_text(item_resource: Resource, quantity: int = 1) -> String:
	return _strip_bbcode(build_bbcode(item_resource, quantity))


static func build_bbcode(item_resource: Resource, quantity: int = 1) -> String:
	if item_resource == null:
		return "物品数据不可用"
	# 详情文本行；首部统一显示名称、分类、数量与售价，后续按资源类型追加字段。
	var detail_lines: Array[String] = []
	detail_lines.append("[font_size=18][b]%s[/b][/font_size]" % get_item_display_name(item_resource))
	detail_lines.append("类型：%s" % get_item_type_label(item_resource))
	if quantity > 1 or is_enhancement_stone(item_resource):
		detail_lines.append("数量：%d / 99" % maxi(quantity, 1))
	# 单件售价；资源堆叠额外展示整组价值，避免菜单价格与详情不一致。
	var unit_sell_price: int = get_item_sell_price(item_resource)
	detail_lines.append("出售价格：%d 金币%s" % [unit_sell_price * maxi(quantity, 1), "（单个 %d）" % unit_sell_price if quantity > 1 else ""])
	# 物品说明；空说明不生成无意义空行。
	var description: String = str(item_resource.get("description"))
	if not description.is_empty():
		detail_lines.append(description)

	if is_enhancement_stone(item_resource):
		_append_stone_lines(detail_lines, item_resource)
	elif is_repair_kit(item_resource):
		_append_repair_kit_lines(detail_lines, item_resource)
	elif is_weapon(item_resource):
		_append_weapon_lines(detail_lines, item_resource)
	return "\n".join(detail_lines)


static func create_tooltip_control(item_resource: Resource, quantity: int = 1) -> Control:
	# 富文本详情；由 Godot 自定义 tooltip 承载，fit_content 保证内容按文本高度完整展开。
	var detail_label: RichTextLabel = RichTextLabel.new()
	detail_label.bbcode_enabled = true
	detail_label.fit_content = true
	detail_label.scroll_active = false
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.custom_minimum_size = Vector2(330.0, 0.0)
	detail_label.text = build_bbcode(item_resource, quantity)

	# 详情边距；为系统 tooltip 提供稳定留白，避免文字紧贴边缘。
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(detail_label)
	# 悬停背景框；使用较低透明度和一圈白色边框统一仓库、背包、装备栏与结算详情样式。
	var tooltip_panel: PanelContainer = PanelContainer.new()
	# 悬停背景样式；圆角和双像素边框提高半透明背景在不同场景亮度下的可辨识度。
	var tooltip_style: StyleBoxFlat = StyleBoxFlat.new()
	tooltip_style.bg_color = TOOLTIP_BACKGROUND_COLOR
	tooltip_style.border_color = TOOLTIP_BORDER_COLOR
	tooltip_style.set_border_width_all(TOOLTIP_BORDER_WIDTH)
	tooltip_style.set_corner_radius_all(TOOLTIP_CORNER_RADIUS)
	tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)
	tooltip_panel.add_child(margin)
	return tooltip_panel


static func _append_stone_lines(detail_lines: Array[String], item_resource: Resource) -> void:
	detail_lines.append("[b]强化词条[/b]")
	# 强化词典；值只表示数值增减方向，详情不显示具体百分比。
	# 品质化显示补充；当前详情保留每条实际百分比，并先显示增强、后显示削弱。
	# 方向化显示补充；当前详情只显示属性与 +/-，具体百分比仅在强化完成弹窗中公开。
	var modifiers: Dictionary = EnhancementRules.normalize_modifiers(item_resource.get("modifiers") as Dictionary)
	_append_stone_lines_by_benefit(detail_lines, modifiers, true)
	_append_stone_lines_by_benefit(detail_lines, modifiers, false)


static func _append_repair_kit_lines(detail_lines: Array[String], item_resource: Resource) -> void:
	# 修复量；取值至少为 0，显示为整数以匹配所有当前修复包的固定耐久数值。
	var repair_amount: float = maxf(float(item_resource.get("repair_amount")), 0.0)
	detail_lines.append("[b]使用效果[/b]")
	detail_lines.append("仅可对武器使用")
	detail_lines.append("恢复耐久：%.0f" % repair_amount)


static func _append_stone_lines_by_benefit(detail_lines: Array[String], modifiers: Dictionary, beneficial: bool) -> void:
	# 属性顺序；每一组内使用规则目录顺序，两次调用保证增强全部排在削弱之前。
	for modifier_key in EnhancementRules.STAT_KEYS:
		if not modifiers.has(modifier_key):
			continue
		# 属性方向；取值固定为 +1 或 -1，用于生成“伤害+”“冷却+”等短文本。
		# 实际数值补充；取值为带方向的百分比小数，旧 +1/-1 会先迁移为 ±10%。
		var modifier_direction: float = float(modifiers.get(modifier_key, 0.0))
		if EnhancementRules.is_direction_beneficial(modifier_key, modifier_direction) != beneficial:
			continue
		# 词条颜色；按玩法利弊渲染，冷却-、能量消耗-、扩散-和后坐力-等降低型增益统一显示绿色。
		var color_code: String = POSITIVE_COLOR if beneficial else NEGATIVE_COLOR
		detail_lines.append("[color=%s]%s[/color]" % [color_code, EnhancementRules.build_modifier_token(modifier_key, modifier_direction, false)])


static func _append_weapon_lines(detail_lines: Array[String], item_resource: Resource) -> void:
	# 当前耐久；取值限制在 0 到最大耐久，用于详情显示与损坏状态说明。
	var current_durability: float = maxf(float(item_resource.get("current_durability")), 0.0)
	# 最大耐久；取值至少为 1，避免旧资源字段缺失造成无效比例。
	var max_durability: float = maxf(float(item_resource.get("max_durability")), 1.0)
	# 单次耐久消耗；每把武器独立配置，成功射击或近战使用时按该浮点数扣除。
	var durability_cost_per_use: float = maxf(float(item_resource.get("durability_cost_per_use")), 0.0)
	detail_lines.append("耐久：%.1f / %.1f" % [current_durability, max_durability])
	detail_lines.append("耐久消耗：%.1f / 次" % durability_cost_per_use)
	if item_resource.has_method("is_broken") and bool(item_resource.call("is_broken")):
		detail_lines.append("[color=%s]状态：损坏，无法使用[/color]" % NEGATIVE_COLOR)
	# 武器类型；决定伤害、冷却及远近战专属属性的基础字段映射。
	var weapon_type: String = str(item_resource.get("weapon_type"))
	_append_weapon_stat_line(detail_lines, item_resource, "damage", 1)
	_append_weapon_stat_line(detail_lines, item_resource, "cooldown", 2, " 秒")
	_append_weapon_stat_line(detail_lines, item_resource, "energy_cost", 1)
	if weapon_type == "ranged":
		_append_weapon_stat_line(detail_lines, item_resource, "bullet_range", 1)
		_append_weapon_stat_line(detail_lines, item_resource, "projectile_speed", 1)
		_append_weapon_stat_line(detail_lines, item_resource, "spread_degrees", 1, "°")
	else:
		_append_weapon_stat_line(detail_lines, item_resource, "melee_active_duration", 2, " 秒")
	_append_weapon_stat_line(detail_lines, item_resource, "recoil_force", 1)
	_append_weapon_stat_line(detail_lines, item_resource, "front_recoil_force", 1)
	_append_weapon_stat_line(detail_lines, item_resource, "impact_force", 1)


static func _append_weapon_stat_line(detail_lines: Array[String], item_resource: Resource, stat_name: String, decimals: int, suffix: String = "") -> void:
	# 基础值；优先调用 WeaponData 统一接口，旧资源回退直接字段读取。
	var base_value: float = float(item_resource.call("get_base_stat", stat_name)) if item_resource.has_method("get_base_stat") else 0.0
	# 有效值；包含累计强化比例，所有战斗组件与详情都读取同一结果。
	var effective_value: float = float(item_resource.call("get_effective_stat", stat_name)) if item_resource.has_method("get_effective_stat") else base_value
	# 强化差值；只用于展示，不覆盖武器基础资源字段。
	var enhancement_value: float = effective_value - base_value
	# 强化是否为玩法增益；数值降低不等于减益，冷却、能耗、扩散和后坐力降低均按规则目录判定为增益。
	var enhancement_is_beneficial: bool = not is_zero_approx(enhancement_value) and EnhancementRules.is_direction_beneficial(stat_name, enhancement_value)
	# 总值颜色；存在强化时按玩法收益显示绿色或红色，未变化时使用中性色。
	var total_color: String = (POSITIVE_COLOR if enhancement_is_beneficial else NEGATIVE_COLOR) if not is_zero_approx(enhancement_value) else NEUTRAL_COLOR
	# 差值颜色；与总值使用同一玩法收益判断，避免冷却减少等正收益被误标为红色。
	var delta_color: String = total_color
	# 数值格式；按属性精度生成 0.0 或 0.00 等稳定格式。
	var value_format: String = "%%.%df" % decimals
	# 总值文本；示例为“伤害：1200（1000+200）”，强化差值始终显式带正负号。
	if is_zero_approx(enhancement_value):
		detail_lines.append("%s：[color=%s]%s[/color]%s" % [EnhancementRules.get_stat_label(stat_name), total_color, value_format % effective_value, suffix])
		return
	# 有强化变化时才显示括号中的基础值和强化差值，避免出现“（100+0.0）”无效信息。
	detail_lines.append("%s：[color=%s]%s[/color]（%s[color=%s]%s[/color]）%s" % [
		EnhancementRules.get_stat_label(stat_name),
		total_color,
		value_format % effective_value,
		value_format % base_value,
		delta_color,
		("+" if enhancement_value >= 0.0 else "") + (value_format % enhancement_value),
		suffix,
	])


static func _strip_bbcode(bbcode_text: String) -> String:
	# BBCode 标签正则；只移除格式标签并保留原文字，供 tooltip_text 和无富文本环境使用。
	var tag_regex: RegEx = RegEx.new()
	tag_regex.compile("\\[[^\\]]+\\]")
	return tag_regex.sub(bbcode_text, "", true)
