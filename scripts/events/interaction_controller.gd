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

## E5-S3 事件层装配（可选注入：事件表 + 动作执行器）。两者齐备时，NPC 交互
## 走事件路径（GDD §3.3：NPC 节点只带 npc_id，交互事件按 phase 映射选对话）；
## 未注入（E1-S6 既有装配/旧测试）或 id 未登记时走直开对话兼容路径，行为零变化。
var _event_loader: Variant = null
var _event_executor: Variant = null

## M8-A②（rev2）：当前高亮的交互提示实体（脏引用守卫；无高亮为 null）。
## 提示显隐由本控制器每物理帧统一驱动，见 _update_interact_hint()。
var _hint_target: Node = null

## M8-A②（rev3）去抖阈值：点亮新目标需**连续命中的物理帧数**；熄灭则即时（非对称
##   迟滞）。3 帧 ≈50ms——足以滤掉"转身/走动经过瞄准线"的单帧噪声，又无可感迟滞。
const HINT_SETTLE_FRAMES: int = 3

## M8-A②（rev3）：当前"候选目标"及其已连续命中帧数（未达阈值前不点亮）。
var _candidate: Node = null
var _candidate_frames: int = 0


## 装配注入（地图根脚本或测试包装器调用）
func setup(p_player: CharacterBody2D, p_runner: Node) -> void:
	_player = p_player
	_runner = p_runner


## E5-S3 事件层注入（可选：town 装配调用；不调用 = 事件路径关闭）
func setup_events(p_loader: Variant, p_executor: Variant) -> void:
	_event_loader = p_loader
	_event_executor = p_executor


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
## 【E5-S3 增量】② 内部按事件层优先分派：NPC 交互事件（npc_<id>）已登记
##   且执行器在位 → execute_event（phase 映射在事件层，GDD §3.3）；未登记 /
##   事件层未装配 → 直开 get_npc_id()（E1-S6 兼容路径，冒烟零回归）。
## 【E5-M5 修】on_interact 自治协议升为第一优先：原"沿父链找 get_npc_id
##   持有者"会把 Boss 壳（Area2D，无 get_npc_id）一路吞到地图根才 return
##   ——自治实体永远分派不到。改为先沿父链找 on_interact 持有者（命中即
##   分派即返回；Area2D 壳的父链必经地图根，不可再上溯——on_interact 会
##   误吞实体根语义），无自治协议才退回 get_npc_id 路径（NPC/宝箱/调查点
##   零变化）。
func _try_interact() -> void:
	if not _player.has_method("get_interact_target"):
		return
	var target: Object = _player.get_interact_target()
	var node: Node = target as Node
	# 自治协议第一优先：沿父链找 on_interact 持有者（命中即分派即返回）
	var scan: Node = node
	while scan != null:
		if scan.has_method("on_interact"):
			scan.on_interact()
			return
		scan = scan.get_parent()
	# NPC 协议路径（E1-S6/E5-S3 既有分派，行为零变化）
	while node != null and not node.has_method("get_npc_id"):
		node = node.get_parent()
	if node == null:
		return
	dispatch_interaction(node)


## NPC 交互分派（E5-S3）：事件路径优先，兼容路径兜底。
## 公开给测试直驱（headless 免射线装配）；门闸（is_idle）在 _unhandled_input
## 已短路，此处不再重复判定。
func dispatch_interaction(p_npc: Node) -> void:
	if _event_loader != null and _event_executor != null \
			and p_npc.has_method("get_npc_id"):
		# 事件 id = "npc_" + 显示段（npc_01_innkeeper → npc_innkeeper，与 S2
		# npc_innkeeper.json 示例命名对齐）。【E5-S3 修】不能只取 parts[2]：
		# 四段 id（npc_03_chase_kid）会被截成 npc_chase → 查无事件 → 误落
		# 兼容路径开 npc_03_chase_kid.json（不存在）。正解：剥掉首段 "npc"
		# 协议前缀 + 序号段（全数字段），剩余段全部回拼——
		# npc_01_innkeeper → npc_innkeeper，npc_03_chase_kid → npc_chase_kid，
		# npc_12_elder → npc_elder，与 events/ 六份 NPC 事件文件名对齐；
		# 无前缀裸 id（guard → npc_guard）同样命中。
		var npc_id := String(p_npc.get_npc_id())
		var segs: PackedStringArray = npc_id.split("_")
		var display_parts: Array[String] = []
		for i: int in segs.size():
			if i == 0 and segs[i] == "npc":
				continue   # 协议前缀段（get_npc_id 协议名）
			if (segs[i] as String).is_valid_int():
				continue   # 序号段（npc_01 / npc_12 的编号）
			display_parts.append(segs[i])
		var event_id := "npc_" + "_".join(display_parts)
		if _event_loader.has_event(event_id):
			_event_executor.execute_event(event_id, _event_loader.get_event(event_id))
			return
	# 兼容路径（E1-S6 冒烟契约）：直开 npc_id 对话
	if _runner.has_method("start_dialogue"):
		_runner.start_dialogue(String(p_npc.get_npc_id()))


