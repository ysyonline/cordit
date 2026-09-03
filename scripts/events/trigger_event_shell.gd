extends Area2D
## trigger_event_shell.gd —— 统一事件触发器薄壳（E5-S2，架构 A7 第 1 层）
##
## 【需求依据】E5-S2 任务书"trigger_*.tscn 薄壳统一化"；架构 A7：触发器是
##   薄壳——Area2D + 脚本，属性只有标识 id，行为委托给数据（事件 JSON）；
##   对话 GDD §4/边缘 2（对话期间触发器不响应，DialogueRunner.is_idle()
##   是唯一门闸真源）。
##
## 【三层链路】命中 → EventLoader.get_event(id)（数据）→ EventExecutor.
##   execute_event（条件评估 + 动作执行）。壳里没有一行事件语义——这正是
##   A7"薄壳"的全部：递 id、把数据递给执行器。chest 自治四步、teleport
##   目录直驱、npc 对话直通是 E4 的临时形态，本壳是它们的 E5 收敛目标：
##   事件数据就绪的触发器一律挂本壳（new_event_id 非空 = 走事件路径），
##   E5-S3 NPC 事件、S4 剧情事件、S5 Boss 锚点共用，不再各造 trigger_*。
##
## 【双路径并行纪律】本壳不改动 chest/investigate/teleport 任何既有行为
## （E4 验收物零回归）；"event_id 协议"指各实体既有的 get_event_id() 接口
## 与本壳的 new_event_id 属性同为 A7 薄壳协议族，E5-S4 回迁时数据侧统一。
##
## 【门闸】_emit_event 前查 DialogueRunner.is_idle()——runner 未注入（无对话
## 装配的图/测试直挂）跳过门闸，与 trigger_teleport.setup(p_runner) 同口径。

## 事件标识（A7 薄壳协议属性）
@export var event_id: String = "trigger_event_shell"

## 事件路径开关：非空 = 命中时按此 id 执行事件（E5 事件路径）；空 = 本壳
## 仅承载 id，行为由既有实体协议分派（保持 E4 行为零变化）
@export var new_event_id: String = ""

## 事件表（装配注入；get_event(id) 取事件字典）
var _loader: Variant = null

## 事件执行器（装配注入；负责条件评估与动作执行）
var _executor: Variant = null

## 对话运行器引用（门闸用；装配注入）
var _dialogue_runner: Node = null


## 装配注入（地图侧 / 测试包装器调用；三引用都走这一个口）
func setup(p_loader: Variant, p_executor: Variant, p_runner: Node) -> void:
	_loader = p_loader
	_executor = p_executor
	_dialogue_runner = p_runner


func _ready() -> void:
	# 踩踏触发面（Area2D 监测体由装配侧 CollisionShape2D 提供）；
	# 交互触发面 = 本壳实现 on_interact()（interaction_controller 协议分派）
	body_entered.connect(_on_body_entered)


## 命中分发：交互触发（interaction_controller 命中本壳实体时调）与
## 踩踏触发（body_entered）最终都汇到 _emit_event——统一壳 = 统一入口。
func on_interact() -> void:
	_emit_event()


func _on_body_entered(_body: Node2D) -> void:
	_emit_event()


## 事件发射（薄壳全部逻辑）：门闸 → 取数据 → 递执行器。
## 门闸（边缘 2）：对话期间一律忽略；runner 未注入时跳过门闸（同 trigger_teleport
## 语义）。事件未登记 / 引用未装配：留日志静默跳过（数据缺失降级，不 crash）。
func _emit_event() -> void:
	if _dialogue_runner != null and not _dialogue_runner.is_idle():
		print("[TriggerEventShell] %s 对话期间忽略（is_idle 门闸）" % event_id)
		return
	if new_event_id.is_empty():
		return
	if _loader == null or not _loader.has_method("get_event"):
		print("[TriggerEventShell] 事件表未装配，%s 跳过" % new_event_id)
		return
	var ev: Dictionary = _loader.get_event(new_event_id)
	if ev.is_empty():
		print("[TriggerEventShell] 事件 \"%s\" 未登记，跳过" % new_event_id)
		return
	if _executor != null and _executor.has_method("execute_event"):
		_executor.execute_event(new_event_id, ev)
	else:
		print("[TriggerEventShell] 执行器未装配，%s 跳过" % new_event_id)
		return
	print("[TriggerEventShell] %s 已发射事件 %s" % [event_id, new_event_id])


## 测试注入口：绕过几何命中直驱发射链（headless 断言用；门闸语义与真实
## 路径完全一致——门闸本身也是被测对象，不在注入口里绕过）
func inject_emit() -> void:
	_emit_event()
