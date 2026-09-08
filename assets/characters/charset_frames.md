# charset 帧网参考正本（R2-CHARSPRITE · 2026-09-06 实测）

> 实测脚本：`tools/dev/_r2_charset_scan.py`（逐行/列扫描）+ `_r2_charset_alpha.py`（转写与变体）。
> 本文所有坐标为 **Pixel 坐标（0 起）**，可直接填 `AtlasTexture.region` / `Sprite2D.region_rect`。
> ⚠️ 330×400 **不能**被 16×18 整除——上半部是图鉴说明文字带 + 武器大图，切勿按"全图 16×18 网格"裁切。

## 1. 文件与许可

| 文件 | 角色 | 说明 |
|---|---|---|
| `charsets_12_m-f_complete_by_antifarea.png` | 原样留档 | P 模式索引色，**只作许可追溯，禁引用** |
| `charsets_12_m-f_antifarea_bright.png` | R1 提亮件（已入库） | **GIF 扁平化，无 alpha 通道**，背景为实色 `(251,220,126)`——不可直接作引擎贴图 |
| `charsets_12_m-f_antifarea_bright_alpha.png` | **R4 透明转写件（引擎使用件）** | 背景色→alpha0，其余像素逐色保留；登记：assets/CREDITS.md B 区 |
| `..._alpha_v1_elder.png` / `v2_porter` / `v3_smith` / `v4_shepherd` | R5 调色板变体 | 与 R4 同网格；仅 4 个指定角色块改色（映射见 _r2_charset_alpha.py），其余块与 R4 逐像素相同 |

