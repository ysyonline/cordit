# M8-A③ · 五图建筑层 WallsObjects 归位 YSorted 子树 — 证据档

- **任务**：M8-A③ · #9 · P0（体验缺陷）
- **日期**：2026-09-13
- **责任人**：程基岩（engineering-lead）
- **一句话**：把小镇/道路/遗迹 f1-f3 五图的建筑层 `WallsObjects` 从「地图根直子节点」改为
  「`YSorted` 的子节点」，使 y-sort 真正生效（玩家/NPC 可被建筑正确遮挡）。
- **收口（team-lead 追加）**：补一条 GUT 引擎级漂移守卫
  `tests/gut/test_m8a3_walls_ysorted.gd`（显式断言五图 `WallsObjects` 父节点为 `YSorted`
  且旧根路径已消失），并跑全量回归——结果已并入本档 §3.4 / §6.2。

---

## 1. 背景与根因

### 缺陷现象
玩家 / NPC 走过建筑、树、柜台等"角色本可站到其后方"的 tile 时，**永远被压在建筑之下**，
无法呈现 2.5D 纵深感。

### 根因（团队定位，本次复核确认）
`WallsObjects` 是地图根（`Map_*` / `Ruins_*`）的**直子节点**，与 `YSorted` 平级：

```
Map_Town (Node2D)
├── Ground (z=-10)
├── GroundDeco (z=-9)
├── YSorted (Node2D, y_sort_enabled=true)
│   └── Player / NPC / 敌人 / 锚点
├── WallsObjects (TileMapLayer, z=0, y_sort_enabled=true)   ← 错位：挂根，不在 YSorted 内
├── Above (z=+10)
└── Triggers
```

Godot 的 y-sort **只对「同一个 y-sort 父节点下的兄弟节点」排序**。`WallsObjects` 与
`Player` 不在同一父节点下 → 二者互不参与排序；`WallsObjects` 作为整体挂在根 z=0，
其绘制先后仅由**树序 + z_index**决定，与玩家脚底 y 无关 → 恒定覆盖/被覆盖。

### 设计依据（正本）
- `docs/architecture/godot4-architecture-adr.md`
  - **:107-108** 结构图：`YSorted (Node2D, y_sort_enabled=true, z=0)` → 内含
    `WallsObjects (TileMapLayer, y_sort_enabled=true)`。
  - **:116** 明文充要条件：*"y-sort 生效的充要条件：父节点 `y_sort_enabled=true` 且
    **所有参与排序的节点在同一个父节点下**"*。
- `design/gdd/e1-s5-town-build-sheet.md`
  - **:293** 五层结构：`YSorted (Node2D) ├── WallsObjects (TileMapLayer, y_sort_enabled=true ✔)`。
  - **:309** *"WallsObjects：全部建筑立面行、边框树干…**这一层的每个 tile 都要在 TileSet 里设过 Y Sort Origin=8**"*。
  - **:397** 验收勾选项：*"场景面板核对：… YSorted(y_sort✔，**内含 WallsObjects y_sort✔**+Player)…"*。

> `y_sort_origin = 8`（tile 底边）早已在 `town_map_tileset.tres` / `ruins_tileset.tres` 全部
> Walls tile 上设定 → **tile 侧准备就绪**，缺的只是节点归属。本次即补齐归属。

**用户拍板范围**：五图全改（非仅小镇）。

---

## 2. 前置验证 —— 重生成等价性（关键发现）

### 方法
把三个生成器复制到临时镜像仓 `.godot_user_tmp/m8a3_regen/repo/tools/`，
在镜像内运行（**绝不直接覆盖 `scenes/`**），与真实产物逐字节比对。

### 结论
| 产物 | 结论 |
|---|---|
| `scenes/maps/town.tscn` | **SAME**（生成器可完全复现） |
| `scenes/maps/ruins_f1.tscn` | **SAME** |
| `scenes/maps/ruins_f2.tscn` | **SAME** |
| `scenes/maps/ruins_f3.tscn` | **SAME** |
| `assets/tiles/town_map_tileset.tres` | **SAME** |
| `scenes/maps/road.tscn` | **DIFF** — 唯一分歧：`return_map` |

