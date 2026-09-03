extends Node2D
## _m5_battle_host —— M5 收口 VICTORY 演示舞台（Boss 教学战）
## 【临时演示场景，仅供 M5 收口录制，录后可删】（与 M4 host 同纪律）
##
## 【定位】组装 E3 真实战斗系统（BattleCommand 指令状态机 + BattleUI 八要素
##   HUD）并程序化打一场【确定性胜利】的 Boss 教学战：蓄力 telegraph →
##   防御应对的完整循环（探索 GDD §5 Boss AI 教学意图）。
##   结束发 battle_finished(VICTORY)——M5 演示里该信号由
##   BattleEventBridge 消费 → 全局 executor.resolve_victory() → 回 f3
##   续行 story_boss_pre 战后段（finale → phase 3 → save_point，I5 兑现）。
##   【桥的簿记宿主是全局 executor，与本替身场景无关】——替身只负责把
##   结算载荷按协议发出，续行链语义与真实战斗场景完全一致。
##
## 【为什么编组走暂存 payload】demo 驱动器在第 7 幕切替身时【捕获重传】桥
##   转发受理的完整载荷（change_scene 传 staged+true——Router 对每次受理
##   无条件覆写暂存位，dryrun9 实锤空载荷切换会把桥的完整四字段 Boss 载荷
##   清掉：enemy_group_id=b5_core + return_map/return_position 由桥补全），
##   本场景 get_staged_payload 取回的与真实战斗场景（bridge 转发受理路径）
##   逐字段一致：同一载荷协议（A5），战后 BattleResultHandler 消费同一暂存
##   完成回 f3 回置。
##
## 【VICTORY 确定性推演】（Lv4 三人 vs 遗迹核心 HP480/ATK18/DEF12 弱火；
##   SPD 凯12>莫11>莉10=核10（同值我方先手），行动序 凯→莫→莉→核；
##   variance=1.0 无浮动；核 AI roll 恒 0.55 → threshold=55：
##   attack 累计50<55 假 / charge 累计70>55 真 → 恒蓄力；
##   蓄力次回合强制 charge_release(2.5)，防御 ×0.5 应对——教学拍完整循环）：
##   我方输出：凯重斩 (23×2−12)×1.8=50.4→50 / 莉火球 (21×2.2−12×1.2)×1.4×1.5=66.78→67 /
##   莫群愈轮不上输出（治疗拍）→ 输出 117/标准回合。
##   HP 流（核心 480）：R1 50+67=117 →R2 117(凯)→释放拍：核 release vs 凯
##   (18×2−18)×2.5=45→防御22.5→23；R3-5 同 R1/R2 节奏 → R5 末 480−117×3−117=12
##   → R6 凯重斩 50 ≥ 12 →【VICTORY @R6，全队存活】。
##   莫娜节拍：R1 普攻(2→1) / R2 防御 / R3 群愈(25×1.8=45) / R4 防御 /
##   R5 群愈 / R6 普攻——治疗量兜住 release 拍后的血线（演示不翻车）。
##   所有 submit_command 显式传 variance=1.0；enemy_action 显式传
##   roll_action=0.55 / release 由 _charging 簿记强制（禁随机：本文件无 randf）。
##
## 【行动时序依据】SPD：凯尔12 > 莫娜11 > 莉娜10 = 核心10（同值先手判定见
##   BattleLogic.build_queue；推演按 凯→莫→莉→核 记账）。

# ------------------------------------------------------------------
# 常量
# ------------------------------------------------------------------

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")

## 每次行动之间的停顿（秒）——保证弹字/闪白/HP 条变化可读
const BEAT_TIME: float = 1.1
## 结算画面展示时长（秒）
const RESULT_HOLD: float = 2.6
## 进战黑屏后的首个停顿（秒）
const INTRO_HOLD: float = 0.7
## 出战黑屏时长（秒，与 BattleTransition.OUTRO_TIME 对应）
const OUTRO_HOLD: float = 0.5

## Boss AI 固定 roll：0.55 → threshold=55 → attack 累计50<55 假 /
## charge 累计70>55 真 → 恒抽 charge（_weighted_pick 按键序累计定位）。
## 次回合 _charging 簿记强制 charge_release（telegraph 兑现，无需 roll）。
const CORE_ROLL_CHARGE: float = 0.55

## 演示队伍等级（B5 预期等级 Lv4，探索 GDD §7；经验曲线口径：B4 后=Lv4）
const PARTY_LEVEL: int = 4

## 战后回传给桥的击破凭据（demo 面无 visible_enemy uid，语义占位：
## VICTORY 链路上 BattleResultHandler 只用它登记 cleared_enemy_set，
## demo 收尾即删档，不产生持久影响）
const DEMO_DEFEAT_UID: String = "enemy_m5_demo_core"


