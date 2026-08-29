# 冒烟测试清单 · 首批（手工可执行版）

> 编制：程基岩（engineering-lead）｜TASK-10｜共 12 条，覆盖 E1-S2/E1-S3 全部架构验收点
> 用法：逐条手工执行，PASS 后截图/复制控制台日志存入 `tests/smoke/evidence/`（文件名=用例ID小写，如 `smk-01.png`）。GUT 落地（EPIC-2 起）后逐条搬迁自动化，本清单保留为人工后备。
> 看结果的地方：编辑器底部**输出面板**（print）；场景树核对用**调试 → 远程场景树**（运行中才可见）。

## 0. 通用前置

- 项目可运行（F5），无报错。
- 新建一个临时调试节点（`Node` + 挂临时脚本，下称"冒烟脚本"）加入 Main 场景，用完即删；脚本不提交（或存 `tests/smoke/` 备用）。
- 所有 print 建议加 `[SMK-xx]` 前缀，截图才有归属。

**冒烟脚本骨架**（SMK-03/04 共用，connect 与 emit 各一段，按需注释）：

```gdscript
extends Node

func _ready() -> void:
    # --- connect 段（SMK-03）---
    EventBus.enemy_touched.connect(func(p): print("[SMK-03] enemy_touched 收到: ", p))
    EventBus.dialogue_finished.connect(func(id): print("[SMK-03] dialogue_finished 收到: ", id))
    EventBus.battle_finished.connect(func(r): print("[SMK-03] battle_finished 收到: ", r))
    EventBus.story_phase_changed.connect(func(n): print("[SMK-03] story_phase_changed 收到: ", n))
    EventBus.save_requested.connect(func(): print("[SMK-03] save_requested 收到（无参）"))
    EventBus.map_ready.connect(func(m): print("[SMK-03] map_ready 收到: ", m))
    # --- emit 段（SMK-04）---
    EventBus.enemy_touched.emit({
        "enemy_group_id": "slime_01", "return_map": "res://scenes/maps/road.tscn",
        "return_position": Vector2(64, 32), "defeat_enemy_uid": "enemy_road_01"})
    EventBus.dialogue_finished.emit("evt_test_01")
    EventBus.battle_finished.emit({"outcome": "VICTORY"})
    EventBus.story_phase_changed.emit(1)
    EventBus.save_requested.emit()
    EventBus.map_ready.emit("town")
```

## 1. 用例（E1-S2 完成后执行：SMK-01 ~ 07）

