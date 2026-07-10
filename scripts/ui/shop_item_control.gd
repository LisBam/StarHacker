extends Button
class_name ShopItemControl

## 商店商品控件统一展示商品名称、类型、价格倍率、二手状态和完整物品悬停详情。
## 控件只发出购买请求，不直接访问金币或修改库存，普通商店与灰市可共同复用。

signal purchase_requested(stock_id: String, failure_group_id: String)

## 物品详情格式化器；复用仓库的武器属性、耐久、强化词条和资源说明。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 武器耐久条组件；商店武器卡片复用仓库同款底部耐久条，直接反映二手武器状态。
const WEAPON_DURABILITY_BAR_SCRIPT: Script = preload("res://scripts/ui/weapon_durability_bar.gd")

## 当前商品资源；配置后用于悬停详情和显示名称，空值时禁用按钮。
var _item_resource: Resource
## 当前商品稳定编号；购买时交给 ShopService 定位真实条目，不依赖分类后的显示下标。
var _stock_id: String = ""
## 当前灰市失败批次编号；普通商店为空字符串，灰市购买时用于精确移除所属批次。
var _failure_group_id: String = ""
## 当前商品数量；武器固定为一，资源允许显示堆叠数量。
var _quantity: int = 1
## 武器耐久条缓存；默认按需创建，资源商品保持隐藏，武器商品固定贴在卡片底部。
var _durability_bar: Control


func configure(entry: Dictionary, is_gray_market: bool) -> void:
	_item_resource = entry.get("resource") as Resource
	_stock_id = str(entry.get("stock_id", ""))
	_failure_group_id = str(entry.get("failure_group_id", "")) if is_gray_market else ""
	_quantity = maxi(int(entry.get("quantity", 1)), 1)
	# 商品价格；刷新时已经固定倍率，卡片只展示最终购买金币。
	var purchase_price: int = maxi(int(entry.get("price", 0)), 0)
	# 价格倍率；保留两位小数用于说明普通商店 1.5 至 3 倍或灰市 4 至 8 倍来源。
	var price_multiplier: float = float(entry.get("price_multiplier", 1.0))
	# 商品名称；空资源回退通用文本并禁用交互。
	var item_name: String = str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", _item_resource)) if _item_resource != null else "无效商品"
	# 商品类型；武器显示近战或远程，强化石显示资源类型。
	var item_type: String = str(ITEM_DETAIL_FORMATTER.call("get_item_type_label", _item_resource)) if _item_resource != null else "未知"
	# 是否为武器；用于决定卡片是否展示当前耐久值。
	var is_weapon: bool = _item_resource != null and str(_item_resource.get("weapon_type")) in ["ranged", "melee"]
	# 是否为二手商品；普通商店二手枪械仅在枪械名称前增加简短标识，不显示历史强化细节。
	var _is_second_hand: bool = bool(entry.get("second_hand", false))
	if _is_second_hand:
		item_name = "【二手】%s" % item_name
	# 价格显示文本；默认仅显示最终金币，开发者开启调试信息后才公开原价倍率。
	var price_text: String = _build_price_text(purchase_price, price_multiplier)
	if is_weapon:
		text = "%s · %s\n%s" % [item_name, item_type, price_text]
	else:
		text = "%s%s · %s\n%s" % [item_name, " x%d" % _quantity if _quantity > 1 else "", item_type, price_text]
	_ensure_durability_bar()
	_durability_bar.call("configure", _item_resource)
	_durability_bar.visible = is_weapon
	tooltip_text = ITEM_DETAIL_FORMATTER.call("build_plain_text", _item_resource, _quantity) if _item_resource != null else ""
	disabled = _item_resource == null or _stock_id.is_empty()
	custom_minimum_size = Vector2(0.0, 66.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_ARROW
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if disabled or _stock_id.is_empty():
		return
	purchase_requested.emit(_stock_id, _failure_group_id)


func _make_custom_tooltip(_for_text: String) -> Object:
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", _item_resource, _quantity)


func _build_price_text(purchase_price: int, price_multiplier: float) -> String:
	# 调试设置服务；缺失时按正式显示兜底，避免商店控件与开发者菜单产生硬依赖。
	var debug_settings: Node = get_tree().root.get_node_or_null("DebugSettings")
	# 是否显示调试倍率；默认 false，仅在开发者菜单明确开启后显示原价计算过程。
	var show_debug_information: bool = debug_settings != null and debug_settings.has_method("is_debug_information_visible") and bool(debug_settings.call("is_debug_information_visible"))
	return "%d金币（原价×%.2f）" % [purchase_price, price_multiplier] if show_debug_information else "%d金币" % purchase_price


func _ensure_durability_bar() -> void:
	if _durability_bar != null:
		return
	_durability_bar = WEAPON_DURABILITY_BAR_SCRIPT.new() as Control
	_durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_durability_bar)
