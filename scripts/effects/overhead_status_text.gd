extends Node2D
class_name OverheadStatusText

## 头顶状态文本独立跟随一个世界坐标目标，并在目标失效或状态结束时自行回收。
## 调用者创建后使用 configure 指定目标与文字；本节点不管理任何技能持续时间或数值效果。

## 默认文字绘制区域；宽度 48 像素可稳定居中双字符状态文本，高度 26 像素容纳 22 号字体与描边。
const DEFAULT_LABEL_SIZE: Vector2 = Vector2(48.0, 26.0)
## 默认文字字体大小；22 像素在常规战斗镜头下可辨认，同时不会遮挡角色模型。
const DEFAULT_FONT_SIZE: int = 22
## 默认文字偏移；向上 52 像素使文本位于角色头顶，不覆盖血条与蓄力条下方的角色模型。
const DEFAULT_WORLD_OFFSET: Vector2 = Vector2(0.0, -52.0)

## 跟随目标；默认 null，configure 注入有效世界节点后每帧同步其全局坐标。
var _target: Node2D
## 状态文字标签；默认 null，configure 时创建并作为本节点子级，负责实际文本绘制而不参与战斗输入。
var _label: Label
## 目标头顶偏移；默认采用 DEFAULT_WORLD_OFFSET，运行时只由 configure 覆盖以适配不同角色状态标记。
var _world_offset: Vector2 = DEFAULT_WORLD_OFFSET


func configure(target: Node2D, status_text: String, text_color: Color, world_offset: Vector2 = DEFAULT_WORLD_OFFSET) -> void:
	## 配置一次可持续跟随的头顶状态文本；重复调用会更新文字内容与目标，但不会重复创建标签。
	_target = target
	_world_offset = world_offset
	if _label == null:
		# 状态文字标签；使用固定绘制区和居中对齐，确保目标移动时标签位置不因文字布局抖动。
		_label = Label.new()
		_label.size = DEFAULT_LABEL_SIZE
		_label.position = -DEFAULT_LABEL_SIZE * 0.5
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
		add_child(_label)
	_label.text = status_text
	_label.modulate = text_color
	_sync_target_position()
	set_process(true)


func _process(_delta: float) -> void:
	## 跟随有效目标；目标被销毁或离开场景时立即回收，避免技能行为提前销毁后残留文本。
	if not is_instance_valid(_target):
		queue_free()
		return
	_sync_target_position()


func dispose() -> void:
	## 主动结束状态文字；技能行为在效果结束时调用，重复调用保持幂等且不会影响其他头顶反馈。
	set_process(false)
	queue_free()


func _sync_target_position() -> void:
	## 把本节点移动到目标全局位置加配置偏移；未配置或失效目标时保留当前坐标，等待下一帧回收。
	if is_instance_valid(_target):
		global_position = _target.global_position + _world_offset
