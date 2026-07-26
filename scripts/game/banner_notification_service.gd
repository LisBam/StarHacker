extends CanvasLayer

## 横幅通知服务在屏幕顶端居中展示全局横幅消息，战斗内外与任何界面之上都保持可见。
## 服务同时持有横幅开关设置并独立持久化；业务模块只广播事实信号或调用展示接口，不感知横幅绘制细节。

signal banner_enabled_changed(enabled: bool)

## 横幅画布图层序号；高于场景过渡层的 1000，保证横幅通知拥有全项目最高显示优先级。
const BANNER_CANVAS_LAYER: int = 1200
## 横幅设置文件路径；独立保存以便导出、导入和删除存档时统一处理。
const SAVE_PATH: String = "user://banner_notification_settings.cfg"
## 横幅设置段名称；固定 notification，后续通知偏好可继续在此段扩展。
const CONFIG_SECTION: String = "notification"
## 横幅开关配置键；保存布尔开关，文件缺失或字段非法时默认开启。
const BANNER_ENABLED_KEY: String = "banner_enabled"
## 待展示消息队列上限；默认 6 条，超出后丢弃最旧的待展示消息，防止连续事件刷屏。
const PENDING_QUEUE_LIMIT: int = 6

## 横幅完整展示时长；默认 4 秒，含进入与淡出动画在内的单条总时长，运行时无需动态修改。
@export_range(1.0, 10.0, 0.1) var banner_display_seconds: float = 4.0
## 横幅进入动画时长；默认 0.25 秒，面板从透明淡入到完全可见，运行时无需动态修改。
@export_range(0.05, 1.0, 0.01) var banner_enter_seconds: float = 0.25
## 横幅淡出动画时长；默认 0.5 秒，透明度线性归零后隐藏面板，运行时无需动态修改。
@export_range(0.1, 2.0, 0.05) var banner_fade_seconds: float = 0.5
## 横幅面板宽度；默认 560 像素，顶部居中显示并自动换行长消息，运行时无需动态修改。
@export_range(320.0, 900.0, 1.0) var banner_width: float = 560.0
## 横幅顶部偏移；默认 12 像素，避开窗口边缘同时保证第一时间可见，运行时无需动态修改。
@export_range(0.0, 120.0, 1.0) var banner_top_offset: float = 12.0

## 横幅是否启用；默认 true，设置页关闭后当前横幅立即中断且新消息直接丢弃。
var _banner_enabled: bool = true
## 横幅面板容器；默认运行时创建并隐藏，展示时淡入、停留后淡出。
var _banner_panel: PanelContainer
## 横幅文本标签；默认运行时创建，展示单条通知消息文本。
var _banner_label: Label
## 横幅动画补间；单条播放周期内持有，关闭开关或播放下一条时统一清理。
var _banner_tween: Tween
## 待展示消息队列；元素为字符串，当前横幅播放完成后按先进先出顺序继续展示。
var _pending_messages: Array[String] = []
## 当前是否正在展示横幅；默认 false，用于决定新消息直接播放还是进入待展示队列。
var _banner_active: bool = false


func _ready() -> void:
	layer = BANNER_CANVAS_LAYER
	# 暂停豁免；战斗暂停或结算窗口打开时横幅仍要正常播放动画。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_banner_interface()
	_connect_business_signals()


func is_banner_enabled() -> bool:
	## 返回横幅通知是否启用；设置开关组件与业务调用方共用该状态。
	return _banner_enabled


func set_banner_enabled(enabled: bool) -> void:
	## 校验、保存并立即应用横幅开关；关闭时中断当前横幅并清空待展示队列，相同值不会重复写盘或广播。
	if _banner_enabled == enabled:
		return
	_banner_enabled = enabled
	_save_settings()
	if not enabled:
		if _banner_tween != null and _banner_tween.is_valid():
			_banner_tween.kill()
		_pending_messages.clear()
		_banner_active = false
		if _banner_panel != null:
			_banner_panel.visible = false
	banner_enabled_changed.emit(_banner_enabled)


