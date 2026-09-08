# CREDITS 署名合规终审 · M7（E7-S4 收官项）

> 审计：路远行（release-ops-lead）｜日期：2026-09-05｜状态：**结论已出，待用户拍板后修订**
> 依据：`assets/CREDITS.md`、`assets/LICENSE-ASSETS.md`、`assets/licenses/` 全量、`production/asset-intake-list.md`、`production/asset-intake-list.md` 红线条款、`production/README.md` §6、`EPIC-7.md` E7-S4 验收标准
> 审计方法：**全部实查**——① `find assets -type f` 全量文件清单；② 解析 `export/win/轨迹残响.pck` 二进制目录段（329 条路径）确认随包分发的素材；③ `git status` 确认入库状态；④ 全仓 `*.png / *.ttf` 扫描。**未采信任何文档转述的"已取用"结论。**
> 处置纪律：**本报告只给建议文本，不修改 `assets/CREDITS.md`。** 等用户拍板。

---

## 0. 判定摘要

| 审计维度 | 判定 |
|---|---|
| **红线：CC-BY-SA 资产** | **0 件 · PASS** |
| **红线：GPL-only 资产** | **0 件 · PASS** |
| **红线：LPC 32×32 素材** | **0 件 · PASS** |
| **红线：bart 城堡件** | **⚠️ P0 阻塞**（2 个文件在 git 仓库内，见第 3 节） |
| **CREDITS 与实入库资产一致性** | **✗ 需修订**（B 区 2 条悬空登记 + A 区 1 条命名歧义） |
| **许可条款记录正确性** | **✓ PASS**（CC0/CC-BY 3.0/CC-BY 4.0/OFL 1.1 四份全文齐备，7 份 notice 齐备，字体许可已勘误） |
| **署名义务落点（随包分发场景）** | **✗ 缺失**（pck 内无 licenses/、无 CREDITS，游戏内无致谢画面） |

### 分路径 go/no-go

| 分发路径 | 判定 | 理由 |
|---|---|---|
| **A. 导出包分发（exe + pck / zip）** | **GO**（需先补随包 CREDITS.txt + 许可全文） | pck 内实测 0×SA、0×GPL、0×LPC、0×bart，红线全部干净 |
| **B. 源码仓库公开发布** | **NO-GO · P0** | bart 城堡件两个文件在仓库内，随源码分发即构成 GPL 2.0/3.0 与 CC-BY-SA 3.0 素材的再分发 |

---

## 1. A 区 · 原样资产逐项核对（7 项）

| # | CREDITS 登记名 | 登记许可 | 仓库内实际文件 | 一致性 |
|---|---|---|---|---|
| A1 | Town Tiles（surt） | CC0 | `assets/tiles/town_tiles.png` | ✓ |
| A2 | Forest Tiles（surt） | CC0 | `assets/tiles/forest_tiles.png` | ✓ |
| A3 | Classical Temple Tiles（surt） | CC0 | `assets/tiles/classical_temple_tiles.png` | ✓ |
| A4 | 16x16 Town Remix（Sharm/Redshrike/surt/Jetrel） | CC-BY 4.0 | `assets/tiles/16oga.png` | ⚠️ **命名歧义** |
| A5 | Twelve 16x18 RPG sprites（Antifarea） | CC-BY 3.0 | `assets/characters/charsets_12_m-f_complete_by_antifarea.png` | ✓ |
| A6 | 48x48 Faces 1st Sheet（CharlesGabriel） | CC-BY 3.0 | `assets/faces/48x48_Faces_1st_Sheet_Update_CharlesGabriel_OGA.png` | ✓ |
| A7 | Fusion Pixel Font（TakWolf） | SIL OFL 1.1 | `assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf` | ⚠️ **状态未注** |

**A 区结论：7 项全部有实入库文件对应，无虚构登记。2 项需补注。**

### A4 · 命名歧义（建议修订）

