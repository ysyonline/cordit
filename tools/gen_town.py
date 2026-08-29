# -*- coding: utf-8 -*-
"""
gen_town.py — E1-S5 小镇白盒地图程序化生成器（定稿版）
依据：design/gdd/e1-s5-town-build-sheet.md（唯一施工依据）
产物：
  assets/tiles/town_map_tileset.tres   共享 TileSet（town + forest 两图集）
  scenes/maps/town.tscn                五层节点树 + tile_map_data + 摆位 + 门 trigger

tile_map_data 格式（Godot 4.x TileMapLayer）：
  u16 版本号(=0) + N×12 字节 cell：
  i16 x | i16 y | u16 source_id | u16 atlas_x | u16 atlas_y | u16 alternative_tile
  全部小端。

tile 选型依据 production/tile_ascii.py 像素像画辨认（详见回传"选型裁量点"）。
本文件为一次性施工工具，位于 production/（工作缓存，不随本次 git 提交）。
"""
import struct

# ---------------------------------------------------------------- 选型表（冻结）
# source_id: 0 = town_tiles, 1 = forest_tiles；值 = (source, atlas_x, atlas_y)
T_GRASS = (1, 0, 0)      # forest 草地平铺
T_GRASS_B = (1, 1, 1)    # forest 草地变体
T_ROAD = (0, 8, 10)      # town 广场石砖（杂棕黄）——土路/街道
T_PLAZA = (0, 11, 0)     # town 灰石广场砖
T_PLAZA_B = (0, 12, 0)   # town 灰石广场砖变体
T_TREE_TRUNK = (1, 8, 2)     # forest 树干行（树 2×2 下排，挂碰撞）
T_TREE_CANOPY_L = (1, 8, 1)  # forest 树冠左（Above）
T_TREE_CANOPY_R = (1, 9, 1)  # forest 树冠右（Above）
T_SHRUB = (0, 18, 25)    # town 灌木（WallsObjects，挂碰撞）
T_WALL_A = (0, 1, 1)     # 灰砖墙 A
T_WALL_B = (0, 2, 1)     # 灰砖墙 B（压线砖）
T_WALL_C = (0, 4, 1)     # 灰砖墙 C（异色变化）
T_WALL_D = (0, 2, 2)     # 灰砖墙 D
T_WALL_E = (0, 4, 2)     # 灰砖墙 E
T_WALL_F = (0, 4, 3)     # 灰砖墙 F
T_DOOR = (0, 6, 1)       # 门洞格（拱形；门格不挂碰撞）
T_ROOF_TOP = (0, 20, 7)  # 红瓦屋顶上排
T_ROOF_MID = (0, 20, 8)  # 红瓦屋顶中排
T_CHIMNEY = (0, 31, 8)   # 烟囱（红瓦组右缘深色件）
T_WINDOW = (0, 13, 2)    # 石造窗件
T_WINDOW_B = (0, 13, 3)  # 窗变体
T_SIGN = (0, 1, 6)       # 挂牌/壁饰（挂墙左端件）
T_CRATE = (0, 26, 22)    # 木箱
T_STONE_L = (0, 0, 27)   # 石造件（神殿用灰石组 A）
T_STONE_M = (0, 1, 27)   # 石造件 B
T_STONE_R = (0, 2, 27)   # 石造件 C
T_STONE_D = (0, 0, 29)   # 石造件 D（杂色变化，封印门格）
T_FOUNTAIN = {(0, 0): (0, 0, 26), (1, 0): (0, 1, 26),   # 喷泉 2×2
              (0, 1): (0, 0, 27), (1, 1): (0, 1, 27)}
T_WELL = (0, 5, 26)      # 井体（深棕水井组右格）
T_BED_A = (0, 16, 16)    # 床上排（白枕）
T_BED_B = (0, 16, 17)    # 床下排
T_BOOKSHELF = (0, 16, 12)   # 深棕竖柜（书架）
T_STAIRS = (0, 16, 15)   # 竖柜变体（楼梯占位）
T_CARPET_A = (0, 10, 18) # 地毯左
T_CARPET_B = (0, 11, 18) # 地毯右
T_TABLE = (0, 27, 26)    # 桌
T_FIREPLACE = (0, 16, 12)   # 炉火占位（暂用深棕柜件，回传报备）
T_SAVEPOINT = (0, 16, 12)   # 存档占位（同上）
T_CHEST = (0, 26, 22)    # 宝箱（木箱件，挂碰撞）
T_INDOOR_FLOOR = (0, 18, 0)  # 木板地板（室内 Ground）
T_FENCE = (0, 22, 10)    # 栅栏（灰石件，南门封路）

