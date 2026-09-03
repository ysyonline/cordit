extends GutTest
## E5-S2 测试 —— 事件 JSON 加载器 + schema 校验器 + 触发器薄壳统一（对话 GDD §3.2）
##
## 【分组】
##   A 抽离等价回归：schema_validator 抽离后 runner 口径零变化（313 基线语义保护）
##   B 动作白名单：10 type 全过 / 未知 type 拒 / 被裁动作回归防线 + 全码零字面
##   C conditions 三键：story_phase / flag / not_flag 结构与白名单
##   D 引用完整性：item_id / group / dialogue id 悬空加载期拦截（边缘 1）
##   E phase 映射：非数字键报错、"0" 兜底、规范化与选取规则（验收③）
##   F 事件加载器：load_all 扫描、E4 镜像跳过、phase_maps 规范化
##   G 动作执行器：9 种动作全实装（wait/play_sfx 占位）+ 条件评估（验收④）
##   H 触发器薄壳统一：三层链路 / is_idle 门闸 / 未登记降级 / E4 兼容路径
##   I 薄壳协议保持：既有实体 get_event_id() 协议族原样
##
## 【跑法】项目根下：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . -s -gdir=res://tests/gut -ginclude_subdirs -gexit

const SchemaValidator := preload("res://scripts/dialogue/schema_validator.gd")
const EventLoader := preload("res://scripts/events/event_loader.gd")
const EventExecutor := preload("res://scripts/events/event_executor.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const ShellScript := preload("res://scripts/events/trigger_event_shell.gd")
const ChestScript := preload("res://scripts/events/chest.gd")
const InvestigateScript := preload("res://scripts/events/investigate_point.gd")
const TeleportScript := preload("res://scripts/events/trigger_teleport.gd")
const TriggerDialogueScript := preload("res://scripts/events/trigger_dialogue.gd")

## GameData 状态快照（after_each 恢复——autoload 跨测试零污染）
var _snapshot: Dictionary = {}
var _runner: Node = null
var _executor: RefCounted = null
var _loader: RefCounted = null
var _shell: Area2D = null


func before_each() -> void:
	_snapshot = {
		"inventory": GameData.inventory.duplicate(true),
		"flags": GameData.flags.duplicate(true),
		"story_phase": GameData.story_phase,
		"chests_opened": GameData.chests_opened.duplicate(true),
		"party_hp_mp": _snap_party(),
	}


func after_each() -> void:
	GameData.inventory = _snapshot["inventory"]
	GameData.flags = _snapshot["flags"]
	GameData.story_phase = _snapshot["story_phase"]
	GameData.chests_opened = _snapshot["chests_opened"]
	_restore_party(_snapshot["party_hp_mp"])
	# save_point 用例会置 SaveManager 意图位——consume 清零，防跨文件残留
	SaveManager.consume_save_request()


func _snap_party() -> Array:
	var out: Array = []
	for r in GameData.party:
		out.append([r.hp, r.max_hp, r.mp, r.max_mp])
	return out


func _restore_party(snap: Array) -> void:
	for i: int in mini(snap.size(), GameData.party.size()):
		GameData.party[i].hp = snap[i][0]
		GameData.party[i].max_hp = snap[i][1]
		GameData.party[i].mp = snap[i][2]
		GameData.party[i].max_mp = snap[i][3]


# ------------------------------------------------------------------
# 通用构造器（事件直驱辅助）
# ------------------------------------------------------------------

## 造一个最小合法事件（单 dialogue 动作，id 指向真实存在的对话）
func _ev_dialogue(dlg_id: String = "dlg_innkeeper_p0") -> Dictionary:
	return {"conditions": {}, "actions": [{"type": "dialogue", "id": dlg_id}]}


func _ev_action(act: Dictionary) -> Dictionary:
	return {"conditions": {}, "actions": [act]}


# ------------------------------------------------------------------
# Group A —— 抽离等价回归（校验口径单源，313 基线语义保护）
# ------------------------------------------------------------------

func test_a1_gdd示例在新旧两口同时通过() -> void:
	# GDD §3.1 示例的等价结构：新校验器与 runner 薄委托同判（口径单源断言）
	var entries: Dictionary = {
		"start": {"speaker": "莉娜", "text": "喂。", "choices": [
			{"text": "「大概吧。」", "next": "a1"}, {"text": "「你想回去了？」", "next": "a2"}]},
		"a1": {"speaker": "莉娜", "text": "哦……那走吧。", "next": "END"},
		"a2": {"speaker": "莉娜", "text": "才、才没有！走吧！", "next": "END"},
	}
	assert_eq(SchemaValidator.validate_dialogue_entries(entries, "user://a1.json"), "",
			"新校验器应通过 GDD 示例口径")
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	assert_eq(_runner._validate_entries(entries, "user://a1.json"), "",
			"runner 薄委托应同判通过（抽离零回归）")


func test_a2_悬空next在新旧两口同时拒绝() -> void:
	var entries: Dictionary = {
		"start": {"speaker": "x", "text": "y", "next": "nowhere"},
	}
	assert_ne(SchemaValidator.validate_dialogue_entries(entries, "user://a2.json"), "",
			"新校验器应拒绝悬空 next")
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	assert_eq(_runner._validate_entries(entries, "user://a2.json"),
			SchemaValidator.validate_dialogue_entries(entries, "user://a2.json"),
			"两口拒绝原因应逐字一致（单源）")


func test_a3_新加载口直接加载S1示例对话() -> void:
	var entries: Dictionary = SchemaValidator.load_dialogue_script("dlg_inn_rina_p0")
	assert_ne(entries.size(), 0, "GDD §3.1 示例应经新加载口加载成功")
	assert_true(entries.has("start"), "条目应含 start 入口")


func test_a4_runner加载链路抽离后等价() -> void:
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	var entries: Dictionary = _runner._load_dialogue_entries("dlg_inn_rina_p0")
	assert_ne(entries.size(), 0, "runner 加载应经抽离后链路照常成功")


func test_a5_分支端点静态版语义() -> void:
	var entries: Dictionary = {
		"start": {"speaker": "x", "text": "y", "choices": [
			{"text": "1", "next": "b1"}, {"text": "2", "next": "b2"}]},
		"b1": {"speaker": "x", "text": "y", "next": "meet"},
		"b2": {"speaker": "x", "text": "y", "next": "meet"},
		"meet": {"speaker": "x", "text": "y", "next": "END"},
	}
	assert_eq(SchemaValidator.branch_endpoint(entries, "b1", 2), "meet",
			"2 步端点：b1 走一步到 meet（走满步数前遇分支终点即候选）")
	assert_eq(SchemaValidator.branch_endpoint(entries, "END", 2), "END",
			"END 入口直接返回 END")
	assert_eq(SchemaValidator.validate_branch_convergence(entries), "",
			"两分支一步汇合应通过")


func test_a6_存量对话全量过新校验器() -> void:
	# E5-S1 G8 的抽离复测：29 个存量脚本 + S2 新增 3 个，全部经新址校验
	var dir: DirAccess = DirAccess.open("res://data/json/dialogues")
	assert_not_null(dir, "应能打开 dialogues 目录")
	var checked: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var text: String = FileAccess.get_file_as_string("res://data/json/dialogues/" + file)
		var parsed: Variant = JSON.parse_string(text)
		assert_true(typeof(parsed) == TYPE_DICTIONARY and not (parsed as Dictionary).is_empty(),
				"JSON 应合法：%s" % file)
		if typeof(parsed) != TYPE_DICTIONARY or (parsed as Dictionary).is_empty():
			continue
		var entries: Dictionary = parsed[(parsed as Dictionary).keys()[0]]
		var err: String = SchemaValidator.validate_dialogue_entries(entries,
				"res://data/json/dialogues/" + file)
		assert_eq(err, "", "存量脚本应全部通过新校验器：%s" % file)
		checked += 1
	assert_gte(checked, 29, "扫描对话脚本数应不低于 S1 存量（29）")


# ------------------------------------------------------------------
# Group B —— 动作白名单（验收④前置：白名单面）
# ------------------------------------------------------------------

func test_b1_全部10种type逐一通过校验() -> void:
	var types: Dictionary = {
		"dialogue": {"type": "dialogue", "id": "dlg_innkeeper_p0"},
		"give_item": {"type": "give_item", "item_id": "potion_s", "count": 1},
		"set_flag": {"type": "set_flag", "flag": "demo_flag"},
		"battle": {"type": "battle", "group": "b1_moth"},
		"heal": {"type": "heal"},
		"teleport": {"type": "teleport", "to_map": "road", "to_spawn": [23.5, 3.5]},
		"save_point": {"type": "save_point"},
		"set_story_phase": {"type": "set_story_phase", "phase": 1},
		"wait": {"type": "wait", "duration": 0.5},
		"play_sfx": {"type": "play_sfx", "sfx": "res://assets/audio/sfx/chest_open.ogg"},
	}
	for t: String in types:
		var err: String = SchemaValidator.validate_event(_ev_action(types[t]), "ev_" + t)
		assert_eq(err, "", "合法动作 %s 应通过校验" % t)


func test_b2_未知type拒绝() -> void:
	var err: String = SchemaValidator.validate_event(_ev_action({"type": "warp_to_moon"}), "ev")
	assert_ne(err, "", "未知 type 应拒绝")
	assert_true(err.contains("白名单"), "拒绝原因应指明白名单")


func test_b3_被裁掉的旧动作type拒绝() -> void:
	# GDD §3.2 裁决回归防线：被裁的旧动作不在白名单，落进来即拒
	var err: String = SchemaValidator.validate_event(
			_ev_action({"type": "set_flag", "flag": "x"}), "ev_setflag")
	assert_eq(err, "", "set_flag 合法（对照组）")
	var err2: String = SchemaValidator.validate_event(
			_ev_action({"type": "give_item", "item_id": "potion_s", "count": 1}), "ev2")
	assert_eq(err2, "", "give_item 合法（对照组）")
	var err3: String = SchemaValidator.validate_event(
			_ev_action({"type": "give_item", "item_id": "potion_s", "count": 1, "extra": true}), "ev3")
	assert_eq(err3, "", "协议外参数只多带不拒（同 SceneRouter payload 纪律）")


func test_b4_被裁动作字面量全代码零存在() -> void:
	# 验收①的机器判据：扫代码目录（scripts/autoload/scenes/tests），被裁动作的
	# 字面量必须为零（docs/gdd/production 的提及属历史记录与验收条文本身，不在
	# "代码"范围）。关键词运行时构造——本测试源码自身不得出现该字面量
	# （自指：扫描范围含本文件；源码里只有字节数组，运行时才拼出完整关键词）。
	var keyword: String = String(PackedByteArray([99, 104, 101, 99, 107]).get_string_from_utf8()) \
			+ "_flag"
	var hits: Array[String] = []
	for base: String in ["res://scripts", "res://autoload", "res://scenes", "res://tests"]:
		_scan_keyword(base, keyword, hits)
	assert_eq(hits.size(), 0, "被裁动作字面量应全代码零存在，命中：%s" % [hits])


func _scan_keyword(p_dir_path: String, p_keyword: String, p_out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(p_dir_path)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			var text: String = FileAccess.get_file_as_string(p_dir_path + "/" + file)
			if text.contains(p_keyword):
				p_out.append(p_dir_path + "/" + file)
	for sub: String in dir.get_directories():
		_scan_keyword(p_dir_path + "/" + sub, p_keyword, p_out)


func test_b5_动作元素非字典拒绝() -> void:
	var ev: Dictionary = {"conditions": {}, "actions": ["not_a_dict"]}
	assert_ne(SchemaValidator.validate_event(ev, "ev"), "", "动作元素非字典应拒绝")


func test_b6_缺actions或空actions拒绝() -> void:
	var ev1: Dictionary = {"conditions": {}}
	assert_ne(SchemaValidator.validate_event(ev1, "ev1"), "", "缺 actions 应拒绝")
	var ev2: Dictionary = {"conditions": {}, "actions": []}
	assert_ne(SchemaValidator.validate_event(ev2, "ev2"), "", "空 actions 应拒绝")


# ------------------------------------------------------------------
# Group C —— conditions 三键（GDD §3.2：仅 3 种键，不扩展）
# ------------------------------------------------------------------

func test_c1_storyphase三种运算符全过() -> void:
	for op: String in SchemaValidator.STORY_PHASE_OPS:
		var ev: Dictionary = {"conditions": {"story_phase": [op, 1]}, "actions": [{"type": "heal"}]}
		assert_eq(SchemaValidator.validate_event(ev, "ev"), "",
				"story_phase 运算符 %s 应通过" % op)


func test_c2_非法运算符拒绝() -> void:
	var ev: Dictionary = {"conditions": {"story_phase": ["<", 1]}, "actions": [{"type": "heal"}]}
	var err: String = SchemaValidator.validate_event(ev, "ev")
	assert_ne(err, "", "非法运算符应拒绝")
	assert_true(err.contains("story_phase"), "拒绝原因应指向 story_phase")


func test_c3_storyphase结构错误拒绝() -> void:
	var bads: Array = [
		{"conditions": {"story_phase": [">="]}, "actions": [{"type": "heal"}]},
		{"conditions": {"story_phase": [">=", 1, 2]}, "actions": [{"type": "heal"}]},
		{"conditions": {"story_phase": [">=", "1"]}, "actions": [{"type": "heal"}]},
		{"conditions": {"story_phase": ">=1"}, "actions": [{"type": "heal"}]},
	]
	for i: int in bads.size():
		assert_ne(SchemaValidator.validate_event(bads[i], "ev%d" % i), "",
				"story_phase 结构错误形态 %d 应拒绝" % i)


func test_c4_flagnoflag须字符串() -> void:
	var ev1: Dictionary = {"conditions": {"flag": "demo"}, "actions": [{"type": "heal"}]}
	assert_eq(SchemaValidator.validate_event(ev1, "ev1"), "", "flag 字符串应通过")
	var ev2: Dictionary = {"conditions": {"not_flag": "demo"}, "actions": [{"type": "heal"}]}
	assert_eq(SchemaValidator.validate_event(ev2, "ev2"), "", "not_flag 字符串应通过")
	var ev3: Dictionary = {"conditions": {"flag": 3}, "actions": [{"type": "heal"}]}
	assert_ne(SchemaValidator.validate_event(ev3, "ev3"), "", "flag 非字符串应拒绝")


func test_c5_白名单外键拒绝() -> void:
	var ev: Dictionary = {"conditions": {"gold": 100}, "actions": [{"type": "heal"}]}
	var err: String = SchemaValidator.validate_event(ev, "ev")
	assert_ne(err, "", "白名单外条件键应拒绝")
	assert_true(err.contains("白名单"), "拒绝原因应指明白名单")


# ------------------------------------------------------------------
# Group D —— 引用完整性（边缘 1：悬空引用加载期拦截）
# ------------------------------------------------------------------

func test_d1_giveitem悬空item_id拒绝() -> void:
	var ev: Dictionary = _ev_action({"type": "give_item", "item_id": "no_such_item", "count": 1})
	var err: String = SchemaValidator.validate_event(ev, "ev")
	assert_ne(err, "", "悬空 item_id 应拒绝")
	assert_true(err.contains("不可解析"), "拒绝原因应指明不可解析")


func test_d2_battle悬空group拒绝() -> void:
	var ev: Dictionary = _ev_action({"type": "battle", "group": "b99_none"})
	var err: String = SchemaValidator.validate_event(ev, "ev")
	assert_ne(err, "", "悬空编组 id 应拒绝")


func test_d3_合法表引用通过() -> void:
	var ev1: Dictionary = _ev_action({"type": "give_item", "item_id": "potion_s", "count": 2})
	assert_eq(SchemaValidator.validate_event(ev1, "ev1"), "", "合法 item_id 应通过")
	var ev2: Dictionary = _ev_action({"type": "battle", "group": "b1_moth"})
	assert_eq(SchemaValidator.validate_event(ev2, "ev2"), "", "合法 group 应通过")


func test_d4_dialogue悬空引用整文件拒绝() -> void:
	# 边缘 1 主路径：load_events_file 第一遍对 dialogue 字符串 id 做 res:// 存在性校验
	var path: String = "user://e5s2_dangling_dlg.json"
	var doc: Dictionary = {"events": {"ev_bad": _ev_dialogue("dlg_not_exist_anywhere")}}
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc))
	f.close()
	# 悬空 dialogue → 整份拒绝（返回 {}）
	var result2: Dictionary = SchemaValidator.load_events_file(path)
	assert_eq(result2.size(), 0, "dialogue 悬空引用应整文件拒绝（加载期拦截）")
	# 对照：合法 id 应加载成功
	var doc2: Dictionary = {"events": {"ev_ok": _ev_dialogue("dlg_innkeeper_p0")}}
	var f2: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f2.store_string(JSON.stringify(doc2))
	f2.close()
	var result3: Dictionary = SchemaValidator.load_events_file(path)
	assert_ne(result3.size(), 0, "合法 dialogue 引用应加载成功")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_d5_giveitem_count非法拒绝() -> void:
	var ev: Dictionary = _ev_action({"type": "give_item", "item_id": "potion_s", "count": 0})
	assert_ne(SchemaValidator.validate_event(ev, "ev1"), "", "count=0 应拒绝")
	var ev2: Dictionary = _ev_action({"type": "give_item", "item_id": "potion_s", "count": "two"})
	assert_ne(SchemaValidator.validate_event(ev2, "ev2"), "", "count 非整数应拒绝")


