extends GutTest
## E4-S4 敌人三态完整 AI（TASK：追击/放弃/回位/定守/互穿）
##
## 断言覆盖（EPIC-4.md E4-S4 两条验收 + 探索 GDD §3.2 三态参数正本）：
##   A. 态机结构：四态枚举（PATROL/GUARD/CHASE/RETURN）与初始态归位；
##   B. 伪视野纯函数 _can_see：距离 4 tile(64px) 含边界、面朝 ±90° 点积
##      含边界（正侧方 90° 临界可见、背后 135° 不可见）——不依赖场景树直测；
##   C. 追击触发与速率：视野内真实玩家实体（物理查询层 16）触发 PATROL→CHASE，
##      直线接近，速 3 tile/s = 48 px/s（GDD §3.2）；
##   D. 放弃双阈值：玩家拉开 6 tile(96px) → RETURN；被墙卡住真实速度≈0
##      持续 1.5s → RETURN（真实墙 + 真实物理帧端到端）；
##   E. 回位精确：RETURN 吸附放置点（入树位置），到位按 waypoints 有无
##      转 PATROL/GUARD；
##   F. 定守不动：GUARD 态玩家贴脸视野内仍零移动、不追击（"站位即交战位"）；
##   G. 敌间互穿行为级：两敌对穿巡逻互不阻挡（GDD 边缘情况 1）；
##   H. 战后免疫配合：免疫期接触放行不发射载荷、CHASE 态不被打断。
##
## 【测试策略】沿 E2-S2 纪律：真实物理帧驱动（await physics_frame）；接触与
##   纯判定直调公开/成员方法（不经物理时序）；真实玩家实例入树作追击目标
##   （layer=16，物理查询可命中）；卡墙用真实 StaticBody2D 墙（层 1）端到端。

const ENEMY_SCENE_PATH: String = "res://scenes/enemies/visible_enemy.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/player.tscn"

## 巡逻速 2 tile/s（E2-S2 口径）与追击速 3 tile/s = 48 px/s（GDD §3.2）
const PATROL_SPEED: float = 32.0
const CHASE_SPEED: float = 48.0

const PHYS_DT: float = 1.0 / 60.0


## 实例化敌人：先设属性与位置、后入树（_ready 快照放置点作回位基准）
func _spawn_enemy(pos: Vector2, uid: String, group: String,
		pts: Array[Vector2] = []) -> CharacterBody2D:
	var packed: PackedScene = load(ENEMY_SCENE_PATH) as PackedScene
	var enemy: CharacterBody2D = packed.instantiate()
	autofree(enemy)
	enemy.enemy_uid = uid
	enemy.group_id = group
	enemy.waypoints = pts
	enemy.position = pos
	add_child_autofree(enemy)
	return enemy


