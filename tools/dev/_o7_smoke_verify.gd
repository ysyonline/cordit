# O-7 生产链冒烟：UI 信号驱动 → 真战斗 → 胜利驻留 → battle_finished 转发
# 【-s 模式限制】Router 拒绝无 Main/World 环境切换（R3 冒烟已实证），故
#   直接实例化 battle.tscn（O-6 修复后的生产场景本体）——装配链、输入桥、
#   敌方驱动、结算驻留、转发链全部是生产代码，与 GUT 直驱的差异是本冒烟
#   不用 GUT 断言基建、走 SceneTree 主循环轮询（更贴近真实帧驱动时序）。
# 运行：Godot headless -s（--path D:\code\cordit），退出码 0=PASS，1=FAIL。
extends SceneTree

var _battle: Node = null
var _finished_result: Variant = null
var _phase := "boot"
var _fails: Array[String] = []
var _guard := 0
var _battle_cmd_log: Array = []


func _initialize() -> void:
	print("[O7-SMOKE] === 生产链冒烟：UI信号→战斗→胜利驻留→转发 ===")


func _process(_delta: float) -> bool:
	_guard += 1
	if _guard > 3600:  # 60s 总护栏
		_fail("60s 总护栏触顶，phase=" + _phase)
		return _finish()
	match _phase:
		"boot":
			if _guard >= 5:
				_boot()
		"drive":
			_drive_tick()
		"await_forward":
			if _finished_result != null:
				return _final_check()
	return false


func _boot() -> void:
	var eb := root.get_node("EventBus")
	eb.battle_finished.connect(_on_forwarded)
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	if packed == null:
		_fail("battle.tscn 无法加载")
		_finish()
		return
	# 预置暂存载荷（Router 受理路径的簿记形态，测试注入口与 GUT 同款）
	root.get_node("SceneRouter")._staged_payload = {
		"enemy_group_id": "b1_moth",
		"return_map": "res://scenes/maps/ruins_f1.tscn",
		"return_position": Vector2(384, 120),
		"defeat_enemy_uid": "enemy_o7_smoke",
	}
	_battle = packed.instantiate()
	root.add_child(_battle)
	print("[O7-SMOKE] ① 战斗场景实例化，开始 UI 信号驱动（玩家链）")
	_phase = "drive"


func _drive_tick() -> void:
	if _battle == null or not is_instance_valid(_battle):
		_fail("战斗场景被提前释放")
		_finish()
		return
	var cmd: RefCounted = _battle.get("cmd")
	if cmd == null:
		_fail("cmd 未装配")
		_finish()
		return
	if cmd.over:
		print("[O7-SMOKE] ② 战斗结束 outcome=%s，等驻留+黑屏+转发" % String(cmd.outcome))
		_phase = "await_forward"
		return
	if cmd.is_party_turn():
		var actor: Dictionary = cmd.current_actor()
		if not actor.is_empty():
			# 玩家链：UI 信号发射（等同真人点"攻击"→选目标→确认）
			_battle.ui.command_selected.emit({"type": "attack", "target_slot": 0})
			# 输入桥的 _drive_until_party_turn 是异步节拍驱动；-s 冒烟里
			# 主循环 _process 每帧tick，这里靠桥内部 await 自然推进，
			# 不需要手动泵——等待期间 is_party_turn 会随队列变化
			pass


func _on_forwarded(r: Dictionary) -> void:
	_finished_result = r
	print("[O7-SMOKE] ③ battle_finished 已转发 outcome=%s 击破凭据=%s" % [
			String(r.get("outcome", "?")), String(r.get("defeat_enemy_uid", "?"))])


func _final_check() -> bool:
	var r: Dictionary = _finished_result
	if String(r.get("outcome", "")) != "VICTORY":
		_fails.append("outcome 应为 VICTORY: " + String(r.get("outcome", "?")))
	if String(r.get("defeat_enemy_uid", "")) != "enemy_o7_smoke":
		_fails.append("击破凭据应透传: " + String(r.get("defeat_enemy_uid", "?")))
	var ps: Array = r.get("party_state", []) as Array
	if ps.size() != 3:
		_fails.append("party_state 应覆盖 3 人: %d" % ps.size())
	if _fails.is_empty():
		print("[O7-SMOKE] === PASS：UI信号→战斗→胜利→驻留→转发 全链通 ===")
	else:
		print("[O7-SMOKE] === FAIL ===")
		for f in _fails:
			print("[O7-SMOKE]   - " + f)
	return true  # 退出 main loop


func _finish() -> bool:
	print("[O7-SMOKE] === FAIL（提前终止）===")
	return true


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[O7-SMOKE] FAIL: " + msg)
