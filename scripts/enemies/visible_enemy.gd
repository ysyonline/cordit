extends CharacterBody2D
## visible_enemy —— 可见敌人实体：巡逻 + 接触遇敌（E2-S2）
##
## 【需求依据】EPIC-2.md E2-S2 + 探索 GDD §3.2（三态中的"巡逻"态先行）+
## 架构 A5（BattlePayload 四字段）：
##   - 沿 waypoints 循环巡逻，恒速 2 tile/s = 32 px/s（16px tile 基准）；
##   - 与玩家碰撞盒相触 → 组装 BattlePayload 经 EventBus.enemy_touched 发出；
##     本节点只负责"发现与上报"，切入战斗由 SceneRouter/战斗场景消费（A5 解耦）。
##
## 【E4-S4 增量：三态完整 AI（探索 GDD §3.2 正本，无寻路）】
##   四态枚举 State：PATROL 巡逻 / GUARD 定守 / CHASE 追击 / RETURN 回位
##   （GUARD 即 GDD"定守"；RETURN 为工程回位过渡态，GDD"返回巡逻"的落地）。
##   - 巡逻：waypoints 循环，恒速 2 tile/s（沿 E2-S2）；
##   - 追击：PATROL 中玩家进 4 tile(64px) 且面朝 ±90°（点积≥0，含边界，
##     伪视野纯函数 _can_see，不设视线射线）→ 直线朝玩家移动，速 3 tile/s
##     = 48 px/s；GUARD 恒不迁出（"站位即交战位"）；
##   - 放弃（双阈值，GDD"卡墙 1.5s 或拉开 6 tile"）：①被墙卡住（move_and_slide
##     后真实速度≈0）累计 1.5s；②与玩家距离 > 6 tile(96px) → 转 RETURN；
##   - 回位：直线返回放置点（_home_position），到点吸附后按 waypoints 有无
##     归 PATROL/GUARD；追击放弃后玩家仍在视野内则再入 CHASE（甩掉敌人后
##     敌人会在放置点附近徘徊，天然形成"回到巡逻区"手感）；
##   - 无寻路算法——被墙挡住就卡住是可接受行为（GDD §3.2 原文）。
##
## 【装配规格】与 player.tscn / npc.tscn 同款约定（美术线到位后仅换纹理）：
##   根节点 (0,0) = 脚底触地点（y-sort 排序基准，规则见 player.gd 头注释）；
##   ├── BodyRect   Sprite2D 载体     位置 (-8,-9)，绘制 x∈[-8,8] y∈[-18,0]，
##   │                               暗红占位矩形（D3 敌人包 Ars Notoria 入库后换皮）；
##   ├── Collision  CollisionShape2D 12x6 @ (0,-3)，只框"脚"（俯视惯例）；
##   └── TouchArea  Area2D            16x14 @ (0,-7)：接触判定区，检测玩家实体进入。
##
## 【碰撞矩阵】（验收点"敌人间无碰撞、与玩家/地形有碰撞"，层位规划全项目约定）：
##   层位：1=世界墙体(含NPC脚)  2=交互物  4=y-sort遮挡物  8=敌人实体  16=玩家实体
##   - 敌人脚部（根节点）：collision_layer = 8，collision_mask = 1|16 = 17；
##     → 挡玩家（玩家 mask 含 8）、被墙/NPC 挡、被玩家挡（GDD 边缘情况 1
##     "仅与玩家/地形碰撞"）；敌人之间的层 8 不在彼此 mask → 可互相重叠穿过 ✓
##   - TouchArea：collision_layer = 0，collision_mask = 16（仅玩家实体层）；
##     → 墙/NPC/其他敌人进入不触发，只认玩家 ✓
##
## 【waypoints 定义】（探索 GDD §3.2"路径在场景内以节点序列定义"的落地）：
##   两种输入等价合并（都转成"相对敌人放置点的偏移"内部表示）：
##   ① @export waypoints: Array[Vector2]——检查器直填（推荐，相对偏移，px）；
##   ② 子节点序列——本节点下挂 Waypoints(Node2D) 容器，内放 Marker2D，
##     其 position（相对偏移）依序并入。地图作者按习惯二选一。
##   巡逻为【循环】模式：走完最后一个回到第一个（GDD"循环或往返"取循环，
##   与 E2-S2 派单一致）；列表为空 = 原地驻守（定守态）。
##
## 【边界】（A3/A5）：地图侧身份——只组装与发射载荷，不感知战斗场景、
##   不切场景（Router 职责）、不写 GameData；对话期间不触发的防误触
##   由地图侧统一裁决（切片内敌人只在道路/遗迹图，小镇无敌人，无耦合点）。
##   玩家定位用物理空间圆查询（mask 仅玩家实体层 16），不持玩家引用、
##   不 get_node 全树扫描。引用风格：preload 常量（不用全局 class_name，
##   理由见 scripts/core/character_record.gd 头注释——项目规范，主理人已裁决采纳）。

