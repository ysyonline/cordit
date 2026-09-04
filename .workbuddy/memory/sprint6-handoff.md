# Sprint 6 会话交接文档（2026-09-04 13:10 归档）

> 用途：本文件是 Sprint 6（EPIC-6 战斗结算升级 + 逃跑失败 + 菜单三页 + 聊天存档）的**会话交接正本**。
> 新开会话时把此文件喂给主理人即可无损续跑。协作铁律：**每完成一任务停下汇报，用户确认后才进下一个；无指令不 commit。**

## 一、当前状态总览（2026-09-04 16:10 更新，T4 收口版）

**Sprint 6 进度：T7 ✅ → T2 ✅ → T3 全部四步 ✅ → T4 全部三步 ✅（S4 收口）。当前测试基线 503/503 全绿 + demo dryrun PASS + 冒烟五通道满额。下一步 = T6（文策侧剧情实写，等用户在新窗口确认开工）。**

**已提交（2026-09-04，两笔）**：`65b524b` = feat(E6-S2,S3) 战斗侧（T7+T2）；第二笔 = feat(E6-S1,S4) 菜单/装备/聊天侧（T3+T4 全部，hash 见 git log）。工作区仅剩 .import CRLF 噪音。

| # | 任务（工具编号=Story） | 状态 | 基线 | 证据 |
|---|------|------|------|------|
| T7 | E6-S2 战结（骨架/EXP 事件流/多级连升+习得/掉落） | ✅ 收口 | 415→445 | evidence/e6s2-gut-t2*.log |
| T2 | E6-S3 逃跑画面/残响中断/胜利回图自动存档 | ✅ 收口 | 445→460? | evidence/e6s3-gut-run1.log |
| T3.1 | E6-S1① 菜单壳+状态页（C 键呼出/五项导航/门闸） | ✅ 收口 | 415→460 | evidence/e6s1-gut-t31.log |
| T3.2 | E6-S1② 道具页（阶段门控过滤/使用写回/detox 地图态） | ✅ 收口 | 460→470 | evidence/e6s1-gut-t32.log |
| T3.3 | E6-S1③④ 装备页（最小 schema/换装/伤害并项/存档 v3） | ✅ 收口（9/4） | 470→482 | evidence/e6s1-gut-t33.log |
| T3.4 | E6-S1⑤ 集成验证（demo 回归+冒烟五通道） | ✅ 收口（9/4） | 482 全绿 | evidence/m6-t34-*.log 共 7 件 |
| T4.1 | E6-S4① 菜单存读档项接线 SaveManager | ✅ 收口（9/4） | 482→488 | evidence/m6-t41-gut.log |
| T4.2 | E6-S4② 队员聊天 2 段+位置触发点×2+JSON | ✅ 收口（9/4） | 488→503 | evidence/m6-t42-gut.log |
| T4.3 | E6-S4③ road 触发区扩 3×2+最终集成验证 | ✅ 收口（9/4） | 503 全绿 | evidence/m6-t43-*.log 共 7 件 |
| **T6** | **E6-S5 剧情实写第一批（P0 50 条+P1 55 条+NPC 42 条+热改跑对账）** | **⏳ 下一个（文策侧，等用户新窗口确认开工）** | — | 字数 350 封顶；文案含 T4.2 聊天 2 段【待润色】一并统稿 |
| T5 | M6 收口（A8 行 6 全绿+试玩视频 #6+tag m6） | ⏳ 排队（依赖 T6） | — | commit/tag 前须用户发话 |

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

## 五、工作区状态（2026-09-04 16:10 已提交）

- **Sprint 6 全部产物已提交两笔**：`65b524b` = feat(E6-S2,S3) 战斗侧（T7+T2）；第二笔 = feat(E6-S1,S4) 菜单/装备/聊天侧（T3+T4，含存档 v3、聊天 JSON、交接档）。HEAD 以 `git log --oneline -3` 实查为准。
- 工作区仅剩 .import 大面积"改动"=CRLF 噪音（`git -c core.autocrlf=false diff` 零差异），沿 M4/M5 惯例永远剔除。
- tag：m1=f9840ed/m2=1b61358/m3=72e1354/m4=07457c5/m5=b550126 均已推远程；**Sprint 6 两笔未推、未打 tag**（tag m6 留给 T5 收口时打）——push/tag 等用户发话。

## 六、下一步 T6（E6-S5）开工卡

**范围**（正本 = production/epics/EPIC-6.md「E6-S5 剧情实写第一批」）：
1. P0 开场+委托 50 条、P1 异变+出发 55 条主线文本实写 JSON。
2. 6 NPC 阶段增量对话 42 条实写。
3. 每拍写完进游戏跑一遍（JSON 热改兑现）；验收=条数对齐预算表 ±10% + 全程零代码改动替换占位。
4. **顺手项**：T4.2 聊天 2 段文案带【待润色】前缀（party_chat_road_01/f2_01.json），T6 统稿时一并润色并删前缀（test_a3 只断言前缀标记，不锁文案内容）。

**验收锚**：EPIC-6 E6-S5 验收条 + 字数 350 封顶/拍；GDD §3.5 预算表为正本。

**参考正本**：data/json/dialogues/ 既有对话 JSON 结构（含 T4.2 两段聊天实例）；E5-S3 NPC 事件装配；对话 GDD §3.5。
**执行者**：文策渊（design-strategist）+ 工程侧跑测配合；主理人编排。

## 七、环境坑速查（继承 Sprint 5 交接档，新增 3 条）

- Godot exe：`D:\software\Godot\Godot_v4.7.2-stable_win64.exe`（console 版同名 _console）；headless 跑测 `MSYS2_ARG_CONV_EXCL="*"` 下 `--path` 与 exe 用 Windows 反斜杠路径。
- GUT 9.7.1；`-gtest` 不生效（跑全量）；**GUT 日志 GBK**：Bash 管道提取易撞 output truncated——**改用 Grep/Read 工具直读日志文件**（`cygpath -w /tmp/xxx.log` 拿 Windows 路径），Run Summary 锚点 `^Totals` 在尾部。
- 新建 .gd 必配 .uid；queue_free 帧末生效；类型化数组逐元素 append 重建。
- 冒烟入口形态不一：e1s5 用 `headless_e1s5_wrapper.tscn`，其余用裸 .tscn。
- 全量 GUT 命令（Git Bash 项目根）：
  `MSYS2_ARG_CONV_EXCL="*" "/d/software/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\\code\\cordit" -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit > /tmp/run.log 2>&1`
- demo dryrun 命令：同上去掉 `-s ... -gexit` 改 `res://evidence/_m5_auto_demo.tscn`。
- **（9/4 新增）Game 菜单测试驱动口径**：主模态入口=confirm_current() 直驱；子模态=合成事件 `_consume_event(_down_key())` / 各 `_consume_xxx(_confirm_event())`；两者勿混用（三态导航用例曾混用+干扰代码，已重写为统一通道）。
- **（9/4 新增）WorkBuddy 内置 Git Bash 的 grep/awk 大输出会截断**——日志分析一律 Grep/Read 工具直读文件。
