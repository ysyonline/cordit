extends Node2D
## ruins_f2_map.gd —— E4-S3 遗迹二层地图根脚本（克隆 road_map.gd 简版结构）
##
## 【需求依据】探索 GDD §3.1 f2 行（48×48、B4 精英定守、队员聊天点）+ §3.2 + §3.4。
## 本 Story 范围：地图本体 + B4 精英定守摆位（空 waypoints = 站位即交战位）
##   + 相机限区 + spawn 落位；聊天点锚点归 E5 事件（GDD §3.1 f2 行"队员聊天点"）。
## 传送接线（from_f1 / to_f3）与进图自动存档归 E4-S6（TODO 见下）。
##
## TODO(E4-S6) 正式时序衔接：
##   1. Triggers 容器挂 trigger_teleport（from_ruins_f1 / to_ruins_f3）；
##   2. _ready 尾部广播 map_ready → SaveManager.save()（探索 GDD §3.4 精确时序）；
##   3. spawn 支持双入口：from_f1(384,40) / from_f3 北口落位。

## 相机限区：主图 48×48 tile = 768×768 px
@export var limits_main: Rect2i = Rect2i(0, 0, 768, 768)

## from_f1 出生落位（入口走廊中央，参考格 (23.5,2.5)）
@export var pos_from_f1: Vector2 = Vector2(384, 40)

## 对话运行器引用位（遗迹图无对话装配；预留接口名与 town_map 对齐，防测试侧空引用）
var dialogue_runner: Node = null
var interaction_controller: Node = null

## E4-S5 内容点位装配产物（{"chests": Array, "investigates": Array}，测试对表用）
var content_points: Dictionary = {}


func _ready() -> void:
	var player: CharacterBody2D = $YSorted/Player
	_apply_limits(player.get_node("Camera2D"), limits_main)
	# E4-S5：内容点位装配（2 宝箱 + 3 调查点，数据/装配见 scripts/events/）
	const MapEvents := preload("res://scripts/events/map_events.gd")
	content_points = MapEvents.assemble(self, "ruins_f2")
	# TODO(E4-S6)：此处广播 EventBus.map_ready 并触发自动存档（§3.4 精确时序）


func _apply_limits(cam: Camera2D, rect: Rect2i) -> void:
	cam.limit_left = rect.position.x
	cam.limit_top = rect.position.y
	cam.limit_right = rect.position.x + rect.size.x
	cam.limit_bottom = rect.position.y + rect.size.y