## 敌人 AI 状态（E4-S4 三态完整 AI；GUARD=GDD 定守，RETURN=工程回位过渡态）
enum State { PATROL, GUARD, CHASE, RETURN }

# ------------------------------------------------------------------
# 调参常量（16px tile 基准，ADR-4；全部来自探索 GDD §3.2 正本）
# ------------------------------------------------------------------

## 巡逻速度：2 tile/s = 32 px/s（探索 GDD §3.2 钉定）
const PATROL_SPEED: float = 32.0

## 追击速度：3 tile/s = 48 px/s（探索 GDD §3.2 钉定）
const CHASE_SPEED: float = 48.0

## 伪视野半径：4 tile = 64 px（追击触发，距离维）
const SIGHT_RANGE: float = 64.0

## 放弃距离：6 tile = 96 px（追击放弃阈值之一，距离维）
const GIVEUP_RANGE: float = 96.0

## 卡墙放弃阈值：真实速度≈0 累计 1.5s（追击放弃阈值之二，时间维）
const STUCK_GIVEUP_TIME: float = 1.5

## 一格 = 16px（全项目 tile 基准，ADR-4 像素口径）
const TILE_SIZE: float = 16.0

## 玩家实体层位（物理空间查询用；与 TouchArea mask、碰撞矩阵口径一致）
const PLAYER_LAYER_BIT: int = 16

# ------------------------------------------------------------------
# 导出量
# ------------------------------------------------------------------

## 敌人唯一标识（战胜后地图侧凭它从地图移除本节点；空则兜底取节点名）。
## 同图内必须唯一（如 "enemy_road_01"）。
@export var enemy_uid: String = ""

## 敌方编组 id（A5：战斗场景据此查 data/resources/enemies/*.tres；
## E2-S2 阶段仅占位传递，如 "slime_01"）
@export var group_id: String = ""

## 战斗结束后的返回地图场景路径（A5 return_map）。
## 地图作者摆放时填本图路径；留空则回退读 SceneRouter.current_scene_path
## （正常运行时即当前图；测试直挂场景树时两者皆空，仅告警不阻断）。
@export var return_map: String = ""

## 巡逻路径点（相对敌人放置点的偏移，px；推荐 tile 中心对齐即 16 的倍数）。
## 空列表 = 定守态（GUARD，站位即交战位）。与 Waypoints/Marker2D 子节点序列合并使用。
@export var waypoints: Array[Vector2] = []

# ------------------------------------------------------------------
# 运行时状态
# ------------------------------------------------------------------

## 当前 AI 态（迁移规则：PATROL→CHASE→RETURN→PATROL/GUARD；GUARD 恒不迁出）
var _state: State = State.PATROL

## 面朝方向（伪视野角度维基准；巡逻随移动方向更新，初始向下）
var _facing: Vector2 = Vector2.DOWN

## 接触后置位（防重叠期间重复发射）；玩家离开接触区后复位
var _engaged: bool = false

## 巡逻目标索引（指向 _points）
var _index: int = 0

## 敌人放置点世界坐标（_ready 快照；waypoints 偏移以此为基准，RETURN 目标）
var _home_position: Vector2 = Vector2.ZERO

## 合并后的巡逻点偏移列表（export 数组 + 节点序列，_ready 时定格）
var _points: Array[Vector2] = []

## 卡墙累计计时（CHASE 中真实速度≈0 时累加，达 1.5s 放弃）
var _stuck_time: float = 0.0


func _ready() -> void:
	# 敌人 uid 兜底取节点名（npc.gd 同款约定；地图锚点直摆即用）
	if enemy_uid.is_empty():
		enemy_uid = String(name)
	# 数据驱动防复活（E2-S4）：已被击破的敌人装载即自删——
	# "谁记得删节点"改为"集合里有的人自己消失"，读档/重进图天然生效
	if GameData.cleared_enemy_set.has(enemy_uid):
		print("[VisibleEnemy] %s 已在击破集合，装载即移除（不复活）" % enemy_uid)
		queue_free()
		return
	_home_position = global_position
	_collect_waypoints()
	# 初始态归位：有 waypoints 巡逻，空 waypoints 定守（E4-S4）
	_set_state(State.GUARD if _points.is_empty() else State.PATROL)
	var area: Area2D = get_node_or_null("TouchArea") as Area2D
	if area != null:
		area.body_entered.connect(_on_touch_area_body_entered)
		area.body_exited.connect(_on_touch_area_body_exited)
	print("[VisibleEnemy] 就绪：%s（编组 %s）巡逻点 %d 个 初始态 %s" % [
			enemy_uid, group_id, _points.size(), State.keys()[_state]])


