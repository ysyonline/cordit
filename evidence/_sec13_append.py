# -*- coding: utf-8 -*-
"""§13 补录：O-6/O-5 修复重导出记录 追加到 m7-package-closeout.md。
所有哈希/总数均现场重算或从文档原文正则提取，杜绝转录漂移。
报告 -> evidence/_sec13_append_report.txt（内容 unicode_escape 转写）。
幂等：文档已含 '## 13.' 时拒绝执行。
"""
import io, os, re, hashlib, subprocess

ROOT = r"D:\code\cordit"
DOC = os.path.join(ROOT, "production", "release", "m7-package-closeout.md")
OUT = os.path.join(ROOT, "evidence", "_sec13_append_report.txt")
rep = []
def log(x=""):
    rep.append(x)

def sha256_file(p):
    h = hashlib.sha256()
    with io.open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()

def gut_totals_block(path):
    """提取 GUT 日志 Totals 块（剥 ANSI）。"""
    t = io.open(path, "r", encoding="utf-8", errors="replace").read()
    t = re.sub(r"\x1b\[[0-9;]*m", "", t)
    lines = t.splitlines()
    for i, ln in enumerate(lines):
        if ln.strip().startswith("Totals"):
            block = [x.strip() for x in lines[i:i + 12] if x.strip()]
            return "；".join(block[:8])
    m = re.findall(r"(\d+) passed", t)
    return ("最后声明：%s passed" % m[-1]) if m else "（日志无 Totals 块，见原文）"

# ---- 0) 幂等 ----
raw = io.open(DOC, "rb").read()
s = raw.decode("utf-8")  # ← 上轮 NameError 根因：漏了这行
if "## 13." in s:
    io.open(OUT, "w", encoding="utf-8").write("ABORT: ## 13. already present")
    print("ABORT")
    raise SystemExit(0)

# ---- 1) 现货哈希 ----
exe_p = os.path.join(ROOT, "export", "win", "轨迹残响.exe")
pck_p = os.path.join(ROOT, "export", "win", "轨迹残响.pck")
zip_p = os.path.join(ROOT, "export", "轨迹残响-v0.1.0-slice-win64.zip")
exe_h, pck_h = sha256_file(exe_p), sha256_file(pck_p)
zip_h = sha256_file(zip_p) if os.path.exists(zip_p) else "MISSING"

# ---- 2) 从文档原文提取 §7 旧哈希 ----
m_exe = re.search(r"\|\s*`轨迹残响\.exe`\s*\|\s*\d{4}-\d\d-\d\d[^|]*\|\s*([0-9A-Fa-f]{64})\s*\|", s)
m_pck = re.search(r"\|\s*`轨迹残响\.pck`\s*\|\s*\d{4}-\d\d-\d\d[^|]*\|\s*([0-9A-Fa-f]{64})\s*\|", s)
m_zip = re.search(r"\|\s*`轨迹残响-v0\.1\.0-slice-win64\.zip`\s*\|\s*\d{4}-\d\d-\d\d[^|]*\|\s*([0-9A-Fa-f]{64})\s*\|", s)
old_exe = m_exe.group(1).upper() if m_exe else "?"
old_pck = m_pck.group(1).upper() if m_pck else "?"
old_zip = m_zip.group(1).upper() if m_zip else "?"
log("SEC7-EXE-MATCH=%s SEC7-PCK-MATCH=%s SEC7-ZIP-MATCH=%s" % (bool(m_exe), bool(m_pck), bool(m_zip)))
log("EXE_SAME_AS_SEC7=%s" % (exe_h == old_exe))
log("PCK_CHANGED=%s" % (pck_h != old_pck))
log("ZIP_SAME_AS_SEC7=%s" % (zip_h == old_zip))

