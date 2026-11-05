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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--filter", default="")
    args = ap.parse_args()

    tests_dir = os.path.join(ROOT, "tests")
    names = sorted(f for f in os.listdir(tests_dir)
                   if f.endswith(".gd")
                   and not f.endswith(".uid")
                   and args.filter in f)
    targets = []
    for f in names:
        path = os.path.join(tests_dir, f)
        head = open(path, encoding="utf-8", errors="ignore").read(400)
        if "extends SceneTree" in head:
            targets.append(f[:-3])
    print(f"SCENE_TREE tests: {len(targets)}", flush=True)

    results = {"pass": [], "fail": [], "timeout": [], "error": []}
    started = time.time()
    for i, name in enumerate(targets):
        timeout = SLOW.get(name, args.timeout)
        cmd = [GODOT, "--headless", "--path", ROOT,
               "--script", f"res://tests/{name}.gd"]
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True,
                                  timeout=timeout, cwd=ROOT)
            out = (proc.stdout or "") + (proc.stderr or "")
            if "_PASS" in out or proc.returncode == 0 and "FAIL" not in out:
                results["pass"].append(name)
            else:
                results["fail"].append({"name": name, "rc": proc.returncode,
                                        "tail": out[-500:]})
        except subprocess.TimeoutExpired:
            results["timeout"].append(name)
        if (i + 1) % 20 == 0:
            print(f"  ... {i + 1}/{len(targets)} "
                  f"(pass={len(results['pass'])} fail={len(results['fail'])} "
                  f"timeout={len(results['timeout'])})", flush=True)

    elapsed = time.time() - started
    print(f"\nSUITE_DONE pass={len(results['pass'])} fail={len(results['fail'])} "
          f"timeout={len(results['timeout'])} elapsed={elapsed:.0f}s", flush=True)
    for t in results["timeout"]:
        print(f"TIMEOUT {t}")
    for f in results["fail"]:
        print(f"FAIL {f['name']} rc={f['rc']}")
        print("  tail:", f["tail"][-200:].replace("\n", " | "))

    os.makedirs(os.path.join(ROOT, "output"), exist_ok=True)
    report = os.path.join(ROOT, "output", "test_suite_report.json")
    with open(report, "w", encoding="utf-8") as fh:
        json.dump({"elapsedSec": elapsed, "results": results}, fh,
                  ensure_ascii=False, indent=1)
    print(f"report: {report}")
    return 1 if (results["fail"] or results["timeout"]) else 0


if __name__ == "__main__":
    sys.exit(main())
