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

## 当前状态(2026-09-12 20:15 快照 · 归档版,新窗口续跑入口)
- **阶段:Phase 7 · 发布门,QA 门 🔴 FAIL 维持**(production/qa/m7-final-qa-gate.md 正本)。tag 止于 m6;HEAD `4821c42`。
- **本日已修六笔(O-5~O-10),全部在工作区未提交**:O-5 f1 入口剧情锚装配;O-6 碰怪无战斗(battle_scene.gd 接真实输入桥+敌方 0.9s 驱动+结算驻留 15s 护栏);O-8 目标选择键盘(battle_ui.gd _unhandled_input);O-9 转场层吞鼠标(全屏 Control 补 IGNORE,CmdMenu/SubMenu 留 STOP);O-10 三件套=①f3 棺前「❗Z」提示(ruins_f3_map.gd _attach_interact_hint,挂场景根防 y-sort 遮盖)②地图名 HUD(新 map_name_hud.gd,UILayer 常驻 town 首装跨图复用,显示名正本=teleport_catalog.MAP_DISPLAY_NAMES:清溪镇/林间小道/遗迹一二三层)③存档反馈条(save_icon.gd 重写为「已存档 · <图名>」文字条 1.6s,flash 兼容+flash_map 新口;autosave_notifier 透传图名;menu_panel 手动存档同款反馈)。
- **测试**:GUT **538/538 全绿**;O-10 冒烟 tools/dev/_o10_smoke_verify.gd **4/4 PASS**;O-7 冒烟 _o7_smoke_verify.gd PASS;O-7/O-10 回归用例=test_o7_ui_bridge.gd(8 用例)+test_o6_real_battle.gd(适配版)。
- **✅ O-13 已修并实机验证闭环(2026-09-12 21:45)**:顶部触发区不对称——玩家碰撞盒 size(12,6) offset(0,-3) 挂脚底**上方**,顶部触发区(tile y=0,size 2×1→y∈[0,16])实测需中心 y≤16 才触发,门洞第 2 格中心 y=24 无反应;底部触发区方向相反天然宽容。**修法=4 条顶部触发区 size 改 (2,2)**(tp_road_to_town/tp_f1_to_f1→f1_to_road/tp_f2_to_f1/tp_f3_to_f2),catalog+json 两处同步,阈值放宽到 y≤32;落位余量 f1/road 24px、f2/f3 8px 均不弹回。**勿改回 2×1**;**勿整块下移到 tile y=1**(贴墙位 x=296,y=40 误触发)。
- **新坑两则(O-10 入册)**:①-s 模式解析错误会被 debugger 断点轰炸成亿级日志——headless 跑测先查日志体积再 grep;②Control 用 PRESET_FULL_RECT 后赋 size 触发引擎告警→GUT Unexpected Errors 假红,须等值锚点+直设 position/size。
- **⚠️ 新坑:GUT 不隔离用户存档**——真实 save.json 泄入测试造成 12 条假红;**跑测正本命令自此必须带 APPDATA=D:/code/cordit/.godot_user_tmp/gut-sandbox 重定向**。
- **待办(新窗口按序执行,等用户发话)**:①~~修 f3→f2 触发区~~ **已完成并实机验证(O-13)**→②③~~03 批次导出+zip~~ **已完成(21:50,zip=D94C410E1C17B12A…/pck=B73F705DACA746BD…/exe 不变 01F7DCF0…;启动验证过=清溪镇;02 退役 _RETIRED-14-51-batch02.zip)**→④~~指纹回写三文档~~ **已完成(closeout §7+§13.5/playtest §0.2/kit §7.4.3)**→⑤工作区变更 commit(O-5~O-13 套件+production 文档+记忆)+tag m7→⑥R-1 外部试玩/R-2 非开发机/R-3 重录视频均在 03 批次上回收。
- **R-3 时序实证(存档)**:10:47 首录视频早于战斗修复,已作废;m7-gameplay.avi 须重录(经 m7-gameplay 实证 R-3 时序)。
- **M6 已收口**:commit e5ad6a0 + tag m6 + push 三方一致;收口正本=evidence/m6-closeout.md。
- **M7 前情**:E7-S1 数值调校、E7-S2 剧情统稿、头像修复(2× 整数放大)、R6 告示板接线、R7 角色换装(char_anim.gd 工厂,分配表待用户目检)——细节见 09-05~09-12 日志。
- **design/ 正本只在 git 历史**(4f3b717 删除入库,取回 `git show 4f3b717^:design/<path>`)→ M8 周期前必须恢复,否则无数值参照。
- **工作区未提交清单(git status 20:15 实盘)**:M 18 文件(.workbuddy 记忆×2 + production 文档×4[qa-gate/playtest-kit/playtest-01/package-closeout] + scripts×11 + test_e2s3) + ?? 新增(map_name_hud.gd+.uid / test_o6_real_battle+.uid / test_o7_ui_bridge+.uid / tools/dev 冒烟 4 件 / evidence 取证日志约 40 件含 _r3-frames 与 m7-gameplay.avi[LFS 作废视频])。commit 惯例:evidence/ 取证件入库,.workbuddy/artifacts/ 不入库。

## 验证纪律(O-6/O-7 教训,全项目永久有效)
- 「GUT 全绿+demo 走通」≠ 生产链路成立——**必须区分"被测对象走的链"与"玩家走的链"是否同一条**;里程碑验收须在**生产入口**(Router 路由目标)做集成级实证(headless 冒烟断言生产侧日志),不能只靠直驱单测。
- **O-7 追加**:UI 信号→状态机的"玩家驱动链"必须有专门回归用例(test_o7_ui_bridge 模式:从 command_selected.emit 开始驱动);demo 的 _autoplay / 测试的直驱 submit_command 都会掩盖接线缺失。
- **O-10 追加**:headless 跑测日志**先查体积再 grep**(-s 模式解析错误会被 debugger 断点轰炸成亿级字符);Control 布局禁"PRESET_FULL_RECT+赋 size"组合(引擎告警→GUT Unexpected Errors 假红),用等值锚点+直设 position/size。

## 环境与坑(精简版)
- Godot=winget 装于 `C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_…\Godot_v4.7.2-stable_win64_console.exe`;GUT 9.7.1;headless 跑测 `MSYS2_ARG_CONV_EXCL="*"`+Windows 反斜杠路径+**APPDATA=gut-sandbox 沙盒重定向(防真实存档泄入)**;demo dryrun 加 `--fixed-fps 30 --quit-after 5400`。
- **WorkBuddy Bash shim 可能坏**(dirname/cd/head 报错)→ 改走 `python -c` 通道,一切取证可靠。
- 高频坑:类型化数组逐元素 append;GDScript 无元组赋值;`-s` 模式 Autoload 须 get_node 运行期取、SceneRouter 拒切换;Git Bash 传 APPDATA 用正斜杠;PS1 中文须 UTF-8 BOM;导出 exclude_filter 递归用 `**`;导出模板装 `.godot_user_tmp/Godot/export_templates/4.7.2.stable/`;.gd 必配 .uid;日志分析用 Grep/Read 直读(Bash 大输出截断);.import"改动"=CRLF 噪音(`git -c core.autocrlf=false diff` 验)。
- 仓库:`*.avi filter=lfs` 已配;`export/` 不入库、export_presets.cfg 已入库;`.godot_user_tmp/` 已排除。远程 `git@github.com:ysyonline/cordit.git`(SSH+代理 127.0.0.1:7892)。
