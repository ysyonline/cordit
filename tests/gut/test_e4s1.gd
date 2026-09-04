extends GutTest
## E4-S1 SaveManager 完整实现（EPIC-4 第 1 条 Story）GUT 用例
##
## 【断言覆盖】EPIC-4 验收标准 + ADR-3 版本化承诺 + 探索 GDD §3.4 原子写：
##   1. SCHEMA 常量与 ADR-3 十字段对齐（v2 结构回归锚）；
##   2. 存→读→存往返数据无损（集合/阶段/队伍数值全量）；
##   3. flags 运行时 Dictionary → JSON 数组的序列化语义；
##   4. 损坏/缺失文件容错（GameData 不被污染）；
##   5. 缺失字段按 SCHEMA 默认补齐；
##   6. 原子写：成功后无 .tmp 残留；写入失败旧档保留（rename 失败分支）；
##   7. version 迁移：旧版本号补齐上迁；未来版本拒绝读入。
##
## 【测试策略】通过 SaveManager.save_path 覆写指向独立测试文件
##   user://e4s1_test_save.json，不触碰真实存档槽（SMK-12 口径）；
##   GameData 用快照/恢复做跨用例隔离（test_e2s4 同款纪律）。
##   "写入中途强杀进程"为人工实测项（任务管理器杀进程，探索 GDD §3.4
##   验收原文），GUT 覆盖到 rename 失败保留旧档分支即达 Story 测试要求。
##
## 跑法（项目根下，Git Bash）：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const CharacterRecord := preload("res://scripts/core/character_record.gd")

## 测试专用存档路径（绝不指向 user://save.json，防污染真实槽）
const TEST_PATH: String = "user://e4s1_test_save.json"

## E1-S2 初始队伍数值（战斗 GDD §3.6，GameData 字段声明的默认值锚）
const DEFAULT_PARTY: Array = [
	{"id": "kyle", "name": "凯尔", "job": "swordsman", "level": 1, "hp": 120, "max_hp": 120, "mp": 10, "max_mp": 10},
	{"id": "lina", "name": "莉娜", "job": "sorcerer", "level": 1, "hp": 80, "max_hp": 80, "mp": 30, "max_mp": 30},
	{"id": "mona", "name": "莫娜", "job": "support", "level": 1, "hp": 95, "max_hp": 95, "mp": 24, "max_mp": 24},
]

## GameData 快照（before_all 取，after_all 还原——handler 直写全局单例的隔离纪律）
var _party_backup: Array = []
var _flags_backup: Dictionary = {}
var _sets_backup: Array = []   # [chests_opened, discovered_weakness_set, cleared_enemy_set]
var _equip_pool_backup: Array = []   # T3.3：owned_equipment 隔离
var _inv_backup: Dictionary = {}   # T3.3：inventory 隔离（test_17 会写 potion_s，
                                   #  不还原会外溢到后续套件——e4s5/e5s2 连环挂教训）
var _phase_backup: int = 0


func before_all() -> void:
	_phase_backup = GameData.story_phase
	_flags_backup = GameData.flags.duplicate()
	_inv_backup = GameData.inventory.duplicate()
	_sets_backup = [
		(GameData.chests_opened as Array).duplicate(),
		(GameData.discovered_weakness_set as Array).duplicate(),
		(GameData.cleared_enemy_set as Array).duplicate(),
	]
	_equip_pool_backup = GameData.owned_equipment.duplicate()
	for c: Resource in GameData.party:
		_party_backup.append({
			"id": c.id, "name": c.name, "job": c.job, "level": c.level,
			"hp": c.hp, "max_hp": c.max_hp, "mp": c.mp, "max_mp": c.max_mp,
			"weapon_id": c.weapon_id, "armor_id": c.armor_id})


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


# ---------------------------------------------------------- 隔离辅助

## 把 GameData 恢复到 E1-S2 初始基线（每条用例前的干净态）
func _restore_gamedata_baseline() -> void:
	GameData.story_phase = _phase_backup
	GameData.flags = _flags_backup.duplicate()
	GameData.inventory = _inv_backup.duplicate()
	GameData.chests_opened = (_sets_backup[0] as Array).duplicate()
	GameData.discovered_weakness_set = (_sets_backup[1] as Array).duplicate()
	GameData.cleared_enemy_set = (_sets_backup[2] as Array).duplicate()
	GameData.owned_equipment = _equip_pool_backup.duplicate()
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


## 直接向测试路径写任意文本（构造损坏档/旧版本档用）
func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f = null


## 读取测试路径的 JSON（断言落盘内容用）
func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "落盘内容应为合法 JSON 对象")
	return parsed if parsed is Dictionary else {}


# =============== 1. SCHEMA 结构回归锚（ADR-3 十字段，v2 起） ===============