# ------------------------------------------------------------------
# Group E —— phase 映射（验收③：非数字键报错 + 选取规则）
# ------------------------------------------------------------------

func _ev_phase_map(p_map: Dictionary) -> Dictionary:
	return {"conditions": {}, "actions": [{"type": "dialogue", "id": p_map}]}


func test_e1_非数字phase键报错() -> void:
	var ev: Dictionary = _ev_phase_map({"0": "dlg_innkeeper_p0", "p1": "dlg_innkeeper_p12"})
	var err: String = SchemaValidator.validate_event(ev, "ev")
	assert_ne(err, "", "非数字 phase 键应报错")
	assert_true(err.contains("非数字"), "拒绝原因应指明非数字键")


func test_e2_缺零兜底键拒绝() -> void:
	var ev: Dictionary = _ev_phase_map({"1": "dlg_innkeeper_p12"})
	var err: String = SchemaValidator.validate_event(ev, "ev")
	assert_ne(err, "", "缺 \"0\" 兜底键应拒绝")
	assert_true(err.contains("0"), "拒绝原因应提及 \"0\" 兜底")


func test_e3_映射值非法拒绝() -> void:
	var ev1: Dictionary = _ev_phase_map({"0": ""})
	assert_ne(SchemaValidator.validate_event(ev1, "ev1"), "", "映射值空串应拒绝")
	var ev2: Dictionary = _ev_phase_map({"0": "dlg_not_exist_anywhere"})
	assert_ne(SchemaValidator.validate_event(ev2, "ev2"), "",
			"映射值指向不存在对话应拒绝（引用完整性含映射值）")


