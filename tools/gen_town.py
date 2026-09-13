# -*- coding: utf-8 -*-
"""
gen_town.py — E1-S5 小镇白盒地图程序化生成器（定稿版）
依据：design/gdd/e1-s5-town-build-sheet.md（唯一施工依据）
产物：
  assets/tiles/town_map_tileset.tres   共享 TileSet（town + forest + temple + oga 四图集）
  scenes/maps/town.tscn                五层节点树 + tile_map_data + 摆位 + 门 trigger

tile_map_data 格式（Godot 4.x TileMapLayer）：
  u16 版本号(=0) + N×12 字节 cell：
  i16 x | i16 y | u16 source_id | u16 atlas_x | u16 atlas_y | u16 alternative_tile
  全部小端。

tile 选型依据 production/tile_ascii.py 像素像画辨认（详见回传"选型裁量点"）。
本文件为一次性施工工具，位于 production/（工作缓存，不随本次 git 提交）。

【M7-A2 增量（2026-09-08）】占位件替换 + 装饰密度提升（2.5D 视觉升级 A2 档）：
  1. 壁炉/存档点退役深棕柜占位：T_FIREPLACE → temple (2,0,0) 暖红玛瑙纹理柱
     （配 A1 InnFireplace 橙光 flicker = 燃炉观感）；T_SAVEPOINT → oga (6,4)
     灰白祭坛+蓝晶石（配 A1 InnSavepoint 蓝白光 = 存档水晶）。两 png 均已
     在库（classical_temple_tiles.png 遗迹在用 / 16oga.png CC-BY 4.0 已登记
     A 区），零新图片文件。
  2. GroundDeco 装饰铺设段：16oga 透明件叠草地合成（灌木/草簇/花/碎石），
     固定种子 random.Random(0x4D374132) 确定性散布——重跑逐字节一致，
     verify_town.py §7 断言依赖。避让：内容点位 7 / 传送门 4 / NPC 12 /
     出生区 3×3 / 南门通道，另避 walls 占格与既有路毯。
"""
import os
import random
import struct

# 仓库根目录 = 本脚本所在 tools/ 的上一级（仓库相对路径，替代原硬编码 D:\code\cordit）
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------- 选型表（冻结）
# source_id: 0 = town_tiles, 1 = forest_tiles, 2 = temple(遗迹神殿图集),
#            3 = oga(16oga 透明装饰件集)；值 = (source, atlas_x, atlas_y)
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
# 【M7-A2 替换】原 T_FIREPLACE/T_SAVEPOINT 备案 =(0,16,12) 深棕柜占位（回传
# 报备在案），退役。替代件 tile_ascii.py 像素像画辨认（tools/tile-inspect/
# scan_candidates.py 色系统计定位 → ASCII 像画确认）：
#   T_FIREPLACE = temple (2,0)：满格暖红玛瑙纹理（scan R=206/256、ASCII 全幅
#     红/棕/白纹理无外形轮廓）→ 单格红纹柱贴室内墙，A1 InnFireplace 橙光
#     flicker 叠加 = 燃炉/火钵观感。town/forest 全图集扫描无独立火焰件
#     （town 红区 (20-31,6-11) 为斜屋顶面、(26-29,24-27) 为红瓦坡、(8-11,13)
#     为大型斜屋——均非壁炉，全图集扫描报备）。
#   T_SAVEPOINT = oga (6,4)：灰白祭坛 + 中央蓝晶石（ASCII：梯形祭坛 K/W 描边
#     + 中央 U 晶簇），正中存档水晶意象；A1 InnSavepoint 蓝白光叠加自洽。
T_FIREPLACE = (2, 2, 0)    # temple 暖红玛瑙纹理柱（燃炉意象，配 A1 炉火橙光）
T_SAVEPOINT = (3, 6, 4)    # oga 祭坛蓝晶石（存档水晶意象，配 A1 存档蓝白光）
T_CHEST = (0, 26, 22)    # 宝箱（木箱件，挂碰撞）
T_INDOOR_FLOOR = (0, 18, 0)  # 木板地板（室内 Ground）
T_FENCE = (0, 22, 10)    # 栅栏（灰石件；E4-S6/R1 起南门不封路，选型保留备用）

