# -*- coding: utf-8 -*-
"""
gen_road.py — E4-S2 道路地图程序化生成器（克隆 gen_town.py 模板）
依据：design/gdd/map-exploration-gdd.md §3.1 道路行（48×64、宝箱 2/调查 3/敌人 3 巡逻、
      密度 ≈每 8s 一发现）+ §3.4（spawn 点周围 8 格无敌人初始位、无碰撞）
      + battle-system-gdd.md §7（B1 道路飞蛾 ×1 / B2 雷壳甲虫 ×2 敌编组摆位）
产物：scenes/maps/road.tscn（TileSet 复用 assets/tiles/town_map_tileset.tres，零新增 tres）

tile_map_data 格式（Godot 4.x TileMapLayer，与 gen_town 相同）：
  u16 版本号(=0) + N×12 字节 cell：i16 x | i16 y | u16 source_id | u16 atlas_x | u16 atlas_y | u16 alternative_tile，全部小端。

地图结构（北进南出，S 形盘山道）：
  北门 (23-24,0) 接小镇 → 南门 (23-24,63) 接遗迹 f1（传送归 E4-S6 接线）
  断桥：虚空裂缝 x15-18 / y38-50（ChasmBlocker 静态碰撞体封边，路桩残段悬空示意）
  石像：2×2 石造件 (22,38)-(23,39)，调查③锚点 (24,38)
"""
import os
import struct

# 仓库根目录 = 本脚本所在 tools/ 的上一级（E4-S0 同款仓库相对路径方案）
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------- 选型表（克隆自 gen_town.py 冻结选型）
# source_id: 0 = town_tiles, 1 = forest_tiles；值 = (source, atlas_x, atlas_y)
T_GRASS = (1, 0, 0)      # forest 草地平铺
T_GRASS_B = (1, 1, 1)    # forest 草地变体
T_ROAD = (0, 8, 10)      # town 广场石砖——土路/街道
T_TREE_TRUNK = (1, 8, 2)     # forest 树干行（挂碰撞）
T_TREE_CANOPY_L = (1, 8, 1)  # forest 树冠左（Above，无碰撞）
T_TREE_CANOPY_R = (1, 9, 1)  # forest 树冠右（Above，无碰撞）
T_SHRUB = (0, 18, 25)    # town 灌木（挂碰撞）
T_FENCE = (0, 22, 10)    # 栅栏（断桥警示桩）
T_STONE_L = (0, 0, 27)   # 石造件 A
T_STONE_M = (0, 1, 27)   # 石造件 B
T_STONE_R = (0, 2, 27)   # 石造件 C
T_CHEST = (0, 26, 22)    # 宝箱（木箱件，挂碰撞）

# 本图 Walls 层用到的碰撞 tile（均已在 town_map_tileset.tres 声明并挂碰撞，本工具不写 tres）
WALL_TILES = sorted({T_TREE_TRUNK, T_SHRUB, T_FENCE, T_STONE_L, T_STONE_M, T_STONE_R, T_CHEST})


def box_full():
    """满格 16×16 碰撞多边形（相对 tile 中心，像素）——与 gen_town 一致"""
    return "-8, -8, 8, -8, 8, 8, -8, 8"


# ---------------------------------------------------------------- tile_map_data 组装（克隆 gen_town）
def cell(x, y, src, ax, ay):
    return struct.pack("<hhHHHH", x, y, src, ax, ay, 0)


def packed_text(cells):
    body = b"\x00\x00" + b"".join(cell(x, y, *t) for (x, y, t) in cells)
    return ", ".join(str(b) for b in body)


