# -*- coding: utf-8 -*-
"""R-3 预置存档构造器 —— 把用户档推进到"遗迹二层 B4（遗像守卫）之前"。

依据（全部正本，零猜测）：
- growth_curve.tres：头注释「B4 预期 Lv3」。故取 Lv3（exp 记 150 为 Lv4 门槛参考，
  实际 exp 不入档——CharacterRecord 无 exp 字段，等级即正本）。
- character_data per_level：凯尔 HP+40/MP+3；莉娜 HP+33/MP+8；莫娜 HP+32/MP+7。
  Lv3 = base + 2×per_level。
- skills_by_level（正本 tres）：Lv3 时凯尔=重斩/横扫/掩护；莉娜=火球/冰锥/雷爆；
  莫娜=治疗/群愈/净化。存档协议不存技能（CharacterRecord 无 skills 字段——
  技能由 GameData 侧按等级+职业实时推导，读档后自动正确，无需写档）。
- story_phase：story_anchor.json story_boss_pre 要求 >=2；story_p3_boss_front
  （B5 前剧情）在 f3 触发。B4 之前 → phase=2。
  ⚠️【O-5 缺陷备注】story_ruin_enter（phase 1→2 的唯一生产路径）在 scripts/、
  scenes/、gen_ruins.py 全库零触发端（已登记 m7-final-qa-gate.md O-5）——
  自然游玩 phase 无法到 2，本预置档直接写 2，恰好绕开该断裂，属录制必需。
- map/position：ruins_f2 从 f1 南门首入落位 (23.5,2)→px(376,40)？不对——
  pos_from_f1 = Vector2(384, 40)（ruins_f2_map.gd @export 正本）。
  B4 摆位 (376,392)（ruins_f2.tscn），出生位 (384,40) 与 B4 同列偏上，
  间距 352px，安全（零重合）。
- 装备：原档实为全新档（phase=0、Lv1、flags/集合全空、装备未穿——evidence/
  _r3-save-backup-20260912-0933-save.json 为证），"忠实玩家自然进度"前提不成立。
  故按"自然玩到 B4 前"的理想口径代穿：kyle weapon_id=iron_sword、
  armor_id=leather_armor，equipment 池清空（装备在身上不在池里，E6-S1 语义）。
- 背包：B1-B3 + f1 三宝箱的自然掉落/拾取估算：
  路上 B1 飞蛾×1、B2 甲虫×2、B3 混编（enemy 组见 f1 tres）掉落 potion_s×若干；
  宝箱 ether_s×1 / potion_m×1 / potion_s×1。
  保守合理值：potion_s×3, potion_m×2, ether_s×1, antidote×1（road 宝箱 1）。
  用量留足 B4 群击抬血 + B5 蓄力应对，避免录到一半没药卡镜头。
- cleared_enemy_set：f1 三只（salamander/crystal + road 3 只）已清，防读档进 f2
  后折返 f1 时敌人复活打断录制。enemy_uid 命名从 tscn 正本取。
- chests_opened：f1 三箱 + road 两箱 + town 一箱（按"路上自然拾取"口径）。
"""
import json
import os

SV = os.path.expandvars(r"C:\Users\weixufeng\AppData\Roaming\Godot\app_userdata\轨迹残响\save.json")

with open(SV, encoding="utf-8") as f:
    d = json.load(f)

# --- map / position：f2 南门首入位（ruins_f2_map.gd pos_from_f1 正本） ---
d["map"] = "ruins_f2"
d["position"] = [384.0, 40.0]

# --- story_phase = 2（ruin_enter 已看，boss_pre 待触发） ---
d["story_phase"] = 2

# --- flags：仅 story_p0_seen（story_intro.json 正本，全主线唯一 flag）。
# P1（story_quest_accept）/P2（story_ruin_enter）均不用旗标：一次性由
# story_phase 门闸（==0 / >=1）+ set_story_phase 单调推进保证，无需写。
# party_chat_f2_01 用自己的 chat_f2_01_seen 旗，读档后自然触发即可，不预置。
flags = ["story_p0_seen"]
d["flags"] = flags

# --- party：Lv3（growth_curve 头注释"B4 预期 Lv3"），数值=base+2×per_level ---
def mk(pid, name, job, base_hp, per_hp, base_mp, per_mp, weapon="", armor=""):
    lv = 3
    return {
        "id": pid, "name": name, "job": job, "level": lv,
        "hp": base_hp + per_hp * (lv - 1), "max_hp": base_hp + per_hp * (lv - 1),
        "mp": base_mp + per_mp * (lv - 1), "max_mp": base_mp + per_mp * (lv - 1),
        "weapon_id": weapon, "armor_id": armor,
    }

d["party"] = [
    mk("kyle", "凯尔", "swordsman", 120, 40, 10, 3, "iron_sword", "leather_armor"),
    mk("lina", "莉娜", "sorcerer", 80, 33, 30, 8),
    mk("mona", "莫娜", "support", 95, 32, 24, 7),
]

# --- 集合字段：路上自然清敌/开箱 ---
d["cleared_enemy_set"] = [
    "road_moth_01", "road_beetle_01", "road_beetle_02",
    "ruins_f1_salamander", "ruins_f1_crystal",
]
d["chests_opened"] = [
    "chest_town_01", "chest_road_01", "chest_road_02",
    "chest_f1_01", "chest_f1_02", "chest_f1_03",
]
d["discovered_weakness_set"] = []  # B5 弱点弹字是新发现，不预置

# --- 背包：路上掉落+宝箱估算，留足 B4/B5 用药 ---
d["inventory"] = {"potion_s": 3, "potion_m": 2, "ether_s": 1, "antidote": 1}
# 装备池：2 件初始装已代穿在凯尔身上（weapon_id/armor_id）→ 池空
d["equipment"] = []

# version 保持 3
d["version"] = 3

with open(SV, "w", encoding="utf-8") as f:
    json.dump(d, f, ensure_ascii=False, indent="\t")

print("OK - preplanted save written")
print("map =", d["map"], "pos =", d["position"], "phase =", d["story_phase"])
print("levels =", [(p["id"], p["level"], p["hp"], p["mp"]) for p in d["party"]])
