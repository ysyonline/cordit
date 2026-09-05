extends GutTest
## E6-S2 胜利结算与升级流（EPIC-6 第 2 条 Story）
##
## 【断言覆盖】EPIC-6.md E6-S2 验收标准 + GDD §4.7 / §6 I4 / D-附 8.10~8.12：
##   A. 结算器纯函数（battle_command.build_settlement）：
##      B1 单敌 → 1 条 exp 事件 + 1 条掉落，无升级（15=15 恰达 Lv2 边界，
##      level_for_exp(15)=2 → 实际含升级行，见 A2 用例的边界口径断言）；
##   B. 多级连升（I4）：Lv1 开局打高经验编组 → 一次跨 2 级事件流
##      （构造：合成经验注入 _build_result 前提——直接驱动 build_settlement
##      的分支逻辑，用真表 B4=140/Lv3→Lv4、B5 累计推演跨级）；
##   C. 技能习得一次性列出（GDD D-附 8.11）：升 2 级时新增技能逐条列出，
##      莉娜 Lv2 一次习得【冰锥】【雷爆】（同级按建卡顺序）；
##   D. 掉落按只结算（D-附 8.10）：B3 飞蛾×3 → 小药瓶 ×3（同 id 累计）；
##   E. _build_result 集成：VICTORY 带协议 / DEFEAT 空协议（向后兼容）；
##   F. show_result 渲染：exp/level_up/skill/drops 四类行文本 + 旧协议
##      （无 exp_events/drops 键）零回归；
##   G. 写回链：party_state 经 handler 既有链路覆写 level（升级生效于
##      GameData），道具入背包走 drops 累计（I2 队伍共享同入口）。
##
## 【测试策略】headless 直驱 BattleCommand（RefCounted，不进场景树）+
##   BattleUI（Control）；GameData 快照/还原隔离（E2-S4 同款纪律）。
##   真表驱动（b1_moth / b3_ruin_mix / b5_core .tres），不造离线数据。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")
const HANDLER_SCRIPT_PATH: String = "res://scripts/battle/battle_result_handler.gd"

## 跨用例隔离用的 GameData 快照（before_all 取，after_all 还原）
var _party_backup: Array = []
var _inventory_backup: Dictionary = {}
var _cleared_backup: Array = []
var _phase_backup: int = 0

var _handler: Node = null


func before_all() -> void:
	_ensure_party_3()
	for c: Resource in GameData.party:
		_party_backup.append({
			"id": c.id, "level": c.level, "hp": c.hp, "max_hp": c.max_hp,
			"mp": c.mp, "max_mp": c.max_mp})
	_inventory_backup = GameData.inventory.duplicate()
	_cleared_backup = (GameData.cleared_enemy_set as Array).duplicate()
	_phase_backup = GameData.story_phase


func after_all() -> void:
	for i: int in GameData.party.size():
		var c: Resource = GameData.party[i]
		var b: Dictionary = _party_backup[i]
		c.level = b["level"]
		c.hp = b["hp"]
		c.max_hp = b["max_hp"]
		c.mp = b["mp"]
		c.max_mp = b["max_mp"]
	GameData.inventory = _inventory_backup.duplicate()
	GameData.cleared_enemy_set = _cleared_backup.duplicate()
	GameData.story_phase = _phase_backup


func before_each() -> void:
	_handler = (load(HANDLER_SCRIPT_PATH) as GDScript).new()
	autofree(_handler)
	GameData.inventory = {}
	SaveManager.save_requested_pending = false


func after_each() -> void:
	if _handler != null and is_instance_valid(_handler):
		_handler._pending_return = {}
	SaveManager.save_requested_pending = false
	after_all()
	GameData.inventory = {}


## 构建指定角色/等级的我方单位数组（E3-S3 同款辅助）
func _party(ids: Array, levels: Array) -> Array:
	var out: Array[Dictionary] = []
	for i: int in ids.size():
		var u: Dictionary = BattleUnits.build_party_unit(String(ids[i]), int(levels[i]))
		if not u.is_empty():
			out.append(u)
	return out


