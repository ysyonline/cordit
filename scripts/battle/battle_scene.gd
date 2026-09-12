extends Node2D
## battle_scene —— 真实战斗场景（E2-S3 占位 → O-6 修复：接入 E3 真实战斗系统）
##
## 【O-6 修复缘起】（2026-09-12 玩家实证 + 代码考古，m7-final-qa-gate.md G-8）：
##   E2-S3 起本场景一直是占位（彩色方块 + 胜利/失败按钮），E3 真实战斗
##   （BattleCommand + BattleUI）建成后从未接入生产路由——玩家碰怪进的是
##   方块阵画面。本改造把装配样板（evidence/_m5_battle_host.gd L80-95，
##   M5/M6 录屏宿主同源）生产化：
##     ① 队伍从 GameData.party 现值构建（等级/装备/当前 HP/MP，非满血口径
##       ——见 _build_party_from_gamedata，与 M6 demo 同源不漂移）；
##     ② 敌方由 encounter_id 查表构建（build_encounter）；
##     ③ 战斗驱动交 BattleCommand（指令状态机，输入经 BattleUI 八要素 HUD）；
##     ④ 结局经 battle_over → 组装 A5 BattleResult → EventBus.battle_finished
##       （BattleResultHandler 消费：覆写 GameData / 登记击破 / 回图）。
##
## 【O-7 修复缘起】（2026-09-12 R-3 重录实锤，QA G-8 新增 Blocker）：
##   O-6 只做了"装配"漏了"驱动"——玩家在菜单点指令后 BattleUI 发出
##   command_selected，但本场景无人消费，战斗永远停在首轮（玩家实况：
##   "进战斗界面后没有提示怎么继续，停在战斗初始化"）。验证盲区与 O-6
##   同根：M5 demo 自带 _autoplay、GUT _drive_battle 直调 submit_command，
##   都绕过 UI 信号，"玩家走的链"从未被测过。本改造补齐生产驱动链：
##     ① 输入桥：ui.command_selected → _on_command_selected →
##       cmd.submit_command（伤害浮动走生产口径 variance_from_roll，
##       0.9~1.1）；提交后自动驱动敌方回合，轮到我方再交还菜单；
##     ② 敌方自动驱动：轮到敌方按 ENEMY_ACT_BEAT 节拍 enemy_action；
##     ③ 结算驻留：battle_over 后等结算揭示弹完（interact 可跳过，护栏
##       15s）→ 出战黑屏 → 才转发 EventBus.battle_finished——修复前
##       胜利瞬间秒回图，E6-S2 结算画面在生产链从未出现过。
##   驱动样板：evidence/_m5_battle_host.gd _autoplay（由自动脚本改为
##   玩家事件驱动 + 节拍等待）。回归测试：tests/gut/test_o7_ui_bridge.gd。
##
## 【保留的占位遗产】last_payload 消费与 [BattleScene] 就绪日志格式不变：
##   B 区接线用例（test_e2s3.gd）按脚本路径判定场景身份，消费语义不回退。
##
## 【边界】（A3/A5）：
##   - 载荷唯一来源：SceneRouter.get_staged_payload()（A3"载荷暂存"唯一读口）；
##   - 不直接写 GameData：写回全由 BattleResultHandler 消费 battle_finished
##     完成（battle_scene 自身只读队伍现值来建战斗单位）；
##   - 不感知地图：return_map/return_position 留在暂存区由 Handler 兜底取；
##   - 引用风格：preload 常量（项目规范）。

## 队伍角色记录类型（preload 常量，项目规范）
const CharacterRecord := preload("res://scripts/core/character_record.gd")
const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")

## 最近一次消费的 BattlePayload（测试与调试观察口；不入存档协议）
var last_payload: Dictionary = {}

## 战斗模型（指令状态机；GUT 可观察）
var cmd: BattleCommand = null
## 战斗视图（八要素 HUD；GUT 可观察）
var ui: Control = null

# ================================================================
# O-7 生产驱动链（玩家事件驱动 + 敌方节拍 + 结算驻留）
# ================================================================

## 敌方两次行动之间的节拍（秒）——保证弹字/闪白可读，口径对齐 M5 BEAT_TIME
const ENEMY_ACT_BEAT: float = 0.9
## 结算揭示护栏（秒）：揭示被跳过/异常卡住的兜底上限，超时强制放行
const REVEAL_GUARD: float = 15.0
## 出战黑屏时长（秒，与 BattleTransition.OUTRO_TIME 对应）
const OUTRO_HOLD: float = 0.5

## 结局转发守门（防 battle_over 重复消费）
var _finalizing: bool = false


func _ready() -> void:
	# 消费暂存载荷（Router 校验闸门在切换前已把关，此处只管消费）
	last_payload = SceneRouter.get_staged_payload()
	var encounter_id: String = String(last_payload.get("enemy_group_id", ""))
	print("[BattleScene] 就绪：编组=%s 回图=%s 队伍=%d 人（真实战斗 O-6 接线）" % [
			encounter_id,
			last_payload.get("return_map", "<空>"),
			GameData.party.size()])

	# ── 装配真实战斗模型（样板：evidence/_m5_battle_host.gd L80-88）──
	cmd = BattleCommand.new()
	cmd.setup(encounter_id, _build_party_from_gamedata(),
			BattleUnits.build_encounter(encounter_id))
	# 跨战斗弱点记忆：战斗前从 GameData 读入（首命中后事件流写回）
	for w: String in GameData.discovered_weakness_set:
		cmd.discovered_weakness.append(w)
	# 注入背包（道具指令可用性；I2 队伍共享背包口径）
	cmd.set_inventory(_inventory_entries())
	# 开局：构建首轮行动队列（漏掉 start() 则队列为空，战斗直接跳过）
	cmd.start()
	cmd.battle_over.connect(_on_battle_over)

	# ── 装配真实战斗视图（八要素 HUD + 打击反馈 + 转场）──
	ui = BattleUI.new()
	ui.name = "BattleHUD"
	add_child(ui)
	ui.bind(cmd)
	ui.play_transition_intro()

	# ── O-7 输入桥：UI 信号 → 指令状态机（缺失即玩家操作无人消费，战斗冻结）──
	ui.command_selected.connect(_on_command_selected)


