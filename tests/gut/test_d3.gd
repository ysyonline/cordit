extends GutTest
## D3 缺陷回归用例（eng-m3demo M3 门3 录制发现）
##
## 【缺陷】battle_command.gd _do_skill() 曾用 targets_for()（目标候选列表）
##   直接遍历结算，导致：① 单体技能命中所有存活敌人（火球对双甲虫各打 40）；
##   ② 结算完全忽略玩家选中的 target_slot，UI 目标光标形同虚设。
## 【修复】新增 _resolve_skill_targets()：单体技能按 target_slot 精确命中；
##   群体技能（*_all）保持 targets_for 全体命中行为不变。
## 【兜底口径】target_slot 无效 / 未选 / 目标已死时，取对应阵营数组序
##   首个存活单位（与 targets_for 候选顺序、UI 光标初位、敌方 AI
##   _first_alive_party 的既有约定一致；GDD §3.4 未定义兜底，此为工程裁定）。
##
## 【正本】design/gdd/battle-system-gdd.md §3.4（目标规则）、§3.6（伤害公式）。
## 全部 headless 驱动 BattleCommand（RefCounted），不进场景树。
## 确定性：submit_command 显式传 variance=1.0、roll=0.0（第3/4位勿传错）。
## 伤害口径（B2 双甲虫，凯尔 Lv1 atk14 / 莉娜 Lv1 mag12 / 甲虫 def6 弱火）：
##   普攻 14*2-6=22；火球 (12*2.2-6*1.2)*1.4*1.5=40；雷爆（莉娜 Lv2 mag15）=26。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")

