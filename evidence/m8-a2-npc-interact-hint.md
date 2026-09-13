# M8-A② · NPC 头顶交互提示（❗Z 脉冲）— 证据档【rev3】

- **任务**：M8-A② · #10 · P1（体验缺陷）→ rev2 → **rev3**（用户在 rev2 实机复验后报回一处残留缺陷）
- **日期**：2026-09-13
- **责任人**：程基岩（engineering-lead）
- **一句话**：NPC 是玩家**当前可交互目标**（面朝 + 射线命中，与 Z 键分派同一判据）时，
  头顶浮出金色「❗Z」脉冲标签；转开/离开/对话中即隐。
- **rev2 背景**：首版（判据=脚底距离；提示挂 NPC 自身）经用户实机验证，暴露两处缺陷
  （见 §2），rev2 修订判据与旧提示的挂载位。
- **rev3 背景**：rev2 经用户复验，缺陷②/③/④（跨图残留、叠影、不误亮）已修好；
  **缺陷①有残留**——用户原话：「正后方,或者其他角度,都会亮一下 ❗,然后不亮。
  正前方,常亮 ❗,期望不是正前方,不要随便亮」。根因与修法见 §9。

---

## 1. 验收口径（rev2 定稿）
- 玩家**面朝** NPC 且 InteractRay 命中（= 按 Z 真能交互）→ 该 NPC 头顶「❗Z」亮；
  转开/离开/无目标 → 隐。
- 「❗Z」恒清晰可见，**不被建筑/树冠遮挡**。
- 提示**随地图生灭**：离开地图即消失，**跨图/重进不残留、不叠影**。

---

## 2. rev2 缺陷与修法（用户实机命中）

### 缺陷①：提示亮起 ≠ 可交互（"要到 NPC 某个特殊位置才对话"）
- **根因**：首版 `npc.gd._physics_process` 用**脚底直线距离**判定（`HINT_RANGE_PX=24`）；
  而真正交互条件（`player.get_interact_target()`，`player.gd:225-231`）是
  **面朝 + `InteractRay.target_position = facing*20` 命中** InteractBody。玩家站
  NPC **侧后方**（距离≤24px）时，提示亮但射线不命中 → **按 Z 无目标**。
- **判定条件对齐（前后对比）**：

  | | 首版（错） | rev2（对） |
  |---|---|---|
  | 判据 | NPC 脚底↔玩家脚底 直线距离 ≤24px | `player.get_interact_target()`（**面朝 + 20px 射线命中**） |
  | 与 Z 键分派关系 | 两套独立判据 | **同一判据**（`_try_interact` 亦调 `get_interact_target`） |
  | 后果 | 亮起但按 Z 无目标 | **提示亮 ⇔ 按 Z 有目标** |
  | 显隐驱动方 | `npc.gd`（含距离计算） | `InteractionController`（每物理帧一次射线） |

- **修法（按派单实现）**：
  - `interaction_controller.gd` 新增 `_physics_process` 每帧轮询：调
    `_player.get_interact_target()` **一次**，沿父链上溯至首个暴露
    `set_interact_hint_visible` 的实体根（NPC 根即其 `get_npc_id` 持有者，与
    `_try_interact` 父链解析同款）→ **该实体亮、其余全灭**；无目标 → 全灭；并
    **记住上一帧实体**（脏引用 `is_instance_valid` 守卫），下帧先熄灭。
  - `npc.gd`：**删除**距离判定 `_physics_process`/`_player_locked`/`HINT_RANGE_PX`；
    新增公开开关 `set_interact_hint_visible(v)`（`_hint` 仍私有）。
  - 保留 `is_input_locked`（对话中）收起行为——由控制器 `_resolve_hint_target` 首判。
  - **只加"读取当前目标 + 切换提示"**，未改 `_try_interact` / `dispatch_interaction` /
    `get_npc_id` / `on_interact` / Z·E 键 / InteractBody 任何逻辑。
  - 单次射线/帧（非 12 NPC 各一次），开销可忽略。

