extends RefCounted
## event_executor.gd —— 事件动作执行器（E5-S2，架构 A7 第 2 层·评估与执行）
##
## 【职责链定位】schema_validator（合法吗）→ event_loader（表里有什么）→
##   本类（现在该发生什么）。触发器薄壳（第 1 层）命中后调用
##   execute_event(event_id, 事件字典)：条件不满足 → 静默跳过；满足 →
##   顺序执行 actions 数组。本类不理解"谁触发了我"——交互/踩踏/剧情锚点
##   在薄壳侧（A7 薄壳纪律：行为在数据侧，壳只递 id）。
##
## 【动作语义表】（GDD §3.2 最终清单；wait/play_sfx 允许空实现占位）：
##   dialogue        → 按 id（或 phase 映射）开演对话（DialogueRunner 注入口）
##   give_item       → GameData.inventory[id] += count（I2 队伍共享，与宝箱同入口）
##   set_flag        → GameData.flags[id] = true（E5-S3 入存档）
##   battle          → 组 BattlePayload 经 EventBus.enemy_touched 发出（A5 通路，
##                     地图→战斗唯一路由；事件流由 runner.force_idle() 收束）
##   heal            → 全队 HP/MP 回满（§3.2"客栈休息全回复"；inventory 疑似
##                     消耗品语义与"全回复"的判定属 E6 消耗品接线，本动作只回复）
##   teleport        → 经 SceneRouter 换图（A5：地图装载不带 payload）；
##                     当前切片事件侧无此用例（传送全在 TeleportCatalog），
##                     通路按协议预留并留日志
##   save_point      → EventBus.save_requested 请求存档（存不存由 SaveManager 裁决）
##   set_story_phase → GameData.story_phase = n + EventBus.story_phase_changed(n)
##                     （E5-S3 广播语义，本 Story 预埋动作侧）
##   wait            → 节奏停顿（可选 duration 秒；E5-S2 仅留执行日志占位——
##                     事件流异步化属 E5-S5 Boss 事件编排需求，届时扩展）
##   play_sfx        → 音效钩子（E6 音频系统就绪后接 AudioStreamPlayer；占位）
##
## 【 battle 暂停/恢复（E5-S5 桥接，对话 GDD §6"对战斗"）】battle 动作把
##   事件流暂停交给战斗：battle 之后的 actions 挂起为"胜利续行段"，随
##   _paused_event 簿记（事件 id / 动作数组 / battle 动作下一帧下标）暂存于
##   本执行器。挂起期间执行器置 _paused = true（in_battle_pause() 可查）：
##   对 execute_event 的新调用一律拒绝并留日志——杜绝战斗转场窗口内再触发
##   任何事件（探索边缘 3"无中途态残留"的入口闸）。胜利回传由
##   battle_event_bridge（SceneRouter 装配的常驻消费端）监听
##   EventBus.battle_finished：VICTORY → 桥接侧 force_idle 收束（延迟一帧，
##   防 battle 动作同步调用链内改写门闸）→ 次帧 resolve_victory() →
##   从暂存事件 battle 下标 +1 续行（phase/save_point 在战后段内生效，
##   I5 全序列一次触发）；DEFEAT → 桥接侧 clear_battle_pause() 整体清簿记
##   （E4-S7 读档已把 GameData 回滚，本侧不残留事件流状态）——story_boss_pre
##   战前段无前置写操作，从头再触发天然干净。pending_battle_group 保留原名
##   与原消费面（S2 语义零漂移）：记录暂存事件被挂起前的编组 id，供桥接/
##   单测断言。

## schema 校验器（pick_phase_id 选取规则同源复用；正本在 scripts/dialogue，
## 自 runner 抽离——events 侧跨域引用对话域校验器，依赖方向 events → dialogue）
const SchemaValidator := preload("res://scripts/dialogue/schema_validator.gd")

