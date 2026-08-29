extends Node
## interaction_controller.gd —— 交互轮询器（E1-S6，探索 GDD §3.3 的执行侧）
##
## 【需求依据】探索 GDD §3.3：交互键 Z 或 E 均有效；检测范围 =
##   玩家面前 1 格 + 自身所在格；对话 GDD §4：对话期间其他触发器不响应。
##
## 【职责】每物理帧轮询 interact 动作（Z/E 同一动作的两个物理键位，
##   project.godot 已注册）→ 命中时取玩家 InteractRay 的目标 →
##   交给 DialogueRunner。几何判定（面前 1 格）在 player.get_interact_target()。
##
## 【防重入】DialogueRunner.is_idle() 为唯一门闸：非 IDLE 时按键归对话推进
##   消费（runner._unhandled_input），本层直接短路，杜绝"对话内再触发"。
##
## 【装配】地图场景根脚本 _ready 时 setup(player, dialogue_runner)；
##   测试树由包装器装配。挂在地图场景内，随图生灭，无全局状态。

## 交互动作名（project.godot [input]，Z=90 / E=69 两物理键位）
const INTERACT_ACTION: String = "interact"

var _player: CharacterBody2D = null
var _runner: Node = null


## 装配注入（地图根脚本或测试包装器调用）
func setup(p_player: CharacterBody2D, p_runner: Node) -> void:
	_player = p_player
	_runner = p_runner


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _runner == null:
		return
	# 对话期间其他触发器不响应（GDD §4 / 边缘情况 2）：runner 非 IDLE 一律短路
	if not _runner.is_idle():
		return
	if event.is_action_pressed(INTERACT_ACTION):
		_try_interact()


## 尝试交互：面前射线命中 → 沿父链找实体根 → 开对话。
## 【4.7.2 实测注意】射线返回的是碰撞形状宿主节点——NPC 的可交互体是
## 子节点 InteractBody（裸 StaticBody2D，见 npc.tscn 注记），而交互协议
## get_npc_id() 定义在实体根上。因此命中后沿 parent 链向上找协议持有者，
## 命中根本体（无子碰撞体的交互物）时第一跳即满足，行为一致。
## 最小版目标协议：交互物实现 get_npc_id() -> String 即可被对话系统消费
## （后续宝箱/调查点按 A7 走事件 id 分派，EPIC-2 扩展）。
func _try_interact() -> void:
	if not _player.has_method("get_interact_target"):
		return
	var target: Object = _player.get_interact_target()
	var node: Node = target as Node
	while node != null and not node.has_method("get_npc_id"):
		node = node.get_parent()
	if node != null and _runner.has_method("start_dialogue"):
		_runner.start_dialogue(node.get_npc_id())


## 测试注入口：headless 断言用（等价真实按键 Z，探针验证 InputEventAction
## 可穿透 _unhandled_input 的 is_action_pressed 判定）
func inject_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = INTERACT_ACTION
	ev.pressed = true
	_unhandled_input(ev)
