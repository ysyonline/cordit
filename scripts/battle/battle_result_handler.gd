extends Node
## BattleResultHandler —— 战后写回处理器（E2-S4，架构 A5 数据闭环下半段）
##
## 【定位】EPIC-2 M2 门"数据能从地图流进战斗再流回地图"的最后一跳：
##   战斗场景发 battle_finished(BattleResult) → 本处理器完成写回与回图。
##
## 【为什么由 SceneRouter._ready 装配、且必须常驻】：
##   battle_finished 发出时的场景时序：旧地图已随 enemy_touched 切换销毁、
##   新地图尚未装载——挂地图下必然收不到信号。本处理器必须跨场景常驻；
##   Router 是当前唯一既有 _ready、跨场景常驻且已承担 enemy_touched 接线
##   （E2-S3）的装配点，handler 属同一条 A5 数据流，装配内聚于此。
##   架构红线"4 Autoload 冻结"不触碰：本节点是普通 Node，非 Autoload。
##
## 【职责】按 outcome 分支（探索 GDD §3.2 / EPIC-2 E2-S4）：
##   共通：party_state 快照覆写 GameData.party（E2-S3 备好的 6 字段结构，
##         按 id 对账，id 不在队伍则跳过并告警）；
##   VICTORY：defeat_enemy_uid 写入 GameData.cleared_enemy_set（查重）——
##         敌人不复活的机制是"数据驱动"：重装地图时 visible_enemy._ready
##         自查该集合并自删，无需任何人持有地图引用去删节点；
##         并登记存档意图（GDD §3.2 胜利即存防复活；§3.4 时序：意图在此
##         置位，回图 map_ready 时 AutosaveNotifier 门控消费落盘）；
##   DEFEAT：自动读档（战斗 GDD §3.5"残响中断"，E4-S7 兑现）——
##         load_save() 成功 → last_loaded 取 map/position 回图回置；
##         GameData 状态（party/flags/集合/背包）随 _restore 一并回滚到
##         存档时点（无额外惩罚，§3.5"读档后角色状态为存档时状态"）；
##         读档失败（无档/损坏）→ 兜底回暂存 return_map + push_warning
##         （防御性：正常流程进图必有自动存档，失败兜底保流程不断）。
##   共通：经 SceneRouter 回图（不带 payload，p_has_payload=false——地图
##         装载无 BattlePayload 协议），并在 map_ready 后把玩家回置到
##         return_position + 启动 0.5s encounter_immunity（探索 GDD §3.2：
##         回置点恰在敌人接触范围内时不秒进战斗，边缘情况 2）。
##
## 【边界】（A5 解耦）：
##   - 地图与战斗零互相引用：本处理器只消费纯数据（result + Router 暂存
##     payload），一切协调经 EventBus / SceneRouter 公开入口；
##   - 不感知具体地图内容：地图侧修复只在 map_ready 之后按结构约定
##     （Main/World 当前子节点、YSorted/Player）做一次性的回置与免疫；
##   - 游戏状态只写 GameData（A3）；本节点自身仅持有"待回置任务"簿记。

## 战后免疫时长（秒）——探索 GDD §3.2 钉定 0.5s
const IMMUNITY_DURATION: float = 0.5

## A4 常驻根下的玩家路径（与 scenes/main.tscn + 地图结构约定一一对应）
const WORLD_NODE_PATH: String = "Main/World"
const PLAYER_NODE_PATH: String = "YSorted/Player"

## 待回置任务簿记（{"position": Vector2}；回置完成后清空）。
## 公开供测试预置/清零（GUT 跨用例隔离，与 SceneRouter 簿记同款处理）。
var _pending_return: Dictionary = {}


func _ready() -> void:
	EventBus.battle_finished.connect(_on_battle_finished)
	EventBus.map_ready.connect(_on_map_ready)


# ------------------------------------------------------------------
# battle_finished 消费：覆写 → 标记 → 回图
# ------------------------------------------------------------------

