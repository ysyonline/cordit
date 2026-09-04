extends GutTest
## T4.2 测试 —— 队员聊天 2 段 + 触发点×2 + 事件/对话 JSON（E6-S4 第 2 步）
##
## 【验收对表】E6-S4 验收条①原文"两段聊天各在指定位置触发一次"：
##   触发点 = 位置触发（对话 GDD §3.5：P1 道路 1 段 / P2 遗迹二层 1 段）。
##   任务书建议的"存/读档成功"触发与验收条冲突，按裁定以验收条为准——
##   本套件以事件层位置触发为准绳；同时加 E 组回归锁定 T4.1 存读档
##   链路（menu_panel 存/读档确认）在本 Story 改动后零回归（验收条②
##   "手动/自动格式一致"由 T4.1既有断言承载，此处只做回归护栏）。
##
## 【分组】
##   A 数据面：两段聊天脚本存在/可开演 + 两事件 E5 同构登记
##     （conditions 门闸 story_phase + not_flag；actions = dialogue + set_flag）
##   B 触发端到端：phase 门闸（低 phase 拒绝 / 达标放行）+ 薄壳
##     inject_emit 直驱（门闸语义与真实踩踏路径完全一致）
##   C 一次性口径：set_flag 后重触发零动作（"触发一次"）；flag 入存档
##     schema（T4.2 未动 SaveManager——版本 3 已含 flags，结构性断言）
##   D 装配面：road/f2 地图脚本装配薄壳（同位、协议属性、層位、目录）
##   E T4.1 回归：菜单存档确认/读档确认链路照常（本 Story 零回归）
##
## 【跑法】项目根下：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const EventLoader := preload("res://scripts/events/event_loader.gd")
const EventExecutor := preload("res://scripts/events/event_executor.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const ShellScript := preload("res://scripts/events/trigger_event_shell.gd")
const Assembler := preload("res://scripts/events/chat_point_assembler.gd")
const RoadMapScript := preload("res://scripts/maps/road_map.gd")
const F2MapScript := preload("res://scripts/maps/ruins_f2_map.gd")
const MenuPanelScript := preload("res://scripts/ui/menu_panel.gd")

const ROAD_CHAT_EVENT: String = "party_chat_road_01"
const F2_CHAT_EVENT: String = "party_chat_f2_01"
const ROAD_CHAT_FLAG: String = "chat_road_01_seen"
const F2_CHAT_FLAG: String = "chat_f2_01_seen"
const SAVE_TEST_PATH: String = "user://m6t42_test_save.json"

## GameData / SaveManager 状态快照（after_each 恢复——E5-S3/S4 既有纪律：
## flags/phase 曾外溢多套件的教训，快照必须含全部被改写字段）
var _snapshot: Dictionary = {}
var _loader: RefCounted = null
var _executor: RefCounted = null
var _runner: Node = null
var _menu: Control = null


func before_each() -> void:
	_snapshot = {
		"flags": GameData.flags.duplicate(true),
		"story_phase": GameData.story_phase,
		"inventory": GameData.inventory.duplicate(true),
		"chests_opened": GameData.chests_opened.duplicate(true),
	}
	# 存档槽隔离（T4.1 SMK-12 口径：指测试槽 + 清意图位/last_loaded + 删残留档）
	SaveManager.save_path = SAVE_TEST_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}
	_remove_test_save()
	# Router 簿记重置（e2s4/e6s1/T4.1 同款隔离）
	SceneRouter._staged_payload = {}
	SceneRouter.current_scene_path = ""
	SceneRouter._switching = false


func after_each() -> void:
	GameData.flags = _snapshot["flags"]
	GameData.story_phase = _snapshot["story_phase"]
	GameData.inventory = _snapshot["inventory"]
	GameData.chests_opened = _snapshot["chests_opened"]
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.save_requested_pending = false
	SaveManager.last_loaded = {}
	_remove_test_save()
	SceneRouter.current_scene_path = ""
	_menu = null
	_runner = null   # 上一用例 autofree 实例的悬垂引用复位（防跨用例摸释放对象）


## 装配 runner + loader + executor（e5s4/e5s5 _make_stack 同构）
func _make_stack() -> void:
	_runner = RunnerScript.new()
	add_child_autofree(_runner)
	_loader = EventLoader.new()
	var failed: Array[String] = _loader.load_all()
	assert_eq(failed.size(), 0, "前置：事件表装载零失败（新聊天事件数据全合法）")
	_executor = EventExecutor.new()
	_executor.setup(_runner)


