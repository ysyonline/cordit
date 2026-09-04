extends GutTest
## test_t65.gd —— T6.5 P0 开场孤儿脚本接线测试（净增，不改旧）
##
## 【被测物】
##   数据：data/json/events/story_intro.json（事件 story_p0_intro：
##         conditions = story_phase==0 + not_flag story_p0_seen；
##         actions = dialogue story_p0_intro → set_flag → save_point）
##   代码：town_map.gd _assemble_opening_story（双守卫装配：生产启动语境
##         current_scene=="Main" + SaveManager.has_save()==false）
##   场景：town.tscn YSorted/P0_Anchor 锚点（与玩家出生位同格 (192,640)）
##
## 【验收映射】探索 GDD §3.4"首次启动（无存档）：开场剧情 P0 结束处执行一次
##   save_point"。save_point 动作语义 = 置 save_requested_pending 意图位
##   （冻结门控），落盘时点 = 下一次 map_ready（与 story_boss_pre 战后段同款）。
##
## 【卫生纪律】m6t41 同款：GameData 字段快照/还原、存档槽指测试路径、
##   意图位/last_loaded 清零、测试档用后即删（SMK-12 口径）。

const EventLoader := preload("res://scripts/events/event_loader.gd")
const EventExecutor := preload("res://scripts/events/event_executor.gd")
const TownScene := preload("res://scenes/maps/town.tscn")

const OPENING_EVENT_ID: String = "story_p0_intro"
const OPENING_FLAG: String = "story_p0_seen"
const OPENING_TRIGGER_NAME: String = "Evt_P0_Opening"
const SAVE_TEST_PATH: String = "user://save_t65_test.json"

## GameData 快照（before_all 备份 / after_all 还原，m6t41 同款口径）
var _phase_backup: int = 0
var _flags_backup: Dictionary = {}


func before_all() -> void:
	_phase_backup = GameData.story_phase
	_flags_backup = GameData.flags.duplicate()


func after_all() -> void:
	GameData.story_phase = _phase_backup
	GameData.flags = _flags_backup.duplicate()


func before_each() -> void:
	# 存档槽隔离：指测试槽 + 清意图位/last_loaded + 删残留档（m6t41 同款）
	SaveManager.save_path = SAVE_TEST_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}
	_remove_test_save()
	GameData.story_phase = 0
	GameData.flags = {}


func after_each() -> void:
	_remove_test_save()
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}
	GameData.story_phase = 0
	GameData.flags = {}


func _remove_test_save() -> void:
	if FileAccess.file_exists(SAVE_TEST_PATH):
		DirAccess.remove_absolute(SAVE_TEST_PATH)


## 假 Main 骨架（root 直下，名为 "Main"——生产启动守卫的判定对象）
func _make_fake_main() -> Node:
	var main := Node2D.new()
	main.name = "Main"
	get_tree().root.add_child(main)
	return main


# =============== A. 数据面（EventLoader + schema） ===============

func test_A1_事件JSON装载零失败且入表() -> void:
	var loader: RefCounted = EventLoader.new()
	var failed: Array[String] = loader.load_all()
	assert_eq(failed.size(), 0, "events 全目录应零失败（story_intro.json schema 合法）")
	assert_true(loader.has_event(OPENING_EVENT_ID), "P0 开局事件应入表")


func test_A2_事件结构对表_条件与动作序列() -> void:
	var loader: RefCounted = EventLoader.new()
	loader.load_all()
	var ev: Dictionary = loader.get_event(OPENING_EVENT_ID)
	assert_false(ev.is_empty(), "P0 事件应可查得")
	# conditions：phase==0 锚定 + not_flag 一次性（与宝箱/演示事件同构）。
	# JSON 数字解析恒为 float（0 → 0.0），逐字段显式类型化对表，不做整字典 ==。
	var conds: Dictionary = ev.get("conditions", {})
	var sp: Array = conds.get("story_phase", [])
	assert_eq(String(sp[0] if sp.size() > 0 else ""), "==", "phase 条件运算符应=锚定 ==")
	assert_eq(int(sp[1] if sp.size() > 1 else -1), 0, "phase 条件应锚定 0（开局）")
	assert_eq(String(conds.get("not_flag", "")), OPENING_FLAG,
			"not_flag 应= story_p0_seen 一次性旗")
	# actions：dialogue → set_flag → save_point（save_point 动作已由
	# executor 实装，story_boss_pre 先例同款；意图位语义落盘在 map_ready）
	var actions: Array = ev.get("actions", [])
	assert_eq(actions.size(), 3, "动作序列应 3 拍")
	assert_eq(String(actions[0]["type"]), "dialogue", "第 1 拍应为 dialogue")
	assert_eq(String(actions[0]["id"]), OPENING_EVENT_ID,
			"dialogue 应指向 P0 对话（文策渊正稿，文案零触碰）")
	assert_eq(String(actions[1]["type"]), "set_flag", "第 2 拍应为 set_flag")
	assert_eq(String(actions[1]["flag"]), OPENING_FLAG, "一次性旗名应对表")
	assert_eq(String(actions[2]["type"]), "save_point", "第 3 拍应为 save_point")


# =============== B. 条件门控（executor conditions_met） ===============

func test_B1_首启语境放行_phase0且无旗() -> void:
	assert_true(EventExecutor.new().conditions_met(_load_event()),
			"phase=0 + 无 story_p0_seen 旗（= 首次启动）应放行")


