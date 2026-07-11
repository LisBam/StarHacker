extends Label
class_name DamageNumberPopup

## 伤害飘字在受击目标世界坐标生成，随后上浮、淡出并自动释放。

## 普通伤害颜色；默认浅黄白。
@export var normal_damage_color: Color = Color(1.0, 0.94, 0.72, 1.0)
## 暴击伤害颜色；默认鲜红色。
@export var critical_damage_color: Color = Color(1.0, 0.18, 0.15, 1.0)
## 飘字持续时间；默认 0.72 秒。
@export_range(0.1, 3.0, 0.05) var lifetime: float = 0.72
## 飘字上浮距离；默认 58 像素。
@export_range(8.0, 240.0, 1.0) var rise_distance: float = 58.0
## 最小字号；默认 14，使低伤害飘字保持可读但减少画面遮挡。
@export_range(8, 96, 1) var minimum_font_size: int = 14
## 最大字号；默认 32，限制暴击和高伤害飘字占用的屏幕空间。
@export_range(8, 160, 1) var maximum_font_size: int = 32
## 对数缩放强度；默认 3.8，降低伤害提升时字号增长速度。
@export_range(0.1, 20.0, 0.1) var logarithmic_scale_strength: float = 3.8


static func spawn_damage_number(parent_node: Node, world_position: Vector2, damage_value: float, is_critical: bool) -> void:
	if parent_node == null or damage_value <= 0.0:
		return
	# 飘字实例；由脚本直接创建，避免受击对象依赖额外场景。
	var popup: DamageNumberPopup = DamageNumberPopup.new()
	parent_node.add_child(popup)
	popup.global_position = world_position
	popup._play(damage_value, is_critical)


func _play(damage_value: float, is_critical: bool) -> void:
	text = str(maxi(roundi(damage_value), 1))
	modulate = critical_damage_color if is_critical else normal_damage_color
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 非线性字号；对数增长保证高伤害更大但不会无限膨胀。
	var resolved_font_size: int = clampi(roundi(float(minimum_font_size) + log(maxf(damage_value, 0.0) + 1.0) * logarithmic_scale_strength), minimum_font_size, maximum_font_size)
	add_theme_font_size_override("font_size", resolved_font_size)
	position -= Vector2(42.0, 26.0)
	custom_minimum_size = Vector2(84.0, 52.0)
	# 上浮淡出补间；目标死亡后仍可独立播放完成。
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise_distance, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