## 实例化真实玩家（layer=16，物理查询与 TouchArea 均可命中）
func _spawn_player(pos: Vector2) -> CharacterBody2D:
	var player: CharacterBody2D = (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	autofree(player)
	add_child_autofree(player)
	player.global_position = pos
	return player


## 等待 N 个物理帧
func _await_frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


# =============== A. 态机结构 ===============

func test_四态枚举与初始态归位() -> void:
	# 有 waypoints → PATROL；空 waypoints → GUARD（定守）
	var patroller := _spawn_enemy(Vector2(0, 0), "e_state_a", "g1",
			[Vector2(32, 0)] as Array[Vector2])
	var guard := _spawn_enemy(Vector2(300, 0), "e_state_b", "g1")
	assert_eq(patroller._state, patroller.State.PATROL, "有 waypoints 初始应 PATROL")
	assert_eq(guard._state, guard.State.GUARD, "空 waypoints 初始应 GUARD（定守）")
	# 四态枚举成员齐备（GDD §3.2 三态 + 工程回位过渡态）
	var names: Array = patroller.State.keys()
	for expected: String in ["PATROL", "GUARD", "CHASE", "RETURN"]:
		assert_has(names, expected, "态枚举应含 %s" % expected)


# =============== B. 伪视野纯函数（距离 + 角度两维） ===============

func test_视野纯函数_角度边界正侧可见背后不可见() -> void:
	# 不入树实例直调（_can_see 为纯逻辑，不依赖场景树——GDD"不设视线射线"）
	var packed: PackedScene = load(ENEMY_SCENE_PATH) as PackedScene
	var enemy: CharacterBody2D = packed.instantiate()
	autofree(enemy)
	enemy.position = Vector2(1000, 1000)
	enemy._facing = Vector2.RIGHT
	# 正前 0°：可见
	assert_true(enemy._can_see(Vector2(1040, 1000)), "面朝正前应可见")
	# 正侧 90° 临界：dot=0，含边界 → 可见（GDD"±90°"取闭区间）
	assert_true(enemy._can_see(Vector2(1000, 1040)), "正侧方 90° 临界应可见（闭区间）")
	# 背后 135°：dot<0 → 不可见
	assert_false(enemy._can_see(Vector2(1000 - 28, 1000 + 28)), "背后 135° 不可见")
	# 正后 180°：不可见
	assert_false(enemy._can_see(Vector2(960, 1000)), "正后方不可见")


func test_视野纯函数_距离边界4tile含边界() -> void:
	var packed: PackedScene = load(ENEMY_SCENE_PATH) as PackedScene
	var enemy: CharacterBody2D = packed.instantiate()
	autofree(enemy)
	enemy.position = Vector2(2000, 2000)
	enemy._facing = Vector2.RIGHT
	# 63px（<4 tile=64px）可见；65px（>4 tile）不可见——"进入 4 tile 半径"
	assert_true(enemy._can_see(Vector2(2063, 2000)), "63px 在视野半径内应可见")
	assert_false(enemy._can_see(Vector2(2065, 2000)), "65px 超视野半径不可见")


# =============== C. 追击触发与速率 ===============

func test_追击触发_视野内玩家实体引CHASE() -> void:
	# 玩家放巡逻面朝方向（+x）正前 48px：帧 0 查询未就绪（物理空间同帧不可查，
	# 实测沉淀）巡逻先走半步并转向 +x；帧 1 起视野命中 → CHASE。随后直线接近，
	# 0.5s 应追近约 24px（48px/s），距玩家缩到 ~23px（未触体：TouchArea 16x14
	# 覆盖不到 23px 外的玩家，无过早战斗载荷）
	var enemy := _spawn_enemy(Vector2(3000, 3000), "e_chase", "g1",
			[Vector2(8, 0), Vector2(-8, 0)] as Array[Vector2])
	var player := _spawn_player(Vector2(3048, 3000))
	await _await_frames(5)
	assert_eq(enemy._state, enemy.State.CHASE, "玩家入视野应触发 PATROL→CHASE")
	var start: Vector2 = enemy.global_position
	await _await_frames(30)
	var closed: float = start.distance_to(enemy.global_position)
	assert_almost_eq(closed, CHASE_SPEED * 0.5, 3.0,
			"0.5s 应追近约 24px（3 tile/s），实为 %.2f px" % closed)
	assert_true(enemy.global_position.distance_to(player.global_position) < 48.0,
			"追击应缩短与玩家距离")


func test_追击速度快于巡逻速_48px秒() -> void:
	# 参数对表（GDD §3.2：巡逻 2 tile/s / 追击 3 tile/s）。玩家放巡逻面朝
	# 方向（+x）正前 48px：帧 1 面朝 DOWN 时正前在 90° 临界（dot=0 闭区间
	# 可见）→ 触发 CHASE，追速 48px/s 实测
	var enemy := _spawn_enemy(Vector2(3100, 3000), "e_spd", "g1",
			[Vector2(8, 0)] as Array[Vector2])
	_spawn_player(Vector2(3148, 3000))
	await _await_frames(5)
	assert_eq(enemy._state, enemy.State.CHASE, "前置：进入 CHASE")
	var start: Vector2 = enemy.global_position
	await _await_frames(30)
	var speed: float = start.distance_to(enemy.global_position) / (30 * PHYS_DT)
	assert_almost_eq(speed, CHASE_SPEED, 4.0,
			"追击实测速率应≈48px/s，实为 %.1f px/s" % speed)
	assert_true(speed > PATROL_SPEED + 8.0, "追击速应明显快于巡逻速 32px/s")


# =============== D. 放弃双阈值 ===============

func test_拉开6tile放弃_视野圈内仍追() -> void:
	# 玩家放面朝方向正前 48px 触发 CHASE；瞬移 80px（64~96 之间：已脱视野
	# 未脱放弃圈）→ 继续追；再瞬移 ~195px（>6 tile=96px）→ 放弃转 RETURN
	var enemy := _spawn_enemy(Vector2(3200, 3000), "e_giveup", "g1",
			[Vector2(8, 0)] as Array[Vector2])
	var player := _spawn_player(Vector2(3248, 3000))
	await _await_frames(5)
	assert_eq(enemy._state, enemy.State.CHASE, "前置：CHASE")
	player.global_position = Vector2(3280, 3000)  # ~80px：放弃圈内，继续追
	await _await_frames(3)
	assert_eq(enemy._state, enemy.State.CHASE, "80px（<96px）应继续追不放弃")
	player.global_position = Vector2(3400, 3000)  # ~195px > 96px：拉开放弃
	await _await_frames(3)
	assert_eq(enemy._state, enemy.State.RETURN, "拉开超 6 tile 应放弃转 RETURN")


func test_被墙卡住1点5秒放弃_端到端() -> void:
	# 真实墙（层 1）隔在敌与玩家之间：追击撞墙真实速度≈0 持续 1.5s → RETURN
	# 触发链（墙先入树，规避静态体注册延迟）：
	#   帧 0~5 玩家放正前 48px 视野内 → CHASE（此时敌人距墙 32px 未贴）；
	#   帧起追击东行 ~0.7s 撞墙贴死 → move_and_slide 真实速度≈0 →
	#   _stuck_time 累计 1.5s（90 帧）→ RETURN。
	# 玩家全程留在墙后 48px（<96px 放弃圈、>64px 视野圈）：既不触发
	# "拉开放弃"（贴墙期间距离 22~48px 反而在视野内，无影响——卡墙是
	# 第一优先迁移），也不会因提前拉远造成假阳性。
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 120)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	wall.position = Vector2(3332, 3000)
	autofree(wall)
	add_child_autofree(wall)
	var enemy := _spawn_enemy(Vector2(3300, 3000), "e_stuck", "g1",
			[Vector2(8, 0)] as Array[Vector2])
	var player := _spawn_player(Vector2(3348, 3000))
	await _await_frames(5)
	assert_eq(enemy._state, enemy.State.CHASE, "前置：面朝正前视野内触发 CHASE")
	assert_true(enemy.global_position.x < 3326.0, "前置：敌人尚未贴墙")
	# 逐帧计数贴墙帧数：贴墙（x 到达 3322 不再前进）累计 90 帧即 1.5s → RETURN
	var stuck_frames: int = 0
	var returned: bool = false
	for i: int in 400:
		await get_tree().physics_frame
		if enemy._state == enemy.State.RETURN:
			returned = true
			break
		if enemy.global_position.x >= 3321.5:
			stuck_frames += 1
	assert_true(returned, "卡墙累计 1.5s 应放弃转 RETURN（贴墙 %d 帧 ≈ %.2fs，终态 %d）" % [
			stuck_frames, stuck_frames / 60.0, enemy._state])