func test_B2_旗置位拦截() -> void:
	GameData.flags = {OPENING_FLAG: true}
	assert_false(EventExecutor.new().conditions_met(_load_event()),
			"story_p0_seen 旗在场应拦截（P0 不重演）")


func test_B3_phase非0拦截() -> void:
	GameData.story_phase = 2
	assert_false(EventExecutor.new().conditions_met(_load_event()),
			"phase>0（demo 中盘切入/续玩语境）应拦截")


func _load_event() -> Dictionary:
	var loader: RefCounted = EventLoader.new()
	loader.load_all()
	return loader.get_event(OPENING_EVENT_ID)


# =============== C. 执行链（mock runner 注入） ===============

func test_C1_执行链三动作依序生效() -> void:
	# mock runner：记录 start_dialogue 入参（e6s1 源码注入同款手法）
	var mock := GDScript.new()
	mock.source_code = """
extends Node
var started: Array = []
func start_dialogue(id: String) -> bool:
	started.append(id)
	return true
"""
	mock.reload()
	var runner: Node = mock.new()
	autofree(runner)
	var executor: RefCounted = EventExecutor.new()
	executor.setup(runner)
	var ev: Dictionary = _load_event()
	executor.execute_event(OPENING_EVENT_ID, ev)
	assert_eq(runner.started, [OPENING_EVENT_ID], "dialogue 应开演 P0（且仅一次）")
	assert_true(GameData.flags.has(OPENING_FLAG), "set_flag 应落 GameData.flags")
	assert_true(SaveManager.save_requested_pending,
			"save_point 应置存档意图位（冻结门控语义，落盘在 map_ready）")


# =============== D. 装配守卫（town 接线面） ===============

func test_D1_非生产语境直挂树不接线() -> void:
	# current_scene = GUT 场景（非 Main）→ 守卫①拦截：无 Evt_P0_Opening
	var town: Node = add_child_autofree(TownScene.instantiate())
	assert_true(town.get_node_or_null("Triggers") != null, "前置：Triggers 容器在场")
	assert_true(town.get_node_or_null("Triggers/" + OPENING_TRIGGER_NAME) == null,
			"非生产启动语境（GUT 直挂）不得接线 P0 触发器")


func test_D2_生产语境无存档接线_壳属性对表() -> void:
	var fake_main: Node = _make_fake_main()
	autofree(fake_main)
	var town: Node = add_child_autofree(TownScene.instantiate())
	# 守卫①窗口：换 current_scene → 直驱装配 → 还原（同步完成，不跨帧）
	var orig_cs: Node = get_tree().current_scene
	get_tree().current_scene = fake_main
	town._assemble_opening_story()
	get_tree().current_scene = orig_cs
	var trigger: Node = town.get_node_or_null("Triggers/" + OPENING_TRIGGER_NAME)
	assert_true(trigger != null, "生产语境 + 无存档应接线 P0 触发器")
	if trigger == null:
		return
	assert_eq(String(trigger.get("new_event_id")), OPENING_EVENT_ID,
			"薄壳应指向 story_p0_intro 事件")
	assert_eq(int(trigger.get("collision_mask")), 16, "踩踏面应监测玩家层 16")
	assert_eq(int(trigger.get("collision_layer")), 0, "触发器自身层应为 0")
	assert_eq((trigger as Node2D).position, Vector2(192, 640),
			"触发器应与出生锚点同位（出生即重叠）")


func test_D3_有存档不接线() -> void:
	# 守卫②：has_save()==true（GDD"首次启动（无存档）"原文口径）
	assert_true(SaveManager.save("town", Vector2(123, 456)), "前置：测试槽已落档")
	var fake_main: Node = _make_fake_main()
	autofree(fake_main)
	var town: Node = add_child_autofree(TownScene.instantiate())
	var orig_cs: Node = get_tree().current_scene
	get_tree().current_scene = fake_main
	town._assemble_opening_story()
	get_tree().current_scene = orig_cs
	assert_true(town.get_node_or_null("Triggers/" + OPENING_TRIGGER_NAME) == null,
			"已有存档（非首次启动）不得接线 P0 触发器")


func test_D4_出生重叠端到端_真实body_entered开演P0() -> void:
	# 真实物理链：接线后玩家与触发器同位重叠 → body_entered → 门闸 →
	# executor → P0 开演 + set_flag + 意图位（生产首启行为的完整复刻）
	var fake_main: Node = _make_fake_main()
	autofree(fake_main)
	var town: Node = add_child_autofree(TownScene.instantiate())
	var orig_cs: Node = get_tree().current_scene
	get_tree().current_scene = fake_main
	town._assemble_opening_story()
	get_tree().current_scene = orig_cs
	var trigger: Node = town.get_node_or_null("Triggers/" + OPENING_TRIGGER_NAME)
	assert_true(trigger != null, "前置：触发器已接线")
	if trigger == null:
		return
	# 等物理帧（Movie Maker/GUT 帧序坑同源：body_entered 在物理步进后发生）
	await wait_seconds(0.6)
	var runner: Node = town.dialogue_runner
	assert_true(runner != null and not runner.is_idle(), "出生重叠应自动开演 P0 对话")
	assert_true(GameData.flags.has(OPENING_FLAG), "set_flag 应已落 flags")
	assert_true(SaveManager.save_requested_pending, "save_point 意图位应已置位")
	# 收束清理：runner 强制回 IDLE（读档安全口径），防跨用例对话残留
	if runner != null and not runner.is_idle():
		runner.force_idle()
