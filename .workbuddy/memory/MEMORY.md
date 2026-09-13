# MEMORY.md — 《轨迹残响》工程记忆(cordit)· 2026-09-13 瘦身 v2

> 主理人:游承峰。类空之轨迹 2.5D JRPG 垂直切片。用户=Web 前端、业余周 5-10h。
> 协作约定:中文输出(含代码注释)、结构化诊断、决策用户拍板、无指令不 commit、每完成一任务停下汇报等确认、**小卡纪律(≤半天/卡)**。
> 续跑入口:本文件(快照+冻结裁决)+ `.workbuddy/memory/` 按日期日志(细节归档,含完整派单规格)。

## 冻结架构(勿翻案)
- Godot 4.7.2 + GDScript;4 Autoload:GameData/EventBus/SceneRouter/SaveManager;core 层纯函数禁 get_node。
- ADR:1 渐进类型 / 2 Resource(数值)+JSON(内容) / 3 JSON 手写存档 / 4 640×360+Nearest 整数缩放;A8 七里程碑表见 docs/architecture/godot4-architecture-adr.md。

## 素材(勿翻案)
- 策略 A 开源:OGA 16x16 主集 + Kenney UI 重上色;账本 3×CC0+3×CC-BY+1×OFL(Fusion Pixel)。**禁** CC-BY-SA/GPL-only/LPC32/bart 城堡件;先登记后复制。
- 敌人头像=精灵×2;faces 裁 32×32 禁缩放;头像窗 48×48;9-slice 边距 8px;遗迹全用 classical_temple_tiles。

## 战斗数值裁定(GDD v1.1,勿改回)
- 物理 DEF 1.0,法术 1.2(勿统一);承伤 剑士4-10%/辅助8-14%/术士10-16%;**逃跑 70%+SPD差×2%(2026-09-13 拍板:以 GDD §3.5+代码 battle_logic.gd:105-108 为准,"80%×3"系派单转述错误作废)**;战斗间 HP/MP 不回满;无回复点;gold 恒 0。
- 技能:凯尔 重斩/横扫/掩护=L1/2/3;莉娜 火球L1/冰锥L2/雷爆L2;莫娜 治疗L1/群愈L2/净化L3;B1 HP50+skills_locked;敌人倍率 .tres:1.0/1.0/1.8/0.8/2.5。
- 失败=读档回存档点;"立绘"=头像差分;16x18≈2.5 头身。

## 存档与传送语义(E4-S6/S7 裁决,勿翻案)
- 门控存档:save_requested_pending(跨图传送/战后 VICTORY 置位)→ 目标图 map_ready 时 consume_save_request() 落盘;存档坐标=玩家实际落位;**落位必须在 TeleportAssembler.assemble 环完成,不可 map_ready 后 deferred**(#8 裁决)。
- 传送正本:teleport_catalog.gd 12 处 + teleports.json 镜像(test_e4s6 锁死);落位防弹回=脚底盒 ±12px;触发器 mask=16。
- DEFEAT 读档:回存档点+免疫 0.5s;失败兜底回暂存图。INITIAL_SCENE_PATH=town。

## 当前状态(2026-09-13 17:2x 快照)
- **HEAD = remote main = `ef4eb82`**;tag m7=4eba8fd。工作区未 commit:#15 改动(battle_command 接缝/test_o7/test_e5s4)+ #11/#12 两文档卡 + evidence/m8-b1-o7-roll-green.log,等用户拍板提交。
- GUT 基线 **575/575**(39 脚本/8684 断言/W2/O10016,#15 新增对偶必败用例);核验器 verify_town 129 / verify_road 66 / verify_ruins 159 全 0 FAIL。
- 阶段:M8 打磨收尾;**用户 17:14 四项拍板:①#15 代码卡与两文档卡分两笔 commit ②#11 方案 B(呈现层切片 13 卡,主推荐) ③逃跑口径以 GDD/代码为准(70%+SPD差×2%) ④#12 先实机走查再议 A 试点**;#11-B 拆卡与 #13 派单待启动。
- ✅ 已实机双验证收口:#8 跨图传送落位 / #9 五图 WallsObjects 归位 YSorted / #10 NPC 交互提示 / #14 剧情事件一次性 / **#15 o7 逃跑 flaky(确定性 roll 注入,RED→GREEN)**。
- 📋 已交付待拍板:**#11 战斗垂直分片提案**(`production/sprints/m8-b4-battle-vertical-slice-proposal.md`;方案 A 6卡/B 13卡主推荐/C 17卡;⚠️ 逃跑口径矛盾:简报"80%×3"无出处 vs GDD+代码"70%+SPD差×2%") / **#12 地图 3D 化评估**(`docs/architecture/map-3d-evaluation.md`;O 默认/A 1卡 spike 试点/B、C 当前负收益) / **#13 原工项链恢复**(未派,前置已满足)。
- 可复用资产:scripts/ui/world_hint.gd / tools/verify_events.py / test_m8a2/m8a3/m8a4 三哨兵。

## 验证纪律(永久有效)
- 「GUT 全绿」≠生产链路成立:必须区分被测链 vs 玩家链;验收须在生产入口做集成实证;UI 信号链须从 command_selected.emit 起驱动(O-7);断言选错观察量=没测(#14 教训)。
- headless 跑测:先查日志体积再 grep(-s 模式解析错误会被断点轰炸);Control 禁 PRESET_FULL_RECT+赋 size;**跑测正本 = APPDATA 沙盒重定向 + 跑前清沙盒残留 save.json,两步缺一不可**。

## 环境与坑(精简)
- Godot console exe 在 WinGet 包目录;GUT 9.7.1;headless 跑测 `MSYS2_ARG_CONV_EXCL="*"`+Windows 反斜杠路径;demo dryrun 加 `--fixed-fps 30 --quit-after 5400`。
- Bash shim 可能坏 → 走 `python -c` 通道取证;PowerShell 输出不回显 → 写文件再 Read。
- 启动游戏(GUI)=Bash 直接执行 exe + run_in_background + dangerouslyDisableSandbox(PS Start-Process 被安全层拦截);bash 抓不到 Godot stdout,日志看游戏控制台窗口或 user://logs/godot.log。
- push 正本:python 写 `C:/Users/weixufeng/.workbuddy/cache/_ssh_cfg_443`(ssh.github.com:443 直连,路径正斜杠)→ `GIT_SSH_COMMAND='ssh -F <cfg>' git push origin main`;commit 用 `git commit -F <msgfile>`;显式 git add 指定路径;.import 改动=CRLF 噪音。
- ⚠️ 已知 flaky:test_o7_ui_bridge::test_逃跑经信号驱动转发(_do_escape randf(),#15 修复中)——全量 GUT 此项偶发红先重跑确认,勿误判回归。
- 远程 git@github.com:ysyonline/cordit.git;*.avi 走 LFS;export/ 不入库;.godot_user_tmp/ 已排除;.gd 必配 .uid。
