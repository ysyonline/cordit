extends Node
## E1-S2 冒烟测试脚本（SMK-03/04 共用）——临时挂入 Main 场景用，用完可移除
##
## 用法（对照 tests/smoke/SMOKE-CHECKLIST.md 第 0/1 节）：
##   1. 在 Main 场景新建一个 Node 子节点，挂载本脚本；
##   2. F5 运行，看输出面板逐行核对（SMK-03 connect 不报错 + SMK-04 参数原样送达）；
##   3. 验收完成删除该节点；本脚本仅存 tests/smoke/ 备用，不参与正式构建。

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
