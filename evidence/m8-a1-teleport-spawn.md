# M8-A1 证据档 —— 跨图传送落位修复 + VICTORY 回图存档坐标修复

**日期**：2026-09-13
**执行**：程基岩（engineering-lead）
**任务单**：M8-A① #1（P0 体验阻断级缺陷，含同批时序修正）
**基线**：GUT 36 scripts / 551 tests / 8535 asserts（修复前，`m8a1_gut_full.log` 全绿）
**收口**：GUT **36 scripts / 557 tests / 8560 asserts / All tests passed（exit=0）**
**证据日志**：
- `evidence/m8-a1-gut-full.log` —— 修复后全量全绿（36/557/8560）
- `evidence/m8-a1-red-before-fix.log` —— **修复前**对照（test_e4s6 单文件，20/25，5 红：即两处缺陷实证）
- `evidence/m8-a1-e4s6-after.log` —— 修复后 test_e4s6 单文件复跑（25/25）

---

## 1. 缺陷与根因

### 缺陷 1：跨图传送落位错误（f3→f2 返程最显著）

- **现象**：跨图传送后玩家落在目标图错误位置（尤以 f3→f2 返程明显）。
- **根因**：`scripts/events/trigger_teleport.gd` 的 `_do_cross_map(spec)` 只消费
  `spec["to_map"]` 去 `SceneRouter.change_scene` 切图，**从未消费 `spec["to_spawn"]`**。
  目标图玩家恒落在该图 tscn 里硬编码的 `YSorted/Player` 初始位：
  | 传送（返程） | to_spawn（tile→像素） | 目标图 tscn 硬编码 Player 位 | 偏差 |
  |---|---|---|---|
  | `tp_f3_to_f2` | (23.5,45.5) → **(384,736)** 北口楼梯走道 | `ruins_f2` = **(384,40)** 南门入口位 | Δy=696px |
  | `tp_f2_to_f1` | (27.5,41.5) → (448,672) | `ruins_f1` = (448,56) | Δy=616px |
  | `tp_road_to_town` | (12.5,45.5) → (208,736) | `town` = (192,640) | 偏离 |
  | （余下 5 条跨图同理，f1→f2 落位恰与硬编码位同值故不可见） | | | |

- **关键时序约束（方案取舍的决定因素）**：五图 `_ready` 顺序均为
  `TeleportAssembler.assemble(...)` → `AutosaveNotifier.announce_ready(...)`。
  `announce_ready` 内部**同步** `emit EventBus.map_ready` 并**立即**读取
  `YSorted/Player.global_position` 作为存档坐标（探索 GDD §3.4「过传送点存」）。
  因此落位**必须**在 `assemble` 这一环完成——**绝不可**用 map_ready 之后
  deferred 回置（那样自动存档会记成入口硬编码位而非 to_spawn 位）。

### 缺陷 2：VICTORY 战后回图存档坐标偏差

- **现象**：VICTORY 战后回图，自动存档坐标 = 目标图 tscn 硬编码入口位，
  而非该文件头注释声称的「回置后的战前位置」。
- **根因**：`scripts/battle/battle_result_handler.gd` 在 VICTORY 时置
  `SaveManager.save_requested_pending = true` 并把待回置位置存进 `_pending_return`；
  `_on_map_ready` 却用 `_do_return.call_deferred()` **延迟一帧**回置。而 `map_ready`
  由 `announce_ready` **同步** emit——emit 返回后 `announce_ready` 立刻读玩家位置存档，
  此刻 deferred 回置尚未执行，玩家仍在目标图 tscn 的硬编码入口位 → 存档记成入口位。

---

## 2. 修法

### 缺陷 1 —— 「装载期落位」机制（装配器内消费，五图脚本零改动）

1. **`autoload/scene_router.gd`**：新增「跨图落位意图」簿记（与
   `SaveManager.save_requested_pending` 同款意图位风格，只是承载坐标而非布尔）：
   - `var _pending_spawn: Variant = null`（Vector2 或 null）
   - `func set_pending_spawn(p: Vector2) -> void`
   - `func consume_pending_spawn() -> Variant`（consume-on-read，返回后清零）
   - 头注释同步说明簿记语义、消费者与「为何必须紧贴装载」的时序依据。
   - ⚠️ 未触碰「4 Autoload 冻结」架构——这是给**已有** Autoload 加字段/方法，非新增 Autoload。