func show_banner(message: String) -> void:
	## 展示或排队一条横幅消息；设置关闭时直接丢弃，正在展示时按先进先出进入待展示队列。
	if not _banner_enabled or message.is_empty() or _banner_panel == null:
		return
	if _banner_active:
		_pending_messages.append(message)
		while _pending_messages.size() > PENDING_QUEUE_LIMIT:
			_pending_messages.pop_front()
		return
	_play_banner(message)


func _connect_business_signals() -> void:
	## 订阅需要横幅提醒的业务信号；业务服务只负责广播事实，不反向依赖横幅服务。
	# 股市服务；强制平仓信号触发最高优先级横幅提醒。
	var stock_market_service: Node = get_tree().root.get_node_or_null("StockMarketService")
	if stock_market_service != null and stock_market_service.has_signal("leverage_position_liquidated"):
		stock_market_service.connect("leverage_position_liquidated", Callable(self, "_on_leverage_position_liquidated"))
	# 保险服务；死亡理赔到账时提醒玩家赔付金额，避免结算界面之外错过入账。
	var insurance_service: Node = get_tree().root.get_node_or_null("InsuranceService")
	if insurance_service != null and insurance_service.has_signal("claim_paid"):
		insurance_service.connect("claim_paid", Callable(self, "_on_insurance_claim_paid"))
	# 银行服务；定期存单到期与贷款自动结算都可能发生在玩家没有打开银行面板时。
	var bank_service: Node = get_tree().root.get_node_or_null("BankService")
	if bank_service != null and bank_service.has_signal("deposit_matured"):
		bank_service.connect("deposit_matured", Callable(self, "_on_bank_deposit_matured"))
	if bank_service != null and bank_service.has_signal("loan_auto_settled"):
		bank_service.connect("loan_auto_settled", Callable(self, "_on_bank_loan_auto_settled"))
	# 派遣服务；委托到期自动交付时提醒玩家角色归队与报酬入账。
	var dispatch_service: Node = get_tree().root.get_node_or_null("DispatchService")
	if dispatch_service != null and dispatch_service.has_signal("dispatch_completed"):
		dispatch_service.connect("dispatch_completed", Callable(self, "_on_dispatch_completed"))
	# 据点服务；设施建成时提醒玩家新等级效果已经生效。
	var hideout_service: Node = get_tree().root.get_node_or_null("HideoutService")
	if hideout_service != null and hideout_service.has_signal("construction_completed"):
		hideout_service.connect("construction_completed", Callable(self, "_on_hideout_construction_completed"))


func _on_leverage_position_liquidated(_stock_id: String, message: String) -> void:
	## 强平回调；把结算说明转成顶部横幅，固定前缀让玩家在任何场景都能第一时间识别风险来源。
	show_banner("【强平通知】%s" % message)


func _on_insurance_claim_paid(_gold_amount: int, message: String) -> void:
	## 保险理赔回调；死亡赔付到账时用固定前缀提示，与死亡结算界面互不依赖。
	show_banner("【保险理赔】%s" % message)


func _on_bank_deposit_matured(_gold_amount: int, message: String) -> void:
	## 定期到期回调；本息自动到账时提示，玩家无需守在银行面板等待兑付。
	show_banner("【银行通知】%s" % message)


func _on_bank_loan_auto_settled(message: String, defaulted: bool) -> void:
	## 贷款自动结算回调；违约使用更醒目的前缀区分正常扣款与信用违约。
	show_banner("【信用违约】%s" % message if defaulted else "【银行通知】%s" % message)


func _on_dispatch_completed(_gold_amount: int, message: String) -> void:
	## 派遣完成回调；委托交付与角色归队合并为一条横幅提示。
	show_banner("【派遣归来】%s" % message)


func _on_hideout_construction_completed(facility_id: String, new_level: int) -> void:
	## 据点建成回调；提示设施新等级已生效，具体效果在据点面板查看。
	# 据点服务；从服务定义中读取设施显示名，保持文案与面板一致。
	var hideout_service: Node = get_tree().root.get_node_or_null("HideoutService")
	# 建成设施显示名；服务缺失时使用通用文案兜底。
	var facility_name: String = "据点设施"
	if hideout_service != null and hideout_service.has_method("get_facility_definitions"):
		for definition in hideout_service.call("get_facility_definitions") as Array:
			if str((definition as Dictionary).get("id", "")) == facility_id:
				facility_name = str((definition as Dictionary).get("name", "据点设施"))
				break
	show_banner("【据点建成】%s 已升级到 Lv.%d，新效果立即生效" % [facility_name, new_level])


