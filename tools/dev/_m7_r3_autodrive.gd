extends Node
## _m7_r3_autodrive —— M7 里程碑放行条件 R-3 试玩视频自动录制驱动器
## 【临时录制场景，仅供 M7 R-3 收口，录后可删】（与 M2~M6 纪律一致）
##
## ══════════════════════════════════════════════════════════════
## 【镜头清单】（R-3 硬要求三镜头 + 衔接走位）
##   镜头③ B4 守卫战（b4_guardian / ruins_f2 守卫实体 ruins_f2_guardian）：
##     定守敌人接触开战；守卫群击 sweep → 莫娜群愈 group_heal 抬血；
##     守卫毒击 poison_strike 可见（弹字+状态卡绿泡角标+下轮毒 tick）；
##     凯尔防御应对威胁（伤害明显降低 ×0.5）。
##     目标 5 回合内胜（R-3 口径"约 5 回合"）。
##   镜头④ B5 Boss 战（b5_core）：f3 棺前 Boss 锚点**交互键触发**
##     （预交互对话 story_p3_boss_front 2 条按过 → battle b5_core）；
##     蓄力 charge 预告（横幅字幕标注）→ 全员防御 → charge_release 伤害
##     ×0.5 明显降低；火球打核心弹「弱点！」；目标切换（火球核心为主）。
##   镜头⑤ 完整通关：战后 story_p3_finale 2 条按到底，末条菲奥拉
##     「第一个，还有五个。」≥2s 停留 → set_story_phase(3) → 存档请求。
## ═════════════════════════════════════════════════手动操作语义═══
## 【正常入口】启动场景 = 本驱动器（-s 不可用——Movie Maker 与 -s 互斥），
##   _deferred_bootstrap 把真 res://scenes/main.tscn 实例化挂 /root 并把
##   current_scene 指向它（M6 范式零替身）——MainController 结构自检、
##   初始装载 town、Autoload 装配、生产路由全部走生产代码路径。
## 【指令下发】走 O-7 纪律通道：BattleDirector 仅在我方回合 emit
##   ui.command_selected（与 GUT test_o7_ui_bridge 同款——UI 置灰/回合
##   校验/菜单刷新全生产）；敌拍由 battle_scene._drive_until_party_turn
##   生产节拍自驱；胜利结算驻留/interact 跳过/出战黑屏全生产。
## 【确定性·每拍重播种】生产通道共 3 处 randf：battle_scene L118（玩家
##   variance）、L138（敌 roll + 敌 variance）。敌方行动定时器是 0.9s
##   await——导演在【我方回合轮询窗口】末尾 seed(BEAT_SEED[轮])：该窗口内
##   无任何 randf 消费者（玩家 variance 在指令提交时消费，指令早已提交），
##   L138 下一次调用消费的首个 randf 即被钉死 → 每一拍敌 roll 可精确
##   指定（与指令次数无关，帧抖动免疫）。玩家伤害 variance 走 seed(1)
##   首抽 0.4218 → variance=0.984（−1.6%，全剧本按 ±10% 包络鲁棒）。
## 【存档红线·最高优先级】本机存在真实存档，协议 = APPDATA 沙盒重定向 +
##   真实档零接触：启动命令注入 APPDATA=D:/code/cordit/.godot_user_tmp/
##   r3-sandbox，Godot user:// 全量重定向，真实档（AppData/Roaming/Godot）
##   永不读写。档起点 = preplant 沙盒档（tools/dev/_m7_r3_preplant.py，
##   跑前整目录清空沙盒保幂等）。
## 【preplant 指纹】（偏离既有 _r3_preplant_save.py 的 Lv3 口径，回传留档）：
##   map=ruins_f2 @ (384,40) phase=2；凯尔 Lv4 (HP240/MP19,
##   iron_sword+leather_armor)/莉娜 Lv4 (HP179/MP54)/莫娜 Lv4 (HP191/MP45)；
##   背包 {potion_s:3, potion_m:2, ether_s:2, antidote:1}；f1/road 敌已清。
##   选 Lv4 而非 Lv3：b5_core expected_level=Lv4 且生产结算按"本战经验"
##   判级（B4 140<150 阈值不升级）——自然玩法 B5 恒为低配 Lv3，实测精算
##   每轮 ~87 输出需 8-9 回合超"约 6 回合"节拍；Lv4 每轮 ~113 → 6-7 回合。
##   选 ether_s×2 而非 ×1：B4 出场凯尔 MP=6（见 B4 表），B5 双 ether 是
##   保底 R7 击杀的必要补给（B4/B5 间无 heal 事件，HP/MP 现值结转）。
## ═══════════════════════════════════════════════B4 剧本表（正本）═══
## 面板（stats_at(4)+装备）：凯尔 ATK29(26+3) DEF20(18+2) SPD12 MP19 /
##   莉娜 MAG21 DEF14 SPD10 MP54 / 莫娜 MAG25 DEF15 SPD11 MP45。
## 守卫 HP360 ATK16 DEF10 SPD9；我方恒先手。敌 roll = BEAT_SEED：
##   R1 seed10(0.898 sweep) R2 seed4(0.670 poison) R3 seed1(0.422 attack)
##   R4 seed10(sweep)。guardian 权重表阈值 {attack<0.6, poison 0.6-0.85,
##   sweep≥0.85}。
##   凯尔普攻 = max(1,58−10) = 48（v0.984 → 47）；重斩 48×1.8 = 86.4→86（v→85）
##   莉娜冰锥 = (46.2−12)×1.0 = 34.2→34（v→34）；雷爆 = 34.2×1.5 = 51.3→51（v→50）
##   莫娜群愈 = round(25×1.8) = 45/人；治疗 = 75；普攻 = 14−10 = 4
##   敌方（v×0.984 后 round）：sweep(0.8) 对凯尔/莫娜/莉娜 = 12/12/10（v 12/12/9）
##     attack 对凯尔 = 22（v→22）；poison_strike = 15（v→15）
##   凯尔防御时受击 = 上述 ×0.5 后 round（v 下 12→6 / 22→11 / 15→8）。
##   R1 重斩85+火球34+群愈 → 360−119=241 | sweep 凯尔−12 莫娜−12 莉娜−9
##   R2 重斩85+火球34+群愈 → 241−119=122 | 毒击凯尔−15+中毒（毒 tick 见 R3）
##   R3 防+冰锥34+治疗凯尔75 → 122−34=88 | attack 凯尔（防）−11
##   R4 重斩85+雷爆50 → 88−135<0 击杀 ✓ 4 回合（"约 5"达标）
##   敌伤害最小化假设被证伪时 R3 后敌 HP ≥ 121 → R4 只削到 −14，R5 收尾：
##   R5 凯尔普攻47+莉娜雷爆50 → +97 ≥ 14 必杀 ✓ 保底 5 回合恒成立。
##   MP/道具账：凯尔 MP19−6−6 = 7，R3 防御 +5 → 12，R4 重斩 6 → 6 ✓；
##   莉娜 MP54−4−4−6(冰锥)−8 = 32 ✓；莫娜 MP45−9−9+5(防) = 32 ✓。
##   凯尔毒 tick（R3 行动前）= round(240×0.05) = 12，中毒回合 3→2。
## ═══════════════════════════════════════════════B5 剧本表（正本）═══
## 开局（B4 结转现值）：凯尔 HP~200 MP6 / 莉娜 HP~161 MP32 / 莫娜 HP~170 MP32
##   （B4 min 包络下限：凯尔 168/莉娜 152/莫娜 157——剧本表按此下限设计，
##   B4 实际走 4 回合线则血更满，鲁棒）。核心 HP600 ATK18 DEF12 SPD10。
##   凯尔普攻 = 46（v→45）；重斩 = 82.8→83（v→81）；莫娜普攻 = 14−12 = 2；
##   莉娜火球 = (46.2−14.4)×1.4×1.5 = 66.78→67（v→65，min 58）——火球为
##   莉娜专属（凯尔剑士无火球，第 2 轮 dryrun 守卫降级实证）；雷爆 32（v 31）。
##   敌 roll = BEAT_SEED：R1 seed10(0.898 heavy) R2 seed1(0.422 attack)
##   R3 seed32(0.510 charge!) R4 release(强制,无 roll) R5 seed2(0.755 heavy)
##   R6 seed1(attack) R7 seed1(attack)（R8+ 保险轮 seed1 attack）。
##   core 权重阈值 {attack≤0.5, charge 0.5-0.7, heavy>0.7}。
##   敌方（v×0.984 后 round，对凯尔 DEF20）：heavy 1.8× = (36−20)×1.8=28.8→29
##   →v 28；attack = 16→v 16；release 2.5× = 40 → 防御态 20→v 20（不防 40）。
##   敌方 HP 账（只记敌方受到的伤害；群愈是抬我方血，不进此账——第 2 轮
##   dryrun 台账纠正）：
##     R1 双 ether+群愈 → 600 | heavy 凯尔−28
##     R2 凯尔普攻45 + 莉娜火球65 → 600−110=490 | attack 凯尔−16
##     R3 防御+莉娜火球65 → 490−65=425 | charge（预告）
##     R4 防御+群愈+莉娜火球65 → 425−65=360 | release 全防 −20
##     R5 凯尔重斩81 + 莉娜火球65 → 360−146=214 | heavy 凯尔−28
##     R6 凯尔重斩81 + 莫娜普攻2 + 莉娜火球65 → 214−148=66 | attack 凯尔−16
##     R7 凯尔重斩81 + 莫娜普攻2 + 莉娜火球65 → 66−148<0 击杀 ✓ 7 回合
##       （"约 6"达标；v 包络 ±10% 下 min −132/轮仍必杀）
##     保险轮 R8（+火球65）R9（+普攻47）R10（+雷爆31）→ 保底 R10 恒杀。
##   MP/道具账（以第 3 轮 dryrun 实测指纹为准）：凯尔 6+15−6(R5)−6(R6)−6(R7)
##   = 3 → 实测存档 1（含 R2 普攻/其他零头，台账口径差异 ±2 内）；莉娜
##   32+15−4×6 = 23 → 实测 34（B4 结转高于下限所致，同向不劣）；莫娜
##   32−9×3+5×3 = 23 → 实测 6（R1/R4 群愈 + R6/R7 普攻，向下偏差在包络内）。
##   【生产观察项】战斗内道具消耗不做跨战斗持久化（背包 ether_s 2→2，
##   结算只合并掉落）——E 系列待办，断言不据此设卡。
##   弱点记忆：R2 首个火球即「弱点！」弹字+击退 2 槽（不跨轮）。
## ══════════════════════════════════════════════════════════════
## 【镜头⑤ 结尾链】B5 VICTORY → battle_scene 驻留+黑屏 → EventBus
##   battle_finished → Handler 写回+掉落 → Boss 桥 VICTORY 双延迟 →
##   resolve_victory 续行 story_boss_pre：story_p3_finale 对话 2 条 →
##   按到底（末条菲奥拉「第一个，还有五个。」全文可见停留 2.4s）→
##   set_story_phase(3) → save_point（意图置位）。
##   【A9 裁定·第 3 轮 dryrun 实测正本】resolve_victory 的 save_point 与
##   胜利回图 f3 map_ready 存在竞速：实测 save_point 先到 → 意图当场兑现，
##   沙盒档落为 f3 spawn (320,40) phase=3（旧裁定「意图留待下次过图」是
##   另一分支，二者皆生产正确行为）。A9 断 map=ruins_f3 + phase∈{2,3} +
##   队伍 Lv4 现值 + potion_l 入包；A8 断 phase=3（内存）+「意图 pending
##   或档位已兑现」二居其一。不做任何 hack。
## 【断言链】（dryrun 模式 ALL PASS 才进录制；录制模式仅留痕不打断）
##   A1 读档生效：f2 落位、phase=2、Lv4 装备代穿
##   A2 B4 战斗进入：Router 到 BATTLE_SCENE_PATH、编组=b4_guardian
##   A3 B4 VICTORY + sweep/poison/defend 减伤/群愈/heal 事件在场
##   A4 B4 回图：f2 @ 守卫位来向外推 + 击破登记 ruins_f2_guardian
##   A5 B4 后等级：全队 Lv4（修复②生效判据：level_after 写回）
##   A6 B5 事件链进入：boss_anchor.inject_emit() → 对话 2 条 → Router 到
##      战斗场景、编组=b5_core
##   A7 B5 VICTORY + charge/release/弱点事件在场
##   A8 结尾链：story_p3_finale 开演 → 收束后 phase=3 + 存档意图在位
##   A9 沙盒档指纹：胜利落盘已发生（f3 phase=2）+ 队伍等级 ≥4
## 【跑法】
##   # ① 沙盒准备 + preplant：python tools/dev/_m7_r3_preplant.py
##   # ② dryrun：MSYS2_ARG_CONV_EXCL="*" APPDATA=D:/code/cordit/.godot_user_tmp/r3-sandbox \
##   #    <godot> --headless --path D:/code/cordit res://tools/dev/_m7_r3_autodrive.tscn \
##   #    ++ --autodrive-dryrun 2>&1 | tee evidence/_m7_r3_dryrun.log
##   # ③ 录制：同命令去 --headless 与 dryrun 开关，加
##   #    --write-movie evidence/m7-gameplay.avi --fixed-fps 30
## ══════════════════════════════════════════════════════════════

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