### road.tscn 分歧详情（手改未收编）
`gen_road.py` 原输出 `return_map = "road"`（短名），但 `road.tscn` 实际为
`return_map = "res://scenes/maps/road.tscn"`（全路径）。

- 这是 **M6 演示期发现的产品缺陷手工修正**（见 `evidence/_m6_auto_demo.gd:469-485`：
  *"road.tscn 的可见敌人 return_map 短名…永远回不了图…产品侧修复建议：road.tscn 三敌人
  return_map 导出值改…"*），当时**只改了 tscn、未同步生成器**。
- 运行时 `visible_enemy.gd:363` 取 `return_map` 后交 `SceneRouter.change_scene(return_map, …)`，
  须 **res:// 全路径**才能解析——短名会导致道路敌人战后**回不了图**。

**处置**：本次一并**把生成器补齐**（`gen_road.py` 三敌 `return_map` 改为全路径，与遗迹
生成器 `res://scenes/maps/ruins_{key}.tscn` 口径一致）。补齐后重跑，`road.tscn` 亦变为
**SAME** → 五图重生成全部等价，可安全"改生成器 + 全量重生成"。

> 该判断结论即本节记录（任务要求"把判断结论写进证据档"）。

---

## 3. 改动清单

### 3.1 生成器（3）
| 文件 | 改动 |
|---|---|
| `tools/gen_town.py` | `layer_node()` 增 `parent` 参数；`WallsObjects` 传 `parent="YSorted"` |
| `tools/gen_road.py` | 同上；另 **同步 `return_map` 手改**（`"road"` → `"res://scenes/maps/road.tscn"`），附 M6 出处注释 |
| `tools/gen_ruins.py` | `tscn_for()` 内层 `layer_node()` 增 `parent` 参数；`WallsObjects` 传 `parent="YSorted"` |

生成器注释均注明 M8-A③ 出处（ADR A6 / 施工单 293）。`parent` 默认 `"."`，
Ground / GroundDeco / Above 三个非排序层**调用点零改动**。

### 3.2 场景（5）—— 全部由生成器重生成
`scenes/maps/{town,road,ruins_f1,ruins_f2,ruins_f3}.tscn`
每图**仅一行**变化：

```diff
-[node name="WallsObjects" type="TileMapLayer" parent="."]
+[node name="WallsObjects" type="TileMapLayer" parent="YSorted"]
```

`tile_set / z_index = 0 / y_sort_enabled = true / tile_map_data` **逐字节不变**。

### 3.3 静态核验器（3）
| 文件 | 改动 |
|---|---|
| `tools/verify_town.py` | `parse_layer()` 增 `parent` 参数；WallsObjects 以 `parent="YSorted"` 解析；新增结构断言 |
| `tools/verify_road.py` | 同上 |
| `tools/verify_ruins.py` | 同上（三层批量） |

新增断言（三器各一）：
`"结构: WallsObjects 为 YSorted 子节点【M8-A③】"` = 文本含
`[node name="WallsObjects" type="TileMapLayer" parent="YSorted"]`。
属性行顺序（`tile_set` → `z_index` → `y_sort_enabled`）**保持不变**，既有 y-sort 断言
（用 `[^\]]*` 吸收 `parent=` 属性）无需改动即通过。

### 3.4 GUT 测试（2 + 1 收口）
| 文件 | 改动 |
|---|---|
| `tests/gut/test_e4s2.gd` | `test_02` 层路径列表 `["Ground","GroundDeco","YSorted/WallsObjects","Above"]` |
| `tests/gut/test_e4s3.gd` | `test_02` 同上；`test_07` 取层改 `get_node("YSorted/WallsObjects")` |
| `tests/gut/test_m8a3_walls_ysorted.gd`（**收口新增**，配 `.uid=uid://m8a3wysdst01`） | 五图逐一 instantiate → 断言 `YSorted/WallsObjects` 存在、旧路径 `WallsObjects` 已消失、`get_parent().name=="YSorted"`、Ground/GroundDeco/Above 仍挂根 |

