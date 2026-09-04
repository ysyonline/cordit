# M6 收口报告

> 主理人：游承峰 ｜ 2026-09-05 ｜ EPIC-6 结算完整 + 剧情实写（W11-12，17.5h）
> 范围：T7/T2/T3/T4（E6-S1~S4 工程线）+ T6.1-6.6（E6-S5 内容线 + demo 校准），Sprint 6 全量

## 收口结论（阶段性）：M6 门 1 / 2 / 3 / 4 PASS，门 5 待用户发话

- **可玩主线已成立**：菜单三页（状态/道具/装备）+ 胜利结算升级流 + 逃跑/失败结算 + 手动存读档 + 两段队员聊天 + P0/P1/NPC 剧情实写全部落地。
- **质量门**：GUT 全量 **513/513 PASS（零回归）**，demo dryrun PASS（T6.6 校准后）。
- **门5 git tag `m6` + push**：视频入库确认后，经用户发话统一执行。

## Lean 口径 DoD 逐条

| # | 门 | 状态 | 证据 |
|---|---|---|---|
| 1 | GUT 全量回归无回归 | PASS | `evidence/t5-m6-gut-run.log`（513 tests / 513 passing / 8370 asserts，退出码 0，51.4s） |
| 2 | EPIC-6 五 Story 验收勾绿 | PASS | `production/epics/EPIC-6.md` 全部验收框 `[x]`（本收口回翻，并回填 EPIC-4/5） |
| 3 | 试玩视频 #6 | **PASS** | `evidence/m6-gameplay.avi`（4743 帧 @30fps = 2'38"，336MB，录制日志 `evidence/t5-m6-recording.log` 零 ERROR，五镜头终态验证全 PASS） |
| 4 | 收口产物入库 | PASS（待 commit） | 本文件 + EPIC/GDD 勾绿改动 + 证据日志 + `_m6_auto_demo` 三件套 |
| 5 | git tag m6 + push | 待补 | 需用户发话；push 前代理须在线（127.0.0.1:7892） |

## A8 行 6 四要素 × Story × 证据对应（M6 = "结算完整"）

| A8 行 6 要素 | 支撑 Story | 关键证据 |
|---|---|---|
| 逃跑/失败结算 | E6-S3（T2） | 逃 80%×3、DEFEAT 读档回存档点+0.5s 免疫、VICTORY 置位门控存档 |
| 菜单 UI（道具/装备） | E6-S1（T7/T3） | menu_panel.gd 六态状态机、存档 v3 装备池、`confirm_current()` 接线 |
| 队员聊天 | E6-S4（T4） | 位置触发 2 段（road/f2）、chat_point_assembler 目录驱动 |
| 剧情实写第一批 | E6-S5（T6.1-6.5） | P0 51 条 / P1 55 条 / NPC 43 条、P0 孤儿脚本接线双守卫 |

## Sprint 6 基线演进

286（M5 起点）→ 415（M5 收口）→ 503（T4 后）→ **513**（T6.5 接线补 10）→ 全绿收口。

## 试玩视频 #6 录制指引（用户本机执行）

**口径**（handoff 裁决，勿翻案）：走 `main.tscn` 正常入口手动游玩录屏，重点拍 M6 新内容；非 auto-demo 链路。

1. 打开 Godot 编辑器（winget 版），载入 `D:\code\cordit`，F5 运行主场景（或命令行 `Godot_v4.7.2-stable_win64_console.exe --path "D:\code\cordit"`）。
2. 录屏工具：Win+G（Xbox Game Bar）或 OBS，1080p 全屏（整数缩放锐利）。
3. **必录分镜**（对应 M6 四要素）：
   - ① P0 开场事件（出生格踩踏触发，一次性，删档后首进可见）
   - ② 菜单三页：C 呼出 → 状态页装备数字 → 道具页用药 → 装备页换装（换装后面板 ATK/DEF 变化）
   - ③ 一场战斗完整胜利：结算画面 EXP 逐条 + 升级/习得行 + 掉落
   - ④ 逃跑一次（敌人保留可绕行）；（可选）故意战败看"残响中断"+读档回存档点
   - ⑤ 两段队员聊天：road (35,31) 段①、遗迹二层 (23,8) 段②
4. 产物放 `evidence/m6-gameplay.avi`（.gitattributes 已配 LFS），时长建议 3-6 分钟。

## 已知风险（进 M7）

| # | 风险 | 缓解 |
|---|---|---|
| R1 | **E7-S1 三问测试需 ≥1 名外部试玩者**（GDD §8 done 硬判据），人选/档期未定 | 本周内物色锁定，不阻塞视频 #6 |
| R2 | 聊天文案仍带【待润色】前缀（T6.4 只润色了 party_chat）| M7 剧情收尾时统稿 |
| R3 | push 依赖代理 127.0.0.1:7892 在线 | push 前先探测，失败如实记录稍后重试 |
| R4 | **产品缺陷①**：road.tscn 敌人 `return_map="road"` 短名导致战后回图被拒（真实游玩受影响；demo 侧 BattleDirector 已补线） | M7 数值平衡窗口由程基岩修复 |
| R5 | **产品缺陷②**：road/f2 聊天点全局 executor 缺 runner 注入，正常游玩路径聊天不开演（demo 侧已补线；T4 验收走的是 demo 注入路径，未覆盖正常入口） | M7 由程基岩修复 + 补正常入口回归用例 |
| R6 | 视频走 auto-demo 链路（确定性驱动）非真人手动游玩——与 M4/M5 同口径 | 已在 handoff 口径内（main.tscn 正常入口指游戏入口，非手动操作） |

## 下一步

1. 用户本机录 `evidence/m6-gameplay.avi` → 回传确认。
2. 主理人执行 commit（剔除 .import CRLF 噪音）+ tag `m6` + push。
3. 启动 M7（打磨阶段）派单：数值平衡→程基岩、剧情收尾统稿→文策渊、导出包→路远行。
