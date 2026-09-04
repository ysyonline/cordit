extends GutTest
## M6 T4.1 菜单存读档项接线 SaveManager（E6-S4 第 1 步）
##
## 【断言覆盖】E6-S4 验收第 2 条"手动存档与自动存档格式一致、可互相覆盖
##   读出"的可自动化面 + 菜单存读档语义对表（GDD §3.4 + E4-S6 已落地裁决）：
##   A. 存档项：confirm_current("save") → SaveManager.save_game 即时落盘
##      （不依赖 save_requested_pending 门控——那是跨图传送/战后自动存的
##      通道）；落盘坐标 = 玩家当前位置；文件 version=3（11 字段 + party
##      内嵌 weapon_id/armor_id + 顶层 equipment，与自动存档同 schema）；
##      成功后关菜单回地图；
##   B. 存档档可读回：SaveManager.load_save 走同一条读档链还原 GameData
##      （"互相覆盖读出"的数据面——自动存与手动存共用单槽同格式）；
##   C. 读档项全链路：confirm_current("load") → load_save 回滚 GameData →
##      battle_finished(DEFEAT) → BattleResultHandler 回存档图 → 回置玩家
##      + 0.5s 免疫（E4-S7 DEFEAT 读档路径复用，菜单真发信号，真 handler
##      + 假 Main 骨架全链路驱动，e2s4 DEFEAT 用例同款环境）；
##   D. 无档不可达：置灰（唯一授权 = SaveManager.has_save()，既有口径）+
##      光标整圈跳过 + 防御兜底（强制光标到位确认也不触发读档链）；
##   E. 损坏档防御：文件在但 JSON 非法 → 读档失败菜单保持打开、GameData
##      不动、last_loaded 不写。
##
## 【测试策略】菜单 UI 直驱（e6s1 同款：confirm_current() 主模态入口直驱）；
##   存档隔离 = save_path 覆写指测试槽 + 用例前后删测试档（SMK-12 口径：
##   不碰真实存档槽）；GameData 全字段快照/还原（e2s4+e6s1 三件套合集——
##   load_save 真回滚 GameData，测后必须还原）；C 组真信号驱动时生产
##   SceneRouter 自带的常驻 handler/bridge 同帧参与（bridge 无簿记直通；
##   双 handler 幂等回置收敛），after_each 追加清生产 handler 簿记防泄漏。
##
## 跑法（项目根下）：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const MenuPanelScript := preload("res://scripts/ui/menu_panel.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")
const HANDLER_SCRIPT_PATH: String = "res://scripts/battle/battle_result_handler.gd"
const TOWN_SCENE_PATH: String = "res://scenes/maps/town.tscn"
const SAVE_TEST_PATH: String = "user://m6t41_test_save.json"

## 跨用例隔离用的 GameData 全字段快照（before_all 取，after_all 还原）
var _party_backup: Array = []
var _inventory_backup: Dictionary = {}
var _equip_backup: Array = []
var _phase_backup: int = 0
var _flags_backup: Dictionary = {}
var _cleared_backup: Array = []
var _chests_backup: Array = []
var _weakness_backup: Array = []

var _menu: Control = null
## C 组全链路用例的测试自有 handler 实例（e2s4 同款；直连 EventBus 参与）
var _handler: Node = null
## 假 Main 骨架（e2s4 同款；Router 装载 town 的落点，after_each 强制拆除）
var _fake_main: Node = null


func before_all() -> void:
	_ensure_party_3()   # 防跨套件 party 泄漏（e5s3 教训，防御性兜底）
	for c: Resource in GameData.party:
		_party_backup.append({
			"id": c.id, "name": c.name, "job": c.job, "level": c.level,
			"hp": c.hp, "max_hp": c.max_hp, "mp": c.mp, "max_mp": c.max_mp,
			"weapon_id": c.weapon_id, "armor_id": c.armor_id})
	_inventory_backup = GameData.inventory.duplicate()
	_equip_backup = GameData.owned_equipment.duplicate()
	_phase_backup = GameData.story_phase
	_flags_backup = GameData.flags.duplicate()
	_cleared_backup = (GameData.cleared_enemy_set as Array).duplicate()
	_chests_backup = (GameData.chests_opened as Array).duplicate()
	_weakness_backup = (GameData.discovered_weakness_set as Array).duplicate()