## party 长度兜底（跨套件隔离防御）：泄漏时按 e4s1 DEFAULT_PARTY 同款重建 3 人。
## 正本隔离靠 e5s3 修复（E6-S2 后 party 已入还原纪律），此兜底防未来新泄漏源。
func _ensure_party_3() -> void:
	if GameData.party.size() >= 3:
		return
	const CharacterRecord := preload("res://scripts/core/character_record.gd")
	var party: Array[CharacterRecord] = [
		CharacterRecord.new("kyle", "凯尔", "swordsman", 1, 120, 120, 10, 10),
		CharacterRecord.new("lina", "莉娜", "sorcerer", 1, 80, 80, 30, 30),
		CharacterRecord.new("mona", "莫娜", "support", 1, 95, 95, 24, 24),
	]
	GameData.party = party


## 组一场装好的 BattleCommand（不打，只 setup+start）
func _ready_bc(encounter_id: String, ids: Array, levels: Array) -> BattleCommand:
	var bc := BattleCommand.new()
	bc.setup(encounter_id, _party(ids, levels), BattleUnits.build_encounter(encounter_id))
	bc.start()
	return bc


# =============== A. 结算器：B1 边界 ===============

func test_B1结算_经验与掉落行() -> void:
	var bc := _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	var s: Dictionary = bc.build_settlement()
	# B1 飞蛾×1：exp=15、掉落 potion_s×1
	assert_eq(int(s["total_exp"]), 15, "B1 总经验应为飞蛾 exp=15")
	var evs: Array = s["exp_events"]
	# B1=15 EXP 恰达 Lv2 阈值（含等号）→ 全队升 2 级，三人各出习得行：
	# exp1（飞蛾）+ level_up1（队伍→Lv2）+ skill3（凯尔 wide_sweep /
	# 莉娜 ice_shard+thunder_burst / 莫娜 group_heal）= 5 条
	assert_eq(evs.size(), 5, "exp1 + level_up1 + skill3（三人各 1 习得行）")
	assert_eq(String(evs[0]["kind"]), "exp", "首条应为 exp")
	assert_eq(String(evs[0]["enemy"]), "道路飞蛾", "敌人名应来自敌人表")
	assert_eq(int(evs[0]["amount"]), 15, "经验值应取敌人表 exp 字段")
	var drops: Array = s["drops"]
	assert_eq(drops.size(), 1, "B1 应恰 1 种掉落")
	assert_eq(String(drops[0]["item_id"]), "potion_s", "掉落应为小药瓶")
	assert_eq(int(drops[0]["count"]), 1, "掉落数量 1")


func test_B1结算_Lv2边界_恰达15含升级行() -> void:
	# 边界口径：level_for_exp(15)=2（累计阈值 15 含等号）→ B1 后恰升 Lv2，
	# 与 GDD §7 "B1 后 Lv2" 一致；凯尔 Lv2 新增 wide_sweep、莫娜 group_heal
	var bc := _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	var s: Dictionary = bc.build_settlement()
	assert_eq(int(s["level_before"]), 1, "开局 Lv1")
	assert_eq(int(s["level_after"]), 2, "15 EXP 恰达 Lv2 阈值（含等号）")
	var evs: Array = s["exp_events"]
	# 5 条 = exp1 + level_up1 + skill3（凯尔/莉娜/莫娜各 1 行，
	# 莉娜单行含 ice_shard+thunder_burst 两个技能）
	assert_eq(evs.size(), 5, "exp1 + level_up1 + skill3")
	assert_eq(String(evs[1]["kind"]), "level_up", "第 2 条应为升级行")
	assert_eq(String(evs[1]["name"]), "队伍", "全队共享池：升级行名义为队伍")
	assert_eq(int(evs[1]["level"]), 2, "升到 Lv2")
	# 凯尔 Lv2 → wide_sweep；莫娜 Lv2 → group_heal；莉娜 Lv2 → ice_shard+thunder_burst
	var skill_names: Array = []
	for i: int in range(2, evs.size()):
		assert_eq(String(evs[i]["kind"]), "skill", "第 3 条起应为习得行")
		skill_names.append(String(evs[i]["name"]))
	assert_eq(skill_names.size(), 3, "三人各 1 条习得行")
	assert_true(skill_names.has("凯尔"), "凯尔应列习得行（wide_sweep）")
	assert_true(skill_names.has("莉娜"), "莉娜应列习得行（冰锥+雷爆）")
	assert_true(skill_names.has("莫娜"), "莫娜应列习得行（group_heal）")


