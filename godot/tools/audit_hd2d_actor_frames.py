"""Report source-frame pixel/alpha inconsistency without modifying art."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = {
    "hero_idle": "content/assets/combat/protagonist/growth_matrix_agc_v6/S1_outer_novice/sword.png",
    "hero_probe_contact": "content/assets/combat/protagonist/s1_outer_novice_v15/sword_attack_probe_rework_v1/attack-4.png",
    "dummy_idle": "content/assets/combat/enemy/enc_trial_sword_swift_agc_m2/identity/intent-1.png",
}

for name, relative in SAMPLES.items():
    image = Image.open(ROOT / relative).convert("RGBA")
    alpha = image.getchannel("A")
    histogram = alpha.histogram()
    print(f"{name}: size={image.size} bbox={alpha.getbbox()} "
          f"rgba_colors={len(set(image.get_flattened_data()))} "
          f"partial_alpha_pixels={sum(histogram[1:255])} opaque_pixels={histogram[255]}")
