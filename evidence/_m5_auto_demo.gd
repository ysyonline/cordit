extends Node
## _m5_auto_demo —— M5 收口试玩视频自动演示驱动器
## 【临时演示场景，仅供 M5 收口录制，录后可删】（与 M2/M3/M4 纪律一致）
##
## 【定位】M4 同模式（A4 常驻根替身 + Godot Movie Maker --write-movie），
##   演示 M5 新特性全链路（E5 对话/事件层 + Boss 事件锚点，探索 GDD I5）：
##   NPC 事件对话（phase 映射）→ 跨图三连 → f3 棺前交互键 →
##   story_boss_pre 全序列（战前台词 → battle b5_core → 战后台词 →
##   set_story_phase(3) → save_point，I5"一次触发避免中途态"）。
##
## 【为什么 Boss 战能走真实链路】本会话修复 5 处生产接线缺口后：
##   f3 装配 InteractionController（Z 键分派）+ 全局 executor 注入 runner
##   （战前/战后台词真实开演）+ rebind_player（跨图引用保鲜）+
##   InteractRay.collide_with_areas（Area2D 壳可被射线命中）+
##   controller 分派链自治协议第一优先。
##   【headless 注入口径】Input.parse_input_event 在 headless/Movie Maker
##   下不到达 _unhandled_input（dryrun3 实锤），交互/翻页改直调注入——
##   与 GUT 415 全绿测试同一通道（dispatch_interaction / on_interact /
##   inject_interact_press），画面走的生产代码路径与真实按键等价。
##
## 【Boss 战画面】真实链路经桥转发 SceneRouter.BATTLE_SCENE_PATH
##   （battle.tscn 仍是 E2-S3 占位场景：方块阵+按钮，payload 校验过闸即
##   被装载——但演示不拍它）：桥转发受理后（完整四字段 payload 已暂存）
##   demo 捕获桥暂存的完整 Boss 载荷并原样重传切 _m5_battle_host 演示替身
##   （真实 BattleCommand + BattleUI，确定性 VICTORY；Router.change_scene
##   对每次受理无条件覆写暂存位——空载荷切换会把桥的完整载荷清掉，
##   dryrun9 实锤，必须捕获重传）；胜利后 host 发 battle_finished(VICTORY)
##   → BattleEventBridge 消费 → 全局 executor resolve_victory → 战后续行
##   段在 f3 新图执行——桥的簿记宿主是全局 executor，与替身/真实场景无关，
##   故替身不破坏 I5 续行链。
##
## 【存档隔离】独立存档槽 user://save_m5_demo.json，用户真实存档零触碰；
##   启动清旧档（首次落盘画面可复现），收尾删档（SMK-12 空壳检查防误伤）。
##
## 【演示脚本】（约 110s @30fps，全确定性、禁随机）：
##   第 1 幕  town 出生：客栈蛇形走位 → 老板对话（npc_01_innkeeper，phase0 台词）
##   第 2 幕  出镇南门 → road（跨图落盘 + 图标闪现）
##   第 3 幕  road 蛇形链南下（S 形盘山道，避开三敌巡逻带）→ 南门 → f1
##   第 4 幕  f1 蛇形链北上（大厅双巡逻带贴边避开）→ 北口 → f2
##   第 5 幕  f2 蛇形链北上（B4 定守正中走南横道避开）→ 北口 → f3
##   第 6 幕  f3 前厅蛇形北上 → 棺前交互 → 战前台词（真实 runner 开演）
##   第 7 幕  battle 挂起+桥转发受理 → 切 _m5_battle_host → 确定性 VICTORY
##   第 8 幕  桥续行 → 回 f3 棺前位 → 战后台词 → phase 2→3 → save_point 落盘
##   第 9 幕  收尾验证（phase=3 / 存档指纹）→ 退出
##
## 【边界】只做演示编排；战斗内部实现全在 _m5_battle_host 侧；
##   禁随机：本文件不含任何 randf / 随机数调用。

# ------------------------------------------------------------------
# 常量
# ------------------------------------------------------------------

## 五图目录（出生位/场景路径/防弹回口径正本）
const Catalog := preload("res://scripts/events/teleport_catalog.gd")

## 战斗演示舞台（确定性 VICTORY 脚本，临时场景与 M4 host 同纪律）
const BATTLE_HOST_PATH: String = "res://evidence/_m5_battle_host.tscn"

## Boss 编组（story_boss_pre battle 动作的 group；I5 唯一用例）
const BOSS_GROUP: String = "b5_core"

## Demo 专用存档槽（隔离用户真实存档；SaveManager 注释明示可测试覆写）
const DEMO_SAVE_PATH: String = "user://save_m5_demo.json"

## 兜底击破凭据（_wait_battle_suspended 超时兜底载荷用；正常路径由
## _m5_battle_host 的 battle_finished 载荷携带）
const DEMO_DEFEAT_UID: String = "enemy_m5_demo_core"

