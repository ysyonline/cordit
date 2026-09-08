# NPC 形象分配表（R2-CHARSPRITE · 初排 2026-09-06）

> 正本声明：本表为**初排**，最终以**用户游戏内目检拍板**为定稿（任务书第 6 条）。
> 改表只动两处：`scripts/maps/town_map.gd` 的 `NPC_CHARSET`（数据正本）+ 本表（说明正本）。
> 形象 id → 图集块对应关系见 `assets/characters/charset_frames.md` §4 与 `scripts/core/char_anim.gd` `SHEET_BY_ID`。
> 目检辅助图：`tools/dev/_r2_npc_down_sheet.png`（12 原生形象朝下 idle+walk 并排对照）。

## 1. 形象池概览

| 形象 id | 来源 | 外观速写 | 引擎纹理 |
|---|---|---|---|
| m1..m6 | 原生男带 6 像 | 金发王子 / 紫衣剑士 / 银发法袍 / 灰甲 / 绿衣 / 褐衣兜帽 | R4 主图 `..._bright_alpha.png` |
| f1..f6 | 原生女带 6 像 | 橙发粉裙 / 金发紫裙 / 蓝发青裙 / 褐裙红带 / 红衣绿发 / 兜帽长袍 | R4 主图 |
| v1_elder | R5 变体（基于 f6） | 灰白长者袍 | `..._alpha_v1_elder.png` |
| v2_porter | R5 变体（基于 m1） | 深棕发深裤 | `..._alpha_v2_porter.png` |
| v3_smith | R5 变体（基于 m2） | 炭灰衣黑发 | `..._alpha_v3_smith.png` |
| v4_shepherd | R5 变体（基于 f2） | 土褐短打红棕发 | `..._alpha_v4_shepherd.png` |

变体必要性：上图 13 角色（凯尔 + 12 NPC）男 9 女 4，原生男像仅 6 → 3 个男角色用变体（登记见 `assets/CREDITS.md` B 区 / `production/asset-intake-list.md` R5）。

## 2. 玩家（地图行走者）

| 角色 | 形象 | 依据 |
|---|---|---|
| **凯尔**（主角，`scenes/player.tscn`） | **m1**（金发王子型，青衣橙披风） | 游击士新人的清爽少年感；四向 idle+walk 全动画（`char_anim.gd` 共享 SpriteFrames，`player.gd` facing 映射驱动）；金发与 v2_porter（深棕变体）明确区分，同屏不撞衫 |

## 3. 小镇 12 NPC（town.tscn 锚点，`town_map.gd NPC_CHARSET` 数据正本）

| npc_id | 对话身份（JSON speaker） | 形象 | 朝向 | 分配依据 |
|---|---|---|---|---|
| npc_01_innkeeper | 莉安大婶（客栈） | **f2** | down | 金发+暖紫裙围裙感，F2 HEALER 的"殷勤店主"气质；f1 留给主妇避免同色相 |
| npc_02_traveler | 神秘旅行者 | **m6** | down | M6 ROGUE 褐衣兜帽感 = "蒙面/来路不明"最贴；文案自述"旅途的意义"兜帽感成立 |
| npc_03_chase_kid | 追风的小孩 | **m5** | down | M5 NINJA 绿衣小个利落 = 追猫小孩的活泼感；亦与"遗迹怪光"好奇台词的灵动气质合拍 |
| npc_04_guard | 镇口守卫 | **m4** | **left** | M4 FIGHTER 灰白重甲 = 镇口武装拦截位唯一适配；面西（left）正对入镇道路，拦路姿态 |
| npc_05_smith | 铁匠老葛 | **v3_smith** | down | 炭灰衣黑发（V3 基于 m2 改色，保留皮革围裙色阶）= 炉火铁匠；原生 m2 紫衣过于花哨故用变体 |
| npc_06_peddler | 货郎阿六 | **m2** | down | 原生 m2 紫衣+蓝饰的"花哨叫卖感"正好留给货郎（针头线脑胭脂水粉），与 v3 铁匠同源不同色 |
| npc_07_priest | 神官梅尔 | **m3** | down | M3 WIZARD 银发白袍 = 神职者唯一适配（教堂语境"愿女神的辉光庇佑"） |
| npc_08_prayer_woman | 祈祷的大婶 | **f4** | down | F4 褐裙红腰带 = 朴素信徒；与 f2 店主（紫）、f1 主妇（粉）色相错开 |
| npc_09_shepherd | 牧羊少年 | **v4_shepherd** | **right** | 土褐田野短打（V4 基于 f2 改褐+红棕发）= 牧羊装束；面东（right）望向镇外坡地（牧场景方位） |
| npc_10_housewife | 主妇卡娜 | **f1** | down | F1 橙发粉裙 = 菜场家常感（"给你挑新鲜的"），主妇专属暖色 |
| npc_11_porter | 搬运工老壮 | **v2_porter** | down | 深棕发深布裤（V2 基于 m1 改色）= 苦力装束；与凯尔（同源 m1 金发）同屏不撞衫 |
| npc_12_elder | 村中长老 | **v1_elder** | down | 灰白长者袍（V1 基于 f6 兜帽袍改灰白）= 老者白须白发气质；f6 原生兜帽袍剪裁即"长者"形 |

## 4. 其他地图（实测无 NPC，零改动）

- `road.tscn` / `ruins_f1/f2/f3.tscn`：仅 Player（自动随 player.tscn 换装为 m1）+ 可见敌人（D3 敌人包未取用，暗红占位块**不在本单范围**，勿动）。
- 莉娜/莫娜：无地图实体节点（跟随队列 Story 用户裁决暂缓），**零改动**；战斗场景不在本单范围。
- npc_13 菲奥拉（委托所前台）：**无地图锚点**（对话仅走 E5-S4 剧情事件壳），无形象消费点，暂不分配——若后续上图建议 f3（蓝发青裙）。

## 5. 技术口径（供回查）

- NPC 纹理：`npc.gd _ready` 经 `char_anim.gd get_idle_texture(charset_id, facing)` 取共享整图 AtlasTexture，**零纹理复制**；未分配时兜底 npc.tscn 默认 `m1/down`。
- 玩家动画：`player.gd` 注入 `char_anim.gd get_frames()`（进程单例 SpriteFrames，8 动画）。
- 脚底原点/y-sort：两处载体绘制范围均 x∈[-8,8] y∈[-18,0]，z_index 默认 0——E1 规则一/二未触碰。
- 调整流程：改 `town_map.gd NPC_CHARSET`（或 npc.tscn 默认值）→ 重启游戏目检 → 用户拍板后回写本表状态为"定稿"。

---
*初排：程基岩（eng-lead）· R2-CHARSPRITE · 2026-09-06 · 待用户目检定稿。*
