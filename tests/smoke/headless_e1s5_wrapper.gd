extends Node
## E1-S5 测试包装器：运行时把 town.tscn 直接挂到 root（town_map.gd 不经 Router，
## 不要求 Main 结构；直接实例化地图场景，绕开 main.tscn 初始装载 map_a 的问题）。
## 测试节点随树销毁，零残留。

const MAP_SCENE := preload("res://scenes/maps/town.tscn")
const SMK_SCRIPT := preload("res://tests/smoke/headless_e1s5.gd")


func _ready() -> void:
	var map: Node = MAP_SCENE.instantiate()
	map.name = "Map_Town"
	get_tree().root.add_child.call_deferred(map)
	await get_tree().process_frame
	await get_tree().process_frame
	var tester: Node = Node.new()
	tester.name = "HeadlessE1S5"
	tester.set_script(SMK_SCRIPT)
	get_tree().root.add_child.call_deferred(tester)
