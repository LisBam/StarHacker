extends AcceptDialog
class_name EnhancementResultDialog

## 强化结果弹窗统一展示一次强化对武器造成的提升与削弱。
## 仓库和局内背包只需传入 GlobalInventory 返回的结果字典，不各自重复拼接数值文本。

## 弹窗默认宽度；默认 560 像素可完整容纳属性名、百分比、基础值和变化值。
@export_range(360, 960, 1) var dialog_width: int = 560


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "强化完成"
	get_ok_button().text = "确定"


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
	dialog_text = "\n".join(result_lines)
	popup_centered(Vector2i(dialog_width, 0))


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
	var percentage_text: String = "%s%d%%" % ["+" if modifier_ratio >= 0.0 else "-", roundi(absf(modifier_ratio) * 100.0)]
	# 带符号变化值；正数显式加号，负数保留减号。
	var change_text: String = "%s%s" % ["+" if change_value >= 0.0 else "", _format_number(change_value)]
	return "%s：%s（基础 %s，变化 %s，强化后 %s）" % [
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
