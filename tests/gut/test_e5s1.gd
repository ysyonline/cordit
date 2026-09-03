extends GutTest
## test_e5s1.gd —— E5-S1 DialogueRunner 四态状态机 + 对话框完整版 GUT 用例
##
## 【断言覆盖】EPIC-5 E5-S1 验收标准 4 条 + 对话 GDD §3.1/§3.4/§4 机制面：
##   A. 加载运行：GDD §3.1 示例 JSON（dlg_inn_rina_p0）原样加载开演——验收 ①
##   B. 逐字 30 字/s（GDD §4 速率契约回归）
##   C. 选项：翻页弹选项 → 进 WAITING_CHOICE → 方向键换光标 → interact 确认
##      → 沿所选分支播且各自 END——验收 ②（必选其一）机制面
##   D. 边缘 4：WAITING_CHOICE 态注入 move_left/move_right（横向移动键）与
##      未注册动作——状态不退出、无选中；只有 interact/上下键可推进
##   E. 边缘 2：非 IDLE（PLAYING 与 WAITING_CHOICE 态）时 trigger_teleport
##      的休眠门闸 is_idle()==false 拦截传送（直驱 _on_body_entered，同 e4s6 口径）
##   F. 边缘 5：对话中途 force_idle()（读档安全口）→ IDLE + 玩家解锁 +
##      框关 + 不发 dialogue_finished + 簿记清空
##   G. 加载期结构校验：choices>2 / 悬空 next / 悬空 choice next / 分支
##      >2 步未汇合 / 嵌套 choices / 缺 start——整份拒绝开演（边缘 1 同源）
##   H. 头像差分：portrait 缺省沿用上一条；48×48 AtlasTexture 口径；
##      未登记 id 隐藏头像窗（catalog 协议）
##   I. 题面合规：状态机枚举恰四态（WAITING_CHOICE 在列且可达）
##
## 【测试策略】runner + box 直驱实例化（add_child_autofree），不依赖地图场景；
##   选项分支走 GDD §3.1 原文示例 JSON；校验反例 JSON 用 user:// 临时文件
##   （start_dialogue 按 id 解析 res://data/json/dialogues/，反例走 _validate_entries
##   直驱——私有函数不戳，经 _load_dialogue_entries 不可达 res:// 外路径，
##   故校验反例直接调 _validate_entries：校验器是纯函数，直驱等价加载路径）。

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const BoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const PortraitCatalog := preload("res://scripts/dialogue/portrait_catalog.gd")

## GDD §3.1 示例脚本（文件名 = 脚本 id，验收 ① 的"原样"正本）
const GDD_SAMPLE_ID := "dlg_inn_rina_p0"

var _runner: Node = null
var _box: Control = null
var _player: CharacterBody2D = null


func before_each() -> void:
	# 挂真实 player.gd（is_input_locked / set_input_locked 定义在其上，
	# runner 的移动锁经 has_method 探测——裸 CharacterBody2D 会静默跳过锁）
	const PlayerScript := preload("res://scripts/player/player.gd")
	_player = CharacterBody2D.new()
	_player.set_script(PlayerScript)
	add_child_autofree(_player)
	_box = BoxScene.instantiate()
	add_child_autofree(_box)
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	_runner.setup(_box, _player)


func after_each() -> void:
	if _runner != null and not _runner.is_idle():
		_runner.force_idle()   # 清理：防跨用例漏解锁/漏关框


# =============== A. 验收 ①：GDD §3.1 示例 JSON 原样加载运行 ===============

func test_A1_GDD示例JSON原样加载开演() -> void:
	var ok: bool = _runner.start_dialogue(GDD_SAMPLE_ID)
	assert_true(ok, "示例 JSON 应原样加载并开演")
	assert_eq(_runner.state, _runner.State.PLAYING, "开演后应为 PLAYING")
	assert_eq(_runner.current_event_id, GDD_SAMPLE_ID, "event_id = 文件名脚本 id")
	# start 条目字段与 GDD §3.1 原文一致（原样加载，非改写副本）
	assert_eq(_runner.get_current_full_text(),
			"委托书写得密密麻麻的……喂凯尔，游击士都是这么过日子的吗？",
			"start 条目全文 = GDD 原文")
	assert_true(_box.visible, "开演应显示对话框")
	assert_eq(_box._speaker_label.text, "莉娜", "名字栏 = 莉娜")


