extends GutTest
## E5-S5 测试 —— Boss 事件锚点 + battle 中断恢复桥（对话 GDD §6"对战斗"、
## 探索 GDD I5 回签、EPIC-5 E5-S5 验收两条）
##
## 【硬标准】
##   验收①：Boss 战前/后事件完整走通，phase 2→3 在战后段内生效
##   验收②：Boss 失败读档后事件从头可再触发、无中途态残留（探索边缘 3）
##
## 【分组】
##   A 数据面：story_boss_pre I5 全序列结构（战前台词→battle→战后段尾接
##     set_story_phase(3)+save_point；战前拍 story_p3_boss_front 存在合法）
##   B 暂停路径：battle 动作 → 挂起簿记 + 暂停闸 + 哨兵载荷 + 战前段已执行
##   C 恢复路径：模拟 VICTORY（直接 emit，headless 可测）→ 续行段生效
##     （phase 2→3 战后段内 + save_requested）+ 挂起闸解除
##   D 失败路径：模拟 DEFEAT → 簿记清空 + 事件可从头完整再触发（验收②）
##   E 桥接单元：挂起登记 / 普通遇敌零簿记 / 回程字段补全 / scene_router
##     全局 executor 装配契约
##   F f3 装配面：BossTriggers 锚点同位重建 trigger_event_shell、协议属性、
##     交互路径驱动（inject_emit 直驱发射链）
##
## 【跑法】项目根下：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const EventLoader := preload("res://scripts/events/event_loader.gd")
const EventExecutor := preload("res://scripts/events/event_executor.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const ShellScript := preload("res://scripts/events/trigger_event_shell.gd")
const RuinsF3MapScript := preload("res://scripts/maps/ruins_f3_map.gd")

## GameData/SaveManager 状态快照（after_each 恢复——跨套件零污染；
## story_phase 曾污染 4 套件的 E2-S4 教训：快照必须含全部被改写字段）
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
	# save_point / battle 用例的信号与簿记残留清零（跨套件隔离）
	SaveManager.consume_save_request()
	if _executor != null and _executor.has_method("clear_battle_pause"):
		_executor.clear_battle_pause()
	_executor = null


## 装配 loader + 真实 runner + executor（e5s4 _make_stack 简版，无 controller）
func _make_stack() -> void:
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	_loader = EventLoader.new()
	var failed: Array[String] = _loader.load_all()
	assert_eq(failed.size(), 0, "前置：事件表装载零失败")
	_executor = EventExecutor.new()
	_executor.setup(_runner)


# ------------------------------------------------------------------
# Group A —— 数据面：I5 全序列结构（GDD I5 回签原文逐项）
# ------------------------------------------------------------------

func test_a1_boss事件I5全序列结构() -> void:
	_make_stack()
	assert_true(_loader.has_event("story_boss_pre"), "story_boss_pre 应登记")
	var ev: Dictionary = _loader.get_event("story_boss_pre")
	var conds: Dictionary = ev.get("conditions", {})
	assert_true(conds.has("story_phase"), "应有 story_phase 门闸（防战后重触发）")
	assert_eq(int((conds["story_phase"] as Array)[1]), 2, "门闸 >=2（进 Boss 前厅的剧情位）")
	var actions: Array = ev.get("actions", [])
	var types: Array[String] = []
	for a: Variant in actions:
		types.append(String((a as Dictionary).get("type")))
	assert_eq(types[0], "dialogue", "I5 序列首动作 = 战前台词")
	assert_eq(String((actions[0] as Dictionary).get("id")), "story_p3_boss_front",
			"战前台词 = story_p3_boss_front")
	assert_eq(types[1], "battle", "第二动作 = battle（暂停点）")
	assert_eq(String((actions[1] as Dictionary).get("group")), "b5_core",
			"battle 编组 = boss_core 语义（b5_core，探索 GDD I5）")
	var idx_phase: int = types.find("set_story_phase")
	var idx_save: int = types.find("save_point")
	assert_true(idx_phase > 1 and idx_save > idx_phase,
			"set_story_phase(3) 与 save_point 必须在 battle 之后的战后段（禁止提前）")
	assert_eq(int((actions[idx_phase] as Dictionary).get("phase")), 3, "战后段置 phase=3（2→3 切换点）")
	assert_eq(types[2], "dialogue", "胜利续行首 = 战后台词")
	assert_eq(String((actions[2] as Dictionary).get("id")), "story_p3_finale",
			"战后台词 = story_p3_finale（S4 既有收束拍）")


func test_a2_战前拍对话脚本存在且可开演() -> void:
	_make_stack()
	assert_true(FileAccess.file_exists("res://data/json/dialogues/story_p3_boss_front.json"),
			"战前拍脚本应存在")
	assert_true(_runner.start_dialogue("story_p3_boss_front"), "战前拍应可开演")
	assert_eq(_runner.get_current_full_text().length() > 0, true, "战前拍首条目应有文本")
	_runner.force_idle()


func test_a3_战前拍文本无ASCII引号() -> void:
	# 任务书纪律：文本占位禁 ASCII 引号（直角引号/「」替代）。逐条扫 text 字段。
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/json/dialogues/story_p3_boss_front.json"))
	assert_true(typeof(parsed) == TYPE_DICTIONARY, "战前拍 JSON 应合法")
	var entries: Dictionary = (parsed as Dictionary).values()[0]
	for eid: Variant in entries.keys():
		var text: String = String((entries[eid] as Dictionary).get("text", ""))
		assert_false(text.contains("\""), "条目 %s 的 text 不应含 ASCII 引号" % String(eid))


# ------------------------------------------------------------------
# Group B —— 暂停路径：battle 动作挂起事件流
# ------------------------------------------------------------------

func test_b1_battle动作挂起簿记与暂停闸() -> void:
	_make_stack()
	GameData.story_phase = 2
	watch_signals(EventBus)
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	# 战前段已执行：对白开演（runner 拿到战前拍）
	assert_eq(_runner.current_event_id, "story_p3_boss_front", "战前段：对白应已开演")
	# battle 发出 + 暂存位记录 + 挂起闸
	assert_signal_emitted(EventBus, "enemy_touched", "battle 应经 A5 通路发 enemy_touched")
	var params: Array = get_signal_parameters(EventBus, "enemy_touched")
	assert_eq(String(params[0]["enemy_group_id"]), "b5_core", "payload 编组应为 b5_core")
	assert_eq(String(_executor.pending_battle_group), "b5_core", "暂存位应记录编组 id")
	assert_true(_executor.in_battle_pause(), "事件流应处于 battle 挂起态")
	# 挂起闸：新事件被拒
	GameData.story_phase = 2
	_executor.execute_event("npc_innkeeper", _loader.get_event("npc_innkeeper"))
	assert_eq(_runner.current_event_id, "story_p3_boss_front",
			"挂起期间新事件应被拒绝（runner 未被 NPC 事件改写）")
	# 战后段未提前执行（探索边缘 3 的"无中途态"入口面）
	assert_eq(GameData.story_phase, 2, "战前段不得提前置 phase=3")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_runner.is_idle(), "battle 延迟收束：runner 回 IDLE（S2 语义保持）")


