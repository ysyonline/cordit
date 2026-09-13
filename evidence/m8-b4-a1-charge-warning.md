# M8-B4-S1（卡号 A1）证据档 · 敌方蓄力警示（横幅 + 持续角标）

> Story：M8-B4 方案 B 第 1 卡（`production/sprints/m8-b4-dispatch-sequence.md`）｜执行：程基岩｜缺陷正本：`m8-b4-battle-vertical-slice-proposal.md` §三 D1（P0 公平性）
> GUT 基线：575/575（39 脚本 / 8684 断言 / W2 / O10016）@ `dca9a82`｜红线遵守：未 git commit / push；未触碰 `scripts/core/battle_logic.gd`、`data/`（.tres）、存档协议、Autoload。

## 0. 根因勘误（对派单前提的重要修正）

派单写"charge 与 charge_release 事件在生产链已发出"。**实读代码后部分成立、部分不成立**：

- **charge_release**：✅ 抵达 UI——但形态不是 `charge_release` 类型事件，而是 `damage` 事件携带 `release: true` 元数据（`battle_command.gd` `_enemy_release` → `events_append_damage`，emit 于 :599）。UI 侧按此形态消费，另兼容声明表预留的 `charge_release` 类型防将来改口径。
- **charge**：❌ **从未越过信号边界**——`_ev("charge", ...)` 只 append 进 `enemy_action` 返回数组，而 `event_emitted.emit` 全文件仅 `events_append_damage` 内 3 处（damage/weakness/knockback，`:599/:608/:615`）；`_emit_all` 是空钩子（头注释自认"事件已在产生处逐一 emit"，对 `_ev` 系事件不成立），且生产场景（`battle_scene.gd:138`）弃用 `enemy_action` 返回值。**纯视图层修复无法响应一个到不了的信号**——故本卡含对 `battle_command.gd` 的两处最小侵入（见 §1，均不在禁触清单内）。

## 1. 改动文件清单

| 文件 | 位置 | 改动 |
|---|---|---|
| `scripts/battle/battle_command.gd` | :141-148 | 新增 `is_charging(slot) -> bool` 只读查询（供 UI 角标/横幅跟随模型刷新，避免 UI 自持游戏状态漂移；零状态迁移） |
| 同上 | :504-509 | `enemy_action` charge 分支：charge 事件在产生处 `event_emitted.emit`（根因修复，一行信号接线；返回数组契约不变） |
| `scripts/battle/battle_ui.gd` | :72-76 | 横幅布局常量（300×28 居中，y=208，避开敌方条 y46 与指令菜单 y248） |
| 同上 | :107, :117-121 | `_enemy_bars` 字典增 `charge_badge` 键；新增 `_charge_banner`/`_charge_label` 成员 |
| 同上 | :229-243 | `_build` 构建横幅：NineSlicePanel 与既有 HUD 面板同款风格 + 高亮黄 C_HI 文字，O-9 `MOUSE_FILTER_IGNORE`，默认隐藏 |
| 同上 | :488-497 | `refresh_enemy_bars` 构建敌方条时增"蓄"角标（与"弱"图标同排左侧，9px C_HI） |
| 同上 | :505-532 | 刷新循环：角标可见性 = `hp>0 且 cmd.is_charging(slot)`（天然覆盖释放清除 + 死亡清除）；横幅模型同步兜底（无存活蓄力者强制熄灭）+ `_any_alive_charging()` |
| 同上 | :973-990 | 测试查询接口：`is_charge_banner_visible` / `get_charge_banner_text` / `is_enemy_charging`（断言状态而非节点存在性） |
| 同上 | :1019-1022, :1028-1036 | `_on_battle_event` 新增：`charge` → 横幅点亮带敌名；`damage+release:true` 与 `charge_release` → 横幅熄灭 |
| `tests/gut/test_m8b4_a1_charge_warning.gd` | 新增 4 用例 | + `.uid`（`uid://dt6e0nnu5rnoa`，经 `--headless --import` 生成） |

