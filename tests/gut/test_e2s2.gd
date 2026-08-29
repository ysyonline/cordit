extends GutTest
## E2-S2 可见敌人节点 + 巡逻/接触（TASK-S2-07）
##
## 断言覆盖（EPIC-2.md E2-S2 三条验收标准的自动化部分）：
##   A. 巡逻位移数学：恒速 2 tile/s = 32 px/s、到点精确吸附、循环回卷、
##      驻守态（空 waypoints）零移动——用真实物理帧驱动（move_and_slide
##      内部按物理 tick 1/60 积分，手动步进会与引擎时序错位，故全部
##      await physics_frame 等真物理跑）；
##   B. 接触遇敌：BattlePayload 四字段（A5）全部正确——编组 id / 返回图 /
##      回置点（敌人反向外侧一格，主导轴四向判定）/ 击破凭据 uid；
##      重复接触防重 + 离开复位；返回图回退链；"只认 CharacterBody2D"过滤；
##   C. 碰撞矩阵：敌人 layer=8/mask=17（墙|玩家，敌间互不挡）、TouchArea
##      mask=16（仅玩家）、玩家 layer=16/mask=9（墙|敌人）——层位组合断言；
##   D. waypoints 双输入：export 数组与 Waypoints/Marker2D 子节点序列合并。
##
## 【测试策略】与 E2-S1 同纪律：不实例化 main.tscn（避 SceneRouter/Tween
##   与 SMK-01 互踩）；敌人实例先设属性与位置再入树（_ready 快照放置点
##   作巡逻基准）；接触断言直接调 _handle_player_contact（不经物理帧时序）；
##   真机巡逻手感与敌间重叠视觉留人眼（fixture map_e2s2.tscn 供跑图验收）。
##
## 跑法（项目根下）：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const ENEMY_SCENE_PATH: String = "res://scenes/enemies/visible_enemy.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/player.tscn"
const FIXTURE_MAP_PATH: String = "res://tests/smoke/fixtures/map_e2s2.tscn"

## 恒速口径：2 tile/s = 32 px/s（探索 GDD §3.2）
const EXPECTED_SPEED: float = 32.0

## 物理帧时长（项目物理 tick 默认 1/60）
const PHYS_DT: float = 1.0 / 60.0

## 接触捕获槽（EventBus.enemy_touched 回调写入）
var _recv_payload: Variant = null


func before_each() -> void:
	_recv_payload = null


## 实例化敌人：先设属性与位置、后入树（_ready 以入树时位置为巡逻基准）
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


## 捕获 enemy_touched 载荷
func _on_enemy_touched(p: Dictionary) -> void:
	_recv_payload = p


## 等待敌人到达目标点（真实物理帧驱动）；超时返回 false（供吸附断言前置）
func _await_arrival(enemy: Node2D, target: Vector2, max_frames: int) -> bool:
	for i: int in max_frames:
		if enemy.global_position == target:
			return true
		await get_tree().physics_frame
	return enemy.global_position == target


## 等待 N 个物理帧
func _await_frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


# =============== A. 巡逻位移数学 ===============

func test_巡逻恒速每帧位移与循环回卷() -> void:
	# 从 (0,0) 巡逻到 (48,0)：前 30 帧（0.5s）应走约 16px（32px/s 口径，
	# 容差 ±1px 覆盖 await 与物理 tick 的对齐误差）；随后应在远端点附近
	# 掉头（回卷目标 = 出发点），x 不越过远端点（吸附防过冲）
	var enemy := _spawn_enemy(Vector2.ZERO, "e1", "g1",
			[Vector2(48, 0)] as Array[Vector2])
	var start: Vector2 = enemy.global_position
	await _await_frames(30)
	var moved: float = (enemy.global_position - start).length()
	assert_almost_eq(moved, EXPECTED_SPEED * 0.5, 1.0,
			"0.5s 应位移约 16px（2 tile/s 恒速），实为 %.2f px" % moved)
	# 到达远端后回卷：x 不越过 48（吸附），且最终掉头向出发点（x 递减）
	await _await_frames(45)  # 再跑 0.75s：足够完成到达+吸附+回卷起步
	assert_true(enemy.global_position.x <= 48.0,
			"x 不得越过远端点（吸附防过冲），实为 %s" % enemy.global_position)
	assert_true(enemy.global_position.x >= 0.0,
			"回卷后应朝出发点行进，实为 %s" % enemy.global_position)