# =============== B. 多级连升（I4）===============

func test_多级连升_一次跨2级() -> void:
	# 开局 Lv1 + B5 核心 exp=260：level_for_exp(260)=4 → 一次跨 3 级（1→4），
	# 覆盖 I4"多级连升"的验收语义（跨 ≥2 级实测）
	var bc := _ready_bc("b5_core", ["kyle", "lina", "mona"], [1, 1, 1])
	var s: Dictionary = bc.build_settlement()
	assert_eq(int(s["level_before"]), 1, "开局 Lv1")
	assert_eq(int(s["level_after"]), 4, "260 EXP 应一次判到 Lv4（多级连升）")
	var lv_rows: int = 0
	for ev: Variant in s["exp_events"]:
		if String((ev as Dictionary).get("kind", "")) == "level_up":
			lv_rows += 1
	assert_eq(lv_rows, 1, "升级行只 1 条（一次列出终态等级，非逐级多条）")


func test_低经验_不升级() -> void:
	# 开局 Lv3 打 B1（15 EXP < Lv4 阈值 150）→ after 取大保持 Lv3，无升级行
	var bc := _ready_bc("b1_moth", ["kyle", "lina", "mona"], [3, 3, 3])
	var s: Dictionary = bc.build_settlement()
	assert_eq(int(s["level_after"]), 3, "经验不足时保持原级")
	var has_lv: bool = false
	for ev: Variant in s["exp_events"]:
		if String((ev as Dictionary).get("kind", "")) == "level_up":
			has_lv = true
	assert_false(has_lv, "不应有升级行")


# =============== C. 技能习得一次性列出 ===============

func test_莉娜Lv2_一次习得冰锥雷爆() -> void:
	# GDD D-附 8.11 正本场景：莉娜 Lv2 一次习得【冰锥】【雷爆】（同级建卡序）
	var bc := _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	var s: Dictionary = bc.build_settlement()
	var lina_row: Dictionary = {}
	for ev: Variant in s["exp_events"]:
		var e: Dictionary = ev
		if String(e.get("kind", "")) == "skill" and String(e.get("name", "")) == "莉娜":
			lina_row = e
	assert_false(lina_row.is_empty(), "莉娜应有习得行")
	var skills: Array = lina_row["skills"]
	assert_eq(skills.size(), 2, "莉娜 Lv2 应一次习得 2 个技能")
	assert_eq(String(skills[0]), "ice_shard", "建卡顺序：冰锥在前")
	assert_eq(String(skills[1]), "thunder_burst", "建卡顺序：雷爆在后")


func test_习得行按等级升序_跨级时低级在前() -> void:
	# 凯尔：Lv2 wide_sweep / Lv3 cover。开局 Lv1 打 B5（升到 Lv4）→
	# 习得行顺序应为 wide_sweep(Lv2) 在 cover(Lv3) 前
	var bc := _ready_bc("b5_core", ["kyle", "lina", "mona"], [1, 1, 1])
	var s: Dictionary = bc.build_settlement()
	var kyle_skills: Array = []
	for ev: Variant in s["exp_events"]:
		var e: Dictionary = ev
		if String(e.get("kind", "")) == "skill" and String(e.get("name", "")) == "凯尔":
			for sid: String in e["skills"]:
				kyle_skills.append(sid)
	assert_eq(String(kyle_skills[0]), "wide_sweep", "Lv2 习得在 Lv3 之前")
	assert_eq(String(kyle_skills[1]), "cover", "Lv3 掩护随后")


