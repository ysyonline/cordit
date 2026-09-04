extends Resource
## EquipmentData —— 装备表行数据（E6-S1 T3.3，最小装备 schema）
##
## 【正本】game-concept.md "数值系统：装备槽（武器/防具各一件，不搞饰品）"
##   + EPIC-6 E6-S1"装备页（武器/防具各一件更换）；写回 GameData"
##
## 【为什么独立一张表，不进道具表】道具（ItemData）是消耗品语义：
##   kind 描述"用的效果"、usable_phase 描述"何时能用"、count 递减。
##   装备是持装语义：换装不消耗、无阶段概念、数值加成挂在面板——
##   塞进 ItemData 需要给三个字段都开特例，违反 ADR-2"不为凑复用歪 schema"。
##   （GDD v1.1 D4 曾删除角色表装备字段，理由是"当时无装备系统"；
##   E6-S1 装备页立项即按新 schema 重建，与本表不冲突。）
##
## 【数值口径】一件装备 ≈ 一级成长（2026-09-04 T3.3 裁定）：
##   武器 atk_bonus 对齐凯尔 per_level.atk=3；防具 def_bonus 对齐三人
##   per_level.def=2。Lv1 装满 ≈ Lv2 面板，温和不出圈；B1 教学场
##   （玩家大概率未换装）节奏不受影响。
##
## 【引用方式】preload 常量（项目规范，理由同 character_record.gd 头注释）。
## 【定位】纯数据 schema，零场景依赖（A1 铁律 3）。

## 槽位种类（概念文档：武器/防具各一件，不搞饰品）
const SLOT_WEAPON := "weapon"
const SLOT_ARMOR := "armor"
const SLOT_VALUES := ["weapon", "armor"]

## 装备稳定 id（内容表主键；party 记录与持有池均引用此 id）
@export var id: String = ""

## 装备显示名（如"旧铁剑"）
@export var name: String = ""

## 槽位（SLOT_*；决定能装到角色哪个槽）
@export_enum("武器:weapon", "防具:armor") var slot: String = SLOT_WEAPON

## ATK 加成（面板值与战斗伤害并项同源；防具恒 0）
@export var atk_bonus: int = 0

## DEF 加成（两个伤害公式的守方项；武器恒 0）
@export var def_bonus: int = 0

## 描述文本（装备页列表直读，中文）
@export var description: String = ""


## 值域校验：返回错误描述数组，空数组 = 合法
func validate() -> Array[String]:
	var errs: Array[String] = []
	if id.is_empty():
		errs.append("id 为空")
	if name.is_empty():
		errs.append("name 为空")
	if not SLOT_VALUES.has(slot):
		errs.append("slot 非法：%s" % slot)
	# 交叉约束：加成不得为负（装备系统无诅咒件，出现负值=录错字段）
	if atk_bonus < 0 or def_bonus < 0:
		errs.append("加成不得为负：atk=%d def=%d" % [atk_bonus, def_bonus])
	# 交叉约束：武器只加 ATK、防具只加 DEF（最小 schema：一对一槽位语义）
	if slot == SLOT_WEAPON and def_bonus != 0:
		errs.append("武器不得带 DEF 加成（%d）" % def_bonus)
	if slot == SLOT_ARMOR and atk_bonus != 0:
		errs.append("防具不得带 ATK 加成（%d）" % atk_bonus)
	# 交叉约束：至少有一项加成（零加成装备没有存在意义）
	if atk_bonus == 0 and def_bonus == 0:
		errs.append("atk_bonus 与 def_bonus 不可同时为 0")
	return errs