func test_单点巡逻自动补全为两点往返() -> void:
	# 只配 1 个点 = "放置点 ↔ 远端点"往返（地图作者直觉写法）；
	# 不补全会退化成"到达远端后目标=自身"永久卡死（回归防线用例）。
	# 注：吸附是瞬态（到达即切向下一目标），精确落点不可观测，
	# 用"区间内 + 持续运动"断言。
	var enemy := _spawn_enemy(Vector2(0, 0), "e_single", "g1",
			[Vector2(32, 0)] as Array[Vector2])
	assert_eq(enemy.get_current_target(), Vector2(32, 0), "单点应指向远端点")
	# 0.5s：应向远端点推进中（在两点之间）
	await _await_frames(30)
	var x_early: float = enemy.global_position.x
	assert_true(x_early > 0.0 and x_early < 32.0,
			"0.5s 应在两点之间推进，实为 %.2f" % x_early)
	# 1.5s：单程 1.0s + 余量，应已折返，x 永不越过两端（吸附防越界）
	await _await_frames(60)
	var x_late: float = enemy.global_position.x
	assert_true(x_late >= 0.0 and x_late <= 32.0,
			"应始终在两点区间内，实为 %.2f" % x_late)
	# 卡死防线：再采样 x 必变化（无补全时永久停在 32 不动）
	await _await_frames(3)
	assert_ne(enemy.global_position.x, x_late, "巡逻不得停摆（单点补全回归防线）")


func test_巡逻到点吸附无过冲() -> void:
	# 短段往返：(100,100) ↔ (110,100)（10px 单程 19 帧），跑 120 帧
	# （约 3 个来回）后位置必须仍在两点区间内——任何过冲都会越出区间
	var enemy := _spawn_enemy(Vector2(100, 100), "e2", "g1",
			[Vector2(10, 0)] as Array[Vector2])
	await _await_frames(120)
	var x: float = enemy.global_position.x
	assert_true(x <= 110.0 and x >= 100.0,
			"多回合往返后仍应在两点区间内（吸附防过冲），实为 %.2f" % x)
	# 持续运动防线：任意两采样点 x 必不同（卡死即恒等）
	await _await_frames(3)
	assert_ne(enemy.global_position.x, x, "巡逻不得停摆")


func test_空巡逻点驻守零移动() -> void:
	# 空 waypoints = 定守（探索 GDD §3.2 三态兼容），物理帧跑起来也不动
	var enemy := _spawn_enemy(Vector2(50, 50), "e3", "g1")
	await _await_frames(20)
	assert_eq(enemy.global_position, Vector2(50, 50), "驻守态不得移动")


# =============== B. 接触遇敌（A5 载荷） ===============

func test_接触载荷四字段全部正确() -> void:
	# 玩家在敌人南侧接触：回置点 = 敌人南侧（来向侧）外推一格 (0,+16)
	EventBus.enemy_touched.connect(_on_enemy_touched)
	var enemy := _spawn_enemy(Vector2(200, 200), "enemy_x_01", "slime_01")
	enemy.return_map = "res://tests/smoke/fixtures/map_e2s2.tscn"
	enemy._handle_player_contact(_fake_body(Vector2(200, 232)))
	EventBus.enemy_touched.disconnect(_on_enemy_touched)
	assert_not_null(_recv_payload, "enemy_touched 应被发射")
	if _recv_payload == null:
		return
	var p: Dictionary = _recv_payload
	# 逐字段核对（A5 协议：与 SceneRouter.PAYLOAD_FIELDS 同源四字段）
	assert_eq(p.get("enemy_group_id"), "slime_01", "编组 id 错")
	assert_eq(p.get("return_map"), "res://tests/smoke/fixtures/map_e2s2.tscn", "返回图错")
	assert_eq(p.get("return_position"), Vector2(200, 216),
			"回置点应为敌人来向侧外推一格（南来 → 南侧一格）")
	assert_eq(p.get("defeat_enemy_uid"), "enemy_x_01", "击破凭据 uid 错")
	# 类型抽查：return_position 必须是 Vector2（Router 校验拒绝 Vector2i 冒充）
	assert_typeof(p.get("return_position"), TYPE_VECTOR2, "return_position 应为 Vector2")


