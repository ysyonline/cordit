extends GutTest
## M8-B4-A3 受击闪白分敌我（D5 P1"每次出手屏幕都闪"）
##
## 【缺陷正本】production/sprints/m8-b4-battle-vertical-slice-proposal.md §三 D5：
##   受击闪白是全屏的且不分敌我——我方攻击命中敌人时也全屏白闪，看多头晕且
##   分不清谁挨打。证据：_on_battle_event damage 分支对任何 damage 都
##   trigger_flash；闪白语义是"被打到了"（battle_hit_feedback.gd 头注释）。
##
## 【先证后修 · RED 靶点】我方攻击命中敌人（damage side=enemy）当前闪白；
##   期望不闪。敌打我方（side=party）闪白为回归守卫（现行为保留）。
##
## 【payload 归属字段确认】（派单要求先读实际代码，不凭猜）
##   damage 事件由 events_append_damage 构造，side/slot 写的是【受击目标】
##   的归属（battle_command.gd :590-592——掩护转移后亦随新 tgt 走），
##   SIDE_PARTY = "party"（battle_logic.gd :114）。payload 已含判据字段，
##   零 battle_command 改动，闸门收在视图层 _on_battle_event。
##
## 【O-7 纪律】信号链驱动（事件 → _on_battle_event → flash_alpha），断言
##   观察量 = flash_alpha 数值 / 闪白态；双向语义各自断言。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")

var _bc: BattleCommand = null


func before_each() -> void:
	_bc = null


func after_each() -> void:
	_bc = null


func _party() -> Array:
	var out: Array = []
	for cid: String in ["kyle", "lina", "mona"]:
		out.append(BattleUnits.build_party_unit(cid, 4))
	return out


func _make_battle(encounter_id: String = "b1_moth") -> Control:
	_bc = BattleCommand.new()
	_bc.setup(encounter_id, _party(), BattleUnits.build_encounter(encounter_id))
	_bc.start()
	var ui := BattleUI.new()
	ui.bind(_bc)
	autofree(ui)
	return ui


# ===== 用例 =====

func test_RED_我方攻击命中敌人不闪白_浮动数字仍生成() -> void:
	# RED：现状任何 damage 都闪。打敌人（side=enemy）应只出数字不闪白
	# （与 A2 回收机制正交：数字生成/回收不受本卡影响）
	var ui := _make_battle()
	_bc.event_emitted.emit({"type": "damage", "side": "enemy", "slot": 0,
			"amount": 25, "weak": false})
	assert_eq(ui.get_flash_alpha(), 0.0,
			"打敌人不应闪白（闪白语义=我方被打到了；现状全闪 → RED）")
	assert_eq(ui.get_float_count(), 1, "打敌人浮动数字照常生成（A2 不受影响）")


func test_敌人打我方仍闪白_回归守卫() -> void:
	# 现行为保留：我方受击（side=party）闪白不回退
	var ui := _make_battle()
	_bc.event_emitted.emit({"type": "damage", "side": "party", "slot": 0,
			"amount": 18, "weak": false})
	assert_true(ui.get_flash_alpha() > 0.0, "我方受击应闪白（语义正本）")
	assert_eq(ui.get_float_count(), 1, "我方受击浮动数字照常生成")


func test_端到端_我方攻击不闪_敌方行动闪白() -> void:
	# 真实生产链双向验证。用 b5_core（Boss HP 600）保证三拍我方攻击后敌人
	# 存活、队列推进到敌方回合（b1_moth 单蛾一拍即死，战斗提前终结）：
	# ① 凯尔攻击 Boss（damage side=enemy）→ 不闪
	var ui := _make_battle("b5_core")
	_bc.submit_command(_bc.party[0], {"type": "attack", "target_slot": 0}, 1.0)
	assert_eq(ui.get_flash_alpha(), 0.0, "端到端：我方出手命中敌人不闪白")
	# ② 推进到敌方回合（凯/莫/莉三拍），Boss 普攻（damage side=party）→ 闪
	#    （attack 权重带 roll∈[0,0.5)，注入 0.0 确定性；variance 1.0）
	var guard: int = 0
	while _bc.is_party_turn() and not _bc.over and guard < 6:
		guard += 1
		var actor: Dictionary = _bc.current_actor()
		_bc.submit_command(actor, {"type": "attack", "target_slot": 0}, 1.0)
	assert_false(_bc.is_party_turn() or _bc.over, "前置：已推进到敌方回合")
	_bc.enemy_action(_bc.enemies[0], 0.0, 1.0)
	assert_true(ui.get_flash_alpha() > 0.0, "端到端：敌人打我方应闪白")
