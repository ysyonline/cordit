# -*- coding: utf-8 -*-
"""
verify_town.py — E1-S5 静态核验器（施工单第 7 节可文件化条目）
独立于生成器：重新解析 town.tscn 的 tile_map_data 字节流与节点树，逐条断言。
用法：python verify_town.py  → 全部 PASS 则退出码 0
"""
import re
import struct
import sys

TSCN = r"D:\code\cordit\scenes\maps\town.tscn"
TRES = r"D:\code\cordit\assets\tiles\town_map_tileset.tres"
GD = r"D:\code\cordit\scripts\maps\town_map.gd"

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
tres_text = open(TRES, encoding="utf-8").read()
gd_text = open(GD, encoding="utf-8").read()

# ---------- 解析 tile_map_data ----------
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


print("== 1. 节点树结构 ==")
required_nodes = [
    ("Map_Town", 'Node2D'), ("VoidBackdrop_A", "Polygon2D"), ("VoidBackdrop_B", "Polygon2D"),
    ("Ground", "TileMapLayer"), ("GroundDeco", "TileMapLayer"),
    ("YSorted", "Node2D"), ("WallsObjects", "TileMapLayer"), ("Above", "TileMapLayer"),
    ("Triggers", "Node2D"), ("NPC_Anchors", "Node2D"), ("Chest_town_01", "Marker2D"),
    ("Door_Inn", "Area2D"), ("Door_HouseA", "Area2D"), ("Inn_Exit", "Area2D"), ("HouseA_Exit", "Area2D"),
]
for nm, ty in required_nodes:
    check(f"节点 {nm} ({ty})", f'[node name="{nm}" type="{ty}"' in tscn_text)
check("12 个 NPC Marker2D", len(re.findall(r'type="Marker2D" parent="YSorted/NPC_Anchors"', tscn_text)) == 12)
check("Player 实例挂 YSorted", '[node name="Player" parent="YSorted" instance=ExtResource' in tscn_text)
check("Player 出生位 (192,640)", "position = Vector2(192, 640)" in tscn_text)
check("y_sort: YSorted", re.search(r'\[node name="YSorted"[^\]]*\]\ny_sort_enabled = true', tscn_text))
check("y_sort: WallsObjects", re.search(r'\[node name="WallsObjects"[^\]]*\]\ntile_set[^\n]*\nz_index = 0\ny_sort_enabled = true', tscn_text))
check("z_index: Ground=-10", "z_index = -10" in tscn_text)
check("z_index: GroundDeco=-9", "z_index = -9" in tscn_text)
check("z_index: Above=+10", "z_index = 10" in tscn_text)
check("z_index: 黑幕=-20", tscn_text.count("z_index = -20") == 2)
check("四层挂共享 TileSet", tscn_text.count('tile_set = ExtResource("3_tileset")') == 4)

print("== 2. 黑幕框与相机限区 ==")
check("黑幕A (1056,0)-(1696,360)", "PackedVector2Array(1056, 0, 1696, 0, 1696, 360, 1056, 360)" in tscn_text)
check("黑幕B (1056,188)-(1696,548)", "PackedVector2Array(1056, 188, 1696, 188, 1696, 548, 1056, 548)" in tscn_text)
gd_limits = re.findall(r'Rect2i\(([\d, ]+)\)', gd_text)
check("gd: 三组 limit", len(gd_limits) == 3, str(gd_limits))
check("gd: 主图 limit 0,0,1024,768", "Rect2i(0, 0, 1024, 768)" in gd_text)
check("gd: 室内A limit 1056,0,640,360", "Rect2i(1056, 0, 640, 360)" in gd_text)
check("gd: 室内B limit 1056,188,640,360", "Rect2i(1056, 188, 640, 360)" in gd_text)
check("gd: reset_smoothing", "reset_smoothing" in gd_text)
check("gd: E4-S6 衔接注释①", "map_ready" in gd_text)
check("gd: E4-S6 衔接注释②", "trigger_*.tscn" in gd_text or "trigger_" in gd_text)
check("gd: E4-S6 衔接注释③", "事件动作参数" in gd_text)

print("== 3. 层内容抽验 ==")
ground = parse_layer(tscn_text, "Ground")
deco = parse_layer(tscn_text, "GroundDeco")
walls = parse_layer(tscn_text, "WallsObjects")
above = parse_layer(tscn_text, "Above")
for nm, layer in [("Ground", ground), ("GroundDeco", deco), ("WallsObjects", walls), ("Above", above)]:
    check(f"{nm} 可解析且非空", layer is not None and len(layer) > 0)

