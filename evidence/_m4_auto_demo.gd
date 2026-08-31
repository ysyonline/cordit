extends Node
## _m4_auto_demo —— M4 收口试玩视频自动演示驱动器
## 【临时演示场景，仅供 M4 收口录制与链路代测，录后可删】（与 M2/M3 纪律一致）
##
## 【定位】M3 曾用同一模式录过 evidence/m3-gameplay.avi（A4 常驻根替身 +
##   Godot Movie Maker --write-movie）。本文件同模式重写，演示 M4 新特性
##   全链路（E4-S6 传送网络 + 门控自动存档 + E4-S7 失败读档）：
##   - 本场景是【A4 常驻根替身】：节点名 Main + World + UILayer/FadeMask，
##     结构与 scenes/main.tscn 一致——SceneRouter / BattleResultHandler
##     都按 "Main/World"、"Main/UILayer/FadeMask" 寻址，故能复用真实
##     场景切换（0.2s 黑屏转场）与战后回图全链路，零修改业务代码。
##   - 玩家移动走 set_input_override 真实物理驱动（碰撞/触发器全真），
##     走位被墙卡住时兜底直落（保演示不烂尾，日志留痕可查）。
##
## 【存档隔离】demo 全程使用独立存档槽 user://save_m4_demo.json
##   （SaveManager.save_path 本为 GUT 隔离而开放覆写）——用户真实存档
##   user://save.json 零触碰。启动时删除旧 demo 档，保证"首次落盘"画面
##   每次干净复现。
##
## 【演示脚本】（约 62s @30fps，全确定性、禁随机）：
##   第 1 幕  town 出生（R2 初始场景）：启动装载不落盘（门控存档跳过）
##   第 2 幕  走向客栈门 → 同图传送进室内（不落盘；相机限区切换）
##   第 3 幕  室内出口 → 同图传送回主图（不落盘）
##   第 4 幕  走向南门 → 跨图传送 road：存档意图置位 → map_ready 落盘
##            + 保存图标闪现（"过传送点存"）
##   第 5 幕  遭遇遗迹守卫（B4 预演编组，payload 经 Router 正常受理）
##   第 6 幕  确定性 DEFEAT（6 回合团灭，见 _m4_battle_host.gd 推演）
##            → 自动读档回 road 入口存档点 (384,64) + 免疫（S7 全链路）
##   第 7 幕  收尾：数据层验证读档回滚（map=road / 位置=存档点）→ 退出
##
## 【边界】只做演示编排：战斗内部实现全在 _m4_battle_host 侧；
##   禁随机：本文件不含任何 randf / 随机数调用。

# ------------------------------------------------------------------
# 常量（preload 常量风格，项目规范）
# ------------------------------------------------------------------

## 五图目录（取出生位/场景路径/防弹回口径正本）
const Catalog := preload("res://scripts/events/teleport_catalog.gd")

## 战斗演示舞台（DEFEAT 确定性脚本，临时场景与 M3 host 同纪律）
const BATTLE_HOST_PATH: String = "res://evidence/_m4_battle_host.tscn"

## 遇敌编组：B4 遗像守卫（精英，ATK16 群击）——数值碾压 Lv1 队伍保 DEFEAT
const ENCOUNTER_ID: String = "b4_guardian"

## demo 专用存档槽（隔离用户真实存档；SaveManager 注释明示可测试覆写）
const DEMO_SAVE_PATH: String = "user://save_m4_demo.json"

## town 走位航点（主图像素坐标；避开 NPC 实体与建筑直角）
const TOWN_SPAWN := Vector2(192, 640)          # town.tscn 玩家出生位
const INN_DOOR_APPROACH := Vector2(472, 640)   # 客栈门 x 对齐（出生行水平东行锚）

# ------------------------------------------------------------------
# 运行时
# ------------------------------------------------------------------

