extends GutTest
## E3-S2 battle_logic.gd 纯函数核心（EPIC-3 第 2 条 Story）
##
## 【断言覆盖】EPIC-3.md E3-S2 四条验收标准 + 主理人追加的两条口径：
##   A. 验收①：同配置战斗顺序可复现（无随机介入排序）
##   B. 验收②：克制三档 ×1.5/×1.0/×0.5 数值正确
##   C. 验收③：击退只作用于当前轮未行动槽位 + 边缘 1/3/6 单测
##   D. 验收④：平衡调整不碰场景文件（改 .tres 即生效）——用真实数值表
##      端到端算一遍伤害，证明数据 → 结算的链路全走 .tres
##   E. 口径①：公式系数集中在常量块（硬断言每个系数）
##   F. 口径②：随机外部化（core 零随机 API，浮动/逃跑由参数注入）
##   G. A1 铁律：battle_logic.gd 零场景依赖、零 import
##
## 【测试策略】
##   battle_logic.gd 是零依赖纯函数层，单测用手工字典驱动，不碰任何 .tres——
##   这样"算法错"与"表填错"是两类互不干扰的失败，定位成本各降一半。
##   只有 D 区（端到端）走真实数值表，专门验证"改 .tres 即生效"。
##
## 跑法（项目根下）：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")

const BATTLE_LOGIC_PATH: String = "res://scripts/core/battle_logic.gd"


# ------------------------------------------------------------------
# 测试夹具（手工单位，不依赖 .tres）
# ------------------------------------------------------------------

## 造一个单位：默认满血、MP 10，属性按传入
func _u(unit_id: String, side: String, slot: int, spd: int,
		hp: int = 100, atk: int = 10, def: int = 5, mag: int = 10,
		weakness: String = "", resist: String = "") -> Dictionary:
	return BattleLogic.make_unit({
		"unit_id": unit_id, "name": unit_id, "side": side, "slot": slot,
		"hp": hp, "max_hp": hp, "mp": 10, "max_mp": 10,
		"atk": atk, "def": def, "mag": mag, "spd": spd,
		"weakness": weakness, "resist": resist,
	})


## 队列 -> 可读键数组（断言失败时能一眼看出顺序错在哪）
func _qkeys(queue: Array) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in queue:
		out.append("%s#%d" % [String(e["side"]), int(e["slot"])])
	return out