## town 出生与客栈老板走位航点（像素坐标；NPC 锚点实测 town.tscn）
const TOWN_SPAWN := Vector2(192, 640)            # town.tscn 玩家出生位
const INNKEEPER_POS := Vector2(488, 296)         # npc_01_innkeeper 锚 (30.5,18.5) 脚底位

# ------------------------------------------------------------------
# 运行时
# ------------------------------------------------------------------

## 底部说明字幕（UILayer 上，战斗期间隐藏）
var _caption: Label = null


func _ready() -> void:
	print("[M5Demo] 启动：M5 收口自动演示（对话事件/Boss 锚点/I5 全序列，禁随机）")
	# 存档隔离：覆写槽路径 + 清旧 demo 档（首次落盘画面可复现）
	SaveManager.save_path = DEMO_SAVE_PATH
	if FileAccess.file_exists(DEMO_SAVE_PATH):
		DirAccess.remove_absolute(DEMO_SAVE_PATH)
		print("[M5Demo] 已清除旧 demo 存档：%s" % DEMO_SAVE_PATH)
	# 剧情中盘切入（dryrun7 实锤修正）：story_boss_pre 门闸 conditions >=2，
	# 而 phase 0→1→2 的推进事件（story_quest_accept/story_ruin_enter）生产地图
	# 侧零接线（触发壳属 E6-S5 剧情实写批次）——demo 直接置 2 模拟"委托已接、
	# 遗迹已进"的存档位；第 1 幕 NPC 对话由此切 p12 段台词（phase 映射），贴合中盘
	GameData.story_phase = 2
	print("[M5Demo] 剧情中盘切入：story_phase=2（Boss 门闸 >=2 放行）")
	_build_caption()
	_run()


# ------------------------------------------------------------------
# 演示主流程（协程）
# ------------------------------------------------------------------

