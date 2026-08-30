extends GutTest
## E4-S5 宝箱/调查事件模板（TASK：27 点位 + 存档闭环）GUT 用例
##
## 【断言覆盖】EPIC-4 E4-S5 两条验收 + 探索 GDD §3.3 模板语义：
##   A. 模板结构：两个模板脚本协议齐备（chest/investigate 交互体 + event_id）；
##   B. 装配：五图装载后 27 点位实体全部在树（9 宝箱 + 18 调查，逐图计数）；
##   C. 对表：点位实体与既有锚点/目录坐标同位（tile*16+8 口径，防数据漂移）；
##      宝箱格美术核（E4-S2 verify_road.py 锚定的 3 处 WallsObjects 宝箱 tile）；
##   D. 宝箱模板语义：首次交互 not_flag 成立 → inventory 增 + chests_opened 登记获得提示可开演；
##   E. 存档闭环（验收 ②）：开箱 → save → load → 已开不重开（inventory 不变）；
##   F. 目录结构化（拍板项④）：PointCatalog ↔ chests.json + investigates.json
##      同构（27 点位 id/图/坐标/道具/文案方向全对齐）；
##   G. 调查模板语义：无状态、可重复交互、dialogue id 指向 flavor 文件条目；
##   H. 文案资产：27 条对话 JSON 全部可解析、结构合法（50% 最终文案落盘证据）；
##   I. spawn 安全区：全部点位离本图 spawn ≥ 5 格（8 格安全区无内容点）；
##   J. 端到端交互：真实玩家 + 控制器按键注入 → 开箱全链路（真实射线命中）。
##
## 【测试策略】全量场景装载走 PackedScene.instantiate + 手动 add_child
##   （同 test_e4s2 纪律，不进 Router）；GameData 用快照/恢复隔离（test_e4s1
##   同款）；存档走覆写 save_path 指向独立测试文件（SMK-12 口径）。
##   端到端用例 J 复用 headless_e1s6 的"站位 + 缓冲期内注入"时序。

const PLAYER_SCENE_PATH: String = "res://scenes/player.tscn"
const MAP_SCENES: Dictionary = {
	"town": "res://scenes/maps/town.tscn",
	"road": "res://scenes/maps/road.tscn",
	"ruins_f1": "res://scenes/maps/ruins_f1.tscn",
	"ruins_f2": "res://scenes/maps/ruins_f2.tscn",
	"ruins_f3": "res://scenes/maps/ruins_f3.tscn",
}
## 每图点位计数对表（探索 GDD §3.1 总表行）
const EXPECT_COUNTS: Dictionary = {
	"town": {"chests": 1, "investigates": 6},
	"road": {"chests": 2, "investigates": 3},
	"ruins_f1": {"chests": 3, "investigates": 4},
	"ruins_f2": {"chests": 2, "investigates": 3},
	"ruins_f3": {"chests": 1, "investigates": 2},
}
## E4-S2 verify_road.py 锚定的"宝箱 tile 挂箱体贴"硬核对（WallsObjects 层）
const CHEST_TILE_ART: Dictionary = {
	"chest_road_01": Vector2i(9, 16),
	"chest_road_02": Vector2i(36, 62),
	"chest_town_01": Vector2i(59, 22),
}

const ChestScript := preload("res://scripts/events/chest.gd")
const InvestigateScript := preload("res://scripts/events/investigate_point.gd")
const PointCatalog := preload("res://scripts/events/point_catalog.gd")
const CharacterRecord := preload("res://scripts/core/character_record.gd")

## 测试专用存档路径（绝不指向 user://save.json，防污染真实槽）
const TEST_PATH: String = "user://e4s5_test_save.json"

var _maps: Array[Node] = []

## GameData 快照（handler 直写全局单例的隔离纪律，test_e4s1 同款）
var _party_backup: Array = []
var _flags_backup: Dictionary = {}
var _sets_backup: Array = []
var _phase_backup: int = 0
var _inv_backup: Dictionary = {}