## 造一支 n 人的同阵营小队（SPD 递减，便于构造确定的队列顺序）
func _squad(n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append(_u("p%d" % i, BattleLogic.SIDE_PARTY, i, 10 - i))
	return out


## 读脚本源码（静态核验用）
func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


## 取源码中的【非注释】代码行
func _code_lines(text: String) -> Array[String]:
	var out: Array[String] = []
	for line: String in text.split("\n"):
		var s: String = line.strip_edges()
		if s.is_empty() or s.begins_with("#"):
			continue
		out.append(s)
	return out


# =============== E. 公式系数常量块（主理人口径①）===============

func test_伤害公式系数对齐GDD_3_6() -> void:
	assert_eq(BattleLogic.PHYS_ATK_COEF, 2.0, "物理 ATK 系数（§3.6：ATK×2）")
	assert_eq(BattleLogic.PHYS_DEF_COEF, 1.0, "物理 DEF 系数（§3.6：DEF×1.0，v1.1 P0 裁定）")
	assert_eq(BattleLogic.MAG_ATK_COEF, 2.2, "法术 MAG 系数（§3.6：MAG×2.2）")
	assert_eq(BattleLogic.MAG_DEF_COEF, 1.2, "法术 DEF 系数（§3.6：DEF×1.2）")
	assert_eq(BattleLogic.MIN_DAMAGE, 1, "伤害下限（§3.6 的 max(1, ...)）")
	assert_eq(BattleLogic.VARIANCE_MIN, 0.9, "浮动下限（§3.6）")
	assert_eq(BattleLogic.VARIANCE_MAX, 1.1, "浮动上限（§3.6）")


func test_防御掩护中毒队列逃跑系数对齐GDD() -> void:
	assert_eq(BattleLogic.DEFEND_DAMAGE_MULT, 0.5, "防御减伤（§3.2）")
	assert_eq(BattleLogic.DEFEND_MP_RECOVER, 5, "防御回蓝（§3.2）")
	assert_eq(BattleLogic.COVER_DAMAGE_MULT, 0.5, "掩护承伤（§3.4）")
	assert_eq(BattleLogic.POISON_MAX_HP_RATIO, 0.05, "中毒扣最大HP×5%（§3.6）")
	assert_eq(BattleLogic.POISON_DURATION, 3, "中毒持续 3 回合（§3.6）")
	assert_eq(BattleLogic.KNOCKBACK_SLOTS, 2, "击退 2 槽（§3.1）")
	assert_eq(BattleLogic.PREVIEW_SLOTS, 3, "预告条 3 格（§3.1）")
	assert_eq(BattleLogic.ESCAPE_BASE, 0.70, "逃跑基础 70%（§3.5）")
	assert_eq(BattleLogic.ESCAPE_SPD_COEF, 0.02, "逃跑速度差系数 2%（§3.5）")
	assert_eq(BattleLogic.ESCAPE_MIN, 0.30, "逃跑下限 30%（§3.5）")
	assert_eq(BattleLogic.ESCAPE_MAX, 0.95, "逃跑上限 95%（§3.5）")


func test_克制倍率唯一出处在core层() -> void:
	# 口径①的延伸：倍率不能有两处定义（skill_data.gd 的重复声明已在
	# E3-S2 移除）。这里断言 core 的值，并确认数据层没有第二处。
	assert_eq(BattleLogic.ELEMENT_MULT_WEAK, 1.5, "弱点 ×1.5（§3.3）")
	assert_eq(BattleLogic.ELEMENT_MULT_NEUTRAL, 1.0, "无相性 ×1.0（§3.3）")
	assert_eq(BattleLogic.ELEMENT_MULT_RESIST, 0.5, "抗性 ×0.5（§3.3）")
	var skill_src: String = _read("res://scripts/data/skill_data.gd")
	for line: String in _code_lines(skill_src):
		assert_eq(line.find("MULT_"), -1,
				"skill_data.gd 不应再声明克制倍率（唯一出处在 battle_logic）：%s" % line)


# =============== B. 克制三档（验收②）===============

func test_克制三档倍率精确值() -> void:
	# 弱点 / 无相性 / 抗性 三档——用精确等值断言，不用区间断言：
	# 区间断言测不出"×1.5 写成 ×1.4"（它照样落在区间内），这是本 Story
	# 把随机外部化的直接收益。
	assert_eq(BattleLogic.element_multiplier("fire", "fire", ""), 1.5, "弱点 ×1.5")
	assert_eq(BattleLogic.element_multiplier("fire", "ice", ""), 1.0, "无相性 ×1.0")
	assert_eq(BattleLogic.element_multiplier("fire", "", "fire"), 0.5, "抗性 ×0.5")
	assert_eq(BattleLogic.element_multiplier("fire", "", ""), 1.0, "无弱无抗 ×1.0")


func test_三系之间不构成循环克制() -> void:
	# §3.3：三系之间互不构成循环克制（不存在火克冰），
	# 相性只由敌人表的 weakness/resist 字段决定。
	# 判据：任意两个【不同】元素，无论对方是弱点还是抗性，倍率恒为 ×1.0——
	#       即不存在"火克冰 / 冰克雷"这类元素对元素的查表。
	#       倍率只在【攻击属性 == 敌人表写的那个属性】时才生效。
	for e: String in ["fire", "ice", "thunder"]:
		for other: String in ["fire", "ice", "thunder"]:
			if e == other:
				continue
			assert_eq(BattleLogic.element_multiplier(e, "", other), 1.0,
					"无内建循环克制：%s 打抗 %s 的敌人仍为 ×1.0" % [e, other])
			assert_eq(BattleLogic.element_multiplier(e, other, ""), 1.0,
					"无内建循环克制：%s 打弱 %s 的敌人仍为 ×1.0（弱点只认同属性）" % [e, other])
	# 交叉确认：同属性才生效（倍率只来源于敌人表，不来源于元素组合）
	assert_eq(BattleLogic.element_multiplier("fire", "fire", ""), 1.5, "同属性弱点 → ×1.5")
	assert_eq(BattleLogic.element_multiplier("fire", "", "fire"), 0.5, "同属性抗性 → ×0.5")


func test_无属性不吃克制() -> void:
	# 物理与回复技能 element 恒为 none：即便敌人有弱点也必须是 ×1.0
	assert_eq(BattleLogic.element_multiplier("none", "fire", ""), 1.0, "none 不吃弱点")
	assert_eq(BattleLogic.element_multiplier("", "fire", ""), 1.0, "空属性不吃弱点")
	assert_false(BattleLogic.is_weakness_hit("none", "fire"), "none 不算命中弱点")
	assert_false(BattleLogic.is_weakness_hit("", "fire"), "空属性不算命中弱点")


func test_克制三档伤害数值正确() -> void:
	# 同一法术打同一敌人，只改相性：19.2 × 1.4 × {1.5, 1.0, 0.5}
	var base_mag: int = 12
	var base_def: int = 6
	var power: float = 1.4
	assert_eq(BattleLogic.compute_magic_damage(base_mag, base_def, power, "fire", "fire", ""),
			40, "弱点：19.2×1.4×1.5 = 40.32 → 40")
	assert_eq(BattleLogic.compute_magic_damage(base_mag, base_def, power, "fire", "", ""),
			27, "无相性：19.2×1.4 = 26.88 → 27")
	assert_eq(BattleLogic.compute_magic_damage(base_mag, base_def, power, "fire", "", "fire"),
			13, "抗性：19.2×1.4×0.5 = 13.44 → 13")


# =============== A. 队列（验收①）===============

func test_队列按SPD降序() -> void:
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 6),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 9),
			_u("e2", BattleLogic.SIDE_ENEMY, 2, 7)]
	assert_eq(_qkeys(BattleLogic.build_queue(party, enemies)),
			["party#0", "enemy#1", "enemy#2", "enemy#0"], "SPD 10/9/7/6 降序")


func test_同SPD时我方恒在敌方之前() -> void:
	# §3.1：速度相同时，我方恒排在敌方之前
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 10)]
	assert_eq(_qkeys(BattleLogic.build_queue(party, enemies)),
			["party#0", "enemy#0"], "同 SPD 我方在前")


func test_同SPD时按槽位序_我方队伍序与敌方生成序() -> void:
	# §3.1：我方之间按队伍槽位序（剑士→术士→辅助），敌方之间按生成槽位序
	var party: Array = [_u("kyle", BattleLogic.SIDE_PARTY, 0, 10),
			_u("lina", BattleLogic.SIDE_PARTY, 1, 10),
			_u("mona", BattleLogic.SIDE_PARTY, 2, 10)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 10),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 10)]
	assert_eq(_qkeys(BattleLogic.build_queue(party, enemies)),
			["party#0", "party#1", "party#2", "enemy#0", "enemy#1"],
			"全同 SPD：先我方三人按槽位序，再敌方按生成序")