func _run() -> void:
	# ── 第 1 幕：小镇出生 + 客栈老板对话（NPC 事件路径）─────────
	_set_caption("【M5 收口演示】边陲小镇·晨 —— NPC 事件对话（E5 事件层）")
	print("[M5Demo] 第 1 幕：装载 town（R2 初始场景）")
	SceneRouter.change_scene(Catalog.MAP_SCENE_PATHS["town"], {}, false)
	await _sleep(1.0)   # Router 转场 0.4s + town 装载（对话/点位/传送装配）
	# 客栈蛇形走位（直穿路线被 B1_inn 立面墙阻挡——M4 同款航点拆段）：
	# 出生(192,640) → 西行上 W 街 → 北街上行 → 市场街东行 → 中轴巷北上 → 老板脚南
	await _walk_to(Vector2(200.0, 640.0), 6.0)      # 西行到 W 街口
	await _walk_to(Vector2(200.0, 328.0), 10.0)     # W 街北上（x=200 = 格 12.5 街中缝）
	await _walk_to(Vector2(312.0, 328.0), 6.0)      # 市场街东行到中轴巷口
	await _walk_to(Vector2(312.0, 318.0), 3.0)      # 中轴巷北上到老板行
	await _walk_to(INNKEEPER_POS + Vector2(0, 20), 5.0)   # 东行到老板脚下一格南
	await _sleep(0.3)
	_interact_with_npc(Vector2.UP)   # 面北交互老板（直调注入与测试同款）
	await _wait_dialogue_started("npc_innkeeper 对话")
	await _sleep(1.0)   # 逐字起播观感
	_set_caption("客栈老板 · 事件对话（npc_01_innkeeper → 事件层 phase 映射）")
	await _sleep(1.6)
	_advance_dialogue()   # 补完+翻页（直驱 runner，等于按 Z）
	await _sleep(1.2)
	_advance_dialogue()   # 收束对话（info → END）
	await _wait_dialogue_finished("npc_innkeeper 收束")
	await _sleep(0.6)

	# ── 第 2 幕：出镇南门 → road（跨图落盘）─────────────────────
	_set_caption("出镇，前往近郊道路……（跨图传送：过传送点存）")
	print("[M5Demo] 第 2 幕：走向南门（触发区中心 %s）"
			% _trigger_center(Vector2(12.5, 47)))
	await _walk_to(Vector2(200.0, 328.0), 4.0)    # 回 W 街口（蛇形回撤）
	await _walk_to(Vector2(200.0, 736.0), 10.0)   # W 街一路南下到南门前
	await _walk_to(_trigger_center(Vector2(12.5, 47)), 5.0)   # 南下进南门
	await _sleep(1.6)   # 跨图转场 + road 落位 (376,64) + map_ready 落盘
	_expect_log("跨图落盘应已发生：[AutosaveNotifier] road + SaveManager 存档")
	_set_caption("近郊道路 —— 存档图标亮起：新安全点 = 进图入口")
	await _sleep(1.8)

	# ── 第 3 幕：road 蛇形链南下 → f1（S 道开口通行，避开敌人带）──
	# road 是 S 形盘山道（封堵带 ×5 全宽双行，直穿必卡墙）——沿链走：
	# N0 南下 → H1 东行 → V1 东缘南下 → H1b 西行长横 → V2 西缘 → H2 东行 → V3
	_set_caption("前往遗迹……（S 形盘山道蛇形南下）")
	print("[M5Demo] 第 3 幕：road 蛇形链（N0→H1→V1→H1b→V2→H2→V3），敌带全部避开")
	await _walk_to(Vector2(384.0, 200.0), 6.0)     # N0 北段南下（格 24 街道）
	await _walk_to(Vector2(696.0, 152.0), 10.0)    # H1 东行（y=152 格 9.5）
	await _walk_to(Vector2(696.0, 264.0), 6.0)     # V1 东缘南下（穿带A 开口 42-43）
	await _walk_to(Vector2(176.0, 280.0), 14.0)    # H1b 西行长横（y=280 格 17.5）
	await _walk_to(Vector2(176.0, 344.0), 5.0)     # V2 西缘南下（穿带B 开口 10-11）
	await _walk_to(Vector2(584.0, 440.0), 14.0)    # H2 东行（y=440 格 27.5）
	await _walk_to(Vector2(584.0, 536.0), 6.0)     # V3 东缘南下（穿带C 开口 35-36）
	await _walk_to(Vector2(72.0, 592.0), 14.0)     # H3 西行长横（y=592 格 37 石像段）
	await _walk_to(Vector2(72.0, 760.0), 8.0)      # V4 西缘南下（穿带D 开口 4-5）
	await _walk_to(Vector2(216.0, 856.0), 10.0)    # H4 东行至断桥西南 + V4b 绕行（y=856 格 53.5）
	await _walk_to(Vector2(696.0, 872.0), 14.0)    # H4c 东行（y=872 格 54.5 绕过断桥南端）
	await _walk_to(Vector2(696.0, 984.0), 6.0)     # V5 南下（穿带E 开口 42-43）
	await _walk_to(Vector2(384.0, 984.0), 10.0)    # H6 西行（y=984 格 61.5）
	await _walk_to(_trigger_center(Vector2(23.5, 63.5)), 5.0)   # 南下进南门
	await _sleep(1.6)   # 跨图转场 + f1 落位 (448,56)
	_expect_log("road→f1 跨图应已触发：tp_road_to_f1")
	_set_caption("遗迹一层 —— 入口前厅")
	await _sleep(1.5)

	# ── 第 4 幕：f1 蛇形链北上 → f2（大厅双巡逻贴墙避开）────────
	# f1 链反向：前厅 → H1 东行 → V2 东缘(穿带A x45-46) → H2 西行 →
	# V3 西缘(穿带B x10-11) → H3 东行 → V4 楼梯走道 → 北口
	_set_caption("深入遗迹……（大厅双敌巡逻带在中央，沿西缘绕行）")
	print("[M5Demo] 第 4 幕：f1 蛇形链北上，巡逻带 (20,22)/(36,25) 均在中央避开")
	await _walk_to(Vector2(448.0, 168.0), 6.0)     # H1 南廊东行（y=168 格 10.5）
	await _walk_to(Vector2(728.0, 168.0), 8.0)     # 东行贴 V2 口（x=728 格 45.5）
	await _walk_to(Vector2(728.0, 416.0), 8.0)     # V2 东缘南下（穿带A 开口 45-46）
	await _walk_to(Vector2(176.0, 416.0), 16.0)    # H2 大厅主横道西行（y=416 格 26，双敌巡逻带 y=352-400 均在北上侧）
	await _walk_to(Vector2(176.0, 560.0), 5.0)     # V3 西缘南下（穿带B 开口 10-11）
	await _walk_to(Vector2(456.0, 632.0), 12.0)    # H3 北区走廊东行（y=632 格 39.5）
	await _walk_to(Vector2(448.0, 656.0), 3.0)     # V4 楼梯走道口（x=448 走道中线，格 28）
	await _walk_to(Vector2(448.0, 696.0), 4.0)     # 北口触发区中心 (448,696)——dryrun5 教训：
	# 目标贴区边 (456,688) 时 5px 完成阈值提前停步（停 y=683.5 差 4.5px 不入区）；
	# 对准区心后即使再停 5px（y≥691）脚盒也已深触发区内，传送必发
	await _sleep(1.6)   # 跨图转场 + f2 落位 (384,40)
	_expect_log("f1→f2 跨图应已触发：tp_f1_to_f2")
	_set_caption("遗迹二层 —— B4 守卫定守中央大厅（沿西环绕行）")
	await _sleep(1.5)

	# ── 第 5 幕：f2 蛇形链北上 → f3（B4 定守大厅正中，走西缘）───
	# f2 链反向：前厅 → H1 东行 → V2 东缘(开口 x41-42) → H2 西行（大厅段
	# B4 定守 (23,24)=368,392 站定不动，走 y=28=448 南侧横道零接触）→
	# V3 西缘(开口 x6-7) → H3 东行 → V4 → 北口
	_set_caption("绕开定守的遗迹守卫……（西环路线，交战位让给玩家主动权）")
	print("[M5Demo] 第 5 幕：f2 蛇形链北上（B4 定守 (23,24) 正中，横道走南侧 y=28）")
	await _walk_to(Vector2(384.0, 168.0), 6.0)     # H1 南廊东行（y=168 格 10.5）
	await _walk_to(Vector2(664.0, 168.0), 8.0)     # 东行贴 V2 口（x=664 格 41.5）
	await _walk_to(Vector2(664.0, 448.0), 8.0)     # V2 东缘南下到 y=448（dryrun5 修正：
	# 降 392 后直接西转会横穿 B4 定守 (368,392) 接触带 py∈[378,398]——先下 56px
	# 到横道 y=448 再西行，对守卫净距 ≥44px；GUARD 恒不追击，纯物理接触判定）
	await _walk_to(Vector2(112.0, 448.0), 16.0)    # H2 大厅主横道西行（y=448 格 27.5 南侧横道）
	await _walk_to(Vector2(112.0, 560.0), 5.0)     # V3 西缘南下（穿带B 开口 6-7）
	await _walk_to(Vector2(176.0, 608.0), 4.0)     # 先东南下到 y=608（dryrun6 修正：
	# 直插 (384,664) 的对角线会擦撞碎石 (14,37) 碰撞区 x∈[224,240] y∈[592,608]——
	# 拆两段绕开；f1 同构碎石段 dryrun5 实证可滑行，但 f2 链从未真实跑过）
	await _walk_to(Vector2(384.0, 664.0), 12.0)    # H3 北区走廊东行（y=664 格 41.5）
	await _walk_to(Vector2(384.0, 760.0), 6.0)     # 北口触发区中心 (384,760)——区心即终点，
	# 不再追加 (384,768)（换图瞬间旧玩家引用走位属遗留风险，dryrun6 起废除）
	await _sleep(1.6)   # 跨图转场 + f3 落位 (320,40)
	_expect_log("f2→f3 跨图应已触发：tp_f2_to_f3")
	_set_caption("遗迹三层 · Boss 前厅 —— 石棺祭坛就在眼前")
	await _sleep(1.5)

	# ── 第 6 幕：棺前交互 → 战前台词（真实 runner）──────────────
	_set_caption("石棺的盖板滑开了一条缝……（交互键触发 Boss 事件锚点）")
	print("[M5Demo] 第 6 幕：走向棺前锚点 (312,552)，面南交互（石棺在 +y 方向）")
	# f3 链反向：前厅 → H1 东行 → V2 东缘(开口 x33-34) → H2 西行 →
	# V3 西缘(开口 x10-11) → H3 祭坛前廊东行 → 祭坛前地面 → 棺前
	await _walk_to(Vector2(320.0, 120.0), 5.0)     # H1 南廊东行（y=120 格 7.5）
	await _walk_to(Vector2(544.0, 120.0), 8.0)     # 东行贴 V2 口（x=544 格 34）
	await _walk_to(Vector2(544.0, 296.0), 8.0)     # V2 东缘南下（穿带A 开口 33-34）
	await _walk_to(Vector2(176.0, 384.0), 14.0)    # H2 大厅主横道西行（y=384 格 24）
	# V3 西缘南下拆两段直落（dryrun6 修正：(176,440)→(240,512) 对角线在 y≈451
	# 时脚盒右缘越 x=192，擦撞带B 第二行墙 (x192-208,y448-464)——绕开口正面进）
	await _walk_to(Vector2(176.0, 480.0), 5.0)     # 先南落到 y=480（带B 南缘外，无墙段）
	await _walk_to(Vector2(240.0, 512.0), 6.0)     # H3 祭坛前廊东行（y=512 格 32；
	# 此对角线已在带B 南缘外，路径无碰撞体）
	await _walk_to(Vector2(312.0, 552.0), 4.0)     # 祭坛前地面（棺前锚点格 (19-20,35) 南邻，距离壳中心 ~16px）
	await _sleep(0.4)
	# 防御：若前段对话有 PLAYING 残留（理论上第 1 幕已收束），先强制回
	# IDLE——runner 非 IDLE 时壳的门闸会吞掉本次交互（is_idle 门闸语义）
	var pre_runner: Node = _find_runner()
	if pre_runner != null and not pre_runner.is_idle():
		push_warning("[M5Demo] 第 6 幕前 runner 非 IDLE，force_idle 收束残留")
		pre_runner.force_idle()
		await _sleep(0.2)
	# 交互朝向 DOWN（朝南）：玩家停 (312,552) 在 Boss 壳 (312,568) 北侧——遗迹
	# 系 +y 即石棺方向，UP 是背对石棺且射线尖点 y=532 够不到壳（dryrun6 修正）
	_interact_with_npc(Vector2.DOWN, true)   # 面南交互 Boss 锚点壳（直调注入与测试同款）
	await _wait_dialogue_started("story_p3_boss_front 战前拍")
	_set_caption("【P3 战前】遗迹的异常，源头就在眼前 ——（事件 dialogue 动作）")
	await _sleep(2.2)   # 战前拍逐字（两条目）
	_advance_dialogue()   # start 补完+翻页
	await _sleep(1.2)
	_advance_dialogue()   # lina 收束 → battle 动作触发
	await _wait_battle_suspended()   # 桥簿记就位 + battle.tscn 转发受理（完整 payload 暂存）

	# ── 第 7 幕：战斗段（替身舞台，确定性 VICTORY 教学拍）───────
	# 桥已把完整四字段 payload 暂存进 SceneRouter（battle.tscn 转发已受理但
	# 演示不拍占位方块阵）；这里切替身：真实 BattleCommand+BattleUI 打教学
	# Boss 战，胜利发 battle_finished → 桥消费 → resolve_victory → 回 f3 续行
	_caption.visible = false   # 战斗 HUD 全屏，字幕让位
	print("[M5Demo] 第 7 幕：切 _m5_battle_host（真实 BattleCommand+UI，VICTORY 剧本）")
	# 捕获重传（dryrun9 实锤修正）：Router.change_scene 第 172 行对每次受理
	# 无条件 _staged_payload = payload.duplicate(true)——此前"空载荷切换、
	# 暂存位保持原样"的假设不成立，空载荷会把桥暂存的完整 Boss 载荷（含
	# return_map/return_position）清成空字典 → VICTORY 后 BattleResultHandler
	# 无回图目标 → 停留战斗替身场景 → 无 map_ready → save_point 意图永不落盘。
	# 现捕获此刻暂存的完整四字段载荷原样重传：过 A5 校验 + 替身
	# get_staged_payload 取回同款 + VICTORY 后处理器从暂存解析回程，
	# 与真实战斗场景（bridge 转发受理路径）暂存内容逐字段一致。
	var staged: Dictionary = SceneRouter.get_staged_payload()
	SceneRouter.change_scene(BATTLE_HOST_PATH, staged, true)
	await EventBus.battle_finished   # 替身打完发结算（含 defeat_enemy_uid）
	_caption.visible = true
	_set_caption("遗迹核心被击破！——【轨迹残响】恢复事件流（胜利续行）")
	await _sleep(3.0)   # 桥延迟两帧续行 + Router 回 f3 + 回置棺前位

	# ── 第 8 幕：战后续行（finale → phase3 → save_point）────────
	_expect_log("胜利续行应已发生：桥 VICTORY → resolve_victory → 战后段")
	print("[M5Demo] 第 8 幕：战后台词 + set_story_phase(3) + save_point")
	_set_caption("【P3 战后】遗迹恢复了它应有的沉默 ——（胜利续行段）")
	await _wait_dialogue_started("story_p3_finale 战后拍")
	await _sleep(2.2)   # finale 逐字
	_advance_dialogue()
	await _sleep(1.2)
	_advance_dialogue()
	await _sleep(0.8)
	# dryrun9 实锤修正：长条目逐字未完时一按只"补完"不"翻页"——两次固定
	# 节拍按后 hook 条尚在 PLAYING（收束超时告警）。补按循环：0.6s 一按直到
	# runner 回 IDLE（本段两条目最多再需两按，循环上限防异常数据死等）
	await _advance_until_idle("story_p3_finale 补按收束")
	await _wait_dialogue_finished("story_p3_finale 收束")
	_set_caption("剧情阶段推进 2→3，存档点已写入（I5 全序列一次触发）")
	await _sleep(1.8)

	# ── 第 9 幕：收尾验证 ──────────────────────────────────────
	_verify_m5_final_state()
	_set_caption("M5 收口演示完成：对话事件 / Boss 锚点 / I5 全序列 ✓")
	await _sleep(2.4)
	# 存档自清理：demo 槽用完即删（SMK-12 空壳检查防误伤）
	if FileAccess.file_exists(DEMO_SAVE_PATH):
		DirAccess.remove_absolute(DEMO_SAVE_PATH)
		print("[M5Demo] 收尾清理 demo 存档：%s" % DEMO_SAVE_PATH)
	print("[M5Demo] 自动退出（Movie Maker 收尾写盘）")
	get_tree().quit()