许可：Antifarea (Charles Gabriel)，CC-BY 3.0，[OGA 页面](https://opengameart.org/content/twelve-16x18-rpg-sprites-plus-base)，notice：`assets/licenses/notices/antifarea-sprites.txt`。

## 2. 真实网格结构（实测）

全图 330×400 分四个横带（自上而下）：

| y 范围 | 内容 | 工程处置 |
|---|---|---|
| y ∈ [0, 152) | 图鉴说明文字（"Twelve 16x18 sprites..." 等）+ 男 2×3 缩略图鉴 | 忽略，勿裁 |
| y ∈ [152, 166) | 空白（背景色） | 忽略 |
| y ∈ [166, 180) | **男带标题条**（六格边框 + "Princess/Knight/Wizard..." 字样） | 忽略；⚠️ 与男带仅隔 1px（y179 空行），裁切坐标必须精确 |
| y ∈ [180, 252) | **男带**：6 角色 × 48×72 | 裁切区 |
| y ∈ [252, 306) | 空白 + 女带标题条（y∈[292,306)） | 忽略 |
| y ∈ [306, 378) | **女带**：6 角色 × 48×72 | 裁切区 |
| y ∈ [378, 400) | 空白 | 忽略 |

（F 带标题条同样以亮框+文字形态存在，肉眼在调色板层面易与背景混淆——扫描时以 y 精确对齐，不做内容探测。）

## 3. 角色块定位（12 块）

每块 **48 宽 × 72 高**（= 16×18 × 3帧×4向，无缝排列）：

- **男带（M1..M6）**：`x0 = 16 + 48*c`（c=0..5），`y0 = 180`
- **女带（F1..F6）**：`x0 = 16 + 48*c`（c=0..5），`y0 = 306`

## 4. 角色编号与外观（调色板实测，供分配对表）

| 编号 | 块原点 (x0,y0) | 头发/头部主色 | 服装主色 | 标题带字形辨识 | 主观速写 |
|---|---|---|---|---|---|
| M1 | (16, 180) | 金发 (255,255,133)/(242,192,42) | 青 (135,225,255) + 橙饰 | PRINCE | 金发王子型，披风 |
| M2 | (64, 180) | 金发 (201,176,75) | 紫衣 (151,77,149) + 蓝饰 | KNIGHT | 紫衣金发、持械感 |
| M3 | (112, 180) | 银白 (217,225,248)/(255,255,255) | 蓝灰衣 (110,127,158) | WIZARD | 银发法袍、白须 |
| M4 | (160, 180) | 灰 (140,140,138)/(108,108,106) | 深灰甲 (69,69,67) | FIGHTER | 灰白发重甲 |
| M5 | (208, 180) | 绿发 (12,135,59)/(102,217,125) | 绿衣 (12,94,34) + 金带 | NINJA | 绿衣绿发、利落 |
| M6 | (256, 180) | 深发 (86,53,34) | 褐红衣 (148,52,34)/(108,28,18) | ROGUE | 褐衣兜帽感 |
| F1 | (16, 306) | 橙发 (225,143,18) | 粉裙 (236,140,170) | PRINCESS | 橙发粉裙 |
| F2 | (64, 306) | 金发 (201,176,75) | 紫裙 (86,53,108) | HEALER | 金发紫裙 |
| F3 | (112, 306) | 蓝白发 (110,176,207) | 青绿裙 (98,157,126) | ELF | 蓝发青裙 |
| F4 | (160, 306) | 褐发 (192,184,149) | 深裙 (118,110,100) + 红饰 (234,77,100) | DARK | 褐发深裙红腰带 |
| F5 | (208, 306) | 绿发 (94,127,42) | 红衣 (196,68,50) + 绿裙 | SHEPHERD | 红衣绿发、田园感 |
| F6 | (256, 306) | 灰兜帽 (135,135,158)/(94,94,100) | 暗长袍 (44,53,59) | MAGE | 兜帽长袍（隐面） |

## 5. 块内帧布局（每块 4 行 × 3 列，单帧 16×18）

行序（自上而下）= **朝向**；列序（自左而右）= **帧**：

| 行 gy | 朝向 | 帧 fx=0 | 帧 fx=1 | 帧 fx=2 |
|---|---|---|---|---|
| 0 | up（背面） | walkA | **idle（静止帧）** | walkB |
| 1 | left | walkA | **idle** | walkB |
| 2 | down（正面） | walkA | **idle** | walkB |
| 3 | right | walkA | **idle** | walkB |

- walkA / walkB 为镜像对称迈步对（walkB 亦可由 walkA 水平翻转得到，工程上直接取原帧）。
- **idle 即中间帧**（fx=1）——静止/待机播放该帧。
- 行走完整循环可按 `walkA → idle → walkB → idle` 四拍播放（1 拍 ≈ 0.1s，见 §7）。

### 帧区域坐标公式

```
角色 g 的朝向 d 的帧 f 的图集区域：
  x = block_x0(g) + f*16        f ∈ {0,1,2}
  y = block_y0(g) + d_row*18    d_row ∈ {up:0, left:1, down:2, right:3}
  size = 16 × 18
```

## 6. 工程约束（player.gd 规则一/二换装落点）

- **脚底原点**：帧绘制范围恒为 x∈[-8,8] y∈[-18,0]。Sprite 节点位置 `(-8, -9)`（中心偏移载体）不变； AnimatedSprite2D `centered = true` 时 position 取 `(-0, -9)` 同理——实现见 `scenes/player.tscn` / `scenes/npc/npc.tscn` 头注释。
- **Nearest 过滤**：`project.godot` 已设 `textures/canvas_textures/default_texture_filter=0`（Nearest），无需逐材质覆盖；缩放只用整数倍。
- **y-sort 三条件**：Sprite/AnimatedSprite2D 节点 `z_index` 保持默认 0，不手调。
- 引擎消费映射（12 形象 → 角色）：`production/npc-sprite-assignment.md`（分配正本，用户目检后定稿）。

## 7. 动画参数（换装实现钉定值）

| 项 | 值 | 依据 |
|---|---|---|
| walk 帧率 | 8 FPS（拍长 0.125s） | 4.5 tile/s ≈ 72 px/s，两步一循环 0.5s，单拍 0.125s（E1-S4 移速钉定） |
| walk 循环 | walkA → idle → walkB → idle（4 拍） | Antifarea 三帧惯例（中间帧 idle） |
| idle | 单帧 idle（fx=1） | 同上 |
| 帧序 | SpriteFrames 动画列表见 `scripts/core/char_anim.gd`（8 动画 × 每向） | 实现 R2-CHARSPRITE |

---
*2026-09-06 程基岩（eng-lead）· R2-CHARSPRITE · 实测数据可由 `_r2_charset_scan.py` 复现。*
