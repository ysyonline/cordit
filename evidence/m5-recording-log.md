# M5 录制日志留证（2026-09-03）

## 命令
```
MSYS2_ARG_CONV_EXCL="*" "D:\software\Godot\Godot_v4.7.2-stable_win64.exe" \
  --path "D:\code\cordit" \
  --write-movie "D:\code\cordit\evidence\m5-gameplay.avi" \
  --fixed-fps 30 --quit-after 5400 \
  res://evidence/_m5_auto_demo.tscn
```
说明：`tools/record_m5_gameplay.bat` 已按 M4 蓝本镜像写好（安全阀 1920→5400 帧），
但 WorkBuddy 内置 Git Bash 的 `cmd //c` 引号传递有坑（bat 未被执行），
故本次由主理人直调 Godot，参数与 bat 完全一致。用户后续双击 bat 即可复现。

## 结果（摘自 /tmp/m5_godot_movie.log）
- `Done recording movie at path: D://code//cordit//evidence//m5-gameplay.avi`
- 4849 frames @ 30 FPS（片长 00:02:41，即 161.6s），录制耗时 1m22s
- demo 自身终态：`[M5Demo] 终态验证 PASS：I5 全序列（battle→续行→phase3→save_point）落地`
- 无 SCRIPT ERROR / 无 ERROR 行
- 产物：evidence/m5-gameplay.avi，320,617,088 字节（~306 MB，未压缩 AVI，M1-M4 同规格）
- LFS：`git check-attr` 确认 `filter: lfs` 生效（.gitattributes `*.avi` 规则）
- git 状态：?? evidence/m5-gameplay.avi（待收口 commit 一并入库）

## 备注
- `--quit-after 5400`（180s）为安全阀，实际由脚本内 `get_tree().quit()` 收尾。
- 片长 161.6s > 估算的 90~110s：因 Movie Maker 固定帧步进下对话逐字/补按节拍
  比实时 headless 慢，属正常现象，画面内容完整（8 幕全部走完到 PASS）。