# WallsObjects 层全部 tile：满格碰撞 + Y Sort Origin = 8
WALL_TILES = sorted({
    T_WALL_A, T_WALL_B, T_WALL_C, T_WALL_D, T_WALL_E, T_WALL_F,
    T_ROOF_TOP, T_ROOF_MID, T_CHIMNEY, T_WINDOW, T_WINDOW_B, T_SIGN, T_CRATE,
    T_STONE_L, T_STONE_M, T_STONE_R, T_STONE_D,
    T_FOUNTAIN[(0, 0)], T_FOUNTAIN[(1, 0)], T_FOUNTAIN[(0, 1)], T_FOUNTAIN[(1, 1)],
    T_WELL, T_BED_A, T_BED_B, T_BOOKSHELF, T_STAIRS, T_TABLE, T_SHRUB,
    T_FIREPLACE, T_SAVEPOINT, T_CHEST, T_FENCE, T_TREE_TRUNK,
})
# 注：T_DOOR 明确不挂碰撞（门洞靠 teleport 进出）；屋顶行按施工单 3.3 归 Above，
# 但由于生成器把屋顶画在 Above 层，Above 不挂碰撞不需 y-sort——屋顶行从 WALL_TILES
# 中去除以精确对齐施工单"Above 层不设 Y Sort Origin"：
WALL_TILES = [t for t in WALL_TILES if t not in (T_ROOF_TOP, T_ROOF_MID, T_CHIMNEY, T_INDOOR_FLOOR)]
ABOVE_TILES = [T_TREE_CANOPY_L, T_TREE_CANOPY_R, T_ROOF_TOP, T_ROOF_MID, T_CHIMNEY]
DECO_TILES = [T_ROAD, T_PLAZA, T_PLAZA_B, T_CARPET_A, T_CARPET_B]
GROUND_TILES = [T_GRASS, T_GRASS_B, T_INDOOR_FLOOR]

DOOR_TILES = [T_DOOR]  # 声明存在但不挂碰撞


def box_full():
    """满格 16×16 碰撞多边形（相对 tile 中心，像素）"""
    return "-8, -8, 8, -8, 8, 8, -8, 8"


# ---------------------------------------------------------------- tile_map_data 组装
def cell(x, y, src, ax, ay):
    return struct.pack("<hhHHHH", x, y, src, ax, ay, 0)


def packed_text(cells):
    body = b"\x00\x00" + b"".join(cell(x, y, *t) for (x, y, t) in cells)  # 前 2 字节 = 格式版本 0
    return ", ".join(str(b) for b in body)


def rect(x0, y0, x1, y1, t, vary=None):
    """闭区间矩形填充；vary(x,y) 可返回变体 tile"""
    out = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            out.append((x, y, vary(x, y) if vary else t))
    return out


def dedupe(cells):
    """同格后写覆盖前写，保持首次出现顺序"""
    d = {}
    for (x, y, t) in cells:
        d[(x, y)] = t
    return [(x, y, t) for (x, y), t in d.items()]


# ================================================================ Ground
ground = []
for y in range(48):
    for x in range(64):
        ground.append((x, y, T_GRASS if (x + y) % 5 else T_GRASS_B))
# 室内A/B 地板
for (rx0, ry0, rx1, ry1) in [(80, 11, 91, 19), (80, 23, 91, 31)]:
    for y in range(ry0, ry1 + 1):
        for x in range(rx0, rx1 + 1):
            ground.append((x, y, T_INDOOR_FLOOR))
ground_cells = dedupe(ground)

# ================================================================ GroundDeco
deco = []
deco += rect(12, 9, 13, 44, T_ROAD)      # W街
deco += rect(12, 8, 45, 9, T_ROAD)       # 北街
deco += rect(44, 9, 45, 36, T_ROAD)      # 东街
deco += rect(12, 19, 60, 20, T_ROAD)     # 市场街（col46-60 即草甸小径）
deco += rect(12, 36, 53, 37, T_ROAD)     # 南街
deco += rect(27, 9, 28, 23, T_ROAD)      # 中轴巷北段
deco += rect(27, 33, 28, 36, T_ROAD)     # 中轴巷南段
deco += rect(22, 24, 33, 32, T_PLAZA)    # 广场（灰石砖）
deco += rect(14, 27, 21, 28, T_ROAD)     # 广场西通道
deco += rect(34, 27, 43, 28, T_ROAD)     # 广场东通道
# 南门铺路 (12,46)-(13,47)
deco += rect(12, 46, 13, 47, T_ROAD)
# 室内A 地毯 (84,15)-(87,16)
for x in range(84, 88, 2):
    for y in range(15, 17):
        deco.append((x, y, T_CARPET_A))
        deco.append((x + 1, y, T_CARPET_B))