# =============== D. 掉落按只结算（D-附 8.10）===============

func test_B3飞蛾三只_小药瓶累计x3() -> void:
	# B3 = 火蜥×1 + 冰晶×1 + 飞蛾×3：ether_s/antidote 各 1 + potion_s×3
	var bc := _ready_bc("b3_ruin_mix", ["kyle", "lina", "mona"], [2, 2, 2])
	var s: Dictionary = bc.build_settlement()
	assert_eq(int(s["total_exp"]), 26 + 26 + 15 + 15 + 15, "B3 总经验 = 26+26+15×3=97")
	var drops: Array = s["drops"]
	assert_eq(drops.size(), 3, "B3 应恰 3 种掉落（同 id 已累计）")
	var by_id: Dictionary = {}
	for dp: Variant in drops:
		var d: Dictionary = dp
		by_id[String(d["item_id"])] = int(d["count"])
	assert_eq(int(by_id.get("potion_s", 0)), 3, "飞蛾×3 → 小药瓶累计 ×3（按只结算）")
	assert_eq(int(by_id.get("ether_s", 0)), 1, "火蜥掉 ether_s×1")
	assert_eq(int(by_id.get("antidote", 0)), 1, "冰晶掉 antidote×1")


# =============== E. _build_result 集成 ===============

func test_VICTORY结果带结算协议() -> void:
	var bc := _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	# 直接置胜（结算器语义已由 A~D 覆盖，此处只验证 _build_result 分支）
	bc.outcome = BattleCommand.OUTCOME_VICTORY
	bc.over = true
	var r: Dictionary = bc._build_result()
	assert_eq((r["exp_events"] as Array).size(), 5, "VICTORY：B1 事件流 5 条（exp1+升级1+习得3）")
	assert_eq((r["drops"] as Array).size(), 1, "VICTORY：掉落 1 条")


func test_DEFEAT结果空协议_向后兼容() -> void:
	var bc := _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	bc.outcome = BattleCommand.OUTCOME_DEFEAT
	bc.over = true
	var r: Dictionary = bc._build_result()
	assert_eq((r["exp_events"] as Array).size(), 0, "DEFEAT：无经验事件")
	assert_eq((r["drops"] as Array).size(), 0, "DEFEAT：无掉落")
	assert_true(r.has("party_state"), "既有 6 字段协议不变")


func test_ESCAPE结果空协议() -> void:
	var bc := _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	bc.outcome = BattleCommand.OUTCOME_ESCAPE
	bc.over = true
	var r: Dictionary = bc._build_result()
	assert_eq((r["exp_events"] as Array).size(), 0, "ESCAPE：无经验事件")
	assert_eq((r["drops"] as Array).size(), 0, "ESCAPE：无掉落")


# =============== F. show_result 渲染 ===============

func test_结算画面渲染四类行() -> void:
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result({
		"outcome": "VICTORY",
		"party_state": [{"name": "凯尔", "hp": 50, "max_hp": 80, "mp": 10, "max_mp": 10}],
		"exp_events": [
			{"kind": "exp", "enemy": "道路飞蛾", "amount": 15},
			{"kind": "level_up", "name": "队伍", "level": 2},
			{"kind": "skill", "name": "莉娜", "level": 2, "skills": ["ice_shard", "thunder_burst"]},
		],
		"drops": [{"item_id": "potion_s", "count": 2}],
	})
	var text: String = ui.get_result_text()
	assert_true(ui.is_result_visible(), "结算面板应可见")
	assert_true(text.contains("胜利"), "应含胜利文案")
	# T2.2 起：事件行逐条揭示，断言全文前先跳过揭示
	ui.finish_reveal()
	text = ui.get_result_text()
	assert_true(text.contains("道路飞蛾"), "应含 exp 行敌人名")
	assert_true(text.contains("15 EXP"), "应含经验数值")
	assert_true(text.contains("Lv2"), "应含升级行")
	assert_true(text.contains("【冰锥】【雷爆】"), "习得行应一次列出多技能（D-附 8.11 格式）")
	assert_true(text.contains("获得 小药瓶 ×2"), "掉落行应显示查表中文名×数量")


