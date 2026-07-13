extends Label
class_name FloatingTextPopup

## 通用世界飘字用于技能连击、奖励和状态反馈，不参与伤害数值或战斗公式。

## 飘字持续时间；默认 0.9 秒，修改影响淡出与自动释放时机。
@export_range(0.1, 5.0, 0.05) var lifetime: float = 0.9
## 飘字上浮距离；默认 52 像素，修改只影响视觉轨迹。
@export_range(0.0, 240.0, 1.0) var rise_distance: float = 52.0
## 飘字字号；默认 20，适合角色头顶短状态文本。
@export_range(8, 96, 1) var font_size: int = 20


static func spawn_text(parent_node: Node, world_position: Vector2, message: String, text_color: Color) -> void:
	## 在指定世界位置创建一次性文本；空父节点或空文本不生成实例。
	if parent_node == null or message.is_empty():
		return
	# 飘字实例；每次反馈独立创建并在动画结束后自动释放。
	var popup: FloatingTextPopup = FloatingTextPopup.new()
	parent_node.add_child(popup)
	popup.global_position = world_position
	popup._play(message, text_color)


func _play(message: String, text_color: Color) -> void:
	## 配置文本并播放并行上浮淡出动画；节点不拦截任何鼠标输入。
	text = message
	modulate = text_color
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", font_size)
	position -= Vector2(72.0, 58.0)
	custom_minimum_size = Vector2(144.0, 44.0)
	# 动画补间；位置和透明度并行变化，结束后释放节点避免世界残留。
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise_distance, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
