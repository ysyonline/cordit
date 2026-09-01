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

## 存档与传送语义（E4-S6/S7 裁决，2026-08-31，勿翻案）
- **门控存档**：SaveManager.save_requested_pending 意图位——跨图传送受理/战后 VICTORY 置位 → 目标图 map_ready 时 consume_save_request() 消费落盘；**启动装载/同图室内传送不落盘**（防启动即覆盖既有存档；GDD §3.4"过传送点存，不进图即存"原文口径）。胜利即存=§3.2 防复活；存档坐标=玩家实际落位（非默认出生位）。
- **传送正本**：teleport_catalog.gd 12 处（town 室内 4 同图 + 跨图 8）+ data/json/events/teleports.json 同构镜像（test_e4s6 锁死）；f3 南门 (19-20,0) 双用途（入口+返程）；落位防弹回口径=落位脚底盒 ±12px 与触发区零重合。
- ** town 室内同图传送 target=整数格**（tile*16+8 格中心，旧 @export 口径；半格 .5 是缺陷不要复辟）；f1/f2/f3 首入 to_spawn y=3/2/2（verify_ruins 锚定 spawn_px），road=3.5。
- **碰撞层**：传送触发器 collision_layer=0 / mask=16（玩家实体层）——town 旧四门 mask=1 在 E2-S2 玩家改 layer=16 后静默失效，已修，test_e4s6 test_12 锁定。
- **DEFEAT 读档**（E4-S7）：load_save() → last_loaded.map/position → MAP_SCENE_PATHS 短名→路径 → 回置存档点+免疫 0.5s；GameData 随 _restore 整体回滚；读档失败兜底回暂存图+告警。
- **R2 已落地**：INITIAL_SCENE_PATH=town.tscn；R1 已落地：town 南门栅栏已拆（gen_town.py 正本路径，verify_town L125 断言已反转）。

## 进度（2026-08-31 17:45 快照，M4 收口完成）
- **M4 ✅ tag m4（07457c5）**：四项委托全绿——①试玩代测（7 幕确定性演示 headless 全绿）②视频#4（m4-gameplay.avi 89.3MB/64s 入库）③冒烟五通道全绿④commit+tag。验收档 `evidence/m4-acceptance.md`。
- **tag 真相（重要）**：仓库 tag 列表曾经为空——MEMORY 旧记载"m1/m2/m3 已打标"不实（历史会话只记未打）。**2026-09-01 用户拍板补齐：m1=f9840ed、m2=1b61358、m3=72e1354（+m4=07457c5），四 tag 已全部推送远程**。
- **Sprint 4（EPIC-4）全部收口**：`db8a6be`(S0~S2)→`021ffb7`(S3)→`5cbc36b`(S4)→`5c7ac2b`(S5)→`c1c4562`(S8)→`07457c5`(S6+S7+M4)。
- **测试基线 266→286/286 全绿**（e4s6 新增 19 条 + e2s4 扩 2 条净增 1）；证据 `evidence/e4s6-gut-full.log` + `evidence/m4-acceptance.md`；冒烟五通道（e1s4 3/3、e1s5 4/4、e1s6 5/5、smk 4/4、smk-e1s3 5/5）EXIT 全 0。
- **仓库体积**：视频 89.3MB 直接入库后 size-pack 11→~100MiB，后续里程碑视频可评估 Git LFS。
- 遗留小债：tools/README.md 未登记 gen/verify 工具链；sfx 为 E6 预留钩子；人眼手感抽查待用户。
- 协作模式：主理人独立实现制（程基岩代理 429 停摆后本会话接手）；用户委托制收口（本次四项全权委托已闭环）。

## 环境与已踩坑
- Godot exe（**D:\software\Godot\Godot_v4.7.2-stable_win64.exe**，本账户 user3667 自装解压版；控制台版同名 _console；旧 WinGet 路径属 weixufeng 账户已废弃）
- GUT 实装 **9.7.1**（9.7.0 起兼容 4.7，非旧计划的 9.3.x）；headless 跑测：`MSYS2_ARG_CONV_EXCL="*"` 下 `--path` 与 exe 必须用 **Windows 反斜杠路径**（MSYS 不再转换），见 `tests/README.md` §2.4。
- TextureRect 截图铺满用 `STRETCH_KEEP_ASPECT_COVERED`（**不存在** `STRETCH_COVER`，会 Compile Error 并级联拖垮依赖方）。
- 类型化数组 `Array[Dictionary]` 赋值：`as` 对非类型化源转换不生效，须**逐元素 append 重建**。
- `submit_command(actor, cmd, variance=1.0, roll=-1.0)`：确定性结果须显式传 roll，默认走 randf()。
- `.gitignore` `!evidence/*.log` 已白名单，证据日志正常 `git add` 即可，无需 `-f`。
- **tile-inspect 管线**：`.rgba` 缓存须经 `decode_png.py` 生成（应用 tRNS 透明），旧缓存未应用 tRNS 会把透明贴片误判为白底实体——像素分析前必查。town=ctype6 直色，temple/forest=ctype3 索引色。
- **Python 工具控制台编码**：verify/gen 系脚本在 PowerShell 下因 GBK 打不出"✅"抛 UnicodeEncodeError（断言已跑完才崩，非产物问题）——统一 Git Bash 跑或设 `PYTHONIOENCODING=utf-8`。
- **成员 spawn 流程**：先 TeamCreate 再 Agent(team_name=...)，直接 spawn 报 "No active team found"；成员会话可能 429 限流中断（exit 前检查回传完整性，收尾缺口主理人可代笔，沿 E4-S2/S3 先例）。
- **Git 远程同步（2026-08-31 落定）**：origin=`git@github.com:ysyonline/cordit.git`（SSH，密钥永不过期）；网络走 `~/.gitconfig` 的 `http.https://github.com.proxy=127.0.0.1:7892` + `~/.ssh/config`（ssh.github.com:443，connect.exe 用 D:/software/Git 全路径，WorkBuddy 内置 Git Bash 无此工具）。`.workbuddy/memory/` 已入库随仓库同步。**坑**：WorkBuddy 内置 PortableGit 的 fetch/push 会静默丢弃 `refs/remotes/`（status 显示 [gone]，属装饰性问题，远程与本地 main 不受影响）；会话内查远程用 `git ls-remote`，或用 `/d/software/Git/cmd/git.exe`（v2.41.0，正常）。
- **GUT 新建 .gd 必须配 .uid 文件**（uid://xxx 一行），否则 sanity 收集哨兵报 "Nonexistent function 'new' in base GDScript"（无 uid 的脚本 load 后 new 失败）。生成后跑一次 Godot 让其登记。
- **GUT -gtest 参数在此环境不生效**（仍跑全量）；筛失败用 `> /tmp/x.log 2>&1` 后 grep "[Failed]"。
- **queue_free 帧末生效**：GUT 断言"旧节点已退役"不能同帧断言其不存在，改按装配产物计数/命名/脚本判定。
- **无 uid 的目录初稿偏差教训**：传送/落位类数据修正时先查"旧 tscn 像素 + verify_*.py 锚定值 + 冒烟断言值"三方正本，任何一方不一致即停下裁决，不要沿用会话内记忆坐标。