func test_同配置战斗顺序可复现_无随机介入排序() -> void:
	# 验收标准①。做法：同输入重复生成 20 次，逐次全等。
	# 若排序里混进任何 randf/randi 做 tie-break，这条会红。
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 12),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 10),
			_u("p2", BattleLogic.SIDE_PARTY, 2, 11)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 12),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 8),
			_u("e2", BattleLogic.SIDE_ENEMY, 2, 10)]
	var first: Array[String] = _qkeys(BattleLogic.build_queue(party, enemies))
	for i: int in 20:
		assert_eq(_qkeys(BattleLogic.build_queue(party, enemies)), first,
				"第 %d 次生成应与首次完全一致（同 SPD 恒定序）" % i)
	assert_eq(first, ["party#0", "enemy#0", "party#2", "party#1", "enemy#2", "enemy#1"],
			"12(我方)/12(敌方)/11/10(我方)/10(敌方)/8")


func test_死者不入队() -> void:
	# §3.1：一轮 = 队列中所有存活单位各行动一次；死者在重置时移出
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10, 100),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 9, 0)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 8, 0)]
	assert_eq(_qkeys(BattleLogic.build_queue(party, enemies)), ["party#0"],
			"HP=0 的 p1 与 e0 不应入队")


# =============== C. 击退（验收③）===============

func test_击退向后移动2个槽位() -> void:
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 99)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 10),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 9),
			_u("e2", BattleLogic.SIDE_ENEMY, 2, 8),
			_u("e3", BattleLogic.SIDE_ENEMY, 3, 7),
			_u("e4", BattleLogic.SIDE_ENEMY, 4, 6)]
	var q: Array = BattleLogic.build_queue(party, enemies)
	assert_eq(_qkeys(q), ["party#0", "enemy#0", "enemy#1", "enemy#2", "enemy#3", "enemy#4"])
	var knocked: Array = BattleLogic.apply_knockback(q, 0, BattleLogic.SIDE_ENEMY, 1)
	assert_eq(_qkeys(knocked),
			["party#0", "enemy#0", "enemy#2", "enemy#3", "enemy#1", "enemy#4"],
			"e1 从下标 2 后移 2 槽到下标 4")


func test_击退边缘3_只剩1个未行动槽位只移到本轮末尾不跨轮() -> void:
	# §3.6 边缘 3：击退按 2 槽计算，但实际只后移至本轮末尾，不跨轮。
	# 场景 A：目标已是倒数第二，后面只剩 1 个槽位
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 99)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 10),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 9)]
	var q: Array = BattleLogic.build_queue(party, enemies)
	assert_eq(_qkeys(q), ["party#0", "enemy#0", "enemy#1"], "前置：3 个槽位")
	var knocked: Array = BattleLogic.apply_knockback(q, 0, BattleLogic.SIDE_ENEMY, 0)
	assert_eq(_qkeys(knocked), ["party#0", "enemy#1", "enemy#0"],
			"e0 只后移 1 槽到本轮末尾（不是 2 槽，更不能跨轮）")
	assert_eq(knocked.size(), q.size(), "击退不得改变队列长度（否则就是跨轮了）")


func test_击退边缘3_场景B_目标在本轮倒数第二且后有多个槽位() -> void:
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 99)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 10),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 9),
			_u("e2", BattleLogic.SIDE_ENEMY, 2, 8)]
	var q: Array = BattleLogic.build_queue(party, enemies)
	# e1 在下标 2，后面只有 e2 一个槽位 → 钳到末尾
	var knocked: Array = BattleLogic.apply_knockback(q, 0, BattleLogic.SIDE_ENEMY, 1)
	assert_eq(_qkeys(knocked), ["party#0", "enemy#0", "enemy#2", "enemy#1"],
			"e1 钳到本轮末尾")
	# 已是最后一个槽位的目标：击退应无实际位移但不报错
	var no_move: Array = BattleLogic.apply_knockback(q, 0, BattleLogic.SIDE_ENEMY, 2)
	assert_eq(_qkeys(no_move), _qkeys(q), "末尾目标击退后位置不变")


func test_击退只作用于尚未行动的当前轮() -> void:
	# §3.1：若已行动过，则下一轮起始位惩罚无效化——即击退只作用于
	# "尚未行动的当前轮"，不跨轮。
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 99)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 10),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 9),
			_u("e2", BattleLogic.SIDE_ENEMY, 2, 8)]
	var q: Array = BattleLogic.build_queue(party, enemies)
	# cursor=2 表示 e1（下标 2）正在行动；e0（下标 1）已行动 → 击退无效
	var knocked: Array = BattleLogic.apply_knockback(q, 2, BattleLogic.SIDE_ENEMY, 0)
	assert_eq(_qkeys(knocked), _qkeys(q), "已行动目标不受击退")
	# 正在行动的目标自身同样不受击退（防御式：不移动当前行动者）
	var on_self: Array = BattleLogic.apply_knockback(q, 2, BattleLogic.SIDE_ENEMY, 1)
	assert_eq(_qkeys(on_self), _qkeys(q), "正在行动的目标不受击退")


func test_击退惩罚不跨轮() -> void:
	# 击退后重建下一轮队列，顺序必须回到纯 SPD 序（惩罚未被带入下一轮）
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 99)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 10),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 9),
			_u("e2", BattleLogic.SIDE_ENEMY, 2, 8)]
	var q: Array = BattleLogic.build_queue(party, enemies)
	var knocked: Array = BattleLogic.apply_knockback(q, 0, BattleLogic.SIDE_ENEMY, 0)
	assert_ne(_qkeys(knocked), _qkeys(q), "前置：本轮内确实发生了位移")
	var next_round: Array = BattleLogic.build_queue(party, enemies)
	assert_eq(_qkeys(next_round), _qkeys(q), "下一轮队列应回到 SPD 序，不残留击退惩罚")


func test_我方不会被击退_单边规则() -> void:
	# §3.1：我方不会被击退（敌人技能不含击退，保持规则单边简单）
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 9)]
	var q: Array = BattleLogic.build_queue(party, [])
	var knocked: Array = BattleLogic.apply_knockback(q, 0, BattleLogic.SIDE_PARTY, 1)
	assert_eq(_qkeys(knocked), _qkeys(q), "我方目标击退应为 no-op")


