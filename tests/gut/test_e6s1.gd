extends GutTest
## E6-S1 主菜单三页 · T3.1 菜单壳 + 状态页（EPIC-6 第 1 条 Story 前半）
##
## 【断言覆盖】（对应 EPIC-6.md E6-S1 验收点的 T3.1 可自动化子集）
##   A. 菜单壳与导航：五条目齐全（状态/道具/装备/存档/读档）、↑↓ 移动
##      跳过置灰项（读档项按 SaveManager.has_save() 置灰，规格 §3.1）、
##      C 呼出 / X·Esc 关闭、开启态模态吞键（防漏给地图侧触发器）；
##   B. 开合门闸：对话进行中 / 战斗中 / 转场中不开（三门闸逐一锚定）；
##   C. 状态页渲染：三块按 GameData.party 直读（名字/Lv/HP·MP 数值与条宽）
##      + 面板六维按 DataTables.stats_at 派生对表 + 莉娜头像 rina_* 映射 + 
##      死亡块置灰（规格 §3.1）；
##   D. 冻结坐标与 9-slice：指令窗 (16,16,96,136)、状态面板 (128,16,496,328)、
##      块顶 y=32/136/240（规格 §3.1 自查表逐项）；窗体为 NineSlicePanel
##      （patch_count ≥ 9，边条平铺禁拉伸——E6-S1 验收第 4 条的可自动化面）；
##   E. 装配面：town_map._assemble_menu 装配产物就位、幂等（二次装配不重复）。
##
## 【测试策略】UI 直驱（e6s2 BattleUI 同款：new + ensure_built，脱离场景树）；
##   GameData 快照/还原隔离 + SceneRouter 簿记重置 + SaveManager.save_path
##   覆写指空（e6s3 同款）；town 装配用例直挂场景树实例化 town.tscn
##   （e1s6 包装器同款思路，GUT 内联）。