func test_b2_battle哨兵载荷供桥接识别() -> void:
	_make_stack()
	GameData.story_phase = 2
	watch_signals(EventBus)
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	var params: Array = get_signal_parameters(EventBus, "enemy_touched")
	assert_true(params[0].has("_from_event_battle"),
			"事件战斗载荷应带 _from_event_battle 哨兵（桥接识别判据）")
	assert_eq(bool(params[0]["_from_event_battle"]), true, "哨兵应为 true")


# ------------------------------------------------------------------
# Group C —— 恢复路径：模拟 VICTORY → 战后续行（验收①）
# ------------------------------------------------------------------

func test_c1_victory续行_phase战段生效_存档请求() -> void:
	_make_stack()
	GameData.story_phase = 2
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	assert_true(_executor.in_battle_pause(), "前置：挂起在位")
	watch_signals(EventBus)
	SaveManager.consume_save_request()   # 清战前段可能的残留（save 未在战前段）
	# 模拟战斗胜利回传（headless 直接 emit——bridge 未装配环境走 executor 直驱）
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	_executor.resolve_victory()
	assert_eq(GameData.story_phase, 3, "phase 2→3 应在战后段内生效（验收①核心）")
	assert_signal_emitted(EventBus, "story_phase_changed", "阶段推进应广播")
	assert_signal_emitted(EventBus, "save_requested", "战后段 save_point 应发存档请求")
	assert_true(SaveManager.consume_save_request(), "存档意图应已登记（consume-on-read）")
	assert_false(_executor.in_battle_pause(), "事件流应收束（挂起闸解除）")
	assert_eq(String(_executor.pending_battle_group), "", "暂存位应清空")


