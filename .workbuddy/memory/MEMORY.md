# MEMORY.md — 《轨迹残响》工程记忆（cordit）

> 主理人：游承峰（游戏开发工作室专家团）。类空之轨迹 2.5D JRPG 垂直切片（边陲小镇+三层遗迹+三人小队）。
> 用户=Web 前端、业余周 5-10h；协作约定：中文输出（含代码注释/文档）、结构化诊断表达、重大决策用户拍板、无指令不 commit。

## 冻结架构（勿翻案）
- Godot 4.7.2 + GDScript；4 Autoload：GameData / EventBus / SceneRouter / SaveManager。
- 4 ADR：GDScript 渐进类型 / JSON(内容)+Resource(数值) / JSON 手写存档 / 640×360+Nearest+整数缩放（ADR-4）。
- core 层纯函数禁 get_node；总文档 `docs/architecture/godot4-architecture-adr.md`（含 A8 七里程碑表）。

## 素材（策略 A 开源，零采购，2026-08-29 拍板）
- OGA 16x16 主集：surt tileset(CC0) + MrBeast Sewer/Cave(CC-BY 3.0) + Redshrike 敌人(CC-BY 3.0) + Antifarea 16x18 角色/48×48 faces(CC-BY 3.0)；补充 DawnLike(CC-BY 4.0)；UI=Kenney 重上色(CC0)。
- 许可账本 3×CC0 + 3×CC-BY + 1×OFL（Fusion Pixel = OFL 1.1）；**禁** CC-BY-SA / GPL-only / LPC 32×32 / bart 城堡件；资产先登记后复制。
- 敌人头像=战斗精灵 ×2 整数放大；faces 裁 32×32 禁缩放；对话框头像窗 48×48（64×64 口径废弃）；9-slice 窗体=自制五色板两套、切分边距 8px。
- **遗迹选型已定（2026-08-30）**：f1/f2/f3 全用 classical_temple_tiles 单图集（CC0），**无需 D1 Sewer/D2 Cave**（触发条件=独立洞穴关卡才登记）；选型表 `design/assets/temple-tileset-selection.md`。

## 战斗数值裁定（GDD v1.1，2026-08-30，勿改回）
- 物理 DEF 系数=1.0（1.5 证伪：三人承伤区间交集为空）；**法术系数 1.2 不动，勿顺手统一**。
- 承伤分档：剑士 4-10% / 辅助 8-14% / 术士 10-16%。
- 技能：凯尔 重斩Lv1/横扫Lv2/掩护Lv3；莉娜 火球Lv1/冰锥Lv2/雷爆Lv2；莫娜 治疗Lv1/群愈Lv2/净化Lv3。
- B1 飞蛾 HP50 + skills_locked（"与"关系）；逃跑三角色各 80%（用户产品裁定不改）；战斗间 HP/MP 不回满（I6）；**回复点已裁：不设**（I6 维持，f1 入口预留 2×2 空地兜底）。
- 敌人行为倍率入 .tres 单例：攻击1.0/毒击1.0/重击1.8/群击0.8/蓄力释放2.5。

## 其他裁决
- 失败=读档回进图存档点；gold_gained 切片内恒 0；HD-2D 降级后期可选；"立绘"=头像差分；比例基准 16x18≈2.5 头身。

## 进度（2026-08-31 01:55 快照，会话收尾）
- **M1 ✅ tag m1｜M2 ✅ tag m2｜M3 ✅ tag m3 五门全绿**（D3 缺陷已修 `2242b99`；视频#3 重录入库）。
- **Sprint 4（EPIC-4）S0~S5 + S8 ✅ 全部收口**：`db8a6be`(S0~S2)→`021ffb7`(S3)→`5cbc36b`(S4)→`5c7ac2b`(S5 宝箱/调查 27 点位+chests_opened 闭环)→`c1c4562`(S8 inventory 入档 schema v1→2)。
- **测试基线 187→266/266 全绿**：S8 关键实现=SCHEMA 十字段+_migrate v<2 分支（SCHEMA 默认兜底）+JSON float→int 逐键转换；ADR-3 正文已同步 v2 十字段。
- **剩 S6 传送+自动存档 2.5h → S7 失败读档 1h = 3.5h 即达 M4 门**；M4 收口仪式=用户本机试玩+视频#4+tag m4。
- S5 拍板项④落地形态：硬编码模板 + point_catalog.gd 正本 + data/json/events/ JSON 镜像（test 同构锁死），E5-S2 加载器就绪后回迁。
- 遗留小债：tools/README.md 未登记 gen/verify 工具链（S6 前补）；sfx 为 E6 预留钩子；SMK-12 静态记录"SCHEMA_VERSION=1"是历史留痕不触发红灯。
- 协作模式：团队 cordit-sprint4-5235（会话结束自动清理，下次重建），程基岩（engineering-lead）续用效率高；主理人独立复验制（不采信自报全部亲跑）+ 用户拍板收口 commit。

## 环境与已踩坑
- Godot exe（WinGet，Glob 搜不到，用全路径）：`C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- GUT 实装 **9.7.1**（9.7.0 起兼容 4.7，非旧计划的 9.3.x）；headless 跑测：`MSYS2_ARG_CONV_EXCL="*"` 下 `--path` 与 exe 必须用 **Windows 反斜杠路径**（MSYS 不再转换），见 `tests/README.md` §2.4。
- TextureRect 截图铺满用 `STRETCH_KEEP_ASPECT_COVERED`（**不存在** `STRETCH_COVER`，会 Compile Error 并级联拖垮依赖方）。
- 类型化数组 `Array[Dictionary]` 赋值：`as` 对非类型化源转换不生效，须**逐元素 append 重建**。
- `submit_command(actor, cmd, variance=1.0, roll=-1.0)`：确定性结果须显式传 roll，默认走 randf()。
- `.gitignore` `!evidence/*.log` 已白名单，证据日志正常 `git add` 即可，无需 `-f`。
- **tile-inspect 管线**：`.rgba` 缓存须经 `decode_png.py` 生成（应用 tRNS 透明），旧缓存未应用 tRNS 会把透明贴片误判为白底实体——像素分析前必查。town=ctype6 直色，temple/forest=ctype3 索引色。
- **Python 工具控制台编码**：verify/gen 系脚本在 PowerShell 下因 GBK 打不出"✅"抛 UnicodeEncodeError（断言已跑完才崩，非产物问题）——统一 Git Bash 跑或设 `PYTHONIOENCODING=utf-8`。
- **成员 spawn 流程**：先 TeamCreate 再 Agent(team_name=...)，直接 spawn 报 "No active team found"；成员会话可能 429 限流中断（exit 前检查回传完整性，收尾缺口主理人可代笔，沿 E4-S2/S3 先例）。
- **Git 远程同步（2026-08-31 落定）**：origin=`git@github.com:ysyonline/cordit.git`（SSH，密钥永不过期）；网络走 `~/.gitconfig` 的 `http.https://github.com.proxy=127.0.0.1:7892` + `~/.ssh/config`（ssh.github.com:443，connect.exe 用 D:/software/Git 全路径，WorkBuddy 内置 Git Bash 无此工具）。`.workbuddy/memory/` 已入库随仓库同步。**坑**：WorkBuddy 内置 PortableGit 的 fetch/push 会静默丢弃 `refs/remotes/`（status 显示 [gone]，属装饰性问题，远程与本地 main 不受影响）；会话内查远程用 `git ls-remote`，或用 `/d/software/Git/cmd/git.exe`（v2.41.0，正常）。