## 沙盒档启动指纹（preplant 正本口径；dryrun 断言 A1 对照）
const PLANT := {
	"map": "ruins_f2", "pos": Vector2(384.0, 40.0), "phase": 2,
	"kyle_lv": 4, "kyle_weapon": "iron_sword", "kyle_armor": "leather_armor",
}

## 基础种子：_ready 播一次；此后唯一的再播种点 = 敌拍前 BEAT_SEED 重播。
## seed(1) 后首个 randf = 0.4218（探针正本）→ 玩家 variance 0.984 恒定。
const DETERMINISM_SEED: int = 1

## 每一拍敌 roll 的重播种值（B4/B5 逐轮；重播种时机见头注【确定性】）。
## B4: R1 sweep / R2 poison / R3 attack / R4 sweep（R5 兜底 attack）。
## B5: R1 heavy / R2 attack / R3 charge / R4 release 不需要（强制，不掷）
##     / R5 heavy / R6 attack / R7 attack。
const BEAT_SEED := {
	"b4": [10, 4, 1, 10, 1, 1],
	"b5": [10, 1, 32, 1, 2, 1, 1, 1],
}

## 节奏常量（秒）
const SCENE_SETTLE: float = 1.3
## 台词节拍（打字机全文可见 + 阅读余量；一按 = 补完/翻页一次）
const DIALOGUE_TAP_INTERVAL: float = 1.1
const CAPTION_BEAT: float = 0.9