### 缺陷②：既有两处提示跨图残留（"没 NPC 的地方也有 !"的真凶）
- **根因**：`town_map._attach_billboard_hint`（:`449-455`）与
  `ruins_f3_map._attach_interact_hint`（:`171-176`）均把 Label 挂
  `get_tree().current_scene`(= 常驻 Main)。Main 只换 `Main/World` 子树
  （`SceneRouter._do_switch`），离开 town/f3 后标签**仍悬在 Main 下继续渲染**
  → 在 road/遗迹的固定世界坐标上飘着（用户所见）；反复进出 town 还**叠加多枚**。
  （此即 #10 原派单预警过的 current_scene 反例，已被实机命中。）
- **修法**：两处均改为**挂本地图根 `self`** 并统一改用 `scripts/ui/world_hint.gd`
  工厂（厂家强制 `z_index=12>Above(10)` → 挂地图根照样恒浮最上，**不再需要靠
  current_scene 求"渲染序最上"**）：
  - `town_map._attach_billboard_hint`：删本地 Label 构造 →
    `billboard_hint = WorldHint.attach(self, p_billboard.position + Vector2(-8,-28), "❗Z", "BillboardHint")`；
    **保留** phase≥1 隐藏门控 + `_on_billboard_phase_changed` 连接；**变量名
    `billboard_hint` 与节点名 `BillboardHint` 兼容**（test_b01_guide /
    dev 冒烟依赖 `town.billboard_hint.text == "❗Z"`）。
  - `ruins_f3_map._attach_interact_hint`：同改工厂 + 挂 `self`；节点名仍
    `InteractHint` 且为**地图根直接子节点**（dev 冒烟 `map.get_node_or_null("InteractHint")`）。
  - NPC 的提示也叫 `InteractHint`，但它是 **NPC 的子节点**，与地图根直接子节点不冲突。
- **附带确认（未动）**：`Main`/`UILayer` 上的常驻装配（menu / map_name_hud /
  quest_objective_hud / dialogue box）是**有意常驻**且有存在性守卫，本次未触碰。

---

## 3. 改动清单（rev2）

| 文件 | 类型 | 改动 |
|---|---|---|
| `scripts/ui/world_hint.gd` | 修改 | `attach()` 增 `p_name` 参数（保留各站点节点名）；头注补 rev2 层位/挂载铁律 |
| `scripts/npc/npc.gd` | 修改 | **删**距离判定 `_physics_process`/`_player_locked`/`HINT_RANGE_PX`；**增** `set_interact_hint_visible(v)` 开关（`_hint` 私有）；头注更新判据 |
| `scripts/events/interaction_controller.gd` | 修改 | **增** `_physics_process` 每帧轮询 → 按 `get_interact_target()` 同源判据切换提示高亮（脏引用守卫）；未触交互分派任何逻辑 |
| `scripts/maps/town_map.gd` | 修改 | 告示板提示改 `WorldHint` 工厂 + 挂地图根（`self`）；保留 phase 门控与 `billboard_hint` 名 |
| `scripts/maps/ruins_f3_map.gd` | 修改 | Boss 锚点提示改 `WorldHint` 工厂 + 挂地图根（`self`）；节点名仍 `InteractHint` 直子节点 |
| `tests/gut/test_m8a2_npc_hint.gd` | 重写 | 10 用例：A 结构 / B 面朝+距离（玩家链）/ C 鲁棒 / D 生命周期 / **E 跨图泄漏回归** |

---

## 4. 红线核对（rev2）

| 红线 | 状态 | 证据 |
|---|---|---|
| 不改交互分派语义 | ✅ | `_try_interact`/`dispatch_interaction`/`get_npc_id`/`on_interact`/Z·E 键/InteractBody 零改动；E 组断言 Z 键目标与提示同源 |
| NPC 仍挂 `YSorted` | ✅ | 未触；test_d1 于 `YSorted` 子中数到 12 NPC |
| Player 仍 `YSorted/Player` | ✅ | 未触城镇装配 |
| 不新增 DialogueRunner 依赖到 npc.gd | ✅ | 对话收起改由控制器读 `player.is_input_locked` |
| 不改 #8/#9 已验收成果 | ✅ | 未触跨图落位/y-sort 相关文件；静态核验器全 PASS |
| 不 commit/push | ✅ | 全程未执行任何 git 写操作 |

