# -*- coding: utf-8 -*-
"""法宝图标交付校验（只读，不修改任何文件）。

用法：
    python tools/validate_treasure_icons.py
    python tools/validate_treasure_icons.py --verbose

检查项：
    1. manifest.json 里 18 项是否齐全
    2. 画布 512x512、RGBA
    3. 四角 alpha == 0（透明底）
    4. alpha 只有 0 或 255（无半透明过渡）
    5. 按 8x8 块对齐（64 逻辑网格，块内颜色必须完全一致 => 无抗锯齿）
    6. 色数 <= 每项上限（默认 16）
退出码 0 = PASS，1 = FAIL。
"""
import json
import os
import sys
from collections import Counter

try:
    from PIL import Image
except ImportError:
    print("TREASURE_ICONS_FAIL reason=PillowNotInstalled")
    sys.exit(1)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # godot/
BRIEF = os.path.join(ROOT, "art_brief", "treasure_icons_v1", "manifest.json")
VERBOSE = "--verbose" in sys.argv

BLOCK = 8
MAX_COLORS = 16

def check_one(item: dict) -> list:
    errs: list = []
    path = os.path.join(ROOT, item["outputPath"].replace("/", os.sep))
    if not os.path.isfile(path):
        return ["missing"]
    try:
        im = Image.open(path)
    except Exception as exc:                        # noqa: BLE001
        return ["unreadable: %s" % exc]
    if im.size != (512, 512):
        errs.append("size=%dx%d" % im.size)
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    # alpha 只能是 0 或 255
    bad_alpha = 0
    for y in range(h):
        for x in range(w):
            a = px[x, y][3]
            if a not in (0, 255):
                bad_alpha += 1
                if bad_alpha > 200:
                    break
        if bad_alpha > 200:
            break
    if bad_alpha:
        errs.append("semi-transparent pixels=%d" % bad_alpha)

    # 四角透明
    for name, (x, y) in (("tl", (0, 0)), ("tr", (w - 1, 0)),
                         ("bl", (0, h - 1)), ("br", (w - 1, h - 1))):
        if px[x, y][3] != 0:
            errs.append("corner %s not transparent" % name)

    # 8x8 块对齐
    misaligned = 0
    for by in range(0, h, BLOCK):
        for bx in range(0, w, BLOCK):
            first = px[bx, by]
            for y in range(by, min(by + BLOCK, h)):
                for x in range(bx, min(bx + BLOCK, w)):
                    if px[x, y] != first:
                        misaligned += 1
                        break
                if misaligned:
                    break
            if misaligned:
                break
        if misaligned:
            break
    if misaligned:
        errs.append("not aligned to %dx%d block (anti-aliasing or off-grid)" % (BLOCK, BLOCK))

    # 色数（只统计不透明像素）
    colors = Counter()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a:
                colors[(r, g, b)] += 1
    if len(colors) > MAX_COLORS:
        errs.append("colors=%d > %d" % (len(colors), MAX_COLORS))
    elif VERBOSE:
        print("      colors=%d" % len(colors))

    return errs

def main() -> int:
    if not os.path.isfile(BRIEF):
        print("TREASURE_ICONS_FAIL reason=ManifestMissing path=%s" % BRIEF)
        return 1
    with open(BRIEF, encoding="utf-8") as fh:
        manifest = json.load(fh)
    items = manifest["items"]
    expected = manifest["delivery"]["totalFiles"]
    if len(items) != expected:
        print("TREASURE_ICONS_FAIL reason=ManifestCount items=%d expected=%d" % (len(items), expected))
        return 1

    ok = 0
    failed = []
    for item in items:
        errs = check_one(item)
        if errs:
            failed.append((item["fileName"], errs))
            print("  FAIL %-18s %s" % (item["fileName"], "; ".join(errs)))
        else:
            ok += 1
            print("  ok   %-18s" % item["fileName"])

    print("TREASURE_ICONS_%s files=%d/%d" % ("PASS" if not failed else "FAIL", ok, len(items)))
    return 0 if not failed else 1

if __name__ == "__main__":
    sys.exit(main())
