extends GutTest
## E2-S4 BattleResult 写回闭环（TASK-S2-10，EPIC-2 收官）
##
## 断言覆盖（EPIC-2.md E2-S4 三条验收标准的自动化部分）：
##   A. 覆写：party_state 快照（E2-S3 备好的 id/level/hp/max_hp/mp/max_mp
##      结构）逐字段写回 GameData.party；队伍外 id 跳过不炸；
##   B. 胜利：defeat_enemy_uid 写入 cleared_enemy_set（查重不重复登记）；
##      数据驱动防复活——命中集合的敌人装载即自删（visible_enemy 自查）；
##   C. 回图回置：VICTORY/DEFEAT 都经 SceneRouter 回图（假 Main 骨架驱动
##      真实 change_scene 通路），玩家回置到 return_position，簿记清空；
##      result 自带字段优先、Router 暂存兜底；
##   D. immunity 0.5s：玩家免疫启动、窗口内敌人接触不发射 enemy_touched、
##      窗口过后恢复可触发、免疫期内重复启动取大不缩短。
##
## 【测试策略】延续前三单纪律：不实例化 main.tscn；GameData 用快照/恢复
##   做跨用例隔离（handler 真写全局单例，测后必须还原）；handler 直驱
##   _on_battle_finished / _on_map_ready（不经 EventBus 转一道弯）；
##   假 Main 骨架 after_each 强制拆除（SMK-01 零污染，E2-S3 同款）。
##
## 跑法（项目根下）：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const MAP_SCENE_PATH: String = "res://tests/smoke/fixtures/map_e2s2.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/player.tscn"
const ENEMY_SCENE_PATH: String = "res://scenes/enemies/visible_enemy.tscn"
const HANDLER_SCRIPT_PATH: String = "res://scripts/battle/battle_result_handler.gd"
const IMMUNITY_DURATION: float = 0.5

## party_state 快照样板（E2-S3 battle_scene._build_result 同构 6 字段）
const SNAPSHOT_LINA: Dictionary = {
	"id": "lina", "level": 2, "hp": 66, "max_hp": 113, "mp": 38, "max_mp": 38}

## 跨用例隔离用的 GameData 快照（before_all 取，after_all 还原）
var _party_backup: Array = []
var _cleared_backup: Array = []
var _flags_backup: Dictionary = {}

## 每条用例的 handler 实例（直驱消费方法）
var _handler: Node = null

## 假 Main 骨架（after_each 拆除）
var _fake_main: Node = null


func before_all() -> void:
	# 全局单例快照（handler 真写 GameData，测后必须还原，防泄漏给其他脚本）
	for c: Resource in GameData.party:
		_party_backup.append({
			"id": c.id, "level": c.level, "hp": c.hp, "max_hp": c.max_hp,
			"mp": c.mp, "max_mp": c.max_mp})
	_cleared_backup = (GameData.cleared_enemy_set as Array).duplicate()
	_flags_backup = GameData.flags.duplicate()


func after_all() -> void:
	# 还原全局单例（幂等：after_each 也调，防用例内覆写外溢）
	for i: int in GameData.party.size():
		var c: Resource = GameData.party[i]
		var b: Dictionary = _party_backup[i]
		c.level = b["level"]
		c.hp = b["hp"]
		c.max_hp = b["max_hp"]
		c.mp = b["mp"]
		c.max_mp = b["max_mp"]
	GameData.cleared_enemy_set = _cleared_backup.duplicate()
	GameData.flags = _flags_backup.duplicate()


func before_each() -> void:
	_handler = (load(HANDLER_SCRIPT_PATH) as GDScript).new()
	autofree(_handler)
	add_child_autofree(_handler)  # 入树：与生产一致（生产挂 Router 之下），
	# get_tree()/call_deferred 通路与真实运行同构
	# Router 簿记重置（E2-S3 同款：autoload 状态跨用例泄漏防护）
	SceneRouter._staged_payload = {}
	SceneRouter.current_scene_path = ""
	SceneRouter._switching = false
	# E4-S6 存档意图位重置（VICTORY 置位会外溢到后续用例/脚本）
	SaveManager.save_requested_pending = false