## 底部说明字幕（UILayer 上，战斗期间隐藏）
var _caption: Label = null


func _ready() -> void:
	print("[M4Demo] 启动：M4 收口自动演示（传送网络/门控存档/失败读档，禁随机）")
	# 存档隔离：覆写槽路径 + 清旧 demo 档（首次落盘画面可复现）
	SaveManager.save_path = DEMO_SAVE_PATH
	if FileAccess.file_exists(DEMO_SAVE_PATH):
		DirAccess.remove_absolute(DEMO_SAVE_PATH)
		print("[M4Demo] 已清除旧 demo 存档：%s" % DEMO_SAVE_PATH)
	_build_caption()
	_run()


# ------------------------------------------------------------------
# 演示主流程（协程）
# ------------------------------------------------------------------

func _run() -> void:
	# ── 第 1 幕：小镇出生（启动装载不落盘）─────────────────────
	_set_caption("【M4 收口演示】边陲小镇·晨 —— 启动装载（不落盘）")
	print("[M4Demo] 第 1 幕：装载 town（R2 初始场景）")
	SceneRouter.change_scene(Catalog.MAP_SCENE_PATHS["town"], {}, false)
	await _sleep(1.0)   # Router 转场 0.4s + town 装载（含对话/点位/传送装配）
	_expect_log("启动装载应无存档意图：[AutosaveNotifier] town 无存档意图")

	# ── 第 2 幕：客栈门同图传送（不落盘）────────────────────────
	# 航点语义：目标 = 触发区中心像素（传送触发瞬移玩家即本段完成——
	# 【坑】不要把航点设在触发区"上方一格"：差 8~11px 不入区不触发；
	# 也不要在传送触发后续段还指向旧目标：瞬移后方向错乱会多余兜底）
	_set_caption("走向客栈……（同图传送：改位置+切相机限区，不存档）")
	print("[M4Demo] 第 2 幕：走向客栈门（触发区中心 %s）" % _trigger_center(Vector2(29, 18)))
	await _walk_to(Vector2(INN_DOOR_APPROACH.x, TOWN_SPAWN.y))   # 水平段
	await _walk_to(_trigger_center(Vector2(29, 18)), 8.0)        # 垂直段→进门（传送即完成）
	await _sleep(1.4)   # 传送落位室内A (1368,280) + 相机限区切换
	_expect_log("同图传送应已触发：[TriggerTeleport] 同图传送 tp_town_door_inn")
	_set_caption("客栈大堂（相机限区已切室内框）—— 同图传送不落盘")
	await _sleep(1.6)

	# ── 第 3 幕：室内出口返回主图（不落盘）──────────────────────
	_set_caption("走出客栈……（出口同图传送，仍不落盘）")
	print("[M4Demo] 第 3 幕：走向客栈出口（Inn_Exit 触发区中心）")
	await _walk_to(_trigger_center(Vector2(85, 18)), 5.0)        # 出口区（传送即完成）
	await _sleep(1.4)   # 落位主图 (29,19) 格中心 + 主图限区恢复
	_expect_log("出口传送应已触发：[TriggerTeleport] 同图传送 tp_town_inn_exit")
	_set_caption("回到主图 —— 存档语义：安全点之外不覆盖存档")
	await _sleep(1.2)

	# ── 第 4 幕：南门跨图 → road（门控落盘 + 图标闪现）───────────
	_set_caption("出镇，前往近郊道路……（跨图传送：过传送点存！）")
	print("[M4Demo] 第 4 幕：走向南门（触发区中心 %s）"
			% _trigger_center(Vector2(12, 47)))
	await _walk_to(Vector2(200.0, 736.0), 10.0)                  # 西行到南门前空地
	await _walk_to(_trigger_center(Vector2(12, 47)), 5.0)        # 南下进南门（跨图即完成）
	await _sleep(1.6)   # Router 跨图转场 + road 落位 (384,64) + map_ready 落盘
	_expect_log("跨图落盘应已发生：[AutosaveNotifier] road + SaveManager 存档")
	_set_caption("近郊道路 —— 存档图标亮起：新安全点 = 进图入口 (384,64)")
	await _sleep(2.0)

	# ── 第 5 幕：遭遇战（payload 经 Router 正常受理）────────────
	_set_caption("！！遭遇遗迹守卫（B4 预演编组）—— 战力远超预期")
	print("[M4Demo] 第 5 幕：构造 BattlePayload 进战斗（Router 同源受理）")
	var payload: Dictionary = {
		"enemy_group_id": ENCOUNTER_ID,
		# A5 return_map = 完整场景路径（Router/处理器按路径回图；M3 同款）
		"return_map": Catalog.MAP_SCENE_PATHS["road"],
		"return_position": Catalog.tile_to_pixel(Vector2(23.5, 3.5)),
		"defeat_enemy_uid": "enemy_m4_demo",
	}
	SceneRouter.change_scene(BATTLE_HOST_PATH, payload, true)
	await _sleep(0.4)
	_caption.visible = false   # 战斗 HUD 自带全屏视图，字幕让位

	# ── 第 6 幕：DEFEAT → 自动读档回存档点（S7 全链路）──────────
	await EventBus.battle_finished
	print("[M4Demo] battle_finished 收到（DEFEAT）→ 等待读档回图")
	_caption.visible = true
	_set_caption("全灭……【轨迹残响】读档 —— 回到进图时的存档点")
	await _sleep(3.0)   # DEFEAT 读档 + Router 回图 + 回置 (384,64) + 免疫
	_expect_log("读档回图应已发生：[BattleResultHandler] DEFEAT 读档成功 -> 回到存档点 road")

	# ── 第 7 幕：收尾（数据层验证 + 清理 + 退出）─────────────────
	_verify_loaded_save()
	_set_caption("M4 收口演示完成：门控存档 / 跨图自动存档 / 失败读档 全链路 ✓")
	await _sleep(2.4)
	# 存档自清理：demo 槽用完即删，不留 user:// 残留（SMK-12 空壳检查会扫描
	# 非日志文件；本场景常被冒烟通道复跑同一台机，残留会误伤其 PASS 判定）
	if FileAccess.file_exists(DEMO_SAVE_PATH):
		DirAccess.remove_absolute(DEMO_SAVE_PATH)
		print("[M4Demo] 收尾清理 demo 存档：%s" % DEMO_SAVE_PATH)
	print("[M4Demo] 自动退出（Movie Maker 收尾写盘）")
	get_tree().quit()


