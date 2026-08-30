# -*- coding: utf-8 -*-
"""
gen_ruins.py — E4-S3 遗迹三层地图程序化生成器（克隆 gen_road.py 模板）
依据：探索 GDD §3.1 三层行（f1 56×44 / f2 48×48 / f3 40×40、宝箱 3/2/1、调查 4/3/2、
      敌人 B3 巡逻+追击 2 / B4 定守精英 1 / f3 零普通敌人）+ §3.2（开阔厅+窄走廊）
      + temple-tileset-selection.md（classical_temple_tiles 单图集，冻结选型）
      + 冻结约束：不设回复点（f1 入口预留 2×2 空地）；f3 Boss 前厅；传送不接线（E4-S6）
产物：scenes/maps/ruins_f1.tscn / ruins_f2.tscn / ruins_f3.tscn（TileSet = assets/tiles/ruins_tileset.tres）

tile_map_data 格式（Godot 4.x TileMapLayer，与 gen_road 相同）：
  u16 版本号(=0) + N×12 字节 cell：i16 x | i16 y | u16 source_id | u16 atlas_x | u16 atlas_y | u16 alternative_tile，全部小端。

结构模板（三层同构：围合式房间 + 偏移门洞，服务"开阔厅+窄走廊"与"甩掉敌人"）：
  f1  南门 → 前厅（入口 2×2 空地预留）→ 开阔大厅（柱廊+神像，B3×2 巡逻）→ 北侧窄廊 → 楼梯厅 → 北口
  f2  南门 → 南走廊 → 中央大厅（四角柱围合，B4 精英定守正中=交战位）→ 北窄廊 → 楼梯厅 → 北口
  f3  南门 → 前厅 → 石棺祭坛（Boss 触发锚点，零敌人）→ 灰石 Boss 门（封死构图）
  纵向推进暗示：三层同构"南入北出" + 面积递减 + f3 灰石/石棺收尾。
  密度自查锚（BFS 最短路径必经点位，由 verify_ruins 复核）：f1 西凹室箱 → 大厅 → 东环宝箱；
  f2 西环廊箱 → 大厅 → 东环调查；f3 前厅调查 → 石棺 → 门前箱。
  宝箱图集无箱形 tile（选型表未含，全图扫描确认）→ 本 Story 只放 Marker2D 锚点，视觉归 E4-S5。
"""
import os
import struct

# 仓库根目录 = 本脚本所在 tools/ 的上一级（gen_road 同款仓库相对路径方案）
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------- 选型表（temple-tileset-selection.md 冻结选型）
# 单图集：source_id 恒 0（classical_temple_tiles）；值 = (source, atlas_x, atlas_y)
T_FLOOR = (0, 27, 22)       # 棕砖平铺（主地面）
T_FLOOR_B = (0, 28, 22)     # 地面变体：裂纹
T_FLOOR_C = (0, 29, 22)     # 地面变体：散石
T_FLOOR_D = (0, 30, 22)     # 地面变体：缺角
T_MOSAIC = (0, 27, 23)      # 嵌入方砖装饰带（主路径提示带）
T_MOSAIC2 = (0, 29, 23)     # 嵌入方砖装饰带变体（楼梯口）
T_WALL = (0, 27, 8)         # B 砖墙（挂碰撞）
T_WALL_K = (0, 40, 8)       # K 灰石墙（挂碰撞，f3/Boss 房外围）
T_PILLAR_B = (0, 11, 16)    # 竖纹墙柱（挂碰撞）
T_SARC_L = (0, 9, 16)       # 石棺左半（挂碰撞）
T_SARC_R = (0, 10, 16)      # 石棺右半（挂碰撞）
T_DOORFRAME = (0, 22, 10)   # 拱门框上段（挂碰撞）
T_DOORFRAME2 = (0, 22, 11)  # 拱门框下段（挂碰撞，Above 层悬示）
T_RUBBLE = (0, 14, 29)      # 碎石堆（透明贴片，挂碰撞）
T_RUBBLE2 = (0, 15, 29)     # 碎石堆变体（挂碰撞）
T_GRASS = (0, 4, 6)         # 草丛贴片（无碰撞，破损点缀）
T_GRASS2 = (0, 5, 6)        # 草丛贴片变体
T_PILLAR_TOP = (0, 39, 44)  # 标准柱柱头（透明贴片，无碰撞）
T_PILLAR_MID = (0, 39, 45)  # 标准柱柱身（透明贴片，无碰撞）
T_PILLAR_BOT = (0, 39, 46)  # 标准柱底座（挂碰撞）
T_PILLAR_TOP2 = (0, 57, 44) # 柱变体柱头
T_PILLAR_MID2 = (0, 57, 45) # 柱变体柱身
T_PILLAR_BOT2 = (0, 57, 46) # 柱变体底座（挂碰撞）
T_STATUE_TL = (0, 14, 24)   # 神像左上（透明贴片）
T_STATUE_TR = (0, 15, 24)   # 神像右上
T_STATUE_ML = (0, 14, 25)   # 神像左中
T_STATUE_MR = (0, 15, 25)   # 神像右中
T_STATUE_BL = (0, 14, 26)   # 神像左下（挂碰撞）
T_STATUE_BR = (0, 15, 26)   # 神像右下（挂碰撞）
T_STATUE_FL = (0, 14, 27)   # 神像左座（挂碰撞）
T_STATUE_FR = (0, 15, 27)   # 神像右座（挂碰撞）
T_STONE_BIG = (0, 52, 34)   # 灰石大块（挂碰撞，Boss 门暗示）
T_STONE_BIG2 = (0, 53, 34)  # 灰石大块变体（挂碰撞）

