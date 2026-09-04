# T6.5 验收记录 —— P0 开场孤儿脚本接线（2026-09-04）

负责人：程基岩（engineering-lead） · Godot 4.7.2 + GDScript

## 一、问题与方案一句话

`story_p0_intro` 对话（51 条目，文策正稿已就位）全项目零引用、玩家不可见。
方案：**数据侧事件 + 出生锚点薄壳 + 生产语境守卫接线**——新事件
`story_p0_intro`（data/json/events/story_intro.json）conditions
`story_phase==0 + not_flag story_p0_seen`，actions `[dialogue story_p0_intro →
set_flag story_p0_seen → save_point]`；town.tscn 加 `P0_Anchor` 锚点（与玩家
出生位同格 (192,640)）；town_map.gd 新增 `_assemble_opening_story()` 按既有
A7 薄壳纪律程序化装配 trigger_event_shell（踩踏面 mask=16）。

## 二、诊断结论（任务书三问）

1. **触发方式**：现有条件体系（story_phase / flag / not_flag，schema 白名单
   "不扩展"）足够——`not_flag` 一次性旗在 demo_actions.json（ev_demo_loot）
   已有先例，宝箱/聊天同构。**不需要 has_save() 条件类型扩展**；"无存档"
   判定放在装配守卫（见下），不动 GDD §3.2 条件白名单。
2. **save_point 时机**：`save_point` 动作 executor 已实装（L162，
   EventBus.save_requested）；`story_boss_pre`（story_anchor.json）已有
   `[dialogue → … → save_point]` 先例。注意：executor 是同步流，dialogue
   动作开演后动作序列立即续走（不等 END）——save_point 在对话开演时置
   `save_requested_pending` 意图位，**实际落盘在下一次 map_ready（首次出镇）**。
   这是冻结门控语义下的既有行为（boss 事件同款），非本任务改动；玩家在出镇
   前退出则无档（重开重演 P0），与"无存档=首次启动"口径自洽。
3. **判定**：走「直接做」路线。未改存档语义 / 门控机制 / Autoload 字段 /
   schema（仍 v3 / 11 字段）；GameData 零新增字段，无需补测试快照对。

## 三、关键设计：双守卫装配（为何不能无条件接线）

"首次启动"与既有测试环境在**数据面不可区分**（m6t41 读档用例经 Router 回
town：phase=0、flags 空、玩家先落出生位；GUT 直挂 town 同理）——无条件接线
会在 503 基线内自动开演 P0 并污染意图位/对话门闸断言（纪律：净增不改旧）。
故 `_assemble_opening_story()` 双守卫：

- 守卫①（生产启动语境）：`get_tree().current_scene.name == "Main"`。
  生产 F5 运行 main.tscn 时 Main 恒为 current_scene；GUT 用例树 / 冒烟
  包装器（headless_e1s4、smk_e1s3 手动重挂 Main 但包装器才是 current_scene）/
  演示替身均不满足 → 不接线。
- 守卫②（GDD"无存档"原文）：`SaveManager.has_save() == false` 才装配。

事件 conditions 仍独立兜底（phase 旗双保险）：demo 置 phase=2 → 即使被接线
（demo 根节点名恰好也是 "Main"），conditions 拦截，日志留痕
`[EventExecutor] story_p0_intro 条件不满足，跳过`。

## 四、改动清单

| 类别 | 文件 | 说明 |
|---|---|---|
| 数据 | `data/json/events/story_intro.json` | 新增：事件 story_p0_intro（文案零触碰，dialogue 仅引用对话 id） |
| 场景 | `scenes/maps/town.tscn` | +3 行：YSorted/P0_Anchor Marker2D @ (192,640)（出生格） |
| 代码 | `scripts/maps/town_map.gd` | +76 行：ShellScript preload、3 常量、`_assemble_opening_story()`（双守卫 + 薄壳装配）+ _ready 一行调用 |
| 测试 | `tests/gut/test_t65.gd` + `.uid` | 新增 10 用例（A 数据面 ×2 / B 条件门控 ×3 / C 执行链 ×1 / D 装配守卫与端到端 ×4） |