CREDITS 用**来源页面作品名**"16x16 Town Remix"登记，仓库内文件名是 OGA 原始下载名 `16oga.png`。两者无任何字面关联，我在审计时花了三步才对上（CREDITS → `asset-intake-list.md` §2.1 表第 4 行 → 文件名）。

这违反 `asset-intake-list.md` §1 约定："**原样资产保留 OGA 原文件名**（与来源页 File(s) 栏一致，**审计零歧义**）"——文件名确实保留了原名，但 CREDITS 登记表没记录它，**"零歧义"的闭环断在登记表这一侧**。

> 影响：不触发任何许可义务问题（署名、许可、回链三项要素都齐全），但**削弱了可审计性**。下一次审计（或外人核查）会重复我这次的追溯成本。

### A7 · Fusion Pixel 字体状态未注（建议修订 + 决策点）

实查结果：**该字体目前未被项目引用。**

- `project.godot` 无 `gui/theme/custom_font`，无主题配置
- 全仓 `.tscn` 无 `theme_override_fonts/font`
- 无任何 `.gd` 或 `.tres` `preload`/`load` 该字体
- 游戏中所有中文依赖 Godot 默认字体的**系统回退**（Windows 下为 DirectWrite 回退）

**但它确实进了分发包**——pck 目录段内命中 `fusion-pixel` 4 次（ttf 本体 + `.fontdata`）。也就是说：**OFL 的"随分发保留许可全文"义务已经触发，但这个字体一个字都没渲染过。**

这是一个需要用户拍板的决策点：

- **选项 1（推荐）**：把字体接上（给 `project.godot` 配默认主题字体，或在对话框/菜单上挂 `theme_override_fonts`）。切片是像素风 JRPG，默认的系统黑体在 640×360 整数拉伸下会糊且风格不对，接上是**净收益**。接上后 OFL 义务与视觉收益才对得上。
- **选项 2**：从导出包剔除（`exclude_filter` 加 `assets/fonts/**`）。省 6.7 MB 源 / 包体大头，同时免除 OFL 随包义务。
- **选项 3**：维持现状。义务照背、好处没有，且非开发机上中文字形不可控（见发布清单 B3）。**不推荐。**

**无论选哪个，CREDITS 都应注明当前状态**，否则登记表读起来像"字体已在使用"。

---

## 2. B 区 · 修改资产逐项核对（3 项）

| # | CREDITS 登记名 | 登记入库日期 | 仓库内实际文件 | 一致性 |
|---|---|---|---|---|
| B1 | `charsets_12_m-f_antifarea_bright.png` | 2026-08-29 | `assets/characters/charsets_12_m-f_antifarea_bright.png` | ✓ **存在** |
| B2 | `faces_32x32/*_battle.png` | （角色定稿日） | `assets/faces/faces_32x32/` 为空目录 | ✗ **悬空** |
| B3 | `enemies/*_portrait_32.png` | （敌人选型日） | `assets/enemies/` 为空目录 | ✗ **悬空** |

**B 区结论：3 项中 1 项成立、2 项悬空。**

### B1 · 合规 ✓

`_bright` 派生件的 `modified from original` 四要素齐全：原资产（Twelve 16x18 RPG sprites #5 全表）✓ 作者（Antifarea）✓ 许可（CC-BY 3.0）✓ 修改说明（角色层轻提亮一档，预混色、逐帧网格不变）✓。

CC-BY 3.0 对演绎作品的署名要求（标注原作者 + 声明已修改）已满足。`notices/antifarea-sprites.txt` 里还额外记录了"回贡献 OGA 为致谢非义务"的口径判断，做得细。

### B2 / B3 · 悬空登记（建议修订）

两行都是 `asset-intake-list.md` §2.2 规划的**未来派生件**（R2 战斗头像裁切、R3 敌人头像放大），规格写得清楚，但**截至本次审计从未产出**：

- `assets/faces/faces_32x32/` 是空目录 —— git 不跟踪空目录，所以**clone 出来的仓库里连这个目录都不存在**
- `assets/enemies/` 同样是空目录
- pck 内无任何 `faces_32x32` / `enemies/` 路径