---

## 5. 测试证据（GUT）

### 5.1 用例（`test_m8a2_npc_hint.gd`）—— 10/10 通过，42 断言
| 分组 | 用例 | 断言要点 |
|---|---|---|
| A 结构 | `test_a1` | 提示随 NPC 建立；text=❗Z；`z_index=HINT_Z_INDEX`；**z_index>10**；IGNORE；默认隐藏；NPC 暴露开关 |
| B 面朝（玩家链） | `test_b1` | **正后方近距(16px)背离→不亮**（且 `get_interact_target()==null`）；转到正前方命中→亮（且目标非空）；转开→灭；转回→再亮 |
| B 对话锁 | `test_b2` | 面朝亮 → `set_input_locked(true)` 收起 → 解锁恢复 |
| C 鲁棒 | `test_c1` | 无玩家：提示仍建、物理帧后恒隐、不报错 |
| C 鲁棒 | `test_c2` | 裸脚本未入树：无提示、`get_npc_id()` 不受影响、开关 null 守卫安全 |
| D 生命周期 | `test_d1` | 真 town：12 NPC 各持一枚提示、全部 `map.is_ancestor_of(hint)`、根直子节点零泄漏 |
| D 生命周期 | `test_d2` | 提示在宿主子树内；宿主 `free()` 后 `is_instance_valid(hint)==false` |
| E 跨图泄漏 | `test_e1` | **current_scene 非空**装配 town → 告示板提示 `get_parent()==map`（非 current_scene）；current_scene 下零 `BillboardHint`/`InteractHint` |
| E 跨图泄漏 | `test_e2` | 同语境装配 f3 → `InteractHint` 为**地图根直接子节点**、`z_index=12`；current_scene 下零残留 |
| E 跨图泄漏 | `test_e3` | 装配后 `map.free()`（模拟切图）→ 告示板/NPC 提示均 `is_instance_valid==false`；`current_scene.get_child_count()==0`（不叠加） |

**O-7 合规**：B 组一律**玩家链驱动**——设定真实 `player.tscn` 节点的位置 + 朝向 →
等物理帧由控制器调 `player.get_interact_target()`（真射线）自行判定翻转；只读
`hint.visible`，不直驱内部字段。E 组以「current_scene 非空」复刻生产语境触发旧泄漏路径。

> 说明：E 组假 current_scene 命名为 `FakeScene`（非 "Main"）——旧泄漏判据是
> `current_scene != null`（与名字无关），故任意非空即可复现；刻意避开 "Main" 名以免
> 触发 town 的 P0 生产启动守卫（`_assemble_opening_story`）误接线开局触发器。

### 5.2 全量回归（引擎级）—— 全绿
- 环境：headless + `APPDATA` 沙箱重定向 + 运行前清残留 `save.json`
- 结果：**Scripts 38 / Tests 568 / Passing 568 / Asserts 8646 / Warnings 2 / Orphans 10016** → `All tests passed!`
- （日志：`evidence/m8-a2-gut-full.log`）

| 指标 | #10 首版 | rev2 | 差值 |
|---|---|---|---|
| Scripts | 38 | 38 | 0 |
| Tests | 565 | 568 | **+3**（用例 7→10） |
| Passing | 565 | 568 | **+3** |
| Asserts | 8632 | 8646 | **+14**（42 vs 28） |
| Warnings | 2 | 2 | **0** |
| Orphans | 10016 | 10016 | **0** |

→ `Warnings`/`Orphans` 与基线一致；新增的控制器 `_physics_process` 与两处地图提示
改挂未破坏任何既有用例（含 `test_b01_guide`、`e4s6` 自动存档、`t65` 开局、`e1s6` 冒烟）。
**零回归。**

### 5.3 静态核验器 —— 全 PASS（未触地图 tscn/生成器，复核零漂移）
| 核验器 | 结果 |
|---|---|
| `verify_town.py` | **PASS 129 / FAIL 0** ✅ |
| `verify_road.py` | **PASS 66 / FAIL 0** ✅ |
| `verify_ruins.py`（f1+f2+f3） | **PASS 159 / FAIL 0** ✅ |