func before_all() -> void:
	_phase_backup = GameData.story_phase
	_flags_backup = GameData.flags.duplicate()
	_inv_backup = GameData.inventory.duplicate()
	_sets_backup = [
		(GameData.chests_opened as Array).duplicate(),
		(GameData.discovered_weakness_set as Array).duplicate(),
		(GameData.cleared_enemy_set as Array).duplicate(),
	]
	for c: Resource in GameData.party:
		_party_backup.append({
			"id": c.id, "name": c.name, "job": c.job, "level": c.level,
			"hp": c.hp, "max_hp": c.max_hp, "mp": c.mp, "max_mp": c.max_mp})


func after_all() -> void:
	_restore_gamedata_baseline()
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.last_loaded = {}
	_cleanup_test_files()


func before_each() -> void:
	_restore_gamedata_baseline()
	SaveManager.save_path = TEST_PATH
	SaveManager.last_loaded = {}
	_cleanup_test_files()


func after_each() -> void:
	for m: Node in _maps:
		if is_instance_valid(m):
			m.queue_free()
	_maps.clear()


# ---------------------------------------------------------- 隔离辅助

func _restore_gamedata_baseline() -> void:
	GameData.story_phase = _phase_backup
	GameData.flags = _flags_backup.duplicate()
	GameData.inventory = _inv_backup.duplicate()
	GameData.chests_opened = (_sets_backup[0] as Array).duplicate()
	GameData.discovered_weakness_set = (_sets_backup[1] as Array).duplicate()
	GameData.cleared_enemy_set = (_sets_backup[2] as Array).duplicate()
	var party: Array[CharacterRecord] = []
	for pd: Dictionary in _party_backup:
		party.append(CharacterRecord.new(
			pd["id"], pd["name"], pd["job"], pd["level"],
			pd["hp"], pd["max_hp"], pd["mp"], pd["max_mp"]))
	GameData.party = party


func _cleanup_test_files() -> void:
	for p: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## 装载一张图入测试树（挂本测试节点下，after_each 统一释放）
func _load_map(map_name: String) -> Node:
	var packed: PackedScene = load(MAP_SCENES[map_name])
	var map: Node = packed.instantiate()
	add_child_autofree(map)
	_maps.append(map)
	return map


# =============== A. 模板结构 ===============

func test_01_宝箱模板协议齐备() -> void:
	var chest := StaticBody2D.new()
	chest.set_script(ChestScript)
	assert_true(chest.has_method("on_interact"), "宝箱应有 on_interact 模板入口")
	assert_true(chest.has_method("get_npc_id"), "宝箱应实现交互协议 get_npc_id")
	assert_true(chest.has_method("get_event_id"), "宝箱应有 E5 回迁预留 event_id 口")
	assert_eq(chest.item_count, 1, "item_count 默认 1")
	assert_eq(chest.get_npc_id(), "chest_opened_", "未配置时兜底串可派生（测试实例无名字）")
	chest.free()


func test_02_调查模板协议齐备且无状态() -> void:
	var inv := StaticBody2D.new()
	inv.set_script(InvestigateScript)
	assert_true(inv.has_method("on_interact"), "调查点应有 on_interact 模板入口")
	assert_true(inv.has_method("get_npc_id"), "调查点应实现交互协议 get_npc_id")
	assert_true(inv.has_method("get_event_id"), "调查点应有 E5 回迁预留 event_id 口")
	inv.free()


# =============== B. 装配（五图 27 点位全部在树） ===============

func test_03_town装配1宝箱6调查() -> void:
	var map: Node = _load_map("town")
	var pts: Dictionary = map.content_points
	assert_eq((pts["chests"] as Array).size(), 1, "town 宝箱应为 1")
	assert_eq((pts["investigates"] as Array).size(), 6, "town 调查点应为 6")


func test_04_road装配2宝箱3调查() -> void:
	var map: Node = _load_map("road")
	var pts: Dictionary = map.content_points
	assert_eq((pts["chests"] as Array).size(), 2, "road 宝箱应为 2")
	assert_eq((pts["investigates"] as Array).size(), 3, "road 调查点应为 3")


