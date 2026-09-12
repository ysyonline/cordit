# MEMORY.md — 《轨迹残响》工程记忆(cordit)· 2026-09-12 瘦身版

> 主理人:游承峰(游戏开发工作室专家团)。类空之轨迹 2.5D JRPG 垂直切片。
> 用户=Web 前端、业余周 5-10h;协作约定:中文输出(含代码注释)、结构化诊断、决策用户拍板、无指令不 commit、**每完成一任务停下汇报等确认**。
> **续跑入口**:本文件(当前快照+冻结裁决)+ `.workbuddy/memory/` 按日期日志(细节归档)。瘦身原则:已完成事项细节进日志,本文件只留"裁决+现状"。

## 冻结架构(勿翻案)
- Godot 4.7.2 + GDScript;4 Autoload:GameData / EventBus / SceneRouter / SaveManager。
- 4 ADR:渐进类型 / JSON(内容)+Resource(数值) / JSON 手写存档 / 640×360+Nearest 整数缩放。
- core 层纯函数禁 get_node;总文档 `docs/architecture/godot4-architecture-adr.md`(含 A8 七里程碑表)。

## 素材(策略 A 开源,勿翻案;**禁** CC-BY-SA/GPL-only/LPC32/bart 城堡件;先登记后复制)
- OGA 16x16 主集(surt CC0/Redshrike/Antifarea CC-BY/DawnLike)+ Kenney UI 重上色;账本 3×CC0+3×CC-BY+1×OFL(Fusion Pixel)。
- 敌人头像=精灵×2 放大;faces 裁 32×32 禁缩放;头像窗 48×48;9-slice=五色板边距 8px;遗迹全用 classical_temple_tiles(选型表 design/assets/temple-tileset-selection.md)。

## 战斗数值裁定(GDD v1.1,勿改回)
- 物理 DEF 系数 1.0;**法术 1.2 勿顺手统一**;承伤 剑士4-10%/辅助8-14%/术士10-16%;逃跑 80%×3;战斗间 HP/MP 不回满;回复点不设。
- 技能:凯尔 重斩/横扫/掩护=L1/2/3;莉娜 火球L1/冰锥L2/雷爆L2;莫娜 治疗L1/群愈L2/净化L3;B1 HP50+skills_locked;敌人倍率 .tres:1.0/1.0/1.8/0.8/2.5。
- 失败=读档回存档点;gold 恒 0;"立绘"=头像差分;16x18≈2.5 头身。

## 存档与传送语义(E4-S6/S7 裁决,勿翻案)
- **门控存档**:save_requested_pending 意图位(跨图传送/战后 VICTORY 置位)→ 目标图 map_ready 时 consume_save_request() 落盘;启动装载/同图室内传送不落盘;存档坐标=玩家实际落位。
- **传送正本**:teleport_catalog.gd 12 处 + teleports.json 镜像(test_e4s6 锁死);落位防弹回=脚底盒 ±12px 与触发区零重合;传送触发器 mask=16。
- **DEFEAT 读档**:load_save() → last_loaded → 回存档点+免疫 0.5s;失败兜底回暂存图。
- R1/R2 已落地:INITIAL_SCENE_PATH=town;town 南门栅栏已拆。

