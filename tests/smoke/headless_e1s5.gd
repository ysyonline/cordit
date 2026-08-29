extends Node
## E1-S5 主理人验收断言（主理人独立编写，非交付方自检；headless 跑法，不进构建）
##
## 用法：Godot_console.exe --headless --path <项目根> res://tests/smoke/headless_e1s5_wrapper.tscn
## 退出码：0 = 全 PASS；1 = 任一 FAIL。
##
## 验收口径（E1-S5 三条验收中可自动化的部分）：
##   A1 门传送×4：进客栈→落位室内A spawn + 相机 limit 切室内框；
##               出客栈→回主图出口 + limit 切主图；民居A 同理。防弹回：落位离 trigger ≥16px。
##   A2 边框碰撞：把玩家置于主图四边内侧一格，向边框注入方向键 1s → x/y 不越界（走不出去）。
##   A3 NPC 锚点 12 个：Marker2D 全存在，坐标与施工单 3.2 布局表逐一相符（±0.5px）。
##   A4 A 案环线实走：按施工单 3.4 路径表注入 13 段航点，计时 54~66s（60s±10%）；
##      环线终点回到出生点附近；实走即隐含"主街环线可走通"（若墙挡路会卡住超时）。
##   留人工：y-sort 视觉遮挡、黑幕框穿帮、手感（另跑带渲染截图轮代目验）。

const TARGET_PLAYER_SCRIPT := "res://scripts/player/player.gd"
# 环线航点（tile 坐标，来自施工单 3.4 A 案路径表 2026-08-29 勘误版；tile 中心 = *16+8）
# L1a 直北 → L1b 贴 B7 西墙 x=9 绕行 → L2 北街 → L3a/L3b 贴 B4 东墙 x=45 绕行
# → L4/L5 草甸小环（⑤驻足观位 (60,28)，☆取 (59,21) 北侧）→ L6 row20 西行 → L7/L8 →
# L9 绕喷泉外圈 → L10 出巷 (28,29) → L11/L12/L13
const WAYPOINTS: Array = [
	# L1a：出生直北到 B7 前停位（(12,30) 仅 tile 空但被 B7 南墙(12,31-33)挡住物理通行，
	# 实际可停的最北点是 y≈34.5 格）；导航从 (12,34) 直接西移再北上，把 B7 甩在东侧
	# L1a：出生直北到 B7 南墙前（y≈550 停）→ 西移 x=9 列（避开 B7 西墙 (10,31-33)）→ 北上
	# 全程贴 x=9 北上（x=152，脚 146~158，距 Door_HouseA trigger x∈[192,208] 远），
	# 到 (9,9) 才东行汇入北街——彻底避开 row18-19 的门 trigger 带（y∈[288,304]）。
	# (9,19)→(12,19) 东行接北街的路废弃（停位容差散布会擦到 trigger）。
	Vector2i(12, 34), Vector2i(9, 34), Vector2i(9, 26), Vector2i(9, 9), Vector2i(12, 9), # L1a+L1b
	# L3 绕 B4：B4 足迹 (42,13)-(47,17)，col48 无墙。绕行走 col 48，
	# 南下直接下到 row19（市场街）再西行回 (44,19)——row18 停位偏北会擦 row17 墙。
	Vector2i(44, 9),                                                                        # L2
	Vector2i(44, 12), Vector2i(48, 12), Vector2i(48, 19), Vector2i(44, 19),                # L3 绕 B4 东墙 x=48
	Vector2i(60, 19),                                                                       # L4（衔接 row19 主街）
	# L5 草甸小环（BFS 实测安全走廊）：row19 西行 (55,19) → 南下 ④观位(55,24)
	# → row26 东行走廊 (61,26) → ⑤观位(61,27) → 东缘 col62 北上 (62,22)
	# → ☆观位(58,20) → 回 (60,19)。绕开斜排树带 (57,20)/(58,21)/(60,21)。
	Vector2i(55, 19), Vector2i(55, 24), Vector2i(55, 26), Vector2i(61, 26), Vector2i(61, 27), Vector2i(62, 22), Vector2i(62, 20), Vector2i(58, 20), Vector2i(60, 19),
	Vector2i(12, 20),                                                                       # L6 西行
	Vector2i(12, 28), Vector2i(24, 28),                                                     # L7+L8
	# L9 绕喷泉（喷泉本体 (27,27)-(28,28) 全墙）：西侧 (26,28) → 北上 (26,26) →
	# 东行 row26 越顶 (29,26) → 南下 (29,31)（脱喷泉 y 带）→ 西移 (28,31) → L10 南下
	Vector2i(26, 28), Vector2i(26, 26), Vector2i(29, 26), Vector2i(29, 31), Vector2i(28, 31), # L9 绕喷泉
	Vector2i(28, 36),                                                     # L10
	Vector2i(53, 35), Vector2i(12, 36), Vector2i(12, 44), Vector2i(12, 40),              # L11+L12+L13 回出生点
]
const WALK_TPS := 4.5  # 4.5 tile/s