## 队伍角色记录类型（preload 常量规约——无全局 class_name，同 GameData/SaveManager；
## heal 动作的回满目标类型）
const CharacterRecord := preload("res://scripts/core/character_record.gd")

## battle 动作延迟收束对话的帧偏移（call_deferred 一帧：本函数可能正被
## runner 的交互链调用，当场 force_idle 会改写调用方刚消费的门闸状态）
const BATTLE_IDLE_DEFERRED_FRAMES: int = 1

## 对话运行器注入口（dialogue 动作与 battle 收束的消费面；null = 对话动作
## 跳过并留日志——headless 纯数据用法）
var dialogue_runner: Node = null

## battle 动作暂存位（最近一次 battle 动作的编组 id；E5-S5 桥接/单测消费）
var pending_battle_group: String = ""

## battle 暂停簿记（E5-S5 桥接）。空字典 = 无挂起事件；非空 = {"event_id": String,
## "actions": Array, "next_idx": int}——next_idx 指向 battle 动作的下一动作。
## 暂存的是事件字典内 actions 数组的引用，bridge 解析新图 executor 后递给
## resolve_victory；事件表为纯数据、跨场景不失效，无需另设拷贝。
var _paused_event: Dictionary = {}

## 暂停标志（簿记存在性的快查口；与 _paused_event 同步维护）
var _paused: bool = false


## 注入对话运行器（触发器壳装配时调用；测试可不注入）
func setup(p_runner: Node) -> void:
	dialogue_runner = p_runner


## 执行入口：条件评估 → 顺序执行动作。
## p_event_id：事件标识（日志/信号消费）；p_event：GDD §3.2 事件字典。
## battle 挂起期间新事件一律拒绝（E5-S5 暂停闸：战斗转场窗口内触发器/
## NPC 交互全部休眠，防并发事件流把战后续行段插花——探索边缘 3 的入口面）。
func execute_event(p_event_id: String, p_event: Dictionary) -> void:
	if _paused:
		print("[EventExecutor] 事件流战斗挂起中，拒绝新事件 \"%s\"（S5 暂停闸）" % p_event_id)
		return
	if not conditions_met(p_event):
		print("[EventExecutor] %s 条件不满足，跳过" % p_event_id)
		return
	var actions: Variant = p_event.get("actions", [])
	for i: int in (actions as Array).size():
		_execute_action(p_event_id, i, actions[i], actions as Array)
		# battle 动作已挂起事件流：立即停走（其后的动作属胜利续行段）
		if _paused:
			return


## 条件评估（GDD §3.2 conditions 三键口径；全部满足才执行；无 conditions = 真）。
## story_phase：[运算符, n] 对 GameData.story_phase 求值；
## flag：GameData.flags 含该键即真；not_flag：不含即真。
## 注：flag/not_flag 均不落 chests_opened（ADR-3 专用集合不参与泛化条件——
## 宝箱"已开"条件的回迁形态由 E5-S4 数据侧定，本类只认 flags）。
func conditions_met(p_event: Dictionary) -> bool:
	var conds: Variant = p_event.get("conditions")
	if conds == null or typeof(conds) != TYPE_DICTIONARY:
		return true
	for k: Variant in (conds as Dictionary).keys():
		var key := String(k)
		var v: Variant = (conds as Dictionary)[k]
		match key:
			"story_phase":
				var op := String((v as Array)[0])
				var n: int = int((v as Array)[1])
				var phase: int = GameData.story_phase
				var ok := false
				if op == ">=":
					ok = phase >= n
				elif op == ">":
					ok = phase > n
				elif op == "==":
					ok = phase == n
				if not ok:
					return false
			"flag":
				if not GameData.flags.has(String(v)):
					return false
			"not_flag":
				if GameData.flags.has(String(v)):
					return false
	return true


