# 《轨迹残响》项目状态总览

> 主理人：游承峰（编排）｜更新：2026-08-31｜当前阶段：**Phase 5 · 制作（Sprint 循环）**
> 本文件是项目入口索引，只反映"现在在哪"。历史收口报告见 `evidence/m1-closeout.md`、`evidence/m2-closeout.md`。

## 1. 当前位置

| 项 | 值 |
|---|---|
| 阶段 | Phase 5 · 制作，Sprint 3 已收口（tag m3，五门全绿） |
| 当前 Sprint | Sprint 4 · EPIC-4「遗迹可探索 + 存档落地」进行中（S0~S5 + S8 ✅，剩 S6~S7 ≈3.5h） |
| 待办尾巴 | 无——S5（`5c7ac2b`）、S8（`c1c4562`）均已收口（2026-08-31 凌晨，用户拍板） |
| 测试基线 | GUT 9.7.1，**266/266 全绿**（`evidence/e4s8-gut-s8.log`；258 基线另证 `evidence/e4s5-gut-s5.log`） |
| 下一道门 | M4：三层遗迹可探索 + 存档落地——当前 **E4-S6 传送网络+进图自动存档（2.5h）**，随后 S7（1h）即达门 |
| 冲刺计划 | `production/sprints/sprint-4.md`（已生效，5 项拍板全落） |

## 2. 里程碑进展（A8 表七行）

| 门 | Epic | 状态 | commit / tag |
|---|---|---|---|
| M1 能走路的世界 | EPIC-1（15.5h） | PASS | `f9840ed` / tag m1 |
| M2 遇敌能打 | EPIC-2（9h） | PASS | `1b61358` / tag m2 |
| M3 战斗是游戏 | EPIC-3（30h） | PASS（五门全绿） | commit 72e1354 / tag m3，187/187 |
| M4 遗迹可探索 + 存档落地 | EPIC-4（19h） | 进行中：S0~S5 + S8 ✅，剩 S6~S7（3.5h） | db8a6be→021ffb7→5cbc36b→5c7ac2b(S5)→c1c4562(S8) |
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

## 5. 已知风险（带入 Sprint 4 尾段）

| # | 风险 | 缓解 |
|---|---|---|
| R3 | 失败读档仍占位（真读档 E4-S7，1h） | S6 完成后立即接 S7，M4 前清账 |
| R6 | S5 宝箱为硬编码触发器形态（拍板项④授权） | E5-S2 JSON 加载器就绪后回迁；点位数据已在 point_catalog.gd + data/json/events/ 双写同构，回迁可平移 |
| R7 | sfx 为 E6 预留钩子（开箱/调查暂无音效） | E6 音频系统落地时接入，接口已留 |
| R8 | controller/runner 生产装配仅 town，road~f3 实地交互待验 | E4-S6 传送网络铺满五图；点位可达性建议 S6 后由 QA 走图实测 |

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
