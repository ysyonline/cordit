# M8-B4-S5（卡号 A5）证据档 · 逃跑反馈（D7）+ 结算面板溢出防御（D10）——A 段收尾

> Story：M8-B4 方案 B 第 5 卡（`production/sprints/m8-b4-dispatch-sequence.md`）｜执行：程基岩｜缺陷正本：`m8-b4-battle-vertical-slice-proposal.md` §三 D7（P1）+ D10（P2，防御性修复）
> GUT 基线：590/590（43 脚本 / 8732 断言 / W2 / O11376）= S4 收口值｜红线遵守：未 git commit / push；未触碰 `scripts/core/battle_logic.gd`、`data/`（.tres）、存档协议、Autoload、**全部 .tscn**。

## 1. 信号边界核查（派单要求项，A1 勘误方法复用）

`_do_escape` 的 escape_fail 为 `_ev` 系事件 → **只进返回数组、不过 `event_emitted`**（A1 勘误同根因），UI 无从响应——RED 实证在案。escape_success 事件同为 `_ev` 系但 UI 无需消费：成功路径经 `battle_over` → `show_result` 呈现结算文本（本卡回归守卫用例确认语义不破坏）。本卡只补 escape_fail 一处 emit，不做多余接线。

## 2. 改动文件清单（行号为改后）

| 文件 | 位置 | 改动 |
|---|---|---|
| `scripts/battle/battle_command.gd` | :446-451 | `_do_escape` 失败分支：escape_fail 事件产生处 `event_emitted.emit`（A1 同款最小侵入，返回数组契约 `[fv]` 不变；**#15 `forced_escape_roll` 检定接缝原样保留零触碰**） |
| `scripts/battle/battle_ui.gd` | :120 | 新增 `_result_scroll` 成员 |
| 同上 | :282-297 | D10：结算文本区改 ScrollContainer（代码内构建，零 .tscn）——横向禁用防抖动；容器保留 STOP（非全屏 328×168 居中且为交互面板"滚轮读长结算"，与 O-9 不冲突，注释在案） |
| 同上 | :769-787 | D7：`_spawn_escape_hint()`——"逃跑失败！"居中弹字（C_WEAK 橙=警示族），与 A2 浮动数字同款上飘+淡出+自动回收（0.35+0.30s），自动消退不残留 |
| 同上 | :1067-1091 | 查询接口：`has_escape_hint()`（提示在场/消退状态）、`get_result_content_height()`（内容高）、`get_result_scroll_max()`（滚动域上限）、`get_result_scroll_page()`（可视区高） |
| 同上 | :1149-1152 | `_on_battle_event` 新增 `escape_fail` 消费 → 提示 |
| `tests/gut/test_m8b4_a5_escape_settlement.gd` | 新增 5 用例 | + `.uid`（`uid://barvvmgkpb32y`，经 `--headless --import` 生成） |

## 3. RED → GREEN（先证后修）

| 阶段 | 结果 | 证据 |
|---|---|---|
| RED | 4/5 新用例红：①escape_fail 不过信号（D7 根因实证）②③④`Nonexistent function 'has_escape_hint' / 'get_result_content_height' / 'get_result_scroll_max'`（UI 无提示、无滚动域）；逃跑成功结算文本守卫 1/5 绿。附注：首轮 RED 跑出 GUT API 误用（assert_ge/assert_le 为 GdUnit4 名，GUT 9.7.1 无此二断言，脚本解析失败被忽略、sanity 哨兵连带红），已改用 assert_gt/assert_true 显式比较——记录在案防再犯 | `evidence/m8-b4-a5-gut-red.log` |
| GREEN | 5/5 全绿，0 failing | `evidence/m8-b4-a5-gut-full.log` |

O-7 纪律：信号链驱动（`submit_command(escape)`（生产提交入口）→ `event_emitted` → `_on_battle_event`）；断言观察量 = 提示在场/消退状态、滚动域覆盖内容高的**状态**。逃跑确定性走 #15 接缝（roll=1.0 必败 / 0.0 必成）；D10 用 B3 规模长结算协议数据（表头 2 + party 3 + 8 exp + 升级 + 习得 + 2 掉落 = 17 行）实证溢出（内容高 > 文本区高）+ 全部行纳入滚动域；两帧等待覆盖 ScrollContainer 延迟排序。

## 4. 交付形态说明

- **D7 提示形态**：浮层居中弹字"逃跑失败！"（橙字警示族，与弱点/克制同色系）+ 上飘淡出自动回收——与既有浮层元素风格同源，满足"自动消退不残留"；逃跑成功不另加提示（结算面板既有文本即反馈，无重复）。
- **D10 方案选型**：ScrollContainer（否决动态扩高——640×360 定版下面板尺寸是构图约束；否决字号收缩——B3 级 17 行缩到可读下限以下）。短结算零变化（内容 < 168px 无滚动条），长结算滚轮可达。**揭示逐行弹出时的自动跟随滚动未做**：ScrollContainer 延迟排序与逐行文本追加存在一帧时序竞态，确定性做法需帧依赖协程，属观感增强项非本卡验收面——留待 B 段/实机反馈再议（风险栏注明）。

## 5. GUT 四项 vs 基线（APPDATA 沙盒 a5-sandbox + 跑前清残留，exit 0）

| 项 | 基线（S4 收口） | 本卡 | 差异说明 |
|---|---|---|---|
| Tests | 590/590 | **595/595** | +5（本卡用例） |
| Asserts | 8732 | **8746** | +14（本卡用例） |
| Warnings | 2 | **2** | 持平 |
| Orphans | 11376 | **11472** | +96，**已归因**：既有泄漏噪声 UI（不 autofree，S1 口径存量约 32 棵）每棵新增 ScrollContainer + 纵/横滚动条 3 节点 ≈ 96——与 A1 横幅 +1359（约 97 棵 × 14 节点）同模式记账增量，非新泄漏源（提示弹字/滚动域内容均自回收） |

## 6. 回归确认（派单点名项）

- **#15 `forced_escape_roll` 接缝**：零触碰（接缝消费逻辑原样）；o7 的 `test_逃跑经信号驱动转发` / `test_逃跑_roll注入1_0_必败不结束战斗` 全量跑持续绿。
- **逃跑成功语义**：`test_逃跑成功结算文本回归_敌人仍在原地徘徊` 实证 `battle_ui.gd:794` 既有文本原样（提案 §七锚点）。
- **A1/A2/A3/A4 交互**：escape_fail 提示走独立 `_float_layer` 弹字，与 A2 数字/A2 弱点弹字/A3 闪白闸门/A4 死亡呈现正交；四卡既有用例全量跑持续绿。

## 7. 遗留风险与未确认项

1. **揭示自动跟随滚动未做**（见 §4 选型说明）：揭示期间若行数超屏，新行弹在可视区外需滚轮——观感增强项，留 B 段或实机反馈。
2. **结算期间滚轮与 interact 跳过的输入并存**：滚轮归 ScrollContainer（STOP 局部），interact 键走 `_unhandled_input` 不受影响（全量 e6s2/e6s3 揭示用例绿佐证）；鼠标点击结算区域会被 ScrollContainer 消费——结算面板下方无可交互 HUD（指令菜单在左、状态栏在底部），无遮蔽风险，已核对布局坐标。
3. 实机观感（提示位置 y=120、橙字、滚动条样式）留用户抽查。
