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
## 【E4-S6/R2 适配】MainController 初始场景已换 town.tscn，SMK-08 断言
##   "初始装载产物 = MapA" 不再成立——包装器在断言前经 Router 合法装载
##   map_a（与被测行为同一条路径），恢复断言前提；town 初始装载不落盘
##   （AutosaveNotifier 门控），SMK-12 user:// 零落盘口径不被破坏。

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MAP_A_PATH := "res://tests/smoke/fixtures/map_a.tscn"
const SMK_SCRIPT := preload("res://tests/smoke/headless_smk_e1s3.gd")


func _ready() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	# 等 Main 入树 + MainController 初始装载 town（0.4s 淡入淡出）完成
	await get_tree().create_timer(0.8).timeout
	# 经 Router 把 World 换回 map_a：恢复 SMK-08/10 的 MapA 断言前提
	SceneRouter.change_scene(MAP_A_PATH, {}, false)
	await get_tree().create_timer(1.0).timeout
	var tester: Node = Node.new()
	tester.name = "HeadlessSMK"
	tester.set_script(SMK_SCRIPT)
	get_tree().root.add_child.call_deferred(tester)