deco_cells = dedupe(deco)

# ================================================================ WallsObjects
walls = []

# --- 边框树墙（0/47 行、0/63 列），南门 (12,47)-(13,47) 开口
for x in range(64):
    if (x, 47) not in [(12, 47), (13, 47)]:
        walls.append((x, 0, T_TREE_TRUNK))
        walls.append((x, 47, T_TREE_TRUNK))
for y in range(48):
    walls.append((0, y, T_TREE_TRUNK))
    walls.append((63, y, T_TREE_TRUNK))
# 南门栅栏 (12,46)-(13,46)（挂碰撞封路）
walls.append((12, 46, T_FENCE))
walls.append((13, 46, T_FENCE))

# --- 建筑（顶 2 行→Above 屋顶；立面 3 行→WallsObjects 墙）
buildings = [
    # (name, x0, y0, x1, y1, door_x or None, door_y)
    ("B1_inn",    26, 13, 33, 17, 29, 17),
    ("B2_houseA", 10, 13, 15, 17, 12, 17),
    ("B3_houseB", 17, 13, 22, 17, None, None),
    ("B4_smith",  42, 13, 47, 17, None, None),
    ("B5_houseC", 50, 13, 55, 17, None, None),
    ("B7_grocer", 10, 29, 15, 33, None, None),
    ("B8_houseE", 18, 30, 23, 34, None, None),
    ("B9_houseF", 42, 26, 47, 30, None, None),
    ("B10_wh",    50, 29, 55, 33, None, None),
]
above = []
for (name, x0, y0, x1, y1, dx, dy) in buildings:
    for y in range(y0, y0 + 2):                      # 屋顶 2 行
        for x in range(x0, x1 + 1):
            above.append((x, y, T_ROOF_TOP if y == y0 else T_ROOF_MID))
    above.append((x1, y0, T_CHIMNEY))                # 烟囱（右上角）
    for y in range(y1 - 2, y1 + 1):                  # 立面 3 行
        for x in range(x0, x1 + 1):
            walls.append((x, y, [T_WALL_A, T_WALL_B, T_WALL_C][(x + y) % 3]))
    mid_y = y1 - 1
    for x in range(x0 + 1, x1, 3):                   # 窗（中行每 3 格）
        if x != dx:
            walls.append((x, mid_y, T_WINDOW if x % 2 else T_WINDOW_B))
    if dx is not None:                               # 门洞格（无碰撞）
        walls.append((dx, dy, T_DOOR))

# --- 神殿 B6 (28,3)-(35,7)：town 通用石造件拼装（裁量点：不用 temple 备用图集）
for y in range(3, 5):
    for x in range(28, 36):
        above.append((x, y, T_ROOF_TOP if y == 3 else T_ROOF_MID))
above.append((35, 3, T_CHIMNEY))
for y in range(5, 8):
    for x in range(28, 36):
        walls.append((x, y, [T_STONE_L, T_STONE_M, T_STONE_R][(x + y) % 3]))
walls.append((31, 7, T_STONE_D))       # 封印门格（挂碰撞，调查②交互位 (31,8)）
walls.append((29, 5, T_WINDOW))  # 石窗
walls.append((33, 5, T_WINDOW))

# --- 喷泉 (27,27)-(28,28) 2×2 满格碰撞
for (ox, oy), t in T_FOUNTAIN.items():
    walls.append((27 + ox, 27 + oy, t))

# --- 草甸树丛（(tx,ty)=树冠位，树干在 ty+1；末两棵=宝箱凹位：树干 (58,21)/(60,21)）
meadow_trees = [(46, 21), (49, 22), (53, 20), (57, 19), (61, 22), (47, 26), (52, 27),
                (56, 28), (60, 28), (48, 30), (54, 31), (58, 20), (60, 20)]
for (tx, ty) in meadow_trees:
    walls.append((tx, ty + 1, T_TREE_TRUNK))
    above.append((tx, ty, T_TREE_CANOPY_L))
    above.append((tx + 1, ty, T_TREE_CANOPY_R))

