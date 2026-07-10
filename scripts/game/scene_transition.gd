extends CanvasLayer

## 场景过渡服务统一为所有场景切换提供快速黑屏淡入淡出。
## 调用方只提交目标场景路径，不直接创建遮罩或管理 Tween，避免各界面重复实现转场。

## 单次完整黑屏过渡时长；默认 0.3 秒，前半段变黑并切换场景，后半段恢复画面。
@export_range(0.05, 2.0, 0.01) var transition_duration: float = 0.30
## 黑屏颜色；默认纯黑，透明度由过渡 Tween 从 0 调整到 1 再恢复到 0。
@export var transition_color: Color = Color.BLACK

## 全屏黑色遮罩；默认在 ready 阶段创建并置于最高 CanvasLayer。
var _fade_rect: ColorRect
## 是否正在切换场景；默认 false，用于忽略过渡期间的重复按钮点击。
var _transitioning: bool = false


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.name = "SceneTransitionFade"
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(transition_color, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.visible = false
	add_child(_fade_rect)


func change_scene_to_file(scene_path: String) -> bool:
	if _transitioning or scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		return false
	_transitioning = true
	_run_transition(scene_path)
	return true


func is_transitioning() -> bool:
	return _transitioning


func _run_transition(scene_path: String) -> void:
	_fade_rect.visible = true
	_fade_rect.color = Color(transition_color, 0.0)
	# 半程时长；完整 0.3 秒平均分配给变黑和恢复两个阶段。
	var half_duration: float = maxf(transition_duration * 0.5, 0.025)
	# 变黑 Tween；暂停菜单中也继续执行，避免从暂停场景返回主菜单时转场停住。
	var fade_out_tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out_tween.tween_property(_fade_rect, "color:a", 1.0, half_duration)
	await fade_out_tween.finished
	# 场景切换结果；失败时仍执行恢复阶段并解除转场锁。
	var change_result: Error = get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	# 恢复 Tween；新场景已经加载后快速移除黑屏滤镜。
	var fade_in_tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in_tween.tween_property(_fade_rect, "color:a", 0.0, half_duration)
	await fade_in_tween.finished
	_fade_rect.visible = false
	_transitioning = false
	if change_result != OK:
		push_error("场景切换失败：%s，错误码 %d" % [scene_path, change_result])
