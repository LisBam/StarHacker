extends RefCounted
class_name ItemDetailFormatter

## 物品详情格式化器集中生成仓库、背包、装备栏和结算界面的统一悬停信息。
## 武器强化数值使用 RichTextLabel BBCode 着色，同时保留纯文本版本作为系统无富文本环境的兜底。

## 装备套装组件脚本；悬停详情调用其纯统计接口，保证激活颜色与实际套装效果使用同一有效件数规则。
const EQUIPMENT_SET_COMPONENT_SCRIPT: Script = preload("res://scripts/components/equipment_set_component.gd")

## 正强化颜色；默认亮绿色，用于高于基础值的总值与正数强化差值。
const POSITIVE_COLOR: String = "#70e889"
## 负强化颜色；默认亮红色，用于低于基础值的总值与负数强化差值。
const NEGATIVE_COLOR: String = "#ff7070"
## 中性数值颜色；默认浅色，用于尚未强化或与基础值相同的总值。
const NEUTRAL_COLOR: String = "#d8e8ee"
## 未触发套装颜色；默认中灰色，用于低于两件或四件门槛的套装效果文本。
const INACTIVE_SET_COLOR: String = "#8a9298"
## 悬停信息背景颜色；默认深蓝黑且透明度为 0.68，比系统默认背景更通透。
const TOOLTIP_BACKGROUND_COLOR: Color = Color(0.025, 0.04, 0.055, 0.68)
## 悬停信息边框颜色；默认接近纯白，用于在半透明背景外形成清晰轮廓。
const TOOLTIP_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.92)
## 悬停信息边框宽度；默认 2 像素，保证半透明背景在亮色场景中仍有清晰边界。
const TOOLTIP_BORDER_WIDTH: int = 2
## 悬停信息圆角半径；默认 6 像素，使详情框与现有游戏 UI 风格一致。
const TOOLTIP_CORNER_RADIUS: int = 6


