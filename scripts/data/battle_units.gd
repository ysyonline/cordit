extends RefCounted
## BattleUnits —— 数值表（.tres）→ 战斗单位字典的构建桥（E3-S2 配套）
##
## 【为什么单独一个文件，而不是塞进 battle_logic.gd】
##   battle_logic.gd 刻意保持【零 import】——它是纯算法层，只认纯 Dictionary，
##   不认识 CharacterData / EnemyData / DataTables。
##   "从数值表读出角色/敌人并组装成单位字典"是数据层职责，放这里。
##   两个收益：
##     ① 数值 schema 变动只改本文件，算法层一行不动；
##     ② battle_logic 的单测不需要任何 .tres，手工字典即可——
##        于是"算法对不对"与"表填得对不对"是两类互不干扰的失败。
##
## 【引用风格】preload 常量（项目规范）。
## 【值域】敌人无 MP / 无 MAG（GDD §5 敌人表无这两个字段，攻击一律走物理公式）。

const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")


## 角色 id + 等级 -> 我方单位字典。
## 六维走 CharacterData.stats_at(level)（E3-S2 口径③：派生函数直接用，
## 不要在调用方自己再算一遍 base + per_level × (level-1)）。
## 槽位取 PARTY_ORDER 的下标——它同时是 §3.1"同 SPD 时我方按队伍槽位序"的键。
static func build_party_unit(character_id: String, level: int = 1) -> Dictionary:
	var c: Resource = DataTables.get_character(character_id)
	if c == null:
		push_warning("[BattleUnits] 角色 id 不存在：%s" % character_id)
		return {}
	var s: Dictionary = c.stats_at(level)
	return BattleLogic.make_unit({
		"unit_id": c.id,
		"name": c.name,
		"side": BattleLogic.SIDE_PARTY,
		"slot": DataTables.PARTY_ORDER.find(character_id),
		"level": level,
		"hp": int(s["hp"]),
		"max_hp": int(s["hp"]),
		"mp": int(s["mp"]),
		"max_mp": int(s["mp"]),
		"atk": int(s["atk"]),
		"def": int(s["def"]),
		"mag": int(s["mag"]),
		"spd": int(s["spd"]),
	})


## 构建完整三人队伍（满血满蓝开局，按 PARTY_ORDER 槽位序返回）。
## 战斗初始化若要沿用 GameData 的当前血量，用 build_party_unit 逐个构造后
## 再覆写 hp/mp（战后写回的逆操作）——本函数只负责"表 -> 单位"这一步。
static func build_party(level: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in DataTables.PARTY_ORDER:
		var unit: Dictionary = build_party_unit(id, level)
		if not unit.is_empty():
			out.append(unit)
	return out


## 敌人 id + 生成槽位 -> 敌方单位字典。
## 槽位由调用方传（编组展开时的下标），它同时是 §3.1"同 SPD 时敌方按
## 生成槽位序"的键——因此编组表 members 的数组顺序直接决定同速敌人的先后。
static func build_enemy_unit(enemy_id: String, slot: int = 0) -> Dictionary:
	var e: Resource = DataTables.get_enemy(enemy_id)
	if e == null:
		push_warning("[BattleUnits] 敌人 id 不存在：%s" % enemy_id)
		return {}
	return BattleLogic.make_unit({
		"unit_id": e.id,
		"name": e.name,
		"side": BattleLogic.SIDE_ENEMY,
		"slot": slot,
		"hp": e.hp,
		"max_hp": e.hp,
		"mp": 0,
		"max_mp": 0,
		"atk": e.atk,
		"def": e.def,
		"mag": 0,        # 敌人无 MAG：攻击一律走物理公式
		"spd": e.spd,
		"weakness": e.weakness,
		"resist": e.resist,
	})


## 编组 id -> 敌方单位数组，按 members 顺序 × count 展开（§7 B1-B5 编组）。
## expand_enemy_ids() 已按"成员顺序 × 数量"展开，此处逐个带上槽位下标。
static func build_encounter(encounter_id: String) -> Array[Dictionary]:
	var group: Resource = DataTables.get_encounter(encounter_id)
	if group == null:
		push_warning("[BattleUnits] 编组 id 不存在：%s" % encounter_id)
		return []
	var out: Array[Dictionary] = []
	var ids: Array[String] = group.expand_enemy_ids()
	for i: int in ids.size():
		var unit: Dictionary = build_enemy_unit(ids[i], i)
		if not unit.is_empty():
			out.append(unit)
	return out


## 编组 id -> 是否禁用逃跑（§3.5：仅 Boss 战禁用，由编组表 is_boss 驱动）。
## 单独暴露是因为这条规则在【编组】层而非敌人层——E3-S3 置灰逃跑菜单时
## 查编组，不要去敌人表里找 is_boss（那里没有）。
static func is_escape_forbidden(encounter_id: String) -> bool:
	var group: Resource = DataTables.get_encounter(encounter_id)
	if group == null:
		return false
	return bool(group.is_boss)