func test_回置点主导轴四向判定() -> void:
	# 玩家从东/西/南/北四向接近：回置点 = 敌人位置沿主导轴向玩家侧外推一格
	# （基准是敌人：y 分量取敌人 y=200；外推方向 = 玩家来向）
	var cases := [
		{"player": Vector2(232, 208), "expect": Vector2(216, 200)},  # 东来 → 回东侧
		{"player": Vector2(168, 208), "expect": Vector2(184, 200)},  # 西来 → 回西侧
		{"player": Vector2(200, 240), "expect": Vector2(200, 216)},  # 南来 → 回南侧
		{"player": Vector2(200, 176), "expect": Vector2(200, 184)},  # 北来 → 回北侧
	]
	for c: Dictionary in cases:
		EventBus.enemy_touched.connect(_on_enemy_touched)
		var enemy := _spawn_enemy(Vector2(200, 200), "e_axis", "g1")
		enemy.return_map = "map_stub"
		enemy._handle_player_contact(_fake_body(c["player"]))
		EventBus.enemy_touched.disconnect(_on_enemy_touched)
		var p: Dictionary = _recv_payload
		assert_not_null(p, "用例 %s 应发射载荷" % [c["player"]])
		if p != null:
			assert_eq(p.get("return_position"), c["expect"],
					"玩家自 %s 接触，回置点应为 %s，实为 %s" % [
					c["player"], c["expect"], p.get("return_position")])


func test_重复接触防重_离开后复位() -> void:
	EventBus.enemy_touched.connect(_on_enemy_touched)
	var enemy := _spawn_enemy(Vector2(300, 300), "e_dup", "g1")
	enemy.return_map = "map_stub"
	var body := _fake_body(Vector2(300, 320))
	enemy._handle_player_contact(body)
	var first: Variant = _recv_payload
	enemy._handle_player_contact(body)  # 重叠期间二次接触
	EventBus.enemy_touched.disconnect(_on_enemy_touched)
	assert_not_null(first, "首次接触应发射")
	assert_true(_recv_payload == first, "重叠期间重复接触不得重复发射")
	# 玩家离开接触区 → 锁复位 → 可再次触发
	enemy._on_touch_area_body_exited(body)
	_recv_payload = null
	EventBus.enemy_touched.connect(_on_enemy_touched)
	enemy._handle_player_contact(body)
	EventBus.enemy_touched.disconnect(_on_enemy_touched)
	assert_not_null(_recv_payload, "离开后再次接触应可重新触发")


func test_返回图回退链_导出值优先_路由簿记兜底() -> void:
	# return_map 留空 → 回退 SceneRouter.current_scene_path
	# （GUT 环境无地图装载簿记，此值为空串 → 载荷带空串并告警，Router 终审拒绝）
	EventBus.enemy_touched.connect(_on_enemy_touched)
	var enemy := _spawn_enemy(Vector2(100, 100), "e_fb", "g1")
	enemy._handle_player_contact(_fake_body(Vector2(100, 120)))
	EventBus.enemy_touched.disconnect(_on_enemy_touched)
	var p: Dictionary = _recv_payload
	assert_not_null(p, "载荷应照常发射（Router 是最终闸门）")
	if p != null:
		assert_eq(p.get("return_map"), SceneRouter.current_scene_path,
				"return_map 留空时应回退 Router 簿记")


func test_敌人节点带全部导出量与触摸区() -> void:
	# 结构断言：enemy_uid/group_id/return_map/waypoints 可赋值，TouchArea 配置正确
	var enemy := _spawn_enemy(Vector2.ZERO, "e_struct", "g2")
	assert_eq(enemy.enemy_uid, "e_struct", "enemy_uid 导出量可用")
	assert_eq(enemy.group_id, "g2", "group_id 导出量可用")
	assert_true(enemy.has_node("TouchArea"), "应有 TouchArea 接触判定区")
	var area: Area2D = enemy.get_node("TouchArea") as Area2D
	assert_not_null(area, "TouchArea 应为 Area2D")
	assert_eq(area.collision_mask, 16, "TouchArea 只认玩家实体层 16")


func test_接触过滤_只认CharacterBody2D() -> void:
	# body_entered 过滤：非 CharacterBody2D（如 StaticBody2D 标靶）不触发
	var enemy := _spawn_enemy(Vector2(400, 200), "e_filter", "g1")
	EventBus.enemy_touched.connect(_on_enemy_touched)
	enemy._on_touch_area_body_entered(_static_probe())
	EventBus.enemy_touched.disconnect(_on_enemy_touched)
	assert_null(_recv_payload, "非 CharacterBody2D 进入不得触发遇敌")