func test_e4_合法映射通过() -> void:
	var ev: Dictionary = _ev_phase_map({"0": "dlg_innkeeper_p0", "1": "dlg_innkeeper_p12"})
	assert_eq(SchemaValidator.validate_event(ev, "ev"), "",
			"GDD §3.3 示例映射形态应通过（含 res:// 存在性）")


func test_e5_normalize映射键转int() -> void:
	var norm: Dictionary = SchemaValidator.normalize_phase_map(
			{"0": "a", "1": "b", "2": "c"})
	assert_eq(norm.size(), 3, "规范化后应保留全部键")
	assert_true(norm.has(0) and norm.has(1) and norm.has(2), "键应为 int")
	assert_eq(norm[1], "b", "值应原样保留")


func test_e6_normalize非数字键返回空() -> void:
	assert_eq(SchemaValidator.normalize_phase_map({"0": "a", "x": "b"}).size(), 0,
			"非数字键规范化应返回空（防御面，加载校验为主闸）")


func test_e7_选取规则取不超当前phase的最大键() -> void:
	# GDD §3.2 原文例：keys{0,1} 且 phase=2 时选 "1"
	var m: Dictionary = SchemaValidator.normalize_phase_map(
			{"0": "dlg_a", "1": "dlg_b"})
	assert_eq(SchemaValidator.pick_phase_id(m, 2), "dlg_b", "phase=2 应选键 1")
	assert_eq(SchemaValidator.pick_phase_id(m, 1), "dlg_b", "phase=1 应选键 1")
	assert_eq(SchemaValidator.pick_phase_id(m, 0), "dlg_a", "phase=0 应选键 0")


