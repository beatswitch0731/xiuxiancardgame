"""Normalize independent generated key poses for source-scale visual QA.

Only removes low-alpha halo, crops, rescales with nearest neighbor and places
the visible feet on a documented line. It does not invent animation frames.
"""

from __future__ import annotations

import json
from pathlib import Path
from PIL import Image
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "godot/art_source/actor_v4_keyframes"
OUT = ROOT / "artifacts/godot-migration/actor-v4-keyframe-review"
OUT.mkdir(parents=True, exist_ok=True)

SPECS = (
    ("yelingyun", "yelingyun_idle_inhale_raw_v2.png", (256, 320), 270, 308),
    ("quick_sword_dummy", "quick_sword_dummy_idle_shift_raw_v1.png", (320, 352), 285, 340),
    ("yelingyun_contact", "yelingyun_sword_contact_raw_v1.png", (512, 320), 265, 308),
    # Low thrust compresses the body vertically; match head/shoulder size to
    # the 270 px neutral actor, rather than forcing both pose bounds to 270 px.
    ("yelingyun_contact_scale_v2", "yelingyun_sword_contact_raw_v1.png", (512, 320), 213, 308),
    # Reconcile the original blade's chest-height intent with a compressed
    # stance. V2 over-compressed the pose and sent the visible sword to the
    # dummy's abdomen at game scale.
    ("yelingyun_contact_scale_v3", "yelingyun_sword_contact_raw_v1.png", (512, 320), 240, 308),
    ("quick_sword_dummy_hit", "quick_sword_dummy_hit_raw_v1.png", (320, 352), 285, 340),
)


def process(actor: str, filename: str, canvas: tuple[int, int], body_h: int, foot_y: int) -> dict:
    raw = np.asarray(Image.open(SOURCE / filename).convert("RGBA")).copy()
    # The generator puts broad warm/gray glows into alpha 1..16. The body is
    # almost entirely opaque; binary alpha removes only antialiased halo/edge.
    foreground = raw[:, :, 3] >= 128
    ys, xs = np.nonzero(foreground)
    if len(xs) == 0:
        raise ValueError(f"{filename}: no opaque actor")
    bounds = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    crop = Image.fromarray(raw, "RGBA").crop(bounds)
    crop_a = np.asarray(crop).copy()
    crop_a[:, :, 3] = np.where(crop_a[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    crop = Image.fromarray(crop_a, "RGBA")
    out_w = round(crop.width * body_h / crop.height)
    if out_w > canvas[0] - 16:
        raise ValueError(f"{actor}: silhouette {out_w}px clips {canvas[0]}px canvas")
    sized = crop.resize((out_w, body_h), Image.Resampling.NEAREST)
    left = round((canvas[0] - out_w) / 2)
    top = foot_y - body_h + 1
    if top < 8 or foot_y >= canvas[1] - 8:
        raise ValueError(f"{actor}: unsafe top or foot margin")
    result = Image.new("RGBA", canvas, (0, 0, 0, 0))
    result.alpha_composite(sized, (left, top))
    path = SOURCE / f"{actor}_single_keypose_review_v1.png"
    result.save(path)
    alpha = np.asarray(result)[:, :, 3]
    yy, xx = np.nonzero(alpha)
    # A sheet cell must reserve the sword and both shoes within its own rect.
    report = {
        "actor": actor,
        "raw": filename,
        "review_png": str(path.relative_to(ROOT)).replace("\\", "/"),
        "raw_bbox_xyxy": bounds,
        "canvas_wh": canvas,
        "visible_bbox_xyxy": [int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1],
        "body_height_px": int(yy.max() - yy.min() + 1),
        "foot_y": int(yy.max()),
        "safe_margin_px": [int(xx.min()), int(yy.min()), canvas[0] - 1 - int(xx.max()), canvas[1] - 1 - int(yy.max())],
        "alpha_values": sorted(map(int, np.unique(alpha).tolist())),
        "rgba_values": int(len(np.unique(np.asarray(result).reshape(-1, 4), axis=0))),
        "eligible_for_sheet": bool(xx.min() >= 8 and yy.min() >= 8 and xx.max() <= canvas[0] - 9 and yy.max() <= canvas[1] - 9),
    }
    return report


def main() -> None:
    reports = [process(*spec) for spec in SPECS]
    # The FrameRonin thumbnail fits each upload by its own width. Put neutral
    # and attack on equal canvases before using its multi-image sequence UI.
    neutral = Image.open(SOURCE / "yelingyun_single_keypose_review_v1.png").convert("RGBA")
    padded = Image.new("RGBA", (512, 320), (0, 0, 0, 0))
    padded.alpha_composite(neutral, (128, 0))
    padded.save(SOURCE / "yelingyun_idle_common_canvas_512x320.png")
    (OUT / "keyframe_geometry_report.json").write_text(
        json.dumps(reports, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    for report in reports:
        print("ACTOR_V4_KEYPOSE", report["actor"], "bbox", report["visible_bbox_xyxy"],
              "foot", report["foot_y"], "margins", report["safe_margin_px"],
              "complete", report["eligible_for_sheet"])


if __name__ == "__main__":
    main()
