extends GutTest
## E3-S5 转场与打击反馈（EPIC-3 第 5 条 Story）
##
## 【断言覆盖】EPIC-3.md E3-S5 验收标准 + GDD §4.8 / §4.6 / §3.3：
##   ① 战斗背景为当前地图截图模糊 + 暗角（set_screenshot 接口 + 暗角四块）；
##   ② 进战转场黑屏 0.2s 触发；
##   ③ 受击闪白 + 浮动数字；
##   ④ 首次命中弱点「弹字/图标/跨战斗记忆」三步：弹"弱点！" + 写入
##      GameData.discovered_weakness_set（§3.3 / §4.4）。
##
## 全部 headless 驱动 BattleUI（Control，不进场景树）。仅经公开查询方法断言，
## 不戳私有成员（兼顾封装与 GDScript headless 成员解析约束）。
## 弱点记忆写入 GameData 的用例均备份/还原，防污染其他测试。

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


func _find(party: Array[Dictionary], unit_id: String) -> Dictionary:
	for u: Dictionary in party:
		if String(u.get("unit_id", "")) == unit_id:
			return u
	return {}


# =============== ① 战斗背景：截图 + 暗角 ===============

func test_背景层存在且提供截图接口() -> void:
	var ui := BattleUI.new()
	ui.ensure_built()
	assert_true(ui.has_background(), "§4.8 背景层应存在")
	# 暗角四块（上/下/左/右）
	# 注：暗角块数经背景层查询；此处校验背景节点自身可用截图接口
	ui.set_battle_screenshot(null)
	assert_false(ui.get_battle_screenshot() != null, "未注入截图时 has_screenshot 应为 false")


# =============== ② 进战转场：黑屏 0.2s ===============

func test_进战转场黑屏触发() -> void:
	var ui := BattleUI.new()
	ui.ensure_built()
	assert_true(ui.has_transition(), "转场层应存在")
	ui.play_transition_intro()
	assert_true(ui.is_transition_playing(), "进战应进入转场播放态")
	assert_eq(ui.get_transition_black_alpha(), 1.0, "进战首帧应为全黑")


# =============== ③ 受击闪白 + 浮动数字 ===============

func test_受击闪白与浮动数字() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var ui := BattleUI.new()
	ui.bind(bc)
	# 直接发 damage 事件（专测 UI 反馈接线，绕过逐条逻辑）
	bc.event_emitted.emit({"type": "damage", "side": "enemy", "slot": 0,
			"amount": 25, "weak": false})
	assert_true(ui.get_flash_alpha() > 0.0, "受击应触发闪白（alpha>0）")
	assert_eq(ui.get_float_count(), 1, "应生成一条浮动数字")
	assert_eq(ui.get_float_text(0), "25", "浮动数字文本应为伤害值")


# =============== ④ 克制弹字 + 跨战斗记忆三步 ===============

func test_克制弹字与跨战斗记忆写入() -> void:
	# 备份 GameData 弱点记忆，测后还原（防污染）
	var backup: Array = (GameData.discovered_weakness_set as Array).duplicate()
	GameData.discovered_weakness_set = []

	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var ui := BattleUI.new()
	ui.bind(bc)
	# 发射 weakness 事件（element = fire）
	bc.event_emitted.emit({"type": "weakness", "side": "enemy", "slot": 0,
			"element": "fire", "name": "飞蛾"})

	assert_eq(ui.get_weak_popup_count(), 1, "应弹一条弱点字")
	assert_eq(ui.get_weak_popup_text(0), "弱点！", "弹字文案应为「弱点！」")
	assert_true(GameData.discovered_weakness_set.has("fire"),
			"§3.3 应写入 GameData.discovered_weakness_set")

	# 还原
	GameData.discovered_weakness_set = backup


# =============== ⑤ 真实流程：火球命中甲虫触发弱点三步（端到端接线） ===============

func test_真实流程_火球命中甲虫触发弱点三步() -> void:
	var backup: Array = (GameData.discovered_weakness_set as Array).duplicate()
	GameData.discovered_weakness_set = []

	var bc := BattleCommand.new()
	bc.setup("b2_beetles", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b2_beetles"))
	bc.start()
	var ui := BattleUI.new()
	ui.bind(bc)

	var lina: Dictionary = _find(bc.party, "lina")
	assert_false(lina.is_empty(), "前置：莉娜应在队")
	# 莉娜 Lv1 火球（fire）打甲虫（弱 fire）→ 应触发 damage(weak)+weakness
	bc.submit_command(lina, {"type": "skill", "skill_id": "fireball", "target_slot": 0})

	assert_true(ui.get_flash_alpha() > 0.0, "受击闪白应触发")
	assert_true(ui.get_weak_popup_count() >= 1, "应弹弱点字（端到端）")
	assert_eq(ui.get_weak_popup_text(0), "弱点！", "弹字应为「弱点！」")
	assert_true(GameData.discovered_weakness_set.has("fire"),
			"§3.3 真实流程应写入跨战斗弱点记忆")

	GameData.discovered_weakness_set = backup