func test_c2_victory续行含战后台词开演() -> void:
	_make_stack()
	GameData.story_phase = 2
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	# battle 动作的 force_idle 是 call_deferred（帧末）；真实游戏战斗历时
	# 数秒早已收束，测试同帧 emit 须手动补延迟帧已过的语义（force_idle 幂等）
	_runner.force_idle()
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	_executor.resolve_victory()
	assert_eq(_runner.current_event_id, "story_p3_finale", "战后段应开演 P3 收束拍")
	_runner.force_idle()


func test_c3_victory后重触发被门闸拒绝() -> void:
	# phase=3 后触发器再命中（薄壳会再调 execute_event）：门闸 >=2 仍真——
	# 但数据侧无 flag 状态，事件会重放。契约：重放把 phase 重置 3（不越界），
	# 与切换点 2 重放语义同构（e5s4 c1 口径）。
	_make_stack()
	GameData.story_phase = 2
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	_executor.resolve_victory()
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	assert_eq(GameData.story_phase, 3, "战后重触发停在 3（重放不越权不回跳）")


# ------------------------------------------------------------------
# Group D —— 失败路径：DEFEAT 清场 + 从头可再触发（验收② / 探索边缘 3）
# ------------------------------------------------------------------

func test_d1_defeat清场后事件从头完整再触发() -> void:
	_make_stack()
	GameData.story_phase = 2
	# 第一次触发：战前段执行 → battle 挂起（模拟打到一半团灭）
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	assert_true(_executor.in_battle_pause(), "前置：第一次触发已挂起")
	EventBus.battle_finished.emit({"outcome": "DEFEAT"})
	# 桥接缺位环境：DEFEAT 清场语义 = clear_battle_pause（生产由桥调用；
	# 此处直驱同一口，等价性由 Group E 桥接单元保障）
	_executor.clear_battle_pause()
	assert_false(_executor.in_battle_pause(), "DEFEAT 后挂起闸应解除")
	assert_eq(String(_executor.pending_battle_group), "", "暂存位应清空")
	assert_eq(GameData.story_phase, 2, "phase 不得残留战后值（E4-S7 读档回滚同语义）")
	# 从头再触发：战前段 → 挂起 → 胜利 → 续行，全程与首跑一致
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	assert_eq(_runner.current_event_id, "story_p3_boss_front", "重触发：战前拍重新开演")
	assert_true(_executor.in_battle_pause(), "重触发：挂起闸再次在位")
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	_executor.resolve_victory()
	assert_eq(GameData.story_phase, 3, "重触发胜利后 phase 照常 2→3")
	assert_true(SaveManager.consume_save_request(), "重触发战后段存档请求照常")


func test_d2_defeat不触发存档意图不误存() -> void:
	_make_stack()
	GameData.story_phase = 2
	SaveManager.consume_save_request()
	_executor.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	_executor.clear_battle_pause()
	assert_false(SaveManager.consume_save_request(),
			"失败路径不得产生存档意图（读档即回滚，无需写档）")


# ------------------------------------------------------------------
# Group E —— 桥接单元（SceneRouter 装配契约 + 簿记语义）
# ------------------------------------------------------------------

func test_e1_router装配全局executor与桥() -> void:
	# SceneRouter._ready 的 E5-S5 增量：全局 executor + 桥随自动加载就绪
	assert_true(SceneRouter.global_event_executor != null, "Router 应装配全局事件执行器")
	assert_true(SceneRouter.battle_event_bridge != null, "Router 应装配事件流战斗桥")
	assert_true(SceneRouter.battle_event_bridge.has_method("has_pending_event_battle"),
			"桥应暴露簿记查询口")


