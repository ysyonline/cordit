# 《轨迹残响》技术搭建文档 · Godot 4 架构 + ADR + 学习路线

> 作者：程基岩（engineering-lead）｜阶段：技术预研/架构｜服务范围：垂直切片 Must-have 109h
> 引擎版本基线：**Godot 4.3+**（4.4 亦可，以下均兼容；文档涉及 TileMapLayer 多层 y-sort 需要 4.3+）
> **勘误注记（2026-08-29，用户拍板）**：本机实际安装 Godot 4.7.x，本项目直接用 4.7（基线"4.3+"覆盖，切片内只用稳定 API 面；W3 装 GUT 时核实其 4.7 兼容版本）。
> 汇编：游承峰（team-lead）。与战斗 GDD 的对齐裁决见 `design/gdd/phase2-3-alignment-review.md`

---

## A. 主架构文档

### A1. 总原则：切片架构三条铁律

1. **薄路径优先**：第 1-2 周先打通"走路→遇敌→打赢→回到地图→存档"的最短纵向路径，哪怕全部是占位美术。所有系统先以"能被主流程调用"的形态存在，再横向加厚。
2. **数据进、数据出，系统互不 import**：地图场景不认识战斗场景，战斗场景不认识地图场景，二者只通过一个纯数据载荷通信（见 A5）。这样任何一个系统做坏了都不阻塞里程碑。
3. **为 90 小时产能设计，不为 900 小时设计**：Cut 清单里的系统（导力器配置、多结局 flag、编成、昼夜）**不为它们预留任何扩展点**。留扩展点是另一种形式的提前实现。

### A2. 目录结构（scenes/ 与资源组织约定）

```
res://
├── autoload/            # 全局单例脚本（见 A3）
│   ├── game_data.gd
│   ├── event_bus.gd
│   ├── scene_router.gd
│   └── save_manager.gd
├── scenes/
│   ├── main/            # Main.tscn（唯一常驻根，见 A4）
│   ├── maps/            # 每张地图一个 tscn：town.tscn, road.tscn, ruin_f1/f2/f3.tscn
│   ├── battle/          # battle.tscn（战斗共用一个场景，敌人配置数据驱动）
│   ├── actors/          # player.tscn, npc.tscn, visible_enemy.tscn
│   ├── ui/              # dialogue_box.tscn, main_menu.tscn, battle_ui.tscn
│   └── events/          # 事件触发器：trigger_chest.tscn, trigger_dialogue.tscn, trigger_encounter.tscn 等（薄场景，行为由 JSON 驱动）
├── scripts/
│   ├── core/            # 纯逻辑类：battle_logic.gd, action_queue.gd, damage_calc.gd（无场景依赖，可单测）
│   ├── actors/          # 角色/敌人运动、交互
│   ├── dialogue/        # dialogue_runner.gd, dialogue_parser.gd
│   └── save/            # 序列化器
├── data/
│   ├── json/            # 对话脚本、事件脚本（见 A6）：dialogues/*.json, events/*.json
│   └── resources/       # items/*.tres, skills/*.tres, enemies/*.tres
├── assets/
│   ├── tiles/  characters/  enemies/  ui/  fonts/  sfx/
│   └── (来源登记表放 assets/CREDITS.md，对应美术守则第 5 条)
└── tests/               # Gut 或 GdUnit4 测试（battle_logic 优先覆盖）
```

**约定**：
- `scripts/core/` 里的战斗逻辑**绝不** `get_node()` 进场景树——它是纯函数式的"输入指令+状态 → 输出结果"，这样回合结算可以脱离渲染做平衡测试（对应数值平衡 12h 的效率）。
- 场景（.tscn）只做"视图+装配"，逻辑尽量下沉到挂载脚本；每个系统有唯一入口脚本。
- 新手注意：Godot 的 `.tscn` 是文本格式、会进 git 冲突——**一次只开一个场景编辑器窗口**，可大幅减少合并痛苦。

### A3. Autoload 单例边界（只建 4 个，不多建）