const MenuPanelScript := preload("res://scripts/ui/menu_panel.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")
const ItemDataScript := preload("res://scripts/data/item_data.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
const PORTRAIT_CATALOG := preload("res://scripts/dialogue/portrait_catalog.gd")
const TOWN_SCENE := preload("res://scenes/maps/town.tscn")

## 跨用例隔离用的快照（before_all 取，after_all 还原——e6s3 同款三件套）
var _party_backup: Array = []
var _inventory_backup: Dictionary = {}
var _equip_backup: Array = []
var _phase_backup: int = 0

var _menu: Control = null


func before_all() -> void:
	_ensure_party_3()   # 防跨套件 party 泄漏（e5s3 教训，防御性兜底）
	for c: Resource in GameData.party:
		_party_backup.append({
			"id": c.id, "level": c.level, "hp": c.hp, "max_hp": c.max_hp,
			"mp": c.mp, "max_mp": c.max_mp,
			"weapon_id": c.weapon_id, "armor_id": c.armor_id})
	_inventory_backup = GameData.inventory.duplicate()
	_equip_backup = GameData.owned_equipment.duplicate()
	_phase_backup = GameData.story_phase


func after_all() -> void:
	for i: int in GameData.party.size():
		var c: Resource = GameData.party[i]
		var b: Dictionary = _party_backup[i]
		c.level = b["level"]
		c.hp = b["hp"]
		c.max_hp = b["max_hp"]
		c.mp = b["mp"]
		c.max_mp = b["max_mp"]
		c.weapon_id = b["weapon_id"]
		c.armor_id = b["armor_id"]
	GameData.inventory = _inventory_backup.duplicate()
	GameData.owned_equipment = _equip_backup.duplicate()
	GameData.story_phase = _phase_backup


func before_each() -> void:
	_menu = MenuPanelScript.new()
	add_child_autofree(_menu)   # 入树：_ready → ensure_built（visible=false 默认关闭）
	# Router 簿记重置（E2-S4 同款隔离）：干净起点 = 探索图、无转场
	SceneRouter._staged_payload = {}
	SceneRouter.current_scene_path = ""
	SceneRouter._switching = false
	SaveManager.save_path = "user://e6s1_no_such_dir/cannot_exist.json"
	SaveManager.save_requested_pending = false


func after_each() -> void:
	_menu = null
	SaveManager.save_path = SaveManager.SAVE_PATH
	after_all()


## 队伍兜底（e6s2/e6s3 同款）
func _ensure_party_3() -> void:
	var wanted: Array[String] = ["kyle", "lina", "mona"]
	for cid: String in wanted:
		var found := false
		for c: Resource in GameData.party:
			if c.id == cid:
				found = true
				break
		if not found:
			var cd: Variant = DataTables.get_character(cid)
			if cd != null:
				GameData.party.append(cd)


## 合成 C 键按下事件（physical C=67，与 project.godot menu 动作键位一致）
func _key_c() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_C
	ev.pressed = true
	return ev


## 合成 X 键按下事件（cancel 动作主键位）
func _key_x() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_X
	ev.pressed = true
	return ev


## 合成 Esc 键按下事件（cancel 动作副键位；Godot 特殊键 = keycode 通道）
func _key_esc() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	return ev


## 合成 ↓ 键（move_down 主键位，装备页角色/槽位态用）
func _down_key() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_S
	ev.pressed = true
	return ev


## 合成 Z 键（interact 确认主键位——子模态事件通道驱动用）
func _confirm_event() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_Z
	ev.pressed = true
	return ev


# =============== A. 菜单壳与导航 ===============

func test_五条目齐全与顺序() -> void:
	assert_eq(_menu.ITEM_IDS, ["status", "item", "equip", "save", "load"],
			"五条目槽位序按规格 §3.1：状态/道具/装备/存档/读档")
	assert_false(_menu.is_open(), "初始关闭态")


func test_C键呼出_X与Esc关闭() -> void:
	assert_true(_menu._consume_event(_key_c()), "C 键应被消费并呼出菜单")
	assert_true(_menu.is_open(), "C 呼出后菜单开启")
	# X 关闭
	assert_true(_menu._consume_event(_key_x()), "X 键应被消费（cancel 主键位）")
	assert_false(_menu.is_open(), "X 关闭菜单")
	# Esc 关闭（cancel 副键位）
	_menu._consume_event(_key_c())
	assert_true(_menu.is_open())
	assert_true(_menu._consume_event(_key_esc()), "Esc 键应被消费（cancel 副键位）")
	assert_false(_menu.is_open(), "Esc 关闭菜单")


func test_读档项按has_save置灰且光标跳过() -> void:
	# save_path 指空目录 → has_save()=false → 读档置灰
	assert_false(SaveManager.has_save(), "前置：无存档文件")
	_menu.try_open()
	assert_true(_menu.is_item_disabled("load"), "无存档时读档应置灰（规格 §3.1）")
	assert_false(_menu.is_item_disabled("status"), "状态项恒可用")
	# ↓×3 从 status 走到 save，再 ↓ 应跳过置灰的 load 回绕到 status
	_menu.move_cursor(1)   # item
	_menu.move_cursor(1)   # equip
	_menu.move_cursor(1)   # save
	assert_eq(_menu.current_item_id(), "save", "三次 ↓ 应落在存档项")
	_menu.move_cursor(1)
	assert_eq(_menu.current_item_id(), "status",
			"读档置灰时光标应跳过回绕到状态项（不落在置灰项）")
	# 造一个存档文件 → 读档项解除置灰
	SaveManager.save_path = "user://e6s1_probe"
	assert_true(SaveManager.save("res://test", Vector2.ZERO), "造测试存档")
	# 重新打开重算置灰态（打开时重算口径）
	_menu.close()
	_menu.try_open()
	assert_false(_menu.is_item_disabled("load"), "有存档后读档项应解除置灰")
	DirAccess.remove_absolute("user://e6s1_probe")


func test_开启态模态吞键_关闭态放行() -> void:
	# 关闭态：非菜单键放行不消费（游戏世界照常收到）。KEY_N 不在
	# menu/cancel/move_*/interact 任何动作里——纯"无关按键"。
	var noise := InputEventKey.new()
	noise.physical_keycode = KEY_N
	noise.pressed = true
	assert_false(_menu._consume_event(noise), "关闭态无关按键应放行")
	# 开启态：模态——识别键处理，其余键一律吞
	_menu.try_open()
	assert_true(_menu._consume_event(noise), "开启态应吞掉无关按键（模态）")
	assert_eq(_menu.get_cursor_index(), 0, "无关按键不得移动光标")
	var down := InputEventKey.new()
	down.physical_keycode = KEY_S
	down.pressed = true
	assert_true(_menu._consume_event(down), "开启态 ↓ 应被消费")
	assert_eq(_menu.get_cursor_index(), 1, "↓ 移动光标到道具项")
	assert_true(_menu._consume_event(_key_x()))
	assert_false(_menu.is_open(), "模态期间取消键仍应生效")


# =============== B. 开合门闸 ===============

func test_对话进行中不开菜单() -> void:
	# 模拟对话占用：宿主下挂一个 is_idle()=false 的极小假 runner。
	# 门闸只认 has_method("is_idle") 与返回值（A7 协议判定同款）；
	# 不用真 runner（进 PLAYING 需 JSON 脚本，且 _process 逐字计时器对空表有风险）。
	# 生成节点名：Godot 对重名自动加 @后缀——显式命名防 get_node_or_null 失配。
	var host := Node.new()
	host.name = "UILayerE6S1"
	add_child_autofree(host)
	var runner := Node.new()
	runner.name = "DialogueRunner"
	var idle_script := GDScript.new()
	idle_script.source_code = "extends Node\nfunc is_idle() -> bool:\n\treturn false\n"
	idle_script.reload()
	runner.set_script(idle_script)
	host.add_child(runner)
	assert_false(runner.is_idle(), "前置：假 runner 报告对话进行中")
	# 菜单当前挂在测试用例自身之下，移挂到 host（模拟 UILayer 宿主语义）
	_menu.reparent(host)
	assert_eq(_menu.get_parent(), host, "前置：菜单已移挂到宿主")
	assert_not_null(_menu.get_parent().get_node_or_null("DialogueRunner"),
			"前置：门闸查询口可达假 runner")
	assert_false(_menu.try_open(), "对话进行中不得打开菜单")
	assert_false(_menu.is_open(), "门闸拒绝后保持关闭")


func test_战斗中不开菜单() -> void:
	SceneRouter.current_scene_path = SceneRouter.BATTLE_SCENE_PATH
	assert_false(_menu.try_open(), "战斗场景中不得打开菜单")
	SceneRouter.current_scene_path = ""
	assert_true(_menu.try_open(), "回到探索图后可正常打开")


func test_转场中不开菜单() -> void:
	SceneRouter._switching = true
	assert_false(_menu.try_open(), "淡入淡出期间不得打开菜单")
	SceneRouter._switching = false
	assert_true(_menu.try_open(), "转场结束后可正常打开")


# =============== C. 状态页渲染 ===============

func test_状态页三块数值对表() -> void:
	_menu.try_open()
	# GameData 初始态：kyle 120/10、lina 80/30、mona 95/24（Lv1）
	var names: Array[String] = []
	for i: int in 3:
		var b: Dictionary = _menu.get_block(i)
		names.append((b["name"] as Label).text)
	assert_eq(names, ["凯尔", "莉娜", "莫娜"], "三块名字按槽位序渲染")
	# 六维派生对表（kyle Lv1：ATK14 MAG4 DEF10 SPD12）
	var b0: Dictionary = _menu.get_block(0)
	assert_eq((b0["atk"] as Label).text, "ATK14")
	assert_eq((b0["mag"] as Label).text, "MAG4")
	assert_eq((b0["def"] as Label).text, "DEF10")
	assert_eq((b0["spd"] as Label).text, "SPD12")
	# HP/MP 数值与条宽（满血 → 条宽=BAR_W）
	assert_eq((b0["hp_val"] as Label).text, "120/120")
	assert_eq((b0["mp_val"] as Label).text, "10/10")
	assert_eq((b0["hp_fill"] as ColorRect).size.x,
			_menu.BAR_W, "满血条宽应等于条宽常量")
	assert_eq((b0["lv"] as Label).text, "Lv1")
	# 升级后重刷：kyle Lv2 六维走 stats_at 派生（ATK 14+3=17）
	var kyle: Resource = GameData.party[0]
	kyle.level = 2
	_menu.refresh_status_page()
	assert_eq((b0["atk"] as Label).text, "ATK17", "Lv2 面板应走 stats_at 派生")
	assert_eq((b0["lv"] as Label).text, "Lv2")
	kyle.level = 1


func test_莉娜头像rina映射与降级() -> void:
	# portrait_catalog 注册名口径：lina → rina_normal（占位映射声明）
	assert_true(PORTRAIT_CATALOG.PORTRAIT_REGIONS.has("rina_normal"),
			"莉娜差分注册名应为 rina_*")
	assert_not_null(PORTRAIT_CATALOG.get_texture("rina_normal"),
			"rina_normal 应可解析出 48×48 纹理")
	_menu.try_open()
	var b1: Dictionary = _menu.get_block(1)
	var face: TextureRect = b1["face"]
	assert_true(face.visible, "莉娜块头像窗应可见")
	assert_eq(face.texture.get_width(), 48, "头像纹理原生 48px（零缩放口径）")
	assert_eq(face.size, Vector2(48, 48), "头像窗 48×48 不缩放")


func test_死亡块置灰_满血块不置灰() -> void:
	var kyle: Resource = GameData.party[0]
	kyle.hp = 0   # 造死亡
	_menu.try_open()
	var b0: Dictionary = _menu.get_block(0)
	assert_eq((b0["root"] as Control).modulate, _menu.C_GRAY,
			"HP=0 角色块应整块置灰 #8E7F98（规格 §3.1）")
	var b1: Dictionary = _menu.get_block(1)
	assert_eq((b1["root"] as Control).modulate, Color.WHITE,
			"满血角色块不得置灰")
	kyle.hp = 120   # 还原


# =============== D. 冻结坐标与 9-slice ===============

func test_冻结坐标对表() -> void:
	assert_eq(_menu.get_cmd_window().position, Vector2(16, 16), "指令窗坐标")
	assert_eq(_menu.get_cmd_window().size, Vector2(96, 136), "指令窗尺寸 5×24+16")
	assert_eq(_menu.get_status_panel().position, Vector2(128, 16), "状态面板坐标")
	assert_eq(_menu.get_status_panel().size, Vector2(496, 328), "状态面板尺寸")
	# 三块块顶 y=32/136/240（规格自查表）
	for i: int in 3:
		var b: Dictionary = _menu.get_block(i)
		assert_eq((b["root"] as Control).position.y, float(32 + i * 104),
				"块 %d 块顶 y 应为冻结值" % i)
		assert_eq((b["root"] as Control).size, Vector2(480, 96), "块尺寸 480×96")


func test_窗体为九宫格且边距8() -> void:
	assert_eq(_menu.get_cmd_window().MARGIN, 8.0, "切分边距 8px（规格 §3.2）")
	assert_true(_menu.get_cmd_window().patch_count() >= 9,
			"窗体拼块数 ≥9（非单一拉伸矩形，验收第 4 条）")
	assert_true(_menu.get_status_panel().patch_count() >= 9,
			"状态面板同为 9-slice")


# =============== F. 道具页（T3.2） ===============
# 口径：EPIC-6 E6-S1 验收第 2 条"道具使用遵守可用阶段字段"；
# 写回口径 = 战斗侧 _do_item / BattleLogic.heal_unit（mini 钳制上限）。

func test_道具页打开_过滤与行序() -> void:
	# 背包预置：potion_s ×2（both→显示）、antidote ×1（both→显示）、
	# 库存 0 条目与战斗专用道具均被过滤（战斗专用当前无 .tres，用 0 库存代表）
	GameData.inventory = {"potion_s": 2, "antidote": 1, "potion_m": 0}
	_menu.try_open()
	_menu.move_cursor(1)      # status → item
	_menu.confirm_current()   # 进道具页
	assert_true(_menu.is_item_page_open(), "确认道具项应进入道具子模态")
	assert_eq(_menu.get_mode(), "item_list", "子模态应为列表态")
	# 行序 = 背包插入序过滤后：potion_s → antidote（potion_m 库存 0 被滤）
	assert_eq(_menu.get_item_page_entries(), {"potion_s": 2, "antidote": 1},
			"0 库存条目应被过滤，行序按背包插入序")


func test_阶段字段过滤_地图不可用道具不进列表() -> void:
	# 口径验证：构造 usable_phase="battle" 的道具 → usable_in_map()=false → 不显示
	GameData.inventory = {"potion_s": 1}
	var battle_only: Resource = ItemDataScript.new()
	battle_only.id = "battle_only_test"
	battle_only.name = "战斗兴奋剂"
	battle_only.kind = "heal_hp"
	battle_only.value = 10
	battle_only.usable_phase = "battle"
	battle_only.description = "仅战斗可用（测试造数）"
	# 不注册进 DataTables（只读表），直接验证过滤函数口径：
	assert_false(battle_only.usable_in_map(),
			"battle 阶段字段道具应被判地图不可用（验收第 2 条口径）")
	assert_true(battle_only.usable_in_battle(),
			"battle 阶段字段道具战斗侧应可用（不回归）")
	# 道具页列表只含 potion_s
	_menu.try_open()
	_menu.move_cursor(1)
	_menu.confirm_current()
	assert_eq(_menu.get_item_page_entries(), {"potion_s": 1})


func test_列表光标移动与回绕() -> void:
	GameData.inventory = {"potion_s": 1, "potion_m": 1, "potion_l": 1,
			"ether_s": 1, "antidote": 1}
	_menu.try_open()
	_menu.move_cursor(1)
	_menu.confirm_current()
	assert_eq(_menu.get_current_item_id(), "potion_s", "初始光标在首行")
	_menu._item_move(1)
	assert_eq(_menu.get_current_item_id(), "potion_m", "↓ 到第二行")
	_menu._item_move(-1)
	assert_eq(_menu.get_current_item_id(), "potion_s", "↑ 回首行")
	_menu._item_move(-1)
	assert_eq(_menu.get_current_item_id(), "antidote", "首行 ↑ 回绕到末行")


func test_取消回主菜单_层级不弹穿() -> void:
	GameData.inventory = {"potion_s": 1}
	_menu.try_open()
	_menu.move_cursor(1)
	_menu.confirm_current()   # 进列表态
	# 列表态 X → 回主模态（菜单仍开着）
	assert_true(_menu._consume_event(_key_x()), "列表态 X 应被消费")
	assert_false(_menu.is_item_page_open(), "X 应退回主模态")
	assert_true(_menu.is_open(), "列表态 X 只收子窗，主菜单不关")
	# 目标态 X → 回列表态（不直接关菜单、不落回地图）
	_menu.confirm_current()
	assert_eq(_menu.get_mode(), "item_list")
	_menu._item_confirm()
	assert_eq(_menu.get_mode(), "item_target", "列表确认应进目标选择")
	assert_true(_menu._consume_event(_key_x()), "目标态 X 应被消费")
	assert_eq(_menu.get_mode(), "item_list", "目标态 X 应回列表态")
	assert_true(_menu.is_open(), "目标态 X 不得关主菜单")
	# 列表态 X → 回主模态，再一次 X 才关整菜单（层级逐层退出）
	assert_true(_menu._consume_event(_key_x()), "列表态 X 应被消费")
	assert_false(_menu.is_item_page_open(), "列表态 X 收子窗回主模态")
	assert_true(_menu.is_open(), "主模态下菜单仍开")
	assert_true(_menu._consume_event(_key_x()))
	assert_false(_menu.is_open(), "主模态 X 关闭整菜单")


func test_空背包_Z静默_X可退() -> void:
	GameData.inventory = {}
	_menu.try_open()
	_menu.move_cursor(1)
	_menu.confirm_current()   # 空列表确认
	assert_true(_menu.is_item_page_open(), "空背包仍进道具页（显示提示文案）")
	_menu._item_confirm()     # 空列表 Z 静默
	assert_eq(_menu.get_mode(), "item_list", "空列表确认不得进目标态（无死层）")
	assert_true(_menu._consume_event(_key_x()))
	assert_false(_menu.is_item_page_open(), "X 可正常退出")


func test_用药写回_HP钳制与库存扣减() -> void:
	var kyle: Resource = GameData.party[0]
	kyle.hp = 100   # 120 上限，扣 40
	GameData.inventory = {"potion_s": 2}
	_menu.try_open()
	_menu.move_cursor(1)
	_menu.confirm_current()      # 列表态，光标 potion_s
	_menu._item_confirm()        # 进目标态，默认目标 0（凯尔）
	assert_eq(_menu.get_mode(), "item_target")
	assert_true(_menu._apply_item(), "用药应生效")
	assert_eq(kyle.hp, 120, "HP 应写回 100+40 并钳制在 120 上限")
	assert_eq(int(GameData.inventory["potion_s"]), 1, "库存应扣一")
	# 连续用药：剩余 1 瓶再吃，库存归 0
	assert_true(_menu._apply_item(), "第二瓶应继续生效（留在目标态）")
	assert_eq(int(GameData.inventory["potion_s"]), 0, "库存归零")
	assert_eq(kyle.hp, 120, "满血吃药钳制不溢出")


func test_用药写回_MP与解毒地图态语义() -> void:
	# MP 回复走 mini 钳制；解毒在地图态无数值变化但扣库存（裁决：
	# CharacterRecord 无中毒字段，真实清毒在战斗侧，地图态不隐藏该道具）
	var lina: Resource = GameData.party[1]
	lina.mp = 20   # 30 上限
	GameData.inventory = {"ether_s": 1, "antidote": 1}
	_menu.try_open()
	_menu.move_cursor(1)
	_menu.confirm_current()   # 列表态（ether_s 在前）
	_menu._item_confirm()
	_menu._target_move(1)     # 目标 0(凯尔)→1(莉娜)
	assert_eq(_menu._item_target, 1, "目标应移到莉娜槽位")
	_menu._apply_item()
	assert_eq(lina.mp, 30, "MP 应写回 20+15 钳制 30 上限")
	assert_eq(int(GameData.inventory["ether_s"]), 0)
	# 解毒：库存扣一、数值无变化
	_menu._item_move(1)   # 光标到 antidote
	_menu._item_confirm()
	_menu._apply_item()
	assert_eq(int(GameData.inventory["antidote"]), 0, "解毒应扣库存")
	assert_eq(lina.hp, 80, "解毒不得改动 HP（规则型效果无数值）")
	assert_eq(lina.mp, 30, "解毒不得改动 MP")


func test_目标选择_移动与跨目标写回() -> void:
	var kyle: Resource = GameData.party[0]
	var mona: Resource = GameData.party[2]
	kyle.hp = 120
	mona.hp = 50   # 95 上限
	GameData.inventory = {"potion_m": 1}
	_menu.try_open()
	_menu.move_cursor(1)
	_menu.confirm_current()
	_menu._item_confirm()      # 目标态，默认 0 凯尔
	_menu._target_move(1)      # → 莉娜
	_menu._target_move(1)      # → 莫娜
	assert_eq(_menu._item_target, 2, "两次 ↓ 目标应到莫娜槽位")
	_menu._apply_item()
	assert_eq(mona.hp, 95, "药应落在莫娜身上（50+45 钳制 95）")
	assert_eq(kyle.hp, 120, "凯尔不受影响")


func test_用药后死亡块置灰解除与状态页回显() -> void:
	var kyle: Resource = GameData.party[0]
	kyle.hp = 0   # 死亡
	GameData.inventory = {"potion_m": 1}
	_menu.try_open()
	var b0: Dictionary = _menu.get_block(0)
	assert_eq((b0["root"] as Control).modulate, _menu.C_GRAY, "前置：死亡块置灰")
	_menu.move_cursor(1)
	_menu.confirm_current()
	_menu._item_confirm()
	_menu._apply_item()
	assert_eq(kyle.hp, 100, "死亡可被道具拉起（0+100；复活无门禁=战斗侧同口径）")
	assert_eq((b0["root"] as Control).modulate, Color.WHITE,
			"复活后块置灰应解除（状态页即时回显）")
	kyle.hp = 120


func test_道具页冻结坐标与九宫格() -> void:
	assert_eq(_menu.get_item_window().position, Vector2(144, 32), "道具子窗坐标")
	assert_eq(_menu.get_item_window().size, Vector2(232, 208), "道具子窗尺寸 8 行+描述区")
	assert_eq(_menu.get_item_window().MARGIN, 8.0, "子窗切分边距 8px")
	assert_true(_menu.get_item_window().patch_count() >= 9, "子窗同为 9-slice")


# =============== G. 装备页（T3.3） ===============
# 口径：EPIC-6 E6-S1 验收第 3 条"装备更换即时反映到 ATK/DEF 面板与战斗伤害"。

func test_装备三态导航_角色到槽位到列表() -> void:
	GameData.owned_equipment = ["iron_sword", "leather_armor"]
	_menu.try_open()
	_menu.move_cursor(2)      # status → equip（中间跳过 item）
	assert_eq(_menu.current_item_id(), "equip")
	_menu.confirm_current()   # 主模态入口：进角色选择态
	assert_eq(_menu.get_mode(), "equip_char", "确认装备项应进角色选择态")
	# 角色态全走事件通道：↓ 移到莉娜 → Z 确认进槽位态
	assert_true(_menu._consume_event(_down_key()), "角色态 ↓ 应被消费")
	assert_eq(_menu._equip_char, 1, "↓ 应把角色光标移到莉娜")
	_menu._consume_equip_char(_confirm_event())
	assert_eq(_menu.get_mode(), "equip_slot", "角色确认应进槽位选择态")
	assert_eq(_menu._equip_slot, 0, "进槽位态应重置为武器槽")
	_menu._consume_equip_slot(_confirm_event())
	assert_eq(_menu.get_mode(), "equip_list", "槽位确认应进装备列表态")


func test_装备列表_按槽位过滤与卸下条目() -> void:
	GameData.owned_equipment = ["iron_sword", "leather_armor"]
	# 武器槽：只见 iron_sword，凯尔未装 → 无卸下行（2 条目=1 装备）
	_menu.try_open()
	_menu._open_equip_char_select()
	_menu._equip_char = 0
	_menu._equip_slot = 0
	_menu._open_equip_list()
	assert_eq(_menu._equip_ids, ["iron_sword"], "武器槽只该有铁剑")
	assert_false(_menu._equip_cursor >= _menu._equip_ids.size(),
			"未装武器时无卸下条目")
	# 装上后再开：出现卸下条目（条目总数 = 1 装备 + 1 卸下）
	GameData.party[0].weapon_id = "iron_sword"
	GameData.owned_equipment = ["leather_armor"]
	_menu._open_equip_list()
	assert_eq(_menu._equip_ids.size(), 0, "铁剑已装，池中无武器")
	assert_true(_menu._equip_cursor < 1, "卸下行在光标 0 位")
	GameData.party[0].weapon_id = ""
	GameData.owned_equipment = ["iron_sword", "leather_armor"]


func test_换装写回_ATK面板即时反映() -> void:
	GameData.owned_equipment = ["iron_sword", "leather_armor"]
	var kyle: Resource = GameData.party[0]
	kyle.weapon_id = ""
	_menu.try_open()          # 打开时刷新状态页：未装 → ATK14
	var b0: Dictionary = _menu.get_block(0)
	assert_eq((b0["atk"] as Label).text, "ATK14", "前置：未装备 ATK14")
	_menu._open_equip_char_select()
	_menu._equip_char = 0
	_menu._equip_slot = 0
	_menu._open_equip_list()
	_menu._equip_cursor = 0   # iron_sword
	assert_true(_menu._apply_equipment_change(), "换装应生效")
	assert_eq(String(kyle.weapon_id), "iron_sword", "武器字段应写回铁剑")
	assert_eq((b0["atk"] as Label).text, "ATK17", "面板应即时反映 ATK14+3=17")
	assert_eq(GameData.owned_equipment, ["leather_armor"], "铁剑应出池")
	# 卸下：回 ATK14、铁剑回池
	_menu._open_equip_list()
	_menu._equip_cursor = _menu._equip_ids.size()   # 卸下行
	_menu._apply_equipment_change()
	assert_eq(String(kyle.weapon_id), "", "卸下后武器字段应清空")
	assert_eq((b0["atk"] as Label).text, "ATK14", "卸下后面板回 ATK14")
	assert_eq(GameData.owned_equipment, ["leather_armor", "iron_sword"],
			"卸下的铁剑应回池")


func test_换装防具_DEF反映与旧装回池不重复() -> void:
	GameData.owned_equipment = ["iron_sword", "leather_armor"]
	var lina: Resource = GameData.party[1]
	lina.armor_id = ""
	_menu.try_open()
	var b1: Dictionary = _menu.get_block(1)
	# 莉娜 Lv1 数值锚 = lina.tres 真相：base_def=6（per_level.def=2）
	assert_eq((b1["def"] as Label).text, "DEF6", "前置：莉娜 Lv1 DEF6")
	_menu._open_equip_char_select()
	_menu._equip_char = 1
	_menu._equip_slot = 1    # 防具槽
	_menu._open_equip_list()
	assert_eq(_menu._equip_ids, ["leather_armor"], "防具槽只该有皮甲")
	_menu._equip_cursor = 0
	_menu._apply_equipment_change()
	assert_eq(String(lina.armor_id), "leather_armor")
	assert_eq((b1["def"] as Label).text, "DEF8", "DEF6+2=8 即时反映")
	# 再换装同槽另一件时旧装回池且不重复（切片内单件，验证防重复守卫）
	lina.armor_id = "leather_armor"
	_menu._apply_equipment_change()   # 光标仍在皮甲行 → 同件 no-op
	assert_eq(String(lina.armor_id), "leather_armor", "同件确认应无变化")
	lina.armor_id = ""


func test_并项函数_面板与战斗同源() -> void:
	# apply_equipment 纯函数直验：六维只动 atk/def，hp/mp/mag/spd 透传
	var base: Dictionary = {"hp": 120, "mp": 10, "atk": 14, "mag": 4, "def": 10, "spd": 12}
	var boosted: Dictionary = BattleUnits.apply_equipment(base, "iron_sword", "leather_armor")
	assert_eq(int(boosted["atk"]), 17, "武器 ATK+3 应叠加")
	assert_eq(int(boosted["def"]), 12, "防具 DEF+2 应叠加")
	assert_eq(int(boosted["hp"]), 120, "HP 不受装备影响")
	assert_eq(int(boosted["mag"]), 4, "MAG 不受装备影响")
	# build_party_unit 带装备参数：战斗单位 atk = 面板同源值
	var u: Dictionary = BattleUnits.build_party_unit("kyle", 1,
			{"weapon_id": "iron_sword", "armor_id": ""})
	assert_eq(int(u["atk"]), 17, "战斗单位 ATK 应含武器加成（面板同源）")
	assert_eq(int(u["def"]), 10, "只装武器时 DEF 不变")
	# 未知装备 id 防御：按 0 加成跳过不炸
	var dirty: Dictionary = BattleUnits.apply_equipment(base, "no_such_sword", "")
	assert_eq(int(dirty["atk"]), 14, "未知装备 id 应按 0 加成跳过")


func test_装备伤害并项_物理公式真值传导() -> void:
	# 验收第 3 条"反映到战斗伤害"的公式级验证：
	# ATK17（装剑凯尔）vs ATK14（裸装）对同一目标，伤害区间整体上移
	var bare: Dictionary = BattleUnits.build_party_unit("kyle", 1)
	var armed: Dictionary = BattleUnits.build_party_unit("kyle", 1,
			{"weapon_id": "iron_sword", "armor_id": ""})
	# 注意：build_enemy_unit 收"敌人 id"（moth.tres），b1_moth 是编组 id
	# （build_encounter 才收）——首轮把编组 id 当敌人 id 传入拿空字典炸 def
	var enemy: Dictionary = BattleUnits.build_enemy_unit("moth", 0)
	const BattleLogic := preload("res://scripts/core/battle_logic.gd")
	var range_bare: Vector2i = BattleLogic.physical_damage_range(
			int(bare["atk"]), int(enemy["def"]), 1.0, 1.0)
	var range_armed: Vector2i = BattleLogic.physical_damage_range(
			int(armed["atk"]), int(enemy["def"]), 1.0, 1.0)
	assert_true(range_armed.x > range_bare.x,
			"装备后伤害下界应上移（%d→%d）" % [range_bare.x, range_armed.x])
	assert_true(range_armed.y > range_bare.y,
			"装备后伤害上界应上移（%d→%d）" % [range_bare.y, range_armed.y])


func test_初始背包直塞_两件装备与默认未装() -> void:
	# GameData 初始态裁定：池=[铁剑,皮甲]，三人身上全空（ATK14 对表不破坏）
	assert_eq(GameData.owned_equipment, ["iron_sword", "leather_armor"],
			"初始持有池应直塞武器+防具各一件")
	for c: Resource in GameData.party:
		assert_eq(String(c.weapon_id), "", "初始无人装武器（%s）" % c.id)
		assert_eq(String(c.armor_id), "", "初始无人装防具（%s）" % c.id)


func test_装备页冻结坐标与九宫格() -> void:
	assert_eq(_menu.get_equip_window().position, Vector2(144, 32), "装备子窗坐标")
	assert_eq(_menu.get_equip_window().size, Vector2(232, 208), "装备子窗尺寸=道具子窗同尺寸（规格 §3.1）")
	assert_eq(_menu.get_equip_window().MARGIN, 8.0, "子窗切分边距 8px")
	assert_true(_menu.get_equip_window().patch_count() >= 9, "子窗同为 9-slice")


func test_装备页取消路径无死层() -> void:
	GameData.owned_equipment = ["iron_sword", "leather_armor"]
	_menu.try_open()
	_menu.move_cursor(2)
	_menu.confirm_current()   # 角色态
	assert_eq(_menu.get_mode(), "equip_char")
	# 角色态 X → 回主模态
	assert_true(_menu._consume_event(_key_x()))
	assert_eq(_menu.get_mode(), "main", "角色态 X 应回主模态")
	assert_true(_menu.is_open())
	# 再进到列表态，逐层 X 退出
	_menu.confirm_current()
	_menu._consume_equip_char(_confirm_event())   # → 槽位态
	_menu._consume_equip_slot(_confirm_event())   # → 列表态
	assert_eq(_menu.get_mode(), "equip_list")
	assert_true(_menu._consume_event(_key_x()), "列表态 X 应被消费")
	assert_eq(_menu.get_mode(), "equip_char", "列表态 X 回角色态")
	assert_true(_menu._consume_event(_key_x()), "角色态 X 应被消费")
	assert_eq(_menu.get_mode(), "main", "逐层退出无死层")


func test_装备schema校验_两件初始装备合法() -> void:
	for eid: String in ["iron_sword", "leather_armor"]:
		var eq: Resource = DataTables.get_equipment(eid)
		assert_not_null(eq, "装备 %s 应已登记 DataTables" % eid)
		assert_eq((eq.validate() as Array).size(), 0,
				"装备 %s schema 应合法" % eid)
	assert_eq(String(DataTables.get_equipment("iron_sword").slot), "weapon")
	assert_eq(int(DataTables.get_equipment("iron_sword").atk_bonus), 3)
	assert_eq(String(DataTables.get_equipment("leather_armor").slot), "armor")
	assert_eq(int(DataTables.get_equipment("leather_armor").def_bonus), 2)


# =============== E. 装配面（town_map） ===============

func test_town装配菜单就位与幂等() -> void:
	var town: Node = add_child_autofree(TOWN_SCENE.instantiate())
	await wait_physics_frames(3)
	var panel: Control = town.menu_panel
	assert_not_null(panel, "town _ready 应装配 MenuPanel")
	assert_eq(panel.name, "MenuPanel")
	assert_false(panel.is_open(), "装配后默认关闭")
	# 幂等：二次装配返回同一实例（防跨图往返重复装配）
	town._assemble_menu()
	assert_eq(town.menu_panel, panel, "二次装配应复用既有实例")
