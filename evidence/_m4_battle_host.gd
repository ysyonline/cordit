extends Node2D
## _m4_battle_host —— M4 收口 DEFEAT 演示舞台
## 【临时演示场景，仅供 M4 收口录制，录后可删】（与 M3 host 同纪律）
##
## 【定位】组装 M4 真实战斗系统并程序化打一场【确定性全灭】：
##   BattleCommand（指令状态机）+ BattleUI（八要素 HUD）+ 打击反馈，
##   全部来自 scripts/battle/ 正式实现，零复制、零修改——本文件只做
##   装配与"自动玩家"编排。战斗结束发 battle_finished(DEFEAT)，
##   由 BattleResultHandler 真实执行 E4-S7 读档回图全链路。
##
## 【为什么打 DEFEAT】M4 新特性演示需要 S7 失败读档链路：全灭 → 自动读档
##   → 回到进图时存档点（road 入口 (384,64)）→ GameData 回滚。
##   编组选 B4 遗像守卫（ATK16 群击 vs Lv1 队伍 = 数值碾压）。
##
## 【DEFEAT 确定性推演】（Lv1 三人 vs 守卫；SPD 凯12>莫11>莉10>守9，
##   行动序恒为 凯→莫→莉→守；守卫 roll_action=0.9 恒抽 sweep 群击；
##   variance=1.0 无浮动；我方恒普攻不奶，莉娜火球）：
##   守卫 sweep(×0.8)：凯(DEF10)=(32-10)×0.8=17.6→18 / 莫=25×0.8=20 / 莉=26×0.8=20.8→21；
##   我方输出：凯 28-10=18 / 莫 14-10=4 / 莉火球 12×2.2−10×1.2=14.4→14，合计 36/回合。
##   HP 流：莉 80→59→38→17→R4 亡；莫 95→75→55→35→15→R5 亡；
##   凯 120→…→R7 亡 →【DEFEAT @R7，守卫剩 240−108−36−22−18−18=38】。
##   所有 submit_command 显式传 variance=1.0；enemy_action 显式传
##   roll_action=0.9（threshold=90：attack 60≤90 假 / poison 85≤90 假 /
##   sweep 100>90 真 → 恒 sweep）；禁随机：本文件无 randf。
##
## 【行动时序依据】SPD：凯尔12 > 莫娜11 > 莉娜10 > 守卫9（§3.1 排序规则）。

# ------------------------------------------------------------------
# 常量
# ------------------------------------------------------------------

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")

## 每次行动之间的停顿（秒）——保证弹字/闪白/HP 条变化可读
const BEAT_TIME: float = 1.1
## 全灭后结算画面展示时长（秒）
const RESULT_HOLD: float = 2.6
## 进战黑屏后的首个停顿（秒）
const INTRO_HOLD: float = 0.7
## 出战黑屏时长（秒，与 BattleTransition.OUTRO_TIME 对应）
const OUTRO_HOLD: float = 0.5

## 守卫 AI 固定 roll：0.9 → threshold=90 → attack(60) 假 / poison_strike(85) 假 /
## sweep(100>90) 真 → 恒抽 sweep 群击（_weighted_pick 按键序累计定位）。
const GUARD_ROLL_SWEEP: float = 0.9


func _ready() -> void:
	var payload: Dictionary = SceneRouter.get_staged_payload()
	var encounter_id: String = String(payload.get("enemy_group_id", "b4_guardian"))
	print("[M4Demo][BattleHost] 就绪：编组=%s（组装真实 BattleCommand + BattleUI，DEFEAT 剧本）"
			% encounter_id)

	# ── 装配真实战斗模型 ────────────────────────────────────────
	bc = BattleCommand.new()
	bc.setup(encounter_id, BattleUnits.build_party(1), BattleUnits.build_encounter(encounter_id))
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

var bc: BattleCommand = null          # 战斗模型（指令状态机）
var ui: Control = null                # 战斗 HUD（BattleUI）
var _final_result: Dictionary = {}    # battle_over 捕获的结算载荷


func _autoplay() -> void:
	await _sleep(INTRO_HOLD)
	var round_no: int = 1
	while not bc.over:
		var actor: Dictionary = bc.current_actor()
		if actor.is_empty():
			break
		if bc.is_party_turn():
			var command: Dictionary = _party_command_for(actor)
			print("[M4Demo] R%d %s 行动：%s" % [round_no,
					String(actor.get("name", "?")), _describe(command)])
			bc.submit_command(actor, command, 1.0)
		else:
			print("[M4Demo] R%d 守卫 %s 行动（AI roll=%.2f → sweep 群击）"
					% [round_no, String(actor.get("name", "?")), GUARD_ROLL_SWEEP])
			bc.enemy_action(actor, GUARD_ROLL_SWEEP, 1.0)
		await _sleep(BEAT_TIME)
		if bc.is_party_turn():
			round_no += 1   # 队首（凯尔）再次行动 = 新回合开始	# bc.over == true：battle_over 已发（DEFEAT）、结算画面已由 BattleUI 显示
	await _sleep(RESULT_HOLD)
	print("[M4Demo] 出战黑屏（play_outro %.1fs）" % OUTRO_HOLD)
	var trans: Node = ui.get_node_or_null("Transition")
	if trans != null and trans.has_method("play_outro"):
		trans.play_outro()
	await _sleep(OUTRO_HOLD)
	print("[M4Demo] 发 battle_finished(DEFEAT) → BattleResultHandler 读档回图")
	EventBus.battle_finished.emit(_final_result)
	# 此后 SceneRouter 回图，本场景随 World 换装被释放


## 我方指令：全员普攻压守卫（DEFEAT 剧本不做抵抗演出——治疗在数值碾压下
## 只会延长战斗不改变结局，普攻是最诚实的"打不过"演出）。
## 火球例外：无弱点加成时 14 点伤害反而高于普攻 2 点，莉娜恒火球。
func _party_command_for(actor: Dictionary) -> Dictionary:
	match String(actor.get("unit_id", "")):
		"lina":
			var targets: Array[Dictionary] = bc.targets_for(
					{"type": BattleCommand.CMD_SKILL, "skill_id": "fireball"})
			if not targets.is_empty():
				return {"type": BattleCommand.CMD_SKILL, "skill_id": "fireball",
						"target_slot": int(targets[0].get("slot", 0))}
			return _attack_first()
		"kyle", "mona":
			return _attack_first()
	# 兜底：普攻
	return _attack_first()


## 普攻第一个存活敌人
func _attack_first() -> Dictionary:
	var targets: Array[Dictionary] = bc.targets_for({"type": BattleCommand.CMD_ATTACK})
	if not targets.is_empty():
		return {"type": BattleCommand.CMD_ATTACK,
				"target_slot": int(targets[0].get("slot", 0))}
	return {"type": BattleCommand.CMD_DEFEND}


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
	print("[M4Demo] 结局 -> %s（结算画面展示 %.1fs）—— DEFEAT 剧本达成"
			% [String(result.get("outcome", "?")), RESULT_HOLD])


func _sleep(t: float) -> void:
	await get_tree().create_timer(t).timeout
