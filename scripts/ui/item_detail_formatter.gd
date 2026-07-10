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
## 属性中文名称；键使用强化系统统一属性名，新增强化属性时应同步补充该表。
const STAT_LABELS: Dictionary = {
	"damage": "伤害",
	"cooldown": "冷却",
	"energy_cost": "能量消耗",
	"projectile_speed": "弹体速度",
	"bullet_range": "弹体射程",
	"spread_degrees": "扩散",
	"recoil_force": "后坐力",
	"front_recoil_force": "前坐力",
	"impact_force": "冲击力",
	"melee_active_duration": "判定时长",
}


static func is_weapon(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) != "enhancement_stone" and str(item_resource.get("weapon_type")) in ["ranged", "melee"]


static func is_enhancement_stone(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "enhancement_stone"


static func get_item_display_name(item_resource: Resource) -> String:
	if item_resource == null:
		return "未知物品"
	# 显示名称；优先使用通用 display_name，武器旧资源缺失时回退稳定 weapon_id。
	var display_name: String = str(item_resource.get("display_name"))
	return str(item_resource.get("weapon_id")) if display_name.is_empty() else display_name


static func get_item_type_label(item_resource: Resource) -> String:
	if is_enhancement_stone(item_resource):
		return "资源 · 强化石"
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
	return margin


static func _append_stone_lines(detail_lines: Array[String], item_resource: Resource) -> void:
	detail_lines.append("[b]强化词条[/b]")
	# 强化词典；键为统一属性名，值为百分比小数，按属性名排序保持不同界面显示一致。
	var modifiers: Dictionary = item_resource.get("modifiers") as Dictionary
	# 排序属性键；稳定顺序便于玩家比较相同强化石。
	var modifier_keys: Array[String] = []
	for raw_key in modifiers.keys():
		modifier_keys.append(str(raw_key))
	modifier_keys.sort()
	for modifier_key in modifier_keys:
		# 强化比例；0.1 显示为 +10%，负值使用红色。
		var modifier_ratio: float = float(modifiers.get(modifier_key, 0.0))
		var color_code: String = POSITIVE_COLOR if modifier_ratio >= 0.0 else NEGATIVE_COLOR
		detail_lines.append("%s：[color=%s]%+.1f%%[/color]" % [str(STAT_LABELS.get(modifier_key, modifier_key)), color_code, modifier_ratio * 100.0])


static func _append_weapon_lines(detail_lines: Array[String], item_resource: Resource) -> void:
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
	# 总值颜色；高于基础为绿、低于基础为红、相同为中性色。
	var total_color: String = POSITIVE_COLOR if effective_value > base_value else (NEGATIVE_COLOR if effective_value < base_value else NEUTRAL_COLOR)
	# 差值颜色；正数为绿、负数为红，0 使用中性色。
	var delta_color: String = POSITIVE_COLOR if enhancement_value > 0.0 else (NEGATIVE_COLOR if enhancement_value < 0.0 else NEUTRAL_COLOR)
	# 数值格式；按属性精度生成 0.0 或 0.00 等稳定格式。
	var value_format: String = "%%.%df" % decimals
	# 总值文本；示例为“伤害：1200（1000+200）”，强化差值始终显式带正负号。
	detail_lines.append("%s：[color=%s]%s[/color]（%s[color=%s]%s[/color]）%s" % [
		str(STAT_LABELS.get(stat_name, stat_name)),
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