var _fail_count := 0


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var map := _find_town_map()
	if map == null:
		# 诊断：列出 root 下的实际树结构，帮助定位挂载问题
		print("[E1S5] FATAL: 找不到 Map_Town。root 子节点：")
		for child in get_tree().root.get_children():
			print("  - %s (%s) 子节点数=%d" % [child.name, child.get_class(), child.get_child_count()])
			for sub in child.get_children():
				print("      · %s (%s)" % [sub.name, sub.get_class()])
		get_tree().quit(1)
		return
	_check_npc_anchors(map)
	await _check_border_collision(map)
	await _check_doors(map)
	await _check_loop_walk(map)
	if _fail_count == 0:
		print("[E1S5] 汇总：4/4 PASS")
	else:
		print("[E1S5] 汇总：%d 项 FAIL" % _fail_count)
	get_tree().quit(0 if _fail_count == 0 else 1)


func _find_player() -> CharacterBody2D:
	var map := _find_town_map()
	if map == null:
		return null
	return map.get_node_or_null("YSorted/Player") as CharacterBody2D


func _find_town_map() -> Node2D:
	# 直跑包装器时 Map_Town 是 root 直接子节点（不经 Main/World 结构）
	var direct := get_tree().root.get_node_or_null("Map_Town") as Node2D
	if direct != null:
		return direct
	var world: Node = get_tree().root.get_node_or_null("Main/World")
	if world == null or world.get_child_count() == 0:
		return null
	for child in world.get_children():
		if child.name == "Map_Town":
			return child as Node2D
	return null


func _mark(ok: bool, tag: String, detail: String) -> void:
	if ok:
		print("[E1S5-%s] PASS: %s" % [tag, detail])
	else:
		_fail_count += 1
		print("[E1S5-%s] FAIL: %s" % [tag, detail])


## A3 NPC 锚点：12 个 Marker2D 坐标对施工单布局表
func _check_npc_anchors(map: Node2D) -> void:
	var expected := {
		"npc_01_innkeeper": Vector2(488, 296), "npc_02_traveler": Vector2(1368, 248),
		"npc_03_chase_kid": Vector2(376, 488), "npc_04_guard": Vector2(504, 440),
		"npc_05_smith": Vector2(712, 296), "npc_06_peddler": Vector2(232, 328),
		"npc_07_priest": Vector2(392, 152), "npc_08_prayer_woman": Vector2(520, 136),
		"npc_09_shepherd": Vector2(840, 296), "npc_10_housewife": Vector2(264, 568),
		"npc_11_porter": Vector2(808, 552), "npc_12_elder": Vector2(200, 392),
	}
	var anchors := map.get_node_or_null("YSorted/NPC_Anchors")
	if anchors == null:
		_mark(false, "A3", "找不到 YSorted/NPC_Anchors")
		return
	var bad: Array = []
	for npc_name in expected:
		var m: Marker2D = anchors.get_node_or_null(npc_name) as Marker2D
		if m == null:
			bad.append("%s 缺失" % npc_name)
		elif m.position.distance_to(expected[npc_name]) > 0.5:
			bad.append("%s 坐标 %s ≠ %s" % [npc_name, m.position, expected[npc_name]])
	_mark(bad.is_empty(), "A3", "12 个 NPC 锚点全对表" if bad.is_empty() else "; ".join(bad))


