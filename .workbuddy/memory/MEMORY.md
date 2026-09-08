# MEMORY.md — 《轨迹残响》工程记忆（cordit）

> 主理人：游承峰（游戏开发工作室专家团）。类空之轨迹 2.5D JRPG 垂直切片。
> 用户=Web 前端、业余周 5-10h；协作约定：中文输出（含代码注释）、结构化诊断、决策用户拍板、无指令不 commit、**每完成一任务停下汇报等确认**。

## 冻结架构（勿翻案）
- Godot 4.7.2 + GDScript；4 Autoload：GameData / EventBus / SceneRouter / SaveManager。
- 4 ADR：渐进类型 / JSON(内容)+Resource(数值) / JSON 手写存档 / 640×360+Nearest 整数缩放。
- core 层纯函数禁 get_node；总文档 `docs/architecture/godot4-architecture-adr.md`（含 A8 七里程碑表）。

## 素材（策略 A 开源，勿翻案；**禁** CC-BY-SA/GPL-only/LPC32/bart 城堡件；先登记后复制）
- OGA 16x16 主集（surt CC0/MrBeast/Redshrike/Antifarea CC-BY/DawnLike）+ Kenney UI 重上色；账本 3×CC0+3×CC-BY+1×OFL(Fusion Pixel)。
- 敌人头像=精灵×2 放大；faces 裁 32×32 禁缩放；头像窗 48×48；9-slice=五色板边距 8px；遗迹全用 classical_temple_tiles（选型表 design/assets/temple-tileset-selection.md）。

## 战斗数值裁定（GDD v1.1，勿改回）
- 物理 DEF 系数 1.0；**法术 1.2 勿顺手统一**；承伤 剑士4-10%/辅助8-14%/术士10-16%；逃跑 80%×3；战斗间 HP/MP 不回满；回复点不设。
- 技能：凯尔 重斩/横扫/掩护=L1/2/3；莉娜 火球L1/冰锥L2/雷爆L2；莫娜 治疗L1/群愈L2/净化L3；B1 HP50+skills_locked；敌人倍率 .tres：1.0/1.0/1.8/0.8/2.5。
- 其他：失败=读档回存档点；gold 恒 0；"立绘"=头像差分；16x18≈2.5 头身。

## 存档与传送语义（E4-S6/S7 裁决，勿翻案）
- **门控存档**：save_requested_pending 意图位（跨图传送/战后 VICTORY 置位）→ 目标图 map_ready 时 consume_save_request() 落盘；**启动装载/同图室内传送不落盘**（GDD §3.4"过传送点存，不进图即存"）；存档坐标=玩家实际落位。
- **传送正本**：teleport_catalog.gd 12 处 + teleports.json 镜像（test_e4s6 锁死）；town 室内 target=整数格（tile*16+8）；f1/f2/f3 首入 y=3/2/2，road=3.5；落位防弹回=脚底盒 ±12px 与触发区零重合；传送触发器 mask=16（玩家实体层）。
- **DEFEAT 读档**（E4-S7）：load_save() → last_loaded → 回存档点+免疫 0.5s；读档失败兜底回暂存图。
- R1/R2 已落地：INITIAL_SCENE_PATH=town；town 南门栅栏已拆（gen_town.py 正本，verify_town L125 已反转）。

