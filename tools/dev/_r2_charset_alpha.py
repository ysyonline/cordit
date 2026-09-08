# -*- coding: utf-8 -*-
"""_r2_charset_alpha.py —— R2-CHARSPRITE：提亮件转写 alpha 透明件 + 调色板变体。

【需求依据】R2-CHARSPRITE 任务 1/4：提亮件 charsets_12_m-f_antifarea_bright.png
为 GIF 扁平化产物（实测无 alpha 通道，背景为实色 (251,220,126)），直接作引擎
贴图会带黄底。本脚本产出：
  ① charsets_12_m-f_antifarea_bright_alpha.png —— 背景色 → alpha=0，其余像素
     逐色保留（R4 派生件）；
  ② _alpha_v1_elder / v2_porter / v3_smith / v4_shepherd —— 4 个调色板变体
    （R5 派生件：原生男形 6 个 < 男性角色 9 名；CC-BY 允许派生，已先在
     assets/CREDITS.md B 区登记后落盘）。

【帧网正本】见 assets/characters/charset_frames.md（_r2_charset_scan 实测）：
  男带 y=180 / 女带 y=306，块 x=16+48*c（c=0..5），每块 48x72 = 16x18 × 3帧×4向。

【许可】Antifarea CC-BY 3.0（assets/licenses/notices/antifarea-sprites.txt）。

【用法】
  C:\\Users\\weixufeng\\.workbuddy\\binaries\\python\\versions\\3.13.12\\python.exe ^
    tools/dev/_r2_charset_alpha.py
幂等：重复运行覆盖产出（登记不变）。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CHAR_DIR = ROOT / "assets" / "characters"
SRC = CHAR_DIR / "charsets_12_m-f_antifarea_bright.png"
BG = (251, 220, 126)  # 提亮件背景实色（角落采样实测）


def load_rgb() -> "Image.Image":
    return Image.open(SRC).convert("RGB")


def to_alpha(img: "Image.Image") -> "Image.Image":
    """背景色 → alpha0，其余逐色保留。"""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    opx, spx = out.load(), img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            c = spx[x, y]
            opx[x, y] = (0, 0, 0, 0) if c == BG else (c[0], c[1], c[2], 255)
    return out


def recolor(img: "Image.Image", mapping: dict, cells: list) -> "Image.Image":
    """对指定角色块（48x72 单元）按 mapping 改色，其余区域原样复制。

    mapping: {旧 RGB: 新 RGB}；cells: [(col, band_y), ...]（col=0..5，band_y=180/306）。
    """
    out = img.copy()
    opx, ipx = out.load(), img.load()
    for (col, band_y) in cells:
        x0, y0 = 16 + col * 48, band_y
        for y in range(y0, y0 + 72):
            for x in range(x0, x0 + 48):
                c = ipx[x, y]
                if c in mapping:
                    opx[x, y] = (*mapping[c], 255)
    return out


def main() -> int:
    rgb = load_rgb()
    alpha = to_alpha(rgb)
    out_main = CHAR_DIR / "charsets_12_m-f_antifarea_bright_alpha.png"
    alpha.save(out_main)
    print(f"[R4] {out_main.name} <- bg{BG} -> alpha0")

    # ── 调色板变体（先登记后落盘：assets/CREDITS.md B 区 R5 行）──────────
    # V1 长者袍（基于 F6 兜帽长袍块）：暗色长袍系 → 灰白长者袍
    v1_map = {
        (94, 94, 100): (200, 198, 192),    # 长袍中调 → 老人灰白
        (44, 53, 59): (158, 156, 152),     # 长袍暗调 → 灰白暗阶
        (108, 28, 18): (120, 118, 116),    # 内衬暗红 → 灰调
        (148, 52, 34): (172, 170, 166),    # 内衬亮红 → 灰亮阶
    }
    # V2 搬运工（基于 M1 金发块）：金发/灰裤 → 深棕发/深裤（与玩家区分）
    v2_map = {
        (255, 255, 133): (110, 76, 44),    # 金发亮 → 深棕
        (242, 192, 42): (86, 58, 34),      # 金发暗 → 深棕暗阶
        (184, 184, 182): (92, 84, 78),     # 灰裤 → 深布裤
    }
    # V3 铁匠（基于 M2 紫衣块）：紫衣金发 → 炭灰衣黑发（皮革围裙保留）
    v3_map = {
        (151, 77, 149): (58, 56, 60),      # 紫衣中调 → 炭灰
        (201, 143, 223): (78, 76, 82),     # 紫衣亮调 → 炭灰亮阶
        (110, 151, 240): (44, 42, 48),     # 蓝饰 → 深炭
        (69, 94, 166): (36, 34, 40),       # 蓝饰暗 → 深炭暗
        (201, 176, 75): (52, 48, 50),      # 金发 → 黑发
    }
    # V4 牧羊人（基于 F2 紫裙块）：紫裙 → 土褐田野短打（绿饰/金肤保留）
    v4_map = {
        (86, 53, 108): (122, 88, 52),      # 紫裙中调 → 土褐
        (168, 118, 190): (150, 110, 66),   # 紫裙亮调 → 褐亮阶
        (201, 176, 75): (196, 68, 50),     # 金发 → 红棕（少年气）
    }

    variants = [
        ("v1_elder", v1_map, [(5, 306)]),
        ("v2_porter", v2_map, [(0, 180)]),
        ("v3_smith", v3_map, [(1, 180)]),
        ("v4_shepherd", v4_map, [(1, 306)]),
    ]
    for name, mapping, cells in variants:
        img = recolor(alpha, mapping, cells)
        out = CHAR_DIR / f"charsets_12_m-f_antifarea_bright_alpha_{name}.png"
        img.save(out)
        print(f"[R5] {out.name} <- {len(mapping)} 色映射，块 {cells}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