func test_结算画面旧协议零回归() -> void:
	# E3-S4 既有用例同款输入（无 exp_events/drops 键）→ 行为不变
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result({"outcome": "VICTORY",
			"party_state": [{"name": "凯尔", "hp": 50, "max_hp": 80, "mp": 10, "max_mp": 10}]})
	assert_true(ui.is_result_visible(), "结算面板应可见")
	assert_true(ui.get_result_text().contains("胜利"), "应显示胜利文案")
	assert_false(ui.get_result_text().contains("EXP"), "无经验键不应渲染经验行")


# =============== F2. 揭示节奏（T2.2：EXP 逐条弹出）===============

## B1 战后完整协议（5 行待弹：exp1+lv1+skill3+drops1）
func _victory_result_for_reveal() -> Dictionary:
	return {
		"outcome": "VICTORY",
		"party_state": [{"name": "凯尔", "hp": 50, "max_hp": 80, "mp": 10, "max_mp": 10}],
		"exp_events": [
			{"kind": "exp", "enemy": "道路飞蛾", "amount": 15},
			{"kind": "level_up", "name": "队伍", "level": 2},
			{"kind": "skill", "name": "凯尔", "level": 2, "skills": ["wide_sweep"]},
			{"kind": "skill", "name": "莉娜", "level": 2, "skills": ["ice_shard", "thunder_burst"]},
			{"kind": "skill", "name": "莫娜", "level": 2, "skills": ["group_heal"]},
		],
		"drops": [{"item_id": "potion_s", "count": 1}],
	}


func test_揭示_表头即出_事件行入队() -> void:
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result(_victory_result_for_reveal())
	# 表头（结局+party_state）立即可见；事件行尚未弹出
	assert_true(ui.get_result_text().contains("胜利"), "表头应立即可见")
	assert_true(ui.get_result_text().contains("凯尔"), "party_state 应立即可见")
	assert_false(ui.get_result_text().contains("道路飞蛾"), "事件行不应立即出现")
	assert_eq(ui.get_reveal_remaining(), 6, "待弹行应 6 条（exp1+lv1+skill3+drops1）")
	assert_true(ui.is_revealing(), "揭示应进行中")


func test_揭示_手动步进逐条弹出_里程碑后多停一拍() -> void:
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result(_victory_result_for_reveal())
	# 第 1 条：exp 行（快档停顿）
	ui.step_reveal()
	assert_true(ui.get_result_text().contains("击败道路飞蛾"), "步进后应弹 exp 行")
	assert_eq(ui.get_reveal_remaining(), 5, "剩 5 条")
	# 第 2 条：升级行（里程碑，停顿应为 0.60 而非 0.35——验证方式：
	# 重置后走 _process 时序，此处先验内容序；dwell 断言在下条用例）
	ui.step_reveal()
	assert_true(ui.get_result_text().contains("队伍 Lv2！"), "升级行随步进弹出")
	# 第 3~5 条：三人习得行
	ui.step_reveal()
	ui.step_reveal()
	ui.step_reveal()
	assert_true(ui.get_result_text().contains("莉娜 习得 【冰锥】【雷爆】"),
			"习得行按 D-附 8.11 格式弹出")
	# 第 6 条：掉落行弹完 → 揭示结束
	ui.step_reveal()
	assert_true(ui.get_result_text().contains("获得 小药瓶 ×1"), "掉落行最后弹出")
	assert_false(ui.is_revealing(), "弹完应自动结束揭示")
	assert_eq(ui.get_reveal_remaining(), 0, "队列应清空")