# 草甸水井④ (56,24)、柴堆⑤ (60,27)、宝箱 (59,22)
walls.append((56, 24, T_WELL))
walls.append((60, 27, T_CRATE))
walls.append((59, 22, T_CHEST))
# 客栈招牌③ (31,18)（门东一格）
walls.append((31, 18, T_SIGN))
# 广场/南街/四角灌木点缀
walls += [(24, 25, T_SHRUB), (31, 25, T_SHRUB), (24, 31, T_SHRUB), (31, 31, T_SHRUB)]
walls += [(20, 38, T_SHRUB), (36, 39, T_SHRUB)]
walls += [(2, 2, T_SHRUB), (61, 2, T_SHRUB), (2, 44, T_SHRUB), (61, 44, T_SHRUB)]

# ================================================================ 室内两间
INN = (80, 11, 91, 19)
HOUSE = (80, 23, 91, 31)
for (ix0, iy0, ix1, iy1) in [INN, HOUSE]:
    for x in range(ix0, ix1 + 1):
        walls.append((x, iy0, T_WALL_A))
        walls.append((x, iy1, T_WALL_B))
    for y in range(iy0 + 1, iy1):
        walls.append((ix0, y, T_WALL_A))
        walls.append((ix1, y, T_WALL_B))
# 门洞（南墙开洞，无碰撞）：室内A (85,19)、室内B (85,31)
walls = [c for c in walls if (c[0], c[1]) not in [(85, 19), (85, 31)]]
walls.append((85, 19, T_DOOR))
walls.append((85, 31, T_DOOR))
# 室内A 陈设（3.6）
walls += [
    (81, 13, T_TABLE), (82, 13, T_TABLE), (83, 13, T_TABLE), (84, 13, T_TABLE),  # 柜台
    (86, 15, T_TABLE), (88, 14, T_TABLE),                                        # 桌×2
    (81, 12, T_FIREPLACE),                                                       # 炉火占位
    (89, 12, T_SAVEPOINT),                                                       # 存档占位
    (90, 18, T_STAIRS),                                                          # 楼梯占位
]
# 室内B 陈设：床 (81,24)-(81,25)、书架 (89,24)、桌 (85,27)
walls += [(81, 24, T_BED_A), (81, 25, T_BED_B), (89, 24, T_BOOKSHELF), (85, 27, T_TABLE)]

walls_cells = dedupe(walls)

# ================================================================ tres 文本
def tile_block(t):
    key = f"{t[1]}:{t[2]}"
    return [f"{key}/0/physics_layer_0/polygon_0/points = PackedVector2Array({box_full()})",
            f"{key}/0/y_sort_origin = 8"]


def plain_tile_lines(cols, rows):
    return [f"{x}:{y}/0 = 0" for y in range(rows) for x in range(cols)]


tres = []
tres.append('[gd_resource type="TileSet" load_steps=5 format=3]')
tres.append('')
tres.append('[ext_resource type="Texture2D" path="res://assets/tiles/town_tiles.png" id="1_town"]')
tres.append('[ext_resource type="Texture2D" path="res://assets/tiles/forest_tiles.png" id="2_forest"]')
tres.append('')
tres.append('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_town"]')
tres.append('texture = ExtResource("1_town")')
tres.append('texture_region_size = Vector2i(16, 16)')
tres += plain_tile_lines(32, 32)
tres.append('')
# town 图集属性行：有碰撞的 tile（Wall 集 ∪ Deco 无碰撞仅声明）
town_walls = sorted({t for t in WALL_TILES if t[0] == 0})
for t in town_walls:
    tres += tile_block(t)
tres.append('')
tres.append('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_forest"]')
tres.append('texture = ExtResource("2_forest")')
tres.append('texture_region_size = Vector2i(16, 16)')
tres += plain_tile_lines(15, 10)
tres.append('')
forest_walls = sorted({t for t in WALL_TILES if t[0] == 1})
for t in forest_walls:
    tres += tile_block(t)
tres.append('')
tres.append('[resource]')
tres.append('tile_size = Vector2i(16, 16)')
tres.append('physics_layer_0/collision_layer = 1')
tres.append('physics_layer_0/collision_mask = 0')
tres.append('sources/0 = SubResource("TileSetAtlasSource_town")')
tres.append('sources/1 = SubResource("TileSetAtlasSource_forest")')
TRES_TEXT = "\n".join(tres) + "\n"

# ================================================================ tscn 文本
def layer_node(name, z, cells, y_sort=False):
    lines = [f'[node name="{name}" type="TileMapLayer" parent="."]',
             'tile_set = ExtResource("3_tileset")',
             f'z_index = {z}']
    if y_sort:
        lines.append('y_sort_enabled = true')
    lines.append(f'tile_map_data = PackedByteArray({packed_text(cells)})')
    return lines