顺带核实了这两行所依赖的上游：
- R2 依赖 A6（48x48 Faces）—— 源在，但**裁切件没做**，游戏里对话框头像直接取 48×48 原生格（零缩放），这是 `portrait_catalog.gd` 现行实现
- R3 依赖 D3（Ars Notoria 敌人包）—— **从未取用**。实查 `scenes/enemies/visible_enemy.tscn`：敌人视觉是 `BodyRect/ColorRect` 暗红占位色块，注释写明"D3 敌人包 Ars Notoria 入库后仅替换纹理"。战斗场景 `battle.tscn` 同样是纯色背景占位

**为什么这算问题**：E7-S4 的验收标准原文是"**CREDITS 与实际入库资产一致**"。B 区现在登记了 2 个不存在的文件，直接不满足该条。而且悬空行的"入库日期"栏还写着"（角色定稿日）""（敌人选型日）"这类**永不兑现的占位**，会让后来人误以为只是日期待填、文件已在。

**但这两行承载的设计意图（R2/R3 派生规格）不能直接删掉**——它们是有价值的规划记录。建议移到独立分区保留（见第 6 节建议文本）。

---

## 3. 红线扫描（4 条硬红线）

> 红线来源：`production/README.md` §6（CC-BY-SA / GPL 资产禁止回潮）、`production/asset-intake-list.md` 第 5 行与 §2.3（bart 城堡件禁入）、任务硬约束（LPC 32×32 禁用）。

### 3.1 CC-BY-SA —— **0 件 · PASS**

A/B 区 8 条已入库登记（7 原样 + 1 派生）许可分别为 CC0 ×3、CC-BY 3.0 ×2、CC-BY 4.0 ×1、SIL OFL 1.1 ×1，无一为 SA 系。C 区 7 条备查项也无一为 SA。

### 3.2 GPL-only —— **0 件 · PASS**

同上。四份许可全文（`CC0-1.0.txt` / `CC-BY-3.0.txt` / `CC-BY-4.0.txt` / `OFL-1.1.txt`）齐备，无 GPL 文本入库。

### 3.3 LPC 32×32 素材 —— **0 件 · PASS**

全仓 `*.png` 共 39 个（排除 `.godot/` 导入缓存），按目录逐个核对：

| 目录 | 数量 | 其中游戏素材 | 规格 |
|---|---:|---|---|
| `assets/` | 7 | **全部 7 个** | 瓦片：town_tiles / forest_tiles / classical_temple_tiles（surt 32×32 与 64×48 系）、16oga（Town Remix 16×16）<br>角色：charsets_12_m-f_complete / _bright **16×18**（Antifarea）<br>头像：48x48_Faces_1st_Sheet **48×48**（CharlesGabriel） |
| `design/` | 14 | 0 | mockup 中间件、OGA 页面缩略预览图、surt 官方示例拼图、**bart 城堡件 ×2**（见 3.4） |
| `addons/` | 9 | 0 | GUT 测试框架插件图标 |
| `tests/` | 9 | 0 | M1 视觉验收截图（e1s5-visual） |

游戏素材 7 件全部为 16×16 / 16×18 / 32×32 / 48×48 / 64×48 网格，**无 LPC（Liberated Pixel Cup）32×32 规格素材**。

无 LPC（Liberated Pixel Cup）32×32 规格素材。

### 3.4 bart 城堡件 —— **⚠️ P0 阻塞**

**点名两个文件：**

```
design/art-bible/mockup/_src/castle_tiles.png    (1024×192)
design/art-bible/mockup/_src/castle_tiles2.png   (144×64)
```

**事实链（全部实查）：**