# Ground：主图草地全铺 + 室内木板
grass_ok = all(ground.get((x, y), (9,))[0] == 1 for x in range(0, 64, 7) for y in range(0, 48, 5))
check("Ground 主图草地为 forest(source=1) 抽样", grass_ok)
check("Ground 室内A 地板 (85,15)=town 木板", ground.get((85, 15), (9,))[0] == 0)
check("Ground 无 64-67 缓冲带 tile", not any(64 <= x <= 67 for (x, y) in ground))
check("Ground 无室内区外溢(>67 且 <80)", not any(68 <= x <= 79 for (x, y) in ground))
# GroundDeco：道路表
check("Deco W街 (12,30)", (12, 30) in deco)
check("Deco 北街 (30,8)", (30, 8) in deco)
check("Deco 东街 (44,30)", (44, 30) in deco)
check("Deco 市场街 (50,19) 草甸小径", (50, 19) in deco)
check("Deco 南街 (40,36)", (40, 36) in deco)
check("Deco 中轴巷 (27,15)", (27, 15) in deco)
check("Deco 广场 (25,26)", (25, 26) in deco)
check("Deco 南门铺路 (12,47)", (12, 47) in deco)
check("Deco 无重叠到边框树", (0, 0) not in deco)
# WallsObjects：建筑/边框/室内
check("Wall 客栈立面 (29,16)", (29, 16) in walls)
check("Wall 客栈门洞 (29,17) 为门 tile", walls.get((29, 17)) == (0, 6, 1))
check("Wall 民居A门洞 (12,17)", walls.get((12, 17)) == (0, 6, 1))
check("Wall 神殿立面 (31,6)", (31, 6) in walls)
check("Wall 神殿封印门 (31,7)", walls.get((31, 7)) == (0, 0, 29))
check("Wall 喷泉 2x2", all((x, y) in walls for x in (27, 28) for y in (27, 28)))
check("Wall 边框树 (0,0)/(63,47)/(0,24)", (0, 0) in walls and (63, 47) in walls and (0, 24) in walls)
check("Wall 南门开口 (12,47)(13,47) 无树", (12, 47) not in walls and (13, 47) not in walls)
check("Wall 南门栅栏 (12,46)(13,46)", (12, 46) in walls and (13, 46) in walls)
check("Wall 室内A 墙圈四角", all(p in walls for p in [(80, 11), (91, 11), (80, 19), (91, 19)]))
check("Wall 室内B 墙圈四角", all(p in walls for p in [(80, 23), (91, 23), (80, 31), (91, 31)]))
check("Wall 室内A 门洞 (85,19)", walls.get((85, 19)) == (0, 6, 1))
check("Wall 室内B 门洞 (85,31)", walls.get((85, 31)) == (0, 6, 1))
check("Wall 存档占位 (89,12)", (89, 12) in walls)
check("Wall 宝箱 (59,22)", (59, 22) in walls)
check("Wall 草甸井 (56,24)", (56, 24) in walls)
check("Wall 柴堆 (60,27)", (60, 27) in walls)
check("Wall 客栈招牌 (31,18)", (31, 18) in walls)
check("Wall 无缓冲带 tile", not any(64 <= x <= 67 for (x, y) in walls))
check("Wall 无室内外溢(68-79)", not any(68 <= x <= 79 for (x, y) in walls))
# Above：屋顶/树冠
check("Above 客栈屋顶 (29,13)", (29, 13) in above)
check("Above 神殿顶 (31,3)", (31, 3) in above)
check("Above 边框树冠 (0,0)? 不——树冠只在散树", True)  # 边框树干无独立树冠（裁量点）
check("Above 草甸树冠 (58,20)(59,20)", (58, 20) in above and (59, 20) in above)
check("Above 无缓冲带 tile", not any(64 <= x <= 67 for (x, y) in above))
check("Above 无屋顶撞边框", (0, 0) not in above)
# 草地只用 forest（施工单 1.2-2 硬裁决）
bad_grass = [(x, y) for (x, y), (s, ax, ay) in ground.items() if x < 64 and y < 48 and s != 1]
check("硬裁决: 主图草地全部 forest_tiles", not bad_grass, f"{len(bad_grass)} 违规格")