func test_真实玩家实例触发接触区回调() -> void:
	# 真实玩家场景实例（layer=16）走 body_entered 同签名回调，验证贯通
	var enemy := _spawn_enemy(Vector2(400, 240), "e_real", "g1")
	enemy.return_map = "map_stub"
	var player: CharacterBody2D = (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	autofree(player)
	add_child_autofree(player)
	player.global_position = Vector2(400, 240)
	EventBus.enemy_touched.connect(_on_enemy_touched)
	enemy._on_touch_area_body_entered(player)
	EventBus.enemy_touched.disconnect(_on_enemy_touched)
	assert_not_null(_recv_payload, "玩家实体进入应触发载荷发射")
	if _recv_payload != null:
		assert_eq((_recv_payload as Dictionary).get("defeat_enemy_uid"), "e_real",
				"真实玩家通路击破凭据应为敌人 uid")


# =============== C. 碰撞矩阵（层位静态断言） ===============

func test_碰撞矩阵_敌间无碰撞_敌与玩家地形有碰撞() -> void:
	var enemy := _spawn_enemy(Vector2.ZERO, "e_layer", "g1")
	# 敌人脚部：layer=8（敌人实体）；mask=17（层1墙体|层16玩家）
	assert_eq(enemy.collision_layer, 8, "敌人脚部应位于敌人实体层 8")
	assert_eq(enemy.collision_mask, 17,
			"敌人应与墙体(1)和玩家(16)碰撞；mask 不含 8 → 敌间互不挡（GDD 边缘情况 1）")
	assert_eq(enemy.collision_mask & 8, 0, "敌人 mask 不得含敌人层 8（敌间互穿）")
	assert_eq(enemy.collision_mask & 1, 1, "敌人应被世界墙体挡（层 1）")
	assert_eq(enemy.collision_mask & 16, 16, "敌人应与玩家实体碰撞（层 16）")
	# 玩家侧：layer=16；mask=9（层1墙体|层8敌人）
	var player: CharacterBody2D = (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	autofree(player)
	assert_eq(player.collision_layer, 16, "玩家应位于玩家实体层 16（敌人 TouchArea 依赖）")
	assert_eq(player.collision_mask, 9,
			"玩家应撞墙(1)且被敌人挡(8)")
	assert_eq(player.collision_mask & 8, 8, "玩家应被敌人实体挡（层 8）")


func test_测试场fixture含两名敌人与玩家挂载() -> void:
	# fixture 静态结构：E2-S2 测试场存在、两名敌人 uid 正确、玩家挂载器在
	assert_true(ResourceLoader.exists(FIXTURE_MAP_PATH, "PackedScene"),
			"E2-S2 测试场 fixture 缺失")
	var packed: PackedScene = load(FIXTURE_MAP_PATH) as PackedScene
	var map: Node = packed.instantiate()
	autofree(map)
	var uid_list: Array[String] = []
	for child: Node in map.get_node("YSorted").get_children():
		if "enemy_uid" in child:
			uid_list.append(String(child.get("enemy_uid")))
	assert_has(uid_list, "enemy_e2s2_a", "测试场应有巡逻敌人 A")
	assert_has(uid_list, "enemy_e2s2_b", "测试场应有巡逻敌人 B")
	assert_not_null(map.get_node_or_null("TempPlayerMount"), "测试场应有玩家挂载器")
	assert_not_null(map.get_node_or_null("PlayerSpawn"), "测试场应有出生点")


# =============== D. waypoints 双输入合并 ===============

func test_waypoints_导出数组与节点序列合并() -> void:
	var packed: PackedScene = load(ENEMY_SCENE_PATH) as PackedScene
	var enemy: CharacterBody2D = packed.instantiate()
	autofree(enemy)
	enemy.waypoints = [Vector2(16, 0), Vector2(32, 0)] as Array[Vector2]
	var wp_container := Node2D.new()
	wp_container.name = "Waypoints"
	enemy.add_child(wp_container)
	var m1 := Marker2D.new()
	m1.position = Vector2(48, 0)
	wp_container.add_child(m1)
	var m2 := Marker2D.new()
	m2.position = Vector2(0, 16)
	wp_container.add_child(m2)
	enemy.position = Vector2(500, 500)
	add_child_autofree(enemy)
	# 合并后共 4 点：export 两点在前，Marker2D 序列在后（顺序即巡逻序）
	assert_eq(enemy.get_current_target(), Vector2(516, 500), "第 1 目标应为 export 第 1 点（相对放置点）")
	enemy._index = 2
	assert_eq(enemy.get_current_target(), Vector2(548, 500), "第 3 目标应为 Marker2D 第 1 点（节点序列并入）")
	enemy._index = 3
	assert_eq(enemy.get_current_target(), Vector2(500, 516), "第 4 目标应为 Marker2D 第 2 点")


## 造一个不进树的伪玩家体（只作接触回调的参数，读其 global_position）
func _fake_body(pos: Vector2) -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	autofree(body)
	body.position = pos
	return body


## 造一个静态体探针（验证接触过滤：StaticBody2D 不该触发遇敌）
func _static_probe() -> StaticBody2D:
	var probe: StaticBody2D = StaticBody2D.new()
	autofree(probe)
	probe.position = Vector2(400, 200)
	return probe
