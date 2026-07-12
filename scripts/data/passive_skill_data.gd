extends Resource
class_name PassiveSkillData

## 被动技能数据资源描述一个角色进入战斗后需要实例化的独立行为节点。
## PassiveSkillComponent 可以同时挂载任意数量的资源，每个行为节点独立维护自己的连接、计时与清理状态。

## 技能稳定标识；必须在同一角色的被动技能数组中唯一，默认空字符串表示配置无效，发布后修改会影响行为状态来源。
@export var skill_id: String = ""
## 技能显示名称；默认“未命名被动技能”，用于角色详情和长期维护识别，运行时不应动态修改模板。
@export var display_name: String = "未命名被动技能"
## 技能完整说明；默认空字符串，应记录触发条件、效果和上限，角色详情会直接显示该文本。
@export_multiline var description: String = ""
## 技能行为脚本；必须能够创建 Node，并实现 configure(caster, stats, skill_data, component)，停用时可选实现 shutdown()。
@export var behavior_script: Script


func is_valid_configuration() -> bool:
	## 只有稳定 ID 和可实例化行为脚本都存在时才允许创建被动实例，避免空资源残留无职责节点。
	return not skill_id.strip_edges().is_empty() and behavior_script != null
