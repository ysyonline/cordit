extends Node
## SMK-08~12 测试包装器：运行时把 main.tscn 重挂到 root 直下
##
## 【为什么需要包装】（headless 运行结构约束）：
##   SceneRouter 依赖 A4 结构：Main 必须是 root 的【直接子节点】
##   （root.get_node_or_null("Main")，见 autoload/scene_router.gd _get_world）。
##   若用 tscn 静态包装（root/SmokeRoot/Main），Router 的结构查找必然落空——
##   这是包装方式与产品假设的冲突，不是产品缺陷（正式运行 F5 从 main.tscn
##   启动时 Main 就在 root 直下）。
##   因此本包装器在 _ready 中：动态实例化 main.tscn → 改名为 "Main" →
##   挂到 root 直下 → 自己只负责驱动 SMK-08~12 断言。测试完随树销毁，零残留。

const SMK_SCRIPT := preload("res://tests/smoke/headless_smk_e1s3.gd")


func _ready() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main: Node = main_scene.instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	# 等 Main 入树 + MainController._ready 跑完，再挂测试节点驱动断言
	await get_tree().process_frame
	await get_tree().process_frame
	var tester: Node = Node.new()
	tester.name = "HeadlessSMK"
	tester.set_script(SMK_SCRIPT)
	get_tree().root.add_child.call_deferred(tester)
