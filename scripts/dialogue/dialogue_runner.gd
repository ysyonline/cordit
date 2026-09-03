extends Node
## dialogue_runner.gd —— 对话运行器四态状态机（E5-S1 完整版，架构 A7）
##
## 【升级自】E1-S6 最小版（IDLE→PLAYING→IDLE）。本版补入 WAITING_CHOICE：
##   IDLE → PLAYING → (WAITING_CHOICE ⇄ PLAYING) → IDLE，A7 原文四态封顶。
##
## 【需求依据】对话 GDD §3.1（字段规范与两个示例 JSON）、§3.4（选项"仅影响
##   当句"：≤2 项、分支尾巴 ≤2 条目必汇合、无持久后果——结构校验在加载期，
##   无持久后果由"选项只改变当句走向、不写任何 flag"的运行时纪律保证）、
##   §4（逐字 30 字/秒；按键 1 = 补完本条，按键 2 = 翻页/确认选项；对话期间
##   锁玩家移动 + 其他触发器休眠）、边缘 2/4/5；UI 规格 §二（五要素喂数）。
##
## 【四态语义】
##   IDLE           待机；is_idle() 是全项目触发器休眠门闸的唯一真源（边缘 2）
##   PLAYING        逐字推进/等待翻页
##   WAITING_CHOICE 选项列表已开，必须显式选择（边缘 4：取消/移动键忽略）
##   （选完回 PLAYING，沿所选分支 next 继续播）
##
## 【输入路由】单动作 "interact"（Z/E）+ 方向键复用为选项光标移动：
##   PLAYING 态   _unhandled_input 消费 interact（补完/翻页）；
##   WAITING_CHOICE 态 interact 与 move_up/move_down 转交对话框
##   handle_choice_input（UI 消费光标与确认，本类只接选中信号）——
##   边缘 4 的"忽略取消/移动键"由对话框侧只认这三个动作实现（无取消路径）。
##   WAITING_CHOICE 态 _unhandled_input 一律 set_input_as_handled，
##   按键不穿透到任何触发器/玩家侧。
##
## 【读档安全（边缘 5）】对话中途读档（失败读档/DEFEAT 自动读档等路径）后
##   状态机必须回 IDLE：本类监听 SaveManager.load_save 的消费口不可行（读档
##   不发信号），故对外暴露 force_idle()——由读档链路（E5-S3 存档接线时挂
##   EventBus.map_ready 前）与测试调用；语义 = 弃当前对话、解锁玩家、关框、
##   清簿记，不 emit dialogue_finished（对话未正常收束，不发假完成信号）。
##
## 【跨图复用（E5-M5 增量）】runner/框挂 UILayer 常驻（town 装配，遗迹图复用），
##   但 _player 指向装配图玩家——玩家随图生灭，跨图后旧引用已释放。因此：
##   ① 对 _player 的锁/解锁一律先 is_instance_valid 守卫（已释放 = 跳过，零噪音）；
##   ② 新增 rebind_player()：遗迹图 _ready 时把 _player 换绑到本图玩家
##   （f3 装配面调用，见 ruins_f3_map._assemble_boss_anchor）——战前台词锁
##   玩家、战斗回来 force_idle 解锁，全程引用鲜活。
##
## 【结构校验加载期拦截（GDD §3.1 + 校验器职责前移）】加载对话 JSON 时校验：
##   顶层单脚本 + start 入口 + 必填 speaker/text/next + next/choices.next
##   引用完整 + choices ≤2 + 选项分支尾巴汇合（3.4 第 2 条：从选项 next 出发
##   ≤2 步必须到达同一汇合点或 END）+ 选项条目不带 choices（禁嵌套选择）。
##   任一不过 = 整份拒绝开演（边缘 1：悬空引用游戏内不出现）。文本超 60 字
##   只告警不拒（渲染层自动折行，GDD §3.1"超长由渲染层处理"）。
##   E5-S2 起校验逻辑抽离至 scripts/data/schema_validator.gd（对话 + 事件
##   两路复用同一口径：动作白名单 / 引用完整性 / 结构校验三职责），本类
##   _validate_entries 保留同名薄委托（存量直驱测试零改动、校验口径单源）。