## 进度（2026-09-05 M7 版，交接正本=sprint6-handoff.md + 本文件进度节）
- **⚡ 新会话续跑入口：喂 `.workbuddy/memory/sprint6-handoff.md`（M6 及之前架构/裁决）+ 本节（M7 最新进度）**。
- **M6 已收口 ✅**：T5-1/2/3/4 全完成——GUT 513/513 复核、A8 行6 勾绿、视频 #6（`evidence/m6-gameplay.avi`）、**commit e5ad6a0 + tag m6 + push 三方一致**。收口正本=evidence/m6-closeout.md（门1-5 全 PASS）。
- **M7 已完成（按提交链）**：
  - **R4/R5 缺陷修复 ✅**（`b827a63`）：road.tscn 敌人 return_map 短名→完整路径；chat_point_assembler.gd 全局 executor runner 注入（road/f2 聊天正常入口修复）。
  - **E7-S1 B1-B3 调校 ✅**（`e3612e2`）：B3 火蜥 HP55→100/ATK12→13/DEF4→8，冰晶 HP50→95/ATK11→13/DEF7→9，飞蛾 2→3（资源压力）；GDD §7 同步修订；GUT 514/514。
  - **E7-S1 B4/B5 调校 ✅**（待 commit，见工作区）：遗像守卫 HP 240→360、遗迹核心 HP 480→600（仅动 HP，其余零改动）；模拟器 `evidence/_m7_balance_sim.gd` 双路径验证（B4 NORMAL 5 回合 sweep→poison 逼治疗+净化 / B5 6 回合 charge×2）；承伤落 §3.6 分档。
  - **E7-S2 剧情统稿 ✅**（待 commit）：story_p2_ruin_enter / story_p3_boss_front / story_p3_finale 共 6 处【占位】文本润色移除，旁白括号+portrait 补齐，口吻对齐 P0/P1；GUT 514/514。
  - **E7-S3 导出包 ✅**（`9cc0de5` 导出预设入库+push）：模板 1.28GB 装至 `.godot_user_tmp/Godot/export_templates/4.7.2.stable/`；产物 `export/win/轨迹残响.exe`(109MB)+pck(3.1MB，递归 `**` glob 排除 tests/evidence/，all_resources 保动态 load)；headless 启动 EXIT=0。**剩余：非开发机实测（启动/完整通关/存档读写，需用户另一台机器）**。
  - **头像系统修复+放大（用户试玩反馈，✅ 未 commit）**：①faces 集散图真网格=顶部 144px 标题带，**人脸行 y=144/192/288/336**，旧表按 y=row×48 取图裁到标题条（"对话没头像"根因）；②头像窗 48→96（2× 整数，用户拍板推翻"48 原生"旧冻结）；③14 NPC 登记占位脸 + 71 处对话 JSON 回填 portrait。
  - **M7-R6 缺陷修复 ✅**（未 commit，派单程基岩已核查）：①**接委托接线落地**——story_quest_accept 加 phase==0 守卫 + investigate_point 启用 get_event_id() 事件路径（quest_event_id 覆盖 inv_town_02→story_quest_accept），phase>=1 回落风味文本；②ContinueHint 改 "Z/E ▼" 键位提示；③GUT **523/523**（+9 新增 test_m7r6）；④**导出包 17:40 重出**（含头像修复+本批，冒烟 EXIT=0）。