| 单例 | 职责 | 明确不管 |
|---|---|---|
| `GameData` | 运行时游戏状态：队伍三人 HP/MP/等级/技能/道具/装备、当前剧情阶段 `story_phase`、已开宝箱集合、金钱 | 不做任何 IO；不感知 UI；不发业务信号 |
| `EventBus` | 全局信号总线：`enemy_touched(payload)`, `dialogue_finished(event_id)`, `battle_finished(result)`, `story_phase_changed(n)`, `save_requested` 等 | 不存状态、不写逻辑，只声明信号 |
| `SceneRouter` | 封装 `change_scene_to_packed` + 场景切换时的过渡遮罩 + 载荷暂存（见 A4） | 不知道具体场景内容，只管"切" |
| `SaveManager` | 读写单存档槽 `user://save.json`；定义"什么状态可存"快照协议（见 ADR-3） | 不决定何时存——存档时机由事件脚本/UI 触发 |

**反模式警告**：不要建 `Global.gd` 大杂烩；不要建 AudioManager/SettingsManager——切片内音效走 Should-have，到时再评估。Autoload 数量超过 6 个就是架构气味。

### A4. 场景切换方案：Main 常驻 + Router 切换

结构：

```
Main.tscn（autoload 之上的常驻根，可选但推荐）
├── World 层    ← 装载 当前地图 or 战斗场景（SceneRouter 替换）
└── UILayer 层  ← 对话框 / 菜单 / 过渡遮罩（跨场景常驻）
```

- **为什么不直接用 `get_tree().change_scene_to_file()`**：切场景时对话框、过渡遮罩会被一起销毁。用常驻 UILayer，对话可以跨"剧情阶段切换"连续存在，过渡遮罩可以做 0.2s 淡入淡出（廉价但立刻有"正经游戏"感）。
- 流转：`地图(触发遇敌) → EventBus.enemy_touched(BattlePayload) → SceneRouter.load_battle(payload) → 战斗结算 → EventBus.battle_finished(BattleResult) → SceneRouter.load_map(return_payload)`。
- **每 2 周里程碑怎么保**：Router 切到任何场景前先检查 payload 合法性，不合法则拒绝切换并打印原因——早期就把"切场景把游戏切崩"这类事故挡在数据校验层。

### A5. 地图系统 ↔ 战斗系统解耦（遇敌传什么）

核心是一对**纯数据结构**（GDScript class，无节点依赖）：

```
BattlePayload（地图 → 战斗）:
  enemy_group_id: String        # → data/resources/enemies/*.tres 里查敌人配置
  return_map: String            # 场景路径
  return_position: Vector2      # 玩家战后回置点（敌人位置旁一格）
  defeat_enemy_uid: String      # 战胜后从地图移除哪个敌人节点

BattleResult（战斗 → 地图）:
  outcome: VICTORY / DEFEAT / ESCAPE
  party_state: Array[dict]      # 战后每人 HP/MP/状态（GameData 直接据此覆写）
  exp_gained, gold_gained, items_used: Array  # 结算写回
```

- 战斗场景**从 GameData 读队伍初始态、向 GameData 写结果态**，地图场景只监听 `battle_finished` 后做两件事：删敌人节点、刷自己。地图与战斗零互相引用。
- 失败处理按 GDD 3.5 执行（见对齐报告裁决 1）：自动读档至进入当前地图时的存档点。
- `gold_gained` 字段保留但切片内恒为 0（GDD 已裁决切片无商店；保留字段避免未来加商店时改协议）。

### A6. 地图分层：TileMapLayer + y-sort（Godot 4.3 正确姿势）

每张地图一个场景，内含多层 **TileMapLayer**（4.3 起弃用单 TileMap 多 layer 的旧 API，直接用多个 TileMapLayer 节点）：

```
Map（Node2D）
├── Ground          (TileMapLayer, z=-10)      地面
├── GroundDeco      (TileMapLayer, z=-9)       地面装饰/路面
├── YSorted         (Node2D, y_sort_enabled=true, z=0)
│   ├── WallsObjects (TileMapLayer, y_sort_enabled=true)   墙、树、房子、柜台等"角色可站到其后方"的 tile
│   ├── player / npcs / visible_enemies / 宝箱          （CharacterBody2D / StaticBody2D，原点设在脚底）
├── Above           (TileMapLayer, z=+10)      树冠、屋檐等始终盖在角色头上的部分
└── Triggers        (Area2D 子节点集合)        事件触发区
```