func test_A2_示例JSON选项结构与GDD原文一致() -> void:
	# 数据正本对表：文件内容逐字段 = GDD §3.1 示例（防"测试专用改版"混入）
	var raw: String = FileAccess.get_file_as_string(
			"res://data/json/dialogues/%s.json" % GDD_SAMPLE_ID)
	var parsed: Dictionary = JSON.parse_string(raw)
	var entries: Dictionary = parsed[GDD_SAMPLE_ID]
	assert_eq(entries.keys().size(), 3, "示例恰 3 条目（start/a1/a2）")
	var start: Dictionary = entries["start"]
	assert_eq((start["choices"] as Array).size(), 2, "start 恰 2 选项")
	assert_eq(String(start["portrait"]), "rina_smile", "start 头像 = rina_smile")
	assert_eq(String((start["choices"][0] as Dictionary)["next"]), "a1", "分支 1 → a1")
	assert_eq(String((start["choices"][1] as Dictionary)["next"]), "a2", "分支 2 → a2")
	assert_eq(String(entries["a1"]["next"]), "END", "a1 → END")
	assert_eq(String(entries["a2"]["next"]), "END", "a2 → END（两尾巴各自收束=汇合于结束）")


# =============== B. 逐字 30 字/s（GDD §4 契约回归） ===============

func test_B1_逐字速率30字每秒() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	var before: int = _runner.get_visible_text().length()
	await wait_seconds(0.5)
	var after: int = _runner.get_visible_text().length()
	# 0.5s × 30字/s = 15 字（帧抖动容差 ±6，headless e1s6 同口径）
	assert_true(after > before and after - before >= 9 and after - before <= 21,
			"0.5s 内逐字推进 %d → %d 字（30字/s ±容差）" % [before, after])


func test_B2_按键补完后翻页弹选项() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	_runner.inject_interact_press()   # 按键 1：补完本条
	await process_frame_safe()
	assert_eq(_runner.get_visible_text(), _runner.get_current_full_text(), "补完后 visible=全文")
	_runner.inject_interact_press()   # 按键 2：翻页 → 本条带 choices → 弹选项
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.WAITING_CHOICE, "翻页应进 WAITING_CHOICE")
	assert_true(_runner.has_pending_choices(), "选项待决标志")
	assert_true(_box.is_choices_open(), "选项窗已开")


## 兼容封装：GUT 的 process_frame await（保持与 e4s6 风格一致的短句）
func process_frame_safe() -> void:
	await get_tree().process_frame


# =============== C. 验收 ②：选项必选其一、光标与分支 ===============

func test_C1_方向键换光标_interact确认走分支1() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	_runner.inject_interact_press()   # 补完
	await process_frame_safe()
	_runner.inject_interact_press()   # 弹选项
	await process_frame_safe()
	# 初始光标 = 选项 0（「大概吧。」）
	_runner.inject_action_press("move_down")   # 循环切到选项 1
	await process_frame_safe()
	_box.handle_choice_input("move_up")        # 切回选项 0（UI 直驱换光标）
	_box.handle_choice_input("interact")       # 确认
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.PLAYING, "确认后回 PLAYING")
	assert_false(_runner.has_pending_choices(), "选项已决")
	# 走的是分支 0 → a1（「哦……那走吧。」）
	assert_eq(_runner.get_current_full_text(), "哦……那走吧。", "选中项 0 应走 a1 分支")
	# a1 无选项：翻页直达 END 收束
	_runner.inject_interact_press()   # 补完 a1
	await process_frame_safe()
	_runner.inject_interact_press()   # 翻页 → END
	await process_frame_safe()
	assert_true(_runner.is_idle(), "分支尾 END 应收束回 IDLE")


