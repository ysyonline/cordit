extends Node2D
## town_map.gd —— E1-S5 小镇地图根脚本：简版门传送（切位置 + 切相机限区）
## 施工依据：design/gdd/e1-s5-town-build-sheet.md 第 4/5 节
##
## 【E1-S6 增量】对话系统装配（交互 + 对话框 + 触发器，架构 A7）：
##   本脚本 _ready 时装配 DialogueRunner（挂 UILayer 跨场景常驻，A4）+
##   InteractionController（挂本地图，随图生灭），并把锚点 NPCs 实例化为
##   npc.tscn 实体。装配代码全部集中在 _assemble_dialogue_system()，
##   其余 E1-S5 已验收行为零触碰。
##
## 【E4-S6 增量】传送网络接入（TODO(E4-S6) 三条逐一落实）：
##   1. 简版 teleport 退役：_routes 字典分派移除，4 门行为改由
##      TeleportAssembler 按目录装配 trigger_teleport 薄壳（场景内旧
##      Area2D 由装配器移除后同位重建）；相机限区查
##      TeleportCatalog.SAME_MAP_LIMITS（与下方 export 三组互为镜像，
##      GUT 对表锁死）；传送落位正本在目录 target 字段。
##   2. 进图自动存档：_ready 尾部 AutosaveNotifier.announce_ready()
##      （广播 map_ready → SaveManager.save()，§3.4"过传送点存"时序）。
##   3. 相机 limit 三组数值保留本脚本 export（正式版迁事件动作参数，布局勿动）。

## 相机限区。注意：Rect2i 前两位 = 左上角坐标，后两位 = 宽高（不是 right/bottom）。
## 室内限区取"黑幕框"640×360（= 视口尺寸），房间在框内居中，相机实际静止。
@export var limits_main: Rect2i = Rect2i(0, 0, 1024, 768)       # 主图 64×48 tile
@export var limits_inn: Rect2i = Rect2i(1056, 0, 640, 360)      # 室内A 黑幕框 (1056,0)-(1696,360)
@export var limits_house: Rect2i = Rect2i(1056, 188, 640, 360)  # 室内B 黑幕框 (1056,188)-(1696,548)

## 对话运行器实例（E1-S6 装配产物；公开供测试树定位/断言）
var dialogue_runner: Node = null

## 交互轮询器实例（E1-S6 装配产物；公开供测试注入）
var interaction_controller: Node = null

## E4-S5 内容点位装配产物（{"chests": Array, "investigates": Array}，测试对表用）
var content_points: Dictionary = {}

## E4-S6 传送触发器装配产物（Array[Area2D]，测试对表用）
var teleports: Array = []

## E5-S3 事件层装配产物（事件表 + 执行器；NPC 阶段对话与 E5-S4 剧情锚点共用）
var event_loader: RefCounted = null
var event_executor: RefCounted = null

## E1-S6 预载：对话系统三件套（runner / controller / 对话框场景 / NPC 场景）
const DialogueRunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const InteractionControllerScript := preload("res://scripts/events/interaction_controller.gd")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const NpcScene := preload("res://scenes/npc/npc.tscn")
const TeleportAssembler := preload("res://scripts/events/teleport_assembler.gd")
const AutosaveNotifier := preload("res://scripts/events/autosave_notifier.gd")
## T6.5 开局剧情锚点（P0 接线）：统一事件薄壳复用（A7 第 1 层，同 ruins_f3 Boss 锚点）
const ShellScript := preload("res://scripts/events/trigger_event_shell.gd")
## E5-S3 事件层（NPC 阶段对话：交互事件按 phase 映射选对话，GDD §3.3）
const EventLoader := preload("res://scripts/events/event_loader.gd")
const EventExecutor := preload("res://scripts/events/event_executor.gd")
## E6-S1 主菜单（UILayer 常驻装配，C 键呼出）
const MenuPanelScript := preload("res://scripts/ui/menu_panel.gd")

## E6-S1 主菜单实例（UILayer 常驻装配产物；公开供测试树定位/断言）
var menu_panel: Control = null

## 本 Story 实体化的 NPC 锚点名（E5-S3 起全量 12 个：6 个配额 NPC 带阶段
## 增量事件，其余 6 个单阶段事件——文案占位，S4 剧情线补正稿）。
## E1-S6 冒烟对 NPC 实体数的断言只点 npc_01/npc_04 两个（在位判定），扩到
## 12 不破冒烟；锚点 Marker2D 原样保留不删（验收物）。
const SPAWN_NPC_IDS: Array[String] = [
	"npc_01_innkeeper", "npc_02_traveler", "npc_03_chase_kid", "npc_04_guard",
	"npc_05_smith", "npc_06_peddler", "npc_07_priest", "npc_08_prayer_woman",
	"npc_09_shepherd", "npc_10_housewife", "npc_11_porter", "npc_12_elder",
]

