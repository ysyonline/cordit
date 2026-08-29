extends Node
## dialogue_runner.gd —— 对话运行器状态机（E1-S6 最小版）
##
## 【需求依据】架构 A7 + 对话 GDD §3.1/§4：
##   - 状态机 IDLE → PLAYING → IDLE（最小版；WAITING_CHOICE 态随 EPIC-2 选项
##     功能补入，状态枚举位已预留）；
##   - 逐字显示 30 字/秒（GDD §4 钉死速率）；
##   - 按键 1（interact: Z/E 任一）= 补完本条；按键 2 = 翻页/确认；
##   - 对话期间玩家移动锁定（A7），其他触发器不响应（GDD §4/边缘情况 2）；
##   - 对话内容全部来自 data/json/dialogues/*.json，零硬编码（E1-S6 验收 ③）。
##
## 【数据流】trigger_dialogue（薄壳）→ start_dialogue(npc_id)
##   → 按 npc_id 解析 res://data/json/dialogues/<npc_id>.json
##   → 取顶层唯一脚本 id → 条目字典 → "start" 入口逐条推进。
##   事件 JSON 加载器完整版（动作执行/phase 映射）属 EPIC-2，本版不做。
##
## 【信号】对话结束 emit EventBus.dialogue_finished(event_id)——
##   参数 = 触发用的 npc_id（与对话 JSON 文件名/town 锚点名三重对齐，
##   最小版无额外前缀；与 SMK-02/03 断言的信号签名（String 单参）一致）。
##
## 【玩家移动锁定的实现】直接调 player.set_input_override(Vector2.ZERO)？
##   不行——那只清掉测试注入，锁不住真实键盘。因此本类持有"输入压制"职责：
##   play() 期间由本 runner 每物理帧向玩家注入 ZERO？同样不成立（ZERO 是放行语义）。
##   故 player.gd 增加 is_input_locked 布尔锁（E1-S6 本次新增，语义见 player.gd）：
##   锁定即忽略一切移动输入（真实键盘与测试注入同等失效），unlock 后恢复。
##   这是本 Story 对已验收文件 player.gd 的唯一触碰点（新增字段与三行判空），
##   E1-S4/E1-S5 断言均在解锁态下运行，行为不变。
##
## 【UI 耦合】本节点持有 dialogue_box（scenes/ui/dialogue_box.tscn 实例）引用；
##   最小版由地图场景装配时传入。UI 显示与本状态机分离（见 dialogue_box.gd）。

## 枚举：状态机四态（GDD §3.1 机制第 3 条）。最小版只用 IDLE/PLAYING，
## WAITING_CHOICE 为 EPIC-2 选项功能预留位。
enum State { IDLE, PLAYING, WAITING_CHOICE }

## 逐字速率：30 字/秒（GDD §4 钉死；"字"= 码点数，中文一字一码）
const CHARS_PER_SECOND: float = 30.0

## 对话 JSON 根目录（A2 目录结构 + GDD §3.1：文件放 data/json/dialogues/）
const DIALOGUE_DIR: String = "res://data/json/dialogues/"

# ------------------------------------------------------------------
# 运行时状态
# ------------------------------------------------------------------

## 当前状态机状态
var state: State = State.IDLE

## 当前对话的事件标识（dialogue_finished 参数；触发时由 npc_id 派生）
var current_event_id: String = ""

## 当前对话脚本（条目 id → 条目字典）
var _entries: Dictionary = {}

## 当前条目 id
var _current_entry_id: String = ""

## 当前条目逐字显示已推进的字符数
var _char_shown: int = 0

## 当前条目是否已全量显示（true 后按键进入翻页/结束分支）
var _text_completed: bool = false

## 逐字推进的时间残差（避免帧率抖动造成累积丢字）
var _char_accumulator: float = 0.0

## 对话框 UI 引用（装配时注入；展示职责在 dialogue_box.gd）
var _dialogue_box: Control = null

