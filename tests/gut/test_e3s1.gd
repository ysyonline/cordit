extends GutTest
## E3-S1 数值 Resource 表（EPIC-3 第 1 条 Story）
##
## 【断言覆盖】EPIC-3.md E3-S1 三条验收标准 + 两条架构铁律：
##   A. 装载与完整性：五表行数、全表 validate() 零问题、跨表引用零悬空、
##      id 与文件名一致；
##   B. 字段与 GDD §5 逐项对齐：角色表（§3.6 Lv1 初值 + 每级成长）、
##      技能表 9 张卡（§3.4：MP/倍率/目标/属性/effect_tag 含掩护与解毒）、
##      敌人表（§7 给定值 + §3.3 至多 1 弱 1 抗 + 行为权重和 100）、
##      掉落表（§5 全 100% 单一道具）、道具表（kind/value/可用阶段）；
##   C. B1-B5 编组建卡：成员、总数、Boss 标记、位置、教学意图；
##   D. 派生纯函数：stats_at / skills_up_to / level_for_exp 的边界；
##   E. 架构铁律静态核验：scripts/data/*.gd 无场景依赖（A1 铁律 3）、
##      数值表不读 JSON（A2 数值与内容分域）。
##
## 【测试策略】全静态、不入场景树、不写全局单例——本 Story 是纯数据表，
##   没有任何运行时状态可污染，因此不需要 before/after 快照隔离。
##   所有断言都是"读 .tres → 比对 GDD 原文"，改数值只需改 .tres（A2）。
##
## 跑法（项目根下）：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const DataTables := preload("res://scripts/data/data_tables.gd")

## E 区静态核验的扫描目标：scripts/data/ 下全部 .gd
const DATA_SCRIPT_DIR: String = "res://scripts/data"

## 五表 + 编组表的"表名 -> 目录名"映射（用于 id/文件名一致性断言）
const TABLE_DIRS: Dictionary = {
	"characters": "characters",
	"skills": "skills",
	"enemies": "enemies",
	"drops": "drops",
	"items": "items",
	"encounters": "encounters",
}


## 取表字典（按表名）
func _table(name: String) -> Dictionary:
	match name:
		"characters": return DataTables.CHARACTERS
		"skills": return DataTables.SKILLS
		"enemies": return DataTables.ENEMIES
		"drops": return DataTables.DROPS
		"items": return DataTables.ITEMS
		"encounters": return DataTables.ENCOUNTERS
	return {}


