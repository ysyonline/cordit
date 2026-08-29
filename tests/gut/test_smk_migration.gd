extends GutTest
## SMK-01~06 → GUT 迁移（TASK-S2-02）
##
## 来源对照：
##   SMK-01~04 动态断言 ← tests/smoke/headless_smk.gd（逐字段同语义迁移）
##   SMK-05/06 静态断言 ← tests/smoke/evidence/smk-05.txt / smk-06.txt（判例同源）
## 断言语义与原 SMK 一致，未放宽；测试函数名含 smk_0x 字样保留编号可追溯。
## SMK-07~12 本期不迁，原手工/headless 通道保留（见 SMOKE-CHECKLIST.md）。
##
## 与原运行前提的唯一差异：GUT 以 -s 脚本模式跑测时会把自身节点挂进 root
## （cli / GutRunner 等），SMK-01 的"恰好 4 个"断言因此需要在测试内识别
## GUT 基建节点——这是还原原断言前提，不是放宽口径（详见 _is_gut_infra 注释）。
##
## 跑法（项目根下）：
##   Godot_console.exe --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

# --------------- SMK-03/04 共用的信号捕获成员（与原 headless_smk.gd 同款） ---------------

var _recv_enemy: Variant = null
var _recv_dialogue: Variant = null
var _recv_battle: Variant = null
var _recv_phase: Variant = null
var _recv_save: bool = false
var _recv_map: Variant = null


func before_each() -> void:
	# 每条用例前重置捕获，防跨用例串扰
	_recv_enemy = null
	_recv_dialogue = null
	_recv_battle = null
	_recv_phase = null
	_recv_save = false
	_recv_map = null


# --------------- SMK-01 四 Autoload 注册生效 ---------------

func test_smk01_四_autoload_注册生效() -> void:
	var expected := ["GameData", "EventBus", "SceneRouter", "SaveManager"]
	var found: Array[String] = []
	for child in get_tree().root.get_children():
		if _is_gut_infra(child):
			continue
		found.append(String(child.name))
	# 原 SMK-01 语义：数量恰为 4（多一个即超建，对照架构 A3）
	assert_eq(found.size(), 4, "root 下非测试基建节点数 = %d（应为 4）: %s" % [found.size(), found])
	for n in expected:
		assert_has(found, n, "缺少单例 " + n)


## GUT 运行基建识别。
## GUT 命令行跑测时挂进 root 的节点（cli = gut_cli.gd、GutRunner = gui/GutRunner.gd）
## 脚本全部位于 addons/gut/ 下；本测试脚本实例自身也可能在 root 上。
## 判定依据是脚本路径而非节点名，避免误伤未来项目侧同名节点。
func _is_gut_infra(node: Node) -> bool:
	if node == self:
		return true
	var s: Script = node.get_script()
	if s != null:
		var p := s.resource_path
		return p.begins_with("res://addons/gut/") or p.begins_with("res://tests/gut/")
	return false


# --------------- SMK-02 EventBus 六信号声明齐全 ---------------

func test_smk02_六信号_声明齐全参数一致() -> void:
	# 预期：信号名 -> 参数个数（save_requested 无参）——与原 SMK-02 逐字一致
	var expected := {
		"enemy_touched": 1, "dialogue_finished": 1, "battle_finished": 1,
		"story_phase_changed": 1, "save_requested": 0, "map_ready": 1}
	# 用脚本级信号列表核对"恰好六个"（过滤继承信号，与原实现同法）
	var sig_list: Array = EventBus.get_script().get_script_signal_list()
	var actual := {}
	for s in sig_list:
		actual[s["name"]] = (s["args"] as Array).size()
	assert_eq(actual.size(), expected.size(), "声明信号数 = %d（应为 6）: %s" % [actual.size(), actual.keys()])
	for k: String in expected:
		assert_has(actual, k, "缺少信号 " + k)
		if actual.has(k):
			assert_eq(actual[k], expected[k], "%s 参数数 = %d（应为 %d）" % [k, actual[k], expected[k]])


# --------------- SMK-03 / SMK-04 信号 connect 与参数送达 ---------------

func test_smk03_六信号_可_connect() -> void:
	# 原 SMK-03 语义：六信号 connect 返回值全部 OK，无 unknown signal / cannot connect
	var errors := _connect_all()
	assert_eq(errors.size(), 0, "connect 失败 -> %s" % [errors])
	_disconnect_all()


func test_smk04_emit_参数原样送达() -> void:
	# 原 SMK-04 语义：connect 后 emit，逐字段核对（含 Vector2 与 int 类型）
	_connect_all()
	var sent := {
		"enemy_group_id": "slime_01", "return_map": "res://scenes/maps/road.tscn",
		"return_position": Vector2(64, 32), "defeat_enemy_uid": "enemy_road_01"}
	EventBus.enemy_touched.emit(sent)
	EventBus.dialogue_finished.emit("evt_test_01")
	EventBus.battle_finished.emit({"outcome": "VICTORY"})
	EventBus.story_phase_changed.emit(1)
	EventBus.save_requested.emit()
	EventBus.map_ready.emit("town")

	assert_eq(_recv_enemy, sent, "enemy_touched payload 不一致: %s" % [_recv_enemy])
	if _recv_enemy != null:
		assert_eq((_recv_enemy as Dictionary).get("return_position"), Vector2(64, 32),
			"return_position 非 Vector2(64, 32)")
	assert_eq(_recv_dialogue, "evt_test_01", "dialogue_finished 收到 %s" % [_recv_dialogue])
	assert_eq(_recv_battle, {"outcome": "VICTORY"}, "battle_finished 收到 %s" % [_recv_battle])
	assert_typeof(_recv_phase, TYPE_INT, "story_phase_changed 收到类型 %d（应为 int）" % typeof(_recv_phase))
	assert_eq(_recv_phase, 1, "story_phase_changed 收到 %s（应为 int 1）" % [_recv_phase])
	assert_true(_recv_save, "save_requested 无参回调未触发")
	assert_eq(_recv_map, "town", "map_ready 收到 %s" % [_recv_map])
	_disconnect_all()