**未触碰**：story_p0/p1 及全部 dlg_*、flavor_*、party_chat_* 对话 JSON
（工作区内同名的 M 均为文策/T6.4 润色成员在制品，与本次零交集）；
SaveManager / SceneRouter / EventBus / event_executor 均未改动。

## 五、验证结果

### 1. 全量 GUT（净增不改旧）

```
Totals
------
Scripts              31
Tests               513
Passing Tests       513
Failing Tests         0
Asserts           8370
Orphans             634
```

基线 503/503 全数保持（513 = 503 + 本任务新增 10），零失败。
Orphans 10016 = 基线原值（m6-t43 / e6s3 / e6s2 历史全量日志逐一同值——
battle_ui 夹具既有累计泄漏，非本任务引入）。
证据：`evidence/t65-gut-full.log`（GBK 编码，锚点 `^Totals`）。

新增 10 用例：
- A1 事件装载零失败且入表；A2 事件结构对表（conditions 三键 + actions 三拍）
- B1 phase0 无旗放行；B2 旗置位拦截；B3 phase≠0 拦截
- C1 执行链三动作依序生效（mock runner：dialogue 开演 + set_flag 落 flags +
  save_point 置 save_requested_pending）
- D1 非生产语境直挂树不接线；D2 生产语境无存档接线（壳属性对表：事件 id /
  mask=16 / 出生同位）；D3 有存档不接线；D4 出生重叠端到端（真实 body_entered
  → 自动开演 P0 → set_flag → 意图位）

### 2. demo dryrun（头less 直跑）——终态指纹与基线对照

命令（与历史 m6-t43 dryrun 同款 unthrottled 形态）：
`Godot_v4.7.2-stable_win64_console.exe --headless --path D:\code\cordit --fixed-fps 30 --quit-after 5400 res://evidence/_m5_auto_demo.tscn`

- **带本任务改动**：`存档指纹：map=ruins_f3 position=[320.0, 40.0] story_phase=2`。
  P0 触发器被 conditions 正确拦截（`story_p0_intro 条件不满足，跳过`），
  意图位零污染。
- **基线对照（临时还原本任务 3 个文件后复跑）**：`story_phase=2 ≠ 3`，
  **与带改动运行逐字节同型失败**。

结论：当前工作区（含文策/T6.4 润色在制品对话 JSON——dlg_npc_*、story_p0/p1
正稿替换）使 demo 固定节拍按法失配（第 1 幕即现 `等待收束超时：npc_innkeeper`，
历史 PASS 的 m6-t43 dryrun 日志无此告警），第 8 幕战后续行 finale 未开演 →
phase 停在 2。**该失败与本任务无关（基线复现，根因在润色 WIP 数据侧）**；
本任务对 demo 的全部可观测影响 = 一条 conditions 拦截日志。指纹中
map=ruins_f3 / (320,40) 两项均未变。待润色批次收口后建议由文策侧协作者
或主理人复跑确认 demo 恢复 PASS（属 T6.4 收口义务，非 T6.5 清单内事项）。
证据：`evidence/t65-demo-dryrun-with-t65.log`（带改动）、
`evidence/t65-demo-dryrun-baseline-control.log`（基线对照）。

### 3. 环境备注（前人 handoff 勘误）

handoff 所记 Godot 路径 `D:\software\Godot\...` 已失效；当前实际位置
`C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`（winget 安装，桌面快捷方式同源）。GBK 日志 + Grep/Read 直读纪律照旧。

## 六、遗留与建议（清单外不做）

1. demo dryrun FAIL 根因在文策润色 WIP（见上），T6.4 收口时须复验。
2. save_point 语义口径（意图位，落盘在下次 map_ready）建议写入文策交接：
   玩家出镇前退出 = 无档重演 P0，属设计内行为。
3. 若未来要求"P0 END 后立即落盘"，需事件流异步化（E5-S5 遗留的 wait 占位
   同源问题），属架构级变更，届时另开拍板。