## 2. RED → GREEN（先证后修，日志见 evidence/）

| 阶段 | 结果 | 证据 |
|---|---|---|
| RED | 3 failing：①`test_RED_charge事件应经event_emitted抵达UI侧`（charge 事件只进返回值不过信号——根因实证）②③ `Nonexistent function 'is_charge_banner_visible'`（UI 零响应） | `evidence/m8-b4-a1-gut-red.log` |
| GREEN | 4/4 新用例全绿，全量 0 failing | `evidence/m8-b4-a1-gut-full.log` |

O-7 纪律：全部用例从真实信号链驱动（`enemy_action`（生产唯一入口，`battle_scene.gd:138` 同款）→ `event_emitted` → `_on_battle_event`）；断言观察量 = 横幅可见性 / 角标点亮与清除的**状态**；随机全注入（`roll_action=0.6` 落 charge 权重带，前置防呆用例自证；`variance=1.0`），无 flaky 面。

## 3. GUT 四项 vs 基线（跑前清沙盒残留 + APPDATA 沙盒重定向，命令同 tests/README §2.4）

| 项 | 基线 | 本卡 | 差异说明 |
|---|---|---|---|
| Tests | 575/575 | **579/579** | +4（本卡用例） |
| Asserts | 8684 | **8697** | +13（本卡用例） |
| Warnings | 2 | **2** | 持平 |
| Orphans | 10016 | **11375** | +1359，**已归因**：存量为既有测试不 autofree UI 树的泄漏噪声（RED 日志可见 e3s4 等每例 `+613/633`）；本卡给每个 UI 增约 14 个节点（横幅 NineSlicePanel 9+ 子块 + label + 角标），约百个既有泄漏 UI 各多带这部分。**隔离复跑实证**：本卡 4 用例单独跑 Orphans = 0（`evidence/m8-b4-a1-gut-isolated-skill-named.log` / `-charge-named.log`）——非新泄漏源，属既有噪声的记账增量 |

## 4. 呈现说明（横幅 + 角标，用户拍板形态两者都要）

- **横幅**：屏幕中带居中（300×28，y=208），NineSlicePanel 与行动预告条/结算面板同款边框风格；点亮时显示"`遗迹核心` 正在蓄力！"（敌名取自事件 `name` 字段），12px 高亮黄（C_HI，当前行动者描边同色）。点亮时机 = charge 事件抵达；清除时机 = ①释放兑现（damage+release:true）②蓄力者死亡（hp>0 模型同步兜底）双保险，防任何路径残留误导。
- **角标**：蓄力中敌人 HP 条名称行"弱"图标左侧显示 9px 高亮黄"蓄"单字，**持续可见**（敌方 HP 条 3s 淡出机制不影响它）；释放后随 `is_charging=false` 熄灭，蓄力者死亡后随 hp>0 守卫熄灭。
- 两者均为纯视图层：横幅可配置鼠标 IGNORE（O-9），不持有战斗状态（角标/横幅可见性全部由模型 `is_charging` + 事件推导）。

## 5. 遗留风险与未确认项

1. **战斗结束残留**（边缘）：逃跑结局下横幅若在点亮中会随场景释放消失，无需处理；已覆盖 VICTORY/DEFEAT 必经的 death 事件路径。
2. **多敌蓄力**（B5 单 Boss 不触发）：横幅为单实例，多敌同帧蓄力时后者文本覆盖前者——M8-B4 各编组无此形态，留待后续卡（S 系呈现层）如需再扩。
3. **"ai" 等其余 `_ev` 系事件仍不过信号**（poison/death 单独事件等）——与本卡无关、未被任何 UI 消费需求引用，D6（死亡呈现）等后续卡会再撞上同一根因，建议后续卡沿用本卡的"产生处 emit"最小修法或统一修 `_emit_all`（需另立 ADR 决策，本卡不越界）。
4. 未实测人工项：实机 B5 观感（横幅位置/字号是否舒适）留用户抽查，机器断言只保行为正确性。