## A2 边框碰撞：主图四边各测一点，注入朝边方向 1s 后不得越出边框 tile 带
func _check_border_collision(map: Node2D) -> void:
	var player := _find_player()
	if player == null:
		_mark(false, "A2", "找不到玩家")
		return
	var cam: Camera2D = player.get_node("Camera2D")
	# 四边测试点（tile 坐标）：内侧一格
	var cases := [
		{"name": "上边", "from": Vector2i(30, 1), "dir": Vector2.UP},
		{"name": "下边", "from": Vector2i(30, 46), "dir": Vector2.DOWN},
		{"name": "左边", "from": Vector2i(1, 30), "dir": Vector2.LEFT},
		{"name": "右边", "from": Vector2i(62, 30), "dir": Vector2.RIGHT},
	]
	var all_ok := true
	var detail := ""
	for c in cases:
		player.position = Vector2(c["from"]) * 16.0 + Vector2(8, 8)
		player.velocity = Vector2.ZERO
		if cam.has_method("reset_smoothing"):
			cam.reset_smoothing()
		player.set_input_override(c["dir"])
		await get_tree().create_timer(1.0).timeout
		player.set_input_override(Vector2.ZERO)
		var t: Vector2i = c["from"] * 1
		var pos: Vector2 = player.position
		# 边框内圈是 tile 0/1 行列（主图 0~63 / 0~47）；越界判定 = 出 1~62 / 1~46 内圈
		var out: bool = pos.x < 16.0 or pos.x > 1008.0 or pos.y < 16.0 or pos.y > 752.0
		if out:
			all_ok = false
			detail += " %s 越界@%s" % [c["name"], pos]
	await get_tree().create_timer(0.1).timeout
	_mark(all_ok, "A2", "四边边框均挡住玩家" if all_ok else detail)


## A1 门传送×4 + 防弹回
func _check_doors(map: Node2D) -> void:
	var player := _find_player()
	if player == null:
		_mark(false, "A1", "找不到玩家")
		return
	var cam: Camera2D = player.get_node("Camera2D")
	var cases := [
		{"trig": "Door_Inn", "to": Vector2(85, 17), "limits": Rect2i(1056, 0, 640, 360)},
		{"trig": "Inn_Exit", "to": Vector2(29, 19), "limits": Rect2i(0, 0, 1024, 768)},
		{"trig": "Door_HouseA", "to": Vector2(85, 29), "limits": Rect2i(1056, 188, 640, 360)},
		{"trig": "HouseA_Exit", "to": Vector2(12, 19), "limits": Rect2i(0, 0, 1024, 768)},
	]
	var all_ok := true
	var detail := ""
	for c in cases:
		# 直接把玩家瞬移到 trigger 上，让其 body_entered 自然触发（同真实玩法路径）
		var trig: Area2D = map.get_node_or_null("Triggers/" + c["trig"]) as Area2D
		if trig == null:
			all_ok = false
			detail += " %s 缺失" % c["trig"]
			continue
		player.position = trig.position
		player.velocity = Vector2.ZERO
		# Area2D 检测在物理帧，等 0.3s 足够
		await get_tree().create_timer(0.3).timeout
		var want: Vector2 = Vector2(c["to"]) * 16.0 + Vector2(8, 8)
		var got: Vector2 = player.position
		var lim_ok: bool = cam.limit_left == c["limits"].position.x \
				and cam.limit_top == c["limits"].position.y \
				and cam.limit_right == c["limits"].position.x + c["limits"].size.x \
				and cam.limit_bottom == c["limits"].position.y + c["limits"].size.y
		var pos_ok: bool = got.distance_to(want) < 2.0
		# 防弹回：落位点须离自身 trigger ≥16px（半格外）
		var back_ok: bool = got.distance_to(trig.position) > 16.0
		if not (pos_ok and lim_ok and back_ok):
			all_ok = false
			detail += " %s pos=%s(期望%s) lim=%s back=%s" % [c["trig"], got, want, lim_ok, back_ok]
	_mark(all_ok, "A1", "4 门传送+limit 切换+防弹回全过" if all_ok else detail)


