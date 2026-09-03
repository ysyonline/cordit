# Sprint 5 会话交接文档（2026-09-02 午更新）

> 用途：本文件是 Sprint 5（EPIC-5 剧情串起来）的**会话交接正本**。新开会话时把此文件喂给主理人即可无损续跑。9/1 会话因网络六断 + 一次服务端 500 + 一次 aborted，成员更换过一轮；9/2 晨会话成员通道又三连挂（killed/aborted/aborted），S5 修复经用户拍板由主理人代笔完成（选项 A）。

## 一、当前状态总览（2026-09-02 11:45）

**Sprint 5 进度：5/5 工程任务完成 ✅，S5 已收口。测试基线 410/410 全绿 + 冒烟五通道全绿。**

| # | 任务 | 状态 | 基线 |
|---|------|------|------|
| 1 | E5-S1 DialogueRunner 状态机 + 对话框完整版 | ✅ 收口 | 313/313 |
| 2 | E5-S2 事件 JSON 加载器 + schema 校验器 + 触发器薄壳 | ✅ 收口 | 367/367 |
| 3 | E5-S3 story_phase 机制 | ✅ 收口 | 384/384 |
| 4 | E5-S4 剧情四拍 JSON 占位 + 12 NPC 事件 | ✅ 收口 | 393/393 |
| 5 | E5-S5 Boss 事件锚点 | ✅ 收口（11:40，主理人代笔修复） | 410/410 |
| 6 | E5-QA 回归 + 冒烟 + M5 门槛核验 | ✅ 收口（11:55，严守真独立复核 **PASS**） | 410/410 独立复现 |
| 7 | M5 收口：视频 #5 + 验收档 + commit + tag m5 | ⏳ 排队（依赖 #6；**commit/tag 前须用户确认**） | — |

## 二、S5 收口记录（2026-09-02，勿翻案）

- 实现落盘：battle_event_bridge.gd（SceneRouter 常驻装配 + global_event_executor 单例）、event_executor.gd 挂起簿记（resolve_victory/in_battle_pause/clear_battle_pause/_from_event_battle 哨兵）、ruins_f3_map.gd 棺前交互键锚点（双锚只装首实体）、story_anchor.json I5 全序列（story_p3_boss_front → battle b5_core → story_p3_finale → phase 3 → save_point）。
- 主理人修复 7 处（3 组根因）：①get_tree 守卫改 is_inside_tree；②双锚 continue 跳过（弃 queue_free）；③**桥接死锁**（_on_enemy_touched 首行空簿记 return 堵死登记路径——生产级 bug，Boss 胜利后剧情永不续行；删守卫改纯哨兵判别）；④桥新增 clear_pending() 测试口（与 executor 对称清理，防 e2→e3 泄漏）；⑤测试 emit VICTORY 前显式 force_idle（帧末时序）；⑥e5s4 c1/c2 适配 battle 挂起新契约（挂起→模拟胜利→resolve_victory）；⑦battle_scene.gd `i / GRID_COLS` 改 `int(i / float(GRID_COLS))` 消 INTEGER_DIVISION。
- 证据：evidence/e5s5-gut-s5.log（410/410，EXIT=0）+ evidence/e5s5-smoke-{e1s4,e1s5,e1s6,smk,smk-e1s3}.log（3/3、4/4、5/5、4/4、5/5 全 EXIT=0）。
- S5 验收两条均已锁进 test_e5s5（c1 验收①战前/后完整走通 + phase 2→3 战后段生效；c3/D 组验收②失败读档无中途态可重触发）。

## 三、E5-QA 收口记录（2026-09-02 11:55，严守真独立复核）

- **总判定 PASS**：静态复核 5 文件无阻塞疑点（死锁修法/哨兵判别/双锚/除法/断言未放宽全部核验安全）；全量独立复跑 410/410（EXIT=0，零 [Failed]）；冒烟五通道独立复跑全 EXIT=0 满额。
- M5 门槛 A8 行 5 三项 + 对话 GDD §8 done 标准（除工时豁免）逐条 PASS，依据映射见本节归档报告（成员 SendMessage 原文，2026-09-02 11:55）。
- 非阻塞备忘 2 条：①ruins_f3_map L107 冗余防御（恒真 if，零行为影响）；②GDD §8-4「选项不留痕迹」靠结构性保证+相邻覆盖，无专门命名用例——均可接受，不扣门。
- 证据：evidence/qa-e5-gut-full.log + qa-e5-smoke-{e1s4,e1s5,e1s6,smk,smk-e1s3}.log（6 文件独立产出）。

## 四、昨日关键裁决记录（勿翻案）

