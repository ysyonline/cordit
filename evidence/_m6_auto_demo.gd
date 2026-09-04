extends Node
## _m6_auto_demo —— M6 收口试玩视频自动演示驱动器
## 【临时演示场景，仅供 M6 收口录制，录后可删】（与 M2~M5 纪律一致）
##
## 【定位】与前作（M4/M5）的关键差异 ——【走 main.tscn 正常入口】：
##   本场景不再是"Main 替身 + 场景直启"，而是作为启动场景把【真的】
##   res://scenes/main.tscn 实例化挂到 /root 下并把 tree.current_scene 指向它
##   ——MainController 结构自检、初始装载 town、P0 开局锚点接线（双守卫：
##   current_scene=="Main" 本体 + 无存档）全部走生产代码路径，零替身。
##
## 【存档红线协议（本演示最高优先级）】P0 守卫 !has_save() 要求 user://
##   save.json 不存在，而用户机器上可能有真实存档。协议三段：
##   ① 启动：若存在 save.json.m6demo_bak（上次异常中断残留）→ 先恢复
##     （丢弃 demo 进度档，防丢真实存档）；然后把 save.json 备份为
##     .m6demo_bak 并临时移除——demo 以"无档"状态走 P0。
##   ② 运行中：demo 的自动存档/胜利存档全部写入真实槽 save.json（不覆写
##     SaveManager.save_path——正常入口语义）；用户真实档此刻安全躺在备份里。
##   ③ 退出（quit 前 / 窗口关闭）：恢复 save.json ← .m6demo_bak 并删备份；
##     本次运行前本就无档的机器则删 demo 档恢复"无档"状态。
##     若 dryrun/录制被强杀（如 --quit-after 安全阀先到），下次启动走 ①
##     自动恢复——任何时序中断都不丢用户真实存档。
##
## 【战斗口径】真实遇敌（可见敌人接触 → enemy_touched → Router 切真实
##   battle.tscn）。battle.tscn 本体是 E2-S3 占位方块阵（结算 UI 缺位），
##   故由内部类 BattleDirector 叠加在占位场景之上：真实 BattleCommand +
##   BattleUI（含 E6-S2 结算逐条揭示）打确定性剧本，battle_finished 交
##   BattleResultHandler 走生产回图链——与 M5 桥转发替身不同，这里【保留
##   Router 的真实遇敌切换】，只把结算视图补齐。
##   确定性：逃跑检定 submit_command 第 4 位显式传 roll=0.0（M3 教训），
##   敌 AI roll 固定 0.5（moth/beetle 权重表 attack=100，roll 不影响结果），
##   伤害 variance 恒 1.0；本文件无任何 randf 调用。
##
## 【镜头串联】（五镜头全拍，无裁剪；预计 headless 时间轴 ~160s，
##   Movie Maker ×1.3~1.6 ≈ 7000~7700 帧 @30fps ≈ 4~4.5 分钟）：
##   镜头1  P0 开场：出生格 (192,640) 自动踩踏 → story_p0_intro（51 条，
##          按实际条数补按收束）→ set_flag + save_point → phase 注入 0→1
##          （等价 story_quest_accept 的 set_story_phase 动作，生产侧 P1
##          触发器未接线，驱动器注入不翻案口径）
##   镜头2  菜单三页：C 呼出 → 状态页看装备数字 → 道具页用小药瓶 →
##          装备页给凯尔换 旧铁剑(ATK+3)/皮甲(DEF+2) → X 逐层退出
##          （全程经 MenuPanel._consume_event 真实状态机，GUT 同通道）
##   镜头3  road 聊天段① (35,31)（M5 路线 V3 段本就穿过命中区，停点微调）
##          → 道路飞蛾诱敌接触 → 完整胜利（结算 EXP/升级/习得/掉落逐条）
##          → 回图（击破敌人数据驱动防复活）
##   镜头4  雷壳甲虫×2 诱敌接触 → 首行动逃跑（roll=0.0 必成）→ 回图
##   镜头5  f1 → f2 聊天段② (23,8)（入口走廊必经）→ 收尾验证 → 退出
##
## 【边界】只做演示编排；零产品代码改动；禁随机（无 randf/随机数调用）。

# ------------------------------------------------------------------
# 常量
# ------------------------------------------------------------------

## 真入口场景（本演示与 M4/M5 替身模式的本质区别）
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

## 五图目录（出生位/场景路径正本）
const Catalog := preload("res://scripts/events/teleport_catalog.gd")

## 用户真实存档与备份路径（红线协议见类头注）
const REAL_SAVE_PATH: String = "user://save.json"
const BAK_SUFFIX: String = ".m6demo_bak"

## 节奏常量（秒；Movie Maker --fixed-fps 下按帧推进，节奏不变）
const P0_PRESS_INTERVAL: float = 0.28     # P0 51 条：0.28s/按（补完+翻页 ≈ 102 按）
const CHAT_PRESS_INTERVAL: float = 0.5    # 聊天段 4 条：0.5s/按
const MENU_TAP_INTERVAL: float = 0.45     # 菜单键击间隔
const SCENE_SETTLE: float = 1.3           # 跨图转场后落位/装配等待
const BATTLE_RETURN_SETTLE: float = 2.2   # 战后回图 + 回置 + 免疫等待
const NATURAL_WINDOW: float = 6.0         # 诱敌自然接触等待上限（超时转 GUT 直驱）

## road 诱敌目标（road.tscn 实体正本：uid/编组/巡逻线 y）
const MOTH := {"uid": "road_moth_01", "group": "b1_moth"}
const BEETLE := {"uid": "road_beetle_02", "group": "b2_beetles"}

# ------------------------------------------------------------------
# 运行时
# ------------------------------------------------------------------

## 底部说明字幕（Main/UILayer 上，战斗期间隐藏）
var _caption: Label = null
## 正常入口 Main 实例（/root/Main）
var _main: Node = null
## 本次运行前用户是否持有真实存档（决定退出时"恢复"还是"清 demo 档"）
var _had_user_save: bool = false
## 存档恢复幂等标志
var _save_restored: bool = false
## 演示时间轴累计（秒）——录制帧数估算用（×30 = 帧数基准）
var _timeline: float = 0.0