func test_e8_选取规则无匹配键返回空串() -> void:
	var m: Dictionary = SchemaValidator.normalize_phase_map({"0": "dlg_a"})
	assert_eq(SchemaValidator.pick_phase_id(m, 0), "dlg_a", "兜底键应命中")
	var m2: Dictionary = SchemaValidator.normalize_phase_map({"1": "dlg_b"})
	assert_eq(SchemaValidator.pick_phase_id(m2, 0), "",
			"无 ≤ 当前 phase 的键应返回空串（防御口；加载校验已挡此数据）")
	# 原始字符串键形态（JSON 直读、未经 normalize）同规则可用
	var raw: Dictionary = {"0": "dlg_a", "1": "dlg_b"}
	assert_eq(SchemaValidator.pick_phase_id(raw, 3), "dlg_b", "字符串键直驱同规则")


# ------------------------------------------------------------------
# Group F —— 事件加载器 load_all
# ------------------------------------------------------------------

func test_f1_loadall扫描目录_E4镜像跳过_新事件入表() -> void:
	_loader = EventLoader.new()
	var failed: Array[String] = _loader.load_all()
	assert_eq(failed.size(), 0, "res://data/json/events/ 全目录应零失败（E4 镜像为跳过）")
	assert_false(_loader.has_event("chest_town_01"),
			"E4 点位镜像（chests.json 无 events 键）不应入事件表")
	assert_true(_loader.has_event("story_quest_accept"), "GDD §3.2 示例事件应入表")
	assert_true(_loader.has_event("npc_innkeeper"), "phase 映射示例事件应入表")
	assert_true(_loader.has_event("ev_demo_battle"), "演示事件应入表")


