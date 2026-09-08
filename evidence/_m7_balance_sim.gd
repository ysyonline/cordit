extends Node
## _m7_balance_sim —— M7 E7-S1 B1-B5 内部数值调校模拟器
## 【临时调校工具，跑后可删】
##
## 用真实 BattleCommand + BattleUnits 跑 B1-B5 五场，
## variance=1.0（中性，消除浮动干扰，便于数值分析），
## 打印每场的回合数、伤害明细、剩余 HP/MP，供调校判断。
##
## 两路策略：
##   NORMAL：正常玩（按教学意图打弱点、合理用技能/治疗/净化/掩护）
##   BRAINDEAD：全员防御（验证失败可达但不冤枉）
##
## 敌人 AI roll 用循环序列，确保每场都触发所有行为类型
## （B4: attack/poison/sweep；B5: attack/heavy_strike/charge→release）。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")

# 敌人 AI roll 循环序列（.tres 字典按字母序排列键，非插入序！）
# B4 字母序: attack(60) poison_strike(25) sweep(15)
#   roll 0.95→sweep, 0.6→poison, 0.3→attack
# B5 字母序: attack(50) charge(20) heavy_strike(30)
#   roll 0.95→heavy, 0.6→charge, 0.3→attack
const ENEMY_ROLLS := [0.95, 0.6, 0.3]


func _ready() -> void:
	_run("B1", "b1_moth", 1)
	_run("B2", "b2_beetles", 1)
	_run("B3", "b3_ruin_mix", 2)
	_run("B4", "b4_guardian", 3)
	_run("B5", "b5_core", 4)
	get_tree().quit()


func _run(label: String, encounter_id: String, level: int) -> void:
	print("\n" + "=".repeat(70))
	print("  %s  encounter=%s  party Lv%d" % [label, encounter_id, level])
	print("=" .repeat(70))

	# ---- 敌方预览 ----
	var enemies: Array[Dictionary] = BattleUnits.build_encounter(encounter_id)
	print("\n[敌方]")
	for e: Dictionary in enemies:
		print("  %s  HP=%d ATK=%d DEF=%d SPD=%d weak=%s"
				% [e.name, e.hp, e.atk, e.def, e.spd, e.weakness])

	# ---- NORMAL 路 ----
	print("\n── NORMAL（正常玩）──")
	_sim_normal(encounter_id, level)

	# ---- BRAINDEAD 路 ----
	print("\n── BRAINDEAD（全员防御）──")
	_sim_braindead(encounter_id, level)


# ------------------------------------------------------------------
# NORMAL：按教学意图最优解（净化/群愈/掩护/防御应对）
# ------------------------------------------------------------------

func _sim_normal(encounter_id: String, level: int) -> void:
	var bc := BattleCommand.new()
	bc.setup(encounter_id, BattleUnits.build_party(level),
			BattleUnits.build_encounter(encounter_id))
	bc.start()

	var rounds: int = 0
	var guard: int = 0
	var roll_idx: int = 0
	var enemy_actions: Array[String] = []
	while not bc.over and guard < 80:
		guard += 1
		var actor: Dictionary = bc.current_actor()
		if actor.is_empty():
			break
		if bc.is_party_turn():
			var cmd: Dictionary = _normal_command(bc, actor)
			bc.submit_command(actor, cmd, 1.0)
		else:
			var roll: float = ENEMY_ROLLS[roll_idx % ENEMY_ROLLS.size()]
			roll_idx += 1
			# 预判行为键（仅日志用）
			var ed: Variant = DataTables.get_enemy(String(actor.get("unit_id", "")))
			var pre_key: String = ""
			if ed != null:
				pre_key = _peek_weighted(ed.ai_weights, roll)
			bc.enemy_action(actor, roll, 1.0)
			enemy_actions.append(pre_key)
		rounds = bc.round_num

	print("  敌人行为序列: %s" % ", ".join(enemy_actions))
	_print_result(bc, rounds)


func _normal_command(bc: BattleCommand, actor: Dictionary) -> Dictionary:
	var uid: String = String(actor.get("unit_id", ""))
	match uid:
		"kyle":
			# 掩护：若有队友残血(<30%)且非自己，掩护该队友
			var lowest: Dictionary = _lowest_hp_party(bc)
			if not lowest.is_empty() and String(lowest.get("unit_id", "")) != "kyle" \
					and int(lowest.get("hp", 0)) < int(lowest.get("max_hp", 1)) * 0.3 \
					and not bc.skills_locked and int(actor.get("mp", 0)) >= 4:
				return _skill_to(bc, "cover", int(lowest.get("slot", 0)))
			# 重斩优先
			if not bc.skills_locked and int(actor.get("mp", 0)) >= 6:
				return _skill(bc, "heavy_slash")
			return _attack(bc)
		"lina":
			# 打弱点：B4 守卫弱雷（雷爆），B5 核心弱火（火球），B3 火蜥弱冰/冰晶弱火
			var tgt: Dictionary = _weakest_enemy(bc)
			var weak: String = String(tgt.get("weakness", ""))
			if not bc.skills_locked:
				if weak == "thunder" and int(actor.get("mp", 0)) >= 8:
					return _skill(bc, "thunder_burst")
				if weak == "ice" and int(actor.get("mp", 0)) >= 4:
					return _skill_to(bc, "ice_shard", int(tgt.get("slot", 0)))
				if weak == "fire" and int(actor.get("mp", 0)) >= 4:
					return _skill_to(bc, "fireball", int(tgt.get("slot", 0)))
				if int(actor.get("mp", 0)) >= 4:
					return _skill(bc, "fireball")
			return _attack(bc)
		"mona":
			# 净化优先：若有人中毒且 MP 够
			var poisoned: Dictionary = _poisoned_party(bc)
			if not poisoned.is_empty() and not bc.skills_locked \
					and int(actor.get("mp", 0)) >= 3:
				return _skill_to(bc, "cleanse", int(poisoned.get("slot", 0)))
			# 群愈：若 2 人以上 <60%
			var wounded: int = _count_wounded(bc, 0.6)
			if wounded >= 2 and not bc.skills_locked and int(actor.get("mp", 0)) >= 9:
				return _skill(bc, "group_heal")
			# 单体治疗：最低血量 <60%
			var lowest2: Dictionary = _lowest_hp_party(bc)
			if int(lowest2.get("hp", 0)) < int(lowest2.get("max_hp", 1)) * 0.6 \
					and int(actor.get("mp", 0)) >= 4:
				return _skill_to(bc, "heal", int(lowest2.get("slot", 0)))
			return _attack(bc)
	return _attack(bc)


