# M7 R-3 录制生产缺口档案（待办，非阻塞 M7 门）

> 来源：M7 放行条件 R-3 试玩视频自动录制（tools/dev/_m7_r3_autodrive.gd + _m7_r3_battle_director.gd）
> 证据正本：evidence/m7-recording.log（GUI Movie Maker 正式录制，3004 帧 @30fps，全断言 PASS）
> 记录人：engineering-lead · 2026-09 录制收口时点
> 状态：三条均不影响 R-3 录制交付（已用 dev 侧驱动器字幕/弹字桥补偿可见性），供 M7 门评审与下 Sprint 排期。

## a) 蓄力 charge 事件无生产 UI 反应（蓄力横幅未实现）

- **现象**：B5 Boss 战中核心 `charge`（蓄力预告）发生时，战斗画面无任何生产侧视觉反馈——无横幅、无弹字、无状态卡角标。R-3 要求"蓄力预告可见"，当前仅由录制驱动器的字幕轨在事件瞬间标注（`_m7_r3_battle_director.gd _on_event`）补偿。
- **根因**：`scripts/battle/battle_ui.gd:936-956` `_on_battle_event` 只处理 `damage`/`weakness` 两种事件类型（弹字 + 受击闪白 + 弱点弹字）；`charge` 事件由 `scripts/battle/battle_command.gd:487` 产生，但只进 `enemy_action` 的**返回数组**——而生产链 `battle_scene.gd:138` 丢弃该返回数组，事件从不抵达信号流/UI。
- **证据行为**：m7-recording.log「R3 敌拍已播种 seed=32」段（B5 第 3 拍 charge 命中）前后无任何 UI 相关日志；驱动器断言「A7 核心蓄力预告在场」靠快照差分转录（非信号流）证实事件已发生。
- **关联事实修正**：`battle_command.gd` 头注声称「UI 订阅 event_emitted 渲染逐条」，与事实不符——全文件仅 `events_append_damage` 内联 emit（damage/weakness/knockback 三类），`_ev` 系事件（heal/defend/poison/charge/skill/item/ai/cover）只走返回值协议且 `_emit_all` 为空桩。**建议**：要么完成「返回数组 → event_emitted 统一 emit」重构（一并修复 heal/poison 弹字在生产不可见），要么修正头注并明确事件契约。E 系列候选。

## b) 战前对话被战斗转场立即强制收束（E5-S5 异步化关联）

- **现象**：B5 棺前事件 `story_boss_pre` 的 2 条战前对话（story_p3_boss_front）在探索画面**从未可见**——开演瞬间即被转场读档安全机制强制收束。玩家实况同样看不到（非录制特有）。
- **根因**：`scripts/events/event_executor.gd:90-94` `execute_event` 为**同步顺序执行**：`dialogue` 动作只发射不等待（L141-142），`battle` 动作（L152-153）立即跟进转场；`dialogue_runner.gd` 的读档安全边缘 5 在战斗装载时强制收束在演对话。
- **证据行为**：m7-recording.log L124-131：「[DialogueRunner] 开演：story_p3_boss_front（2 条目）」→ 同秒内「[DialogueRunner] 强制收束（读档安全，边缘 5）：弃 story_p3_boss_front → IDLE」→「对话经 0 按收束」。
- **关联**：事件流异步化属 E5-S5 既定范围（executor L173 `wait` 动作占位注释自认）。**需产品侧确认**：玩家实况看不到 story_p3_boss_front 文本是否符合叙事预期；若不符合，短平快方案是给 dialogue 动作加"等待收束"阻塞语义（或在 battle 动作前置 `await dialogue_finished`），不必等 E5-S5 全量异步化。

## c) 战斗内道具消耗不做跨战斗持久化（M6 修复②同族）

- **现象**：战斗中使用的道具（本录制：B5 R1 双 ether_s）在结算后背包数量**原样保留**——消耗未扣减。仅掉落合并生效。
- **根因**：`battle_result_handler.gd` 的 VICTORY 结算只把掉落写入 `GameData.inventory`，不回写战斗内的消耗差分（战斗内 `cmd._inventory` 是 `battle_scene.gd` 装配时的独立副本）。与 M6 修复②（level 写回）同族：都是"战斗态 → GameData"回写链不完整的切片口径。
- **证据行为**：m7-recording.log L193：B5 结算后背包 `{ ether_s: 2, potion_l: 1 }`——R1 双 ether 消费后仍为 2，仅掉落 potion_l 新增。
- **处置**：已按裁定新立 Story（见 `production/sprints/story-battle-item-persistence.md`），本录制不受影响（ether_s×2 预置 + 剧本不依赖战斗内扣减）。注意：若该 Story 修复落地，R-3 复录时 preplant 的 ether_s×2 口径仍成立（消耗即耗尽，不改变保底剧本）。