## 手工搭 road/f2 地图装配面（e5s5 f 组同款：不走 _ready，手工补场景结构
## 后直驱装配函数；Marker 容器挂 YSorted 下与真实场景结构一致）
func _make_map(p_script: GDScript, p_container: String) -> Node2D:
	var map: Node2D = autofree(p_script.new())
	var ysorted: Node2D = Node2D.new()
	ysorted.name = "YSorted"
	map.add_child(ysorted)
	var anchors: Node2D = Node2D.new()
	anchors.name = p_container
	ysorted.add_child(anchors)
	return map


func _remove_test_save() -> void:
	if FileAccess.file_exists(SAVE_TEST_PATH):
		DirAccess.remove_absolute(SAVE_TEST_PATH)


# ------------------------------------------------------------------
# Group A —— 数据面（E5 同构：脚本存在可开演 + 事件登记结构对表）
# ------------------------------------------------------------------

func test_a1_两段聊天脚本存在且可开演() -> void:
	_make_stack()
	for id: String in [ROAD_CHAT_EVENT, F2_CHAT_EVENT]:
		assert_true(FileAccess.file_exists("res://data/json/dialogues/%s.json" % id),
				"聊天脚本应存在：%s" % id)
		assert_true(_runner.start_dialogue(id), "聊天脚本应可开演：%s" % id)
		assert_eq(_runner.current_event_id, id, "开演后当前段 id 应一致：%s" % id)
		_runner.force_idle()


func test_a2_聊天事件E5同构登记且结构与宝箱一次性语义对齐() -> void:
	_make_stack()
	for pair: Array in [[ROAD_CHAT_EVENT, ROAD_CHAT_FLAG, 1], [F2_CHAT_EVENT, F2_CHAT_FLAG, 2]]:
		var eid: String = pair[0]
		var fid: String = pair[1]
		var gate: int = pair[2]
		assert_true(_loader.has_event(eid), "聊天事件应登记：%s" % eid)
		var ev: Dictionary = _loader.get_event(eid)
		var conds: Dictionary = ev.get("conditions", {})
		# 门闸双条件：story_phase（时段）+ not_flag（一次性），E5 三键白名单内
		assert_true(conds.has("story_phase"), "%s 应有 story_phase 门闸" % eid)
		assert_eq(int((conds["story_phase"] as Array)[1]), gate,
				"%s 门闸 >=%d（GDD 指定时段）" % [eid, gate])
		assert_eq(String((conds["story_phase"] as Array)[0]), ">=", "%s 门闸应为 >=" % eid)
		assert_true(conds.has("not_flag"), "%s 应有 not_flag 门闸（一次性，宝箱已开判定同构）" % eid)
		assert_eq(String(conds["not_flag"]), fid, "%s 门闸 flag 名应对齐" % eid)
		# 动作序列：dialogue（聊天段）+ set_flag（登记），与宝箱四步模板同构
		var actions: Array = ev.get("actions", [])
		assert_eq(actions.size(), 2, "%s 应恰为 dialogue + set_flag 两动作" % eid)
		assert_eq(String((actions[0] as Dictionary).get("type")), "dialogue",
				"%s 首动作 = dialogue" % eid)
		assert_eq(String((actions[0] as Dictionary).get("id")), eid,
				"%s 对白 id 应与事件同名（一事件一段）" % eid)
		assert_eq(String((actions[1] as Dictionary).get("type")), "set_flag",
				"%s 次动作 = set_flag（触发登记）" % eid)
		assert_eq(String((actions[1] as Dictionary).get("flag")), fid,
				"%s 登记 flag 名应与门闸对齐" % eid)