func _ready() -> void:
	print("[M6Demo] 启动：M6 收口自动演示（main.tscn 正常入口 + P0 开场 + 菜单三页 + 胜利/逃跑 + 两段队员聊天，禁随机）")
	_prepare_user_save()
	# 防御性清态（新进程本为初值；按任务要求显式保证 P0 门闸全开）
	GameData.story_phase = 0
	GameData.flags.clear()
	GameData.cleared_enemy_set.clear()
	GameData.discovered_weakness_set.clear()
	print("[M6Demo] GameData 清态确认：phase=0 flags=%s（P0 守卫 not_flag/==0 放行）" % [GameData.flags])
	# 启动帧根节点仍在装配子节点（dryrun1 实锤：_ready 内直接 add_child 被拒），
	# 延迟一拍再挂 main.tscn 正常入口
	call_deferred("_deferred_bootstrap")


## 延迟引导：挂正常入口 + 字幕 + 起跑演示主流程
func _deferred_bootstrap() -> void:
	_spawn_main_entry()
	_build_caption()
	_run()


func _notification(what: int) -> void:
	# 窗口关闭（GUI 录制中途中止）也走恢复协议——红线兜底第二道
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_restore_user_save()
		get_tree().quit()


func _exit_tree() -> void:
	# 幂等：正常路径已在 quit 前恢复过，此处仅兜底
	_restore_user_save()


## 实例化真的 main.tscn 并接管 current_scene——MainController 结构自检、
## town 初始装载、P0 双守卫全部走生产路径（本演示的口径根基）。
func _spawn_main_entry() -> void:
	_main = MAIN_SCENE.instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	print("[M6Demo] 正常入口已挂载：res://scenes/main.tscn（/root/%s，current_scene 已指向）" % _main.name)


# ------------------------------------------------------------------
# 存档红线协议（启动备份 / 退出恢复）
# ------------------------------------------------------------------

func _prepare_user_save() -> void:
	# ① 中断恢复：上次异常退出留下的备份先还原（demo 进度档被真实档覆盖丢弃）
	if FileAccess.file_exists(REAL_SAVE_PATH + BAK_SUFFIX):
		_copy_file(REAL_SAVE_PATH + BAK_SUFFIX, REAL_SAVE_PATH)
		print("[M6Demo] 检测到上次中断备份，已恢复用户真实存档（save.json ← save.json.m6demo_bak，备份保留待本轮收尾）")
	# ② 备份本轮用户存档并临时移除（P0 的 !has_save() 守卫由此放行）
	if FileAccess.file_exists(REAL_SAVE_PATH):
		_had_user_save = true
		_copy_file(REAL_SAVE_PATH, REAL_SAVE_PATH + BAK_SUFFIX)
		DirAccess.remove_absolute(REAL_SAVE_PATH)
		print("[M6Demo] 用户真实存档已备份并临时移除：save.json → save.json.m6demo_bak（退出时恢复——红线）")
	else:
		_had_user_save = false
		print("[M6Demo] 当前无用户存档（首次启动口径，P0 可触发；退出时清除 demo 档恢复无档状态）")


func _restore_user_save() -> void:
	if _save_restored:
		return
	_save_restored = true
	if FileAccess.file_exists(REAL_SAVE_PATH + BAK_SUFFIX):
		_copy_file(REAL_SAVE_PATH + BAK_SUFFIX, REAL_SAVE_PATH)
		DirAccess.remove_absolute(REAL_SAVE_PATH + BAK_SUFFIX)
		print("[M6Demo] 用户真实存档已恢复：save.json ← save.json.m6demo_bak（备份已移除）")
	elif not _had_user_save and FileAccess.file_exists(REAL_SAVE_PATH):
		DirAccess.remove_absolute(REAL_SAVE_PATH)
		print("[M6Demo] 本次运行前无用户存档：demo 存档已清除，恢复无档状态（SMK-12 纯净）")
	else:
		print("[M6Demo] 存档收尾：无需恢复（无备份且无 demo 档）")


func _copy_file(p_from: String, p_to: String) -> void:
	var reader := FileAccess.open(p_from, FileAccess.READ)
	if reader == null:
		push_warning("[M6Demo] 备份读取失败：%s" % p_from)
		return
	var text: String = reader.get_as_text()
	reader = null
	var writer := FileAccess.open(p_to, FileAccess.WRITE)
	if writer == null:
		push_warning("[M6Demo] 备份写入失败：%s" % p_to)
		return
	writer.store_string(text)
	writer.flush()
	writer = null


# ------------------------------------------------------------------
# 正常入口挂载
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# 演示主流程（协程）
# ------------------------------------------------------------------