def rect(x0, y0, x1, y1, t):
    """闭区间矩形填充"""
    return [(x, y, t) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


def dedupe(cells):
    """同格后写覆盖前写"""
    d = {}
    for (x, y, t) in cells:
        d[(x, y)] = t
    return [(x, y, t) for (x, y), t in d.items()]


# ---------------------------------------------------------------- 尺寸与虚空区
W, H = 48, 64
# 虚空裂缝（断桥）：x∈[15,18], y∈[38,50]——无 Ground/Deco，Walls 不入，碰撞由 ChasmBlocker 封边
CHASM = (15, 38, 18, 50)


def in_chasm(x, y):
    x0, y0, x1, y1 = CHASM
    return x0 <= x <= x1 and y0 <= y <= y1


# ---------------------------------------------------------------- 道路布线（GroundDeco，T_ROAD）
# S 形盘山道：北门→东→西→东→西→断桥绕行→南门；主路径约 223 tile ≈ 50s 纯走图（4.5 tile/s）
ROAD_SEGS = [
    (23, 1, 24, 12),    # N0 北门南下
    (24, 8, 43, 9),     # H1 东行
    (42, 9, 43, 16),    # V1 南下（东缘）
    (10, 16, 43, 17),   # H1b 西行长横
    (10, 16, 11, 26),   # V2 南下（西缘）
    (10, 26, 36, 27),   # H2 东行
    (35, 26, 36, 36),   # V3 南下（东缘）
    (4, 36, 36, 37),    # H3 西行长横（石像段）
    (4, 36, 5, 46),     # V4 南下（西缘）
    (4, 46, 14, 47),    # H4 东行至断桥西缘
    (15, 46, 15, 47),   # 断桥西残段（悬空路桩，止于虚空）
    (18, 46, 18, 47),   # 断桥东残段（对岸残端，示意桥已断）
    (13, 47, 14, 53),   # V4b 绕行南下（虚空西侧）
    (13, 53, 43, 54),   # H4c 东行（绕过断桥南端）
    (42, 53, 43, 60),   # V5 南下（东缘）
    (23, 60, 43, 61),   # H6 西行
    (23, 62, 24, 62),   # V7 至遗迹门
]
deco = []
for (x0, y0, x1, y1) in ROAD_SEGS:
    deco += rect(x0, y0, x1, y1, T_ROAD)
deco_cells = dedupe(deco)

# ---------------------------------------------------------------- Ground（草地平铺，虚空区留黑）
ground = []
for y in range(H):
    for x in range(W):
        if in_chasm(x, y):
            continue  # 虚空不铺底（露引擎清屏色 = 裂缝黑）
        ground.append((x, y, T_GRASS if (x + y) % 5 else T_GRASS_B))
ground_cells = dedupe(ground)

# ---------------------------------------------------------------- WallsObjects
walls = []

# --- 边框树墙：0/63 行、0/47 列；北门 (23,0)(24,0)、南门 (23,63)(24,63) 开口
gate_open = {(23, 0), (24, 0), (23, 63), (24, 63)}
for x in range(W):
    for y in (0, H - 1):
        if (x, y) not in gate_open:
            walls.append((x, y, T_TREE_TRUNK))
for y in range(H):
    walls.append((0, y, T_TREE_TRUNK))
    walls.append((W - 1, y, T_TREE_TRUNK))

# --- 林墙封堵带 ×5（双行，防草地直穿捷径）：S 形道路的每个南北空隙各两条横贯带，
#     带上开口 = 该高度穿过 S 链的道路格（2 宽）。玩家南下必须沿 S 链绕行（BFS 复核 ~220 tile）。
#     带D 压到 y40/41（断桥北缘）：把"绕行选择"提前到 H3 段，断桥-石像构图不动。
BANDS = [
    (14, [(42, 14), (43, 14)]),                # 带A：N0尾(y12)→H1b头(y16) 空隙；开口=V1
    (21, [(10, 21), (11, 21)]),                # 带B：H1b尾(y17)→H2头(y26)；开口=V2
    (31, [(35, 31), (36, 31)]),                # 带C：H2尾(y27)→H3头(y36)；开口=V3
    (40, [(4, 40), (5, 40)]),                  # 带D：H3(y36)→H4c头(y53)；开口=V4（断桥绕行，断桥本身阻断中段）
    (57, [(42, 57), (43, 57)]),                # 带E：H4c尾(y54)→H6头(y60)；开口=V5
]
for (by, opens) in BANDS:
    open_xs = {x for (x, oy) in opens if oy == by}  # 开口按列定义：两行同列均开（通道 2×2）
    for dy in (0, 1):                          # 双行树墙（消除 1 格缝隙直穿）
        for bx in range(W):
            if bx in open_xs or in_chasm(bx, by + dy):
                continue  # 开口列与虚空格（虚空本身阻断）不放树
            walls.append((bx, by + dy, T_TREE_TRUNK))

# --- 断桥警示桩（虚空邻接草地侧，6 根；与带D 同格处由后写覆盖为栅栏桩）
walls += [(14, 44, T_FENCE), (14, 45, T_FENCE), (19, 44, T_FENCE),
          (19, 45, T_FENCE), (19, 48, T_FENCE), (19, 49, T_FENCE)]

# --- 石像地标：2×2 石造件 (22,38)-(23,39)（调查③锚点在东侧 (24,38)）
walls += [(22, 38, T_STONE_L), (23, 38, T_STONE_M), (22, 39, T_STONE_M), (23, 39, T_STONE_R)]

# --- 遗迹门南柱：南门两侧石柱 (21,62)(22,62)(25,62)(26,62)（遗迹入口暗示，f1 归 E4-S3）
walls += [(21, 62, T_STONE_L), (22, 62, T_STONE_M), (25, 62, T_STONE_M), (26, 62, T_STONE_R)]

# --- 宝箱 tile（挂碰撞，锚点同位）：宝箱① (9,16)、宝箱② (36,62)
walls += [(9, 16, T_CHEST), (36, 62, T_CHEST)]

# --- 散树（树干位；树冠 = Above 层正上方）；已避开道路 ±2、spawn 半径 8、虚空 ±1、锚点、封堵带
TREE_TRUNKS = [(3, 3), (8, 4), (33, 3), (45, 12), (2, 26), (45, 26), (2, 42),
               (45, 42), (2, 56), (45, 56), (8, 58), (40, 58)]
above = []
for (tx, ty) in TREE_TRUNKS:
    walls.append((tx, ty, T_TREE_TRUNK))
    above.append((tx, ty - 1, T_TREE_CANOPY_L))   # 树冠 = 树干正上方（gen_town 同款）
    above.append((tx + 1, ty - 1, T_TREE_CANOPY_R))

# --- 灌木点缀（含四角）
SHRUBS = [(16, 22), (40, 30), (8, 30), (28, 44), (30, 58), (16, 58),
          (2, 2), (45, 2), (2, 61), (45, 61)]
for (sx, sy) in SHRUBS:
    walls.append((sx, sy, T_SHRUB))

walls_cells = dedupe(walls)

# ---------------------------------------------------------------- 点位与实体数据
# 敌人 ×3（巡逻；group 对应战斗 GDD §7：B1 飞蛾×1 → b1_moth；B2 甲虫×2 → b2_beetles）
# 摆位沿路径序：蛾 (18,26) → 甲虫A (14,36) → 甲虫B (30,53)（南=后，教学序成立）
ENEMIES = [
    ("Enemy_road_moth_01", 18, 26, "road_moth_01", "b1_moth", [80, 0, -80, 0]),
    ("Enemy_road_beetle_01", 14, 36, "road_beetle_01", "b2_beetles", [80, 0, -80, 0]),
    ("Enemy_road_beetle_02", 30, 53, "road_beetle_02", "b2_beetles", [96, 0, -96, 0]),
]
# 调查锚点 ×3（文案归 E7-S2 占位；事件模板归 E4-S5）
INVESTIGATE = [("Investigate_road_01", 38, 10), ("Investigate_road_02", 34, 28),
               ("Investigate_road_03", 24, 38)]
# 宝箱锚点 ×2（与 Walls 层宝箱 tile 同位）
CHESTS = [("Chest_road_01", 9, 16), ("Chest_road_02", 36, 62)]
# 出生点：from_town 落位 = 2 宽道路中线 (384,64)，参考格 (23.5,3.5)——
# 距北边框树(y0) 切比雪夫 3 格 > 工程自查口径（GDD"周围 8 格"针对敌人初始位；
# 碰撞项按边框树豁免边框带，工程自查以 ≥2 格净空执行并留档）
SPAWN_PX = (384, 64)
# 断桥封边碰撞体：覆盖虚空区 x[240,304] y[608,816]（tile x15-18 / y38-50）
BLOCKER_POS = (272, 712)
BLOCKER_SIZE = (64, 208)

# ---------------------------------------------------------------- tscn 文本
tscn = []
tscn.append('[gd_scene load_steps=6 format=3]')
tscn.append('')
tscn.append('[ext_resource type="Script" path="res://scripts/maps/road_map.gd" id="1_mapgd"]')
tscn.append('[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="2_player"]')
tscn.append('[ext_resource type="TileSet" path="res://assets/tiles/town_map_tileset.tres" id="3_tileset"]')
tscn.append('[ext_resource type="PackedScene" path="res://scenes/enemies/visible_enemy.tscn" id="4_enemy"]')
tscn.append('')
tscn.append('[sub_resource type="RectangleShape2D" id="RectangleShape2D_chasm"]')
tscn.append(f'size = Vector2({BLOCKER_SIZE[0]}, {BLOCKER_SIZE[1]})')
tscn.append('')
tscn.append('[node name="Map_Road" type="Node2D"]')
tscn.append('script = ExtResource("1_mapgd")')
tscn.append('')


def layer_node(name, z, cells, y_sort=False):
    lines = [f'[node name="{name}" type="TileMapLayer" parent="."]',
             'tile_set = ExtResource("3_tileset")',
             f'z_index = {z}']
    if y_sort:
        lines.append('y_sort_enabled = true')
    lines.append(f'tile_map_data = PackedByteArray({packed_text(cells)})')
    return lines


tscn += layer_node("Ground", -10, ground_cells)
tscn.append('')
tscn += layer_node("GroundDeco", -9, deco_cells)
tscn.append('')
tscn += ['[node name="YSorted" type="Node2D" parent="."]',
         'y_sort_enabled = true',
         '']
# 敌人 ×3（可见敌人实体，E2-S2 场景实例）
for (nm, tx, ty, uid, gid, wps) in ENEMIES:
    tscn += [f'[node name="{nm}" parent="YSorted" instance=ExtResource("4_enemy")]',
             f'position = Vector2({tx * 16 + 8}, {ty * 16 + 8})',
             f'enemy_uid = "{uid}"',
             f'group_id = "{gid}"',
             'return_map = "road"',
             'waypoints = Array[Vector2]([Vector2(%d, %d), Vector2(%d, %d)])' % tuple(wps),
             '']
# 点位锚点（宝箱/调查）
tscn += ['[node name="Anchors" type="Node2D" parent="YSorted"]', '']
for (nm, tx, ty) in CHESTS + INVESTIGATE:
    tscn += [f'[node name="{nm}" type="Marker2D" parent="YSorted/Anchors"]',
             f'position = Vector2({tx * 16 + 8}, {ty * 16 + 8})',
             '']
# 玩家（from_town 出生位）
tscn += ['[node name="Player" parent="YSorted" instance=ExtResource("2_player")]',
         f'position = Vector2({SPAWN_PX[0]}, {SPAWN_PX[1]})',
         '']
tscn += layer_node("WallsObjects", 0, walls_cells, y_sort=True)
tscn.append('')
tscn += layer_node("Above", 10, above)
tscn.append('')
# 传送触发器归 E4-S6 接线（from_town / to_ruins_f1），本 Story 仅留容器
tscn += ['[node name="Triggers" type="Node2D" parent="."]', '']
# 断桥封边静态碰撞体（层 1 = 世界墙体；挡玩家坠入虚空）
tscn += ['[node name="ChasmBlocker" type="StaticBody2D" parent="."]',
         'collision_layer = 1',
         'collision_mask = 0',
         f'position = Vector2({BLOCKER_POS[0]}, {BLOCKER_POS[1]})',
         '']
tscn += ['[node name="CollisionShape2D" type="CollisionShape2D" parent="ChasmBlocker"]',
         'shape = SubResource("RectangleShape2D_chasm")',
         '']
TSCN_TEXT = "\n".join(tscn) + "\n"

out_path = os.path.join(REPO_ROOT, "scenes", "maps", "road.tscn")
with open(out_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(TSCN_TEXT)

print("road tscn:", len(TSCN_TEXT), "chars ->", os.path.relpath(out_path, REPO_ROOT))
print("cells  ground:", len(ground_cells), "| deco:", len(deco_cells),
      "| walls:", len(walls_cells), "| above:", len(above))
# 主路径长度粗算（各段中线长，供证据引用；精确值以 verify_road.py BFS 为准）
mid = sum((x1 - x0) + (y1 - y0) + 1 for (x0, y0, x1, y1) in ROAD_SEGS)
print("road segments:", len(ROAD_SEGS), "| 主路径中线粗算:", mid, "tile ≈", round(mid / 4.5), "s 纯走图")
