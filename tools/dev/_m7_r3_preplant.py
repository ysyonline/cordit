# -*- coding: utf-8 -*-
"""M7 R-3 沙盒 preplant —— 把 APPDATA 沙盒档推进到 B4（遗像守卫）之前。

【与 _r3_preplant_save.py 的差异】本脚本只写沙盒（APPDATA 重定向后的
user:// 落点），全程零接触真实存档——真实档路径在本文件中不出现。

【user:// 映射】Godot Windows user:// = %APPDATA%/Godot/app_userdata/<工程名>/
驱动器启动命令注入 APPDATA=D:/code/cordit/.godot_user_tmp/r3-sandbox
→ 沙盒档落点 = r3-sandbox/Godot/app_userdata/轨迹残响/save.json
跑前先整目录清空沙盒（保幂等：上次 dryrun 的残留档/日志不渗入）。

【等级口径：Lv4】（偏离 _r3_preplant_save.py 的 Lv3，理由）：
- b5_core.tres expected_level = "Lv4"（§7 编排：B4 时 Lv3、B5 时 Lv4——
  依赖 B1~B3 累计经验把队伍推上 Lv4）；
- 生产结算 build_settlement 只按"本战经验"判级（140 < 150 阈值），
  B4 战后不会从 Lv3 升到 Lv4——自然玩法下 B5 恒为低配 Lv3（产品侧已知
  限制，battle_command.gd 头注【切片口径】自认）。实测精算：Lv3 打 B5
  每轮输出 ~87（min 包络 79），600 HP 核心需 8-9 回合，超出 R-3"约 6
  回合"节拍；Lv4 每轮 ~113（min 包络 103）→ R6~R7 击杀，正好达标。
  录制按 §7 意图曲线直接预置 Lv4。
- 数值 = base + per_level × 3（character_data 正本）。

【ether_s ×2】（偏离既有 preplant 的 ×1，理由）：
- B4→B5 战斗间无 heal 事件（story_boss_pre 链不含 heal），HP/MP 按战斗
  现值结转；B4 出场凯尔 MP = 19−6−6+5−6 = 6，B5 六发火球（莉娜 30 MP
  4×4+8）零冗余，双 ether 是 B5 剧本表（凯尔 R3/R4 防御+重斩、莉娜
  R6 防御）在 min 方差包络下 R7 保底击杀的必要补给。I2 队伍共享背包，
  战斗内任意角色可对任意目标使用（heal_mp 目标任意）。

【指纹】（M7 门评审留档）：
  map=ruins_f2 @ (384,40) phase=2
  flags=[story_p0_seen, chat_f2_01_seen]
    （chat_f2_01_seen 为 dryrun 第 1 轮实证补植：f2 走位必经聊天点 (384,360)，
    未 seen 会在接触守卫途中抢跑开演且对话不断链至战斗外——污染镜头③/④）
  f1/road 敌已清（5 uid）；宝箱已开 6；弱点记忆空
  party = 凯尔 Lv4 (HP240/MP19, iron_sword+leather_armor)
        / 莉娜 Lv4 (HP179/MP54) / 莫娜 Lv4 (HP191/MP45)
  inventory = {potion_s:3, potion_m:2, ether_s:2, antidote:1}
  equipment 持有池 []（两件初始装已穿在凯尔身上）
"""
import json
import os
import shutil

SANDBOX_APPDATA = r"D:\code\cordit\.godot_user_tmp\r3-sandbox"
SV = os.path.join(SANDBOX_APPDATA, "Godot", "app_userdata", "轨迹残响", "save.json")

# 幂等：整目录清空沙盒（真实档在 AppData/Roaming，永不触碰）
shutil.rmtree(SANDBOX_APPDATA, ignore_errors=True)
os.makedirs(os.path.dirname(SV), exist_ok=True)

d = {
    "version": 3,
    "map": "ruins_f2",
    "position": [384.0, 40.0],
    "story_phase": 2,
    "flags": ["story_p0_seen", "chat_f2_01_seen"],
    "chests_opened": [
        "chest_town_01", "chest_road_01", "chest_road_02",
        "chest_f1_01", "chest_f1_02", "chest_f1_03",
    ],
    "discovered_weakness_set": [],
    "cleared_enemy_set": [
        "road_moth_01", "road_beetle_01", "road_beetle_02",
        "ruins_f1_salamander", "ruins_f1_crystal",
    ],
    "inventory": {"potion_s": 3, "potion_m": 2, "ether_s": 2, "antidote": 1},
    "equipment": [],
    "party": [],
}

LV = 4

def mk(pid, name, job, base_hp, per_hp, base_mp, per_mp, weapon="", armor=""):
    return {
        "id": pid, "name": name, "job": job, "level": LV,
        "hp": base_hp + per_hp * (LV - 1), "max_hp": base_hp + per_hp * (LV - 1),
        "mp": base_mp + per_mp * (LV - 1), "max_mp": base_mp + per_mp * (LV - 1),
        "weapon_id": weapon, "armor_id": armor,
    }

d["party"] = [
    mk("kyle", "凯尔", "swordsman", 120, 40, 10, 3, "iron_sword", "leather_armor"),
    mk("lina", "莉娜", "sorcerer", 80, 33, 30, 8),
    mk("mona", "莫娜", "support", 95, 32, 24, 7),
]

with open(SV, "w", encoding="utf-8") as f:
    json.dump(d, f, ensure_ascii=False, indent="\t")

print("OK - sandbox preplant written (Lv4, ether_s x2, flags=[story_p0_seen,chat_f2_01_seen])")
print("path =", SV)
print("levels =", [(p["id"], p["level"], p["hp"], p["mp"]) for p in d["party"]])
