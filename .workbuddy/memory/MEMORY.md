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

## 进度（2026-09-04 快照⑤ T6 收口版，交接正本=sprint6-handoff.md）
- **⚡ 新会话续跑入口：喂 `.workbuddy/memory/sprint6-handoff.md` 即可无损续接**（本节只留摘要）。
- **Sprint 6**：T7 ✅ → T2 ✅ → T3 ✅ → T4 ✅ → **T6.1-6.5 全 ✅（E6-S5 剧情实写第一批收口：P0 51 条/P1 55 条/NPC 43/聊天润色/P0 孤儿接线）**。基线 **GUT 513/513**。demo dryrun FAIL=**T6.6 待修**（对话节奏变了、demo 驱动按键步数旧的，非回归；根因+开工卡在 handoff §六）。**下一步=T6.6（工程侧 demo 校准）→ T5（M6 收口）**。待拍板：phase 2 专属档（主理人倾向接受现两档）。
- **T6 新裁决（勿翻案，详见 handoff §一）**：行宽口径 40 字/行（50 软/60 硬）；portrait 每条显式写（NPC/旁白=""）；branch_endpoint 只走 1 跳；42=总量预算口径（总 43）；set_story_phase 在事件层；T6.5 双守卫接线（not_flag story_p0_seen+phase==0+Main 场景+无存档）。
- **Sprint 6 提交**：`65b524b`(E6-S2,S3) → `08a9bc7`(E6-S1,S4) → 9/4 晚新增三笔（E6-S5 内容/T6.5 接线/docs memory，hash 以 git log 实查）。tag m1–m5 已推远程；**tag m6 留 T5**。
- **Sprint 5 ✅ tag m5=b550126**：EPIC-5 收口 GUT 286→415。M5 demo 修复（勿翻案）：①Router 覆写暂存位 ②f3 runner 直取 ③桥哨兵直通。小债：tools/README.md、sfx 钩子、手感抽查。M7（15h）：数值平衡/剧情收尾/导出包。
- **Sprint 6 计划（9/3 批准）**：T7→T2→T3→T4→T5，T6 剧情实写穿插。编号映射 T2=S3/T3=S1/T4=S4/T5=M6 收口/T6=S5/T7=S2。⚠️ GameData 加新字段须全测试文件补快照/还原对。
- **⚠️ 外部试玩者是 M7 硬阻塞**：E7-S1 三问测试需 ≥1 名外部测试者，人选/档期未定，宜早锁定。
- **仓库**：`*.avi filter=lfs` 已配；.import 大面积"改动"=CRLF 噪音（`git -c core.autocrlf=false diff` 零差异），commit 时剔除。

## 环境与已踩坑（全量版见 sprint6-handoff.md §七）
- Godot=**winget 安装**：`C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`（⚠️ 2026-09-04 实测 `D:\software\Godot\` 已不存在，旧记录作废；demo dryrun 需加 `--fixed-fps 30 --quit-after 5400` unthrottled 形态）；GUT 9.7.1；headless 跑测 `MSYS2_ARG_CONV_EXCL="*"`+**Windows 反斜杠路径**。
- 通用坑：`STRETCH_KEEP_ASPECT_COVERED`；类型化数组逐元素 append；submit_command 显式传 roll；.gd 必配 .uid；-gtest 不生效；queue_free 帧末生效；Python 工具走 Git Bash（GBK）；成员 spawn 先 TeamCreate；日志分析用 Grep/Read 工具直读（Bash 大输出截断）。
- **Git 远程**：`git@github.com:ysyonline/cordit.git`（SSH）+代理 127.0.0.1:7892；PortableGit 丢 refs/remotes 属装饰性问题——查远程用 `git ls-remote`。
- 传送/落位修正先查"tscn 像素+verify 锚定+冒烟断言"三方正本，不一致即停。
