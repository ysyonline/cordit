# E4-S1 证据档 · SaveManager 完整实现

> Story：Sprint 4 第 1 项（`production/sprints/sprint-4.md` §3 E4-S1 + `production/epics/EPIC-4.md`）｜执行：程基岩｜日期：2026-08-30
> 实际耗时：约 **12 分钟**（工具时间线：10:41Z 基线启动 → 10:45Z 收口全绿；预算 3.5h）。结余原因：schema 常量与 ADR-3 字段表冻结、无 UI/事件对接面，实现面收敛于单文件。
> 约束遵守：未 git commit / git add；注释简体中文；只动 `autoload/save_manager.gd` + `tests/gut/test_e4s1.gd` + `evidence/`；未触碰 scenes / event_bus / scene_router / game_data（GameData 零改动——回灌只写已有字段）。

## 1. 改动文件清单

| 文件 | 改动 |
|---|---|
| `autoload/save_manager.gd` | 空壳 → 完整实现（~210 行）：`save(map, position)` / `load_save() -> bool` / `has_save()` / `last_loaded` 快照载体；`_snapshot` / `_restore` / `_serialize_party` / `_deserialize_party` / `_migrate` / `_atomic_write` 六个内聚私有函数；SCHEMA 常量与 SAVE_PATH / SCHEMA_VERSION 原样保留（结构零变更） |
| `tests/gut/test_e4s1.gd` | 新增 GUT 15 用例（见 §3） |
| `evidence/e4s1-gut-baseline.log` | 改动前全量基线 200/200 PASS（exit 0） |
| `evidence/e4s1-gut-s1.log` | 收口全量回归 215/215 PASS（exit 0） |

## 2. 实现要点（关键架构/技术决策）

1. **API 形态**：`save(map: String, position: Vector2) -> bool`——map/position 由调用方传参而非 SaveManager 自取：二者是节点侧状态，GameData 按 A3 职责边界不持有；E4-S6（map_ready 时序）与事件脚本 save_point 各自带参调用。
2. **读档回灌边界**：`load_save()` 只回灌 GameData 已有字段（story_phase/flags/chests_opened/discovered_weakness_set/cleared_enemy_set/party），**map/position 不写 GameData**——经 `last_loaded: Dictionary` 暴露，E4-S7 失败读档据此驱动 Router 回图（避免为读档去改 GameData 职责边界）。
3. **序列化语义**（ADR-3 手写 JSON）：
   - `party`：CharacterRecord → 8 字段纯值字典（id/name/job/level/hp/max_hp/mp/max_mp），与 E2-S4 写回字段同构；回灌重建 CharacterRecord（类型化数组逐元素 append，规避 Array[T] 直接赋值坑）。
   - `flags`：运行时 Dictionary → JSON 键数组（值恒 true；带值标志属未来扩展，届时走 version bump）。
   - 三个集合逐元素 String 化回灌（防御 JSON 数字混入）。
4. **原子写**（探索 GDD §3.4 工程义务）：`save.json.tmp` 全量落盘 + flush + 释放句柄 → `DirAccess.rename` 替换。任一步失败：尽力清理 tmp、返回 false、**旧档从未被触碰**（强杀进程安全性由"rename 前旧档零接触"保证）。
5. **容错矩阵**：文件缺失 → false（首次启动分支）；打开失败 / 非法 JSON / 顶层非对象 → false + push_warning；字段缺失 → 按 SCHEMA 默认值补齐（`_migrate` 合并语义）；**version > SCHEMA_VERSION → 拒绝读入**（旧代码不碰新档，防降级破坏）。
6. **迁移骨架**：`_migrate` 含 v0→v1 占位分支与"E5/E6 加字段操作规程"四步注释（SCHEMA 加字段 → bump → 追加 if v<2 分支 → GUT 补迁移用例）。
7. **测试隔离**：`save_path` 可覆写实例变量（默认 = SAVE_PATH），GUT 指向 `user://e4s1_test_save.json`，不污染真实存档槽（SMK-12 口径）；生产代码不覆写（注释已声明）。

## 3. GUT 用例（15 例，tests/gut/test_e4s1.gd）

