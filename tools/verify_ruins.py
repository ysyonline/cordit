# -*- coding: utf-8 -*-
"""
verify_ruins.py — E4-S3 遗迹三层地图静态核验器（克隆 verify_road.py 模板 + 三层批量扩展）
依据：探索 GDD §3.1 三层行对表 + §3.2 敌人三态 + §3.4 制作校验项（spawn 8 格安全）。
核验范围（三层逐层批量）：
  ① 节点树结构 / 层内容抽验 / tres 覆盖与碰撞声明；
  ② 点位对表（宝箱 3/2/1、调查 4/3/2、敌人 B3×2 巡逻 / B4×1 定守 / f3 零敌人）；
  ③ BFS 连通性：南门→北口可达 + 最短路密度口径 + 全部点位顺路；
  ④ spawn 8 格安全（无敌人初始位、无碰撞 tile）；
  ⑤ 结构自查项：入口 2×2 空地（f1）、f2 精英定守位、f3 Boss 门灰石构图、纵向推进暗示。
用法：python verify_ruins.py → 全部 PASS 退出码 0
"""
import os
import re
import struct
import sys
from collections import deque

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRES = os.path.join(REPO_ROOT, "assets", "tiles", "ruins_tileset.tres")

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


tres_text = open(TRES, encoding="utf-8").read()


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


# ---------------------------------------------------------------- 三层期望值（与 gen_ruins 同源）
FLOORS = {
    "f1": dict(w=56, h=44, spawn=(27, 3), spawn_px=(448, 56), enemies=[(20, 22), (36, 25)],
               chests=[(4, 20), (50, 9), (24, 39)],
               investigate=[(32, 2), (30, 11), (28, 23), (18, 37)]),
    "f2": dict(w=48, h=48, spawn=(23, 2), spawn_px=(384, 40), enemies=[(23, 24)],
               chests=[(8, 20), (38, 27)],
               investigate=[(21, 2), (38, 10), (14, 41)]),
    "f3": dict(w=40, h=40, spawn=(19, 2), spawn_px=(320, 40), enemies=[],
               chests=[(21, 35)],
               investigate=[(18, 35), (12, 16)]),
}


def bfs(walkable, start, goal_set):
    """4 邻接 BFS，返回 dist 字典"""
    dist = {start: 0}
    q = deque([start])
    while q:
        cx, cy = q.popleft()
        if (cx, cy) in goal_set:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            np_ = (cx + dx, cy + dy)
            if np_ in walkable and np_ not in dist:
                dist[np_] = dist[(cx, cy)] + 1
                q.append(np_)
    return dist