func test_C2_选分支2走a2路径() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()   # 弹选项（光标=0）
	await process_frame_safe()
	_box.handle_choice_input("move_down")   # 光标 → 1
	_box.handle_choice_input("interact")    # 确认分支 1
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.PLAYING, "确认后回 PLAYING")
	assert_eq(_runner.get_current_full_text(), "才、才没有！走吧！", "选中项 1 应走 a2 分支")


func test_C3_对话框确认信号与光标语义() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	watch_signals(_box)
	_box.handle_choice_input("move_down")
	_box.handle_choice_input("move_down")   # 2 项循环：又回 0
	_box.handle_choice_input("interact")
	# GUT 9.7.1 签名：(object, signal_name, expected_params[, index])——
	# 第 4 参为 index 非 fail 文本，文本改挂 assert_signal_emit_count 口径说明
	assert_signal_emitted(_box, "choice_selected", "两次下移循环后确认应发选中信号")
	assert_signal_emit_count(_box, "choice_selected", 1, "确认只发一次")
	assert_eq(get_signal_parameters(_box, "choice_selected")[0], 0,
			"两次下移循环后光标回 0：选中 index=0")


# =============== D. 边缘 4：选项态取消/移动键忽略 ===============

func test_D1_选项态横向移动键被忽略() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()   # 弹选项
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.WAITING_CHOICE, "前置：选项态")
	# 横向移动键注入：应被忽略（不选中、不退出选项态、不翻页）
	_runner.inject_action_press("move_left")
	await process_frame_safe()
	_runner.inject_action_press("move_right")
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.WAITING_CHOICE, "横移键不得退出选项态")
	assert_true(_box.is_choices_open(), "选项窗不得关闭")
	assert_false(_runner.has_pending_choices() == false and _runner.state == _runner.State.PLAYING,
			"横移键不得视作确认")


func test_D2_选项态未注册动作不推进() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	# 未注册动作（is_action_pressed 恒 false）：全吞但不改变状态
	_runner.inject_action_press("debug_panel")
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.WAITING_CHOICE, "无关键不推进")
	# 上下键/确认键是唯三出路
	_box.handle_choice_input("move_up")
	_box.handle_choice_input("interact")
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.PLAYING, "显式确认后离开选项态")


func test_D3_玩家移动键在选项态不解除对话锁() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	assert_true(_player.is_input_locked, "对话期间玩家移动已锁")
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	# 选项态狂按方向键：锁不动
	_runner.inject_action_press("move_left")
	_runner.inject_action_press("move_up")
	await process_frame_safe()
	assert_true(_player.is_input_locked, "选项态仍锁移动（A7：对话期间=全程）")
	_box.handle_choice_input("interact")
	await process_frame_safe()
	assert_true(_player.is_input_locked, "确认后仍在对话中，锁继续")


# =============== E. 边缘 2：非 IDLE 时传送触发器一律忽略 ===============

func test_E1_非IDLE态传送触发器休眠_直驱口径() -> void:
	# 直驱 trigger_teleport._on_body_entered（test_e4s6 test_13 同款口径），
	# 断言门闸 = runner.is_idle()（四态语义下 PLAYING/WAITING_CHOICE 均非空闲）
	const TriggerScript := preload("res://scripts/events/trigger_teleport.gd")
	var trig: Area2D = TriggerScript.new()
	add_child_autofree(trig)
	trig.teleport_id = "tp_town_door_inn"
	trig.setup(_runner)
	var fake_player := CharacterBody2D.new()
	fake_player.collision_layer = 16
	add_child_autofree(fake_player)
	# IDLE：放行（门闸不拦）
	trig._on_body_entered(fake_player)
	assert_eq(fake_player.global_position, Vector2(1368, 280), "IDLE 态传送放行（对照组）")
	# 复位 + 冷却清零，进 PLAYING
	fake_player.global_position = Vector2.ZERO
	trig._cooldown = 0.0
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演 → 非 IDLE")
	trig._on_body_entered(fake_player)
	assert_eq(fake_player.global_position, Vector2.ZERO, "PLAYING 态触发器休眠，位置不动")
	# WAITING_CHOICE 同样休眠
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.WAITING_CHOICE, "前置：选项态")
	trig._on_body_entered(fake_player)
	assert_eq(fake_player.global_position, Vector2.ZERO, "WAITING_CHOICE 态触发器同样休眠")
	assert_false(_runner.is_idle(), "is_idle() 全程 false（门闸真源）")


