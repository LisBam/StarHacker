extends Node

## 二倍速行为只管理一次限时效果的强度、受击衰减、能量消费统计和无伤完成奖励。

## 玩家攻速来源 ID；固定值保证重复配置只覆盖本技能且结束时不会移除其他攻速来源。
const ATTACK_SPEED_SOURCE_ID: String = "silver_wolf_double_speed"
## 玩家固定移速来源 ID；与攻速来源分离，使两个属性可通过各自公开接口独立清理。
const MOVE_SPEED_SOURCE_ID: String = "silver_wolf_double_speed"
## 世界飘字脚本；无伤完成时用于生成绿色 COMBO! 反馈。
const FLOATING_TEXT_POPUP_SCRIPT: Script = preload("res://scripts/effects/floating_text_popup.gd")
## 持续头顶状态文本脚本；二倍速生效期间用它显示跟随银狼的固定 2× 标记。
const OVERHEAD_STATUS_TEXT_SCRIPT: Script = preload("res://scripts/effects/overhead_status_text.gd")
## 二倍速头顶状态文字；固定使用 2×，只在本技能持续期间显示。
const DOUBLE_SPEED_STATUS_TEXT: String = "2×"
## 二倍速头顶状态颜色；青蓝色与银狼技能的数码视觉保持一致，不参与任何数值或伤害结算。
const DOUBLE_SPEED_STATUS_COLOR: Color = Color(0.38, 0.88, 1.0, 1.0)
## 二倍速头顶状态偏移；向上 52 像素与角色模型保持间距，避免遮挡脚下攻击或受击反馈。
const DOUBLE_SPEED_STATUS_OFFSET: Vector2 = Vector2(0.0, -52.0)

## 当前施法者；默认 null，由主动技能组件注入并提供攻速、移速和受击信号接口。
var _caster: Node2D
## 当前战斗属性组件；默认 null，用于监听真实能量消费并在无伤完成时返还。
var _stats_component: Node
## 当前技能数据；默认 null，保存全部可调持续时间、增益与衰减数值。
var _skill_data: Resource
## 主动技能组件；默认 null，用于效果结束时缩放本槽剩余冷却。
var _active_skill_component: Node
## 本次技能槽下标；默认 -1，释放成功时从上下文记录供无伤奖励定位冷却。
var _slot_index: int = -1
## 当前效果剩余时间；取值大于等于 0，默认 0 表示技能未激活。
var _remaining_duration: float = 0.0
## 当前效果强度比例；默认 0，释放后为 1，每次受击按配置从初始强度线性扣减。
var _effect_strength: float = 0.0
## 本次效果期间是否实际受击；默认 false，任何一次未闪避攻击都会永久取消本次无伤奖励。
var _was_hit: bool = false
## 本次效果期间实际消费能量总量；默认 0，由 energy_spent 信号累计，不受自然能量恢复影响。
var _energy_spent_during_effect: float = 0.0
## 二倍速头顶状态节点；默认 null，效果开始时创建并在任何结束路径回收，独立于短时飘字生命周期。
var _overhead_status_text: Node2D


func _ready() -> void:
	set_process(false)


func configure(caster: Node2D, stats_component: Node, skill_data: Resource, active_skill_component: Node) -> void:
	## 注入行为依赖并连接长期信号；角色切换时 shutdown 会完整断开。
	_caster = caster
	_stats_component = stats_component
	_skill_data = skill_data
	_active_skill_component = active_skill_component
	if is_instance_valid(_caster) and _caster.has_signal("damage_received"):
		_caster.connect("damage_received", Callable(self, "_on_damage_received"))
	if _stats_component != null and _stats_component.has_signal("energy_spent"):
		_stats_component.connect("energy_spent", Callable(self, "_on_energy_spent"))


func execute(context: Dictionary) -> bool:
	## 启动完整强度的二倍速；技能冷却和释放成本继续由主动技能组件统一结算。
	if not is_instance_valid(_caster) or _skill_data == null or not _caster.has_method("set_attack_speed_bonus_source") or not _caster.has_method("set_movement_speed_attribute_bonus_source"):
		return false
	_slot_index = int(context.get("slot_index", -1))
	_remaining_duration = maxf(float(_skill_data.get("effect_duration")), 0.01)
	_effect_strength = 1.0
	_was_hit = false
	_energy_spent_during_effect = 0.0
	_apply_current_strength()
	_show_overhead_status_text()
	set_process(true)
	return true


func _process(delta: float) -> void:
	if _remaining_duration <= 0.0:
		_finish_effect(true)
		return
	_remaining_duration = maxf(_remaining_duration - maxf(delta, 0.0), 0.0)
	if _remaining_duration <= 0.0:
		_finish_effect(true)