# 本图 Walls 层用到的碰撞 tile（均已在 ruins_tileset.tres 声明并挂碰撞）
WALL_TILES = sorted({T_WALL, T_WALL_K, T_PILLAR_B, T_SARC_L, T_SARC_R,
                     T_DOORFRAME, T_DOORFRAME2, T_RUBBLE, T_RUBBLE2,
                     T_PILLAR_BOT, T_PILLAR_BOT2,
                     T_STATUE_BL, T_STATUE_BR, T_STATUE_FL, T_STATUE_FR,
                     T_STONE_BIG, T_STONE_BIG2})

# ---------------------------------------------------------------- tile_map_data 组装（克隆 gen_road）
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


def remove_cells(cells, pred):
    """过滤删除满足条件的 cell"""
    return [c for c in cells if not pred(c)]


# ---------------------------------------------------------------- 共享结构模板
def border(w, h, gates):
    """四面边框墙：gates = {(x,y), ...} 开口格集合"""
    cells = []
    for x in range(w):
        for y in (0, h - 1):
            if (x, y) not in gates:
                cells.append((x, y, T_WALL))
    for y in range(h):
        for x in (0, w - 1):
            if (x, y) not in gates:
                cells.append((x, y, T_WALL))
    return cells


def pillars_col(x, y0, variant=False):
    """单柱 3 格竖排：返回 (柱头, 柱身, 底座) tile 元组；
    柱头/柱身 → Above 装饰层，底座 → Walls 挂碰撞"""
    if variant:
        return (T_PILLAR_TOP2, T_PILLAR_MID2, T_PILLAR_BOT2)
    return (T_PILLAR_TOP, T_PILLAR_MID, T_PILLAR_BOT)


def statue_2x4(x, y0):
    """神像 2×4：上两行装饰层（Above），下两行 Walls 挂碰撞（y_sort 底座）"""
    walls = [(x, y0 + 2, T_STATUE_BL), (x + 1, y0 + 2, T_STATUE_BR),
             (x, y0 + 3, T_STATUE_FL), (x + 1, y0 + 3, T_STATUE_FR)]
    above = [(x, y0, T_STATUE_TL), (x + 1, y0, T_STATUE_TR),
             (x, y0 + 1, T_STATUE_ML), (x + 1, y0 + 1, T_STATUE_MR)]
    return walls, above