func test_击退目标不在队列时原样返回不炸() -> void:
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10)]
	var q: Array = BattleLogic.build_queue(party, [])
	var knocked: Array = BattleLogic.apply_knockback(q, 0, BattleLogic.SIDE_ENEMY, 7)
	assert_eq(_qkeys(knocked), _qkeys(q), "不存在的槽位应原样返回")


func test_击退为纯函数不修改入参() -> void:
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 99)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 10),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 9),
			_u("e2", BattleLogic.SIDE_ENEMY, 2, 8)]
	var q: Array = BattleLogic.build_queue(party, enemies)
	var before: Array[String] = _qkeys(q)
	var _knocked: Array = BattleLogic.apply_knockback(q, 0, BattleLogic.SIDE_ENEMY, 0)
	assert_eq(_qkeys(q), before, "原队列不得被修改（纯函数）")


func test_击退触发条件_弱点命中且目标未防御() -> void:
	assert_true(BattleLogic.should_knockback("fire", "fire", false), "命中弱点应触发击退")
	assert_false(BattleLogic.should_knockback("fire", "ice", false), "非弱点不触发")
	assert_false(BattleLogic.should_knockback("fire", "", false), "敌方无弱点不触发")
	# §3.2：防御状态下被弱点命中，不触发击退（防御=稳住阵脚，规则自洽）
	assert_false(BattleLogic.should_knockback("fire", "fire", true), "防御中不触发击退")


# =============== D. 队列剔除与推进（§3.6 边缘 1 / 6）===============

func test_边缘1_队列中单位在轮到它之前死亡则跳过() -> void:
	# §3.6 边缘 1：队列中某单位在轮到它之前死亡 → 跳过其行动，队列即刻重算
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 9),
			_u("p2", BattleLogic.SIDE_PARTY, 2, 8)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 7)]
	var q: Array = BattleLogic.build_queue(party, enemies)
	assert_eq(_qkeys(q), ["party#0", "party#1", "party#2", "enemy#0"])
	# p1 在轮到它之前死亡
	party[1] = BattleLogic.damage_unit(party[1], 999)
	var advanced: Dictionary = BattleLogic.advance(q, 0, party, enemies)
	assert_false(bool(advanced["round_over"]), "本轮未结束")
	assert_eq(_qkeys(advanced["queue"]), ["party#0", "party#2", "enemy#0"],
			"死者 p1 应从队列移除（预告条即刻重算）")
	assert_eq(int(advanced["cursor"]), 1, "游标应指向 p2（跳过死者）")


func test_边缘6_敌人被击退后行动前死亡则从队列移除() -> void:
	# §3.6 边缘 6：敌人被击退后、行动前死亡 → 从队列移除，其被跳过不产生任何结算
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 99)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 10),
			_u("e1", BattleLogic.SIDE_ENEMY, 1, 9),
			_u("e2", BattleLogic.SIDE_ENEMY, 2, 8)]
	var q: Array = BattleLogic.build_queue(party, enemies)
	var knocked: Array = BattleLogic.apply_knockback(q, 0, BattleLogic.SIDE_ENEMY, 1)
	assert_eq(_qkeys(knocked), ["party#0", "enemy#0", "enemy#2", "enemy#1"], "前置：e1 被击退到末尾")
	# e1 在轮到它之前死亡
	enemies[1] = BattleLogic.damage_unit(enemies[1], 999)
	var pruned: Dictionary = BattleLogic.prune_dead(knocked, 0, party, enemies)
	assert_eq(_qkeys(pruned["queue"]), ["party#0", "enemy#0", "enemy#2"],
			"死亡的 e1 应从队列移除，其被跳过不产生任何结算")


func test_剔除死者时修正游标_不吞掉活人行动() -> void:
	# 静默失败防护：若被移除的死者位于游标【之前】而不修正游标，
	# 游标会多走一格 → 静默吞掉一个活人的行动，
	# 表现为"有人莫名其妙少打一回合"，且不会报错。
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 9),
			_u("p2", BattleLogic.SIDE_PARTY, 2, 8)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 7)]
	var q: Array = BattleLogic.build_queue(party, enemies)
	# cursor=2 → p2 正在行动；此时 p0（下标 0，在游标之前）死亡
	party[0] = BattleLogic.damage_unit(party[0], 999)
	var pruned: Dictionary = BattleLogic.prune_dead(q, 2, party, enemies)
	assert_eq(_qkeys(pruned["queue"]), ["party#1", "party#2", "enemy#0"], "死者已移除")
	assert_eq(int(pruned["cursor"]), 1,
			"游标应从 2 修正到 1（仍指向 p2，而不是跳到 e0）")
	var advanced: Dictionary = BattleLogic.advance(q, 2, party, enemies)
	assert_false(bool(advanced["round_over"]), "p2 之后还有 e0，本轮未结束")


func test_advance_轮末返回round_over() -> void:
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 9)]
	var q: Array = BattleLogic.build_queue(party, [])
	assert_false(bool(BattleLogic.advance(q, 0, party, [])["round_over"]), "还有下一人")
	var last: Dictionary = BattleLogic.advance(q, 1, party, [])
	assert_true(bool(last["round_over"]), "最后一人结算完应标记本轮结束")
	assert_eq(int(last["cursor"]), -1, "本轮结束时游标为 -1")


# =============== E. 行动预告条（§3.1）===============

func test_预告条从当前行动者起取3格() -> void:
	var party: Array = _squad(5)
	var q: Array = BattleLogic.build_queue(party, [])
	assert_eq(_qkeys(BattleLogic.preview(q, 0)), ["party#0", "party#1", "party#2"],
			"从当前行动者起 3 格（当前行动者高亮，故包含自身）")
	assert_eq(_qkeys(BattleLogic.preview(q, 2)), ["party#2", "party#3", "party#4"])


