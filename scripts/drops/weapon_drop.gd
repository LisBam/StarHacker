extends Area2D
class_name WeaponDrop

## 武器掉落物在地图上保存一把武器资源。
## HUD 会扫描 weapon_drops 组生成附近掉落物列表，玩家点击列表或按 F 后调用 pickup_to_inventory 拾取。

## 掉落武器资源；默认空表示无效掉落，运行时由 GameWorld 或背包丢弃逻辑写入。
@export var weapon_data: Resource
## 可拾取距离；取值建议大于玩家半径，默认 96 像素，HUD 使用该距离判断是否进入附近列表。
@export_range(1.0, 400.0, 1.0, "or_greater") var pickup_radius: float = 96.0
## 掉落物悬浮幅度；取值建议 0 到 12，默认 4 像素，修改会影响地面武器轻微浮动表现。
@export_range(0.0, 32.0, 0.5) var bob_amplitude: float = 4.0
## 掉落物悬浮速度；取值建议大于 0，默认 3，修改会影响地面武器浮动频率。
@export_range(0.0, 20.0, 0.1) var bob_speed: float = 3.0

## 掉落物基础视觉位置；取值为 ready 时视觉节点 position，默认用于叠加悬浮动画。
var _visual_base_position: Vector2 = Vector2.ZERO
## 当前存活时间；取值大于等于 0，默认 0，用于驱动悬浮动画。
var _age: float = 0.0

## 视觉根节点缓存；默认绑定直接子节点 Visual，允许为空以避免场景节点缺失时阻断掉落逻辑。
@onready var _visual_root: Node2D = get_node_or_null("Visual") as Node2D
## 名称标签缓存；默认绑定 Visual/NameLabel，用于显示武器简称，允许为空以兼容临时掉落物场景。
@onready var _name_label: Label = get_node_or_null("Visual/NameLabel") as Label
## 图标标签缓存；默认绑定 Visual/IconLabel，用于显示武器 icon_text，允许为空以兼容临时掉落物场景。
@onready var _icon_label: Label = get_node_or_null("Visual/IconLabel") as Label


func _ready() -> void:
	add_to_group("weapon_drops")
	if _visual_root != null:
		_visual_base_position = _visual_root.position
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
	_refresh_visual()


func get_weapon_data() -> Resource:
	return weapon_data


func get_pickup_radius() -> float:
	return pickup_radius


func get_pickup_display_name() -> String:
	if weapon_data == null:
		return "未知武器"

	# 武器显示名；取值来自资源 display_name 字段，默认用于附近掉落物列表和按钮文本。
	var display_name: String = str(weapon_data.get("display_name"))
	if display_name.is_empty():
		return "未知武器"

	return display_name


func pickup_to_inventory(inventory_component: Node) -> bool:
	if weapon_data == null or inventory_component == null or not inventory_component.has_method("add_item"):
		return false

	if not bool(inventory_component.call("add_item", weapon_data)):
		return false

	remove_from_group("weapon_drops")
	visible = false
	queue_free()
	return true


func _refresh_visual() -> void:
	if _name_label == null or _icon_label == null:
		return

	_name_label.text = get_pickup_display_name()
	if weapon_data == null:
		_icon_label.text = "?"
		return

	# 图标文本；取值来自武器资源 icon_text 字段，默认问号用于未配置图标。
	var icon_text: String = str(weapon_data.get("icon_text"))
	_icon_label.text = "?" if icon_text.is_empty() else icon_text
