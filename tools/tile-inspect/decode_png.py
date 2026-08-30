# -*- coding: utf-8 -*-
"""索引色 PNG (ctype=3) → RGBA 缓存解码器（纯标准库）。

用法:
    python decode_png.py <png路径> <输出rgba路径>
产出: 逐像素 RGBA 缓存（W*H*4 字节，小端），供 tile_ascii / analyze_tiles 选用型。
支持: PLTE 调色板 + tRNS 透明索引 + 全部 5 种行滤波（含 Paeth）。
"""
import struct
import sys
import zlib


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def decode_indexed_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "PNG 签名不符"
    pos = 8
    w = h = bd = ct = 0
    plte = None
    trns = None
    idat = bytearray()
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", body[:10])
        elif typ == b"PLTE":
            plte = body
        elif typ == b"tRNS":
            trns = body
        elif typ == b"IDAT":
            idat += body
        pos += 12 + ln
        if typ == b"IEND":
            break
    assert bd == 8, f"仅支持 8bit，实际 bitdepth={bd}"
    assert ct in (3, 6), f"仅支持索引色(3)或直色RGBA(6)，实际 colortype={ct}"
    assert plte is not None or ct == 6, "缺 PLTE 调色板"

    # zlib 解压 + 逐行反滤波
    raw = zlib.decompress(bytes(idat))
    stride = w * (4 if ct == 6 else 1)  # 直色RGBA每像素4字节 / 索引色1字节
    idx = bytearray(w * h * (4 if ct == 6 else 1))
    prev = bytearray(stride)
    for row in range(h):
        ft = raw[row * (stride + 1)]
        line = bytearray(raw[(row * (stride + 1) + 1):(row + 1) * (stride + 1)])
        for x in range(stride):
            step = 4 if ct == 6 else 1
            a = line[x - step] if x >= step else 0
            b = prev[x]
            c = prev[x - step] if x >= step else 0
            if ft == 1:
                line[x] = (line[x] + a) & 0xFF
            elif ft == 2:
                line[x] = (line[x] + b) & 0xFF
            elif ft == 3:
                line[x] = (line[x] + (a + b) // 2) & 0xFF
            elif ft == 4:
                line[x] = (line[x] + paeth(a, b, c)) & 0xFF
        idx[row * stride:(row + 1) * stride] = line
        prev = line

    if ct == 6:
        return w, h, bytes(idx)

    # 调色板 + tRNS → RGBA
    n_colors = len(plte) // 3
    alpha_tab = bytes([255] * n_colors)
    if trns:
        alpha_tab = bytearray(alpha_tab)
        for i, av in enumerate(trns):
            if i < n_colors:
                alpha_tab[i] = av
        alpha_tab = bytes(alpha_tab)
    out = bytearray(w * h * 4)
    for p, ci in enumerate(idx):
        out[p * 4:p * 4 + 3] = plte[ci * 3:ci * 3 + 3]
        out[p * 4 + 3] = alpha_tab[ci]
    return w, h, bytes(out)


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    w, h, px = decode_indexed_png(src)
    open(dst, "wb").write(px)
    n_trans = sum(1 for i in range(3, len(px), 4) if px[i] < 128)
    print(f"OK {w}x{h} -> {dst}  (透明像素 {n_trans} / {w * h})")
