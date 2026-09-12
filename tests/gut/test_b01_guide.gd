extends GutTest
## B-01 引导缺位修复测试 —— 任务目标 HUD + 告示板「!」提示
##
## 【缺陷背景】R-1 外部试玩（m7-external-playtest-01.md §3 B-01，Blocker）：
##   玩家 story_phase=0、从未对告示板按 Z、Boss 永不触发——「没看见boss，
##   不知道怎么触发」。headless 复现证代码链零断点（evidence/
##   _story_chain_repro.log ALL PASS），纯引导缺位。修复两件：
##   ① town 告示板「❗Z」脉冲标签（phase>=1 隐藏）
##   ② 常驻任务目标 HUD（quest_objective_hud.gd，story_phase_changed 驱动）
##
## 【分组】
##   A HUD 纯逻辑：phase→文案映射 / 底条适配 / phase>=3 隐藏 / 同值幂等
##   B HUD 信号驱动：story_phase_changed 换文案（生产消费链同款驱动）
##   C 装配级：真 town.tscn 装配后 HUD 在位 + 告示板「!」在位 + phase 门控
##
## 【跑法】项目根下（APPDATA 沙盒必带——GUT 不隔离用户存档教训）：
##   MSYS2_ARG_CONV_EXCL="*" APPDATA=<sandbox> Godot_console.exe --headless
##   --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const TownScenePath: String = "res://scenes/maps/town.tscn"
const HudScript := preload("res://scripts/ui/quest_objective_hud.gd")
const BILLBOARD_ID: String = "inv_town_02"

## GameData 状态快照（after_each 恢复——autoload 跨测试零污染，m7r6 同款纪律）
var _snapshot: Dictionary = {}


func before_each() -> void:
	_snapshot = {
		"story_phase": GameData.story_phase,
		"flags": GameData.flags.duplicate(true),
		"inventory": GameData.inventory.duplicate(true),
		"chests_opened": GameData.chests_opened.duplicate(true),
	}


func after_each() -> void:
	GameData.story_phase = _snapshot["story_phase"]
	GameData.flags = _snapshot["flags"]
	GameData.inventory = _snapshot["inventory"]
	GameData.chests_opened = _snapshot["chests_opened"]


## 裸 HUD 实例（直挂测试树；_ready 内直读 GameData.story_phase 初始同步）
func _make_hud() -> Control:
	var hud := Control.new()
	hud.set_script(HudScript)
	add_child_autofree(hud)
	return hud


# ------------------------------------------------------------------
# Group A —— HUD 纯逻辑（初始同步 + 映射表）
# ------------------------------------------------------------------

func test_a1_phase0初始同步显示接取目标() -> void:
	GameData.story_phase = 0
	var hud: Control = _make_hud()
	assert_true(hud.visible, "phase=0 装配即显示（未接取是 R-1 卡死点，须最显眼）")
	assert_eq(String(hud.call("get_displayed_objective")), "◆ 查看告示板，接取委托",
			"phase=0 文案应为接取指引")


func test_a2_phase1初始同步显示遗迹目标() -> void:
	GameData.story_phase = 1
	var hud: Control = _make_hud()
	assert_true(hud.visible, "phase=1 显示")
	assert_eq(String(hud.call("get_displayed_objective")), "◆ 前往遗迹一层，调查异常亮光",
			"phase=1 文案应与 story_p1_dispatch 委托原文口径一致")


func test_a3_phase2初始同步显示石棺目标() -> void:
	GameData.story_phase = 2
	var hud: Control = _make_hud()
	assert_true(hud.visible, "phase=2 显示")
	assert_eq(String(hud.call("get_displayed_objective")), "◆ 深入遗迹第三层，调查石棺",
			"phase=2 文案应指向 f3 棺前锚")


func test_a4_phase3以上隐藏() -> void:
	GameData.story_phase = 3
	var hud: Control = _make_hud()
	assert_false(hud.visible, "phase=3（终章后）应隐藏——无「下一步」可指")


func test_a5_文案表与剧情三阶段对齐() -> void:
	# 映射表键覆盖口径：0/1/2 有条目，3+ 无（has 判定即隐藏语义）
	var table: Dictionary = HudScript.OBJECTIVES
	assert_true(table.has(0), "OBJECTIVES 应含 phase=0（接取指引）")
	assert_true(table.has(1), "OBJECTIVES 应含 phase=1（遗迹一层）")
	assert_true(table.has(2), "OBJECTIVES 应含 phase=2（遗迹三层石棺）")
	assert_false(table.has(3), "OBJECTIVES 不应含 phase=3（终章后隐藏）")