# 【M7-A2】16oga 透明装饰件（GroundDeco 层叠草地合成；ASCII 辨认）：
#   (5,1)(6,1)(7,1) 灌木圆冠（深绿描边+浅绿高光，透明底）、(5,4) 草簇（散叶
#   玫瑰形小丛）、(6,3)(7,3) 花（红/黄小花盘）、(6,2) 小石堆（灰石+白高光）。
#   全部不挂碰撞（草面杂物，walkable）；GroundDeco z=-9 高于 Ground 草地。
D_BUSH_A = (3, 5, 1)     # oga 灌木 A（圆冠密）
D_BUSH_B = (3, 6, 1)     # oga 灌木 B（圆冠疏）
D_BUSH_C = (3, 7, 1)     # oga 灌木 C（圆冠宽）
D_GRASS_TUFT = (3, 5, 4)  # oga 草簇
D_FLOWER_R = (3, 6, 3)   # oga 红花
D_FLOWER_Y = (3, 7, 3)   # oga 黄花
D_STONES = (3, 6, 2)     # oga 小石堆
DECO_FLORA = [D_BUSH_A, D_BUSH_B, D_BUSH_C, D_GRASS_TUFT, D_FLOWER_R, D_FLOWER_Y]  # 随机池（石堆不进随机池，成丛专用）

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

# 【M7-A2】装饰避让坐标集（GroundDeco 装饰不许落的格；集合构建顺序须在
# NPCS/TRIGGERS 定义之前——用字面量直书，与下方表互为镜像，verify §7 对表）。
# ① 内容点位 7：宝箱 (59,22) + 调查点 6（point_catalog.gd town 节）
# ② 传送门 4（门格 + 出口格；TRIGGERS 同位）
# ③ NPC 锚点 12（NPCS 表镜像）
# ④ 玩家出生区 3×3：(12,40) 周边（出生格 ±1，开局 P0 锚点重叠同格）
# ⑤ 南门通道 (12-13,45-47)（铺路 + 边框开口）
AVOID_DECO = {
    (59, 22),
    (25, 26), (30, 10), (20, 33), (39, 16), (44, 30), (16, 22),
    (29, 18), (12, 18), (85, 18), (85, 30),
    (30, 18), (85, 15), (23, 30), (31, 27), (44, 18), (14, 20),
    (24, 9), (32, 8), (52, 18), (16, 35), (50, 34), (12, 24),
    (11, 39), (12, 39), (13, 39), (11, 40), (12, 40), (13, 40),
    (11, 41), (12, 41), (13, 41),
    (12, 45), (13, 45), (12, 46), (13, 46), (12, 47), (13, 47),
}


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
# 【M7-A2】装饰铺设段在 Walls 段之后执行（需引用 buildings 表与 walls 已收
# 格做硬排除；单源无镜像——见 "M7-A2 装饰铺设" 一节）

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
# 【E4-S6/R1】南门栅栏拆除：原 (12,46)(13,46) 施工期占位封路已裁撤（E4-S6
# 传送网络接线，南门须通行；verify_town.py L125 断言同步改为"无栅栏"）。
# 通道 = 铺路 (12,46)-(13,47) + 边框开口 (12,47)(13,47)。

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
# 【M7-A2】(81,12)/(89,12) 选型替换：T_FIREPLACE=temple 红纹柱（燃炉）、
# T_SAVEPOINT=oga 祭坛蓝晶（存档水晶）——选型依据见选型表 M7-A2 注。
walls += [
    (81, 13, T_TABLE), (82, 13, T_TABLE), (83, 13, T_TABLE), (84, 13, T_TABLE),  # 柜台
    (86, 15, T_TABLE), (88, 14, T_TABLE),                                        # 桌×2
    (81, 12, T_FIREPLACE),                                                       # 炉火（红纹柱+橙光）
    (89, 12, T_SAVEPOINT),                                                       # 存档水晶（祭坛蓝晶+蓝白光）
    (90, 18, T_STAIRS),                                                          # 楼梯占位
]
# 室内B 陈设：床 (81,24)-(81,25)、书架 (89,24)、桌 (85,27)
walls += [(81, 24, T_BED_A), (81, 25, T_BED_B), (89, 24, T_BOOKSHELF), (85, 27, T_TABLE)]

walls_cells = dedupe(walls)