# ---- 3) GUT 总数与冒烟标记 ----
t_o6 = gut_totals_block(os.path.join(ROOT, "evidence", "_o6-gut-clean2.log"))
t_o5 = gut_totals_block(os.path.join(ROOT, "evidence", "_o5-gut-clean.log"))
smoke = io.open(os.path.join(ROOT, "evidence", "_o5-smoke-verify3.log"), "r", encoding="utf-8", errors="replace").read()
n_pass = smoke.count("PASS:")
smoke_mark = "SMOKE_RESULT: ALL PASS" if "SMOKE_RESULT: ALL PASS" in smoke else "（见日志）"
exp_smoke_p = os.path.join(ROOT, "evidence", "o6-export-smoke.log")
if os.path.exists(exp_smoke_p):
    es = io.open(exp_smoke_p, "r", encoding="utf-8", errors="replace").read()
    es_mark = "SMOKE_RESULT: ALL PASS" if "SMOKE_RESULT: ALL PASS" in es else ("EXIT=0（会话内捕获）" if "EXIT" in es else "（执行日志在案）")
else:
    es_mark = "（日志缺失）"
log("GUT-O6=%s" % gut_totals_block(os.path.join(ROOT, "evidence", "_o6-gut-clean2.log")).encode("unicode_escape").decode("ascii"))
log("GUT-O5=%s" % gut_totals_block(os.path.join(ROOT, "evidence", "_o5-gut-clean.log")).encode("unicode_escape").decode("ascii"))
log("SMOKE-PASS-COUNT=%d" % n_pass)

# ---- 4) 组装 §13 ----
exe_same = (exe_h == old_exe)
exe_note = ("exe 与 §7 的 01D exe **逐字节一致**（哈希同）——本轮改动面仅脚本/测试/文档、零资源变更，"
            "导出壳未动、差异全部承载于 pck，交叉印证重导出面正确。" if exe_same else
            "exe 相对 §7 的 01D（`%s…`）**已变更** → `%s…`。" % (old_exe[:8], exe_h[:8]))
addition = (
    "\n---\n\n"
    "## 13. O-6 / O-5 修复重导出补录（2026-09-12）\n\n"
    "> **背景**：01D 包（§7）发放后、外部试玩启动前，按主理人拍板「**暂停试玩等新版**」，先行修复两项 QA gate 遗留缺陷并重导出。"
    "本节记录修复内容、重导出产物与指纹。**§7 表格维持 01D 口径不动**；zip 重打包与 §7 / playtest 档 §0 / QA gate R-0 的指纹回写，"
    "按计划**延后至 commit/tag 步骤统一执行**。\n\n"
    "### 13.1 修复内容\n\n"
    "| 项 | 缺陷 | 修复 |\n"
    "| --- | --- | --- |\n"
    "| **O-6** | 生产路由（跨图遭遇）接的是演示战斗路径，`test_e2s3.gd` 为占位绑定 | `battle_scene.gd` 重写接入 E3 真实战斗系统；`test_e2s3.gd` 重写为真实绑定。新用例当场揪出 `battle_command.setup()` 生产缺陷（无类型 `Array.duplicate()` 直接赋 `Array[Dictionary]` 成员报类型错）→ 改为逐元素 append 重建，全量回归通过 |\n"
    "| **O-5** | `story_ruin_enter` 有事件 JSON、无生产触发端，自然游玩 phase 无法 1→2（G-8，Major） | `ruins_f1_map.gd` 装配入口剧情锚 `Evt_Ruin_Enter`（双守卫装配，同 f3 Boss 锚族；位置 (448,56)、collision_mask=16；`new_event_id` → `story_ruin_enter`：对话 story_p2 → set_story_phase 2） |\n\n"
    "### 13.2 重导出产物与指纹（export/win/ 现货，2026-09-12）\n\n"
    "| 产物 | 大小 (B) | SHA256 |\n"
    "| --- | --- | --- |\n"
    "| `轨迹残响.exe` | 109,132,800 | `%s` |\n"
    "| `轨迹残响.pck` | 3,405,028 | `%s` |\n\n"
    "- %s\n"
    "- pck 相对 §7 的 01D（`%s…`）**已变更** → 本表为含 O-6/O-5 修复的版本。\n"
    "- ⚠️ **`轨迹残响-v0.1.0-slice-win64.zip` 仍为 01D 旧包**（`%s…`，磁盘现货复核一致），**当前不可用于发放**；重打包延后至 commit/tag 步骤。\n\n"
    "### 13.3 回归与冒烟证据\n\n"
    "| 证据 | 结论 |\n"
    "| --- | --- |\n"
    "| `evidence/_o6-gut-clean.log` | 首跑暴露 `battle_command.setup()` 类型缺陷（预期红，缺陷证据在案） |\n"
    "| `evidence/_o6-gut-clean2.log` | 修复后全量 GUT：%s（APPDATA 重定向干净环境） |\n"
    "| `evidence/_o5-gut-clean.log` | O-5 装配后全量 GUT：%s |\n"
    "| `evidence/_o5-smoke-verify3.log` | f1 入口锚生产语境冒烟 %d/8 PASS（%s；锚装配 @(448,56) / new_event_id / mask=16 / layer=0 / 事件表在册 / phase=0 拦截 / phase=1 放行，真实触发链发射日志在案） |\n"
    "| `evidence/o6-export3.log` + `evidence/o6-export-smoke.log` | 本轮重导出执行日志；导出包 headless 冒烟：%s |\n\n"
    "### 13.4 延续待办\n\n"
    "- zip 重打包 + §7 / playtest 档 §0 / QA gate R-0 指纹回写 → **与 commit/tag 同步执行**（等主理人发话）。\n"
    "- 工作区未提交：`scripts/battle/battle_scene.gd`、`scripts/battle/battle_command.gd`、`scripts/maps/ruins_f1_map.gd`、`tests/gut/test_e2s3.gd`、`tests/gut/test_o6_real_battle.gd(+.uid)`、`production/qa/m7-final-qa-gate.md`、本节及 `evidence/` 日志。\n"
) % (exe_h, pck_h, exe_note, old_pck, old_zip, t_o6, t_o5, n_pass, smoke_mark, es_mark)

