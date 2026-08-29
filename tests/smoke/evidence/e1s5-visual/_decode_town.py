# 临时脚本：解码 town.tscn 四层 tile_map_data，确认目标区域 tile 分布（用完可删）
import re, struct, sys

TSCN = r"D:/code/cordit/scenes/maps/town.tscn"

def parse_layers(text):
    layers = {}
    # 逐节点块提取
    for m in re.finditer(r'\[node name="(\w+)" type="TileMapLayer"[^\]]*\][^\[]*?tile_map_data = PackedByteArray\(([^)]*)\)', text):
        name = m.group(1)
        bytes_ = [int(x) for x in m.group(2).split(",")]
        layers[name] = bytes_
    return layers

def decode(data_bytes):
    if len(data_bytes) < 2:
        return {}
    fmt = struct.unpack_from("<H", bytes(data_bytes), 0)[0]
    cells = {}
    off = 2
    while off + 12 <= len(data_bytes):
        x, y, src, ax, ay, alt = struct.unpack_from("<hhHHHH", bytes(data_bytes), off)
        cells[(x, y)] = (src, ax, ay, alt)
        off += 12
    return cells

text = open(TSCN, encoding="utf-8").read()
layers = {k: decode(v) for k, v in parse_layers(text).items()}

def dump(name, x0, x1, y0, y1):
    print(f"== {name} region tiles ({x0},{y0})-({x1},{y1}) ==")
    lay = layers.get(name, {})
    for y in range(y0, y1 + 1):
        row = []
        for x in range(x0, x1 + 1):
            c = lay.get((x, y))
            row.append(f"({c[1]:2d},{c[2]:2d})" if c else "  .   ")
        print(f"y={y:2d} " + " ".join(row))
    print()

# 草甸三物件区域
dump("WallsObjects", 54, 63, 19, 29)
# 室内B 区域（tile 80-91, 23-31）
dump("Ground", 79, 92, 22, 32)
dump("WallsObjects", 79, 92, 22, 32)
dump("Above", 54, 63, 17, 22)
