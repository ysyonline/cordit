extends Node2D
## ruins_f3_map.gd —— E4-S3 遗迹三层（Boss 前厅）地图根脚本（克隆 road_map.gd 简版结构）
##
## 【需求依据】探索 GDD §3.1 f3 行（40×40、零普通敌人、Boss 事件触发）+ §3.4 + I5 接口。
## 本 Story 范围：地图本体（前厅 + 石棺祭坛 + 灰石 Boss 门构图）+ 相机限区 + spawn 落位。
## f3 零敌人：Boss 本体不放地图，由 Boss 事件 battle 动作召唤（I5，事件归 E5、接线归 E4-S6）。
## BossTriggers 锚点 ×2（棺前交互格）：E5 story_boss_pre 事件触发位（交互键，非踩踏）。
##
## TODO(E4-S6) 正式时序衔接：
##   1. Triggers 容器挂 trigger_teleport（from_ruins_f2 / 战后回城）；
##   2. _ready 尾部广播 map_ready → SaveManager.save()（探索 GDD §3.4 精确时序）；
##   3. spawn 支持双入口：from_f2(320,40) / Boss 战败读档回本位。
## TODO(E5) story_boss_pre 事件挂接：BossTriggers 锚点 → I5 事件链（战前台词→battle b5_core→…）。

## 相机限区：主图 40×40 tile = 640×640 px
@export var limits_main: Rect2i = Rect2i(0, 0, 640, 640)

## from_f2 出生落位（入口走廊中央，参考格 (19.5,2.5)）
@export var pos_from_f2: Vector2 = Vector2(320, 40)

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