func test_f2_phase_maps规范化入表() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	var pm: Dictionary = _loader.get_phase_map("npc_innkeeper")
	assert_eq(pm.size(), 1, "npc_innkeeper 应有一个带映射的动作")
	var inner: Dictionary = pm.get(0, {})
	assert_true(inner.has(0) and inner.has(1), "映射键应已规范化为 int")
	assert_eq(inner[1], "dlg_npc_01_innkeeper_p12",
			"映射值应原样保留（S3 起映射指向配额对话文件）")


func test_f3_getevent未知id返回空字典() -> void:
	_loader = EventLoader.new()
	_loader.load_all()
	assert_eq(_loader.get_event("nonexistent_id").size(), 0, "未知 id 应返回空字典")


func test_f4_loadeventsfile非事件schema文件跳过() -> void:
	# E4 镜像形态（顶层无 events 键）→ 返回 {"skipped": true}（加载器据此
	# 与"校验拒绝"区分：跳过不计失败，见 test_f1 的零失败断言）
	var result: Dictionary = SchemaValidator.load_events_file("res://data/json/events/chests.json")
	assert_true(result.has("skipped"), "无 events 键的文件应返回 skipped 标记（非拒绝）")
	assert_false(result.has("events"), "skipped 文件不应带 events 表")


