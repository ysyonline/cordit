# tools/ · 施工期工具

> 本目录是**施工期工具，不是游戏运行时依赖**。Godot 工程本身不加载这里的任何文件，不了解它们不影响理解游戏代码。
> 来源：E1-S5 小镇施工期产物，经 `production/tool-disposition.md` 裁决后于 commit `1e0295f` 入库。

## 调用顺序（EPIC-4 遗迹施工会克隆这套流程）

1. `python tile-inspect/analyze_tiles.py` — 逐 16×16 格统计图集 RGBA 像素，输出分类明细
2. `python tile-inspect/tile_ascii.py` — 把候选区域渲染成 ASCII 像画，供无图环境辨认证 tile
3. **人工选型** → 把选型结果写进生成器的选型表
4. `python gen_town.py` — 程序化生成 `scenes/maps/town.tscn` + `assets/tiles/town_map_tileset.tres`
5. `python verify_town.py` — 静态核验产物，全部 PASS 则退出码 0

> 事后手工改过 `.tscn` 的话，重跑第 5 步即可回归（M1 期 108/108 PASS 就是它产出的）。

## 已知缺陷（2026-08-30 主理人核查）

四个脚本内部硬编码了 `D:\code\cordit\...` 绝对路径，共 7 处：

| 脚本 | 行 | 硬编码内容 |
|---|---|---|
| `gen_town.py` | 380 / 382 | 输出的 .tres / .tscn 路径 |
| `verify_town.py` | 11 / 12 / 13 | 读取的 .tscn / .tres / .gd 路径 |
| `tile-inspect/analyze_tiles.py` | 8 | 读取的 `.rgba` 路径 |
| `tile-inspect/tile_ascii.py` | 38 | 读取的 `.rgba` 路径 |

**其中 `tile-inspect/` 两个脚本当前是坏的**：它们指向 `D:\code\cordit\production\*.rgba`，而 `.rgba` 文件已随裁决迁移到 `tools/tile-inspect/`，路径失效。

**影响与处理**：EPIC-4 遗迹施工要克隆这套工具，动工前必须先改为仓库相对路径（或加 argparse 参数），改动量约十行。已立案为待办，未修。
