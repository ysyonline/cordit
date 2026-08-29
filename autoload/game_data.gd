extends Node
## GameData —— 运行时游戏状态单例（Autoload 注册名：GameData）
##
## 职责边界（架构文档 A3 表）：
##   只做"运行时状态的存放与读写"——字段声明 + 值的读写；
##   不做任何磁盘读写（存读档属 SaveManager 职责，此处连注释都不留关键词，保 SMK-07 静态搜索零命中）；
##   不感知 UI；不声明、不发射任何业务信号（跨系统通知一律走 EventBus）。
##
## E2-S1 起填充队伍真实数据（CharacterRecord 数值结构 + GDD §3.6 初始数值）。
## 字段结构依据：战斗 GDD §5 数据结构需求 + §2 成长表（凯尔/莉娜/莫娜）。
## 类型标注策略：ADR-1 渐进类型——从第一行就写类型。

## 队伍角色记录类型（ADR-2：结构化数值用 Resource/自定义 class）。
## 用 preload 常量而非全局 class_name：headless 跑测通道即时可用，
## 类型检查能力等价（决策理由见 character_record.gd 头注释）。
const CharacterRecord := preload("res://scripts/core/character_record.gd")

# ------------------------------------------------------------------
# 队伍（三人小队，槽位序固定：剑士→术士→辅助，战斗 GDD §2 队列同序）
# E2-S1 起填充真实数据：数值口径 = 战斗 GDD §3.6 属性量级表 Lv1 列。
# 槽位序即队伍顺序，全项目（行动队列/调试面板/战斗 UI）都按此序遍历。
# 角色记录结构见 scripts/core/character_record.gd（ADR-2 数值口径：
# 结构化数值用 Resource/自定义 class，而非裸 Dictionary——带字段名编译期
# 检查，拼错字段名直接报错而非静默存错值）。
# ------------------------------------------------------------------

## 队伍角色数据列表（槽位 0=凯尔·剑士 / 1=莉娜·术士 / 2=莫娜·辅助）
## 元素为 CharacterRecord（自定义 Resource，见类注释）；静态字段声明保留，
## SMK-06 的字段清单/类型标注断言以此为锚。
var party: Array[CharacterRecord] = [
	# 凯尔·剑士（物理输出）：Lv1 HP120/MP10（战斗 GDD §3.6）
	CharacterRecord.new("kyle", "凯尔", "swordsman", 1, 120, 120, 10, 10),
	# 莉娜·术士（法术输出）：Lv1 HP80/MP30（战斗 GDD §3.6）
	CharacterRecord.new("lina", "莉娜", "sorcerer", 1, 80, 80, 30, 30),
	# 莫娜·辅助（治疗）：Lv1 HP95/MP24（战斗 GDD §3.6）
	CharacterRecord.new("mona", "莫娜", "support", 1, 95, 95, 24, 24),
]

## 队伍共享背包：道具 id -> 数量（战斗 GDD I2：道具为队伍共享，非按角色）
var inventory: Dictionary = {}

## 队伍金钱（切片内恒为 0，GDD 已裁决切片无商店；保留字段避免未来加商店时改协议——架构 A5 同款理由）
var gold: int = 0

# ------------------------------------------------------------------
# 剧情状态
# ------------------------------------------------------------------

## 当前剧情阶段（Cut 清单外唯一的状态机制，只需一个 int）
var story_phase: int = 0

## 全局剧情标志集合（事件脚本 set_flag / check_flag 的存取处，键为字符串）
var flags: Dictionary = {}

## 已开启宝箱集合（存宝箱 event_id，Array 去重约定）
var chests_opened: Array = []

## 已击破的可见敌人集合（存 defeat_enemy_uid，战斗胜利后由地图侧回写）
var cleared_enemy_set: Array = []

## 已记忆的敌人弱点集合（跨战斗弱点记忆，战斗 GDD §3.3）
var discovered_weakness_set: Array = []
