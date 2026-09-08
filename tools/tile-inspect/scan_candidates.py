# -*- coding: utf-8 -*-
"""scan_candidates.py — 按色系统计给 tile 打分，辅助辨认火焰/水晶/装饰候选件。

用法: python scan_candidates.py <atlas>   atlas in {town, forest, oga}
输出每个 tile 的: 坐标 | 各色系像素数 | 透明占比，按特征排序。
色系: R=橙红(火焰) U=蓝(水晶/水) y=黄沙 W=白 n=黄绿 g=绿 b=棕 k=暗灰 . =透明
"""
import os
import sys

RGBA_DIR = os.path.dirname(os.path.abspath(__file__))
ATLAS = {
    # name: (file, width_px, height_px)
    "town":   ("town_tiles", 512, 512),
    "forest": ("forest_tiles", 240, 160),
    "oga":    ("16oga", 160, 80),
}

def classify(r, g, b, a):
    if a < 128:
        return '.'
    mx, mn = max(r, g, b), min(r, g, b)
    chroma = mx - mn
    if mx < 45:
        return ' '
    if chroma < 22:
        if mx < 90: return 'k'
        if mx < 160: return 'K'
        return 'W'
    if b >= r and b >= g:
        return 'U' if mx > 140 else 'u'
    if g >= r and g >= b:
        if r > g - 30 and mx > 100: return 'n'
        return 'g' if mx > 100 else 'f'
    if r >= g and r >= b:
        if g > r - 20 and b < g - 20 and mx > 130:
            return 'y'
        if r > g + 40 and r > b + 40:
            return 'R' if mx > 150 else 'r'
        if r > b + 15:
            return 'B' if mx > 150 else 'b'
        return 'o'
    return '?'

def main():
    name = sys.argv[1] if len(sys.argv) > 1 else 'oga'
    fname, W, H = ATLAS[name]
    px = open(os.path.join(RGBA_DIR, fname + ".rgba"), "rb").read()
    cols, rows = W // 16, H // 16
    results = []
    for ty in range(rows):
        for tx in range(cols):
            counts = {}
            for pyy in range(16):
                base = ((ty * 16 + pyy) * W + tx * 16) * 4
                for pxx in range(16):
                    i = base + pxx * 4
                    c = classify(px[i], px[i+1], px[i+2], px[i+3])
                    counts[c] = counts.get(c, 0) + 1
            total = sum(counts.values())
            opaque = total - counts.get('.', 0)
            results.append((tx, ty, counts, opaque))
    # 打印全部非空 tile 摘要
    print(f"== {name}: {cols}x{rows} tiles, 非空tile数={sum(1 for r in results if r[3] > 20)} ==")
    for tx, ty, c, opaque in results:
        if opaque <= 20:
            continue
        def n(k): return c.get(k, 0)
        fire = n('R') + n('r')          # 橙红
        crystal = n('U') + n('W')       # 蓝白
        green = n('g') + n('n') + n('f')
        tag = []
        if fire > 30: tag.append("FIRE?")
        if crystal > 40: tag.append("CRYSTAL?")
        if n('y') > 30: tag.append("SAND")
        print(f"({tx:2d},{ty:2d}) opq={opaque:3d} R={n('R')+n('r'):3d} U={n('U')+n('u'):3d} "
              f"W={n('W'):3d} y={n('y'):3d} g={green:3d} b={n('B')+n('b'):3d} k={n('k'):3d} "
              f"{' '.join(tag)}")

if __name__ == '__main__':
    main()
