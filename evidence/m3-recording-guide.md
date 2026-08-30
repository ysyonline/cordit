# M3 门3 试玩视频 · 一键录制操作单

> 编制：程基岩（eng-m3demo）｜服务对象：主理人游承峰｜2026-08-30
> 结论先行：**双击 `tools\record_m3_gameplay.bat`，等约 30 秒，收工。**
> （沙箱内已实测录制成功并交付了一版 `evidence/m3-gameplay.avi`；若你对画面不满意或想重录，按本单操作即可，步骤完全一致。）

---

## 1. 你要做的唯一动作

**在资源管理器中双击：`tools\record_m3_gameplay.bat`**

就这一下。脚本会自动：

1. 定位 Godot 4.7.2（WinGet 安装路径，已写死在脚本里，路径变了才需要改脚本第一段）；
2. 删除旧的 `evidence\m3-gameplay.avi`（如有）；
3. 以 Godot Movie Maker 模式启动自动演示场景，**约 20~40 秒**录完并自动退出游戏；
4. 在控制台报告成功或失败（窗口不会自动关，看完了按任意键关闭）。

## 2. 预期效果（17.5 秒 @30fps，640×360）

| 时间 | 画面 |
|---|---|
| 0:00–0:03 | 白盒图 A：玩家向右走，底部字幕"探索近郊道路……" |
| 0:03 | 黑屏转场，切入战斗（雷壳甲虫×2，弱火教学场） |
| 0:04 | 凯尔普攻（白字伤害 + 受击闪白） |
| 0:05 | 莫娜防御（指令菜单可见五项） |
| 0:06 | **莉娜火球 → 橙字大伤害 + "弱点！"弹字 ×2 + 击退**（本片核心爽点） |
| 0:07 | 敌方甲虫反击凯尔 |
| 0:08–0:11 | 凯尔防御 → 莫娜治疗（绿字）→ 莉娜火球收尾 |
| 0:12–0:14 | 胜利结算画面（"胜利！"+ 三人 HP/MP） |
| 0:14–0:15 | 出战黑屏 → 回到地图，玩家回置 |
| 0:15–0:17 | 字幕"战斗胜利！已回到地图 —— 录制完成"，自动退出 |

## 3. 成功标志（满足任一即成功）

- 控制台出现 **`Done recording movie at path: D:\code\cordit\evidence\m3-gameplay.avi`**，以及
  `526 frames at 30 FPS (movie length: 00:00:17:16)` 一行；
- `evidence\m3-gameplay.avi` 存在且大小约 **12 MB**。

## 4. 产物与交回

| 项 | 路径 |
|---|---|
| 视频 | `evidence/m3-gameplay.avi` |
| 录制日志（控制台全程输出） | `evidence/m3-recording.log` |

**交回主理人验收时**：无需单独传文件——上述两个文件都在仓库 `evidence/` 内，告诉主理人"门3 视频已录，见 evidence/m3-gameplay.avi"即可（验收时会随 M3 收口统一 commit；`.gitignore` 已白名单 `evidence/*.log`，avi 也请主理人批准入库——M2 的 `m2-gameplay.avi` 就是这么入库的）。

## 5. 失败排查（按可能性排序）

1. **窗口一闪而过、没有 avi**：多半是 Godot 路径变了。脚本开头 `GODOT_EXE=` 一行改成你本机的 `Godot_v4.7.2-stable_win64_console.exe` 全路径即可。
2. **控制台报 Invalid project path**：确认你是直接双击 bat（工作目录不对时会找不到项目，正常双击不会发生）。
3. **画面黑屏但录制"成功"**：本机显卡不支持 OpenGL 3.3 兼容模式时才会出现（极罕见）。走第 6 节备用路线。
4. 其他报错：把控制台内容截图发主理人。

## 6. 备用路线：Win+G 手动屏录（不依赖 Movie Maker）

1. 正常启动游戏（可用编辑器打开项目直接 F5，或命令行运行
   `Godot_console.exe --path D:\code\cordit res://evidence/_m3_auto_demo.tscn`——会自动演完整场）；
2. `Win + G` 打开 Xbox Game Bar → 录制按钮（或 `Win + Alt + R` 直接开录）；
3. 录满一遍自动演示（约 17 秒），停止；
4. 把录屏文件改名为 `m3-gameplay.mp4` 放入 `evidence/`，并告知主理人"走的是备用路线、格式是 mp4"。

## 7. 给后续接手者的技术备忘

- 演示场景是**临时的、录后可删**：`evidence/_m3_auto_demo.tscn/.gd`（A4 常驻根替身 + 驱动器）与 `evidence/_m3_battle_host.tscn/.gd`（战斗舞台）。与 M2 收口纪律一致，删除不影响任何业务代码。
- 演示**全程禁随机**：所有 `submit_command` 显式传 `variance=1.0`，敌人 AI 显式传 `roll_action=0.0`，不使用逃跑——每次录制画面逐帧一致。
- 已知发现（已如实上报主理人，演示按现状行为编排）：`battle_command.gd` 的 `_do_skill` 对单体技能会命中所有存活敌人（火球实际表现为 AOE），且技能结算忽略玩家选中的 `target_slot`。正式修复属业务代码改动，须主理人批准后另行立项。
- 自验证据：GUT 全量 **187/187 PASS**（`evidence/m3-demo-gut-full.log`，退出码 0，零回归）。
