extends Node

## 开拓！！行为按当前相机真实世界视野统计其他单位和宝箱，并向属性组件写入独立来源的攻防倍率。
## 计数目标通过节点组显式声明，视野外或已经移除的节点不会继续提供加成。

## 相机缩放安全下限；固定 0.001，避免编辑器异常零缩放导致视野尺寸除零，不作为玩法参数动态修改。
const MINIMUM_CAMERA_ZOOM: float = 0.001
## 被动刷新安全下限；固定 0.02 秒，与资源导出范围一致，避免异常资源每帧无界刷新。
const MINIMUM_REFRESH_INTERVAL: float = 0.02
## 隔离视野边长安全下限；固定 1 像素，防止兼容资源提供负尺寸或退化矩形。
const MINIMUM_FALLBACK_VIEW_AXIS: float = 1.0

## 当前施法角色；默认 null，由被动技能组件注入，用于读取位置、相机和排除自身。
var _caster: Node2D
## 当前战斗属性组件；默认 null，必须提供 set_skill_stat_multiplier 才能应用攻防比例。
var _stats_component: Node
## 当前被动技能资源；默认 null，提供每目标比例、上限、刷新间隔和目标组。
var _skill_data: Resource
## 当前被动技能组件；默认 null，仅保留统一配置签名，行为不访问其内部状态。
var _passive_skill_component: Node
## 下次视野计数剩余时间；默认 0 表示配置后下一帧立即刷新一次。
var _refresh_remaining: float = 0.0
## 当前属性倍率来源标识；默认空字符串，配置后使用技能稳定 ID，角色切换时据此精确移除本被动加成。
var _source_id: String = ""


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, passive_skill_component: Node) -> void:
	## 注入被动依赖并启用逐帧计时；首次 process 会立即完成视野统计。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_passive_skill_component = passive_skill_component
	_source_id = str(skill_data.get("skill_id")) if skill_data != null else ""
	_refresh_remaining = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_caster) or _skill_data == null or _stats_component == null:
		return
	_refresh_remaining = maxf(_refresh_remaining - maxf(delta, 0.0), 0.0)
	if _refresh_remaining > 0.0:
		return
	_refresh_remaining = maxf(float(_skill_data.get("refresh_interval")), MINIMUM_REFRESH_INTERVAL)
	_update_presence_bonus()


func shutdown() -> void:
	## 停用被动时只移除自身稳定来源，不影响其他被动技能写入的倍率。
	if _stats_component != null and _stats_component.has_method("remove_skill_stat_multiplier") and not _source_id.is_empty():
		_stats_component.call("remove_skill_stat_multiplier", _source_id)
	set_process(false)


func _update_presence_bonus() -> void:
	if not _stats_component.has_method("set_skill_stat_multiplier"):
		return
	# 当前相机世界视野矩形；使用真实缩放和窗口尺寸，装备视野变化会自然扩大计数区域。
	var view_rect: Rect2 = _get_camera_world_view_rect()
	# 已计数实例集合；单位和宝箱误入多个组时只计算一次。
	var counted_instance_ids: Dictionary = {}
	# 合法目标数量；默认 0，每个当前视野内的其他单位或宝箱增加 1。
	var target_count: int = 0
	for raw_group in [_skill_data.get("unit_group"), _skill_data.get("chest_group")]:
		# 计数组名；空组安全跳过，允许资源关闭某一类别。
		var target_group: StringName = StringName(str(raw_group))
		if target_group.is_empty():
			continue
		for raw_target in get_tree().get_nodes_in_group(target_group):
			# 计数目标；只接受有效 Node2D、排除角色自身与即将释放节点。
			var target: Node2D = raw_target as Node2D
			if target == null or target == _caster or not is_instance_valid(target) or target.is_queued_for_deletion():
				continue
			# 目标实例编号；用于跨单位组与宝箱组去重。
			var target_instance_id: int = target.get_instance_id()
			if counted_instance_ids.has(target_instance_id) or not view_rect.has_point(target.global_position):
				continue
			counted_instance_ids[target_instance_id] = true
			target_count += 1
	# 每目标倍率；默认 0.02，负数按 0 处理，异常资源不会把被动变成减益。
	var ratio_per_target: float = maxf(float(_skill_data.get("bonus_ratio_per_target")), 0.0)
	# 最大倍率；默认 0.20，最终比例严格限制在 0 至该值。
	var maximum_ratio: float = maxf(float(_skill_data.get("maximum_bonus_ratio")), 0.0)
	# 本次攻防倍率；攻击力与防御力使用同一计数和比例，最多默认 10 个目标达到 20%。
	var resolved_ratio: float = minf(float(target_count) * ratio_per_target, maximum_ratio)
	_stats_component.call("set_skill_stat_multiplier", _source_id, resolved_ratio, resolved_ratio)


func _get_camera_world_view_rect() -> Rect2:
	# 施法者视口；用于查询当前实际参与渲染的 Camera2D，默认与玩家战斗视口一致。
	var caster_viewport: Viewport = _caster.get_viewport()
	# 当前活动相机；从施法者视口读取，不依赖玩家场景中的固定子节点名。
	var camera: Camera2D = caster_viewport.get_camera_2d() if caster_viewport != null else null
	if camera == null or camera.get_viewport() == null:
		# 隔离场景视野尺寸；宽高至少 1 像素，默认由技能资源提供 1280×720。
		var raw_fallback_view_size: Vector2 = _skill_data.get("fallback_view_size")
		# 标准化隔离视野尺寸；只影响没有玩家相机的兼容或测试场景。
		var fallback_view_size: Vector2 = Vector2(maxf(raw_fallback_view_size.x, MINIMUM_FALLBACK_VIEW_AXIS), maxf(raw_fallback_view_size.y, MINIMUM_FALLBACK_VIEW_AXIS))
		return Rect2(_caster.global_position - fallback_view_size * 0.5, fallback_view_size)
	# 当前视口尺寸；取值至少 1×1，避免窗口初始化阶段产生退化范围。
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	# 当前相机缩放；绝对值至少 0.001，缩放越小世界视野越大。
	var camera_zoom: Vector2 = Vector2(maxf(absf(camera.zoom.x), MINIMUM_CAMERA_ZOOM), maxf(absf(camera.zoom.y), MINIMUM_CAMERA_ZOOM))
	# 当前世界视野尺寸；视口像素除以相机缩放，与地图探索系统使用相同语义。
	var world_view_size: Vector2 = viewport_size / camera_zoom
	# 当前相机世界中心；读取平滑后的屏幕中心，缺失移动时与角色位置一致。
	var camera_center: Vector2 = camera.get_screen_center_position()
	return Rect2(camera_center - world_view_size * 0.5, world_view_size)