## 单动作分派（type 白名单已由加载校验保证；未登记 type 防御性跳过）。
## p_actions：宿主动作数组（battle 动作挂起"下标之后整段"时需要全量引用）
func _execute_action(p_event_id: String, p_idx: int, p_action: Variant,
		p_actions: Array = []) -> void:
	if typeof(p_action) != TYPE_DICTIONARY:
		return
	var act := p_action as Dictionary
	var atype := String(act.get("type"))
	match atype:
		"dialogue":
			_start_dialogue(act, p_event_id)
		"give_item":
			var iid := String(act.get("item_id", ""))
			var count := int(act.get("count", 1))
			GameData.inventory[iid] = int(GameData.inventory.get(iid, 0)) + count
			print("[EventExecutor] give_item %s x%d（背包 %s）" % [iid, count, GameData.inventory])
		"set_flag":
			var fid := String(act.get("flag", ""))
			GameData.flags[fid] = true
			print("[EventExecutor] set_flag %s（flags=%s）" % [fid, GameData.flags])
		"battle":
			_start_battle(String(act.get("group", "")), p_event_id, p_idx, p_actions)
		"heal":
			_heal_party(p_event_id)
		"teleport":
			# 通路预留（A5：事件侧传送当前无用例，行走传送在 TeleportCatalog）；
			# 日志格式化先拼全串再 %（+ 与 % 同行时 % 先结合会抛格式化错误）
			print(("[EventExecutor] teleport %s -> %s %s（通路预留：事件侧传送当前"
					+ "无用例，行走传送在 TeleportCatalog）") % [
					p_event_id, String(act.get("to_map", "")), str(act.get("to_spawn", []))])
		"save_point":
			EventBus.save_requested.emit()
			print("[EventExecutor] save_point：已发存档请求（%s）" % p_event_id)
		"set_story_phase":
			if act.has("phase"):
				GameData.story_phase = int(act["phase"])
				EventBus.story_phase_changed.emit(GameData.story_phase)
			print("[EventExecutor] set_story_phase -> %d（%s）" % [GameData.story_phase, p_event_id])
		"wait":
			# E6 钩子占位（验收原文允许空实现）：事件流同步版仅留日志；
			# duration 参数合法带出，E5-S5 编排异步化时启用
			print("[EventExecutor] wait %s 秒（占位：事件流异步化属 E5-S5）" % str(act.get("duration", 0.0)))
		"play_sfx":
			# E6 音频钩子占位（验收原文允许空实现）
			print("[EventExecutor] play_sfx %s（占位：E6 接线）" % str(act.get("sfx", "")))
		_:
			print("[EventExecutor] 未登记动作 type \"%s\"（%s 第 %d），跳过" % [
					atype, p_event_id, p_idx])


## dialogue 动作：字符串 id 直用；字典按 phase 映射选取（SchemaValidator.
## pick_phase_id：取 ≤ 当前 phase 的最大键，"0" 兜底由加载校验保证）。
## 选取为空 / 开演失败：跳过不 crash（对话缺失降级，同宝箱提示对话口径）。
func _start_dialogue(p_act: Dictionary, p_event_id: String) -> bool:
	var idv: Variant = p_act.get("id")
	var dlg_id := ""
	if typeof(idv) == TYPE_STRING:
		dlg_id = String(idv)
	elif typeof(idv) == TYPE_DICTIONARY:
		dlg_id = SchemaValidator.pick_phase_id(idv, GameData.story_phase)
	if dlg_id.is_empty():
		print("[EventExecutor] dialogue 选取为空，跳过（%s）" % p_event_id)
		return false
	if dialogue_runner == null or not dialogue_runner.has_method("start_dialogue"):
		print("[EventExecutor] 对话运行器未注入，dialogue \"%s\" 跳过（%s）" % [dlg_id, p_event_id])
		return false
	var ok: bool = dialogue_runner.start_dialogue(dlg_id)
	if not ok:
		print("[EventExecutor] dialogue \"%s\" 被拒（%s）" % [dlg_id, p_event_id])
	return ok


