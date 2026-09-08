# M7 未提交变更 · 分批提交清单（2026-09-07）

> 工作区共 188 项变更（109 已跟踪修改 + 79 未跟踪/删除）。以下 8 批 + 1 项待裁定。
> 前置动作（P0）：① 跑一次 headless `--import` 补 `map_lighting.gd` / `test_m7a1.gd` 两个 .uid；② 逐批用 `git -c core.autocrlf=false diff --stat` 复核，零差异的 .import CRLF 噪音件剔除。

## 批次总表

| # | 提交信息草稿 | 核心文件 | 件数 |
|---|---|---|---|
| 1 | `feat(M7-R6): 接委托接线落地——story_quest_accept phase==0 守卫 + investigate_point 启用 quest_event_id 事件路径；GUT +9 至 523/523` | investigate_point.gd、map_events.gd、events/story_quest_accept.json、test_m7r6.gd+.uid、evidence/_m7-r6*-*.log×7、_r2_gut-red-polluted-appdata.log | 13 |
| 2 | `fix(M7-portrait): 头像系统修复+放大——faces 网格正本校正（人脸行 y=144/192/288/336）、头像窗 48→96、14 NPC 占位脸登记 + 71 处对话 JSON 回填 portrait；含 E7-S2 剧情统稿 6 处与 R6 键位提示 Z/E▼` | portrait_catalog.gd、dialogue_box.gd+.tscn、dialogues/ 29 件 JSON（含 story_p2/p3 三件统稿）、e7s2-gut.log、_faces_*×4、_m7-portrait-gut.log | 37 |
| 3 | `feat(M7-R7): 角色换装——char_anim.gd SpriteFrames 工厂 + player 四向行走/NPC 静态帧换装 + R4/R5 派生件×5 登记入库；NPC 形象分配初排待目检` | char_anim.gd+.uid、player.gd/.tscn、npc.gd/.tscn、assets/characters/×11、CREDITS.md、npc-sprite-assignment.md、tools/dev/_r2_*×5、_m7-r7-*.log×2 | 22 |
| 4 | `balance(E7-S1): B4/B5 数值调校——遗像守卫 HP240→360、遗迹核心 HP480→600（仅动 HP）；模拟器+GUT 证据入库` | guardian.tres、core.tres、test_e3s1.gd、test_e5s4.gd、_m7_balance_sim.gd+.uid、m7-balance-*.log×7 | 13 |
| 5 | `feat(M7-A1): town 俯视光照增强——MapLighting 静态装配器（CanvasModulate+7 光源径向渐变+呼吸闪烁）+ test_m7a1 7 用例 84 断言` | map_lighting.gd+补.uid、town_map.gd（含 R6 接线增量）、test_m7a1.gd+补.uid、m7a1-*×7 | 12 |
| 6 | `feat(M7-A2): town 装饰密度提升+占位件真贴图替换——DECO_FLORA 池+16oga 第四图集接入，壁炉/存档点真贴图；gen_town/verify_town 正本收编 P0_Anchor（verify 128/128）` | gen_town.py、verify_town.py、tile_ascii.py、16oga.rgba、scan_candidates.py、town_map_tileset.tres、town.tscn、m7a2-*×9（含 _inn/_sq 目录） | 16 |
| 7 | `build(M7): 导出管线入库——export_presets 递归 ** 排除+许可证过滤、project.godot 字体/方向键键位、e7s3 安装+管线 ps1` | export_presets.cfg、project.godot、fusion-pixel .ttf.import、tools/dev/e7s3_*.ps1×2、e7s3-export.log、m7-batch-*.log×5 | 9 |
| 8 | `docs(M7): QA 门禁/release 三件套/试玩工具包/素材台账 + 全程 GUT·导出证据归档 + 工作室记忆档案` | production/qa×4、production/release/×3、asset-intake-list.md、m7-qa-gate-*.log×3、.workbuddy/memory/×5 | 16 |

**合计约 138 件入库；design/ 52 件不在任何批次内（见下方待裁定）。**

## ⚠️ 待裁定 1：design/ 52 件磁盘删除（原因不明，阻塞批次划分外的一切）

- `git status` 显示 52 件 ` D`（index 仍在、磁盘已无）= **整个 design/ 目录从磁盘上消失**：GDD v1.1（battle-system-gdd.md）、art-bible、temple-tileset-selection、audio-direction、game-concept 全没。
- bart 清理 commit `ad2efa2` 只删了 castle_tiles 4 件（已入库）；**其余 48 件的删除没有任何 commit 记录**，非本次会话所为。
- 风险：GDD 是战斗数值正本（§3.6/§7 均被引用）；悬置不处理会让后续 git 操作长期背着 52 条噪音。
- 选项：**A. 全量恢复**（`git checkout -- design/`，最稳）；**B. 确认删除入库**（`git rm -r design/` 单独一个 commit）；**C. 暂时搁置**（不推荐，噪音持续存在）。
- 若选 A 恢复后仍想要"仓库瘦身"，可另行立项做带存档的归档迁移，不与本次混批。

## ⚠️ 待裁定 2：.uid 补齐方式

- 缺失：`scripts/maps/map_lighting.gd.uid`、`tests/gut/test_m7a1.gd.uid`（项目纪律".gd 必配 .uid"）。
- 建议跑一次 headless `--import` 自动生成（顺带校验资源无报错），生成的 uid 值进批次 5。

## 执行规则

1. 每批 `git add` 精确路径（禁 `git add -A`），commit 后 `git status` 复核无越界暂存；
2. 批 3/5 之间无依赖可任意序；批 6 依赖批 5 的 town_map.gd 无冲突（同文件不同段，town_map.gd 只在批 5）；
3. 全部批次完成后跑全量 GUT（APPDATA 重定向干净环境）确认 530/530，再由你决定是否 push；
4. 按约定：清单过目拍板后执行，每批 commit 完成即停、汇报等确认。
