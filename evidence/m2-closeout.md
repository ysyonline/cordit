# M2 收口报告

> 主理人：游承峰 ｜ 2026-08-30 ｜ tag m2 ｜ Lean 口径
> 范围：EPIC-2 遇敌能打（W3-4，9h）四 Story E2-S1~S4

## 收口结论：M2 门 PASS — Phase 5 Sprint 2 关门

EPIC-2 本质达成——"战斗是假的，数据流必须是真的"：数据能从地图流进战斗再流回地图，最难的建筑学部分走完。

## Lean 口径 DoD 逐条

| # | 门 | 状态 | 证据 |
|---|---|---|---|
| 1 | GUT 全量回归无回归 | PASS | `evidence/m2-gut-full-rerun.log`（62 tests / 62 passing / All tests passed，退出码 0） |
| 2 | A8 行 2 四要素勾绿 | PASS | `production/epics/EPIC-2.md` 全 Story 验收框 `[x]` + 收口门进度标记 |
| 3 | 试玩视频 #2 | PASS | `evidence/m2-gameplay.avi`（8.73s @ 30fps，640×360，四要素覆盖） |
| 4 | 未跟踪文件入库 | PASS | 收口 commit 含全部 M2 evidence + overview.md + e2s3-evidence-note |
| 5 | git tag m2 | PASS | tag `m2` |

## 四要素 × Story × 证据对应

| A8 行 2 四要素 | 支撑 Story | commit | GUT | 录制 log 行 |
|---|---|---|---|---|
| 可见敌人 | E2-S2 | 25a178c | 37/37 | L7（VisibleEnemy 就绪） |
| 切入战斗（占位 UI） | E2-S3 | 588c176 | 49/49 | L14-18（Router 受理 battle.tscn + BattleScene 3 人队伍） |
| 攻击/防御（占位胜负按钮） | E2-S3+E2-S4 | 588c176+3cf66bc | 62/62 | L19-23（胜利按钮 → battle_finished VICTORY） |
| 胜负回到地图 | E2-S4 | 3cf66bc | 62/62 | L24+L30（cleared_enemy_set 自删 + 回置 344,200 + 免疫 0.5s） |

## Story 交付清单

| Story | commit | 内容 | GUT |
|---|---|---|---|
| E2-S1 | fa2ac75 | GameData 3 角色 CharacterRecord + M 键调试面板 | 23/23 |
| E2-S2 | 25a178c | 可见敌人节点 + 巡逻/接触遇敌 + payload 四字段 | 37/37 |
| E2-S3 | 588c176 | 占位战斗场景 + Router 载荷校验（非法 payload 拒绝） | 49/49/293 断言 |
| E2-S4 | 3cf66bc | BattleResultHandler 战后写回闭环（删敌人+回置+免疫） | 62/62（+13 用例） |

基建：1e0295f（GUT 9.7.1 实装兼容 4.7.2 + SMK-01~06 迁移 + 工具裁决 + README 修订）

## 试玩视频 #2 技术方案

- Godot 内置 Movie Maker `--write-movie` + 临时 auto-demo 脚本（state machine 驱动）
- 复用既有基础设施（map_whitebox / temp_player_mount / visible_enemy / battle.tscn），零修改 E2 业务代码
- auto-demo 脚本录制后已删（与 M1 收口纪律一致）
- 渲染：OpenGL Compatibility, Intel UHD，262 帧 5 秒录完（160% 实时速度）
- 录制 log：`evidence/m2-recording.log`（38 行）+ headless 预验 `evidence/m2-headless-test.log`

## 已知风险与缓解（进 Sprint 3）

| # | 风险 | 缓解 |
|---|---|---|
| R1 | EPIC-3 30h 是最重 Epic，含 battle_logic 纯函数 + 四指令 + UI 全套 | 工时含 3h buffer；超支砍序已在 EPIC-3.md 定（S5 打磨 → S4 预估伤害 → S3 逃跑完善；队列/克制/四指令/UI 骨架不可砍） |
| R2 | E2 战斗是占位（胜负按钮模拟结局），真正战斗逻辑在 EPIC-3 | E3-S2 battle_logic.gd 纯函数核心先行，5h 建纯函数地基 |
| R3 | 失败读档逻辑仍占位（真读档 E4-S7） | EPIC-3 E3-S3 允许失败占位提示，不阻塞 M3 |

## 下一步：Sprint 3（EPIC-3 战斗是"游戏"，W5-6，30h 卡满）

6 Story：E3-S1 数值 Resource 表(4h) → E3-S2 battle_logic 纯函数核心(5h) → E3-S3 四指令+三结局结算(6h) → E3-S4 战斗 UI 全套(6h) → E3-S5 转场与打击反馈(3h) → E3-S6 边缘情况 7 条实测(3h)。

开工前主理人出 Sprint 3 冲刺计划草案，用户拍板后 spawn 程基岩逐 Story 推进。
