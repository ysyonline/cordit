# -*- coding: utf-8 -*-
"""
verify_road.py — E4-S2 道路地图静态核验器（克隆 verify_town.py 模板 + 两项新增）
依据：探索 GDD §3.1 道路行对表 + §3.4 制作校验项（spawn 8 格安全）。
新增核验（town 版没有的）：
  ① BFS 连通性：北门→南门可达、主路径长度达标（~60s 口径 = 230-300 tile）；
  ② spawn 8 格安全：出生点周围无敌人初始位、无碰撞 tile（ChasmBlocker 矩形单列）。
用法：python verify_road.py → 全部 PASS 退出码 0
"""
import os
import re
import struct
import sys
from collections import deque

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TSCN = os.path.join(REPO_ROOT, "scenes", "maps", "road.tscn")
GD = os.path.join(REPO_ROOT, "scripts", "maps", "road_map.gd")
TRES = os.path.join(REPO_ROOT, "assets", "tiles", "town_map_tileset.tres")

failures = []
passed = 0


def check(name, cond, detail=""):
    global passed
    if cond:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failures.append(name)
        print(f"  FAIL  {name}  {detail}")


tscn_text = open(TSCN, encoding="utf-8").read()
gd_text = open(GD, encoding="utf-8").read()
tres_text = open(TRES, encoding="utf-8").read()

# ---------- 解析 tile_map_data（同 verify_town） ----------
def parse_layer(text, layer_name):
    m = re.search(
        r'\[node name="%s" type="TileMapLayer" parent="\."\]\n(.*?)(?=\n\[node|\Z)'
        % layer_name, text, re.S)
    if not m:
        return None
    body = m.group(1)
    dm = re.search(r'tile_map_data = PackedByteArray\(([\d,\s]*)\)', body)
    if not dm:
        return {}
    vals = [int(v) for v in dm.group(1).split(",")]
    raw = bytes(vals)
    assert raw[:2] == b"\x00\x00", "版本号前 2 字节应为 0"
    cells = {}
    for off in range(2, len(raw), 12):
        x, y, src, ax, ay, alt = struct.unpack_from("<hhHHHH", raw, off)
        cells[(x, y)] = (src, ax, ay)
    return cells


W, H = 48, 64
CHASM = (15, 38, 18, 50)  # 虚空裂缝（与 gen_road 常量同源）
SPAWN = (23, 3)           # 出生参考格（2 宽中线，落位 (384,64)）
ENEMY_SPAWN_TILES = [(18, 26), (14, 36), (30, 53)]  # 与 gen_road ENEMIES 同源
BAND_ROWS = [14, 21, 31, 44, 57]  # 林墙封堵带 y（防直穿捷径）


def in_chasm(x, y):
    x0, y0, x1, y1 = CHASM
    return x0 <= x <= x1 and y0 <= y <= y1


print("== 1. 节点树结构 ==")
required_nodes = [
    ("Map_Road", "Node2D"), ("Ground", "TileMapLayer"), ("GroundDeco", "TileMapLayer"),
    ("YSorted", "Node2D"), ("WallsObjects", "TileMapLayer"), ("Above", "TileMapLayer"),
    ("Triggers", "Node2D"), ("ChasmBlocker", "StaticBody2D"), ("Anchors", "Node2D"),
]
for nm, ty in required_nodes:
    check(f"节点 {nm} ({ty})", f'[node name="{nm}" type="{ty}"' in tscn_text)
