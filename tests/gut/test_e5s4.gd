extends GutTest
## E5-S4 测试 —— 剧情四拍 + 三个 story_phase 切换点（对话 GDD §3.3/§3.5）
##
## 【硬标准】剧情四拍全程只改 JSON 不改代码跑通：本文件只测【数据面】，
## 不新增/修改任何产品代码（S4 交付物全部为 data/json/*）。
##
## 【分组】
##   A 四拍对话脚本存在且 schema 合法：p0_intro / p1_dispatch / p2_ruin_enter /
##     p3_finale（GDD §3.5 文件组织的平铺目录承载形态，story_ 前缀分段）
##   B 三个切换点事件接线（全项目仅 3 处，均为事件动作）：
##     ① story_quest_accept 末尾 set_story_phase 1（0→1）
##     ② story_ruin_enter 末尾 set_story_phase 2（1→2，带 >=1 条件）
##     ③ story_boss_pre 战后段 set_story_phase 3（2→3，带 >=2 条件 + save_point）
##   C 切换点时序端到端（executor 实驱）：conditions 门闸在低 phase 拒绝、
##     达标 phase 放行并推进；广播按 0→1→2→3 单向时序递进
##   D 配额第 6 席菲奥拉（S3 遗留缺口收口）：事件登记 + phase 映射 + 双档可解析
##     + executor 实驱分派（与 e5s3 e1 同构；e5s3 常量为 5 席小镇实体面，不动）
##
## 【跑法】项目根下：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const EventLoader := preload("res://scripts/events/event_loader.gd")
const EventExecutor := preload("res://scripts/events/event_executor.gd")
const InteractionControllerScript := preload("res://scripts/events/interaction_controller.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const NpcScript := preload("res://scripts/npc/npc.gd")

## 四拍对话脚本 id（GDD §3.5：p0_intro/p1_dispatch/p2_ruin_enter/p3_finale）
const STORY_BEAT_IDS: Array[String] = [
	"story_p0_intro", "story_p1_dispatch", "story_p2_ruin_enter", "story_p3_finale",
]

## GameData/SaveManager 状态快照（after_each 恢复——autoload 跨测试零污染，
## E5-S3 跨套件泄漏教训：快照必须含全部被改写字段）
var _snapshot: Dictionary = {}
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


func after_each() -> void:
	GameData.inventory = _snapshot["inventory"]
	GameData.flags = _snapshot["flags"]
	GameData.story_phase = _snapshot["story_phase"]
	GameData.chests_opened = _snapshot["chests_opened"]


## 装配 runner + controller（事件层注入形态）+ executor（e5s3 _make_stack 同构）
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


## 裸 NPC 实体（最小协议面，e5s3 同构）
func _make_npc(p_id: String) -> StaticBody2D:
	_npc = StaticBody2D.new()
	_npc.set_script(NpcScript)
	_npc.npc_id = p_id
	autofree(_npc)
	return _npc


# ------------------------------------------------------------------
# Group A —— 四拍对话脚本数据面（GDD §3.5 文件组织）
# ------------------------------------------------------------------

func test_a1_四拍脚本全部存在且装载零失败() -> void:
	for id: String in STORY_BEAT_IDS:
		assert_true(FileAccess.file_exists("res://data/json/dialogues/%s.json" % id),
				"四拍脚本应存在：%s" % id)
	# 全目录装载零失败（新四拍 + fiona 三件套全合法）
	_loader = EventLoader.new()
	var failed: Array[String] = _loader.load_all()
	assert_eq(failed.size(), 0, "events/ 全目录零失败（S4 新增数据全合法）")


func test_a2_四拍脚本对话可开演() -> void:
	_make_stack()
	for id: String in STORY_BEAT_IDS:
		assert_true(_runner.start_dialogue(id), "四拍脚本应可开演：%s" % id)
		_runner.force_idle()


# ------------------------------------------------------------------
# Group B —— 三个切换点事件接线（数据面）
# ------------------------------------------------------------------

func test_b1_切换点1_quest_accept末尾置phase1() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	assert_true(_loader.has_event("story_quest_accept"), "切换点1事件应登记")
	var ev: Dictionary = _loader.get_event("story_quest_accept")
	var actions: Array = ev.get("actions", [])
	assert_gt(actions.size(), 1, "切换点1应至少含 dialogue + set_story_phase 两动作")
	var last: Dictionary = actions[actions.size() - 1]
	assert_eq(String(last.get("type")), "set_story_phase", "切换点1末动作应为 set_story_phase")
	assert_eq(int(last.get("phase")), 1, "切换点1目标 phase=1（0→1）")
	var first: Dictionary = actions[0]
	assert_eq(String(first.get("type")), "dialogue", "切换点1首动作应先开演")
	assert_eq(String(first.get("id")), "story_p1_dispatch", "切换点1对白=P1 委托拍")


func test_b2_切换点2_ruin_enter带条件置phase2() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	assert_true(_loader.has_event("story_ruin_enter"), "切换点2事件应登记")
	var ev: Dictionary = _loader.get_event("story_ruin_enter")
	var conds: Dictionary = ev.get("conditions", {})
	assert_true(conds.has("story_phase"), "切换点2应有 story_phase 门闸")
	assert_eq(int((conds["story_phase"] as Array)[1]), 1, "门闸 >=1（防重复触发回跳）")
	var actions: Array = ev.get("actions", [])
	var last: Dictionary = actions[actions.size() - 1]
	assert_eq(String(last.get("type")), "set_story_phase", "切换点2末动作应为 set_story_phase")
	assert_eq(int(last.get("phase")), 2, "切换点2目标 phase=2（1→2）")
	assert_eq(String((actions[0] as Dictionary).get("id")), "story_p2_ruin_enter",
			"切换点2对白=P2 调查拍")


func test_b3_切换点3_boss_pre带条件置phase3并请求存档() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	assert_true(_loader.has_event("story_boss_pre"), "切换点3事件应登记")
	var ev: Dictionary = _loader.get_event("story_boss_pre")
	var conds: Dictionary = ev.get("conditions", {})
	assert_true(conds.has("story_phase"), "切换点3应有 story_phase 门闸")
	assert_eq(int((conds["story_phase"] as Array)[1]), 2, "门闸 >=2（Boss 战后段语义）")
	var actions: Array = ev.get("actions", [])
	var types: Array[String] = []
	for a: Variant in actions:
		types.append(String((a as Dictionary).get("type")))
	assert_true(types.has("dialogue"), "切换点3应含对白（P3 收束拍）")
	assert_true(types.has("set_story_phase"), "切换点3应含 set_story_phase")
	assert_true(types.has("save_point"), "切换点3战后段应请求存档（GDD §3.3 切换点3）")
	var phase_idx: int = types.find("set_story_phase")
	assert_eq(int((actions[phase_idx] as Dictionary).get("phase")), 3, "切换点3目标 phase=3（2→3）")


# ------------------------------------------------------------------
# Group C —— 切换点时序端到端（executor 实驱）
# ------------------------------------------------------------------

func test_c1_三切换点时序0123单向推进() -> void:
	_make_stack()
	watch_signals(EventBus)
	_loader = EventLoader.new()
	_loader.load_all()
	# 初始 phase=0：切换点2/3 被门闸拒绝
	GameData.story_phase = 0
	_executor.execute_event("story_ruin_enter", _loader.get_event("story_ruin_enter"))
	assert_eq(GameData.story_phase, 0, "phase=0 时切换点2被 >=1 门闸拒绝")
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	assert_eq(GameData.story_phase, 0, "phase=0 时切换点3被 >=2 门闸拒绝")
	# 切换点1：0→1（对白开演 + 置 phase）
	_executor.execute_event("story_quest_accept", _loader.get_event("story_quest_accept"))
	assert_eq(GameData.story_phase, 1, "切换点1推进 0→1")
	# 切换点1重放：重置后必须能再次触发（数据驱动可重入，门闸在切换点2/3侧）
	GameData.story_phase = 0
	_executor.execute_event("story_quest_accept", _loader.get_event("story_quest_accept"))
	assert_eq(GameData.story_phase, 1, "切换点1无门闸可重入（0→1 幂等）")
	# 切换点2：1→2
	_executor.execute_event("story_ruin_enter", _loader.get_event("story_ruin_enter"))
	assert_eq(GameData.story_phase, 2, "切换点2推进 1→2")
	# 切换点2重放于 phase=2：门闸 >=1 放行但动作重置 phase=2（不回跳不越界）
	_executor.execute_event("story_ruin_enter", _loader.get_event("story_ruin_enter"))
	assert_eq(GameData.story_phase, 2, "切换点2重放停在 2（重触发不越权）")
	# 切换点3：2→3 + save_requested。E5-S5 起 story_boss_pre 升级为 I5 全序列：
	# 战前拍→battle（挂起）→战后段（phase/save_point 在胜利续行段内）。
	# 测试模拟战斗胜利回传以驱动战后段（同 test_e5s5 c1 口径）；
	# battle 动作的 force_idle 是帧末，此处显式收束补齐时序（幂等）。
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	assert_true(_executor.in_battle_pause(), "切换点3应于 battle 处挂起（I5 全序列契约）")
	_runner.force_idle()
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	_executor.resolve_victory()
	assert_eq(GameData.story_phase, 3, "切换点3推进 2→3（切片终态）")
	assert_signal_emit_count(EventBus, "story_phase_changed", 5,
			"五次 set_story_phase 动作各广播一次（两次条件拒绝零广播）")


func test_c2_切换点3战段发存档请求() -> void:
	_make_stack()
	_loader = EventLoader.new()
	_loader.load_all()
	var residual: bool = SaveManager.consume_save_request()   # 清残留（consume-on-read）
	GameData.story_phase = 2
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	_runner.force_idle()
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	_executor.resolve_victory()
	assert_true(SaveManager.consume_save_request(),
			"切换点3战后段应发出存档请求（E4 consume-on-read 口径，返回值=待处理意图）")


# ------------------------------------------------------------------
# Group D —— 配额第 6 席菲奥拉（S3 缺口收口）
# ------------------------------------------------------------------

func test_d1_菲奥拉事件登记且phase映射齐备() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	assert_true(_loader.has_event("npc_fiona"), "菲奥拉事件应登记（配额第 6 席）")
	var pm: Dictionary = _loader.get_phase_map("npc_fiona")
	assert_eq(pm.size(), 1, "npc_fiona 应恰有一个带映射的 dialogue 动作")
	var inner: Dictionary = pm.get(0, {})
	assert_true(inner.has(0) and inner.has(1), "映射键应为 int 0/1（规范化）")
	assert_eq(String(inner[0]), "dlg_npc_13_fiona", "\"0\" 键指 P0 档")
	assert_eq(String(inner[1]), "dlg_npc_13_fiona_p12", "\"1\" 键指增量档")
	for k: Variant in inner.keys():
		var dlg: String = String(inner[k])
		assert_true(FileAccess.file_exists("res://data/json/dialogues/%s.json" % dlg),
				"映射值 \"%s\" 应可解析到对话文件" % dlg)


func test_d2_菲奥拉阶段变化端到端() -> void:
	_make_stack()
	_npc = _make_npc("npc_13_fiona")
	_controller.dispatch_interaction(_npc)
	assert_eq(_runner.current_event_id, "dlg_npc_13_fiona", "菲奥拉 phase=0 开 P0 档")
	_runner.force_idle()
	var ev: Dictionary = {"conditions": {}, "actions": [{"type": "set_story_phase", "phase": 1}]}
	_executor.execute_event("ev_d2", ev)
	_controller.dispatch_interaction(_npc)
	assert_eq(_runner.current_event_id, "dlg_npc_13_fiona_p12", "菲奥拉 phase>=1 开增量档")
