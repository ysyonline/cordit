# 《轨迹残响》地图 3D 化评估 · 决策材料（未定论）

> 作者：程基岩（engineering-lead）｜性质：**纯评估文档，不含实现、不改任何代码/场景/数据/ADR**；未做任何 git 操作
> 评估对象：`docs/architecture/godot4-architecture-adr.md` 的 **A8 冻结架构**（七里程碑 + 五图）与现行 2.5D 地图体系
> 触发背景：用户 M8 反馈第 ⑤ 条"地图想探讨 3D 化"——本文只把选项摆清楚，**结论权在用户**
> 引擎基线：Godot 4.7.2（GL Compatibility 渲染器，`project.godot:15`）；仓库 HEAD=ef4eb82
> 验证纪律：本文引用现状一律带 文件:行；凡无法在本机/文档确认的，标注"未确认（原因）"，不臆造。

---

## 0. 一页决策摘要表

| 选项 | 一句话定位 | 工作量（卡×0.5d） | 对 A8 冻结架构冲击 | 对 ADR-4 整数缩放/像素铁律 | 核心风险 | 回滚性 | 当前阶段收益判断 |
|---|---|---|---|---|---|---|---|
| **O 基线：保持现状** | 2D 平面 + 已有光照/装饰增强；"纵深感"按③类诉求交美术演出打磨 | 0（若走③类打磨另计美术口径） | 零 | 零冲突 | 低（唯一成本是⑤反馈未被直接回应） | — | **正收益**（不扰动已收口的 558 测试绿基线） |
| **A 伪 3D 增强**（②类） | 2D 玩法与场景树零改动：视差远景 + LightOccluder2D 阴影 + 局部浮空/高度演出 | 3–6 卡（1.5–3d） | 小：全部以增量装配器落位（M7-A1 光照同款手法），五图复用 | 低风险，但必须钉死"不开 shadow 级开销、不做非整数变换"的子约束 | 中低：阴影在 16px 网格上易碎、视差与 YSorted 分层可能打架 | 单卡级（每项独立开关，逐项撤） | **中性偏正**：可作试点，但不解决"想看立体"的原始想象 |
| **B 斜投影/伪透视改造**（②类重口径） | 仍是 2D 玩法，但呈现层做 skew/Shader 伪透视 + 高度坐标体系 | 10–18 卡（5–9d） | 中：生成器→verify→y-sort 校准→五图全量重生成，A8 里程碑 1–2 的产物大面积重验 | **高冲突**：Nearest + snap_2d_transforms_to_pixel 下非整数变换产生像素噪点/抖动（见 §4.5），需先 spike 实验验证 | 中高：像素观感可能整体劣化；工作量集中在"视觉正确性反复调" | 分支回滚可行，但沉没成本集中 | **当前切片阶段大概率负收益**（打断 M8 收口节奏，收益不确定） |
| **C 整体换 3D 渲染**（①类） | 3D 场景 + 像素贴图/Sprite3D 混合 + 3D 相机 | 40–70 卡（20–35d+） | **颠覆**：A8 七里程碑产物全部重做；五图全部重建；光照/相机/碰撞/传送/事件锚点全部重写 | **颠覆**：640×360 + integer + Nearest 体系整体不适用，需为 3D 重建一套像素呈现管线（Godot 4.7 新增 3D 最近邻过滤可缓解，见 §4.6） | 极高：单人业余 5–10h/周节奏下≈2–4 个月纯改造期 | **不可行**（等于重启新项目，2D 切片只能封存） | **明确负收益**（与 M8 方向提案 A–D 四选项全部冲突） |

> 阅读指引：同一句"地图 3D 化"背后可能是三种成本差 10 倍以上的诉求，先读 §2 问题定义再回看本表。

---

## 1. 现状盘点（实证）

### 1.1 地图分层与渲染顺序

每张地图场景的分层（以 town 为实证，其余四图同构）：