func test_预告条在队列末尾截断且不跨轮() -> void:
	var party: Array = _squad(5)
	var q: Array = BattleLogic.build_queue(party, [])
	assert_eq(_qkeys(BattleLogic.preview(q, 4)), ["party#4"], "末尾只剩 1 格")
	assert_eq(BattleLogic.preview(q, -1).size(), 0, "游标 -1（轮末）无预告")
	assert_eq(BattleLogic.preview(q, 99).size(), 0, "越界游标返回空")


# =============== F. 伤害 / 浮动（验收②+口径②）===============

func test_物理伤害公式精确值() -> void:
	# §3.6：max(1, ATK×2 − DEF×1.0) × 倍率 × 浮动（v1.1 P0：DEF 系数 1.5→1.0）
	# 20×2 − 10×1.0 = 30；×1.8 = 54
	assert_eq(BattleLogic.compute_physical_damage(20, 10, 1.8), 54, "重斩基准值")
	# 14×2 − 3×1.0 = 25；×1.0 = 25
	assert_eq(BattleLogic.compute_physical_damage(14, 3, 1.0), 25, "凯尔 Lv1 打飞蛾")
	# 高 DEF 压制：8×2 − 10×1.0 = 6（P0 裁定：凯尔不再免伤，原 1.5 系数时仅 1 点）
	assert_eq(BattleLogic.compute_physical_damage(8, 10, 1.0), 6,
			"飞蛾打凯尔 Lv1 为 6 点（v1.1 P0：DEF×1.0 不再抵消 ATK×2）")


func test_法术伤害公式精确值() -> void:
	# §3.6：max(1, MAG×2.2 − DEF×1.2) × 倍率 × 属性倍率 × 浮动
	# 12×2.2 − 6×1.2 = 19.2；×1.4 ×1.5 = 40.32 → 40
	assert_eq(BattleLogic.compute_magic_damage(12, 6, 1.4, "fire", "fire", ""), 40,
			"莉娜 Lv1 火球打弱火的甲虫")


func test_浮动外部化_roll两端为精确值() -> void:
	# 口径②：随机外部化后，单测能拿到浮动两端的【精确值】而非区间。
	var lo: float = BattleLogic.variance_from_roll(0.0)
	var hi: float = BattleLogic.variance_from_roll(1.0)
	assert_almost_eq(lo, 0.9, 0.0001, "roll=0 → 浮动 0.9")
	assert_almost_eq(hi, 1.1, 0.0001, "roll=1 → 浮动 1.1")
	var d_lo: int = BattleLogic.compute_physical_damage(20, 10, 1.8, lo)
	var d_hi: int = BattleLogic.compute_physical_damage(20, 10, 1.8, hi)
	assert_eq(d_lo, 49, "54 × 0.9 = 48.6 → 49（四舍五入）")
	assert_eq(d_hi, 59, "54 × 1.1 = 59.4 → 59（四舍五入）")


func test_取整口径为四舍五入() -> void:
	# GDD 未定取整口径，此处锁定为"四舍五入（half away from zero）"并显式测试，
	# 免得将来有人换了取整方式却没人知道。
	assert_eq(BattleLogic.compute_physical_damage(20, 10, 1.8, 0.9), 49, "48.6 → 49")
	assert_eq(BattleLogic.compute_physical_damage(20, 10, 1.8, 1.1), 59, "59.4 → 59")


func test_浮动越界钳制() -> void:
	# 防御式：调用方误传 0.0 或 5.0 时拉回 §3.6 区间，不静默放大/归零
	assert_eq(BattleLogic.compute_physical_damage(20, 10, 1.8, 0.0), 49, "0.0 钳到 0.9")
	assert_eq(BattleLogic.compute_physical_damage(20, 10, 1.8, 5.0), 59, "5.0 钳到 1.1")


func test_防御与掩护各减伤50且不叠加() -> void:
	# §3.2 防御 ×0.5；§3.4 掩护 ×0.5，"与防御不叠加，掩护中视为防御姿态"
	assert_eq(BattleLogic.incoming_damage_multiplier(false, false), 1.0, "常态")
	assert_eq(BattleLogic.incoming_damage_multiplier(true, false), 0.5, "防御")
	assert_eq(BattleLogic.incoming_damage_multiplier(false, true), 0.5, "掩护")
	assert_eq(BattleLogic.incoming_damage_multiplier(true, true), 0.5, "防御+掩护不叠加")
	# 54 → ×0.5 = 27
	assert_eq(BattleLogic.compute_physical_damage(20, 10, 1.8, 1.0, 0.5), 27,
			"防御姿态下重斩伤害")


func test_伤害下限为1_不出现0伤害() -> void:
	# 本系统无 MISS（§4.6），"造成 0 伤害"只会被当成 bug。
	# 极端压制：base 已触底 1，再吃抗性 0.5 → 0.5，仍应显示 1
	assert_eq(BattleLogic.compute_magic_damage(1, 100, 1.0, "fire", "", "fire"), 1,
			"base 触底 + 抗性 0.5 → 下限 1")
	assert_eq(BattleLogic.compute_physical_damage(1, 100, 1.0), 1, "ATK 远低于 DEF → 下限 1")


func test_预估伤害区间端点等于浮动两端() -> void:
	# 供 E3-S4 的"— 24~29 —"直读；端点与真值共用同一套系数，不会漂移
	var r: Vector2i = BattleLogic.physical_damage_range(14, 3, 1.0)
	assert_eq(r, Vector2i(23, 28), "25 × [0.9, 1.1] = [22.5, 27.5] → [23, 28]")
	assert_eq(r.x, BattleLogic.compute_physical_damage(14, 3, 1.0, BattleLogic.VARIANCE_MIN))
	assert_eq(r.y, BattleLogic.compute_physical_damage(14, 3, 1.0, BattleLogic.VARIANCE_MAX))
	var mr: Vector2i = BattleLogic.magic_damage_range(12, 6, 1.4, "fire", "fire", "")
	assert_eq(mr, Vector2i(36, 44), "40.32 × [0.9, 1.1] = [36.29, 44.35] → [36, 44]")