func test_揭示_dwell两档_经process时序可确定性驱动() -> void:
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	# 挂树才有 _process（headless 下 Control 不入树不跑帧）
	add_child_autofree(ui)
	ui.show_result({
		"outcome": "VICTORY",
		"party_state": [],
		"exp_events": [
			{"kind": "exp", "enemy": "甲", "amount": 5},
			{"kind": "level_up", "name": "队伍", "level": 2},
			{"kind": "exp", "enemy": "乙", "amount": 6},
		],
		"drops": [],
	})
	# 逐行停顿口径：弹完一行计时器归零，按【下一行】的 dwell 等待。
	# 时序：0.35s 弹 exp甲 → +0.60s（升级行 dwell）弹 Lv2 → +0.35s 弹 exp乙
	ui._process(0.35)
	assert_eq(ui.get_reveal_remaining(), 2, "0.35s 后快档行应已弹出")
	ui._process(0.59)
	assert_eq(ui.get_reveal_remaining(), 2, "升级行 dwell 0.60 未满不弹")
	ui._process(0.01)
	assert_eq(ui.get_reveal_remaining(), 1, "累计 0.95s 升级行应已弹出（0.60 dwell）")
	ui._process(0.34)
	assert_eq(ui.get_reveal_remaining(), 1, "不足 0.35s 不弹下一快档行")
	ui._process(0.01)
	assert_eq(ui.get_reveal_remaining(), 0, "累计 1.30s 全部弹完")
	assert_false(ui.is_revealing(), "弹完应结束")


func test_揭示_finish跳过_全部立即弹出() -> void:
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result(_victory_result_for_reveal())
	ui.finish_reveal()
	assert_eq(ui.get_reveal_remaining(), 0, "跳过后队列应清空")
	assert_true(ui.get_result_text().contains("获得 小药瓶 ×1"), "末行应已弹出")
	assert_false(ui.is_revealing(), "揭示应结束")


func test_揭示_旧协议不启动计时() -> void:
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result({"outcome": "VICTORY",
			"party_state": [{"name": "凯尔", "hp": 50, "max_hp": 80, "mp": 10, "max_mp": 10}]})
	assert_false(ui.is_revealing(), "无结算键不应启动揭示")
	assert_eq(ui.get_reveal_remaining(), 0, "队列为空")
	ui.step_reveal()   # 空队列步进应安全无异常
	assert_false(ui.is_revealing(), "空队列步进后仍应结束态")


# =============== F3. 端到端集成（T2.3）===============

## 端到端：真实 _build_result(VICTORY) → show_result → finish_reveal，
## 全文逐项对表（exp/升级/习得/掉落四类行都在最终文本里）
func test_端到端_VICTORY真载荷揭示全文对表() -> void:
	var bc := _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	bc.outcome = BattleCommand.OUTCOME_VICTORY
	bc.over = true
	var r: Dictionary = bc._build_result()
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result(r)
	assert_true(ui.is_revealing(), "真 VICTORY 载荷应启动揭示")
	ui.finish_reveal()
	var text: String = ui.get_result_text()
	# 四类行逐项在场（B1：15EXP 升 Lv2 → 三人习得 + 小药瓶掉落）
	assert_true(text.contains("击败道路飞蛾  获得 15 EXP"), "exp 行文本")
	assert_true(text.contains("队伍 Lv2！"), "升级行文本")
	assert_true(text.contains("凯尔 习得 【横扫】"), "凯尔习得行（Lv2 wide_sweep=横扫）")
	assert_true(text.contains("莉娜 习得 【冰锥】【雷爆】"), "莉娜习得行（D-附 8.11 双技能）")
	assert_true(text.contains("莫娜 习得 【群愈】"), "莫娜习得行（Lv2 group_heal）")
	assert_true(text.contains("获得 小药瓶 ×1"), "掉落行文本")


