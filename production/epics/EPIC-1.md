# EPIC-1 · 能走路的世界（W1-2，15.5h）

> 里程碑门 M1：小镇地图 + 玩家移动/碰撞 + 1 个 NPC + 1 段对话（A8 行 1）
> 本 Epic 同时承载学习路线 C2 第 1-2 周——练习产出物全部直接进项目。

## Story 列表

### E1-S1 环境与项目骨架 · 2.5h
- 需求依据：ADR-4（渲染配置一套定死）；架构 A2（目录结构）；C2 第 1 周。
- 做什么：安装 Godot 4.3；按 A2 建 `autoload/ scenes/ scripts/ data/ assets/ tests/` 目录；写入 ADR-4 全套项目设置（640×360 / canvas_items / keep / Nearest / integer 缩放 / snap_2d_transforms / Compatibility 渲染器）；git 仓库初始化（.gitignore 含 `.godot/`）。
- 验收标准：
  - [ ] 空场景在 1080p 全屏下整数缩放、16px 贴图锐利无模糊
  - [ ] 项目设置截图留档（后续所有 Epic 的渲染基线）
  - [ ] git 提交规范运转（一次 Story 一次或多次提交）

### E1-S2 四 Autoload 空壳 · 1.5h
- 需求依据：架构 A3（单例边界表）；EventBus 信号清单 = `enemy_touched / dialogue_finished / battle_finished / story_phase_changed / save_requested / map_ready`。
- 做什么：建 `game_data.gd / event_bus.gd / scene_router.gd / save_manager.gd` 四个空壳；GameData 只声明字段（队伍/story_phase/flags/chests_opened/cleared_enemy_set/discovered_weakness_set），SaveManager 只声明 schema 常量。
- 验收标准：
  - [ ] 4 个单例注册生效，信号可 emit/connect
  - [ ] 无超边界方法（GameData 不做 IO、EventBus 不存状态——自查对照 A3 表）

### E1-S3 Main.tscn + UILayer + SceneRouter · 2.5h
- 需求依据：架构 A4（常驻根结构、过渡遮罩、payload 合法性校验）。
- 做什么：Main 常驻根 + World/UILayer 两层；SceneRouter 封装场景切换 + 0.2s 淡入淡出 + 载荷校验（不合法拒绝切换并打印原因）；两张白盒图验证互切。
- 验收标准：
  - [ ] 白盒图 A→B→A 切换正常，淡入淡出可见
  - [ ] 传入非法 payload 时拒绝切换且有日志
  - [ ] UILayer 跨场景切换不销毁（放一个 Label 验证存活）

### E1-S4 玩家移动/碰撞/相机 · 2.5h
- 需求依据：架构 A6（CharacterBody2D + move_and_slide、原点在脚底、移速 4-5 tile/s、0.15s 转向缓冲、Camera2D smoothing 开 + snap 关的取舍实测）。
- 做什么：player.tscn 八向移动 + TileSet 物理碰撞 + Camera2D 跟随；花半天把 y-sort 原点规则调对（全项目复用的一次性投入）。
- 验收标准：
  - [ ] 撞墙正常、无穿模；4.5 tile/s 移速手感确认
  - [ ] 无 subpixel 抖动（1080p 下逐帧观察）
  - [ ] 角色原点在脚底，站墙后/树后被正确遮挡

### E1-S5 小镇地图白盒 · 4h
- 需求依据：探索 GDD §3.1 小镇行（64×48 + 2 内嵌室内 12×9）；架构 A6 五层结构（Ground/GroundDeco/YSorted/Above/Triggers）；美术守则（surt tileset、草地取 forest_tiles）。
- 做什么：小镇一张图 + 室内内嵌到同图远角（门=teleport 到远角房间，相机限区）；NPC/建筑摆位按 GDD 密度表。
- 验收标准：
  - [ ] 主街环线 ~90s 可走通，密度抽查（NPC+调查+宝箱点位已预留）
  - [ ] 五层结构齐备，y-sort 视觉正确
  - [ ] 室内区相机限定，门可进可出（teleport 走 E4-S6 的正式时序，此处允许简版）

### E1-S6 NPC + 交互 + 对话框最小版 · 2.5h
- 需求依据：架构 A7（触发器薄壳 event_id + 对话 JSON 条目式）；探索 GDD §3.3（Z/E 均有效、面前 1 格 + 所在格）；对话 GDD §3.1（字段规范）、§4（逐字 30 字/秒）。
- 做什么：npc.tscn（只带 npc_id）；trigger_dialogue 薄壳；对话框最小版（名字栏 + 文本区 + 逐字显示 + 按键补完/翻页）；一段手写对话 JSON 跑通。
- 验收标准：
  - [ ] 按 Z/E 触发对话，逐字显示、按键可跳/翻
  - [ ] 对话期间玩家移动锁定
  - [ ] 对话内容来自 `data/json/dialogues/`，非硬编码

## M1 收口
- A8 行 1 验证标准全绿 + 试玩视频 #1 + git tag `m1`。
- 若学习曲线导致超时：优先保 S1-S4（骨架与移动），S5 可降到"半张图"，S6 可降为"固定键触发写死对话"——但对话框必须出现。
