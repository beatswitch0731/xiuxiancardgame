"""
P0-1: Character sprite optimization
768x944 RGB PNG (~820KB) --> 512x768 WebP (~250KB)
Uses center-crop + NEAREST resize to preserve pixel art sharpness.
"""
from PIL import Image
import glob, os

SRC_DIR = "assets/characters"
DST_DIR = SRC_DIR  # overwrite in place
TARGET_W, TARGET_H = 512, 768
WEBP_QUALITY = 85

files = sorted(glob.glob(f"{SRC_DIR}/*.png"))
print(f"Found {len(files)} character PNGs\n")

for fp in files:
    fname = os.path.basename(fp)
    img = Image.open(fp)
    w, h = img.size
    orig_kb = os.path.getsize(fp) / 1024

    # Target aspect = 512/768 = 2/3
    target_aspect = TARGET_W / TARGET_H
    current_aspect = w / h

    if current_aspect > target_aspect:
        # Current wider than target -> crop width
        new_w = int(h * target_aspect)
        left = (w - new_w) // 2
        cropped = img.crop((left, 0, left + new_w, h))
    else:
        # Current taller than target -> crop height
        new_h = int(w / target_aspect)
        top = (h - new_h) // 2
        cropped = img.crop((0, top, w, top + new_h))

    # NEAREST resize to preserve pixel art
    resized = cropped.resize((TARGET_W, TARGET_H), Image.NEAREST)

    # Save as WebP (lossy, quality 85)
    out_path = fp.replace(".png", ".webp")
    resized.save(out_path, "WEBP", quality=WEBP_QUALITY)
    new_kb = os.path.getsize(out_path) / 1024

    # Delete old PNG
    os.remove(fp)

    reduction = (1 - new_kb / orig_kb) * 100
    print(f"  {fname}: {w}x{h} {orig_kb:.0f}KB -> {TARGET_W}x{TARGET_H} {new_kb:.0f}KB ({reduction:.0f}% smaller)")

# Summary
total_kb = sum(os.path.getsize(f) / 1024 for f in glob.glob(f"{SRC_DIR}/*.webp"))
print(f"\nTOTAL: {total_kb:.0f} KB ({total_kb/1024:.1f} MB)")
print("Done. All characters converted to 512x768 WebP.")