func after_all() -> void:
	_restore_game_data()


func before_each() -> void:
	_menu = MenuPanelScript.new()
	add_child_autofree(_menu)   # 入树：_ready → ensure_built（默认关闭）
	# Router 簿记重置（e2s4/e6s1 同款隔离）
	SceneRouter._staged_payload = {}
	SceneRouter.current_scene_path = ""
	SceneRouter._switching = false
	# 存档槽隔离：指测试槽（SMK-12 口径）+ 清意图位/last_loaded + 删残留档
	SaveManager.save_path = SAVE_TEST_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}
	_remove_test_save()


func after_each() -> void:
	_remove_test_save()
	# 假 Main 骨架强制拆除（含 Router 装入的 town 全图），SMK-01 零污染
	if _fake_main != null and is_instance_valid(_fake_main):
		_fake_main.free()
	_fake_main = null
	# 测试自有 handler 簿记清零 + 生产常驻 handler 簿记清零（双 handler
	# 真信号用例的泄漏堵口——生产 handler 挂 SceneRouter autoload 之下，
	# 跨用例永生，簿记残留会在后续用例的 map_ready 里误回置）
	if _handler != null and is_instance_valid(_handler):
		_handler._pending_return = {}
	var prod_handler: Node = SceneRouter.get_node_or_null("BattleResultHandler")
	if prod_handler != null:
		prod_handler._pending_return = {}
	_handler = null
	_menu = null
	# 存档槽/簿记还原
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}
	SceneRouter.current_scene_path = ""
	_restore_game_data()


## GameData 全字段还原（after_all / after_each 共用；幂等）
func _restore_game_data() -> void:
	for i: int in GameData.party.size():
		var c: Resource = GameData.party[i]
		var b: Dictionary = _party_backup[i]
		c.level = b["level"]
		c.hp = b["hp"]
		c.max_hp = b["max_hp"]
		c.mp = b["mp"]
		c.max_mp = b["max_mp"]
		c.weapon_id = b["weapon_id"]
		c.armor_id = b["armor_id"]
	GameData.inventory = _inventory_backup.duplicate()
	GameData.owned_equipment = _equip_backup.duplicate()
	GameData.story_phase = _phase_backup
	GameData.flags = _flags_backup.duplicate()
	GameData.cleared_enemy_set = _cleared_backup.duplicate()
	GameData.chests_opened = _chests_backup.duplicate()
	GameData.discovered_weakness_set = _weakness_backup.duplicate()


func _remove_test_save() -> void:
	if FileAccess.file_exists(SAVE_TEST_PATH):
		DirAccess.remove_absolute(SAVE_TEST_PATH)


## 队伍兜底（e6s1/e6s3 同款：GameData.party 不足 3 人时补齐）
func _ensure_party_3() -> void:
	var wanted: Array[String] = ["kyle", "lina", "mona"]
	for cid: String in wanted:
		var found := false
		for c: Resource in GameData.party:
			if c.id == cid:
				found = true
				break
		if not found:
			var cd: Variant = DataTables.get_character(cid)
			if cd != null:
				GameData.party.append(cd)


## 合成 ↓ 键（move_down 主键位；主模态光标驱动用）
func _down_key() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_S
	ev.pressed = true
	return ev


## 造假 Main/World 骨架（e2s4 同款：Router 真实 change_scene 通路落点）
func _make_fake_main() -> Node:
	var main := Node2D.new()
	main.name = "Main"
	var world := Node2D.new()
	world.name = "World"
	main.add_child(world)
	get_tree().root.add_child(main)
	_fake_main = main
	return main


## 取 Router 刚换装进 World 的"当前地图"（e2s4 同款）
func _routed_map() -> Node:
	var world: Node = _fake_main.get_node("World")
	var map: Node = world.get_child(world.get_child_count() - 1)
	assert_eq(map.get_child_count() > 0, true, "World 应已装入地图场景")
	return map


