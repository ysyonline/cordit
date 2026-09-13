extends GutTest
## test_e4s6.gd —— E4-S6 传送网络 + 进图自动存档 GUT 用例
##
## 【断言覆盖】探索 GDD §3.4 精确时序 + E4-S6 施工单：
##   A. 目录结构：12 处传送定义齐备（4 同图 + 8 跨图），字段类型合法；
##   B. 同构锁定（拍板项④）：TeleportCatalog ↔ teleports.json 逐字段镜像；
##   C. 装配：五图装载后触发器实体全部在树（逐图计数 + 命名 + 脚本挂载）；
##   D. 同位：同图 4 处触发器与旧 tscn 门位同像素（防 E2-S5 验收行为漂移）；
##   E. 落位防弹回：12 处落位像素与触发区 ±12px 脚底盒零重合（含跨图 y 向）；
##   F. 目录↔场景 export 镜像：SAME_MAP_LIMITS ↔ town_map @export 三组限区；
##      跨图 to_spawn ↔ 各图 pos_from_* @export（首入口径一致）；
##   G. 薄壳行为：同图传送改位置+换限区；跨图传送发意图+换图（Gate 环境）；
##   H. 门控存档：无意图不落盘（启动装载）；意图置位→map_ready 消费落盘；
##      consume-on-read 语义（二次调用不再落盘）；
##   I. E2-S2 回归修复：装配触发器 collision_mask=16（玩家实体层）。
##
## 【测试策略】地图装载 instantiate + add_child 直驱（不经 Router，同
##   test_e4s5 纪律）；GameData 快照恢复 + save_path 覆写隔离（SMK-12）；
##   存档意图位 SaveManager.save_requested_pending 用例前后强制清零。

const TeleportCatalog := preload("res://scripts/events/teleport_catalog.gd")
const TeleportAssembler := preload("res://scripts/events/teleport_assembler.gd")
const TriggerScript := preload("res://scripts/events/trigger_teleport.gd")
const AutosaveNotifier := preload("res://scripts/events/autosave_notifier.gd")

const MAP_SCENES: Dictionary = {
	"town": "res://scenes/maps/town.tscn",
	"road": "res://scenes/maps/road.tscn",
	"ruins_f1": "res://scenes/maps/ruins_f1.tscn",
	"ruins_f2": "res://scenes/maps/ruins_f2.tscn",
	"ruins_f3": "res://scenes/maps/ruins_f3.tscn",
}
## 每图触发器计数对表（目录 by_map 正本镜像；4 同图 + 8 跨图 = 12）
const EXPECT_TRIGGERS: Dictionary = {
	"town": 5, "road": 2, "ruins_f1": 2, "ruins_f2": 2, "ruins_f3": 1,
}
## 旧 tscn 门位（1×1 门垫中心像素，gen_town.py 生成原值）——同位校验基准
const LEGACY_DOOR_PX: Dictionary = {
	"tp_town_door_inn": Vector2(472, 296),
	"tp_town_door_house_a": Vector2(200, 296),
	"tp_town_inn_exit": Vector2(1368, 296),
	"tp_town_house_a_exit": Vector2(1368, 488),
}
## 跨图 to_spawn ↔ 各图首入 @export 镜像（目录 ENTRY_SPAWNS 同源）
const ENTRY_EXPORTS: Dictionary = {
	"town": ["pos_inn_spawn"],   # 占位：town 无首入 export，见 F 组用例说明
	"road": "pos_from_town",
	"ruins_f1": "pos_from_road",
	"ruins_f2": "pos_from_f1",
	"ruins_f3": "pos_from_f2",
}

const TEST_PATH: String = "user://e4s6_test_save.json"

## M8-A1：战后处理器脚本 + 真图路径（缺陷 2 回图存档坐标实证/回归用）
const HANDLER_SCRIPT: GDScript = preload("res://scripts/battle/battle_result_handler.gd")
const ROAD_MAP_PATH: String = "res://scenes/maps/road.tscn"