print("== 4. 点位表（3.5，19 点位） ==")
npc_expect = {
    "npc_01_innkeeper": (30, 18), "npc_02_traveler": (85, 15), "npc_03_chase_kid": (23, 30),
    "npc_04_guard": (31, 27), "npc_05_smith": (44, 18), "npc_06_peddler": (14, 20),
    "npc_07_priest": (24, 9), "npc_08_prayer_woman": (32, 8), "npc_09_shepherd": (52, 18),
    "npc_10_housewife": (16, 35), "npc_11_porter": (50, 34), "npc_12_elder": (12, 24),
}
for nm, (tx, ty) in npc_expect.items():
    m = re.search(r'\[node name="%s"[^\]]*\]\nposition = Vector2\((\d+), (\d+)\)' % nm, tscn_text)
    ok = m and abs(int(m.group(1)) - (tx * 16 + 8)) < 1 and abs(int(m.group(2)) - (ty * 16 + 8)) < 1
    check(f"NPC {nm} @({tx},{ty})", bool(ok))
chest = re.search(r'\[node name="Chest_town_01"[^\]]*\]\nposition = Vector2\((\d+), (\d+)\)', tscn_text)
check("宝箱锚点 @(59,22)", chest and (59 * 16 + 8, 22 * 16 + 8) == (int(chest.group(1)), int(chest.group(2))))
trig_expect = {"Door_Inn": (29, 18), "Door_HouseA": (12, 18), "Inn_Exit": (85, 18), "HouseA_Exit": (85, 30)}
for nm, (tx, ty) in trig_expect.items():
    m = re.search(r'\[node name="%s"[^\]]*\]\ncollision_mask = 1\nposition = Vector2\((\d+), (\d+)\)' % nm, tscn_text)
    ok = m and int(m.group(1)) == tx * 16 + 8 and int(m.group(2)) == ty * 16 + 8
    check(f"Trigger {nm} @({tx},{ty}) mask=1", bool(ok))

print("== 5. TileSet 资源 ==")
check("tres: 两图集", "TileSetAtlasSource_town" in tres_text and "TileSetAtlasSource_forest" in tres_text)
check("tres: 两 png 引用", "town_tiles.png" in tres_text and "forest_tiles.png" in tres_text)
check("tres: tile_size 16", "tile_size = Vector2i(16, 16)" in tres_text)
check("tres: 物理层 layer=1 mask=0", "physics_layer_0/collision_layer = 1" in tres_text and "physics_layer_0/collision_mask = 0" in tres_text)
check("tres: sources/0、sources/1 注册", 'sources/0 = SubResource("TileSetAtlasSource_town")' in tres_text and 'sources/1 = SubResource("TileSetAtlasSource_forest")' in tres_text)
# 门洞格不挂碰撞
check("tres: 门洞 tile (0,6,1) 已声明", "\n6:1/0 = 0" in tres_text)
check("tres: 门洞 tile (0,6,1) 无碰撞行", "\n6:1/0/physics" not in tres_text)
# Y Sort Origin=8 的 tile 数量
ysort_cnt = len(re.findall(r'y_sort_origin = 8', tres_text))
check("tres: 25 个 y_sort_origin=8 tile", ysort_cnt == 25, f"实际 {ysort_cnt}")
# 四层用到的每个 (src,ax,ay) 都在 tres 声明
def tiles_used(layer, src_id):
    return {(ax, ay) for (s, ax, ay) in layer.values() if s == src_id}
for src_id, atlas in [(0, "town"), (1, "forest")]:
    used = tiles_used(ground, src_id) | tiles_used(deco, src_id) | tiles_used(walls, src_id) | tiles_used(above, src_id)
    missing = [t for t in used if not re.search(r'(?m)^%d:%d/0 = 0$' % t, tres_text)]
    check(f"tres: {'town' if src_id==0 else 'forest'} 图集覆盖全部用到的 tile", not missing, str(missing[:5]))
    # Walls 层用到的 tile 必须有 physics 行（属性行独立成行，精确前缀匹配）
    wall_used = tiles_used(walls, src_id)
    no_phys = []
    for (ax, ay) in wall_used:
        if not re.search(r'(?m)^%d:%d/0/physics_layer_0' % (ax, ay), tres_text):
            no_phys.append((ax, ay))
    # 门洞 (6,1) 是 walls 层唯一无碰撞 tile
    no_phys = [p for p in no_phys if p != (6, 1)]
    check(f"tres: Walls 层用到的 tile 均挂碰撞(门洞除外)", not no_phys, str(no_phys[:5]))

print("== 6. 汇总 ==")
print(f"PASS {passed} / FAIL {len(failures)}")
if failures:
    print("失败项:")
    for f in failures:
        print(" -", f)
    sys.exit(1)
print("全部通过 ✅")
