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
## 同目标飘字横向偏移步长；默认 18 像素，相邻伤害依次左右错开，运行时修改只影响可读性。
@export_range(0.0, 120.0, 1.0) var horizontal_offset_step: float = 18.0
## 同目标飘字纵向分层步长；默认 12 像素，使连续伤害即使数值宽度较大也不会完全重叠。
@export_range(0.0, 120.0, 1.0) var vertical_offset_step: float = 12.0
## 同目标最多使用的错位槽数量；默认 6，超过后循环使用并依靠旧飘字已上浮的距离保持可读。
@export_range(1, 24, 1) var offset_lane_count: int = 6

## 每个受击目标当前仍存活的伤害飘字弱引用；键为目标实例 ID，值为 WeakRef 数组，用于计算下一次错位槽。
static var _active_popups_by_target: Dictionary = {}
## 按字号共享的 LabelSettings 静态缓存；键为整数字号，值为可复用资源，同字号飘字复用同一设置以消除逐次分配。
static var _label_settings_by_font_size: Dictionary = {}


static func spawn_damage_number(parent_node: Node, world_position: Vector2, damage_value: float, is_critical: bool, target_instance_id: int = 0) -> void:
	## 生成伤害飘字并按受击目标分配错位槽；target_instance_id 为 0 时保持独立居中显示。
	if parent_node == null or damage_value <= 0.0:
		return
	# 飘字实例；由脚本直接创建，避免受击对象依赖额外场景。
	var popup: DamageNumberPopup = DamageNumberPopup.new()
	parent_node.add_child(popup)
	popup.global_position = world_position
	# 错位槽索引；同一目标的存活飘字越多，下一段伤害使用越靠后的交错位置。
	var offset_lane: int = _register_popup(target_instance_id, popup)
	popup._play(damage_value, is_critical, offset_lane)


static func _register_popup(target_instance_id: int, popup: DamageNumberPopup) -> int:
	## 清理已释放弱引用并登记新飘字；返回登记前的活动数量作为稳定错位槽。
	if target_instance_id <= 0:
		return 0
	# 目标活动弱引用；失效节点不会被静态字典强引用，目标销毁后也可在下次命中时自然清理。
	var active_references: Array = _active_popups_by_target[target_instance_id] if _active_popups_by_target.has(target_instance_id) else []
	# 仍有效的弱引用；每项必须解析到场景树内 DamageNumberPopup 才参与槽位计数。
	# 当前实现直接复用存量数组并原地剔除失效项，避免每次命中都构建新的临时数组。
	var valid_references: Array = active_references
	# 倒序遍历索引；从尾部开始原地移除失效项，避免正序删除时跳过相邻元素。
	for reference_index in range(valid_references.size() - 1, -1, -1):
		# 当前遍历弱引用；解析失败或节点已释放的项立即原地移除。
		var popup_reference: Variant = valid_references[reference_index]
		if not (popup_reference is WeakRef and is_instance_valid((popup_reference as WeakRef).get_ref())):
			valid_references.remove_at(reference_index)
	if valid_references.is_empty():
		# 清理后没有存活飘字时先移除该目标键；防止已销毁目标的实例 ID 永久驻留静态字典造成泄漏。
		_active_popups_by_target.erase(target_instance_id)
	# 错位槽；当前有效数量即为新飘字序号，随后登记自身弱引用供后续伤害读取。
	var offset_lane: int = valid_references.size()
	valid_references.append(weakref(popup))
	_active_popups_by_target[target_instance_id] = valid_references
	return offset_lane


static func reset_tracking() -> void:
	## 清空全部按目标登记的飘字弱引用；供宿主在场景切换或战斗初始化入口调用，避免旧战斗目标的实例 ID 长期驻留静态字典。
	_active_popups_by_target.clear()


func _play(damage_value: float, is_critical: bool, offset_lane: int) -> void:
	## 配置伤害文本、字号和错位轨迹；同一目标的连续命中会在左右与高度上交替展开。
	text = str(maxi(roundi(damage_value), 1))
	modulate = critical_damage_color if is_critical else normal_damage_color
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 非线性字号；对数增长保证高伤害更大但不会无限膨胀。
	var resolved_font_size: int = clampi(roundi(float(minimum_font_size) + log(maxf(damage_value, 0.0) + 1.0) * logarithmic_scale_strength), minimum_font_size, maximum_font_size)
	# 当前有效主题字色；LabelSettings 会覆盖主题颜色，共享资源必须同步该颜色才能保持与字号覆盖方案完全相同的视觉。
	var theme_font_color: Color = get_theme_color("font_color")
	# 共享字号设置；同字号飘字复用同一静态 LabelSettings 资源，伤害颜色继续由 modulate 叠加，不改变渲染结果。
	var shared_label_settings: LabelSettings = _label_settings_by_font_size.get(resolved_font_size) as LabelSettings
	if shared_label_settings == null:
		shared_label_settings = LabelSettings.new()
		shared_label_settings.font_size = resolved_font_size
		_label_settings_by_font_size[resolved_font_size] = shared_label_settings
	if shared_label_settings.font_color != theme_font_color:
		shared_label_settings.font_color = theme_font_color
	label_settings = shared_label_settings
	# 有效错位槽；限制槽数量防止极高攻速让文字横向无限远离受击目标。
	var resolved_lane: int = posmod(offset_lane, maxi(offset_lane_count, 1))
	# 横向方向；首段居中，后续依次右、左交替，并按层数逐步增加距离。
	var horizontal_direction: float = 0.0 if resolved_lane == 0 else (1.0 if resolved_lane % 2 == 1 else -1.0)
	# 横向层级；槽 1/2 使用一倍偏移，槽 3/4 使用两倍偏移。
	var horizontal_layer: float = float((resolved_lane + 1) / 2)
	# 初始错位；纵向随槽位上移，确保同时两段伤害至少产生轻微可辨偏移。
	var spawn_offset: Vector2 = Vector2(horizontal_direction * horizontal_layer * horizontal_offset_step, -float(resolved_lane) * vertical_offset_step)
	position -= Vector2(42.0, 26.0)
	position += spawn_offset
	custom_minimum_size = Vector2(84.0, 52.0)
	# 上浮淡出补间；目标死亡后仍可独立播放完成。
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise_distance, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
