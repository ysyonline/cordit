extends SceneTree
## _r3_seed_probe —— 敌 AI 确定性种子探针（M7 R-3 校准工具，录后可删）
##
## 用途：battle_scene 生产通道 L138 用 randf() 抽敌 AI 行为；驱动器在敌方
## 行动拍前 seed(n) 固化序列 → 首个 randf() 即 roll_action。本探针枚举
## n → 首个 roll 值，供 _m7_r3_autodrive.gd 的 BEAT_SEED 表按区间选种子：
##   guardian {attack:60, poison_strike:25, sweep:15}：
##     roll < 0.60 → attack；0.60 ≤ roll < 0.85 → poison_strike；roll ≥ 0.85 → sweep
##   core {attack:50, charge:20, heavy_strike:30}：
##     roll ≤ 0.50 → attack；0.50 < roll ≤ 0.70 → charge；roll > 0.70 → heavy_strike
## 跑法：godot --headless -s res://tools/dev/_r3_seed_probe.gd（零文件副作用）

func _initialize() -> void:
	print("=== R3 SEED PROBE（seed(n) 后首个 randf）===")
	for n: int in range(1, 401):
		seed(n)
		var r: float = randf()
		print("SEED %d -> %.4f" % [n, r])
	print("=== PROBE END ===")
	quit(0)
