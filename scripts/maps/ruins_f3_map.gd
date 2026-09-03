extends Node2D
## ruins_f3_map.gd —— E4-S3 遗迹三层（Boss 前厅）地图根脚本（克隆 road_map.gd 简版结构）
##
## 【需求依据】探索 GDD §3.1 f3 行（40×40、零普通敌人、Boss 事件触发）+ §3.4 + I5 接口。
## 本 Story 范围：地图本体（前厅 + 石棺祭坛 + 灰石 Boss 门构图）+ 相机限区 + spawn 落位。
## f3 零敌人：Boss 本体不放地图，由 Boss 事件 battle 动作召唤（I5，事件归 E5、接线归 E4-S6）。
## BossTriggers 锚点 ×2（棺前交互格）：E5 story_boss_pre 事件触发位（交互键，非踩踏）。
##
## 【E4-S6 增量】传送接线 + 进图自动存档（TODO(E4-S6) 三条逐一落实）：
##   1. Triggers 容器挂 trigger_teleport（from_f2 南门 + to_f2 返程同位复用，
##      目录驱动；f3 无北口——Boss 门封死构图，Boss 战走事件非地图出口）；
##   2. _ready 尾部 AutosaveNotifier.announce_ready()（§3.4 精确时序）；
##   3. spawn 单入口 from_f2(320,40)；Boss 战败读档回本位（E4-S7 兑现），
##      战后回城归 E5 I5 事件链（save_point/teleport 动作）。
## TODO(E5) story_boss_pre 事件挂接：BossTriggers 锚点 → I5 事件链（战前台词→battle b5_core→…）。
## 【E5-S5 增量】上条 TODO 兑现（见 _assemble_boss_anchor 注）。

## 相机限区：主图 40×40 tile = 640×640 px
@export var limits_main: Rect2i = Rect2i(0, 0, 640, 640)

## from_f2 出生落位（入口走廊中央，参考格 (19.5,2.5)）
@export var pos_from_f2: Vector2 = Vector2(320, 40)

## 对话运行器引用位（遗迹图无对话装配；预留接口名与 town_map 对齐，防测试侧空引用）
var dialogue_runner: Node = null
var interaction_controller: Node = null

## E4-S5 内容点位装配产物（{"chests": Array, "investigates": Array}，测试对表用）
var content_points: Dictionary = {}

## E4-S6 传送触发器装配产物（Array[Area2D]，测试对表用）
var teleports: Array = []

## E5-S5 Boss 锚点（Area2D 触发器薄壳，测试对表用）
var boss_anchor: Area2D = null

## E5-S5 事件层引用（全局 executor，Router 装配单例；薄壳三件套装配用）
var event_executor: RefCounted = null

const TeleportAssembler := preload("res://scripts/events/teleport_assembler.gd")
const AutosaveNotifier := preload("res://scripts/events/autosave_notifier.gd")
const EventLoader := preload("res://scripts/events/event_loader.gd")
const ShellScript := preload("res://scripts/events/trigger_event_shell.gd")
const InteractionControllerScript := preload("res://scripts/events/interaction_controller.gd")
const BOSS_EVENT_ID: String = "story_boss_pre"


func _ready() -> void:
	var player: CharacterBody2D = $YSorted/Player
	_apply_limits(player.get_node("Camera2D"), limits_main)
	# E4-S5：内容点位装配（1 宝箱 + 2 调查点，数据/装配见 scripts/events/）
	const MapEvents := preload("res://scripts/events/map_events.gd")
	content_points = MapEvents.assemble(self, "ruins_f3")
	# E4-S6：传送装配（from_f2 入口 + to_f2 返程南门双用途；遗迹图无对话装配）
	teleports = TeleportAssembler.assemble(self, "ruins_f3", null)
	# E4-S6：进图自动存档（map_ready 广播 + save + 图标，§3.4 时序收口）
	AutosaveNotifier.announce_ready(self, "ruins_f3")
	# E5-M5：交互轮询器（f3 既有装配缺口补齐——Boss 锚点是交互键触发位，
	# 无控制器则 Z 键无人分派，锚点纯摆设；顺带宝箱/调查点恢复可交互。
	# runner 用 UILayer 常驻实例（无则 null，门闸跳过，与遗迹图惯例一致））
	_assemble_interaction(player)
	# E5-S5：Boss 锚点（I5 事件链触发位）
	_assemble_boss_anchor()