func _on_battle_finished(result: Dictionary) -> void:
	# 1) 队伍态覆写（VICTORY 写战后值；DEFEAT 下方读档会整体回滚，此处
	#    幂等覆写无害——读档失败兜底路径也保持队伍态自洽）
	_apply_party_state(result.get("party_state", []) as Array)
	# 1.5) 掉落写回（E6-S2 T2.4：D-附 8.10 掉落按只结算 → I2 队伍共享背包，
	#    与宝箱 give_item 同入口同口径）。DEFEAT 不写——下方读档整体回滚，
	#    写了也会被覆盖，白写；ESCAPE 无 drops 键（空数组，循环零次，天然幂等）。
	_apply_drops(result.get("drops", []) as Array)
	# 2) 胜利登记击破（数据驱动防复活：敌人 _ready 自查自删）
	var outcome: String = String(result.get("outcome", ""))
	if outcome == "VICTORY":
		var uid: String = _resolve_defeat_uid(result)
		if uid.is_empty():
			push_warning("[BattleResultHandler] VICTORY 但击破凭据为空（result 与暂存载荷均无 defeat_enemy_uid），敌人将保留")
		elif not GameData.cleared_enemy_set.has(uid):
			GameData.cleared_enemy_set.append(uid)
		# 胜利即存档意图（探索 GDD §3.2 防复活：读档不得让已击破敌人回来；
		# §3.4 时序：意图在此登记，目标图 map_ready 时由 AutosaveNotifier
		# 门控消费落盘——存档坐标 = 回置后的战前位置，非默认出生位）
		SaveManager.save_requested_pending = true
	# 3) 回图目标解析：
	#    DEFEAT → 自动读档（战斗 GDD §3.5）：回滚 GameData 到存档时点，
	#    回图目标取存档的 map/position（"进入地图时的存档点"）；
	#    VICTORY → result 自带字段优先（E2-S3 起战斗场景随结果转交 payload
	#    三字段），Router 暂存兜底（战斗期间暂存不会被覆盖）。
	var return_map: String
	var return_pos: Vector2
	if outcome == "DEFEAT":
		if SaveManager.load_save():
			return_map = _map_name_to_path(String(SaveManager.last_loaded["map"]))
			return_pos = _position_from_loaded()
			print("[BattleResultHandler] DEFEAT 读档成功 -> 回到存档点 %s @ %s" % [
					String(SaveManager.last_loaded["map"]), return_pos])
		else:
			# 防御性兜底：无档/损坏。正常流程进图必有自动存档，走到这里说明
			# 存档链路已出问题——保流程不断（暂存字段回图），告警交诊断。
			var staged_fallback: Dictionary = SceneRouter.get_staged_payload()
			return_map = String(result.get("return_map",
					staged_fallback.get("return_map", "")))
			return_pos = result.get("return_position",
					staged_fallback.get("return_position", Vector2.ZERO))
			push_warning("[BattleResultHandler] DEFEAT 读档失败（无档/损坏），兜底回暂存图 %s——存档链路需排查" % return_map)
	else:
		var staged: Dictionary = SceneRouter.get_staged_payload()
		return_map = String(result.get("return_map", staged.get("return_map", "")))
		return_pos = result.get("return_position",
				staged.get("return_position", Vector2.ZERO))
	if return_map.is_empty():
		push_warning("[BattleResultHandler] 无回图目标（result/staged 均缺 return_map），停留当前场景")
		return
	_pending_return = {"position": return_pos}
	# 4) 回图：地图装载不带 BattlePayload（显式 false 跳过协议校验，A5 只
	#    约束地图↔战斗方向）；0.2s 淡入淡出复用 Router 既有转场
	SceneRouter.change_scene(return_map, {}, false)
	print("[BattleResultHandler] %s 结算完成 -> 回图 %s（回置 %s）" % [
			outcome, return_map, return_pos])


## result 里的 defeat_enemy_uid 优先，暂存 payload 兜底
func _resolve_defeat_uid(result: Dictionary) -> String:
	var uid: String = String(result.get("defeat_enemy_uid", ""))
	if uid.is_empty():
		uid = String(SceneRouter.get_staged_payload().get("defeat_enemy_uid", ""))
	return uid


