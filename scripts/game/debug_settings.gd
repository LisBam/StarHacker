extends Node

## 开发者调试设置统一维护可在运行时切换的调试信息显示状态。
## 任何需要展示开发计算过程的 UI 只读取本服务，避免把调试条件分散到商店、锻造等业务模块。

signal debug_information_visibility_changed(visible: bool)

## 调试设置存档路径；默认写入用户目录，使开发者开关在重启游戏后保持上次选择。
const SAVE_PATH: String = "user://debug_settings.cfg"
## 调试设置配置段名称；固定为 debug，新增开发者可见性字段时应在此段中维护。
const CONFIG_SECTION: String = "debug"
## 调试信息显示配置键；固定保存布尔值，供商店等界面决定是否展示原价倍率。
const DEBUG_INFORMATION_VISIBLE_KEY: String = "information_visible"

## 当前是否显示调试信息；默认 false，正式界面仅显示面向玩家的结果数值。
var _debug_information_visible: bool = false


func _ready() -> void:
	_load_settings()


func is_debug_information_visible() -> bool:
	return _debug_information_visible


func set_debug_information_visible(visible: bool) -> void:
	if _debug_information_visible == visible:
		return
	_debug_information_visible = visible
	_save_settings()
	debug_information_visibility_changed.emit(_debug_information_visible)


func _load_settings() -> void:
	# 调试配置文件；读取失败时保持默认关闭，确保正式 UI 不会意外泄露开发计算信息。
	var config_file: ConfigFile = ConfigFile.new()
	# 配置加载结果；只有成功且存在目标键时才覆盖默认值。
	var load_result: Error = config_file.load(SAVE_PATH)
	if load_result != OK or not config_file.has_section_key(CONFIG_SECTION, DEBUG_INFORMATION_VISIBLE_KEY):
		return
	_debug_information_visible = bool(config_file.get_value(CONFIG_SECTION, DEBUG_INFORMATION_VISIBLE_KEY, false))


func _save_settings() -> void:
	# 调试配置文件；每次开关变化后覆写单个布尔值，不影响输入绑定等其他用户设置。
	var config_file: ConfigFile = ConfigFile.new()
	config_file.set_value(CONFIG_SECTION, DEBUG_INFORMATION_VISIBLE_KEY, _debug_information_visible)
	config_file.save(SAVE_PATH)
