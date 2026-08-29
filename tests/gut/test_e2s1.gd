extends GutTest
## E2-S1 GameData 队伍数据 + M 键调试面板（TASK-S2-06）
##
## 断言覆盖（EPIC-2.md E2-S1 验收标准的自动化部分）：
##   A. 队伍数据：3 名角色（剑士/术士/辅助）字段齐全且类型正确，
##      初始数值与战斗 GDD §3.6 Lv1 列一致（ADR-2 数值口径的守门断言）；
##   B. ADR-1/边界：GameData 源码零 IO 函数、字段带类型标注、
##      CharacterRecord 为 Resource 子类（结构化数值而非裸 Dictionary）；
##   C. 面板形态：场景可实例化、根节点是 CanvasLayer（UILayer 层级）、
##      挂载后位于 UILayer 子树而非 World（世界）之下；
##   D. M 键 toggle：toggle() 开/关状态正确往返；_is_toggle_pressed 对
##      physical_keycode=KEY_M 的按下事件判定为真（回退通道，工程是否注册
##      debug_panel 动作均可判定）；echo/松开/Ctrl 组合不触发。
##
## 【为什么用 Fixture 子类替换 _build_ui】：
##   headless 模式下项目未载入内置主题字体，RichTextLabel 的 BBCode 粗体
##   （[b] 标签）渲染会持续刷"字体缺字"告警污染测试输出。面板脚本预留了
##   _build_ui() 可覆写点（控件树组装与逻辑无耦合），Fixture 只挂最小占位
##   标签——被测的 toggle/输入判定/刷新调度逻辑全部保留原实现。
##
## 【为什么不在测试里实例化 main.tscn】：
##   main.tscn 的 main_controller.gd 会经 SceneRouter 装载初始场景并执行
##   0.2s 淡入淡出（异步），会与 SMK-01"root 下恰 4 个非测试节点"断言、
##   SceneRouter._switching 防重入簿记互相干扰。挂载关系（DebugPanel 属
##   UILayer 子树）改用"静态场景文件 + 运行时挂载"两条通道联合验证：
##   场景文件文本含 [node ... parent="UILayer"]，运行时把手造 UILayer 与
##   面板实例组成同构树核对父子关系。
##
## 跑法（项目根下）：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const PANEL_SCENE_PATH: String = "res://scenes/ui/debug_panel.tscn"
const GAME_DATA_SCRIPT_PATH: String = "res://autoload/game_data.gd"

## 战斗 GDD §3.6 Lv1 列的初始数值口径（槽位序：剑士→术士→辅助）
const EXPECTED_PARTY: Array = [
	{"id": "kyle", "name": "凯尔", "job": "swordsman", "level": 1,
		"hp": 120, "max_hp": 120, "mp": 10, "max_mp": 10},
	{"id": "lina", "name": "莉娜", "job": "sorcerer", "level": 1,
		"hp": 80, "max_hp": 80, "mp": 30, "max_mp": 30},
	{"id": "mona", "name": "莫娜", "job": "support", "level": 1,
		"hp": 95, "max_hp": 95, "mp": 24, "max_mp": 24},
]

## CharacterRecord 必备字段 -> 期望类型（Variant.Type）
const RECORD_FIELDS: Dictionary = {
	"id": TYPE_STRING, "name": TYPE_STRING, "job": TYPE_STRING,
	"level": TYPE_INT, "hp": TYPE_INT, "max_hp": TYPE_INT,
	"mp": TYPE_INT, "max_mp": TYPE_INT,
}


## 最小 UI 替身：只挂一个占位 Label，规避 headless 下 BBCode 字体告警。
## 同步覆写 _refresh_text：替身没有真文本控件 _text，原刷新实现会在
## toggle/轮询时向 Nil 赋值；替身改写 refresh_count 计数器，
## 让用例能直接断言"刷新确实发生了"（数据实时刷新的逻辑级证据）。
class FixturePanel:
	extends "res://scripts/ui/debug_panel.gd"

	var text_proxy: Label = null
	## _refresh_text 被调用次数（实时刷新断言用）
	var refresh_count: int = 0

	func _build_ui() -> void:
		text_proxy = Label.new()
		text_proxy.name = "FixtureTextProxy"
		add_child(text_proxy)

	func _refresh_text() -> void:
		refresh_count += 1
		if text_proxy != null:
			text_proxy.text = "刷新 %d" % refresh_count