### SMK-01 四 Autoload 注册生效
- **被测对象**：GameData / EventBus / SceneRouter / SaveManager（autoload/*.gd）
- **前置**：E1-S2 完成，项目设置 → Autoload 已登记 4 项
- **步骤**：① F5 运行；② 菜单"调试 → 远程场景树"展开 root；③ 核对四个单例节点存在
- **预期**：root 子节点含 GameData、EventBus、SceneRouter、SaveManager 四个；控制台无脚本错误；数量恰为 4（多一个即超建，对照 A3）

### SMK-02 EventBus 六信号声明齐全
- **被测对象**：event_bus.gd 的 signal 声明
- **前置**：SMK-01 PASS
- **步骤**：① 远程场景树选中 EventBus 节点；② 检查器"Signals"区核对清单
- **预期**：恰好六个：`enemy_touched(payload)`、`dialogue_finished(event_id)`、`battle_finished(result)`、`story_phase_changed(n)`、`save_requested`、`map_ready(map)`——无多余、无缺漏、拼写一致

### SMK-03 EventBus 六信号可 connect
- **被测对象**：信号连接机制
- **前置**：冒烟脚本已挂入 Main，只启用 connect 段
- **步骤**：① F5 运行；② 看输出面板六行 `[SMK-03]`（emit 段此时注释掉，若运行即无输出，仅验证 connect 不报错）；③ 解开 emit 段再跑一次
- **预期**：两次运行均无 "cannot connect / unknown signal" 类错误；第二次运行输出六行回调打印，顺序与 emit 一致

### SMK-04 EventBus 信号 emit 参数原样送达
- **被测对象**：信号带参传递
- **前置**：SMK-03 PASS；冒烟脚本 connect + emit 两段全启用
- **步骤**：① 运行；② 逐行核对打印内容与 emit 入参
- **预期**：enemy_touched 的 4 字段字典逐字段一致（含 Vector2）；battle_finished 收到 `{"outcome":"VICTORY"}`；story_phase_changed 收到 `1`（int 非 string）；save_requested 正常触发无参回调；六条全部命中，无一静默丢失

### SMK-05 EventBus 无状态越界（A3 边界）
- **被测对象**：event_bus.gd 源码
- **前置**：无（静态检查）
- **步骤**：打开 autoload/event_bus.gd 通读；或用编辑器搜索 `var ` 与 `func `
- **预期**：除六个 `signal` 声明外，无成员变量、无函数、无 `_ready`——EventBus 只做声明（A3："不存状态、不写逻辑"）。发现任何 var/func 即 FAIL 并当场删除

### SMK-06 GameData 字段声明齐全
- **被测对象**：game_data.gd
- **前置**：E1-S2 完成
- **步骤**：① 远程场景树选中 GameData；② 检查器核对导出字段；③ 源码核对类型标注
- **预期**：至少含队伍（三人 HP/MP/等级/技能/道具/装备的结构声明）、`story_phase`、`flags`、`chests_opened`、`cleared_enemy_set`、`discovered_weakness_set`（对照 E1-S2 与 A3）；字段有类型标注（ADR-1）

### SMK-07 GameData 无 IO、无信号（A3 边界）
- **被测对象**：game_data.gd 行为
- **前置**：SMK-06 PASS
- **步骤**：① 源码搜索 `FileAccess`、`user://`、`signal`、`emit`；② F5 运行后打开 `用户数据目录`（编辑器：项目 → 打开用户数据文件夹）核对文件清单
- **预期**：源码零命中；运行前后 user:// 目录无新增文件（存档文件属于 EPIC-4 的 SaveManager 职责）；GameData 不声明、不发射任何信号

## 2. 用例（E1-S3 完成后执行：SMK-08 ~ 12）

> SceneRouter 的校验/切换入口函数名以 E1-S3 实现为准；下列步骤按"调用入口 + 看输出面板日志"执行，意图不随命名改变。

### SMK-08 SceneRouter 合法 payload 通过校验
- **被测对象**：payload 校验逻辑（A4：切场景前先检查）
- **前置**：E1-S3 完成，白盒图 A/B 已建
- **步骤**：① 冒烟脚本调用切换入口，传入完整合法 BattlePayload（字段照 A5：enemy_group_id/return_map/return_position/defeat_enemy_uid）；② 观察场景切换
- **预期**：校验通过，无拒绝日志；World 层装载目标场景；淡入淡出可见

### SMK-09 非法 payload 拒绝并打日志
- **被测对象**：拒绝路径
- **前置**：SMK-08 PASS
- **步骤**：依次调用三次，每次换一种非法值：① 空 `{}`；② 缺 `return_map` 字段；③ `return_position` 传字符串（类型错）
- **预期**：三次均拒绝切换，每次输出面板打印**含原因**的拒绝日志（能区分"缺字段/类型错"）；游戏不崩溃、不停帧

### SMK-10 拒绝时当前场景不被破坏
- **被测对象**：失败路径的副作用
- **前置**：SMK-09 PASS
- **步骤**：① 在白盒图 A 上执行 SMK-09 的非法调用；② 远程场景树核对 World 层
- **预期**：World 层仍为场景 A，未被替换为空/半装载状态；随后一次合法调用可正常切到 B（Router 未进入坏状态）

### SMK-11 UILayer 跨场景存活
- **被测对象**：Main 常驻结构（A4）
- **前置**：UILayer 内放一个测试 Label（E1-S3 验收项自带）
- **步骤**：① 记录 Label 的实例（冒烟脚本持有引用或用 `is_instance_valid`）；② A→B 合法切换；③ B→A 再切回
- **预期**：两轮切换后 Label 仍显示且为同一实例（valid 未变 null）；对话框/遮罩类 UI 的常驻前提成立

### SMK-12 SaveManager 空壳无副作用
- **被测对象**：save_manager.gd（E1-S2 只声明 schema 常量）
- **前置**：E1-S2/S3 完成
- **步骤**：① 源码核对：仅 schema 常量声明（对照 ADR-3 字段表），无读写调用；② F5 运行后核对 user:// 目录
- **预期**：运行不产生 save.json 或任何文件（写盘属 EPIC-4 E4-S1 职责）；常量字段与 ADR-3 schema 一一对应（version/map/position/party/story_phase/flags/chests_opened/discovered_weakness_set/cleared_enemy_set）

## 3. 执行时点（对齐 tests/README 第 5 节）

| 时点 | 范围 | 硬性要求 |
|---|---|---|
| E1-S2 勾验收前 | SMK-01~07 | 全 PASS 才算 Story 完成，证据入 evidence/ |
| E1-S3 勾验收前 | SMK-01~12 全量 | 同上 |
| M1 里程碑门收口（录视频 #1 前） | SMK-01~12 全量 | 15 分钟内可跑完，PASS 才打 tag `m1` |
| 之后任何改动 autoload/ 或 SceneRouter 的提交前 | 相关条目 | 原有 PASS 不得变 FAIL |

## 4. 执行记录

| 日期 | 执行人 | 范围 | 结果 | 备注 |
|---|---|---|---|---|
| 2026-08-29 | 游承峰（team-lead 代核） | SMK-05/06/07 静态部分 + SMK-12 源码预核 | PASS | 静态搜索/通读核对；证据见 evidence/smk-05~07.txt；SMK-07 的 user:// 动态复核与 SMK-12 挂 E1-S3 后全量重跑 |
| 2026-08-29 | 游承峰（headless 自动化） | SMK-01~04 动态 + SMK-07/12 动态（user:// 核对） | PASS | Godot 4.7.2 headless 跑 tests/smoke/headless_smk.tscn，4/4 PASS 退出码 0；user:// 仅引擎 logs 零游戏文件；证据见 evidence/smk-01-04-headless.log；SMK-08~12 仍按计划 E1-S3 后全量重跑 |
| | | SMK-01~07 | | E1-S2 首跑（上述两行合并即首跑全量，全绿） |
| | | SMK-01~12 | | E1-S3 / M1 收口 |

（每行对应一次全量执行；FAIL 时在备注写用例号与现象，修复合入后重跑整段范围。）
