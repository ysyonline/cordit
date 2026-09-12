extends Node
## _o5_smoke_main.gd —— O-5 冒烟包装 Main（挂 current_scene 判定用）
## 由 headless 直启本场景：真实 Autoload + 真实场景树 + current_scene 本体。

func _ready() -> void:
	print("=== O5 smoke start ===")
	var fails: int = 0

	# 包装 Main 自身就是 current_scene（场景直启形态）→ 生产语境成立
	var cs := get_tree().current_scene
	print("current_scene = ", cs.name if cs else "<null>")

	# ① f1 实例化挂本 Main 下（_ready 时序：child 先于 parent ready 完成
	#    的时序由 Godot 保证：add_child 即刻触发子树 _ready，current_scene 已是本 Main）
	var f1_scene: PackedScene = load("res://scenes/maps/ruins_f1.tscn")
	var f1 = f1_scene.instantiate()
	add_child(f1)
	await get_tree().process_frame

	var anchor = f1.get_node_or_null("Triggers/Evt_Ruin_Enter")
	if anchor == null:
		print("SMOKE_FAIL: 生产语境入口锚未接线")
		fails += 1
	else:
		print("PASS: 生产语境入口锚已装配 @", (anchor as Node2D).position)
		var eid := String(anchor.get("new_event_id"))
		if eid != "story_ruin_enter":
			print("SMOKE_FAIL: new_event_id=", eid)
			fails += 1
		else:
			print("PASS: new_event_id = story_ruin_enter")
		if int(anchor.get("collision_mask")) != 16:
			print("SMOKE_FAIL: mask != 16")
			fails += 1
		else:
			print("PASS: collision_mask = 16")
		if int(anchor.get("collision_layer")) != 0:
			print("SMOKE_FAIL: layer != 0")
			fails += 1
		else:
			print("PASS: collision_layer = 0")
		if f1.get("ruin_enter_anchor") != anchor:
			print("SMOKE_FAIL: 对表成员未回填")
			fails += 1
		else:
			print("PASS: ruin_enter_anchor 成员已回填")

	# ② 事件表 + 门闸语义
	var loader = load("res://scripts/events/event_loader.gd").new()
	loader.load_all()
	if not loader.has_event("story_ruin_enter"):
		print("SMOKE_FAIL: 事件表无 story_ruin_enter")
		fails += 1
	else:
		print("PASS: 事件表已登记 story_ruin_enter")
		var ev: Dictionary = loader.get_event("story_ruin_enter")
		var executor = load("res://scripts/events/event_executor.gd").new()
		var gexec = get_node("/root/SceneRouter").get("global_event_executor")
		# 用全局 executor（与装配同实例）评估门闸
		GameData.story_phase = 0
		if gexec.conditions_met(ev):
			print("SMOKE_FAIL: phase=0 应拦截")
			fails += 1
		else:
			print("PASS: phase=0 门闸拦截")
		GameData.story_phase = 1
		if not gexec.conditions_met(ev):
			print("SMOKE_FAIL: phase=1 应放行")
			fails += 1
		else:
			print("PASS: phase=1 门闸放行")
		GameData.story_phase = 0

	if fails > 0:
		print("SMOKE_RESULT: FAIL (%d)" % fails)
		get_tree().quit(1)
	else:
		print("SMOKE_RESULT: ALL PASS")
		get_tree().quit(0)
