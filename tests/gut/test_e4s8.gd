extends GutTest
## E4-S8 inventory 入存档 schema（version bump 1→2 + 迁移）GUT 用例
##
## 【断言覆盖】任务卡验收标准 + ADR-3 版本化承诺（E4-S1 规程延续）：
##   1. 存→读→inventory 无损往返（多道具多数量、扰动后回灌、二存二读稳定）；
##   2. v1 旧档（手工构造无 inventory 键的 JSON）读档不报错、inventory 为空、
##      不污染其余字段（迁移分支行为验证）；
##   3. v2 落盘结构：快照键集 ≡ SCHEMA、version=2、inventory 以 JSON 对象落盘；
##   4. 回灌类型安全：JSON float → int 逐键转换（count 恒为 int）；
##   5. E4-S5 端到端衔接：开箱→存→读→道具数量无损（真模板驱动）。
##
## 【测试策略】save_path 覆写指向独立 user:// 文件（SMK-12 口径，不碰真实槽）；
##   GameData 快照/恢复隔离（test_e4s1/e4s5 同款纪律）；v1 旧档用
##   _write_raw 直接写 JSON 文本构造（test_e4s1 test_10/13 同款手法）。

const CharacterRecord := preload("res://scripts/core/character_record.gd")
const ChestScript := preload("res://scripts/events/chest.gd")

## 测试专用存档路径（绝不指向 user://save.json，防污染真实槽）
const TEST_PATH: String = "user://e4s8_test_save.json"

## E1-S2 初始队伍数值（GameData 字段声明默认值锚，test_e4s1 同款）
const DEFAULT_PARTY: Array = [
	{"id": "kyle", "name": "凯尔", "job": "swordsman", "level": 1, "hp": 120, "max_hp": 120, "mp": 10, "max_mp": 10},
	{"id": "lina", "name": "莉娜", "job": "sorcerer", "level": 1, "hp": 80, "max_hp": 80, "mp": 30, "max_mp": 30},
	{"id": "mona", "name": "莫娜", "job": "support", "level": 1, "hp": 95, "max_hp": 95, "mp": 24, "max_mp": 24},
]

## GameData 快照（handler 直写全局单例的隔离纪律）
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
	pass   # 无场景装载，文件清理在 before_each/after_all 兜底


# ---------------------------------------------------------- 隔离辅助

func _restore_gamedata_baseline() -> void:
	GameData.story_phase = _phase_backup
	GameData.flags = _flags_backup.duplicate()
	GameData.inventory = _inv_backup.duplicate()
	GameData.chests_opened = (_sets_backup[0] as Array).duplicate()
	GameData.discovered_weakness_set = (_sets_backup[1] as Array).duplicate()
	GameData.cleared_enemy_set = (_sets_backup[2] as Array).duplicate()
	var party: Array[CharacterRecord] = []
	for pd: Dictionary in DEFAULT_PARTY:
		party.append(CharacterRecord.new(
			pd["id"], pd["name"], pd["job"], pd["level"],
			pd["hp"], pd["max_hp"], pd["mp"], pd["max_mp"]))
	GameData.party = party


func _cleanup_test_files() -> void:
	for p: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## 直接向测试路径写任意文本（构造 v1 旧档用）
func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f = null


## 读取测试路径的 JSON（断言落盘内容用）
func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "落盘内容应为合法 JSON 对象")
	return parsed if parsed is Dictionary else {}


# =============== 1. 往返无损（验收①） ===============

func test_01_存读往返_背包多道具多数量无损() -> void:
	# 写入态：三道具三数量（E4-S5 掉落口径的真实道具 id）
	GameData.inventory = {"potion_s": 5, "ether_s": 3, "antidote": 2}
	assert_true(SaveManager.save("res://scenes/maps/town.tscn", Vector2(192, 640)), "存档")
	# 扰动：模拟读档前的运行时漂移（用掉道具/捡到垃圾）
	GameData.inventory = {"potion_s": 0, "mystery_key": 1}
	# 读档回灌
	assert_true(SaveManager.load_save(), "读档应成功")
	assert_eq(GameData.inventory, {"potion_s": 5, "ether_s": 3, "antidote": 2},
			"背包三道具三数量应无损往返（验收①）")
	assert_false(GameData.inventory.has("mystery_key"), "扰动值不得残留")


