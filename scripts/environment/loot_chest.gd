extends StaticBody2D
class_name LootChest

## 宝箱是可受击、可长按开启的静态建筑实体。
## 宝箱只负责品质数值、生命、开启进度和释放请求，实际掉落物池由 GameWorld 统一生成。

signal loot_released(chest_position: Vector2, quality_id: String, drop_count: int, minimum_high_quality_count: int, broken_open: bool)
signal chest_removed(chest: Node)

## 普通宝箱品质标识；用于品质抽取、视觉和掉落权重查询。
const QUALITY_COMMON: String = "common"
## 中级宝箱品质标识；用于品质抽取、视觉和掉落权重查询。
const QUALITY_MEDIUM: String = "medium"
## 高级宝箱品质标识；用于品质抽取、视觉和掉落权重查询。
const QUALITY_HIGH: String = "high"
## 极品宝箱品质标识；用于品质抽取、视觉和必定高品质掉落规则。
const QUALITY_SUPREME: String = "supreme"
## 品质顺序；与 47%、35%、15%、3% 权重共同构成完整随机分布。
const QUALITY_ORDER: Array[String] = [QUALITY_COMMON, QUALITY_MEDIUM, QUALITY_HIGH, QUALITY_SUPREME]
## 品质权重；总和固定为 1.0，修改会直接改变地图宝箱品质分布。
const QUALITY_WEIGHTS: Dictionary = {QUALITY_COMMON: 0.47, QUALITY_MEDIUM: 0.35, QUALITY_HIGH: 0.15, QUALITY_SUPREME: 0.03}
## 品质数值表；依次记录名称、生命、基础开启时间、掉落数量范围和最低高品质数量。
const QUALITY_CONFIGS: Dictionary = {
	QUALITY_COMMON: {"display_name": "普通宝箱", "health": 20.0, "hold_duration": 1.0, "drop_min": 2, "drop_max": 4, "minimum_high_quality_count": 0, "color": Color(0.48, 0.62, 0.70, 1.0)},
	QUALITY_MEDIUM: {"display_name": "中级宝箱", "health": 40.0, "hold_duration": 2.0, "drop_min": 3, "drop_max": 6, "minimum_high_quality_count": 0, "color": Color(0.30, 0.72, 1.0, 1.0)},
	QUALITY_HIGH: {"display_name": "高级宝箱", "health": 100.0, "hold_duration": 3.0, "drop_min": 4, "drop_max": 8, "minimum_high_quality_count": 0, "color": Color(0.72, 0.42, 1.0, 1.0)},
	QUALITY_SUPREME: {"display_name": "极品宝箱", "health": 200.0, "hold_duration": 5.0, "drop_min": 5, "drop_max": 10, "minimum_high_quality_count": 5, "color": Color(1.0, 0.68, 0.18, 1.0)},
}

## 玩家可长按开启的交互距离；默认 104 像素，修改会影响 HUD 选择附近宝箱的范围。
@export_range(32.0, 320.0, 1.0) var interaction_radius: float = 104.0
## 进度条最小有效开启时间；默认 0.05 秒，防止残血宝箱出现除零或无法完成的极小时间。
@export_range(0.01, 1.0, 0.01) var minimum_hold_duration: float = 0.05

## 当前品质标识；默认普通，生成后由 GameWorld 按品质权重配置。
var _quality_id: String = QUALITY_COMMON
## 当前宝箱生命；默认 10，与普通宝箱配置一致，受到伤害后限制到 0 以上。
var _current_health: float = 20.0
## 当前宝箱最大生命；默认 10，用于把受伤比例映射为长按时间缩减比例。
var _maximum_health: float = 20.0
## 当前品质基础长按时间；默认 1 秒，实际需求会乘剩余生命比例。
var _base_hold_duration: float = 1.0
## 当前长按累计时间；默认 0，松开交互、离开范围或切换目标时重置。
var _hold_elapsed: float = 0.0
## 当前是否收到 HUD 的持续开启请求；默认 false，只有周围没有可拾取掉落物且玩家按住 F 时启用。
var _interaction_active: bool = false
## 当前交互玩家；默认 null，用于宝箱自身复核距离，避免 HUD 状态延迟造成远程开启。
var _interaction_player: Node2D
## 宝箱是否已经释放掉落；默认 false，确保受击归零和长按完成同帧发生时只结算一次。
var _opened: bool = false
## 宝箱随机数生成器；默认启动时随机化，用于在品质数量范围内抽取实际掉落数量。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 调试设置服务；默认从 AutoLoad 获取，决定品质标签是否附加当前与最大生命值。
var _debug_settings: Node