## 当前状态(2026-09-13 02:50 快照 · **B-01 已 commit+push `1b5b925`,等试玩复测回收**,新窗口续跑入口)
- **阶段:Phase 7 · 发布门。HEAD = remote main = `1b5b925`**(B-01 修复+证据+回收档+记忆);tag 止于 m7(dcee4d6)。**04 批次 zip 已发放试玩者**(02:44 用户拍板);用户真人端到端验证 PASS(Boss DEFEAT 一次即止,不打第二次)。
- **push 坑(新)**:代理 7892 关闭时 git push 走 SSH 代理配置会 errno=10061 → 用 `git -c core.sshCommand="ssh -o ConnectTimeout=8" push origin main` **直连成功**。
- **✅ R-1 断点诊断已实锤(2026-09-13 凌晨)**:headless 全链路复现 `evidence/_story_chain_repro.log` ALL PASS——**代码链零断点**,R-1 story_phase=0 属引导缺位(玩家未接取任务;告示板无「!」+ 无任务目标 HUD)。回收档 m7-external-playtest-01.md §2(三问/B-2/结尾钩子全未过)+§3(B-01 Blocker~B-06)+§4(草稿🟡 CONCERNS)+§5 已填。待用户拍板 M7 门判定。
- **✅ B-01 引导缺位修复已落地(2026-09-13 00:55,用户拍板「按建议执行」,工作区未提交)**:
  - 新 `scripts/ui/quest_objective_hud.gd`(+uid):常驻任务目标 HUD,story_phase_changed 驱动+_ready 直读 GameData 初始同步;文案 0=查看告示板接取委托/1=前往遗迹一层/2=深入遗迹第三层石棺/≥3 隐藏;左上 (8,32)。
  - `town_map.gd` 三增量:_assemble_quest_objective_hud(脚本判重守卫)/_attach_billboard_hint(告示板「❗Z」金色脉冲,O-12 同款,phase>=1 门控隐藏)/billboard_hint+quest_objective_hud 实例变量。
  - 新 `tests/gut/test_b01_guide.gd` 13 用例(A 纯逻辑5/B 信号4/C 装配4);新 `tools/dev/_b01_smoke_verify.gd`+`.tscn` 生产装配冒烟 4/4 PASS(`evidence/_b01-smoke.log`)。
  - **测试:GUT 551/551 全绿**(`evidence/_b01-gut-full.log`;538 存量零回归+13 新增)。
- **⚠️ 未提交 → 已清**:B-01 套件+evidence+回收档+记忆已全部进 `1b5b925`(22 文件);m7-gameplay.avi(124MB 作废)留磁盘不入库。
- **下一步(等复测回收)**:①试玩者复测问卷回收(04 批次)→②R-3 重录 m7-gameplay.avi(须在含 B-01 的新包上)→③M7 门最终判定;M8 前恢复 design/(git 历史 4f3b717)。
- **✅ B-01 真人端到端验证 PASS(2026-09-13 02:4x)**:用户完整走链——告示板接委托(0→1)→road 甲虫 VICTORY→f1 自动 P2(1→2)→f3 棺前 Boss 战开打。**Boss 战 DEFEAT**(kyle Lv1 阵亡,数值预期内);读档回 f3(320,40) phase=2,簿记清空可重触发;DEFEAT 读档语义实战验证通过。R-1 根因修复实证闭环,四环节引导全命中。重试建议已给(f2 B4 练级/防御/药)。
- **⑤ M7 收口前情**:dcee4d6「O-5~O-13 全套修复+03 批次」112 文件。R-1 已发出(22:37)并回收归档(23:00)。
- **✅ O-13 顶部触发区已锁死**:4 条返程 size (2,2),阈值 y≤32,实机验证闭环;**勿改回 2×1、勿下移 tile y=1**。
- **✅ 04 批次已重导出（2026-09-13 02:1x,用户拍板②不等①）**:exe `01F7DCF0…` 逐字节不变;pck `BFDD4722F46D162F…` 3,416,012 B(含 B-01);zip `F584BB5128730A79…69B19BA4` 42,029,052 B(14 条目顶层目录结构,CRC OK,内件与 win/ 逐字节一致);03 zip 退役 _RETIRED-21-50-batch03.zip。导出包冒烟 PASS(QuestObjectiveHud 常驻装配日志+零 SCRIPT ERROR,evidence/_b01-batch04-smoke.log)。回收档 §0.3 已回写指纹。**待:用户实机目检→发试玩者复测→M7 门判定→commit**。
- **新坑三则(全项目永久有效)**:①GUT 存档隔离坑**变体**——沙盒 APPDATA 自身残留旧 save.json 也会泄入(DEFEAT 用例 load_save 回滚 GameData 造成假红);**跑测前必须清沙盒存档**,仅重定向 APPDATA 不够。②-s 模式解析错误被 debugger 轰炸成亿级日志——先查体积再 grep。③Control 禁 PRESET_FULL_RECT+赋 size(假红),等值锚点+直设 position/size。④**pck 内容判定禁字节扫中文**(编译后 token 流,中文非明文=假阴性;03 已验证串也搜不到);ASCII 路径串可信,最可靠=运行级冒烟。⑤导出产物落名走 {preset_name} 占位符,导出后须手动归位;zip 顶层目录结构须对齐历史批次。
- **R-3 时序实证**:m7-gameplay.avi(10:47 录)早于 O-6 修复已作废,须在含 B-01 修复的新包上重录。
- **M6/M7 前情**:M6=e5ad6a0;O-5~O-13 修复明细见 09-12 日志。**design/ 正本只在 git 历史**(4f3b717 删除,`git show 4f3b717^:design/<path>` 取回)→ M8 前必须恢复。

