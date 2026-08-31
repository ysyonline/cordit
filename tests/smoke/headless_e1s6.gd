extends Node
## E1-S6 无头自验脚本（交付自检用，非正式 SMK 用例；headless 跑法，不进构建）
##
## 用法：Godot_console.exe --headless --path <项目根> res://tests/smoke/headless_e1s6.tscn
## 退出码：0 = 全 PASS；1 = 任一 FAIL。
##
## 断言口径（E1-S6 三条验收的可自动化部分 + 数据驱动专项；写法沿 headless_e1s4.gd：
## wrapper 直挂 + 判定式断言非只打印）：
##   ① 交互触发：模拟玩家面向 NPC 按 Z（InputEventAction 注入，探针已验证
##      headless 下 is_action_pressed 判定链路可用）→ 状态机进 PLAYING
##      且玩家移动被锁（注入移动输入后 1s 位移为 0）；
##   ② 逐字推进与按键补完：短窗口观察 visible_text 增长（30 字/s），
##      注入 interact → 本条剩余字符一次补完；
##   ③ 对话结束回 IDLE + emit dialogue_finished（参数 = npc_id，与 JSON
##      文件名/锚点名三重对齐，无额外前缀）；
##   ④ 内容来自 JSON：改写临时 JSON 文本（text 替换为哨兵串）→ 重新触发对话
##      → 全文断言跟随变化（改回后复测），证明零硬编码。
## 留人工：对话框视觉（面板/名字栏/折行）、手感、逐字观感（带渲染轮代目验）。

const TOWN_SCENE := preload("res://scenes/maps/town.tscn")
const GUARD_NPC_ID := "npc_04_guard"
# guard 锚点 (504,440) = tile(31,27) 中心；玩家站东侧 1 格 tile(32,27)=(520,440)，
# 面西射线 20px（胸口 y=430）落入 InteractShape（x∈[496,512] y∈[424,440]）。
const GUARD_FACE_TILE := Vector2i(32, 27)
const SENTINEL_TEXT := "哨兵文本：JSON 数据驱动验证 E1S6"

var _map: Node2D = null
var _player: CharacterBody2D = null
var _received_event_id: String = ""
var _received_count: int = 0
var _fail_count := 0


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	# town 由 wrapper 挂在 Main/World 下（Router 整层替换路径），按此定位
	var world: Node = get_tree().root.get_node_or_null("Main/World")
	_map = null
	if world != null:
		for child in world.get_children():
			if String(child.name) == "Map_Town":
				_map = child as Node2D
				break
	if _map == null:
		print("[E1S6] FATAL: 找不到 Map_Town。World 子节点：")
		if world != null:
			for child in world.get_children():
				print("  - %s (%s)" % [child.name, child.get_class()])
		get_tree().quit(1)
		return
	_player = _map.get_node("YSorted/Player") as CharacterBody2D
	# dialogue_finished 捕获（SMK-02/03 同款签名：String 单参）
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	# 核心链路顺序执行
	await _check_interact_triggers_and_locks()
	await _check_typewriter_and_advance()
	await _check_finish_and_signal()
	await _check_json_driven()
	# 复跑 E1-S5 三条关键回归（同进程内证明零破坏）
	await _rerun_e1s5_regression()
	if _fail_count == 0:
		print("[E1S6] 汇总：5/5 PASS")
	else:
		print("[E1S6] 汇总：%d 项 FAIL" % _fail_count)
	_cleanup_ui()
	get_tree().quit(0 if _fail_count == 0 else 1)


# ------------------------------------------------------------------
# 断言 ① 交互触发 + 移动锁
# ------------------------------------------------------------------