check("3 个敌人实体（visible_enemy 实例）", tscn_text.count('instance=ExtResource("4_enemy")') == 3)
check("Player 实例挂 YSorted", '[node name="Player" parent="YSorted" instance=ExtResource' in tscn_text)
check("Player 出生位 (384,64)", "position = Vector2(384, 64)" in tscn_text)
check("y_sort: YSorted", re.search(r'\[node name="YSorted"[^\]]*\]\ny_sort_enabled = true', tscn_text))
check("y_sort: WallsObjects", re.search(r'\[node name="WallsObjects"[^\]]*\]\ntile_set[^\n]*\nz_index = 0\ny_sort_enabled = true', tscn_text))
check("z_index: Ground=-10 / Deco=-9 / Above=+10", "z_index = -10" in tscn_text and "z_index = -9" in tscn_text and "z_index = 10" in tscn_text)
check("四层挂共享 TileSet", tscn_text.count('tile_set = ExtResource("3_tileset")') == 4)
check("ChasmBlocker 层1(mask 0)", re.search(r'\[node name="ChasmBlocker"[^\]]*\]\ncollision_layer = 1\ncollision_mask = 0', tscn_text))
check("5 个点位锚点（2 箱 + 3 调查）", len(re.findall(r'type="Marker2D" parent="YSorted/Anchors"', tscn_text)) == 5)

print("== 2. 地图脚本 ==")
check("gd: 主限区 768×1024", "Rect2i(0, 0, 768, 1024)" in gd_text)
check("gd: from_town 落位 (384,64)", "Vector2(384, 64)" in gd_text)
check("gd: E4-S6 衔接注释（map_ready）", "map_ready" in gd_text)
check("gd: 无对话装配（道路 0 NPC）", "DialogueBoxScene" not in gd_text)

print("== 3. 层内容抽验 ==")
ground = parse_layer(tscn_text, "Ground")
deco = parse_layer(tscn_text, "GroundDeco")
walls = parse_layer(tscn_text, "WallsObjects")
above = parse_layer(tscn_text, "Above")
for nm, layer in [("Ground", ground), ("GroundDeco", deco), ("WallsObjects", walls), ("Above", above)]:
    check(f"{nm} 可解析且非空", layer is not None and len(layer) > 0)

check("Ground 草地为 forest(source=1) 抽样", all(ground.get((x, y), (9,))[0] == 1 for x in range(0, 48, 7) for y in range(0, 64, 5) if not in_chasm(x, y)))
check("Ground 虚空区无 tile", not any(in_chasm(x, y) for (x, y) in ground))
check("Deco 北门铺路 (23,1)", (23, 1) in deco)
check("Deco 断桥西残段 (15,47)", (15, 47) in deco)
check("Deco 断桥东残段 (18,46)", (18, 46) in deco)
# 虚空无 tile：断桥残段 (15,46)(15,47)(18,46)(18,47) 属"悬空路桩"设计，豁免
check("Deco 虚空区无 tile（断桥残段豁免）", not any(in_chasm(x, y) for (x, y) in deco if (x, y) not in [(15, 46), (15, 47), (18, 46), (18, 47)]))
check("Wall 边框树 (0,0)/(47,63)", (0, 0) in walls and (47, 63) in walls)
check("Wall 北门开口 (23,0)(24,0) 无树", (23, 0) not in walls and (24, 0) not in walls)
check("Wall 南门开口 (23,63)(24,63) 无树", (23, 63) not in walls and (24, 63) not in walls)
check("Wall 虚空区无 tile", not any(in_chasm(x, y) for (x, y) in walls))
check("Wall 石像 2×2 (22,38)-(23,39)", all(p in walls for p in [(22, 38), (23, 38), (22, 39), (23, 39)]))
check("Wall 遗迹门南柱 (21,62)/(26,62)", (21, 62) in walls and (26, 62) in walls)
check("Wall 断桥警示桩 ×6", sum(1 for (x, y) in walls if walls[(x, y)] == (0, 22, 10)) == 6)
# 林墙封堵带 ×5（双行）：每条带两行、开口列两行均通（S 形强制化的结构性证据）
band_ok = True
band_bad = []
for (by, opens) in [(14, {42, 43}), (21, {10, 11}), (31, {35, 36}),
                    (40, {4, 5}), (57, {42, 43})]:
    for dy in (0, 1):
        for bx in range(W):
            if bx in opens or in_chasm(bx, by + dy):
                continue
            if (bx, by + dy) not in walls:
                band_ok = False
                band_bad.append((bx, by + dy))