```
Map_Town (Node2D)                                    town.tscn:10
├── VoidBackdrop_A/B (Polygon2D, z=-20)              town.tscn:13-21  室内黑幕框
├── Ground (TileMapLayer, z=-10)                     town.tscn:23-26  地面
├── GroundDeco (TileMapLayer, z=-9)                  town.tscn:28-31  地面装饰
├── YSorted (Node2D, y_sort_enabled=true)            town.tscn:33-34
│   ├── WallsObjects (TileMapLayer, z=0, y_sort_enabled=true)  town.tscn:36-40
│   ├── NPC_Anchors / Chest / P0_Anchor / Player     town.tscn:49-94
├── Above (TileMapLayer, z=+10)                      town.tscn:42-45  树冠/屋檐
├── Triggers (Node2D)                                town.tscn:47
└── (运行时装配) Lighting 容器                        town_map.gd:430-432
```

关键近期变化——**M8-A③（#9）刚把五图 WallsObjects 从地图根直子节点移入 `YSorted` 子树**
（z=+10 树冠语义澄清：树冠/屋檐仍在 `Above` z=+10；本次移的是"建筑立面/树干/柜台"这层）：

- 改动本身：`[node name="WallsObjects" ... parent="."]` → `parent="YSorted"`，每图仅此一行
  （`evidence/m8-a3-walls-into-ysorted.md:106-109`）。
- 动机与原理：Godot y-sort 只对**同一 y-sort 父节点下的兄弟**排序；此前 WallsObjects 与
  Player 不在同一父节点下，恒定覆盖/被覆盖，2.5D 遮挡纵深完全不生效（同档 :17-36）。
- 防漂移守卫：引擎级测试 `tests/gut/test_m8a3_walls_ysorted.gd`（五图 instantiate，40 断言）；
  全量回归 Scripts 37 / Tests 558 / Passing 558（`evidence/m8-a3-walls-into-ysorted.md:188-192`）。
- 架构正本：ADR A6 结构图 `docs/architecture/godot4-architecture-adr.md:103-112`，y-sort 充要
  条件 `:116`（"所有参与排序的节点在同一个父节点下"）。

### 1.2 y-sort 机制与 y_sort_origin 校准

- tile 侧：Walls/建筑类 tile 的 `y_sort_origin = 8`（16px tile 的底边）已在
  `assets/tiles/town_map_tileset.tres` 全量设定（grep 命中 10+ 处，如 `0:26/0/y_sort_origin = 8`）；
  遗迹侧同口径（`evidence/m8-a3-walls-into-ysorted.md:49-51`：`ruins_tileset.tres` 全部 Walls tile 已设）。
- 角色/实体侧：原点=脚底。player.tscn 根节点 (0,0) 即脚底触地点，Body 精灵 position (0,-9)
  上移锚定（`scenes/player.tscn:8-16,48-54`）；NPC/宝箱/锚点均按"摆到锚点脚底位"装配
  （`scripts/maps/town_map.gd:224-240`）。
- 排序语义：每个 Walls tile 以底边 y、玩家以脚底 y 参与同一轮 y 升序绘制——玩家脚底 y 大于
  tile 底边 y 时玩家后绘（遮挡建筑下沿），反之被遮（`evidence/m8-a3-walls-into-ysorted.md:217-220`）。

### 1.3 player.tscn 的 Camera2D 配置

- `position_smoothing_enabled = true`，`position_smoothing_speed = 8.0`
  （`scenes/player.tscn:71-73`）。
- **Godot 4.x 相机级无 snap 属性**——A6 所指"snap 关以避免与平滑打架"由 ADR-4 的全局
  `snap_2d_transforms_to_pixel` 承担，此处无可调项（`scenes/player.tscn:32-35` 注释）。
- 相机限区由各图脚本 export 三组 Rect2i 下发（town 主图 1024×768px=64×48 tile，室内黑幕框
  640×360=视口尺寸、相机实际静止；`scripts/maps/town_map.gd:37-39` 与 `_apply_limits` :274-278）。

### 1.4 ADR-4 的整数缩放体系（对 3D 化最硬的约束）

