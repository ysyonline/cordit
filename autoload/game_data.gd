extends Node
## GameData —— 运行时游戏状态单例（Autoload 注册名：GameData）
##
## 职责边界（架构文档 A3 表）：
##   只做"运行时状态的存放与读写"——字段声明 + 值的读写；
##   不做任何 IO（无 FileAccess / user://，存读档属 SaveManager）；
##   不感知 UI；不声明、不发射任何业务信号（跨系统通知一律走 EventBus）。
##
## E1-S2 空壳范围：仅字段声明，零函数、零 IO、零信号。
## 字段结构依据：战斗 GDD §5 数据结构需求 + §2 成长表（凯尔/莉娜/莫娜）。
## 类型标注策略：ADR-1 渐进类型——从第一行就写类型。

# ------------------------------------------------------------------
# 队伍（三人小队，槽位序固定：剑士→术士→辅助，战斗 GDD §2 队列同序）
# 结构占位：空壳阶段全部给"类型正确的空容器 + 中文注释说明用途"。
# EPIC-2 填充真实数据时，容器内元素结构以战斗 GDD §5 角色表为准。
# ------------------------------------------------------------------

## 队伍角色数据列表（槽位 0=凯尔·剑士 / 1=莉娜·术士 / 2=莫娜·辅助）
## 每人一个 Dictionary，字段：id, name, job, level, hp, max_hp, mp, max_mp,
##   atk, mag, def, spd, skills(习得技能 id 数组), inventory(共享背包 id 计数), equipment(weapon/armor id)
var party: Array[Dictionary] = []

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