func test_02_回灌count恒为int非float() -> void:
	# JSON 解析的数字恒为 float：回灌必须逐键 int 化，否则后续累加/对账分型出错
	GameData.inventory = {"potion_s": 7}
	assert_true(SaveManager.save("m", Vector2.ZERO), "存档")
	assert_true(SaveManager.load_save(), "读档")
	assert_true(GameData.inventory["potion_s"] is int, "count 回灌后应为 int（JSON float 已转换）")
	assert_eq(GameData.inventory["potion_s"], 7, "count 数值无损")


func test_03_空背包往返与二存二读稳定() -> void:
	# 空背包 → 存读 → 仍空；再存再读不漂移
	GameData.inventory = {}
	assert_true(SaveManager.save("m1", Vector2(1, 2)), "第一次存档")
	assert_true(SaveManager.load_save(), "第一次读档")
	assert_true(GameData.inventory.is_empty(), "空背包往返后仍为空")
	# 二存二读（test_e4s1 test_06 口径）
	GameData.inventory = {"ether_s": 2}
	GameData.chests_opened = ["chest_road_01"]
	assert_true(SaveManager.save("m2", Vector2(3, 4)), "第二次存档")
	GameData.inventory = {"zzz": 9}
	GameData.chests_opened = ["x"]
	assert_true(SaveManager.load_save(), "第二次读档")
	assert_eq(GameData.inventory, {"ether_s": 2}, "二存二读后背包无损")
	assert_eq(GameData.chests_opened, ["chest_road_01"], "二存二读后集合无损")
	assert_eq(String(SaveManager.last_loaded["map"]), "m2", "last_loaded 指向最新一次读档")


# =============== 2. v1 旧档迁移（验收②） ===============

func test_04_v1旧档读档不报错且inventory补空() -> void:
	# 手工构造 v1 真实形态旧档：九字段齐、无 inventory 键、version=1
	_write_raw(TEST_PATH, JSON.stringify({
		"version": 1,
		"map": "res://scenes/maps/road.tscn",
		"position": [384.0, 64.0],
		"party": [{"id": "kyle", "name": "凯尔", "job": "swordsman",
				"level": 2, "hp": 100, "max_hp": 120, "mp": 8, "max_mp": 10}],
		"story_phase": 3,
		"flags": ["met_elder"],
		"chests_opened": ["chest_town_01"],
		"discovered_weakness_set": ["moth:fire"],
		"cleared_enemy_set": ["b1_moth_0"],
	}))
	GameData.inventory = {"drift": 1}   # 扰动：读档应清掉运行时漂移
	assert_true(SaveManager.load_save(), "v1 旧档应经迁移后可读（不报错）")
	assert_true(GameData.inventory.is_empty(), "v1 旧档 inventory 应补空 Dictionary")
	# 迁移不污染其余字段：v1 数据原样回灌
	assert_eq(GameData.story_phase, 3, "v1 story_phase 原样回灌")
	assert_eq(GameData.chests_opened, ["chest_town_01"], "v1 chests_opened 原样回灌")
	assert_eq(GameData.discovered_weakness_set, ["moth:fire"], "v1 弱点集原样回灌")
	assert_eq(GameData.cleared_enemy_set, ["b1_moth_0"], "v1 击破集原样回灌")
	assert_eq(GameData.party[0].hp, 100, "v1 队伍数值原样回灌")
	assert_true(GameData.flags.has("met_elder"), "v1 flags 原样回灌")
	# 迁移后 last_loaded 的 version 应上迁为当前版本
	assert_eq(int(SaveManager.last_loaded["version"]), SaveManager.SCHEMA_VERSION,
			"迁移后快照 version 应为当前格式版本")