## 五图 Player 在 tscn 里的硬编码初始位（缺陷 1/2 的辨识锚：正确落位值应≠硬编码位）
const HARDCODED_PLAYER_PX: Dictionary = {
	"town": Vector2(192, 640),
	"road": Vector2(384, 64),
	"ruins_f1": Vector2(448, 56),
	"ruins_f2": Vector2(384, 40),
	"ruins_f3": Vector2(320, 40),
}

var _maps: Array[Node] = []

## 假 Main 骨架（缺陷 2 用例经 Router 真装载目标图；after_each 拆除）
var _fake_main: Node = null

## GameData 快照（缺陷 2 VICTORY 用例真写全局单例，测后还原防泄漏）
var _cleared_backup: Array = []
var _phase_backup: int = 0


## 跨用例隔离：清 Router 跨图落位意图位（M8-A1 新增字段；按方法存在性防御，
## 使本文件在缺陷修复前后都能运行——修复前为 no-op）。
func _reset_pending_spawn() -> void:
	if SceneRouter.has_method("consume_pending_spawn"):
		SceneRouter.consume_pending_spawn()


func before_all() -> void:
	SaveManager.save_path = SaveManager.SAVE_PATH
	_cleared_backup = (GameData.cleared_enemy_set as Array).duplicate()
	_phase_backup = GameData.story_phase


func after_all() -> void:
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}
	_reset_pending_spawn()
	GameData.cleared_enemy_set = _cleared_backup.duplicate()
	GameData.story_phase = _phase_backup
	_cleanup_test_files()


func before_each() -> void:
	SaveManager.save_path = TEST_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}
	# M8-A1：Router 簿记隔离（假 Main / 暂存 payload / 切换标志 / 落位意图）
	SceneRouter._staged_payload = {}
	SceneRouter.current_scene_path = ""
	SceneRouter._switching = false
	_reset_pending_spawn()
	_fake_main = null
	_cleanup_test_files()


func after_each() -> void:
	for m: Node in _maps:
		if is_instance_valid(m):
			m.queue_free()
	_maps.clear()
	SaveManager.save_requested_pending = false
	# M8-A1：假 Main 拆除 + GameData 还原（缺陷 2 VICTORY 用例）
	if _fake_main != null and is_instance_valid(_fake_main):
		_fake_main.free()
	_fake_main = null
	_reset_pending_spawn()
	GameData.cleared_enemy_set = _cleared_backup.duplicate()
	GameData.story_phase = _phase_backup
	_cleanup_test_files()


func _cleanup_test_files() -> void:
	for p: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## 装载一张图入测试树（触发 _ready 装配；意图位已清零，不落盘）
func _load_map(map_name: String) -> Node:
	var packed: PackedScene = load(MAP_SCENES[map_name])
	var map: Node = packed.instantiate()
	add_child_autofree(map)
	_maps.append(map)
	return map


# =============== A. 目录结构 ===============

func test_01_目录12处传送齐备且分类正确() -> void:
	assert_eq(TeleportCatalog.TELEPORTS.size(), 12, "目录应登记 12 处传送")
	var same := 0
	var cross := 0
	var ids: Array[String] = []
	for spec: Dictionary in TeleportCatalog.TELEPORTS:
		var id: String = String(spec["id"])
		assert_false(ids.has(id), "传送 id 应唯一：%s" % id)
		ids.append(id)
		assert_true(TeleportCatalog.MAP_SCENE_PATHS.has(String(spec["map"])),
				"%s 的 map 应为五图之一" % id)
		var kind: String = String(spec["kind"])
		assert_true(kind in ["same_map", "cross_map"], "%s kind 非法" % id)
		if kind == "same_map":
			same += 1
			assert_true(spec["target"] is Vector2, "%s 同图应有 target" % id)
		else:
			cross += 1
			assert_true(TeleportCatalog.MAP_SCENE_PATHS.has(String(spec["to_map"])),
					"%s to_map 应登记场景路径" % id)
	assert_eq(same, 4, "同图传送应 4 处（town 室内）")
	assert_eq(cross, 8, "跨图传送应 8 处")