`grep WallsObjects` 全仓核对：仅上述两文件按路径访问（`test_e4s5.gd` 仅注释提及，代码
走 `content_points` / `YSorted/Player`，无需改）。

**收口断言（防漂移）**：`test_m8a3_walls_ysorted.gd` 是**引擎级**结构守卫——直接
`instantiate()` 五图，用节点路径解析 `YSorted/WallsObjects`，并对**旧路径`WallsObjects`
断言其为 null**。未来任何重生成/手工编辑若把该层退回根，则该测试立即失败，无需依赖
文本级核验器。覆盖全部 5 图，单测试 40 断言（5 图 × 8 断言）。

---

## 4. 变更面证明（最小化）

以**更新后的生成器**重生成到镜像，与**改动前的真实 tscn** 逐字节 diff：

| 文件 | diff |
|---|---|
| town.tscn | 1 处（WallsObjects parent 行） |
| road.tscn | 1 处（同上） |
| ruins_f1.tscn | 1 处（同上） |
| ruins_f2.tscn | 1 处（同上） |
| ruins_f3.tscn | 1 处（同上） |
| town_map_tileset.tres | **SAME（零改动）** |

每图字符数 +6（`"."` → `"YSorted"`），无其它任何字符漂移。
重生成后 `real == mirror` 逐字节一致（见 `.godot_user_tmp/m8a3_apply.log`）。

---

## 5. 红线核对

| 红线 | 状态 | 证据 |
|---|---|---|
| Player 路径仍 `YSorted/Player` | ✅ | 五图未动 Player 声明 |
| NPC 实体仍挂 `YSorted` | ✅ | `NPC_Anchors` / 敌人 / `Anchors` parent 未动 |
| `Above` 仍挂根、z=+10 | ✅ | diff 无 Above 行；verifier `z_index = 10` PASS |
| `Triggers` 仍挂根 | ✅ | diff 无 Triggers 行 |
| Ground/GroundDeco z=-10/-9 | ✅ | verifier PASS |
| `WallsObjects` z=0 + y_sort_enabled=true | ✅ | verifier `y_sort: WallsObjects` PASS |
| 不改 tile / 资产 / TileSet | ✅ | `town_map_tileset.tres` 逐字节 SAME；`tile_map_data` 不变 |
| 不 git commit/push | ✅ | 全程未执行任何 git 写操作 |

---

## 6. 核验结果

### 6.1 静态核验器（Python）—— 全 PASS
| 核验器 | 结果 |
|---|---|
| `verify_town.py` | **PASS 129 / FAIL 0** ✅ |
| `verify_road.py` | **PASS 66 / FAIL 0** ✅ |
| `verify_ruins.py`（f1+f2+f3） | **PASS 159 / FAIL 0** ✅ |

三器均含新增 `结构: WallsObjects 为 YSorted 子节点【M8-A③】` 断言，全部 PASS。
（日志：`.godot_user_tmp/m8a3_verify.log`）

### 6.2 GUT 全量回归（引擎级）—— 全绿
- 环境：headless + `APPDATA` 沙箱重定向（`.godot_user_tmp/gut-sandbox`）+ 运行前清残留 `save.json`
- 结果（**含收口新增漂移守卫**）：**Scripts 37 / Tests 558 / Passing 558 / Asserts 8602 / Warnings 2** → `All tests passed!`
- 直接相关：`test_e4s2` **6/6**、`test_e4s3` **8/8**、`test_e4s6` **25/25**、`test_m8a3_walls_ysorted` **1/1（40 断言）**
- （日志：`evidence/m8-a3-gut-full.log`）

**与基线对比（证明零回归 + 收口增量）**：

| 指标 | M8-A① 后基线 | 本次（含收口） | 差值 |
|---|---|---|---|
| Scripts | 36 | 37 | **+1**（新增 test_m8a3 文件） |
| Tests | 557 | 558 | **+1**（新增漂移守卫测试） |
| Passing | 557 | 558 | **+1** |
| Asserts | 8560 | 8602 | **+42**（5 图 × 8 断言 + tscn 路径/平级断言） |
| Warnings | 2 | 2 | **0** |

