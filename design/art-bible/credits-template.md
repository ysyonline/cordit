# CREDITS 合规模板（策略 A 生效版）

> 作者：林绘澄（art-director）｜TASK-09 产物 3｜依据：TASK-07 报告第四节"署名与合规操作清单"
> 用法：正式开工时将本模板实例化为 `assets/CREDITS.md`（双轨制登记）与 `assets/licenses/` 目录；`LICENSE-ASSETS.md` 放 `assets/` 根目录作索引。

---

## 一、`assets/CREDITS.md` 模板（双轨制）

```markdown
# 素材致谢与登记（CREDITS）

> 本项目素材登记制：所有入库资产逐行登记；修改过的资产单独分区并注明 "modified from original"。
> 许可速查：CC0=无义务；CC-BY=须署名（作者+许可+链接）；OGA 系资产须回链 opengameart.org。
> 入库红线：CC-BY-SA 与 GPL-only 资产禁止入库（如确需引入，其衍生/合并贴图集须按同许可开放，且入库前须经美术总监一审）。

## A. 原样资产（unmodified）

| 资产名 | 作者 | 来源 URL | 许可 | 入库日期 | 是否修改 |
|---|---|---|---|---|---|
| Town Tiles | surt | https://opengameart.org/content/town-tiles | CC0 | 2026-08-29 | 否 |
| Forest Tiles | surt | https://opengameart.org/content/forest-tiles | CC0 | 2026-08-29 | 否 |
| Classical Temple Tiles | surt | https://opengameart.org/content/classical-temple-tiles | CC0 | 2026-08-29 | 否 |
| 16x16 Town Remix | Sharm, Redshrike, surt (含 Jetrel 物件) | https://opengameart.org/content/16x16-town-remix | CC-BY 4.0（该页多许可并列，选用档；另有 CC-BY 3.0 / OGA-BY 3.0） | 2026-08-29 | 否 |
| Twelve 16x18 RPG sprites, plus base | Antifarea (Charles Gabriel) | https://opengameart.org/content/twelve-16x18-rpg-sprites-plus-base | CC-BY 3.0 | 2026-08-29 | 否 |
| 48x48 Faces 1st Sheet | CharlesGabriel (Charles Gabriel) | https://opengameart.org/content/48x48-faces-1st-sheet | CC-BY 3.0 | 2026-08-29 | 否 |
| Fusion Pixel Font (12px, zh_hans) | TakWolf | https://github.com/TakWolf/fusion-pixel-font | CC-BY 4.0 | 2026-08-29 | 否 |

## B. 修改资产（modified from original）

| 资产名 | 原资产 | 作者 | 来源 URL | 许可 | 入库日期 | 修改说明 |
|---|---|---|---|---|---|---|
| （示例行）角色立绘·凯尔 | Twelve 16x18 RPG sprites（strus0 号位） | Antifarea | （同上） | CC-BY 3.0 | （入库日） | 校色提亮一档 + 差分表情自绘（基于 48x48 Face Template） |

## C. 管线待入库（已核实许可、尚未取用）

| 资产名 | 作者 | 来源 URL | 许可 | 备注 |
|---|---|---|---|---|
| Sewer tileset | MrBeast | https://opengameart.org/content/sewer-tileset | CC-BY 3.0 | 遗迹一层 |
| Cave tileset | MrBeast | https://opengameart.org/content/cave-tileset-0 | CC-BY 3.0 | 遗迹二层 |
| DawnLike 16x16 Universal Roguelike v1.81 | DragonDePlatino, DawnBringer | https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181 | CC-BY 4.0 | 怪物/物品补充池 |
| 16x16 Item-Icons | OGA 系多作者 | https://opengameart.org/content/16x16-item-icons | 逐文件核实后登记 | 物品图标备选 |
| Kenney UI Pack: RPG Expansion | Kenney | https://kenney.nl/assets/ui-pack-rpg-expansion | CC0 | 窗体框底稿（重上色后入 B 区） |
| 48x48 Face Template | CharlesGabriel | https://opengameart.org/content/48x48-face-template | CC-BY 3.0 | 差分自绘底模 |
```

---

## 二、`assets/licenses/` 目录结构 + `LICENSE-ASSETS.md` 索引模板