func after_each() -> void:
	# 假 Main 骨架强制拆除（含 Router 装入的地图），SMK-01 零污染
	if _fake_main != null and is_instance_valid(_fake_main):
		_fake_main.free()
	_fake_main = null
	# 处理器簿记清零（跨用例隔离）
	if _handler != null and is_instance_valid(_handler):
		_handler._pending_return = {}
	# 存档意图位还原（防 VICTORY 用例置位外溢）
	SaveManager.save_requested_pending = false
	# 每条用例后还原队伍/集合（用例内覆写不外溢）
	after_all()


## 造假 Main/World 骨架（空 World：触发 Router"无环境拒绝"与"装载可达"两类路径）
func _make_fake_main() -> Node:
	var main := Node2D.new()
	main.name = "Main"
	var world := Node2D.new()
	world.name = "World"
	main.add_child(world)
	get_tree().root.add_child(main)
	_fake_main = main
	return main


## 取 Router 刚换装进 World 的"当前地图"（非测试预置的旧图——
## battle_finished 触发 Router 换装后，生产语义下的"本图玩家"是新图新实例）
func _routed_map() -> Node:
	var world: Node = _fake_main.get_node("World")
	var map: Node = world.get_child(world.get_child_count() - 1)
	assert_eq(map.get_child_count() > 0, true, "World 应已装入地图场景")
	return map


## 取 Router 换装后的地图上由 TempPlayerMount 挂载的玩家（节点名 Player）
func _routed_player() -> Node2D:
	return _routed_map().get_node("YSorted/Player") as Node2D


## VICTORY 结果样板（字段与 E2-S3 battle_scene._build_result 同构，
## 另带战斗场景随结果转交的回图三字段；map 用测试场路径使装载可达）
func _victory_result() -> Dictionary:
	return {
		"outcome": "VICTORY",
		"party_state": [SNAPSHOT_LINA.duplicate()],
		"exp_gained": [],
		"gold_gained": 0,
		"items_used": [],
		"return_map": MAP_SCENE_PATH,
		"return_position": Vector2(100, 200),
		"defeat_enemy_uid": "enemy_e2s2_a",
	}


## DEFEAT 结果样板（无回图三字段：回退链走 Router 暂存）
func _defeat_result() -> Dictionary:
	return {
		"outcome": "DEFEAT",
		"party_state": [],
		"exp_gained": [],
		"gold_gained": 0,
		"items_used": [],
	}


# =============== A. GameData 覆写 ===============

func test_party_state快照逐字段覆写() -> void:
	# 莉娜 Lv1 80/80 30/30（E2-S1 初始）→ 快照 Lv2 66/113 38/38
	_handler._apply_party_state([SNAPSHOT_LINA.duplicate()])
	var lina: Resource = GameData.party[1]
	assert_eq(lina.id, "lina", "对账键应为 id")
	assert_eq(lina.level, 2, "level 应覆写为快照值")
	assert_eq(lina.hp, 66, "hp 应覆写为快照值")
	assert_eq(lina.max_hp, 113, "max_hp 应覆写为快照值")
	assert_eq(lina.mp, 38, "mp 应覆写为快照值")
	assert_eq(lina.max_mp, 38, "max_mp 应覆写为快照值")
	# 未出现在快照中的角色不受影响
	var kyle: Resource = GameData.party[0]
	assert_eq(kyle.hp, 120, "快照外角色（凯尔）不得被误写")


func test_party_state含队伍外id跳过不炸() -> void:
	# 防御式：快照 id 不在队伍（如未来换人/临时单位）→ 跳过 + 告警，不崩
	var before: int = GameData.party.size()
	var ghost: Dictionary = {"id": "ghost_xx", "level": 9, "hp": 1,
			"max_hp": 1, "mp": 1, "max_mp": 1}
	_handler._apply_party_state([ghost, SNAPSHOT_LINA.duplicate()])
	assert_eq(GameData.party.size(), before, "队伍人数不得变")
	assert_eq(GameData.party[1].hp, 66, "合法快照仍应正常写入")


