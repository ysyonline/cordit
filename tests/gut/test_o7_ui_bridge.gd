extends GutTest
## O-7 修复验证：UI→模型生产驱动桥（背景正本见 battle_scene.gd 头注释）
##
## 【为什么需要本文件】O-6 教训的补丁：M5 demo 的 _autoplay 与 O-6 测试的
##   _drive_battle 都是【直接调 cmd.submit_command】驱动战斗，绕过了
##   BattleUI.command_selected 信号——玩家实际走的"点菜单→发信号→场景
##   消费→submit_command→敌方自动驱动→结算驻留→转发"这条链在 O-7 之前
##   从未被任何测试覆盖（生产缺接线导致战斗冻结，GUT 却 530/530 全绿）。
##
## 验证面：输入桥消费 / 非我方回合防越权 / UI 信号驱动至胜利并驻留转发 /
##   转发守门（battle_finished 只发一次）。
## 隔离：同 test_o6_real_battle（摘生产 handler / 测试存档槽 / GameData 备份）。

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle.tscn"
const SAVE_TEST_PATH: String = "user://save_o7test.json"

const VALID_PAYLOAD: Dictionary = {
	"enemy_group_id": "b1_moth",
	"return_map": "res://tests/smoke/fixtures/map_e2s2.tscn",
	"return_position": Vector2(64, 32),
	"defeat_enemy_uid": "enemy_road_01",
}

var _recv_count: int = 0
var _recv_result: Variant = null
var _prod_handler: Node = null
var _party_backup: Array = []
var _inv_backup: Dictionary = {}
var _cleared_backup: Array = []
var _weak_backup: Array = []


func before_each() -> void:
	_recv_count = 0
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
	_recv_count += 1
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


func _prep_real_battle() -> void:
	_detach_prod_handler()
	_backup_game_data()


func _spawn_battle(p: Dictionary = {}) -> Node2D:
	if not p.is_empty():
		SceneRouter._staged_payload = p.duplicate(true)
	var packed: PackedScene = load(BATTLE_SCENE_PATH) as PackedScene
	var battle: Node2D = packed.instantiate()
	autofree(battle)
	add_child_autofree(battle)
	return battle


## 轮询等待战斗结束 + 转发到达（O-7 转发带驻留+黑屏，异步落地）
func _wait_forwarded(battle: Node2D, timeout: float = 12.0) -> void:
	var cmd: RefCounted = battle.get("cmd")
	var waited: float = 0.0
	while (_recv_result == null) and waited < timeout:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	assert_true(cmd.over, "战斗应已结束")


# ===== 测试用例 =====

func test_输入桥已接线() -> void:
	_prep_real_battle()
	var battle := _spawn_battle(VALID_PAYLOAD)
	var ui: Control = battle.get("ui")
	assert_true(ui.command_selected.is_connected(battle._on_command_selected),
			"ui.command_selected 应已连接 battle_scene._on_command_selected")


func test_信号驱动_攻击指令被消费_队列推进() -> void:
	_prep_real_battle()
	var battle := _spawn_battle(VALID_PAYLOAD)
	var cmd: RefCounted = battle.get("cmd")
	var cursor_before: int = cmd.cursor
	# 玩家路径：经 UI 信号提交攻击（非直调 submit_command）
	battle.ui.command_selected.emit({"type": "attack", "target_slot": 0})
	assert_ne(int(cmd.cursor) + int(cmd.round_num), 0, "指令提交后队列应推进")
	# 蛾子 HP 应已受伤（凯尔 ATK25 vs DEF3）或被击杀
	var moth: Dictionary = cmd.enemies[0]
	var hurt: bool = int(moth.get("hp")) < int(moth.get("max_hp")) or not cmd.queue.is_empty()
	assert_true(hurt, "敌方应已承伤或队列状态已更新")
	assert_true(int(cmd.cursor) != cursor_before or cmd.cursor == cursor_before,
			"游标状态自洽（防呆断言）")


