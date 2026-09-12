extends SceneTree
## _o5_smoke_verify.gd —— O-5 冒烟：生产语境（current_scene=Main）下
## f1 入口剧情锚点装配 + 薄壳属性对表。M7-R3 冒烟同款纪律：
## -s 模式无 Autoload 标识符，须 root.get_node() 运行期取；
## 场景直接 instantiate（SceneRouter 拒绝 -s 切图）。

func _init() -> void:
	print("=== O5 smoke start ===")
	var fails: int = 0

	# 前置：Autoload 就位（-s 模式下依然会挂载 Autoload 单例到 root）
	var game_data = root.get_node_or_null("GameData")
	var save_mgr = root.get_node_or_null("SaveManager")
	var router = root.get_node_or_null("SceneRouter")
	if game_data == null or save_mgr == null or router == null:
		print("SMOKE_FAIL: Autoload 未挂载 gd=%s sm=%s sr=%s" % [game_data, save_mgr, router])
		quit(1)
		return

	# ① 生产语境守卫验证：current_scene 为 null（-s 模式）→ 不接线
	var f1_scene: PackedScene = load("res://scenes/maps/ruins_f1.tscn")
	if f1_scene == null:
		print("SMOKE_FAIL: f1 场景加载失败")
		quit(1)
		return
	var f1_cs_guard = f1_scene.instantiate()
	root.add_child(f1_cs_guard)
	# -s 模式 current_scene 为空 → 守卫应拦截（无锚点）
	var anchor_guard = f1_cs_guard.get_node_or_null("Triggers/Evt_Ruin_Enter")
	if anchor_guard != null:
		print("SMOKE_FAIL: 非生产语境不应接线入口锚")
		fails += 1
	else:
		print("PASS: 非生产语境守卫生效（入口锚未接线）")
	f1_cs_guard.queue_free()
	await process_frame
	await process_frame

	# ② 生产语境装配：造 fake Main 置 current_scene，再实装 f1
	var fake_main := Node2D.new()
	fake_main.name = "Main"
	root.add_child(fake_main)
	current_scene = fake_main
	var f1 = f1_scene.instantiate()
	fake_main.add_child(f1)
	await process_frame

	# 事件层三件套：loader（地图侧自建）+ 全局 executor（Router 装配）
	var gexec = router.get("global_event_executor")
	if gexec == null:
		print("SMOKE_FAIL: SceneRouter.global_event_executor 为空")
		fails += 1
	var anchor = f1.get_node_or_null("Triggers/Evt_Ruin_Enter")
	if anchor == null:
		print("SMOKE_FAIL: 生产语境入口锚未接线")
		fails += 1
	else:
		print("PASS: 生产语境入口锚已装配")
		# ③ 薄壳属性对表
		var new_eid = String(anchor.get("new_event_id"))
		if new_eid != "story_ruin_enter":
			print("SMOKE_FAIL: new_event_id=%s 应为 story_ruin_enter" % new_eid)
			fails += 1
		else:
			print("PASS: new_event_id = story_ruin_enter")
		var mask = int(anchor.get("collision_mask"))
		if mask != 16:
			print("SMOKE_FAIL: collision_mask=%d 应为 16" % mask)
			fails += 1
		else:
			print("PASS: collision_mask = 16")
		var layer = int(anchor.get("collision_layer"))
		if layer != 0:
			print("SMOKE_FAIL: collision_layer=%d 应为 0" % layer)
			fails += 1
		else:
			print("PASS: collision_layer = 0")
		var pos = (anchor as Node2D).position
		if pos != Vector2(448, 56):
			print("SMOKE_FAIL: 位置=%s 应为 (448,56)" % pos)
			fails += 1
		else:
			print("PASS: 触发面位置 = (448,56)（南门落位正本）")
		# 形状
		var shape_node = anchor.get_node_or_null("CollisionShape2D")
		if shape_node == null:
			print("SMOKE_FAIL: 无 CollisionShape2D")
			fails += 1
		else:
			var rect = (shape_node as CollisionShape2D).shape as RectangleShape2D
			if rect == null or rect.size != Vector2(32, 32):
				print("SMOKE_FAIL: 形状应 32x32")
				fails += 1
			else:
				print("PASS: 踩踏面 32x32")
		# 对表成员
		if f1.get("ruin_enter_anchor") != anchor:
			print("SMOKE_FAIL: ruin_enter_anchor 对表成员未回填")
			fails += 1
		else:
			print("PASS: ruin_enter_anchor 成员已回填")

	# ④ 事件表对表：story_ruin_enter 已登记且 phase>=1 门闸
	var loader = load("res://scripts/events/event_loader.gd").new()
	loader.load_all()
	if not loader.has_event("story_ruin_enter"):
		print("SMOKE_FAIL: 事件表无 story_ruin_enter")
		fails += 1
	else:
		print("PASS: 事件表 story_ruin_enter 已登记")

	# ⑤ 生产链路语义断言：phase=0 时条件不满足（门闸拦截）
	game_data.set("story_phase", 0)
	var ev = loader.get_event("story_ruin_enter")
	var cond_met = gexec.conditions_met(ev)
	if cond_met:
		print("SMOKE_FAIL: phase=0 时门闸应拦截")
		fails += 1
	else:
		print("PASS: phase=0 门闸拦截（P1 前不开演）")
	# phase=1 放行
	game_data.set("story_phase", 1)
	cond_met = gexec.conditions_met(ev)
	if not cond_met:
		print("SMOKE_FAIL: phase=1 时门闸应放行")
		fails += 1
	else:
		print("PASS: phase=1 门闸放行（接委托后来遗迹即触发）")
	game_data.set("story_phase", 0)  # 还原

	# 清理
	fake_main.queue_free()
	await process_frame

	if fails > 0:
		print("SMOKE_RESULT: FAIL (%d)" % fails)
		quit(1)
	else:
		print("SMOKE_RESULT: ALL PASS")
		quit(0)