## 取装载地图上的玩家（town 原生 YSorted/Player 结构，e2s4 _routed_player 同款）
func _routed_player() -> Node2D:
	return _routed_map().get_node("YSorted/Player") as Node2D


## 读测试槽存档原文（JSON 解析对表用）
func _read_save_text() -> String:
	var f := FileAccess.open(SAVE_TEST_PATH, FileAccess.READ)
	assert_true(f != null, "前置：测试槽存档文件应可读")
	return f.get_as_text()


## 主模态光标移到第 slot 位（↓ 键事件驱动；slot = ITEM_IDS 下标）
func _cursor_to(slot: int) -> void:
	for _i: int in slot:
		_menu.move_cursor(1)


## 解析测试槽存档 JSON（失败断言后提前返回，防后续空引用炸日志）
func _parsed_save() -> Variant:
	var parsed: Variant = JSON.parse_string(_read_save_text())
	assert_true(parsed is Dictionary, "存档应为合法 JSON 对象")
	if not (parsed is Dictionary):
		return null
	return parsed


# =============== A. 存档项接线（① 即时落盘 / 版本 3 / 坐标） ===============

func test_存档确认_即时落盘且文件版本3() -> void:
	# 生产不变量：菜单只在探索图可开（三门闸），簿记恒为当前探索图路径
	SceneRouter.current_scene_path = TOWN_SCENE_PATH
	assert_false(SaveManager.has_save(), "前置：无存档文件")
	_menu.try_open()
	assert_true(_menu.is_open(), "前置：菜单开启")
	_cursor_to(3)
	assert_eq(_menu.current_item_id(), "save", "前置：光标在存档项")
	# 主模态入口直驱（e6s1 对表口径）
	_menu.confirm_current()
	# 即时落盘：不依赖 save_requested_pending 门控（菜单手动存语义，
	# 门控是跨图传送/战后自动存的通道——两通道互不干扰）
	assert_true(SaveManager.has_save(), "存档确认应即时落盘（不经意图位门控）")
	assert_false(SaveManager.save_requested_pending,
			"手动存不得置位存档意图（门控通道语义隔离）")
	# 文件对表：version=3（与自动存档同一 schema——E6-S4 验收"格式一致"）
	var data: Dictionary = _parsed_save()
	assert_eq(int(data["version"]), 3, "落盘版本应=v3（SCHEMA_VERSION 锚定）")
	assert_eq(int(data["version"]), SaveManager.SCHEMA_VERSION,
			"落盘版本应与 SCHEMA_VERSION 一致")
	assert_eq(data.keys().size(), SaveManager.SCHEMA.keys().size(),
			"字段集应 ≡ SCHEMA 键集（11 字段全量）")
	assert_eq(String(data["map"]), "town", "map 字段应=当前探索图短名（与自动存档口径一致）")
	assert_true(data.has("equipment"), "v3 顶层装备池字段应在场")
	var party0: Dictionary = data["party"][0]
	assert_true(party0.has("weapon_id") and party0.has("armor_id"),
			"party 条目应内嵌装备字段（v3 结构与自动存档一致）")
	# 存档收束：成功后关菜单回地图
	assert_false(_menu.is_open(), "存档成功后应关闭菜单")


func test_存档坐标_取玩家当前位置() -> void:
	# 哑玩家入组（_current_player_position 走 "player" 组解析——与玩家锁
	# 同源口径）；入树后再入组确保组注册生效
	SceneRouter.current_scene_path = TOWN_SCENE_PATH
	var dummy := Node2D.new()
	dummy.name = "DummyPlayer"
	add_child_autofree(dummy)
	dummy.add_to_group("player")
	dummy.global_position = Vector2(123, 456)
	_menu.try_open()
	_cursor_to(3)
	_menu.confirm_current()
	assert_true(SaveManager.has_save(), "前置：已落盘")
	var data: Dictionary = _parsed_save()
	var arr: Array = data["position"]
	assert_eq(Vector2(float(arr[0]), float(arr[1])), Vector2(123, 456),
			"落盘坐标应=玩家当前位置（菜单手动存坐标口径）")