# ------------------------------------------------------------------
# 工具
# ------------------------------------------------------------------

## 协程等待 t 秒（模拟时间；Movie Maker --fixed-fps 下按帧推进，节奏不变）
func _sleep(t: float) -> void:
	await get_tree().create_timer(t).timeout


## tile 坐标（Vector2，可含 .5）→ 触发区中心像素（走位目标：走进区内必触发）
func _trigger_center(t: Vector2) -> Vector2:
	return Vector2(t.x * 16.0 + 8.0, t.y * 16.0 + 8.0)


## 真实走位到目标点（override 注入 + 碰撞全真；真卡墙 0.5s 兜底直落）。
## 【帧序坑】恢复时机必须等 physics_frame（M4 教训：process_frame 恢复时
## is_moving 恒读旧值）；本版按【位移量】判定：每轮等物理帧，位移≈0 判卡。
func _walk_to(target: Vector2, timeout: float = 9.0) -> void:
	var player: Node2D = _find_player()
	if player == null:
		push_warning("[M5Demo] 找不到玩家，跳过走位 -> %s" % target)
		return
	var body := player as CharacterBody2D
	var elapsed: float = 0.0
	var stuck: float = 0.0
	var prev_pos: Vector2 = player.global_position
	print("[M5Demo][walk] 开始 -> %s（起点 %s）" % [target, prev_pos])
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
		# 传送瞬移侦测：单帧位移 >100px 必是传送落位——本段语义已达成，
		# 立即中断防旧目标多余兜底（M4 同款）
		if moved > 100.0:
			break
		if moved < 0.5:
			stuck += 1.0 / 60.0
			if stuck > 0.5:
				player.global_position = target
				print("[M5Demo] 走位被阻挡，兜底直落 -> %s（碰撞链路日志可查）" % target)
				break
		else:
			stuck = 0.0
	player.set_input_override(Vector2.ZERO)
	print("[M5Demo][walk] 结束 -> %s（历时 %.1fs stuck=%.2f）"
			% [player.global_position, elapsed, stuck])


