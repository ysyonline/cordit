extends StaticBody2D
## investigate_point.gd —— 调查点事件实体（E4-S5，探索 GDD §3.3 调查模板）
##
## 【需求依据】探索 GDD §3.3：调查点 = 交互触发器 + dialogue
##   （`map_<map>_flavor.json` 单条目）；文案原则：一半世界观氛围
##   （"石像的眼睛被人凿去了"），一半纯趣味（"花坛里的土最近被翻过"）。
##   拍板项④：硬编码触发器先行，点位数据结构化落盘（flavor.json + 点位表），
##   E5-S2 加载器就绪后回迁 JSON 驱动。
##
## 【与宝箱的差异】无状态、可无限次交互（每次都重播同一条 flavor 对话），
##   不写 chests_opened、不写 flags、不给道具——调查是纯氛围内容点。
##
## 【交互协议】沿 chest.gd 同款：本节点为层 2 StaticBody2D 交互判定体，
##   get_npc_id() 返回 flavor 对话 id 供既有 interaction_controller 零改动
##   消费（控制器按协议开对话，无需理解"调查点"语义）。
##
## 【装配规格】同 chest.gd：根 (0,0) = 脚底触地点；BodyRect 12x12 灰蓝
##   占位矩形（美术线到位后按点位题材换装饰物贴图，如石像/花坛/木牌）；
##   InteractShape 16x16 @ (0,-6) 层 2。调查点格不挂层 1（不挡路）。

## 调查点唯一标识（点位表主键；如 "inv_town_01"）
@export var inv_id: String = ""

## 调查对话 id（解析 data/json/dialogues/map_<map>_flavor.json 的脚本键）
@export var dialogue_id: String = ""

## 事件标识（A7 薄壳协议属性：E5 回迁 JSON 后 = events 文件里的 event_id）
@export var event_id: String = ""


## 交互动作执行（调查模板 = 单条 dialogue，无状态）
func on_interact() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var runner: Node = tree.root.get_node_or_null("Main/UILayer/DialogueRunner")
	if runner == null:
		runner = tree.root.find_child("DialogueRunner", true, false)
	if runner != null and runner.has_method("start_dialogue"):
		runner.start_dialogue(get_npc_id())
	print("[Investigate] %s -> dialogue %s" % [_resolve_id(), get_npc_id()])


## 交互协议口（interaction_controller 沿父链找协议持有者；对话 id 直通）
func get_npc_id() -> String:
	if not dialogue_id.is_empty():
		return dialogue_id
	return "inv_" + _resolve_id()


## 事件标识口（E5 JSON 回迁预留协议）
func get_event_id() -> String:
	return _resolve_id()


## id 兜底链：导出量 → event_id → 场景节点名
func _resolve_id() -> String:
	if not inv_id.is_empty():
		return inv_id
	if not event_id.is_empty():
		return event_id
	return String(name)