def floor_cells(w, h):
    """全图铺地 + 变体混铺（约 15%：r==3 裂纹 / r==7 散石 / r==11 缺角）"""
    cells = []
    for y in range(h):
        for x in range(w):
            r = (x * 7 + y * 13) % 20
            t = T_FLOOR_B if r == 3 else (T_FLOOR_C if r == 7 else (T_FLOOR_D if r == 11 else T_FLOOR))
            cells.append((x, y, t))
    return cells


def wall_ring(x0, y0, x1, y1, doors):
    """矩形房间围合墙（1 格厚）：doors = {(x,y)} 开口集合"""
    cells = []
    for x in range(x0, x1 + 1):
        for y in (y0, y1):
            if (x, y) not in doors:
                cells.append((x, y, T_WALL))
    for y in range(y0, y1 + 1):
        for x in (x0, x1):
            if (x, y) not in doors:
                cells.append((x, y, T_WALL))
    return cells


# ---------------------------------------------------------------- 三层定义
def build_f1():
    """f1 56×44（road 蛇形链配方）：前厅(围合) → 南廊 H1 → 东缘 V2(穿带A) → 开阔大厅(带A-带B 之间)
    → 西缘 V3(穿带B) → 北区走廊 H3 → 楼梯走道 V4 → 北口。
    B3×2 巡逻于大厅开阔区；入口 2×2 空地预留 (27-28,2-3)。"""
    w, h = 56, 44
    south_gate = {(27, 0), (28, 0)}
    north_stair = {(27, h - 1), (28, h - 1)}
    ground = floor_cells(w, h)

    # ---- 主路径链（GroundDeco 方砖提示带）
    deco = []
    reserved = {(27, 2), (28, 2), (27, 3), (28, 3)}  # 入口 2×2 空地预留（回复点冻结"不设"）
    deco += rect(24, 2, 30, 7, T_MOSAIC)        # 前厅地面（预留空地在 §gen 尾部过滤）
    deco += rect(27, 9, 46, 10, T_MOSAIC)       # H1 南廊东行
    deco += rect(45, 11, 46, 24, T_MOSAIC)      # V2 东缘南下
    deco += rect(10, 25, 46, 26, T_MOSAIC)      # H2 大厅主横道西行
    deco += rect(10, 27, 11, 38, T_MOSAIC)      # V3 西缘南下
    deco += rect(10, 39, 30, 40, T_MOSAIC)      # H3 北区走廊东行
    deco += rect(27, 41, 28, h - 2, T_MOSAIC)   # V4 楼梯走道

    # ---- 封堵与围合
    walls = border(w, h, south_gate | north_stair)
    # 前厅围合（x22-33 / y1-8）：南=入口列开口，北=(27,8)(28,8) 通南廊
    walls += wall_ring(22, 1, 33, 8,
                       {(27, 1), (28, 1), (27, 8), (28, 8)} | south_gate)
    # 带A（双行全宽，开口列 x45-46 = V2 通道）
    for dy in (0, 1):
        for x in range(1, w - 1):
            if x not in (45, 46):
                walls.append((x, 16 + dy, T_WALL))
    # 带B（双行全宽，开口列 x10-11 = V3 通道）
    for dy in (0, 1):
        for x in range(1, w - 1):
            if x not in (10, 11):
                walls.append((x, 31 + dy, T_WALL))

    # ---- 大厅构件（开阔区 y18-30）
    walls_p = []
    above = []
    # 柱廊 2×2（变体混排）
    for (px_, py_, va) in [(18, 20, False), (37, 20, True), (18, 27, True), (37, 27, False)]:
        top, mid, bot = pillars_col(px_, py_, va)
        walls_p.append((px_, py_ + 2, bot))
        above += [(px_, py_, top), (px_, py_ + 1, mid)]
    # 神像一对（大厅中部，f1 视觉锚）
    sw1, sa1 = statue_2x4(24, 20)
    sw2, sa2 = statue_2x4(30, 20)
    walls_p += sw1 + sw2
    above += sa1 + sa2
    # 拱门框（前厅北口两侧）
    walls_p += [(26, 8, T_DOORFRAME), (29, 8, T_DOORFRAME)]
    above += [(26, 7, T_DOORFRAME2), (29, 7, T_DOORFRAME2)]
    # 碎石点缀（不可达装饰位/边角，远离链与点位）
    walls_p += [(4, 5, T_RUBBLE), (50, 5, T_RUBBLE2), (4, 13, T_RUBBLE2), (51, 13, T_RUBBLE),
                (16, 36, T_RUBBLE2), (40, 36, T_RUBBLE)]
    above += [(4, 4, T_GRASS), (50, 4, T_GRASS2), (16, 35, T_GRASS)]

    walls = dedupe(walls + walls_p)
    ground = dedupe(ground)
    deco = dedupe([c for c in deco if c[0:2] not in reserved])  # 预留空地无装饰
    above = dedupe(above)

    # 敌人 ×2（B3 巡逻+追击；大厅开阔区双纵队）
    enemies = [
        ("Enemy_ruins_f1_01", 20, 22, "ruins_f1_salamander", "b3_ruin_mix", [80, 0, -80, 0]),
        ("Enemy_ruins_f1_02", 36, 25, "ruins_f1_crystal", "b3_ruin_mix", [0, 80, 0, -80]),
    ]
    # 宝箱 ×3：开阔区西北角(4,20 H2 支线) / 南廊东端(50,9) / 楼梯前廊(24,39)
    chests = [("Chest_ruins_f1_01", 4, 20), ("Chest_ruins_f1_02", 50, 9), ("Chest_ruins_f1_03", 24, 39)]
    # 调查 ×4：前厅内(32,2 出生旁) / H1 南沿(30,11) / 大厅中央神像旁(28,23) / 北区(18,37)
    investigate = [("Investigate_ruins_f1_01", 32, 2), ("Investigate_ruins_f1_02", 30, 11),
                   ("Investigate_ruins_f1_03", 28, 23), ("Investigate_ruins_f1_04", 18, 37)]
    spawn_px = (28 * 16, 3 * 16 + 8)  # from_road：入口预留区中央偏南，参考格 (27.5,3.5)
    return dict(w=w, h=h, ground=ground, deco=deco, walls=walls, above=above,
                enemies=enemies, chests=chests, investigate=investigate,
                boss=None, spawn_px=spawn_px,
                spawn_tile=(27, 3), blockers=[])


