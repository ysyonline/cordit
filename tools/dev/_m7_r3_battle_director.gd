extends Node
## _m7_r3_battle_director —— M7 R-3 战斗导演（驱动器配套件，录后随驱动器同删）
##
## 【职责】挂 battle.tscn 根下，逐回合执行 driver 的剧本表（O-7 纪律：
##   指令一律经 ui.command_selected 发出，与玩家点击同通道）+ 每一拍敌
##   行动前重播种（driver.BEAT_SEED——确定性方案正本见驱动器头注）。
##   战斗事件转录进 driver._battle_events 供 A3/A7 断言。
##
## 【事件转录·两通道】（dryrun 第 1 轮实证：生产链只内联 emit damage 系）
##   ① 信号流：bc.event_emitted —— 只有 damage/weakness/knockback（生产
##      battle_command 仅在 events_append_damage 内联 emit；_ev 系 heal/
##      defend/poison/charge/skill 事件只进 submit_command/enemy_action 的
##      返回数组，而 battle_scene 两处调用都丢弃返回数组）。
##   ② 快照差分重建：ui.command_selected 的消费端 battle_scene.
##      _on_command_selected 是同步调用（submit_command 原子完成 tick+行动），
##      emit 前后各拍一次全单位状态快照，差分精确对应该角色行动；敌拍同理
##      （敌方 0.9s 定时器窗口前后差分）。重建事件标注 "_rebuilt": true 留痕，
##      与信号流原版事件可区分。断言只需类型在场，重建即满足证据标准。
##
## 【为什么敌拍前重播种安全】battle_scene._drive_until_party_turn 的敌拍
##   有 0.9s await 窗口；导演在我方回合轮询循环里、于「指令已提交、敌拍
##   定时器已启动」之后 seed()——窗口内无任何 randf 消费者（玩家 variance
##   在指令提交时已消费），L138 下一次调用的首个 randf 即被钉死。
##
## 【指令协议】与 command_selected 消费端（battle_scene._on_command_selected）
##   完全一致：attack/skill/item/defend；技能/道具带可用性守卫（MP 不足/
##   未习得/耗尽 → 降级防御或普攻并留痕——防软锁，不中断剧本）。

## 每次指令后等待生产链消费的超时上限（秒；远大于敌拍 0.9s + 弹字驻留）
const SUBMIT_TIMEOUT: float = 14.0
## 我方回合轮询间隔（秒）
const POLL_INTERVAL: float = 0.08
## 玩家思考时间（秒；每条指令 emit 前停留，观感节奏用——此刻仍是我方回合
## 队列静止，零随机链风险；见 _submit 注释）
const COMMAND_DWELL: float = 2.0
## 战斗整体护栏（秒；剧本最坏 8 轮 × ~4s + 结算揭示 15s + 黑屏，300s 充裕）
const BATTLE_GUARD: float = 300.0

## 宿主驱动器（driver._battle_script / driver.BEAT_SEED / driver._battle_events）
var driver: Node = null
## "b4" / "b5"
var kind: String = ""
## 完成信号（driver await 此信号后做断言）
signal done

## 状态机引用（battle_scene.cmd）
var bc: Variant = null
## 战斗 UI 引用（battle_scene.ui）
var ui: Variant = null
## 防重发锁（同一行动者只发一次指令）
var _acted: Dictionary = {}
## 每轮敌拍已播种标记（一轮敌拍 = 一次 L138 调用；释放拍不掷随机不播种）
var _beat_seeded: Dictionary = {}
## 已发指令计数（玩家 variance 序列观测；诊断用）
var _submitted: int = 0
## 敌拍差分的前置快照（进入敌拍时拍，回到我方回合/结束时差分）
var _enemy_pre: Dictionary = {}
## 群击字幕只报一次（首轮 sweep 即报，后续静默）
var _sweep_captioned: bool = false


func _ready() -> void:
	bc = get_parent().get("cmd")
	ui = get_parent().get("ui")
	if bc == null or ui == null:
		push_error("[R3Director] FAIL：cmd/ui 未就绪")
		done.emit()
		return
	# 通道①：信号流转录（damage/weakness/knockback）
	bc.connect("event_emitted", Callable(self, "_on_event"))
	print("[R3Director] 导演就绪：%s（round1 队列 %d 项）" % [kind, (bc as RefCounted).queue.size()])
	_autoplay()


