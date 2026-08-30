# E4-S3 证据档 · 遗迹三层地图（gen → verify → GUT 三层验收）

> Story：Sprint 4 第 4 项（`production/sprints/sprint-4.md` §3 E4-S3 + `production/epics/EPIC-4.md` E4-S3）
> 执行：工程=程基岩（≈1h：框架计时 53 分钟 / 工件时间戳窗口 56 分钟，复核属实）；收尾补档=主理人代笔（程基岩收尾会话 429 限流中断，用户指示 A+B 双线——主理人沿 E4-S2 先例补档、程基岩复核）｜日期：2026-08-30
> 约束遵守：未 git commit / git add；注释简体中文；产物经用户验收前不视为终版。

## 1. 交付文件清单（2 工具 + 1 TileSet + 3 场景 + 3 地图脚本 + 1 测试 + 2 证据）

| 文件 | 性质 | 说明 |
|---|---|---|
| `tools/gen_ruins.py` | 新增 | 遗迹三层生成器（克隆 gen_road 模板）：f1 56×44 / f2 48×48 / f3 40×40 一次生成；开阔厅+窄走廊结构 |
| `tools/verify_ruins.py` | 新增 | 静态核验器 **156 项**：节点树/层抽验/点位对表/BFS 连通与密度/spawn 8 格安全/结构自查（含 f3 深处感三件套） |
| `assets/tiles/ruins_tileset.tres` | 新增 | 遗迹 TileSet——classical_temple_tiles.png 单图集（CC0/surt，选型表 `design/assets/temple-tileset-selection.md`）；Walls 层 tile 全挂碰撞 |
| `scenes/maps/ruins_f1.tscn` | 生成 | f1 场景（128310 chars，56×44=896×704px） |
| `scenes/maps/ruins_f2.tscn` | 生成 | f2 场景（119363 chars，48×48=768×768px） |
| `scenes/maps/ruins_f3.tscn` | 生成 | f3 场景（85839 chars，40×40=640×640px） |
| `scripts/maps/ruins_f1_map.gd` | 新增 | 地图根脚本（克隆 road_map 简版）：限区 + pos_from_road 落位 (448,56)；Triggers 留 E4-S6 |
| `scripts/maps/ruins_f2_map.gd` | 新增 | 同上：pos_from_f1 落位 (384,40) |
| `scripts/maps/ruins_f3_map.gd` | 新增 | 同上：pos_from_f2 落位 (320,40) |
| `tests/gut/test_e4s3.gd` | 新增 | GUT 8 用例：PackedScene 引擎级装载/四层 tileset/点位对表/敌人形态/f2 定守/f1 巡逻/f3 Boss 前厅构图/限区落位 |
| `evidence/e4s3-gut-baseline.log` | 证据 | 开工前基线 221/221 PASS |
| `evidence/e4s3-gut-s3.log` | 证据 | 收口全量回归 **229/229 PASS**（221 存量零回归 + 8 新增）；首版因跑错 exe 路径产生坏日志，主理人已用正确路径重跑覆写 |

## 2. 三层设计（对表探索 GDD §3.1 三层行 + §3.2）

| 层 | 尺寸（tile） | BFS 最短路 | 结构 | 敌人 |
|---|---|---|---|---|
| f1 | 56×44 | 109 tile ≈ 24s 纯走（达标 90-320） | 入口前厅 → 开阔厅 + 窄走廊；入口 2×2 空地预留（回复点不设，I6 冻结） | 2×b3_ruin_mix 巡逻（salamander@(20,22) / crystal@(36,25)，各 2 waypoints） |
| f2 | 48×48 | 113 tile ≈ 25s（达标 90-320） | 中央大厅 + 环廊；精英站位 x14-33/y12-31 中央带 | 1×b4_guardian **定守**（waypoints=0，站位即交战位） |
| f3 | 40×40 | 78 tile ≈ 17s（达标 60-280） | Boss 前厅：石棺祭坛 + 神像×2 + 灰石门（Boss 门位封死，E5 事件开启） | **0 普通敌人**（Boss 事件触发，GDD f3 行） |

- **纵向推进暗示**（结构自查专项）：三层尺寸递减（56×44→48×48→40×40）+ f3 深处感三件套（石棺+神像+灰石门）verify PASS。
- **TileSet 零素材新增**：三层全用 classical_temple_tiles 单图集（选型已冻结，2026-08-30 拍板）。

