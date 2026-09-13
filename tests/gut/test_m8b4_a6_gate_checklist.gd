extends GutTest
## M8-B4-A6 A 段收口 · checklist 补漏断言（提案 §七 [A] 项覆盖缺口）
##
## 【补漏对象】（对照 production/sprints/m8-b4-battle-vertical-slice-proposal.md
##   §七 checklist 逐项核对后的两个自动化缺口，详见 evidence/m8-b4-stage-a-gate.md）：
##   ① [A]"蓄力警示回合选择防御 → 释放伤害确认为未防御的一半（对照结算数字）"——
##     既有覆盖仅纯函数层（e3s2:469-472 incoming_damage_multiplier 四象限 +
##     e3s1:307 目录 power=2.5），缺"蓄力→防御→释放"组合链的数字对照断言。
##   ② [A]"B3 三敌胜利结算：所有行完整显示在面板内，无文字画出面板外"——
##     既有覆盖为合成协议数据（e6s2）与合成规模（A5 D10），缺真实 B3 编组
##     结算器输出 → 面板呈现的全链断言。
##
## 【无 RED 说明】本文件为覆盖缺口补断言（行为已存在且预期正确），非缺陷修复
##   ——按收口卡口径"缺漏的自动化项补断言"，无先证后修对象；若本文件跑红即
##   为新发现缺陷，须立即上报 team-lead。
##
## 【O-7 纪律】信号链驱动 + 状态断言；随机全注入确定性。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")

## Boss charge 权重带 roll（A1 口径：attack50/charge20/heavy30 → (0.50,0.70]）
const CHARGE_ROLL := 0.6

var _bc: BattleCommand = null
var _recv: Array = []


func before_each() -> void:
	_bc = null
	_recv = []


func after_each() -> void:
	if _bc != null and _bc.event_emitted.is_connected(_on_event):
		_bc.event_emitted.disconnect(_on_event)
	_bc = null


func _on_event(e: Dictionary) -> void:
	_recv.append(e)


func _party(levels: Array) -> Array:
	var out: Array = []
	var ids: Array = ["kyle", "lina", "mona"]
	for i: int in ids.size():
		out.append(BattleUnits.build_party_unit(String(ids[i]), int(levels[i])))
	return out


func _has_event(type: String) -> bool:
	for e: Dictionary in _recv:
		if String(e.get("type", "")) == type:
			return true
	return false


# ===== ① 蓄力→防御→释放 减半对照（checklist P0 第 2 项）=====

func test_A段收口_蓄力回合防御_释放伤害为未防御一半_对照真值() -> void:
	_bc = BattleCommand.new()
	_bc.setup("b5_core", _party([4, 4, 4]), BattleUnits.build_encounter("b5_core"))
	_bc.start()
	_bc.event_emitted.connect(_on_event)
	var ui := BattleUI.new()
	ui.bind(_bc)
	autofree(ui)
	var kyle: Dictionary = _bc.party[0]
	var boss_atk: int = int(_bc.enemies[0].get("atk", 0))
	var kyle_def: int = int(kyle.get("def", 0))
	# BattleLogic 真值对照基准（同公式同参数，仅防御倍率不同——预估伤害同款范式）
	var expected_full: int = BattleLogic.compute_physical_damage(boss_atk, kyle_def,
			2.5, 1.0, BattleLogic.incoming_damage_multiplier(false, false))
	var expected_defended: int = BattleLogic.compute_physical_damage(boss_atk, kyle_def,
			2.5, 1.0, BattleLogic.incoming_damage_multiplier(true, false))
	# 第 1 轮：三人普攻推进 → Boss 蓄力（A1 警示同时点亮，回归面）
	_bc.submit_command(_bc.party[0], {"type": "attack", "target_slot": 0}, 1.0)
	_bc.submit_command(_bc.current_actor(), {"type": "attack", "target_slot": 0}, 1.0)
	_bc.submit_command(_bc.current_actor(), {"type": "attack", "target_slot": 0}, 1.0)
	_bc.enemy_action(_bc.enemies[0], CHARGE_ROLL, 1.0)
	assert_true(_has_event("charge"), "前置：Boss 已蓄力（A1 警示链在位）")
	# 第 2 轮：凯尔防御（"蓄力警示回合选择防御"），其余推进 → Boss 必发释放
	_bc.submit_command(_bc.party[0], {"type": "defend"}, 1.0)
	_bc.submit_command(_bc.current_actor(), {"type": "attack", "target_slot": 0}, 1.0)
	_bc.submit_command(_bc.current_actor(), {"type": "attack", "target_slot": 0}, 1.0)
	_bc.enemy_action(_bc.enemies[0], 0.0, 1.0)   # ② 蓄力必发 release，roll 无关
	# 找释放伤害事件（damage + release:true + 目标凯尔）
	var release_amount: int = -1
	for e: Dictionary in _recv:
		if String(e.get("type", "")) == "damage" and bool(e.get("release", false)) \
				and String(e.get("side", "")) == BattleLogic.SIDE_PARTY \
				and int(e.get("slot", -1)) == 0:
			release_amount = int(e.get("amount", -1))
	assert_true(release_amount > 0, "前置：释放伤害事件已抵达（信号链）")
	assert_eq(release_amount, expected_defended,
			"防御态释放伤害应与 BattleLogic 真值一致（对照结算数字）")
	assert_true(absf(float(release_amount) - float(expected_full) / 2.0) <= 1.0,
			"释放伤害应为未防御的一半（整取容差 ±1：%d vs %d）" % [release_amount, expected_full])
	assert_lt(release_amount, expected_full, "减半方向守卫：防御态 < 未防御")