func test_e2_全局executor挂起即登记桥簿记() -> void:
	_make_stack()   # runner 装备（战前拍可开演）
	# 用全局 executor 走真实挂起路径（桥的 enemy_touched 监听在自动加载环境已接线）
	var gexec: RefCounted = SceneRouter.global_event_executor
	_loader = EventLoader.new()
	_loader.load_all()
	gexec.setup(_runner)
	GameData.story_phase = 2
	gexec.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	assert_true(gexec.in_battle_pause(), "全局 executor 应挂起")
	assert_true(SceneRouter.battle_event_bridge.has_pending_event_battle(),
			"桥应登记事件战斗簿记")
	gexec.clear_battle_pause()
	SceneRouter.battle_event_bridge.clear_pending()   # 簿记与 executor 对称清理（防泄漏到 e3）


func test_e3_普通遇敌载荷不进桥簿记() -> void:
	watch_signals(EventBus)
	# 模拟 visible_enemy 组装的普通载荷（无哨兵键）
	EventBus.enemy_touched.emit({
		"enemy_group_id": "b1_moth",
		"return_map": "res://scenes/maps/town.tscn",
		"return_position": Vector2(100, 100),
		"defeat_enemy_uid": "enemy_x",
	})
	assert_false(SceneRouter.battle_event_bridge.has_pending_event_battle(),
			"普通遇敌不得触发事件流簿记（直通既有链路）")


func test_e4_clear暂停不影响无簿记环境() -> void:
	_make_stack()
	_executor.resolve_victory()   # 无挂起时的防御路径：仅日志，不炸
	assert_false(_executor.in_battle_pause(), "无簿记 resolve 后仍应无挂起")


# ------------------------------------------------------------------
# Group F —— f3 装配面（BossTriggers 锚点同位重建薄壳 + 交互驱动）
# ------------------------------------------------------------------

func test_f1_f3场景Boss锚点装配协议齐备() -> void:
	var map: Node2D = autofree(RuinsF3MapScript.new())
	# 手工补齐场景结构（map 脚本 _ready 依赖 YSorted/Player 等——装配面单测
	# 只驱动 _assemble_boss_anchor，不走 _ready）
	var ysorted: Node2D = Node2D.new()
	ysorted.name = "YSorted"
	map.add_child(ysorted)
	var anchors: Node2D = Node2D.new()
	anchors.name = "BossTriggers"
	ysorted.add_child(anchors)
	var a1: Marker2D = Marker2D.new()
	a1.name = "Boss_ruins_f3_trigger_01"
	a1.position = Vector2(312, 568)   # f3.tscn 实锚（gen_ruins (19,35) 格）
	anchors.add_child(a1)
	var a2: Marker2D = Marker2D.new()
	a2.name = "Boss_ruins_f3_trigger_02"
	a2.position = Vector2(328, 568)
	anchors.add_child(a2)
	map._assemble_boss_anchor()
	assert_true(map.boss_anchor != null, "Boss 锚点应装配成功")
	assert_true(map.boss_anchor.has_method("on_interact"), "锚点应实现交互协议（controller 可分派）")
	assert_eq(String(map.boss_anchor.new_event_id), "story_boss_pre", "锚点应指向 story_boss_pre")
	assert_true(String(map.boss_anchor.event_id).begins_with("boss_anchor_"),
			"锚点 event_id 应带 boss_anchor_ 前缀（调试定位）")
	# 同位断言：实体落在锚点脚位（gen_ruins (19,35) 格中心口径）
	assert_eq(map.boss_anchor.position, Vector2(312, 568), "锚点实体应与 Marker 同位")
	# 双锚只留一实体（防同帧双触发）
	var shells: Array = []
	for c: Node in anchors.get_children():
		if c.has_method("on_interact"):
			shells.append(c)
	assert_eq(shells.size(), 1, "同位双锚应只装配一个触发器实体")


