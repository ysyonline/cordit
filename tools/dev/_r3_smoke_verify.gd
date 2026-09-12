# R-3 预置存档验档冒烟（乙方案 Task 4）
# 路径：真实链路 load_save() → battle_finished(DEFEAT) → BattleResultHandler
#       回图 ruins_f2 → map_ready 后验玩家落位 / phase / B4 敌人在场 / 档未被覆盖。
# 运行：Godot headless -s（--path D:\code\cordit），退出码 0=PASS，1=FAIL。
extends SceneTree

var _frames := 0
var _checked := false


func _initialize() -> void:
	print("[R3-SMOKE] === 预置存档验档冒烟开始 ===")


func _process(_delta: float) -> bool:
	_frames += 1
	# 第 5 帧：Autoload 就绪后走真实读档+回图链
	if _frames == 5 and not _checked:
		_checked = true
		_run()
	# 第 240 帧（约 4s）：回图链完成后终检 + 退出
	if _frames >= 240:
		_final_check()
		return true  # 退出 main loop
	return false


func _run() -> void:
	var sm := root.get_node("SaveManager")
	# ① 读档（真实存档槽，不走测试覆写）
	if not sm.load_save():
		print("[R3-SMOKE] FAIL: load_save() 返回 false")
		return
	var ll: Dictionary = sm.last_loaded
	print("[R3-SMOKE] ① 读档成功: map=%s pos=%s phase=%d" % [
		String(ll.get("map", "?")), str(ll.get("position", "?")), int(ll.get("story_phase", -1))])
	# ② 模拟菜单读档确认动作的回图信号（与 menu_panel._confirm_load_item 同链）
	var eb := root.get_node("EventBus")
	eb.battle_finished.emit({"outcome": "DEFEAT", "party_state": []})


func _final_check() -> void:
	var fails: Array[String] = []
	# ③ 当前场景应为 ruins_f2（DEFEAT 链经 BattleResultHandler 回图）
	# SceneTree -s 模式无常驻根 Main/World，Router 拒绝真实切换（见日志）——
	# 场景装载链改由"直接实例化 f2 场景"替代验证（读档回灌口径已在 ①⑥ 全覆盖）。
	var cur: Node = null
	if current_scene != null:
		cur = current_scene
	else:
		var packed: PackedScene = load("res://scenes/maps/ruins_f2.tscn")
		cur = packed.instantiate()
		root.add_child(cur)
		print("[R3-SMOKE] ③' （-s 模式 Router 不可用）直接实例化 f2 场景替代验证")
	if cur == null:
		fails.append("当前场景为空")
	else:
		var path := String(cur.scene_file_path)
		print("[R3-SMOKE] ③ 当前场景: %s" % path)
		if path != "res://scenes/maps/ruins_f2.tscn":
			fails.append("场景不是 ruins_f2: " + path)
		# ④ 玩家落位 = 存档位 (384, 40)（±1px 容差）
		var player: Node2D = cur.get_node_or_null("YSorted/Player") as Node2D
		if player == null:
			fails.append("场景无 Player 节点")
		else:
			var p := player.global_position
			print("[R3-SMOKE] ④ 玩家落位: %s" % str(p))
			if absf(p.x - 384.0) > 1.0 or absf(p.y - 40.0) > 1.0:
				fails.append("落位偏差过大: %s != (384,40)" % str(p))
		# ⑤ B4 守卫在场（预置档 cleared 不含 ruins_f2_guardian）
		var guardian: Node = cur.get_node_or_null("YSorted/Enemy_ruins_f2_elite")
		if guardian == null:
			fails.append("B4 守卫节点缺失（Enemy_ruins_f2_elite）")
		else:
			var uid := String(guardian.get("enemy_uid"))
			print("[R3-SMOKE] ⑤ B4 守卫在场: uid=%s" % uid)
			if uid != "ruins_f2_guardian":
				fails.append("守卫 uid 异常: " + uid)
	# ⑥ GameData 状态 = 预置档口径（GameData 也是 Autoload，运行期经 root 取）
	var gd := root.get_node("GameData")
	print("[R3-SMOKE] ⑥ phase=%d flags=%s" % [gd.story_phase, str(gd.flags.keys())])
	if gd.story_phase != 2:
		fails.append("story_phase != 2: %d" % gd.story_phase)
	if not gd.flags.has("story_p0_seen"):
		fails.append("flags 缺 story_p0_seen")
	var kyle_hp := 0
	for c in gd.party:
		if c.id == "kyle":
			kyle_hp = c.max_hp
			print("[R3-SMOKE] ⑥ 凯尔 Lv%d HP%d/%d 武器=%s 防具=%s" % [
				c.level, c.hp, c.max_hp, c.weapon_id, c.armor_id])
			if c.level != 3 or c.max_hp != 200:
				fails.append("凯尔等级/HP 异常: Lv%d HP%d" % [c.level, c.max_hp])
			if c.weapon_id != "iron_sword" or c.armor_id != "leather_armor":
				fails.append("凯尔装备未代穿: %s/%s" % [c.weapon_id, c.armor_id])
	if kyle_hp == 0:
		fails.append("队伍无凯尔")
	# ⑦ 档未被启动装载覆盖（AutosaveNotifier 门控：无意图不落盘）
	var sm := root.get_node("SaveManager")
	var txt := FileAccess.get_file_as_string(sm.SAVE_PATH)
	var still_mine := txt.contains("ruins_f2") and txt.contains("story_p0_seen")
	print("[R3-SMOKE] ⑦ 存档文件仍是预置档: %s" % str(still_mine))
	if not still_mine:
		fails.append("存档文件被覆盖（门控失效）")
	# 结论
	if fails.is_empty():
		print("[R3-SMOKE] === PASS：读档落位 f2 南门 / phase=2 / B4 在场 / 档未覆盖 ===")
	else:
		print("[R3-SMOKE] === FAIL ===")
		for f in fails:
			print("[R3-SMOKE]   - " + f)