# ------------------------------------------------------------------
# 工具
# ------------------------------------------------------------------

## 协程等待 t 秒（模拟时间；Movie Maker --fixed-fps 下按帧推进，节奏不变）
func _sleep(t: float) -> void:
	await get_tree().create_timer(t).timeout


## tile 坐标（Vector2，可含 .5）→ 触发区中心像素（走位目标：走进区内必触发）。
## 【坑】目标设在触发区"上方一格"会差 8~11px 不入区（body_entered 不发），
## 目标必须落在区中心，让传送瞬移自然打断走位。
func _trigger_center(t: Vector2) -> Vector2:
	return Vector2(t.x * 16.0 + 8.0, t.y * 16.0 + 8.0)


## 真实走位到目标点（override 注入 + 碰撞全真；真卡墙 0.5s 兜底直落）。
## 【帧序坑】恢复时机必须等 physics_frame：process_frame 恢复时本物理帧
## 还没跑，is_moving() 恒读旧值——第一版用 process_frame + is_moving 判卡，
## override 注入首帧即误判 stuck 导致全程兜底直落（headless 实测坐实：
## create_timer + override 玩家 1s 走 73px 完全正常）。
## 本版改【位移量】判定：每轮等物理帧，位移≈0 且 override 已注入才算卡。
func _walk_to(target: Vector2, timeout: float = 9.0) -> void:
	var player: Node2D = _find_player()
	if player == null:
		push_warning("[M4Demo] 找不到玩家，跳过走位 -> %s" % target)
		return
	var body := player as CharacterBody2D
	var elapsed: float = 0.0
	var stuck: float = 0.0
	var prev_pos: Vector2 = player.global_position
	print("[M4Demo][walk] 开始 %s -> %s（起点 %s）" % [prev_pos, target, prev_pos])
	while elapsed < timeout:
		var d := target - player.global_position
		if d.length() < 5.0:
			break
		player.set_input_override(d)
		# 等一个物理帧：_physics_process 消费 override 并 move_and_slide
		await get_tree().physics_frame
		await get_tree().physics_frame
		var moved := player.global_position.distance_to(prev_pos)
		prev_pos = player.global_position
		elapsed += 1.0 / 60.0   # 物理帧步长（Movie Maker 下按 fixed-fps 推进）
		# 传送瞬移侦测：单帧位移 >100px 必是传送落位（走速 72px/s 单帧仅 1.2px）
		# ——本段语义已达成（"走进触发区"完成），立即中断防旧目标多余兜底
		if moved > 100.0:
			break
		if moved < 0.5:
			stuck += 1.0 / 60.0
			if stuck > 0.5:
				player.global_position = target
				print("[M4Demo] 走位被阻挡，兜底直落 -> %s（碰撞链路日志可查）" % target)
				break
		else:
			stuck = 0.0
	player.set_input_override(Vector2.ZERO)
	print("[M4Demo][walk] 结束 -> %s（历时 %.1fs stuck=%.2f）"
			% [player.global_position, elapsed, stuck])


