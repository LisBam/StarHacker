extends VBoxContainer
class_name CharacterStatsPanel

## 角色属性面板统一展示角色基础值、有效装备加成与最终总值。
## 战斗中读取运行时组件快照，主菜单中读取角色档案与全局装备，保证共享背包在两种上下文下均可复用。

## 装备套装组件脚本；局外属性页调用其纯统计接口，确保套装属性与战斗组件使用同一触发规则。
const EQUIPMENT_SET_COMPONENT_SCRIPT: Script = preload("res://scripts/components/equipment_set_component.gd")

## 属性行显示顺序；键用于读取快照，名称用于生成长期稳定的中文界面。
const ATTRIBUTE_ROWS: Array[Dictionary] = [
	{"key": "max_energy", "label": "能量上限", "percent": false},
	{"key": "attack_power", "label": "攻击力", "percent": false},
	{"key": "defense_power", "label": "防御力", "percent": false},
	{"key": "health_regeneration_per_five_seconds", "label": "每 5 秒回血", "percent": false},
	{"key": "move_speed", "label": "移速", "percent": false},
	{"key": "vision_range", "label": "视野", "percent": true},
	{"key": "dodge_chance", "label": "闪避率", "percent": true},
	{"key": "cooldown_reduction", "label": "冷却缩减", "percent": true},
	{"key": "energy_regeneration", "label": "能量恢复", "percent": false}
]

## 战斗属性组件；默认空表示主菜单上下文，存在时提供实时生命和战斗属性快照。
var _stats_component: Node
## 装备组件；默认空表示主菜单上下文，存在时提供实际移速与视野快照。
var _equipment_component: Node
## 玩家控制器；默认空表示主菜单上下文，用于读取并监听技能固定移速属性来源。
var _player_controller: Node
## 全局库存服务；主菜单属性页通过它读取当前四部位装备，战斗中仍保留作为安全兜底。
var _global_inventory: Node
## 会话状态服务；用于读取当前选中角色及其基础属性档案。
var _session_state: Node
## 属性行标签表；键为稳定属性名，值为运行时标签，刷新时只更新文本而不重建控件。
var _attribute_labels: Dictionary = {}
## 生命属性标签；单独显示“当前生命 / 总上限（基础上限+装备上限）”。
var _health_label: Label
## 角色名称标签；显示当前选中角色，帮助玩家确认属性归属。
var _character_name_label: Label


func _ready() -> void:
	_global_inventory = get_tree().root.get_node_or_null("GlobalInventory")
	_session_state = get_tree().root.get_node_or_null("SessionState")
	_build_interface()
	refresh()


func configure_runtime_components(stats_component: Node, equipment_component: Node) -> void:
	## 注入战斗中的角色组件；主菜单不调用此方法并自动使用角色档案与全局装备计算。
	if _stats_component != null and _stats_component.has_signal("stats_changed") and _stats_component.is_connected("stats_changed", Callable(self, "refresh")):
		_stats_component.disconnect("stats_changed", Callable(self, "refresh"))
	if _player_controller != null and _player_controller.has_signal("movement_speed_attribute_bonus_changed") and _player_controller.is_connected("movement_speed_attribute_bonus_changed", Callable(self, "refresh")):
		_player_controller.disconnect("movement_speed_attribute_bonus_changed", Callable(self, "refresh"))
	_stats_component = stats_component
	_equipment_component = equipment_component
	_player_controller = _stats_component.get_parent() if _stats_component != null else null
	if _stats_component != null and _stats_component.has_signal("stats_changed") and not _stats_component.is_connected("stats_changed", Callable(self, "refresh")):
		_stats_component.connect("stats_changed", Callable(self, "refresh"))
	if _player_controller != null and _player_controller.has_signal("movement_speed_attribute_bonus_changed") and not _player_controller.is_connected("movement_speed_attribute_bonus_changed", Callable(self, "refresh")):
		_player_controller.connect("movement_speed_attribute_bonus_changed", Callable(self, "refresh"))
	if is_node_ready():
		refresh()


