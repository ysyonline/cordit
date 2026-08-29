extends Node
## E1-S6 测试包装器：运行时把 town.tscn 直接挂到 root（模式同 headless_e1s5_wrapper.gd
## ——town_map.gd 不经 Router，不要求 Main 结构……但 E1-S6 装配优先找 Main/UILayer，
## 故本包装器把 main.tscn 一并重挂（模式同 headless_e1s4_wrapper.gd），
## 再挂 town 地图到 World。runner/对话框随 UILayer 常驻，测试结束统一清理。

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TOWN_SCENE := preload("res://scenes/maps/town.tscn")
const SMK_SCRIPT := preload("res://tests/smoke/headless_e1s6.gd")


func _ready() -> void:
	# Main 常驻根（UILayer 宿主）；MainController._ready 会初始装载 map_a（含
	# 0.4s 淡入淡出），装载完成后下方"整层替换"会把它原样换掉——不影响本测试。
	var main: Node = MAIN_SCENE.instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.8).timeout  # 等 Router 初始装载淡入淡出彻底结束
	# 整层替换 World（queue_free 旧 map_a，直接放 town，不经 Router）
	var world: Node = main.get_node("World")
	for old in world.get_children():
		old.queue_free()
	var town: Node = TOWN_SCENE.instantiate()
	town.name = "Map_Town"
	world.add_child.call_deferred(town)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame  # 装配脚本 add_child 立即生效后再等一帧
	var tester: Node = Node.new()
	tester.name = "HeadlessE1S6"
	tester.set_script(SMK_SCRIPT)
	get_tree().root.add_child.call_deferred(tester)