func test_存档档_同链路可读回且GameData还原() -> void:
	# E6-S4 验收"手动存档与自动存档格式一致、可互相覆盖读出"的数据面：
	# 手动存的档必须能被 SaveManager.load_save（DEFEAT/读档项同一条链）读回
	SceneRouter.current_scene_path = TOWN_SCENE_PATH
	GameData.story_phase = 2
	GameData.flags = {"evt_m6t41_flag": true}
	GameData.inventory = {"potion_s": 3}
	GameData.owned_equipment = ["iron_sword"]
	GameData.party[0].hp = 77
	_menu.try_open()
	_cursor_to(3)
	_menu.confirm_current()
	assert_false(_menu.is_open(), "前置：存档已收束关菜单")
	# 读回（唯一读档链入口）
	assert_true(SaveManager.load_save(), "手动档应可被 load_save 读回（同槽同格式）")
	assert_eq(GameData.story_phase, 2, "读回应还原 story_phase")
	assert_true(GameData.flags.has("evt_m6t41_flag"), "读回应还原 flags")
	assert_eq(int(GameData.inventory["potion_s"]), 3, "读回应还原 inventory（int 非 float）")
	assert_eq(GameData.owned_equipment, ["iron_sword"], "读回应还原装备池")
	assert_eq(GameData.party[0].hp, 77, "读回应还原队伍数值")
	assert_eq(String(SaveManager.last_loaded["map"]), "town", "last_loaded.map 应=落盘地图")


# =============== B. 读档项接线（② 成功回置存档点） ===============

func test_读档确认_回滚数据且回存档点带免疫() -> void:
	# ① 造档：走菜单存档接线（与手动存同格式互证）；哑玩家给非零存档坐标，
	#    回置断言更醒目（坐标 (333,444) 随档落盘）
	SceneRouter.current_scene_path = TOWN_SCENE_PATH
	var dummy := Node2D.new()
	dummy.name = "DummyPlayer"
	add_child_autofree(dummy)
	dummy.add_to_group("player")
	dummy.global_position = Vector2(333, 444)
	_menu.try_open()
	_cursor_to(3)
	_menu.confirm_current()
	assert_true(SaveManager.has_save(), "前置：菜单存档已落盘")
	assert_false(_menu.is_open(), "前置：存档后菜单已关")
	# ② 存档后污染状态（模拟"存档后又玩了一段"）；存档时点凯尔 HP=120
	#    （before_all 快照还原口径），污染到 88 后读档应回到 120
	GameData.party[0].hp = 88
	GameData.story_phase = 9
	# ③ 全链路环境：真 handler 入树（参与 EventBus）+ 假 Main 骨架
	#    （e2s4 DEFEAT 用例同款）；生产 SceneRouter 自带 handler/bridge 同帧
	#    参与：bridge 无簿记直通返回，双 handler 幂等回置收敛
	_handler = (load(HANDLER_SCRIPT_PATH) as GDScript).new()
	autofree(_handler)
	add_child_autofree(_handler)
	_make_fake_main()
	# ④ 重新开菜单（重算置灰——现在有档，load 解除置灰）→ 光标到读档项确认
	_menu.try_open()
	assert_false(_menu.is_item_disabled("load"), "有档时读档项应解除置灰")
	_cursor_to(4)
	assert_eq(_menu.current_item_id(), "load", "前置：光标在读档项")
	_menu.confirm_current()
	# 读档即时面：GameData 回滚 + 菜单收束
	assert_eq(GameData.party[0].hp, 120, "读档应整体回滚队伍态到存档时点（E4-S7 同口径）")
	assert_eq(GameData.story_phase, 0, "读档应回滚 story_phase")
	assert_false(_menu.is_open(), "读档成功后应关闭菜单回地图")
	# ⑤ 回图链（真信号→Router 装载存档图 town→map_ready→回置+免疫）：
	#    淡出 0.2s + 装载 + 淡入 0.2s + deferred 回置；到位即查免疫
	#    （0.5s 免疫窗口短于固定等待，轮询到位后立即断言，不赌时长余量）
	var waited := 0.0
	while waited < 2.0:
		await wait_seconds(0.1)
		waited += 0.1
		var world: Node = _fake_main.get_node("World")
		if world.get_child_count() > 0:
			var map: Node = world.get_child(world.get_child_count() - 1)
			if map.scene_file_path == TOWN_SCENE_PATH and map.get_node_or_null("YSorted/Player") != null:
				break
	assert_eq(_routed_map().scene_file_path, TOWN_SCENE_PATH,
			"应经 SceneRouter 回到存档图 town（DEFEAT 读档路径复用）")
	var player: Node2D = _routed_player()
	assert_eq(player.global_position, Vector2(333, 444),
			"玩家应回置到存档坐标（落盘坐标=存档时玩家位置）")
	assert_true(player.is_encounter_immune(),
			"回置后应启动 0.5s 遇敌免疫（E4-S7 回置口径）")


