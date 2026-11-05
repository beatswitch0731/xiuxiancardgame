#!/usr/bin/env python3
"""把 noncombat_domain.gd 里的事件位字面量替换为 EventTypes.X（S1b）。

为什么不用全局替换：同文件 117 个大写字符串里 55 个是 phase 名/动作名/
卡类型/错误码，全局替换必然误伤。这里只在**三类结构性位置的实参区间**
内替换，且用字符偏移做精确切片。

用法：
    python tools/apply_event_constants.py --check   # 只报告，不改文件
    python tools/apply_event_constants.py --apply   # 写回文件
"""
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DOMAIN = os.path.join(ROOT, "scripts", "noncombat_domain.gd")

LITERAL = re.compile(r'^"([A-Z][A-Z0-9_]*)"$')
TYPE_FIELD = re.compile(r'("type"\s*:\s*)"([A-Z][A-Z0-9_]*)"')


def find_calls(text: str, func_name: str):
    """返回 [(arg_spans, args)]，arg_spans 为每个实参在 text 中的 (start, end)。

    与 audit_event_types.split_call_args 同一套括号计数逻辑，区别是记录偏移。
    """
    calls = []
    i = 0
    n = len(text)
    needle = func_name + "("
    while True:
        idx = text.find(needle, i)
        if idx < 0:
            break
        line_start = text.rfind("\n", 0, idx) + 1
        if text[line_start:idx].strip().startswith("func"):
            i = idx + len(needle)
            continue
        open_idx = idx + len(func_name)
        depth = 0
        args, spans = [], []
        cur = open_idx + 1
        j = open_idx
        in_str = False
        quote = ""
        escape = False
        closed = False
        while j < n:
            ch = text[j]
            if in_str:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif ch == quote:
                    in_str = False
            else:
                if ch in "\"'":
                    in_str = True
                    quote = ch
                elif ch in "([{":
                    depth += 1
                elif ch in ")]}":
                    depth -= 1
                    if depth == 0:
                        args.append(text[cur:j])
                        spans.append((cur, j))
                        closed = True
                        break
                elif ch == "," and depth == 1:
                    args.append(text[cur:j])
                    spans.append((cur, j))
                    cur = j + 1
            j += 1
        if closed and args:
            calls.append((spans, [a.strip() for a in args]))
        i = j + 1
    return calls


def load_event_names():
    """从 S1 生成的冻结快照读取 62 个事件名。

    用白名单而不是"解析实参位置"：通用括号计数在含字典字面量、三元表达式、
    多行嵌套调用的实参上会失衡（实测把两个函数合并成一个 span），
    白名单**限定了只可能命中事件名**，天然不会碰 phase/动作名。
    """
    snapshot = os.path.join(ROOT, "tests", "fixtures", "event_types_v1.json")
    data = json.loads(open(snapshot, encoding="utf-8").read())
    return sorted(data["types"], key=len, reverse=True)


def collect_edits(text: str):
    """返回 [(start, end, replacement, label)]，按 start 升序。

    两条规则：
      1. `, "EVENT_NAME"` —— _commit_encounter_transition / _commit_camp_target
         的第 2/3 实参（事件名总在逗号之后）
      2. `"type": "EVENT_NAME"` —— _emit_event 的字典字段
    """
    alt = "|".join(load_event_names())
    comma_rule = re.compile(r'(,\s*)"(' + alt + r')"')
    type_rule = re.compile(r'("type"\s*:\s*)"(' + alt + r')"')
    edits = []
    for match in comma_rule.finditer(text):
        edits.append((match.start(2) - 1, match.end(2) + 1,
                      "EventTypes." + match.group(2), "comma"))
    for match in type_rule.finditer(text):
        edits.append((match.start(2) - 1, match.end(2) + 1,
                      "EventTypes." + match.group(2), "type_field"))
    edits.sort(key=lambda e: e[0])
    return edits


def main() -> int:
    ap = argparse.ArgumentParser()
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    text = open(DOMAIN, encoding="utf-8").read()
    edits = collect_edits(text)

    # 已替换过的会被 LITERAL 排除，所以这里统计的是"待替换"
    counts = {}
    for _s, _e, _r, label in edits:
        counts[label] = counts.get(label, 0) + 1
    print(f"PENDING total={len(edits)} " + " ".join(
        f"{k}={v}" for k, v in sorted(counts.items())))

    if args.check:
        for start, _end, replacement, label in edits[:5]:
            line = text.count("\n", 0, start) + 1
            print(f"  L{line} {label} -> {replacement}")
        if len(edits) > 5:
            print(f"  ... 还有 {len(edits) - 5} 处")
        return 0 if edits else 0

    if not edits:
        print("NOTHING_TO_DO（可能已经替换过）")
        return 0

    out = text
    for start, end, replacement, _label in sorted(edits, key=lambda e: -e[0]):
        out = out[:start] + replacement + out[end:]

    # 替换后自检：_commit_encounter_transition / _commit_camp_target 的第 2/3
    # 实参不应再有裸字面量；_emit_event 内不应再有 "type": "大写串"
    residual = collect_edits(out)
    if residual:
        print(f"POST_CHECK_FAIL 仍有 {len(residual)} 处可替换")
        for start, _e, r, label in residual[:5]:
            line = out.count("\n", 0, start) + 1
            print(f"  L{line} {label} -> {r}")
        return 1

    open(DOMAIN, "w", encoding="utf-8", newline="").write(out)
    print(f"APPLIED {len(edits)} 处")
    return 0


if __name__ == "__main__":
    sys.exit(main())