func _ready() -> void:
	var payload: Dictionary = SceneRouter.get_staged_payload()
	var encounter_id: String = String(payload.get("enemy_group_id", "b5_core"))
	print("[M5Demo][BattleHost] 就绪：编组=%s（真实 BattleCommand+BattleUI，VICTORY 教学剧本）"
			% encounter_id)

	# ── 装配真实战斗模型 ────────────────────────────────────────
	bc = BattleCommand.new()
	bc.setup(encounter_id, BattleUnits.build_party(PARTY_LEVEL),
			BattleUnits.build_encounter(encounter_id))
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
var _round_counter: int = 0           # 莫娜节拍用的回合簿记（与 bc.round_num 对账）


func _autoplay() -> void:
	await _sleep(INTRO_HOLD)
	var guard: int = 0
	while not bc.over and guard < 40:   # 防御性护栏：推演 R6 内必结束
		guard += 1
		var actor: Dictionary = bc.current_actor()
		if actor.is_empty():
			break
		if bc.is_party_turn():
			var command: Dictionary = _party_command_for(actor)
			print("[M5Demo] R%d %s 行动：%s" % [bc.round_num,
					String(actor.get("name", "?")), _describe(command)])
			bc.submit_command(actor, command, 1.0)
		else:
			# Boss 行动：蓄力拍恒 roll=0.55；释放拍由 _charging 簿记强制
			# （enemy_action 内部先查蓄力簿记，roll 不参与释放判定）
			print("[M5Demo] R%d 核心 行动（AI roll=%.2f → 蓄力/释放拍）"
					% [bc.round_num, CORE_ROLL_CHARGE])
			bc.enemy_action(actor, CORE_ROLL_CHARGE, 1.0)
		await _sleep(BEAT_TIME)
	await _sleep(RESULT_HOLD)
	print("[M5Demo] 出战黑屏（play_outro %.1fs）" % OUTRO_HOLD)
	var trans: Node = ui.get_node_or_null("Transition")
	if trans != null and trans.has_method("play_outro"):
		trans.play_outro()
	await _sleep(OUTRO_HOLD)
	var final: Dictionary = _final_result.duplicate(true)
	final["defeat_enemy_uid"] = DEMO_DEFEAT_UID   # 桥/处理器消费的击破凭据
	print("[M5Demo] 发 battle_finished(%s) → 桥消费 → resolve_victory 续行战后段"
			% String(final.get("outcome", "?")))
	EventBus.battle_finished.emit(final)
	# 此后 SceneRouter 回图（桥续行 → BattleResultHandler 回 f3），本场景随
	# World 换装被释放


## 我方指令（教学拍：凯尔恒重斩主输出；莉娜恒火球吃弱点；莫娜节拍
## 治疗兜 release 后血线，防御拍演示"看到蓄力→防御"的应对教学）：
##   莫娜回合簿记 _round_counter 与 bc.round_num 对账——奇数轮治疗 /
##   偶数轮防御（蓄力→释放的应对拍落在防御轮上，与核心 AI 节奏咬合）。
func _party_command_for(actor: Dictionary) -> Dictionary:
	match String(actor.get("unit_id", "")):
		"kyle":
			return _skill_first("heavy_slash")
		"lina":
			return _skill_first("fireball")
		"mona":
			_round_counter = bc.round_num
			if _round_counter % 2 == 1:
				var heal: Dictionary = {
					"type": BattleCommand.CMD_SKILL, "skill_id": "group_heal"}
				if not bc.targets_for(heal).is_empty():
					return heal
				return _attack_first()
			return {"type": BattleCommand.CMD_DEFEND}
	# 兜底：普攻
	return _attack_first()


## 技能优先（MP 耗尽 / 目标不可达时降级普攻——fireball mp4×11 发 54MP
## 充裕、heavy_slash mp6×6 发 19MP 恰好打空，降级路径实拍为普攻，合理）
func _skill_first(skill_id: String) -> Dictionary:
	var cmd: Dictionary = {"type": BattleCommand.CMD_SKILL, "skill_id": skill_id}
	var targets: Array[Dictionary] = bc.targets_for(cmd)
	if not targets.is_empty():
		cmd["target_slot"] = int(targets[0].get("slot", 0))
		return cmd
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
			return "防御（蓄力应对教学拍）"
		_:
			return String(command.get("type", "?"))


# ------------------------------------------------------------------
# 结局与写回
# ------------------------------------------------------------------

func _on_battle_over(result: Dictionary) -> void:
	_final_result = result
	print("[M5Demo] 结局 -> %s（结算画面展示 %.1fs）—— VICTORY 教学剧本达成"
			% [String(result.get("outcome", "?")), RESULT_HOLD])


func _sleep(t: float) -> void:
	await get_tree().create_timer(t).timeout
