# 素材致谢与登记（CREDITS）

> 本项目素材登记制：所有入库资产逐行登记；修改过的资产单独分区并注明 "modified from original"。
> 许可速查：CC0=无义务；CC-BY=须署名（作者+许可+链接）；OGA 系资产须回链 opengameart.org。
> 入库红线：CC-BY-SA 与 GPL-only 资产禁止入库（如确需引入，须经美术总监一审）。
> 实例化说明：依 asset-intake-list.md（TASK-11）第 3 节预览全文由林绘澄（art-director）代执行入库（TASK-14），入库日期 2026-08-29。

## A. 原样资产

| 资产名 | 仓库内文件名 | 作者 | 来源 URL | 许可 | 入库日期 | 是否修改 |
|---|---|---|---|---|---|---|
| Town Tiles | `assets/tiles/town_tiles.png` | surt | https://opengameart.org/content/town-tiles | CC0 | 2026-08-29 | 否 |
| Forest Tiles | `assets/tiles/forest_tiles.png` | surt | https://opengameart.org/content/forest-tiles | CC0 | 2026-08-29 | 否 |
| Classical Temple Tiles | `assets/tiles/classical_temple_tiles.png` | surt | https://opengameart.org/content/classical-temple-tiles | CC0 | 2026-08-29 | 否 |
| 16x16 Town Remix | `assets/tiles/16oga.png` | Sharm（协作 Redshrike、surt，含 Jetrel 物件） | https://opengameart.org/content/16x16-town-remix | CC-BY 4.0（该页多许可并列，选用档） | 2026-08-29 | 否 |
| Twelve 16x18 RPG sprites, plus base | `assets/characters/charsets_12_m-f_complete_by_antifarea.png` | Antifarea (Charles Gabriel) | https://opengameart.org/content/twelve-16x18-rpg-sprites-plus-base | CC-BY 3.0 | 2026-08-29 | 否 |
| 48x48 Faces 1st Sheet | `assets/faces/48x48_Faces_1st_Sheet_Update_CharlesGabriel_OGA.png` | CharlesGabriel | https://opengameart.org/content/48x48-faces-1st-sheet | CC-BY 3.0 | 2026-08-29 | 否 |
| Fusion Pixel Font (12px proportional, zh_hans) | `assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf` | TakWolf（缝合上游多作者，详见 notices/fusion-pixel-font.txt） | https://github.com/TakWolf/fusion-pixel-font | SIL OFL 1.1（清单预登记 CC-BY 4.0 有误，2026-08-29 经 README 与包内 OFL.txt 核实勘误） | 2026-08-29 | 否 |

> A7 状态注（2026-09-05 M7 收官批次更新）：本字体**已接入**为项目 GUI 默认字体（`project.godot` → `gui/theme/custom_font`），导入设置已关闭抗锯齿以保像素风。OFL 的"随分发保留许可全文"义务随包履行（`licenses/OFL-1.1.txt` 已随 pck 分发，见 D 区分发要求）。

## B. 修改资产