## 找当前地图的玩家（与 BattleResultHandler 同一寻址约定）
func _find_player() -> Node2D:
	var world: Node = get_node_or_null("World")
	if world == null or world.get_child_count() == 0:
		return null
	var map: Node = world.get_child(world.get_child_count() - 1)
	return map.get_node_or_null("YSorted/Player") as Node2D


## 数据层验证读档回滚（第 7 幕；重启读档的 headless 等价验证）：
## DEFEAT 读档已把 GameData 回滚到存档时点；此处复核 last_loaded 指纹。
func _verify_loaded_save() -> void:
	if not SaveManager.has_save():
		push_warning("[M4Demo] 验证失败：demo 存档不存在")
		return
	var map_name: String = String(SaveManager.last_loaded.get("map", ""))
	var pos_arr: Array = SaveManager.last_loaded.get("position", [0, 0])
	print("[M4Demo] 读档验证：map=%s position=%s（预期 road / (384,64) 附近）"
			% [map_name, str(pos_arr)])
	if map_name == "road":
		print("[M4Demo] 读档验证 PASS：失败读档回滚到进图存档点")
	else:
		push_warning("[M4Demo] 读档验证 FAIL：map=%s ≠ road" % map_name)


## 日志期望提示（录制画面观察辅助；行为正确性以真实日志为准）
func _expect_log(what: String) -> void:
	print("[M4Demo] 期望日志：%s" % what)


## 底部字幕（UILayer 顶层，半透明黑底提高可读性）
func _build_caption() -> void:
	var layer: CanvasLayer = get_node_or_null("UILayer") as CanvasLayer
	if layer == null:
		return
	var bg := ColorRect.new()
	bg.name = "DemoCaptionBg"
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.position = Vector2(0, 330)
	bg.size = Vector2(640, 30)
	layer.add_child(bg)
	_caption = Label.new()
	_caption.name = "DemoCaption"
	_caption.position = Vector2(8, 336)
	_caption.size = Vector2(624, 20)
	_caption.add_theme_font_size_override("font_size", 12)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(_caption)


func _set_caption(text: String) -> void:
	if _caption != null:
		_caption.text = text
