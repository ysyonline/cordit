extends Node
## SaveManager —— 存读档单例（Autoload 注册名：SaveManager）
##
## 职责边界（架构文档 A3 表）：
##   定义"什么状态可存"的快照协议（schema）；读写单存档槽。
##   不决定何时存——存档时机由事件脚本（save_point 动作）/ UI 通过
##   EventBus.save_requested 触发。
##
## ⚠ E1-S2 空壳：本文件只有 schema 常量声明，零读写、零 IO、零函数。
##   实际读写（FileAccess + JSON）属 EPIC-4 E4-S1 职责（SMK-12 验收点：
##   运行本项目不得在 user:// 产生任何文件）。
##
## 快照协议（ADR-3：JSON 手写字段序列化，不用 Resource 序列化）：
##   只存"游戏状态的值"，绝不存场景/节点引用；version 字段负责未来迁移。

## 存档槽路径（单存档槽；user:// 映射到用户数据目录）
const SAVE_PATH: String = "user://save.json"

## 存档格式版本（读档时据此走迁移函数；当前唯一版本）
const SCHEMA_VERSION: int = 1

## 可存状态快照的 schema（与 ADR-3 字段表一一对应，SMK-12 验收依据）：
##   version                  → int，格式版本
##   map                      → String，当前场景路径/地图标识
##   position                 → Array[float, float]，玩家回置点（x, y）
##   party                    → Array，三人队伍快照（等级/HP/MP/装备/道具等）
##   story_phase              → int，剧情阶段
##   flags                    → Array，全局剧情标志（运行时在 GameData.flags 为 Dictionary，序列化时转数组）
##   chests_opened            → Array，已开宝箱集合（GameData.chests_opened）
##   discovered_weakness_set  → Array，已记忆弱点集合（GameData.discovered_weakness_set）
##   cleared_enemy_set        → Array，已击破敌人集合（GameData.cleared_enemy_set）
## 值为各字段的"类型示例占位"（空容器/零值），仅描述结构，不含数据。
const SCHEMA: Dictionary = {
	"version": 1,
	"map": "",
	"position": [0.0, 0.0],
	"party": [],
	"story_phase": 0,
	"flags": [],
	"chests_opened": [],
	"discovered_weakness_set": [],
	"cleared_enemy_set": [],
}