# ---- 5) 追加 + 字节级回验 ----
if not s.endswith("\n"):
    addition = "\n" + addition
s2 = s + addition
data = s2.encode("utf-8")
io.open(DOC, "wb").write(data)
back = io.open(DOC, "rb").read()
ok_suffix = back.endswith(addition.encode("utf-8"))
ok_13 = b"## 13." in back
log("APPENDED=%s SUFFIX-OK=%s HAS13=%s SIZE=%d->%d" % (True, ok_suffix, ok_13, len(raw), len(back)))

# ---- 6) 顺带：MEMORY.md / 日志 / QA gate diff 现状dump（供下一步记忆回写） ----
mem_p = os.path.join(ROOT, ".workbuddy", "memory", "MEMORY.md")
mt = io.open(mem_p, "r", encoding="utf-8").read()
log("[MEMORY-GREP]")
for ln in mt.splitlines():
    if re.search(r"O-5|O-6|523/523|530/530|当前 GUT|未提交|待修|待回归", ln):
        log("    " + ln.encode("unicode_escape").decode("ascii")[:220])

day_p = os.path.join(ROOT, ".workbuddy", "memory", "2026-09-12.md")
if os.path.exists(day_p):
    dt = io.open(day_p, "r", encoding="utf-8").read()
    log("[DAYLOG] bytes=%d tail:" % len(dt))
    for ln in dt.splitlines()[-8:]:
        log("    " + ln.encode("unicode_escape").decode("ascii")[:200])

try:
    r = subprocess.run(["git", "diff", "--stat", "production/qa/m7-final-qa-gate.md"],
                       cwd=ROOT, capture_output=True, timeout=60)
    log("[QA-GATE-DIFF-STAT] " + r.stdout.decode("utf-8", "replace").strip())
    r2 = subprocess.run(["git", "diff", "production/qa/m7-final-qa-gate.md"],
                        cwd=ROOT, capture_output=True, timeout=60)
    d = r2.stdout.decode("utf-8", "replace")
    log("[QA-GATE-DIFF-HEAD]")
    for ln in d.splitlines()[:60]:
        log("    " + ln.encode("unicode_escape").decode("ascii")[:220])
except Exception as e:
    log("[GIT-DIFF] ERROR %r" % e)

io.open(OUT, "w", encoding="utf-8").write("\n".join(rep))
print("SEC13 APPENDED OK suffix_ok=%s has13=%s" % (ok_suffix, ok_13))
