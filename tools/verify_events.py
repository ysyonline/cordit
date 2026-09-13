# -*- coding: utf-8 -*-
"""
verify_events.py — M8-B① 剧情事件"一次性触发"静态核验器（防复发哨兵）
================================================================================
【为什么需要它】用户实机命中：从 road 进遗迹一层播完剧情，往返后再进又重播；
f3 Boss 剧情同样。根因 = data/json/events/story_anchor.json 两条事件只有**单调**
story_phase 门（>=1 / >=2），无一次性标志 → phase 推进后门仍真 → 每次进图都重播。
本哨兵扫描全部事件表，揪出"带副作用却没有一次性保护"的事件，防同类回归。

【扫描范围】data/json/events/*.json 中含顶层 "events" 字典的文件
  （chests / investigates / teleports 为别的 schema，跳过）。

【判定规则】（对照正本：story_intro.json / party_chat.json ——
  正解形态 = conditions 加 "not_flag": "<id>_seen" + actions 末尾 set_flag）

  白名单（刻意可重复，恒 PASS）：
    W1 demo 事件（id 前缀 ev_demo_ 或其文件为 demo_actions.json）——演示/测试用，
       非生产一次性。
    W2 会话类：无"状态改写型动作"（battle / give_item / set_story_phase）
       且无 story_phase 门——纯对话/回血等，反复触发是正确的（如 NPC 12 条）。

  报 FAIL 的情形（每条为一次 check）：
    F1 含副作用（dialogue / battle / give_item / set_story_phase）且无 not_flag，
       且用**单调门** story_phase >= / >：phase 推进后门仍真 → 可重播。
    F2 含副作用且无 not_flag，且用 **== 门但"粘滞"**：事件自身未把 phase 推进到
       别的值 → == 门保持为真 → 可重播。（对照：story_quest_accept == 0 且自身
       set_story_phase 1 → 推进出 0 → 一次性，属正解，PASS。）
    F3 完全无 conditions 且含 battle / set_story_phase（可无限重复的强副作用）。
    F4 含副作用且无 not_flag，且**既无 story_phase 门也无 not_flag**（非会话类）。

  本次两处历史反例（已修，留作判定锚）：
    · story_ruin_enter：conditions {story_phase: [">=",1]} 曾经无 not_flag → F1。
    · story_boss_pre ：conditions {story_phase: [">=",2]} 曾经无 not_flag → F1。

【用法】python tools/verify_events.py  → 全 PASS 退出码 0；有 FAIL 退出码 1。
独立于运行时：只读 JSON 文本，不起引擎。
"""
import glob
import json
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVENTS_DIR = os.path.join(REPO_ROOT, "data", "json", "events")

## 副作用动作（GDD §3.2 动作清单里会改写世界/流程者）
SIDE_EFFECTS = {"dialogue", "battle", "give_item", "set_story_phase"}
## "状态改写型"动作（会话白名单的排除项：只有它们才可能造成不可逆/可重播副作用）
STATE_MUTATING = {"battle", "give_item", "set_story_phase"}
DEMO_PREFIX = "ev_demo_"

failures = []
passed = 0


def check(name, cond, detail=""):
    global passed
    if cond:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failures.append(name)
        print(f"  FAIL  {name}  {detail}")


def _phase_gate(conds):
    v = conds.get("story_phase")
    if isinstance(v, list) and len(v) >= 2 and isinstance(v[0], str):
        return v[0], v[1]
    return None, None


def audit_event(eid, ev, fname):
    actions = ev.get("actions", []) if isinstance(ev, dict) else []
    atypes = [a.get("type") for a in actions if isinstance(a, dict)]
    conds = ev.get("conditions", {}) if isinstance(ev, dict) else {}
    ckeys = set(conds.keys()) if isinstance(conds, dict) else set()

    # ---- 白名单 W1：demo ----
    if eid.startswith(DEMO_PREFIX) or fname == "demo_actions.json":
        check(f"{eid}（W1 demo 白名单：演示/测试用，非生产一次性）", True)
        return
    # ---- 白名单 W2：会话类（无状态改写动作且无 phase 门 → 刻意可重复）----
    if not any(t in STATE_MUTATING for t in atypes) and "story_phase" not in ckeys:
        check(f"{eid}（W2 会话白名单：无常驻 phase 门、无状态改写动作——可重复）", True)
        return

    has_side = any(t in SIDE_EFFECTS for t in atypes)
    has_not_flag = "not_flag" in ckeys
    op, n = _phase_gate(conds)

    # ---- F3：空 conditions + 强副作用 ----
    if not ckeys and ("battle" in atypes or "set_story_phase" in atypes):
        check(f"{eid}（F3 空 conditions 且含 battle/set_story_phase → 可无限重复）", False,
              "应加 not_flag + actions 末尾 set_flag")
        return
    # ---- 无副作用 → 放行 ----
    if not has_side:
        check(f"{eid}（无副作用动作）", True)
        return
    # ---- 有 not_flag → 一次性保护在位 ----
    if has_not_flag:
        check(f"{eid}（一次性保护区在位：not_flag={conds.get('not_flag')}）", True)
        return
    # ---- F1：单调门 ----
    if op in (">=", ">"):
        check(f"{eid}（F1 单调门 story_phase {op} {n} 且无 not_flag → 推进后仍真 → 可重播）",
              False, "应加 not_flag + actions 末尾 set_flag（对照 story_intro/party_chat）")
        return
    # ---- F2：== 门粘滞（事件自身未推进出该值）----
    if op == "==":
        advances = any(
            (a.get("type") == "set_story_phase" and int(a.get("phase", n)) != n)
            for a in actions if isinstance(a, dict))
        if advances:
            check(f"{eid}（== {n} 门且自身推进 phase → 一次性，正解）", True)
        else:
            check(f"{eid}（F2 == {n} 门粘滞：事件未推进出该值且无 not_flag → 可重播）", False,
                  "应加 not_flag + set_flag")
        return
    # ---- F4：既无 phase 门也无 not_flag 的副作用事件 ----
    check(f"{eid}（F4 无 phase 门亦无 not_flag，含副作用 → 可重播）", False,
          "应加 not_flag + actions 末尾 set_flag")


def main():
    print("== 事件一次性触发核验（data/json/events/*.json）==")
    n_events = 0
    n_files = 0
    for path in sorted(glob.glob(os.path.join(EVENTS_DIR, "*.json"))):
        fname = os.path.basename(path)
        try:
            data = json.load(open(path, encoding="utf-8"))
        except Exception as e:   # noqa: BLE001
            check(f"{fname} JSON 可解析", False, str(e))
            continue
        if not isinstance(data, dict) or "events" not in data:
            continue   # 非事件表（chests / investigates / teleports）
        n_files += 1
        for eid, ev in data["events"].items():
            n_events += 1
            audit_event(eid, ev, fname)

    print(f"\n扫描事件表 {n_files} 份 / 事件 {n_events} 条")
    print(f"PASS {passed} / FAIL {len(failures)}")
    if failures:
        print("失败项:")
        for f in failures:
            print(" -", f)
        sys.exit(1)
    print("全部通过 ✅")


if __name__ == "__main__":
    main()
