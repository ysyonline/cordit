# -*- coding: utf-8 -*-
"""O-6/O-5 重导出补录前置校验（只读，不写任何业务文件）。
报告 -> evidence/_sec13_verify_report.txt（UTF-8）。
非 ASCII 一律 unicode_escape 转写，规避显示层漂移。
"""
import io, os, re, hashlib, glob, time, subprocess

ROOT = r"D:\code\cordit"
OUT = os.path.join(ROOT, "evidence", "_sec13_verify_report.txt")
rep = []

def log(x=""):
    rep.append(x)

def esc(x):
    return x.encode("unicode_escape").decode("ascii")

# 1) 关键证据日志存在性 + 关键行
for name in ["_o6-gut-clean2.log", "_o6-gut-clean.log", "_o5-gut-clean.log", "_o5-smoke-verify3.log"]:
    p = os.path.join(ROOT, "evidence", name)
    if os.path.exists(p):
        t = io.open(p, "r", encoding="utf-8", errors="replace").read()
        key = [ln for ln in t.splitlines() if re.search(r"(passed|failed|Totals|PASS|FAIL|EXIT|Traceback|ERROR)", ln)]
        log("[EVIDENCE] %s size=%d" % (name, os.path.getsize(p)))
        for ln in key[-10:]:
            log("    " + esc(ln))
    else:
        log("[EVIDENCE] %s MISSING" % name)

log("[EVIDENCE-GLOB] _o*.log")
for p in sorted(glob.glob(os.path.join(ROOT, "evidence", "_o*.log"))):
    log("    " + os.path.basename(p))

# 2) 导出包指纹重算 + 目录清点
log("[EXPORT-DIR]")
for p in sorted(glob.glob(os.path.join(ROOT, "export", "win", "*"))):
    log("    %s size=%d" % (esc(os.path.basename(p)), os.path.getsize(p)))
for tag, rel in [("EXE", u"export/win/\u8f68\u8ff9\u6b8b\u54cd.exe"), ("PCK", u"export/win/\u8f68\u8ff9\u6b8b\u54cd.pck")]:
    p = os.path.join(ROOT, rel)
    if os.path.exists(p):
        h = hashlib.sha256()
        with io.open(p, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        log("[HASH-%s] size=%d sha256=%s" % (tag, os.path.getsize(p), h.hexdigest().upper()))
    else:
        log("[HASH-%s] MISSING" % tag)
for p in sorted(glob.glob(os.path.join(ROOT, "export", "*.zip"))):
    log("[ZIP] %s size=%d mtime=%s" % (esc(os.path.basename(p)), os.path.getsize(p),
        time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(p)))))

# 3) closeout 文档现状
doc = os.path.join(ROOT, "production", "release", "m7-package-closeout.md")
raw = io.open(doc, "rb").read()
s = raw.decode("utf-8")
log("[DOC] bytes=%d crlf=%s sections=%s has13=%s" % (len(raw), b"\r\n" in raw,
    re.findall(r"^## (\d+)\.", s, re.M), ("## 13." in s)))
log("[DOC-TAIL-30]")
for ln in s.splitlines()[-30:]:
    log("    " + ln)

# 4) production 文档中的 64 位指纹引用点（供 R-0 / playtest 档 §0 回写定位）
log("[FINGERPRINT-REFS]")
n = 0
for p in glob.glob(os.path.join(ROOT, "production", "**", "*.md"), recursive=True):
    try:
        t = io.open(p, "r", encoding="utf-8", errors="replace").read()
    except Exception:
        continue
    for m in re.finditer(r"^[^\n]*[0-9A-Fa-f]{64}[^\n]*$", t, re.M):
        n += 1
        log("    %s :: %s" % (esc(os.path.relpath(p, ROOT)), esc(m.group(0))[:150]))
log("    total=%d" % n)

# 5) git 工作区现状
try:
    r = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, timeout=60)
    lines = [ln for ln in r.stdout.decode("utf-8", "replace").splitlines() if ln.strip()]
    log("[GIT-STATUS] count=%d" % len(lines))
    for ln in lines[:80]:
        log("    " + esc(ln))
    r2 = subprocess.run(["git", "log", "--oneline", "-3"], cwd=ROOT, capture_output=True, timeout=60)
    log("[GIT-LOG] " + esc(r2.stdout.decode("utf-8", "replace").strip()))
except Exception as e:
    log("[GIT] ERROR %r" % e)

io.open(OUT, "w", encoding="utf-8").write("\n".join(rep))
print("VERIFY REPORT WRITTEN lines=%d" % len(rep))
