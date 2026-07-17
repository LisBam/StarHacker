extends Node
class_name ProgressiveItemLoader

## 长物品列表渐进加载器先同步创建首批卡片，再按帧分批补齐剩余内容。
## 宿主负责提供条目快照和单项创建回调；刷新、筛选或关闭界面时调用 cancel() 即可使旧任务安全失效。

## 当前加载代数；每次开始或取消任务都会增加，旧协程发现代数变化后立即停止。
var _generation: int = 0


func start(entries: Array, create_callback: Callable, initial_count: int, batch_count: int) -> void:
	## 启动一次渐进加载；首批在当前调用栈内完成，剩余条目从下一帧开始分批创建。
	_generation += 1
	# 本次加载代数；用于后续异步批次识别刷新后已经失效的旧任务。
	var generation: int = _generation
	# 稳定条目快照；浅复制数组以隔离调用方后续清空或重新排序，条目字典仍保持只读引用。
	var entry_snapshot: Array = entries.duplicate(false)
	# 首批数量；至少为 1，确保打开界面时立即出现可见内容。
	var resolved_initial_count: int = maxi(initial_count, 1)
	# 每帧批量；至少为 1，数值越大加载完成越快但单帧创建成本越高。
	var resolved_batch_count: int = maxi(batch_count, 1)
	# 当前同步创建上限；不能超过实际条目数量。
	var immediate_end: int = mini(resolved_initial_count, entry_snapshot.size())
	for entry_index in range(immediate_end):
		create_callback.call(entry_snapshot[entry_index], entry_index)
	if immediate_end < entry_snapshot.size():
		_continue_loading(entry_snapshot, create_callback, immediate_end, resolved_batch_count, generation)


func cancel() -> void:
	## 取消尚未完成的异步批次；已经显示的控件由宿主按自身复用或清理协议处理。
	_generation += 1


func _continue_loading(entries: Array, create_callback: Callable, start_index: int, batch_count: int, generation: int) -> void:
	## 从下一帧开始加载剩余条目；每批结束后主动让出主线程，保证滚动、按钮和动画保持响应。
	var entry_index: int = start_index
	while entry_index < entries.size():
		await Engine.get_main_loop().process_frame
		if generation != _generation or not is_inside_tree():
			return
		# 当前批次结束下标；使用半开区间，最后一批自动收缩到实际条目数量。
		var batch_end: int = mini(entry_index + batch_count, entries.size())
		while entry_index < batch_end:
			create_callback.call(entries[entry_index], entry_index)
			entry_index += 1
