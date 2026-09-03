extends RefCounted
## event_loader.gd —— 事件 JSON 加载器（E5-S2，架构 A7 第 2 层·行为在数据侧）
##
## 【为什么存在】拍板项④与 E4 各硬编码模板（chest/investigate/trigger_teleport）
##   的共同回迁目标：E5-S2 起，"哪个 id 触发什么动作序列"的答案不在代码里，
##   在 data/json/events/*.json（GDD §3.2 schema）。本类是 JSON → 运行时事件表
##   的唯一入口；schema 校验（白名单/引用完整性/结构）在 schema_validator.gd，
##   评估/执行在 event_executor.gd——三层各管一段，同 dialogue 侧
##   （校验器 / runner / box）分界同构。
##
## 【加载范围】启动期或按需调 load_all()：扫描 data/json/events/ 下全部 .json，
##   逐文件经 SchemaValidator.load_events_file（顶层无 "events" 键的文件——
##   E4 的 chests/investigates/teleports 三份点位镜像——被校验器跳过并打日志，
##   不计入加载失败）。加载结果：event_id → 事件字典 的总表 + phase 映射总表。
##
## 【为什么是 RefCounted 而非 Autoload】架构 A3 只批 4 个单例；事件表由
##   使用方（E5-S3 executor / NPC 交互接线）按需实例化持有——纯数据缓存，
##   无跨场景生命周期诉求（同 DataTables static/RefCounted 取舍理由）。
##
## 【缓存与刷新】同一次进程内重复 load_all 以最后一次为准（JSON 热改重启
##   生效——切片无热重载诉求，GDD §1"改 JSON 不改码"指改数据不改码本体的
##   交付形态）。文件不存在时返回空表（不 crash；调用方防御）。

## 事件 JSON 根目录（GDD §3.2：data/json/events/）
const EVENTS_DIR: String = "res://data/json/events/"

## schema 校验器（E5-S2 抽离复用版；正本在 scripts/dialogue，自 runner 抽离——
## events 侧跨域引用对话域校验器，依赖方向 events → dialogue）
const SchemaValidator := preload("res://scripts/dialogue/schema_validator.gd")


## 事件表：event_id → 事件字典（load_all 后可查）
var events: Dictionary = {}

## phase 映射总表：event_id → {动作序号: {int phase: 对话 id}}（E5-S3 消费）
var phase_maps: Dictionary = {}

## 事件文件名（不含扩展名）→ 原始路径（触发器定位调试用）
var loaded_files: Array[String] = []


## 全量加载：扫描 EVENTS_DIR 全部 .json，逐文件校验入表。
## 任一文件校验失败 = 整份拒绝（该文件零入表），失败文件计入返回值。
## 返回失败文件名数组（空 = 全绿）。
func load_all() -> Array[String]:
	var failed: Array[String] = []
	events.clear()
	phase_maps.clear()
	loaded_files.clear()
	var dir: DirAccess = DirAccess.open(EVENTS_DIR)
	if dir == null:
		print("[EventLoader] 事件目录不存在：%s" % EVENTS_DIR)
		return failed
	for file: String in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var path: String = EVENTS_DIR + file
		var result: Dictionary = SchemaValidator.load_events_file(path)
		if result.is_empty():
			# 校验器拒绝（schema 非法/悬空引用等）：整份不入表，计失败
			failed.append(file)
			continue
		if result.has("skipped"):
			# 非事件 schema 文件（E4 点位镜像，顶层无 events 键）：跳过不计失败
			continue
		var file_events: Dictionary = result["events"]
		for eid: Variant in file_events.keys():
			events[String(eid)] = file_events[eid]
		var file_pm: Dictionary = result["phase_maps"]
		for eid2: Variant in file_pm.keys():
			phase_maps[String(eid2)] = file_pm[eid2]
		loaded_files.append(file)
	print("[EventLoader] 加载完成：%d 文件 / %d 事件（失败 %d）" % [
			loaded_files.size(), events.size(), failed.size()])
	return failed


## 按 id 查事件（未加载或未知 id 返回空字典——调用方按"无此事件"处置）
func get_event(p_event_id: String) -> Dictionary:
	var ev: Variant = events.get(p_event_id)
	if typeof(ev) != TYPE_DICTIONARY:
		return {}
	return ev


## 按 id 查 phase 映射（无映射返回空字典）
func get_phase_map(p_event_id: String) -> Dictionary:
	var pm: Variant = phase_maps.get(p_event_id)
	if typeof(pm) != TYPE_DICTIONARY:
		return {}
	return pm


## 事件 id 是否已登记（触发器接线时的存在性快查）
func has_event(p_event_id: String) -> bool:
	return events.has(p_event_id)


## 重置（测试隔离用：清空三张表，不影响磁盘数据）
func reset() -> void:
	events.clear()
	phase_maps.clear()
	loaded_files.clear()
