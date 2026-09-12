# B-01 生产装配冒烟：真 town.tscn 装配后 ① 任务目标 HUD ② 告示板「!」
# 【-s SceneTree 限制】_init 阶段 Autoload 未就绪（编译期引用 GameData/EventBus
#   会炸）——沿 _story_chain_repro 范式：extends Node + 配套 .tscn 直启，
#   _ready 等 Autoload 挂树后再实例化场景。退出码 0=PASS，1=FAIL。
extends Node

var _fails: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame   # 等 Autoload 就绪（同 repro 范式）
	print("[B01] === 生产装配冒烟：任务目标 HUD + 告示板提示 ===")

	# ---- 前置：清 phase（防沙盒泄档/前序污染，与 GUT 快照同口径）----
	GameData.story_phase = 0

	# ---- 生产路径装配 town（_ready 全链：事件层/点位/双 HUD/传送/光照）----
	var packed: PackedScene = load("res://scenes/maps/town.tscn")
	var town: Node = packed.instantiate()
	add_child(town)
	await get_tree().process_frame

	# ① 任务目标 HUD 在位 + phase=0 初始同步
	if town.quest_objective_hud == null:
		_fail("QuestObjectiveHud 未装配（town_map._assemble_quest_objective_hud 未生效）")
	else:
		if not town.quest_objective_hud.visible:
			_fail("HUD phase=0 应可见")
		var got: String = town.quest_objective_hud.get_displayed_objective()
		if got != "◆ 查看告示板，接取委托":
			_fail("HUD phase=0 文案=%s 期望 ◆ 查看告示板，接取委托" % got)

	# ② 告示板「!」提示在位
	if town.billboard_hint == null:
		_fail("BillboardHint 未装配（_attach_billboard_hint 未生效）")
	else:
		if not town.billboard_hint.visible:
			_fail("BillboardHint phase=0 应可见")
		if town.billboard_hint.text != "❗Z":
			_fail("BillboardHint.text=%s 期望 ❗Z" % town.billboard_hint.text)

	# ③ 生产链信号驱动：模拟接取委托（executor set_story_phase 同款广播）
	EventBus.story_phase_changed.emit(1)
	await get_tree().process_frame
	if town.quest_objective_hud == null or town.billboard_hint == null:
		_fail("信号驱动前置缺失")
	else:
		var got1: String = town.quest_objective_hud.get_displayed_objective()
		if got1 != "◆ 前往遗迹一层，调查异常亮光":
			_fail("收 phase_changed(1) HUD 文案=%s 期望 ◆ 前往遗迹一层，调查异常亮光" % got1)
		if town.billboard_hint.visible:
			_fail("接取后 BillboardHint 应隐藏（phase 门控）")

	# ④ 带档复检：重置 phase=1 重装 town，提示应装配即隐藏 + HUD 落显遗迹目标
	town.queue_free()
	await get_tree().process_frame
	GameData.story_phase = 1
	var town2: Node = (packed as PackedScene).instantiate()
	add_child(town2)
	await get_tree().process_frame
	if town2.billboard_hint == null:
		_fail("带档复检：BillboardHint 未装配")
	elif town2.billboard_hint.visible:
		_fail("带档复检：phase=1 进镇提示应装配即隐藏")
	if town2.quest_objective_hud == null:
		_fail("带档复检：HUD 未装配")
	else:
		var got2: String = town2.quest_objective_hud.get_displayed_objective()
		if got2 != "◆ 前往遗迹一层，调查异常亮光":
			_fail("带档复检：HUD 初始同步=%s 期望 遗迹目标" % got2)

	# ---- 收尾 ----
	if _fails.is_empty():
		print("[B01] SMOKE ALL PASS (4/4)")
		get_tree().quit(0)
	else:
		print("[B01] SMOKE FAIL (%d):" % _fails.size())
		for f: String in _fails:
			print("  - ", f)
		get_tree().quit(1)


func _fail(msg: String) -> void:
	_fails.append(msg)
