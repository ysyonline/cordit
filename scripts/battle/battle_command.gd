extends RefCounted
## BattleCommand —— 指令状态机（E3-S3，回合流程编排层）
##
## 【定位】battle_logic.gd 是纯算法层（无状态、无随机）；本文件是【编排层】
##   ——持有战斗状态、驱动"菜单→目标→结算→队列推进"、处理四指令 / 三结局 /
##   逃跑 / 边缘情况 / 敌人 AI。设计成 RefCounted（非 Node）：headless 可测，
##   UI（E3-S4）只是它的渲染 / 输入外壳，不污染算法可测性（A1 铁律 3 精神）。
##
## 【随机外部化】伤害浮动 variance、逃跑检定 roll、敌人 AI 权重抽取 roll 均
##   由调用方注入（缺省用中性 1.0 / randf()），保持单测可确定性断言。
##
## 【信号】UI 订阅 event_emitted 渲染逐条；battle_over 由战斗场景消费，
##   组装 BattleResult 发 EventBus.battle_finished（读档占位在 E2-S4 已接好）。
##
## 【正本】design/gdd/battle-system-gdd.md §3.1~§3.6、EPIC-3.md E3-S3。

const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")

# 指令类型
const CMD_ATTACK := "attack"
const CMD_SKILL := "skill"
const CMD_ITEM := "item"
const CMD_DEFEND := "defend"
const CMD_ESCAPE := "escape"

# 结局
const OUTCOME_VICTORY := "VICTORY"
const OUTCOME_DEFEAT := "DEFEAT"
const OUTCOME_ESCAPE := "ESCAPE"

# 事件类型（event_emitted 的 type 字段）
# damage / heal / poison / defend / escape_fail / escape_success / weakness
# knockback / skill / item / death / ai / charge / charge_release / cover

signal event_emitted(event: Dictionary)
signal battle_over(result: Dictionary)

# ==================================================================
# 战斗状态
# ==================================================================
var encounter_id: String = ""
var party: Array[Dictionary] = []      # 我方单位（unit dict，含 level）
var enemies: Array[Dictionary] = []    # 敌方单位
var queue: Array[Dictionary] = []
var cursor: int = 0
var round_num: int = 1
var outcome: String = ""
var over: bool = false
var skills_locked: bool = false
var escape_forbidden: bool = false
var discovered_weakness: Array[String] = []   # 跨战斗弱点记忆（外部注入 / 读出）
var _charging: Dictionary = {}                 # 敌方 slot -> true（蓄力待发）
var _cover_map: Dictionary = {}                 # 被掩护者 slot -> 掩护者 slot（我方）
var _inventory: Array[Dictionary] = []          # [{"item_id":String,"count":int}] 外部注入

# ==================================================================
# 初始化 / 开局
# ==================================================================

## 注入背包（道具指令可用性由它决定；A5 战斗侧不感知背包结构，故显式传入）
func set_inventory(inv: Array) -> void:
	# inv 可能为未类型化的空数组（如测试注入 []），duplicate 返回 Array 与
	# 成员类型 Array[Dictionary] 不匹配，需逐元素重建为类型化数组。
	_inventory = []
	for it in inv:
		_inventory.append(it)


## 装配一场战斗（p_party / p_enemies 为 unit dict 数组，建议由 BattleUnits 构建）
func setup(p_encounter_id: String, p_party: Array, p_enemies: Array) -> void:
	encounter_id = p_encounter_id
	party = p_party.duplicate(true)
	enemies = p_enemies.duplicate(true)
	var grp: Variant = DataTables.get_encounter(p_encounter_id)
	skills_locked = grp.skills_locked if grp != null else false
	escape_forbidden = BattleUnits.is_escape_forbidden(p_encounter_id)
	_charging = {}
	_cover_map = {}


## 开局：构建首轮队列，cursor 归零
func start() -> void:
	queue = BattleLogic.build_queue(party, enemies)
	cursor = 0
	round_num = 1
	outcome = ""
	over = false


# ==================================================================
# 单位查询 / 当前行动者
# ==================================================================

func _unit(side: String, slot: int) -> Dictionary:
	return BattleLogic.find_unit(party, enemies, side, slot)


