extends GutTest
## E3-S6 边缘情况 8 条全量实测（EPIC-3 第 6 条 Story）
##
## 【断言覆盖】GDD §3.6 边缘情况 1~8（原 7 条 + Sprint 3 新增"中毒致死"第 8 条）：
##   1. 队列中某单位在轮到它之前死亡：跳过其行动，队列即刻重算（prune）。
##   2. 当前行动者被"掩护"目标转移伤害致死：由掩护者承接，不中断行动结算。
##   3. 击退目标恰好只剩 1 个未行动槽位：击退按 2 槽计算但钳到本轮末尾（不跨轮）。
##   4. MP 不足时技能不可用（攻击/防御永远可用），防软锁。
##   5. 道具耗尽：可用道具为空、道具指令置灰。
##   6. 敌人被击退后、行动前死亡：从队列移除、其被跳过不产生结算。
##   7. 我方全灭发生在敌人行动结算途中：立即中断剩余行动，进入失败流程。
##   8. 中毒在行动前扣血致单位死亡：中断剩余结算、检查全灭、跳过该单位本回合行动。
##
## 全部 headless 驱动 BattleCommand（RefCounted，不进场景树）+ BattleLogic 纯函数，
## 经公开 API 与队列结构断言，不戳私有成员。

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


## 队列条目字典（apply_knockback 只读 side/slot）
func _qe(side: String, slot: int) -> Dictionary:
	return {"side": side, "slot": slot}


func _queue_has(queue: Array, side: String, slot: int) -> bool:
	return BattleLogic.find_entry_index(queue, side, slot) >= 0


# =============== 边缘 1：轮到前死亡 → 跳过 + 队列重算 ===============

