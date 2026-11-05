#!/usr/bin/env python3
"""全量测试 runner（补齐项目基建缺口：此前无一键全量执行）。

用法：
    python tools/run_test_suite.py [--timeout 120] [--filter SUBSTR]

行为：
- 收集 tests/*.gd 中 extends SceneTree 的测试
- 逐个 headless 执行（默认单测超时 120 秒）
- 已知超时清单（任务书 §8.3）自动用 700 秒单独跑
- 汇总 PASS / FAIL / TIMEOUT，失败清单写入 output/test_suite_report.json
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPO = os.path.dirname(ROOT)
GODOT = os.path.join(REPO, ".godot-toolchain", "godot-4.7.2",
                     "Godot_v4.7.2-stable_win64_console.exe")

# 任务书 §8.3 的已知耗时测试：单独给长超时
SLOW = {
    "noncombat_choice_echo_public_seed": 400,
    "noncombat_faction_combat": 400,
    "noncombat_faction_natural": 700,
    "noncombat_q_fellow_outcomes": 400,
}


def _first_extends(text: str) -> str:
    match = re.search(r"^\s*extends\s+(.+)$", text, re.MULTILINE)
    return match.group(1).strip() if match else ""


def classify_test_file(path: str, depth: int = 0, visited: set | None = None) -> str:
    """判定一个 tests/*.gd 是 test / helper / skip。

    旧实现只看文件前 400 字符是否含 "extends SceneTree"，会静默丢掉
    `extends "res://tests/xxx.gd"` 这类子类测试（实测 405 个 .gd 只收 240 个）。
    这里递归解析基类链，并要求本文件自己定义 _run 或 _initialize，
    从而把纯 helper（如 noncombat_faction_natural.gd）正确排除。
    """
    if depth > 8:
        return "helper"
    visited = set() if visited is None else visited
    key = os.path.normcase(path)
    if key in visited:
        return "helper"
    visited.add(key)
    try:
        text = open(path, encoding="utf-8", errors="ignore").read()
    except OSError:
        return "helper"
    if "# SUITE_SKIP:" in text:
        return "skip"
    base = _first_extends(text)
    if not base:
        return "helper"
    if base.split("(")[0].strip() == "SceneTree":
        return "test" if "func _initialize(" in text else "helper"
    match = re.search(r'"res://(.+?\.gd)"', base)
    if not match:
        return "helper"
    base_path = os.path.join(ROOT, match.group(1))
    if not os.path.isfile(base_path):
        return "helper"
    if classify_test_file(base_path, depth + 1, visited) != "test":
        return "helper"
    return "test" if ("func _run(" in text or "func _initialize(" in text) else "helper"


def discover_tests(tests_dir: str, name_filter: str) -> tuple[list, list, list]:
    targets, skipped, helpers = [], [], []
    for name in sorted(os.listdir(tests_dir)):
        if not name.endswith(".gd") or name.endswith(".uid"):
            continue
        if name_filter not in name:
            continue
        kind = classify_test_file(os.path.join(tests_dir, name))
        stem = name[:-3]
        if kind == "test":
            targets.append(stem)
        elif kind == "skip":
            skipped.append(stem)
        else:
            helpers.append(stem)
    return targets, skipped, helpers


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--filter", default="")
    ap.add_argument("--explain", action="store_true",
                    help="打印 helper / skip 明细，便于核对收集规则")
    ap.add_argument("--list-only", action="store_true",
                    help="只打印收集结果，不执行测试、不写报告")
    ap.add_argument("--report", default="",
                    help="报告输出路径（默认 output/test_suite_report.json）")
    args = ap.parse_args()

    tests_dir = os.path.join(ROOT, "tests")
    targets, skipped, helpers = discover_tests(tests_dir, args.filter)
    print(f"SCENE_TREE tests: {len(targets)} "
          f"(skipped={len(skipped)} helpers={len(helpers)})", flush=True)
    if args.explain:
        for stem in helpers:
            print(f"  HELPER {stem}")
        for stem in skipped:
            print(f"  SKIP   {stem}")
    if args.list_only:
        return 0
    if not targets:
        print("SUITE_EMPTY: 未收集到任何测试，拒绝写报告（避免覆盖既有基线）")
        return 2

    results = {"pass": [], "fail": [], "timeout": [], "error": []}
    started = time.time()
    for i, name in enumerate(targets):
        timeout = SLOW.get(name, args.timeout)
        cmd = [GODOT, "--headless", "--path", ROOT,
               "--script", f"res://tests/{name}.gd"]
        one_started = time.time()
        # 用 Popen + communicate 而非 run：超时时能保住已产生的输出
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True,
                                encoding="utf-8", errors="replace", cwd=ROOT)
        try:
            out, _ = proc.communicate(timeout=timeout)
            rc = proc.returncode
            if ("_PASS" in out) or (rc == 0 and "FAIL" not in out
                                    and "SCRIPT ERROR" not in out):
                results["pass"].append(name)
            else:
                results["fail"].append({"name": name, "rc": rc, "tail": out[-500:]})
        except subprocess.TimeoutExpired:
            proc.kill()
            out, _ = proc.communicate()
            elapsed_one = time.time() - one_started
            log_dir = os.path.join(ROOT, "output", "test_timeout")
            os.makedirs(log_dir, exist_ok=True)
            log_path = os.path.join(log_dir, name + ".log")
            with open(log_path, "w", encoding="utf-8") as fh:
                fh.write(out or "")
            lines = (out or "").strip().splitlines()
            results["timeout"].append({
                "name": name,
                "elapsedSec": round(elapsed_one, 1),
                "stdoutBytes": len(out or ""),
                "lastLine": lines[-1][:200] if lines else "",
                "log": os.path.relpath(log_path, ROOT).replace("\\", "/"),
            })
        if (i + 1) % 20 == 0:
            print(f"  ... {i + 1}/{len(targets)} "
                  f"(pass={len(results['pass'])} fail={len(results['fail'])} "
                  f"timeout={len(results['timeout'])})", flush=True)

    elapsed = time.time() - started
    print(f"\nSUITE_DONE pass={len(results['pass'])} fail={len(results['fail'])} "
          f"timeout={len(results['timeout'])} elapsed={elapsed:.0f}s", flush=True)
    for t in results["timeout"]:
        print(f"TIMEOUT {t['name']} {t['elapsedSec']}s "
              f"bytes={t['stdoutBytes']} log={t['log']}")
    for f in results["fail"]:
        print(f"FAIL {f['name']} rc={f['rc']}")
        print("  tail:", f["tail"][-200:].replace("\n", " | "))

    report = args.report or os.path.join(ROOT, "output", "test_suite_report.json")
    os.makedirs(os.path.dirname(report) or ROOT, exist_ok=True)
    with open(report, "w", encoding="utf-8") as fh:
        json.dump({"elapsedSec": elapsed, "results": results}, fh,
                  ensure_ascii=False, indent=1)
    print(f"report: {report}")
    return 1 if (results["fail"] or results["timeout"]) else 0


if __name__ == "__main__":
    sys.exit(main())
