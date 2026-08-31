extends Node
## MainController —— 常驻根 Main 的装配/验证脚本（挂 scenes/main.tscn 根节点）
##
## 【职责】（架构 A4；本文件是 E1-S3 "Main 常驻根"的实现侧）：
##   ① 启动时自检 A4 结构（World / UILayer / UILayer/FadeMask 齐备），
##      结构缺失立即报错——后续所有场景切换都依赖该结构，坏结构必须启动即暴露；
##   ② 装载初始场景（E4-S6/R2 起为小镇正式地图 town.tscn，
##      届时只改 INITIAL_SCENE_PATH 一个常量——已兑现）。
##
## 【边界】：
##   - 不实现任何玩法逻辑、不存游戏状态（游戏状态只在 GameData，A3）；
##   - 不感知具体场景内容：初始装载也走 SceneRouter.change_scene，
##     与后续切换共用同一条校验/过渡路径，Router 职责单一（A3）；
##   - 不发业务信号：装载完成的"地图侧通知"由被装载的地图场景自己
##     发 EventBus.map_ready（归属裁决见 scene_router.gd 头注释与 A3/A7）。
##
## 【E1-S3 验收对应】：
##   - SMK-11：本脚本不触碰 UILayer——跨场景切换时 UILayer（含测试
##     Label 与 FadeMask）永不被销毁，存活由冒烟脚本直接验证；
##   - SMK-08/09/10：切换一律经 SceneRouter，拒绝路径不影响本层。


## 初始场景路径（E4-S6/R2 起 = 小镇正式地图；白盒图 A 退役为冒烟夹具）。
## 注意：初始装载【不落盘】——AutosaveNotifier 门控（save_requested_pending
## 未置位即跳过写盘），防止启动即用默认出生位覆盖玩家既有存档。
const INITIAL_SCENE_PATH: String = "res://scenes/maps/town.tscn"


func _ready() -> void:
	print("[MainController] 常驻根就绪：Main / World / UILayer(CanvasLayer) + FadeMask —— 架构 A4")
	_check_structure()
	_load_initial_scene()


## 自检 A4 结构：World 与 UILayer/FadeMask 必须存在，缺失即报错（不静默带病运行）
func _check_structure() -> void:
	var missing: Array[String] = []
	if get_node_or_null("World") == null:
		missing.append("World")
	if get_node_or_null("UILayer/FadeMask") == null:
		missing.append("UILayer/FadeMask")
	if not missing.is_empty():
		push_error("[MainController] A4 结构自检失败，缺失节点：%s——SceneRouter 切换将全部被拒" % [missing])


## 经 SceneRouter 装载初始场景；World 已有子节点时跳过（防御重复装载）
func _load_initial_scene() -> void:
	var world: Node = get_node_or_null("World")
	if world == null or world.get_child_count() > 0:
		return
	if not SceneRouter.change_scene(INITIAL_SCENE_PATH, {}, false):
		push_error("[MainController] 初始场景装载被拒（原因见 [SceneRouter] 日志）：", INITIAL_SCENE_PATH)