## 测试注入口：headless 断言用（等价真实按键 Z，探针验证 InputEventAction
## 可穿透 _unhandled_input 的 is_action_pressed 判定）
func inject_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = INTERACT_ACTION
	ev.pressed = true
	_unhandled_input(ev)


# ------------------------------------------------------------------
# M8-A②（rev2/rev3）：交互提示显隐驱动（NPC 头顶「❗Z」）
# ------------------------------------------------------------------

## 每物理帧读取玩家当前交互目标 → 仅点亮该实体、其余全灭。
## 【判据同源】复用 player.get_interact_target()（面朝 + InteractRay 20px 命中），
##   与 Z 键分派 _try_interact() 完全同一判据 → 保证"提示亮 ⇔ 按 Z 有目标"，
##   修 rev2 缺陷①（原按脚底距离判定会"亮起但按 Z 无目标"）。
## 【rev3 去抖】点亮需连续 HINT_SETTLE_FRAMES 帧稳定命中，熄灭即时——修用户实机
##   残留缺陷"正后方/其他角度会亮一下 ❗ 然后不亮"中的单帧假亮（配合 player.gd
##   松键朝向保持，二者共同消除朝向抖动引发的脉冲）。
## 【开销】每帧一次射线（非 12 NPC 各一次），可忽略。
func _physics_process(_delta: float) -> void:
	_update_interact_hint()


## 切换提示高亮（rev3 增去抖）：记住上一帧实体，脏引用安全地先熄灭旧的、再点亮新的。
## 【非对称迟滞（rev3）】
##   · 熄灭**即时**（≤1 帧）：无稳定目标立刻收起——不产生"残留亮帧"；
##   · 点亮**需连续 HINT_SETTLE_FRAMES 帧稳定命中**：滤掉单帧噪声假亮。
## 无变化（含"始终无目标"）则清候选、跳过，避免冗余调用与误计数。
func _update_interact_hint() -> void:
	var next: Node = _resolve_hint_target()
	if next == _hint_target:
		_candidate = null
		_candidate_frames = 0
		return
	if next == null:
		# 熄灭即时（非对称迟滞的"快灭"侧）
		_set_hint(_hint_target, false)
		_hint_target = null
		_candidate = null
		_candidate_frames = 0
		return
	# next 为新的非空目标：需连续命中 HINT_SETTLE_FRAMES 帧才点亮
	if next == _candidate:
		_candidate_frames += 1
	else:
		_candidate = next
		_candidate_frames = 1
	if _candidate_frames >= HINT_SETTLE_FRAMES:
		_set_hint(_hint_target, false)   # 先灭旧（脏引用守卫在 _set_hint）
		_set_hint(next, true)
		_hint_target = next
		_candidate = null
		_candidate_frames = 0


## 解析"玩家当前交互目标对应的提示实体"：无玩家 / 对话锁定 / 无命中 → null。
## 命中体沿父链上溯至首个暴露 set_interact_hint_visible 的实体根
## （NPC 根即其 get_npc_id 持有者，与 _try_interact 的父链解析同款手法）；
## 非提示实体（墙 / 宝箱 / Boss 壳）不暴露该协议 → null（不抢提示）。
## 对话/演出锁定（player.is_input_locked）时一律不提示（保持收起，rev2 保留）。
func _resolve_hint_target() -> Node:
	if _player == null:
		return null
	if _player.get("is_input_locked") == true:
		return null
	if not _player.has_method("get_interact_target"):
		return null
	var node: Node = _player.get_interact_target() as Node
	while node != null:
		if node.has_method("set_interact_hint_visible"):
			return node
		node = node.get_parent()
	return null


## 落显隐（脏引用安全：目标实体可能已随图释放 → is_instance_valid 守卫）
func _set_hint(p_node: Node, p_visible: bool) -> void:
	if p_node != null and is_instance_valid(p_node) \
			and p_node.has_method("set_interact_hint_visible"):
		p_node.set_interact_hint_visible(p_visible)
