extends Node2D
## ruins_f1_map.gd —— E4-S3 遗迹一层地图根脚本（克隆 road_map.gd 简版结构）
##
## 【需求依据】探索 GDD §3.1 f1 行（56×44、B3 巡逻+追击、教学探索）+ §3.2 + §3.4。
## 本 Story 范围：地图本体 + B3 敌人摆位 + 相机限区 + spawn 落位。
## 传送接线（from_road / to_f2）与进图自动存档归 E4-S6（TODO 见下）。
##
## 【E4-S6 增量】传送接线 + 进图自动存档（TODO(E4-S6) 三条逐一落实）：
##   1. Triggers 容器挂 trigger_teleport（from_road 南门 / to_f2 北口，目录驱动）；
##   2. _ready 尾部 AutosaveNotifier.announce_ready()（§3.4 精确时序）；
##   3. spawn 双入口由传送目录 to_spawn 落位（南门 (27.5,3.5) / 北口返程 (27.5,41.5)）。

## 相机限区：主图 56×44 tile = 896×704 px
@export var limits_main: Rect2i = Rect2i(0, 0, 896, 704)

## from_road 出生落位（入口 2×2 空地预留区中央偏南，参考格 (27.5,3.5)）
@export var pos_from_road: Vector2 = Vector2(448, 56)

## 对话运行器引用位（遗迹图无对话装配；预留接口名与 town_map 对齐，防测试侧空引用）
var dialogue_runner: Node = null
var interaction_controller: Node = null

## E4-S5 内容点位装配产物（{"chests": Array, "investigates": Array}，测试对表用）
var content_points: Dictionary = {}

## E4-S6 传送触发器装配产物（Array[Area2D]，测试对表用）
var teleports: Array = []

## M7-R8（O-5）：入口剧情锚点（Area2D 薄壳，测试对表用；未接线时 null）
var ruin_enter_anchor: Area2D = null

const TeleportAssembler := preload("res://scripts/events/teleport_assembler.gd")
const AutosaveNotifier := preload("res://scripts/events/autosave_notifier.gd")
## M7-R8（O-5 修复）：入口剧情锚点装配（story_ruin_enter 触发端——生产侧
## 唯一缺失端，自然游玩 phase 1→2 断链的根因）。同族范式：f3 Boss 锚
## （全局 executor 单例 + 薄壳递 id）× town P0 锚（双守卫防 GUT 自开演）。
const EventLoader := preload("res://scripts/events/event_loader.gd")
const ShellScript := preload("res://scripts/events/trigger_event_shell.gd")
const RUIN_ENTER_EVENT_ID: String = "story_ruin_enter"
const RUIN_ENTER_TRIGGER_NAME: String = "Evt_Ruin_Enter"


func _ready() -> void:
	var player: CharacterBody2D = $YSorted/Player
	_apply_limits(player.get_node("Camera2D"), limits_main)
	# E4-S5：内容点位装配（3 宝箱 + 4 调查点，数据/装配见 scripts/events/）
	const MapEvents := preload("res://scripts/events/map_events.gd")
	content_points = MapEvents.assemble(self, "ruins_f1")
	# E4-S6：传送装配（from_road / to_ruins_f2；遗迹图无对话装配，runner=null）
	teleports = TeleportAssembler.assemble(self, "ruins_f1", null)
	# E4-S6：进图自动存档（map_ready 广播 + save + 图标，§3.4 时序收口）
	AutosaveNotifier.announce_ready(self, "ruins_f1")
	# M7-R8（O-5 修复）：入口剧情锚点（story_ruin_enter 触发端，phase 1→2）
	_assemble_ruin_enter_anchor()


func _apply_limits(cam: Camera2D, rect: Rect2i) -> void:
	cam.limit_left = rect.position.x
	cam.limit_top = rect.position.y
	cam.limit_right = rect.position.x + rect.size.x
	cam.limit_bottom = rect.position.y + rect.size.y