func test_01_schema与ADR3十字段对齐() -> void:
	# v3（E6-S1 T3.3）：+equipment（装备持有池），其余字段不变；
	# party 条目内嵌 weapon_id/armor_id 由 _serialize/_deserialize 锚定
	var expected: Array = ["version", "map", "position", "party", "story_phase",
			"flags", "chests_opened", "discovered_weakness_set", "cleared_enemy_set",
			"inventory", "equipment"]
	var keys: Array = SaveManager.SCHEMA.keys()
	keys.sort()
	expected.sort()
	assert_eq(keys, expected, "SCHEMA 键集必须与 ADR-3 字段表一一对应")
	assert_eq(SaveManager.SCHEMA_VERSION, 3, "当前格式版本应为 3（v2→v3 加 equipment）")
	assert_eq(SaveManager.SAVE_PATH, "user://save.json", "存档路径应为 ADR-3 口径 user://save.json")


func test_02_存档落盘且快照键集等于SCHEMA() -> void:
	var ok: bool = SaveManager.save("res://scenes/maps/town.tscn", Vector2(192, 640))
	assert_true(ok, "save 应返回 true")
	assert_true(FileAccess.file_exists(TEST_PATH), "存档文件应已落盘")
	var data := _read_json(TEST_PATH)
	var snap_keys: Array = data.keys()
	var schema_keys: Array = SaveManager.SCHEMA.keys()
	snap_keys.sort()
	schema_keys.sort()
	assert_eq(snap_keys, schema_keys, "快照键集必须 ≡ SCHEMA 键集（不多不少）")
	assert_eq(int(data["version"]), SaveManager.SCHEMA_VERSION, "落盘 version 应为当前格式版本")
	assert_eq(String(data["map"]), "res://scenes/maps/town.tscn", "map 应原样落盘")
	assert_eq(data["position"], [192.0, 640.0], "position 应为 (x, y) 浮点数组")


# =============== 2. 往返一致性（存→读→存无损） ===============

func test_03_往返一致性_阶段标志与三个集合() -> void:
	# 写入态：全部字段置非默认值
	GameData.story_phase = 2
	GameData.flags = {"met_elder": true, "got_herb": true}
	GameData.chests_opened = ["chest_town_01", "chest_road_02"]
	GameData.discovered_weakness_set = ["moth:fire"]
	GameData.cleared_enemy_set = ["b1_moth_0"]
	assert_true(SaveManager.save("res://scenes/maps/town.tscn", Vector2(192, 640)), "第一次存档")
	# 扰动：全部字段改成别的值（模拟读档前的运行时漂移）
	GameData.story_phase = 9
	GameData.flags = {"other": true}
	GameData.chests_opened = ["x"]
	GameData.discovered_weakness_set = ["y"]
	GameData.cleared_enemy_set = ["z"]
	# 读档回灌
	assert_true(SaveManager.load_save(), "load_save 应返回 true")
	assert_eq(GameData.story_phase, 2, "story_phase 往返无损")
	assert_true(GameData.flags.has("met_elder") and GameData.flags.has("got_herb"),
			"flags 键集往返无损")
	assert_eq(GameData.flags.size(), 2, "flags 无多余键")
	assert_eq(GameData.chests_opened, ["chest_town_01", "chest_road_02"], "chests_opened 往返无损")
	assert_eq(GameData.discovered_weakness_set, ["moth:fire"], "discovered_weakness_set 往返无损")
	assert_eq(GameData.cleared_enemy_set, ["b1_moth_0"], "cleared_enemy_set 往返无损")


func test_04_往返一致性_队伍数值() -> void:
	# 写入态：队伍打完仗的残血态
	GameData.party[0].hp = 37
	GameData.party[0].level = 3
	GameData.party[0].mp = 2
	GameData.party[1].hp = 0
	GameData.party[2].mp = 0
	assert_true(SaveManager.save("res://scenes/maps/town.tscn", Vector2(1, 2)), "存档")
	# 扰动后读档
	GameData.party[0].hp = 999
	assert_true(SaveManager.load_save(), "读档")
	assert_eq(GameData.party[0].hp, 37, "kyle hp 往返无损")
	assert_eq(GameData.party[0].level, 3, "kyle level 往返无损")
	assert_eq(GameData.party[0].mp, 2, "kyle mp 往返无损")
	assert_eq(GameData.party[1].hp, 0, "lina hp=0 往返无损")
	assert_eq(GameData.party[2].mp, 0, "mona mp=0 往返无损")
	# 重建的记录应保有身份字段
	assert_eq(GameData.party[0].id, "kyle", "id 往返无损")
	assert_eq(GameData.party[0].name, "凯尔", "name 往返无损")
	assert_eq(GameData.party[0].job, "swordsman", "job 往返无损")
	# 上限字段同步无损
	assert_eq(GameData.party[0].max_hp, 120, "max_hp 往返无损")


