extends Resource
## ItemData —— 道具表行数据（E3-S1，战斗 GDD §5 道具表）
##
## 【正本】design/gdd/battle-system-gdd.md
##   §5 道具表字段（战斗侧只读）：id, name, kind(回HP/回MP/解毒),
##      value, 可用阶段(地图/战斗/皆可)
##   §3.2 道具指令：战斗中可用回复类道具（回复 HP/MP/解毒），
##      目标可为任意我方单体（含自己），每回合限用 1 个
##   §6 I2 探索奖励：掉落写入背包走道具表通用接口，战斗侧不感知背包结构
##
## 【定位】纯数据 schema + 纯函数判定，零场景依赖（A1 铁律 3）。
## 【引用风格】preload 常量（项目规范）。
##
## 【获取途径说明】切片无商店（GDD §3.5 裁决），道具来源只有两处：
##   ① 战斗掉落（本表 + drops 表）；② 宝箱事件 give_item（探索侧 JSON）。
##   解毒草刻意挂在 B3 冰晶掉落上——B4（遗迹二层）才出现中毒，
##   B3（遗迹一层）先给解药是给玩家的预置容错通道。

## 道具种类（GDD §5 kind：回HP/回MP/解毒）
const KIND_HEAL_HP := "heal_hp"  # 回复 HP，value = 回复量
const KIND_HEAL_MP := "heal_mp"  # 回复 MP，value = 回复量
const KIND_DETOX := "detox"      # 解毒，value 不参与计算（恒 0）
const KIND_VALUES := ["heal_hp", "heal_mp", "detox"]

## 可用阶段（GDD §5 可用阶段：地图/战斗/皆可）
const PHASE_MAP := "map"        # 仅地图可用
const PHASE_BATTLE := "battle"  # 仅战斗可用
const PHASE_BOTH := "both"      # 地图与战斗皆可（切片内回复类全取此项）
const PHASE_VALUES := ["map", "battle", "both"]

## 道具 id（内容表主键；drops 表 items[].item_id 与背包键均引用此 id）
@export var id: String = ""

## 道具显示名（如"小药瓶"）
@export var name: String = ""

## 道具种类（见 KIND_* 常量）
@export_enum("回HP:heal_hp", "回MP:heal_mp", "解毒:detox") var kind: String = KIND_HEAL_HP

## 数值：回HP/回MP 为回复量；解毒恒 0（规则型效果，无数值）
@export var value: int = 0

## 可用阶段（见 PHASE_* 常量；战斗指令菜单据此过滤可选项）
@export_enum("地图:map", "战斗:battle", "皆可:both") var usable_phase: String = PHASE_BOTH

## 描述文本（菜单与获取提示直读，中文）
@export var description: String = ""


## 战斗中是否可用（战斗指令菜单过滤用）
func usable_in_battle() -> bool:
	return usable_phase == PHASE_BATTLE or usable_phase == PHASE_BOTH


## 地图上是否可用（菜单 UI 过滤用）
func usable_in_map() -> bool:
	return usable_phase == PHASE_MAP or usable_phase == PHASE_BOTH


## 值域校验：返回错误描述数组，空数组 = 合法
func validate() -> Array[String]:
	var errs: Array[String] = []
	if id.is_empty():
		errs.append("id 为空")
	if name.is_empty():
		errs.append("name 为空")
	if not KIND_VALUES.has(kind):
		errs.append("kind 非法：%s" % kind)
	if not PHASE_VALUES.has(usable_phase):
		errs.append("usable_phase 非法：%s" % usable_phase)
	# 交叉约束：回复类必须有正数值，否则吃了没反应（静默失效最难查）
	if kind != KIND_DETOX and value <= 0:
		errs.append("%s 的 value 应为正，实际 %d" % [kind, value])
	# 交叉约束：解毒为规则型效果，value 必须为 0（非 0 说明录错了字段）
	if kind == KIND_DETOX and value != 0:
		errs.append("解毒类 value 应为 0，实际 %d" % value)
	return errs
