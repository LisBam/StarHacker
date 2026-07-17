extends Area2D
class_name WeaponDrop

## 通用物品掉落物在地图上保存一件武器，或保存一组堆叠资源及其数量。
## HUD 会扫描 item_drops 组生成附近掉落物列表，玩家点击列表或按 F 后调用 pickup_to_inventory 拾取。

## 库存限制配置；地面堆叠数量必须与背包和仓库的单组上限保持一致。
const INVENTORY_LIMITS: Script = preload("res://scripts/data/inventory_limits.gd")
## 统一物品详情格式化器；武器与装备掉落名称通过该入口保留二手前缀和损坏状态。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")

## 掉落武器资源；默认空表示无效掉落，运行时由 GameWorld 或背包丢弃逻辑写入。
@export var weapon_data: Resource
## 通用掉落物资源；默认空并兼容旧 weapon_data 字段，强化石等非武器物品只写入该字段。
@export var item_data: Resource
## 地面掉落数量；武器固定为 1，可堆叠资源取值 1 到 99，运行时由整组丢弃流程写入且拾取后一次性合并回背包。
## 现行限制补充：武器与装备都固定为 1，可堆叠资源正式取值为 1 到 10，旧注释中的 99 仅描述历史规则。
@export_range(1, 10, 1) var quantity: int = 1
## 可拾取距离；取值建议大于玩家半径，默认 96 像素，HUD 使用该距离判断是否进入附近列表。
@export_range(1.0, 400.0, 1.0, "or_greater") var pickup_radius: float = 96.0
## 掉落物悬浮幅度；取值建议 0 到 12，默认 0 表示地面武器保持静止，修改会影响地面武器轻微浮动表现。
@export_range(0.0, 32.0, 0.5) var bob_amplitude: float = 0.0
## 掉落物悬浮速度；取值建议大于等于 0，默认 0 表示不播放浮动动画，修改会影响地面武器浮动频率。
@export_range(0.0, 20.0, 0.1) var bob_speed: float = 0.0

## 掉落物基础视觉位置；取值为 ready 时视觉节点 position，默认用于叠加悬浮动画。
var _visual_base_position: Vector2 = Vector2.ZERO
## 当前存活时间；取值大于等于 0，默认 0，用于驱动悬浮动画。
var _age: float = 0.0
## 当前是否正在播放宝箱击破飞出动画；默认 false，动画期间不会进入可拾取分组。
var _launching: bool = false
## 当前飞出动画补间；默认 null，用于同时驱动世界位移和视觉抛物线高度。
var _launch_tween: Tween

## 视觉根节点缓存；默认绑定直接子节点 Visual，允许为空以避免场景节点缺失时阻断掉落逻辑。
@onready var _visual_root: Node2D = get_node_or_null("Visual") as Node2D
## 名称标签缓存；默认绑定 Visual/NameLabel，用于显示武器简称，允许为空以兼容临时掉落物场景。
@onready var _name_label: Label = get_node_or_null("Visual/NameLabel") as Label
## 图标标签缓存；默认绑定 Visual/IconLabel，用于显示武器 icon_text，允许为空以兼容临时掉落物场景。
@onready var _icon_label: Label = get_node_or_null("Visual/IconLabel") as Label


func _ready() -> void:
	add_to_group("item_drops")
	add_to_group("weapon_drops")
	if _visual_root != null:
		_visual_base_position = _visual_root.position
	set_process(bob_amplitude > 0.0 and bob_speed > 0.0)
	_refresh_visual()


func _process(delta: float) -> void:
	_age += delta
	if _visual_root == null:
		return

	if bob_amplitude > 0.0 and bob_speed > 0.0:
		# 悬浮偏移；取值为正弦函数结果，默认让掉落物轻微上下浮动。
		var bob_offset: float = sin(_age * bob_speed) * bob_amplitude
		_visual_root.position = _visual_base_position + Vector2(0.0, bob_offset)


func configure_drop(new_weapon_data: Resource) -> void:
	weapon_data = new_weapon_data
	item_data = new_weapon_data
	quantity = 1
	_refresh_visual()


func configure_item_drop(new_item_data: Resource, new_quantity: int = 1) -> void:
	item_data = new_item_data
	weapon_data = new_item_data if new_item_data != null and str(new_item_data.get("item_kind")) != "enhancement_stone" else null
	# 有效地面数量；武器和装备始终是一件，只有可堆叠资源保留传入数量。
	var is_stackable_item: bool = new_item_data != null and str(new_item_data.get("item_kind")) in ["enhancement_stone", "repair_kit", "consumable"]
	quantity = clampi(new_quantity, 1, INVENTORY_LIMITS.MAX_STACK_QUANTITY) if is_stackable_item else 1
	_refresh_visual()


func get_weapon_data() -> Resource:
	return _get_item_data()


func get_item_data() -> Resource:
	## 返回当前地面物品资源；结算被动与世界统计通过只读接口计价，不直接访问兼容字段。
	return _get_item_data()


func get_pickup_radius() -> float:
	return pickup_radius