2. **`scripts/events/trigger_teleport.gd` · `_do_cross_map`**：在 `change_scene` **之前**
   `SceneRouter.set_pending_spawn(TeleportCatalog.tile_to_pixel(spec["to_spawn"]))`；
   若 `change_scene` 返回 `false`（被拒），立即 `consume_pending_spawn()` **回滚**，
   防意图残留污染下一次装载。
3. **`scripts/events/teleport_assembler.gd` · `assemble`**：装载期第一步调用新增静态
   `_apply_pending_spawn(p_map_root)`——`consume_pending_spawn()`，若非 null 则把
   `YSorted/Player` 的 `global_position` 设为该值。无 pending（启动装载 / 同图室内
   传送 / 战斗回图）→ 静默跳过；玩家节点缺失时**也消费掉**（防残留）并 `push_warning`。
   `assemble` 返回的触发器数组语义不变（对表断言不受影响）。

**为何在 `assemble` 且必须在 `announce_ready` 之前**：`assemble` 是五图 `_ready` 的第一环，
先于 `announce_ready`（后者同步读位置存档）。只有在装载期（乃至更早）完成落位，自动存档
坐标才等于 to_spawn 落位值。

### 缺陷 2 —— `map_ready` 回调内**同步**回置

`scripts/battle/battle_result_handler.gd`：

- `_on_map_ready`：由 `_do_return.call_deferred()` 改为**同步**调用
  `_pos_return_immediate()`——因为 `map_ready` 是同步 emit 的，同步回置即发生在
  `announce_ready` 读位存档**之前**，存档坐标随之正确。仅当玩家确实未就绪时
  （World 在但无 `YSorted/Player`，异步挂载的异常场景）才退化为延迟一帧重试。
- `_pos_return_immediate()`：返回 `bool`（成功 / 了结 vs 暂缓重试）。簿记清理时机：
  成功回置、或"重试也无用"的环境（未入树 / 无 Main-World）→ 清空；仅"World 在但无玩家"
  这一瞬时态才保留簿记待重试（避免重试循环刷告警）。

**为何选「同步回置」而非「return_position 经 set_pending_spawn 由 assemble 消费」**：
两者都能让回置发生在存档读取之前，最终存档坐标一致。取舍理由：

- `_pending_return` 簿记**已被 5 个测试文件**（test_e2s4 / test_o7 / test_o6 / test_m6t41 /
  test_e6s2）直接预置/清零并断言其语义；而这些测试用的白盒图 fixture **无 TeleportAssembler**，
  一旦 battle 路径改走 `set_pending_spawn`，意图在这些环境**无人消费 → 残留**，需逐个测试
  文件补隔离，改动面大、回归风险高（任务明令优先保证 DEFEAT 与既有测试不回归）。
- 「同步回置」直接对准缺陷 2 的**根因**（`call_deferred`），且 `_pending_return` 的既有
  语义/测试断言全部保留，改动最小、最稳。
- 二者本质等价：`map_ready` 同步 emit → 同步回置 → `announce_ready` 随后读位存档；
  落位与存档读取的相对先后被钉死，正是任务要求的效果。

**DEFEAT / ESCAPE 路径未受影响**：仅改了"回置发生的时机（同步）、簿记清理分支"，
读档回图与暂存兜底逻辑一字未动；`test_e2s4` 的 `test_DEFEAT读档成功_回存档点` /
`test_DEFEAT读档失败_兜底回暂存图` 等断言全部照常绿。

---

## 3. 改动文件表

| 文件 | 性质 | 说明 |
|---|---|---|
| `autoload/scene_router.gd` | 修改 | 新增 `_pending_spawn` 簿记 + `set_pending_spawn` / `consume_pending_spawn` + 头注释【职责】④ |
| `scripts/events/trigger_teleport.gd` | 修改 | `_do_cross_map` 登记落位意图（change_scene 前）+ 被拒回滚 |
| `scripts/events/teleport_assembler.gd` | 修改 | `assemble` 装载期调用 `_apply_pending_spawn` 消费意图落位 |
| `scripts/battle/battle_result_handler.gd` | 修改 | `_on_map_ready` 同步回置；`_pos_return_immediate` 返回 bool + 簿记清理分支 |
| `tests/gut/test_e4s6.gd` | 修改 | 新增 6 条用例（test_20~25）+ 隔离基建（假 Main / GameData 快照 / Router 簿记重置） |
| `evidence/m8-a1-teleport-spawn.md` | 新建 | 本档 |
| `evidence/m8-a1-gut-full.log` | 新建 | 修复后全量 GUT 日志（全绿） |
| `evidence/m8-a1-red-before-fix.log` | 新建 | 修复前 RED / 实证日志 |
| `evidence/m8-a1-e4s6-after.log` | 新建 | 修复后 test_e4s6 单文件复跑日志 |

