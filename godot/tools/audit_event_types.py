#!/usr/bin/env python3
"""事件类型提取器：从 noncombat_domain.gd 结构化提取全部事件类型。

为什么不用全局正则替换：domain 内有 117 个大写字符串字面量，其中 55 个
是 phase 名（NORMAL_PENDING）、动作名（PLAY_CARD/END_TURN）、卡类型
（NORMAL/LOCATION）或错误码（SOURCE_UNAVAILABLE）——全局替换会误伤。

因此只在三类**结构性位置**提取：
  A 组：_commit_encounter_transition(...) 的第 2 个实参
  B 组：_commit_camp_target(...) 的第 3 个实参
  C 组：_emit_event({... "type": "XXX" ...}) 里紧跟在 "type": 后的字面量
        （必须锚定 "type": 前缀；L3171 的三元表达式里还有 "DEATH_PENDING"
         这种 phase 名，用"取最后一个大写串"的启发式会抓错）

用法：
    python tools/audit_event_types.py --check    # 校验常量表与源码是否一致
    python tools/audit_event_types.py --write    # 生成常量表与冻结快照
    python tools/audit_event_types.py --dump     # 只打印提取结果
"""
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DOMAIN = os.path.join(ROOT, "scripts", "noncombat_domain.gd")
CONST_FILE = os.path.join(ROOT, "scripts", "noncombat_event_types.gd")
SNAPSHOT = os.path.join(ROOT, "tests", "fixtures", "event_types_v1.json")

LITERAL = re.compile(r'^"([A-Z][A-Z0-9_]*)"$')
TYPE_FIELD = re.compile(r'"type"\s*:\s*"([A-Z][A-Z0-9_]*)"')


def split_call_args(text: str, func_name: str):
    """返回 [(line_no, [arg_str, ...]), ...]，按括号计数切分实参。

    正确处理：嵌套括号、字符串内的括号与逗号、跨行调用、转义引号。
    跳过 `func xxx(` 定义行。
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
        prefix = text[line_start:idx].strip()
        # 注意用 "func"（不带尾空格）：strip() 已去掉 "func " 的尾随空格
        if prefix.startswith("func"):
            i = idx + len(needle)
            continue
        open_idx = idx + len(func_name)
        depth = 0
        args = []
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
                        closed = True
                        break
                elif ch == "," and depth == 1:
                    args.append(text[cur:j])
                    cur = j + 1
            j += 1
        if closed and args:
            calls.append((text.count("\n", 0, idx) + 1, [a.strip() for a in args]))
        i = j + 1
    return calls


def extract():
    text = open(DOMAIN, encoding="utf-8").read()
    a_group, unparsed_a = [], []
    for line, args in split_call_args(text, "_commit_encounter_transition"):
        if len(args) < 2:
            unparsed_a.append((line, args))
            continue
        m = LITERAL.match(args[1])
        if not m:
            # _commit_camp_target 把 event_type 变量透传进来（L5101/L5113 已覆盖），
            # 这类动态调用不算未解析
            if args[1].strip() == "event_type":
                continue
            unparsed_a.append((line, args))
            continue
        a_group.append(m.group(1))

    b_group, unparsed_b = [], []
    for line, args in split_call_args(text, "_commit_camp_target"):
        if len(args) < 3:
            unparsed_b.append((line, args))
            continue
        m = LITERAL.match(args[2])
        if not m:
            unparsed_b.append((line, args))
            continue
        b_group.append(m.group(1))

    c_group = []
    for _line, args in split_call_args(text, "_emit_event"):
        if not args:
            continue
        m = TYPE_FIELD.search(args[0])
        if m:
            c_group.append(m.group(1))

    return (sorted(set(a_group)), sorted(set(b_group)), sorted(set(c_group)),
            unparsed_a, unparsed_b)


def expected():
    """从源码计算应得的事件类型集合与前缀断言。"""
    a, b, c, unparsed_a, unparsed_b = extract()
    if unparsed_a or unparsed_b:
        print("UNPARSED calls (需人工处理)：")
        for line, args in unparsed_a + unparsed_b:
            print(f"  L{line}: {args}")
        return None
    return {"A": a, "B": b, "C": c, "all": sorted(set(a) | set(b) | set(c))}


def render_const_file(types) -> str:
    lines = [
        "extends RefCounted",
        "",
        "## 事件类型常量表（自动生成，请勿手改）。",
        "## 生成：python tools/audit_event_types.py --write",
        "## 校验：python tools/audit_event_types.py --check",
        "##",
        "## 为什么需要这张表：noncombat_domain.gd 里 117 个大写字符串字面量中，",
        "## 55 个是 phase 名 / 动作名 / 卡类型 / 错误码，只有 62 个是事件类型。",
        "## _emit_event() 用 is_event_type() 做白名单校验，拼错或漏登记会立刻报错。",
        "",
    ]
    for name in types:
        lines.append(f'const {name} := "{name}"')
    lines.append("")
    lines.append("const ALL := [")
    for name in types:
        lines.append(f'\t"{name}",')
    lines.append("]")
    lines.append("")
    lines.append("")
    lines.append("static func is_event_type(value: String) -> bool:")
    lines.append("\treturn ALL.has(value)")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--dump", action="store_true")
    args = ap.parse_args()

    data = expected()
    if data is None:
        return 1
    print(f"EXTRACT A={len(data['A'])} B={len(data['B'])} "
          f"C={len(data['C'])} union={len(data['all'])}")
    if args.dump:
        for name in data["all"]:
            print("  " + name)
        return 0
    if len(data["all"]) != 62:
        print(f"ASSERT_FAIL union 应为 62，实际 {len(data['all'])}")
        for name in data["all"]:
            print("  " + name)
        return 1

    if args.write:
        os.makedirs(os.path.dirname(CONST_FILE), exist_ok=True)
        with open(CONST_FILE, "w", encoding="utf-8", newline="") as fh:
            fh.write(render_const_file(data["all"]))
        os.makedirs(os.path.dirname(SNAPSHOT), exist_ok=True)
        with open(SNAPSHOT, "w", encoding="utf-8", newline="") as fh:
            json.dump({"version": 1, "count": len(data["all"]),
                       "types": data["all"]}, fh, ensure_ascii=False, indent=1)
            fh.write("\n")
        print(f"WROTE {os.path.relpath(CONST_FILE, ROOT)}")
        print(f"WROTE {os.path.relpath(SNAPSHOT, ROOT)}")
        return 0

    # --check：常量表与快照都必须与源码一致
    problems = []
    if not os.path.isfile(CONST_FILE):
        problems.append("常量表缺失")
    else:
        current = open(CONST_FILE, encoding="utf-8").read()
        want = render_const_file(data["all"])
        if current != want:
            problems.append("常量表与源码不一致（跑 --write 重新生成）")
    if not os.path.isfile(SNAPSHOT):
        problems.append("冻结快照缺失")
    else:
        snap = json.load(open(SNAPSHOT, encoding="utf-8"))
        if sorted(snap.get("types", [])) != data["all"]:
            problems.append("快照与源码不一致")
    if problems:
        for p in problems:
            print("CHECK_FAIL " + p)
        return 1
    print("EVENT_TYPES_CHECK_PASS count=62")
    return 0


if __name__ == "__main__":
    sys.exit(main())