# ------------------------------------------------------------------
# 态机（E4-S4；_physics_process 每帧：查玩家 → 迁移判定 → 按态移动）
# ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# 迁移判定前置：GUARD 恒不迁出（定守零行为，站位即交战位）
	if _state == State.GUARD:
		return
	# 感知：物理空间圆查询定位玩家（mask 仅玩家层 16；无玩家脱管则视为无目标）
	var player: Node2D = _find_player()
	var dist: float = INF if player == null else global_position.distance_to(player.global_position)

	match _state:
		State.PATROL:
			if player != null and dist <= SIGHT_RANGE and _can_see(player.global_position):
				_set_state(State.CHASE)
				return
			_move_patrol(delta)
		State.CHASE:
			# 放弃双阈值：拉开 >6 tile（距离维）→ RETURN
			if player == null or dist > GIVEUP_RANGE:
				_set_state(State.RETURN)
				return
			# 追击移动 + 卡墙计时（时间维）
			_move_chase(player.global_position, delta)
			if _stuck_time >= STUCK_GIVEUP_TIME:
				_set_state(State.RETURN)
				return
			# 追击中脱离视野不放弃（GDD 只按距离/卡墙两阈值放弃），
			# 保持直线追向最后已知位置由下一帧查询自然接管
		State.RETURN:
			# 回位途中玩家再入视野 → 重新追击（甩掉敌人后会在放置点附近徘徊）
			if player != null and dist <= SIGHT_RANGE and _can_see(player.global_position):
				_set_state(State.CHASE)
				return
			var to_home: Vector2 = _home_position - global_position
			if to_home.length() <= PATROL_SPEED * delta:
				global_position = _home_position  # 精确吸附放置点
				_stuck_time = 0.0
				_set_state(State.GUARD if _points.is_empty() else State.PATROL)
				return
			velocity = to_home.normalized() * PATROL_SPEED
			_facing = to_home.normalized()
			move_and_slide()  # 回位同样受墙阻挡（勿穿墙；卡死无迁移，等待玩家再入视野）


## 显式迁移口（唯一改态入口，测试与调试观测点）
func _set_state(next: State) -> void:
	if _state == next:
		return
	_state = next
	# 入态副作用：进追击清卡墙计时；离追击（放弃）亦清
	if next == State.CHASE:
		_stuck_time = 0.0
	elif next == State.RETURN:
		_stuck_time = 0.0


## 伪视野判定（纯逻辑，不依赖场景树；GDD"不设视线射线"）：
## 距离 ≤4 tile 且相对面朝方向 ±90°（点积 ≥0，边界含）→ 可见
func _can_see(target_pos: Vector2) -> bool:
	var to_target: Vector2 = target_pos - global_position
	if to_target.length() > SIGHT_RANGE:
		return false
	return _facing.dot(to_target.normalized()) >= 0.0


## 物理空间圆查询定位玩家（半径 = 放弃距离 96px，覆盖视野/放弃两判定圈）。
## 仅玩家实体层 16 可命中（与 TouchArea mask 同口径；层位正本：16=玩家实体
## 专属，敌人/NPC 均不入该层，故命中即玩家——项目无 player group 约定）。
## query 每敌每帧 1 次（切片内敌 ≤3，非热路径敏感）；查多体时取最近。
func _find_player() -> Node2D:
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GIVEUP_RANGE
	params.shape = circle
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = PLAYER_LAYER_BIT
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var hits: Array[Dictionary] = space.intersect_shape(params, 4)
	var best: Node2D = null
	var best_dist: float = INF
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is Node2D:
			var d: float = global_position.distance_to((collider as Node2D).global_position)
			if d < best_dist:
				best_dist = d
				best = collider
	return best


## 巡逻移动（E2-S2 沿革：到点吸附 + 循环回卷；面朝随移动方向更新）
func _move_patrol(delta: float) -> void:
	if _points.is_empty():
		return  # 驻守态：零速度零开销
	var target: Vector2 = get_current_target()
	var to_target: Vector2 = target - global_position
	var step: float = PATROL_SPEED * delta
	# 到点吸附：剩余距离小于一步时直接落点并切下一段（防高速过冲抖动）
	if to_target.length() <= step:
		global_position = target
		_index = (_index + 1) % _points.size()
		to_target = get_current_target() - global_position
	if to_target == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	velocity = to_target.normalized() * PATROL_SPEED
	_facing = to_target.normalized()
	move_and_slide()


