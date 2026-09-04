# Sprint 6 会话交接文档（2026-09-04 23:00 归档，T6 收口版）

> 用途：本文件是 Sprint 6 的**会话交接正本**。新开会话时把此文件喂给主理人即可无损续跑。
> 协作铁律：**每完成一任务停下汇报，用户确认后才进下一个；无指令不 commit。**

## 一、当前状态总览（2026-09-04 23:00 更新，T6 五件收口版）

**Sprint 6 进度：T7 ✅ → T2 ✅ → T3 ✅ → T4 ✅ → T6.1-6.5 全 ✅。当前测试基线 GUT 513/513（503 基线 + T6.5 新增 10 用例，Totals 实锤）。demo dryrun FAIL（T6.6 待修，见开工卡）。下一步 = T6.6（工程侧 demo 校准）→ T5（M6 收口）。**

**E6-S5（剧情实写第一批）已全部完成**：P0 51 条 / P1 55 条 / NPC 总量 43（预算 42±10% 内）/ 聊天两段润色 / P0 孤儿脚本接线。全部文本零产品代码改动（测试适配除外）。

| # | 任务 | 状态 | 基线 | 证据/产物 |
|---|------|------|------|------|
| T7/T2/T3/T4 | 前四个 Story | ✅ 已提交（65b524b/08a9bc7） | — | 见 git log |
| T6.1 | P0 主线 51 条（2 占位→实写） | ✅ 用户放行 | — | story_p0_intro.json |
| T6.2 | P1 主线 55 条（road 第一次残响兑现） | ✅ 用户认收 | — | story_p1_dispatch.json |
| T6.3 | NPC 总量 43（新增 20，零孤儿） | ✅ ⚠️phase2 档位待拍板 | — | dlg_npc_* 16 文件 |
| T6.4 | 聊天润色+test_a3 适配 | ✅ | — | party_chat_*.json + test_m6t42.gd |
| T6.5 | P0 孤儿脚本接线（事件+触发器+双守卫） | ✅ | 503→513 | evidence/t65-* 4 件 |
| **T6.6** | **demo dryrun 驱动重校准** | **⏳ 下一个（工程侧）** | — | 见 §六开工卡 |
| T5 | M6 收口（A8 行6 全绿+视频#6+tag m6） | ⏳ 排队（依赖 T6.6） | — | commit/tag 前须用户发话 |

### 本窗口用户裁决记录（勿翻案）
1. **g4「我们接了」保持原样**（P0 口头接单 vs GDD §3.3 冲突的折中已获认可；phase 语义由 P1 末尾 set_story_phase 1 把关）。
2. **遗迹方位**：flavor_inv_town_02「北部」→「镇外」已修；全文零「北」字（lint 实测）。
3. **P0 孤儿脚本立项 T6.5** → 程基岩直接做路线收口。
4. **6 席阶段 NPC = GDD §3.3 版**（菲奥拉/客栈老板/追鸡孩子/铁匠/守卫/旅人），build-sheet 版作废。
5. **P0/P1 语气均已放行**。
6. **待拍板**：① T6.6 派工 ② phase 2 专属档要不要加（现 0/1 两档，加"2"档=6 条新文案+events 改动，主理人倾向接受两档）。

### 本 Sprint 新增关键裁决（T6 五件，勿翻案）
- **UI 行宽口径**：`design/ui/` §2.1 = 484px÷12px ≈ **40 字/行**；写作纪律=50 字软上限/60 硬红线；P0-P1 全部条目单行内（最长 39 字）。
- **portrait 显式纪律**：dialogue_runner.gd 的 portrait 缺省沿用上一条 → **每条必须显式写 portrait**（三人 kyle_/rina_/mona_* 差分，NPC/旁白一律 "" 走头像窗隐藏降级）。P0/P1/T6.3 新写条目全覆盖；既有 01/04/13 日常档无该字段（无害，未动）。
- **branch_endpoint 只走 1 跳**（max_steps=2 含起点）→ 分支尾巴只能 1 条即汇合。
- **42 条=总量预算口径**：GDD §3.5 的 NPC 块预算是文本总量（现有 23 正稿+新增 20=43），非新增 42。
- **set_story_phase 在事件层**（events/story_quest_accept.json：dialogue→set_story_phase(1)），对话 JSON 内无 phase 字段是正常的。
- **T6.5 接线方案**：新事件 `data/json/events/story_intro.json`（not_flag story_p0_seen 一次性 + phase==0 + 双守卫 current_scene=="Main" && !has_save()）+ town.tscn 出生格 (192,640) 锚点 + town_map.gd +77 行程序化装配（A7 薄壳纪律，mask=16）；save_point 语义自洽=executor 置意图位→首次出镇 map_ready 落盘（出镇前退出=无档重演 P0）。
- **demo FAIL 根因（勿误判为回归）**：文策 T6.3/T6.4 改变对话条数节奏（innkeeper_p12 1→3 条等），demo 自动驱动按键步数按旧节奏写死 → 收束超时挂到第 6 幕 → 第 8 幕 phase=3 时序错位（终态 phase=2≠3）。非 T6.5 引入（基线对照排除）、非内容质量问题。修复=T6.6 校准驱动。

