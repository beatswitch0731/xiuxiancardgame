"""Compare native 1280x800 first-fight renders at the same camera and idle pose.

This gate measures the player-visible actor pixels, not the light node values.
The floor control region guards against raising global exposure to fake a pass.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageStat


REGIONS = {
    "hero_torso": (393, 338, 461, 438),
    "dummy_torso": (832, 338, 916, 432),
    "floor_control": (590, 465, 690, 530),
}


def median_luminance(image: Image.Image, box: tuple[int, int, int, int]) -> float:
    rgb_medians = ImageStat.Stat(image.crop(box)).median[:3]
    return sum(rgb_medians) / 3.0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    args = parser.parse_args()
    with Image.open(args.before) as source, Image.open(args.after) as result:
        if source.size != (1280, 800) or result.size != source.size:
            raise SystemExit("ACTOR_VISIBILITY_FAIL requires matched 1280x800 captures")
        before = source.convert("RGB")
        after = result.convert("RGB")
        delta = {
            name: median_luminance(after, box) - median_luminance(before, box)
            for name, box in REGIONS.items()
        }
    passed = (
        delta["hero_torso"] >= 13.0
        and delta["dummy_torso"] >= 20.0
        and abs(delta["floor_control"]) <= 1.0
    )
    print(("ACTOR_VISIBILITY_PASS" if passed else "ACTOR_VISIBILITY_FAIL"), delta)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