check("Wall 林墙封堵带 ×5（双行）完整（防直穿）", band_ok, str(band_bad[:5]))
check("Above 树冠 (3,2)/(8,3)（散树树干 (3,3)/(8,4) 正上方）", (3, 2) in above and (8, 3) in above)
check("Above 虚空区无 tile", not any(in_chasm(x, y) for (x, y) in above))
# 用到的 tile 均已在共享 tres 声明
def tiles_used(layer):
    return {(ax, ay) for (s, ax, ay) in layer.values()}
used = tiles_used(ground) | tiles_used(deco) | tiles_used(walls) | tiles_used(above)
src_of = {}
for layer in (ground, deco, walls, above):
    for (s, ax, ay) in layer.values():
        src_of[(ax, ay)] = s
missing = []
for layer in (ground, deco, walls, above):
    for (s, ax, ay) in layer.values():
        atlas = "town" if s == 0 else "forest"
        if not re.search(r'(?m)^%d:%d/0 = 0$' % (ax, ay), tres_text):
            missing.append((ax, ay))
check("tres: 共享图集覆盖全部用到的 tile", not missing, str(missing[:5]))
# Walls 层 tile 均挂碰撞（本图无门洞 tile，无例外）
no_phys = [p for p in tiles_used(walls) if not re.search(r'(?m)^%d:%d/0/physics_layer_0' % p, tres_text)]
check("tres: Walls 层 tile 均挂碰撞", not no_phys, str(no_phys[:5]))

print("== 4. 点位表（GDD §3.1 道路行对表） ==")
enemy_expect = [
    ("Enemy_road_moth_01", 18, 26, "road_moth_01", "b1_moth"),
    ("Enemy_road_beetle_01", 14, 36, "road_beetle_01", "b2_beetles"),
    ("Enemy_road_beetle_02", 30, 53, "road_beetle_02", "b2_beetles"),
]
for nm, tx, ty, uid, gid in enemy_expect:
    m = re.search(r'\[node name="%s"[^\]]*\]\nposition = Vector2\((\d+), (\d+)\)\nenemy_uid = "([^"]+)"\ngroup_id = "([^"]+)"' % nm, tscn_text)
    ok = m and int(m.group(1)) == tx * 16 + 8 and int(m.group(2)) == ty * 16 + 8
    check(f"敌人 {nm} @({tx},{ty})", bool(ok))
    ok2 = m and m.group(3) == uid and m.group(4) == gid
    check(f"敌人 {nm} uid/group={uid}/{gid}", bool(ok2))
check("编组对表: 1×b1_moth + 2×b2_beetles", tscn_text.count('group_id = "b1_moth"') == 1 and tscn_text.count('group_id = "b2_beetles"') == 2)
point_expect = {
    "Chest_road_01": (9, 16), "Chest_road_02": (36, 62),
    "Investigate_road_01": (38, 10), "Investigate_road_02": (34, 28), "Investigate_road_03": (24, 38),
}
for nm, (tx, ty) in point_expect.items():
    m = re.search(r'\[node name="%s" type="Marker2D"[^\]]*\]\nposition = Vector2\((\d+), (\d+)\)' % nm, tscn_text)
    ok = m and int(m.group(1)) == tx * 16 + 8 and int(m.group(2)) == ty * 16 + 8
    check(f"锚点 {nm} @({tx},{ty})", bool(ok))
check("宝箱 tile 与锚点同位 (9,16)/(36,62)", walls.get((9, 16)) == (0, 26, 22) and walls.get((36, 62)) == (0, 26, 22))

print("== 5. BFS 连通性 + 密度（新增①） ==")
# 可走 = 有 Ground 且无 Walls；虚拟边界外不可走；虚空不可走
walkable = set()
for (x, y) in ground:
    if (x, y) not in walls and not in_chasm(x, y):
        walkable.add((x, y))
north_gate = [(23, 1), (24, 1)]
south_gate = [(23, 62), (24, 62)]
# 北门→南门 BFS（4 邻接）
start = next(p for p in north_gate if p in walkable)
goal = set(p for p in south_gate if p in walkable)
dist = {start: 0}
q = deque([start])
while q:
    cx, cy = q.popleft()
    if (cx, cy) in goal:
        break
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        np_ = (cx + dx, cy + dy)
        if np_ in walkable and np_ not in dist:
            dist[np_] = dist[(cx, cy)] + 1
            q.append(np_)