1. **S1**：GDD §3.1 带 choices 条目可省略 next（按示例口径，不改正本；运行时缺省兜底 "END"）。
2. **S2 四项**：①"9 种动作"按全量 10 type 落地；②trigger 统一化以脚本兑现（trigger_event_shell.gd），不建空壳 .tscn；③Godot JSON 恒产 float——整数字段"float 收/整值验/int 落"；④E4 镜像 JSON 无 events 键返回 skipped:true。
3. **S3**：e2s4 跨套件泄漏修法=该文件内补 story_phase 快照备份/还原（3 行，非全局）；interaction_controller 只修拼接点不整文件回滚。
4. **S4 三项**：①平铺+story_ 前缀承载 GDD §3.5 子目录语义（schema 加载口子目录支持 defer 后续 sprint）；②菲奥拉实体锚点顺延 npc_13（5 实体+事件表兑现 6 席配额，不动 town.tscn）；③冒烟日志实为 UTF-8（UTF-16/iconv 结论作废）。

## 五、新增工程纪律（长期有效，新会话必须遵守）

- ⚠️ **GameData 加新字段时**：必须 grep tests/gut 里含 before_all 快照的文件，把新字段补进备份/还原对（e2s4 式跨套件泄漏坑——story_phase=7 曾横穿 4 个套件污染 e5s3）。GameStateSnapshot helper 单测基类列入技术债候选。
- **JSON 文本占位禁 ASCII 引号**（会破 JSON），用直角引号『』替代。
- GDD §3.1 带 choices 条目可省略 next（S1 裁决）。
- **（9/2 新增）信号驱动桥接类**：消费函数勿以"簿记为空"作首行守卫（登记与消费同函数时构成死锁）——判别职责交给哨兵键。
- **（9/2 新增）测试对称清理**：登记型用例结束时，簿记宿主与登记方都要清（e2 清 executor 不清桥，泄漏到 e3）。
- **（9/2 新增）GDScript 4.7.2 无全局 intdiv()**（Parser Error）；整除用 `int(a / float(b))` 或 `@warning_ignore("integer_division")`。

## 六、环境坑速查（新会话成员必读）

- Godot exe：`D:\software\Godot\Godot_v4.7.2-stable_win64.exe`；headless 跑测 `MSYS2_ARG_CONV_EXCL="*"` 下用 Windows 反斜杠路径，见 tests/README.md §2.4
- GUT 9.7.1；-gtest 参数不生效（跑全量），筛失败重定向后 grep "[Failed]"
- 新建 .gd 必配 .uid（uid:// 一行）
- queue_free 帧末生效；GUT 日志实为 UTF-8（无需转码）；GUT 失败块打印时序可能导致"失败用例归属"误读（S3 的 a4 误标教训）
- curl 测网络须 `--noproxy "*"` 才是真实直连结果；成员报 502 先 ping 网关分段定位
- **（9/2 新增）全量跑测日志 ~33MB**：统计行在尾部，`tail -c 2000 | grep` 提取；中文段可能乱码属正常
- **（9/2 新增）冒烟入口形态不一**：e1s4/e1s6/smk/smk-e1s3 用 `.tscn` 入口，e1s5 用 `headless_e1s5_wrapper.tscn`（无裸 e1s5.tscn）；`--script` 直跑 .gd 报 "doesn't inherit from SceneTree or MainLoop"

## 七、风险与杂项

- **M5 视频评估 Git LFS**：仓库 size-pack ~100MiB（M4 视频 89.3MB 入库后），M5 视频 #5 录制前先评估；不可行则沿 M4 先例直接入库。
- **遗留小债**：tools/README.md 未登记 gen/verify 工具链；sfx 为 E6 预留钩子；GameStateSnapshot helper 基类。
- **probe*.txt 13 个**（仓库根目录）：M5 收口前清理（主理人任务）。
- 9/1 网络六断；9/2 晨成员通道三连挂（killed/aborted/aborted，最短 6 分钟零落盘）——连续异常时主理人代笔是既定兜底（沿 E4-S2/S3 先例，本次用户拍板选项 A）。

## 八、团队与任务系统状态

- 团队：`sprint5-epic5-e314`（本会话新建；工作区任务 #1 S5 已 completed，#2 QA、#3 M5 pending）
- 成员：engineering-lead（killed）、engineering-lead-3（aborted）、engineering-lead-4（aborted）——全部弃用；E5-QA spawn 新 quality-lead 实例
- 正本文档：对话 GDD `design/gdd/dialogue-event-gdd.md`；架构 `docs/architecture/godot4-architecture-adr.md`（A7/A8）；里程碑 `production/epics/EPIC-5.md`
- 证据链：evidence/e5s{1,2,3,4,5}-gut-*.log + e5s{1,3,4,5}-smoke-*.log 全部在案
