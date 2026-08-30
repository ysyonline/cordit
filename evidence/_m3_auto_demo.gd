extends Node
## _m3_auto_demo —— M3 门3 试玩视频自动演示驱动器
## 【临时演示场景，仅供 M3 门3 录制，录后可删】（与 M2 收口纪律一致）
##
## 【定位】M2 曾用同一模式录过 evidence/m2-gameplay.avi（auto-demo 场景 +
##   Godot Movie Maker --write-movie）。M2 的 demo 脚本"录完即删"，本文件按
##   同一模式重写，且升级为"打真战斗"：
##   - 本场景是【A4 常驻根替身】：节点名 Main + World + UILayer/FadeMask，
##     结构与 scenes/main.tscn 一致——SceneRouter / BattleResultHandler
##     都按 "Main/World"、"Main/UILayer/FadeMask" 寻址，故能复用真实
##     场景切换（0.2s 黑屏转场）与战后回图全链路，零修改业务代码。
##   - 战斗本体在 evidence/_m3_battle_host.tscn（本驱动经 SceneRouter
##     正常切换装入 World，战斗结束发 battle_finished 由真处理器回图）。
##
## 【演示脚本】（约 17s @30fps，全确定性、禁随机）：
##   0.0s  白盒图 A 装载，玩家向右走 1.6s（注入 set_input_override）
##   ~3s   切入战斗（Router 淡出淡入 = 进战黑屏转场）
##   ~3-13s 战斗（见 _m3_battle_host.gd：普攻→防御→火球弱点！→敌方行动
##          →普攻→治疗→火球收尾 → 胜利结算 → 出战黑屏）
##   ~13-15s BattleResultHandler 写回 + 回图 + 玩家回置
##   ~15s  打印"录制完成"，1.2s 后自动退出（Movie Maker 收尾写盘）
##
## 【边界】只做演示编排：不引用战斗内部实现（全在 battle_host 侧）；
##   GameData 仅注入演示背包（potion_s×2，让"道具"按钮点亮更真实）；
##   禁随机：本文件不含任何 randf / 随机数调用。

# ------------------------------------------------------------------
# 常量
# ------------------------------------------------------------------

## 演示用地图（E1 白盒图 A：640×360 单屏，相机限区钳制后画面完整）
const DEMO_MAP_PATH: String = "res://tests/smoke/fixtures/map_a.tscn"

## 战斗演示舞台（临时场景，与 M2 的 demo map 同目录同纪律）
const BATTLE_HOST_PATH: String = "res://evidence/_m3_battle_host.tscn"

## 遇敌编组：B2 雷壳甲虫×2（弱火）——火球首杀触发"弱点！"+击退的爽点场
const ENCOUNTER_ID: String = "b2_beetles"

## 战后回置点（= map_a 玩家出生点，BattleResultHandler 会回置 + 免疫 0.5s）
const RETURN_POSITION: Vector2 = Vector2(96, 160)

## 节奏（秒）
const WALK_DURATION: float = 1.6

# ------------------------------------------------------------------
# 运行时
# ------------------------------------------------------------------

## 底部说明字幕（UILayer 上，战斗期间隐藏）
var _caption: Label = null


func _ready() -> void:
	print("[M3Demo] 启动：M3 门3 自动演示（b2_beetles 弱火教学场，禁随机）")
	# 演示背包：让战斗菜单"道具"项点亮（真仓库键值结构，战斗侧读 GameData）
	GameData.inventory["potion_s"] = 2
	_build_caption()
	_run()


# ------------------------------------------------------------------
# 演示主流程（协程）
# ------------------------------------------------------------------

func _run() -> void:
	# ── 第 1 幕：地图探索 ──────────────────────────────────────
	_set_caption("【M3 门3 自动演示】探索近郊道路……")
	print("[M3Demo] 装载 demo 图 ", DEMO_MAP_PATH)
	SceneRouter.change_scene(DEMO_MAP_PATH, {}, false)
	await _sleep(0.7)   # Router 淡出淡入 0.4s + 装载

	var player: Node2D = _find_player()
	if player != null:
		_clamp_camera(player)
		player.set_input_override(Vector2.RIGHT)
		print("[M3Demo] 玩家向右前进 %.1fs" % WALK_DURATION)
	await _sleep(WALK_DURATION)
	if player != null:
		player.set_input_override(Vector2.ZERO)

	# ── 第 2 幕：切入战斗（Router 黑屏转场）─────────────────────
	_set_caption("遭遇雷壳甲虫！切入战斗……")
	print("[M3Demo] 触发进战（enemy_touched 同源：Router 受理 + payload 校验）")
	var payload: Dictionary = {
		"enemy_group_id": ENCOUNTER_ID,
		"return_map": DEMO_MAP_PATH,
		"return_position": RETURN_POSITION,
		"defeat_enemy_uid": "enemy_m3_demo",
	}
	SceneRouter.change_scene(BATTLE_HOST_PATH, payload, true)
	await _sleep(0.4)
	_caption.visible = false   # 战斗 HUD 自带全屏视图，字幕让位

	# ── 第 3 幕：战斗全程（在 battle_host 内自动执行）────────────
	await EventBus.battle_finished
	print("[M3Demo] battle_finished 收到（VICTORY）→ 等待处理器回图")
	await _sleep(2.4)   # Router 回图淡入淡出 + 地图装载 + 玩家回置/免疫

	# ── 第 4 幕：战后回图 ──────────────────────────────────────
	_caption.visible = true
	_set_caption("战斗胜利！已回到地图 —— 录制完成")
	print("[M3Demo] 录制完成：进战转场 / 普攻 / 火球弱点(闪白+弹字+击退) / "
			+ "敌方行动 / 防御 / 治疗 / 胜利结算 / 回图 全覆盖")
	await _sleep(1.2)
	print("[M3Demo] 自动退出（Movie Maker 收尾写盘）")
	get_tree().quit()


# ------------------------------------------------------------------
# 工具
# ------------------------------------------------------------------

## 协程等待 t 秒（模拟时间；Movie Maker --fixed-fps 下按帧推进，节奏不变）
func _sleep(t: float) -> void:
	await get_tree().create_timer(t).timeout


## 找当前地图的玩家（与 BattleResultHandler 同一寻址约定）
func _find_player() -> Node2D:
	var world: Node = get_node_or_null("World")
	if world == null or world.get_child_count() == 0:
		return null
	var map: Node = world.get_child(world.get_child_count() - 1)
	return map.get_node_or_null("YSorted/Player") as Node2D


## 把玩家相机钳进 640×360 单屏（白盒图恰好一屏，避免拍到图外的空底色）
func _clamp_camera(player: Node2D) -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 640
	cam.limit_bottom = 360


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
