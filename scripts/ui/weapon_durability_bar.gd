extends Control
class_name WeaponDurabilityBar

## 武器耐久条是只读显示组件，负责把 WeaponData 的当前耐久比例绘制在物品 UI 最底部。
## 组件不修改武器状态，可复用于战斗装备槽、战斗背包、仓库、局外装备栏和结算卡片。
## 通用耐久补充：组件现按耐久属性而非武器类型工作，也供穿戴装备、锻造、商店和后续耐久物品复用。
## 边框内缩补充：宿主存在独立边框时可配置水平与底部内缩，使耐久条只占用边框内部区域。

## 耐久条高度；默认 5 像素，贴在父物品 UI 底部并保持与父控件等宽。
@export_range(2.0, 16.0, 1.0) var bar_height: float = 5.0
## 水平内缩距离；默认 0 像素保持通用等宽行为，标准物品卡片运行时传入 2 像素边框宽度，修改会同时缩进左右两侧。
@export_range(0.0, 32.0, 1.0) var horizontal_inset: float = 0.0
## 底部内缩距离；默认 0 像素贴住父控件底部，标准物品卡片运行时传入 2 像素边框宽度，修改会整体上移耐久条。
@export_range(0.0, 32.0, 1.0) var bottom_inset: float = 0.0
## 耐久条背景颜色；默认半透明深灰，用于显示已损失耐久的空缺区域。
@export var background_color: Color = Color(0.03, 0.04, 0.05, 0.92)
## 高耐久颜色；默认绿色，耐久比例高于 50% 时使用。
@export var high_durability_color: Color = Color(0.28, 0.92, 0.46, 1.0)
## 中耐久颜色；默认黄色，耐久比例处于 20% 到 50% 时使用。
@export var medium_durability_color: Color = Color(0.96, 0.72, 0.20, 1.0)
## 低耐久颜色；默认红色，耐久比例低于 20% 且尚未损坏时使用。
@export var low_durability_color: Color = Color(0.96, 0.24, 0.28, 1.0)
## 损坏颜色；默认灰色，耐久归零时用于明确表示武器不可使用。
@export var broken_color: Color = Color(0.38, 0.40, 0.42, 1.0)
## 中耐久阈值；默认 0.5，低于或等于该比例时由绿色切换为黄色。
@export_range(0.0, 1.0, 0.01) var medium_threshold: float = 0.5
## 低耐久阈值；默认 0.2，低于或等于该比例时由黄色切换为红色。
@export_range(0.0, 1.0, 0.01) var low_threshold: float = 0.2

## 当前显示的武器资源；默认 null 表示隐藏耐久填充，配置后只读取耐久接口。
var _weapon_resource: Resource


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_layout()
	queue_redraw()


func set_layout_insets(requested_horizontal_inset: float, requested_bottom_inset: float) -> void:
	## 配置宿主边框内缩；参数单位为像素，负值会限制为 0，运行时修改会立即更新控件位置与宽度。
	horizontal_inset = maxf(requested_horizontal_inset, 0.0)
	bottom_inset = maxf(requested_bottom_inset, 0.0)
	if is_node_ready():
		_apply_layout()
		queue_redraw()


func _apply_layout() -> void:
	# 实际水平内缩；左右使用相同数值，保证耐久填充仍以卡片中心对称布局。
	var resolved_horizontal_inset: float = maxf(horizontal_inset, 0.0)
	# 实际底部内缩；用于避开宿主底部边框，同时保持耐久条自身高度不变。
	var resolved_bottom_inset: float = maxf(bottom_inset, 0.0)
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = resolved_horizontal_inset
	offset_top = -(bar_height + resolved_bottom_inset)
	offset_right = -resolved_horizontal_inset
	offset_bottom = -resolved_bottom_inset


func configure(weapon_resource: Resource) -> void:
	_weapon_resource = weapon_resource
	visible = _has_durability_attributes(_weapon_resource)
	queue_redraw()


func refresh() -> void:
	visible = _has_durability_attributes(_weapon_resource)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# 当前耐久比例；取值限制在 0 到 1，旧资源缺少接口时按满耐久显示以保证兼容。
	var durability_ratio: float = _get_durability_ratio()
	# 完整背景矩形；宽度等于布局内缩后的可用区域，默认无内缩时仍与父物品 UI 等宽。
	var full_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(full_rect, background_color, true)
	# 填充矩形；从左向右表示剩余耐久，耐久归零时宽度为 0。
	var fill_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(size.x * durability_ratio, size.y))
	if fill_rect.size.x > 0.0:
		draw_rect(fill_rect, _get_fill_color(durability_ratio), true)
	elif durability_ratio <= 0.0:
		draw_rect(full_rect, broken_color, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _get_durability_ratio() -> float:
	if _weapon_resource == null:
		return 1.0
	if _weapon_resource.has_method("get_durability_ratio"):
		return clampf(float(_weapon_resource.call("get_durability_ratio")), 0.0, 1.0)
	# 属性兼容比例；自定义耐久物品即使没有比例方法，也可直接通过当前值与最大值使用标准耐久条。
	var maximum_durability: float = float(_weapon_resource.call("get_maximum_durability")) if _weapon_resource.has_method("get_maximum_durability") else maxf(float(_weapon_resource.get("max_durability")), 0.0)
	if maximum_durability <= 0.0:
		return 0.0
	return clampf(float(_weapon_resource.get("current_durability")) / maximum_durability, 0.0, 1.0)


func _get_fill_color(durability_ratio: float) -> Color:
	if durability_ratio <= 0.0:
		return broken_color
	if durability_ratio <= clampf(low_threshold, 0.0, 1.0):
		return low_durability_color
	if durability_ratio <= clampf(medium_threshold, low_threshold, 1.0):
		return medium_durability_color
	return high_durability_color


func _is_weapon_resource(item_resource: Resource) -> bool:
	return _has_durability_attributes(item_resource)


func _has_durability_attributes(item_resource: Resource) -> bool:
	# 耐久组件显示条件；只有资源同时声明当前耐久与最大耐久属性时才渲染，物品类型不参与判断。
	if item_resource == null:
		return false
	# 属性存在状态；通过属性列表识别真实声明，避免 Resource.get() 对不存在字段的空值产生误判。
	var has_current_durability: bool = false
	# 最大耐久属性存在状态；必须与当前耐久同时存在才构成完整耐久模型。
	var has_maximum_durability: bool = false
	for property_info in item_resource.get_property_list():
		# 属性名称；取值来自 Godot 资源属性字典，字符串比较可兼容脚本变量与导出变量。
		var property_name: String = str((property_info as Dictionary).get("name", ""))
		has_current_durability = has_current_durability or property_name == "current_durability"
		has_maximum_durability = has_maximum_durability or property_name == "max_durability"
		if has_current_durability and has_maximum_durability:
			return true
	return false
