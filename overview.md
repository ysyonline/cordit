# 《轨迹残响》项目状态总览

> 主理人：游承峰（编排）｜更新：2026-08-30｜当前阶段：**Phase 5 · 制作（Sprint 循环）**
> 本文件是项目入口索引，只反映"现在在哪"。历史收口报告见 `evidence/m1-closeout.md`、`evidence/m2-closeout.md`。

## 1. 当前位置

| 项 | 值 |
|---|---|
| 阶段 | Phase 5 · 制作，Sprint 3 收口 |
| 当前 Sprint | Sprint 3 · EPIC-3「战斗是游戏」（W5-6，30h 卡满） |
| 在飞 Story | E3-S1 ~ E3-S6 全部完成，M3 收口中（门3 试玩视频 + 门5 tag 待用户批准） |
| 测试基线 | GUT 9.7.1，187/187 全绿（`evidence/s3-gut-e3s6.log`） |
| 下一道门 | M4：遗迹可探索 + 存档落地（EPIC-4，19h） |
| 冲刺计划 | `production/sprints/sprint-3.md` |

## 2. 里程碑进展（A8 表七行）

| 门 | Epic | 状态 | commit / tag |
|---|---|---|---|
| M1 能走路的世界 | EPIC-1（15.5h） | PASS | `f9840ed` / tag m1 |
| M2 遇敌能打 | EPIC-2（9h） | PASS | `1b61358` / tag m2 |
| M3 战斗是游戏 | EPIC-3（30h） | PASS（收口待门3/门5） | E3-S1~S6 全完成，187/187 |
| M4 遗迹可探索 + 存档落地 | EPIC-4（19h） | 待启动 | — |
| M5 ~ M7 | EPIC-5 ~ 7 | 待启动 | — |

## 3. 冻结决策（勿翻案）

- 引擎 Godot 4.7.2 + GDScript 渐进类型；四 Autoload：GameData / EventBus / SceneRouter / SaveManager
- ADR-4：640×360 视口 + Nearest + 整数缩放；数值走 Resource、内容走 JSON；core 层纯函数禁 `get_node`
- 美术走开源素材（OGA 16x16 系列 + DawnLike + Kenney UI），**零采购**；许可账本 3×CC0 + 3×CC-BY + 1×OFL，**禁 CC-BY-SA / GPL-only**
- 失败处理 = 读档回进图存档点；敌人头像 = 战斗精灵 ×2 整数放大；9-slice 窗体框全自制五色板两套
- 详见 `docs/architecture/godot4-architecture-adr.md` 与各 GDD

## 4. 文档索引

| 类别 | 路径 |
|---|---|
| 概念与 GDD | `design/concept/`、`design/gdd/`（战斗 / 对话 / 探索 / 小镇施工单） |
| 架构与 ADR | `docs/architecture/godot4-architecture-adr.md` |
| 美术方向与许可 | `design/art-bible/`、`assets/CREDITS.md`、`assets/LICENSE-ASSETS.md` |
| UI 规格 | `design/ui/ui-layout-specs.md` |
| 音频方向 | `design/audio/`（Sprint 3 补建中） |
| Epic 与冲刺 | `production/epics/EPIC-1~7.md`、`production/sprints/` |
| 测试与证据 | `tests/`、`evidence/` |

## 5. 已知风险（带入 Sprint 3）

| # | 风险 | 缓解 |
|---|---|---|
| R1 | EPIC-3 30h 是最重 Epic，纯函数 + 四指令 + UI 三面夹击，超支风险高 | 工时含 3h buffer；砍序已在 EPIC-3.md 定（S5 打磨 → S4 预估伤害 → S3 逃跑完善；队列/克制/四指令/UI 骨架不可砍） |
| R2 | E2 战斗是占位（胜负按钮模拟结局），真战斗逻辑全在 EPIC-3 | E3-S2 battle_logic.gd 纯函数核心先行，5h 建地基 |
| R3 | 失败读档仍占位（真读档 E4-S7） | E3-S3 允许失败占位提示，不阻塞 M3 |
| R4 | QA 职能此前未独立上线，测试为工程侧自测 | Sprint 3 补建独立 QA 策略（`production/qa/`） |
| R5 | 音频线此前完全空白 | Sprint 3 补建音频方向（`design/audio/`），重点供 E3-S5 使用 |

## 6. 纪律备忘

- **无用户明确指令不 git commit**（提交由主理人统一安排）
- 每 Story 开工前 GUT 全量重跑，日志留 `evidence/`
- 资产**先登记后复制**，入库前核对许可
- 中文输出（代码注释与文档一律中文）

## 7. 环境备忘

Godot 可执行文件（WinGet 安装，`find`/`Glob` 搜不到，直接用全路径）：
`C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`

GUT 跑测命令见 `tests/README.md` §2.4（Git Bash 需加 `MSYS2_ARG_CONV_EXCL="*"` 前缀）。

> 注意：仓库 `.gitignore` 第 23 行 `*.log` 全局忽略日志，但第 26 行 `!evidence/*.log` 已白名单放行——`evidence/` 下的证据日志正常 `git add` 即可，无需 `-f`。
