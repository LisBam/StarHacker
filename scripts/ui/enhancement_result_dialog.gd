extends AcceptDialog
class_name EnhancementResultDialog

## 强化结果弹窗统一展示一次强化对武器造成的提升与削弱。
## 仓库和局内背包只需传入 GlobalInventory 返回的结果字典，不各自重复拼接数值文本。

## 弹窗默认宽度；默认 560 像素可完整容纳属性名、百分比、基础值和变化值。
@export_range(360, 960, 1) var dialog_width: int = 560
## 弹窗默认高度；默认 430 像素，为多词条结果、价格变化和底部确定按钮保留稳定空间。
@export_range(260, 720, 1) var dialog_height: int = 430

## 增益属性颜色；默认亮绿色，与强化石详情和武器属性变化保持一致。
const BENEFICIAL_COLOR: String = "#70e889"
## 减益属性颜色；默认亮红色，与强化石详情和武器属性变化保持一致。
const DETRIMENTAL_COLOR: String = "#ff7070"
## 中性价格颜色；默认浅蓝白色，用于价格没有变化的情况。
const NEUTRAL_COLOR: String = "#d8e8ee"

## 强化结果富文本；默认在 ready 创建并覆盖系统纯文本标签，用于逐条渲染玩法利弊颜色。
var _result_label: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "强化完成"
	get_ok_button().text = "确定"
	get_label().visible = false
	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = false
	_result_label.scroll_active = true
	_result_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_label.offset_left = 18.0
	_result_label.offset_top = 44.0
	_result_label.offset_right = -18.0
	_result_label.offset_bottom = -62.0
	add_child(_result_label)


func present(enhancement_result: Dictionary) -> void:
	if not bool(enhancement_result.get("success", false)):
		return
	# 强化武器；优先读取显示名称，异常资源回退为通用名称。
	var weapon_resource: Resource = enhancement_result.get("weapon") as Resource
	# 武器显示名称；空资源或未配置名称时使用“未知武器”。
	var weapon_name: String = str(weapon_resource.get("display_name")) if weapon_resource != null else ""
	if weapon_name.is_empty():
		weapon_name = "未知武器"
	# 弹窗文本行；先展示提升属性，再展示削弱属性，与强化石详情顺序一致。
	var result_lines: PackedStringArray = PackedStringArray(["武器：%s" % weapon_name])
	# 提升明细；元素为属性变化字典，可能为空数组。
	var beneficial_changes: Array = enhancement_result.get("beneficial_changes", []) as Array
	# 削弱明细；元素为属性变化字典，极品强化石必定为空。
	var detrimental_changes: Array = enhancement_result.get("detrimental_changes", []) as Array
	_append_change_section(result_lines, "提升属性", beneficial_changes, "无")
	_append_change_section(result_lines, "削弱属性", detrimental_changes, "无")
	# 强化前耐久；锻造服务在结算前保存，用于明确展示牺牲品带来的实际耐久收益。
	var durability_before: float = maxf(float(enhancement_result.get("durability_before", 0.0)), 0.0)
	# 强化后耐久；已经限制在主物品最大耐久以内，耐久溢出部分不会写入或计费。
	var durability_after: float = maxf(float(enhancement_result.get("durability_after", durability_before)), 0.0)
	# 实际恢复耐久；只展示真正写入主物品的数值，纯强化石锻造时固定为 0。
	var durability_restored: float = maxf(float(enhancement_result.get("durability_restored", durability_after - durability_before)), 0.0)
	result_lines.append("")
	result_lines.append("耐久变化")
	result_lines.append("[color=%s]%s → %s（+%s）[/color]" % [BENEFICIAL_COLOR if durability_restored > 0.0 else NEUTRAL_COLOR, _format_number(durability_before), _format_number(durability_after), _format_number(durability_restored)])
	# 强化前售价；由 GlobalInventory 在应用词条前读取，避免弹窗自行复算历史状态。
	var sell_price_before: int = maxi(int(enhancement_result.get("sell_price_before", 0)), 0)
	# 强化后售价；包含本次随机强化产生的全部价格影响。
	var sell_price_after: int = maxi(int(enhancement_result.get("sell_price_after", sell_price_before)), 0)
	# 售价变化；正数显式显示加号，负数保留减号，0 表示本次词条综合后价格不变。
	var sell_price_change: int = sell_price_after - sell_price_before
	result_lines.append("")
	result_lines.append("价格变化")
	# 价格颜色；价格上升为绿色、下降为红色、无变化使用中性色。
	var price_color: String = BENEFICIAL_COLOR if sell_price_change > 0 else (DETRIMENTAL_COLOR if sell_price_change < 0 else NEUTRAL_COLOR)
	result_lines.append("[color=%s]%d → %d 金币（%s%d）[/color]" % [price_color, sell_price_before, sell_price_after, "+" if sell_price_change >= 0 else "", sell_price_change])
	dialog_text = ""
	_result_label.text = "\n".join(result_lines)
	popup_centered(Vector2i(dialog_width, dialog_height))


