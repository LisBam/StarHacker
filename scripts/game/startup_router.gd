extends Node

## 启动路由在任何可见页面出现前决定进入首次战斗引导或常规主菜单。
## 它只负责一次场景选择，不参与战斗规则、库存结算或永久进度写入。

## 常规主菜单场景路径；首次引导已完成或保护服务缺失时使用。
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
## 首次战斗新手引导场景路径；新档第一次启动时直接进入，不显示主菜单中间帧。
@export_file("*.tscn") var tutorial_combat_scene_path: String = "res://scenes/game/game_world.tscn"


func _ready() -> void:
	## 延迟到当前启动场景完成 ready 后切换，避免在场景树初始化回调中同步替换根节点。
	call_deferred("_route_startup_scene")


func _route_startup_scene() -> void:
	## 读取新手保护服务的唯一引导资格并执行场景切换；服务缺失时安全回退常规主菜单。
	# 新手保护服务；同时拥有一次性引导永久状态与本次会话配置入口。
	var newcomer_protection_service: Node = get_tree().root.get_node_or_null("NewcomerProtectionService")
	# 是否启动首次引导；必须同时具备查询与开始接口，防止部分旧服务版本误切战斗。
	var should_start_tutorial: bool = newcomer_protection_service != null and newcomer_protection_service.has_method("should_start_first_run_tutorial") and newcomer_protection_service.has_method("begin_first_run_tutorial") and bool(newcomer_protection_service.call("should_start_first_run_tutorial"))
	if should_start_tutorial:
		newcomer_protection_service.call("begin_first_run_tutorial")
		get_tree().change_scene_to_file(tutorial_combat_scene_path)
		return
	get_tree().change_scene_to_file(main_menu_scene_path)
