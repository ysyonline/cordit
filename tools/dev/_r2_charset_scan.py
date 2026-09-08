# -*- coding: utf-8 -*-
"""_r2_charset_scan.py —— R2-CHARSPRITE：实测 Antifarea 提亮 charset 的真实帧网。

【需求依据】R2-CHARSPRITE 任务 1：330x400 不一定能被 16x18 整除（400/18 ≈ 22.2
不整除），可能含边距/间隔，禁止按假设网格裁切——逐行扫描非透明像素块，定位
12 个角色块的行列坐标，实测为准。

【用法】（本机受管 Python，勿全局 pip）
  C:\\Users\\weixufeng\\.workbuddy\\binaries\\python\\versions\\3.13.12\\python.exe ^
    tools/dev/_r2_charset_scan.py

【输出】
  - 控制台：块结构概览（每行条带的 y 范围 / x 范围 / 高度）
  - assets/characters/charset_frames.md 的数据基础（帧网参考文档由扫描结果
    人工核对后撰写，本脚本只产数据）
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

PNG = Path(__file__).resolve().parents[2] / "assets" / "characters" / "charsets_12_m-f_antifarea_bright.png"


def main() -> int:
    img = Image.open(PNG).convert("RGBA")
    w, h = img.size
    print(f"image: {PNG.name}  {w}x{h}")
    px = img.load()

    # 1) 垂直投影：逐行统计非透明像素数，找水平空白带 → 行条带（角色行）
    row_has = [any(px[x, y][3] > 0 for x in range(w)) for y in range(h)]
    row_bands = []
    y = 0
    while y < h:
        if row_has[y]:
            y0 = y
            while y < h and row_has[y]:
                y += 1
            row_bands.append((y0, y - 1))
        else:
            y += 1
    print(f"row bands ({len(row_bands)}):")
    for (y0, y1) in row_bands:
        print(f"  y {y0:3d}..{y1:3d}  height={y1 - y0 + 1}")

    # 2) 每个行条带内做水平投影 → 角色块（12 个横排角色）
    char_blocks = []  # [(col, x0, y0, x1, y1)]
    for bi, (y0, y1) in enumerate(row_bands):
        col_has = [any(px[x, yy][3] > 0 for yy in range(y0, y1 + 1)) for x in range(w)]
        x = 0
        xs = []
        while x < w:
            if col_has[x]:
                x0 = x
                while x < w and col_has[x]:
                    x += 1
                xs.append((x0, x - 1))
            else:
                x += 1
        for i, (a, b) in enumerate(xs):
            print(f"  band{bi} char#{i}: x[{a}..{b}] w={b - a + 1}")
            char_blocks.append((i, a, y0, b, y1))

    # 3) 16x18 对齐核验：以每角色块包围盒顶/左为原点，检查 16x18 网格假设
    print("\n16x18 grid assumption check (block bbox height should be 18, width <= 16):")
    for (ci, x0, y0, x1, y1) in char_blocks:
        ok = (y1 - y0 + 1 == 18) and (x1 - x0 + 1 <= 16)
        flag = "OK " if ok else "!!!"
        print(f"  {flag} char#{ci}: bbox x[{x0}..{x1}] y[{y0}..{y1}] {x1-x0+1}x{y1-y0+1}")

    # 4) 帧序探测（内部帧边界：块内竖直空白缝）
    print("\ninner frame gaps per char block (vertical fully-transparent columns inside bbox):")
    for (ci, x0, y0, x1, y1) in char_blocks:
        gaps = []
        run = 0
        for x in range(x0, x1 + 1):
            empty = all(px[x, yy][3] == 0 for yy in range(y0, y1 + 1))
            if empty:
                run += 1
            else:
                if run > 0:
                    gaps.append((x - run, x - 1, run))
                run = 0
        if run > 0:
            gaps.append((x1 - run + 1, x1, run))
        print(f"  char#{ci}: " + (", ".join(f"x[{a}..{b}](w{g})" for a, b, g in gaps) if gaps else "none"))

    # 汇总 JSON（供后续脚本/文档引用）
    summary = {
        "png": PNG.name,
        "size": [w, h],
        "row_bands": [[y0, y1] for (y0, y1) in row_bands],
        "char_blocks": [
            {"row": bi, "col": ci, "x0": x0, "y0": y0, "x1": x1, "y1": y1}
            for bi, (y0, y1) in enumerate(row_bands)
            for (ci, x0, y0, x1, y1) in [b for b in char_blocks if b[2] == y0]
        ],
    }
    out = Path(__file__).resolve().parents[2] / "tools" / "dev" / "_r2_charset_scan_result.json"
    out.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nsummary -> {out}")
    return 0


if __name__ == "__main__":
    main()
