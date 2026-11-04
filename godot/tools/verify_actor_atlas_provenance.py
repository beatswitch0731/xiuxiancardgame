"""Check that a FrameRonin atlas contains the approved source pixels in order.

This gate proves packaging fidelity only. It does not approve drawing, motion,
identity, or the separate full-actor visual contract.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]


def _inside_workspace(path: Path) -> bool:
    return path.resolve().is_relative_to(ROOT.resolve())


def _visible_rgba(image: Image.Image) -> bytes:
    pixels = bytearray(image.convert("RGBA").tobytes())
    for offset in range(0, len(pixels), 4):
        if pixels[offset + 3] == 0:
            pixels[offset:offset + 3] = b"\0\0\0"
    return bytes(pixels)


def verify(manifest: dict, clip: str, sheet_path: Path, index: dict) -> list[str]:
    errors: list[str] = []
    frames = manifest.get("clips", {}).get(clip)
    cells = index.get("frames")
    if not isinstance(frames, list) or not frames:
        return [f"manifest: missing source clip {clip}"]
    if not isinstance(cells, list) or len(cells) != len(frames):
        return [f"index: {clip} requires {len(frames)} ordered cells"]
    if index.get("actorId", manifest.get("actorId")) != manifest.get("actorId"):
        errors.append("index: actorId differs from approved source")
    if index.get("artSetId", manifest.get("artSetId")) != manifest.get("artSetId"):
        errors.append("index: artSetId differs from approved source")
    if not _inside_workspace(sheet_path) or not sheet_path.is_file():
        return errors + ["sheet: atlas must be an existing file inside the workspace"]
    with Image.open(sheet_path) as image:
        atlas = image.convert("RGBA")
    rectangles: list[tuple[int, int, int, int]] = []
    for number, (frame, cell) in enumerate(zip(frames, cells)):
        label = f"{clip}[{number}]"
        if not isinstance(frame, dict) or not isinstance(cell, dict):
            errors.append(f"{label}: source frame and index cell must be objects")
            continue
        source = frame.get("source", "")
        if not isinstance(source, str) or not source:
            errors.append(f"{label}: missing source path")
            continue
        source_path = ROOT / source
        if not _inside_workspace(source_path) or not source_path.is_file():
            errors.append(f"{label}: source image missing or outside workspace")
            continue
        if hashlib.sha256(source_path.read_bytes()).hexdigest() != frame.get("sha256"):
            errors.append(f"{label}: frozen source SHA-256 mismatch")
            continue
        if frame.get("artSetId") != manifest.get("artSetId"):
            errors.append(f"{label}: source art set differs from manifest")
        if cell.get("source_sha256", frame["sha256"]) != frame["sha256"]:
            errors.append(f"{label}: atlas index points to another source frame")
        with Image.open(source_path) as image:
            source_image = image.convert("RGBA")
        canvas = frame.get("canvas", {})
        if [source_image.width, source_image.height] != [canvas.get("w"), canvas.get("h")]:
            errors.append(f"{label}: source canvas differs from manifest")
            continue
        try:
            x, y, w, h = (cell[key] for key in ("x", "y", "w", "h"))
        except KeyError:
            errors.append(f"{label}: incomplete atlas rectangle")
            continue
        if not all(type(value) is int for value in (x, y, w, h)):
            errors.append(f"{label}: atlas rectangle must use integer coordinates")
            continue
        if x < 0 or y < 0 or w != source_image.width or h != source_image.height \
                or x + w > atlas.width or y + h > atlas.height:
            errors.append(f"{label}: atlas cell is cropped, scaled, or outside sheet")
            continue
        rect = (x, y, x + w, y + h)
        if any(x < right and x + w > left and y < bottom and y + h > top
               for left, top, right, bottom in rectangles):
            errors.append(f"{label}: atlas cells overlap")
        rectangles.append(rect)
        crop = atlas.crop(rect)
        if _visible_rgba(crop) != _visible_rgba(source_image):
            errors.append(f"{label}: atlas pixels differ from approved source")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="full actor visual-contract manifest")
    parser.add_argument("--clip", required=True, help="one authored clip in the manifest")
    parser.add_argument("--sheet", required=True, type=Path, help="FrameRonin PNG atlas")
    parser.add_argument("--index", required=True, type=Path, help="ordered FrameRonin cells JSON")
    args = parser.parse_args()
    for path in (args.manifest, args.index):
        if not _inside_workspace(path) or not path.is_file():
            parser.error(f"missing workspace file: {path}")
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    index = json.loads(args.index.read_text(encoding="utf-8"))
    errors = verify(manifest, args.clip, args.sheet, index)
    for error in errors:
        print("ACTOR_ATLAS_PROVENANCE_FAIL", error)
    if errors:
        raise SystemExit(1)
    print(f"ACTOR_ATLAS_PROVENANCE_PASS actor={manifest['actorId']} "
          f"clip={args.clip} cells={len(index['frames'])} manual_art_review_unverified=true")


if __name__ == "__main__":
    main()