func _connect_all() -> Array[String]:
	var errors: Array[String] = []
	if EventBus.enemy_touched.connect(_on_enemy_touched) != OK:
		errors.append("enemy_touched")
	if EventBus.dialogue_finished.connect(_on_dialogue_finished) != OK:
		errors.append("dialogue_finished")
	if EventBus.battle_finished.connect(_on_battle_finished) != OK:
		errors.append("battle_finished")
	if EventBus.story_phase_changed.connect(_on_story_phase_changed) != OK:
		errors.append("story_phase_changed")
	if EventBus.save_requested.connect(_on_save_requested) != OK:
		errors.append("save_requested")
	if EventBus.map_ready.connect(_on_map_ready) != OK:
		errors.append("map_ready")
	return errors


func _disconnect_all() -> void:
	EventBus.enemy_touched.disconnect(_on_enemy_touched)
	EventBus.dialogue_finished.disconnect(_on_dialogue_finished)
	EventBus.battle_finished.disconnect(_on_battle_finished)
	EventBus.story_phase_changed.disconnect(_on_story_phase_changed)
	EventBus.save_requested.disconnect(_on_save_requested)
	EventBus.map_ready.disconnect(_on_map_ready)


# --------------- SMK-05 EventBus 无状态越界（A3 边界，静态） ---------------

func test_smk05_EventBus_无状态越界() -> void:
	# 原 SMK-05 判例（evidence/smk-05.txt）：除 extends + 六条 signal 声明 + 注释外，
	# 零成员变量、零函数、零 _ready。原正则的 `_ready` 分支只可能经由 func 声明
	# 出现在代码行（signal 名含 _ready 属 SMK-02 范围，判例已认定合法），故此处
	# 以"非注释行的 var/func 声明"为越界判据，语义与原判例一致。
	var src: String = (load("res://autoload/event_bus.gd") as Script).source_code
	var re_decl := RegEx.create_from_string("^\\s*(var |func )")
	var violations: Array[String] = []
	var lines := src.split("\n")
	for i in lines.size():
		var raw := lines[i] as String
		if raw.strip_edges().begins_with("#"):
			continue  # 注释行允许出现 var/func/_ready 字样（原判例第 2 条）
		if re_decl.search(raw) != null:
			violations.append("第 %d 行: %s" % [i + 1, raw.strip_edges()])
	assert_eq(violations.size(), 0, "EventBus 存在越界声明（A3：只声明信号）: %s" % [violations])


# --------------- SMK-06 GameData 字段声明齐全（静态+运行时双通道） ---------------

func test_smk06_GameData_字段齐全且带类型标注() -> void:
	# 原 SMK-06 预期字段清单 + 判例认定的附加字段（inventory/gold，A5 协议保留）
	var required := ["party", "inventory", "gold", "story_phase", "flags",
		"chests_opened", "cleared_enemy_set", "discovered_weakness_set"]
	var src: String = (load("res://autoload/game_data.gd") as Script).source_code
	for field in required:
		# 运行时存在性（对应原"远程场景树/检查器核对"通道）
		assert_true(field in GameData, "GameData 缺少字段 " + field)
		# 源码带显式类型标注（ADR-1 渐进类型，对应原"源码核对类型标注"通道）
		# 逐行扫描（与 SMK-05 同法）：避免 ^ 锚点在非多行模式下只匹配串首
		var re := RegEx.create_from_string("^\\s*var\\s+%s\\s*:" % field)
		var annotated := false
		for raw in src.split("\n"):
			if re.search(raw as String) != null:
				annotated = true
				break
		assert_true(annotated, "字段 %s 缺少类型标注（ADR-1）" % field)
	# 关键字段运行时类型抽查（对应原检查器核对）
	assert_true(GameData.party is Array, "party 应为 Array（空壳阶段 Array[Dictionary] 占位）")
	assert_true(GameData.story_phase is int, "story_phase 应为 int")
	assert_true(GameData.flags is Dictionary, "flags 应为 Dictionary")


# --------------- 信号捕获回调（与原 headless_smk.gd 同名同参） ---------------

func _on_enemy_touched(p: Dictionary) -> void:
	_recv_enemy = p

func _on_dialogue_finished(id: String) -> void:
	_recv_dialogue = id

func _on_battle_finished(r: Dictionary) -> void:
	_recv_battle = r

func _on_story_phase_changed(n: int) -> void:
	_recv_phase = n

func _on_save_requested() -> void:
	_recv_save = true

func _on_map_ready(m: String) -> void:
	_recv_map = m