func _run() -> void:
	# ══ 镜头 1：P0 开场事件（出生格自动踩踏，真实守卫链）═════════
	_set_caption("【M6 收口演示】边陲小镇·晨 —— 正常入口，无存档首进（P0 开场）")
	await _sleep(SCENE_SETTLE)   # MainController 初始装载 town + P0 锚点装配 + 出生重叠触发
	_expect_log("P0 接线应已发生：[TownMap] P0 开局锚点装配完成（守卫：Main 本体 + 无存档）")
	# 【产品接线缺口补线（demo 侧，零产品代码改动）】聊天点装配器在 road/f2 图
	# 兜底取 SceneRouter.global_event_executor，但该全局实例的 dialogue_runner
	# 只有 f3 装配面会注入——road/f2 聊天点命中后 dialogue 动作"运行器未注入"
	# 静默跳过（dryrun4 实锤：只打 flag 不开演）。此处把常驻 runner 注入全局
	# executor（与 f3 生产装配同一接口），聊天段才能真开演。
	# 【须回传主理人】产品侧修复建议：road/f2 map _ready 装配聊天点前对全局
	# executor 注入 UILayer 常驻 runner（与 ruins_f3_map 同款）。
	var runner: Node = _find_runner()
	if runner != null and SceneRouter.global_event_executor != null \
			and not SceneRouter.global_event_executor.has_dialogue_runner():
		SceneRouter.global_event_executor.setup(runner)
		print("[M6Demo] 全局 executor 已注入常驻 runner（demo 侧补线，聊天点开演通道打通）")
	_expect_log("P0 开演应已发生：[DialogueRunner] 开演：story_p0_intro（51 条目）")
	await _wait_dialogue_started("P0 开场对白", 8.0)
	_set_caption("P0 开场对白 —— 委托、异变与出发（事件层 story_p0_intro，51 条）")
	await _sleep(0.8)
	await _advance_until_idle("P0 按实际条数收束", 160, P0_PRESS_INTERVAL)
	await _wait_dialogue_finished("P0 收束")
	_expect_log("P0 动作应已落地：set_flag story_p0_seen + save_point 存档请求")
	# 剧情推进注入（生产侧 P1 触发器未接线；等价 story_quest_accept 的
	# set_story_phase 动作——聊天段① 门闸 phase>=1 由此放行）
	GameData.story_phase = 1
	EventBus.story_phase_changed.emit(1)
	print("[M6Demo] 剧情推进注入：story_phase 0→1（P1 委托受理，聊天段① 门闸放行）")
	await _sleep(0.4)

	# ══ 镜头 2：菜单三页（状态 / 道具 / 装备，C 呼出 X 退出）══════
	_set_caption("菜单三页 —— C 呼出：状态页装备数字 / 道具页用药 / 装备页换装")
	# 演示注入：凯尔掉 15 HP（用药可见回复）+ 背包直塞小药瓶×2（初始直塞口径，
	# owned_equipment 的 2 件装备 GameData 本就自带）
	var kyle: Resource = GameData.party[0]
	kyle.hp = maxi(1, int(kyle.hp) - 15)
	GameData.inventory["potion_s"] = 2
	print("[M6Demo] 演示注入：凯尔 HP-15（用药可见）+ 背包 小药瓶×2（初始直塞口径）")
	var menu: Node = _find_menu()
	if menu == null:
		push_warning("[M6Demo] MenuPanel 未找到，镜头 2 跳过")
	else:
		await _menu_tap(menu, _menu_key())          # C → 打开（状态页）
		await _sleep(0.7)
		var atk_before := _menu_stat(menu, "atk")
		var def_before := _menu_stat(menu, "def")
		print("[M6Demo] 状态页（换装前）：凯尔 %s / %s" % [atk_before, def_before])
		await _menu_tap(menu, _menu_action("move_down"))   # → 道具
		await _menu_tap(menu, _menu_action("interact"))    # 道具列表（小药瓶×2）
		await _sleep(0.6)
		await _menu_tap(menu, _menu_action("interact"))    # 目标选择（凯尔）
		await _menu_tap(menu, _menu_action("interact"))    # 用药（HP 105→120，剩 1）
		await _sleep(0.6)
		_expect_log("用药应已发生：[MenuPanel] 使用 小药瓶 → 凯尔（剩 1）")
		await _menu_tap(menu, _menu_action("cancel"))      # 回列表
		await _menu_tap(menu, _menu_action("cancel"))      # 回主菜单
		await _menu_tap(menu, _menu_action("move_down"))   # → 装备
		await _menu_tap(menu, _menu_action("interact"))    # 角色选择（凯尔）
		await _menu_tap(menu, _menu_action("interact"))    # 槽位：武器
		await _menu_tap(menu, _menu_action("interact"))    # 列表：旧铁剑 ATK+3
		await _sleep(0.6)
		await _menu_tap(menu, _menu_action("interact"))    # 换装生效
		_expect_log("换装应已发生：[MenuPanel] 凯尔 换装 武器：[iron_sword]")
		await _menu_tap(menu, _menu_action("cancel"))      # 回角色选择
		await _menu_tap(menu, _menu_action("interact"))    # 槽位（复位武器）
		await _menu_tap(menu, _menu_action("move_down"))   # → 防具
		await _menu_tap(menu, _menu_action("interact"))    # 列表：皮甲 DEF+2
		await _sleep(0.6)
		await _menu_tap(menu, _menu_action("interact"))    # 换装生效
		_expect_log("换装应已发生：[MenuPanel] 凯尔 换装 防具：[leather_armor]")
		await _sleep(0.6)
		print("[M6Demo] 状态页（换装后）：凯尔 %s / %s（预期 ATK+3 / DEF+2 可见变化）"
				% [_menu_stat(menu, "atk"), _menu_stat(menu, "def")])
		await _menu_tap(menu, _menu_action("cancel"))      # 回角色选择
		await _menu_tap(menu, _menu_action("cancel"))      # 回主菜单
		await _menu_tap(menu, _menu_action("cancel"))      # X 关闭（解锁玩家）
		_expect_log("关菜单应已发生：[MenuPanel] 菜单关闭")
	await _sleep(0.5)

	# ══ 出镇（南门跨图 → road，过传送点存）═════════════════════
	_set_caption("出镇，前往近郊道路……（跨图传送：过传送点存）")
	await _walk_seg(Vector2(200.0, 640.0), 3.0)     # 西行半格到南街中线（M5 同列）
	await _walk_seg(Vector2(200.0, 736.0), 6.0)     # 南街一路南下
	await _walk_seg(_trigger_center(Vector2(12.5, 47)), 4.0)   # 南门触发区中心
	await _sleep(SCENE_SETTLE)   # 跨图转场 + road 落位 (384,64) + map_ready 落盘
	_expect_log("跨图落盘应已发生：[AutosaveNotifier] road + SaveManager 存档")
	_set_caption("近郊道路 —— 存档图标亮起：新安全点 = 进图入口")
	await _sleep(0.8)

	# ══ 镜头 3 前半：道路飞蛾诱敌 → 完整胜利 ════════════════════
	_set_caption("道路遇敌 —— 道路飞蛾（B1 教学战）……")
	await _walk_seg(Vector2(384.0, 200.0), 4.0)     # N0 北段南下（M5 正本）
	await _walk_seg(Vector2(696.0, 152.0), 7.0)     # H1 东行
	await _walk_seg(Vector2(696.0, 264.0), 4.0)     # V1 东缘南下
	await _walk_seg(Vector2(176.0, 280.0), 10.0)    # H1b 西行长横
	await _walk_seg(Vector2(176.0, 344.0), 3.0)     # V2 西缘南下（带B 开口）
	await _walk_seg(Vector2(296.0, 394.0), 5.0, false)   # 蛾巡逻线（y=424）北侧 30px 诱敌位（免疫关）
	await _wait_contact_and_fight("道路飞蛾 road_moth_01", MOTH)
	_set_caption("胜利！EXP / 升级 / 习得 / 掉落 逐条结算 —— 飞蛾数据驱动防复活")
	await _sleep(0.8)

	# ══ 镜头 5 前半：road 聊天段① (35,31)（phase>=1 门闸已放行）══
	_set_caption("队员聊天 · 段①（road 35,31 位置触发，一次性 flag 门闸）")
	await _walk_seg(Vector2(584.0, 440.0), 7.0)     # 回 H2 主横道（M5 开放区）
	await _walk_seg(Vector2(584.0, 490.0), 2.0)     # 聊天命中区北侧停点（区 y∈[496,528]）
	await _walk_seg(Vector2(584.0, 512.0), 2.0)     # 踏入 3×2 命中区 → 触发
	await _handle_chat("party_chat_road_01", 12)
	_expect_log("聊天段① 应已发生：[ChatPointAssembler] road 装配 + party_chat_road_01 开演/收束")

	# ══ 镜头 4：雷壳甲虫×2 诱敌 → 首行动逃跑（roll=0.0）═════════
	_set_caption("继续南下……雷壳甲虫拦路 —— 三角色各 80%，逃跑检定注入确定性 roll")
	await _walk_seg(Vector2(584.0, 536.0), 2.0)     # V3 南下收尾
	await _walk_seg(Vector2(72.0, 592.0), 10.0)     # H3 西行长横（M5 正本，甲虫①带 y=584 南侧 8px 外）
	await _walk_seg(Vector2(72.0, 760.0), 5.0)      # V4 西缘南下（带D 开口）
	await _walk_seg(Vector2(216.0, 856.0), 5.0)     # H4 东行至断桥西南（M5 正本）
	await _walk_seg(Vector2(488.0, 872.0), 6.0, false)   # 甲虫②巡逻线（y=856）南侧 16px 诱敌位（免疫关）
	await _wait_contact_and_fight("雷壳甲虫×2 road_beetle_02", BEETLE)
	_set_caption("逃跑成功！敌人保留可绕行（ESCAPE 不登记击破、不掉落、不置存档意图）")
	await _sleep(0.8)

	# ══ 南门 → f1（M5 正本蛇形链收尾段）════════════════════════
	_set_caption("前往遗迹……")
	await _walk_seg(Vector2(696.0, 872.0), 5.0)     # H4c 东行（M5 正本）
	await _walk_seg(Vector2(696.0, 984.0), 4.0)     # V5 南下（带E 开口）
	await _walk_seg(Vector2(384.0, 984.0), 6.0)     # H6 西行
	await _walk_seg(_trigger_center(Vector2(23.5, 63.5)), 3.0)   # 南门触发区中心
	await _sleep(SCENE_SETTLE)   # f1 落位 (448,56)
	_expect_log("road→f1 跨图应已触发：tp_road_to_f1")
	# 剧情推进注入（进遗迹调查，等价 story_ruin_enter 的 set_story_phase 动作
	# ——聊天段② 门闸 phase>=2 由此放行）
	GameData.story_phase = 2
	EventBus.story_phase_changed.emit(2)
	print("[M6Demo] 剧情推进注入：story_phase 1→2（进遗迹调查，聊天段② 门闸放行）")
	_set_caption("遗迹一层 —— 大厅双巡逻带在中央，沿西缘绕行（M5 正本路线）")
	await _sleep(0.8)

	# ══ f1 蛇形链北上（M5 正本，巡逻带全部避开）═════════════════
	await _walk_seg(Vector2(448.0, 168.0), 5.0)     # H1 南廊东行
	await _walk_seg(Vector2(728.0, 168.0), 6.0)     # 东行贴 V2 口
	await _walk_seg(Vector2(728.0, 416.0), 7.0)     # V2 东缘南下（带A 开口 45-46）
	await _walk_seg(Vector2(176.0, 416.0), 13.0)    # H2 大厅主横道西行
	await _walk_seg(Vector2(176.0, 560.0), 5.0)     # V3 西缘南下（带B 开口 10-11）
	await _walk_seg(Vector2(456.0, 632.0), 10.0)    # H3 北区走廊东行
	await _walk_seg(Vector2(448.0, 656.0), 3.0)     # V4 楼梯走道口
	await _walk_seg(Vector2(448.0, 696.0), 4.0)     # 北口触发区中心（M5 dryrun5 教训位）
	await _sleep(SCENE_SETTLE)   # f2 落位 (384,40)
	_expect_log("f1→f2 跨图应已触发：tp_f1_to_f2")

	# ══ 镜头 5 后半：f2 聊天段② (23,8)（phase>=2 门闸已放行）════
	_set_caption("遗迹二层 —— 入口走廊必经点：队员聊天 · 段②")
	await _walk_seg(Vector2(384.0, 122.0), 3.0)     # 聊天命中区北侧停点（区 y∈[128,160]）
	await _walk_seg(Vector2(384.0, 142.0), 2.0)     # 踏入 2×2 命中区 → 触发
	await _handle_chat("party_chat_f2_01", 12)
	_expect_log("聊天段② 应已发生：party_chat_f2_01 开演/收束（B4 定守 (23,24) 不在动线上）")

	# ══ 收尾：终态验证 → 恢复用户存档 → 退出 ═══════════════════
	_set_caption("M6 收口演示完成：P0 开场 / 菜单三页 / 胜利结算 / 逃跑 / 两段队员聊天 ✓")
	_verify_m6_final_state()
	await _sleep(2.4)
	_restore_user_save()
	print("[M6Demo] 演示时间轴累计 ≈ %.0fs（≈ %d 帧 @30fps；Movie Maker ×1.3~1.6 慢放 ≈ %d~%d 帧 ≈ %.1f~%.1f 分钟）"
			% [_timeline, int(_timeline * 30.0), int(_timeline * 30.0 * 1.3),
			int(_timeline * 30.0 * 1.6), _timeline * 1.3 / 60.0, _timeline * 1.6 / 60.0])
	print("[M6Demo] 自动退出（Movie Maker 收尾写盘）")
	get_tree().quit()