func test_伤害为纯函数不修改入参() -> void:
	var unit: Dictionary = _u("p0", BattleLogic.SIDE_PARTY, 0, 10, 100)
	var hp_before: int = int(unit["hp"])
	var hurt: Dictionary = BattleLogic.damage_unit(unit, 30)
	assert_eq(int(unit["hp"]), hp_before, "原单位不得被修改")
	assert_eq(int(hurt["hp"]), 70, "新单位扣血 30")
	assert_true(BattleLogic.is_alive(hurt), "70 HP 仍存活")


func test_存活由HP派生_无布尔标记可漂移() -> void:
	# 静默失败防护：unit 结构里刻意没有 "alive" 字段。
	# 存一个布尔标记就会出现"标记与血量不一致 → 死人还能行动"。
	var unit: Dictionary = _u("p0", BattleLogic.SIDE_PARTY, 0, 10, 100)
	assert_false(unit.has("alive"), "unit 不应有 alive 字段（一律由 hp 派生）")
	var dead: Dictionary = BattleLogic.damage_unit(unit, 100)
	assert_false(BattleLogic.is_alive(dead), "HP 归零即死亡")
	assert_eq(int(dead["hp"]), 0, "HP 不出现负数")
	var overkill: Dictionary = BattleLogic.damage_unit(unit, 999)
	assert_eq(int(overkill["hp"]), 0, "过量伤害钳到 0")


# =============== G. 回复 / 中毒（§3.6）===============

func test_回复量等于MAG乘倍率且不吃DEF() -> void:
	# §3.6：回复 = MAG × 技能倍率，不吃 DEF 项
	assert_eq(BattleLogic.compute_heal(10, 3.0), 30, "治疗：MAG10 × 3.0")
	assert_eq(BattleLogic.compute_heal(10, 1.8), 18, "群愈：MAG10 × 1.8")
	assert_eq(BattleLogic.compute_heal(20, 3.0), 60, "MAG20 × 3.0")
	# 回血钳到上限，不溢出
	var unit: Dictionary = _u("p0", BattleLogic.SIDE_PARTY, 0, 10, 100)
	var hurt: Dictionary = BattleLogic.damage_unit(unit, 70)
	var healed: Dictionary = BattleLogic.heal_unit(hurt, 999)
	assert_eq(int(healed["hp"]), 100, "回血钳到 max_hp，不溢出")


func test_中毒每回合扣最大HP的百分之五() -> void:
	# §3.6：每回合行动前扣 最大HP×5%
	assert_eq(BattleLogic.compute_poison_damage(120), 6, "120 × 5% = 6")
	assert_eq(BattleLogic.compute_poison_damage(80), 4, "80 × 5% = 4")
	assert_eq(BattleLogic.compute_poison_damage(95), 5, "95 × 5% = 4.75 → 5")
	assert_eq(BattleLogic.compute_poison_damage(1), 1, "下限 1：低血量时毒不空转")


func test_中毒时长递减且到期停止() -> void:
	var unit: Dictionary = _u("p0", BattleLogic.SIDE_PARTY, 0, 10, 100)
	var poisoned: Dictionary = BattleLogic.apply_poison(unit)
	assert_eq(int(poisoned["poison_turns"]), 3, "中毒 3 回合")
	var t1: Dictionary = BattleLogic.tick_poison(poisoned)
	assert_eq(int(t1["damage"]), 5, "100 × 5% = 5")
	assert_eq(int(t1["unit"]["hp"]), 95)
	assert_eq(int(t1["unit"]["poison_turns"]), 2, "剩余回合递减")
	var t2: Dictionary = BattleLogic.tick_poison(t1["unit"])
	var t3: Dictionary = BattleLogic.tick_poison(t2["unit"])
	assert_eq(int(t3["unit"]["poison_turns"]), 0, "3 回合后到期")
	var t4: Dictionary = BattleLogic.tick_poison(t3["unit"])
	assert_eq(int(t4["damage"]), 0, "到期后不再扣血")
	assert_eq(int(t4["unit"]["hp"]), int(t3["unit"]["hp"]), "到期后血量不变")


func test_中毒可叠加时长不可叠加伤害() -> void:
	# §3.6："可叠加时长不可叠加伤害"——重复中毒累加回合数，单次伤害不放大
	var unit: Dictionary = _u("p0", BattleLogic.SIDE_PARTY, 0, 10, 100)
	var once: Dictionary = BattleLogic.apply_poison(unit)
	var twice: Dictionary = BattleLogic.apply_poison(once)
	assert_eq(int(twice["poison_turns"]), 6, "二次中毒累加时长：3 + 3 = 6")
	var t: Dictionary = BattleLogic.tick_poison(twice)
	assert_eq(int(t["damage"]), 5, "伤害不因层数放大，仍是 5")


func test_防御指令回蓝并置位且不溢出() -> void:
	# §3.2：防御 = 本回合减伤 50% + 回 5 MP
	var unit: Dictionary = _u("p0", BattleLogic.SIDE_PARTY, 0, 10, 100)
	unit["mp"] = 2
	var r: Dictionary = BattleLogic.apply_defend(unit)
	assert_true(bool(r["unit"]["defending"]), "置防御姿态")
	assert_eq(int(r["unit"]["mp"]), 7, "2 + 5 = 7")
	assert_eq(int(r["mp_recovered"]), 5, "实际回复 5")
	# 满蓝时不溢出
	var full: Dictionary = _u("p1", BattleLogic.SIDE_PARTY, 1, 10, 100)
	full["mp"] = 9
	var r2: Dictionary = BattleLogic.apply_defend(full)
	assert_eq(int(r2["unit"]["mp"]), 10, "钳到 max_mp=10")
	assert_eq(int(r2["mp_recovered"]), 1, "实际回复 1")


