extends GutTest
## test_e4s2.gd —— E4-S2 道路地图静态断言（GDD §3.1 道路行 + §3.4 制作校验项）
##
## 【口径】结构/点位对表已由 tools/verify_road.py 承担（65 项，BFS 连通性 +
## spawn 安全区为 Python 侧独有）。本文件覆盖「GUT 侧应有」的最小集：
## 场景可装载、敌人实体导出量正确、TileSet 引用有效——防止 .tscn 文本
## 通过静态核验但引擎装载即崩的空档（PackedScene 级验证只有引擎能做）。
##
## 【证据】evidence/e4s2-gut-s2.log（全量回归）+ evidence/e4s2-road-map.md

const ROAD_SCENE_PATH := "res://scenes/maps/road.tscn"
const TILESET_PATH := "res://assets/tiles/town_map_tileset.tres"
const ENEMY_SCENE_PATH := "res://scenes/enemies/visible_enemy.tscn"

var _road: Node = null


func after_each() -> void:
	if is_instance_valid(_road):
		_road.queue_free()
	_road = null


## 用例1：场景可被 PackedScene 装载（引擎级解析，verify_road.py 的正则覆盖不到）
func test_01_场景可装载且根脚本正确() -> void:
	assert_true(ResourceLoader.exists(ROAD_SCENE_PATH, "PackedScene"), "road.tscn 应存在")
	var packed: PackedScene = load(ROAD_SCENE_PATH)
	assert_not_null(packed, "PackedScene 装载不应为 null")
	_road = packed.instantiate()
	assert_not_null(_road, "实例化不应为 null")
	assert_eq(_road.get_script().resource_path, "res://scripts/maps/road_map.gd", "根脚本应为 road_map.gd")


## 用例2：四层 TileMapLayer 齐备且共享 TileSet 引用有效
func test_02_四层齐备且tileset引用有效() -> void:
	_road = (load(ROAD_SCENE_PATH) as PackedScene).instantiate()
	for layer_name in ["Ground", "GroundDeco", "WallsObjects", "Above"]:
		var layer: TileMapLayer = _road.get_node_or_null(layer_name)
		assert_not_null(layer, "TileMapLayer %s 应存在" % layer_name)
		if layer != null:
			assert_not_null(layer.tile_set, "%s 的 tile_set 不应为 null" % layer_name)
			assert_eq(layer.tile_set.resource_path, TILESET_PATH, "%s 应挂共享 TileSet" % layer_name)


## 用例3：3 个敌人实体导出量正确（uid/group/waypoints，对表战斗 GDD B1/B2）
func test_03_三个敌人实体导出量正确() -> void:
	_road = (load(ROAD_SCENE_PATH) as PackedScene).instantiate()
	var expect := {
		"Enemy_road_moth_01": {"uid": "road_moth_01", "group": "b1_moth", "wp": 2},
		"Enemy_road_beetle_01": {"uid": "road_beetle_01", "group": "b2_beetles", "wp": 2},
		"Enemy_road_beetle_02": {"uid": "road_beetle_02", "group": "b2_beetles", "wp": 2},
	}
	for enemy_name in expect:
		var enemy: Node = _road.get_node_or_null("YSorted/%s" % enemy_name)
		assert_not_null(enemy, "敌人实体 %s 应存在" % enemy_name)
		if enemy != null:
			assert_eq(enemy.enemy_uid, expect[enemy_name]["uid"], "%s enemy_uid" % enemy_name)
			assert_eq(enemy.group_id, expect[enemy_name]["group"], "%s group_id" % enemy_name)
			assert_eq(enemy.waypoints.size(), expect[enemy_name]["wp"], "%s 巡逻点数" % enemy_name)


## 用例4：点位锚点对表（宝箱 2 / 调查 3，GDD §3.1 道路行）
func test_04_点位锚点对表() -> void:
	_road = (load(ROAD_SCENE_PATH) as PackedScene).instantiate()
	var anchors: Node = _road.get_node_or_null("YSorted/Anchors")
	assert_not_null(anchors, "Anchors 容器应存在")
	if anchors != null:
		var chests := 0
		var investigates := 0
		for anchor in anchors.get_children():
			if String(anchor.name).begins_with("Chest_road_"):
				chests += 1
			elif String(anchor.name).begins_with("Investigate_road_"):
				investigates += 1
		assert_eq(chests, 2, "宝箱锚点应为 2（GDD §3.1 道路行）")
		assert_eq(investigates, 3, "调查锚点应为 3（GDD §3.1 道路行）")


## 用例5：断桥封边碰撞体存在且为静态墙体层（层1）——防玩家坠入虚空
func test_05_断桥封边碰撞体存在() -> void:
	_road = (load(ROAD_SCENE_PATH) as PackedScene).instantiate()
	var blocker: StaticBody2D = _road.get_node_or_null("ChasmBlocker")
	assert_not_null(blocker, "ChasmBlocker 应存在")
	if blocker != null:
		assert_eq(blocker.collision_layer, 1, "封边体应属世界墙体层（层1）")
		var shape: CollisionShape2D = blocker.get_node_or_null("CollisionShape2D")
		assert_not_null(shape, "封边体应有碰撞形状")
		if shape != null:
			assert_true(shape.shape is RectangleShape2D, "封边体形状应为矩形")


## 用例6：地图脚本限区与落位导出量（from_town 出生位 (384,64)，768×1024 限区）
func test_06_地图脚本限区与落位() -> void:
	_road = (load(ROAD_SCENE_PATH) as PackedScene).instantiate()
	assert_eq(_road.limits_main, Rect2i(0, 0, 768, 1024), "主限区应为 48×64 tile 像素")
	assert_eq(_road.pos_from_town, Vector2(384, 64), "from_town 落位应为道路中线 (384,64)")
