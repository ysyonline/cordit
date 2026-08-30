extends GutTest
## test_e4s3.gd —— E4-S3 遗迹三层地图静态断言（GDD §3.1 三层行 + §3.2 敌人三态 + §3.4）
##
## 【口径】结构/点位/BFS 已由 tools/verify_ruins.py 承担（156 项）。本文件覆盖
## 「GUT 侧应有」的最小集：三层场景 PackedScene 引擎级装载（正则核验覆盖不到的空档）、
## 三层点位数量参数化对表、f3 无普通敌人断言、f2 精英无巡逻 waypoints、
## TileSet 引用有效、spawn/出口落位静态断言。
##
## 【证据】evidence/e4s3-gut-s3.log（全量回归）+ evidence/e4s3-ruins-maps.md

const FLOORS := ["f1", "f2", "f3"]
const TILESET_PATH := "res://assets/tiles/ruins_tileset.tres"

# GDD §3.1 三层行点位对表：宝箱 3/2/1、调查 4/3/2、敌人 2 巡逻 / 1 定守 / 0
const EXPECT := {
	"f1": {"scene": "res://scenes/maps/ruins_f1.tscn", "size": "896x704",
		"chests": 3, "investigates": 4, "enemies": 2,
		"spawn": Vector2(448, 56), "limit": Rect2i(0, 0, 896, 704)},
	"f2": {"scene": "res://scenes/maps/ruins_f2.tscn", "size": "768x768",
		"chests": 2, "investigates": 3, "enemies": 1,
		"spawn": Vector2(384, 40), "limit": Rect2i(0, 0, 768, 768)},
	"f3": {"scene": "res://scenes/maps/ruins_f3.tscn", "size": "640x640",
		"chests": 1, "investigates": 2, "enemies": 0,
		"spawn": Vector2(320, 40), "limit": Rect2i(0, 0, 640, 640)},
}

var _maps: Array[Node] = []


func before_each() -> void:
	for key in FLOORS:
		_maps.append((load(EXPECT[key]["scene"]) as PackedScene).instantiate())


func after_each() -> void:
	for m in _maps:
		if is_instance_valid(m):
			m.queue_free()
	_maps.clear()


## 用例1：三层场景均可 PackedScene 装载且根脚本正确（引擎级解析，verify 正则覆盖不到）
func test_01_三层场景可装载且根脚本正确() -> void:
	for i in FLOORS.size():
		var key: String = FLOORS[i]
		var packed: PackedScene = load(EXPECT[key]["scene"])
		assert_not_null(packed, "ruins_%s.tscn 应可装载" % key)
		var m: Node = _maps[i]
		assert_not_null(m, "ruins_%s 实例化不应为 null" % key)
		if m != null:
			var expect_script := "res://scripts/maps/ruins_%s_map.gd" % key
			assert_eq(m.get_script().resource_path, expect_script, "ruins_%s 根脚本" % key)


## 用例2：三层四层 TileMapLayer 齐备且共享 ruins TileSet 引用有效
func test_02_四层齐备且共享tileset有效() -> void:
	for i in FLOORS.size():
		var key: String = FLOORS[i]
		var m: Node = _maps[i]
		for layer_name in ["Ground", "GroundDeco", "WallsObjects", "Above"]:
			var layer: TileMapLayer = m.get_node_or_null(layer_name)
			assert_not_null(layer, "ruins_%s/%s 应存在" % [key, layer_name])
			if layer != null:
				assert_not_null(layer.tile_set, "%s 的 tile_set 不应为 null" % layer_name)
				assert_eq(layer.tile_set.resource_path, TILESET_PATH,
					"ruins_%s/%s 应挂共享 TileSet" % [key, layer_name])


## 用例3：三层点位数量参数化对表（宝箱 3/2/1、调查 4/3/2——GDD §3.1 正本）
func test_03_三层点位数量对表() -> void:
	for i in FLOORS.size():
		var key: String = FLOORS[i]
		var anchors: Node = _maps[i].get_node_or_null("YSorted/Anchors")
		assert_not_null(anchors, "ruins_%s Anchors 应存在" % key)
		if anchors != null:
			var chests := 0
			var investigates := 0
			for anchor in anchors.get_children():
				if String(anchor.name).begins_with("Chest_ruins_"):
					chests += 1
				elif String(anchor.name).begins_with("Investigate_ruins_"):
					investigates += 1
			assert_eq(chests, EXPECT[key]["chests"], "ruins_%s 宝箱数" % key)
			assert_eq(investigates, EXPECT[key]["investigates"], "ruins_%s 调查点数" % key)


