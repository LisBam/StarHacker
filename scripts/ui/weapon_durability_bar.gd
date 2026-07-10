extends Control
class_name WeaponDurabilityBar

## 武器耐久条是只读显示组件，负责把 WeaponData 的当前耐久比例绘制在物品 UI 最底部。
## 组件不修改武器状态，可复用于战斗装备槽、战斗背包、仓库、局外装备栏和结算卡片。

## 耐久条高度；默认 5 像素，贴在父物品 UI 底部并保持与父控件等宽。
@export_range(2.0, 16.0, 1.0) var bar_height: float = 5.0
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
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 0.0
	offset_top = -bar_height
	offset_right = 0.0
	offset_bottom = 0.0
	queue_redraw()


func configure(weapon_resource: Resource) -> void:
	_weapon_resource = weapon_resource
	visible = _is_weapon_resource(_weapon_resource)
	queue_redraw()


func refresh() -> void:
	visible = _is_weapon_resource(_weapon_resource)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# 当前耐久比例；取值限制在 0 到 1，旧资源缺少接口时按满耐久显示以保证兼容。
	var durability_ratio: float = _get_durability_ratio()
	# 完整背景矩形；宽度始终等于父物品 UI，满足所有物品界面统一贴底展示的要求。
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
	if _weapon_resource == null or not _weapon_resource.has_method("get_durability_ratio"):
		return 1.0
	return clampf(float(_weapon_resource.call("get_durability_ratio")), 0.0, 1.0)


func _get_fill_color(durability_ratio: float) -> Color:
	if durability_ratio <= 0.0:
		return broken_color
	if durability_ratio <= clampf(low_threshold, 0.0, 1.0):
		return low_durability_color
	if durability_ratio <= clampf(medium_threshold, low_threshold, 1.0):
		return medium_durability_color
	return high_durability_color


func _is_weapon_resource(item_resource: Resource) -> bool:
	return item_resource != null and str(item_resource.get("weapon_type")) in ["ranged", "melee"]