| # | 用例 | 覆盖验收点 |
|---|---|---|
| 01 | schema与ADR3九字段对齐 | schema 字段对齐 SCHEMA 常量断言 |
| 02 | 存档落盘且快照键集等于SCHEMA | 快照键集 ≡ SCHEMA（不多不少）、map/position/version 落盘 |
| 03 | 往返一致性_阶段标志与三个集合 | 存→读→存往返无损 |
| 04 | 往返一致性_队伍数值 | party 8 字段往返无损（含 hp=0/mp=0 边界） |
| 05 | flags序列化为JSON数组 | Dictionary→数组序列化语义 |
| 06 | 存读再存二次往返稳定 | 二存二读稳定 + last_loaded 指向最新档 |
| 07 | 缺失文件容错 | 容错 + GameData 不被污染 |
| 08 | 损坏JSON容错 | 非法 JSON → false；引擎 Parse Error 经 `assert_engine_error` 显式预期（GUT 9.7 Unexpected Errors 机制对冲） |
| 09 | 非对象JSON容错 | 顶层数组拒绝 |
| 10 | 缺失字段按SCHEMA默认补齐 | 半截档容错 |
| 11 | 原子写成功后无tmp残留 | 临时文件 + rename 路径 |
| 12 | 写入失败保留旧档 | rename 失败分支旧档原封不动（强杀实测的人工项对应单元级分支） |
| 13 | 旧版本号上迁到当前版本 | version 迁移分支 |
| 14 | 未来版本拒绝读入 | 迁移函数拒绝语义 |
| 15 | has_save与last_loaded语义 | E4-S6/S7 消费面 |

## 4. 跑测记录

命令（Git Bash，tests/README §2.4 口径）：
```
MSYS2_ARG_CONV_EXCL="*" <Godot_v4.7.2-stable_win64_console.exe 全路径> --headless --path D:\code\cordit \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit
```

| 轮次 | 结果 | 退出码 | 证据 |
|---|---|---|---|
| 基线（改动前） | **200/200 PASS**（13 脚本，与 team-lead 口径一致） | 0 | evidence/e4s1-gut-baseline.log |
| 中间轮 | 214/215（test_08 引擎 Parse Error 被 GUT 计为 Unexpected Errors） | 1 | 已被收口轮覆盖 |
| 收口 | **215/215 PASS**（14 脚本，6025→6千余 asserts） | **0** | evidence/e4s1-gut-s1.log |

## 5. 验收口径逐条勾对（EPIC-4 原文）

- ✅ **存→读→存往返数据无损**：用例 03/04/06（阶段/flags/三集合/队伍 8 字段/二次往返）
- ✅ **schema 全字段**：用例 01/02 断言快照键集 ≡ SCHEMA 九字段；version 字段落盘
- ✅ **读档回灌 GameData**：`_restore` 显式逐字段写回（用例 03/04/10）
- ⚠→✅ **写入中途强杀进程旧档可读出**：人工实测项（任务管理器杀进程，探索 GDD §3.4 验收原文）——**沙箱无法执行，如实标注留待用户本机**；GUT 已覆盖同保证的单元级分支（用例 12：rename 未发生 → 旧档零接触保留），机制上 tmp+rename 保证旧档在被替换前不被触碰
- ✅ **version 字段 + 迁移函数骨架就位**：`_migrate` 上迁/拒绝/补齐三分支 + E5/E6 操作规程注释（用例 13/14）
- ✅ **存档路径 user://save.json**（ADR-3 口径）：SAVE_PATH 常量原样保留（用例 01 断言）
- ✅ **GUT 12-15 用例**：15 例（要求区间内）
- ✅ **全量回归零失败**：215/215（M3 存量 200 无回归）
- ✅ SMK-12 口径保持：测试经 save_path 覆写隔离，全量跑测未在真实存档槽产生文件

## 6. 待用户/后续事项

1. **人工实测项**：本机跑游戏 → 存档 → 写入瞬间任务管理器杀进程 → 重启读旧档（探索 GDD §3.4 + M4 门要素③的实测部分）。
2. E4-S5（set_flag 动作）写入 flags 时按"键集合"语义（值恒 true）；若需要带值标志，届时走 version bump。
3. E4-S6 调 `SaveManager.save(当前图路径, 玩家位置)`；E4-S7 读 `SaveManager.last_loaded["map"]/["position"]` 回图。