# =============== A. 队伍数据（GDD 数值口径） ===============

func test_队伍恰好三名角色() -> void:
	assert_eq(GameData.party.size(), 3, "队伍应为 3 人（剑士/术士/辅助），实为 %d" % GameData.party.size())


func test_角色字段齐全且类型正确() -> void:
	assert_eq(GameData.party.size(), 3, "前置：队伍 3 人")
	for i: int in GameData.party.size():
		var rec: Resource = GameData.party[i]
		assert_not_null(rec, "槽位 %d 角色记录不应为空" % i)
		for field: String in RECORD_FIELDS:
			assert_true(field in rec, "槽位 %d 缺少字段 %s" % [i, field])
			if field in rec:
				assert_typeof(rec.get(field), RECORD_FIELDS[field],
						"槽位 %d 字段 %s 类型应为 %s" % [i, field, type_string(RECORD_FIELDS[field])])


func test_角色初始数值与战斗GDD一致() -> void:
	assert_eq(GameData.party.size(), 3, "前置：队伍 3 人")
	for i: int in GameData.party.size():
		var rec: Resource = GameData.party[i]
		var exp: Dictionary = EXPECTED_PARTY[i]
		for field: String in exp:
			assert_eq(rec.get(field), exp[field],
					"槽位 %d 字段 %s 应为 %s（战斗 GDD §3.6 Lv1），实为 %s" % [i, field, exp[field], rec.get(field)])


func test_职业构成剑士术士辅助各一() -> void:
	var jobs: Array[String] = []
	for rec: Resource in GameData.party:
		jobs.append(rec.job)
	assert_has(jobs, "swordsman", "缺少剑士")
	assert_has(jobs, "sorcerer", "缺少术士")
	assert_has(jobs, "support", "缺少辅助")


func test_角色记录是Resource子类而非裸Dictionary() -> void:
	# ADR-2 数值口径守门：结构化数值用 Resource/自定义 class，
	# 防止退回裸 Dictionary（拼错字段名不报错的静默坑）
	for i: int in GameData.party.size():
		var rec: Resource = GameData.party[i]
		assert_true(rec is Resource, "槽位 %d 应为 Resource 子类，实为 %s" % [i, typeof(rec)])
		assert_true(rec.get_script() != null, "槽位 %d 应挂 CharacterRecord 脚本" % i)


# =============== B. ADR-1 / A3 边界（GameData 源码静态断言） ===============

func test_GameData_源码零IO函数() -> void:
	# A3：GameData 不做任何磁盘读写；守门防 FileAccess/DirAccess 混入
	var src: String = (load(GAME_DATA_SCRIPT_PATH) as Script).source_code
	var forbidden: Array[String] = ["FileAccess", "DirAccess", "store_", "get_line", "open("]
	var hits: Array[String] = []
	for i: int in (src.split("\n") as Array).size():
		var raw: String = (src.split("\n") as Array)[i]
		if raw.strip_edges().begins_with("#"):
			continue  # 注释里的边界说明不算违规
		for kw: String in forbidden:
			if kw in raw:
				hits.append("第 %d 行含 \"%s\"：%s" % [i + 1, kw, raw.strip_edges()])
	assert_eq(hits.size(), 0, "GameData 出现 IO 踪迹（A3 红线）： %s" % [hits])


func test_GameData_新队伍字段仍有类型标注() -> void:
	# SMK-06 同法：逐行扫描 var party: 的类型标注（ADR-1 回归防线）
	var src: String = (load(GAME_DATA_SCRIPT_PATH) as Script).source_code
	var re := RegEx.create_from_string("^\\s*var\\s+party\\s*:")
	var annotated := false
	for raw: String in src.split("\n"):
		if re.search(raw) != null:
			annotated = true
			break
	assert_true(annotated, "字段 party 缺少类型标注（ADR-1）")
	assert_true(GameData.party is Array, "party 应为类型化 Array")


# =============== C. 面板形态（纯 UILayer） ===============