# ------------------------------------------------------------------
# Group B —— 信号驱动（EventBus.story_phase_changed 消费链）
# ------------------------------------------------------------------

func test_b1_信号驱动换文案0到1() -> void:
	GameData.story_phase = 0
	var hud: Control = _make_hud()
	EventBus.story_phase_changed.emit(1)
	assert_eq(String(hud.call("get_displayed_objective")), "◆ 前往遗迹一层，调查异常亮光",
			"收 phase_changed(1) 应切遗迹目标（接取委托后即时反馈）")
	assert_true(hud.visible, "切相后保持可见")


func test_b2_信号驱动换文案1到2() -> void:
	GameData.story_phase = 1
	var hud: Control = _make_hud()
	EventBus.story_phase_changed.emit(2)
	assert_eq(String(hud.call("get_displayed_objective")), "◆ 深入遗迹第三层，调查石棺",
			"收 phase_changed(2) 应切石棺目标（f1 入口锚后即时反馈）")


func test_b3_信号驱动phase3隐藏() -> void:
	GameData.story_phase = 2
	var hud: Control = _make_hud()
	assert_true(hud.visible, "哨兵：phase=2 可见")
	EventBus.story_phase_changed.emit(3)
	assert_false(hud.visible, "收 phase_changed(3) 应隐藏（终章后无目标）")


func test_b4_同值重放幂等() -> void:
	GameData.story_phase = 1
	var hud: Control = _make_hud()
	EventBus.story_phase_changed.emit(1)
	EventBus.story_phase_changed.emit(1)
	assert_true(hud.visible, "同值重放不改变可见性（幂等刷写）")
	assert_eq(String(hud.call("get_displayed_objective")), "◆ 前往遗迹一层，调查异常亮光",
			"同值重放文案不变")


# ------------------------------------------------------------------
# Group C —— 装配级（真 town.tscn 端到端）
# ------------------------------------------------------------------

## town.tscn 实树装配（m7r6 _load_town 同口径：_ready 全链装配）
func _load_town() -> Node:
	var packed: PackedScene = load(TownScenePath)
	var map: Node = packed.instantiate()
	add_child_autofree(map)
	return map


func test_c1_town装配后任务目标HUD在位且随phase落显() -> void:
	GameData.story_phase = 0
	var map: Node = _load_town()
	assert_true(map.quest_objective_hud != null, "town 装配产物应含任务目标 HUD 实例")
	assert_true(map.quest_objective_hud.visible, "装配级：phase=0 HUD 应显示")
	assert_eq(String(map.quest_objective_hud.call("get_displayed_objective")),
			"◆ 查看告示板，接取委托", "装配级：初始同步应显示接取指引")
	# 信号驱动切相（生产链：告示板交互 → executor set_story_phase → 广播）
	GameData.story_phase = 1
	EventBus.story_phase_changed.emit(1)
	assert_eq(String(map.quest_objective_hud.call("get_displayed_objective")),
			"◆ 前往遗迹一层，调查异常亮光", "装配级：收信号应切遗迹目标")


func test_c2_town装配后告示板感叹号提示在位() -> void:
	GameData.story_phase = 0
	var map: Node = _load_town()
	assert_true(map.billboard_hint != null, "town 装配产物应含告示板「!」提示标签")
	assert_true(map.billboard_hint.visible, "phase=0 提示应可见（引导入口）")
	assert_eq(String(map.billboard_hint.text), "❗Z", "提示文案应为「❗Z」（同 O-12 已验证样式）")
	# 门控：phase 推进后隐藏
	GameData.story_phase = 1
	EventBus.story_phase_changed.emit(1)
	assert_false(map.billboard_hint.visible, "接取委托（phase>=1）后提示应隐藏")


func test_c3_带档phase1进镇提示自动隐藏() -> void:
	# 带档启动（phase 已 >=1）重进 town：装配时按 GameData 现状判定隐藏
	GameData.story_phase = 1
	var map: Node = _load_town()
	assert_true(map.billboard_hint != null, "带档进镇提示标签仍应装配（对表用）")
	assert_false(map.billboard_hint.visible, "phase>=1 进镇提示应装配即隐藏")


func test_c4_town重复装配防双实例() -> void:
	# 跨图往返会二次 _ready：HUD 按"脚本一致即复用"防重（menu_panel 同款守卫）
	GameData.story_phase = 0
	var map: Node = _load_town()
	var hud_first: Control = map.quest_objective_hud
	# 模拟重进 town：再次装配到同一 UILayer 兜底宿主（测试树 = map 自身）
	map._assemble_quest_objective_hud()
	map._assemble_map_name_hud()
	assert_eq(map.quest_objective_hud, hud_first,
			"二次装配应复用既有实例（防双 HUD 双显示）")
