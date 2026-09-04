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


func _ready() -> void:
	var player: CharacterBody2D = $YSorted/Player
	_apply_limits(player.get_node("Camera2D"), limits_main)
	# E1-S6：对话系统装配（锚点实体化 + runner/controller + 对话框入 UILayer）
	_assemble_dialogue_system(player)
	# E4-S5：内容点位装配（1 宝箱 + 6 调查点，数据/装配见 scripts/events/）
	_assemble_content_points()
	# E4-S6：传送装配（场景内旧 4 门由装配器移除，目录驱动薄壳同位重建）
	teleports = TeleportAssembler.assemble(self, "town", dialogue_runner)
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