## 用新单位替换数组里同 side/slot 的单位（状态层负责写回；纯函数层出参不修改入参）
func _replace_unit(new_unit: Dictionary) -> void:
	var side: String = String(new_unit.get("side", ""))
	var slot: int = int(new_unit.get("slot", -1))
	var list: Array[Dictionary] = party if side == BattleLogic.SIDE_PARTY else enemies
	for i: int in list.size():
		if int(list[i].get("slot", -1)) == slot:
			list[i] = new_unit
			return


func current_entry() -> Dictionary:
	if cursor < 0 or cursor >= queue.size():
		return {}
	return queue[cursor]


func current_actor() -> Dictionary:
	var e: Dictionary = current_entry()
	if e.is_empty():
		return {}
	return _unit(String(e["side"]), int(e["slot"]))


func is_party_turn() -> bool:
	var e: Dictionary = current_entry()
	if e.is_empty():
		return false
	return String(e["side"]) == BattleLogic.SIDE_PARTY


# ==================================================================
# 可用指令 / 技能 / 道具 / 目标（供 UI 菜单与 GUT 断言）
# ==================================================================

## 当前行动者可下的指令列表（§3.6 边缘 4：攻击/防御永远可用防软锁）
func available_commands(actor: Dictionary) -> Array[String]:
	var cmds: Array[String] = [CMD_ATTACK, CMD_DEFEND]
	if not skills_locked:
		cmds.append(CMD_SKILL)
	if not _inventory.is_empty():
		cmds.append(CMD_ITEM)
	if not escape_forbidden:
		cmds.append(CMD_ESCAPE)
	return cmds


## 角色按 level 习得且 mp 足够的技能（SkillData 列表）
func available_skills(actor: Dictionary) -> Array:
	var out: Array = []
	var cid: String = String(actor.get("unit_id", ""))
	var cd: Variant = DataTables.get_character(cid)
	if cd == null:
		return out
	var lv: int = int(actor.get("level", 1))
	var learned: Array[String] = []
	for lvl in cd.skills_by_level:
		if int(lvl) <= lv:
			for sid: String in cd.skills_by_level[lvl]:
				learned.append(sid)
	for sid: String in learned:
		var sk: Variant = DataTables.get_skill(sid)
		if sk != null and int(actor.get("mp", 0)) >= sk.mp_cost:
			out.append(sk)
	return out


## 战斗内可用道具（背包里 count>0 且战斗可用）
func available_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in _inventory:
		if int(entry.get("count", 0)) > 0:
			var item: Variant = DataTables.get_item(String(entry.get("item_id", "")))
			if item != null and item.usable_in_battle():
				out.append(entry)
	return out


## 某指令的合法目标列表（unit dict 数组）
func targets_for(command: Dictionary) -> Array[Dictionary]:
	var kind: String = String(command.get("type", ""))
	var skill: Variant = null
	if kind == CMD_SKILL:
		skill = DataTables.get_skill(String(command.get("skill_id", "")))
	match kind:
		CMD_ATTACK:
			return _alive(enemies)
		CMD_ITEM:
			return _alive(party)
		CMD_DEFEND:
			return []
		CMD_ESCAPE:
			return []
		CMD_SKILL:
			if skill == null:
				return []
			match String(skill.target):
				"enemy_single":
					return _alive(enemies)
				"enemy_all":
					return _alive(enemies)
				"ally_single":
					return _alive(party)
				"ally_all":
					return _alive(party)
	return []