**目录结构：**
```
assets/
├── CREDITS.md                  ← 第一节模板实例
├── LICENSE-ASSETS.md           ← 许可索引（下模板）
└── licenses/
    ├── CC0-1.0.txt             ← CC0 通用文本（一份）
    ├── CC-BY-3.0.txt           ← CC-BY 3.0 通用文本
    ├── CC-BY-4.0.txt           ← CC-BY 4.0 通用文本
    ├── OGA-BY-3.0.txt          ← OGA-BY 3.0 通用文本
    └── notices/                ← 各资产专属 attribution notice
        ├── town-tiles.txt          （原文照抄页面 Copyright/Attribution Notice）
        ├── town-remix.txt
        ├── antifarea-sprites.txt   （含"须回链 OGA"要求原文）
        ├── 48x48-faces.txt
        └── fusion-pixel-font.txt   （含字体许可双档说明）
```

**`LICENSE-ASSETS.md` 索引模板：**
```markdown
# 素材许可索引（LICENSE-ASSETS）

| 资产 | 许可 | 通用文本 | 专属 notice | 署名义务摘要 |
|---|---|---|---|---|
| Town Tiles / Forest Tiles / Classical Temple Tiles | CC0 | licenses/CC0-1.0.txt | 无 | 无（仍列入 CREDITS 以示尊重） |
| 16x16 Town Remix | CC-BY 4.0 | licenses/CC-BY-4.0.txt | notices/town-remix.txt | 署名四位作者 + 回链 opengameart.org |
| 16x18 角色表（Antifarea） | CC-BY 3.0 | licenses/CC-BY-3.0.txt | notices/antifarea-sprites.txt | 署名 Antifarea/Charles Gabriel + 回链 opengameart.org |
| 48x48 Faces（CharlesGabriel） | CC-BY 3.0 | licenses/CC-BY-3.0.txt | notices/48x48-faces.txt | 署名 Charles Gabriel + 回链 opengameart.org |
| Fusion Pixel Font | CC-BY 4.0 | licenses/CC-BY-4.0.txt | notices/fusion-pixel-font.txt | 署名 TakWolf + 字体名 |

结论行：本项目当前入库资产 = 3×CC0 + 3×CC-BY + 0×CC-BY-SA + 0×GPL。itch/Steam 商用发布无许可冲突。
```

---

## 三、游戏内致谢画面条目格式

主菜单"制作名单"入口 → 滚动列表，**每个资产一组四行**；CC-BY 项（及一切 OGA 系资产）必须含 opengameart.org 回链（OGA 系硬要求）：

```
作品：Town Tiles
作者：surt
许可：CC0 1.0
来源：https://opengameart.org/content/town-tiles

作品：Twelve 16x18 RPG sprites
作者：Antifarea (Charles Gabriel)
许可：CC-BY 3.0
来源：https://opengameart.org （opengameart.org/content/twelve-16x18-rpg-sprites-plus-base）

作品：Fusion Pixel Font（中文字体）
作者：TakWolf
许可：CC-BY 4.0
来源：https://github.com/TakWolf/fusion-pixel-font
```

格式规则：① 顺序按 CREDITS.md A 区登记序；② 修改资产同样按原资产信息署名，并在作品名后加注"（修改版）"；③ 致谢画面数据直接从 CREDITS.md 生成（构建期解析或手工同步，二者选一并在管线注释标明）。

---

## 四、登记纪律（写入管线约定）

1. **先登记后入库**：任何素材文件进 `assets/` 前，CREDITS.md 对应行必须已存在。
2. **多许可资产只登记选用档**（如 Town Remix 登记为 CC-BY 4.0），避免许可混淆。
3. **修改即入 B 区**：校色/裁切/拼合过的资产从 A 区移至 B 区并写明修改说明。
4. **发布前自查**：每次对外发布（itch 页面更新/Steam 构建）前，跑一遍"CREDITS.md ↔ assets/ 目录 ↔ 致谢画面数据"三方一致性核对。

——模板完。预填 7 项已核实资产（3 CC0 + 3 CC-BY + 字体 CC-BY 4.0）+ 6 项管线待入库。
