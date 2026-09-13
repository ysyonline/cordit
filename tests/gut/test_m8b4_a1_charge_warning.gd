extends GutTest
## M8-B4-A1 敌方蓄力警示（横幅 + 敌方持续角标）
##
## 【缺陷正本】production/sprints/m8-b4-battle-vertical-slice-proposal.md §三 D1：
##   B5 Boss 蓄力（charge → 下拍释放倍率 2.5）在生产链存在，但 UI 零反应——
##   玩家"莫名其妙挨一记巨痛"，telegraph 机制在数据层存在、在玩家眼前不存在。
##
## 【先证后修 · RED 靶点】
##   ① charge 事件从未越过 event_emitted 信号边界——battle_command._emit_all
##     是空钩子（头注释自认"事件已在产生处逐一 emit"，但 _ev 系事件只 append
##     进返回数组、不 emit），event_emitted.emit 全文件仅 events_append_damage
##     内 3 处（damage/weakness/knockback）。UI 想消费也无从消费。
##   ② battle_ui._on_battle_event 只消费 damage/weakness，无横幅/角标响应。
##
## 【O-7 纪律】用例从真实信号链驱动：bc.enemy_action（生产唯一入口，
##   battle_scene.gd:138 同款调用）→ event_emitted → battle_ui._on_battle_event；
##   断言观察量 = 横幅可见性 / 角标点亮与清除的【状态】（非节点存在性）。
##
## 【隔离】headless 直驱 BattleCommand + BattleUI（test_e3s4 同款），不进生产
##   场景、不碰 GameData/存档；随机全部注入：roll_action=0.6 落 charge 权重带
##   （core.tres ai_weights = attack50/charge20/heavy30，累进带 (0.50,0.70]），
##   variance=1.0 中性，确定性断言，无 flaky 面。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")

## 落在 charge 权重带的确定性 roll（见头注释权重带推演）
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


func _party() -> Array:
	var out: Array = []
	for cid: String in ["kyle", "lina", "mona"]:
		out.append(BattleUnits.build_party_unit(cid, 4))
	return out


## 装配 B5 Boss 战 + 绑定 UI + 事件记录（装配口径与生产 battle_scene._ready 同构）
func _make_b5() -> Control:
	_bc = BattleCommand.new()
	_bc.setup("b5_core", _party(), BattleUnits.build_encounter("b5_core"))
	_bc.start()
	_bc.event_emitted.connect(_on_event)
	var ui := BattleUI.new()
	ui.bind(_bc)
	autofree(ui)
	return ui


func _boss() -> Dictionary:
	return _bc.enemies[0]


func _has_event(type: String) -> bool:
	for e: Dictionary in _recv:
		if String(e.get("type", "")) == type:
			return true
	return false


# ===== 用例 =====

func test_前置_roll注入确实命中charge权重带() -> void:
	_make_b5()
	# 防呆：roll=0.6 必须抽到 charge，否则后续用例前提崩塌（抽带口径见头注释）
	var evs: Array[Dictionary] = _bc.enemy_action(_boss(), CHARGE_ROLL, 1.0)
	var picked: String = ""
	for e: Dictionary in evs:
		if String(e.get("type", "")) == "ai":
			picked = String(e.get("action", ""))
	assert_eq(picked, "charge", "roll=0.6 应落在 charge 权重带")


func test_RED_charge事件应经event_emitted抵达UI侧() -> void:
	_make_b5()
	# 根因 RED：现状 charge 事件只进 enemy_action 返回值（生产场景弃用返回值），
	# 从不过信号——UI 订阅 event_emitted 永远收不到。
	_bc.enemy_action(_boss(), CHARGE_ROLL, 1.0)
	assert_true(_has_event("charge"),
			"charge 事件应经 event_emitted 抵达 UI（现状只进返回值不过信号 → RED）")


func test_蓄力横幅点亮带敌名_释放后清除() -> void:
	var ui := _make_b5()
	# 蓄力回合：横幅点亮 + 点名 Boss + 敌方 HP 条区持续角标点亮
	_bc.enemy_action(_boss(), CHARGE_ROLL, 1.0)
	assert_true(ui.is_charge_banner_visible(), "蓄力回合横幅应点亮（telegraph 预警）")
	assert_true(ui.get_charge_banner_text().contains("遗迹核心"), "横幅应点名蓄力敌人")
	assert_true(ui.is_enemy_charging(0), "蓄力中敌人的 HP 条区应点亮持续角标")
	# 下一拍释放（enemy_action ②：_charging 命中必发 release，telegraph 兑现）
	_bc.enemy_action(_boss(), 0.0, 1.0)
	assert_false(ui.is_charge_banner_visible(), "释放兑现后横幅应清除")
	assert_false(ui.is_enemy_charging(0), "释放兑现后角标应清除")


func test_蓄力者死亡后横幅角标清除() -> void:
	var ui := _make_b5()
	_bc.enemy_action(_boss(), CHARGE_ROLL, 1.0)
	assert_true(ui.is_charge_banner_visible(), "前置：横幅已点亮")
	assert_true(ui.is_enemy_charging(0), "前置：角标已点亮")
	# 未及释放即被击杀：致死伤害走生产事件链（events_append_damage 的 emit 路径）
	_bc.events_append_damage(_boss(), 99999, BattleLogic.ELEMENT_NONE, false, {})
	assert_false(ui.is_charge_banner_visible(), "蓄力者死亡后横幅应清除（残留即误导）")
	assert_false(ui.is_enemy_charging(0), "蓄力者死亡后角标应清除")