## battle 动作：组装 A5 BattlePayload → enemy_touched（Router 是地图↔战斗
## 唯一通路，零互引）。事件流由此暂停：battle 之后的动作挂起为胜利续行段
## （E5-S5，语义见类头注）；"胜利后恢复"由 battle_event_bridge 消费
## battle_finished 后调 resolve_victory。return_map/return_position 空载荷
## 由桥接在发出前补全（executor 不感知地图坐标——A3 职责边界）。
## 载荷带 _from_event_battle 哨兵（桥接识别事件战斗 vs 普通遇敌的判据；
## SceneRouter 协议外字段"只警告不拒"纪律下安全透传，桥接转发前已擦除）。
func _start_battle(p_group: String, p_event_id: String, p_idx: int,
		p_actions: Array) -> void:
	pending_battle_group = p_group
	_paused_event = {"event_id": p_event_id, "actions": p_actions, "next_idx": p_idx + 1}
	_paused = true
	if dialogue_runner != null:
		dialogue_runner.call_deferred("force_idle")
	EventBus.enemy_touched.emit({
		"enemy_group_id": p_group,
		"return_map": "",
		"return_position": Vector2.ZERO,
		"defeat_enemy_uid": "",
		"_from_event_battle": true,
	})
	print("[EventExecutor] battle %s（%s）：payload 已发，事件流自下标 %d 起挂起（胜利续行段 %d 动作）" % [
			p_group, p_event_id, p_idx + 1, p_actions.size() - p_idx - 1])


## heal 动作：全队 HP/MP 回满（§3.2 客栈休息语义；队伍结构见 CharacterRecord）
func _heal_party(p_event_id: String) -> void:
	for record: CharacterRecord in GameData.party:
		record.hp = record.max_hp
		record.mp = record.max_mp
	print("[EventExecutor] heal 全队回满（%s）" % p_event_id)


## 胜利续行（E5-S5 桥接消费口）：从暂停簿记的 battle 下标 +1 继续执行剩余
## 动作（phase/save_point 等战后段在此生效，I5"一次触发"兑现）。执行前清
## 簿记——续行动作若再遇 battle（数据侧无此用例）可重新挂起；执行后若无新
## 挂起则事件流彻底收束。防御：无挂起簿记时留日志直接返回（桥接重放/测试
## 误触不炸）。
func resolve_victory() -> void:
	if not _paused:
		print("[EventExecutor] resolve_victory：无挂起事件流，忽略")
		return
	var ev_id: String = String(_paused_event["event_id"])
	var actions: Array = _paused_event["actions"]
	var from_idx: int = int(_paused_event["next_idx"])
	clear_battle_pause()
	print("[EventExecutor] 胜利续行 %s：自下标 %d / 共 %d 动作" % [ev_id, from_idx, actions.size()])
	for i: int in range(from_idx, actions.size()):
		_execute_action(ev_id, i, actions[i], actions)
		if _paused:
			return   # 续行段内再遇 battle：再次挂起（防御分支，当前数据无用例）


## 清除 battle 暂停簿记（DEFEAT 清场 / 桥接消费后 / 测试隔离用）。
## 暂存位与暂停闸一并复位——失败路径读档回滚后事件须可从头再触发。
func clear_battle_pause() -> void:
	_paused_event = {}
	_paused = false
	clear_battle_pending()


## 清除 battle 暂存位（S2 既有测试口，语义保留：只清编组 id 不动暂停簿记）
func clear_battle_pending() -> void:
	pending_battle_group = ""


## 测试观察口：对话运行器是否已注入且具备开演能力
func has_dialogue_runner() -> bool:
	return dialogue_runner != null and dialogue_runner.has_method("start_dialogue")


## 暂停闸查询（E5-S5）：事件流是否处于 battle 挂起态（桥接/单测断言用）
func in_battle_pause() -> bool:
	return _paused
