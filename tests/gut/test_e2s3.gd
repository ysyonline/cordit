extends GutTest
## E2-S3 占位战斗场景 + Router 载荷校验（TASK-S2-08）
##
## 断言覆盖（EPIC-2.md E2-S3 两条验收标准的自动化部分）：
##   A. Router 校验闸门：合法 payload 受理；缺字段/类型冒充（Vector2i 冒充
##      Vector2）拒绝——validate_payload 返回值与拒绝语义（SMK-09 同源）；
##   B. 接线闭环：enemy_touched → Router → 战斗场景入 World（手造假
##      Main/World 骨架驱动真实 change_scene 通路，无 FadeMask 时按设计
##      退化为直接换装——SMK-10 语义：拒绝不破坏当前场景）；
##   C. 战斗场景：可实例化；消费 staged payload 摆方块阵（同 id 恒同阵、
##      空载荷防御态 9 灰格）；直读 GameData.party 显示 3 角色；
##      胜利/失败按钮发 A5 BattleResult（outcome + party_state 快照）；
##   D. A3 边界守门：按钮触发后 GameData 零变化（本 Story 只发不写，
##      覆写属 E2-S4）。
##
## 【测试策略】延续 E2-S1/S2 纪律：不实例化真 main.tscn；接线用例的假
##   Main 骨架在 after_each 强制拆除（防污染 SMK-01 的"root 恰 4 节点"
##   断言）；staged payload 用 SceneRouter 内部簿记直接预置（测试注入口）。
##
## 跑法（项目根下）：
##   MSYS2_ARG_CONV_EXCL="*" Godot_console.exe --headless --path . \
##     -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle.tscn"
const BATTLE_SCRIPT_PATH: String = "res://scripts/battle/battle_scene.gd"

## 合法 BattlePayload 样板（A5 四字段，与 E2-S2 发射侧同构）。
## 【O-6 改造】编组 id 从占位时代的表外 id slime_01 换为表内真实编组
##   b1_moth——战斗场景已真实装配，接线用例实例化的将是真实战斗。
const VALID_PAYLOAD: Dictionary = {
	"enemy_group_id": "b1_moth",
	"return_map": "res://tests/smoke/fixtures/map_e2s2.tscn",
	"return_position": Vector2(64, 32),
	"defeat_enemy_uid": "enemy_road_01",
}
## 接线用例的假 Main 骨架（after_each 拆除）
var _fake_main: Node = null

## battle_finished 捕获槽
var _recv_result: Variant = null


func before_each() -> void:
	_recv_result = null
	# Router 簿记重置：autoload 状态跨用例持久，上一条用例的暂存载荷/
	# 切换路径会泄漏到下一条（空载荷防御态、非法拒绝断言都依赖干净簿记）
	SceneRouter._staged_payload = {}
	SceneRouter.current_scene_path = ""
	SceneRouter._switching = false


func after_each() -> void:
	# 假 Main 骨架强制拆除（含 Router 装入其中的战斗场景），
	# 保 SMK-01"root 下非测试基建节点恰 4 个"断言零污染
	if _fake_main != null and is_instance_valid(_fake_main):
		_fake_main.free()
	_fake_main = null


## 捕获 battle_finished
func _on_battle_finished(r: Dictionary) -> void:
	_recv_result = r


## 预置 Router 暂存载荷（测试注入口：正式路径由 change_scene 受理时写入）
func _stage_payload(p: Dictionary) -> void:
	SceneRouter._staged_payload = p.duplicate(true)


## 造假 Main/World 骨架（复刻 A4 结构的最小子集：无 UILayer——Router 在
## 无遮罩时按设计退化为直接换装，正好让 _do_switch 同步完成可断言）
func _make_fake_main() -> Node2D:
	var main := Node2D.new()
	main.name = "Main"
	var world := Node2D.new()
	world.name = "World"
	main.add_child(world)
	get_tree().root.add_child(main)
	_fake_main = main
	return main


## 实例化战斗场景（可选预置载荷；autofree 托管）
func _spawn_battle(p: Dictionary = {}) -> Node2D:
	if not p.is_empty():
		_stage_payload(p)
	var packed: PackedScene = load(BATTLE_SCENE_PATH) as PackedScene
	var battle: Node2D = packed.instantiate()
	autofree(battle)
	add_child_autofree(battle)
	return battle