## 验证纪律(O-6/O-7 教训,全项目永久有效)
- 「GUT 全绿+demo 走通」≠ 生产链路成立——**必须区分"被测对象走的链"与"玩家走的链"是否同一条**;里程碑验收须在**生产入口**(Router 路由目标)做集成级实证(headless 冒烟断言生产侧日志),不能只靠直驱单测。
- **O-7 追加**:UI 信号→状态机的"玩家驱动链"必须有专门回归用例(test_o7_ui_bridge 模式:从 command_selected.emit 开始驱动);demo 的 _autoplay / 测试的直驱 submit_command 都会掩盖接线缺失。
- **O-10 追加**:headless 跑测日志**先查体积再 grep**(-s 模式解析错误会被 debugger 断点轰炸成亿级字符);Control 布局禁"PRESET_FULL_RECT+赋 size"组合(引擎告警→GUT Unexpected Errors 假红),用等值锚点+直设 position/size。
- **B-01 追加(存档隔离坑完整口径)**:APPDATA 重定向只隔离真实用户档,**沙盒自身残留旧 save.json 也会经 DEFEAT→load_save 链泄入**(e5s5 test_d1 假红实证);跑测正本命令 = 重定向 + **跑前清沙盒存档**两步缺一不可。

## 环境与坑(精简版)
- Godot=winget 装于 `C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_…\Godot_v4.7.2-stable_win64_console.exe`;GUT 9.7.1;headless 跑测 `MSYS2_ARG_CONV_EXCL="*"`+Windows 反斜杠路径+**APPDATA=gut-sandbox 沙盒重定向(防真实存档泄入)**;demo dryrun 加 `--fixed-fps 30 --quit-after 5400`。
- **WorkBuddy Bash shim 可能坏**(dirname/cd/head 报错)→ 改走 `python -c` 通道,一切取证可靠。
- 高频坑:类型化数组逐元素 append;GDScript 无元组赋值;`-s` 模式 Autoload 须 get_node 运行期取、SceneRouter 拒切换;Git Bash 传 APPDATA 用正斜杠;PS1 中文须 UTF-8 BOM;导出 exclude_filter 递归用 `**`;导出模板装 `.godot_user_tmp/Godot/export_templates/4.7.2.stable/`;.gd 必配 .uid;日志分析用 Grep/Read 直读(Bash 大输出截断);.import"改动"=CRLF 噪音(`git -c core.autocrlf=false diff` 验)。
- 仓库:`*.avi filter=lfs` 已配;`export/` 不入库、export_presets.cfg 已入库;`.godot_user_tmp/` 已排除。远程 `git@github.com:ysyonline/cordit.git`(SSH+代理 127.0.0.1:7892)。