# ------------------------------------------------------------------
# 战斗段（真实遇敌 + 导演叠加）
# ------------------------------------------------------------------

## 诱敌守候：站上诱敌位后 ① 等敌人追击贴身自然接触（TouchArea body_entered）
## ② 上限 NATURAL_WINDOW 未触 → 改走 GUT 同款直驱通道 _handle_player_contact
## （visible_enemy 公开驱动口；免疫窗口会吞掉单次 body_entered——玩家兜底直落
## 进接触区 + 上一段过路免疫未过期时，dryrun5 实锤自然路径永不触发）
## ③ 敌人定位失败再兜底构造 BattlePayload 直启（M4 口径，Router 同源受理）。
func _wait_contact_and_fight(label: String, target: Dictionary) -> void:
	print("[M6Demo] 诱敌守候：%s（先等 %.0fs 自然接触）" % [label, NATURAL_WINDOW])
	var waited: float = 0.0
	while waited < NATURAL_WINDOW:
		if SceneRouter.current_scene_path == SceneRouter.BATTLE_SCENE_PATH:
			break
		await _sleep(0.25)
		waited += 0.25
	if SceneRouter.current_scene_path != SceneRouter.BATTLE_SCENE_PATH:
		print("[M6Demo] 自然接触未发生（%.0fs）——改用 GUT 直驱通道 _handle_player_contact"
				% waited)
		var enemy: Node = _find_enemy_by_uid(String(target["uid"]))
		var player: Node2D = _find_player()
		if enemy != null and player != null:
			player.encounter_immunity = 0.0   # 清免疫（demo 侧），确保直驱放行
			enemy._handle_player_contact(player)
			print("[M6Demo] 直驱接触完成：%s（回置点 = 敌位沿来向外推 1 格）" % label)
		else:
			push_warning("[M6Demo] 直驱目标缺失（enemy=%s player=%s）——构造 BattlePayload 兜底进战斗"
					% [enemy != null, player != null])
			var pos: Vector2 = player.global_position if player != null else Vector2.ZERO
			SceneRouter.change_scene(SceneRouter.BATTLE_SCENE_PATH, {
				"enemy_group_id": String(target["group"]),
				"return_map": SceneRouter.current_scene_path,
				"return_position": pos,
				"defeat_enemy_uid": String(target["uid"]),
			}, true)
	# 等战斗场景就位（Router 0.4s 转场）
	var t2: float = 0.0
	while t2 < 6.0 and SceneRouter.current_scene_path != SceneRouter.BATTLE_SCENE_PATH:
		await _sleep(0.2)
		t2 += 0.2
	await _run_battle_auto()