## 把玩家放到 guard 东侧 1 格并面朝西（射线 20px 覆盖面前 1 格）。
## 朝向重建时序（生产路径等价：移动键定朝向 → 0.15s 缓冲期内按键交互）：
##   set_input_override(LEFT) → 2 物理帧（_update_facing 生效）→ 松键当帧
##   （facing 仍 =LEFT，缓冲计时中）→ 调用方立刻注入交互键。
## 注意：此后任何 create_timer 等待超 0.15s 都会让 facing 复位为 DOWN——
##   本函数不承担"保持朝向"职责，交互注入必须由调用方紧随其后执行。
func _place_player_facing_guard() -> void:
	_player.position = Vector2(GUARD_FACE_TILE) * 16.0 + Vector2(8, 8)
	_player.velocity = Vector2.ZERO
	_player.set_input_override(Vector2.LEFT)  # 面朝西（朝 NPC）
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player.set_input_override(Vector2.ZERO)
	await get_tree().physics_frame  # 松键当帧，缓冲期内 facing=LEFT，供立即注入


func _check_interact_triggers_and_locks() -> void:
	# 玩家站 guard 东侧 1 格面朝西（站位 + 朝向重建 + 缓冲期内注入交互，
	# 生产时序：移动键定朝向 → 0.15s 内按 Z）
	await _place_player_facing_guard()
	var controller: Node = _map.interaction_controller
	var runner: Node = _map.dialogue_runner
	if controller == null or runner == null:
		_fail("A1", "装配缺失：controller=%s runner=%s" % [controller, runner])
		return
	controller.inject_interact()
	await get_tree().physics_frame
	var playing: bool = runner.state == runner.State.PLAYING
	var pos_before_lock: Vector2 = _player.position
	if not playing:
		# 诊断：射线为何没命中
		var target: Object = _player.get_interact_target()
		print("[E1S6-A1] 诊断：玩家位置=%s facing=%s 射线目标=%s" % [
				_player.position, _player.facing, target])
	var box_visible: bool = false
	for child in get_tree().root.get_node_or_null("Main/UILayer").get_children():
		if child.has_method("set_text"):
			box_visible = child.visible
	if not playing:
		_fail("A1", "按 Z 后状态机未进 PLAYING（当前 %s）" % runner.state)
		return
	if not box_visible:
		_fail("A1", "对话框未显示")
	# 移动锁：锁定态下注入 RIGHT 输入 1s，位移必须为 0
	# （基准 = 注入交互瞬间的实际落点：站位函数注入方向键 2 帧会有 ~2px
	#   行走漂移，属预期，不参与锁判定）
	_player.set_input_override(Vector2.RIGHT)
	await get_tree().create_timer(1.0).timeout
	_player.set_input_override(Vector2.ZERO)
	var disp: float = (_player.get_last_frame_displacement()).length()
	var pos_locked: bool = _player.position.distance_to(pos_before_lock) < 0.5
	_pass_cond(playing and box_visible and pos_locked and disp < 0.5, "A1",
			"按 Z 触发对话：PLAYING + 框显示 + 锁定态 1s 位移 %.2fpx" % disp)


# ------------------------------------------------------------------
# 断言 ② 逐字 + 补完
# ------------------------------------------------------------------

func _check_typewriter_and_advance() -> void:
	var runner: Node = _map.dialogue_runner
	# 新对话已在 ① 中开演；补完上一条，翻到下一条再测逐字（保证观察窗干净）
	runner.inject_interact_press()  # 补完 start 条
	await get_tree().process_frame
	runner.inject_interact_press()  # 翻到 warn 条
	await get_tree().process_frame
	var before: int = runner.get_visible_text().length()
	await get_tree().create_timer(0.5).timeout
	var after: int = runner.get_visible_text().length()
	# 0.5s × 30字/s = 15 字（帧抖动容差 ±6 字）
	_pass_cond(after > before and after - before >= 9 and after - before <= 21, "A2",
			"逐字推进：0.5s 内 %d → %d 字（30字/s ±容差）" % [before, after])
	# 按键补完：注入一次 → visible == 全文
	runner.inject_interact_press()
	await get_tree().process_frame
	var full: String = runner.get_current_full_text()
	_pass_cond(runner.get_visible_text() == full, "A2b",
			"按键补完：visible(%d) == 全文(%d)" % [runner.get_visible_text().length(), full.length()])


# ------------------------------------------------------------------
# 断言 ③ 结束回 IDLE + dialogue_finished
# ------------------------------------------------------------------

