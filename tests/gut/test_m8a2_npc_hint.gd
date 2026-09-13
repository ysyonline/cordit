extends GutTest
## test_m8a2_npc_hint.gd —— M8-A② NPC 头顶交互提示（❗Z 脉冲）【rev3】
##
## 【被测行为】NPC 是玩家**当前可交互目标**时（面朝 + InteractRay 命中——与 Z 键
##   分派同一判据），头顶浮出金色「❗Z」脉冲标签；转开/离开/对话中即隐。
##   rev2 由 InteractionController 每物理帧统一驱动（不再由 npc.gd 按距离判定）。
##   rev3 增「朝向保持 + 去抖」：修复"正后方/其他角度会亮一下 ❗ 然后不亮"。
##
## 【分组】
##   A 结构：提示随 NPC 建立、样式合规（❗Z / 金 / z_index>Above / 默认隐藏）
##   B 邻近（面朝）：玩家链驱动——正后方近距不亮、转到正前方亮、转开灭；
##     对话锁定中收起（未冻结玩家物理，朝向由用例确定性设定）
##   C 鲁棒：无玩家环境恒隐不炸；裸脚本 NPC 未入树零副作用（e5s3/e5s4 同款）
##   D 生命周期：town 12 NPC 各持一枚且挂地图子树内；提示随宿主释放而销毁
##   E 跨图泄漏回归（rev2 缺陷②）：告示板/Boss 提示挂地图根、不挂 current_scene；
##     释放旧图提示随之消亡、current_scene 零残留
##   F 朝向保持 + 去抖（rev3）：【非冻结真实玩家 + set_input_override】令真实
##     _update_facing 松键动力学进入被测路径——F1 回归红线（松键后朝向保持、
##     不复位 DOWN 致误亮）、F2 正向对照（面朝合法常亮）、F3 去抖（瞬时命中不亮）
##
## 【跑法】项目根下（APPDATA 沙盒必带——GUT 不隔离用户存档教训）：
##   MSYS2_ARG_CONV_EXCL="*" APPDATA=<sandbox> Godot_console.exe --headless
##   --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit
##
## 【O-7 口径】B/F 组一律用【玩家驱动链】触发：设定真实 player 节点并等物理帧由
##   控制器自行判定翻转（判据 = player.get_interact_target()，产物 = 真射线命中）；
##   只读 observable 的 hint.visible，不直驱提示内部字段。F 组刻意【不冻结】玩家
##   物理——rev3 的缺陷正藏在真实 _update_facing 的松键复位里（rev2 用例盲区）。