func test_面板场景可实例化且根节点是CanvasLayer() -> void:
	assert_true(ResourceLoader.exists(PANEL_SCENE_PATH, "PackedScene"),
			"调试面板场景缺失：" + PANEL_SCENE_PATH)
	var packed: PackedScene = load(PANEL_SCENE_PATH) as PackedScene
	assert_not_null(packed, "面板场景装载失败")
	var panel: Node = packed.instantiate()
	assert_not_null(panel, "面板场景实例化失败")
	assert_true(panel is CanvasLayer, "面板根节点应为 CanvasLayer（UILayer 层级），实为 %s" % typeof(panel))
	assert_eq((panel as CanvasLayer).visible, false, "面板默认应隐藏（不影响首屏）")
	panel.free()  # 未进树的实例用 free 即时释放


func test_面板控件树不拦截鼠标输入() -> void:
	# 验收点 2 的自动化部分：整棵面板控件树 mouse_filter = IGNORE
	# 本用例为纯静态检查（实例化形态已由其他用例覆盖）：
	# 源码中不得出现非 IGNORE 的 mouse_filter 赋值
	var src: String = (load("res://scripts/ui/debug_panel.gd") as Script).source_code
	for i: int in (src.split("\n") as Array).size():
		var raw: String = (src.split("\n") as Array)[i]
		if "mouse_filter" in raw and not raw.strip_edges().begins_with("#"):
			assert_true("MOUSE_FILTER_IGNORE" in raw,
					"第 %d 行 mouse_filter 未设 IGNORE： %s" % [i + 1, raw.strip_edges()])
	# focus 同理：不得获取键盘焦点（不干扰 WASD）
	assert_true("FOCUS_NONE" in src, "面板应设置 focus_mode = FOCUS_NONE（不抢键盘焦点）")


func test_面板挂载于UILayer子树而非World() -> void:
	# 场景文件通道：main.tscn 中 DebugPanel 的 parent 必须是 "UILayer"
	var main_src: String = FileAccess.get_file_as_string("res://scenes/main.tscn")
	var re := RegEx.create_from_string("\\[node name=\"DebugPanel\"[^\\]]*parent=\"([^\"]+)\"")
	var m: RegExMatch = re.search(main_src)
	assert_not_null(m, "main.tscn 中未找到 DebugPanel 实例节点")
	if m != null:
		assert_eq(m.get_string(1), "UILayer",
				"DebugPanel 应挂在 UILayer 下（纯 UILayer 节点），实为 " + m.get_string(1))
	# 运行时通道：Fixture 直接实例化（覆写 _build_ui 规避 headless 字体告警；
	# 场景 instantiate 产出的是基类脚本实例，取不到 Fixture 成员），
	# 手造 UILayer 与面板组成同构树，核对父子关系成立
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child_autofree(ui_layer)
	var panel: FixturePanel = FixturePanel.new()
	autofree(panel)
	ui_layer.add_child(panel)
	assert_eq(panel.get_parent(), ui_layer, "面板运行时父节点应为 UILayer")
	assert_false(panel.is_in_group("world"), "面板不得属于世界分组")
	# 面板必须在 World 之外：本项目 World 是 Main 的直接子节点，
	# 沿父链逐级上溯，任何祖先都不得名为 World（Node 无现成祖先列表 API）
	var walker: Node = panel
	var found_world := false
	while walker != null:
		if walker.name == "World":
			found_world = true
		walker = walker.get_parent()
	assert_false(found_world, "面板祖先链上不应出现 World（世界）节点")


func test_面板刷新不重建控件树() -> void:
	# 刷新只重写文本字符串，不 new 控件（验收点"数据实时刷新"的实现纪律：
	# 每帧重建 UI 会整层重排导致卡顿）
	# Fixture 直接实例化（覆写 _build_ui 规避 headless 字体告警）；
	# 场景 instantiate 产出基类脚本实例，取不到 Fixture 成员
	var panel: FixturePanel = FixturePanel.new()
	autofree(panel)
	add_child_autofree(panel)
	var children_before: Array = panel.get_children().duplicate()
	panel.toggle()
	assert_true(panel.visible, "前置：面板已打开")
	assert_eq(panel.refresh_count, 1, "打开瞬间应立即刷新一次（无旧数据残留窗口）")
	# 等过一个刷新周期：轮询应再次刷新，控件树原封不动
	await wait_seconds(panel.REFRESH_INTERVAL + 0.05)
	assert_true(panel.refresh_count >= 2,
			"开启期间应持续轮询刷新（实时刷新证据），实为 %d 次" % panel.refresh_count)
	assert_eq((panel.get_children() as Array).size(), children_before.size(),
			"刷新不得增删控件节点")
	for i: int in children_before.size():
		assert_eq(panel.get_children()[i], children_before[i], "刷新不得替换控件实例")
	assert_true(panel.text_proxy.visible, "刷新后占位文本节点应存活可见")
	# 关闭后轮询停止：再等一小段时间，刷新计数不得增长（零开销）
	var count_after_open: int = panel.refresh_count
	panel.toggle()
	assert_false(panel.visible, "前置：面板已关闭")
	await wait_seconds(0.05)
	assert_eq(panel.refresh_count, count_after_open, "关闭后不得再刷新（零开销直返）")


