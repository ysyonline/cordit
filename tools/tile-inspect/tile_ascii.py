# -*- coding: utf-8 -*-
"""把图集候选区域渲染成 ASCII 像画：每像素一字符，供无图环境辨认证 tile。"""
import os
import sys

# 解码缓存目录 = 本脚本所在目录（E4-S0 修复：.rgba 已随裁决迁至 tools/tile-inspect/，
# 不再指向原硬编码 D:\code\cordit\production\）
RGBA_DIR = os.path.dirname(os.path.abspath(__file__))

PAL = [
    # (判定函数缩写, 字符)
]

def px_char(r, g, b, a):
    if a < 128:
        return '.'
    mx, mn = max(r, g, b), min(r, g, b)
    chroma = mx - mn
    if mx < 45:
        return ' '        # 近黑
    if chroma < 22:
        if mx < 90: return 'k'   # 暗灰
        if mx < 160: return 'K'  # 中灰
        return 'W'               # 亮灰/白
    if b >= r and b >= g:
        return 'U' if mx > 140 else 'u'   # 蓝(水)
    if g >= r and g >= b:
        if r > g - 30 and mx > 100: return 'n'  # 黄绿(草亮)
        return 'g' if mx > 100 else 'f'         # 绿 / 深绿
    if r >= g and r >= b:
        if g > r - 20 and b < g - 20 and mx > 130:
            return 'y'  # 黄/沙
        if r > g + 40 and r > b + 40:
            return 'R' if mx > 150 else 'r'     # 红
        if r > b + 15:
            return 'B' if mx > 150 else 'b'     # 棕/木
        return 'o'  # 其他暖色
    return '?'

def load(name):
    # E4-S3 选型扩充：classical_temple 图集接入（64×48 网格，1024×768）
    fname = {"town": "town_tiles", "forest": "forest_tiles",
             "temple": "classical_temple_tiles"}[name]
    W = {"town": (512, 512), "forest": (240, 160),
         "temple": (1024, 768)}[name]
    px = open(os.path.join(RGBA_DIR, f"{fname}.rgba"), "rb").read()
    return W[0], W[1], px

def region(name, x0, y0, x1, y1, label=""):
    """打印 tile 区块 [x0..x1) x [y0..y1)（tile 坐标），横排拼一幅像画"""
    W, H, px = load(name)
    tw, th = (x1 - x0) * 16, (y1 - y0) * 16
    print(f"--- {name} tiles cols {x0}-{x1-1} rows {y0}-{y1-1} {label} ---")
    header = []
    for tx in range(x0, x1):
        header.append(f"|{tx%100:<15d}")
    print("".join(header))
    for py in range(th):
        row = []
        ty = y0 + py // 16
        for tx in range(x0, x1):
            base = ((ty * 16 + py % 16) * W + tx * 16) * 4
            chars = []
            for pxx in range(16):
                i = base + pxx * 4
                chars.append(px_char(px[i], px[i+1], px[i+2], px[i+3]))
            row.append("".join(chars))
        mark = f"{ty%100:>3d} " if py % 16 == 0 else "    "
        print(mark + " ".join(row))
    print()

if __name__ == '__main__':
    which = sys.argv[1] if len(sys.argv) > 1 else 'all'
    # 批次按命令行选择
    if which in ('ground', 'all'):
        region("town", 10, 0, 14, 2, "沙色块?")
        region("town", 22, 0, 26, 1, "石色块?")
        region("town", 18, 0, 20, 1, "木板色?")
    if which in ('walls', 'all'):
        region("town", 0, 1, 8, 6, "灰墙区?")
        region("town", 8, 6, 16, 8, "墙面/门?")
    if which in ('roof', 'all'):
        region("town", 24, 6, 32, 12, "红屋顶区?")
        region("town", 8, 12, 12, 16, "红区2?")