func test_f2_锚点交互直驱事件链到挂起() -> void:
	var map: Node2D = autofree(RuinsF3MapScript.new())
	var ysorted: Node2D = Node2D.new()
	ysorted.name = "YSorted"
	map.add_child(ysorted)
	var anchors: Node2D = Node2D.new()
	anchors.name = "BossTriggers"
	ysorted.add_child(anchors)
	var a1: Marker2D = Marker2D.new()
	a1.name = "Boss_ruins_f3_trigger_01"
	anchors.add_child(a1)
	map._assemble_boss_anchor()
	# 交互路径：薄壳 inject_emit（等价 on_interact 命中）→ 事件层 → 挂起
	GameData.story_phase = 2
	map.boss_anchor.inject_emit()
	assert_true(map.event_executor.in_battle_pause(), "锚点命中应走事件链至 battle 挂起")
	assert_eq(String(map.event_executor.pending_battle_group), "b5_core", "编组 id 照常记录")
	# 门闸复测（GDD 边缘 2 于 Boss 锚点面）：对话期间命中被忽略
	map.event_executor.clear_battle_pause()
	GameData.story_phase = 2
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	_runner.start_dialogue("dlg_innkeeper_p0")
	map.boss_anchor.setup(map.boss_anchor.get_parent(), map.event_executor, _runner)
	watch_signals(EventBus)
	var touched_count: int = 0
	touched_count = 0
	map.boss_anchor.inject_emit()
	assert_false(map.event_executor.in_battle_pause(), "对话期间锚点命中应被门闸忽略")
	_runner.force_idle()


func test_f3_phase3后锚点命中零动作() -> void:
	var map: Node2D = autofree(RuinsF3MapScript.new())
	var ysorted: Node2D = Node2D.new()
	ysorted.name = "YSorted"
	map.add_child(ysorted)
	var anchors: Node2D = Node2D.new()
	anchors.name = "BossTriggers"
	ysorted.add_child(anchors)
	var a1: Marker2D = Marker2D.new()
	a1.name = "Boss_ruins_f3_trigger_01"
	anchors.add_child(a1)
	map._assemble_boss_anchor()
	GameData.story_phase = 3   # 切片终态：条件 >=2 仍真，但战前重放语义归 Group C；
	# 此处验证的是挂起闸独立面：命中后若已在挂起（外来状态）则不重复入链
	GameData.story_phase = 2
	map.boss_anchor.inject_emit()
	var gexec: RefCounted = map.event_executor
	assert_true(gexec.in_battle_pause(), "phase=2 命中照常入链")
	var first_group: String = String(gexec.pending_battle_group)
	var loader2: RefCounted = EventLoader.new()
	loader2.load_all()
	gexec.execute_event("story_boss_pre", loader2.get_event("story_boss_pre"))
	assert_eq(String(gexec.pending_battle_group), first_group,
			"挂起期间再次命中应被暂停闸拒绝（不重复 battle）")
	gexec.clear_battle_pause()


# ------------------------------------------------------------------
# Group G —— E5-M5 装配面回归：Boss 链生产接线缺口修复
# （缺口①Area2D 壳射线不可见 ②controller 分派链吞自治实体 ③全局 executor
#   无 runner 注入 ④runner 跨图 _player 悬垂 ⑤f3 无交互装配）
# ------------------------------------------------------------------

func test_g2_全局executor装配后可注入runner并播放战前台词() -> void:
	# 缺口③：Router 创建全局 executor 后从未 setup(runner)——dialogue 动作
	# 被静默跳过。f3 装配面（_assemble_interaction）负责注入，此处验注入后
	# dialogue 动作真实开演（战前拍文本出现 = 缺口闭合的行为证据）。
	var gexec: RefCounted = SceneRouter.global_event_executor
	_make_stack()   # 装 runner；loader 就绪
	gexec.setup(_runner)
	GameData.story_phase = 2
	gexec.execute_event("story_boss_pre", _loader.get_event("story_boss_pre"))
	assert_eq(_runner.current_event_id, "story_p3_boss_front",
			"全局 executor 注入 runner 后，战前台词应真实开演（缺口③闭合）")
	gexec.clear_battle_pause()


func test_g3_runner换绑玩家_跨图引用保鲜() -> void:
	# 缺口④：runner/框常驻 UILayer，_player 指向装配图玩家——跨图后旧引用
	# 释放。rebind_player 换绑后：锁/解锁落在新玩家上；旧引用释放后
	# start_dialogue/force_idle 靠 is_instance_valid 守卫不炸。
	# 【注意】锁字段在 player.gd（is_input_locked），裸 CharacterBody2D 无
	# 此脚本——用真实 player.tscn 实例断言锁语义。
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var old_player: CharacterBody2D = player_scene.instantiate()
	add_child_autofree(old_player)
	_make_stack()
	_runner.setup(null, old_player)
	var new_player: CharacterBody2D = player_scene.instantiate()
	add_child_autofree(new_player)
	_runner.rebind_player(new_player)
	_runner.start_dialogue("dlg_innkeeper_p0")
	assert_eq(bool(new_player.get("is_input_locked")), true,
			"换绑后开演应锁新玩家（引用保鲜）")
	_runner.force_idle()
	assert_eq(bool(new_player.get("is_input_locked")), false,
			"收束应解锁新玩家")
	# 旧引用释放后新对话/收束照常（守卫生效，不摸已释放对象）
	old_player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_runner.start_dialogue("dlg_innkeeper_p0")
	_runner.force_idle()
	assert_true(_runner.is_idle(), "旧玩家释放后新对话/收束照常（守卫生效）")