| 项 | 现值 | 出处 |
|---|---|---|
| 视口 | 640×360 | `project.godot:27-28` |
| Stretch | `canvas_items` + scale_mode `integer` | `project.godot:29-30` |
| 默认纹理过滤 | `default_texture_filter=0`（Nearest） | `project.godot:93` |
| subpixel 防抖 | `snap_2d_transforms_to_pixel=true` | `project.godot:96` |
| 渲染器 | GL Compatibility | `project.godot:94-95`；ADR-4 亦定 2D 不需 Forward+（`godot4-architecture-adr.md:196`） |
| 决策性质 | ADR-4 明文"一套固定配置，写进项目设置后不再动""后期想改视口分辨率成本极高" | `godot4-architecture-adr.md:190-200` |

### 1.5 MapLighting（M7-A1 光照层）做了什么

- 纯装配、config 字典驱动的静态工厂（`scripts/maps/map_lighting.gd:41-91`）：产出
  CanvasModulate 全图压色 + N 处静态 PointLight2D（光斑纹理 = GradientTexture2D 代码生成，
  零新图片资产）+ 玩家随身提灯光（运行时挂 Player 子节点）+ flicker 光呼吸 Tween。
- town 实配 7 处光源（喷泉/炉火/存档点/烛光/封印门/南门路灯/客栈门灯，前两者呼吸；
  `scripts/maps/town_map.gd:152-172`），Lighting 容器挂地图根、**y_sort 之外**（:430-432）。
- **阴影刻意未开**：全部光源 `shadow_enabled = false`，头注明示"16px tile 阴影开销大且易闪，
  A1 不开"（`scripts/maps/map_lighting.gd:74,123` 与 :28）——这是 ②类"阴影增强"的现成接入点，
  也是其风险提示的第一手出处。
- 范围红线：仅 town 接线；遗迹/road 不动（同档 :7-8）。

### 1.6 资产侧硬约束

- 在库账本：**6 件图片资产 = 3×CC0 + 3×CC-BY，0×SA + 0×GPL**；字体 Fusion Pixel CC-BY 4.0
  （OFL 系匿名Pro 等 GUT 附带字体另计）——正本 `production/asset-intake-list.md`（"当前入库"
  行、"入库红线：CC-BY-SA 与 GPL-only 资产禁止入库"行）。
- **禁入清单有实例**：bart「16x16 Castle Tiles」因页面含 GPL 2.0/3.0 与 CC-BY-SA 3.0 档被
  判禁入（同档"禁入（账本红线）"行）；LPC32 体系同守"账本不恶化"裁决。
- tileset 规模：town_map_tileset.tres 四图集（town/forest/temple/oga，`tools/gen_town.py:6,36-37`）；
  遗迹单图集 classical_temple_tiles（`tools/gen_ruins.py:6`）。
- **对 3D 化的含义**：账本全部是 2D 像素资产（16×16 tile 网 / 16×18 帧网）。①类整体换 3D
  意味着资产账本整体作废重开（3D 模型或 3D 化像素管线），且当前禁入规则对 3D 资产市场
  （通常许可更碎）无现成对策。

### 1.7 五图规模与生成器链

| 地图 | 规模（格） | 出处 |
|---|---|---|
| town | 64×48（1024×768px） | `scripts/maps/town_map.gd:37` |
| road | 48×64 | `tools/gen_road.py:4` |
| ruins_f1 | 56×44 | `tools/gen_ruins.py:4` |
| ruins_f2 | 48×48 | `tools/gen_ruins.py:4` |
| ruins_f3 | 40×40 | `tools/gen_ruins.py:4` |

生成器→核验器链：`tools/gen_town.py / gen_road.py / gen_ruins.py` 程序化产出
`tile_map_data`（u16 版本 + N×12B cell 小端，`gen_town.py:9-12`）→
`tools/verify_town.py / verify_road.py / verify_ruins.py` 静态断言（M8-A③ 后含
"WallsObjects 为 YSorted 子节点"结构断言，PASS 129/66/159——
`evidence/m8-a3-walls-into-ysorted.md:178-185`）。
**重要工程事实**：M8-A③ 已实证"改生成器 + 全量重生成 + 逐字节等价校验"链路可用
（五图重生成 SAME，同档 §2）——这既降低了②类改造的重生成成本，也说明任何"呈现层
变换"若想进生成器口径，改的是这一整条链，不是单图手调。

### 1.8 已有的"2.5D 增强"存量（避免重复建设）

