"""Freeze actual V4 keyposes as negative admission fixtures, never game art."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "art_direction" / "candidates"

POSES = {
    "yelingyun_s1": {
        "idle": ("yelingyun_single_keypose_review_v1.png", 256, 320, 308, [95, 39, 49, 53], 75),
        "sword_probe": ("yelingyun_contact_scale_v3_single_keypose_review_v1.png", 512, 320, 308, [151, 69, 49, 53], 87),
    },
    "quick_sword_dummy": {
        "idle": ("quick_sword_dummy_single_keypose_review_v1.png", 320, 352, 340, [133, 56, 56, 65], 99),
        "hurt": ("quick_sword_dummy_hit_single_keypose_review_v1.png", 320, 352, 340, [128, 56, 56, 65], 99),
    },
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for actor, clips in POSES.items():
        art_set = f"actor_v4_two_keyposes_{actor}_rejected"
        manifest = {
            "actorId": actor,
            "artSetId": art_set,
            "logicalPixelGrid": 2,
            "storyboardFrameCounts": {clip: 32 for clip in clips},
            "clips": {},
            "purpose": "Negative evidence: two independent poses do not form an approved action set",
        }
        for clip, (name, w, h, foot, head, shoulder) in clips.items():
            path = ROOT / "godot" / "art_source" / "actor_v4_keyframes" / name
            manifest["clips"][clip] = [{
                "source": path.relative_to(ROOT).as_posix(),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "artSetId": art_set,
                "canvas": {"w": w, "h": h},
                "footYPx": foot,
                "headBox": head,
                "shoulderSpanPx": shoulder,
                "reviewStatus": "keypose_visual_candidate_only",
            }]
        target = OUT / f"{actor}_v4_rejected_art_manifest.json"
        target.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("V4_REJECTION_MANIFEST_BUILT", target)


if __name__ == "__main__":
    main()
