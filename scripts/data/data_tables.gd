extends RefCounted
## DataTables —— 数值表总装载器（E3-S1）
##
## 【职责】把 data/resources/ 下的 .tres 行数据集中成一处查询入口，
##   让战斗逻辑（E3-S2 的 scripts/core/battle_logic.gd）与 UI 只读这一个
##   文件，不在业务代码里散落 load() 字符串拼接。
##
## 【为什么用 preload 而不是 load】
##   preload 在【解析期】校验路径——路径写错是编译错误，而不是运行时
##   返回 null 后炸在半路。代价是启动时全表驻留内存；切片共 35 个
##   小 Resource（每个 ~10 个字段），量级远小于一张贴图，可忽略。
##
## 【为什么用 static 而不是单例】
##   ① 架构 A3 只批了 4 个 Autoload，为查表加第 5 个单例属架构气味；
##   ② 本类零状态，单例的唯一收益（跨场景存活）用不上——Resource 本身
##     被引擎缓存，preload 常量在任何节点里取到的是同一份实例。
##   调用方式：const DataTables := preload("res://scripts/data/data_tables.gd")
##             DataTables.get_skill("fireball")
##
## 【定位】纯查询层，零场景依赖、零 IO、零全局状态（A1 铁律 3 / A3 边界）。

# ------------------------------------------------------------------
# 类型常量（preload 脚本即类型，项目规范：不用全局 class_name）
# ------------------------------------------------------------------

const CharacterData := preload("res://scripts/data/character_data.gd")
const SkillData := preload("res://scripts/data/skill_data.gd")
const EnemyData := preload("res://scripts/data/enemy_data.gd")
const DropData := preload("res://scripts/data/drop_data.gd")
const ItemData := preload("res://scripts/data/item_data.gd")
const EquipmentData := preload("res://scripts/data/equipment_data.gd")
const EncounterGroup := preload("res://scripts/data/encounter_group.gd")
const GrowthCurve := preload("res://scripts/data/growth_curve.gd")
const EnemyActionCatalog := preload("res://scripts/data/enemy_action_catalog.gd")

# ------------------------------------------------------------------
# 行数据索引（id -> .tres 实例）
# ------------------------------------------------------------------

## 角色表（战斗 GDD §5 characters；三人小队，槽位序即队伍序）
const CHARACTERS: Dictionary = {
	"kyle": preload("res://data/resources/characters/kyle.tres"),
	"lina": preload("res://data/resources/characters/lina.tres"),
	"mona": preload("res://data/resources/characters/mona.tres"),
}

## 技能表（§5 skills；9 个 = 三人 × 3，见 §3.4）
const SKILLS: Dictionary = {
	# 凯尔 · 剑士
	"heavy_slash": preload("res://data/resources/skills/heavy_slash.tres"),
	"wide_sweep": preload("res://data/resources/skills/wide_sweep.tres"),
	"cover": preload("res://data/resources/skills/cover.tres"),
	# 莉娜 · 术士
	"fireball": preload("res://data/resources/skills/fireball.tres"),
	"ice_shard": preload("res://data/resources/skills/ice_shard.tres"),
	"thunder_burst": preload("res://data/resources/skills/thunder_burst.tres"),
	# 莫娜 · 辅助
	"heal": preload("res://data/resources/skills/heal.tres"),
	"group_heal": preload("res://data/resources/skills/group_heal.tres"),
	"cleanse": preload("res://data/resources/skills/cleanse.tres"),
}

## 敌人表（§5 enemies；B1-B5 出现的全部 6 种敌人）
const ENEMIES: Dictionary = {
	"moth": preload("res://data/resources/enemies/moth.tres"),
	"beetle": preload("res://data/resources/enemies/beetle.tres"),
	"salamander": preload("res://data/resources/enemies/salamander.tres"),
	"crystal": preload("res://data/resources/enemies/crystal.tres"),
	"guardian": preload("res://data/resources/enemies/guardian.tres"),
	"core": preload("res://data/resources/enemies/core.tres"),
}

## 掉落表（§5 drops；每种敌人一条）
const DROPS: Dictionary = {
	"drop_moth": preload("res://data/resources/drops/drop_moth.tres"),
	"drop_beetle": preload("res://data/resources/drops/drop_beetle.tres"),
	"drop_salamander": preload("res://data/resources/drops/drop_salamander.tres"),
	"drop_crystal": preload("res://data/resources/drops/drop_crystal.tres"),
	"drop_guardian": preload("res://data/resources/drops/drop_guardian.tres"),
	"drop_core": preload("res://data/resources/drops/drop_core.tres"),
}

## 道具表（§5 items，战斗侧只读）
const ITEMS: Dictionary = {
	"potion_s": preload("res://data/resources/items/potion_s.tres"),
	"potion_m": preload("res://data/resources/items/potion_m.tres"),
	"potion_l": preload("res://data/resources/items/potion_l.tres"),
	"ether_s": preload("res://data/resources/items/ether_s.tres"),
	"antidote": preload("res://data/resources/items/antidote.tres"),
}

## 装备表（E6-S1 T3.3 最小装备 schema；切片 2 件=初始背包直塞配额）
const EQUIPMENTS: Dictionary = {
	"iron_sword": preload("res://data/resources/equipment/iron_sword.tres"),
	"leather_armor": preload("res://data/resources/equipment/leather_armor.tres"),
}