## 枚举：状态机四态（A7；E5-S1 起四态全部启用）
enum State { IDLE, PLAYING, WAITING_CHOICE }

## 逐字速率：30 字/秒（GDD §4 钉死；"字"= 码点数，中文一字一码）
const CHARS_PER_SECOND: float = 30.0

## 对话 JSON 根目录（A2 目录结构 + GDD §3.1：文件放 data/json/dialogues/）
const DIALOGUE_DIR: String = "res://data/json/dialogues/"

## 选项分支尾巴汇合步数上限（GDD §3.4 第 2 条：≤2 步内汇合到同一 next 或各自 END）
const BRANCH_TAIL_MAX_STEPS: int = 2

# ------------------------------------------------------------------
# 运行时状态
# ------------------------------------------------------------------

## 当前状态机状态
var state: State = State.IDLE

## 当前对话的事件标识（dialogue_finished 参数；触发时由调用方 id 派生）
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

## 头像差分记忆（GDD §3.1：portrait 缺省沿用上一条；开演时复位为空）
var _current_portrait: String = ""

## 选项待决列表（进入 WAITING_CHOICE 时快照；选中后按 next 跳转）
var _pending_choices: Array = []

## 对话框 UI 引用（装配时注入；展示职责在 dialogue_box.gd）
var _dialogue_box: Control = null

## 玩家引用（移动锁定用；装配时注入）
var _player: CharacterBody2D = null

# ------------------------------------------------------------------
# 生命周期
# ------------------------------------------------------------------

func _process(delta: float) -> void:
	# 逐字只在 PLAYING 推进；WAITING_CHOICE 态文本已完成、无需走此处
	if state != State.PLAYING:
		return
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


## 输入路由（headless 与生产同一入口；语义见头注释【输入路由】）。
## _unhandled_input 天然获得按下沿语义；WAITING_CHOICE 态全量吞键（含移动），
## 选项方向/确认经对话框 handle_choice_input 分派——取消/横移等一律忽略（边缘 4）。
func _unhandled_input(event: InputEvent) -> void:
	if state == State.WAITING_CHOICE:
		var consumed := false
		if event.is_action_pressed("interact"):
			consumed = _dialogue_box.handle_choice_input("interact")
		elif event.is_action_pressed("move_up"):
			consumed = _dialogue_box.handle_choice_input("move_up")
		elif event.is_action_pressed("move_down"):
			consumed = _dialogue_box.handle_choice_input("move_down")
		# 边缘 4：选项态其余按键（含取消/横移）一律吞掉不响应
		get_viewport().set_input_as_handled()
		return
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
	if _dialogue_box != null and _dialogue_box.has_signal("choice_selected"):
		if not _dialogue_box.choice_selected.is_connected(_on_choice_selected):
			_dialogue_box.choice_selected.connect(_on_choice_selected)


## 玩家换绑（E5-M5：跨图复用装配面）。runner/框常驻 UILayer，但玩家随图生灭
## ——遗迹图 _ready 时调用，把 _player 换到本图玩家（旧引用可能已释放，直接
## 覆写即可）。不重绑对话框（框也是常驻的，信号已在 setup 时接好）。
func rebind_player(p_player: CharacterBody2D) -> void:
	_player = p_player


## 是否空闲（其他触发器判定"对话期间不响应"的唯一依据，GDD 边缘 2。
## WAITING_CHOICE 亦非空闲——选项悬而未决时世界必须静止）
func is_idle() -> bool:
	return state == State.IDLE