func get_quantity() -> int:
	## 返回地面节点代表的实际物品数量；附近列表、拾取和结算计价均可通过该只读接口取得一致结果。
	return clampi(quantity, 1, INVENTORY_LIMITS.MAX_STACK_QUANTITY)


func play_launch_animation(target_position: Vector2, duration: float, arc_height: float) -> void:
	if _launch_tween != null and _launch_tween.is_valid():
		_launch_tween.kill()
	_launching = true
	remove_from_group("item_drops")
	remove_from_group("weapon_drops")
	# 有效动画参数；时长至少 0.05 秒，弧高使用正值确保物品先向上飞出再落地。
	var resolved_duration: float = maxf(duration, 0.05)
	# 有效抛物线高度；默认由 GameWorld 按击破掉落配置传入。
	var resolved_arc_height: float = maxf(arc_height, 0.0)
	_launch_tween = create_tween()
	_launch_tween.set_parallel(true)
	_launch_tween.tween_property(self, "global_position", target_position, resolved_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _visual_root != null:
		# 视觉上升阶段；占总时长 42%，与水平位移共同形成明显飞出轨迹。
		var rise_duration: float = resolved_duration * 0.42
		# 视觉下降阶段；占剩余时长，落地后回到原始视觉位置。
		var fall_duration: float = resolved_duration - rise_duration
		var arc_tween: Tween = create_tween()
		arc_tween.tween_property(_visual_root, "position", _visual_base_position + Vector2.UP * resolved_arc_height, rise_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arc_tween.tween_property(_visual_root, "position", _visual_base_position, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_launch_tween.chain().tween_callback(_finish_launch_animation)


func get_pickup_display_name() -> String:
	# 当前掉落资源；优先读取通用字段并兼容旧武器场景配置。
	var current_item_data: Resource = _get_item_data()
	if current_item_data == null:
		return "未知物品"
	# 物品显示名；强化石优先使用增强词条预览，其他类型读取通用 display_name。
	var display_name: String = ""
	if str(current_item_data.get("item_kind")) == "enhancement_stone" and current_item_data.has_method("get_pickup_preview_name"):
		display_name = str(current_item_data.call("get_pickup_preview_name"))
	else:
		display_name = str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", current_item_data))
	if display_name.is_empty():
		return "未知物品"

	return "%s x%d" % [display_name, get_quantity()] if get_quantity() > 1 else display_name


func pickup_to_inventory(inventory_component: Node) -> bool:
	# 当前掉落资源；拾取时把同一资源实例交给全局库存，以便本局收益统计排除重复拾取。
	var current_item_data: Resource = _get_item_data()
	if _launching or current_item_data == null or inventory_component == null or not inventory_component.has_method("add_item"):
		return false

	# 实际拾取数量；新版组件可一次合并整组资源，旧组件只兼容单件掉落。
	var pickup_quantity: int = get_quantity()
	# 拾取是否成功；只有整个地面堆叠都被库存服务接收后才移除掉落节点，失败时数量和节点保持不变。
	var pickup_succeeded: bool = bool(inventory_component.call("add_item_quantity", current_item_data, pickup_quantity)) if inventory_component.has_method("add_item_quantity") else pickup_quantity == 1 and bool(inventory_component.call("add_item", current_item_data))
	if not pickup_succeeded:
		return false
	remove_from_group("item_drops")
	remove_from_group("weapon_drops")
	weapon_data = null
	item_data = null
	quantity = 1
	visible = false
	queue_free()
	return true


func consume_for_training() -> bool:
	## 训练场拾取只消费地面掉落，不写入全局背包或存档，保证训练奖励不会污染正式库存。
	if _launching or _get_item_data() == null:
		return false
	queue_free()
	return true


func show_pickup_status(message: String = "背包已满！") -> void:
	## 在掉落物上方显示短暂拾取状态；默认用于背包满时反馈，不改变掉落物所有权。
	var status_label: Label = Label.new()
	status_label.text = message
	status_label.position = Vector2(-70.0, -46.0)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 1.0))
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)
	var tween: Tween = create_tween()
	tween.tween_property(status_label, "position", status_label.position + Vector2(0.0, -22.0), 0.65)
	tween.parallel().tween_property(status_label, "modulate:a", 0.0, 0.65)
	tween.tween_callback(status_label.queue_free)


func _refresh_visual() -> void:
	if _name_label == null or _icon_label == null:
		return

	_name_label.text = get_pickup_display_name()
	# 当前掉落资源；用于统一刷新武器和强化石图标。
	var current_item_data: Resource = _get_item_data()
	if current_item_data == null:
		_icon_label.text = "?"
		return

	# 图标文本；取值来自物品资源 icon_text 字段，默认问号用于未配置图标。
	var icon_text: String = str(current_item_data.get("icon_text"))
	_icon_label.text = "?" if icon_text.is_empty() else icon_text


func _get_item_data() -> Resource:
	return item_data if item_data != null else weapon_data


func _finish_launch_animation() -> void:
	_launching = false
	add_to_group("item_drops")
	add_to_group("weapon_drops")
	if _visual_root != null:
		_visual_root.position = _visual_base_position
