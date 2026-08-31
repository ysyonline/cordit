# E4-S6 证据档 —— 传送网络 + 进图自动存档（含 E4-S7 失败读档联动）

**日期**：2026-08-31
**执行**：游承峰（主理人，接手程基岩代理停摆会话，用户拍板「我在本会话接手」）
**基线**：GUT 266/266（接手时点）→ **286/286 全绿**（收口）
**证据日志**：`evidence/e4s6-gut-full.log`（20 scripts / 286 tests / 6970 asserts / All tests passed，exit=0）

---

## 1. 交付物清单

| 文件 | 性质 | 说明 |
|---|---|---|
| `scripts/events/teleport_catalog.gd` | 新建 | 12 处传送数据正本（4 同图 + 8 跨图）+ SAME_MAP_LIMITS + MAP_SCENE_PATHS + ENTRY_SPAWNS |
| `data/json/events/teleports.json` | 新建 | 同构 JSON 镜像（拍板项④），GUT 锁死同构 |
| `scripts/events/trigger_teleport.gd` | 新建 | 薄壳 Area2D：id 驱动，同图改位置+换限区，跨图 Router 换图+存档意图 |
| `scripts/events/teleport_assembler.gd` | 新建 | 装配器：按目录构建薄壳、移除 town 旧 4 门 |
| `scripts/events/autosave_notifier.gd` | 新建 | §3.4 时序收口：map_ready 广播 + 门控存档 + 图标 |
| `scripts/ui/save_icon.gd` | 新建 | 存档闪现图标 0.5s（GDD §4） |
| `scripts/maps/{town,road,ruins_f1,ruins_f2,ruins_f3}_map.gd` | 修改 | 五图接入装配器 + announce_ready |
| `autoload/save_manager.gd` | 修改 | 新增存档意图位 save_requested_pending + save_requested 消费 + consume-on-read |
| `scripts/battle/battle_result_handler.gd` | 修改 | VICTORY 登记存档意图；DEFEAT 真读档（E4-S7） |
| `scripts/main/main_controller.gd` | 修改 | R2：INITIAL_SCENE_PATH → town.tscn |
| `tools/gen_town.py` + `tools/verify_town.py` | 修改 | R1：南门栅栏拆除 + verify 断言同步反转 |
| `tests/smoke/headless_e1s4_wrapper.gd` 等 4 个 | 修改 | R2 波及适配（详见 §5） |
| `tests/gut/test_e4s6.gd` | 新建 | 19 条用例（见 §2） |
| `tests/gut/test_e2s4.gd`、`test_e4s5.gd` | 修改 | DEFEAT 语义适配 + 意图位泄漏防护 |

## 2. test_e4s6.gd 覆盖（19 条）

A 目录结构（12 处/4+8 分类/id 唯一）· 静态辅助协议（tile*16+8 口径）
B 目录↔JSON 逐字段同构（12 条 × 7 字段）
C 五图装配计数（town 5 / road 2 / f1 2 / f2 2 / f3 1）+ 薄壳脚本 + Evt_ 命名
D town 四门同位重建像素一致（与旧 tscn 门位 0px 偏差）+ 16×16 门垫
E 12 处落位与触发区 ±12px 脚底盒零重合（防弹回）
F 限区镜像（SAME_MAP_LIMITS ↔ town export 三组）+ 跨图首入 ↔ 各图 pos_from_* export
G 薄壳行为直驱：同图传送落位/限区切换；碰撞层 mask=16（E2-S2 修复锚）；敌人层/对话期/冷却期三重过滤
H 门控存档：无意图不落盘；意图→落盘→坐标=玩家实际位；consume-on-read；信号置位
I 跨图 to_map 场景路径闭环（8 处 ResourceLoader.exists）

## 3. 存档语义（本 Story 裁决，经用户工作流授权 AI 裁决后回传）

**门控存档（意图位）**——替代初稿"无条件进图即存"：

- **发现**：R2 切初始场景为 town 后，无条件存档 = 每次启动游戏都会用默认出生位**覆盖玩家既有存档**（如遗迹深处）。且 GDD §3.4 冻结口径原文即"**过传送点存，不进图即存**"——初稿无条件存才是偏差。
- **机制**：`SaveManager.save_requested_pending`（意图位）。跨图传送受理（trigger_teleport._do_cross_map）/ 战后胜利（battle_result_handler）置位 → 目标图 map_ready 时 `consume_save_request()` 消费才落盘。
- **三类入口语义**：
  - 启动装载（R2）：无意图 → **不落盘**（保既有存档）；
  - 同图室内传送：不置意图 → 不落盘（前次会话裁定维持：存档语义=安全点，室内无遇敌，且防覆盖"门外主图"存档位）；
  - 跨图传送 / 战后胜利回图：置位 → 落盘（坐标=玩家落位/回置后的实际位置）。
- **胜利即存**：VICTORY 置位意图，探索 GDD §3.2"胜利即存防复活"——读档不得让已击破敌人复活。修复了初稿"announce_ready 在地图 _ready 存默认出生位，handler 回置在后"的坐标偏差（存档位≠最终位）。

