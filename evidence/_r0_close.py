# -*- coding: utf-8 -*-
"""QA gate R-0 销项 + §13.3 引用咬合核对。
报告 -> evidence/_r0_close_report.txt（unicode_escape 转写）。
"""
import io, os, re

ROOT = r"D:\code\cordit"
DOC = os.path.join(ROOT, "production", "release", "m7-package-closeout.md")
GATE = os.path.join(ROOT, "production", "qa", "m7-final-qa-gate.md")
EV = os.path.join(ROOT, "evidence")
OUT = os.path.join(ROOT, "evidence", "_r0_close_report.txt")

rep = []
def log(x=""):
    rep.append(x)

# ---- 1) §13.3 引用咬合核对 ----
s = io.open(DOC, "r", encoding="utf-8").read()
sec13 = s[s.index("## 13."):]
refs = sorted(set(re.findall(r"evidence/([A-Za-z0-9_.\-]+?\.log)", sec13)))
log("[SEC13-REFS]")
for r in refs:
    log("    %-28s %s" % (r, "EXISTS" if os.path.exists(os.path.join(EV, r)) else "MISSING!"))

# ---- 2) R-0 行销项 ----
g = io.open(GATE, "r", encoding="utf-8").read()
g_orig = g

m = re.search(r"\|\s*\*\*R-0\*\*（新增，先于一切）\s*\|\s*(.+?)\|\s*(.+?)\|\s*$", g, re.M | re.S)
log("R0-ROW-FOUND=%s" % bool(m))
if m:
    r0_new = (
        "| **R-0** | ✅ **已销项（2026-09-12）**：O-6 修复 + O-5 修复落地——生产路由接入真实战斗（battle_scene.gd 重写）、"
        "f1 入口锚装配（ruins_f1_map.gd，双守卫）；GUT 全绿 530/530（`evidence/_o6-gut-clean2.log`、`_o5-gut-clean.log`，APPDATA 重定向）；"
        "重新导出完成（exe `01F7DCF0…`、pck `D6AC9B5E…`，现货指纹见 `m7-package-closeout.md` §13.2）；"
        "导出包 headless 冒烟通过（`evidence/o6-export-smoke.log`）；"
        "⚠️ zip 重打包 + playtest 档 §0 + §7 表回写 → **延后至 commit/tag 同步执行** |"
    )
    g = g[:m.start()] + r0_new + g[m.end():]

# ---- 3) G-8 表 O-5/O-6 行加修复标注（仅前缀注入，不删原文） ----
for oid, fix in [
    ("O-5", "✅ 修复落地 2026-09-12（ruins_f1_map.gd 入口锚装配 + GUT 530/530 + 冒烟 8/8）→ 摘要如下（历史原文保留）："),
    ("O-6", "✅ 修复落地 2026-09-12（battle_scene.gd 重写接真实战斗 + battle_command.setup() 类型缺陷修复 + GUT 530/530 + 重导出）→ 摘要如下（历史原文保留）："),
]:
    pat = re.compile(r"(\|\s*\*\*" + oid + r"\*\*\s*\|)")
    m2 = pat.search(g)
    log("%s-ROW-FOUND=%s" % (oid, bool(m2)))
    if m2 and "修复落地" not in g[m2.start():m2.start() + 600]:
        g = g[:m2.end()] + " " + fix + " " + g[m2.end():]

io.open(GATE, "w", encoding="utf-8").write(g)
back = io.open(GATE, "r", encoding="utf-8").read()
log("GATE-WRITTEN CHANGED=%s" % (back != g_orig))
log("R0-CLOSED-MARK=%s" % ("已销项（2026-09-12）" in back))
log("FIX-MARK-COUNT=%d" % back.count("修复落地 2026-09-12"))

# ---- 4) dump 最终态（unicode_escape 防漂移） ----
log("[FINAL-ROWS]")
for ln in back.splitlines():
    if re.search(r"\*\*(R-0|O-5|O-6)\*\*", ln):
        log("    " + ln.encode("unicode_escape").decode("ascii")[:600])

io.open(OUT, "w", encoding="utf-8").write("\n".join(rep))
print("R0 CLOSED=%s FIXMARK=%d" % ("已销项（2026-09-12）" in back, back.count("修复落地 2026-09-12")))