func test_02_静态辅助函数协议() -> void:
	assert_eq(TeleportCatalog.tile_to_pixel(Vector2(3, 4)), Vector2(56, 72),
			"tile_to_pixel 应为 tile*16+8 格中心口径")
	var spec: Dictionary = TeleportCatalog.by_id("tp_town_door_inn")
	assert_false(spec.is_empty(), "by_id 应命中已登记 id")
	assert_true(TeleportCatalog.by_id("tp_not_exist").is_empty(), "未登记 id 返回空字典")
	assert_eq(TeleportCatalog.entity_name("tp_x"), "Evt_tp_x", "实体名应有 Evt_ 前缀")
	# trigger_pixel_pos：触发区中心 = 左上 tile*16 + size*8（半格尺寸）
	assert_eq(TeleportCatalog.trigger_pixel_pos(spec), Vector2(472, 296),
			"Door_Inn 触发区中心应与旧门位一致")


# =============== B. 目录↔JSON 同构 ===============

func test_03_目录与JSON镜像同构() -> void:
	var text: String = FileAccess.get_file_as_string("res://data/json/events/teleports.json")
	var parsed: Variant = JSON.parse_string(text)
	assert_not_null(parsed, "teleports.json 应可解析")
	if not (parsed is Dictionary):
		return
	var entries: Array = (parsed as Dictionary)["teleports"]
	assert_eq(entries.size(), TeleportCatalog.TELEPORTS.size(), "条目数一致")
	for i: int in entries.size():
		var j: Dictionary = entries[i]
		var g: Dictionary = TeleportCatalog.TELEPORTS[i]
		var tid: String = String(j["id"])
		assert_eq(tid, String(g["id"]), "第 %d 条 id 顺序一致" % i)
		assert_eq(String(j["map"]), String(g["map"]), "%s map 一致" % tid)
		var jtile: Array = j["tile"]
		assert_eq(Vector2i(jtile[0], jtile[1]), g["tile"], "%s tile 一致" % tid)
		var jsz: Array = j["size"]
		assert_eq(Vector2i(jsz[0], jsz[1]), g["size"], "%s size 一致" % tid)
		assert_eq(String(j["kind"]), String(g["kind"]), "%s kind 一致" % tid)
		var jtarget: Array = j["target"]
		assert_eq(Vector2(jtarget[0], jtarget[1]), g["target"], "%s target 一致" % tid)
		assert_eq(String(j["to_map"]), String(g["to_map"]), "%s to_map 一致" % tid)
		var jspawn: Array = j["to_spawn"]
		assert_eq(Vector2(jspawn[0], jspawn[1]), g["to_spawn"], "%s to_spawn 一致" % tid)


# =============== C. 装配（五图逐图计数） ===============

func test_04_五图装配触发器计数与命名() -> void:
	for map_name: String in EXPECT_TRIGGERS:
		var map: Node = _load_map(map_name)
		var container: Node = map.get_node_or_null("Triggers")
		assert_not_null(container, "%s 应有 Triggers 容器" % map_name)
		if container == null:
			continue
		var built: Array = map.get("teleports")
		assert_eq(built.size(), EXPECT_TRIGGERS[map_name],
				"%s 装配数应 %d" % [map_name, EXPECT_TRIGGERS[map_name]])
		for trigger: Area2D in built:
			assert_true(trigger.get_script() == TriggerScript,
					"%s 触发器应挂薄壳脚本" % trigger.name)
			assert_false(String(trigger.name).begins_with("Door_"),
					"旧直连门名不应残留（同位重建退役）：%s" % trigger.name)
			assert_false(String(trigger.name).begins_with("Inn_Exit"),
					"旧出口名不应残留：%s" % trigger.name)