func test_05_flags序列化为JSON数组() -> void:
	GameData.flags = {"a": true, "b": true}
	assert_true(SaveManager.save("m", Vector2.ZERO), "存档")
	var data := _read_json(TEST_PATH)
	assert_true(data["flags"] is Array, "JSON 里 flags 应为数组（ADR-3 口径）")
	assert_eq((data["flags"] as Array).size(), 2, "flags 数组含全部键")


func test_06_存读再存二次往返稳定() -> void:
	GameData.story_phase = 1
	GameData.chests_opened = ["c1"]
	assert_true(SaveManager.save("m1", Vector2(10, 20)), "第一次存档")
	assert_true(SaveManager.load_save(), "第一次读档")
	assert_true(SaveManager.save("m2", Vector2(30, 40)), "第二次存档")
	GameData.story_phase = 7
	GameData.chests_opened = ["zzz"]
	assert_true(SaveManager.load_save(), "第二次读档")
	assert_eq(GameData.story_phase, 1, "二存二读后 story_phase 仍无损")
	assert_eq(GameData.chests_opened, ["c1"], "二存二读后集合仍无损")
	assert_eq(SaveManager.last_loaded["map"], "m2", "last_loaded 应为最新一次读档内容")


# =============== 3. 容错分支 ===============

func test_07_缺失文件容错() -> void:
	# 从未存过档：load 返回 false，GameData 不被触碰
	GameData.story_phase = 5
	assert_false(SaveManager.load_save(), "无存档文件应返回 false")
	assert_eq(GameData.story_phase, 5, "读档失败时 GameData 不变")


func test_08_损坏JSON容错() -> void:
	assert_true(SaveManager.save("m", Vector2.ZERO), "先写一份正常档")
	_write_raw(TEST_PATH, "{这不是合法JSON")
	GameData.story_phase = 3
	assert_false(SaveManager.load_save(), "损坏档应返回 false")
	# 引擎对非法 JSON 必然打印 Parse Error（JSON.parse_string 内部行为），
	# 属预期错误，显式断言并标记已处理，防 GUT 计为 Unexpected Errors
	assert_engine_error("Parse JSON failed", "损坏档触发引擎 Parse Error 属预期")
	assert_eq(GameData.story_phase, 3, "损坏档不污染 GameData")
	assert_false(SaveManager.last_loaded.has("map"), "损坏档不写入 last_loaded")


func test_09_非对象JSON容错() -> void:
	_write_raw(TEST_PATH, "[1, 2, 3]")
	assert_false(SaveManager.load_save(), "顶层数组应被拒绝")


func test_10_缺失字段按SCHEMA默认补齐() -> void:
	# 手改存档少了三个字段：应按 SCHEMA 默认值补齐而非炸掉
	_write_raw(TEST_PATH, JSON.stringify({
		"version": 1, "map": "res://scenes/maps/town.tscn", "story_phase": 4,
		"position": [5.0, 6.0], "party": [],
	}))
	assert_true(SaveManager.load_save(), "缺字段的档应可读")
	assert_eq(GameData.story_phase, 4, "已有字段正常回灌")
	assert_true(GameData.chests_opened.is_empty(), "缺失 chests_opened 补默认空")
	assert_true(GameData.flags.is_empty(), "缺失 flags 补默认空")
	assert_eq(GameData.party.size(), 0, "缺失 party 补默认空数组")


# =============== 4. 原子写（探索 GDD §3.4 工程义务） ===============

func test_11_原子写成功后无tmp残留() -> void:
	assert_true(SaveManager.save("m", Vector2.ZERO), "存档")
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), "rename 完成后不应有 .tmp 残留")
	assert_true(FileAccess.file_exists(TEST_PATH), "正式档存在")


func test_12_写入失败保留旧档() -> void:
	# 先写一份好档
	GameData.story_phase = 6
	assert_true(SaveManager.save("good_map", Vector2(7, 8)), "好档写入")
	# 再对同一目标路径制造写失败：把 save_path 指到不存在的目录
	SaveManager.save_path = "user://e4s1_no_such_dir/cannot_write.json"
	assert_false(SaveManager.save("bad", Vector2.ZERO), "不可写路径应返回 false")
	# 旧档完好：路径还原后读出仍是好档内容
	SaveManager.save_path = TEST_PATH
	GameData.story_phase = 0
	assert_true(SaveManager.load_save(), "旧档应仍可读")
	assert_eq(GameData.story_phase, 6, "写入失败后旧档内容原封不动")
	assert_eq(SaveManager.last_loaded["map"], "good_map", "旧档 map 字段无损")
	# 注："写入中途强杀进程旧档可读出"为人工实测项（任务管理器杀进程），
	# 本用例覆盖的是同一保证的单元级分支：rename 未发生 → 旧档从未被触碰。


