extends GutTest
## M8-B4-A5 逃跑反馈（D7）+ 结算面板溢出防御（D10）——A 段收尾实现卡
##
## 【缺陷正本】m8-b4-battle-vertical-slice-proposal.md §三：
##   D7（P1）：escape_fail 事件无 UI 消费，点逃跑像没点；证据先证后修。
##   D10（P2）：B3 三敌结算 8-10 行 > 面板文本区 168px，"疑似"溢出——本卡
##   防御性修复（提案 §三 D10），零 .tscn 改动、全部 battle_ui.gd 代码内。
##
## 【先证后修 · RED 靶点】
##   ① escape_fail 不过信号：_ev("escape_fail") 只进 _do_escape 返回数组
##     （A1 勘误同根因），event_emitted 无此事件 → UI 永远无从响应。
##   ② D10 溢出现状实证：B3 规模长结算内容高 > 文本区高（168px）且无滚动域。
##
## 【O-7 / 纪律】信号链驱动 + 状态断言（提示在场/消退、滚动域覆盖内容高）；
##   逃跑确定性走 #15 forced_escape_roll 接缝（原样使用不破坏：roll=1.0 必败 /
##   0.0 必成）；UI 入场景树（提示淡出与 ScrollContainer 排序需帧推进）。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
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


func _make_battle_in_tree() -> Control:
	_bc = BattleCommand.new()
	_bc.setup("b1_moth", _party(), BattleUnits.build_encounter("b1_moth"))
	_bc.start()
	_bc.event_emitted.connect(_on_event)
	var ui := BattleUI.new()
	ui.bind(_bc)
	add_child_autofree(ui)
	return ui


func _has_event(type: String) -> bool:
	for e: Dictionary in _recv:
		if String(e.get("type", "")) == type:
			return true
	return false


## B3 规模长结算协议数据：表头 2 行 + party 3 行 + 8 exp + 升级 + 习得 + 2 掉落
func _long_result() -> Dictionary:
	var exp_events: Array = []
	for i: int in 8:
		exp_events.append({"kind": "exp", "enemy": "道路飞蛾", "amount": 20 + i})
	return {
		"outcome": "VICTORY",
		"party_state": [
			{"name": "凯尔", "hp": 200, "max_hp": 240, "mp": 20, "max_mp": 30},
			{"name": "莉娜", "hp": 160, "max_hp": 200, "mp": 15, "max_mp": 40},
			{"name": "莫娜", "hp": 180, "max_hp": 220, "mp": 25, "max_mp": 35},
		],
		"exp_events": exp_events,
		"level_up": [{"kind": "level_up", "name": "凯尔", "level": 5}],
		"skill": [{"kind": "skill", "name": "莉娜", "skills": ["ice_spike"]}],
		"drops": [
			{"item_id": "potion_s", "count": 1},
			{"item_id": "ether_s", "count": 2},
		],
	}


# ===== D7：逃跑反馈 =====

func test_RED_逃跑失败事件应经event_emitted抵达UI侧() -> void:
	_make_battle_in_tree()
	# #15 接缝原样使用：显式 roll=1.0（≥钳上限 95%）必败，b1_moth 非 Boss 可逃
	_bc.submit_command(_bc.current_actor(), {"type": "escape"}, 1.0, 1.0)
	assert_true(_has_event("escape_fail"),
			"escape_fail 事件应经 event_emitted 抵达 UI（现状只进返回值 → RED）")
	assert_false(_bc.over, "逃跑失败战斗应继续")


func test_RED_逃跑失败显式提示_自动消退不残留() -> void:
	var ui := _make_battle_in_tree()
	_bc.submit_command(_bc.current_actor(), {"type": "escape"}, 1.0, 1.0)
	assert_true(ui.has_escape_hint(), "逃跑失败应出现显式提示（现状无反应 → RED）")
	await get_tree().create_timer(1.0).timeout
	assert_false(ui.has_escape_hint(), "提示应自动消退不残留（A2 同纪律）")


func test_逃跑成功结算文本回归_敌人仍在原地徘徊() -> void:
	# 提案 §七锚点：结算明示"敌人仍在原地徘徊"既有文本不破坏（守卫用例）
	var ui := _make_battle_in_tree()
	_bc.submit_command(_bc.current_actor(), {"type": "escape"}, 1.0, 0.0)
	assert_true(_bc.over and _bc.outcome == "ESCAPE", "前置：逃跑成功（roll=0.0 必成）")
	assert_true(ui.is_result_visible(), "结算面板应可见")
	assert_true(ui.get_result_text().contains("敌人仍在原地徘徊"),
			"逃跑成功保留语义文本应原样保留")


# ===== D10：结算面板溢出防御 =====

func test_RED_长结算溢出防御_内容可滚动到达() -> void:
	var ui := _make_battle_in_tree()
	ui.show_result(_long_result())
	ui.finish_reveal()   # 全部行立即弹出（确定性，不依赖 dwell 计时）
	# 等两帧：Label 最小高变化 → ScrollContainer 延迟排序 → 滚动域就位
	await get_tree().process_frame
	await get_tree().process_frame
	# 溢出现状实证（提案 D10"疑似"→ 实证）：内容高 > 文本区高
	assert_gt(ui.get_result_content_height(), ui.get_result_scroll_page(),
			"B3 规模长结算内容确实超出面板文本区（现状溢出实证）")
	# 防御目标：内容完整纳入滚动域 → 全部行可滚动到达（提案 §四口径）
	assert_true(ui.get_result_scroll_max() >= ui.get_result_content_height() - 1.0,
			"全部结算行应纳入滚动域（可滚动到达 → RED：现状无滚动域）")
	# 语义不破坏：末行掉落文本仍在
	assert_true(ui.get_result_text().contains("获得"), "掉落行文本应保留")


func test_短结算无溢出_滚动域不越内容() -> void:
	# 防御不误伤：短结算（表头+party 1 行）内容 < 文本区，滚动域恰好容纳
	var ui := _make_battle_in_tree()
	ui.show_result({"outcome": "VICTORY",
		"party_state": [{"name": "凯尔", "hp": 200, "max_hp": 240, "mp": 20, "max_mp": 30}]})
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(ui.get_result_content_height() <= ui.get_result_scroll_page(),
			"短结算内容不应溢出")
	assert_true(ui.get_result_scroll_max() <= ui.get_result_content_height() + 1.0,
			"滚动域不应虚增（内容即边界）")
