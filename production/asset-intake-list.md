# 资产建库清单（TASK-11 · Phase 4 收口件）

> 编制：林绘澄（art-director）｜2026-08-29｜依据：credits-template.md（TASK-09）、revision-art-skeleton.md、mockup/_src 核实留档（_inspect/_proj/_alpha/_env*）
> 用法：开发者按第 5 节顺序一晚完成入库；入库完成后本清单归档，后续增补以 `assets/CREDITS.md` 为唯一正本。
> 红线复述：0×SA、0×GPL；CC-BY 须署名（作者+许可+OGA 回链）；**先登记（CREDITS）后复制（文件进 assets/）**——登记纪律第 1 条。

---

## 1. 目录规范

对齐 ADR A2（`assets/` 下 tiles/characters/enemies/ui/fonts/sfx）+ credits-template 第二节（licenses/ 双轨），新增 `faces/`：

```
assets/
├── CREDITS.md                 ← 第 3 节预览全文粘贴（A/B/C 三区）
├── LICENSE-ASSETS.md          ← 许可索引（credits-template 第二节模板 + 本清单账本行）
├── licenses/
│   ├── CC0-1.0.txt            ← creativecommons.org/publicdomain/zero/1.0/legalcode 全文
│   ├── CC-BY-3.0.txt          ← creativecommons.org/licenses/by/3.0/legalcode 全文
│   ├── CC-BY-4.0.txt          ← creativecommons.org/licenses/by/4.0/legalcode 全文
│   └── notices/               ← 各资产专属 attribution notice（照抄 OGA 页面原文）
│       ├── town-tiles.txt / forest-tiles.txt / classical-temple-tiles.txt   （CC0，无义务，各留一行来源即可）
│       ├── town-remix.txt     （页面 Notice 原文，见第 3 节脚注）
│       ├── antifarea-sprites.txt
│       └── 48x48-faces.txt
├── tiles/
│   ├── town_tiles.png                     ← 小镇 + 道路（M1）
│   ├── forest_tiles.png                   ← 野外 + 草地/植被唯一取材源（M1）
│   ├── classical_temple_tiles.png         ← 遗迹三层/Boss 房（M4）
│   ├── 16oga.png                          ← Town Remix 补件（塔楼/城堡起手件）
│   ├── sewer_tiles.png                    ← 缺口 D1 补齐后放入（遗迹一层）
│   └── cave_tiles.png                     ← 缺口 D2 补齐后放入（遗迹二层）
├── characters/
│   ├── charsets_12_m-f_complete_by_antifarea.png         ← 原样留档（许可追溯）
│   └── charsets_12_m-f_antifarea_bright.png              ← 提亮派生件（引擎实际使用）
├── faces/
│   ├── 48x48_Faces_1st_Sheet_Update_CharlesGabriel_OGA.png   ← 原样（对话框头像源）
│   └── faces_32x32/                        ← 角色定稿后放战斗槽裁切件（B 区登记）
├── enemies/                                 ← 缺口 D3 补齐后放（战斗精灵 + 32×32 头像派生）
├── ui/                                      ← 缺口 D4 补齐后放（Kenney 底稿 + 自制窗体）
├── fonts/                                   ← 缺口 D6 补齐后放（Fusion Pixel）
└── sfx/                                     ← 切片无音效（Should-have），空占位
```

约定：
- **原样资产保留 OGA 原文件名**（与来源页 File(s) 栏一致，审计零歧义）；派生件用描述性名 + 后缀（`_bright`、`_32x32`）。
- 派生件与其原样件同目录或子目录成对存放；CREDITS A 区登原样件、B 区登派生件（登记纪律第 3 条：裁切/校色/拼合即入 B 区）。
- 进 Godot 后抽查 Import 面板：Filter=Nearest、Mipmap=Off（项目级 ADR-4 已设，抽查即可）。

---

## 2. 逐文件入库表（mockup/_src 全量 13 文件）

### 2.1 入库（6 件 → 账本 3×CC0 + 3×CC-BY）