func _alive(list: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in list:
		if BattleLogic.is_alive(u):
			out.append(u)
	return out


# ==================================================================
# 玩家提交指令（核心驱动入口）
# ==================================================================

## 执行当前行动者的一次指令，返回事件流（供 UI 渲染 / GUT 断言）。
## variance：伤害浮动系数（默认 1.0 中性）；roll：逃跑检定随机 [0,1)（默认 randf）。
## 流程：① 行动前中毒 tick（边缘 8）② 执行指令 ③ 检查胜负 ④ 推进队列。
func submit_command(actor: Dictionary, command: Dictionary,
		variance: float = BattleLogic.NEUTRAL_VARIANCE, roll: float = -1.0) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if over:
		return events

	# ① 行动前中毒结算（§3.6 边缘 8：中毒致死立即中断本回合行动）
	var poison := BattleLogic.tick_poison(actor)
	actor = poison["unit"]
	_replace_unit(actor)
	if int(poison.get("damage", 0)) > 0:
		events.append(_ev("poison", actor, {"amount": int(poison["damage"])}))
		if not BattleLogic.is_alive(actor):
			events.append(_ev("death", actor, {}))
			if _check_wipe():
				_emit_all(events)
				return events
			_advance_and_check()
			_emit_all(events)
			return events

	# ② 执行指令
	match String(command.get("type", "")):
		CMD_ATTACK:
			events.append_array(_do_attack(actor, command, variance))
		CMD_SKILL:
			events.append_array(_do_skill(actor, command, variance))
		CMD_ITEM:
			events.append_array(_do_item(actor, command))
		CMD_DEFEND:
			events.append_array(_do_defend(actor))
		CMD_ESCAPE:
			events.append_array(_do_escape(actor, roll))
		_:
			push_warning("[BattleCommand] 未知指令类型：%s" % command.get("type", "<空>"))

	# ③ 胜负检查（全灭途中中断，§3.6 边缘 7）
	if _check_wipe():
		_emit_all(events)
		return events

	# ④ 推进队列
	_advance_and_check()
	_emit_all(events)
	return events


# ==================================================================
# 指令实现
# ==================================================================

func _do_attack(actor: Dictionary, command: Dictionary, variance: float) -> Array[Dictionary]:
	var tgt: Dictionary = _unit(BattleLogic.SIDE_ENEMY, int(command.get("target_slot", -1)))
	if tgt.is_empty() or not BattleLogic.is_alive(tgt):
		return []
	var dmg: int = BattleLogic.compute_physical_damage(
		int(actor.get("atk", 1)), int(tgt.get("def", 0)), 1.0, variance,
		BattleLogic.incoming_damage_multiplier(bool(tgt.get("defending", false)), bool(tgt.get("covering", false))))
	return events_append_damage(tgt, dmg, BattleLogic.ELEMENT_NONE, false,
		{"name": String(actor.get("name", ""))})


func _do_skill(actor: Dictionary, command: Dictionary, variance: float) -> Array[Dictionary]:
	var sk: Variant = DataTables.get_skill(String(command.get("skill_id", "")))
	if sk == null:
		return []
	if int(actor.get("mp", 0)) < sk.mp_cost:
		return []   # 防软锁之外的非法调用，直接忽略
	actor["mp"] = maxi(0, int(actor.get("mp", 0)) - sk.mp_cost)
	_replace_unit(actor)
	var events: Array[Dictionary] = [_ev("skill", actor, {"skill": sk.id, "name": sk.name})]

	match String(sk.kind):
		"physical", "magic":
			var targets: Array[Dictionary] = targets_for({"type": CMD_SKILL, "skill_id": sk.id})
			for tgt: Dictionary in targets:
				var dmg: int
				if String(sk.kind) == "physical":
					dmg = BattleLogic.compute_physical_damage(int(actor.get("atk", 1)),
						int(tgt.get("def", 0)), sk.power, variance,
						BattleLogic.incoming_damage_multiplier(bool(tgt.get("defending", false)), bool(tgt.get("covering", false))))
				else:
					dmg = BattleLogic.compute_magic_damage(int(actor.get("mag", 1)),
						int(tgt.get("def", 0)), sk.power, sk.element,
						String(tgt.get("weakness", "")), String(tgt.get("resist", "")), variance,
						BattleLogic.incoming_damage_multiplier(bool(tgt.get("defending", false)), bool(tgt.get("covering", false))))
				events.append_array(events_append_damage(tgt, dmg, sk.element,
					BattleLogic.is_weakness_hit(sk.element, String(tgt.get("weakness", ""))),
					{"name": String(actor.get("name", "")), "skill": sk.name}))
		"heal":
			var targets: Array[Dictionary] = targets_for({"type": CMD_SKILL, "skill_id": sk.id})
			for tgt: Dictionary in targets:
				var amt: int = BattleLogic.compute_heal(int(actor.get("mag", 1)), sk.power)
				tgt = BattleLogic.heal_unit(tgt, amt)
				_replace_unit(tgt)
				events.append(_ev("heal", tgt, {"amount": amt, "name": String(actor.get("name", ""))}))
		"utility":
			if String(sk.effect_tag) == "cover":
				var tgt_slot: int = int(command.get("target_slot", int(actor.get("slot", -1))))
				actor["covering"] = true
				_replace_unit(actor)
				if tgt_slot != int(actor.get("slot", -1)):
					_cover_map[tgt_slot] = int(actor.get("slot", -1))
				events.append(_ev("cover", actor, {"target_slot": tgt_slot}))
			elif String(sk.effect_tag) == "detox":
				var tgt_slot: int = int(command.get("target_slot", int(actor.get("slot", -1))))
				var tgt: Dictionary = _unit(BattleLogic.SIDE_PARTY, tgt_slot)
				if not tgt.is_empty():
					tgt["poison_turns"] = 0
					_replace_unit(tgt)
					events.append(_ev("item", tgt, {"effect": "detox", "name": String(actor.get("name", ""))}))
	return events


func _do_item(actor: Dictionary, command: Dictionary) -> Array[Dictionary]:
	var item_id: String = String(command.get("item_id", ""))
	var item: Variant = DataTables.get_item(item_id)
	if item == null or not item.usable_in_battle():
		return []
	var found := false
	for entry: Dictionary in _inventory:
		if String(entry.get("item_id", "")) == item_id and int(entry.get("count", 0)) > 0:
			entry["count"] = int(entry.get("count", 0)) - 1
			found = true
			break
	if not found:
		return []   # 道具耗尽（§3.6 边缘 5：菜单应可取消返回，这里忽略非法调用）
	var tgt_slot: int = int(command.get("target_slot", int(actor.get("slot", -1))))
	var tgt: Dictionary = _unit(BattleLogic.SIDE_PARTY, tgt_slot)
	if tgt.is_empty():
		return []
	var events: Array[Dictionary] = []
	match String(item.kind):
		"heal_hp":
			tgt = BattleLogic.heal_unit(tgt, item.value)
			_replace_unit(tgt)
			events.append(_ev("heal", tgt, {"amount": item.value, "item": item.name}))
		"heal_mp":
			tgt["mp"] = mini(int(tgt.get("max_mp", 0)), int(tgt.get("mp", 0)) + item.value)
			_replace_unit(tgt)
			events.append(_ev("heal", tgt, {"amount": item.value, "item": item.name, "mp": true}))
		"detox":
			tgt["poison_turns"] = 0
			_replace_unit(tgt)
			events.append(_ev("item", tgt, {"effect": "detox", "item": item.name}))
	return events


func _do_defend(actor: Dictionary) -> Array[Dictionary]:
	var res: Dictionary = BattleLogic.apply_defend(actor)
	actor = res["unit"]
	_replace_unit(actor)
	return [_ev("defend", actor, {"mp_recovered": int(res.get("mp_recovered", 0))})]


func _do_escape(actor: Dictionary, roll: float) -> Array[Dictionary]:
	var r: float = roll if roll >= 0.0 else randf()
	if BattleLogic.escape_success(party, enemies, r):
		over = true
		outcome = OUTCOME_ESCAPE
		battle_over.emit(_build_result())
		return [_ev("escape_success", actor, {})]
	return [_ev("escape_fail", actor, {})]


# ==================================================================
# 敌人 AI（自动行动）
# ==================================================================

## 敌人行动者自动行动。roll_action 用于权重抽取（缺省 randf）；variance 伤害浮动。
## 处理蓄力 / 释放标记（§5 charge/charge_release）与中毒附加。
func enemy_action(actor: Dictionary, roll_action: float = -1.0,
		variance: float = BattleLogic.NEUTRAL_VARIANCE) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if over:
		return events

	# ① 行动前中毒 tick（边缘 8）
	var poison := BattleLogic.tick_poison(actor)
	actor = poison["unit"]
	_replace_unit(actor)
	if int(poison.get("damage", 0)) > 0:
		events.append(_ev("poison", actor, {"amount": int(poison["damage"])}))
		if not BattleLogic.is_alive(actor):
			events.append(_ev("death", actor, {}))
			if _check_wipe():
				_emit_all(events)
				return events
			_advance_and_check()
			_emit_all(events)
			return events

	# ② 蓄力后必发 charge_release（telegraph 兑现）
	var slot: int = int(actor.get("slot", -1))
	if _charging.has(slot) and _charging[slot]:
		_charging[slot] = false
		events.append_array(_enemy_release(actor, variance))
		if _check_wipe():
			_emit_all(events)
			return events
		_advance_and_check()
		_emit_all(events)
		return events

	# ③ 按权重抽行为键
	var ed: Variant = DataTables.get_enemy(String(actor.get("unit_id", "")))
	if ed == null:
		return events
	var action_key: String = _weighted_pick(ed.ai_weights, roll_action)
	var entry: Dictionary = DataTables.ACTION_CATALOG.get_action(action_key)
	if entry.is_empty():
		return events

	events.append(_ev("ai", actor, {"action": action_key}))
	match action_key:
		"attack":
			events.append_array(_enemy_hit(actor, entry, variance, false))
		"poison_strike":
			events.append_array(_enemy_hit(actor, entry, variance, true))
		"sweep":
			events.append_array(_enemy_sweep(actor, entry, variance))
		"heavy_strike":
			events.append_array(_enemy_hit(actor, entry, variance, false))
		"charge":
			_charging[slot] = true
			events.append(_ev("charge", actor, {}))

	if _check_wipe():
		_emit_all(events)
		return events
	_advance_and_check()
	_emit_all(events)
	return events


func _enemy_release(actor: Dictionary, variance: float) -> Array[Dictionary]:
	var entry: Dictionary = DataTables.ACTION_CATALOG.get_action("charge_release")
	var tgt: Dictionary = _first_alive_party()
	if tgt.is_empty():
		return []
	var dmg: int = BattleLogic.compute_physical_damage(int(actor.get("atk", 1)),
		int(tgt.get("def", 0)), float(entry.get("power", 1.0)), variance,
		BattleLogic.incoming_damage_multiplier(bool(tgt.get("defending", false)), bool(tgt.get("covering", false))))
	return events_append_damage(tgt, dmg, BattleLogic.ELEMENT_NONE, false,
		{"name": String(actor.get("name", "")), "release": true})


func _enemy_hit(actor: Dictionary, entry: Dictionary, variance: float, applies_poison: bool) -> Array[Dictionary]:
	var tgt: Dictionary = _first_alive_party()
	if tgt.is_empty():
		return []
	var dmg: int = BattleLogic.compute_physical_damage(int(actor.get("atk", 1)),
		int(tgt.get("def", 0)), float(entry.get("power", 1.0)), variance,
		BattleLogic.incoming_damage_multiplier(bool(tgt.get("defending", false)), bool(tgt.get("covering", false))))
	var events: Array[Dictionary] = events_append_damage(tgt, dmg, BattleLogic.ELEMENT_NONE, false,
		{"name": String(actor.get("name", ""))})
	if applies_poison and BattleLogic.is_alive(tgt):
		tgt = BattleLogic.apply_poison(tgt)
		_replace_unit(tgt)
		events.append(_ev("poison", tgt, {"amount": BattleLogic.compute_poison_damage(int(tgt.get("max_hp", 1))), "applied": true}))
	return events


func _enemy_sweep(actor: Dictionary, entry: Dictionary, variance: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for tgt: Dictionary in _alive(party):
		var dmg: int = BattleLogic.compute_physical_damage(int(actor.get("atk", 1)),
			int(tgt.get("def", 0)), float(entry.get("power", 1.0)), variance,
			BattleLogic.incoming_damage_multiplier(bool(tgt.get("defending", false)), bool(tgt.get("covering", false))))
		events.append_array(events_append_damage(tgt, dmg, BattleLogic.ELEMENT_NONE, false,
			{"name": String(actor.get("name", "")), "sweep": true}))
	return events


func _first_alive_party() -> Dictionary:
	for u: Dictionary in party:
		if BattleLogic.is_alive(u):
			return u
	return {}


## 权重抽取：roll<0 用 randf；否则 roll∈[0,1) 按累计权重定位
func _weighted_pick(weights: Dictionary, roll: float) -> String:
	var keys: Array[String] = []
	var total: int = 0
	for k: String in weights:
		keys.append(k)
		total += int(weights[k])
	if total <= 0:
		return ""
	var r: float = roll if roll >= 0.0 else randf()
	var threshold: float = r * float(total)
	var acc: int = 0
	for k: String in keys:
		acc += int(weights[k])
		if float(acc) > threshold:
			return k
	return keys[keys.size() - 1]


# ==================================================================
# 伤害应用（含掩护转移 / 击退 / 弱点记忆）
# ==================================================================

## 对目标造成伤害，处理：掩护转移（边缘 2）→ 弱点记忆 / 击退 → 写回 → 事件
## 返回本次产生的全部事件（主伤害 + 可能的 weakness / knockback），并逐一 emit。
func events_append_damage(tgt: Dictionary, amount: int, element: String, is_weak: bool, base_meta: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# 掩护转移：被掩护者受击 → 转给掩护者（其 covering ×0.5 已含防御姿态减伤）
	if _cover_map.has(int(tgt.get("slot", -1))):
		var caster_slot: int = int(_cover_map[int(tgt.get("slot", -1))])
		var caster: Dictionary = _unit(BattleLogic.SIDE_PARTY, caster_slot)
		if not caster.is_empty() and BattleLogic.is_alive(caster):
			tgt = caster
			base_meta["covered"] = true
	# 应用伤害
	tgt = BattleLogic.damage_unit(tgt, amount)
	_replace_unit(tgt)
	var ev: Dictionary = base_meta.duplicate(true)
	ev["type"] = "damage"
	ev["side"] = String(tgt.get("side", ""))
	ev["slot"] = int(tgt.get("slot", -1))
	ev["amount"] = amount
	ev["element"] = element
	ev["weak"] = is_weak
	if not BattleLogic.is_alive(tgt):
		ev["death"] = true
	out.append(ev)
	event_emitted.emit(ev)
	# 弱点：记忆 + 弹字 + 击退（§3.3 / §3.1）
	if is_weak and String(tgt.get("side", "")) == BattleLogic.SIDE_ENEMY:
		var wk: String = String(tgt.get("weakness", ""))
		if not wk.is_empty() and not discovered_weakness.has(wk):
			discovered_weakness.append(wk)
		var wv: Dictionary = {"type": "weakness", "side": BattleLogic.SIDE_ENEMY,
			"slot": int(tgt.get("slot", -1)), "name": String(tgt.get("name", "")), "element": wk}
		out.append(wv)
		event_emitted.emit(wv)
		if not bool(tgt.get("defending", false)):
			queue = BattleLogic.apply_knockback(queue, cursor, BattleLogic.SIDE_ENEMY, int(tgt.get("slot", -1)))
			var kv: Dictionary = {"type": "knockback", "side": BattleLogic.SIDE_ENEMY,
				"slot": int(tgt.get("slot", -1)), "name": String(tgt.get("name", "")),
				"slots": BattleLogic.KNOCKBACK_SLOTS}
			out.append(kv)
			event_emitted.emit(kv)
	return out


# ==================================================================
# 胜负 / 推进
# ==================================================================

## 全灭检查：任一方全灭 → 置 outcome + over + 发 battle_over（边缘 7 途中中断）
func _check_wipe() -> bool:
	if BattleLogic.is_wiped(enemies):
		over = true
		outcome = OUTCOME_VICTORY
		battle_over.emit(_build_result())
		return true
	if BattleLogic.is_wiped(party):
		over = true
		outcome = OUTCOME_DEFEAT
		battle_over.emit(_build_result())
		return true
	return false


## 推进游标 + 轮末重建队列（reset_round_flags 清瞬时姿态 / 清掩护标记）
func _advance_and_check() -> void:
	if over:
		return
	var res: Dictionary = BattleLogic.advance(queue, cursor, party, enemies)
	queue = res["queue"]
	cursor = int(res["cursor"])
	if bool(res.get("round_over", false)):
		_new_round()


func _new_round() -> void:
	for i: int in party.size():
		party[i] = BattleLogic.reset_round_flags(party[i])
	for i: int in enemies.size():
		enemies[i] = BattleLogic.reset_round_flags(enemies[i])
	_cover_map = {}
	_charging = {}
	queue = BattleLogic.build_queue(party, enemies)
	cursor = 0
	round_num += 1


# ==================================================================
# 结果组装 / 事件工具
# ==================================================================

func _build_result() -> Dictionary:
	var party_state: Array = []
	for u: Dictionary in party:
		party_state.append({
			"id": u.get("unit_id", ""),
			"level": int(u.get("level", 1)),
			"hp": int(u.get("hp", 0)),
			"max_hp": int(u.get("max_hp", 1)),
			"mp": int(u.get("mp", 0)),
			"max_mp": int(u.get("max_mp", 0)),
		})
	return {
		"outcome": outcome,
		"party_state": party_state,
		"encounter_id": encounter_id,
		"exp_gained": [],
		"gold_gained": 0,
		"items_used": [],
	}


func _ev(type: String, unit: Dictionary, extra: Dictionary) -> Dictionary:
	var ev: Dictionary = {"type": type}
	ev["side"] = String(unit.get("side", ""))
	ev["slot"] = int(unit.get("slot", -1))
	ev["name"] = String(unit.get("name", ""))
	for k in extra:
		ev[k] = extra[k]
	return ev


## 批量发射（事件已在产生处逐一 emit；此处保留钩子以便将来扩展批量处理）
func _emit_all(_events: Array[Dictionary]) -> void:
	pass
