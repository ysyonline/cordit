extends CharacterBody2D
## visible_enemy —— 可见敌人实体：巡逻 + 接触遇敌（E2-S2）
##
## 【需求依据】EPIC-2.md E2-S2 + 探索 GDD §3.2（三态中的"巡逻"态先行）+
## 架构 A5（BattlePayload 四字段）：
##   - 沿 waypoints 循环巡逻，恒速 2 tile/s = 32 px/s（16px tile 基准）；
##   - 与玩家碰撞盒相触 → 组装 BattlePayload 经 EventBus.enemy_touched 发出；
##     本节点只负责"发现与上报"，切入战斗由 SceneRouter/战斗场景消费（A5 解耦）。
##
## 【装配规格】与 player.tscn / npc.tscn 同款约定（美术线到位后仅换纹理）：
##   根节点 (0,0) = 脚底触地点（y-sort 排序基准，规则见 player.gd 头注释）；
##   ├── BodyRect   Sprite2D 载体     位置 (-8,-9)，绘制 x∈[-8,8] y∈[-18,0]，
##   │                               暗红占位矩形（D3 敌人包 Ars Notoria 入库后换皮）；
##   ├── Collision  CollisionShape2D  12x6 @ (0,-3)，只框"脚"（俯视惯例）；
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
##   与 E2-S2 派单一致）；列表为空 = 原地驻守（与后续"定守"态自然兼容）。
##
## 【边界】（A3/A5）：地图侧身份——只组装与发射载荷，不感知战斗场景、
##   不切场景（Router 职责）、不写 GameData；对话期间不触发的防误触
##   由地图侧统一裁决（切片内敌人只在道路/遗迹图，小镇无敌人，无耦合点）。
##   引用风格：preload 常量（不用全局 class_name，理由见
##   scripts/core/character_record.gd 头注释——项目规范，主理人已裁决采纳）。

## 巡逻速度：2 tile/s = 32 px/s（探索 GDD §3.2 钉定）
const PATROL_SPEED: float = 32.0

## 一格 = 16px（全项目 tile 基准，ADR-4 像素口径）
const TILE_SIZE: float = 16.0

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
## 空列表 = 原地驻守。与 Waypoints/Marker2D 子节点序列合并使用。
@export var waypoints: Array[Vector2] = []

## 接触后置位（防重叠期间重复发射）；玩家离开接触区后复位
var _engaged: bool = false

## 巡逻目标索引（指向 _points）
var _index: int = 0

## 敌人放置点世界坐标（_ready 快照；waypoints 偏移以此为基准）
var _home_position: Vector2 = Vector2.ZERO

## 合并后的巡逻点偏移列表（export 数组 + 节点序列，_ready 时定格）
var _points: Array[Vector2] = []


func _ready() -> void:
	# 敌人 uid 兜底取节点名（npc.gd 同款约定；地图锚点直摆即用）
	if enemy_uid.is_empty():
		enemy_uid = String(name)
	_home_position = global_position
	_collect_waypoints()
	var area: Area2D = get_node_or_null("TouchArea") as Area2D
	if area != null:
		area.body_entered.connect(_on_touch_area_body_entered)
		area.body_exited.connect(_on_touch_area_body_exited)
	print("[VisibleEnemy] 就绪：%s（编组 %s）巡逻点 %d 个" % [
			enemy_uid, group_id, _points.size()])


## 合并两路 waypoints 输入（export 数组在前，节点序列在后，依序巡逻）。
## 单点补全：只配 1 个点时自动把"放置点（零偏移）"补为第二点——
## 语义为"放置点 ↔ 远端点"两点往返（GDD"循环或往返"的地图作者直觉写法；
## 不补全会退化成"到达后目标=自身"的原地卡死）。
func _collect_waypoints() -> void:
	_points = []
	_points.assign(waypoints)
	var container: Node = get_node_or_null("Waypoints")
	if container != null:
		for child in container.get_children():
			if child is Marker2D:
				_points.append((child as Marker2D).position)
	if _points.size() == 1:
		_points.append(Vector2.ZERO)


## 当前巡逻目标的世界坐标（无巡逻点时返回自身位置）
func get_current_target() -> Vector2:
	if _points.is_empty():
		return global_position
	return _home_position + _points[_index]


func _physics_process(delta: float) -> void:
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
	move_and_slide()


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


## 接触处理：防重锁 + 组装 A5 四字段载荷 + EventBus 发射。
## 拆出公开方法供 GUT 直接驱动（不依赖物理帧时序）。
func _handle_player_contact(player: Node2D) -> void:
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