func test_05_town旧门Area2D已退役_同帧以计数与命名判定() -> void:
	# 注意：装配器对旧门 queue_free 是帧末生效，同帧内旧 Area2D 仍在树上——
	# 故退役语义不能按"无脚本节点不存在"断言，改按两个可同步观察的量判定：
	# ① 装配产物计数 = 目录定义数（5：4 室内 + 1 南门）；
	# ② 产物全部挂薄壳脚本且用 Evt_ 命名（旧直连门无脚本、旧命名不复发）。
	var map: Node = _load_map("town")
	var built: Array = map.get("teleports")
	assert_eq(built.size(), 5, "town 装配数应 5（4 室内门 + 南门）")
	for trigger: Area2D in built:
		assert_true(trigger.get_script() == TriggerScript, "%s 应挂薄壳" % trigger.name)
		assert_true(String(trigger.name).begins_with("Evt_tp_"),
				"命名应为 Evt_tp_*（旧 Door_*/ *_Exit 命名退役）：%s" % trigger.name)


# =============== D. 同位校验（旧门行为平移） ===============

func test_06_town四门同位重建像素一致() -> void:
	var map: Node = _load_map("town")
	for trigger: Area2D in map.get("teleports"):
		var tid: String = trigger.teleport_id
		if LEGACY_DOOR_PX.has(tid):
			assert_eq(trigger.position, LEGACY_DOOR_PX[tid],
					"%s 应与旧 tscn 门位同像素" % tid)
			# 形状尺寸 = 1×1 门垫 16×16
			var shape_node: CollisionShape2D = trigger.get_node("CollisionShape2D")
			assert_eq((shape_node.shape as RectangleShape2D).size, Vector2(16, 16),
					"%s 门垫尺寸应 16×16" % tid)


# =============== E. 落位防弹回（12 处全审计） ===============

func test_07_全部落位与触发区零重合() -> void:
	for spec: Dictionary in TeleportCatalog.TELEPORTS:
		var tid: String = String(spec["id"])
		var tl: Vector2i = spec["tile"]
		var sz: Vector2i = spec["size"]
		var target: Vector2 = spec["target"] if String(spec["kind"]) == "same_map" \
				else spec["to_spawn"]
		var px := TeleportCatalog.tile_to_pixel(target)
		# 脚底盒 ±12px（player 碰撞盒半宽）与触发区矩形重合检测：
		# 两轴重合量均 > 0 才算碰撞，取单轴最小值量化重叠深度
		var x_min: float = tl.x * 16.0
		var x_max: float = (tl.x + sz.x) * 16.0
		var y_min: float = tl.y * 16.0
		var y_max: float = (tl.y + sz.y) * 16.0
		var overlap_x: float = minf(x_max, px.x + 12.0) - maxf(x_min, px.x - 12.0)
		var overlap_y: float = minf(y_max, px.y + 12.0) - maxf(y_min, px.y - 12.0)
		var ov: float = 0.0
		if overlap_x > 0.0 and overlap_y > 0.0:
			ov = minf(overlap_x, overlap_y)
		assert_true(ov <= 0.0,
				"%s 落位 %s 与触发区应零重合（实测 %.0fpx）" % [tid, px, ov])


func test_08_同图落位为整数格中心() -> void:
	# e4s6 目录初稿半格 (85.5,17.5) 缺陷回归锚：同图 target 必须整数格
	for spec: Dictionary in TeleportCatalog.TELEPORTS:
		if String(spec["kind"]) != "same_map":
			continue
		var t: Vector2 = spec["target"]
		assert_eq(t.x, floorf(t.x), "%s target.x 应整数格" % spec["id"])
		assert_eq(t.y, floorf(t.y), "%s target.y 应整数格" % spec["id"])


# =============== F. 目录↔场景 export 镜像 ===============