## 发起对话：id → 解析 data/json/dialogues/<id>.json → 进入 PLAYING。
## 返回 true = 成功开演；false = 拒绝（IDLE 之外 / JSON 缺失 / 结构非法）。
func start_dialogue(id: String) -> bool:
	if state != State.IDLE:
		print("[DialogueRunner] 拒绝：状态机非 IDLE（当前 %s），忽略触发" % State.keys()[state])
		return false
	var entries: Dictionary = _load_dialogue_entries(id)
	if entries.is_empty():
		return false
	_entries = entries
	current_event_id = id
	# 压锁玩家移动（A7：对话期间移动锁定；含测试注入一并失效）。
	# is_instance_valid 守卫：玩家随图生灭，跨图后旧引用已释放——Godot 4 对
	# 已释放对象调方法会炸，守卫跳过（rebind_player 由新图装配面换绑）
	if _player != null and is_instance_valid(_player) and _player.has_method("set_input_locked"):
		_player.set_input_locked(true)
	if _dialogue_box != null:
		_dialogue_box.open()
	state = State.PLAYING
	_current_portrait = "uninit"   # 哨兵：迫使首条目必刷一次头像窗（清上段对话残留）
	_enter_entry("start")
	print("[DialogueRunner] 开演：%s（%d 条目）" % [current_event_id, entries.size()])
	return true


## 强制回 IDLE（GDD 边缘 5：对话中途读档后状态机回 IDLE）。
## 由读档链路（E5-S3 接线）/ 测试调用：弃当前对话、解锁玩家、关框、清簿记；
## 不 emit dialogue_finished（对话未正常收束，不发假完成信号）。
## 幂等：IDLE 态调用为无害空操作。
func force_idle() -> void:
	if state == State.IDLE:
		return
	var aborted_id: String = current_event_id
	if _dialogue_box != null:
		_dialogue_box.close()   # 含关选项窗
	state = State.IDLE
	if _player != null and is_instance_valid(_player) and _player.has_method("set_input_locked"):
		_player.set_input_locked(false)
	print("[DialogueRunner] 强制收束（读档安全，边缘 5）：弃 %s → IDLE" % aborted_id)
	_clear_runtime()


# ------------------------------------------------------------------
# 内部实现 · 加载与校验（校验本体已抽离 schema_validator.gd，此处薄委托）
# ------------------------------------------------------------------

## schema 校验器（E5-S2 抽离：对话 + 事件两路复用，静态纯函数集）
const SchemaValidator := preload("res://scripts/dialogue/schema_validator.gd")


## JSON 加载 + 结构校验。E5-S2 起加载与校验本体在 SchemaValidator.
## load_dialogue_script（res:// 同源同口径），本方法仅保留内部调用面。
## 加载失败（文件不存在/解析错/结构非法）打印原因并返回空字典，拒绝开演。
func _load_dialogue_entries(id: String) -> Dictionary:
	return SchemaValidator.load_dialogue_script(id)


## 对话脚本结构校验。返回空串 = 通过；非空 = 首个拒绝原因。
## 【薄委托保留说明】E5-S1 的校验器直驱测试（test_e5s1 反例组）以本方法为
## 入口——签名与语义零变化，实现转发给校验器，口径单源（改动只发生在一处）。
func _validate_entries(entries: Dictionary, path: String) -> String:
	return SchemaValidator.validate_dialogue_entries(entries, path)


# ------------------------------------------------------------------
# 内部实现 · 条目推进
# ------------------------------------------------------------------

## 进入条目：名字栏 + 头像 + 重置逐字器
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
	# 头像差分：缺省沿用上一条（GDD §3.1 字段表）；变化时才换帧（§4 差分切换）。
	# 开演哨兵 "uninit" 保证首条目必刷一次（清上段对话的头像残留）。
	# 【首条目洞修补（E5-S2）】原实现 `get("portrait", _current_portrait)` 在
	# 首条目无 portrait 字段时取回哨兵自身、"不变化"分支永不触发——上段对话
	# 的头像残留不被清除。S1 的旁白脚本 start 带显式 "portrait": "" 掩盖了
	# 此洞；修正为：首条目（哨兵在位）强制走刷新，后续条目维持缺省沿用。
	var is_first_entry: bool = _current_portrait == "uninit"
	var portrait: String = String(entry.get("portrait", "" if is_first_entry else _current_portrait))
	if is_first_entry or portrait != _current_portrait:
		_current_portrait = portrait
		_apply_portrait(portrait)
	_update_box_text()