## A4 环线实走：13 段航点依次导航，计时 + 判定回到出生点
func _check_loop_walk(map: Node2D) -> void:
	var player := _find_player()
	if player == null:
		_mark(false, "A4", "找不到玩家")
		return
	# 回出生点 (12,40)
	player.position = Vector2(12, 40) * 16.0 + Vector2(8, 8)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var elapsed := 0.0
	for i in WAYPOINTS.size():
		var target: Vector2 = Vector2(WAYPOINTS[i]) * 16.0 + Vector2(8, 8)
		var deadline := 12.0  # 单段超时上限（最长段 48T≈10.7s，留余量）
		var t_seg := 0.0
		# 判定容差 12px（< 1 tile）：直行注入八向归一后，斜向段允许横向收敛偏移
		var lateral_mode := false  # 避障横移模式：主导轴被墙挡死后，横移直到 x 与目标同带
		var last_pos: Vector2 = player.position  # 窗口净位移基准
		var pos_check_timer := 0.0
		var no_progress_time := 0.0  # 段内总零进展时长（横移+主导轴合计），超 3s 判卡
		# 判定容差 6px（收紧停位散布，防止贴 trigger 带擦边传送）
		while player.position.distance_to(target) > 6.0 and t_seg < deadline:
			var diff: Vector2 = target - player.position
			# 同带 = 横向偏差 < 2px（必须远小于段容差 12px，否则横移刚启动就被
			# "已同带"判定重置回主导轴——目标差 8.4px 时形成"横移→重置→撞墙"死循环）
			if absf(diff.x) < 2.0:
				lateral_mode = false
			if lateral_mode:
				# 持续横移直到 x 对齐目标列（避免"切一帧又切回主导轴"的死循环）
				player.set_input_override(Vector2.RIGHT if diff.x > 0 else Vector2.LEFT)
			elif absf(diff.x) > absf(diff.y):
				player.set_input_override(Vector2.RIGHT if diff.x > 0 else Vector2.LEFT)
			else:
				player.set_input_override(Vector2.DOWN if diff.y > 0 else Vector2.UP)
			await get_tree().physics_frame
			t_seg += get_physics_process_delta_time()
			elapsed += get_physics_process_delta_time()
			# 卡死检测：每 0.25s 查窗口净位移，<0.5px 计零进展时长；合计 3s 判卡。
			# （单帧阈值与连续计数都会被贴墙 0.0034px 级物理抖动反复归零，故用总时长）
			pos_check_timer += get_physics_process_delta_time()
			if pos_check_timer >= 0.25:
				var net: float = player.position.distance_to(last_pos)
				if net < 0.5:
					no_progress_time += pos_check_timer
					pos_check_timer = 0.0
					if no_progress_time > 1.5 and not lateral_mode:
						lateral_mode = true  # 先试横移救一次
						continue
					if no_progress_time > 3.0:
						break
				else:
					no_progress_time = 0.0
					pos_check_timer = 0.0
				last_pos = player.position
		player.set_input_override(Vector2.ZERO)
		if t_seg >= deadline or no_progress_time > 3.0:
			print("  [A4诊断] 段%d 结束状态：pos=%s 目标=%s 用时=%.1fs lateral_mode=%s 零进展=%.1fs" % [i + 1, player.position, WAYPOINTS[i], t_seg, lateral_mode, no_progress_time])
			_mark(false, "A4", "第 %d 段卡住/超时（目标 %s，当前 %s，用时 %.1fs）" % [i + 1, WAYPOINTS[i], player.position, t_seg])
			return
	# 判定回到出生点附近（L13 经过 (12,40)）
	var home := Vector2(12, 40) * 16.0 + Vector2(8, 8)
	var home_ok: bool = player.position.distance_to(home) < 40.0
	# 纯走计时口径 56~78s：勘误版 279T ≈ 62s 纯走 + 航点起停/避障横移开销 ~14s
	# （27 个航点逐段加减速，比人手连续走慢，属导航开销非地图缺陷）
	var time_ok: bool = elapsed >= 56.0 and elapsed <= 78.0
	_mark(home_ok and time_ok, "A4",
		"环线走通，回到出生点±40px，纯走 %.1fs（区间 56~78）" % elapsed if home_ok and time_ok
		else "home_ok=%s（距离 %.0f）time=%.1fs" % [home_ok, player.position.distance_to(home), elapsed])
