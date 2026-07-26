extends Control
class_name MiningIncomeFloatEmitter

## 矿场资产收益飘字发射器按持有数量生成独立的单台收益文字。
## 每台资产每秒对应一次逻辑发射，数量越多，发射间隔越短；组件只负责视觉，不参与真实收益结算。
## 频率上限补充：持有数量超过每秒飘字上限时按上限速率发射，超出的逻辑发射直接丢弃，仅影响视觉密度不影响任何收益数值。

## 单个飘字持续时间；默认 0.85 秒，控制文字从出现到完全消失的总时长。
@export_range(0.20, 3.0, 0.05) var float_duration_seconds: float = 0.85
## 单个飘字上升距离；默认 24 像素，正值表示从名称右侧向上移动。
@export_range(4.0, 80.0, 1.0) var rise_distance: float = 24.0
## 飘字横向随机范围；默认 14 像素，避免多个资产同时产出时文字完全重叠。
@export_range(0.0, 60.0, 1.0) var horizontal_spread: float = 14.0
## 单帧最大生成标签数量；默认 12，用于界面恢复显示或低帧率积压时保护 UI 节点创建开销，不改变真实收益或单次飘字数值。
@export_range(1, 128, 1) var maximum_spawns_per_frame: int = 12
## 每卡每秒最大飘字数量；默认 8，持有量超过该值时按上限速率发射，超出的逻辑发射直接丢弃，只影响视觉不影响真实收益。
@export_range(1, 64, 1) var maximum_floats_per_second: int = 8
## 等待队列硬上限倍率；默认 2，积压逻辑次数最多保留单帧上限的该倍数，防止低帧率下形成永久消化不完的队列。
@export_range(1, 8, 1) var pending_spawn_limit_multiplier: int = 2
## 飘字字体大小；默认 12，与资产名称后的紧凑收益反馈保持协调。
@export_range(8, 28, 1) var float_font_size: int = 12
## 飘字颜色；默认亮绿色，和矿场全局收益反馈使用相同收益语义。
@export var float_color: Color = Color(0.34, 1.0, 0.62, 1.0)

## 当前资产持有数量；默认 0，每个单位每秒贡献一次视觉发射频率。
var _asset_quantity: int = 0
## 当前单台每秒整数收益；默认 0，决定每个独立飘字显示的数值。
var _unit_income_per_second: int = 0
## 是否显示真实整数；默认 false 使用 K/M/B 缩写，与矿场顶部开关保持一致。
var _show_exact_values: bool = false
## 尚未发射的逻辑数量累计；按 delta × 持有数量增长，达到 1 时生成一个飘字。
var _spawn_accumulator: float = 0.0
## 等待视觉展示的逻辑资产次数；低帧率或单帧达到保护上限时累加，后续仍逐个生成单台收益飘字。
var _pending_logical_spawns: int = 0
## 随机数生成器；默认启动时随机化，用于分散飘字横向位置和轻微起始高度。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_random.randomize()
	set_process(_asset_quantity > 0 and _unit_income_per_second > 0)


func configure(asset_quantity: int, unit_income_per_second: int, show_exact_values: bool) -> void:
	## 配置当前卡片的持有数量、单台收益和格式；可在加入场景树前安全调用。
	_asset_quantity = maxi(asset_quantity, 0)
	_unit_income_per_second = maxi(unit_income_per_second, 0)
	_show_exact_values = show_exact_values
	_spawn_accumulator = 0.0
	_pending_logical_spawns = 0
	set_process(_asset_quantity > 0 and _unit_income_per_second > 0)