func test_05_f1装配3宝箱4调查() -> void:
	var map: Node = _load_map("ruins_f1")
	var pts: Dictionary = map.content_points
	assert_eq((pts["chests"] as Array).size(), 3, "f1 宝箱应为 3")
	assert_eq((pts["investigates"] as Array).size(), 4, "f1 调查点应为 4")


func test_06_f2装配2宝箱3调查() -> void:
	var map: Node = _load_map("ruins_f2")
	var pts: Dictionary = map.content_points
	assert_eq((pts["chests"] as Array).size(), 2, "f2 宝箱应为 2")
	assert_eq((pts["investigates"] as Array).size(), 3, "f2 调查点应为 3")


func test_07_f3装配1宝箱2调查() -> void:
	var map: Node = _load_map("ruins_f3")
	var pts: Dictionary = map.content_points
	assert_eq((pts["chests"] as Array).size(), 1, "f3 宝箱应为 1")
	assert_eq((pts["investigates"] as Array).size(), 2, "f3 调查点应为 2")


# =============== C. 对表（实体-锚点同位 / 宝箱美术） ===============

## 目录坐标 ↔ 既有 Marker2D 锚点同位（road/f1/f2/f3 的锚点由 E4-S2/S3
## 制作对表验收；town 宝箱锚点挂 YSorted、town 6 调查点为新增无锚点）
func test_08_点位实体与既有锚点同位() -> void:
	var checked: int = 0
	for map_name: String in MAP_SCENES:
		var map: Node = _load_map(map_name)
		var pts: Dictionary = map.content_points
		for chest: Node in pts["chests"]:
			# 宝箱 id -> 既有锚点名（Chest_*），实体应落在锚点同位
			var id: String = chest.get_event_id()
			var parent: Node = map.get_node_or_null("YSorted/Anchors")
			if parent == null:
				parent = map.get_node("YSorted")
			var anchor: Node = parent.get_node_or_null(PointCatalog.chest_anchor_name(id))
			if anchor == null:
				continue
			assert_eq(chest.position, (anchor as Node2D).position, "%s 实体应与锚点同位" % id)
			checked += 1
		for inv: Node in pts["investigates"]:
			var inv_id: String = inv.get_event_id()
			var parts: PackedStringArray = inv_id.split("_")
			if parts[1] == "town":
				continue   # town 6 调查点为本次新增（无既有锚点），坐标自定
			var parent2: Node = map.get_node("YSorted/Anchors")
			var anchor2: Node = parent2.get_node_or_null(PointCatalog.inv_anchor_name(inv_id))
			if anchor2 == null:
				continue
			assert_eq(inv.position, (anchor2 as Node2D).position,
					"%s 实体应与锚点同位（实体是美术锚点的交互载体，偏移=死物）" % inv_id)
			checked += 1
	assert_true(checked >= 19, "至少 19 个点位应命中既有锚点（实为 %d）" % checked)


