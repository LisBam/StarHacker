extends Node2D
class_name NetworkDamageProxy

## 网络伤害代理在本机重建一次远程伤害来源；它实现受击方会向 source 查询的全部战斗数值接口。
## 客户端玩家受到主机敌人伤害、主机敌人受到客户端玩家伤害时，都由同步器把数值写入本代理后再走本地标准受击流程。
## 代理是复用节点，不参与场景保存；每次转发伤害前由 NetworkCombatSync 重新配置全部字段。

## 代理攻击力；来自远程伤害来源的 get_attack_power 查询结果，参与本地攻防公式。
var proxy_attack_power: float = 100.0
## 代理暴击率；取值 0 到 1，来自远程伤害来源，本地受击方用它重放暴击判定。
var proxy_critical_chance: float = 0.0
## 代理暴击倍率；默认 1.5，来自远程伤害来源，参与本地伤害公式。
var proxy_critical_damage_multiplier: float = 1.5
## 代理冲击力；单位为单次无碰撞理论位移像素，受击方按自身韧性换算击退初速度。
var proxy_impact_force: float = 0.0
## 代理击退方向；取值为单位向量，零向量时受击方回退按位置推导方向。
var proxy_knockback_direction: Vector2 = Vector2.ZERO


func configure_remote_damage(attack_power: float, critical_chance: float, critical_damage_multiplier: float, impact_force: float, knockback_direction: Vector2, source_position: Vector2) -> void:
	## 一次性写入远程伤害来源的全部战斗数值与世界位置；随后立即把本代理作为 source 传入受击接口。
	proxy_attack_power = maxf(attack_power, 0.0)
	proxy_critical_chance = clampf(critical_chance, 0.0, 1.0)
	proxy_critical_damage_multiplier = maxf(critical_damage_multiplier, 1.0)
	proxy_impact_force = maxf(impact_force, 0.0)
	proxy_knockback_direction = knockback_direction
	global_position = source_position


func get_attack_power() -> float:
	return proxy_attack_power


func get_critical_chance() -> float:
	return proxy_critical_chance


func get_critical_damage_multiplier() -> float:
	return proxy_critical_damage_multiplier


func get_impact_force() -> float:
	return proxy_impact_force


func get_knockback_direction() -> Vector2:
	if proxy_knockback_direction.is_zero_approx():
		return Vector2.ZERO
	return proxy_knockback_direction.normalized()