## 玩家指令提交（BattleUI.command_selected 消费端）。
## 校验回合归属防越权（非我方回合/行动者不符直接忽略——UI 置灰是第一道，
## 这里是第二道）；伤害浮动走生产口径 variance_from_roll（0.9~1.1）。
## 提交后启动敌方自动驱动，轮到我方时自然停回菜单。
func _on_command_selected(command: Dictionary) -> void:
	if cmd == null or cmd.over:
		return
	var actor: Dictionary = cmd.current_actor()
	if not cmd.is_party_turn() or actor.is_empty():
		return
	print("[BattleScene] 玩家指令 %s（%s）" % [
			String(command.get("type", "?")), String(actor.get("name", "?"))])
	cmd.submit_command(actor, command,
			BattleLogic.variance_from_roll(randf()))
	ui.refresh_command_menu()   # 提交后立即刷新：敌回合隐藏菜单防误点
	_drive_until_party_turn()


## 敌方自动驱动：轮到敌方则按节拍行动，轮到我方（或战斗结束）即停。
## 我方指令刚推进完队列时敌人可能连续行动多拍（SPD 序），逐拍 await。
func _drive_until_party_turn() -> void:
	var guard: int = 0
	while not cmd.over and guard < 8:
		guard += 1
		var actor: Dictionary = cmd.current_actor()
		if actor.is_empty():
			return
		if cmd.is_party_turn():
			ui.refresh_command_menu()   # 回到我方：重新点亮菜单
			return
		await get_tree().create_timer(ENEMY_ACT_BEAT).timeout
		if cmd.over:
			return
		cmd.enemy_action(actor, randf(), BattleLogic.variance_from_roll(randf()))
	# 护栏触顶仍不轮到我方：异常状态，打印现场供诊断（不静默卡死）


## 战斗结束：把 BC 的结算结果补上击破凭据后转发 EventBus。
## O-7 驻留：等结算揭示弹完（interact 可跳过）→ 出战黑屏 → 才转发——
## 保证 E6-S2 结算画面在生产链可见，修复前胜利瞬间秒回图。
## defeat_enemy_uid 取暂存载荷（碰怪遇敌路径由 visible_enemy 写入；事件
## 战斗路径为空串——胜利续行由 BattleEventBridge 消费，击破登记靠空值
## 防御跳过，语义不变）。转交后本场景随 World 换装被释放，无需自拆。
func _on_battle_over(result: Dictionary) -> void:
	if _finalizing:
		return
	_finalizing = true
	var final: Dictionary = result.duplicate(true)
	final["defeat_enemy_uid"] = String(last_payload.get("defeat_enemy_uid", ""))
	print("[BattleScene] 结局 -> %s（击破凭据=%s，驻留结算揭示后转交）" % [
			String(final.get("outcome", "?")), final["defeat_enemy_uid"]])
	# 驻留：结算揭示逐条弹出（BattleUI._process 自驱），interact 键可跳过；
	# 护栏 15s 兜底防揭示异常卡住。await 期间玩家看的是完整结算画面。
	var waited: float = 0.0
	while ui != null and ui.is_revealing() and waited < REVEAL_GUARD:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	# 出战黑屏（0.3s 淡入到全黑）+ 停留，再转交回图
	if ui != null:
		var trans: Node = ui.get_node_or_null("Transition")
		if trans != null and trans.has_method("play_outro"):
			trans.play_outro()
		await get_tree().create_timer(OUTRO_HOLD).timeout
	print("[BattleScene] 驻留结束（%.1fs），发 battle_finished(%s) -> 转交 BattleResultHandler"
			% [waited, String(final.get("outcome", "?"))])
	EventBus.battle_finished.emit(final)


# ------------------------------------------------------------------
# GameData → 战斗单位（生产口径：等级 + 装备 + 当前 HP/MP 现值）
# ------------------------------------------------------------------

## GameData.party → 战斗单位数组。与 M6 demo _build_party_from_gamedata
## 同源不漂移：六维走 stats_at(level) + apply_equipment（装备加成生产并项），
## HP/MP 取角色当前值（战斗从探索态接续，非满血开局）。HP 下限钳 1 防御
## 脏档（maxi(1,...)——0 血角色进战斗即刻全灭，属异常态，交读档回滚）。
func _build_party_from_gamedata() -> Array:
	var out: Array = []
	for rec: CharacterRecord in GameData.party:
		var unit: Dictionary = BattleUnits.build_party_unit(String(rec.id),
				int(rec.level),
				{"weapon_id": String(rec.weapon_id), "armor_id": String(rec.armor_id)})
		if unit.is_empty():
			continue
		unit["hp"] = maxi(1, int(rec.hp))
		unit["mp"] = maxi(0, int(rec.mp))
		out.append(unit)
	return out


## GameData.inventory → BattleCommand 背包协议（[{item_id, count}]）。
## 口径与 BattleCommand.set_inventory 注入格式一致；count<=0 不注入。
func _inventory_entries() -> Array:
	var out: Array = []
	for iid: String in GameData.inventory:
		var count: int = int(GameData.inventory[iid])
		if count > 0:
			out.append({"item_id": iid, "count": count})
	return out
