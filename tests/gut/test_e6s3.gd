extends GutTest
## E6-S3 逃跑/失败结算完善（EPIC-6 第 3 条 Story）
##
## 【断言覆盖】EPIC-6.md E6-S3 两条验收标准 + 战斗 GDD §3.5 / 探索 GDD I3：
##   A. 结算画面文案（battle_ui.show_result）：
##      DEFEAT → "残响中断"画面（含"存档点"去向提示）；
##      ESCAPE → "成功撤退" + 敌人保留语义提示（可绕行可再战）；
##   B. 敌人保留语义（验收 1）：ESCAPE 经 handler 后 cleared_enemy_set
##      不登记（只有 VICTORY 写集合）；集合外敌人实例化不自删
##      （visible_enemy 数据驱动自查——不登记 ⇔ 装载保留 ⇔ 可绕行可再战）；
##   C. 存档意图（验收 2 / I3 时机②生产端）：VICTORY 置位
##      SaveManager.save_requested_pending；ESCAPE/DEFEAT 不置位
##      （消费端 map_ready → consume_save_request 已由 e4s6 覆盖，
##      本文件锚定生产端分支，两端合起来即完整链路证据）。
##
## 【测试策略】handler 直驱 _on_battle_finished（e2s4 同款，不经 EventBus）；
##   BattleUI 直驱 show_result（e6s2 同款）；GameData 快照/还原隔离，
##   意图位用例前后强制清零（e4s6 同款——VICTORY 置位会外溢）。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")
const HANDLER_SCRIPT_PATH: String = "res://scripts/battle/battle_result_handler.gd"
const ENEMY_SCENE_PATH: String = "res://scenes/enemies/visible_enemy.tscn"

## 跨用例隔离用的 GameData 快照（before_all 取，after_all 还原）
var _party_backup: Array = []
var _cleared_backup: Array = []
var _inventory_backup: Dictionary = {}
var _phase_backup: int = 0

var _handler: Node = null


func before_all() -> void:
	_ensure_party_3()   # 防跨套件 party 泄漏（e5s3 教训，防御性兜底）
	for c: Resource in GameData.party:
		_party_backup.append({
			"id": c.id, "level": c.level, "hp": c.hp, "max_hp": c.max_hp,
			"mp": c.mp, "max_mp": c.max_mp})
	_cleared_backup = (GameData.cleared_enemy_set as Array).duplicate()
	_inventory_backup = GameData.inventory.duplicate()
	_phase_backup = GameData.story_phase


func after_all() -> void:
	for i: int in GameData.party.size():
		var c: Resource = GameData.party[i]
		var b: Dictionary = _party_backup[i]
		c.level = b["level"]
		c.hp = b["hp"]
		c.max_hp = b["max_hp"]
		c.mp = b["mp"]
		c.max_mp = b["max_mp"]
	GameData.cleared_enemy_set = _cleared_backup.duplicate()
	GameData.inventory = _inventory_backup.duplicate()
	GameData.story_phase = _phase_backup


func before_each() -> void:
	_handler = (load(HANDLER_SCRIPT_PATH) as GDScript).new()
	autofree(_handler)
	# 不入树：直驱 _on_battle_finished 时 change_scene 对空目标会拒绝告警
	# （ESCAPE/DEFEAT 分支无回图字段），核心断言（集合/意图位）不受影响
	# Router 簿记重置（E2-S4 同款隔离）
	SceneRouter._staged_payload = {}
	SceneRouter.current_scene_path = ""
	SceneRouter._switching = false
	SaveManager.save_requested_pending = false


func after_each() -> void:
	_handler = null
	SaveManager.save_requested_pending = false
	after_all()


## 队伍兜底（test_e6s2._ensure_party_3 同款：GameData.party 不足 3 人时补齐）
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


# =============== A. 结算画面文案 ===============

func test_DEFEAT结算画面_残响中断与存档点提示() -> void:
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result({"outcome": "DEFEAT",
			"party_state": [{"name": "凯尔", "hp": 0, "max_hp": 80,
					"mp": 10, "max_mp": 10}]})
	var text: String = ui.get_result_text()
	assert_true(text.contains("残响中断"), "失败应显示\"残响中断\"画面（GDD §3.5）")
	assert_true(text.contains("存档点"), "应提示读档去向（进入地图时的存档点）")
	assert_false(text.contains("全灭"), "旧占位文案应已替换")


