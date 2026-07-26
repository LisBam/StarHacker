extends Node2D
class_name CombatBurstEffect

## 战斗爆发特效用于表现受击、死亡和其他短促反馈。
## 它通过代码绘制扩散圆环和碎片，不依赖外部贴图，适合原型阶段快速复用。

## 特效颜色；默认青白色，运行时由 spawn_burst 覆盖，修改会影响圆环和碎片颜色。
var effect_color: Color = Color(0.75, 0.95, 1.0, 1.0)
## 最大扩散半径；取值建议大于 0，默认 34 像素，修改会影响特效覆盖范围。
var max_radius: float = 34.0
## 特效持续时间；取值应大于 0，默认 0.22 秒，修改会影响特效消散速度。
var duration: float = 0.22
## 碎片数量；取值建议 0 到 24，默认 8，修改会影响绘制密度和视觉强度。
var particle_count: int = 8
## 当前已播放时间；取值大于等于 0，默认 0，修改会影响特效进度和销毁时机。
var _elapsed_time: float = 0.0
## 碎片方向数组；元素为单位向量，默认由 configure 随机生成，修改会影响碎片飞散方向。
var _particle_directions: Array[Vector2] = []
## 碎片距离倍率数组；元素为 0 到 1 的浮点数，默认由 configure 随机生成，修改会影响碎片飞散距离。
var _particle_distance_factors: Array[float] = []
## 局部随机数生成器；默认每个特效独立随机化，修改会影响碎片分布。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 特效脚本静态缓存；首次生成特效时加载一次后跨实例复用，避免每次受击都执行运行时资源路径查找。
static var _cached_effect_script: Script = null


static func spawn_burst(parent_node: Node, burst_position: Vector2, burst_color: Color, burst_radius: float, burst_duration: float, burst_particle_count: int) -> Node2D:
	if parent_node == null:
		return null

	# 特效脚本资源；取值为当前脚本路径，默认用于避免跨脚本依赖全局类名缓存。
	# 当前实现改为读取静态缓存；只有首次生成时执行一次 load，后续密集受击特效直接复用同一脚本资源。
	if _cached_effect_script == null:
		_cached_effect_script = load("res://scripts/effects/combat_burst_effect.gd") as Script
	var effect_script: Script = _cached_effect_script
	if effect_script == null:
		return null

	# 特效实例；取值为新建 CombatBurstEffect，默认挂到传入父节点并使用全局坐标显示。
	var effect: Node2D = effect_script.new() as Node2D
	if effect == null:
		return null

	effect.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_node.add_child(effect)
	effect.global_position = burst_position
	if effect.has_method("configure"):
		effect.call("configure", burst_color, burst_radius, burst_duration, burst_particle_count)
	return effect


func configure(new_color: Color, new_radius: float, new_duration: float, new_particle_count: int) -> void:
	effect_color = new_color
	max_radius = maxf(new_radius, 1.0)
	duration = maxf(new_duration, 0.01)
	particle_count = maxi(new_particle_count, 0)
	_elapsed_time = 0.0
	_random.randomize()
	_build_particles()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed_time += delta
	if _elapsed_time >= duration:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	# 特效进度；取值为 0 到 1，默认驱动扩散半径、透明度和碎片位置。
	var progress: float = clampf(_elapsed_time / duration, 0.0, 1.0)
	# 透明度；取值从 1 递减到 0，默认让特效自然消散。
	var alpha: float = 1.0 - progress
	# 当前圆环半径；取值随时间从小到最大半径，默认表现冲击扩散。
	var current_radius: float = lerpf(max_radius * 0.18, max_radius, progress)
	# 当前颜色；取值为 effect_color 叠加透明度，默认用于圆环和碎片。
	var draw_color: Color = Color(effect_color.r, effect_color.g, effect_color.b, effect_color.a * alpha)
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 16, draw_color, 2.0)
	draw_circle(Vector2.ZERO, max_radius * 0.16 * alpha, draw_color)

	# 碎片索引；取值为 0 到碎片数量减 1，默认逐个绘制飞散短线。
	for particle_index in range(_particle_directions.size()):
		# 碎片方向；取值为单位向量，默认由随机角度生成。
		var particle_direction: Vector2 = _particle_directions[particle_index]
		# 碎片距离倍率；取值通常为 0.55 到 1，默认让碎片距离略有差异。
		var distance_factor: float = _particle_distance_factors[particle_index]
		# 碎片终点；取值为当前进度下的局部坐标，默认沿方向飞出。
		var particle_end: Vector2 = particle_direction * max_radius * distance_factor * progress
		# 碎片起点；取值略短于终点，默认形成速度线。
		var particle_start: Vector2 = particle_end - particle_direction * max_radius * 0.16
		draw_line(particle_start, particle_end, draw_color, 2.0)


func _build_particles() -> void:
	_particle_directions.clear()
	_particle_distance_factors.clear()

	# 碎片生成索引；取值为 0 到 particle_count - 1，默认生成环形随机碎片。
	for particle_index in range(particle_count):
		# 碎片角度；取值为 0 到 TAU 的随机弧度，默认让碎片向四周扩散。
		var particle_angle: float = _random.randf_range(0.0, TAU)
		_particle_directions.append(Vector2.RIGHT.rotated(particle_angle))
		_particle_distance_factors.append(_random.randf_range(0.55, 1.0))
