# M8-B4-S4（卡号 A3）证据档 · 受击闪白分敌我（D5"每次出手屏幕都闪"）

> Story：M8-B4 方案 B 第 4 卡（`production/sprints/m8-b4-dispatch-sequence.md`）｜执行：程基岩｜缺陷正本：`m8-b4-battle-vertical-slice-proposal.md` §三 D5（P1）
> GUT 基线：587/587（42 脚本 / 8722 断言 / W2 / O11375）= S3 收口值｜红线遵守：未 git commit / push；未触碰 `scripts/core/battle_logic.gd`、`data/`（.tres）、存档协议、Autoload。

## 1. payload 归属字段确认（派单要求先读实际代码，不凭猜）

damage 事件由 `events_append_damage` 构造，`side`/`slot` 写的是**受击目标**的归属（`battle_command.gd:590-592`；掩护转移后随新目标 `tgt` 走，covered 情形 side 恒为 party）；`SIDE_PARTY = "party"`（`battle_logic.gd:114`）。**payload 已含判据字段，零 battle_command 改动**——闸门收在视图层 `_on_battle_event`，与 A1/A4 的"模型层补 emit"模式不同（本次无需）。

## 2. 改动文件清单（行号为改后）

| 文件 | 位置 | 改动 |
|---|---|---|
| `scripts/battle/battle_ui.gd` | :1059-1064 | damage 分支：`trigger_flash` 前增 `side == SIDE_PARTY` 闸门——仅我方受击闪白，打敌人不闪；浮动数字生成不受影响 |
| `scripts/battle/battle_hit_feedback.gd` | :5-9 | 头注释补语义契约（触发闸门在 battle_ui，本组件保持无脑响应，归属判断不在此） |
| `tests/gut/test_m8b4_a3_flash_side.gd` | 新增 3 用例 | + `.uid`（`uid://du0wgu2cyl6wg`，经 `--headless --import` 生成） |
| `tests/gut/test_e3s5.gd` | :70-79、:122-128 | 两处撞车断言改写（见 §3） |

## 3. 存量断言撞车改写论证（派单纪律：逐一论证"加强而非削弱"）

grep `get_flash_alpha|trigger_flash` 全测试目录，命中 2 处，**均撞车**（旧断言以 side=enemy 的 damage 期待闪白，与新语义直接冲突），逐一处理：

1. **`test_e3s5.gd:70`（synthetic）**：原"发 side=enemy damage → 期待闪白"。
   改为**双向各断言**：side=enemy → 断言 flash==0（新语义正方向）+ 浮动数字照常；side=party → 断言 flash>0（回归守卫）。
   **论证**：断言数 1→2、语义覆盖从单方向变双向正反各一，无任何原有保证被丢弃（数字生成断言原样保留）——**加强**。
2. **`test_e3s5.gd:117→122`（端到端火球）**：原"莉娜火球打甲虫 → 期待闪白"。打的是敌人，新语义下正确行为恰是不闪。
   改为断言 flash==0（端到端新语义正方向）；我方受击闪白已由用例 1 的 party 分支 + 本卡 A3 用例双向覆盖。
   **论证**：该用例的弱点亮起/记忆写入/闪白接线存在性等其余断言原样保留；闪白断言从"有闪"细化为"按归属闪"，与全部新用例形成三角覆盖——**加强**。

## 4. RED → GREEN（先证后修）

| 阶段 | 结果 | 证据 |
|---|---|---|
| RED | 2/3 新用例红：打敌人 flash=1.0（synthetic 与端到端双路径实证"现状全闪"）；敌打我方闪白回归守卫 1/3 绿（现行为确认在位） | `evidence/m8-b4-a3-gut-red.log` |
| GREEN | 3/3 全绿、e3s5 改写断言全绿，0 failing | `evidence/m8-b4-a3-gut-full.log` |

O-7 纪律：信号链驱动；断言观察量 = flash_alpha 数值/闪白态（非节点存在性）。端到端用例走真实生产链：玩家 `submit_command` 三拍推进（b5_core Boss HP 600 保证敌人存活到敌方回合——RED 首轮用 b1_moth 蛾子一拍即死提前终局，已换编组修正）→ 敌方 `enemy_action`（roll=0.0 落 attack 带、variance=1.0）→ 双向各验一次。零随机依赖。

## 5. GUT 四项 vs 基线（APPDATA 沙盒 a3-sandbox + 跑前清残留，exit 0）

| 项 | 基线（S3 收口） | 本卡 | 差异说明 |
|---|---|---|---|
| Tests | 587/587 | **590/590** | +3（本卡用例） |
| Asserts | 8722 | **8732** | +10（本卡用例 + e3s5 改写净增 1） |
| Warnings | 2 | **2** | 持平 |
| Orphans | 11375 | **11376** | +1：唯一结构性新增 = e3s5 闪白用例新增的第二次 emit（side=party）多生成 1 条浮动数字，其 Tween 因该用例 UI 脱树不处理、横跨 orphan 计数点。量级 1、计数噪声级；生产链 UI 恒在树上、Tween 正常回收（A2 机制不受影响）。非回归面 |

## 6. 与 A1/A2 交互回归（派单点名项）

- **A2 回收**：`test_RED_我方攻击命中敌人不闪白_浮动数字仍生成` 实证打敌人时数字照常生成（回收生命周期不变）；全量跑 A2 的 3 个回收用例持续绿。
- **A1 角标**：damage 事件 side=enemy 的其余消费路径（weakness/击退/角标刷新）未触碰；A1 全部用例全量跑持续绿。

## 7. 遗留风险与未确认项

1. **闪白语义收窄后的"敌方受击反馈"**：打敌人现在只剩浮动数字 + 弱点弹字；若后续卡认为敌方受击也需体感锚点，正确做法是受击方局部反馈（如 S10 死亡淡出/受击抖动），而非恢复全屏闪——属呈现层后续卡决策空间，本卡不越界。
2. **covered（掩护转移）情形**：伤害转由掩护者承受，side=party → 闪白，语义正确（我方被打到了）；无独立用例（掩护机制由 e3s3 既有用例覆盖其数值面，呈现面与普通我方受击同路径）。
3. 实机观感留用户抽查。