M7-A1/A2 两个 2.5D 视觉升级档已落地：光照层（§1.5）+ 装饰密度提升/占位件替换
（`tools/gen_town.py:17-26`）+ M8-A③ y-sort 归位（§1.1）。即：③类"纵深感"诉求中的
**光照氛围与前后遮挡两块已经做完**，且各有验收证据。

---

## 2. 问题定义："3D 化"是三种成本差 10 倍以上的诉求

| 诉求 | 玩家嘴里的样子 | 技术实质 | 成本量级 |
|---|---|---|---|
| **① 整体换 3D 渲染** | "游戏是 3D 的" | 3D 场景/相机/光照/碰撞，像素贴图混合渲染 | 现有架构全面重写（§4 选项 C） |
| **② 2D 玩法 + 伪 3D 增强** | "画面更有立体感" | 视差、高度错觉、斜投影/伪透视、动态光照阴影 | 增量改造到局部重构（§4 选项 A/B） |
| **③ 只是想要纵深感** | "走着不像纸片，画面有层次" | **不是技术缺口，是美术与演出打磨**——y-sort 遮挡、光照氛围、构图层次已具备，缺的是内容密度与演出细节 | 交文策渊/美术口径，技术零改造 |

判定要点：当前项目**已经是 2.5D**（多层 TileMapLayer + y-sort 遮挡 + CanvasModulate +
PointLight2D，§1.8）。⑤反馈若属③，则本文选项 A/B/C 全部是过度工程；若属②，A 与 B 的
分界在"是否动呈现层变换体系"；只有①才真正触及 A8 冻结架构的存废。
**因此本文档的第一产出物不是选项，而是一个待用户回答的问题（§5 待拍板项 1）。**

---

## 3. 与 M8 方向提案的关系（不越权，仅对表）

`production/sprints/m8-direction-proposal.md` 已给出 A 打磨 / B 发布 / C 扩展 / D 两段式
四选项与排序 D>B>C>A。本文不重复该裁决，只指出结构事实：

- **O（保持现状）** 与 M8 任一方向零冲突；
- **A（伪 3D 增强）** 工作量 1.5–3d，量级上近似该提案"方向 A 打磨收尾"（8–12h）内的
  一个子项，可并轨；
- **B（伪透视改造）** 5–9d，超过方向 A 全部工项，会实质改写 M8 排期；
- **C（换 3D）** 20–35d+，与四方向全部互斥，等于在"切片收口之后往哪走"的问题之外
 另立一个项目。

---

## 4. 方案选项详述（含 Godot 4.7.2 能力边界核对）

### 4.1 选项 O —— 保持现状（基线）

- **做**：什么都不改。⑤反馈中属③的部分（纵深感动）按美术/演出打磨路径立项（技术零改造）。
- **不做**：任何渲染层/节点树/生成器改动。
- **对 A8 七里程碑与五图的冲击**：零。558 用例绿基线不动。
- **对 ADR-4**：零冲突。
- **风险/收益/回滚**：无技术风险；收益是保护"无已知瑕疵的冻结切片"状态（M8 方向提案
  选项 A 的核心资产）。回滚不适用。
- **诚实的另一面**：若用户真实意图是①或②，O 只是"不回应"，不是"回答"——所以本选项
  必须与 §5 待拍板项 1 的澄清问题一起交付。

### 4.2 选项 A —— 伪 3D 增强（②类，增量）

- **做**（三件互相独立，可拆卡）：
  1. **视差远景**：地图外围/室内窗外加 Parallax 层（4.3 起有 Parallax2D 节点；
     ParallaxBackground/ParallaxLayer 旧对仍可用）。俯视 JRPG 的视差用途受限——主要
     适室内窗外景、道路远景横移，不适小镇整图。
  2. **动态阴影**：对 Walls 类 tile 挂 LightOccluder2D + 开光源 `shadow_enabled`。
     Godot 4 的 2D 光照/阴影（PointLight2D + LightOccluder2D）为稳定特性；但本项目
     M7-A1 已实证"16px tile 阴影开销大且易闪"才全程关闭（`map_lighting.gd:28`）——
     开启需重做 shadow filter 调参并在 GL Compatibility 下实测帧率。
  3. **局部高度/浮空演出**：特定实体（飞鸟、桥下穿行、旗帜）用 z_index 微调 + Tween
     做浮空/投影错觉；Node2D 变换含 skew 属性可做局部斜切。
