extends Resource
## EncounterGroup —— 敌方编组表行数据（E3-S1，战斗 GDD §7 B1-B5 编排）
##
## 【正本】design/gdd/battle-system-gdd.md
##   §7 数值/平衡首轮方案（5 场战斗编排：敌方配置 / 教学意图 / 预期等级）
##   架构 A5：BattlePayload.enemy_group_id → 战斗侧据此查敌方配置
##   §3.5 逃跑：仅普通战斗可逃，Boss 战禁用（菜单置灰）
##
## 【为什么需要第 6 张表】
##   敌人表（enemy_data.gd）是"敌人种类"，一行 = 一种敌人；
##   但 A5 的 enemy_group_id 与 §7 的"B2 = 甲虫×2 / B3 = 四种敌人混编"
##   都是【一场战斗的编组】——种类表表达不了"同种多个"与"多同种组合"。
##   本表即为"编组"这一层，是 enemy_group_id 的直接查表对象。
##   GDD §5 未列此表（§5 只讲到敌人种类），属工程必要的补充表，
##   已列入回传偏差清单待主理人确认。
##
## 【定位】纯数据 schema + 纯函数派生，零场景依赖（A1 铁律 3）。
## 【引用风格】preload 常量（项目规范）。

## 编组 id（A5 BattlePayload.enemy_group_id 的取值；地图侧 visible_enemy
## 的 group_id 导出项填此值，如 "b2_beetles"）
@export var id: String = ""

## 编组显示名（调试与战斗开场提示用，如"雷壳甲虫"）
@export var name: String = ""

## 编组成员数组，元素形如：{"enemy_id": String, "count": int}
## 顺序即敌方生成槽位序，同时是 §3.1"敌方之间按生成槽位序"的排序依据——
## 改数组顺序会改变同 SPD 敌人的行动先后，调序即调战斗节奏。
@export var members: Array[Dictionary] = []

## 是否为 Boss 战（true → 逃跑指令禁用置灰，§3.5；B4 精英战为 false）
@export var is_boss: bool = false

## 是否锁定【技能】指令（GDD v1.1 新增，服务 §7 B1 教学意图）。
##   true → 战斗中技能菜单不可用/置灰，只开放攻击与道具，
##   逼玩家先学会"攻击/道具"这两条基础指令，再在 B2 接触克制。
##   目前仅 B1（道路飞蛾）为 true——B1 的教学意图原文是
##   "纯教学：攻击/道具，无压力"，而实测 B1 若不锁技能，
##   莉娜 Lv1 火球可单杀飞蛾，玩家根本来不及体验被教学的那两条指令。
## ⚠️ 锁技能【不等于】锁防御：防御永远可用（§3.6 边缘 4 防软锁），
##    因此本字段只影响技能菜单，不得用于禁用攻击/防御/道具。
@export var skills_locked: bool = false

## 所在位置（§7：road 道路 / ruin_f1 遗迹一层 / ruin_f2 二层 / ruin_f3 三层）
@export var location: String = ""

## 教学意图（§7 表格"教学意图"列原文摘录；不参与计算，供调校时对照）
@export var teaching_intent: String = ""

## 预期等级（§7 表格"预期等级"列；调校时的基准，不参与计算）
@export var expected_level: String = ""


## 编组内敌人总数（含同种多只；队列容量与 UI 布局的预分配依据）
func total_enemies() -> int:
	var total: int = 0
	for entry: Dictionary in members:
		total += int(entry.get("count", 0))
	return total


## 展开为逐个敌人的 id 列表（按成员顺序 × count，供战斗实例化直接遍历）
func expand_enemy_ids() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in members:
		var enemy_id: String = String(entry.get("enemy_id", ""))
		var count: int = int(entry.get("count", 0))
		for _i: int in count:
			out.append(enemy_id)
	return out


## 值域校验：返回错误描述数组，空数组 = 合法
func validate() -> Array[String]:
	var errs: Array[String] = []
	if id.is_empty():
		errs.append("id 为空")
	if name.is_empty():
		errs.append("name 为空")
	if members.is_empty():
		errs.append("members 为空")
	for i: int in members.size():
		var entry: Dictionary = members[i]
		if String(entry.get("enemy_id", "")).is_empty():
			errs.append("members[%d].enemy_id 为空" % i)
		var count: int = int(entry.get("count", 0))
		if count <= 0:
			errs.append("members[%d].count 非正：%d" % [i, count])
	return errs