func test_a3_聊天文本已润色无占位前缀且无ASCII引号() -> void:
	# 任务纪律：文本占位禁 ASCII 引号（直角引号替代）；【待润色】前缀已于
	# T6.4 润色时整段替换删除——此处反向锁定，防止占位前缀回潮
	for id: String in [ROAD_CHAT_EVENT, F2_CHAT_EVENT]:
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("res://data/json/dialogues/%s.json" % id))
		assert_true(typeof(parsed) == TYPE_DICTIONARY, "%s JSON 应合法" % id)
		var entries: Dictionary = (parsed as Dictionary).values()[0]
		assert_true(entries.size() >= 2, "%s 至少 2 条目（队员多轮对话形态）" % id)
		for eid: Variant in entries.keys():
			var entry: Dictionary = entries[eid]
			var text: String = String(entry.get("text", ""))
			assert_false(text.contains("\""), "条目 %s 的 text 不应含 ASCII 引号" % String(eid))
			assert_false(text.begins_with("【待润色】"),
					"条目 %s 不应再带【待润色】前缀（T6.4 润色已完成）" % String(eid))


# ------------------------------------------------------------------
# Group B —— 触发端到端（phase 门闸 + 薄壳 inject_emit 直驱）
# ------------------------------------------------------------------

func test_b1_道路聊天点phase1放行开演并登记flag() -> void:
	_make_stack()
	GameData.story_phase = 0
	_executor.execute_event(ROAD_CHAT_EVENT, _loader.get_event(ROAD_CHAT_EVENT))
	assert_eq(_runner.current_event_id, "", "phase=0 时道路聊天被 >=1 门闸拒绝（P1 前不响）")
	GameData.story_phase = 1
	_executor.execute_event(ROAD_CHAT_EVENT, _loader.get_event(ROAD_CHAT_EVENT))
	assert_eq(_runner.current_event_id, ROAD_CHAT_EVENT, "phase>=1 道路聊天应开演（P1 指定段）")
	assert_true(_runner.get_current_full_text().length() > 0, "开演后应有文本")
	_runner.force_idle()
	assert_true(GameData.flags.has(ROAD_CHAT_FLAG), "触发后应登记一次性 flag")


func test_b2_遗迹二层聊天点phase2放行phase1拒绝() -> void:
	_make_stack()
	GameData.story_phase = 1
	_executor.execute_event(F2_CHAT_EVENT, _loader.get_event(F2_CHAT_EVENT))
	assert_eq(_runner.current_event_id, "", "phase=1 时二层聊天被 >=2 门闸拒绝（P2 前不响）")
	GameData.story_phase = 2
	_executor.execute_event(F2_CHAT_EVENT, _loader.get_event(F2_CHAT_EVENT))
	assert_eq(_runner.current_event_id, F2_CHAT_EVENT, "phase>=2 二层聊天应开演（P2 指定段）")
	_runner.force_idle()
	assert_true(GameData.flags.has(F2_CHAT_FLAG), "触发后应登记一次性 flag")


func test_b3_薄壳注入直驱触发链与真实踩踏同语义() -> void:
	# 装配面薄壳（inject_emit 等价真实踩踏命中——trigger_event_shell 测试口径；
	# 门闸本身也是被测对象，不在注入口绕过）
	_make_stack()
	# 全局 executor 注入测试 runner（e5s5 g2 缺口③同款装配面）：
	# 装配器取 SceneRouter 全局单例，不注入则 dialogue 动作被静默跳过
	SceneRouter.global_event_executor.setup(_runner)
	var map: Node2D = _make_map(RoadMapScript, "Anchors")
	var built: Array = Assembler.assemble(map, "road", null)
	assert_eq(built.size(), 1, "road 应装配 1 处聊天点")
	GameData.story_phase = 1
	(built[0] as Area2D).inject_emit()
	assert_eq(_runner.current_event_id, ROAD_CHAT_EVENT, "薄壳命中应走事件链开演（真实踩踏同语义）")
	_runner.force_idle()


# ------------------------------------------------------------------
# Group C —— 一次性口径（"各触发一次"）+ flag 入存档结构
# ------------------------------------------------------------------

func test_c1_重复触发被flag门闸拒绝零动作() -> void:
	_make_stack()
	GameData.story_phase = 1
	_executor.execute_event(ROAD_CHAT_EVENT, _loader.get_event(ROAD_CHAT_EVENT))
	assert_eq(_runner.current_event_id, ROAD_CHAT_EVENT, "前置：首次触发开演")
	_runner.force_idle()
	# 重复触发（再踩/重进图回来再踩）：not_flag 门闸拒绝，不开演不重登记
	_executor.execute_event(ROAD_CHAT_EVENT, _loader.get_event(ROAD_CHAT_EVENT))
	assert_ne(_runner.current_event_id, ROAD_CHAT_EVENT, "重复触发不得再开演（各触发一次）")
	# 两段各自独立：道路段已看完不影响二层段的触发资格
	GameData.story_phase = 2
	_executor.execute_event(F2_CHAT_EVENT, _loader.get_event(F2_CHAT_EVENT))
	assert_eq(_runner.current_event_id, F2_CHAT_EVENT, "二段各自独立（道路段 flag 不影响二层段）")
	_runner.force_idle()