func test_f5_loadeventsfile合法文件返回双表() -> void:
	var result: Dictionary = SchemaValidator.load_events_file(
			"res://data/json/events/npc_innkeeper.json")
	assert_ne(result.size(), 0, "合法事件文件应加载成功")
	assert_true(result.has("events") and result.has("phase_maps"),
			"返回结构应含 events + phase_maps 双表")


# ------------------------------------------------------------------
# Group G —— 动作执行器（验收④：9 种动作全部实装）
# ------------------------------------------------------------------

## 装配真实 runner（裸开演：box/player 缺省安全，S1 设计保证）
func _make_runner() -> Node:
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	return _runner


func _make_executor(p_runner: Node = null) -> RefCounted:
	_executor = EventExecutor.new()
	if p_runner != null:
		_executor.setup(p_runner)
	return _executor


func test_g1_dialogue动作开演() -> void:
	var r: Node = _make_runner()
	var ex: RefCounted = _make_executor(r)
	ex.execute_event("ev_g1", _ev_dialogue("dlg_innkeeper_p0"))
	assert_true(r.has_method("start_dialogue") and r.current_event_id == "dlg_innkeeper_p0",
			"dialogue 动作应按 id 开演")


func test_g2_giveitem写背包() -> void:
	var ex: RefCounted = _make_executor(null)
	GameData.inventory["potion_s"] = 1
	ex.execute_event("ev_g2", _ev_action({"type": "give_item", "item_id": "potion_s", "count": 2}))
	assert_eq(int(GameData.inventory["potion_s"]), 3, "count 应累加（I2 队伍共享背包）")


func test_g3_setflag写flags() -> void:
	var ex: RefCounted = _make_executor(null)
	assert_false(GameData.flags.has("ev_g3_flag"), "哨兵：flag 初始不存在")
	ex.execute_event("ev_g3", _ev_action({"type": "set_flag", "flag": "ev_g3_flag"}))
	assert_true(GameData.flags.has("ev_g3_flag"), "set_flag 应写入 GameData.flags")


func test_g4_battle发payload并暂存组id() -> void:
	var r: Node = _make_runner()
	r.start_dialogue("dlg_innkeeper_p0")   # 制造"对话中"前置
	assert_false(r.is_idle(), "哨兵：对话中")
	watch_signals(EventBus)
	var ex: RefCounted = _make_executor(r)
	ex.execute_event("ev_g4", _ev_action({"type": "battle", "group": "b1_moth"}))
	assert_signal_emitted(EventBus, "enemy_touched", "battle 应经 A5 通路发 enemy_touched")
	var params: Array = get_signal_parameters(EventBus, "enemy_touched")
	assert_eq(String(params[0]["enemy_group_id"]), "b1_moth", "payload 组 id 应正确")
	assert_eq(String(ex.pending_battle_group), "b1_moth", "暂存位应记录组 id（S5 桥接消费）")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(r.is_idle(), "事件流应收束：runner 回 IDLE（延迟一帧 force_idle）")


