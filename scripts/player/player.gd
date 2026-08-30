extends CharacterBody2D
## player —— 玩家角色：八向移动 / 碰撞 / 脚底原点 / 相机跟随（E1-S4）
##
## 【需求依据】架构 A6 + EPIC-1.md E1-S4：
##   CharacterBody2D + move_and_slide()；原点在脚底；移速 4-5 tile/s（本实现
##   4.5 tile/s = 72px/s，16px tile 基准）；0.15s 转向缓冲；Camera2D 跟随。
##
## ■■■ 全项目复用规则一：脚底原点（本节点已按此装配，勿破坏）■■■
##   player 根节点 (0,0) = 双脚触地点。视觉/交互/碰撞全部相对脚底上移：
##     - 占位矩形 16x18：rect position (-8, -18)（正式精灵到位后按此规格替换，
##       美术线 R2/R3 交付后只换 Sprite2D，本脚本与场景结构零改动）；
##     - 物理碰撞体 12x6：center (0, -3)，只框"脚"，墙可挡脚不挡头（俯视惯例）；
##     - 交互射线 InteractRay：从胸口 (0, -10) 指向面朝方向 20px；
##   y-sort 排序取节点自身 y（= 脚底），这是遮挡正确的根基。
##
## ■■■ 全项目复用规则二：y-sort 遮挡三条件（A6，E1-S4 实测沉淀）■■■
##   "角色站墙后/树后被正确遮挡"充要条件：
##   ① 角色与所有可站立遮挡物（墙/树/房子/柜台）挂在【同一个】
##      y_sort_enabled = true 的父容器（地图 YSorted 节点）下；
##   ② 每个遮挡物的节点原点在其【底边】（墙=墙基线，树=树干入土点）——
##      排序按各节点原点 y：角色脚底 y < 遮挡物基线 y ⇒ 角色在后、被遮挡；
##   ③ 所有参与者 z_index 相同（默认 0），禁用 z_index 手调破排序。
##   参考实现：tests/smoke/fixtures/map_a.tscn 的 YSorted 容器（墙/柱/玩家同层）。
##
## 【相机取舍】（A6 指定实测项，结论记于 player.tscn Camera2D 属性注释）：
##   position_smoothing 开（speed=8）+ position_smoothing.snap 关——平滑与
##   像素 snap 同开会互相打架（A6 预判）；全局防抖由 ADR-4 的
##   snap_2d_transforms_to_pixel 承担，缩放整数化由 ADR-4 stretch 承担。
##
## 【边界】（A3）：不感知场景路由（遇敌→切场景由触发器/EventBus 决定）；
##   不读写 GameData（队伍数据 EPIC-2 接入）；不持有任何游戏状态。

# ------------------------------------------------------------------
# 常量与调参（16px tile 基准，ADR-4 视口 640x360）
# ------------------------------------------------------------------

## 移动速度：4.5 tile/s = 72 px/s（E1-S4 钉定；手感人工验收，改这里即可调）
@export var move_speed: float = 72.0

## 转向缓冲时长（秒）：松开方向后按此时间保持原朝向——规避"按两下方向
## 原地抖"（A6）。期间无新输入则朝向复位。
const INPUT_BUFFER_TIME: float = 0.15

## 交互射线长度（px）：面前 1 格余量，E1-S6 交互用（本 Story 只装配不消费）
const INTERACT_RAY_LENGTH: float = 20.0

## 遮挡自检节流间隔（秒）：人眼无感的定时自检，非热路径
const OCCLUSION_CHECK_INTERVAL: float = 0.5

## 占位件规格（px）：16x18 竖版二头身角色占位；正式精灵到位后整体替换
const PLACEHOLDER_BODY_WIDTH: int = 16
const PLACEHOLDER_BODY_HEIGHT: int = 18

# ------------------------------------------------------------------
# 运行时状态
# ------------------------------------------------------------------

## 面朝方向（八向之一；移动时更新，松键后缓冲期内保持）
var facing: Vector2 = Vector2.DOWN

## 转向缓冲累计计时（秒）
var _facing_buffer: float = 0.0

## 遮挡自检节流计时（秒）
var _occlusion_timer: float = 0.0

## 上一帧位移（px/帧，供测试与调参观察；物理帧频率下 ≈ px/物理帧）
var _last_frame_displacement: Vector2 = Vector2.ZERO

## 测试注入口：非 ZERO 时优先于真实键盘（无头自验用；运行时保持 ZERO）
var _input_override: Vector2 = Vector2.ZERO

## 输入锁：true 时真实键盘与测试注入一并失效（移动向量强制 ZERO）。
## E1-S6 新增：对话期间移动锁定（A7）由 DialogueRunner 持有开关权。
## 默认 false——E1-S4/E1-S5 全部断言在解锁态下运行，行为零变化。
var is_input_locked: bool = false

## 遇敌免疫剩余秒数（E2-S4）：>0 期间接触判定放行（敌我互穿不触发战斗）。
## 探索 GDD §3.2 战后回置保护——0.5s 计时器由 BattleResultHandler 经
## start_encounter_immunity() 启动；E2-S2 的敌人接触判定消费本状态。
var encounter_immunity: float = 0.0

## 遮挡自检最近一次命中结果（SMK 观察用）
var _occluded_by: Node = null

# ------------------------------------------------------------------
# 生命周期
# ------------------------------------------------------------------

