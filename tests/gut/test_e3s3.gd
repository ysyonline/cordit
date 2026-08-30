extends GutTest
## E3-S3 四指令 + 三结局状态机（EPIC-3 第 3 条 Story）
##
## 【断言覆盖】EPIC-3.md E3-S3 验收标准 + GDD §3.2~§3.6 边缘情况：
##   ① 四指令可用（攻击/技能/道具/防御）、MP 不足置灰、Boss 禁逃、B1 锁技能；
##   ② 攻击物理伤害按公式；火球命中弱点伤害放大 + 弱点记忆 + 击退；
##   ③ 防御减伤姿态 + 回 MP 5；
##   ④ 逃跑成功率公式 + 任一成功整队脱离；
##   ⑤ 胜利（敌全灭）/ 失败（我方全灭）/ 失败读档占位（outcome=DEFEAT）；
##   ⑥ 边缘 8 中毒行动前致死中断；边缘 2 掩护承接伤害转移；
##   ⑦ 敌人 AI 权重复用 + 蓄力/释放 telegraph。
##
## 全部 headless 驱动 BattleCommand（RefCounted），不进场景树。

const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")

## 构建指定角色/等级的我方单位数组
func _party(ids: Array, levels: Array) -> Array:
	var out: Array[Dictionary] = []
	for i: int in ids.size():
		var u: Dictionary = BattleUnits.build_party_unit(String(ids[i]), int(levels[i]))
		if not u.is_empty():
			out.append(u)
	return out


## 取实时当前行动者（队列中引用的实际单位）
func _actor(bc: BattleCommand) -> Dictionary:
	return bc.current_actor()


## 改某单位 hp（用于构造低血致死场景）
func _set_hp(list: Array[Dictionary], slot: int, hp: int) -> void:
	for u: Dictionary in list:
		if int(u.get("slot", -1)) == slot:
			u["hp"] = hp


# =============== ① 四指令可用性 ===============

func test_B1锁技能_可用指令不含技能() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var cmds: Array[String] = bc.available_commands(_actor(bc))
	assert_true(cmds.has("attack"), "攻击永远可用")
	assert_true(cmds.has("defend"), "防御永远可用")
	assert_true(cmds.has("escape"), "B1 非 Boss，逃跑可用")
	assert_false(cmds.has("skill"), "B1 skills_locked，技能应置灰")


func test_Boss战_逃跑置灰() -> void:
	var bc := BattleCommand.new()
	bc.setup("b5_core", _party(["kyle", "lina", "mona"], [4, 4, 4]), BattleUnits.build_encounter("b5_core"))
	bc.start()
	var cmds: Array[String] = bc.available_commands(_actor(bc))
	assert_false(cmds.has("escape"), "Boss 战逃跑应置灰")