# ------------------------------------------------------------------
# BRAINDEAD：全员防御（验证失败可达但不冤枉）
# ------------------------------------------------------------------

func _sim_braindead(encounter_id: String, level: int) -> void:
	var bc := BattleCommand.new()
	bc.setup(encounter_id, BattleUnits.build_party(level),
			BattleUnits.build_encounter(encounter_id))
	bc.start()

	var rounds: int = 0
	var guard: int = 0
	var roll_idx: int = 0
	while not bc.over and guard < 200:
		guard += 1
		var actor: Dictionary = bc.current_actor()
		if actor.is_empty():
			break
		if bc.is_party_turn():
			bc.submit_command(actor, {"type": BattleCommand.CMD_DEFEND}, 1.0)
		else:
			bc.enemy_action(actor, ENEMY_ROLLS[roll_idx % ENEMY_ROLLS.size()], 1.0)
			roll_idx += 1
		rounds = bc.round_num

	_print_result(bc, rounds)


# ------------------------------------------------------------------
# 辅助
# ------------------------------------------------------------------

func _attack(bc: BattleCommand) -> Dictionary:
	var targets: Array[Dictionary] = bc.targets_for({"type": BattleCommand.CMD_ATTACK})
	if targets.is_empty():
		return {"type": BattleCommand.CMD_DEFEND}
	return {"type": BattleCommand.CMD_ATTACK,
			"target_slot": int(targets[0].get("slot", 0))}


func _skill(bc: BattleCommand, skill_id: String) -> Dictionary:
	var cmd: Dictionary = {"type": BattleCommand.CMD_SKILL, "skill_id": skill_id}
	var targets: Array[Dictionary] = bc.targets_for(cmd)
	if targets.is_empty():
		return _attack(bc)
	cmd["target_slot"] = int(targets[0].get("slot", 0))
	return cmd


func _skill_to(bc: BattleCommand, skill_id: String, slot: int) -> Dictionary:
	var cmd: Dictionary = {"type": BattleCommand.CMD_SKILL, "skill_id": skill_id,
			"target_slot": slot}
	var targets: Array[Dictionary] = bc.targets_for(cmd)
	for t: Dictionary in targets:
		if int(t.get("slot", -1)) == slot:
			return cmd
	return _skill(bc, skill_id)


func _weakest_enemy(bc: BattleCommand) -> Dictionary:
	var targets: Array[Dictionary] = bc.targets_for({"type": BattleCommand.CMD_ATTACK})
	for t: Dictionary in targets:
		if not String(t.get("weakness", "")).is_empty():
			return t
	if targets.is_empty():
		return {}
	return targets[0]


func _lowest_hp_party(bc: BattleCommand) -> Dictionary:
	var lowest: Dictionary = {}
	var lowest_pct: float = 1.0
	for u: Dictionary in bc.party:
		if not BattleLogic.is_alive(u):
			continue
		var pct: float = float(u.get("hp", 0)) / float(u.get("max_hp", 1))
		if pct < lowest_pct:
			lowest_pct = pct
			lowest = u
	return lowest


func _poisoned_party(bc: BattleCommand) -> Dictionary:
	for u: Dictionary in bc.party:
		if BattleLogic.is_alive(u) and bool(u.get("poisoned", false)):
			return u
	return {}


func _count_wounded(bc: BattleCommand, threshold: float) -> int:
	var n: int = 0
	for u: Dictionary in bc.party:
		if not BattleLogic.is_alive(u):
			continue
		if float(u.get("hp", 0)) / float(u.get("max_hp", 1)) < threshold:
			n += 1
	return n


## 预判权重抽取结果（仅日志用，逻辑同 _weighted_pick）
func _peek_weighted(weights: Dictionary, roll: float) -> String:
	var total: int = 0
	for k: String in weights:
		total += int(weights[k])
	if total <= 0:
		return ""
	var threshold: float = roll * float(total)
	var acc: int = 0
	for k: String in weights:
		acc += int(weights[k])
		if float(acc) > threshold:
			return k
	return ""


func _print_result(bc: BattleCommand, rounds: int) -> void:
	print("  结局: %s  | 回合数: %d" % [bc.outcome, rounds])
	print("  [我方剩余]")
	for u: Dictionary in bc.party:
		var alive: String = "✓" if BattleLogic.is_alive(u) else "✗"
		print("    %s %s  HP %d/%d  MP %d/%d%s"
				% [alive, u.name, int(u.get("hp", 0)), int(u.get("max_hp", 0)),
				int(u.get("mp", 0)), int(u.get("max_mp", 0)),
				"  [毒]" if bool(u.get("poisoned", false)) else ""])