func test_09_限区镜像_目录SAME_MAP_LIMITS对表() -> void:
	var map: Node = _load_map("town")
	assert_eq(map.limits_main, Rect2i(0, 0, 1024, 768), "主图限区 export")
	assert_eq(map.limits_inn, Rect2i(1056, 0, 640, 360), "室内A 限区 export")
	assert_eq(map.limits_house, Rect2i(1056, 188, 640, 360), "室内B 限区 export")
	# 目录侧 SAME_MAP_LIMITS 与 export 数值互为镜像
	assert_eq(TeleportCatalog.SAME_MAP_LIMITS["tp_town_door_inn"], map.limits_inn,
			"door_inn 限区 = limits_inn")
	assert_eq(TeleportCatalog.SAME_MAP_LIMITS["tp_town_door_house_a"], map.limits_house,
			"door_house_a 限区 = limits_house")
	assert_eq(TeleportCatalog.SAME_MAP_LIMITS["tp_town_inn_exit"], map.limits_main,
			"inn_exit 限区 = limits_main")
	assert_eq(TeleportCatalog.SAME_MAP_LIMITS["tp_town_house_a_exit"], map.limits_main,
			"house_a_exit 限区 = limits_main")


func test_10_跨图首入落位与各图export一致() -> void:
	# 目录 ENTRY_SPAWNS（首入参考）↔ 各图 pos_from_* @export（首入口径同源）
	var map: Node = _load_map("road")
	assert_eq(map.pos_from_town,
			TeleportCatalog.tile_to_pixel(TeleportCatalog.ENTRY_SPAWNS["road"]),
			"road pos_from_town = 目录首入 tile 转像素")
	map = _load_map("ruins_f1")
	assert_eq(map.pos_from_road,
			TeleportCatalog.tile_to_pixel(TeleportCatalog.ENTRY_SPAWNS["ruins_f1"]),
			"f1 pos_from_road = 目录首入")
	map = _load_map("ruins_f2")
	assert_eq(map.pos_from_f1,
			TeleportCatalog.tile_to_pixel(TeleportCatalog.ENTRY_SPAWNS["ruins_f2"]),
			"f2 pos_from_f1 = 目录首入")
	map = _load_map("ruins_f3")
	assert_eq(map.pos_from_f2,
			TeleportCatalog.tile_to_pixel(TeleportCatalog.ENTRY_SPAWNS["ruins_f3"]),
			"f3 pos_from_f2 = 目录首入")


# =============== G. 薄壳行为（直驱协议层） ===============

func test_11_薄壳同图传送_改位置与换限区() -> void:
	var map: Node = _load_map("town")
	var player: CharacterBody2D = map.get_node("YSorted/Player")
	var trigger: Area2D = map.get_node("Triggers/Evt_tp_town_door_inn")
	trigger._do_same_map(TeleportCatalog.by_id("tp_town_door_inn"), player)
	assert_eq(player.global_position, Vector2(1368, 280),
			"同图传送应落 (85,17) 格中心 (1368,280)")
	var cam: Camera2D = player.get_node("Camera2D")
	assert_eq(cam.limit_left, 1056, "传送后相机限区应切室内A")
	assert_eq(cam.limit_right, 1056 + 640, "室内A 右界")
	assert_eq(cam.limit_bottom, 360, "室内A 下界")


func test_12_薄壳碰撞层位_E2S2回归修复() -> void:
	var map: Node = _load_map("town")
	for trigger: Area2D in map.get("teleports"):
		assert_eq(trigger.collision_layer, 0, "触发器自身 layer 应为 0")
		assert_eq(trigger.collision_mask, 16,
				"触发器 mask 应为 16（玩家实体层，E2-S2 回归修复）")


func test_13_body过滤_非玩家与对话期不触发() -> void:
	var map: Node = _load_map("town")
	var player: CharacterBody2D = map.get_node("YSorted/Player")
	var trigger: Area2D = map.get_node("Triggers/Evt_tp_town_door_inn")
	# 敌人层实体（layer 8）不触发
	var fake_enemy := CharacterBody2D.new()
	fake_enemy.collision_layer = 8
	map.add_child(fake_enemy)
	trigger._on_body_entered(fake_enemy)
	assert_ne(fake_enemy.global_position, Vector2(1368, 280), "非玩家层不触发传送")
	fake_enemy.queue_free()
	# 玩家 + 对话非 IDLE：闸门拦截
	map.dialogue_runner.state = map.dialogue_runner.State.PLAYING
	player.global_position = Vector2.ZERO
	trigger._on_body_entered(player)
	assert_eq(player.global_position, Vector2.ZERO, "对话期触发器不响应")
	map.dialogue_runner.state = map.dialogue_runner.State.IDLE
	# 冷却期内不重复触发
	trigger._cooldown = 0.5
	trigger._on_body_entered(player)
	assert_eq(player.global_position, Vector2.ZERO, "冷却期内不触发")


