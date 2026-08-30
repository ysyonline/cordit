extends Resource
## SkillData —— 技能表行数据（E3-S1，战斗 GDD §5 技能表）
##
## 【正本】design/gdd/battle-system-gdd.md
##   §5 技能表字段：id, name, kind(物理/法术/回复/功能), element(无/火/冰/雷),
##      power(倍率), target(敌单/敌群/我单/我群), mp_cost,
##      effect_tag(无/解毒/掩护), 学习等级, 描述文本
##   §3.4 角色技能表（三人 × 3 = 9 技能，MP/目标/效果的唯一出处）
##   §3.6 伤害/回复公式（power 在公式里的位置）
##
## 【公式挂接说明】（供 E3-S2 的 battle_logic.gd 直读，不含算法）
##   物理：伤害 = max(1, ATK×2 − DEF×1.5) × power × 浮动(0.9~1.1)
##   法术：伤害 = max(1, MAG×2.2 − DEF×1.2) × power × 属性倍率 × 浮动
##   回复：回复量 = MAG × power（不吃 DEF 项）
##   功能：power 不参与数值计算（掩护/解毒为规则型效果），恒填 0.0
##
## 【定位】纯数据 schema + 纯函数判定，零场景依赖（A1 铁律 3）。
## 【引用风格】preload 常量（项目规范）。
## 【值域校验】见 validate()，由 tests/gut/test_e3s1.gd 全表断言。

## 技能种类（GDD §5 kind：物理/法术/回复/功能）
const KIND_PHYSICAL := "physical"  # 物理：走物理伤害公式
const KIND_MAGIC := "magic"       # 法术：走法术伤害公式（吃属性克制）
const KIND_HEAL := "heal"         # 回复：MAG × power，不吃 DEF
const KIND_UTILITY := "utility"   # 功能：规则型效果，power 恒 0
const KIND_VALUES := ["physical", "magic", "heal", "utility"]

## 属性（GDD §5 element：无/火/冰/雷）
const ELEMENT_NONE := "none"
const ELEMENT_FIRE := "fire"
const ELEMENT_ICE := "ice"
const ELEMENT_THUNDER := "thunder"
const ELEMENT_VALUES := ["none", "fire", "ice", "thunder"]

## 三系克制倍率（GDD §3.3：弱点 ×1.5 / 无相性 ×1.0 / 抗性 ×0.5；
## 三系之间互不构成循环克制，相性只由敌人表 weakness/resist 决定）。
##
## ⚠️ 倍率的【唯一出处】已迁到 scripts/core/battle_logic.gd 的
## `ELEMENT_MULT_WEAK / ELEMENT_MULT_NEUTRAL / ELEMENT_MULT_RESIST`
## （E3-S2 起，公式系数集中在 core 的常量块统一管理）。
## 本类不再重复声明，避免"两处各改一处"的漂移——需要倍率请引 BattleLogic。

## 目标类型（GDD §5 target：敌单/敌群/我单/我群）
const TARGET_ENEMY_SINGLE := "enemy_single"
const TARGET_ENEMY_ALL := "enemy_all"
const TARGET_ALLY_SINGLE := "ally_single"
const TARGET_ALLY_ALL := "ally_all"
const TARGET_VALUES := ["enemy_single", "enemy_all", "ally_single", "ally_all"]

## 效果标签（GDD §5 effect_tag：无/解毒/掩护）
const TAG_NONE := "none"        # 无附加规则，走通用数值结算
const TAG_DETOX := "detox"      # 解毒：清除目标中毒（中毒仅存于 B4/B5）
const TAG_COVER := "cover"      # 掩护：本回合代替目标承伤，自身承伤 ×0.5
const TAG_VALUES := ["none", "detox", "cover"]

## 技能 id（内容表主键；角色表 skills_by_level 引用此 id）
@export var id: String = ""

## 技能显示名（战斗 UI 菜单项；如"重斩"）
@export var name: String = ""

## 技能种类（见 KIND_* 常量；决定用哪条公式）
@export_enum("物理:physical", "法术:magic", "回复:heal", "功能:utility") var kind: String = KIND_PHYSICAL

## 属性（见 ELEMENT_* 常量；仅法术吃克制倍率，物理/回复/功能恒 none）
@export_enum("无:none", "火:fire", "冰:ice", "雷:thunder") var element: String = ELEMENT_NONE

## 倍率（power）：物理/法术为伤害倍率，回复为 MAG 系数，功能恒 0.0
@export var power: float = 1.0

## 目标类型（见 TARGET_* 常量）
@export_enum("敌单:enemy_single", "敌群:enemy_all", "我单:ally_single", "我群:ally_all") var target: String = TARGET_ENEMY_SINGLE

## MP 消耗（§3.4 逐技能给定；MP 不足时菜单置灰，见 §3.6 边缘情况 4）
@export var mp_cost: int = 0

## 效果标签（见 TAG_* 常量；掩护/解毒走规则分支而非数值分支）
@export_enum("无:none", "解毒:detox", "掩护:cover") var effect_tag: String = TAG_NONE

## 学习等级（数值口径裁决见 character_data.gd 头注释第 2 条：
## 每人的首个技能下调至 Lv1，保证首战技能按钮不为空——§3.6 明文要求）
@export var learn_level: int = 1

## 描述文本（GDD §5 字段；战斗 UI 技能说明栏直读，中文）
@export var description: String = ""


## 是否为进攻型技能（走伤害公式：物理 或 法术）
func is_offensive() -> bool:
	return kind == KIND_PHYSICAL or kind == KIND_MAGIC


## 是否为回复型技能（回复量 = MAG × power，不吃 DEF）
func is_healing() -> bool:
	return kind == KIND_HEAL


## 是否吃三系克制（只有法术吃；物理/回复/功能恒 false——§3.5 公式与
## §3.3"相性只由敌人表决定"共同裁定）
func uses_element() -> bool:
	return kind == KIND_MAGIC and element != ELEMENT_NONE


## 值域校验：返回错误描述数组，空数组 = 合法
func validate() -> Array[String]:
	var errs: Array[String] = []
	if id.is_empty():
		errs.append("id 为空")
	if name.is_empty():
		errs.append("name 为空")
	if not KIND_VALUES.has(kind):
		errs.append("kind 非法：%s" % kind)
	if not ELEMENT_VALUES.has(element):
		errs.append("element 非法：%s" % element)
	if not TARGET_VALUES.has(target):
		errs.append("target 非法：%s" % target)
	if not TAG_VALUES.has(effect_tag):
		errs.append("effect_tag 非法：%s" % effect_tag)
	if mp_cost < 0:
		errs.append("mp_cost 为负：%d" % mp_cost)
	if learn_level < 1:
		errs.append("learn_level 小于 1：%d" % learn_level)
	# 交叉约束：功能技不参与数值计算，power 必须是 0
	if kind == KIND_UTILITY and not is_zero_approx(power):
		errs.append("功能技 power 应为 0，实际 %f" % power)
	# 交叉约束：非功能技必须有正倍率，否则结算恒为 0（静默失效）
	if kind != KIND_UTILITY and power <= 0.0:
		errs.append("%s 技 power 应为正，实际 %f" % [kind, power])
	# 交叉约束：元素只对法术有意义（物理带元素会静默丢失克制收益）
	if element != ELEMENT_NONE and kind != KIND_MAGIC:
		errs.append("非术法技能不得带元素：kind=%s element=%s" % [kind, element])
	return errs