# ══════════════════════════════════════════════════════════════
# 通道①：信号流转录 + 关键节点字幕
# ══════════════════════════════════════════════════════════════

func _on_event(e: Dictionary) -> void:
	if driver != null:
		driver._battle_events.append(e)
	var t: String = String(e.get("type", ""))
	# F5 镜头④蓄力释放可见性：release 伤害事件的瞬间字幕（charge 无生产
	# UI 反应——BattleUI 只渲染 damage/weakness 弹字，缺口已报备 team-lead）
	if t == "damage" and bool(e.get("release", false)):
		_caption("蓄力释放撞上防御——伤害减半（×0.5），预告-应对-化解闭环")
	# 镜头③要素①：群击伤害瞬间字幕（一次即可）
	if t == "damage" and bool(e.get("sweep", false)) and not _sweep_captioned:
		_sweep_captioned = true
		_caption("守卫横扫！全队受创——莫娜的群愈即将抬血")


# ══════════════════════════════════════════════════════════════
# 通道②：状态快照差分重建（_ev 系事件证据链）
# ══════════════════════════════════════════════════════════════

## 全单位状态快照：{side:slot: {hp, mp, defending, poison_turns}} + 敌蓄力表
func _snap() -> Dictionary:
	var s: Dictionary = {}
	for arr_name: String in ["party", "enemies"]:
		var arr: Array = bc.get(arr_name)
		for u: Dictionary in arr:
			s["%s:%d" % ["p" if arr_name == "party" else "e", int(u.get("slot", -1))]] = {
				"hp": int(u.get("hp", 0)), "mp": int(u.get("mp", 0)),
				"defending": bool(u.get("defending", false)),
				"poison_turns": int(u.get("poison_turns", 0)),
			}
	var charging: Dictionary = bc.get("_charging")
	var ch: Dictionary = {}
	for k: Variant in charging:
		ch[str(k)] = bool(charging[k])
	s["_charging"] = ch
	return s


## 差分重建：pre → post 的每单位状态变化 → 合成事件（留痕 _rebuilt:true）
##   hp 增 → heal；mp 增 → heal(mp)；防 false→true → defend；
##   中毒回合 0→>0 → poison(applied)；中毒回合减且 hp 减 → 毒 tick；
##   敌 _charging false→true → charge（镜头④预告）
func _diff(pre: Dictionary, post: Dictionary) -> void:
	if driver == null:
		return
	for key: String in pre:
		if key == "_charging":
			continue
		var a: Dictionary = pre[key]
		var b: Dictionary = post.get(key, {})
		if b.is_empty():
			continue
		var side: String = "party" if key.begins_with("p") else "enemy"
		var slot: int = int(key.get_slice(":", 1))
		# heal（HP）
		var dh: int = int(b.get("hp", 0)) - int(a.get("hp", 0))
		if dh > 0:
			_emit_rebuilt({"type": "heal", "side": side, "slot": slot,
					"amount": dh, "_rebuilt": true})
		# heal（MP，ether 等道具）
		var dm: int = int(b.get("mp", 0)) - int(a.get("mp", 0))
		if dm > 0:
			_emit_rebuilt({"type": "heal", "side": side, "slot": slot,
					"amount": dm, "mp": true, "_rebuilt": true})
		# defend
		if not bool(a.get("defending", false)) and bool(b.get("defending", false)):
			_emit_rebuilt({"type": "defend", "side": side, "slot": slot,
					"_rebuilt": true})
		# 中毒施加（敌 poison_strike / 玩家毒技能）
		var pt_a: int = int(a.get("poison_turns", 0))
		var pt_b: int = int(b.get("poison_turns", 0))
		if pt_b > pt_a:
			_emit_rebuilt({"type": "poison", "side": side, "slot": slot,
					"amount": 0, "applied": true, "_rebuilt": true})
		# 毒 tick（行动前结算：回合数减 + 掉血；无 applied 键——与施加区分）
		elif pt_b < pt_a and dh < 0:
			_emit_rebuilt({"type": "poison", "side": side, "slot": slot,
					"amount": -dh, "_rebuilt": true})
	# 敌蓄力预告
	var ca: Dictionary = pre.get("_charging", {})
	var cb: Dictionary = post.get("_charging", {})
	for k: String in cb:
		if bool(cb[k]) and not bool(ca.get(k, false)):
			_emit_rebuilt({"type": "charge", "side": "enemy", "slot": int(k),
					"_rebuilt": true})


