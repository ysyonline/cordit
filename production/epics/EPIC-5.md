# EPIC-5 · 剧情串起来（W9-10，17h）

> 里程碑门 M5：4 张图 + 剧情阶段机制 + NPC 阶段对话 + Boss（A8 行 5）
> 正本：对话事件 GDD（`design/gdd/dialogue-event-gdd.md`），14h 工时 + 剧情占位 3h。

## Story 列表

### E5-S1 DialogueRunner 状态机 + 对话框完整版 · 8h
- 需求依据：对话 GDD §3.1（字段规范）、§3.4（选项"仅影响当句"）、§4（对话框要素：名字栏/头像窗 48×48/文本区/继续箭头/选项列表）；架构 A7（4 态状态机，约 200-300 行）。
- 做什么：IDLE→PLAYING→WAITING_CHOICE→PLAYING 状态机；逐字 30 字/秒；头像差分静态换帧；选项 ≤2 且分支尾巴 ≤2 条目必须汇合；对话期间锁移动 + 触发器休眠。
- 验收标准：
  - [ ] 对话 GDD §3.1 两个示例 JSON 原样加载运行
  - [ ] 选项必选其一（取消/移动键忽略——边缘 4）
  - [ ] 对话中踩传送点不可能发生（边缘 2：非 IDLE 触发器一律忽略）
  - [ ] 对话中途读档后状态机回 IDLE（边缘 5）

### E5-S2 事件 JSON 加载器 + schema 校验器 + 触发器薄壳 · 4h
- 需求依据：对话 GDD §3.2（9 种动作白名单；conditions 仅 3 键；工程三职责：白名单/引用完整性/结构校验）；§3.2 phase 映射选取规则（取 ≤ 当前 phase 的最大键、至少含 "0" 兜底）；架构 A7。
- 做什么：events/*.json 加载器；加载期校验器（未知 type 报错、dialogue/next/item_id/enemy_group_id 引用全可解析）；trigger_*.tscn 薄壳统一化。
- 验收标准：
  - [ ] `check_flag` 不存在于代码中（done 标准原文）
  - [ ] 悬空引用在加载期报错拦截（边缘 1）
  - [ ] 非数字 phase 键报错；映射选取规则单测通过
  - [ ] 9 种动作全部实装（wait/play_sfx 允许空实现占位）

### E5-S3 story_phase 机制 · 2h
- 需求依据：对话 GDD §3.3（phase 0-3 定义、GameData 单 int、EventBus 广播）；存档字段入 ADR-3（对话 GDD §5）。
- 做什么：story_phase 进 GameData + 存档；`story_phase_changed(n)` 广播；NPC 交互事件按 phase 映射选对话。
- 验收标准：
  - [ ] phase 值随存档往返无损
  - [ ] 6 个配额 NPC（菲奥拉/客栈老板/广场小孩/武器店老头/镇口守卫/神秘旅行者）可观察到阶段对话变化

### E5-S4 剧情四拍 JSON 占位 + 12 NPC 事件 · 1.5h
- 需求依据：对话 GDD §3.5（文件组织约定：story/ p0-p3 分拍、npc_<id> 分文件）；§3.3 三个切换点。
- 做什么：四拍事件骨架（占位文本）+ 12 NPC 事件 JSON + 三个 `set_story_phase` 切换点接线（quest_accept 0→1 / ruin_enter 1→2 / boss_pre 战后 2→3）。
- 验收标准：
  - [ ] **剧情四拍全程只改 JSON 不改代码地跑通**（done 标准原文，占位文本即可）
  - [ ] 3 个切换点时序正确

### E5-S5 Boss 事件锚点 · 1h
- 需求依据：探索 GDD I5 回签（`story_boss_pre` 全序列：战前台词→battle{group:boss_core}→胜利续行→战后台词→set_story_phase(3)→save_point，一次触发避免中途态）；对话 GDD §3.3 切换点 3。
- 做什么：f3 交互键触发器（非踩踏）+ Boss 事件 JSON；battle 动作把事件流暂停交给战斗、胜利后恢复。
- 验收标准：
  - [ ] Boss 战前/后事件完整走通，phase 2→3 在战后段内生效
  - [ ] Boss 失败读档后事件从头可再触发、无中途态残留（探索边缘 3）

（实施顺序 S1→S5；S5 依赖 battle 动作放最后。S1-S3 合计 14h 对齐对话 GDD 工时，S4/S5 为剧情 16h 的占位份额。）

## M5 收口
- A8 行 5 全绿：小镇→道路→遗迹三层全程可走，NPC 会"记得"你的进度，Boss 可战可胜。
- 试玩视频 #5 + git tag `m5`。
- 对话事件 GDD §8 done 标准除"工时 ≤14h"外全部打勾。