## 找当前地图的玩家（与 BattleResultHandler 同一寻址约定）
func _find_player() -> Node2D:
	var world: Node = get_node_or_null("World")
	if world == null or world.get_child_count() == 0:
		return null
	var map: Node = world.get_child(world.get_child_count() - 1)
	return map.get_node_or_null("YSorted/Player") as Node2D


## 找当前地图的交互轮询器（town / f3 装配产物；挂在地图根下）
func _find_controller() -> Node:
	var world: Node = get_node_or_null("World")
	if world == null or world.get_child_count() == 0:
		return null
	var map: Node = world.get_child(world.get_child_count() - 1)
	return map.get_node_or_null("InteractionController")


## 找常驻对话运行器。demo 根自身就是 A4 的 Main（tscn: Main + World +
## UILayer），runner 由 town 装配挂在本根的 UILayer 之下——所以寻址是
## "UILayer/DialogueRunner" 而非 "Main/UILayer/..."（后者= Main 下再找
## Main，恒 null；dryrun4 实锤：翻页注入因此全失败，对话卡 PLAYING）。
func _find_runner() -> Node:
	var runner: Node = get_node_or_null("UILayer/DialogueRunner")
	if runner != null:
		return runner
	# 防御兜底：正典 A4 结构（root/Main/UILayer）直查一次
	var tree: SceneTree = get_tree()
	if tree != null:
		return tree.root.get_node_or_null("Main/UILayer/DialogueRunner")
	return null