# =============== D. M 键 toggle 逻辑 ===============

func test_toggle_开_关往返() -> void:
	# Fixture 直接实例化（覆写 _build_ui 规避 headless 字体告警；
	# toggle/_unhandled_input 判定逻辑在基类实现，行为不受替身影响）
	var panel: FixturePanel = FixturePanel.new()
	autofree(panel)
	add_child_autofree(panel)
	assert_false(panel.visible, "初始应关闭")
	panel.toggle()
	assert_true(panel.visible, "第一次 toggle 应打开")
	panel.toggle()
	assert_false(panel.visible, "第二次 toggle 应关闭")
	panel.toggle()
	assert_true(panel.visible, "第三次 toggle 应再次打开")


func test_M键按下事件被判定为toggle() -> void:
	# Fixture 直接实例化（原因同前：场景 instantiate 产出基类脚本实例）
	var panel: FixturePanel = FixturePanel.new()
	autofree(panel)
	add_child_autofree(panel)
	# 按下：物理 M 键（工程未注册 debug_panel 动作时的回退通道必须可用）
	var press := InputEventKey.new()
	press.physical_keycode = KEY_M
	press.pressed = true
	assert_true(panel._is_toggle_pressed(press), "物理 M 键按下应判定为 toggle")
	# 松开不触发（toggle 只认刚按下）
	var release := InputEventKey.new()
	release.physical_keycode = KEY_M
	release.pressed = false
	assert_false(panel._is_toggle_pressed(release), "M 键松开不应触发 toggle")
	# 按住不放的 echo 不触发（按住只 toggle 一次）
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_M
	echo.pressed = true
	echo.echo = true
	assert_false(panel._is_toggle_pressed(echo), "echo 事件不应触发 toggle")
	# Ctrl+M 预留组合键空间，不触发
	var ctrl_m := InputEventKey.new()
	ctrl_m.physical_keycode = KEY_M
	ctrl_m.pressed = true
	ctrl_m.ctrl_pressed = true
	assert_false(panel._is_toggle_pressed(ctrl_m), "Ctrl+M 不应触发（预留组合键）")
	# 非 M 键不触发
	var other := InputEventKey.new()
	other.physical_keycode = KEY_N
	other.pressed = true
	assert_false(panel._is_toggle_pressed(other), "非 M 键不应触发 toggle")


func test_M键事件驱动toggle_非_M_事件面板不动() -> void:
	# 走完整 _unhandled_input 通路：M 按下 -> 面板打开；Z（交互键）-> 不变
	# Fixture 直接实例化（原因同前）
	var panel: FixturePanel = FixturePanel.new()
	autofree(panel)
	add_child_autofree(panel)
	var press_m := InputEventKey.new()
	press_m.physical_keycode = KEY_M
	press_m.pressed = true
	panel._unhandled_input(press_m)
	assert_true(panel.visible, "M 按下事件应经 _unhandled_input 打开面板")
	var press_z := InputEventKey.new()
	press_z.physical_keycode = KEY_Z
	press_z.pressed = true
	panel._unhandled_input(press_z)
	assert_true(panel.visible, "非 M 键事件不应改变面板状态")
	var press_m2 := InputEventKey.new()
	press_m2.physical_keycode = KEY_M
	press_m2.pressed = true
	panel._unhandled_input(press_m2)
	assert_false(panel.visible, "再次 M 按下应关闭面板")
