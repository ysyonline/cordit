extends Resource
## GrowthCurve —— 队伍升级经验曲线（E3-S1 补充表，非 GDD §5 五表之一）
##
## 【为什么需要这张表】
##   GDD §5 角色表列了 per_level 成长值组，但【没有】"升到下一级需要多少
##   经验"——经验曲线既不在角色表字段里，也不在敌人表字段里（敌人表只有
##   exp）。§6 I4 把升级交给"角色成长模块"，但那个模块要有曲线才能跑。
##   本表即为该曲线的落点：1 行全局资源，全队共用（经验为队伍共享口径，
##   与 GameData.gold / inventory 同款"队伍级"状态）。
##
## 【数值口径（工程初值，待文策渊裁定）】
##   按 §7 五场战斗的"预期等级"反推：B1 后 Lv2、B3 后 Lv3、B4 后 Lv4、
##   B5 后 Lv5，且 §3.6 说"切片内预计升 4 级"（Lv1 → Lv5）。
##   阈值（累计经验）与五场累计的对照：
##     Lv2=15   B1 飞蛾×1  = 15  → 累计 15  → Lv2  ✓（B2 预期 Lv1-2）
##     Lv3=60   B2 甲虫×2  = 36  → 累计 51  → Lv2  ✓（B3 预期 Lv2）
##     Lv4=150  B3 混编    = 82  → 累计 133 → Lv3  ✓（B4 预期 Lv3）
##     Lv5=300  B4 守卫    = 140 → 累计 273 → Lv4  ✓（B5 预期 Lv4）
##              B5 核心    = 260 → 累计 533 → Lv5  ✓
##   经验值本身落在敌人表 exp 字段（每敌一个值，击破逐个结算）。
##
## 【定位】纯数据 schema + 纯函数派生，零场景依赖（A1 铁律 3）。
## 【引用风格】preload 常量（项目规范）。

## 切片等级上限（§3.6"Lv1 → Lv5"）
const MAX_LEVEL := 5

## 升到下一级所需的【累计】经验阈值（下标 0 = 升到 Lv2 的门槛）。
## 长度 = MAX_LEVEL - 1 = 4；用累计值而非"本级所需"，是为了让读档/回看
## 时"当前等级"成为经验的纯函数，避免额外存一个等级字段与之不同步。
@export var exp_thresholds: Array[int] = [15, 60, 150, 300]


## 累计经验 -> 当前等级（纯函数，钳到 [1, MAX_LEVEL]）。
## 判据：等级 = 1 + 已跨过的阈值个数。
func level_for_exp(total_exp: int) -> int:
	var lv: int = 1
	for threshold: int in exp_thresholds:
		if total_exp >= threshold:
			lv += 1
	return clampi(lv, 1, MAX_LEVEL)


## 当前等级下，升到下一级还差多少经验（已满级返回 0）
func exp_to_next(total_exp: int) -> int:
	var lv: int = level_for_exp(total_exp)
	if lv >= MAX_LEVEL:
		return 0
	var threshold: int = exp_thresholds[lv - 1]
	return maxi(0, threshold - total_exp)


## 值域校验：返回错误描述数组，空数组 = 合法
func validate() -> Array[String]:
	var errs: Array[String] = []
	if exp_thresholds.size() != MAX_LEVEL - 1:
		errs.append("exp_thresholds 长度应为 %d，实际 %d" % [
				MAX_LEVEL - 1, exp_thresholds.size()])
	for i: int in exp_thresholds.size():
		if exp_thresholds[i] <= 0:
			errs.append("exp_thresholds[%d] 非正：%d" % [i, exp_thresholds[i]])
		# 累计阈值必须严格递增，否则 level_for_exp 的计数口径失效
		if i > 0 and exp_thresholds[i] <= exp_thresholds[i - 1]:
			errs.append("exp_thresholds 非严格递增：下标 %d" % i)
	return errs