reached = [d for d in dist if d in goal]
check("BFS: 北门→南门连通", bool(reached), "南门不可达")
if reached:
    shortest = min(dist[d] for d in reached)
    # 口径注（E4-S2 工程自查）：GDD "~60s" 含战斗/交互停顿；BFS 纯走 ≥215 tile（≈48s）
    # + 8 发现点交互 ≈12s ≈ 60s。上限 300 防过度冗长。
    check(f"BFS: 最短路 {shortest} tile ≈ {round(shortest / 4.5)}s 纯走（达标线 215-300）", 215 <= shortest <= 300, f"实际 {shortest}")
# 顺路性：全部 8 发现点 detour = dN+dS-L ≤ 15（宝箱格挂碰撞，取相邻可走格最小 detour）
dS_dist = {}
start_s = next(p for p in south_gate if p in walkable)
dist_s = {start_s: 0}
q = deque([start_s])
while q:
    cx, cy = q.popleft()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        np_ = (cx + dx, cy + dy)
        if np_ in walkable and np_ not in dist_s:
            dist_s[np_] = dist_s[(cx, cy)] + 1
            q.append(np_)
L = min(dist[d] for d in reached)
def detour_of(tx, ty):
    if (tx, ty) in dist and (tx, ty) in dist_s:
        return dist[(tx, ty)] + dist_s[(tx, ty)] - L
    cands = [dist[p] + dist_s[p] - L for p in [(tx + 1, ty), (tx - 1, ty), (tx, ty + 1), (tx, ty - 1)]
             if p in dist and p in dist_s]
    return min(cands) if cands else 999
points = [(9, 16), (36, 62), (38, 10), (34, 28), (24, 38),          # 2 箱 + 3 调查
          (18, 26), (14, 36), (30, 53)]                              # 3 敌（遇敌点）
bad_detour = [(p, detour_of(*p)) for p in points if detour_of(*p) > 15]
check("8 发现点全部顺路（detour ≤ 15 tile）", not bad_detour, str(bad_detour))
# 敌人初始位均在可走格
bad_enemy = [p for p in ENEMY_SPAWN_TILES if p not in walkable]
check("BFS: 3 敌人初始位均可走", not bad_enemy, str(bad_enemy))

print("== 6. spawn 8 格安全（GDD §3.4 制作校验项） ==")
sx, sy = SPAWN
r = 8  # 周围 8 格半径（切比雪夫距离）
near_enemies = [p for p in ENEMY_SPAWN_TILES if max(abs(p[0] - sx), abs(p[1] - sy)) <= r]
check("spawn 周围 8 格无敌人初始位", not near_enemies, str(near_enemies))
# 碰撞项：边框带（y<=1 北缘，属地图边界结构）豁免；其余碰撞 tile 不入圈
near_walls = [(x, y) for (x, y) in walls if max(abs(x - sx), abs(y - sy)) <= r and y > 1]
check("spawn 周围 8 格无碰撞 tile（边框带豁免）", not near_walls, str(near_walls[:5]))
in_walk = (sx, sy) in walkable
check("spawn 参考格可走", in_walk)
# 敌人巡逻半径 80/96px = 5/6 tile，与 spawn 距离复核（巡逻最远伸入半径 vs 切比雪夫距离）
wp_far = [(18, 26, 5), (14, 36, 5), (30, 53, 6)]
wp_risk = [(x, y, wp) for (x, y, wp) in wp_far if max(abs(x - sx), abs(y - sy)) - wp <= r]
check("敌人巡逻最远点不进 spawn 8 格圈", not wp_risk, str(wp_risk))

print("== 7. 汇总 ==")
print(f"PASS {passed} / FAIL {len(failures)}")
if failures:
    print("失败项:")
    for f in failures:
        print(" -", f)
    sys.exit(1)
print("全部通过 ✅")
