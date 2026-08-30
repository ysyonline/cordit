extends Resource
## EnemyData —— 敌人表行数据（E3-S1，战斗 GDD §5 敌人表）
##
## 【正本】design/gdd/battle-system-gdd.md
##   §5 敌人表字段：id, name, sprite_id, hp, atk, def, spd, weakness(可空),
##      resist(可空), exp, drop_id, ai_pattern(见下), 行为权重
##   §5 AI 模式（最小版）：每敌人一个权重表——普通敌 {攻击:100}；
##      精英 {攻击:60, 毒击:25, 群击:15}；Boss {攻击:50, 单体重击:30, 蓄力:20}
##   §3.3 每个敌人至多 1 弱点、至多 1 抗性（可皆无）
##   §7 B1-B5 五场战斗编排（HP/ATK/弱点/AI 的唯一给定出处）
##
## 【定位】纯数据 schema + 纯函数派生，零场景依赖（A1 铁律 3）。
## 【引用风格】preload 常量（项目规范）。
##
## 【数值来源说明（重要，涉及 GDD 未给的字段）】
##   §7 只给了 B1 飞蛾(HP30/ATK8/无相性)、B2 甲虫(HP45/弱火/ATK9)、
##   B4 守卫(HP240/弱雷/ATK16)、B5 核心(HP480/弱火/ATK18) 的 HP/ATK/弱点。
##   以下字段由 §3.6 的量化规则反推，属【工程初值，待文策渊裁定】：
##     - DEF / SPD：无量化规则，按"克制收益可感知 + 队列序有取舍"手调；
##     - 火蜥/冰晶 的 HP/ATK：按 §3.6"杂兵 HP 30~60"与"敌方 ATK 使无防御
##       角色单次受 8%~15% 最大 HP 伤害"两条规则定档。
##   推导过程与偏差清单见 evidence 回传；改数值只需改 .tres，不改代码（A2）。
##
## 【ai_pattern 与 ai_weights 分列】
##   GDD §5 把 "ai_pattern" 与 "行为权重" 列为两个字段，本表照此分列：
##     ai_pattern = 模式档位（normal/elite/boss，对应 §5 三种权重范式）；
##     ai_weights = 行为权重表（action_key -> int，本表的实际驱动数据）。

## AI 模式档位（GDD §5 三种范式）
const PATTERN_NORMAL := "normal"  # 普通敌：{攻击:100}
const PATTERN_ELITE := "elite"    # 精英：{攻击:60, 毒击:25, 群击:15}
const PATTERN_BOSS := "boss"      # Boss：{攻击:50, 单体重击:30, 蓄力:20}
const PATTERN_VALUES := ["normal", "elite", "boss"]

## 【敌方行为目录已迁出代码】
##   v1.1 裁定：行为目录（倍率 / 目标 / 是否附加中毒 / 是否 telegraph）
##   从本文件的类常量迁入 `data/resources/enemy_action_catalog.tres`
##   ——一个全局单例 Resource，由 `DataTables.ACTION_CATALOG` 访问。
##   理由：倍率是【数值】，按 A2 应走 .tres 而非代码常量；
##        改倍率不该需要改代码、不该需要重跑编辑器导入。
##   本文件因此【不再持有行为词汇表】——行为键的合法性由跨表校验
##   `DataTables.validate_action_keys()` 负责（本文件的 validate() 只校验
##   自身形状：权重非空且为正。这样行内校验保持自包含、不反向依赖目录）。

## 属性取值（与 skill_data.gd 的 ELEMENT_* 同源；空串 = 无相性）
const ELEMENT_VALUES := ["", "none", "fire", "ice", "thunder"]

## 敌人 id（内容表主键；编组表 encounter_group.gd 引用此 id）
@export var id: String = ""

## 敌人显示名（如"道路飞蛾"）
@export var name: String = ""

## 精灵资源标识（美术包入库前为占位 id，仅作装配锚点，不直接 load）
@export var sprite_id: String = ""