# =============== B. 胜利分支 ===============

func test_VICTORY击破凭据写入cleared集合且查重() -> void:
	assert_false(GameData.cleared_enemy_set.has("enemy_e2s2_a"),
			"前置：集合中无该敌人")
	_handler._on_battle_finished(_victory_result())
	assert_true(GameData.cleared_enemy_set.has("enemy_e2s2_a"),
			"VICTORY 后击破凭据应入集合")
	var size_after_first: int = (GameData.cleared_enemy_set as Array).size()
	_handler._on_battle_finished(_victory_result())  # 重复结算同一敌人
	assert_eq((GameData.cleared_enemy_set as Array).size(), size_after_first,
			"重复 VICTORY 不得重复登记（查重）")


func test_数据驱动防复活_命中集合的敌人装载即自删() -> void:
	# 集合登记 enemy_e2s2_a → 该实例化 _ready 应 queue_free（不复活）
	GameData.cleared_enemy_set.append("enemy_e2s2_a")
	var packed: PackedScene = load(ENEMY_SCENE_PATH) as PackedScene
	var enemy: CharacterBody2D = packed.instantiate()
	enemy.enemy_uid = "enemy_e2s2_a"  # 赋 uid 必须先于入树：_ready 自查依赖它
	add_child_autofree(enemy)
	assert_true(enemy.is_queued_for_deletion(),
			"命中击破集合的敌人装载后应自删")
	# 对照组：集合外的敌人正常存活
	var enemy2: CharacterBody2D = packed.instantiate()
	enemy2.enemy_uid = "enemy_alive"
	add_child_autofree(enemy2)
	assert_false(enemy2.is_queued_for_deletion(), "集合外敌人不得被误删")


func test_VICTORY回图并回置_簿记清空() -> void:
	_make_fake_main()
	_handler._on_battle_finished(_victory_result())
	# 回图经 Router 受理（假 Main 有 World，同步换装真实执行）
	assert_eq(SceneRouter.current_scene_path, MAP_SCENE_PATH,
			"VICTORY 应经 Router 回图")
	# 生产时序：新图 _ready 发 map_ready → handler 回置；测试同步直驱
	# _pos_return_immediate 等价复现（免 await，断言确定性）
	_handler._on_map_ready("map_e2s2")
	_handler._pos_return_immediate()
	# "本图玩家"是 Router 换装后新图的 TempPlayerMount 挂载实例（生产语义）
	var player: Node2D = _routed_player()
	assert_eq(player.global_position, Vector2(100, 200),
			"玩家应回置到 return_position（敌人来向外侧一格）")
	assert_ne(player.global_position, Vector2(96, 320), "不得停留在出生点")
	assert_eq((_handler._pending_return as Dictionary).size(), 0,
			"回置完成后簿记应清空")
	assert_true(player.is_encounter_immune(), "回置后应处于免疫期")


func test_VICTORY缺击破凭据仅告警不炸() -> void:
	# result 与暂存都没有 defeat_enemy_uid：敌人保留 + 流程不中断
	_make_fake_main()
	var r: Dictionary = _victory_result()
	r.erase("defeat_enemy_uid")
	var size_before: int = (GameData.cleared_enemy_set as Array).size()
	_handler._on_battle_finished(r)
	assert_eq((GameData.cleared_enemy_set as Array).size(), size_before,
			"缺凭据不得写集合")
	assert_eq(SceneRouter.current_scene_path, MAP_SCENE_PATH,
			"缺凭据不阻断回图")


# =============== C. 失败分支与回退链 ===============