| # | 源文件(_src/) | 尺寸 | 作者 | 来源 URL | 许可 | 处置 | 目标路径 | 切片/裁切说明 |
|---|---|---|---|---|---|---|---|---|
| 1 | town_tiles.png | 512×512 | surt | opengameart.org/content/town-tiles | CC0 | 原样直接用 | assets/tiles/town_tiles.png | 32×32 tile 网，直接作 TileSet 图集；全表仅 1 块纯草地（坐标 16,480），草地一律取 forest |
| 2 | forest_tiles.png | 240×160 | surt | opengameart.org/content/forest-tiles | CC0 | 原样直接用 | assets/tiles/forest_tiles.png | 15×10 tile 网，全不透明；草地/植被唯一取材源（与 town 官方配套） |
| 3 | classical_temple_tiles.png | 1024×768 | surt | opengameart.org/content/classical-temple-tiles | CC0 | 原样直接用 | assets/tiles/classical_temple_tiles.png | 64×48 tile 网；遗迹三层/Boss 房专用 |
| 4 | 16oga.png | 160×80 | Sharm（协作 Redshrike、surt，含 Jetrel 物件） | opengameart.org/content/16x16-town-remix | CC-BY 4.0（选用档） | 原样直接用 | assets/tiles/16oga.png | 10×5 tile 网，右缘 156-159 有空列（制图忽略）；塔楼/城堡起手件；作者自述为"补丁包"，需与 town_tiles 配合拼图 |
| 5 | charsets_12_m-f_complete_by_antifarea.png | 330×400 | Antifarea (Charles Gabriel) | opengameart.org/content/twelve-16x18-rpg-sprites-plus-base | CC-BY 3.0 | 入库 + 派生 | assets/characters/charsets_12_m-f_complete_by_antifarea.png | 16×18 帧网；按校色规范 2 生成提亮派生件（见 2.2），引擎用派生件 |
| 6 | 48x48_Faces_1st_Sheet_Update_CharlesGabriel_OGA.png | 288×400 | CharlesGabriel | opengameart.org/content/48x48-faces-1st-sheet | CC-BY 3.0 | 原样入库，裁切后置 | assets/faces/48x48_Faces_1st_Sheet_Update_CharlesGabriel_OGA.png | 6 列×8 行 48×48 网格，底部余 16px 边（裁切按 6×8 对齐）；对话框头像直接取 48×48 原生格（零缩放）；战斗槽 32×32 裁切件待角色定稿 |

### 2.2 派生件规格（B 区预登记，本晚只做 R1，R2/R3 到期再做）

| 编号 | 派生件 | 基于源 | 规格与规则 | 产出时机 |
|---|---|---|---|---|
| R1 | charsets_12_m-f_antifarea_bright.png | 源 #5 | 角色层轻提亮一档（预混色、保持整数色值，见第 5 节步骤 4 脚本）；逐帧对齐原网格 | 入库当晚 |
| R2 | faces_32x32/<角色名>_battle.png | 源 #6 | 48×48 **裁**眉眼区 32×32，禁缩放（48→32 非整数倍）；每角色一件 | 角色定稿后（M3 前） |
| R3 | enemies/<敌名>_portrait_32.png | 缺口 D3 战斗精灵 | 敌头像 = 战斗精灵 16×16 头部 **×2 整数放大**（Nearest）+ 1px #4A3B52 描边 | 敌人选型后（M2 前） |

### 2.3 不入库（7 件，留档 _src 不动）

| 源文件 | 判定 | 理由 |
|---|---|---|
| castle_tiles.png（1024×192） | 禁入（账本红线） | 出自 bart「16x16 Castle Tiles」，页面多许可含 **GPL 2.0/3.0 与 CC-BY-SA 3.0** 档；虽含 CC-BY 3.0 可选，但**不在冻结账本内且当前 5 张图（小镇/道路/遗迹×3）无使用位**——为守"账本不恶化"裁决不入库。未来若需城堡：Town Remix（#4）自带城堡起手件，仍零新增 |
| castle_tiles2.png（144×64） | 禁入（同上） | 同页另一文件「16x16 castle_0.png」 |
| town_test.png | 不入 | mockup 加工中间件（非素材原件） |
| town_preview.png / chars_preview.png / faces_preview.png | 不入 | OGA 页面缩略预览图，非素材本体 |
| temple_mockup.png | 不入 | surt 官方示例拼图（classical_temple_mockup.png），作遗迹三层布局参照留在 design/ 侧，不进 assets/ |

