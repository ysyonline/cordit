extends Node
## EventBus —— 全局信号总线（Autoload 注册名：EventBus）
##
## 职责边界（架构文档 A3 表）：
##   只声明信号，不存状态、不写逻辑——零 var、零 func、零 _ready。
##   任何系统需要"通知别的系统"时，一律 emit 这里的信号；禁止旁路直连。
##
## 信号清单（E1-S2 钉死，与 tests/smoke/SMOKE-CHECKLIST.md SMK-02 逐字一致）：
##   payload / result 等参数一律为纯数据 Dictionary（架构 A5：数据进、数据出）。

## 地图 → 战斗：碰到可见敌人，载荷为 BattlePayload
## （字段：enemy_group_id / return_map / return_position / defeat_enemy_uid，见架构 A5）
signal enemy_touched(payload: Dictionary)

## 对话 → 世界：一段对话播完，参数为事件 id
signal dialogue_finished(event_id: String)

## 战斗 → 地图：战斗结算完毕，载荷为 BattleResult
## （字段：outcome / party_state / exp_gained / gold_gained / items_used，见架构 A5）
signal battle_finished(result: Dictionary)

## 剧情 → 全局：剧情阶段推进，参数为新阶段编号（int）
signal story_phase_changed(n: int)

## UI / 事件脚本 → SaveManager：请求存档（无参；存不存、存到哪由 SaveManager 决定）
signal save_requested

## 场景 → 全局：一张地图装载完成，参数为地图名（如 "town"）
signal map_ready(map: String)