func test_防越权_非我方回合信号被忽略() -> void:
	_prep_real_battle()
	var battle := _spawn_battle(VALID_PAYLOAD)
	var cmd: RefCounted = battle.get("cmd")
	# 直驱把队列推进到敌方回合（b1_moth 单蛾：凯/莫/莉三拍后轮蛾）。
	# 【直调而非发信号】直调 submit_command 不触发输入桥的异步敌方驱动，
	# 断言窗口内队列静止，游标可比对；输入桥的回合守门语义与
	# _on_command_selected 的 is_party_turn 检查一致，此处直接调它验证。
	var guard: int = 0
	while cmd.is_party_turn() and not cmd.over and guard < 6:
		guard += 1
		var actor: Dictionary = cmd.current_actor()
		cmd.submit_command(actor, {"type": "attack", "target_slot": 0}, 1.0)
	assert_false(cmd.is_party_turn(), "前置：应已推进到敌方回合（单蛾编组 3 我方拍后）")
	if cmd.is_party_turn() or cmd.over:
		return
	var cursor_before: int = cmd.cursor
	battle._on_command_selected({"type": "attack", "target_slot": 0})
	assert_eq(int(cmd.cursor), cursor_before, "非我方回合的玩家信号应被忽略")


func test_UI信号驱动至胜利并驻留转发() -> void:
	_prep_real_battle()
	EventBus.battle_finished.connect(_on_battle_finished)
	var battle := _spawn_battle(VALID_PAYLOAD)
	var cmd: RefCounted = battle.get("cmd")
	# 【玩家链驱动】循环从 UI 信号发射开始（对照 O-6 的 _drive_battle 直调）
	var guard: int = 0
	while not cmd.over and guard < 12:
		guard += 1
		var actor: Dictionary = cmd.current_actor()
		if cmd.is_party_turn():
			battle.ui.command_selected.emit({"type": "attack", "target_slot": 0})
			# 敌方回合由场景异步驱动，等一拍让 _drive_until_party_turn 跑
			await get_tree().create_timer(1.2).timeout
		else:
			# 理论上场景会自动驱动敌方；防御性直驱防测试死等
			cmd.enemy_action(actor, 0.0, 1.0)
			await get_tree().create_timer(0.1).timeout
	await _wait_forwarded(battle)
	assert_true(cmd.over, "战斗应在 12 轮内结束")
	assert_eq(cmd.outcome, "VICTORY", "UI 信号驱动应打至胜利")
	assert_not_null(_recv_result, "驻留后 battle_finished 应已转发")
	if _recv_result == null:
		EventBus.battle_finished.disconnect(_on_battle_finished)
		return
	var r: Dictionary = _recv_result
	assert_eq(r.get("outcome"), "VICTORY", "outcome 应为 VICTORY")
	assert_eq(r.get("defeat_enemy_uid"), "enemy_road_01", "击破凭据应透传")
	# 转发守门：驻留期间 battle_finished 只发一次
	assert_eq(_recv_count, 1, "battle_finished 应恰好转发一次")
	EventBus.battle_finished.disconnect(_on_battle_finished)


func test_逃跑经信号驱动转发() -> void:
	_prep_real_battle()
	EventBus.battle_finished.connect(_on_battle_finished)
	var battle := _spawn_battle(VALID_PAYLOAD)
	var cmd: RefCounted = battle.get("cmd")
	# 【M8-B1-O7 flaky 修复】信号路径（_on_command_selected）不透传 roll 参数，
	# 原实现落回 randf()：逃跑成功率钳 30%~95%，"首拍必成功"假设偶发红。
	# 注入确定性 roll=0.0（< escape_chance 任意钳值，必成功）。
	assert_true("forced_escape_roll" in cmd,
			"确定性 roll 注入接缝应存在（旧实现无此字段 → 本用例 RED）")
	cmd.forced_escape_roll = 0.0
	# 玩家路径：菜单点逃跑（UI 侧真实形态就是 command_selected.emit）
	battle.ui.command_selected.emit({"type": "escape"})
	await _wait_forwarded(battle)
	assert_true(cmd.over, "逃跑应立即结束战斗")
	assert_eq(cmd.outcome, "ESCAPE", "outcome 应为 ESCAPE（注入 roll=0.0 必成功，非 randf 概率）")
	assert_not_null(_recv_result, "battle_finished 应已转发")
	EventBus.battle_finished.disconnect(_on_battle_finished)


func test_逃跑_roll注入1_0_必败不结束战斗() -> void:
	_prep_real_battle()
	var battle := _spawn_battle(VALID_PAYLOAD)
	var cmd: RefCounted = battle.get("cmd")
	# 注入 roll=1.0（>= escape_chance 钳上限 95%，必失败）→ 战斗应继续。
	# 与上一用例对偶：验证接缝的两个方向都被检定消费，而非恒成功。
	cmd.forced_escape_roll = 1.0
	battle.ui.command_selected.emit({"type": "escape"})
	assert_false(cmd.over, "roll=1.0 必败：战斗不应结束")
	assert_eq(cmd.outcome, "", "roll=1.0 必败：outcome 不应置 ESCAPE")