## 二、本 Sprint 关键裁决（勿翻案）

### 全局三项（用户拍板）
1. **菜单呼出键 = C 键**（physical C=67）；C 键单向语义：关闭态开菜单、开启态只吞不关（防列表深处 C 弹穿回地图）；关闭统一 X/Esc 逐层退出。
2. **装备系统 = 最小 schema 重建**（弃旧计划）：weapon/armor 双槽位 + atk_bonus/def_bonus，`validate()` 交叉约束（武器不带 DEF/防具不带 ATK/加成非负且不同时为 0）。
3. **装备来源 = 初始背包直塞 2 件**：iron_sword(ATK+3) / leather_armor(DEF+2)；切片无商店。

### 菜单正本 `scripts/ui/menu_panel.gd`（~700 行，六态状态机）
- 门闸三条（switching/战斗图/is_idle）；模态吞键；玩家锁走 "player" 组；置灰唯一授权项=读档 has_save()；lina 头像=rina_normal（素材拼写如此）；**九宫格内容节点必须在 build() 之后加**（_rebuild 清自身子节点坑）。
- `enum Mode { MAIN, ITEM_LIST, ITEM_TARGET, EQUIP_CHAR, EQUIP_SLOT, EQUIP_LIST }`，`_consume_event` 六路分派；**get_mode() 必须六态全量映射**（首轮漏装备三态漏报 "main" 假挂 6 断言的教训）。
- 冻结坐标：指令窗 (16,16,96,136)、状态面板 (128,16,496,328)、道具/装备子窗 (144,32,232,208) 同尺寸互斥、8 行列表、描述两行、切分边距 8px。
- confirm_current() 主模态专用入口（status 刷新/item 开列表/equip 进角色态/**save/load 仍是 print 占位——T4 接线点唯一在此 match 内**）；子模态确认一律走事件通道。
- 道具页：过滤=usable_in_map()+count>0（行序=背包插入序）；**detox 地图态=显示/可用/扣库存但无数值变化**；死亡不作用药门禁；HP/MP 写回 mini 钳上限+扣库存减一不 erase；用药后留目标态。
- 装备页：角色态=角色块高亮当光标（不叠死亡置灰）；列表=槽位过滤+卸下行置底（当前已装不带卸下行）；`_apply_equipment_change()` 唯一写盘点（三向库存搬移：旧装回池→新装出池写字段→卸下清字段）。

### 装备数值口径
- **并项同源原则**：`BattleUnits.apply_equipment(stats, weapon_id, armor_id)` 是唯一并项函数——状态页（refresh_status_page）与战斗侧（build_party_unit 可选 equip 参，缺省不叠加旧调用点零改动）共用，面板数字=战斗公式输入。
- 一件装备 ≈ 一级成长（铁剑 ATK+3=凯尔 per_level.atk；皮甲 DEF+2=三人 per_level.def）。
- 持有池 `GameData.owned_equipment: Array[String]`（与道具背包分离，无数量语义）；装上出池写字段/卸下回池清字段。
- **存档 v2→v3**：SCHEMA_VERSION=3（11 字段，顶层 equipment 池 + party 条目内嵌 weapon_id/armor_id）；`_migrate` v<3 分支补初始 2 件；`_deserialize_party` 构造器 10 参 get 兜底空串。

### E6-S2/S3（T7/T2）要点
- 战结：EXP 事件流+多级连升+习得行（skills_up_to 差集）+掉落（give_item 同入口）；结算画面揭示器（dwell 两档/手动步进/finish 跳过）；升级/掉落经 handler 写回 GameData。
- 逃/败：ESCAPE="成功撤退"+敌人保留（cleared 集不登记）；DEFEAT="残响中断"+读档回存档点；**VICTORY 置位 save_requested_pending（生产端）→ map_ready 消费（e4s6 已有）**；逃跑三角色各 80%（用户产品裁定）。

### E6-S4（T4 三步）要点（9/4 新增，勿翻案）
- **菜单手动存=即时落盘**（`_confirm_save_item` → SaveManager.save(map,pos)），不碰 save_requested_pending 门控（手动/自动通道隔离）；坐标="player" 组动态解析（player.tscn 已加组）；地图名=SceneRouter 路径经 TeleportCatalog.MAP_SCENE_PATHS 反查短名（空兜底 "town"）；写盘失败 push_warning 菜单保持打开。
- **菜单读档复用 E4-S7 DEFEAT 链**：`_confirm_load_item` → load_save → `EventBus.battle_finished.emit({outcome:"DEFEAT",party_state:[]})` → 既有回置+0.5s 免疫；损坏档 GameData 不动。
- **聊天触发=位置触发**（验收条 EPIC-6.md:36 正本裁定，非存读档触发）：段① road (35,31) phase>=1、段② ruins_f2 (23,8) phase>=2；一次性=E5 既有 not_flag+set_flag（与宝箱同构），flag 走 GameData.flags（v3 既有字段，SaveManager 零改动）；road 命中区 3×2、f2 2×2（`size_tiles` 目录字段，`DEFAULT_SIZE_TILES` 兜底，锚点=tile×16+8 中心不变）。
- 装配=`scripts/events/chat_point_assembler.gd` 目录驱动多图（克隆 Boss 锚点薄壳模式）；文案带【待润色】前缀待 T6 统稿。
- 教训：demo dryrun 与冒烟**勿并行**（演示档落盘污染 smk_e1s3 user:// 纯净检查，重跑已证）。

## 三、T3.3 首轮 11 挂教训（新会话必读，勿重蹈）

1. **get_mode() 查询口漏映射新枚举态**——状态机对但查询口漏报回 "main"；新增 Mode 枚举值时查询口必须同步全量映射。
2. **build_enemy_unit 收"敌人 id"（moth）非"编组 id"（b1_moth）**——build_encounter 才收编组 id。
3. **数值锚以 .tres 真相为准**——莉娜 Lv1 DEF6（base_def=6）不是 12。
4. **⚠️ 测试套件间 GameData 污染外溢链**：e4s1 test_17 写 inventory 但基线还原函数漏还原 → 外溢 e4s5×3/e5s2×1 连环假挂。**修复=源头补快照/还原，下游零改动回绿**。⚠️ 永久纪律：GameData 加新字段时，grep 所有 before_all 快照文件补备份/还原对。
5. **schema bump 后锚联动**：e4s8 version 字面量 2→3（两处）、e3s1 scripts/data/ .gd 计数 10→11。

## 四、T3.4 集成验证记录（2026-09-04，S1 收口证据）

- **demo dryrun PASS**：`_m5_auto_demo` headless 直跑 8 幕全链路（town→road→f1→f2→f3→Boss VICTORY→桥续行→phase3→save_point）在存档 v3+菜单/装备改动下零破坏；终态指纹 map=ruins_f3/(320,40)/phase=3 吻合。
- **冒烟五通道满额**：smk 4/4、e1s4 3/3、e1s5 4/4（wrapper 入口）、e1s6 5/5、smk_e1s3 5/5，退出码全 0。
- **GUT 482/482**（28 脚本/8176 断言/29s）。
- 证据 7 件：`evidence/m6-t34-{demo-dryrun,gut-full,smoke-smk,smoke-e1s4,smoke-e1s5,smoke-e1s6,smoke-smk_e1s3}.log`。

## 五、工作区状态（2026-09-04 23:00 收口提交版）

- **9/4 全天提交史**：`65b524b`=feat(E6-S2,S3) 战斗侧 → `08a9bc7`=feat(E6-S1,S4) 菜单/装备/聊天侧 → `39c47af` 等记忆 docs 笔 → 17:20 已 push（b550126..39c47af 验证过）。
- **23:00 收口新增三笔**（T6 五件产物，本窗口用户授权"该提交的提交"）：① feat(E6-S5) 文策内容侧（story_p0/p1、dlg_npc_*×16、party_chat×2、flavor 方位修正、test_m6t42 适配）② feat(T6.5) 工程接线侧（story_intro.json、town.tscn、town_map.gd、test_t65、evidence/t65-*×4）③ docs(memory) 交接档更新。具体 hash 以 `git log --oneline -6` 实查为准。
- 工作区仅剩 .import 大面积"改动"=CRLF 噪音（`git -c core.autocrlf=false diff` 零差异），沿惯例永远剔除。
- tag：m1–m5 均已推远程；**tag m6 留给 T5 收口时打**。

## 六、下一步 T6.6（demo dryrun 驱动重校准）开工卡

**背景**：E6-S5 剧情实写改变了对话条数与节奏（innkeeper_p12 1→3 条、P0 2→51 条等），`evidence/_m5_auto_demo.tscn` 的自动驱动按键步数/等待窗按旧节奏写死 → npc_innkeeper_p12 收束超时（demo 中盘切入 phase=2，town 命中 p12 档）挂到第 6 幕 force_idle → 第 8 幕 set_story_phase(3) 时序错位，终态 FAIL（phase=2≠3，存档指纹同）。GUT 513/513 全绿，**仅 demo 一项待修，是 T5（M6 收口）的硬阻塞**。

**范围**：
1. 校准 `_m5_auto_demo` 驱动（等待窗/收束判定），适配新对话节奏——优先找「按对话实际条数驱动」的通用解，不要逐幕硬编码步数。
2. 复验终态指纹：map=ruins_f3 / (320,40) / phase=3 全吻合。
3. 顺手复验冒烟五通道（demo 与冒烟**勿并行**，演示档落盘污染 user:// 的教训 9/4 刚踩过）。
4. 证据落 evidence/，命名带 t66 前缀。

**执行者**：程基岩（engineering-lead）。**裁决前置**：派工前等用户发话；若发现需要动 GameData/存档语义，停下回传 A/B/C。

**T6.6 收口后 → T5**：A8 行 6 全绿打勾 + 试玩视频 #6（M6 试玩拍聊天用 main.tscn 正常入口）+ git tag `m6` + push，等用户发话。

## 七、环境坑速查（继承 Sprint 5 交接档，新增 3 条）

- Godot exe：**winget 路径 `C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`（⚠️ 9/4 晚实测 `D:\software\Godot\` 已不存在，旧路径作废）**；headless 跑测 `MSYS2_ARG_CONV_EXCL="*"` 下 `--path` 与 exe 用 Windows 反斜杠路径。
- GUT 9.7.1；`-gtest` 不生效（跑全量）；**GUT 日志 GBK**：Bash 管道提取易撞 output truncated——**改用 Grep/Read 工具直读日志文件**（`cygpath -w /tmp/xxx.log` 拿 Windows 路径），Run Summary 锚点 `^Totals` 在尾部。
- 新建 .gd 必配 .uid；queue_free 帧末生效；类型化数组逐元素 append 重建。
- 冒烟入口形态不一：e1s5 用 `headless_e1s5_wrapper.tscn`，其余用裸 .tscn。
- 全量 GUT 命令（Git Bash 项目根）：
  `MSYS2_ARG_CONV_EXCL="*" "/c/Users/weixufeng/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\\code\\cordit" -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit > /tmp/run.log 2>&1`
- demo dryrun 命令：同上去掉 `-s ... -gexit` 改 `res://evidence/_m5_auto_demo.tscn`，**加 `--fixed-fps 30 --quit-after 5400`（unthrottled 形态）**。
- **（9/4 新增）Game 菜单测试驱动口径**：主模态入口=confirm_current() 直驱；子模态=合成事件 `_consume_event(_down_key())` / 各 `_consume_xxx(_confirm_event())`；两者勿混用（三态导航用例曾混用+干扰代码，已重写为统一通道）。
- **（9/4 新增）WorkBuddy 内置 Git Bash 的 grep/awk 大输出会截断**——日志分析一律 Grep/Read 工具直读文件。