## 头像差分落框：可解析 → 换 48×48 帧；空/未登记 → 隐藏头像窗（降级不报错）
func _apply_portrait(portrait_id: String) -> void:
	if _dialogue_box == null or not _dialogue_box.has_method("set_portrait"):
		return
	const PortraitCatalog := preload("res://scripts/dialogue/portrait_catalog.gd")
	_dialogue_box.set_portrait(PortraitCatalog.get_texture(portrait_id))


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


## 当前条目是否带待选选项（测试/上层观察用）
func has_pending_choices() -> bool:
	return state == State.WAITING_CHOICE


## 逐字推进到框（UI 职责分离：runner 只喂数）
func _update_box_text() -> void:
	if _dialogue_box != null:
		_dialogue_box.set_text(get_visible_text())


## 逐字完成时通知框（框据此显示"继续"箭头提示）
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
	# 已完成 → 翻页；本条带选项 → 进 WAITING_CHOICE（GDD §3.1：choices 与 next 同条目时，
	# 选项优先——翻页动作变为"弹出选项列表"）
	var entry: Dictionary = _entries[_current_entry_id]
	var choices: Variant = entry.get("choices")
	if choices != null and not (choices as Array).is_empty():
		_pending_choices = choices
		state = State.WAITING_CHOICE
		if _dialogue_box != null and _dialogue_box.has_method("open_choices"):
			var labels: Array = []
			for c: Variant in _pending_choices:
				labels.append(String((c as Dictionary)["text"]))
			_dialogue_box.open_choices(labels)
		print("[DialogueRunner] 选项待决：%s（%d 项）" % [_current_entry_id, _pending_choices.size()])
		return
	# 缺省 "END" 兜底：带 choices 无 next 的条目（GDD §3.1 示例口径）在选项
	# 全部失效的病态数据下按结束收束；正常路径已被加载校验拦截
	var next_id: String = entry.get("next", "END")
	if next_id == "END":
		_finish_dialogue()
	else:
		_enter_entry(next_id)


## 选项选中（对话框 choice_selected 回调）：关窗 → 回 PLAYING → 沿所选分支 next。
## 选项"仅影响当句"的运行时纪律落点：这里只做 next 跳转，不写任何
## GameData/flag/phase——选项无持久后果由结构保证（分支尾巴无动作字段可执行）。
func _on_choice_selected(index: int) -> void:
	if state != State.WAITING_CHOICE:
		return
	var pick: Dictionary = _pending_choices[clampi(index, 0, _pending_choices.size() - 1)]
	_pending_choices = []
	state = State.PLAYING
	if _dialogue_box != null and _dialogue_box.has_method("close_choices"):
		_dialogue_box.close_choices()
	# 选项 next 必填（校验器保证）；"END" 兜底仅为防御，正常不可达
	var next_id: String = String(pick.get("next", "END"))
	if next_id == "END":
		_finish_dialogue()
	else:
		_enter_entry(next_id)
	print("[DialogueRunner] 选项已选 #%d → %s（仅影响当句）" % [index, next_id])


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
	_clear_runtime()


## 运行时簿记清零（正常收束与强制收束共用）
func _clear_runtime() -> void:
	current_event_id = ""
	_entries = {}
	_current_entry_id = ""
	_pending_choices = []
	_char_shown = 0
	_char_accumulator = 0.0
	_text_completed = false


# ------------------------------------------------------------------
# 测试注入口
# ------------------------------------------------------------------

## 直接注入"按键按下"事件（headless 断言的推进通道；生产路径 = _unhandled_input
## 收真实 InputEventKey，InputEventAction 走同一 is_action_pressed 判定，语义等价）
func inject_interact_press() -> void:
	_inject_action("interact")


## 注入任意注册动作（选项光标移动 move_up/move_down 的测试通道，边缘 4 断言用）
func inject_action_press(action: String) -> void:
	_inject_action(action)


func _inject_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	_unhandled_input(ev)