func test_05_v1旧档再存档升级为v2带inventory() -> void:
	# 旧档读入 → 再存档：落盘即 v2（含 inventory 键），玩家无感升级
	_write_raw(TEST_PATH, JSON.stringify({
		"version": 1, "map": "m", "position": [0.0, 0.0], "party": [],
		"story_phase": 1, "flags": [], "chests_opened": [],
		"discovered_weakness_set": [], "cleared_enemy_set": [],
	}))
	assert_true(SaveManager.load_save(), "v1 旧档可读")
	GameData.inventory = {"potion_m": 1}   # 旧档玩家开新档后拿到道具
	assert_true(SaveManager.save("m2", Vector2(5, 6)), "再存档")
	var data := _read_json(TEST_PATH)
	# T3.3 起 schema bump 2→3（equipment 入档）：再存档落盘 = 当前版本
	assert_eq(int(data["version"]), 3, "再存档落盘应为 v3（当前版本）")
	assert_true(data.has("inventory"), "落盘应含 inventory 键（v2 起冻结）")
	# JSON 解析数值恒为 float，逐键 int 化比较（test_09 同款教训：整字典直比会分型判异）
	var disk_inv: Dictionary = data["inventory"]
	assert_eq(int(disk_inv.get("potion_m", 0)), 1, "inventory 内容落盘无损")


func test_06_v1旧档部分字段缺失仍可读() -> void:
	# 手改档容错（test_e4s1 test_10 口径延续）：缺 inventory 缺 chests_opened 等
	_write_raw(TEST_PATH, JSON.stringify({
		"version": 1, "map": "m", "story_phase": 5,
		"position": [1.0, 2.0], "party": [],
	}))
	assert_true(SaveManager.load_save(), "缺字段的 v1 档应可读")
	assert_eq(GameData.story_phase, 5, "已有字段正常回灌")
	assert_true(GameData.inventory.is_empty(), "缺失 inventory 补默认空")
	assert_true(GameData.chests_opened.is_empty(), "缺失 chests_opened 补默认空")


# =============== 3. v2 落盘结构 ===============

func test_07_v2快照键集等于SCHEMA且inventory为JSON对象() -> void:
	GameData.inventory = {"potion_s": 2, "ether_s": 1}
	assert_true(SaveManager.save("m", Vector2.ZERO), "存档")
	var data := _read_json(TEST_PATH)
	var snap_keys: Array = data.keys()
	var schema_keys: Array = SaveManager.SCHEMA.keys()
	snap_keys.sort()
	schema_keys.sort()
	assert_eq(snap_keys, schema_keys, "快照键集必须 ≡ SCHEMA 键集（11 字段，不多不少）")
	# T3.3 起 schema bump 2→3（equipment 入档），版本锚随之更新
	assert_eq(int(data["version"]), 3, "落盘 version 应为 3（当前版本）")
	assert_true(data["inventory"] is Dictionary, "inventory 应以 JSON 对象（键值对）落盘")
	assert_eq(int(data["inventory"]["potion_s"]), 2, "inventory 数值落盘无损")


# =============== 4. E4-S5 端到端衔接（真模板驱动） ===============

func test_08_开箱存读道具数量无损() -> void:
	# chest 模板 on_interact → 存 → 读：验收①的产品级走法（非直写 GameData）
	var chest := StaticBody2D.new()
	chest.name = "chest_town_01"
	chest.set_script(ChestScript)
	add_child_autofree(chest)
	chest.chest_id = "chest_town_01"
	chest.item_id = "potion_m"
	chest.item_count = 1
	chest.on_interact()
	assert_eq(int(GameData.inventory.get("potion_m", 0)), 1, "前置：开箱入包")
	assert_true(SaveManager.save("m", Vector2.ZERO), "存档")
	GameData.inventory = {}   # 扰动
	assert_true(SaveManager.load_save(), "读档")
	assert_eq(int(GameData.inventory.get("potion_m", 0)), 1,
			"开箱所得道具经存读档无损（E4-S5 遗留缺口闭环）")
	assert_true(GameData.chests_opened.has("chest_town_01"),
			"已开登记随档回灌：再交互不会重复给道具")