# ================================================================ 【M7-A2】装饰铺设
# 16oga 透明件叠草地（GroundDeco 层 z=-9 高于 Ground），固定种子确定性散布
# ——禁真随机，重跑逐字节一致（verify §7 断言依赖）。密度锚点：草甸区、
# 建筑间隙、南门外通道两侧；总格数 40-80 档。排除集：AVOID_DECO（内容点位
# 7/传送门 4/NPC 12/出生区 3×3/南门通道）+ 主图外 + 已有路毯 + walls 占格 +
# 建筑/神殿/树/点景占地（墙脚外圈 1 格留步道）。
rng = random.Random(0x4D374132)  # 固定种子（"M7A2" hex），逐字节确定性
_taken = {(x, y) for (x, y, _t) in deco_cells}          # 既有路毯/地毯格
# 建筑占地（屋顶 2 行 + 立面 3 行，含烟囱位）
_building_fp = set()
for (_bn, x0, y0, x1, y1, _dx, _dy) in buildings:
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            _building_fp.add((xx, yy))
_temple_fp = {(x, y) for x in range(28, 36) for y in range(3, 8)}
_tree_fp = set()   # 草甸树：树冠 2×1 在 ty 行 + 树干在 ty+1 行
for (tx, ty) in meadow_trees:
    _tree_fp.add((tx, ty))
    _tree_fp.add((tx + 1, ty))
    _tree_fp.add((tx, ty + 1))
_landmark_fp = {(56, 24), (60, 27), (59, 22), (31, 18),          # 井/柴堆/宝箱/招牌
                (24, 25), (31, 25), (24, 31), (31, 31),          # 广场灌木
                (20, 38), (36, 39), (2, 2), (61, 2), (2, 44), (61, 44)}  # 四角灌木
_walls_fp = {(x, y) for (x, y, _t) in walls_cells}               # 边框树墙等全部占格
_excluded = AVOID_DECO | _taken | _building_fp | _temple_fp | _tree_fp | _landmark_fp | _walls_fp


