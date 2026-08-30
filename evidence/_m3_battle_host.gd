extends Node2D
## _m3_battle_host —— M3 门3 战斗演示舞台
## 【临时演示场景，仅供 M3 门3 录制，录后可删】
##
## 【定位】组装 M3 真实战斗系统并程序化打完一整场：
##   BattleCommand（指令状态机）+ BattleUI（八要素 HUD）+ 打击反馈
##   （闪白 / "弱点！"弹字）+ 进出战黑屏转场，全部来自
##   scripts/battle/ 正式实现，零复制、零修改——本文件只做装配与
##   "自动玩家"编排（相当于代替玩家按菜单）。
##
## 【为什么要这个临时场景】scenes/battle/battle.tscn 当前仍是 E2-S3
##   占位场景（胜利/失败按钮），M3 的 BattleUI 尚未接线到正式战斗场景；
##   演示用临时装配把真实系统搬上画面，正式接线属后续 Story（已在交付
##   说明中标注）。本场景经 SceneRouter 正常切换装入 World，战斗结束发
##   EventBus.battle_finished，由 BattleResultHandler 真实写回 + 回图。
##
## 【演示脚本】（B2 雷壳甲虫×2，弱火；全确定性——禁随机）：
##   第 1 轮  凯尔普攻 → 莫娜防御 → 莉娜火球（弱点！闪白+橙字+击退，
##            甲虫①倒下）→ 甲虫②反击凯尔
##   第 2 轮  凯尔普攻 → 莫娜治疗（绿字）→ 莉娜火球收尾 → 胜利结算
##   所有 submit_command 显式传 variance=1.0；enemy_action 显式传
##   roll_action=0.0（ai_weights 全 100 权重必中 attack）；不逃跑。
##
## 【行动时序依据】SPD：凯尔12 > 莫娜11 > 莉娜10 > 甲虫8，
##   行动队列顺序恒为 凯尔→莫娜→莉娜→甲虫①→甲虫②（§3.1 排序规则）。

# ------------------------------------------------------------------
# 常量（preload 常量风格，项目规范）
# ------------------------------------------------------------------

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")

## 每次行动之间的停顿（秒）——保证弹字/闪白/HP 条变化可读
const BEAT_TIME: float = 1.1
## 结算画面展示时长（秒）
const RESULT_HOLD: float = 2.2
## 进战黑屏后的首个停顿（秒）
const INTRO_HOLD: float = 0.7
## 出战黑屏时长（秒，与 BattleTransition.OUTRO_TIME 对应）
const OUTRO_HOLD: float = 0.5

# ------------------------------------------------------------------
# 运行时
# ------------------------------------------------------------------

var bc: BattleCommand = null          # 战斗模型（指令状态机）
var ui: Control = null                # 战斗 HUD（BattleUI）
var _final_result: Dictionary = {}    # battle_over 捕获的结算载荷


func _ready() -> void:
	var payload: Dictionary = SceneRouter.get_staged_payload()
	var encounter_id: String = String(payload.get("enemy_group_id", "b2_beetles"))
	print("[M3Demo][BattleHost] 就绪：编组=%s 回图=%s（组装真实 BattleCommand + BattleUI）"
			% [encounter_id, payload.get("return_map", "<空>")])

	# ── 装配真实战斗模型 ────────────────────────────────────────
	bc = BattleCommand.new()
	bc.setup(encounter_id, BattleUnits.build_party(1), BattleUnits.build_encounter(encounter_id))
	_set_inventory_from_game_data()
	# 跨战斗弱点记忆：战斗前从 GameData 读入（首次命中后 hit_feedback 会写回）
	for w: String in GameData.discovered_weakness_set:
		bc.discovered_weakness.append(w)
	# 开局：构建首轮行动队列（漏掉 start() 则队列为空，战斗会直接跳过）
	bc.start()
	bc.battle_over.connect(_on_battle_over)

	# ── 装配真实战斗视图（八要素 HUD + 打击反馈 + 转场）──────────
	ui = BattleUI.new()
	ui.name = "BattleHUD"
	add_child(ui)
	ui.bind(bc)
	ui.play_transition_intro()

	_autoplay()


# ------------------------------------------------------------------
# 自动玩家（确定性脚本驱动，禁随机）
# ------------------------------------------------------------------