func refresh() -> void:
	## 刷新全部属性文本；装备变化、角色切换或背包重新打开时由宿主调用。
	if _health_label == null:
		return
	# 完整属性快照；每项包含 total、base 与 equipment 三个数值。
	var snapshot: Dictionary = _get_runtime_snapshot() if _stats_component != null else _get_menu_snapshot()
	# 角色档案；仅用于显示当前角色名称，缺失时安全回退为“当前角色”。
	var character_profile: Dictionary = _get_character_profile()
	_character_name_label.text = str(character_profile.get("display_name", "当前角色"))
	# 生命结构；基础上限与装备加成均来自统一快照，当前生命在局外按满生命显示。
	var health_values: Dictionary = snapshot.get("max_health", {"total": 0.0, "base": 0.0, "equipment": 0.0})
	var current_health: float = float(snapshot.get("current_health", health_values.get("total", 0.0)))
	_health_label.text = "生命值 / 生命上限：%s / %s（%s+%s）" % [
		_format_number(current_health),
		_format_number(float(health_values.get("total", 0.0))),
		_format_number(float(health_values.get("base", 0.0))),
		_format_number(float(health_values.get("equipment", 0.0)))
	]
	for row_definition in ATTRIBUTE_ROWS:
		# 属性键；用于从快照和标签表读取同一属性。
		var attribute_key: String = str(row_definition.get("key", ""))
		# 属性值结构；缺失数据统一显示 0（0+0），不会阻断其他属性刷新。
		var attribute_values: Dictionary = snapshot.get(attribute_key, {"total": 0.0, "base": 0.0, "equipment": 0.0})
		# 属性标签；创建界面时已登记，异常键只跳过当前行。
		var value_label: Label = _attribute_labels.get(attribute_key) as Label
		if value_label == null:
			continue
		# 是否使用百分比；视野和闪避率将内部比例转换为玩家易读的百分点。
		# 冷却缩减同样使用内部比例；新属性沿用既有百分比格式，确保 0.05 在角色面板显示为 5%。
		var is_percent: bool = bool(row_definition.get("percent", false))
		# 套装、技能与临时额外值；非零来源分别标注，避免百分比套装或消耗品被误归入装备点数。
		var set_value: float = float(attribute_values.get("set", 0.0))
		var skill_value: float = float(attribute_values.get("skill", 0.0))
		var temporary_value: float = float(attribute_values.get("temporary", 0.0))
		# 分项文本；基础与装备始终显示，其他运行时来源仅在非零时追加。
		var value_parts: PackedStringArray = PackedStringArray([
			_format_attribute_value(float(attribute_values.get("base", 0.0)), is_percent),
			_format_attribute_value(float(attribute_values.get("equipment", 0.0)), is_percent),
		])
		if not is_zero_approx(set_value):
			value_parts.append("套装%s" % _format_attribute_value(set_value, is_percent))
		if not is_zero_approx(skill_value):
			value_parts.append("技能%s" % _format_attribute_value(skill_value, is_percent))
		if not is_zero_approx(temporary_value):
			value_parts.append("临时%s" % _format_attribute_value(temporary_value, is_percent))
		value_label.text = "%s：%s（%s）" % [str(row_definition.get("label", attribute_key)), _format_attribute_value(float(attribute_values.get("total", 0.0)), is_percent), "+".join(value_parts)]


func _build_interface() -> void:
	## 创建固定属性行，后续刷新只改文本，避免背包信号频繁触发节点重建。
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 9)
	_character_name_label = Label.new()
	_character_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_character_name_label.add_theme_font_size_override("font_size", 20)
	add_child(_character_name_label)
	_health_label = _create_attribute_label()
	add_child(_health_label)
	for row_definition in ATTRIBUTE_ROWS:
		# 新建属性标签；每个稳定属性键只对应一行。
		var attribute_label: Label = _create_attribute_label()
		_attribute_labels[str(row_definition.get("key", ""))] = attribute_label
		add_child(attribute_label)


func _create_attribute_label() -> Label:
	## 创建可自动换行的属性文本，窄装备栏中仍完整显示三值表达式。
	# 属性标签；默认最小高度 28，提供稳定行距并允许长文本换行。
	var attribute_label: Label = Label.new()
	attribute_label.custom_minimum_size = Vector2(0.0, 28.0)
	attribute_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return attribute_label