## 按 enemy_uid 在当前地图 YSorted 下定位可见敌人实体
func _find_enemy_by_uid(p_uid: String) -> Node:
	var world: Node = _get_world()
	if world == null or world.get_child_count() == 0:
		return null
	var map: Node = world.get_child(world.get_child_count() - 1)
	var ysorted: Node = map.get_node_or_null("YSorted")
	if ysorted == null:
		return null
	for child: Node in ysorted.get_children():
		if child.get("enemy_uid") != null and String(child.get("enemy_uid")) == p_uid:
			return child
	return null


## 轮询等待 Router 离开战斗场景（战后回图完成的标志）
func _wait_scene_changed_from_battle(timeout: float) -> void:
	var elapsed: float = 0.0
	while elapsed < timeout:
		if SceneRouter.current_scene_path != SceneRouter.BATTLE_SCENE_PATH:
			print("[M6Demo] 战后回图完成（耗时 %.1fs，current=%s）"
					% [elapsed, SceneRouter.current_scene_path])
			return
		await _sleep(0.2)
		elapsed += 0.2
	push_warning("[M6Demo] 等待战后回图超时（%.0fs）——继续后续流程留痕" % timeout)


## 战斗导演挂载 + 等战后回图。剧本由 BattleDirector 按编组 id 自选：
## b1_moth → 完整胜利；其余（b2_beetles 等）→ 首行动逃跑。
func _run_battle_auto() -> void:
	_caption.visible = false   # 战斗 HUD 全屏，字幕让位
	var world: Node = _get_world()
	if world == null or world.get_child_count() == 0:
		push_warning("[M6Demo] 战斗场景定位失败（World 空）——战斗段跳过")
		return
	var battle_scene: Node = world.get_child(world.get_child_count() - 1)
	if battle_scene.get_node_or_null("M6BattleDirector") != null:
		push_warning("[M6Demo] 该战斗场景已有导演在位——只等收束不重复挂载")
		await EventBus.battle_finished
		await _wait_scene_changed_from_battle(6.0)
		await _sleep(BATTLE_RETURN_SETTLE)
		_caption.visible = true
		return
	var director: BattleDirector = BattleDirector.new()
	director.name = "M6BattleDirector"
	director.driver = self
	battle_scene.add_child(director)
	_normalize_staged_return()
	await EventBus.battle_finished
	print("[M6Demo] battle_finished 已回传（剧本=%s），等待 BattleResultHandler 回图"
			% director.script_kind)
	await _wait_scene_changed_from_battle(6.0)
	# 战后免疫延长（E2-S4 生产口径 0.5s 太短）：ESCAPE 回置点与敌人相邻
	# （敌人位 + 玩家来向外推 1 格），0.5s 一过立即再触——延长到 4s 覆盖
	# 回图落位 + 下一段走位起步
	var player: Node2D = _find_player()
	if player != null and player.has_method("start_encounter_immunity"):
		player.start_encounter_immunity(4.0)
		print("[M6Demo] 战后免疫延长至 4s（回置点贴敌防秒触）")
	await _sleep(BATTLE_RETURN_SETTLE)   # 回图转场 + 玩家回置 + 免疫
	_caption.visible = true


