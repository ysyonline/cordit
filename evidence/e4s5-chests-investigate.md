# E4-S5 宝箱/调查事件模板（27 点位 + 存档闭环）—— 验证证据

> 角色：engineering-lead 程基岩 · Sprint 4 · P0
> 引擎：Godot 4.7.2 stable（winget 包）+ GUT 9.7.1 · 测试基线 240 → **258**（全绿）
> 需求依据：探索 GDD §3.3（事件模板）/ §3.1（密度总表）/ §3.4（spawn 安全区）、EPIC-4 E4-S5 任务卡、拍板项④（硬编码先行 + 数据结构化落盘）

---

## 1. 验收结论

| 验收标准 | 结果 | 证据 |
|---|---|---|
| ① 27 个内容点位全部可交互（9 宝箱 + 18 调查） | ✅ | test_03~07 装配计数、test_08 锚点同位、test_18 真实射线端到端 |
| ② 存档→读档→已开宝箱不重开（GUT 断言） | ✅ | test_12：存→扰动→读→chests_opened 无损回灌→再交互道具量不变 |
| ③ 全量回归零破坏 | ✅ | `evidence/e4s5-gut-s5.log`：**258/258 PASS，exit 0**（基线 240/240 见 `evidence/e4s5-gut-baseline.log`） |

---

## 2. 验证命令与日志

```
# 全量回归（tests/README.md §2.4 口径，Git Bash）
MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit
```

- 本机实际可执行文件（PATH 无 Godot，winget 安装位）：
  `C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- 最终日志：`evidence/e4s5-gut-s5.log`
  - Scripts 18 / **Tests 258 / Passing 258** / Asserts 6624 / `All tests passed!` / **exit 0**
- 基线日志：`evidence/e4s5-gut-baseline.log`（240/240，改造前）

> 环境坑（复述 tests/README.md）：Git Bash 必须带 `MSYS2_ARG_CONV_EXCL="*"`，否则 `res://` 被 MSYS 改写成 `res:/` 导致 GUT 加载失败。另：GUT 单文件用 `-gtest=<res路径>`（`-gdir` 只收目录）。

---

## 3. 文件变更清单

### 3.1 新增（脚本）
| 文件 | 内容 |
|---|---|
| `scripts/events/chest.gd` | 宝箱事件实体模板：`on_interact()` 四步闭环（①play_sfx 钩子 → ②give_item → ③提示对话 → ④set_flag 登记 `chests_opened`）；已开再交互只重播提示不重复给道具（not_flag 等价判定）；`get_npc_id()`/`get_event_id()` 协议口 |
| `scripts/events/investigate_point.gd` | 调查点实体模板：`on_interact()` 仅开演 flavor 对话，零状态写入（可无限重复交互） |
| `scripts/events/point_catalog.gd` | 27 点位结构化数据正本（tile 坐标 + 内容 + tone），含 `SPAWNS` 表与锚点/实体命名约定函数 |
| `scripts/events/map_events.gd` | 装配器：`assemble(map_root, map_name)` → 按目录在五图生成实体（程序化 StaticBody2D + 16×16 交互体，层 2/掩码 0，offset (0,-7)/(0,-6)），返回 `{"chests": [], "investigates": []}` |

### 3.2 新增（数据）
| 文件 | 内容 |
|---|---|
| `data/json/events/chests.json` | 9 宝箱结构化镜像（id/map/tile/item_id），E5 回迁数据 |
| `data/json/events/investigates.json` | 18 调查点结构化镜像（id/map/tile/tone），E5 回迁数据 |
| `data/json/dialogues/dlg_chest_{town_01,road_01,road_02,f1_01,f1_02,f1_03,f2_01,f2_02,f3_01}.json` | 9 个开箱获得提示对话（一箱一文件，文件名=对话 id，E1-S6 runner 契约） |
| `data/json/dialogues/flavor_inv_{town_01..06, road_01..03, f1_01..04, f2_01..03, f3_01..02}.json` | 18 个调查文案对话，≥20 字最终文案；氛围向 9 / 趣味向 9 |

### 3.3 修改
| 文件 | 变更 |
|---|---|
| `scripts/events/interaction_controller.gd` | `_try_interact()` 协议分派：父链找协议持有者后，`has_method("on_interact")` → 实体自治调用（宝箱/调查）；否则走既有 NPC 对话路径（**NPC 行为零变更**）。`_unhandled_input()` 补 null-runner 守卫 |
| `scripts/maps/{town,road,ruins_f1,ruins_f2,ruins_f3}_map.gd` | 各加 `content_points: Dictionary`，`_ready()` 尾部调 `MapEvents.assemble(self, "<map_name>")` |
| `tests/gut/test_e4s5.gd` | 新增 18 用例（A~J 九组覆盖，见 §5） |