func test_c2_一次性flag入存档schema读档后语义持久() -> void:
	# 结构性断言：flags 已是 ADR-3 v1 起的存档字段（E5-S3 起 GameData.flags
	# 直接入档）——T4.2 未动 SaveManager；验证聊天 flag 走的正是这个通道。
	assert_true(SaveManager.SCHEMA.has("flags"), "存档 schema 应含 flags 字段（既有，未动）")
	assert_eq(int(SaveManager.SCHEMA_VERSION), 3, "T4.2 不动存档格式版本（无字段新增）")
	# 行为面：置 flag → 存档 → 清内存 → 读档 → flag 应随档还原
	_make_stack()
	GameData.story_phase = 1
	GameData.flags[ROAD_CHAT_FLAG] = true
	var scene_ok: bool = SaveManager.save("road", Vector2(100, 100))
	assert_true(scene_ok, "前置：存档应成功")
	GameData.flags.erase(ROAD_CHAT_FLAG)   # 模拟跨会话内存清零
	assert_true(SaveManager.load_save(), "前置：读档应成功")
	assert_true(GameData.flags.has(ROAD_CHAT_FLAG),
			"已触发标记应随存档还原（删档/回档前不重播，读档后保持已看）")


# ------------------------------------------------------------------
# Group D —— 装配面（road/f2 薄壳同位 + 协议属性 + 目录对表）
# ------------------------------------------------------------------

func test_d1_road地图装配薄壳同位且协议齐备() -> void:
	var map: Node2D = _make_map(RoadMapScript, "Anchors")
	var built: Array = Assembler.assemble(map, "road", null)
	assert_eq(built.size(), 1, "road 应装配 1 处聊天点")
	var trigger: Area2D = built[0]
	assert_eq(String(trigger.new_event_id), ROAD_CHAT_EVENT, "薄壳应指向道路聊天事件")
	assert_true(String(trigger.event_id).begins_with("chat_point_"),
			"薄壳 event_id 应带 chat_point_ 前缀（调试定位）")
	assert_eq(trigger.position, Vector2(35 * 16 + 8, 31 * 16 + 8),
			"薄壳应落在目录格中心（road (35,31)，BFS 主路径近心位）")
	assert_eq(int(trigger.collision_layer), 0, "纯踩踏面：自身不被交互射线检测")
	assert_eq(int(trigger.collision_mask), 16, "踩踏面应监测玩家实体层（mask=16）")
	# 【T4.3 扩区拍板】road 命中区 3×2（48×32 px）：y=31/32 林墙带开口仅
	# x=35/36，2×2 只覆盖 35 整格 + 邻格各半，扩 3×2 后开口整格全覆盖
	var road_shape: RectangleShape2D = (trigger.get_node("CollisionShape2D").shape
			as RectangleShape2D)
	assert_eq(road_shape.size, Vector2(48, 32), "road 命中区应为 3×2（48×32 px，T4.3 拍板）")
	var parent: Node = trigger.get_parent()
	assert_eq(String(parent.get_parent().name), "YSorted", "实体应挂 YSorted/Anchors 容器")


func test_d2_f2地图装配薄壳同位且目录隔离() -> void:
	var map: Node2D = _make_map(F2MapScript, "Anchors")
	var built: Array = Assembler.assemble(map, "ruins_f2", null)
	assert_eq(built.size(), 1, "ruins_f2 应装配 1 处聊天点")
	var trigger: Area2D = built[0]
	assert_eq(String(trigger.new_event_id), F2_CHAT_EVENT, "薄壳应指向二层聊天事件")
	assert_eq(trigger.position, Vector2(23 * 16 + 8, 8 * 16 + 8),
			"薄壳应落在目录格中心（f2 (23,8)，入口前厅必经位）")
	# 目录隔离：road 事件不得装进 f2（反之亦然）——assemble 按 map 字段过滤
	assert_ne(String(trigger.new_event_id), ROAD_CHAT_EVENT, "目录隔离：f2 不装 road 段")
	# f2 命中区维持 2×2（T4.3 扩区仅 road，目录字段化后互不牵连）
	var f2_shape: RectangleShape2D = (trigger.get_node("CollisionShape2D").shape
			as RectangleShape2D)
	assert_eq(f2_shape.size, Vector2(32, 32), "f2 命中区应维持 2×2（32×32 px，T4.3 不扩）")