## 玩家引用（移动锁定用；装配时注入）
var _player: CharacterBody2D = null

# ------------------------------------------------------------------
# 生命周期
# ------------------------------------------------------------------

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	# 逐字推进：按 30 字/s 匀速；Timer 节点在这里不如累积器精确且免装配
	if not _text_completed:
		_char_accumulator += delta * CHARS_PER_SECOND
		var full_text: String = _get_current_text()
		var target: int = mini(_char_shown + int(_char_accumulator), full_text.length())
		if target > _char_shown:
			_char_accumulator -= float(target - _char_shown)
			_char_shown = target
			_update_box_text()
		if _char_shown >= full_text.length():
			_text_completed = true
			_char_accumulator = 0.0
			_notify_box_text_completed()


## 交互键轮询：补完（未完成时）/ 翻页（已完成时）。
## 用 _unhandled_input 而非 _process 内 is_action_just_pressed：与场景其他
## 输入消费者解耦，且天然获得"每按一次只触发一次"的按下沿语义。
func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	if event.is_action_pressed("interact"):
		_advance()
		# 已消费，阻止穿透（其他触发器"对话期间不响应"的一部分）
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------
# 对外接口
# ------------------------------------------------------------------

## 装配注入（由地图场景 / 测试包装器调用）
func setup(p_dialogue_box: Control, p_player: CharacterBody2D) -> void:
	_dialogue_box = p_dialogue_box
	_player = p_player


## 是否空闲（其他触发器判定"对话期间不响应"的唯一依据，GDD 边缘情况 2）
func is_idle() -> bool:
	return state == State.IDLE


## 发起对话：npc_id → 解析 data/json/dialogues/<npc_id>.json → 进入 PLAYING。
## 返回 true = 成功开演；false = 拒绝（IDLE 之外 / JSON 缺失 / 结构非法）。
func start_dialogue(npc_id: String) -> bool:
	if state != State.IDLE:
		print("[DialogueRunner] 拒绝：状态机非 IDLE（当前 %s），忽略触发" % State.keys()[state])
		return false
	var entries: Dictionary = _load_dialogue_entries(npc_id)
	if entries.is_empty():
		return false
	_entries = entries
	# event_id = npc_id 直传：与对话 JSON 文件名、town 锚点名三重对齐
	# （GDD §3.3 事件 id 形态 npc_<name>；本项目 npc_id 已含 npc_ 前缀）。
	# EventBus.dialogue_finished 参数 = 该 id（String 单参，SMK-02/03 签名）。
	current_event_id = npc_id
	# 压锁玩家移动（A7：对话期间移动锁定；含测试注入一并失效，见头注释）
	if _player != null and _player.has_method("set_input_locked"):
		_player.set_input_locked(true)
	if _dialogue_box != null:
		_dialogue_box.open()
	state = State.PLAYING
	_enter_entry("start")
	print("[DialogueRunner] 开演：%s（%d 条目）" % [current_event_id, entries.size()])
	return true


# ------------------------------------------------------------------
# 内部实现
# ------------------------------------------------------------------

