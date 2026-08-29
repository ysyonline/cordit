# EPIC-2 · 遇敌能打（W3-4，9h）

> 里程碑门 M2：可见敌人 + 切入战斗（占位 UI）+ 攻击/防御 + 胜负回到地图（A8 行 2）
> 本 Epic 的本质是把 A5 的数据闭环走通——战斗是假的，数据流必须是真的。

## Story 列表

### E2-S1 GameData 队伍数据 + 调试面板 · 2h
- 需求依据：架构 A3（GameData 职责）；C2 第 2 周练习 3（按 M 打开的调试面板）。
- 做什么：3 名角色 HP/MP/等级硬编码进 GameData；M 键调试面板显示全部运行时状态（后续所有系统的调试地基，值得做好）。
- 验收标准：
  - [ ] M 键开/关面板，数据实时刷新
  - [ ] 面板为纯 UILayer 节点，不影响游戏世界

### E2-S2 可见敌人节点 + 巡逻/接触 · 2.5h
- 需求依据：探索 GDD §3.2（三态中的"巡逻"态先行；waypoint 节点序列、恒速 2 tile/s、碰撞盒相触发 `enemy_touched`）；架构 A5（BattlePayload 四字段）。
- 做什么：visible_enemy.tscn（enemy_uid / group_id / waypoints）；巡逻往返；接触组装 BattlePayload 发 EventBus。
- 验收标准：
  - [ ] 敌人沿 waypoints 循环移动，恒速 2 tile/s
  - [ ] 接触后 payload 四字段全部正确（return_position 在敌人反向外侧一格）
  - [ ] 敌人间无碰撞、与玩家/地形有碰撞

### E2-S3 占位战斗场景 + Router 载荷校验 · 2.5h
- 需求依据：架构 A4/A5；C2 第 2 周练习 4（纯色背景 + 9 个彩色方块的占位战斗，不做战斗逻辑）。
- 做什么：battle.tscn 占位版；从 payload 读 enemy_group_id 显示方块；"胜利/失败"两个按钮模拟结局。
- 验收标准：
  - [ ] Router 切入战斗时转场黑屏正常，payload 非法则拒绝
  - [ ] 战斗场景从 GameData 读队伍初始态（显示在占位 UI 上）

### E2-S4 BattleResult 写回闭环 · 2h
- 需求依据：架构 A5（outcome / party_state 覆写 GameData）；探索 GDD §3.2（胜利移除敌人 + encounter_immunity 预留 0.5s）。
- 做什么：胜负按钮各自发 BattleResult；地图侧监听 `battle_finished` 后删敌人节点（defeat_enemy_uid）+ 玩家回置；失败流程此阶段允许占位（真读档在 E4-S7）。
- 验收标准：
  - [ ] 胜利：敌人节点移除，玩家回到敌人旁一格
  - [ ] 失败：能回到地图（读档逻辑占位），GameData 数据正确覆写
  - [ ] 战后回图立即再撞同一敌人不会秒进战斗（immunity 生效）

## M2 收口
- A8 行 2 验证标准全绿 + 试玩视频 #2 + git tag `m2`。
- 完成标准一句话：**数据能从地图流进战斗再流回地图**——做到这里，最难的建筑学部分已经走完。