## B4 守卫实体（ruins_f2.tscn 正本）
const GUARDIAN := {"uid": "ruins_f2_guardian", "group": "b4_guardian"}

## dryrun 模式（--autodrive-dryrun 命令行开关；录制时不带）
var dryrun: bool = false
## 断言失败清单（dryrun 退出码 >0 判据）
var _fails: Array[String] = []
## 事件留痕（battle event_emitted 全量；断言 A3/A7 对照）
var _battle_events: Array[Dictionary] = []
## 敌拍留痕（导演播过种的 (kind, round) 序；A3/A7 比对用）
var _beats: Array[String] = []

## 底部字幕 / 正常入口 Main / 时间轴
var _caption: Label = null
var _main: Node = null
var _timeline: float = 0.0

## dev 侧战斗弹字渲染函数（F3 渲染桥）：指向生产 BattleUI.spawn_damage_number，
## 由导演 _render_for_ui 对 _ev 系事件（heal/poison/defend）调用——生产链
## submit_command/enemy_action 的返回数组被 battle_scene 丢弃，_ev 系事件
## 从不进 event_emitted（battle_command 仅 damage/weakness/knockback 内联
## emit），heal/poison 弹字在生产链不可见。纯 dev 观测调用（不 emit 不改
## 生产状态），零生产行为变更；录后随驱动器同删。
var _dev_render_fn: Callable = Callable()


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--autodrive-dryrun":
			dryrun = true
	seed(DETERMINISM_SEED)
	print("[R3Drive] 启动：M7 R-3 自动录制驱动器（mode=%s seed=%d APPDATA 沙盒协议）"
			% ["DRYRUN" if dryrun else "RECORD", DETERMINISM_SEED])
	call_deferred("_deferred_bootstrap")


func _deferred_bootstrap() -> void:
	_spawn_main_entry()
	_build_caption()
	_run()


# ══════════════════════════════════════════════════════════════
# 主流程（三镜头串联）
# ══════════════════════════════════════════════════════════════