- **五图地图脚本 `_ready` 零改动**（`scripts/maps/*.gd` 未触碰）。
- **无新增 `.gd` 文件**（故无新增 `.uid` 需求）。
- `data/json/events/teleports.json` 未动（目录数据正本不变）。

---

## 4. 缺陷 2 实证前后对比（先证后修）

**修复前（`evidence/m8-a1-red-before-fix.log`，test_e4s6 20/25）** —— 观测到的偏差：

```
- test_25_VICTORY回图存档坐标应为回置后的return_position
    [Failed]:  [VECTOR2(384.0, 64.0)] expected to equal [VECTOR2(400.0, 640.0)]:
               VICTORY 存档坐标应为回置后的 return_position（非 tscn 硬编码 (384,64)）
```

- 用例：真图 `road.tscn`（含 `announce_ready` 自动存档）经 Router 装入假 Main；
  `road` 的 tscn Player 硬编码 **(384,64)**；VICTORY 的 `return_position` 取 **(400,640)**。
- **实证结论**：自动存档坐标 = **(384,64)**（入口硬编码位），而玩家最终被回置到
  (400,640)——存档位 ≠ 回置位，偏差 Δ=(16,576)px，与根因（deferred 晚于同步读位）完全吻合。

**修复后（`evidence/m8-a1-e4s6-after.log` / `m8-a1-gut-full.log`）**：

```
[BattleResultHandler] 玩家回置 -> (400.0, 640.0)，免疫 0.5s 启动
...
- test_25_VICTORY回图存档坐标应为回置后的return_position   → 绿
```

存档坐标 = return_position = (400,640)，偏差消除。

> 说明：修复前的 RED 日志中 test_24 另有一条「跨图传送应自动存档」失败——那是当时用例未带
> 遮罩、无 `FadeMask` 的**同步装载**使 `_do_cross_map` 的存档意图 emit 晚于目标图装载所致
> （测试时序失真）；最终用例已补 UILayer/FadeMask 复刻生产「异步淡出后装载」的时序，该条不再出现。

---

## 5. headless 全绿证据摘要

命令（沙盒重定向 + 跑前清残留 save.json，B-01 教训）：

```
APPDATA=<repo>/.godot_user_tmp/gut-sandbox  Godot_v4.7.2-stable_win64_console.exe \
  --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests/gut -ginclude_subdirs -gexit
```

`evidence/m8-a1-gut-full.log` 收尾：

```
Totals
------
Warnings              2
Scripts              36
Tests               557
Passing Tests       557
Asserts            8560
Orphans           10016
Time              77.161s

---- All tests passed! ----
```

（557 = 基线 551 + 本次 6 条新增；`Warnings 2` 与基线一致——2 条为 GUT/无 Main 环境既有
「回置失败：Main/World 无当前场景」告警，非本次引入、条数未增。）

关键链路日志（修复后）：

```
[TeleportAssembler] 装载期落位 -> Ruins_F2 @ (384.0, 736.0)（跨图传送 to_spawn）
[SceneRouter] 装载完成 -> res://scenes/maps/ruins_f2.tscn
[TriggerTeleport] 跨图传送 tp_f3_to_f2 -> ruins_f2（受理=true）
[TriggerTeleport] 跨图传送 tp_f3_to_f2 -> ruins_f2 被拒（受理=false），落位意图已回滚   ← test_23 回滚分支
[BattleResultHandler] 玩家回置 -> (400.0, 640.0)，免疫 0.5s 启动                     ← 存档读取前
```

---

## 6. 生产链路口径说明（修复后）

**跨图传送（缺陷 1）**：