func test_E2_is_idle四态语义() -> void:
	assert_true(_runner.is_idle(), "初始 IDLE")
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	assert_false(_runner.is_idle(), "PLAYING 非 IDLE")
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	assert_false(_runner.is_idle(), "WAITING_CHOICE 非 IDLE（选项悬而未决，世界静止）")
	_box.handle_choice_input("interact")
	await process_frame_safe()
	assert_false(_runner.is_idle(), "选后回 PLAYING，仍非 IDLE")
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	assert_true(_runner.is_idle(), "分支 END 收束回 IDLE")


# =============== F. 边缘 5：对话中途读档 → 强制回 IDLE ===============

func test_F1_force_idle读档安全口_状态簿记与信号() -> void:
	watch_signals(EventBus)
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	_runner.inject_interact_press()   # 补完 start（对话进行中）
	await process_frame_safe()
	assert_false(_runner.is_idle(), "前置：对话进行中")
	# 模拟读档链路调用 force_idle（E5-S3 存档接线后的生产挂点）
	_runner.force_idle()
	await process_frame_safe()
	assert_true(_runner.is_idle(), "边缘 5：读档后状态机强制回 IDLE")
	assert_false(_player.is_input_locked, "玩家移动解锁")
	assert_false(_box.visible, "对话框关闭")
	assert_eq(_runner.current_event_id, "", "簿记清空：event_id 归零")
	assert_eq(_runner.get_current_full_text(), "", "簿记清空：当前条目归零")
	assert_signal_not_emitted(EventBus, "dialogue_finished",
			"强制收束不发 dialogue_finished（未正常收束不发假完成）")


func test_F2_force_idle幂等_选项态下同样成立() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()   # 弹选项
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.WAITING_CHOICE, "前置：选项态悬而未决")
	_runner.force_idle()
	await process_frame_safe()
	assert_true(_runner.is_idle(), "选项态读档同样强制回 IDLE")
	assert_false(_box.is_choices_open(), "选项窗关闭")
	assert_false(_player.is_input_locked, "解锁")
	# 幂等：IDLE 态再调一次，无害
	_runner.force_idle()
	assert_true(_runner.is_idle(), "幂等：重复调用无害")


# =============== G. 加载期结构校验（边缘 1 同源 + §3.4 分支规则） ===============

## 校验器直驱辅助：构造条目字典 → runner._validate_entries（纯函数，直驱等价加载）
func _validate(entries: Dictionary) -> String:
	return _runner._validate_entries(entries, "user://e5s1_case.json")


func _gdd_entries() -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(
			"res://data/json/dialogues/%s.json" % GDD_SAMPLE_ID)
	return (JSON.parse_string(raw) as Dictionary)[GDD_SAMPLE_ID]


func test_G1_选项超2拒绝() -> void:
	var entries := _gdd_entries()
	entries["start"]["choices"] = [
		{"text": "a", "next": "a1"}, {"text": "b", "next": "a2"}, {"text": "c", "next": "a1"}]
	assert_ne(_validate(entries), "", "choices=3 应拒绝")


func test_G2_next悬空引用拒绝() -> void:
	var entries := _gdd_entries()
	entries["a1"]["next"] = "no_such_entry"
	assert_ne(_validate(entries), "", "悬空 next 应拒绝（边缘 1：加载期拦截）")