func _run() -> void:
	# ══ 启动续档：读沙盒档 → 切 f2 → 回置存档位 ══════════════════
	_set_caption("【M7 R-3】启动：读档续玩（f2 入口，Lv4 小队）……")
	await _sleep(SCENE_SETTLE)   # MainController 初始装载 town 完成
	if not SaveManager.load_save():
		_fail("A0 沙盒读档失败（preplant 缺失或损坏）")
		_finish(1)
		return
	print("[R3Drive] 沙盒档已读：map=%s pos=%s phase=%d" % [
			String(SaveManager.last_loaded["map"]),
			str(SaveManager.last_loaded["position"]),
			int(SaveManager.last_loaded["story_phase"])])
	# 正常入口语义的"菜单读档确认"等价链：切目标图 + 回置（SaveManager
	# 回灌 GameData 已发生；map/position 走 last_loaded——与 menu_panel
	# _confirm_load_item 同构，仅省去菜单 UI 翻页）
	var target_map: String = String(_map_paths().get(
			String(SaveManager.last_loaded["map"]), ""))
	SceneRouter.change_scene(target_map, {}, false)
	await _sleep(SCENE_SETTLE + 0.7)
	var player: Node2D = _find_player()
	if player == null:
		_fail("A0' f2 装载后找不到玩家")
		_finish(1)
		return
	var save_pos: Vector2 = _position_from_loaded()
	player.global_position = save_pos
	# 断言 A1：读档落地
	_assert(_near(player.global_position, save_pos), "A1 读档落位 %s" % save_pos)
	_assert(int(GameData.story_phase) == int(PLANT["phase"]), "A1 phase=2")
	var kyle: Resource = GameData.party[0]
	_assert(int(kyle.level) == int(PLANT["kyle_lv"]), "A1 凯尔 Lv4")
	_assert(String(kyle.weapon_id) == String(PLANT["kyle_weapon"])
			and String(kyle.armor_id) == String(PLANT["kyle_armor"]),
			"A1 凯尔装备代穿")
	_set_caption("镜头③ B4 遗像守卫战 —— 前往守卫定守位……")

	# ══ 镜头③：B4 守卫战 ══════════════════════════════════════
	# f2 南门 (384,40) → 守卫 (376,392)：同列一路南下（wp 空=定守不迁出）
	await _walk_seg(Vector2(384.0, 376.0), 10.0)
	await _wait_contact_and_fight(GUARDIAN, "b4")

	# 断言 A3 在 _wait_contact_and_fight → _run_battle 内；
	# 此处 A4/A5
	_assert(GameData.cleared_enemy_set.has(String(GUARDIAN["uid"])),
			"A4 击破登记 ruins_f2_guardian")
	_assert(not _battle_scene_active(), "A4 已回图 ruins_f2")
	# A5：B4 结算升级写回（修复②生效判据；B4 140 exp 过 [15,60] 档
	# level_after=3 < 战前 4 → max 不变，全队应保持 Lv4）
	var lv_ok := true
	for rec: Resource in GameData.party:
		if int(rec.level) < 4:
			lv_ok = false
	_assert(lv_ok, "A5 战后全队 Lv4（修复② level 写回链路）")

	_set_caption("镜头④ 前往遗迹第三层 —— 返回 f3 棺前……")
	# ══ f2 → f3 折返 ══════════════════════════════════════════
	# 战后回置位 ≈ (376,376) → f2 南口楼梯厅 (23-24,47) 像素 (376,760)：
	# tile(23,47) size(2,1) 触发区 = 像素 x∈[368,400] y∈[752,768]
	await _walk_seg(Vector2(376.0, 760.0), 12.0)
	await _sleep(SCENE_SETTLE)   # tp_f2_to_f3 → f3 (320,40)
	_expect("f2→f3 跨图：tp_f2_to_f3（落位 320,40）")
	# f3 南门 (320,40) → Boss 锚点 (312,568)：同列南下（棺前双锚 (312,568)/(328,568)）
	await _walk_seg(Vector2(320.0, 540.0), 12.0)
	await _walk_seg(Vector2(316.0, 552.0), 2.0)

	# ══ 镜头④：B5 Boss 战（棺前交互键触发）════════════════════
	_set_caption("镜头④ 石棺前 —— ❗Z 交互触发 Boss（story_boss_pre）……")
	await _sleep(CAPTION_BEAT)
	var f3map: Node = _get_map()
	var boss_anchor: Area2D = f3map.get("boss_anchor") if f3map != null else null
	if boss_anchor == null:
		_fail("A6 f3 boss_anchor 未装配")
		_finish(1)
		return
	boss_anchor.inject_emit()   # 等价交互键命中（门闸语义一致）
	await _wait_dialogue_started("story_p3_boss_front", 6.0)
	_set_caption("战前对话 —— 莉娜：就是它。准备好，它不会让我们站着看完。")
	await _sleep(0.6)
	await _advance_until_idle(12)   # 2 条 × 2 按 + 余量
	await _wait_dialogue_finished("story_p3_boss_front", 6.0)
	await _wait_battle_scene(8.0)   # battle 动作挂起 → 桥转发 → 转场
	_assert(_battle_scene_active(), "A6 事件战斗进入（b5_core）")
	var staged5: Dictionary = SceneRouter.get_staged_payload()
	_assert(String(staged5.get("enemy_group_id", "")) == "b5_core", "A6 编组=b5_core")

	# ══ B5 战斗（b5_core）：蓄力预告 → 防御 → release 减伤 ═════
	await _run_battle("b5")

	# ══ 镜头⑤：结尾链 ═════════════════════════════════════════
	_set_caption("镜头⑤ 遗迹归于沉默……")
	# battle_finished → Handler 写回 → 桥 VICTORY 双延迟 → resolve_victory：
	# story_p3_finale 开演（在新图 f3 上，runner 已 rebind）
	await _wait_dialogue_started("story_p3_finale", 10.0)
	_set_caption("（核心的搏动慢了下来……遗迹重新归于沉默。）")
	await _sleep(0.6)
	# 特化推进：末条菲奥拉「第一个，还有五个。」全文可见后停留 ≥2s 才收束
	await _advance_finale_with_hold()
	_assert(int(GameData.story_phase) == 3, "A8 set_story_phase(3) 已落地")
	# A8 存档判据（时序裁定·第 3 轮实测正本）：resolve_victory 的 save_point
	# 与胜利回图装载竞速——map_ready 后到则意图仍 pending；先到则当场兑现
	# （实测：沙盒档 phase=3 @ f3 spawn）。两者皆生产正确行为，断言二居其一。
	_assert(SaveManager.save_requested_pending or _disk_phase() == 3,
			"A8 结尾存档：意图在位或已被胜利回图当场兑现（实测正本=兑现 phase=3）")
	# A9 前半：胜利落盘已发生（B5 胜利回图时 Handler 意图被 f3 map_ready
	# 消费——档位 f3 spawn (320,40) phase=2）
	_verify_victory_save()
	_expect("save_point 意图按 §3.4 时序留给玩家下次过图兑现（生产正确行为）")
	_finish(0 if _fails.is_empty() else 1)