def build_f2():
    """f2 48×48（同构蛇形）：前厅围合 → H1 → V2(穿带A) → 大厅（B4 精英定守正中）
    → H2 → V3(穿带B) → 北区走廊 H3 → V4 → 北口"""
    w, h = 48, 48
    south_gate = {(23, 0), (24, 0)}
    north_stair = {(23, h - 1), (24, h - 1)}
    ground = floor_cells(w, h)

    deco = []
    deco += rect(20, 2, 26, 7, T_MOSAIC)        # 前厅地面
    deco += rect(23, 9, 42, 10, T_MOSAIC)       # H1 南廊东行
    deco += rect(41, 11, 42, 25, T_MOSAIC)      # V2 东缘南下
    deco += rect(6, 26, 42, 27, T_MOSAIC)       # H2 大厅主横道西行
    deco += rect(6, 28, 7, 40, T_MOSAIC)        # V3 西缘南下
    deco += rect(6, 41, 24, 42, T_MOSAIC)       # H3 北区走廊东行
    deco += rect(23, 43, 24, h - 2, T_MOSAIC)   # V4 楼梯走道

    walls = border(w, h, south_gate | north_stair)
    # 前厅围合（x19-28 / y1-8）
    walls += wall_ring(19, 1, 28, 8,
                       {(23, 1), (24, 1), (23, 8), (24, 8)} | south_gate)
    # 带A（开口列 x41-42）
    for dy in (0, 1):
        for x in range(1, w - 1):
            if x not in (41, 42):
                walls.append((x, 17 + dy, T_WALL))
    # 带B（开口列 x6-7）
    for dy in (0, 1):
        for x in range(1, w - 1):
            if x not in (6, 7):
                walls.append((x, 33 + dy, T_WALL))

    walls_p = []
    above = []
    # 大厅四角柱（环内），定守精英正中——站位即交战位
    for (px_, py_, va) in [(14, 21, False), (33, 21, True), (14, 28, True), (33, 28, False)]:
        top, mid, bot = pillars_col(px_, py_, va)
        walls_p.append((px_, py_ + 2, bot))
        above += [(px_, py_, top), (px_, py_ + 1, mid)]
    # 拱门框（前厅北口两侧）
    walls_p += [(22, 8, T_DOORFRAME), (25, 8, T_DOORFRAME)]
    above += [(22, 7, T_DOORFRAME2), (25, 7, T_DOORFRAME2)]
    # 碎石点缀
    walls_p += [(4, 5, T_RUBBLE), (43, 5, T_RUBBLE2), (4, 13, T_RUBBLE2), (43, 13, T_RUBBLE),
                (14, 37, T_RUBBLE2), (34, 37, T_RUBBLE)]
    above += [(4, 4, T_GRASS), (43, 4, T_GRASS2), (14, 36, T_GRASS)]

    walls = dedupe(walls + walls_p)
    ground = dedupe(ground)
    deco = dedupe(deco)
    above = dedupe(above)

    # 敌人 ×1（B4 精英定守：空 waypoints = 原地驻守，站位即交战位）
    enemies = [
        ("Enemy_ruins_f2_elite", 23, 24, "ruins_f2_guardian", "b4_guardian", []),
    ]
    # 宝箱 ×2：大厅西北 (8,20) / H2 东段 (38,27)
    chests = [("Chest_ruins_f2_01", 8, 20), ("Chest_ruins_f2_02", 38, 27)]
    # 调查 ×3：前厅内 (21,2) / H1 东段 (38,10) / 北区 (14,41)
    investigate = [("Investigate_ruins_f2_01", 21, 2), ("Investigate_ruins_f2_02", 38, 10),
                   ("Investigate_ruins_f2_03", 14, 41)]
    spawn_px = (24 * 16, 2 * 16 + 8)  # from_f1：入口参考格 (23.5,2.5)
    return dict(w=w, h=h, ground=ground, deco=deco, walls=walls, above=above,
                enemies=enemies, chests=chests, investigate=investigate,
                boss=None, spawn_px=spawn_px,
                spawn_tile=(23, 2), blockers=[])


