# M7-O13 f3→f2 返程传送冒烟：沿南门通道逐格上推玩家，定位触发阈值。
#
# 【背景】用户实测"贴着 f3 最顶门洞走却不切图"。触发区 tile(19,0) size(2,1)
#   → 像素 y∈[0,16]，只有最顶 16px；门洞通路 (19,0)(20,0)+(19,1)(20,1) 是
#   通的（gen_ruins.py:309/323 已挖空）。所以疑点不在"路不通"，而在
#   "触发条太苛刻"——玩家要走到多高才能踩进那条 16px 的窄带？本脚本把
#   玩家从落位 (19.5,2)=y40 逐格上推到 y=0，逐点断言触发器是否响应。
#
# 【判定口径】-s 模式下 SceneRouter 恒拒切换（未找到常驻根 Main/World），
#   故不断言"切图成功"，只断言"触发器是否进入"——双判据：
#     ① trigger._cooldown > 0（_on_body_entered 执行后置 0.5，内部硬证据）
#     ② 日志出现 "[TriggerTeleport] 跨图传送 tp_f3_to_f2"（外部可 grep）
#   切图本身由生产入口（main.tscn）保证，本脚本不覆盖。
#
# 【产出】打印玩家碰撞盒尺寸、触发区几何、首个触发 y。退出码 0=PASS，1=FAIL。
extends SceneTree

var _fails: Array[String] = []
var _guard := 0
var _phase := "boot"
var _map: Node = null
var _player: CharacterBody2D = null
var _trigger: Area2D = null

## 上推位点（像素 y）：40=落位 tile2 → 0=tile0 最顶
var _steps: Array[float] = [40.0, 36.0, 32.0, 28.0, 24.0, 20.0, 16.0, 12.0, 8.0, 4.0, 0.0]
var _idx := 0
var _frames := 0
var _trigger_at := -1.0
var _box_h := 0.0


func _initialize() -> void:
	print("[F3F2] === f3→f2 返程传送阈值冒烟 ===")


func _process(_delta: float) -> bool:
	_guard += 1
	if _guard > 1800:   # 30s 护栏
		_fail("30s 护栏触顶，phase=" + _phase)
		return _finish()
	match _phase:
		"boot":
			if _guard >= 5 and root.has_node("SceneRouter"):
				_boot()
		"probe":
			return _probe()
	return false


func _boot() -> void:
	var f3: PackedScene = load("res://scenes/maps/ruins_f3.tscn")
	_map = f3.instantiate()
	root.add_child(_map)
	_phase = "probe"


func _probe() -> bool:
	if _map == null or _guard < 12:
		return false

	# ---- 首帧：抓几何信息 ----
	if _player == null:
		_player = _map.get_node_or_null("YSorted/Player")
		if _player == null:
			_fail("f3 场景无 YSorted/Player")
			return _finish()
		var cs: CollisionShape2D = _player.get_node_or_null("CollisionShape2D")
		if cs != null and cs.shape is RectangleShape2D:
			_box_h = (cs.shape as RectangleShape2D).size.y
		print("[F3F2] 玩家碰撞盒高 = %s px（中心 y=%s）" % [_box_h, _player.global_position.y])

		var trig: Node = _map.get_node_or_null("Triggers/Tp_tp_f3_to_f2")
		if trig == null:
			# 目录实体名规则不确定时兜底：扫 Triggers 子节点找 teleport_id
			var cont: Node = _map.get_node_or_null("Triggers")
			if cont != null:
				for c in cont.get_children():
					if "teleport_id" in c and String(c.teleport_id) == "tp_f3_to_f2":
						trig = c
						break
		if trig == null:
			_fail("f3 未装配 tp_f3_to_f2 触发器")
			return _finish()
		_trigger = trig as Area2D
		var ts: CollisionShape2D = _trigger.get_node_or_null("CollisionShape2D")
		var tsz: Vector2 = (ts.shape as RectangleShape2D).size if ts != null and ts.shape is RectangleShape2D else Vector2.ZERO
		print("[F3F2] 触发区中心 = %s，尺寸 = %s → y∈[%s, %s]" % [
			_trigger.position, tsz, _trigger.position.y - tsz.y / 2.0, _trigger.position.y + tsz.y / 2.0])

	# ---- 逐点上推 ----
	if _idx < _steps.size():
		_frames += 1
		if _frames == 1:
			_player.global_position = Vector2(320.0, _steps[_idx])
		if _frames >= 6:   # 给物理服务器 6 帧做重叠检测
			var fired: bool = _trigger._cooldown > 0.0
			print("[F3F2] 位点 y=%s (tile %.2f) → 触发=%s" % [
				_steps[_idx], _steps[_idx] / 16.0, fired])
			if fired and _trigger_at < 0.0:
				_trigger_at = _steps[_idx]
			_frames = 0
			_idx += 1
			_trigger._cooldown = 0.0   # 清冷却，逐点独立判定
		return false

	return _report()


func _report() -> bool:
	print("[F3F2] ---- 结论 ----")
	if _trigger_at < 0.0:
		print("[F3F2] 全程未触发：玩家沿门洞通道从 y=40 推到 y=0 都没进触发区")
		_fail("f3→f2 触发器在整条门洞通道上均不响应（数据链或几何错配）")
	else:
		print("[F3F2] 首个触发位点 y=%s（tile %.2f），玩家碰撞盒高 %s" % [
			_trigger_at, _trigger_at / 16.0, _box_h])
		# 手感判据：门洞有 2 格深（tile0/1）。若只有 tile y<1 才触发，
		# 玩家必须贴地图最顶边才走得了，实测体感就是"门坏了"。
		if _trigger_at > 16.0:
			print("[F3F2] 判定：门洞第 2 格（tile y=1）即可触发，通道可达性 OK")
		else:
			print("[F3F2] 判定：仅 tile y<1（贴最顶边）才触发，触发条过窄")
	return _finish()


func _fail(msg: String) -> void:
	_fails.append(msg)


func _finish() -> bool:
	if _fails.is_empty():
		print("[F3F2] SMOKE PASS")
	else:
		print("[F3F2] SMOKE FAIL (%d):" % _fails.size())
		for f: String in _fails:
			print("  - ", f)
	quit(0 if _fails.is_empty() else 1)
	return true