def _deco_ok(x, y):
    """装饰可落格判定：主图内、非避让集、建筑墙脚外圈 1 格不落（防糊墙线）"""
    if not (1 <= x <= 62 and 1 <= y <= 46):
        return False
    if (x, y) in _excluded:
        return False
    if any((x + dx, y + dy) in _building_fp for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
        return False
    return True


_deco_spots = []   # [(x, y, tile)]
# 锚点区 A：草甸区（市场街东段两侧，col 46-60、row 21-33，跳过树/点景）
for _y in range(21, 34):
    for _x in range(46, 61):
        if _deco_ok(_x, _y) and rng.random() < 0.16:
            _deco_spots.append((_x, _y, DECO_FLORA[rng.randrange(len(DECO_FLORA))]))
# 锚点区 B：建筑间隙走廊带（西民居群/南街南带/东民居群/东南草坡）
for (_x0, _y0, _x1, _y1, _p) in [(16, 19, 26, 28, 0.10), (24, 34, 42, 42, 0.08),
                                  (42, 19, 49, 25, 0.10), (56, 30, 61, 38, 0.08)]:
    for _y in range(_y0, _y1 + 1):
        for _x in range(_x0, _x1 + 1):
            if _deco_ok(_x, _y) and rng.random() < _p:
                _deco_spots.append((_x, _y, DECO_FLORA[rng.randrange(len(DECO_FLORA))]))
# 锚点区 C：南门外通道两侧（col 9-16 / row 41-46，入口迎宾密一些）
for _y in range(41, 47):
    for _x in range(9, 17):
        if _deco_ok(_x, _y) and rng.random() < 0.20:
            _deco_spots.append((_x, _y, DECO_FLORA[rng.randrange(len(DECO_FLORA))]))
# 2×2 丛簇 3 处（灌木+草簇+花拼角；坐标定死不走随机——verify §7 抽验锚点）
for (_cx, _cy) in [(18, 24), (50, 23), (37, 40)]:
    _patch = [(0, 0, D_BUSH_A), (1, 0, D_GRASS_TUFT), (0, 1, D_FLOWER_Y), (1, 1, D_BUSH_C)]
    for (ox, oy, t) in _patch:
        if _deco_ok(_cx + ox, _cy + oy):
            _deco_spots.append((_cx + ox, _cy + oy, t))
# 石堆点缀 4 处（井旁/南门旁/广场西口外/草甸小径边——固定坐标，非随机；
# 均为草地格，不落路毯/广场内，不在建筑墙脚外圈）
for (_sx, _sy) in [(55, 25), (14, 44), (17, 25), (51, 21)]:
    if _deco_ok(_sx, _sy):
        _deco_spots.append((_sx, _sy, D_STONES))
deco += _deco_spots
deco_cells = dedupe(deco)

# ================================================================ tres 文本
def tile_block(t):
    key = f"{t[1]}:{t[2]}"
    return [f"{key}/0/physics_layer_0/polygon_0/points = PackedVector2Array({box_full()})",
            f"{key}/0/y_sort_origin = 8"]


def plain_tile_lines(cols, rows):
    return [f"{x}:{y}/0 = 0" for y in range(rows) for x in range(cols)]


tres = []
# M7-A2：4 ext_resource + 4 sub_resource + 1 resource = load_steps 9
tres.append('[gd_resource type="TileSet" load_steps=9 format=3]')
tres.append('')
tres.append('[ext_resource type="Texture2D" path="res://assets/tiles/town_tiles.png" id="1_town"]')
tres.append('[ext_resource type="Texture2D" path="res://assets/tiles/forest_tiles.png" id="2_forest"]')
tres.append('[ext_resource type="Texture2D" path="res://assets/tiles/classical_temple_tiles.png" id="3_temple"]')
tres.append('[ext_resource type="Texture2D" path="res://assets/tiles/16oga.png" id="4_oga"]')
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
# M7-A2：temple 图集接入（64×48 网格；仅壁炉 (2,0) 挂碰撞+y_sort，余全平声明）
tres.append('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_temple"]')
tres.append('texture = ExtResource("3_temple")')
tres.append('texture_region_size = Vector2i(16, 16)')
tres += plain_tile_lines(64, 48)
tres.append('')
temple_walls = sorted({t for t in WALL_TILES if t[0] == 2})
for t in temple_walls:
    tres += tile_block(t)
tres.append('')
# M7-A2：oga 图集接入（10×5 网格；仅存档点 (6,4) 挂碰撞+y_sort，装饰件全平声明）
tres.append('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_oga"]')
tres.append('texture = ExtResource("4_oga")')
tres.append('texture_region_size = Vector2i(16, 16)')
tres += plain_tile_lines(10, 5)
tres.append('')
oga_walls = sorted({t for t in WALL_TILES if t[0] == 3})
for t in oga_walls:
    tres += tile_block(t)
tres.append('')
tres.append('[resource]')
tres.append('tile_size = Vector2i(16, 16)')
tres.append('physics_layer_0/collision_layer = 1')
tres.append('physics_layer_0/collision_mask = 0')
tres.append('sources/0 = SubResource("TileSetAtlasSource_town")')
tres.append('sources/1 = SubResource("TileSetAtlasSource_forest")')
tres.append('sources/2 = SubResource("TileSetAtlasSource_temple")')
tres.append('sources/3 = SubResource("TileSetAtlasSource_oga")')
TRES_TEXT = "\n".join(tres) + "\n"

# ================================================================ tscn 文本
def layer_node(name, z, cells, y_sort=False, parent="."):
    # 【M8-A③】新增 parent 参数：WallsObjects 归位 YSorted 子树。
    # y-sort 生效充要条件（ADR A6 / 施工单 293）：父节点 y_sort_enabled=true 且
    # 所有参与排序的节点（含 WallsObjects 的每个 tile）在**同一父节点**下。
    # 其余层（Ground/GroundDeco/Above）不参与 y-sort，仍挂根（parent="."）。
    lines = [f'[node name="{name}" type="TileMapLayer" parent="{parent}"]',
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
tscn += layer_node("WallsObjects", 0, walls_cells, y_sort=True, parent="YSorted")
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
# T6.5 P0 开局锚点（M7-A2 回补：1e3c984 曾手改进 tscn 而生成器未收编，重生成
# 即丢 → test_t65 D2/D4 断裂。坐标 = 出生 tile (12,40) 脚底原点，与 Player 同位
# ——出生即物理重叠，body_entered 首物理帧开演 P0）
tscn += ['[node name="P0_Anchor" type="Marker2D" parent="YSorted"]',
         'position = Vector2(192, 640)',
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

# 输出路径改为仓库相对路径（E4-S0 修复：不再写死 D:\code\cordit）
with open(os.path.join(REPO_ROOT, "assets", "tiles", "town_map_tileset.tres"), "w", encoding="utf-8", newline="\n") as f:
    f.write(TRES_TEXT)
with open(os.path.join(REPO_ROOT, "scenes", "maps", "town.tscn"), "w", encoding="utf-8", newline="\n") as f:
    f.write(TSCN_TEXT)

print("tileset tres:", len(TRES_TEXT), "chars")
print("town tscn:", len(TSCN_TEXT), "chars")
print("cells  ground:", len(ground_cells), "| deco:", len(deco_cells),
      "| walls:", len(walls_cells), "| above:", len(above))
print("wall-tile types:", len(WALL_TILES), "| door tiles:", len(DOOR_TILES))
