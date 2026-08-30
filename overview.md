# M1 收口报告

> 主理人：游承峰 ｜ 2026-08-29 深夜 ｜ commit f9840ed ｜ tag m1

## 收口结论：M1 门 PASS — Phase 4 关门，Phase 5 启动

## DoD 五条逐条

| # | 条目 | 状态 | 证据 |
|---|---|---|---|
| 1 | EPIC-1 六 Story 验收逐条勾绿 | PASS | `production/epics/EPIC-1.md` 全部 `[x]` |
| 2 | SMK-01~12 全量 PASS + evidence 留档 | PASS | `evidence/m1-smk-01-04.log`（4/4）+ `m1-smk-08-12.log`（5/5）+ 静态核验 3/3 = 12/12 |
| 3 | M1 试玩视频 #1 | PASS | `evidence/m1-gameplay.avi`（33s@15fps，覆盖移动/碰撞/对话/进屋） |
| 4 | git tag m1 | PASS | tag `m1` @ f9840ed |
| 5 | 资产首批 6 件入库 | PASS | commit b085e1a（3×CC0 + 3×CC-BY） |

## 执行摘要

### SMK 全量重跑（12/12 PASS）
- **动态**：Godot 4.7.2 headless 跑 `headless_smk.tscn`（SMK-01~04：四单例/六信号/connect/emit 参数 4/4）+ `headless_smk_e1s3.tscn`（SMK-08~12：合法切换/三非法拒绝/零副作用/UILayer 存活/user:// 零落盘 5/5）
- **静态**：源码核验 SMK-05（EventBus 零 var/func）+ SMK-06（GameData 8 字段带类型）+ SMK-07（GameData 无 IO）+ SMK-12（SaveManager 仅 schema 常量）

### S5 人眼代验（PASS）
- 主理人后台拉起 Godot 窗口模式跑 `visual_e1s5.gd`，产出 9 张截图（y-sort front/behind × 3 物件 + 室内A/B + 井近距）
- 静态核验 verify_town.py 108/108（y_sort_enabled/z_index/y_sort_origin 配置正确）
- 室内四角全黑 + 中心 60% 非黑（黑幕框 + 房间正常）
- 环线代验收 76.1s（4/4 PASS）
- 报告：`evidence/e1s5-m1-visual-accept.md`

### 试玩视频（33s@15fps）
- Godot Movie Maker `--write-movie` + 自动试播脚本（set_input_override 移动 + inject_interact_press 对话推进 + teleport 进屋）
- 覆盖门标准四要素：移动/碰撞 → 对话 → 进屋 → 出屋 → 探索

### 工作区清理
- 删除诊断脚本：repro×3 / probe_npc / visual_e1s5 / auto_demo + _analyze.py / _decode_town.py / 9 .import
- 保留 M1 证据：SMK log + S5 截图 PNG + 试玩视频 + 代验报告
- production/ 7 件临时工具留待 W3 裁决

## Godot exe 路径

WinGet 安装（find/Glob 搜不到，WinGet\Packages reparse point 导致递归跳过）：
`C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`

## 下一步

Sprint 2（EPIC-2 遇敌能打，W3-4，9h）：
1. 装 GUT 9.3.x + 迁移 SMK-01~06 为自动化用例
2. production/ 临时工具裁决
3. EPIC-2 Story 开工
