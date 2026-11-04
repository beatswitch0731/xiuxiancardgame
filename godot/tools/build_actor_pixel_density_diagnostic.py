"""Build an isolated 1:1 pixel-density render control, never runtime art.

The existing painted key poses are sampled at about 0.7 screen pixels per
source pixel. Reducing both canvas dimensions to 75% while raising the Godot
pixel size by 4/3 preserves the actor's world size and tests that mismatch.
It cannot turn an illustration into authored pixel animation.
"""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source" / "actor_v3_sprite"
OUTPUT = SOURCE / "diagnostic_pixel_density"
OUTPUT.mkdir(parents=True, exist_ok=True)

for name in (
    "yelingyun_new_master_v2_256x320_review.png",
    "yelingyun_sword_contact_v1_512x320_review.png",
    "quick_sword_dummy_hit_v1_320x352_review.png",
):
    image = Image.open(SOURCE / name).convert("RGBA")
    reduced = image.resize(
        (image.width * 3 // 4, image.height * 3 // 4),
        Image.Resampling.NEAREST,
    )
    target = OUTPUT / name
    reduced.save(target)
    print(f"PIXEL_DENSITY_DIAGNOSTIC {target.name} {reduced.width}x{reduced.height}")
