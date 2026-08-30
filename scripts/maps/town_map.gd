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
## TODO(E4-S6) 正式时序衔接（三条，重做本脚本时逐条落实）：
## 1. 简版 teleport 无转场、无 map_ready、无自动存档——正式时序按探索 GDD §3.4：
##    teleport 动作 → 载图/落位 → 地图广播 map_ready → SaveManager.save()
##    （同图室内传送是否触发自动存档，E4-S6 裁决）。
## 2. trigger 现为 Area2D 直连行为；正式版换成 events/trigger_*.tscn 薄壳
##    （只带 event_id，行为走 JSON），本场景 4 个 Area2D 的碰撞形状与位置可原样迁移。
## 3. 相机 limit 三组数值已内聚在本脚本 export，正式版迁入事件动作参数即可，
##    节点布局不变（黑幕框即 limit 边界，布局勿动）。

## 相机限区。注意：Rect2i 前两位 = 左上角坐标，后两位 = 宽高（不是 right/bottom）。
## 室内限区取"黑幕框"640×360（= 视口尺寸），房间在框内居中，相机实际静止。
@export var limits_main: Rect2i = Rect2i(0, 0, 1024, 768)       # 主图 64×48 tile
@export var limits_inn: Rect2i = Rect2i(1056, 0, 640, 360)      # 室内A 黑幕框 (1056,0)-(1696,360)
@export var limits_house: Rect2i = Rect2i(1056, 188, 640, 360)  # 室内B 黑幕框 (1056,188)-(1696,548)

## 传送落位（tile 中心像素；落位恒在出口 trigger 之外一格，防原地弹回循环）
@export var pos_inn_spawn: Vector2 = Vector2(85, 17) * 16.0 + Vector2(8, 8)    # 客栈入口落位 (85,17)
@export var pos_house_spawn: Vector2 = Vector2(85, 29) * 16.0 + Vector2(8, 8)  # 民居A入口落位 (85,29)
@export var pos_inn_out: Vector2 = Vector2(29, 19) * 16.0 + Vector2(8, 8)      # 客栈出口落位 (29,19)
@export var pos_house_out: Vector2 = Vector2(12, 19) * 16.0 + Vector2(8, 8)    # 民居A出口落位 (12,19)

var _routes := {}  # trigger 节点名 → { "target": Vector2, "limits": Rect2i }

## 对话运行器实例（E1-S6 装配产物；公开供测试树定位/断言）
var dialogue_runner: Node = null

## 交互轮询器实例（E1-S6 装配产物；公开供测试注入）
var interaction_controller: Node = null

## E4-S5 内容点位装配产物（{"chests": Array, "investigates": Array}，测试对表用）
var content_points: Dictionary = {}

## E1-S6 预载：对话系统三件套（runner / controller / 对话框场景 / NPC 场景）
const DialogueRunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const InteractionControllerScript := preload("res://scripts/events/interaction_controller.gd")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const NpcScene := preload("res://scenes/npc/npc.tscn")

## 本 Story 实体化的 NPC 锚点名（最小版：摆 2 个验证，其余 M1 前补——
## 命名 = E1-S5 验收锚点名，锚点 Marker2D 原样保留不删）。
const SPAWN_NPC_IDS: Array[String] = ["npc_01_innkeeper", "npc_04_guard"]


func _ready() -> void:
	_routes = {
		"Door_Inn": {"target": pos_inn_spawn, "limits": limits_inn},
		"Door_HouseA": {"target": pos_house_spawn, "limits": limits_house},
		"Inn_Exit": {"target": pos_inn_out, "limits": limits_main},
		"HouseA_Exit": {"target": pos_house_out, "limits": limits_main},
	}
	var player: CharacterBody2D = $YSorted/Player
	_apply_limits(player.get_node("Camera2D"), limits_main)
	for area in $Triggers.get_children():
		if area is Area2D:
			area.body_entered.connect(_on_trigger_body_entered.bind(String(area.name)))
	# E1-S6：对话系统装配（锚点实体化 + runner/controller + 对话框入 UILayer）
	_assemble_dialogue_system(player)
	# E4-S5：内容点位装配（1 宝箱 + 6 调查点，数据/装配见 scripts/events/）
	_assemble_content_points()


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
	# ④ 交互轮询器（挂本地图）
	interaction_controller = Node.new()
	interaction_controller.name = "InteractionController"
	interaction_controller.set_script(InteractionControllerScript)
	add_child(interaction_controller)
	interaction_controller.setup(player, dialogue_runner)


func _on_trigger_body_entered(body: Node2D, trigger_name: String) -> void:
	if not (body is CharacterBody2D) or not _routes.has(trigger_name):
		return
	# 对话期间触发器不响应（对话 GDD §4；边缘情况 2 同规则前瞻）
	if dialogue_runner != null and not dialogue_runner.is_idle():
		return
	var route: Dictionary = _routes[trigger_name]
	body.global_position = route["target"]
	var cam: Camera2D = body.get_node("Camera2D")
	_apply_limits(cam, route["limits"])
	cam.reset_smoothing()


func _apply_limits(cam: Camera2D, rect: Rect2i) -> void:
	cam.limit_left = rect.position.x
	cam.limit_top = rect.position.y
	cam.limit_right = rect.position.x + rect.size.x
	cam.limit_bottom = rect.position.y + rect.size.y
