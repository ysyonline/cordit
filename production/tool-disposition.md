# production/ 临时工具裁决表（TASK-S2-03）

> 编制：程基岩（engineering-lead）｜日期：2026-08-29
> 性质：**仅裁决建议，未执行任何删除/移动**——全部 7 件现状保持原位（当前均为 git 未跟踪状态），待主理人/用户拍板后由人工执行。
> 背景要点：7 件全部产生于 E1-S5 小镇施工期；`gen_town.py` 头部自述"一次性施工工具，工作缓存，不随 git 提交"，但该约定是当时的临时口径，本表按"EPIC-2 之后的实际价值"重新裁决。

## 1. 裁决总表

| # | 对象 | 裁决建议 | 建议目标路径 | 理由（一句话） |
|---|---|---|---|---|
| 1 | `analyze_tiles.py` | **保留入库** | `tools/tile-inspect/analyze_tiles.py` | 通用图集像素统计/分类器，"无图环境辨认证 tile"的施工基建，EPIC-4 遗迹新图集选型可直接复用 |
| 2 | `tile_ascii.py` | **保留入库** | `tools/tile-inspect/tile_ascii.py` | 同上：ASCII 像画渲染是 tile 像素级辨认的唯一手段，与 #1 构成一套工具 |
| 3 | `town_tiles.rgba` | **保留入库** | `tools/tile-inspect/town_tiles.rgba` | #1/#2 的唯一输入格式（python 无解码依赖即跑），离开它工具是死的；1.0 MB 一次性成本 |
| 4 | `forest_tiles.rgba` | **保留入库** | `tools/tile-inspect/forest_tiles.rgba` | 同 #3（153 KB）；两件 rgba 与两个脚本必须同进退，拆开裁决会让保留的工具失去数据 |
| 5 | `gen_town.py` | **保留入库** | `tools/gen_town.py` | town.tscn 的唯一"源码"（程序化生成器），内含 TileMapLayer tile_map_data 二进制格式的可运行实现，EPIC-4 遗迹三层地图生成器将以此克隆 |
| 6 | `verify_town.py` | **保留入库** | `tools/verify_town.py` | 与 gen_town.py 配对的静态核验器（M1 期 108/108 PASS 的证据生产者），后续手工改 town.tscn 后重跑即回归；遗迹核验器同款克隆 |
| 7 | `tile_analysis.txt` | **归档** | `production/archive/tile_analysis.txt` | 它是 #1 的输出快照，价值 = E1-S5 选型决策证据（裁量点追溯），选型已冻结进 gen_town.py 选型表，留档即可不必入库主树 |

## 2. 组合关系说明（裁决不可拆的三组）

- **工具组**（#1 #2 #3 #4）：两个脚本只吃 `.rgba` 原始像素缓存；`.rgba` 离开脚本又只是无人解码的二进制。**四件要么全保留、要么全归档**，不存在有意义的中间态。
- **施工组**（#5 #6）：生成器与核验器是一对，分开保留没有意义。
- **快照件**（#7）：独立于以上两组，纯历史证据。

> 若主理人倾向省 git 体积：备选方案是工具组四件**整体归档**（连 zip 留 `production/archive/`），代价是 EPIC-4 遗迹施工要重新搭 tile 辨认管线。本表不推荐——1.2 MB 换一条已在 M1 验证过的施工管线，收益明确。

## 3. 入库执行时的两个注意事项（不阻塞裁决）

1. **硬编码绝对路径**：#1/#2/#3 内部写死 `D:\code\cordit\production\...`，#5/#6 写死输出/读取路径——入库时需改为仓库相对路径（或加 argparse 参数），改动量约十行以内。
2. **gen_town.py 头部注释**需同步改写（原"不随 git 提交"口径作废），并在 `tools/` 建一个两行的 README 说明生成/核验的调用顺序，避免后来者误把生成器当运行时依赖。

## 4. 状态

- [x] 主理人过目（2026-08-30，游承峰：裁决表成立，同意按建议执行）
- [x] 用户拍板（2026-08-30，随 Sprint 2 基建收口一并确认）
- [x] 按裁决执行（**移动/归档已完成**，commit `1e0295f`）

**执行结果核对（2026-08-30 主理人复查）**：

| # | 对象 | 裁决 | 实际落点 | 核对 |
|---|---|---|---|---|
| 1 | `analyze_tiles.py` | 保留入库 | `tools/tile-inspect/analyze_tiles.py` | 已到位 |
| 2 | `tile_ascii.py` | 保留入库 | `tools/tile-inspect/tile_ascii.py` | 已到位 |
| 3 | `town_tiles.rgba` | 保留入库 | `tools/tile-inspect/town_tiles.rgba` | 已到位 |
| 4 | `forest_tiles.rgba` | 保留入库 | `tools/tile-inspect/forest_tiles.rgba` | 已到位 |
| 5 | `gen_town.py` | 保留入库 | `tools/gen_town.py` | 已到位，头部注释已改写 |
| 6 | `verify_town.py` | 保留入库 | `tools/verify_town.py` | 已到位 |
| 7 | `tile_analysis.txt` | 归档 | `production/archive/tile_analysis.txt` | 已到位 |

## 5. 遗留缺陷（§3 注意事项 1 未执行）

**§3 第 1 条"硬编码绝对路径改为相对路径"没有做。** 2026-08-30 主理人复查确认：4 个脚本共 7 处硬编码 `D:\code\cordit\...`，其中 `tile-inspect/` 两脚本指向的 `.rgba` 已随本次裁决迁走，**路径失效、脚本当前跑不起来**。

- 影响面：不影响游戏本体（工具非运行时依赖）；阻塞点是 **EPIC-4 遗迹施工需要克隆这套工具**。
- 修复量：约十行（改为仓库相对路径或加 argparse 参数）。
- 状态：**待办**，已同步记入 `tools/README.md` 的"已知缺陷"一节。建议在 EPIC-4 动工前，作为一条独立小任务派给工程侧处理。

> 教训：裁决表的"注意事项"段与"状态"段分离，导致执行时只做了裁决动作、漏了附带整改。后续同类裁决应把注意事项一并列入可勾选清单。
