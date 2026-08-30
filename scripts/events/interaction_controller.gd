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
	if _player == null:
		return
	# 对话期间其他触发器不响应（GDD §4 / 边缘情况 2）：runner 非 IDLE 一律短路。
	# runner 为 null（无对话装配的图）时跳过门闸——宝箱/调查的自治路径不依赖
	# runner，模板内部自行判空。
	if _runner != null and not _runner.is_idle():
		return
	if event.is_action_pressed(INTERACT_ACTION):
		_try_interact()


## 尝试交互：面前射线命中 → 沿父链找实体根 → 按协议分派。
## 【4.7.2 实测注意】射线返回的是碰撞形状宿主节点——NPC 的可交互体是
## 子节点 InteractBody（裸 StaticBody2D，见 npc.tscn 注记），而交互协议
## get_npc_id() 定义在实体根上。因此命中后沿 parent 链向上找协议持有者，
## 命中根本体（无子碰撞体的交互物）时第一跳即满足，行为一致。
## 【E4-S5 协议分派】（A7：控制器不懂事件语义，只认方法签名）：
##   ① 实体根实现 on_interact() → 调用后即返回（模板事件自治：宝箱
##      "音效→给道具→提示对话→登记"四步在 chest.gd 内闭环；调查点同理）；
##   ② 否则按 E1-S6 既有协议开对话（NPC 路径，行为零变化）。
##   判据用 has_method 而非类型/分组：不引入新依赖，未来任何实体挂上
##   on_interact() 即自动获得自治能力（薄壳协议的可扩展形态）。
func _try_interact() -> void:
	if not _player.has_method("get_interact_target"):
		return
	var target: Object = _player.get_interact_target()
	var node: Node = target as Node
	while node != null and not node.has_method("get_npc_id"):
		node = node.get_parent()
	if node == null:
		return
	if node.has_method("on_interact"):
		node.on_interact()
		return
	if _runner.has_method("start_dialogue"):
		_runner.start_dialogue(node.get_npc_id())


## 测试注入口：headless 断言用（等价真实按键 Z，探针验证 InputEventAction
## 可穿透 _unhandled_input 的 is_action_pressed 判定）
func inject_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = INTERACT_ACTION
	ev.pressed = true
	_unhandled_input(ev)