func _get_runtime_snapshot() -> Dictionary:
	## 合并战斗属性组件与装备组件快照，生命值使用实时状态。
	# 战斗快照；包含生命、能量、攻防、恢复和闪避属性。
	var snapshot: Dictionary = _stats_component.call("get_character_attribute_snapshot") as Dictionary if _stats_component.has_method("get_character_attribute_snapshot") else {}
	if _equipment_component != null and _equipment_component.has_method("get_character_attribute_snapshot"):
		# 装备运行快照；移速已换算为实际点数，视野保留比例供百分比格式化。
		var equipment_snapshot: Dictionary = _equipment_component.call("get_character_attribute_snapshot") as Dictionary
		snapshot.merge(equipment_snapshot, true)
	if _player_controller != null and _player_controller.has_method("get_movement_speed_attribute_bonus") and snapshot.get("move_speed") is Dictionary:
		# 移速技能快照；二倍速等固定点数来源独立标记为“技能”，并加入消耗品倍率计算前的当前移速。
		var move_speed_values: Dictionary = (snapshot.get("move_speed") as Dictionary).duplicate()
		# 技能移速点数；满强度二倍速为 99，受击衰减时随来源信号即时刷新。
		var skill_move_speed: float = maxf(float(_player_controller.call("get_movement_speed_attribute_bonus")), 0.0)
		move_speed_values["skill"] = skill_move_speed
		move_speed_values["total"] = maxf(float(move_speed_values.get("total", 0.0)) + skill_move_speed, 0.0)
		snapshot["move_speed"] = move_speed_values
	# 临时增益组件；移速饮料作用于装备结算后的有效移速，单独写入 temporary 供界面标注。
	var temporary_buff_component: Node = _stats_component.get_parent().get_node_or_null("TemporaryBuffComponent") if _stats_component.get_parent() != null else null
	if temporary_buff_component != null and temporary_buff_component.has_method("get_move_speed_multiplier") and snapshot.get("move_speed") is Dictionary:
		# 移速快照；装备组件已经提供基础、装备和合计值，在其合计上应用消耗品倍率。
		var move_speed_values: Dictionary = (snapshot.get("move_speed") as Dictionary).duplicate()
		# 临时移速点数；倍率 1.1 表示当前基础与装备合计值的 10%。
		var temporary_move_speed: float = float(move_speed_values.get("total", 0.0)) * (maxf(float(temporary_buff_component.call("get_move_speed_multiplier")), 0.0) - 1.0)
		move_speed_values["temporary"] = temporary_move_speed
		move_speed_values["total"] = maxf(float(move_speed_values.get("total", 0.0)) + temporary_move_speed, 0.0)
		snapshot["move_speed"] = move_speed_values
	return snapshot


func _get_menu_snapshot() -> Dictionary:
	## 根据角色档案和当前有效防具构建局外快照；损坏装备不提供任何属性。
	# 角色档案；包含主菜单所需的全部基础属性。
	var profile: Dictionary = _get_character_profile()
	# 装备聚合属性；只统计四部位当前有效装备。
	var equipment_attributes: Dictionary = _get_menu_equipment_attributes()
	# 基础移速；用于把装备比例换算为实际速度点数。
	var base_move_speed: float = float(profile.get("move_speed", 0.0))
	# 装备移速点数；脚部比例乘以角色基础速度，与战斗组件公式一致。
	var equipment_move_speed: float = base_move_speed * maxf(float(equipment_attributes.get("move_speed", 0.0)), 0.0)
	# 属性快照；局外没有受伤状态，当前生命等于含装备加成的总生命上限。
	var snapshot: Dictionary = {}
	for attribute_key in ["max_health", "attack_power", "defense_power", "health_regeneration_per_five_seconds", "dodge_chance", "cooldown_reduction", "energy_regeneration"]:
		# 基础属性；每 5 秒回血、闪避默认为 0，能量恢复由角色档案提供每秒 15 点并支持 0.1 精度。
		var base_value: float = float(profile.get(attribute_key, 0.0))
		# 装备属性；由有效四部位装备直接加算。
		var equipment_value: float = float(equipment_attributes.get(attribute_key, 0.0))
		snapshot[attribute_key] = _build_value_snapshot(base_value, equipment_value)
	# 局外套装最终倍率；与战斗属性组件使用同一纯计算入口，拾荒者两件套等百分比效果单独标注为套装值。
	var armor_equipment: Dictionary = _global_inventory.call("get_armor_equipment_resources") as Dictionary if _global_inventory != null and _global_inventory.has_method("get_armor_equipment_resources") else {}
	# 套装倍率字典；值为额外比例，例如 defense_power=0.2 表示基础与装备合计防御提高20%。
	var set_multipliers: Dictionary = EQUIPMENT_SET_COMPONENT_SCRIPT.call("calculate_active_attribute_multipliers", armor_equipment) as Dictionary
	for attribute_key in ["attack_power", "defense_power"]:
		# 原属性快照；循环阶段已经保存基础、装备和未乘套装的合计值。
		var attribute_values: Dictionary = (snapshot.get(attribute_key, {}) as Dictionary).duplicate()
		# 套装额外值；只计算当前属性声明的最终倍率，未声明时保持0。
		var set_value: float = float(attribute_values.get("total", 0.0)) * float(set_multipliers.get(attribute_key, 0.0))
		attribute_values["set"] = set_value
		attribute_values["total"] = maxf(float(attribute_values.get("total", 0.0)) + set_value, 0.0)
		snapshot[attribute_key] = attribute_values
	snapshot["max_energy"] = _build_value_snapshot(float(profile.get("max_energy", 0.0)), 0.0)
	snapshot["move_speed"] = _build_value_snapshot(base_move_speed, equipment_move_speed)
	snapshot["vision_range"] = _build_value_snapshot(float(profile.get("vision_range", 0.0)), float(equipment_attributes.get("vision_range", 0.0)))
	snapshot["current_health"] = float((snapshot.get("max_health") as Dictionary).get("total", 0.0))
	return snapshot