- **待回收**：用户游戏内目检（头像/告示板接线/键位提示/**R2 形象分配**）；非开发机实测。HEAD `ad2efa2`（bart 城堡件移除）为用户侧 commit。
- **M7-R7 · R2-CHARSPRITE 角色换装 ✅**（2026-09-06，未 commit，派单程基岩两程完成、主理人核查收口）：大地图色块占位→正式行走图。正本：`assets/characters/charset_frames.md`（男带 y180/女带 y306，块 x=16+48c 48×72）；`scripts/core/char_anim.gd` 单例 SpriteFrames 工厂；R4 透明转写件+R5 变体×4（先登记后复制合规）；player=四向 idle/walk 8FPS，npc=静态帧+charset_id/facing export；分配初排 `production/npc-sprite-assignment.md`（凯尔=m1，12 NPC 映射，**待用户目检定稿**）。GUT 523/523 全绿+冒烟 EXIT=0（`evidence/_m7-r7-*.log` 21:46）。
- **⚠️ 开发机真实存档污染 GUT（2026-09-05 发现）**：user:// 下有用户存档后，e5s5 d1（DEFEAT 读档链路，隐含假设无档）必失败——全量 GUT 须重定向 APPDATA 跑（干净环境 523/523 见 `evidence/_m7-r6b-gut-clean2.log`）。**待拍板**：给 e5s5 d1 等用例加存档三段协议或重定向 SaveManager 路径。
- **当前 GUT**：523/523 PASS。
- **⚠️ 工作区有未提交 M7 变更**（勿当丢失）：B4/B5 tres、test_e3s1、GDD、剧情三文件、模拟器+证据日志、tools/dev/ 导出脚本、**头像修复套件（portrait_catalog/dialogue_box/71 处对话 JSON）**、**M7-R6（investigate_point/map_events/town_map/story_quest_accept.json/dialogue_box/test_m7r6）**、**M7-R7 换装套件（char_anim.gd/R4R5 素材×5/player+npc 换装/town_map NPC_CHARSET/分配表/帧网正本/目检图）**——用户尚未发话 commit。
- **⚠️ 外部试玩者是 M7 硬阻塞**：E7-S1 三问测试需 ≥1 名外部测试者，人选/档期未定，宜早锁定（B4/B5 内部数值已就绪，就差三问反馈）。
- **仓库**：`*.avi filter=lfs` 已配；.import 大面积"改动"=CRLF 噪音（`git -c core.autocrlf=false diff` 零差异），commit 时剔除。`export/` 不入库、`export_presets.cfg` 已入库（9cc0de5，clone 后可复现导出）、`.godot_user_tmp/` 已排除。

## 环境与已踩坑（全量版见 sprint6-handoff.md §七）
- Godot=**winget 安装**：`C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`（⚠️ 2026-09-04 实测 `D:\software\Godot\` 已不存在，旧记录作废；demo dryrun 需加 `--fixed-fps 30 --quit-after 5400` unthrottled 形态）；GUT 9.7.1；headless 跑测 `MSYS2_ARG_CONV_EXCL="*"`+**Windows 反斜杠路径**。
- 通用坑：`STRETCH_KEEP_ASPECT_COVERED`；类型化数组逐元素 append；submit_command 显式传 roll；.gd 必配 .uid；-gtest 不生效；queue_free 帧末生效；Python 工具走 Git Bash（GBK）；成员 spawn 先 TeamCreate；日志分析用 Grep/Read 工具直读（Bash 大输出截断）。
- **M7 新坑**：①导出模板 `.tpz`=zip，解压须剥 `templates/` 前缀，且装到 headless 实际读取的 APPDATA（本项目重定向 `.godot_user_tmp/Godot/export_templates/4.7.2.stable/`）非 Roaming；②`exclude_filter`=逗号分隔 glob，目录递归用 `**`（`*` 不跨目录）；③导出前须先建目标目录否则报"导出路径不存在"；④PowerShell 5.1 读无 BOM 的中文 .ps1 按 GBK 破串致语法解析失败——脚本须存 UTF-8 BOM，写后先 AST `Parser::ParseFile` 验证再跑；⑤Godot 加载 .tres 时 Dictionary 键按字母序排列，ai_weights 权重抽取区间按字母序算（B5 charge ∈(0.5,0.7]）；⑥**GDScript 不支持 Python 元组赋值 `a, b = x, y`**（Parse Error），`--check-only --script` 单脚本可拦，commit 前必跑；⑦**Git Bash 传 APPDATA 用正斜杠**——反斜杠经双层转义成 `C://…//` 双斜杠 → FileAccess 写档失败 → 存档类用例集体假红。
- **Git 远程**：`git@github.com:ysyonline/cordit.git`（SSH）+代理 127.0.0.1:7892；PortableGit 丢 refs/remotes 属装饰性问题——查远程用 `git ls-remote`。
- 传送/落位修正先查"tscn 像素+verify 锚定+冒烟断言"三方正本，不一致即停。
