# M4 验收证据档（2026-08-31）

> 垂直切片第四里程碑：四图连通可玩（town/road/f1/f2/f3）。
> 执行模式：用户四项全权委托（试玩代测 / 视频#4 / 冒烟复跑 / commit+tag）。

## 四项收口结果

### ① F5 试玩（自动化代测）✅
- 交付：`evidence/_m4_auto_demo.gd` + `.tscn`（A4 常驻根替身，7 幕确定性演示）
- 证据：`evidence/m4-demo-headless-playtest.log`（第五遍全绿）
- 覆盖链路：town 出生（不落盘）→ 客栈同图传送（不落盘）→ 出口回主图（不落盘）
  → 南门跨图 road（落盘+图标）→ B4 遭遇战 → 确定性 DEFEAT → 读档回存档点
  (384,64) + GameData 回滚验证 PASS
- 残留人眼项：手感/镜头观感待用户本机抽查（自动化无法覆盖）

### ② 视频 #4 ✅
- 交付：`evidence/m4-gameplay.avi`（89.3MB，64s @30fps，Movie Maker 真实引擎画面）
- 工具：`tools/record_m4_gameplay.bat`（GODOT_EXE=D:\software\Godot，1920 帧）
- 确定性保证：战斗脚本 `_m4_battle_host.gd` 显式 roll=0.9 恒 sweep、variance=1.0，
  DEFEAT 剧本 7 回合与推演逐 HP 一致；无 AI 生成画面

### ③ 冒烟 headless 复跑 ✅（修复后全绿）
首跑（严守真，team cordit-sprint4-m4-9ede，7m20s）：3 绿 2 FAIL，均非产品缺陷：
- e1s5-A1「四门缺失」＝断言过时：E4-S6 旧四门被 assembler 同位重建为
  `Evt_tp_*` 薄壳。修复：`headless_e1s5.gd` A1 断言升级新实体名（期望值不变）。
- smk-e1s3 SMK-12「user:// 残留 save_m4_demo.json」＝demo 存档槽未自清理。
  修复：`_m4_auto_demo.gd` 收尾自清理 + 残留手工清除。
复跑（主理人本机）：五通道全绿，EXIT 全 0：
| 通道 | 结果 | 证据 |
|------|------|------|
| e1s4 走位 | 3/3 PASS | evidence/m4-smoke-e1s4.log |
| e1s5 门传送 | 4/4 PASS（修复后） | evidence/m4-smoke-e1s5.log |
| e1s6 传送网络 | 5/5 PASS（回归锚） | evidence/m4-smoke-e1s6.log |
| smk 核心信号 | 4/4 PASS | evidence/m4-smoke-smk.log |
| smk-e1s3 空壳 | 5/5 PASS（修复后） | evidence/m4-smoke-smk-e1s3.log |

### ④ commit + tag ✅
- commit：`07457c5`（63 files, +3902/-179，含视频入库 89.3MB）
- tag：`m4`
- GUT 基线：266 → 286/286（e4s6 新增 19 条 + e2s4 扩 2 条净增 1）
  证据：evidence/e4s6-gut-baseline.log / e4s6-gut-full.log
- .import 55 个纯行尾噪声未入库（沿 c1c4562 惯例）
- 补齐 S3 起历史欠账 .uid 19 个

## tag 补记说明
MEMORY 曾记载 m1/m2/m3 标签，但仓库 tag 列表实际为空（历史会话只执行了
记忆记录未执行打标）。本次补打 m4；如需补 m1/m2/m3 可按
`git log --oneline | grep "M1\|M2\|M3"` 定位历史 commit 后
`git tag mN <hash>`，是否补齐由用户拍板。

## 遗留项
- 人眼手感抽查（试玩项自动化边界）
- m1/m2/m3 标签是否补打（用户决策）
- tools/README.md 登记 gen/verify 工具链（小债顺延）
- sfx 为 E6 预留钩子
