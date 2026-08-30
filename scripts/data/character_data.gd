extends Resource
## CharacterData —— 角色表行数据（E3-S1，战斗 GDD §5 角色表）
##
## 【正本】design/gdd/battle-system-gdd.md
##   §5 角色表字段：id, name, job, base_hp, base_mp, base_atk, base_mag,
##      base_def, spd, per_level 成长值组, skills_by_level[]
##      （"初始装备(武器id/防具id)"已由 v1.1 D4 裁定删除，见文件末说明）
##   §3.6 属性量级（Lv1 初值）与"逐级定值"成长规则
##   §3.4 角色技能表（三人各 3 技能，技能 id 见 skill_data.gd）
##
## 【定位】纯数据 schema + 纯函数派生，零场景依赖：
##   - 不 get_node、不读全局单例、不做 IO（架构 A1 铁律 3 / A3 边界）；
##   - 本文件只回答"某个等级下这个角色的面板是多少 / 会哪些技能"，
##     真正的伤害与队列算法属 E3-S2 的 scripts/core/battle_logic.gd。
##
## 【数值口径裁决（必须读，涉及两处 GDD 内部不一致）】
##   1. Lv1 列取 §3.6 表格左列，per_level 取 §3.6 正文"每级 +X"文本——
##      理由是正文是逐级可实现的规格（升级时逐项累加），而表格右列
##      （Lv5）与正文推算值在 3 处对不上（见 evidence 回传的偏差清单），
##      正文为可实现口径故取正文。
##   2. 技能习得等级：§3.6 正文"Lv1 时三人各已有 1 个基础技能，保证首战
##      技能按钮不为空"与"升级自动习得"清单冲突（清单里没有 Lv1 技能）。
##      裁决：把每人最早习得的技能下调到 Lv1（凯尔 重斩 / 莉娜 火球 /
##      莫娜 治疗），其余 6 个技能等级完全照 §3.6 清单。关键理由：§7 明确
##      B2 的教学意图是"火球首杀触发弱点！+击退"，而 B2 预期等级为
##      Lv1-2——若火球 Lv2 才习得，玩家在 Lv1 打 B2 时教学意图落空。
##
## 【引用风格】preload 常量（项目规范，理由见 scripts/core/character_record.gd
##   头注释：headless 跑测通道不重扫全局类注册表，preload 引用即时可用）。
##
## 【值域校验】不做 @export_enum 之外的运行时拦截：值域由 validate() 返回
##   错误清单，并由 tests/gut/test_e3s1.gd 对全表逐行断言（headless 可跑，
##   比编辑器下拉更强——编辑器下拉只防手滑，不防批量改错）。

## 职业取值（GDD §3.4 三人定位）
const JOB_SWORDSMAN := "swordsman"   # 剑士 · 物理输出
const JOB_SORCERER := "sorcerer"    # 术士 · 法术输出 / 弱点工具箱
const JOB_SUPPORT := "support"      # 辅助 · 治疗与容错
const JOB_VALUES := ["swordsman", "sorcerer", "support"]

## per_level 成长值组的合法键（GDD §3.6：HP/MP/ATK/MAG/DEF 各有成长，
## SPD 为静态值——§1.3 Cut 清单已砍速度 buffs/debuffs，故 spd 恒 +0）
const GROWTH_KEYS := ["hp", "mp", "atk", "mag", "def", "spd"]

## 切片等级上限（GDD §3.6"Lv1 → Lv5，切片内预计升 4 级"）
const MAX_LEVEL := 5

## 角色稳定 id（内容表主键，与 GameData.party[].id 对账）
@export var id: String = ""

## 显示名（战斗 UI / 结算画面直读）
@export var name: String = ""

## 职业标识（见 JOB_* 常量）
@export_enum("剑士:swordsman", "术士:sorcerer", "辅助:support") var job: String = JOB_SWORDSMAN

