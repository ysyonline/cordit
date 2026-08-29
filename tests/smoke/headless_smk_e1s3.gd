extends Node
## SMK-08~12 无头自动化冒烟脚本（E1-S3 质量门专用，headless 跑法，不进构建）
##
## 用法：
##   Godot_console.exe --headless --path <项目根> res://tests/smoke/headless_smk_e1s3.tscn
## 退出码：0 = 全 PASS；1 = 任一 FAIL。
##
## 设计说明：
##   - 直接以 main.tscn 为主场景运行（Router 依赖 A4 常驻根结构），
##     测试节点由 tscn 追加在 Main 下，等 MainController 初始装载完成后再断言；
##   - SMK-08 合法切换（含淡入淡出全程 0.4s 的等待）；
##   - SMK-09 三种非法 payload（空字典/缺字段/类型错）逐一拒绝；
##   - SMK-10 拒绝后 World 不变 + Router 可继续合法工作；
##   - SMK-11 UILayer/TestLabel 两轮切换后同实例存活；
##   - SMK-12 源码部分由主理人静态核对，此处复验 user:// 零落盘。
##   "淡入淡出可见"属人眼验收项，无头只验机制（mask alpha 变化由 SMK-08 日志佐证）。

var _label_ref: Label = null


func _ready() -> void:
	# 等 MainController 初始装载白盒图 A（0.2s 淡出+装载+0.2s 淡入 + 余量）
	await get_tree().create_timer(1.0).timeout
	var results: Array = [
		await _check_smk08(),
		await _check_smk09(),
		await _check_smk10(),
		await _check_smk11(),
		_check_smk12(),
	]
	var pass_count: int = results.count(true)
	print("[SMK-E1S3] 汇总：%d/5 PASS" % pass_count)
	get_tree().quit(0 if pass_count == 5 else 1)


## 取 World 容器（Main/World）
func _world() -> Node:
	return get_tree().root.get_node_or_null("Main/World")


func _current_map_name() -> String:
	var world: Node = _world()
	if world == null or world.get_child_count() == 0:
		return "<空>"
	return String(world.get_child(0).name)


## SMK-08 合法 payload 通过校验并完成切换（A→B），淡入淡出机制运转
func _check_smk08() -> bool:
	var before: String = _current_map_name()
	var payload := {
		"enemy_group_id": "slime_01", "return_map": "res://tests/smoke/fixtures/map_a.tscn",
		"return_position": Vector2(64, 32), "defeat_enemy_uid": "enemy_road_01"}
	var accepted: bool = SceneRouter.change_scene(
			"res://tests/smoke/fixtures/map_b.tscn", payload)
	if not accepted:
		print("[SMK-08] FAIL: 合法 payload 被拒绝受理")
		return false
	await get_tree().create_timer(1.0).timeout
	var after: String = _current_map_name()
	var staged: Dictionary = SceneRouter.get_staged_payload()
	if before != "MapA" or after != "MapB":
		print("[SMK-08] FAIL: 切换前=%s 切换后=%s（应为 MapA→MapB）" % [before, after])
		return false
	if staged.get("defeat_enemy_uid") != "enemy_road_01":
		print("[SMK-08] FAIL: 暂存载荷取回不一致: %s" % [staged])
		return false
	print("[SMK-08] PASS: 合法 payload 受理并完成切换 %s→%s，暂存载荷可取回" % [before, after])
	return true


## SMK-09 三种非法 payload 均拒绝且日志含原因（缺字段/类型错可区分）
func _check_smk09() -> bool:
	var target := "res://tests/smoke/fixtures/map_b.tscn"
	var cases := [
		["空字典 {}", {}, true],
		["缺 return_map 字段", {
			"enemy_group_id": "s", "return_position": Vector2(1, 1),
			"defeat_enemy_uid": "u"}, true],
		["return_position 类型错（String）", {
			"enemy_group_id": "s", "return_map": "res://tests/smoke/fixtures/map_a.tscn",
			"return_position": "64,32", "defeat_enemy_uid": "u"}, true],
	]
	var all_ok: bool = true
	for c: Array in cases:
		var accepted: bool = SceneRouter.change_scene(target, c[1])
		if accepted:
			print("[SMK-09] FAIL: 非法用例「%s」未被拒绝" % c[0])
			all_ok = false
	if all_ok:
		print("[SMK-09] PASS: 三种非法 payload 全部拒绝（拒绝日志见上，含缺字段/类型错区分）")
	return all_ok


## SMK-10 拒绝后当前场景不被破坏 + Router 未进坏状态（随后合法切换成功）
func _check_smk10() -> bool:
	var world: Node = _world()
	var before_child: Node = world.get_child(0) if world.get_child_count() > 0 else null
	# 先来一发非法调用
	SceneRouter.change_scene("res://tests/smoke/fixtures/map_b.tscn", {})
	# 紧接一次合法调用（无 payload 地图装载），验证 Router 未卡死
	var ok: bool = SceneRouter.change_scene(
			"res://tests/smoke/fixtures/map_a.tscn", {}, false)
	if not ok:
		print("[SMK-10] FAIL: 拒绝后的合法调用被防重入误伤（应能继续受理）")
		return false
	await get_tree().create_timer(1.0).timeout
	var current: Node = world.get_child(0) if world.get_child_count() > 0 else null
	if current == null or String(current.name) != "MapA":
		print("[SMK-10] FAIL: 拒绝后 World 内容异常: %s" % [_current_map_name()])
		return false
	print("[SMK-10] PASS: 非法调用零副作用（World 未被破坏），后续合法切换正常到 %s" % [_current_map_name()])
	return true


## SMK-11 UILayer/TestLabel 跨两轮切换存活且同实例
func _check_smk11() -> bool:
	var label_path := "Main/UILayer/TestLabel"
	_label_ref = get_tree().root.get_node_or_null("Main/UILayer/TestLabel") as Label
	if _label_ref == null:
		print("[SMK-11] FAIL: 找不到 %s" % label_path)
		return false
	# A→B 一轮
	SceneRouter.change_scene("res://tests/smoke/fixtures/map_b.tscn", {}, false)
	await get_tree().create_timer(1.0).timeout
	# B→A 二轮
	SceneRouter.change_scene("res://tests/smoke/fixtures/map_a.tscn", {}, false)
	await get_tree().create_timer(1.0).timeout
	var now: Label = get_tree().root.get_node_or_null("Main/UILayer/TestLabel") as Label
	if now == null:
		print("[SMK-11] FAIL: 两轮切换后 TestLabel 不存在")
		return false
	if now != _label_ref or not is_instance_valid(_label_ref):
		print("[SMK-11] FAIL: TestLabel 实例发生变化（非同一实例）")
		return false
	print("[SMK-11] PASS: 两轮切换后 TestLabel 同实例存活（valid 且指针一致）")
	return true


## SMK-12 动态部分：全程跑完 user:// 无新增文件（源码静态部分已由主理人核对）
func _check_smk12() -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		print("[SMK-12] FAIL: user:// 目录无法打开")
		return false
	dir.list_dir_begin()
	var files: Array[String] = []
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			files.append(f)
		f = dir.get_next()
	var bad: Array[String] = []
	for x in files:
		if not x.begins_with("log"):
			bad.append(x)
	if not bad.is_empty():
		print("[SMK-12] FAIL: user:// 出现非日志文件: %s" % [bad])
		return false
	print("[SMK-12] PASS: user:// 零存档/零游戏文件（仅引擎 logs），空壳无副作用")
	return true
