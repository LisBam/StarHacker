extends RefCounted
class_name FinanceUnlockRules

## 金融解锁规则集中维护功能标识、成长顺序与累计星穹门槛。
## 主菜单只查询本规则表和全局库存的累计获得值，不复制任何数值或自行推导解锁状态。

## 骇入保险功能标识；作为首个金融功能，在玩家完成约一局平均收益后开放。
const FEATURE_INSURANCE: String = "insurance"
## 星海银行功能标识；作为第二个金融功能，在玩家形成基础可支配资金后开放。
const FEATURE_BANK: String = "bank"
## 量子算力矿场功能标识；作为第三个金融功能，在玩家能够承担长期经营投入后开放。
const FEATURE_MINING_FARM: String = "mining_farm"
## 股票市场功能标识；作为最后一个高复杂度金融功能，在玩家熟悉基础经济循环后开放。
const FEATURE_STOCK_MARKET: String = "stock_market"

## 金融功能成长顺序；界面展示与测试均按保险、银行、矿场、炒股排列。
const UNLOCK_ORDER: Array[String] = [
	FEATURE_INSURANCE,
	FEATURE_BANK,
	FEATURE_MINING_FARM,
	FEATURE_STOCK_MARKET,
]
## 金融功能累计获得星穹门槛；按新手平均每局带出约 1000 星穹物品价值设计为约 1、3、6、10 局阶段。
const UNLOCK_THRESHOLDS: Dictionary = {
	FEATURE_INSURANCE: 1000,
	FEATURE_BANK: 3000,
	FEATURE_MINING_FARM: 6000,
	FEATURE_STOCK_MARKET: 10000,
}


static func get_unlock_threshold(feature_id: String) -> int:
	## 返回指定金融功能的累计获得星穹门槛；未知标识返回极大值，默认保持安全锁定。
	return maxi(int(UNLOCK_THRESHOLDS.get(feature_id, 2147483647)), 0)


static func is_feature_unlocked(feature_id: String, total_coins_earned: int) -> bool:
	## 判断指定金融功能是否达到永久解锁门槛；累计值只增不减，消费星穹不会重新上锁。
	if not UNLOCK_THRESHOLDS.has(feature_id):
		return false
	return maxi(total_coins_earned, 0) >= get_unlock_threshold(feature_id)


static func get_locked_tooltip(feature_id: String) -> String:
	## 返回主菜单未解锁按钮的统一悬停提示；数值直接读取规则表，避免提示与判定脱节。
	return "累计获得%d星穹解锁" % get_unlock_threshold(feature_id)
