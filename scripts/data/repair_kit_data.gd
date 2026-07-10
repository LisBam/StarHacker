extends Resource
class_name RepairKitData

## 修复包数据资源描述可堆叠的武器耐久修复道具。
## 修复包只能由仓库或随身背包对玩家持有的武器使用，不能作为锻造材料或作用于其他资源。

## 物品类型；固定为 repair_kit，供库存、分类、UI 与武器和强化石解耦识别。
@export var item_kind: String = "repair_kit"
## 稳定道具标识；默认空字符串，项目内资源必须填写以支持堆叠与存档恢复。
@export var item_id: String = ""
## 道具显示名称；用于仓库、背包、掉落物和悬停详情。
@export var display_name: String = "修复包"
## 道具说明；明确只能作用于武器并在使用后恢复固定耐久。
@export_multiline var description: String = "只能对武器使用，恢复固定耐久。"
## 道具图标文本；默认十字标记，地面掉落与资源卡片共用该简写。
@export var icon_text: String = "+"
## 单个出售价格；取值大于等于 0，出售堆叠时会乘以实际数量。
@export_range(0, 999999, 1) var sell_price: int = 20
## 单个修复包恢复的耐久；取值大于 0，使用时实际恢复量不会超过武器最大耐久。
@export_range(1.0, 10000.0, 1.0, "or_greater") var repair_amount: float = 100.0


func get_stack_signature() -> String:
	return "repair_kit:%s" % item_id


func get_effective_sell_price() -> int:
	return maxi(sell_price, 0)