## 最大 HP（无"当前 HP"——战斗中 HP 是运行时状态，不进静态表）
@export var hp: int = 1

## ATK（物理伤害公式的攻方项；敌人无 MAG，攻击一律走物理公式）
@export var atk: int = 1

## DEF（两个伤害公式的守方项）
@export var def: int = 0

## SPD（行动队列排序键，静态值）
@export var spd: int = 1

## 弱点属性（可空；命中弱点 ×1.5 且触发击退 2 槽——§3.1/§3.3）
## 至多 1 个，空串表示无弱点
@export var weakness: String = ""

## 抗性属性（可空；命中抗性 ×0.5，无额外效果——§3.1/§3.3）
## 至多 1 个，空串表示无抗性；与 weakness 不得相同
@export var resist: String = ""

## 击破后获得的经验值（GDD §5 列了字段但未给数值与升级曲线；
## 数值为按 §7 预期等级反推的工程初值，见 growth_curve.gd）
@export var exp: int = 0

## 掉落表 id（引用 drops/*.tres 的主键）
@export var drop_id: String = ""

## AI 模式档位（见 PATTERN_* 常量）
@export_enum("普通:normal", "精英:elite", "Boss:boss") var ai_pattern: String = PATTERN_NORMAL

## 行为权重表：{行为键 String -> 权重 int}，由 E3-S3 按权重随机取行为。
## 约定：各项权重之和应 = 100（validate() 校验，便于策划直读百分比）。
@export var ai_weights: Dictionary = {}

## 行为备注（人工可读的设计意图/调校记录；不参与任何计算）
@export var notes: String = ""


## 是否有弱点（空串 = 无）
func has_weakness() -> bool:
	return not weakness.is_empty()


## 是否有抗性（空串 = 无）
func has_resist() -> bool:
	return not resist.is_empty()


## 行为权重总和（校验用：约定 100）
func total_weight() -> int:
	var total: int = 0
	for key: String in ai_weights:
		total += int(ai_weights[key])
	return total


## 值域校验：返回错误描述数组，空数组 = 合法
func validate() -> Array[String]:
	var errs: Array[String] = []
	if id.is_empty():
		errs.append("id 为空")
	if name.is_empty():
		errs.append("name 为空")
	if hp <= 0:
		errs.append("hp 非正：%d" % hp)
	if atk <= 0:
		errs.append("atk 非正：%d" % atk)
	if def < 0:
		errs.append("def 为负：%d" % def)
	if spd <= 0:
		errs.append("spd 非正：%d" % spd)
	# §3.3 硬约束：至多 1 弱点、至多 1 抗性（本表用单字段天然满足"至多 1"，
	# 这里额外拦截"弱抗同源"——同一属性既弱又抗是数据录入错误的典型形态）
	if not ELEMENT_VALUES.has(weakness):
		errs.append("weakness 非法：%s" % weakness)
	if not ELEMENT_VALUES.has(resist):
		errs.append("resist 非法：%s" % resist)
	if has_weakness() and weakness == resist:
		errs.append("weakness 与 resist 不得相同：%s" % weakness)
	if exp < 0:
		errs.append("exp 为负：%d" % exp)
	if drop_id.is_empty():
		errs.append("drop_id 为空（GDD §5 敌人表必填）")
	if not PATTERN_VALUES.has(ai_pattern):
		errs.append("ai_pattern 非法：%s" % ai_pattern)
	if ai_weights.is_empty():
		errs.append("ai_weights 为空")
	# 行为键的词汇校验不在这里做（词汇表在 enemy_action_catalog.tres），
	# 由 DataTables.validate_action_keys() 跨表校验；此处只校验形状。
	for key: String in ai_weights:
		if int(ai_weights[key]) <= 0:
			errs.append("ai_weights 权重非正：%s=%s" % [key, str(ai_weights[key])])
	if total_weight() != 100:
		errs.append("ai_weights 权重和应为 100，实际 %d" % total_weight())
	return errs