func test_轮末重置瞬时姿态标记() -> void:
	# 静默失败防护：defending 泄漏到下一轮 = 永久减伤 50%，
	# 表现为"敌人打不动人"，排查时很容易先怀疑数值表而不是这个标记。
	var unit: Dictionary = _u("p0", BattleLogic.SIDE_PARTY, 0, 10, 100)
	var defending: Dictionary = BattleLogic.apply_defend(unit)["unit"]
	defending["covering"] = true
	var reset: Dictionary = BattleLogic.reset_round_flags(defending)
	assert_false(bool(reset["defending"]), "轮末清除防御标记")
	assert_false(bool(reset["covering"]), "轮末清除掩护标记")


# =============== H. 逃跑（§3.5）===============

func test_逃跑成功率公式与钳制() -> void:
	# §3.5：70% + (我方平均SPD − 敌方平均SPD) × 2%，钳 30%~95%
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 12),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 10),
			_u("p2", BattleLogic.SIDE_PARTY, 2, 11)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 6)]
	assert_almost_eq(BattleLogic.average_spd(party), 11.0, 0.0001, "我方平均 SPD = 11")
	assert_almost_eq(BattleLogic.escape_chance(party, enemies), 0.80, 0.0001,
			"70% + (11−6)×2% = 80%")
	# 下限钳制：速度劣势极大
	var fast_enemies: Array = [_u("e1", BattleLogic.SIDE_ENEMY, 0, 40)]
	assert_almost_eq(BattleLogic.escape_chance(party, fast_enemies), 0.30, 0.0001,
			"70% − 29×2% = 12% → 钳到 30%")
	# 上限钳制：速度优势极大
	var fast_party: Array = [_u("p9", BattleLogic.SIDE_PARTY, 0, 40)]
	assert_almost_eq(BattleLogic.escape_chance(fast_party, enemies), 0.95, 0.0001,
			"70% + 34×2% = 138% → 钳到 95%")


func test_逃跑成功率只统计存活单位() -> void:
	# 口径选择：阵亡者不应拉低/拉高"当前在场"的平均速度
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 12),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 10, 0)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 6, 0)]
	assert_almost_eq(BattleLogic.average_spd(party), 12.0, 0.0001, "死者不计入我方平均")
	assert_almost_eq(BattleLogic.average_spd(enemies), 0.0, 0.0001, "全灭敌方平均为 0")


func test_逃跑检定随机外部化() -> void:
	# 口径②：roll 由调用方给，core 只做阈值比较 → 单测可精确命中边界
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 12),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 10),
			_u("p2", BattleLogic.SIDE_PARTY, 2, 11)]
	var enemies: Array = [_u("e0", BattleLogic.SIDE_ENEMY, 0, 6)]
	var chance: float = BattleLogic.escape_chance(party, enemies)  # 0.80
	assert_true(BattleLogic.escape_success(party, enemies, chance - 0.01), "低于阈值 → 成功")
	assert_false(BattleLogic.escape_success(party, enemies, chance + 0.01), "高于阈值 → 失败")


func test_全灭判定与空数组防御() -> void:
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10),
			_u("p1", BattleLogic.SIDE_PARTY, 1, 9)]
	assert_false(BattleLogic.is_wiped(party), "全员存活")
	var half: Array = [BattleLogic.damage_unit(party[0], 999), party[1]]
	assert_false(BattleLogic.is_wiped(half), "尚有 1 人存活")
	var wiped: Array = [BattleLogic.damage_unit(party[0], 999),
			BattleLogic.damage_unit(party[1], 999)]
	assert_true(BattleLogic.is_wiped(wiped), "全员阵亡")
	assert_true(BattleLogic.is_wiped([]), "空数组视为全灭（防御式，不静默继续结算）")


# =============== D. 端到端：改 .tres 即生效（验收④）===============

func test_从tres构建队伍六维与stats_at一致() -> void:
	# 口径③：直接用 CharacterData.stats_at 派生，不要在调用方重算一遍
	var party: Array = BattleUnits.build_party(1)
	assert_eq(party.size(), 3, "三人小队")
	for i: int in party.size():
		var unit: Dictionary = party[i]
		var c: Resource = DataTables.get_character(String(unit["unit_id"]))
		var s: Dictionary = c.stats_at(1)
		assert_eq(int(unit["hp"]), int(s["hp"]), "%s HP" % c.name)
		assert_eq(int(unit["mp"]), int(s["mp"]), "%s MP" % c.name)
		assert_eq(int(unit["atk"]), int(s["atk"]), "%s ATK" % c.name)
		assert_eq(int(unit["mag"]), int(s["mag"]), "%s MAG" % c.name)
		assert_eq(int(unit["def"]), int(s["def"]), "%s DEF" % c.name)
		assert_eq(int(unit["spd"]), int(s["spd"]), "%s SPD" % c.name)
		assert_eq(int(unit["slot"]), i, "%s 槽位序即 PARTY_ORDER 下标" % c.name)


func test_编组展开槽位序与members一致() -> void:
	# §3.1：敌方之间按生成槽位序——编组表 members 的数组顺序即槽位序，
	# 所以改 members 顺序就能调同速敌人的先后（调序即调节奏）
	var enemies: Array = BattleUnits.build_encounter("b3_ruin_mix")
	assert_eq(enemies.size(), 5, "B3 = 火蜥 + 冰晶 + 飞蛾×3")
	var ids: Array[String] = []
	for u: Dictionary in enemies:
		ids.append(String(u["unit_id"]))
		assert_eq(String(u["side"]), BattleLogic.SIDE_ENEMY, "敌方单位阵营")
	assert_eq(ids, ["salamander", "crystal", "moth", "moth", "moth"], "槽位 0..4 按 members 顺序")
	for i: int in enemies.size():
		assert_eq(int(enemies[i]["slot"]), i, "槽位下标连续")