func test_DEFEAT读档成功_回存档点() -> void:
	# 【E4-S7 语义】DEFEAT → load_save() 成功 → 回存档 map/position；
	# GameData 随 _restore 回滚（story_phase 等回到存档时点）。
	# 准备：写一份独立存档（save_path 覆写隔离，SMK-12 口径）
	var old_path: String = SaveManager.save_path
	SaveManager.save_path = "user://e2s4_defeat_test_save.json"
	GameData.story_phase = 7
	GameData.flags = {"evt_flag_test": true}
	assert_true(SaveManager.save("ruins_f1", Vector2(448, 56)), "预置存档")
	# 战斗"污染"状态（模拟战斗期间状态变化；DEFEAT 后应回滚）
	GameData.story_phase = 99
	_make_fake_main()
	_handler._on_battle_finished(_defeat_result())
	# 读档回滚断言
	assert_eq(GameData.story_phase, 7, "DEFEAT 读档应回滚 story_phase 到存档时点")
	assert_true(GameData.flags.has("evt_flag_test"), "flags 应随 _restore 回滚")
	assert_eq(SceneRouter.current_scene_path,
			"res://scenes/maps/ruins_f1.tscn", "DEFEAT 应回存档 map 的场景路径")
	_handler._on_map_ready("ruins_f1")
	_handler._pos_return_immediate()
	var player: Node2D = _routed_player()
	assert_eq(player.global_position, Vector2(448, 56),
			"DEFEAT 回置应取存档 position（进图存档点）")
	assert_true(player.is_encounter_immune(), "DEFEAT 回置后同样免疫")
	# 清理（隔离纪律：还原 save_path + 删测试档）
	SaveManager.save_path = old_path
	SaveManager.last_loaded = {}
	DirAccess.remove_absolute("user://e2s4_defeat_test_save.json")


func test_DEFEAT读档失败_兜底回暂存图() -> void:
	# 【E4-S7 兜底】无存档（load_save false）→ 回暂存 return_map + 告警，
	# 流程不断（防御式：存档链路异常时仍能回到战斗前地图）
	var old_path: String = SaveManager.save_path
	SaveManager.save_path = "user://e2s4_no_such_dir/cannot_exist.json"
	SceneRouter._staged_payload = {"return_map": MAP_SCENE_PATH,
			"return_position": Vector2(48, 60)}
	_make_fake_main()
	_handler._on_battle_finished(_defeat_result())
	assert_eq(SceneRouter.current_scene_path, MAP_SCENE_PATH,
			"读档失败应兜底回暂存图")
	_handler._on_map_ready("map_e2s2")
	_handler._pos_return_immediate()
	var player: Node2D = _routed_player()
	assert_eq(player.global_position, Vector2(48, 60),
			"兜底回置应取暂存 return_position")
	SaveManager.save_path = old_path


func test_result自带字段优先于暂存() -> void:
	# 优先级：result 字段 > Router 暂存（防战斗期间暂存被覆盖后错回）
	SceneRouter._staged_payload = {"return_map": "res://nowhere.tscn",
			"return_position": Vector2.ZERO, "defeat_enemy_uid": "stale_uid"}
	_make_fake_main()
	var r: Dictionary = _victory_result()
	_handler._on_battle_finished(r)
	# result 的 map/uid 应胜出（stale_uid 不得入集合）
	assert_eq(SceneRouter.current_scene_path, MAP_SCENE_PATH,
			"result.return_map 应优先于暂存")
	assert_true(GameData.cleared_enemy_set.has("enemy_e2s2_a"),
			"result 凭据应胜出")
	assert_false(GameData.cleared_enemy_set.has("stale_uid"),
			"暂存旧凭据不得误入集合")


func test_无回图目标仅告警停留原地() -> void:
	# result/暂存均缺 return_map：不切换、簿记不置位（防御式）
	var r: Dictionary = _victory_result()
	r.erase("return_map")  # 样板自带回图字段，须显式擦除才落到"无目标"分支
	r.erase("return_position")
	SceneRouter._staged_payload = {}
	SceneRouter.current_scene_path = ""
	_handler._on_battle_finished(r)
	assert_eq(SceneRouter.current_scene_path, "", "无目标不得切换")
	assert_eq((_handler._pending_return as Dictionary).size(), 0,
			"无目标不得置回置簿记")


