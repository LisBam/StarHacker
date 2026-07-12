extends Button
class_name ShopItemControl

## 商店商品控件统一展示商品名称、类型、价格倍率、二手状态和完整物品悬停详情。
## 控件只发出购买请求，不直接访问金币或修改库存，普通商店与灰市可共同复用。

signal purchase_requested(stock_id: String, failure_group_id: String)

## 物品详情格式化器；复用仓库的武器属性、耐久、强化词条和资源说明。
const ITEM_DETAIL_FORMATTER: Script = preload("res://scripts/ui/item_detail_formatter.gd")
## 通用物品卡片视图；普通商店与灰市商品必须与背包、仓库和锻造使用同一固定尺寸模板。
const ITEM_CARD_VIEW_SCRIPT: Script = preload("res://scripts/ui/item_card_view.gd")
## 武器耐久条组件；商店武器卡片复用仓库同款底部耐久条，直接反映二手武器状态。
## 通用耐久补充：当前实际显示由 ItemCardView 内部按耐久属性决定，装备等非武器耐久物品同样适用。
const WEAPON_DURABILITY_BAR_SCRIPT: Script = preload("res://scripts/ui/weapon_durability_bar.gd")
## 商店金币黄色；商品价格统一使用明亮金黄色，便于与普通物品摘要区分。
const COIN_TEXT_COLOR: String = "#ffd45c"

## 当前商品资源；配置后用于悬停详情和显示名称，空值时禁用按钮。
var _item_resource: Resource
## 当前商品稳定编号；购买时交给 ShopService 定位真实条目，不依赖分类后的显示下标。
var _stock_id: String = ""
## 当前灰市失败批次编号；普通商店为空字符串，灰市购买时用于精确移除所属批次。
var _failure_group_id: String = ""
## 当前商品数量；武器固定为一，资源允许显示堆叠数量。
var _quantity: int = 1
## 当前商品购买价格；配置时从商店条目读取，用于卡片与悬停详情统一显示“价格”。
var _purchase_price: int = 0
## 武器耐久条缓存；默认按需创建，资源商品保持隐藏，武器商品固定贴在卡片底部。
## 通用模板补充：该缓存仅保留旧接口兼容，当前商品耐久显示由 _item_card_view 统一承担。
var _durability_bar: Control
## 通用物品卡片视图缓存；默认首次配置时创建，统一商品名称、类型、价格与耐久组件。
var _item_card_view: Control


func configure(entry: Dictionary, is_gray_market: bool) -> void:
	_item_resource = entry.get("resource") as Resource
	_stock_id = str(entry.get("stock_id", ""))
	_failure_group_id = str(entry.get("failure_group_id", "")) if is_gray_market else ""
	_quantity = maxi(int(entry.get("quantity", 1)), 1)
	# 商品价格；刷新时已经固定倍率，卡片只展示最终购买金币。
	var purchase_price: int = maxi(int(entry.get("price", 0)), 0)
	_purchase_price = purchase_price
	# 价格倍率；保留两位小数用于说明普通商店 1.5 至 3 倍或灰市 4 至 8 倍来源。
	var price_multiplier: float = float(entry.get("price_multiplier", 1.0))
	# 商品名称；空资源回退通用文本并禁用交互。
	var item_name: String = str(ITEM_DETAIL_FORMATTER.call("get_item_display_name", _item_resource)) if _item_resource != null else "无效商品"
	# 商品类型；武器显示近战或远程，强化石显示资源类型。
	var item_type: String = str(ITEM_DETAIL_FORMATTER.call("get_item_type_label", _item_resource)) if _item_resource != null else "未知"
	# 是否为武器；用于决定卡片是否展示当前耐久值。
	var is_weapon: bool = _item_resource != null and (str(_item_resource.get("weapon_type")) in ["ranged", "melee", "hybrid"] or str(_item_resource.get("item_kind")) == "equipment")
	# 是否为二手商品；普通商店二手枪械仅在枪械名称前增加简短标识，不显示历史强化细节。
	var _is_second_hand: bool = bool(entry.get("second_hand", false))
	if _is_second_hand:
		item_name = "【二手】%s" % item_name
	# 价格显示文本；默认仅显示最终金币，开发者开启调试信息后才公开原价倍率。
	var price_text: String = _build_price_text(purchase_price, price_multiplier)
	# 商品顶部摘要；强化石第一行显示资源类型，第二行继续由通用卡片显示名称。
	var context_text: String = item_type
	# 商品第三行摘要；强化石只显示彩色属性，普通商品继续显示金币价格。
	var detail_text: String = _build_stone_shop_attribute_text() if _is_enhancement_stone() else price_text
	# 商品第四行摘要；仅强化石显示独立金币价格，形成类型、名称、属性、金币四行排版。
	var secondary_detail_text: String = price_text if _is_enhancement_stone() else ""
	text = ""
	_ensure_item_card_view()
	_item_card_view.call("configure", _item_resource, _quantity, context_text, detail_text, "无效商品", item_name, secondary_detail_text)
	_item_card_view.call("set_visual_state", false, false)
	tooltip_text = ITEM_DETAIL_FORMATTER.call("build_plain_text", _item_resource, _quantity, "价格", _purchase_price) if _item_resource != null else ""
	disabled = _item_resource == null or _stock_id.is_empty()
	_item_card_view.call("set_disabled_state", disabled)
	custom_minimum_size = ITEM_CARD_VIEW_SCRIPT.get_standard_size()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_ARROW
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _on_pressed() -> void:
	if disabled or _stock_id.is_empty():
		return
	purchase_requested.emit(_stock_id, _failure_group_id)