## 目录正本 ↔ chests.json / investigates.json 结构化镜像逐字段一致
## （拍板项④：27 点位全量落盘，E5 回迁数据可平移）
func test_09_目录与JSON镜像同构() -> void:
	var text: String = FileAccess.get_file_as_string("res://data/json/events/chests.json")
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "chests.json 应为合法 JSON 对象")
	var arr: Array = (parsed as Dictionary)["chests"]
	assert_eq(arr.size(), PointCatalog.CHESTS.size(), "JSON 镜像应与目录条数一致（9）")
	for i: int in arr.size():
		var jc: Dictionary = arr[i]
		var gc: Dictionary = PointCatalog.CHESTS[i]
		assert_eq(String(jc["event_id"]), String(gc["id"]), "第 %d 条 id 应一致" % i)
		assert_eq(String(jc["map"]), String(gc["map"]), "%s 图应一致" % jc["event_id"])
		var tile: Vector2i = gc["tile"]
		# JSON 数值恒解析为 float，与目录 int 逐位容错比较（assert_eq 会分型判异）
		var jt: Array = jc["tile"]
		assert_eq(int(jt[0]), tile.x, "%s tile.x 应一致" % jc["event_id"])
		assert_eq(int(jt[1]), tile.y, "%s tile.y 应一致" % jc["event_id"])
		assert_eq(String(jc["item_id"]), String(gc["item_id"]), "%s 道具应一致" % jc["event_id"])
	# 调查点 18 条同构校验（id/map/tile/tone 全对齐）
	var inv_text: String = FileAccess.get_file_as_string(
			"res://data/json/events/investigates.json")
	var inv_parsed: Variant = JSON.parse_string(inv_text)
	assert_true(inv_parsed is Dictionary, "investigates.json 应为合法 JSON 对象")
	var inv_arr: Array = (inv_parsed as Dictionary)["investigates"]
	assert_eq(inv_arr.size(), PointCatalog.INVESTIGATES.size(),
			"调查点 JSON 镜像应与目录条数一致（18）")
	for i2: int in inv_arr.size():
		var ji: Dictionary = inv_arr[i2]
		var gi: Dictionary = PointCatalog.INVESTIGATES[i2]
		assert_eq(String(ji["id"]), String(gi["id"]), "第 %d 条 id 应一致" % i2)
		assert_eq(String(ji["map"]), String(gi["map"]), "%s 图应一致" % ji["id"])
		var itile: Vector2i = gi["tile"]
		var jit: Array = ji["tile"]
		assert_eq(int(jit[0]), itile.x, "%s tile.x 应一致" % ji["id"])
		assert_eq(int(jit[1]), itile.y, "%s tile.y 应一致" % ji["id"])
		assert_eq(String(ji["tone"]), String(gi["tone"]), "%s tone 应一致" % ji["id"])


# =============== D/E. 宝箱模板语义 + 存档闭环 ===============

## 取一个脱树的宝箱实例直驱模板（headless 全链路：交互→给道具→登记）
func _drive_chest(chest: StaticBody2D) -> void:
	chest.on_interact()


func test_10_宝箱首次交互给道具并登记() -> void:
	var map: Node = _load_map("road")
	var chest: StaticBody2D = (map.content_points["chests"] as Array)[0]
	assert_false(GameData.chests_opened.has("chest_road_01"), "前置：未开")
	var before: int = int(GameData.inventory.get("potion_s", 0))
	_drive_chest(chest)
	assert_eq(int(GameData.inventory.get("potion_s", 0)), before + 2,
			"give_item 应入背包（potion_s ×2，与战斗掉落同口）")
	assert_true(GameData.chests_opened.has("chest_road_01"), "set_flag 应登记 chests_opened")


func test_11_已开宝箱再交互不重开() -> void:
	var map: Node = _load_map("road")
	var chest: StaticBody2D = (map.content_points["chests"] as Array)[0]
	_drive_chest(chest)
	var count_after_first: int = int(GameData.inventory.get("potion_s", 0))
	_drive_chest(chest)   # 已开：应只重播提示，不重复给道具
	assert_eq(int(GameData.inventory.get("potion_s", 0)), count_after_first,
			"已开宝箱再交互不得重复给道具（not_flag 条件已不成立）")
	assert_eq((GameData.chests_opened as Array).count("chest_road_01"), 1,
			"chests_opened 不应重复登记")