1. **这两个文件在 git 仓库内、已被提交入库。** 来源页为 bart「16x16 Castle Tiles」，页面多许可并列，含 **GPL 2.0 / GPL 3.0 / CC-BY-SA 3.0** 三档。`asset-intake-list.md` §2.3 已明确判定"禁入（账本红线）"。
2. **它们不在 `assets/` 下**，也**未被任何场景、脚本或 JSON 引用**（全仓 `res://` 引用扫描无命中）。
3. **它们不在分发包内。** `export_presets.cfg` 的 `exclude_filter` 含 `design/**`；实测 pck 二进制目录段内 `castle` 关键字命中 **0 次**。**导出包分发路径（路径 A）是干净的。**
4. **但第 1 条是决定性的。** 只要仓库被公开（作品集场景下这是默认预期），这两个文件就随源码一起分发了。在多许可并列且本项目**从未做出"选用 CC-BY 3.0 档"的书面声明**的情况下，外界无从判断项目行使的是哪一档许可——而另外两档（GPL / SA）具有传染性。

**为什么不能因为"没用上"就算了**：`asset-intake-list.md` §2.3 当时的判断是"留档 `_src` 不动"，理由是"未来若需城堡可复用 + 避免重复下载"。这个理由在**仓库私有**时成立；一旦切换到**仓库公开**（M7 发布即触发），同一个动作的法律性质从"本地留档"变成"公开再分发"。红线纪律看的是后者的状态，不是前者的意图。

**处置选项（须用户拍板）：**

| 选项 | 动作 | 代价 | 推荐度 |
|---|---|---|---|
| ① | 从工作区删除 + 清理 git 历史（`git filter-repo` / BFG） | 约 30 分钟；会改写历史，若已 push 需强推 | **推荐**（若仓库计划公开） |
| ② | 移出仓库，存到仓库外的本地 `_src` 备份目录 | 约 5 分钟；**历史里仍有该文件**，仅 HEAD 之后消失 | 不够彻底，历史仍可检出 |
| ③ | 仓库保持私有，只对外发 Release 附件（zip） | 0 分钟；但丢了"看代码"这一作品集核心价值 | 备选 |
| ④ | 维持现状不动 | 0 分钟；**红线持续违反** | 不可接受 |

**注意**：选项 ①②涉及 git 历史改写，且我已被告知**禁止执行任何 git 写操作**。本报告只给判定与选项，执行须由用户本人或另行授权。

---

## 4. 许可义务履行核对

### 4.1 已履行项 ✓

| 义务 | 来源 | 现状 |
|---|---|---|
| CC-BY 三项：署名作者 | Town Remix / Antifarea / 48x48 Faces | A 区均已登记作者全名 ✓ |
| CC-BY 三项：标注许可 | 同上 | A 区均已标注版本（4.0 / 3.0 / 3.0）✓ |
| CC-BY 三项：回链 opengameart.org | 同上 | 3 份 notice 原文均含 OGA 回链 ✓ |
| CC-BY 演绎件：声明已修改 | `_bright` 派生件 | B 区"修改说明"列 + "原资产"列 ✓ |
| OFL：保留许可全文 | Fusion Pixel Font | `assets/licenses/OFL-1.1.txt` ✓ |
| OFL：不得单独出售字体本体 | 同上 | 作为游戏构建物一部分分发，不触发 ✓ |
| 许可全文入库 | 全部 | 4 份全文齐备 ✓ |
| 专属 notice 入库 | 全部 | 7 份齐备（含 3 份 CC0 的来源留痕）✓ |

**额外加分项**：`notices/fusion-pixel-font.txt` 记录了"清单预登记 CC-BY 4.0 → 实为 SIL OFL 1.1"的勘误过程与核实路径（仓库 README + 包内 OFL.txt）。**这是本次审计里质量最高的一条记录**——许可勘误留痕比"一开始就填对"更有审计价值。

### 4.2 缺失项 ✗

| # | 缺失 | 影响 | 严重度 |
|---|---|---|---|
| 1 | **pck 内无任何 `licenses/` 与 CREDITS 文件** | 随包分发时，OFL 的"保留许可全文"与 CC-BY 的"署名"义务**在游戏包内没有落点** | P1（阻塞对外分发，不阻塞 M7 门） |
| 2 | **游戏内无致谢画面** | CREDITS 第 D 区已生成 7 条四行式致谢条目，但全仓 `scenes/ scripts/ data/` 内 `credits`/`致谢` 命中 0 次——**这些条目目前只存在于一个 md 文件里，玩家永远看不到** | P1（可用随包 CREDITS.txt 替代） |
| 3 | **随包无 CREDITS.txt** | 同上 | P1 |

