extends Area2D
class_name PlayerProjectile

## 玩家弹体是一个独立 Area2D，生成后按 launch 传入的方向飞行。
## 它通过最大寿命和最大距离自动回收，避免长时间射击后场景中残留大量不可见节点。
## 被命中的对象如果实现 apply_damage(damage: float, source: Node)，弹体会自动调用该接口。

signal hit_body(body: Node, damage: float)
signal hit_area(area: Area2D, damage: float)

## 弹体默认速度；取值建议大于 0，默认 900 与远程攻击组件一致，运行时修改会影响未覆盖速度的弹体飞行。
@export_range(1.0, 2400.0, 1.0, "or_greater") var speed: float = 900.0
## 弹体最大存活时间；取值应大于 0，默认 1.2 秒避免远距离残留，运行时修改会影响自动销毁时间。
@export_range(0.01, 20.0, 0.01) var lifetime: float = 1.2
## 弹体最大飞行距离；取值应大于 0，默认 960 像素限制射程，运行时修改会影响自动销毁距离。
@export_range(1.0, 4000.0, 1.0, "or_greater") var max_distance: float = 960.0
## 弹体命中伤害；取值建议大于等于 0，默认 12 作为基础远程伤害，运行时修改会影响命中回调伤害值。
@export_range(0.0, 9999.0, 1.0, "or_greater") var damage: float = 12.0
## 命中后是否销毁；取值为 true/false，默认 true 避免穿透，运行时修改会影响弹体能否连续命中。
@export var destroy_on_hit: bool = true

## 当前弹体速度向量；取值为方向乘速度，默认向右用于未 launch 时的兜底移动，修改会影响后续飞行方向和速度。
var _velocity: Vector2 = Vector2.RIGHT
## 当前弹体存活时间；取值大于等于 0，默认 0 表示刚生成，修改会影响 lifetime 自动销毁判定。
var _age: float = 0.0
## 弹体出生位置；取值为全局坐标 Vector2，默认在 ready 时记录当前位置，修改会影响 max_distance 销毁判定。
var _start_position: Vector2


func _ready() -> void:
	_start_position = global_position
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_age += delta

	if _age >= lifetime or global_position.distance_to(_start_position) >= max_distance:
		queue_free()


func launch(direction: Vector2, speed_override: float = -1.0) -> void:
	if direction.is_zero_approx():
		return

	# 本次发射速度；取值优先使用正数覆盖值，否则使用 speed，默认由组件传入，修改会影响当前弹体飞行速度。
	var resolved_speed: float = speed_override if speed_override > 0.0 else speed
	_velocity = direction.normalized() * resolved_speed
	rotation = direction.angle()


func set_damage(value: float) -> void:
	damage = maxf(value, 0.0)


func _on_body_entered(body: Node) -> void:
	if _apply_hit(body):
		hit_body.emit(body, damage)


func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return

	if _apply_hit(area):
		hit_area.emit(area, damage)


func _apply_hit(target: Node) -> bool:
	if target.has_method("apply_damage"):
		target.call("apply_damage", damage, self)

	if destroy_on_hit:
		queue_free()

	return true
