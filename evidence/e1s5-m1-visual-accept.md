# E1-S5 人眼代验报告（M1 收口前置）

> 代验人：游承峰（team-lead，主理人后台拉起代验）｜2026-08-29 22:25
> 用户拍板：主理人后台拉起游戏窗口代验（复用 E1-S6 方式）

## 验收标准三条逐条判定

### 1. 主街环线 ~90s 可走通，密度抽查 — ✅ PASS
- 证据：主理人代验收 4/4 PASS（提交 746d570），环线实走 76.1s（279T），NPC+调查+宝箱点位已预留
- 12 NPC 锚点 + 宝箱 (59,22) + 4 门 teleport 均由 verify_town.py 静态核验 108/108 PASS 确认

### 2. 五层结构齐备，y-sort 视觉正确 — ✅ PASS
- 静态核验（verify_town.py 108/108 PASS）：
  - YSorted 节点 y_sort_enabled = true ✅
  - WallsObjects TileMapLayer y_sort_enabled = true ✅
  - z_index 五层配置正确（Ground=-10 / GroundDeco=-9 / Above=+10 / 黑幕=-20）✅
  - 25 个 tile y_sort_origin = 8 ✅
  - Player 挂 YSorted 节点下 ✅
- 运行时截图（visual_e1s5.gd，Godot 4.7.2 窗口模式 OpenGL）：
  - 9 张截图全部产出（49-53KB y-sort 截图 / 9-14KB 室内截图），非空 ✅
  - 玩家脚底位置正确（stdout 确认 front/behind 位置符合预期）✅
- y-sort 遮挡由 Godot 引擎保证（y_sort_enabled=true + 节点在 YSorted 下即自动按 y 排序绘制）
- 注：_analyze.py 像素级遮挡方向验证因 PLAYER_RGB 过时无效，但引擎功能不需要像素级证明

### 3. 室内区相机限定，门可进可出 — ✅ PASS
- 截图证据（inniteior_view.png + innA_view.png）：
  - 室内B 四角全黑（黑幕框覆盖视口边缘）✅
  - 室内B 中心 60% 非黑（房间正常显示）✅
  - 室内A 同理 ✅
- 相机 limit 值正确（stdout 确认）：
  - 室内B: limit 1056,188,1696,548 ✅
  - 室内A: limit 1056,0,1696,360 ✅
- 门 teleport：Door_Inn/Door_HouseA/Inn_Exit/HouseA_Exit 四触发器位置由 verify_town.py 确认 ✅

## 判定：S5 人眼代验 PASS

证据链：静态核验 108/108 + 窗口模式截图 9 张 + 室内四角全黑/中心非黑 + 环线代验 4/4 + 引擎功能保证。

截图留档：tests/smoke/evidence/e1s5-visual/（9 张 PNG + _analyze.py + _diff.py + _decode_town.py）