## 3. 点位对表（全部顺路验证 detour ≤20）

| 层 | 宝箱 | 调查 | GDD §3.1 对表 |
|---|---|---|---|
| f1 | 3：(4,20)(50,9)(24,39) | 4：(32,2)(30,11)(28,23)(18,37) | 宝箱 3 / 调查 4 ✅ |
| f2 | 2：(8,20)(38,27) | 3：(21,2)(38,10)(14,41) | 宝箱 2 / 调查 3 ✅ |
| f3 | 1：(21,35) | 2：(18,35)(12,16) | 宝箱 1 / 调查 2 ✅ |

Boss 触发器锚点 ×2（f3 石棺前，E5 事件数据位预留）；三层 Triggers 容器均留 E4-S6 接线（空容器）。

## 4. 验收口径逐条勾对（EPIC-4 原文）

- ✅ **三层纵向推进"往深处去"暗示成立（结构自查）**：verify_ruins 156 项含纵向推进专项 3 项 PASS
- ✅ **各层宝箱/调查点数量对表（3+2+1 / 4+3+2）**：verify §4 三层十三项 + GUT 用例 3 双重覆盖
- ✅ **f2 精英定守位即交战位**：GUT 用例 5（waypoints=0 + 站位中央带断言）+ verify f2 §7
- ✅ GUT 6-8 用例：**8 例**（简报上限内）
- ✅ 全量回归 **229/229 PASS exit 0**（221 存量零回归 + 新增 8）
- ✅ tileset 登记先行（classical_temple_tiles CC0/surt 已入库+选型表，先登记后复制纪律遵守）

## 5. 主理人独立复验记录（不采信自报）

| 验证项 | 结果 |
|---|---|
| test_e4s3.gd 单文件复跑 | 8/8 PASS |
| GUT 全量复跑 | 229/229 PASS（与收口日志一致） |
| verify_ruins.py 复跑 | PASS 156 / FAIL 0 |
| 场景/脚本/tileset/工具落盘核对 | 12 文件全部在位 |

## 6. 程基岩复核结论（2026-08-30 晚回传，原话摘要）

- **PASS 零修正**：verify_ruins 本机复跑 156/0；BFS 109/113/78 与证据档逐字一致；f1 双敌 waypoints×2、f2 精英 b4_guardian waypoints=0 站位带 x14-33/y12-31 全对；GUT 229/229 确认。
- 工时佐证：工件时间戳窗口 21:12→22:08 = 56 分钟，EPIC-4「实际 ≈1h」如实；结构配方系前两轮围合式布局 BFS 真 FAIL 后复用 road 配方纠偏（"复用 E4-S2 抵扣"定性准确）。
- **E4-S4 接手预判：低难度全绿可接**——f1 waypoints×2 / f2 waypoints=0 均为 visible_enemy.gd 现行导出量，S4 只在 _physics_process 按态机分支消费，零改图零改场景；"空列表=原地驻守"注释即 S4 预留锚点；接触遇敌已拆公开 _handle_player_contact 供 GUT 驱动（沿用 E2-S2 先例）。唯一正活：现态机无显式 state 枚举，S4 需先引三态枚举与迁移规则（非 S3 欠账）。

## 7. 环境备注与移交事项（给 E4-S4 / E4-S6）

1. **环境坑（复核发现）**：verify/gen 系 Python 脚本在 PowerShell 控制台跑会因 GBK 打不出"✅"抛 UnicodeEncodeError（断言已全跑完才崩，非产物问题）；**统一用 Git Bash 跑**，或设 `PYTHONIOENCODING=utf-8`。
2. **E4-S4 敌人三态**：数据面零欠账（见 §6）；建议仍由程基岩接（三层结构与其手上 waypoints 摆位即三态测试场）。
3. **E4-S6 传送接线**：三层 Triggers 容器已预留；spawn 落位导出量 pos_from_road / pos_from_f1 / pos_from_f2 已就位；三层均有 E4-S6 衔接注释（map_ready 自动存档时机）。
4. gen_ruins / verify_ruins 尚未登记进 `tools/README.md` 工具清单（与 gen_road/verify_road 一并整理，S6 前补）。
5. 真实体感走图（三层连穿 + f2 精英遭遇）留待用户本机 M4 试玩实测。