func _emit_rebuilt(ev: Dictionary) -> void:
	driver._battle_events.append(ev)
	# 弹字/字幕：heal（HP/MP 恢复）→ 绿字、poison tick → 紫字、charge → 预告字幕
	match String(ev.get("type", "")):
		"heal":
			_render_number(ev, "heal")
		"poison":
			if not ev.has("applied"):
				_render_number(ev, "poison")
		"charge":
			_caption("⚠ 核心正在蓄力——大招将至！下一拍全员防御（减伤×0.5）")
		"defend":
			pass   # 防御姿态有状态卡角标（生产状态栏刷新），无需弹字


## dev 侧弹字：调生产 BattleUI.spawn_damage_number（pos/amount/kind 协议）。
## 坐标复用生产 ui._event_screen_pos（与 damage/weakness 弹字同口径落点）。
func _render_number(ev: Dictionary, kind: String) -> void:
	if ui == null or driver == null or driver._dev_render_fn == Callable():
		return
	var pos: Vector2 = ui.call("_event_screen_pos", ev)
	driver._dev_render_fn.call(pos, int(ev.get("amount", 0)), kind)


func _caption(text: String) -> void:
	if driver != null:
		driver._set_caption(text)


# ══════════════════════════════════════════════════════════════
# 主循环：轮询 + 我方指令 + 敌拍播种/差分
# ══════════════════════════════════════════════════════════════

func _autoplay() -> void:
	var waited: float = 0.0
	while not bool(bc.get("over")) and waited < BATTLE_GUARD:
		await _sleep(POLL_INTERVAL)
		waited += POLL_INTERVAL
		if bool(bc.get("over")):
			if not _enemy_pre.is_empty():
				_diff(_enemy_pre, _snap())
				_enemy_pre = {}
			break
		if not bool(bc.call("is_party_turn")):
			# 敌拍窗口：进窗拍快照（首个轮询点，先于 0.9s 定时器的敌行动）
			if _enemy_pre.is_empty():
				_enemy_pre = _snap()
			# 若本轮尚未播种且剧本表有值 → 在敌拍定时器窗口内重播种
			_seed_beat_if_needed()
			continue
		# 回到我方回合：敌拍窗口收口（差分重建敌方行动事件）
		if not _enemy_pre.is_empty():
			_diff(_enemy_pre, _snap())
			_enemy_pre = {}
		var actor: Dictionary = bc.call("current_actor")
		if actor.is_empty():
			continue
		var actor_key: String = "%d:%d" % [int(bc.get("round_num")), int(actor.get("slot", -1))]
		if _acted.has(actor_key):
			continue   # 已发过指令，等队列推进
		_acted[actor_key] = true
		var cmd_dict: Dictionary = _party_command(actor)
		_submit(cmd_dict, actor)
	print("[R3Director] 结局 outcome=%s rounds=%d 事件=%d 提交=%d" % [
			String(bc.get("outcome")), int(bc.get("round_num")),
			driver._battle_events.size() if driver != null else -1, _submitted])
	done.emit()


## 敌拍重播种：本轮（b4/b5 × round_num）未播过且表有值才播。
## 释放拍（charge 事件已出现后的下一拍）不掷随机，跳过播种。
func _seed_beat_if_needed() -> void:
	var r: int = int(bc.get("round_num"))
	var key: String = "%s:%d" % [kind, r]
	if _beat_seeded.has(key):
		return
	var table: Dictionary = driver.BEAT_SEED
	if not table.has(kind):
		return
	var seeds: Array = table[kind]
	if r < 1 or r > seeds.size():
		return
	# 释放拍判定：敌方已 charge 且尚未 release → 本轮敌拍是强制 release
	if _release_pending():
		_beat_seeded[key] = true
		print("[R3Director] R%d 敌拍=release（强制，免播种）" % r)
		return
	seed(int(seeds[r - 1]))
	_beat_seeded[key] = true
	if driver.has_method("_expect"):
		driver._beats.append(key)
	print("[R3Director] R%d 敌拍已播种 seed=%d（窗口内钉死 roll）" % [r, int(seeds[r - 1])])


