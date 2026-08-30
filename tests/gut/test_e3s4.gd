extends GutTest
## E3-S4 战斗 UI 全套（EPIC-3 第 4 条 Story）
##
## 【断言覆盖】EPIC-3.md E3-S4 验收标准 + GDD §4 八要素：
##   ① §4 八要素逐项在场（战斗背景归 S5，不在此）；
##   ② 击退后预告条立即刷新；
##   ③ UI 全部在 640×360 内、9-slice 边条平铺不拉伸；
##   ④ 指令菜单置灰：攻击/防御永远可用、B1 锁技能、Boss 禁逃、空背包道具置灰；
##   ⑤ 预估伤害区间格式 "— 24~29 —" 且与 BattleLogic 真值一致；
##   ⑥ 浮动数字生成；⑦ 结算画面显示。
##
## 全部 headless 驱动 BattleUI（Control，不进场景树）。仅经公开查询方法断言，
## 不戳私有成员（兼顾封装与 GDScript headless 成员解析约束）。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")

func _party(ids: Array, levels: Array) -> Array:
	var out: Array[Dictionary] = []
	for i: int in ids.size():
		var u: Dictionary = BattleUnits.build_party_unit(String(ids[i]), int(levels[i]))
		if not u.is_empty():
			out.append(u)
	return out


# =============== ① §4 八要素逐项在场 ===============

func test_八要素逐项在场() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var ui := BattleUI.new()
	ui.bind(bc)
	assert_true(ui.has_pred_bar(), "§4.1 行动预告条")
	assert_true(ui.has_cmd_menu(), "§4.2 指令菜单")
	assert_true(ui.has_status_bar(), "§4.3 我方状态栏")
	assert_true(ui.has_enemy_layer(), "§4.4 敌方信息层")
	assert_true(ui.has_target_cursor(), "§4.5 目标光标")
	assert_true(ui.has_dmg_label(), "§4.5 预估伤害区间")
	assert_true(ui.has_float_layer(), "§4.6 浮动数字层")
	assert_true(ui.has_result_panel(), "§4.7 结算画面")
	# 子内容应已构建
	assert_true(ui.get_enemy_bar_count() >= 1, "§4.4 敌方 HP 条已构建")
	assert_eq(ui.get_status_card_count(), 3, "§4.3 三名角色状态卡")
	assert_eq(ui.get_prediction_slot_count(), 3, "§4.1 三格预告")


# =============== ② 击退后预告条立即刷新 ===============

func test_击退后预告条立即刷新() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	# 把敌方挪到预览窗口内（cursor 之后），便于观察刷新
	var q: Array[Dictionary] = BattleLogic.build_queue(bc.party, bc.enemies)
	var ei: int = -1
	for i: int in q.size():
		if String(q[i]["side"]) == BattleLogic.SIDE_ENEMY:
			ei = i
			break
	assert_ne(ei, -1, "应有敌方")
	var enemy_entry: Dictionary = q[ei]
	q.remove_at(ei)
	q.insert(1, enemy_entry)   # 敌方落到 index 1（cursor 0 之后）
	bc.queue = q
	bc.cursor = 0
	var ui := BattleUI.new()
	ui.bind(bc)
	var before: Array[String] = ui.get_prediction_names()
	# 对敌方施加击退
	var e: Dictionary = bc.queue[1]
	bc.queue = BattleLogic.apply_knockback(bc.queue, bc.cursor, String(e["side"]), int(e["slot"]))
	ui.refresh_prediction_bar()
	var after: Array[String] = ui.get_prediction_names()
	assert_ne(after, before, "击退后预告条顺序应立即刷新")
	assert_eq(after, _model_preview_names(bc), "UI 应与最新队列一致")


# =============== ③ 9-slice 边条平铺不拉伸 ===============

func test_9slice_边条平铺不拉伸() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var ui := BattleUI.new()
	ui.bind(bc)
	# 九宫格面板由 9+ 离散子块拼合（切分边距 8px 见 nine_slice_panel.gd MARGIN 常量）
	assert_true(ui.cmd_menu_patch_count() >= 9, "指令菜单九宫格由 9+ 离散子块拼合")
	assert_true(ui.status_bar_patch_count() >= 9, "状态栏九宫格")
	assert_true(ui.result_panel_patch_count() >= 9, "结算面板九宫格")
	# 全部落在 640×360 视口内
	assert_true(ui.size.x <= 640.0 and ui.size.y <= 360.0, "UI 不超出 640×360")