# =============== C. 无档不可达（③ 置灰 + 防御兜底） ===============

func test_无档读档项置灰且确认不触发读档链() -> void:
	# before_each 已清测试档 → has_save()=false（置灰唯一授权口径，既有不变）
	assert_false(SaveManager.has_save(), "前置：无存档文件")
	_menu.try_open()
	assert_true(_menu.is_item_disabled("load"),
			"无档时读档项应置灰（规格 §3.1，唯一授权=has_save）")
	assert_false(_menu.is_item_disabled("save"), "存档项恒可用（规格未授权置灰）")
	# 光标导航：↓ 一整圈（5 步回起点），永不落在置灰的 load 上
	for _i: int in 5:
		_menu.move_cursor(1)
	assert_ne(_menu.current_item_id(), "load", "光标导航应跳过置灰读档项（整圈不落）")
	# 防御兜底：强制光标到位再确认（置灰态与文件态之间的窗口——如运行中
	# 外部删档），不得触发读档链、不得关菜单
	_cursor_to(0)   # 先回 status 再强制指 load（模拟非法到位）
	_menu._cursor_index = _menu.ITEM_IDS.find("load")
	_menu.confirm_current()
	assert_false(SaveManager.last_loaded.has("map"),
			"无档确认不得触发 load_save（防御式再查兜底）")
	assert_true(_menu.is_open(), "无档确认不得关菜单")


func test_损坏档_读档失败菜单保持打开且GameData不动() -> void:
	# 档在但 JSON 非法：has_save()=true（读档项可选）→ load_save 失败 →
	# 菜单保持打开（不假成功）、GameData 原封不动、last_loaded 不写
	var f := FileAccess.open(SAVE_TEST_PATH, FileAccess.WRITE)
	f.store_string("{\"version\": 3, \"map\": ")   # 半截 JSON
	f = null
	SceneRouter.current_scene_path = TOWN_SCENE_PATH
	var phase_before := GameData.story_phase
	var hp_before: int = GameData.party[0].hp
	_menu.try_open()
	assert_false(_menu.is_item_disabled("load"), "前置：文件存在，读档项可选")
	_cursor_to(4)
	_menu.confirm_current()
	# 引擎对非法 JSON 必然打印 Parse Error（JSON.parse_string 内部行为），
	# 属预期错误，显式断言并标记已处理（e4s1 test_08 同款），防 GUT 计为
	# Unexpected Errors
	assert_engine_error("Parse JSON failed", "损坏档触发引擎 Parse Error 属预期")
	assert_true(_menu.is_open(), "读档失败菜单应保持打开（玩家可 X 退出）")
	assert_eq(GameData.story_phase, phase_before, "读档失败 GameData.story_phase 不得被改动")
	assert_eq(GameData.party[0].hp, hp_before, "读档失败队伍数值不得被改动")
	assert_false(SaveManager.last_loaded.has("map"), "失败读档不得写 last_loaded")
