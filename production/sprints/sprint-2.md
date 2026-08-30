# Sprint 2 冲刺计划 · EPIC-2 遇敌能打（W3-4，9h）

> **本文件是 2026-08-30 的事后追溯补档。**
> Sprint 2 执行当时（2026-08-30）**未留下计划文档，靠口头推进**。补档目的：补全 M2 的证据链与决策记录，供 M3 复盘与后续 Sprint 参照。
> 内容与执行结果一致，**不代表执行当刻存在此计划**——凡与实况冲突处，以 `evidence/m2-closeout.md` 与 git 提交为准。
>
> 汇编：游承峰（team-lead）｜补档日期：2026-08-30
> 输入正本：`production/epics/EPIC-2.md`（Story 四要素 + 砍序）、`evidence/m2-closeout.md`（收口报告）、git 提交序列

---

## 1. Sprint 目标（Sprint 结束 = 里程碑门 M2 通过）

**一句话**：敌人看得见、碰得上、打得起来、打完回得去地图——**战斗是假的，数据流必须是真的**。

| 门标准（A8 行 2） | 覆盖 Story | 试玩视频 |
|---|---|---|
| 可见敌人 + 切入战斗（占位 UI）+ 攻击/防御 + 胜负回到地图 | E2-S1 ~ E2-S4 全部 | #2（`evidence/m2-gameplay.avi`，8.73s@30fps，640×360） |

**DoD（Lean 口径）**：
1. EPIC-2 四条 Story 验收标准逐条勾绿
2. GUT 全量回归无回归，`evidence/` 留档
3. 试玩视频 #2 录制，覆盖门标准四要素
4. 未跟踪文件入库
5. git tag `m2`

**结果：五条全绿，M2 门 PASS（commit 1b61358，tag m2）。**

## 2. 实际排期与交付

### 基建先行（0 号位，Story 之前完成）

| commit | 内容 |
|---|---|
| `1e0295f` | GUT 9.7.1 实装（兼容 Godot 4.7.2）+ SMK-01~06 迁移为自动化用例 + production/ 临时工具裁决 + tests/README.md 修订 |

> 口径勘误：原计划装 GUT 9.3.x，实际装 **9.7.1**（v9.5.0 起要求 Godot 4.5+，9.7.0 起兼容 4.7）。

### Story 序列

| 顺 | Story | 工时 | commit | 交付内容 | GUT |
|---|---|---|---|---|---|
| 1 | E2-S1 队伍数据 + 调试面板 | 2h | `fa2ac75` | GameData 3 角色 CharacterRecord + M 键调试面板 | 23/23 |
| 2 | E2-S2 可见敌人 + 遇敌 | 2.5h | `25a178c` | 可见敌人节点 + 巡逻/接触遇敌 + payload 四字段 | 37/37 |
| 3 | E2-S3 占位战斗场景 | 2.5h | `588c176` | battle.tscn 占位 + Router 载荷校验（非法 payload 拒绝） | 49/49（293 断言） |
| 4 | E2-S4 战后写回闭环 | 2h | `3cf66bc` | BattleResultHandler：删敌人 + 回置坐标 + 0.5s 遇敌免疫 | 62/62（+13 用例） |

### A8 行 2 四要素 × Story 对应

| 四要素 | 支撑 Story | commit | 录制 log 行 |
|---|---|---|---|
| 可见敌人 | E2-S2 | `25a178c` | L7（VisibleEnemy 就绪） |
| 切入战斗（占位 UI） | E2-S3 | `588c176` | L14-18（Router 受理 battle.tscn + BattleScene 3 人队伍） |
| 攻击/防御（占位胜负按钮） | E2-S3 + S4 | `588c176` + `3cf66bc` | L19-23（胜利按钮 → battle_finished VICTORY） |
| 胜负回到地图 | E2-S4 | `3cf66bc` | L24 + L30（cleared_enemy_set 自删 + 回置 344,200 + 免疫 0.5s） |

## 3. 试玩视频 #2 技术方案（可复用）

- Godot 内置 Movie Maker `--write-movie` + 临时 auto-demo 脚本（state machine 驱动）
- 复用既有基础设施（map_whitebox / temp_player_mount / visible_enemy / battle.tscn），**零修改 E2 业务代码**
- auto-demo 脚本录制后即删（与 M1 收口纪律一致）
- 渲染：OpenGL Compatibility，Intel UHD，262 帧 / 5 秒录完（160% 实时速度）
- 日志：`evidence/m2-recording.log`（38 行）+ headless 预验 `evidence/m2-headless-test.log`

## 4. 复盘

### 做得对（沿用）

1. **基建先行**：GUT 与 SMK 迁移放在 Story 之前，使后续每条 Story 都有自动化门可守，M2 收口时 62 用例可一次全量重跑。
2. **占位不假装**：明确承认战斗是占位（胜负按钮），把力气全花在数据流闭环上——EPIC-2 的本质达成。
3. **录制零侵入**：试玩视频用临时 auto-demo 脚本驱动，不污染业务代码，录完即删。
4. **每 Story 一 commit**：证据链清晰，回退粒度细。

### 待改进（Sprint 3 已补）

1. **无计划文档** → 本文件补档；Sprint 3 起计划前置（`production/sprints/sprint-3.md` 已在开工前备好并经用户拍板）。
2. **QA 职能未独立** → 现有用例均为工程侧自测，Sprint 3 补建独立 QA 策略（`production/qa/`）。
3. **音频线空白** → Sprint 3 补建音频方向（`design/audio/`），供 E3-S5 打击反馈使用。
4. **入口文档滞后** → `overview.md` 在 M2 收口后仍停留在 M1，2026-08-30 已改为项目状态总览，M1 收口报告归档至 `evidence/m1-closeout.md`。

## 5. 带出的风险（进 Sprint 3）

| # | 风险 | 缓解 |
|---|---|---|
| R1 | EPIC-3 30h 是最重 Epic，纯函数 + 四指令 + UI 三面夹击 | 工时含 3h buffer；砍序已在 EPIC-3.md 定 |
| R2 | E2 战斗是占位，真战斗逻辑全在 EPIC-3 | E3-S2 battle_logic.gd 纯函数核心先行 |
| R3 | 失败读档仍占位（真读档 E4-S7） | E3-S3 允许失败占位提示，不阻塞 M3 |
