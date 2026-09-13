extends GutTest
## M8-B4-A2 浮动数字动画化 + 自动回收（D4 P1"屏幕越打越脏"）
##
## 【缺陷正本】production/sprints/m8-b4-battle-vertical-slice-proposal.md §三 D4
##   + §四成功标准 3：浮动数字与"弱点！"弹字出现后永不消失、无动画，多轮战斗
##   残影堆积。证据：battle_ui.spawn_damage_number 只 add_child（无 tween/淡出/
##   回收）；battle_hit_feedback.spawn_weak_popup 同病。
##
## 【先证后修 · RED 靶点】残影永不清零：生成数字/弹字后等待超过任意合理生命
##   周期，两宿主层（battle_ui._float_layer / hit_fx._popup_layer）子节点数
##   不归零。
##
## 【O-7 纪律】信号链驱动（damage/weakness 事件 → _on_battle_event → 动画 →
##   回收）；断言观察量 = 两宿主层子节点数（状态）。回收依赖 Tween 逐帧处理，
##   故 UI 入场景树（add_child_autofree）+ await 真实帧推进——test_o7 已证
##   headless 下 create_timer/帧处理可用。
##
## 【存量断言撞车预排查结论】（回传正本，见 evidence md §3）
##   test_e3s4/e3s5 全部数字/弹字断言均在生成后【同步】执行（无 await），位于
##   动画生命周期内，节点在场 → 零撞车、零断言修改（"加强而非削弱"无须论证：
##   既有断言一字未动）。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")

## 等待上限 > 数字生命周期（0.35 上飘 + 0.30 淡出）与弹字生命周期
## （0.35 驻留 + 0.25 淡出），留足裕量
const WAIT_AFTER_LIFETIME := 1.2

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


## 战斗 UI 入场景树（回收依赖 Tween 帧处理，headless 须真在树上）
func _make_battle_in_tree() -> Control:
	_bc = BattleCommand.new()
	_bc.setup("b1_moth", _party(), BattleUnits.build_encounter("b1_moth"))
	_bc.start()
	var ui := BattleUI.new()
	ui.bind(_bc)
	add_child_autofree(ui)
	return ui


func _emit_damage(ui: Control, amount: int) -> void:
	_bc.event_emitted.emit({"type": "damage", "side": "enemy", "slot": 0,
			"amount": amount, "weak": false})


# ===== 用例 =====

func test_RED_浮动数字动画结束后自动回收_浮层归零() -> void:
	var ui := _make_battle_in_tree()
	_emit_damage(ui, 25)
	assert_eq(ui.get_float_count(), 1, "前置：数字已生成（生成路径既有行为）")
	await get_tree().create_timer(WAIT_AFTER_LIFETIME).timeout
	assert_eq(ui.get_float_count(), 0,
			"动画结束后浮动数字应自动回收，浮层归零（现状永不消失 → RED）")


func test_RED_弱点弹字动画结束后自动回收_弹字层归零() -> void:
	var backup: Array = (GameData.discovered_weakness_set as Array).duplicate()
	GameData.discovered_weakness_set = []
	var ui := _make_battle_in_tree()
	_bc.event_emitted.emit({"type": "weakness", "side": "enemy", "slot": 0,
			"element": "fire", "name": "飞蛾"})
	assert_eq(ui.get_weak_popup_count(), 1, "前置：弹字已生成（生成路径既有行为）")
	await get_tree().create_timer(WAIT_AFTER_LIFETIME).timeout
	assert_eq(ui.get_weak_popup_count(), 0,
			"动画结束后弱点弹字应自动回收，弹字层归零（现状永不消失 → RED）")
	GameData.discovered_weakness_set = backup


func test_多轮战斗后两宿主层归零_零残留() -> void:
	# 成功标准 3（提案 §四）：多轮战斗事件后 _float_layer 与 hit_fx 弹字层
	# 各自归零——"自动断言：战斗结束浮层子节点数归零"
	var backup: Array = (GameData.discovered_weakness_set as Array).duplicate()
	GameData.discovered_weakness_set = []
	var ui := _make_battle_in_tree()
	# 模拟 6 轮：每轮 2 次伤害数字 + 每 2 轮 1 次弱点弹字 = 12 数字 + 3 弹字
	for r: int in 6:
		_emit_damage(ui, 20 + r)
		_emit_damage(ui, 30 + r)
		if r % 2 == 0:
			_bc.event_emitted.emit({"type": "weakness", "side": "enemy",
					"slot": 0, "element": "fire", "name": "飞蛾"})
	assert_eq(ui.get_float_count(), 12, "前置：12 条数字在动画生命周期内全部在场")
	assert_eq(ui.get_weak_popup_count(), 3, "前置：3 条弹字在动画生命周期内全部在场")
	await get_tree().create_timer(WAIT_AFTER_LIFETIME).timeout
	assert_eq(ui.get_float_count(), 0, "battle_ui._float_layer 应归零（零残留）")
	assert_eq(ui.get_weak_popup_count(), 0, "hit_feedback._popup_layer 应归零（零残留）")
	GameData.discovered_weakness_set = backup
