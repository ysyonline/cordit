extends GutTest
## M8-B4-A4 死亡呈现（D6 P1："死人还站着"）
##
## 【缺陷正本】production/sprints/m8-b4-battle-vertical-slice-proposal.md §三 D6：
##   death 事件无 UI 反应——我方 hp=0 状态卡照常以存活态显示、敌方死后 HP 条
##   不消失，胜负信息模糊、队伍状态误读。
##
## 【先证后修 · RED 靶点】（A1 勘误同根因的延续）
##   ① death 类型事件不过信号：_ev("death") 两处产生点（submit_command 中毒
##     tick 致死 / enemy_action 中毒 tick 致死）只 append 进返回数组，而
##     event_emitted.emit 仅存在于 events_append_damage（damage/weakness/
##     knockback + A1 已接线的 charge）。伤害致死路径虽随 damage 事件携带
##     death=true 抵达，UI 侧亦无任何死亡呈现消费。
##   ② UI 无死亡态：refresh_status_bar 不判存活、refresh_enemy_bars 不跳过死者。
##
## 【呈现裁决】（回传留档）
##   - 我方卡：复用 menu_panel.gd C_GRAY(8E7F98) 同值置灰 + 名称"（倒下）"后缀
##     ——与探索侧菜单"死亡=置灰"语义同源不漂移。
##   - 敌方条：hp=0 隐藏（采纳派单建议）。理由：B 段 S10 死亡淡出动画直接吃
##     本卡语义（本卡定"死亡该是什么样"，S10 只加动画不换语义）；"隐藏"是比
##     "死亡标识"更强的终局语义（切片内无复活，死人从战场消失零误读），实现
##     代价两形态相同（一行 visible），按派单授权选语义更强者。
##
## 【O-7 纪律】信号链驱动（enemy_action / submit_command / events_append_damage
##   生产入口 → event_emitted → battle_ui._on_battle_event），断言观察量 =
##   卡灰化态 / 条隐藏的【状态】；随机全注入，确定性断言。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")

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


func _party() -> Array:
	var out: Array = []
	for cid: String in ["kyle", "lina", "mona"]:
		out.append(BattleUnits.build_party_unit(cid, 4))
	return out


func _make_battle(encounter_id: String) -> Control:
	_bc = BattleCommand.new()
	_bc.setup(encounter_id, _party(), BattleUnits.build_encounter(encounter_id))
	_bc.start()
	_bc.event_emitted.connect(_on_event)
	var ui := BattleUI.new()
	ui.bind(_bc)
	autofree(ui)
	return ui


func _has_event(type: String) -> bool:
	for e: Dictionary in _recv:
		if String(e.get("type", "")) == type:
			return true
	return false


# ===== 用例 =====

func test_RED_中毒致死事件应经event_emitted抵达UI侧() -> void:
	# 敌方中毒 tick 致死路径（enemy_action ①）：hp=1 + poison_turns=1，
	# 5% maxHP 中毒伤害（B5 Boss maxHP 600 → 30）必致死。
	_make_battle("b5_core")
	_bc.enemies[0]["poison_turns"] = 1
	_bc.enemies[0]["hp"] = 1
	_bc.enemy_action(_bc.enemies[0], 0.0, 1.0)
	assert_true(_has_event("death"),
			"death 事件应经 event_emitted 抵达 UI（现状只进返回值不过信号 → RED）")


func test_RED_我方阵亡状态卡灰化_其余存活不受影响() -> void:
	# 伤害致死路径（damage 事件自带 death=true，生产 emit 已在）：凯尔致死
	var ui := _make_battle("b1_moth")
	_bc.events_append_damage(_bc.party[0], 99999, BattleLogic.ELEMENT_NONE, false, {})
	assert_true(ui.is_party_down(0), "hp=0 状态卡应呈灰化倒下态（现状无死亡呈现 → RED）")
	assert_false(ui.is_party_down(1), "存活队友卡不应被误灰化")
	assert_false(ui.is_party_down(2), "存活队友卡不应被误灰化")


func test_RED_敌方阵亡血条隐藏() -> void:
	var ui := _make_battle("b5_core")
	_bc.events_append_damage(_bc.enemies[0], 99999, BattleLogic.ELEMENT_NONE, false, {})
	assert_true(ui.is_enemy_bar_hidden(0), "hp=0 敌方血条应隐藏（死人还站着 → RED）")


func test_我方中毒致死经信号驱动卡灰化() -> void:
	# 第二 death 产生点（submit_command ① 我方中毒 tick 致死）全链：致死 →
	# death 事件过信号 → 卡灰化（修复后此用例验证接线+呈现贯通）
	var ui := _make_battle("b1_moth")
	_bc.party[0]["poison_turns"] = 1
	_bc.party[0]["hp"] = 1
	_bc.submit_command(_bc.party[0], {"type": "attack", "target_slot": 0}, 1.0)
	assert_true(_has_event("death"), "我方中毒致死应发 death 事件过信号")
	assert_true(ui.is_party_down(0), "致死后状态卡应灰化倒下")
	assert_false(ui.is_party_down(1), "其余队友不受影响")


func test_A1回归_蓄力者死亡横幅角标仍清除且敌条隐藏() -> void:
	# A1 兜底（hp>0 守卫 + _any_alive_charging）与本卡敌条隐藏的交互回归
	var ui := _make_battle("b5_core")
	_bc.enemy_action(_bc.enemies[0], 0.6, 1.0)   # roll 落 charge 带（A1 口径）
	assert_true(ui.is_charge_banner_visible(), "前置：蓄力横幅已点亮")
	assert_true(ui.is_enemy_charging(0), "前置：蓄力角标已点亮")
	_bc.events_append_damage(_bc.enemies[0], 99999, BattleLogic.ELEMENT_NONE, false, {})
	assert_false(ui.is_charge_banner_visible(), "A1 回归：蓄力者死亡横幅应清除")
	assert_false(ui.is_enemy_charging(0), "A1 回归：蓄力者死亡角标应清除")
	assert_true(ui.is_enemy_bar_hidden(0), "本卡：蓄力者死亡敌条应隐藏")