def build_f3():
    """f3 40×40（同构蛇形，Boss 前厅）：前厅围合 → H1 → V2(穿带A) → 大厅 → H2
    → V3(穿带B) → 祭坛厅（石棺+神像+Boss 触发锚点）→ 灰石 Boss 门（封死构图）。
    零普通敌人；BFS 终点 = 棺前 Boss 锚点。"""
    w, h = 40, 40
    south_gate = {(19, 0), (20, 0)}
    ground = floor_cells(w, h)

    deco = []
    deco += rect(16, 2, 22, 5, T_MOSAIC)        # 前厅地面
    deco += rect(19, 7, 34, 8, T_MOSAIC)        # H1 南廊东行
    deco += rect(33, 9, 34, 22, T_MOSAIC)       # V2 东缘南下
    deco += rect(10, 23, 34, 24, T_MOSAIC)      # H2 大厅主横道西行
    deco += rect(10, 25, 11, 30, T_MOSAIC)      # V3 西缘南下
    deco += rect(11, 31, 19, 32, T_MOSAIC)      # H3 祭坛前廊东行
    deco += rect(18, 33, 21, 34, T_MOSAIC)      # 祭坛前地面

    walls = border(w, h, south_gate)
    # 前厅围合（x15-24 / y1-6）
    walls += wall_ring(15, 1, 24, 6,
                       {(19, 1), (20, 1), (19, 6), (20, 6)} | south_gate)
    # 带A（开口列 x33-34）
    for dy in (0, 1):
        for x in range(1, w - 1):
            if x not in (33, 34):
                walls.append((x, 13 + dy, T_WALL))
    # 带B（开口列 x10-11）
    for dy in (0, 1):
        for x in range(1, w - 1):
            if x not in (10, 11):
                walls.append((x, 27 + dy, T_WALL))

    # ---- Boss 门灰石构图（北缘 y=39 中央 x17-22：灰石墙段 + 灰石大块封死门位）
    walls = remove_cells(walls, lambda c: c[1] == h - 1 and 17 <= c[0] <= 22)
    walls += rect(17, h - 1, 18, h - 1, T_WALL_K) + rect(21, h - 1, 22, h - 1, T_WALL_K)
    walls = dedupe(walls)
    walls += [(19, h - 1, T_STONE_BIG), (20, h - 1, T_STONE_BIG2)]
    walls = dedupe(walls)

    walls_p = []
    above = []
    # 前厅/大厅柱廊对（东西各一）
    for (px_, py_, va) in [(14, 16, False), (25, 16, True)]:
        top, mid, bot = pillars_col(px_, py_, va)
        walls_p.append((px_, py_ + 2, bot))
        above += [(px_, py_, top), (px_, py_ + 1, mid)]
    # 石棺祭坛（2×1，棺前即 Boss 触发锚点 (19-20,35)）——"往深处去"终点
    walls_p += [(19, 36, T_SARC_L), (20, 36, T_SARC_R)]
    # 神像一对（祭坛前两侧，f3 视觉锚）
    sw1, sa1 = statue_2x4(16, 33)
    sw2, sa2 = statue_2x4(22, 33)
    walls_p += sw1 + sw2
    above += sa1 + sa2
    # 拱门框（前厅北口两侧）
    walls_p += [(18, 6, T_DOORFRAME), (21, 6, T_DOORFRAME)]
    above += [(18, 5, T_DOORFRAME2), (21, 5, T_DOORFRAME2)]
    # 碎石点缀
    walls_p += [(4, 4, T_RUBBLE), (35, 4, T_RUBBLE2), (4, 10, T_RUBBLE2), (35, 10, T_RUBBLE),
                (14, 36, T_RUBBLE2), (25, 36, T_RUBBLE)]
    above += [(4, 3, T_GRASS), (35, 3, T_GRASS2)]

    walls = dedupe(walls + walls_p)
    ground = dedupe(ground)
    deco = dedupe(deco)
    above = dedupe(above)

    # 零普通敌人（GDD f3 行"0（Boss 事件触发）"）；Boss 本体由 E5 事件召唤（I5）
    enemies = []
    # 宝箱 ×1：祭坛前东格（补给定位）
    chests = [("Chest_ruins_f3_01", 21, 35)]
    # 调查 ×2：石棺西格 / 大厅西北
    investigate = [("Investigate_ruins_f3_01", 18, 35), ("Investigate_ruins_f3_02", 12, 16)]
    # Boss 触发器锚点（棺前 2 格，交互键触发归 E5 事件；先留数据位）
    boss = [("Boss_ruins_f3_trigger", 19, 35), ("Boss_ruins_f3_trigger", 20, 35)]
    spawn_px = (20 * 16, 2 * 16 + 8)  # from_f2：入口参考格 (19.5,2.5)
    return dict(w=w, h=h, ground=ground, deco=deco, walls=walls, above=above,
                enemies=enemies, chests=chests, investigate=investigate,
                boss=boss, spawn_px=spawn_px,
                spawn_tile=(19, 2), blockers=[])