func test_d3_无容器图装配安全降级不炸() -> void:
	# 无 YSorted/Anchors 容器（异常态）：警告 + 返回空数组（降级不 crash，
	# 与 TeleportAssembler 无 Triggers 容器同口径）
	var map: Node2D = autofree(F2MapScript.new())
	var built: Array = Assembler.assemble(map, "ruins_f2", null)
	assert_eq(built.size(), 0, "无容器应安全降级返回空")


func test_d4_地图脚本声明chat_points承接字段() -> void:
	# _ready 接线承载：两图脚本应有 chat_points 属性且 _ready 含装配调用
	# （静态断言防装配调用被误删——真实 _ready 全链路由 E 组/T4.1 冒烟兜底）
	var road_map: Node2D = autofree(RoadMapScript.new())
	var f2_map: Node2D = autofree(F2MapScript.new())
	var road_props: Array = road_map.get_property_list().map(
			func(p: Dictionary) -> String: return String(p["name"]))
	var f2_props: Array = f2_map.get_property_list().map(
			func(p: Dictionary) -> String: return String(p["name"]))
	assert_true("chat_points" in road_props, "road_map 应声明 chat_points 承接字段")
	assert_true("chat_points" in f2_props, "ruins_f2_map 应声明 chat_points 承接字段")


# ------------------------------------------------------------------
# Group E —— T4.1 回归（菜单存/读档链路在本 Story 改动后零回归）
# ------------------------------------------------------------------

func test_e1_菜单存档确认链路回归() -> void:
	_menu = MenuPanelScript.new()
	add_child_autofree(_menu)
	_menu.try_open()
	_menu.confirm_current()   # 光标默认 "status"——先确认不误触
	_menu.move_cursor(1)
	_menu.move_cursor(1)
	_menu.move_cursor(1)
	assert_eq(_menu.current_item_id(), "save", "前置：光标在存档项")
	_menu.confirm_current()
	assert_true(SaveManager.has_save(), "T4.1 回归：存档确认应即时落盘")
	assert_false(_menu.is_open(), "T4.1 回归：存档成功应关菜单")


func test_e2_菜单读档确认链路回归() -> void:
	_menu = MenuPanelScript.new()
	add_child_autofree(_menu)
	# 先落一份档（直接走 SaveManager，T4.1 语义）
	GameData.story_phase = 2
	assert_true(SaveManager.save("ruins_f2", Vector2(100, 100)), "前置：测试档落盘")
	GameData.story_phase = 0   # 内存态改动，读档后应被回滚
	_menu.try_open()
	for _i: int in 4:
		_menu.move_cursor(1)
	assert_eq(_menu.current_item_id(), "load", "前置：光标在读档项")
	_menu.confirm_current()
	assert_true(SaveManager.last_loaded.has("map"), "T4.1 回归：读档确认应回灌 GameData")
	assert_eq(GameData.story_phase, 2, "T4.1 回归：读档应回滚 story_phase（存档值）")
	assert_false(_menu.is_open(), "T4.1 回归：读档成功应关菜单")


func test_e3_菜单存档与事件save_point落盘格式同构() -> void:
	# E6-S4 验收②"手动存档与自动存档格式一致"的结构面：同 schema 版本 +
	# 同字段集（行为面交叉覆盖由 T4.1 B 组承载）
	_menu = MenuPanelScript.new()
	add_child_autofree(_menu)
	_menu.try_open()
	for _i: int in 3:
		_menu.move_cursor(1)
	_menu.confirm_current()
	var manual: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(SAVE_TEST_PATH))
	assert_true(typeof(manual) == TYPE_DICTIONARY, "前置：手动档应可解析")
	assert_eq(int((manual as Dictionary).get("version")), SaveManager.SCHEMA_VERSION,
			"手动档版本应 = 当前 schema 版本（与自动存档同构）")
	assert_true((manual as Dictionary).has("flags"), "手动档应含 flags（聊天标记随档持久）")