## 敌方编组表（§7 B1-B5 编排；A5 enemy_group_id 的查表对象）
const ENCOUNTERS: Dictionary = {	"b1_moth": preload("res://data/resources/encounters/b1_moth.tres"),
	"b2_beetles": preload("res://data/resources/encounters/b2_beetles.tres"),
	"b3_ruin_mix": preload("res://data/resources/encounters/b3_ruin_mix.tres"),
	"b4_guardian": preload("res://data/resources/encounters/b4_guardian.tres"),
	"b5_core": preload("res://data/resources/encounters/b5_core.tres"),
}

## 升级经验曲线（补充表，见 growth_curve.gd 头注释）
const GROWTH: GrowthCurve = preload("res://data/resources/growth_curve.tres")

## 敌方行为目录（全局单例，v1.1 从 enemy_data.gd 类常量迁出；
## 见 enemy_action_catalog.gd 头注释）
const ACTION_CATALOG: EnemyActionCatalog = preload("res://data/resources/enemy_action_catalog.tres")

## 队伍槽位序（战斗 GDD §3.1：我方之间按队伍槽位序 剑士→术士→辅助）
const PARTY_ORDER: Array[String] = ["kyle", "lina", "mona"]


# ------------------------------------------------------------------
# 单行查询（未知 id 返回 null，调用方自行判空）
# ------------------------------------------------------------------

static func get_character(id: String) -> CharacterData:
	return CHARACTERS.get(id, null)


static func get_skill(id: String) -> SkillData:
	return SKILLS.get(id, null)


static func get_enemy(id: String) -> EnemyData:
	return ENEMIES.get(id, null)


static func get_drop(id: String) -> DropData:
	return DROPS.get(id, null)


static func get_item(id: String) -> ItemData:
	return ITEMS.get(id, null)


static func get_equipment(id: String) -> EquipmentData:
	return EQUIPMENTS.get(id, null)


static func get_encounter(id: String) -> EncounterGroup:
	return ENCOUNTERS.get(id, null)


## 按队伍槽位序取三人角色数据（战斗初始化与 UI 布局的唯一入口）
static func get_party() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for id: String in PARTY_ORDER:
		var data: CharacterData = get_character(id)
		if data != null:
			out.append(data)
	return out


# ------------------------------------------------------------------
# 全表校验（测试与调校入口）
# ------------------------------------------------------------------

## 对全部表逐行跑 validate()，返回 {表名: {行 id: 错误数组}}。
## 空错误数组的行不出现在结果里——返回值里出现任何条目即数据有问题。
## tests/gut/test_e3s1.gd 直接断言"结果为空字典"。
static func validate_all() -> Dictionary:
	var problems: Dictionary = {}
	_collect_problems(problems, "characters", CHARACTERS)
	_collect_problems(problems, "skills", SKILLS)
	_collect_problems(problems, "enemies", ENEMIES)
	_collect_problems(problems, "drops", DROPS)
	_collect_problems(problems, "items", ITEMS)
	_collect_problems(problems, "encounters", ENCOUNTERS)
	var growth_errs: Array = GROWTH.validate()
	if not growth_errs.is_empty():
		problems["growth_curve"] = {"growth_curve": growth_errs}
	return problems


## 收集单表的校验结果（内部工具）
static func _collect_problems(out: Dictionary, table_name: String, table: Dictionary) -> void:
	for id: String in table:
		var row: Resource = table[id]
		if row == null:
			out[table_name] = {id: ["资源加载为 null"]}
			continue
		if not row.has_method("validate"):
			out[table_name] = {id: ["行数据未实现 validate()"]}
			continue
		var errs: Array = row.validate()
		if not errs.is_empty():
			if not out.has(table_name):
				out[table_name] = {}
			out[table_name][id] = errs


## 引用完整性校验：跨表 id 引用是否存在悬空（ADR-2"引用完整性"的机器判据）
## 检查三组引用：角色表.skills_by_level → 技能表；
##               敌人表.drop_id → 掉落表；掉落表.items[].item_id → 道具表；
##               编组表.members[].enemy_id → 敌人表。
static func validate_references() -> Array[String]:
	var errs: Array[String] = []
	for cid: String in CHARACTERS:
		var character: CharacterData = CHARACTERS[cid]
		for lv: int in character.skills_by_level:
			for sid: String in character.skills_by_level[lv]:
				if not SKILLS.has(sid):
					errs.append("characters/%s 引用了不存在的技能：%s" % [cid, sid])
	for eid: String in ENEMIES:
		var enemy: EnemyData = ENEMIES[eid]
		if not DROPS.has(enemy.drop_id):
			errs.append("enemies/%s 引用了不存在的掉落表：%s" % [eid, enemy.drop_id])
	for did: String in DROPS:
		var drop: DropData = DROPS[did]
		for entry: Dictionary in drop.items:
			var item_id: String = String(entry.get("item_id", ""))
			if not ITEMS.has(item_id):
				errs.append("drops/%s 引用了不存在的道具：%s" % [did, item_id])
	for gid: String in ENCOUNTERS:
		var group: EncounterGroup = ENCOUNTERS[gid]
		for entry: Dictionary in group.members:
			var enemy_id: String = String(entry.get("enemy_id", ""))
			if not ENEMIES.has(enemy_id):
				errs.append("encounters/%s 引用了不存在的敌人：%s" % [gid, enemy_id])
	return errs
