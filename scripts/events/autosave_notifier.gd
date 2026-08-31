extends Node
## autosave_notifier.gd —— E4-S6 进图自动存档通知器（§3.4"过传送点存"时序兑现点）
##
## 【为什么需要这个类】GDD §3.4 精确时序：teleport → Router 载图 → 落位 →
##   地图广播 map_ready → SaveManager.save()。五图 _ready 都要"广播 map_ready +
##   存档"，逻辑收口在一处（地图件零复制粘贴，同 map_events/teleport_assembler
##   收口理由）；地图侧一行调用 announce_ready(self, map_name, player)。
##
## 【写盘时点与门控】本类在 map_ready 广播【后】查存档意图：
##   - 有意图（跨图传送受理 / 战后胜利已登记）→ save() 落盘；
##   - 无意图（游戏启动初始装载 / 同图室内传送）→ 不写盘——防止启动即用
##     默认出生位覆盖玩家既有存档（GDD §3.4"过传送点存，不进图即存"）。
## 【存档条件】战后回图路径由 BattleResultHandler 置意图（GDD I3 ② 胜利即存
##   防复活 GDD §3.2；DEFEAT 走 S7 读档不经此路）。
## 【同图室内传送不存档】trigger_teleport 侧不置意图，时序天然隔离。

const SaveIconScene := preload("res://scripts/ui/save_icon.gd")


## 地图 _ready 尾部调用：广播 map_ready + 门控存档 + 图标闪现。
## p_map_root：地图场景根（取玩家当前位置做存档坐标）；
## p_map_name：地图名（map_ready 参数 + 存档 map 字段）。
## 返回 true = 已存档；false = 无意图跳过或写盘失败（地图装载不受影响）。
static func announce_ready(p_map_root: Node, p_map_name: String) -> bool:
	EventBus.map_ready.emit(p_map_name)
	# 玩家实际位置（已落位，"站在新图入口"）；无玩家退化为原点并照常走门控
	var pos := Vector2.ZERO
	var player: Node2D = p_map_root.get_node_or_null("YSorted/Player") as Node2D
	if player != null:
		pos = player.global_position
	else:
		push_warning("[AutosaveNotifier] %s 无玩家节点，存档坐标退化为原点" % p_map_name)
	# 门控：只有登记过存档意图（跨图传送/战后胜利）才落盘
	if not SaveManager.consume_save_request():
		print("[AutosaveNotifier] %s 无存档意图（启动装载/同图传送），跳过写盘" % p_map_name)
		return false
	var ok: bool = SaveManager.save(p_map_name, pos)
	if not ok:
		push_warning("[AutosaveNotifier] %s 自动存档写入失败（旧档保留）" % p_map_name)
	_spawn_save_icon(p_map_root, ok)
	return ok


## 存档图标：右下角闪现 0.5s（探索 GDD §4；人工验收项，headless 下自动跳过）。
## 挂地图根（随图销毁，无残留）；无 Main/UILayer 依赖，测试树同样安全。
static func _spawn_save_icon(p_map_root: Node, p_ok: bool) -> void:
	if p_map_root.get_tree() == null:
		return   # 未入树（纯数据构造期），跳过
	var icon := Control.new()
	icon.set_script(SaveIconScene)
	icon.name = "SaveIconFlash"
	p_map_root.add_child(icon)
	icon.flash(p_ok)
