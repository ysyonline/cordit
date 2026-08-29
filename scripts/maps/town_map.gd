extends Node2D
## town_map.gd —— E1-S5 小镇地图根脚本：简版门传送（切位置 + 切相机限区）
## 施工依据：design/gdd/e1-s5-town-build-sheet.md 第 4/5 节
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


func _on_trigger_body_entered(body: Node2D, trigger_name: String) -> void:
	if not (body is CharacterBody2D) or not _routes.has(trigger_name):
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