func _get_menu_equipment_attributes() -> Dictionary:
	## 聚合局外四部位装备的角色面板属性，严格跳过损坏装备。
	# 聚合属性；键与装备数据字段及角色面板快照保持一致。
	var attributes: Dictionary = {"attack_power": 0.0, "defense_power": 0.0, "max_health": 0.0, "health_regeneration_per_five_seconds": 0.0, "energy_regeneration": 0.0, "dodge_chance": 0.0, "cooldown_reduction": 0.0, "move_speed": 0.0, "vision_range": 0.0}
	if _global_inventory == null or not _global_inventory.has_method("get_armor_equipment_resources"):
		return attributes
	# 四部位装备；键为 head、body、legs、feet，值允许为空。
	var armor_equipment: Dictionary = _global_inventory.call("get_armor_equipment_resources") as Dictionary
	for armor_slot in ["head", "body", "legs", "feet"]:
		# 当前部位装备；空槽和已损坏装备不提供属性。
		var equipment_data: Resource = armor_equipment.get(armor_slot) as Resource
		if equipment_data == null or (equipment_data.has_method("is_broken") and bool(equipment_data.call("is_broken"))):
			continue
		for attribute_key in attributes.keys():
			# 有效装备属性；优先走强化后的统一取值接口。
			var equipment_value: float = float(equipment_data.call("get_effective_stat", attribute_key)) if equipment_data.has_method("get_effective_stat") else float(equipment_data.get(attribute_key))
			attributes[attribute_key] = float(attributes.get(attribute_key, 0.0)) + equipment_value
	# 套装属性加成；局外与战斗都只统计已穿戴且未损坏部件，并只合并角色面板已支持的属性键。
	var set_attribute_bonuses: Dictionary = EQUIPMENT_SET_COMPONENT_SCRIPT.call("calculate_active_attribute_bonuses", armor_equipment) as Dictionary
	for raw_attribute_key in set_attribute_bonuses.keys():
		# 套装属性键；未知特殊效果不进入数值面板，由其负责组件单独消费。
		var attribute_key: String = str(raw_attribute_key)
		if attributes.has(attribute_key):
			attributes[attribute_key] = float(attributes.get(attribute_key, 0.0)) + float(set_attribute_bonuses.get(raw_attribute_key, 0.0))
	return attributes


func _get_character_profile() -> Dictionary:
	## 读取当前选中角色档案；服务缺失时返回完整默认值，保证属性页可独立实例化测试。
	if _session_state != null and _session_state.has_method("get_character_profile"):
		# 当前角色标识；优先使用公开入口，避免直接依赖自动加载字段。
		var character_id: String = str(_session_state.call("get_selected_character_id")) if _session_state.has_method("get_selected_character_id") else "stelle"
		return _session_state.call("get_character_profile", character_id) as Dictionary
	return {"display_name": "星", "max_health": 100.0, "max_energy": 100.0, "move_speed": 100.0, "attack_power": 100.0, "defense_power": 100.0, "health_regeneration_per_five_seconds": 0.0, "vision_range": 1.0, "dodge_chance": 0.0, "energy_regeneration": 15.0}


func _build_value_snapshot(base_value: float, equipment_value: float) -> Dictionary:
	## 构建角色面板通用三值结构；最终值最低为 0。
	return {"base": base_value, "equipment": equipment_value, "total": maxf(base_value + equipment_value, 0.0)}


func _format_attribute_value(value: float, is_percent: bool) -> String:
	## 格式化普通数值或比例；比例统一乘以 100 并附加百分号。
	return "%s%%" % _format_number(value * 100.0) if is_percent else _format_number(value)


func _format_number(value: float) -> String:
	## 整数不显示小数，非整数保留最多两位，兼顾基础属性和强化后的精确结果。
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