（日志：`.godot_user_tmp/m8a3_verify.log`）

---

## 6. 引擎风险与知识缺口

1. **像素级遮挡 + 脉冲视觉无 headless 自动断言**：「严格浮于建筑/树冠之上、脉冲可见」
   需人工 F5 目检（与 #9 y-sort 目检同趟）。
2. **`is_input_locked` 语义近似**：它是「输入锁定」而非精确「正在对话」；演出手动锁
   输入时也会收起（更保守，可接受）。零 runner 依赖，守 A7 薄壳边界。
3. **控制器每帧一次射线**：非热路径量级（每帧 1 次，非 12 NPC 各一次）；与
   `_try_interact` 共用 `get_interact_target`，行为一致。
4. **dev 冒烟兼容**：`tools/dev/_b01_smoke_verify.gd`（`town.billboard_hint`）与
   `_o10_smoke_verify.gd`（`map.get_node_or_null("InteractHint")`）依赖的变量名/节点名/
   文案均保持，应仍通过（非 GUT，未随套件跑）。
5. **知识诚实**：`z_index` 全局排序为 Godot 4 稳定语义；引擎 4.7.2 在训练域内。

---

## 7. 附：工作脚本与日志（临时区，不入库）
- `.godot_user_tmp/m8a2v2_targeted.log`：新用例单跑（10/10，42 断言）。
- `evidence/m8-a2-gut-full.log`：全量 GUT 回归（568/568）。
- `.godot_user_tmp/m8a3_verify.log`：三静态核验器日志（129/66/159 全 PASS）。
- 复用运行器 `.godot_user_tmp/m8a1_run.py`（沙箱 + 清残留纪律）。

---

## 8. 用户游戏内复验清单（rev2 重点）
1. **面朝 NPC 才亮**：站到 NPC **正后方**近处（≤1 格）→ 提示**不亮**、按 Z **无对话**；
   转到 NPC **正前方** → 提示亮、按 Z 能对话（提示亮 ⇔ 可交互）。
2. **无游离提示**：在 town、road、遗迹中**不再出现**没有 NPC 的地方飘着「!」。
3. **不叠影**：反复进出 town / 跨图往返 → 提示每次恰一枚，不累积。
4. 对话中（按 Z 开对话框）→ 提示收起；对话结束 → 恢复。
5. 站建筑门/墙后靠近且**面朝** NPC → 提示仍清晰可见（不被建筑/树冠掩）。

---

## 9. rev3（残留缺陷修复：朝向保持 + 去抖）

### 9.1 用户实机复验结论（rev2 后）
- ② 无游离 ❗ ✅ / ③ 不叠影 ✅ / ④ 对话中收起 ✅；
- **① 有残留**，原话：**「正后方,或者其他角度,都会亮一下 ❗,然后不亮。正前方,常亮 ❗,
  期望不是正前方,不要随便亮」**。

### 9.2 根因（两处，均带行号）

**根因 a（主因）：`player.gd:152-160 _update_facing()` 松键后把 `facing` 复位为 `DOWN`。**
- 旧实现：`else:` 分支在缓冲超时（0.15s）后执行 `facing = Vector2.DOWN`（原 `:158-159`）。
- 症状映射：玩家**点一下**朝 NPC 的方向 → 移动当帧 `facing=该方向`（射线命中→亮）；
  松键 0.15s 后 `facing` 被复位为 `DOWN` → 若 NPC 不在正南，射线落空 → **灭**
  （=用户所见"亮一下然后不亮"）；若 NPC 恰在**正南**，复位后 `DOWN` 仍命中 →
  **常亮**（=用户所见"正前方常亮"）。

**根因 b（次因）：移动中 `facing` 随移动方向逐帧变化（`player.gd:153-155`）。**
- 走过 NPC 身旁时朝向在 ±角度间抖动 → 射线命中状态出现**单帧真假** → 提示闪一下。