func _play_banner(message: String) -> void:
	## 播放单条横幅完整周期；淡入、停留、淡出结束后自动播放队列中的下一条。
	_banner_active = true
	_banner_label.text = message
	_banner_panel.visible = true
	_banner_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_panel, "modulate:a", 1.0, maxf(banner_enter_seconds, 0.05))
	# 稳定停留时长；总展示时长扣除进入与淡出动画后至少保留 0.5 秒完全可读时间。
	_banner_tween.tween_interval(maxf(banner_display_seconds - banner_enter_seconds - banner_fade_seconds, 0.5))
	_banner_tween.tween_property(_banner_panel, "modulate:a", 0.0, maxf(banner_fade_seconds, 0.1))
	_banner_tween.tween_callback(_on_banner_finished)


func _on_banner_finished() -> void:
	## 单条横幅播放结束；隐藏面板并按先进先出继续播放队列中的下一条待展示消息。
	_banner_panel.visible = false
	_banner_active = false
	if _pending_messages.is_empty():
		return
	# 下一条待展示消息；先进先出保证通知顺序与事件发生顺序一致。
	var next_message: String = _pending_messages.pop_front()
	_play_banner(next_message)


func _build_banner_interface() -> void:
	## 创建顶部居中的横幅面板；面板不拦截鼠标，位于任何场景与弹窗之上只做只读提示。
	_banner_panel = PanelContainer.new()
	_banner_panel.name = "BannerPanel"
	_banner_panel.visible = false
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 顶部居中锚点；水平锚定屏幕中线，按配置宽度左右对称展开。
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_right = 0.5
	_banner_panel.offset_left = -banner_width * 0.5
	_banner_panel.offset_right = banner_width * 0.5
	_banner_panel.offset_top = banner_top_offset
	# 横幅面板样式；深色底加警示琥珀描边，独立于换肤主题保证任何 UI 风格下都醒目可读。
	var banner_style: StyleBoxFlat = StyleBoxFlat.new()
	banner_style.bg_color = Color(0.06, 0.08, 0.10, 0.92)
	banner_style.border_color = Color(1.0, 0.80, 0.30, 1.0)
	banner_style.set_border_width_all(1)
	banner_style.set_corner_radius_all(6)
	banner_style.content_margin_left = 18.0
	banner_style.content_margin_right = 18.0
	banner_style.content_margin_top = 10.0
	banner_style.content_margin_bottom = 10.0
	_banner_panel.add_theme_stylebox_override("panel", banner_style)
	add_child(_banner_panel)
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.add_theme_font_size_override("font_size", 16)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.44, 1.0))
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.add_child(_banner_label)


func _load_settings() -> void:
	## 读取横幅开关配置；文件缺失、损坏或字段非法时保持默认开启，不创建额外文件。
	# 配置文件；只读取本服务拥有的固定路径，不解析其他模块设置。
	var config_file: ConfigFile = ConfigFile.new()
	# 加载结果；非 OK 表示首次启动或文件不可读，保持默认开启。
	var load_result: Error = config_file.load(SAVE_PATH)
	if load_result != OK or not config_file.has_section_key(CONFIG_SECTION, BANNER_ENABLED_KEY):
		return
	_banner_enabled = bool(config_file.get_value(CONFIG_SECTION, BANNER_ENABLED_KEY, true))


func _save_settings() -> void:
	## 覆写当前横幅开关配置；文件只包含稳定布尔值，不保存控件实例或临时消息队列。
	# 配置文件；每次切换重新创建，避免遗留未知字段影响当前结构。
	var config_file: ConfigFile = ConfigFile.new()
	config_file.set_value(CONFIG_SECTION, BANNER_ENABLED_KEY, _banner_enabled)
	# 保存结果；写入失败不会撤销内存中的即时切换，但会输出错误供开发者定位权限或磁盘问题。
	var save_result: Error = config_file.save(SAVE_PATH)
	if save_result != OK:
		push_error("保存横幅通知设置失败，错误码：%d" % save_result)
