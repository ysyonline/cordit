# E4-S0 证据档 · tools/ 硬编码路径修复 + 五步链路验收

> Story：Sprint 4 第 0 项（`production/sprints/sprint-4.md` §3 E4-S0）｜执行：程基岩｜日期：2026-08-30
> 实际耗时：约 **14 分钟**（837 秒，开工时间戳 1788085178 计），预算 1h，大幅结余（估因：改动为机械替换 + 无 Godot 环节）。
> 环境约束：Windows + Git Bash；Python 托管版全路径 `C:\Users\weixufeng\.workbuddy\binaries\python\versions\3.13.12\python.exe`（下文简写 `$PY`）。
> 约束遵守：未执行 git commit / git add，仅改工作区；未触碰运行时 GDScript / scenes / autoload（gen_town 重生成产物经 MD5 对比与修复前逐字节一致，等于未改）。

## 1. 改动文件清单（4 脚本 + 1 文档）

| 文件 | 改动 |
|---|---|
| `tools/gen_town.py` | ① 380/382 行两处输出路径改 `os.path.join(REPO_ROOT, ...)`；② 顶部新增 `REPO_ROOT = 脚本位置推算仓库根`（中文注释注明 E4-S0 修复）。原 380/382 行硬编码 `D:\code\cordit\assets\tiles\town_map_tileset.tres` 与 `D:\code\cordit\scenes\maps\town.tscn` 清除 |
| `tools/verify_town.py` | 11/12/13 行三处读取路径（.tscn / .tres / .gd）改仓库相对 `os.path.join(REPO_ROOT, ...)`；顶部新增 REPO_ROOT 推算 + 中文注释 |
| `tools/tile-inspect/analyze_tiles.py` | 第 8 行 `.rgba` 路径改 `os.path.join(RGBA_DIR, f"{name}.rgba")`，`RGBA_DIR` = 脚本所在目录；顺带清理未使用的 `statistics` 导入 |
| `tools/tile-inspect/tile_ascii.py` | 第 38 行 `.rgba` 路径同上改脚本所在目录；中文注释注明".rgba 已随裁决迁至 tools/tile-inspect/" |
| `tools/README.md` | 已知缺陷表清零（原表降级为 `<details>` 历史存档，注明 2026-08-30 E4-S0 修复与验收结论） |

方案口径：**仓库相对路径**（非 argparse）——四脚本统一用 `__file__` 推算目录，任何机器克隆仓库即在原地可跑，无参数负担；全部注释简体中文。
`grep -r "D:\code\cordit" tools/` 复核：脚本内硬编码为 0 残留（剩余匹配仅为注释里的历史说明与 README 存档文字）。

## 2. 五步调用顺序全链路（README §调用顺序，工作目录 `D:\code\cordit\tools`）

| 步 | 命令 | 结果 | 退出码 |
|---|---|---|---|
| 1 | `$PY tile-inspect/analyze_tiles.py` | 输出两图集 32×32 / 15×10 分类 ASCII 与逐格 RGB 明细（1076 行） | **0** |
| 2 | `$PY tile-inspect/tile_ascii.py` | 输出 ground/walls/roof 三批候选区 ASCII 像画（357 行） | **0** |
| 3 | 人工选型 → 写入生成器选型表 | 人工步骤，无可自动化执行；本次沿用 town 冻结选型表未改动 | —（人工） |
| 4 | `$PY gen_town.py` | 重生成 town_map_tileset.tres（16780 chars）+ town.tscn（175597 chars） | **0** |
| 5 | `$PY verify_town.py` | **108 PASS / 0 FAIL，全部通过 ✅** | **0** |

## 3. 回归证据（验收口径核心项）

1. **gen_town 产物零漂移**：开工前先留基线 MD5，第 4 步重生成后对比——
   - `scenes/maps/town.tscn`：`64176e3fd86ea2fd749c737621c27dc1`（基线 = 修复后，逐字节一致）
   - `assets/tiles/town_map_tileset.tres`：`e950d98e4cb066f261a0a7077961b621`（同上）
   - `diff` 无差异输出 → 路径改造对生成器输出零影响。
2. **verify_town 重跑全 PASS**：修复后重跑 town 产物核验 **108/108 全绿**（M1 基线 108/108 持平，无回归），退出码 0。
3. **tile-inspect 失效修复实证**：两脚本修复前指向已不存在的 `production\*.rgba`（必 FileNotFoundError）；修复后第 1、2 步成功读入 `tools/tile-inspect/town_tiles.rgba`（512×512）与 `forest_tiles.rgba`（240×160）并正常输出，退出码均 0。

## 4. 验收口径逐条勾对（sprint-4.md §3 E4-S0）

- ✅ 7 处硬编码绝对路径改仓库相对路径（§1 清单，逐处对应）
- ✅ tile-inspect 两脚本 `.rgba` 迁址路径同步修正，修路径保留（未归档，遵用户拍板）
- ✅ 五步调用顺序全链路复跑，退出码 0（第 3 步为人工选型步骤，如实标注）
- ✅ `tools/README.md` 已知缺陷表清零，注明 2026-08-30 E4-S0
- ✅ 不新增 GUT 用例（Python 工具非运行时依赖）；以 verify_town 重跑 108/108 PASS 作回归证据
- ✅ 未 git commit / git add；未触碰运行时代码

## 5. 本机复现步骤（用户侧）

```bash
cd D:\code\cordit\tools
python tile-inspect/analyze_tiles.py   # 步骤1，exit 0
python tile-inspect/tile_ascii.py      # 步骤2，exit 0
# 步骤3：人工选型（遗迹施工时才需要新选型）
python gen_town.py                     # 步骤4，exit 0
python verify_town.py                  # 步骤5，应输出 PASS 108 / FAIL 0，exit 0
```

> 注：沙箱内无法启动 Godot 编辑器，但五步链路均为纯 Python 静态管线，不依赖编辑器；产物完整性已由 MD5 一致性 + verify 108/108 双重覆盖，无需编辑器环节即可确认等价。