func _ready() -> void:
	# 顶层运动模式：俯视必须 FLOATING（默认 GROUNDED 是平台器语义，
	# 会引入地板吸附/单向判定，俯视下表现为莫名卡顿与斜坡滑落）
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cam: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.make_current()
	print("[Player] 就绪：脚底原点 / 72px/s / 0.15s 转向缓冲 / FLOATING 运动模式 / 输入锁就位")


func _physics_process(delta: float) -> void:
	# 遇敌免疫倒计时（E2-S4）：非负递减，归零即恢复可触敌
	if encounter_immunity > 0.0:
		encounter_immunity = maxf(encounter_immunity - delta, 0.0)
	var dir: Vector2 = _get_move_vector()
	_update_facing(dir, delta)
	velocity = dir * move_speed
	move_and_slide()
	_last_frame_displacement = velocity * delta
	_tick_occlusion_check(delta)


# ------------------------------------------------------------------
# 输入与朝向
# ------------------------------------------------------------------

## 取移动向量：测试注入优先，否则读输入动作 move_*（project.godot [input]）。
## Input.get_vector 已做斜向归一（长度≤1，斜走不超速）与死区处理。
## 输入锁开启时（对话期间，A7）一律返回 ZERO——锁优先级最高。
func _get_move_vector() -> Vector2:
	if is_input_locked:
		return Vector2.ZERO
	if _input_override != Vector2.ZERO:
		return _input_override.normalized()
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return v


## 转向缓冲：有输入 → 立即转朝向并清缓冲；无输入 → 缓冲期内保持原朝向，
## 超时复位。保证 E1-S6 交互"面前 1 格"判定不因松键抖动而漂移。
func _update_facing(dir: Vector2, delta: float) -> void:
	if dir != Vector2.ZERO:
		facing = dir.normalized()
		_facing_buffer = INPUT_BUFFER_TIME
	else:
		_facing_buffer = maxf(_facing_buffer - delta, 0.0)
		if _facing_buffer == 0.0:
			facing = Vector2.DOWN


# ------------------------------------------------------------------
# 遮挡自检（非 gameplay 依赖，自证 y-sort 规则生效；日志供冒烟观察）
# ------------------------------------------------------------------

## 定时自检：从"胸口"向"脚底"打一条向下的短射线（RayCast2D: InteractRay
## 之外另有 OcclusionRay），命中即表示脚下有遮挡物且自己画在其后面
## （y-sort 已把自己排前）。此射线只探 y-sort 遮挡物层（第 3 层），
## 不与墙体（第 2 层）交互——撞墙是 move_and_slide 的事，与遮挡无关。
func _tick_occlusion_check(delta: float) -> void:
	_occlusion_timer += delta
	if _occlusion_timer < OCCLUSION_CHECK_INTERVAL:
		return
	_occlusion_timer = 0.0
	var ray: RayCast2D = get_node_or_null("OcclusionRay") as RayCast2D
	if ray == null:
		return
	ray.force_raycast_update()
	if ray.is_colliding():
		var collider: Object = ray.get_collider()
		if collider != _occluded_by:
			_occluded_by = collider
			print("[Player] y-sort 自检：当前被 %s 遮挡（遮挡规则生效）" % collider.name)
	else:
		if _occluded_by != null:
			print("[Player] y-sort 自检：离开 %s 遮挡区" % _occluded_by.name)
		_occluded_by = null


# ------------------------------------------------------------------
# 对外接口（供后续系统与自动化测试调用）
# ------------------------------------------------------------------

## 是否在移动（位移感知：碰撞顶墙时 velocity 会被 move_and_slide 修正，
## 故以实际位移判定而非输入向量）
func is_moving() -> bool:
	return get_real_velocity().length_squared() > 0.01


## 面前交互目标（E1-S6 消费；无命中返回 null）。
## 射线排除遮挡物层（第 3 层，mask=4）：站在宝箱/敌人【后面】也能交互
## （俯视游戏惯例：按 y-sort 被遮挡 ≠ 不可交互）。
## 注意：命中任意物体即返回（含层 1 墙体）——"面前 1 格是墙不是 NPC"时
## 由调用方（interaction_controller）按目标协议过滤，player 不理解目标类型。
func get_interact_target() -> Object:
	var ray: RayCast2D = get_node_or_null("InteractRay") as RayCast2D
	if ray == null:
		return null
	ray.target_position = facing * INTERACT_RAY_LENGTH
	ray.force_raycast_update()
	return ray.get_collider() if ray.is_colliding() else null


## 测试注入：设置后忽略真实键盘（Vector2.ZERO 恢复正常输入）
func set_input_override(v: Vector2) -> void:
	_input_override = v.normalized() if v != Vector2.ZERO else Vector2.ZERO


## 启动遇敌免疫（E2-S4）：持续 duration 秒，期间敌人接触判定放行。
## 幂等取大：免疫期内再次调用不会缩短剩余时间（战后重叠触发场景）。
func start_encounter_immunity(duration: float) -> void:
	encounter_immunity = maxf(encounter_immunity, duration)


## 是否处于遇敌免疫中（敌人接触判定与 GUT 断言的统一查询口）
func is_encounter_immune() -> bool:
	return encounter_immunity > 0.0


## 输入锁开关（E1-S6）：对话系统持有；锁定时 set_input_override 注入同样失效。
func set_input_locked(locked: bool) -> void:
	is_input_locked = locked
	if locked:
		velocity = Vector2.ZERO


## 上一帧实际位移（px/物理帧，测试断言与调参观察用）
func get_last_frame_displacement() -> Vector2:
	return _last_frame_displacement
