extends Node
## SMK-01~04 无头自动化冒烟脚本（headless 跑法，不进构建）
##
## 用法：
##   Godot_console.exe --headless --path <项目根> res://tests/smoke/headless_smk.tscn
## 退出码：0 = 全 PASS；1 = 任一 FAIL。
## 证据：输出面板逐行含 [SMK-xx] 前缀，由调用方 tee 落盘 tests/smoke/evidence/。

var _recv_enemy: Variant = null
var _recv_dialogue: Variant = null
var _recv_battle: Variant = null
var _recv_phase: Variant = null
var _recv_save: bool = false
var _recv_map: Variant = null


func _ready() -> void:
	var results: Array = [
		_check_smk01(),
		_check_smk02(),
		_check_smk03(),
		_check_smk04(),
	]
	var pass_count := results.count(true)
	print("[SMK] 汇总：%d/4 PASS" % pass_count)
	get_tree().quit(0 if pass_count == 4 else 1)


## SMK-01 四 Autoload 注册生效（root 下除本测试场景外恰好 4 个单例节点）
func _check_smk01() -> bool:
	var expected := ["GameData", "EventBus", "SceneRouter", "SaveManager"]
	var found: Array[String] = []
	for child in get_tree().root.get_children():
		if child != self:
			found.append(String(child.name))
	if found.size() != 4:
		print("[SMK-01] FAIL: root 下非测试节点数 = %d（应为 4）: %s" % [found.size(), found])
		return false
	for n in expected:
		if not n in found:
			print("[SMK-01] FAIL: 缺少单例 %s" % n)
			return false
	print("[SMK-01] PASS: 四 Autoload 注册生效，root 单例 = %s" % [found])
	return true


## SMK-02 EventBus 六信号声明齐全、参数数一致、无多余
func _check_smk02() -> bool:
	# 预期：信号名 -> 参数个数（save_requested 无参）
	var expected := {
		"enemy_touched": 1, "dialogue_finished": 1, "battle_finished": 1,
		"story_phase_changed": 1, "save_requested": 0, "map_ready": 1}
	# 用脚本级信号列表（过滤 Node 继承信号），核对"恰好六个"
	var sig_list: Array = EventBus.get_script().get_script_signal_list()
	var actual := {}
	for s in sig_list:
		actual[s["name"]] = (s["args"] as Array).size()
	if actual.size() != expected.size():
		print("[SMK-02] FAIL: 声明信号数 = %d（应为 6）: %s" % [actual.size(), actual.keys()])
		return false
	for k: String in expected:
		if not actual.has(k):
			print("[SMK-02] FAIL: 缺少信号 %s" % k)
			return false
		if actual[k] != expected[k]:
			print("[SMK-02] FAIL: %s 参数数 = %d（应为 %d）" % [k, actual[k], expected[k]])
			return false
	print("[SMK-02] PASS: 六信号齐全且参数一致 -> %s" % [actual.keys()])
	return true


## SMK-03 六信号可 connect（连接返回值全部 OK，无 unknown signal / cannot connect）
func _check_smk03() -> bool:
	var errors: Array[String] = []
	if EventBus.enemy_touched.connect(_on_enemy_touched) != OK:
		errors.append("enemy_touched")
	if EventBus.dialogue_finished.connect(_on_dialogue_finished) != OK:
		errors.append("dialogue_finished")
	if EventBus.battle_finished.connect(_on_battle_finished) != OK:
		errors.append("battle_finished")
	if EventBus.story_phase_changed.connect(_on_story_phase_changed) != OK:
		errors.append("story_phase_changed")
	if EventBus.save_requested.connect(_on_save_requested) != OK:
		errors.append("save_requested")
	if EventBus.map_ready.connect(_on_map_ready) != OK:
		errors.append("map_ready")
	if not errors.is_empty():
		print("[SMK-03] FAIL: connect 失败 -> %s" % [errors])
		return false
	print("[SMK-03] PASS: 六信号全部 connect 成功")
	return true


## SMK-04 emit 参数原样送达（逐字段核对，含 Vector2 与 int 类型）
func _check_smk04() -> bool:
	var sent := {
		"enemy_group_id": "slime_01", "return_map": "res://scenes/maps/road.tscn",
		"return_position": Vector2(64, 32), "defeat_enemy_uid": "enemy_road_01"}
	EventBus.enemy_touched.emit(sent)
	EventBus.dialogue_finished.emit("evt_test_01")
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	EventBus.story_phase_changed.emit(1)
	EventBus.save_requested.emit()
	EventBus.map_ready.emit("town")

	var fails: Array[String] = []
	if _recv_enemy == null or (_recv_enemy as Dictionary) != sent:
		fails.append("enemy_touched payload 不一致: %s" % [_recv_enemy])
	elif (_recv_enemy as Dictionary)["return_position"] != Vector2(64, 32):
		fails.append("return_position 非 Vector2(64, 32)")
	if _recv_dialogue != "evt_test_01":
		fails.append("dialogue_finished 收到 %s" % [_recv_dialogue])
	if _recv_battle == null or (_recv_battle as Dictionary).get("outcome") != "VICTORY":
		fails.append("battle_finished 收到 %s" % [_recv_battle])
	if typeof(_recv_phase) != TYPE_INT or _recv_phase != 1:
		fails.append("story_phase_changed 收到 %s（类型 %d，应为 int 1）" % [_recv_phase, typeof(_recv_phase)])
	if not _recv_save:
		fails.append("save_requested 无参回调未触发")
	if _recv_map != "town":
		fails.append("map_ready 收到 %s" % [_recv_map])
	if not fails.is_empty():
		for f in fails:
			print("[SMK-04] FAIL: %s" % f)
		return false
	print("[SMK-04] PASS: 六信号参数原样送达（字典逐字段含 Vector2、int 1、无参回调均命中）")
	return true


# --- 回调（SMK-03 连接 / SMK-04 捕获）---
func _on_enemy_touched(p: Dictionary) -> void:
	_recv_enemy = p
	print("[SMK-03] enemy_touched 收到: ", p)

func _on_dialogue_finished(id: String) -> void:
	_recv_dialogue = id
	print("[SMK-03] dialogue_finished 收到: ", id)

func _on_battle_finished(r: Dictionary) -> void:
	_recv_battle = r
	print("[SMK-03] battle_finished 收到: ", r)

func _on_story_phase_changed(n: int) -> void:
	_recv_phase = n
	print("[SMK-03] story_phase_changed 收到: ", n)

func _on_save_requested() -> void:
	_recv_save = true
	print("[SMK-03] save_requested 收到（无参）")

func _on_map_ready(m: String) -> void:
	_recv_map = m
	print("[SMK-03] map_ready 收到: ", m)
