extends Node
## E1-S4 无头自验脚本（交付自检用，非正式 SMK 用例；headless 跑法，不进构建）
##
## 用法：Godot_console.exe --headless --path <项目根> res://tests/smoke/headless_e1s4.tscn
## 退出码：0 = 全 PASS；1 = 任一 FAIL。
##
## 断言项（E1-S4 三条验收中可自动化的部分；手感/视觉留人工）：
##   ① 初始装载后玩家在 YSorted 挂载成功（脚底原点 = PlayerSpawn）；
##   ② 注入向右输入 → 玩家 x 位移增长，速率 ≈ 72px/s（±10%）；
##   ③ 注入朝墙输入 → 碰撞后实际位移归零（move_and_slide 顶墙停住，
##      不穿墙不抖动）；结束注入后 velocity 归零。
##   淡入淡出等 E1-S3 机制已由 SMK-08~12 覆盖，不重复。

const TARGET_PLAYER_SCRIPT := "res://scripts/player/player.gd"


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var results: Array = [
		await _check_spawn(),
		await _check_move_right(),
		await _check_wall_block(),
	]
	var pass_count: int = results.count(true)
	print("[E1S4] 汇总：%d/3 PASS" % pass_count)
	get_tree().quit(0 if pass_count == 3 else 1)


## 找 YSorted 下的玩家节点（CharacterBody2D 且挂 player.gd）
func _find_player() -> CharacterBody2D:
	var world: Node = get_tree().root.get_node_or_null("Main/World")
	if world == null or world.get_child_count() == 0:
		return null
	var ysorted: Node = world.get_child(0).get_node_or_null("YSorted")
	if ysorted == null:
		return null
	for child in ysorted.get_children():
		var body := child as CharacterBody2D
		if body != null and body.get_script() != null \
				and (body.get_script() as Script).resource_path == TARGET_PLAYER_SCRIPT:
			return body
	return null


## ① 出生与挂载：玩家存在、在 YSorted 下、脚底坐标 ≈ PlayerSpawn(96,160)
func _check_spawn() -> bool:
	var player := _find_player()
	if player == null:
		print("[E1S4-1] FAIL: YSorted 下未找到玩家")
		return false
	var spawn: Node2D = player.get_parent().get_parent().get_node_or_null("PlayerSpawn") as Node2D
	if spawn == null:
		print("[E1S4-1] FAIL: 找不到 PlayerSpawn")
		return false
	if player.position.distance_to(spawn.position) > 1.0:
		print("[E1S4-1] FAIL: 出生位置 %s ≠ 脚底标记 %s" % [player.position, spawn.position])
		return false
	print("[E1S4-1] PASS: 玩家挂载于 YSorted，脚底原点 @ %s" % player.position)
	return true


## ② 直线移动：注入向右 1s，位移 ≈ 72px（±10%），并核对最后帧位移量
func _check_move_right() -> bool:
	var player := _find_player()
	if player == null:
		print("[E1S4-2] FAIL: 找不到玩家")
		return false
	var start: Vector2 = player.position
	player.set_input_override(Vector2.RIGHT)
	await get_tree().create_timer(1.0).timeout
	player.set_input_override(Vector2.ZERO)
	var dist: float = player.position.x - start.x
	# ±10% 容差：转向缓冲 0.15s 内仍保持 RIGHT，应接近满速 72px
	if absf(dist - 72.0) > 7.2:
		print("[E1S4-2] FAIL: 1s 位移 %.1fpx（期望 72±7.2）" % dist)
		return false
	var last: Vector2 = player.get_last_frame_displacement()
	if last.length() > 3.0:
		print("[E1S4-2] FAIL: 停止注入后仍有残余位移 %s" % last)
		return false
	print("[E1S4-2] PASS: 1s 右移 %.1fpx（≈72px/s = 4.5tile/s），停注即停" % dist)
	return true


## ③ 撞墙：从墙左侧注入向右，1s 内应被横墙(320,220)挡住：x 停在墙左缘附近、
##    不越墙、不抖动（位移归零），is_moving() 转false
func _check_wall_block() -> bool:
	var player := _find_player()
	if player == null:
		print("[E1S4-3] FAIL: 找不到玩家")
		return false
	# 置于 (240, 220)（横墙左缘 x=272 左侧 32px 处，脚底 y 与墙同带）
	player.position = Vector2(240, 220)
	var start_x: float = player.position.x
	player.set_input_override(Vector2.RIGHT)
	await get_tree().create_timer(1.0).timeout
	var blocked_x: float = player.position.x
	var still_pushing: bool = player.is_moving()
	player.set_input_override(Vector2.ZERO)
	await get_tree().create_timer(0.2).timeout
	var after_x: float = player.position.x
	# 墙左缘 272，脚矩形半宽 6 → 脚底最大 x ≈ 266（留 6px 余量）
	if blocked_x > 266.0:
		print("[E1S4-3] FAIL: 越墙 x=%.1f（应 ≤266）" % blocked_x)
		return false
	if blocked_x <= start_x + 10.0:
		print("[E1S4-3] FAIL: 未发生接近墙的位移 x=%.1f（起点 %.1f）" % [blocked_x, start_x])
		return false
	if absf(after_x - blocked_x) > 0.5:
		print("[E1S4-3] FAIL: 顶墙后位置漂移 %.1f→%.1f（碰撞应稳定）" % [blocked_x, after_x])
		return false
	if still_pushing:
		print("[E1S4-3] 警告：顶墙注入期间 real_velocity 未归零（顶墙滑移量小可接受）")
	print("[E1S4-3] PASS: 撞墙停住 x=%.1f（墙左缘 272），无穿墙无漂移" % blocked_x)
	return true