- **不做**：不动场景树分层、不动 y-sort 口径、不动生成器链、不动碰撞与玩法。
- **改造面**：新增独立装配器脚本（M7-A1 MapLighting 同款静态工厂风格）+ 各图 config；
  生成器链只在"装饰件需要 occluder 元数据"时才需评估。
- **对 A8 与五图冲击**：七里程碑产物全部复用；五图零重生成（装配在运行时 _ready 增量，
  同 `_assemble_lighting` 先例 `town_map.gd:198-199`）。
- **工作量**：视差 1–2 卡、阴影 1–2 卡、浮空演出 1–2 卡，合计 **3–6 卡（1.5–3d）**；
  另建议先 1 卡 spike 验证阴影观感再决定是否全量。
- **对 ADR-4**：视差/浮空全程整数变换则零冲突；阴影不影响变换体系。子约束：**禁止
  非整数缩放/偏移**进入 YSorted 子树（会与 snap_2d_transforms_to_pixel + Nearest 打架，
  产生像素抖动——机理同 ADR-4 负面清单，`godot4-architecture-adr.md:197-200`）。
- **风险/收益/回滚**：风险中低（观感在 640×360 像素网格上可能"加强感不足"，即花 2 卡
  看不出差别）；收益是②类诉求的最低成本回应；回滚单卡级（每项独立开关、独立装配器）。
- **负收益提示**：若用户真实诉求是①（想看"真的立体"），A 属于答非所问；且在"对外发布"
  （M8 方向 B）视角下，视差/阴影的边际观感收益低于缺口修复与内容，**优先级大概率低于
  M8 方向提案的既有排序**。

### 4.3 选项 B —— 斜投影/伪透视改造（②类重口径）

- **做**：呈现层整体加伪透视——典型手法：①地图根/相机做 skew/斜切变换（等距或
  斜 45°观感）；②引入"高度"伪坐标（实体 y 位置 = 平面 y − 高度系数×深度）；③
  canvas_item Shader 做逐顶点伪透视（VERTEX manipulation）。
- **不做**：玩法逻辑、事件协议（A5）、战斗系统、存档协议不变——2D 玩法数据面完整保留。
- **改造面**：这是②类里唯一触碰**生成器链**的选项——五图 tile 摆位若叠加 skew/伪透视，
  `gen_*.py` 的坐标映射、`verify_*.py` 的全部几何断言、y_sort_origin 校准值（8px 底边在
  skew 后不再等于"底边"）、相机限区 Rect2i 数值、传送落位目录全部要在新变换下重新推导。
- **对 A8 与五图冲击**：里程碑 1–2 的地图产物（town/road 白盒与构建单）需要按新变换
  重验；五图可走"生成器改 + 全量重生成"（链路 M8-A③ 已验证可用），但 verify 断言近乎
  全部重写。里程碑 3–7 的战斗/UI/剧情产物**大部分复用**（它们不依赖呈现变换）。
- **工作量**：变换体系与 spike 3–5 卡 + 生成器/verify 重写 3–4 卡 + 五图重生成与逐图
  目检 2–4 卡 + y-sort/碰撞/传送重校准 2–5 卡，合计 **10–18 卡（5–9d）**，且不含
  返工余量（像素观感调优是长尾）。
- **对 ADR-4**：**正面冲突**。Nearest 过滤 + 整数缩放 + snap_2d_transforms_to_pixel 的
  前提是"变换落在像素网格上"；斜切/伪透视必然产生非整数变换 → 两种后果二选一：
  a) 关 snap 接受 subpixel 抖动（ADR-4 明文要防的坑回归）；b) 把渲染挪进低分辨率
  SubViewport 再整数放大（可保像素锐利，但 Lighting/UI 分层与 640×360 假设全部要重验）。
  **两条路都在本项目未验证，必须先 spike。**