## 宝箱主体视觉；默认绑定 BodyVisual，用于按品质统一着色。
@onready var _body_visual: Polygon2D = get_node_or_null("BodyVisual") as Polygon2D
## 宝箱品质标签；默认绑定 QualityLabel，显示当前品质名称和生命。
@onready var _quality_label: Label = get_node_or_null("QualityLabel") as Label
## 宝箱开启进度条；默认绑定 OpenProgress，只有有效长按交互期间显示在宝箱上方。
@onready var _open_progress: ProgressBar = get_node_or_null("OpenProgress") as ProgressBar
## 宝箱交互提示；默认绑定 InteractionLabel，玩家进入范围且尚未长按时显示“长按F开启”。
@onready var _interaction_label: Label = get_node_or_null("InteractionLabel") as Label


func _ready() -> void:
	_random.randomize()
	_debug_settings = get_tree().root.get_node_or_null("DebugSettings")
	if _debug_settings != null and _debug_settings.has_signal("debug_information_visibility_changed"):
		_debug_settings.connect("debug_information_visibility_changed", Callable(self, "_on_debug_information_visibility_changed"))
	add_to_group("loot_chests")
	add_to_group("environment_obstacles")
	_refresh_quality_state()
	# 未交互宝箱只保留物理、绘制与受伤入口，长按开始后再启用进度处理。
	set_process(false)


func _process(delta: float) -> void:
	if _opened:
		set_process(false)
		return
	if not _interaction_active or _interaction_player == null or not is_instance_valid(_interaction_player):
		_interaction_active = false
		_interaction_player = null
		set_process(false)
		_reset_hold_progress()
		return
	# 当前交互距离；与 HUD 使用同一宝箱公开半径，平方比较避免长按期间逐帧开方。
	var interaction_distance: float = get_interaction_radius()
	if global_position.distance_squared_to(_interaction_player.global_position) > interaction_distance * interaction_distance:
		_interaction_active = false
		_interaction_player = null
		set_process(false)
		_reset_hold_progress()
		return
	# 当前有效开启时间；受伤后按剩余生命比例线性缩短，生命归零会由伤害流程立即开启。
	var effective_hold_duration: float = get_effective_hold_duration()
	_hold_elapsed = minf(_hold_elapsed + maxf(delta, 0.0), effective_hold_duration)
	_refresh_progress_bar(effective_hold_duration)
	if _hold_elapsed >= effective_hold_duration:
		_release_loot(false)


func configure_quality(quality_id: String) -> void:
	# 品质配置；异常标识回退普通宝箱，确保生命、开启时间和掉落数量始终完整。
	_quality_id = quality_id if quality_id in QUALITY_ORDER else QUALITY_COMMON
	# 当前品质配置；集中读取生命、长按时间、掉落数量和视觉颜色。
	var quality_config: Dictionary = QUALITY_CONFIGS.get(_quality_id, QUALITY_CONFIGS[QUALITY_COMMON]) as Dictionary
	_maximum_health = maxf(float(quality_config.get("health", 10.0)), 1.0)
	_current_health = _maximum_health
	_base_hold_duration = maxf(float(quality_config.get("hold_duration", 1.0)), minimum_hold_duration)
	_hold_elapsed = 0.0
	_refresh_quality_state()


func apply_damage(damage: float, _source: Node) -> void:
	if _opened or damage <= 0.0:
		return
	_current_health = maxf(_current_health - damage, 0.0)
	_refresh_quality_state()
	if _current_health <= 0.0:
		_release_loot(true)
		return
	# 已积累进度可能在受伤缩短需求后立即达到新阈值，此时直接完成开启。
	if _hold_elapsed >= get_effective_hold_duration():
		_release_loot(false)


func set_open_interaction_active(active: bool, player: Node2D) -> void:
	# 交互请求；切换目标或松开按键时重置进度，持续作用于同一宝箱时保留累计值。
	if not active:
		_interaction_active = false
		_interaction_player = null
		# 取消或松开长按后立即停止进度回调，等待下一次交互重新启用。
		set_process(false)
		_reset_hold_progress()
		return
	_interaction_active = true
	_interaction_player = player
	# 长按请求生效后启用进度回调，实际距离仍由宝箱自身逐帧复核。
	set_process(true)
	if _interaction_label != null:
		_interaction_label.visible = false