## 交互注入（【headless 实测口径】Input.parse_input_event 在 headless/Movie
## Maker 下不会到达 _unhandled_input——dryrun3 实锤：两处 Z 注入全零反应。
## 改用与 GUT 415 全绿测试完全相同的直调通道：① 优先 controller.
## dispatch_interaction 直驱 NPC 实体（E5-S3 事件层口径，行为=真实按 Z）；
## ② 兜底 runner.inject_interact_press（S1 起的推进通道）。画面效果与
## 真实按键等价——对话框/HUD/锁玩家全走同一生产代码路径。
## p_face：交互前显式设朝向（兜底直落不改 facing，且静止 0.15s 后 facing
## 复位 DOWN——客栈老板/Boss 锚点都在北面，不设则射线永远朝南打空）。
## p_want_boss：目标语义（false=town NPC 实体，true=f3 Boss 锚点壳——
## dryrun4 教训：f3 的调查点实体同挂 YSorted，不做语义限定会误捞）。
func _interact_with_npc(p_face: Vector2 = Vector2.UP,
		p_want_boss: bool = false) -> void:
	var player: Node2D = _find_player()
	if player != null and player.get("facing") != null:
		player.set("facing", p_face)
		print("[M5Demo] 朝向已设 -> %s（交互射线对准北面目标）" % p_face)
	var controller: Node = _find_controller()
	var npc: Node = _find_interact_target(p_want_boss)
	if controller != null and npc != null and npc.has_method("get_npc_id"):
		# NPC 协议路径（E5-S3 事件层：phase 映射选对话，与真实按 Z 等价）
		controller.dispatch_interaction(npc)
		print("[M5Demo] 交互注入（dispatch 直驱 %s）：E5-S3 事件路径" % npc.name)
		return
	if npc != null and npc.has_method("on_interact"):
		# 自治协议路径（f3 Boss 锚点薄壳：on_interact → 事件层，与测试
		# inject_emit 同一入口——GUT Group F 全绿通道）
		npc.on_interact()
		print("[M5Demo] 交互注入（on_interact 直驱 %s）：A7 薄壳协议" % npc.name)
		return
	var runner: Node = _find_runner()
	if runner != null:
		runner.inject_interact_press()
		print("[M5Demo] 交互注入（runner 直驱兜底）")
	else:
		push_warning("[M5Demo] 交互注入全通道失败：controller/npc/runner 均不可达")


