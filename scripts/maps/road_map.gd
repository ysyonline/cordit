extends Node2D
## road_map.gd —— E4-S2 道路地图根脚本（克隆 town_map.gd 简版结构）
##
## 【需求依据】探索 GDD §3.1 道路行（48×64、B1/B2 唯一通道）+ §3.4。
## 本 Story 范围：地图本体 + 敌人巡逻摆位 + 相机限区 + spawn 落位。
## 传送接线（from_town / to_ruins_f1）与进图自动存档归 E4-S6（TODO 见下）。
##
## 【与 town_map.gd 的差异】
##   - 无室内限区（道路图单区域），仅一组主限区；
##   - 无 NPC 锚点（道路 0 NPC，GDD §3.1）；
##   - ChasmBlocker（断桥虚空封边）为纯场景静态碰撞体，无需脚本参与。
##
## 【E4-S6 增量】传送接线 + 进图自动存档（TODO(E4-S6) 三条逐一落实）：
##   1. Triggers 容器挂 trigger_teleport（from_town / to_ruins_f1，目录驱动）；
##   2. _ready 尾部 AutosaveNotifier.announce_ready()（§3.4 精确时序）；
##   3. spawn 双入口由传送目录 to_spawn 落位（玩家实际位置=存档坐标），
##      场景内 Player 初始位仅为 from_town 首入缺省。

## 相机限区：主图 48×64 tile = 768×1024 px
@export var limits_main: Rect2i = Rect2i(0, 0, 768, 1024)

## from_town 出生落位（tile 中心像素；北门南下 2 宽道路中线参考格 (23.5,3.5)）
@export var pos_from_town: Vector2 = Vector2(384, 64)

## 对话运行器引用位（道路图无对话装配；预留接口名与 town_map 对齐，防测试侧空引用）
var dialogue_runner: Node = null
var interaction_controller: Node = null

## E4-S5 内容点位装配产物（{"chests": Array, "investigates": Array}，测试对表用）
var content_points: Dictionary = {}

## E4-S6 传送触发器装配产物（Array[Area2D]，测试对表用）
var teleports: Array = []

## T4.2 队员聊天点触发器（Array[Area2D]，测试对表用；E6-S4 第 2 步）
var chat_points: Array = []

const TeleportAssembler := preload("res://scripts/events/teleport_assembler.gd")
const AutosaveNotifier := preload("res://scripts/events/autosave_notifier.gd")


func _ready() -> void:
	var player: CharacterBody2D = $YSorted/Player
	_apply_limits(player.get_node("Camera2D"), limits_main)
	# E4-S5：内容点位装配（2 宝箱 + 3 调查点，数据/装配见 scripts/events/）
	const MapEvents := preload("res://scripts/events/map_events.gd")
	content_points = MapEvents.assemble(self, "road")
	# E4-S6：传送装配（from_town / to_ruins_f1；road 无对话装配，runner=null）
	teleports = TeleportAssembler.assemble(self, "road", null)
	# E4-S6：进图自动存档（map_ready 广播 + save + 图标，§3.4 时序收口）
	AutosaveNotifier.announce_ready(self, "road")
	# T4.2：队员聊天点（E6-S4 第 2 步，P1 道路段位置触发；事件门闸
	# phase>=1 + 一次性 flag 在数据侧，此处纯装配）
	const ChatPointAssembler := preload("res://scripts/events/chat_point_assembler.gd")
	chat_points = ChatPointAssembler.assemble(self, "road", dialogue_runner)


func _apply_limits(cam: Camera2D, rect: Rect2i) -> void:
	cam.limit_left = rect.position.x
	cam.limit_top = rect.position.y
	cam.limit_right = rect.position.x + rect.size.x
	cam.limit_bottom = rect.position.y + rect.size.y
