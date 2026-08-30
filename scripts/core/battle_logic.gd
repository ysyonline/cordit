extends RefCounted
## BattleLogic —— 战斗纯函数核心（E3-S2，架构 A1 铁律 3 / A2 约定）
##
## 【职责边界】
##   只做"输入状态 + 指令 → 输出结果"的纯计算：
##     队列生成与重算、击退、伤害/克制/浮动、中毒、逃跑判定。
##   不做：场景切换、UI、IO、随机抽样、状态持有、节点查询。
##
## 【三条硬约束】
##   1. 零场景依赖（A1 铁律 3）：不 get_node / 不 $ / 不读全局单例 /
##      不 preload 任何 .tscn。本文件【零 import】——连数值表都不引用，
##      入参一律是纯 Dictionary，出参也是纯 Dictionary。
##      数值表 → 单位字典的组装桥在 scripts/data/battle_units.gd。
##   2. 零随机 API（E3-S2 追加口径）：本层不调用 randi / randf / randomize /
##      randf_range 等任何随机函数。浮动、逃跑检定的随机因子一律由调用方
##      以【参数】传入（variance: float / roll: float），core 只负责算进去。
##      理由：否则单测只能写区间断言，而区间断言测不出"×1.5 写成 ×1.4"
##      ——它照样落在区间内。
##   3. 公式系数集中在顶部常量块（E3-S2 追加口径，见下方 §1），不散落在
##      函数体表达式里。改系数只动一处。
##
## 【正本】design/gdd/battle-system-gdd.md
##   §3.1 速度行动队列（SPD 降序 / 同值恒定序 / 击退 2 槽不跨轮 / 预告条 3 格）
##   §3.2 四大基础指令（防御 ×0.5 且回 MP 5；防御中被弱点命中不触发击退）
##   §3.3 三系克制（弱点 ×1.5 / 无相性 ×1.0 / 抗性 ×0.5；相性只由敌人表决定）
##   §3.4 掩护（自身承伤 ×0.5，与防御不叠加，掩护中视为防御姿态）
##   §3.5 逃跑成功率 = 70% + (我方平均SPD − 敌方平均SPD) × 2%，钳 30%~95%
##   §3.6 伤害/回复/中毒公式 + 边缘情况 1-7
##
## 【引用风格】preload 常量（项目规范，见 character_record.gd 头注释）。
##
## 【单位（unit）字典结构】——本层所有函数的入参/出参单位一律用这个结构。
##   本层不认识 CharacterData / EnemyData，只认识这个纯字典。
##   {
##     "unit_id": String,    # 角色 id 或敌人 id
##     "name": String,       # 显示名（浮动数字与 UI 用）
##     "side": String,       # SIDE_PARTY / SIDE_ENEMY
##     "slot": int,          # 队伍槽位序 或 敌方生成槽位序（同 SPD 时的稳定序）
##     "hp": int, "max_hp": int,
##     "mp": int, "max_mp": int,
##     "atk": int, "def": int, "mag": int, "spd": int,
##     "weakness": String,   # 可空（我方恒为空串）
##     "resist": String,     # 可空
##     "poison_turns": int,  # 剩余中毒回合数（0 = 未中毒）
##     "defending": bool,    # 本回合防御姿态（每轮结束必须重置，见 reset_round_flags）
##     "covering": bool,     # 本回合掩护姿态（同上）
##   }
##   注意：没有 "alive" 字段——存活一律由 is_alive() 从 hp > 0 派生。
##   存一个会漂移的布尔标记，是"显示已死但还能行动"这类幽灵 bug 的温床。

# ==================================================================
# §1. 公式系数常量块（E3-S2 追加口径：集中管理，改系数只动这一块）
# ==================================================================
# 共 22 个常量，分 6 组（另有 §2 的阵营/元素取值 4 个，非公式系数）。
# 每个都标注 GDD 出处与"改动后果"，方便文策渊裁定后按图索骥地改，
# 不需要读函数体。