# =============== A. Router 校验闸门 ===============

func test_Router_合法载荷受理() -> void:
	assert_true(SceneRouter.validate_payload(VALID_PAYLOAD),
			"四字段齐全且类型正确的载荷应受理")


func test_Router_缺字段拒绝并逐条报因() -> void:
	# 逐个抽掉四字段之一：全部拒绝（缺字段明细在输出，SMK-09 验收点同源）
	for field: String in VALID_PAYLOAD:
		var broken: Dictionary = VALID_PAYLOAD.duplicate(true)
		broken.erase(field)
		var ok: bool = SceneRouter.validate_payload(broken)
		assert_false(ok, "缺 %s 的载荷应被拒绝" % field)


func test_Router_Vector2i冒充Vector2被拒() -> void:
	# 类型精确匹配守门：Vector2i 是 int 对，不能冒充 Vector2（A5 校验规则）
	var fake: Dictionary = VALID_PAYLOAD.duplicate(true)
	fake["return_position"] = Vector2i(64, 32)
	assert_false(SceneRouter.validate_payload(fake),
			"Vector2i 冒充 return_position 应被拒（类型精确匹配）")


func test_Router_多余字段放行不拒绝() -> void:
	# 协议外字段只警告不拒绝（A5 未来加字段时旧调用方不被一票否决）
	var extended: Dictionary = VALID_PAYLOAD.duplicate(true)
	extended["extra_note"] = "未来字段"
	assert_true(SceneRouter.validate_payload(extended), "协议外字段应放行")


# =============== B. 接线闭环（enemy_touched → Router → 战斗入 World） ===============

func test_接线_合法载荷经信号装入战斗场景() -> void:
	var main := _make_fake_main()
	var world: Node = main.get_node("World")
	assert_eq(world.get_child_count(), 0, "前置：World 为空")
	# 模拟地图侧遇敌：E2-S2 的发射形态原样重放
	EventBus.enemy_touched.emit(VALID_PAYLOAD)
	# 无 FadeMask 时 _do_switch 同步完成：World 应已装入战斗场景
	assert_eq(SceneRouter.current_scene_path, SceneRouter.BATTLE_SCENE_PATH,
			"接线后 Router 簿记应指向战斗场景")
	assert_eq(world.get_child_count(), 1, "World 应装入恰好一个场景")
	var battle: Node = world.get_child(0)
	var s: Script = battle.get_script()
	assert_true(s != null and s.resource_path == BATTLE_SCRIPT_PATH,
			"装入 World 的应是战斗场景（按脚本路径判）")
	# 战斗场景应已消费暂存载荷（A5 闭环中段贯通）
	assert_eq(battle.get("last_payload"), VALID_PAYLOAD,
			"战斗场景消费的载荷应与发射的载荷一致")


func test_接线_非法载荷被拒_世界不动() -> void:
	var main := _make_fake_main()
	var world: Node = main.get_node("World")
	# Vector2i 冒充：闸门应拒绝切换（SMK-10 语义：拒绝不破坏当前场景）
	var bad: Dictionary = VALID_PAYLOAD.duplicate(true)
	bad["return_position"] = Vector2i(1, 1)
	EventBus.enemy_touched.emit(bad)
	assert_ne(SceneRouter.current_scene_path, SceneRouter.BATTLE_SCENE_PATH,
			"非法载荷不得切换")
	assert_eq(world.get_child_count(), 0, "拒绝时 World 不得被换装")
# =====================================================================
# 【C/D 区退役声明】（O-6 改造，2026-09-12）
# 下列 6 条占位用例随 battle_scene.gd 重写为真实战斗而退役：
#   test_战斗场景可实例化_空载荷防御态 / test_方块阵_同编组恒同阵_数量在界内
#   test_战斗场景直读GameData队伍初始态 / test_胜利按钮发BattleResult_VICTORY
#   test_失败按钮发BattleResult_DEFEAT / test_按钮触发后GameData零变化
# 场景节点（EnemyBlocks/PartyState/BtnVictory/BtnDefeat）不复存在，
# 属 sprint3-qa-plan §5.4"预期红"到期兑现条款。
# 接棒验证 → tests/gut/test_o6_real_battle.gd（真实战斗全链路 6 用例）。
# =====================================================================
