"""Inspect one actor's *whole* authored frame set before FrameRonin packaging.

Geometry is machine checked; identity, anatomy and art review must be annotated
by a human. This deliberately rejects the V4 two-keypose mixed-style preview.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from statistics import median

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REQUIRED = {
    "yelingyun_s1": ["idle", "attack", "guard", "reaction", "hurt", "defeat",
                     "sword_guard", "sword_probe", "sword_followthrough", "sword_edge",
                     "sword_sheath_guard"],
    "quick_sword_dummy": ["idle", "attack", "guard", "hurt", "defeat"],
}
MINIMUM_FRAMES = {
    "yelingyun_s1": {
        "idle": 24, "attack": 16, "guard": 12, "reaction": 12,
        "hurt": 12, "defeat": 12, "sword_guard": 16, "sword_probe": 32,
        "sword_followthrough": 24, "sword_edge": 24, "sword_sheath_guard": 16,
    },
    "quick_sword_dummy": {
        "idle": 24, "attack": 32, "guard": 12, "hurt": 16, "defeat": 12,
    },
}
APPROVED_REVIEW = "identity_anatomy_pixel_light_passed"
MAX_VISIBLE_COLORS = 128  # Machine ceiling; character bible targets about 24 body colors.


def density(image: Image.Image, logical_grid: int) -> tuple[int, float]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    visible_colors = set()
    broken = 0
    occupied = 0
    for y in range(0, rgba.height, logical_grid):
        for x in range(0, rgba.width, logical_grid):
            block = [pixels[xx, yy] for yy in range(y, min(y + logical_grid, rgba.height))
                     for xx in range(x, min(x + logical_grid, rgba.width))]
            visible = [p for p in block if p[3] > 8]
            if not visible:
                continue
            occupied += 1
            visible_colors.update(p[:3] for p in visible)
            if any(p != block[0] for p in block[1:]):
                broken += 1
    return len(visible_colors), broken / max(1, occupied)


def validate(manifest: dict) -> list[str]:
    errors: list[str] = []
    actor = manifest.get("actorId", "")
    if actor not in REQUIRED:
        return [f"actor: unknown actorId {actor!r}"]
    logical_grid = manifest.get("logicalPixelGrid", 0)
    if logical_grid != 2:
        errors.append("pixel_grid: this visual world requires a 2px logical grid")
    art_set = manifest.get("artSetId", "")
    if not art_set:
        errors.append("provenance: missing artSetId")
    clips: dict[str, list[dict]] = manifest.get("clips", {})
    clip_hashes: dict[str, set[str]] = {}
    for clip in REQUIRED[actor]:
        if not clips.get(clip):
            errors.append(f"incomplete: missing authored clip {clip}")
    for clip, frames in clips.items():
        if clip not in REQUIRED[actor]:
            errors.append(f"clip: unexpected {clip}")
            continue
        if not isinstance(frames, list):
            errors.append(f"clip: {clip} needs an ordered frame list")
            continue
        expected_count = manifest.get("storyboardFrameCounts", {}).get(clip)
        minimum = MINIMUM_FRAMES[actor][clip]
        if expected_count is None or len(frames) != expected_count or expected_count < minimum:
            errors.append(f"incomplete: {clip} has {len(frames)} frames; storyboard={expected_count}, floor={minimum}")
        head_sizes: list[tuple[float, float]] = []
        shoulder_spans: list[float] = []
        foot_lines: list[float] = []
        visible_hashes: set[str] = set()
        for index, frame in enumerate(frames):
            label = f"{clip}[{index}]"
            source = frame.get("source", "")
            path = ROOT / source
            if not source or not path.resolve().is_relative_to(ROOT.resolve()):
                errors.append(f"provenance: {label} source escapes workspace")
                continue
            if not path.is_file():
                errors.append(f"provenance: {label} source image missing: {source}")
                continue
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest != frame.get("sha256"):
                errors.append(f"provenance: {label} sha256 does not match frozen source")
            if frame.get("artSetId") != art_set:
                errors.append(f"source_mix: {label} differs from actor art set")
            if frame.get("reviewStatus") != APPROVED_REVIEW:
                errors.append(f"review: {label} identity/anatomy/pixel/light approval missing")
            with Image.open(path) as image:
                rgba = image.convert("RGBA")
                if rgba.getchannel("A").getbbox() is None:
                    errors.append(f"frame: {label} is empty")
                canvas = frame.get("canvas", {})
                if [rgba.width, rgba.height] != [canvas.get("w"), canvas.get("h")]:
                    errors.append(f"canvas: {label} image and declared canvas differ")
                colors, broken = density(rgba, 2)
                if colors > MAX_VISIBLE_COLORS:
                    errors.append(f"palette: {label} has {colors} visible RGB colors (>{MAX_VISIBLE_COLORS})")
                if broken > 0.08:
                    errors.append(f"pixel_grid: {label} has {broken:.1%} fragmented 2px cells (>8%)")
                visible_hashes.add(hashlib.sha256(rgba.tobytes()).hexdigest())
                foot = frame.get("footYPx")
                if not isinstance(foot, (int, float)) or not 0 < foot <= rgba.height:
                    errors.append(f"foot: {label} missing valid pixel foot line")
                else:
                    foot_lines.append(float(foot) / rgba.height)
                head = frame.get("headBox", [])
                if len(head) != 4 or min(head[2:]) <= 0:
                    errors.append(f"anatomy: {label} missing reviewed head box")
                else:
                    head_sizes.append((float(head[2]), float(head[3])))
                shoulder = frame.get("shoulderSpanPx")
                if not isinstance(shoulder, (int, float)) or shoulder <= 0:
                    errors.append(f"anatomy: {label} missing shoulder span")
                else:
                    shoulder_spans.append(float(shoulder))
        if len(visible_hashes) < len(frames):
            errors.append(f"motion: {clip} repeats complete authored frames")
        clip_hashes[clip] = visible_hashes
        if foot_lines and max(foot_lines) - min(foot_lines) > 0.0065:
            errors.append(f"foot: {clip} changes normalized ground line by >2px at 320px")
        for label, values in [("head_width", [size[0] for size in head_sizes]),
                              ("head_height", [size[1] for size in head_sizes]),
                              ("shoulder", shoulder_spans)]:
            if values and (max(values) - min(values)) / median(values) > 0.12:
                errors.append(f"anatomy: {clip} {label} changes by >12%")
    # A pose can crouch, but anatomical sizes and ground scale must remain
    # compatible across clips, not merely within each isolated strip.
    all_frames = [frame for frames in clips.values() if isinstance(frames, list) for frame in frames]
    head_widths = [float(f["headBox"][2]) for f in all_frames
                   if isinstance(f.get("headBox"), list) and len(f["headBox"]) == 4]
    shoulder_widths = [float(f["shoulderSpanPx"]) for f in all_frames
                       if isinstance(f.get("shoulderSpanPx"), (int, float))]
    for label, values in [("head_width", head_widths), ("shoulder", shoulder_widths)]:
        if values and (max(values) - min(values)) / median(values) > 0.12:
            errors.append(f"anatomy: cross-clip {label} changes by >12%")
    clip_names = sorted(clip_hashes)
    for i, left in enumerate(clip_names):
        for right in clip_names[i + 1:]:
            smaller = min(len(clip_hashes[left]), len(clip_hashes[right]))
            if smaller and len(clip_hashes[left] & clip_hashes[right]) / smaller > 0.2:
                errors.append(f"source_mix: {left} and {right} reuse >20% identical poses")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    result = validate(json.loads(args.manifest.read_text(encoding="utf-8")))
    for error in result:
        print("ART_GATE_FAIL", error)
    if result:
        raise SystemExit(1)
    print("ACTOR_ART_PREFLIGHT_PASS manual_visual_review_unverified=true actor="
          + json.loads(args.manifest.read_text(encoding="utf-8"))["actorId"])


if __name__ == "__main__":
    main()