# ---------------------------------------------------------------- 场景文本组装
MAP_NAMES = {"f1": "Ruins_F1", "f2": "Ruins_F2", "f3": "Ruins_F3"}
SCRIPT_NAMES = {"f1": "ruins_f1_map.gd", "f2": "ruins_f2_map.gd", "f3": "ruins_f3_map.gd"}


def tscn_for(floor_key, m):
    name = MAP_NAMES[floor_key]
    script = SCRIPT_NAMES[floor_key]
    out = []
    out.append('[gd_scene load_steps=5 format=3]')
    out.append('')
    out.append(f'[ext_resource type="Script" path="res://scripts/maps/{script}" id="1_mapgd"]')
    out.append('[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="2_player"]')
    out.append('[ext_resource type="TileSet" path="res://assets/tiles/ruins_tileset.tres" id="3_tileset"]')
    out.append('[ext_resource type="PackedScene" path="res://scenes/enemies/visible_enemy.tscn" id="4_enemy"]')
    out.append('')
    out.append(f'[node name="{name}" type="Node2D"]')
    out.append('script = ExtResource("1_mapgd")')
    out.append('')

    def layer_node(nm, z, cells, ysort=False):
        lines = [f'[node name="{nm}" type="TileMapLayer" parent="."]',
                 'tile_set = ExtResource("3_tileset")',
                 f'z_index = {z}']
        if ysort:
            lines.append('y_sort_enabled = true')
        lines.append(f'tile_map_data = PackedByteArray({packed_text(cells)})')
        return lines

    out += layer_node("Ground", -10, m["ground"])
    out.append('')
    out += layer_node("GroundDeco", -9, m["deco"])
    out.append('')
    out += ['[node name="YSorted" type="Node2D" parent="."]',
            'y_sort_enabled = true',
            '']
    # 敌人实体（定守精英 waypoints 为空数组）
    for (nm, tx, ty, uid, gid, wps) in m["enemies"]:
        wp_body = ", ".join(f'Vector2({wps[i]}, {wps[i + 1]})' for i in range(0, len(wps), 2))
        out += [f'[node name="{nm}" parent="YSorted" instance=ExtResource("4_enemy")]',
                f'position = Vector2({tx * 16 + 8}, {ty * 16 + 8})',
                f'enemy_uid = "{uid}"',
                f'group_id = "{gid}"',
                f'return_map = "res://scenes/maps/ruins_{floor_key}.tscn"',
                f'waypoints = Array[Vector2]([{wp_body}])',
                '']
    # 点位锚点（宝箱/调查）
    out += ['[node name="Anchors" type="Node2D" parent="YSorted"]', '']
    for (nm, tx, ty) in m["chests"] + m["investigate"]:
        out += [f'[node name="{nm}" type="Marker2D" parent="YSorted/Anchors"]',
                f'position = Vector2({tx * 16 + 8}, {ty * 16 + 8})',
                '']
    # Boss 触发器锚点（f3 专属；数据位，接线归 E5/E4-S6）
    if m["boss"]:
        out += ['[node name="BossTriggers" type="Node2D" parent="YSorted"]', '']
        for i, (nm, tx, ty) in enumerate(m["boss"]):
            out += [f'[node name="{nm}_{i + 1:02d}" type="Marker2D" parent="YSorted/BossTriggers"]',
                    f'position = Vector2({tx * 16 + 8}, {ty * 16 + 8})',
                    '']
    # 玩家（进图出生位）
    out += ['[node name="Player" parent="YSorted" instance=ExtResource("2_player")]',
            f'position = Vector2({m["spawn_px"][0]}, {m["spawn_px"][1]})',
            '']
    out += layer_node("WallsObjects", 0, m["walls"], ysort=True)
    out.append('')
    out += layer_node("Above", 10, m["above"])
    out.append('')
    # 传送触发器归 E4-S6 接线（from_road/from_f1/from_f2 + to_next），本 Story 仅留容器
    out += ['[node name="Triggers" type="Node2D" parent="."]', '']
    return "\n".join(out) + "\n"


def main():
    for key, builder in [("f1", build_f1), ("f2", build_f2), ("f3", build_f3)]:
        m = builder()
        text = tscn_for(key, m)
        out_path = os.path.join(REPO_ROOT, "scenes", "maps", f"ruins_{key}.tscn")
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print(f"ruins_{key}.tscn: {len(text)} chars | {m['w']}x{m['h']} | "
              f"ground {len(m['ground'])} deco {len(m['deco'])} walls {len(m['walls'])} above {len(m['above'])} | "
              f"敌 {len(m['enemies'])} 箱 {len(m['chests'])} 查 {len(m['investigate'])}"
              + (" | Boss 锚 ×2" if m["boss"] else ""))


if __name__ == "__main__":
    main()