func _on_mouse_entered() -> void:
	if _item_card_view != null and _item_resource != null:
		_item_card_view.call("play_hover", self, true)


func _on_mouse_exited() -> void:
	if _item_card_view != null:
		_item_card_view.call("play_hover", self, false)


func _make_custom_tooltip(_for_text: String) -> Object:
	return ITEM_DETAIL_FORMATTER.call("create_tooltip_control", _item_resource, _quantity, "价格", _purchase_price)


func _build_price_text(purchase_price: int, price_multiplier: float) -> String:
	# 调试设置服务；缺失时按正式显示兜底，避免商店控件与开发者菜单产生硬依赖。
	var debug_settings: Node = get_tree().root.get_node_or_null("DebugSettings")
	# 是否显示调试倍率；默认 false，仅在开发者菜单明确开启后显示原价计算过程。
	var show_debug_information: bool = debug_settings != null and debug_settings.has_method("is_debug_information_visible") and bool(debug_settings.call("is_debug_information_visible"))
	var raw_price_text: String = "%d金币（原价×%.2f）" % [purchase_price, price_multiplier] if show_debug_information else "%d金币" % purchase_price
	return "[color=%s]%s[/color]" % [COIN_TEXT_COLOR, raw_price_text]


func _is_enhancement_stone() -> bool:
	return _item_resource != null and str(_item_resource.get("item_kind")) == "enhancement_stone"


func _build_stone_attribute_text() -> String:
	if not _is_enhancement_stone():
		return ""
	# 强化石属性；按统一规则目录顺序显示属性名称与正负方向，不提前公开使用时才随机的实际百分比。
	var modifiers: Dictionary = EnhancementRules.normalize_modifiers(_item_resource.get("modifiers") as Dictionary)
	# 属性文本集合；多个属性以空格分隔，并由通用卡片负责超长文本居中截断。
	var attribute_tokens: PackedStringArray = PackedStringArray()
	for stat_name in EnhancementRules.STAT_KEYS:
		if modifiers.has(stat_name):
			attribute_tokens.append(EnhancementRules.build_modifier_token(stat_name, modifiers.get(stat_name), false))
	return " ".join(attribute_tokens) if not attribute_tokens.is_empty() else "无属性"


func _build_stone_shop_attribute_text() -> String:
	# 强化石词条；按仓库卡片相同顺序先显示增强、再显示削弱，并按玩法利弊分别着色。
	var modifiers: Dictionary = EnhancementRules.normalize_modifiers(_item_resource.get("modifiers") as Dictionary)
	# 彩色词条；每项包含独立 BBCode，通用物品卡片直接负责渲染。
	var colored_tokens: PackedStringArray = PackedStringArray()
	for beneficial in [true, false]:
		for stat_name in EnhancementRules.STAT_KEYS:
			if not modifiers.has(stat_name) or EnhancementRules.is_direction_beneficial(stat_name, modifiers.get(stat_name)) != beneficial:
				continue
			# 词条颜色；与仓库强化石卡片保持一致，增强为绿色、削弱为红色。
			var color_code: String = "#70e889" if beneficial else "#ff7070"
			colored_tokens.append("[color=%s]%s[/color]" % [color_code, EnhancementRules.build_modifier_token(stat_name, modifiers.get(stat_name), false)])
	return " ".join(colored_tokens) if not colored_tokens.is_empty() else "无词条"


func _ensure_durability_bar() -> void:
	if _durability_bar != null:
		return
	_durability_bar = WEAPON_DURABILITY_BAR_SCRIPT.new() as Control
	_durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_durability_bar)


func _ensure_item_card_view() -> void:
	if _item_card_view != null:
		return
	# 商品按钮只保留购买信号，全部视觉内容由跨系统通用模板承担。
	_item_card_view = ITEM_CARD_VIEW_SCRIPT.new() as Control
	_item_card_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_item_card_view)