## 追击移动：直线朝玩家（无寻路，GDD"被墙挡住就卡住是可接受行为"）。
## 卡墙判定：move_and_slide 后目标向真实速度≈0（被墙完全顶住，法向分量
## 被吃掉）累计计时——get_real_velocity 与意图速度同向比对，排除贴墙滑动
## 与角落抖动的假零速。
func _move_chase(player_pos: Vector2, delta: float) -> void:
	var to_player: Vector2 = player_pos - global_position
	if to_player == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	velocity = to_player.normalized() * CHASE_SPEED
	_facing = to_player.normalized()
	move_and_slide()
	# 卡墙检测：目标向真实速度分量（碰撞修正在法向，切向保留）；
	# 法向被墙完全顶住 → 该分量≈0 → 累计卡墙时间
	var real: Vector2 = get_real_velocity()
	var intent: Vector2 = to_player.normalized()
	var real_along: float = real.dot(intent)
	if real_along < CHASE_SPEED * 0.25:
		_stuck_time += delta
	else:
		_stuck_time = 0.0


# ------------------------------------------------------------------
# 巡罗点与目标查询（E2-S2 沿革）
# ------------------------------------------------------------------

## 合并两路 waypoints 输入（export 数组在前，节点序列在后，依序巡逻）。
## 单点补全：只配 1 个点时自动把"放置点（零偏移）"补为第二点——
## 语义为"放置点 ↔ 远端点"两点往返（GDD"循环或往返"的地图作者直觉写法；
## 不补全会退化成"到达后目标=自身"的原地卡死）。
func _collect_waypoints() -> void:
	_points = []
	_points.assign(waypoints)
	var container: Node = get_node_or_null("Waypoints")
	if container != null:
		for child: Node in container.get_children():
			if child is Marker2D:
				_points.append((child as Marker2D).position)
	if _points.size() == 1:
		_points.append(Vector2.ZERO)


## 当前巡逻目标的世界坐标（无巡逻点时返回自身位置）
func get_current_target() -> Vector2:
	if _points.is_empty():
		return global_position
	return _home_position + _points[_index]


# ------------------------------------------------------------------
# 接触遇敌（A5 载荷组装与发射）
# ------------------------------------------------------------------

## TouchArea 回调：仅玩家实体层能进入（mask=16 过滤），双保险再验类型
func _on_touch_area_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	_handle_player_contact(body)


func _on_touch_area_body_exited(body: Node2D) -> void:
	# 玩家离开接触区 → 解除交战锁（允许下次接触再次触发；
	# E2-S3 起真正遇敌会切场景，本锁主要防"重叠期间反复刷信号"）
	if body is CharacterBody2D:
		_engaged = false


## 接触处理：防重锁 + 玩家免疫放行 + 组装 A5 四字段载荷 + EventBus 发射。
## 拆出公开方法供 GUT 直接驱动（不依赖物理帧时序）。
func _handle_player_contact(player: Node2D) -> void:
	# 战后免疫（E2-S4）：玩家 start_encounter_immunity 期间接触不触发——
	# "战后回图立即再撞同一敌人不会秒进战斗"（探索 GDD §3.2）
	if player.has_method("is_encounter_immune") and player.is_encounter_immune():
		print("[VisibleEnemy] %s：玩家免疫中，接触放行" % enemy_uid)
		return
	if _engaged:
		return
	_engaged = true
	var payload: Dictionary = _build_payload(player.global_position)
	EventBus.enemy_touched.emit(payload)
	print("[VisibleEnemy] %s 接触遇敌 -> %s（回置点 %s）" % [
			enemy_uid, payload["enemy_group_id"], payload["return_position"]])


## 组装 BattlePayload（架构 A5 四字段，字段名/类型与 SceneRouter 校验表一致）：
##   enemy_group_id  → 编组 id（战斗侧查表键）
##   return_map      → 导出值 > SceneRouter 簿记 > 空串告警（Router 是最终闸门）
##   return_position → 敌人位置沿"玩家来向"外侧一格（探索 GDD §3.2 回置规则）：
##                     取玩家相对敌人的主导轴方向（四向对齐格点），外推 1 tile
##   defeat_enemy_uid→ 本敌人 uid（战胜后地图侧移除凭据）
func _build_payload(player_pos: Vector2) -> Dictionary:
	var away: Vector2 = player_pos - global_position
	var dir: Vector2
	if absf(away.x) >= absf(away.y):
		dir = Vector2.RIGHT if away.x >= 0.0 else Vector2.LEFT
	else:
		dir = Vector2.DOWN if away.y >= 0.0 else Vector2.UP
	var map_path: String = return_map
	if map_path.is_empty():
		map_path = SceneRouter.current_scene_path
		if map_path.is_empty():
			push_warning("[VisibleEnemy] %s：return_map 为空（导出值与 Router 簿记皆空），载荷将被 Router 拒绝" % enemy_uid)
	return {
		"enemy_group_id": group_id,
		"return_map": map_path,
		"return_position": global_position + dir * TILE_SIZE,
		"defeat_enemy_uid": enemy_uid,
	}
