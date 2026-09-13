extends GutTest
## test_m8a3_walls_ysorted.gd —— M8-A③ 收口：五图建筑层 WallsObjects 归位 YSorted 子树
##
## 【被测不变量】WallsObjects 必须是 YSorted 的子节点（不得挂地图根）。
##   y-sort 生效的充要条件 = 「参与排序的所有节点在同一 y_sort 父节点下」
##   （godot4-architecture-adr.md A6 :116；施工单 e1-s5-town-build-sheet.md :293/:397）。
##   #9 已把五图建筑层从「根直子节点」改为「YSorted 子节点」以修「玩家/NPC 恒被建筑遮挡」。
##
## 【本文件职责】该结构不变量的**引擎级漂移哨兵**——防未来「重生成/手工编辑 tscn」把
##   WallsObjects 退回根直子节点（届时 y-sort 静默失效，像素遮挡层无从自动断言）。
##   与 tools/verify_{town,road,ruins}.py 的文本级断言互补（此处在引擎实体层核对节点归属）。
##
## 【口径】PackedScene 实体装载后按节点路径取层（正则核验覆盖不到节点归属），
##   与 test_e4s2/test_e4s3 同纪律；不引入 Autoload 依赖、不进 Router。

const MAP_SCENES: Dictionary = {
	"town": "res://scenes/maps/town.tscn",
	"road": "res://scenes/maps/road.tscn",
	"ruins_f1": "res://scenes/maps/ruins_f1.tscn",
	"ruins_f2": "res://scenes/maps/ruins_f2.tscn",
	"ruins_f3": "res://scenes/maps/ruins_f3.tscn",
}


## 五图：WallsObjects 挂 YSorted 子树（旧根路径不存在）；非排序层仍挂根。
func test_五图WallsObjects均归位YSorted子树() -> void:
	for map_name: String in MAP_SCENES:
		var packed: PackedScene = load(MAP_SCENES[map_name])
		assert_not_null(packed, "%s 应可装载" % map_name)
		if packed == null:
			continue
		var map: Node = packed.instantiate()
		assert_not_null(map, "%s 应可实例化" % map_name)
		if map == null:
			continue

		# ① 新路径存在
		var walls: Node = map.get_node_or_null("YSorted/WallsObjects")
		assert_not_null(walls, "%s：WallsObjects 应挂 YSorted 子树下（#9 结构不变量）" % map_name)
		# ② 旧路径（根直子）不得再存在 —— 防漂移的关键断言
		assert_null(map.get_node_or_null("WallsObjects"),
				"%s：WallsObjects 不应再挂地图根（旧路径，防重生成/手改回退）" % map_name)
		# ③ 父节点名显式对表
		if walls != null:
			var parent: Node = walls.get_parent()
			if parent != null:
				assert_eq(parent.name, "YSorted",
						"%s：WallsObjects 父节点应为 YSorted" % map_name)
		# ④ 归属变更只动 WallsObjects：其余非排序层仍挂地图根
		for layer_name in ["Ground", "GroundDeco", "Above"]:
			assert_not_null(map.get_node_or_null(layer_name),
					"%s：%s 应仍挂地图根" % [map_name, layer_name])

		map.free()
