extends Node
## _m7_balance_sim —— M7 E7-S1 B1-B3 内部数值调校模拟器
## 【临时调校工具，跑后可删】
##
## 用真实 BattleCommand + BattleUnits 跑 B1/B2/B3 三场，
## variance=1.0（中性，消除浮动干扰，便于数值分析），
## 打印每场的回合数、伤害明细、剩余 HP/MP，供调校判断。
##
## 两路策略：
##   NORMAL：正常玩（按教学意图打弱点、合理用技能/治疗）
##   BRAINDEAD：故意失误（全员防御，验证失败可达但不冤枉）

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const BattleLogic := preload("res://scripts/core/battle_logic.gd")


func _ready() -> void:
	_run("B1", "b1_moth", 1)
	_run("B2", "b2_beetles", 1)
	_run("B3", "b3_ruin_mix", 2)
	get_tree().quit()


func _run(label: String, encounter_id: String, level: int) -> void:
	print("\n" + "=".repeat(70))
	print("  %s  encounter=%s  party Lv%d" % [label, encounter_id, level])
	print("=" .repeat(70))

	# ---- 敌方预览 ----
	var enemies: Array[Dictionary] = BattleUnits.build_encounter(encounter_id)
	print("\n[敌方]")
	for e: Dictionary in enemies:
		print("  %s  HP=%d ATK=%d DEF=%d SPD=%d weak=%s resist=%s"
				% [e.name, e.hp, e.atk, e.def, e.spd, e.weakness, e.resist])

	# ---- NORMAL 路 ----
	print("\n── NORMAL（正常玩）──")
	_sim_normal(encounter_id, level)

	# ---- BRAINDEAD 路 ----
	print("\n── BRAINDEAD（全员防御）──")
	_sim_braindead(encounter_id, level)


# ------------------------------------------------------------------
# NORMAL：按教学意图最优解
# ------------------------------------------------------------------

func _sim_normal(encounter_id: String, level: int) -> void:
	var bc := BattleCommand.new()
	bc.setup(encounter_id, BattleUnits.build_party(level),
			BattleUnits.build_encounter(encounter_id))
	bc.start()

	var rounds: int = 0
	var guard: int = 0
	while not bc.over and guard < 60:
		guard += 1
		var actor: Dictionary = bc.current_actor()
		if actor.is_empty():
			break
		if bc.is_party_turn():
			var cmd: Dictionary = _normal_command(bc, actor)
			bc.submit_command(actor, cmd, 1.0)
		else:
			bc.enemy_action(actor, 0.5, 1.0)
		rounds = bc.round_num

	_print_result(bc, rounds)


func _normal_command(bc: BattleCommand, actor: Dictionary) -> Dictionary:
	var uid: String = String(actor.get("unit_id", ""))
	match uid:
		"kyle":
			# 重斩优先（B1 skills_locked 时不可用）
			if not bc.skills_locked and int(actor.get("mp", 0)) >= 6:
				return _skill(bc, "heavy_slash")
			return _attack(bc)
		"lina":
			# 打弱点：B3 火蜥弱冰 / 冰晶弱火 / 甲虫弱火；B1 飞蛾无相性
			var tgt: Dictionary = _weakest_enemy(bc)
			var weak: String = String(tgt.get("weakness", ""))
			if not bc.skills_locked:
				if weak == "ice" and int(actor.get("mp", 0)) >= 4:
					return _skill_to(bc, "ice_shard", int(tgt.get("slot", 0)))
				if weak == "fire" and int(actor.get("mp", 0)) >= 4:
					return _skill_to(bc, "fireball", int(tgt.get("slot", 0)))
				# 无弱点目标：火球兜底（B1 飞蛾无相性，火球也比普攻强）
				if int(actor.get("mp", 0)) >= 4:
					return _skill(bc, "fireball")
			return _attack(bc)
		"mona":
			# 血线低于 60% 治疗，否则普攻（正常玩不浪费 MP）
			var lowest: Dictionary = _lowest_hp_party(bc)
			if int(lowest.get("hp", 0)) < int(lowest.get("max_hp", 1)) * 0.6 \
					and int(actor.get("mp", 0)) >= 4:
				return {"type": BattleCommand.CMD_SKILL, "skill_id": "heal",
						"target_slot": int(lowest.get("slot", 0))}
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
	while not bc.over and guard < 200:
		guard += 1
		var actor: Dictionary = bc.current_actor()
		if actor.is_empty():
			break
		if bc.is_party_turn():
			bc.submit_command(actor, {"type": BattleCommand.CMD_DEFEND}, 1.0)
		else:
			bc.enemy_action(actor, 0.5, 1.0)
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
	# 校验目标仍存活
	var targets: Array[Dictionary] = bc.targets_for(cmd)
	for t: Dictionary in targets:
		if int(t.get("slot", -1)) == slot:
			return cmd
	return _skill(bc, skill_id)


func _weakest_enemy(bc: BattleCommand) -> Dictionary:
	# 优先打有弱点的敌人（教学意图），否则打第一个存活敌人
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


func _print_result(bc: BattleCommand, rounds: int) -> void:
	print("  结局: %s  | 回合数: %d" % [bc.outcome, rounds])
	print("  [我方剩余]")
	for u: Dictionary in bc.party:
		var alive: String = "✓" if BattleLogic.is_alive(u) else "✗"
		print("    %s %s  HP %d/%d  MP %d/%d"
				% [alive, u.name, int(u.get("hp", 0)), int(u.get("max_hp", 0)),
				int(u.get("mp", 0)), int(u.get("max_mp", 0))])