## JSON 加载：FileAccess 读 + JSON.parse。
## 【边界说明】scripts/core/ 才禁 get_node 进场景树；dialogue/ 属系统装配层，
## FileAccess 读 res:// 数据文件是 A7"数据驱动"的本体职责，不越界（A3 只约束
## autoload 四单例——GameData 无 IO 的边界不涉及本文件）。
## 加载失败（文件不存在/解析错/结构非法）打印原因并返回空字典，拒绝开演。
func _load_dialogue_entries(npc_id: String) -> Dictionary:
	var path: String = DIALOGUE_DIR + npc_id + ".json"
	if not FileAccess.file_exists(path):
		print("[DialogueRunner] 对话文件不存在：%s" % path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		print("[DialogueRunner] 对话文件为空：%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or (parsed as Dictionary).is_empty():
		print("[DialogueRunner] JSON 非法（顶层须为非空字典）：%s" % path)
		return {}
	# 顶层 = { 对话脚本id: { 条目id: 条目 } }；取唯一脚本（GDD §3.1：一个文件=一段对话）
	var script_key: String = (parsed as Dictionary).keys()[0]
	var entries: Dictionary = parsed[script_key]
	# 最小版结构校验：入口必须存在；条目必填 speaker/text/next（GDD §3.1 表）
	if not entries.has("start"):
		print("[DialogueRunner] 缺少 start 入口：%s" % path)
		return {}
	for entry_id: String in entries:
		var entry: Dictionary = entries[entry_id]
		if not entry.has("speaker") or not entry.has("text") or not entry.has("next"):
			print("[DialogueRunner] 条目 %s 缺必填字段（speaker/text/next）：%s" % [entry_id, path])
			return {}
	return entries


## 进入条目：名字栏 + 重置逐字器
func _enter_entry(entry_id: String) -> void:
	_current_entry_id = entry_id
	_char_shown = 0
	_char_accumulator = 0.0
	_text_completed = false
	var entry: Dictionary = _entries[entry_id]
	# 名字栏：空串 = 旁白（GDD §3.1），隐藏名字栏
	var speaker: String = entry.get("speaker", "")
	if _dialogue_box != null:
		_dialogue_box.set_speaker(speaker)
	_update_box_text()


## 当前条目全文（数据驱动断言③的直接消费面）
func _get_current_text() -> String:
	if _current_entry_id.is_empty():
		return ""
	return _entries[_current_entry_id].get("text", "")


## 当前条目已显示部分
func get_visible_text() -> String:
	return _get_current_text().substr(0, _char_shown)


## 当前条目全文（测试观察用）
func get_current_full_text() -> String:
	return _get_current_text()


## 逐字推进到框（UI 职责分离：runner 只喂数）
func _update_box_text() -> void:
	if _dialogue_box != null:
		_dialogue_box.set_text(get_visible_text())


## 逐字完成时通知框（框据此显示"继续"箭头提示；最小版由框自行简化）
func _notify_box_text_completed() -> void:
	if _dialogue_box != null and _dialogue_box.has_method("on_text_completed"):
		_dialogue_box.on_text_completed()


## 按键推进：按键 1 = 补完本条（GDD §4）；已完成时再按 = 翻页/结束（按键 2 语义）
func _advance() -> void:
	if not _text_completed:
		# 补完本条：剩余字符一次全出
		_char_shown = _get_current_text().length()
		_text_completed = true
		_char_accumulator = 0.0
		_update_box_text()
		_notify_box_text_completed()
		return
	# 已完成 → 翻页
	var next_id: String = _entries[_current_entry_id].get("next", "END")
	if next_id == "END":
		_finish_dialogue()
	else:
		_enter_entry(next_id)


## 收束：回 IDLE + 解锁玩家 + 关框 + emit dialogue_finished（SMK-02/03 断言依赖，
## 信号名与 String 单参签名不得改动）
func _finish_dialogue() -> void:
	state = State.IDLE
	if _player != null and _player.has_method("set_input_locked"):
		_player.set_input_locked(false)
	if _dialogue_box != null:
		_dialogue_box.close()
	print("[DialogueRunner] 对话结束：%s → IDLE" % current_event_id)
	EventBus.dialogue_finished.emit(current_event_id)
	current_event_id = ""
	_entries = {}
	_current_entry_id = ""


## 测试注入口：直接注入"按键按下"事件（headless 断言 ② 的推进通道）。
## 生产路径 = _unhandled_input 收真实 InputEventKey；测试用 InputEventAction
## 走同一 is_action_pressed 判定，语义等价（探针已验证 headless 下链路可用）。
func inject_interact_press() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	_unhandled_input(ev)