func _check_finish_and_signal() -> void:
	var runner: Node = _map.dialogue_runner
	_received_count = 0
	_received_event_id = ""
	# 当前在 warn 条已完成态：再按一次 = 翻页到 END → 收束
	runner.inject_interact_press()
	await get_tree().process_frame
	await get_tree().process_frame
	var idle: bool = runner.is_idle()
	var box_closed: bool = true
	for child in get_tree().root.get_node_or_null("Main/UILayer").get_children():
		if child.has_method("set_text"):
			box_closed = not child.visible
	var sig_ok: bool = _received_count == 1 and _received_event_id == GUARD_NPC_ID
	_pass_cond(idle and box_closed and sig_ok, "A3",
			"收束：IDLE=%s 框关=%s dialogue_finished(1次)=\"%s\"" % [idle, box_closed, _received_event_id])
	# 解锁后移动恢复：注入 RIGHT 0.5s，位移必须 > 0
	_player.set_input_override(Vector2.RIGHT)
	await get_tree().create_timer(0.5).timeout
	_player.set_input_override(Vector2.ZERO)
	var disp: float = _player.get_last_frame_displacement().length()
	var moved: bool = _player.position.distance_to(
			Vector2(GUARD_FACE_TILE) * 16.0 + Vector2(8, 8)) > 4.0
	_pass_cond(moved, "A3b", "解锁后移动恢复（0.5s 注入已离开原位，末帧位移 %.2fpx）" % disp)


# ------------------------------------------------------------------
# 断言 ④ 数据驱动：改 JSON 文本断言跟随
# ------------------------------------------------------------------

func _check_json_driven() -> void:
	var path: String = "res://data/json/dialogues/%s.json" % GUARD_NPC_ID
	# 读原文（ResourceLoader 在编辑器管线内直接读 res:// 文本）
	var original: String = FileAccess.get_file_as_string(path)
	var parsed: Dictionary = JSON.parse_string(original)
	# 定位脚本 id（顶层唯一键）并替换 start 条 text 为哨兵串
	var script_key: String = parsed.keys()[0]
	var original_text: String = parsed[script_key]["start"]["text"]
	parsed[script_key]["start"]["text"] = SENTINEL_TEXT
	var modified := JSON.stringify(parsed, "  ")
	# 写回（headless 下 res:// 即项目目录，可直接写）
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(modified)
	f.close()
	# 重新触发对话（站位 + 朝向重建 + 缓冲期内注入，同 A1 时序）
	await _place_player_facing_guard()
	_map.interaction_controller.inject_interact()
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout  # 等 0.4s 哨兵串(14字)应已逐字显示 12 字
	var got: String = _map.dialogue_runner.get_current_full_text()
	var data_ok: bool = got == SENTINEL_TEXT
	# 收束对话（start → warn 共 2 条：补完 + 翻页 ×2 后到达 END；多按一次
	# 属 IDLE 态空按，runner 静默忽略——按键 4 次确保回 IDLE，恢复干净状态）
	for i in range(4):
		_map.dialogue_runner.inject_interact_press()
		await get_tree().process_frame
	await get_tree().process_frame
	# 复原 JSON（写回原文）并复测加载原文成功
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_string(original)
	f2.close()
	await _place_player_facing_guard()
	_map.interaction_controller.inject_interact()
	await get_tree().process_frame
	var restored: String = _map.dialogue_runner.get_current_full_text()
	var restore_ok: bool = restored == original_text
	# 收束（还原干净状态供后续回归；同上 4 次按键确保回 IDLE）
	for i in range(4):
		_map.dialogue_runner.inject_interact_press()
		await get_tree().process_frame
	await get_tree().process_frame
	_pass_cond(data_ok and restore_ok, "A4",
			"数据驱动：JSON 改文后全文=\"%s\"；复原后=\"%s…\"" % [got, restored.substr(0, 10)])


# ------------------------------------------------------------------
# E1-S5 回归复跑（同进程；证对话装配零破坏已验收行为）
# ------------------------------------------------------------------

