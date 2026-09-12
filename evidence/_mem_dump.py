# -*- coding: utf-8 -*-
"""MEMORY.md 目标行字节级 dump（供精确编辑定位）。报告 -> evidence/_mem_dump.txt"""
import io, re

p = r"D:\code\cordit\.workbuddy\memory\MEMORY.md"
s = io.open(p, "r", encoding="utf-8").read()
rep = []
for i, ln in enumerate(s.splitlines(), 1):
    if re.search(r"O-5|O-6|当前 GUT|工作区有未提交|待回收|R2 形象|M7-R7|M7-R6|R-0", ln):
        rep.append("L%03d(len=%d) %s" % (i, len(ln), ln.encode("unicode_escape").decode("ascii")))
io.open(r"D:\code\cordit\evidence\_mem_dump.txt", "w", encoding="utf-8").write("\n".join(rep))
print("DUMPED %d lines" % len(rep))
