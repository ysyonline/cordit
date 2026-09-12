extends Node
## _story_chain_repro.gd —— 剧情链 headless 全链路复现（诊断 R-1 试玩断点）
##
## 目标：证明 town 告示板 -> f1 入口锚 -> f3 棺前锚 代码链无断点。
## 若全 PASS，则 R-1 试玩者 story_phase=0 + 仅杀 road 甲虫 = 引导缺位
## （玩家未对 town 告示板按 Z 接取任务），非代码断点。
##
## 跑法（Windows 反斜杠 + MSYS2_ARG_CONV_EXCL + APPDATA 沙盒重定向防真实存档泄入）：
##   MSYS2_ARG_CONV_EXCL="*" APPDATA=D:/code/cordit/.godot_user_tmp/gut-sandbox \
##   "<GODOT>" --headless --path D:/code/cordit res://tools/dev/_story_chain_repro.tscn
## 退出码：0 = 全 PASS（链通）；1 = 任一 FAIL。

const BILLBOARD_ID: String = "inv_town_02"

func _ready() -> void:
	print("=== STORY CHAIN REPRO (R-1 断点诊断) ===")
	await get_tree().process_frame   # 等 Autoload 完成加载
	var fails := 0

	var gd = GameData
	var eb = EventBus
	var sr = get_node("/root/SceneRouter")
	if gd == null or eb == null or sr == null:
		print("FAIL: Autoload 未挂载 (gd=%s eb=%s sr=%s)" % [gd, eb, sr])
		get_tree().quit(1)
		return

	# 造 fake Main（生产语境守卫要求 current_scene.name == "Main"）
	var fake_main := Node2D.new()
	fake_main.name = "Main"
	get_tree().root.add_child(fake_main)
	get_tree().current_scene = fake_main

	# 全局 executor（f1/f3 锚点走 SceneRouter.global_event_executor）
	var exec = load("res://scripts/events/event_executor.gd").new()
	sr.global_event_executor = exec

	# ---------- STEP 1: town 告示板 -> story_quest_accept (0->1) ----------
	var town = load("res://scenes/maps/town.tscn").instantiate()
	fake_main.add_child(town)
	await get_tree().process_frame
	var billboard = null
	for inv in town.content_points["investigates"]:
		if String(inv.call("get_event_id")) == BILLBOARD_ID:
			billboard = inv
	if billboard == null:
		print("FAIL: town 无告示板 %s" % BILLBOARD_ID)
		fails += 1
	else:
		# 真机里玩家会先看完自动开演的 P0 开场对话再去找告示板；
		# 复现里先强制收束 P0 对话（同玩家看完/跳过），否则 is_idle 门闸会拦截
		if town.dialogue_runner != null:
			town.dialogue_runner.force_idle()
		gd.set("story_phase", 0)
		billboard.on_interact()
		if gd.story_phase != 1:
			print("FAIL: 告示板接取未推进 phase（got %d，应为 1）" % gd.story_phase)
			fails += 1
		else:
			print("PASS: town 告示板 -> story_quest_accept -> phase=1")
	town.queue_free()
	await get_tree().process_frame

	# ---------- STEP 2: f1 入口锚 -> story_ruin_enter (1->2) ----------
	var f1 = load("res://scenes/maps/ruins_f1.tscn").instantiate()
	fake_main.add_child(f1)
	await get_tree().process_frame
	var anchor = f1.get_node_or_null("Triggers/Evt_Ruin_Enter")
	if anchor == null:
		print("FAIL: f1 入口锚未装配")
		fails += 1
	else:
		# 门闸：phase=0 不应放行
		gd.set("story_phase", 0)
		anchor.inject_emit()
		if gd.story_phase != 0:
			print("FAIL: f1 锚 phase=0 时不应推进（got %d）" % gd.story_phase)
			fails += 1
		else:
			print("PASS: f1 锚 gate 拦截 phase=0（P1 前不开演）")
		# phase=1 应放行 -> 2
		gd.set("story_phase", 1)
		anchor.inject_emit()
		if gd.story_phase != 2:
			print("FAIL: f1 锚 phase=1 未推进 ->2（got %d）" % gd.story_phase)
			fails += 1
		else:
			print("PASS: f1 入口锚 -> story_ruin_enter -> phase=2")
	f1.queue_free()
	await get_tree().process_frame

	# ---------- STEP 3: f3 棺前锚 -> story_boss_pre (2 -> boss b5_core) ----------
	var f3 = load("res://scenes/maps/ruins_f3.tscn").instantiate()
	fake_main.add_child(f3)
	await get_tree().process_frame
	var boss = f3.get("boss_anchor")
	if boss == null:
		print("FAIL: f3 Boss 锚未装配")
		fails += 1
	else:
		# 门闸：phase=1 不应触发 boss
		gd.set("story_phase", 1)
		exec.clear_battle_pause()
		boss.on_interact()
		if exec.pending_battle_group != "":
			print("FAIL: f3 锚 phase=1 不应开 boss（got %s）" % exec.pending_battle_group)
			fails += 1
		else:
			print("PASS: f3 锚 gate 拦截 phase=1（Boss 前需先入遗迹）")
		# phase=2 应开 boss (b5_core)
		gd.set("story_phase", 2)
		exec.clear_battle_pause()
		boss.on_interact()
		if exec.pending_battle_group != "b5_core":
			print("FAIL: f3 锚 phase=2 未开 boss（got '%s'）" % exec.pending_battle_group)
			fails += 1
		else:
			print("PASS: f3 棺前锚 -> story_boss_pre -> 战斗 b5_core 触发")
		# boss 战前 phase 保持 2（battle 动作挂起事件流，胜利后续行段含 ->3）
		if gd.story_phase != 2:
			print("FAIL: boss 战前 phase 应为 2（battle 挂起）got %d" % gd.story_phase)
			fails += 1
		else:
			print("PASS: boss 战前 phase 保持 2（胜利后续行段含 ->3）")
	f3.queue_free()
	await get_tree().process_frame

	fake_main.queue_free()
	await get_tree().process_frame

	if fails > 0:
		print("REPRO_RESULT: FAIL (%d 项)" % fails)
		get_tree().quit(1)
	else:
		print("REPRO_RESULT: ALL PASS —— 代码链无断点，R-1 story_phase=0 属引导缺位（玩家未接取任务）")
		get_tree().quit(0)
