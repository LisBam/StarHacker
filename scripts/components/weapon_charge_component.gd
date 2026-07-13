extends Node
class_name WeaponChargeComponent

## 武器蓄力组件只维护一次武器蓄力的时间、来源和临时防御/移动效果。
## 玩家控制器负责读取输入与执行攻击，本组件不生成命中、不扣能量和耐久，避免特殊效果重复结算攻击成本。

## 共用蓄力条所有者 ID；固定 weapon，保证武器结束只能隐藏自己取得的显示，不覆盖主动技能蓄力。
const CHARGE_BAR_OWNER_ID: StringName = &"weapon"

## 蓄力条路径；默认复用角色头顶进度条，缺失时蓄力机制仍正常运行，运行时通常不动态修改。
@export var charge_bar_path: NodePath = ^"../SkillChargeBar"

## 当前蓄力武器；默认 null 表示没有活动蓄力，武器切换、输入关闭或释放后会立即清空。
var _charging_weapon: Resource
## 当前蓄力对应的攻击通道；取值为 ranged 或 melee，默认空字符串，混合武器释放时仍由控制器同时执行两个通道。
## 当前规则补充：混合武器释放时只执行本字段记录的单一通道，另一通道拥有独立输入与冷却。
var _attack_mode: String = ""
## 当前蓄力武器的实际装备来源；取值为 ranged 或 melee，默认空字符串，用于释放时恢复真实槽位反馈。
var _source_kind: String = ""
## 当前蓄力武器的远程槽索引；取值为 -1 或有效远程槽，默认 -1 表示来源不是远程槽。
var _source_index: int = -1
## 当前累计蓄力时间；取值 0 至武器最大蓄力时间，默认 0，达到上限后保持不再增长。
var _charge_elapsed: float = 0.0

## 角色头顶蓄力条缓存；默认按 charge_bar_path 解析，允许为空以支持无界面验证场景。
@onready var _charge_bar: Node = get_node_or_null(charge_bar_path)


func begin_charge(weapon_data: Resource, attack_mode: String, source_kind: String = "", source_index: int = -1) -> bool:
	## 开始一次可配置武器蓄力；已有蓄力或资源未声明效果时返回 false，不覆盖当前输入状态。
	if _charging_weapon != null or weapon_data == null or not bool(weapon_data.get("has_charge_effect")):
		return false
	_charging_weapon = weapon_data
	_attack_mode = attack_mode
	_source_kind = source_kind
	_source_index = source_index
	_charge_elapsed = 0.0
	if _charge_bar != null and _charge_bar.has_method("show_charge"):
		_charge_bar.call("show_charge", CHARGE_BAR_OWNER_ID)
	return true


func update_charge(delta: float) -> void:
	## 按武器上限累计本次蓄力；上限至少 0.01 秒，异常资源不会产生除零或负进度。
	if _charging_weapon == null:
		return
	# 最大蓄力时间；来自当前武器效果配置，达到后保持满蓄力直到松开。
	var maximum_duration: float = maxf(float(_charging_weapon.get("maximum_charge_duration")), 0.01)
	_charge_elapsed = minf(_charge_elapsed + maxf(delta, 0.0), maximum_duration)
	if _charge_bar != null and _charge_bar.has_method("set_charge_ratio"):
		_charge_bar.call("set_charge_ratio", _charge_elapsed / maximum_duration, CHARGE_BAR_OWNER_ID)


func release_charge() -> Dictionary:
	## 结束蓄力并返回释放快照；调用方使用快照执行一次攻击，组件先清理状态以防攻击回调重入。
	if _charging_weapon == null:
		return {}
	# 最大蓄力时间；与累计阶段使用相同下限，保证释放比例可预测。
	var maximum_duration: float = maxf(float(_charging_weapon.get("maximum_charge_duration")), 0.01)
	# 最低蓄力释放语义；按下与松开都发生在相邻物理帧之间时累计时间保持 0，但仍返回完整快照并执行武器基础攻击。
	# 释放结果；保存清理前的武器、通道、时间和比例，比例限制到 0 至 1。
	var release_context: Dictionary = {
		"weapon": _charging_weapon,
		"attack_mode": _attack_mode,
		"source_kind": _source_kind,
		"source_index": _source_index,
		"charge_seconds": _charge_elapsed,
		"charge_ratio": clampf(_charge_elapsed / maximum_duration, 0.0, 1.0),
	}
	_clear_state()
	return release_context


func cancel_charge() -> void:
	## 取消蓄力且不生成攻击；战斗输入关闭、武器失效或角色死亡时使用。
	# 共用蓄力条所有权；武器没有活动蓄力时不得隐藏可能正由主动技能显示的同一节点。
	if _charging_weapon == null:
		return
	_clear_state()


func is_charging() -> bool:
	## 返回当前是否存在活动武器蓄力，供玩家控制器决定是否屏蔽普通连射输入。
	return _charging_weapon != null


func get_charging_weapon() -> Resource:
	## 返回当前蓄力武器引用；仅用于验证武器是否仍装备，调用方不得修改资源字段。
	return _charging_weapon


func get_attack_mode() -> String:
	## 返回本次蓄力开始时的攻击通道；无活动蓄力时为空字符串。
	return _attack_mode


func get_movement_speed_multiplier() -> float:
	## 返回蓄力期间移动倍率；无蓄力固定为 1，资源值限制到 0 至 1。
	return clampf(float(_charging_weapon.get("charge_movement_speed_multiplier")), 0.0, 1.0) if _charging_weapon != null else 1.0


func get_damage_reduction_ratio() -> float:
	## 返回蓄力期间减伤比例；无蓄力固定为 0，资源值限制到 0 至 100%。
	return clampf(float(_charging_weapon.get("charge_damage_reduction_ratio")), 0.0, 1.0) if _charging_weapon != null else 0.0


func _clear_state() -> void:
	## 清空全部运行时状态并隐藏进度条；多次调用保持幂等。
	_charging_weapon = null
	_attack_mode = ""
	_source_kind = ""
	_source_index = -1
	_charge_elapsed = 0.0
	if _charge_bar != null and _charge_bar.has_method("hide_charge"):
		_charge_bar.call("hide_charge", CHARGE_BAR_OWNER_ID)