# =============== E. 回位精确 ===============

func test_回位吸附放置点并按waypoints归基态() -> void:
	# 巡逻敌被拉开触发 RETURN → 走回放置点精确吸附 → 转回 PATROL
	# 注：玩家拉到 200px（放弃圈外），回位途中不会再入视野触发重追
	var home := Vector2(3400, 3000)
	var enemy := _spawn_enemy(home, "e_return", "g1",
			[Vector2(8, 0)] as Array[Vector2])
	var player := _spawn_player(Vector2(3448, 3000))  # 面朝方向正前 48px
	await _await_frames(5)
	assert_eq(enemy._state, enemy.State.CHASE, "前置：CHASE")
	player.global_position = Vector2(3400, 3200)  # 200px 拉开（>放弃圈 96px）
	await _await_frames(3)
	assert_eq(enemy._state, enemy.State.RETURN, "前置：放弃转 RETURN")
	var arrived: bool = false
	for i: int in 240:
		if enemy.global_position == home:
			arrived = true
			break
		await get_tree().physics_frame
	assert_true(arrived, "回位应精确吸附放置点 %s，实为 %s" % [home, enemy.global_position])
	assert_eq(enemy._state, enemy.State.PATROL, "有 waypoints 回位后应归 PATROL")
	# GUARD 归位迁移规则：定守敌恒不自然迁出，用态直注进 RETURN 验证
	# "空 waypoints 回位后归 GUARD"（上一玩家 200px 外无干扰）
	var home_g := Vector2(3600, 3000)
	var guard := _spawn_enemy(home_g, "e_return_g", "g1")
	assert_eq(guard._state, guard.State.GUARD, "定守初始 GUARD（前置确认）")
	guard._set_state(guard.State.RETURN)
	guard.global_position = home_g + Vector2(40, 0)
	await _await_frames(3)
	var arrived_g: bool = false
	for i: int in 120:
		if guard.global_position == home_g:
			arrived_g = true
			break
		await get_tree().physics_frame
	assert_true(arrived_g, "RETURN 应吸附放置点（GUARD 归位路径）")
	assert_eq(guard._state, guard.State.GUARD, "空 waypoints 回位后应归 GUARD")