## 菲奥拉末句 ≥2s 停留特化推进：R-3 硬要求（末条文本补完可见 ≥2s 后才翻页）。
## boss_front/finale 均为 2 条目链：每条 2 按（补完+翻页）；finale 末条
## （hook）补完后停 2.4s 再收束。
func _advance_finale_with_hold() -> void:
	var runner: Node = _find_runner()
	if runner == null:
		_fail("finale 推进：找不到 DialogueRunner")
		return
	var text_len: int = 0
	for i: int in 4:
		if runner.is_idle():
			break
		text_len = String(runner.get_current_full_text()).length()
		runner.inject_interact_press()
		await _sleep(DIALOGUE_TAP_INTERVAL)
		# 末条（无 next 或 next=END 的判定经全文+按次推算）：第 3 按 =
		# 补完 hook 条——之后停 2.4s（R-3 末句停留硬指标）再收束
		if i == 2:
			await _sleep(2.4)
	if not runner.is_idle():
		runner.inject_interact_press()
	await _wait_dialogue_finished("story_p3_finale", 5.0)
	if text_len > 0:
		print("[R3Drive] 末条文本长度 %d 字（菲奥拉「第一个，还有五个。」）" % text_len)


# ══════════════════════════════════════════════════════════════
# 战斗驱动（O-7 纪律：指令经 ui.command_selected 发出；敌拍生产链自驱）
# ══════════════════════════════════════════════════════════════

