# M3 收口报告

> 主理人：游承峰 ｜ 2026-08-30 ｜ EPIC-3 战斗是"游戏"（W5-6，30h 卡满）
> 范围：E3-S1 数值 Resource 表 → E3-S6 边缘情况 8 条实测（六 Story 全完成）

## 收口结论（阶段性）：M3 门 1 / 2 / 4 PASS，门 3 / 5 待补

- **可玩主线已成立**：B1（道路飞蛾）+ B2（雷壳甲虫）两场战斗从遇敌→指令→结算→回图全程打通，三系克制、四指令、战斗 UI 八要素、转场与打击反馈全部就位。
- **质量门**：GUT 全量 **187/187 PASS（零回归）**，六 Story 验收标准全部勾绿，证据入库。
- **两道门待补**（环境/授权依赖，非工程阻塞）：
  - 门3 试玩视频 #3：需在**本机 OpenGL 环境**录制（沙箱 headless 为 RendererDummy，无法渲染），方案同 M2（auto-demo + Godot Movie Maker）。
  - 门5 git tag `m3`：需用户明确批准后再统一 commit + tag（Sprint 3 全程未提交，遵循"无指令不 commit"纪律）。

## Lean 口径 DoD 逐条

| # | 门 | 状态 | 证据 |
|---|---|---|---|
| 1 | GUT 全量回归无回归 | PASS | `evidence/s3-gut-e3s6.log`（187 tests / 187 passing / 5994 asserts，退出码 0） |
| 2 | EPIC-3 六 Story 验收勾绿 | PASS | `production/epics/EPIC-3.md` 全部验收框 `[x]` |
| 3 | 试玩视频 #3 | 待补 | 需本机录制（见下方"试玩视频 #3 技术方案"） |
| 4 | 未跟踪文件入库 | PASS | `evidence/s3-gut-e3s6.log` + 本文件随 M3 收口 commit 入库 |
| 5 | git tag m3 | 待补 | 需用户批准 |

## Story 交付清单（GUT 按文件）

| Story | 内容 | GUT 文件 | 用例 |
|---|---|---|---|
| E3-S1 | 五张数值 Resource 表 + Resource 类 | test_e3s1.gd | 33/33 |
| E3-S2 | battle_logic.gd 纯函数核心 | test_e3s2.gd | 56/56 |
| E3-S3 | 四指令 + 三结局结算 | test_e3s3.gd | 12/12 |
| E3-S4 | 战斗 UI 全套（§4 八要素） | test_e3s4.gd | 10/10 |
| E3-S5 | 转场与打击反馈（背景/闪白/弱点弹字） | test_e3s5.gd | 5/5 |
| E3-S6 | 边缘情况 8 条全量实测 | test_e3s6.gd | 8/8 |
| 基线回归 | E2-S1~4 + sanity + SMK | 6 文件 | 63/63 |
| **合计** | | | **187/187** |

> 注：Sprint 3 全部代码改动**尚未 commit**（纪律：无用户明确指令不提交）。commit hash 待 M3 收口统一提交后回填。

## 四要素 × Story × 证据对应（M3 = "战斗是游戏"）

| A8 行 3 四要素 | 支撑 Story | GUT 文件 | 用例 |
|---|---|---|---|
| 速度队列 + 三系克制 | E3-S2 | test_e3s2.gd | 56/56 |
| 技能（9 卡 + 习得等级） | E3-S1 + E3-S2 | test_e3s1/s2 | 89 用例合计 |
| 四指令 + 三结局 | E3-S3 | test_e3s3.gd | 12/12 |
| 战斗 UI 八要素 | E3-S4 | test_e3s4.gd | 10/10 |
| 转场 + 打击反馈 | E3-S5 | test_e3s5.gd | 5/5 |
| 边缘健壮性 | E3-S6 | test_e3s6.gd | 8/8 |

## 收口期两处 defect 修复（E3-S6 测试暴露）