## 用例4：敌人数量与形态对表——f1 巡逻 2 / f2 定守 1 / f3 零普通敌人（Boss 事件触发）
func test_04_敌人数量与形态对表() -> void:
	for i in FLOORS.size():
		var key: String = FLOORS[i]
		var enemies := 0
		for child in _maps[i].get_node("YSorted").get_children():
			# 排除玩家（同为 CharacterBody2D）；visible_enemy 实例以 enemy_uid 导出量识别
			if child is CharacterBody2D and "enemy_uid" in child:
				enemies += 1
		assert_eq(enemies, EXPECT[key]["enemies"], "ruins_%s 敌人数（GDD §3.1）" % key)


## 用例5：f2 精英定守位即交战位——空 waypoints 且站位在大厅中央带（GDD §3.2 定守态）
func test_05_f2精英定守无巡逻点() -> void:
	var elite: Node = _maps[1].get_node_or_null("YSorted/Enemy_ruins_f2_elite")
	assert_not_null(elite, "f2 精英实体应存在")
	if elite != null:
		assert_eq(elite.group_id, "b4_guardian", "精英编组应为 b4_guardian（B4 遗像守卫）")
		assert_eq(elite.waypoints.size(), 0, "定守态 waypoints 应为空（无巡逻）")
		var pos: Vector2 = elite.position
		assert_true(pos.x >= 14 * 16 and pos.x <= 34 * 16 and pos.y >= 12 * 16 and pos.y <= 32 * 16,
			"精英站位应在中央大厅带（站位即交战位）")


## 用例6：f1 敌人编组 B3×2 且均有巡逻 waypoints（GDD §3.2 巡逻态 + 战斗 GDD §7 B3）
func test_06_f1敌人巡逻态对表() -> void:
	var found := 0
	for child in _maps[0].get_node("YSorted").get_children():
		# 排除玩家（同为 CharacterBody2D）；visible_enemy 实例以 enemy_uid 导出量识别
		if child is CharacterBody2D and "enemy_uid" in child:
			found += 1
			assert_eq(child.group_id, "b3_ruin_mix", "f1 敌人编组应为 b3_ruin_mix")
			assert_eq(child.waypoints.size(), 2, "巡逻态应有 2 个 waypoints")
			assert_eq(child.return_map, "res://scenes/maps/ruins_f1.tscn", "return_map 应为本图")
	assert_eq(found, 2, "f1 敌人应为 2")


## 用例7：f3 零普通敌人 + Boss 触发器锚点 ×2 + 石棺/灰石门构图件齐备（I5 事件锚点预留）
func test_07_f3_boss前厅构图() -> void:
	var boss_triggers: Node = _maps[2].get_node_or_null("YSorted/BossTriggers")
	assert_not_null(boss_triggers, "f3 BossTriggers 容器应存在")
	if boss_triggers != null:
		assert_eq(boss_triggers.get_child_count(), 2, "Boss 触发器锚点应 ×2（棺前 2 格）")
	# 构件抽验：石棺 2×1 挂 Walls 层（tile 9:16 / 10:16，verify_ruins §7 已复核坐标）
	var walls: TileMapLayer = _maps[2].get_node("WallsObjects")
	assert_true(walls.get_used_rect().size.x > 0, "f3 Walls 层应有内容（石棺/灰石门所在层）")


## 用例8：三层地图脚本限区与出生落位导出量（E4-S6 接线依据：from_road/from_f1/from_f2）
func test_08_三层限区与落位导出量() -> void:
	for i in FLOORS.size():
		var key: String = FLOORS[i]
		var m: Node = _maps[i]
		assert_eq(m.limits_main, EXPECT[key]["limit"], "ruins_%s 主限区" % key)
		var spawn: Vector2 = EXPECT[key]["spawn"]
		var pos_prop: String = ["pos_from_road", "pos_from_f1", "pos_from_f2"][i]
		assert_eq(m.get(pos_prop), spawn, "ruins_%s %s 落位" % [key, pos_prop])