func _process(delta: float) -> void:
	if _asset_quantity <= 0 or _unit_income_per_second <= 0 or not is_visible_in_tree():
		return
	# 本帧新增逻辑发射量；每个资产单位每秒增加 1，使数量与飘字速度保持线性关系。
	# 频率上限补充：持有量超过每秒飘字上限时按上限速率发射，超出的逻辑飘字直接丢弃，真实收益结算不受影响。
	# 本帧有效发射速率；取持有量与每秒飘字上限的较小值。
	var effective_spawn_rate: float = minf(float(_asset_quantity), float(maxi(maximum_floats_per_second, 1)))
	_spawn_accumulator += maxf(delta, 0.0) * effective_spawn_rate
	# 本帧应发射数量；只取完整单位，余下小数留到后续帧继续累计。
	var requested_spawns: int = int(floor(_spawn_accumulator))
	if requested_spawns > 0:
		_spawn_accumulator -= float(requested_spawns)
		_pending_logical_spawns += requested_spawns
		# 等待队列硬上限；积压最多保留单帧上限的固定倍数，超出部分直接丢弃以防长期积压。
		_pending_logical_spawns = mini(_pending_logical_spawns, maxi(maximum_spawns_per_frame, 1) * maxi(pending_spawn_limit_multiplier, 1))
	# 等待队列刷新；即使本帧没有新增逻辑次数，也会在后续帧继续按创建上限消化积压。
	_flush_pending_spawns()


func _flush_pending_spawns() -> void:
	## 按单帧保护上限消化逻辑收益；每个逻辑资产次数始终对应一个独立的单台收益飘字。
	if _pending_logical_spawns <= 0:
		return
	# 独立飘字数量；积压只延后到后续帧，不合并显示数值或放大字号。
	var individual_spawn_count: int = mini(_pending_logical_spawns, maxi(maximum_spawns_per_frame, 1))
	_pending_logical_spawns -= individual_spawn_count
	for _spawn_index in range(individual_spawn_count):
		_spawn_income_float()


func _spawn_income_float() -> void:
	# 收益飘字；数值固定为一台资产的一秒收益，高持有量只提高独立飘字出现频率。
	var income_label: Label = Label.new()
	income_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	income_label.text = "+%s" % _format_value(_unit_income_per_second)
	income_label.add_theme_font_size_override("font_size", float_font_size)
	income_label.add_theme_color_override("font_color", float_color)
	# 起始位置；横向随机散开并保留少量纵向偏移，使高频文字仍能分辨。
	var start_position: Vector2 = Vector2(
		_random.randf_range(-horizontal_spread, horizontal_spread),
		_random.randf_range(3.0, 9.0)
	)
	income_label.position = start_position
	income_label.modulate.a = 0.0
	add_child(income_label)
	# 飘字动画；先快速显现，再持续上升并逐渐完全消失，结束后释放节点。
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(income_label, "position:y", start_position.y - rise_distance, float_duration_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(income_label, "modulate:a", 1.0, minf(float_duration_seconds * 0.18, 0.15))
	var fade_tween: PropertyTweener = tween.tween_property(income_label, "modulate:a", 0.0, float_duration_seconds * 0.68)
	fade_tween.set_delay(float_duration_seconds * 0.32)
	tween.chain().tween_callback(_finish_income_float.bind(income_label))


func _finish_income_float(income_label: Label) -> void:
	## 回收完成动画的标签；等待队列由处理帧按单帧上限继续生成，不依赖活动飘字数量。
	if is_instance_valid(income_label):
		income_label.queue_free()


func _format_value(value: int) -> String:
	## 根据矿场显示开关格式化单台收益；格式变化只影响文字，不改变每台资产的逻辑发射次数。
	if _show_exact_values:
		return str(value)
	# 绝对值；决定 K、M、B 单位，资产收益本身始终为非负整数。
	var absolute_value: int = absi(value)
	if absolute_value >= 1000000000:
		return "%.2fB" % (float(value) / 1000000000.0)
	if absolute_value >= 1000000:
		return "%.2fM" % (float(value) / 1000000.0)
	if absolute_value >= 10000:
		return "%.2fK" % (float(value) / 1000.0)
	return str(value)