## 【产品缺陷补正（demo 侧，零产品代码改动）】road.tscn 的可见敌人 return_map
## 导出值为短名 "road"（非场景路径）——BattleResultHandler 战后直接拿它调
## change_scene 会被 Router 以"目标路径不存在"拒绝（dryrun3 实锤），战斗后
## 永远回不了图。demo 在导演挂载后把 Router 暂存载荷的 return_map 短名
## 翻译成 TeleportCatalog 正本路径，让生产回图链正常走完。
## 【须回传主理人】产品侧修复建议：road.tscn 三敌人 return_map 导出值改
## "res://scenes/maps/road.tscn"（或 handler 侧做短名反查）。
func _normalize_staged_return() -> void:
	var staged: Dictionary = SceneRouter.get_staged_payload()
	var rm := String(staged.get("return_map", ""))
	if rm.is_empty() or rm.begins_with("res://"):
		return
	var fixed := String(Catalog.MAP_SCENE_PATHS.get(rm, ""))
	if fixed.is_empty():
		return
	SceneRouter._staged_payload["return_map"] = fixed
	print("[M6Demo] 暂存载荷 return_map 短名补正：\"%s\" → \"%s\"（demo 侧数据补正，产品缺陷见回传报告）"
			% [rm, fixed])


## 途中遭遇兜底：任意走位段后若已在战斗场景（巡逻带擦边等计划外接触），
## 同样交导演处理（按编组自选剧本），演示不烂尾。
## 【safe 通道】p_safe=true 的过路段先给玩家遇敌免疫（时长 = 段超时 + 1.5s
## 裕量）——途经巡逻带不接触（逃跑战后回置点与敌人相邻，不免疫会立即再触
## 形成"逃跑-再遇"死循环，dryrun4 实锤）。诱敌接近段显式传 false。
func _walk_seg(target: Vector2, timeout: float, p_safe: bool = true) -> void:
	if p_safe:
		var player: Node2D = _find_player()
		if player != null and player.has_method("start_encounter_immunity"):
			player.start_encounter_immunity(timeout + 1.5)
	await _walk_to(target, timeout)
	if SceneRouter.current_scene_path == SceneRouter.BATTLE_SCENE_PATH:
		push_warning("[M6Demo] 途中遭遇（计划外接触）——交战斗导演按编组剧本处理")
		await _run_battle_auto()


# ------------------------------------------------------------------
# 走位 / 对话 / 菜单工具（M5 同款，增补 freed 守卫）
# ------------------------------------------------------------------

func _sleep(t: float) -> void:
	_timeline += t
	await get_tree().create_timer(t).timeout


func _trigger_center(t: Vector2) -> Vector2:
	return Vector2(t.x * 16.0 + 8.0, t.y * 16.0 + 8.0)


func _get_world() -> Node:
	if _main == null:
		return null
	return _main.get_node_or_null("World")


## 真实走位到目标点（override 注入 + 碰撞全真；真卡墙 0.5s 兜底直落）。
## 【M6 增补】遇敌切场瞬间玩家随旧图释放——每轮先 is_instance_valid 守卫，
## 已释放立即放弃本段（战斗交 _walk_seg / 守候循环接管）。
func _walk_to(target: Vector2, timeout: float = 9.0) -> void:
	var player: Node2D = _find_player()
	if player == null:
		push_warning("[M6Demo] 找不到玩家，跳过走位 -> %s" % target)
		return
	var elapsed: float = 0.0
	var stuck: float = 0.0
	var prev_pos: Vector2 = player.global_position
	print("[M6Demo][walk] 开始 -> %s（起点 %s）" % [target, prev_pos])
	while elapsed < timeout:
		if not is_instance_valid(player):
			print("[M6Demo][walk] 玩家已随旧图释放（遇敌切场），本段作废 -> %s" % target)
			return
		var d := target - player.global_position
		if d.length() < 5.0:
			break
		player.set_input_override(d)
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not is_instance_valid(player):
			print("[M6Demo][walk] 玩家已随旧图释放（遇敌切场），本段作废 -> %s" % target)
			return
		var moved := player.global_position.distance_to(prev_pos)
		prev_pos = player.global_position
		elapsed += 1.0 / 60.0   # 物理帧步长（Movie Maker 下按 fixed-fps 推进）
		if moved > 100.0:       # 传送瞬移侦测：本段语义已达成
			break
		if moved < 0.5:
			stuck += 1.0 / 60.0
			if stuck > 0.5:
				player.global_position = target
				print("[M6Demo] 走位被阻挡，兜底直落 -> %s（碰撞链路日志可查）" % target)
				break
		else:
			stuck = 0.0
	if is_instance_valid(player):
		player.set_input_override(Vector2.ZERO)
	_timeline += elapsed   # 走位实际耗时计入时间轴
	print("[M6Demo][walk] 结束 -> %s（历时 %.1fs stuck=%.2f）"
			% [player.global_position if is_instance_valid(player) else target, elapsed, stuck])


func _find_player() -> Node2D:
	var world: Node = _get_world()
	if world == null or world.get_child_count() == 0:
		return null
	var map: Node = world.get_child(world.get_child_count() - 1)
	return map.get_node_or_null("YSorted/Player") as Node2D


## 常驻对话运行器（正常入口正典结构：/root/Main/UILayer/DialogueRunner）
func _find_runner() -> Node:
	if _main == null:
		return null
	return _main.get_node_or_null("UILayer/DialogueRunner")


## 主菜单（正常入口正典结构：/root/Main/UILayer/MenuPanel，town 首装常驻）
func _find_menu() -> Node:
	if _main == null:
		return null
	return _main.get_node_or_null("UILayer/MenuPanel")


## 聊天段统一处理：等开演 → 按实际条数补按收束 → 等收束
func _handle_chat(what: String, max_presses: int) -> void:
	await _wait_dialogue_started(what, 6.0)
	await _sleep(0.6)
	await _advance_until_idle(what + " 按实际条数收束", max_presses, CHAT_PRESS_INTERVAL)
	await _wait_dialogue_finished(what)


func _wait_dialogue_started(what: String, timeout: float = 5.0) -> void:
	var runner: Node = _find_runner()
	var elapsed: float = 0.0
	while elapsed < timeout:
		if runner != null and not runner.is_idle():
			print("[M6Demo] 对话已开演：%s（耗时 %.1fs）" % [what, elapsed])
			return
		await _sleep(0.1)
		elapsed += 0.1
	push_warning("[M6Demo] 等待开演超时：%s（runner=%s）——后续按兜底流程走"
			% [what, runner != null])


