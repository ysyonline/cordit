extends Node2D
## ruins_f1_map.gd —— E4-S3 遗迹一层地图根脚本（克隆 road_map.gd 简版结构）
##
## 【需求依据】探索 GDD §3.1 f1 行（56×44、B3 巡逻+追击、教学探索）+ §3.2 + §3.4。
## 本 Story 范围：地图本体 + B3 敌人摆位 + 相机限区 + spawn 落位。
## 传送接线（from_road / to_f2）与进图自动存档归 E4-S6（TODO 见下）。
##
## TODO(E4-S6) 正式时序衔接：
##   1. Triggers 容器挂 trigger_teleport（from_road / to_ruins_f2）；
##   2. _ready 尾部广播 map_ready → SaveManager.save()（探索 GDD §3.4 精确时序）；
##   3. spawn 支持双入口：from_road(448,40) / from_f2 北口落位。

## 相机限区：主图 56×44 tile = 896×704 px
@export var limits_main: Rect2i = Rect2i(0, 0, 896, 704)

## from_road 出生落位（入口 2×2 空地预留区中央偏南，参考格 (27.5,3.5)）
@export var pos_from_road: Vector2 = Vector2(448, 56)

## 对话运行器引用位（遗迹图无对话装配；预留接口名与 town_map 对齐，防测试侧空引用）
var dialogue_runner: Node = null
var interaction_controller: Node = null


func _ready() -> void:
	var player: CharacterBody2D = $YSorted/Player
	_apply_limits(player.get_node("Camera2D"), limits_main)
	# TODO(E4-S6)：此处广播 EventBus.map_ready 并触发自动存档（§3.4 精确时序）


func _apply_limits(cam: Camera2D, rect: Rect2i) -> void:
	cam.limit_left = rect.position.x
	cam.limit_top = rect.position.y
	cam.limit_right = rect.position.x + rect.size.x
	cam.limit_bottom = rect.position.y + rect.size.y
