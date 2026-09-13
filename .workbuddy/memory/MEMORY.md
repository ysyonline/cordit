# MEMORY.md — 《轨迹残响》工程记忆(cordit)· 2026-09-13 瘦身版

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

## 当前状态(2026-09-13 09:17 快照 · **R-3 AI 代录已 commit+push `aefdece`,待 M7 门终审**,新窗口续跑入口)
- **阶段:Phase 7 · 发布门(最后一审)。HEAD = remote main = `ebf5bc1`**;tag 止于 m7(dcee4d6)。
- **✅ 试玩者复测已回收(03:01 用户口头转述)**:04 批次试玩者玩完,反馈「没有大问题了」——B-01 引导修复实证消除 R-1。无正式问卷,门审时按口头结论落档。
- **✅ R-3 已达成(AI 代录口径,`aefdece` 18 文件)**:用户拍板「你自己来录」→ 派 engineering-lead 建 M6 范式确定性驱动器(tools/dev/_m7_r3_autodrive+battle_director+preplant)。产物:evidence/m7-gameplay.avi **1:40(3004帧@30fps,覆盖用户手录6:20版)** + m7-recording.log **29断言全PASS零FAIL** + 干跑日志。链路:读档→B4 R4胜(群愈/毒/防御)→B5 R7胜(蓄力/弱点弹字)→结尾钩子停2.4s→phase=3落盘。确定性实证:干跑与录制逐字节一致。
- **⚠️ 门审豁免两条(待严守真签字)**:①时长 1:40 < shotlist 2-3 分钟(AI 信号通道结构性快,三镜头硬要求全覆盖);②录制起点=沙盒预植档 Lv4(用户真实档 Lv1 无群愈拍不了镜头③;真实档全程零接触)。
- **✅ battle_command 两处修复(随 aefdece 入库)**:_charging 跨轮保留(蓄力release分支此前生产不可达)+ VICTORY 升级 level_after 写回快照(结算与菜单等级矛盾)。**GUT 551/551**。
- **⚠️ GUT 偶发超时隐患(已留档)**:o7「逃跑经信号驱动转发」全量跑测下偶发超窗(信号已消费但12s窗内未落地;复跑即绿,改动面无交集)——后续可放宽 _wait_forwarded 超时或降载跑测。日志:_r3_commit_gut.log/_r3_o7_solo.log。
- **生产缺口三条已落档(production/qa/m7-r3-recording-findings.md,下Sprint候选)**:a) charge 事件无生产 UI 反应(battle_ui 只渲染 damage/weakness;battle_command 头注「UI订阅event_emitted」与事实不符,_emit_all 空桩);b) 战前对话 story_p3_boss_front 被转场强制收束,玩家实况不可见(executor 同步流,需产品侧确认叙事预期);c) 战斗内道具消耗不持久化(已立 Story: production/sprints/story-battle-item-persistence.md,P2 未排期)。
- **下一步(新窗口从这里接)**:①派严守真 M7 门终审(R-3 全证据+复测口头结论+两条豁免)→②门过则 tag m7 收口 →③M8 前恢复 design/(git 历史 4f3b717,`git show 4f3b717^:design/<path>`)。
- **杂项**:工作区残留 3 个临时取证件(evidence/_tmp_check1.log/_tmp_check2.log/_tmp_exit.txt)未跟踪,下次提交顺手清;驱动器三件套按 tool-disposition 惯例录后可删(暂留)。
- **push 坑(沿用)**:代理 7892 关闭时用 `git -c core.sshCommand="ssh -o ConnectTimeout=8" push origin main` 直连成功(aefdece/ebf5bc1 两连推验证)。
- **B-01 前情(已收口,细节见 09-13 日志)**:引导缺位修复 commit `1b5b925`;用户真人端到端验证 PASS(Boss DEFEAT 一次即止);04 批次 zip 已发试玩者。

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