## 构建指定角色/等级的我方单位数组
func _party(ids: Array, levels: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in ids.size():
		var u: Dictionary = BattleUnits.build_party_unit(String(ids[i]), int(levels[i]))
		if not u.is_empty():
			out.append(u)
	return out


## 从数组取指定角色（unit_id）的实时单位
func _find(list: Array[Dictionary], unit_id: String) -> Dictionary:
	for u: Dictionary in list:
		if String(u.get("unit_id", "")) == unit_id:
			return u
	return {}


## 改某单位 hp（构造低血 / 致死场景）
func _set_hp(list: Array[Dictionary], slot: int, hp: int) -> void:
	for u: Dictionary in list:
		if int(u.get("slot", -1)) == slot:
			u["hp"] = hp


## 统计事件流中命中某单位的 damage 事件数
func _damage_events_on(res: Array, side: String, slot: int) -> int:
	var n: int = 0
	for e: Dictionary in res:
		if String(e.get("type", "")) == "damage" \
				and String(e.get("side", "")) == side and int(e.get("slot", -1)) == slot:
			n += 1
	return n


## 搭一个 B2 双甲虫战场（多敌场：正是暴露 D3 的最小场景）
func _beetle_battle(levels: Array) -> BattleCommand:
	var bc := BattleCommand.new()
	bc.setup("b2_beetles", _party(["kyle", "lina", "mona"], levels),
			BattleUnits.build_encounter("b2_beetles"))
	bc.start()
	return bc


# =============== 单体技能：只命中选定目标且只结算一次 ===============

func test_多敌场火球只命中选定甲虫且只结算一次() -> void:
	var bc := _beetle_battle([1, 1, 1])
	var hp0_before: int = bc.enemies[0]["hp"]
	var hp1_before: int = bc.enemies[1]["hp"]
	var lina: Dictionary = _find(bc.party, "lina")
	var res: Array[Dictionary] = bc.submit_command(lina,
			{"type": "skill", "skill_id": "fireball", "target_slot": 1}, 1.0, 0.0)
	assert_eq(bc.enemies[1]["hp"], hp1_before - 40, "选中的 1 号甲虫应扣 40")
	assert_eq(bc.enemies[0]["hp"], hp0_before, "未选中的 0 号甲虫不应掉血（D3 缺陷为各打 40）")
	assert_eq(_damage_events_on(res, "enemy", 0), 0, "0 号甲虫不应有 damage 事件")
	assert_eq(_damage_events_on(res, "enemy", 1), 1, "1 号甲虫应恰好结算一次")


func test_重斩单体只命中选定目标() -> void:
	var bc := _beetle_battle([2, 1, 1])   # 凯尔 Lv2 习得重斩以外的横扫，重斩 Lv1 已有
	var hp0_before: int = bc.enemies[0]["hp"]
	var hp1_before: int = bc.enemies[1]["hp"]
	var kyle: Dictionary = _find(bc.party, "kyle")
	bc.submit_command(kyle, {"type": "skill", "skill_id": "heavy_slash", "target_slot": 0}, 1.0, 0.0)
	assert_lt(bc.enemies[0]["hp"], hp0_before, "重斩（enemy_single）应命中选中的 0 号甲虫")
	assert_eq(bc.enemies[1]["hp"], hp1_before, "重斩不应波及 1 号甲虫")


# =============== 兜底口径：target_slot 无效 / 未选 / 目标已死 ===============

func test_未选目标时单体技能兜底首个存活敌方() -> void:
	var bc := _beetle_battle([1, 1, 1])
	var hp0_before: int = bc.enemies[0]["hp"]
	var hp1_before: int = bc.enemies[1]["hp"]
	var lina: Dictionary = _find(bc.party, "lina")
	# 不带 target_slot（模拟非法/旧调用路径）：兜底打数组序首个存活敌方（slot 0）
	var res: Array[Dictionary] = bc.submit_command(lina,
			{"type": "skill", "skill_id": "fireball"}, 1.0, 0.0)
	assert_eq(bc.enemies[0]["hp"], hp0_before - 40, "兜底应命中数组序首个存活敌方（0 号）")
	assert_eq(bc.enemies[1]["hp"], hp1_before, "兜底仍只命中一个目标，不回退全体")
	assert_eq(_damage_events_on(res, "enemy", 1), 0, "兜底不应产生对 1 号的伤害事件")


func test_指定目标已死亡时兜底首个存活敌方() -> void:
	var bc := _beetle_battle([1, 1, 1])
	_set_hp(bc.enemies, 0, 0)   # 0 号甲虫先死
	var hp1_before: int = bc.enemies[1]["hp"]
	var lina: Dictionary = _find(bc.party, "lina")
	var res: Array[Dictionary] = bc.submit_command(lina,
			{"type": "skill", "skill_id": "fireball", "target_slot": 0}, 1.0, 0.0)
	assert_eq(bc.enemies[1]["hp"], hp1_before - 40, "选定目标已死应兜底到首个存活敌方（1 号）")
	assert_eq(_damage_events_on(res, "enemy", 1), 1, "兜底目标应恰好结算一次")


func test_无效target_slot时单体技能兜底首个存活敌方() -> void:
	var bc := _beetle_battle([1, 1, 1])
	var hp0_before: int = bc.enemies[0]["hp"]
	var lina: Dictionary = _find(bc.party, "lina")
	bc.submit_command(lina, {"type": "skill", "skill_id": "fireball", "target_slot": 99}, 1.0, 0.0)
	assert_eq(bc.enemies[0]["hp"], hp0_before - 40, "越界 slot 应兜底到首个存活敌方")


# =============== 单体 / 群体治疗 ===============

func test_单体治疗只命中选定我方() -> void:
	var bc := _beetle_battle([1, 1, 3])   # 莫娜 Lv3 已习得治疗（v1.1 重排）
	var mona: Dictionary = _find(bc.party, "mona")
	mona["mp"] = maxi(int(mona.get("mp", 0)), 20)   # 隔离 MP 因素
	_set_hp(bc.party, 0, 10)
	_set_hp(bc.party, 1, 10)
	bc.submit_command(mona, {"type": "skill", "skill_id": "heal", "target_slot": 1}, 1.0, 0.0)
	assert_gt(bc.party[1]["hp"], 10, "选中的莉娜应被治疗")
	assert_eq(bc.party[0]["hp"], 10, "未选中的凯尔不应被治疗（修复前 ally_single 会奶全队）")


func test_单体治疗未选目标时兜底首个存活我方() -> void:
	var bc := _beetle_battle([1, 1, 3])
	var mona: Dictionary = _find(bc.party, "mona")
	mona["mp"] = maxi(int(mona.get("mp", 0)), 20)
	_set_hp(bc.party, 0, 10)
	_set_hp(bc.party, 1, 10)
	bc.submit_command(mona, {"type": "skill", "skill_id": "heal"}, 1.0, 0.0)
	assert_gt(bc.party[0]["hp"], 10, "兜底应治疗数组序首个存活我方（凯尔）")
	assert_eq(bc.party[1]["hp"], 10, "兜底仍只治疗一个目标")


func test_群愈仍命中全体我方() -> void:
	var bc := _beetle_battle([1, 1, 3])
	var mona: Dictionary = _find(bc.party, "mona")
	mona["mp"] = maxi(int(mona.get("mp", 0)), 30)
	_set_hp(bc.party, 0, 10)
	_set_hp(bc.party, 1, 10)
	_set_hp(bc.party, 2, 10)
	bc.submit_command(mona, {"type": "skill", "skill_id": "group_heal"}, 1.0, 0.0)
	assert_gt(bc.party[0]["hp"], 10, "群愈（ally_all）应治疗凯尔")
	assert_gt(bc.party[1]["hp"], 10, "群愈应治疗莉娜")
	assert_gt(bc.party[2]["hp"], 10, "群愈应治疗莫娜")


# =============== 群体技能：保持全体命中行为不变 ===============

func test_雷爆仍命中全体敌人且无视target_slot() -> void:
	var bc := _beetle_battle([1, 2, 1])   # 莉娜 Lv2 习得雷爆
	var hp0_before: int = bc.enemies[0]["hp"]
	var hp1_before: int = bc.enemies[1]["hp"]
	var lina: Dictionary = _find(bc.party, "lina")
	lina["mp"] = maxi(int(lina.get("mp", 0)), 20)
	var res: Array[Dictionary] = bc.submit_command(lina,
			{"type": "skill", "skill_id": "thunder_burst", "target_slot": 0}, 1.0, 0.0)
	# 莉娜 Lv2 mag15：(15*2.2-6*1.2)*1.0 = 25.8 → 26（雷属性中性，无弱点加成）
	assert_eq(bc.enemies[0]["hp"], hp0_before - 26, "雷爆（enemy_all，power1.0 中性）0 号应扣 26")
	assert_eq(bc.enemies[1]["hp"], hp1_before - 26, "雷爆 1 号应同样扣 26，群体行为不变")
	assert_eq(_damage_events_on(res, "enemy", 0) + _damage_events_on(res, "enemy", 1), 2,
			"雷爆应恰好结算两次（每个甲虫各一次）")


func test_横扫仍命中全体敌人() -> void:
	var bc := _beetle_battle([2, 1, 1])   # 凯尔 Lv2 习得横扫
	var hp0_before: int = bc.enemies[0]["hp"]
	var hp1_before: int = bc.enemies[1]["hp"]
	var kyle: Dictionary = _find(bc.party, "kyle")
	kyle["mp"] = maxi(int(kyle.get("mp", 0)), 20)
	bc.submit_command(kyle, {"type": "skill", "skill_id": "wide_sweep", "target_slot": 1}, 1.0, 0.0)
	assert_lt(bc.enemies[0]["hp"], hp0_before, "横扫（enemy_all）应命中 0 号甲虫")
	assert_lt(bc.enemies[1]["hp"], hp1_before, "横扫应命中 1 号甲虫（target_slot 对群体技能无效）")


# =============== 连带核查：普攻 / 敌方 AI 目标规则未受影响 ===============

func test_普攻仍按target_slot单体命中() -> void:
	var bc := _beetle_battle([1, 1, 1])
	var hp0_before: int = bc.enemies[0]["hp"]
	var hp1_before: int = bc.enemies[1]["hp"]
	var kyle: Dictionary = _find(bc.party, "kyle")
	bc.submit_command(kyle, {"type": "attack", "target_slot": 1}, 1.0, 0.0)
	assert_eq(bc.enemies[1]["hp"], hp1_before - 22, "普攻打 1 号甲虫：14*2-6=22")
	assert_eq(bc.enemies[0]["hp"], hp0_before, "普攻不应波及 0 号甲虫")


func test_敌方单体攻击打首个存活我方() -> void:
	var bc := _beetle_battle([1, 1, 1])
	var beetle: Dictionary = bc.enemies[0]
	var kyle_hp_before: int = bc.party[0]["hp"]
	var lina_hp_before: int = bc.party[1]["hp"]
	# 甲虫 ai_weights = {"attack": 100}，roll_action=0.0 必抽 attack（单体）
	bc.enemy_action(beetle, 0.0, 1.0)
	assert_lt(bc.party[0]["hp"], kyle_hp_before, "敌方单体应打首个存活我方（凯尔，既有约定不变）")
	assert_eq(bc.party[1]["hp"], lina_hp_before, "敌方单体不应波及莉娜")


func test_敌方群体横扫仍打全体我方() -> void:
	var bc := _beetle_battle([1, 1, 1])
	var beetle: Dictionary = bc.enemies[0]
	# sweep 为敌方行为目录键（甲虫权重里没有，直接驱动 _enemy_sweep 验证行为口径）
	var entry: Dictionary = {"power": 1.0}
	var events: Array[Dictionary] = bc._enemy_sweep(beetle, entry, 1.0)
	var hits: int = 0
	for e: Dictionary in events:
		if String(e.get("type", "")) == "damage" and String(e.get("side", "")) == "party":
			hits += 1
	assert_eq(hits, 3, "敌方横扫应命中我方全体三人（行为不变）")
