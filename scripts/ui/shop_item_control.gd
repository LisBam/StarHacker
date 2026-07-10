extends Button
class_name ShopItemControl

## 商店商品控件统一展示商品名称、类型、价格倍率、二手状态和完整物品悬停详情。
## 控件只发出购买请求，不直接访问金币或修改库存，普通商店与灰市可共同复用。

signal purchase_requested(stock_id: String, failure_group_id: String)

## 物品详情格式化器；复用仓库的武器属性、耐久、强化词条和资源说明。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")

## 当前商品资源；配置后用于悬停详情和显示名称，空值时禁用按钮。
var _item_resource: Resource
## 当前商品稳定编号；购买时交给 ShopService 定位真实条目，不依赖分类后的显示下标。
var _stock_id: String = ""
## 当前灰市失败批次编号；普通商店为空字符串，灰市购买时用于精确移除所属批次。
var _failure_group_id: String = ""
## 当前商品数量；武器固定为一，资源允许显示堆叠数量。
var _quantity: int = 1


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
	# 二手说明；仅普通商店二手枪械显示耐久与历史强化石数量，灰市保留遗失物原状态但不标为二手。
	var second_hand_text: String = ""
	if bool(entry.get("second_hand", false)):
		second_hand_text = " · 二手枪械 · 曾使用 %d 颗强化石" % maxi(int(entry.get("used_stone_count", 0)), 0)
	text = "%s%s · %s%s\n购买价 %d 金币（原价 × %.2f）" % [item_name, " x%d" % _quantity if _quantity > 1 else "", item_type, second_hand_text, purchase_price, price_multiplier]
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
