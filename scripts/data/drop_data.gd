extends Resource
## DropData —— 掉落表行数据（E3-S1，战斗 GDD §5 掉落表）
##
## 【正本】design/gdd/battle-system-gdd.md
##   §5 掉落表字段：id, items[(item_id, 概率)], 保底规则（无；切片掉落全
##      100% 单一道具，不做概率掉落——砍掉随机性 = 省测试）
##
## 【本表的最小化形态】
##   按 §5 的裁决，切片内每个掉落表恒为"1 条记录 + 概率 1.0"，因此 items
##   数组长度恒为 1。保留数组与 probability 字段是为了不偏离 §5 字段形状：
##   将来若恢复概率掉落，只改数据不改 schema（但那需要先过文策渊的
##   "省测试"论证，别悄悄加回来）。
##   count 为实践补充字段（§5 未列）：胜利结算要写"获得 药水 ×1"，
##   没有数量就无法表达多件掉落。默认 1。
##
## 【定位】纯数据 schema + 纯函数派生，零场景依赖（A1 铁律 3）。
## 【引用风格】preload 常量（项目规范）。

## 掉落表 id（内容表主键；敌人表 drop_id 引用此 id）
@export var id: String = ""

## 掉落条目数组，元素形如：
##   {"item_id": String, "probability": float, "count": int}
## 当前切片恒为 1 条、probability = 1.0（§5：全 100% 单一道具）
@export var items: Array[Dictionary] = []

## 保底规则（GDD §5 明文：无）。保留为字段以便策划侧一眼看到该裁决，
## 而不是"字段缺失"被误读为"忘了设计"。非空即视为偏离 GDD，需走裁定。
@export var pity_rule: String = "无"


## 概率总和（§5 口径下恒为 1.0）
func total_probability() -> float:
	var total: float = 0.0
	for entry: Dictionary in items:
		total += float(entry.get("probability", 0.0))
	return total


## 是否为"全 100% 单一道具"形态（§5 裁决形态的机器判据）
func is_single_full_drop() -> bool:
	return items.size() == 1 and is_equal_approx(float((items[0] as Dictionary).get("probability", 0.0)), 1.0)


## 值域校验：返回错误描述数组，空数组 = 合法
func validate() -> Array[String]:
	var errs: Array[String] = []
	if id.is_empty():
		errs.append("id 为空")
	if items.is_empty():
		errs.append("items 为空（至少 1 条掉落）")
	for i: int in items.size():
		var entry: Dictionary = items[i]
		var item_id: String = String(entry.get("item_id", ""))
		if item_id.is_empty():
			errs.append("items[%d].item_id 为空" % i)
		var prob: float = float(entry.get("probability", 0.0))
		if prob <= 0.0 or prob > 1.0:
			errs.append("items[%d].probability 越界：%f" % [i, prob])
		var count: int = int(entry.get("count", 0))
		if count <= 0:
			errs.append("items[%d].count 非正：%d" % [i, count])
	# §5 裁决：切片不做概率掉落——偏离即告警（不阻断，交由人工裁定）
	if not is_single_full_drop():
		errs.append("非 §5 裁决形态（应为 1 条 / 概率 1.0），实际 %d 条 / 概率和 %f" % [
				items.size(), total_probability()])
	return errs