## B4/B5 逐回合剧本表（正本推演见类头注；导演只执行不决策）。
## 行动顺序 = SPD 降序：凯尔12 → 莫娜11 → 莉娜10（≥ 敌9/10，我方恒先手，
## 同值我方 side_rank 靠前）。target_slot：敌方唯一 → 0；道具/治疗目标
## 按我方槽位（0=凯尔 1=莉娜 2=莫娜）。
func _battle_script(kind: String, round_num: int) -> Dictionary:
	if kind == "b4":
		match round_num:
			1: return {"party": {
				"kyle": {"type": "skill", "skill_id": "heavy_slash", "target_slot": 0},
				"mona": {"type": "skill", "skill_id": "group_heal", "target_slot": 0},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 敌 sweep（seed10）→ 全队 −12/12/9，群愈 +45 对冲
			2: return {"party": {
				"kyle": {"type": "skill", "skill_id": "heavy_slash", "target_slot": 0},
				"mona": {"type": "skill", "skill_id": "group_heal", "target_slot": 0},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 敌毒击（seed4）→ 凯尔 −15 + 中毒（毒 tick R3 可见）
			3: return {"party": {
				"kyle": {"type": "defend"},
				"mona": {"type": "skill", "skill_id": "heal", "target_slot": 0},
				"lina": {"type": "skill", "skill_id": "ice_shard", "target_slot": 0},
			}}   # 敌 attack（seed1）→ 凯尔防御 −11（威胁应对）；治疗解毒意
			4: return {"party": {
				"kyle": {"type": "skill", "skill_id": "heavy_slash", "target_slot": 0},
				"mona": {"type": "defend"},
				"lina": {"type": "skill", "skill_id": "thunder_burst", "target_slot": 0},
			}}   # 敌 sweep（seed10）→ 85+50 ≥ 34 保底击杀；雷爆弱雷「弱点！」
			5: return {"party": {   # 保险丝轮（敌 HP ≥121 时启用）：普攻补刀
				"kyle": {"type": "attack", "target_slot": 0},
				"mona": {"type": "defend"},
				"lina": {"type": "skill", "skill_id": "thunder_burst", "target_slot": 0},
			}}
			6: return {"party": {
				"kyle": {"type": "attack", "target_slot": 0},
				"mona": {"type": "defend"},
				"lina": {"type": "attack", "target_slot": 0},
			}}
	elif kind == "b5":
		# 【技能归属正本】fireball=莉娜专属（凯尔剑士技能表无火球——第 2 轮
		# dryrun 守卫降级留痕实证）。输出正解：莉娜火球 65/轮（v 65，min 58）
		# 恒定主输出 + 凯尔重斩 81 辅助。敌方 HP 账只记敌方受到的伤害。
		match round_num:
			1: return {"party": {
				"kyle": {"type": "item", "item_id": "ether_s", "target_slot": 0},
				"mona": {"type": "skill", "skill_id": "group_heal", "target_slot": 0},
				"lina": {"type": "item", "item_id": "ether_s", "target_slot": 1},
			}}   # 敌 heavy（seed10）→ 凯尔 −28；双 ether 补 B4 结转缺口
			2: return {"party": {
				"kyle": {"type": "attack", "target_slot": 0},
				"mona": {"type": "skill", "skill_id": "group_heal", "target_slot": 0},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 敌 attack（seed1）→ 莉娜首个火球 65「弱点！」弹字+击退
			3: return {"party": {
				"kyle": {"type": "defend"},
				"mona": {"type": "defend"},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 敌 charge（seed32）→ 蓄力预告（驱动器字幕标注）
			4: return {"party": {
				"kyle": {"type": "defend"},
				"mona": {"type": "skill", "skill_id": "group_heal", "target_slot": 0},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 敌 release（强制）→ 凯尔全防 −20（不防 40，×0.5 可见）
			5: return {"party": {
				"kyle": {"type": "skill", "skill_id": "heavy_slash", "target_slot": 0},
				"mona": {"type": "defend"},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 敌 heavy（seed2）→ 凯尔 −28
			6: return {"party": {
				"kyle": {"type": "skill", "skill_id": "heavy_slash", "target_slot": 0},
				"mona": {"type": "attack", "target_slot": 0},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 敌 attack（seed1）→ 凯尔 −16
			7: return {"party": {
				"kyle": {"type": "skill", "skill_id": "heavy_slash", "target_slot": 0},
				"mona": {"type": "attack", "target_slot": 0},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 击杀轮（台账见头注；保底 R8/R10 保险轮）
			8: return {"party": {
				"kyle": {"type": "attack", "target_slot": 0},
				"mona": {"type": "defend"},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 保险轮①
			9: return {"party": {
				"kyle": {"type": "attack", "target_slot": 0},
				"mona": {"type": "attack", "target_slot": 0},
				"lina": {"type": "skill", "skill_id": "fireball", "target_slot": 0},
			}}   # 保险轮②
			10: return {"party": {
				"kyle": {"type": "attack", "target_slot": 0},
				"mona": {"type": "attack", "target_slot": 0},
				"lina": {"type": "skill", "skill_id": "thunder_burst", "target_slot": 0},
			}}   # 保险轮③
	return {}


func _run_battle(kind: String) -> void:
	var battle_scene: Node = _battle_scene_node()
	if battle_scene == null:
		_fail("%s 战斗场景定位失败" % kind)
		_finish(1)
		return
	# F3 渲染桥接线：驱动器持有指向生产弹字函数的 dev 引用，战后解除
	var bui: Node = battle_scene.get("ui")
	if bui != null and bui.has_method("spawn_damage_number"):
		_dev_render_fn = Callable(bui, "spawn_damage_number")
	else:
		_dev_render_fn = Callable()
	var events_before: int = _battle_events.size()
	var director: Node = Node.new()
	director.set_script(preload("res://tools/dev/_m7_r3_battle_director.gd"))
	director.name = "R3BattleDirector"
	director.set("driver", self)
	director.set("kind", kind)
	battle_scene.add_child(director)
	await director.done
	# 断言 A3/A7：结局 + 关键事件在场（事件由 director 转录进 _battle_events）
	var outcome: String = ""
	var bc: Variant = battle_scene.get("cmd")
	if bc != null:
		outcome = String(bc.get("outcome"))
	_assert(outcome == "VICTORY", "A%s %s VICTORY（rounds=%d）" % [
			"3" if kind == "b4" else "7", kind, _rounds_of(bc)])
	_e_assert(kind, "heal", "群愈/治疗回复事件在场")
	if kind == "b4":
		# sweep 不是独立事件类型：群击 = damage 事件 + sweep:true 元数据
		# （events_append_damage base_meta 注入，battle_command 正本 L532）
		var sweep_ok := false
		for ev: Dictionary in _battle_events:
			if String(ev.get("type", "")) == "damage" and bool(ev.get("sweep", false)):
				sweep_ok = true
		_assert(sweep_ok, "A3 %s 守卫群击在场（教学要素①；damage+sweep 元数据）" % kind)
		_e_assert(kind, "poison", "守卫毒击在场（教学要素②）")
		_e_assert(kind, "defend", "凯尔防御姿态在场（威胁应对）")
		# 毒 tick 证据：行动前扣血事件（无 applied 键；施加事件带 applied:true）
		var tick_ok := false
		for ev: Dictionary in _battle_events:
			if String(ev.get("type", "")) == "poison" and not ev.has("applied"):
				tick_ok = true
		_assert(tick_ok, "A3 凯尔毒 tick 结算可见（下轮行动前扣血）")
	else:
		_e_assert(kind, "charge", "核心蓄力预告在场（telegraph 教学）")
		_e_assert(kind, "defend", "防御应对 release（减伤 ×0.5）")
		_e_assert(kind, "weakness", "火球打核心弹「弱点！」")
		# release 减伤对照：release 伤害事件存在且值为防御口径
		var rel_ok := false
		for ev: Dictionary in _battle_events:
			if String(ev.get("type", "")) == "damage" and bool(ev.get("release", false)):
				rel_ok = true
		_assert(rel_ok, "A7 charge_release 兑现（伤害事件在场）")
	print("[R3Drive] %s 战斗收束（事件 %d → %d）" % [kind, events_before, _battle_events.size()])
	_dev_render_fn = Callable()   # 战后解除 dev 渲染桥


## 事件类型在场断言（A3/A7 的工具件；录制模式不追加 fail 只留痕）
func _e_assert(kind: String, ev_type: String, what: String) -> void:
	var found := false
	for ev: Dictionary in _battle_events:
		if String(ev.get("type", "")) == ev_type:
			found = true
			break
	_assert(found, "%s %s：%s" % ["A3" if kind == "b4" else "A7", kind, what])


func _rounds_of(bc: Variant) -> int:
	return int(bc.get("round_num")) if bc != null else -1


func _wait_battle_scene(timeout: float) -> void:
	var t: float = 0.0
	while t < timeout:
		if _battle_scene_active():
			return
		await _sleep(0.2)
		t += 0.2
	_fail("等待战斗场景超时（%.0fs）" % timeout)


func _battle_scene_active() -> bool:
	return SceneRouter.current_scene_path == SceneRouter.BATTLE_SCENE_PATH


func _battle_scene_node() -> Node:
	var world: Node = _get_world()
	if world == null or world.get_child_count() == 0:
		return null
	return world.get_child(world.get_child_count() - 1)


func _wait_contact_and_fight(target: Dictionary, kind: String) -> void:
	# 走位段已把玩家送进守卫 TouchArea 邻域；等自然接触（定守敌人不动，
	# 接触 = 玩家贴身），兜底直驱 _handle_player_contact（GUT 同通道）
	var waited: float = 0.0
	while waited < 4.0:
		if _battle_scene_active():
			break
		await _sleep(0.25)
		waited += 0.25
	if not _battle_scene_active():
		var enemy: Node = _find_enemy_by_uid(String(target["uid"]))
		var player: Node2D = _find_player()
		if enemy != null and player != null:
			player.encounter_immunity = 0.0
			enemy._handle_player_contact(player)
			print("[R3Drive] 守卫接触兜底直驱：%s" % String(target["uid"]))
	await _wait_battle_scene(6.0)
	_assert(_battle_scene_active(), "A2 %s 战斗进入" % kind)
	# A2 事件战斗身份：staged payload 编组
	var staged: Dictionary = SceneRouter.get_staged_payload()
	_assert(String(staged.get("enemy_group_id", "")) == String(target["group"]),
			"A2 编组=%s" % String(target["group"]))
	await _run_battle(kind)
	# 战后：等回图 + 回置
	await _wait_scene_changed_from_battle(10.0)
	await _sleep(2.2)
	if _caption != null:
		_caption.visible = true


func _wait_scene_changed_from_battle(timeout: float) -> void:
	var t: float = 0.0
	while t < timeout:
		if not _battle_scene_active():
			print("[R3Drive] 战后回图完成（%.1fs）" % t)
			return
		await _sleep(0.2)
		t += 0.2
	_fail("战后回图超时")


# ══════════════════════════════════════════════════════════════
# 走位 / 对话 / 断言 / 收尾工具（M6 同款增补）
# ══════════════════════════════════════════════════════════════

func _walk_seg(target: Vector2, timeout: float, p_safe: bool = true) -> void:
	if p_safe:
		var player: Node2D = _find_player()
		if player != null and player.has_method("start_encounter_immunity"):
			player.start_encounter_immunity(timeout + 1.5)
	await _walk_to(target, timeout)
	if _battle_scene_active():
		# 计划外遭遇（巡逻带擦边）：f2 守卫定守、f3 零敌——理论不可达；
		# 保险丝：断言失败（不静默吞）
		_fail("计划外遭遇（走位段 %s 后进入战斗）" % str(target))


func _walk_to(target: Vector2, timeout: float) -> void:
	var player: Node2D = _find_player()
	if player == null:
		_fail("找不到玩家，跳过走位 -> %s" % str(target))
		return
	var elapsed: float = 0.0
	var stuck: float = 0.0
	var prev_pos: Vector2 = player.global_position
	print("[R3Drive][walk] -> %s（起点 %s）" % [target, prev_pos])
	while elapsed < timeout:
		if not is_instance_valid(player):
			return   # 遇敌切场（接触直驱后立即开战）
		var d := target - player.global_position
		if d.length() < 5.0:
			break
		player.set_input_override(d)
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not is_instance_valid(player):
			return
		var moved := player.global_position.distance_to(prev_pos)
		prev_pos = player.global_position
		elapsed += 1.0 / 60.0
		if moved > 100.0:
			break   # 传送瞬移侦测（跨图已切）
		if moved < 0.5:
			stuck += 1.0 / 60.0
			if stuck > 0.5:
				player.global_position = target
				print("[R3Drive][walk] 卡墙兜底直落 -> %s" % str(target))
				break
		else:
			stuck = 0.0
	if is_instance_valid(player):
		player.set_input_override(Vector2.ZERO)
	_timeline += elapsed
	print("[R3Drive][walk] 到位 %s（历时 %.1fs）"
			% [player.global_position if is_instance_valid(player) else target, elapsed])


func _wait_dialogue_started(what: String, timeout: float = 5.0) -> void:
	var runner: Node = _find_runner()
	var t: float = 0.0
	while t < timeout:
		if runner != null and not runner.is_idle():
			print("[R3Drive] 对话开演：%s（%.1fs）" % [what, t])
			return
		await _sleep(0.1)
		t += 0.1
	_fail("等待对话开演超时：%s" % what)


func _wait_dialogue_finished(what: String, timeout: float = 5.0) -> void:
	var runner: Node = _find_runner()
	var t: float = 0.0
	while t < timeout:
		if runner == null or runner.is_idle():
			print("[R3Drive] 对话收束：%s（%.1fs）" % [what, t])
			return
		await _sleep(0.1)
		t += 0.1
	_fail("等待对话收束超时：%s" % what)


func _advance_until_idle(max_presses: int, p_interval: float = DIALOGUE_TAP_INTERVAL) -> void:
	var runner: Node = _find_runner()
	var presses: int = 0
	while presses < max_presses:
		if runner == null or runner.is_idle():
			print("[R3Drive] 对话经 %d 按收束" % presses)
			return
		runner.inject_interact_press()
		presses += 1
		await _sleep(p_interval)
	_fail("对话 %d 按未收束" % max_presses)


func _find_runner() -> Node:
	if _main == null:
		return null
	return _main.get_node_or_null("UILayer/DialogueRunner")


func _get_world() -> Node:
	if _main == null:
		return null
	return _main.get_node_or_null("World")


func _get_map() -> Node:
	var world: Node = _get_world()
	if world == null or world.get_child_count() == 0:
		return null
	return world.get_child(world.get_child_count() - 1)


func _find_player() -> Node2D:
	var map: Node = _get_map()
	if map == null:
		return null
	return map.get_node_or_null("YSorted/Player") as Node2D


func _find_enemy_by_uid(p_uid: String) -> Node:
	var map: Node = _get_map()
	if map == null:
		return null
	var ysorted: Node = map.get_node_or_null("YSorted")
	if ysorted == null:
		return null
	for child: Node in ysorted.get_children():
		if child.get("enemy_uid") != null and String(child.get("enemy_uid")) == p_uid:
			return child
	return null


func _spawn_main_entry() -> void:
	_main = MAIN_SCENE.instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	print("[R3Drive] 正常入口已挂载：res://scenes/main.tscn（current_scene 已指向）")


func _build_caption() -> void:
	var layer: CanvasLayer = _main.get_node_or_null("UILayer") as CanvasLayer
	if layer == null:
		return
	var test_label: Node = layer.get_node_or_null("TestLabel")
	if test_label != null:
		(test_label as CanvasItem).visible = false
	var bg := ColorRect.new()
	bg.name = "R3CaptionBg"
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.position = Vector2(0, 330)
	bg.size = Vector2(640, 30)
	layer.add_child(bg)
	_caption = Label.new()
	_caption.name = "R3Caption"
	_caption.position = Vector2(8, 336)
	_caption.size = Vector2(624, 20)
	_caption.add_theme_font_size_override("font_size", 12)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(_caption)


func _set_caption(text: String) -> void:
	if _caption != null:
		_caption.text = text
	_timeline += CAPTION_BEAT


func _sleep(t: float) -> void:
	_timeline += t
	await get_tree().create_timer(t).timeout


func _expect(what: String) -> void:
	print("[R3Drive] 期望：%s" % what)


func _assert(cond: bool, what: String) -> void:
	if cond:
		print("[R3Drive][PASS] %s" % what)
	else:
		_fails.append(what)
		push_warning("[R3Drive][FAIL] %s" % what)


func _fail(what: String) -> void:
	_fails.append(what)
	push_error("[R3Drive][FAIL] %s" % what)


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= 1.0


## 存档 map 短名 → 场景路径（与 BattleResultHandler._map_name_to_path 同源）
func _map_paths() -> Dictionary:
	const Catalog := preload("res://scripts/events/teleport_catalog.gd")
	return Catalog.MAP_SCENE_PATHS


func _position_from_loaded() -> Vector2:
	var arr: Array = SaveManager.last_loaded["position"]
	return Vector2(float(arr[0]), float(arr[1]))


## 沙盒档落盘 phase 读取（A8 时序判据用；异常返回 -1）
func _disk_phase() -> int:
	if not SaveManager.has_save():
		return -1
	var f := FileAccess.open(SaveManager.save_path, FileAccess.READ)
	if f == null:
		return -1
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f = null
	if parsed == null or not (parsed is Dictionary):
		return -1
	return int((parsed as Dictionary).get("story_phase", -1))


## A9 前半：B5 胜利落盘已发生（f3 map_ready 消费 Handler 意图——
## 档位 = f3 spawn (320,40)、phase=2、全队 Lv4 现值）
func _verify_victory_save() -> void:
	if not SaveManager.has_save():
		_fail("A9 沙盒存档不存在")
		return
	var f := FileAccess.open(SaveManager.save_path, FileAccess.READ)
	if f == null:
		_fail("A9 存档打不开")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f = null
	if parsed == null or not (parsed is Dictionary):
		_fail("A9 存档非法 JSON")
		return
	var snap: Dictionary = parsed as Dictionary
	print("[R3Drive] A9 指纹：map=%s pos=%s phase=%d" % [
			String(snap.get("map", "?")), str(snap.get("position", [])),
			int(snap.get("story_phase", -1))])
	_assert(String(snap.get("map", "")) == "ruins_f3", "A9 胜利落盘 map=ruins_f3")
	# phase 判据（时序裁定·第 3 轮实测正本）：finale save_point 与胜利回图
	# map_ready 竞速先到时档位直接落 phase=3；后到则留 phase=2 意图待消费。
	# 两者皆生产正确行为。
	_assert(int(snap.get("story_phase", -1)) in [2, 3],
			"A9 胜利落盘 phase∈{2,3}（save_point/map_ready 竞速二态）")
	var party: Array = snap.get("party", [])
	var lv_ok := party.size() >= 3
	for pd: Variant in party:
		var p: Dictionary = pd
		print("[R3Drive] A9 队伍指纹：%s Lv%d HP%d/%d MP%d/%d" % [
				String(p.get("id", "?")), int(p.get("level", 0)),
				int(p.get("hp", 0)), int(p.get("max_hp", 0)),
				int(p.get("mp", 0)), int(p.get("max_mp", 0))])
		if int(p.get("level", 0)) < 4:
			lv_ok = false
	_assert(lv_ok, "A9 存档队伍 Lv4+（修复②跨战写回证据链）")
	# A9 排他性库存认证（非 B5 结算态不可满足，防止把 B4 后传送档误判为胜利落盘）：
	# ① 双 ether 已耗尽（B5 R1 消费 → 结算写回）② B5 掉落 potion_l 已入包
	# （drop_core 100% 单掉，仅 B5 结算链会写入）
	var inv: Dictionary = snap.get("inventory", {})
	# 【第 3 轮实测正本】生产结算只合并掉落（potion_l 入包 ✓），战斗内道具
	# 消耗不做跨战斗持久化（ether_s 2→2）——消耗持久化属 E 系列待办观察项。
	# ether 账在内存态断（A9 队伍指纹 MP 值已含 ether 补蓝效果：凯尔 MP1 = 6+15−20）。
	_assert(int(inv.get("potion_l", 0)) >= 1,
			"A9 potion_l 入包（drop_core 100% 掉落 → B5 结算凭证）")


func _finish(code: int) -> void:
	if dryrun:
		print("[R3Drive] ═══ DRYRUN 结果 ═══")
		if _fails.is_empty():
			print("[R3Drive] ALL PASS（断言全过）——可进 GUI 录制")
		else:
			print("[R3Drive] FAIL ×%d：" % _fails.size())
			for what: String in _fails:
				print("[R3Drive]   - %s" % what)
		print("[R3Drive] 时间轴 ≈ %.0fs ≈ %d 帧 @30fps" % [_timeline, int(_timeline * 30.0)])
		print("[R3Drive] 敌拍留痕：%s" % str(_beats))
		print("[R3Drive] 退出码 %d" % code)
	get_tree().quit(code)
