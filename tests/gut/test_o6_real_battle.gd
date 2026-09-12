extends GutTest
## O-6 修复验证：生产路由真实战斗全链路（背景正本见 battle_scene.gd 头注释）
## 验证面：装配 / 队伍接续(残血不回满) / 装备并项(ATK+3) / 槽位序 /
##   确定性驱动至胜利+转发链 / 逃跑确定性转发。
## 推演（variance=1.0；moth DEF3 无相性）：
##   R1 凯尔25 莫娜11 莉娜7 蛾反击凯尔6；R2 凯尔25 击杀。凯尔战后 114。
## 隔离：摘生产 handler（remove_child 必须配 disconnect）/ 测试存档槽 /
##   GameData 备份还原。

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle.tscn"
const SAVE_TEST_PATH: String = "user://save_o6test.json"

const VALID_PAYLOAD: Dictionary = {
	"enemy_group_id": "b1_moth",
	"return_map": "res://tests/smoke/fixtures/map_e2s2.tscn",
	"return_position": Vector2(64, 32),
	"defeat_enemy_uid": "enemy_road_01",
}

var _fake_main: Node = null
var _recv_result: Variant = null
var _prod_handler: Node = null
var _party_backup: Array = []
var _inv_backup: Dictionary = {}
var _cleared_backup: Array = []
var _weak_backup: Array = []


func before_each() -> void:
	_recv_result = null
	SceneRouter._staged_payload = {}
	SceneRouter.current_scene_path = ""
	SceneRouter._switching = false
	SaveManager.save_path = SAVE_TEST_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}
	_remove_test_save()


func after_each() -> void:
	_remove_test_save()
	if _fake_main != null and is_instance_valid(_fake_main):
		_fake_main.free()
	_fake_main = null
	if _prod_handler != null and is_instance_valid(_prod_handler):
		if not EventBus.battle_finished.is_connected(_prod_handler._on_battle_finished):
			EventBus.battle_finished.connect(_prod_handler._on_battle_finished)
		if _prod_handler.get_parent() == null:
			SceneRouter.add_child(_prod_handler)
		_prod_handler._pending_return = {}
	_prod_handler = null
	_restore_game_data()
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}


func _on_battle_finished(r: Dictionary) -> void:
	_recv_result = r


func _detach_prod_handler() -> void:
	_prod_handler = SceneRouter.get_node_or_null("BattleResultHandler")
	if _prod_handler == null or not is_instance_valid(_prod_handler):
		_prod_handler = null
		return
	SceneRouter.remove_child(_prod_handler)
	if EventBus.battle_finished.is_connected(_prod_handler._on_battle_finished):
		EventBus.battle_finished.disconnect(_prod_handler._on_battle_finished)


func _backup_game_data() -> void:
	_party_backup.clear()
	for c: Resource in GameData.party:
		_party_backup.append({
			"id": c.id, "level": c.level, "hp": c.hp, "max_hp": c.max_hp,
			"mp": c.mp, "max_mp": c.max_mp,
			"weapon_id": c.weapon_id, "armor_id": c.armor_id,
		})
	_inv_backup = GameData.inventory.duplicate()
	_cleared_backup = GameData.cleared_enemy_set.duplicate()
	_weak_backup = GameData.discovered_weakness_set.duplicate()


func _restore_game_data() -> void:
	for i: int in _party_backup.size():
		var c: Resource = GameData.party[i]
		var b: Dictionary = _party_backup[i]
		c.level = int(b["level"])
		c.hp = int(b["hp"])
		c.max_hp = int(b["max_hp"])
		c.mp = int(b["mp"])
		c.max_mp = int(b["max_mp"])
		c.weapon_id = String(b["weapon_id"])
		c.armor_id = String(b["armor_id"])
	GameData.inventory = _inv_backup.duplicate()
	GameData.cleared_enemy_set = _cleared_backup.duplicate()
	GameData.discovered_weakness_set = _weak_backup.duplicate()


func _remove_test_save() -> void:
	if FileAccess.file_exists(SAVE_TEST_PATH):
		DirAccess.remove_absolute(SAVE_TEST_PATH)


func _spawn_battle(p: Dictionary = {}) -> Node2D:
	if not p.is_empty():
		SceneRouter._staged_payload = p.duplicate(true)
	var packed: PackedScene = load(BATTLE_SCENE_PATH) as PackedScene
	var battle: Node2D = packed.instantiate()
	autofree(battle)
	add_child_autofree(battle)
	return battle


func _prep_real_battle() -> void:
	_detach_prod_handler()
	_backup_game_data()


func _drive_battle(cmd: RefCounted, max_actions: int = 12) -> void:
	var guard: int = 0
	while not cmd.over and guard < max_actions:
		guard += 1
		var actor: Dictionary = cmd.current_actor()
		if cmd.is_party_turn():
			cmd.submit_command(actor, {"type": "attack", "target_slot": 0}, 1.0)
		else:
			cmd.enemy_action(actor, 0.0, 1.0)


