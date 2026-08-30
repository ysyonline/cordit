extends StaticBody2D
## chest.gd —— 宝箱事件实体（E4-S5，探索 GDD §3.3 宝箱模板）
##
## 【需求依据】探索 GDD §3.3：宝箱开启 = 事件模板
##   `conditions:{not_flag:chest_id}` → `play_sfx + give_item + dialogue + set_flag`；
##   开启状态走存档 schema `chests_opened[]`（ADR-3，不用泛化 flags）。
##   EPIC-4 E4-S5 + 拍板项④：EPIC-5 JSON 事件加载器未就绪 → 本版为
##   【硬编码触发器形态】的模板事件，动作序列按模板内联实现；
##   E5-S2 加载器就绪后回迁为 JSON 驱动（本节点保留 event_id 协议属性，
##   点位数据在 data/json/events/chests.json 结构化落盘，回迁时数据可平移）。
##
## 【模板语义】（对照探索 GDD §3.3 模板，条件即"已开集合中查无此箱"）：
##   not_flag(chest_id)  → chests_opened.has(id) == false 才执行：
##     ① play_sfx（预留调用点：音频系统 E6 建，先留 _play_sfx 钩子与日志）；
##     ② give_item(item_id, count) → 写 GameData.inventory（与战斗掉落
##       同入口，探索 GDD I2：道具为队伍共享背包）；
##     ③ dialogue(获得提示) → DialogueRunner 按 dialogue_id 开对话
##       （提示文案在 data/json/dialogues/dlg_chest_<id>.json，一箱一文件）；
##     ④ set_flag → chests_opened.append(id)（去重）。
##   已开（chests_opened 含 id）→ 再交互只重播获得提示对话，不重复给道具
##   （"已开不重开"= 道具/Flag 只发一次；EPIC-4 验收口径）。
##
## 【交互协议】（沿 NPC InteractBody 先例，npc.tscn 工程注记）：
##   交互判定体 = 本节点自身（StaticBody2D 层 2，被 player 的 InteractRay
##   命中）；interaction_controller 沿父链找协议持有者后按签名分派：
##   有 on_interact() 即实体自治（本模板四步闭环），get_npc_id() 保留为
##   "获得提示对话 id"口（模板③ 由实体内调 runner 开演）。
##
## 【装配规格】根 (0,0) = 脚底触地点（y-sort 基准，规则同 player.gd）；
##   BodyRect 16x14 棕色占位矩形（美术线 R2/R3 到位后换箱体贴图）；
##   InteractShape 16x16 @ (0,-7) 层 2（与 npc.tscn InteractBody 同尺寸）。
##   宝箱格不挂世界墙体（层 1）——玩家可走上箱格邻接交互，不挡路。

## 宝箱唯一标识（存档 chests_opened 的键，全项目唯一；如 "chest_town_01"）
@export var chest_id: String = ""

## 开箱获得道具 id（须可解析到 data/resources/items/<id>.tres，ItemData 表）
@export var item_id: String = "potion_s"

## 获得数量（默认 1；GDD §5 掉落 count 同款语义）
@export var item_count: int = 1

## 获得提示对话 id（解析 data/json/dialogues/<dialogue_id>.json）
@export var dialogue_id: String = ""

## 事件标识（A7 薄壳协议属性：E5 回迁 JSON 后 = events 文件里的 event_id）
@export var event_id: String = ""

## 音效钩子（E6 接线）：开箱音效资源路径占位；音频系统就绪前仅日志
@export var open_sfx_path: String = ""


## 交互动作执行（模板本体：①音效 ②给道具 ③提示对话 ④登记已开）。
## 由 interaction_controller 命中后调用（控制器只认协议、不懂宝箱语义，
## 行为分派在实体——A7 薄壳纪律的反面即"行为在数据侧"的临时形态）。
func on_interact() -> void:
	var id: String = _resolve_id()
	# ④' 已开判定（等价 not_flag 条件不成立）：只重播提示，不重复给道具
	if GameData.chests_opened.has(id):
		_start_dialogue()
		return
	# ① play_sfx（预留钩子；E6 音频系统就绪后在此换 AudioStreamPlayer2D）
	_play_open_sfx()
	# ② give_item：写 GameData.inventory（I2：与战斗掉落同入口，队伍共享）。
	#   键 = item_id（与掉落表 items[].item_id / 道具表主键同源），不是 chest_id
	#   ——chest_id 是事件标识，入背包键会把道具记账写歪（实测教训见证据档）。
	GameData.inventory[item_id] = int(GameData.inventory.get(item_id, 0)) + item_count
	print("[Chest] give_item %s x%d -> inventory=%s" % [item_id, item_count, GameData.inventory])
	# ③ dialogue(获得提示)：开演失败不阻断登记（对话文件缺失时箱子仍可开）
	_start_dialogue()
	# ④ set_flag：登记到 chests_opened（ADR-3 专用集合，去重）
	if not GameData.chests_opened.has(id):
		GameData.chests_opened.append(id)
	print("[Chest] set_flag：%s 已入 chests_opened（共 %d）" % [id, GameData.chests_opened.size()])


## 交互协议口：返回"获得提示"对话 id（控制器协议兼容面 + 模板③消费）
func get_npc_id() -> String:
	return dialogue_id if not dialogue_id.is_empty() else "chest_opened_" + _resolve_id()


## 事件标识口（E5 JSON 回迁时控制器按 event_id 分派的预留协议）
func get_event_id() -> String:
	return _resolve_id()


## id 兜底链：导出量 → event_id → 场景节点名（对齐 npc.gd _ready 兜底惯例）
func _resolve_id() -> String:
	if not chest_id.is_empty():
		return chest_id
	if not event_id.is_empty():
		return event_id
	return String(name)


## 获得提示对话：runner 缺席（测试直挂）/ 文件缺失时静默跳过，不阻断④
func _start_dialogue() -> void:
	var runner: Node = _find_dialogue_runner()
	if runner == null or not runner.has_method("start_dialogue"):
		return
	runner.start_dialogue(get_npc_id())


## 沿父链向树上找 DialogueRunner（挂 UILayer 跨场景常驻，A4）。
## 惰性查找而非装配注入：宝箱由地图装配方批量实例化（见 map_events.gd），
## runner 装配时序在地图 _ready 内不定，命中时再取最新引用最稳。
func _find_dialogue_runner() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var runner: Node = tree.root.get_node_or_null("Main/UILayer/DialogueRunner")
	if runner != null:
		return runner
	# 无 Main 结构（GUT 测试树）时按节点名全树浅查一次
	return tree.root.find_child("DialogueRunner", true, false)


## ① play_sfx 预留钩子：音频系统 E6 落地后改此实现（AudioStreamPlayer2D）
func _play_open_sfx() -> void:
	if open_sfx_path.is_empty():
		print("[Chest] play_sfx（预留，E6 接线）：未配置音效资源")
		return
	print("[Chest] play_sfx（预留，E6 接线）：%s" % open_sfx_path)