## E5-M5：交互轮询器装配（Z/E → InteractRay → 协议分派）。
## runner 三选一：UILayer 常驻实例（真实游戏，town 装配的跨图复用）→
## 本图自建薄实例（测试树无 Main 结构）→ null（headless 纯装配面）。
## 跨图复用时必须 rebind_player 换绑本图玩家——旧引用（town 玩家）已随图
## 释放，战前台词的移动锁/战后 force_idle 的解锁都会摸空。
func _assemble_interaction(p_player: CharacterBody2D) -> void:
	var runner: Node = null
	if is_inside_tree():
		runner = get_tree().root.get_node_or_null("Main/UILayer/DialogueRunner")
	if runner == null:
		# 测试树兜底：自建薄实例挂本图（随图生灭；仅门闸与 dialogue 动作用）
		runner = Node.new()
		runner.name = "DialogueRunner"
		runner.set_script(preload("res://scripts/dialogue/dialogue_runner.gd"))
		add_child(runner)
		runner.setup(null, p_player)
	else:
		runner.rebind_player(p_player)
	dialogue_runner = runner
	# 全局 executor 注入 runner（缺口②，dryrun8 实锤修复）：Router 创建全局
	# executor 后从未 setup——dialogue 动作被静默跳过，战前/战后台词实机不播。
	# 【此处必须直取 SceneRouter 单例】成员变量 event_executor 在
	# _assemble_boss_anchor（本函数之后）才赋值，用成员判断恒 null——
	# E5-QA 备忘"恒真 if 零行为影响"实为此恒假分支，setup 从未执行过。
	var gexec: RefCounted = SceneRouter.global_event_executor
	if gexec != null and gexec.has_method("setup"):
		gexec.setup(runner)
	event_executor = gexec   # 同步成员引用，_assemble_boss_anchor 复用同实例
	interaction_controller = Node.new()
	interaction_controller.name = "InteractionController"
	interaction_controller.set_script(InteractionControllerScript)
	add_child(interaction_controller)
	interaction_controller.setup(p_player, runner)


## E5-S5：Boss 交互键锚点（探索 GDD I5 / 对话 GDD §3.3 切换点 3）。
## gen_ruins 预置的 BossTriggers 双锚 Marker2D（棺前 (19-20,35) 格）原样保留
## （E4-S3 验收物），锚点实体同位重建为 trigger_event_shell 薄壳：
##   new_event_id = story_boss_pre → 事件层全权（conditions >=2 门闸在数据侧，
##   phase 3 后重触发零动作），on_interact() 协议分派 = 交互键触发（非踩踏，
##   I5"我准备好再开"主动权）。
## 三件套取全局单实例（Router 装配）：loader 轻量按需自建（纯数据缓存），
## executor 与 runner 复用全局——battle 挂起簿记/胜利续行全走全局实例，
## 这正是"转场后战后续行"的载体（详见 battle_event_bridge 头注）。
## runner 注入缺口②已在 _assemble_interaction 收口（该函数先于本函数执行，
## 成员 event_executor 已由彼处赋值为全局单例——本处只做一致性兜底重读）。
func _assemble_boss_anchor() -> void:
	event_executor = SceneRouter.global_event_executor
	var runner: Node = dialogue_runner
	if runner == null and is_inside_tree():
		# 未入树（headless 单测装配面）时不查树——Godot 4 对未入树节点调
		# get_tree() 会打 "Parameter data.tree is null" 引擎错误（GUT 判
		# Unexpected Errors），is_inside_tree() 守卫才是零噪音判定
		runner = get_tree().root.get_node_or_null("Main/UILayer/DialogueRunner")
	var loader: RefCounted = EventLoader.new()
	loader.load_all()
	var anchors: Node = get_node_or_null("YSorted/BossTriggers")
	if anchors == null:
		push_warning("[RuinsF3Map] 无 BossTriggers 容器，Boss 锚点装配跳过")
		return
	for anchor in anchors.get_children():
		if boss_anchor != null:
			# 同位双锚只装首实体（防同帧双触发）；后续锚确定性跳过——
			# 不用 queue_free（帧末生效，同帧计数仍见 2，headless 断言不可靠）
			continue
		var trigger: Area2D = Area2D.new()
		trigger.set_script(ShellScript)
		trigger.name = "Evt_" + String(anchor.name)
		trigger.event_id = "boss_anchor_" + String(anchor.name)
		trigger.new_event_id = BOSS_EVENT_ID
		trigger.setup(loader, event_executor, runner)
		trigger.collision_layer = 2          # 交互物层（InteractRay 命中面）
		trigger.collision_mask = 0
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.name = "InteractShape"
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(16, 16)
		shape_node.shape = rect
		trigger.add_child(shape_node)
		trigger.position = (anchor as Node2D).position
		anchors.add_child(trigger)
		if boss_anchor == null:
			boss_anchor = trigger            # 双锚同规格；测试对表取首个
	print("[RuinsF3Map] Boss 锚点装配完成：%s（交互键，事件 story_boss_pre）" % BOSS_EVENT_ID)


func _apply_limits(cam: Camera2D, rect: Rect2i) -> void:
	cam.limit_left = rect.position.x
	cam.limit_top = rect.position.y
	cam.limit_right = rect.position.x + rect.size.x
	cam.limit_bottom = rect.position.y + rect.size.y
