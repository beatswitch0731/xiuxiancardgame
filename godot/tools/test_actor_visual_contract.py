"""Disposable fixtures prove both acceptance and rejection of art admission."""

import hashlib
import json
import shutil
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

from validate_actor_visual_contract import MINIMUM_FRAMES, REQUIRED, ROOT, validate

PARENT = ROOT / "godot" / "art_source"


def main() -> None:
    fixture = Path(tempfile.mkdtemp(prefix="_actor_gate_fixture_", dir=PARENT)).resolve()
    if not fixture.is_relative_to(PARENT.resolve()):
        raise RuntimeError("Unsafe art-gate fixture path")
    try:
        manifest = {
            "actorId": "yelingyun_s1", "artSetId": "fixture_new_drawn_set",
            "logicalPixelGrid": 2,
            "storyboardFrameCounts": MINIMUM_FRAMES["yelingyun_s1"].copy(),
            "clips": {},
        }
        for clip_index, clip in enumerate(REQUIRED["yelingyun_s1"]):
            frames = []
            for index in range(MINIMUM_FRAMES["yelingyun_s1"][clip]):
                image = Image.new("RGBA", (64, 80))
                draw = ImageDraw.Draw(image)
                draw.rectangle((22, 18, 41, 73), fill=(48 + clip_index * 4, 68 + index * 3, 80, 255))
                draw.rectangle((12 + index % 8 * 2, 34, 17 + index % 8 * 2, 47),
                               fill=(132, 140, 138, 255))
                target = fixture / f"{clip}_{index}.png"
                image.save(target)
                frames.append({
                    "source": target.relative_to(ROOT).as_posix(),
                    "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                    "artSetId": "fixture_new_drawn_set", "canvas": {"w": 64, "h": 80},
                    "footYPx": 76, "headBox": [24, 18, 14, 14],
                    "shoulderSpanPx": 20,
                    "reviewStatus": "identity_anatomy_pixel_light_passed",
                })
            manifest["clips"][clip] = frames
        accepted = validate(manifest)
        if accepted:
            raise AssertionError(f"Coherent disposable fixture rejected: {accepted}")
        wrong_head = json.loads(json.dumps(manifest))
        wrong_head["clips"]["sword_probe"][1]["headBox"][2] = 21
        if not any("cross-clip head_width" in error for error in validate(wrong_head)):
            raise AssertionError("Stand/attack head-scale drift was not rejected")
        old_frame = json.loads(json.dumps(manifest))
        old_frame["clips"]["sword_probe"][1]["artSetId"] = "old_web_sprite_set"
        if not any("source_mix" in error for error in validate(old_frame)):
            raise AssertionError("Mixed actor art sources were not rejected")
        cloned_clip = json.loads(json.dumps(manifest))
        cloned_clip["clips"]["guard"] = cloned_clip["clips"]["reaction"][:]
        cloned_clip["storyboardFrameCounts"]["guard"] = len(cloned_clip["clips"]["guard"])
        if not any("reuse >20% identical poses" in error for error in validate(cloned_clip)):
            raise AssertionError("Different actions were allowed to reuse the same frame strip")
        unknown_clip = json.loads(json.dumps(manifest))
        unknown_clip["clips"]["invented_spin"] = unknown_clip["clips"]["idle"][:]
        if "clip: unexpected invented_spin" not in validate(unknown_clip):
            raise AssertionError("Unknown clip did not produce a structured gate error")
        for actor in ["yelingyun_s1", "quick_sword_dummy"]:
            candidate = ROOT / "godot" / "art_direction" / "candidates" / f"{actor}_v4_rejected_art_manifest.json"
            failed = validate(json.loads(candidate.read_text(encoding="utf-8")))
            if not any("incomplete" in error for error in failed) or not any("palette" in error for error in failed):
                raise AssertionError(f"Rejected V4 {actor} candidate passed key art gates")
        print("ACTOR_VISUAL_CONTRACT_TEST_PASS mechanical_fixture=accepted anatomy_drift=rejected "
              "source_mix=rejected duplicated_action=rejected unknown_clip=rejected v4_hero_dummy=rejected")
    finally:
        if fixture.is_relative_to(PARENT.resolve()) and fixture.name.startswith("_actor_gate_fixture_"):
            shutil.rmtree(fixture)


if __name__ == "__main__":
    main()