## 读脚本源码文本（静态核验用）
func _read_script(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


# =============== A. 装载与完整性 ===============

func test_五表行数符合建卡要求() -> void:
	assert_eq(DataTables.CHARACTERS.size(), 3, "角色表应为 3 人小队")
	assert_eq(DataTables.SKILLS.size(), 9, "技能表应为 9 个技能（3 人 × 3）")
	assert_eq(DataTables.ENEMIES.size(), 6, "敌人表应为 B1-B5 出现的 6 种敌人")
	assert_eq(DataTables.DROPS.size(), 6, "掉落表应为每种敌人一条")
	assert_eq(DataTables.ITEMS.size(), 5, "道具表")
	assert_eq(DataTables.ENCOUNTERS.size(), 5, "编组表应为 B1-B5 五场")


func test_全表validate零问题() -> void:
	var problems: Dictionary = DataTables.validate_all()
	assert_eq(problems.keys(), [], "全表 validate() 应零问题，实际：%s" % str(problems))


func test_跨表引用零悬空() -> void:
	# 角色表.skills_by_level→技能表 / 敌人表.drop_id→掉落表 /
	# 掉落表.items[].item_id→道具表 / 编组表.members[].enemy_id→敌人表
	var errs: Array = DataTables.validate_references()
	assert_eq(errs, [], "跨表引用应零悬空，实际：%s" % str(errs))


func test_行id与文件名一致() -> void:
	# 约定：行 id 即文件名。违反会导致"按 id 拼路径"的调用方找错文件，
	# 且 .tres 内部无自校验——用测试把这层约定钉死。
	for table_name: String in TABLE_DIRS:
		var dir: String = String(TABLE_DIRS[table_name])
		for row_id: String in _table(table_name):
			var path: String = "res://data/resources/%s/%s.tres" % [dir, row_id]
			assert_true(FileAccess.file_exists(path),
					"%s/%s 应存在同名 .tres 文件" % [table_name, row_id])


func test_每行都挂载了Resource脚本() -> void:
	# 裸 Resource（忘了挂 script）会让所有字段静默取默认值——
	# 这是手改 .tres 最易犯且不报错的错误，必须拦在测试层。
	for table_name: String in TABLE_DIRS:
		for row_id: String in _table(table_name):
			var row: Resource = _table(table_name)[row_id]
			assert_not_null(row.get_script(), "%s/%s 未挂载脚本" % [table_name, row_id])


# =============== B1. 角色表字段对齐 §5 / §3.6 ===============

func test_角色表Lv1初值对齐GDD_3_6() -> void:
	# GDD §3.6 属性量级表 Lv1 列：凯尔 120/10/14/4/10/12、
	# 莉娜 80/30/5/12/6/10、莫娜 95/24/7/10/7/11
	var kyle: Resource = DataTables.get_character("kyle")
	assert_eq(kyle.base_hp, 120, "凯尔 Lv1 HP")
	assert_eq(kyle.base_mp, 10, "凯尔 Lv1 MP")
	assert_eq(kyle.base_atk, 14, "凯尔 Lv1 ATK")
	assert_eq(kyle.base_mag, 4, "凯尔 Lv1 MAG")
	assert_eq(kyle.base_def, 10, "凯尔 Lv1 DEF")
	assert_eq(kyle.spd, 12, "凯尔 SPD")
	var lina: Resource = DataTables.get_character("lina")
	assert_eq(lina.base_hp, 80, "莉娜 Lv1 HP")
	assert_eq(lina.base_mp, 30, "莉娜 Lv1 MP")
	assert_eq(lina.base_atk, 5, "莉娜 Lv1 ATK")
	assert_eq(lina.base_mag, 12, "莉娜 Lv1 MAG")
	assert_eq(lina.base_def, 6, "莉娜 Lv1 DEF")
	assert_eq(lina.spd, 10, "莉娜 SPD")
	var mona: Resource = DataTables.get_character("mona")
	assert_eq(mona.base_hp, 95, "莫娜 Lv1 HP")
	assert_eq(mona.base_mp, 24, "莫娜 Lv1 MP")
	assert_eq(mona.base_atk, 7, "莫娜 Lv1 ATK")
	assert_eq(mona.base_mag, 10, "莫娜 Lv1 MAG")
	assert_eq(mona.base_def, 7, "莫娜 Lv1 DEF")
	assert_eq(mona.spd, 11, "莫娜 SPD")


func test_角色表per_level对齐GDD_3_6正文() -> void:
	# §3.6 正文"每级 HP +40/33/32，MP +3/+8/+7，ATK +3，MAG +3/+5，DEF +2"
	# （ATK 只有剑士成长、MAG 剑士恒 0；SPD 为静态值恒 +0）
	assert_eq(DataTables.get_character("kyle").per_level,
			{"hp": 40, "mp": 3, "atk": 3, "mag": 0, "def": 2, "spd": 0}, "凯尔成长值组")
	assert_eq(DataTables.get_character("lina").per_level,
			{"hp": 33, "mp": 8, "atk": 0, "mag": 3, "def": 2, "spd": 0}, "莉娜成长值组")
	assert_eq(DataTables.get_character("mona").per_level,
			{"hp": 32, "mp": 7, "atk": 0, "mag": 5, "def": 2, "spd": 0}, "莫娜成长值组")


func test_角色表SPD恒为静态值不随等级成长() -> void:
	# §1.3 Cut 清单已砍速度 buffs/debuffs，§3.6 表格 SPD 列左右同值
	for id: String in DataTables.PARTY_ORDER:
		var c: Resource = DataTables.get_character(id)
		assert_eq(c.stats_at(1)["spd"], c.stats_at(5)["spd"], "%s 的 SPD 应不随等级变化" % c.name)
		assert_eq(c.per_level.get("spd", 0), 0, "%s 的 spd 成长应为 0" % c.name)


func test_角色表字段清单覆盖GDD_5() -> void:
	# §5 角色表字段（v1.1 D4：已删除"初始装备"，无 weapon_id/armor_id）：
	# id, name, job, base_hp, base_mp, base_atk, base_mag, base_def, spd,
	# per_level 成长值组, skills_by_level[]
	var c: Resource = DataTables.get_character("kyle")
	for field: String in ["id", "name", "job", "base_hp", "base_mp", "base_atk",
			"base_mag", "base_def", "spd", "per_level", "skills_by_level"]:
		assert_true(field in c, "角色表缺字段：%s" % field)


# =============== B2. 技能表 9 张卡 ===============

func test_9技能全部建卡且归属正确() -> void:
	var kyle: Resource = DataTables.get_character("kyle")
	var lina: Resource = DataTables.get_character("lina")
	var mona: Resource = DataTables.get_character("mona")
	assert_eq(kyle.skills_up_to(5),
			["heavy_slash", "wide_sweep", "cover"], "凯尔三技能")
	assert_eq(lina.skills_up_to(5),
			["fireball", "ice_shard", "thunder_burst"], "莉娜三技能")
	# 注意：skills_up_to 按【习得等级升序】返回（群愈 Lv2 早于净化 Lv3，v1.1 重排），
	# 不是建卡顺序——UI 的技能列表顺序即此顺序，改等级即改列表顺序。
	assert_eq(mona.skills_up_to(5),
			["heal", "group_heal", "cleanse"], "莫娜三技能（按习得等级升序，v1.1 重排）")
	# 三人的技能集合互不相交，且并集恰好是技能表 9 条（无孤儿技能卡）
	var union: Array[String] = []
	for c: Resource in [kyle, lina, mona]:
		for sid: String in c.skills_up_to(5):
			assert_false(union.has(sid), "技能 %s 被多个角色重复持有" % sid)
			union.append(sid)
	assert_eq(union.size(), DataTables.SKILLS.size(), "技能表应无孤儿技能卡")


func test_effect_tag含掩护与解毒() -> void:
	# 验收标准原文：9 个技能全部建卡，effect_tag 含掩护/解毒
	assert_eq(DataTables.get_skill("cover").effect_tag, "cover", "掩护技 effect_tag")
	assert_eq(DataTables.get_skill("cleanse").effect_tag, "detox", "解毒技 effect_tag")
	# 且这两张卡分别归剑士与辅助（§3.4 定位）
	assert_true(DataTables.get_character("kyle").skills_up_to(5).has("cover"), "掩护应属凯尔")
	assert_true(DataTables.get_character("mona").skills_up_to(5).has("cleanse"), "净化应属莫娜")


func test_技能字段对齐GDD_3_4() -> void:
	# §3.4 逐技能给定 MP / 目标 / 效果（倍率）
	var cases: Array = [
		["heavy_slash", "重斩", "physical", "none", 1.8, "enemy_single", 6],
		["wide_sweep", "横扫", "physical", "none", 0.9, "enemy_all", 5],
		["cover", "掩护", "utility", "none", 0.0, "ally_single", 4],
		["fireball", "火球", "magic", "fire", 1.4, "enemy_single", 4],
		["ice_shard", "冰锥", "magic", "ice", 1.4, "enemy_single", 4],
		["thunder_burst", "雷爆", "magic", "thunder", 1.0, "enemy_all", 8],
		["heal", "治疗", "heal", "none", 3.0, "ally_single", 4],
		["group_heal", "群愈", "heal", "none", 1.8, "ally_all", 9],
		["cleanse", "净化", "utility", "none", 0.0, "ally_single", 3],
	]
	for c: Array in cases:
		var sid: String = String(c[0])
		var s: Resource = DataTables.get_skill(sid)
		assert_not_null(s, "技能卡缺失：%s" % sid)
		assert_eq(s.name, String(c[1]), "%s 显示名" % sid)
		assert_eq(s.kind, String(c[2]), "%s kind" % sid)
		assert_eq(s.element, String(c[3]), "%s element" % sid)
		assert_almost_eq(s.power, float(c[4]), 0.001, "%s 倍率" % sid)
		assert_eq(s.target, String(c[5]), "%s 目标类型" % sid)
		assert_eq(s.mp_cost, int(c[6]), "%s MP 消耗" % sid)
		assert_false(s.description.is_empty(), "%s 描述文本不得为空（§5 字段）" % sid)


func test_术士三系齐全且吃克制_其余技能不带元素() -> void:
	# §3.4 设计意图：术士三系齐全使"切属性"始终可执行；
	# §3.3 相性只作用于法术，物理/回复/功能带元素会静默丢失克制收益
	var elements: Array[String] = []
	for sid: String in DataTables.get_character("lina").skills_up_to(5):
		var s: Resource = DataTables.get_skill(sid)
		assert_eq(s.kind, "magic", "莉娜技能应全为法术：%s" % sid)
		assert_true(s.uses_element(), "莉娜技能应带元素：%s" % sid)
		elements.append(s.element)
	elements.sort()
	assert_eq(elements, ["fire", "ice", "thunder"], "莉娜应三系齐全")
	for sid: String in DataTables.SKILLS:
		var s: Resource = DataTables.get_skill(sid)
		if s.kind != "magic":
			assert_eq(s.element, "none", "非法术技能不得带元素：%s" % sid)


func test_Lv1时三人各有1个基础技能() -> void:
	# §3.6 明文："Lv1 时三人各已有 1 个基础技能，保证首战技能按钮不为空"
	# 数值口径裁决：把每人最早习得的技能下调到 Lv1（见 character_data.gd 头注释）
	for id: String in DataTables.PARTY_ORDER:
		var c: Resource = DataTables.get_character(id)
		assert_eq(c.skills_up_to(1).size(), 1, "%s 在 Lv1 应恰好有 1 个技能" % c.name)
	assert_true(DataTables.get_character("lina").skills_up_to(1).has("fireball"),
			"莉娜 Lv1 应有火球（§7 定 B2 教学意图依赖它，而 B2 预期等级 Lv1-2）")


# =============== B3. 敌人表 ===============

func test_敌人表GDD_7给定值对齐() -> void:
	# §7 只给了 B1/B2/B4/B5 的 HP/ATK/弱点，此处逐项硬断言（防御后续手改漂移）
	var moth: Resource = DataTables.get_enemy("moth")
	assert_eq(moth.hp, 50, "飞蛾 HP（§7 v1.1 裁定 30→50）")
	assert_eq(moth.atk, 8, "飞蛾 ATK（§7）")
	assert_eq(moth.weakness, "", "飞蛾无相性（§7）")
	var beetle: Resource = DataTables.get_enemy("beetle")
	assert_eq(beetle.hp, 45, "甲虫 HP（§7）")
	assert_eq(beetle.atk, 9, "甲虫 ATK（§7）")
	assert_eq(beetle.weakness, "fire", "甲虫弱火（§7）")
	var guardian: Resource = DataTables.get_enemy("guardian")
	assert_eq(guardian.hp, 240, "守卫 HP（§7）")
	assert_eq(guardian.atk, 16, "守卫 ATK（§7）")
	assert_eq(guardian.weakness, "thunder", "守卫弱雷（§7）")
	var core: Resource = DataTables.get_enemy("core")
	assert_eq(core.hp, 480, "核心 HP（§7）")
	assert_eq(core.atk, 18, "核心 ATK（§7）")
	assert_eq(core.weakness, "fire", "核心弱火（§7）")
	# B3 的火蜥/冰晶 §7 只给了弱点
	assert_eq(DataTables.get_enemy("salamander").weakness, "ice", "火蜥弱冰（§7）")
	assert_eq(DataTables.get_enemy("crystal").weakness, "fire", "冰晶弱火（§7）")


func test_每个敌人至多1弱点至多1抗性且不同源() -> void:
	# §3.3："每个敌人至多 1 个弱点、至多 1 个抗性（可皆无）"
	# 本表用单字段天然满足"至多 1"，此处额外拦"弱抗同源"与非法值
	var legal: Array = ["", "none", "fire", "ice", "thunder"]
	for eid: String in DataTables.ENEMIES:
		var e: Resource = DataTables.get_enemy(eid)
		assert_true(legal.has(e.weakness), "%s weakness 值非法：%s" % [eid, e.weakness])
		assert_true(legal.has(e.resist), "%s resist 值非法：%s" % [eid, e.resist])
		assert_false(e.has_weakness() and e.weakness == e.resist,
				"%s 不得同一属性既弱又抗：%s" % [eid, e.weakness])


func test_敌人AI权重和恒为100() -> void:
	# §5 三种范式：普通{攻击:100}、精英{攻击60/毒击25/群击15}、
	# Boss{攻击50/单体重击30/蓄力20}——权重和均为 100，便于策划直读百分比
	assert_eq(DataTables.get_enemy("moth").ai_weights, {"attack": 100}, "普通敌范式")
	assert_eq(DataTables.get_enemy("guardian").ai_weights,
			{"attack": 60, "poison_strike": 25, "sweep": 15}, "精英范式（§5/§7）")
	assert_eq(DataTables.get_enemy("core").ai_weights,
			{"attack": 50, "heavy_strike": 30, "charge": 20}, "Boss 范式（§5/§7）")
	for eid: String in DataTables.ENEMIES:
		var e: Resource = DataTables.get_enemy(eid)
		assert_eq(e.total_weight(), 100, "%s 权重和应为 100" % eid)
		assert_true(("elite" if eid == "guardian" else
				("boss" if eid == "core" else "normal")) == e.ai_pattern,
				"%s 的 ai_pattern 档位" % eid)


func test_Boss蓄力为telegraph技() -> void:
	# §5："蓄力为 telegraph 技：本回合蓄力，下回合必放强力攻击
	#      （配合预告条教会玩家'看到蓄力→防御'）"
	var catalog = DataTables.ACTION_CATALOG
	assert_true(catalog.has_action("charge"), "行为目录应含蓄力")
	assert_true(bool(catalog.get_action("charge").get("telegraph", false)),
			"蓄力应标记为 telegraph")
	assert_true(catalog.has_action("charge_release"), "行为目录应含蓄力解放")
	assert_eq(catalog.get_action("charge_release").get("power", 0.0), 2.5,
			"蓄力解放倍率应为 2.5（v1.1 新增）")
	assert_true(DataTables.get_enemy("core").ai_weights.has("charge"),
			"Boss 行为权重应含蓄力")


func test_敌人表字段清单覆盖GDD_5() -> void:
	# §5 敌人表：id, name, sprite_id, hp, atk, def, spd, weakness(可空),
	# resist(可空), exp, drop_id, ai_pattern, 行为权重
	var e: Resource = DataTables.get_enemy("moth")
	for field: String in ["id", "name", "sprite_id", "hp", "atk", "def", "spd",
			"weakness", "resist", "exp", "drop_id", "ai_pattern", "ai_weights"]:
		assert_true(field in e, "敌人表缺字段：%s" % field)


# =============== B4. 掉落表与道具表 ===============

func test_掉落表全为100单一道具() -> void:
	# §5："保底规则（无；切片掉落全 100% 单一道具，不做概率掉落
	#      ——砍掉随机性 = 省测试）"
	for did: String in DataTables.DROPS:
		var d: Resource = DataTables.get_drop(did)
		assert_true(d.is_single_full_drop(), "%s 应为 1 条 / 概率 1.0" % did)
		assert_almost_eq(d.total_probability(), 1.0, 0.001, "%s 概率和" % did)
		assert_eq(d.pity_rule, "无", "%s 保底规则应为'无'（§5 裁决）" % did)


func test_道具表字段与交叉约束() -> void:
	# §5 道具表：id, name, kind(回HP/回MP/解毒), value, 可用阶段(地图/战斗/皆可)
	var legal_kinds: Array = ["heal_hp", "heal_mp", "detox"]
	for iid: String in DataTables.ITEMS:
		var it: Resource = DataTables.get_item(iid)
		assert_true(legal_kinds.has(it.kind), "%s kind 非法" % iid)
		assert_true(it.usable_in_battle(), "%s 应战斗可用（§3.2 战斗中可用回复类道具）" % iid)
		if it.kind == "detox":
			assert_eq(it.value, 0, "%s 解毒类 value 应为 0" % iid)
		else:
			assert_gt(it.value, 0, "%s 回复类 value 应为正" % iid)
		assert_false(it.description.is_empty(), "%s 描述文本不得为空" % iid)
	# 解毒道具必须存在（B4/B5 中毒战需要道具侧的解毒通道，§3.2/§3.4）
	assert_not_null(DataTables.get_item("antidote"), "道具表应含解毒道具")


func test_解毒道具在B4之前可得() -> void:
	# 设计意图核验：B4（遗迹二层）才出现中毒，B3（遗迹一层）的掉落里
	# 必须有解毒草，否则玩家进 B4 时只有"净化技能"一条路（而净化 Lv3 才习得）
	var b3: Resource = DataTables.get_encounter("b3_ruin_mix")
	var has_antidote: bool = false
	for eid: String in b3.expand_enemy_ids():
		var enemy: Resource = DataTables.get_enemy(eid)
		var drop: Resource = DataTables.get_drop(enemy.drop_id)
		for entry: Dictionary in drop.items:
			if String(entry.get("item_id", "")) == "antidote":
				has_antidote = true
	assert_true(has_antidote, "B3 掉落链应能产出解毒草")


# =============== C. B1-B5 编组建卡 ===============

func test_B1至B5编组全部建卡且配置对齐GDD_7() -> void:
	var expected: Array = [
		["b1_moth", "road", 1, false],
		["b2_beetles", "road", 2, false],
		["b3_ruin_mix", "ruin_f1", 4, false],
		["b4_guardian", "ruin_f2", 1, false],
		["b5_core", "ruin_f3", 1, true],
	]
	for c: Array in expected:
		var gid: String = String(c[0])
		var g: Resource = DataTables.get_encounter(gid)
		assert_not_null(g, "编组缺卡：%s" % gid)
		assert_eq(g.location, String(c[1]), "%s 位置（§7）" % gid)
		assert_eq(g.total_enemies(), int(c[2]), "%s 敌人总数（§7）" % gid)
		assert_eq(g.is_boss, bool(c[3]), "%s Boss 标记（§3.5 仅 Boss 禁逃）" % gid)
		assert_false(g.teaching_intent.is_empty(), "%s 应记录教学意图（§7）" % gid)
		assert_false(g.expected_level.is_empty(), "%s 应记录预期等级（§7）" % gid)


func test_B3混编成员为火蜥冰晶加飞蛾两只() -> void:
	# §7：火蜥(弱冰)×1 + 冰晶(弱火)×1 + 飞蛾×2
	var ids: Array[String] = DataTables.get_encounter("b3_ruin_mix").expand_enemy_ids()
	assert_eq(ids, ["salamander", "crystal", "moth", "moth"], "B3 编组展开顺序")


func test_只有B5禁用逃跑() -> void:
	# §3.5：仅普通战斗可逃，Boss 战禁用（菜单置灰）。B4 精英非 Boss → 可逃
	var boss_count: int = 0
	for gid: String in DataTables.ENCOUNTERS:
		var g: Resource = DataTables.get_encounter(gid)
		if g.is_boss:
			boss_count += 1
			assert_eq(gid, "b5_core", "仅 B5 应为 Boss 战")
	assert_eq(boss_count, 1, "五场战斗中应恰好一场 Boss 战")


# =============== D. 派生纯函数 ===============

func test_stats_at逐级定值累加() -> void:
	# 凯尔 §3.6：HP 120→280、MP 10→22、ATK 14→26、DEF 10→18，MAG/SPD 恒定
	var kyle: Resource = DataTables.get_character("kyle")
	var s1: Dictionary = kyle.stats_at(1)
	assert_eq(s1, {"hp": 120, "mp": 10, "atk": 14, "mag": 4, "def": 10, "spd": 12}, "凯尔 Lv1")
	var s5: Dictionary = kyle.stats_at(5)
	assert_eq(s5["hp"], 280, "凯尔 Lv5 HP（与 §3.6 表格右列一致）")
	assert_eq(s5["mp"], 22, "凯尔 Lv5 MP")
	assert_eq(s5["atk"], 26, "凯尔 Lv5 ATK")
	assert_eq(s5["mag"], 4, "凯尔 Lv5 MAG（恒定）")
	assert_eq(s5["def"], 18, "凯尔 Lv5 DEF")
	assert_eq(s5["spd"], 12, "凯尔 Lv5 SPD（静态值）")


func test_stats_at等级越界钳制() -> void:
	var c: Resource = DataTables.get_character("kyle")
	assert_eq(c.stats_at(0)["hp"], 120, "等级 0 应钳到 Lv1")
	assert_eq(c.stats_at(99)["hp"], c.stats_at(5)["hp"], "等级超上限应钳到 Lv5")


func test_skills_up_to按等级递增() -> void:
	var kyle: Resource = DataTables.get_character("kyle")
	assert_eq(kyle.skills_up_to(1), ["heavy_slash"], "Lv1 仅重斩")
	assert_eq(kyle.skills_up_to(2), ["heavy_slash", "wide_sweep"], "Lv2 习得横扫（v1.1 重排：原 Lv3）")
	assert_eq(kyle.skills_up_to(3), ["heavy_slash", "wide_sweep", "cover"], "Lv3 习得掩护（v1.1 重排：原 Lv5）")
	assert_eq(kyle.skills_up_to(4), ["heavy_slash", "wide_sweep", "cover"], "Lv4 无新增")
	assert_eq(kyle.skills_up_to(5).size(), 3, "Lv5 三技能齐全")


func test_经验曲线等级映射与五场累计对照() -> void:
	# growth_curve.gd 头注释的对照表：B1 后 Lv2、B3 后 Lv3、B4 后 Lv4、B5 后 Lv5
	var g: Resource = DataTables.GROWTH
	assert_eq(g.level_for_exp(0), 1, "0 经验为 Lv1")
	assert_eq(g.level_for_exp(15), 2, "B1 后应 Lv2")
	assert_eq(g.level_for_exp(51), 2, "B2 后仍 Lv2（B3 预期 Lv2）")
	assert_eq(g.level_for_exp(133), 3, "B3 后应 Lv3（B4 预期 Lv3）")
	assert_eq(g.level_for_exp(273), 4, "B4 后应 Lv4（B5 预期 Lv4）")
	assert_eq(g.level_for_exp(533), 5, "B5 后应 Lv5（§3.6 预计升 4 级）")
	assert_eq(g.level_for_exp(99999), 5, "等级上限钳制")
	assert_eq(g.exp_to_next(0), 15, "Lv1 升下级还差 15")
	assert_eq(g.exp_to_next(533), 0, "满级后无下级")


func test_五场战斗经验累计与预期等级自洽() -> void:
	# 用编组表 × 敌人表 exp 实算累计，验证曲线不是拍脑袋定的
	var total: int = 0
	var expected: Array = [2, 2, 3, 4, 5]  # 各场结束后的预期等级（§7）
	var order: Array[String] = ["b1_moth", "b2_beetles", "b3_ruin_mix", "b4_guardian", "b5_core"]
	for i: int in order.size():
		var g: Resource = DataTables.get_encounter(order[i])
		for eid: String in g.expand_enemy_ids():
			total += DataTables.get_enemy(eid).exp
		assert_eq(DataTables.GROWTH.level_for_exp(total), int(expected[i]),
				"%s 结束后应为 Lv%d（累计经验 %d）" % [order[i], int(expected[i]), total])


# =============== E. 架构铁律静态核验 ===============

func test_数据表脚本无场景依赖_A1铁律3() -> void:
	# A1 铁律 3：core 层（本 Story 的 scripts/data/ 同属纯数据层）
	# 绝不 get_node() 进场景树。逐行扫描，跳过注释行。
	var dir: DirAccess = DirAccess.open(DATA_SCRIPT_DIR)
	assert_not_null(dir, "应能打开 %s" % DATA_SCRIPT_DIR)
	var scanned: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		scanned += 1
		var text: String = _read_script("%s/%s" % [DATA_SCRIPT_DIR, file])
		for line: String in text.split("\n"):
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue  # 注释里讨论 get_node 是允许的（说明性文字）
			assert_eq(stripped.find("get_node"), -1,
					"%s 出现场景依赖：%s" % [file, stripped])
			assert_eq(stripped.find("$"), -1,
					"%s 出现节点取址符 $：%s" % [file, stripped])
	# 13 = 7 个表类（角色/技能/敌人/掉落/道具/编组/经验曲线）
	#   + 1 个装载器 data_tables.gd
	#   + 1 个数据桥 battle_units.gd（E3-S2 新增：数值表 → 战斗单位字典）
	#   + 1 个行为目录类 enemy_action_catalog.gd（v1.1 倍率迁 .tres 配套）
	#   + 1 个装备表类 equipment_data.gd（E6-S1 T3.3 新增：装备最小 schema）
	#   + 3 个事件系统件（E5-S2：schema 校验器在 dialogue 域不算此处，
	#     loader/executor 在 events 域——见 test_e5s2；本目录仍为纯数值域）
	# 这个计数是"目录里混进无关脚本"的哨兵——新增文件请同步更新并说明。
	assert_eq(scanned, 11, "scripts/data/ 下应有 11 个 .gd（8 表类 + 装载器 + 数据桥 + 行为目录类）")


func test_数值表不读JSON_A2分域() -> void:
	# A2：数值定义走 Resource（.tres），内容文本（对话/事件）走 JSON，不混。
	# 数值层任何一处引用 .json 都是分域被打通的信号。
	# E5-S2 例外清单：本目录不再落事件系统件（loader/executor 在 scripts/events，
	# 校验器在 scripts/dialogue——E5-S2 首轮放错域已纠正），故无放行名单。
	var dir: DirAccess = DirAccess.open(DATA_SCRIPT_DIR)
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var text: String = _read_script("%s/%s" % [DATA_SCRIPT_DIR, file])
		for line: String in text.split("\n"):
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			assert_eq(stripped.find(".json"), -1,
					"%s 不应读取 JSON：%s" % [file, stripped])


func test_数值资源全部落在data_resources下_A2() -> void:
	# A2 目录约定：data/resources/ 存数值 .tres，data/json/ 存内容 JSON。
	# 断言所有行数据的真实路径前缀，防止后续有人把 .tres 散落到别处。
	var checked: int = 0
	for table_name: String in TABLE_DIRS:
		var dir: String = String(TABLE_DIRS[table_name])
		for row_id: String in _table(table_name):
			var path: String = "res://data/resources/%s/%s.tres" % [dir, row_id]
			assert_true(FileAccess.file_exists(path), "%s 应在 data/resources/ 下" % path)
			checked += 1
	assert_eq(checked, 34, "五表 + 编组表共应 34 行")
	assert_true(FileAccess.file_exists("res://data/resources/growth_curve.tres"),
			"经验曲线应在 data/resources/ 下")
