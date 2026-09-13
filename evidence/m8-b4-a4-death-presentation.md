# M8-B4-S2（卡号 A4）证据档 · 死亡呈现（我方卡灰化 + 敌方条隐藏 + death 事件接线）

> Story：M8-B4 方案 B 第 2 卡（`production/sprints/m8-b4-dispatch-sequence.md`）｜执行：程基岩｜缺陷正本：`m8-b4-battle-vertical-slice-proposal.md` §三 D6（P1"死人还站着"）
> GUT 基线：579/579（40 脚本 / 8697 断言 / W2 / O11375）= S1 收口值｜红线遵守：未 git commit / push；未触碰 `scripts/core/battle_logic.gd`、`data/`（.tres）、存档协议、Autoload。

## 1. 根因确认（承 A1 勘误）

death 事件呈现缺失是**两层叠加**：

1. **信号层**：death 类型事件两处产生点（`submit_command` 我方中毒 tick 致死、`enemy_action` 敌方中毒 tick 致死，原 `:284`/`:463`）只 append 进返回数组不过 `event_emitted`——A1 勘误同根因（`_emit_all` 空钩子）。伤害致死路径虽随 damage 事件携带 `death=true` 抵达，但：
2. **视图层**：`_on_battle_event` 不消费任何死亡语义；`refresh_status_bar` 不判存活、`refresh_enemy_bars` 不跳过死者。

## 2. 改动文件清单（行号为改后）

| 文件 | 位置 | 改动 |
|---|---|---|
| `scripts/battle/battle_command.gd` | :284-289、:468-473 | 两处中毒致死产生点：death 事件在产生处 `event_emitted.emit`（A1 同款最小侵入，返回数组契约不变；`replace_all` 一次覆盖两处同形代码，未顺手重构 `_emit_all`） |
| `scripts/battle/battle_ui.gd` | :43-45 | 新增 `C_DOWN` 阵亡灰常量——与 `scripts/ui/menu_panel.gd` `C_GRAY`(8E7F98) **同值**，探索侧菜单"hp<=0 置灰"语义同源，战斗/探索死亡观感一致 |
| 同上 | :432-437 | `refresh_status_bar`：hp=0 → 卡整体 modulate 灰化 + 名称"（倒下）"后缀；存活恢复 WHITE |
| 同上 | :519-522 | `refresh_enemy_bars`：hp=0 → 敌条 root 隐藏 |
| 同上 | :1003-1014 | 查询接口 `is_party_down(idx)`（灰化态断言）/ `is_enemy_bar_hidden(idx)`（条隐藏断言） |
| `tests/gut/test_m8b4_a4_death_presentation.gd` | 新增 5 用例 | + `.uid`（`uid://bknxq5gyuglhs`，经 `--headless --import` 生成） |

## 3. 呈现形态裁决（派单授权自定，理由留档）

- **我方卡 = 灰化 + "（倒下）"**：与 `menu_panel.gd` 既有"死亡=置灰"同值同语义，玩家跨场景零学习成本；modulate 整卡灰化连 HP/MP 条与中毒角标一并降调，一眼可辨。
- **敌方条 = 隐藏**（采纳派单建议）：理由①B 段 S10 死亡淡出动画直接吃本卡语义（本卡定"死亡该是什么样"，S10 只加动画不换语义）；②"隐藏"是比"死亡标识"更强的终局语义——切片内无复活，死人从战场消失零误读；③实现代价两形态相同（一行 visible），按授权选语义更强者。

## 4. RED → GREEN（先证后修）

| 阶段 | 结果 | 证据 |
|---|---|---|
| RED | 5/5 新用例全红，存量 579 全绿不回归：①中毒致死 death 事件不过信号（我方/敌方两条路径各证一次）②`Nonexistent function 'is_party_down'` ③`Nonexistent function 'is_enemy_bar_hidden'`（UI 无死亡态） | `evidence/m8-b4-a4-gut-red.log` |
| GREEN | 5/5 全绿，0 failing | `evidence/m8-b4-a4-gut-full.log` |

O-7 纪律：信号链驱动（enemy_action / submit_command / events_append_damage 生产入口 → event_emitted → `_on_battle_event`）；断言观察量 = 灰化态 / 条隐藏 / 信号抵达的**状态**；中毒致死用确定性前提（poison_turns=1 + hp=1，5% maxHP 中毒伤害必致死）零随机依赖。

## 5. GUT 四项 vs 基线（APPDATA 沙盒 a4-sandbox + 跑前清残留，exit 0）

| 项 | 基线（S1 收口） | 本卡 | 差异说明 |
|---|---|---|---|
| Tests | 579/579 | **584/584** | +5（本卡用例） |
| Asserts | 8697 | **8712** | +15（本卡用例） |
| Warnings | 2 | **2** | 持平 |
| Orphans | 11375 | **11375** | **持平**——本卡零新增节点（灰化是 modulate、隐藏是 visible，均改属性不加节点），且死亡隐藏反而让泄漏统计中既有 UI 的子树状态无增减。按派单口径注明：Orphans 存量本身为既有测试不 autofree 的已归因噪声（S1 证据），非本卡回归面 |

## 6. A1 交互回归（派单点名项）

`test_A1回归_蓄力者死亡横幅角标仍清除且敌条隐藏`（本卡用例 5）实证：蓄力中的 Boss 被击杀 → A1 横幅清除 ✅ + A1 角标清除 ✅ + 本卡敌条隐藏 ✅ 三态同时正确。A1 兜底机制（hp>0 守卫 + `_any_alive_charging`）与本卡改动正交不冲突；A1 全部 4 用例在全量跑中持续绿。

## 7. 遗留风险与未确认项

1. **敌条隐藏与"受击显示 3s 淡出"机制的叠加**：死亡隐藏走 `root.visible`，与既有 alpha 淡出（`_on_enemy_fade`）正交；死者条不会再被 `show_enemy_hp` 复活（visible=false 优先）。未发现冲突路径，GUT 全绿佐证。
2. **敌方全灭瞬间的表现**：单敌编组死亡 → 条隐藏 + 结算面板弹出（`_check_wipe` → battle_over），死亡呈现与结算面板衔接自然；已由本卡用例覆盖。
3. 实机观感（灰度深浅 8E7F98 是否够明显、"（倒下）"字号）留用户抽查，机器断言只保行为正确性。