# =============== D. encounter_immunity 0.5s ===============

func test_免疫启动与倒计时清零() -> void:
	var player: CharacterBody2D = (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	autofree(player)
	add_child_autofree(player)
	assert_false(player.is_encounter_immune(), "初始无免疫")
	player.start_encounter_immunity(IMMUNITY_DURATION)
	assert_true(player.is_encounter_immune(), "启动后应处于免疫期")
	assert_almost_eq(player.encounter_immunity, IMMUNITY_DURATION, 0.001,
			"免疫剩余应约 0.5s")
	# 推满 0.5s 物理帧：免疫应自然清零（_physics_process 倒计时）
	for i: int in 40:
		player._physics_process(1.0 / 60.0)
	assert_false(player.is_encounter_immune(), "0.5s 后免疫应过期")


func test_免疫期内敌人接触不发射_过期后恢复() -> void:
	# E2-S2 接触链 + E2-S4 免疫状态联合验证：窗口内二次接触不进战斗
	var enemy: CharacterBody2D = (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
	autofree(enemy)
	enemy.position = Vector2(400, 240)
	add_child_autofree(enemy)
	var player: CharacterBody2D = (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	autofree(player)
	add_child_autofree(player)
	player.global_position = Vector2(400, 240)
	var fires: Array = []
	var cb := func(_p: Dictionary) -> void:
		fires.append(1)
	EventBus.enemy_touched.connect(cb)
	# 窗口内：接触放行，不发射
	player.start_encounter_immunity(IMMUNITY_DURATION)
	enemy._handle_player_contact(player)
	assert_eq(fires.size(), 0, "免疫窗口内接触不得发射 enemy_touched")
	# 推 0.6s：免疫过期后同一接触应正常发射（再撞同一敌人可进战斗）
	for i: int in 40:
		player._physics_process(1.0 / 60.0)
	assert_false(player.is_encounter_immune(), "前置：免疫已过期")
	enemy._handle_player_contact(player)
	EventBus.enemy_touched.disconnect(cb)
	assert_eq(fires.size(), 1, "免疫过期后接触应发射 enemy_touched")


func test_免疫重复启动取大不缩短() -> void:
	# 幂等取大：剩余 0.4s 时再启动 0.5s 不得把剩余压回 0.5 以下/以上错乱，
	# 语义 = max(旧剩余, 新时长)
	var player: CharacterBody2D = (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	autofree(player)
	add_child_autofree(player)
	player.start_encounter_immunity(IMMUNITY_DURATION)
	for i: int in 6:  # 消耗 0.1s，剩 0.4s
		player._physics_process(1.0 / 60.0)
	var remaining_before: float = player.encounter_immunity
	player.start_encounter_immunity(0.2)  # 更短的启动不得缩短剩余
	assert_almost_eq(player.encounter_immunity, remaining_before, 0.001,
			"更短启动不得缩短剩余免疫")
	player.start_encounter_immunity(0.9)  # 更长启动应取大
	assert_almost_eq(player.encounter_immunity, 0.9, 0.001,
			"更长启动应取大")


func test_免疫查询不依赖方法存在性_普通节点安全() -> void:
	# has_method 防御：无免疫接口的节点（如占位体）接触照常触发
	var enemy: CharacterBody2D = (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
	autofree(enemy)
	enemy.position = Vector2(10, 10)
	add_child_autofree(enemy)
	var plain := Node2D.new()
	autofree(plain)
	plain.position = Vector2(10, 10)
	var fires: Array = []
	var cb := func(_p: Dictionary) -> void:
		fires.append(1)
	EventBus.enemy_touched.connect(cb)
	enemy._handle_player_contact(plain)
	EventBus.enemy_touched.disconnect(cb)
	assert_eq(fires.size(), 1, "无免疫接口的接触对象应照常触发遇敌")
