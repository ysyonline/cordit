# -*- coding: utf-8 -*-
"""§13 修正：回填 §7 旧指纹、纠正 exe 对比结论。
反引号感知正则重提取（§13 自身表格无日期列，不会误匹配）。
报告 -> evidence/_sec13_fix_report.txt（§13 全文 + QA gate 相关行，unicode_escape）。
"""
import io, os, re

ROOT = r"D:\code\cordit"
DOC = os.path.join(ROOT, "production", "release", "m7-package-closeout.md")
GATE = os.path.join(ROOT, "production", "qa", "m7-final-qa-gate.md")
OUT = os.path.join(ROOT, "evidence", "_sec13_fix_report.txt")
rep = []
def log(x=""):
    rep.append(x)

def sha256_file(p):
    import hashlib
    h = hashlib.sha256()
    with io.open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()

raw = io.open(DOC, "rb").read()
s = raw.decode("utf-8")

# ---- 1) 反引号感知重提取 §7 旧指纹 ----
def grab(name_re):
    pat = (r"\|\s*`" + name_re + r"`\s*\|\s*\d{4}-\d\d-\d\d[^|]*\|\s*`([0-9A-Fa-f]{64})`\s*\|")
    m = re.search(pat, s)
    return (m.group(1).upper() if m else None)

old_exe = grab(u"轨迹残响\.exe")
old_pck = grab(u"轨迹残响\.pck")
old_zip = grab(u"轨迹残响-v0\.1\.0-slice-win64\.zip")
log("EXTRACT exe=%s pck=%s zip=%s" % (old_exe, old_pck, old_zip))

exe_h = sha256_file(os.path.join(ROOT, "export", "win", u"轨迹残响.exe"))
pck_h = sha256_file(os.path.join(ROOT, "export", "win", u"轨迹残响.pck"))

assert old_exe and old_pck and old_zip, "EXTRACT FAILED - abort"
assert old_exe.startswith("01F7DCF0"), "old_exe prefix unexpected"
assert old_pck.startswith("BAA778C5"), "old_pck prefix unexpected"
assert old_zip.startswith("25BF07E9"), "old_zip prefix unexpected"
assert exe_h == old_exe, "live exe != sec7 exe?!"

# ---- 2) 三处定点替换（仅 §13 块内） ----
i13 = s.index("## 13.")
head, tail = s[:i13], s[i13:]
n_before = tail

r1_old = u"exe 相对 §7 的 01D（`?…`）**已变更** → `" + exe_h[:8] + u"…`。"
r1_new = (u"exe 与 §7 的 01D（`" + old_exe[:8] + u"…`）**逐字节一致**——符合预期：本轮改动面仅脚本/测试（归 pck），exe 壳未动。")
r2_old = u"pck 相对 §7 的 01D（`?…`）"
r2_new = u"pck 相对 §7 的 01D（`" + old_pck[:8] + u"…`）"
r3_old = u"（`?…`，磁盘现货复核一致）"
r3_new = u"（`" + old_zip[:8] + u"…`，磁盘现货复核一致）"

c1 = tail.count(r1_old); c2 = tail.count(r2_old); c3 = tail.count(r3_old)
log("COUNT r1=%d r2=%d r3=%d" % (c1, c2, c3))
tail = tail.replace(r1_old, r1_new).replace(r2_old, r2_new).replace(r3_old, r3_new)
assert "?…" not in tail, "still has ? placeholder"
s2 = head + tail
data = s2.encode("utf-8")
io.open(DOC, "wb").write(data)
back = io.open(DOC, "rb").read()
log("PATCHED ok=%s size=%d->%d" % (r1_new.encode("utf-8") in back and r3_new.encode("utf-8") in back, len(raw), len(back)))

# ---- 3) dump 最终 §13 全文 ----
b = back.decode("utf-8")
sec13 = b[b.index("## 13."):]
log("[SEC13-FULL]")
for ln in sec13.splitlines():
    log("    " + ln.encode("unicode_escape").decode("ascii"))

# ---- 4) dump QA gate 相关行（供销项补丁） ----
g = io.open(GATE, "r", encoding="utf-8").read()
log("[GATE-ROWS]")
for ln in g.splitlines():
    if re.search(r"\*\*(R-0|O-4|O-5|O-6)\*\*", ln) or ln.startswith("# ") or "一句话结论" in ln or ("放行条件" in ln and ln.startswith("#")):
        log("    " + ln.encode("unicode_escape").decode("ascii")[:400])

io.open(OUT, "w", encoding="utf-8").write("\n".join(rep))
print("SEC13 FIXED placeholders_cleared=%s" % ("?…" not in tail))
