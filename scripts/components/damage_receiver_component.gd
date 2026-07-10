extends Area2D
class_name DamageReceiverComponent

## 伤害接收转发组件让同一实体可以额外挂载 Area2D 命中层，并把伤害统一交给父级聚合脚本处理。
## 当前宝箱使用该组件接收玩家近战命中，静态本体继续负责移动阻挡与双方弹体碰撞。

## 伤害处理节点路径；默认指向父节点，目标必须提供 apply_damage(damage, source) 方法，运行时通常不动态修改。
@export var damage_target_path: NodePath = ^".."

## 伤害处理节点缓存；默认在 ready 后解析，缺失时安全忽略伤害而不会影响其他碰撞。
@onready var _damage_target: Node = get_node_or_null(damage_target_path)


func apply_damage(damage: float, source: Node) -> void:
	# 伤害转发；保留原始伤害来源，便于聚合实体区分玩家、敌方弹体或以后扩展的环境伤害。
	if _damage_target != null and _damage_target.has_method("apply_damage"):
		_damage_target.call("apply_damage", damage, source)