# =============== F. 定守不动 ===============

func test_定守态玩家贴脸仍零移动不追击() -> void:
	# GUARD 恒不追（"站位即交战位"，GDD §3.2 定守行）：玩家放正下 24px 视野内，
	# 敌人零位移、态恒 GUARD（接触战斗由 TouchArea 照常承担，不在本断言）
	var home := Vector2(3700, 3000)
	var guard := _spawn_enemy(home, "e_guard", "g1")
	_spawn_player(Vector2(3700, 3024))
	await _await_frames(40)
	assert_eq(guard._state, guard.State.GUARD, "定守态不得迁移")
	assert_eq(guard.global_position, home, "定守态玩家贴脸也不得移动（零位移）")


# =============== G. 敌间互穿（边缘情况 1 行为级） ===============

func test_敌间互穿_对穿巡逻互不阻挡() -> void:
	# 两敌同走廊相向巡逻：mask 不含敌层 8（E2-S2 静态断言）→ 行为级对穿：
	# 各自保持移动不被对方卡停，位置交错而过
	var a := _spawn_enemy(Vector2(3800, 3000), "e_pass_a", "g1",
			[Vector2(64, 0)] as Array[Vector2])
	var b := _spawn_enemy(Vector2(3864, 3016), "e_pass_b", "g1",
			[Vector2(-64, 0)] as Array[Vector2])
	await _await_frames(30)
	var a_x1: float = a.global_position.x
	var b_x1: float = b.global_position.x
	await _await_frames(30)
	# 双方持续推进（若互挡会卡停：x 采样不变）
	assert_ne(a.global_position.x, a_x1, "敌 A 应持续巡逻不被敌 B 卡停")
	assert_ne(b.global_position.x, b_x1, "敌 B 应持续巡逻不被敌 A 卡停")
	assert_true(a_x1 > 3800.0, "敌 A 应沿路径推进")


# =============== H. 战后免疫配合 ===============

func test_免疫期接触放行且CHASE不被打断() -> void:
	# E3 口径：免疫期接触判定放行（不发射载荷）。S4 视角：追击中贴脸接触
	# 放行后态机不被打断（仍 CHASE 继续压进，免疫过了再触发战斗）
	var enemy := _spawn_enemy(Vector2(3900, 3000), "e_immu", "g1")
	var player := _spawn_player(Vector2(3900, 3030))
	await _await_frames(3)
	assert_eq(enemy._state, enemy.State.GUARD, "空 waypoints 应 GUARD（贴脸不追）")
	# 换巡逻敌验证 CHASE 中免疫接触：玩家放面朝方向正前 48px（视野内触发）
	var enemy2 := _spawn_enemy(Vector2(3900, 3100), "e_immu2", "g1",
			[Vector2(8, 0)] as Array[Vector2])
	var player2 := _spawn_player(Vector2(3948, 3100))
	await _await_frames(5)
	assert_eq(enemy2._state, enemy2.State.CHASE, "前置：CHASE")
	player2.start_encounter_immunity(10.0)
	var fired: Array[Dictionary] = []
	var cb := func(p: Dictionary) -> void: fired.append(p)
	EventBus.enemy_touched.connect(cb)
	enemy2._handle_player_contact(player2)  # 免疫期接触 → 应放行不发射
	var during: int = fired.size()
	assert_eq(during, 0, "免疫期接触不得发射战斗载荷")
	assert_eq(enemy2._state, enemy2.State.CHASE, "免疫放行不得打断追击态")
	player2.encounter_immunity = 0.0  # 直清字段：start_encounter_immunity 幂等取大，0.0 清不掉
	enemy2._handle_player_contact(player2)  # 免疫结束后接触 → 应正常发射
	var after: int = fired.size()
	EventBus.enemy_touched.disconnect(cb)
	assert_eq(after, 1, "免疫结束后接触应正常发射载荷")
