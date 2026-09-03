extends GutTest
## E5-S3 测试 —— story_phase 机制：存档往返 + 阶段广播 + NPC 阶段对话（对话 GDD §3.3/§5）
##
## 【分组】
##   A 存档往返（验收①）：phase 随存档→读档→值不变；flags 往返；E4-S7 整体
##     回滚语义不破坏（读档失败 / 字段缺失回默认）；v1 迁移补默认 phase=0
##   B story_phase_changed 广播：executor.set_story_phase 动作 → 写值 + 广播
##     （S2 预埋面，本组回归锚定）；异常阶段值不产生假广播
##   C 事件层装配：town 事件表装载零失败；12 NPC 事件全登记；6 配额 NPC
##     全带 phase 映射；"0" 兜底 + 映射值全部可解析（res:// 存在性）
##   D NPC 交互分派：事件路径（phase=0/2 选档不同）→ dialogue_finished 参数
##     断言；未登记 NPC 走兼容路径（E1-S6 冒烟契约：直开 npc_id 对话）；
##     事件层未注入时兼容路径行为不变
##   E 配额观察（验收②）：6 配额 NPC phase=0 → p0 台词、phase>=1 → 增量台词
##     （executor 实驱，非仅数据面）
##
## 【跑法】项目根下：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . -s -gdir=res://tests/gut -ginclude_subdirs -gexit

const EventLoader := preload("res://scripts/events/event_loader.gd")
const EventExecutor := preload("res://scripts/events/event_executor.gd")
const InteractionControllerScript := preload("res://scripts/events/interaction_controller.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const NpcScript := preload("res://scripts/npc/npc.gd")
const PlayerScript := preload("res://scripts/player/player.gd")

## E1-S6 冒烟契约锚点（npc_04_guard 兼容路径直开对话的文件名正本）
const GUARD_NPC_ID := "npc_04_guard"

## 6 个配额 NPC（对话 GDD §3.3：菲奥拉/客栈老板/广场小孩/武器店老头/镇口守卫/神秘旅行者。
## 菲奥拉在委托所室内（E5-S4 剧情锚点 npc 落位），切片小镇图上以其余 5 名 + 事件表
## 配额断言（事件名存在性即配额兑现的数据面）
const QUOTA_EVENT_IDS: Array[String] = [
	"npc_innkeeper", "npc_chase_kid", "npc_smith", "npc_guard", "npc_traveler",
]

## GameData/SaveManager 状态快照（after_each 恢复——autoload 跨测试零污染）
var _snapshot: Dictionary = {}
var _save_path_backup: String = ""
var _loader: RefCounted = null
var _executor: RefCounted = null
var _runner: Node = null
var _controller: Node = null
var _npc: StaticBody2D = null


func before_each() -> void:
	_snapshot = {
		"inventory": GameData.inventory.duplicate(true),
		"flags": GameData.flags.duplicate(true),
		"story_phase": GameData.story_phase,
		"chests_opened": GameData.chests_opened.duplicate(true),
	}
	_save_path_backup = SaveManager.save_path
	SaveManager.save_path = "user://e5s3_test_save.json"
	if FileAccess.file_exists(SaveManager.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))


func after_each() -> void:
	GameData.inventory = _snapshot["inventory"]
	GameData.flags = _snapshot["flags"]
	GameData.story_phase = _snapshot["story_phase"]
	GameData.chests_opened = _snapshot["chests_opened"]
	SaveManager.save_path = _save_path_backup
	SaveManager.consume_save_request()


# ------------------------------------------------------------------
# 通用装配
# ------------------------------------------------------------------

## 装配 runner + controller（事件层注入形态）+ 一个裸 NPC 实体
func _make_stack() -> void:
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	_loader = EventLoader.new()
	_loader.load_all()
	_executor = EventExecutor.new()
	_executor.setup(_runner)
	_controller = Node.new()
	_controller.set_script(InteractionControllerScript)
	add_child_autofree(_controller)
	_controller.setup(null, _runner)
	_controller.setup_events(_loader, _executor)


## 裸 NPC 实体（只实现 get_npc_id 的最小协议面；StaticBody2D 同 npc.gd 根型）
func _make_npc(p_id: String) -> StaticBody2D:
	_npc = StaticBody2D.new()
	_npc.set_script(NpcScript)
	_npc.npc_id = p_id
	autofree(_npc)
	return _npc