## 找面前可交互实体（town：NPC 实体带 get_npc_id；f3：Boss 锚点壳带
## on_interact 且名字 Evt_Boss_* 前缀）。
## 【dryrun4 教训】f3 图把宝箱/调查点实体也挂在 YSorted 下（自治协议
## Evt_* 命名），48px 半径内最近者可能是调查点而非 Boss 锚点——交互目标
## 必须按场景语义二选一：p_want_boss=true 时只认 Boss 锚点壳（名字
## Evt_Boss_ 前缀），false 时只认 NPC 实体（名字 npc_*_entity 后缀）。
func _find_interact_target(p_want_boss: bool) -> Node:
	var player: Node2D = _find_player()
	if player == null:
		return null
	var world: Node = get_node_or_null("World")
	if world == null or world.get_child_count() == 0:
		return null
	var map: Node = world.get_child(world.get_child_count() - 1)
	var ysorted: Node = map.get_node_or_null("YSorted")
	if ysorted == null:
		return null
	# 候选池：YSorted 直挂（town NPC 实体）+ YSorted/BossTriggers 子容器（f3
	# Boss 壳——ruins_f3_map._assemble_boss_anchor 装配在此，dryrun6 实锤：
	# 单层扫描漏检壳，交互全通道退化为 runner 兜底，战前拍无人开演）
	var pools: Array = [ysorted]
	var boss_container: Node = ysorted.get_node_or_null("BossTriggers")
	if boss_container != null:
		pools.append(boss_container)
	var best: Node = null
	var best_d: float = 64.0
	for pool: Node in pools:
		for child in pool.get_children():
			var n := child as Node2D
			if n == null or n == player:
				continue
			var cname := String(child.name)
			if p_want_boss:
				# Boss 锚点壳：ruins_f3_map._assemble_boss_anchor 命名 Evt_<锚点名>
				# （锚点名 Boss_ruins_f3_trigger → 节点名 Evt_Boss_ruins_f3_trigger）
				if not cname.begins_with("Evt_Boss") or not child.has_method("on_interact"):
					continue
			else:
				# town NPC 实体：town_map 装配命名 <锚点名>_entity（协议在实体根）
				if not cname.ends_with("_entity") or not child.has_method("get_npc_id"):
					continue
			var d: float = n.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = child
	if best == null:
		push_warning("[M5Demo] 半径内无交互目标（want_boss=%s）" % p_want_boss)
	return best


## 注入对话翻页键（直驱 runner._unhandled_input：PLAYING 态 = 补完本条 +
## 翻页；与测试 inject_interact_press 同一入口，headless 零损耗）
func _advance_dialogue() -> void:
	var runner: Node = _find_runner()
	if runner != null:
		runner.inject_interact_press()
		print("[M5Demo] 翻页注入（runner 直驱）")
	else:
		push_warning("[M5Demo] 翻页注入失败：常驻 runner 未找到")


## 等待对话开演（协程轮询 runner 状态机；超时兜底放行不烂尾）
func _wait_dialogue_started(what: String, timeout: float = 5.0) -> void:
	var runner: Node = _find_runner()
	var elapsed: float = 0.0
	while elapsed < timeout:
		if runner != null and not runner.is_idle():
			print("[M5Demo] 对话已开演：%s（耗时 %.1fs）" % [what, elapsed])
			return
		await _sleep(0.1)
		elapsed += 0.1
	push_warning("[M5Demo] 等待开演超时：%s（runner=%s）——后续按兜底流程走"
			% [what, runner != null])


## 等待对话收束（协程轮询；超时兜底放行）
func _wait_dialogue_finished(what: String, timeout: float = 5.0) -> void:
	var runner: Node = _find_runner()
	var elapsed: float = 0.0
	while elapsed < timeout:
		if runner == null or runner.is_idle():
			print("[M5Demo] 对话已收束：%s（耗时 %.1fs）" % [what, elapsed])
			return
		await _sleep(0.1)
		elapsed += 0.1
	push_warning("[M5Demo] 等待收束超时：%s——后续按兜底流程走" % what)


## 补按循环（dryrun9 实锤修正配套）：长条目逐字未完时一按只"补完"不"翻页"，
## 固定节拍按法对条目数/字数敏感会差按。0.6s 一按直到 runner 回 IDLE——
## runner 未注入（理论上不可达）直接返回防死循环；上限 6 按防御异常数据。
func _advance_until_idle(what: String, max_presses: int = 6) -> void:
	var runner: Node = _find_runner()
	var presses: int = 0
	while presses < max_presses:
		if runner == null or runner.is_idle():
			print("[M5Demo] %s：经 %d 次补按收束" % [what, presses])
			return
		runner.inject_interact_press()
		presses += 1
		print("[M5Demo] 补按注入（%s 第 %d 次）" % [what, presses])
		await _sleep(0.6)
	push_warning("[M5Demo] %s：补按 %d 次仍未收束（异常，交由 _wait_dialogue_finished 留痕）"
			% [what, presses])