**未触碰**：`npc.gd`/NPC 场景、`save_manager.gd`（ADR-3 schema 未动）、E4-S2/S3 地图场景（锚点/碰撞原样）。

---

## 4. 27 点位清单（tile 坐标，装配转像素 tile×16+8）

### 宝箱 9（town 1 / road 2 / f1 3 / f2 2 / f3 1）
| id | 图 | tile | 内容 | 选点意图（GDD §3.3 风险自选） |
|---|---|---|---|---|
| chest_town_01 | town | (59,22) | potion_m ×1 | 市场街尽头，安全图无守敌 |
| chest_road_01 | road | (9,16) | potion_s ×2 | moth 巡逻线南侧支路，绕过即拿 |
| chest_road_02 | road | (36,62) | antidote ×1 | 南门西侧断桥死角，beetle_01 巡逻线边缘 |
| chest_f1_01 | ruins_f1 | (4,20) | ether_s ×1 | 西翼死路，salamander 视野外 |
| chest_f1_02 | ruins_f1 | (50,9) | potion_m ×1 | 东北高台，crystal 巡逻线背后 |
| chest_f1_03 | ruins_f1 | (24,39) | potion_s ×1 | 中部石阵，两敌巡逻圈间凹地 |
| chest_f2_01 | ruins_f2 | (8,20) | potion_l ×1 | 西厅，guardian 视野圈外绕行 |
| chest_f2_02 | ruins_f2 | (38,27) | potion_m ×1 | 东侧支路，引开精英的时机奖励 |
| chest_f3_01 | ruins_f3 | (21,35) | potion_l ×1 | Boss 门左侧凹格，战前最后补给 |

### 调查点 18（town 6 / road 3 / f1 4 / f2 3 / f3 2；A=氛围 F=趣味，各 9）
| id | 图 | tile | tone | 主题（文案见 flavor_inv_<id>.json） |
|---|---|---|---|---|
| inv_town_01 | town | (25,26) | F | 广场喷泉·许愿硬币砸中异物 |
| inv_town_02 | town | (30,10) | A | 北门告示板·三个月前的遗迹封入公告 |
| inv_town_03 | town | (20,33) | F | 客栈后巷木桶·桶里有人打鼾 |
| inv_town_04 | town | (39,16) | A | 神社石像·双眼新凿痕 |
| inv_town_05 | town | (44,30) | F | 东街路灯·剑痕真相存疑 |
| inv_town_06 | town | (16,22) | F | 民居窗台花盆·搬走一周仍被浇水 |
| inv_road_01 | road | (38,10) | F | 断桥警示桩·"桥资筹措中" |
| inv_road_02 | road | (34,28) | F | 石像底座·掌心粉笔笑脸 |
| inv_road_03 | road | (24,38) | A | 界碑·只出不回的脚印 |
| inv_f1_01 | ruins_f1 | (32,2) | A | 入口浮雕·被凿去的第七位祭司 |
| inv_f1_02 | ruins_f1 | (30,11) | A | 坍柱刻痕·古代记账数字 |
| inv_f1_03 | ruins_f1 | (28,23) | F | 残破供桌·三块小石子 |
| inv_f1_04 | ruins_f1 | (18,37) | F | 苔藓石缝·绕开宝箱的小路 |
| inv_f2_01 | ruins_f2 | (21,2) | A | 遗像基座·"守诺者长眠于此" |
| inv_f2_02 | ruins_f2 | (38,10) | A | 断裂锁链·一击斩断的平口 |
| inv_f2_03 | ruins_f2 | (14,41) | F | 墙角刻字·"箱子是骗人的" |
| inv_f3_01 | ruins_f3 | (18,35) | A | 石棺铭文·未完工的最后一行 |
| inv_f3_02 | ruins_f3 | (12,16) | A | 灰石 Boss 门·门后规律低鸣 |

> 坐标口径：road/f1/f2/f3 的 21 点与 E4-S2/S3 既有 Marker2D 锚点（Chest_*/Investigate_*）逐一同位（test_08 实测）；town 6 点为本次新增选点。

---

## 5. 测试覆盖（test_e4s5.gd，18 用例）

| 组 | 用例 | 断言要点 |
|---|---|---|
| A 模板结构 | test_01/02 | on_interact/get_npc_id/get_event_id 协议齐备 |
| B 装配 | test_03~07 | 五图逐图计数 = GDD §3.1 总表（1+6/2+3/3+4/2+3/1+2） |
| C 对表 | test_08 | 实体与既有锚点逐点同位（防数据漂移；宝箱 tile 另有 WallsObjects 美术核对 3 处） |
| C 对表 | test_09 | 目录 ↔ chests.json + investigates.json 27 点全量同构（拍板项④） |
| D/E 宝箱语义+存档 | test_10/11/12 | 首次交互给道具+登记；已开不重给；**存→扰动→读→chests_opened 回灌→再交互道具量不变（验收②闭环）** |
| G 调查语义 | test_13/14 | 协议返回 flavor id；零状态写入；重复交互安全；18 文件全存在 |
| H 文案资产 | test_15/16 | 9 宝箱对话结构合法；18 调查文案 ≥20 字；氛围/趣味 = 9/9 |
| I 安全区 | test_17 | 全部点位离 spawn ≥2 格（不压出生点，见 §6-③ 口径说明） |
| J 端到端 | test_18 | 真实玩家 + InteractRay + 控制器注入按键 → 射线命中 → 协议分派 → 开箱生效 |