| 资产名 | 仓库内文件名 | 原资产 | 作者 | 来源 URL | 许可 | 入库日期 | 修改说明 |
|---|---|---|---|---|---|---|---|
| charsets_12_m-f_antifarea_bright.png | `assets/characters/charsets_12_m-f_antifarea_bright.png` | Twelve 16x18 RPG sprites（#5 全表） | Antifarea | （同上） | CC-BY 3.0 | 2026-08-29 | 角色层轻提亮一档（预混色，逐帧网格不变；美术骨架校色规范 2） |
| charsets_12_m-f_antifarea_bright_alpha.png | `assets/characters/charsets_12_m-f_antifarea_bright_alpha.png` | charsets_12_m-f_antifarea_bright.png（B 区上行） | Antifarea | （同上） | CC-BY 3.0 | 2026-09-06 | 背景色 (251,220,126) → alpha=0 转写（提亮件为 GIF 扁平化无透明通道，无法直接作引擎贴图）；其余像素逐色保留，帧网不变 |
| charsets_12_m-f_antifarea_bright_alpha_v1_elder.png | `assets/characters/charsets_12_m-f_antifarea_bright_alpha_v1_elder.png` | charsets_12_m-f_antifarea_bright_alpha.png（F6 兜帽长袍块） | Antifarea | （同上） | CC-BY 3.0 | 2026-09-06 | 调色板变体 V1：暗色长袍系 6 色 → 灰白长者袍（仅改色，网格/像素结构不变） |
| charsets_12_m-f_antifarea_bright_alpha_v2_porter.png | `assets/characters/charsets_12_m-f_antifarea_bright_alpha_v2_porter.png` | charsets_12_m-f_antifarea_bright_alpha.png（M1 块） | Antifarea | （同上） | CC-BY 3.0 | 2026-09-06 | 调色板变体 V2：金发/灰裤 3 色 → 深棕发/深裤（与玩家形象区分，仅改色） |
| charsets_12_m-f_antifarea_bright_alpha_v3_smith.png | `assets/characters/charsets_12_m-f_antifarea_bright_alpha_v3_smith.png` | charsets_12_m-f_antifarea_bright_alpha.png（M2 块） | Antifarea | （同上） | CC-BY 3.0 | 2026-09-06 | 调色板变体 V3：紫衣金发 6 色 → 炭灰衣黑发（铁匠炉火气质；皮革围裙色保留），仅改色 |
| charsets_12_m-f_antifarea_bright_alpha_v4_shepherd.png | `assets/characters/charsets_12_m-f_antifarea_bright_alpha_v4_shepherd.png` | charsets_12_m-f_antifarea_bright_alpha.png（F2 块） | Antifarea | （同上） | CC-BY 3.0 | 2026-09-06 | 调色板变体 V4：紫裙 4 色 → 土褐田野短打（牧羊少年；绿饰与金肤保留），仅改色 |

> 2026-09-05 M7 终审：B 区仅登记**磁盘上真实存在**的派生件。原 R2/R3 两行（战斗头像裁切、敌人头像放大）截至本次审计未产出，已移入第 E 区"规划中（未产出）"。

## C. 管线待入库（已核实许可、尚未取用）

> 2026-09-05 M7 终审实查：以下 7 项**均未取用**，`assets/` 与 `export/win/轨迹残响.pck` 内均无对应文件，本区登记自洽。取用前须先移入 A 区（原样）或 B 区（派生），文件才落盘。

| 资产名 | 作者 | 来源 URL | 许可 | 备注 |
|---|---|---|---|---|
| Sewer tileset | MrBeast | https://opengameart.org/content/sewer-tileset | CC-BY 3.0 | 遗迹一层（M4 前） |
| Cave tileset | MrBeast | https://opengameart.org/content/cave-tileset-0 | CC-BY 3.0 | 遗迹二层（M4 前） |
| Bosses and monsters spritesheets (Ars Notoria) | Balmer（原画 Redshrike） | https://opengameart.org/content/bosses-and-monsters-spritesheets-ars-notoria | CC-BY 3.0 | B1-B4+Boss 战斗精灵（M2 前）；侧视、DB32 调色板 |
| DawnLike v1.81 | DragonDePlatino, DawnBringer | https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181 | CC-BY 4.0 | 怪物/物品图标补充池 + 地图可见敌人（M2/M6 前） |
| Kenney UI Pack: RPG Expansion | Kenney | https://kenney.nl/assets/ui-pack-rpg-expansion | CC0 | 窗体框底稿/光标（重上色后入 B 区，M3 前） |
| 48x48 Face Template | CharlesGabriel | https://opengameart.org/content/48x48-face-template | CC-BY 3.0 | 差分自绘底模（Should-have，缓） |
| 16x16 Item-Icons | OGA 系多作者 | https://opengameart.org/content/16x16-item-icons | 逐文件核实后登记 | 物品图标备选（DawnLike 已覆盖主方案，可不取） |

## D. 致谢画面条目（credits-template 第三节四行式，按 A 区序生成）

> **分发要求（2026-09-05 M7 收官批次补）**：游戏内无致谢画面。本节条目以 `CREDITS.txt` 随分发包附带，并与 `licenses/` 目录（4 份许可全文 + 7 份 notice）一同随 pck 分发——这是 CC-BY 署名义务与 OFL 保留许可全文义务在分发场景下的落点（`export_presets.cfg` include_filter 已配置）。

