# O-10 生产装配冒烟：f3 装配产物实证（HUD / Boss 提示 / 存档反馈文案）
# 【-s 模式限制】_init 阶段 Autoload 未就绪（ruins_f3_map.gd 编译期引用
#   SceneRouter/GameData 会炸）——沿 O-7 冒烟的帧驱动模式：等 Autoload
#   挂树后再实例化场景。退出码 0=PASS，1=FAIL。
extends SceneTree

var _fails: Array[String] = []
var _guard := 0
var _phase := "boot"


func _initialize() -> void:
	print("[O10] === 生产装配冒烟：HUD/Boss提示/存档反馈 ===")


func _process(_delta: float) -> bool:
	_guard += 1
	if _guard > 1800:   # 30s 护栏
		_fail("30s 护栏触顶，phase=" + _phase)
		return _finish()
	match _phase:
		"boot":
			if _guard >= 5 and root.has_node("SceneRouter"):
				_boot()
		"check":
			return _check()
	return false


func _boot() -> void:
	# ---- ② 显示名映射（纯静态，先行）----
	var tc: GDScript = load("res://scripts/events/teleport_catalog.gd")
	var cases := {
		"town": "清溪镇", "road": "林间小道",
		"ruins_f1": "遗迹第一层", "ruins_f2": "遗迹第二层",
		"ruins_f3": "遗迹第三层",
	}
	var map_ok := true
	for k: String in cases:
		var got: String = tc.display_name(k)
		if got != cases[k]:
			_fail("display_name(%s)=%s 期望 %s" % [k, got, cases[k]])
			map_ok = false
	print("[O10] display_name 映射：", "PASS" if map_ok else "FAIL")

	# ---- ①+④ 装配 f3（生产路径：实例化即 _ready 全装配）----
	var f3: PackedScene = load("res://scenes/maps/ruins_f3.tscn")
	var map: Node = f3.instantiate()
	root.add_child(map)
	_phase = "check"


func _check() -> bool:
	var map: Node = root.get_node_or_null("RuinsF3")
	if map == null:
		# 场景根名兜底（实例化后自动名）：取 root 首个 Node2D 子节点
		for c in root.get_children():
			if c is Node2D and c.name != "root":
				map = c
				break
	if map == null or _guard < 10:
		return false   # 等场景就位 + 至少跑几帧（tween/广播稳定）

	# ① Boss 交互提示标签（挂场景根直铺，O12 设计位）
	var f1 := _fails.is_empty()
	var hint: Label = map.get_node_or_null("InteractHint")
	if hint == null:
		_fail("InteractHint 未装配（场景根直铺位）")
	else:
		if hint.text != "❗Z":
			_fail("InteractHint.text=%s 期望 ❗Z" % hint.text)
		if not hint.visible:
			_fail("InteractHint 不可见")
	print("[O10] Boss 交互提示标签：", "PASS" if f1 else "FAIL")

	# ④ HUD 响应链：生产模式 = town 首装 + UILayer 常驻跨图复用（与
	# menu_panel 同构；f3 不自装——INITIAL_SCENE_PATH 恒经 town）。
	# 冒烟直接驱动生产链上真实发生的事：HUD 实例挂 root（模拟 UILayer
	# 常驻位）→ 收 map_ready("ruins_f3") 广播 → 显示名映射。
	var f2_fail: Array[String] = []
	var hud := Control.new()
	hud.set_script(load("res://scripts/ui/map_name_hud.gd"))
	root.add_child(hud)
	# town 首装时 _ready 内 announce_ready 已广播 "town"——模拟先经历 town
	root.get_node("EventBus").map_ready.emit("town")
	if hud.get_displayed_name() != "清溪镇":
		f2_fail.append("HUD town 显示=%s 期望 清溪镇" % hud.get_displayed_name())
	# 玩家走到 f3：真实跨图 map_ready 广播
	root.get_node("EventBus").map_ready.emit("ruins_f3")
	if hud.get_displayed_name() != "遗迹第三层":
		f2_fail.append("HUD f3 显示=%s 期望 遗迹第三层" % hud.get_displayed_name())
	for m: String in f2_fail:
		_fail(m)
	print("[O10] MapNameHud 收号与映射：", "PASS" if f2_fail.is_empty() else "FAIL")

	# ---- ③ 存档反馈条文案协议（直驱 flash_map，不落盘）----
	var f3_fail: Array[String] = []
	var icon := Control.new()
	icon.set_script(load("res://scripts/ui/save_icon.gd"))
	root.add_child(icon)
	icon.flash_map(true, "ruins_f3")
	var lbl: Label = icon.get_node_or_null("Text")
	if lbl == null:
		f3_fail.append("save_icon 无 Text 子节点（_ready 未执行？）")
	elif lbl.text != "已存档 · 遗迹第三层":
		f3_fail.append("flash_map 文案=%s 期望 已存档 · 遗迹第三层" % lbl.text)
	for m: String in f3_fail:
		_fail(m)
	print("[O10] 存档反馈条文案：", "PASS" if f3_fail.is_empty() else "FAIL")
	return _finish()


func _fail(msg: String) -> void:
	_fails.append(msg)


func _finish() -> bool:
	if _fails.is_empty():
		print("[O10] SMOKE ALL PASS")
	else:
		print("[O10] SMOKE FAIL (%d):" % _fails.size())
		for f: String in _fails:
			print("  - ", f)
	quit(0 if _fails.is_empty() else 1)
	return true
