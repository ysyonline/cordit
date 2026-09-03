# M5 验收证据档（2026-09-03）

> 垂直切片第五里程碑：剧情串起来（4 张图 + story_phase 机制 + NPC 阶段对话 + Boss 可战可胜）。
> 执行模式：用户逐项指令推进（①②已完成并报备；本档为第③步；④ commit+tag 待用户另行发话）。

## M5 收口四件套进度

| # | 项目 | 状态 | 证据 |
|---|------|------|------|
| ① | demo 全绿（dryrun + GUT 全量） | ✅ | m5-demo-headless-dryrun10.log / m5-final-gut-full.log |
| ② | 视频 #5 | ✅ | m5-gameplay.avi + m5-recording-log.md |
| ③ | 验收档（本档） | ✅ | m5-acceptance.md |
| ④ | commit + tag m5 | ⏳ 待用户发话 | — |

## 收口项详情

### ① demo 全绿 ✅
- 交付：`evidence/_m5_auto_demo.gd` + `.tscn`（A4 常驻根替身，8 幕确定性演示）
- 证据：`evidence/m5-demo-headless-dryrun10.log`（第 10 遍 PASS，终态验证：
  I5 全序列 battle→续行→phase3→save_point 落地；存档指纹
  map=ruins_f3 position=(320,40) story_phase=3 与预期逐项一致；demo 存档自清理）
- GUT 全量：**415/415**（m5-final-gut-full.log，24.7s，All tests passed）
  - 基线演进：286（M4）→ S1 313 → S2 367 → S3 384 → S4 393 → S5 410 → 收口修复 415（净增 +129）
- 演示覆盖链路：town 出生（不落盘）→ 客栈老板 phase 对话 → 南门跨图 road（落盘）
  → 遗迹 f1→f2→f3 穿带走位 → 棺前 Boss 锚点交互 → story_boss_pre 战前拍
  → battle b5_core（VICTORY 剧本）→ 桥消费续行回 f3 → 战后台词 + phase 2→3 + save_point

### ② 视频 #5 ✅
- 交付：`evidence/m5-gameplay.avi`（306 MB，4849 帧 @30fps = 2m41s，Movie Maker 真实引擎画面）
- 工具：`tools/record_m5_gameplay.bat`（镜像 M4；安全阀 1920→5400 帧，实际由 demo 自带 quit 收尾）
- 过程注记：录制经直调 Godot exe 完成（WorkBuddy Git Bash 的 cmd //c 引号传递坑，
  与 bat 参数完全一致，详见 `evidence/m5-recording-log.md`）；用户后续双击 bat 可复现
- 确定性保证：禁随机、固定 walk 锚点、VICTORY 剧本，与 dryrun10 日志逐幕对应；无 AI 生成画面
- 片长说明：161.6s 长于实时估算，系 Movie Maker 固定帧步进下对话逐字/补按节拍
  较 headless 慢，画面内容完整（8 幕全部走完至 PASS）

### ③ QA 回归（E5-QA，严守真独立复核）✅ PASS
- 静态复核：S5 主理人代笔修复 7 处（3 组根因）逐项核验安全
  （桥接死锁修法/哨兵判别/双锚只装首实体/整除修正/断言未放宽）
- GUT 独立复跑：**410/410**（qa-e5-gut-full.log，EXIT=0，零 [Failed]）
  - 注：410 为 QA 时点基线；收口期主理人另有 3 处生产级修复（Router 覆写暂存位/
    f3 runner 注入直取/桥哨兵直通），修复后终态 415/415（m5-final-gut-full.log）
- 冒烟五通道独立复跑，全 EXIT=0 满额：

| 通道 | 结果 | 证据 |
|------|------|------|
| e1s4 走位 | 3/3 PASS | evidence/qa-e5-smoke-e1s4.log |
| e1s5 门传送 | 4/4 PASS | evidence/qa-e5-smoke-e1s5.log |
| e1s6 传送网络 | 5/5 PASS（回归锚） | evidence/qa-e5-smoke-e1s6.log |
| smk 核心信号 | 4/4 PASS | evidence/qa-e5-smoke-smk.log |
| smk-e1s3 空壳 | 5/5 PASS | evidence/qa-e5-smoke-smk-e1s3.log |

- 非阻塞备忘 2 条（QA 原文，不扣门）：①ruins_f3_map L107 恒真防御 if（零行为影响）；
  ②GDD §8-4「选项不留痕迹」靠结构性保证+相邻覆盖，无专门命名用例

### Sprint 5 五 Story 工程收口（过程档，详见 sprint5-handoff.md）

| Story | 内容 | 收口基线 |
|-------|------|---------|
| E5-S1 | DialogueRunner 状态机 + 对话框完整版 | 313/313 |
| E5-S2 | 事件 JSON 加载器 + schema 校验器 + 触发器薄壳 | 367/367 |
| E5-S3 | story_phase 机制 | 384/384 |
| E5-S4 | 剧情四拍 JSON 占位 + 12 NPC 事件 | 393/393 |
| E5-S5 | Boss 事件锚点（主理人代笔修复桥接死锁） | 410/410 |

- 内容规模：对话 JSON 58 个 + 事件 JSON 11 个（data/json/），story_phase 三切换点接线
- EPIC-5 done 标准：对话 GDD §8 除「工时 ≤14h」外全部打勾（工时豁免由用户既有裁定）

## ④ commit + tag（待用户发话）
- 待提交内容概览：新文件 122 个（E5 测试 5 件套+fixtures、事件/对话系统脚本、
  58 对话 JSON、60+ 证据日志、本档、视频 #5、录制 bat）+ 修改 80 个
  （其中 .import 行尾噪声 58 个拟沿 M4 惯例剔除；m1-m4 avi 的 M 状态为 LFS filter
  改写效应非内容变更，拟一并剔除）；代码主体 +648/-127（scripts/tests/autoload）
- 计划：用户确认后 commit + tag `m5` + push（含 LFS 大文件）

## 遗留项
- 人眼手感/观感抽查（视频已可本机播放复核，自动化边界）
- tools/README.md 登记 gen/verify + record 工具链（小债顺延）
- sfx 为 E6 预留钩子（play_sfx 空实现占位）
- 剧情占位文本 → M6（E6-S5）实写第一批
- 非阻塞备忘 2 条（见③）