# ===== ② B3 三敌真实结算全链（checklist 归因可读项）=====

func test_A段收口_B3三敌真实结算_全部行显示且滚动可达() -> void:
	_bc = BattleCommand.new()
	_bc.setup("b3_ruin_mix", _party([2, 2, 2]), BattleUnits.build_encounter("b3_ruin_mix"))
	_bc.start()
	_bc.event_emitted.connect(_on_event)
	var ui := BattleUI.new()
	ui.bind(_bc)
	add_child_autofree(ui)
	# 真实胜利链：清场（events_append_damage 生产 emit 路径逐只致死）→
	# 提交防御指令触发 ③ _check_wipe → VICTORY + battle_over(_build_result)
	# → UI 自动 show_result（生产协议含 outcome/party_state/结算三区）
	for e: Dictionary in _bc.enemies:
		_bc.events_append_damage(e, 99999, BattleLogic.ELEMENT_NONE, false, {})
	_bc.submit_command(_bc.party[0], {"type": "defend"}, 1.0)
	assert_true(_bc.over and _bc.outcome == "VICTORY", "前置：B3 全灭胜利")
	assert_true(ui.is_result_visible(), "结算面板应已自动显示")
	ui.finish_reveal()   # 全部行立即弹出（确定性）
	await get_tree().process_frame
	await get_tree().process_frame
	var text: String = ui.get_result_text()
	assert_true(text.contains("胜利！"), "胜利文案应显示")
	# 行完整性：每个敌人名 / 升级行 / 掉落行均出现在结算文本中
	var s: Dictionary = _bc.build_settlement()   # 只取协议数据做对照（幂等纯函数）
	var exp_events: Array = s["exp_events"]
	var drops: Array = s["drops"]
	assert_true(exp_events.size() >= 6, "前置：B3 结算应有 exp/升级/习得多行（实得 %d）" % exp_events.size())
	assert_true(drops.size() >= 1, "前置：B3 应有掉落行")
	var seen_names: Dictionary = {}
	for ev: Variant in exp_events:
		var e: Dictionary = ev
		if String(e.get("kind", "")) == "exp":
			seen_names[String(e.get("enemy", ""))] = true
		if String(e.get("kind", "")) == "level_up":
			assert_true(text.contains("队伍 Lv"), "升级行应显示（队伍 Lv%d）" % int(e.get("level", 0)))
	for nm: String in seen_names.keys():
		assert_true(text.contains(nm), "击败行应显示敌人名：%s" % nm)
	assert_true(text.contains("获得"), "掉落行应显示")
	# 总行数 = 表头 2 + party 3 + 揭示行（exp+升级+习得+掉落），与协议逐行对表
	var expected_lines: int = 2 + 3 + exp_events.size() + drops.size()
	assert_eq(text.split("\n").size(), expected_lines,
			"结算文本行数应与协议数据一致（无行丢失）")
	# 无文字画出面板外：内容纳入滚动域可滚动到达（A5 D10 防御承接真实数据）
	assert_gt(ui.get_result_content_height(), ui.get_result_scroll_page(),
			"B3 长结算内容确实超出文本区（溢出为真，滚动承接）")
	assert_true(ui.get_result_scroll_max() >= ui.get_result_content_height() - 1.0,
			"全部 B3 结算行应纳入滚动域（可滚动到达）")