| # | 类型 | 位置 | 现象 | 修复 |
|---|---|---|---|---|
| D1 | 代码潜伏 bug | `scripts/battle/battle_command.gd` `set_inventory()` | 注入空背包 `[]` 时 `inv.duplicate(true)` 返回未类型化 `Array`，赋值给 `Array[Dictionary]` 成员报类型错，致 `test_边缘5_道具耗尽置灰` 失败 | 改为逐元素重建类型化数组：`_inventory = []; for it in inv: _inventory.append(it)`，对所有输入（空/非空、类型化/未类型化）均安全 |
| D2 | 测试用例参数位写错 | `tests/gut/test_e3s3.gd` `test_逃跑成功_整队脱离` | 把 `0.0` 传到了 `submit_command` 第 3 位 `variance`，`roll` 仍默认 `-1.0` 走 `randf()`，逃跑结果随机（约 20% 失败） | 改为第 4 位显式传 `roll=0.0`：`submit_command(_actor(bc), {"type":"escape"}, 1.0, 0.0)`，使断言意图（确定性逃脱成功）真正成立 |

> D1 是真实代码 bug（被新测试合法暴露，非测试误报），已修且零回归；D2 是测试自身参数位错误，escape 逻辑本身正确。

## GDD §3.6 边缘条数勘误

- `EPIC-3.md` 原写"S6 边缘情况 7 条"，但战斗 GDD §3.6 实际为 **8 条**（边缘 1~8，原漏计边缘 8"中毒行动前扣血致死跳过本回合"）。
- E3-S6 按 GDD 实测 **8 条全过**（test_e3s6.gd 8/8）。已在 EPIC-3.md 备注订正，避免后续误判。

## 试玩视频 #3 技术方案（待本机录制）

沿用 M2 已验证链路：

- Godot 内置 Movie Maker `--write-movie` + 临时 auto-demo 脚本（state machine 驱动，自动走完 B1→B2 两场战斗：遇敌→攻击/技能/防御/逃跑→克制弹字→胜负→回图）。
- 复用既有基础设施（battle.tscn / BattleUI / BattleCommand），**零修改业务代码**。
- auto-demo 脚本录制后删除（与 M1/M2 收口纪律一致）。
- 渲染：OpenGL Compatibility，640×360 @ 30 FPS。
- 录制命令（本机，需显示环境）：
  ```
  Godot_v4.7.2-stable_win64_console.exe --path "D:\code\cordit" --write-movie "D:\code\cordit\evidence\m3-gameplay.avi"
  ```
- 沙箱限制：当前 headless 为 RendererDummy，**无法渲染视频**，故门3 必须在用户本机完成。auto-demo 场景与录制脚本可由工程侧备好，用户一键录制。

## 已知风险（进 Sprint 4 / M4）

| # | 风险 | 缓解 |
|---|---|---|
| R1 | EPIC-4 遗迹施工需克隆 EPIC-1 的 town 生成工具，但该工具 `tools/` 4 脚本含 7 处硬编码 `D:\code\cordit\...` 且指向的 `.rgba` 已迁走、路径失效 | 开工前先修工具路径（Sprint 3 过程资产补链已立案，待执行） |
| R2 | 跨 Epic 前置约束：战斗间 HP/MP 不回满（GDD §6 I6）；EPIC-4 开工前须锁定"地图有无免费回复点"，否则 §7 B3 资源压力教学意图需重裁 | 由用户拍板后写入 EPIC-4 设计 |
| R3 | 失败读档仍占位（真读档 E4-S7） | 不阻塞 M3；M4 接管 |

## 下一步：Sprint 4（EPIC-4 遗迹可探索 + 存档落地，19h）

- 先修 `tools/` 4 脚本硬编码路径（R1），再克隆 town 生成工具做 EPIC-4 三层遗迹。
- 存档落地（ADR-3 版本化 JSON 手写存档）接 E4-S7 真读档，替换 M3 占位提示。
- 待用户批准 M3 收口 commit + tag `m3` 后，从 `m3` 切出 Sprint 4 分支。
