# -*- coding: utf-8 -*-
"""QA gate 表格结构修正：
1) R-0 行恢复 3 列结构；
2) O-5/O-6 修复标注从「严重度」列挪到「摘要」列；
3) 门判定标题下追加 R-0 销项追记（不翻转 FAIL 判定）；
4) §13.3 导出冒烟措辞精确化。
报告 -> evidence/_gate_fix2_report.txt
"""
import io, os, re

ROOT = r"D:\code\cordit"
GATE = os.path.join(ROOT, "production", "qa", "m7-final-qa-gate.md")
DOC = os.path.join(ROOT, "production", "release", "m7-package-closeout.md")
OUT = os.path.join(ROOT, "evidence", "_gate_fix2_report.txt")

rep = []
def log(x=""):
    rep.append(x)

g = io.open(GATE, "r", encoding="utf-8").read()
orig = g

# ---- 1) R-0 行恢复 3 列 ----
pat_r0 = re.compile(r"\| \*\*R-0\*\* \| ✅ \*\*已销项（2026-09-12）\*\*：.*?\|\s*$", re.M | re.S)
m = pat_r0.search(g)
log("R0-OLD-FOUND=%s" % bool(m))
r0_new = (
    "| **R-0**（✅ 已销项 2026-09-12） "
    "| O-6 修复（生产路由接入真实战斗，battle_scene.gd 重写）+ O-5 修复（f1 入口锚装配，ruins_f1_map.gd）落地："
    "GUT 全绿 530/530（APPDATA 重定向）→ 重新导出（exe `01F7DCF0…` / pck `D6AC9B5E…`）→ 导出包 headless 冒烟通过 → "
    "SHA256 已录入 `m7-package-closeout.md` §13.2；zip 重打包与试玩档 §0 / §7 回写延后至 commit/tag 同步执行 "
    "| ✅ 回收证据：`evidence/_o6-gut-clean2.log`、`_o5-gut-clean.log`、`_o5-smoke-verify3.log`、`o6-export-smoke.log`、closeout §13 |"
)
if m:
    g = g[:m.start()] + r0_new + g[m.end():]

# ---- 2) O-5 行：修复标注挪到摘要列 ----
o5_old = ("| ✅ 修复落地 2026-09-12（ruins_f1_map.gd 入口锚装配 + GUT 530/530 + 冒烟 8/8）→ 摘要如下（历史原文保留）：  "
          "**Major（对游戏流程而言）** | **")
o5_new = ("| **Major（对游戏流程而言）** | ✅ **修复落地 2026-09-12**（ruins_f1_map.gd 入口锚装配 + GUT 530/530 + 冒烟 8/8）。"
          "修复前摘要（历史原文保留）：**")
c5 = g.count(o5_old)
g = g.replace(o5_old, o5_new, 1)
log("O5-MOVE count=%d" % c5)

# ---- 3) O-6 行：修复标注挪到摘要列 ----
o6_old = ("| ✅ 修复落地 2026-09-12（battle_scene.gd 重写接真实战斗 + battle_command.setup() 类型缺陷修复 + GUT 530/530 + 重导出）"
          "→ 摘要如下（历史原文保留）：  **🔴 Blocker（2026-09-12 玩家实证 + 代码考古坐实）** | **")
o6_new = ("| **🔴 Blocker（2026-09-12 玩家实证 + 代码考古坐实；已修复）** | ✅ **修复落地 2026-09-12**"
          "（battle_scene.gd 重写接真实战斗 + battle_command.setup() 类型缺陷修复 + GUT 530/530 + 重导出）。"
          "修复前摘要（历史原文保留）：**")
c6 = g.count(o6_old)
g = g.replace(o6_old, o6_new, 1)
log("O6-MOVE count=%d" % c6)

# ---- 4) 门判定标题下追记 ----
title = "# 🔴 FAIL（2026-09-12 降级；原判定 🟡 CONCERNS）"
note = ("\n\n> 📌 **2026-09-12 追记（R-0 销项）**：O-6 已修复（生产路由接入真实战斗）并重导出，O-5 一并修复；"
        "证据见放行条件表 R-0 行与 `m7-package-closeout.md` §13。"
        "门仍维持 FAIL——仅剩 R-1（外部试玩三问）/ R-2（非开发机实测）/ R-3（视频 #7 须在新包重录）三项外部回收；"
        "门判定翻转待主理人复核后定。")
if title in g and "R-0 销项" not in g:
    g = g.replace(title, title + note, 1)
    log("NOTE-INSERTED=True")
else:
    log("NOTE-INSERTED=False title_found=%s already=%s" % (title in g, "R-0 销项" in g))

io.open(GATE, "w", encoding="utf-8").write(g)
back = io.open(GATE, "r", encoding="utf-8").read()

# ---- 5) 回验：行列数咬合 ----
log("[COL-CHECK] 放行条件表与 G-8 表各行管道数")
in_table = False
for ln in back.splitlines():
    if ln.startswith("|"):
        in_table = True
    elif in_table:
        break
for ln in back.splitlines():
    if re.match(r"^\|\s*\*\*(R-0|R-1|R-2|R-3|O-5|O-6)\*\*", ln):
        log("    cols=%d :: %s" % (ln.count("|") - 1, ln[:60].encode("unicode_escape").decode("ascii")))
log("NOTE-IN-FILE=%s" % ("📌 **2026-09-12 追记（R-0 销项）**" in back))

# ---- 6) §13.3 冒烟措辞精确化 ----
s = io.open(DOC, "r", encoding="utf-8").read()
s_old = u"导出包 headless 冒烟：（执行日志在案）"
s_new = u"导出包 headless 冒烟 EXIT=0（会话内捕获；该日志文件为启动/退出记录，无断言行）"
c7 = s.count(s_old)
s = s.replace(s_old, s_new, 1)
io.open(DOC, "wb").write(s.encode("utf-8"))
log("SEC13-SMOKE-WORDING count=%d" % c7)

# ---- 7) dump 最终 R-0/O-5/O-6 行与追记 ----
log("[FINAL]")
for ln in back.splitlines():
    if re.search(r"\*\*(R-0|O-5|O-6)\*\*", ln) or "追记（R-0 销项）" in ln:
        log("    " + ln.encode("unicode_escape").decode("ascii")[:700])

io.open(OUT, "w", encoding="utf-8").write("\n".join(rep))
print("GATE FIX2 done r0_3col=%s o5=%d o6=%d note=%s" % (r0_new.split("|")[1] in back, c5, c6, "追记（R-0 销项）" in back))