**切片场景下的最低成本合规方案**（推荐，不做游戏内致谢画面）：

```
轨迹残响-v0.1.0-slice-win64.zip
├── 轨迹残响.exe
├── 轨迹残响.pck
├── 怎么玩.txt                    ← 操作键位 + 已知问题（quality-lead 交付包内已有）
├── CREDITS.txt                   ← assets/CREDITS.md 第 D 区致谢条目原文
└── licenses/
    ├── CC0-1.0.txt
    ├── CC-BY-3.0.txt
    ├── CC-BY-4.0.txt
    ├── OFL-1.1.txt
    └── notices/（7 份）
```

这满足 CC-BY 的"在合理位置署名"与 OFL 的"随分发保留许可全文"，对切片而言足够，且**不需要为它写一个致谢场景**。

---

## 5. C 区 · 管线待入库核对（7 项）

任务背景里提到的素材来源比实际入库的多。**实查结论：以下 7 项全部未取用**，CREDITS 将其列在 C 区（"已核实许可、尚未取用"）是**自洽的**，无需修订：

| 资产 | 作者 | 许可 | 实查状态 |
|---|---|---|---|
| Sewer tileset | MrBeast | CC-BY 3.0 | 未取用（`assets/tiles/` 无 sewer_tiles.png）✓ 自洽 |
| Cave tileset | MrBeast | CC-BY 3.0 | 未取用 ✓ 自洽 |
| Bosses and monsters (Ars Notoria) | Balmer / 原画 Redshrike | CC-BY 3.0 | 未取用（`assets/enemies/` 空，敌人为占位色块）✓ 自洽 |
| DawnLike v1.81 | DragonDePlatino, DawnBringer | CC-BY 4.0 | 未取用（pck 内 0 命中）✓ 自洽 |
| Kenney UI Pack: RPG Expansion | Kenney | CC0 | 未取用（`assets/ui/` 空，UI 为 Godot 内置控件 + StyleBox 自绘）✓ 自洽 |
| 48x48 Face Template | CharlesGabriel | CC-BY 3.0 | 未取用 ✓ 自洽 |
| 16x16 Item-Icons | OGA 多作者 | 逐文件核实后登记 | 未取用 ✓ 自洽 |

**两处口径澄清**（避免后续误判）：

1. **Redshrike 已在致谢名单里**——通过 A 区的「16x16 Town Remix」（四人协作之一）。C 区的 Ars Notoria 只是他的另一件作品，未取用。
2. **"OGA 16x16 主集"= A4 的 `16oga.png`**（Town Remix 补丁包），已登记、已随包。不存在"另有一份 OGA 16x16 主集未登记"的情况。

---

## 6. 建议修订文本（**不直接改 `assets/CREDITS.md`，等用户拍板**）

以下为可直接替换/插入的建议文本。

### 6.1 A 区表格：增补"仓库内文件名"列

