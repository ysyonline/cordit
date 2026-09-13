extends GutTest
## test_m8a4_story_once.gd —— M8-B① 剧情事件一次性触发（not_flag / set_flag）
##
## 【被测行为】story_ruin_enter / story_boss_pre 是"推进剧情 phase"的一次性事件：
##   触发过（且成功走完）后，同一存档内不应重播——由数据侧 conditions.not_flag +
##   actions 末尾 set_flag 保证（与 story_intro / party_chat 同范式）。
##   【胜负语义红线】story_boss_pre 的 set_flag 必须在 battle【之后】（actions 末尾）：
##   胜利才续行至末尾置位（此后不重播）；战败走 clear_battle_pause 丢弃续行段 →
##   不置位 → 战败可重试（与 test_e5s5 d1 既有契约一致）。把 set_flag 提到 battle
##   之前会破坏本组 G3。
##
## 【用户实机缺陷】从 road 进遗迹一层播完剧情，往返后再进又重播；f3 Boss 剧情同样。
##   根因：两条事件只有单调门（>=1 / >=2），无一次性标志 → phase 推进后门仍真 → 重播。
##
## 【分组】
##   G1 ruin_enter 一次性：首触发置位；重触发被 not_flag 拒绝、不再开演（非只看 phase）
##   G2 boss 胜利后一次性：胜利续行置位；重触发被拒
##   G3 胜负语义红线：战败不置位（可重试、战前拍重开演）；胜利续行才置位；此后不重播
##
## 【跑法】项目根下（APPDATA 沙盒必带——GUT 不隔离用户存档教训）：
##   MSYS2_ARG_CONV_EXCL="*" APPDATA=<sandbox> Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const EventLoader := preload("res://scripts/events/event_loader.gd")
const EventExecutor := preload("res://scripts/events/event_executor.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")

## 一次性标志名（数据侧 data/json/events/story_anchor.json 正本）
const FLAG_RUIN_SEEN: String = "story_ruin_enter_seen"
const FLAG_BOSS_SEEN: String = "story_boss_pre_seen"

## GameData/SaveManager 状态快照（after_each 恢复——autoload 跨套件零污染，
## e5s4/e5s5 同纪律：快照须含全部被改写字段）
var _snapshot: Dictionary = {}
var _loader: RefCounted = null
var _executor: RefCounted = null
var _runner: Node = null


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
	SaveManager.consume_save_request()
	if _executor != null and _executor.has_method("clear_battle_pause"):
		_executor.clear_battle_pause()
	_executor = null


## 装配 loader + 真实 runner + executor（e5s5 _make_stack 同构）
func _make_stack() -> void:
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	_loader = EventLoader.new()
	assert_eq((_loader.load_all() as Array).size(), 0, "前置：事件表装载零失败")
	_executor = EventExecutor.new()
	_executor.setup(_runner)


func _ev(p_id: String) -> Dictionary:
	return _loader.get_event(p_id)


# ------------------------------------------------------------------
# Group G —— 一次性触发（not_flag / set_flag）
# ------------------------------------------------------------------

func test_g1_ruin_enter一次性防重播() -> void:
	_make_stack()
	GameData.story_phase = 1
	_executor.execute_event("story_ruin_enter", _ev("story_ruin_enter"))
	assert_eq(GameData.story_phase, 2, "首次触发推进 1→2")
	assert_true(GameData.flags.has(FLAG_RUIN_SEEN),
			"首次触发应置一次性标志（not_flag 的判据）")
	_runner.force_idle()   # 清 current_event_id，令"未被改写"可判
	assert_eq(_runner.current_event_id, "", "前置：force_idle 后 current_event_id 已清")
	_executor.execute_event("story_ruin_enter", _ev("story_ruin_enter"))
	assert_eq(GameData.story_phase, 2, "重触发后 phase 保持 2（不再推进）")
	assert_eq(_runner.current_event_id, "",
			"重触发被 not_flag 拒绝 → 不再开演（证明无二次开演，而非只是 phase 未变）")


func test_g2_boss_pre胜利后一次性防重播() -> void:
	_make_stack()
	GameData.story_phase = 2
	_executor.execute_event("story_boss_pre", _ev("story_boss_pre"))
	assert_true(_executor.in_battle_pause(), "前置：战前段于 battle 处挂起")
	_runner.force_idle()
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	_executor.resolve_victory()
	assert_eq(GameData.story_phase, 3, "胜利续行推进 2→3")
	assert_true(GameData.flags.has(FLAG_BOSS_SEEN), "胜利续行末尾应置一次性标志")
	_runner.force_idle()
	_executor.execute_event("story_boss_pre", _ev("story_boss_pre"))
	assert_eq(GameData.story_phase, 3, "胜利后重触发停 3（不越权不回跳）")
	assert_eq(_runner.current_event_id, "",
			"胜利后重触发被 not_flag 拒绝 → 不再开演")


func test_g3_战败不置位可重试_胜利后才一次性() -> void:
	_make_stack()
	GameData.story_phase = 2
	# 第一轮：触发 → 战败 → 清挂起（生产由 battle_event_bridge 调 clear_battle_pause）
	_executor.execute_event("story_boss_pre", _ev("story_boss_pre"))
	assert_true(_executor.in_battle_pause(), "前置：第一次触发已挂起")
	EventBus.battle_finished.emit({"outcome": "DEFEAT"})
	_executor.clear_battle_pause()
	assert_false(GameData.flags.has(FLAG_BOSS_SEEN),
			"战败不得置一次性标志（set_flag 在 battle 之后 → 续行段被丢弃 → 可重试）")
	# 重试：从头重新开演
	_runner.force_idle()
	_executor.execute_event("story_boss_pre", _ev("story_boss_pre"))
	assert_eq(_runner.current_event_id, "story_p3_boss_front", "战败重试：战前拍重新开演")
	# 第二轮：胜利 → 续行至末尾 → 置位 + 一次性
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	_executor.resolve_victory()
	assert_eq(GameData.story_phase, 3, "重试胜利后 phase 照常 2→3")
	assert_true(GameData.flags.has(FLAG_BOSS_SEEN), "胜利续行末尾置一次性标志")
	_runner.force_idle()
	_executor.execute_event("story_boss_pre", _ev("story_boss_pre"))
	assert_eq(GameData.story_phase, 3, "胜利后重触发停 3")
	assert_eq(_runner.current_event_id, "",
			"胜利后重触发被 not_flag 拒绝 → 不再开播")