## 蓄力释放拍判定：敌方已 charge 且尚未 release（事件流尾部扫描）
func _release_pending() -> bool:
	if driver == null:
		return false
	var charged := false
	var released := false
	for ev: Dictionary in driver._battle_events:
		var t := String(ev.get("type", ""))
		if t == "charge":
			charged = true
		elif t == "damage" and bool(ev.get("release", false)):
			released = true
	return charged and not released


## 查剧本表：driver._battle_script(kind, round).party[unit_id]
func _party_command(actor: Dictionary) -> Dictionary:
	var script_row: Dictionary = driver._battle_script(kind, int(bc.get("round_num")))
	var party_cmds: Dictionary = script_row.get("party", {})
	var raw: Dictionary = party_cmds.get(String(actor.get("unit_id", "")), {})
	# 剧本表无此轮条目或类型缺失 → 防御兜底（防「未知指令类型」在生产端
	# 空转警告并耗死全队——第 2 轮 dryrun R9+ 实锤的死循环路径）
	if String(raw.get("type", "")).is_empty():
		return {"type": "defend"}
	var t := String(raw.get("type", "defend"))
	# ── 可用性守卫（防软锁；留痕降级）──
	if t == "skill":
		var sk_ok := false
		for sk: Variant in bc.call("available_skills", actor):
			if String(sk.get("id")) == String(raw.get("skill_id", "")):
				sk_ok = true
				break
		if not sk_ok:
			print("[R3Director] R%d %s 技能不可用（MP/习得），降级防御" % [
					int(bc.get("round_num")), String(actor.get("unit_id"))])
			return {"type": "defend"}
	elif t == "item":
		var item_ok := false
		for it: Dictionary in bc.call("available_items"):
			if String(it.get("item_id", "")) == String(raw.get("item_id", "")):
				item_ok = true
				break
		if not item_ok:
			print("[R3Director] R%d %s 道具不可用（耗尽），降级防御" % [
					int(bc.get("round_num")), String(actor.get("unit_id"))])
			return {"type": "defend"}
	return raw


## 经 O-7 通道提交指令（ui.command_selected → battle_scene._on_command_selected）。
## emit 是同步调用（直连信号）：submit_command 原子完成「行动前毒 tick +
## 指令效果」，前后快照差分 = 该角色行动的完整 _ev 系事件（通道②）。
## 【观感节奏】emit 前 dwell：此刻仍是我方回合、队列静止、敌拍定时器未
## 启动——等待零随机链风险；emit 后加延迟则会吃掉 0.9s 敌拍重播种窗口，
## 绝对不可后移。
func _submit(command: Dictionary, actor: Dictionary) -> void:
	print("[R3Director] R%d %s → %s" % [
			int(bc.get("round_num")), String(actor.get("unit_id", "?")), str(command)])
	await _sleep(COMMAND_DWELL)
	var pre: Dictionary = _snap()
	_submitted += 1
	ui.command_selected.emit(command)
	_diff(pre, _snap())
	await _wait_consumed(actor)


## 指令消费等待：提交后队列推进（同轮多人轮转）或进入敌拍（生产 0.9s 节拍）
## 或战斗结束。超时留痕不中断（主循环 _acted 锁防重发）。
func _wait_consumed(actor_before: Dictionary) -> void:
	var waited: float = 0.0
	while waited < SUBMIT_TIMEOUT:
		await _sleep(POLL_INTERVAL)
		waited += POLL_INTERVAL
		if bool(bc.get("over")):
			return
		if not bool(bc.call("is_party_turn")):
			return   # 敌拍进行中（生产链驱动）
		var now: Dictionary = bc.call("current_actor")
		if now.is_empty():
			return
		if String(now.get("unit_id", "")) != String(actor_before.get("unit_id", "")):
			return   # 我方下一位
	print("[R3Director] 指令消费等待超时（%.0fs，同行动者）——留痕继续" % SUBMIT_TIMEOUT)


func _sleep(t: float) -> void:
	await get_tree().create_timer(t).timeout