# =============== H. 门控存档（§3.4 时序核心） ===============

func test_14_无意图装载地图不落盘() -> void:
	assert_false(FileAccess.file_exists(TEST_PATH), "前置：测试存档不存在")
	_load_map("town")   # _ready → announce_ready（意图位 before_each 已清零）
	assert_false(FileAccess.file_exists(TEST_PATH),
			"启动装载（无意图）不得写盘——防默认出生位覆盖既有存档")


func test_15_意图置位后map_ready消费落盘() -> void:
	SaveManager.save_requested_pending = true
	var map: Node = _load_map("town")
	var player: CharacterBody2D = map.get_node("YSorted/Player")
	assert_true(FileAccess.file_exists(TEST_PATH), "有意图应落盘")
	assert_true(SaveManager.load_save(), "落盘内容应可读回")
	assert_eq(SaveManager.last_loaded["map"], "town", "存档 map 字段 = 图名")
	var pos: Array = SaveManager.last_loaded["position"]
	var loaded := Vector2(pos[0], pos[1])
	assert_eq(loaded, player.global_position, "存档坐标 = 玩家实际落位")


func test_16_意图位consume_on_read语义() -> void:
	SaveManager.save_requested_pending = true
	assert_true(SaveManager.consume_save_request(), "首次消费应 true")
	assert_false(SaveManager.consume_save_request(), "二次消费应 false（consume-on-read）")


func test_17_save_requested信号置位意图() -> void:
	assert_false(SaveManager.save_requested_pending, "前置：无意图")
	EventBus.save_requested.emit()   # trigger_teleport._do_cross_map 受理后发射
	assert_true(SaveManager.save_requested_pending, "信号应置位存档意图")


# =============== I. 通知器与图标协议 ===============

func test_18_通知器返回值语义() -> void:
	# 无意图 → false（跳过写盘）
	assert_false(AutosaveNotifier.announce_ready(_load_map("road"), "road_test"),
			"无意图返回 false")
	# 有意图 → true（落盘成功）
	SaveManager.save_requested_pending = true
	assert_true(AutosaveNotifier.announce_ready(_maps[0], "road_test2"),
			"有意图且写盘成功返回 true")


func test_19_跨图传送目录场景路径闭环() -> void:
	# 8 处跨图 to_map 全部能在 MAP_SCENE_PATHS 闭环解析（防断链）
	var cross_count := 0
	for spec: Dictionary in TeleportCatalog.TELEPORTS:
		if String(spec["kind"]) != "cross_map":
			continue
		cross_count += 1
		var path: String = TeleportCatalog.MAP_SCENE_PATHS[String(spec["to_map"])]
		assert_true(ResourceLoader.exists(path, "PackedScene"),
				"%s 目标场景应存在：%s" % [spec["id"], path])
	assert_eq(cross_count, 8, "跨图应 8 处")


# =============== J. 跨图落位（缺陷 1 修复锚） ===============
# 【修复语义】跨图传送的落位（to_spawn）由目标图 _ready 的 TeleportAssembler
# 消费 SceneRouter 的落位意图完成——必须在 announce_ready 读位置存档【之前】，
# 否则自动存档记成目标图 tscn 硬编码入口位（§3.4「过传送点存」的坐标口径）。
# 【测试策略】直接登记落位意图 + 装载目标图（instantiate 直驱，同本文件纪律），
# 断言玩家落位与随后存档坐标均为 to_spawn 像素位。