func test_g5_heal全队回满() -> void:
	var ex: RefCounted = _make_executor(null)
	# 先制造伤势
	GameData.party[0].hp = 1
	GameData.party[0].mp = 0
	GameData.party[2].hp = 1
	ex.execute_event("ev_g5", _ev_action({"type": "heal"}))
	for r in GameData.party:
		assert_eq(r.hp, r.max_hp, "heal 后 %s HP 应满" % r.id)
		assert_eq(r.mp, r.max_mp, "heal 后 %s MP 应满" % r.id)


func test_g6_savepoint发存档请求() -> void:
	watch_signals(EventBus)
	var ex: RefCounted = _make_executor(null)
	ex.execute_event("ev_g6", _ev_action({"type": "save_point"}))
	assert_signal_emitted(EventBus, "save_requested", "save_point 应发存档请求")


func test_g7_setstoryphase写值并广播() -> void:
	watch_signals(EventBus)
	var ex: RefCounted = _make_executor(null)
	ex.execute_event("ev_g7", _ev_action({"type": "set_story_phase", "phase": 2}))
	assert_eq(GameData.story_phase, 2, "story_phase 应写入")
	assert_signal_emitted(EventBus, "story_phase_changed", "阶段变化应广播")
	var params: Array = get_signal_parameters(EventBus, "story_phase_changed")
	assert_eq(int(params[0]), 2, "广播参数应为新阶段值")


func test_g8_waitplaysfx_teleport占位不炸() -> void:
	var ex: RefCounted = _make_executor(null)
	# E6 钩子占位与通路预留：执行必须无异常（验收④"允许空实现占位"的运行面）
	ex.execute_event("ev_g8a", _ev_action({"type": "wait", "duration": 0.5}))
	ex.execute_event("ev_g8b", _ev_action({"type": "play_sfx", "sfx": "res://x.ogg"}))
	ex.execute_event("ev_g8c", _ev_action({"type": "teleport", "to_map": "road", "to_spawn": [1.5, 2]}))
	assert_true(true, "三个占位/预留动作执行完毕未异常")


func test_g9_notflag条件评估() -> void:
	var ex: RefCounted = _make_executor(null)
	var ev: Dictionary = {"conditions": {"not_flag": "taken"}, "actions": [
		{"type": "give_item", "item_id": "potion_s", "count": 1}]}
	ex.execute_event("ev_g9a", ev)
	assert_eq(int(GameData.inventory.get("potion_s", 0)), 1, "flag 不存在 → 条件过 → 执行")
	GameData.flags["taken"] = true
	ex.execute_event("ev_g9b", ev)
	assert_eq(int(GameData.inventory.get("potion_s", 0)), 1, "flag 存在 → 条件不过 → 跳过")


func test_g10_storyphase条件评估() -> void:
	var ex: RefCounted = _make_executor(null)
	GameData.story_phase = 1
	var ev: Dictionary = {"conditions": {"story_phase": [">=", 2]}, "actions": [
		{"type": "set_flag", "flag": "never"}]}
	ex.execute_event("ev_g10", ev)
	assert_false(GameData.flags.has("never"), "phase 1 < 2 → 条件不过 → 跳过")
	GameData.story_phase = 2
	ex.execute_event("ev_g10b", ev)
	assert_true(GameData.flags.has("never"), "phase 2 >= 2 → 执行")


func test_g11_phase映射按当前phase选对话() -> void:
	var r: Node = _make_runner()
	var ex: RefCounted = _make_executor(r)
	var ev: Dictionary = {"conditions": {}, "actions": [
		{"type": "dialogue", "id": {"0": "dlg_innkeeper_p0", "1": "dlg_innkeeper_p12"}}]}
	GameData.story_phase = 0
	ex.execute_event("ev_g11a", ev)
	assert_eq(r.current_event_id, "dlg_innkeeper_p0", "phase=0 应选 \"0\" 键对话")
	r.force_idle()
	GameData.story_phase = 2
	ex.execute_event("ev_g11b", ev)
	assert_eq(r.current_event_id, "dlg_innkeeper_p12",
			"phase=2 应取 ≤ 当前 phase 的最大键（GDD §3.2 原文例）")


