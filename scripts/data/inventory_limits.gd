extends RefCounted
class_name InventoryLimits

## 库存限制集中维护背包容量与可堆叠物品的单组数量上限。
## 所有库存服务、地面掉落和物品界面必须读取本文件，避免不同入口使用不一致的容量数字。

## 背包最大物品组数；固定为 50 组，武器、装备和每一组可堆叠资源都各占用一组。
## 现行基础容量补充：新建据点的背包初始上限为 25 组；据点“战术仓储舱”每升 1 级追加 5 组，5 级时达到 50 组。
const BACKPACK_MAX_GROUPS: int = 25
## 可堆叠物品单组上限；固定为 10 件，强化石、修复包和消耗品共同遵守该限制。
const MAX_STACK_QUANTITY: int = 10
## 旧库存存档允许的单组数量上限；固定为 99，仅用于读取历史堆叠并拆分为多个现行十件组，不影响新物品生成。
const LEGACY_MAX_STACK_QUANTITY: int = 99
