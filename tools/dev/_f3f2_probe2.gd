# M7-O13 f3→f2 触发区候选配置探针（只读游戏数据，脚本内模拟候选几何）
#
# 【承接 _f3f2_smoke_verify.gd 的结论】现状触发区 tile(19,0) size(2,1)
#   → 像素 y∈[0,16]，玩家中心必须走到 y≤16 才触发；门洞第 2 格中心 y=24
#   不触发 —— 顶部触发区比底部苛刻（玩家碰撞盒在脚底下方延伸，往北走滞
#   后半格）。这是 4 条"顶部触发区"（road_to_town / f1_to_road / f2_to_f1 /
#   f3_to_f2）的通病。
#
# 【本脚本要排掉的坑】单纯加深到 2 格（y∈[0,32]）会让玩家在门厅内"贴北墙"
#   走到 y=32 时误触发被传走。所以不能靠推理拍板，必须实测：
#     ① 门洞通道上推 → 触发阈值 c_max（越大越好走）
#     ② 非门洞列贴墙（x=tile18/21，y=32/36/40）→ 是否误触发（必须 false）
#     ③ 落位 y=40（tile2.5）→ 必须不触发（防弹回）
#   候选几何全部在脚本内改写 shape.size / trigger.position 模拟，
#   **不落盘、不改 teleport_catalog.gd，也不改 teleports.json**。
#
# 【判定重置纪律】body_entered 只在"进入瞬间"发一次：每测一个位点前先把
#   玩家挪到远处（y=200）等 3 帧"退出"区域，再挪到目标位等 5 帧判定。
extends SceneTree

var _map: Node = null
var _player: CharacterBody2D = null
var _trigger: Area2D = null
var _shape: RectangleShape2D = null

var _phase := "boot"
var _guard := 0

## 候选配置：[名称, 区域 y_min, 区域 y_max]
var _cands: Array = [
	["C0 现状 tile0", 0.0, 16.0],
	["C1 tile0~1", 0.0, 32.0],
	["C2 tile1 单格", 16.0, 32.0],
	["C3 tile0~0.5格", 0.0, 24.0],
]
var _ci := 0

## 探测位点：[名称, x, y, 期望(1=应触发 / 0=不应触发)]
var _probes: Array = []
var _pi := 0
var _frames := 0


func _initialize() -> void:
	print("[PROBE2] === f3→f2 触发区候选配置探针 ===")


func _process(_delta: float) -> bool:
	_guard += 1
	if _guard > 5400:   # 90s 护栏
		print("[PROBE2] 护栏触顶")
		quit(1)
		return true
	match _phase:
		"boot":
			if _guard >= 5 and root.has_node("SceneRouter"):
				_boot()
		"intro":
			return _intro()
		"run":
			return _run()
	return false


func _boot() -> void:
	var f3: PackedScene = load("res://scenes/maps/ruins_f3.tscn")
	_map = f3.instantiate()
	root.add_child(_map)
	_phase = "intro"


func _intro() -> bool:
	if _guard < 12:
		return false
	_player = _map.get_node_or_null("YSorted/Player")
	if _player == null:
		print("[PROBE2] FAIL：f3 无 YSorted/Player")
		quit(1)
		return true
	print("[PROBE2] 玩家 position=%s" % _player.global_position)
	for c in _player.get_children():
		if c is CollisionShape2D:
			var s = (c as CollisionShape2D).shape
			print("[PROBE2] 碰撞形状 %s：%s offset=%s size=%s" % [
				c.name, s.get_class(), (c as CollisionShape2D).position,
				(s as RectangleShape2D).size if s is RectangleShape2D else "?"])
	var cont: Node = _map.get_node_or_null("Triggers")
	for c in cont.get_children():
		if "teleport_id" in c and String(c.teleport_id) == "tp_f3_to_f2":
			_trigger = c as Area2D
	if _trigger == null:
		print("[PROBE2] FAIL：未找到 tp_f3_to_f2")
		quit(1)
		return true
	_shape = (_trigger.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	print("[PROBE2] 原始触发区：pos=%s size=%s" % [_trigger.position, _shape.size])

	# 探测位点：门洞列 x=320（tile19-20 中缝）；贴墙列 x=296(tile18)/344(tile21)
	_probes = [
		["落位 y40 防弹回", 320.0, 40.0, 0],
		["门洞 y32(tile2)", 320.0, 32.0, 0],
		["门洞 y28", 320.0, 28.0, 9],
		["门洞 y24(tile1中心)", 320.0, 24.0, 9],
		["门洞 y20", 320.0, 20.0, 9],
		["门洞 y16", 320.0, 16.0, 9],
		["贴墙 y40 x296", 296.0, 40.0, 0],
		["贴墙 y36 x296", 296.0, 36.0, 0],
		["贴墙 y32 x296", 296.0, 32.0, 0],
		["贴墙 y32 x344", 344.0, 32.0, 0],
	]
	_phase = "run"
	return false


func _run() -> bool:
	if _ci >= _cands.size():
		return _report()

	var cand: Array = _cands[_ci]
	if _pi == 0 and _frames == 0:
		# 套用候选几何（y 区间 → 中心/尺寸；x 保持 304~336）
		var ymin: float = cand[1]
		var ymax: float = cand[2]
		_shape.size = Vector2(32.0, ymax - ymin)
		_trigger.position = Vector2(320.0, (ymin + ymax) / 2.0)
		print("[PROBE2] ---- 候选 %s：区域 y∈[%s, %s] ----" % [cand[0], ymin, ymax])

	if _pi >= _probes.size():
		_ci += 1
		_pi = 0
		_frames = 0
		return false

	var p: Array = _probes[_pi]
	_frames += 1
	if _frames == 1:
		_player.global_position = Vector2(2000.0, 200.0)   # 退出区（重置 entered）
		_trigger._cooldown = 0.0
	elif _frames == 4:
		_player.global_position = Vector2(p[1], p[2])
	elif _frames >= 9:
		var fired: bool = _trigger._cooldown > 0.0
		var exp_: int = p[3]
		var verdict: String = "—"
		if exp_ == 0:
			verdict = "OK" if not fired else "✗误触发"
		elif exp_ == 9:
			verdict = "OK(触发)" if fired else "未触发"
		print("[PROBE2]   %-22s x=%s y=%s → fired=%s %s" % [p[0], p[1], p[2], fired, verdict])
		_trigger._cooldown = 0.0
		_frames = 0
		_pi += 1
	return false


func _report() -> bool:
	print("[PROBE2] === 探针结束（游戏数据未改动）===")
	quit(0)
	return true