## M7-R8（O-5 修复）：入口剧情锚点装配（对话 GDD §3.3 切换点 2 生产端）。
## 【缺陷正本】story_ruin_enter 此前只有数据侧登记（story_anchor.json）与
## 测试侧直驱（e5s4/e5s5），生产侧零触发端——自然游玩 phase 恒 1，B5 Boss
## 链断链。本函数补齐触发端：踩踏面（南门入图落位格）→ 薄壳递 id →
## 全局 executor（phase>=1 门闸在事件数据侧，重触发零动作）。
##
## 【装配三选一同 f3】loader 轻量按需自建（纯数据缓存）；executor 取
## SceneRouter 全局单例（battle 簿记跨场景存活的同一载体，与 f3 Boss 锚
## 同源）；runner 用 UILayer 常驻实例（town 装配、跨图复用，rebind_player
## 由 f3 _assemble_interaction 先例承担；无则 null——dialogue 动作被执行器
## 静默跳过，set_story_phase 照常生效，降级不炸链）。
##
## 【双守卫——为何不能无条件装配】同 town P0 锚口径：GUT 直挂 f1 的用例
## （e2s4/e4s3/e4s5/e4s6）玩家场景默认位恰在入口格 (448,56)，无条件接线
## 会在测试树里 body_entered 自动开演 P2 剧情并置 phase=2，污染存量断言
## （净增不改旧纪律）。故：
##   ① 生产启动守卫：current_scene 必须是 Main 本体（生产 F5 运行时恒
##     成立；GUT 用例树/冒烟包装器/演示替身的 current_scene 均非 Main）。
##   ② 事件层守卫：事件表未登记 story_ruin_enter 时降级不接线（数据缺失
##     降级口径，同薄壳 _emit_event 未登记跳过）。
func _assemble_ruin_enter_anchor() -> void:
	var cs: Node = get_tree().current_scene if is_inside_tree() else null
	if cs == null or cs.name != "Main":
		print("[RuinsF1Map] 非生产启动语境（current_scene=%s），入口锚不接线" % [
				String(cs.name) if cs != null else "<null>"])
		return
	var loader: RefCounted = EventLoader.new()
	loader.load_all()
	if not loader.has_event(RUIN_ENTER_EVENT_ID):
		push_warning("[RuinsF1Map] 事件表无 %s，入口锚降级不接线" % RUIN_ENTER_EVENT_ID)
		return
	var executor: RefCounted = SceneRouter.global_event_executor
	var runner: Node = null
	if is_inside_tree():
		runner = get_tree().root.get_node_or_null("Main/UILayer/DialogueRunner")
	var container: Node = get_node_or_null("Triggers")
	if container == null:
		push_warning("[RuinsF1Map] 无 Triggers 容器，入口锚装配跳过")
		return
	var trigger: Area2D = Area2D.new()
	trigger.set_script(ShellScript)
	trigger.name = RUIN_ENTER_TRIGGER_NAME
	trigger.event_id = RUIN_ENTER_TRIGGER_NAME
	trigger.new_event_id = RUIN_ENTER_EVENT_ID
	trigger.setup(loader, executor, runner)
	trigger.collision_layer = 0
	trigger.collision_mask = 16   # 玩家实体层（TeleportAssembler 同口径）
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(32, 32)   # 入口预留格 2x2 全覆盖（出生落位即重叠触发）
	shape_node.shape = rect
	trigger.add_child(shape_node)
	trigger.position = pos_from_road   # (448,56) = 南门入图落位正本（同 P0 出生锚位）
	container.add_child(trigger)
	ruin_enter_anchor = trigger
	print("[RuinsF1Map] 入口剧情锚点装配完成：%s -> 事件 %s（踩踏@%s）" % [
			RUIN_ENTER_TRIGGER_NAME, RUIN_ENTER_EVENT_ID, trigger.position])