func _on_damage_received(_final_damage: float, _source: Node) -> void:
	## 实际受击缩短当前持续时间并线性降低两个增益；技能未激活时忽略信号。
	if _remaining_duration <= 0.0 or _skill_data == null:
		return
	_was_hit = true
	_remaining_duration = maxf(_remaining_duration - maxf(float(_skill_data.get("duration_loss_per_hit")), 0.0), 0.0)
	_effect_strength = maxf(_effect_strength - clampf(float(_skill_data.get("effect_loss_ratio_per_hit")), 0.0, 1.0), 0.0)
	_apply_current_strength()
	if _remaining_duration <= 0.0:
		_finish_effect(true)


func _on_energy_spent(amount: float) -> void:
	## 累计效果激活期间的真实正数消费；退款不会触发 energy_spent，因此不会形成递归统计。
	if _remaining_duration > 0.0:
		_energy_spent_during_effect += maxf(amount, 0.0)


func _apply_current_strength() -> void:
	## 把当前线性强度同步到玩家两个独立来源；强度为零仍保留来源到持续时间结束，数值效果为零。
	if not is_instance_valid(_caster) or _skill_data == null:
		return
	_caster.call("set_attack_speed_bonus_source", ATTACK_SPEED_SOURCE_ID, maxf(float(_skill_data.get("attack_speed_bonus_ratio")), 0.0) * _effect_strength)
	_caster.call("set_movement_speed_attribute_bonus_source", MOVE_SPEED_SOURCE_ID, maxf(float(_skill_data.get("move_speed_attribute_bonus")), 0.0) * _effect_strength)


func _finish_effect(allow_no_hit_reward: bool) -> void:
	## 清理两个临时来源；仅自然计时或受击缩短结束且全程无伤时发放退款、冷却缩减和头顶反馈。
	if _remaining_duration <= 0.0 and not is_processing():
		return
	_remaining_duration = 0.0
	set_process(false)
	_clear_overhead_status_text()
	if is_instance_valid(_caster):
		if _caster.has_method("remove_attack_speed_bonus_source"):
			_caster.call("remove_attack_speed_bonus_source", ATTACK_SPEED_SOURCE_ID)
		if _caster.has_method("remove_movement_speed_attribute_bonus_source"):
			_caster.call("remove_movement_speed_attribute_bonus_source", MOVE_SPEED_SOURCE_ID)
	if not allow_no_hit_reward or _was_hit:
		return
	if _stats_component != null and _stats_component.has_method("set_energy"):
		_stats_component.call("set_energy", float(_stats_component.get("current_energy")) + _energy_spent_during_effect)
	if _active_skill_component != null and _active_skill_component.has_method("scale_cooldown_remaining") and _slot_index >= 0:
		_active_skill_component.call("scale_cooldown_remaining", _slot_index, 1.0 - clampf(float(_skill_data.get("no_hit_cooldown_reduction_ratio")), 0.0, 1.0))
	if is_instance_valid(_caster):
		# 飘字父节点；优先当前场景，使反馈脱离行为节点生命周期完成播放。
		var effect_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		FLOATING_TEXT_POPUP_SCRIPT.spawn_text(effect_parent, _caster.global_position, str(_skill_data.get("no_hit_feedback_text")), _skill_data.get("no_hit_feedback_color") as Color)


func _show_overhead_status_text() -> void:
	## 创建或刷新二倍速期间的头顶 2× 标记；标记挂到当前场景，避免技能行为节点重建时错失世界坐标绘制。
	_clear_overhead_status_text()
	if not is_instance_valid(_caster):
		return
	# 世界特效父节点；优先当前场景，缺失时回退根节点，使独立测试场景也可显示状态文本。
	var effect_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	# 二倍速状态文本；脚本实例化失败时只缺少视觉反馈，不影响攻速、移速或无伤奖励结算。
	var status_text: Node2D = OVERHEAD_STATUS_TEXT_SCRIPT.new() as Node2D
	if effect_parent == null or status_text == null:
		return
	effect_parent.add_child(status_text)
	status_text.call("configure", _caster, DOUBLE_SPEED_STATUS_TEXT, DOUBLE_SPEED_STATUS_COLOR, DOUBLE_SPEED_STATUS_OFFSET)
	_overhead_status_text = status_text


func _clear_overhead_status_text() -> void:
	## 回收当前二倍速头顶标记；节点已被场景自动销毁时只清空引用，不会影响其他技能的独立标记。
	if is_instance_valid(_overhead_status_text):
		if _overhead_status_text.has_method("dispose"):
			_overhead_status_text.call("dispose")
		else:
			_overhead_status_text.queue_free()
	_overhead_status_text = null


func shutdown() -> void:
	## 角色切换或技能重配时停止效果且不发放完成奖励，并断开全部外部信号。
	_finish_effect(false)
	if is_instance_valid(_caster) and _caster.has_signal("damage_received") and _caster.is_connected("damage_received", Callable(self, "_on_damage_received")):
		_caster.disconnect("damage_received", Callable(self, "_on_damage_received"))
	if _stats_component != null and _stats_component.has_signal("energy_spent") and _stats_component.is_connected("energy_spent", Callable(self, "_on_energy_spent")):
		_stats_component.disconnect("energy_spent", Callable(self, "_on_energy_spent"))