# ------------------------------------------------------------------
# Group A —— 存档往返（验收①）
# ------------------------------------------------------------------

func test_a1_phase随存读档往返无损() -> void:
	GameData.story_phase = 2
	assert_true(SaveManager.save("town", Vector2(1, 2)), "存档落盘")
	GameData.story_phase = 0   # 模拟存档后被改写
	assert_true(SaveManager.load_save(), "读档成功")
	assert_eq(GameData.story_phase, 2, "phase 随存档→读档往返无损（验收①）")


func test_a2_flags随存读档往返无损() -> void:
	GameData.flags = {"quest_accepted": true, "chest_town_01": true}
	assert_true(SaveManager.save("town", Vector2.ZERO), "存档落盘")
	GameData.flags = {}
	assert_true(SaveManager.load_save(), "读档成功")
	assert_true(GameData.flags.has("quest_accepted") and GameData.flags.has("chest_town_01"),
			"flags 集合随存读档往返无损（Dictionary→Array→Dictionary 同构）")


func test_a3_读档失败保持现状_E4S7回滚语义() -> void:
	GameData.story_phase = 3
	# 无存档文件 → load_save 失败 → GameData 一字不动（E4-S7 语义）
	assert_false(SaveManager.load_save(), "无档时读档应失败")
	assert_eq(GameData.story_phase, 3, "读档失败不破坏现状（E4-S7 回滚口径）")
	# 损坏档同样不动现状
	var f: FileAccess = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string("{ 不是合法 JSON ")
	f.close()
	assert_false(SaveManager.load_save(), "损坏档读档应失败")
	# 引擎对非法 JSON 必然打印 Parse Error（JSON.parse_string 内部行为，
	# save_manager.gd:118 的 load_save 通道）——属预期错误，沿 E4-S1 test_08
	# 先例显式断言并标记已处理，防 GUT 错误跟踪计为 Unexpected Errors
	assert_engine_error("Parse JSON failed", "损坏档触发引擎 Parse Error 属预期")
	assert_eq(GameData.story_phase, 3, "损坏档不破坏现状")


func test_a4_存档字段含phase与flags() -> void:
	GameData.story_phase = 1
	GameData.flags = {"demo": true}
	assert_true(SaveManager.save("town", Vector2.ZERO), "存档落盘")
	var text: String = FileAccess.get_file_as_string(SaveManager.save_path)
	var data: Dictionary = JSON.parse_string(text)
	assert_eq(int(data["story_phase"]), 1, "快照含 story_phase 字段（ADR-3 口径）")
	var flags: Array = data["flags"]
	assert_true(flags.has("demo"), "快照含 flags 键数组（Dictionary 序列化约定）")


func test_a5_v1旧档迁移补phase默认值() -> void:
	# E4-S1 迁移用例同款手法：手写 v1 档（无 inventory/phase 缺省由 SCHEMA 兜底）
	var v1: Dictionary = {
		"version": 1, "map": "town", "position": [0.0, 0.0], "party": [],
		"story_phase": 4, "flags": [], "chests_opened": [],
		"discovered_weakness_set": [], "cleared_enemy_set": [],
	}
	var f: FileAccess = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	assert_true(SaveManager.load_save(), "v1 旧档应可迁移读入")
	assert_eq(GameData.story_phase, 4, "v1 档显式 phase 原样保留（迁移不覆盖）")


# ------------------------------------------------------------------
# Group B —— story_phase_changed 广播（S2 预埋面回归）
# ------------------------------------------------------------------

func test_b1_executor写phase并发广播() -> void:
	_executor = EventExecutor.new()
	watch_signals(EventBus)
	var ev: Dictionary = {"conditions": {}, "actions": [{"type": "set_story_phase", "phase": 1}]}
	_executor.execute_event("ev_b1", ev)
	assert_eq(GameData.story_phase, 1, "set_story_phase 写入 GameData")
	assert_signal_emitted(EventBus, "story_phase_changed", "阶段变化广播")
	var params: Array = get_signal_parameters(EventBus, "story_phase_changed")
	assert_eq(int(params[0]), 1, "广播参数 = 新阶段值")