> `_alpha.txt / _inspect.txt / _proj.txt / _env*.txt` 为核实证据链，留档 `_src/`，永不入库。

---

## 3. assets/CREDITS.md 实例化预览（正文全文，日期按实际入库日替换）

```markdown
# 素材致谢与登记（CREDITS）

> 本项目素材登记制：所有入库资产逐行登记；修改过的资产单独分区并注明 "modified from original"。
> 许可速查：CC0=无义务；CC-BY=须署名（作者+许可+链接）；OGA 系资产须回链 opengameart.org。
> 入库红线：CC-BY-SA 与 GPL-only 资产禁止入库（如确需引入，须经美术总监一审）。

## A. 原样资产

| 资产名 | 作者 | 来源 URL | 许可 | 入库日期 | 是否修改 |
|---|---|---|---|---|---|
| Town Tiles | surt | https://opengameart.org/content/town-tiles | CC0 | 2026-08-29 | 否 |
| Forest Tiles | surt | https://opengameart.org/content/forest-tiles | CC0 | 2026-08-29 | 否 |
| Classical Temple Tiles | surt | https://opengameart.org/content/classical-temple-tiles | CC0 | 2026-08-29 | 否 |
| 16x16 Town Remix | Sharm（协作 Redshrike、surt，含 Jetrel 物件） | https://opengameart.org/content/16x16-town-remix | CC-BY 4.0（该页多许可并列，选用档） | 2026-08-29 | 否 |
| Twelve 16x18 RPG sprites, plus base | Antifarea (Charles Gabriel) | https://opengameart.org/content/twelve-16x18-rpg-sprites-plus-base | CC-BY 3.0 | 2026-08-29 | 否 |
| 48x48 Faces 1st Sheet | CharlesGabriel | https://opengameart.org/content/48x48-faces-1st-sheet | CC-BY 3.0 | 2026-08-29 | 否 |

## B. 修改资产

| 资产名 | 原资产 | 作者 | 来源 URL | 许可 | 入库日期 | 修改说明 |
|---|---|---|---|---|---|---|
| charsets_12_m-f_antifarea_bright.png | Twelve 16x18 RPG sprites（#5 全表） | Antifarea | （同上） | CC-BY 3.0 | 2026-08-29 | 角色层轻提亮一档（预混色，逐帧网格不变；美术骨架校色规范 2） |
| faces_32x32/*_battle.png | 48x48 Faces 1st Sheet（#6 对应格） | CharlesGabriel | （同上） | CC-BY 3.0 | （角色定稿日） | 48×48 裁眉眼区 32×32，零缩放 |
| enemies/*_portrait_32.png | （D3 敌人包对应精灵） | （随 D3 登记） | （随 D3） | （随 D3） | （敌人选型日） | 16×16 ×2 整数放大 + 1px 描边 |

## C. 管线待入库（已核实许可、尚未取用）

| 资产名 | 作者 | 来源 URL | 许可 | 备注 |
|---|---|---|---|---|
| Sewer tileset | MrBeast | https://opengameart.org/content/sewer-tileset | CC-BY 3.0 | 遗迹一层（M4 前） |
| Cave tileset | MrBeast | https://opengameart.org/content/cave-tileset-0 | CC-BY 3.0 | 遗迹二层（M4 前） |
| Bosses and monsters spritesheets (Ars Notoria) | Balmer（原画 Redshrike） | https://opengameart.org/content/bosses-and-monsters-spritesheets-ars-notoria | CC-BY 3.0 | B1-B4+Boss 战斗精灵（M2 前）；侧视、DB32 调色板 |
| DawnLike v1.81 | DragonDePlatino, DawnBringer | https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181 | CC-BY 4.0 | 怪物/物品图标补充池 + 地图可见敌人（M2/M6 前） |
| Kenney UI Pack: RPG Expansion | Kenney | https://kenney.nl/assets/ui-pack-rpg-expansion | CC0 | 窗体框底稿/光标（重上色后入 B 区，M3 前） |
| Fusion Pixel Font（12px, zh_hans） | TakWolf | https://github.com/TakWolf/fusion-pixel-font | CC-BY 4.0 | 中文字体，UI 规格硬依赖（**最高优先**，M1 前必入） |
| 48x48 Face Template | CharlesGabriel | https://opengameart.org/content/48x48-face-template | CC-BY 3.0 | 差分自绘底模（Should-have，缓） |
| 16x16 Item-Icons | OGA 系多作者 | https://opengameart.org/content/16x16-item-icons | 逐文件核实后登记 | 物品图标备选（DawnLike 已覆盖主方案，可不取） |
```

