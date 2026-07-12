extends Resource
class_name ContentPackData

## 内容扩展包数据资源集中声明一个角色解锁后可进入全局内容池的武器、装备、道具与怪物。
## 清单只负责内容归属，不保存玩家解锁进度；解锁状态由 SessionState 统一持久化和查询。

## 扩展包稳定标识；必须使用唯一英文 ID，默认空字符串表示配置无效，发布后修改会影响角色与内容的归属关系。
@export var pack_id: String = ""
## 扩展包显示名称；默认“未命名扩展包”，用于调试信息与后续扩展包管理界面，运行时通常不动态修改。
@export var display_name: String = "未命名扩展包"
## 所属角色稳定标识；角色被解锁时同步解锁本清单，默认空字符串表示没有合法解锁来源。
@export var character_id: String = ""
## 扩展包武器模板；每项必须来自武器自动扫描目录，解锁后进入商店、掉落、宝箱与开发者发放池。
@export var weapon_resources: Array[Resource] = []
## 扩展包装备模板；每项必须来自装备自动扫描目录，解锁后进入商店、掉落、宝箱与开发者发放池。
@export var equipment_resources: Array[Resource] = []
## 扩展包道具模板；每项必须来自道具自动扫描目录，解锁后进入商店、掉落、宝箱与开发者发放池。
@export var item_resources: Array[Resource] = []
## 扩展包怪物场景；每项必须来自怪物自动扫描目录，解锁后进入正式战斗与训练场随机生成池。
@export var enemy_scenes: Array[PackedScene] = []


func get_weapon_paths() -> PackedStringArray:
	## 返回武器模板路径副本；空资源与未保存资源不会进入归属表。
	return _collect_resource_paths(weapon_resources)


func get_equipment_paths() -> PackedStringArray:
	## 返回装备模板路径副本；ContentCatalog 使用路径与自动扫描结果建立稳定归属。
	return _collect_resource_paths(equipment_resources)


func get_item_paths() -> PackedStringArray:
	## 返回道具模板路径副本；同一路径只会由排序靠前的合法扩展包取得归属权。
	return _collect_resource_paths(item_resources)


func get_enemy_scene_paths() -> PackedStringArray:
	## 返回怪物场景路径副本；场景仍由 GameWorld 在实际生成时实例化。
	# 怪物资源数组；PackedScene 继承 Resource，可复用通用路径收集逻辑且不复制场景内容。
	var enemy_resources: Array[Resource] = []
	# 怪物场景遍历项；空场景会由通用收集逻辑忽略。
	for enemy_scene in enemy_scenes:
		enemy_resources.append(enemy_scene)
	return _collect_resource_paths(enemy_resources)


func get_all_content_paths() -> PackedStringArray:
	## 返回扩展包四类内容的去重路径，供目录服务建立统一过滤索引。
	# 全部内容路径；按武器、装备、道具、怪物顺序追加，便于维护时稳定追踪清单来源。
	var content_paths: PackedStringArray = PackedStringArray()
	# 分类路径数组；每类已经过滤空路径，合并时再次去重以容忍误配置。
	for category_paths in [get_weapon_paths(), get_equipment_paths(), get_item_paths(), get_enemy_scene_paths()]:
		# 分类内容路径；只有尚未登记的路径才追加到最终清单。
		for content_path in category_paths:
			if not content_paths.has(content_path):
				content_paths.append(content_path)
	return content_paths


func _collect_resource_paths(resources: Array[Resource]) -> PackedStringArray:
	## 把已保存资源转换为稳定路径；运行时临时资源没有 resource_path，因此不会形成不可恢复的扩展包条目。
	# 资源路径结果；保持检查器清单顺序并移除重复项。
	var resource_paths: PackedStringArray = PackedStringArray()
	# 内容资源遍历项；类型已经由对应导出数组限制，仍允许空槽以便检查器编辑。
	for content_resource in resources:
		if content_resource == null:
			continue
		# 内容资源路径；必须非空且未出现，才能作为目录归属键使用。
		var content_path: String = content_resource.resource_path.strip_edges()
		if not content_path.is_empty() and not resource_paths.has(content_path):
			resource_paths.append(content_path)
	return resource_paths