func _autoplay() -> void:
	await _sleep(INTRO_HOLD)
	while not bc.over:
		var actor: Dictionary = bc.current_actor()
		if actor.is_empty():
			break
		if bc.is_party_turn():
			var command: Dictionary = _party_command_for(actor)
			print("[M3Demo] %s 行动：%s" % [String(actor.get("name", "?")),
					_describe(command)])
			bc.submit_command(actor, command, 1.0)
		else:
			print("[M3Demo] 敌方 %s 行动（AI roll=0.0 → attack）" % String(actor.get("name", "?")))
			bc.enemy_action(actor, 0.0, 1.0)
		await _sleep(BEAT_TIME)
	# bc.over == true：battle_over 已发、结算画面已由 BattleUI 显示
	await _sleep(RESULT_HOLD)
	print("[M3Demo] 出战黑屏（play_outro %.1fs）" % OUTRO_HOLD)
	var trans: Node = ui.get_node_or_null("Transition")
	if trans != null and trans.has_method("play_outro"):
		trans.play_outro()
	await _sleep(OUTRO_HOLD)
	print("[M3Demo] 发 battle_finished → BattleResultHandler 写回 + 回图")
	EventBus.battle_finished.emit(_final_result)
	# 此后 SceneRouter 回图，本场景随 World 换装被释放


## 按角色脚本给出指令（目标在执行时按存活者实时解析，保持确定性）
func _party_command_for(actor: Dictionary) -> Dictionary:
	match String(actor.get("unit_id", "")):
		"kyle":
			# 凯尔：多敌在场时普攻压血线；只剩最后一个敌人时改防御，
			# 把收尾交给莉娜火球、把治疗节拍让给莫娜（演示覆盖更全）
			if _alive_enemy_count() > 1:
				var targets: Array[Dictionary] = bc.targets_for({"type": BattleCommand.CMD_ATTACK})
				if not targets.is_empty():
					return {"type": BattleCommand.CMD_ATTACK,
							"target_slot": int(targets[0].get("slot", 0))}
			return {"type": BattleCommand.CMD_DEFEND}
		"lina":
			# 火球（fire，甲虫弱点）：打当前第一顺位存活敌人
			var targets: Array[Dictionary] = bc.targets_for(
					{"type": BattleCommand.CMD_SKILL, "skill_id": "fireball"})
			if not targets.is_empty():
				return {"type": BattleCommand.CMD_SKILL, "skill_id": "fireball",
						"target_slot": int(targets[0].get("slot", 0))}
		"mona":
			# 莫娜：有伤员先治疗（绿字），否则防御（+5 MP）
			var hurt: Dictionary = _first_hurt_ally()
			if not hurt.is_empty():
				return {"type": BattleCommand.CMD_SKILL, "skill_id": "heal",
						"target_slot": int(hurt.get("slot", 0))}
			return {"type": BattleCommand.CMD_DEFEND}
	# 兜底（理论上不会走到）：防御
	return {"type": BattleCommand.CMD_DEFEND}


## 第一个未满血的存活我方单位（无则返回空字典）
func _first_hurt_ally() -> Dictionary:
	for u: Dictionary in bc.party:
		if int(u.get("hp", 0)) > 0 and int(u.get("hp", 0)) < int(u.get("max_hp", 1)):
			return u
	return {}


## 存活敌方数量
func _alive_enemy_count() -> int:
	var n: int = 0
	for e: Dictionary in bc.enemies:
		if int(e.get("hp", 0)) > 0:
			n += 1
	return n


## 指令可读描述（打印用）
func _describe(command: Dictionary) -> String:
	match String(command.get("type", "")):
		BattleCommand.CMD_ATTACK:
			return "普攻 → 敌方槽位 %d" % int(command.get("target_slot", -1))
		BattleCommand.CMD_SKILL:
			return "技能 %s → 槽位 %d" % [String(command.get("skill_id", "?")),
					int(command.get("target_slot", -1))]
		BattleCommand.CMD_DEFEND:
			return "防御"
		_:
			return String(command.get("type", "?"))


# ------------------------------------------------------------------
# 结局与写回
# ------------------------------------------------------------------

func _on_battle_over(result: Dictionary) -> void:
	_final_result = result
	print("[M3Demo] 结局 -> %s（结算画面展示 %.1fs）" % [
			String(result.get("outcome", "?")), RESULT_HOLD])


## GameData.inventory（{id: 数量}）→ BattleCommand 背包（[{item_id, count}]）
func _set_inventory_from_game_data() -> void:
	var inv: Array = []
	for item_id: String in GameData.inventory:
		inv.append({"item_id": item_id, "count": int(GameData.inventory[item_id])})
	bc.set_inventory(inv)


func _sleep(t: float) -> void:
	await get_tree().create_timer(t).timeout