func _rerun_e1s5_regression() -> void:
	# A3 锚点 12 个：坐标与验收表逐一相符（±0.5px）——NPC 实体是 YSorted 新增
	# 子节点，不触碰锚点；断言防"装配误删/误移锚点"。
	var anchors: Node = _map.get_node("YSorted/NPC_Anchors")
	var expected := {
		"npc_01_innkeeper": Vector2(488, 296), "npc_02_traveler": Vector2(1368, 248),
		"npc_03_chase_kid": Vector2(376, 488), "npc_04_guard": Vector2(504, 440),
		"npc_05_smith": Vector2(712, 296), "npc_06_peddler": Vector2(232, 328),
		"npc_07_priest": Vector2(392, 152), "npc_08_prayer_woman": Vector2(520, 136),
		"npc_09_shepherd": Vector2(840, 296), "npc_10_housewife": Vector2(264, 568),
		"npc_11_porter": Vector2(808, 552), "npc_12_elder": Vector2(200, 392),
	}
	var bad: Array = []
	for npc_name in expected:
		var m: Marker2D = anchors.get_node_or_null(npc_name) as Marker2D
		if m == null or m.position.distance_to(expected[npc_name]) > 0.5:
			bad.append(npc_name)
	_pass_cond(bad.is_empty(), "R-A3", "E1S5-A3 回归：12 锚点全对表" if bad.is_empty() else "漂移:%s" % [bad])
	# NPC 实体在位：2 个，脚底位与锚点重合
	var in_place := 0
	for npc_name in ["npc_01_innkeeper", "npc_04_guard"]:
		var e: StaticBody2D = _map.get_node_or_null("YSorted/" + npc_name + "_entity") as StaticBody2D
		var a: Marker2D = anchors.get_node_or_null(npc_name) as Marker2D
		if e != null and a != null and e.position.distance_to(a.position) < 0.5:
			in_place += 1
	_pass_cond(in_place == 2, "R-NPC", "NPC 实体 2/2 摆位与锚点重合（脚底原点）")
	# 门传送抽测：客栈门进出往返（E1S5-A1 同口径；E4-S6 起节点由装配器
	# 目录驱动重建为 Evt_tp_town_door_inn / Evt_tp_town_inn_exit）
	var player: CharacterBody2D = _player
	var trig: Area2D = _map.get_node("Triggers/Evt_tp_town_door_inn") as Area2D
	player.position = trig.position
	player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.3).timeout
	var want_in: Vector2 = Vector2(85, 17) * 16.0 + Vector2(8, 8)
	var door_in_ok: bool = player.position.distance_to(want_in) < 2.0
	# 出门
	var trig_out: Area2D = _map.get_node("Triggers/Evt_tp_town_inn_exit") as Area2D
	player.position = trig_out.position
	player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.3).timeout
	var want_out: Vector2 = Vector2(29, 19) * 16.0 + Vector2(8, 8)
	var door_out_ok: bool = player.position.distance_to(want_out) < 2.0
	_pass_cond(door_in_ok and door_out_ok, "R-A1", "E1S5-A1 回归：Door_Inn 进出往返正常")


# ------------------------------------------------------------------
# 工具
# ------------------------------------------------------------------

func _on_dialogue_finished(event_id: String) -> void:
	_received_count += 1
	_received_event_id = event_id


func _pass_cond(ok: bool, tag: String, detail: String) -> void:
	if ok:
		print("[E1S6-%s] PASS: %s" % [tag, detail])
	else:
		_fail_count += 1
		print("[E1S6-%s] FAIL: %s" % [tag, detail])


func _fail(tag: String, detail: String) -> void:
	_fail_count += 1
	print("[E1S6-%s] FAIL: %s" % [tag, detail])


## 清理常驻层上的对话框/runner（Wrapper 模式下由本测试负责，防泄漏到后续用例）
func _cleanup_ui() -> void:
	var ui: Node = get_tree().root.get_node_or_null("Main/UILayer")
	if ui == null:
		return
	for child in ui.get_children():
		if child.has_meta("temp_dialogue_box") or String(child.name) == "DialogueRunner":
			child.queue_free()