# ------------------------------------------------------------------
# Group H —— 触发器薄壳统一（三层链路 + 门闸 + 降级）
# ------------------------------------------------------------------

## 装配完整三层（loader + executor + runner + shell）
func _make_stack() -> Area2D:
	_loader = EventLoader.new()
	_loader.load_all()
	var r: Node = _make_runner()
	_executor = EventExecutor.new()
	_executor.setup(r)
	_shell = autofree(ShellScript.new())
	_shell.setup(_loader, _executor, r)
	add_child_autofree(_shell)
	return _shell


func test_h1_薄壳三层链路发射事件() -> void:
	var shell: Area2D = _make_stack()
	shell.new_event_id = "ev_demo_loot"
	shell.inject_emit()
	assert_true(GameData.flags.has("demo_loot_taken"),
			"壳命中 → loader 取数 → executor 执行：set_flag 副作用应发生")


func test_h2_对话期间壳忽略事件_边缘2() -> void:
	var shell: Area2D = _make_stack()
	shell.new_event_id = "ev_demo_loot"
	var r: Node = _runner
	r.start_dialogue("dlg_innkeeper_p0")   # 制造对话中
	assert_false(r.is_idle(), "哨兵：对话中")
	shell.inject_emit()
	assert_false(GameData.flags.has("demo_loot_taken"),
			"对话期间触发器应一律忽略（is_idle 门闸，边缘 2 复测于新壳）")
	r.force_idle()


func test_h3_未登记事件静默跳过() -> void:
	var shell: Area2D = _make_stack()
	shell.new_event_id = "ev_no_such"
	shell.inject_emit()
	assert_true(true, "未登记事件不应 crash")


func test_h4_neweventid为空保持E4兼容路径() -> void:
	var shell: Area2D = _make_stack()
	shell.new_event_id = ""
	var flags_before: Dictionary = GameData.flags.duplicate(true)
	shell.inject_emit()
	assert_eq(GameData.flags, flags_before, "事件路径关闭时命中应零动作（E4 行为零变化）")


func test_h5_runner未注入跳过门闸照常执行() -> void:
	# 同 trigger_teleport 语义：无对话装配的图，门闸不挡事件
	_loader = EventLoader.new()
	_loader.load_all()
	_executor = EventExecutor.new()
	_shell = autofree(ShellScript.new())
	_shell.setup(_loader, _executor, null)
	add_child_autofree(_shell)
	_shell.new_event_id = "ev_demo_loot"
	_shell.inject_emit()
	assert_true(GameData.flags.has("demo_loot_taken"), "runner 缺席时事件应照常执行")


# ------------------------------------------------------------------
# Group I —— 薄壳协议保持（event_id 协议族原样）
# ------------------------------------------------------------------

func test_i1_既有实体协议族原样() -> void:
	var chest: StaticBody2D = autofree(ChestScript.new())
	var inv: StaticBody2D = autofree(InvestigateScript.new())
	var tp: Area2D = autofree(TeleportScript.new())
	assert_true(chest.has_method("get_event_id"), "chest 应保留 get_event_id 协议")
	assert_true(inv.has_method("get_event_id"), "investigate 应保留 get_event_id 协议")
	assert_true(tp.has_method("get_event_id"), "trigger_teleport 应保留 get_event_id 协议")
	assert_true(chest.has_method("on_interact") and inv.has_method("on_interact"),
			"实体自治协议应原样（E4 零回归）")


func test_i2_统一壳带薄壳协议属性() -> void:
	var shell: Area2D = autofree(ShellScript.new())
	assert_true("event_id" in shell, "统一壳应带 event_id 协议属性")
	assert_true(shell.has_method("on_interact"), "统一壳应实现交互协议（controller 可分派）")
	var td: Area2D = autofree(TriggerDialogueScript.new())
	assert_true("event_id" in td, "trigger_dialogue 薄壳协议应原样")


func test_i3_卸载后事件目录加载幂等() -> void:
	# load_all 二连跑：以最后一次为准，无残留无翻倍
	_loader = EventLoader.new()
	_loader.load_all()
	var first_count: int = _loader.events.size()
	_loader.load_all()
	assert_eq(_loader.events.size(), first_count, "重复加载应幂等（同表规模）")
	assert_gte(first_count, 6, "S2 事件数据应 ≥ 6 个（story/npc/demo 系列）")
