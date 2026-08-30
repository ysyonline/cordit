extends Resource
## EnemyActionCatalog —— 敌方行为目录（全局单例 Resource，E3-S2 返工新增）
##
## 【为什么从代码迁到这里】
##   敌方行为的【倍率】是数值。按 A2「数值走 Resource、内容走 JSON」，
##   它不该躺在 `enemy_data.gd` 的类常量里——改倍率不该需要改代码。
##   GDD v1.1 裁定：目录整体迁入 `data/resources/enemy_action_catalog.tres`，
##   一个全局单例，由 `DataTables.ACTION_CATALOG` 访问。
##
## 【目录条目结构】
##   {
##     "label": String,          # 中文显示名（浮动数字 / 调试用）
##     "target": String,         # enemy_single / enemy_all / none
##     "power": float,           # 伤害倍率（走物理公式，敌人无 MAG）
##     "applies_poison": bool,   # 是否附加中毒（§3.6 中毒规则）
##     "telegraph": bool,        # 是否为 telegraph 技（§5 蓄力）
##     "selectable": bool,       # 是否进入【随机】抽取池（见下）
##     "note": String,           # 设计说明，不参与计算
##   }
##
## 【selectable 字段的必要性】
##   `charge_release`（蓄力解放）是【必发】的后续动作，不参与权重随机。
##   若没有这个标记，E3-S3 很容易把它当成普通行为塞进抽取池，
##   表现为 Boss 不蓄力也能放 2.5 倍大招——数值上完全说得通、测试也不报错，
##   属于最难查的那类"逻辑对但语义错"。用显式标记把它挡在池外。
##
## 【引用风格】preload 常量（项目规范）。

## 行为键取值（目录的完整词汇表；敌人表 ai_weights 的键必须是这里的子集）
const ACTION_KEYS := [
	"attack",           # 攻击
	"poison_strike",    # 毒击
	"sweep",            # 群击
	"heavy_strike",     # 单体重击
	"charge",           # 蓄力（telegraph）
	"charge_release",   # 蓄力解放（不参与随机，蓄力后必发）
]

## 行为目录：行为键 -> 条目（见文件头"目录条目结构"）
@export var actions: Dictionary = {}


## 取行为条目；不存在时返回空字典（调用方判空，不要用默认值蒙混过关）
func get_action(key: String) -> Dictionary:
	var entry: Variant = actions.get(key, null)
	if entry == null:
		return {}
	return entry as Dictionary


## 行为键是否存在
func has_action(key: String) -> bool:
	return actions.has(key)


## 所有行为键
func action_keys() -> Array[String]:
	var out: Array[String] = []
	for key: String in actions:
		out.append(key)
	return out


## 可进入随机抽取池的行为键（selectable = true 的条目）
func selectable_keys() -> Array[String]:
	var out: Array[String] = []
	for key: String in actions:
		if bool((actions[key] as Dictionary).get("selectable", false)):
			out.append(key)
	return out


## 值域校验：返回错误描述数组，空数组 = 合法
func validate() -> Array[String]:
	var errs: Array[String] = []
	if actions.is_empty():
		errs.append("行为目录为空")
	for key: String in actions:
		var e: Dictionary = actions[key] as Dictionary
		if String(e.get("label", "")).is_empty():
			errs.append("%s 缺中文显示名" % key)
		var target: String = String(e.get("target", ""))
		if not ["enemy_single", "enemy_all", "none"].has(target):
			errs.append("%s 的 target 非法：%s" % [key, target])
		var power: float = float(e.get("power", -1.0))
		if power < 0.0:
			errs.append("%s 的 power 为负：%f" % [key, power])
		# 交叉约束：telegraph 技本身不造成伤害（它只是"预告"），倍率必须为 0
		if bool(e.get("telegraph", false)) and not is_zero_approx(power):
			errs.append("%s 是 telegraph 技，power 应为 0，实际 %f" % [key, power])
		# 交叉约束：会造成伤害的条目必须有正倍率，否则命中后结算为 0
		if (not bool(e.get("telegraph", false))) and target != "none" and power <= 0.0:
			errs.append("%s 会造成伤害但 power 非正：%f" % [key, power])
	return errs