func test_20_跨图落位_装配器消费pending落到to_spawn() -> void:
	for spec: Dictionary in TeleportCatalog.TELEPORTS:
		if String(spec["kind"]) != "cross_map":
			continue
		var tid: String = String(spec["id"])
		var to_map: String = String(spec["to_map"])
		var expected: Vector2 = TeleportCatalog.tile_to_pixel(spec["to_spawn"])
		SceneRouter.set_pending_spawn(expected)
		var map: Node = _load_map(to_map)
		var player: Node2D = map.get_node("YSorted/Player")
		assert_eq(player.global_position, expected,
				"%s：目标图 %s 玩家应落在 to_spawn %s" % [tid, to_map, expected])


func test_21_跨图落位后存档坐标为落位值() -> void:
	# f3→f2 返程最佳辨识锚：目标图 ruins_f2 硬编码 (384,40) 与落位 (384,736) 显著不同
	var spec: Dictionary = TeleportCatalog.by_id("tp_f3_to_f2")
	var expected: Vector2 = TeleportCatalog.tile_to_pixel(spec["to_spawn"])
	assert_ne(expected, HARDCODED_PLAYER_PX["ruins_f2"],
			"前置：落位应≠ruins_f2 tscn 硬编码位")
	SceneRouter.set_pending_spawn(expected)
	SaveManager.save_requested_pending = true   # 模拟跨图传送受理后的存档意图
	_load_map("ruins_f2")
	assert_true(FileAccess.file_exists(TEST_PATH), "有落位+存档意图应落盘")
	assert_true(SaveManager.load_save(), "落盘内容应可读回")
	assert_eq(SaveManager.last_loaded["map"], "ruins_f2", "存档 map = 目标图名")
	var pos: Array = SaveManager.last_loaded["position"]
	assert_eq(Vector2(pos[0], pos[1]), expected,
			"存档坐标应为 to_spawn 落位值（非 ruins_f2 tscn 硬编码 (384,40)）")


func test_22_无落位意图时装配器不动玩家位置() -> void:
	# 启动装载 / 同图室内传送 / 战斗回图：无意图 → 玩家保持 tscn 硬编码位
	var map: Node = _load_map("ruins_f2")
	var player: Node2D = map.get_node("YSorted/Player")
	assert_eq(player.global_position, HARDCODED_PLAYER_PX["ruins_f2"],
			"无 pending 时玩家应保持 tscn 初始位")


func test_23_传送被拒时落位意图回滚() -> void:
	# GUT 直挂环境无 Main/World → change_scene 必拒（结构检查）→ 落位意图须 consume 回滚
	var trigger := Area2D.new()
	trigger.set_script(TriggerScript)
	trigger.teleport_id = "tp_f3_to_f2"
	SceneRouter.set_pending_spawn(Vector2(999, 999))
	trigger._do_cross_map(TeleportCatalog.by_id("tp_f3_to_f2"))
	assert_eq(SceneRouter.consume_pending_spawn(), null,
			"被拒后落位意图应已回滚（consume 返回 null）")
	trigger.free()