```markdown
| 资产名 | 仓库内文件名 | 作者 | 来源 URL | 许可 | 入库日期 | 是否修改 |
|---|---|---|---|---|---|---|
| Town Tiles | `assets/tiles/town_tiles.png` | surt | https://opengameart.org/content/town-tiles | CC0 | 2026-08-29 | 否 |
| Forest Tiles | `assets/tiles/forest_tiles.png` | surt | https://opengameart.org/content/forest-tiles | CC0 | 2026-08-29 | 否 |
| Classical Temple Tiles | `assets/tiles/classical_temple_tiles.png` | surt | https://opengameart.org/content/classical-temple-tiles | CC0 | 2026-08-29 | 否 |
| 16x16 Town Remix | `assets/tiles/16oga.png` | Sharm（协作 Redshrike、surt，含 Jetrel 物件） | https://opengameart.org/content/16x16-town-remix | CC-BY 4.0（该页多许可并列，选用档） | 2026-08-29 | 否 |
| Twelve 16x18 RPG sprites, plus base | `assets/characters/charsets_12_m-f_complete_by_antifarea.png` | Antifarea (Charles Gabriel) | https://opengameart.org/content/twelve-16x18-rpg-sprites-plus-base | CC-BY 3.0 | 2026-08-29 | 否 |
| 48x48 Faces 1st Sheet | `assets/faces/48x48_Faces_1st_Sheet_Update_CharlesGabriel_OGA.png` | CharlesGabriel | https://opengameart.org/content/48x48-faces-1st-sheet | CC-BY 3.0 | 2026-08-29 | 否 |
| Fusion Pixel Font (12px proportional, zh_hans) | `assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf` | TakWolf（缝合上游多作者，详见 notices/fusion-pixel-font.txt） | https://github.com/TakWolf/fusion-pixel-font | SIL OFL 1.1（清单预登记 CC-BY 4.0 有误，2026-08-29 经 README 与包内 OFL.txt 核实勘误） | 2026-08-29 | 否 |
```

> A7 状态注（2026-09-05 M7 终审补）：本字体**已随包分发**（pck 内含 ttf 本体与 .fontdata），但截至本次审计**尚未被项目引用**——`project.godot` 无默认主题字体，无场景或脚本 preload 它，游戏内中文依赖系统字体回退。OFL 的"随分发保留许可全文"义务已触发，须按第 4.2 节方案随包附带 `licenses/OFL-1.1.txt`。处置决策见 `production/release/m7-credits-audit.md` 第 1 节 A7。

### 6.2 B 区：仅保留实际存在的派生件

```markdown
## B. 修改资产

| 资产名 | 仓库内文件名 | 原资产 | 作者 | 来源 URL | 许可 | 入库日期 | 修改说明 |
|---|---|---|---|---|---|---|---|
| charsets_12_m-f_antifarea_bright.png | `assets/characters/charsets_12_m-f_antifarea_bright.png` | Twelve 16x18 RPG sprites（#5 全表） | Antifarea | （同上） | CC-BY 3.0 | 2026-08-29 | 角色层轻提亮一档（预混色，逐帧网格不变；美术骨架校色规范 2） |

> 2026-09-05 M7 终审：B 区仅登记**磁盘上真实存在**的派生件。原 R2/R3 两行（战斗头像裁切、敌人头像放大）截至本次审计未产出，已移入新增的第 E 区"规划中（未产出）"。
```

### 6.3 新增 E 区：规划中（未产出，无署名义务）

```markdown
## E. 规划中（未产出 · 无当前署名义务）

> 2026-09-05 M7 终审新增。本节记录**已规划但仓库内尚未产出**的派生件规格。
> 纪律：本节条目**不产生署名义务**（文件不存在即未分发）；一旦产出，须先移入 B 区登记、文件才落盘（登记纪律第 1 条）。

| 编号 | 计划派生件 | 基于源 | 规格与规则 | 原计划产出时机 | 当前状态（2026-09-05） |
|---|---|---|---|---|---|
| R2 | faces_32x32/<角色名>_battle.png | A6 · 48x48 Faces 1st Sheet | 48×48 **裁**眉眼区 32×32，禁缩放（48→32 非整数倍）；每角色一件 | 角色定稿后（M3 前） | **未产出**。`assets/faces/faces_32x32/` 为空目录。现行实现直接取 48×48 原生格零缩放（`scripts/dialogue/portrait_catalog.gd`） |
| R3 | enemies/<敌名>_portrait_32.png | D3 · 敌人战斗精灵（Ars Notoria，未取用） | 敌头像 = 战斗精灵 16×16 头部 **×2 整数放大**（Nearest）+ 1px #4A3B52 描边 | 敌人选型后（M2 前） | **未产出**。上游 D3 从未取用，`assets/enemies/` 为空目录。敌人视觉现为 ColorRect 暗红占位色块（`scenes/enemies/visible_enemy.tscn`） |
```