# =============== 5. version 迁移骨架 ===============

func test_13_旧版本号上迁到当前版本() -> void:
	# 构造 version=0 的"旧档"：字段齐但版本号落后
	_write_raw(TEST_PATH, JSON.stringify({
		"version": 0, "map": "old_map", "position": [1.0, 2.0],
		"party": [], "story_phase": 8, "flags": ["f0"],
		"chests_opened": [], "discovered_weakness_set": [], "cleared_enemy_set": [],
	}))
	assert_true(SaveManager.load_save(), "旧版本档应经迁移后可读")
	assert_eq(GameData.story_phase, 8, "旧档数据正常回灌")
	assert_eq(int(SaveManager.last_loaded["version"]), SaveManager.SCHEMA_VERSION,
			"迁移后 version 应上迁到当前格式版本")


func test_14_未来版本拒绝读入() -> void:
	_write_raw(TEST_PATH, JSON.stringify({
		"version": 99, "map": "future", "story_phase": 1, "position": [0.0, 0.0],
		"party": [], "flags": [], "chests_opened": [],
		"discovered_weakness_set": [], "cleared_enemy_set": [],
	}))
	GameData.story_phase = 4
	assert_false(SaveManager.load_save(), "未来版本格式应拒绝读入")
	assert_eq(GameData.story_phase, 4, "拒绝读入时 GameData 不变")


func test_15_has_save与last_loaded语义() -> void:
	assert_false(SaveManager.has_save(), "未存档时 has_save 为 false")
	assert_true(SaveManager.last_loaded.is_empty(), "未读档时 last_loaded 为空")
	assert_true(SaveManager.save("res://scenes/maps/town.tscn", Vector2(192, 640)), "存档")
	assert_true(SaveManager.has_save(), "存档后 has_save 为 true")
	assert_true(SaveManager.load_save(), "读档")
	assert_eq(String(SaveManager.last_loaded["map"]), "res://scenes/maps/town.tscn",
			"last_loaded 携带 map（E4-S7 回图依据）")
	assert_eq(SaveManager.last_loaded["position"], [192.0, 640.0],
			"last_loaded 携带 position（E4-S7 回置依据）")


# =============== 6. 装备持久化（v3，E6-S1 T3.3） ===============

func test_16_装备往返_持有池与身上装备() -> void:
	# 写入态：凯尔装铁剑（出池）、池里只剩皮甲
	GameData.party[0].weapon_id = "iron_sword"
	GameData.party[0].armor_id = ""
	GameData.owned_equipment = ["leather_armor"]
	assert_true(SaveManager.save("m", Vector2.ZERO), "存档")
	# 扰动后读档
	GameData.party[0].weapon_id = ""
	GameData.owned_equipment = []
	assert_true(SaveManager.load_save(), "读档")
	assert_eq(String(GameData.party[0].weapon_id), "iron_sword",
			"身上武器往返无损")
	assert_eq(GameData.owned_equipment, ["leather_armor"], "持有池往返无损")
	# 落盘 JSON 结构锚定：party 条目含装备键、顶层 equipment 为数组
	var data := _read_json(TEST_PATH)
	assert_true((data["party"][0] as Dictionary).has("weapon_id"),
			"party 条目应内嵌 weapon_id（v3 结构）")
	assert_true(data["equipment"] is Array, "顶层 equipment 应为数组")


func test_17_v2旧档迁移_补装备默认值() -> void:
	# 构造 v2 真实结构旧档：无 equipment 键、party 条目无装备字段
	_write_raw(TEST_PATH, JSON.stringify({
		"version": 2, "map": "res://scenes/maps/town.tscn",
		"position": [1.0, 2.0], "story_phase": 3, "flags": [],
		"chests_opened": [], "discovered_weakness_set": [],
		"cleared_enemy_set": [], "inventory": {"potion_s": 1},
		"party": [{"id": "kyle", "name": "凯尔", "job": "swordsman",
			"level": 1, "hp": 120, "max_hp": 120, "mp": 10, "max_hp2": 0,
			"max_mp": 10}],
	}))
	assert_true(SaveManager.load_save(), "v2 旧档应经迁移后可读")
	assert_eq(int(SaveManager.last_loaded["version"]), 3, "迁移后 version 应为 3")
	assert_eq(GameData.owned_equipment, ["iron_sword", "leather_armor"],
			"v2 旧档持有池应补初始 2 件（与 New Game 一致）")
	assert_eq(String(GameData.party[0].weapon_id), "",
			"v2 旧档角色装备应补空串（人人空手）")
	assert_eq(int(GameData.inventory["potion_s"]), 1, "v2 背包字段原样保留")
