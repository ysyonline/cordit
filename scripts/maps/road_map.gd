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
## TODO(E4-S6) 正式时序衔接：
##   1. Triggers 容器挂 trigger_teleport（from_town / to_ruins_f1）；
##   2. _ready 尾部广播 map_ready → SaveManager.save()（探索 GDD §3.4 精确时序）；
##   3. spawn 支持双入口：from_town(384,64) / from_f1 南门落位。

## 相机限区：主图 48×64 tile = 768×1024 px
@export var limits_main: Rect2i = Rect2i(0, 0, 768, 1024)

## from_town 出生落位（tile 中心像素；北门南下 2 宽道路中线参考格 (23.5,3.5)）
@export var pos_from_town: Vector2 = Vector2(384, 64)

## 对话运行器引用位（道路图无对话装配；预留接口名与 town_map 对齐，防测试侧空引用）
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
