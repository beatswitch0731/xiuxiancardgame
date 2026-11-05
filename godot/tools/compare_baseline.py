#!/usr/bin/env python3
"""PNG 逐像素比对（S3 视觉回归工具）。

为什么不用 md5：PNG 编码器输出不保证逐字节确定（压缩块划分、时间戳元数据
都可能不同），同一画面两次保存的 md5 可能不一致。真正要确认的是像素。

用法：
    python tools/compare_baseline.py A.png B.png
    python tools/compare_baseline.py A.png B.png --tolerance 2 --max-ratio 0.001

退出码：0 通过 / 1 超阈值 / 2 输入错误
"""
import argparse
import sys

try:
    from PIL import Image, ImageChops
except ImportError:
    print("NEED_PIL: pip install pillow")
    sys.exit(2)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("baseline")
    ap.add_argument("candidate")
    ap.add_argument("--tolerance", type=int, default=0,
                    help="单通道允许的最大差值（0 = 严格逐像素一致）")
    ap.add_argument("--max-ratio", type=float, default=0.0,
                    help="允许的超差像素占比上限（0.001 = 0.1%%）")
    args = ap.parse_args()

    try:
        a = Image.open(args.baseline).convert("RGBA")
        b = Image.open(args.candidate).convert("RGBA")
    except OSError as exc:
        print(f"OPEN_FAIL {exc}")
        return 2

    if a.size != b.size:
        print(f"COMPARE_FAIL size {a.size} != {b.size}")
        return 1

    diff = ImageChops.difference(a, b)
    gray = diff.convert("L")
    hist = gray.histogram()
    total = a.size[0] * a.size[1]
    over = sum(hist[args.tolerance + 1:]) if args.tolerance < 255 else 0
    ratio = over / total if total else 0.0
    bbox = gray.getbbox()
    peak = max(range(256), key=lambda v: v if hist[v] else -1) if total else 0
    max_channel = 255
    for value in range(255, args.tolerance, -1):
        if hist[value]:
            max_channel = value
            break

    print(f"COMPARE size={a.size} diffPixels={over}/{total} "
          f"ratio={ratio:.6f} maxChannelDiff={max_channel} bbox={bbox}")

    if ratio > args.max_ratio:
        print(f"COMPARE_FAIL ratio {ratio:.6f} > {args.max_ratio}")
        return 1
    print("COMPARE_PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