## 4. 数据修正记录（目录初稿缺陷，弹回审计法）

| 项 | 初稿 | 修正 | 依据 |
|---|---|---|---|
| 同图 4 处 target | (85.5,17.5) 等半格 | (85,17) 等整数格 | 旧 @export 正本 + e1s6 冒烟断言均为格中心 tile*16+8；半格口径系统性偏移 8px |
| Inn_Exit 触发区 | (85,19) | (85,18) | 旧 tscn 节点像素 (1368,296) 反推 tile=(85,18)；HouseA_Exit 同理 (85,30) |
| f1/f2/f3 to_spawn y | 3.5/2.5/2.5 | 3/2/2 | verify_ruins.py 锚定 spawn_px (448,56)/(384,40)/(320,40)；目录与 export 同源修正，且北门触发区零重合复核通过 |

全 12 处弹回审计（落位脚底盒 vs 触发区矩形）：修正后 0px 重合。

## 5. R1/R2 落地与波及适配

- **R1 南门栅栏**：`gen_town.py` 删 (12,46)(13,46) 栅栏两行 → 重跑生成 → `verify_town.py` L125 断言反转为"已拆除"。verify_town **108/108 PASS**。
- **R2 初始场景**：`INITIAL_SCENE_PATH` → `res://scenes/maps/town.tscn`。门控存档保证启动不落盘。
- **波及适配**（初始装载变 more 的连锁）：
  - `headless_e1s4_wrapper.gd`：断言依赖 map_a 几何（出生 (96,160)/横墙 272），改"初始装载完成后整层替换 World 直挂 map_a"（e1s6 wrapper 同模式）；
  - `headless_smk_e1s3_wrapper.gd`：SMK-08 断言"初始=MapA"，改装载后经 Router 合法切回 map_a 恢复断言前提（SMK-12 零落盘不受影响——town 初始装载不落盘）；
  - `headless_e1s6.gd`：R-A1 门传送回归的节点名 `Triggers/Door_Inn/Inn_Exit` → `Evt_tp_town_door_inn/inn_exit`（装配器同位重建后旧名退役）。
- **冒烟回归**：SMK/E1S4/E1S6 通道为运行时挂载型（headless 手动驱动），静态断言已适配；完整 headless 冒烟复跑待 M4 收口仪式（用户本机试玩）一并执行。

## 6. E2-S2 门层位回归修复（根因 + 修复）

- **根因**：town 四门 Area2D `collision_mask=1`（玩家旧 layer=1 时代配置）。E2-S2 玩家改 `layer=16` 后 `mask & layer = 0`，四门**静默失效**（e1s5 人眼验收发生在 layer=1 时代，未暴露）。
- **修复**：装配器统一 `collision_layer=0 / collision_mask=16`（薄壳协议），四门随目录驱动重建一并复活。
- **回归锚**：test_e4s6 test_12 永久锁定 mask=16。

## 7. E4-S7 失败读档（随本档交付，M4 门条件已含）

- **DEFEAT 分支**（battle_result_handler）：`load_save()` 成功 → `last_loaded` 取 map/position → `_map_name_to_path`（短名→场景路径，TeleportCatalog 正本）→ change_scene → map_ready 回置存档点 + 免疫。GameData（story_phase/flags/集合/背包/party）随 `_restore` 整体回滚到存档时点（战斗 GDD §3.5"无额外惩罚"）。
- **读档失败兜底**：无档/损坏 → 回暂存 return_map + push_warning（防御性：正常流程进图必有自动存档，走到兜底=存档链路异常，保流程不断交诊断）。
- **用例**（test_e2s4 扩 2 条）：读档成功回存档点（story_phase 回滚断言）+ 读档失败兜底回暂存图。
- DialogueRunner IDLE 强制锚点（事件 GDD §5）：E5 事件链接入时兑现（当前无战斗中对话场景）。

## 8. 静态核验器全绿

| 核验器 | 结果 |
|---|---|
| `tools/verify_town.py` | 108 PASS / 0 FAIL（含 R1 反转断言 + 薄壳 reset_smoothing 归属断言更新） |
| `tools/verify_ruins.py` | 156 PASS / 0 FAIL |
| `tools/verify_road.py` | 65 PASS / 0 FAIL |
| GUT 全量 | **286/286**（266 基线 + 19 e4s6 新增 + 1 e2s4 净增） |

## 9. 遗留与红线

- **未 commit**（用户拍板制）：全部改动在工作区，等 M4 收口仪式后一并处理。
- tools/README.md 工具链登记仍未补（前次会话遗留小债，S7 已无阻塞）。
- Orphans 10016 与退出期 RID 泄漏告警为 GUT 框架既有现象（基线一致，非本次引入）。
- 冒烟 headless 通道（e1s4/e1s6/smk08-12）的最终复跑挂 M4 收口仪式（用户本机试玩 + 视频#4）。