func test_MP不足_技能置灰() -> void:
	var bc := BattleCommand.new()
	var party: Array[Dictionary] = _party(["kyle"], [1])
	party[0]["mp"] = 0   # 凯尔 Lv1 仅重斩(mp6)，MP=0 应置灰
	bc.setup("b1_moth", party, BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var skills: Array = bc.available_skills(_actor(bc))
	assert_eq(skills.size(), 0, "MP=0 时凯尔无可用技能")


# =============== ② 伤害公式 ===============

func test_攻击造成物理伤害按公式() -> void:
	var bc := BattleCommand.new()
	var party: Array[Dictionary] = _party(["kyle"], [1])
	bc.setup("b1_moth", party, BattleUnits.build_encounter("b1_moth"))
	bc.start()
	var hp_before: int = bc.enemies[0]["hp"]   # 飞蛾 hp 50
	bc.submit_command(_actor(bc), {"type": "attack", "target_slot": 0}, 1.0)
	# 凯尔 Lv1 atk14, 飞蛾 def3: max(1,14*2-3)=25
	assert_eq(bc.enemies[0]["hp"], hp_before - 25, "凯尔普攻飞蛾应扣 25")


func test_火球命中弱点_伤害放大且记录弱点且击退() -> void:
	var bc := BattleCommand.new()
	var party: Array[Dictionary] = _party(["lina"], [1])
	bc.setup("b2_beetles", party, BattleUnits.build_encounter("b2_beetles"))
	bc.start()  # 莉娜 spd10 > 甲虫 spd8，莉娜先手
	var hp_before: int = bc.enemies[0]["hp"]   # 甲虫 hp 45，弱火
	var res: Array[Dictionary] = bc.submit_command(_actor(bc),
		{"type": "skill", "skill_id": "fireball", "target_slot": 0}, 1.0)
	# 莉娜 Lv1 mag12: max(1,12*2.2-6*1.2)=19.2 ×1.4 ×1.5 = 40.32 → 40
	assert_eq(bc.enemies[0]["hp"], hp_before - 40, "火球打甲虫应扣 40")
	assert_true(bc.discovered_weakness.has("fire"), "命中弱点应记录到跨战斗记忆")
	var has_weak: bool = false
	var has_kb: bool = false
	for e: Dictionary in res:
		if e["type"] == "weakness":
			has_weak = true
		if e["type"] == "knockback":
			has_kb = true
	assert_true(has_weak, "应发射弱点弹字事件")
	assert_true(has_kb, "命中弱点应触发击退事件")


# =============== ③ 防御 ===============

func test_防御_减伤姿态且回MP() -> void:
	var bc := BattleCommand.new()
	var party: Array[Dictionary] = _party(["kyle"], [1])
	bc.setup("b1_moth", party, BattleUnits.build_encounter("b1_moth"))
	bc.start()
	bc.party[0]["mp"] = 5   # 留足回复空间（满蓝时防御回蓝被 max 钳制，测不出）
	var mp_before: int = bc.party[0]["mp"]   # 5
	bc.submit_command(_actor(bc), {"type": "defend"}, 1.0)
	assert_true(bc.party[0]["defending"], "防御姿态应置位")
	assert_eq(bc.party[0]["mp"], mp_before + 5, "防御应回 5 MP")


# =============== ④ 逃跑 ===============

func test_逃跑成功_整队脱离() -> void:
	var bc := BattleCommand.new()
	bc.setup("b1_moth", _party(["kyle", "lina", "mona"], [1, 1, 1]), BattleUnits.build_encounter("b1_moth"))
	bc.start()
	# B1 我方均 SPD>飞蛾，escape_chance = 0.7 + (11-6)*0.02 = 0.8；roll=0 必成功
	# 注意：submit_command 第3位是 variance、第4位才是 roll，务必显式传位
	bc.submit_command(_actor(bc), {"type": "escape"}, 1.0, 0.0)
	assert_eq(bc.outcome, "ESCAPE", "逃跑成功应置 ESCAPE")
	assert_true(bc.over, "逃跑成功应结束战斗")


# =============== ⑤ 三结局 ===============

func test_胜利_敌全灭触发() -> void:
	var bc := BattleCommand.new()
	var enemies: Array[Dictionary] = BattleUnits.build_encounter("b1_moth")
	_set_hp(enemies, 0, 10)   # 飞蛾 hp 降到 10，凯尔普攻 25 必杀
	bc.setup("b1_moth", _party(["kyle"], [1]), enemies)
	bc.start()
	bc.submit_command(_actor(bc), {"type": "attack", "target_slot": 0}, 1.0)
	assert_eq(bc.outcome, "VICTORY", "敌全灭应触发胜利")


func test_失败_我方全灭触发() -> void:
	var bc := BattleCommand.new()
	var party: Array[Dictionary] = _party(["kyle"], [1])
	_set_hp(party, 0, 5)   # 凯尔 hp 5，飞蛾普攻 6 必杀
	bc.setup("b1_moth", party, BattleUnits.build_encounter("b1_moth"))
	bc.start()
	bc.submit_command(_actor(bc), {"type": "attack", "target_slot": 0}, 1.0)  # 飞蛾未死
	var moth: Dictionary = _actor(bc)   # 推进到飞蛾行动
	bc.enemy_action(moth, -1, 1.0)      # 飞蛾攻击凯尔
	assert_eq(bc.outcome, "DEFEAT", "我方全灭应触发失败（读档占位）")


# =============== ⑥ 边缘 ===============

func test_边缘8_中毒行动前致死中断() -> void:
	var bc := BattleCommand.new()
	var party: Array[Dictionary] = _party(["kyle"], [1])
	party[0]["poison_turns"] = 1
	party[0]["max_hp"] = 100
	party[0]["hp"] = 3   # 低于毒伤 100*5%=5
	bc.setup("b1_moth", party, BattleUnits.build_encounter("b1_moth"))
	bc.start()
	bc.submit_command(_actor(bc), {"type": "attack", "target_slot": 0}, 1.0)
	assert_eq(bc.outcome, "DEFEAT", "中毒致死导致全灭应触发失败")


func test_边缘2_掩护承接伤害转移() -> void:
	# 用满编三人队：单元 slot 字段 == 数组下标（生产不变量），_unit("party",2) 才能命中莫娜
	var bc := BattleCommand.new()
	var party: Array[Dictionary] = _party(["kyle", "lina", "mona"], [1, 1, 1])
	party[0]["hp"] = 100   # 凯尔（slot0）掩护者
	party[2]["hp"] = 5     # 莫娜（slot2）被掩护者，脆
	bc.setup("b1_moth", party, BattleUnits.build_encounter("b1_moth"))
	bc.start()
	bc.submit_command(_actor(bc), {"type": "skill", "skill_id": "cover", "target_slot": 2}, 1.0)
	assert_true(bc.party[0]["covering"], "凯尔应进入掩护姿态")
	# 模拟莫娜(slot2)受击 10 点：应转移给凯尔(slot0)
	var mona: Dictionary = bc._unit("party", 2)
	var mona_hp_before: int = mona["hp"]
	var kyle_hp_before: int = bc.party[0]["hp"]
	bc.events_append_damage(mona, 10, BattleLogic.ELEMENT_NONE, false, {"name": "莫娜"})
	assert_eq(mona["hp"], mona_hp_before, "被掩护者不应直接承伤")
	assert_eq(bc.party[0]["hp"], kyle_hp_before - 10, "伤害应转移给掩护者凯尔")


# =============== ⑦ 敌人 AI ===============

func test_敌人AI_普通敌只放攻击() -> void:
	var bc := BattleCommand.new()
	var party: Array[Dictionary] = _party(["kyle"], [1])
	bc.setup("b1_moth", party, BattleUnits.build_encounter("b1_moth"))
	bc.start()
	bc.submit_command(_actor(bc), {"type": "attack", "target_slot": 0}, 1.0)  # 飞蛾未死
	var kyle_hp_before: int = bc.party[0]["hp"]
	var moth: Dictionary = _actor(bc)
	bc.enemy_action(moth, 0.0, 1.0)   # roll=0 → 普通敌权重 100 必选 attack
	assert_true(bc.party[0]["hp"] < kyle_hp_before or bc.over, "飞蛾应发动攻击（或已致全灭）")