func _append_change_section(target_lines: PackedStringArray, section_title: String, changes: Array, empty_text: String) -> void:
	target_lines.append("")
	target_lines.append(section_title)
	if changes.is_empty():
		target_lines.append(empty_text)
		return
	# 变化遍历项；异常类型直接跳过，避免一个损坏字段阻断整个结果弹窗。
	for raw_change in changes:
		if not (raw_change is Dictionary):
			continue
		# 属性变化字典；包含本次百分比、基础值、实际变化值与强化后数值。
		var change: Dictionary = raw_change as Dictionary
		target_lines.append(_format_change_line(change))


func _format_change_line(change: Dictionary) -> String:
	# 属性标识；使用 EnhancementRules 的中文名称表统一与武器详情的显示。
	var stat_name: String = str(change.get("stat_name", ""))
	# 本次强化百分比；正负号表示数值变化方向，例如冷却 -20% 属于提升。
	var modifier_ratio: float = float(change.get("modifier_ratio", 0.0))
	# 基础数值；是武器模板未强化的原始数值。
	var base_value: float = float(change.get("base_value", 0.0))
	# 实际变化值；是本次强化对当前有效数值造成的增减。
	var change_value: float = float(change.get("change_value", 0.0))
	# 强化后数值；包含所有历史强化累计并已应用属性下限。
	var after_value: float = float(change.get("after_value", 0.0))
	# 带符号百分比；使用整数百分点对齐强化石生成精度。
	# 公式类型；加算属性用“百分点”展示，乘算属性继续显示百分比，避免两种幅度被误读为同一公式。
	var calculation_mode: String = str(change.get("calculation_mode", EnhancementRules.get_calculation_mode(stat_name)))
	# 带符号幅度；加算区间保留 0.1 个百分点，乘算区间按整数百分比展示。
	var percentage_text: String = ("%s%.1f 个百分点" % ["+" if modifier_ratio >= 0.0 else "-", absf(modifier_ratio) * 100.0]) if calculation_mode == EnhancementRules.CALCULATION_ADDITIVE_POINTS else ("%s%d%%" % ["+" if modifier_ratio >= 0.0 else "-", roundi(absf(modifier_ratio) * 100.0)])
	# 带符号变化值；正数显式加号，负数保留减号。
	var change_text: String = "%s%s" % ["+" if change_value >= 0.0 else "", _format_number(change_value)]
	# 玩法收益；冷却、能量消耗、扩散和后坐力降低等负方向收益同样使用绿色。
	var is_beneficial: bool = EnhancementRules.is_direction_beneficial(stat_name, modifier_ratio)
	# 词条颜色；严格按玩法收益而不是数值正负选择。
	var color_code: String = BENEFICIAL_COLOR if is_beneficial else DETRIMENTAL_COLOR
	return "[color=%s]%s：%s（基础 %s，变化 %s，强化后 %s）[/color]" % [
		color_code,
		EnhancementRules.get_stat_label(stat_name),
		percentage_text,
		_format_number(base_value),
		change_text,
		_format_number(after_value),
	]


func _format_number(value: float) -> String:
	# 两位小数文本；然后移除无意义的末尾 0，在保留精度的同时提高可读性。
	var formatted_value: String = "%.2f" % value
	while formatted_value.contains(".") and formatted_value.ends_with("0"):
		formatted_value = formatted_value.trim_suffix("0")
	if formatted_value.ends_with("."):
		formatted_value = formatted_value.trim_suffix(".")
	return formatted_value