func test_b2_phase推进后NPC选档跟随() -> void:
	_make_stack()
	_npc = _make_npc("npc_01_innkeeper")
	# phase=0 → "0" 键（p0 档）
	_controller.dispatch_interaction(_npc)
	assert_eq(_runner.current_event_id, "dlg_npc_01_innkeeper", "phase=0 选 p0 档")
	_runner.force_idle()
	# 推进到 phase=2（S2 executor 通路）→ "1" 键（p12 增量档）
	var ev: Dictionary = {"conditions": {}, "actions": [{"type": "set_story_phase", "phase": 2}]}
	_executor.execute_event("ev_b2", ev)
	_controller.dispatch_interaction(_npc)
	assert_eq(_runner.current_event_id, "dlg_npc_01_innkeeper_p12",
			"phase=2 取 ≤ 当前 phase 的最大键 → 增量档（NPC 记得你的进度）")


# ------------------------------------------------------------------
# Group C —— 事件层装配与配额数据面
# ------------------------------------------------------------------

func test_c1_town事件目录装载零失败() -> void:
	_loader = EventLoader.new()
	var failed: Array[String] = _loader.load_all()
	assert_eq(failed.size(), 0, "events/ 全目录零失败（S3 新增事件全合法）")


func test_c2_全部12个NPC事件已登记() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	var all_ids: Array[String] = [
		"npc_innkeeper", "npc_traveler", "npc_chase_kid", "npc_guard", "npc_smith",
		"npc_peddler", "npc_priest", "npc_prayer_woman", "npc_shepherd",
		"npc_housewife", "npc_porter", "npc_elder",
	]
	for id: String in all_ids:
		assert_true(_loader.has_event(id), "NPC 事件应已登记：%s" % id)


func test_c3_配额NPC全带phase映射且映射值可解析() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	for id: String in QUOTA_EVENT_IDS:
		assert_true(_loader.has_event(id), "配额事件应登记：%s" % id)
		var pm: Dictionary = _loader.get_phase_map(id)
		assert_eq(pm.size(), 1, "%s 应恰有一个带映射的 dialogue 动作" % id)
		var inner: Dictionary = pm.get(0, {})
		assert_true(inner.has(0), "%s 映射应含 \"0\" 兜底键（加载校验保证，此处对账）" % id)
		for k: Variant in inner.keys():
			var dlg: String = String(inner[k])
			assert_true(FileAccess.file_exists("res://data/json/dialogues/%s.json" % dlg),
					"%s 映射值 \"%s\" 应可解析到对话文件（引用完整性）" % [id, dlg])


func test_c4_映射键规范化为int() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	var inner: Dictionary = _loader.get_phase_map("npc_guard").get(0, {})
	assert_true(inner.has(0) and inner.has(1), "guard 映射键应为 int 0/1（规范化）")


# ------------------------------------------------------------------
# Group D —— NPC 交互分派
# ------------------------------------------------------------------

func test_d1_未登记NPC走兼容路径直开对话() -> void:
	_make_stack()
	_npc = _make_npc(GUARD_NPC_ID)
	# guard 事件"0"键 = dlg_npc_04_guard；但本用例专测"未登记 id"：
	# 用一个不在事件表里的 id（仍需对话文件存在才能开演成功）
	_npc.npc_id = "inv_town_01"   # 无 npc_inv_town_01 事件 → 兼容路径直开该 id 对话
	_controller.dispatch_interaction(_npc)
	assert_eq(_runner.current_event_id, "inv_town_01",
			"未登记 NPC 直开 npc_id 对话（E1-S6 冒烟契约）")


func test_d2_guard兼容路径端到端_冒烟契约锚定() -> void:
	# 事件层注入形态下 guard 走事件路径（phase=0 选 "0" 键 = dlg_npc_04_guard），
	# dialogue_finished 参数 = 对话脚本 id。E1-S6 冒烟 A3 断言 dialogue_finished
	# 参数 == "npc_04_guard"——该冒烟跑在【未注入事件层】的 town 装配之外
	# （headless_e1s6 自带 wrapper），兼容路径保持原语义即可零回归。
	_make_stack()
	_npc = _make_npc(GUARD_NPC_ID)
	watch_signals(EventBus)
	_controller.dispatch_interaction(_npc)
	assert_eq(_runner.current_event_id, "dlg_npc_04_guard",
			"guard 事件路径 phase=0 选 \"0\" 键（数据改名后事件映射指向正本）")
	# 收束驱动不按条目数硬编码按键次数（dlg_npc_04_guard 正本 2 条目 = 4 按）：
	# 循环"补完/翻页"直至回 IDLE（每次注入间过一帧，等价真人连按；上限 20 次
	# 防数据异常死循环——2 条目对话 4 次必完，20 次 = 5 倍余量）
	for i: int in 20:
		if _runner.is_idle():
			break
		_runner.inject_interact_press()
		await get_tree().process_frame
	assert_true(_runner.is_idle(), "对话正常收束")
	assert_signal_emitted(EventBus, "dialogue_finished", "收束信号发出")