## Lv1 基础 HP（§3.6 表格左列）
@export var base_hp: int = 1
## Lv1 基础 MP（§3.6 表格左列）
@export var base_mp: int = 0
## Lv1 基础 ATK（物理伤害公式的攻方项，§3.6）
@export var base_atk: int = 1
## Lv1 基础 MAG（法术伤害与回复公式的攻方项，§3.6）
@export var base_mag: int = 1
## Lv1 基础 DEF（两个伤害公式的守方项，§3.6）
@export var base_def: int = 0
## SPD 速度（行动队列排序键；静态值，不随等级成长——§1.3 Cut 清单）
@export var spd: int = 1

## 逐级成长值组（§3.6 正文"每级 +X"）：{hp:int, mp:int, atk:int,
## mag:int, def:int, spd:int}；缺失键按 0 处理（_growth 兜底）。
@export var per_level: Dictionary = {}

## 技能习得表：{等级 int -> 技能 id 数组}。键为 int，值为 Array[String]。
## 例：{1: ["heavy_slash"], 3: ["wide_sweep"], 5: ["cover"]}
@export var skills_by_level: Dictionary = {}

## 【D4 已裁定删除：weapon_id / armor_id】
##   GDD §5 角色表原文列了"初始装备(武器id/防具id)"，但切片无装备表与换装
##   系统，道具表 kind 也只有回HP/回MP/解毒——装备不属于其中任何一张表，
##   留着就是两个恒为空的悬空字段（引用无处可去，还会诱导后来者填值产生
##   假引用）。v1.1 裁定：字段整体删除，等装备系统立项再按新 schema 加回。
##   S1 返工（2026-08-30）：@export 字段已从本类删除，三个角色 .tres 的
##   weapon_id/armor_id 空串字段也已清除——悬空彻底移除。


## 取指定键的每级成长值（缺键按 0，防御式）
func _growth(key: String) -> int:
	return int(per_level.get(key, 0))


## 等级 -> 六维面板（逐级定值累加，无随机——§3.6"不做随机成长"）。
## 入参越界钳到 [1, MAX_LEVEL]；返回键与 GROWTH_KEYS 一致。
func stats_at(level: int) -> Dictionary:
	var lv: int = clampi(level, 1, MAX_LEVEL)
	var steps: int = lv - 1
	return {
		"hp": base_hp + steps * _growth("hp"),
		"mp": base_mp + steps * _growth("mp"),
		"atk": base_atk + steps * _growth("atk"),
		"mag": base_mag + steps * _growth("mag"),
		"def": base_def + steps * _growth("def"),
		"spd": spd + steps * _growth("spd"),
	}


## 等级 -> 已习得技能 id 列表（按等级升序合并，同 id 去重）。
## "截至该等级会哪些技能"是战斗 UI 技能菜单与存档的直接数据源。
func skills_up_to(level: int) -> Array[String]:
	var out: Array[String] = []
	var levels: Array = skills_by_level.keys()
	levels.sort()
	for lv: int in levels:
		if lv > level:
			continue
		var ids: Array = skills_by_level[lv] as Array
		for sid: String in ids:
			if not out.has(sid):
				out.append(sid)
	return out


## 值域校验：返回错误描述数组，空数组 = 合法。
## 由 tests/gut/test_e3s1.gd 对全表逐行调用，作为"字段对齐 §5"的机器判据。
func validate() -> Array[String]:
	var errs: Array[String] = []
	if id.is_empty():
		errs.append("id 为空")
	if name.is_empty():
		errs.append("name 为空")
	if not JOB_VALUES.has(job):
		errs.append("job 非法：%s" % job)
	if base_hp <= 0:
		errs.append("base_hp 非正：%d" % base_hp)
	if base_atk <= 0:
		errs.append("base_atk 非正：%d" % base_atk)
	if base_mag < 0 or base_def < 0 or base_mp < 0:
		errs.append("存在负数基础属性")
	if spd <= 0:
		errs.append("spd 非正：%d" % spd)
	for key: String in per_level:
		if not GROWTH_KEYS.has(key):
			errs.append("per_level 含未知键：%s" % key)
	for lv: int in skills_by_level:
		if lv < 1 or lv > MAX_LEVEL:
			errs.append("skills_by_level 等级越界：%d" % lv)
	return errs