func _wait_dialogue_finished(what: String, timeout: float = 5.0) -> void:
	var runner: Node = _find_runner()
	var elapsed: float = 0.0
	while elapsed < timeout:
		if runner == null or runner.is_idle():
			print("[M6Demo] 对话已收束：%s（耗时 %.1fs）" % [what, elapsed])
			return
		await _sleep(0.1)
		elapsed += 0.1
	push_warning("[M6Demo] 等待收束超时：%s——后续按兜底流程走" % what)


## 补按循环（M5 同款）：0.6s 一按直到 runner 回 IDLE；p_interval 可调
## （P0 51 条用 0.28s 控总时长；上限防御异常数据死等）。
func _advance_until_idle(what: String, max_presses: int,
		p_interval: float = 0.6) -> void:
	var runner: Node = _find_runner()
	var presses: int = 0
	while presses < max_presses:
		if runner == null or runner.is_idle():
			print("[M6Demo] %s：经 %d 次补按收束" % [what, presses])
			return
		runner.inject_interact_press()
		presses += 1
		await _sleep(p_interval)
	push_warning("[M6Demo] %s：补按 %d 次仍未收束（异常，交由 _wait_dialogue_finished 留痕）"
			% [what, presses])


# ------------------------------------------------------------------
# 菜单注入（MenuPanel._consume_event 公开测试直驱面——与 GUT 同通道）
# ------------------------------------------------------------------

func _menu_key() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_C   # menu_panel._is_menu_key 物理键回退通道
	ev.pressed = true
	return ev