# ---- 1.1 伤害公式系数（GDD §3.6 + v1.1 P0 裁定）----
# 物理伤害 = max(1, ATK×2 − DEF×1.0) × 技能倍率 × 浮动(0.9~1.1)
# 法术伤害 = max(1, MAG×2.2 − DEF×1.2) × 技能倍率 × 属性倍率 × 浮动(0.9~1.1)
#
# 【PHYS_DEF_COEF 1.5 → 1.0】GDD v1.1 P0 裁定（2026-08-30，文策渊裁定/主理人下发）：
#   原 1.5 使高 DEF 角色近乎免伤——凯尔 Lv1 DEF 10 面对飞蛾 ATK 8 =
#   max(1, 16−15) = 1 点 = 0.83% 最大 HP，远低于体验目标。
#   为什么是改系数而不是上调敌人 ATK（主理人原倾向方案）：三个角色对飞蛾
#   ATK 的需求区间为凯尔 [12.30,16.50] / 莉娜 [7.70,10.50] / 莫娜 [9.05,12.38]，
#   **交集为空**——减法公式下凯尔与莉娜 4 点 DEF 差 ×1.5 = 6 点伤害差，
#   而莉娜 80 HP 的 8%~15% 带宽总共只有 6.4 点宽，无解。
#   裁定后 §3.6 的"8%~15%"改为【分角色分档】：剑士 4-10% / 辅助 8-14% /
#   术士 10-16%。6 个敌人 × 3 角色全部落档，敌方 ATK 一个都不用改。
#
# ⚠️ MAG_DEF_COEF 保持 1.2，【不要顺手统一成 1.0】：法术在切片内单向使用
#    （敌人无 MAG），从不参与我方承伤链路。GDD v1.1 已写明理由。
const PHYS_ATK_COEF := 2.0   # 物理：攻方 ATK 系数
const PHYS_DEF_COEF := 1.0   # 物理：守方 DEF 系数（v1.1 P0 裁定：1.5 → 1.0）
const MAG_ATK_COEF := 2.2    # 法术：攻方 MAG 系数
const MAG_DEF_COEF := 1.2    # 法术：守方 DEF 系数 ⚠️ 不可随物理一并改成 1.0
const MIN_DAMAGE := 1        # 伤害下限（GDD 的 max(1, ...) 与结果下限共用）

# ---- 1.2 浮动系数（GDD §3.6：每次结算随机项 0.9~1.1，仅用于打击感）----
const VARIANCE_MIN := 0.9
const VARIANCE_MAX := 1.1
const NEUTRAL_VARIANCE := 1.0   # 无浮动默认值（单测与 UI 预估用）

# ---- 1.3 三系克制倍率（GDD §3.3）----
# 三系之间互不构成循环克制，相性只由敌人表 weakness/resist 决定。
const ELEMENT_MULT_WEAK := 1.5     # 弱点
const ELEMENT_MULT_NEUTRAL := 1.0  # 无相性
const ELEMENT_MULT_RESIST := 0.5   # 抗性（无额外效果，不触发击退）

# ---- 1.4 防御与掩护（GDD §3.2 / §3.4）----
# 两者同为 0.5 且【不叠加】（§3.4："与防御不叠加，掩护中视为防御姿态"）。
# 分开命名是为了标明各自出处，裁定其一不会影响另一个。
const DEFEND_DAMAGE_MULT := 0.5   # 防御：本回合受到的所有伤害 ×0.5
const DEFEND_MP_RECOVER := 5      # 防御：回复 5 MP
const COVER_DAMAGE_MULT := 0.5    # 掩护：自身承伤 ×0.5（不叠加）

# ---- 1.5 中毒（GDD §3.6）----
const POISON_MAX_HP_RATIO := 0.05  # 每回合扣 最大HP×5%
const POISON_DURATION := 3         # 持续 3 回合

# ---- 1.6 队列与逃跑（GDD §3.1 / §3.5）----
const KNOCKBACK_SLOTS := 2   # 击退：向后移动 2 个槽位（不跨轮）
const PREVIEW_SLOTS := 3     # 行动预告条格数
const ESCAPE_BASE := 0.70    # 逃跑基础成功率 70%
const ESCAPE_SPD_COEF := 0.02  # 速度差每 1 点 → ±2%
const ESCAPE_MIN := 0.30     # 下限 30%
const ESCAPE_MAX := 0.95     # 上限 95%

# ==================================================================
# §2. 阵营与元素取值
# ==================================================================

const SIDE_PARTY := "party"
const SIDE_ENEMY := "enemy"

## 同 SPD 时的阵营优先级：我方 0 恒排在敌方 1 之前（GDD §3.1）
const SIDE_RANK: Dictionary = {"party": 0, "enemy": 1}

## "无属性"的取值（与 skill_data.gd 的 ELEMENT_NONE 同值，本层不引用它）
const ELEMENT_NONE := "none"


# ==================================================================
# §3. 单位构造与查询
# ==================================================================

