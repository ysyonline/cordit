# E1-S5 视觉验收像素分析（纯标准库 PNG 解码，无 PIL 依赖；保留在 evidence 旁备查）
import os, struct, zlib

D = r"D:/code/cordit/tests/smoke/evidence/e1s5-visual"
PLAYER_RGB = (230, 191, 77)
TOL = 10

def load_png(path):
    """极简 PNG 解码：只支持 8bit RGB/RGBA，非隔行（Godot 截图即此格式）。"""
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not png"
    off, w, h, bitd, ctype = 8, 0, 0, 0, 0
    idat = b""
    plte = None
    trns = None
    while off < len(data):
        ln = struct.unpack(">I", data[off:off + 4])[0]
        typ = data[off + 4:off + 8]
        chunk = data[off + 8:off + 8 + ln]
        if typ == b"IHDR":
            w, h, bitd, ctype = struct.unpack(">IIBB", chunk[:10])
        elif typ == b"IDAT":
            idat += chunk
        elif typ == b"PLTE":
            plte = chunk
        elif typ == b"tRNS":
            trns = chunk
        off += 12 + ln
    assert bitd == 8, f"bit depth {bitd} not supported"
    nch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = w * nch
    out = bytearray(w * h * nch)
    prev = bytearray(stride)
    pos = 0
    for y in range(h):
        ft = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos + stride]); pos += stride
        if ft == 1:
            for i in range(nch, stride):
                line[i] = (line[i] + line[i - nch]) & 0xFF
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ft == 3:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif ft == 4:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                b = prev[i]
                c = prev[i - nch] if i >= nch else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out[y * stride:(y + 1) * stride] = line
        prev = line
    if ctype == 3:  # palette -> rgb
        rgb = bytearray(w * h * 3)
        for i in range(w * h):
            idx = out[i]
            rgb[i * 3:i * 3 + 3] = plte[idx * 3:idx * 3 + 3]
        return w, h, bytes(rgb), 3
    return w, h, bytes(out), nch

def px(img, x, y):
    w, h, buf, nch = img
    o = (y * w + x) * nch
    return (buf[o], buf[o + 1], buf[o + 2])

def is_player(p):
    return all(abs(p[i] - PLAYER_RGB[i]) <= TOL for i in range(3))

def is_black(p):
    return p[0] <= 8 and p[1] <= 8 and p[2] <= 8

SUBJECTS = {
    "well":  (896, 384),
    "wood":  (960, 432),
    "chest": (944, 352),
}
FEET = {
    "well":  {"front": (904, 408), "behind": (904, 376)},
    "wood":  {"front": (968, 456), "behind": (968, 424)},
    "chest": {"front": (952, 376), "behind": (952, 344)},
}

print("=" * 72)
print("一、y-sort 六张截图判定")
print("  front：玩家在物件下方一格，物件 tile(16x16)内应出现玩家色>=100px（玩家遮挡物件）")
print("  behind：物件 tile 内玩家色=0，且玩家矩形顶部8行玩家色<32（物件遮挡上半身）")
print("=" * 72)

for name, (twx, twy) in SUBJECTS.items():
    for kind in ("front", "behind"):
        img = load_png(os.path.join(D, f"ysort_{name}_{kind}.png"))
        w, h = img[0], img[1]
        feet = FEET[name][kind]
        ox, oy = feet[0] - 320, feet[1] - 180
        tx0, ty0 = twx - ox, twy - oy
        n_tile = sum(1 for x in range(tx0, tx0 + 16) for y in range(ty0, ty0 + 16)
                     if 0 <= x < w and 0 <= y < h and is_player(px(img, x, y)))
        px0, py0 = 312, 162
        n_body = sum(1 for x in range(px0, px0 + 16) for y in range(py0, py0 + 18)
                     if is_player(px(img, x, y)))
        n_top = sum(1 for x in range(px0, px0 + 16) for y in range(py0, py0 + 8)
                    if is_player(px(img, x, y)))
        # 玩家矩形顶部8行的实际主色（behind 判定的证据）
        top_colors = {}
        for x in range(px0, px0 + 16, 4):
            for y in range(py0, py0 + 8, 2):
                c = px(img, x, y)
                top_colors[c] = top_colors.get(c, 0) + 1
        top_main = sorted(top_colors.items(), key=lambda kv: -kv[1])[:2]
        ok = (n_tile >= 100) if kind == "front" else (n_tile == 0 and n_top < 32)
        print(f"[{name}_{kind}] 物件tile内玩家色={n_tile}/256 玩家矩形={n_body}/288 顶8行={n_top}/128 "
              f"顶8行主色={top_main} -> {'PASS' if ok else 'FAIL'}")

print()
print("=" * 72)
print("二、室内B 黑幕框判定（inniteior_view.png）")
print("  规则：边缘20px环带非黑占比<1%；中心房间区应大量非黑")
print("=" * 72)
img = load_png(os.path.join(D, "inniteior_view.png"))
w, h, nch = img[0], img[1], img[3]
edge_total = edge_notblack = 0
for x in range(w):
    for y in range(h):
        if x < 20 or x >= w - 20 or y < 20 or y >= h - 20:
            edge_total += 1
            if not is_black(px(img, x, y)):
                edge_notblack += 1
ratio = edge_notblack / edge_total * 100
n_center = n_center_nb = 0
for x in range(w // 2 - 96, w // 2 + 96, 4):
    for y in range(h // 2 - 72, h // 2 + 72, 4):
        n_center += 1
        if not is_black(px(img, x, y)):
            n_center_nb += 1
for corner, (cx, cy) in {"左上": (10, 10), "右上": (w - 10, 10), "左下": (10, h - 10), "右下": (w - 10, h - 10)}.items():
    print(f"  {corner}角RGB={px(img, cx, cy)}")
print(f"  边缘环带：非黑 {edge_notblack}/{edge_total} = {ratio:.3f}%  -> {'PASS' if ratio < 1.0 else 'FAIL'}")
print(f"  中心房间区(4px步进)：非黑 {n_center_nb}/{n_center}  -> {'房间正常显示' if n_center_nb > 200 else 'CHECK'}")