**验证盲区（为何 rev2 测试没抓到）**：`test_m8a2_npc_hint.gd` 的 rev2 B 组用
`_player.set_physics_process(false)` **冻结**玩家物理 → 真实 `_update_facing` 的
"松键复位"动力学**从未进入被测路径**；用例只直设 `facing` 静态值，故漏检。

### 9.3 修法（按派单实现）

**(1) `scripts/player/player.gd` —— 朝向保持（不复位）**
- `_update_facing()` 的 `else` 分支**只保留缓冲递减删除后无操作**：改为**无输入即保持
  末次朝向**，删除 `facing = Vector2.DOWN` 复位。
- 因复位逻辑删除后 `INPUT_BUFFER_TIME` / `_facing_buffer` 成为死代码（Grep 全项目
  `INPUT_BUFFER_TIME|_facing_buffer` 仅命中本文件 5 处），**一并删除**；`_update_facing`
  签名由 `(dir, delta)` 收敛为 `(dir)`（避免 UNUSED_PARAMETER 警告）。
- 同步：文件头 `:6`、常量区 `:51-57`、`facing` 变量注释、`_ready()` print（`:119`）、
  `_update_facing` 头注。**语义**：`facing` 恒为最近一次非零输入方向——既满足 A6
  原意（规避"按两下方向原地抖"：保持远比 0.15s 久），又消除松键后漂移。

**(2) `scripts/events/interaction_controller.gd` —— 点亮去抖（非对称迟滞）**
- 新增 `const HINT_SETTLE_FRAMES := 3`（≈50ms）与 `_candidate` / `_candidate_frames`。
- `_update_interact_hint()`：**点亮**新目标需**连续 3 物理帧稳定命中**；**熄灭即时**
  （≤1 帧）。无变化则清候选。仍**每帧 1 次射线**、保留 `_hint_target` 脏引用守卫。
- **未加**"移动中不提示"闸门（按派单要求）。

**(3) 二者协同**：根因 a 由 (1) 消除（朝向不再折返）；根因 b 的单帧噪声由 (2) 吸收。

### 9.4 改动清单（rev3）
| 文件 | 类型 | 改动 |
|---|---|---|
| `scripts/player/player.gd` | 修改 | 删松键复位 DOWN；删死代码 `INPUT_BUFFER_TIME`/`_facing_buffer`；`_update_facing` 签名收敛；同步注释/print |
| `scripts/events/interaction_controller.gd` | 修改 | 增去抖 `HINT_SETTLE_FRAMES=3` + `_candidate`/`_candidate_frames`；点亮需 3 帧、熄灭即时；未触分派逻辑 |
| `tests/gut/test_m8a2_npc_hint.gd` | 修改 | 增 **F 组**（非冻结真实玩家 + `set_input_override`）；B 组等帧 2→6（适配去抖）；`_make_led_world` 增 `p_freeze_player` |
| `tests/smoke/headless_e1s6.gd` | 修改 | 同步 `_place_player_facing_guard` 注释（"0.15s 复位"约束已退役） |

### 9.5 测试证据

**(a) F 组 RED → GREEN（先证后修）**
- 用例：`test_m8a2_npc_hint.gd` 新增 F 组（非冻结真实玩家 + `set_input_override`）：
  - **F1（回归红线）** 玩家置 NPC **正北 16px**，`set_input_override(UP)` 2 帧 → 松键
    `ZERO` → 等 12 物理帧（>0.15s）。断言：① `facing` **保持 `UP`**；② 提示**不亮**；
    ③ `get_interact_target()==null`（同源锚）。
  - **F2（正向对照）** 面朝 DOWN 命中 → 亮；松键后 `facing` 保持 DOWN → **仍亮**。
  - **F3（去抖）** 瞬时命中 ≤2 帧 → 提示**全程不亮**（冻结玩家以精确控帧，
    与 B 组同款隔离纪律）。
- **RED（修复前，`.godot_user_tmp/m8a2r3_red.log` → `evidence/m8-a2r3-fgroup-red.log`）**：
  `11/13 passed`，F1 报 3 失败（`VECTOR2(0,1)`≠`VECTOR2(0,-1)` 即 facing 被复位为 DOWN、
  提示误亮、`InteractBody` 非空），F3 报 1 失败（假亮）。