## T6.5 开局剧情（P0）事件 id（data/json/events/story_intro.json 同名顶层事件；
## 动作序列 = dialogue story_p0_intro → set_flag story_p0_seen → save_point，
## 门控在数据侧 conditions：story_phase == 0 且未打 story_p0_seen 旗）
const OPENING_EVENT_ID: String = "story_p0_intro"

## T6.5 开局锚点路径（town.tscn YSorted/P0_Anchor，与玩家出生位 (192,640) 同格——
## 出生即物理重叠，body_entered 首物理帧开演 P0）
const OPENING_ANCHOR_PATH: String = "YSorted/P0_Anchor"

## T6.5 开局触发器实体名（Triggers 容器内；测试对表用）
const OPENING_TRIGGER_NAME: String = "Evt_P0_Opening"


func _ready() -> void:
	var player: CharacterBody2D = $YSorted/Player
	_apply_limits(player.get_node("Camera2D"), limits_main)
	# E1-S6：对话系统装配（锚点实体化 + runner/controller + 对话框入 UILayer）
	_assemble_dialogue_system(player)
	# E4-S5：内容点位装配（1 宝箱 + 6 调查点，数据/装配见 scripts/events/）
	_assemble_content_points()
	# E4-S6：传送装配（场景内旧 4 门由装配器移除，目录驱动薄壳同位重建）
	teleports = TeleportAssembler.assemble(self, "town", dialogue_runner)
	# T6.5：开局剧情锚点装配（P0 接线；守卫见函数头注）
	_assemble_opening_story()
	# E4-S6：进图自动存档（map_ready 广播 + save + 图标，§3.4 时序收口）
	AutosaveNotifier.announce_ready(self, "town")
	# E6-S1：主菜单装配（UILayer 常驻 + C 键呼出；town 首装，跨图复用）
	_assemble_menu()


func _assemble_content_points() -> void:
	const MapEvents := preload("res://scripts/events/map_events.gd")
	content_points = MapEvents.assemble(self, "town")


## E1-S6：对话系统装配（全部增量集中于此，E1-S5 已验收行为零触碰）。
## 层位归属：runner + 对话框挂 Main/UILayer（跨场景常驻，A4——对话可跨
## 剧情阶段连续存在）；无 Main 结构（测试直挂）时兜底挂本地图，由测试侧
## 负责释放。InteractionController 挂本地图（随图生灭，无全局状态）。
func _assemble_dialogue_system(player: CharacterBody2D) -> void:
	# ① 锚点实体化：E1-S5 的 Marker2D 锚点原样保留，NPC 实体摆到锚点脚底位
	var anchors: Node = get_node_or_null("YSorted/NPC_Anchors")
	if anchors != null:
		for anchor in anchors.get_children():
			var anchor_name := String(anchor.name)
			if anchor_name in SPAWN_NPC_IDS:
				var npc: StaticBody2D = NpcScene.instantiate()
				npc.name = anchor_name + "_entity"
				npc.npc_id = anchor_name
				npc.position = anchor.position
				get_node("YSorted").add_child(npc)
	# ② 对话框（UILayer 常驻层；无 Main 时兜底挂本地图根）
	var box: Control = DialogueBoxScene.instantiate()
	var ui_host: Node = get_tree().root.get_node_or_null("Main/UILayer")
	var box_is_temp: bool = false
	if ui_host == null:
		ui_host = self
		box_is_temp = true
	ui_host.add_child(box)
	if box_is_temp:
		box.set_meta("temp_dialogue_box", true)  # 标记：测试树释放时随图销毁
	# ③ DialogueRunner（与对话框同宿主；runner 引用同图玩家与框）
	dialogue_runner = Node.new()
	dialogue_runner.name = "DialogueRunner"
	dialogue_runner.set_script(DialogueRunnerScript)
	ui_host.add_child(dialogue_runner)
	dialogue_runner.setup(box, player)
	# ③' E5-S3 事件层：事件表装载 + 执行器（runner 注入 dialogue 动作与
	# battle 收束消费面；装载失败仅日志，NPC 交互退回兼容路径不炸图）
	event_loader = EventLoader.new()
	var load_failed: Array[String] = event_loader.load_all()
	if not load_failed.is_empty():
		push_warning("[TownMap] 事件文件加载失败：%s（对应事件不可触发）" % [load_failed])
	event_executor = EventExecutor.new()
	event_executor.setup(dialogue_runner)
	# ④ 交互轮询器（挂本地图）+ 事件层注入（NPC 交互按 phase 映射选对话）
	interaction_controller = Node.new()
	interaction_controller.name = "InteractionController"
	interaction_controller.set_script(InteractionControllerScript)
	add_child(interaction_controller)
	interaction_controller.setup(player, dialogue_runner)
	interaction_controller.setup_events(event_loader, event_executor)


func _apply_limits(cam: Camera2D, rect: Rect2i) -> void:
	cam.limit_left = rect.position.x
	cam.limit_top = rect.position.y
	cam.limit_right = rect.position.x + rect.size.x
	cam.limit_bottom = rect.position.y + rect.size.y