func test_边缘1_死者在轮到前被跳过_队列移除() -> void:
	var bc := BattleCommand.new()
	bc.setup("b2_beetles", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b2_beetles"))
	bc.start()
	# beetle1 在轮到前就死（模拟早于其行动被击杀）
	bc.enemies[1]["hp"] = 0
	# 当前行动者（kyle）执行一次攻击，触发 _advance_and_check → 剔除死者
	var kyle: Dictionary = _find(bc.party, "kyle")
	bc.submit_command(kyle, {"type": "attack", "target_slot": 0})
	# beetle1 应从队列移除（其行动被跳过、不产生结算）
	assert_false(_queue_has(bc.queue, "enemy", 1), "边缘1：死者被移除出队列")
	var prev: Array[Dictionary] = BattleLogic.preview(bc.queue, bc.cursor, 3)
	var in_preview: bool = false
	for e in prev:
		if String(e["side"]) == "enemy" and int(e["slot"]) == 1:
			in_preview = true
	assert_false(in_preview, "边缘1：预告条不应含死者")


# =============== 边缘 2：掩护转移伤害由掩护者承接 ===============

func test_边缘2_掩护转移伤害由掩护者承接() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [3, 3, 3]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var kyle: Dictionary = _find(bc.party, "kyle")
	var mona: Dictionary = _find(bc.party, "mona")
	# kyle Lv3 掩护 mona（mona 为被掩护者）
	bc.submit_command(kyle, {"type": "skill", "skill_id": "cover", "target_slot": int(mona["slot"])})
	# kyle 设为低血量，使其承接伤害后致死
	kyle["hp"] = 3
	bc.party[int(kyle["slot"])] = kyle
	var mona_hp_before: int = int(mona["hp"])
	# 模拟敌人攻击 mona（应被转移给 kyle）
	var evs: Array = bc.events_append_damage(mona, 10, "none", false, {})
	# 被掩护者 mona 不应受击
	var mona_after: Dictionary = _find(bc.party, "mona")
	assert_eq(int(mona_after["hp"]), mona_hp_before, "边缘2：被掩护者未受击")
	# 掩护者 kyle 承接伤害（hp 下降或死亡）
	var kyle_after: Dictionary = _find(bc.party, "kyle")
	assert_true(int(kyle_after["hp"]) < int(kyle["hp"]) or not BattleLogic.is_alive(kyle_after),
			"边缘2：掩护者承接伤害")
	# 结算未中断：damage 事件记在掩护者（kyle）头上
	var transferred: bool = false
	for e in evs:
		if String(e["type"]) == "damage" and String(e["side"]) == "party" and int(e["slot"]) == int(kyle["slot"]):
			transferred = true
	assert_true(transferred, "边缘2：伤害事件记在掩护者（kyle）头上")


# =============== 边缘 3：击退只剩 1 个未行动槽位 → 钳到本轮末尾 ===============

func test_边缘3_击退钳到本轮末尾不跨轮() -> void:
	# 构造队列：cursor=0，目标在 idx1，其后仅 1 个未行动槽位（idx2=末尾）
	var q: Array[Dictionary] = [_qe("party", 0), _qe("enemy", 0), _qe("enemy", 1)]
	# 仅 1 个未行动槽位在目标之后 → 击退应钳到末尾 idx2（不跨轮）
	var out: Array[Dictionary] = BattleLogic.apply_knockback(q, 0, "enemy", 0)
	assert_eq(BattleLogic.find_entry_index(out, "enemy", 0), 2, "边缘3：击退钳到本轮末尾（idx=2）")
	assert_eq(out.size(), 3, "边缘3：不跨轮，队列长度不变")


# =============== 边缘 4：MP 不足技能不可用，攻击/防御永远可用 ===============

func test_边缘4_MP不足技能不可用_攻击防御可用() -> void:
	var bc := BattleCommand.new()
	bc.setup("b2_beetles", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b2_beetles"))
	bc.start()
	# kyle MP 清零
	var kyle: Dictionary = _find(bc.party, "kyle")
	kyle["mp"] = 0
	bc.party[int(kyle["slot"])] = kyle
	# MP=0 → 无可用技能（技能菜单因此全置灰）
	assert_eq(bc.available_skills(kyle).size(), 0, "边缘4：MP=0 时无可用技能")
	# 攻击 / 防御永远可用（防软锁）
	var cmds: Array[String] = bc.available_commands(kyle)
	assert_true(cmds.has("attack"), "边缘4：攻击永远可用")
	assert_true(cmds.has("defend"), "边缘4：防御永远可用")


# =============== 边缘 5：道具耗尽置灰 ===============

func test_边缘5_道具耗尽置灰() -> void:
	var bc := BattleCommand.new()
	bc.setup("b2_beetles", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b2_beetles"))
	bc.start()
	bc.set_inventory([])   # 空背包
	assert_eq(bc.available_items().size(), 0, "边缘5：空背包无可用道具")
	var ui := BattleUI.new()
	ui.bind(bc)
	assert_true(ui.is_command_disabled("item"), "边缘5：道具耗尽应置灰")


# =============== 边缘 6：击退后、行动前死亡 → 从队列移除、跳过结算 ===============

func test_边缘6_击退后死者在行动前被移除() -> void:
	var bc := BattleCommand.new()
	bc.setup("b2_beetles", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b2_beetles"))
	bc.start()
	# 若 beetle1 尚未行动，先击退它
	var idx1: int = BattleLogic.find_entry_index(bc.queue, "enemy", 1)
	if idx1 > bc.cursor:
		bc.queue = BattleLogic.apply_knockback(bc.queue, bc.cursor, "enemy", 1)
	# 行动前直接击杀 beetle1
	bc.enemies[1]["hp"] = 0
	# 当前行动者攻击 beetle0，触发推进与剔除
	var kyle: Dictionary = _find(bc.party, "kyle")
	bc.submit_command(kyle, {"type": "attack", "target_slot": 0})
	assert_false(_queue_has(bc.queue, "enemy", 1), "边缘6：击退后死亡的敌人被移除、不产生结算")


# =============== 边缘 7：我方全灭发生在敌方结算途中 → 中断进入失败 ===============

func test_边缘7_我方全灭在敌方结算途中中断() -> void:
	var bc := BattleCommand.new()
	var party := _party(["kyle", "lina", "mona"], [4, 4, 4])
	party[0]["hp"] = 0   # 已死
	party[1]["hp"] = 0   # 已死
	party[2]["hp"] = 1   # 唯一存活，1 HP
	bc.setup("b1_moth", party, BattleUnits.build_encounter("b1_moth"))
	bc.start()
	# 敌方行动：攻击唯一存活者（1 HP）应将其击杀 → 全灭
	var moth: Dictionary = bc.enemies[0]
	var evs: Array = bc.enemy_action(moth, 0.0, 1.0)
	assert_true(bc.over, "边缘7：结算途中全灭应结束战斗")
	assert_eq(bc.outcome, BattleCommand.OUTCOME_DEFEAT, "边缘7：应为失败结局")
	# 敌方行动确实发生了结算（产生了事件），但随后被中断
	assert_true(evs.size() > 0, "边缘7：敌方当次行动已结算")


# =============== 边缘 8：中毒行动前扣血致死 → 中断、检查全灭、跳过本回合 ===============

func test_边缘8_中毒行动前扣血致死跳过本回合() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var lina: Dictionary = _find(bc.party, "lina")
	# lina 中毒 1 回合，HP 恰好 = 毒伤（max_hp×5% 向下取整后），行动前即死
	var poison_dmg: int = BattleLogic.compute_poison_damage(int(lina["max_hp"]))
	lina["poison_turns"] = 1
	lina["hp"] = poison_dmg   # 中毒扣血即致死
	bc.party[int(lina["slot"])] = lina
	# lina 本回合行动（防御）：毒发应先于行动结算 → 死亡 → 跳过本回合
	var evs: Array = bc.submit_command(lina, {"type": "defend"})
	# lina 应已死亡（毒发），且未执行 defend（无 defend 事件）
	var lina_after: Dictionary = _find(bc.party, "lina")
	assert_false(BattleLogic.is_alive(lina_after), "边缘8：中毒致 lina 死亡")
	var did_defend: bool = false
	for e in evs:
		if String(e["type"]) == "defend" and int(e["slot"]) == int(lina["slot"]):
			did_defend = true
	assert_false(did_defend, "边缘8：死亡单位本回合行动被跳过（无 defend 结算）")
