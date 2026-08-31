extends Node
## E1-S4 测试包装器：运行时把 main.tscn 重挂到 root 直下（模式同
## headless_smk_e1s3_wrapper.gd——SceneRouter 依赖 Main 为 root 直接子节点）。
## 【E4-S6/R2 适配】MainController 初始场景已换 town.tscn，而本测试断言
## 依赖 map_a 白盒几何（出生 (96,160)/横墙 272 左缘）——故初始装载完成后
## 整层替换 World 直挂 map_a（模式同 headless_e1s6_wrapper，不经 Router）。
## 测试节点随树销毁，零残留。

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MAP_A_SCENE := preload("res://tests/smoke/fixtures/map_a.tscn")
const SMK_SCRIPT := preload("res://tests/smoke/headless_e1s4.gd")


func _ready() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	# 等 Main 入树 + MainController 初始装载 town（0.4s 淡入淡出）完成
	await get_tree().create_timer(0.8).timeout
	# 整层替换 World：queue_free 初始装载的 town，直挂 map_a（不经 Router）
	var world: Node = main.get_node("World")
	for old in world.get_children():
		old.queue_free()
	var map_a: Node = MAP_A_SCENE.instantiate()
	map_a.name = "MapA"
	world.add_child.call_deferred(map_a)
	await get_tree().process_frame
	await get_tree().process_frame
	var tester: Node = Node.new()
	tester.name = "HeadlessE1S4"
	tester.set_script(SMK_SCRIPT)
	get_tree().root.add_child.call_deferred(tester)