func _menu_action(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _menu_tap(menu: Node, ev: InputEvent) -> void:
	menu._consume_event(ev)
	await _sleep(MENU_TAP_INTERVAL)


func _menu_stat(menu: Node, key: String) -> String:
	var block: Dictionary = menu.get_block(0)
	if block.is_empty():
		return "?"
	return String(block[key].text)


## GameData 队伍 → 战斗单位（等级/装备/当前 HP 全走生产并项口径：
## build_party_unit 内部 apply_equipment——与状态页数字同源不漂移）。
## BattleDirector（内部类）经 driver 引用调用。
func _build_party_from_gamedata() -> Array[Dictionary]:
	const BattleUnits := preload("res://scripts/data/battle_units.gd")
	var out: Array[Dictionary] = []
	for rec: Resource in GameData.party:
		var unit: Dictionary = BattleUnits.build_party_unit(String(rec.id), int(rec.level),
				{"weapon_id": String(rec.weapon_id), "armor_id": String(rec.armor_id)})
		if unit.is_empty():
			continue
		unit["hp"] = maxi(1, int(rec.hp))
		out.append(unit)
	var summary := ""
	for u: Dictionary in out:
		summary += "%sLv%d(H%d) " % [String(u.get("unit_id", "?")), int(u.get("level", 0)), int(u.get("hp", 0))]
	print("[M6Demo] 战斗队伍构建（GameData 口径含装备）： %s" % summary)
	return out


# ------------------------------------------------------------------
# 收尾验证（M5 指纹风格）
# ------------------------------------------------------------------

func _verify_m6_final_state() -> void:
	print("[M6Demo] 终态验证：story_phase=%d（预期 2）" % GameData.story_phase)
	if GameData.story_phase != 2:
		push_warning("[M6Demo] 终态验证 FAIL：story_phase=%d ≠ 2" % GameData.story_phase)
	for flag: String in ["story_p0_seen", "chat_road_01_seen", "chat_f2_01_seen"]:
		var has: bool = GameData.flags.has(flag)
		print("[M6Demo] 终态验证：flag %s = %s（预期 true）" % [flag, str(has)])
		if not has:
			push_warning("[M6Demo] 终态验证 FAIL：缺 flag %s" % flag)
	var kyle: Resource = GameData.party[0]
	print("[M6Demo] 终态验证：凯尔装备 weapon=%s armor=%s（预期 iron_sword/leather_armor）"
			% [String(kyle.weapon_id), String(kyle.armor_id)])
	print("[M6Demo] 终态验证：背包=%s（预期 小药瓶×2：用药后剩 1 + 飞蛾掉落 1）" % [GameData.inventory])
	# 存档指纹（demo 进度档——退出即被真实档覆盖恢复，仅作链路证据）
	if not SaveManager.has_save():
		push_warning("[M6Demo] 终态验证 FAIL：demo 进度存档不存在")
		return
	var f := FileAccess.open(SaveManager.save_path, FileAccess.READ)
	if f == null:
		push_warning("[M6Demo] 终态验证 FAIL：存档文件无法打开")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f = null
	if parsed == null or not (parsed is Dictionary):
		push_warning("[M6Demo] 终态验证 FAIL：存档不是合法 JSON 对象")
		return
	var snap: Dictionary = parsed as Dictionary
	print("[M6Demo] 存档指纹：map=%s position=%s story_phase=%d（预期 ruins_f2 / 入图落位 (384,40) / 2）"
			% [String(snap.get("map", "")), str(snap.get("position", [])), int(snap.get("story_phase", -1))])
	if String(snap.get("map", "")) == "ruins_f2" and int(snap.get("story_phase", -1)) == 2:
		print("[M6Demo] 终态验证 PASS：五镜头全链路落地（P0/菜单/胜利/逃跑/两段聊天）")
	else:
		push_warning("[M6Demo] 终态验证 FAIL：存档指纹不符（见上一行）")


## 日志期望提示（录制画面观察辅助；行为正确性以真实日志为准）
func _expect_log(what: String) -> void:
	print("[M6Demo] 期望日志：%s" % what)


## 底部字幕（Main/UILayer 顶层，半透明黑底提高可读性；TestLabel 隐藏让位）
func _build_caption() -> void:
	var layer: CanvasLayer = _main.get_node_or_null("UILayer") as CanvasLayer
	if layer == null:
		return
	var test_label: Node = layer.get_node_or_null("TestLabel")
	if test_label != null:
		(test_label as CanvasItem).visible = false   # 驱动器侧隐藏验活占位文本（非产品改动）
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


# ==================================================================
# 战斗导演（内部类）：叠加在真实 battle.tscn（E2-S3 占位方块阵）之上，
# 用真实 BattleCommand + BattleUI 打确定性剧本；battle_finished 交
# BattleResultHandler 走生产回图链——占位方块/按钮隐藏，结算揭示逐条弹出。
# ==================================================================
class BattleDirector extends Node2D:

	const BattleCommand := preload("res://scripts/battle/battle_command.gd")
	const BattleUI := preload("res://scripts/battle/battle_ui.gd")
	const BattleUnits := preload("res://scripts/data/battle_units.gd")

	const BEAT_TIME: float = 0.9          # 行动间停顿（弹字/HP 条可读）
	const VICTORY_HOLD: float = 4.2       # 结算展示（揭示 ~3.1s + 缓冲）
	const ESCAPE_HOLD: float = 1.6        # 逃跑结算展示
	const OUTRO_HOLD: float = 0.5         # 出战黑屏（BattleTransition.OUTRO_TIME）
	const ENEMY_ROLL: float = 0.5         # 敌 AI 固定 roll（attack 权重 100，不影响结果）
	const ESCAPE_ROLL: float = 0.0        # 逃跑检定固定 roll（三角色各 80%，0.0 必成）

	var driver: Node = null
	var script_kind: String = ""          # "victory" / "escape"
	var bc: BattleCommand = null
	var ui: Control = null
	var _final_result: Dictionary = {}


	func _ready() -> void:
		var payload: Dictionary = SceneRouter.get_staged_payload()
		var enc := String(payload.get("enemy_group_id", ""))
		script_kind = "victory" if enc == "b1_moth" else "escape"
		print("[M6Demo][Battle] 导演就绪：编组=%s 剧本=%s（真实 BattleCommand+BattleUI，占位方块阵隐藏）"
				% [enc, script_kind])
		_hide_placeholder()
		bc = BattleCommand.new()
		bc.setup(enc, driver._build_party_from_gamedata(), BattleUnits.build_encounter(enc))
		bc.start()
		bc.battle_over.connect(_on_battle_over)
		ui = BattleUI.new()
		ui.name = "BattleHUD"
		add_child(ui)
		ui.bind(bc)
		ui.play_transition_intro()
		_autoplay()


	## 隐藏 E2-S3 占位视觉（方块阵/占位队伍文本/结局按钮），保留暗色底
	func _hide_placeholder() -> void:
		var host: Node = get_parent()
		if host == null:
			return
		for n: String in ["EnemyBlocks", "PartyState", "BtnVictory", "BtnDefeat"]:
			var c: Node = host.get_node_or_null(n)
			if c != null:
				(c as CanvasItem).visible = false


	func _autoplay() -> void:
		await _sleep(0.7)
		var guard: int = 0
		while not bc.over and guard < 40:   # 防御护栏
			guard += 1
			var actor: Dictionary = bc.current_actor()
			if actor.is_empty():
				break
			if bc.is_party_turn():
				var command: Dictionary = _party_command(actor)
				print("[M6Demo][Battle] R%d %s 行动：%s" % [bc.round_num,
						String(actor.get("name", "?")), _describe(command)])
				if String(command.get("type", "")) == BattleCommand.CMD_ESCAPE:
					# M3 教训：逃跑检定的 roll 在 submit_command 第 4 位显式传入
					bc.submit_command(actor, command, 1.0, ESCAPE_ROLL)
				else:
					bc.submit_command(actor, command, 1.0)
			else:
				print("[M6Demo][Battle] R%d 敌方 行动（AI roll=%.2f 固定）"
						% [bc.round_num, ENEMY_ROLL])
				bc.enemy_action(actor, ENEMY_ROLL, 1.0)
			await _sleep(BEAT_TIME)
		var hold: float = VICTORY_HOLD if script_kind == "victory" else ESCAPE_HOLD
		await _sleep(hold)
		var trans: Node = ui.get_node_or_null("Transition")
		if trans != null and trans.has_method("play_outro"):
			trans.play_outro()
		await _sleep(OUTRO_HOLD)
		print("[M6Demo][Battle] 发 battle_finished(%s) → BattleResultHandler 生产回图链"
				% String(_final_result.get("outcome", "?")))
		EventBus.battle_finished.emit(_final_result)


	## 我方确定性剧本：逃跑剧本首行动即逃；胜利剧本凯尔/莉娜恒普攻、
	## 莫娜第 1 回合防御（展示防御指令），第 2 回合起普攻补刀。
	func _party_command(actor: Dictionary) -> Dictionary:
		if script_kind == "escape":
			return {"type": BattleCommand.CMD_ESCAPE}
		if String(actor.get("unit_id", "")) == "mona" and bc.round_num == 1:
			return {"type": BattleCommand.CMD_DEFEND}
		return _attack_first()


	func _attack_first() -> Dictionary:
		var targets: Array[Dictionary] = bc.targets_for({"type": BattleCommand.CMD_ATTACK})
		if not targets.is_empty():
			return {"type": BattleCommand.CMD_ATTACK,
					"target_slot": int(targets[0].get("slot", 0))}
		return {"type": BattleCommand.CMD_DEFEND}


	func _describe(command: Dictionary) -> String:
		match String(command.get("type", "")):
			BattleCommand.CMD_ATTACK:
				return "普攻 → 敌方槽位 %d" % int(command.get("target_slot", -1))
			BattleCommand.CMD_DEFEND:
				return "防御"
			BattleCommand.CMD_ESCAPE:
				return "逃跑（roll=%.1f 确定性成功）" % ESCAPE_ROLL
			_:
				return String(command.get("type", "?"))


	func _on_battle_over(result: Dictionary) -> void:
		_final_result = result
		var hold: float = VICTORY_HOLD if script_kind == "victory" else ESCAPE_HOLD
		print("[M6Demo][Battle] 结局 -> %s（结算画面展示 %.1fs，揭示中=%s，待弹 %d 行）"
				% [String(result.get("outcome", "?")), hold,
				str(ui.is_revealing()), ui.get_reveal_remaining()])


	func _sleep(t: float) -> void:
		await driver._sleep(t)   # 经驱动器计时（时间轴累计含战斗段）
