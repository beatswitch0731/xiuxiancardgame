"""Extract authored Gemini video frames; no character pixels are drawn here.

The source MP4 and every unmodified decoded frame stay in the artifact folder.
This script only keys the green backdrop, aligns the fixed camera, and reduces
the selected whole-character frames to the battle's 128x80 sprite canvas.
"""

from hashlib import sha256
import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "artifacts/godot-migration/qingyun-gemini-video-probe/source"
RAW = SOURCE / "raw_frames"
OUT = ROOT / "godot/assets/undercurrent_pixel_v1/actor_gemini_video_v1"
REVIEW = ROOT / "artifacts/godot-migration/qingyun-gemini-video-probe"
OUT.mkdir(parents=True, exist_ok=True)

FRAMES = {
    "hero_idle_0": (13, (22, 70), (49, 70), (58, 52), (66, 61)),
    "hero_idle_1": (37, (21, 70), (49, 70), (58, 52), (66, 61)),
    "hero_idle_2": (61, (22, 70), (49, 70), (58, 52), (65, 61)),
    "hero_probe_0": (61, (22, 70), (49, 70), (58, 52), (65, 61)),
    "hero_probe_1": (79, (20, 70), (50, 70), (53, 50), (63, 59)),
    "hero_probe_2": (85, (19, 70), (51, 70), (50, 39), (51, 36)),
    "hero_probe_3": (97, (18, 70), (52, 70), (62, 35), (82, 34)),
    "hero_probe_4": (145, (23, 70), (52, 70), (51, 42), (68, 27)),
    "hero_probe_5": (151, (22, 70), (49, 70), (57, 51), (70, 59)),
}


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def keyed_source(frame: Image.Image) -> Image.Image:
    pixels = np.asarray(frame.convert("RGB"), dtype=np.uint8).copy()
    channels = pixels.astype(np.int16)
    green_excess = channels[:, :, 1] - np.maximum(channels[:, :, 0], channels[:, :, 2])
    background = (green_excess > 35) & (channels[:, :, 1] > 70)
    # The video has a green backdrop, not a drawn scene. Remove only that
    # backdrop; keep the actual model's outlines, fabric and sword pixels.
    spill = (~background) & (green_excess > 10)
    pixels[:, :, 1][spill] = np.minimum(
        channels[:, :, 1][spill],
        np.maximum(channels[:, :, 0], channels[:, :, 2])[spill] + 10,
    ).astype(np.uint8)
    alpha = np.where(background, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack((pixels, alpha)), "RGBA")


def native_frame(source: Image.Image, resampling: Image.Resampling) -> Image.Image:
    # In the 1280x720 fixed-camera source, the boot baseline stays at y=667.
    # One output pixel spans ten video pixels; pivot (40,70) is the battle foot.
    crop = source.crop((220, -33, 1500, 767))
    reduced = crop.resize((128, 80), resampling)
    pixels = np.asarray(reduced, dtype=np.uint8).copy()
    pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 128, 255, 0)
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return Image.fromarray(pixels, "RGBA")


def main() -> None:
    movie = SOURCE / "gemini_sword_probe_raw.mp4"
    still = ROOT / "godot/assets/undercurrent_pixel_v1/actor_mapfit_v3/player_idle_source.png"
    manifest = {
        "generator": "Gemini video UI, actual returned model version not exposed",
        "generationConversation": "https://gemini.google.com/app/cf7a683c4a46de41",
        "prompt": (
            "Use the attached full-body pixel-art swordsman as the exact character identity and opening pose. "
            "Make one short, readable combat animation: he breathes in a supported stance, performs a compact "
            "forward sword thrust to the right, then settles back to the same stance. Fixed orthographic side camera, "
            "whole body and both feet always visible, no zoom or pan, no cuts. Preserve the face, hair knot, blue-gray "
            "robe, boots, sword design, pixel-cluster look and proportions from the input. Both feet make clear ground "
            "contacts; no sliding, no extra limbs, no morphing. Uniform pure green chroma-key background only, no room, "
            "floor, props, enemies, particles, text, UI, or cinematic lighting."
        ),
        "sourceVideo": str(movie.relative_to(ROOT)).replace("\\", "/"),
        "sourceVideoSha256": digest(movie),
        "inputStill": str(still.relative_to(ROOT)).replace("\\", "/"),
        "inputStillSha256": digest(still),
        "inputStillReview": "previously rejected v3 art; pipeline probe only",
        "battleMotionReview": "REJECTED: video feet remain in place while stage adds 88px travel",
        "source": {"width": 1280, "height": 720, "fps": 24, "frames": 240, "durationSec": 10.01},
        "canvas": [128, 80],
        "pivot": [40, 70],
        "method": "green-dominance key; shared fixed-camera crop; 10:1 reduction; alpha cutoff at 128",
        "frames": {},
    }
    variants = {"smooth": Image.Resampling.LANCZOS, "pixel": Image.Resampling.NEAREST}
    for name, (frame_number, left, right, grip, tip) in FRAMES.items():
        raw = RAW / f"frame_{frame_number:04d}.png"
        if not raw.is_file():
            raise FileNotFoundError(raw)
        keyed = keyed_source(Image.open(raw))
        for variant, resampling in variants.items():
            output = OUT / variant
            output.mkdir(exist_ok=True)
            native_frame(keyed, resampling).save(output / f"{name}.png")
        manifest["frames"][name] = {
            "sourceFrame1Based": frame_number,
            "sourceTimeSec": round((frame_number - 1) / 24, 4),
            "left_foot": left,
            "right_foot": right,
            "hand_grip": grip,
            "weapon_tip": tip,
            "groundedFeet": ["left", "right"],
            "pngSha256": {
                variant: digest(OUT / variant / f"{name}.png")
                for variant in variants
            },
        }
    (OUT / "gemini_sword_probe_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    for variant in variants:
        sheet = Image.new("RGBA", (128 * 6, 80), "#171b24")
        for index in range(6):
            name = f"hero_probe_{index}"
            frame = Image.open(OUT / variant / f"{name}.png").convert("RGBA")
            sheet.alpha_composite(frame, (index * 128, 0))
        sheet.resize((1536, 160), Image.Resampling.NEAREST).save(
            REVIEW / f"gemini_probe_{variant}_2x.png"
        )
    print(f"EXTRACTED_GEMINI_FRAMES count={len(FRAMES)} source_sha256={manifest['sourceVideoSha256']}")


if __name__ == "__main__":
    main()
