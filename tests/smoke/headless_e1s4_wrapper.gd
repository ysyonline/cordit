extends Node
## E1-S4 测试包装器：运行时把 main.tscn 重挂到 root 直下（模式同
## headless_smk_e1s3_wrapper.gd——SceneRouter 依赖 Main 为 root 直接子节点）。
## 测试节点随树销毁，零残留。

const SMK_SCRIPT := preload("res://tests/smoke/headless_e1s4.gd")


func _ready() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main: Node = main_scene.instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	# 等 Main 入树 + MainController 初始装载 map_a（0.4s 淡入淡出）+ 挂载器跑完
	await get_tree().process_frame
	await get_tree().process_frame
	var tester: Node = Node.new()
	tester.name = "HeadlessE1S4"
	tester.set_script(SMK_SCRIPT)
	get_tree().root.add_child.call_deferred(tester)