func test_端到端_B1队列顺序由tres决定() -> void:
	# 证明队列顺序完全由 .tres 的 spd 决定：改 .tres 的 spd 即改顺序，
	# 不需要碰任何场景文件或代码。
	var party: Array = BattleUnits.build_party(1)
	var enemies: Array = BattleUnits.build_encounter("b1_moth")
	assert_eq(_qkeys(BattleLogic.build_queue(party, enemies)),
			["party#0", "party#2", "party#1", "enemy#0"],
			"凯尔12 → 莫娜11 → 莉娜10 → 飞蛾6（值全部来自 .tres）")


func test_端到端_莉娜火球打甲虫伤害来自tres() -> void:
	# 端到端：数值表 → 单位 → 伤害公式，全链路无硬编码。
	# 莉娜 Lv1 MAG 12、甲虫 DEF 6、弱火、火球 power 1.4
	# = (12×2.2 − 6×1.2) × 1.4 × 1.5 = 40.32 → 40
	var lina: Dictionary = BattleUnits.build_party_unit("lina", 1)
	var beetle: Dictionary = BattleUnits.build_enemy_unit("beetle", 0)
	var fireball: Resource = DataTables.get_skill("fireball")
	var dmg: int = BattleLogic.compute_magic_damage(
			int(lina["mag"]), int(beetle["def"]), fireball.power,
			fireball.element, String(beetle["weakness"]), String(beetle["resist"]))
	assert_eq(dmg, 40, "火球打弱火甲虫：19.2 × 1.4 × 1.5 = 40.32 → 40")
	# 对照：凯尔普攻打同一甲虫只有 19 → 克制的收益可感知（§7 B2 教学意图）
	var kyle: Dictionary = BattleUnits.build_party_unit("kyle", 1)
	var basic: int = BattleLogic.compute_physical_damage(int(kyle["atk"]), int(beetle["def"]), 1.0)
	assert_eq(basic, 22, "凯尔 Lv1 普攻打甲虫：28 − 6 = 22")
	assert_true(dmg > basic * 1.5, "火球伤害应显著高于普攻（B2 克制教学成立）")


func test_端到端_逃跑率与Boss禁逃来自tres() -> void:
	var party: Array = BattleUnits.build_party(1)
	var b1: Array = BattleUnits.build_encounter("b1_moth")
	assert_almost_eq(BattleLogic.escape_chance(party, b1), 0.80, 0.0001,
			"B1：70% + (11−6)×2% = 80%")
	assert_false(BattleUnits.is_escape_forbidden("b1_moth"), "B1 非 Boss → 可逃")
	assert_false(BattleUnits.is_escape_forbidden("b4_guardian"), "B4 精英非 Boss → 可逃")
	assert_true(BattleUnits.is_escape_forbidden("b5_core"), "B5 Boss → 禁逃（§3.5）")


# =============== G. A1 铁律与口径静态核验 ===============

func test_battle_logic零场景依赖_A1铁律3() -> void:
	# A1 铁律 3：core 层绝不 get_node() 进场景树
	var lines: Array[String] = _code_lines(_read(BATTLE_LOGIC_PATH))
	assert_gt(lines.size(), 50, "前置：源码已读入")
	for line: String in lines:
		assert_eq(line.find("get_node"), -1, "出现场景依赖：%s" % line)
		assert_eq(line.find("$"), -1, "出现节点取址符：%s" % line)


func test_battle_logic零import_不认识数值表与JSON() -> void:
	# 口径：core 层零 import——不 preload 数值表、不读 JSON、不 load 场景。
	# 保证"算法错"与"表填错"互不干扰，也保证 core 可在无 .tres 环境下单测。
	var lines: Array[String] = _code_lines(_read(BATTLE_LOGIC_PATH))
	for line: String in lines:
		assert_eq(line.find("preload"), -1, "core 层不应 preload：%s" % line)
		assert_eq(line.find("DataTables"), -1, "core 层不应引用数值表：%s" % line)
		assert_eq(line.find(".tres"), -1, "core 层不应引用 .tres：%s" % line)
		assert_eq(line.find(".json"), -1, "core 层不应读 JSON：%s" % line)
		assert_eq(line.find("load("), -1, "core 层不应动态 load：%s" % line)


func test_battle_logic零随机API_口径2() -> void:
	# 口径②：core 层不调用任何随机 API，浮动/逃跑的随机因子由参数注入。
	# 这条一旦失守，单测就只能退化为区间断言。
	var lines: Array[String] = _code_lines(_read(BATTLE_LOGIC_PATH))
	for line: String in lines:
		assert_eq(line.find("randi"), -1, "出现随机 API：%s" % line)
		assert_eq(line.find("randf"), -1, "出现随机 API：%s" % line)
		assert_eq(line.find("randomize"), -1, "出现随机 API：%s" % line)
		assert_eq(line.find("RandomNumberGenerator"), -1, "出现随机 API：%s" % line)


func test_随机因子全部由参数注入() -> void:
	# 反证：所有吃随机的函数都有对应的入参，调用方才能注入确定值。
	# 用"传确定值必须得确定结果"来证明，而不是靠读源码。
	var d1: int = BattleLogic.compute_physical_damage(20, 10, 1.8, 1.0)
	var d2: int = BattleLogic.compute_physical_damage(20, 10, 1.8, 1.0)
	assert_eq(d1, d2, "同参数必得同结果（无随机介入）")
	var party: Array = [_u("p0", BattleLogic.SIDE_PARTY, 0, 10)]
	var e1: bool = BattleLogic.escape_success(party, [], 0.5)
	var e2: bool = BattleLogic.escape_success(party, [], 0.5)
	assert_eq(e1, e2, "同 roll 必得同检定结果")