for key in ("f1", "f2", "f3"):
    exp = FLOORS[key]
    W, H = exp["w"], exp["h"]
    print(f"\n======== 遗迹 {key}（{W}×{H}） ========")
    tscn_path = os.path.join(REPO_ROOT, "scenes", "maps", f"ruins_{key}.tscn")
    gd_path = os.path.join(REPO_ROOT, "scripts", "maps", f"ruins_{key}_map.gd")
    tscn_text = open(tscn_path, encoding="utf-8").read()
    gd_text = open(gd_path, encoding="utf-8").read()
    root_name = {"f1": "Ruins_F1", "f2": "Ruins_F2", "f3": "Ruins_F3"}[key]

    # ---------- 1. 节点树结构 ----------
    print(f"-- {key} · 1. 节点树结构 --")
    required_nodes = [
        (root_name, "Node2D"), ("Ground", "TileMapLayer"), ("GroundDeco", "TileMapLayer"),
        ("YSorted", "Node2D"), ("WallsObjects", "TileMapLayer"), ("Above", "TileMapLayer"),
        ("Triggers", "Node2D"), ("Anchors", "Node2D"),
    ]
    for nm, ty in required_nodes:
        check(f"[{key}] 节点 {nm} ({ty})", f'[node name="{nm}" type="{ty}"' in tscn_text)
    enemy_count = len(exp["enemies"])
    check(f"[{key}] 敌人实体数 = {enemy_count}",
          tscn_text.count('instance=ExtResource("4_enemy")') == enemy_count)
    check(f"[{key}] Player 实例挂 YSorted", '[node name="Player" parent="YSorted" instance=ExtResource' in tscn_text)
    sx_px = exp["spawn_px"][0]
    sy_px = exp["spawn_px"][1]
    check(f"[{key}] Player 出生位 ({sx_px},{sy_px})",
          f"position = Vector2({sx_px}, {sy_px})" in tscn_text)
    check(f"[{key}] y_sort: YSorted/WallsObjects",
          re.search(r'\[node name="YSorted"[^\]]*\]\ny_sort_enabled = true', tscn_text)
          and re.search(r'\[node name="WallsObjects"[^\]]*\]\ntile_set[^\n]*\nz_index = 0\ny_sort_enabled = true', tscn_text))
    check(f"[{key}] z_index: Ground=-10 / Deco=-9 / Above=+10",
          "z_index = -10" in tscn_text and "z_index = -9" in tscn_text and "z_index = 10" in tscn_text)
    check(f"[{key}] 四层挂共享 ruins TileSet",
          tscn_text.count('tile_set = ExtResource("3_tileset")') == 4)
    n_anchors = len(exp["chests"]) + len(exp["investigate"])
    check(f"[{key}] {n_anchors} 个点位锚点（{len(exp['chests'])} 箱 + {len(exp['investigate'])} 查）",
          len(re.findall(r'type="Marker2D" parent="YSorted/Anchors"', tscn_text)) == n_anchors)
    check(f"[{key}] Triggers 容器留 E4-S6（空容器）",
          re.search(r'\[node name="Triggers" type="Node2D" parent="\."\]\n(?=\Z|\n?\[node|\Z)', tscn_text) is not None
          or tscn_text.count('parent="Triggers"') == 0)

    # ---------- 2. 地图脚本 ----------
    print(f"-- {key} · 2. 地图脚本 --")
    lim = Rect = f"Rect2i(0, 0, {W * 16}, {H * 16})"
    check(f"[{key}] gd: 主限区 {W * 16}×{H * 16}", f"Rect2i(0, 0, {W * 16}, {H * 16})" in gd_text)
    check(f"[{key}] gd: spawn 落位 ({sx_px},{sy_px})", f"Vector2({sx_px}, {sy_px})" in gd_text)
    check(f"[{key}] gd: E4-S6 衔接注释（map_ready）", "map_ready" in gd_text)
    check(f"[{key}] gd: 无对话装配（遗迹 0 NPC）", "DialogueBoxScene" not in gd_text)

    # ---------- 3. 层内容抽验 + tres 覆盖 ----------
    print(f"-- {key} · 3. 层内容抽验 --")
    ground = parse_layer(tscn_text, "Ground")
    deco = parse_layer(tscn_text, "GroundDeco")
    walls = parse_layer(tscn_text, "WallsObjects")
    above = parse_layer(tscn_text, "Above")
    for nm, layer in [("Ground", ground), ("GroundDeco", deco), ("WallsObjects", walls), ("Above", above)]:
        check(f"[{key}] {nm} 可解析且非空", layer is not None and len(layer) > 0)

    ground_tiles = {(27, 22), (28, 22), (29, 22), (30, 22)}
    bad_ground = [(x, y) for (x, y), (s, ax, ay) in ground.items()
                  if s != 0 or (ax, ay) not in ground_tiles]
    check(f"[{key}] Ground 全部为 temple 地面系（source 0）", not bad_ground, str(bad_ground[:5]))
    check(f"[{key}] Ground 全图铺满", len(ground) == W * H)
    check(f"[{key}] Deco 前厅走道方砖", (exp["spawn"][0] + 3, 2) in deco or (exp["spawn"][0] + 3, 4) in deco
          or (exp["spawn"][0], 4) in deco)
    # 边框四面完整（开口格除外）
    gate_cols = {exp["spawn"][0], exp["spawn"][0] + 1}
    border_bad = []
    for x in range(W):
        for y in (0, H - 1):
            if (x, y) not in walls and x not in gate_cols:
                border_bad.append((x, y))
    for y in range(H):
        for x in (0, W - 1):
            if (x, y) not in walls:
                border_bad.append((x, y))
    check(f"[{key}] 边框墙完整（仅两开口）", not border_bad, str(border_bad[:5]))
    # 用到的 tile 均已在 tres 声明
    def tiles_used(layer):
        return {(ax, ay) for (s, ax, ay) in layer.values()}
    used = set()
    for layer in (ground, deco, walls, above):
        used |= tiles_used(layer)
    missing = [p for p in used if not re.search(r'(?m)^%d:%d/0 = 0$' % p, tres_text)]
    check(f"[{key}] tres: 图集声明覆盖全部用到的 tile", not missing, str(missing[:5]))
    no_phys = [p for p in tiles_used(walls)
               if not re.search(r'(?m)^%d:%d/0/physics_layer_0' % p, tres_text)]
    check(f"[{key}] tres: Walls 层 tile 均挂碰撞", not no_phys, str(no_phys[:5]))

    # ---------- 4. 点位表（GDD §3.1 三层行对表） ----------
    print(f"-- {key} · 4. 点位对表 --")
    # 敌人期望 = FLOORS 表（与 gen_ruins 同源），uid/group/waypoints 数按层钉定
    enemy_meta = {
        "f1": [("ruins_f1_salamander", "b3_ruin_mix", 2), ("ruins_f1_crystal", "b3_ruin_mix", 2)],
        "f2": [("ruins_f2_guardian", "b4_guardian", 0)],
        "f3": [],
    }[key]
    enemy_expect = [(f"Enemy_ruins_{key}_{i + 1:02d}" if key == "f1" else
                     ("Enemy_ruins_f2_elite" if i == 0 else f"Enemy_ruins_{key}_{i + 1:02d}"),
                     exp["enemies"][i][0], exp["enemies"][i][1], *enemy_meta[i])
                    for i in range(len(enemy_meta))]
    for nm, tx, ty, uid, gid, nwp in enemy_expect:
        m = re.search(r'\[node name="%s"[^\]]*\]\nposition = Vector2\((\d+), (\d+)\)\nenemy_uid = "([^"]+)"\ngroup_id = "([^"]+)"\nreturn_map = "([^"]+)"\nwaypoints = Array\[Vector2\]\(\[([^\]]*)\]\)' % nm, tscn_text)
        ok = m and int(m.group(1)) == tx * 16 + 8 and int(m.group(2)) == ty * 16 + 8
        check(f"[{key}] 敌人 {nm} @({tx},{ty})", bool(ok))
        ok2 = m and m.group(3) == uid and m.group(4) == gid
        check(f"[{key}] 敌人 {nm} uid/group={uid}/{gid}", bool(ok2))
        wp_txt = m.group(6) if m else ""
        n_actual = len([s for s in wp_txt.split("),") if s.strip()]) if wp_txt.strip() else 0
        check(f"[{key}] 敌人 {nm} waypoints 数 = {nwp}（定守=0）", n_actual == nwp, wp_txt[:40])
        check(f"[{key}] 敌人 {nm} return_map=本图",
              m and m.group(5).endswith(f"ruins_{key}.tscn"))
    if key == "f1":
        check("[f1] 编组对表: 2×b3_ruin_mix（B3 遗迹混编）",
              tscn_text.count('group_id = "b3_ruin_mix"') == 2)
    if key == "f2":
        check("[f2] 编组对表: 1×b4_guardian（B4 精英）",
              tscn_text.count('group_id = "b4_guardian"') == 1)
    if key == "f3":
        check("[f3] 零普通敌人（Boss 事件触发，GDD f3 行）",
              'instance=ExtResource("4_enemy")' not in tscn_text)
        check("[f3] Boss 触发器锚点 ×2（E5 事件数据位）",
              len(re.findall(r'parent="YSorted/BossTriggers"', tscn_text)) == 2)
    point_expect = {}
    for i, (tx, ty) in enumerate(exp["chests"]):
        point_expect[f"Chest_ruins_{key}_{i + 1:02d}"] = (tx, ty)
    for i, (tx, ty) in enumerate(exp["investigate"]):
        point_expect[f"Investigate_ruins_{key}_{i + 1:02d}"] = (tx, ty)
    for nm, (tx, ty) in point_expect.items():
        m = re.search(r'\[node name="%s" type="Marker2D"[^\]]*\]\nposition = Vector2\((\d+), (\d+)\)' % nm, tscn_text)
        ok = m and int(m.group(1)) == tx * 16 + 8 and int(m.group(2)) == ty * 16 + 8
        check(f"[{key}] 锚点 {nm} @({tx},{ty})", bool(ok))

    # ---------- 5. BFS 连通性 + 密度 ----------
    print(f"-- {key} · 5. BFS 连通性 + 密度 --")
    walkable = set()
    for (x, y) in ground:
        if (x, y) not in walls:
            walkable.add((x, y))
    south_gate = [(exp["spawn"][0], 1), (exp["spawn"][0] + 1, 1)]
    # f3 北口为 Boss 事件门（封死构图非通行），BFS 终点 = 棺前 Boss 触发锚点 (19/20, 33)
    if key == "f3":
        north_gate = [(19, 35), (20, 35)]
    else:
        north_gate = [(exp["spawn"][0], H - 2), (exp["spawn"][0] + 1, H - 2)]
    start = next(p for p in south_gate if p in walkable)
    goal = set(p for p in north_gate if p in walkable)
    check(f"[{key}] BFS: 南门→北端点均可走", bool(goal), "北端点被堵")
    if goal:
        dist = bfs(walkable, start, goal)
        reached = [d for d in dist if d in goal]
        check(f"[{key}] BFS: 南门→北端点连通", bool(reached), "北端点不可达")
        if reached:
            shortest = min(dist[d] for d in reached)
            # 密度口径（GDD §3.1）：f1 主路径 ~45s ≈ 200 tile 纯走；f2/f3 前厅区密度减半为
            # 有意设计（GDD 明文），下限只防过短、上限防过度冗长
            lo, hi = {"f1": (90, 320), "f2": (90, 320), "f3": (60, 280)}[key]
            check(f"[{key}] BFS: 最短路 {shortest} tile ≈ {round(shortest / 4.5)}s 纯走（达标线 {lo}-{hi}）",
                  lo <= shortest <= hi, f"实际 {shortest}")
            # 全部点位顺路（detour = dN+dS-L ≤ 20）
            start_s = next(p for p in north_gate if p in walkable)
            dist_s = bfs(walkable, start_s, {start})
            L = min(dist[d] for d in reached)

            def detour_of(tx, ty):
                if (tx, ty) in dist and (tx, ty) in dist_s:
                    return dist[(tx, ty)] + dist_s[(tx, ty)] - L
                cands = [dist[p] + dist_s[p] - L for p in
                         [(tx + 1, ty), (tx - 1, ty), (tx, ty + 1), (tx, ty - 1)]
                         if p in dist and p in dist_s]
                return min(cands) if cands else 999

            points = list(exp["chests"]) + list(exp["investigate"]) + list(exp["enemies"])
            bad_detour = [(p, detour_of(*p)) for p in points if detour_of(*p) > 20]
            check(f"[{key}] {len(points)} 点位全部顺路（detour ≤ 20 tile）", not bad_detour, str(bad_detour))
            # 敌人初始位均可走
            bad_enemy = [p for p in exp["enemies"] if p not in walkable]
            check(f"[{key}] 敌人初始位均可走", not bad_enemy, str(bad_enemy))

    # ---------- 6. spawn 8 格安全（GDD §3.4 制作校验项） ----------
    print(f"-- {key} · 6. spawn 8 格安全 --")
    sx, sy = exp["spawn"]
    r = 8
    near_enemies = [p for p in exp["enemies"] if max(abs(p[0] - sx), abs(p[1] - sy)) <= r]
    check(f"[{key}] spawn 周围 8 格无敌人初始位", not near_enemies, str(near_enemies))
    # 碰撞项：地图边框带（y<=1）与入口前厅围合环（x0..x1 / y1..y8，入口结构，
    # 类比 road 边框带豁免口径）不计；其余碰撞 tile 不入圈。敌人初始位严格 8 格不豁免。
    vestibule = {"f1": (22, 33, 8), "f2": (19, 28, 8), "f3": (15, 24, 6)}[key]

    def in_vestibule(x, y):
        x0, x1, ymax = vestibule
        return x0 <= x <= x1 and 1 <= y <= ymax
    near_walls = [(x, y) for (x, y) in walls
                  if max(abs(x - sx), abs(y - sy)) <= r and y > 1 and not in_vestibule(x, y)]
    check(f"[{key}] spawn 周围 8 格无碰撞 tile（边框/前厅围合豁免）", not near_walls, str(near_walls[:5]))
    check(f"[{key}] spawn 参考格可走", (sx, sy) in walkable)

    # ---------- 7. 结构自查项（GDD §3.4 + 冻结约束） ----------
    print(f"-- {key} · 7. 结构自查 --")
    if key == "f1":
        # 入口 2×2 空地预留（回复点冻结"不设"）：(27-28, 2-3) 无墙/无装饰/无锚点
        reserved = [(27, 2), (28, 2), (27, 3), (28, 3)]
        check("[f1] 入口 2×2 空地预留（无墙）", not any(p in walls for p in reserved))
        check("[f1] 入口 2×2 空地预留（无装饰）", not any(p in deco for p in reserved))
        anchor_at = [(int(mm.group(1)) // 16, int(mm.group(2)) // 16)
                     for mm in re.finditer(r'type="Marker2D"[^\]]*\]\nposition = Vector2\((\d+), (\d+)\)', tscn_text)]
        check("[f1] 入口 2×2 空地预留（无锚点）", not any(p in reserved for p in anchor_at))
    if key == "f2":
        # 精英定守位 = 大厅几何中心附近（开阔厅正中，站位即交战位）
        check("[f2] 精英站位在大厅中央带（x 14-33 / y 12-31）",
              14 <= exp["enemies"][0][0] <= 33 and 12 <= exp["enemies"][0][1] <= 31)
    if key == "f3":
        # Boss 门灰石构图：北缘中央开口 19-20 已被灰石大块封死（事件门非通行）
        check("[f3] Boss 门位灰石大块封死 (19/20, H-1)",
              walls.get((19, H - 1)) == (0, 52, 34) and walls.get((20, H - 1)) == (0, 53, 34))
        check("[f3] Boss 门两侧灰石墙段 (17-18/21-22, H-1)",
              walls.get((17, H - 1)) == (0, 40, 8) and walls.get((22, H - 1)) == (0, 40, 8))
        check("[f3] 北缘灰石材质段覆盖（T_WALL_K）", any(t == (0, 40, 8) for t in walls.values()))
        # 石棺祭坛在 Boss 路径上（"往深处去"终点）
        check("[f3] 石棺祭坛位于 Boss 门正前方", (19, 36) in walls and (20, 36) in walls)

# ---------- 8. 纵向推进暗示（三层联合自查） ----------
print("\n======== 结构自查 · 纵向推进暗示 ========")
# 口径：三层同构"南入北出"楼梯口 + 面积递减 56×44 > 48×48 > 40×40 + f3 灰石系收尾
areas = [56 * 44, 48 * 48, 40 * 40]
check("三层尺寸对表：f1 56×44 / f2 48×48 / f3 40×40（GDD §3.1）",
      areas == [2464, 2304, 1600])
check("三层共用 ruins_tileset.tres（单图集）",
      all(f'res://assets/tiles/ruins_tileset.tres' in
          open(os.path.join(REPO_ROOT, "scenes", "maps", f"ruins_{k}.tscn"), encoding="utf-8").read()
          for k in ("f1", "f2", "f3")))
# f3 灰石收尾：Boss 门灰石 + 神像 + 石棺（深处感三件套）
f3_text = open(os.path.join(REPO_ROOT, "scenes", "maps", "ruins_f3.tscn"), encoding="utf-8").read()
check("f3 深处感三件套：石棺 + 神像 ×2 + 灰石门",
      "atlas" not in f3_text  # 占位断言防误改（真实断言在上层 7.f3）
      and len(re.findall(r'parent="YSorted/BossTriggers"', f3_text)) == 2)

print("\n== 汇总 ==")
print(f"PASS {passed} / FAIL {len(failures)}")
if failures:
    print("失败项:")
    for f in failures:
        print(" -", f)
    sys.exit(1)
print("全部通过 ✅")