NPCS = [
    ("npc_01_innkeeper", 30, 18), ("npc_02_traveler", 85, 15),
    ("npc_03_chase_kid", 23, 30), ("npc_04_guard", 31, 27),
    ("npc_05_smith", 44, 18), ("npc_06_peddler", 14, 20),
    ("npc_07_priest", 24, 9), ("npc_08_prayer_woman", 32, 8),
    ("npc_09_shepherd", 52, 18), ("npc_10_housewife", 16, 35),
    ("npc_11_porter", 50, 34), ("npc_12_elder", 12, 24),
]
TRIGGERS = [
    ("Door_Inn", 29, 18), ("Door_HouseA", 12, 18),
    ("Inn_Exit", 85, 18), ("HouseA_Exit", 85, 30),
]

tscn = []
tscn.append('[gd_scene load_steps=5 format=3]')
tscn.append('')
tscn.append('[ext_resource type="Script" path="res://scripts/maps/town_map.gd" id="1_mapgd"]')
tscn.append('[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="2_player"]')
tscn.append('[ext_resource type="TileSet" path="res://assets/tiles/town_map_tileset.tres" id="3_tileset"]')
tscn.append('')
tscn.append('[sub_resource type="RectangleShape2D" id="RectangleShape2D_door"]')
tscn.append('size = Vector2(16, 16)')
tscn.append('')
tscn.append('[node name="Map_Town" type="Node2D"]')
tscn.append('script = ExtResource("1_mapgd")')
tscn.append('')
tscn += ['[node name="VoidBackdrop_A" type="Polygon2D" parent="."]',
         'z_index = -20',
         'color = Color(0, 0, 0, 1)',
         'polygon = PackedVector2Array(1056, 0, 1696, 0, 1696, 360, 1056, 360)',
         '']
tscn += ['[node name="VoidBackdrop_B" type="Polygon2D" parent="."]',
         'z_index = -20',
         'color = Color(0, 0, 0, 1)',
         'polygon = PackedVector2Array(1056, 188, 1696, 188, 1696, 548, 1056, 548)',
         '']
tscn += layer_node("Ground", -10, ground_cells)
tscn.append('')
tscn += layer_node("GroundDeco", -9, deco_cells)
tscn.append('')
tscn += ['[node name="YSorted" type="Node2D" parent="."]',
         'y_sort_enabled = true',
         '']
tscn += layer_node("WallsObjects", 0, walls_cells, y_sort=True)
tscn.append('')
tscn += layer_node("Above", 10, above)
tscn.append('')
tscn += ['[node name="Triggers" type="Node2D" parent="."]', '']
tscn += ['[node name="NPC_Anchors" type="Node2D" parent="YSorted"]', '']
for (nm, tx, ty) in NPCS:
    tscn += [f'[node name="{nm}" type="Marker2D" parent="YSorted/NPC_Anchors"]',
             f'position = Vector2({tx * 16 + 8}, {ty * 16 + 8})',
             '']
tscn += ['[node name="Chest_town_01" type="Marker2D" parent="YSorted"]',
         f'position = Vector2({59 * 16 + 8}, {22 * 16 + 8})',
         '']
tscn += ['[node name="Player" parent="YSorted" instance=ExtResource("2_player")]',
         'position = Vector2(192, 640)',   # 施工单 3.5：出生 tile (12,40) = (192,640)，脚底原点
         '']
for (nm, tx, ty) in TRIGGERS:
    cx, cy = tx * 16 + 8, ty * 16 + 8
    tscn += [f'[node name="{nm}" type="Area2D" parent="Triggers"]',
             'collision_mask = 1',
             f'position = Vector2({cx}, {cy})',
             '']
    tscn += [f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Triggers/{nm}"]',
             'shape = SubResource("RectangleShape2D_door")',
             '']
TSCN_TEXT = "\n".join(tscn) + "\n"

with open(r"D:\code\cordit\assets\tiles\town_map_tileset.tres", "w", encoding="utf-8", newline="\n") as f:
    f.write(TRES_TEXT)
with open(r"D:\code\cordit\scenes\maps\town.tscn", "w", encoding="utf-8", newline="\n") as f:
    f.write(TSCN_TEXT)

print("tileset tres:", len(TRES_TEXT), "chars")
print("town tscn:", len(TSCN_TEXT), "chars")
print("cells  ground:", len(ground_cells), "| deco:", len(deco_cells),
      "| walls:", len(walls_cells), "| above:", len(above))
print("wall-tile types:", len(WALL_TILES), "| door tiles:", len(DOOR_TILES))