# =============== ④ 指令菜单置灰 ===============

func test_指令菜单_攻击防御永远可用() -> void:
	var bc := BattleCommand.new()
	bc.setup("b2_beetles", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b2_beetles"))
	bc.start()
	var ui := BattleUI.new()
	ui.bind(bc)
	assert_false(ui.is_command_disabled("attack"), "攻击永远可用")
	assert_false(ui.is_command_disabled("defend"), "防御永远可用")
	assert_false(ui.is_command_disabled("escape"), "b2 非 Boss，逃跑可用")
	assert_false(ui.is_command_disabled("skill"), "b2 未锁技能，技能可用")
	assert_true(ui.is_command_disabled("item"), "空背包，道具置灰")


func test_B1锁技能_技能按钮置灰() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	assert_true(bc.skills_locked, "B1 skills_locked 应为 true")
	var ui := BattleUI.new()
	ui.bind(bc)
	assert_true(ui.is_command_disabled("skill"), "B1 锁技能，技能按钮应置灰")


func test_Boss战_逃跑按钮置灰() -> void:
	var bc := BattleCommand.new()
	bc.setup("b5_core", _party(["kyle", "lina", "mona"], [4, 4, 4]), BattleUnits.build_encounter("b5_core"))
	bc.start()
	assert_true(bc.escape_forbidden, "Boss 战 escape_forbidden 应为 true")
	var ui := BattleUI.new()
	ui.bind(bc)
	assert_true(ui.is_command_disabled("escape"), "Boss 战逃跑应置灰")


# =============== ⑤ 预估伤害区间 ===============

func test_预估伤害区间格式() -> void:
	var ui := BattleUI.new()
	ui.ensure_built()
	assert_eq(ui.format_damage_range(Vector2i(24, 29)), "— 24~29 —", "§4.5 格式")


func test_predict_for_与真值一致() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var ui := BattleUI.new()
	ui.bind(bc)
	var actor: Dictionary = bc.current_actor()
	var enemy: Dictionary = bc.enemies[0]
	var r: Vector2i = ui.predict_for(actor, enemy, {"type": "attack"})
	var expect: Vector2i = BattleLogic.physical_damage_range(
			int(actor.get("atk", 1)), int(enemy.get("def", 0)), 1.0, 1.0)
	assert_eq(r, expect, "预估应与 BattleLogic 真值共用系数")


# =============== ⑥ 浮动数字 ===============

func test_浮动数字_生成() -> void:
	var ui := BattleUI.new()
	ui.ensure_built()
	ui.spawn_damage_number(Vector2(10, 10), 25, "weak")
	ui.spawn_damage_number(Vector2(40, 10), 12, "heal")
	assert_eq(ui.get_float_count(), 2, "应生成两个浮动数字")
	assert_eq(ui.get_float_text(0), "25", "弱点伤害数字文本")
	assert_eq(ui.get_float_text(1), "12", "回复数字文本")


# =============== ⑦ 结算画面 ===============

func test_结算画面_显示() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var ui := BattleUI.new()
	ui.bind(bc)
	ui.show_result({"outcome": "VICTORY",
			"party_state": [{"name": "凯尔", "hp": 50, "max_hp": 80, "mp": 10, "max_mp": 10}]})
	assert_true(ui.is_result_visible(), "结算面板应可见")
	assert_true(ui.get_result_text().contains("胜利"), "应显示胜利文案")


# =============== 辅助 ===============

func _model_preview_names(bc: BattleCommand) -> Array[String]:
	var out: Array[String] = []
	var prev: Array[Dictionary] = BattleLogic.preview(bc.queue, bc.cursor, 3)
	for e in prev:
		var u: Dictionary = BattleLogic.find_unit(bc.party, bc.enemies,
				String(e["side"]), int(e["slot"]))
		out.append(String(u.get("name", "")))
	return out