- **风险/收益/回滚**：风险中高——最大单项是"调了 5–9 天，观感反而不如干净像素"
  （16×16 Time Fantasy 系素材不是为斜投影设计的，透视畸变会放大素材接缝）；收益是
  ②类诉求的最强回应。回滚：分支开发可整体废弃，但沉没成本集中。
- **负收益提示（诚实）**：在当前切片阶段（M8 收口期、5–10h/周单人业余节奏），
  B **大概率负收益**：①它把"冻结切片"重新解冻；②M8 方向提案已论证缺口修复/发布/内容
  的优先结构，B 与三者抢同一份每周 5–10h；③其收益完全押在"用户确实想要斜投影观感"
  这一未确认判断上。
- **Godot 4.7.2 能力边界**：2D canvas 变换为仿射（无透视投影），Camera2D 无透视参数
  （官方文档《Displaying 3D nodes in 2D》以外的 2D 相机文档未提供透视能力——4.7 分支
  文档目录已核实存在该主题页）；伪透视只能靠节点 skew / Shader / SubViewport 组合，
  无引擎级"2.5D 相机"。**Node2D.skew 在 4.7.2 下的具体行为、canvas_item Shader 伪透视
  在 GL Compatibility 下的性能：未确认（本机未实验；4.7 分支文档未逐条核对），需实验验证。**

### 4.4 选项 C —— 整体换 3D 渲染（①类）

- **做**：世界层改 3D 场景（3D 相机/光照/网格地形或体素块），角色用 Sprite3D/
  AnimatedSprite3D 立牌或 3D 化像素；2D UI 层保留。
- **不做**：不承诺保留任何 A8 里程碑产物。
- **对 A8 与五图冲击**：**颠覆**。七里程碑中 1/2/4（地图、遇敌世界）全部重做；3/5/6/7
  中战斗/剧情/结算的**逻辑层**（scripts/core 纯函数、A5 纯数据协议、JSON 事件）理论上
  可复用——这是 A1 铁律"数据进、数据出"预埋的红利，但其全部**场景与表现层**重做。
  五图：tile_map_data 无 3D 对应物（Godot 3D 侧是 GridMap/MeshLibrary 体系），生成器链
  整体作废重写。
- **工作量**：保守估算 **40–70 卡（20–35d+）**——3D 场景与相机 8–12 卡、地形与碰撞
  8–12 卡、角色/敌人立牌与动画 6–10 卡、光照体系重建 4–8 卡、2D/3D 混合 UI 与交互射线
  4–8 卡、五图重建 6–12 卡、回归测试重建 4–8 卡。按 5–10h/周 ≈ **2–4 个月纯改造期**。
- **对 ADR-4**：**颠覆**。640×360+integer+Nearest 是 2D canvas 体系；3D 侧需要重建像素
  呈现管线（低分辨率 3D 渲染 + 最近邻过滤）。Godot 4.7 release notes 确认 4.7 新增
  "3D 渲染最近邻过滤"选项（"New nearest-neighbor scaling option for viewports…does not
  affect 2D rendering"，godotengine.org/releases/4.7）——说明引擎侧为像素风 3D 提供了
  新支持，但整套 640×360 假设（UI 字号、九宫格、黑幕框、相机限区）仍需重建。
- **风险/收益/回滚**：风险极高——除工作量外：①资产账本重开（§1.6，3D 资产许可生态更碎，
  禁入规则无对策）；②用户为 TS/JS 背景、无 3D 开发经历（ADR-1 背景栏），学习曲线陡增；
  ③GL Compatibility 下 2D/3D 混合渲染的像素观感在 640×360 级别是否成立：**未确认（未
  实验），需实验验证**。回滚：不可行——只能封存 2D 切片另立仓库。
- **负收益提示（明确）**：与 M8 方向提案 A–D 四选项全部冲突，且把"2 头身 16×18 像素小人"
  放进 3D 空间的观感收益存疑（该组合通常只在低多边形/像素混合风格下成立，而那需要
  3D 建模产能——单人业余项目无此产能）。**本文不对 C 做任何推进建议，仅如实呈现成本。**