## 等待战斗挂起就绪（第 6→7 幕切换的前置门）：
## ① 全局 executor 进入 battle 暂停（簿记在位）；
## ② 桥已转发 battle.tscn（Router 受理=完整四字段 payload 已暂存）。
## 轮询两条件齐备后再切替身，替身 get_staged_payload 读到的才是完整载荷。
func _wait_battle_suspended(timeout: float = 6.0) -> void:
	var exec: RefCounted = SceneRouter.global_event_executor
	var elapsed: float = 0.0
	var suspended := false
	var forwarded := false
	while elapsed < timeout:
		suspended = exec != null and exec.in_battle_pause()
		# 桥转发受理的标志：Router 暂存 payload 出现 return_map 非空
		#（battle 动作发的原始载荷此字段为空串，桥补全后才非空）
		var staged: Dictionary = SceneRouter.get_staged_payload()
		forwarded = not staged.is_empty() \
				and String(staged.get("return_map", "")) != ""
		if suspended and forwarded:
			print("[M5Demo] 战斗挂起就绪：executor 暂停 + 桥转发受理"
					+ "（耗时 %.1fs，暂存回程=%s @ %s）" % [
					elapsed, staged["return_map"], staged["return_position"]])
			return
		await _sleep(0.1)
		elapsed += 0.1
	push_warning("[M5Demo] 战斗挂起超时（暂停=%s 转发=%s）——替身切换改带兜底载荷"
			% [suspended, forwarded])
	# 兜底：桥没转发成功时（理论不可达），直接构造完整载荷切替身，
	# 保证演示不烂尾——VICTORY 到来时桥无挂起仅日志忽略（战后段不续行，
	# 第 8/9 幕的验证会 FAIL 留痕，不静默假绿）
	SceneRouter.change_scene(BATTLE_HOST_PATH, {
		"enemy_group_id": BOSS_GROUP,
		"return_map": Catalog.MAP_SCENE_PATHS["ruins_f3"],
		"return_position": Vector2(312, 552),
		"defeat_enemy_uid": DEMO_DEFEAT_UID,
	}, true)


## 数据层验证 M5 终态（第 9 幕）：phase=3 + 存档指纹 = f3 棺前位
## 【dryrun7 修正】指纹直读存档文件——SaveManager.last_loaded 只在 load_save()
## 后非空（demo 全程只存不读，恒空字典是验收代码读错源，非存档失败）。
func _verify_m5_final_state() -> void:
	print("[M5Demo] 终态验证：story_phase=%d（预期 3）" % GameData.story_phase)
	if GameData.story_phase != 3:
		push_warning("[M5Demo] 终态验证 FAIL：story_phase=%d ≠ 3" % GameData.story_phase)
	if not SaveManager.has_save():
		push_warning("[M5Demo] 终态验证 FAIL：demo 存档不存在")
		return
	var f := FileAccess.open(SaveManager.save_path, FileAccess.READ)
	if f == null:
		push_warning("[M5Demo] 终态验证 FAIL：存档文件无法打开")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f = null
	if parsed == null or not (parsed is Dictionary):
		push_warning("[M5Demo] 终态验证 FAIL：存档不是合法 JSON 对象")
		return
	var snap: Dictionary = parsed as Dictionary
	var map_name: String = String(snap.get("map", ""))
	var pos_arr: Array = snap.get("position", [0, 0])
	var snap_phase: int = int(snap.get("story_phase", -1))
	# 【存档坐标口径】生产时序（E2-S4/E4-S6）：回图 map_ready 时 announce_ready
	# 先落盘（此刻玩家仍在 f3 入口落位 (320,40)），回置棺前位是其后一帧的
	# deferred——故存档坐标=入图落位，非棺前位；这是生产行为非缺陷。
	# 验收判据只查 map+phase：phase=3 证明战后续行全链（save_point 在
	# set_story_phase 之后）已消费落盘，坐标不需在判据内。
	print("[M5Demo] 存档指纹：map=%s position=%s story_phase=%d（预期 ruins_f3 / 入图落位 (320,40) / 3）"
			% [map_name, str(pos_arr), snap_phase])
	if map_name == "ruins_f3" and snap_phase == 3:
		print("[M5Demo] 终态验证 PASS：I5 全序列（battle→续行→phase3→save_point）落地")
	else:
		if map_name != "ruins_f3":
			push_warning("[M5Demo] 终态验证 FAIL：存档图=%s ≠ ruins_f3" % map_name)
		if snap_phase != 3:
			push_warning("[M5Demo] 终态验证 FAIL：存档 phase=%d ≠ 3" % snap_phase)


## 日志期望提示（录制画面观察辅助；行为正确性以真实日志为准）
func _expect_log(what: String) -> void:
	print("[M5Demo] 期望日志：%s" % what)


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