→ 差值**精确等于**收口新增的单一守卫测试，其余 557 个用例**逐项原样通过** → 零回归。

> `Warnings 2` 为基线既有（`test_m7a1` / `test_smk_migration` 的"无 Main 环境"回置告警），
> 本次**未新增任何警告**。尾部 RID / ObjectDB 泄漏为 headless 退出噪声（基线同样存在）。

### 6.3 引擎级结构证据
五图经 `PackedScene.instantiate()` 装载后，`YSorted/WallsObjects` 均可由引擎节点路径
解析（test_e4s2 `test_02`、test_e4s3 `test_02` / `test_07` 直接断言）。若 parent 有误，
`get_node_or_null("YSorted/WallsObjects")` 返回 null → 断言失败。**引擎侧已验证归属。**

---

## 7. 原理说明与手动目检（headless 不可自动化）

y-sort 生效链：`YSorted(y_sort_enabled)` 收集其下兄弟项（含 `WallsObjects` 的**每个 tile**，
按各自 `y_sort_origin=8` 即 tile 底边 y 参与排序）与 `Player`（脚底原点）→ 按 y 升序绘制
→ 玩家脚底 y > 建筑 tile 底边 y 时玩家后绘（盖住建筑下沿）；反之建筑后绘（遮住玩家下半身）。

**以下 3 个目检点需人工 F5 验证（headless 无渲染，自动化测试覆盖不到）**，对应施工单
`:314-317`：
1. 小镇玩家站客栈北侧 `(29,12)`：身体被屋顶/立面上部遮挡（Above 恒盖 + Walls 底边排序）。
2. 小镇玩家站喷泉南侧 `(27,29)`：玩家盖住喷泉下沿。
3. 五图玩家贴边框树北侧行走：树冠（Above）恒在头顶，树干随绕行正确前后遮挡（**本轮修复
   主要针对的正是树干/建筑这类"可站其后方"的 WallsObjects tile**）。

> 建议：交付前由美术/主理人在编辑器 F5 逐图走查 3 点。本轮为**节点归属**修复，
> 数值/资产零变更，视觉正确性由该走查最终确认。

---

## 8. 风险与后续

1. **y-sort 目检点未在本轮自动化**：headless 测试无法断言像素遮挡关系。已列为人工交付项。
2. **`WallsObjects` 现为 `YSorted` 首个子节点（town）/ 末个子节点（road·ruins）**：
   y-sort 按 y 排序、不依赖树序；对**同 y 平局**的稳定序理论上略有差异，但 tile 用底边
   y（origin=8）、玩家用脚底原点，生产上不构成可见差异。无需调整。
3. **后续重生成纪律**：`gen_road.py` 的 `return_map` 已补齐。今后任何 tscn 手改**务必同步
   生成器**（本次道路 `return_map` 分歧即为反例）。建议 CI 加一步"重生成后 `git diff --exit-code`"
   以防漂移（超出本任务范围，留作建议）。
4. **无新增 Autoload / 无新资源 / 无协议变更**：仅节点归属 + 生成器/校验/测试同步。

---

## 9. 附：工作脚本与备份（临时区，不入库）
- `.godot_user_tmp/m8a3_regen.py` + `m8a3_regen.log`：前置等价性检查（镜像运行 + diff）。
- `.godot_user_tmp/m8a3_apply.py` + `m8a3_apply.log`：就地重生成 + real==mirror 校验。
- `.godot_user_tmp/m8a3_verify.py` + `m8a3_verify.log`：三核验器运行日志。
- `.godot_user_tmp/m8a3_backup/`：改动前五图 tscn + tres 备份（回滚用）。
- `evidence/m8-a3-gut-full.log`：全量 GUT 回归日志（**Scripts 37 / Tests 558 / 558 passed / Asserts 8602**，含收口漂移守卫）。