测试隔离纪律：GameData 快照/恢复（test_e4s1 同款）、存档指向 `user://e4s5_test_save.json` 绝不碰真实槽、地图 `add_child_autofree` + `after_each` 释放。

---

## 6. 关键决策与修正记录（含实测教训）

1. **inventory 键 = item_id 而非 chest_id**：首版把 `chest_road_01` 写进背包键（日志留痕），已修正为 `GameData.inventory[item_id] += count`，与战斗掉落记账同源（探索 GDD I2 队伍共享背包）。
2. **一文件一脚本（E1-S6 runner 契约）**：初版把 9 箱提示合 1 文件、18 调查合 5 文件，违反"文件名=对话 id"，已拆分为 27 个单脚本 JSON，原件删除。
3. **spawn 安全区口径回正**：初版自设"内容点离 spawn ≥5 格"，导致把 f2 两点挪离美术锚点（test_08 与 test_17 互相打架）。复核探索 GDD §3.4 原文："**spawn 周围 8 格无敌人初始位、无碰撞**"——约束对象是敌人与碰撞，不含内容点。已回归：f2 两点回锚点位（E4-S3 已验收的美术正本），test_17 改守工程底线"≥2 格不压出生落位"。
4. **tone 标签以文案实际笔触为准**：文案是正本，逐条归类后改写 3 条 town 文案为趣味向、修正 road 组标签方向，最终氛围 9 / 趣味 9（test_16 锁死配比）。
5. **实体与美术锚点命名空间分离**：实体名 `Evt_<id>`，锚点名 `Chest_*/Investigate_*`（town 已有 `Chest_town_01` Marker2D，同名会被引擎强制改名并污染查找）。
6. **程序化交互体**（无 .tscn）：装配器给实体加 16×16 CollisionShape2D（层 2，与 npc.tscn InteractBody 同规格）。缺它射线只命中 tilemap 墙体、协议静默失效（test_18 曾空转的根因）。
7. **自治事件分派**：控制器只认协议（`on_interact` 有则实体自治，无则 NPC 对话），NPC 行为零变更；E4-S6 传送网络 Story 再把 controller 铺满五图（当前仅 town 生产装配）。

---

## 7. 遗留风险与边界（需主理人知悉/拍板）

| # | 事项 | 影响 | 建议 |
|---|---|---|---|
| ① | **ADR-3 v1 存档 schema 无 inventory 字段**（九冻结字段）。存→读后 chests_opened 回灌正常、已开不重给（验收②达成），但**道具数量会回到读档前运行时值**——背包持久化是真产品缺口 | 开箱所得道具在跨次读档后丢失数量 | schema v1→v2 加 `inventory` 字段（version bump + 兼容读 v1），建议单开 Story 或并入 E5 存档扩展，**须用户拍板** |
| ② | sfx 为预留钩子（`_play_open_sfx()` 仅日志） | 开箱无音效（音频系统 E6 建） | E6 接 AudioStreamPlayer2D 时只需改 chest.gd 一处实现 |
| ③ | 宝箱对话开演依赖 runner 在树；当前仅 town 生产装配 controller/runner | road/f1/f2/f3 实地跑图时交互无反馈（测试树内已验协议链路本身） | E4-S6 五图 controller 接线时一并铺开（test_18 注记同源） |
| ④ | GUT 日志尾部有引擎退出期 RID/CanvasItem 泄漏 WARNING（10016 orphans） | 无测试失败，属 headless 退出期资源回收告警，历 Sprint 基线即有 | 不阻塞；如需清零另立专项 |
| ⑤ | 点位不可达性未做逐点走图实测（测试只验几何装配与协议） | 若锚点位落在墙体内，射线交互可能够不着 | 建议 E4-S6 传送 Story 完成后由严守真走图验一回，或补自动化寻路校验 |

---

## 8. 拍板项④落地形态（E5 回迁指引）

- 数据正本：`scripts/events/point_catalog.gd`（GDScript typed arrays）。
- JSON 镜像：`data/json/events/chests.json`（9）+ `investigates.json`（18），字段与正本一一对应（test_09 同构校验锁死）。
- E5-S2 JSON 事件加载器就绪后：加载器直接读 JSON → 本表降级为校验锚或删除；实体协议面（`event_id`/`get_event_id`）已预留，控制器分派无需重写。