```
玩家踩踏触发区
  → trigger_teleport._on_body_entered（层/对话/冷却过滤）
  → _do_cross_map：SceneRouter.set_pending_spawn(tile_to_pixel(to_spawn))   ← 登记落位意图
  → SceneRouter.change_scene(path)：0.2s 淡出
       → 目标图 instantiate 入 Main/World → 目标图 _ready：
            ① TeleportAssembler.assemble —— consume_pending_spawn() → 玩家落位到 to_spawn  ← 关键
            ② AutosaveNotifier.announce_ready —— 同步 emit map_ready → 立即读玩家位置（= to_spawn）→ 存档
       → 0.2s 淡入
  → （受理成功）EventBus.save_requested.emit() 登记存档意图（消费端即上一步 announce_ready）
```

**VICTORY 回图（缺陷 2）**：

```
battle_finished(VICTORY)
  → BattleResultHandler._on_battle_finished：置存档意图 + _pending_return = return_position
  → SceneRouter.change_scene(return_map)：0.2s 淡出 → 目标图 _ready：
        AutosaveNotifier.announce_ready：
          ① 同步 emit map_ready
               → BattleResultHandler._on_map_ready【同步】回置玩家到 return_position + 启动免疫
          ② 读玩家位置（= return_position）→ 存档                                  ← 已修正
```

---

## 7. test_e4s6 新增用例（test_20~25，共 6 条）

| 用例 | 断言要点 |
|---|---|
| test_20_跨图落位_装配器消费pending落到to_spawn | 8 条跨图逐条：登记 to_spawn 像素 → 装载目标图 → 玩家落位 = to_spawn |
| test_21_跨图落位后存档坐标为落位值 | f3→f2：落位 + 存档坐标均为 (384,736)（非 ruins_f2 硬编码 (384,40)） |
| test_22_无落位意图时装配器不动玩家位置 | 无 pending → 玩家保持 tscn 初始位（启动装载/同图传送/战斗回图语义） |
| test_23_传送被拒时落位意图回滚 | 无 Main 结构 → change_scene 拒 → 落位意图 consume 回滚（返回 null） |
| test_24_跨图传送真实链路_f3南门踩踏落位与存档 | **玩家驱动链**：踩踏触发区 → _do_cross_map → Router → 目标图落位 + 存档均 = to_spawn |
| test_25_VICTORY回图存档坐标应为回置后的return_position | 缺陷 2 实证/回归：存档坐标 = 回置后 return_position（非 tscn 硬编码） |

隔离纪律：GameData（cleared_enemy_set / story_phase）快照恢复；假 Main after_each 拆除；
`SceneRouter` 簿记（`_staged_payload` / `current_scene_path` / `_switching` / `_pending_spawn`）
用例前后重置；存档槽 `user://e4s6_test_save.json` 覆写隔离（SMK-12）。

---

## 8. 未决风险 / 待用户游戏内目检

- **未 git commit**（无用户指令不提交；全部改动在工作区）。
- **潜在（本次未修，观察项）**：`trigger_teleport._do_cross_map` 的 `EventBus.save_requested.emit()`
  在 `change_scene` 返回**之后**发出。生产 `main.tscn` 有 `UILayer/FadeMask`，`change_scene`
  的装载在 0.2s 淡出后异步发生，故存档意图先于装载、无问题；但无遮罩的**同步装载**环境
  （部分测试/未来 headless 通道）会出现「意图晚于装载」。本次在测试侧以带 `FadeMask` 的
  假 Main 复刻生产时序规避，**未改生产代码**（保持改动面最小）。如后续决定收口，可把
  intent emit 提前到 change_scene 之前并补被拒回滚。
- **待用户游戏内目检**（机器不可判）：
  1. 五图跨图往返落位手感——玩家是否落在门前合理位置、返程是否有「弹回触发区」；
  2. f3→f2 返程落点 (384,736) 北口楼梯走道是否与门洞构图吻合；
  3. 跨图传送 / 战后 VICTORY 回图后的自动存档坐标是否 = 玩家实际所见落位（读档复原位一致）。
- **引擎一致性**：全部改动基于 Godot 4.7.2 + GDScript，未使用超出该版本 API 的能力；
  无元组赋值、渐进类型、静态函数访问 Autoload（同 `autosave_notifier` 既有用法）。
