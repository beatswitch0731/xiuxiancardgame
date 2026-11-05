"""Report effective visible source pixels of the active first-fight actors.

Canvas dimensions alone hide the large transparent margins around these sprites.
Alpha >= 128 is counted as visible; this is an asset audit, not an art pass.
"""

import json
from pathlib import Path
import re
from statistics import median

from PIL import Image


GODOT = Path(__file__).resolve().parents[1]
CONTENT = GODOT / "content"
ACTION_DATA = json.loads((CONTENT / "data/combat/action_presentations.json").read_text(encoding="utf-8"))


def visible_height(path: Path) -> int:
    alpha = Image.open(path).convert("RGBA").getchannel("A")
    bounds = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"Empty actor frame: {path}")
    return bounds[3] - bounds[1]


def clip_scale(actor: str, clip: str) -> float:
    filename = "yelingyun_s1.tres" if actor == "hero" else "quick_sword_dummy.tres"
    resource = (GODOT / "assets/battle/source_first_fight" / filename).read_text(encoding="utf-8")
    match = re.search(rf"^metadata/scale_{re.escape(clip)} = ([0-9.]+)$", resource, re.M)
    if not match:
        raise ValueError(f"Missing scale for {actor}/{clip}")
    return float(match.group(1))


groups = {
    ("hero", "idle"): ["assets/combat/protagonist/growth_matrix_agc_v6/S1_outer_novice/sword.png"],
    ("dummy", "idle"): ["assets/combat/enemy/enc_trial_sword_swift_agc_m2/identity/intent-1.png"],
}
sword = ACTION_DATA["paths"]["sword"]
for clip in ("attack", "guard", "reaction", "hurt", "defeat"):
    groups[("hero", clip)] = sword[clip]["animation"]["frames"]
groups[("hero", "sword_guard")] = sword["guard"]["animation"]["frames"]
for clip, data in ACTION_DATA["cardActions"].items():
    groups[("hero", clip)] = data["animation"]["frames"]
for clip, data in ACTION_DATA["encounters"]["enc_trial_sword_swift"].items():
    groups[("dummy", clip)] = data["animation"]["frames"]

print("actor clip frames visible_height_px[min/median/max] world_size_factor")
for (actor, clip), paths in groups.items():
    heights = [visible_height(CONTENT / path) for path in paths]
    print(f"{actor:5} {clip:21} {len(paths):2} "
          f"{min(heights):3}/{median(heights):5.1f}/{max(heights):3} "
          f"{clip_scale(actor, clip):.3f}")

print("candidate_idle_512 visible_height_px")
for actor, filename in (("hero", "yelingyun_identity_detail_512.png"),
                        ("dummy", "quick_sword_dummy_idle_512.png")):
    print(actor, visible_height(GODOT / "assets/characters/actor_candidates/density_v1" / filename))