func set_interaction_prompt_visible(visible: bool) -> void:
	if _interaction_label != null:
		_interaction_label.visible = visible and not _opened and not _interaction_active


func get_interaction_radius() -> float:
	return maxf(interaction_radius, 1.0)


func get_effective_hold_duration() -> float:
	# 剩余生命比例；伤害越高，所需长按时间越短，0 生命由受击流程直接释放掉落。
	var health_ratio: float = clampf(_current_health / maxf(_maximum_health, 1.0), 0.0, 1.0)
	return maxf(_base_hold_duration * health_ratio, minimum_hold_duration)


func get_chest_display_name() -> String:
	# 当前品质配置；显示名称缺失时回退通用“宝箱”。
	var quality_config: Dictionary = QUALITY_CONFIGS.get(_quality_id, QUALITY_CONFIGS[QUALITY_COMMON]) as Dictionary
	return str(quality_config.get("display_name", "宝箱"))


static func roll_quality(random_source: RandomNumberGenerator) -> String:
	if random_source == null:
		return QUALITY_COMMON
	# 品质随机值；依次落入 47%、35%、15% 和 3% 的累计区间。
	var quality_roll: float = random_source.randf()
	# 累计品质权重；按普通到极品顺序映射随机值。
	var cumulative_weight: float = 0.0
	for quality_id in QUALITY_ORDER:
		cumulative_weight += float(QUALITY_WEIGHTS.get(quality_id, 0.0))
		if quality_roll < cumulative_weight:
			return quality_id
	return QUALITY_SUPREME


func _release_loot(broken_open: bool) -> void:
	if _opened:
		return
	_opened = true
	_interaction_active = false
	set_process(false)
	# 当前品质配置；用于抽取掉落数量并读取极品最低高品质数量。
	var quality_config: Dictionary = QUALITY_CONFIGS.get(_quality_id, QUALITY_CONFIGS[QUALITY_COMMON]) as Dictionary
	# 实际掉落数量；在当前品质闭区间内等概率抽取，极品额外请求至少 5 件高品质物品。
	var drop_count: int = _random.randi_range(int(quality_config.get("drop_min", 2)), int(quality_config.get("drop_max", 4)))
	# 最低高品质掉落数量；不会超过本次实际总掉落数。
	var minimum_high_quality_count: int = mini(int(quality_config.get("minimum_high_quality_count", 0)), drop_count)
	# 股市统计服务；宝箱打开只上报一次，不关心手动开启或击破方式。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_method("record_run_metric"):
		stock_market_service.call("record_run_metric", "chests_opened", 1.0)
	loot_released.emit(global_position, _quality_id, drop_count, minimum_high_quality_count, broken_open)
	chest_removed.emit(self)
	queue_free()


func force_network_remove() -> void:
	## 联机静默移除；其他成员已开启或击毁同位置宝箱时调用，本机不出货、不上报开箱统计，只派发移除信号并释放节点。
	if _opened:
		return
	_opened = true
	_interaction_active = false
	set_process(false)
	chest_removed.emit(self)
	queue_free()


func _reset_hold_progress() -> void:
	_hold_elapsed = 0.0
	if _open_progress != null:
		_open_progress.visible = false
		_open_progress.value = 0.0
	if _interaction_label != null:
		_interaction_label.visible = false


func _refresh_progress_bar(effective_hold_duration: float) -> void:
	if _open_progress == null:
		return
	_open_progress.visible = true
	_open_progress.max_value = 1.0
	_open_progress.value = clampf(_hold_elapsed / maxf(effective_hold_duration, minimum_hold_duration), 0.0, 1.0)


func _refresh_quality_state() -> void:
	# 当前品质配置；同步刷新主体颜色和生命文本。
	var quality_config: Dictionary = QUALITY_CONFIGS.get(_quality_id, QUALITY_CONFIGS[QUALITY_COMMON]) as Dictionary
	if _body_visual != null:
		_body_visual.color = quality_config.get("color", Color.WHITE)
	if _quality_label != null:
		# 调试信息可见状态；正式显示只保留宝箱品质，开启开发者调试后才附加生命数值。
		var show_debug_information: bool = _debug_settings != null and _debug_settings.has_method("is_debug_information_visible") and bool(_debug_settings.call("is_debug_information_visible"))
		_quality_label.text = "%s  %d/%d" % [get_chest_display_name(), ceili(_current_health), ceili(_maximum_health)] if show_debug_information else get_chest_display_name()


func _on_debug_information_visibility_changed(_visible: bool) -> void:
	_refresh_quality_state()
