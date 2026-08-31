# Sprint 4 收尾：E4-S6 传送网络 + 自动存档 & E4-S7 失败读档 — 会话总结

## 概要
接手程基岩代理（429 限流停摆、零代码产出）的任务，在本会话完成 E4-S6（传送网络 + 进图自动存档）与 E4-S7（失败读档）全部实现与测试。**测试基线 266 → 286/286 全绿**，verify 三件套（town 108 + ruins 156 + road 65）全 PASS。按用户拍板制**未 commit**，等 M4 收口仪式。

## 交付内容
1. **传送网络**：`teleport_catalog.gd`（12 处数据正本：town 室内 4 + 跨图 8）+ `teleports.json` 同构镜像 + `trigger_teleport.gd` 薄壳 + `teleport_assembler.gd` 装配器（town 旧 4 门退役并修复 E2-S2 门层位静默失效回归）。
2. **门控自动存档**：`SaveManager.save_requested_pending` 意图位——跨图传送/战后胜利才落盘，启动装载与同图室内传送不落盘（防止启动即覆盖玩家既有存档；GDD §3.4"过传送点存，不进图即存"）；胜利即存兑现 §3.2 防复活。
3. **R1/R2**：town 南门栅栏拆除（gen 正本路径）；初始场景切 `town.tscn`；三个冒烟 wrapper 与 e1s6 断言适配。
4. **E4-S7 失败读档**：DEFEAT → `load_save()` → 回进图存档点 + 免疫；GameData 随 `_restore` 整体回滚；读档失败兜底回暂存图 + 告警。
5. **测试**：`test_e4s6.gd` 19 条新增；`test_e2s4.gd` DEFEAT 用例重写 2 条；意图位泄漏防护补进 e2s4/e4s5。

## 关键修正（目录初稿缺陷）
- 同图 4 处落位半格口径 → 整数格（对齐旧 @export 正本）；Inn_Exit/HouseA_Exit 触发区 tile 偏 1 行（按旧 tscn 像素反推）；f1/f2/f3 to_spawn 对齐 verify_ruins 锚定值。修正后 12/12 处落位防弹回零重合。

## 待办（M4 收口仪式，用户侧）
本机试玩 → 录视频#4 → 冒烟 headless 复跑确认 → commit 拍板 + tag m4。

## 主要产物
- 证据档：`evidence/e4s6-teleport-autosave.md`、`evidence/e4s6-gut-full.log`
- 代码：`scripts/events/`（4 新文件）、`autoload/save_manager.gd`、`scripts/battle/battle_result_handler.gd`、`scripts/main/main_controller.gd`、五图脚本、`tests/gut/test_e4s6.gd`