- **GREEN（修复后，`evidence/m8-a2r3-fgroup-green.log`）**：`13/13 passed`，54 断言。

**(b) 全量回归（引擎级）—— 全绿**
- 环境：headless + `APPDATA` 沙箱重定向 + 运行前清残留 `save.json`。
- 结果：**Scripts 38 / Tests 571 / Passing 571 / Asserts 8658 / Warnings 2 / Orphans 10016** → `All tests passed!`
- （日志：`evidence/m8-a2r3-gut-full.log`）

| 指标 | rev2 基线 | rev3 | 差值 |
|---|---|---|---|
| Scripts | 38 | 38 | 0 |
| Tests | 568 | 571 | **+3**（F 组新增 3 用例） |
| Passing | 568 | 571 | **+3** |
| Asserts | 8646 | 8658 | **+12** |
| Warnings | 2 | 2 | **0** |
| Orphans | 10016 | 10016 | **0** |

**(c) 静态核验器 —— 全 PASS**（未触地图 tscn/生成器，复核零漂移）
- `verify_town.py` PASS 129 / FAIL 0；`verify_road.py` PASS 66 / FAIL 0；
  `verify_ruins.py`（f1+f2+f3）PASS 159 / FAIL 0。（日志：`.godot_user_tmp/m8a3_verify.log`）

**(d) 关于 `test_o7_ui_bridge.gd::test_逃跑经信号驱动转发` 的偶发失败（如实记录）**
- 全量首跑出现该用例 1 次失败；经查为**预先存在的 RNG 抖动**，与本次改动无关：
  `battle_command.gd:_do_escape` 用 `randf()` 掷骰，`battle_logic.escape_success`
  以 `roll < escape_chance`（约 70-95%）判定，而用例假定"首拍即成功"。
- 隔离复跑 5 次：**3 PASS / 2 FAIL**（同文件、不改任何代码）→ 证明为随机抖动。
  样本：`evidence/m8-a2r3-o7-flaky-fail-sample.log`。重跑全量即回到 571/571。
- **建议（交主理人）》**：将该用例改为注入确定性 `roll`（`battle_command` 已支持
  `roll` 参数注入）或以多次重试+期望分布断言，根治 flaky（本次未改，避免扩大改动面）。

### 9.6 红线核对（rev3）
| 红线 | 状态 | 证据 |
|---|---|---|
| 不改交互分派语义 | ✅ | `_try_interact`/`dispatch_interaction`/`get_npc_id`/`on_interact`/Z·E 键/InteractBody 零改动 |
| 不改 #8 SceneRouter/触发/落位 | ✅ | 未触；全量 GUT 绿 |
| 不改 #9 五 tscn/WallsObjects 父 | ✅ | 未触；三核验器 PASS |
| 不破坏 rev2 产物 | ✅ | `npc.gd`/`world_hint.gd`/`town_map.gd`/`ruins_f3_map.gd` 未改；rev2 B/D/E 组仍通过 |
| 不新增 .gd 无需 .uid | ✅ | 本 rev3 未新增脚本文件（仅改既有 .gd 与测试） |
| 不 commit/push | ✅ | 全程未执行任何 git 写操作 |

### 9.7 引擎风险与知识缺口（rev3 追加）
1. **朝向语义偏离原 ADR 措辞（已在 M8-B①/#14 同步）**：`docs/architecture/godot4-architecture-adr.md:117`
   与 `production/epics/EPIC-1.md:32` 原写"0.15s 转向缓冲"；本次按用户诉求改为**保持末次
   朝向（不复位）**。该两处措辞已由 M8-B①（#14）同步为"松键后保持末次朝向（不复位）"
   （条款编号与结构未动）。
2. **修复不依赖知识缺口**：`_update_facing`/去抖均用 Godot 4 稳定语义（节点
   `_physics_process` 顺序、信号时序），4.7.2 在训练域内。
3. **像素级观感留人工**：去抖阈值 50ms 的"手感"、朝向保持的待机观感，需 F5 目检。
