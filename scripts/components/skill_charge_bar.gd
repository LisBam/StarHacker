extends Node2D
class_name SkillChargeBar

## 技能蓄力条固定绘制在角色头顶，仅反映当前蓄力比例，不参与时间累计或释放判定。
## ActiveSkillComponent 在可蓄力技能按下、更新和结束时分别调用显示、设值与隐藏接口。

## 蓄力条单轴尺寸安全下限；固定 1 像素，防止检查器异常值生成负矩形或不可见绘制。
const MINIMUM_BAR_AXIS_SIZE: float = 1.0

## 蓄力条相对角色的局部偏移；默认位于角色头顶 42 像素，运行时通常不动态修改。
@export var bar_offset: Vector2 = Vector2(0.0, -42.0)
## 蓄力条尺寸；默认 64×8 像素，宽度提供清晰进度，高度避免遮挡战斗画面。
@export var bar_size: Vector2 = Vector2(64.0, 8.0)
## 蓄力条背景颜色；默认深色高透明度，用于保证不同地图背景下都能辨认。
@export var background_color: Color = Color(0.02, 0.03, 0.05, 0.90)
## 蓄力进度颜色；默认金色，与星的主动技能释放特效保持一致。
@export var fill_color: Color = Color(1.0, 0.76, 0.20, 0.96)
## 蓄力条边框颜色；默认浅色半透明，修改只影响视觉轮廓。
@export var border_color: Color = Color(0.86, 0.94, 1.0, 0.88)
## 蓄力条边框宽度；默认 1 像素，取值大于 0，修改只影响外框粗细。
@export_range(0.5, 6.0, 0.5) var border_width: float = 1.0

## 当前蓄力比例；取值 0 至 1，默认 0，显示期间由主动技能组件逐帧更新。
var _charge_ratio: float = 0.0


func show_charge() -> void:
	## 显示并从 0 开始新的蓄力条，避免连续技能沿用上次残留进度。
	_charge_ratio = 0.0
	visible = true
	queue_redraw()


func set_charge_ratio(charge_ratio: float) -> void:
	## 更新蓄力比例并限制在合法范围；达到最大时间后保持满条直到玩家松开按键。
	_charge_ratio = clampf(charge_ratio, 0.0, 1.0)
	queue_redraw()


func hide_charge() -> void:
	## 隐藏并清空蓄力条；技能释放、取消或角色切换后不会保留旧进度。
	_charge_ratio = 0.0
	visible = false
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# 标准化尺寸；宽高至少 1 像素，避免检查器异常值生成负矩形。
	var resolved_size: Vector2 = Vector2(maxf(bar_size.x, MINIMUM_BAR_AXIS_SIZE), maxf(bar_size.y, MINIMUM_BAR_AXIS_SIZE))
	# 蓄力条完整矩形；以 bar_offset 为中心，便于不同角色共用同一头顶位置语义。
	var background_rect: Rect2 = Rect2(bar_offset - resolved_size * 0.5, resolved_size)
	draw_rect(background_rect, background_color, true)
	# 蓄力填充矩形；宽度按当前比例缩放，高度保持完整。
	var fill_rect: Rect2 = Rect2(background_rect.position, Vector2(background_rect.size.x * _charge_ratio, background_rect.size.y))
	draw_rect(fill_rect, fill_color, true)
	draw_rect(background_rect, border_color, false, border_width)