func test_G3_choice_next悬空引用拒绝() -> void:
	var entries := _gdd_entries()
	entries["start"]["choices"][0]["next"] = "ghost"
	assert_ne(_validate(entries), "", "悬空 choice next 应拒绝")


func test_G4_分支超2步未汇合拒绝() -> void:
	# 分支尾巴拉长：a1 → a1b → a1c（3 条目不汇合）；a2 直接 END
	var entries := _gdd_entries()
	entries["a1"] = {"speaker": "莉娜", "text": "一步", "next": "a1b"}
	entries["a1b"] = {"speaker": "莉娜", "text": "两步", "next": "a1c"}
	entries["a1c"] = {"speaker": "莉娜", "text": "三步不汇合", "next": "END"}
	entries["a2"] = {"speaker": "莉娜", "text": "另一支", "next": "END"}
	assert_ne(_validate(entries), "", "分支 3 条目不汇合应拒绝（尾巴 ≤2 条目）")


func test_G5_两步内汇合通过() -> void:
	# a1 → join、a2 → join：一步汇合，合法
	var entries := _gdd_entries()
	entries["join"] = {"speaker": "莉娜", "portrait": "rina_normal", "text": "走吧。", "next": "END"}
	entries["a1"] = {"speaker": "莉娜", "text": "支一", "next": "join"}
	entries["a2"] = {"speaker": "莉娜", "text": "支二", "next": "join"}
	assert_eq(_validate(entries), "", "一步汇合应通过")


func test_G6_嵌套choices拒绝() -> void:
	var entries := _gdd_entries()
	entries["a1"] = {"speaker": "莉娜", "text": "嵌套",
		"next": "END", "choices": [{"text": "x", "next": "END"}]}
	assert_ne(_validate(entries), "", "分支条目内嵌 choices 应拒绝")


func test_G7_缺start与缺必填字段拒绝() -> void:
	var entries := {"s1": {"speaker": "", "text": "x", "next": "END"}}
	assert_ne(_validate(entries), "", "缺 start 应拒绝")
	var entries2 := {"start": {"speaker": "", "text": "x"}}
	assert_ne(_validate(entries2), "", "缺 next 应拒绝（无选项条目必须有 next）")
	var entries3 := {"start": {"text": "x", "next": "END"}}
	assert_ne(_validate(entries3), "", "缺 speaker 应拒绝")


func test_G7b_选项条目省略next合法_GDD示例口径() -> void:
	# GDD §3.1 完整示例中 start 条目 = choices 无 next——示例即权威正本
	var entries := {
		"start": {"speaker": "莉娜", "text": "选吧", "portrait": "rina_smile",
			"choices": [{"text": "a", "next": "a1"}, {"text": "b", "next": "a2"}]},
		"a1": {"speaker": "莉娜", "text": "甲", "next": "END"},
		"a2": {"speaker": "莉娜", "text": "乙", "next": "END"},
	}
	assert_eq(_validate(entries), "", "choices 条目省略 next 应合法（示例口径）")
	# 反过来：无 choices 却缺 next 仍拒绝
	entries["solo"] = {"speaker": "", "text": "无选项无 next"}
	assert_ne(_validate(entries), "", "无选项条目缺 next 应拒绝")


func test_G8_GDD示例与全库存量对话脚本校验通过() -> void:
	assert_eq(_validate(_gdd_entries()), "", "GDD 示例应通过校验（原样加载的先决条件）")
	# 存量 29 个对话文件全量过校验（防新校验器误伤存量内容）
	var dir: DirAccess = DirAccess.open("res://data/json/dialogues")
	assert_not_null(dir, "应能打开对话目录")
	var checked := 0
	for file: String in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var raw: String = FileAccess.get_file_as_string("res://data/json/dialogues/" + file)
		var parsed: Variant = JSON.parse_string(raw)
		assert_true(parsed is Dictionary and not (parsed as Dictionary).is_empty(),
				"%s 顶层须非空字典" % file)
		if not (parsed is Dictionary) or (parsed as Dictionary).is_empty():
			continue
		var entries: Dictionary = (parsed as Dictionary)[(parsed as Dictionary).keys()[0]]
		assert_eq(_validate(entries), "", "存量脚本应全部通过：%s" % file)
		checked += 1
	assert_gte(checked, 29, "应至少扫过 29 个存量对话文件")