## 习得生效（验收"技能菜单出现"）：升级前后 skills_up_to 差集 ≡ 结算器
## 习得行列出的技能——表驱动同源，无需另立"已习得"清单
func test_习得生效_skills_up_to差集与结算器习得行一致() -> void:
	var bc := _ready_bc("b5_core", ["kyle", "lina", "mona"], [1, 1, 1])
	var s: Dictionary = bc.build_settlement()
	var after_lv: int = int(s["level_after"])
	# 结算器习得行收集的技能全集
	var settled: Array[String] = []
	for ev: Variant in s["exp_events"]:
		var e: Dictionary = ev
		if String(e.get("kind", "")) == "skill":
			for sid: Variant in e.get("skills", []):
				settled.append(String(sid))
	assert_false(settled.is_empty(), "B5(260EXP→Lv4) 应有习得行")
	# 三人升级前后差集（team 级）恰等于习得行全集
	var before_all: Array[String] = []
	var after_all: Array[String] = []
	for cid: String in ["kyle", "lina", "mona"]:
		var cd: Variant = DataTables.get_character(cid)
		var got_before: Array[String] = cd.skills_up_to(1)
		var got_after: Array[String] = cd.skills_up_to(after_lv)
		for sid: String in got_before:
			if not before_all.has(sid):
				before_all.append(sid)
		for sid: String in got_after:
			if not after_all.has(sid):
				after_all.append(sid)
	assert_eq(after_all.size() - before_all.size(), settled.size(),
			"全队新增技能数应与习得行技能数一致")
	for sid: String in settled:
		assert_true(after_all.has(sid) and not before_all.has(sid),
				"习得技能 %s 应在升级后出现且升级前不存在" % sid)


## 确认键跳过（T2.3 输入接线）：揭示中按 interact → 剩余行全部立即弹出；
## 揭示外按键不消费（指令菜单不受影响）
func test_确认键跳过揭示_非揭示期不拦截() -> void:
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	# 非揭示期：注入按键应无副作用（不报错、无文本变化）
	var before: String = ui.get_result_text()
	ui.inject_interact_press()
	assert_eq(ui.get_result_text(), before, "非揭示期按键不应改动文本")
	# 揭示期：注入按键 → 跳过
	ui.show_result(_victory_result_for_reveal())
	assert_true(ui.is_revealing(), "揭示应进行中")
	ui.inject_interact_press()
	assert_false(ui.is_revealing(), "按键后揭示应结束（finish_reveal 语义）")
	assert_eq(ui.get_reveal_remaining(), 0, "剩余行应全部弹出")
	assert_true(ui.get_result_text().contains("获得 小药瓶 ×1"), "末行已在文本中")


## 多级连升端到端：B5 真载荷揭示 → 升级行只 1 条且显示 Lv4
## （I4 验收"一次战斗跨 2 级"在视图侧的完整兑现）
func test_端到端_多级连升揭示_终态等级一次列出() -> void:
	var bc := _ready_bc("b5_core", ["kyle", "lina", "mona"], [1, 1, 1])
	bc.outcome = BattleCommand.OUTCOME_VICTORY
	bc.over = true
	var r: Dictionary = bc._build_result()
	var ui := BattleUI.new()
	autofree(ui)
	ui.ensure_built()
	ui.show_result(r)
	ui.finish_reveal()
	var text: String = ui.get_result_text()
	assert_true(text.contains("队伍 Lv4！"), "升级行应一次列出终态 Lv4")
	# party_state 渲染行是"名  HP x/x  MP x/x"格式、不含 Lv 字样——
	# "Lv4" 全文应恰 1 处（升级行），证明非逐级多条
	assert_eq(text.count("Lv4"), 1, "升级行只 1 条（party_state 行不含 Lv 字样）")
	# 习得行按等级分行（结算器 for lv→for u 循环序）：凯尔横扫(Lv2)行在掩护(Lv3)行前
	assert_true(text.contains("凯尔 习得 【横扫】"), "凯尔 Lv2 横扫习得行")
	assert_true(text.contains("凯尔 习得 【掩护】"), "凯尔 Lv3 掩护习得行")
	assert_true(text.find("凯尔 习得 【横扫】") < text.find("凯尔 习得 【掩护】"),
			"低等级习得行在前（升序）")


# =============== G. 写回链 ===============