```
作品：Town Tiles
作者：surt
许可：CC0 1.0
来源：https://opengameart.org/content/town-tiles

作品：Forest Tiles
作者：surt
许可：CC0 1.0
来源：https://opengameart.org/content/forest-tiles

作品：Classical Temple Tiles
作者：surt
许可：CC0 1.0
来源：https://opengameart.org/content/classical-temple-tiles

作品：16x16 Town Remix
作者：Lanea "Sharm" Zimmerman, Stephen "Redshrike" Challener, Carl "Surt" Olsson, Jetrel
许可：CC-BY 4.0
来源：https://opengameart.org （opengameart.org/content/16x16-town-remix）

作品：Twelve 16x18 RPG sprites, plus base
作者：Antifarea (Charles Gabriel)
许可：CC-BY 3.0
来源：https://opengameart.org （opengameart.org/content/twelve-16x18-rpg-sprites-plus-base）

作品：48x48 Faces 1st Sheet
作者：CharlesGabriel (Charles Gabriel)
许可：CC-BY 3.0
来源：https://opengameart.org （opengameart.org/content/48x48-faces-1st-sheet）

作品：Fusion Pixel Font（缝合像素字体，12px 比例模式简中档）
作者：TakWolf
许可：SIL Open Font License 1.1
来源：https://github.com/TakWolf/fusion-pixel-font
```

Town Remix 专属 notice 原文（亦存 licenses/notices/town-remix.txt）：

> Art by Lanea "Sharm" Zimmerman, Stephen "Redshrike" Challener, Carl "Surt" Olsson, and Jetrel, for OpenGameArt.org (http://opengameart.org)

## E. 规划中（未产出 · 无当前署名义务）

> 2026-09-05 M7 终审新增。本节记录**已规划但仓库内尚未产出**的派生件规格。
> 纪律：本节条目**不产生署名义务**（文件不存在即未分发）；一旦产出，须先移入 B 区登记、文件才落盘（登记纪律第 1 条）。

| 编号 | 计划派生件 | 基于源 | 规格与规则 | 原计划产出时机 | 当前状态（2026-09-05） |
|---|---|---|---|---|---|
| R2 | faces_32x32/<角色名>_battle.png | A6 · 48x48 Faces 1st Sheet | 48×48 **裁**眉眼区 32×32，禁缩放（48→32 非整数倍）；每角色一件 | 角色定稿后（M3 前） | **未产出**。现行实现直接取 48×48 原生格零缩放（`scripts/dialogue/portrait_catalog.gd`） |
| R3 | enemies/<敌名>_portrait_32.png | D3 · 敌人战斗精灵（Ars Notoria，未取用） | 敌头像 = 战斗精灵 16×16 头部 **×2 整数放大**（Nearest）+ 1px #4A3B52 描边 | 敌人选型后（M2 前） | **未产出**。上游 D3 从未取用。敌人视觉现为 ColorRect 暗红占位色块（`scenes/enemies/visible_enemy.tscn`） |

## F. M7 发布红线符合性声明（2026-09-05 收官批次）

**分发包（`export/win/轨迹残响.exe` + `.pck`）**：

| 红线 | 计数 | 核验方式 |
|---|---|---|
| CC-BY-SA 资产 | **0** | 逐个核对 A/B 区 8 条登记 + pck 二进制目录段 329 条路径（m7-credits-audit.md 第 3 节实查） |
| GPL-only 资产 | **0** | 同上 |
| LPC 32×32 素材 | **0** | 全仓 39 个 png 按目录核对，游戏素材仅 7 件（瓦片 32×32/64×48/16×16、角色 16×18、头像 48×48） |
| bart 城堡件 | **0** | 2 个文件已从仓库移除（commit `ad2efa2`），`exclude_filter` 亦含 `design/**` |

**源码仓库**：bart 城堡件 2 件（`design/art-bible/mockup/_src/castle_tiles.png`、`castle_tiles2.png`）已于 commit `ad2efa2` 移除。⚠️ 注意：git 历史中仍可检出旧版本；若仓库计划公开发布且需彻底清除，须另行清理历史（`git filter-repo` / BFG），属用户拍板项。

**账本**：A 区 7 件（3×CC0 + 3×CC-BY + 1×OFL）+ B 区 1 件派生（CC-BY 3.0）= 磁盘素材文件 8 个。0×SA + 0×GPL 保持完好。