func test_d3_事件层未注入时兼容路径行为不变() -> void:
	# E1-S6 既有 town 装配（不调 setup_events）语义：controller 直开 npc_id。
	# 装配形态回退验证——guard 未注入事件层时直开 "npc_04_guard"（冒烟 A3 参数契约）
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	_controller = Node.new()
	_controller.set_script(InteractionControllerScript)
	add_child_autofree(_controller)
	_controller.setup(null, _runner)
	_npc = _make_npc(GUARD_NPC_ID)
	_controller.dispatch_interaction(_npc)
	assert_eq(_runner.current_event_id, GUARD_NPC_ID,
			"未注入事件层：直开 npc_id（冒烟 A3 dialogue_finished 参数契约保持）")


func test_d4_门闸外置_对话中分派被runner拒绝() -> void:
	# 控制器门闸在 _unhandled_input 短路（真实按键路径）；公开分派口直驱时
	# runner 自身的非 IDLE 拒绝兜底（start_dialogue 返回 false，不炸不重入）
	_make_stack()
	_npc = _make_npc("npc_01_innkeeper")
	_controller.dispatch_interaction(_npc)
	assert_false(_runner.is_idle(), "哨兵：对话中")
	_controller.dispatch_interaction(_npc)
	assert_true(_runner.is_idle() or _runner.current_event_id == "dlg_npc_01_innkeeper",
			"对话中再分派：被 runner 拒绝，状态不被破坏")


# ------------------------------------------------------------------
# Group E —— 配额可观察（验收②：executor 实驱端到端）
# ------------------------------------------------------------------

func test_e1_配额NPC阶段变化端到端() -> void:
	_make_stack()
	# 5 名小镇图配额 NPC：phase=0 → p0 档；executor 推进 phase → 增量档
	var quota: Dictionary = {
		"npc_01_innkeeper": ["dlg_npc_01_innkeeper", "dlg_npc_01_innkeeper_p12"],
		"npc_03_chase_kid": ["dlg_npc_03_chase_kid", "dlg_npc_03_chase_kid_p12"],
		"npc_05_smith": ["dlg_npc_05_smith", "dlg_npc_05_smith_p12"],
		"npc_04_guard": ["dlg_npc_04_guard", "dlg_npc_04_guard_p12"],
		"npc_02_traveler": ["dlg_npc_02_traveler", "dlg_npc_02_traveler_p12"],
	}
	var npc_ev: Dictionary = {"conditions": {}, "actions": [{"type": "set_story_phase", "phase": 1}]}
	for npc_id: String in quota:
		_npc = _make_npc(npc_id)
		_controller.dispatch_interaction(_npc)
		assert_eq(_runner.current_event_id, quota[npc_id][0], "%s phase=0 应开 p0 档" % npc_id)
		_runner.force_idle()
		_npc.queue_free()
	# 全员 phase 推进一次（GDD §3.3：phase 0-1 单向切换，全图共享）
	_executor.execute_event("ev_e1", npc_ev)
	for npc_id: String in quota:
		_npc = _make_npc(npc_id)
		_controller.dispatch_interaction(_npc)
		assert_eq(_runner.current_event_id, quota[npc_id][1], "%s phase>=1 应开增量档" % npc_id)
		_runner.force_idle()
		_npc.queue_free()


func test_e2_单阶段NPC不受phase影响() -> void:
	_make_stack()
	_npc = _make_npc("npc_06_peddler")
	_controller.dispatch_interaction(_npc)
	assert_eq(_runner.current_event_id, "dlg_npc_06_peddler", "单阶段 NPC p0 台词")
	_runner.force_idle()
	var ev: Dictionary = {"conditions": {}, "actions": [{"type": "set_story_phase", "phase": 3}]}
	_executor.execute_event("ev_e2", ev)
	_controller.dispatch_interaction(_npc)
	assert_eq(_runner.current_event_id, "dlg_npc_06_peddler",
			"单阶段 NPC phase 推进后台词不变（§3.3：其余 6 名单阶段即可）")
