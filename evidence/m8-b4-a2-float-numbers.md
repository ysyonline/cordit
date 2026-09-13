# M8-B4-S3（卡号 A2）证据档 · 浮动数字动画化 + 自动回收（D4"屏幕越打越脏"）

> Story：M8-B4 方案 B 第 3 卡（`production/sprints/m8-b4-dispatch-sequence.md`）｜执行：程基岩｜缺陷正本：`m8-b4-battle-vertical-slice-proposal.md` §三 D4（P1）+ §四成功标准 3（零残留）
> GUT 基线：584/584（41 脚本 / 8712 断言 / W2 / O11375）= S2 收口值｜红线遵守：未 git commit / push；未触碰 `scripts/core/battle_logic.gd`、`data/`（.tres）、存档协议、Autoload。

## 1. 改动文件清单（行号为改后）

| 文件 | 位置 | 改动 |
|---|---|---|
| `scripts/battle/battle_ui.gd` | :725-728 | 生命周期常量：上飘 0.35s（与结算揭示普通行 dwell 同档节奏）+ 淡出 0.30s + 上飘幅度 18px；总生命周期 0.65s |
| 同上 | :746-754 | `spawn_damage_number` 追加 Tween：位置上飘（EASE_OUT + TRANS_QUAD 收尾）→ 延迟淡出（modulate:a→0）→ `queue_free` 自动回收。终点 y 取整值（pos.y−18）保持 640×360 观感干净（ADR-4 精神；纯 Label 位移无新纹理，无整像素硬约束） |
| `scripts/battle/battle_hit_feedback.gd` | :18-20 | 弹字生命周期常量：驻留 0.35s（同结算揭示档）+ 淡出 0.25s |
| 同上 | :86-100 | `spawn_weak_popup` 追加 Tween：interval 驻留 → 淡出 → `queue_free`。**同病同治不推倒**：放大 1.3 倍既有呈现原样保留，仅补生命周期 |
| `tests/gut/test_m8b4_a2_float_recycle.gd` | 新增 3 用例 | + `.uid`（`uid://ceuirhrdqt1i0`，经 `--headless --import` 生成） |

## 2. RED → GREEN（先证后修）

| 阶段 | 结果 | 证据 |
|---|---|---|
| RED | 3/3 新用例全红、存量 584 全绿不回归：等待 1.2s（> 生命周期上限）后浮层计数 1 / 弹字层计数 1 / 多轮模拟后 12+3 **原样残留**——"永不消失"实证；同用例前置断言（生成 1/1/12/3）全过，证明生成路径既有行为未破坏 | `evidence/m8-b4-a2-gut-red.log` |
| GREEN | 3/3 全绿（回收后 0/0/0+0），0 failing | `evidence/m8-b4-a2-gut-full.log` |

O-7 纪律：信号链驱动（damage/weakness 事件 → `_on_battle_event` → 生成 → 动画 → 回收）；断言观察量 = 两宿主层**子节点数状态**。回收依赖 Tween 帧处理，用例将 UI 入场景树（`add_child_autofree`）+ `await create_timer(1.2s)` 真实帧推进（headless 可用性由 test_o7 既有实践背书）。

## 3. 存量断言撞车预排查（派单点名项）

全量 grep 浮动数字/弹字相关查询接口的测试引用，命中 4 处、**零撞车、零断言修改**：

| 引用 | 内容 | 判定 |
|---|---|---|
| `test_e3s5.gd:71-72` | `get_float_count()==1` / `get_float_text(0)=="25"` | 生成后**同步**断言，处于 0.65s 生命周期内，节点在场 → 不受影响 |
| `test_e3s5.gd:91,118-119` | `get_weak_popup_count()` / `get_weak_popup_text` | 同上（0.60s 生命周期内） |
| `test_e3s4.gd:160-164` | `spawn_damage_number`×2 + count/text 断言 | 同上 |
| `test_e3s4.gd:43` | `has_float_layer()` | 层节点存在性，与生命周期无关 |

且上述用例的 UI 均未入场景树（Tween 不启动，节点在 autofree 前恒在场）——双重不撞车。既有断言一字未动，"加强而非削弱"论证无须触发（无任何断言被放宽或删除）。

## 4. 成功标准 3 兑现（提案 §四"零残留"）

`test_多轮战斗后两宿主层归零_零残留`：模拟 6 轮战斗（12 条 damage 数字 + 3 条 weakness 弹字，最接近真实多轮密度），断言两层**各自**归零：

- `battle_ui._float_layer`：每条数字由自身 Tween 结束回调 `queue_free`（子节点自行退场）→ `get_float_count()==0`。
- `battle_hit_feedback._popup_layer`：每条弹字同样由自身 Tween 结束回调 `queue_free` → `get_weak_popup_count()==0`（该计数即 `_popup_layer.get_child_count()`，命中弹字宿主层本体）。

两层回收机制同构、互不依赖，无中央清扫器——任何一条动画被异常中断也只影响自身，不产生连锁残留。

## 5. GUT 四项 vs 基线（APPDATA 沙盒 a2-sandbox + 跑前清残留，exit 0）

| 项 | 基线（S2 收口） | 本卡 | 差异说明 |
|---|---|---|---|
| Tests | 584/584 | **587/587** | +3（本卡用例） |
| Asserts | 8712 | **8722** | +10（本卡用例） |
| Warnings | 2 | **2** | 持平 |
| Orphans | 11375 | **11375** | **持平**——数字/弹字改由 Tween 结束自回收；本卡用例入树的 UI 在回收断言后交 autofree 整树释放。存量 Orphans 为已归因噪声（S1 口径），非本卡回归面 |

## 6. 遗留风险与未确认项

1. **实机节奏观感**：0.35+0.30s / 0.35+0.25s 为代码口径，机器断言只保"会动、会消失、零残留"；手感（幅度 18px、快慢）留用户实机抽查，不满意只调三个常量。
2. **脱离场景树的 UI**（部分既有测试的用法）中生成的数字不会被 Tween 回收（Tween 不处理），但这些 UI 本就随测试 autofree 整树释放，生产链 UI 恒在树上——无生产影响。
3. **结算驻留期间的最后一批数字**：0.65s 生命周期 < 结算驻留时长，战斗结束瞬间产生的数字在驻留期间自然消散，与结算面板无绘制冲突（浮层在结算面板之下）。