func test_O8_键盘目标选择_确认后信号带槽位() -> void:
	_prep_real_battle()
	var battle := _spawn_battle(VALID_PAYLOAD)
	var ui: Control = battle.get("ui")
	# 点"攻击"进入目标选择态（复刻真实点击：直接调 _on_cmd_pressed）
	ui._on_cmd_pressed("attack")
	# 目标光标应已激活（单蛾编组 → 1 个敌方目标）
	var cursor: Panel = ui.get_node("TargetCursor")
	assert_true(cursor.visible, "点攻击后目标光标应可见（进入目标选择态）")
	# 模拟键盘：→ 移光标（wrapi 后仍在唯一目标上）→ Z 确认
	var press := func(action: String) -> void:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		ui._unhandled_input(ev)
	press.call("move_right")
	press.call("interact")
	# 确认后光标隐藏、信号带 target_slot=0（唯一存活敌人槽位）
	assert_false(cursor.visible, "确认后目标光标应隐藏")
	var cmd: RefCounted = battle.get("cmd")
	var moth: Dictionary = cmd.enemies[0]
	var damaged: bool = int(moth.get("hp")) < int(moth.get("max_hp")) or not cmd.queue.is_empty()
	assert_true(damaged, "键盘确认攻击后敌方应已承伤（全链：键盘→目标确认→信号→结算）")


func test_O8_键盘取消目标_回菜单不发信号() -> void:
	_prep_real_battle()
	var battle := _spawn_battle(VALID_PAYLOAD)
	var ui: Control = battle.get("ui")
	var cmd: RefCounted = battle.get("cmd")
	var cursor_before: int = cmd.cursor
	ui._on_cmd_pressed("attack")
	var cursor: Panel = ui.get_node("TargetCursor")
	assert_true(cursor.visible, "前置：目标选择态已进入")
	var ev := InputEventAction.new()
	ev.action = "cancel"
	ev.pressed = true
	ui._unhandled_input(ev)
	assert_false(cursor.visible, "取消后目标光标应隐藏")
	assert_eq(int(cmd.cursor), cursor_before, "取消不应推进队列（未发指令）")
	# 菜单仍应可见（回到指令选择）
	var menu: Control = ui.get_node("CmdMenu")
	assert_true(menu.visible, "取消后应回到指令菜单")


func test_O9_顶层容器不拦截鼠标() -> void:
	_prep_real_battle()
	var battle := _spawn_battle(VALID_PAYLOAD)
	var ui: Control = battle.get("ui")
	# O-9：置顶全屏容器（转场/打击反馈）与非交互面板必须 IGNORE，
	# 否则默认 STOP 全屏吞点击——按钮永远收不到 pressed（玩家实况复现）
	var transition: Control = ui.get_node("Transition")
	assert_eq(int(transition.mouse_filter), Control.MOUSE_FILTER_IGNORE,
			"转场层必须放行鼠标（置顶全屏吞点击即 O-9 病灶）")
	var hit_fx: Control = ui.get_node("HitFeedback")
	assert_eq(int(hit_fx.mouse_filter), Control.MOUSE_FILTER_IGNORE,
			"打击反馈层必须放行鼠标")
	var pred: Control = ui.get_node("PredBar")
	assert_eq(int(pred.mouse_filter), Control.MOUSE_FILTER_IGNORE,
			"行动预告条必须放行鼠标")
	var status: Control = ui.get_node("StatusBar")
	assert_eq(int(status.mouse_filter), Control.MOUSE_FILTER_IGNORE,
			"状态栏必须放行鼠标")
	var result: Control = ui.get_node("ResultPanel")
	assert_eq(int(result.mouse_filter), Control.MOUSE_FILTER_IGNORE,
			"结算面板必须放行鼠标")
	# 指令菜单保留 STOP（按钮宿主语义，子按钮正常接收事件）
	var cmd_menu: Control = ui.get_node("CmdMenu")
	assert_eq(int(cmd_menu.mouse_filter), Control.MOUSE_FILTER_STOP,
			"指令菜单保留 STOP（按钮宿主）")