### 6.4 C 区：补注实查日期

在 C 区表头下方加一行：

```markdown
> 2026-09-05 M7 终审实查：以下 7 项**均未取用**，`assets/` 与 `export/win/轨迹残响.pck` 内均无对应文件，本区登记自洽。取用前须先移入 A 区（原样）或 B 区（派生），文件才落盘。
```

### 6.5 新增 F 区：红线符合性声明

```markdown
## F. M7 发布红线符合性声明（2026-09-05 终审）

**分发包（`export/win/轨迹残响.exe` + `.pck`）**：

| 红线 | 计数 | 核验方式 |
|---|---|---|
| CC-BY-SA 资产 | **0** | 逐个核对 A/B 区 8 条登记 + pck 二进制目录段 329 条路径 |
| GPL-only 资产 | **0** | 同上 |
| LPC 32×32 素材 | **0** | 全仓 39 个 png 按目录核对，游戏素材仅 7 件（瓦片 32×32/64×48/16×16、角色 16×18、头像 48×48） |
| bart 城堡件 | **0** | pck 内 `castle` 关键字命中 0 次（`exclude_filter` 含 `design/**`） |

**源码仓库**：⚠️ **bart 城堡件 2 件仍在库内**——
`design/art-bible/mockup/_src/castle_tiles.png`、`design/art-bible/mockup/_src/castle_tiles2.png`。
二者位于 `design/` 下、未被任何场景/脚本引用、且已被排除出分发包，但文件本体随 git 历史分发。
**结论：阻塞"仓库公开发布"路径，不阻塞"导出包分发"路径。** 处置须用户拍板（见 `production/release/m7-credits-audit.md` 第 3.4 节）。

**账本**：A 区 7 件（3×CC0 + 3×CC-BY + 1×OFL）+ B 区 1 件派生（CC-BY 3.0）= 磁盘素材文件 8 个。0×SA + 0×GPL 保持完好。
```

### 6.6 D 区致谢条目：补分发要求

在 D 区代码块上方加一行：

```markdown
> **分发要求（2026-09-05 M7 终审补）**：游戏内无致谢画面。本条目须以 `CREDITS.txt` 随分发包附带，并与 `licenses/` 目录（4 份许可全文 + 7 份 notice）一同打包——这是 CC-BY 署名义务与 OFL 保留许可全文义务在分发场景下的唯一落点。
```

---

## 7. 结论

**CREDITS 需要修订。** 修订内容共 5 处，全部为**登记口径与状态标注**问题，**不涉及任何许可判定的更正**——已入库资产的许可认定全部正确，notice 与许可全文齐备，字体许可勘误记录质量高。

| # | 修订项 | 性质 |
|---|---|---|
| 1 | A 区增补"仓库内文件名"列（解决 A4 命名歧义） | 可审计性 |
| 2 | A7 补注"已随包分发但未被引"状态 + 引出决策点 | 状态准确性 |
| 3 | B 区删除 2 条悬空登记，移入新增 E 区 | **违反 E7-S4 验收标准** |
| 4 | C 区补注实查日期与"未取用"结论 | 防误判 |
| 5 | 新增 F 区红线符合性声明 | 收官证据 |

**P0 阻塞项 1 条**：bart 城堡件 2 个文件在仓库内，**阻塞"源码仓库公开发布"分发路径**。不阻塞导出包分发（pck 内 0 命中）。

**P1 待办 1 条**：随包 CREDITS.txt + licenses/ 目录——**阻塞对外分发**，不阻塞 M7 门本身。

**须用户拍板的 3 件事**：
1. 是否按第 6 节文本修订 `assets/CREDITS.md`（我只给建议，未改动原文件）
2. bart 城堡件选哪个处置选项（推荐 ① 清理历史，若仓库计划公开）
3. Fusion Pixel 字体：接上用 / 从包里剔除 / 维持现状（推荐"接上用"）