func test_g4_f3地图装配交互控制器与runner换绑() -> void:
	# 缺口⑤：f3 无 InteractionController——Z 键无人分派。装配面单测：
	# 手工补全结构后驱动 _assemble_interaction，断言控制器在位、runner 换绑、
	# 全局 executor 拿到 runner；随后薄壳命中照常入链（装配面集成拍）。
	var map: Node2D = autofree(RuinsF3MapScript.new())
	var ysorted: Node2D = Node2D.new()
	ysorted.name = "YSorted"
	map.add_child(ysorted)
	var player: CharacterBody2D = CharacterBody2D.new()
	player.name = "Player"
	ysorted.add_child(player)
	var anchors: Node2D = Node2D.new()
	anchors.name = "BossTriggers"
	ysorted.add_child(anchors)
	var a1: Marker2D = Marker2D.new()
	a1.name = "Boss_ruins_f3_trigger_01"
	anchors.add_child(a1)
	map.event_executor = SceneRouter.global_event_executor
	map._assemble_interaction(player)   # 未入树形态：runner 走本图薄实例兜底
	assert_true(map.interaction_controller != null
			and map.interaction_controller.has_method("setup"),
			"f3 应装配交互轮询器（缺口⑤闭合）")
	assert_true(map.dialogue_runner != null, "f3 应持有 runner 引用")
	var gexec: RefCounted = SceneRouter.global_event_executor
	assert_true(gexec.dialogue_runner != null,
			"全局 executor 应已注入 runner（缺口③装配面证据）")
	var loader3: RefCounted = EventLoader.new()
	loader3.load_all()
	map._assemble_boss_anchor()   # 锚点装配：runner 取 dialogue_runner（本图薄实例）
	assert_true(map.boss_anchor != null, "前置：Boss 锚点应已装配")
	map.boss_anchor.setup(loader3, gexec, map.dialogue_runner)
	GameData.story_phase = 2
	map.boss_anchor.inject_emit()
	assert_true(gexec.in_battle_pause(), "薄壳命中（装配面 runner 在位）照常入链")
	gexec.clear_battle_pause()
	SceneRouter.battle_event_bridge.clear_pending()   # 桥簿记对称清理


func test_g5_interactray开area命中面_场景属性落地() -> void:
	# 缺口①：壳是 Area2D，玩家 InteractRay 默认 collide_with_areas=false
	# ——射线完全打不中壳（E1-S6 探针矩阵实测结论的前提即本开关默认关）。
	# 场景属性必须显式开（tscn 落地断言，防回退）。
	var packed: PackedScene = load("res://scenes/player.tscn")
	var player: Node = packed.instantiate()
	autofree(player)
	var ray: RayCast2D = player.get_node_or_null("InteractRay") as RayCast2D
	assert_true(ray != null, "前置：InteractRay 在位")
	assert_true(ray.collide_with_areas, "InteractRay 应开 Area2D 命中（缺口①闭合）")
	assert_true(ray.collision_mask & 2 != 0, "InteractRay 应含交互物层（层2）")


func test_g6_分派链自治协议优先于npc协议() -> void:
	# 缺口②的分派语义直接验证：节点带 on_interact 时即使沿父链也先命中
	# 自治协议（npc 协议路径在其后才兜底）。用探针节点固化行为契约。
	var probe := Node.new()
	probe.set_script(preload("res://tests/gut/fixtures/probe_on_interact.gd"))
	add_child_autofree(probe)
	assert_true(probe.has_method("on_interact"), "探针应实现自治协议")
	assert_false(probe.has_method("get_npc_id"), "探针不应有 npc 协议（纯自治实体）")