## 从统计字典构造单位（缺失键取默认值，杜绝"字段缺失 → 静默按 0 算"）
static func make_unit(stats: Dictionary) -> Dictionary:
	return {
		"unit_id": String(stats.get("unit_id", "")),
		"name": String(stats.get("name", "")),
		"side": String(stats.get("side", SIDE_PARTY)),
		"slot": int(stats.get("slot", 0)),
		"hp": int(stats.get("hp", 1)),
		"max_hp": int(stats.get("max_hp", 1)),
		"mp": int(stats.get("mp", 0)),
		"max_mp": int(stats.get("max_mp", 0)),
		"atk": int(stats.get("atk", 1)),
		"def": int(stats.get("def", 0)),
		"mag": int(stats.get("mag", 0)),
		"spd": int(stats.get("spd", 1)),
		"weakness": String(stats.get("weakness", "")),
		"resist": String(stats.get("resist", "")),
		"poison_turns": int(stats.get("poison_turns", 0)),
		"defending": bool(stats.get("defending", false)),
		"covering": bool(stats.get("covering", false)),
	}


## 存活判定：一律从 hp 派生，不存布尔标记（见文件头"单位数据结构"说明）
static func is_alive(unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0


## 按 (阵营, 槽位) 取单位；找不到返回空字典（调用方判空，不静默用默认值）
static func find_unit(party: Array, enemies: Array, side: String, slot: int) -> Dictionary:
	var list: Array = party if side == SIDE_PARTY else enemies
	if slot < 0 or slot >= list.size():
		return {}
	return list[slot] as Dictionary


## 全灭判定（空数组视为全灭：防御式——宁可进失败流程，也不要静默继续结算）
static func is_wiped(units: Array) -> bool:
	for u: Dictionary in units:
		if is_alive(u):
			return false
	return true


# ==================================================================
# §4. 行动队列（GDD §3.1）
# ==================================================================

## 队列条目（身份 + 排序快照，不含状态）
## 快照 SPD 的理由：Godot 的排序比较器取不到外部参数，且 SPD 是静态值
## （§1.3 已砍速度 buffs/debuffs），轮内不会变化，快照是安全的。
static func _queue_entry(unit: Dictionary, slot: int) -> Dictionary:
	var side: String = String(unit.get("side", SIDE_PARTY))
	return {
		"side": side,
		"slot": slot,
		"spd": int(unit.get("spd", 0)),
		"side_rank": int(SIDE_RANK.get(side, 1)),
	}


## 队列排序比较器（§3.1 全部排序规则的落点）：
##   ① SPD 降序；② 同 SPD 我方恒在敌方之前；③ 同阵营按槽位序。
##   【不引入随机】——同配置战斗的顺序必须可复现，否则平衡调校无从谈起。
static func _compare_queue_entries(a: Dictionary, b: Dictionary) -> bool:
	if int(a["spd"]) != int(b["spd"]):
		return int(a["spd"]) > int(b["spd"])
	if int(a["side_rank"]) != int(b["side_rank"]):
		return int(a["side_rank"]) < int(b["side_rank"])
	return int(a["slot"]) < int(b["slot"])


## 生成一轮的行动队列：存活单位全员入队，按 §3.1 规则排序。
## 死者不入队（§3.1"一轮结束，队列重置（死者在重置时移出）"）。
static func build_queue(party: Array, enemies: Array) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	for i: int in party.size():
		var u: Dictionary = party[i] as Dictionary
		if is_alive(u):
			queue.append(_queue_entry(u, i))
	for i: int in enemies.size():
		var u: Dictionary = enemies[i] as Dictionary
		if is_alive(u):
			queue.append(_queue_entry(u, i))
	queue.sort_custom(_compare_queue_entries)
	return queue


## 剔除队列中的死者（GDD §3.6 边缘 1 与边缘 6 的公共机制）。
## 返回 {"queue": 新队列, "cursor": 修正后的游标}——
## 游标必须修正：若被移除的死者位于游标【之前】，不修正会让游标跳过一个
## 活人（静默吞掉一次行动，表现为"有人莫名其妙少打一回合"）。
static func prune_dead(queue: Array, cursor: int, party: Array, enemies: Array) -> Dictionary:
	var kept: Array[Dictionary] = []
	var removed_before_cursor: int = 0
	for i: int in queue.size():
		var e: Dictionary = queue[i] as Dictionary
		var u: Dictionary = find_unit(party, enemies, String(e["side"]), int(e["slot"]))
		if u.is_empty() or not is_alive(u):
			if i < cursor:
				removed_before_cursor += 1
			continue
		kept.append(e)
	return {"queue": kept, "cursor": cursor - removed_before_cursor}


## 推进游标（不含剔除）；越界返回 -1 表示本轮结束。
## 生产路径请优先用 advance()——它内含剔除。
static func advance_cursor(queue: Array, cursor: int) -> int:
	var next: int = cursor + 1
	if next >= queue.size():
		return -1
	return next


## 结算完当前单位后推进到下一个行动者（内含剔除死者，推荐入口）。
## 返回 {"queue", "cursor", "round_over"}；round_over = true 时 cursor 为 -1，
## 调用方据此重建下一轮队列（build_queue）。
static func advance(queue: Array, cursor: int, party: Array, enemies: Array) -> Dictionary:
	var pruned: Dictionary = prune_dead(queue, cursor, party, enemies)
	var q: Array = pruned["queue"] as Array
	var next: int = int(pruned["cursor"]) + 1
	if next >= q.size():
		return {"queue": q, "cursor": -1, "round_over": true}
	return {"queue": q, "cursor": next, "round_over": false}


## 行动预告条：从当前行动者起取接下来 count 个槽位（§3.1：当前行动者高亮）。
## 只做切片，不跨轮——不足 count 个就返回现有的（UI 侧留空槽即可）。
static func preview(queue: Array, cursor: int, count: int = PREVIEW_SLOTS) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if cursor < 0 or cursor >= queue.size():
		return out
	for i: int in count:
		var idx: int = cursor + i
		if idx >= queue.size():
			break
		out.append(queue[idx] as Dictionary)
	return out


# ==================================================================
# §5. 击退（GDD §3.1 + §3.6 边缘 3）
# ==================================================================

## 在队列中定位条目下标，找不到返回 -1
static func find_entry_index(queue: Array, side: String, slot: int) -> int:
	for i: int in queue.size():
		var e: Dictionary = queue[i] as Dictionary
		if String(e["side"]) == side and int(e["slot"]) == slot:
			return i
	return -1


## 击退：目标在本轮队列中后移 KNOCKBACK_SLOTS 个槽位。
## 返回新队列（不修改入参）。以下三种情况【原样返回】：
##   ① 目标非敌方——§3.1 单边规则："我方不会被击退"；
##   ② 目标已行动（下标 <= cursor，含正在行动）——§3.1"若已行动过，则
##      下一轮起始位惩罚无效化"，即击退只作用于"尚未行动的当前轮"；
##   ③ 目标不在队列中（已死/未入队）。
## 边缘 3：可后移的槽位不足 2 个时，钳到本轮末尾——按 2 槽计算，但
##   【绝不跨轮】把惩罚带进下一轮。
static func apply_knockback(queue: Array, cursor: int, side: String, slot: int) -> Array[Dictionary]:
	if side != SIDE_ENEMY:
		return _clone_queue(queue)
	var idx: int = find_entry_index(queue, side, slot)
	if idx < 0 or idx <= cursor:
		return _clone_queue(queue)
	var out: Array[Dictionary] = _clone_queue(queue)
	var entry: Dictionary = out[idx] as Dictionary
	out.remove_at(idx)
	# 移除后长度减 1，故末尾下标为 out.size()；钳制即"只后移至本轮末尾"
	var target_idx: int = mini(idx + KNOCKBACK_SLOTS, out.size())
	out.insert(target_idx, entry)
	return out


## 深拷贝队列（纯函数防护：出参不与入参共享可变子对象）
static func _clone_queue(queue: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(queue.duplicate(true))
	return out


# ==================================================================
# §6. 伤害 / 克制 / 浮动（GDD §3.3 + §3.6）
# ==================================================================

## 属性倍率：弱点 ×1.5 / 抗性 ×0.5 / 其余 ×1.0。
## 无属性（空串或 "none"）恒 ×1.0——物理与回复技能不吃克制。
static func element_multiplier(element: String, weakness: String, resist: String) -> float:
	if element.is_empty() or element == ELEMENT_NONE:
		return ELEMENT_MULT_NEUTRAL
	if element == weakness:
		return ELEMENT_MULT_WEAK
	if element == resist:
		return ELEMENT_MULT_RESIST
	return ELEMENT_MULT_NEUTRAL


## 是否命中弱点（决定击退的唯一入口，别在别处重复判等）
static func is_weakness_hit(element: String, weakness: String) -> bool:
	return (not element.is_empty()) and element != ELEMENT_NONE and element == weakness


## 是否触发击退（§3.1 触发条件 + §3.2 例外）：
## 命中弱点 且 目标未处于防御姿态——§3.2"若在防御状态下被弱点属性命中，
## 不触发击退（防御=稳住阵脚，规则自洽）"。
static func should_knockback(element: String, weakness: String, target_defending: bool) -> bool:
	return is_weakness_hit(element, weakness) and not target_defending


## 浮动钳制（防御式：调用方传入越界值时拉回 §3.6 区间，不静默放大）
static func clamp_variance(variance: float) -> float:
	return clampf(variance, VARIANCE_MIN, VARIANCE_MAX)


## 把调用方给的 [0,1] 随机 roll 映射成 §3.6 的浮动系数 0.9~1.1。
## 这是"随机外部化"的接缝：core 不抽随机，只做映射——
## 于是单测可以传 roll=0.0 / 1.0 拿到浮动的两端精确值，而不是区间。
static func variance_from_roll(roll: float) -> float:
	return lerpf(VARIANCE_MIN, VARIANCE_MAX, clampf(roll, 0.0, 1.0))


## 受击方伤害倍率：防御 或 掩护 → ×0.5，两者【不叠加】（§3.2 / §3.4）
static func incoming_damage_multiplier(is_defending: bool, is_covering: bool) -> float:
	if is_defending or is_covering:
		return DEFEND_DAMAGE_MULT
	return 1.0


## 物理伤害 = max(1, ATK×2 − DEF×1.5) × 倍率 × 浮动 × 受击倍率
## variance 由调用方传入（1.0 = 无浮动）；damage_mult 传
## incoming_damage_multiplier() 的结果。
static func compute_physical_damage(atk: int, def: int, power: float,
		variance: float = NEUTRAL_VARIANCE, damage_mult: float = 1.0) -> int:
	var base: float = float(atk) * PHYS_ATK_COEF - float(def) * PHYS_DEF_COEF
	base = maxf(base, float(MIN_DAMAGE))
	var raw: float = base * power * clamp_variance(variance) * damage_mult
	# 结果下限 1：GDD 的 max(1,...) 只写在 base 上，但 ×0.5 抗性/防御后
	# 可能算出 0——显示"造成 0 伤害"会被当成 bug（本系统无 MISS，§4.6）
	return maxi(MIN_DAMAGE, int(round(raw)))


## 法术伤害 = max(1, MAG×2.2 − DEF×1.2) × 倍率 × 属性倍率 × 浮动 × 受击倍率
static func compute_magic_damage(mag: int, def: int, power: float, element: String,
		weakness: String, resist: String,
		variance: float = NEUTRAL_VARIANCE, damage_mult: float = 1.0) -> int:
	var base: float = float(mag) * MAG_ATK_COEF - float(def) * MAG_DEF_COEF
	base = maxf(base, float(MIN_DAMAGE))
	var raw: float = (base * power * element_multiplier(element, weakness, resist)
			* clamp_variance(variance) * damage_mult)
	return maxi(MIN_DAMAGE, int(round(raw)))


## 物理伤害预估区间（浮动两端，供 E3-S4 的"— 24~29 —"直读）。
## 放在这里而不是 UI 侧重算，是为了让区间端点与真值共用同一套系数——
## 否则 UI 预估与实际结算会因常量漂移而对不上（且这种对不上极难发现）。
static func physical_damage_range(atk: int, def: int, power: float,
		damage_mult: float = 1.0) -> Vector2i:
	return Vector2i(
			compute_physical_damage(atk, def, power, VARIANCE_MIN, damage_mult),
			compute_physical_damage(atk, def, power, VARIANCE_MAX, damage_mult))


## 法术伤害预估区间（同上）
static func magic_damage_range(mag: int, def: int, power: float, element: String,
		weakness: String, resist: String, damage_mult: float = 1.0) -> Vector2i:
	return Vector2i(
			compute_magic_damage(mag, def, power, element, weakness, resist,
					VARIANCE_MIN, damage_mult),
			compute_magic_damage(mag, def, power, element, weakness, resist,
					VARIANCE_MAX, damage_mult))


## 回复量 = MAG × 技能倍率（§3.6：回复不吃 DEF 项，也不吃浮动）
static func compute_heal(mag: int, power: float) -> int:
	return maxi(0, int(round(float(mag) * power)))


## 中毒每回合伤害 = 最大HP × 5%（§3.6）。
## 取整口径：四舍五入（GDD 未定）；下限 1——否则低血量时毒会变成空转。
static func compute_poison_damage(max_hp: int) -> int:
	return maxi(MIN_DAMAGE, int(round(float(max_hp) * POISON_MAX_HP_RATIO)))


# ==================================================================
# §7. 状态变更（全部纯函数：返回新字典，不修改入参）
# ==================================================================

## 扣血（不修改入参）。存活由 is_alive() 从 hp 派生，无需同步布尔字段。
static func damage_unit(unit: Dictionary, amount: int) -> Dictionary:
	var out: Dictionary = unit.duplicate(true)
	out["hp"] = maxi(0, int(unit.get("hp", 0)) - maxi(0, amount))
	return out


## 回血（钳到上限，不溢出）
static func heal_unit(unit: Dictionary, amount: int) -> Dictionary:
	var out: Dictionary = unit.duplicate(true)
	out["hp"] = mini(int(unit.get("max_hp", 1)), int(unit.get("hp", 0)) + maxi(0, amount))
	return out


## 附加中毒：§3.6"可叠加时长不可叠加伤害"——重复中毒【累加】回合数，
## 单次伤害不随层数放大。
## ⚠️ 工程假设：GDD 只说"可叠加时长"，未说是否有上限。此处按字面实现为
##    无上限累加（3 回合/次）。若文策渊裁定为"刷新为 3 回合"，改本函数
##    一行即可；裁定为"有上限"则加一个 clamp。
static func apply_poison(unit: Dictionary, turns: int = POISON_DURATION) -> Dictionary:
	var out: Dictionary = unit.duplicate(true)
	out["poison_turns"] = int(unit.get("poison_turns", 0)) + turns
	return out


## 中毒回合结算（每回合行动前调用）：扣血 + 剩余回合递减。
## 返回 {"unit": 新单位, "damage": 本回合毒伤}；未中毒时 damage = 0。
static func tick_poison(unit: Dictionary) -> Dictionary:
	if int(unit.get("poison_turns", 0)) <= 0:
		return {"unit": unit.duplicate(true), "damage": 0}
	var dmg: int = compute_poison_damage(int(unit.get("max_hp", 1)))
	var damaged: Dictionary = damage_unit(unit, dmg)
	damaged["poison_turns"] = maxi(0, int(unit.get("poison_turns", 0)) - 1)
	return {"unit": damaged, "damage": dmg}


## 防御指令（§3.2）：置防御姿态 + 回 5 MP。
## 返回 {"unit": 新单位, "mp_recovered": 实际回复量}（已满 MP 时为 0）。
static func apply_defend(unit: Dictionary) -> Dictionary:
	var out: Dictionary = unit.duplicate(true)
	out["defending"] = true
	var before: int = int(unit.get("mp", 0))
	var after: int = mini(int(unit.get("max_mp", 0)), before + DEFEND_MP_RECOVER)
	out["mp"] = after
	return {"unit": out, "mp_recovered": after - before}


## 轮末重置瞬时姿态标记（defending / covering）。
## 不重置的后果是静默且严重的：防御态泄漏到下一轮 = 永久减伤 50%，
## 表现为"敌人打不动人"，排查时会先怀疑数值表而不是这个标记。
static func reset_round_flags(unit: Dictionary) -> Dictionary:
	var out: Dictionary = unit.duplicate(true)
	out["defending"] = false
	out["covering"] = false
	return out


# ==================================================================
# §8. 逃跑判定（GDD §3.5）
# ==================================================================

## 存活单位的平均 SPD（只统计存活者——逃跑与队列口径都用"当前在场"的速度）
static func average_spd(units: Array) -> float:
	var total: int = 0
	var count: int = 0
	for u: Dictionary in units:
		if is_alive(u):
			total += int(u.get("spd", 0))
			count += 1
	if count == 0:
		return 0.0
	return float(total) / float(count)


## 逃跑成功率 = 70% + (我方平均SPD − 敌方平均SPD) × 2%，钳 30%~95%
static func escape_chance(party: Array, enemies: Array) -> float:
	var diff: float = average_spd(party) - average_spd(enemies)
	return clampf(ESCAPE_BASE + diff * ESCAPE_SPD_COEF, ESCAPE_MIN, ESCAPE_MAX)


## 逃跑检定（随机外部化）：roll 由调用方给 [0,1)，core 只做阈值比较。
## 返回 true = 逃脱成功。
static func escape_success(party: Array, enemies: Array, roll: float) -> bool:
	return clampf(roll, 0.0, 1.0) < escape_chance(party, enemies)