- **Godot 4.7.2 能力边界**：SubViewport 渲染 3D 进 2D（官方 4.7 文档"Displaying 3D
  nodes in 2D"主题存在，已核实）；Sprite3D/AnimatedSprite3D 为稳定节点；GridMap+
  MeshLibrary 为 3D 体素/方块标准方案（4.7 还新增了 MeshLibrary 编辑器，release notes
  已核实）。2D/3D 混合在 Compatibility 渲染器的具体限制（光照模型、透明排序）：**未确认
  （官方文档该章节未逐条核对 + 本机未实验），需实验验证。**

### 4.5 三选项共同的前提性实验（若用户拍板 A 或 B，先做）

| Spike | 验证问题 | 预算 |
|---|---|---|
| S-A | town 一面墙挂 LightOccluder2D + 开 shadow：观感是否提升、GL Compatibility 帧率是否可接受 | 1 卡 |
| S-B | 六格 demo：skew 伪透视 + Nearest + snap 三者并存的像素观感；SubViewport 方案对照 | 1–2 卡 |
| S-C | 16×18 立牌 Sprite3D 在 3D 相机下的像素清晰度（低分辨率 SubViewport 路线） | 2 卡 |

spike 产物为截图+结论一段，进 `evidence/`，不进生产场景。

---

## 5. 建议与待拍板项

### 建议（不越权，供用户裁决）

**建议路径：O 为默认 + 一个澄清问题先行；A 仅作可选试点；B/C 不建议在当前阶段推进。**

理由：
1. **诉求未定型**：⑤反馈"想探讨 3D 化"本身是开放句式，三种诉求成本差 10 倍以上（§2）。
   先问清"想看到什么"比先动手省 5–9 天的无效改造风险。
2. **纵深感两大件已完成**：y-sort 遮挡（M8-A③ 刚修好，用户尚未在实机确认新观感）与
   光照氛围（M7-A1）都在位——③类诉求的存量响应其实刚落地，**先让用户玩到 M8-A③ 之后
   的实机画面再谈 3D 化，是零成本的降歧义手段**。
3. **架构纪律**：A8 是冻结架构；B 已实质解冻呈现层，C 直接推翻。解冻/推翻均应由用户
   明示，而非技术侧默认推进。若用户拍板 B 或 C，建议**另开卡片同步修订
   `godot4-architecture-adr.md`（新增 ADR-5），本文不代改**。

### 待拍板项（开放问题）

1. **⑤反馈的真实诉求是①/②/③中哪一种？**（若为③：转美术/演出打磨路径，本文即结案。）
2. 若为②：是否接受先让用户实机确认 M8-A③ 后的 y-sort 观感，再决定是否立项 A？
3. 若立项 A：是否接受"先 1 卡阴影 spike（S-A），看证据再定全量"的节奏？
4. 若用户仍要 B 或 C：是否接受"另立里程碑 + 新增 ADR-5 修订冻结架构 + 排期与 M8 方向
   提案重新合并裁决"的三连前提？
5. （顺带登记）用户是否有"斜投影/等距"这类具体参考作（若有，S-B spike 的对照物可确定）。

---

## 6. 无法确认部分（诚实登记）

| 事项 | 状态与原因 |
|---|---|
| Node2D.skew / canvas_item Shader 伪透视在 Godot 4.7.2 + GL Compatibility 下的实际表现与性能 | 未确认（本机未实验；4.7 分支官方文档未逐条核对）→ 需实验验证（S-B） |
| 2D/3D 混合渲染（SubViewport 3D-in-2D、Sprite3D 立牌）在 Compatibility 渲染器、640×360 低分辨率下的像素观感 | 未确认（同上）→ 需实验验证（S-C） |
| Godot 4.7.2 中 Parallax2D 节点 API 细节 | 部分确认（Parallax2D 于 4.3 引入、为现行推荐节点，社区文档与 4.7 文档目录可佐证；具体属性面未在本机核对） |
| B/C 选项工作量估算的方差 | 本文给的是区间估算（依据：M8-A③ 实测的生成器链改造口径），非报价；实际取决于 spike 结果 |
| `ruins_tileset.tres` 的 y_sort_origin 逐格值 | 未逐格 grep 核对（依据 M8-A③ 证据档 :49-51 的"全部 Walls tile 已设"记载转引） |

—— 程基岩，评估完毕；本文件为唯一产出，未触碰任何既有文件。
