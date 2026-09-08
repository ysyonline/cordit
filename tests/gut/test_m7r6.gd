extends GutTest
## M7-R6 缺陷修复批次测试 —— story_quest_accept 告示板接线 + 对话框键位提示
##
## 【缺陷背景】（用户试玩反馈，M7 记录 2026-09-05）
##   ① story_quest_accept（接委托 → 播 story_p1_dispatch + set_story_phase 1）
##     全项目零触发器接线：P0 开场后告示板（inv_town_02，town tile 30,10）
##     只播风味文本，进遗迹 P2 剧情（story_ruin_enter 条件 phase>=1）被
##     phase=0 静默跳过——剧情链断裂。
##   ② 对话首句无键位提示："第一句不知道按什么"（ContinueHint 改 "Z/E ▼"，
##     几何/文本在 dialogue_box.tscn，visible 逻辑零改动——本文件锁数据面，
##     UI 时机断言沿用既有 e5s1 口径不重复）。
##
## 【修复口径】（主理人已与用户确认）
##   phase==0：告示板交互（Z/E，面前一格）→ 开演 story_quest_accept →
##     set_story_phase 1；phase>=1：告示板回落 flavor_inv_town_02 风味文本
##     （调查点可无限重复交互语义不变）。
##
## 【实现链路】复用既有协议与薄壳（ADR 禁翻案）：
##   investigate_point.setup_events（事件层注入，get_event_id 预留协议启用）
##   → is_idle 门闸（同 TriggerEventShell 口径）→ EventExecutor.conditions_met
##   （story_quest_accept.json 的 story_phase==0 守卫，story_p0_intro 同款
##   判定口径）→ execute_event；条件不满足回落既有 flavor 路径。
##
## 【分组】
##   A 数据面：story_quest_accept 守卫（phase==0）+ 告示板 flavor 资产在位
##   B 交互级：phase=0 交互开演置 phase 1 / phase=1 回落风味文本 / 门闸 /
##     未注入事件层与未登记 id 的零回归路径
##   C 装配级：真 town.tscn 装配后告示板事件路径端到端生效
##
## 【跑法】项目根下：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const EventLoader := preload("res://scripts/events/event_loader.gd")
const EventExecutor := preload("res://scripts/events/event_executor.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const InvestigateScript := preload("res://scripts/events/investigate_point.gd")
const TOWN_SCENE_PATH: String = "res://scenes/maps/town.tscn"

## 告示板点位 id（town tile 30,10，PointCatalog.INVESTIGATES 正本）
const BILLBOARD_ID: String = "inv_town_02"

## GameData 状态快照（after_each 恢复——autoload 跨测试零污染，e5s4 同款纪律）
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


## 装配 runner + 事件层（e5s4 _make_stack 同构；runner 节点名同生产装配面
## ——investigate_point 回落路径按名 find_child("DialogueRunner")）
func _make_stack() -> void:
	_runner = RunnerScript.new()
	_runner.name = "DialogueRunner"
	add_child_autofree(_runner)
	_loader = EventLoader.new()
	_loader.load_all()
	_executor = EventExecutor.new()
	_executor.setup(_runner)


## 裸告示板实体（协议面同 map_events._build_investigate + town_map 告示板
## 映射：quest_event_id 由装配面写入——测试镜像生产接线口径）
func _make_billboard(p_inject_events: bool) -> StaticBody2D:
	var inv := StaticBody2D.new()
	inv.set_script(InvestigateScript)
	inv.inv_id = BILLBOARD_ID
	inv.event_id = BILLBOARD_ID
	inv.dialogue_id = "flavor_" + BILLBOARD_ID
	inv.quest_event_id = "story_quest_accept"
	add_child_autofree(inv)   # 必须入树：on_interact 的 get_tree() 依赖
	if p_inject_events:
		inv.setup_events(_loader, _executor, _runner)
	return inv


# ------------------------------------------------------------------
# Group A —— 数据面守卫（story_p0_intro 同款判定口径）
# ------------------------------------------------------------------

func test_a1_quest_accept应带phase0守卫() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	assert_true(_loader.has_event("story_quest_accept"), "切换点1事件应登记")
	var ev: Dictionary = _loader.get_event("story_quest_accept")
	var conds: Dictionary = ev.get("conditions", {})
	assert_true(conds.has("story_phase"), "M7-R6：quest_accept 应带 story_phase 守卫（防 phase>=1 重放开演）")
	assert_eq(String((conds["story_phase"] as Array)[0]), "==", "守卫运算符应为 ==（仅 phase=0 接委托）")
	assert_eq(int((conds["story_phase"] as Array)[1]), 0, "守卫目标 phase=0")


func test_a2_告示板flavor资产在位() -> void:
	assert_true(FileAccess.file_exists("res://data/json/dialogues/flavor_%s.json" % BILLBOARD_ID),
			"告示板回落风味文本资产应存在：flavor_inv_town_02.json")
	assert_true(FileAccess.file_exists("res://data/json/dialogues/story_p1_dispatch.json"),
			"接线目标对话资产应存在：story_p1_dispatch.json")


# ------------------------------------------------------------------
# Group B —— 交互级（薄壳协议实驱）
# ------------------------------------------------------------------

func test_b1_phase0交互开演委托拍并置phase1() -> void:
	_make_stack()
	GameData.story_phase = 0
	var inv: StaticBody2D = _make_billboard(true)
	inv.on_interact()
	assert_eq(GameData.story_phase, 1, "phase=0 交互应推进 0→1（set_story_phase 动作）")
	assert_eq(String(_runner.current_event_id), "story_p1_dispatch",
			"交互应开演 story_quest_accept 的委托拍对白")
	assert_false(_runner.is_idle(), "对白应处于播放态（剧情链已接通）")
	_runner.force_idle()


func test_b2_phase1交互回落风味文本() -> void:
	_make_stack()
	GameData.story_phase = 1
	var inv: StaticBody2D = _make_billboard(true)
	inv.on_interact()
	assert_eq(GameData.story_phase, 1, "phase=1 交互不得再推进 phase（守卫拒绝）")
	assert_eq(String(_runner.current_event_id), "flavor_inv_town_02",
			"phase>=1 应回落告示板风味文本（调查语义不变）")
	assert_false(_runner.is_idle(), "风味文本应正常开演（可无限重复交互）")
	_runner.force_idle()
	# 可重复交互：二次交互同样回落风味文本、零状态漂移
	inv.on_interact()
	assert_eq(String(_runner.current_event_id), "flavor_inv_town_02", "重复交互仍回落风味文本")
	_runner.force_idle()


func test_b3_对话期间交互被门闸忽略() -> void:
	_make_stack()
	GameData.story_phase = 0
	_runner.start_dialogue("flavor_inv_town_02")   # 制造对话中
	assert_false(_runner.is_idle(), "哨兵：对话中")
	var inv: StaticBody2D = _make_billboard(true)
	inv.on_interact()
	assert_eq(GameData.story_phase, 0, "对话期间交互应被 is_idle 门闸忽略（边缘 2，同 TriggerEventShell 口径）")
	_runner.force_idle()


func test_b4_未注入事件层行为零变化() -> void:
	# E4-S5 兼容路径：无事件层装配（其余四图/旧测试语境）直走 flavor，零回归
	_make_stack()
	GameData.story_phase = 0
	var inv: StaticBody2D = _make_billboard(false)
	inv.on_interact()
	assert_eq(GameData.story_phase, 0, "未注入事件层不得推进 phase")
	assert_eq(String(_runner.current_event_id), "flavor_inv_town_02",
			"未注入事件层应直开 flavor（E4-S5 行为零变化）")
	_runner.force_idle()


func test_b5_未登记id回落flavor路径() -> void:
	# 事件层已注入但点位 id 未登记事件表（如普通调查点）→ 兼容路径
	_make_stack()
	GameData.story_phase = 0
	var inv := StaticBody2D.new()
	inv.set_script(InvestigateScript)
	inv.inv_id = "inv_town_01"
	inv.dialogue_id = "flavor_inv_town_01"
	inv.setup_events(_loader, _executor, _runner)
	add_child_autofree(inv)   # 入树：flavor 回落路径需 get_tree() 找 runner
	inv.on_interact()
	assert_eq(GameData.story_phase, 0, "未登记 id 不得触发任何事件")
	assert_eq(String(_runner.current_event_id), "flavor_inv_town_01",
			"未登记 id 应回落既有 flavor 路径")
	_runner.force_idle()


# ------------------------------------------------------------------
# Group C —— 装配级（真 town.tscn 端到端）
# ------------------------------------------------------------------

## town.tscn 实树装配（e4s5 _load_map 同口径）：_ready 全链含事件层注入
func _load_town() -> Node:
	var packed: PackedScene = load(TOWN_SCENE_PATH)
	var map: Node = packed.instantiate()
	add_child_autofree(map)
	return map


func test_c1_town装配后告示板事件路径端到端生效() -> void:
	var map: Node = _load_town()
	GameData.story_phase = 0
	# 找到告示板实体（装配产物遍历，命名不依赖）
	var billboard: StaticBody2D = null
	for inv: Node in (map.content_points["investigates"] as Array):
		if String(inv.call("get_event_id")) == BILLBOARD_ID:
			billboard = inv as StaticBody2D
			break
	assert_true(billboard != null, "town 装配产物应含告示板实体 %s" % BILLBOARD_ID)
	var town_runner: Node = map.dialogue_runner
	assert_true(town_runner != null, "town 应已装配对话运行器")
	# phase=0 交互：开演委托拍 + 置 phase 1（P0 后剧情链接通）
	billboard.on_interact()
	assert_eq(GameData.story_phase, 1, "装配级：phase=0 交互应推进 0→1")
	assert_eq(String(town_runner.current_event_id), "story_p1_dispatch",
			"装配级：交互应开演委托拍对白（事件路径经 town 事件层三件套）")
	town_runner.force_idle()
	# phase=1 再交互：回落风味文本（守卫拒绝 + flavor 兜底）
	billboard.on_interact()
	assert_eq(GameData.story_phase, 1, "装配级：phase=1 再交互不得推进 phase")
	assert_eq(String(town_runner.current_event_id), "flavor_inv_town_02",
			"装配级：phase=1 应回落告示板风味文本")
	town_runner.force_idle()


func test_c2_town其余调查点不受接线影响() -> void:
	# 通用注入 + has_event 门闸的回归面：普通调查点（无事件登记）仍走 flavor
	var map: Node = _load_town()
	GameData.story_phase = 0
	var fountain: StaticBody2D = null
	for inv: Node in (map.content_points["investigates"] as Array):
		if String(inv.call("get_event_id")) == "inv_town_01":
			fountain = inv as StaticBody2D
			break
	assert_true(fountain != null, "town 装配产物应含调查点 inv_town_01")
	fountain.on_interact()
	assert_eq(GameData.story_phase, 0, "普通调查点不得触发任何事件")
	assert_eq(String(map.dialogue_runner.current_event_id), "flavor_inv_town_01",
			"普通调查点仍走 flavor 路径（零回归）")
	map.dialogue_runner.force_idle()