func test_ESCAPE结算画面_撤退与敌人保留提示() -> void:
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result({"outcome": "ESCAPE",
			"party_state": [{"name": "凯尔", "hp": 50, "max_hp": 80,
					"mp": 10, "max_mp": 10}]})
	var text: String = ui.get_result_text()
	assert_true(text.contains("成功撤退"), "应显示撤退文案")
	assert_true(text.contains("敌人仍在原地"), "应提示敌人保留（可绕行可再战，GDD §3.5）")
	assert_true(ui.get_reveal_remaining() == 0 and not ui.is_revealing(),
			"ESCAPE 无待弹行，不启动揭示计时（旧协议行为不变）")


# =============== B. 敌人保留语义（验收 1） ===============

func test_ESCAPE后cleared集合不登记_敌人保留可再战() -> void:
	GameData.cleared_enemy_set = []   # 干净起点（after_all 会还原）
	# 前置锚定：该敌人不在集合（可见、可再战）
	assert_false(GameData.cleared_enemy_set.has("enemy_e6s3_x"),
			"前置：敌人不在击破集合")
	# ESCAPE 结果经 handler 全分支（回图字段缺失走告警路径，断言不受影响）
	_handler._on_battle_finished({"outcome": "ESCAPE", "party_state": []})
	assert_false(GameData.cleared_enemy_set.has("enemy_e6s3_x"),
			"ESCAPE 后集合不得登记——数据不登记 ⇔ 敌人装载保留（可绕行）⇔ 可再战")
	assert_true(GameData.cleared_enemy_set.is_empty(),
			"ESCAPE 全程不得写入集合")


## 数据驱动防复活的镜像面：集合外敌人实例化不自删——ESCAPE 后敌人留在
## 原地正是靠"不写集合"这一数据事实（visible_enemy._ready 自查语义）
func test_集合外敌人实例化不自删_ESCAPE保留语义的数据面() -> void:
	var packed: PackedScene = load(ENEMY_SCENE_PATH) as PackedScene
	var enemy: CharacterBody2D = packed.instantiate()
	enemy.enemy_uid = "enemy_e6s3_x"   # 赋 uid 先于入树：_ready 自查依赖它
	add_child_autofree(enemy)
	assert_false(enemy.is_queued_for_deletion(),
			"未登记集合的敌人装载后应保留（ESCAPE 语义镜像：不登记即不删）")


# =============== C. 存档意图位（验收 2 / I3 时机②生产端） ===============

func test_VICTORY置位存档意图_ESCAPE不置位() -> void:
	GameData.cleared_enemy_set = []
	# VICTORY：应置位 save_requested_pending（回图 map_ready 时
	# AutosaveNotifier 消费落盘——I3 时机②生产端；消费端 e4s6 已覆盖）
	_handler._on_battle_finished({"outcome": "VICTORY", "party_state": [],
			"defeat_enemy_uid": "enemy_e6s3_v"})
	assert_true(SaveManager.save_requested_pending,
			"VICTORY 应置位存档意图（I3：胜利回图立即自动存档）")
	# ESCAPE：不得置位（逃跑不打扰存档节奏）
	SaveManager.save_requested_pending = false
	_handler._on_battle_finished({"outcome": "ESCAPE", "party_state": []})
	assert_false(SaveManager.save_requested_pending,
			"ESCAPE 不得置位存档意图（仅胜利即存，§3.2 防复活口径）")


func test_DEFEAT分支意图位不置位() -> void:
	# DEFEAT：读档链整体回滚（E4-S7），意图位若被置位会被读档态覆盖，
	# 但生产语义上 DEFEAT 走的是"读档落盘"而非"新意图"——显式锚定不置位
	# 【隔离】save_path 覆写指空（e2s4 同款）：防测试机残留存档被真读档、
	# 真换场景——本用例只断言意图位，不验读档链（e2s4 C 组已覆盖）
	var old_path: String = SaveManager.save_path
	SaveManager.save_path = "user://e6s3_no_such_dir/cannot_exist.json"
	_handler._on_battle_finished({"outcome": "DEFEAT", "party_state": []})
	SaveManager.save_path = old_path
	assert_false(SaveManager.save_requested_pending,
			"DEFEAT 不得置位新存档意图（去向由读档链接管）")