## T6.5：开局剧情锚点装配（探索 GDD §3.4"首次启动（无存档）：开场剧情 P0
## 结束处执行一次 save_point"——此前 story_p0_intro 对话零引用，玩家看不到 P0）。
##
## 【装配面】trigger_event_shell 薄壳（A7 第 1 层，行为全在数据侧）挂 Triggers
## 容器：踩踏面（mask=16 玩家层，同 TeleportAssembler 口径）以出生锚点为中心，
## 出生即重叠 → body_entered 首物理帧 _emit_event → executor 走
## conditions（phase==0 且无 story_p0_seen 旗）→ dialogue/set_flag/save_point。
## 三件套注入本图 _assemble_dialogue_system 装配产物（runner/loader/executor）。
##
## 【双守卫——为何不能无条件装配】"首次启动"与既有测试环境在数据面不可区分
## （GUT 直挂 town / m6t41 假 Main 经 Router 读档回 town：均为 phase=0、
## flags 空、玩家先落出生位）——无条件接线会在 503 基线内自动开演 P0 并置
## 存档意图位，污染存档门控与对话门闸断言（净增不改旧纪律）。故：
##   ① 生产启动守卫：current_scene 必须是 Main 本体（生产 F5/运行 main.tscn
##     时 Main 恒为 current_scene；GUT 用例树 / 冒烟包装器 / 演示替身的
##     current_scene 均非 Main——smk_e1s3、e1s4 是手动重挂 Main，包装器才
##     是 current_scene，同样不接线，冒烟 user:// 纯净性（SMK-12）不受扰）。
##   ② 无存档守卫：SaveManager.has_save() 为假才装配——GDD"首次启动（无存档）"
##     原文口径；带档启动（旧档玩家/续玩）不触发 P0（旧档若 phase>0 或带
##     story_p0_seen 旗，conditions 亦会拦，双保险）。
## 两守卫只影响【接线】，事件数据本身 schema 与执行链由 test_t65 全量覆盖。
func _assemble_opening_story() -> void:
	if not is_inside_tree():
		return
	var cs: Node = get_tree().current_scene
	if cs == null or cs.name != "Main":
		print("[TownMap] 非生产启动语境（current_scene=%s），P0 锚点不接线" % [
				String(cs.name) if cs != null else "<null>"])
		return
	if SaveManager.has_save():
		print("[TownMap] 已有存档（has_save=true），P0 锚点不接线（GDD 首次启动口径）")
		return
	var anchor: Node2D = get_node_or_null(OPENING_ANCHOR_PATH) as Node2D
	if anchor == null:
		push_warning("[TownMap] 无 %s 锚点，P0 开局装配跳过" % OPENING_ANCHOR_PATH)
		return
	var container: Node = get_node_or_null("Triggers")
	if container == null:
		push_warning("[TownMap] 无 Triggers 容器，P0 开局装配跳过")
		return
	var trigger: Area2D = Area2D.new()
	trigger.set_script(ShellScript)
	trigger.name = OPENING_TRIGGER_NAME
	trigger.event_id = OPENING_TRIGGER_NAME
	trigger.new_event_id = OPENING_EVENT_ID
	trigger.setup(event_loader, event_executor, dialogue_runner)
	trigger.collision_layer = 0
	trigger.collision_mask = 16   # 玩家实体层（与 TeleportAssembler 同口径）
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(32, 32)   # 出生格 ±1 格重叠面：脚盒落格即触发
	shape_node.shape = rect
	trigger.add_child(shape_node)
	trigger.position = anchor.position
	container.add_child(trigger)
	print("[TownMap] P0 开局锚点装配完成：%s → 事件 %s（踩踏@%s）" % [
			OPENING_TRIGGER_NAME, OPENING_EVENT_ID, trigger.position])


## E6-S1：主菜单装配（全部增量集中于此，既有验收行为零触碰）。
## 层位归属：挂 Main/UILayer（跨场景常驻，A4——town 首装、遗迹图复用同一
## 实例，避免每图一份）；无 Main 结构（测试直挂）时兜底挂本地图，由测试侧
## 负责释放。已存在实例时跳过（防重复装配——跨图往返会多次走 _ready）。
## 守卫改为按脚本判定：ui_host 下可能存在他人挂的同名 Control（防御性），
## 且兜底宿主（本图）在跨图往返时自身也会换新——按 name 复用会把旧图临死
## 节点当正本；脚本一致才是"确实是主菜单"的可靠判据。
func _assemble_menu() -> void:
	var ui_host: Node = get_tree().root.get_node_or_null("Main/UILayer")
	var is_temp: bool = false
	if ui_host == null:
		ui_host = self
		is_temp = true
	var existing: Node = ui_host.get_node_or_null("MenuPanel")
	if existing != null and existing.get_script() == MenuPanelScript:
		menu_panel = existing
		return
	var panel: Control = Control.new()
	panel.name = "MenuPanel"
	panel.set_script(MenuPanelScript)
	ui_host.add_child(panel)
	if is_temp:
		panel.set_meta("temp_menu_panel", true)  # 标记：测试树释放时随图销毁
	menu_panel = panel