## 轮询等待 battle_finished 到达（O-7 起转发带结算驻留+黑屏，延迟约 1.6s+；
## GUT 用 await 挂起用例直到回调落地或超时）
func _wait_battle_finished(timeout: float = 8.0) -> void:
	var waited: float = 0.0
	while _recv_result == null and waited < timeout:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1


# ===== 测试用例 =====

func test_装配断言() -> void:
	_prep_real_battle()
	var battle := _spawn_battle(VALID_PAYLOAD)
	assert_not_null(battle.get("cmd"), "BattleCommand 应已装配")
	assert_not_null(battle.get("ui"), "BattleUI 应已装配")
	assert_true((battle.get("ui") as Control).is_inside_tree(), "BattleUI 应入树")


func test_队伍接续() -> void:
	_prep_real_battle()
	GameData.party[1].hp = 41
	var battle := _spawn_battle(VALID_PAYLOAD)
	var party: Array = (battle.get("cmd") as RefCounted).party
	assert_eq(int(party[1].get("hp")), 41, "莉娜战斗 HP 应为探索态现值 41（不回满）")


func test_装备并项() -> void:
	_prep_real_battle()
	GameData.party[0].weapon_id = "iron_sword"
	var battle := _spawn_battle(VALID_PAYLOAD)
	var party: Array = (battle.get("cmd") as RefCounted).party
	assert_eq(int(party[0].get("atk")), 17, "凯尔 ATK 应为 14+3=17（含装备）")


func test_槽位序() -> void:
	_prep_real_battle()
	var battle := _spawn_battle(VALID_PAYLOAD)
	var party: Array = (battle.get("cmd") as RefCounted).party
	assert_eq(party.size(), GameData.party.size(), "队伍人数应一致")
	for i: int in party.size():
		assert_eq(String(party[i].get("unit_id")), GameData.party[i].id,
				"槽位 %d 应与 GameData 队伍序一致" % i)


func test_驱动至胜利并转发() -> void:
	_prep_real_battle()
	EventBus.battle_finished.connect(_on_battle_finished)
	var battle := _spawn_battle(VALID_PAYLOAD)
	var cmd: RefCounted = battle.get("cmd")
	_drive_battle(cmd)
	assert_true(cmd.over, "战斗应在 12 行动内结束")
	assert_eq(cmd.outcome, "VICTORY", "三人打单蛾应胜利")
	# O-7：转发带结算驻留+黑屏（约 1.6s+），轮询等待而非同步断言
	await _wait_battle_finished()
	assert_not_null(_recv_result, "battle_finished 应已转发")
	if _recv_result == null:
		EventBus.battle_finished.disconnect(_on_battle_finished)
		return
	var r: Dictionary = _recv_result
	assert_eq(r.get("outcome"), "VICTORY", "outcome 应为 VICTORY")
	assert_eq(r.get("defeat_enemy_uid"), "enemy_road_01", "击破凭据应透传")
	assert_eq(r.get("encounter_id"), "b1_moth", "encounter_id 应透传")
	var ps: Array = r.get("party_state", []) as Array
	assert_eq(ps.size(), 3, "party_state 应覆盖 3 人")
	if ps.size() == 3:
		var snap: Dictionary = ps[0]
		assert_eq(int(snap.get("hp")), 114, "凯尔快照 HP 应为 114（120-6）")
	assert_true(cmd.discovered_weakness.is_empty(), "无相性敌人不产生弱点记忆")
	assert_eq(GameData.party[0].hp, 120, "场景只发不写：GameData 零变化")
	EventBus.battle_finished.disconnect(_on_battle_finished)


func test_逃跑确定性转发() -> void:
	_prep_real_battle()
	EventBus.battle_finished.connect(_on_battle_finished)
	var battle := _spawn_battle(VALID_PAYLOAD)
	var cmd: RefCounted = battle.get("cmd")
	var actor: Dictionary = cmd.current_actor()
	assert_eq(String(actor.get("unit_id")), "kyle", "首轮行动者应为凯尔（SPD 最高）")
	cmd.submit_command(actor, {"type": "escape"}, 1.0, 0.0)
	assert_true(cmd.over, "roll=0.0 应确定性逃跑成功")
	assert_eq(cmd.outcome, "ESCAPE", "outcome 应为 ESCAPE")
	# O-7：转发延迟到黑屏后（约 0.5s），轮询等待而非同步断言
	await _wait_battle_finished()
	assert_not_null(_recv_result, "battle_finished 应已转发")
	if _recv_result == null:
		EventBus.battle_finished.disconnect(_on_battle_finished)
		return
	var r: Dictionary = _recv_result
	assert_eq(r.get("outcome"), "ESCAPE", "outcome 应为 ESCAPE")
	assert_eq(r.get("defeat_enemy_uid"), "enemy_road_01", "逃跑转发同样补击破凭据字段")
	assert_eq(GameData.cleared_enemy_set.size(), 0, "场景只发不写：击破集零变化")
	EventBus.battle_finished.disconnect(_on_battle_finished)