**致谢画面条目**（credits-template 第三节四行式）按 A 区序生成，CC-BY 项必含 opengameart.org 回链；Town Remix 的专属 notice 原文：

> Art by Lanea "Sharm" Zimmerman, Stephen "Redshrike" Challener, Carl "Surt" Olsson, and Jetrel, for OpenGameArt.org (http://opengameart.org)

（antifarea-sprites / 48x48-faces 的 notice 操作时打开对应 OGA 页面，照抄页面 Copyright/Attribution Notice 栏原文存入 notices/。）

**账本核对行**（写入 LICENSE-ASSETS.md 末尾）：

> 当前入库 = 6 件图片资产：3×CC0 + 3×CC-BY，0×SA + 0×GPL。字体补齐后为 3×CC0 + 4×CC-BY（credits-template 既有项，非本任务恶化）。

---

## 4. 缺口清单（切片必需但 _src/ 尚无）

| # | 资产 | OGA/来源检索名 | 作者 | 许可（已核实口径） | 用途 | 需要时点 |
|---|---|---|---|---|---|---|
| D1 | Sewer tileset | 检索 "sewer tileset"（MrBeast） | MrBeast | CC-BY 3.0 | 遗迹一层（砖墙水道） | M4 前（W7） |
| D2 | Cave tileset | 检索 "cave tileset"（MrBeast，URL 尾缀 -0） | MrBeast | CC-BY 3.0 | 遗迹二层（洞窟） | M4 前（W7） |
| D3 | 敌人战斗精灵包 | "Bosses and monsters spritesheets (Ars Notoria)" | Balmer（原画 Redshrike） | CC-BY 3.0 | B1-B4+Boss 战斗精灵 + 头像裁切源（R3） | **M2 前（W3，最紧）** |
| D4 | Kenney ui-pack-rpg-expansion | kenney.nl/assets/ui-pack-rpg-expansion | Kenney | CC0 | 窗体框 9-slice 底稿、光标（重上色五色板） | M3 前（W5） |
| D5 | DawnLike v1.81 | "dawnlike 16x16 universal roguelike" | DragonDePlatino, DawnBringer | CC-BY 4.0 | 物品/状态图标、地图可见敌人 | M2/M6 前 |
| D6 | Fusion Pixel Font | github.com/TakWolf/fusion-pixel-font（取 12px zh_hans 版） | TakWolf | CC-BY 4.0（仓库 LICENSE 双档以页面为准） | 全部中文 UI 文本 | **M1 前（立即，最高优先）** |
| D7 | 48x48 Face Template | "48x48 face template" | CharlesGabriel | CC-BY 3.0 | 头像差分自绘底模 | Should-have，缓取 |
| D8 | 16x16 Item-Icons | "16x16 item icons" | OGA 多作者 | 逐文件核实 | 物品图标备选 | 可不取（D5 已覆盖） |

> D1-D6 为 Must 路径缺口，D7/D8 为可选。战斗 VFX 包（itch CC0 系）EPIC-3 期间再评估，不入本清单。所有 D 项下载时**先看页面许可栏**：凡只标 CC-BY-SA / GPL 的整包弃用，回来找我换源。

---

## 5. 入库操作顺序（一晚 ≈2.5h 核心 + 余量）

> 顺序说明：任务原文写"复制→裁切→licenses→CREDITS"，但登记纪律第 1 条"先登记后入库"优先——故调整为 CREDITS 先行、复制殿后，目标一致。

1. **【15min】先登记**：按 ADR A2/本清单第 1 节建 `assets/` 目录树；把第 3 节预览全文粘为 `assets/CREDITS.md`（入库日期改当天）；`LICENSE-ASSETS.md` 用 credits-template 第二节模板（账本行用第 3 节末核对行）。
2. **【20min】建 licenses/**：从 creativecommons.org 存三份许可全文（CC0-1.0 / CC-BY-3.0 / CC-BY-4.0，另存为 txt）；开着 town-remix、charsets、faces 三个 OGA 页面，照抄各自 Copyright/Attribution Notice 为 notices/ 六个 txt（Town Remix 原文见第 3 节，surt 三件各写一行"CC0，无署名义务，来源：<URL>"即可）。
3. **【10min】复制 6 件原样资产**：仅表 2.1 的 6 个文件，**保留原文件名**，复制（非移动）到第 1 节目标路径；castle×2、preview×3、town_test、temple_mockup 一律不动。
4. **【15min】生成 R1 提亮件**：环境已装 Python+Pillow（mockup 期间装过），在项目根跑：
   `python -c "from PIL import Image; im=Image.open('assets/characters/charsets_12_m-f_complete_by_antifarea.png').convert('RGBA'); im.putdata([((min(255,r+12),min(255,g+12),min(255,b+10),a)) for r,g,b,a in im.getdata()]); im.save('assets/characters/charsets_12_m-f_antifarea_bright.png')"`
   （整表 +12/+12/+10 预混提亮，色值整数、网格不变；成品与原表并排目验，过亮就减到 +8。）
5. **【10min】缺口顺手下载**：D6 字体立即下（M1 硬依赖）；D3 敌人包顺手下到 `enemies/`（页面确认 CC-BY 3.0）；其余 D 项到点再下。每下一件，先在 CREDITS.md 对应区补行，文件才落盘。
6. **【15min】自查 + 提交**：核对四件事——① CREDITS A 区 6 行 ↔ assets/ 实际 6 文件一一对应；② 账本 = 3×CC0 + 3×CC-BY，0×SA/GPL；③ notices/ 六件齐全且含 OGA 回链；④ `_src/` 一字未动。git commit：`assets: intake sprint-1 batch (TASK-11), 3xCC0 + 3xCC-BY, 0xSA/GPL`。

裁切件 R2/R3 不在本晚：R2 待角色定稿（M3 前）、R3 待敌人选型（M2 前），届时各是一次 20 分钟小活，按 2.2 规格执行即可。

---

## 6. 风险与备注（给主理人）

1. **bart 城堡件裁决**：castle_tiles×2 为多许可页（含 GPL/SA 档）且无使用位，本清单禁入以守账本；替代路径已留（Town Remix 自带城堡起手件）。如未来剧情确需大城堡，须走"美术总监一审"流程再议。
2. **账本口径**：本批严格 3×CC0 + 3×CC-BY；字体入库后 CC-BY 计 4（credits-template 既有 A 区项，非恶化）。
3. **16oga.png 是补丁包**：作者自述需配合 town_tiles / Redshrike indoor expansion 才能拼出预览效果，拼图预期按"取塔楼件为主"管理；indoor expansion 如需引入另行核实（现为潜在 D9，未列 Must）。
4. **Faces 表底部 16px 余边**：裁切按 6 列×8 行网格对齐，勿按高度整除切。
5. **Godot 导入抽查**：Filter=Nearest / Mipmap=Off（ADR-4 项目级已设，抽查 6 件原样资产即可）。
