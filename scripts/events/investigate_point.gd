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
##
## 【M7-R6 增量·事件路径优先】get_event_id() 预留协议正式启用：事件层注入
##   （setup_events）且本点位 id 已登记事件表时，交互优先走 A7 事件协议
##   （门闸同 TriggerEventShell is_idle 口径 → EventExecutor.conditions_met
##   评估 → 达标交执行器执行动作）。落地用例 = town 告示板（inv_town_02）：
##   phase==0 交互开演 story_quest_accept（story_p1_dispatch + 置 phase 1，
##   条件守卫在事件 JSON 侧）；phase>=1 条件不满足 → 回落 flavor 风味文本。
##   "调查点无状态、可无限重复交互"语义不变——phase 演进全部由事件数据侧
##   驱动，本层不持有任何游戏状态；未注入事件层（其余四图/旧测试）行为零变化。

## 调查点唯一标识（点位表主键；如 "inv_town_01"）
@export var inv_id: String = ""

## 调查对话 id（解析 data/json/dialogues/map_<map>_flavor.json 的脚本键）
@export var dialogue_id: String = ""

## 事件标识（A7 薄壳协议属性：E5 回迁 JSON 后 = events 文件里的 event_id）
@export var event_id: String = ""

## 剧情事件 id 覆盖（M7-R6）：点位 id 与事件表键不一致时显式指定
## （告示板用例：inv_town_02 → story_quest_accept，由 town_map 装配面写入）；
## 空 = 事件路径按 get_event_id() 作事件键（同构 id 命名约定）
@export var quest_event_id: String = ""

## 事件表（M7-R6 注入；null = 事件路径关闭，交互直走 flavor 兼容路径）
var _event_loader: Variant = null

## 事件执行器（M7-R6 注入；条件评估 + 动作执行）
var _event_executor: Variant = null

## 对话运行器引用（事件路径 is_idle 门闸用；装配注入）
var _dialogue_runner: Node = null


## 事件层注入（M7-R6：map_events.assemble 可选参数透传 / 测试直调；
## 三引用都走这一个口，同 TriggerEventShell.setup 口径）
func setup_events(p_loader: Variant, p_executor: Variant, p_runner: Node) -> void:
	_event_loader = p_loader
	_event_executor = p_executor
	_dialogue_runner = p_runner


## 交互动作执行（M7-R6 起：事件路径优先，回落无状态 flavor 调查）。
## 分派规则：
##   ① 事件层已注入且 get_event_id() 已登记事件表 → 事件路径：
##      is_idle 门闸（对话期间忽略，边缘 2）→ conditions_met 评估（如
##      story_quest_accept 的 story_phase==0 守卫）→ 达标执行动作后返回；
##      条件不满足（如 phase>=1 的告示板）→ 落到 ② 回落风味文本。
##   ② 既有无状态调查路径（E4-S5 零回归）：直开 flavor 对话，可无限重复。
func on_interact() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	# —— ① 事件路径（M7-R6 剧情链接线：告示板 phase==0 → story_quest_accept）
	if _event_loader != null and _event_executor != null:
		var eid: String = get_event_id()
		if not quest_event_id.is_empty():
			eid = quest_event_id   # 点位 id ≠ 事件键时按覆盖属性取（见属性头注）
		if _event_loader.has_event(eid):
			# 门闸（同 TriggerEventShell 口径）：对话期间一律忽略
			if _dialogue_runner != null and not _dialogue_runner.is_idle():
				print("[Investigate] %s 对话期间忽略（is_idle 门闸）" % eid)
				return
			var ev: Dictionary = _event_loader.get_event(eid)
			if _event_executor.conditions_met(ev):
				_event_executor.execute_event(eid, ev)
				return
			# 条件不满足（如 phase>=1）：回落风味文本，走既有调查语义
	# —— ② 既有无状态调查路径（E4-S5 行为零变化）
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