要点：
- **碰撞不是一层独立图层**，直接在 TileSet 资源里给物理层配置 collision shape（多层各自可挂）。
- y-sort 生效的充要条件：父节点 `y_sort_enabled=true` 且**所有参与排序的节点在同一个父节点下**；角色节点原点必须在脚底（sprite 偏移上移），墙 tile 的原点在其底部——这是 2.5D 纵深感 80% 的来源，花半天调对一次，之后全项目复用。
- 玩家移动用 `CharacterBody2D + move_and_slide()`，16x16 tile、移动速度建议 4-5 tiles/s，带一个 0.15s 的转向缓冲避免"按两下方向原地抖"。

### A7. 对话事件系统：数据驱动的最小完整方案

三层结构：

1. **触发器（场景侧）**：`events/trigger_*.tscn` 是薄壳——一个 Area2D + 脚本，属性只有 `event_id: String`。交互/踩踏/剧情阶段判断全部委托给 JSON。
2. **事件脚本（data/json/events/*.json）**：
```json
{ "event_id": "ruin_f1_chest_01", "conditions": { "story_phase": [">=", 1], "not_flag": "chest_f1_01" },
  "actions": [ {"type":"give_item","id":"potion_s","count":2}, {"type":"set_flag","flag":"chest_f1_01"},
               {"type":"dialogue","id":"chest_open_generic"}, {"type":"save_point"} ] }
```
   动作类型切片内只需要 8-10 种：`dialogue / give_item / set_flag / check_flag / battle / heal / teleport / save_point / wait / play_sfx`。**就此打住**，不要做通用脚本语言。
3. **对话脚本（data/json/dialogues/*.json）**：条目式，`speaker / portrait / text / next / choices(可选)`。逐字显示由 `DialogueBox` UI 定时器实现（约 30 字/秒，按键跳过→整段），带打字机音效钩子（Should-have）。
- **NPC 阶段刷新对话**：NPC 节点只有 `npc_id`，运行时按 `story_phase` 从对话 JSON 里选 `"dialogue_id": {"0": "npc_a_phase0", "1": "npc_a_phase1", ...}`——这就是 Cut 清单外唯一的状态机制，且只需一个 int。
- 运行器 `DialogueRunner` 是一个状态机：`IDLE → PLAYING → WAITING_CHOICE → PLAYING`，通过 EventBus 与地图交互（对话时锁玩家移动）。约 200-300 行可完成。

### A8. 里程碑保障机制（回应"每 2 周必须能玩"）

| 周 | 里程碑 | 可玩验证标准 |
|---|---|---|
| 1-2 | 能走路的世界 | 小镇地图 + 玩家移动/碰撞 + 1 个 NPC + 1 段对话 |
| 3-4 | 遇敌能打 | 可见敌人 + 切入战斗（占位 UI）+ 攻击/防御 + 胜负回到地图 |
| 5-6 | 战斗是"游戏" | 速度队列 + 技能 + 三系克制 + 战斗 UI 成型；**UI 在此必须存在**（对应坑 5 规避③）|
| 7-8 | 遗迹可探索 | 遗迹三层 + 宝箱/调查 + 存读档（单槽）；**存档在此必须存在** |
| 9-10 | 剧情串起来 | 4 张图 + 剧情阶段机制 + NPC 阶段对话 + Boss |
| 11-12 | 结算完整 | 逃跑/失败结算 + 菜单 UI（道具/装备）+ 队员聊天 |
| 13-14 | 打磨发布 | 数值平衡 5 场战斗过"三问测试" + 导出 Windows 包 |

架构对里程碑的直接支撑：① 系统间零 import，任何一个里程碑延期不阻塞下游（Router 接到空 payload 会安全拒绝）；② 战斗逻辑与渲染分离，平衡调整不碰场景；③ 对话/事件全 JSON，策划内容（剧情 16h）不需要改代码就能迭代。**第 6-8 周弃坑高发期恰好落在里程碑 3（战斗成型）+ 存档落地之后——把两个"无聊但必需"系统压在弃坑窗口之前，是有意的排程。**

---

## B. 架构决策记录（ADR）

### ADR-1：脚本语言选型 → GDScript（带渐进类型标注）

- **背景**：开发者是 TS/JS 前端工程师，无游戏开发经历、无 C#/.NET 经验；业余时间每周 5-10h；项目为单机回合制，无性能热路径。
- **备选**：① GDScript；② C#；③ 纯 C# core + GDScript 粘合。
- **决策**：**全部 GDScript**，启用类型标注（`func damage(atk: int, def: int) -> int:`），从第一行代码就写类型。
- **理由**：
  1. 回合制战斗的 CPU 开销小到可以忽略，C# 的性能优势在本项目**用不上**；
  2. Godot 的教程/问答/AssetLib 生态 90% 是 GDScript，第一次做游戏时"遇到问题搜得到答案"的价值远高于静态类型收益；
  3. 双语言方案增加的是**心智切换成本**（两套构建、两套调试器），对单人业余项目是纯负债；
  4. GDScript 4.x 类型标注已可覆盖 TS 用户在意的"变量拼错早发现"需求，且语法对 JS 用户几乎零门槛（信号 ≈ EventEmitter、await/协程手感相似）。
- **后果**：正——学习曲线最短、热重载快、文档素材多；负——编辑器补全弱于 IDE 的 C#，大型重构靠搜索而非语义分析（切片规模 ~5k 行内可控）。若未来正式版做复杂系统，届时单模块迁移 C# 的成本是可控的（core/ 目录已是纯逻辑类）。

### ADR-2：对话/事件数据格式 → JSON（内容）+ 自定义 Resource（数值定义）

- **背景**：对话与事件内容约 250-350 条，策划内容预期频繁改动；用户熟悉 JSON；数值定义（物品/技能/敌人）需要引用贴图等引擎资源。
- **备选**：① 全 JSON；② 全 Godot Resource（.tres）；③ 数据库/表格工具。
- **决策**：**对话脚本与事件脚本用 JSON 文件；物品/技能/敌人等数值定义用自定义 Resource（.tres）**。
- **理由**：
  1. JSON 对高频改动的文本是最优解：纯文本、git diff 友好、可用任何外部工具批量生成/校对，且用户已有 JSON 心智——**这是把用户已有技能直接变现的地方**；
  2. 数值定义走 Resource 的关键收益是**编辑器引用**：技能资源里可以直接拖入图标、特效场景、目标选择策略，类型检查由引擎兜底，比手写 JSON 字符串 ID 少一整类"ID 打错字运行时才炸"的 bug；
  3. 全 Resource 的坏处：.tres 对文本内容极不友好（转义、diff 噪音），改 10 条对话就要开 10 次编辑器；全 JSON 的坏处：贴图引用要用 `load(path)` 字符串拼，失去编辑器校验。
- **后果**：正——内容迭代与工程迭代解耦（策划改 JSON 不动场景）；负——需要手写一个 ~80 行的 JSON schema 校验器 + 加载器（一次性成本，里程碑 2 前完成）。**正式版再考虑**：本地化、对话图编辑器、表格导入管线。

### ADR-3：存档方案 → JSON 手写字段序列化（不用 Resource 序列化）

- **背景**：Godot 4 教程普遍教 `ResourceSaver.save()` 存自定义 Resource；单存档槽、自动存档点 + 手动存档。
- **备选**：① Resource 序列化（`ResourceSaver`）；② JSON 手写字段序列化；③ var_to_str/str_to_var。
- **决策**：**JSON 手写序列化**——`SaveManager` 维护一个显式的 schema：`{ "version": 1, "map": "...", "position": [...], "party": [...], "story_phase": n, "flags": [...], "chests_opened": [...], "discovered_weakness_set": [...], "cleared_enemy_set": [...] }`，写入 `user://save.json`。
- **理由**：
  1. Resource 序列化的经典事故是**存档里直接存了场景/节点引用**——改一次场景结构，旧存档全部失效甚至崩溃加载；手写 JSON 强迫你只存"游戏状态的值"，天然规避此坑；
  2. 存档格式版本化（`version` 字段 + 迁移函数）在手写方案里是一行 if，在 Resource 方案里是玄学；
  3. `user://save.json` 可被用户手改——对单机切片这**不是缺点**，是玩家福利，且便于你自己调试（直接改数值测试 Boss 战）；
  4. JSON 明文 + 手写 schema 也让存读档成为新手可以逐字段理解的功能，降低实现风险（5h 预算内最稳的路径）。
- **后果**：正——版本兼容可控、可调试性强、实现透明；负——每加一个可存状态要同步改 schema（用一条 checklist 约束：GameData 任何新字段加入时必须同时问"它进不进存档"）。安全上无需求做加密（正式版再考虑），至多 base64 混淆。

### ADR-4：像素渲染设置 → 独立低分辨率 viewport + 整数缩放

- **背景**：Time Fantasy 16x16 tile、2 头身角色、×3/×4 整数缩放、统一左上光照（美术守则第 2.1 条）。
- **决策**（一套固定配置，写进项目设置后不再动）：
  - **视口分辨率**：`640×360`（=16px tile 的 40×22.5 格，×3 整数缩放到 1080p），项目设置 Project Width/Height 填 640/360；
  - **Stretch Mode**: `canvas_items`，**Stretch Aspect**: `keep`（黑边不接受非整数拉伸）；
  - **默认纹理过滤**: `Nearest`（Project Settings → Rendering → Textures → Canvas Textures → Default Texture Filter）——16x16 素材模糊的最大元凶就是默认的 Linear；
  - **缩放**: `integer`（Display → Window → Stretch → Scale Mode = integer，4.x 支持）；
  - 2D 渲染（Compatibility/GLES3 渲染器即可，切片不需要 Forward+ 特性，且低端机兼容更好）；
  - `Snapping → 2D → snap_2d_transforms_to_pixel = true`，防 subpixel 抖动。
  - UI 独立于游戏像素风：中文像素字体（Fusion Pixel，见美术补位表）按 viewport 内 16px 网格设计字号，禁用系统字体。
- **理由**：这是 Godot 4 做像素游戏的社区标准配置，一次设置全场受益；640×360 下 16x16 tile 呈现粒度与空之轨迹式信息密度匹配，且天然支持全屏整数放大不糊。
- **后果**：正——零成本获得"锐利像素"观感；负——所有 UI 必须在 640×360 内设计（字号、九宫格窗体都要按小尺寸做），后期想改视口分辨率成本极高，**立项第一周就定死**。镜头跟随用一个 `Camera2D`（position smoothing 开启，snap to pixel 关闭以避免平滑与 snap 打架，实测取舍见里程碑 1）。

---

## C. Web 前端工程师的 Godot 学习路线

### C1. 概念映射表

| 前端概念 | Godot 概念 | 备注 |
|---|---|---|
| 组件 Component | **Node** | Godot 的 Node ≈ 深度耦合了生命周期的组件 |
| 组件树 / App 树 | **Scene（.tscn）→ 场景树** | Scene 是"可复用的子树文件"，≈ 一个自定义元素的定义文件 |
| `<MyWidget />` 实例化 | 实例化 Scene 为子节点 | 组合优于继承，与 React 哲学同源 |
| 生命周期 useEffect | `_ready()` / `_process(delta)` / `_physics_process()` | `_ready` ≈ mount；`_process` ≈ 每帧 rAF 回调 |
| EventEmitter / 自定义事件 | **Signal**（`signal hurt; emit_signal("hurt")` / `hurt.connect(fn)`） | 加 `await some_signal` 就是 Promise 式写法 |
| props / 状态提升 | 节点属性 `@export var speed := 80` | export 后在编辑器 Inspector 里可调 |
| Context / 全局 Store | **Autoload 单例** | 本项目限定 4 个，见 A3 |
| 资源（数据） | **Resource**（.tres/.res） | ≈ 一个被引擎缓存和引用追踪的数据对象 |
| npm / package.json | **AssetLib（内置）** | 但本切片几乎不需要插件——引擎自带功能够用 |
| TypeScript 类型标注 | GDScript 类型标注（`:int`, `-> void`） | 写！从第一行就写 |
| `import` | `preload()` / `load()` | preload ≈ 静态 import，load ≈ 动态 import |
| async/await | `await`（对信号用）| `await get_tree().create_timer(0.5).timeout` ≈ sleep |
| rAF / 游戏循环 | 引擎主循环（不用自己写） | 忘掉手动循环，信任 `_process` |
| CSS 布局 | Control 节点锚点/容器（VBoxContainer 等） | 只用于 UI；地图世界不用它 |
| React DevTools | 远程调试器 / Debugger 面板 / print() | 断点、监视、性能剖析器都在编辑器底部 |

### C2. 两周学习计划（每周 5-10h，产出物全部直接进项目）

**第 1 周（约 6-8h）：会走路的小镇 = 官方教程 + 里程碑 1 合体**
- 目标：学会编辑器五大件（场景面板/文件系统/Inspector/调试器/文档 F1），能自己搭场景、连信号、写脚本。
- 路径（按序，共约 4h 素材学习）：
  1. 官方"你的第一个 2D 游戏"（Dodge the Creeps）教程跟完——**不要跳**，它就是本项目所需技能的 80%：移动、碰撞、信号、场景实例化、UI；
  2. 现查现学：TileMapLayer 画地图 + TileSet 物理碰撞（官方文档 2D 部分即可）。
- 练习 = **直接做里程碑 1**（约 3-4h 动手）：建项目，按 ADR-4 设定渲染；Time Fantasy 素材导入（import 时确认 filter）；小镇一张图 + 玩家 CharacterBody2D 八向移动 + 1 个 NPC（按 E 触发一段写死的对话 Label）。完成标准：**能在 1080p 全屏锐利地跑图、撞墙正常、能和 NPC 说话**。这就是第一个 5 分钟试玩视频素材。

**第 2 周（约 6-8h）：状态与数据流 = 把 JS 心智搬进来**
- 目标：吃透 Autoload/信号/场景切换三件套——这是本架构的骨架。
- 路径：官方文档《Scene tree》《Singletons (Autoload)》《Signals》三篇精读（约 2h）；其余全部动手。
- 练习 = 里程碑 1 收尾 + 里程碑 2 起点（约 5h）：
  1. 建 4 个 Autoload 空壳（按 A3 边界写好信号声明）；
  2. 建 Main.tscn + UILayer，实现 SceneRouter 的地图间切换（小镇→道路，走地图边缘传送点）；
  3. 队伍数据进 GameData（3 个角色的 HP/MP 硬编码即可），做一个按 M 打开的调试面板显示数据；
  4. 放一个可见敌人，接触时 EventBus 发 payload、Router 切到一张**纯色背景+9 个彩色方块**的占位战斗场景（不实现战斗逻辑），打赢/打输各一个按钮切回地图并写回数据。
- 完成标准：**数据能从地图流进"战斗"再流回地图**。做到这里，最难的建筑学部分已经走完，剩下的是往骨架上长肉。

**学习原则**：每一小时学习必须有一小时立刻用在本项目上；教程完成度 80% 即推进，不追求"学完再做"。

### C3. 明确"不要学"清单（防范围膨胀）

- ❌ **3D 一切**（节点、光照、相机）——本项目纯 2D；
- ❌ **Shader/GLSL**——切片内所有视觉效果用动画/贴图/CanvasModulate 实现，shader 深水区留给正式版；
- ❌ **多人网络 / RPC / Dedicated server**——单机游戏，一个字都不看；
- ❌ **GDExtension / C++ / C#**——ADR-1 已裁决；
- ❌ **插件/编辑器扩展开发**——切片不需要装任何插件；
- ❌ **动画系统深水区**（AnimationPlayer 高级用法、Skeleton2D、IK）——角色动画用素材包自带帧序列 + AnimatedSprite2D 即可；
- ❌ **物理引擎深水区**（Rigidbody、Joint、自定义积分）——只用 CharacterBody2D/Area2D；
- ❌ **音频管线**——Should-have 阶段现学现用（AudioStreamPlayer 是十分钟级知识）；
- ❌ **导出模板多平台**——只配 Windows 导出，其他平台正式版再说；
- ⚠️ **TileSet 高级地形系统**（terrain set 自动拼接）可以了解概念，但**不要**为它重构已有的手摆地图。

---

## 移交说明

1. **给 design-strategist**：A7 的事件动作类型清单（10 种）与对话 JSON 字段，是"回合制战斗 GDD"之外剧情片段（16h）的格式契约，请剧情写作时按此结构产出，避免二返工。战斗 GDD 中的速度队列/克制数值，直接在 `scripts/core/battle_logic.gd` 纯函数层定义，便于数值平衡自动化测试。
2. **给 art-director**：ADR-4 的 640×360 视口是硬约束，请 UI 补位方案（9-slice 窗体、像素字体字号）按此分辨率设计；素材导入清单请同步 assets/CREDITS.md 约定。
3. **待用户拍板项**：① ADR-1/2/3/4 四条决策如无异议即冻结；② 视口 640×360 定死（影响全部 UI 与地图构图，第 1 周必须确认）；③ 学习路线第 1 周从官方 2D 教程起步的安排是否符合用户当前进度。
4. **风险与知识缺口**：Godot 4.4 的 Stretch Scale Mode "integer" 细节行为建议实测验证一次（不同 Godot 小版本有微调）；其余所用 API 均为 4.3+ 稳定接口，无臆造。

—— 程基岩，技术架构完毕。
