"""Place the existing whole-character still on a green video input canvas."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "godot/assets/battle/undercurrent_pixel_v1/actor_mapfit_v3/player_idle_source.png"
OUT = ROOT / "artifacts/godot-migration/qingyun-gemini-video-probe/source/gemini_lunge_input.png"
original = Image.open(SOURCE).convert("RGBA")
bbox = original.getchannel("A").getbbox()
if bbox is None:
    raise ValueError("Character source has no opaque pixels")
subject = original.crop(bbox)
height = 540
width = round(subject.width * height / subject.height)
subject = subject.resize((width, height), Image.Resampling.LANCZOS)
canvas = Image.new("RGBA", (1280, 720), (0, 186, 22, 255))
canvas.alpha_composite(subject, (85, 95))
canvas.convert("RGB").save(OUT)
print(OUT)