static func is_weapon(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) != "enhancement_stone" and str(item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"]


static func is_enhancement_stone(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "enhancement_stone"


static func is_repair_kit(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "repair_kit"


static func is_consumable(item_resource: Resource) -> bool:
	## 判断资源是否为战斗限时消耗品；详情面板使用结构化效果字段展示准确数值。
	return item_resource != null and str(item_resource.get("item_kind")) == "consumable"


static func is_equipment(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("item_kind")) == "equipment"


static func get_item_display_name(item_resource: Resource) -> String:
	if item_resource == null:
		return "未知物品"
	# 显示名称；优先使用通用 display_name，武器旧资源缺失时回退稳定 weapon_id。
	var display_name: String = str(item_resource.get("display_name"))
	if display_name.is_empty():
		display_name = str(item_resource.get("weapon_id"))
	return "%s（损坏）" % display_name if (is_weapon(item_resource) or is_equipment(item_resource)) and item_resource.has_method("is_broken") and bool(item_resource.call("is_broken")) else display_name


static func get_item_type_label(item_resource: Resource) -> String:
	if is_enhancement_stone(item_resource):
		return "资源 · 强化石"
	if is_repair_kit(item_resource):
		return "道具 · 修复包"
	if is_consumable(item_resource):
		return "道具 · 消耗品"
	if is_equipment(item_resource):
		# 部位名称表；四个稳定装备槽映射为玩家可读中文，异常值回退“未知部位”。
		var slot_labels: Dictionary = {"head": "头部", "body": "躯干", "legs": "腿部", "feet": "脚部"}
		# 基础装备类型文本；标准物品卡片会直接显示该行，因此始终包含装备部位。
		var equipment_type_label: String = "装备 · %s" % slot_labels.get(str(item_resource.get("equipment_slot")), "未知部位")
		# 套装数据；配置有效显示名称时追加到类型行，让非悬停状态也能识别装备归属。
		var equipment_set: Resource = item_resource.get("equipment_set") as Resource if _resource_has_property(item_resource, "equipment_set") else null
		if equipment_set != null:
			# 套装显示名称；空值不追加，避免标准卡片出现多余分隔符。
			var set_display_name: String = str(equipment_set.get("display_name")).strip_edges()
			if not set_display_name.is_empty():
				return "%s · %s" % [equipment_type_label, set_display_name]
		return equipment_type_label
	# 武器类型；ranged 与 melee 分别映射到仓库武器子分类。
	var weapon_type: String = str(item_resource.get("weapon_type")) if item_resource != null else ""
	return "武器 · 远程" if weapon_type == "ranged" else ("武器 · 近战" if weapon_type == "melee" else ("武器 · 远程+近战" if weapon_type == "hybrid" else "未知"))


static func get_item_value(item_resource: Resource) -> int:
	if item_resource == null:
		return 0
	if item_resource.has_method("get_effective_value"):
		return maxi(int(item_resource.call("get_effective_value")), 0)
	return maxi(int(item_resource.get("value")), 0)


static func build_plain_text(item_resource: Resource, quantity: int = 1, value_label: String = "价值", total_value_override: int = -1) -> String:
	return _strip_bbcode(build_bbcode(item_resource, quantity, value_label, total_value_override))


static func build_bbcode(item_resource: Resource, quantity: int = 1, value_label: String = "价值", total_value_override: int = -1) -> String:
	if item_resource == null:
		return "物品数据不可用"
	# 详情文本行；首部统一显示名称、分类、数量与价值，后续按资源类型追加字段。
	var detail_lines: Array[String] = []
	detail_lines.append("[font_size=18][b]%s[/b][/font_size]" % get_item_display_name(item_resource))
	detail_lines.append("类型：%s" % get_item_type_label(item_resource))
	if quantity > 1 or is_enhancement_stone(item_resource):
		detail_lines.append("数量：%d / 99" % maxi(quantity, 1))
	# 单件价值；资源堆叠额外展示整组价值，避免菜单摘要与详情不一致。
	var unit_value: int = get_item_value(item_resource)
	# 详情价值；普通界面显示价值，物资撤离界面传入实际撤离收费覆盖值。
	var displayed_total_value: int = total_value_override if total_value_override >= 0 else unit_value * maxi(quantity, 1)
	# 单值补充；仅普通价值且堆叠数量大于 1 时显示，撤离收费已经包含整组向上取整结果。
	var unit_value_suffix: String = "（单个 %d）" % unit_value if value_label == "价值" and quantity > 1 else ""
	detail_lines.append("%s：%d 金币%s" % [value_label, displayed_total_value, unit_value_suffix])
	# 物品说明；空说明不生成无意义空行。
	var description: String = str(item_resource.get("description"))
	if not description.is_empty():
		detail_lines.append(description)

	if is_enhancement_stone(item_resource):
		_append_stone_lines(detail_lines, item_resource)
	elif is_repair_kit(item_resource):
		_append_repair_kit_lines(detail_lines, item_resource)
	elif is_consumable(item_resource):
		_append_consumable_lines(detail_lines, item_resource)
	elif is_weapon(item_resource):
		_append_weapon_lines(detail_lines, item_resource)
	elif is_equipment(item_resource):
		_append_equipment_lines(detail_lines, item_resource)
	return "\n".join(detail_lines)


static func _append_equipment_lines(detail_lines: Array[String], item_resource: Resource) -> void:
	# 当前耐久；取值限制在 0 到最大耐久，与武器详情使用相同的“当前 / 最大”格式。
	var current_durability: float = maxf(float(item_resource.get("current_durability")), 0.0)
	# 最大耐久；取值至少为 1，确保装备详情始终明确显示耐久上限。
	var max_durability: float = float(item_resource.call("get_maximum_durability")) if item_resource.has_method("get_maximum_durability") else maxf(float(item_resource.get("max_durability")), 1.0)
	detail_lines.append("耐久：%.1f / %.1f" % [current_durability, max_durability])
	if item_resource.has_method("is_broken") and bool(item_resource.call("is_broken")):
		detail_lines.append("[color=%s]状态：损坏，全部装备属性失效[/color]" % NEGATIVE_COLOR)
	_append_equipment_set_lines(detail_lines, item_resource)
	# 装备属性规格；每项依次保存属性名、小数位、单位后缀和显示倍率，百分比字段统一乘 100 后追加 %。
	var stat_specs: Array[Array] = [
		["attack_power", 1, "", 1.0],
		["defense_power", 1, "", 1.0],
		["max_health", 1, "", 1.0],
		["health_regeneration_per_five_seconds", 1, "", 1.0],
		["energy_regeneration", 1, "", 1.0],
		["dodge_chance", 1, "%", 100.0],
		["cooldown_reduction", 1, "%", 100.0],
		["move_speed", 0, "%", 100.0],
		["vision_range", 0, "%", 100.0],
		["critical_chance", 0, "%", 100.0],
		["critical_damage", 0, "%", 100.0],
	]
	detail_lines.append("[b]装备属性[/b]")
	for stat_spec in stat_specs:
		# 属性规格字段；统一交给武器同款格式化函数生成颜色、基础值和强化差值括号。
		var stat_name: String = str(stat_spec[0])
		# 属性小数位；普通装备数值保留 1 位，百分比属性显示整数百分比。
		var decimals: int = int(stat_spec[1])
		# 属性单位；百分比字段为 %，普通数值为空字符串。
		var suffix: String = str(stat_spec[2])
		# 显示倍率；底层百分比小数乘 100 后再进入统一文本格式化流程。
		var display_multiplier: float = float(stat_spec[3])
		# 零值显示规则；腿部的冷却缩减即使基础为 0% 也需要显示，便于玩家识别该部位可被对应强化石提升。
		var skip_zero_unmodified: bool = not (stat_name == "cooldown_reduction" and str(item_resource.get("equipment_slot")) == "legs")
		_append_weapon_stat_line(detail_lines, item_resource, stat_name, decimals, suffix, display_multiplier, skip_zero_unmodified)


static func _append_equipment_set_lines(detail_lines: Array[String], item_resource: Resource) -> void:
	## 追加装备所属套装与两个档位效果；已达到门槛显示绿色，未达到门槛显示灰色。
	# 当前防具快照；读取 GlobalInventory 公开接口，悬停仓库或背包中的套装件时仍以身上装备为准。
	var armor_equipment: Dictionary = _get_equipped_armor_resources()
	_append_equipment_set_lines_from_snapshot(detail_lines, item_resource, armor_equipment)


static func build_equipment_set_bbcode(item_resource: Resource, armor_equipment: Dictionary) -> String:
	## 使用调用方提供的防具快照构建套装详情片段；供确定性测试和不依赖 AutoLoad 的预览界面复用。
	# 套装详情行；结构与正式悬停框完全一致，只省略物品名称、价值和普通属性。
	var detail_lines: Array[String] = []
	_append_equipment_set_lines_from_snapshot(detail_lines, item_resource, armor_equipment)
	return "\n".join(detail_lines)


static func _append_equipment_set_lines_from_snapshot(detail_lines: Array[String], item_resource: Resource, armor_equipment: Dictionary) -> void:
	## 使用明确装备快照追加套装行；正式悬停和测试入口共享颜色、文本与门槛判断。
	# 套装数据；基础装备未配置引用时保持空结果。
	var equipment_set: Resource = item_resource.get("equipment_set") as Resource if _resource_has_property(item_resource, "equipment_set") else null
	if equipment_set == null or not equipment_set.has_method("get_tier_definitions"):
		return
	# 套装稳定标识；空 ID 不参与件数统计。
	var set_id: String = str(equipment_set.get("set_id")).strip_edges()
	if set_id.is_empty():
		return
	# 当前有效件数；损坏装备由套装组件统一排除。
	var active_piece_count: int = int(EQUIPMENT_SET_COMPONENT_SCRIPT.call("get_active_piece_count_for_set", armor_equipment, set_id))
	# 套装显示名称；缺失时回退稳定 ID。
	var set_display_name: String = str(equipment_set.get("display_name")).strip_edges()
	if set_display_name.is_empty():
		set_display_name = set_id
	detail_lines.append("[b]所属套装：%s（当前 %d 件）[/b]" % [set_display_name, active_piece_count])
	# 套装档位遍历项；保持数据资源原始顺序。
	for raw_tier_definition in equipment_set.call("get_tier_definitions") as Array[Dictionary]:
		# 套装档位定义；包含触发件数和效果原文。
		var tier_definition: Dictionary = raw_tier_definition as Dictionary
		# 触发件数；至少为 1，用于标题和激活判断。
		var required_count: int = maxi(int(tier_definition.get("required_count", 1)), 1)
		# 效果原文；空文本不创建档位行。
		var effect_description: String = str(tier_definition.get("description", ""))
		if effect_description.is_empty():
			continue
		# 档位颜色；达到门槛为绿色，否则为灰色。
		var tier_color: String = POSITIVE_COLOR if active_piece_count >= required_count else INACTIVE_SET_COLOR
		# 档位标题；标准两件套与四件套保持内容文档原始中文，其余可配置门槛使用数字标题。
		var tier_title: String = "两件套效果" if required_count == 2 else ("四件套效果" if required_count == 4 else "%d件套效果" % required_count)
		detail_lines.append("[color=%s]%s：%s[/color]" % [tier_color, tier_title, effect_description])


static func _get_equipped_armor_resources() -> Dictionary:
	## 从运行中的全局库存读取装备栏快照；脱离 SceneTree 的格式化测试安全回退为空装备。
	# 主循环；只有 SceneTree 才能访问 AutoLoad 根节点，编辑器资源预览等环境可能为空。
	var main_loop: MainLoop = Engine.get_main_loop()
	# 场景树；类型转换失败时表示当前没有可用运行时装备状态。
	var scene_tree: SceneTree = main_loop as SceneTree
	if scene_tree == null:
		return {}
	# 全局库存服务；统一拥有四部位装备记录，详情格式化器只读取公开资源快照。
	var global_inventory: Node = scene_tree.root.get_node_or_null("GlobalInventory")
	if global_inventory != null and global_inventory.has_method("get_armor_equipment_resources"):
		return global_inventory.call("get_armor_equipment_resources") as Dictionary
	return {}


static func _resource_has_property(content_resource: Resource, property_name: String) -> bool:
	## 判断兼容物品资源是否公开指定字段；缺少套装字段的旧装备继续按基础装备显示。
	if content_resource == null:
		return false
	# 属性描述遍历项；统一检查脚本导出字段与内置属性名。
	for property_info in content_resource.get_property_list():
		if str((property_info as Dictionary).get("name", "")) == property_name:
			return true
	return false


static func create_tooltip_control(item_resource: Resource, quantity: int = 1, value_label: String = "价值", total_value_override: int = -1) -> Control:
	# 富文本详情；由 Godot 自定义 tooltip 承载，fit_content 保证内容按文本高度完整展开。
	var detail_label: RichTextLabel = RichTextLabel.new()
	detail_label.bbcode_enabled = true
	detail_label.fit_content = true
	detail_label.scroll_active = false
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.custom_minimum_size = Vector2(330.0, 0.0)
	detail_label.text = build_bbcode(item_resource, quantity, value_label, total_value_override)

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
	var modifiers: Dictionary = item_resource.call("get_normalized_modifiers") as Dictionary if item_resource.has_method("get_normalized_modifiers") else EnhancementRules.normalize_modifiers(item_resource.get("modifiers") as Dictionary, str(item_resource.get("quality_id")) == EnhancementRules.QUALITY_SPECIALIZED)
	_append_stone_lines_by_benefit(detail_lines, modifiers, true)
	_append_stone_lines_by_benefit(detail_lines, modifiers, false)


static func _append_repair_kit_lines(detail_lines: Array[String], item_resource: Resource) -> void:
	# 修复量；取值至少为 0，显示为整数以匹配所有当前修复包的固定耐久数值。
	var repair_amount: float = maxf(float(item_resource.get("repair_amount")), 0.0)
	detail_lines.append("[b]使用效果[/b]")
	detail_lines.append("可对武器或装备使用")
	detail_lines.append("恢复耐久：%.0f" % repair_amount)


static func _append_consumable_lines(detail_lines: Array[String], item_resource: Resource) -> void:
	## 追加消耗品结构化效果；优先使用资源方法，兼容资源缺少方法时回退说明文本。
	detail_lines.append("[b]使用效果[/b]")
	# 效果摘要；由 ConsumableData 根据属性类型、数值与持续时间生成，确保显示与运行时字段一致。
	var effect_description: String = str(item_resource.call("get_effect_description")) if item_resource.has_method("get_effect_description") else str(item_resource.get("description"))
	detail_lines.append(effect_description)


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
		# 词条颜色；按玩法利弊渲染，冷却-、能耗-、偏移-和后坐力-等降低型增益统一显示绿色。
		var color_code: String = POSITIVE_COLOR if beneficial else NEGATIVE_COLOR
		detail_lines.append("[color=%s]%s[/color]" % [color_code, EnhancementRules.build_modifier_token(modifier_key, modifier_direction, false)])


static func _append_weapon_lines(detail_lines: Array[String], item_resource: Resource) -> void:
	# 当前耐久；取值限制在 0 到最大耐久，用于详情显示与损坏状态说明。
	var current_durability: float = maxf(float(item_resource.get("current_durability")), 0.0)
	# 最大耐久；取值至少为 1，避免旧资源字段缺失造成无效比例。
	var max_durability: float = float(item_resource.call("get_maximum_durability")) if item_resource.has_method("get_maximum_durability") else maxf(float(item_resource.get("max_durability")), 1.0)
	# 单次耐久消耗；每把武器独立配置，成功射击或近战使用时按该浮点数扣除。
	# 固定消耗显示补充：耐久成本由普通/混合类型规则固定决定，不是资源可强化字段，因此详情不重复展示“耐久消耗”属性行。
	detail_lines.append("耐久：%.1f / %.1f" % [current_durability, max_durability])
	if item_resource.has_method("is_broken") and bool(item_resource.call("is_broken")):
		detail_lines.append("[color=%s]状态：损坏，无法使用[/color]" % NEGATIVE_COLOR)
	# 武器类型；决定伤害、冷却及远近战专属属性的基础字段映射。
	var weapon_type: String = str(item_resource.get("weapon_type"))
	if weapon_type == "hybrid":
		_append_weapon_attack_channel_stat_line(detail_lines, item_resource, "远程伤害", "damage", "ranged", 1)
		_append_weapon_attack_channel_stat_line(detail_lines, item_resource, "近战伤害", "damage", "melee", 1)
	else:
		_append_weapon_stat_line(detail_lines, item_resource, "damage", 1)
	_append_weapon_stat_line(detail_lines, item_resource, "cooldown", 2, " 秒")
	_append_weapon_stat_line(detail_lines, item_resource, "energy_consumption", 0)
	if weapon_type == "hybrid":
		_append_weapon_attack_channel_stat_line(detail_lines, item_resource, "远程距离", "attack_distance", "ranged", 1)
		_append_weapon_attack_channel_stat_line(detail_lines, item_resource, "近战距离", "attack_distance", "melee", 1)
	else:
		_append_weapon_stat_line(detail_lines, item_resource, "attack_distance", 1)
	# 暴击属性；与其他武器、装备属性共用统一颜色和括号变化明细，底层小数乘 100 后显示百分比。
	_append_weapon_stat_line(detail_lines, item_resource, "critical_chance", 0, "%", 100.0)
	_append_weapon_stat_line(detail_lines, item_resource, "critical_damage", 0, "%", 100.0)
	if weapon_type in ["ranged", "hybrid"]:
		_append_weapon_stat_line(detail_lines, item_resource, "projectile_speed", 1)
		_append_weapon_stat_line(detail_lines, item_resource, "deviation_degrees", 1, "°")
		if _weapon_has_effective_attribute(item_resource, "has_scatter"):
			_append_weapon_stat_line(detail_lines, item_resource, "scatter_count", 0)
		if _weapon_has_effective_attribute(item_resource, "has_piercing"):
			_append_weapon_stat_line(detail_lines, item_resource, "piercing_count", 0)
		if _weapon_has_effective_attribute(item_resource, "has_bounce"):
			_append_weapon_stat_line(detail_lines, item_resource, "bounce_count", 0)
		if _weapon_has_effective_attribute(item_resource, "has_combo"):
			_append_weapon_stat_line(detail_lines, item_resource, "combo_count", 0)
	if weapon_type in ["melee", "hybrid"]:
		_append_weapon_stat_line(detail_lines, item_resource, "melee_active_duration", 2, " 秒")
	if bool(item_resource.get("has_recoil")):
		_append_weapon_stat_line(detail_lines, item_resource, "recoil_force", 1)
	if bool(item_resource.get("has_front_recoil")):
		_append_weapon_stat_line(detail_lines, item_resource, "front_recoil_force", 1)
	if weapon_type == "hybrid":
		_append_weapon_attack_channel_stat_line(detail_lines, item_resource, "远程冲击", "impact_force", "ranged", 1)
		_append_weapon_attack_channel_stat_line(detail_lines, item_resource, "近战冲击", "impact_force", "melee", 1)
	else:
		_append_weapon_stat_line(detail_lines, item_resource, "impact_force", 1)


static func _weapon_has_effective_attribute(item_resource: Resource, attribute_property_name: String) -> bool:
	## 返回详情面板是否应展示指定武器机制；特化新增机制与模板原生机制使用同一入口。
	if item_resource == null:
		return false
	if item_resource.has_method("has_effective_attribute"):
		return bool(item_resource.call("has_effective_attribute", attribute_property_name))
	return bool(item_resource.get(attribute_property_name))


static func _append_weapon_attack_channel_stat_line(detail_lines: Array[String], item_resource: Resource, label: String, stat_name: String, attack_mode: String, decimals: int, suffix: String = "") -> void:
	## 追加混合武器单一攻击通道属性；基础值独立、强化比例共享，显示时仍分别给出真实强化前后值。
	# 基础字段名；伤害本来就分通道保存，距离与冲击使用混合武器专属字段。
	var property_name: String = ("ranged_damage" if attack_mode == "ranged" else "melee_damage") if stat_name == "damage" else (("ranged_attack_distance" if attack_mode == "ranged" else "melee_attack_distance") if stat_name == "attack_distance" else ("ranged_impact_force" if attack_mode == "ranged" else "melee_impact_force"))
	# 通道基础值；资源字段缺失时按 0 处理，现行 hybrid 资源必须显式填写全部六个基础值。
	var base_value: float = maxf(float(item_resource.get(property_name)), 0.0)
	# 通道有效值；优先使用武器统一双通道接口，兼容资源缺失时回退基础值。
	var effective_value: float = float(item_resource.call("get_effective_attack_stat", stat_name, attack_mode)) if item_resource.has_method("get_effective_attack_stat") else base_value
	# 强化差值；两个通道读取同一累计比例，但各自按基础值换算实际变化量。
	var enhancement_value: float = effective_value - base_value
	# 玩法颜色；伤害、距离和冲击提高均为增益，减少均为减益。
	var total_color: String = (POSITIVE_COLOR if enhancement_value > 0.0 else NEGATIVE_COLOR) if not is_zero_approx(enhancement_value) else NEUTRAL_COLOR
	# 数值格式；由调用方控制小数位，保持与普通武器详情一致。
	var value_format: String = "%%.%df" % decimals
	if is_zero_approx(enhancement_value):
		detail_lines.append("%s：[color=%s]%s[/color]%s" % [label, total_color, value_format % effective_value, suffix])
		return
	detail_lines.append("%s：[color=%s]%s[/color]（%s[color=%s]%s[/color]）%s" % [label, total_color, value_format % effective_value, value_format % base_value, total_color, ("+" if enhancement_value >= 0.0 else "") + (value_format % enhancement_value), suffix])


static func _append_weapon_stat_line(detail_lines: Array[String], item_resource: Resource, stat_name: String, decimals: int, suffix: String = "", display_multiplier: float = 1.0, skip_zero_unmodified: bool = false) -> void:
	# 基础值；优先调用 WeaponData 统一接口，旧资源回退直接字段读取。
	var base_value: float = float(item_resource.call("get_base_stat", stat_name)) if item_resource.has_method("get_base_stat") else 0.0
	# 有效值；包含累计强化比例，所有战斗组件与详情都读取同一结果。
	var effective_value: float = float(item_resource.call("get_effective_stat", stat_name)) if item_resource.has_method("get_effective_stat") else base_value
	# 强化差值；只用于展示，不覆盖武器基础资源字段。
	var enhancement_value: float = effective_value - base_value
	# 空属性跳过规则；装备只显示基础值、最终值或强化差值至少一项非零的有效属性，武器保持完整固定属性表。
	if skip_zero_unmodified and is_zero_approx(base_value) and is_zero_approx(effective_value) and is_zero_approx(enhancement_value):
		return
	# 强化是否为玩法增益；数值降低不等于减益，冷却、能耗、偏移和后坐力降低均按规则目录判定为增益。
	var enhancement_is_beneficial: bool = not is_zero_approx(enhancement_value) and EnhancementRules.is_direction_beneficial(stat_name, enhancement_value)
	# 总值颜色；存在强化时按玩法收益显示绿色或红色，未变化时使用中性色。
	var total_color: String = (POSITIVE_COLOR if enhancement_is_beneficial else NEGATIVE_COLOR) if not is_zero_approx(enhancement_value) else NEUTRAL_COLOR
	# 差值颜色；与总值使用同一玩法收益判断，避免冷却减少等正收益被误标为红色。
	var delta_color: String = total_color
	# 数值格式；按属性精度生成 0.0 或 0.00 等稳定格式。
	var value_format: String = "%%.%df" % decimals
	# 显示基础值；百分比字段乘 100，普通数值保持原始单位。
	var displayed_base_value: float = base_value * display_multiplier
	# 显示有效值；与基础值使用相同倍率，保证括号内外单位一致。
	var displayed_effective_value: float = effective_value * display_multiplier
	# 显示强化差值；由有效值减基础值得到，并使用相同倍率保留真实本次累计变化量。
	var displayed_enhancement_value: float = enhancement_value * display_multiplier
	# 总值文本；示例为“伤害：1200（1000+200）”，强化差值始终显式带正负号。
	if is_zero_approx(enhancement_value):
		detail_lines.append("%s：[color=%s]%s[/color]%s" % [EnhancementRules.get_stat_label(stat_name), total_color, value_format % displayed_effective_value, suffix])
		return
	# 有强化变化时才显示括号中的基础值和强化差值，避免出现“（100+0.0）”无效信息。
	detail_lines.append("%s：[color=%s]%s[/color]（%s[color=%s]%s[/color]）%s" % [
		EnhancementRules.get_stat_label(stat_name),
		total_color,
		value_format % displayed_effective_value,
		value_format % displayed_base_value,
		delta_color,
		("+" if displayed_enhancement_value >= 0.0 else "") + (value_format % displayed_enhancement_value),
		suffix,
	])


static func _strip_bbcode(bbcode_text: String) -> String:
	# BBCode 标签正则；只移除格式标签并保留原文字，供 tooltip_text 和无富文本环境使用。
	var tag_regex: RegEx = RegEx.new()
	tag_regex.compile("\\[[^\\]]+\\]")
	return tag_regex.sub(bbcode_text, "", true)