const NpcScene := preload("res://scenes/npc/npc.tscn")
const NpcScript := preload("res://scripts/npc/npc.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const WorldHint := preload("res://scripts/ui/world_hint.gd")
const InteractionControllerScript := preload("res://scripts/events/interaction_controller.gd")
const TownScenePath: String = "res://scenes/maps/town.tscn"
const F3ScenePath: String = "res://scenes/maps/ruins_f3.tscn"

## GameData 快照（town 装配读 story_phase 等；还原防跨套件污染，b01 同纪律）
var _snapshot: Dictionary = {}
var _world: Node2D = null
var _npc: StaticBody2D = null
var _player: Node2D = null
var _ctrl: Node = null


func before_each() -> void:
	_snapshot = {
		"story_phase": GameData.story_phase,
		"flags": GameData.flags.duplicate(true),
		"inventory": GameData.inventory.duplicate(true),
		"chests_opened": GameData.chests_opened.duplicate(true),
	}


func after_each() -> void:
	GameData.story_phase = _snapshot["story_phase"]
	GameData.flags = _snapshot["flags"]
	GameData.inventory = _snapshot["inventory"]
	GameData.chests_opened = _snapshot["chests_opened"]


## 造"世界"（容器 + NPC）；无控制器/无玩家 → 提示保持默认隐藏（A/C 组结构面用）
func _make_world() -> void:
	_world = Node2D.new()
	_world.name = "M8A2TestWorld"
	add_child_autofree(_world)
	_npc = NpcScene.instantiate()
	_world.add_child(_npc)
	_npc.position = Vector2(200, 200)


## 造"受控世界"：容器 + NPC + 交互控制器 + 真玩家实例（player.tscn，带 InteractRay）。
## 【p_freeze_player】true（默认，B 组用）→ 冻结玩家物理处理：朝向/位置由用例直接
##   确定性设定，隔离朝向动力学；false（F 组用）→ 保留玩家真实 _physics_process，
##   令 _update_facing 的松键动力学进入被测路径（rev3 缺陷所在）。
##   两种模式下被驱链均生产同源：controller → player.get_interact_target()（面朝 + 射线命中）。
func _make_led_world(p_with_player: bool = true, p_freeze_player: bool = true) -> void:
	_world = Node2D.new()
	_world.name = "M8A2LedWorld"
	add_child_autofree(_world)
	_npc = NpcScene.instantiate()
	_world.add_child(_npc)
	_npc.position = Vector2(200, 200)
	_ctrl = Node.new()
	_ctrl.set_script(InteractionControllerScript)
	_world.add_child(_ctrl)
	if p_with_player:
		_player = PlayerScene.instantiate()
		_world.add_child(_player)
		if p_freeze_player:
			_player.set_physics_process(false)   # 冻结自身逻辑：朝向/位置由用例确定性设定
		_player.position = Vector2(600, 600) # 远：默认不在瞄准线
		_ctrl.setup(_player, null)
	else:
		_ctrl.setup(null, null)


## 等 n 个物理帧（触发 controller._physics_process 自行判定）。
## 【rev3 去抖】控制器点亮需连续 HINT_SETTLE_FRAMES(=3) 帧稳定命中，故断言"亮"
##   前须 ≥3 帧（B 组统一用 6 帧留余量）；断言"灭"（即时熄灭）不受影响。
func _tick_physics(p_n: int) -> void:
	for i in p_n:
		await get_tree().physics_frame


func _hint_of(p_npc: Node) -> Label:
	return p_npc.get_node_or_null("InteractHint") as Label


## 假 current_scene（root 直下）——验证提示不挂它。
## 【为何不叫 "Main"】旧泄漏代码的判据是 `current_scene != null`（与名字无关），
##   故用任意非空 current_scene 即可复现；刻意避开 "Main" 名 → 不触发 town 的
##   P0 生产启动守卫（`cs.name == "Main"`），避免本用例误接线开局触发器。
func _make_fake_scene() -> Node:
	var scene := Node2D.new()
	scene.name = "FakeScene"
	get_tree().root.add_child(scene)
	return scene


# ------------------------------------------------------------------
# Group A —— 结构：提示随 NPC 建立 + 样式合规
# ------------------------------------------------------------------

func test_a1_提示随NPC建立且样式合规并默认隐藏() -> void:
	_make_world()
	var hint: Label = _hint_of(_npc)
	assert_not_null(hint, "NPC 应建立头顶『❗Z』提示（InteractHint 子节点）")
	if hint == null:
		return
	assert_eq(hint.text, "❗Z", "文案=❗Z（沿用已验收样式，直接教交互键）")
	assert_eq(hint.z_index, WorldHint.HINT_Z_INDEX, "z_index 应为工厂常量 HINT_Z_INDEX")
	assert_gt(hint.z_index, 10, "z_index 须 > Above(z=+10)——保证不被树冠/建筑层掩")
	assert_eq(hint.mouse_filter, Control.MOUSE_FILTER_IGNORE, "提示不吃鼠标点击")
	assert_false(hint.visible, "装配即默认隐藏（是可交互目标才显，非常驻气泡）")
	assert_true(_npc.has_method("set_interact_hint_visible"),
			"NPC 应暴露提示开关（交互轮询器唯一驱动口）")


# ------------------------------------------------------------------
# Group B —— 邻近显隐（面朝 + 射线命中；玩家链驱动）
# ------------------------------------------------------------------

func test_b1_仅当玩家面朝NPC且命中才亮() -> void:
	_make_led_world()
	var hint: Label = _hint_of(_npc)
	assert_not_null(hint, "前置：NPC 提示已建立")
	if hint == null:
		return
	# ① 正后方近距（16px，脚底距离 < 旧 24px 阈值）但面朝背离 → 不亮
	_player.position = Vector2(200 + 16, 200)   # 位于 NPC 右侧 16px
	_player.facing = Vector2.RIGHT              # 背对 NPC
	await _tick_physics(6)
	assert_false(hint.visible, "面朝背离且近距 → 不亮（提示=可交互，非纯距离）")
	assert_null(_player.get_interact_target(),
			"同源锚：背离时 Z 键亦无目标（提示亮灭与分派判据一致）")
	# ② 转到正前方近距（NPC 左侧 16px，面朝右 → 射线命中）→ 亮
	_player.position = Vector2(200 - 16, 200)
	_player.facing = Vector2.RIGHT
	await _tick_physics(6)
	assert_true(hint.visible, "面朝 NPC 且射线命中 → 亮（提示亮 ⇔ 按 Z 有目标）")
	assert_not_null(_player.get_interact_target(), "同源锚：面朝时 Z 键有目标")
	# ③ 转开（面朝左，背离）→ 灭
	_player.facing = Vector2.LEFT
	await _tick_physics(6)
	assert_false(hint.visible, "转开后 → 灭")
	# ④ 再转回面朝 NPC → 亮（可逆）
	_player.facing = Vector2.RIGHT
	await _tick_physics(6)
	assert_true(hint.visible, "转回面朝 → 再亮（可逆）")


func test_b2_对话锁定中提示收起_借玩家锁() -> void:
	_make_led_world()
	var hint: Label = _hint_of(_npc)
	assert_not_null(hint, "前置：NPC 提示已建立")
	if hint == null:
		return
	_player.position = Vector2(200 - 16, 200)
	_player.facing = Vector2.RIGHT
	await _tick_physics(6)
	assert_true(hint.visible, "哨兵：面朝且未锁定 → 亮")
	_player.call("set_input_locked", true)   # 借 player.gd 既有对话锁开关
	await _tick_physics(6)
	assert_false(hint.visible, "对话锁定中提示收起（不与对话框抢视线）")
	_player.call("set_input_locked", false)
	await _tick_physics(6)
	assert_true(hint.visible, "解锁后提示恢复（对话结束即恢复引导）")


# ------------------------------------------------------------------
# Group C —— 鲁棒：无玩家 / 裸脚本未入树
# ------------------------------------------------------------------

func test_c1_无玩家环境提示恒隐不炸() -> void:
	_make_led_world(false)   # 有控制器、无玩家
	var hint: Label = _hint_of(_npc)
	assert_not_null(hint, "无玩家时提示节点仍随 NPC 建立（结构不依赖玩家）")
	if hint == null:
		return
	await _tick_physics(3)
	assert_false(hint.visible, "无玩家 → 提示恒隐藏（不报错、不打日志刷屏）")


func test_c2_裸脚本NPC未入树零副作用() -> void:
	# e5s3/e5s4 同款：StaticBody2D + NpcScript 建而不入树 → _ready 不触发
	var bare := StaticBody2D.new()
	bare.set_script(NpcScript)
	bare.npc_id = "npc_bare"
	assert_null(bare.get_node_or_null("InteractHint"),
			"未入树裸脚本 _ready 未触发 → 无提示（无副作用、不报错）")
	assert_eq(bare.get_npc_id(), "npc_bare", "交互协议 get_npc_id() 不受提示逻辑影响")
	# 开关对未建提示的实例安全（null 守卫，不炸）
	bare.call("set_interact_hint_visible", true)
	bare.free()


# ------------------------------------------------------------------
# Group D —— 生命周期：挂地图子树内 + 随宿主释放
# ------------------------------------------------------------------

func test_d1_town12NPC各持提示且挂地图子树内不泄根() -> void:
	GameData.story_phase = 0
	var map: Node = (load(TownScenePath) as PackedScene).instantiate()
	add_child_autofree(map)
	var ysorted: Node = map.get_node_or_null("YSorted")
	assert_not_null(ysorted, "town 应有 YSorted 容器")
	if ysorted == null:
		return
	var entities := 0
	var with_hint := 0
	var leaked := 0
	for child: Node in ysorted.get_children():
		if "npc_id" in child:
			entities += 1
			var h: Node = child.get_node_or_null("InteractHint")
			if h != null:
				with_hint += 1
				if not map.is_ancestor_of(h):
					leaked += 1
	assert_eq(entities, 12, "town 应实体化 12 个 NPC")
	assert_eq(with_hint, 12, "每个 NPC 应各持一枚头顶提示（InteractHint）")
	assert_eq(leaked, 0, "所有提示须挂在地图子树内（随图生灭，不泄漏到根/current_scene）")
	# 反例守卫：不得有交互提示挂到任何根直子节点
	var root_direct := 0
	for c: Node in get_tree().root.get_children():
		if c.get_node_or_null("InteractHint") != null:
			root_direct += 1
	assert_eq(root_direct, 0, "不得有交互提示挂在场景根直子节点上")


func test_d2_提示随宿主释放而销毁不叠影() -> void:
	# 独立容器作宿主：释放后提示应随宿主一并消亡（跨图重进不叠影的结构保证）
	var host := Node2D.new()
	add_child(host)
	var npc: StaticBody2D = NpcScene.instantiate()
	host.add_child(npc)
	var hint: Label = _hint_of(npc)
	assert_not_null(hint, "前置：提示已建立")
	if hint == null:
		host.free()
		return
	assert_true(host.is_ancestor_of(hint), "提示在宿主子树内（随宿主生灭）")
	host.free()
	assert_false(is_instance_valid(hint), "宿主释放 → 提示随之销毁（无残留、不叠影）")


# ------------------------------------------------------------------
# Group E —— 跨图泄漏回归（rev2 缺陷②：提示不得挂 current_scene）
# ------------------------------------------------------------------

func test_e1_town提示随地图不挂current_scene() -> void:
	# 复刻生产语境：装配时 current_scene 非空（旧代码会把提示挂它 → 跨图残留）
	GameData.story_phase = 0
	var fake: Node = _make_fake_scene()   # 已挂 root
	autofree(fake)
	var orig_cs: Node = get_tree().current_scene
	get_tree().current_scene = fake
	var map: Node = (load(TownScenePath) as PackedScene).instantiate()
	add_child_autofree(map)                 # _ready 期间 current_scene=fake
	get_tree().current_scene = orig_cs
	assert_not_null(map.billboard_hint, "town 应装配告示板提示")
	assert_eq(map.billboard_hint.get_parent(), map,
			"告示板提示须挂地图根（rev2 修：旧代码挂 current_scene → 跨图残留/叠影）")
	assert_null(fake.get_node_or_null("BillboardHint"),
			"current_scene 下不得残留告示板提示")
	assert_null(fake.get_node_or_null("InteractHint"),
			"current_scene 下不得残留 NPC 提示")


func test_e2_f3提示为地图根直接子节点不挂current_scene() -> void:
	var fake: Node = _make_fake_scene()   # 已挂 root
	autofree(fake)
	var orig_cs: Node = get_tree().current_scene
	get_tree().current_scene = fake
	var map: Node = (load(F3ScenePath) as PackedScene).instantiate()
	add_child_autofree(map)
	get_tree().current_scene = orig_cs
	var hint: Node = map.get_node_or_null("InteractHint")
	assert_not_null(hint, "f3 应装配 Boss 锚点提示（InteractHint）")
	if hint != null:
		assert_eq(hint.get_parent(), map,
				"InteractHint 须为地图根直接子节点（dev 冒烟按直接子节点查）")
		assert_eq(hint.z_index, WorldHint.HINT_Z_INDEX, "z_index=12>Above(10)")
	assert_null(fake.get_node_or_null("InteractHint"),
			"current_scene 下不得残留 f3 提示")


func test_e3_释放地图后提示随之消亡不残留() -> void:
	# 模拟切图：装配（current_scene 非空）→ 释放旧图 → 提示应全消失、零残留
	GameData.story_phase = 0
	var fake: Node = _make_fake_scene()   # 已挂 root
	autofree(fake)
	var orig_cs: Node = get_tree().current_scene
	get_tree().current_scene = fake
	var map: Node = (load(TownScenePath) as PackedScene).instantiate()
	add_child(map)
	get_tree().current_scene = orig_cs
	var bb: Node = map.billboard_hint
	var npc_h: Node = map.get_node_or_null("YSorted/npc_01_innkeeper_entity/InteractHint")
	assert_not_null(bb, "前置：告示板提示已装配")
	map.free()   # 切图：释放旧图
	assert_false(is_instance_valid(bb), "释放地图后告示板提示随之销毁（不残留）")
	if npc_h != null:
		assert_false(is_instance_valid(npc_h), "释放地图后 NPC 提示随之销毁")
	assert_null(fake.get_node_or_null("BillboardHint"),
			"current_scene 下无告示板提示残留（旧代码会残留于此）")
	assert_eq(fake.get_child_count(), 0, "current_scene 下零提示残留")


# ------------------------------------------------------------------
# Group F —— 朝向保持 + 去抖（rev3）
#   用户实机残留缺陷："正后方/其他角度都会亮一下 ❗ 然后不亮。正前方常亮 ❗"。
#   根因二：player._update_facing 松键后把 facing 复位为 DOWN → 朝向判定漂移。
#   F1/F2 用【非冻结真实玩家 + set_input_override】把真实松键动力学纳入被测路径
#   （rev2 用例冻结了玩家物理 → 该缺陷从未进入测试，即"验证盲区"）；F3 考控制器
#   去抖，故冻结玩家以精确控帧（与 B 组同款隔离纪律）。
# ------------------------------------------------------------------

## 回归红线：松键后朝向应保持，不得复位为 DOWN 而折返误亮正南的 NPC。
## 布置：玩家在 NPC 正北 16px——面朝 UP 时射线背离（不亮）；若复位为 DOWN 则
##   射线折返命中正南 NPC → 误亮（旧实现症状）。此用例在修复前必须 RED、修复后 GREEN。
func test_f1_松键后保持朝向不误亮提示_回归红线() -> void:
	_make_led_world(true, false)   # 非冻结玩家：真实 _update_facing 动力学
	var hint: Label = _hint_of(_npc)
	assert_not_null(hint, "前置：NPC 提示已建立")
	if hint == null:
		return
	# 玩家在 NPC 正北 16px：面朝 UP 背离；面朝 DOWN 才会命中（射线 y 覆盖 NPC 交互体）
	_player.position = Vector2(200, 200 - 16)
	_player.set_input_override(Vector2.UP)     # 朝北（背离 NPC）
	await _tick_physics(2)                      # 真实 _update_facing 生效 → facing=UP
	_player.set_input_override(Vector2.ZERO)    # 松键（进入旧实现的缓冲→复位窗口）
	# 等远超旧缓冲 0.15s：≥12 物理帧（≈0.2s）确保越过复位时点
	await _tick_physics(12)
	assert_eq(_player.facing, Vector2.UP,
			"松键后朝向应保持 UP（不得复位 DOWN，否则引向正南误判）")
	assert_false(hint.visible,
			"面朝背离（UP，NPC 在正南）→ 提示不得因朝向复位而误亮")
	assert_null(_player.get_interact_target(),
			"同源锚：此刻按 Z 亦无目标（提示亮灭与分派判据一致）")


## 正向对照：面朝 NPC（正南）命中 → 常亮；松键后朝向保持 DOWN → 提示不误灭。
## 确认"朝向保持"修复不误伤合法高亮（对称性检查）。
func test_f2_面朝NPC时提示常亮且松键后保持() -> void:
	_make_led_world(true, false)
	var hint: Label = _hint_of(_npc)
	assert_not_null(hint, "前置：NPC 提示已建立")
	if hint == null:
		return
	_player.position = Vector2(200, 200 - 16)
	_player.set_input_override(Vector2.DOWN)   # 朝南（面向 NPC）
	await _tick_physics(6)                      # 命中稳定 ≥ 去抖阈值 → 亮
	assert_true(hint.visible, "面朝 NPC + 射线命中 → 亮")
	_player.set_input_override(Vector2.ZERO)    # 松键
	await _tick_physics(12)                     # 远超旧缓冲复位时点
	assert_eq(_player.facing, Vector2.DOWN, "松键后朝向保持 DOWN")
	assert_true(hint.visible, "合法高亮不因松键而误灭（正向对照）")
	assert_not_null(_player.get_interact_target(), "同源锚：仍可交互")


## 去抖：命中仅一两帧的瞬时噪声不足以点亮（需连续 3 物理帧稳定命中）。
## 【此用例冻结玩家以精确控帧】本用例考的是**控制器去抖**（非 _update_facing 动力学），
##   故冻结玩家、直接翻面把"命中窗口"钉到精确的 1-2 帧——与 B 组同款隔离纪律；
##   真实非冻结朝向动力学由 F1/F2 覆盖。
## 仿"转身/走动经过 NPC 瞄准线的单帧闪烁"——旧实现即刻闪光，去抖后应全程不亮。
func test_f3_瞬时命中不足去抖不亮() -> void:
	_make_led_world(true, true)   # 冻结玩家：命中窗口按帧精确可控
	var hint: Label = _hint_of(_npc)
	assert_not_null(hint, "前置：NPC 提示已建立")
	if hint == null:
		return
	_player.position = Vector2(200 - 16, 200)   # NPC 正西 16px
	var ever_lit: bool = hint.visible
	_player.facing = Vector2.RIGHT               # 朝东（面向 NPC）——命中窗口仅 2 帧
	await _tick_physics(2)
	ever_lit = ever_lit or hint.visible
	_player.facing = Vector2.LEFT                # 立即背离
	await _tick_physics(8)
	ever_lit = ever_lit or hint.visible
	assert_false(ever_lit, "瞬时命中（≤2 帧）不足去抖阈值（3 帧）→ 提示全程不亮")
	assert_false(hint.visible, "终态：背离 → 不亮")
