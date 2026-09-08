extends Node
## _m7a1_screenshot.gd —— M7-A1 town 光照视觉证据采集器（临时，采后可删）
##
## 跑法（窗口模式真实渲染器 + MovieWriter PNG 序列逐帧落盘，先例
## record_m3/m4/m5_gameplay 同路径；一次跑一个机位，M7A1_MODE 摆位）：
##   M7A1_MODE=square Godot.exe --path . --write-movie evidence/_m7a1_sq/f.png \
##     --fixed-fps 30 --quit-after 90 res://evidence/_m7a1_screenshot.tscn
##   M7A1_MODE=inn    同上，目录 _m7a1_inn（截图 = 序列最后一帧）
##
## 说明：直接实例化真 town.tscn（光照装配在 town._ready 全链内，与 Main
## 无关；P0 守卫 current_scene!="Main" 自动跳过——画面无对话框遮挡）。

const TOWN_SCENE := "res://scenes/maps/town.tscn"
const SQUARE_POS := Vector2(448, 520)   # 广场喷泉下方：水光 + 客栈门灯同框
const INN_POS := Vector2(1304, 280)     # 室内A壁炉下方：炉火 + 存档点光同框


func _ready() -> void:
	var town: Node = (load(TOWN_SCENE) as PackedScene).instantiate()
	add_child.call_deferred(town)
	_position.call_deferred(town)


func _position(town: Node) -> void:
	for i in 10:
		await get_tree().process_frame
	var mode := OS.get_environment("M7A1_MODE")
	if mode == "inn":
		var cam: Camera2D = town.get_node("YSorted/Player/Camera2D") as Camera2D
		town._apply_limits(cam, town.limits_inn)   # 生产传送同款限区切换
		_teleport_player(town, INN_POS)
	else:
		_teleport_player(town, SQUARE_POS)
	print("[M7A1Shot] 摆位完成 mode=%s pos=%s（其余交给 MovieWriter 逐帧落盘）" % [mode,
			(town.get_node("YSorted/Player") as Node2D).global_position])


func _teleport_player(town: Node, p_pos: Vector2) -> void:
	(town.get_node("YSorted/Player") as CharacterBody2D).global_position = p_pos