func test_24_跨图传送真实链路_f3南门踩踏落位与存档() -> void:
	# 【玩家驱动链】不直驱落位簿记：玩家踩 f3 南门触发区 → _on_body_entered
	# → _do_cross_map → Router change_scene → 目标图 f2 _ready → 装配器消费
	# 落位意图 → announce_ready 存档。断言落位与存档坐标一致且为目标落位。
	# 【为何带 FadeMask】生产 main.tscn 有 UILayer/FadeMask → change_scene 异步
	# 淡出后才装载目标图（存档意图在装载前已发出）；本用例造同款骨架复刻该
	# 时序，避免"无遮罩同步装载"使存档意图晚于装载的测试失真。
	_make_fake_main(true)
	var f3: Node = _load_map("ruins_f3")
	var player: CharacterBody2D = f3.get_node("YSorted/Player")
	var trigger: Area2D = f3.get_node("Triggers/Evt_tp_f3_to_f2")
	SaveManager.save_requested_pending = false
	_cleanup_test_files()
	var spec: Dictionary = TeleportCatalog.by_id("tp_f3_to_f2")
	var expected: Vector2 = TeleportCatalog.tile_to_pixel(spec["to_spawn"])
	trigger._on_body_entered(player)   # 玩家踩踏（经对话闸门/冷却/层过滤后分派）
	# 淡出 0.2s + 淡入 0.2s：等足够时间让目标图装载与自动存档完成
	await get_tree().create_timer(0.6).timeout
	var world: Node = _fake_main.get_node("World")
	assert_true(world.get_child_count() > 0, "Router 应已装入目标图")
	var target: Node = world.get_child(world.get_child_count() - 1)
	assert_eq(String(target.name), "Ruins_F2", "应装入 ruins_f2 场景")
	var tplayer: Node2D = target.get_node("YSorted/Player")
	assert_eq(tplayer.global_position, expected,
			"f3→f2 返程应落在 f2 北口楼梯走道 to_spawn %s" % expected)
	assert_true(SaveManager.load_save(), "跨图传送应自动存档")
	var spos: Array = SaveManager.last_loaded["position"]
	assert_eq(Vector2(spos[0], spos[1]), expected, "跨图存档坐标 = to_spawn 落位值")


# =============== K. VICTORY 回图存档坐标（缺陷 2 实证 + 回归锚） ===============

## 造假 Main/World 骨架（缺陷 2：让 Router.change_scene 真装载目标图）
## with_fade_mask=true 时附带 UILayer/FadeMask，复刻生产"异步淡出后装载"的时序。
func _make_fake_main(with_fade_mask: bool = false) -> Node:
	var main := Node2D.new()
	main.name = "Main"
	var world := Node2D.new()
	world.name = "World"
	main.add_child(world)
	if with_fade_mask:
		var ui := CanvasLayer.new()
		ui.name = "UILayer"
		var mask := ColorRect.new()
		mask.name = "FadeMask"
		mask.color = Color(0, 0, 0)
		mask.modulate = Color(1, 1, 1, 0)
		ui.add_child(mask)
		main.add_child(ui)
	get_tree().root.add_child(main)
	_fake_main = main
	return main


func test_25_VICTORY回图存档坐标应为回置后的return_position() -> void:
	# 【缺陷 2 实证 / 回归锚】真图（road，含 announce_ready 自动存档）经 Router
	# 装入假 Main。road tscn 里 Player 硬编码 (384,64)；VICTORY 的 return_position
	# 取 (400,640)（显著不同于硬编码位）。断言：自动存档坐标 = return_position
	# （回置后的战前位），而非 tscn 硬编码入口位。修复前本用例红（存档记成
	# (384,64)——回置经 map_ready 后 deferred 执行，晚于 announce_ready 的同步读位）。
	_make_fake_main()
	var handler: Node = HANDLER_SCRIPT.new()
	add_child_autofree(handler)
	var return_pos := Vector2(400, 640)
	assert_ne(return_pos, HARDCODED_PLAYER_PX["road"],
			"前置：return_position 应不同于 road tscn 硬编码位")
	SaveManager.save_requested_pending = false
	_cleanup_test_files()
	handler._on_battle_finished({
		"outcome": "VICTORY",
		"party_state": [],
		"drops": [],
		"return_map": ROAD_MAP_PATH,
		"return_position": return_pos,
		"defeat_enemy_uid": "enemy_m8a1_probe",
	})
	# 假 Main 无 FadeMask → change_scene 同步装载 road → announce_ready 同步落盘
	assert_true(FileAccess.file_exists(TEST_PATH), "VICTORY 回图应触发自动存档")
	assert_true(SaveManager.load_save(), "落盘内容应可读回")
	assert_eq(SaveManager.last_loaded["map"], "road", "存档 map 应为回图图名")
	var pos: Array = SaveManager.last_loaded["position"]
	assert_eq(Vector2(pos[0], pos[1]), return_pos,
			"VICTORY 存档坐标应为回置后的 return_position（非 tscn 硬编码 (384,64)）")
	handler._pending_return = {}
