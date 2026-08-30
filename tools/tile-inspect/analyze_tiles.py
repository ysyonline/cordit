# -*- coding: utf-8 -*-
"""E1-S5 施工辅助：逐 16x16 格统计两图集 RGBA 像素，输出分类 ASCII 图与明细。
只读 assets/tiles 下的 png 解码缓存（*.rgba），不碰任何游戏文件。
"""
import os
import sys

# 解码缓存目录 = 本脚本所在目录（E4-S0 修复：.rgba 已随裁决迁至 tools/tile-inspect/，
# 不再指向原硬编码 D:\code\cordit\production\）
RGBA_DIR = os.path.dirname(os.path.abspath(__file__))

def load(name, w, h):
    px = open(os.path.join(RGBA_DIR, f"{name}.rgba"), "rb").read()
    assert len(px) == w * h * 4
    return px

def tile_stats(px, W, tx, ty):
    x0, y0 = tx * 16, ty * 16
    rs = gs = bs = 0
    n = 0
    trans = 0
    color_count = {}
    for y in range(y0, y0 + 16):
        for x in range(x0, x0 + 16):
            i = (y * W + x) * 4
            r, g, b, a = px[i], px[i+1], px[i+2], px[i+3]
            if a < 128:
                trans += 1
                continue
            rs += r; gs += g; bs += b; n += 1
            key = (r >> 4, g >> 4, b >> 4)  # 16 级量化
            color_count[key] = color_count.get(key, 0) + 1
    if n == 0:
        return None
    ar, ag, ab = rs / n, gs / n, bs / n
    # 主色占比与主色均值
    top = max(color_count.items(), key=lambda kv: kv[1])
    return dict(r=ar, g=ag, b=ab, cov=n / 256.0, trans=trans,
                top_ratio=top[1] / n, tr=top[0][0]*16, tg=top[0][1]*16, tb=top[0][2]*16)

def classify(s):
    r, g, b, tr, tg, tb = s['r'], s['g'], s['b'], s['tr'], s['tg'], s['tb']
    if s['cov'] < 0.15:
        return 'e'  # empty
    # 绿色系：草/树
    if g > r + 10 and g > b + 10:
        if s['cov'] < 0.9 and s['top_ratio'] < 0.85:
            return 'C'  # canopy / complex green (树冠/树丛)
        return 'G'  # grass / tree green
    # 蓝色系：水
    if b > r + 15 and b > g + 5:
        return 'w'
    # 红色系：屋顶/招牌
    if r > g + 25 and r > b + 25:
        return 'R'
    # 暖棕：木/土路
    if r > b + 15 and g > b + 5 and r > 60:
        return 'B'  # brown (wood/dirt)
    # 灰系：石/墙
    mx, mn = max(r, g, b), min(r, g, b)
    if mx - mn < 18:
        return 'K'  # gray (stone/wall)
    return 'm'  # mixed/other

def dump(name, W, H, cols, rows):
    px = load(name, W, H)
    print(f"== {name} {W}x{H}  {cols}cols x {rows}rows ==")
    detail = []
    for ty in range(rows):
        line = []
        for tx in range(cols):
            s = tile_stats(px, W, tx, ty)
            if s is None:
                line.append('e')
                detail.append((tx, ty, None))
            else:
                c = classify(s)
                line.append(c)
                detail.append((tx, ty, s))
        print(f"{ty:2d} " + ''.join(line))
    return detail

if __name__ == '__main__':
    d1 = dump("town_tiles", 512, 512, 32, 32)
    print()
    d2 = dump("forest_tiles", 240, 160, 15, 10)
    # 输出非空格 RGB 明细供选型
    print("\n-- town_tiles 明细(avg rgb | top rgb | cov) --")
    for tx, ty, s in d1:
        if s:
            print(f"({tx:2d},{ty:2d}) {s['r']:5.0f}{s['g']:5.0f}{s['b']:5.0f} | {s['tr']:3d},{s['tg']:3d},{s['tb']:3d} | {s['cov']:.2f} top{s['top_ratio']:.2f}")
    print("\n-- forest_tiles 明细 --")
    for tx, ty, s in d2:
        if s:
            print(f"({tx:2d},{ty:2d}) {s['r']:5.0f}{s['g']:5.0f}{s['b']:5.0f} | {s['tr']:3d},{s['tg']:3d},{s['tb']:3d} | {s['cov']:.2f} top{s['top_ratio']:.2f}")