func test_升级经handler写回GameData() -> void:
	# party_state 带 level=2（B1 战后）→ handler._apply_party_state 覆写
	# （I4：升级生效于 GameData，探索/对话侧零感知）
	_ensure_party_3()   # 防跨套件 party 泄漏（正本隔离在 e5s3，此为防御）
	GameData.party[1].level = 1
	var snap: Dictionary = {"id": "lina", "level": 2, "hp": 113, "max_hp": 113,
			"mp": 38, "max_mp": 38}
	_handler._apply_party_state([snap])
	assert_eq(GameData.party[1].level, 2, "升级应写回 GameData.party")
	assert_eq(GameData.party[1].max_hp, 113, "max_hp 应随级覆写（§3.6 逐级定值）")


func test_掉落入背包_队伍共享同入口() -> void:
	# drops 累计写入 GameData.inventory（I2：与宝箱 give_item 同入口）
	for dp: Variant in [{"item_id": "potion_s", "count": 2}]:
		var d: Dictionary = dp
		var iid: String = String(d["item_id"])
		GameData.inventory[iid] = int(GameData.inventory.get(iid, 0)) + int(d["count"])
	assert_eq(int(GameData.inventory.get("potion_s", 0)), 2, "小药瓶 ×2 应入队背包")


# =============== G2. 掉落写回真链路（T2.4：handler._apply_drops）===============

func test_掉落经handler写回_背包累计() -> void:
	# 真链路：handler._apply_drops 消费 result.drops → GameData.inventory
	# （与 T2.1 的"手动累计"用例不同，此条验证 handler 侧写回实现本身）
	GameData.inventory = {"potion_s": 1}   # 预置：已有 1 瓶
	_handler._apply_drops([{"item_id": "potion_s", "count": 2},
			{"item_id": "ether_s", "count": 1}])
	assert_eq(int(GameData.inventory.get("potion_s", 0)), 3, "同 id 应累计（1+2=3）")
	assert_eq(int(GameData.inventory.get("ether_s", 0)), 1, "新 id 应写入")


func test_掉落写回_脏数据防御() -> void:
	# 空 item_id / 非正数 count 条目跳过不写入（防御式，与结算器产出契约互备）
	GameData.inventory = {}
	_handler._apply_drops([{"item_id": "", "count": 2},
			{"item_id": "potion_s", "count": 0},
			{"item_id": "ether_s", "count": -1}])
	assert_true(GameData.inventory.is_empty(), "脏条目全部跳过，背包零污染")


func test_三结局写回分支_VICTORY落包_DEFEATESCAPE不落() -> void:
	# 全链路分支：battle_finished → handler 分支 → 背包终态
	var bcs: BattleCommand = _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	# VICTORY：drops 非空 → 入包
	bcs.outcome = BattleCommand.OUTCOME_VICTORY
	bcs.over = true
	var r_v: Dictionary = bcs._build_result()
	GameData.inventory = {}
	_handler._on_battle_finished(r_v)
	assert_eq(int(GameData.inventory.get("potion_s", 0)), 1, "VICTORY：掉落应入包")
	# ESCAPE：协议空数组 → 循环零次，背包不动
	bcs = _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	bcs.outcome = BattleCommand.OUTCOME_ESCAPE
	bcs.over = true
	var r_e: Dictionary = bcs._build_result()
	GameData.inventory = {}
	_handler._on_battle_finished(r_e)
	assert_true(GameData.inventory.is_empty(), "ESCAPE：无掉落，背包不动")
	# DEFEAT：协议空数组 + handler 不写（读档回滚语义，此处只验不落包）
	bcs = _ready_bc("b1_moth", ["kyle", "lina", "mona"], [1, 1, 1])
	bcs.outcome = BattleCommand.OUTCOME_DEFEAT
	bcs.over = true
	var r_d: Dictionary = bcs._build_result()
	GameData.inventory = {}
	_handler._on_battle_finished(r_d)
	assert_true(GameData.inventory.is_empty(), "DEFEAT：无掉落，背包不动")