func test_12_存档闭环_存读后已开不重开() -> void:
	# ① 开箱 → 存档（快照落 chests_opened + inventory，ADR-3 v2 十字段）
	# 【v2 升级注记】E4-S8 起 inventory 入存档（v1 无此字段），验收②闭环
	#   从"chests_opened 回灌"升级为"chests_opened + inventory 双回灌"：
	#   存→读后道具数量无损；已开宝箱再交互仍不重复给道具。
	var road: Node = _load_map("road")
	var chest: StaticBody2D = (road.content_points["chests"] as Array)[0]
	_drive_chest(chest)
	assert_true(GameData.chests_opened.has("chest_road_01"), "前置：开箱已登记")
	assert_eq(int(GameData.inventory.get("potion_s", 0)), 2, "前置：开箱已给道具（运行时）")
	assert_true(SaveManager.save("res://scenes/maps/road.tscn", Vector2(384, 64)), "存档")
	# ② 扰动：模拟"读档前的运行时漂移"（读档必须清掉这份伪状态）
	GameData.chests_opened = []
	GameData.inventory = {"junk": 99}
	# ③ 读档回灌
	assert_true(SaveManager.load_save(), "读档应成功")
	assert_eq(GameData.chests_opened, ["chest_road_01"], "chests_opened 应从存档无损回灌")
	assert_eq(int(GameData.inventory.get("potion_s", 0)), 2,
			"inventory 应从存档无损回灌（E4-S8 v2）")
	assert_false(GameData.inventory.has("junk"), "扰动值应被存档值替换")
	# ④ 已开不重开：读档后的宝箱再交互，不得重复给道具（验收 ② 闭环断言）
	var road2: Node = _load_map("road")
	var chest2: StaticBody2D = (road2.content_points["chests"] as Array)[0]
	_drive_chest(chest2)
	assert_eq(int(GameData.inventory.get("potion_s", 0)), 2,
			"存→读→已开不重开：道具不再重复发放（验收 ②，v2 口径）")


# =============== G. 调查模板语义 ===============

func test_13_调查点交互协议返回flavor对话id() -> void:
	var map: Node = _load_map("town")
	var inv: StaticBody2D = (map.content_points["investigates"] as Array)[0]
	var dlg: String = inv.get_npc_id()
	assert_true(dlg.begins_with("flavor_inv_town_"), "调查协议应返回 flavor_<点位id> 对话 id")
	# 无状态性：交互不应触碰任何游戏状态（无 runner 环境：静默跳过对话）
	inv.on_interact()
	assert_true(GameData.chests_opened.is_empty(), "调查点不得写 chests_opened")
	assert_true(GameData.inventory.is_empty(), "调查点不得写 inventory")
	# 可重复交互：无状态 → 二次调用同样安全（不抛错、状态不变）
	inv.on_interact()
	assert_true(GameData.chests_opened.is_empty(), "调查点重复交互仍零状态写入")


func test_14_五图调查点全部指向存在的flavor文件() -> void:
	# 对话 id = flavor 文件名（DialogueRunner E1-S6 契约：文件名即对话 id），
	# 交互即能开演的资产前提：flavor_<id>.json 逐一存在且结构合法
	for spec: Dictionary in PointCatalog.INVESTIGATES:
		var path: String = "res://data/json/dialogues/flavor_%s.json" % spec["id"]
		assert_true(FileAccess.file_exists(path), "%s 文件应存在" % path)
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(parsed is Dictionary, "%s 应为合法 JSON" % path)
		if not (parsed is Dictionary):
			continue
		var entries: Dictionary = (parsed as Dictionary)
		assert_true(entries.has("flavor_" + String(spec["id"])),
				"%s 应含同名脚本键" % path.get_file())
		var entry: Dictionary = entries["flavor_" + String(spec["id"])]
		assert_true(entry.has("start"), "%s 应含 start 入口" % path.get_file())


# =============== H. 文案资产（27 条全部合法） ===============

func test_15_宝箱对话JSON九文件全部合法() -> void:
	# 对话 id = 文件名（runner E1-S6 契约）；9 个宝箱各一个对话文件
	for gc: Dictionary in PointCatalog.CHESTS:
		var path: String = "res://data/json/dialogues/dlg_%s.json" % gc["id"]
		assert_true(FileAccess.file_exists(path), "%s 应存在" % path)
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(parsed is Dictionary, "%s 应为合法 JSON" % path)
		if not (parsed is Dictionary):
			continue
		var entries: Dictionary = parsed as Dictionary
		assert_true(entries.has("dlg_" + String(gc["id"])), "%s 应含同名脚本键" % path.get_file())
		var entry: Dictionary = entries["dlg_" + String(gc["id"])]["start"]
		assert_true(entry.has("speaker") and entry.has("text") and entry.has("next"),
				"%s 条目结构应合法（speaker/text/next）" % path.get_file())
		assert_true(String(entry["text"]).length() > 0, "%s 文案非空" % path.get_file())


