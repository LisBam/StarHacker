extends Node
class_name DodgeFeedbackComponent

## 闪避反馈组件只负责玩家成功触发概率闪避时的模型透明动画和 MISS 世界飘字。
## 组件不判定闪避概率、不修改伤害结果，宿主仅在确定本次攻击被闪避后调用 play_feedback()。

## 通用世界飘字脚本；默认用于创建独立 MISS 文本，避免反馈组件复制字体与动画实现。
const FLOATING_TEXT_POPUP_SCRIPT: Script = preload("res://scripts/effects/floating_text_popup.gd")

## 需要同步透明的视觉节点路径；默认由玩家场景配置 Body 与 Core，运行时通常不动态修改。
@export var visual_node_paths: Array[NodePath] = []
## 闪避瞬间最低透明度；默认 0.18，0 为完全不可见、1 为不透明，运行时修改只影响视觉强度。
@export_range(0.0, 1.0, 0.01) var minimum_alpha: float = 0.18
## 闪避透明反馈总时长；默认 0.18 秒，前半段快速变透明、后半段恢复，不提供额外无敌时间。
@export_range(0.02, 2.0, 0.01) var feedback_duration: float = 0.18
## MISS 飘字相对玩家中心偏移；默认向上 18 像素，修改只影响文本生成位置。
@export var miss_text_offset: Vector2 = Vector2(0.0, -18.0)
## MISS 飘字颜色；默认浅青白，与玩家受击反馈区分且在深色地图上保持清晰。
@export var miss_text_color: Color = Color(0.72, 0.94, 1.0, 1.0)
## MISS 飘字内容；默认小写 miss，运行时通常不动态修改，可用于本地化替换。
@export var miss_text: String = "miss"

## 已解析视觉节点；元素为 CanvasItem，默认在 ready 时由路径数组收集，缺失节点会安全跳过。
var _visual_nodes: Array[CanvasItem] = []
## 每个视觉节点的原始透明度；键为实例 ID、值为 0 至 1，重复反馈结束后恢复场景原始状态。
var _original_alpha_by_instance_id: Dictionary = {}
## 当前透明动画；默认 null，连续闪避时停止旧动画并从最低透明度重新播放。
var _feedback_tween: Tween


func _ready() -> void:
	for visual_node_path in visual_node_paths:
		# 视觉节点；仅接收 CanvasItem，避免误把碰撞体或逻辑组件加入透明动画。
		var visual_node: CanvasItem = get_node_or_null(visual_node_path) as CanvasItem
		if visual_node == null:
			continue
		_visual_nodes.append(visual_node)
		_original_alpha_by_instance_id[visual_node.get_instance_id()] = visual_node.modulate.a


func play_feedback(world_position: Vector2, effect_parent: Node) -> void:
	## 播放一次概率闪避反馈；视觉节点缺失时仍会尝试生成 MISS 飘字。
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	# 半程时长；最低 0.01 秒，防止异常配置产生零时长补间。
	var half_duration: float = maxf(feedback_duration * 0.5, 0.01)
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	for visual_node in _visual_nodes:
		if not is_instance_valid(visual_node):
			continue
		visual_node.modulate.a = clampf(minimum_alpha, 0.0, 1.0)
		# 原始透明度；场景本身允许半透明角色，反馈结束后必须恢复对应节点自己的初始值。
		var original_alpha: float = float(_original_alpha_by_instance_id.get(visual_node.get_instance_id(), 1.0))
		_feedback_tween.tween_property(visual_node, "modulate:a", original_alpha, half_duration * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	FLOATING_TEXT_POPUP_SCRIPT.spawn_text(effect_parent, world_position + miss_text_offset, miss_text, miss_text_color)