## 存档 map 字段（短名 "town"/"ruins_f1"…）→ 场景路径（TeleportCatalog 正本）。
## 未知短名返回空串（change_scene 会拒绝并告警，不静默）。
func _map_name_to_path(map_name: String) -> String:
	const Catalog := preload("res://scripts/events/teleport_catalog.gd")
	return Catalog.MAP_SCENE_PATHS.get(map_name, "")


## last_loaded["position"]（JSON 数组 [x, y]）→ Vector2（float 逐键转换）
func _position_from_loaded() -> Vector2:
	var arr: Array = SaveManager.last_loaded["position"]
	return Vector2(float(arr[0]), float(arr[1]))


## party_state 快照写回 GameData.party（按 id 对账；E2-S3 备好的 6 字段结构）
func _apply_party_state(party_state: Array) -> void:
	for snap: Variant in party_state:
		var rec: Dictionary = snap
		var matched := false
		for c: Resource in GameData.party:
			if c.id == rec.get("id", ""):
				c.level = int(rec.get("level", c.level))
				c.hp = int(rec.get("hp", c.hp))
				c.max_hp = int(rec.get("max_hp", c.max_hp))
				c.mp = int(rec.get("mp", c.mp))
				c.max_mp = int(rec.get("max_mp", c.max_mp))
				matched = true
				break
		if not matched:
			push_warning("[BattleResultHandler] party_state 含队伍外 id \"%s\"，跳过" % rec.get("id", "<空>"))


## 掉落写回（E6-S2 T2.4）：result.drops（结算器产物，同 id 已累计）逐条
## 并入 GameData.inventory——I2 口径：与宝箱 give_item 同入口
## （GameData.inventory[id] += count），无独立战斗背包层。
func _apply_drops(drops: Array) -> void:
	for dp: Variant in drops:
		var d: Dictionary = dp
		var iid: String = String(d.get("item_id", ""))
		if iid.is_empty():
			continue
		var count: int = int(d.get("count", 0))
		if count <= 0:
			continue
		GameData.inventory[iid] = int(GameData.inventory.get(iid, 0)) + count
		print("[BattleResultHandler] 掉落入包 %s x%d（背包 %s）" % [iid, count, GameData.inventory])


# ------------------------------------------------------------------
# map_ready 消费：玩家回置 + 免疫启动
# ------------------------------------------------------------------

func _on_map_ready(_map_id: String) -> void:
	if _pending_return.is_empty():
		return
	# 延迟一帧：地图 _ready 发 map_ready 时玩家挂载（TempPlayerMount 兄弟
	# 节点）理论上已完成，deferred 保帧序确定性，不赌实现细节
	_do_return.call_deferred()


## 执行回置：找当前地图的玩家 → 回置 return_position → 启动免疫 → 清簿记
func _do_return() -> void:
	if _pending_return.is_empty():
		return
	_pos_return_immediate()


## 回置实现（同步版）：供 deferred 调用与测试直驱共用。
## get_tree() 为 null（节点未入树，如 GUT 直驱实例）时直接失败告警——
## 回置依赖场景树定位玩家，无树环境没有可回置的对象。
func _pos_return_immediate() -> void:
	if _pending_return.is_empty():
		return
	var pos: Vector2 = _pending_return["position"]
	_pending_return = {}
	var tree: SceneTree = get_tree()
	if tree == null:
		push_warning("[BattleResultHandler] 回置失败：处理器不在场景树内（无 Main 环境），簿记已清空")
		return
	var world: Node = tree.root.get_node_or_null(WORLD_NODE_PATH)
	if world == null or world.get_child_count() == 0:
		push_warning("[BattleResultHandler] 回置失败：Main/World 无当前场景（GUT/无 Main 环境）")
		return
	var player: Node2D = world.get_child(world.get_child_count() - 1).get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if player == null:
		push_warning("[BattleResultHandler] 回置失败：当前地图无 " + PLAYER_NODE_PATH)
		return
	player.global_position = pos
	if player.has_method("start_encounter_immunity"):
		player.start_encounter_immunity(IMMUNITY_DURATION)
	print("[BattleResultHandler] 玩家回置 -> %s，免疫 %.1fs 启动" % [pos, IMMUNITY_DURATION])