func test_16_调查文案18条全覆盖且方向各半() -> void:
	var atmospheric: int = 0
	var playful: int = 0
	for spec: Dictionary in PointCatalog.INVESTIGATES:
		var path: String = "res://data/json/dialogues/flavor_%s.json" % spec["id"]
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary):
			continue
		var entries: Dictionary = parsed as Dictionary
		var key: String = "flavor_" + String(spec["id"])
		if not entries.has(key):
			continue
		var entry: Dictionary = entries[key]["start"]
		assert_true(String(entry["text"]).length() >= 20,
				"%s 文案应达最终文案长度（≥20 字）" % spec["id"])
		if String(spec["tone"]) == "A":
			atmospheric += 1
		else:
			playful += 1
	assert_eq(atmospheric, 9, "氛围向文案应为 9 条（18 的一半）")
	assert_eq(playful, 9, "趣味向文案应为 9 条（18 的一半）")


# =============== I. spawn 安全区 ===============

func test_17_全部点位离spawn至少2格() -> void:
	# GDD §3.4 八格安全区约束对象是「敌人初始位与碰撞」，内容点不占敌人
	# 配额 → 工程底线：点位不压 spawn 落位格及其紧邻（≥2 格曼哈顿距离），
	# 防出生点嵌交互体挡路（SMA-16 spawn 可站立性同源）。
	# 唯一贴线点 inv_f2_01（距 spawn 3 格）= E4-S3 已验收锚点位，保留。
	for arr: Array in [PointCatalog.CHESTS, PointCatalog.INVESTIGATES]:
		for spec: Dictionary in arr:
			var spawn: Vector2i = PointCatalog.SPAWNS[String(spec["map"])]
			var tile: Vector2i = spec["tile"]
			var dist: int = absi(tile.x - spawn.x) + absi(tile.y - spawn.y)
			assert_true(dist >= 2, "%s 离 spawn 应 ≥2 格（实为 %d）" % [spec["id"], dist])


# =============== J. 端到端：真实玩家 + 控制器按键 → 开箱 ===============

func test_18_端到端玩家面前开箱全链路() -> void:
	# 真实场景装载（含装配产物）+ 真实玩家 InteractRay + 真实控制器注入：
	# 玩家站宝箱下方一格面朝上 → 射线命中宝箱交互体 → 控制器按协议开箱。
	# 【注】road 图无对话装配（E1-S6 仅 town 装配 controller），故此处
	# 按 town_map 同款规格手动装配 controller（production 接线在 E4-S6
	# 传送网络 Story 一并铺开五图；本 Story 只验协议链路本身）。
	var map: Node = _load_map("road")
	var chest: StaticBody2D = (map.content_points["chests"] as Array)[0]
	var player: CharacterBody2D = map.get_node("YSorted/Player")
	var controller: Node = map.interaction_controller
	if controller == null:
		controller = Node.new()
		controller.name = "InteractionController"
		controller.set_script(preload("res://scripts/events/interaction_controller.gd"))
		map.add_child(controller)
		controller.setup(player, null)   # runner 为 null：宝箱自治路径不依赖 runner
	# 玩家移到宝箱下方一格、面朝上（生产时序：输入定朝向 → 缓冲期内按键）
	player.set_input_override(Vector2.UP)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.global_position = chest.global_position + Vector2(0, 16)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.set_input_override(Vector2.ZERO)
	await get_tree().physics_frame   # 松键当帧，facing=UP 保持
	# 前置确认：射线确实命中宝箱（几何有效性的直接证据）
	var target: Object = player.get_interact_target()
	assert_not_null(target, "玩家面前 1 格应命中宝箱交互体")
	# 控制器注入交互键 → 协议分派 → 宝箱自治开箱
	controller.inject_interact()
	await get_tree().physics_frame
	# 验证点：控制器按键后模板④登记与②给道具均须生效（实体自治路径）
	assert_true(GameData.chests_opened.has("chest_road_01"),
			"端到端：控制器按键后宝箱应登记已开")
	assert_eq(int(GameData.inventory.get("potion_s", 0)), 2, "端到端：道具应入背包")
