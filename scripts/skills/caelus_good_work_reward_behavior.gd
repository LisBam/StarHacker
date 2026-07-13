extends Node

## 好活当赏统计 6 秒内实际受伤次数；窗口内未使用武器且累计 6 次时，为穹提供一次永久至消耗的护盾。

## 当前施法者；默认 null，用于监听受伤与武器使用并访问护盾组件。
var _caster: Node2D
## 当前战斗属性组件；默认 null，用于读取最终防御力。
var _stats_component: Node
## 当前技能资源；默认 null，保存窗口、次数、冷却和护盾公式。
var _skill_data: Resource
## 当前统计窗口剩余时间；默认 0 表示尚未开始或已经失效。
var _window_remaining: float = 0.0
## 当前触发冷却剩余时间；默认 0，正值期间忽略受伤统计。
var _cooldown_remaining: float = 0.0
## 当前窗口累计实际受伤次数；默认 0。
var _hit_count: int = 0
## 当前窗口是否使用过武器；默认 false，任何成功武器攻击都会使本窗口无法触发。
var _weapon_used_in_window: bool = false


func _ready() -> void:
	set_process(true)


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, _passive_skill_component: Node) -> void:
	## 注入依赖并连接玩家实际受伤与成功武器攻击信号。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	if is_instance_valid(_caster):
		_caster.connect("damage_received", Callable(self, "_on_damage_received"))
		_caster.connect("weapon_attack_succeeded", Callable(self, "_on_weapon_attack_succeeded"))


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - maxf(delta, 0.0), 0.0)
	if _window_remaining <= 0.0:
		return
	_window_remaining = maxf(_window_remaining - maxf(delta, 0.0), 0.0)
	if _window_remaining <= 0.0:
		_reset_window()


func _on_damage_received(_damage: float, _source: Node) -> void:
	## 冷却外首次受伤开启窗口，后续受伤累计；达到次数时立即判断本窗口是否使用武器。
	if _skill_data == null or _cooldown_remaining > 0.0:
		return
	if _window_remaining <= 0.0:
		_window_remaining = maxf(float(_skill_data.get("tracking_window")), 0.01)
		_hit_count = 0
		_weapon_used_in_window = false
	_hit_count += 1
	if _hit_count < maxi(int(_skill_data.get("required_hit_count")), 1):
		return
	if not _weapon_used_in_window:
		_grant_shield()
		_cooldown_remaining = maxf(float(_skill_data.get("trigger_cooldown")), 0.0)
	_reset_window()


func _on_weapon_attack_succeeded(_kind: String, _index: int, _weapon: Resource) -> void:
	## 只有正在统计的 6 秒窗口记录武器使用；窗口外攻击不会预先污染下一次统计。
	if _window_remaining > 0.0:
		_weapon_used_in_window = true


func _grant_shield() -> void:
	## 按 `66 + 6%最终防御力` 增加可持续至被伤害消耗的护盾。
	var shield_component: Node = _caster.call("get_shield_component") if is_instance_valid(_caster) and _caster.has_method("get_shield_component") else null
	if shield_component == null or not shield_component.has_method("add_shield"):
		return
	var defense_power: float = float(_stats_component.call("get_defense_power")) if _stats_component != null and _stats_component.has_method("get_defense_power") else 0.0
	var shield_amount: float = maxf(float(_skill_data.get("base_shield_amount")), 0.0) + defense_power * maxf(float(_skill_data.get("defense_power_ratio")), 0.0)
	shield_component.call("add_shield", shield_amount, true)


func _reset_window() -> void:
	## 清空一次统计窗口；触发冷却由独立计时保留。
	_window_remaining = 0.0
	_hit_count = 0
	_weapon_used_in_window = false


func shutdown() -> void:
	## 角色切换时断开信号并清空未完成窗口。
	if is_instance_valid(_caster):
		if _caster.is_connected("damage_received", Callable(self, "_on_damage_received")):
			_caster.disconnect("damage_received", Callable(self, "_on_damage_received"))
		if _caster.is_connected("weapon_attack_succeeded", Callable(self, "_on_weapon_attack_succeeded")):
			_caster.disconnect("weapon_attack_succeeded", Callable(self, "_on_weapon_attack_succeeded"))
	_reset_window()