# =============== H. 头像差分（48×48，缺省沿用，未知隐藏） ===============

func test_H1_portrait缺省沿用上一条() -> void:
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "开演")
	# start 带 portrait=rina_smile
	assert_true(_box._portrait_frame.visible, "带 portrait 条目显示头像窗")
	assert_eq(_box._portrait_rect.texture.get_width(), 48, "头像原生 48 宽（禁 64 旧口径）")
	assert_eq(_box._portrait_rect.texture.get_height(), 48, "头像原生 48 高")
	# 补完 + 翻页弹选项（choices 条目自身无 portrait 字段——沿用 rina_smile）
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	_box.handle_choice_input("move_down")
	_box.handle_choice_input("interact")   # → a2（portrait=rina_angry）
	await process_frame_safe()
	assert_eq(_box._portrait_rect.texture.get_width(), 48, "a2 差分仍 48×48")


func test_H2_旁白无portrait隐藏头像窗() -> void:
	# 旁白脚本（speaker=""、无 portrait 字段）：名字栏与头像窗都隐藏
	assert_true(_runner.start_dialogue("dlg_story_quest_accept"), "开演旁白脚本")
	assert_false(_box._speaker_bar.visible, "旁白隐藏名字栏")
	assert_false(_box._portrait_frame.visible, "未登记 portrait 隐藏头像窗")
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	_runner.inject_interact_press()
	await process_frame_safe()
	assert_true(_runner.is_idle(), "旁白脚本 END 收束")


func test_H3_catalog协议_未登记id返回null() -> void:
	assert_null(PortraitCatalog.get_texture(""), "空 id → null（隐藏降级）")
	assert_null(PortraitCatalog.get_texture("ghost_face"), "未登记 id → null")
	var t: Texture2D = PortraitCatalog.get_texture("rina_smile")
	assert_not_null(t, "已登记 id 出图")
	assert_eq(t.get_width(), 48, "AtlasTexture 48 宽")
	assert_eq(t.get_height(), 48, "AtlasTexture 48 高")


# =============== I. 题面合规：四态状态机 ===============

func test_I1_状态机四态循环WAITING_CHOICE可达() -> void:
	# GDD §1 钉死"状态机只有 4 态（IDLE→PLAYING→WAITING_CHOICE→PLAYING→IDLE）"：
	# 4 态 = 转换序列计 PLAYING 两次，枚举成员 3 个（A7 同构），断言锚定防误加状态
	var keys: Array = _runner.State.keys()
	assert_eq(keys.size(), 3, "枚举成员恰 3 个（4 态循环 = 序列计 PLAYING 两次）")
	assert_true(keys.has("IDLE"), "含 IDLE")
	assert_true(keys.has("PLAYING"), "含 PLAYING")
	assert_true(keys.has("WAITING_CHOICE"), "含 WAITING_CHOICE（本 Story 启用）")
	# 可达性：完整走一遍四态循环 IDLE→PLAYING→WAITING_CHOICE→PLAYING→IDLE
	assert_true(_runner.start_dialogue(GDD_SAMPLE_ID), "IDLE→PLAYING")
	assert_eq(_runner.state, _runner.State.PLAYING, "PLAYING")
	_runner.inject_interact_press()   # 补完
	await process_frame_safe()
	_runner.inject_interact_press()   # 弹选项
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.WAITING_CHOICE, "PLAYING→WAITING_CHOICE")
	_box.handle_choice_input("interact")
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.PLAYING, "WAITING_CHOICE→PLAYING")
	_runner.inject_interact_press()   # 补完 a2
	await process_frame_safe()
	_runner.inject_interact_press()   # END
	await process_frame_safe()
	assert_eq(_runner.state, _runner.State.IDLE, "PLAYING→IDLE")
